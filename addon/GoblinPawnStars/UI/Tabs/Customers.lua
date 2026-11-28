--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Tabs/Customers.lua
    Who is in the shop, what they want, and how close you are to a deal.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

ns.UI.Tabs.customers = {
    title = "Customers",
    icon = "Interface\\Icons\\INV_Misc_Head_Human_01",
    Create = function(parent)
        local ui = { rows = {} }

        -------------------------------------------------------------------
        -- Current negotiation
        -------------------------------------------------------------------
        local current = W.Panel(parent, "parchment")
        current:SetPoint("TOPLEFT", 0, 0)
        current:SetSize(380, 118)

        local caption = W.Text(current, "AT THE COUNTER", 9, T.colors.muted)
        caption:SetPoint("TOPLEFT", 12, -10)

        ui.currentPortrait = W.Portrait(current, 54, "WARRIOR")
        ui.currentPortrait:SetPoint("TOPLEFT", 12, -24)
        ui.currentPortrait:Hide()

        ui.currentName = W.Text(current, "Nobody is at the counter.", 14, T.colors.gold)
        ui.currentName:SetPoint("TOPLEFT", 76, -24)
        ui.currentName:SetPoint("TOPRIGHT", -12, -24)

        ui.currentMeta = W.Text(current, "Customers arrive on their own. Stock the shelves and wait.", 10, T.colors.muted)
        ui.currentMeta:SetPoint("TOPLEFT", 76, -44)
        ui.currentMeta:SetPoint("TOPRIGHT", -12, -44)
        ui.currentMeta:SetWordWrap(true)

        ui.currentBar = W.Bar(current, 288, 7, T.colors.green)
        ui.currentBar:SetPoint("TOPLEFT", 76, -66)

        ui.currentButton = W.Button(current, "Resume Negotiation", 150, 28, function()
            if ns.Negotiation.Active() then
                ns.UI.Negotiation.Show()
            elseif #ns.Customers.Waiting() > 0 then
                ns.UI.StartNegotiation(1)
            else
                ns.UI.Toast("Nobody is at the counter.")
            end
        end, "primary")
        ui.currentButton:SetPoint("BOTTOMRIGHT", -12, 10)

        -------------------------------------------------------------------
        -- Waiting queue
        -------------------------------------------------------------------
        local queue = W.Panel(parent, "panel")
        queue:SetPoint("TOPLEFT", 0, -126)
        queue:SetSize(380, 292)

        local queueTitle = W.Text(queue, "WAITING IN THE SHOP", 9, T.colors.goldDim)
        queueTitle:SetPoint("TOPLEFT", 12, -10)
        ui.queueSlots = W.Text(queue, "", 9, T.colors.muted)
        ui.queueSlots:SetPoint("TOPRIGHT", -12, -10)

        for index = 1, 4 do
            local row = W.Create(queue, "Frame")
            row:SetPoint("TOPLEFT", 8, -26 - (index - 1) * 64)
            row:SetPoint("TOPRIGHT", -8, -26 - (index - 1) * 64)
            row:SetHeight(58)
            row:Hide()

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            T.Fill(bg, 0.09, 0.075, 0.045, 0.7)

            local portrait = W.Portrait(row, 40, "WARRIOR")
            portrait:SetPoint("LEFT", 6, 0)

            local name = W.Text(row, "", 12, T.colors.parchment)
            name:SetPoint("TOPLEFT", 54, -8)
            name:SetPoint("TOPRIGHT", -70, -8)

            local meta = W.Text(row, "", 9, T.colors.muted)
            meta:SetPoint("TOPLEFT", 54, -25)
            meta:SetPoint("TOPRIGHT", -70, -25)

            local patience = W.Bar(row, 120, 5, T.colors.green)
            patience:SetPoint("BOTTOMLEFT", 54, 10)

            local talk = W.Button(row, "Talk", 58, 24, function()
                if not row.customerIndex then return end
                ns.UI.StartNegotiation(row.customerIndex)
            end, "primary")
            talk:SetPoint("RIGHT", -30, 10)

            local dismiss = W.Button(row, "×", 22, 24, function()
                if not row.customerIndex then return end
                ns.Customers.Dismiss(row.customerIndex)
                ns.UI.Refresh()
            end, "danger")
            dismiss:SetPoint("RIGHT", -4, 10)

            row.portrait = portrait
            row.name = name
            row.meta = meta
            row.patience = patience
            row.talk = talk
            ui.rows[index] = row
        end

        ui.emptyQueue = W.Text(queue, "No customers waiting. One will wander in soon.", 11, T.colors.dim)
        ui.emptyQueue:SetPoint("TOPLEFT", 12, -40)

        -------------------------------------------------------------------
        -- Right column
        -------------------------------------------------------------------
        local request = W.Panel(parent, "panel")
        request:SetPoint("TOPLEFT", 388, 0)
        request:SetPoint("TOPRIGHT", 0, 0)
        request:SetHeight(96)

        local requestTitle = W.Text(request, "WANTED TODAY", 9, T.colors.goldDim)
        requestTitle:SetPoint("TOPLEFT", 12, -10)
        ui.requestText = W.Text(request, "", 11, T.colors.parchment)
        ui.requestText:SetPoint("TOPLEFT", 12, -26)
        ui.requestText:SetPoint("TOPRIGHT", -12, -26)
        -- Bounded box: a wrapped line at a large font clips inside the card
        -- instead of spilling over the bar (the bar is anchored to the bottom
        -- edge, so it cannot be pushed out either).
        ui.requestText:SetPoint("BOTTOMRIGHT", -12, 22)
        ui.requestText:SetWordWrap(true)
        ui.requestBar = W.Bar(request, 300, 6, T.colors.gold)
        -- Same place as the old -76 offset on the 96px card, but expressed from
        -- the bottom so it stays put when the card content grows.
        ui.requestBar:SetPoint("BOTTOMLEFT", 12, 14)

        local event = W.Panel(parent, "panel")
        event:SetPoint("TOPLEFT", 388, -104)
        event:SetPoint("TOPRIGHT", 0, -104)
        event:SetHeight(120)

        local eventTitle = W.Text(event, "HAPPENING NOW", 9, T.colors.goldDim)
        eventTitle:SetPoint("TOPLEFT", 12, -10)
        ui.eventText = W.Text(event, "Nothing unusual. Enjoy it while it lasts.", 11, T.colors.parchment)
        ui.eventText:SetPoint("TOPLEFT", 12, -26)
        ui.eventText:SetPoint("TOPRIGHT", -12, -26)
        ui.eventText:SetWordWrap(true)
        ui.eventButton = W.Button(event, "Deal With It", 120, 26, function()
            if ns.Encounters.Pending() then
                ns.UI.EventFrame.Show()
            elseif ns.Encounters.PendingResult() then
                ns.UI.EventFrame.Show()
            else
                ns.UI.Toast("Nothing is happening right now.")
            end
        end, "gold")
        ui.eventButton:SetPoint("BOTTOMRIGHT", -12, 10)

        local visitor = W.Panel(parent, "panel")
        visitor:SetPoint("TOPLEFT", 388, -232)
        visitor:SetPoint("TOPRIGHT", 0, -232)
        visitor:SetHeight(186)

        local visitorTitle = W.Text(visitor, "LAST VISITOR", 9, T.colors.goldDim)
        visitorTitle:SetPoint("TOPLEFT", 12, -10)
        ui.visitorText = W.Text(visitor, "No visitors yet.", 11, T.colors.parchment)
        ui.visitorText:SetPoint("TOPLEFT", 12, -28)
        ui.visitorText:SetPoint("TOPRIGHT", -12, -28)
        ui.visitorText:SetHeight(120)
        ui.visitorText:SetWordWrap(true)
        ui.visitorText:SetJustifyH("LEFT")

        local hint = W.Text(visitor, "|cff9c8a5aTip: patience runs out.|r", 9, T.colors.dim)
        hint:SetPoint("BOTTOMLEFT", 12, 10)

        -------------------------------------------------------------------
        function ui.Refresh()
            local db = ns.DB.Get()
            local currentCustomer = ns.Negotiation.Active()

            if currentCustomer then
                local item = ns.Negotiation.Item()
                local personality = ns.Customers.Personality(currentCustomer)
                ui.currentPortrait:Show()
                ui.currentPortrait:SetCustomer(currentCustomer)
                ui.currentName:SetText(currentCustomer.name)
                if currentCustomer.order then
                    -- A regular collecting a special order leads with what they
                    -- came back for; the item and price follow.
                    ui.currentMeta:SetText(string.format(
                        "|cffffd700Special order: %s|r · wants %s · offering %s",
                        ns.Data.CategoryName(currentCustomer.orderCategory),
                        item and item.name or "something sold",
                        U.comma(currentCustomer.offer or 0) .. " gc"))
                else
                    ui.currentMeta:SetText(string.format("%s%s%s · wants %s · offering %s",
                        currentCustomer.regular and "|cffffd700Named regular|r · " or "",
                        currentCustomer.returning and string.format("|cff7fd0ffReturning visitor (%d)|r · ",
                            currentCustomer.returning) or "",
                        personality and personality.name or "Customer",
                        item and item.name or "something sold",
                        U.comma(currentCustomer.offer or 0) .. " gc"))
                end
                ui.currentBar:SetValue(ns.Customers.PatienceRatio(currentCustomer), 1)
                ui.currentButton:SetLabel("Resume Negotiation")
                ui.currentButton:SetState(true)
            else
                ui.currentPortrait:Hide()
                ui.currentName:SetText("Nobody is at the counter.")
                ui.currentMeta:SetText("Customers arrive on their own. Stock the shelves and wait.")
                ui.currentBar:SetValue(0, 1)
                ui.currentButton:SetLabel("Open Negotiation")
                ui.currentButton:SetState(#db.shop.waiting > 0)
            end

            local waiting = db.shop.waiting
            ui.queueSlots:SetText(string.format("%d / %d slots", #waiting, ns.Shop.WaitingSlots()))
            ui.emptyQueue:SetShown(#waiting == 0)

            for index, row in ipairs(ui.rows) do
                local customer = waiting[index]
                if customer then
                    local item = db.inventory[customer.itemUid]
                    local personality = ns.Customers.Personality(customer)
                    row.customerIndex = index
                    row.portrait:SetCustomer(customer)
                    row.name:SetText(customer.name)
                    if customer.order then
                        row.meta:SetText(string.format("|cffffd700Order: %s|r · %s · %s",
                            ns.Data.CategoryName(customer.orderCategory),
                            personality and personality.name or "Customer",
                            item and item.name or "item gone"))
                    elseif customer.orderCategory then
                        row.meta:SetText(string.format("|cffffd700Wants %s|r · %s · %s",
                            ns.Data.CategoryName(customer.orderCategory),
                            personality and personality.name or "Customer",
                            item and item.name or "item gone"))
                    else
                        row.meta:SetText(string.format("%s%s%s · %s",
                            customer.regular and "|cffffd700Named regular|r · " or "",
                            customer.returning and string.format("|cff7fd0ffReturning (%d)|r · ",
                                customer.returning) or "",
                            personality and personality.name or "Customer",
                            item and item.name or "item gone"))
                    end
                    row.patience:SetValue(ns.Customers.PatienceRatio(customer), 1)
                    row.talk:SetState(item ~= nil)
                    row:Show()
                else
                    row.customerIndex = nil
                    row:Hide()
                end
            end

            local requestDef = ns.Shop.DailyRequest()
            local order = ns.Regulars.Next()
            local wanted = {}
            if requestDef then
                if requestDef.fulfilled then
                    wanted[#wanted + 1] = "|cff5fd64fBuyer satisfied today.|r"
                else
                    wanted[#wanted + 1] = string.format("Buyers want %s · +%d%% first sale.",
                        requestDef.label, math.floor((requestDef.bonus or 0) * 100))
                end
            end
            if order then
                local days = ns.Regulars.DaysLeft(order)
                local others = #ns.Regulars.Orders() - 1
                wanted[#wanted + 1] = string.format("|cffffd700%s|r %s: %s · %s · %s gc%s",
                    order.patron and "Patron order" or "Order",
                    -- Names are generated and can run long; a 40 character name
                    -- would wrap the card on its own at a large font.
                    W.Shorten(order.name, 16), order.label,
                    days <= 1 and "|cffff5555last day|r" or (days .. " days"),
                    U.comma(order.budget),
                    others > 0 and string.format(" |cff9c8a5a(+%d)|r", others) or "")
            end
            -- Fit the card rather than letting it grow: measure the joined text
            -- and keep the order line first if both do not fit. GetStringHeight
            -- is the truth on a real client; the fallback assumes a line per
            -- entry, which is what the mock and old clients can know.
            local function measure(text)
                local shown
                pcall(function() ui.requestText:SetText(text) end)
                if type(ui.requestText.GetStringHeight) == "function" then
                    local ok, height = pcall(ui.requestText.GetStringHeight, ui.requestText)
                    if ok and tonumber(height) and tonumber(height) > 0 then shown = tonumber(height) end
                end
                if not shown then
                    local lines = 1
                    for _ in tostring(text):gmatch("\n") do lines = lines + 1 end
                    shown = lines * 15
                end
                return shown
            end
            local kept = W.FitLines(wanted, 46, measure)
            ui.requestText:SetText(table.concat(kept, "\n"))
            if order then
                -- The bar fills as the deadline approaches, so urgency is a shape
                -- as well as a number.
                local span = math.max(1, (tonumber(order.dueDay) or 0) - (tonumber(order.placedDay) or 0))
                ui.requestBar:SetValue(1 - ns.Regulars.DaysLeft(order) / span, 1)
            else
                ui.requestBar:SetValue(requestDef and requestDef.fulfilled and 1 or 0, 1)
            end

            local pending = ns.Encounters.Pending()
            if pending then
                ui.eventText:SetText("|cffffd700" .. (pending.title or "Something") .. "|r — " ..
                    (pending.text or ""))
                ui.eventButton:SetState(true)
            else
                local result = ns.Encounters.PendingResult()
                if result then
                    ui.eventText:SetText(result.text or "")
                    ui.eventButton:SetState(true)
                else
                    ui.eventText:SetText("Nothing unusual. Enjoy it while it lasts.")
                    ui.eventButton:SetState(false)
                end
            end

            local visitor = db.shop.lastVisitor
            if visitor then
                ui.visitorText:SetText(string.format("|cffffd700%s|r\n%s\n\n|cff9c8a5a%s|r",
                    visitor.name or "Someone", visitor.text or "", visitor.result or ""))
            else
                ui.visitorText:SetText("No visitors yet. Your legend starts with the first one.")
            end
        end

        return ui
    end,
}
