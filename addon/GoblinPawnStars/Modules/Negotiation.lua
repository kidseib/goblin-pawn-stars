--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Negotiation.lua
    The heart of the minigame. Customers have a hidden ceiling derived from the
    item's market value, their personality, their budget and your reputation.
    Counters are probabilistic, never a guaranteed win.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local N = {}
ns.Negotiation = N

---------------------------------------------------------------------------
-- State helpers
---------------------------------------------------------------------------

function N.Active()
    return DB.Get().shop.current
end

function N.Item()
    local customer = N.Active()
    if not customer then return nil end
    return DB.Get().inventory[customer.itemUid]
end

function N.Personality()
    return ns.Customers.Personality(N.Active())
end

function N.MarketPrice()
    local item = N.Item()
    return item and ns.Market.Value(item) or 0
end

function N.Offer()
    local customer = N.Active()
    return customer and customer.offer or 0
end

function N.PatienceRatio()
    return ns.Customers.PatienceRatio(N.Active())
end

function N.Unlocked()
    local db = DB.Get()
    return db.tier >= 2 or (db.employees.appraiser or 0) > 0
end

function N.Suggested(kind)
    local value = N.MarketPrice()
    if value <= 0 then return 0 end
    if kind == "fair" then return U.floor(value * 1.02) end
    if kind == "greedy" then return U.floor(value * 1.32) end
    return U.floor(value * 0.92)
end

local function endVisit(customer, result, text)
    local db = DB.Get()
    db.shop.current = nil
    ns.Customers.RecordVisit(customer, result, text)
    return true
end

---------------------------------------------------------------------------
-- Sale completion
---------------------------------------------------------------------------

local function completeSale(price, method)
    local db = DB.Get()
    local customer = db.shop.current
    if not customer then return nil end

    local record = db.inventory[customer.itemUid]
    if not record then
        db.shop.current = nil
        return nil
    end

    local baseValue = ns.Market.Value(record)
    local itemName = record.name

    -- Daily customer request bonus, paid once per day.
    local requestBonus = 0
    local request = ns.Shop.DailyRequest()
    if request and not request.fulfilled and request.category == record.category then
        requestBonus = request.bonus or 0
        request.fulfilled = true
    end

    price = math.max(1, U.floor(price * (1 + requestBonus)))

    ns.Inventory.Remove(customer.itemUid, 1)

    db.credits = (db.credits or 0) + price
    db.stats.earned = (db.stats.earned or 0) + price
    db.stats.revenue = (db.stats.revenue or 0) + price
    db.stats.sales = (db.stats.sales or 0) + 1
    db.stats.customersServed = (db.stats.customersServed or 0) + 1
    if method == "counter" then
        db.stats.counterSuccess = (db.stats.counterSuccess or 0) + 1
    end
    if customer.rare then
        db.stats.rareSales = (db.stats.rareSales or 0) + 1
    end
    if price > (db.stats.bestSale or 0) then db.stats.bestSale = price end

    local multiple = baseValue > 0 and (price / baseValue) or 0
    if multiple > (db.stats.bestMultiple or 0) then
        db.stats.bestMultiple = math.floor(multiple * 100) / 100
    end

    db.shop.lastSale = {
        itemName = itemName,
        price = price,
        at = U.now(),
        personality = customer.personality,
    }

    if ns.Throughput then ns.Throughput.RecordSale(price) end

    local reputation = method == "autosale" and 1 or (customer.rare and 6 or 3)
    ns.Shop.AddReputation(reputation)

    ns.Customers.RecordVisit(customer, "sale", string.format(
        "bought %s for %s credits", itemName, U.comma(price)))
    db.shop.current = nil

    -- Named regulars advance only after a completed sale, so their story is
    -- paid for by stock leaving the shelves like every other customer.
    if ns.Regular and customer.regular then
        ns.Regular.OnServed(customer)
    end

    ns.History.Add({
        kind = "sale",
        text = string.format("%s bought %s", customer.name, itemName),
        amount = price,
        icon = record.icon,
        detail = string.format("Market value %s · %s %s",
            U.comma(baseValue),
            method == "counter" and "counteroffer"
                or (method == "autosale" and "salesperson sale" or "accepted offer"),
            requestBonus > 0 and "(daily request bonus)" or ""),
    })

    if ns.Sound then ns.Sound.Play("coin") end
    ns.Achievements.Check()

    return price, itemName, requestBonus > 0
