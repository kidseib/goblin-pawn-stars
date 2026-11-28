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
`npm run check` reports 64 files and 20,121 lines on this branch.

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

### Iteration 5 — a patron worth having

Iteration 4 built the order loop and left three things on the table: the order was only
visible inside the Customers tab, its card was never checked at a non-default UI scale,
and "patron" was a 2% offer lift. This pass closes all three, and the audit turned up a
save bug underneath them.

| Knob | Before | After | Why |
| --- | --- | --- | --- |
| patron budget | 2.6x tier | 3.2x tier | a relationship should buy bigger errands, not just a better price |
| patron deadline | 2 days | 3 days | they trust the shop with the search; still bounded by the day clock |
| patron premium | 1.35x market | 1.50x market | pays for the shelf space a patron order occupies, still inside the named budget |
| patron reputation | +8 | +12 | the relationship is the reward; reputation is what the shop spends |
| patron goodwill | +1 visit | +2 visits | a patron delivery counts double toward the next loyalty tier |
| patron offer lift | 1.02 | 1.04 | small, permanent, applies to everything they buy |
| patron arrival weight | 1.0 | 1.5 | the felt part: patrons come back more often than ordinary regulars |
| patron ask rate | 0.50 | 0.75 | and they are likelier to have a request when they do |
| promotion | history line | history line + toast + an immediate bigger order | the milestone hands the player something to do |

Design decisions:

- **The promotion places an order right away.** Without it, patron status could only be
  felt on the *next* order cycle, which in a 30-minute session is nearly never. Handing
  over a larger errand at the moment of promotion makes the milestone legible and gives
  the premium somewhere to land. It is the same order system, capped the same way.
- **Status is carried, not recomputed.** `patron` lives on the regular, `patron` also on
  the order (so a deadline stays generous even if the flag changes), and both survive the
  normalize rebuild. It is a boolean, not a new table.
- **Awareness is one chip in the title bar, not a new surface.** The title bar is the only
  strip that is on screen whichever tab is open, it already carries the shop-day bar and
  the save health, and the chip is styled from the same palette. It names the shelf and
  the days left, escalates to red on the last day, and carries a real tooltip; clicking it
  is the existing `ShowTab("customers")` path. No new timers: the existing one-second
  header refresh reads at most three orders.
- **The card fails safe instead of growing.** The bar moved from a fixed offset to the
  card's bottom edge; the text is a bounded box; `Widgets.FitLines` keeps the longest run
  of lines from the end that fits the measured height, so the order line outranks the
  daily buyer line at large fonts. `GetStringHeight` is used when the client has it and a
  line-count estimate when it does not, so the mock and older clients behave predictably.
- **Fixed while auditing:** `Persist.normalize` rebuilt every regular from a fixed field
  list, which silently dropped `patron`, `fulfilled` and `souredDay` on every load. That
  is why patron status would not have survived a relog, and it also meant iteration 4's
  save test was passing without covering it. All three are now carried and clamped.

Balance measurements (six seeds x 30 simulated minutes, same policy in every mode):

| Mode | Orders placed / filled / lapsed | Order revenue | Gross earned | Order share | Reputation | Patrons |
| --- | --- | --- | --- | --- | --- | --- |
| on (sources the shelf) | 4.0 / 3.3 / 0.0 | 599 gc | 3,561 gc | 16.8% | 183 | 0.67 |
| off (feature disabled) | 0 / 0 / 0 | 0 | 2,373 gc | 0% | 142 | 0 |
| ignore (never sources) | 1.5 / 0.0 / 0.5 | 0 | 3,021 gc | 0% | 151 | 0 |
| on, patron rewards disabled | 4.0 / 3.3 / 0.0 | 593 gc | 3,653 gc | 16.2% | 178 | 0.67 |

The loop pays for attention and not for existing: sourcing orders beats ignoring them by
about 18% gross and 32 reputation over half an hour, while ignoring still leaves a working
shop. Order revenue is now ~17% of gross because the promotion order and patron budgets are
bigger — that is the intended shape, one premium sale in five rather than in nine. Patron
status itself adds a small measurable slice in a 30-minute window (+5 reputation, more
deliveries) and a much larger one in play, because the patron's bigger errand is already
open when the session continues. The `on`/`off` gap (3,561 vs 2,373) is larger than the
order share because order arrivals also displace plain walk-ins with regulars, who pay the
loyalty premium — the same effect iteration 3 introduced, amplified by a cast that now has
something to come back for.

