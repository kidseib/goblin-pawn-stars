--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Upgrades.lua
    Shop tiers and the one-off upgrades that improve storage, traffic, appraisal,
    haggling, security, staff capacity and rare-customer luck.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local Data = ns.Data

Data.Tiers = {
    {
        tier = 1,
        name = "Roadside Trading Stall",
        blurb = "A plank, a stolen awning and a sack of other people's regrets.",
        cost = 0,
        storage = 12,
        arrival = 20,
        budget = 280,
        appraisal = 25,
        employees = 0,
        rareChance = 0.02,
        reputation = 0,
    },
    {
        tier = 2,
        name = "Goblin Pawnshop",
        blurb = "A real door, real shelves and the first forged receipt.",
        cost = 1200,
        storage = 24,
        arrival = 17,
        budget = 540,
        appraisal = 45,
        employees = 1,
        rareChance = 0.06,
        reputation = 5,
    },
    {
        tier = 3,
        name = "Established Trading Post",
        blurb = "Regulars, a kettle, and a back room with a suspicious lock.",
        cost = 5000,
        storage = 44,
        arrival = 14,
        budget = 1150,
        appraisal = 65,
        employees = 2,
        rareChance = 0.10,
        reputation = 12,
    },
    {
        tier = 4,
        name = "Luxury Auction House",
        blurb = "Velvet ropes, glass cases, and prices that make people gasp.",
        cost = 32000,
        storage = 72,
        arrival = 12,
        budget = 2500,
        appraisal = 82,
        employees = 4,
        rareChance = 0.15,
        reputation = 20,
    },
    {
        tier = 5,
        name = "Azeroth Trading Empire",
        blurb = "Three cities, two continents, one very nervous accountant.",
        cost = 150000,
        storage = 120,
        arrival = 10,
        budget = 5400,
        appraisal = 95,
        employees = 6,
        rareChance = 0.22,
        reputation = 32,
    },
}

function Data.Tier(tier)
    return Data.Tiers[ns.Util.clamp(tonumber(tier) or 1, 1, #Data.Tiers)]
end

function Data.NextTier(tier)
    return Data.Tiers[(tonumber(tier) or 1) + 1]
end

--[[ Upgrades ---------------------------------------------------------------
    Each level adds `fx` on top of the previous. Costs grow with the level.
--------------------------------------------------------------------------- ]]

Data.Upgrades = {
    {
        key = "shelves",
        name = "Secondhand Shelves",
        description = "More shelves, more junk, more fortune.",
        icon = "Interface\\Icons\\INV_Misc_Bag_08",
        minTier = 1, maxLevel = 6,
        baseCost = 260, costGrowth = 1.85,
        fx = { storage = 6 },
        fxText = "+6 storage",
    },
    {
        key = "display_case",
        name = "Glass Display Case",
        description = "Makes a rusty fork look like a museum piece.",
        icon = "Interface\\Icons\\INV_Box_01",
        minTier = 2, maxLevel = 3,
        baseCost = 750, costGrowth = 1.9,
        fx = { appraisal = 6, offer = 0.02 },
        fxText = "+6 appraisal, +2% offers",
    },
    {
        key = "haggling_manual",
        name = "Goblin Book of Haggling",
        description = "Chapter one: never accept the first offer. Chapter two: never stop.",
        icon = "Interface\\Icons\\INV_Scroll_05",
        minTier = 1, maxLevel = 4,
        baseCost = 420, costGrowth = 1.8,
        fx = { haggle = 0.05 },
        fxText = "+5% successful counteroffers",
    },
    {
        key = "sign",
        name = "Painted Shop Sign",
        description = "Loud, gaudy and visible from the zeppelin tower.",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        minTier = 1, maxLevel = 4,
        baseCost = 300, costGrowth = 1.75,
        fx = { arrival = 8, waiting = 0.25 },
        fxText = "-8s between customers",
    },
    {
        key = "security",
        name = "Iron Bars and a Mean Dog",
        description = "The dog is mostly decorative. Mostly.",
        icon = "Interface\\Icons\\INV_Misc_Bone_01",
        minTier = 2, maxLevel = 3,
        baseCost = 900, costGrowth = 1.9,
        fx = { theft = 0.2 },
        fxText = "-20% theft chance",
    },
    {
        key = "ledger",
        name = "Honest Ledger",
        description = "Reduces 'miscellaneous expenses' by an accounting miracle.",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        minTier = 2, maxLevel = 3,
        baseCost = 800, costGrowth = 1.85,
        fx = { expense = 0.10 },
        fxText = "-10% operating expenses",
    },
    {
        key = "lounge",
        name = "Customer Lounge",
        description = "A bench, a rug and a kettle. Customers will wait longer.",
        icon = "Interface\\Icons\\INV_Misc_Drink_01",
        minTier = 2, maxLevel = 3,
        baseCost = 1100, costGrowth = 1.9,
        fx = { waiting = 1, patience = 0.5 },
        fxText = "+1 waiting slot",
    },
    {
        key = "lens",
        name = "Appraiser's Loupe",
        description = "Reveals hallmarks, forgeries and the occasional curse.",
        icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
        minTier = 2, maxLevel = 3,
        baseCost = 1300, costGrowth = 1.9,
        fx = { appraisal = 8, forgery = 0.15 },
        fxText = "+8 appraisal, better forgery detection",
    },
    {
        key = "plaque",
        name = "Reputation Plaques",
        description = "Framed letters from people who almost paid on time.",
        icon = "Interface\\Icons\\INV_Misc_Scroll_04",
        minTier = 3, maxLevel = 2,
        baseCost = 2600, costGrowth = 2.0,
        fx = { repGain = 0.2, offer = 0.02 },
        fxText = "+20% reputation gain, +2% offers",
    },
    {
        key = "auction_license",
        name = "Auction License",
        description = "Legally distinct from a cartel. Mostly.",
        icon = "Interface\\Icons\\INV_Scroll_11",
        minTier = 4, maxLevel = 1,
        baseCost = 9000, costGrowth = 1.0,
        fx = { arrival = 6, rare = 0.03 },
        fxText = "-6s between customers, rare customers more common",
    },
    {
        key = "blimp",
        name = "Advertising Blimp",
        description = "A slow, noisy, extremely effective floating billboard.",
        icon = "Interface\\Icons\\INV_Misc_EngGizmos_19",
        minTier = 5, maxLevel = 1,
        baseCost = 42000, costGrowth = 1.0,
        fx = { arrival = 12, rare = 0.06, waiting = 1 },
        fxText = "-12s between customers, +rare customers, +1 waiting slot",
    },
}

Data.UpgradeByKey = {}
for _, upgrade in ipairs(Data.Upgrades) do
    Data.UpgradeByKey[upgrade.key] = upgrade
end

function Data.UpgradeCost(upgrade, currentLevel)
    if not upgrade then return math.huge end
    currentLevel = math.max(0, tonumber(currentLevel) or 0)
    return math.floor(upgrade.baseCost * (upgrade.costGrowth ^ currentLevel))
end

function Data.UpgradeUnlocked(upgrade, tier)
    return upgrade and (upgrade.minTier or 1) <= (tonumber(tier) or 1)
end
