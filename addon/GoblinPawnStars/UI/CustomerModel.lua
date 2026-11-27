-- Goblin Pawn Stars: load customer appearances from the client's own models.
local ADDON, ns = ...
local C = ns.Compat
local M = {}
ns.UI.CustomerModel = M

-- Creature display IDs for common vendors and townsfolk. Names select a stable
-- appearance across the arrival, queue, and negotiation. The last two races
-- use creature IDs because their vendors entered the game in later expansions.
local displays = {
    Goblin = { 7094, 7096, 7054 },
    Dwarf = { 3047, 2790 },
    Orc = { 1312, 1384 },
    Human = { 3269, 5074 },
    Troll = { 4362 },
    BloodElf = { 16713, 16705, 16691 },
    Undead = { 2662, 2629 },
    Tauren = { 3801, 2140 },
    NightElf = { 2233 },
    Gnome = { 7038, 7039 },
    Draenei = { 16699 },
}
local creatures = {
    Pandaren = { 54586, 59608 },
    Vulpera = { 128101, 135446 },
}
local defaultDisplay = 7094
local martaDisplay = 7969
local stand, walk = 0, 4

local function set(model, method, ...)
    if not C.HasMethod(model, method) then return false end
    local ok, result = pcall(model[method], model, ...)
    return ok and result ~= false
end

local function appearance(customer)
    if customer.regular then return "SetDisplayInfo", martaDisplay end
    local variants = displays[customer.race]
    local method = "SetDisplayInfo"
    if not variants then
        variants = creatures[customer.race] or displays.Goblin
        if creatures[customer.race] then method = "SetCreature" end
    end
    return method, variants[ns.Util.hash(customer.name) % #variants + 1]
end

function M.Attach(parent, icon, zoom)
    local model = C.CreateFrame("PlayerModel", nil, parent)
    if not C.HasMethod(model, "SetDisplayInfo") then return nil end
    model:SetPoint("TOPLEFT", parent, "TOPLEFT", 3, -3)
    model:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -3, 3)
    model:SetAlpha(0)
    model:EnableMouse(false)
    set(model, "SetKeepModelOnHide", true)

    local widget = {}
    local selectedMethod, selectedID, displayID, loadedCallback
    local generation = 0
    local loading, ready = false, false
    local visible = true

    function widget:SetWalking(walking)
        if not ready then return end
        set(model, "SetRotation", walking and -1.05 or -0.25, false)
        set(model, "SetAnimation", walking and walk or stand, 0)
    end

    function widget:SetVisible(shown)
        visible = shown and true or false
        if visible then
            model:Show()
            if ready then icon:Hide() end
        else
            model:Hide()
            icon:Show()
        end
    end

    local function reveal(fromEvent)
        if not loading then return end
        local fileID = C.Call(model.GetModelFileID, model)
        if type(fileID) == "number" then
            if fileID <= 0 then return end
        elseif not fromEvent then
            return
        end

        local reportedDisplay = C.Call(model.GetDisplayInfo, model)
        if displayID and type(reportedDisplay) == "number"
            and reportedDisplay > 0 and reportedDisplay ~= displayID then return end

        loading, ready = false, true
        set(model, "RefreshCamera")
        set(model, "SetPortraitZoom", zoom)
        widget:SetWalking(false)
        model:SetAlpha(1)
        widget:SetVisible(visible)
        if visible and loadedCallback then
            local callback = loadedCallback
            loadedCallback = nil
            local ok, err = pcall(callback, widget)
            if not ok then ns.Debug("customer model animation: " .. tostring(err)) end
        end
    end

    set(model, "SetScript", "OnModelLoaded", function() reveal(true) end)

    local function load(method, id)
        loading = false
        set(model, "ClearModel")
        loading = true
        displayID = method == "SetDisplayInfo" and id or nil
        if not set(model, method, id) then
            loading = false
            return false
        end
        reveal(false)
        return true
    end

    function widget:SetCustomer(customer, callback)
        local method, id = appearance(customer)
        loadedCallback = callback
        if method == selectedMethod and id == selectedID then
            if ready and callback then
                loadedCallback = nil
                callback(self)
            end
            return
        end
        selectedMethod, selectedID = method, id
        generation = generation + 1
        local request = generation
        ready = false
        model:SetAlpha(0)
        icon:Show()
        model:Show()

        if not load(method, id) and id ~= defaultDisplay then
            load("SetDisplayInfo", defaultDisplay)
        end
        if ready then return end

        -- Some clients defer the file ID until the frame becomes visible.
        -- Keep the icon until the native model is ready.
        C.After(0.25, function()
            if generation == request then reveal(false) end
        end)
        if id ~= defaultDisplay then
            C.After(0.9, function()
                if generation ~= request or ready then return end
                reveal(false)
                if not ready then load("SetDisplayInfo", defaultDisplay) end
            end)
        end
    end

    return widget
end