Progression checks (same builds):

- `sim_30min`: **1,222 gc, tier 2, 40 sales, reputation 166**, regulars 3, orders 2 placed /
  1 filled / 0 lapsed, order sales 247 gc, 18,540 export characters / 2,759 compact.
- `sim_campaign --hours 4 --seeds 4`: every milestone on **4/4 seeds** — first note 57:38,
  second 114:04, final 180:19, tier 2 37:34, tier 3 88:19, museum 110:52, Marta 57:44.
  No seed starves and no seed finishes early.

Known issues from this pass:

- **Nothing here was seen in the live client.** The chip lives in the title bar next to the
  `?` button and the card layout is proven by anchors and measured text heights in the
  mock, but no font, texture or frame has been looked at in game. A large font is the
  specific case to try first.
- `GetStringHeight` is the only real measurement path; on a client that lacks it the
  fallback assumes one line per entry, so a *wrapped* long line could still overlap the
  bar in that fallback. Names are elided to 16 characters to keep that from happening.
- Patron arrival weight of 1.5 is tuned from the probe, not from a long session. If three
  patrons exist, the shop becomes noticeably patron-heavy; the 0.30 ordinary ceiling is
  unchanged, so strangers still arrive.
- The patron greeting lines are new prose and unread in game.

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

### Iteration 4 — special orders

Iteration 3 gave the shop a cast; the cast had nothing to do but browse. This pass turns a
regular into a small standing goal: they come back wanting one shelf of goods, name a
budget, and give the player two shop days to find it.

| Knob | Value | Why |
| --- | --- | --- |
| asks per arrival | 0.50 | measured 3.2 orders per 30-minute session — one every ~9 minutes, rare enough to feel like an event |
| minimum visits | 1 | one remembered sale is the entry ticket; requiring two made the loop absent in 4 of 6 probe seeds |
| deadline | 2 shop days (30 minutes) | 4 days never lapsed in a 30-minute session, which made the gamble toothless |
| premium | 1.35x live market value, capped by the named budget | ~33% over a good haggled sale, and it still removes the unit through `completeSale` |
| budget | tier budget x 2.6 | reads as a real ceiling early on; it stops being the binding constraint as tiers rise |
| reputation | +8 delivered / -4 lapsed | a delivery is worth more than two ordinary sales; a lapse stings and never wipes progress |
| goodwill | +1 visit on delivery, -1 on lapse | makes the relationship itself the reward |
| patron | 2 deliveries | permanent 2% offer lift; small, permanent and visible in the queue |
| caps | 3 orders, 1 per regular | bounded save state; one regular cannot monopolise the board |

Design decisions:

- **The order is placed by the regular, at arrival, in their own voice.** There is no
  order board the player opens and no new window: the mechanic rides the arrival path the
  addon already had (`Regulars.SpawnOptions` → `Customers.TrySpawn`).
- **The wanted shelf is one the shop is short of**, preferring categories the wholesaler
  is currently offering. That is what makes it an errand instead of a formality, and it
  keeps the loop solvable without a loot drop.
- **A fillable order gets first refusal on the next arrival** (55% per arrival, before the
  ordinary regular roll). Without this the payoff was a blind bet: the regular who asked
  almost never came back while the stock was still on the shelf.
- **Collecting opens near the ceiling (90%) rather than at a haggle opening.** The order is
  a stated price, so accepting it is the reward for having held the stock. Ordinary
  bargaining still happens with everyone else.
- **Lapsing runs on `Shop.EndShopDay`**, the 15-minute day clock that already exists. No
  new timer, no polling, one pass over at most three rows per day.
- **Journal snapshots strip orders** exactly like regulars: they carry names, and the
  macro journal is measured in characters. SavedVariables carry them; the journal does not.

Balance measurements (six seeds x 30 simulated minutes, same policy, feature on / off /
ignoring orders):

| Mode | Orders placed | Delivered | Lapsed | Order revenue | Gross earned |
| --- | --- | --- | --- | --- | --- |
| on (sources the shelf) | 3.2 / session | 2.8 | 0 | 267 gc (11% of gross) | 2,411 gc |
| off (feature disabled) | 0 | 0 | 0 | 0 | 2,606 gc |
| ignore (never buys the shelf) | 2.5 / session | 0.3 | 0.7 | 51 gc | 3,040 gc |

