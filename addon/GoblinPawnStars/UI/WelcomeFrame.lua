--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/WelcomeFrame.lua
    The splash screen. First launch gets the three-beat introduction; a new
    addon version gets a "what's new" card instead. Both routes can launch the
    guided tour, and both credit the authors.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local T = ns.Theme
local W = ns.Widgets
local DB = ns.DB

local frame
local title, subtitle, intro, note
local firstPanel, updatePanel, updateTitle
local tourButton, loginButton, watermark
local currentMode = "first"

local CREDITS = "Created by |cffffd700ErrorSeib|r & |cff7bd66bBuffy|r |cff9c8a5a(Codebuff)|r"

local STEPS = {
    {
        icon = "Interface\\Icons\\INV_Misc_Bag_08",
        title = "1. Stock the shelves",
        text = "Loot anything, or buy bulk lots from the wholesaler. A virtual copy appears in the shop — your real bags are never touched.",
    },
    {
        icon = "Interface\\Icons\\INV_Misc_Coin_02",
        title = "2. Haggle",
        text = "Customers make offers based on taste, budget and reputation. Accept, reject, or counter. A salesperson can work the queue while you are busy.",
    },
    {
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        title = "3. Build an empire",
        text = "Spend Goblin Credits on storage, staff, security and four bigger shop tiers. Rent and wages are due every shop day.",
    },
}

local WHATS_NEW = {
    ["1.6.0"] = {
        "Customer waits are twice as long in Fast, Normal and Relaxed.",
        "Turn on Questing auto-sell in Settings to serve the queue while you are away from the shop.",
        "Questing auto-sell pays one-third of the best possible manual deal.",
    },
    ["1.5.0"] = {
        "Customers walk in with native WoW models. Drag the arrival card to move it.",
        "Adjust arrival pace and notification style in Settings.",
        "Negotiation dialogue is easier to read, and the header shows what is holding up arrivals.",
    },
    ["1.4.0"] = {
        "The Deed: three cartel payments with a real ending, plus endless mode and franchise prestige.",
        "The Curious Collection: a five-slot museum set that permanently improves offers.",
        "Marta Copperpin: a named regular with three story visits and a permanent referral bonus.",
        "Progress now checkpoints into macro bodies automatically, so a beta logout no longer loses the campaign.",
    },
    ["1.3.0"] = {
        "Credits/min and customers/min are now visible in the header and dashboard.",
        "The Goblin Wholesaler sells three rotating bulk lots for credits — buy low, sell high.",
        "The salesperson now auto-sells queued customers at a lower margin instead of one hidden shop-day roll.",
        "Tier 1 traffic is about five times faster and starts with two waiting slots, so the first half hour actually moves.",
    },
    ["1.2.0"] = {
        "Guided tour: a spotlight walks you through the counter, haggling and upgrades.",
        "Animated windows, tabs, toasts and a splash screen that actually splashes.",
        "A Next Up card on the dashboard that always points at the most useful next move.",
        "First-launch and update screens, replayable any time with /gps guide.",
    },
}

local function whatsNew()
    return WHATS_NEW[ns.VERSION] or {
        "Polish, fixes and a smoother first ten minutes.",
        "Replay the guided tour from the splash screen or with /gps guide.",
    }
end

local function refresh()
    local db = DB.Get()
    if loginButton then
        local enabled = db.settings.showWelcome ~= false
        loginButton:SetLabel("Show on updates: " .. (enabled and "On" or "Off"))
        loginButton:SetTone(enabled and "primary" or "neutral")
    end
end

local function buildFirstPanel(parent)
    local panel = W.Create(parent, "Frame")
    panel:SetPoint("TOPLEFT", 20, -150)
    panel:SetPoint("TOPRIGHT", -20, -150)
    panel:SetHeight(150)

    local width = 190
    for index, step in ipairs(STEPS) do
        local card = W.Panel(panel, "inset")
        card:SetSize(width, 150)
        card:SetPoint("TOPLEFT", (index - 1) * (width + 15), 0)

        local icon = W.Icon(card, 32, step.icon)
        icon:SetPoint("TOPLEFT", 10, -10)

        local stepTitle = W.Text(card, step.title, 12, T.colors.gold)
        stepTitle:SetPoint("TOPLEFT", 10, -50)
        stepTitle:SetPoint("TOPRIGHT", -10, -50)

        local stepText = W.Text(card, step.text, 10, T.colors.parchment)
        stepText:SetPoint("TOPLEFT", 10, -68)
        stepText:SetPoint("BOTTOMRIGHT", -10, 8)
        stepText:SetWordWrap(true)
        stepText:SetSpacing(2)
    end
    return panel
