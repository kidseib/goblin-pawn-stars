--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/NegotiationFrame.lua
    The haggling window. Shows the customer, their dialogue, the item, the
    offer, their patience and the counteroffer controls.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

local N = ns.Negotiation
local frame
local portrait, nameText, personalityText, patienceBar, patienceLabel
local dialogueText, itemIcon, itemName, itemValue, itemCount
local offerLabel, offerValue, marketLabel, marketValue
local counterBox, feedbackText
local acceptButton, rejectButton, counterButton, appraiseButton, closeButton
local wagerButton
local wagerHintId
local oddsText, oddsBar, payoutBanner
local streakText, streakBar, lastStreakText
local presets = {}
local locked = false
local payoutRevision = 0
local lastDialogueText

local PRESETS = {
    { label = "Low", kind = "low" },
    { label = "Fair", kind = "fair" },
    { label = "Greedy", kind = "greedy" },
}

-- The number beside the counter is the number N.Counter will roll, not a hint.
local function refreshOdds()
    if not oddsText then return end
    local amount = counterBox and tonumber(counterBox:GetText())
    local odds = N.Odds(amount)

    if not odds then
        oddsText:SetText("")
        oddsBar:SetValue(0, 1)
    elseif odds.kind == "none" then
        oddsText:SetText(T.Hex(T.colors.dim) .. "pick a price|r")
        oddsBar:SetValue(0, 1)
        oddsBar:SetColor(T.colors.dim)
    else
        local color = T.colors[odds.tone] or T.colors.muted
        oddsText:SetText(T.Hex(color) .. string.format("%d%%", odds.percent) .. "|r "
            .. T.Hex(T.colors.muted) .. odds.label .. "|r")
        oddsBar:SetValue(math.max(odds.chance, 0.02), 1)
        oddsBar:SetColor(color)
    end
end

--[[ Counter streak ---------------------------------------------------------
    One bar and one short label in the title bar: how close the current run of
    landed counters is to a clean deal, and whether one is armed. It reads three
    numbers from Modules/Streak.lua, writes the label only when the text actually
    changes, and never runs on a frame of its own.
--------------------------------------------------------------------------- ]]
local function refreshStreak()
    if not streakBar or not streakText then return end
    local streak = ns.Streak and ns.Streak.Status and ns.Streak.Status()
    if not streak then return end

    local color = T.colors[streak.tone] or T.colors.muted
    local text
    if streak.armed then
        local percent = math.floor((ns.Streak.Bonus() or 0) * 100 + 0.5)
        text = T.Hex(color) .. "CLEAN DEAL|r " .. T.Hex(T.colors.dim) .. "+" .. percent .. "% next|r"
    else
        text = T.Hex(color) .. (streak.label or "STREAK") .. "|r "
            .. T.Hex(T.colors.dim) .. string.format("%d/%d", streak.count, streak.limit) .. "|r"
    end
    if text ~= lastStreakText then
        lastStreakText = text
        streakText:SetText(text)
    end
    streakBar:SetValue(streak.armed and streak.limit or streak.count, streak.limit)
    streakBar:SetColor(streak.armed and T.colors.gold or (streak.count > 0 and T.colors.green or T.colors.dim))
end