The order premium is a real but bounded slice of revenue: about one sale in three is an
order, worth roughly 11% of gross. With orders on, gross earned is *not* higher than with
them off (2,411 vs 2,606) because an order customer displaces an ordinary arrival and
because the player spends credits sourcing the shelf — the loop pays for the decision, not
for existing. Ignoring orders shows the intended failure mode: orders lapse, reputation
drops (123 vs 135 and 108 vs 140 on two seeds) and no premium is collected. Lapses did not
occur in the "on" runs at all, which is the point: an attentive player converts.

Known issues from this pass:

- The order premium of 1.35x is validated only against the headless policy. A player who
  buys the wanted shelf at wholesale and sells it at the premium can chain orders; the cap
  of three open orders and the 50% ask chance are what bound it, and a live session may
  want `orderPay` closer to 1.25.
- The queue row, the counter meta and the wanted panel all gained text. They fit at 100%
  UI scale in the mock (`WANTED TODAY` now carries two lines above its bar), but a large
  font or a small UI scale has not been checked. *Addressed in iteration 5 (bottom-anchored
  bar, bounded text box, `Widgets.FitLines`); still unseen in game.*
- The order greeting and acceptance pools are new prose; nobody has read them on a live
  client.
- The `ignore` probe buys no wanted shelf at all, which is a harsher player than reality;
  a half-attentive player sits between the `on` and `ignore` rows.

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

### Iteration 6 — the clean deal and the ceremony

Two features from the ten-feature plan, chosen because they cost almost nothing per frame
and change how the moment-to-moment haggling *feels*: a hot hand you can lose, and a
milestone you can see. Nothing here is saved except one integer.

**The counter streak.** `Data/Streak.lua` holds the tuning (threshold 5, +10% on the next
sale, +2 reputation, clamp 0.10) and `Modules/Streak.lua` holds the state in two module
locals. It is session-only on purpose:

- saving it would let a player park four wins, log out, and carry an armed perk into any
  later sale — an unlimited, if slow, money channel;
- it would need a save migration for a number that is more fun when it can be lost;
- with no `db` field there is nothing to corrupt, trim, explode or exploit. A relog is a
  clean streak by definition, so "reload restores a streak-free state" needs no code.

The state machine is one counter and one boolean: `Hit()` (landed counter) increments
until the ceiling, `Miss()` (declined/insulted/walked) zeroes the counter, `Consume()`
spends the armed perk inside `completeSale` and resets. `Miss` deliberately keeps an
armed perk: a streak is a hot hand, but confiscating a reward the player already earned
reads as punishment, not difficulty.

The perk pays through the bonus ratio `completeSale` already used for the daily request,
so it cannot create money outside a real sale: the item still leaves stock, the credits
still come from a customer, and the sale still writes one ledger line. It is clamped to
`maxBonus` so future tuning cannot stack two armed deals, and it is spent before `Hit()`
for that same sale, so the winning sale cannot re-arm it. Pricing in `/gps`-visible terms:
five good counters in a row pay one sale an extra 10% of its agreed price, roughly one
sale in five — a visible reward that is smaller than the reputation and regular-visit
effects already in the game, which is what keeps it from being the optimal strategy.

**The ceremony.** `Modules/Ceremony.lua` compares the reached reputation tier with
`db.shop.celebratedTier`, celebrates at most one newly crossed tier, and never repeats one.
Because the flag is saved and clamped in `Persist.normalize`, a relog restores the pips and
stays quiet; only a tier crossed *after* this build fires, and jumping two tiers in one
gain announces only the top one. Deeds reuse the list `Achievements.Check` already returns
(already persisted) and celebrate quietly, because that screen already prints and toasts
the unlock itself. Presentation reuses the existing toast panel, `ns.Anim.Reveal/Pulse`
and the native `achievement` fanfare: three icons, one pulse each, a one-shot 1.25 s hide
behind a revision counter so overlapping milestones cannot strand a panel on screen.

**What it cost.** Both features hook events that already fire (a landed counter, a
reputation change from `AddReputation`, the once-a-second header refresh) and do integer
comparisons. No new timer, no `OnUpdate`, no frame work, no table growth. The only new
widgets are one label and one bar in the negotiation title bar, four static pips and a
caption in the sidebar, and one lazily built celebration panel reused forever.

**Measurement.** `tools/` benchmark (temporary, `/gps profile`'s counter is in-client
only) driving the same workload on this build and on the previous head `c987eac`, headless
under fengari:

