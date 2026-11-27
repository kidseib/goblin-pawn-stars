--[[ Goblin Pawn Stars -------------------------------------------------------
    Core/Backups.lua
    Rolling local snapshots of the shop database. This is deliberately a
    separate SavedVariables global: a snapshot must not contain the snapshot
    list, or every capture would grow the next one. Capture only reads the
    active database; restore replaces it with the encoded snapshot.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local DB = ns.DB
local U = ns.Util

local B = {}
ns.Backups = B

local MAX_SLOTS = 3
local FIRST_AUTO = 30
local EVERY_AUTO = 600

local autoElapsed = 0
local firstAuto = true
local scratchStore
local scratchDb

local function newStore()
    return { version = 1, slots = {} }
end

-- Live snapshots live in their own SavedVariables table. Sanitise a hand-edited
-- or partially written store once on access rather than letting the UI meet a
-- non-table slot.
local function liveStore()
    local store = _G.GoblinPawnStarsBackups
    if type(store) ~= "table" then
        store = newStore()
        _G.GoblinPawnStarsBackups = store
    end
    if type(store.slots) ~= "table" then store.slots = {} end
    for index = #store.slots, 1, -1 do
        local snapshot = store.slots[index]
        if type(snapshot) ~= "table" or type(snapshot.text) ~= "string" then
            table.remove(store.slots, index)
        end
    end
    return store
end

local function defaultStore()
    if DB.scratch then
        local db = DB.Get()
        if scratchDb ~= db then
            scratchDb = db
            scratchStore = newStore()
        end
        return scratchStore
    end
    return liveStore()
end

local function hasProgress(db)
    if db.stats and (tonumber(db.stats.sales) or 0) > 0 then return true end
    if type(db.inventory) == "table" and next(db.inventory) then return true end
    if db.campaign and (tonumber(db.campaign.payments) or 0) > 0 then return true end
    return false
end

function B.NewStore()
    return newStore()
end

function B.Slots(store)
    store = store or defaultStore()
    if type(store) ~= "table" then return {} end
    return type(store.slots) == "table" and store.slots or {}
end

-- Reads the active database and stores a timestamped copy of it. No economy
-- function is called, so a capture can neither mint credits nor add stock.
function B.Capture(reason, store)
    local db = DB.Get()
    if not db then return nil, "no shop data" end
    local ok, text = pcall(DB.Export)
    if not ok or type(text) ~= "string" or text == "" then
        return nil, "could not encode the shop"
    end
    store = store or defaultStore()
    if type(store) ~= "table" then return nil, "no backup store" end
    if type(store.slots) ~= "table" then store.slots = {} end

    local snapshot = {
        at = U.now(),
        reason = reason or "manual",
        text = text,
        credits = tonumber(db.credits) or 0,
        items = ns.Inventory.Count(),
        sales = (db.stats and tonumber(db.stats.sales)) or 0,
        tier = tonumber(db.tier) or 1,
    }
    table.insert(store.slots, 1, snapshot)
    while #store.slots > MAX_SLOTS do table.remove(store.slots) end
    store.version = 1
    autoElapsed = 0
    return snapshot
end

-- The pre-restore capture is mandatory. If it cannot be written, abort rather
-- than replacing the shop with only an in-memory target snapshot.
function B.Restore(index, confirmed, store)
    store = store or defaultStore()
    if type(store) ~= "table" or type(store.slots) ~= "table" then
        return false, "no backup store"
    end
    local snapshot = store.slots[index]
    if type(snapshot) ~= "table" then return false, "that snapshot is no longer there" end
    if confirmed ~= true then return false, "confirmation required" end
    local text = snapshot.text
    if type(text) ~= "string" or text == "" then return false, "that snapshot is empty" end

    local pre, preErr = B.Capture("pre-restore", store)
    if not pre then
        return false, "could not save the pre-restore backup: " .. tostring(preErr)
    end

    local ok, err = DB.Import(text)
    if not ok then return false, err or "could not restore that snapshot" end
    autoElapsed = 0
    return true
end

-- Called once a second by the simulation clock. Paused and scratch shops do not
-- capture automatically; pre-restore captures are explicit and always run.
function B.Tick(dt)
    if DB.scratch or not DB.IsLive() then return end
    autoElapsed = autoElapsed + (tonumber(dt) or 0)
    local interval = firstAuto and FIRST_AUTO or EVERY_AUTO
    if autoElapsed < interval then return end
    autoElapsed = 0
    firstAuto = false
    if hasProgress(DB.Get()) then B.Capture("auto") end
end

local REASON_LABELS = {
    manual = "Manual",
    auto = "Automatic",
    ["pre-restore"] = "Before restore",
}

function B.Reason(reason)
    return REASON_LABELS[reason] or "Snapshot"
end

function B.Summary(snapshot)
    if type(snapshot) ~= "table" then return "" end
    return string.format("%s gc · %d stacks · %d sales",
        U.comma(snapshot.credits or 0),
        tonumber(snapshot.items) or 0,
        tonumber(snapshot.sales) or 0)
end

function B.Stamp(at)
    if type(date) ~= "function" then return "unknown time" end
    local ok, text = pcall(date, "%Y-%m-%d %H:%M", tonumber(at) or 0)
    if ok and text then return tostring(text) end
    return "unknown time"
end
