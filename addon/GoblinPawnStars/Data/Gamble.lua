--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Gamble.lua
    Tuning and voice for the desperate buyer's double-or-nothing wager.

    The wager is a real decision with a stated price on both sides, and it is
    deliberately worth slightly less than simply accepting the offer on the
    table. That is the whole point: gambling should be a tempting shortcut, not
    the correct play. The math lives in Modules/Gamble.lua; these numbers are the
    knobs.

    edge         : the wager's expected value as a fraction of the safe offer
    lossShare    : what a lost flip still pays, as a fraction of the safe offer
    maxPrizeShare: the prize never exceeds this multiple of the safe offer, which
                   keeps a huge hidden ceiling from turning the bet into free money
    minChance/maxChance: display and sanity clamps for the stated odds
    repSting     : reputation lost on a lost flip (never credits)
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...

ns.Data = ns.Data or {}
ns.Data.Gamble = {
    edge = 0.94,
    lossShare = 0.80,
    maxPrizeShare = 2.0,
    minChance = 0.12,
    maxChance = 0.55,
    repSting = 2,
}

-- Spoken when the customer opens the wager, wins it, or loses it. Only the
-- desperate archetype has its own pools in Data/Personalities.lua; these are the
-- fallback, so a new gambling archetype still has a voice on day one.
ns.Data.Gamble.lines = {
    wager = {
        "Double or nothing. My whole purse, or I take it cheap. Pick.",
        "One flip. Everything I've got or a discount. Those are the terms.",
    },
    wagerWin = {
        "…{price}. Fine. The coin has no respect for a good argument.",
        "You won. {price}, then. I'll remember this shop.",
    },
    wagerLose = {
        "Ha! {price} it is. You should see your own face.",
        "{price}. A pleasure. Do try not to gamble with your own stock.",
    },
}