end

---------------------------------------------------------------------------
-- Player actions
---------------------------------------------------------------------------

-- Called by the salesperson on the waiting queue. The price is a discount to
-- live market value, never to a non-existent sale, and the item is consumed by
-- completeSale just like a counter sale.
function N.AutoSell(customer, margin)
    local db = DB.Get()
    if not customer or db.shop.current then return false end

    local record = db.inventory[customer.itemUid]
    if not record then return false end

    local queued = false
    for index, entry in ipairs(db.shop.waiting) do
        if entry == customer then
            table.remove(db.shop.waiting, index)
            queued = true
            break
        end
    end
    if not queued then return false end

    local value = ns.Market.Value(record)
    local price = math.max(1, U.floor(value * U.clamp(tonumber(margin) or 0.76, 0.5, 0.95)))
    if customer.maxPay and customer.maxPay > 0 and price > customer.maxPay then
        price = math.max(1, math.floor(customer.maxPay))
    end

    db.shop.current = customer
    local soldPrice, itemName = completeSale(price, "autosale")
    if not soldPrice then
        db.shop.current = nil
        return false
    end

    db.stats.autoSales = (db.stats.autoSales or 0) + 1
    db.stats.autoRevenue = (db.stats.autoRevenue or 0) + soldPrice
    return true, soldPrice, itemName
end

function N.Accept()
    local customer = N.Active()
    if not customer then return false, "Nobody is at the counter." end
    local price = completeSale(customer.offer, "accept")
    if not price then return false, "That item is no longer in stock." end
    local line = ns.Data.PersonalityLine(N.Personality(), "accept", {
        price = U.comma(price),
    })
    ns.Customers.RecordVisit(customer, "sale", line)
    return true, { result = "sold", price = price, dialogue = line }
end

function N.Reject()
    local db = DB.Get()
    local customer = N.Active()
    if not customer then return false, "Nobody is at the counter." end

    db.stats.rejected = (db.stats.rejected or 0) + 1
    local line = ns.Customers.LeaveDialogue(customer, "leave")
    endVisit(customer, "rejected", line)
    if ns.Sound then ns.Sound.Play("reject") end
    return true, { result = "rejected", dialogue = line }
end