| path | previous head | iteration 6 |
| --- | --- | --- |
| negotiation refresh, 8,000 calls | 0.013–0.014 ms/call | 0.013–0.015 ms/call |
| main-frame refresh, 800 calls | 0.95–1.03 ms/call (3 runs) | 0.94–1.05 ms/call (3 runs) |
| celebration panel, 200 builds | n/a | 0.28 ms/call (event only) |

Ranges are three runs each; the two builds overlap, so no measurable regression. The
header refresh runs once a second, not per frame; the streak work is three number reads
on the same refresh the window already did. This is VM CPU only — no GPU, no widget
layout, no client frame time, and no in-game FPS claim is made.

**Tests.** Six new headless tests in `Modules/Diagnostics.lua` (89 total): the streak arms
at the threshold, pays once, cannot be spent twice, resets on a botched counter while
keeping the armed perk, pays over the agreed price from the completed sale only, restarts
from the winning sale, never reaches `Export()`, and leaves a fresh `Normalize({})` with no
streak field; the tier ceremony fires exactly once, does not repeat on a second gain or
after an Export/Import round trip, and a deed unlock fires one celebration per unlock but
not again. `tools/smoke_ui.lua` asserts the meter text (`NO STREAK` → `2/5` → `CLEAN
DEAL`), that the celebration panel builds, and that the standing pips follow the flag in
both directions.

**Known issues / not verified.** No WoW client here: the meter's fit in the title bar at
small UI scales, the pip tooltip and the sound choice are harness-only claims. The streak
is not part of `/gps export` by design, so a bug report about it will not reproduce from a
save. The perk's 10% was chosen against the existing reputation/regular-visit effects on
paper, not against live player earnings; it is one constant in `Data/Streak.lua` to retune.

### Iteration 7 — double or nothing

Plan item #3. The negotiation loop had four verbs (accept, counter, reject, appraise); all
of them are safe. This adds one that is genuinely risky, in the voice of the archetype most
likely to offer it.

**What it is.** The Desperate Buyer (`Data/Personalities.lua`, `gamble = true`) puts a flip
on the table: win and they pay `min(ceiling, 2 x offer)`; lose and they pay `0.80 x offer`
and lose 2 reputation. The button sits beside the counteroffer, its label states the odds
and the prize, its tooltip states both outcomes, and the first time it appears the feedback
line spells the whole deal out in one sentence. One wager per customer.

**Why the math looks like that.** A gamble that beats accepting is not a decision, it is a
formality, so the terms are solved backwards from a target: with
`chance = (edge - lossShare) * offer / (prize - lossShare * offer)` the expected value is
exactly `edge * offer` — 94% of taking the safe offer. Two guards keep it there when the
gap between offer and ceiling is extreme:

- the prize caps at twice the safe offer, so a customer whose hidden ceiling is far above
their opening cannot hand out a lottery win;
- the odds clamp to 12–55%, and clamping can only push the value further below the safe
offer (0.938 x offer in the worst case), never above it.

A property test sweeps 60 ceiling/offer pairs and asserts `EV <= offer` for every one, plus
`EV > 0.90 x offer` so the wager stays tempting rather than pointless. The 6% edge is paid
for by taking a real risk on a real sale, not by a hidden tax on the player's credits.

**Why a reputation sting and not gold.** A lost flip already costs money — the difference
between 0.8x and 1.0x the safe offer. Charging gold on top would make the wager a trap that
can go negative, and the addon's economy rule is that credits only move through sales. Two
reputation is recoverable, visible on the standing pips, and stings in a way the player can
feel without being unable to play on.

**Why once per customer, and why it survives a reload.** `customer.gambled` rides on the
customer record that `shop.current` already persists. Rerolling a lost flip by reloading
would have been the obvious exploit, so the flag is sanitized in the existing
`cleanCustomer` pass (no schema change, no new shop field, old saves unaffected) and the
negotiation window re-derives the terms from it. The `Persist` test exports and imports a
used-up wager and asserts a reload offers nothing.

**Why the button is free.** The window refreshes once a second while it is open and asks for
the terms each time. A one-entry memo in `Modules/Negotiation.lua` keys on customer id,
offer, ceiling and the wager flag, so repeats cost three comparisons and no allocation, and
a raised offer or a new customer recomputes. No timer, no `OnUpdate`, no new frame work; the
button is built once with the window and only its label changes when the terms change.