end

local function buildUpdatePanel(parent)
    local panel = W.Panel(parent, "inset")
    panel:SetPoint("TOPLEFT", 20, -150)
    panel:SetPoint("TOPRIGHT", -20, -150)
    panel:SetHeight(150)

    updateTitle = W.Text(panel, "WHAT'S NEW IN v" .. ns.VERSION, 11, T.colors.gold)
    updateTitle:SetPoint("TOPLEFT", 14, -12)
    updateTitle:SetPoint("TOPRIGHT", -14, -12)

    local lines = whatsNew()
    for index = 1, 4 do
        local line = W.Text(panel, "", 11, T.colors.parchment)
        line:SetPoint("TOPLEFT", 14, -36 - (index - 1) * 24)
        line:SetPoint("TOPRIGHT", -14, -36 - (index - 1) * 24)
        line:SetHeight(22)
        line:SetWordWrap(true)
        if lines[index] then
            line:SetText("|cffffd700·|r " .. lines[index])
            line:Show()
        else
            line:Hide()
        end
    end
    return panel
end

local function build()
    frame = ns.Compat.CreateFrame("Frame", "GoblinPawnStarsWelcomeFrame", UIParent, "BackdropTemplate")
    if not frame then return end

    frame:SetSize(620, 520)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetToplevel(true)
    T.Decorate(frame, "window")
    frame:SetPoint("CENTER")

    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self:StartMoving() end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
    end)

    watermark = frame:CreateTexture(nil, "ARTWORK")
    watermark:SetTexture(T.media.coin)
    watermark:SetSize(120, 120)
    watermark:SetPoint("TOPRIGHT", -24, -18)
    watermark:SetAlpha(0.12)
    if ns.Anim then ns.Anim.Spin(watermark, 16) end

    local icon = W.Icon(frame, 44, T.media.goblin)
    icon:SetPoint("TOPLEFT", 18, -16)

    title = W.Text(frame, "WELCOME TO THE PAWN SHOP", 20, T.colors.gold)
    title:SetPoint("TOPLEFT", 74, -16)
    title:SetPoint("TOPRIGHT", -130, -16)

    local credits = W.Text(frame, CREDITS, 10, T.colors.muted)
    credits:SetPoint("TOPLEFT", 74, -42)
    credits:SetPoint("TOPRIGHT", -130, -42)

    local version = W.Text(frame, "v" .. ns.VERSION, 10, T.colors.goldDim)
    version:SetPoint("TOPRIGHT", -42, -18)
    version:SetJustifyH("RIGHT")

    local close = W.Button(frame, "×", 24, 22, function()
        ns.UI.Welcome.Hide()
    end, "danger")
    close:SetPoint("TOPRIGHT", -12, -14)

    local line = T.GoldLine(frame, 1)
    line:SetPoint("TOPLEFT", 16, -68)
    line:SetPoint("TOPRIGHT", -16, -68)

    subtitle = W.Text(frame, "YOUR SHOP. YOUR RULES. YOUR PROFIT.", 13, T.colors.gold)
    subtitle:SetPoint("TOPLEFT", 20, -78)
    subtitle:SetPoint("TOPRIGHT", -20, -78)

    intro = W.Text(frame,
        "A goblin stall, a sack of other people's loot, and a very flexible definition of 'fair price'. " ..
        "Everything is simulated: no real gold, no real inventory, no automation.",
        11, T.colors.parchment)
    intro:SetPoint("TOPLEFT", 20, -102)
    intro:SetPoint("TOPRIGHT", -20, -102)
    intro:SetHeight(38)
    intro:SetWordWrap(true)
    intro:SetSpacing(3)

    firstPanel = buildFirstPanel(frame)
    updatePanel = buildUpdatePanel(frame)

    note = W.Text(frame,
        "Type |cffffffff/gps|r any time to open the shop. Replay this tour with |cffffffff/gps guide|r. " ..
        "Sound, window scale and a copy-paste backup live in Settings.",
        9, T.colors.muted)
    note:SetPoint("TOPLEFT", 20, -312)
    note:SetPoint("TOPRIGHT", -20, -312)
    note:SetHeight(30)
    note:SetWordWrap(true)

    tourButton = W.Button(frame, "Take the 60-Second Tour", 236, 36, function()
        ns.UI.Welcome.Hide()
        ns.UI.Open()
        if ns.UI.Tour then ns.UI.Tour.Start(1) end
    end, "primary")
    tourButton:SetPoint("BOTTOMLEFT", 20, 80)

    local openButton = W.Button(frame, "Open the Shop", 150, 36, function()
        ns.UI.Welcome.Hide()
        ns.UI.Open()
        ns.UI.ShowTab("dashboard")
    end, "gold")
    openButton:SetPoint("BOTTOMLEFT", 264, 80)

    local laterButton = W.Button(frame, "Later", 90, 36, function()
        ns.UI.Welcome.Hide()
    end, "neutral")
    laterButton:SetPoint("BOTTOMLEFT", 422, 80)

    loginButton = W.Button(frame, "Show on updates: On", 200, 26, function()
        local db = DB.Get()
        db.settings.showWelcome = not (db.settings.showWelcome ~= false)
        refresh()
        if ns.Sound then ns.Sound.Play("open") end
    end, "primary")
    loginButton:SetPoint("BOTTOMLEFT", 20, 42)

    local footVersion = W.Text(frame,
        "Goblin Pawn Stars v" .. ns.VERSION .. " · Interface " .. ns.INTERFACE,
        9, T.colors.dim)
    footVersion:SetPoint("BOTTOMRIGHT", -20, 46)
    footVersion:SetJustifyH("RIGHT")

    frame:Hide()

    frame:SetScript("OnHide", function()
        local db = DB.Get()
        db.settings.welcomeVersion = ns.VERSION
    end)

    if UISpecialFrames then
        local exists = false
        for _, name in ipairs(UISpecialFrames) do
            if name == "GoblinPawnStarsWelcomeFrame" then exists = true break end
        end
        if not exists then table.insert(UISpecialFrames, "GoblinPawnStarsWelcomeFrame") end
    end
