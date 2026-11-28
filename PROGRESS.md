# PROGRESS

## Current state — v1.7.9

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
timing changed. The headless suite is **59 tests**; UI smoke is green.

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
session unable to write at all. The suite is **59 tests**. This work has not run in
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
npm run check              -> Lua 5.1 syntax OK: 61 files, 17,498 lines; TOC OK
npm test                   -> 59 passed, 0 failed; UI smoke: all tabs and overlays
node tools/sim_30min.js    -> FINAL 449 gc, tier 2, 40 sales; idle probe 17 auto-sales
```

Those four commands were run inside a fresh `git clone` of `main` in a throwaway
directory, not in the working tree, so the numbers above describe exactly what a
clean checkout produces. The 1.7.9 journal tests are counted in the 59. Earlier
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
2. `/gps test` prints 59 PASS lines in chat.
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

## Notes for the next agent

- `Modules/Diagnostics.lua` is the shared test surface for both `/gps test` and the
  harness. Add an economic test for every new reward or reset.
- `tools/smoke_ui.lua` only exercises UI the harness can show; the Deed tab is included
  in the tab sweep, but its click flows still need the live checklist.
- Journal persistence is deliberately **state restoration only**. Do not add offline
  catch-up earnings without a separate exploit review and stock-consumption proof.
- Keep the macro journal's campaign fields ahead of inventory if the 24-chunk budget is
  ever tightened; trimming lowest-value inventory first is intentional.
