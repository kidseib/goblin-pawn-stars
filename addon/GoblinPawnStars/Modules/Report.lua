--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Report.lua
    /gps report: one compact, pasteable block describing what this client
    actually supports, whether saving works, the most recent Lua errors and the
    current economy. Every probe is guarded so a missing API is reported as
    missing instead of breaking the command.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local R = {}
ns.Report = R

local MAX_LINES = 12
local ERROR_TEXT_LIMIT = 70

local SOUND_SAMPLES = {
    "COIN_PICKUP", "IG_MAINMENU_OPEN", "IG_MAINMENU_CLOSE",
    "LOOT_WINDOW_OPEN", "ACHIEVEMENT_MENU_OPEN",
}

local CONTAINER_METHODS = {
    "GetContainerNumSlots", "GetContainerItemInfo",
    "GetContainerItemID", "GetContainerItemLink",
}

local TEXTURE_SAMPLES = {
    "Interface\\Icons\\INV_Misc_Coin_01",
    "Interface\\DialogFrame\\UI-DialogBox-Background",
    "Interface\\Tooltips\\UI-Tooltip-Background",
    "Interface\\Icons\\ClassIcon_WARRIOR",
}

local function attempt(fallback, fn, ...)
    local ok, result = pcall(fn, ...)
    if ok and result ~= nil then return result end
    return fallback
end

local function ratio(found, total)
    return tostring(found) .. "/" .. tostring(total)
end

-- Lua 5.1 accepts floats for %d, newer sandboxes do not, so cast explicitly.
local function int(value)
    return tostring(math.floor(tonumber(value) or 0))
end

local function truncate(text, limit)
    text = tostring(text or ""):gsub("\n.*$", " ")
    if #text > limit then return text:sub(1, limit - 3) .. "..." end
    return text
end

local function ageText(stamp)
    stamp = tonumber(stamp) or 0
    if stamp <= 0 then return "never" end
    return U.clock(math.max(0, U.now() - stamp)) .. " ago"
end

---------------------------------------------------------------------------
-- Capability probes
---------------------------------------------------------------------------

