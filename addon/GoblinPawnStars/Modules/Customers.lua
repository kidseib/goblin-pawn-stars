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
    local willingness = personality.maxWill * repFactor * offerBonus * U.randomBetween(0.94, 1.08)
    -- Campaign rewards are permanent offer bonuses, so they lift what customers
    -- will pay for stock. They never create credits outside a completed sale.
    if ns.Campaign then willingness = willingness * (1 + ns.Campaign.OfferBonus()) end
    if rare then willingness = willingness * 1.12 end

    -- Hidden ceiling: what this customer would actually pay for this item.
    local maxPay = math.floor(math.min(
        value * willingness,
        budget,
        value * 2.8
    ))
    maxPay = math.max(1, maxPay)

    local opening = U.randomBetween(personality.opening[1], personality.opening[2])
    local offer = U.round(maxPay * opening, 5)
    offer = U.clamp(offer, 1, maxPay)

    local patience = (personality.patience or 2) + math.floor(bonuses.patience or 0)
    if rare then patience = patience + 1 end
    if options.celebrity then patience = patience + 1 end
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
        appraised = false,
        revealed = false,
        appraisalBonus = 0,
        createdAt = U.now(),
        dialogue = identity.greeting,
        seller = options.seller and true or false,
        regular = options.regular and true or false,
        regularVisit = options.regularVisit,
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

    -- A due named regular replaces one ordinary arrival. This is still a
    -- normal customer with a normal budget; her sale consumes normal stock.
    if not options and ns.Regular then
        options = ns.Regular.SpawnOptions(false)
    end

    local customer, record = buildCustomer(options)
    if not customer then return nil, record end

    db.shop.waiting[#db.shop.waiting + 1] = customer
    local def = ns.Data.PersonalityByKey[customer.personality]
    if customer.regular then
        customer.dialogue = customer.greeting
    else
        customer.dialogue = def and ns.Data.PersonalityLine(def, "greet", {}) or customer.greeting
    end

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
    if db.settings.autoSell == false then return end

    local level = tonumber(db.employees.salesperson) or 0
    if level <= 0 then return end
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
    local interval = math.max(6, 12 - (level - 1) * 1.5)
    local margin = U.clamp(0.72 + (ns.Shop.Bonuses().autosale or 0), 0.72, 0.94)
    local ok, price, itemName = ns.Negotiation.AutoSell(customer, margin)
    if ok then
        autoTimer = interval
        if ns.UI and ns.UI.IsOpen and ns.UI.IsOpen() and ns.UI.Toast then
            ns.UI.Toast(string.format("Your salesperson sold %s for %s gc.",
                itemName or "an item", U.comma(price or 0)))
        end
    else
        autoTimer = 2
    end
end

function C.Tick(dt)
    local db = DB.Get()
    if db.settings.paused == true then return end

    -- Run the salesperson on every tick, not only when a new arrival is due.
    autoSellTick(dt)

    db.shop.nextArrival = math.max(0, (db.shop.nextArrival or 30) - dt)
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

    local def = C.Personality(customer)
    customer.dialogue = ns.Data.PersonalityLine(def, "offer", {
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

function C.LeaveDialogue(customer, lineKey)
    local def = C.Personality(customer)
    return ns.Data.PersonalityLine(def, lineKey or "leave", {})
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
