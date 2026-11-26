--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Deed.lua
    The 1.4.0 "The Deed" campaign: a three-payment cartel debt, one museum set,
    one named regular and the franchise endings. All rewards are virtual.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local Data = ns.Data

Data.Deed = {
    creditor = "Bilgewater Cartel",
    collector = "Snix Brassknuckle",
    intro = "Your uncle signed for a cartel loan, then vanished with the strongbox. " ..
        "Snix Brassknuckle has left the ledger on your counter. The debt is yours now: " ..
        "three payments, no extensions.",
    total = 32500,
    payments = {
        {
            amount = 1500,
            title = "The First Note",
            story = "Snix counts the coins twice, pockets one, and writes a receipt. " ..
                "\"Two more notes. The cartel is starting to like you. That is not a compliment.\" " ..
                "The Curious Collection and Marta Copperpin are now available.",
            unlock = "Museum set and named regular unlocked.",
        },
        {
            amount = 6000,
            title = "The Second Note",
            story = "The second payment buys you a nod instead of a threat. Snix mentions, " ..
                "almost kindly, that the cartel has started calling your shop \"the little museum\". " ..
                "Marta hears the story and decides she has a piece worth donating.",
        },
        {
            amount = 25000,
            title = "The Final Note",
            story = "Snix strikes the debt from the ledger with one claw. For a moment the shop " ..
                "is quiet enough to hear the market breathe. Then he asks the only question that matters: " ..
                "\"So. What happens to this place now?\"",
        },
    },
    endings = {
        endless = {
            title = "Endless Ledger",
            text = "You keep the doors open. The cartel is paid, the shelves keep turning, " ..
                "and there is always another customer with another story and another handful of coins.",
        },
        franchise = {
            title = "The Next Shop",
            text = "You sign the shop over to a trusted goblin and start again with a smaller stall, " ..
                "a cleaner ledger, and everything you learned. The museum and Marta come with you.",
        },
    },
}

Data.Museum = {
    key = "curious_collection",
    name = "The Curious Collection",
    description = "Five pieces with a story, not just a price tag. Donate one eligible " ..
        "item per slot. The set is yours forever and adds +5% to customer offers.",
    minQuality = 2,
    bonus = 0.05,
    slots = {
        {
            key = "weapon",
            label = "A Blade with a History",
            hint = "Weapon, quality 2 or better",
            icon = "Interface\\Icons\\INV_Sword_04",
        },
        {
            key = "gem",
            label = "A Stone That Remembers",
            hint = "Gem, quality 2 or better",
            icon = "Interface\\Icons\\INV_Misc_Gem_01",
        },
        {
            key = "cloth",
            label = "A Rag of Some Importance",
            hint = "Cloth, quality 2 or better",
            icon = "Interface\\Icons\\INV_Fabric_Linen_01",
        },
        {
            key = "ore",
            label = "A Nugget with a Past",
            hint = "Ore, quality 2 or better",
            icon = "Interface\\Icons\\INV_Ore_Copper_01",
        },
        {
            key = "misc",
            label = "The Unclassifiable Thing",
            hint = "Curiosity, quality 2 or better",
            icon = "Interface\\Icons\\INV_Misc_Orb_03",
        },
    },
}

Data.Regular = {
    key = "marta",
    name = "Marta Copperpin",
    race = "Dwarf",
    class = "WARRIOR",
    occupation = "Retired Prospector",
    personality = "collector",
    greeting = "Marta Copperpin sets a battered prospector's satchel on the counter. " ..
        "\"I hear this place buys things with a story. Good. I have three, and I am in no hurry.\"",
    bonus = 0.03,
    visits = {
        {
            title = "The First Visit",
            story = "Marta sells you a piece from her prospecting days and tells you where it came from. " ..
                "She does not haggle. She appraises you instead.",
        },
        {
            title = "The Second Visit",
            story = "Marta returns with a smaller piece and a larger story. Snix watches from the door, " ..
                "pretending not to listen. Marta pretends not to notice him.",
        },
        {
            title = "The Third Visit",
            story = "Marta brings the last piece and a proposition: keep the museum honest and she will " ..
                "send every retired prospector she knows. Her friendship adds +3% to customer offers, permanently.",
        },
    },
}
