--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/MarketEvents.lua
    Temporary demand shocks. Durations and cooldowns are measured in seconds of
    actual playtime so logging out pauses the market instead of draining it.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local Data = ns.Data

Data.MarketEvents = {
    {
        key = "war_effort",
        name = "War Effort",
        description = "Recruiters are buying every blade in sight. Weapon demand surges.",
        icon = "Interface\\Icons\\INV_Sword_04",
        weight = 14, minTier = 1,
        duration = { 420, 780 },
        effect = { weapon = 1.32 },
    },
    {
        key = "alchemist_convention",
        name = "Alchemist Convention",
        description = "Three hundred alchemists, no potions, one very good week for you.",
        icon = "Interface\\Icons\\INV_Potion_51",
        weight = 13, minTier = 1,
        duration = { 360, 720 },
        effect = { consumable = 1.38, herb = 1.18 },
    },
    {
        key = "mining_shortage",
        name = "Mining Shortage",
        description = "A cave-in upstream. Ore and bars are suddenly worth arguing over.",
        icon = "Interface\\Icons\\INV_Ore_Mithril_01",
        weight = 13, minTier = 1,
        duration = { 420, 780 },
        effect = { ore = 1.34 },
    },
    {
        key = "goblin_market_crash",
        name = "Goblin Market Crash",
        description = "A cartel sneezed. Luxury goods are worthless until the panic passes.",
        icon = "Interface\\Icons\\INV_Misc_Coin_07",
        weight = 10, minTier = 1,
        duration = { 300, 600 },
        effect = { gem = 0.76, pet = 0.78, misc = 0.84, recipe = 0.88 },
    },
    {
        key = "collectors_festival",
        name = "Collector's Festival",
        description = "Collectors descend on the city with deep pockets and deeper opinions.",
        icon = "Interface\\Icons\\INV_Misc_Gem_03",
        weight = 11, minTier = 2,
        duration = { 480, 840 },
        effect = { gem = 1.28, misc = 1.18, pet = 1.16, recipe = 1.12 },
    },
    {
        key = "tailoring_boom",
        name = "Tailoring Boom",
        description = "Everyone wants a new robe for the season. Cloth is gold.",
        icon = "Interface\\Icons\\INV_Fabric_Linen_01",
        weight = 10, minTier = 1,
        duration = { 360, 660 },
        effect = { cloth = 1.30 },
    },
    {
        key = "leather_shortage",
        name = "Leather Shortage",
        description = "A beast plague thinned the herds. Tanners are paying premiums.",
        icon = "Interface\\Icons\\INV_Misc_LeatherScrap_05",
        weight = 10, minTier = 1,
        duration = { 360, 700 },
        effect = { leather = 1.30 },
    },
    {
        key = "enchanting_fad",
        name = "Enchanting Fad",
        description = "Every adventurer wants a glowing weapon. Dust and shards fly off shelves.",
        icon = "Interface\\Icons\\INV_Enchant_DustArcane",
        weight = 9, minTier = 2,
        duration = { 360, 720 },
        effect = { enchant = 1.26 },
    },
    {
        key = "recipe_boom",
        name = "Guild Recipe Rush",
        description = "Raiders are hoarding plans. Recipes are suddenly collectible.",
        icon = "Interface\\Icons\\INV_Scroll_03",
        weight = 8, minTier = 2,
        duration = { 420, 780 },
        effect = { recipe = 1.30 },
    },
    {
        key = "auction_frenzy",
        name = "Auction Frenzy",
        description = "A visiting magnate is buying anything with a price tag. Everything rises.",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        weight = 5, minTier = 3,
        duration = { 240, 480 },
        effect = {
            weapon = 1.12, armor = 1.12, ore = 1.12, herb = 1.12, leather = 1.12,
            cloth = 1.12, gem = 1.12, enchant = 1.12, consumable = 1.12,
            recipe = 1.12, misc = 1.12, pet = 1.12,
        },
    },
    {
        key = "harvest_festival",
        name = "Harvest Festival",
        description = "Herbs, brews and remedies sell as fast as they are stocked.",
        icon = "Interface\\Icons\\INV_Misc_Herb_02",
        weight = 9, minTier = 1,
        duration = { 420, 720 },
        effect = { herb = 1.28, consumable = 1.14 },
    },
}

Data.MarketEventByKey = {}
for _, event in ipairs(Data.MarketEvents) do
    Data.MarketEventByKey[event.key] = event
end

function Data.MarketEventPick(tier)
    local pool = {}
    for _, event in ipairs(Data.MarketEvents) do
        if (event.minTier or 1) <= (tier or 1) then
            pool[#pool + 1] = event
        end
    end
    return ns.Util.weightedPick(pool, function(entry) return entry.weight or 1 end)
end
