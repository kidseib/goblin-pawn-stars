--[[ Goblin Pawn Stars -------------------------------------------------------
    Core/Journal.lua
    Forever's beta client writes SavedVariables but does not load them back.
    Macro bodies are stored server-side and therefore survive a cold restart, so
    the journal packs a compact snapshot into macro bodies as a fallback.

    Chunks use a short comment header and a base64 payload. Macro bodies are
    capped at 255 characters, so the payload is kept deliberately small and
    inventory is trimmed (lowest value first) if it would not fit.

    Saves alternate between two generations (A and B). Each write is read back
    and compared before the next step, and a generation only becomes current
    when its header chunk is rewritten as committed at the very end. A crash or
    a rejected write therefore leaves the other generation, and the macro list,
    exactly as it was.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local J = {}
ns.Journal = J

local CHUNK_SIZE = 210
local MAX_CHUNKS = 12          -- per generation; a save needs two of them
local LEGACY_CHUNKS = 24       -- pre-1.6.4 single-generation saves
local PREFIX_V1 = "--GPSJ1:"
local PREFIX_V2 = "--GPSJ2:"
local GENERATIONS = { "A", "B" }
local MACRO_ICON = 134400
local SAVE_THROTTLE = 30
local RETRY_DELAY = 8
local FIRST_SAVE = 10
local EMPTY_ATTEMPTS = 3

local startedAt = U.now()
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
    generation = nil,
    counter = 0,
    stamp = nil,
    fingerprint = nil,
    attempts = 0,
}

-- A broken save path is invisible until the next login, so the first failure of
-- each kind gets one chat line per session instead of a silent return.
local reportedFailures = {}

local function reportSaveFailure(detail)
    J.status.error = detail
    if reportedFailures[detail] then return end
    reportedFailures[detail] = true
    ns.Warn("Could not save progress to the macro journal: " .. tostring(detail) ..
        ". This session may not survive a logout. Type |cffffffff/gps journal|r for details.")
end

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

local function chunkName(generation, index)
    return string.format("GPS%s%02d", generation, index)
end

local function legacyName(index)
    return string.format("GPSJ%02d", index)
end

local function bodyLooksLikeJournal(body)
    if type(body) ~= "string" then return false end
    return body:sub(1, #PREFIX_V2) == PREFIX_V2 or body:sub(1, #PREFIX_V1) == PREFIX_V1
end

local function makeChunk(generation, counter, index, total, stamp, state, data)
    -- %.0f keeps Lua 5.1 happy and avoids the integer-subtype checks newer
    -- sandboxes add to %d for the checksum-sized numbers here.
    return string.format("%s%s:%.0f:%.0f:%.0f:%.0f:%s:%s",
        PREFIX_V2, generation, counter, index, total, stamp, state, data)
end

local function parseChunk(body)
    if type(body) ~= "string" then return nil end
    if body:sub(1, #PREFIX_V2) == PREFIX_V2 then
        local generation, counter, index, total, stamp, state, data =
            body:match("^%-%-GPSJ2:([AB]):(%d+):(%d+):(%d+):(%d+):([cp]):(.*)$")
        if not generation or not data then return nil end
        return {
            version = 2,
            generation = generation,
            counter = tonumber(counter) or 0,
            index = tonumber(index),
            total = tonumber(total),
            stamp = tonumber(stamp),
            state = state,
            data = data,
        }
    end
    local index, total, stamp, data = body:match("^%-%-GPSJ1:(%d+):(%d+):(%d+):(.*)$")
    if not index or not data then return nil end
    return {
        version = 1,
        index = tonumber(index),
        total = tonumber(total),
        stamp = tonumber(stamp),
        data = data,
    }
end

---------------------------------------------------------------------------
-- Snapshot sizing
---------------------------------------------------------------------------

local PACK_FORMAT = 2

local function encodedSnapshot(snapshot)
    return base64Encode(DB.Encode(snapshot, true))
end

local function inventoryWeight(record)
    if type(record) ~= "table" then return 0 end
    local value = tonumber(record.value) or tonumber(record[7]) or 1
    local count = tonumber(record.count) or tonumber(record[8]) or 1
    return value * count
end

-- Trims the cheapest stock until the encoded snapshot fits one generation. Runs
-- after packing, so the budget is measured on the bytes that actually ship.
local function trimSnapshot(snapshot, encoded)
    local limit = MAX_CHUNKS * CHUNK_SIZE
    if #encoded <= limit then return encoded, false end

    local packed = snapshot.inventoryFormat == PACK_FORMAT
    local records = {}
    for key, record in pairs(snapshot.inventory or {}) do
        records[#records + 1] = { key = key, record = record, weight = inventoryWeight(record) }
    end
    table.sort(records, function(a, b) return a.weight < b.weight end)

    local removed = 0
    local function rebuild()
        if packed then
            local kept = {}
            for _, entry in ipairs(records) do
                if not entry.dropped then kept[#kept + 1] = entry.record end
            end
            snapshot.inventory = kept
        else
            for _, entry in ipairs(records) do
                if entry.dropped then snapshot.inventory[entry.key] = nil end
            end
        end
        return encodedSnapshot(snapshot)
    end

    local index = 1
    while #encoded > limit and index <= #records do
        for _ = 1, 4 do
            local entry = records[index]
            index = index + 1
            if not entry then break end
            entry.dropped = true
            removed = removed + 1
        end
        encoded = rebuild()
    end
    -- Stock is the cheapest thing to lose; economy, campaign, museum and stats
    -- matter more than the shelves. Never refuse to save over a full stockroom.
    if #encoded > limit then
        for _, entry in ipairs(records) do
            if not entry.dropped then
                entry.dropped = true
                removed = removed + 1
            end
        end
        encoded = rebuild()
    end
    return encoded, removed > 0
end

---------------------------------------------------------------------------
-- Stock packing
---------------------------------------------------------------------------

-- A record's field names cost more than its values in the serializer, and the
-- journal only has a few thousand characters. Stock therefore travels as a
-- fixed tuple: uid, id, name, quality, ilvl, category, value, count, fake.
-- Icons are rebuilt from the item ID at login; the UI falls back to a question
-- mark when the client has no cached icon.
local function packInventory(snapshot)
    local packed = {}
    for uid, record in pairs(snapshot.inventory or {}) do
        if type(record) == "table" and record.name then
            packed[#packed + 1] = {
                tonumber(record.uid) or tonumber(uid) or 0,
                math.floor(tonumber(record.id) or 0),
                tostring(record.name),
                math.floor(tonumber(record.quality) or 1),
                math.floor(tonumber(record.ilvl) or 1),
                tostring(record.category or "misc"),
                math.floor(tonumber(record.value) or 1),
                math.floor(tonumber(record.count) or 1),
                record.counterfeit and 1 or 0,
            }
        end
    end
    table.sort(packed, function(a, b) return a[1] < b[1] end)
    snapshot.inventory = packed
    snapshot.inventoryFormat = PACK_FORMAT
end

local function unpackInventory(data)
    if type(data) ~= "table" or data.inventoryFormat ~= PACK_FORMAT then return false end
    local records = {}
    for _, entry in ipairs(type(data.inventory) == "table" and data.inventory or {}) do
        if type(entry) == "table" and entry[3] and entry[3] ~= "" then
            local uid = math.floor(tonumber(entry[1]) or 0)
            if uid < 1 then uid = #records + 1 end
            local id = math.floor(tonumber(entry[2]) or 0)
            local record = {
                uid = uid,
                id = id > 0 and id or nil,
                name = entry[3],
                quality = math.floor(tonumber(entry[4]) or 1),
                ilvl = math.floor(tonumber(entry[5]) or 1),
                category = entry[6] or "misc",
                value = math.max(1, math.floor(tonumber(entry[7]) or 1)),
                count = math.max(1, math.floor(tonumber(entry[8]) or 1)),
                counterfeit = (entry[9] == 1 or entry[9] == true) or nil,
            }
            if record.id then
                local info = ns.Compat.ItemInstant(record.id)
                record.icon = info and info.icon or nil
            end
            records[uid] = record
        end
    end
    data.inventory = records
    data.inventoryFormat = nil
    return true
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

local function storedBody(name)
    local index = ns.Compat.MacroIndexByName(name)
    if not index or index <= 0 then return nil end
    local existingName, body = ns.Compat.MacroInfo(index)
    if existingName ~= name then return nil end
    return body
end

-- Splits the macro list into the two save generations plus any pre-1.6.4
-- single-generation save left behind by an older install.
local function collectJournal()
    local generations = {}
    for _, generation in ipairs(GENERATIONS) do
        local chunks = {}
        for index = 1, MAX_CHUNKS do
            local parsed = parseChunk(storedBody(chunkName(generation, index)))
            if parsed and parsed.version == 2 and parsed.generation == generation then
                chunks[parsed.index] = parsed
            end
        end
        if next(chunks) then generations[generation] = chunks end
    end

    local legacy = {}
    for index = 1, LEGACY_CHUNKS do
        local parsed = parseChunk(storedBody(legacyName(index)))
        if parsed and parsed.version == 1 then legacy[parsed.index] = parsed end
    end
    return generations, legacy
end

-- Rebuilds one generation's payload. Every inconsistency is rejected here, so
-- only a complete, checksum-clean and committed save can ever become current.
local function assemble(chunks, limit, requireCommit)
    local total
    for index, chunk in pairs(chunks) do
        if not chunk.total or chunk.total < 1 or chunk.total > limit then
            return nil, "invalid journal chunk count"
        end
        if not total then total = chunk.total end
        if chunk.total ~= total then return nil, "journal chunks disagree on length" end
        if index > total then return nil, "journal chunk out of range" end
    end
    if not total then return nil, "empty" end
    if requireCommit and (not chunks[1] or chunks[1].state ~= "c") then
        return nil, "journal save did not finish"
    end

    local parts = {}
    for index = 1, total do
        local chunk = chunks[index]
        if not chunk then return nil, "journal is incomplete" end
        parts[index] = chunk.data
    end
    local encoded = table.concat(parts)
    if checksum(encoded) ~= chunks[1].stamp then
        return nil, "journal checksum mismatch"
    end
    return encoded, total
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

local function scheduleRetry()
    ns.Compat.After(2, function() J.TryLoad() end)
    ns.Compat.After(5, function() J.TryLoad() end)
    ns.Compat.After(10, function() J.TryLoad() end)
end

-- Returns settled, restored. "Settled" means the journal state is known, so a
-- save may replace it; "restored" means this call imported an older run and the
-- macros already hold it.
function J.TryLoad(force)
    if loading then return false, false end
    if loaded and not force then return true, false end
    if force then loaded = false end

    local db = DB.Get()
    if db.settings.macroJournal == false then
        loaded = true
        J.status.error = nil
        return true, false
    end

    if ns.Compat.MacroCount() == nil then
        J.status.error = "macro API unavailable"
        scheduleRetry()
        return false
    end

    local generations, legacy = collectJournal()

    -- Both generations are checked. The highest committed counter wins, so a
    -- pending or half-written generation simply loses to the previous save.
    local best
    for _, name in ipairs(GENERATIONS) do
        local chunks = generations[name]
        if chunks then
            local candidate, candidateTotal = assemble(chunks, MAX_CHUNKS, true)
            local counter = chunks[1] and chunks[1].counter or 0
            if candidate and (not best or counter > best.counter) then
                best = {
                    encoded = candidate,
                    total = candidateTotal,
                    generation = name,
                    counter = counter,
                    stamp = chunks[1] and chunks[1].stamp,
                }
            end
        end
    end

    local encoded, total, generation, counter, loadedStamp
    if best then
        encoded, total, generation, counter = best.encoded, best.total, best.generation, best.counter
        loadedStamp = best.stamp
    elseif next(legacy) then
        loadedStamp = legacy[1] and legacy[1].stamp
        -- Single-generation save from 1.6.3 or earlier: no commit header exists.
        local legacyEncoded, legacyTotal, legacyError = assemble(legacy, LEGACY_CHUNKS, false)
        if not legacyEncoded then
            loaded = true
            J.status.error = legacyError
            return false
        end
        encoded, total = legacyEncoded, legacyTotal
    end

    if not encoded then
        local sawChunks = next(legacy) ~= nil
        for _, name in ipairs(GENERATIONS) do
            if generations[name] then sawChunks = true end
        end
        if sawChunks then
            -- Chunks exist but none is a finished save: the macro list may still
            -- be filling in, or the last save stopped before its commit header.
            J.status.error = "journal is incomplete"
            scheduleRetry()
            return false, false
        end
        -- No chunks at all looks identical on a fresh install and on a client
        -- whose macro list lands a moment after login. Treat the first reads as
        -- provisional and only settle as empty once they keep coming back empty,
        -- because settling early lets the first autosave overwrite a real save.
        if not force and (tonumber(J.status.attempts) or 0) < EMPTY_ATTEMPTS then
            J.status.attempts = (tonumber(J.status.attempts) or 0) + 1
            J.status.empty = true
            J.status.error = nil
            scheduleRetry()
            return false, false
        end
        J.status.attempts = 0
        loaded = true
        J.status.error = nil
        J.status.savedAt = 0
        J.status.chunks = 0
        J.status.stamp = nil
        J.status.generation = nil
        J.status.counter = 0
        J.status.empty = true
        return true, false
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
    local currentPriority = DB.Get()
    if hasProgress(currentPriority) and (currentPriority.savedAt or 0) >= journalAt then
        loaded = true
        J.status.error = nil
        J.status.savedAt = journalAt
        J.status.chunks = total
        J.status.stamp = loadedStamp
        J.status.fingerprint = nil
        J.status.attempts = 0
        J.status.generation = generation
        J.status.counter = counter or 0
        J.status.empty = false
        return true, false
    end

    local repacked = unpackInventory(payload.data)
    if repacked then
        -- Import decodes the text itself, so the unpacked table has to go back
        -- through the same codec for the restore path to stay unchanged.
        text = ns.Serialize.Encode(payload)
    end

    local login = currentPriority.lastSession and currentPriority.lastSession.login
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
    J.status.stamp = loadedStamp
    J.status.fingerprint = nil
    J.status.attempts = 0
    J.status.generation = generation
    J.status.counter = counter or 0
    J.status.empty = false

    if not fresh.settings.journalHintShown then
        fresh.settings.journalHintShown = true
        ns.Print("Progress restored from the macro journal (the beta client is not loading SavedVariables yet).")
    end
    if ns.UI and ns.UI.Refresh then
        local refreshOk = pcall(ns.UI.Refresh)
        if not refreshOk then ns.Debug("UI refresh after journal load failed") end
    end
    return true, true
end

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------

-- Writes one macro and proves it landed: the body is read back and compared
-- with what was sent. A client that truncates, refuses or renames the body
-- fails the save before anything is deleted.
local function writeChunk(name, body)
    local index = ns.Compat.MacroIndexByName(name)
    if index and index > 0 then
        local _, existingBody = ns.Compat.MacroInfo(index)
        if existingBody and not bodyLooksLikeJournal(existingBody) then
            return false, "macro name collision on " .. name
        end
        if existingBody ~= body then
            -- Some clients answer EditMacro with nothing at all even when it
            -- worked, so the read-back below decides, not the return value.
            ns.Compat.EditMacro(index, name, MACRO_ICON, body)
        end
    else
        ns.Compat.CreateMacro(name, MACRO_ICON, body)
    end

    local stored = storedBody(name)
    if stored ~= body then
        if index and index > 0 then return false, "could not update " .. name end
        return false, "could not create " .. name .. " (macro slots may be full)"
    end
    return true
end

-- Delete by name, not by a numeric index that shifts after every delete.
local function deleteGeneration(generation, keepCount)
    if not generation then return end
    for index = (keepCount or 0) + 1, MAX_CHUNKS do
        local name = chunkName(generation, index)
        local macroIndex = ns.Compat.MacroIndexByName(name)
        if macroIndex and macroIndex > 0 then
            local _, body = ns.Compat.MacroInfo(macroIndex)
            if bodyLooksLikeJournal(body) then ns.Compat.DeleteMacro(macroIndex) end
        end
    end
end

local function deleteLegacy()
    for index = 1, LEGACY_CHUNKS do
        local name = legacyName(index)
        local macroIndex = ns.Compat.MacroIndexByName(name)
        if macroIndex and macroIndex > 0 then
            local _, body = ns.Compat.MacroInfo(macroIndex)
            if bodyLooksLikeJournal(body) then ns.Compat.DeleteMacro(macroIndex) end
        end
    end
end

-- Writes a whole generation. The header goes first as pending, every payload
-- chunk is verified, and only then the header is rewritten as committed; until
-- that last verified write this generation can never win at login.
local function writeGeneration(generation, counter, encoded, stamp)
    local total = math.ceil(#encoded / CHUNK_SIZE)
    if total < 1 or total > MAX_CHUNKS then
        return false, "journal does not fit in " .. tostring(MAX_CHUNKS) .. " macros per generation"
    end

    local function bodyFor(index, state)
        local data = encoded:sub((index - 1) * CHUNK_SIZE + 1, index * CHUNK_SIZE)
        return makeChunk(generation, counter, index, total, stamp, state, data)
    end

    local ok, detail = writeChunk(chunkName(generation, 1), bodyFor(1, "p"))
    if not ok then return false, detail end

    for index = 2, total do
        ok, detail = writeChunk(chunkName(generation, index), bodyFor(index, "c"))
        if not ok then return false, detail end
    end

    ok, detail = writeChunk(chunkName(generation, 1), bodyFor(1, "c"))
    if not ok then return false, detail end

    deleteGeneration(generation, total)
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
        reportSaveFailure("macro API unavailable")
        return false
    end

    -- Never write over a journal this session has not read. The macro list can
    -- appear a moment after login, and the first autosave used to replace a
    -- good save with fresh defaults when that happened.
    if not loaded then
        local settled, restored = J.TryLoad()
        if not settled then
            -- Usually just the macro list arriving late. Saying nothing here is
            -- deliberate: the retries and the next tick save on their own, and a
            -- chat warning at login would only alarm a player whose save is fine.
            J.status.error = "waiting for the macro list"
            return false
        end
        if restored then
            -- TryLoad imported the saved run; the macros already hold it.
            lastSave = U.now()
            pending = false
            return true, J.status
        end
    end

    saving = true
    local snapshot = DB.Snapshot()
    -- Pack first: the journal's budget is measured on what is actually written,
    -- and packing is what makes a normal shop fit without losing stock.
    packInventory(snapshot)
    local encoded = encodedSnapshot(snapshot)
    local trimmed
    encoded, trimmed = trimSnapshot(snapshot, encoded)
    if #encoded > MAX_CHUNKS * CHUNK_SIZE then
        saving = false
        reportSaveFailure("journal is too large, even without stock")
        return false
    end

    local stamp = checksum(encoded)

    -- The payload timestamp changes on every save, so compare the shop itself.
    -- Writing 24 macros every half minute rewrites a list the player can see,
    -- and most saves carry identical data.
    snapshot.savedAt = nil
    local fingerprint = checksum(DB.Encode(snapshot, true, 0))
    if J.status.fingerprint == fingerprint and J.status.generation then
        lastSave = U.now()
        pending = false
        J.status.error = nil
        J.status.savedAt = lastSave
        J.status.trimmed = trimmed and true or false
        J.status.empty = false
        return true, J.status
    end

    -- Write the generation that is not current. If nothing was loaded this
    -- session, look first so an existing save is never blindly overwritten.
    if not J.status.generation then
        local generations = collectJournal()
        local newest
        for _, name in ipairs(GENERATIONS) do
            local chunks = generations[name]
            local header = chunks and chunks[1]
            if header and header.state == "c" then
                if not newest or (header.counter or 0) > newest.counter then
                    newest = { name = name, counter = header.counter or 0 }
                end
            end
        end
        if newest then
            J.status.generation = newest.name
            J.status.counter = newest.counter
        end
    end

    local previous = J.status.generation
    local generation = previous == "A" and "B" or "A"
    local counter = (tonumber(J.status.counter) or 0) + 1

    local ok, detail = writeGeneration(generation, counter, encoded, stamp)
    saving = false
    if not ok then
        reportSaveFailure(detail)
        return false
    end

    -- The new generation is complete, verified and committed. Only now is the
    -- previous save allowed to disappear.
    deleteGeneration(previous)
    deleteLegacy()

    lastSave = U.now()
    pending = false
    J.status.error = nil
    J.status.chunks = detail
    J.status.savedAt = lastSave
    J.status.trimmed = trimmed and true or false
    J.status.empty = false
    J.status.stamp = stamp
    J.status.fingerprint = fingerprint
    J.status.generation = generation
    J.status.counter = counter
    return true, J.status
end

-- Saves start early (a short session must still land one) and retry quickly
-- after a failure instead of waiting out the full throttle.
function J.Save()
    if not ns.db or loaded == false then return false end
    local now = U.now()
    if now - startedAt < FIRST_SAVE then return false end
    local wait = J.status.error and RETRY_DELAY or SAVE_THROTTLE
    if now - lastSave < wait and not pending then return false end
    return J.SaveNow()
end

-- Drives the save schedule itself, so a short session still lands a save about
-- ten seconds in instead of waiting for the next thirty-second autosave.
function J.Tick()
    if not loaded then return end
    if pending and not ns.Compat.InCombat() then
        J.SaveNow()
        return
    end
    J.Save()
end

function J.Clear()
    if ns.Compat.MacroCount() == nil then return false end
    for _, generation in ipairs(GENERATIONS) do deleteGeneration(generation) end
    deleteLegacy()
    lastSave = 0
    J.status.savedAt = 0
    J.status.chunks = 0
    J.status.error = nil
    J.status.empty = true
    J.status.stamp = nil
    J.status.fingerprint = nil
    J.status.attempts = 0
    J.status.generation = nil
    J.status.counter = 0
    return true
end

---------------------------------------------------------------------------
-- Presentation and events
---------------------------------------------------------------------------

function J.Active()
    return DB.Get().settings.macroJournal ~= false
end

-- True once TryLoad has settled (restored, empty, or rejected). The splash
-- screen waits for this so a slow macro list cannot make it think the player
-- has never seen it.
function J.Loaded()
    return loaded
end

function J.Report()
    local db = DB.Get()
    local active = db.settings.macroJournal ~= false
    local slots = ns.Compat.MacroCount()
    ns.Print("Macro journal: " .. (active and "|cff7bd66bon|r" or "|cffff5555off|r") ..
        " · " .. (loaded and "loaded this session" or "not loaded yet"))
    ns.Print(string.format("  Chunks: %d/%d · generation %s · macro list: %s",
        J.status.chunks or 0, MAX_CHUNKS, tostring(J.status.generation or "none"),
        slots and (tostring(slots) .. " slot(s) visible") or "|cffff5555unavailable|r"))
    if (J.status.savedAt or 0) > 0 then
        ns.Print("  Last save: " .. U.clock(math.max(0, U.now() - J.status.savedAt)) .. " ago" ..
            (J.status.trimmed and " · stock trimmed to fit" or ""))
    else
        ns.Print("  Last save: none recorded")
    end
    ns.Print(string.format("  This run: %s credits · tier %d · %d stock stack(s)",
        ns.Util.comma(db.credits), db.tier or 1,
        ns.Inventory and ns.Inventory.Count and ns.Inventory.Count() or 0))
    if not active then
        ns.Warn("  The journal is off in Settings; only a backup string survives a logout.")
    elseif J.status.error then
        ns.Warn("  Last error: " .. tostring(J.status.error))
    else
        ns.Print("  No save errors reported this session.")
    end
end

function J.StatusText()
    local status = J.status
    if not J.Active() then return "Macro journal off; use a backup string in Settings." end
    if status.error then return "Journal: " .. tostring(status.error) end
    if (status.savedAt or 0) > 0 then
        local age = math.max(0, U.now() - status.savedAt)
        local trimmed = status.trimmed and " · inventory trimmed" or ""
        return string.format("Journal: %d chunks (gen %s) · saved %s ago%s",
            status.chunks or 0, tostring(status.generation or "?"), U.clock(age), trimmed)
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
