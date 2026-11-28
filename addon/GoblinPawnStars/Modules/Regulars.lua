--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Regulars.lua
    Customers with a memory. Iteration 2 gave every archetype a voice; iteration
    3 gave the shop a cast: a sale near the customer's own ceiling is remembered
    in `db.shop.regulars` (name, archetype, visit count) and that person can take
    an ordinary arrival later, keeping their identity and earning one extra
    haggling round, then a small loyalty premium.

    Iteration 4 adds the loop around that cast. A regular who has already come
    back once can turn up wanting a specific shelf of goods, with a budget and a
    deadline (`db.shop.orders`, same cap as the cast). The player decides what to
    do with stock of that shelf: sell it to a walk-in now, or hold it and hope
    the regular returns before the order goes cold. Delivering pays over live
    market value, adds reputation and goodwill and can make them a patron;
    letting it lapse costs a little reputation and some goodwill, never the shop.

    Nothing here creates credits outside a completed sale: the order only lifts
    what a regular will pay for stock they asked for, and the sale still removes
    the unit through `Negotiation.completeSale` → `Inventory.Remove`.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local DB = ns.DB
local U = ns.Util
local R = {}
ns.Regulars = R

local function def()
    return ns.Data.Regulars
end

local function memory()
    local db = DB.Get()
    if type(db.shop.regulars) ~= "table" then db.shop.regulars = {} end
    return db.shop.regulars
end

local function orders()
    local db = DB.Get()
    if type(db.shop.orders) ~= "table" then db.shop.orders = {} end
    return db.shop.orders
end

local function entryFor(name, personality)
    for _, entry in ipairs(memory()) do
        if entry.name == name and entry.personality == personality then return entry end
    end
    return nil
end

local function orderFor(name, personality)
    local list = orders()
    for index, order in ipairs(list) do
        if order.name == name and order.personality == personality then return order, index end
    end
    return nil
end

function R.List()
    return memory()
end

function R.Orders()
    return orders()
end

function R.Entry(name, personality)
    return entryFor(name, personality)
end

--- How many shop days an open order has left. Pure read, used by the UI and by
--- the tests; nothing ticks this.
function R.DaysLeft(order)
    if type(order) ~= "table" then return 0 end
    local db = DB.Get()
    return math.max(0, math.floor((tonumber(order.dueDay) or 0) - (tonumber(db.stats.shopDays) or 0)))
end

--- One line of plain text for a compact status surface (the title-bar chip and
--- the Customers card share it, so the same order never reads two ways).
--- Returns the text and the days left, so callers can colour urgency.
function R.SummaryLine(order)
    if type(order) ~= "table" then return nil, 0 end
    local days = R.DaysLeft(order)
    local left
    if days <= 0 then
        left = "last day"
    elseif days == 1 then
        left = "1 day left"
    else
        left = string.format("%d days left", days)
    end
    return string.format("%s · %s · up to %s gc",
        order.label or "goods", left, U.comma(tonumber(order.budget) or 0)), days
end

--- The order closest to its deadline, for the one-line summary in the UI.
function R.Next()
    local soonest, soonestDue = nil, math.huge
    for _, order in ipairs(orders()) do
        local due = tonumber(order.dueDay) or 0
        if due < soonestDue then soonest, soonestDue = order, due end
    end
    return soonest
end

--- Loyalty for a returning customer, as pure numbers so it can be tested and
--- tuned in one place.
function R.Loyalty(visits)
    local data = def()
    visits = math.max(0, math.floor(tonumber(visits) or 0))
    local patience = 0
    if visits >= (data.patienceAt or 2) then patience = 1 end
    local offer = 1
    if visits >= (data.offerAt or 3) then offer = 1 + (data.offerBump or 0.05) end
    return patience, offer
end

--- The best unit of stock in `category` the shop could hand over. Counterfeits
--- are never what a regular asked for.
local function stockFor(category)
    if type(category) ~= "string" then return nil end
    local best
    for _, record in pairs(DB.Get().inventory) do
        if record.category == category and not record.counterfeit then
            if not best or (tonumber(record.value) or 0) > (tonumber(best.value) or 0) then
                best = record
            end
        end
    end
    return best
end

function R.StockFor(category)
    return stockFor(category)
