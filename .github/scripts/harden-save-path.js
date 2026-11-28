// Applies the save-path hardening edits. Every anchor is asserted, so a moved or
// duplicated block fails loudly instead of silently editing the wrong place.
// Deleted by the workflow that runs it.
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
      throw new Error(
        path + ': expected ' + want + ' match(es) for ' +
        JSON.stringify(oldText.slice(0, 70)) + ', found ' + found);
    }
    text = parts.join(newText);
  }
  fs.writeFileSync(path, text);
  console.log('edited ' + path);
}

// ---------------------------------------------------------------------------
// Core/Journal.lua — the write path
// ---------------------------------------------------------------------------
edit('addon/GoblinPawnStars/Core/Journal.lua', [
  [
    'local legacyScanned = false\n',
    'local legacyScanned = false\nlocal dropPartial = nil     -- set below; abandons the half-written generation\n',
  ],
  [
    'local function abandonSave(detail)\n    saving = false\n    J.status.attempts = (J.status.attempts or 0) + 1',
    'local function abandonSave(detail, job)\n    saving = false\n' +
    '    -- A half-written target generation must not be left on the list: its chunks\n' +
    '    -- hold slots the next attempt needs, and on a full list that deadlock never\n' +
    '    -- heals. The committed generation is never touched here.\n' +
    '    if dropPartial then dropPartial(job) end\n' +
    '    J.status.attempts = (J.status.attempts or 0) + 1',
  ],
  [
    '    if #encoded > BUDGET and dropped < count then\n        dropped = count\n        encoded = rebuilt(count)\n    end\n    return encoded, dropped > 0\nend\n',
    '    if #encoded > BUDGET and dropped < count then\n        dropped = count\n        encoded = rebuilt(count)\n    end\n    return encoded, dropped > 0\nend\n\n' +
    '-- Cuts the optional halves of a snapshot until its encoded form fits a name\n' +
    '-- budget. Stock goes first because it is replaceable, then the museum list, then\n' +
    '-- the cosmetic settings; credits, tier, stats and campaign are never dropped, so\n' +
    '-- a shop that cannot fit still saves its economy and progression instead of\n' +
    '-- reporting an error the player can never clear.\n' +
    'local function shrinkSnapshot(snapshot, maxChunks)\n' +
    '    local limit = math.max(1, maxChunks or MAX_CHUNKS) * CHUNK_SIZE\n' +
    '    local encoded = encodedSnapshot(snapshot)\n' +
    '    if #encoded <= limit then return encoded end\n' +
    '    snapshot.inventory = {}\n' +
    '    encoded = encodedSnapshot(snapshot)\n' +
    '    if #encoded <= limit then return encoded end\n' +
    '    if type(snapshot.museum) == "table" then\n' +
    '        snapshot.museum.donated = {}\n' +
    '        encoded = encodedSnapshot(snapshot)\n' +
    '        if #encoded <= limit then return encoded end\n' +
    '    end\n' +
    '    snapshot.settings = nil\n' +
    '    encoded = encodedSnapshot(snapshot)\n' +
    '    if #encoded <= limit then return encoded end\n' +
    '    return nil\n' +
    'end\n',
  ],
  [
    '        stamp = checksum(encoded),\n        total = total,\n        fingerprint = fingerprint,\n        trimmed = trimmed and true or false,\n    }',
    '        stamp = checksum(encoded),\n        total = total,\n        fingerprint = fingerprint,\n        trimmed = trimmed and true or false,\n' +
    '        -- Kept for the refused-write path below: a save that cannot create a\n' +
    '        -- name re-encodes this snapshot to fit the names it already owns.\n' +
    '        snapshot = snapshot,\n    }',
  ],
  [
    '    local trimmed\n    encoded, trimmed = trimSnapshot(snapshot, encoded)\n    if #encoded > BUDGET then\n        return nil, "journal is too large, even without stock"\n    end',
    '    local trimmed\n    encoded, trimmed = trimSnapshot(snapshot, encoded)\n    if #encoded > BUDGET then\n' +
    '        -- The shop itself does not fit one generation: drop the optional blocks\n' +
    '        -- and save the economy instead of refusing every save from now on.\n' +
    '        local shrunk = shrinkSnapshot(snapshot, MAX_CHUNKS)\n' +
    '        if not shrunk then return nil, "journal is too large, even without stock" end\n' +
    '        encoded, trimmed = shrunk, true\n    end',
  ],
  [
    'local function deleteLegacy()\n    local removed = 0\n    for _, name in ipairs(legacyChunkNames()) do\n        if deleteChunk(name) then removed = removed + 1 end\n    end\n    legacyScanned = true\n    return removed\nend\n',
    'local function deleteLegacy()\n    local removed = 0\n    for _, name in ipairs(legacyChunkNames()) do\n        if deleteChunk(name) then removed = removed + 1 end\n    end\n    legacyScanned = true\n    return removed\nend\n\n' +
    '-- Hands the macro list back every journal name the committed save does not own:\n' +
    '-- a generation left behind by an interrupted save and surplus chunks of a larger\n' +
    '-- one. Only bodies that look like journal chunks are deleted, so a player macro\n' +
    '-- is never touched. Returns how many names were freed.\n' +
    'local function reclaimSlots(generation, keepCount)\n' +
    '    local freed = 0\n' +
    '    for _, candidate in ipairs(GENERATIONS) do\n' +
    '        local first = 1\n' +
    '        if candidate == generation then first = (keepCount or 0) + 1 end\n' +
    '        for index = first, MAX_CHUNKS do\n' +
    '            if deleteChunk(chunkName(candidate, index)) then freed = freed + 1 end\n' +
    '        end\n' +
    '    end\n' +
    '    return freed\n' +
    'end\n\n' +
    '-- Deletes the chunks a failed save wrote into a generation that is not the\n' +
    '-- committed one, so the next attempt starts from a list with room.\n' +
    'function dropPartial(job)\n' +
    '    if not job or not job.generation then return 0 end\n' +
    '    if job.generation == J.status.generation then return 0 end\n' +
    '    local freed = 0\n' +
    '    for index = 1, MAX_CHUNKS do\n' +
    '        if deleteChunk(chunkName(job.generation, index)) then freed = freed + 1 end\n' +
    '    end\n' +
    '    return freed\n' +
    'end\n\n' +
    '-- Reshapes a queued save so it fits the chunk names the committed generation\n' +
    '-- already owns. Only reached when the list refuses a new name.\n' +
    'local function fitPayload(job, maxChunks)\n' +
    '    if not job.snapshot then return false end\n' +
    '    local encoded = shrinkSnapshot(job.snapshot, maxChunks)\n' +
    '    if not encoded then return false end\n' +
    '    job.encoded = encoded\n' +
    '    job.total = math.max(1, math.ceil(#encoded / CHUNK_SIZE))\n' +
    '    job.stamp = checksum(encoded)\n' +
    '    job.fingerprint = payloadFingerprint(encoded)\n' +
    '    job.trimmed = true\n' +
    '    return true\n' +
    'end\n',
  ],
  [
    '    if kind == "create" and current.previous and not job.rewrote\n        and (ns.Compat.MacroCount() or 0) >= 36\n        and current.total <= (J.status.chunks or 0) then\n        -- Completely full list: rewrite the committed generation in place.\n        -- This gives up the fallback, but a save that lands beats a dead\n        -- journal, and the new payload cannot be larger than the old one. The\n        -- failed partial generation is removed first so its chunks cannot\n        -- linger on the list.\n        job.rewrote = true\n        local failed = current.generation\n        current.generation = current.previous\n        current.previous = nil\n        for index = 1, MAX_CHUNKS do deleteChunk(chunkName(failed, index)) end\n        job.phase = "write"\n        buildSteps(job)\n        return true, false\n    end\n\n    return false, { detail = detail, kind = kind }',
    '    -- The list refused a name and freeing legacy chunks did not help. Rewrite the\n' +
    '    -- generation that is already on the list instead: those names are the\n' +
    '    -- journal\'s own, so no create is needed and a player\'s macro cannot collide\n' +
    '    -- with them. The payload is cut down to the chunk count already there, so a\n' +
    '    -- full list degrades to a smaller save instead of an error that never clears.\n' +
    '    -- This gives up the fallback generation, but a save that lands beats a dead\n' +
    '    -- journal.\n' +
    '    if not job.rewrote and (kind == "create" or kind == "collision") then\n' +
    '        local committed = J.status.generation\n' +
    '        local have = tonumber(J.status.chunks) or 0\n' +
    '        if committed and committed ~= current.generation and have >= 1\n' +
    '            and fitPayload(job, have) then\n' +
    '            job.rewrote = true\n' +
    '            -- The half-written target can never be committed now; its names go\n' +
    '            -- back to the list before the rewrite starts.\n' +
    '            for index = 1, MAX_CHUNKS do deleteChunk(chunkName(current.generation, index)) end\n' +
    '            current.generation = committed\n' +
    '            current.previous = nil\n' +
    '            job.phase = "write"\n' +
    '            buildSteps(job)\n' +
    '            return true, false\n' +
    '        end\n' +
    '    end\n\n' +
    '    -- A first save into a full list has no committed copy to fall back on, so the\n' +
    '    -- only thing it may spend is the journal\'s own leftovers.\n' +
    '    if kind == "create" and not job.reclaimed then\n' +
    '        job.reclaimed = true\n' +
    '        if reclaimSlots(J.status.generation, J.status.chunks) > 0 then return true, false end\n' +
    '    end\n\n' +
    '    return false, { detail = detail, kind = kind }',
  ],
  [
    'abandonSave("the save errored: " .. tostring(ok))',
    'abandonSave("the save errored: " .. tostring(ok), job)',
    4,
  ],
  [
    'abandonSave(failure and failure.detail or "the staged save failed")',
    'abandonSave(failure and failure.detail or "the staged save failed", job)',
  ],
  [
    'abandonSave(failure and failure.detail or "the save did not finish")',
    'abandonSave(failure and failure.detail or "the save did not finish", job)',
  ],
  [
    'abandonSave(failure and failure.detail or "the save failed")',
    'abandonSave(failure and failure.detail or "the save failed", job)',
    2,
  ],
]);

