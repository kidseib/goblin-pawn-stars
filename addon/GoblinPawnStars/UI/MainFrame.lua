--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/MainFrame.lua
    The shop window: title bar, sidebar tabs, a live header and the tab host.
    Tabs are registered by the files in UI/Tabs and built lazily.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets
local DB = ns.DB

ns.UI.TabOrder = {
    "dashboard", "deed", "customers", "inventory", "market",
    "upgrades", "employees", "achievements", "history", "settings",
}

local frame
local header = {}
local lastCredits
local tabButtons = {}
local tabHost
local activeTab = "dashboard"
local tickAccumulator = 0
local slowAccumulator = 0
local toastFrame
local toastTimer

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function savePosition()
    if not frame then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local db = DB.Get()
    db.settings.window = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = x or 0,
        y = y or 0,
    }
end

local function restorePosition()
    local db = DB.Get()
    local saved = db.settings.window
    frame:ClearAllPoints()
    if type(saved) == "table" and saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    else
        frame:SetPoint("CENTER")
    end
end

local function buildHeader(parent)
    local panel = W.Panel(parent, "panel")
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    panel:SetHeight(56)

    header.creditsCaption = W.Text(panel, "GOBLIN CREDITS", 9, T.colors.muted)
    header.creditsCaption:SetPoint("TOPLEFT", 12, -8)
    header.creditsValue = W.Number(panel, "0", 20, T.colors.gold)
    header.creditsValue:SetPoint("TOPLEFT", 12, -19)

    header.repCaption = W.Text(panel, "REPUTATION", 9, T.colors.muted)
    header.repCaption:SetPoint("TOPLEFT", 182, -8)
    header.repValue = W.Text(panel, "Nobody", 11, T.colors.text)
    header.repValue:SetPoint("TOPLEFT", 182, -20)
    header.repBar = W.Bar(panel, 180, 7, T.colors.green)
    header.repBar:SetPoint("TOPLEFT", 182, -37)

    header.stockCaption = W.Text(panel, "STOCK", 9, T.colors.muted)
    header.stockCaption:SetPoint("TOPLEFT", 390, -8)
    header.stockValue = W.Text(panel, "0 / 0", 11, T.colors.text)
    header.stockValue:SetPoint("TOPLEFT", 390, -20)
    header.stockBar = W.Bar(panel, 130, 7, T.colors.parchment)
    header.stockBar:SetPoint("TOPLEFT", 390, -37)

    header.trafficCaption = W.Text(panel, "NEXT CUSTOMER", 9, T.colors.muted)
    header.trafficCaption:SetPoint("TOPLEFT", 548, -8)
    header.trafficValue = W.Text(panel, "—", 11, T.colors.text)
    header.trafficValue:SetPoint("TOPLEFT", 548, -20)
    header.dayBar = W.Bar(panel, 180, 7, T.colors.goldDim)
    header.dayBar:SetPoint("TOPLEFT", 548, -37)

    header.rates = W.Text(panel, "", 8, T.colors.green)
    header.rates:SetPoint("TOPLEFT", 12, -43)

    header.clock = W.Text(panel, "", 9, T.colors.dim)
    header.clock:SetPoint("BOTTOMRIGHT", -12, -6)
    header.clock:SetJustifyH("RIGHT")

    header.frame = panel
    ns.UI.Header = header
end

