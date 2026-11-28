// Refinement iteration 1, part A: gameplay data, shop, customers, encounters, schema.
const fs = require('fs');

function edit(path, pairs) {
  let text = fs.readFileSync(path, 'utf8');
  for (const pair of pairs) {
    const oldText = pair[0];
    const newText = pair[1];
    const found = text.split(oldText).length - 1;
    if (found !== 1) {
      throw new Error(path + ': expected exactly one match for ' +
        JSON.stringify(oldText.slice(0, 70)) + ', found ' + found);
    }
    text = text.split(oldText).join(newText);
  }
  fs.writeFileSync(path, text);
  console.log('edited ' + path);
}

edit('addon/GoblinPawnStars/Data/Upgrades.lua', [[
`function Data.UpgradeUnlocked(upgrade, tier)
    return upgrade and (upgrade.minTier or 1) <= (tonumber(tier) or 1)
end`,
`function Data.UpgradeUnlocked(upgrade, tier)
    return upgrade and (upgrade.minTier or 1) <= (tonumber(tier) or 1)
end

--[[ Reputation milestones ---------------------------------------------------
    Reputation used to be a number beside the shop name and a small price
    modifier, which made a lifetime of good deals feel like filling a bar. Each
    milestone now unlocks one concrete perk. The label, the perk and the
    dashboard copy all read from this table so they cannot drift apart.
--------------------------------------------------------------------------- ]]

Data.ReputationTiers = {
    {
        at = 100, name = "Known", perk = "waiting", amount = 1,
        perkText = "+1 waiting slot",
        blurb = "People know the sign. One more customer will queue for you.",
    },
    {
        at = 250, name = "Respected", perk = "rare", amount = 0.02,
        perkText = "+2% rare customers",
        blurb = "Word travels. Collectors hear there is something worth seeing.",
    },
    {
        at = 500, name = "Trusted", perk = "patience", amount = 1,
        perkText = "+1 haggling round",
        blurb = "Fair dealing earns customers one more round before they walk.",
    },
    {
        at = 800, name = "Legendary", perk = "offer", amount = 0.05,
        perkText = "+5% on every offer",
        blurb = "A living legend. Even the cautious ones pay closer to your price.",
    },
}
`,
]]);

edit('addon/GoblinPawnStars/Modules/Shop.lua', [
[`function S.RareChance()
    local tier = S.TierInfo()
    return U.clamp((tier.rareChance or 0) + (S.Bonuses().rare or 0), 0, 0.6)
end`,
`function S.RareChance()
    local tier = S.TierInfo()
    local perks = S.ReputationPerks()
    return U.clamp((tier.rareChance or 0) + (S.Bonuses().rare or 0) + (perks.rare or 0), 0, 0.6)
end`],
[`function S.WaitingSlots()
    local tier = S.TierInfo()
    local base = 2 + math.floor((tier.tier - 1) / 2)
    return math.max(2, math.floor(base + (S.Bonuses().waiting or 0) + 0.001))
end`,
`function S.WaitingSlots()
    local tier = S.TierInfo()
    local base = 2 + math.floor((tier.tier - 1) / 2)
    local perks = S.ReputationPerks()
    return math.max(2, math.floor(base + (S.Bonuses().waiting or 0) + (perks.waiting or 0) + 0.001))
end`],
[`function S.ReputationLabel()
    local rep = S.Reputation()
    if rep >= 800 then return "Legendary", "|cffff8000" end
    if rep >= 500 then return "Trusted", "|cffa335ee" end
    if rep >= 250 then return "Respected", "|cff0070dd" end
    if rep >= 100 then return "Known", "|cff1eff00" end
    return "Nobody", "|cff9d9d9d"
end`,
`local REPUTATION_COLORS = {
    Known = "|cff1eff00",
    Respected = "|cff0070dd",
    Trusted = "|cffa335ee",
    Legendary = "|cffff8000",
}

-- The highest milestone the shop has reached, or nil below the first one.
function S.ReputationTier()
    local rep = S.Reputation()
    local reached
    for _, def in ipairs(ns.Data.ReputationTiers or {}) do
        if rep >= (def.at or 0) then reached = def end
    end
    return reached
end

-- The next milestone still to earn, used by the dashboard and the tooltip.
function S.NextReputationTier()
    local rep = S.Reputation()
    for _, def in ipairs(ns.Data.ReputationTiers or {}) do
        if rep < (def.at or 0) then return def end
    end
end

-- Perks are cumulative: reaching Legendary keeps every earlier one.
function S.ReputationPerks()
    local perks = { waiting = 0, rare = 0, patience = 0, offer = 0, count = 0 }
    local rep = S.Reputation()
    for _, def in ipairs(ns.Data.ReputationTiers or {}) do
        if rep >= (def.at or 0) then
            perks.count = perks.count + 1
            local key = def.perk
            if key then perks[key] = (perks[key] or 0) + (def.amount or 0) end
        end
    end
    return perks
end

function S.ReputationLabel()
    local def = S.ReputationTier()
    if not def then return "Nobody", "|cff9d9d9d" end
    return def.name, REPUTATION_COLORS[def.name] or "|cff9d9d9d"
end`],
]);

