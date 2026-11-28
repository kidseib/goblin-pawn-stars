--[[ Headless mock of the World of Warcraft addon environment.
     Used only by tools/run_tests.js (fengari). It is intentionally permissive:
     widgets are tables whose unknown methods are no-ops, but the handful of
     getters the addon actually branches on return real values.
--------------------------------------------------------------------------- ]]

unpack = unpack or table.unpack
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local function makeObject(kind)
    local object = {
        __kind = kind,
        __text = "",
        __shown = true,
        __width = 400,
        __height = 300,
        __scripts = {},
        __points = {},
    }

    local methods = {}

    function methods:SetScript(name, fn) self.__scripts[name] = fn end
    function methods:GetScript(name) return self.__scripts[name] end
    function methods:Show() self.__shown = true end
    function methods:Hide() self.__shown = false end
    function methods:SetShown(shown) self.__shown = shown and true or false end
    function methods:IsShown() return self.__shown end
    function methods:SetText(text) self.__text = tostring(text or "") end
    function methods:GetText() return self.__text end
    function methods:SetWidth(width) self.__width = tonumber(width) or self.__width end
    function methods:SetHeight(height) self.__height = tonumber(height) or self.__height end
    function methods:SetSize(width, height)
        self.__width = tonumber(width) or self.__width
        self.__height = tonumber(height) or self.__height
    end
    function methods:GetWidth() return self.__width end
    function methods:GetHeight() return self.__height end
    -- Simple origin-based geometry so layout code can be smoke-tested. The
    -- mock does not resolve anchors; every frame starts at the bottom-left.
    function methods:GetLeft() return 0 end
    function methods:GetRight() return self.__width end
    function methods:GetTop() return self.__height end
    function methods:GetBottom() return 0 end
    function methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
    function methods:SetPoint(point, ...)
        self.__points[#self.__points + 1] = { point = point, ... }
    end
    function methods:GetVerticalScroll() return 0 end
    function methods:GetHorizontalScroll() return 0 end
    function methods:GetEffectiveScale() return 1 end
    function methods:GetScale() return 1 end
    function methods:GetCenter() return 0, 0 end
    function methods:GetName() return "Mock" .. tostring(kind) end
    function methods:GetFont() return { path = "MockFont" } end
    function methods:GetFontObject() return {} end
    function methods:IsObjectType() return true end
    function methods:GetObjectType() return kind end
    function methods:CreateTexture() return makeObject("Texture") end
    function methods:CreateFontString() return makeObject("FontString") end
    function methods:CreateAnimationGroup() return makeObject("AnimationGroup") end
    function methods:SetBackdrop() return true end
    function methods:GetNumPoints() return #self.__points end
    function methods:SetFocus() self.__focused = true end
    function methods:ClearFocus() self.__focused = false end
    function methods:GetAlpha() return 1 end
    function methods:SetAlpha() end
    function methods:HighlightText() end
    function methods:SetCursor() end
    function methods:SetFrameStrata() end
    function methods:SetToplevel() end
    function methods:SetClampedToScreen() end
    function methods:SetMovable() end
    function methods:StartMoving() end
    function methods:StopMovingOrSizing() end
    function methods:EnableMouse() end
    function methods:EnableMouseWheel() end
    function methods:RegisterForClicks() end
    function methods:RegisterForDrag() end
    function methods:RegisterEvent() return true end
    function methods:UnregisterEvent() return true end
    function methods:SetScrollChild() end
    function methods:SetVerticalScroll() end
    function methods:SetParent() end

    setmetatable(object, {
        __index = function(self, key)
            local method = methods[key]
            if method then return method end
            local fallback = function(...) return self end
            rawset(self, key, fallback)
            return fallback
        end,
    })

    return object
end

function CreateFrame(kind, name, parent, template)
    local frame = makeObject(kind or "Frame")
    if name then _G[name] = frame end
    if parent then frame.__parent = parent end
    if template then frame.__template = template end
    return frame
end

UIParent = makeObject("Frame")
GameTooltip = makeObject("GameTooltip")
Minimap = makeObject("Minimap")
Minimap.GetCenter = function() return 0, 0 end
Minimap.GetEffectiveScale = function() return 1 end

UISpecialFrames = {}
SlashCmdList = {}
NUM_BAG_SLOTS = 4

CHAT_MESSAGES = {}
DEFAULT_CHAT_FRAME = makeObject("Frame")
DEFAULT_CHAT_FRAME.AddMessage = function(self, message)
    CHAT_MESSAGES[#CHAT_MESSAGES + 1] = tostring(message)
end

-- Timers: recorded but never fired, so the harness stays deterministic.
TIMERS = {}
C_Timer = {
    After = function(seconds, callback)
        TIMERS[#TIMERS + 1] = { kind = "after", seconds = seconds, callback = callback }
    end,
    NewTimer = function(seconds, callback)
        TIMERS[#TIMERS + 1] = { kind = "timer", seconds = seconds, callback = callback }
        return { Cancel = function() end }
    end,
    NewTicker = function(seconds, callback)
        TIMERS[#TIMERS + 1] = { kind = "ticker", seconds = seconds, callback = callback }
        return { Cancel = function() end }
    end,
}

-- Item database used by C_Item. Column order matches the documented returns:
-- name, link, quality, itemLevel, requiredLevel, typeName, subTypeName,
-- maxStack, equipLoc, iconFileID, sellPrice, classID, subclassID.
ITEM_DB = {
    [2589] = { "Linen Cloth", "|cffffffff|Hitem:2589|h[Linen Cloth]|h|r", 1, 5, 1, "Tradeskill", "Cloth", 20, "", 134939, 8, 7, 5 },
    [2592] = { "Wool Cloth", "|cffffffff|Hitem:2592|h[Wool Cloth]|h|r", 1, 15, 1, "Tradeskill", "Cloth", 20, "", 134939, 14, 7, 5 },
    [2770] = { "Copper Ore", "|cffffffff|Hitem:2770|h[Copper Ore]|h|r", 1, 5, 1, "Tradeskill", "Metal & Stone", 20, "", 134579, 5, 7, 7 },
    [4306] = { "Silk Cloth", "|cff1eff00|Hitem:4306|h[Silk Cloth]|h|r", 2, 30, 1, "Tradeskill", "Cloth", 20, "", 134939, 30, 7, 5 },
    [19019] = { "Thunderfury, Blessed Blade of the Windseeker", "|cffff8000|Hitem:19019|h[Thunderfury]|h|r", 5, 80, 60, "Weapon", "Swords", 1, "INVTYPE_WEAPON", 135349, 1000, 2, 7 },
    [6948] = { "Hearthstone", "|cffffffff|Hitem:6948|h[Hearthstone]|h|r", 1, 1, 1, "Miscellaneous", "Junk", 1, "", 134414, 0, 15, 0 },
    [5512] = { "Blood Shard", "|cff1eff00|Hitem:5512|h[Blood Shard]|h|r", 2, 10, 1, "Quest", "Quest", 1, "", 134337, 0, 12, 0 },
}

C_Item = {
    GetItemInfo = function(item)
        local row = ITEM_DB[tonumber(item)]
        if not row then return nil end
        return unpack(row)
    end,
    GetItemIconByID = function(item)
        local row = ITEM_DB[tonumber(item)]
        return row and row[10] or 134400
    end,
    GetItemNameByID = function(item)
        local row = ITEM_DB[tonumber(item)]
        return row and row[1] or nil
    end,
    -- Mirrors the documented order: itemID, type, subtype, equipLoc, icon,
    -- classID, subclassID. Works even when GetItemInfo would return nil.
    GetItemInfoInstant = function(item)
        local row = ITEM_DB[tonumber(item)]
        if not row then return nil end
        return tonumber(item), row[6], row[7], row[9], row[10], row[12], row[13]
    end,
    IsItemConjured = function() return false end,
}

-- Empty bags: bag scanning finds nothing in the harness.
C_Container = {
    GetContainerNumSlots = function() return 0 end,
    GetContainerItemID = function() return nil end,
    GetContainerItemInfo = function() return nil end,
    GetContainerItemLink = function() return nil end,
}

-- Macro store for the save journal. Indexed exactly like the game APIs.
MACRO_STORE = {}

function GetNumMacros()
    local count = 0
    for _ in pairs(MACRO_STORE) do count = count + 1 end
    return count, 0
end

function GetMacroInfo(index)
    local macro = MACRO_STORE[tonumber(index) or 0]
    if not macro then return nil end
    return macro.name, macro.icon, macro.body
end

function GetMacroIndexByName(name)
    for index, macro in pairs(MACRO_STORE) do
        if macro.name == name then return index end
    end
    return 0
end

-- The client refuses a new macro once the list is full. The cap is a global so a
-- test can lower it and prove the journal copes with a list smaller than the
-- 36-slot list the mock models by default.
MACRO_CAP = 36

function __setMacroCap(cap)
    MACRO_CAP = tonumber(cap) or 36
end

function CreateMacro(name, icon, body)
    local index = 1
    while MACRO_STORE[index] do index = index + 1 end
    if index > MACRO_CAP then return nil end
    MACRO_STORE[index] = { name = name, icon = icon or 134400, body = body or "" }
    return index
end

function EditMacro(index, name, icon, body)
    local macro = MACRO_STORE[tonumber(index) or 0]
    if not macro then return false end
    macro.name = name or macro.name
    macro.icon = icon or macro.icon
    macro.body = body or macro.body
    return true
end

function DeleteMacro(index)
    MACRO_STORE[tonumber(index) or 0] = nil
    return true
end

function __clearMacros()
    MACRO_STORE = {}
end

SOUNDKIT = {}
function PlaySound() end

-- Modern Settings integration and the AddOn compartment.
SETTINGS_CATEGORY = nil
SETTINGS_OPENED = nil
COMPARTMENT_INFO = nil
Settings = {
    RegisterCanvasLayoutCategory = function(canvas, name)
        return {
            name = name,
            frame = canvas,
            GetID = function() return 77 end,
        }
    end,
    RegisterAddOnCategory = function(category)
        SETTINGS_CATEGORY = category
    end,
    OpenToCategory = function(id)
        SETTINGS_OPENED = id
    end,
}
AddonCompartmentFrame = {
    RegisterAddon = function(self, info)
        COMPARTMENT_INFO = info
        return true
    end,
}

ITEM_QUALITY_COLORS = {}
CLASS_ICON_TCOORDS = nil
GameFontNormal = {}
GameFontHighlight = {}
GameFontNormalLarge = {}
GameFontWhite = {}

function InCombatLockdown() return false end
function UnitAffectingCombat() return false end
function GetCursorPosition() return 0, 0 end

time = os.time
date = os.date
GetTime = os.clock
GetServerTime = os.time

function GetBuildInfo() return "1.60.1", "69893", "Sep 17 2026", 16001 end

-- Lua-side reporting used by the Node harness.
function __report()
    local results = __NS.Diagnostics.Run()
    local failed = 0
    local lines = {}
    for _, result in ipairs(results) do
        if result.ok then
            lines[#lines + 1] = "PASS " .. result.name
        else
            failed = failed + 1
            lines[#lines + 1] = "FAIL " .. result.name .. " — " .. tostring(result.error)
        end
    end
    lines[#lines + 1] = string.format("%d passed, %d failed", #results - failed, failed)
    return table.concat(lines, "\n"), failed
end