local function buildSidebar(parent)
    local sidebar = W.Panel(parent, "panel")
    -- Left-anchored only. Adding a right-edge anchor here makes the client stretch
    -- the sidebar to the window width (the anchor beats SetWidth), which turns every
    -- tab button into a full-width bar sitting above the tab content and swallowing
    -- its clicks. Keep the width explicit and the right edge free.
    sidebar:SetPoint("TOPLEFT", 10, -56)
    sidebar:SetPoint("BOTTOMLEFT", 10, 12)
    sidebar:SetWidth(188)
    ns.UI.Sidebar = sidebar

    local title = W.Text(sidebar, "SHOP LEDGER", 10, T.colors.goldDim)
    title:SetPoint("TOPLEFT", 12, -10)

    local divider = W.Divider(sidebar, 160, 1)
    divider:SetPoint("TOPLEFT", 12, -24)

    local offset = -32
    for index, id in ipairs(ns.UI.TabOrder) do
        local def = ns.UI.Tabs[id]
        if def then
            local button = W.Create(sidebar, "Button")
            -- Explicit size: never derive the hit area from both sidebar edges.
            button:SetPoint("TOPLEFT", 8, offset)
            button:SetSize(172, 36)
            button:RegisterForClicks("AnyUp")

            local bg = button:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            T.Fill(bg, 0.10, 0.08, 0.05, 0.5)
            button.bg = bg

            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            T.Fill(highlight, 0.85, 0.75, 0.4, 0.10)

            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetSize(20, 20)
            icon:SetPoint("LEFT", 8, 0)
            icon:SetTexture(def.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
            button.icon = icon

            local label = W.Text(button, def.title or id, 12, T.colors.text)
            label:SetPoint("LEFT", 36, 0)
            button.label = label

            local selected = button:CreateTexture(nil, "OVERLAY")
            selected:SetPoint("TOPLEFT")
            selected:SetPoint("BOTTOMRIGHT")
            T.Fill(selected, 0.62, 0.50, 0.22, 0.28)
            selected:Hide()
            button.selected = selected

            button:SetScript("OnClick", function()
                ns.UI.ShowTab(id)
            end)

            tabButtons[id] = button
            offset = offset - 38
        end
    end

    ns.UI.TabButtons = tabButtons

    local footer = W.Text(sidebar, "Goblin Pawn Stars", 9, T.colors.dim)
    footer:SetPoint("BOTTOMLEFT", 12, 10)
    local version = W.Text(sidebar, "v" .. ns.VERSION, 9, T.colors.dim)
    version:SetPoint("BOTTOMRIGHT", -12, 10)
end

local function buildTitleBar()
    local bar = W.Create(frame, "Frame")
    bar:SetPoint("TOPLEFT", 8, -6)
    bar:SetPoint("TOPRIGHT", -8, -6)
    bar:SetHeight(42)

    local icon = W.Icon(bar, 30, T.media.goblin)
    icon:SetPoint("LEFT", 4, 0)

    local title = W.Text(bar, "GOBLIN PAWN STARS", 19, T.colors.gold)
    title:SetPoint("LEFT", 42, 4)

    local subtitle = W.Text(bar, "Honest deals · mostly", 9, T.colors.goldDim)
    subtitle:SetPoint("LEFT", 44, -12)

    local close = W.Button(bar, "×", 26, 24, function()
        ns.UI.Close()
    end, "danger")
    close:SetPoint("RIGHT", -2, 0)

    local guide = W.Button(bar, "?", 24, 24, function()
        if ns.UI.Tour then
            ns.UI.Tour.Start(1)
        else
            ns.Print("The guided tour is unavailable.")
        end
    end, "gold")
    guide:SetPoint("RIGHT", close, "LEFT", -6, 0)

    local line = T.GoldLine(frame, 1)
    line:SetPoint("TOPLEFT", 12, -50)
    line:SetPoint("TOPRIGHT", -12, -50)

    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
end

local function buildWindow()
    frame = ns.Compat.CreateFrame("Frame", "GoblinPawnStarsFrame", UIParent, "BackdropTemplate")
    if not frame then return false end

    frame:SetSize(960, 640)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetToplevel(true)
    T.Decorate(frame, "window")
    restorePosition()

    if frame.SetScale then
        local scale = tonumber(DB.Get().settings.scale) or 1
        frame:SetScale(U.clamp(scale, 0.8, 1.2))
    end

    buildTitleBar()

    local content = W.Create(frame, "Frame")
    content:SetPoint("TOPLEFT", 206, -56)
    content:SetPoint("BOTTOMRIGHT", -10, 12)

    buildHeader(content)

    tabHost = W.Create(content, "Frame")
    tabHost:SetPoint("TOPLEFT", 0, -64)
    tabHost:SetPoint("BOTTOMRIGHT", 0, 0)

    buildSidebar(frame)

    frame:Hide()
    if UISpecialFrames then
        local already = false
        for _, name in ipairs(UISpecialFrames) do
            if name == "GoblinPawnStarsFrame" then already = true break end
        end
        if not already then table.insert(UISpecialFrames, "GoblinPawnStarsFrame") end
    end

    return true
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

local function getTab(id)
    local def = ns.UI.Tabs[id]
    if not def then return nil end
    if not def.frame then
        def.frame = W.Create(tabHost, "Frame")
        def.frame:SetAllPoints()
        local ok, api = pcall(def.Create, def.frame)
        if not ok then
            ns.Print("|cffff5555Tab error (" .. tostring(id) .. "):|r " .. tostring(api))
            api = {}
        end
        def.api = api or {}
    end
    return def
end

function ns.UI.ShowTab(id)
    if not ns.UI.Tabs[id] then id = "dashboard" end
    local previousTab = activeTab
    activeTab = id

    for tabId, button in pairs(tabButtons) do
        if tabId == id then
            button.selected:Show()
            if ns.Anim then ns.Anim.Pulse(button.selected, 1.08, 0.22) end
            button.bg:SetVertexColor(1, 1, 1)
            button.label:SetTextColor(T.colors.gold[1], T.colors.gold[2], T.colors.gold[3])
        else
            button.selected:Hide()
            button.label:SetTextColor(T.colors.text[1], T.colors.text[2], T.colors.text[3])
        end
    end

    for tabId, def in pairs(ns.UI.Tabs) do
        if def.frame then
            if tabId == id then def.frame:Show() else def.frame:Hide() end
        end
    end

    local def = getTab(id)
    if def and def.frame then
        def.frame:Show()
        if previousTab ~= id and ns.Anim then
            ns.Anim.Reveal(def.frame, 0.16, 0.35)
        end
        if def.api and def.api.Refresh then
            local ok, err = pcall(def.api.Refresh)
            if not ok then
                ns.RecordError("tab:" .. tostring(id), err)
                ns.Debug("refresh error on " .. id .. ": " .. tostring(err))
            end
        end
    end
end

---------------------------------------------------------------------------
-- Header refresh
---------------------------------------------------------------------------

local function refreshHeader()
    if not frame or not frame:IsShown() then return end
    local db = DB.Get()
    local summary = ns.Shop.Summary()

    header.creditsValue:SetText(U.comma(db.credits))
    if lastCredits and lastCredits ~= db.credits and ns.Anim then
        ns.Anim.Pulse(header.creditsValue, 1.12, 0.28)
    end
    lastCredits = db.credits
    local label, color = ns.Shop.ReputationLabel()
    header.repValue:SetText(string.format("%s |cff888888(%d / 1000)|r", label, math.floor(db.reputation)))
    header.repBar:SetValue(db.reputation, 1000)

    header.stockValue:SetText(string.format("%d / %d", summary.storageUsed, summary.storageMax))
    header.stockBar:SetValue(summary.storageUsed, summary.storageMax)
    if summary.storageUsed >= summary.storageMax then
        header.stockBar:SetColor(T.colors.red)
    else
        header.stockBar:SetColor(T.colors.parchment)
    end

    local waiting = #db.shop.waiting
    local traffic = ns.Customers.ArrivalBlocker() or U.clock(db.shop.nextArrival or 0)
    header.trafficValue:SetText(string.format("%s · %d waiting", traffic, waiting))
    header.dayBar:SetValue(ns.Shop.ShopDayProgress(), 1)

    local creditsPerMin, customersPerMin = ns.Throughput.Rates()
    header.rates:SetText(string.format("%s gc/min · %.1f customers/min",
        U.comma(math.floor(creditsPerMin + 0.5)), customersPerMin))

    header.clock:SetText(string.format("%s · %s", ns.Shop.TierInfo().name, U.clock(db.stats.playtime or 0)))
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function ns.UI.Open()
    if not frame then return end
    local wasShown = frame:IsShown()
    frame:Show()
    if not wasShown and ns.Anim then ns.Anim.Reveal(frame, 0.2, 0) end
    ns.UI.ShowTab(activeTab)
    refreshHeader()
end

function ns.UI.Close()
    if frame then frame:Hide() end
end

function ns.UI.Toggle()
    if not frame then return end
    if frame:IsShown() then ns.UI.Close() else ns.UI.Open() end
end

function ns.UI.IsOpen()
    return frame and frame:IsShown()
end

function ns.UI.Refresh()
    local arrival = ns.UI.CustomerArrival
    if arrival then pcall(arrival.Refresh) end
    refreshHeader()
    local def = ns.UI.Tabs[activeTab]
    if def and def.api and def.api.Refresh and frame and frame:IsShown() then
        local ok, err = pcall(def.api.Refresh)
        if not ok then
            ns.RecordError("refresh", err)
            ns.Debug("refresh error: " .. tostring(err))
        end
    end
    if ns.UI.RefreshOverlays then ns.UI.RefreshOverlays() end
    if ns.UI.Wholesaler and ns.UI.Wholesaler.Refresh then
        pcall(ns.UI.Wholesaler.Refresh)
    end
end

function ns.UI.Tick(dt)
    -- The wholesaler is a standalone window, so its timer must refresh even when
    -- the main shop window is closed.
    if ns.UI.Wholesaler and ns.UI.Wholesaler.Refresh then
        pcall(ns.UI.Wholesaler.Refresh)
    end
    if not frame or not frame:IsShown() then return end
    tickAccumulator = tickAccumulator + (dt or 0)
    if tickAccumulator < 1 then return end
    tickAccumulator = 0
    refreshHeader()

    slowAccumulator = slowAccumulator + 1
    if slowAccumulator >= 3 then
        slowAccumulator = 0
        local def = ns.UI.Tabs[activeTab]
        if def and def.api and def.api.Refresh then
            if activeTab == "dashboard" or activeTab == "deed"
                or activeTab == "market" or activeTab == "customers" then
                pcall(def.api.Refresh)
            end
        end
    end

    if ns.UI.RefreshOverlays then ns.UI.RefreshOverlays() end
end

function ns.UI.StartNegotiation(index)
    local ok, err = ns.Customers.StartNegotiation(index)
    if not ok then
        ns.Print(err or "That customer is not available.")
        return false
    end
    ns.UI.Open()
    if ns.UI.Negotiation then ns.UI.Negotiation.Show() end
    ns.UI.Refresh()
    return true
end

---------------------------------------------------------------------------
-- Toast
---------------------------------------------------------------------------

local function ensureToast()
    if toastFrame then return toastFrame end
    toastFrame = W.Panel(UIParent, "panel")
    if not toastFrame then return nil end
    toastFrame:SetSize(360, 40)
    toastFrame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    toastFrame:SetFrameStrata("DIALOG")
    toastFrame.text = W.Text(toastFrame, "", 12, T.colors.gold)
    toastFrame.text:SetPoint("LEFT", 14, 0)
    toastFrame.text:SetPoint("RIGHT", -14, 0)
    toastFrame:Hide()
    return toastFrame
end

function ns.UI.Toast(message)
    local toast = ensureToast()
    if not toast then return end
    toast.text:SetText(tostring(message or ""))
    toast:Show()
    if ns.Anim then ns.Anim.Reveal(toast, 0.18, 0) end
    if toastTimer then
        if type(toastTimer) == "userdata" and toastTimer.Cancel then
            pcall(toastTimer.Cancel, toastTimer)
        end
        toastTimer = nil
    end
    if C_Timer and C_Timer.NewTimer then
        local ok, timer = pcall(C_Timer.NewTimer, 3.4, function()
            if toastFrame then toastFrame:Hide() end
        end)
        if ok then toastTimer = timer end
    else
        ns.Compat.After(3.4, function()
            if toastFrame then toastFrame:Hide() end
        end)
    end
end

function ns.UI.ShowEncounter()
    if ns.UI.EventFrame then ns.UI.EventFrame.Show() end
end

---------------------------------------------------------------------------

local loaded = buildWindow()
if loaded then
    ns.UI.MainFrame = frame
    local arrival = ns.UI.CustomerArrival
    if arrival and frame.HookScript then
        local function positionArrival()
            pcall(arrival.Position)
        end
        pcall(frame.HookScript, frame, "OnShow", positionArrival)
        pcall(frame.HookScript, frame, "OnHide", positionArrival)
    end
    ns.UI.ShowTab("dashboard")
end