// ---------------------------------------------------------------------------
// tools/mock_wow.lua — a macro cap the tests can lower
// ---------------------------------------------------------------------------
edit('tools/mock_wow.lua', [
  [
    'function CreateMacro(name, icon, body)\n    local index = 1\n    while MACRO_STORE[index] do index = index + 1 end\n    if index > 36 then return nil end',
    '-- The client refuses a new macro once the list is full. The cap is a global so a\n' +
    '-- test can lower it and prove the journal copes with a list smaller than the\n' +
    '-- 36-slot list the mock models by default.\n' +
    'MACRO_CAP = 36\n\n' +
    'function __setMacroCap(cap)\n' +
    '    MACRO_CAP = tonumber(cap) or 36\n' +
    'end\n\n' +
    'function CreateMacro(name, icon, body)\n    local index = 1\n    while MACRO_STORE[index] do index = index + 1 end\n    if index > MACRO_CAP then return nil end',
  ],
]);

// ---------------------------------------------------------------------------
// Modules/Diagnostics.lua — four tests, each failing before the fix
// ---------------------------------------------------------------------------
const anchor = '        expectEqual(ns.DB.Get().credits, 2222, "a failed commit destroyed the previous save")\n\n        ns.db = real\n        _G.GoblinPawnStarsDB = realGlobal\n        __clearMacros()\n    end)\n';

