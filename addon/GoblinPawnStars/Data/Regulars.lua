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
    patronOffer = 1.02,  -- permanent offer lift once they are a patron
    lapseRep = -4,       -- cost of letting an order go cold
    orderArrivalBoost = 0.15, -- extra arrival weight while the shop can fill it
    orderReturnChance = 0.55, -- chance a fillable order claims the next arrival
    orderMaxChance = 0.55,    -- ceiling while an order can actually be filled
}

ns.Data = ns.Data or {}
ns.Data.Regulars = R
