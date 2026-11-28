// Refinement iteration 1, part B: dashboard, tests and documentation.
const fs = require('fs');

function edit(path, pairs) {
  let text = fs.readFileSync(path, 'utf8');
  for (const pair of pairs) {
    const oldText = pair[0];
    const newText = pair[1];
    const found = text.split(oldText).length - 1;
    if (found !== 1) {
      throw new Error(path + ': expected exactly one match for ' +
        JSON.stringify(oldText.slice(0, 70)) + ', found ' + found);
    }
    text = text.split(oldText).join(newText);
  }
  fs.writeFileSync(path, text);
  console.log('edited ' + path);
}

edit('addon/GoblinPawnStars/UI/Tabs/Dashboard.lua', [
[`            tiles[index] = { value = value, note = note }
        end
        ui.tiles = tiles`,
`            tiles[index] = { value = value, note = note, frame = tile }
        end
        ui.tiles = tiles

        -- Reputation is a progression system, not a scoreboard: hovering the tile
        -- lists exactly what each milestone unlocks and which one is next.
        if tiles[2].frame and GameTooltip then
            tiles[2].frame:EnableMouse(true)
            tiles[2].frame:SetScript("OnEnter", function(self)
                local reputation = math.floor(ns.DB.Get().reputation or 0)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Reputation", 0.94, 0.78, 0.33)
                local reached = ns.Shop.ReputationTier()
                GameTooltip:AddLine(string.format("%s · %d / 1000",
                    reached and reached.name or "Nobody", reputation), 0.91, 0.85, 0.69)
                for _, def in ipairs(ns.Data.ReputationTiers) do
                    local unlocked = reputation >= (def.at or 0)
                    GameTooltip:AddLine(string.format("%s  %s %d — %s",
                        unlocked and "|cff5fd64fUnlocked|r" or "|cff888888Locked|r",
                        def.name, def.at, def.perkText or ""), 0.85, 0.82, 0.7, true)
                end
                GameTooltip:AddLine("Every completed sale earns reputation.", 0.62, 0.58, 0.47)
                GameTooltip:Show()
            end)
            tiles[2].frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end`],
[`            local repLabel = ns.Shop.ReputationLabel()
            ui.tiles[2].value:SetText(string.format("%d", math.floor(db.reputation)))
            ui.tiles[2].note:SetText(repLabel)`,
`            local repLabel = ns.Shop.ReputationLabel()
            local perks = ns.Shop.ReputationPerks()
            ui.tiles[2].value:SetText(string.format("%d", math.floor(db.reputation)))
            ui.tiles[2].note:SetText(string.format("%s · %d/%d perks", repLabel,
                perks.count or 0, #ns.Data.ReputationTiers))`],
]);

edit('addon/GoblinPawnStars/Modules/Diagnostics.lua', [[
`    return results
end

function D.Report()`,
`    -----------------------------------------------------------------------
    test("shop events do not repeat back to back", function()
        withScratch(nil, function(scratch)
            local previous
            for _ = 1, 14 do
                local def = ns.Data.EncounterPick(scratch.tier, scratch.shop.encounterRecent)
                expect(def, "no event could be picked at tier 1")
                expect(def.key ~= previous, "the same event fired twice in a row: " .. tostring(def.key))
                ns.Encounters.Remember(ns.Data.EncounterIndex[def.key])
                previous = def.key
            end
            expect(#scratch.shop.encounterRecent <= 2, "the recency list grew without bound")

            -- Deterministic guard: whatever the dice do, an event listed as recent
            -- must not be drawn again while the tier still has other candidates.
            local blockedIndex = ns.Data.EncounterIndex.thief
            for _ = 1, 30 do
                local def = ns.Data.EncounterPick(1, { blockedIndex })
                expect(def, "the recency filter starved the pool")
                expect(def.key ~= "thief", "an event that just happened was drawn again")
            end

            ns.Inventory.Add({
                id = 4500, name = "Brass Key", quality = 2, ilvl = 20,
                classID = 15, subclassID = 0, category = "misc", value = 90,
            })
            ns.Encounters.Trigger("thief")
            expectEqual(scratch.shop.encounterRecent[1], ns.Data.EncounterIndex.thief,
                "a triggered event was not remembered as it happened")
        end)
    end)

    -----------------------------------------------------------------------
    test("reputation milestones unlock real perks", function()
        withScratch(nil, function(scratch)
            scratch.tier = 1
            scratch.reputation = 0
            local baseSlots = ns.Shop.WaitingSlots()
            local baseRare = ns.Shop.RareChance()
            expectEqual(ns.Shop.ReputationPerks().count, 0, "perks unlocked at zero reputation")
            expectEqual(ns.Shop.ReputationLabel(), "Nobody", "the label drifted from the milestone table")

            scratch.reputation = 120
            expectEqual(ns.Shop.ReputationLabel(), "Known", "the first milestone did not unlock")
            expectEqual(ns.Shop.WaitingSlots(), baseSlots + 1, "Known did not add its waiting slot")

            scratch.reputation = 260
            expect(ns.Shop.RareChance() > baseRare, "Respected did not raise the rare chance")
            expectEqual(ns.Shop.ReputationPerks().patience, 0, "patience unlocked before Trusted")

            ns.Inventory.Add({
                id = 7100, name = "Test Blade", quality = 3, ilvl = 40,
                classID = 2, subclassID = 7, category = "weapon", value = 500,
            })
            ns.Customers.TrySpawn({ personality = "trader" })
            local early = scratch.shop.waiting[#scratch.shop.waiting]
            expect(early, "no customer was generated")
            expectEqual(early.patienceMax, 4, "Trusted changed patience too early")

            scratch.reputation = 520
            ns.Customers.TrySpawn({ personality = "trader" })
            local trusted = scratch.shop.waiting[#scratch.shop.waiting]
            expect(trusted, "no customer was generated at Trusted")
            expectEqual(trusted.patienceMax, 5, "Trusted did not add its haggling round")

            scratch.reputation = 820
            expectEqual(ns.Shop.ReputationPerks().offer, 0.05, "Legendary lost its offer bonus")
            expectEqual(ns.Shop.ReputationPerks().count, 4, "earlier perks were dropped")
            expectEqual(ns.Shop.ReputationLabel(), "Legendary", "the top milestone is not Legendary")
        end)
    end)

    return results
end

function D.Report()`],
]);

