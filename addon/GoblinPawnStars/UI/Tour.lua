--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Tour.lua
    A spotlight-style guided tour. It dims everything except the current
    target, explains one idea per step, and moves the player through the tabs
    in the same order they should play them.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local T = ns.Theme
local W = ns.Widgets
local DB = ns.DB

local frame, card
local stepLabel, titleText, bodyText, hintText
local nextButton, backButton, skipButton
local shades, edges, dots = {}, {}, {}
local index = 1
local active = false

local Tour = {}

local STEPS = {
    {
        title = "This is your shop now.",
        body = "Goblin Pawn Stars runs entirely inside the addon: the loot, the customers, the credits and the haggling are all fictional. Your real bags and gold are never touched. This tour takes about a minute.",
        hint = "Use Next and Back, or Skip. Replay any time with /gps guide.",
    },
    {
        title = "The four numbers that matter",
        body = "Goblin Credits are your wallet. Reputation unlocks better customers and improves haggling. Stock is what is on the shelves. Next customer is the arrival timer, the queue sits beside it, and the bottom line shows credits and customers per minute.",
        hint = "The header is always visible, whichever tab you are on.",
        target = "header",
    },
    {
        title = "Everything lives in the tabs",
        body = "Dashboard is the overview and your next objective. The Deed holds the cartel debt, museum and Marta. Customers holds the queue. Inventory is your virtual stock. Market shows demand. Upgrades and Employees spend the profits.",
        hint = "Click any tab at any time. The tour will not lock you out.",
        target = "sidebar",
    },
    {
        title = "Loot becomes stock",
        body = "Anything you loot in the world appears here as a virtual copy. When the shelves run dry, the Wholesaler sells bulk lots for credits. Customers wander in while the shop is open, pick something they like, and make an offer. The daily request category pays a bonus on the first matching sale.",
        hint = "Already carrying loot? Click Stock Bags Now on the Dashboard to import it.",
        tab = "customers",
        target = "customers",
    },
    {
        title = "Haggle like a goblin",
        body = "Accept takes the offer straight away. Reject ends the visit. Make Counteroffer risks their patience for a better price. Appraise reveals the value range and exposes forgeries. Rare collectors pay well over the odds.",
        hint = "A customer's true ceiling is hidden. Patience runs out one round at a time.",
        tab = "customers",
    },
    {
        title = "Reinvest the profit",
        body = "Upgrades add storage, traffic, security and haggling power. Employees add bonuses but charge wages. A salesperson works the waiting queue automatically at a lower margin, so the shop can keep selling while you are busy. Rent and wages are due every shop day, which is 15 minutes of playtime.",
        hint = "Storage first, then traffic and haggling; hire a salesperson once tier 2 unlocks slots.",
        tab = "upgrades",
        target = "upgrades",
    },
    {
        title = "There is always a next step",
        body = "The Next Up card on the dashboard always points at the most useful next action. After the starter goals, the cartel's three payments, the museum and Marta take over. Pay the ledger, choose an ending, then keep the shop open or open a franchise.",
        hint = "Progress is checkpointed automatically to macro bodies on the beta client. Manual backups still live in Settings > Backup & Restore.",
        tab = "dashboard",
        target = "goal",
    },
}

local function targetFor(key)
    if key == "header" then
        return ns.UI.Header and ns.UI.Header.frame
    elseif key == "sidebar" then
        return ns.UI.Sidebar
    elseif key == "goal" then
        local api = ns.UI.Tabs.dashboard and ns.UI.Tabs.dashboard.api
        return api and api.goalCard
    end
    return ns.UI.TabButtons and ns.UI.TabButtons[key]
end

local function hideHighlight()
    for _, texture in ipairs(shades) do texture:Hide() end
    for _, texture in ipairs(edges) do texture:Hide() end
end

local function layout(target)
    local width = frame:GetWidth() or 0
    local height = frame:GetHeight() or 0

    local x1, x2, y1, y2
    if target and target.GetLeft and target.GetTop and target:IsShown() then
        local tx = target:GetLeft()
        local ty = target:GetTop()
        local tw = target:GetWidth() or 0
        local th = target:GetHeight() or 0
        if tx and ty and tw > 4 and th > 4 then
            local ox = frame:GetLeft() or 0
            local oy = frame:GetBottom() or 0
            x1 = tx - ox - 4
            x2 = x1 + tw + 8
            y2 = ty - oy + 4
            y1 = y2 - th - 8
        end
    end

    if not x1 then
        hideHighlight()
        return
    end

    x1 = math.max(0, math.min(x1, width - 8))
    x2 = math.max(x1 + 8, math.min(x2, width))
    y1 = math.max(0, math.min(y1, height - 8))
    y2 = math.max(y1 + 8, math.min(y2, height))

    shades[1]:ClearAllPoints()
    shades[1]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, y2)
    shades[1]:SetSize(width, math.max(0, height - y2))

    shades[2]:ClearAllPoints()
    shades[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    shades[2]:SetSize(width, y1)

    shades[3]:ClearAllPoints()
    shades[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, y1)
    shades[3]:SetSize(x1, y2 - y1)

    shades[4]:ClearAllPoints()
    shades[4]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x2, y1)
    shades[4]:SetSize(math.max(0, width - x2), y2 - y1)

    for _, texture in ipairs(shades) do texture:Show() end

    edges[1]:ClearAllPoints()
    edges[1]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x1, y2 - 2)
    edges[1]:SetSize(x2 - x1, 2)
    edges[2]:ClearAllPoints()
    edges[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x1, y1)
    edges[2]:SetSize(x2 - x1, 2)
    edges[3]:ClearAllPoints()
    edges[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x1, y1)
    edges[3]:SetSize(2, y2 - y1)
    edges[4]:ClearAllPoints()
    edges[4]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x2 - 2, y1)
    edges[4]:SetSize(2, y2 - y1)
    for _, texture in ipairs(edges) do texture:Show() end
