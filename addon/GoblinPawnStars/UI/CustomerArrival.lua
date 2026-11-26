-- Goblin Pawn Stars: movable customer-arrival notifications.
local ADDON, ns = ...
local W, T = ns.Widgets, ns.Theme
local arrival = {}
ns.UI.CustomerArrival = arrival

local layouts = {
    compact = { width = 274, height = 46, actor = 30, start = 8, distance = 0, text = 46 },
    screen = { width = 306, height = 74, actor = 62, start = 4, distance = 34, text = 108 },
    shop = { width = 420, height = 112, actor = 96, start = 6, distance = 58, text = 174 },
}

local card
local revision, dismissal = 0, 0
local current, animated, previewing
local scope, layout
local dragging, dragged, walking

local function placement()
    return ns.DB.Get().settings.arrivalPositions
end

local function placeActor()
    if not card or not layout then return end
    local offset = layout.start + (walking and 0 or layout.distance)
    card.actor:ClearAllPoints()
    card.actor:SetPoint("LEFT", card, "LEFT", offset, 0)
end

function arrival.Hide()
    revision = revision + 1
    current = nil
    previewing = false
    walking = false
    if card then
        if dragging then card:StopMovingOrSizing() end
        dragging = false
        ns.Anim.StopCustomerWalk(card.actor)
        if card.model then card.model:SetWalking(false) end
        card:Hide()
    end
end

local function dismissAfter(seconds)
    dismissal = dismissal + 1
    local shown, timer = revision, dismissal
    ns.Compat.After(seconds, function()
        if shown == revision and timer == dismissal and not dragging then arrival.Hide() end
    end)
end

function arrival.Refresh()
    if not current or previewing then return end
    local count = #ns.Customers.Waiting()
    if count == 0 then
        if not dragging then arrival.Hide() end
        return
    end
    card.detail:SetText(string.format("%s  ·  %d waiting",
        current.regular and "Returning customer" or (current.rare and "Rare customer" or "Customer arrived"), count))
end

function arrival.Position()
    if not card or dragging then return end
    local negotiation = ns.UI.Negotiation and ns.UI.Negotiation.Frame()
    local shopOpen = ns.UI.IsOpen and ns.UI.IsOpen()
    scope = (shopOpen or (negotiation and negotiation:IsShown())) and "shop" or "screen"
    layout = animated and layouts[scope] or layouts.compact
    local large = layout == layouts.shop
    local saved = placement()[scope]
    local x = type(saved) == "table" and tonumber(saved.x) or 0
    local y = type(saved) == "table" and tonumber(saved.y) or 0
    card:ClearAllPoints()
    card:SetPoint("CENTER", UIParent, "CENTER", x, y)
    card:SetSize(layout.width, layout.height)
    card.actor:SetSize(layout.actor, layout.actor)
    card.icon:SetSize(large and 48 or 30, large and 48 or 30)
    card.door:SetSize(large and 76 or 52, large and 86 or 56)
    card.name:ClearAllPoints()
    card.name:SetPoint("LEFT", card, "LEFT", layout.text, large and 13 or 7)
    card.name:SetPoint("RIGHT", card, "RIGHT", -12, large and 13 or 7)
    card.name:SetFont(T.font, large and 20 or 13, "")
    card.hint:SetShown(large)
    placeActor()
end

local function build()
    local panel = W.Panel(UIParent, "panel")
    if not panel then return end
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(40)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnMouseDown", function() dragged = false end)
    panel:SetScript("OnDragStart", function(self)
        dragged, dragging = true, true
        self:StartMoving()
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        dragging = false
        local x, y = self:GetCenter()
        local centerX, centerY = UIParent:GetCenter()
        if x and y and centerX and centerY then
            placement()[scope] = { x = x - centerX, y = y - centerY }
        end
        arrival.Position()
        dismissAfter(previewing and 4 or 2.5)
    end)
    panel:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or dragging or dragged then return end
        arrival.Hide()
        ns.UI.Open()
        ns.UI.ShowTab("customers")
    end)

    panel.door = panel:CreateTexture(nil, "ARTWORK")
    panel.door:SetPoint("LEFT", 8, 0)
    T.Fill(panel.door, 0.23, 0.14, 0.07, 1)
    local recess = panel:CreateTexture(nil, "ARTWORK", nil, 1)
    recess:SetPoint("TOPLEFT", panel.door, 3, -3)
    recess:SetPoint("BOTTOMRIGHT", panel.door, -3, 3)
    T.Fill(recess, 0.06, 0.04, 0.03, 1)
    panel.recess = recess

    panel.flash = panel:CreateTexture(nil, "OVERLAY")
    panel.flash:SetPoint("TOPLEFT", 5, -5)
    panel.flash:SetPoint("BOTTOMRIGHT", -5, 5)
    T.Fill(panel.flash, 1, 0.76, 0.22, 0.30)
    panel.flash:SetAlpha(0)
    panel.actor = W.Create(panel, "Frame")
    panel.icon = panel.actor:CreateTexture(nil, "ARTWORK")
    panel.icon:SetPoint("CENTER")
    panel.name = W.Text(panel, "", 13, T.colors.gold)
    if panel.name.SetWordWrap then panel.name:SetWordWrap(false) end
    panel.detail = W.Text(panel, "", 10, T.colors.parchment)
    panel.detail:SetPoint("TOPLEFT", panel.name, "BOTTOMLEFT", 0, -4)
    panel.hint = W.Text(panel, "Drag to move", 9, T.colors.muted)
    panel.hint:SetPoint("BOTTOMRIGHT", -12, 10)
    local ok, widget = pcall(ns.UI.CustomerModel.Attach, panel.actor, panel.icon, 0)
    panel.model = ok and widget or nil
    panel:Hide()
    return panel
end

function arrival.Show(customer, preview)
    local mode = preview and "Animated" or ns.DB.Get().settings.customerArrival
    if not preview and (mode == "Off" or #ns.Customers.Waiting() == 0) then return end
    card = card or build()
    if not card then return end

    animated = mode ~= "Compact"
    current, previewing = customer, preview
    revision = revision + 1
    local shown = revision
    walking = false
    ns.Anim.StopCustomerWalk(card.actor)
    arrival.Position()
    if preview then
        card.detail:SetText("Arrival preview")
    else
        arrival.Refresh()
    end
    card.name:SetText(customer.name)
    card.door:SetShown(animated)
    card.recess:SetShown(animated)
    card.flash:SetAlpha(0)
    W.SetClassIcon(card.icon, customer.class)
    card:Show()

    if card.model then
        card.model:SetWalking(false)
        local ok, err = pcall(card.model.SetCustomer, card.model, customer, function(model)
            if shown ~= revision or not animated then return end
            walking = true
            placeActor()
            model:SetWalking(true)
            ns.Anim.CustomerWalk(card.actor, layout.distance, function()
                if shown ~= revision then return end
                walking = false
                placeActor()
                model:SetWalking(false)
            end)
        end)
        if not ok then ns.Debug("customer model: " .. tostring(err)) end
    end
    if animated and (scope == "shop" or customer.rare or customer.regular) then
        ns.Anim.Flash(card.flash)
    end
    if preview then
        ns.Compat.After(1.8, function()
            if shown == revision and card.icon:IsShown() then
                ns.Warn("WoW could not load the preview model. The arrival card is using a game icon.")
            end
        end)
    end
    dismissAfter(preview and 8 or (scope == "shop" and 5 or 4))
    return card
end
