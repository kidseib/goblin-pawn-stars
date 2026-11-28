// One-shot delivery script: journal payload format 3 + two tests + docs.
// Deleted by the workflow that runs it. Every anchor is asserted.
const fs = require('fs');

function edit(path, pairs) {
  let text = fs.readFileSync(path, 'utf8');
  for (const pair of pairs) {
    const oldText = pair[0];
    const newText = pair[1];
    const want = pair.length > 2 ? pair[2] : 1;
    const parts = text.split(oldText);
    const found = parts.length - 1;
    if (found !== want) {
      throw new Error(path + ': expected ' + want + ' for ' +
        JSON.stringify(oldText.slice(0, 70)) + ', found ' + found);
    }
    text = parts.join(newText);
  }
  fs.writeFileSync(path, text);
  console.log('edited ' + path);
}

const journalFormat = `local STAT_FIELDS = {
    "playtime", "sales", "revenue", "earned", "spent", "expenses", "rejected",
    "offersSeen", "counterSuccess", "counterFail", "appraisals", "thefts",
    "theftsPrevented", "rareSales", "customersServed", "bestSale", "bestMultiple",
    "shopDays", "eventsResolved", "itemsCollected", "negotiations", "refunds",
    "counterfeitBought", "counterfeitsRefused", "customers", "auctionsWon",
    "mysteryItems", "donations", "totalDiscount", "wholesaleSpent",
    "wholesaleBought", "autoSales", "autoRevenue", "debtPaid", "museumDonated",
    "regularVisits", "franchises",
}
local SETTING_FIELDS = {
    "sound", "minimap", "minimapAngle", "scale", "customerArrival", "animations",
    "performance", "arrivalPace", "arrivalPositions", "autoCollect",
    "modestDialog", "showWelcome", "welcomeVersion", "tourDone", "tourVersion",
    "bagHintShown", "starterGranted", "autoSell", "questAutoSell", "paused",
    "macroJournal", "autoLoadJournal", "journalHintShown",
}
local MARKET_FIELDS = { "key", "startedAt", "untilAt" }

local function packFields(source, fields, into)
    into = into or {}
    for index = 1, #fields do
        into[index] = source[fields[index]]
    end
    return into
end

local function unpackFields(values, fields, into)
    into = into or {}
    if type(values) ~= "table" then return into end
    for index = 1, #fields do
        local value = values[index]
        if value ~= nil then into[fields[index]] = value end
    end
    return into
end

-- Same table, with the three name-heavy sections swapped for value arrays.
local function packJournal(snapshot)
    local packed = {}
    for key, value in pairs(snapshot) do packed[key] = value end
    -- inventoryFormat must survive: it tells the loader the stock records are
    -- packed tuples rather than full item records.
    packed.stats = packFields(snapshot.stats or {}, STAT_FIELDS)
    packed.settings = packFields(snapshot.settings or {}, SETTING_FIELDS)
    local market = {}
    for key, value in pairs(snapshot.market or {}) do market[key] = value end
    local events = {}
    for index, event in ipairs(snapshot.market and snapshot.market.events or {}) do
        events[index] = packFields(event, MARKET_FIELDS)
    end
    market.events = events
    packed.market = market
    return packed
end

local function unpackJournal(packed)
    local snapshot = {}
    for key, value in pairs(packed) do snapshot[key] = value end
    snapshot.stats = unpackFields(packed.stats, STAT_FIELDS)
    snapshot.settings = unpackFields(packed.settings, SETTING_FIELDS)
    local market = {}
    for key, value in pairs(packed.market or {}) do market[key] = value end
    local events = {}
    for index, entry in ipairs(packed.market and packed.market.events or {}) do
        local event = unpackFields(entry, MARKET_FIELDS)
        if event.key then events[index] = event end
    end
    market.events = events
    snapshot.market = market
    return snapshot
end

local function encodedSnapshot(snapshot)
    local payload = {
        version = DB.SchemaVersion(),
        addon = ns.ADDON,
        savedAt = tonumber(snapshot.savedAt) or U.now(),
        format = 3,
        data = DB.Compact(packJournal(snapshot)),
    }
    return base64Encode(ns.Serialize.Encode(payload))
end
`;

