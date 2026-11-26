--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/WholesalerFrame.lua
    Three rotating wholesale lots. Buying is a credit sink; the profit only
    exists once customers buy the virtual stock one unit at a time.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

local frame
local rows = {}
local timerText
local refresh

local function qualityColor(quality)
    if quality >= 3 then return T.colors.blue end
    if quality == 2 then return T.colors.green end
    return T.colors.parchment
end

local function build()
    frame = W.Panel(UIParent, "panel")
    if not frame then return end
    frame:SetSize(570, 430)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()

    local title = W.Text(frame, "GOBLIN WHOLESALER", 19, T.colors.gold)
    title:SetPoint("TOPLEFT", 16, -12)

    local subtitle = W.Text(frame, "Bulk lots, no receipts. Delivery every few minutes.", 10, T.colors.muted)
    subtitle:SetPoint("TOPLEFT", 16, -34)

    local close = W.Button(frame, "X", 26, 24, function() frame:Hide() end, "neutral")
    close:SetPoint("TOPRIGHT", -12, -12)

    local divider = W.Divider(frame, 538, 1)
    divider:SetPoint("TOPLEFT", 16, -58)

    for position = 1, 3 do
        local slot = position
        local row = W.Panel(frame, "inset")
        row:SetPoint("TOPLEFT", 14, -68 - (slot - 1) * 104)
        row:SetPoint("TOPRIGHT", -14, -68 - (slot - 1) * 104)
        row:SetHeight(96)

        local icon = W.Icon(row, 46)
        icon:SetPoint("LEFT", 12, 0)
        row.icon = icon

        local name = W.Text(row, "", 13, T.colors.parchment)
        name:SetPoint("TOPLEFT", 68, -10)
        name:SetPoint("TOPRIGHT", -176, -10)
        row.name = name

        local contents = W.Text(row, "", 10, T.colors.text)
        contents:SetPoint("TOPLEFT", 68, -30)
        contents:SetPoint("TOPRIGHT", -176, -30)
        row.contents = contents

        local meta = W.Text(row, "", 9, T.colors.muted)
        meta:SetPoint("TOPLEFT", 68, -48)
        meta:SetPoint("TOPRIGHT", -176, -48)
        row.meta = meta

        local cost = W.Number(row, "0", 16, T.colors.gold)
        cost:SetPoint("TOPRIGHT", -94, -12)
        cost:SetJustifyH("RIGHT")
        row.cost = cost

        local costCaption = W.Text(row, "BUY-IN", 8, T.colors.muted)
        costCaption:SetPoint("TOPRIGHT", -94, -31)
        costCaption:SetJustifyH("RIGHT")

        local buy = W.Button(row, "Buy lot", 76, 26, function()
            local ok, result, err = ns.Wholesaler.Buy(slot)
            if ok then
                ns.UI.Toast("Lot bought. Stock is on the shelves.")
            else
                ns.UI.Toast(err or (type(result) == "string" and result)
                    or "The wholesaler laughs and keeps the crate.")
            end
            refresh()
            if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        end, "gold")
        buy:SetPoint("RIGHT", -10, 10)
        row.buy = buy

        rows[slot] = row
    end

    timerText = W.Text(frame, "", 10, T.colors.dim)
    timerText:SetPoint("BOTTOMLEFT", 16, 14)

    local note = W.Text(frame, "Credits leave now. Profit only arrives when a customer buys a unit.", 9, T.colors.dim)
    note:SetPoint("BOTTOMRIGHT", -16, 14)
    note:SetJustifyH("RIGHT")
end

refresh = function()
    if not frame or not frame:IsShown() then return end

    local lots = ns.Wholesaler.Lots()
    for position, row in ipairs(rows) do
        local lot = lots[position]
        if lot then
            row:Show()
            row.icon:SetIcon(lot.icon)
            row.icon:SetAlpha(lot.bought and 0.4 or 1)
            row.name:SetText(lot.name)
            row.name:SetTextColor(qualityColor(lot.quality)[1], qualityColor(lot.quality)[2], qualityColor(lot.quality)[3])
            row.contents:SetText(string.format("%d × %s · item level %d", lot.count, lot.itemName, lot.ilvl))
            local margin = lot.retail > 0 and math.floor(((lot.retail - lot.cost) / lot.retail) * 100) or 0
            row.meta:SetText(string.format("Est. retail %s gc · %d%% before haggling",
                U.comma(lot.retail), margin))
            row.cost:SetText(U.comma(lot.cost))
            if lot.bought then
                row.buy:SetState(false)
                row.buy:SetLabel("Sold")
                row.meta:SetText("Sold. The next delivery is already being loaded.")
            else
                row.buy:SetState(true)
                row.buy:SetLabel("Buy lot")
            end
        else
            row:Hide()
        end
    end

    timerText:SetText(string.format("Next delivery in %s", U.clock(ns.Wholesaler.TimeLeft())))
end

ns.UI.Wholesaler = {
    Show = function()
        if not frame then build() end
        if not frame then return end
        ns.Wholesaler.Ensure()
        frame:Show()
        refresh()
    end,
    Hide = function()
        if frame then frame:Hide() end
    end,
    Refresh = function()
        refresh()
    end,
}

build()
