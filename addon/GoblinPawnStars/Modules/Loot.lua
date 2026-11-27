--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Loot.lua
    Watches the player's bags (read-only) and turns newly gained items into
    virtual stock. Diffing item counts instead of trusting loot events makes the
    detector idempotent: repeated events can never duplicate stock.

    Three details matter on a live client:
      * an empty bag snapshot must still become the baseline, otherwise the
        first item looted after login is swallowed;
      * just-looted item IDs are often not cached yet, so a scan falls back to
        GetItemInfoInstant + the bag hyperlink instead of dropping the gain;
      * selling or destroying real items lowers the bag counts, and the baseline
        has to follow that drop or re-looting the same item is invisible.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local L = {}
ns.Loot = L

local MAX_PER_SCAN = 8
local scanScheduled = false
local deferRetries = 0

-- Snapshot of itemID -> total count across all readable bags, plus the first
-- hyperlink seen for each ID (used to resolve uncached items).
local function snapshotBags()
    local counts, links = {}, {}
    local readable = false

    for _, bag in ipairs(ns.Compat.BagSlots()) do
        local slots = ns.Compat.GetContainerNumSlots(bag)
        if slots > 0 then
            readable = true
            for slot = 1, slots do
                local info = ns.Compat.GetContainerItemInfo(bag, slot)
                local itemID, count, link

                if type(info) == "table" then
                    itemID = tonumber(info.itemID)
                    count = tonumber(info.stackCount) or 1
                    link = info.hyperlink
                end
                if not itemID then
                    itemID = ns.Compat.GetContainerItemID(bag, slot)
                end
                if not link then
                    link = ns.Compat.GetContainerItemLink(bag, slot)
                end
                if not itemID and link then
                    itemID = ns.Compat.ItemIDFromLink(link)
                end

                if itemID then
                    counts[itemID] = (counts[itemID] or 0) + (count or 1)
                    if type(link) == "string" and not links[itemID] then
                        links[itemID] = link
                    end
                end
            end
        end
    end

    return counts, readable, links
end

local function noteStock(record, gained)
    local label = record.name or "an item"
    if gained > 1 then label = label .. " x" .. gained end
    ns.Debug("stocked " .. label)
end

