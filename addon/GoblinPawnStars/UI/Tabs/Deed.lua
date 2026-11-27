--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Tabs/Deed.lua
    The campaign tab: the cartel ledger, museum set, Marta Copperpin, the ending
    choice, endless mode and the franchise reset.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

ns.UI.Tabs.deed = {
    title = "The Deed",
    icon = "Interface\\Icons\\INV_Scroll_03",
    Create = function(parent)
        local ui = {}

        -------------------------------------------------------------------
        -- Campaign
        -------------------------------------------------------------------
        local campaign = W.Panel(parent, "parchment")
        campaign:SetPoint("TOPLEFT", 0, 0)
        campaign:SetPoint("TOPRIGHT", 0, 0)
        campaign:SetHeight(148)

        local seal = W.Icon(campaign, 42, "Interface\\Icons\\INV_Scroll_03")
        seal:SetPoint("TOPLEFT", 12, -12)

        local heading = W.Text(campaign, "THE DEED", 10, T.colors.goldDim)
        heading:SetPoint("TOPLEFT", 66, -12)

        ui.campaignTitle = W.Text(campaign, "The Bilgewater Ledger", 18, T.colors.gold)
        ui.campaignTitle:SetPoint("TOPLEFT", 66, -25)
        ui.campaignTitle:SetPoint("TOPRIGHT", -190, -25)

        ui.campaignStory = W.Text(campaign, "", 10, T.colors.parchment)
        ui.campaignStory:SetPoint("TOPLEFT", 66, -50)
        ui.campaignStory:SetPoint("TOPRIGHT", -190, -50)
        ui.campaignStory:SetHeight(52)
        ui.campaignStory:SetWordWrap(true)
        ui.campaignStory:SetSpacing(2)

        ui.debtBar = W.Bar(campaign, 330, 8, T.colors.gold)
        ui.debtBar:SetPoint("BOTTOMLEFT", 66, 30)

        ui.debtText = W.Text(campaign, "", 9, T.colors.dim)
        ui.debtText:SetPoint("BOTTOMLEFT", 66, 14)

        ui.payButton = W.Button(campaign, "Pay", 150, 34, function()
            local ok, payment = ns.Campaign.Pay()
            if not ok then
                if ns.UI and ns.UI.Toast then ns.UI.Toast(payment or "The payment failed.") end
                return
            end
            if ns.UI and ns.UI.Toast then
                ns.UI.Toast(payment.title .. " paid.")
            end
            if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        end, "gold")
        ui.payButton:SetPoint("RIGHT", -12, 0)

        ui.endlessButton = W.Button(campaign, "Keep the Shop Open", 160, 30, function()
            local ok, err = ns.Campaign.Endless()
            if not ok then
                if ns.UI and ns.UI.Toast then ns.UI.Toast(err or "Endless mode is unavailable.") end
                return
            end
            if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        end, "primary")
        ui.endlessButton:SetPoint("TOPRIGHT", -12, -14)

        ui.franchiseButton = W.Button(campaign, "Open a Franchise", 160, 30, function()
            local now = U.now()
            if not ui.franchiseArmedUntil or now > ui.franchiseArmedUntil then
                ui.franchiseArmedUntil = now + 10
                ui.Refresh()
                ui.franchiseButton:SetLabel("Click again to confirm")
                ns.Compat.After(10, function()
                    if ui.franchiseArmedUntil and U.now() > ui.franchiseArmedUntil then
                        ui.franchiseArmedUntil = nil
                        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
                    end
                end)
                return
            end
            ui.franchiseArmedUntil = nil
            local ok, level = ns.Campaign.Franchise()
            if not ok then
                if ns.UI and ns.UI.Toast then ns.UI.Toast(level or "The franchise could not be opened.") end
                return
            end
            if ns.UI and ns.UI.Toast then
                ns.UI.Toast("Franchise " .. tostring(level) .. " opened. A new deed begins.")
            end
            if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        end, "neutral")
        ui.franchiseButton:SetPoint("TOPRIGHT", -12, -50)

        ui.endingNote = W.Text(campaign, "", 9, T.colors.muted)
        ui.endingNote:SetPoint("TOPRIGHT", -12, -88)
        ui.endingNote:SetWidth(166)
        ui.endingNote:SetJustifyH("RIGHT")
        ui.endingNote:SetHeight(42)
        ui.endingNote:SetWordWrap(true)

        -------------------------------------------------------------------
        -- Museum
        -------------------------------------------------------------------
        local museum = W.Panel(parent, "panel")
        museum:SetPoint("TOPLEFT", 0, -156)
        museum:SetSize(360, 280)

        local museumTitle = W.Text(museum, "THE CURIOUS COLLECTION", 10, T.colors.goldDim)
        museumTitle:SetPoint("TOPLEFT", 12, -10)
        ui.museumSub = W.Text(museum, "", 9, T.colors.muted)
        ui.museumSub:SetPoint("TOPLEFT", 12, -24)
        ui.museumSub:SetPoint("TOPRIGHT", -12, -24)

        ui.museumRows = {}
        ui.museumButtons = {}
        for index, slot in ipairs(ns.Data.Museum.slots) do
            local row = W.Create(museum, "Frame")
            row:SetPoint("TOPLEFT", 10, -48 - (index - 1) * 44)
            row:SetPoint("TOPRIGHT", -10, -48 - (index - 1) * 44)
            row:SetHeight(40)

            local icon = W.Icon(row, 24, slot.icon)
            icon:SetPoint("LEFT", 0, 0)

            local label = W.Text(row, slot.label, 10, T.colors.parchment)
            label:SetPoint("TOPLEFT", 32, -1)
            label:SetPoint("TOPRIGHT", -96, -1)
            label:SetHeight(16)

            local status = W.Text(row, slot.hint, 9, T.colors.dim)
            status:SetPoint("TOPLEFT", 32, -16)
            status:SetPoint("TOPRIGHT", -96, -16)
            status:SetHeight(18)
            status:SetWordWrap(true)

            local button = W.Button(row, "Donate", 86, 22, function()
                local ok, record, completed = ns.Museum.Donate(slot.key)
                if not ok then
                    if ns.UI and ns.UI.Toast then ns.UI.Toast(record or "That donation failed.") end
                    return
                end
                if ns.UI and ns.UI.Toast and not completed then
                    ns.UI.Toast("Donated " .. tostring(record.name) .. ".")
                end
                if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
            end, "gold")
            button:SetPoint("RIGHT", 0, 0)

            ui.museumRows[index] = { label = label, status = status }
            ui.museumButtons[index] = button
        end

        -------------------------------------------------------------------
        -- Regular
        -------------------------------------------------------------------
        local regular = W.Panel(parent, "panel")
        regular:SetPoint("TOPLEFT", 368, -156)
        regular:SetPoint("TOPRIGHT", 0, -156)
        regular:SetHeight(280)

        local regularTitle = W.Text(regular, "A NAMED REGULAR", 10, T.colors.goldDim)
        regularTitle:SetPoint("TOPLEFT", 12, -10)

        local portrait = W.Portrait(regular, 46, "WARRIOR")
        portrait:SetPoint("TOPLEFT", 12, -30)
        portrait:SetCustomer({ regular = true, class = "WARRIOR" })

        ui.regularName = W.Text(regular, "Marta Copperpin", 16, T.colors.gold)
        ui.regularName:SetPoint("TOPLEFT", 70, -30)
        ui.regularName:SetPoint("TOPRIGHT", -12, -30)

        ui.regularRole = W.Text(regular, "Retired Prospector", 9, T.colors.muted)
        ui.regularRole:SetPoint("TOPLEFT", 70, -48)

        ui.regularStory = W.Text(regular, "", 10, T.colors.parchment)
        ui.regularStory:SetPoint("TOPLEFT", 12, -84)
        ui.regularStory:SetPoint("TOPRIGHT", -12, -84)
        ui.regularStory:SetHeight(72)
        ui.regularStory:SetWordWrap(true)
        ui.regularStory:SetSpacing(2)

        ui.regularCaption = W.Text(regular, "", 9, T.colors.muted)
        ui.regularCaption:SetPoint("TOPLEFT", 12, -164)

        ui.regularBar = W.Bar(regular, 300, 7, T.colors.green)
        ui.regularBar:SetPoint("TOPLEFT", 12, -178)

        ui.regularNext = W.Text(regular, "", 9, T.colors.dim)
        ui.regularNext:SetPoint("TOPLEFT", 12, -190)
        ui.regularNext:SetPoint("TOPRIGHT", -12, -190)
        ui.regularNext:SetHeight(30)
        ui.regularNext:SetWordWrap(true)

        ui.callButton = W.Button(regular, "Invite Marta", 132, 28, function()
            local ok, err = ns.Regular.Call()
            if not ok then
                if ns.UI and ns.UI.Toast then ns.UI.Toast(err or "Marta cannot visit right now.") end
                return
            end
            if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        end, "primary")
        ui.callButton:SetPoint("BOTTOMLEFT", 12, 14)

        -------------------------------------------------------------------
        -- Footer
        -------------------------------------------------------------------
        local footer = W.Panel(parent, "inset")
        footer:SetPoint("TOPLEFT", 0, -444)
        footer:SetPoint("TOPRIGHT", 0, -444)
        footer:SetHeight(64)

        ui.journal = W.Text(footer, "", 9, T.colors.muted)
        ui.journal:SetPoint("TOPLEFT", 12, -10)
        ui.journal:SetPoint("TOPRIGHT", -190, -10)
        ui.journal:SetHeight(30)
        ui.journal:SetWordWrap(true)

        ui.prestige = W.Text(footer, "", 9, T.colors.dim)
        ui.prestige:SetPoint("BOTTOMLEFT", 12, 9)
        ui.prestige:SetPoint("BOTTOMRIGHT", -190, 9)

        local checkpoint = W.Button(footer, "Checkpoint Now", 138, 24, function()
            local ok, status = ns.Journal.SaveNow(true)
            if ok then
                if ns.UI and ns.UI.Toast then
                    ns.UI.Toast(string.format("Journal saved: %d chunks.", status.chunks or 0))
                end
            else
                if ns.UI and ns.UI.Toast then
                    ns.UI.Toast(ns.Journal.StatusText())
                end
            end
            if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        end, "neutral")
        checkpoint:SetPoint("RIGHT", -12, 0)

        -------------------------------------------------------------------
        -- Refresh
        -------------------------------------------------------------------
        function ui.Refresh()
            local db = ns.DB.Get()
            local state = ns.Campaign.State()
            local payments = ns.Campaign.PaymentCount()
            local total = ns.Campaign.Total()
            local paid = ns.Campaign.Paid()

            ui.debtBar:SetValue(paid, total)
            if state.completed then
                ui.campaignTitle:SetText("The Bilgewater Ledger · Paid")
                ui.debtText:SetText(string.format("Paid in full: %s / %s gc · Franchise level %d",
                    U.comma(paid), U.comma(total), db.prestige.level or 0))
                ui.debtText:SetTextColor(T.colors.green[1], T.colors.green[2], T.colors.green[3])
                ui.payButton:Hide()
                ui.endlessButton:Show()
                ui.franchiseButton:Show()
                if state.mode == "endless" then
                    ui.endlessButton:SetState(false)
                    ui.endlessButton:SetLabel("Endless Mode")
                    ui.campaignStory:SetText(ns.Data.Deed.endings.endless.text)
                    ui.endingNote:SetText("The shop keeps its doors open. You can still open a franchise.")
                elseif state.mode == "ending" then
                    ui.endlessButton:SetState(true)
                    ui.endlessButton:SetLabel("Keep the Shop Open")
                    ui.campaignStory:SetText("The ledger is closed. Snix is waiting for an answer. " ..
                        "Choose endless mode, or sign the shop over and begin a new deed with a permanent bonus.")
                    ui.endingNote:SetText("Franchise keeps the museum, Marta, achievements and every offer bonus.")
                else
                    ui.endlessButton:SetState(true)
                    ui.endlessButton:SetLabel("Keep the Shop Open")
                    ui.campaignStory:SetText(ns.Data.Deed.endings.endless.text)
                    ui.endingNote:SetText("Franchise level " .. tostring(db.prestige.level or 0))
                end
                ui.endingNote:Show()
                if ui.franchiseArmedUntil and U.now() <= ui.franchiseArmedUntil then
                    ui.franchiseButton:SetLabel("Click again to confirm")
                else
                    ui.franchiseButton:SetLabel("Open a Franchise")
                end
            else
                local nextPayment = ns.Campaign.NextPayment()
                local story = ns.Data.Deed.intro
                if state.payments > 0 then
                    local previous = ns.Data.Deed.payments[state.payments]
                    story = previous and previous.story or story
                end
                ui.campaignTitle:SetText(string.format("Payment %d of %d · %s",
                    state.payments + 1, payments, nextPayment and nextPayment.title or "The Ledger"))
                ui.campaignStory:SetText(story)
                ui.debtText:SetText(string.format("Paid %s / %s gc · Next note %s gc",
                    U.comma(paid), U.comma(total), U.comma(nextPayment and nextPayment.amount or 0)))
                ui.debtText:SetTextColor(T.colors.dim[1], T.colors.dim[2], T.colors.dim[3])
                ui.payButton:Show()
                local canPay = (db.credits or 0) >= (nextPayment and nextPayment.amount or math.huge)
                ui.payButton:SetState(canPay)
                ui.payButton:SetLabel(string.format("Pay %s gc", U.comma(nextPayment and nextPayment.amount or 0)))
                ui.endlessButton:Hide()
                ui.franchiseButton:Hide()
                ui.endingNote:Hide()
            end

            -- Museum
            ui.museumSub:SetText(string.format("%d / %d donated%s", ns.Museum.Count(), ns.Museum.Total(),
                ns.Museum.Completed() and " · complete, +5% offers" or ""))
            for index, slot in ipairs(ns.Data.Museum.slots) do
                local row = ui.museumRows[index]
                local button = ui.museumButtons[index]
                local donated = ns.Museum.Donated(slot.key)
                if donated then
                    row.label:SetText(donated.name or slot.label)
                    row.status:SetText("Donated · " .. (slot.hint or ""))
                    button:SetLabel("Done")
                    button:SetState(false)
                elseif not ns.Museum.Unlocked() then
                    row.label:SetText(slot.label)
                    row.status:SetText("Locked until the first payment")
                    button:SetLabel("Locked")
                    button:SetState(false)
                else
                    local record = ns.Museum.Eligible(slot.key)
                    row.label:SetText(slot.label)
                    row.status:SetText(record and ("Ready: " .. record.name) or (slot.hint or ""))
                    button:SetLabel(record and "Donate" or "No item")
                    button:SetState(record ~= nil)
                end
            end

            -- Marta
            ui.regularName:SetText(ns.Data.Regular.name)
            ui.regularRole:SetText(string.format("%s · %s", ns.Data.Regular.occupation, ns.Data.Regular.race))
            ui.regularBar:SetValue(ns.Regular.Visits(), ns.Regular.TotalVisits())
            ui.regularCaption:SetText(string.format("Visits %d / %d%s", ns.Regular.Visits(),
                ns.Regular.TotalVisits(), ns.Regular.Done() and " · complete" or ""))
            if not ns.Regular.Unlocked() then
                ui.regularStory:SetText("Marta Copperpin has heard about the shop, but she does not " ..
                    "visit unpaid businesses. Pay the first note to unlock her story.")
                ui.regularNext:SetText("Locked until the first payment.")
                ui.callButton:SetState(false)
                ui.callButton:SetLabel("Locked")
            elseif ns.Regular.Done() then
                ui.regularStory:SetText("Marta's story is complete. Her referral network adds +3% " ..
                    "to every customer offer, permanently.")
                ui.regularNext:SetText("No more visits. The museum keeps her pieces.")
                ui.callButton:SetState(false)
                ui.callButton:SetLabel("Story complete")
            else
                local canCall, reason = ns.Regular.CanCall()
                ui.regularStory:SetText(ns.Regular.State().lastStory or ns.Data.Regular.greeting)
                ui.regularNext:SetText(reason or string.format(
                    "Next visit ready. Natural arrivals check after %d sales, or invite her now.",
                    math.max(0, (ns.Regular.NextAt() or 0) - (db.stats.sales or 0))))
                ui.callButton:SetState(canCall)
                ui.callButton:SetLabel(canCall and "Invite Marta" or "Not ready")
            end

            -- Footer
            ui.journal:SetText(ns.Journal.StatusText())
            local bonus = ns.Campaign.OfferBonus()
            local parts = {
                string.format("Franchise level %d (+%d%% offers)", db.prestige.level or 0,
                    (db.prestige.level or 0) * 5),
            }
            if ns.Museum.Completed() then parts[#parts + 1] = "Museum +5%" end
            if ns.Regular.Done() then parts[#parts + 1] = "Marta +3%" end
            parts[#parts + 1] = string.format("Total +%d%%", math.floor(bonus * 100))
            ui.prestige:SetText(table.concat(parts, " · "))
        end

        ui.Refresh()
        return ui
    end,
}
