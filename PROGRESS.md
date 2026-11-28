# PROGRESS

## Journal payload format 3 — the live `save error`

The player's 1.7.9 client reported `Could not save progress to the macro journal:
journal is too large, even without stock` on a 489-credit tier 1 shop with 10 stock
stacks, while `/gps journal` showed `Chunks: 0/12 · generation none`. The write path
showed the cause was capacity, not corruption: `prepareJob` refuses a snapshot that
does not fit one generation (12 chunks x 210 base64 characters = 2,520), and
`trimSnapshot` can only shed stock. A played shop spends that budget on field names.
Measured on the real addon under the mock, a 50-minute profile (all 37 counters
non-default, 23 settings, two market events, one museum entry, a daily request)
encoded to **2,292 base64 characters with no stock at all** — 91% of the budget — so
any stock pushed it over and the trim then had nothing left to drop.

Format 3 carries the stat, settings and market-event sections as ordered value arrays
instead of name/value maps, so the names cost nothing. On the same profile the fixed
part drops **2,292 -> 1,288** base64, and a save with twelve full stacks drops
**2,580 -> 2,276**, which fits one generation with 244 characters to spare and no
stock trimmed at all. The loader reads both formats: a payload without `format = 3` is
expanded exactly as before, and `inventoryFormat` still travels so packed stock keeps
unpacking. The field order is part of the format — append, never reorder — and missing
positions keep their schema default, so older payloads expand cleanly.

The player also confirmed that a full exit-and-login restores credits, tier and stock
while the journal has written zero chunks, so SavedVariables carry the run and the
journal is a fallback rather than the only save path. `GetNumMacros()` returned 33
general + 3 character macros on that character, and `GPSA01`/`GPSB01` were found at
indices 8 and 20: leftovers from builds that tried to write before the size refusal,
which the next save reuses rather than creating new names.

### Evidence that could not be obtained

The analysis machine has no WoW installation, no `WTF` folder, no `SavedVariables`, no
`Logs` or `Errors` folder and no addon debug dump (searched `/`, `/opt`, `/usr/share`,
`/home`, `/root`, `/mnt`, `/srv`, the workspace). The chunk bodies on the player's disk
were therefore never read; this diagnosis rests on the client's own chat output and on
payloads measured headlessly. No live in-game result is claimed for format 3.

## Save path hardening — after v1.7.9

Work on `main`. The player reported a `save error` in the header after a session that
saved and relogged cleanly, so the write path was audited end to end and four ways it
could dead-end were reproduced in the headless suite, then fixed:

- **A full macro list at any cap.** The in-place fallback only ran when
  `GetNumMacros()` reported **36** or more — a hardcoded guess at the client's limit. On
  a list that refuses a create while reporting fewer (a smaller cap, or a full
  *character* list, which is a separate limit from the account list), every save failed
  with `could not create GPSB01 (macro slots may be full)` and never recovered: the
  chunks the failed attempt had just written held the very slots the retry needed. The
  fallback now triggers on the refusal itself rather than on a count, and an abandoned
  save sweeps the generation it wrote.
- **A name collision.** A player macro called `GPSB01` made every save fail with
  `macro name collision on GPSB01` for the life of the character. A collision on the new
  generation is now treated exactly like a full list: the save rewrites the generation
  it already owns, whose names are provably the journal's, and the player's macro is
  never touched.
- **A payload too large for one generation.** `journal is too large, even without stock`
  was terminal, so one oversized block (the museum list grows with play) stopped every
  later save. The snapshot now sheds its optional blocks in a fixed order — stock, the
  museum list, then cosmetic settings — and saves credits, tier, stats, campaign and
  inventory essentials instead.
- **A first save into a full list** had no committed copy to fall back on; it now
  reclaims the journal's own leftovers (an interrupted generation, surplus chunks)
  before giving up.

The load/save split from `ca87258` stays: the header says `load error` or `save error`,
never both. The suite is **65 tests**; each of the four new tests failed against the
previous `Core/Journal.lua` with the exact messages above and passes now. No live client
has run any of this.

## Refinement pass — branch `refinement-polish`

The polish mission runs on `refinement-polish`, branched from `main` at `41a4da7`
(1.8.0). `main` is not modified by this work; only the owner decides when it merges.
`npm run check` reports 64 files and 19,365 lines on this branch.

### Iteration 1 — reputation milestones and event freshness

Two systems were shallower than the rest of the simulation.

**Reputation** climbed to 1,000 over a run and changed exactly two things: the label
beside the shop name and a 0.88-1.10 factor on what customers were willing to pay. That
is a bar, not a progression system, and nothing told the player what the bar was buying.
It now drives four milestones from `Data.ReputationTiers`, each with one concrete perk:

| Milestone | Reputation | Perk |
| --- | --- | --- |
| Known | 100 | +1 waiting slot |
| Respected | 250 | +2% rare customers |
| Trusted | 500 | +1 haggling round |
| Legendary | 800 | +5% on every offer |

Design decisions:

- **The label and the perk come from one table.** `ReputationLabel`, `ReputationPerks` and
  the Dashboard copy all read `Data.ReputationTiers`, so a threshold cannot be moved in
  one place and left behind in another (the old label had four hardcoded `if` lines).
- **Perks are cumulative and conservative.** The waiting slot is the only structural
  change; the rest are small modifiers on systems that already exist, so no new UI,
  timer or saved field was needed to make reputation feel different. The offer bonus is
  the largest at the very top of the ladder, where a 5% sale increase cannot distort the
  early economy.
- **Discovery without clutter.** The Dashboard tile still reads `Known · 1/4 perks`, and
  hovering it lists every milestone with its perk and whether it is unlocked. No new tab,
  no new command, no extra window.

**Shop events** were drawn from a weighted table with no memory, so `thief` could fire
three times in twenty minutes and read as a bug rather than a bad night. `Encounters`
now keeps the indices of the last two events in `db.shop.encounterRecent` and
`Data.EncounterPick` skips them while at least three candidates remain:

- **Indices, not key strings.** Two numbers cost about a dozen characters in a journal
  payload that is measured in characters; two key strings would cost ~60 base64.
- **The filter yields.** A tier-1 shop has eleven eligible events, but if a future data
  change leaves three, variety beats the rule and the recent list is ignored.
- **The save carries it.** The list is additive (`{}` default, `normalize` clamps it to
  two positive integers), so old saves and old journals load unchanged.
- **Fixed a quiet bug.** Event memory used to be written from the drawn definition, but
  a draw with nothing to build from (`complainer` with no sale yet, `thief` with an empty
  shop) falls back to a different event. The fallback is now the one recorded.

Performance: `ReputationPerks` walks four table entries and is called from
`WaitingSlots`, `RareChance`, customer construction and the once-a-second header
refresh. No new timers, no polling, no allocations beyond one small table per call.

Verification on this branch: `npm run check` exit 0 (61 files, 18,306 lines, TOC OK),
`npm test` exit 0 with **67 passed, 0 failed** (two new tests; the event test includes a
deterministic 30-draw guard that would fail on the pre-change picker), UI smoke green, and
`node tools/sim_30min.js` unchanged at 40 sales / tier 2 / reputation 146.

Known issues and next opportunities:

- The tooltip has run only in the mock; whether it clips at small UI scales is unverified.
- Dialogue is still chosen per archetype without looking at the item, so two visits by
  the same personality read alike. A contextual greeting (`greetPrefer` when the piece
  matches `prefer`) is the next text-depth change.
- Nothing in the addon has been run inside World of Warcraft. That remains true for
  every claim above.

## Current state — v1.8.0

**v1.8.0** ships the journal payload format described below: the stat, settings and
market-event sections travel as ordered value arrays, so a played shop with a full
stockroom fits one generation (2,580 -> 2,276 base64 characters, nothing trimmed) and
the live `save error` stops. Version numbering jumped to 1.8.0 because the payload
format changes; `main`, the tag and every document carry the same number.


Phases 1–4 are implemented. Phase 5 (optional multiplayer) is deliberately not
started. The addon is feature-complete for a single-player shop simulation and is
packaged as an installable ZIP. Created by **ErrorSeib & Buffy (Codebuff)**.

**v1.7.9** changes how the macro journal is read and written. Loading runs by itself
shortly after login, but never more than four reads: one counter, no chained retries,
and the last attempt always settles. While an attempt is pending the header reads
`loading saved shop` and every save is refused, so a fresh session cannot stamp
defaults over a run it has not read. **Settings → Auto-load** turns the login load off,
and **Settings → Backup & Restore → Load saved** (confirmed twice) repeats one read on
demand as the recovery path. The old loader scheduled three more full macro-list reads
from every failed attempt, which is what multiplied macro work until the client
stalled. An autosave is a queue of single macro operations with an 8 ms budget per
tick: one chunk per frame, cleanup only after the commit, and **Save Now**, logout,
import and `/gps verify` flush a staged save synchronously. No gameplay or arrival
timing changed. The headless suite is **65 tests**; UI smoke is green.

**v1.7.8** was a presentation and responsiveness release: Settings has a one-click
Performance mode, simultaneous arrivals aggregate on one card, the card pauses while
hovered and has its own close control, `/gps profile` keeps rolling operation timings,
and the Inventory tab reuses sort-time market values. The suite was 55 tests.

v1.1.0 added the welcome window, Settings category, Addon Compartment entry and an
item-parsing correctness pass. v1.1.1 fixed the sidebar/tab hit area. v1.2.0 added the
guided tour, splash/update screens, Next Up and animations. v1.2.1 fixed bag scanning's
nil handling and baseline behaviour. v1.3.0 added visible throughput, the wholesaler,
queue-based salesperson auto-sales, faster early traffic and a tuned first 30-minute
arc. **v1.4.0** adds The Deed campaign, the Curious Collection museum, Marta Copperpin,
endless mode, franchise prestige and the macro save journal. **v1.5.0** adds native customer models and movable arrival cards. **v1.6.0**
adds questing auto-sell and doubles the arrival waits. **v1.6.1** fixes the minimap
coin's ring, background and waiting-customer pip. **v1.6.3** adds `/gps report`
(client probe, journal status, recent Lua errors, economy snapshot), remembers the
last eight Lua errors for it, and lowers the tier-3 shop to 5,000 gc. **v1.6.4** makes
the macro journal crash-safe: two alternating generations, a read-back check on every
chunk, a commit header written last, and a regression test that fails a write halfway
and at the commit step and still restores the previous run. **v1.6.5** fixes progress
vanishing on every logout and the welcome screen reappearing: SavedVariables handed over
late are adopted instead of overwritten with defaults, a save refuses to replace a
journal the session has not read, the first empty read is retried before it is treated
as a fresh install, and the journal starts saving ten seconds into a session. **v1.7.0** makes the save path
checkable and the opening minutes teachable: `/gps verify` saves and then reads the
journal back to compare it with the run, the header shows the save state, `/gps uicheck`
reports windows that sit off-screen, the first three customers are scripted around a
winnable opening counter, `/gps motion` turns animations off, and logging in prints a
one-line shop summary. Saving no longer freezes on a full stockroom: trimming used to
re-encode the whole shop for every four stacks it dropped, and an unchanged autosave now
skips that step entirely. Effects no longer leak animation groups either: each region
keeps one group per effect and replays it, so a long session stays at the same speed.
Releases are now built by a tag-driven workflow. 43 tests passed at that release.

**v1.7.1** makes the counteroffer odds honest and the payout exact: the window and
`Negotiation.Counter` share one `Odds` function, the scripted first buyer opens at 45%
of their ceiling and is eager, the Make Counteroffer button consumes the full
`(ok, payload)` result instead of erroring before the payout, and `completeSale` returns
the wallet delta the window displays. It also refreshes the header after automatic
sales, drops saved customers whose offer or ceiling is missing instead of rendering
`0 gc`, and anchors the Low/Fair/Greedy presets to the customer's visible offer so they
never suggest a pay cut. The mock suite is **47 tests** (46 at the original 1.7.1
checkpoint, plus the customer-relative preset test); no part of the addon has been run
in the live client.

### v1.7.2 — rolling backups

`Core/Backups.lua` and `UI/BackupFrame.lua` add three timestamped snapshots in a
separate `GoblinPawnStarsBackups` SavedVariables table. Capture only reads the shop
and stores `DB.Export()` text; it never calls an economy function. The first automatic
capture runs after 30 seconds, then every 600 seconds while the shop has progress;
**Backup now** and the pre-restore capture are manual. A restore needs a second
click, always writes a `pre-restore` snapshot first, and replaces the database with
`DB.Import()` rather than merging. If that safety snapshot cannot be encoded the
restore aborts. The backup store is separate from the shop database, so snapshots
cannot contain themselves.

The 1.7.1 ZIP predates this work and is superseded by the 1.7.2 build; the 1.7.1
checkpoint remains `ef03caf`, and 1.7.2 is the release that ships the 1.7.1 fixes and
the backups together. The suite is **50 tests** (47 plus three backup tests) and the
UI smoke builds and captures from the backup window. This work has not run in the
live client.

### v1.7.9 — a bounded login load and a save that never holds the frame

The old loader scheduled three more reads from every failed attempt, so a journal
that would not assemble multiplied macro reads until the client stalled. Loading is
back at login, but bounded: `J.AutoLoad` arms at `PLAYER_LOGIN` and the clock performs
at most `LOGIN_ATTEMPTS` (four) reads at 2, 5, 10 and 30 seconds — one counter, no
chained timers, and the last attempt settles either way. An empty macro list does not
settle early, because it can still be arriving, so `J.TryLoad(origin, hold)` reports a
third "waiting" result that only the automatic path uses. `J.Load` is the Settings
button (one read, press twice), `J.status.autoLoadJournal` (default on) can turn the
login load off, and `J.status.loadedBy` records which path settled the run for
`/gps journal`. Every write is still refused until a load settles (`J.status.loaded`),
so a fresh session cannot stamp defaults over a real save. Importing a paste or
resetting progress adopts the save path. The login summary is now printed from
`announceSession` on the journal's first settle (`J.AfterSettle`, drained from the
tick), so a restored run is announced with its own credits, queue and stock instead
of the fresh-stall line the defaults produce two seconds earlier.

An autosave is now a queue of single macro operations. `prepareJob` still builds the
snapshot, `buildSteps` lays out pending header, payload and commit header, and the
clock gives `advance` an 8 ms budget a tick, always allowing one operation so slow
client calls still make progress. Cleanup (retired generation, leftover chunks,
legacy `GPSJ` chunks) is queued the same way, one name per step, and only runs after
the commit. `SaveNow`, logout, import and `/gps verify` flush a staged save
synchronously, so a manual checkpoint never lands half-written. A journal that will
not assemble settles the load so the next save can replace it, instead of leaving the
session unable to write at all. The suite is **65 tests**. This work has not run in
the live client.

### v1.7.5 — five-minute, idle-only autosaves

1.7.4 kept both macro generations, so at rest it held 24 chunks; with the player's
own macros that could fill the client list and leave the red save error up. 1.7.5
retires the replaced generation after every successful save, so only one generation
is on the list. Autosaves run every five minutes (the first at five), wait until the
shop window is closed and no customer is at the counter, and write the whole
generation in one batch. Every chunk is read back before the commit header; the
previous generation is untouched until then. The incremental tick writer and its
cleanup/verification queues were removed. A completely full list rewrites the
committed generation in place as a last resort, and failures back off from one
minute to five. Settings and The Deed both have an immediate checkpoint button. The
suite is **53 tests**. This work has not run in the live client.

### v1.7.4 — stop the journal stutter

1.7.3 spread the macro writes across ticks but still read every chunk back and
deleted the replaced generation after each save. On the beta client those macro
calls are the expensive part: a 12-chunk shop made about 80 calls every 30 seconds.
1.7.4 keeps the previous generation as the crash fallback instead of deleting it,
removes per-chunk read-back from automatic saves (logout, import and `/gps verify`
still verify), and saves once a minute with the first save at 20 seconds. Legacy
`GPSJ` chunks are scanned once per session. The suite remains **53 tests**.

### v1.7.3 — save-path freeze and recovery

The journal writes one verified macro per clock tick instead of thirteen writes and a
dozen deletions in one frame, so an autosave cannot hitch the client. The replaced
generation is retired one macro per tick after the commit. A create failure frees
pre-1.6.4 `GPSJ` chunks one at a time, which fixes the upgrade deadlock where 24 old
chunks plus a new generation could exceed the macro limit forever; a failed save never
removes the last committed generation. Failed saves back off for a minute instead of
retrying every eight seconds, the legacy loader reports its real error again, pausing
the shop no longer stops the autosave, and logout/restore save the latest state rather
than an older in-flight snapshot. The suite is **53 tests** (50 plus three save-path
regressions). This work has not run in the live client.

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Shop UI, virtual loot inventory, customer generation, negotiation, fictional currency, persistent saving | **Done** |
| 2 | Market fluctuation, personalities, reputation, shop upgrades | **Done** |
| 3 | Employees, random events, achievements, special customers | **Done** |
| 4 | Interface polish, economy balancing, sound effects, bug fixing | **Done** (sound + polish complete; balance validated by simulation, not live play) |
| 5 | Optional multiplayer via addon comms | **Not started** — see `TODO.md` |

## Customer arrivals in v1.5.0

The addon uses the client's native NPC models for arrivals and portraits. The
mock tests cover model loading, icon fallback, walk and idle requests, centered
layouts, independent drag positions, arrival pace, and Settings clicks. A live
Forever visual pass is still needed to verify the selected models, their
animations and framing, and the brighter negotiation panel. The clock smoke
check verifies that a due arrival waits for stock, combat to end, or a free
slot. The header and `/gps arrivals` show the active blocker.

## Arrival pacing and questing auto-sell

The mock diagnostics verify doubled arrival intervals, one-time migration of
the pending countdown, and a questing sale that pays a third of the maximum
manual offer and consumes stock. The UI smoke test clicks the questing toggle.
The new pacing and toggle still need a live-client pass.

## What exists

* 61 Lua files, 17,498 lines, loaded by a single TOC at Interface 16001.
* Ten-tab main window, movable negotiation window, wholesaler window, encounter popup,
  minimap coin, toasts, tooltips, optional sound.
* The Deed: three payments, an ending choice, endless mode, franchise prestige, one
  five-slot museum set, one named regular and three campaign achievements.
* Throughput tracker, wholesale lot generator, starter crate and queue-based
  salesperson automation.
* 12 inventory categories, 13 races, 9 personalities, 5 shop tiers, 11 upgrades,
  6 employees, 11 market events, 11 encounter types, 26 achievements.
* Standard SavedVariables, a chunked macro journal for the beta save bug, a
  full copy-paste backup/restore path, and three rolling snapshots in a separate
  SavedVariables table.
* One guarded compatibility layer for every risky client API.

## Verification performed

Commands, run from the repository root:

```
npm ci                     -> added 5 packages, exit 0
npm run check              -> Lua 5.1 syntax OK: 61 files, 18,073 lines; TOC OK
npm test                   -> 67 passed, 0 failed; UI smoke: all tabs and overlays
node tools/sim_30min.js    -> FINAL 449 gc, tier 2, 40 sales; idle probe 17 auto-sales
```

Those four commands were run inside a fresh `git clone` of `main` in a throwaway
directory, not in the working tree, so the numbers above describe exactly what a
clean checkout produces. The 1.7.9 journal tests are counted in the 65. Earlier
release preps reported 58 files/15,696 lines (47 tests), 60 files/16,151 lines
(50 tests) and 60 files/16,595 lines (53 tests); those numbers are historical and
superseded.

No part of the addon has been executed inside World of Warcraft. Every result on
this page comes from the fengari harness with mocked WoW APIs, the UI smoke script
and the Node simulations.

The headless suite executes the real addon code in fengari with mocked WoW APIs. It
covers:

1. Data table coherence (tiers, personalities, achievements, unique keys).
2. Serializer round-trip including quotes, backslashes and newlines.
3. Inventory stacking, capacity limits and overflow rejection.
4. Market multiplier bounds with two simultaneous events.
5. Customer generation requires stock; ceiling never exceeds budget; offer ≤ ceiling.
6. Accepting an offer pays exactly once and removes exactly one item.
7. 40 rounds of random counteroffers cannot mint credits or duplicate stock.
8. Shop-day expenses never drive credits negative.
9. Storage upgrades and appraiser hiring change real numbers.
10. Achievements unlock once and only once.
11. Encounter resolution clears pending state.
12. Every encounter option resolves without error or negative credits.
13. Every personality can spawn, appraise, counter and settle without error.
14. Backup export → import restores credits, tier and stats.
15. Loot eligibility rejects grey, quest and key items.
16. Wholesaler lots deduct their exact cost, add exactly one stock record, and cannot
    be bought twice.
17. The salesperson auto-sells a queued customer, consumes stock, pays exactly the
    recorded revenue, clears the queue, and cannot sell without stock.
18. Throughput is zero with no sales, then reports the expected rates.
19. The starter crate gives two stock stacks, no credits, and only grants once.
20. **Macro journal** saves a run into ≤24 chunks (each body ≤255 characters), restores
    credits/campaign/museum/sales, omits history, and rejects a corrupted checksum.
    Compact snapshots drop default values and pack stock as tuples, so a normal
    twenty-item shop saves without trimming and a zero balance or a false setting is
    not replaced by its default.
21. **Journal trimming** fits 80 bulk stock records into 24 chunks, trims low-value
    inventory first, and still restores campaign state and credits.
22. **The Deed** charges 1,500 / 6,000 / 25,000 exactly, completes at 32,500, unlocks
    Marta on the first payment, and offers endless mode.
23. **Museum** donations consume one stock unit, cannot fill a slot twice, complete the
    set and activate the +5% offer bonus without creating credits.
24. **Marta** can be invited three times, each visit completes a normal stock-backed
    sale, and the third visit marks her story complete with +3% offers.
25. **Franchise** resets the economy and starts a new deed while keeping museum, Marta,
    achievements and the advanced prestige level.
26. **Journal rebind** restores a journal, verifies the restored table is the active
    database, pays a debt note immediately, cold-loads that payment, then resets right
    after a restore and cold-loads the reset before any autosave can run.
27. **Franchise journal commit** defers the reset save, rebuilds the franchise state,
    then cold-loads the new journal and confirms the old debt is gone while the museum,
    Marta and prestige level survived.

The UI smoke pass builds and refreshes all ten tabs, including the Deed tab, and
continues to check the splash modes, tour steps, goal card, options panel, negotiation,
events, wholesaler window, slash commands and a simulated hour.

The 1.7.1 additions are covered by tests for the odds identity (the window and the roll
use the same value), the first buyer's 45% opening and eager odds, the exact credit
delta for accept/counter/salesperson/quest sales, stale-customer normalization, and the
preset floor for a high-opening customer. The UI smoke clicks the real accept and
counter buttons and compares the banner and auto-sale header with the wallet delta.
These are mock tests only.

The separate `tools/sim_30min.js` probe runs a fixed policy that never pays the debt:
40 sales and 2,472 gc earned by minute 30, tier 2 at minute 25, 449 gc left,
1.0–1.3 customers/min, and a 10-minute closed-window probe with 17 auto-sales, an
empty queue and 193 gc/min. That policy never hires the salesperson, so its auto-sale
column stays at 0 inside the 30 minutes. The numbers describe a scripted probe, not
campaign pacing or live feel. The debt amounts (1,500 / 6,000 / 25,000) are unchanged
from the outlined design and need a real play pass.

## Not verified — needs an in-game pass (1.7.3)

No part of this addon has been run inside World of Warcraft. The 1.7.1 checklist below
is the remaining release gate; the older list after it is still open.

- **Save path:** the header during an autosave (it may read **save pending** while the
  journal writes one macro per tick), a full macro list recovering by deleting old
  `GPSJ` chunks, a save error waiting a minute before retrying, and a logout during an
  in-flight save storing the latest sale.
- **Rolling backups:** the Settings entry and window layout; automatic snapshots at 30
  seconds and every 10 minutes; `GoblinPawnStarsBackups` persisting across `/reload`
  and relog; an exact restore round-trip; the pre-restore row; a corrupt snapshot
  leaving the shop untouched; and a paused shop skipping automatic capture.
- **1.7.1 counter flow:** the odds bar and preset prices in the live window; the
  scripted first buyer opens around 65% of market; Low/Fair/Greedy read about 94/88/64%
  on a fresh save; a landed counter completes and pays; the banner and feedback equal
  the header credit delta; two sales in a row show their own amounts.
- **1.7.1 automatic sales and saves:** a salesperson or questing sale refreshes the
  header immediately; relog with a valid customer at the counter shows a positive offer
  and working odds; an invalid saved customer is dropped instead of rendering `0 gc`.
- **1.7.1 presets:** a high-opening customer never gets a Low/Fair/Greedy suggestion
  below their current offer.

The older unverified areas:

- **Macro journal:** whether `CreateMacro`/`EditMacro` are usable on Forever, whether
  macro bodies survive a full client restart as expected, the real account macro slot
  limit, and how long a staged save takes on a real client. Nothing is read at login
  any more, so the only load path to prove is **Settings → Backup & Restore → Load
  saved**.
- **Deed layout:** the campaign panel, five museum rows, Marta panel and footer at
  960×640 and at 0.8/1.0/1.2 scale. No visual pass was performed.
- **Campaign feel:** payment pacing, whether 25,000 gc is reachable in a reasonable
  number of sessions, whether Marta appears too often, and whether the franchise reset
  feels rewarding.
- **Layout and appearance:** text overlap, wrapping and spacing with real Blizzard
  fonts, UI scales and skins.
- **Textures:** dialog, tooltip, button, class-icon and campaign icons; none rendered.
- **Item data:** real `C_Item.GetItemInfo` results and tooltips.
- **Bag scanning:** real `C_Container` shapes, reagent bags and loot events.
- **SavedVariables:** re-check after Blizzard fixes the beta bug; a newer SavedVariables
  snapshot is intended to win over an older journal.
- **Sound cues:** whether the `SOUNDKIT` keys exist on build 16001.
- **Minimap button and slash registration.**

## In-game checklist (first pass)

1. `/gps` opens the window; all ten tabs render without Lua errors; Esc closes it.
2. `/gps test` prints 65 PASS lines in chat.
3. Loot one item; it appears in Inventory. Re-looting does not duplicate stock.
4. Make a sale, then open **The Deed** and pay the first note when affordable. Confirm
   1,500 credits leave the wallet and the museum/Marta unlock.
5. Donate one eligible quality-2+ item to each museum slot; confirm stock falls by one
   per donation and the set completes with a +5% offer bonus.
6. Invite Marta, sell her three pieces, and confirm visits count 1/2/3 and her +3%
   bonus appears in the Deed footer.
7. Pay the second and third notes. Confirm the ending card appears; choose endless mode,
   then open a franchise. Confirm credits/stock/tier reset, the museum/Marta remain and
   the franchise level adds +5% offers.
8. Cold-logout and restart the client. The header reads `loading saved shop` while the
   bounded login load runs, then the run comes back on its own. Confirm the journal
   status in the Deed tab and that campaign/museum/Marta/prestige progress return. Then
   turn **Auto-load** off, relog, and confirm the header stays `load progress` until
   **Load saved** is pressed twice. If macro slots are full, confirm the UI reports the
   error instead of silently losing progress.
9. Use **Checkpoint Now**, then `/reload`, and confirm no duplicate stocks, credits or
   campaign payments are replayed.
10. Let a shop day pass (15 minutes), confirm rent/wages appear in the Ledger.
11. Trigger an event naturally; resolve both options over a couple of occurrences.
12. Export a full backup, reset, import; confirm full progress including history returns.
13. Watch for taint or "blocked" messages (there should be none; no secure APIs are used).
14. Corrupt one committed journal chunk (edit a `GPSA`/`GPSB` macro body in the macro
   window), then log in: the bounded load must report `Saved shop could not be loaded
   (journal payload is corrupt)` or `journal is incomplete`, settle within its four
   attempts, leave the shop in one coherent state, allow `/gps verify` to write a
   replacement generation, and keep that replacement after another restart.

## Campaign simulation (dev-only)

`npm run sim:campaign` (or `node tools/sim_campaign.js --hours 6 --seeds 3`)
plays the real addon under the mock with a fixed policy: sells at the counter,
haggles, pays the three deed notes, buys a tier when it pays back inside an
hour of the current rate, keeps stock and buys upgrades. It prints
time-to-milestone, credits/hour per tier and flags anything that looks like a
grind wall. `--accept-only` and `--tier-first` bracket other play styles, and
`--verbose` prints the 15-minute timeline. It is a tuning aid; nothing in
`tools/` ships in the ZIP.

Three six-hour seeds before the balance probe: first note 66 min, second
120 min, final 266 min, tier 2 at 43 min, tier 3 at 171 min. The opening is
income-bound at tier 1 (~1,700 gc/h operating), not gated by a price. The final
note is a deliberate 2.2 h save at tier-3 income, but the tier-3 shop cost
6,500 - more than the second note itself - so every run postponed it until
after the note. Lowering it to 5,000 moved the final note to 221 min (median)
and tier 3 to 116 min, at the cost of the second note sliding to 145 min
because the policy invests in the tier first. Tier 4 (32,000) stays above the
final note and remains post-campaign content; tier 5 is endless mode only.

### Iteration 2 — customers who read the room

Iteration 1 fixed what the shop *rewarded*. This pass fixed what it *said*. Every
archetype had one greeting pool, one accept pool and one leave pool, and the negotiation
window rewrote its font string every second. The result was nine voices that went stale
after three visits, and a dialogue panel that could clip a long sentence mid-word.

**The dialogue is one data file.** `Data/Dialogue.lua` owns the resolver and the pools;
`Data/Personalities.lua` still owns behaviour and the flat per-key base line that other
systems use. Each archetype has six contextual pools - `greetPrefer`, `greetFine`,
`acceptRich`, `refuseOver`, `refuseInsult`, `leaveFurious` - plus the base `greet`,
`offer`, `accept`, `refuse`, `leave` lines. Context is derived from state the shop
already has:

| Context | Source |
| --- | --- |
| price band | `customer.offer` vs `Market.Value(item)` (rich / fair / low) |
| quality | `item.quality` >= 3 |
| preferred category | `U.contains(personality.prefer, item.category)` |
| mood | `customer.patience` vs `patienceMax`, and the haggling flag |
| reputation | `Shop.Reputation()` label, used in the greeting pools |

Pools are chosen in `D.Variants` priority order (greet: prefer then fine; accept: counter
then rich; refuse: insult, then over-reach, then furious), and each resolves through
`U.fill`, so a missing `{item}` or `{price}` cannot leak a brace into the frame. An
unknown archetype, a missing item or an empty pool lands on `D.Fallback`, which is also
two lines per key - a blank quote pair is now impossible.

Design decisions worth keeping:

- **The save holds indices, not strings.** Six entries of `scope * 16 + index`, newest
  first, is roughly a dozen characters in a journal that is measured by the character.
  Strings would cost 60+ base64 each for the same information.
- **Cosmetic text never draws from `math.random`.** Line choice is a deterministic
  rotation over the unblocked candidates. This was not the first implementation: when it
  used `math.random`, the shared stream shifted and the fixed-policy campaign sim fell
  from "all four seeds finish" to two - proof that a cosmetic draw can move loot and
  haggling rolls. Nothing in the dialogue path consumes gameplay randomness now, and the
  campaign probe is back to four of four seeds.
- **The memory yields rather than starving.** A two-line pool fills its own memory after
  two draws; instead of repeating the newest line it drops only that entry and picks among
  the rest, so a two-line pool still alternates forever.
- **The window is written, not redrawn.** `UI/NegotiationFrame` compares the composed
  string before `SetText`, caps the font string at three lines, and refreshes when the
  customer or item changes, so the panel no longer re-wraps once a second.

Verification on this branch: `npm run check` exit 0 (**62 files, 19,010 lines**, TOC OK),
`npm test` exit 0 with **71 passed, 0 failed** (four new: the archetype sweep over
greet/offer/accept/refuse/leave, contextual selection incl. unknown archetype/missing
item/unknown preference, anti-repeat determinism with a save round trip of the memory,
and old/broken saves), UI smoke green, `node tools/sim_30min.js` at 41 sales / tier 2 /
reputation 167, and `node tools/sim_campaign.js --hours 4 --seeds 4` reaching every
milestone on all four seeds.

Known issues:

- The three-line cap is a compromise for the existing 76px panel; a very long line loses
  its tail instead of growing the window. Nothing exceeds three lines at 100% scale in the
  mock, but a large font or a small UI scale could clip.
- The campaign sim is deterministic but policy-fragile: any change in the number of RNG
  draws reshuffles every seed, so sim-to-sim comparisons are only meaningful for the same
  draw count. That fragility is in the sim's fixed policy, not in the addon.
- Nothing here has run inside World of Warcraft; the dialogue panel, the three-line cap
  and the fonts are unverified in the live client.

### Iteration 3 — regulars

Iteration 2 gave the shop nine voices; this pass gave it a cast. Every customer was
still a stranger, so the dialogue could be as specific as it liked and nobody ever came
back to hear it. Three faces can now be remembered.

| Knob | Value | Why |
| --- | --- | --- |
| remembered faces | 3 | enough to feel like a neighbourhood, small enough to read at a glance |
| chance an arrival is a regular | 0.10 + 0.03 per repeat visit, max 0.30 | the roof never becomes a private club, and a shop that treated people well sees them more |
| good sale | 80% of the customer's own hidden ceiling | rewards pushing a counter near the limit, not dumping stock |
| extra haggling round | from visit 2 | makes a familiar customer feel easier without changing the odds maths |
| loyalty premium | 5% from visit 4 | small, sale-backed, and only after a real relationship |

Design decisions:

- **Only a completed sale creates a regular.** `Remember` is called from
  `Negotiation.completeSale` with the credited price, so there is no path to goodwill
  through a timeout, a button or a failed haggling round.
- **Identity is the memory.** Name, race, class, occupation and archetype are stored, and
  the spawn path reuses them, so the same person walks in with their own greeting pool
  (`greetReturn` on every archetype) rather than a new stranger's name on a familiar line.
- **The journal still fits.** Regulars are identity strings, so `DB.Snapshot` empties
  them before the macro-journal fallback is encoded; SavedVariables keeps them and the
  next normal save restores them. Documented rather than paid for in the character budget.
- **Selection is sub-linear.** Weight grows with visits at half rate, so the face you
  have seen most cannot take most of the arrivals away from the other two.
- **No new timers or polling.** `SpawnOptions` runs only when the shop was already going
  to spawn an arrival, and loyalty is two number reads.

Verification on this branch: `npm run check` exit 0 (**64 files, 19,365 lines**, TOC OK),
`npm test` exit 0 with **75 passed, 0 failed**, UI smoke green, `node tools/sim_30min.js`
at 42 sales / tier 2 / reputation 152, and `node tools/sim_campaign.js --hours 4 --seeds 4`
still reaching all three deed notes on 4/4 seeds (final note median 166:42). A 30-minute
probe printed the remembered faces: `Theric Bloodfeather:2, Wren Boltfizz:2, Wren
Mekkatorque:1` — regulars form in ordinary play, not just in tests.

Known issues:

- The loyalty premium is deliberately small, so its economic effect is inside simulation
  noise; the tuning is defensible but not proven to be the *best* number in a live shop.
- A regular whose name collides with another generated identity would merge visits during
  normalization; with generated names this is vanishingly rare and harmless.
- Nothing here has run inside World of Warcraft: the "Returning visitor (N)" line in the
  Customers tab, the new greeting pool and the whole loop are mock-only.

## Notes for the next agent

- `Modules/Diagnostics.lua` is the shared test surface for both `/gps test` and the
  harness. Add an economic test for every new reward or reset.
- `tools/smoke_ui.lua` only exercises UI the harness can show; the Deed tab is included
  in the tab sweep, but its click flows still need the live checklist.
- Journal persistence is deliberately **state restoration only**. Do not add offline
  catch-up earnings without a separate exploit review and stock-consumption proof.
- Keep the macro journal's campaign fields ahead of inventory if the 24-chunk budget is
  ever tightened; trimming lowest-value inventory first is intentional.
