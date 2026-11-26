--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/EventFrame.lua
    A modal-looking popup for random encounters and their results.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local T = ns.Theme
local W = ns.Widgets

local frame, icon, titleText, bodyText, resultText
local optionButtons = {}
local contentHolder, optionHolder, continueButton

local function clearOptions()
    for _, button in ipairs(optionButtons) do
        button:Hide()
    end
end

local function showResult(text)
    clearOptions()
    bodyText:Hide()
    resultText:Show()
    resultText:SetText(text)
    if not continueButton then
        continueButton = W.Button(frame, "Continue", 160, 30, function()
            frame:Hide()
            if ns.UI.Refresh then ns.UI.Refresh() end
        end, "gold")
        continueButton:SetPoint("BOTTOM", 0, 18)
    end
    continueButton:Show()
end

local function refresh()
    local event = ns.Encounters.Pending()
    if not event then
        local result = ns.Encounters.PendingResult()
        if result then
            icon:SetIcon("Interface\\Icons\\INV_Misc_Note_01")
            titleText:SetText("SHOP LEDGER")
            showResult((result.text or "") .. "\n\n|cff888888" ..
                (result.tone == "good" and "A good day for business." or
                 result.tone == "bad" and "A bad day for business." or "Another day in the shop.") .. "|r")
        else
            frame:Hide()
        end
        return
    end

    icon:SetIcon(event.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    titleText:SetText(string.upper(event.title or "UNEXPECTED VISITOR"))
    bodyText:Show()
    resultText:Hide()
    bodyText:SetText(event.text or "")
    if continueButton then continueButton:Hide() end
    clearOptions()

    local offset = -8
    for index, option in ipairs(event.options or {}) do
        local button = optionButtons[index]
        if not button then
            button = W.Button(frame, option.label or "Continue", 392, 32, nil, option.tone or "neutral")
            optionButtons[index] = button
        end
        button:Show()
        button:SetLabel(option.label or "Continue")
        button:SetTone(option.tone or "neutral")
        button:SetState(not option.disabled)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", optionHolder, "TOPLEFT", 0, offset)
        button:SetScript("OnClick", function()
            local ok, message = ns.Encounters.Resolve(option.id)
            if ok then
                local event2 = ns.Encounters.Pending()
                if event2 then
                    refresh()
                else
                    icon:SetIcon("Interface\\Icons\\INV_Misc_Note_01")
                    titleText:SetText("SHOP LEDGER")
                    showResult(tostring(message))
                end
                if ns.UI.Refresh then ns.UI.Refresh() end
                if ns.Sound then ns.Sound.Play("open") end
            else
                ns.Print(tostring(message))
            end
        end)
        offset = offset - 38
    end
end

local function build()
    frame = ns.Compat.CreateFrame("Frame", "GoblinPawnStarsEventFrame", UIParent, "BackdropTemplate")
    if not frame then return end
    frame:SetSize(440, 360)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    T.Decorate(frame, "window")
    frame:SetPoint("CENTER", UIParent, "CENTER", -280, 40)

    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self:StartMoving() end
    end)
    frame:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)

    local close = W.Button(frame, "×", 24, 22, function() frame:Hide() end, "danger")
    close:SetPoint("TOPRIGHT", -10, -10)

    icon = W.Icon(frame, 42)
    icon:SetPoint("TOPLEFT", 18, -14)

    titleText = W.Text(frame, "UNEXPECTED VISITOR", 15, T.colors.gold)
    titleText:SetPoint("TOPLEFT", 70, -18)
    titleText:SetPoint("TOPRIGHT", -40, -18)

    local line = T.GoldLine(frame, 1)
    line:SetPoint("TOPLEFT", 14, -62)
    line:SetPoint("TOPRIGHT", -14, -62)

    bodyText = W.Text(frame, "", 12, T.colors.parchment)
    bodyText:SetPoint("TOPLEFT", 18, -74)
    bodyText:SetPoint("TOPRIGHT", -18, -74)
    bodyText:SetHeight(120)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetWordWrap(true)
    bodyText:SetSpacing(3)

    resultText = W.Text(frame, "", 12, T.colors.parchment)
    resultText:SetPoint("TOPLEFT", 18, -74)
    resultText:SetPoint("TOPRIGHT", -18, -74)
    resultText:SetHeight(180)
    resultText:SetJustifyH("LEFT")
    resultText:SetWordWrap(true)
    resultText:SetSpacing(3)
    resultText:Hide()

    optionHolder = W.Create(frame, "Frame")
    optionHolder:SetPoint("TOPLEFT", 24, -196)
    optionHolder:SetPoint("BOTTOMRIGHT", -24, 18)

    contentHolder = optionHolder
    frame:Hide()
end

build()

ns.UI.EventFrame = {
    Show = function()
        if not frame then return end
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
}
