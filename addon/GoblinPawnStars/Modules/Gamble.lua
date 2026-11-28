--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Gamble.lua
    The desperate buyer's double-or-nothing wager.

    One customer archetype (Data flag `gamble = true`) can put a flip on the
    table: win and they pay the most they were ever going to pay; lose and they
    pay a discount and the shop's name takes a small knock. The player decides
    whether to take it, so it has to be honest about the odds and it has to be
    slightly worse than simply accepting.

    Expected value, by construction:
        prize  = min(ceiling, maxPrizeShare * offer)
        loss   = lossShare * offer
        chance = (edge - lossShare) * offer / (prize - lossShare * offer)
    so  chance * prize + (1 - chance) * loss = edge * offer  (about 94% of the
    safe offer) whenever the chance sits inside its clamps. Clamping can only
    move the value further below the safe offer, never above it.

    Nothing here writes to the database or completes a sale: this module only
    states terms and rolls once. Modules/Negotiation.lua owns the sale, so a
    wager is paid by a real customer for a real virtual unit like every other
    sale, and a lost wager never removes gold that was not already on the table.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local G = {}
ns.Gamble = G

local function tuning()
    return (ns.Data and ns.Data.Gamble) or {}
end

--- Personality data, if the archetype is allowed to gamble at all.
function G.Allowed(customerOrPersonality)
    if type(customerOrPersonality) ~= "table" then return nil end
    local personality = customerOrPersonality
    if customerOrPersonality.personality then
        personality = ns.Data.PersonalityByKey[customerOrPersonality.personality]
    end
    if personality and personality.gamble then return personality end
    return nil
end

--- The wager on the table for this customer, or nil when there is none.
--  O(1): a handful of arithmetic on two numbers the customer record already has.
function G.Terms(customer)
    if type(customer) ~= "table" then return nil end
    if not G.Allowed(customer) then return nil end
    -- One wager per customer. The flag rides on the customer record, which the
    -- save already carries, so a reload cannot reroll a lost flip.
    if customer.gambled then return nil end

    local offer = math.floor(tonumber(customer.offer) or 0)
    local ceiling = math.floor(tonumber(customer.maxPay) or 0)
    if offer <= 0 or ceiling <= offer then return nil end

    local config = tuning()
    local edge = U.clamp(tonumber(config.edge) or 0.94, 0.5, 0.99)
    local lossShare = U.clamp(tonumber(config.lossShare) or 0.80, 0.25, edge - 0.005)
    local prize = math.min(ceiling,
        math.floor(offer * (tonumber(config.maxPrizeShare) or 2.0)))
    prize = math.max(prize, offer + 1)
    local loss = math.max(1, math.floor(offer * lossShare))

    local span = prize - lossShare * offer
    if span <= 0 then return nil end
    local chance = ((edge - lossShare) * offer) / span
    chance = U.clamp(chance,
        tonumber(config.minChance) or 0.12, tonumber(config.maxChance) or 0.55)

    return {
        chance = chance,
        percent = math.floor(chance * 100 + 0.5),
        prize = prize,
        loss = loss,
        offer = offer,
        ceiling = ceiling,
        sting = math.max(0, math.floor(tonumber(config.repSting) or 2)),
    }
end

--- Expected credits from the wager, for the tests and the design notes.
function G.Value(terms)
    if type(terms) ~= "table" then return 0 end
    return terms.chance * terms.prize + (1 - terms.chance) * terms.loss
end

--- One roll. The caller is responsible for paying the result.
function G.Roll(terms)
    if type(terms) ~= "table" then return false end
    return U.chance(terms.chance) and true or false
end

--- The customer's line for a wager beat, with the archetype's own pool first.
function G.Say(personality, key, vars)
    local line = ns.Data.PersonalityLine(personality, key, vars)
    if line ~= "" then return line end
    local pool = (tuning().lines or {})[key]
    if type(pool) == "table" and #pool > 0 then
        return U.fill(pool[math.random(#pool)], vars or {})
    end
    return ""
end