const tests = `
    -----------------------------------------------------------------------
    -- These four tests fill the client macro list on purpose. Each one cleans up
    -- through pcall so a failure cannot leave the list full and cap the tests
    -- that follow, which would hide the real cause behind five cascade failures.
    test("a save at the macro cap rewrites the committed generation", function()
        if type(__clearMacros) ~= "function" or type(__setMacroCap) ~= "function" then return end
        __clearMacros()
        __setMacroCap(18)
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB

        local function journalMacros()
            local count = 0
            for _, macro in pairs(MACRO_STORE) do
                if type(macro.name) == "string" and macro.name:match("^GPS[ABJ]%d%d$") then
                    count = count + 1
                end
            end
            return count
        end

        local ok, err = pcall(function()
            local db = ns.DB.Scratch()
            db.settings.macroJournal = true
            db.credits = 700
            db.tier = 2
            db.stats.sales = 4
            ns.db = db
            ns.Journal.TryLoad()
            expect(ns.Journal.SaveNow(), "seed save failed: " .. tostring(ns.Journal.status.error))
            local chunks = ns.Journal.status.chunks
            expect(chunks > 1, "the test needs a multi-chunk save")

            -- A player whose macro list is already full: every slot the journal
            -- does not own is taken, so a new chunk name cannot be created.
            for index = 1, 18 - chunks do
                CreateMacro("PLAYERSLOT" .. index, 134400, "/say goblin " .. index)
            end
            expectEqual(ns.Compat.MacroCount(), 18, "the macro list is not at its cap")

            db.credits = 4242
            db.stats.sales = 11
            expect(ns.Journal.SaveNow(), "a save at the macro cap failed: " ..
                tostring(ns.Journal.status.error))
            expect(ns.Journal.status.error == nil, "a save at the macro cap reported an error")
            expect(journalMacros() <= chunks,
                "a save at the macro cap spent slots it did not have: " .. journalMacros())

            local loaded = ns.DB.Scratch()
            loaded.settings.macroJournal = true
            ns.db = loaded
            expect(ns.Journal.TryLoad(), "the save made at the macro cap did not load: " ..
                tostring(ns.Journal.status.error))
            expectEqual(ns.DB.Get().credits, 4242, "a save at the macro cap lost credits")
            expectEqual(ns.DB.Get().stats.sales, 11, "a save at the macro cap lost sales")
        end)

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __setMacroCap(36)
        __clearMacros()
        if not ok then error(err, 0) end
    end)

    -----------------------------------------------------------------------
    test("an interrupted generation on a full list does not block the next save", function()
        if type(__clearMacros) ~= "function" or type(__setMacroCap) ~= "function" then return end
        __clearMacros()
        __setMacroCap(24)
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB

        local function journalMacros()
            local count = 0
            for _, macro in pairs(MACRO_STORE) do
                if type(macro.name) == "string" and macro.name:match("^GPS[ABJ]%d%d$") then
                    count = count + 1
                end
            end
            return count
        end

        local ok, err = pcall(function()
            local db = ns.DB.Scratch()
            db.settings.macroJournal = true
            db.credits = 500
            db.tier = 1
            ns.db = db
            ns.Journal.TryLoad()
            expect(ns.Journal.SaveNow(), "seed save failed: " .. tostring(ns.Journal.status.error))
            local chunks = ns.Journal.status.chunks
            local committed = ns.Journal.status.generation
            local other = committed == "A" and "B" or "A"

            -- Exactly what an interrupted save leaves behind: the pending header
            -- and one payload chunk of the other generation, uncommitted.
            CreateMacro(string.format("GPS%s01", other), 134400,
                string.format("--GPSJ2:%s:1:01:%02d:1234:p:AAAA", other, chunks))
            CreateMacro(string.format("GPS%s02", other), 134400,
                string.format("--GPSJ2:%s:1:02:%02d:1234:c:BBBB", other, chunks))
            for index = 1, 24 - chunks - 2 do
                CreateMacro("PLAYERSLOT" .. index, 134400, "/say hi " .. index)
            end
            expectEqual(ns.Compat.MacroCount(), 24, "the macro list is not at its cap")

            db.credits = 888
            expect(ns.Journal.SaveNow(), "a save after a partial write failed: " ..
                tostring(ns.Journal.status.error))
            expect(journalMacros() <= chunks,
                "the partial generation was left on the list: " .. journalMacros())

            local loaded = ns.DB.Scratch()
            loaded.settings.macroJournal = true
            ns.db = loaded
            expect(ns.Journal.TryLoad(), "the recovered save did not load: " ..
                tostring(ns.Journal.status.error))
            expectEqual(ns.DB.Get().credits, 888, "the recovered save did not restore progress")
        end)

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __setMacroCap(36)
        __clearMacros()
        if not ok then error(err, 0) end
    end)

    -----------------------------------------------------------------------
    test("a player macro on a journal name does not stop every save", function()
        if type(__clearMacros) ~= "function" or type(__setMacroCap) ~= "function" then return end
        __clearMacros()
        __setMacroCap(36)
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB

        local ok, err = pcall(function()
            local db = ns.DB.Scratch()
            db.settings.macroJournal = true
            db.credits = 600
            db.tier = 3
            ns.db = db
            ns.Journal.TryLoad()
            expect(ns.Journal.SaveNow(), "seed save failed: " .. tostring(ns.Journal.status.error))
            local committed = ns.Journal.status.generation
            local other = committed == "A" and "B" or "A"

            -- The player happens to own a macro called GPS<other>01. That name is
            -- not the journal's to touch, so the save has to use the generation it
            -- already owns instead of giving up for the character's life.
            CreateMacro(string.format("GPS%s01", other), 134400, "/say this one is mine")
            db.credits = 1350
            expect(ns.Journal.SaveNow(), "a name collision blocked the save: " ..
                tostring(ns.Journal.status.error))
            local owned = ns.Compat.MacroIndexByName(string.format("GPS%s01", other))
            local _, ownedBody = ns.Compat.MacroInfo(owned)
            expectEqual(ownedBody, "/say this one is mine", "the save overwrote a player macro")

            local loaded = ns.DB.Scratch()
            loaded.settings.macroJournal = true
            ns.db = loaded
            expect(ns.Journal.TryLoad(), "the save after a collision did not load: " ..
                tostring(ns.Journal.status.error))
            expectEqual(ns.DB.Get().credits, 1350, "the save after a collision lost progress")
        end)

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __setMacroCap(36)
        __clearMacros()
        if not ok then error(err, 0) end
    end)

    -----------------------------------------------------------------------
    test("a snapshot too large for the journal still saves the economy", function()
        if type(__clearMacros) ~= "function" or type(__setMacroCap) ~= "function" then return end
        __clearMacros()
        __setMacroCap(36)
        local real = ns.db
        local realGlobal = _G.GoblinPawnStarsDB

        local ok, err = pcall(function()
            local db = ns.DB.Scratch()
            db.settings.macroJournal = true
            db.credits = 900
            db.tier = 2
            db.stats.sales = 6
            ns.db = db
            ns.Journal.TryLoad()
            expect(ns.Journal.SaveNow(), "seed save failed: " .. tostring(ns.Journal.status.error))

            -- A museum filled far past what twelve macro bodies can hold. The
            -- stock is already dropped by the trim, so only the optional blocks
            -- can give way.
            for index = 1, 400 do
                db.museum.donated["stress" .. index] = { name = "Stress Artifact Number " .. index }
            end
            db.credits = 2600
            db.stats.sales = 19
            expect(ns.Journal.SaveNow(), "an oversized snapshot failed to save: " ..
                tostring(ns.Journal.status.error))

            local loaded = ns.DB.Scratch()
            loaded.settings.macroJournal = true
            ns.db = loaded
            expect(ns.Journal.TryLoad(), "the degraded save did not load: " ..
                tostring(ns.Journal.status.error))
            expectEqual(ns.DB.Get().credits, 2600, "the degraded save lost credits")
            expectEqual(ns.DB.Get().stats.sales, 19, "the degraded save lost sales")
        end)

        ns.db = real
        _G.GoblinPawnStarsDB = realGlobal
        __setMacroCap(36)
        __clearMacros()
        if not ok then error(err, 0) end
    end)
`;