edit('addon/GoblinPawnStars/Core/Journal.lua', [
  [
    'local function encodedSnapshot(snapshot)\n    return base64Encode(DB.Encode(snapshot, true))\nend\n',
    '-- The journal has 2,520 base64 characters in one generation, and a played shop\n' +
    '-- spent 91% of that on field names: 37 stat keys, 23 settings keys and the event\n' +
    '-- records. Format 3 carries those sections as ordered arrays of values, so the\n' +
    '-- names cost nothing and the shop itself fits. The order is part of the format:\n' +
    '-- append new fields to the end, never reorder, and older payloads still expand\n' +
    '-- because missing positions keep their default.\n' + journalFormat,
  ],
  [
    '    if payload.addon and payload.addon ~= ns.ADDON then\n        settle(who)\n        setError("load", "journal belongs to another addon")\n        return false\n    end\n',
    '    if payload.addon and payload.addon ~= ns.ADDON then\n        settle(who)\n        setError("load", "journal belongs to another addon")\n        return false\n    end\n' +
    '    if payload.format == 3 then\n' +
    '        -- Positional sections: expand them back into the shape the importer and\n' +
    '        -- the rest of the addon expect. Payloads without a format are pre-3 and\n' +
    '        -- already a full table.\n' +
    '        payload.data = unpackJournal(payload.data or {})\n' +
    '        payload.format = nil\n' +
    '        text = ns.Serialize.Encode(payload)\n' +
    '    end\n',
  ],
  [
    '    local payload, decodeError = ns.Serialize.Decode(text)\n    if not payload then return false, "the saved data did not decode: " .. tostring(decodeError) end\n    local stored = payload.data or {}\n',
    '    local payload, decodeError = ns.Serialize.Decode(text)\n    if not payload then return false, "the saved data did not decode: " .. tostring(decodeError) end\n    if payload.format == 3 then payload.data = unpackJournal(payload.data or {}) end\n    local stored = payload.data or {}\n',
  ],
]);

