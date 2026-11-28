--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Streak.lua
    Tuning for the counter streak ("clean deal" fever). Session-only state lives
    in Modules/Streak.lua; nothing here is saved, because a streak is a mood, not
    progression.

    The perk is deliberately small and one-shot. A streak asks the player to
    haggle well several times in a row, and then pays roughly one sale in five a
    little more; it can never be banked, stacked or replayed by relogging.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...

ns.Data = ns.Data or {}
ns.Data.Streak = {
    threshold = 5,     -- won counters in a row before a clean deal is armed
    perkBonus = 0.10,  -- paid by the customer on the next landed counter
    perkRep = 2,       -- a small standing bump; the money still comes from a sale
    maxBonus = 0.10,   -- clamp, so no future tuning can stack past one clean deal
}