edit('addon/GoblinPawnStars/Modules/Diagnostics.lua', [[anchor, anchor + tests]]);

// ---------------------------------------------------------------------------
// Docs — honest counts and the new finding
// ---------------------------------------------------------------------------
const progressNote = `## Save path hardening — after v1.7.9

Work on \`main\`. The player reported a \`save error\` in the header after a session that
saved and relogged cleanly, so the write path was audited end to end and four ways it
could dead-end were reproduced in the headless suite, then fixed:

- **A full macro list at any cap.** The in-place fallback only ran when
  \`GetNumMacros()\` reported **36** or more — a hardcoded guess at the client's limit. On
  a list that refuses a create while reporting fewer (a smaller cap, or a full
  *character* list, which is a separate limit from the account list), every save failed
  with \`could not create GPSB01 (macro slots may be full)\` and never recovered: the
  chunks the failed attempt had just written held the very slots the retry needed. The
  fallback now triggers on the refusal itself rather than on a count, and an abandoned
  save sweeps the generation it wrote.
- **A name collision.** A player macro called \`GPSB01\` made every save fail with
  \`macro name collision on GPSB01\` for the life of the character. A collision on the new
  generation is now treated exactly like a full list: the save rewrites the generation
  it already owns, whose names are provably the journal's, and the player's macro is
  never touched.
- **A payload too large for one generation.** \`journal is too large, even without stock\`
  was terminal, so one oversized block (the museum list grows with play) stopped every
  later save. The snapshot now sheds its optional blocks in a fixed order — stock, the
  museum list, then cosmetic settings — and saves credits, tier, stats, campaign and
  inventory essentials instead.
- **A first save into a full list** had no committed copy to fall back on; it now
  reclaims the journal's own leftovers (an interrupted generation, surplus chunks)
  before giving up.

The load/save split from \`ca87258\` stays: the header says \`load error\` or \`save error\`,
never both. The suite is **63 tests**; each of the four new tests failed against the
previous \`Core/Journal.lua\` with the exact messages above and passes now. No live client
has run any of this.

## Current state — v1.7.9`;