edit('addon/GoblinPawnStars/Modules/Customers.lua', [
[`    local willingness = personality.maxWill * repFactor * offerBonus * U.randomBetween(0.94, 1.08)`,
`    local repPerks = ns.Shop.ReputationPerks()
    local willingness = personality.maxWill * repFactor * offerBonus * U.randomBetween(0.94, 1.08)
        * (1 + (repPerks.offer or 0))`],
[`    local patience = (personality.patience or 2) + math.floor(bonuses.patience or 0)`,
`    local patience = (personality.patience or 2)
        + math.floor((bonuses.patience or 0) + (repPerks.patience or 0))`],
]);

edit('addon/GoblinPawnStars/Data/Encounters.lua', [[
`Data.EncounterByKey = {}
for _, encounter in ipairs(Data.Encounters) do
    Data.EncounterByKey[encounter.key] = encounter
end

function Data.EncounterPick(tier)
    local pool = {}
    for _, encounter in ipairs(Data.Encounters) do
        if (encounter.minTier or 1) <= (tier or 1) then
            pool[#pool + 1] = encounter
        end
    end
    return ns.Util.weightedPick(pool, function(entry) return entry.weight or 1 end)
end`,
`Data.EncounterByKey = {}
Data.EncounterIndex = {}
for index, encounter in ipairs(Data.Encounters) do
    Data.EncounterByKey[encounter.key] = encounter
    Data.EncounterIndex[encounter.key] = index
end

--[[ Picking an event --------------------------------------------------------
    \`recent\` holds the indices of the last couple of events, newest first. They
    are skipped so the same event cannot fire twice in a row, or alternate
    A-B-A all evening, which is what makes a random table feel broken. The
    filter is dropped when it would leave fewer than three candidates: a young
    shop has a short eligible list and variety matters more than the rule.
--------------------------------------------------------------------------- ]]
function Data.EncounterPick(tier, recent)
    local pool = {}
    for index, encounter in ipairs(Data.Encounters) do
        if (encounter.minTier or 1) <= (tier or 1) then
            pool[#pool + 1] = { def = encounter, index = index }
        end
    end
    if #pool == 0 then return nil end

    if type(recent) == "table" and #recent > 0 and #pool > 3 then
        local blocked = {}
        for _, index in ipairs(recent) do blocked[tonumber(index) or -1] = true end
        local remaining = {}
        for _, entry in ipairs(pool) do
            if not blocked[entry.index] then remaining[#remaining + 1] = entry end
        end
        if #remaining >= 3 then pool = remaining end
    end

    local picked = ns.Util.weightedPick(pool, function(entry) return entry.def.weight or 1 end)
    return picked and picked.def or nil
end`
]]);

edit('addon/GoblinPawnStars/Modules/Encounters.lua', [
[`local ROLL_INTERVAL = 170
local ROLL_CHANCE = 0.38
`,
`local ROLL_INTERVAL = 170
local ROLL_CHANCE = 0.38

-- Two remembered events are enough to break both A-A and A-B-A repeats, and
-- two small numbers cost almost nothing in a journal payload that is measured
-- in characters.
local MAX_RECENT = 2
`],
[`function E.Pending()`,
`-- Recently seen event indices, newest first. Stored in the save so a relog
-- does not immediately repeat the event the player just dismissed.
function E.Recent()
    local db = DB.Get()
    local list = db.shop.encounterRecent
    if type(list) ~= "table" then
        list = {}
        db.shop.encounterRecent = list
    end
    return list
end

function E.Remember(index)
    index = tonumber(index)
    if not index then return end
    local list = E.Recent()
    for position = #list, 1, -1 do
        if list[position] == index then table.remove(list, position) end
    end
    table.insert(list, 1, index)
    while #list > MAX_RECENT do table.remove(list) end
end

function E.Pending()`],
[`    if db.shop.encounter then return nil end
    local def = key and ns.Data.EncounterByKey[key] or ns.Data.EncounterPick(db.tier)
    if not def then return nil end`,
`    if db.shop.encounter then return nil end
    local def = key and ns.Data.EncounterByKey[key] or ns.Data.EncounterPick(db.tier, E.Recent())
    if not def then return nil end`],
[`    db.shop.encounter = event
    db.shop.encounterResult = nil
    if ns.UI and ns.UI.ShowEncounter then ns.UI.ShowEncounter() end`,
`    db.shop.encounter = event
    db.shop.encounterResult = nil
    -- Remember the event that actually happened, not the one that was drawn: a
    -- draw with nothing to build from falls back to a different event.
    E.Remember(ns.Data.EncounterIndex[event.key or def.key])
    if ns.UI and ns.UI.ShowEncounter then ns.UI.ShowEncounter() end`],
]);

edit('addon/GoblinPawnStars/Core/Persist.lua', [
[`            shopDayProgress = 0,
            wholesale = {`,
`            shopDayProgress = 0,
            encounterRecent = {},
            wholesale = {`],
[`    if type(db.shop.wholesale) ~= "table" then db.shop.wholesale = { lots = {}, nextRestock = 0, restocks = 0 } end`,
`    local recent = db.shop.encounterRecent
    local cleanRecent = {}
    if type(recent) == "table" then
        for _, index in ipairs(recent) do
            index = tonumber(index)
            if index and index >= 1 and #cleanRecent < 2 then
                cleanRecent[#cleanRecent + 1] = math.floor(index)
            end
        end
    end
    db.shop.encounterRecent = cleanRecent
    if type(db.shop.wholesale) ~= "table" then db.shop.wholesale = { lots = {}, nextRestock = 0, restocks = 0 } end`],
]);

console.log('refinement 1 part A applied');
