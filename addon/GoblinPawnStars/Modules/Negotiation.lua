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

    local low = U.floor(value * 0.92)
    local fair = U.floor(value * 1.02)
    local greedy = U.floor(value * 1.32)

    -- The offer is visible and the ceiling is not: every preset must be a real
    -- upward counter, never a price below what the customer already offered.
    local offer = tonumber(N.Offer()) or 0
    if offer > 0 then
        low = math.max(low, offer + 1)
        fair = math.max(fair, low + 1)
        greedy = math.max(greedy, fair + 1)
    end

    if kind == "fair" then return fair end
    if kind == "greedy" then return greedy end
    return low
end

--[[ Counteroffer odds -------------------------------------------------------
    N.Counter rolls exactly once. N.Odds is the same formula, exposed so the
    window can print the real number beside the price instead of a mood. The
    window and the roll must never disagree: that is the worst bug this
    minigame can have.
--------------------------------------------------------------------------- ]]
--[[ Wager terms memo -------------------------------------------------------
    The window refreshes once a second while it is open, and it asks for the
    wager every time. The terms only change when the customer does, so the last
    answer is kept in one small table keyed on the four values that decide it.
    Repeats cost three comparisons and no allocation; a new customer, a raised
    offer or a spent wager all miss the memo and recompute.
--------------------------------------------------------------------------- ]]
local wagerMemo = {}
local function wagerFor(customer)
    local id = customer.id
    local offer = customer.offer
    local maxPay = customer.maxPay
    local gambled = customer.gambled and true or false
    if wagerMemo.id == id and wagerMemo.offer == offer
        and wagerMemo.maxPay == maxPay and wagerMemo.gambled == gambled then
        return wagerMemo.terms
    end
    wagerMemo.id, wagerMemo.offer, wagerMemo.maxPay, wagerMemo.gambled = id, offer, maxPay, gambled
    wagerMemo.terms = ns.Gamble.Terms(customer)
    return wagerMemo.terms
end

function N.Odds(amount)
    local customer = N.Active()
    local record = N.Item()
    if not customer or not record then return nil end

    local maxPay = tonumber(customer.maxPay) or 0
    local value = ns.Market.Value(record)
    amount = tonumber(amount)

    if not amount or amount <= 0 then
        return { chance = 0, percent = 0, label = "PICK A PRICE", tone = "dim",
            kind = "none", ceiling = maxPay }
    end
    amount = math.floor(amount)

    local personality = N.Personality() or ns.Data.Personalities[1]
    local bonuses = ns.Shop.Bonuses()

    -- An absurd demand ends the visit outright; there is nothing to roll.
    if amount > maxPay * 1.6 and amount > value * 1.75 then
        return { chance = 0, percent = 0, label = "INSULT", tone = "red",
            kind = "insult", ceiling = maxPay }
    end

    -- Above the hidden ceiling they only push back, so the roll never happens.
    if amount > maxPay then
        return { chance = 0, percent = 0, label = "ABOVE THEIR LIMIT", tone = "red",
            kind = "over", ceiling = maxPay }
    end

    local margin = (maxPay - amount) / math.max(1, maxPay)
    local chance = 0.26
        + margin * 1.15
        - (personality.stubborn or 0) * 0.30
        + (bonuses.haggle or 0)
        + (customer.appraisalBonus or 0)
        + (ns.Shop.Reputation() / 1000) * 0.12
        + (customer.eager and 0.30 or 0)
    chance = U.clamp(chance, 0.05, 0.94)

    local label, tone
    if chance >= 0.78 then label, tone = "SURE THING", "green"
    elseif chance >= 0.55 then label, tone = "GOOD ODDS", "green"
    elseif chance >= 0.32 then label, tone = "COIN FLIP", "gold"
    elseif chance >= 0.15 then label, tone = "LONG SHOT", "gold"
    else label, tone = "DESPERATE", "red" end

    return {
        chance = chance,
        percent = math.floor(chance * 100 + 0.5),
        label = label,
        tone = tone,
        kind = "reach",
        ceiling = maxPay,
    }
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