edit('PROGRESS.md', [
  ['# PROGRESS\n\n## Current state — v1.7.9', '# PROGRESS\n\n' + progressNote],
  ['timing changed. The headless suite is **59 tests**; UI smoke is green.',
   'timing changed. The headless suite is **63 tests**; UI smoke is green.'],
  ['session unable to write at all. The suite is **59 tests**.',
   'session unable to write at all. The suite is **63 tests**.'],
  ['npm run check              -> Lua 5.1 syntax OK: 61 files, 17,498 lines; TOC OK',
   'npm run check              -> Lua 5.1 syntax OK: 61 files, 17,839 lines; TOC OK'],
  ['npm test                   -> 59 passed, 0 failed; UI smoke: all tabs and overlays',
   'npm test                   -> 63 passed, 0 failed; UI smoke: all tabs and overlays'],
  ['The 1.7.9 journal tests are counted in the 59.',
   'The 1.7.9 journal tests are counted in the 63.'],
  ['2. `/gps test` prints 59 PASS lines in chat.', '2. `/gps test` prints 63 PASS lines in chat.'],
]);

edit('README.md', [
  ['tests-59%2F59', 'tests-63%2F63'],
  ['alt="59 of 59 tests passing"', 'alt="63 of 63 tests passing"'],
  ['> 59-test headless suite plus the UI smoke pass.', '> 63-test headless suite plus the UI smoke pass.'],
  ['runs the 59-test diagnostics suite', 'runs the 63-test diagnostics suite'],
  ['* Headless diagnostics suite: **59/59 passing**', '* Headless diagnostics suite: **63/63 passing**'],
  ['* Lua 5.1 syntax check: **passing** (61 files, 17,498 lines).',
   '* Lua 5.1 syntax check: **passing** (61 files, 17,839 lines).'],
]);

edit('TESTING.md', [
  ['the Lua 5.1 parse (61 files, 17,498 lines)', 'the Lua 5.1 parse (61 files, 17,839 lines)'],
  ['the **59-test headless suite**', 'the **63-test headless suite**'],
  ['- `/gps test` should report **59 passed, 0 failed**.',
   '- `/gps test` should report **63 passed, 0 failed**.'],
  ['  must never freeze the window. Leave macro slots free, and do not rename\n  or delete those macros while testing.',
   '  must never freeze the window. The journal no longer needs free slots: when the macro\n' +
   '  list refuses a new name it rewrites the generation it already owns and sheds stock,\n' +
   '  then the museum list, to fit — the header stays clean and `/gps journal` shows\n' +
   '  `trimmed`. Do not rename or delete the `GPSA`/`GPSB` macros while testing.'],
]);

edit('docs/curseforge/description.md', [
  ['**59-test headless simulation suite**', '**63-test headless simulation suite**'],
]);

console.log('save-path hardening applied');
