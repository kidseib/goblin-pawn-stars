--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/MinimapButton.lua
    A draggable coin on the minimap. Click to open the shop, drag to reposition.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local T = ns.Theme
local W = ns.Widgets
local DB = ns.DB

local button

local function positionFromAngle(angle)
    local radians = math.rad(angle or 195)
    local radius = 80
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

local function updatePosition()
    local angle = DB.Get().settings.minimapAngle or 195
    positionFromAngle(angle)
end

local function updateVisibility()
    if not button then return end
    if DB.Get().settings.minimap == false then
        button:Hide()
    else
        button:Show()
    end
end

function ns.UI.UpdateMinimap()
    updateVisibility()
    updatePosition()
end

local function build()
    button = ns.Compat.CreateFrame("Button", "GoblinPawnStarsMinimapButton", Minimap)
    if not button then return end
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local ring = button:CreateTexture(nil, "BACKGROUND")
    ring:SetSize(52, 52)
    ring:SetPoint("CENTER")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(T.media.coin)
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    button.icon = icon

    local alert = button:CreateTexture(nil, "OVERLAY")
    alert:SetSize(8, 8)
    alert:SetPoint("TOPRIGHT", -4, -4)
    T.Fill(alert, 0.4, 0.9, 0.35, 1)
    alert:Hide()
    button.alert = alert

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            if ns.UI.ShowTab then
                ns.UI.ShowTab("dashboard")
                ns.UI.Open()
            end
        else
            ns.UI.Toggle()
        end
        if ns.Sound then ns.Sound.Play("open") end
    end)

    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            DB.Get().settings.minimapAngle = angle
            positionFromAngle(angle)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        DB.Save()
    end)

    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local summary = ns.Shop.Summary()
        GameTooltip:SetText("Goblin Pawn Stars", 0.94, 0.78, 0.33)
        GameTooltip:AddLine(summary.tierName, 0.91, 0.85, 0.69)
        GameTooltip:AddLine("Credits: " .. ns.Util.comma(summary.credits), 1, 0.82, 0)
        GameTooltip:AddLine(string.format("Stock: %d / %d · Waiting: %d",
            summary.storageUsed, summary.storageMax, summary.customersWaiting), 0.8, 0.78, 0.7)
        if summary.customersWaiting > 0 then
            GameTooltip:AddLine("A customer is waiting at your counter.", 0.49, 0.84, 0.42)
        end
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("Left click to open · drag to move", 0.55, 0.52, 0.45)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        ns.Compat.HideTooltip()
    end)

    updatePosition()
    updateVisibility()

    button:SetScript("OnUpdate", nil)
    if C_Timer and C_Timer.NewTicker then
        pcall(C_Timer.NewTicker, 2, function()
            if not button then return end
            if #DB.Get().shop.waiting > 0 then button.alert:Show() else button.alert:Hide() end
        end)
    end
end

build()

function ns.UI.MinimapButton()
    return button
end
