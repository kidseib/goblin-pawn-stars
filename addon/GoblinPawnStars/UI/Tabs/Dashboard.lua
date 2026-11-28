--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Tabs/Dashboard.lua
    The shop at a glance: tier, credits, reputation, daily demand, market mood
    and the latest arrivals.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

ns.UI.Tabs.dashboard = {
    title = "Dashboard",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
    Create = function(parent)
        local ui = {}

        -------------------------------------------------------------------
        -- Shop sign
        -------------------------------------------------------------------
        local sign = W.Panel(parent, "parchment")
        sign:SetPoint("TOPLEFT", 0, 0)
        sign:SetPoint("TOPRIGHT", 0, 0)
        sign:SetHeight(88)

        local tierIcon = W.Icon(sign, 50, T.tierIcons[1])
        tierIcon:SetPoint("LEFT", 14, 4)

        ui.tierName = W.Text(sign, "Roadside Trading Stall", 19, T.colors.gold)
        ui.tierName:SetPoint("TOPLEFT", 78, -12)
        ui.tierName:SetPoint("TOPRIGHT", -16, -12)

        ui.tierBlurb = W.Text(sign, "", 11, T.colors.muted)
        ui.tierBlurb:SetPoint("TOPLEFT", 78, -36)
        ui.tierBlurb:SetPoint("TOPRIGHT", -16, -36)
        ui.tierBlurb:SetWordWrap(true)

        ui.tierBar = W.Bar(sign, 400, 7, T.colors.gold)
        ui.tierBar:SetPoint("BOTTOMLEFT", 78, 22)

        ui.tierHint = W.Text(sign, "", 9, T.colors.dim)
        ui.tierHint:SetPoint("BOTTOMLEFT", 78, 8)

        local nextButton = W.Button(sign, "Upgrades", 90, 24, function()
            ns.UI.ShowTab("upgrades")
        end, "gold")
        nextButton:SetPoint("BOTTOMRIGHT", -16, 16)

        local deedButton = W.Button(sign, "The Deed", 90, 24, function()
            ns.UI.ShowTab("deed")
        end, "neutral")
        deedButton:SetPoint("BOTTOMRIGHT", -112, 16)

        -------------------------------------------------------------------
        -- Stat tiles
        -------------------------------------------------------------------
        local tiles = {}
        local labels = { "GOBLIN CREDITS", "REPUTATION", "SALES", "BEST SALE" }
        local width = 174
        for index = 1, 4 do
            local tile = W.Panel(parent, "panel")
            tile:SetSize(width, 58)
            tile:SetPoint("TOPLEFT", (index - 1) * (width + 8), -96)

            local caption = W.Text(tile, labels[index], 9, T.colors.muted)
            caption:SetPoint("TOPLEFT", 10, -8)
            local value = W.Number(tile, "0", 19, T.colors.gold)
            value:SetPoint("TOPLEFT", 10, -22)
            local note = W.Text(tile, "", 9, T.colors.dim)
            note:SetPoint("BOTTOMLEFT", 10, 7)

            tiles[index] = { value = value, note = note, frame = tile }
        end
        ui.tiles = tiles

        -- Reputation is a progression system, not a scoreboard: hovering the tile
        -- lists exactly what each milestone unlocks and which one is next.
        if tiles[2].frame and GameTooltip then
            tiles[2].frame:EnableMouse(true)
            tiles[2].frame:SetScript("OnEnter", function(self)
                local reputation = math.floor(ns.DB.Get().reputation or 0)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Reputation", 0.94, 0.78, 0.33)
                local reached = ns.Shop.ReputationTier()
                GameTooltip:AddLine(string.format("%s · %d / 1000",
                    reached and reached.name or "Nobody", reputation), 0.91, 0.85, 0.69)
                for _, def in ipairs(ns.Data.ReputationTiers) do
                    local unlocked = reputation >= (def.at or 0)
                    GameTooltip:AddLine(string.format("%s  %s %d — %s",
                        unlocked and "|cff5fd64fUnlocked|r" or "|cff888888Locked|r",
                        def.name, def.at, def.perkText or ""), 0.85, 0.82, 0.7, true)
                end
                GameTooltip:AddLine("Every completed sale earns reputation.", 0.62, 0.58, 0.47)
                GameTooltip:Show()
            end)
            tiles[2].frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        -------------------------------------------------------------------
        -- Today / latest
        -------------------------------------------------------------------
        local today = W.Panel(parent, "panel")
        today:SetSize(360, 176)
        today:SetPoint("TOPLEFT", 0, -162)

        local todayTitle = W.Text(today, "TODAY AT THE SHOP", 10, T.colors.goldDim)
        todayTitle:SetPoint("TOPLEFT", 12, -10)

        ui.requestLabel = W.Text(today, "", 12, T.colors.parchment)
        ui.requestLabel:SetPoint("TOPLEFT", 12, -28)
        ui.requestLabel:SetPoint("TOPRIGHT", -12, -28)

        local dayCaption = W.Text(today, "SHOP DAY (RENT & WAGES)", 9, T.colors.muted)
        dayCaption:SetPoint("TOPLEFT", 12, -56)
        ui.dayBar = W.Bar(today, 336, 7, T.colors.goldDim)
        ui.dayBar:SetPoint("TOPLEFT", 12, -70)
        ui.dayText = W.Text(today, "", 9, T.colors.dim)
        ui.dayText:SetPoint("TOPLEFT", 12, -80)

        local marketCaption = W.Text(today, "MARKET MOOD", 9, T.colors.muted)
        marketCaption:SetPoint("TOPLEFT", 12, -100)
        ui.marketText = W.Text(today, "", 11, T.colors.text)
        ui.marketText:SetPoint("TOPLEFT", 12, -113)
        ui.marketText:SetPoint("TOPRIGHT", -12, -113)
        ui.marketText:SetWordWrap(true)

        local latest = W.Panel(parent, "panel")
        latest:SetPoint("TOPLEFT", 368, -162)
        latest:SetPoint("TOPRIGHT", 0, -162)
        latest:SetHeight(176)

        local latestTitle = W.Text(latest, "LATEST NEWS", 10, T.colors.goldDim)
        latestTitle:SetPoint("TOPLEFT", 12, -10)

        ui.visitor = W.Text(latest, "", 11, T.colors.parchment)
        ui.visitor:SetPoint("TOPLEFT", 12, -28)
        ui.visitor:SetPoint("TOPRIGHT", -12, -28)
        ui.visitor:SetWordWrap(true)

        ui.stockText = W.Text(latest, "", 10, T.colors.muted)
        ui.stockText:SetPoint("TOPLEFT", 12, -58)
        ui.stockText:SetPoint("TOPRIGHT", -12, -58)

        ui.historyLines = {}
        for index = 1, 3 do
            local line = W.Text(latest, "", 10, T.colors.muted)
            line:SetPoint("TOPLEFT", 12, -78 - (index - 1) * 30)
            line:SetPoint("TOPRIGHT", -12, -78 - (index - 1) * 30)
            line:SetHeight(26)
            line:SetWordWrap(true)
            ui.historyLines[index] = line
        end

        -------------------------------------------------------------------
        -- Quick actions
        -------------------------------------------------------------------
        local counterButton = W.Button(parent, "Open the Counter", 172, 32, function()
            local current = ns.Negotiation.Active()
            if current then
                ns.UI.Negotiation.Show()
            elseif #ns.Customers.Waiting() > 0 then
                ns.UI.StartNegotiation(1)
            else
                ns.UI.Toast("No customer is waiting. They will wander in soon.")
            end
        end, "primary")
        counterButton:SetPoint("TOPLEFT", 0, -348)

        local inventoryButton = W.Button(parent, "Browse Inventory", 142, 32, function()
            ns.UI.ShowTab("inventory")
        end, "neutral")
        inventoryButton:SetPoint("TOPLEFT", 180, -348)

        local marketButton = W.Button(parent, "Market Report", 138, 32, function()
            ns.UI.ShowTab("market")
        end, "neutral")
        marketButton:SetPoint("TOPLEFT", 330, -348)

        local wholesaleButton = W.Button(parent, "Wholesaler", 128, 32, function()
            if ns.UI.Wholesaler then ns.UI.Wholesaler.Show() end
        end, "neutral")
        wholesaleButton:SetPoint("TOPLEFT", 476, -348)

        local testButton = W.Button(parent, "Stock Bags Now", 132, 32, function()
            local added, items, readable = ns.Loot.ImportCurrentBags()
            if not readable then
                ns.UI.Toast("Bags are not readable on this client. Run /gps scan for details.")
            elseif added > 0 then
                ns.UI.Toast(string.format("Imported %d stack%s (%d items) from your bags.",
                    added, added == 1 and "" or "s", items))
            else
                ns.UI.Toast("Nothing new to import. New loot is stocked automatically.")
            end
            ns.UI.Refresh()
        end, "gold")
        testButton:SetPoint("TOPRIGHT", 0, -348)

        -------------------------------------------------------------------
        -- Next up
        -------------------------------------------------------------------
        ui.goalCard = W.Panel(parent, "inset")
        ui.goalCard:SetPoint("TOPLEFT", 0, -392)
        ui.goalCard:SetPoint("TOPRIGHT", 0, -392)
        ui.goalCard:SetHeight(72)

        local goalCaption = W.Text(ui.goalCard, "NEXT UP", 9, T.colors.goldDim)
        goalCaption:SetPoint("TOPLEFT", 12, -9)

        ui.goalLabel = W.Text(ui.goalCard, "", 12, T.colors.gold)
        ui.goalLabel:SetPoint("TOPLEFT", 12, -23)
        ui.goalLabel:SetPoint("TOPRIGHT", -140, -23)

        ui.goalHint = W.Text(ui.goalCard, "", 9, T.colors.muted)
        ui.goalHint:SetPoint("TOPLEFT", 12, -41)
        ui.goalHint:SetPoint("TOPRIGHT", -140, -41)
        ui.goalHint:SetHeight(26)
        ui.goalHint:SetWordWrap(true)

        ui.goalButton = W.Button(ui.goalCard, "Take me there", 112, 26, function()
            local db = ns.DB.Get()
            local step = ns.Goals.Current(db)
            if not step then
                ns.UI.ShowTab("achievements")
                return
            end
            if step.action == "tour" and ns.UI.Tour then
                ns.UI.Tour.Start(1)
            elseif step.action == "deed" then
                ns.UI.ShowTab("deed")
            elseif step.action == "wholesaler" then
                if ns.UI.Wholesaler then ns.UI.Wholesaler.Show() end
            elseif step.action == "import" then
                local added, items, readable = ns.Loot.ImportCurrentBags()
                if not readable then
                    ns.UI.Toast("Bags are not readable on this client. Run /gps scan for details.")
                elseif added > 0 then
                    ns.UI.Toast(string.format("Imported %d stack%s (%d items) from your bags.",
                        added, added == 1 and "" or "s", items))
                else
                    ns.UI.Toast("Nothing eligible in your bags yet. Loot something first.")
                end
                ns.UI.Refresh()
            else
                ns.UI.ShowTab(step.tab or "dashboard")
            end
        end, "gold")
        ui.goalButton:SetPoint("RIGHT", -12, 0)

        -------------------------------------------------------------------
        -- Refresh
        -------------------------------------------------------------------
        function ui.Refresh()
            local db = ns.DB.Get()
            local tier = ns.Shop.TierInfo()
            local nextTier = ns.Shop.NextTier()

            ui.tierName:SetText(tier.name)
            ui.tierBlurb:SetText(tier.blurb or "")
            tierIcon:SetIcon(T.tierIcons[db.tier] or T.tierIcons[1])

            if nextTier then
                local progress = U.clamp(db.credits / math.max(1, nextTier.cost), 0, 1)
                ui.tierBar:SetValue(progress, 1)
                ui.tierHint:SetText(string.format("Next: %s — %s / %s gc (%d%%)",
                    nextTier.name, U.comma(db.credits), U.comma(nextTier.cost),
                    math.floor(progress * 100)))
            else
                ui.tierBar:SetValue(1, 1)
                ui.tierHint:SetText("You own the biggest shop on the continent.")
            end

            local creditsPerMin, customersPerMin = 0, 0
            if ns.Throughput then creditsPerMin, customersPerMin = ns.Throughput.Rates() end

            ui.tiles[1].value:SetText(U.comma(db.credits))
            ui.tiles[1].note:SetText(string.format("%s gc/min · %s lifetime",
                U.comma(math.floor(creditsPerMin + 0.5)), U.comma(db.stats.earned or 0)))

            local repLabel = ns.Shop.ReputationLabel()
            local perks = ns.Shop.ReputationPerks()
            ui.tiles[2].value:SetText(string.format("%d", math.floor(db.reputation)))
            ui.tiles[2].note:SetText(string.format("%s · %d/%d perks", repLabel,
                perks.count or 0, #ns.Data.ReputationTiers))

            ui.tiles[3].value:SetText(U.comma(db.stats.sales or 0))
            ui.tiles[3].note:SetText(string.format("%d served · %.1f customers/min",
                db.stats.customersServed or 0, customersPerMin))

            ui.tiles[4].value:SetText(U.comma(db.stats.bestSale or 0))
            ui.tiles[4].note:SetText(string.format("best x%.2f value", db.stats.bestMultiple or 1))

            local request = ns.Shop.DailyRequest()
            if request then
                ui.requestLabel:SetText(string.format(
                    "Today's customers want |cffffd700%s|r — +%d%% on the first matching sale.",
                    request.label, math.floor((request.bonus or 0) * 100)))
                if request.fulfilled then
                    ui.requestLabel:SetText("|cff5fd64fDaily request complete.|r " ..
                        "Tomorrow brings a new obsession.")
                end
            end

            ui.dayBar:SetValue(ns.Shop.ShopDayProgress(), 1)
            ui.dayText:SetText(string.format("Next expenses: %s gc (rent %s + wages %s)",
                U.comma(ns.Shop.DailyExpenses()),
                U.comma(18 + tier.tier * 32),
                U.comma(ns.Staff.TotalWages())))

            local events = ns.Market.Active()
            if #events > 0 then
                local parts = {}
                for _, event in ipairs(events) do
                    parts[#parts + 1] = string.format("%s (%s)", event.name, U.clock(event.remaining))
                end
                ui.marketText:SetText(table.concat(parts, " · "))
                ui.marketText:SetTextColor(T.colors.green[1], T.colors.green[2], T.colors.green[3])
            else
                ui.marketText:SetText("Quiet. Prices are drifting on their own.")
                ui.marketText:SetTextColor(T.colors.muted[1], T.colors.muted[2], T.colors.muted[3])
            end

            local visitor = db.shop.lastVisitor
            if visitor then
                ui.visitor:SetText(string.format("|cff9c8a5aLast visitor:|r %s %s.", visitor.name, visitor.text or ""))
            else
                ui.visitor:SetText("|cff9c8a5aNo one has visited yet.|r Open the shop and wait.")
            end

            local stock = db.shop.lastStock
            if stock and stock.names and #stock.names > 0 then
                ui.stockText:SetText(string.format("New stock: %s%s", table.concat(stock.names, ", "),
                    stock.count > #stock.names and (" +" .. (stock.count - #stock.names) .. " more") or ""))
            else
                ui.stockText:SetText("Loot something, or buy a bulk lot from the Wholesaler.")
            end

            local history = ns.History.List(nil, 3)
            for index, line in ipairs(ui.historyLines) do
                local entry = history[index]
                if entry then
                    local amount = entry.amount and entry.amount ~= 0
                        and (" |cffffd700" .. (entry.amount > 0 and "+" or "") .. U.comma(entry.amount) .. "|r") or ""
                    line:SetText("· " .. (entry.text or "") .. amount)
                else
                    line:SetText("")
                end
            end

            local goal = ns.Goals.Current(db)
            local done, total = ns.Goals.Progress(db)
            if goal then
                goalCaption:SetText(string.format("NEXT UP · %d OF %d", done + 1, total))
                ui.goalLabel:SetText(goal.label)
                ui.goalHint:SetText(goal.hint)
                ui.goalButton:SetLabel(goal.action == "tour" and "Start tour" or "Take me there")
            else
                goalCaption:SetText("NEXT UP · STARTER GOALS COMPLETE")
                ui.goalLabel:SetText("You run this town.")
                ui.goalHint:SetText("Chase the next tier, achievements and rare collectors. The Deed tab holds the cartel campaign and its endings.")
                ui.goalButton:SetLabel("Achievements")
            end
            if ui.lastGoalDone and done > ui.lastGoalDone then
                if ns.Anim then ns.Anim.Pulse(ui.goalCard) end
                if ns.UI.Toast then ns.UI.Toast("Next step complete. The goblin council approves.") end
            end
            ui.lastGoalDone = done
        end

        function ui.RefreshHeaderOnly() end

        return ui
    end,
}