-- `cleanDeal` is the session streak's one-shot perk: a fraction the customer
-- rounds the agreed price up by. It only ever applies to a sale that is already
-- happening (the unit still leaves through Inventory.Remove), it is spent on the
-- next landed counter and it cannot be banked across a reload, so the money it
-- adds is bounded by one sale in every five good haggles.
-- `label` overrides the ledger's description of the method for the odd case
-- that is still a sale but is not one of the four regular routes (the wager).
local function completeSale(price, method, cleanDeal, label)
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

    local bonusAdjustedPrice = price * (1 + requestBonus + (tonumber(cleanDeal) or 0))
    price = math.max(1, U.floor(method == "questsale" and bonusAdjustedPrice / 3 or bonusAdjustedPrice))

    ns.Inventory.Remove(customer.itemUid, 1)

    -- The wallet delta is the only figure the UI is allowed to display. The
    -- request bonus and rounding are already inside `price`, so this equals the
    -- price in every normal sale and cannot drift from what the player received.
    local beforeCredits = db.credits or 0
    db.credits = beforeCredits + price
    price = db.credits - beforeCredits
    -- The one place a regular is born: a completed sale near their own ceiling.
    if ns.Regulars then ns.Regulars.Remember(customer, price) end
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

    local automated = method == "autosale" or method == "questsale"
    local reputation = automated and 1 or (customer.rare and 6 or 3)
    ns.Shop.AddReputation(reputation)

    ns.Customers.RecordVisit(customer, "sale", string.format(
        "bought %s for %s credits", itemName, U.comma(price)))
    db.shop.current = nil

    -- Named regulars advance only after a completed sale, so their story is
    -- paid for by stock leaving the shelves like every other customer.
    if ns.Regular and customer.regular then
        ns.Regular.OnServed(customer)
    end

    local how = label
    if not how then
        if method == "counter" then
            how = cleanDeal and "counteroffer · clean deal" or "counteroffer"
        elseif method == "questsale" then
            how = "questing auto-sale"
        elseif method == "autosale" then
            how = "salesperson sale"
        else
            how = "accepted offer"
        end
    end

    ns.History.Add({
        kind = "sale",
        text = string.format("%s bought %s", customer.name, itemName),
        amount = price,
        icon = record.icon,
        detail = string.format("Market value %s · %s %s",
            U.comma(baseValue), how,
            requestBonus > 0 and "(daily request bonus)" or ""),
    })

    if ns.Sound then ns.Sound.Play("coin") end
    ns.Achievements.Check()

    return price, itemName, requestBonus > 0
end

---------------------------------------------------------------------------
-- Player actions
---------------------------------------------------------------------------

-- Both automatic modes consume an item through completeSale. The salesperson
-- discounts live market value. Questing takes a third of the maximum offer.
function N.AutoSell(customer, margin, questing)
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
    local maxPay = tonumber(customer.maxPay)
    local price
    if questing then
        price = maxPay and maxPay > 0 and maxPay or value
    else
        price = math.max(1, U.floor(value * U.clamp(tonumber(margin) or 0.76, 0.5, 0.95)))
        if maxPay and maxPay > 0 then price = math.min(price, math.max(1, math.floor(maxPay))) end
    end

    db.shop.current = customer
    local soldPrice, itemName = completeSale(price, questing and "questsale" or "autosale")
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
    local line = ns.Data.Dialogue.Line(customer, "accept", { price = U.comma(price) })
    customer.dialogue = line
    ns.Customers.RecordVisit(customer, "sale", line)
    return true, { result = "sold", price = price, dialogue = line }
end

