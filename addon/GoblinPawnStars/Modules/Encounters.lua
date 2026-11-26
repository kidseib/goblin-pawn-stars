--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Encounters.lua
    Random shop events. Everything is simulated locally; none of it touches the
    player's real inventory, gold or the game world.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local E = {}
ns.Encounters = E

local ROLL_INTERVAL = 170
local ROLL_CHANCE = 0.38

---------------------------------------------------------------------------
-- Builders
---------------------------------------------------------------------------

local function randomSynthetic()
    local list = ns.Data.SyntheticItems
    local def = list[math.random(#list)]
    local info = {
        name = def.name,
        icon = def.icon,
        quality = def.quality,
        ilvl = def.ilvl,
        classID = def.classID or 15,
        subclassID = def.subclassID or 0,
        description = def.description,
    }
    info.category = ns.Data.CategoryOf(info)
    info.value = ns.Data.BaseValue(info)
    return info
end

local function pickRecord()
    return ns.Inventory.RandomRecord()
end

local function cannotStore()
    return ns.Inventory.Count() >= ns.Inventory.Capacity()
end

local function buildCounterfeit()
    local record = pickRecord()
    if not record then return nil end

    local price = math.max(12, U.floor(ns.Market.Value(record) * 0.4))
    local bonuses = ns.Shop.Bonuses()
    local detectChance = U.clamp(ns.Shop.Appraisal() / 100 * 0.75 + (bonuses.forgery or 0), 0, 0.95)
    local detected = U.chance(detectChance)

    local text = string.format(
        "%s slides a %s across the counter and asks %s credits for it. \"Fresh from a dungeon. Definitely real.\"",
        "A nervous customer", record.name, U.comma(price))
    if detected then
        text = text .. "\n\n|cffff5555Your eye catches a bad hallmark: this is a counterfeit.|r"
    end

    return {
        key = "counterfeit",
        title = "Counterfeit Goods",
        icon = "Interface\\Icons\\INV_Misc_Coin_09",
        text = text,
        item = { name = record.name, icon = record.icon, quality = record.quality },
        uid = record.uid,
        price = price,
        detected = detected,
        options = {
            { id = "buy", label = "Buy it (" .. U.comma(price) .. " credits)", tone = "primary", disabled = price > ns.Shop.Credits() or cannotStore() },
            { id = "refuse", label = "Refuse the deal", tone = "danger" },
        },
    }
end

local function buildThief()
    local record = pickRecord()
    if not record then return nil end
    local bonuses = ns.Shop.Bonuses()
    local stopChance = U.clamp(0.3 + (bonuses.theft or 0) * 1.4, 0.1, 0.92)

    return {
        key = "thief",
        title = "Thief in the Aisles",
        icon = "Interface\\Icons\\Ability_Stealth",
        text = string.format(
            "Someone is easing %s into a coat with far too many pockets. The shop is quiet. You are the only one watching.",
            record.name),
        item = { name = record.name, icon = record.icon, quality = record.quality },
        uid = record.uid,
        stopChance = stopChance,
        options = {
            { id = "confront", label = "Confront the thief", tone = "primary" },
            { id = "ignore", label = "Pretend not to notice", tone = "danger" },
        },
    }
end

local function buildCelebrity()
    if ns.Inventory.Count() == 0 then return nil end
    return {
        key = "celebrity",
        title = "Celebrity Adventurer",
        icon = "Interface\\Icons\\INV_Helmet_01",
        text = string.format(
            "%s just walked in, followed by a chronicler and three very excited fans. They are looking for something with a story attached.",
            ns.Data.GenerateIdentity().name),
        options = {
            { id = "meet", label = "Show them the best stock", tone = "primary" },
            { id = "decline", label = "Send them away politely", tone = "danger" },
        },
    }
end

local function buildComplainer()
    local lastSale = DB.Get().shop.lastSale
    if not lastSale then return nil end
    local refund = math.max(15, U.floor((lastSale.price or 0) * 0.55))
    return {
        key = "complainer",
        title = "Returning Customer",
        icon = "Interface\\Icons\\INV_Misc_Bone_03",
        text = string.format(
            "The buyer of %s is back, waving a receipt and something that is definitely broken. They want %s credits back.",
            lastSale.itemName or "an item", U.comma(refund)),
        price = refund,
        options = {
            { id = "refund", label = "Refund them (" .. U.comma(refund) .. " credits)", tone = "primary", disabled = refund > ns.Shop.Credits() },
            { id = "refuse", label = "Point at the 'no refunds' sign", tone = "danger" },
        },
    }
end

local function buildMystery()
    local info = randomSynthetic()
    return {
        key = "mystery_delivery",
        title = "Mystery Delivery",
        icon = "Interface\\Icons\\INV_Misc_Crate01",
        text = "A crate arrives with your name on it, misspelled twice. There is no sender, but there is a faint ticking sound.",
        synthetic = info,
        options = {
            { id = "open", label = "Open the crate", tone = "primary", disabled = cannotStore() },
            { id = "sendback", label = "Send it back unopened", tone = "danger" },
        },
    }
end

local function buildRareCollector()
    if ns.Inventory.Count() == 0 then return nil end
    return {
        key = "rare_collector",
        title = "A Very Specific Collector",
        icon = "Interface\\Icons\\INV_Misc_Gem_04",
        text = "A hooded figure asks for your finest piece, names a figure well above the market, and does not blink.",
        options = {
            { id = "meet", label = "Bring out the good stuff", tone = "primary" },
            { id = "decline", label = "Say the shop is closed", tone = "danger" },
        },
    }
end

local function buildRival()
    local cost = 60 + ns.Shop.Tier() * 45
    return {
        key = "rival_shop",
        title = "Rival Pawnshop",
        icon = "Interface\\Icons\\INV_Misc_Coin_03",
        text = string.format(
            "A new pawnshop opened two streets over and is undercutting every price in the district. You could ride it out, or spend %s credits on a loud, petty advertising war.",
            U.comma(cost)),
        price = cost,
        options = {
            { id = "undercut", label = "Out-advertise them (" .. U.comma(cost) .. " credits)", tone = "primary", disabled = cost > ns.Shop.Credits() },
            { id = "ride", label = "Ride out the price war", tone = "danger" },
        },
    }
end

local function buildAuction()
    local info = randomSynthetic()
    local bid = 150 + ns.Shop.Tier() * 130
    return {
        key = "auction",
        title = "Special Auction",
        icon = "Interface\\Icons\\INV_Misc_Horn_03",
        text = string.format(
            "A sealed-bid auction tonight. Lot %d is a %s. The opening bid is %s credits and the room is full of amateurs.",
            math.random(1, 99), info.name, U.comma(bid)),
        synthetic = info,
        price = bid,
        winChance = U.clamp(0.34 + ns.Shop.Appraisal() / 100 * 0.3, 0.3, 0.85),
        options = {
            { id = "bid", label = "Bid " .. U.comma(bid) .. " credits", tone = "primary", disabled = bid > ns.Shop.Credits() or cannotStore() },
            { id = "pass", label = "Let it go", tone = "danger" },
        },
    }
end

local function buildLowball()
    local record = pickRecord()
    if not record then return nil end
    local offer = math.max(1, U.floor(ns.Market.Value(record) * 0.03))
    return {
        key = "lowball",
        title = "Ridiculous Lowball",
        icon = "Interface\\Icons\\INV_Misc_Coin_06",
        text = string.format(
            "A customer points at %s and offers %s credits. %s",
            record.name, U.comma(offer), "\"That's the best I can do.\""),
        item = { name = record.name, icon = record.icon, quality = record.quality },
        uid = record.uid,
        price = offer,
        options = {
            { id = "accept", label = "Take the insulting offer", tone = "danger" },
            { id = "reject", label = "Absolutely not", tone = "primary" },
        },
    }
end

local function buildTax()
    local credits = ns.Shop.Credits()
    local amount = math.min(2000, math.max(25, U.floor(credits * 0.12)))
    return {
        key = "tax_audit",
        title = "Goblin Tax Audit",
        icon = "Interface\\Icons\\INV_Misc_Note_05",
        text = string.format(
            "An auditor with a clipboard explains that your 'mystery crate acquisitions' have been flagged. The matter can be resolved for %s credits.",
            U.comma(amount)),
        price = amount,
        options = {
            { id = "pay", label = "Pay the audit (" .. U.comma(amount) .. " credits)", tone = "primary", disabled = amount > credits },
            { id = "refuse", label = "Refuse, loudly", tone = "danger" },
        },
    }
end

local function buildMerchant()
    local info = randomSynthetic()
    local price = math.max(20, U.floor((info.value or 20) * 0.55))
    return {
        key = "traveling_merchant",
        title = "Traveling Merchant",
        icon = "Interface\\Icons\\INV_Misc_Bag_17",
        text = string.format(
            "A merchant's cart broke an axle outside. He will part with a %s for %s credits if it gets him home tonight.",
            info.name, U.comma(price)),
        synthetic = info,
        price = price,
        options = {
            { id = "buy", label = "Buy it (" .. U.comma(price) .. " credits)", tone = "primary", disabled = price > ns.Shop.Credits() or cannotStore() },
            { id = "decline", label = "Wish him luck", tone = "danger" },
        },
    }
end

local BUILDERS = {
    counterfeit = buildCounterfeit,
    thief = buildThief,
    celebrity = buildCelebrity,
    complainer = buildComplainer,
    mystery_delivery = buildMystery,
    rare_collector = buildRareCollector,
    rival_shop = buildRival,
    auction = buildAuction,
    lowball = buildLowball,
    tax_audit = buildTax,
    traveling_merchant = buildMerchant,
}

---------------------------------------------------------------------------
-- Runtime
---------------------------------------------------------------------------

function E.Pending()
    return DB.Get().shop.encounter
end

function E.PendingResult()
    return DB.Get().shop.encounterResult
end

function E.ClearResult()
    DB.Get().shop.encounterResult = nil
end

function E.Trigger(key)
    local db = DB.Get()
    if db.shop.encounter then return nil end
    local def = key and ns.Data.EncounterByKey[key] or ns.Data.EncounterPick(db.tier)
    if not def then return nil end

    local builder = BUILDERS[def.key]
    local event = builder and builder()
    if not event then
        -- Nothing to build from (empty shelves, no prior sale): try one other.
        local fallback = ns.Data.EncounterByKey.mystery_delivery
        if def.key == "mystery_delivery" then return nil end
        event = buildMystery()
        if not event then return nil end
    end

    db.shop.encounter = event
    db.shop.encounterResult = nil
    if ns.UI and ns.UI.ShowEncounter then ns.UI.ShowEncounter() end
    if ns.Sound then ns.Sound.Play("event") end
    return event
end

function E.Tick(dt)
    local db = DB.Get()
    if db.settings.paused then return end
    if db.shop.encounter then return end
    if ns.Compat.InCombat() then return end

    db.shop.encounterTimer = (db.shop.encounterTimer or 0) + dt
    if db.shop.encounterTimer < ROLL_INTERVAL then return end
    db.shop.encounterTimer = 0
    if U.chance(ROLL_CHANCE) then
        E.Trigger()
    end
end

local function finish(text, tone)
    local db = DB.Get()
    db.shop.encounter = nil
    db.shop.encounterResult = { text = text, tone = tone or "neutral", at = U.now() }
    db.stats.eventsResolved = (db.stats.eventsResolved or 0) + 1
    ns.Achievements.Check()
    return true, text
end

local function addSynthetic(info, options)
    local record, reason = ns.Inventory.Add(info, options or { source = "event" })
    if not record then return nil, reason end
    return record
end

function E.Resolve(optionId)
    local db = DB.Get()
    local event = db.shop.encounter
    if not event then return false, "Nothing is happening right now." end

    local key = event.key
    local record

    if key == "counterfeit" then
        if optionId == "buy" then
            if cannotStore() then
                return finish("There is no shelf space left. The seller shrugs and leaves.", "bad")
            end
            if not ns.Shop.Charge(event.price, "purchase") then
                return finish("You do not have enough credits. The seller takes the item elsewhere.", "bad")
            end
            local stored = ns.DB.Get().inventory[event.uid]
            local info = {
                id = stored and stored.id,
                name = event.item and event.item.name or "Unknown item",
                icon = event.item and event.item.icon,
                quality = event.item and event.item.quality or 2,
                ilvl = stored and stored.ilvl or 20,
                classID = stored and stored.classID or 15,
                subclassID = stored and stored.subclassID or 0,
                category = stored and stored.category or "misc",
                value = stored and stored.value or 30,
            }
            addSynthetic(info, { source = "counterfeit", counterfeit = true, forceNew = true })
            db.stats.counterfeitBought = (db.stats.counterfeitBought or 0) + 1
            ns.History.Add({ kind = "purchase", text = "Bought a suspicious " .. info.name, amount = -event.price })
            return finish("You bought it. Later, an appraiser laughs at you for a full minute.", "bad")
        end
        db.stats.counterfeitsRefused = (db.stats.counterfeitsRefused or 0) + 1
        ns.Shop.AddReputation(2)
        return finish("You refuse. The seller leaves quickly, which tells you everything.", "good")
    end

    if key == "thief" then
        local item = db.inventory[event.uid]
        if optionId == "confront" then
            if U.chance(event.stopChance or 0.4) then
                db.stats.theftsPrevented = (db.stats.theftsPrevented or 0) + 1
                ns.Shop.AddReputation(1)
                return finish("You block the door and extend a hand. The thief returns the goods and leaves at speed.", "good")
            end
            if item then ns.Inventory.Remove(event.uid, 1) end
            db.stats.thefts = (db.stats.thefts or 0) + 1
            ns.Shop.AddReputation(-2)
            return finish("They bolt past you. One item is gone, and so is your dignity.", "bad")
        end
        if item then ns.Inventory.Remove(event.uid, 1) end
        db.stats.thefts = (db.stats.thefts or 0) + 1
        return finish("You study the ceiling very carefully. The thief leaves with the goods.", "bad")
    end

    if key == "celebrity" then
        if optionId == "meet" then
            local customer = ns.Customers.TrySpawn({ celebrity = true, rare = true })
            if customer then
                ns.Customers.NotifyArrival(customer)
                ns.Shop.AddReputation(4)
                return finish("The chronicler takes notes while the celebrity browses. They are waiting at your counter.", "good")
            end
            return finish("They glance at the empty shelves and leave. Their fans buy nothing.", "bad")
        end
        ns.Shop.AddReputation(1)
        return finish("You politely send them away. The fans buy nothing, but nobody breaks anything.", "neutral")
    end

    if key == "complainer" then
        if optionId == "refund" then
            if not ns.Shop.Charge(event.price, "refund") then
                return finish("You cannot cover the refund. They leave a very loud review.", "bad")
            end
            db.stats.refunds = (db.stats.refunds or 0) + 1
            ns.Shop.AddReputation(4)
            ns.History.Add({ kind = "expense", text = "Refunded a dissatisfied customer", amount = -event.price })
            return finish("You refund them. They will tell three friends, which is the entire point.", "good")
        end
        ns.Shop.AddReputation(-6)
        return finish("You point at the sign. They point at your soul, then leave.", "bad")
    end

    if key == "mystery_delivery" then
        if optionId == "open" then
            if cannotStore() then return finish("No shelf space. The crate goes into the back room forever.", "bad") end
            local stored = addSynthetic(event.synthetic, { source = "mystery" })
            if not stored then return finish("The crate turns out to be mostly packing straw.", "neutral") end
            db.stats.mysteryItems = (db.stats.mysteryItems or 0) + 1
            return finish("Inside: " .. stored.name .. ". Worth a closer look.", "good")
        end
        ns.Shop.AddReputation(1)
        return finish("You send the ticking crate back. Wise, probably.", "neutral")
    end

    if key == "rare_collector" then
        if optionId == "meet" then
            local customer = ns.Customers.TrySpawn({ rare = true, personality = "rare_hunter", force = true })
            if customer then
                ns.Customers.NotifyArrival(customer)
                ns.Shop.AddReputation(3)
                return finish("You bring out the good stuff. They are waiting, and they are interested.", "good")
            end
            return finish("There is nothing suitable in stock. The figure leaves without a word.", "bad")
        end
        return finish("You close the shop for the afternoon. The figure is gone when you look again.", "neutral")
    end

    if key == "rival_shop" then
        if optionId == "undercut" then
            if not ns.Shop.Charge(event.price, "purchase") then
                return finish("You cannot afford the advertising war. The price war grinds on.", "bad")
            end
            ns.Market.StopEvent("goblin_market_crash")
            ns.Shop.AddReputation(5)
            ns.History.Add({ kind = "purchase", text = "Advertised against a rival pawnshop", amount = -event.price })
            return finish("Your sign is louder. Your leaflets are everywhere. Customers come back.", "good")
        end
        ns.Market.StartEvent("goblin_market_crash")
        return finish("The rival undercuts you into the ground. Luxury prices sag for a while.", "bad")
    end

    if key == "auction" then
        if optionId == "bid" then
            if not ns.Shop.Charge(event.price, "purchase") then
                return finish("The auctioneer does not accept promises.", "bad")
            end
            if cannotStore() then
                ns.Shop.Earn(event.price)
                return finish("You win, then realise there is no shelf space. The lot is resold immediately at cost.", "neutral")
            end
            if U.chance(event.winChance or 0.5) then
                local info = event.synthetic
                info.value = U.floor((info.value or 40) * 2.2)
                local stored = addSynthetic(info, { source = "auction" })
                db.stats.auctionsWon = (db.stats.auctionsWon or 0) + 1
                if stored then
                    ns.History.Add({ kind = "purchase", text = "Won an auction: " .. stored.name, amount = -event.price })
                    return finish("Your bid wins. " .. stored.name .. " is yours, and worth far more than you paid.", "good")
                end
            end
            ns.History.Add({ kind = "expense", text = "Lost an auction bid", amount = -event.price })
            return finish("You lose the lot to a goblin in an enormous hat. The bid is gone.", "bad")
        end
        return finish("You let the lot pass. It sells for a sum that makes your eye twitch.", "neutral")
    end

    if key == "lowball" then
        local item = db.inventory[event.uid]
        if optionId == "accept" then
            if not item then return finish("The item is already gone.", "neutral") end
            local name = item.name
            ns.Inventory.Remove(event.uid, 1)
            ns.Shop.Earn(event.price)
            db.stats.sales = (db.stats.sales or 0) + 1
            db.stats.revenue = (db.stats.revenue or 0) + event.price
            ns.History.Add({ kind = "sale", text = "Sold " .. name .. " for a pittance", amount = event.price })
            return finish("You take " .. U.comma(event.price) .. " credits for it. Everyone in the shop hears the laugh.", "bad")
        end
        ns.Shop.AddReputation(1)
        db.stats.rejected = (db.stats.rejected or 0) + 1
        return finish("Absolutely not. The customer respects it, oddly.", "good")
    end

    if key == "tax_audit" then
        if optionId == "pay" then
            if not ns.Shop.Charge(event.price, "expense") then
                return finish("You cannot pay. The auditor adds a note to your file.", "bad")
            end
            db.stats.expenses = (db.stats.expenses or 0) + event.price
            ns.Shop.AddReputation(2)
            ns.History.Add({ kind = "expense", text = "Paid a tax audit", amount = -event.price })
            return finish("You pay. The auditor looks disappointed, then writes 'cooperative'.", "neutral")
        end
        ns.Shop.AddReputation(-12)
        return finish("You refuse loudly. A larger audit is scheduled for next week.", "bad")
    end

    if key == "traveling_merchant" then
        if optionId == "buy" then
            if cannotStore() then return finish("No shelf space, and no room in the cart either. He moves on.", "bad") end
            if not ns.Shop.Charge(event.price, "purchase") then
                return finish("You cannot afford it. He shrugs and pushes the cart away.", "bad")
            end
            local stored = addSynthetic(event.synthetic, { source = "merchant" })
            ns.History.Add({ kind = "purchase", text = "Bought " .. (stored and stored.name or "goods") .. " from a merchant", amount = -event.price })
            return finish("A fair deal for once: " .. (stored and stored.name or "the goods") .. " joins your shelves.", "good")
        end
        return finish("You wish him luck. He will remember the shop that did not help.", "neutral")
    end

    return finish("Nothing happens.", "neutral")
end

function E.Status()
    local pending = E.Pending()
    if pending then return "pending" end
    local result = E.PendingResult()
    if result then return "result" end
    return "idle"
end
