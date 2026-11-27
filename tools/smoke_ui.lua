-- UI smoke test executed by tools/run_tests.js inside the mocked client.
-- Builds every tab, opens the main window, drives the negotiation and event
-- frames and runs the slash command handler. Catches nil-field and typo errors
-- that only appear when a tab is first shown.

function __smoke()
    local failures = {}
    local function attempt(name, fn)
        local ok, err = pcall(fn)
        if not ok then
            failures[#failures + 1] = name .. ": " .. tostring(err)
        end
    end

    local clone = __NS.DB.Scratch()
    local real = __NS.db
    __NS.db = clone

    __NS.Inventory.Add({
        id = 2589, name = "Linen Cloth", quality = 1, ilvl = 5,
        classID = 7, subclassID = 5, category = "cloth", value = 60,
    })
    __NS.Inventory.Add({
        id = 19019, name = "Thunderfury, Blessed Blade of the Windseeker", quality = 5,
        ilvl = 80, classID = 2, subclassID = 7, category = "weapon", value = 5000,
    })
    clone.credits = 60000
    clone.tier = 4

    attempt("customer arrival card", function()
        local UI = __NS.UI
        local arrivalDb = __NS.DB.Scratch()
        arrivalDb.shop.waiting = { { name = "Test merchant", class = "MAGE", race = "Goblin" } }
        __NS.db = arrivalDb
        local checked, problem = pcall(function()
            UI.Close()
            local panel = UI.CustomerArrival.Show(arrivalDb.shop.waiting[1])
            assert(panel and panel:IsShown() and panel.door:IsShown(), "missing closed-shop entrance")
            assert(panel.name:GetText() == "Test merchant", "customer name missing")
            assert(panel.detail:GetText():find("1 waiting", 1, true), "queue count missing")
            local actorPoint = panel.actor.__points[#panel.actor.__points]
            assert(actorPoint.point == "LEFT" and actorPoint[3] == 4,
                "closed-shop customer did not rest inside the doorway")
            local firstPoint = panel.__points[#panel.__points]
            assert(firstPoint.point == "CENTER" and firstPoint[3] == 0 and firstPoint[4] == 0,
                "closed-shop card did not start centered")
            local expired = TIMERS[#TIMERS].callback
            panel.GetCenter = function() return 45, 85 end
            panel:GetScript("OnDragStart")(panel)
            expired()
            assert(panel:IsShown(), "arrival vanished during a drag")
            panel:GetScript("OnDragStop")(panel)
            panel:GetScript("OnMouseUp")(panel, "LeftButton")
            assert(panel:IsShown() and not UI.IsOpen(), "drag also triggered click-through")
            local positions = arrivalDb.settings.arrivalPositions
            assert(positions.screen.x == 45 and positions.screen.y == 85 and not positions.shop,
                "drag did not save the closed-shop position independently")
            UI.Open()
            UI.CustomerArrival.Position()
            local shopPoint = panel.__points[#panel.__points]
            assert(panel:GetWidth() == 420 and shopPoint[3] == 0 and shopPoint[4] == 0,
                "open-shop card did not enlarge and center independently")
            actorPoint = panel.actor.__points[#panel.actor.__points]
            assert(actorPoint.point == "LEFT" and actorPoint[3] == 6,
                "open-shop customer did not rest inside the doorway")
            panel.GetCenter = function() return -60, 130 end
            panel:GetScript("OnDragStart")(panel)
            panel:GetScript("OnDragStop")(panel)
            assert(positions.shop.x == -60 and positions.shop.y == 130 and positions.screen.x == 45,
                "dragging the shop card moved the closed-shop card")
            arrivalDb.settings.customerArrival = "Compact"
            arrivalDb.shop.waiting[2] = { name = "Second merchant", rare = true }
            UI.CustomerArrival.Show(arrivalDb.shop.waiting[2])
            expired()
            assert(panel:IsShown() and not panel.door:IsShown(), "old timer hid the compact card")
            actorPoint = panel.actor.__points[#panel.actor.__points]
            assert(actorPoint.point == "LEFT" and actorPoint[3] == 8,
                "compact customer moved out of the icon")
            assert(panel.detail:GetText():find("2 waiting", 1, true), "queue count did not update")
            panel:GetScript("OnMouseDown")(panel, "LeftButton")
            panel:GetScript("OnMouseUp")(panel, "LeftButton")
            assert(not panel:IsShown() and UI.IsOpen() and UI.Tabs.customers.frame:IsShown(),
                "arrival click did not open Customers")
            UI.Close()
            arrivalDb.settings.customerArrival = "Off"
            UI.CustomerArrival.Show(arrivalDb.shop.waiting[1])
            assert(not panel:IsShown(), "Off mode showed an arrival")
            arrivalDb.shop.waiting = {}
            SlashCmdList.GOBLINPAWNSTARS("arrival")
            assert(panel:IsShown() and panel.door:IsShown(), "preview requires live arrivals")
            assert(panel.detail:GetText() == "Arrival preview", "preview label is missing")
            local savedPoint = panel.__points[#panel.__points]
            assert(savedPoint[3] == 45 and savedPoint[4] == 85, "preview did not restore the saved position")
            assert(#arrivalDb.shop.waiting == 0 and arrivalDb.settings.customerArrival == "Off",
                "preview changed the queue or arrival setting")

        end)
        UI.CustomerArrival.Hide()
        __NS.db = clone
        assert(checked, problem)
    end)

    attempt("arrival error falls back to the original toast", function()
        local UI = __NS.UI
        local show, toast = UI.CustomerArrival.Show, UI.Toast
        local message
        UI.CustomerArrival.Show = function() error("simulated client UI error") end
        UI.Toast = function(text) message = text end
        local ok, err = pcall(__NS.Customers.NotifyArrival, { name = "Test merchant" })
        UI.CustomerArrival.Show, UI.Toast = show, toast
        assert(ok, err)
        assert(message == "Test merchant walked into the shop.", "fallback toast missing")
    end)

    attempt("native customer model keeps an icon until loaded and plays walk and idle", function()
        local C, widgets = __NS.Compat, __NS.Widgets
        local createFrame = C.CreateFrame
        local parent = widgets.Create(UIParent, "Frame")
        local icon = parent:CreateTexture()
        local display, fileID, played
        local model = {
            SetPoint = function() end,
            SetAlpha = function() end,
            EnableMouse = function() end,
            Show = function() end,
            SetScript = function(self, name, callback)
                assert(name == "OnModelLoaded")
                self.loaded = callback
            end,
            ClearModel = function() fileID = nil end,
            SetDisplayInfo = function(_, id) display = id end,
            GetDisplayInfo = function() return display end,
            GetModelFileID = function() return fileID or 0 end,
            SetAnimation = function(_, id) played = id end,
        }
        C.CreateFrame = function(kind)
            assert(kind == "PlayerModel")
            return model
        end
        local ok, widget = pcall(__NS.UI.CustomerModel.Attach, parent, icon, 0)
        C.CreateFrame = createFrame
        assert(ok and widget, widget)
        widget:SetCustomer({ name = "Goblin merchant", race = "Goblin" }, function(customerModel)
            customerModel:SetWalking(true)
        end)
        assert(icon:IsShown() and type(display) == "number", "pending model hid the icon")
        fileID = 9999
        model.loaded()
        assert(not icon:IsShown() and played == 4, "native model did not start its walk after loading")
        widget:SetWalking(false)
        assert(played == 0, "native model did not return to idle")
        widget:SetCustomer({ name = "Dwarf vendor", race = "Dwarf" })
        assert(icon:IsShown(), "new pending model kept the old portrait")
        TIMERS[#TIMERS].callback()
        assert(icon:IsShown() and display == 7094, "unavailable model did not try the goblin fallback")
    end)

    attempt("animation helpers reuse one group per region", function()
        -- Animation groups belong to their region for its whole life. Creating
        -- one per call leaked thousands of them in a long session, which is what
        -- made the client slower and slower.
        local created = 0
        local function animation()
            return {
                SetDuration = function() end,
                SetFromAlpha = function() end,
                SetToAlpha = function() end,
                SetSmoothing = function() end,
                SetScaleFrom = function() end,
                SetScaleTo = function() end,
                SetStartDelay = function() end,
                SetDegrees = function() end,
            }
        end
        local region = {
            GetScale = function() return 1 end,
            SetScale = function() end,
            SetAlpha = function() end,
            CreateAnimationGroup = function()
                created = created + 1
                return {
                    CreateAnimation = function() return animation() end,
                    SetScript = function() end,
                    SetLooping = function() end,
                    Play = function() end,
                    Stop = function() end,
                }
            end,
        }
        for _ = 1, 40 do
            __NS.Anim.Reveal(region, 0.2, 0)
            __NS.Anim.Pulse(region, 1.1, 0.2)
        end
        assert(created == 2, "animation groups are recreated per call: " .. created)
    end)

    attempt("customer model frame moves across the doorway", function()
        local finished = 0
        local actor = { CreateAnimationGroup = function()
            return {
                CreateAnimation = function(_, kind)
                    assert(kind == "Translation")
                    return {
                        SetDuration = function(_, seconds) assert(seconds == 1.1) end,
                        SetOffset = function(_, x, y) assert(x == 34 and y == 0) end,
                    }
                end,
                SetScript = function(group, name, callback)
                    assert(name == "OnFinished")
                    group.finished = callback
                end,
                Play = function(group) group.finished() end,
            }
        end }
        __NS.Anim.CustomerWalk(actor, 34, function() finished = finished + 1 end)
        __NS.Anim.CustomerWalk({}, 34, function() finished = finished + 1 end)
        assert(finished == 2, "missing animation API did not settle the model")
    end)

    attempt("settings clicks update labels and values", function()
        local UI, widgets = __NS.UI, __NS.Widgets
        local db = __NS.DB.Scratch()
        local buttons = {}
        local makeButton = widgets.Button
        __NS.db = db
        widgets.Button = function(parent, label, ...)
            local button = makeButton(parent, label, ...)
            buttons[#buttons + 1] = button
            return button
        end
        local ok, problem = pcall(function()
            UI.Open()
            UI.ShowTab("settings")
            local function click(button)
                button:GetScript("OnClick")(button, "LeftButton")
                return button.label:GetText()
            end
            local fields = { "sound", "minimap", "autoCollect", "autoSell", "paused" }
            for index, field in ipairs(fields) do
                local before = db.settings[field]
                local button = buttons[index]
                assert(click(button) == (before and "Off" or "On"), field .. " label did not toggle")
                assert(db.settings[field] == (not before), field .. " value did not toggle")
                click(button)
            end
            for _, mode in ipairs({ "Compact", "Off", "Animated" }) do
                assert(click(buttons[6]) == mode and db.settings.customerArrival == mode,
                    "notification mode did not change to " .. mode)
            end
            db.shop.nextArrival = 40
            for _, state in ipairs({ { "Fast", 20 }, { "Relaxed", 80 }, { "Normal", 40 } }) do
                assert(click(buttons[7]) == state[1] and db.settings.arrivalPace == state[1],
                    "arrival pace did not change to " .. state[1])
                assert(db.shop.nextArrival == state[2], "active countdown was not adjusted")
            end
            assert(click(buttons[8]) == "−" and db.settings.scale == 0.95, "scale minus did not work")
            assert(click(buttons[9]) == "+" and db.settings.scale == 1, "scale plus did not work")
            assert(click(buttons[10]) == "On" and db.settings.questAutoSell == true,
                "questing toggle did not turn on")
            assert(click(buttons[10]) == "Off" and db.settings.questAutoSell == false,
                "questing toggle did not turn off")
        end)
        widgets.Button = makeButton
        __NS.db = clone
        UI.Refresh()
        assert(ok, problem)
    end)

    attempt("rolling backup window captures without changing the shop", function()
        local previous = __NS.db
        local wasScratch = __NS.DB.scratch
        local ok, problem = pcall(function()
            local db = __NS.DB.Scratch()
            __NS.db = db
            local backup = __NS.UI.BackupFrame
            assert(backup, "backup window did not load")
            backup.Show()
            local frame = backup.Frame()
            assert(frame and frame:IsShown(), "backup window did not show")
            local beforeCredits = db.credits
            local beforeItems = __NS.Inventory.Count()
            local snapshot, err = __NS.Backups.Capture("manual")
            assert(snapshot, "manual backup failed: " .. tostring(err))
            assert(db.credits == beforeCredits, "backup capture changed credits")
            assert(__NS.Inventory.Count() == beforeItems, "backup capture changed stock")
            backup.Refresh()
            assert(#__NS.Backups.Slots() >= 1, "backup window did not list the snapshot")
            backup.Hide()
            assert(not frame:IsShown(), "backup window did not hide")
        end)
        __NS.db = previous
        __NS.DB.scratch = wasScratch
        assert(ok, problem)
    end)

    attempt("main window open", function() __NS.UI.Open() end)
    attempt("main window toggle", function() __NS.UI.Toggle(); __NS.UI.Toggle() end)

    -- Guards the bug where the sidebar was anchored to the window's right edge:
    -- the client then stretched it (and every tab button) across the tab content,
    -- so clicks meant for the tabs hit the sidebar tabs instead.
    attempt("sidebar and tabs stay in the sidebar", function()
        local sidebar = __NS.UI.Sidebar
        if not sidebar then error("sidebar is not exposed for testing") end
        if sidebar:GetWidth() ~= 188 then
            error("sidebar width is " .. tostring(sidebar:GetWidth()) .. ", expected 188")
        end
        for _, entry in ipairs(sidebar.__points or {}) do
            local anchor = entry.point
            if anchor == "RIGHT" or anchor == "TOPRIGHT" or anchor == "BOTTOMRIGHT" then
                error("sidebar is anchored to the right edge (" .. anchor .. ") and will cover the tabs")
            end
        end
        local count = 0
        for id, button in pairs(__NS.UI.TabButtons or {}) do
            count = count + 1
            if button:GetWidth() ~= 172 or button:GetHeight() ~= 36 then
                error("tab button " .. id .. " is " .. tostring(button:GetWidth()) .. "x"
                    .. tostring(button:GetHeight()) .. ", expected 172x36")
            end
        end
        if count ~= #__NS.UI.TabOrder then
            error("only " .. count .. " tab buttons for " .. #__NS.UI.TabOrder .. " tabs")
        end
    end)

    for _, id in ipairs(__NS.UI.TabOrder) do
        attempt("tab " .. id, function()
            __NS.UI.ShowTab(id)
            local def = __NS.UI.Tabs[id]
            if def and def.api and def.api.Refresh then def.api.Refresh() end
        end)
    end

    attempt("inventory filters", function()
        __NS.UI.ShowTab("inventory")
        local def = __NS.UI.Tabs.inventory
        if def and def.api then def.api.Refresh() end
    end)

    attempt("dashboard refresh", function()
        __NS.UI.ShowTab("dashboard")
        local def = __NS.UI.Tabs.dashboard
        if def and def.api then def.api.Refresh() end
    end)

    attempt("spawn and negotiate", function()
        __NS.Customers.TrySpawn({ personality = "collector" })
        __NS.UI.ShowTab("customers")
        local def = __NS.UI.Tabs.customers
        if def and def.api then def.api.Refresh() end
        local started = __NS.UI.StartNegotiation(1)
        if not started then error("negotiation did not start") end
        __NS.UI.Negotiation.Refresh()
        local result = __NS.Negotiation.Appraise()
        if not result then error("appraise failed") end
        __NS.UI.Negotiation.Hide()
    end)

    attempt("accept offer displays the exact credits added", function()
        local db = __NS.DB.Get()
        if not __NS.Negotiation.Active() then
            __NS.Customers.TrySpawn({ personality = "gullible" })
            if not __NS.Customers.StartNegotiation(1) then error("negotiation did not start") end
        end
        __NS.UI.Negotiation.Show()
        local button = __NS.UI.Negotiation.AcceptButton()
        if not button then error("accept control is not exposed") end
        local before = db.credits or 0
        button:GetScript("OnClick")(button, "LeftButton")
        local delta = (db.credits or 0) - before
        if delta <= 0 then error("accept paid nothing") end
        local shown = __NS.UI.Negotiation.PayoutText()
        local expected = "+" .. __NS.Util.comma(delta) .. " gc"
        if shown ~= expected then
            error("accept banner " .. tostring(shown) .. " != credits added " .. expected)
        end
    end)

    attempt("counter button completes and pays for a sale", function()
        local db = __NS.DB.Get()
        __NS.Inventory.Add({
            id = 2770, name = "Copper Ore", quality = 1, ilvl = 5,
            classID = 7, subclassID = 7, category = "ore", value = 40,
        })
        __NS.Customers.TrySpawn({ personality = "gullible" })
        if not __NS.Customers.StartNegotiation(1) then error("negotiation did not start") end
        __NS.UI.Negotiation.Show()

        local box = __NS.UI.Negotiation.CounterBox()
        local button = __NS.UI.Negotiation.CounterButton()
        if not box or not button then error("counter controls are not exposed") end
        box:SetText("1")

        local original = __NS.Util.chance
        __NS.Util.chance = function() return true end
        local before = db.credits or 0
        button:GetScript("OnClick")(button, "LeftButton")
        __NS.Util.chance = original

        -- Reading only the first return of Negotiation.Counter used to pass a
        -- boolean here and error before the payout, leaving the window stuck.
        if __NS.Negotiation.Active() then error("counter did not complete the sale") end
        local delta = (db.credits or 0) - before
        if delta <= 0 then error("counter win paid nothing") end
        local shown = __NS.UI.Negotiation.PayoutText()
        local expected = "+" .. __NS.Util.comma(delta) .. " gc"
        if shown ~= expected then
            error("counter banner " .. tostring(shown) .. " != credits added " .. expected)
        end
    end)

    attempt("auto-sale header equals the exact credits added", function()
        local db = __NS.DB.Get()
        db.shop.current = nil
        db.shop.waiting = {}
        db.shop.nextArrival = 999
        db.employees.salesperson = 1
        db.settings.autoSell = true
        db.settings.questAutoSell = false
        db.settings.paused = false
        local record = __NS.Inventory.Add({
            id = 2771, name = "Auto Sale Ore", quality = 1, ilvl = 5,
            classID = 7, subclassID = 7, category = "ore", value = 100,
        })
        if not record then error("could not add auto-sale stock") end
        db.shop.waiting = { {
            name = "Auto buyer", itemUid = record.uid,
            offer = 100, maxPay = 200, patience = 30, patienceMax = 30,
            personality = "gullible",
        } }
        db.credits = 0
        __NS.UI.Open()
        __NS.UI.Refresh()
        local header = __NS.UI.Header
        if not header then error("header is not exposed") end
        if header.creditsValue:GetText() ~= "0" then error("header did not start at 0") end

        __NS.Customers.Tick(20)
        local delta = (db.credits or 0) - 0
        if delta <= 0 then error("auto-sale did not pay") end
        local expected = __NS.Util.comma(db.credits)
        if header.creditsValue:GetText() ~= expected then
            error("header shows " .. tostring(header.creditsValue:GetText())
                .. " but wallet is " .. expected)
        end
    end)

    attempt("every market event", function()
        for _, event in ipairs(__NS.Data.MarketEvents) do
            __NS.Market.StartEvent(event.key)
        end
        __NS.UI.ShowTab("market")
        local def = __NS.UI.Tabs.market
        if def and def.api then def.api.Refresh() end
        __NS.Market.StopEvent("war_effort")
    end)

    attempt("every encounter popup", function()
        for _, def in ipairs(__NS.Data.Encounters) do
            __NS.Encounters.Trigger(def.key)
            if __NS.Encounters.Pending() then
                __NS.UI.EventFrame.Show()
                local event = __NS.Encounters.Pending()
                local option = event.options and event.options[1]
                if option then __NS.Encounters.Resolve(option.id) end
                __NS.Encounters.ClearResult()
            end
        end
        __NS.UI.ShowTab("customers")
        local def = __NS.UI.Tabs.customers
        if def and def.api then def.api.Refresh() end
    end)

    attempt("hire and promote every employee", function()
        clone.tier = 5
        clone.credits = 500000
        for _, employee in ipairs(__NS.Data.Employees) do
            __NS.Staff.Hire(employee.key)
            __NS.Staff.Promote(employee.key)
        end
        __NS.UI.ShowTab("employees")
        local def = __NS.UI.Tabs.employees
        if def and def.api then def.api.Refresh() end
    end)

    attempt("buy every upgrade", function()
        clone.tier = 5
        clone.credits = 1000000
        for _, upgrade in ipairs(__NS.Data.Upgrades) do
            __NS.Shop.BuyUpgrade(upgrade.key)
        end
        __NS.UI.ShowTab("upgrades")
        local def = __NS.UI.Tabs.upgrades
        if def and def.api then def.api.Refresh() end
    end)

    attempt("wholesaler window buys a lot", function()
        __NS.Wholesaler.Restock()
        __NS.UI.Wholesaler.Show()
        local lots = __NS.Wholesaler.Lots()
        if #lots ~= 3 then error("expected three wholesale lots") end
        local before = clone.credits
        local ok, record = __NS.Wholesaler.Buy(1)
        if not ok then error("wholesaler purchase failed: " .. tostring(record)) end
        if clone.credits >= before then error("wholesaler did not spend credits") end
        __NS.UI.Wholesaler.Refresh()
        __NS.UI.Wholesaler.Hide()
    end)

    attempt("upgrade tier", function()
        clone.credits = 500000
        __NS.Shop.UpgradeTier()
    end)

    attempt("achievements tab", function()
        __NS.UI.ShowTab("achievements")
        local def = __NS.UI.Tabs.achievements
        if def and def.api then def.api.Refresh() end
    end)

    attempt("history tab", function()
        __NS.UI.ShowTab("history")
        local def = __NS.UI.Tabs.history
        if def and def.api then def.api.Refresh() end
    end)

    attempt("settings tab", function()
        __NS.UI.ShowTab("settings")
        local def = __NS.UI.Tabs.settings
        if def and def.api then def.api.Refresh() end
        __NS.DB.Export()
    end)

    attempt("item parsing uses the documented return positions", function()
        local cloth = __NS.Compat.Item(2589)
        if not cloth then error("2589 did not parse") end
        if cloth.classID ~= 7 then error("classID parsed as " .. tostring(cloth.classID)) end
        if cloth.subclassID ~= 5 then error("subclassID parsed as " .. tostring(cloth.subclassID)) end
        if __NS.Data.CategoryOf(cloth) ~= "cloth" then
            error("Linen Cloth filed as " .. tostring(__NS.Data.CategoryOf(cloth)))
        end
        local ore = __NS.Compat.Item(2770)
        if __NS.Data.CategoryOf(ore) ~= "ore" then error("Copper Ore should be ore") end
        local sword = __NS.Compat.Item(19019)
        if __NS.Data.CategoryOf(sword) ~= "weapon" then error("Thunderfury should be a weapon") end
        local quest = __NS.Compat.Item(5512)
        if __NS.Data.IsEligible(quest) then error("quest item should be ineligible") end
    end)

    local function withBags(map)
        -- Bags report their capacity even when empty (the real client always
        -- does), so scanning an empty backpack is still "readable".
        C_Container.GetContainerNumSlots = function(bag)
            return map[bag] and 16 or 0
        end
        C_Container.GetContainerItemInfo = function(bag, slot)
            local list = map[bag]
            local id = list and list[slot]
            if not id then return nil end
            local row = ITEM_DB[id]
            return { itemID = id, stackCount = 1, hyperlink = row and row[2] or nil }
        end
        C_Container.GetContainerItemLink = function(bag, slot)
            local list = map[bag]
            local id = list and list[slot]
            local row = id and ITEM_DB[id]
            return row and row[2] or nil
        end
    end

    attempt("empty bags still form a baseline", function()
        local bags = { [0] = {} }
        withBags(bags)
        clone.baseline = nil
        local initial = __NS.Loot.Scan(true)
        if initial ~= 0 then error("an empty baseline added stock") end

        table.insert(bags[0], 2592)
        local added = __NS.Loot.Scan(true)
        if added ~= 1 then
            error("the first item looted after an empty login was swallowed: " .. tostring(added))
        end
    end)

    attempt("re-looting after bags empty is detected", function()
        local bags = { [0] = { 2589, 2589 } }
        withBags(bags)
        clone.baseline = { counts = {}, at = 0 }
        __NS.Loot.Scan(true)

        -- Player sells/destroys the real items; baseline must follow the drop.
        bags[0] = {}
        __NS.Loot.Scan(true)

        table.insert(bags[0], 2589)
        local added = __NS.Loot.Scan(true)
        if added ~= 1 then
            error("re-looting the same item was invisible after the bags emptied: " .. tostring(added))
        end
    end)

    attempt("uncached loot is stocked from its link", function()
        local bags = { [0] = { 4306 } }
        withBags(bags)
        local originalInfo = C_Item.GetItemInfo
        local originalName = C_Item.GetItemNameByID
        C_Item.GetItemInfo = function(item)
            if tonumber(item) == 4306 then return nil end
            return originalInfo(item)
        end
        C_Item.GetItemNameByID = function(item)
            if tonumber(item) == 4306 then return nil end
            return originalName(item)
        end

        clone.baseline = { counts = {}, at = 0 }
        local added = __NS.Loot.Scan(true)

        C_Item.GetItemInfo = originalInfo
        C_Item.GetItemNameByID = originalName
        if added ~= 1 then
            error("an uncached item was not stocked from its hyperlink: " .. tostring(added))
        end
    end)

    attempt("stock bags now imports current loot once", function()
        ITEM_DB[5000] = {
            "Test Relic", "|cff1eff00|Hitem:5000|h[Test Relic]|h|r", 2, 30, 1,
            "Armor", "Cloth", 20, "", 134939, 30, 4, 1,
        }
        local bags = { [0] = { 5000 } }
        withBags(bags)
        clone.baseline = nil

        local added = __NS.Loot.ImportCurrentBags()
        if added ~= 1 then error("import stocked " .. tostring(added) .. " stacks, expected 1") end
        local again = __NS.Loot.ImportCurrentBags()
        if again ~= 0 then error("a second import duplicated the stack") end
        if not __NS.Inventory.FindByItemID(5000) then error("imported item is missing from stock") end
    end)

    attempt("bag scan deduplicates", function()
        local bags = { [0] = { 2589, 2770 } }
        local originalSlots = C_Container.GetContainerNumSlots
        local originalInfo = C_Container.GetContainerItemInfo
        C_Container.GetContainerNumSlots = function(bag)
            local list = bags[bag]
            return list and #list or 0
        end
        C_Container.GetContainerItemInfo = function(bag, slot)
            local list = bags[bag]
            local id = list and list[slot]
            if not id then return nil end
            return { itemID = id, stackCount = 1, hyperlink = "|Hitem:" .. id .. "|h[x]|h" }
        end

        local function stockUnits()
            local total = 0
            for _, record in pairs(__NS.DB.Get().inventory) do
                total = total + (tonumber(record.count) or 0)
            end
            return total
        end

        clone.baseline = nil
        local before = stockUnits()
        local baseline = __NS.Loot.Scan(true)
        if baseline ~= 0 then error("first scan should only capture a baseline") end

        table.insert(bags[0], 2592)
        local added = __NS.Loot.Scan(true)
        if added ~= 1 then error("expected one new item, got " .. tostring(added)) end
        if stockUnits() ~= before + 1 then error("stock units did not increase by one") end

        local duplicate = __NS.Loot.Scan(true)
        if duplicate ~= 0 then error("duplicate scan added " .. tostring(duplicate) .. " items") end

        C_Container.GetContainerNumSlots = originalSlots
        C_Container.GetContainerItemInfo = originalInfo
    end)

    attempt("welcome frame gating", function()
        local db = __NS.DB.Get()
        db.settings.showWelcome = true
        db.settings.welcomeVersion = nil
        __NS.UI.Welcome.MaybeShow()
        if not __NS.UI.Welcome.IsShown() then error("welcome did not show on first run") end
        if __NS.UI.Welcome.Mode() ~= "first" then error("first run should use the intro splash") end
        __NS.UI.Welcome.Hide()
        if db.settings.welcomeVersion ~= __NS.VERSION then
            error("welcome version was not recorded")
        end
        __NS.UI.Welcome.MaybeShow()
        if __NS.UI.Welcome.IsShown() then error("welcome repeated for the same version") end

        db.settings.welcomeVersion = "0.0.1"
        __NS.UI.Welcome.MaybeShow()
        if not __NS.UI.Welcome.IsShown() then error("welcome did not show after a version change") end
        if __NS.UI.Welcome.Mode() ~= "update" then error("version change should use the update splash") end
        __NS.UI.Welcome.Hide()

        db.settings.welcomeVersion = nil
        db.settings.showWelcome = false
        __NS.UI.Welcome.MaybeShow()
        if __NS.UI.Welcome.IsShown() then error("welcome ignored the update toggle") end
        db.settings.showWelcome = true
        __NS.UI.Welcome.Show()
        __NS.UI.Welcome.Hide()
    end)

    attempt("guided tour walks every step", function()
        __NS.UI.Open()
        __NS.UI.Tour.Start(1)
        if not __NS.UI.Tour.IsActive() then error("tour did not start") end
        if __NS.UI.Tour.Steps < 5 then error("tour is too short to explain the loop") end
        __NS.UI.Tour.Next()
        __NS.UI.Tour.Back()
        if __NS.UI.Tour.Index() ~= 1 then error("back did not return to the first step") end
        for _ = 2, __NS.UI.Tour.Steps do __NS.UI.Tour.Next() end
        if not __NS.UI.Tour.IsActive() then error("tour ended before its last step") end
        __NS.UI.Tour.Next()
        if __NS.UI.Tour.IsActive() then error("finish did not close the tour") end
        local db = __NS.DB.Get()
        if not db.settings.tourDone then error("tour completion was not recorded") end
        if db.settings.tourVersion ~= __NS.VERSION then error("tour version was not recorded") end
    end)

    attempt("next-up goals advance", function()
        local scratch = __NS.DB.Scratch()
        scratch.settings.tourDone = true
        scratch.stats.itemsCollected = 1
        local step = __NS.Goals.Current(scratch)
        if not step or step.key ~= "customer" then
            error("first goal after the tour should be the customer, got " .. tostring(step and step.key))
        end
        scratch.stats.sales = 1
        scratch.stats.customersServed = 1
        scratch.stats.wholesaleBought = 1
        step = __NS.Goals.Current(scratch)
        if not step or step.key ~= "upgrade" then
            error("a sale did not advance the goals, got " .. tostring(step and step.key))
        end
        local done, total = __NS.Goals.Progress(scratch)
        if done < 2 or total < 5 then error("goal progress is wrong: " .. done .. "/" .. total) end
        local api = __NS.UI.Tabs.dashboard and __NS.UI.Tabs.dashboard.api
        if not api or not api.goalCard then error("dashboard goal card was not built") end
    end)

    attempt("options panel and compartment registration", function()
        if not __NS.UI.RegisteredOptions then error("Settings category not registered") end
        if not SETTINGS_CATEGORY then error("category missing from Settings") end
        if type(GoblinPawnStars_CompartmentClick) ~= "function" then
            error("Addon Compartment click handler missing")
        end
        if type(GoblinPawnStars_CompartmentEnter) ~= "function" then
            error("Addon Compartment enter handler missing")
        end
        GoblinPawnStars_CompartmentClick("GoblinPawnStars", { buttonName = "LeftButton" })
        GoblinPawnStars_CompartmentEnter("GoblinPawnStars", UIParent)
        GoblinPawnStars_CompartmentLeave()
        local handler = SlashCmdList["GOBLINPAWNSTARS"]
        handler("options")
        if SETTINGS_OPENED ~= 77 then error("options command did not open the category") end
        __NS.UI.Close()
    end)

    attempt("scheduled customer arrives when a blocker clears", function()
        local ns = __NS
        local db, old = ns.DB.Scratch(), ns.db
        local inCombat = ns.Compat.InCombat
        ns.db = db
        local ok, problem = pcall(function()
            db.settings.customerArrival = "Off"
            db.shop.nextArrival = 2
            local function update()
                ns.Clock.frame:GetScript("OnUpdate")(ns.Clock.frame, 1)
            end
            update()
            update()
            assert(db.shop.nextArrival == 0 and ns.Customers.ArrivalBlocker() == "No stock",
                "empty shelves restarted the timer")
            ns.Inventory.Add({ id = 2589, name = "Linen Cloth", category = "cloth", value = 60 })
            ns.Compat.InCombat = function() return true end
            update()
            assert(db.shop.nextArrival == 0 and #ns.Customers.Waiting() == 0
                and ns.Customers.ArrivalBlocker() == "In combat", "combat did not hold the due arrival")
            ns.Compat.InCombat = function() return false end
            update()
            assert(db.shop.nextArrival > 0 and #ns.Customers.Waiting() == 1 and db.stats.customers == 1,
                "restocked shop did not get a customer when combat ended")
            db.shop.nextArrival = 1
            update()
            db.shop.nextArrival = 1
            update()
            assert(db.shop.nextArrival == 0 and ns.Customers.ArrivalBlocker() == "Queue full",
                "full queue restarted the timer")
            ns.Customers.Dismiss(1)
            update()
            assert(db.stats.customers == 3 and #ns.Customers.Waiting() == 2,
                "a due customer did not fill the freed slot")
            db.settings.paused = true
            local remaining = db.shop.nextArrival
            update()
            assert(db.shop.nextArrival == remaining and ns.Customers.ArrivalBlocker() == "Paused",
                "pause did not preserve the countdown")
        end)
        ns.Compat.InCombat = inCombat
        ns.db = old
        assert(ok, problem)
    end)

    attempt("simulated hour of play", function()
        local real = __NS.db
        local fresh = __NS.DB.Scratch()
        __NS.db = fresh
        __NS.Inventory.Add({
            id = 2589, name = "Linen Cloth", quality = 1, ilvl = 5,
            classID = 7, subclassID = 5, category = "cloth", value = 60,
        })
        __NS.Inventory.Add({
            id = 2770, name = "Copper Ore", quality = 1, ilvl = 5,
            classID = 7, subclassID = 7, category = "ore", value = 40,
        })
        __NS.UI.Close()
        for _ = 1, 3600 do
            __NS.Clock.OnTick(1)
        end
        if (fresh.stats.playtime or 0) < 3500 then error("playtime did not advance") end
        if (fresh.stats.shopDays or 0) < 3 then error("shop days did not fire") end
        if (fresh.credits or 0) < 0 then error("credits went negative") end
        if fresh.stats.customers == 0 then error("no customer arrived in an hour of play") end
        if #fresh.shop.waiting > __NS.Shop.WaitingSlots() then error("customer queue overflowed") end
        if type(fresh.shop.nextArrival) ~= "number" or fresh.shop.nextArrival ~= fresh.shop.nextArrival then
            error("next customer timer became invalid")
        end
        __NS.db = real
    end)

    attempt("toast", function() __NS.UI.Toast("hello from the smoke test") end)
    attempt("minimap update", function()
        __NS.DB.Get().settings.minimap = false
        if __NS.UI.UpdateMinimap then __NS.UI.UpdateMinimap() end
        __NS.DB.Get().settings.minimap = true
        if __NS.UI.UpdateMinimap then __NS.UI.UpdateMinimap() end
    end)

    attempt("slash commands", function()
        local handler = SlashCmdList and SlashCmdList["GOBLINPAWNSTARS"]
        if not handler then error("slash command not registered") end
        handler("help")
        handler("version")
        handler("arrivals")
        handler("report")
        handler("profile")
        handler("debug")
        handler("welcome")
        handler("")
        handler("nonsense")
    end)

    __NS.db = real

    for _, message in ipairs(CHAT_MESSAGES) do
        local text = tostring(message)
        if text:find("Tab error", 1, true) or text:find("attempt to index", 1, true) then
            failures[#failures + 1] = "chat error: " .. text
        end
    end

    return table.concat(failures, "\n"), #failures
end
