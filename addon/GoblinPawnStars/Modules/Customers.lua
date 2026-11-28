--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Customers.lua
    Generates customers, decides what they want, how much they can pay and when
    the next one walks through the door.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local C = {}
ns.Customers = C

-- The salesperson works the waiting queue on a timer. This is deliberately
-- slower than a player at the counter and sells below the best haggled price.
local autoTimer = 8

-- The first three visitors are scripted, and the first one is guaranteed to be
-- worth countering. A new player's opening haggling round should be a win: the
-- odds readout has nothing to teach if the first counter is a coin flip.
local ONBOARDING = { "gullible", "trader", "impatient" }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function pickItem(personality)
    local db = DB.Get()
    local pool = {}
    for _, record in pairs(db.inventory) do
        local weight = 1
        if ns.Util.contains(personality.prefer, record.category) then
            weight = weight + 2.5
        end
        weight = weight + (tonumber(record.quality) or 1) * 0.35
        if record.counterfeit then weight = weight * 0.25 end
        pool[#pool + 1] = { record = record, weight = weight }
    end
    if #pool == 0 then return nil end
    local picked = U.weightedPick(pool, function(entry) return entry.weight end)
    return picked and picked.record or nil
end

local function requestForToday()
    local request = ns.Shop.DailyRequest()
    return request
end

local function buildCustomer(options)
    options = options or {}
    local db = DB.Get()
    local tier = ns.Data.Tier(db.tier)
    local personality = options.personality and ns.Data.PersonalityByKey[options.personality]
        or ns.Data.PersonalityPick(db.tier)
    if not personality then personality = ns.Data.Personalities[1] end

    local identity = ns.Data.GenerateIdentity()
    if options.name then identity.name = options.name end
    if options.race then identity.race = options.race end
    if options.class then identity.class = options.class end
    if options.occupation then identity.occupation = options.occupation end
    if options.greeting then identity.greeting = options.greeting end
    local bonuses = ns.Shop.Bonuses()

    -- Occasional idle chatter keeps repeat visits from reading identically.
    if not options.regular and U.chance(0.22) and #ns.Data.IdleChatter > 0 then
        identity.greeting = identity.greeting .. " " .. ns.Data.IdleChatter[math.random(#ns.Data.IdleChatter)]
    end

    local rare = options.rare
    if rare == nil then
        rare = U.chance(ns.Shop.RareChance() + (personality.rare or 0) * 0.5)
    end

    local budgetFactor = U.randomBetween(0.88, 1.22)
    if rare then budgetFactor = budgetFactor * 2.1 end
    if options.celebrity then budgetFactor = budgetFactor * 2.8 end

    local budget = math.floor((tier.budget or 280) * (personality.budget or 1) * budgetFactor)

    local record = options.record or pickItem(personality)
    if not record then return nil, "no stock" end

    local value = ns.Market.Value(record)
    local repFactor = ns.Shop.ReputationFactor()
    local offerBonus = 1 + (bonuses.offer or 0)
    local repPerks = ns.Shop.ReputationPerks()
    local willingness = personality.maxWill * repFactor * offerBonus * U.randomBetween(0.94, 1.08)
        * (1 + (repPerks.offer or 0))
    -- Campaign rewards are permanent offer bonuses, so they lift what customers
    -- will pay for stock. They never create credits outside a completed sale.
    if ns.Campaign then willingness = willingness * (1 + ns.Campaign.OfferBonus()) end
    if rare then willingness = willingness * 1.12 end
    -- The scripted first buyer is keen, so the counter the window suggests lands.
    if options.firstDeal then willingness = math.max(willingness, 1.45) end
    -- A remembered customer pays the loyalty premium, if they have earned it.
    local returning = math.max(0, math.floor(tonumber(options.returning) or 0))
    if returning > 0 then
        local _, loyaltyOffer = ns.Regulars.Loyalty(returning)
        willingness = willingness * loyaltyOffer
    end
    -- A regular who came back for the exact shelf they asked for is motivated:
    -- they will pay over live market value, up to the budget they named. A
    -- patron keeps a small permanent lift. Both only ever raise a real sale.
    local order = options.order
    local orderData = ns.Data.Regulars
    if order then
        willingness = math.max(willingness,
            order.patron and (orderData.patronPay or 1.5) or (orderData.orderPay or 1.35))
        local named = tonumber(options.orderBudget) or 0
        if named > 0 then budget = math.max(budget, named) end
    end
    if options.patron then
        willingness = willingness * (orderData.patronOffer or 1.02)
    end

    -- Hidden ceiling: what this customer would actually pay for this item.
    local maxPay = math.floor(math.min(
        value * willingness,
        budget,
        value * 2.8
    ))
    maxPay = math.max(1, maxPay)
    if options.firstDeal then
        -- Their own budget grows to cover it; nothing is granted outside the sale.
        maxPay = math.max(maxPay, U.floor(value * 1.45))
        budget = math.max(budget, maxPay)
    end

    local opening = U.randomBetween(personality.opening[1], personality.opening[2])
    -- The scripted first buyer opens low enough to leave a visible upward counter.
    if options.firstDeal then opening = math.min(opening, 0.45) end
    -- A special order is a stated price, not a haggle: they open near their
    -- ceiling, so accepting it is the reward for having held the stock.
    if order then opening = math.max(opening, 0.9) end
    local offer = U.round(maxPay * opening, 5)
    offer = U.clamp(offer, 1, maxPay)

    local patience = (personality.patience or 2)
        + math.floor((bonuses.patience or 0) + (repPerks.patience or 0))
    if rare then patience = patience + 1 end
    if options.celebrity then patience = patience + 1 end
    if returning > 0 then
        local loyaltyPatience = ns.Regulars.Loyalty(returning)
        patience = patience + loyaltyPatience
    end
    -- Someone who came back for a piece waits a little longer for it.
    if order then patience = patience + 1 end
    patience = math.max(1, patience)

    db.shop.nextCustomerId = (db.shop.nextCustomerId or 0) + 1

    local customer = {
        id = db.shop.nextCustomerId,
        name = identity.name,
        race = identity.race,
        class = identity.class,
        occupation = identity.occupation,
        personality = personality.key,
        greeting = identity.greeting,
        budget = budget,
        maxPay = maxPay,
        offer = offer,
        patience = patience,
        patienceMax = patience,
        rounds = 0,
        valueBias = willingness,
        itemUid = record.uid,
        rare = rare and true or false,
        celebrity = options.celebrity and true or false,
        eager = options.firstDeal and true or false,
        appraised = false,
        revealed = false,
        appraisalBonus = 0,
        createdAt = U.now(),
        dialogue = identity.greeting,
        seller = options.seller and true or false,
        regular = options.regular and true or false,
        regularVisit = options.regularVisit,
        returning = returning > 0 and returning or nil,
        patron = options.patron and true or nil,
        -- Collecting an order, or having just asked for one (orderCategory).
        order = order and true or nil,
        orderCategory = order and order.category
            or (options.orderAsk and options.orderAsk.category) or nil,
        orderBudget = order and tonumber(options.orderBudget) or nil,
    }

    return customer, record, personality
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function C.Waiting()
    return DB.Get().shop.waiting
end

function C.Current()
    return DB.Get().shop.current
end

function C.WaitingSlots()
    return ns.Shop.WaitingSlots()
end

function C.CanAccept()
    return #DB.Get().shop.waiting < ns.Shop.WaitingSlots()
end

function C.ArrivalBlocker()
    if DB.Get().settings.paused == true then return "Paused" end
    if ns.Inventory.Count() == 0 then return "No stock" end
    if not C.CanAccept() then return "Queue full" end
    if ns.Compat.InCombat() then return "In combat" end
end

function C.Personality(customer)
    if not customer then return nil end
    return ns.Data.PersonalityByKey[customer.personality]
end

function C.Item(customer)
    if not customer then return nil end
    return DB.Get().inventory[customer.itemUid]
end

function C.TrySpawn(options)
    local db = DB.Get()
    if ns.Inventory.Count() == 0 then return nil, "no stock" end
    if #db.shop.waiting >= ns.Shop.WaitingSlots() then return nil, "shop is full" end
    if db.shop.current and options and options.force then
        -- Only used by encounters with a dedicated "invite" flow.
    end

    -- Scripted opening customers, before the named-regular path can claim them.
    if not options then
        local arrived = tonumber(db.stats.customers) or 0
        local scripted = ONBOARDING[arrived + 1]
        if scripted and (db.stats.sales or 0) == 0 then
            options = { personality = scripted, firstDeal = (arrived == 0) }
        end
    end

    -- A due named regular replaces one ordinary arrival. This is still a
    -- normal customer with a normal budget; her sale consumes normal stock.
    if not options and ns.Regular then
        options = ns.Regular.SpawnOptions(false)
    end

    -- A face the shop remembers can take an ordinary arrival instead.
    if not options and ns.Regulars then
        options = ns.Regulars.SpawnOptions()
    end

    local customer, record = buildCustomer(options)
    if not customer then return nil, record end

    db.shop.waiting[#db.shop.waiting + 1] = customer
    -- The greeting is chosen with the item in hand, so a collector looking at a
    -- gem and a collector looking at a rusty fork do not say the same thing. A
    -- special order names the shelf they came back for.
    local greetVars = { offer = customer.offer }
    if customer.orderCategory then
        greetVars.category = ns.Data.CategoryName(customer.orderCategory)
    end
    customer.dialogue = ns.Data.Dialogue.Line(customer, "greet", greetVars)

    db.stats.customers = (db.stats.customers or 0) + 1
    db.shop.lastArrivalAt = db.stats.playtime or 0
    return customer, record
end

function C.NotifyArrival(customer)
    local arrival = ns.UI and ns.UI.CustomerArrival
    if DB.Get().settings.customerArrival ~= "Off" then
        local shown
        if arrival then
            local ok, result = pcall(arrival.Show, customer)
            shown = ok and result
            if not ok then
                pcall(arrival.Hide)
                ns.Debug("customer notification: " .. tostring(result))
            end
        end
        if not shown and ns.UI and ns.UI.Toast then
            pcall(ns.UI.Toast, customer.name .. " walked into the shop.")
        end
    end
    if ns.Sound then ns.Sound.Play("customer") end
end

local function autoSellTick(dt)
    local db = DB.Get()
    local questing = db.settings.questAutoSell == true
    local level = tonumber(db.employees.salesperson) or 0
    if not questing and (db.settings.autoSell == false or level <= 0) then return end
    if db.shop.current then return end
    if ns.Compat.InCombat() then
        autoTimer = math.max(autoTimer, 3)
        return
    end
    if #db.shop.waiting == 0 then
        autoTimer = math.min(autoTimer, 3)
        return
    end

    autoTimer = autoTimer - (tonumber(dt) or 0)
    if autoTimer > 0 then return end

    local customer = db.shop.waiting[1]
    local interval = questing and 12 or math.max(6, 12 - (level - 1) * 1.5)
    local margin = not questing and U.clamp(0.72 + (ns.Shop.Bonuses().autosale or 0), 0.72, 0.94)
    local ok, price, itemName = ns.Negotiation.AutoSell(customer, margin, questing)
    if ok then
        autoTimer = interval
        -- completeSale already moved the credits; refresh now so the header does
        -- not keep showing the pre-sale wallet until the next one-second UI tick.
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        if ns.UI and ns.UI.IsOpen and ns.UI.IsOpen() and ns.UI.Toast then
            local seller = questing and "Questing auto-sell" or "Your salesperson"
            ns.UI.Toast(string.format("%s sold %s for %s gc.", seller,
                itemName or "an item", U.comma(price or 0)))
        end
    else
        autoTimer = 2
    end
end

function C.Tick(dt)
    local db = DB.Get()
    if db.settings.paused == true then return end

    -- Run auto-selling on every tick, not only when a new arrival is due.
    autoSellTick(dt)

    db.shop.nextArrival = math.max(0, (db.shop.nextArrival or 60) - dt)
    if db.shop.nextArrival > 0 then return end

    -- Hold a due arrival until the shop can accept it. Stocking an item or
    -- freeing a waiting slot should not restart an already elapsed wait.
    if C.ArrivalBlocker() then return end

    local customer = C.TrySpawn()
    if customer then
        local interval = ns.Shop.ArrivalInterval() * U.randomBetween(0.82, 1.3)
        local _, speed = ns.Shop.ArrivalPace()
        db.shop.nextArrival = math.max(15 * speed, interval)
        C.NotifyArrival(customer)
    else
        db.shop.nextArrival = 20
    end
end

function C.PatienceRatio(customer)
    customer = customer or C.Current()
    if not customer then return 0 end
    return U.clamp((customer.patience or 0) / math.max(1, customer.patienceMax or 1), 0, 1)
end

function C.StartNegotiation(index)
    local db = DB.Get()
    if db.shop.current then return false, "already talking to someone" end
    local customer = table.remove(db.shop.waiting, index or 1)
    if not customer then return false, "no customer waiting" end

    if not db.inventory[customer.itemUid] then
        return false, "the item is gone"
    end

    db.shop.current = customer
    db.stats.negotiations = (db.stats.negotiations or 0) + 1
    db.stats.offersSeen = (db.stats.offersSeen or 0) + 1

    customer.dialogue = ns.Data.Dialogue.Line(customer, "offer", {
        offer = U.comma(customer.offer),
        item = (db.inventory[customer.itemUid] or {}).name or "it",
    })
    return true, customer
end

function C.Dismiss(index)
    local db = DB.Get()
    local customer = table.remove(db.shop.waiting, index or 1)
    if not customer then return false, "no customer" end
    db.shop.lastVisitor = {
        name = customer.name,
        result = "left",
        text = "got tired of waiting and left",
        at = U.now(),
    }
    return true, customer
end

function C.LeaveDialogue(customer, lineKey, flags)
    return ns.Data.Dialogue.Line(customer, lineKey or "leave", nil, flags)
end

function C.RecordVisit(customer, result, text)
    local db = DB.Get()
    db.shop.lastVisitor = {
        name = customer and customer.name or "Someone",
        personality = customer and customer.personality or nil,
        result = result,
        text = text or "",
        at = U.now(),
    }
end

function C.TodayRequest()
    return ns.Shop.DailyRequest()
end
