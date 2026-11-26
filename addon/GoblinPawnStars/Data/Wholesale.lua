--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Wholesale.lua
    Bulk lots sold by the goblin wholesaler. Each template becomes one virtual
    stack; the lot's price is derived from the live market, never from a timer.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local Data = ns.Data

Data.Wholesale = {
    {
        key = "cloth",
        lotName = "Bale of Salvaged Cloth",
        itemName = "Bolt of Salvaged Cloth",
        category = "cloth",
        classID = 7, subclassID = 5,
        ilvl = 20,
        icon = "Interface\\Icons\\INV_Fabric_Linen_01",
    },
    {
        key = "ore",
        lotName = "Crate of Unclaimed Ore",
        itemName = "Chunk of Unclaimed Ore",
        category = "ore",
        classID = 7, subclassID = 7,
        ilvl = 21,
        icon = "Interface\\Icons\\INV_Ore_Copper_01",
    },
    {
        key = "leather",
        lotName = "Bundle of Odd Hides",
        itemName = "Cured Odd Hide",
        category = "leather",
        classID = 7, subclassID = 6,
        ilvl = 22,
        icon = "Interface\\Icons\\INV_Misc_LeatherScrap_03",
    },
    {
        key = "herb",
        lotName = "Sack of Damp Herbs",
        itemName = "Sprig of Damp Herb",
        category = "herb",
        classID = 7, subclassID = 9,
        ilvl = 21,
        icon = "Interface\\Icons\\INV_Misc_Herb_07",
    },
    {
        key = "weapon",
        lotName = "Barrel of Questionable Blades",
        itemName = "Chipped Longsword",
        category = "weapon",
        classID = 2, subclassID = 7,
        ilvl = 23,
        icon = "Interface\\Icons\\INV_Sword_04",
    },
    {
        key = "armor",
        lotName = "Crate of Mismatched Armor",
        itemName = "Dented Chain Vest",
        category = "armor",
        classID = 4, subclassID = 3,
        ilvl = 22,
        icon = "Interface\\Icons\\INV_Chest_Chain_04",
    },
    {
        key = "gem",
        lotName = "Pouch of Cloudy Gems",
        itemName = "Cloudy Cut Gem",
        category = "gem",
        classID = 3, subclassID = 0,
        ilvl = 24,
        icon = "Interface\\Icons\\INV_Misc_Gem_01",
    },
    {
        key = "enchant",
        lotName = "Tin of Enchanting Dust",
        itemName = "Pinch of Strange Dust",
        category = "enchant",
        classID = 7, subclassID = 10,
        ilvl = 22,
        icon = "Interface\\Icons\\INV_Enchant_DustArcane",
    },
    {
        key = "consumable",
        lotName = "Case of Unlabelled Potions",
        itemName = "Cloudy Red Potion",
        category = "consumable",
        classID = 0, subclassID = 0,
        ilvl = 19,
        icon = "Interface\\Icons\\INV_Potion_51",
    },
    {
        key = "misc",
        lotName = "Box of Curiosities",
        itemName = "Unidentified Curiosity",
        category = "misc",
        classID = 15, subclassID = 0,
        ilvl = 20,
        icon = "Interface\\Icons\\INV_Misc_Bag_10",
    },
}

Data.WholesaleByKey = {}
for _, template in ipairs(Data.Wholesale) do
    Data.WholesaleByKey[template.key] = template
end
