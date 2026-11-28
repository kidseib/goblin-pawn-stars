--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Encounters.lua
    Random shop events. Each definition is pure data; Modules/Encounters.lua
    builds the concrete offer (item, price, stakes) from it.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local Data = ns.Data

Data.Encounters = {
    {
        key = "counterfeit",
        name = "Counterfeit Goods",
        icon = "Interface\\Icons\\INV_Misc_Coin_09",
        weight = 14, minTier = 1, kind = "seller",
        description = "A nervous customer slides a shiny item across the counter and asks for a quick sale.",
        accept = "buy",
        decline = "refuse",
    },
    {
        key = "thief",
        name = "Thief in the Aisles",
        icon = "Interface\\Icons\\Ability_Stealth",
        weight = 13, minTier = 1, kind = "crisis",
        description = "Someone is stuffing a shelf item into a coat that has far too many pockets.",
        accept = "confront",
        decline = "ignore",
    },
    {
        key = "celebrity",
        name = "Celebrity Adventurer",
        icon = "Interface\\Icons\\INV_Helmet_01",
        weight = 9, minTier = 2, kind = "visit",
        description = "A famous adventurer walks in, followed by a chronicler and three fans.",
    },
    {
        key = "complainer",
        name = "Returning Customer",
        icon = "Interface\\Icons\\INV_Misc_Bone_03",
        weight = 11, minTier = 1, kind = "complaint",
        description = "A previous buyer storms in waving a receipt and something that is definitely broken.",
    },
    {
        key = "mystery_delivery",
        name = "Mystery Delivery",
        icon = "Interface\\Icons\\INV_Misc_Crate01",
        weight = 10, minTier = 1, kind = "delivery",
        description = "An unmarked crate arrives with your name on it, misspelled twice.",
    },
    {
        key = "rare_collector",
        name = "Unusually Large Payment",
        icon = "Interface\\Icons\\INV_Misc_Gem_04",
        weight = 7, minTier = 2, kind = "visit",
        description = "A collector with a very specific interest and a very large purse asks for your best piece.",
    },
    {
        key = "rival_shop",
        name = "Rival Pawnshop",
        icon = "Interface\\Icons\\INV_Misc_Coin_03",
        weight = 9, minTier = 2, kind = "market",
        description = "A new shop opened two streets over and is undercutting everyone.",
    },
    {
        key = "auction",
        name = "Special Auction",
        icon = "Interface\\Icons\\INV_Misc_Horn_03",
        weight = 8, minTier = 3, kind = "auction",
        description = "A sealed-bid auction is happening tonight and you have been invited.",
    },
    {
        key = "lowball",
        name = "Ridiculous Lowball",
        icon = "Interface\\Icons\\INV_Misc_Coin_06",
        weight = 12, minTier = 1, kind = "lowball",
        description = "A customer points at a fine piece and offers roughly the price of a stale bread roll.",
    },
    {
        key = "tax_audit",
        name = "Goblin Tax Audit",
        icon = "Interface\\Icons\\INV_Misc_Note_05",
        weight = 7, minTier = 2, kind = "tax",
        description = "A tax collector with a clipboard and a smile that has never reached his eyes.",
    },
    {
        key = "traveling_merchant",
        name = "Traveling Merchant",
        icon = "Interface\\Icons\\INV_Misc_Bag_17",
        weight = 8, minTier = 1, kind = "deal",
        description = "A merchant's cart broke an axle outside and he needs coin for repairs.",
    },
}

Data.EncounterByKey = {}
Data.EncounterIndex = {}
for index, encounter in ipairs(Data.Encounters) do
    Data.EncounterByKey[encounter.key] = encounter
    Data.EncounterIndex[encounter.key] = index
end

--[[ Picking an event --------------------------------------------------------
    `recent` holds the indices of the last couple of events, newest first. They
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
end
