--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Ceremony.lua
    Milestones with a little ceremony: a reputation tier crossed and a deed
    completed. Two things happen, both cheap:

      1. A one-second celebration (icon burst + toast + the native achievement
         fanfare) drawn by UI/MainFrame's existing toast path.
      2. A permanent visual flag: one pip per reputation tier in the sidebar,
         driven by `db.shop.celebratedTier`, so the shop visibly grows as the
         player earns standing.

    There is no timer and no polling here. `Sync` is called from the one place
    reputation changes (Shop.AddReputation) and from the UI's existing header
    refresh, so it runs only when something already happened, and it compares two
    integers to decide whether to act. The saved flag means a relog restores the
    pips without replaying the fanfare.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local DB = ns.DB
local C = {}
ns.Ceremony = C

local function tiers()
    return (ns.Data and ns.Data.ReputationTiers) or {}
end

--- Highest reputation tier index the shop has actually reached.
function C.Reached()
    local rep = tonumber(ns.Shop and ns.Shop.Reputation and ns.Shop.Reputation() or 0) or 0
    local reached = 0
    for index, def in ipairs(tiers()) do
        if rep >= (tonumber(def.at) or 0) then reached = index end
    end
    return reached
end

--- Highest tier already celebrated (persisted, clamped, additive).
function C.Celebrated()
    local ok, db = pcall(DB.Get)
    if not ok or type(db) ~= "table" or type(db.shop) ~= "table" then return 0 end
    local value = math.floor(tonumber(db.shop.celebratedTier) or 0)
    return math.max(0, math.min(#tiers(), value))
end

local PERK_TEXT = {
    waiting = "an extra waiting slot",
    rare = "rarer customers",
    patience = "one more haggling round",
    offer = "5% better offers",
}

--- Plays the celebration. `quiet` skips the toast (the deeds screen already
--  announces its own unlocks); the burst and the fanfare always happen.
function C.Play(kind, title, text, icon, quiet)
    if ns.UI and ns.UI.Celebrate and not quiet then
        pcall(ns.UI.Celebrate, title, text, icon)
    elseif ns.UI and ns.UI.Celebrate then
        pcall(ns.UI.Celebrate, title, text, icon, true)
    end
    if ns.Sound and ns.Sound.Play then pcall(ns.Sound.Play, "achievement") end
    -- Deeds already write their own ledger line in Achievements.Check; only the
    -- tier ceremony adds one here, so nothing is logged twice.
    if kind == "tier" and title and ns.History and ns.History.Add then
        pcall(ns.History.Add, {
            kind = kind,
            text = title,
            amount = 0,
            icon = icon,
            detail = text,
        })
    end
    return true
end

--- Called after reputation changes and from the header refresh. Celebrates at
--  most one newly crossed tier and never repeats one: the flag is saved.
function C.Sync()
    local ok, db = pcall(DB.Get)
    if not ok or type(db) ~= "table" or type(db.shop) ~= "table" then return false end
    -- One read of the database, one loop over four entries. This runs from the
    -- once-a-second header refresh, so it has to be cheaper than a widget write.
    local rep = tonumber(db.reputation) or 0
    local reached = 0
    local list = tiers()
    for index, def in ipairs(list) do
        if rep >= (tonumber(def.at) or 0) then reached = index end
    end
    local celebrated = math.max(0, math.min(#list,
        math.floor(tonumber(db.shop.celebratedTier) or 0)))
    if reached <= celebrated then return false end

    -- Jumping two tiers in one gain (a big deed payout) still announces only
    -- the top one: one celebration, not a queue of them.
    db.shop.celebratedTier = reached
    local def = list[reached]
    local title = def and def.name or "New standing"
    local text = def and string.format("%d reputation · %s",
        tonumber(def.at) or 0, PERK_TEXT[def.perk] or "the shop is noticed") or nil
    C.Play("tier", title, text, def and def.icon)
    return true
end

--- Deed completion. Quiet because Achievements.Check already prints and toasts.
function C.Deed(def)
    if type(def) ~= "table" then return false end
    C.Play("deed", def.name or "Deed", def.description, def.icon, true)
    return true
end

--- Diagnostics only: reset the saved flag so a test can force a tier-up.
function C.Forget()
    local ok, db = pcall(DB.Get)
    if ok and type(db) == "table" and type(db.shop) == "table" then
        db.shop.celebratedTier = 0
    end
end