function N.Counter(amount)
    local db = DB.Get()
    local customer = N.Active()
    local record = N.Item()
    if not customer or not record then return false, "Nobody is at the counter." end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return false, "Type a counteroffer first."
    end
    amount = math.floor(amount)

    local personality = N.Personality() or ns.Data.Personalities[1]
    local value = ns.Market.Value(record)
    local bonuses = ns.Shop.Bonuses()
    local maxPay = customer.maxPay or value

    customer.rounds = (customer.rounds or 0) + 1
    db.stats.offersSeen = (db.stats.offersSeen or 0) + 1
    db.stats.counteroffers = (db.stats.counteroffers or 0) + 1

    local function response(result, dialogue, extra)
        local payload = { result = result, dialogue = dialogue, offer = customer.offer }
        if extra then
            for key, entry in pairs(extra) do payload[key] = entry end
        end
        return payload
    end

    -- Absurd demands insult the customer and end the conversation.
    if amount > maxPay * 1.6 and amount > value * 1.75 then
        local line = ns.Customers.LeaveDialogue(customer, "leave")
        db.stats.counterFail = (db.stats.counterFail or 0) + 1
        endVisit(customer, "insulted", line)
        if ns.Sound then ns.Sound.Play("reject") end
        return true, response("insulted", line, { price = 0 })
    end

    if amount <= maxPay then
        local margin = (maxPay - amount) / math.max(1, maxPay)
        local chance = 0.26
            + margin * 1.15
            - (personality.stubborn or 0) * 0.30
            + (bonuses.haggle or 0)
            + (customer.appraisalBonus or 0)
            + (ns.Shop.Reputation() / 1000) * 0.12
        chance = U.clamp(chance, 0.05, 0.94)

        if U.chance(chance) then
            local price = completeSale(amount, "counter")
            if not price then return false, "That item is no longer in stock." end
            local line = ns.Data.PersonalityLine(personality, "accept", { price = U.comma(price) })
            ns.Customers.RecordVisit(customer, "sale", line)
            return true, response("accepted", line, { price = price })
        end

        customer.patience = math.max(0, (customer.patience or 0) - 1)
        db.stats.counterFail = (db.stats.counterFail or 0) + 1

        if customer.patience <= 0 then
            local line = ns.Customers.LeaveDialogue(customer, "leave")
            endVisit(customer, "walked", line)
            if ns.Sound then ns.Sound.Play("reject") end
            return true, response("left", line, { price = 0 })
        end

        -- They nudge their offer upward rather than storming off immediately.
        local raised = U.round((customer.offer or 0) * (1 + U.randomBetween(0.07, 0.19)), 5)
        customer.offer = math.min(maxPay, math.max(customer.offer or 0, raised))

        if customer.offer >= amount then
            local price = completeSale(customer.offer, "counter")
            if not price then return false, "That item is no longer in stock." end
            local line = ns.Data.PersonalityLine(personality, "accept", { price = U.comma(price) })
            ns.Customers.RecordVisit(customer, "sale", line)
            return true, response("accepted", line, { price = price })
        end

        local line = ns.Data.PersonalityLine(personality, "refuse", {
            counter = U.comma(amount),
        })
        customer.dialogue = line
        return true, response("declined", line, { price = 0 })
    end

    -- Above the hidden ceiling: they push back once, then can walk away.
    customer.patience = math.max(0, (customer.patience or 0) - 1)
    db.stats.counterFail = (db.stats.counterFail or 0) + 1

    if customer.patience <= 0 then
        local line = ns.Customers.LeaveDialogue(customer, "leave")
        endVisit(customer, "walked", line)
        if ns.Sound then ns.Sound.Play("reject") end
        return true, response("left", line, { price = 0 })
    end

    customer.offer = math.min(maxPay, U.round((customer.offer or 0) * 1.08, 5))
    local line = ns.Data.PersonalityLine(personality, "refuse", { counter = U.comma(amount) })
    customer.dialogue = line
    if ns.Sound then ns.Sound.Play("reject") end
    return true, response("declined", line, { price = 0 })
end

function N.Appraise()
    local db = DB.Get()
    local customer = N.Active()
    local record = N.Item()
    if not customer or not record then return false, "Nobody to appraise for." end
    if not N.Unlocked() then
        return false, "You need a proper shop or an appraiser to do that."
    end
    if customer.appraised then
        return false, "You already appraised this piece for them."
    end

    local accuracy = ns.Shop.Appraisal()
    customer.appraised = true
    customer.appraisalBonus = 0.04 + (accuracy / 100) * 0.06
    db.stats.appraisals = (db.stats.appraisals or 0) + 1

    local value = ns.Market.Value(record)
    local exact = U.chance(accuracy / 100)
    local spread = (1 - accuracy / 100) * 0.3
    local lower = math.max(1, U.floor(value * (1 - spread)))
    local upper = U.floor(value * (1 + spread))

    if exact then
        customer.revealed = true
        lower, upper = value, value
    end

    local forgeryChance = U.clamp(accuracy / 100 + (ns.Shop.Bonuses().forgery or 0), 0, 0.96)
    local fake = record.counterfeit and U.chance(forgeryChance)

    ns.Achievements.Check()

    return true, {
        exact = exact,
        lower = lower,
        upper = upper,
        value = value,
        counterfeit = fake and true or false,
        ceiling = exact and customer.maxPay or nil,
    }
end

function N.Close()
    local customer = N.Active()
    if not customer then return false end
    local line = "stepped away from the counter"
    endVisit(customer, "left", line)
    return true
end

function N.WindowsLeft()
    local customer = N.Active()
    if not customer then return 0 end
    return math.max(0, customer.patience or 0)
end

function N.Summary()
    local customer = N.Active()
    if not customer then return nil end
    local record = N.Item()
    return {
        customer = customer,
        personality = N.Personality(),
        item = record,
        price = record and ns.Market.Value(record) or 0,
        offer = customer.offer or 0,
        patience = N.PatienceRatio(),
        appraised = customer.appraised,
    }
end
