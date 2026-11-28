--[[ Goblin Pawn Stars -------------------------------------------------------
    Core/Journal.lua
    Forever's beta client writes SavedVariables but does not load them back.
    Macro bodies are stored server-side and therefore survive a cold restart, so
    the journal packs a compact snapshot into macro bodies as a fallback.

    Chunks use a short comment header and a base64 payload. Macro bodies are
    capped at 255 characters, so the payload is kept deliberately small and
    inventory is trimmed (lowest value first) if it would not fit.

    Saves alternate between two generations (A and B). A save is a queue of
    single macro operations, handed a few milliseconds a second by the clock, so
    it never writes or deletes more than one chunk per frame; that is what keeps
    a large shop from hitching the client. Every chunk is read back and only the
    final write commits the generation, so the macro list holds one save at rest
    and an interrupted save leaves the previous one intact. Autosaves run every
    five minutes and wait until the shop window and counter are idle. Logout,
    import and `/gps verify` finish any staged save and read every chunk back.

    Loading starts by itself shortly after login but is strictly bounded: at
    most four reads, one counter, no chained retries, and the last attempt always
    settles. A save is refused until a load has settled or the player resets, so
    a fresh session cannot overwrite a run it has not read. Settings → Backup &
    Restore → Load saved repeats one read on demand, and Auto-load there turns the
    login load off.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local J = {}
ns.Journal = J

local CHUNK_SIZE = 210
local MAX_CHUNKS = 12          -- per generation; a save needs two of them
local BUDGET = MAX_CHUNKS * CHUNK_SIZE -- one generation's payload, in base64
local LEGACY_CHUNKS = 24       -- pre-1.6.4 single-generation saves
local PREFIX_V1 = "--GPSJ1:"
local PREFIX_V2 = "--GPSJ2:"
local GENERATIONS = { "A", "B" }
local MACRO_ICON = 134400
local SAVE_THROTTLE = 300
-- A failed macro write is expensive and usually environmental (a full macro
-- list), so back off instead of retrying every tick. The attempt count grows
-- the delay up to the normal autosave interval.
local RETRY_DELAY = 60
local FIRST_SAVE = 300
-- Milliseconds a tick may spend on macro work. One chunk write is allowed even
-- when it alone costs more than this, so a save always makes progress.
local STEP_BUDGET_MS = 8
-- A login load may read the macro list this many times, at these seconds after
-- login, driven by the clock. One counter, no chaining: a journal that will not
-- assemble costs four reads in total and then settles, instead of multiplying
-- reads the way the old retry chains did.
local LOGIN_DELAYS = { 2, 5, 10, 30 }
local LOGIN_ATTEMPTS = 4

local startedAt = U.now()
local lastSave = 0
local saving = false
local staged = nil           -- the save currently spread across ticks
local pending = false
local auto = nil            -- { tries, nextAt } while a login load is pending
local afterSettle = nil     -- one-shot listener for the first settled load
local nextAttempt = 0
local legacyScanned = false

-- U.now() is whole seconds, so a save's duration is measured with GetTime.
local function millis()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    value = ok and tonumber(value) or nil
    return value and value * 1000 or nil
end

J.status = {
    -- False until a save has been loaded or deliberately reset this session.
    -- Every write path checks it, so an unread journal is never overwritten.
    loaded = false,
    -- Which path settled the load (login, manual, import, reset), for /gps journal.
    loadedBy = nil,
    chunks = 0,
    savedAt = 0,
    trimmed = false,
    error = nil,
    generation = nil,
    counter = 0,
    stamp = nil,
    fingerprint = nil,
    attempts = 0,
    saveMs = 0,
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

-- Both success paths end the same way: the journal is no longer in flight and
-- the status describes the save that just landed. `spentMs` is the macro time the
-- queue measured, so a save spread over several ticks never reports the wall
-- clock it spanned; an unchanged save passes nil and reports zero.
local function finishSave(spentMs)
    saving = false
    lastSave = U.now()
    pending = false
    nextAttempt = 0
    J.status.error = nil
    J.status.savedAt = lastSave
    J.status.attempts = 0
    J.status.saveMs = math.max(0, math.floor(tonumber(spentMs) or 0))
    if ns.Perf and (J.status.saveMs or 0) > 0 then
        ns.Perf.RecordValue("journal", J.status.saveMs)
    end
    return true, J.status
end

-- Reasons the journal declines to write without being broken. They must not
-- reach the player as a save failure, or a closed shop window would look like a
-- lost save.
local QUIET = {
    ["journal off"] = true,
    ["in combat"] = true,
    ["journal not loaded"] = true,
    ["busy"] = true,
}

local function quietDetail(detail)
    return QUIET[detail] == true
end

local function abandonSave(detail)
    saving = false
    J.status.attempts = (J.status.attempts or 0) + 1
    reportSaveFailure(detail)
    nextAttempt = U.now() + math.min(SAVE_THROTTLE, RETRY_DELAY * J.status.attempts)
    return false
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

-- The payload timestamp changes on every save, so the fingerprint covers the
-- encoded shop with the savedAt value masked out. Hashing the bytes already in
-- hand avoids a second full encode just to prove nothing changed. If the codec
-- ever stopped writing that key the timestamp would be hashed and every save
-- would look changed, which only costs work, never correctness.
local function payloadFingerprint(text)
    return checksum((text:gsub("s7:savedAtd[^;]*;", "s7:savedAtd;")))
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

-- Packed stock carries its value at 7 and its count at 8 (see packInventory).
local function inventoryWeight(record)
    return (record[7] or 1) * (record[8] or 1)
end

-- Trims the cheapest stock until the encoded snapshot fits one generation. Runs
-- after packing, so the budget is measured on the bytes that actually ship.
--
-- Each pass drops the number of stacks the remaining overflow needs, estimated
-- from the average encoded size of one stack. Dropping four stacks per pass and
-- re-encoding everything made a full stockroom cost dozens of full encodes,
-- which a player felt as a multi-second freeze on every save.
local function trimSnapshot(snapshot, encoded)
    if #encoded <= BUDGET then return encoded, false end

    local records = {}
    for _, record in pairs(snapshot.inventory or {}) do
        records[#records + 1] = record
    end
    local count = #records
    if count == 0 then return encoded, false end

    -- Cheapest first: stock is the least valuable thing to lose, and the order
    -- is what keeps the expensive pieces after a trim.
    table.sort(records, function(a, b) return inventoryWeight(a) < inventoryWeight(b) end)

    -- Re-encodes the shop keeping everything after the `dropped` cheapest stacks.
    local function rebuilt(dropped)
        local kept = {}
        for index = dropped + 1, count do kept[#kept + 1] = records[index] end
        snapshot.inventory = kept
        return encodedSnapshot(snapshot)
    end

    -- One encode without stock gives the fixed cost, so the first pass can drop
    -- close to the right number instead of guessing.
    local fixed = rebuilt(count)
    local perRecord = math.max(1, (#encoded - #fixed) / count)

    local dropped = 0
    for _ = 1, 4 do
        if #encoded <= BUDGET then break end
        local step = math.ceil((#encoded - BUDGET) / perRecord)
        dropped = math.min(count, dropped + math.max(1, step))
        encoded = rebuilt(dropped)
    end
    -- Never refuse to save over a full stockroom: the economy, campaign, museum
    -- and stats matter more than the shelves.
    if #encoded > BUDGET and dropped < count then
        dropped = count
        encoded = rebuilt(count)
    end
    return encoded, dropped > 0
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
    local total = chunks[1] and chunks[1].total
    if not total then
        for _, chunk in pairs(chunks) do
            total = chunk.total
            break
        end
    end
    if not total or total < 1 or total > limit then
        return nil, "invalid journal chunk count"
    end
    if requireCommit and (not chunks[1] or chunks[1].state ~= "c") then
        return nil, "journal save did not finish"
    end

    local parts = {}
    local seen = 0
    for index = 1, total do
        local chunk = chunks[index]
        if not chunk then return nil, "journal is incomplete" end
        if chunk.total ~= total then return nil, "journal chunks disagree on length" end
        parts[index] = chunk.data
        seen = seen + 1
    end
    -- Chunks past `total` are leftovers from an older, larger save in the same
    -- generation slot. They are ignored here and deleted one per tick later.
    if seen < 1 then return nil, "empty" end
    local encoded = table.concat(parts)
    if checksum(encoded) ~= chunks[1].stamp then
        return nil, "journal checksum mismatch"
    end
    return encoded, total
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

-- A settled journal is one whose state is known: nothing to restore, a run
-- restored, or a save that cannot be read and may therefore be replaced. Every
-- outcome settles except "macro API unavailable", which leaves the next attempt
-- free to try again. `origin` only records which path settled it, for /gps
-- journal; the gate itself is the boolean.
local function settle(origin)
    J.status.loaded = true
    J.status.loadedBy = origin or "manual"
end

-- Returns settled, restored, waiting. "Settled" means the journal state is
-- known, so a save may replace it; "restored" means this call imported an older
-- run and the macros already hold it. "Waiting" means the macro list looked
-- empty, which right after login usually means it has not arrived yet: only the
-- automatic login load passes hold, and only it keeps the gate closed for that
-- case. One read: a failure reports why and stops, so even an unreadable journal
-- costs a single scan of the macro list.
function J.TryLoad(origin, hold)
    local who = origin or "manual"
    -- The flag is cleared for the duration of the read and settled by every
    -- outcome except "macro API unavailable". A journal that cannot be assembled
    -- is not a save this addon can ever restore, and blocking writes forever would
    -- strand the session, so settling lets the next save replace the bad chunks.
    J.status.loaded = false
    J.status.loadedBy = nil

    local db = DB.Get()
    if db.settings.macroJournal == false then
        settle(who)
        J.status.error = nil
        return true, false
    end

    if ns.Compat.MacroCount() == nil then
        J.status.error = "macro API unavailable"
        return false, false
    end

    local generations, legacy = collectJournal()
    -- A legacy save is a one-time migration cost: force one cleanup scan on the
    -- next save, then leave the macro list alone unless a save needs slots.
    if next(legacy) then legacyScanned = false end

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
        local legacyEncoded, legacyTotal = assemble(legacy, LEGACY_CHUNKS, false)
        if not legacyEncoded then
            settle(who)
            J.status.error = legacyTotal
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
            -- Chunks exist but none is a finished save: a save stopped before its
            -- commit header and its run is gone, so there is nothing to restore.
            -- Report it and let the next save replace those chunks.
            settle(who)
            J.status.error = "journal is incomplete"
            return false, false
        end
        if hold then
            -- The macro list can still be filling in right after login. Leave
            -- the journal unloaded so no save can stamp defaults over a run that
            -- has not arrived yet; the caller reads again later.
            J.status.error = nil
            return false, false, true
        end
        -- No saved run at all: a fresh install, or a manual load requested before
        -- the macro list arrived. The player can ask again, so adopting the
        -- session here is safe.
        settle(who)
        J.status.error = nil
        J.status.savedAt = 0
        J.status.chunks = 0
        J.status.stamp = nil
        J.status.generation = nil
        J.status.counter = 0
        return true, false
    end

    local text = base64Decode(encoded)
    if not text then
        settle(who)
        J.status.error = "journal payload is corrupt"
        return false
    end
    local payload, err = ns.Serialize.Decode(text)
    if not payload or type(payload.data) ~= "table" then
        settle(who)
        J.status.error = "journal could not be decoded: " .. tostring(err or "bad payload")
        return false
    end
    if payload.addon and payload.addon ~= ns.ADDON then
        settle(who)
        J.status.error = "journal belongs to another addon"
        return false
    end

    local journalAt = tonumber(payload.savedAt) or 0
    local currentPriority = DB.Get()
    if hasProgress(currentPriority) and (currentPriority.savedAt or 0) >= journalAt then
        settle(who)
        J.status.error = nil
        J.status.savedAt = journalAt
        J.status.chunks = total
        J.status.stamp = loadedStamp
        J.status.fingerprint = nil
        J.status.generation = generation
        J.status.counter = counter or 0
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
        -- The payload decoded but could not be adopted. Nothing can ever restore
        -- it, so settle and let the next save replace it instead of leaving the
        -- session with no save path.
        settle(who)
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
    settle(who)
    J.status.error = nil
    J.status.savedAt = journalAt
    J.status.chunks = total
    J.status.stamp = loadedStamp
    J.status.fingerprint = nil
    J.status.generation = generation
    J.status.counter = counter or 0

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
-- Automatic loading
---------------------------------------------------------------------------

-- Arms the bounded login load. The clock drives it rather than a chain of
-- timers, so there is exactly one pending attempt and one counter, and a client
-- that cannot read macros can never multiply the work.
function J.AutoLoad()
    auto = nil
    if J.status.loaded then return false end
    if not J.Active() then return false end
    if DB.Get().settings.autoLoadJournal == false then return false end
    auto = { tries = 0, nextAt = U.now() + LOGIN_DELAYS[1] }
    return true
end

function J.AutoPending()
    return auto ~= nil
end

-- Runs `fn` once when the first load of this session settles. The login summary
-- registers here: at login the journal is still a couple of seconds away, so
-- describing the shop straight away would call every returning player a fresh
-- stall. Already-settled sessions run the callback immediately.
function J.AfterSettle(fn)
    if type(fn) ~= "function" then return end
    if J.status.loaded then
        local ok = pcall(fn)
        if not ok then ns.Debug("journal settle callback failed") end
        return
    end
    afterSettle = fn
end

-- Drains the listener from a tick rather than from settle(), so the restored
-- run's own chat line lands first and the summary describes the loaded shop.
local function drainAfterSettle()
    if not afterSettle or not J.status.loaded then return end
    local fn = afterSettle
    afterSettle = nil
    local ok = pcall(fn)
    if not ok then ns.Debug("journal settle callback failed") end
end

-- A manual load, an import or a reset settles the journal on its own terms.
function J.CancelAutoLoad()
    auto = nil
end

-- Reads the macro list once, then settles, schedules the next bounded attempt,
-- or gives up and settles anyway so the session never loses its save path.
local function tickAutoLoad()
    if not auto then return end
    -- Something else chose a run (Load saved, import, reset) while this was
    -- waiting: that choice wins and the login load stops.
    if J.status.loaded then
        auto = nil
        return
    end
    local now = U.now()
    if now < auto.nextAt then return end
    -- Never read macros in combat. This defers the attempt without spending it,
    -- so the cap still counts only real reads of the macro list.
    if ns.Compat.InCombat() then
        auto.nextAt = now + 5
        return
    end

    auto.tries = auto.tries + 1
    local settled, restored, waiting = J.TryLoad("login", true)
    if restored or settled then
        auto = nil
        return
    end
    if waiting and auto.tries < LOGIN_ATTEMPTS then
        -- The macro list looked empty and may still be filling in. Try again
        -- later; the gate stays closed so no save can run in the meantime.
        auto.nextAt = now + LOGIN_DELAYS[auto.tries + 1]
        return
    end

    -- Out of attempts, or the macro API never appeared. Settle so the session is
    -- not stuck, and say so when the read genuinely failed.
    auto = nil
    settle("login")
    if J.status.error then
        ns.Warn("Saved shop could not be loaded (" .. tostring(J.status.error) ..
            "). Use Settings → Backup & Restore to keep a backup. Type |cffffffff/gps journal|r for details.")
    end
end

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------

-- One macro write, read back and compared. A client can accept a write and
-- store something else, so the body is what decides. Every chunk is verified
-- before the commit header can make the generation current; a failure here
-- aborts the save with the previous generation still intact.
local function writeChunk(name, body)
    local index = ns.Compat.MacroIndexByName(name)
    if index and index > 0 then
        local _, existingBody = ns.Compat.MacroInfo(index)
        if existingBody and not bodyLooksLikeJournal(existingBody) then
            return false, "macro name collision on " .. name, "collision"
        end
        -- The body was just read: an identical chunk needs no write or second
        -- read. On a normal save most payload chunks are unchanged.
        if existingBody == body then return true end
        ns.Compat.EditMacro(index, name, MACRO_ICON, body)
    else
        -- A refused create is the one failure that freeing old chunks can fix.
        if not ns.Compat.CreateMacro(name, MACRO_ICON, body) and storedBody(name) ~= body then
            return false, "could not create " .. name .. " (macro slots may be full)", "create"
        end
    end

    if storedBody(name) ~= body then
        return false, "could not update " .. name, "write"
    end
    return true
end

local function deleteChunk(name)
    local macroIndex = ns.Compat.MacroIndexByName(name)
    if not macroIndex or macroIndex <= 0 then return false end
    local _, body = ns.Compat.MacroInfo(macroIndex)
    if not bodyLooksLikeJournal(body) then return false end
    ns.Compat.DeleteMacro(macroIndex)
    return true
end

-- Delete by name, not by a numeric index that shifts after every delete.
local function deleteGeneration(generation, keepCount)
    if not generation then return end
    for index = (keepCount or 0) + 1, MAX_CHUNKS do
        deleteChunk(chunkName(generation, index))
    end
end

local function legacyChunkNames()
    local names = {}
    for index = 1, LEGACY_CHUNKS do
        local name = legacyName(index)
        local macroIndex = ns.Compat.MacroIndexByName(name)
        if macroIndex and macroIndex > 0 then
            local _, body = ns.Compat.MacroInfo(macroIndex)
            if bodyLooksLikeJournal(body) then names[#names + 1] = name end
        end
    end
    return names
end

local function deleteLegacy()
    local removed = 0
    for _, name in ipairs(legacyChunkNames()) do
        if deleteChunk(name) then removed = removed + 1 end
    end
    legacyScanned = true
    return removed
end

-- One chunk body for the new generation. The first chunk doubles as the
-- header: "p" while the save is in flight, "c" after every payload chunk has
-- been written and read back.
local function jobBody(current, index, state)
    local data = current.encoded:sub((index - 1) * CHUNK_SIZE + 1, index * CHUNK_SIZE)
    return makeChunk(current.generation, current.counter, index, current.total,
        current.stamp, state, data)
end

local function prepareJob(force)
    local db = DB.Get()
    if db.settings.macroJournal == false then return nil, "journal off" end
    -- Nothing is written until the player has loaded a run or reset one, so a
    -- fresh session cannot stamp defaults over a real save. Checked before the
    -- combat deferral, which must not arm a save that will never run.
    if not J.status.loaded then return nil, "journal not loaded" end
    if ns.Compat.InCombat() then
        pending = true
        return nil, "in combat"
    end
    if ns.Compat.MacroCount() == nil then return nil, "macro API unavailable" end

    -- Never write macros while the shop window or a haggle is open. A five
    -- minute autosave can wait for a quiet moment; the player should never see
    -- a hitch in the middle of a sale.
    if not force then
        local uiOpen = ns.UI and type(ns.UI.IsOpen) == "function" and ns.UI.IsOpen()
        if uiOpen or (db.shop and db.shop.current) then
            nextAttempt = U.now() + 20
            return nil, "busy"
        end
    end

    local snapshot = DB.Snapshot()
    packInventory(snapshot)
    local encoded = encodedSnapshot(snapshot)

    -- Most autosaves carry identical data. Skip before trimming: trimming is
    -- the expensive half, and an unchanged save must not rewrite the macros.
    local fingerprint = payloadFingerprint(encoded)
    if not force and J.status.fingerprint == fingerprint and J.status.generation then
        return "unchanged"
    end

    local trimmed
    encoded, trimmed = trimSnapshot(snapshot, encoded)
    if #encoded > BUDGET then
        return nil, "journal is too large, even without stock"
    end
    local total = math.ceil(#encoded / CHUNK_SIZE)
    if total < 1 or total > MAX_CHUNKS then
        return nil, "journal does not fit in " .. tostring(MAX_CHUNKS) ..
            " macros per generation"
    end

    local previous = J.status.generation
    return {
        generation = previous == "A" and "B" or "A",
        previous = previous,
        counter = (J.status.counter or 0) + 1,
        encoded = encoded,
        stamp = checksum(encoded),
        total = total,
        fingerprint = fingerprint,
        trimmed = trimmed and true or false,
    }
end

-- A save is a queue of single macro operations rather than one batch. The
-- clock hands it a few milliseconds a second, so a save can never hold the
-- frame no matter how many chunks the shop needs or how slow the client's macro
-- calls are. The order is unchanged, so crash safety is unchanged: the pending
-- header goes first, every payload chunk is read back, and only the final
-- verified write makes the generation committed.

-- The new generation: header "p", then the payload, then the same header as
-- "c". Until that last write lands this generation can never win at login.
local function buildSteps(job)
    local current = job
    local steps = {
        { kind = "write", name = chunkName(current.generation, 1), index = 1, state = "p" },
    }
    for index = 2, current.total do
        steps[#steps + 1] = {
            kind = "write", name = chunkName(current.generation, index),
            index = index, state = "c",
        }
    end
    steps[#steps + 1] = {
        kind = "write", name = chunkName(current.generation, 1), index = 1, state = "c",
    }
    job.steps, job.cursor = steps, 1
end

-- Cleanup runs only after the commit, one name per step: the retired generation,
-- chunks left over from a larger save, and pre-1.6.4 legacy chunks.
local function buildCleanup(job)
    local current = job
    local steps = {}
    if current.previous and current.previous ~= current.generation then
        for index = 1, MAX_CHUNKS do
            steps[#steps + 1] = { kind = "delete", name = chunkName(current.previous, index) }
        end
    end
    for index = current.total + 1, MAX_CHUNKS do
        steps[#steps + 1] = { kind = "delete", name = chunkName(current.generation, index) }
    end
    if not legacyScanned then
        legacyScanned = true
        for index = 1, LEGACY_CHUNKS do
            steps[#steps + 1] = { kind = "delete", name = legacyName(index) }
        end
    end
    job.steps, job.cursor = steps, 1
end

-- Performs one queued operation. Returns ok, then true when the save is finished
-- or a failure table when it has to stop.
local function stepJob(job)
    if job.cursor > #job.steps then
        if job.phase == "write" then
            job.phase = "cleanup"
            buildCleanup(job)
            return true, false
        end
        return true, true
    end

    local step = job.steps[job.cursor]
    if step.kind == "delete" then
        job.cursor = job.cursor + 1
        deleteChunk(step.name)
        return true, false
    end

    local current = job
    local ok, detail, kind = writeChunk(step.name, jobBody(current, step.index, step.state))
    if ok then
        job.cursor = job.cursor + 1
        return true, false
    end

    -- A refused create is the one failure that more macros can fix. It is rare,
    -- so the scan stays inside this step instead of being queued.
    if kind == "create" and not job.freed then
        job.freed = true
        if deleteLegacy() > 0 then return true, false end
    end

    if kind == "create" and current.previous and not job.rewrote
        and (ns.Compat.MacroCount() or 0) >= 36
        and current.total <= (J.status.chunks or 0) then
        -- Completely full list: rewrite the committed generation in place.
        -- This gives up the fallback, but a save that lands beats a dead
        -- journal, and the new payload cannot be larger than the old one. The
        -- failed partial generation is removed first so its chunks cannot
        -- linger on the list.
        job.rewrote = true
        local failed = current.generation
        current.generation = current.previous
        current.previous = nil
        for index = 1, MAX_CHUNKS do deleteChunk(chunkName(failed, index)) end
        job.phase = "write"
        buildSteps(job)
        return true, false
    end

    return false, { detail = detail, kind = kind }
end

-- Runs queued operations until the budget is spent, or to the end when no
-- budget is given. At least one operation always runs, so a save made of slow
-- calls still makes progress one call per tick.
local function advance(job, budgetMs)
    local started = millis()
    local ops = 0
    -- Only the time spent inside this save is reported, never the wall clock it
    -- spanned across ticks.
    local function spent()
        local now = millis()
        if started and now then
            job.busyMs = (job.busyMs or 0) + math.max(0, now - started)
        end
    end
    while true do
        local ok, result = stepJob(job)
        if not ok then spent() return false, result end
        if result == true then spent() return true end
        ops = ops + 1
        if budgetMs then
            local now = millis()
            if now and (now - started) >= budgetMs then spent() return nil end
        end
        -- A queue this long means something is wrong; stop for this tick and
        -- let the next one continue instead of spinning. A synchronous save has
        -- no budget to spend, so only the absolute guard applies to it.
        if budgetMs and ops >= 64 then spent() return nil end
        if ops >= 4096 then spent() return nil end
    end
end

local function finishJob(job)
    local current = job
    J.status.chunks = current.total
    J.status.trimmed = current.trimmed
    J.status.stamp = current.stamp
    J.status.fingerprint = current.fingerprint
    J.status.generation = current.generation
    J.status.counter = current.counter
    J.status.attempts = 0
    return finishSave(job.busyMs)
end

-- Finishes whatever is staged, synchronously. Save Now, logout, an import and
-- /gps verify must see a committed save, never a half-written generation.
local function flushStaged()
    if not staged then return true, J.status end
    local job = staged
    staged = nil
    local called, ok, failure = pcall(advance, job, nil)
    if not called then
        saving = false
        return abandonSave("the save errored: " .. tostring(ok))
    end
    if ok ~= true then
        saving = false
        return abandonSave(failure and failure.detail or "the staged save failed")
    end
    return finishJob(job)
end

function J.SaveNow(force)
    if staged then
        -- A forced call (Save Now, logout, import, /gps verify) finishes the queue
        -- before it returns. A gameplay checkpoint lets the in-flight save finish
        -- on its own ticks instead of bunching the rest of the writes into this
        -- frame; the next autosave picks up whatever changed.
        if not force then return false, J.status end
        local ok = flushStaged()
        if not ok then return false, J.status end
    end
    if saving then return false, J.status end
    saving = true

    local job, detail = prepareJob(force)
    if job == "unchanged" then
        if not legacyScanned then deleteLegacy() end
        saving = false
        return finishSave(nil)
    elseif not job then
        saving = false
        if quietDetail(detail) then return false, J.status end
        reportSaveFailure(detail or "could not prepare a save")
        nextAttempt = U.now() + RETRY_DELAY
        return false, J.status
    end

    job.phase = "write"
    buildSteps(job)
    local called, ok, failure = pcall(advance, job, nil)
    saving = false
    if not called then
        return abandonSave("the save errored: " .. tostring(ok))
    end
    -- Never commit a generation the queue did not finish.
    if ok ~= true then
        return abandonSave(failure and failure.detail or "the save did not finish")
    end
    return finishJob(job)
end

function J.Save()
    if not ns.db or not J.status.loaded then return false end
    if saving or staged then return false end
    local now = U.now()
    if now - startedAt < FIRST_SAVE then return false end
    if now < nextAttempt then return false end
    local attempts = math.max(1, tonumber(J.status.attempts) or 1)
    local wait = J.status.error
        and math.min(SAVE_THROTTLE, RETRY_DELAY * attempts) or SAVE_THROTTLE
    if now - lastSave < wait and not pending then return false end

    -- The autosave stages the job and spends one slice of it now; the rest lands
    -- one tick at a time. Nothing here writes the whole generation in one frame.
    saving = true
    local job, detail = prepareJob(false)
    saving = false
    if job == "unchanged" then
        if not legacyScanned then deleteLegacy() end
        return finishSave(nil)
    elseif not job then
        if not quietDetail(detail) then
            reportSaveFailure(detail or "could not prepare a save")
            nextAttempt = U.now() + RETRY_DELAY
        end
        return false
    end

    job.phase = "write"
    buildSteps(job)
    staged = job
    local called, ok, failure = pcall(advance, job, STEP_BUDGET_MS)
    if not called then
        staged = nil
        return abandonSave("the save errored: " .. tostring(ok))
    end
    if ok == false then
        staged = nil
        return abandonSave(failure and failure.detail or "the save failed")
    elseif ok == true then
        staged = nil
        return finishJob(job)
    end
    return false, J.status
end

-- Drives the save schedule itself. The clock calls this once a second; the
-- journal only writes when the five-minute interval is due and the shop is idle,
-- and it advances at most one time budget of macro work per second.
function J.Tick()
    tickAutoLoad()
    drainAfterSettle()
    if not J.status.loaded then return end
    if staged then
        local job = staged
        local called, ok, failure = pcall(advance, job, STEP_BUDGET_MS)
        if not called then
            staged = nil
            return abandonSave("the save errored: " .. tostring(ok))
        end
        if ok == false then
            staged = nil
            abandonSave(failure and failure.detail or "the save failed")
        elseif ok == true then
            staged = nil
            finishJob(job)
        end
        return
    end
    if pending and not ns.Compat.InCombat() then
        -- A save deferred by combat should not fire the instant the fight ends.
        -- Give the player twenty seconds to loot and move on.
        pending = false
        nextAttempt = math.max(nextAttempt, U.now() + 20)
        return
    end
    J.Save()
end

function J.Clear()
    if ns.Compat.MacroCount() == nil then return false end
    -- A reset wins over a save that is half written: its chunks go below, and it
    -- also cancels any login load that has not run yet.
    auto = nil
    staged = nil
    saving = false
    for _, generation in ipairs(GENERATIONS) do deleteGeneration(generation) end
    deleteLegacy()
    legacyScanned = false
    nextAttempt = 0
    lastSave = 0
    J.status.savedAt = 0
    J.status.chunks = 0
    J.status.error = nil
    J.status.stamp = nil
    J.status.fingerprint = nil
    J.status.attempts = 0
    J.status.generation = nil
    J.status.counter = 0
    J.status.saveMs = 0
    -- The macros are empty now, so this session owns them: saving starts here.
    settle("reset")
    return true
end

---------------------------------------------------------------------------
-- Presentation and events
---------------------------------------------------------------------------

function J.Active()
    return DB.Get().settings.macroJournal ~= false
end

-- True once a load has settled (restored, empty, or rejected) or a reset
-- adopted the macro list. Every write path needs it, so the header and the
-- login line read it too.
function J.Loaded()
    return J.status.loaded == true
end

-- Lets another explicit choice (importing a pasted backup) adopt the save path.
function J.MarkLoaded()
    auto = nil
    settle("import")
end

-- The on-demand load behind Settings → Backup & Restore → Load saved. One read,
-- one answer: a failure is reported to the player instead of being retried
-- behind their back.
function J.Load()
    if not J.Active() then
        return false, "the macro journal is off in Settings; use a backup string instead"
    end
    if ns.Compat.InCombat() then
        return false, "cannot read the macro list in combat; try again after the fight"
    end

    auto = nil
    local settled, restored = J.TryLoad("manual")
    drainAfterSettle()
    if restored then return true, "Saved run loaded." end
    if settled then
        return true, "No saved run was found. This session is a fresh shop and now saves."
    end
    return false, "the journal could not be read: " ..
        tostring(J.status.error or "unknown reason")
end

function J.Report()
    local db = DB.Get()
    local active = db.settings.macroJournal ~= false
    local slots = ns.Compat.MacroCount()
    local loadText
    if J.status.loaded then
        loadText = "loaded this session" ..
            (J.status.loadedBy and (" (" .. tostring(J.status.loadedBy) .. ")") or "")
    elseif auto then
        loadText = "|cffe0c060loading the saved shop|r"
    else
        loadText = "|cffe0c060not loaded — Settings → Backup & Restore → Load saved|r"
    end
    ns.Print("Macro journal: " .. (active and "|cff7bd66bon|r" or "|cffff5555off|r") ..
        " · " .. loadText ..
        " · auto-load " .. (db.settings.autoLoadJournal == false and "off" or "on"))
    ns.Print(string.format("  Chunks: %d/%d · generation %s · macro list: %s",
        J.status.chunks or 0, MAX_CHUNKS, tostring(J.status.generation or "none"),
        slots and (tostring(slots) .. " slot(s) visible") or "|cffff5555unavailable|r"))
    if (J.status.savedAt or 0) > 0 then
        local spent = tonumber(J.status.saveMs) or 0
        ns.Print("  Last save: " .. U.clock(math.max(0, U.now() - J.status.savedAt)) .. " ago" ..
            (spent > 0 and string.format(" (took %d ms)", spent)
                or " (batched)") ..
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

-- One short line for the header. The full story stays in /gps journal; this is
-- what a player can read without being told to run a command.
function J.Health()
    local status = J.status
    if not J.Active() then return "|cffff6b5esave off|r", "off" end
    if status.error then return "|cffff5555save error|r", "error" end
    if not status.loaded then
        if auto then return "|cffe0c060loading saved shop|r", "pending" end
        return "|cffe0c060load progress|r", "pending"
    end
    -- A journal restored at login is not a save this session. Keep the header
    -- on "save pending" until the first five-minute save lands, instead of
    -- showing a stale age that makes a healthy journal look broken.
    if (status.savedAt or 0) > startedAt then
        local age = math.max(0, U.now() - status.savedAt)
        if age <= 330 then return "|cff7bd66bsaved " .. U.clock(age) .. " ago|r", "ok" end
        return "|cffe0c060saved " .. U.clock(age) .. " ago|r", "stale"
    end
    return "|cffe0c060save pending|r", "pending"
end

-- Reads the committed journal back off the macro list and compares it with the
-- run in memory. This answers "did my progress actually save?" without a
-- logout, and it is the check every save bug report should start with.
function J.Verify()
    local db = DB.Get()
    if not J.Active() then
        return false, "the macro journal is off; use a backup string in Settings"
    end
    if ns.Compat.MacroCount() == nil then
        return false, "the macro API is unavailable on this client"
    end
    if not J.status.loaded then
        return false, "nothing is loaded this session; the saved shop is still being read, or press Load saved in Settings → Backup & Restore"
    end
    if ns.Compat.InCombat() then
        return false, "cannot save in combat; try again after the fight"
    end

    local written = J.SaveNow(true)
    if not written then
        return false, "the journal did not save: " .. tostring(J.status.error or "unknown reason")
    end

    local generations = collectJournal()
    local best
    for _, name in ipairs(GENERATIONS) do
        local chunks = generations[name]
        if chunks then
            local candidate = assemble(chunks, MAX_CHUNKS, true)
            local counter = chunks[1] and chunks[1].counter or 0
            if candidate and (not best or counter > best.counter) then
                best = { encoded = candidate, generation = name, counter = counter }
            end
        end
    end
    if not best then return false, "no committed save was found in the macro list" end

    local text = base64Decode(best.encoded)
    if not text then return false, "the saved payload is not readable base64" end
    local payload, decodeError = ns.Serialize.Decode(text)
    if not payload then return false, "the saved data did not decode: " .. tostring(decodeError) end
    local stored = payload.data or {}
    local storedStats = stored.stats or {}

    -- Stock is deliberately not compared: a journal over budget drops the
    -- lowest-value stacks, so a smaller inventory is a correct save.
    local mismatches = {}
    if (stored.credits or 0) ~= (db.credits or 0) then
        mismatches[#mismatches + 1] = string.format("credits %s vs %s",
            U.comma(stored.credits or 0), U.comma(db.credits or 0))
    end
    if (stored.tier or 1) ~= (db.tier or 1) then
        mismatches[#mismatches + 1] = string.format("tier %s vs %s",
            tostring(stored.tier), tostring(db.tier))
    end
    if (storedStats.sales or 0) ~= (db.stats.sales or 0) then
        mismatches[#mismatches + 1] = string.format("sales %d vs %d",
            storedStats.sales or 0, db.stats.sales or 0)
    end
    if (storedStats.customersServed or 0) ~= (db.stats.customersServed or 0) then
        mismatches[#mismatches + 1] = string.format("served %d vs %d",
            storedStats.customersServed or 0, db.stats.customersServed or 0)
    end
    if #mismatches > 0 then
        return false, string.format("generation %s does not match this run (%s)",
            tostring(best.generation), table.concat(mismatches, ", "))
    end

    local stock = 0
    for _ in pairs(stored.inventory or {}) do stock = stock + 1 end
    return true, string.format("generation %s verified: %s gc, %d sales, %d stock stacks",
        tostring(best.generation), U.comma(stored.credits or 0), storedStats.sales or 0, stock)
end

function J.StatusText()
    local status = J.status
    if not J.Active() then return "Macro journal off; use a backup string in Settings." end
    if status.error then return "Journal: " .. tostring(status.error) end
    if not status.loaded then
        if auto then return "Journal: loading the saved shop from the macro list…" end
        return "Journal not loaded this session. Settings → Backup & Restore → Load saved."
    end
    if (status.savedAt or 0) > 0 then
        local age = math.max(0, U.now() - status.savedAt)
        local trimmed = status.trimmed and " · inventory trimmed" or ""
        return string.format("Journal: %d chunks (gen %s) · saved %s ago%s",
            status.chunks or 0, tostring(status.generation or "?"), U.clock(age), trimmed)
    end
    return "Journal empty; the next autosave will fill it."
end

J.events = ns.Compat.EventFrame({
    -- The only automatic read. It arms one bounded login load; the clock performs
    -- the reads, so a bad journal costs at most LOGIN_ATTEMPTS scans and cannot
    -- stall anyone. Auto-load is a setting, and Load saved works either way.
    PLAYER_LOGIN = function()
        local ok = pcall(J.AutoLoad)
        if not ok then ns.Debug("journal auto-load did not arm") end
    end,
    PLAYER_LOGOUT = function()
        J.SaveNow(true)
    end,
})
