-- Goblin Pawn Stars: customer entrances and shared customer artwork.
local ADDON, ns = ...
local W, T = ns.Widgets, ns.Theme
local arrival = {}
ns.UI.CustomerArrival = arrival

local media = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local rows = {
    Goblin = 0, Gnome = 0, Dwarf = 1, Orc = 2, Troll = 2, Human = 3,
    BloodElf = 4, NightElf = 4, Tauren = 5, Pandaren = 5, Vulpera = 5,
    Undead = 6,
}
local coats = {
    WARRIOR = { 0.86, 0.54, 0.36 }, ROGUE = { 0.65, 0.78, 0.48 },
    MAGE = { 0.53, 0.76, 1 }, PRIEST = { 1, 0.93, 0.78 },
    HUNTER = { 0.68, 0.83, 0.55 }, PALADIN = { 1, 0.76, 0.45 },
    WARLOCK = { 0.78, 0.62, 0.93 }, DRUID = { 0.77, 0.83, 0.54 },
}

function arrival.Paint(texture, customer, pose)
    local row = customer.regular and 7 or (rows[customer.race] or 3)
    pose = pose or 0
    if texture:SetTexture(media .. "Customers.tga") == false then return false end
    texture:SetTexCoord((pose * 32 + 0.5) / 128, (pose * 32 + 31.5) / 128,
        (row * 32 + 0.5) / 256, (row * 32 + 31.5) / 256)
    local tint = coats[customer.class]
    if customer.regular or not tint then
        texture:SetVertexColor(1, 1, 1)
    else
        texture:SetVertexColor(tint[1], tint[2], tint[3])
    end
    return true
end

local stepOffsets = { [0] = 23, -5, 9 }

local card
local revision = 0
local current
local animated

function arrival.Hide()
    revision = revision + 1
    current = nil
    if card then card:Hide() end
end

function arrival.Refresh()
    if not current then return end
    local count = #ns.Customers.Waiting()
    if count == 0 then
        arrival.Hide()
        return
    end
    card.detail:SetText(string.format("%s  ·  %d waiting",
        current.regular and "Returning customer" or (current.rare and "Rare customer" or "Customer arrived"), count))
end

function arrival.Position()
    if not card then return end
    card:ClearAllPoints()
    if ns.UI.IsOpen() then
        card:SetSize(260, animated and 58 or 38)
        card:SetPoint("TOPRIGHT", ns.UI.Header.frame, "TOPRIGHT", -8, -2)
    else
        card:SetSize(306, animated and 66 or 42)
        card:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -28, -196)
    end
end

local function build()
    local panel = W.Panel(UIParent, "panel")
    if not panel then return end
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(40)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        arrival.Hide()
        ns.UI.Open()
        ns.UI.ShowTab("customers")
    end)
    panel.door = panel:CreateTexture(nil, "ARTWORK")
    panel.door:SetTexture(media .. "ShopDoor.tga")
    panel.door:SetSize(48, 48)
    panel.door:SetPoint("BOTTOMLEFT", 5, 5)
    panel.actor = panel:CreateTexture(nil, "ARTWORK", nil, 1)
    panel.name = W.Text(panel, "", 13, T.colors.gold)
    panel.name:SetWordWrap(false)
    panel.detail = W.Text(panel, "", 10, T.colors.parchment)
    panel.detail:SetPoint("TOPLEFT", panel.name, "BOTTOMLEFT", 0, -3)
    panel.glint = W.Text(panel, "✦", 19, T.colors.gold)
    panel.glint:SetPoint("TOPLEFT", 8, -4)
    panel:Hide()
    return panel
end

function arrival.Show(customer)
    local mode = ns.DB.Get().settings.customerArrival
    if mode == "Off" or #ns.Customers.Waiting() == 0 then return end
    card = card or build()
    if not card then return end

    animated = mode ~= "Compact"
    current = customer
    revision = revision + 1
    local shownRevision = revision
    arrival.Position()
    arrival.Refresh()
    card.name:ClearAllPoints()
    card.name:SetPoint("LEFT", animated and 76 or 44, 7)
    card.name:SetPoint("RIGHT", -12, 7)
    card.name:SetText(customer.name)
    card.door:SetShown(animated)
    card.glint:SetShown(animated and (customer.rare or customer.regular) and true or false)
    card.actor:SetSize(animated and 48 or 30, animated and 48 or 30)

    local function setPose(pose)
        if shownRevision ~= revision then return end
        local offset = animated and stepOffsets[pose] or 8
        card.actor:ClearAllPoints()
        card.actor:SetPoint("BOTTOMLEFT", offset, 5)
        if not arrival.Paint(card.actor, customer, pose) then
            card.actor:SetTexture("Interface\\Icons\\ClassIcon_" .. (customer.class or "WARRIOR"))
            card.actor:SetTexCoord(0, 1, 0, 1)
            card.actor:SetVertexColor(1, 1, 1)
        end
    end

    card:Show()
    if animated then
        ns.Anim.CustomerWalk(card.actor, setPose)
        if card.glint:IsShown() then ns.Anim.Pulse(card.glint, 1.25, 0.45) end
    else
        setPose(0)
    end
    ns.Compat.After(4, function()
        if revision == shownRevision then arrival.Hide() end
    end)
    return card
end