end

--[[ Placing an order --------------------------------------------------------
    Called from SpawnOptions when a remembered customer walks in and cannot be
    served what they want right now. The category is one of the shelves they are
    shortest of, so the request is an errand rather than a formality. `category`
    is only passed by tests, which need a deterministic shelf.
--------------------------------------------------------------------------- ]]
function R.PlaceOrder(entry, category)
    local data = def()
    if type(entry) ~= "table" or type(entry.name) ~= "string" or entry.name == "" then
        return nil
    end
    if (tonumber(entry.visits) or 1) < (data.orderMinVisits or 2) then return nil end

    local list = orders()
    if #list >= (data.maxOrders or 3) then return nil end
    if orderFor(entry.name, entry.personality) then return nil end

    local db = DB.Get()
    local day = tonumber(db.stats.shopDays) or 0
    -- A regular who just had an order go cold does not immediately ask again.
    if (tonumber(entry.souredDay) or -999) > day - (data.sourDays or 2) then return nil end

    local label
    if category and ns.Data.CategoryNames[category] then
        label = ns.Data.CategoryNames[category]
    else
        local counts, lowest = {}, math.huge
        for _, candidate in ipairs(ns.Data.Categories) do
            local units = 0
            for _, record in pairs(db.inventory) do
                if record.category == candidate.key then
                    units = units + (tonumber(record.count) or 1)
                end
            end
            counts[#counts + 1] = { key = candidate.key, name = candidate.name, units = units }
            if units < lowest then lowest = units end
        end
        -- Prefer a shelf the wholesaler is currently offering: the player can
        -- actually source it before the deadline instead of hoping for loot.
        local onSale = {}
        local lots = ns.Wholesaler and ns.Wholesaler.Lots and ns.Wholesaler.Lots() or {}
        for _, lot in ipairs(lots) do
            if lot.category and not lot.bought then onSale[lot.category] = true end
        end
        local pool, reachable = {}, {}
        for _, candidate in ipairs(counts) do
            if candidate.units <= lowest then
                pool[#pool + 1] = candidate
                if onSale[candidate.key] then reachable[#reachable + 1] = candidate end
            end
        end
        local pick = (reachable[1] and reachable[math.random(#reachable)]) or pool[math.random(#pool)]
        category, label = pick.key, pick.name
    end

    local tier = ns.Data.Tier(db.tier)
    local patron = entry.patron and true or nil
    local budgetScale = patron and (data.patronBudget or 3.2) or (data.orderBudget or 2.6)
    local days = (data.orderDays or 2) + (patron and (data.patronDays or 1) or 0)
    local order = {
        name = entry.name,
        personality = entry.personality,
        category = category,
        label = label,
        -- Implied budget: the most they will put on the counter, scaled by the
        -- shop's own tier so early shops cannot be handed late-game sums. A
        -- patron brings a bigger purse and gives one more day, which is what
        -- makes delivering to them worth the shelf space.
        budget = math.floor((tonumber(tier.budget) or 280) * budgetScale),
        patron = patron,
        placedDay = day,
        dueDay = day + days,
    }
    list[#list + 1] = order
    db.stats.ordersPlaced = (db.stats.ordersPlaced or 0) + 1

    ns.History.Add({
        kind = "order",
        text = string.format("%s wants %s", entry.name, label),
        amount = 0,
        detail = string.format("back within %d shop days · up to %s credits%s",
            days, U.comma(order.budget), patron and " · patron" or ""),
    })
    return order
end

--[[ Delivering an order -----------------------------------------------------
    Only ever reached from a completed sale of the wanted shelf, through
    R.Remember. Pays in reputation and goodwill, and after enough deliveries the
    regular becomes a patron, which is a permanent lift on what they will pay.
--------------------------------------------------------------------------- ]]
function R.Fulfil(customer, price)
    if type(customer) ~= "table" then return nil end
    local order, index = orderFor(customer.name, customer.personality)
    if not order then return nil end
    local data = def()
    table.remove(orders(), index)

    local patron = order.patron and true or nil
    local entry = entryFor(customer.name, customer.personality)
    if entry then
        entry.fulfilled = math.min(99, (tonumber(entry.fulfilled) or 0) + 1)
        entry.visits = math.min(99, (tonumber(entry.visits) or 1)
            + (patron and (data.patronVisitBonus or 2) or (data.orderVisitBonus or 1)))
        entry.lastAt = U.now()
        entry.souredDay = nil
        if not entry.patron and (tonumber(entry.fulfilled) or 0) >= (data.patronAt or 2) then
            entry.patron = true
            ns.History.Add({
                kind = "order",
                text = string.format("%s became a patron of the shop", entry.name),
                detail = "delivered special orders",
            })
            -- A brand-new patron immediately trusts the shop with a bigger
            -- errand, so the promotion hands the player something to do and a
            -- payoff they can see, instead of only a number in a tooltip.
            pcall(R.PlaceOrder, entry)
            if ns.UI and ns.UI.Toast then
                pcall(ns.UI.Toast, string.format("%s is now a patron: bigger orders, one extra day.", entry.name))
            end
        end
    end

    local db = DB.Get()
    db.stats.ordersFilled = (db.stats.ordersFilled or 0) + 1
    db.stats.orderRevenue = (db.stats.orderRevenue or 0) + (tonumber(price) or 0)

    ns.Shop.AddReputation(patron and (data.patronRep or 12) or (data.orderRep or 8))
    ns.History.Add({
        kind = "order",
        text = string.format("%s collected the %s they asked for", order.name, order.label),
        amount = tonumber(price) or 0,
        detail = "special order delivered",
    })
    return order
end

--[[ Lapsing an order -------------------------------------------------------
    Runs from Shop.EndShopDay, the only day clock the addon already has. The cost
    is real but small: a few reputation and a little goodwill, and the regular
    stays on the books.
--------------------------------------------------------------------------- ]]
function R.EndShopDay()
    local list = orders()
    if #list == 0 then return 0 end
    local data = def()
    local db = DB.Get()
    local day = tonumber(db.stats.shopDays) or 0
    local kept, lapsed = {}, 0

    for _, order in ipairs(list) do
        if day < (tonumber(order.dueDay) or day) then
            kept[#kept + 1] = order
        else
            lapsed = lapsed + 1
            ns.Shop.AddReputation(data.lapseRep or -4)
            local entry = entryFor(order.name, order.personality)
            if entry then
                entry.visits = math.max(1, (tonumber(entry.visits) or 1) - 1)
                entry.souredDay = day
            end
            ns.History.Add({
                kind = "order",
                text = string.format("%s gave up waiting for %s", order.name, order.label),
                amount = 0,
                detail = "the special order went cold",
            })
        end
    end

    if lapsed > 0 then
        db.stats.ordersLapsed = (db.stats.ordersLapsed or 0) + lapsed
        db.shop.orders = kept
        if ns.UI and ns.UI.Toast then
            pcall(ns.UI.Toast, lapsed == 1 and "A special order went cold."
                or (lapsed .. " special orders went cold."))
        end
    end
    return lapsed
end

--- Remembers one completed sale. Called only from Negotiation.completeSale, so
--- there is no way to become a regular without buying something.
function R.Remember(customer, price)
    local data = def()
    if type(customer) ~= "table" or type(customer.name) ~= "string" or customer.name == "" then
        return nil
    end

    -- A sale of the shelf they asked for is a delivery, and it always counts,
    -- however the price was reached: they came back for that piece.
    local delivered = customer.order and R.Fulfil(customer, price) or nil

    local ceiling = tonumber(customer.maxPay) or 0
    local paid = tonumber(price) or 0
    -- A haggled-down sale does not buy goodwill; a sale near their own ceiling
    -- does. maxPay is the hidden limit, so this asks "did they leave happy?"
    if not delivered and (ceiling <= 0 or paid / ceiling < (data.goodRatio or 0.78)) then
        return nil
    end

    local list = memory()
    local entry
    for _, candidate in ipairs(list) do
        if candidate.name == customer.name and candidate.personality == customer.personality then
            entry = candidate
            break
        end
    end

    if entry then
        entry.visits = math.min(99, (tonumber(entry.visits) or 1) + 1)
        entry.lastAt = U.now()
    else
        entry = {
            name = customer.name,
            personality = customer.personality,
            race = customer.race,
            class = customer.class,
            occupation = customer.occupation,
            visits = 1,
            lastAt = U.now(),
        }
        list[#list + 1] = entry
    end

    -- Bounded: forget the face that has come least often (the oldest on a tie).
    while #list > (data.max or 3) do
        local worst = 1
        for index = 2, #list do
            local visits = tonumber(list[index].visits) or 0
            local worstVisits = tonumber(list[worst].visits) or 0
            if visits < worstVisits or (visits == worstVisits and (tonumber(list[index].lastAt) or 0) < (tonumber(list[worst].lastAt) or 0)) then
                worst = index
            end
        end
        table.remove(list, worst)
    end

    return entry
end

--[[ Which remembered face takes this arrival ---------------------------------
    Same weighted-pick shape as the rest of the addon and no timers: it is only
    consulted when the shop was already going to spawn somebody.
--------------------------------------------------------------------------- ]]
function R.SpawnOptions()
    local data = def()
    local list = memory()
    if #list == 0 then return nil end

    -- Weight grows with visits but sub-linearly, so one very familiar face
    -- cannot take most of the arrivals away from the other two.
    -- A patron is a relationship the player invested in, so they show up more
    -- often than an ordinary regular: that is the part of the reward that is
    -- felt in a single session rather than only in the numbers.
    local function weightOf(entry)
        local visits = math.max(1, tonumber(entry.visits) or 1)
        local weight = 1 + (visits - 1) * 0.5
        if entry.patron then weight = weight * (data.patronWeight or 1.5) end
        return weight
    end

    local best, total = 0, 0
    for _, entry in ipairs(list) do
        local visits = math.max(1, tonumber(entry.visits) or 1)
        best = math.max(best, visits)
        total = total + weightOf(entry)
    end

    -- A regular with an order the shelves can now fill is far likelier to come
    -- back, so holding stock is a real gamble that usually resolves. That visit
    -- gets first refusal on the arrival: the player has to see the payoff or
    -- holding stock is a blind bet.
    local fillable = 0
    for _, order in ipairs(orders()) do
        local record = stockFor(order.category)
        if record then
            fillable = fillable + 1
            local entry = entryFor(order.name, order.personality)
            if entry and U.chance(data.orderReturnChance or 0.55) then
                return {
                    name = entry.name,
                    race = entry.race,
                    class = entry.class,
                    occupation = entry.occupation,
                    personality = entry.personality,
                    returning = math.max(1, tonumber(entry.visits) or 1),
                    patron = entry.patron and true or nil,
                    order = order,
                    record = record,
                    orderBudget = tonumber(order.budget) or nil,
                }
            end
        end
    end

    local chance = (data.chance or 0.14) + (best - 1) * (data.chancePerVisit or 0.04)
    if ns.Regular and ns.Regular.Unlocked and ns.Regular.Unlocked() then chance = chance + 0.06 end
    chance = chance + fillable * (data.orderArrivalBoost or 0.15)
    local ceiling = data.maxChance or 0.30
    if fillable > 0 then ceiling = data.orderMaxChance or 0.55 end
    chance = U.clamp(chance, 0, ceiling)
    if not U.chance(chance) then return nil end

    -- Weighted by visits: the people who like the shop come back most often.
    local roll = U.randomBetween(1, total)
    local pick = list[#list]
    for _, entry in ipairs(list) do
        roll = roll - weightOf(entry)
        if roll <= 0 then
            pick = entry
            break
        end
    end

    local options = {
        name = pick.name,
        race = pick.race,
        class = pick.class,
        occupation = pick.occupation,
        personality = pick.personality,
        returning = math.max(1, tonumber(pick.visits) or 1),
        patron = pick.patron and true or nil,
    }

    local order = orderFor(pick.name, pick.personality)
    local record = order and stockFor(order.category)
    if record then
        -- They came back for the piece they asked for.
        options.order = order
        options.record = record
        options.orderBudget = tonumber(order.budget) or nil
    else
        -- Nothing on that shelf yet: they may ask for it, then browse.
        local placed = nil
        local askChance = pick.patron and (data.patronOrderChance or 0.75)
            or (data.orderChance or 0.34)
        if U.chance(askChance) then placed = R.PlaceOrder(pick) end
        if placed then
            options.orderAsk = placed
        end
    end

    return options
end
