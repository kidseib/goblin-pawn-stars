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
    if C.Paused() then return end

    db.stats.playtime = (db.stats.playtime or 0) + dt

    ns.Market.Tick(dt)
    ns.Shop.Tick(dt)
    ns.Customers.Tick(dt)
    ns.Throughput.Tick(dt)
    ns.Wholesaler.Tick(dt)
    ns.Encounters.Tick(dt)
    if ns.Journal and ns.Journal.Tick then ns.Journal.Tick() end

    saveAccumulator = saveAccumulator + dt
    if saveAccumulator >= AUTOSAVE then
        saveAccumulator = 0
        DB.Save()
    end

    if ns.UI and ns.UI.Tick then
        local ok, err = pcall(ns.UI.Tick, dt)
        if not ok then ns.Debug("UI tick error: " .. tostring(err)) end
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
        if not ok then ns.Debug("tick error: " .. tostring(err)) end
    end)
end

C.frame = frame

C.events = ns.Compat.EventFrame({
    PLAYER_LOGIN = function()
        -- Restore before the clock grants the starter crate or schedules the
        -- first arrival, so a fresh client never overwrites a real journal run.
        if ns.Journal then ns.Journal.TryLoad() end
        local db = DB.Get()
        db.lastSession = { login = ns.Util.now(), version = ns.VERSION }
        local firstVisit = (db.stats.sales or 0) == 0
        local delay = ns.Shop.ArrivalInterval() * (firstVisit and 0.28 or 0.5)
        db.shop.nextArrival = math.max(16, delay)
        ns.Wholesaler.GrantStarter()
        ns.Shop.RefreshDailyRequest()
        ns.Achievements.Check()
        if firstVisit then
            ns.Print("Your stall is open. A starter crate is on the counter; the wholesaler can keep it stocked. Type |cff7bd66b/gps|r to begin.")
        end
        ns.Debug("simulation clock started")
    end,
})