local function refresh()
    local summary = N.Summary()
    if not summary then
        frame:Hide()
        return
    end

    local customer = summary.customer
    local personality = summary.personality or ns.Data.Personalities[1]
    local item = summary.item

    portrait:SetCustomer(customer)
    nameText:SetText(customer.name or "Customer")
    personalityText:SetText(string.format("%s%s · %s · %s",
        customer.regular and "Named regular · " or "",
        personality.name or "Customer", customer.occupation or "", customer.race or ""))

    local ratio = N.PatienceRatio()
    patienceBar:SetValue(ratio, 1)
    if ratio <= 0.34 then
        patienceBar:SetColor(T.colors.red)
    elseif ratio <= 0.67 then
        patienceBar:SetColor(T.colors.gold)
    else
        patienceBar:SetColor(T.colors.green)
    end
    patienceLabel:SetText(string.format("Patience: %d of %d",
        customer.patience or 0, customer.patienceMax or 0))

    -- Only touch the font string when the line actually changed: rewriting the
    -- same text every second re-wraps it and is wasted work while the window is
    -- open. An empty pool must still render something readable.
    local line = U.trim(customer.dialogue or customer.greeting or "")
    if line == "" then line = "They wait for you to name a price." end
    local shown = "“" .. line .. "”"
    if shown ~= lastDialogueText then
        dialogueText:SetText(shown)
        lastDialogueText = shown
    end

    itemIcon:SetIcon(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    itemName:SetText(T.ItemName(item))
    itemCount:SetText((item.count or 1) > 1 and ("x" .. tostring(item.count)) or "")

    marketValue:SetText(T.Credits(summary.price))
    offerValue:SetText(T.Credits(customer.offer or 0))

    if customer.appraised then
        appraiseButton:SetState(false)
        appraiseButton:SetLabel("Appraised")
    elseif N.Unlocked() then
        appraiseButton:SetState(true)
        appraiseButton:SetLabel("Appraise")
    else
        appraiseButton:SetState(false)
        appraiseButton:SetLabel("Appraise (locked)")
    end

    local damaged = item.counterfeit and customer.appraised
    itemValue:SetText(string.format("Category: %s%s",
        ns.Data.CategoryName(item.category),
        damaged and " |cffff5555· suspected forgery|r" or ""))

    for _, preset in ipairs(presets) do
        preset:SetState(true)
    end
    refreshOdds()
    refreshStreak()

    -- Double or nothing: only offered by the archetype that carries the data
    -- flag, only once, and only while there is a real gap to gamble over. The
    -- button states the odds; the tooltip states both outcomes.
    local terms = summary.wager
    if wagerButton then
        if terms then
            wagerButton.terms = terms
            wagerButton:Show()
            wagerButton:SetLabel(string.format("Double or nothing\n%d%% · win %s gc",
                terms.percent, U.comma(terms.prize)))
            if wagerHintId ~= customer.id then
                wagerHintId = customer.id
                feedbackText:SetText(string.format(
                    "|cffffd700They are out of time.|r Double or nothing at %d%%: "
                    .. "they pay %s gc if you win, %s gc if you lose, and %d standing.",
                    terms.percent, U.comma(terms.prize), U.comma(terms.loss), terms.sting or 0))
            end
        else
            wagerButton.terms = nil
            wagerButton:Hide()
        end
    end
end

-- Coins and a big number for a completed sale. completeSale has already paid the
-- credits and its return value is the exact wallet delta, so the banner shows that
-- number and nothing else.
local function payout(price)
    if not frame then return end
    price = tonumber(price) or 0
    if price <= 0 then return end

    payoutRevision = payoutRevision + 1
    local shown = payoutRevision
    if payoutBanner then
        payoutBanner.text:SetText("+" .. U.comma(price) .. " gc")
        payoutBanner:Show()
        ns.Anim.Pulse(payoutBanner, 1.16, 0.5)
        ns.Anim.Pulse(payoutBanner.text, 1.12, 0.4)
    end
    if ns.Sound then ns.Sound.Play("coin") end
    ns.Compat.After(2.4, function()
        if shown == payoutRevision and payoutBanner then payoutBanner:Hide() end
    end)
end

local function finish_and_close(result)
    if not result then return end
    local dialogue = result.dialogue or ""
    local price = tonumber(result.price) or 0
    if result.result == "sold" or result.result == "accepted" then
        if price <= 0 then
            -- completeSale now reports the exact credit delta. A zero here is a
            -- real defect, not something to hide behind the previous sale.
            feedbackText:SetText("|cffff6b5eThat sale reported no price. Nothing was guessed.|r")
            return
        end
        local clean = tonumber(result.cleanDeal) or 0
        if result.wager then
            if result.won then
                feedbackText:SetText("|cffffd700Double or nothing — you won it.|r |cff5fd64fThey paid "
                    .. U.comma(price) .. " gc.|r " .. dialogue)
                if payoutBanner then ns.Anim.Pulse(payoutBanner, 1.3, 0.6) end
            else
                feedbackText:SetText("|cffff6b5eDouble or nothing — the coin went their way.|r They paid "
                    .. U.comma(price) .. " gc and the shop's name took a knock. " .. dialogue)
            end
            payout(price)
        elseif clean > 0 then
            -- The flourish for the perk: the payout banner already exists, so
            -- the celebration is one more pulse on it, not another window.
            feedbackText:SetText("|cffffd700Clean deal!|r |cff5fd64fSold for "
                .. U.comma(price) .. " gc.|r " .. dialogue)
            if payoutBanner then ns.Anim.Pulse(payoutBanner, 1.26, 0.6) end
        else
            feedbackText:SetText("|cff5fd64fSold for " .. U.comma(price) .. " gc.|r " .. dialogue)
        end
        payout(price)
    elseif result.result == "rejected" or result.result == "left" or result.result == "insulted" then
        feedbackText:SetText("|cffff6b5eThey left.|r " .. dialogue)
    else
        feedbackText:SetText("|cffffd700" .. dialogue .. "|r")
    end

    if ns.UI.Refresh then ns.UI.Refresh() end
    ns.Compat.After(2.4, function()
        if frame and not N.Active() then frame:Hide() end
    end)
end

local function build()
    frame = ns.Compat.CreateFrame("Frame", "GoblinPawnStarsNegotiationFrame", UIParent, "BackdropTemplate")
    if not frame then return end
    frame:SetSize(470, 590)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetToplevel(true)
    T.Decorate(frame, "window")
    frame:SetPoint("CENTER", UIParent, "CENTER", 260, 0)

    local titleBar = W.Create(frame, "Frame")
    titleBar:SetPoint("TOPLEFT", 10, -8)
    titleBar:SetPoint("TOPRIGHT", -10, -8)
    titleBar:SetHeight(30)

    local title = W.Text(titleBar, "NEGOTIATION", 15, T.colors.gold)
    title:SetPoint("LEFT", 4, 0)

    closeButton = W.Button(titleBar, "×", 24, 22, function()
        if N.Active() then
            N.Close()
            if ns.UI.Refresh then ns.UI.Refresh() end
        end
        frame:Hide()
    end, "danger")
    closeButton:SetPoint("RIGHT", -2, 0)

    streakText = W.Text(titleBar, "", 10, T.colors.muted)
    streakText:SetPoint("RIGHT", closeButton, "LEFT", -12, 7)
    streakText:SetJustifyH("RIGHT")
    streakBar = W.Bar(titleBar, 104, 5, T.colors.dim)
    streakBar:SetPoint("RIGHT", closeButton, "LEFT", -12, -8)

    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self:StartMoving() end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
    end)

    -- Customer card ------------------------------------------------------
    local card = W.Panel(frame, "panel")
    card:SetPoint("TOPLEFT", 14, -44)
    card:SetPoint("TOPRIGHT", -14, -44)
    card:SetHeight(78)

    portrait = W.Portrait(card, 58, "WARRIOR")
    portrait:SetPoint("LEFT", 10, 0)

    nameText = W.Text(card, "Customer", 16, T.colors.gold)
    nameText:SetPoint("TOPLEFT", 80, -10)
    nameText:SetPoint("TOPRIGHT", -10, -10)

    personalityText = W.Text(card, "", 10, T.colors.muted)
    personalityText:SetPoint("TOPLEFT", 80, -31)
    personalityText:SetPoint("TOPRIGHT", -10, -31)

    patienceBar = W.Bar(card, 340, 8, T.colors.green)
    patienceBar:SetPoint("TOPLEFT", 80, -46)
    patienceLabel = W.Text(card, "", 9, T.colors.muted)
    patienceLabel:SetPoint("TOPLEFT", 80, -57)

    -- Dialogue -----------------------------------------------------------
    local dialoguePanel = W.Panel(frame, "inset")
    dialoguePanel:SetPoint("TOPLEFT", 14, -130)
    dialoguePanel:SetPoint("TOPRIGHT", -14, -130)
    dialoguePanel:SetHeight(76)
    local dialogueBackground = dialoguePanel:CreateTexture(nil, "BACKGROUND", nil, 1)
    dialogueBackground:SetPoint("TOPLEFT", 4, -4)
    dialogueBackground:SetPoint("BOTTOMRIGHT", -4, 4)
    T.Fill(dialogueBackground, 0.09, 0.07, 0.05, 1)
    dialogueText = W.Text(dialoguePanel, "", 14, T.colors.text)
    dialogueText:SetPoint("TOPLEFT", 12, -10)
    dialogueText:SetPoint("BOTTOMRIGHT", -12, 10)
    dialogueText:SetJustifyH("LEFT")
    dialogueText:SetWordWrap(true)
    dialogueText:SetSpacing(3)
    -- Long contextual lines wrap to three lines and stop there instead of being
    -- sliced by the panel edge halfway through a word.
    if dialogueText.SetMaxLines then dialogueText:SetMaxLines(3) end

    -- Item ---------------------------------------------------------------
    local itemPanel = W.Panel(frame, "inset")
    itemPanel:SetPoint("TOPLEFT", 14, -214)
    itemPanel:SetPoint("TOPRIGHT", -14, -214)
    itemPanel:SetHeight(72)

    itemIcon = W.Icon(itemPanel, 44)
    itemIcon:SetPoint("LEFT", 12, 0)

    itemName = W.Text(itemPanel, "Item", 13, T.colors.parchment)
    itemName:SetPoint("TOPLEFT", 68, -10)
    itemName:SetPoint("TOPRIGHT", -12, -10)
    itemCount = W.Number(itemPanel, "", 12, T.colors.muted)
    itemCount:SetPoint("TOPRIGHT", -10, -10)

    itemValue = W.Text(itemPanel, "", 10, T.colors.muted)
    itemValue:SetPoint("TOPLEFT", 68, -30)
    itemValue:SetPoint("TOPRIGHT", -12, -30)

    marketLabel = W.Text(itemPanel, "Estimated market value", 9, T.colors.dim)
    marketLabel:SetPoint("TOPLEFT", 68, -46)
    marketValue = W.Number(itemPanel, "0 gc", 13, T.colors.gold)
    marketValue:SetPoint("TOPLEFT", 180, -44)

    -- Offer --------------------------------------------------------------
    local offerPanel = W.Panel(frame, "parchment")
    offerPanel:SetPoint("TOPLEFT", 14, -294)
    offerPanel:SetPoint("TOPRIGHT", -14, -294)
    offerPanel:SetHeight(64)

    offerLabel = W.Text(offerPanel, "THEIR CURRENT OFFER", 9, T.colors.muted)
    offerLabel:SetPoint("TOPLEFT", 14, -9)
    offerValue = W.Number(offerPanel, "0 gc", 22, T.colors.gold)
    offerValue:SetPoint("TOPLEFT", 14, -22)

    local oddsCaption = W.Text(offerPanel, "YOUR COUNTER ODDS", 9, T.colors.muted)
    oddsCaption:SetPoint("TOPRIGHT", -14, -8)
    oddsCaption:SetJustifyH("RIGHT")
    oddsText = W.Number(offerPanel, "", 16, T.colors.gold)
    oddsText:SetPoint("TOPRIGHT", -14, -20)
    oddsText:SetJustifyH("RIGHT")
    oddsBar = W.Bar(offerPanel, 168, 7, T.colors.gold)
    oddsBar:SetPoint("TOPRIGHT", -14, -44)

    -- Counter ------------------------------------------------------------
    local counterLabel = W.Text(frame, "YOUR COUNTEROFFER", 9, T.colors.muted)
    counterLabel:SetPoint("TOPLEFT", 18, -368)

    counterBox = W.EditBox(frame, 150, 26, "amount")
    counterBox:SetPoint("TOPLEFT", 16, -382)
    counterBox:SetNumeric(true)
    counterBox:SetScript("OnTextChanged", function() refreshOdds() end)
    counterBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if not locked then
            -- Counter returns (ok, payload). Keeping only the first value passed
            -- a boolean to finish_and_close and errored on every landed counter.
            local ok, result = N.Counter(tonumber(self:GetText()))
            if ok then finish_and_close(result) end
            refresh()
        end
    end)

    local offset = 178
    for index, preset in ipairs(PRESETS) do
        local button = W.Button(frame, preset.label, 62, 26, function()
            if locked then return end
            counterBox:SetText(tostring(N.Suggested(preset.kind)))
            counterBox:SetFocus()
            counterBox:HighlightText()
        end, "neutral")
        button:SetPoint("TOPLEFT", offset, -382)
        presets[index] = button
        offset = offset + 68
    end

    counterButton = W.Button(frame, "Make Counteroffer", 200, 30, function()
        if locked then return end
        locked = true
        local ok, result = N.Counter(tonumber(counterBox:GetText()))
        locked = false
        if not ok then
            feedbackText:SetText("|cffff6b5e" .. tostring(result) .. "|r")
            return
        end
        finish_and_close(result)
        refresh()
    end, "gold")
    counterButton:SetPoint("TOPLEFT", 16, -416)

    wagerButton = W.Button(frame, "Double or nothing", 220, 30, function()
        if locked then return end
        locked = true
        local ok, result = N.Wager()
        locked = false
        if not ok then
            feedbackText:SetText("|cffff6b5e" .. tostring(result) .. "|r")
            refresh()
            return
        end
        finish_and_close(result)
        refresh()
    end, "gold")
    wagerButton:SetPoint("TOPLEFT", 226, -416)
    wagerButton:Hide()
    wagerButton:SetScript("OnEnter", function(self)
        local terms = self.terms
        if not GameTooltip or not terms then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Double or nothing", 0.94, 0.78, 0.33)
        GameTooltip:AddLine(string.format("Win · %d%%\nThey pay %s gc, the most they would ever pay.",
            terms.percent, U.comma(terms.prize)), 0.55, 0.85, 0.45)
        GameTooltip:AddLine(string.format("Lose · %d%%\nThey pay %s gc and your standing drops by %d.",
            100 - terms.percent, U.comma(terms.loss), terms.sting or 0), 0.95, 0.55, 0.5)
        GameTooltip:AddLine("One wager per customer. The odds are honest and slightly against you.",
            0.62, 0.58, 0.47)
        GameTooltip:Show()
    end)
    wagerButton:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    -- Actions ------------------------------------------------------------
    acceptButton = W.Button(frame, "Accept Offer", 200, 34, function()
        if locked then return end
        locked = true
        local ok, result = N.Accept()
        locked = false
        if not ok then
            feedbackText:SetText("|cffff6b5e" .. tostring(result) .. "|r")
            return
        end
        finish_and_close(result)
    end, "primary")
    acceptButton:SetPoint("TOPLEFT", 16, -458)

    rejectButton = W.Button(frame, "Reject", 130, 34, function()
        if locked then return end
        locked = true
        local ok, result = N.Reject()
        locked = false
        if ok then finish_and_close(result) end
    end, "danger")
    rejectButton:SetPoint("TOPLEFT", 226, -458)

    appraiseButton = W.Button(frame, "Appraise", 100, 34, function()
        if locked then return end
        local ok, info = N.Appraise()
        if not ok then
            feedbackText:SetText("|cffffaa55" .. tostring(info) .. "|r")
            return
        end
        local text
        if info.counterfeit then
            text = "|cffff5555Forgery. The hallmark is wrong, and the metal is worse.|r"
        elseif info.exact then
            text = string.format("|cff7bd66bWorth about %s gc.|r|nThey look like they could reach %s gc.",
                U.comma(info.value), U.comma(info.ceiling or 0))
        else
            text = string.format("|cffffd700Somewhere between %s and %s gc. You'd want a better loupe.|r",
                U.comma(info.lower), U.comma(info.upper))
        end
        feedbackText:SetText(text)
        refresh()
    end, "blue")
    appraiseButton:SetPoint("TOPRIGHT", -16, -458)
    appraiseButton:SetWidth(100)

    -- Feedback -----------------------------------------------------------
    feedbackText = W.Text(frame, " ", 11, T.colors.parchment)
    feedbackText:SetPoint("TOPLEFT", 18, -502)
    feedbackText:SetPoint("BOTTOMRIGHT", -18, 14)
    feedbackText:SetJustifyH("LEFT")
    feedbackText:SetWordWrap(true)
    feedbackText:SetSpacing(3)

    -- Payout banner ------------------------------------------------------
    payoutBanner = W.Create(frame, "Frame")
    payoutBanner:SetPoint("CENTER", frame, "CENTER", 0, 60)
    payoutBanner:SetSize(320, 64)
    local glow = payoutBanner:CreateTexture(nil, "BACKGROUND")
    glow:SetAllPoints()
    T.Fill(glow, 0.95, 0.78, 0.30, 0.16)
    payoutBanner.text = W.Number(payoutBanner, "", 34, T.colors.gold)
    payoutBanner.text:SetPoint("CENTER", 0, 0)
    payoutBanner.text:SetJustifyH("CENTER")
    payoutBanner:Hide()

    frame:Hide()
    if UISpecialFrames then
        local exists = false
        for _, name in ipairs(UISpecialFrames) do
            if name == "GoblinPawnStarsNegotiationFrame" then exists = true break end
        end
        if not exists then table.insert(UISpecialFrames, "GoblinPawnStarsNegotiationFrame") end
    end
end

build()

ns.UI.Negotiation = {
    Show = function()
        if not frame then return end
        if not N.Active() then
            ns.Print("No customer is at the counter.")
            return
        end
        frame:Show()
        if ns.Anim then ns.Anim.Reveal(frame, 0.2, 0) end
        refresh()
    end,
    Hide = function()
        if frame then frame:Hide() end
    end,
    Refresh = function()
        if frame and frame:IsShown() then refresh() end
    end,
    Frame = function()
        return frame
    end,
    CounterBox = function()
        return counterBox
    end,
    CounterButton = function()
        return counterButton
    end,
    AcceptButton = function()
        return acceptButton
    end,
    PayoutText = function()
        return payoutBanner and payoutBanner.text:GetText() or nil
    end,
    StreakText = function()
        return streakText and streakText:GetText() or nil
    end,
    StreakBar = function()
        return streakBar
    end,
    WagerButton = function()
        return wagerButton
    end,
}

ns.UI.RefreshOverlays = function()
    if ns.UI.Negotiation then ns.UI.Negotiation.Refresh() end
end
