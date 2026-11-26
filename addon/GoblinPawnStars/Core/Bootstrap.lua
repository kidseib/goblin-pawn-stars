--[[ Goblin Pawn Stars -------------------------------------------------------
    Core/Bootstrap.lua
    Namespace, chat helpers and small, dependency-free utilities used by every
    other module. Keep this file free of WoW UI code so the logic layer stays
    testable outside the game client.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...

ns.ADDON = ADDON
ns.VERSION = "1.7.0"
ns.CREDIT = "ErrorSeib & Buffy (Codebuff)"
ns.INTERFACE = 16001
ns.PREFIX = "|cff7bd66bGoblin Pawn Stars|r: "
ns.debugEnabled = false

local U = {}
ns.Util = U

---------------------------------------------------------------------------
-- Chat output
---------------------------------------------------------------------------

function ns.Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. tostring(message))
    end
end

function ns.Debug(message)
    if ns.debugEnabled then
        ns.Print("|cff8a8a8a[debug]|r " .. tostring(message))
    end
end

function ns.Warn(message)
    ns.Print("|cffffcc55" .. tostring(message) .. "|r")
end

-- Small session-only ring of failures, newest first. /gps report prints it so a
-- teammate can see what actually broke instead of reproducing it blind.
ns.errors = {}
local MAX_ERRORS = 8

function ns.RecordError(source, message)
    local text = tostring(message or "")
    text = text:gsub("\n.*$", "")
    if #text > 160 then text = text:sub(1, 157) .. "..." end
    table.insert(ns.errors, 1, { at = U.now(), source = tostring(source or "lua"), text = text })
    while #ns.errors > MAX_ERRORS do table.remove(ns.errors) end
end

---------------------------------------------------------------------------
-- Numbers & strings
---------------------------------------------------------------------------

function U.clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

function U.round(value, step)
    value = tonumber(value) or 0
    step = tonumber(step) or 1
    if step <= 0 then return value end
    return math.floor(value / step + 0.5) * step
end

function U.floor(value)
    return math.floor(tonumber(value) or 0)
end

function U.lerp(a, b, t)
    return a + (b - a) * (t or 0)
end

function U.comma(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    local sign = ""
    if text:sub(1, 1) == "-" then
        sign = "-"
        text = text:sub(2)
    end
    local out = ""
    while #text > 3 do
        out = "," .. text:sub(-3) .. out
        text = text:sub(1, #text - 3)
    end
    return sign .. text .. out
end

function U.clock(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    if minutes >= 60 then
        local hours = math.floor(minutes / 60)
        return string.format("%dh %02dm", hours, minutes % 60)
    end
    return string.format("%dm %02ds", minutes, secs)
end

function U.trim(text)
    text = tostring(text or "")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

function U.upper(text) return string.upper(tostring(text or "")) end
function U.lower(text) return string.lower(tostring(text or "")) end

function U.contains(list, value)
    if not list then return false end
    for index = 1, #list do
        if list[index] == value then return true end
    end
    return false
end

function U.now()
    if type(time) == "function" then return time() end
    return 0
end

function U.today()
    if type(date) == "function" then
        return date("%Y-%m-%d")
    end
    return "day-0"
end

---------------------------------------------------------------------------
-- Tables
---------------------------------------------------------------------------

function U.copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, entry in pairs(value) do
        out[key] = U.copy(entry)
    end
    return out
end

function U.count(tbl)
    local total = 0
    for _ in pairs(tbl or {}) do total = total + 1 end
    return total
end

function U.sortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

function U.pick(list)
    if not list or #list == 0 then return nil end
    return list[math.random(#list)]
end

function U.weightedPick(list, weightOf)
    if not list or #list == 0 then return nil end
    local total = 0
    for index = 1, #list do
        local entry = list[index]
        local weight = weightOf and weightOf(entry) or (entry and entry.weight) or 1
        if weight > 0 then total = total + weight end
    end
    if total <= 0 then return list[#list] end
    local roll = math.random() * total
    local acc = 0
    for index = 1, #list do
        local entry = list[index]
        local weight = weightOf and weightOf(entry) or (entry and entry.weight) or 1
        if weight > 0 then
            acc = acc + weight
            if roll <= acc then return entry end
        end
    end
    return list[#list]
end

function U.shuffle(list)
    for index = #list, 2, -1 do
        local swap = math.random(index)
        list[index], list[swap] = list[swap], list[index]
    end
    return list
end

function U.hash(text)
    text = tostring(text or "")
    local h = 5381
    for index = 1, #text do
        h = (h * 33 + text:byte(index)) % 2147483647
    end
    return h
end

-- Fills missing keys in `target` from `defaults` (recursive, non-destructive).
function U.applyDefaults(target, defaults)
    if type(target) ~= "table" then target = {} end
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = U.applyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

function U.randomBetween(low, high)
    if high <= low then return low end
    return low + math.random() * (high - low)
end

function U.randomInt(low, high)
    low = math.floor(low)
    high = math.floor(high)
    if high <= low then return low end
    return math.random(low, high)
end

function U.chance(probability)
    return math.random() < (probability or 0)
end

function U.capitalize(text)
    text = tostring(text or "")
    if text == "" then return text end
    return text:sub(1, 1):upper() .. text:sub(2)
end

-- Fills {placeholders} in a dialogue template. Unknown keys are left alone so
-- a typo shows up in the UI instead of silently emptying the line.
function U.fill(template, vars)
    template = tostring(template or "")
    if not vars then return template end
    return (template:gsub("{(%w+)}", function(key)
        local value = vars[key]
        if value == nil then return "{" .. key .. "}" end
        return tostring(value)
    end))
end