**Settles flat.** The first delivery of this feature shipped a flake that only appeared on
some calendar days: `completeSale` creates the day's request lazily, so a wager on an item
whose category matched that day's request was paid `prize x (1 + bonus)` — the button stated
80 and the player received 101. The flip now calls `completeSale(..., flat)`:  the request is
still marked fulfilled (a real sale happened) but the bonus is not added, so the number on
the button is the number paid. The window journal line still reads `double or nothing · won`
without the `(daily request bonus)` suffix, which is correct for a flat settlement. A
regression test now builds a matching request (`bonus 0.25`, today's date) before the flip and
asserts the payout equals `terms.prize` and the request is fulfilled; without the flag it
fails deterministically.

**Measurement.** Temporary headless benchmark (deleted), previous head `7bb0b32` vs this
build, four runs each under fengari:

| path | previous head | iteration 7 |
| --- | --- | --- |
| negotiation refresh, 8,000 calls | 0.0106–0.0154 ms/call | 0.0121–0.0158 ms/call |
| main-frame refresh, 800 calls | 0.93–1.08 ms/call | 0.90–1.01 ms/call |
| same-process split | — | trader 0.0057–0.0073, desperate 0.0049–0.0089 ms/call |

Ranges overlap; the same-process split (a customer who can gamble versus one who cannot)
shows no difference at all, which is the honest test of whether the wager adds per-refresh
work. Terms in isolation cost ~0.03 ms per computation in the harness, and that runs once
per customer or offer change, not per refresh. VM CPU only — no GPU, no widget layout, no
in-game FPS claim.

**Tests.** Six new headless tests (95 total): honest odds and non-positive edge across 60
offer/ceiling pairs; availability (only a gambler, only with a real gap, only once, never
with a zero offer); a won wager sells exactly one unit out of a 200-stack shelf at the
stated prize and cannot be repeated; a lost wager pays the stated discount, records exactly
one negative reputation call and moves no other credits; a used wager survives
`Export`/`Import` with no new save field; and the no-customer / missing-stock paths pay
nothing. `tools/smoke_ui.lua` drives the real window: the button appears for a desperate
buyer, its label carries the odds, clicking it pays the stated prize and the payout banner
equals the credits added, and the button is hidden for a trader. `npm test` was run 10 times
back to back after the flat-settlement fix (95/95 and a green UI smoke every time) because
the earlier version had a date-dependent flake.

**Economy.** `sim_30min` and the six-seed campaign are unchanged to the digit (1,222 gc /
tier 2 / 40 sales / rep 166; medians 57:38, 114:04, 180:19, tier 2 37:34, tier 3 88:19,
museum 110:52). Expected: the wager is player-driven, so it never fires in a simulation; its
balance is argued by the property test above, not by the sims.

**Known issues / not verified.** No WoW client here: the two-line button label at large font
sizes or a non-100% UI scale, the tooltip layout and the exact wording of the new lines are
harness-only claims. The wager is deliberately absent from the simulations, so its effect on
a real player's earnings per hour has not been measured — only its expected value per flip.
The 0.94 edge and 0.80 loss share are two constants in `Data/Gamble.lua` if the balance ever
needs to move.

### Iteration 8 — the A-board (plan item #4)

Plan item #4. The shop already had a daily *request* — a customer's want, rolled at dawn
and paid once on the first matching sale. A "specials board" that advertised a category for
a bonus would have been that same idea with different furniture, so the A-board became the
other half of the exchange: the request is what buyers want from you, the board is what
*you* tell the street.

**What it is.** `Data/Board.lua` holds one placard per category — headline, one-line blurb
and a lift band. Bulk lines get the biggest lift (cloth, herbs, ore, leather, potions:
12–16%) because they need it to compete with the request; premium lines (gems, weapons,
armour, companions) get 8–11% because they move on their own. Each shop day
`Modules/Board.lua` offers **two** placards, drawn from the categories actually on the
shelves, and the player chalks one. For the rest of the day every sale of that category
pays the placard's lift, and the wait for the next customer is multiplied by 0.88. It
clears when the day changes and can be chalked once per day.

**Why a choice, and why footfall instead of assortment.** The request is luck; the board is
the shop's own advertising, so it should be a decision — which of your lines do you push
today — and it should be legible in play. The first implementation biased *which item a
customer brings* toward the advertised category (weight 1.6x). A six-seed probe showed that
is the wrong lever: it concentrates sales on whatever the advertised line happens to be,
so advertising a cheap line drains it and earns **less** (−7.7% revenue across six seeds).
Traffic is the honest lever for a sign: the arrival interval shrinks while the board is up
(one multiplier inside `Shop.ArrivalInterval`, no second scheduler) and the lift pays on
sales that were going to happen anyway. Re-measured the same way: **+3.6% revenue, +15%
sales** across six seeds, and the pick is provably untouched (a diagnostics test samples the
same trader 400 times with and without a board and requires the category mix to stay put).

**Deterministic, so a reload cannot reroll it.** The lift and the day's pair are hashed from
the date string and the category with `U.hash`, the same trick `Data.BaseValue` uses for item
values. Nothing is rolled, so the saved state is only `{ day, key }`: the percentage is
derived from the data every time it is read, so it can never drift from the save, and
`Board.Active()` is one string compare — a board from an earlier day simply stops counting,
with no timer and no cleanup pass. `Persist.normalize` keeps a table only when the key is a
category the data knows, and rewrites it as `{ day, key }`; an old save gets the additive
default `nil` and the morning's board has to be chalked again.

**Where the money comes from.** `completeSale` adds the board lift after the daily request,
before the wallet delta, so the payout banner still prints exactly the credits that were
received. A flat settlement (the wager) ignores it and keeps the figure it quoted — the same
rule the flat flag already applies to the request bonus. The negotiation window prints
`A-board +N%` beside the category *before* the player names a price, so the lift is never a
surprise, and the ledger's sale detail tags `A-board bonus` next to `daily request bonus`.

**What it costs.** One table lookup per sale, one multiplier per arrival-interval
computation, and one bounded inventory pass in the dashboard refresh (stops at 400 stacks)
to count how much of the advertised line is on the shelves. No timer, no `OnUpdate`, no new
frame: the two board buttons are built once with the tab and only their labels and
visibility change. The TODAY card grew 38 px and the panels below moved down with it; the
content pane still has ~8 px to spare under the goal card.

**Measurement.**

- Baseline unchanged: `sim_30min` FINAL 1,222 gc / tier 2 / 40 sales / rep 166 / best 290 and
the four-seed campaign medians 57:38, 114:04, 180:19, tier 2 37:34, tier 3 88:19, museum
110:52 — identical to the recorded baseline, because neither harness chalks a board. That is
the expected result: the board is a player decision, and the harness policy does not make it.
- Board probe (temporary, deleted): the same scripted policy and the same six seeds run
twice, board on and board off — 18,553 vs 17,914 credits earned, 270 vs 235 sales (+3.6%
revenue, +15% sales, median seed 2,834 vs 2,505). Individual seeds range from −23% to +128%,
because extra footfall makes the fixed policy exhaust cheap stock and shifts when it buys
the next tier; the aggregate is the honest read and the spread is the policy, not the board.
- Export size fell 39 characters (18,694 → 18,655): the ledger's sale detail no longer
carries a trailing space when no bonus applies. Every economic figure is identical.

**Tests.** Six new headless tests (101 total): the catalogue (two distinct stocked lines,
stable across reads on one day, lift inside its band, stated percent equals paid lift, no
board for an empty shop); once-per-day chalk plus reload, stale-day expiry and junk-save
sanitization; a featured sale paying exactly `offer * (1 + lift)` with one unit leaving stock
and the ledger tagged; a flat wager still paying exactly its quoted prize; footfall (exact
`BoardTraffic` multiplier, category mix unchanged over 800 samples); and an unchalked day
paying exactly the plain offer. `tools/smoke_ui.lua` drives the real dashboard row: two
buttons with the lift in the label, a click that chalks, the chalked line and shelf hint
after the refresh, and a negotiation window that reports the lift and pays it.

**Known issues / not verified.** No WoW client here: the two 162x24 buttons at 0.8–1.2 UI
scale and large fonts, the multiline tooltip and the 38 px taller TODAY card are
harness-only claims (the mock builds them and asserts the row exists, not that it looks
right). The probe cannot play the board as well as a person choosing their best line, so
+3.6% is a floor-ish sanity number, not a balance proof. Knobs: `Data.BoardTraffic` and each
placard's `low`/`high` in `Data/Board.lua`.

## Notes for the next agent

- `Modules/Diagnostics.lua` is the shared test surface for both `/gps test` and the
  harness. Add an economic test for every new reward or reset.
- `tools/smoke_ui.lua` only exercises UI the harness can show; the Deed tab is included
  in the tab sweep, but its click flows still need the live checklist.
- Journal persistence is deliberately **state restoration only**. Do not add offline
  catch-up earnings without a separate exploit review and stock-consumption proof.
- Keep the macro journal's campaign fields ahead of inventory if the 24-chunk budget is
  ever tightened; trimming lowest-value inventory first is intentional.