local function macroSources()
    local parts = {}
    for _, name in ipairs({ "CreateMacro", "EditMacro", "DeleteMacro" }) do
        local where = "missing"
        if type(_G[name]) == "function" then
            where = "global"
        elseif C_Macro and type(C_Macro[name]) == "function" then
            where = "C_Macro"
        end
        parts[#parts + 1] = name:gsub("Macro", ""):lower() .. "=" .. where
    end
    return table.concat(parts, " ")
end

local function macroProbe()
    local count = attempt(nil, ns.Compat.MacroCount)
    local countText = count and ("ok(" .. tostring(count) .. ")") or "no"
    return "macros=" .. countText .. " " .. macroSources()
end

local function soundProbe()
    if type(SOUNDKIT) ~= "table" then return "sound=no" end
    local found = 0
    for _, key in ipairs(SOUND_SAMPLES) do
        if SOUNDKIT[key] ~= nil then found = found + 1 end
    end
    return "sound=" .. ratio(found, #SOUND_SAMPLES)
end

local function containerProbe()
    if type(C_Container) ~= "table" then
        return "bags=legacy(" .. (type(GetContainerItemInfo) == "function" and "ok" or "no") .. ")"
    end
    local found = 0
    for _, name in ipairs(CONTAINER_METHODS) do
        if type(C_Container[name]) == "function" then found = found + 1 end
    end
    return "bags=C_Container(" .. ratio(found, #CONTAINER_METHODS) .. ")"
end

local function itemProbe()
    if C_Item and type(C_Item.GetItemInfo) == "function" then return "item=C_Item" end
    if type(GetItemInfo) == "function" then return "item=legacy" end
    return "item=no"
end

local function textureProbe()
    local frame = attempt(nil, ns.Compat.CreateFrame, "Frame")
    if not frame then return "texture=no frame" end
    local texture = attempt(nil, frame.CreateTexture, frame, nil, "BACKGROUND")
    if not texture then return "texture=no texture" end

    local accepted = 0
    for _, path in ipairs(TEXTURE_SAMPLES) do
        local ok = pcall(texture.SetTexture, texture, path)
        if ok then
            local current = attempt(nil, texture.GetTexture, texture)
            if current then accepted = accepted + 1 end
        end
    end
    pcall(frame.Hide, frame)

    -- GetFileIDFromPath answers whether the client knows the file at all; the
    -- SetTexture round-trip above only proves the API exists.
    local known = nil
    if type(GetFileIDFromPath) == "function" then
        known = 0
        for _, path in ipairs(TEXTURE_SAMPLES) do
            local id = attempt(nil, GetFileIDFromPath, path)
            if id then known = known + 1 end
        end
    end
    if known then
        return "texture=" .. ratio(accepted, #TEXTURE_SAMPLES) .. " (files " .. ratio(known, #TEXTURE_SAMPLES) .. ")"
    end
    return "texture=" .. ratio(accepted, #TEXTURE_SAMPLES)
end

local function capabilityLine()
    return table.concat({
        macroProbe(), soundProbe(), containerProbe(), itemProbe(), textureProbe(),
    }, " · ")
end

---------------------------------------------------------------------------
-- Report sections
---------------------------------------------------------------------------

local function journalLine()
    local journal = ns.Journal
    if not journal then return "journal: module missing" end
    local status = journal.status or {}
    local loaded = attempt(false, journal.Loaded)
    local active = attempt(true, journal.Active)
    local text = string.format("journal: %s · %s · %d chunks · gen %s · saved %s",
        active and "on" or "off",
        loaded and "loaded" or "not loaded",
        tonumber(status.chunks) or 0,
        tostring(status.generation or "none"),
        ageText(status.savedAt))
    if status.trimmed then text = text .. " · trimmed" end
    if status.error then text = text .. " · error: " .. truncate(status.error, ERROR_TEXT_LIMIT) end
    return text
end

local function errorLine()
    local list = ns.errors or {}
    if #list == 0 then return "errors: none this session" end
    local parts = { "errors: " .. tostring(#list) }
    for index = 1, math.min(3, #list) do
        local entry = list[index]
        parts[#parts + 1] = string.format("%s %s: %s",
            ageText(entry.at), tostring(entry.source or "lua"),
            truncate(entry.text, 46))
    end
    return table.concat(parts, " · ")
end

local function economyLine()
    local db = DB.Get()
    local tier = ns.Shop.TierInfo()
    local label = ns.Shop.ReputationLabel()
    return "econ: " .. U.comma(db.credits) .. " gc · tier " .. int(db.tier or 1) .. "/" .. int(#ns.Data.Tiers) ..
        " " .. tostring(tier and tier.name or "?") .. " · rep " .. int(db.reputation) .. " " .. tostring(label) ..
        " · sales " .. U.comma(db.stats.sales or 0) .. " · revenue " .. U.comma(db.stats.revenue or 0) ..
        " · spent " .. U.comma(db.stats.spent or 0) .. " · expenses " .. U.comma(db.stats.expenses or 0)
end

local function shopLine()
    local db = DB.Get()
    local upgradeLevels = 0
    for _, level in pairs(db.upgrades or {}) do upgradeLevels = upgradeLevels + (tonumber(level) or 0) end
    local staff = 0
    for _, level in pairs(db.employees or {}) do
        if (tonumber(level) or 0) > 0 then staff = staff + 1 end
    end
    local achievements = 0
    for _ in pairs(db.achievements or {}) do achievements = achievements + 1 end
    return "shop: " .. int(ns.Inventory.Count()) .. "/" .. int(ns.Inventory.Capacity()) .. " stock · " ..
        int(upgradeLevels) .. " upgrade levels · staff " .. int(staff) .. "/" .. int(ns.Staff.Slots()) ..
        " · achievements " .. int(achievements) .. "/" .. int(#ns.Data.Achievements) ..
        " · museum " .. int(ns.Museum and ns.Museum.Count() or 0) .. "/" .. int(ns.Museum and ns.Museum.Total() or 0) ..
        " · Marta " .. int(ns.Regular and ns.Regular.Visits() or 0) .. "/" .. int(ns.Regular and ns.Regular.TotalVisits() or 0)
end

local function campaignLine()
    local campaign = ns.Campaign
    if not campaign then return "deed: module missing" end
    local nextNote = campaign.NextPayment()
    local prestige = DB.Get().prestige
    return "deed: " .. int(campaign.Payments()) .. "/" .. int(campaign.PaymentCount()) .. " notes · " ..
        U.comma(campaign.Paid()) .. "/" .. U.comma(campaign.Total()) .. " paid · next " ..
        (nextNote and U.comma(nextNote.amount) or "none") .. " · mode " .. tostring(campaign.Mode()) ..
        " · prestige " .. int(prestige and prestige.level or 0)
end

local function paceLine()
    local db = DB.Get()
    local creditsRate, customerRate = ns.Throughput.Rates()
    local events = #(db.market and db.market.events or {})
    return "pace: " .. int(creditsRate or 0) .. " gc/min · " ..
        string.format("%.1f", tonumber(customerRate) or 0) .. " customers/min · shop day " ..
        int((ns.Shop.ShopDayProgress() or 0) * 100 + 0.5) .. "% · market events " .. int(events) ..
        " · queue " .. int(#(db.shop.waiting or {})) .. "/" .. int(ns.Shop.WaitingSlots())
end

local function settingsLine()
    local db = DB.Get()
    local settings = db.settings or {}
    return "settings: scale " .. string.format("%.2f", tonumber(settings.scale) or 1) ..
        " · pace " .. tostring(settings.arrivalPace or "Normal") ..
        " · arrivals " .. tostring(settings.customerArrival or "Animated") ..
        " · auto-sell " .. (settings.autoSell ~= false and "on" or "off") ..
        " · performance " .. (settings.performance == true and "on" or "off") ..
        " · sound " .. (settings.sound ~= false and "on" or "off") ..
        " · paused " .. (settings.paused and "on" or "off") ..
        " · debug " .. (ns.debugEnabled and "on" or "off")
end

local function headerLine()
    local stamp = "?"
    if type(date) == "function" then
        local ok, text = pcall(date, "%Y-%m-%d %H:%M", U.now())
        if ok and text then stamp = text end
    end
    return "GPS| Goblin Pawn Stars " .. tostring(ns.VERSION) .. " · interface " .. int(ns.INTERFACE) ..
        " · " .. stamp .. " · playtime " .. U.clock(DB.Get().stats.playtime or 0)
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

-- Builds the whole bundle. Kept side-effect free so /gps test can assert on it.
function R.Build()
    local lines = { headerLine() }
    lines[#lines + 1] = "GPS| api: " .. capabilityLine()
    lines[#lines + 1] = "GPS| " .. journalLine()
    lines[#lines + 1] = "GPS| " .. errorLine()
    lines[#lines + 1] = "GPS| " .. economyLine()
    lines[#lines + 1] = "GPS| " .. shopLine()
    lines[#lines + 1] = "GPS| " .. campaignLine()
    lines[#lines + 1] = "GPS| " .. paceLine()
    lines[#lines + 1] = "GPS| " .. settingsLine()
    lines[#lines + 1] = "GPS| end of report — copy every GPS| line"

    while #lines > MAX_LINES do table.remove(lines) end
    return table.concat(lines, "\n")
end

function R.Print()
    local text = R.Build()
    ns.Print("Diagnostics report — copy the lines below and send them along.")
    for line in text:gmatch("[^\n]+") do
        ns.Print(line)
    end
end

local function clockMs()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    if not ok or not tonumber(value) then return nil end
    return tonumber(value) * 1000
end

local function profileLine(label, fn, detail)
    local started = clockMs()
    if not started then
        return "GPS| " .. label .. ": timing unavailable"
    end
    local ok, result = pcall(fn)
    if not ok then
        return "GPS| " .. label .. ": failed · " .. truncate(result, ERROR_TEXT_LIMIT)
    end
    local finished = clockMs() or started
    local ms = math.floor((finished - started) + 0.5)
    return "GPS| " .. label .. ": " .. ms .. " ms" .. (detail and detail(result) or "")
end

local function rollingLine(key, label)
    local metric = ns.Perf and ns.Perf.Get and ns.Perf.Get(key)
    if not metric or (metric.count or 0) == 0 then
        return "GPS| rolling " .. label .. ": no samples yet"
    end
    local suffix = metric.label and (" · " .. tostring(metric.label)) or ""
    return string.format("GPS| rolling %s: last %d ms · max %d ms · %d samples%s",
        label, math.floor((tonumber(metric.last) or 0) + 0.5),
        math.floor((tonumber(metric.max) or 0) + 0.5), metric.count, suffix)
end

local function memoryText()
    if type(GetAddOnMemoryUsage) ~= "function" then return "unknown" end
    local ok, value = pcall(GetAddOnMemoryUsage, ns.ADDON)
    if not ok or not tonumber(value) then return "unknown" end
    return string.format("%.1f MB", tonumber(value) / 1024)
end

-- Times the known heavy paths without changing the shop. Run it with the shop
-- open on the tab that feels slow, then send the GPS| lines back with /gps report.
function R.Profile()
    local db = DB.Get()
    local macros = attempt(nil, ns.Compat.MacroCount)
    local status = ns.Journal and ns.Journal.status or {}
    local lines = {
        "GPS| performance profile · v" .. tostring(ns.VERSION) .. " · interface " .. int(ns.INTERFACE),
        string.format("GPS| stock %d/%d · queue %d/%d · macro chunks %d · macro slots %s · memory %s",
            ns.Inventory.Count(), ns.Inventory.Capacity(), #db.shop.waiting,
            ns.Shop.WaitingSlots(), tonumber(status.chunks) or 0,
            macros and tostring(macros) or "unavailable", memoryText()),
    }

    lines[#lines + 1] = profileLine("backup encode", function() return DB.Export() end, function(text)
        return string.format(" · %d KB", math.floor(#text / 1024))
    end)
    lines[#lines + 1] = profileLine("stock sort (value)", function()
        return ns.Inventory.List({ sort = "value" })
    end, function(list)
        return string.format(" · %d stacks", #list)
    end)
    if ns.Loot and ns.Loot.Diagnose then
        lines[#lines + 1] = profileLine("bag scan (read-only)", function()
            return ns.Loot.Diagnose()
        end, function(report)
            return string.format(" · %d bags · %d stacks · %d items",
                tonumber(report.bags) or 0, tonumber(report.stacks) or 0, tonumber(report.items) or 0)
        end)
    end
    local shopState = ns.UI and ns.UI.IsOpen and ns.UI.IsOpen() and "shop open" or "shop closed"
    lines[#lines + 1] = profileLine("UI refresh (" .. shopState .. ")", function()
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    end)

    lines[#lines + 1] = rollingLine("journal", "journal save")
    lines[#lines + 1] = rollingLine("backup", "backup encode")
    lines[#lines + 1] = rollingLine("bags", "bag scan")
    lines[#lines + 1] = rollingLine("tab", "active-tab refresh")

    local saveMs = tonumber(status.saveMs) or 0
    lines[#lines + 1] = string.format("GPS| last journal save: %s · %d chunks · gen %s",
        saveMs > 0 and string.format("%d ms", math.floor(saveMs + 0.5)) or "not measured",
        tonumber(status.chunks) or 0, tostring(status.generation or "none"))
    if status.error then
        lines[#lines + 1] = "GPS| journal error: " .. truncate(status.error, ERROR_TEXT_LIMIT)
    end
    lines[#lines + 1] = "GPS| run this with the shop open on the slow tab; it only reads and redraws."

    ns.Print("Performance profile — copy the lines below.")
    for _, line in ipairs(lines) do ns.Print(line) end
    return table.concat(lines, "\n")
end

-- Chains the client's error handler so uncaught Lua errors are remembered
-- without changing what the player normally sees.
function R.Install()
    if R.installed then return true end
    if type(seterrorhandler) ~= "function" then return false end

    local previous
    if type(geterrorhandler) == "function" then
        local ok, handler = pcall(geterrorhandler)
        if ok then previous = handler end
    end

    local ok = pcall(seterrorhandler, function(message)
        ns.RecordError("lua", message)
        if previous then pcall(previous, message) end
    end)
    R.installed = ok
    return ok
end

R.events = ns.Compat.EventFrame({
    PLAYER_LOGIN = function()
        R.Install()
    end,
})