end

build()

ns.UI.Welcome = {
    mode = "first",
    -- mode is "first" on a fresh save and "update" when a previous version was
    -- already seen. Both routes can start the guided tour.
    Show = function(mode)
        if not frame then return end
        local db = DB.Get()
        mode = mode or (db.settings.welcomeVersion and "update" or "first")
        if mode ~= "update" then mode = "first" end
        currentMode = mode
        ns.UI.Welcome.mode = mode

        if firstPanel then firstPanel:SetShown(mode == "first") end
        if updatePanel then updatePanel:SetShown(mode == "update") end
        title:SetText(mode == "update" and "GOBLIN PAWN STARS" or "WELCOME TO THE PAWN SHOP")
        subtitle:SetText(mode == "update" and ("WHAT'S NEW IN v" .. ns.VERSION)
            or "YOUR SHOP. YOUR RULES. YOUR PROFIT.")
        tourButton:SetLabel(mode == "update" and "Take the Tour" or "Take the 60-Second Tour")
        refresh()

        frame:Show()
        if ns.Anim then ns.Anim.Reveal(frame, 0.3, 0) end
    end,
    Hide = function()
        if not frame then return end
        frame:Hide()
        local db = DB.Get()
        db.settings.welcomeVersion = ns.VERSION
    end,
    -- Shows once per addon version unless the player switched it off.
    MaybeShow = function()
        local db = DB.Get()
        if db.settings.showWelcome == false then return end
        if db.settings.welcomeVersion == ns.VERSION then return end
        ns.UI.Welcome.Show(db.settings.welcomeVersion and "update" or "first")
    end,
    IsShown = function()
        return frame and frame:IsShown() or false
    end,
    Mode = function()
        return currentMode
    end,
}

ns.Compat.EventFrame({
    PLAYER_LOGIN = function()
        ns.Compat.After(3, function()
            if ns.UI.Welcome then ns.UI.Welcome.MaybeShow() end
        end)
    end,
})
