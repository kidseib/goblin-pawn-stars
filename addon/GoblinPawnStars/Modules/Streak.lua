--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Streak.lua
    The counter streak: a session-only count of counters that landed in a row.
    Five in a row arms one "clean deal" — the next landed counter pays a little
    over the agreed price and a couple of reputation — then everything resets.

    Why session-only: a streak is a hot hand, not progress. Saving it would let a
    player park four wins, log out, and carry the perk into any later sale; it
    would also mean a save migration for a number that is more fun when it can be
    lost. Nothing here touches `db`, so there is nothing to migrate, nothing to
    serialize and nothing that can grow.

    Cost is O(1) per event: one increment on a landed counter, one reset on a
    botched one. The UI reads three numbers when the window refreshes; no timer,
    no frame work and no allocation.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local S = {}
ns.Streak = S

local count = 0
local armed = false

local function tuning()
    return ns.Data.Streak or {}
end

local function threshold()
    return math.max(1, math.floor(tonumber(tuning().threshold) or 5))
end

--- Won counters in the current run of good haggling.
function S.Count()
    return count
end

--- Meter ceiling, so the UI never hardcodes the tuning value.
function S.Threshold()
    return threshold()
end

--- True while a clean deal is waiting for the next landed counter.
function S.Armed()
    return armed
end

--- Fraction the next landed counter pays over its agreed price (0 when unarmed).
function S.Bonus()
    if not armed then return 0 end
    local bonus = tonumber(tuning().perkBonus) or 0
    return math.max(0, math.min(tonumber(tuning().maxBonus) or 0.10, bonus))
end

--- Small, readable state for the UI: count, ceiling, armed and the label.
function S.Status()
    local limit = threshold()
    local label, tone
    if armed then
        label, tone = "CLEAN DEAL READY", "gold"
    elseif count >= limit - 1 then
        label, tone = "ONE MORE", "gold"
    elseif count >= math.max(1, math.floor(limit / 2)) then
        label, tone = "HOT HAND", "green"
    elseif count > 0 then
        label, tone = "WARMING UP", "muted"
    else
        label, tone = "NO STREAK", "dim"
    end
    return { count = count, limit = limit, armed = armed, label = label, tone = tone }
end

--- A counteroffer landed. Returns true when this one armed the clean deal.
function S.Hit()
    if armed then
        -- Already armed: the hand is hot but the perk is still one sale.
        return false
    end
    count = math.min(threshold(), count + 1)
    if count >= threshold() then armed = true end
    return armed
end

--- A botched counteroffer: the streak is gone, the armed perk is not. Losing a
--  hot hand should sting without also confiscating a reward already earned.
function S.Miss()
    count = 0
end

--- Spend the armed clean deal. Returns the bonus fraction, or 0 if unarmed.
--  Called once, from the landed-counter path that already completed a sale.
function S.Consume()
    if not armed then return 0 end
    local bonus = S.Bonus()
    armed = false
    count = 0
    return bonus
end

--- Diagnostics and tests only: wipe session state without touching the save.
function S.Reset()
    count = 0
    armed = false
end
