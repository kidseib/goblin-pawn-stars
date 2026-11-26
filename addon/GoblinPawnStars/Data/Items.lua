--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Items.lua
    Item categories, acquisition eligibility and the fictional valuation model.
    Real WoW item names, icons, quality and item level are used; values are
    invented Goblin Credits, never anything tied to the player's real gold.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local Data = ns.Data or {}
ns.Data = Data

---------------------------------------------------------------------------
-- Categories
---------------------------------------------------------------------------

Data.Categories = {
    { key = "weapon", name = "Weapons", icon = "Interface\\Icons\\INV_Sword_04" },
    { key = "armor", name = "Armor", icon = "Interface\\Icons\\INV_Chest_Chain_04" },
    { key = "ore", name = "Ore & Bars", icon = "Interface\\Icons\\INV_Ore_Copper_01" },
    { key = "herb", name = "Herbs", icon = "Interface\\Icons\\INV_Misc_Herb_07" },
    { key = "leather", name = "Leather & Hides", icon = "Interface\\Icons\\INV_Misc_LeatherScrap_03" },
    { key = "cloth", name = "Cloth", icon = "Interface\\Icons\\INV_Fabric_Linen_01" },
    { key = "gem", name = "Gems", icon = "Interface\\Icons\\INV_Misc_Gem_01" },
    { key = "enchant", name = "Enchanting", icon = "Interface\\Icons\\INV_Enchant_DustArcane" },
    { key = "consumable", name = "Potions & Consumables", icon = "Interface\\Icons\\INV_Potion_51" },
    { key = "recipe", name = "Recipes & Plans", icon = "Interface\\Icons\\INV_Scroll_03" },
    { key = "misc", name = "Curiosities", icon = "Interface\\Icons\\INV_Misc_Bag_10" },
    { key = "pet", name = "Companions & Mounts", icon = "Interface\\Icons\\INV_Misc_Egg_02" },
}

Data.CategoryNames = {}
for _, category in ipairs(Data.Categories) do
    Data.CategoryNames[category.key] = category.name
end

function Data.CategoryName(key)
    return Data.CategoryNames[key] or "Curiosities"
end

-- Rough value weight per category. Crafting staples are cheap in bulk, gems,
-- weapons and companions carry a premium.
local CATEGORY_VALUE = {
    weapon = 1.20,
    armor = 1.05,
    ore = 0.95,
    herb = 0.85,
    leather = 0.90,
    cloth = 0.80,
    gem = 1.35,
    enchant = 1.10,
    consumable = 0.60,
    recipe = 0.75,
    misc = 1.00,
    pet = 2.60,
}

local QUALITY_MULT = {
    [0] = 0.45,
    [1] = 1.00,
    [2] = 2.10,
    [3] = 5.20,
    [4] = 15.00,
    [5] = 48.00,
    [6] = 95.00,
    [7] = 7.00,
}

-- Trade goods subclasses (Retail enum values, used only as a hint).
local TRADE_SUBCLASS = {
    [4] = "gem",      -- Jewelcrafting
    [5] = "cloth",
    [6] = "leather",
    [7] = "ore",      -- Metal & Stone
    [9] = "herb",
    [10] = "enchant",
    [11] = "misc",    -- Elemental
}

local MISC_SUBCLASS = {
    [2] = "pet",   -- Companion pets
    [5] = "pet",   -- Mounts
}

-- Fallbacks keyed by the localized type/subtype names returned at positions 6/7
-- of C_Item.GetItemInfo. Numeric class IDs are authoritative; these cover builds
-- or cached rows that omit the numeric tail.
local TYPE_NAME_CATEGORY = {
    ["Weapon"] = "weapon",
    ["Armor"] = "armor",
    ["Gem"] = "gem",
    ["Consumable"] = "consumable",
    ["Recipe"] = "recipe",
    ["Miscellaneous"] = "misc",
    ["Battlepet"] = "pet",
    ["Pet"] = "pet",
    ["Tradeskill"] = "tradegoods",
    ["Trade Goods"] = "tradegoods",
}

local SUBTYPE_NAME_CATEGORY = {
    ["Cloth"] = "cloth",
    ["Leather"] = "leather",
    ["Metal & Stone"] = "ore",
    ["Ore"] = "ore",
    ["Herb"] = "herb",
    ["Enchanting"] = "enchant",
    ["Jewelcrafting"] = "gem",
    ["Cooking"] = "consumable",
    ["Companion Pets"] = "pet",
    ["Mounts"] = "pet",
    ["Holiday"] = "misc",
}

function Data.CategoryOf(info)
    if not info then return "misc" end
    local classID = tonumber(info.classID) or 0
    local subclassID = tonumber(info.subclassID) or 0

    if classID == 2 then return "weapon" end
    if classID == 4 then return "armor" end
    if classID == 3 then return "gem" end
    if classID == 7 then return TRADE_SUBCLASS[subclassID] or "misc" end
    if classID == 9 then return "recipe" end
    if classID == 16 then return "enchant" end
    if classID == 0 then return "consumable" end
    if classID == 15 then return MISC_SUBCLASS[subclassID] or "misc" end
    if classID == 17 then return "pet" end

    local subtype = info.subTypeName
    if subtype and SUBTYPE_NAME_CATEGORY[subtype] then
        return SUBTYPE_NAME_CATEGORY[subtype]
    end

    local typeName = info.typeName
    if typeName then
        local category = TYPE_NAME_CATEGORY[typeName]
        if category == "tradegoods" then return "misc" end
        if category then return category end
    end

    return "misc"
