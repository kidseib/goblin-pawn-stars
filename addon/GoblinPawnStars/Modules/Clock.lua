--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Clock.lua
    One throttled OnUpdate frame drives every simulation tick. Nothing polls the
    event queue and nothing runs per-frame except this accumulator.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local DB = ns.DB
local C = {}
ns.Clock = C

local TICK = 1.0
local AUTOSAVE = 30.0

local accumulator = 0
local saveAccumulator = 0

function C.Paused()
    return DB.Get().settings.paused == true
end

function C.OnTick(dt)
    local db = DB.Get()

    -- Saving is not gameplay. Pausing the shop must not stall an incremental
    -- journal write or the autosave, or a paused session could never settle.
    if ns.Journal and ns.Journal.Tick then ns.Journal.Tick() end
    saveAccumulator = saveAccumulator + dt
    if saveAccumulator >= AUTOSAVE then
        saveAccumulator = 0
        DB.Save()
    end

    if C.Paused() then return end

    db.stats.playtime = (db.stats.playtime or 0) + dt

    ns.Market.Tick(dt)
    ns.Shop.Tick(dt)
    ns.Customers.Tick(dt)
    ns.Throughput.Tick(dt)
    ns.Wholesaler.Tick(dt)
    ns.Encounters.Tick(dt)
    if ns.Backups and ns.Backups.Tick then ns.Backups.Tick(dt) end

    if ns.UI and ns.UI.Tick then
        local ok, err = pcall(ns.UI.Tick, dt)
        if not ok then
            ns.RecordError("ui-tick", err)
            ns.Debug("UI tick error: " .. tostring(err))
        end
    end
end

local frame = ns.Compat.CreateFrame("Frame")
if frame then
    frame:SetScript("OnUpdate", function(_, elapsed)
        accumulator = accumulator + math.min(elapsed or 0, 5)
        if accumulator < TICK then return end
        local step = accumulator
        accumulator = 0
        local ok, err = pcall(C.OnTick, step)
        if not ok then
            ns.RecordError("tick", err)
            ns.Debug("tick error: " .. tostring(err))
        end
    end)
end

C.frame = frame

-- Describes the shop that is actually in memory. It runs straight after login,
-- or — when a saved run is still coming out of the macro journal — on the
-- journal's first settle, so a returning player never gets the fresh-stall line.
local function announceSession()
    local db = DB.Get()
    if (db.stats.sales or 0) == 0 then
        ns.Print("Your stall is open. A starter crate is on the counter; the wholesaler can keep it stocked. Type |cff7bd66b/gps|r to begin.")
        return
    end
    -- Nothing is earned while the shop is closed, so the summary says what is
    -- waiting rather than pretending the salesperson traded overnight.
    ns.Print(string.format(
        "|cff7bd66bWelcome back|r · %s gc · %d waiting · %d/%d stock.",
        ns.Util.comma(db.credits or 0), #db.shop.waiting,
        ns.Inventory.Count(), ns.Inventory.Capacity()))
end

C.events = ns.Compat.EventFrame({
    PLAYER_LOGIN = function()
        local db = DB.Get()
        db.lastSession = { login = ns.Util.now(), version = ns.VERSION }
        local firstVisit = (db.stats.sales or 0) == 0
        local delay = ns.Shop.ArrivalInterval() * (firstVisit and 0.28 or 0.5)
        db.shop.nextArrival = math.max(16, delay)
        ns.Wholesaler.GrantStarter()
        ns.Shop.RefreshDailyRequest()
        ns.Achievements.Check()

        -- The journal arms a short automatic load at login. While it is pending the
        -- summary waits for it: two seconds later the saved run replaces these
        -- defaults, so announcing now would call a returning player a new stall.
        local journal = ns.Journal
        if journal and journal.AutoPending and journal.AutoPending() then
            ns.Print("|cff9c8a5aLoading your saved shop…|r Settings → Backup & Restore can load it by hand.")
            if journal.AfterSettle then journal.AfterSettle(announceSession) end
        else
            announceSession()
            if journal and journal.Active and journal.Active()
                and not (journal.Loaded and journal.Loaded()) then
                -- Nothing is going to load this session: point at the button.
                ns.Print("|cff9c8a5aSaved shop not loaded.|r Settings → Backup & Restore → " ..
                    "|cffffffffLoad saved|r resumes it. Nothing is overwritten until you choose.")
            end
        end
        ns.Debug("simulation clock started")
    end,
})