const changelog = `## [Unreleased]

Development continues on the \`refinement-polish\` branch; \`main\` stays at 1.8.0. Nothing
below is released yet.

### Added

- **Reputation milestones with real perks.** Reputation used to be a number beside the
  shop name and a small price modifier, so a lifetime of good deals felt like filling a
  bar. Four milestones now unlock concrete perks, in order: **Known** (100) one extra
  waiting slot, **Respected** (250) +2% rare customers, **Trusted** (500) one extra
  haggling round, **Legendary** (800) +5% on every offer. Perks are cumulative, and the
  Dashboard reputation tile lists all four, unlocked or not, when you hover it.

### Changed

- **Shop events no longer repeat back to back.** The last two events are remembered in
  the save as two small indices and skipped while at least three candidates remain, so
  the same crisis cannot fire twice in a row or alternate A-B-A for an evening. A relog
  no longer immediately repeats the event you just dismissed.
- Event memory records the event that actually happened rather than the one drawn: a
  draw with nothing to build from falls back to another event, and the fallback is what
  gets remembered.

### Verified

- 67 headless tests (two new: event freshness, reputation perks), \`npm run check\` and
  \`npm test\` at exit 0, UI smoke green, and the 30-minute simulation unchanged at 40
  sales and tier 2 — reputation 146 at the end, so the first milestone is reached in a
  normal session. **Not run in the live client.**

`;

const progress = `## Refinement pass — branch \`refinement-polish\`

The polish mission runs on \`refinement-polish\`, branched from \`main\` at \`41a4da7\`
(1.8.0). \`main\` is not modified by this work; only the owner decides when it merges.
\`npm run check\` reports 61 files and 18,306 lines on this branch.

### Iteration 1 — reputation milestones and event freshness

Two systems were shallower than the rest of the simulation.

**Reputation** climbed to 1,000 over a run and changed exactly two things: the label
beside the shop name and a 0.88-1.10 factor on what customers were willing to pay. That
is a bar, not a progression system, and nothing told the player what the bar was buying.
It now drives four milestones from \`Data.ReputationTiers\`, each with one concrete perk:

| Milestone | Reputation | Perk |
| --- | --- | --- |
| Known | 100 | +1 waiting slot |
| Respected | 250 | +2% rare customers |
| Trusted | 500 | +1 haggling round |
| Legendary | 800 | +5% on every offer |

Design decisions:

- **The label and the perk come from one table.** \`ReputationLabel\`, \`ReputationPerks\` and
  the Dashboard copy all read \`Data.ReputationTiers\`, so a threshold cannot be moved in
  one place and left behind in another (the old label had four hardcoded \`if\` lines).
- **Perks are cumulative and conservative.** The waiting slot is the only structural
  change; the rest are small modifiers on systems that already exist, so no new UI,
  timer or saved field was needed to make reputation feel different. The offer bonus is
  the largest at the very top of the ladder, where a 5% sale increase cannot distort the
  early economy.
- **Discovery without clutter.** The Dashboard tile still reads \`Known · 1/4 perks\`, and
  hovering it lists every milestone with its perk and whether it is unlocked. No new tab,
  no new command, no extra window.

**Shop events** were drawn from a weighted table with no memory, so \`thief\` could fire
three times in twenty minutes and read as a bug rather than a bad night. \`Encounters\`
now keeps the indices of the last two events in \`db.shop.encounterRecent\` and
\`Data.EncounterPick\` skips them while at least three candidates remain:

- **Indices, not key strings.** Two numbers cost about a dozen characters in a journal
  payload that is measured in characters; two key strings would cost ~60 base64.
- **The filter yields.** A tier-1 shop has eleven eligible events, but if a future data
  change leaves three, variety beats the rule and the recent list is ignored.
- **The save carries it.** The list is additive (\`{}\` default, \`normalize\` clamps it to
  two positive integers), so old saves and old journals load unchanged.
- **Fixed a quiet bug.** Event memory used to be written from the drawn definition, but
  a draw with nothing to build from (\`complainer\` with no sale yet, \`thief\` with an empty
  shop) falls back to a different event. The fallback is now the one recorded.

Performance: \`ReputationPerks\` walks four table entries and is called from
\`WaitingSlots\`, \`RareChance\`, customer construction and the once-a-second header
refresh. No new timers, no polling, no allocations beyond one small table per call.

Verification on this branch: \`npm run check\` exit 0 (61 files, 18,306 lines, TOC OK),
\`npm test\` exit 0 with **67 passed, 0 failed** (two new tests; the event test includes a
deterministic 30-draw guard that would fail on the pre-change picker), UI smoke green, and
\`node tools/sim_30min.js\` unchanged at 40 sales / tier 2 / reputation 146.

Known issues and next opportunities:

- The tooltip has run only in the mock; whether it clips at small UI scales is unverified.
- Dialogue is still chosen per archetype without looking at the item, so two visits by
  the same personality read alike. A contextual greeting (\`greetPrefer\` when the piece
  matches \`prefer\`) is the next text-depth change.
- Nothing in the addon has been run inside World of Warcraft. That remains true for
  every claim above.

`;