end

---------------------------------------------------------------------------
-- Eligibility
---------------------------------------------------------------------------

-- Item classes we never turn into pawnshop stock: quest items, keys and
-- anything the player cannot freely hand over.
local EXCLUDED_CLASSES = {
    [12] = true, -- Quest
    [13] = true, -- Key
}

function Data.IsEligible(info)
    if not info or not info.name then return false, "unknown item" end
    local classID = tonumber(info.classID) or 0
    if EXCLUDED_CLASSES[classID] then return false, "quest or key item" end
    if classID == 18 then return false, "reagent bag plumbing" end
    if info.typeName == "Quest" or info.typeName == "Quest Item" then
        return false, "quest item"
    end
    if info.typeName == "Key" then return false, "key item" end
    local quality = tonumber(info.quality) or 0
    if quality < 1 then return false, "grey junk" end
    if info.ilvl and info.ilvl <= 0 and classID ~= 15 then return false, "no item level" end
    if type(info.name) == "string" and info.name:find("Conjured", 1, true) then
        return false, "conjured"
    end
    return true
end

---------------------------------------------------------------------------
-- Valuation
---------------------------------------------------------------------------

function Data.QualityMultiplier(quality)
    return QUALITY_MULT[tonumber(quality) or 1] or 1.0
end

function Data.CategoryMultiplier(category)
    return CATEGORY_VALUE[category] or 1.0
end

-- Deterministic per-item "character": the same sword is always worth the same
-- base amount, which keeps appraisals trustworthy between sessions.
function Data.BaseValue(info)
    if not info then return 1 end
    local quality = tonumber(info.quality) or 1
    local itemLevel = math.max(1, tonumber(info.ilvl) or 1)
    local category = Data.CategoryOf(info)
    local seed = tostring(info.id or info.name or "?")
    local jitter = 0.86 + (U.hash(seed) % 29) / 100 -- 0.86 .. 1.14
    local base = (10 + itemLevel * 2.2) * Data.QualityMultiplier(quality)
    base = base * Data.CategoryMultiplier(category) * jitter
    return math.max(6, U.floor(U.round(base)))
end

-- A stack is worth slightly less per unit than a single piece, which stops
-- "stack flipping" from being the best strategy in the game.
function Data.StackValue(record)
    local value = tonumber(record and record.value) or 1
    local count = tonumber(record and record.count) or 1
    if count <= 1 then return value end
    return math.max(1, U.floor(value * (1 - math.min(0.25, (count - 1) * 0.03))))
end

function Data.MarketValue(record, marketMultiplier)
    if not record then return 0 end
    local value = Data.StackValue(record)
    if record.counterfeit then value = math.max(1, U.floor(value * 0.08)) end
    return U.floor(U.round(value * (marketMultiplier or 1)))
end

function Data.RuntimeCategory(info)
    return Data.CategoryOf(info)
end

---------------------------------------------------------------------------
-- Synthetic items (mystery crates, encounter rewards)
---------------------------------------------------------------------------

Data.SyntheticItems = {
    {
        name = "Mystery Crate",
        icon = "Interface\\Icons\\INV_Misc_Crate01",
        quality = 2,
        ilvl = 25,
        classID = 15,
        subclassID = 0,
        description = "A crate wrapped in rattling twine. Smells faintly of pickled fish.",
    },
    {
        name = "Tarnished Goblet",
        icon = "Interface\\Icons\\INV_Drink_10",
        quality = 3,
        ilvl = 40,
        classID = 15,
        subclassID = 0,
        description = "Engraved with a goblin crest and someone else's initials.",
    },
    {
        name = "Cracked Scrying Orb",
        icon = "Interface\\Icons\\INV_Misc_Orb_01",
        quality = 3,
        ilvl = 45,
        classID = 15,
        subclassID = 0,
        description = "Still flickers when you haggle too hard.",
    },
    {
        name = "Bundle of Questionable Maps",
        icon = "Interface\\Icons\\INV_Scroll_02",
        quality = 2,
        ilvl = 20,
        classID = 15,
        subclassID = 0,
        description = "Half of these lead to the same swamp.",
    },
    {
        name = "Gilded Gear Cog",
        icon = "Interface\\Icons\\INV_Misc_Gear_01",
        quality = 4,
        ilvl = 60,
        classID = 15,
        subclassID = 0,
        description = "Goblin engineering at its most decorative and least useful.",
    },
    {
        name = "Pilfered Jewelry Box",
        icon = "Interface\\Icons\\INV_Box_01",
        quality = 3,
        ilvl = 35,
        classID = 15,
        subclassID = 0,
        description = "The lock is broken. The story is probably worse.",
    },
}
