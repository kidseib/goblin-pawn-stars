--[[ Goblin Pawn Stars -------------------------------------------------------
    Core/Persist.lua
    SavedVariables schema, migrations, defaults and the copy-paste backup codec.

    IMPORTANT (WoW Forever beta, build 1.60.x): the client writes SavedVariables
    on exit but currently does not load them back at login. The addon therefore
    also offers an Export/Import string in Settings so progression can be carried
    between sessions, and it works unchanged once Blizzard restores SV loading.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = {}
ns.DB = DB

local SCHEMA_VERSION = 1

local CATEGORY_KEYS = {
    "weapon", "armor", "ore", "herb", "leather", "cloth",
    "gem", "enchant", "consumable", "recipe", "misc", "pet",
}

local function defaults()
    local marketIndex = {}
    for _, key in ipairs(CATEGORY_KEYS) do marketIndex[key] = 1.0 end

    return {
        version = SCHEMA_VERSION,
        createdAt = U.now(),
        savedAt = 0,
        credits = 250,
        reputation = 10,
        tier = 1,
        nextUid = 1,
        inventory = {},
        upgrades = {},
        employees = {},
        achievements = {},
        history = {},
        stats = {
            playtime = 0,
            sales = 0,
            revenue = 0,
            earned = 0,
            spent = 0,
            expenses = 0,
            rejected = 0,
            offersSeen = 0,
            counterSuccess = 0,
            counterFail = 0,
            appraisals = 0,
            thefts = 0,
            theftsPrevented = 0,
            rareSales = 0,
            customersServed = 0,
            bestSale = 0,
            bestMultiple = 0,
            shopDays = 0,
            eventsResolved = 0,
            itemsCollected = 0,
            negotiations = 0,
            refunds = 0,
            counterfeitBought = 0,
            counterfeitsRefused = 0,
            customers = 0,
            auctionsWon = 0,
            mysteryItems = 0,
            donations = 0,
            totalDiscount = 0,
            wholesaleSpent = 0,
            wholesaleBought = 0,
            autoSales = 0,
            autoRevenue = 0,
            debtPaid = 0,
            museumDonated = 0,
            regularVisits = 0,
            franchises = 0,
        },
        market = {
            idx = marketIndex,
            events = {},
            drift = 0,
            lastEventAt = 0,
        },
        shop = {
            waiting = {},
            current = nil,
            nextArrival = 180,
            arrivalTimingVersion = 2,
            lastArrivalAt = 0,
            request = nil,
            requestDay = nil,
            shopDayProgress = 0,
            wholesale = {
                lots = {},
                nextRestock = 0,
                restocks = 0,
            },
        },
        campaign = {
            payments = 0,
            paid = 0,
            completed = false,
            mode = "campaign",
            ending = nil,
            startedAt = 0,
        },
        prestige = {
            level = 0,
            marks = 0,
            franchises = 0,
        },
        museum = {
            donated = {},
            completed = false,
            unlocked = false,
        },
        regular = {
            visits = 0,
            done = false,
            unlocked = false,
            nextAt = 0,
            lastStory = nil,
        },
        settings = {
            sound = true,
            minimap = true,
            minimapAngle = 195,
            scale = 1.0,
            customerArrival = "Animated",
            animations = true,
            performance = false,
            arrivalPace = "Normal",
            arrivalPositions = {},
            autoCollect = true,
            modestDialog = false,
            showWelcome = true,
            welcomeVersion = nil,
            tourDone = false,
            tourVersion = nil,
            bagHintShown = false,
            starterGranted = false,
            autoSell = true,
            questAutoSell = false,
            paused = false,
            macroJournal = true,
            journalHintShown = false,
        },
        baseline = nil,
        lastSession = {
            login = U.now(),
            version = ns.VERSION,
        },
    }
end

---------------------------------------------------------------------------
-- Compact payloads
---------------------------------------------------------------------------

-- Drops every value that already matches the schema default, so a save only
-- carries what actually changed. The macro journal is limited to a few thousand
-- characters; an untrimmed snapshot spends most of that budget on zeroed stats
-- and default settings, which is what made the journal refuse to write at all.
-- normalize() rebuilds every omitted key on load.
function DB.Compact(data)
    if type(data) ~= "table" then return data end
    local template = defaults()
    local function walk(value, fallback)
        if type(value) ~= "table" then return value end
        local out = {}
        for key, entry in pairs(value) do
            local base = type(fallback) == "table" and fallback[key] or nil
            if type(entry) == "table" then
                local sub = walk(entry, base)
                if next(sub) ~= nil or type(base) ~= "table" then out[key] = sub end
            elseif entry ~= base then
                out[key] = entry
            end
        end
        return out
    end
    return walk(data, template)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local function normalize(db)
    local oldShop = type(db) == "table" and db.shop
    local oldCountdown = type(oldShop) == "table" and not oldShop.arrivalTimingVersion
        and tonumber(oldShop.nextArrival)
    db = U.applyDefaults(db, defaults())
    if oldCountdown then db.shop.nextArrival = math.max(0, oldCountdown * 2) end
    db.version = SCHEMA_VERSION

    -- Arrays must stay arrays even after a broken/empty import.
    if type(db.inventory) ~= "table" then db.inventory = {} end
    if type(db.history) ~= "table" then db.history = {} end
    if type(db.achievements) ~= "table" then db.achievements = {} end
    if type(db.employees) ~= "table" then db.employees = {} end
    if type(db.upgrades) ~= "table" then db.upgrades = {} end
    if type(db.market.events) ~= "table" then db.market.events = {} end
    if type(db.shop.waiting) ~= "table" then db.shop.waiting = {} end
    if type(db.shop.wholesale) ~= "table" then db.shop.wholesale = { lots = {}, nextRestock = 0, restocks = 0 } end
    if type(db.shop.wholesale.lots) ~= "table" then db.shop.wholesale.lots = {} end
    if type(db.stats) ~= "table" then db.stats = defaults().stats end
    if type(db.campaign) ~= "table" then db.campaign = defaults().campaign end
    if type(db.prestige) ~= "table" then db.prestige = defaults().prestige end
    if type(db.museum) ~= "table" then db.museum = defaults().museum end
    if type(db.museum.donated) ~= "table" then db.museum.donated = {} end
    if type(db.regular) ~= "table" then db.regular = defaults().regular end
    db.savedAt = math.max(0, tonumber(db.savedAt) or 0)
    db.campaign.payments = U.clamp(math.floor(tonumber(db.campaign.payments) or 0), 0, 3)
    db.campaign.paid = math.max(0, math.floor(tonumber(db.campaign.paid) or 0))
    db.campaign.completed = db.campaign.completed and true or false
    if db.campaign.mode ~= "ending" and db.campaign.mode ~= "endless" then
        db.campaign.mode = db.campaign.completed and "endless" or "campaign"
    end
    db.prestige.level = math.max(0, math.floor(tonumber(db.prestige.level) or 0))
    db.prestige.marks = math.max(0, math.floor(tonumber(db.prestige.marks) or 0))
    db.prestige.franchises = math.max(0, math.floor(tonumber(db.prestige.franchises) or 0))
    db.museum.completed = db.museum.completed and true or false
    db.museum.unlocked = db.museum.unlocked and true or false
    db.regular.visits = U.clamp(math.floor(tonumber(db.regular.visits) or 0), 0, 3)
    db.regular.done = db.regular.done and true or false
    db.regular.unlocked = db.regular.unlocked and true or (db.campaign.payments > 0)
    db.regular.nextAt = math.max(0, math.floor(tonumber(db.regular.nextAt) or 0))

    for _, key in ipairs(CATEGORY_KEYS) do
        if type(db.market.idx[key]) ~= "number" then db.market.idx[key] = 1.0 end
    end

    db.credits = math.max(0, math.floor(tonumber(db.credits) or 250))
    db.reputation = U.clamp(tonumber(db.reputation) or 0, 0, 1000)
    db.tier = U.clamp(math.floor(tonumber(db.tier) or 1), 1, #ns.Data.Tiers)
    db.nextUid = math.max(1, math.floor(tonumber(db.nextUid) or 1))

    for uid, record in pairs(db.inventory) do
        if type(record) ~= "table" or not record.name then
            db.inventory[uid] = nil
        else
            record.count = math.max(1, math.floor(tonumber(record.count) or 1))
            record.value = math.max(1, math.floor(tonumber(record.value) or 1))
            record.uid = tonumber(record.uid) or tonumber(uid) or 1
        end
    end

    -- Drop stale customer references pointing at sold items, and customers whose
    -- opening offer or hidden ceiling did not survive the save. Without both the
    -- negotiation window renders "0 gc" and no counter can ever land.
    local function cleanCustomer(customer)
        if type(customer) ~= "table" or not customer.itemUid
            or not db.inventory[customer.itemUid] then
            return nil
        end
        local offer = tonumber(customer.offer)
        local maxPay = tonumber(customer.maxPay)
        if not offer or offer < 1 or not maxPay or maxPay < offer then return nil end
        customer.offer = math.floor(offer)
        customer.maxPay = math.floor(maxPay)
        customer.patience = math.max(0, math.floor(tonumber(customer.patience) or 0))
        customer.patienceMax = math.max(1, math.floor(tonumber(customer.patienceMax) or customer.patience))
        return customer
    end

    db.shop.current = cleanCustomer(db.shop.current)
    local waiting = {}
    for _, customer in ipairs(db.shop.waiting) do
        local clean = cleanCustomer(customer)
        if clean then waiting[#waiting + 1] = clean end
    end
    db.shop.waiting = waiting

    return db
end

-- Test/repair entry point: the same repair pass the loader runs.
DB.Normalize = normalize

-- The client can hand SavedVariables to the addon after the files have already
-- built a fresh database. Without this the session keeps running on defaults and
-- the next save writes those defaults over the real character data, which wiped
-- progress (and the welcome flag) on every logout.
function DB.Sync()
    -- Tests and diagnostics run on throwaway tables; they must never adopt the
    -- player's real database through this path.
    if DB.scratch then return false end
    local stored = _G.GoblinPawnStarsDB
    if type(stored) ~= "table" or stored == ns.db then return false end
    -- A table the client supplies empty is not data; never adopt nothing.
    if not next(stored) then return false end
    local current = ns.db
    if current and (tonumber(current.savedAt) or 0) > (tonumber(stored.savedAt) or 0) then
        -- This session is ahead of what the client just handed over; adopting it
        -- would roll progress back.
        return false
    end
    ns.db = normalize(stored)
    _G.GoblinPawnStarsDB = ns.db
    return true
end

function DB.Get()
    if not ns.db then DB.Init() end
    DB.Sync()
    return ns.db
end

function DB.Init()
    local stored = _G.GoblinPawnStarsDB
    if type(stored) ~= "table" then stored = {} end
    ns.db = normalize(stored)
    DB.scratch = false
    -- Do not stamp savedAt here. The macro journal compares this value with its
    -- own timestamp; a fresh client starting at 0 must accept the journal.
    DB.Save(true)
    return ns.db
end

function DB.Save(skipStamp)
    if not ns.db then return end
    -- Never stamp a session's defaults over a table the client loaded late.
    DB.Sync()
    if not skipStamp then ns.db.savedAt = U.now() end
    _G.GoblinPawnStarsDB = ns.db
    if ns.Journal then ns.Journal.Save() end
end

-- Small helper so UI code can credit the authors consistently.
function DB.Credit()
    return ns.CREDIT or "ErrorSeib & Buffy (Codebuff)"
end

-- A throwaway database for diagnostics and tests. Never touches the global.
function DB.Scratch()
    local db = normalize({})
    -- Diagnostics must never write test data into the real account macros.
    -- Journal tests switch this back on explicitly.
    db.settings.macroJournal = false
    DB.scratch = true
    return db
end

function DB.IsLive()
    return ns.db ~= nil and ns.db == _G.GoblinPawnStarsDB
end

-- Resetting the live shop normally clears the journal and writes a fresh one.
-- Franchise passes deferSave so the old journal stays intact until it has built
-- the replacement state; a crash can then never leave an empty journal behind.
function DB.Reset(deferSave)
    local live = DB.IsLive()
    if live and not deferSave and ns.Journal and ns.Journal.Clear then
        ns.Journal.Clear()
    end
    ns.db = normalize(defaults())
    if live then
        _G.GoblinPawnStarsDB = ns.db
        if not deferSave then DB.Save() end
    end
    return ns.db
end

function DB.SchemaVersion()
    return SCHEMA_VERSION
end

---------------------------------------------------------------------------
-- Compact, self-contained serialization (no loadstring, no library)
---------------------------------------------------------------------------

local S = {}
ns.Serialize = S

local function isArray(tbl)
    local count = 0
    for key in pairs(tbl) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false, 0 end
        count = count + 1
    end
    for index = 1, count do
        if tbl[index] == nil then return false, 0 end
    end
    return true, count
end

local function encodeValue(value, out)
    local kind = type(value)
    if kind == "nil" then
        out[#out + 1] = "n"
    elseif kind == "boolean" then
        out[#out + 1] = value and "b1" or "b0"
    elseif kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            out[#out + 1] = "d0;"
        else
            -- Lua 5.1 formats a number with "%.14g" in tostring anyway, and
            -- the journal encodes thousands of them per save.
            out[#out + 1] = "d" .. tostring(value) .. ";"
        end
    elseif kind == "string" then
        out[#out + 1] = "s" .. #value .. ":" .. value
    elseif kind == "table" then
        local array, count = isArray(value)
        if array then
            out[#out + 1] = "a" .. count .. ":"
            for index = 1, count do encodeValue(value[index], out) end
        else
            local keys = {}
            for key in pairs(value) do
                local keyType = type(key)
                if keyType == "string" or keyType == "number" or keyType == "boolean" then
                    keys[#keys + 1] = key
                end
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            out[#out + 1] = "m" .. #keys .. ":"
            for index = 1, #keys do
                encodeValue(keys[index], out)
                encodeValue(value[keys[index]], out)
            end
        end
    else
        out[#out + 1] = "n"
    end
end

function S.Encode(value)
    local out = {}
    encodeValue(value, out)
    return table.concat(out)
end

local function decodeValue(text, state)
    local tag = text:sub(state.pos, state.pos)
    state.pos = state.pos + 1
    if tag == "n" then return nil end
    if tag == "b" then
        local bit = text:sub(state.pos, state.pos)
        state.pos = state.pos + 1
        return bit == "1"
    end
    if tag == "d" then
        local stop = text:find(";", state.pos, true)
        if not stop then error("unterminated number") end
        local number = tonumber(text:sub(state.pos, stop - 1))
        state.pos = stop + 1
        if number == nil then error("bad number") end
        return number
    end
    if tag == "s" then
        local colon = text:find(":", state.pos, true)
        if not colon then error("bad string header") end
        local length = tonumber(text:sub(state.pos, colon - 1))
        if not length then error("bad string length") end
        local value = text:sub(colon + 1, colon + length)
        state.pos = colon + length + 1
        return value
    end
    if tag == "a" or tag == "m" then
        local colon = text:find(":", state.pos, true)
        if not colon then error("bad table header") end
        local count = tonumber(text:sub(state.pos, colon - 1))
        if not count then error("bad table size") end
        state.pos = colon + 1
        local result = {}
        if tag == "a" then
            for index = 1, count do
                result[index] = decodeValue(text, state)
            end
        else
            for _ = 1, count do
                local key = decodeValue(text, state)
                result[key] = decodeValue(text, state)
            end
        end
        return result
    end
    error("unknown tag '" .. tostring(tag) .. "' at " .. tostring(state.pos - 1))
end

function S.Decode(text)
    if type(text) ~= "string" or text == "" then return nil, "empty string" end
    local state = { pos = 1 }
    local ok, value = pcall(decodeValue, text, state)
    if not ok then return nil, tostring(value) end
    if type(value) ~= "table" then return nil, "payload is not a table" end
    return value, nil, state.pos - 1
end

---------------------------------------------------------------------------
-- Backup / restore
---------------------------------------------------------------------------

function DB.Export()
    local payload = {
        version = SCHEMA_VERSION,
        addon = ns.ADDON,
        savedAt = U.now(),
        data = ns.db,
    }
    return S.Encode(payload)
end

function DB.Import(text, skipSave)
    if type(text) ~= "string" then return false, "nothing to import" end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    local payload, err = S.Decode(text)
    if not payload then return false, err or "could not decode backup" end
    if payload.addon and payload.addon ~= ns.ADDON then
        return false, "that backup belongs to another addon"
    end
    local data = payload.data or payload
    if type(data) ~= "table" then
        return false, "backup is missing shop data"
    end
    -- Compact payloads (the macro journal) omit keys equal to their default, so
    -- credits can legitimately be absent. Only untagged pasted strings must
    -- carry the old marker.
    if not payload.addon and type(data.credits) ~= "number" then
        return false, "backup is missing shop data"
    end
    -- Import replaces the active database in memory, even when the caller is
    -- restoring a journal and asks to skip persistence. Bind before returning
    -- so an immediate payment, donation, or reset operates on the active table.
    ns.db = normalize(data)
    _G.GoblinPawnStarsDB = ns.db
    DB.scratch = false
    if not skipSave then
        DB.Save()
        if ns.Journal and ns.Journal.SaveNow then ns.Journal.SaveNow(true) end
    end
    return true
end

-- The macro journal cannot fit the full 250-entry ledger and live customer
-- queue. It stores the shop itself: economy, progression, campaign, museum and
-- regular. Arrivals and wholesale offers are regenerated after login.
function DB.Snapshot()
    local db = DB.Get()
    local snap = {}
    for key, value in pairs(db) do snap[key] = value end
    snap.savedAt = U.now()
    snap.history = {}
    snap.baseline = nil

    -- Stock records keep only what the shop needs to draw and sell them. The
    -- numeric class IDs, acquisition time and source are add-time metadata and
    -- cost several dozen characters per item in a save that is already short on
    -- room.
    snap.inventory = {}
    for uid, record in pairs(db.inventory or {}) do
        if type(record) == "table" then
            snap.inventory[uid] = {
                uid = record.uid or uid,
                id = record.id,
                name = record.name,
                icon = record.icon,
                quality = record.quality,
                ilvl = record.ilvl,
                category = record.category,
                value = record.value,
                count = record.count,
                description = record.description,
                counterfeit = record.counterfeit or nil,
            }
        end
    end

    local shop = {}
    for key, value in pairs(db.shop or {}) do shop[key] = value end
    shop.waiting = {}
    shop.current = nil
    shop.encounter = nil
    shop.encounterResult = nil
    shop.wholesale = {
        lots = {},
        nextRestock = 0,
        restocks = (db.shop and db.shop.wholesale and db.shop.wholesale.restocks) or 0,
    }
    snap.shop = shop
    return snap
end

-- savedAt is overridable so a caller can encode the same state twice and get
-- the same bytes (the journal uses that to tell whether anything changed).
function DB.Encode(data, minimize, savedAt)
    if minimize then data = DB.Compact(data) end
    local payload = {
        version = SCHEMA_VERSION,
        addon = ns.ADDON,
        savedAt = tonumber(savedAt) or U.now(),
        data = data,
    }
    return S.Encode(payload)
end

---------------------------------------------------------------------------
-- Savings hooks
---------------------------------------------------------------------------

DB.events = ns.Compat.EventFrame({
    PLAYER_LOGOUT = function()
        DB.Save()
    end,
})
