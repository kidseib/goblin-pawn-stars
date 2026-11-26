--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Names.lua
    Procedural customer identities: races, names, occupations, epithets and
    class picks used for the portrait art.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local Data = ns.Data or {}
ns.Data = Data

Data.Races = {
    {
        key = "Goblin",
        classes = { "ROGUE", "WARRIOR", "MAGE", "PRIEST", "HUNTER", "WARLOCK" },
        first = {
            "Grizzek", "Nix", "Briz", "Sprocket", "Gazlowe", "Rixi", "Tinker",
            "Mozz", "Kablooie", "Snix", "Bogz", "Vexa", "Ratch", "Zizz",
        },
        last = {
            "Fizzwrench", "Goldtooth", "Coinbite", "Steamvalve", "Dustfuse",
            "Quickfinger", "Shinyspoon", "Brassknuckle", "Profitmargin",
            "Wrenchworth", "Slapdash", "Tallymark",
        },
        occupations = {
            "Scrap merchant", "Alchemist", "Dockhand", "Cartel courier",
            "Retired pirate", "Auction crier", "Bomb appraiser", "Loan collector",
        },
    },
    {
        key = "Dwarf",
        classes = { "WARRIOR", "PALADIN", "HUNTER", "PRIEST", "ROGUE", "SHAMAN" },
        first = { "Brann", "Torrin", "Hilda", "Grum", "Dagny", "Kelda", "Borri", "Fenna" },
        last = { "Stonebraid", "Ironale", "Deepdelver", "Bronzebrow", "Anvilmar", "Goldvein" },
        occupations = { "Prospector", "Brewmaster", "Archivist", "Mason", "Mountaineer" },
    },
    {
        key = "Orc",
        classes = { "WARRIOR", "SHAMAN", "HUNTER", "ROGUE", "WARLOCK", "DEATHKNIGHT" },
        first = { "Gromm", "Durak", "Kaza", "Rugok", "Morg", "Thessa", "Urzul", "Nark" },
        last = { "Skullsplitter", "Warsong", "Ironjaw", "Bloodhowl", "Darkscar", "Wolfbrother" },
        occupations = { "Pit fighter", "Wolf trainer", "Smith", "Scout", "Grunt" },
    },
    {
        key = "Human",
        classes = { "WARRIOR", "PALADIN", "MAGE", "PRIEST", "ROGUE", "HUNTER" },
        first = { "Edwin", "Marian", "Tobias", "Elsbeth", "Roderick", "Lydia", "Cedric", "Anselm" },
        last = { "VanCleef", "Hearthstone", "Whitfield", "Goodbarrel", "Brentwood", "Marsh" },
        occupations = { "Retired guard", "Merchant", "Scribe", "Innkeeper", "Courier", "Duellist" },
    },
    {
        key = "Troll",
        classes = { "SHAMAN", "HUNTER", "ROGUE", "PRIEST", "WARRIOR", "DRUID" },
        first = { "Zalazane", "Kiza", "Rokhan", "Senji", "Volni", "Jin", "Akil", "Mazra" },
        last = { "Hexblade", "Shadowtooth", "Skyshadow", "Darkspear", "Bonechill" },
        occupations = { "Hex doctor", "Fisher", "Headhunter", "Bone carver", "Trader" },
    },
    {
        key = "BloodElf",
        classes = { "MAGE", "PALADIN", "PRIEST", "ROGUE", "HUNTER", "WARLOCK" },
        first = { "Aelrin", "Sylvara", "Theric", "Lorith", "Vaelis", "Miral", "Kaelith" },
        last = { "Sunstrider", "Dawnwhisper", "Bloodfeather", "Silverbough", "Emberfall" },
        occupations = { "Enchanter", "Perfumer", "Spellblade", "Art dealer", "Courtesan" },
    },
    {
        key = "Undead",
        classes = { "WARLOCK", "ROGUE", "PRIEST", "MAGE", "WARRIOR", "HUNTER" },
        first = { "Mortimer", "Grimshaw", "Belladonna", "Dregg", "Ophelia", "Varn" },
        last = { "Rotwell", "Gravehood", "Ashenmoor", "Coldhand", "Wormwood" },
        occupations = { "Grave robber", "Apothecary", "Poison tester", "Undertaker" },
    },
    {
        key = "Tauren",
        classes = { "WARRIOR", "SHAMAN", "DRUID", "HUNTER", "PALADIN", "PRIEST" },
        first = { "Baine", "Hamuul", "Tahua", "Kodo", "Aponi", "Etar", "Nara" },
        last = { "Cloudhoof", "Bloodhoof", "Dawnstrider", "Windtotem", "Plainswalker" },
        occupations = { "Herbalist", "Storyteller", "Hide tanner", "Spirit guide" },
    },
    {
        key = "NightElf",
        classes = { "DRUID", "HUNTER", "PRIEST", "ROGUE", "WARRIOR", "MAGE" },
        first = { "Illiyana", "Ferryn", "Malfur", "Shandris", "Thalor", "Velene" },
        last = { "Moonwhisper", "Starfall", "Nightbreeze", "Shadowleaf", "Dawnpetal" },
        occupations = { "Herbalist", "Sentinel", "Dreamwatcher", "Bowyer" },
    },
    {
        key = "Gnome",
        classes = { "MAGE", "WARLOCK", "ROGUE", "WARRIOR", "PRIEST", "HUNTER" },
        first = { "Gelbin", "Trixie", "Fizzle", "Wren", "Bink", "Sprocket" },
        last = { "Mekkatorque", "Sparkblade", "Cogspinner", "Tinkersworth", "Boltfizz" },
        occupations = { "Inventor", "Gem cutter", "Demolitionist", "Watchmaker" },
    },
    {
        key = "Pandaren",
        classes = { "MONK", "WARRIOR", "MAGE", "PRIEST", "ROGUE", "HUNTER" },
        first = { "Chen", "Lili", "Taran", "Mei", "Zhu", "Aysa" },
        last = { "Stormstout", "Cloudfall", "Barleybrew", "Frostpaw", "Thunderfoot" },
        occupations = { "Noodle vendor", "Brewer", "Wanderer", "Tea merchant" },
    },
    {
        key = "Vulpera",
        classes = { "ROGUE", "HUNTER", "SHAMAN", "MAGE", "WARRIOR", "PRIEST" },
        first = { "Kiro", "Nisha", "Meerah", "Sira", "Vexi", "Rik" },
        last = { "Sandrunner", "Dunehide", "Wanderfoot", "Coinpouch", "Wickertail" },
        occupations = { "Caravan guide", "Fence", "Trinket seller", "Desert scout" },
    },
    {
        key = "Draenei",
        classes = { "PALADIN", "PRIEST", "SHAMAN", "MAGE", "HUNTER", "WARRIOR" },
        first = { "Aponi", "Velen", "Rulkan", "Maraad", "Yrel", "Hataru" },
        last = { "Lightbound", "Crystalsong", "Stormward", "Exodar", "Skycaller" },
        occupations = { "Artificer", "Anchorite", "Crystal merchant", "Vindicator" },
    },
}

