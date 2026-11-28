-- Headless 30-minute progression probe. Load with the full addon in the mock.
-- The policy is deliberately simple: accept offers, keep stock topped up from
-- the wholesaler, buy the next tier, hire a salesperson, then buy cheap upgrades.

function __sim30()
    local ns = __NS
    local real = ns.db
    local db = ns.DB.Scratch()
    ns.db = db
    math.randomseed(424242)
    ns.Throughput.Reset()
    ns.Wholesaler.GrantStarter()

    local lines = {}
    local function snapshot(minute)
        local creditsRate, customerRate = ns.Throughput.Rates()
        lines[#lines + 1] = string.format(
            "%2dm | %6d gc | tier %d | %3d sales | %2d stock | %2d auto | %2d lots | %.0f gc/min | %.1f cust/min",
            minute, db.credits, db.tier, db.stats.sales or 0,
            ns.Inventory.Count(), db.stats.autoSales or 0, db.stats.wholesaleBought or 0,
            creditsRate, customerRate)
    end

    local function buyUpgrade(key)
        local def = ns.Data.UpgradeByKey[key]
        if not def then return end
        local level = db.upgrades[key] or 0
        if level >= def.maxLevel then return end
        if db.credits >= ns.Data.UpgradeCost(def, level) + 120 then
            ns.Shop.BuyUpgrade(key)
        end
    end

    local function policy()
        if not db.shop.current and #db.shop.waiting > 0 then
            ns.Customers.StartNegotiation(1)
            if db.shop.current then ns.Negotiation.Accept() end
        end

        -- Save for the next progression beat before buying more stock or polish.
        local nextTier = ns.Shop.NextTier()
        local reserve = nextTier and nextTier.cost or 0
        local employee = ns.Data.EmployeeByKey.salesperson
        local staffCost = employee and ns.Data.EmployeeCost(employee, 0) or 0
        if db.tier >= 2 and (db.employees.salesperson or 0) == 0 then
            reserve = reserve + staffCost
        end

        if db.credits >= reserve + 100 and nextTier then
            ns.Shop.UpgradeTier()
        elseif db.tier >= 2 and (db.employees.salesperson or 0) == 0
            and db.credits >= staffCost + 100 then
            ns.Staff.Hire("salesperson")
        end

        if ns.Inventory.Count() < 6 then
            local lots = ns.Wholesaler.Lots()
            for _, lot in ipairs(lots) do
                local affordable = db.credits - lot.cost >= (reserve + 100)
                if not lot.bought and (affordable or ns.Inventory.Count() == 0)
                    and db.credits >= lot.cost and ns.Inventory.Free() >= 1 then
                    ns.Wholesaler.Buy(lot.position)
                    break
                end
            end
        end

        if db.credits - reserve > 600 and (db.employees.salesperson or 0) > 0 then
            buyUpgrade("shelves")
            buyUpgrade("haggling_manual")
            buyUpgrade("sign")
        end
    end

    for second = 1, 1800 do
        ns.Clock.OnTick(1)
        if second % 2 == 0 then policy() end
        if second % 300 == 0 then snapshot(second / 60) end
    end

    snapshot(30)
        local history = db.history
    local shop = db.shop
    db.history = {}
    db.shop = { waiting = {}, current = nil, wholesale = { lots = {}, nextRestock = 0, restocks = 0 } }
    local compactChars = #ns.DB.Export()
    db.history = history
    db.shop = shop

    local final = string.format(
        "\nFINAL | %d gc | tier %d | %d sales | %d served | %d auto-sales | %d lots | rep %d | best %d"
            .. "\nregulars %d | orders %d placed / %d filled / %d lapsed | order sales %d"
            .. "\nearned %d | spent %d | wholesale %d | expenses %d | avg sale %d | export chars %d | compact chars %d",
        db.credits, db.tier, db.stats.sales or 0, db.stats.customersServed or 0,
        db.stats.autoSales or 0, db.stats.wholesaleBought or 0,
        math.floor(db.reputation or 0), db.stats.bestSale or 0,
        #(db.shop.regulars or {}),
        db.stats.ordersPlaced or 0, db.stats.ordersFilled or 0, db.stats.ordersLapsed or 0,
        db.stats.orderRevenue or 0,
        db.stats.earned or 0, db.stats.spent or 0, db.stats.wholesaleSpent or 0,
        db.stats.expenses or 0,
        math.floor((db.stats.revenue or 0) / math.max(1, db.stats.sales or 1)),
        #ns.DB.Export(), compactChars)

    ns.db = real
    return table.concat(lines, "\n") .. final
end

-- Ten minutes with the shop window closed and no player input. The salesperson
-- must clear the queue without printing money or letting it overflow forever.
function __sim_idle()
    local ns = __NS
    local real = ns.db
    local db = ns.DB.Scratch()
    ns.db = db
    math.randomseed(777)
    ns.Throughput.Reset()
    db.tier = 2
    db.credits = 5000
    db.employees.salesperson = 2
    db.shop.nextArrival = 0

    for index = 1, 8 do
        ns.Inventory.Add({
            id = 8000 + index, name = "Idle Test Stock " .. index, quality = 2, ilvl = 30,
            classID = 15, subclassID = 0, category = "misc", value = 240,
        }, { count = 20, forceNew = true })
    end

    for _ = 1, 600 do ns.Clock.OnTick(1) end

    local creditsRate, customerRate = ns.Throughput.Rates()
    local line = string.format(
        "IDLE 10m | %d auto-sales | %d credits | %d stock | %d queue | %.0f gc/min | %.1f cust/min",
        db.stats.autoSales or 0, db.credits, ns.Inventory.Count(), #db.shop.waiting,
        creditsRate, customerRate)
    ns.db = real
    return line
end