end

local function showStep()
    local step = STEPS[index]
    if not step then return end

    if step.tab and ns.UI.ShowTab then ns.UI.ShowTab(step.tab) end
    local target = step.target and targetFor(step.target) or nil

    stepLabel:SetText(string.format("GUIDED TOUR · STEP %d OF %d", index, #STEPS))
    titleText:SetText(step.title)
    bodyText:SetText(step.body)
    hintText:SetText(step.hint or "")
    nextButton:SetLabel(index == #STEPS and "Finish" or "Next")
    backButton:SetState(index > 1)

    for dotIndex, dot in ipairs(dots) do
        dot:SetAlpha(dotIndex <= index and 1 or 0.22)
    end

    layout(target)
    if ns.Anim then ns.Anim.Reveal(card, 0.16, 0.3) end
end

local function markSeen()
    local db = DB.Get()
    db.settings.tourDone = true
    db.settings.tourVersion = ns.VERSION
end

local function build()
    frame = ns.Compat.CreateFrame("Frame", "GoblinPawnStarsTourFrame", UIParent)
    if not frame then return end
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    if frame.SetFrameLevel then frame:SetFrameLevel(250) end
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function() end)

    for index2 = 1, 4 do
        local texture = frame:CreateTexture(nil, "BACKGROUND")
        T.Fill(texture, 0, 0, 0, 0.62)
        texture:Hide()
        shades[index2] = texture

        local edge = frame:CreateTexture(nil, "OVERLAY")
        T.Fill(edge, 0.94, 0.78, 0.33, 0.95)
        edge:Hide()
        edges[index2] = edge
    end

    card = W.Panel(frame, "window")
    card:SetSize(430, 236)
    card:SetPoint("CENTER", UIParent, "CENTER", 150, 0)
    card:SetFrameStrata("FULLSCREEN_DIALOG")

    stepLabel = W.Text(card, "GUIDED TOUR", 9, T.colors.goldDim)
    stepLabel:SetPoint("TOPLEFT", 16, -12)
    stepLabel:SetPoint("TOPRIGHT", -16, -12)

    titleText = W.Text(card, "", 18, T.colors.gold)
    titleText:SetPoint("TOPLEFT", 16, -28)
    titleText:SetPoint("TOPRIGHT", -16, -28)
    titleText:SetHeight(24)

    bodyText = W.Text(card, "", 11, T.colors.parchment)
    bodyText:SetPoint("TOPLEFT", 16, -58)
    bodyText:SetPoint("TOPRIGHT", -16, -58)
    bodyText:SetHeight(96)
    bodyText:SetWordWrap(true)
    bodyText:SetSpacing(3)

    hintText = W.Text(card, "", 9, T.colors.muted)
    hintText:SetPoint("TOPLEFT", 16, -160)
    hintText:SetPoint("TOPRIGHT", -16, -160)
    hintText:SetHeight(26)
    hintText:SetWordWrap(true)

    for dotIndex = 1, #STEPS do
        local dot = card:CreateTexture(nil, "ARTWORK")
        T.Fill(dot, 0.94, 0.78, 0.33, 1)
        dot:SetSize(7, 7)
        dot:SetPoint("BOTTOMLEFT", 16 + (dotIndex - 1) * 12, 54)
        dots[dotIndex] = dot
    end

    skipButton = W.Button(card, "Skip", 74, 28, function()
        Tour.Stop(true)
    end, "neutral")
    skipButton:SetPoint("BOTTOMLEFT", 16, 16)

    backButton = W.Button(card, "Back", 88, 30, function()
        Tour.Back()
    end, "neutral")
    backButton:SetPoint("BOTTOMRIGHT", -142, 15)

    nextButton = W.Button(card, "Next", 120, 30, function()
        Tour.Next()
    end, "primary")
    nextButton:SetPoint("BOTTOMRIGHT", -16, 15)

    frame:Hide()

    frame:SetScript("OnHide", function()
        if active then
            active = false
            markSeen()
        end
        hideHighlight()
    end)

    if UISpecialFrames then
        local exists = false
        for _, name in ipairs(UISpecialFrames) do
            if name == "GoblinPawnStarsTourFrame" then exists = true break end
        end
        if not exists then table.insert(UISpecialFrames, "GoblinPawnStarsTourFrame") end
    end
end

build()

function Tour.Start(step)
    if not frame then return end
    if ns.UI.Open then ns.UI.Open() end
    active = true
    index = math.max(1, math.min(#STEPS, math.floor(tonumber(step) or 1)))
    frame:Show()
    showStep()
end

function Tour.Next()
    if not active then return end
    if index < #STEPS then
        index = index + 1
        showStep()
    else
        Tour.Stop(true)
    end
end

function Tour.Back()
    if not active or index <= 1 then return end
    index = index - 1
    showStep()
end

function Tour.Stop(mark)
    active = false
    if frame then frame:Hide() end
    hideHighlight()
    if mark ~= false then
        markSeen()
        if ns.UI.Refresh then ns.UI.Refresh() end
    end
end

function Tour.IsActive()
    return active and frame and frame:IsShown() or false
end

function Tour.Index()
    return index
end

Tour.Steps = #STEPS

ns.UI.Tour = Tour