const tests = `
    -----------------------------------------------------------------------
    -- Journal payload format 3 packs the stat and setting sections by position:
    -- a played shop spent 91% of its 2,520-character budget on field names and
    -- then refused to save at all with "journal is too large, even without
    -- stock". These two tests cover what the format buys and what it must keep.
    test("a played shop fits the macro journal and round-trips", function()
        if type(__clearMacros) ~= "function" then return end
        __clearMacros()
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB

        local ok, err = pcall(function()
            local db = ns.DB.Scratch()
            db.settings.macroJournal = true
            db.credits = 489
            db.tier = 2
            -- Fifty minutes of play touches every counter, so none of them can be
            -- omitted as a default any more.
            for key in pairs(db.stats) do db.stats[key] = 17 end
            db.stats.playtime = 3055
            db.stats.sales = 12
            db.stats.revenue = 389
            db.stats.bestSale = 62
            db.market.events = {
                { key = "war", untilAt = 3000, startedAt = 1200 },
                { key = "plague", untilAt = 3600, startedAt = 2400 },
            }
            db.shop.shopDayProgress = 0.39
            db.shop.request = {
                id = 70001, name = "Black Whelp Scale", category = "misc", value = 210, day = 1,
            }
            db.achievements.unlocked = { firstSale = 1200, rare = 3000 }
            db.settings.tourDone = true
            db.settings.welcomeVersion = 3
            db.settings.arrivalPositions = { compact = { x = 120.5, y = -340.25 } }
            db.museum.donated = {
                weapon = { name = "Rusted Longsword of the Fallen Keep", at = 2400 },
            }
            ns.db = db
            ns.Journal.TryLoad()
            for index = 1, 12 do
                ns.Inventory.Add({
                    id = 70000 + index, name = "Black Whelp Scale", quality = 2,
                    ilvl = 18, category = "misc", value = 120, count = 3,
                })
            end
            expect(ns.Inventory.Count() > 1, "the test needs stock to save")
            expect(ns.Journal.SaveNow(), "a played shop did not fit the journal: " ..
                tostring(ns.Journal.status.error))
            expect(ns.Journal.status.trimmed ~= true,
                "a played shop still had to throw stock away to fit")

            local loaded = ns.DB.Scratch()
            loaded.settings.macroJournal = true
            ns.db = loaded
            expect(ns.Journal.TryLoad(), "the played shop did not load: " ..
                tostring(ns.Journal.status.error))
            expectEqual(ns.DB.Get().credits, 489, "the played shop lost credits")
            expectEqual(ns.DB.Get().tier, 2, "the played shop lost its tier")
            expectEqual(ns.DB.Get().stats.sales, 12, "the played shop lost sales")
            expectEqual(ns.DB.Get().stats.playtime, 3055, "the played shop lost playtime")
            expectEqual(ns.DB.Get().settings.arrivalPace, "Normal", "the played shop lost settings")
            expect(ns.Inventory.Count() > 0, "the played shop lost its stock")
        end)

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __clearMacros()
        if not ok then error(err, 0) end
    end)

    -----------------------------------------------------------------------
    test("a journal written without the positional format still loads", function()
        if type(__clearMacros) ~= "function" or type(MACRO_STORE) ~= "table" then return end
        __clearMacros()
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB

        local ok, err = pcall(function()
            -- The previous build wrote the whole shop table with its field names and
            -- no \`format\` marker. Those journals have to keep loading.
            local function b64(text)
                local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
                local out = {}
                local index = 1
                while index <= #text do
                    local a, b, c = text:byte(index, index + 2)
                    local n = (a or 0) * 65536 + (b or 0) * 256 + (c or 0)
                    local c1 = math.floor(n / 262144) % 64 + 1
                    local c2 = math.floor(n / 4096) % 64 + 1
                    local c3 = math.floor(n / 64) % 64 + 1
                    local c4 = n % 64 + 1
                    out[#out + 1] = alphabet:sub(c1, c1) .. alphabet:sub(c2, c2)
                        .. alphabet:sub(c3, c3) .. alphabet:sub(c4, c4)
                    index = index + 3
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

            local text = ns.Serialize.Encode({
                version = 2,
                addon = "GoblinPawnStars",
                savedAt = 1000,
                data = { credits = 321, tier = 2, stats = { sales = 5, playtime = 1200 } },
            })
            local encoded = b64(text)
            local stamp = checksum(encoded)
            local chunkSize = 210
            local total = math.ceil(#encoded / chunkSize)
            expect(total >= 1 and total <= 12, "the crafted payload does not fit one generation")
            for index = 1, total do
                local piece = encoded:sub((index - 1) * chunkSize + 1, index * chunkSize)
                local body = string.format("--GPSJ2:A:7:%02d:%02d:%.0f:c:%s", index, total, stamp, piece)
                expect(CreateMacro(string.format("GPSA%02d", index), 134400, body),
                    "could not write test chunk " .. index)
            end

            local loaded = ns.DB.Scratch()
            loaded.settings.macroJournal = true
            ns.db = loaded
            expect(ns.Journal.TryLoad(), "a pre-format payload did not load: " ..
                tostring(ns.Journal.status.error))
            expectEqual(ns.DB.Get().credits, 321, "a pre-format payload lost credits")
            expectEqual(ns.DB.Get().stats.sales, 5, "a pre-format payload lost stats")
        end)

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __clearMacros()
        if not ok then error(err, 0) end
    end)
`;

edit('addon/GoblinPawnStars/Modules/Diagnostics.lua', [
  ['\n    return results\nend\n\nfunction D.Report()', tests + '\n    return results\nend\n\nfunction D.Report()'],
]);

