--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Achievements.lua
    Custom milestones, with fictional shop titles awarded on unlock. These are
    addon-only titles shown in the dashboard, not real WoW titles.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local Data = ns.Data

Data.Achievements = {
    {
        key = "first_sale",
        name = "First Customer",
        description = "Complete your first sale.",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        stat = "sales", target = 1, points = 5,
    },
    {
        key = "best_i_can_do",
        name = "Best I Can Do",
        description = "Successfully complete 100 sales.",
        icon = "Interface\\Icons\\INV_Misc_Coin_02",
        stat = "sales", target = 100, points = 25,
        title = "the Pawnbroker",
    },
    {
        key = "highway_robbery",
        name = "Highway Robbery",
        description = "Sell a single item for at least twice its estimated value.",
        icon = "Interface\\Icons\\INV_Misc_Coin_03",
        stat = "bestMultiple", target = 2, points = 20,
        title = "the Highwayman",
    },
    {
        key = "absolutely_not",
        name = "Absolutely Not",
        description = "Reject 100 offers.",
        icon = "Interface\\Icons\\INV_Misc_Bone_01",
        stat = "rejected", target = 100, points = 20,
        title = "the Unimpressed",
    },
    {
        key = "goblin_millionaire",
        name = "Goblin Millionaire",
        description = "Earn 1,000,000 Goblin Credits over the life of the business.",
        icon = "Interface\\Icons\\INV_Misc_Coin_07",
        stat = "earned", target = 1000000, points = 100,
        title = "Goblin Millionaire",
    },
    {
        key = "professional_lowballer",
        name = "Professional Lowballer",
        description = "Win 50 counteroffers.",
        icon = "Interface\\Icons\\INV_Misc_Coin_05",
        stat = "counterSuccess", target = 50, points = 30,
        title = "the Silver-Tongued",
    },
    {
        key = "i_know_what_ive_got",
        name = "I Know What I've Got",
        description = "Make a successful sale to a rare collector.",
        icon = "Interface\\Icons\\INV_Misc_Orb_03",
        stat = "rareSales", target = 1, points = 25,
        title = "the Collector's Favourite",
    },
    {
        key = "let_me_call_an_expert",
        name = "Let Me Call an Expert",
        description = "Appraise 100 items.",
        icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
        stat = "appraisals", target = 100, points = 25,
        title = "the Expert",
    },
    {
        key = "counter_insurgent",
        name = "Counter-Insurgent",
        description = "Win 10 counteroffers.",
        icon = "Interface\\Icons\\INV_Scroll_05",
        stat = "counterSuccess", target = 10, points = 10,
    },
    {
        key = "reputation_above",
        name = "A Name Worth Knowing",
        description = "Reach 500 reputation.",
        icon = "Interface\\Icons\\INV_Misc_Scroll_04",
        stat = "reputation", target = 500, points = 20,
    },
    {
        key = "tier_two",
        name = "Indoor Plumbing",
        description = "Upgrade to a Goblin Pawnshop.",
        icon = "Interface\\Icons\\INV_Misc_Bag_10",
        stat = "tier", target = 2, points = 10,
    },
    {
        key = "tier_three",
        name = "Established Address",
        description = "Upgrade to an Established Trading Post.",
        icon = "Interface\\Icons\\INV_Misc_Bag_14",
        stat = "tier", target = 3, points = 20,
    },
    {
        key = "tier_four",
        name = "Velvet Ropes",
        description = "Upgrade to a Luxury Auction House.",
        icon = "Interface\\Icons\\INV_Box_01",
        stat = "tier", target = 4, points = 35,
    },
    {
        key = "tier_five",
        name = "Trading Empire",
        description = "Upgrade to an Azeroth Trading Empire.",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        stat = "tier", target = 5, points = 50,
        title = "the Empire Builder",
    },
    {
        key = "full_house",
        name = "Full House",
        description = "Have three employees at the same time.",
        icon = "Interface\\Icons\\INV_Misc_Horn_02",
        check = function(db)
            local count = 0
            for _, level in pairs(db.employees) do
                if (tonumber(level) or 0) > 0 then count = count + 1 end
            end
            return count, 3
        end,
        points = 20,
    },
    {
        key = "master_appraiser",
        name = "Master Appraiser",
        description = "Raise any employee to level 5.",
        icon = "Interface\\Icons\\INV_Misc_Spyglass_03",
        check = function(db)
            local best = 0
            for _, level in pairs(db.employees) do
                if (tonumber(level) or 0) > best then best = tonumber(level) end
            end
            return best, 5
        end,
        points = 30,
    },
    {
        key = "deep_stock",
        name = "Deep Stock",
        description = "Acquire 250 virtual items in total.",
        icon = "Interface\\Icons\\INV_Misc_Bag_08",
        stat = "itemsCollected", target = 250, points = 20,
    },
    {
        key = "crate_opener",
        name = "Crate Opener",
        description = "Open 10 mystery deliveries.",
        icon = "Interface\\Icons\\INV_Misc_Crate01",
        stat = "mysteryItems", target = 10, points = 15,
    },
    {
        key = "thief_taker",
        name = "Not Today",
        description = "Stop 10 theft attempts.",
        icon = "Interface\\Icons\\INV_Shield_02",
        stat = "theftsPrevented", target = 10, points = 20,
    },
    {
        key = "counterfeit_spotter",
        name = "Eye for a Fake",
        description = "Refuse 5 counterfeit offers.",
        icon = "Interface\\Icons\\INV_Misc_Coin_09",
        stat = "counterfeitsRefused", target = 5, points = 15,
    },
    {
        key = "big_spender",
        name = "Big Spender",
        description = "Spend 100,000 Goblin Credits on the business.",
        icon = "Interface\\Icons\\INV_Misc_Coin_04",
        stat = "spent", target = 100000, points = 25,
    },
    {
        key = "auction_winner",
        name = "Going Once, Going Twice",
        description = "Win a special auction.",
        icon = "Interface\\Icons\\INV_Misc_Horn_03",
        stat = "auctionsWon", target = 1, points = 15,
    },
    {
        key = "people_person",
        name = "People Person",
        description = "Serve 250 customers.",
        icon = "Interface\\Icons\\INV_Misc_Head_Human_01",
        stat = "customersServed", target = 250, points = 25,
    },
    {
        key = "curator",
        name = "Curator of Curiosities",
        description = "Complete The Curious Collection museum set.",
        icon = "Interface\\Icons\\INV_Misc_Orb_03",
        check = function(db)
            return (db.museum and db.museum.completed) and 1 or 0, 1
        end,
        points = 30,
        title = "the Curator",
    },
    {
        key = "marta_friend",
        name = "A Regular's Regular",
        description = "Complete all three of Marta Copperpin's visits.",
        icon = "Interface\\Icons\\INV_Misc_Head_Dwarf_01",
        check = function(db)
            return (db.regular and db.regular.done) and 1 or 0, 1
        end,
        points = 25,
    },
    {
        key = "debt_free",
        name = "Free Goblin",
        description = "Pay the Bilgewater Cartel debt in full.",
        icon = "Interface\\Icons\\INV_Scroll_03",
        check = function(db)
            return (db.campaign and db.campaign.completed) and 1 or 0, 1
        end,
        points = 50,
        title = "the Free Goblin",
    },
}

Data.AchievementByKey = {}
for _, achievement in ipairs(Data.Achievements) do
    Data.AchievementByKey[achievement.key] = achievement
end
