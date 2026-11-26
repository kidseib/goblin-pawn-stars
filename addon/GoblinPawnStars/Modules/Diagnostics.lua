--[[ Goblin PawnStars --------------------------------------------------------
    Modules/Diagnostics.lua
    Self-tests for the pure simulation layer. Run with /gps test in game, or via
    the Node harness in /tools. Each test swaps in a scratch database so real
    progression is never touched.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local D = {}
ns.Diagnostics = D

local function newResults()
    local list = {}
    return list
end

local function runWith(scratchSetup, fn)
    local real = ns.db
    local realGlobal = _G.GoblinPawnStarsDB
    ns.db = ns.DB.Scratch()
    if scratchSetup then scratchSetup(ns.db) end
    local ok, err = pcall(fn, ns.db)
    ns.db = real
    _G.GoblinPawnStarsDB = realGlobal
    return ok, err
end

function D.Run()
    local results = newResults()

    local function test(name, fn)
        local ok, err = pcall(fn)
        results[#results + 1] = { name = name, ok = ok, error = (not ok) and tostring(err) or nil }
    end

    local function withScratch(setup, fn)
        local ok, err = runWith(setup, fn)
        if not ok then error(err, 0) end
    end

    local function expect(condition, message)
        if not condition then error(message or "expectation failed", 2) end
    end

    local function expectEqual(actual, expected, message)
        if actual ~= expected then
            error((message or "values differ") .. ": got " .. tostring(actual) .. ", wanted " .. tostring(expected), 2)
        end
    end

    -----------------------------------------------------------------------
    test("data tables are coherent", function()
        expectEqual(#ns.Data.Tiers, 5, "expected five shop tiers")
        expectEqual(#ns.Data.Personalities, 9, "expected nine personalities")
        expect(#ns.Data.Achievements >= 20, "expected at least twenty achievements")
        for index = 2, #ns.Data.Tiers do
            local previous, current = ns.Data.Tiers[index - 1], ns.Data.Tiers[index]
            expect(current.cost > previous.cost, "tier costs must increase")
            expect(current.storage > previous.storage, "tier storage must increase")
        end
        local seen = {}
        for _, def in ipairs(ns.Data.Achievements) do
            expect(not seen[def.key], "duplicate achievement key " .. tostring(def.key))
            seen[def.key] = true
        end
        for _, personality in ipairs(ns.Data.Personalities) do
            expect(#personality.prefer > 0, "personality needs preferred categories")
            expect(personality.opening[1] > 0 and personality.opening[2] > personality.opening[1],
                "bad opening range for " .. personality.key)
        end
    end)

    -----------------------------------------------------------------------
    test("serializer round-trips the database", function()
        local encoded
        withScratch(nil, function(scratch)
            scratch.credits = 12345
            scratch.tier = 3
            scratch.inventory[1] = {
                uid = 1, id = 6948, name = "Hearthstone \"Test\" \\ line\nbreak",
                icon = "Interface\\Icons\\INV_Misc_Rune_01", quality = 3,
                ilvl = 40, category = "misc", value = 300, count = 2, counterfeit = false,
            }
            encoded = ns.DB.Export()
        end)
        local payload, err = ns.Serialize.Decode(encoded)
        expect(payload, "decode failed: " .. tostring(err))
        expectEqual(payload.data.credits, 12345, "credits lost in round trip")
        expectEqual(payload.data.inventory[1].name, "Hearthstone \"Test\" \\ line\nbreak", "string escaping broke")
        expectEqual(payload.data.inventory[1].count, 2, "stack count lost")
    end)

    -----------------------------------------------------------------------
    test("inventory stacks and respects capacity", function()
        withScratch(nil, function(scratch)
            local info = {
                id = 2589, name = "Linen Cloth", quality = 1, ilvl = 5,
                classID = 7, subclassID = 5, icon = "Interface\\Icons\\INV_Fabric_Linen_01",
            }
            info.category = ns.Data.CategoryOf(info)
            info.value = ns.Data.BaseValue(info)
            local first = ns.Inventory.Add(info, { count = 2 })
            expect(first, "first add failed")
            expectEqual(first.count, 2, "stack count wrong")
            ns.Inventory.Add(info, { count = 1 })
            expectEqual(ns.Inventory.Count(), 1, "same item should stack into one record")

            local capacity = ns.Inventory.Capacity()
            for index = 1, capacity + 5 do
                ns.Inventory.Add({
                    id = 1000 + index, name = "Widget " .. index, quality = 2, ilvl = 10,
                    classID = 15, subclassID = 0, category = "misc", value = 20,
                })
            end
            expect(ns.Inventory.Count() <= capacity, "inventory exceeded capacity")
            local record, reason = ns.Inventory.Add({
                id = 9999, name = "Overflow", quality = 1, ilvl = 1,
                classID = 15, subclassID = 0, category = "misc", value = 5,
            })
            expect(record == nil and reason == "storage full", "overflow was not rejected")
        end)
    end)

    -----------------------------------------------------------------------
    test("market multipliers stay in bounds", function()
        withScratch(nil, function(scratch)
            ns.Market.StartEvent("war_effort")
            ns.Market.StartEvent("goblin_market_crash")
            for _, category in ipairs(ns.Data.Categories) do
                local multiplier = ns.Market.Multiplier(category.key)
                expect(multiplier >= 0.45 and multiplier <= 2.4,
                    "multiplier out of bounds for " .. category.key .. ": " .. tostring(multiplier))
            end
            local item = { category = "weapon", value = 1000, count = 1, quality = 4 }
            expect(ns.Market.Value(item) > 0, "market value must be positive")
        end)
    end)

    -----------------------------------------------------------------------
    test("arrival pace adjusts the interval and active countdown", function()
        withScratch(nil, function(scratch)
            scratch.settings.arrivalPace = nil
            local normal = ns.Shop.ArrivalInterval()
            local oldNormal = U.clamp((ns.Shop.TierInfo().arrival or 110) - (ns.Shop.Bonuses().arrival or 0), 8, 300)
            expectEqual(normal, oldNormal * 2, "Normal wait was not doubled")
            scratch.shop.nextArrival = 40
            ns.Shop.SetArrivalPace("Fast")
            expectEqual(ns.Shop.ArrivalInterval(), normal / 2, "Fast interval")
            expectEqual(scratch.shop.nextArrival, 20, "Fast countdown")
            ns.Shop.SetArrivalPace("Relaxed")
            expectEqual(ns.Shop.ArrivalInterval(), normal * 2, "Relaxed interval")
            expectEqual(scratch.shop.nextArrival, 80, "Relaxed countdown")
            ns.Shop.SetArrivalPace("Normal")
            expectEqual(scratch.shop.nextArrival, 40, "Normal countdown")
        end)
    end)

    -----------------------------------------------------------------------
    test("legacy arrival countdown is doubled only once", function()
        withScratch(nil, function(scratch)
            scratch.shop.nextArrival = 17
            scratch.shop.arrivalTimingVersion = nil
            expect(ns.DB.Import(ns.DB.Export(), true), "legacy backup failed to import")
            expectEqual(ns.DB.Get().shop.nextArrival, 34, "legacy countdown")
            expect(ns.DB.Import(ns.DB.Export(), true), "current backup failed to import")
            expectEqual(ns.DB.Get().shop.nextArrival, 34, "countdown doubled twice")
        end)
    end)

    -----------------------------------------------------------------------
    test("customers need stock and stay within budget", function()
        withScratch(nil, function(scratch)
            local customer = ns.Customers.TrySpawn()
            expect(customer == nil, "customer spawned with an empty shop")

            ns.Inventory.Add({
                id = 2589, name = "Linen Cloth", quality = 1, ilvl = 5,
                classID = 7, subclassID = 5, category = "cloth", value = 120,
            })
            local spawned, record = ns.Customers.TrySpawn()
            expect(spawned ~= nil, "customer failed to spawn with stock")
            expect(record ~= nil, "customer has no item")
            expect(spawned.maxPay <= spawned.budget, "customer's ceiling exceeds their budget")
            expect(spawned.offer > 0 and spawned.offer <= spawned.maxPay, "opening offer out of range")
            expectEqual(#ns.Customers.Waiting(), 1, "customer was not queued")
        end)
    end)

    -----------------------------------------------------------------------
    test("accepting an offer pays out exactly once", function()
        withScratch(nil, function(scratch)
            local info = {
                id = 2592, name = "Wool Cloth", quality = 1, ilvl = 15,
                classID = 7, subclassID = 5, category = "cloth", value = 300,
            }
            ns.Inventory.Add(info)
            ns.Customers.TrySpawn({ personality = "gullible" })
            expect(ns.Customers.StartNegotiation(1), "negotiation did not start")

            local startCredits = scratch.credits
            local offer = ns.Negotiation.Offer()
            -- completeSale also pays the daily request bonus when the item matches
            -- today's request, so the expected payout must include it.
            local request = ns.Shop.DailyRequest()
            local requestBonus = 0
            if request and not request.fulfilled and request.category == info.category then
                requestBonus = request.bonus or 0
            end
            local expected = math.max(1, math.floor(offer * (1 + requestBonus)))
            local ok = ns.Negotiation.Accept()
            expect(ok, "accept failed")
            expectEqual(scratch.credits, startCredits + expected, "credits did not match the accepted offer")
            expectEqual(ns.Inventory.Count(), 0, "sold item was not removed")
            expectEqual(scratch.stats.sales, 1, "sale was not counted")

            local second = ns.Customers.TrySpawn()
            expect(second == nil, "a customer spawned for an empty shop")
            expectEqual(scratch.stats.sales, 1, "a phantom sale was recorded")
        end)
    end)

    -----------------------------------------------------------------------
    test("counteroffers cannot mint money or duplicate stock", function()
        withScratch(nil, function(scratch)
            local totalEver = 0
            for round = 1, 40 do
                ns.Inventory.Add({
                    id = 3000 + round, name = "Test Blade " .. round, quality = 3, ilvl = 60,
                    classID = 2, subclassID = 7, category = "weapon", value = 900,
                })
                ns.Customers.TrySpawn({ personality = "trader" })
                if ns.Customers.StartNegotiation(1) then
                    local item = ns.Negotiation.Item()
                    local ceiling = item and ns.Market.Value(item) or 0
                    for _ = 1, 3 do
                        if not ns.Negotiation.Active() then break end
                        local counter = math.max(1, math.floor(ceiling * (0.7 + math.random() * 0.8)))
                        ns.Negotiation.Counter(counter)
                    end
                    if ns.Negotiation.Active() then ns.Negotiation.Reject() end
                end
                totalEver = totalEver + 1
            end
            expect(scratch.credits >= 0, "credits went negative")
            local stocked = 0
            for _ in pairs(scratch.inventory) do stocked = stocked + 1 end
            expect(stocked <= totalEver, "stock multiplied out of nowhere")
            expect(scratch.stats.sales <= totalEver, "more sales than items offered")
        end)
    end)

    -----------------------------------------------------------------------
    test("shop days charge expenses without going negative", function()
        withScratch(nil, function(scratch)
            scratch.credits = 10
            scratch.tier = 2
            ns.Shop.EndShopDay()
            expect(scratch.credits >= 0, "credits went negative after expenses")
            expect(scratch.stats.expenses > 0, "no expenses were recorded")
        end)
    end)

    -----------------------------------------------------------------------
    test("upgrades and employees apply their effects", function()
        withScratch(nil, function(scratch)
            scratch.credits = 100000
            scratch.tier = 3
            local before = ns.Inventory.Capacity()
            local ok = ns.Shop.BuyUpgrade("shelves")
            expect(ok, "could not buy an upgrade")
            expect(ns.Inventory.Capacity() == before + 6, "storage upgrade had no effect")

            local hired = ns.Staff.Hire("appraiser")
            expect(hired, "could not hire the appraiser")
            expect(ns.Staff.Level("appraiser") == 1, "employee level not set")
            expect(ns.Shop.Appraisal() > ns.Data.Tier(3).appraisal, "appraiser did not improve appraisal")
        end)
    end)

    -----------------------------------------------------------------------
    test("achievements unlock from lifetime stats", function()
        withScratch(nil, function(scratch)
            scratch.stats.sales = 100
            scratch.stats.counterSuccess = 50
            scratch.stats.bestMultiple = 2.4
            local unlocked = ns.Achievements.Check()
            expect(#unlocked >= 3, "expected several achievements to unlock")
            expect(scratch.achievements.best_i_can_do, "Best I Can Do did not unlock")
            expect(scratch.achievements.highway_robbery, "Highway Robbery did not unlock")
            local again = ns.Achievements.Check()
            expectEqual(#again, 0, "achievements unlocked twice")
        end)
    end)

    -----------------------------------------------------------------------
    test("encounters resolve and clear their pending state", function()
        withScratch(nil, function(scratch)
            ns.Inventory.Add({
                id = 4000, name = "Brass Compass", quality = 2, ilvl = 30,
                classID = 15, subclassID = 0, category = "misc", value = 200,
            })
            scratch.credits = 5000
            local event = ns.Encounters.Trigger("mystery_delivery")
            expect(event, "mystery delivery did not trigger")
            expect(ns.Encounters.Resolve("open"), "could not resolve the event")
            expect(scratch.shop.encounter == nil, "pending encounter was not cleared")
            expect(scratch.shop.encounterResult ~= nil, "no result was stored")
        end)
    end)

    -----------------------------------------------------------------------
    test("every encounter option resolves safely", function()
        local function fresh(fn)
            local real = ns.db
            ns.db = ns.DB.Scratch()
            ns.db.credits = 20000
            ns.db.tier = 4
            ns.Inventory.Add({
                id = 5000, name = "Test Relic", quality = 4, ilvl = 70,
                classID = 15, subclassID = 0, category = "misc", value = 1500,
            })
            local ok, err = pcall(fn, ns.db)
            ns.db = real
            if not ok then error(err, 0) end
        end

        for _, def in ipairs(ns.Data.Encounters) do
            local optionIds = {}
            fresh(function(scratch)
                local event = ns.Encounters.Trigger(def.key)
                if event then
                    for _, option in ipairs(event.options or {}) do
                        optionIds[#optionIds + 1] = option.id
                    end
                end
            end)
            for _, optionId in ipairs(optionIds) do
                fresh(function(scratch)
                    ns.Encounters.Trigger(def.key)
                    local ok, message = ns.Encounters.Resolve(optionId)
                    expect(ok, def.key .. "/" .. optionId .. ": " .. tostring(message))
                    expect(scratch.shop.encounter == nil, def.key .. " left a pending encounter")
                    expect(scratch.credits >= 0, def.key .. " drove credits negative")
                end)
            end
        end
    end)

    -----------------------------------------------------------------------
    test("every personality negotiates without errors", function()
        local real = ns.db
        for _, personality in ipairs(ns.Data.Personalities) do
            ns.db = ns.DB.Scratch()
            ns.db.tier = 5
            ns.Inventory.Add({
                id = 6000, name = "Trader's Test Piece", quality = 3, ilvl = 55,
                classID = 2, subclassID = 7, category = "weapon", value = 1200,
            })
            local ok, err = pcall(function()
                ns.Customers.TrySpawn({ personality = personality.key })
                expect(ns.Customers.StartNegotiation(1), "could not start with " .. personality.key)
                local customer = ns.Negotiation.Active()
                expect(customer ~= nil, "no active customer for " .. personality.key)
                ns.Negotiation.Appraise()
                ns.Negotiation.Counter(math.max(1, ns.Negotiation.Suggested("fair")))
                if ns.Negotiation.Active() then ns.Negotiation.Accept() end
            end)
            ns.db = real
            if not ok then error(personality.key .. ": " .. tostring(err), 0) end
        end
        expect(ns.db.credits >= 0, "personality loop left a negative balance")
    end)

    -----------------------------------------------------------------------
    test("backup import restores progress", function()
        local encoded
        withScratch(function(scratch)
            scratch.credits = 4321
            scratch.tier = 2
            scratch.stats.sales = 12
        end, function(scratch)
            encoded = ns.DB.Export()
        end)
        _G.__encodedBackup = encoded
        withScratch(nil, function(scratch)
            local ok, err = ns.DB.Import(encoded)
            expect(ok, "import failed: " .. tostring(err))
            expectEqual(ns.DB.Get().credits, 4321, "credits not restored")
            expectEqual(ns.DB.Get().stats.sales, 12, "stats not restored")
            expectEqual(ns.DB.Get().tier, 2, "tier not restored")
        end)
    end)

    -----------------------------------------------------------------------
    test("starter crate grants stock without granting credits", function()
        withScratch(nil, function(scratch)
            local startingCredits = scratch.credits
            local granted = ns.Wholesaler.GrantStarter()
            expect(granted, "starter crate was not granted to an empty shop")
            expectEqual(ns.Inventory.Count(), 2, "starter crate should add two stacks")
            expectEqual(scratch.credits, startingCredits, "starter crate created credits")
            expect(scratch.settings.starterGranted, "starter crate was not marked as granted")

            local again = ns.Wholesaler.GrantStarter()
            expect(not again, "starter crate was granted twice")
            expectEqual(ns.Inventory.Count(), 2, "second starter crate changed stock")
        end)
    end)

    -----------------------------------------------------------------------
    test("wholesaler lots cost credits and become stock exactly once", function()
        withScratch(nil, function(scratch)
            scratch.credits = 5000
            local lots = ns.Wholesaler.Restock()
            expectEqual(#lots, 3, "expected three wholesale lots")
            local lot = lots[1]
            expect(lot.cost > 0, "lot has no price")
            expect(lot.retail > lot.cost, "lot has no plausible retail margin")

            local beforeCredits = scratch.credits
            local beforeStock = ns.Inventory.Count()
            local ok, record = ns.Wholesaler.Buy(1)
            expect(ok, "could not buy a wholesale lot")
            expect(record and record.count == lot.count, "lot contents were not stocked")
            expectEqual(scratch.credits, beforeCredits - lot.cost, "lot did not deduct its exact cost")
            expectEqual(ns.Inventory.Count(), beforeStock + 1, "lot did not add exactly one stock record")
            expect(lot.bought, "lot was not marked sold")
            expectEqual(scratch.stats.wholesaleBought, 1, "wholesale purchase was not counted")
            expectEqual(scratch.stats.wholesaleSpent, lot.cost, "wholesale spend was not counted")

            local again = ns.Wholesaler.Buy(1)
            expect(not again, "the same lot could be bought twice")
            expectEqual(scratch.credits, beforeCredits - lot.cost, "a failed second purchase changed credits")

            local restocks = scratch.shop.wholesale.restocks
            local creditsBeforeRestock = scratch.credits
            scratch.shop.wholesale.nextRestock = 1
            ns.Wholesaler.Tick(2)
            expectEqual(scratch.shop.wholesale.restocks, restocks + 1, "restock timer did not roll new lots")
            expectEqual(#ns.Wholesaler.Lots(), 3, "restock did not produce three lots")
            expectEqual(scratch.credits, creditsBeforeRestock, "restocking created credits")
        end)
    end)

    -----------------------------------------------------------------------
    test("salesperson auto-sells queued customers and consumes stock", function()
        withScratch(function(scratch)
            scratch.tier = 2
            scratch.employees.salesperson = 1
            scratch.credits = 50
            scratch.shop.nextArrival = 999
            scratch.stats.autoSales = 0
            scratch.shop.request = {
                day = U.today(), category = "weapon", label = "Weapons",
                bonus = 0.2, fulfilled = false,
            }
            ns.Inventory.Add({
                id = 7100, name = "Auto Sale Test Relic", quality = 2, ilvl = 40,
                classID = 15, subclassID = 0, category = "misc", value = 600,
            })
            local spawned = ns.Customers.TrySpawn({ personality = "gambler" })
            expect(spawned, "could not queue a customer for the salesperson")
        end, function(scratch)
            local record = ns.Inventory.RandomRecord()
            local market = ns.Market.Value(record)
            local beforeCredits = scratch.credits

            ns.Customers.Tick(13)

            expectEqual(scratch.stats.autoSales, 1, "salesperson did not close a queued sale")
            expect(#ns.Customers.Waiting() == 0, "auto-sold customer stayed in the queue")
            expect(ns.Inventory.Count() == 0, "auto-sale did not consume the stock")
            expect(scratch.credits > beforeCredits, "auto-sale did not pay credits")
            expect(scratch.stats.autoRevenue == scratch.credits - beforeCredits,
                "auto-sale revenue did not match the credits paid")
            expect(scratch.credits - beforeCredits <= math.floor(market * 0.8) + 1,
                "auto-sale paid above its discounted market price")

            local after = ns.Customers.Tick(13)
            expectEqual(scratch.stats.autoSales, 1, "salesperson sold without a customer")
            expect(after == nil, "a customer appeared with no stock")
        end)
    end)

    -----------------------------------------------------------------------
    test("questing auto-sell pays a third without a salesperson", function()
        withScratch(nil, function(scratch)
            scratch.settings.autoSell = false
            scratch.shop.nextArrival = 999
            scratch.shop.request = {
                day = U.today(), category = "cloth", label = "Cloth",
                bonus = 0.2, fulfilled = false,
            }
            ns.Inventory.Add({ id = 2589, name = "Linen Cloth", category = "cloth", value = 800 })
            local customer = ns.Customers.TrySpawn()
            expect(customer, "customer failed to queue")
            customer.maxPay = 300
            local credits = scratch.credits

            ns.Customers.Tick(60)
            expectEqual(scratch.credits, credits, "quest sale ran with the toggle off")
            expectEqual(#ns.Customers.Waiting(), 1, "customer disappeared before enabling questing")
            scratch.settings.questAutoSell = true
            ns.Customers.Tick(60)

            expectEqual(scratch.credits - credits, 120, "quest sale price or daily bonus")
            expectEqual(scratch.stats.autoSales, 1, "quest sale did not record an automatic sale")
            expectEqual(scratch.stats.autoRevenue, 120, "quest sale did not record revenue")
            expectEqual(ns.Inventory.Count(), 0, "quest sale did not consume stock")
            expectEqual(#ns.Customers.Waiting(), 0, "quest sale did not serve the queued customer")
            ns.Customers.Tick(60)
            expectEqual(scratch.credits - credits, 120, "quest sale created credits without stock")
        end)
    end)

    -----------------------------------------------------------------------
    test("throughput reports only recorded sales", function()
        withScratch(nil, function(scratch)
            ns.Throughput.Reset()
            local credits, customers = ns.Throughput.Rates()
            expectEqual(credits, 0, "empty throughput should be zero")
            expectEqual(customers, 0, "empty customer throughput should be zero")

            ns.Throughput.RecordSale(120)
            ns.Throughput.Tick(30)
            credits, customers = ns.Throughput.Rates()
            expect(math.abs(credits - 240) < 1, "credits per minute were wrong: " .. tostring(credits))
            expect(math.abs(customers - 2) < 0.01, "customer rate was wrong: " .. tostring(customers))
        end)
    end)

    -----------------------------------------------------------------------
    test("macro journal restores a run and rejects corruption", function()
        -- Macro-store fixtures exist only in the headless harness. Never touch
        -- or clear a real player's macros from /gps test.
        if type(__clearMacros) ~= "function" or type(MACRO_STORE) ~= "table" then return end
        __clearMacros()
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB
        local original = ns.DB.Scratch()
        original.settings.macroJournal = true
        original.credits = 4321
        original.tier = 2
        original.stats.sales = 11
        original.campaign.payments = 2
        original.campaign.paid = 7500
        original.museum.donated.weapon = { name = "Journal Blade" }
        original.regular.visits = 1
        original.regular.unlocked = true
        ns.db = original

        local ok, status = ns.Journal.SaveNow()
        expect(ok, "journal save failed: " .. tostring(status))
        expect(status.chunks > 0 and status.chunks <= 24, "journal used an invalid chunk count")
        for index = 1, status.chunks do
            expect(MACRO_STORE[index] and #MACRO_STORE[index].body <= 255,
                "journal macro body exceeded the game limit")
        end

        local fresh = ns.DB.Scratch()
        fresh.settings.macroJournal = true
        ns.db = fresh
        local loaded = ns.Journal.TryLoad(true)
        expect(loaded, "journal did not load: " .. tostring(ns.Journal.status.error))
        expectEqual(ns.DB.Get().credits, 4321, "journal lost credits")
        expectEqual(ns.DB.Get().campaign.payments, 2, "journal lost campaign progress")
        expectEqual(ns.DB.Get().museum.donated.weapon.name, "Journal Blade", "journal lost museum progress")
        expectEqual(ns.DB.Get().stats.sales, 11, "journal lost sales")
        expectEqual(#ns.DB.Get().history, 0, "journal should omit the verbose ledger")

        local corrupt = MACRO_STORE[1].body
        MACRO_STORE[1].body = corrupt:sub(1, #corrupt - 1) .. (corrupt:sub(-1) == "A" and "B" or "A")
        ns.db = ns.DB.Scratch()
        ns.db.settings.macroJournal = true
        local corrupted = ns.Journal.TryLoad(true)
        expect(not corrupted, "corrupt journal was accepted")
        expect(ns.Journal.status.error ~= nil, "corrupt journal did not report an error")

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __clearMacros()
    end)

    -----------------------------------------------------------------------
    test("journal keeps the last good save when a write fails halfway", function()
        if type(__clearMacros) ~= "function" or type(MACRO_STORE) ~= "table" then return end
        __clearMacros()
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB

        local function macroCount()
            local count = 0
            for _ in pairs(MACRO_STORE) do count = count + 1 end
            return count
        end

        local db = ns.DB.Scratch()
        db.settings.macroJournal = true
        db.credits = 1111
        db.tier = 2
        db.stats.sales = 3
        ns.db = db
        expect(ns.Journal.SaveNow(), "seed save failed: " .. tostring(ns.Journal.status.error))

        local first = ns.Journal.status.generation
        expect(first == "A" or first == "B", "a save did not report its generation")
        expect(ns.Journal.status.chunks > 1, "the test needs a multi-chunk save")

        -- Progress that must never replace the good save if writing fails.
        db.credits = 9999
        db.stats.sales = 99

        local originalCreate, originalEdit = ns.Compat.CreateMacro, ns.Compat.EditMacro
        local writes = 0
        local function refuse()
            writes = writes + 1
            return writes >= 2
        end
        ns.Compat.CreateMacro = function(name, icon, body)
            if refuse() then return nil end
            return originalCreate(name, icon, body)
        end
        ns.Compat.EditMacro = function(index, name, icon, body)
            if refuse() then return false end
            return originalEdit(index, name, icon, body)
        end

        local ok = ns.Journal.SaveNow()
        ns.Compat.CreateMacro, ns.Compat.EditMacro = originalCreate, originalEdit

        expect(not ok, "a save whose writes fail must not report success")
        expect(ns.Journal.status.error ~= nil, "the failed save did not record an error")
        expectEqual(ns.Journal.status.generation, first, "a failed save changed the current generation")

        -- A half-written generation has to lose to the previous committed one.
        local fresh = ns.DB.Scratch()
        fresh.settings.macroJournal = true
        ns.db = fresh
        expect(ns.Journal.TryLoad(true), "the last good save did not load after a failed write: " ..
            tostring(ns.Journal.status.error))
        expectEqual(ns.DB.Get().credits, 1111, "a half-written save replaced the last good one")
        expectEqual(ns.DB.Get().stats.sales, 3, "a half-written save lost stats")

        -- The next save must still work, switch generation and clean up.
        local recovered = ns.DB.Get()
        recovered.credits = 2222
        recovered.stats.sales = 7
        ns.db = recovered
        expect(ns.Journal.SaveNow(), "recovery save failed: " .. tostring(ns.Journal.status.error))
        expect(ns.Journal.status.generation ~= first, "the recovery save reused the failed generation")
        expect(macroCount() <= 12, "more than one generation was left in the macro list: " .. macroCount())

        local again = ns.DB.Scratch()
        again.settings.macroJournal = true
        ns.db = again
        expect(ns.Journal.TryLoad(true), "the recovered save did not load")
        expectEqual(ns.DB.Get().credits, 2222, "the recovered save did not restore")
        expectEqual(ns.DB.Get().stats.sales, 7, "the recovered save lost stats")

        -- Failing the last write (the commit header) is just as harmless: the
        -- payload is on disk but uncommitted, so it must still lose.
        local committed = ns.Journal.status.generation
        local writesInSave = ns.Journal.status.chunks
        ns.DB.Get().credits = 3333
        local calls = 0
        ns.Compat.CreateMacro = function(name, icon, body)
            calls = calls + 1
            if calls > writesInSave then return nil end
            return originalCreate(name, icon, body)
        end
        ns.Compat.EditMacro = function(index, name, icon, body)
            calls = calls + 1
            if calls > writesInSave then return false end
            return originalEdit(index, name, icon, body)
        end
        expect(not ns.Journal.SaveNow(), "a save that cannot commit must not report success")
        ns.Compat.CreateMacro, ns.Compat.EditMacro = originalCreate, originalEdit
        expectEqual(ns.Journal.status.generation, committed, "a failed commit changed the generation")

        local check = ns.DB.Scratch()
        check.settings.macroJournal = true
        ns.db = check
        expect(ns.Journal.TryLoad(true), "the previous save did not load after a failed commit")
        expectEqual(ns.DB.Get().credits, 2222, "a failed commit destroyed the previous save")

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __clearMacros()
    end)

    -----------------------------------------------------------------------
    test("journal still reads a save written before 1.6.4", function()
        if type(__clearMacros) ~= "function" or type(MACRO_STORE) ~= "table" then return end
        __clearMacros()
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB

        local db = ns.DB.Scratch()
        db.settings.macroJournal = true
        db.credits = 6789
        db.stats.sales = 5
        ns.db = db
        expect(ns.Journal.SaveNow(), "could not seed a save")

        -- Rewrite the committed generation as the 1.6.3 single-generation format.
        local bodies = {}
        for _, macro in pairs(MACRO_STORE) do
            local generation, counter, index, total, stamp, state, data =
                macro.body:match("^%-%-GPSJ2:([AB]):(%d+):(%d+):(%d+):(%d+):([cp]):(.*)$")
            if generation then
                bodies[tonumber(index)] = { total = tonumber(total), stamp = tonumber(stamp), data = data }
            end
        end
        expect(next(bodies) ~= nil, "nothing was written to migrate")
        __clearMacros()
        for index, chunk in pairs(bodies) do
            MACRO_STORE[index] = {
                name = string.format("GPSJ%02d", index),
                icon = 134400,
                body = string.format("--GPSJ1:%.0f:%.0f:%.0f:%s", index, chunk.total, chunk.stamp, chunk.data),
            }
        end

        local fresh = ns.DB.Scratch()
        fresh.settings.macroJournal = true
        ns.db = fresh
        expect(ns.Journal.TryLoad(true), "a pre-1.6.4 journal did not load: " ..
            tostring(ns.Journal.status.error))
        expectEqual(ns.DB.Get().credits, 6789, "the old journal lost credits")
        expectEqual(ns.DB.Get().stats.sales, 5, "the old journal lost stats")

        -- The next save moves to a generation and retires the old chunks.
        expect(ns.Journal.SaveNow(), "the save after an upgrade failed: " .. tostring(ns.Journal.status.error))
        local legacyLeft = 0
        for _, macro in pairs(MACRO_STORE) do
            if type(macro.name) == "string" and macro.name:sub(1, 4) == "GPSJ" then
                legacyLeft = legacyLeft + 1
            end
        end
        expectEqual(legacyLeft, 0, "pre-1.6.4 chunks were left behind after the upgrade save")

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __clearMacros()
    end)

    -----------------------------------------------------------------------
    test("journal keeps a normal shop and the seen-splash flag", function()
        if type(__clearMacros) ~= "function" or type(MACRO_STORE) ~= "table" then return end
        __clearMacros()
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB
        local db = ns.DB.Scratch()
        db.settings.macroJournal = true
        db.settings.welcomeVersion = "1.6.2"
        db.settings.tourDone = true
        db.credits = 777
        db.tier = 2
        db.stats.sales = 12
        for index = 1, 20 do
            db.inventory[index] = {
                uid = index, id = 1000 + index, name = "Journal Shop " .. index,
                icon = "Interface\\Icons\\INV_Misc_Coin_01", quality = 2, ilvl = 20,
                classID = 15, subclassID = 0, category = "misc",
                value = 20 + index, count = 1, acquired = 1, source = "loot",
            }
        end
        ns.db = db

        local ok, status = ns.Journal.SaveNow()
        expect(ok, "normal shop journal save failed: " .. tostring(status))
        expect(not status.trimmed, "a normal shop should not need trimming")

        local fresh = ns.DB.Scratch()
        fresh.settings.macroJournal = true
        ns.db = fresh
        expect(ns.Journal.TryLoad(true), "normal shop journal did not load")
        expectEqual(ns.DB.Get().credits, 777, "normal shop lost credits")
        expectEqual(ns.DB.Get().settings.welcomeVersion, "1.6.2",
            "the splash flag did not survive a login")
        expectEqual(ns.Inventory.Count(), 20, "normal shop lost stock")

        -- Values that differ from the defaults must survive compaction even when
        -- they are falsy or zero.
        local edge = ns.DB.Scratch()
        edge.settings.macroJournal = true
        edge.settings.showWelcome = false
        edge.credits = 0
        ns.db = edge
        expect(ns.Journal.SaveNow(), "edge-case journal save failed")
        local empty = ns.DB.Scratch()
        empty.settings.macroJournal = true
        ns.db = empty
        expect(ns.Journal.TryLoad(true), "edge-case journal did not load")
        expectEqual(ns.DB.Get().credits, 0, "compaction resurrected default credits")
        expect(ns.DB.Get().settings.showWelcome == false, "compaction lost a false setting")

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __clearMacros()
    end)

    -----------------------------------------------------------------------
    test("journal trims low-value stock before campaign state", function()
        if type(__clearMacros) ~= "function" or type(MACRO_STORE) ~= "table" then return end
        __clearMacros()
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB
        local db = ns.DB.Scratch()
        db.settings.macroJournal = true
        db.credits = 12345
        db.tier = 5
        db.campaign.payments = 2
        db.campaign.paid = 7500
        db.museum.donated.weapon = { name = "Large Journal Blade" }
        for index = 1, 80 do
            db.inventory[index] = {
                uid = index, name = "Journal Bulk " .. index, quality = 2, ilvl = 20,
                classID = 15, subclassID = 0, category = "misc",
                value = index, count = 1, acquired = 1,
            }
        end
        ns.db = db

        local ok, status = ns.Journal.SaveNow()
        expect(ok, "large journal save failed: " .. tostring(status))
        expect(status.chunks <= 24, "large journal exceeded the chunk budget")
        expect(status.trimmed, "large journal did not trim inventory")

        local fresh = ns.DB.Scratch()
        fresh.settings.macroJournal = true
        ns.db = fresh
        expect(ns.Journal.TryLoad(true), "trimmed journal did not load")
        local loaded = ns.DB.Get()
        expectEqual(loaded.campaign.payments, 2, "trimming lost campaign state")
        expectEqual(loaded.credits, 12345, "trimming lost credits")
        expect(ns.Inventory.Count() < 80, "trimming kept the entire oversized inventory")

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __clearMacros()
    end)

    -----------------------------------------------------------------------
    test("journal rebinds the live database before an immediate payment or reset", function()
        if type(__clearMacros) ~= "function" or type(MACRO_STORE) ~= "table" then return end
        __clearMacros()
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB

        local original = ns.DB.Scratch()
        original.settings.macroJournal = true
        original.credits = 2000
        original.campaign.payments = 0
        original.campaign.paid = 0
        ns.db = original
        expect(ns.Journal.SaveNow(), "could not seed the journal")

        -- Simulate a login where the restored table replaces the active one.
        local boot = ns.DB.Scratch()
        boot.settings.macroJournal = true
        ns.db = boot
        _G.GoblinPawnStarsDB = boot
        expect(ns.Journal.TryLoad(true), "journal did not load: " .. tostring(ns.Journal.status.error))
        expect(_G.GoblinPawnStarsDB == ns.DB.Get(),
            "journal restore left the active database unbound")

        local ok, payment = ns.Campaign.Pay()
        expect(ok and payment.amount == 1500, "payment right after restore failed")
        expectEqual(ns.DB.Get().campaign.payments, 1, "payment right after restore did not stick")
        expectEqual(ns.DB.Get().credits, 500, "payment right after restore charged the wrong amount")

        -- The payment's immediate save must be readable before an autosave can run.
        local checkpoint = ns.DB.Scratch()
        checkpoint.settings.macroJournal = true
        ns.db = checkpoint
        _G.GoblinPawnStarsDB = checkpoint
        expect(ns.Journal.TryLoad(true), "payment journal did not load")
        expectEqual(ns.DB.Get().campaign.payments, 1, "payment was not saved immediately")
        expectEqual(ns.DB.Get().credits, 500, "immediate payment save lost credits")

        -- Reset immediately after this restore, again before an autosave.
        ns.DB.Reset()
        expect(_G.GoblinPawnStarsDB == ns.DB.Get(),
            "reset after restore left the active database unbound")
        expectEqual(ns.DB.Get().campaign.payments, 0, "reset did not clear the campaign")
        local resetCredits = ns.DB.Get().credits
        expectEqual(resetCredits, ns.DB.Scratch().credits, "reset kept the old credit balance")

        local afterReset = ns.DB.Scratch()
        afterReset.settings.macroJournal = true
        ns.db = afterReset
        _G.GoblinPawnStarsDB = afterReset
        expect(ns.Journal.TryLoad(true), "reset journal did not load")
        expectEqual(ns.DB.Get().campaign.payments, 0, "reset journal restored the old campaign")
        expectEqual(ns.DB.Get().credits, resetCredits, "reset journal restored old credits")

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __clearMacros()
    end)

    -----------------------------------------------------------------------
    test("franchise commits its deferred reset to the journal", function()
        if type(__clearMacros) ~= "function" or type(MACRO_STORE) ~= "table" then return end
        __clearMacros()
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB

        local original = ns.DB.Scratch()
        original.settings.macroJournal = true
        original.credits = 10000
        original.campaign.payments = 3
        original.campaign.paid = 32500
        original.campaign.completed = true
        original.campaign.mode = "endless"
        original.museum.unlocked = true
        original.museum.donated.weapon = { name = "Heirloom Blade" }
        original.regular.unlocked = true
        original.regular.visits = 1
        ns.db = original
        _G.GoblinPawnStarsDB = original
        expect(ns.Journal.SaveNow(), "could not seed the franchise journal")

        local ok, level = ns.Campaign.Franchise()
        expect(ok and level == 1, "franchise did not open the first level")
        expect(_G.GoblinPawnStarsDB == ns.DB.Get(),
            "franchise reset left the active database unbound")

        local checkpoint = ns.DB.Scratch()
        checkpoint.settings.macroJournal = true
        ns.db = checkpoint
        _G.GoblinPawnStarsDB = checkpoint
        expect(ns.Journal.TryLoad(true), "franchise journal did not load")
        local loaded = ns.DB.Get()
        expectEqual(loaded.prestige.level, 1, "franchise level was not journaled")
        expectEqual(loaded.campaign.payments, 0, "franchise journal restored the old debt")
        expectEqual(loaded.museum.donated.weapon.name, "Heirloom Blade", "franchise lost the museum")
        expectEqual(loaded.regular.visits, 1, "franchise lost Marta's visits")

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __clearMacros()
    end)

    -----------------------------------------------------------------------
    test("the deed pays three notes and offers endless mode", function()
        withScratch(function(scratch)
            scratch.credits = 50000
            scratch.settings.macroJournal = false
        end, function(scratch)
            local ok, payment = ns.Campaign.Pay()
            expect(ok and payment.amount == 1500, "first payment failed")
            expectEqual(scratch.campaign.payments, 1, "first payment was not counted")
            expectEqual(scratch.credits, 48500, "first payment charged the wrong amount")
            expect(scratch.regular.unlocked, "first payment did not unlock Marta")

            ok = ns.Campaign.Pay()
            expect(ok, "second payment failed")
            ok = ns.Campaign.Pay()
            expect(ok, "third payment failed")
            expect(ns.Campaign.Completed(), "debt did not complete")
            expectEqual(scratch.campaign.paid, 32500, "debt total was wrong")
            expectEqual(scratch.credits, 17500, "payments charged the wrong total")
            expectEqual(scratch.stats.debtPaid, 32500, "lifetime debt stat was wrong")
            expectEqual(ns.Campaign.Mode(), "ending", "ending choice was not offered")

            expect(ns.Campaign.Endless(), "endless mode was rejected")
            expectEqual(ns.Campaign.Mode(), "endless", "endless mode did not stick")
        end)
    end)

    -----------------------------------------------------------------------
    test("the museum consumes stock and pays a permanent offer bonus", function()
        withScratch(function(scratch)
            scratch.credits = 2000
            scratch.settings.macroJournal = false
            ns.Campaign.Pay()
            for index, slot in ipairs(ns.Data.Museum.slots) do
                ns.Inventory.Add({
                    id = 8000 + index, name = "Museum Piece " .. index, quality = 2, ilvl = 20,
                    classID = 15, subclassID = 0, category = slot.key, value = 100,
                })
            end
        end, function(scratch)
            local beforeMuseum = ns.Museum.Count()
            local beforeStock = ns.Inventory.Count()
            local beforeCredits = scratch.credits
            local ok = ns.Museum.Donate("weapon")
            expect(ok, "weapon donation failed")
            expectEqual(ns.Museum.Count(), beforeMuseum + 1, "museum count did not advance")
            expectEqual(ns.Inventory.Count(), beforeStock - 1, "donation did not consume stock")
            expectEqual(scratch.credits, beforeCredits, "donation created credits")
            expect(not ns.Museum.Donate("weapon"), "the same slot was donated twice")

            for _, slot in ipairs(ns.Data.Museum.slots) do
                if not ns.Museum.Donated(slot.key) then ns.Museum.Donate(slot.key) end
            end
            expect(ns.Museum.Completed(), "museum did not complete")
            expect(math.abs(ns.Campaign.OfferBonus() - 0.05) < 0.001, "museum bonus was not applied")
        end)
    end)

    -----------------------------------------------------------------------
    test("Marta makes three paid visits and keeps her bonus", function()
        withScratch(function(scratch)
            scratch.credits = 5000
            scratch.settings.macroJournal = false
            ns.Campaign.Pay()
        end, function(scratch)
            for visit = 1, 3 do
                ns.Inventory.Add({
                    id = 9000 + visit, name = "Marta Test Piece " .. visit, quality = 3, ilvl = 40,
                    classID = 15, subclassID = 0, category = "misc", value = 400,
                })
                local called = ns.Regular.Call()
                expect(called, "Marta could not be invited on visit " .. visit)
                expect(ns.Customers.StartNegotiation(1), "Marta negotiation did not start")
                local accepted = ns.Negotiation.Accept()
                expect(accepted, "Marta sale failed on visit " .. visit)
            end
            expectEqual(ns.Regular.Visits(), 3, "Marta visits were not counted")
            expect(ns.Regular.Done(), "Marta's story did not complete")
            expect(scratch.stats.regularVisits == 3, "regular visits stat was wrong")
            expect(math.abs(ns.Campaign.OfferBonus() - 0.03) < 0.001, "Marta bonus was not applied")
        end)
    end)

    -----------------------------------------------------------------------
    test("franchise resets the run but keeps museum and prestige", function()
        withScratch(function(scratch)
            scratch.credits = 100000
            scratch.settings.macroJournal = false
            scratch.tier = 3
            scratch.prestige.level = 1
            scratch.achievements.first_sale = { at = 1 }
            scratch.museum.completed = true
            scratch.regular.done = true
            for _ = 1, 3 do ns.Campaign.Pay() end
        end, function(scratch)
            local ok, level = ns.Campaign.Franchise()
            expect(ok, "franchise failed")
            expectEqual(level, 2, "franchise level did not advance")
            local fresh = ns.DB.Get()
            expectEqual(fresh.credits, 250, "franchise did not reset credits")
            expectEqual(fresh.tier, 1, "franchise did not reset the shop tier")
            expectEqual(fresh.prestige.level, 2, "franchise level was lost")
            expect(fresh.museum.completed, "franchise lost the museum")
            expect(fresh.regular.done, "franchise lost Marta's story")
            expect(fresh.achievements.first_sale, "franchise lost achievements")
            expectEqual(fresh.campaign.payments, 0, "franchise did not start a new deed")
            expect(ns.Inventory.Count() >= 2, "franchise did not grant starter stock")
        end)
    end)

    -----------------------------------------------------------------------
    test("loot eligibility rejects junk and quest items", function()
        expect(ns.Data.IsEligible({ name = "Grey Rock", quality = 0, classID = 15, ilvl = 1 }) == false,
            "grey items should be ineligible")
        expect(ns.Data.IsEligible({ name = "Quest Thing", quality = 2, classID = 12, ilvl = 1 }) == false,
            "quest items should be ineligible")
        expect(ns.Data.IsEligible({ name = "Fine Sword", quality = 3, classID = 2, ilvl = 40 }) == true,
            "weapons should be eligible")
    end)

    -----------------------------------------------------------------------
    test("report bundle is compact, pasteable and probes the client", function()
        ns.RecordError("test", "synthetic report failure")
        local text = ns.Report.Build()
        expect(type(text) == "string" and #text > 100, "report should build text")
        expect(text:sub(1, 4) == "GPS|", "report should start with the GPS| prefix")
        expect(text:find(ns.VERSION, 1, true) ~= nil, "report should carry the version")
        for _, needle in ipairs({ "api:", "journal:", "errors:", "econ:", "deed:", "pace:" }) do
            expect(text:find(needle, 1, true) ~= nil, "report is missing " .. needle)
        end
        expect(text:find("synthetic report failure", 1, true) ~= nil,
            "recorded errors should appear in the report")
        local lines = 1
        for _ in text:gmatch("\n") do lines = lines + 1 end
        expect(lines <= 12, "report must stay compact, got " .. lines .. " lines")

        for index, entry in ipairs(ns.errors or {}) do
            if entry.text == "synthetic report failure" then
                table.remove(ns.errors, index)
                break
            end
        end
    end)

    return results
end

function D.Report()
    local results = D.Run()
    local passed, failed = 0, 0
    for _, result in ipairs(results) do
        if result.ok then
            passed = passed + 1
            ns.Print("|cff7bd66bPASS|r " .. result.name)
        else
            failed = failed + 1
            ns.Print("|cffff5555FAIL|r " .. result.name .. " — " .. tostring(result.error))
        end
    end
    ns.Print(string.format("Diagnostics: |cff7bd66b%d passed|r, %s%d failed|r", passed,
        failed > 0 and "|cffff5555" or "|cff888888", failed))
    return results, passed, failed
end