const roadmap = `# TODO

## Refinement roadmap (branch \`refinement-polish\`, branched from \`main\` @ \`41a4da7\`)

\`main\` stays at 1.8.0 until the owner says otherwise. Work lands here first.

### Done on this branch

- [x] Reputation milestones: Known / Respected / Trusted / Legendary now unlock a
      waiting slot, a rare-customer bonus, an extra haggling round and an offer bonus,
      all from one data table, all visible on the Dashboard tile tooltip.
- [x] Shop events remember the last two draws, so no event repeats back to back or
      alternates A-B-A, and a relog does not repeat the event you just dismissed.
- [x] Two new headless tests (67 total) covering both changes.

### Next up (planned order)

- [ ] **Contextual customer dialogue.** Choose a greeting by whether the piece matches
      the personality's \`prefer\` list, so two visits by the same archetype read
      differently. Pure data + one call site, no schema change.
- [ ] **UI pass on typography and spacing.** Audit every tab against a single scale for
      caption/value/label text, tighten the header, and give the negotiation window a
      clearer hierarchy between offer, odds and actions.
- [ ] **Return-visit memory.** Customers recognise a shop that treated them well, feeding
      reputation and the regular-visit path instead of disappearing completely.
- [ ] Read-path salvage for the macro journal: a partial payload should keep the fields
      that validate instead of refusing the load outright.
- [ ] First-run pacing review: the first five minutes currently teach haggling well but
      say nothing about the market index, the daily request or the deed.

`;

edit('CHANGELOG.md', [
  ['## [1.8.0] — 2026-11-28', changelog + '## [1.8.0] — 2026-11-28'],
]);

edit('PROGRESS.md', [
  ['## Current state — v1.8.0\n', progress + '## Current state — v1.8.0\n'],
  ['npm test                   -> 65 passed, 0 failed; UI smoke: all tabs and overlays',
   'npm test                   -> 67 passed, 0 failed; UI smoke: all tabs and overlays'],
]);

edit('TESTING.md', [
  ['the TOC, the **65-test headless suite** (including the four macro-journal tests), the',
   'the TOC, the **67-test headless suite** (including the four macro-journal tests), the'],
  ['- \`/gps test\` should report **65 passed, 0 failed**. The macro-journal tests skip',
   '- \`/gps test\` should report **67 passed, 0 failed**. The macro-journal tests skip'],
]);

edit('README.md', [
  ['badge/tests-65%2F65', 'badge/tests-67%2F67'],
  ['alt="65 of 65 tests passing"', 'alt="67 of 67 tests passing"'],
  ['> 65-test headless suite plus the UI smoke pass.', '> 67-test headless suite plus the UI smoke pass.'],
  ['runs the 65-test diagnostics suite', 'runs the 67-test diagnostics suite'],
  ['* Headless diagnostics suite: **65/65 passing**', '* Headless diagnostics suite: **67/67 passing**'],
]);

const todo = fs.readFileSync('TODO.md', 'utf8');
if (!todo.startsWith('# TODO\n\n')) throw new Error('TODO.md header moved');
fs.writeFileSync('TODO.md', roadmap + todo.slice('# TODO\n\n'.length));
console.log('edited TODO.md');

console.log('refinement 1 part B applied');
