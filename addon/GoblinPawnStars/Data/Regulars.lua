--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Regulars.lua
    Tuning for returning customers. A good sale is remembered, and that person
    can walk back in later with their own name, their own archetype and a little
    more patience than a stranger. Numbers only: the behaviour lives in
    Modules/Regulars.lua.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...

local R = {
    max = 3,             -- how many faces the shop can remember
    chance = 0.10,       -- baseline chance a free arrival is a remembered customer
    chancePerVisit = 0.03, -- each repeat visit makes the next one likelier
    maxChance = 0.30,    -- a ceiling, so the door never becomes a private club
    goodRatio = 0.80,    -- share of their ceiling that counts as a good sale
    patienceAt = 2,      -- visits before they wait one extra round
    offerAt = 4,         -- visits before they pay the loyalty premium
    offerBump = 0.05,    -- premium is small and only ever lifts a real sale
}

ns.Data = ns.Data or {}
ns.Data.Regulars = R