Data.Epithets = {
    "the Unwashed", "of Ratchet", "the Overpriced", "Twice-Banned",
    "the Suspiciously Wealthy", "of the Long Receipt", "the Coin Counter",
    "Formerly Respectable", "the Loud", "of No Fixed Address",
}

Data.Greetings = {
    "Word around the docks is you buy anything.",
    "This place still standing? Impressive.",
    "I have a very specific need and very little patience.",
    "Your sign said 'fair prices'. I have my doubts.",
    "Let's skip the small talk. Show me the goods.",
    "A friend of a friend said you're the one to see.",
}

Data.IdleChatter = {
    "This shop smells like old rope and ambition.",
    "My cousin got rich in a pawnshop. Then he got arrested.",
    "I once sold a shield to a man who used it as a dinner plate.",
    "Goblin accounting: if it fits in the chest, it's inventory.",
    "Do you take payment in questionable promises?",
    "I'm not saying I'm cheap, but I reuse my tea bags.",
}

Data.Occupations = {
    "Scrap merchant", "Retired adventurer", "Alchemist", "Dockhand",
    "Treasure hunter", "Smith", "Cartographer", "Bounty hunter",
    "Dust salesman", "Caravan guard", "Noodle vendor", "Demolitionist",
}

function Data.RaceByKey(key)
    for _, race in ipairs(Data.Races) do
        if race.key == key then return race end
    end
    return Data.Races[1]
end

function Data.RandomRace()
    return Data.Races[math.random(#Data.Races)]
end

-- Builds a customer identity. Returns a table; no WoW API is touched so this
-- is fully testable outside the client.
function Data.GenerateIdentity()
    local race = Data.RandomRace()
    local first = race.first[math.random(#race.first)]
    local last = race.last[math.random(#race.last)]
    local name = first .. " " .. last
    if math.random() < 0.18 then
        name = name .. " " .. Data.Epithets[math.random(#Data.Epithets)]
    end

    local classes = race.classes
    local class = classes[math.random(#classes)]

    local occupation
    if math.random() < 0.62 then
        occupation = race.occupations[math.random(#race.occupations)]
    else
        occupation = Data.Occupations[math.random(#Data.Occupations)]
    end

    return {
        name = name,
        race = race.key,
        class = class,
        occupation = occupation,
        greeting = Data.Greetings[math.random(#Data.Greetings)],
    }
end