-- Returns number of new stock records created and how many gains were deferred
-- (uncached item data, storage full, or over the per-scan cap).
local function scan(force)
    local db = DB.Get()
    if not force and db.settings.autoCollect == false then return 0, 0 end

    local snapshot, readable, links = snapshotBags()
    if not readable then return 0, 0 end

    -- An empty snapshot is still a valid baseline. Without this, logging in with
    -- empty bags and looting one item would treat that item as the baseline.
    if type(db.baseline) ~= "table" or type(db.baseline.counts) ~= "table" then
        db.baseline = { counts = snapshot, at = U.now() }
        ns.Debug("captured initial bag snapshot")

        -- One-time discovery hint: the first scan is deliberately silent, so tell
        -- the player how to import loot they were already carrying.
        if not db.settings.bagHintShown then
            local eligible = 0
            for itemID in pairs(snapshot) do
                local info = ns.Compat.Item(itemID, links[itemID])
                if info and ns.Data.IsEligible(info) then eligible = eligible + 1 end
            end
            if eligible > 0 then
                db.settings.bagHintShown = true
                ns.Print(string.format(
                    "|cffffd700%d eligible item stack%s|r in your bags. Click |cffffffffStock Bags Now|r on the Dashboard, or type /gps importbags, to copy them onto the shelves.",
                    eligible, eligible == 1 and "" or "s"))
            end
        end
        return 0, 0
    end

    local baseline = db.baseline.counts
    local nextBaseline = {}
    for itemID, count in pairs(snapshot) do nextBaseline[itemID] = count end

    local added = 0
    local deferred = 0
    local gainedTotal = 0
    local newNames = {}

    for itemID, count in pairs(snapshot) do
        local before = tonumber(baseline[itemID]) or 0
        local gained = count - before
        if gained > 0 then
            local info = ns.Compat.Item(itemID, links[itemID])
            if not info then
                -- Not cached yet: keep the old count so a later scan sees the gain.
                nextBaseline[itemID] = before
                deferred = deferred + 1
                ns.Compat.RequestItemData(itemID)
            else
                local eligible = ns.Data.IsEligible(info)
                if eligible and added < MAX_PER_SCAN then
                    info.category = ns.Data.CategoryOf(info)
                    info.value = ns.Data.BaseValue(info)
                    local record = ns.Inventory.Add(info, { source = "loot", count = gained })
                    if record then
                        added = added + 1
                        gainedTotal = gainedTotal + gained
                        newNames[#newNames + 1] = info.name
                        noteStock(record, gained)
                    else
                        nextBaseline[itemID] = before
                        deferred = deferred + 1
                    end
                elseif eligible then
                    -- Over the cap: leave the gap for the next scan.
                    nextBaseline[itemID] = before
                    deferred = deferred + 1
                end
            end
        end
    end

    db.baseline.counts = nextBaseline
    db.baseline.at = U.now()

    if added > 0 then
        db.shop.lastStock = {
            names = newNames,
            count = gainedTotal,
            at = U.now(),
        }
        ns.Achievements.Check()
        if ns.UI and ns.UI.Toast then
            ns.UI.Toast(string.format("Stocked %d new stack%s at the pawnshop.",
                added, added == 1 and "" or "s"))
        end
    end

    -- Pick up the rest shortly, but never spin forever when storage is full.
    if added > 0 then deferRetries = 0 end
    if deferred > 0 and L.ScheduleScan and deferRetries < 3 then
        deferRetries = deferRetries + 1
        L.ScheduleScan(5)
    elseif deferred == 0 then
        deferRetries = 0
    end

    return added, deferred
end

-- Every real scan, including event/timer scans forced from Settings, goes
-- through this wrapper so its duration is recorded once.
function L.Scan(force)
    local started = ns.Perf and ns.Perf.Now and ns.Perf.Now()
    local ok, added, deferred = pcall(scan, force)
    if ns.Perf then ns.Perf.Record("bags", started) end
    if not ok then error(added, 0) end
    return added, deferred
end

-- One-shot import for loot the player already had before installing or before
-- the baseline existed. IDs already represented in stock are skipped entirely,
-- so pressing it twice cannot duplicate a stack.
function L.ImportCurrentBags()
    local db = DB.Get()
    local snapshot, readable, links = snapshotBags()
    if not readable then return 0, 0, false end

    local stocked = {}
    for _, record in pairs(db.inventory) do
        if record.id then stocked[record.id] = true end
    end

    local added, items = 0, 0
    local names = {}

    -- Start from the current bag counts, but leave a zero gap for anything that
    -- could not be imported (storage full, uncached). A later scan then sees it
    -- as new instead of losing it behind the fresh baseline.
    local nextBaseline = {}
    for itemID, count in pairs(snapshot) do nextBaseline[itemID] = count end

    for itemID, count in pairs(snapshot) do
        if not stocked[itemID] then
            local info = ns.Compat.Item(itemID, links[itemID])
            if info then
                if ns.Data.IsEligible(info) then
                    info.category = ns.Data.CategoryOf(info)
                    info.value = ns.Data.BaseValue(info)
                    local record = ns.Inventory.Add(info, { source = "import", count = count })
                    if record then
                        added = added + 1
                        items = items + count
                        stocked[itemID] = true
                        names[#names + 1] = info.name
                    else
                        nextBaseline[itemID] = 0
                    end
                end
            else
                nextBaseline[itemID] = 0
                ns.Compat.RequestItemData(itemID)
            end
        end
    end

    db.baseline = { counts = nextBaseline, at = U.now() }

    if added > 0 then
        db.shop.lastStock = { names = names, count = items, at = U.now() }
        ns.Achievements.Check()
    end
    return added, items, true
end

function L.Diagnose()
    local db = DB.Get()
    local snapshot, readable, links = snapshotBags()
    local stacks, items = 0, 0
    for _, count in pairs(snapshot) do
        stacks = stacks + 1
        items = items + count
    end

    local baselineStacks = 0
    if type(db.baseline) == "table" and type(db.baseline.counts) == "table" then
        for _ in pairs(db.baseline.counts) do baselineStacks = baselineStacks + 1 end
    end

    local linksKnown = 0
    for _ in pairs(links) do linksKnown = linksKnown + 1 end

    local eligible, skipped, uncached = 0, 0, 0
    for itemID in pairs(snapshot) do
        local info = ns.Compat.Item(itemID, links[itemID])
        if not info then
            uncached = uncached + 1
        elseif ns.Data.IsEligible(info) then
            eligible = eligible + 1
        else
            skipped = skipped + 1
        end
    end

    return {
        readable = readable,
        bags = #ns.Compat.BagSlots(),
        stacks = stacks,
        items = items,
        baselineStacks = baselineStacks,
        hasBaseline = type(db.baseline) == "table" and type(db.baseline.counts) == "table",
        linksKnown = linksKnown,
        eligible = eligible,
        skipped = skipped,
        uncached = uncached,
        autoCollect = db.settings.autoCollect ~= false,
    }
end

function L.ScheduleScan(delay)
    if scanScheduled then return end
    scanScheduled = true
    local ok = pcall(function()
        C_Timer.After(delay or 1.0, function()
            scanScheduled = false
            local ok, err = pcall(L.Scan)
            if not ok then
                ns.RecordError("bags", err)
                ns.Debug("bag scan error: " .. tostring(err))
            end
        end)
    end)
    if not ok then
        scanScheduled = false
        L.Scan()
    end
end

function L.ResetBaseline()
    local db = DB.Get()
    local snapshot = snapshotBags()
    db.baseline = { counts = snapshot, at = U.now() }
    return true
end

function L.Events()
    return ns.Compat.EventFrame({
        PLAYER_ENTERING_WORLD = function()
            L.ScheduleScan(3.0)
        end,
        BAG_UPDATE_DELAYED = function()
            L.ScheduleScan(1.0)
        end,
        PLAYER_LOGIN = function()
            L.ScheduleScan(2.0)
        end,
        -- Fires when the client caches an item's data; retry deferred gains.
        GET_ITEM_INFO_RECEIVED = function()
            L.ScheduleScan(1.5)
        end,
    })
end

L.events = L.Events()

-- Safety net for clients where the bag events are unreliable. Thirty seconds is
-- cheap (a read-only pass over the slots) and never creates credits or items.
if C_Timer and type(C_Timer.NewTicker) == "function" then
    local ok, ticker = pcall(C_Timer.NewTicker, 30, function()
        local scanned, err = pcall(L.Scan)
        if not scanned then
            ns.RecordError("bags-periodic", err)
            ns.Debug("periodic bag scan error: " .. tostring(err))
        end
    end)
    if ok then L.ticker = ticker end
end
