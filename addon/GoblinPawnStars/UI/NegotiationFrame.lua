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
local presets = {}
local locked = false

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

    dialogueText:SetText("|cff2b2118“|r" .. (customer.dialogue or customer.greeting or "...") .. "|cff2b2118”|r")
    dialogueText:SetTextColor(0.16, 0.12, 0.07)

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
end

local function finish_and_close(result)
    if not result then return end
    local dialogue = result.dialogue or ""
    if result.result == "sold" then
        feedbackText:SetText("|cff5fd64fSold for " .. U.comma(result.price or 0) .. " gc.|r " .. dialogue)
        if ns.Sound then ns.Sound.Play("coin") end
    elseif result.result == "accepted" then
        feedbackText:SetText("|cff5fd64fDeal at " .. U.comma(result.price or 0) .. " gc.|r " .. dialogue)
        if ns.Sound then ns.Sound.Play("coin") end
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
    dialogueText = W.Text(dialoguePanel, "", 13, T.colors.parchment)
    dialogueText:SetPoint("TOPLEFT", 12, -10)
    dialogueText:SetPoint("BOTTOMRIGHT", -12, 10)
    dialogueText:SetJustifyH("LEFT")
    dialogueText:SetWordWrap(true)
    dialogueText:SetSpacing(3)

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

    local hint = W.Text(offerPanel, "Counter below, or take the deal.", 10, T.colors.muted)
    hint:SetPoint("RIGHT", -14, -6)
    hint:SetJustifyH("RIGHT")

    -- Counter ------------------------------------------------------------
    local counterLabel = W.Text(frame, "YOUR COUNTEROFFER", 9, T.colors.muted)
    counterLabel:SetPoint("TOPLEFT", 18, -368)

    counterBox = W.EditBox(frame, 150, 26, "amount")
    counterBox:SetPoint("TOPLEFT", 16, -382)
    counterBox:SetNumeric(true)
    counterBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if not locked then
            local result = N.Counter(tonumber(self:GetText()))
            if result then finish_and_close(result) end
            refresh()
        end
    end)

    local presetData = {
        { label = "Low", amount = function() return N.Suggested("low") end },
        { label = "Fair", amount = function() return N.Suggested("fair") end },
        { label = "Greedy", amount = function() return N.Suggested("greedy") end },
    }
    local offset = 178
    for index, preset in ipairs(presetData) do
        local button = W.Button(frame, preset.label, 62, 26, function()
            if locked then return end
            counterBox:SetText(tostring(preset.amount()))
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
        local result = N.Counter(tonumber(counterBox:GetText()))
        locked = false
        if not result then
            feedbackText:SetText("|cffff6b5eType a number first.|r")
            return
        end
        finish_and_close(result)
        refresh()
    end, "gold")
    counterButton:SetPoint("TOPLEFT", 16, -416)

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
}

ns.UI.RefreshOverlays = function()
    if ns.UI.Negotiation then ns.UI.Negotiation.Refresh() end
end