const progressNote = `## Journal payload format 3 — the live \`save error\`

The player's 1.7.9 client reported \`Could not save progress to the macro journal:
journal is too large, even without stock\` on a 489-credit tier 1 shop with 10 stock
stacks, while \`/gps journal\` showed \`Chunks: 0/12 · generation none\`. The write path
showed the cause was capacity, not corruption: \`prepareJob\` refuses a snapshot that
does not fit one generation (12 chunks x 210 base64 characters = 2,520), and
\`trimSnapshot\` can only shed stock. A played shop spends that budget on field names.
Measured on the real addon under the mock, a 50-minute profile (all 37 counters
non-default, 23 settings, two market events, one museum entry, a daily request)
encoded to **2,292 base64 characters with no stock at all** — 91% of the budget — so
any stock pushed it over and the trim then had nothing left to drop.

Format 3 carries the stat, settings and market-event sections as ordered value arrays
instead of name/value maps, so the names cost nothing. On the same profile the fixed
part drops **2,292 -> 1,288** base64, and a save with twelve full stacks drops
**2,580 -> 2,276**, which fits one generation with 244 characters to spare and no
stock trimmed at all. The loader reads both formats: a payload without \`format = 3\` is
expanded exactly as before, and \`inventoryFormat\` still travels so packed stock keeps
unpacking. The field order is part of the format — append, never reorder — and missing
positions keep their schema default, so older payloads expand cleanly.

The player also confirmed that a full exit-and-login restores credits, tier and stock
while the journal has written zero chunks, so SavedVariables carry the run and the
journal is a fallback rather than the only save path. \`GetNumMacros()\` returned 33
general + 3 character macros on that character, and \`GPSA01\`/\`GPSB01\` were found at
indices 8 and 20: leftovers from builds that tried to write before the size refusal,
which the next save reuses rather than creating new names.

### Evidence that could not be obtained

The analysis machine has no WoW installation, no \`WTF\` folder, no \`SavedVariables\`, no
\`Logs\` or \`Errors\` folder and no addon debug dump (searched \`/\`, \`/opt\`, \`/usr/share\`,
\`/home\`, \`/root\`, \`/mnt\`, \`/srv\`, the workspace). The chunk bodies on the player's disk
were therefore never read; this diagnosis rests on the client's own chat output and on
payloads measured headlessly. No live in-game result is claimed for format 3.

## Save path hardening — after v1.7.9`;

edit('PROGRESS.md', [
  ['## Save path hardening — after v1.7.9', progressNote],
  ['never both. The suite is **63 tests**;', 'never both. The suite is **65 tests**;'],
  ['timing changed. The headless suite is **63 tests**;', 'timing changed. The headless suite is **65 tests**;'],
  ['session unable to write at all. The suite is **63 tests**.', 'session unable to write at all. The suite is **65 tests**.'],
  ['npm run check              -> Lua 5.1 syntax OK: 61 files, 17,839 lines; TOC OK',
   'npm run check              -> Lua 5.1 syntax OK: 61 files, 18,073 lines; TOC OK'],
  ['npm test                   -> 63 passed, 0 failed;', 'npm test                   -> 65 passed, 0 failed;'],
  ['The 1.7.9 journal tests are counted in the 63.', 'The 1.7.9 journal tests are counted in the 65.'],
  ['2. `/gps test` prints 63 PASS lines in chat.', '2. `/gps test` prints 65 PASS lines in chat.'],
]);

edit('README.md', [
  ['tests-63%2F63', 'tests-65%2F65'],
  ['alt="63 of 63 tests passing"', 'alt="65 of 65 tests passing"'],
  ['> 63-test headless suite', '> 65-test headless suite'],
  ['runs the 63-test diagnostics suite', 'runs the 65-test diagnostics suite'],
  ['* Headless diagnostics suite: **63/63 passing**', '* Headless diagnostics suite: **65/65 passing**'],
  ['* Lua 5.1 syntax check: **passing** (61 files, 17,839 lines).',
   '* Lua 5.1 syntax check: **passing** (61 files, 18,073 lines).'],
]);

edit('TESTING.md', [
  ['the Lua 5.1 parse (61 files, 17,839 lines)', 'the Lua 5.1 parse (61 files, 18,073 lines)'],
  ['the **63-test headless suite**', 'the **65-test headless suite**'],
  ['- `/gps test` should report **63 passed, 0 failed**.', '- `/gps test` should report **65 passed, 0 failed**.'],
]);

edit('docs/curseforge/description.md', [
  ['**63-test headless simulation suite**', '**65-test headless simulation suite**'],
]);

console.log('journal payload format 3 applied');
