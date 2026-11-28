--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Regulars.lua
    Tuning for returning customers. A good sale is remembered, and that person
    can walk back in later with their own name, their own archetype and a little
    more patience than a stranger. A regular can also ask for a specific shelf
    of goods: a special order with a budget and a deadline.

    Numbers only: the behaviour lives in Modules/Regulars.lua.
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

    -- Special orders ---------------------------------------------------------
    orderChance = 0.50,  -- chance a visited regular asks for something specific
    orderMinVisits = 1,  -- one remembered sale is enough to be asked for stock
    orderDays = 2,       -- shop days (15 min each) to find the goods before it lapses
    sourDays = 2,        -- shop days a lapse keeps them quiet
    maxOrders = 3,       -- bounded save state, one per regular at most
    orderPay = 1.35,     -- what they will pay over live market value
    orderBudget = 2.6,   -- implied budget as a multiple of the tier budget
    orderRep = 8,        -- reputation for delivering
    orderVisitBonus = 1, -- extra remembered visits on top of the sale itself
    patronAt = 2,        -- delivered orders before they become a patron
    patronOffer = 1.04,  -- permanent offer lift on everything once a patron
    -- A patron is a relationship, not a badge: their orders are larger, they
    -- give the shop one more day to source them, they pay more for the shelf
    -- they asked for, and delivering to them is worth more standing. All of it
    -- runs through a completed sale, so none of it mints credits.
    patronPay = 1.50,    -- what a patron pays over live market value for an order
    patronBudget = 3.2,  -- their implied budget, as a multiple of the tier budget
    patronDays = 1,      -- extra shop days on a patron's order
    patronRep = 12,      -- reputation for delivering to a patron
    patronVisitBonus = 2, -- extra remembered visits for a patron delivery
    patronWeight = 1.5,  -- a patron takes more of the arrivals than a regular
    patronOrderChance = 0.75, -- and is likelier to bring a request when they do
    lapseRep = -4,       -- cost of letting an order go cold
    orderArrivalBoost = 0.15, -- extra arrival weight while the shop can fill it
    orderReturnChance = 0.55, -- chance a fillable order claims the next arrival
    orderMaxChance = 0.55,    -- ceiling while an order can actually be filled
}

ns.Data = ns.Data or {}
ns.Data.Regulars = R
