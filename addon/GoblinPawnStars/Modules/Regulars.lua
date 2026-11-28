--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Regulars.lua
    Customers with a memory. Iteration 2 gave every archetype a voice; this is
    what gives the shop a cast. A sale that met the customer's own ceiling is
    remembered in `db.shop.regulars` (name, archetype, visit count) and that
    person can take an ordinary arrival later, keeping their identity and
    earning one extra haggling round, then a small loyalty premium.

    Nothing here creates credits: the premium only raises what a returning
    customer will pay for stock, and every visit still ends in a normal sale.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local DB = ns.DB
local U = ns.Util
local R = {}
ns.Regulars = R

local function def()
    return ns.Data.Regulars
end

local function memory()
    local db = DB.Get()
    if type(db.shop.regulars) ~= "table" then db.shop.regulars = {} end
    return db.shop.regulars
end

function R.List()
    return memory()
end

--- Loyalty for a returning customer, as pure numbers so it can be tested and
--- tuned in one place.
function R.Loyalty(visits)
    local data = def()
    visits = math.max(0, math.floor(tonumber(visits) or 0))
    local patience = 0
    if visits >= (data.patienceAt or 2) then patience = 1 end
    local offer = 1
    if visits >= (data.offerAt or 3) then offer = 1 + (data.offerBump or 0.05) end
    return patience, offer
end

--- Remembers one completed sale. Called only from Negotiation.completeSale, so
--- there is no way to become a regular without buying something.
function R.Remember(customer, price)
    local data = def()
    if type(customer) ~= "table" or type(customer.name) ~= "string" or customer.name == "" then
        return nil
    end
    local ceiling = tonumber(customer.maxPay) or 0
    local paid = tonumber(price) or 0
    -- A haggled-down sale does not buy goodwill; a sale near their own ceiling
    -- does. maxPay is the hidden limit, so this asks "did they leave happy?"
    if ceiling <= 0 or paid / ceiling < (data.goodRatio or 0.78) then return nil end

    local list = memory()
    local entry
    for _, candidate in ipairs(list) do
        if candidate.name == customer.name and candidate.personality == customer.personality then
            entry = candidate
            break
        end
    end

    if entry then
        entry.visits = math.min(99, (tonumber(entry.visits) or 1) + 1)
        entry.lastAt = U.now()
    else
        entry = {
            name = customer.name,
            personality = customer.personality,
            race = customer.race,
            class = customer.class,
            occupation = customer.occupation,
            visits = 1,
            lastAt = U.now(),
        }
        list[#list + 1] = entry
    end

    -- Bounded: forget the face that has come least often (the oldest on a tie).
    while #list > (data.max or 3) do
        local worst = 1
        for index = 2, #list do
            if (tonumber(list[index].visits) or 0) < (tonumber(list[worst].visits) or 0) then
                worst = index
            end
        end
        table.remove(list, worst)
    end

    return entry
end

--- Options for an ordinary arrival, or nil. Uses the same weighted-pick shape as
--- the rest of the addon and adds no timers: it is consulted only when the shop
--- was already going to spawn somebody.
function R.SpawnOptions()
    local data = def()
    local list = memory()
    if #list == 0 then return nil end

    -- Weight grows with visits but sub-linearly, so one very familiar face
    -- cannot take most of the arrivals away from the other two.
    local best, total = 0, 0
    for _, entry in ipairs(list) do
        local visits = math.max(1, tonumber(entry.visits) or 1)
        best = math.max(best, visits)
        total = total + 1 + (visits - 1) * 0.5
    end

    local chance = (data.chance or 0.14) + (best - 1) * (data.chancePerVisit or 0.04)
    if ns.Regular and ns.Regular.Unlocked and ns.Regular.Unlocked() then chance = chance + 0.06 end
    chance = U.clamp(chance, 0, data.maxChance or 0.42)
    if not U.chance(chance) then return nil end

    -- Weighted by visits: the people who like the shop come back most often.
    local roll = U.randomBetween(1, total)
    local pick = list[#list]
    for _, entry in ipairs(list) do
        local visits = math.max(1, tonumber(entry.visits) or 1)
        roll = roll - (1 + (visits - 1) * 0.5)
        if roll <= 0 then
            pick = entry
            break
        end
    end

    return {
        name = pick.name,
        race = pick.race,
        class = pick.class,
        occupation = pick.occupation,
        personality = pick.personality,
        returning = math.max(1, tonumber(pick.visits) or 1),
    }
end