function N.Reject()
    local db = DB.Get()
    local customer = N.Active()
    if not customer then return false, "Nobody is at the counter." end

    db.stats.rejected = (db.stats.rejected or 0) + 1
    local line = ns.Customers.LeaveDialogue(customer, "leave", {
        furious = (tonumber(customer.patience) or 0) <= 0,
    })
    customer.dialogue = line
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
    local odds = N.Odds(amount)
    local maxPay = (odds and odds.ceiling) or customer.maxPay or 0

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
    if odds and odds.kind == "insult" then
        local line = ns.Customers.LeaveDialogue(customer, "leave", { insult = true })
        customer.dialogue = line
        db.stats.counterFail = (db.stats.counterFail or 0) + 1
        endVisit(customer, "insulted", line)
        if ns.Sound then ns.Sound.Play("reject") end
        return true, response("insulted", line, { price = 0 })
    end

    if odds and odds.kind == "reach" then
        if U.chance(odds.chance) then
            -- Spend the clean deal only if the sale really completes. The streak
            -- then starts again from this win, so the perk is never re-armed by
            -- the same sale that spent it.
            local cleanBonus = ns.Streak.Armed() and ns.Streak.Bonus() or 0
            local price = completeSale(amount, "counter", cleanBonus > 0 and cleanBonus or nil)
            if not price then return false, "That item is no longer in stock." end
            if cleanBonus > 0 then
                ns.Streak.Consume()
                ns.Shop.AddReputation(tonumber(ns.Data.Streak and ns.Data.Streak.perkRep) or 2)
            end
            ns.Streak.Hit()
            local line = ns.Data.Dialogue.Line(customer, "accept",
                { price = U.comma(price) }, { counter = true })
            customer.dialogue = line
            ns.Customers.RecordVisit(customer, "sale", line)
            return true, response("accepted", line,
                { price = price, cleanDeal = cleanBonus > 0 and cleanBonus or nil })
        end

        -- A botched counter ends the hot hand but keeps any armed perk.
        ns.Streak.Miss()
        customer.patience = math.max(0, (customer.patience or 0) - 1)
        db.stats.counterFail = (db.stats.counterFail or 0) + 1

        if customer.patience <= 0 then
            local line = ns.Customers.LeaveDialogue(customer, "leave", { furious = true })
            customer.dialogue = line
            endVisit(customer, "walked", line)
            if ns.Sound then ns.Sound.Play("reject") end
            return true, response("left", line, { price = 0 })
        end

        -- They nudge their offer upward rather than storming off immediately.
        local raised = U.round((customer.offer or 0) * (1 + U.randomBetween(0.07, 0.19)), 5)
        customer.offer = math.min(maxPay, math.max(customer.offer or 0, raised))

        if customer.offer >= amount then
            local cleanBonus = ns.Streak.Armed() and ns.Streak.Bonus() or 0
            local price = completeSale(customer.offer, "counter", cleanBonus > 0 and cleanBonus or nil)
            if not price then return false, "That item is no longer in stock." end
            if cleanBonus > 0 then
                ns.Streak.Consume()
                ns.Shop.AddReputation(tonumber(ns.Data.Streak and ns.Data.Streak.perkRep) or 2)
            end
            ns.Streak.Hit()
            local line = ns.Data.Dialogue.Line(customer, "accept",
                { price = U.comma(price) }, { counter = true })
            customer.dialogue = line
            ns.Customers.RecordVisit(customer, "sale", line)
            return true, response("accepted", line,
                { price = price, cleanDeal = cleanBonus > 0 and cleanBonus or nil })
        end

        local line = ns.Data.Dialogue.Line(customer, "refuse", {
            counter = U.comma(amount),
        })
        customer.dialogue = line
        return true, response("declined", line, { price = 0 })
    end

    -- Above the hidden ceiling: they push back once, then can walk away.
    ns.Streak.Miss()
    customer.patience = math.max(0, (customer.patience or 0) - 1)
    db.stats.counterFail = (db.stats.counterFail or 0) + 1

    if customer.patience <= 0 then
        local line = ns.Customers.LeaveDialogue(customer, "leave")
        endVisit(customer, "walked", line)
        if ns.Sound then ns.Sound.Play("reject") end
        return true, response("left", line, { price = 0 })
    end

    customer.offer = math.min(maxPay, U.round((customer.offer or 0) * 1.08, 5))
    local line = ns.Data.Dialogue.Line(customer, "refuse",
        { counter = U.comma(amount) }, { over = true })
    customer.dialogue = line
    if ns.Sound then ns.Sound.Play("reject") end
    return true, response("declined", line, { price = 0 })
end

--[[ Double or nothing ------------------------------------------------------
    A desperate buyer bets their own purse: win and they pay the most they were
    ever going to pay, lose and they pay a discount and the shop's name takes a
    small knock. Once per customer, and it is priced to be slightly worse than
    accepting, so it is a temptation rather than the correct play.

    The sale still goes through completeSale: the unit leaves the shelves and the
    credits come from a customer. A lost flip never touches gold that was not on
    the table.
--------------------------------------------------------------------------- ]]
function N.Wager()
    local customer = N.Active()
    if not customer then return false, "Nobody is at the counter." end

    local terms = wagerFor(customer)
    if not terms then return false, "There is no wager on the table." end
    local personality = N.Personality()

    -- Marked before the roll: a flip cannot be rerolled, not even across the
    -- reload that restores this customer from the save.
    customer.gambled = true

    local won = ns.Gamble.Roll(terms)
    local price = won and terms.prize or terms.loss
    local paid = completeSale(price, "wager", nil,
        won and "double or nothing · won" or "double or nothing · lost")
    if not paid then return false, "That item is no longer in stock." end

    -- A lost flip costs standing, never gold that was already earned.
    if not won and terms.sting > 0 then ns.Shop.AddReputation(-terms.sting) end

    local line = ns.Gamble.Say(personality, won and "wagerWin" or "wagerLose",
        { price = U.comma(paid) })
    customer.dialogue = line
    ns.Customers.RecordVisit(customer, "sale", line)

    return true, {
        result = "sold",
        price = paid,
        dialogue = line,
        wager = true,
        won = won and true or false,
        terms = terms,
    }
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
        -- nil when this customer has no wager to offer (wrong archetype, already
        -- used it, or there is no gap between their offer and their ceiling).
        wager = wagerFor(customer),
    }
end
