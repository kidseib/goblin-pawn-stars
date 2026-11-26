--[[ Goblin Pawn Stars -------------------------------------------------------
    Core/Journal.lua
    Forever's beta client writes SavedVariables but does not load them back.
    Macro bodies are stored server-side and therefore survive a cold restart, so
    the journal packs a compact snapshot into macro bodies as a fallback.

    Chunks use a short comment header and a base64 payload. Macro bodies are
    capped at 255 characters, so the payload is kept deliberately small and
    inventory is trimmed (lowest value first) if it would not fit.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local J = {}
ns.Journal = J

local CHUNK_SIZE = 220
local MAX_CHUNKS = 18
local PREFIX = "--GPSJ1:"
local MACRO_ICON = 134400
local SAVE_THROTTLE = 45

local lastSave = 0
local loaded = false
local loading = false
local saving = false
local pending = false

J.status = {
    chunks = 0,
    savedAt = 0,
    trimmed = false,
    error = nil,
}

---------------------------------------------------------------------------
-- Encoding helpers
---------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64Encode(text)
    local out = {}
    local length = #text
    local index = 1
    while index <= length do
        local a, b, c = text:byte(index, index + 2)
        local n = (a or 0) * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = math.floor(n / 262144) % 64 + 1
        local c2 = math.floor(n / 4096) % 64 + 1
        local c3 = math.floor(n / 64) % 64 + 1
        local c4 = n % 64 + 1
        out[#out + 1] = B64:sub(c1, c1) .. B64:sub(c2, c2) .. B64:sub(c3, c3) .. B64:sub(c4, c4)
        index = index + 3
    end
    local pad = (3 - (length % 3)) % 3
    if pad > 0 then
        local last = out[#out]
        out[#out] = last:sub(1, #last - pad) .. string.rep("=", pad)
    end
    return table.concat(out)
end

local function base64Value(char)
    if char == "=" then return 0 end
    local position = B64:find(char, 1, true)
    if not position then return nil end
    return position - 1
end

local function base64Decode(text)
    if type(text) ~= "string" or #text % 4 ~= 0 then return nil end
    local out = {}
    for index = 1, #text, 4 do
        local a, b, c, d = text:sub(index, index + 3):byte(1, 4)
        if not a or not b or not c or not d then return nil end
        local ca, cb, cc, cd = string.char(a), string.char(b), string.char(c), string.char(d)
        if ca == "=" or cb == "=" then return nil end
        local va = base64Value(ca)
        local vb = base64Value(cb)
        local vc = base64Value(cc)
        local vd = base64Value(cd)
        if va == nil or vb == nil or vc == nil or vd == nil then return nil end
        if cc == "=" and cd ~= "=" then return nil end
        local n = va * 262144 + vb * 4096 + vc * 64 + vd
        out[#out + 1] = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
        if cc == "=" then
            out[#out] = out[#out]:sub(1, 1)
        elseif cd == "=" then
            out[#out] = out[#out]:sub(1, 2)
        end
    end
    return table.concat(out)
end

local function checksum(text)
    local value = 5381
    for index = 1, #text do
        value = (value * 33 + text:byte(index)) % 4294967296
    end
    return math.floor(value)
end

local function makeChunk(sequence, total, stamp, data)
    return string.format("%s%.0f:%.0f:%.0f:%s", PREFIX, sequence, total, stamp, data)
end

local function parseChunk(body)
    if type(body) ~= "string" or body:sub(1, #PREFIX) ~= PREFIX then return nil end
    local sequence, total, stamp, data = body:match("^%-%-GPSJ1:(%d+):(%d+):(%d+):(.*)$")
    if not sequence then return nil end
    return tonumber(sequence), tonumber(total), tonumber(stamp), data
end

---------------------------------------------------------------------------
-- Snapshot sizing
---------------------------------------------------------------------------

local function encodedSnapshot(snapshot)
    return base64Encode(DB.Encode(snapshot))
end

local function trimSnapshot(snapshot, encoded)
    local limit = MAX_CHUNKS * CHUNK_SIZE
    if #encoded <= limit then return encoded, false end

    local entries = {}
    for uid, record in pairs(snapshot.inventory or {}) do
        entries[#entries + 1] = {
            uid = uid,
            weight = (tonumber(record.value) or 1) * (tonumber(record.count) or 1),
        }
    end
    table.sort(entries, function(a, b) return a.weight < b.weight end)

    local removed = 0
    local index = 1
    while #encoded > limit and index <= #entries do
        for _ = 1, 4 do
            local entry = entries[index]
            index = index + 1
            if not entry then break end
            snapshot.inventory[entry.uid] = nil
            removed = removed + 1
        end
        encoded = encodedSnapshot(snapshot)
    end
    return encoded, removed > 0
end

local function hasProgress(db)
    if not db then return false end
    if (db.stats and (db.stats.sales or 0) > 0) then return true end
    if (db.tier or 1) > 1 then return true end
    if db.campaign and (db.campaign.payments or 0) > 0 then return true end
    if db.inventory and next(db.inventory) then return true end
    return false
end

---------------------------------------------------------------------------
-- Reading macro chunks
---------------------------------------------------------------------------

local function readChunks()
    local available = ns.Compat.MacroCount()
    if available == nil then return nil, false end

    local chunks = {}
    for index = 1, 36 do
        local name, body = ns.Compat.MacroInfo(index)
        if name and body then
            local sequence, total, stamp, data = parseChunk(body)
            if sequence and data then
                if chunks[sequence] then
                    return nil, true, "duplicate journal chunk " .. tostring(sequence)
                end
                chunks[sequence] = { total = total, stamp = stamp, data = data }
            end
        end
    end
    return chunks, true
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

local function scheduleRetry()
    ns.Compat.After(2, function() J.TryLoad() end)
    ns.Compat.After(5, function() J.TryLoad() end)
    ns.Compat.After(10, function() J.TryLoad() end)
end

function J.TryLoad(force)
    if loading then return false end
    if loaded and not force then return true end
    if force then loaded = false end

    local db = DB.Get()
    if db.settings.macroJournal == false then
        loaded = true
        J.status.error = nil
        return true
    end

    local chunks, available, readError = readChunks()
    if not available then
        J.status.error = "macro API unavailable"
        scheduleRetry()
        return false
    end
    if readError then
        loaded = true
        J.status.error = readError
        return false
    end
    if not chunks or next(chunks) == nil then
        loaded = true
        J.status.error = nil
        J.status.savedAt = 0
        J.status.chunks = 0
        J.status.empty = true
        return true
    end

    local total
    for sequence, chunk in pairs(chunks) do
        if not total then total = chunk.total end
        if not chunk.total or chunk.total < 1 or chunk.total > MAX_CHUNKS then
            loaded = true
            J.status.error = "invalid journal chunk count"
            return false
        end
        if chunk.total ~= total then
            loaded = true
            J.status.error = "journal chunks disagree on length"
            return false
        end
        if sequence > total then
            loaded = true
            J.status.error = "journal chunk out of range"
            return false
        end
    end

    local encoded = {}
    for sequence = 1, total do
        local chunk = chunks[sequence]
        if not chunk then
            J.status.error = "journal is incomplete"
            scheduleRetry()
            return false
        end
        encoded[sequence] = chunk.data
    end
    encoded = table.concat(encoded)

    local stamp = chunks[1].stamp
    if checksum(encoded) ~= stamp then
        loaded = true
        J.status.error = "journal checksum mismatch"
        return false
    end

    local text = base64Decode(encoded)
    if not text then
        loaded = true
        J.status.error = "journal payload is corrupt"
        return false
    end
    local payload, err = ns.Serialize.Decode(text)
    if not payload or type(payload.data) ~= "table" then
        loaded = true
        J.status.error = "journal could not be decoded: " .. tostring(err or "bad payload")
        return false
    end
    if payload.addon and payload.addon ~= ns.ADDON then
        loaded = true
        J.status.error = "journal belongs to another addon"
        return false
    end

    local journalAt = tonumber(payload.savedAt) or 0
    local current = DB.Get()
    if hasProgress(current) and (current.savedAt or 0) >= journalAt then
        loaded = true
        J.status.error = nil
        J.status.savedAt = journalAt
        J.status.chunks = total
        J.status.empty = false
        return true
    end

    local login = current.lastSession and current.lastSession.login
    local ok, importError = DB.Import(text, true)
    if not ok then
        J.status.error = "journal import failed: " .. tostring(importError)
        return false
    end

    local fresh = DB.Get()
    fresh.savedAt = journalAt
    fresh.lastSession = { login = login or U.now(), version = ns.VERSION }
    -- Do not let a stale timer from the saved run fire a customer instantly on
    -- a later login. No elapsed time is credited here; this only schedules the
    -- next ordinary arrival.
    fresh.shop.nextArrival = math.max(16, tonumber(fresh.shop.nextArrival) or 16)
    loaded = true
    J.status.error = nil
    J.status.savedAt = journalAt
    J.status.chunks = total
    J.status.empty = false

    if not fresh.settings.journalHintShown then
        fresh.settings.journalHintShown = true
        ns.Print("Progress restored from the macro journal (the beta client is not loading SavedVariables yet).")
    end
    if ns.UI and ns.UI.Refresh then
        local refreshOk = pcall(ns.UI.Refresh)
        if not refreshOk then ns.Debug("UI refresh after journal load failed") end
    end
    return true
end

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------

local function writeChunks(encoded, stamp)
    local total = math.ceil(#encoded / CHUNK_SIZE)
    if total < 1 or total > MAX_CHUNKS then
        return false, "journal does not fit in " .. tostring(MAX_CHUNKS) .. " macros"
    end

    for sequence = 1, total do
        local data = encoded:sub((sequence - 1) * CHUNK_SIZE + 1, sequence * CHUNK_SIZE)
        local body = makeChunk(sequence, total, stamp, data)
        local name = string.format("GPSJ%02d", sequence)
        local index = ns.Compat.MacroIndexByName(name)

        if index and index > 0 then
            local existingName, existingBody = ns.Compat.MacroInfo(index)
            if existingBody and existingBody:sub(1, #PREFIX) ~= PREFIX then
                return false, "macro name collision on " .. name
            end
            if existingBody ~= body then
                if not ns.Compat.EditMacro(index, name, MACRO_ICON, body) then
                    return false, "could not update " .. name
                end
            end
        else
            local created = ns.Compat.CreateMacro(name, MACRO_ICON, body)
            if not created then
                return false, "could not create " .. name .. " (macro slots may be full)"
            end
        end
    end

    -- Delete by name, not by a numeric index that shifts after every delete.
    for sequence = total + 1, MAX_CHUNKS do
        local name = string.format("GPSJ%02d", sequence)
        local index = ns.Compat.MacroIndexByName(name)
        if index and index > 0 then
            local _, body = ns.Compat.MacroInfo(index)
            if body and body:sub(1, #PREFIX) == PREFIX then
                ns.Compat.DeleteMacro(index)
            end
        end
    end
    return true, total
end

function J.SaveNow()
    if saving or loading then return false end
    local db = DB.Get()
    if db.settings.macroJournal == false then
        return false
    end
    if ns.Compat.InCombat() then
        pending = true
        return false
    end
    if ns.Compat.MacroCount() == nil then
        J.status.error = "macro API unavailable"
        return false
    end

    saving = true
    local snapshot = DB.Snapshot()
    local encoded = encodedSnapshot(snapshot)
    local trimmed
    encoded, trimmed = trimSnapshot(snapshot, encoded)
    if #encoded > MAX_CHUNKS * CHUNK_SIZE then
        saving = false
        J.status.error = "journal is too large, even without inventory"
        return false
    end

    local stamp = checksum(encoded)
    local ok, detail = writeChunks(encoded, stamp)
    saving = false
    if not ok then
        J.status.error = detail
        return false
    end

    lastSave = U.now()
    pending = false
    J.status.error = nil
    J.status.chunks = detail
    J.status.savedAt = lastSave
    J.status.trimmed = trimmed and true or false
    J.status.empty = false
    return true, J.status
end

function J.Save()
    if not ns.db or loaded == false then return false end
    local now = U.now()
    if now - lastSave < SAVE_THROTTLE and not pending then return false end
    return J.SaveNow()
end

function J.Tick()
    if pending and not ns.Compat.InCombat() then J.SaveNow() end
end

function J.Clear()
    if ns.Compat.MacroCount() == nil then return false end
    -- Names are stable; macro indices compact when one is removed.
    for sequence = 1, MAX_CHUNKS do
        local name = string.format("GPSJ%02d", sequence)
        local index = ns.Compat.MacroIndexByName(name)
        if index and index > 0 then
            local _, body = ns.Compat.MacroInfo(index)
            if body and body:sub(1, #PREFIX) == PREFIX then
                ns.Compat.DeleteMacro(index)
            end
        end
    end
    lastSave = 0
    J.status.savedAt = 0
    J.status.chunks = 0
    J.status.error = nil
    J.status.empty = true
    return true
end

---------------------------------------------------------------------------
-- Presentation and events
---------------------------------------------------------------------------

function J.Active()
    return DB.Get().settings.macroJournal ~= false
end

function J.StatusText()
    local status = J.status
    if not J.Active() then return "Macro journal off; use a backup string in Settings." end
    if status.error then return "Journal: " .. tostring(status.error) end
    if (status.savedAt or 0) > 0 then
        local age = math.max(0, U.now() - status.savedAt)
        local trimmed = status.trimmed and " · inventory trimmed" or ""
        return string.format("Journal: %d chunks · saved %s ago%s",
            status.chunks or 0, U.clock(age), trimmed)
    end
    if loaded then return "Journal empty; the next autosave will fill it." end
    return "Journal waiting for the macro list."
end

J.events = ns.Compat.EventFrame({
    PLAYER_LOGIN = function()
        if not J.TryLoad() then scheduleRetry() end
    end,
    PLAYER_ENTERING_WORLD = function()
        -- Macro lists can populate a fraction after PLAYER_LOGIN. Recheck an
        -- empty journal once the world is ready, before an autosave could
        -- overwrite a real run with fresh defaults.
        if J.status.empty and (DB.Get().savedAt or 0) == 0 then
            J.TryLoad(true)
        else
            J.TryLoad()
        end
    end,
    PLAYER_LOGOUT = function()
        J.SaveNow()
    end,
})
