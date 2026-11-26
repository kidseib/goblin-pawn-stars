--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/OptionsPanel.lua
    Modern client integration: a Blizzard Settings category and an Addon
    Compartment entry. Both are optional and silently skipped when the client
    (or a future Forever build) does not expose them.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local T = ns.Theme
local W = ns.Widgets
local DB = ns.DB

local panel
local soundButton
local minimapButton
local welcomeButton

local function refresh()
    if not panel then return end
    local db = DB.Get()
    local soundOn = db.settings.sound ~= false
    local minimapOn = db.settings.minimap ~= false
    if soundButton then
        soundButton:SetLabel("Sound: " .. (soundOn and "On" or "Off"))
        soundButton:SetTone(soundOn and "primary" or "neutral")
    end
    if minimapButton then
        minimapButton:SetLabel("Minimap: " .. (minimapOn and "On" or "Off"))
        minimapButton:SetTone(minimapOn and "primary" or "neutral")
    end
end

local function buildPanel()
    if panel then return panel end

    panel = W.Create(UIParent, "Frame")
    panel:SetSize(620, 400)
    panel.name = "Goblin Pawn Stars"

    local title = W.Text(panel, "Goblin Pawn Stars", 19, T.colors.gold)
    title:SetPoint("TOPLEFT", 10, -10)

    local subtitle = W.Text(panel,
        "A pawnshop empire in your bags · v" .. ns.VERSION ..
        " · Created by ErrorSeib & Buffy (Codebuff)",
        10, T.colors.muted)
    subtitle:SetPoint("TOPLEFT", 10, -36)
    subtitle:SetPoint("TOPRIGHT", -10, -36)

    local line = T.GoldLine(panel, 1)
    line:SetPoint("TOPLEFT", 10, -58)
    line:SetPoint("TOPRIGHT", -10, -58)

    local body = W.Text(panel,
        "Loot items to stock the shop, haggle with procedural customers, and spend Goblin Credits on storage, staff and five shop tiers. " ..
        "Everything is fictional: the addon never touches your real bags, gold or the game world.",
        11, T.colors.parchment)
    body:SetPoint("TOPLEFT", 10, -70)
    body:SetPoint("TOPRIGHT", -10, -70)
    body:SetHeight(54)
    body:SetWordWrap(true)
    body:SetSpacing(3)

    local openShop = W.Button(panel, "Open the Shop", 160, 30, function()
        ns.UI.Open()
    end, "primary")
    openShop:SetPoint("TOPLEFT", 10, -134)

    welcomeButton = W.Button(panel, "Show Welcome", 160, 30, function()
        if ns.UI.Welcome then ns.UI.Welcome.Show() end
    end, "gold")
    welcomeButton:SetPoint("TOPLEFT", 180, -134)

    local diagnostics = W.Button(panel, "Run Diagnostics", 160, 30, function()
        ns.Diagnostics.Report()
    end, "neutral")
    diagnostics:SetPoint("TOPLEFT", 350, -134)

    soundButton = W.Button(panel, "Sound: On", 160, 30, function()
        local db = DB.Get()
        db.settings.sound = not (db.settings.sound ~= false)
        refresh()
        if ns.Sound then ns.Sound.Play("open") end
    end, "primary")
    soundButton:SetPoint("TOPLEFT", 10, -172)

    minimapButton = W.Button(panel, "Minimap: On", 160, 30, function()
        local db = DB.Get()
        db.settings.minimap = not (db.settings.minimap ~= false)
        if ns.UI.UpdateMinimap then ns.UI.UpdateMinimap() end
        refresh()
    end, "primary")
    minimapButton:SetPoint("TOPLEFT", 180, -172)

    local settingsTab = W.Button(panel, "Full Settings", 160, 30, function()
        if ns.UI.ShowTab then
            ns.UI.ShowTab("settings")
            ns.UI.Open()
        end
    end, "gold")
    settingsTab:SetPoint("TOPLEFT", 350, -172)

    local backupNote = W.Text(panel,
        "|cff9c8a5aSaving:|r the current Forever beta writes SavedVariables but does not load them. " ..
        "The Deed tab checkpoints progress into macro bodies automatically; Settings → Backup & Restore still provides a full copy-paste backup.",
        10, T.colors.muted)
    backupNote:SetPoint("TOPLEFT", 10, -216)
    backupNote:SetPoint("TOPRIGHT", -10, -216)
    backupNote:SetHeight(44)
    backupNote:SetWordWrap(true)

    local footer = W.Text(panel,
        "Slash commands: |cffffffff/gps|r, |cffffffff/goblinpawnstars|r · |cffffffff/gps test|r for diagnostics",
        9, T.colors.dim)
    footer:SetPoint("BOTTOMLEFT", 10, 10)
    footer:SetPoint("BOTTOMRIGHT", -10, 10)

    panel:SetScript("OnShow", refresh)
    panel:Hide()
    refresh()
    return panel
end

local function registerSettings()
    if not (Settings and type(Settings.RegisterCanvasLayoutCategory) == "function"
        and type(Settings.RegisterAddOnCategory) == "function") then
        return false
    end
    local canvas = buildPanel()
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, canvas, "Goblin Pawn Stars")
    if not ok or not category then return false end
    local registered = pcall(Settings.RegisterAddOnCategory, category)
    if not registered then return false end
    ns.UI.optionsCategory = category
    return true
end

--[[ Addon Compartment ----------------------------------------------------
    Registered through TOC metadata (## AddonCompartmentFunc and friends), which
    is the officially supported route and works even when the compartment frame
    is created later by Blizzard_Minimap. These must be globals.
--------------------------------------------------------------------------- ]]

function GoblinPawnStars_CompartmentClick(addonName, buttonInfo)
    if ns.UI and ns.UI.Toggle then ns.UI.Toggle() end
end

function GoblinPawnStars_CompartmentEnter(addonName, menuButtonFrame)
    if not GameTooltip then return end
    GameTooltip:SetOwner(menuButtonFrame or UIParent, "ANCHOR_RIGHT")
    GameTooltip:SetText("Goblin Pawn Stars", 0.94, 0.78, 0.33)
    GameTooltip:AddLine("Open the pawnshop.", 0.91, 0.85, 0.69)
    local summary = ns.Shop.Summary()
    GameTooltip:AddLine(string.format("%s · %d waiting", summary.tierName, summary.customersWaiting), 0.62, 0.58, 0.47)
    GameTooltip:Show()
end

function GoblinPawnStars_CompartmentLeave()
    ns.Compat.HideTooltip()
end

ns.UI.RegisteredOptions = registerSettings()
ns.UI.CompartmentMode = "toc-metadata"

function ns.UI.OpenOptions()
    local category = ns.UI.optionsCategory
    if category and Settings and type(Settings.OpenToCategory) == "function" then
        local candidates = {}
        local okId, id = pcall(function() return category:GetID() end)
        if okId and id then candidates[#candidates + 1] = id end
        if category.ID then candidates[#candidates + 1] = category.ID end
        for _, candidate in ipairs(candidates) do
            local ok = pcall(Settings.OpenToCategory, candidate)
            if ok then return true end
        end
    end
    if ns.UI.ShowTab then
        ns.UI.ShowTab("settings")
        ns.UI.Open()
    end
    return false
end
