--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Personalities.lua
    The nine customer archetypes: how they open, how hard they haggle, how long
    they wait and what they like to buy. All dialogue is local templates.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local Data = ns.Data

--[[ Field guide -------------------------------------------------------------
    opening     : fraction of the customer's hidden maximum used for the first offer
    maxWill     : how far above market value they will ever go
    budget      : personal budget multiplier applied to the tier's base budget
    patience    : negotiation rounds before they walk out
    stubborn    : resistance to counteroffers, 0 = pushover, 1 = stone wall
    haggleSkill : penalty applied when the player counters greedily
    prefer      : categories this customer actually wants
    rare        : chance this archetype is a "rare collector" variant
    weight      : spawn weight, filtered by minTier
--------------------------------------------------------------------------- ]]

Data.Personalities = {
    {
        key = "cheap",
        name = "Cheap Bargain Hunter",
        short = "Bargain Hunter",
        icon = "Interface\\Icons\\INV_Misc_Coin_02",
        description = "Believes every price is a personal insult. Will haggle over a copper.",
        weight = 20, minTier = 1,
        opening = { 0.24, 0.44 }, maxWill = 0.86, budget = 0.75,
        patience = 2, stubborn = 0.68, haggleSkill = 0.85,
        prefer = { "misc", "cloth", "consumable", "ore" },
        lines = {
            greet = {
                "I'm not made of money, you know.",
                "Let's be reasonable. Which you clearly aren't.",
                "I'll look, but I'm not buying anything overpriced.",
            },
            offer = {
                "I'll give you {offer}. That's already generous.",
                "{offer}. Take it before I come to my senses.",
            },
            accept = {
                "Fine. {price}. You're robbing me blind.",
                "Ugh. {price}. I'll be eating turnips for a week.",
            },
            refuse = {
                "{counter}? For THAT? I could buy a whole cart for that.",
                "No no no. {counter} is a fantasy number.",
            },
            leave = {
                "Forget it. There's a stall down the road that knows how to price.",
                "I'll wait for the market to collapse. It always does.",
            },
        },
    },
    {
        key = "collector",
        name = "Wealthy Collector",
        short = "Collector",
        icon = "Interface\\Icons\\INV_Misc_Gem_03",
        description = "Money is no object, taste is everything. Pays well for the right piece.",
        weight = 12, minTier = 1,
        opening = { 0.62, 0.92 }, maxWill = 1.95, budget = 2.4,
        patience = 4, stubborn = 0.18, haggleSkill = 0.35,
        prefer = { "gem", "misc", "pet", "recipe" },
        rare = 0.35,
        lines = {
            greet = {
                "I collect only things with a story. Preferably an expensive one.",
                "My display hall has a gap. Fill it.",
                "Do try not to waste my afternoon.",
            },
            offer = {
                "I shall offer {offer}. It is, I assure you, more than fair.",
                "{offer}. I have paid more for worse at auction.",
            },
            accept = {
                "Splendid. {price}, and do wrap it properly.",
                "Agreed. {price}. Put it on my account, the one nobody audits.",
            },
            refuse = {
                "{counter}? My dear, I have appraisers who laugh at numbers like that.",
                "That is not a price, that is a fairy tale. {counter}, honestly.",
            },
            leave = {
                "I shall take my collection budget elsewhere.",
                "How dreadfully common. Good day.",
            },
        },
    },
    {
        key = "trader",
        name = "Experienced Trader",
        short = "Trader",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        description = "Knows every price on the continent and enjoys telling you so.",
        weight = 16, minTier = 1,
        opening = { 0.46, 0.66 }, maxWill = 1.18, budget = 1.6,
        patience = 4, stubborn = 0.52, haggleSkill = 1.0,
        prefer = { "ore", "herb", "leather", "cloth", "enchant" },
        lines = {
            greet = {
                "I know what this is worth. Do you?",
                "Let's keep this professional. I have three more shops today.",
                "I've been trading since before your sign was nailed up.",
            },
            offer = {
                "{offer}. Market rate, plus a small courtesy.",
                "I'll take it at {offer}. That's the honest number.",
            },
            accept = {
                "Done. {price}. You drive a hard bargain, for a beginner.",
                "{price}. Pleasure doing business. Don't spend it on fuses.",
            },
            refuse = {
                "{counter}? You've been reading auction listings again.",
                "That's above the going rate. {counter} won't happen.",
            },
            leave = {
                "I'll take my coin to someone who understands the market.",
                "Noted. I'll remember this shop's prices.",
            },
        },
    },
    {
        key = "gullible",
        name = "Gullible Adventurer",
        short = "Adventurer",
        icon = "Interface\\Icons\\INV_Helmet_08",
        description = "Fresh from a dungeon, convinced everything is an artifact.",
        weight = 15, minTier = 1,
        opening = { 0.78, 1.06 }, maxWill = 1.48, budget = 1.1,
        patience = 3, stubborn = 0.08, haggleSkill = 0.2,
        prefer = { "weapon", "armor", "gem", "enchant" },
        lines = {
            greet = {
                "Is this the shop that buys mysterious relics? Perfect!",
                "I found this in a dungeon and it hummed at me.",
                "My guild said not to come here. Here I am.",
            },
            offer = {
                "How about {offer}? That's all my quest money.",
                "{offer}! I hope that's enough, I already spent the rest on potions.",
            },
            accept = {
                "Amazing! {price}! Wait until my guild hears about this.",
                "Deal! {price}! You're my favourite shopkeeper ever.",
            },
            refuse = {
                "{counter}? Oh. I, uh, don't have that much.",
                "That seems like a lot. Is {counter} normal?",
            },
            leave = {
                "I'll come back when I've looted something else. Bye!",
                "Okay! I'll go ask the other shop. They have a parrot.",
            },
        },
    },
    {
        key = "desperate",
        name = "Desperate Buyer",
        short = "Desperate",
        icon = "Interface\\Icons\\INV_Misc_Bandage_04",
        description = "Needs it today, for reasons they will not explain.",
        weight = 11, minTier = 1,
        opening = { 0.84, 1.14 }, maxWill = 1.72, budget = 1.35,
        patience = 2, stubborn = 0.12, haggleSkill = 0.3,
        prefer = { "consumable", "armor", "weapon", "herb" },
        -- The only archetype currently desperate enough to bet its own purse.
        -- Modules/Gamble.lua reads this flag; the negotiation window shows the
        -- wager only for customers whose data says yes.
        gamble = true,
        lines = {
            greet = {
                "You have it? Tell me you have it.",
                "I need something, and I need it before nightfall.",
                "No time for pleasantries. Show me what you've got.",
            },
            offer = {
                "{offer}. Right now. I'm not bargaining.",
                "{offer} and I walk out with it this instant.",
            },
            accept = {
                "{price}. Done. Thank you. Really.",
                "Take {price}. I owe you one, in a vague, non-binding way.",
            },
            refuse = {
                "{counter}? I don't have time for games!",
                "That is daylight robbery. {counter} is absurd.",
            },
            leave = {
                "I'll find it somewhere else. I have to.",
                "Useless. I'm going.",
            },
            wager = {
                "I haven't got time to haggle. Double or nothing. My whole purse, or I take it cheap.",
                "One flip. That's all the patience I have left. Everything I have, or a discount.",
            },
            wagerWin = {
                "Fine. {price}. I said double or nothing and the coin said nothing.",
                "{price}. Take it and don't look so pleased about it.",
            },
            wagerLose = {
                "Ha! {price}, and cheap at that. I needed the good news.",
                "{price}. I'd have paid double, but you offered to flip.",
            },
        },
    },
    {
        key = "suspicious",
        name = "Suspicious Goblin",
        short = "Suspicious",
        icon = "Interface\\Icons\\INV_Misc_Coin_05",
        description = "Certain that someone, somewhere, is skimming a copper off them.",
        weight = 13, minTier = 1,
        opening = { 0.38, 0.62 }, maxWill = 1.08, budget = 1.2,
        patience = 3, stubborn = 0.6, haggleSkill = 0.9,
        prefer = { "misc", "ore", "gem", "recipe" },
        lines = {
            greet = {
                "I'm watching you. And the scales. Mostly the scales.",
                "I hear this shop has hidden fees. I want to see the fees.",
                "Everything labelled? Good. I check.",
            },
            offer = {
                "{offer}. And I want a receipt. And a second receipt.",
                "{offer}. Round numbers only, I don't trust decimals.",
            },
            accept = {
                "Fine. {price}. I'll be counting my change twice.",
                "{price}. Don't think I won't notice if it's short.",
            },
            refuse = {
                "{counter}? What are you, a pirate? Oh wait.",
                "That's inflated. Suspiciously inflated. {counter}, no.",
            },
            leave = {
                "Shady. I'm leaving before I get swindled.",
                "I knew it. Hidden fees everywhere. Goodbye.",
            },
        },
    },
    {
        key = "impatient",
        name = "Impatient Warrior",
        short = "Impatient",
        icon = "Interface\\Icons\\INV_Sword_27",
        description = "Has three raids, a duel and a haircut scheduled. Buys fast.",
        weight = 12, minTier = 1,
        opening = { 0.58, 0.88 }, maxWill = 1.28, budget = 1.15,
        patience = 1, stubborn = 0.22, haggleSkill = 0.4,
        prefer = { "weapon", "armor", "consumable" },
        lines = {
            greet = {
                "Speed it up. I have a duel at four.",
                "You. Talk. Price. Now.",
                "I'm in a hurry. Everyone is in my way today.",
            },
            offer = {
                "{offer}. Yes or no, don't make a speech.",
                "{offer} and I stop leaning on your counter.",
            },
            accept = {
                "{price}. Finally. Somebody in this town understands urgency.",
                "Done. {price}. Don't talk to me, I'm late.",
            },
            refuse = {
                "{counter}? You're wasting my time with numbers.",
                "Nope. Too much. {counter} is too much.",
            },
            leave = {
                "Forget it. I'll fight with the old one.",
                "I don't have time for this. I'm gone.",
            },
        },
    },
    {
        key = "merchant",
        name = "Traveling Merchant",
        short = "Merchant",
        icon = "Interface\\Icons\\INV_Misc_Bag_14",
        description = "Buys in bulk, complains in bulk, pays reliably.",
        weight = 9, minTier = 2,
        opening = { 0.42, 0.64 }, maxWill = 1.06, budget = 2.0,
        patience = 5, stubborn = 0.44, haggleSkill = 0.95,
        prefer = { "ore", "cloth", "leather", "herb", "consumable" },
        lines = {
            greet = {
                "I'm moving a caravan through here. Buying everything that won't melt.",
                "Bulk prices, yes? The cart is already loaded.",
                "I buy cheap, I sell cheap, I complain free of charge.",
            },
            offer = {
                "{offer}. If it moves, I'll double my order.",
                "{offer} for that one. Don't play precious with me.",
            },
            accept = {
                "{price}. I'll take it. And two more like it if you have them.",
                "Agreed. {price}. My cart thanks you.",
            },
            refuse = {
                "{counter}? With that price I'd have to sell my ox.",
                "Not at {counter}. I'm a merchant, not a charity.",
            },
            leave = {
                "No deal. I'll try the market in Stormwind.",
                "Caravan's leaving. So am I.",
            },
        },
    },
    {
        key = "rare_hunter",
        name = "Mysterious Rare-Item Collector",
        short = "Rare Collector",
        icon = "Interface\\Icons\\INV_Misc_Orb_03",
        description = "Only wants the exceptional, and pays accordingly. Never says why.",
        weight = 5, minTier = 3,
        opening = { 0.66, 0.98 }, maxWill = 2.45, budget = 3.2,
        patience = 3, stubborn = 0.32, haggleSkill = 0.55,
        prefer = { "gem", "misc", "pet", "weapon" },
        rare = 0.85,
        lines = {
            greet = {
                "I have travelled a long way for something rather specific.",
                "Do you have anything... odd? Odd sells.",
                "I am looking for the piece nobody else would buy.",
            },
            offer = {
                "{offer}. I trust we are not negotiating the story, only the coin.",
                "{offer}. It is worth considerably more to the right buyer. Me.",
            },
            accept = {
                "{price}. A fine addition. My order will be pleased.",
                "Done. {price}. You did not ask its purpose. Wise.",
            },
            refuse = {
                "{counter}? You mistake my curiosity for desperation.",
                "That figure is fanciful. {counter} will not happen.",
            },
            leave = {
                "I shall return to the whispers. They had better leads.",
                "A pity. I had such plans for it.",
            },
        },
    },
}

Data.PersonalityByKey = {}
Data.PersonalityIndex = {}
for index, personality in ipairs(Data.Personalities) do
    Data.PersonalityByKey[personality.key] = personality
    Data.PersonalityIndex[personality.key] = index
end

function Data.PersonalityPick(tier)
    local pool = {}
    for _, personality in ipairs(Data.Personalities) do
        if (personality.minTier or 1) <= (tier or 1) then
            pool[#pool + 1] = personality
        end
    end
    return ns.Util.weightedPick(pool, function(entry) return entry.weight or 1 end)
end

function Data.PersonalityLine(personality, key, vars)
    local bucket = personality and personality.lines and personality.lines[key]
    if not bucket or #bucket == 0 then return "" end
    return ns.Util.fill(bucket[math.random(#bucket)], vars)
end
