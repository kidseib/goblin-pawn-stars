# Changelog

All notable changes to Goblin Pawn Stars. Format loosely follows Keep a Changelog.

## [Unreleased]

Development continues on the `refinement-polish` branch; `main` stays at 1.8.0. Nothing
below is released yet.

### Added

- **Special orders from regulars.** A remembered customer can now come back wanting
  something specific: one shelf of goods (gems, herbs, recipes...), a stated budget
  ("up to 1,684 credits") and a deadline of two shop days. The wanted shelf is chosen
  from what the shop is shortest of, preferring what the wholesaler is currently
  offering, so the order is an errand the player can actually run. Turning up with it
  pays 1.35x live market value inside the named budget, +8 reputation and extra
  goodwill; two delivered orders make that customer a **patron**, with a small
  permanent lift on what they will pay. Letting the deadline pass costs 4 reputation,
  one remembered visit and a two-day sulk, and the regular stays on the books — a real
  cost, never a catastrophe. Orders live in `db.shop.orders`, capped at three, cleaned
  by an additive `Persist.normalize` pass and deliberately stripped from journal
  snapshots. The `Customers` tab shows the request and its urgency in the existing
  wanted panel, in the queue row and at the counter, plus an order-greeting and
  order-acceptance pool for every archetype.
- **Regulars: customers who remember the shop.** A sale that met the customer's own
  hidden ceiling is remembered — name, archetype, race and visit count — in
  `db.shop.regulars`, and that person can walk back in later instead of a stranger.
  Returning visitors keep their identity and say so in their own voice ("You again. I
  have been watching this place."), get one extra haggling round from their second
  visit, and pay a 5% loyalty premium from their fourth. The list is capped at three
  faces, weighting favours the people who come most often, and the doorway never turns
  into a private club (30% ceiling). Every credit still comes from a sale — the premium
  only raises what a returning customer will pay for stock.
- **Customers who read the room.** Every archetype used to talk from one pool per
  moment, so the third visit from the same personality sounded like the first. Greetings,
  haggling pushback, refusals and walk-aways now come from contextual pools that know the
  piece on the counter: the preferred-category greeting, the "good quality" greeting, the
  rich-offer acceptance, the over-reach and insulted refusals, the furious walk-away. All
  of it lives in one data file (`Data/Dialogue.lua`), 6 pools x 9 archetypes x 2 lines,
  with a generic fallback so no personality can ever render a blank frame.
- **Customer dialogue remembers what was just said.** The last six chosen lines are kept
  in the save as small packed indices (no strings, no growth beyond six) and skipped while
  another line is available, so consecutive visitors, and even consecutive rounds with
  the same customer, cannot repeat. A relog keeps the memory, so the first customer after
  a restart does not repeat the last one from before it.
- **Reputation milestones with real perks.** Reputation used to be a number beside the
  shop name and a small price modifier, so a lifetime of good deals felt like filling a
  bar. Four milestones now unlock concrete perks, in order: **Known** (100) one extra
  waiting slot, **Respected** (250) +2% rare customers, **Trusted** (500) one extra
  haggling round, **Legendary** (800) +5% on every offer. Perks are cumulative, and the
  Dashboard reputation tile lists all four, unlocked or not, when you hover it.

### Added

- **Counter streak — the clean deal.** Every counteroffer that lands now fills a small
  meter in the negotiation window's title bar (`STREAK 3/5`, gold from the first landed
  counter, then `CLEAN DEAL +10% next` when the perk arms). Five landed counters in a row arm one clean deal: the next
  counter that lands pays 10% over the agreed price (the customer rounds up), adds 2
  reputation, flashes the payout banner and reads `Clean deal!` in the feedback line —
  then the meter resets to zero. The streak is session-only and deliberately not saved,
  so it cannot be banked across a relog; a botched counter clears the meter but keeps a
  perk that was already earned. The bonus only ever rides on a completed sale (the unit
  still leaves through `Inventory.Remove`), is clamped by `Data/Streak.maxBonus`, and is
  spent exactly once — roughly one sale in five good haggles, never stackable.
- **Deed and reputation ceremony.** Crossing a reputation tier, and completing any deed,
  now fires a 1.25-second celebration — three pulsing icons on the existing toast panel,
  the native achievement fanfare and a one-line toast — instead of only a chat message.
  The shop also gains a permanent visual flag: one **SHOP STANDING** pip in the sidebar
  per tier reached, with a tooltip listing every tier earned or missing. The flag travels
  in `db.shop.celebratedTier` (additive, clamped, 0 on old saves), so a relog restores the
  pips and never replays the fanfare.
- **Patron status is a relationship now, not a footnote.** Two delivered orders
  still make a regular a patron, but what that buys has teeth: their orders carry a
  23% larger implied budget (3.2x the tier budget instead of 2.6x), one extra shop day
  to fill them, and they pay 1.5x live market value for the shelf they asked for
  instead of 1.35x. Delivering to one is worth 12 reputation instead of 8 and two
  remembered visits instead of one, and their standing offer lift went from 2% to 4%.
  The part a player feels first is the door: a patron takes half again the arrival
  weight of an ordinary regular and asks for something 75% of the time instead of 50%,
  and the moment they are promoted they hand over a bigger order, so the milestone
  immediately becomes something to do. Patrons also greet the shop in their own voice —
  nine archetypes x 2 new lines — and read as `Patron order` in the wanted panel and as
  a gold `Patron` badge in the queue. Still bounded: one order per regular, three open
  at once, every credit from a completed sale.
- **Special-order awareness outside the Customers tab.** A single chip in the shop's
  title bar names the shelf and the days left, turns red on the last day, carries a
  tooltip with who wants what for how much, and opens the Customers tab when clicked.
  It is the one strip that is always on screen, so stocking, buying wholesale or
  watching the day clock no longer hides a pending deadline. Hidden when nothing is
  open, sized to its own text, refreshed by the existing header update.

### Fixed

- **Patron status, deliveries and the sulk day were being wiped on every reload.** The
  `Persist.normalize` rebuild of `db.shop.regulars` kept only identity and visits, so a
  patron came back a stranger, finished deliveries reset to zero and a soured regular
  forgot their cooling-off day — which also silently undid part of iteration 4's save
  test. The rebuild now carries `patron`, `fulfilled` (clamped 0-99) and `souredDay`
  additively, and `db.shop.orders` keeps each order's `patron` flag. A save that predates
  the fields gains none of them.
- **The `WANTED TODAY` card no longer pushes its own bar out at large fonts.** The bar
  is anchored to the card's bottom edge instead of at a fixed offset from the top, the
  text is a bounded box, and when the two lines do not fit at the current font the daily
  buyer line is dropped first (the order line always survives), with long regular names
  elided. `Widgets.FitLines` is the pure decision, so the behaviour is tested at normal,
  large and impossible font sizes. Appearance at 100% scale is unchanged.
- **The negotiation dialogue no longer jumps or slices words.** The window rewrote its
  font string every second, which re-wrapped the same sentence and could clip a long line
  mid-word; it is now written only when the text actually changes, wraps to at most three
  lines, and never shows an empty quote pair when a customer has nothing to say.
- Greeting text now refreshes with the customer and the item, instead of holding the
  previous visit's line until the next tick.

### Changed

- **Shop events no longer repeat back to back.** The last two events are remembered in
  the save as two small indices and skipped while at least three candidates remain, so
  the same crisis cannot fire twice in a row or alternate A-B-A for an evening. A relog
  no longer immediately repeats the event you just dismissed.
- Event memory records the event that actually happened rather than the one drawn: a
  draw with nothing to build from falls back to another event, and the fallback is what
  gets remembered.

### Verified

- 83 headless tests (three new for this pass: patron status and order history survive a
  reload, a patron's order is bigger/longer/better paid with the premium reaching the
  hidden ceiling, and the order card fits its own card at any font size), `npm run check`
  at exit 0 (**64 files, 20,523 lines**), UI smoke green (including new assertions that
  the title-bar chip names the shelf and escalates on the last day, and that the card's
  text box clears its bottom-anchored bar), and a six-seed on/off/ignored/patron-disabled
  probe plus both sims. **Not run in the live client.**
- 80 headless tests (five new for this pass: special orders only come from proven
  regulars, a delivered order pays over market value and grows the relationship, two
  deliveries make a patron, a lapsed order costs a little goodwill and nothing
  catastrophic, and orders survive saves while the journal omits them), `npm run check`
  at exit 0 (**64 files, 20,121 lines**), UI smoke green, and both sims run: the
  30-minute probe and the four-seed campaign probe. **Not run in the live client.**
- 75 headless tests (four new: only a done deal makes a regular, the list stays bounded,
  returning customers keep their identity and earn loyalty, and regulars survive a save
  while the journal fallback deliberately omits their names) — plus the four from the
  dialogue pass and the full suite below.
- 71 headless tests (four new for this pass: every archetype x every situation, pool
  selection and fallbacks, anti-repeat determinism with the memory round-tripped through
  a save, and old/broken saves), `npm run check` and `npm test` at exit 0, UI smoke
  green, and both simulations running: the 30-minute probe reaches 41 sales, tier 2 and
  reputation 167, and the four-seed campaign probe reaches all three deed notes on all
  four seeds. **Not run in the live client.**

## [1.8.0] — 2026-11-28

Saving to the macro journal works on a shop that has actually been played, and a save
that hits a full macro list, a name collision or an oversized payload now lands instead
of failing for the rest of the character's life. No gameplay, visual or economy changes.

### Fixed

- **The live `save error`.** `Could not save progress to the macro journal: journal is
  too large, even without stock` refused every save on a small, early shop. One
  generation holds 2,520 base64 characters and the trim could only shed stock, while a
  played shop spent 91% of that budget on field names alone (2,292 characters with no
  stock at all). The payload now packs the stat, settings and market-event sections as
  ordered value arrays, so a played shop with a full stockroom fits: 2,580 -> 2,276
  characters, with 244 to spare and nothing trimmed.
- **A full macro list.** The in-place fallback only ran when `GetNumMacros()` reported
  36 or more, a hardcoded guess at the client's limit. It now triggers on the refusal
  itself, rewrites the generation the journal already owns, and never creates a new
  name when none is free.
- **A name collision.** A player macro called `GPSB01` used to fail every save with
  `macro name collision on GPSB01`. A collision on the new generation is treated exactly
  like a full list; the player's macro is never touched.
- **An oversized payload.** `journal is too large, even without stock` was terminal.
  The snapshot now sheds its optional halves in a fixed order - stock, the museum list,
  then cosmetic settings - and still saves credits, tier, stats, campaign and inventory
  essentials.
- **A failed save left its chunks behind.** An abandoned save now sweeps the generation
  it wrote, so a full list can always be retried.

### Changed

- The header and `/gps journal` say **`load error`** or **`save error`**, never both:
  a refused read and a refused write need different fixes.
- Journal payloads carry `format = 3`. Payloads written by earlier builds still load, and
  missing positions keep their schema default.

### Verified

- 65 headless tests, `npm run check` and `npm test` at exit 0 from a clean clone. The new
  tests each fail on the previous loader/encoder. **Not run in the live client.**

## [1.7.9] — 2026-11-27

Loading the macro journal starts by itself after login again, but it is strictly
bounded, and the autosave writes one macro at a time instead of a whole generation
in one frame. Nothing in this pass changes gameplay, arrivals, stock or the economy.

### Changed

- **Loading is automatic but bounded.** A login arms one short load: at most four
  reads of the macro list at 2, 5, 10 and 30 seconds, one counter, no chained
  retries, and the last attempt always settles. While it runs the header reads
  `loading saved shop` and no save is allowed, so a fresh session can never stamp
  defaults over a run that has not been read. **Settings → Auto-load** turns it off,
  and **Settings → Backup & Restore → Load saved** (press twice) stays as the
  recovery path and the only way in when it is off. `/gps journal` says which path
  loaded the run.

### Fixed

- A journal that would not assemble no longer starts a retry chain. Each failed read
  used to schedule three more reads two, five and ten seconds later, and each of those
  failed the same way, so a stuck journal multiplied macro reads until the client
  stalled. A load is now a single read that reports its error and stops. A journal
  that cannot be restored — an incomplete generation, an unreadable payload, bad
  legacy chunks — settles the load, so the next save replaces it instead of leaving
  the session with no save path at all. An empty macro list at login may be read
  again, because the list can still be arriving, but never more than four times in
  total.
- The login summary no longer calls a returning player a new stall. It is printed
  after the journal's first settled load instead of from the defaults that exist two
  seconds before the saved run arrives, so a restored session says `Welcome back` with
  its real credits, queue and stock.

### Changed (save path)

- The autosave no longer writes every chunk and deletes the retired generation in one
  frame. A save is staged as a queue of single macro operations and the clock spends
  at most **8 ms** a second on it, always performing one operation so it cannot stall.
  The order is untouched: pending header first, every chunk read back, commit header
  last, cleanup after. A save spread over several seconds reports the time it actually
  spent working instead of the wall clock it spanned.

### Tests

- The suite is now **59 tests**. One covers an unloaded session refusing to write, the
  manual load restoring the saved run and saving resuming; another proves an autosave
  writes a single macro per tick, with the pending header first and the commit last; a
  third proves a journal that cannot be assembled settles the load so saving can
  replace it rather than staying blocked forever; a fourth proves the login load stops
  at its read cap, settles on the last attempt, and does not arm when Auto-load is off.

---

## [1.7.8] — 2026-11-27

A presentation and responsiveness pass. Gameplay, arrival timing, stock and the
economy are unchanged.

### Added

- **Settings → Performance mode** (top-right toggle) for lighter clients: class icons
  replace 3D customer portraits, animation helpers take their instant path, and the
  arrival card switches to its compact layout. It is an overlay, so turning it off
  restores the player's existing motion and notification choices.
- The arrival card now queues a second customer as an updated waiting count instead of
  replacing the first customer's name and portrait. It also pauses its dismissal timer
  while hovered and has a close button that dismisses only the card.
- `/gps profile` reports rolling last/max timings for journal saves, backup encodes,
  bag scans and active-tab refreshes. Samples use the existing clock and are taken only
  when the operation runs; there is no new update loop.

### Changed

- The Inventory tab reuses the market values already resolved for the value sort when
  rendering rows, instead of recalculating every visible stack a second time.

### Tests

- The suite is now **55 tests**. UI smoke covers hover-paused arrival dismissal, the
  close control, simultaneous-arrival aggregation, Performance mode on and off,
  class-icon portrait fallback, animation bypass, and compact arrival layout.

---

## [1.7.7] — 2026-11-27

### Fixed

- The customer arrival card's NPC model now walks into the doorway and rests
  inside the portrait instead of finishing beside the empty frame. The compact
  card keeps the model centered on its icon.

### Tests

- UI smoke now checks the model's resting position in the closed-shop, open-shop
  and compact arrival cards.

---

## [1.7.6] — 2026-11-27

A performance and diagnostics release. The Inventory tab no longer recalculates
every stack's market value several times per comparison, which gets expensive as
the stockroom grows.

### Fixed

- The Inventory tab resolves each stack's market value once per sort instead of
  recalculating it inside the comparator. Sales and arrivals that refresh an open
  Inventory tab no longer repeat that work for every comparison.

### Added

- `/gps profile` times the backup encode, the stock sort, a read-only bag scan and
  the current UI refresh, then reports the last journal save duration, macro slots
  and addon memory. It does not change the shop; run it on the tab that feels slow
  and send the `GPS|` lines with `/gps report`.

### Tests

- Added a regression test that builds a 240-stack stockroom and asserts the value
  sort resolves each stack exactly once and keeps the old descending-value,
  name-ordered tie-break for the explicit, default and unknown-sort paths.

---

## [1.7.5] — 2026-11-27

Make saving invisible during play. 1.7.4 stopped the per-chunk read-back, but it
kept both macro generations on the list. At 24 chunks that could fill the client's
macro slots, leave the red **save error** in the header, and still write a batch of
macros while the shop was open.

### Changed

- Autosaves run every **5 minutes**, with the first save at 5 minutes. Logout,
  imports, `/gps verify` and **Checkpoint Now** still save immediately.
- **Settings → Save Now** writes a checkpoint immediately and reports the chunk
  count, alongside the existing Deed-tab checkpoint.
- Autosaves wait until the shop window is closed and no customer is at the counter.
  A save that comes due during a sale runs after the customer leaves.
- A save is one batch (one frame), not one macro per tick. It writes the new
  generation, reads every chunk back, rewrites the commit header, and retires the
  old generation. The macro list holds one journal generation at rest instead of
  two, and the previous one is untouched until the new one has fully verified.
- The incremental tick writer and its cleanup and verification queues are gone.
  A save is a single synchronous batch, so there is no half-finished job to
  resume, clean up or time across ticks.
- The previous generation is retired after every successful save, so 1.7.4's
  24-chunk footprint (and the slot-full red error) is gone.
- If the macro list is completely full, the save rewrites the committed generation
  in place rather than leaving the journal stuck. Legacy 1.6.x chunks are still
  freed first, and a failed save never deletes the last good generation.
- Failed saves back off from one minute up to the five-minute interval, so an
  environment failure does not retry every tick.
- The header keeps **saved** green for five and a half minutes, matching the new
  cadence instead of turning orange after 90 seconds.

### Tests

- 53 tests pass, including a new autosave test that proves the save waits for the
  counter to clear and leaves only one generation on the macro list, and a direct
  check that an interrupted write leaves the previous generation's chunks byte-for-
  byte intact.

---

## [1.7.4] — 2026-11-27

Fix the stutter 1.7.3 still caused after a sale. 1.7.3 spread the journal writes
across clock ticks, but it still read every chunk back and deleted the previous
generation after each save. On Forever the macro calls are the expensive part, so
the client spent much of every 30 seconds waiting on the journal.

### Fixed

- The previous save generation is kept as the crash fallback instead of being
  deleted after every autosave. That removes a dozen `DeleteMacro` calls from each
  save and leaves two restorable saves on the macro list.
- Automatic saves no longer read every chunk back. A save writes its chunks and the
  commit header once; read-back verification remains on logout, import and
  `/gps verify`, where the result is shown to the player.
- Autosaves run once a minute instead of every 30 seconds, and the first save waits
  20 seconds instead of 10, so the opening customer is not competing with a save.
- Legacy `GPSJ` chunks are scanned once per session (or after loading a legacy
  save), not on every save.
- On a 12-chunk test shop the journal now makes about 12 macro calls a minute,
  down from about 80 every 30 seconds.

### Tests

- 53 tests pass, including the full 36-macro recovery and failed-write tests.

---

## [1.7.3] — 2026-11-27

Fix the autosave freeze and the permanent `save error` some 1.7.0 installs hit after
upgrading from an older journal. This release also ships the 1.7.1 payout fixes and
the 1.7.2 rolling backups, which were never published.

### Fixed

- Journal saves no longer write a dozen macros and then delete another dozen in one
  frame. The writer commits one verified macro per clock tick, and retires the old
  generation one macro per tick after the new header lands, so an autosave can no
  longer freeze the client for a second or more.
- A full macro list no longer deadlocks the journal. A pre-1.6.4 save leaves up to 24
  `GPSJ` chunks behind; writing a new 12-chunk generation next to them could exceed the
  client's macro limit forever, because the old chunks were only deleted after a
  successful save that could never fit. Those chunks are now removed as needed to make
  room, one per tick, and a failed create still leaves the last good save intact.
- A failed save retries once a minute instead of every eight seconds, so an environment
  failure cannot turn into a stutter loop.
- The legacy-journal loader reports its real error again. A three-value unpack of a
  two-value return was clearing the message, which hid the reason from the header and
  `/gps journal`.
- Pausing the shop no longer stops the autosave or an in-flight journal write.
- Logout and a restore/import save the state in hand instead of flushing a snapshot
  that started before the last sale.

### Tests

- 53 tests pass. Three new tests assert that a save performs at most one macro write
  per tick, that a full 36-macro list frees old `GPSJ` chunks and commits again, and
  that a failed save waits instead of retrying every tick.

---

## [1.7.2] — 2026-11-27

Rolling backups for the shop save. This release also ships the 1.7.1 payout and
preset fixes, which were committed but never tagged.

### Added

- Three timestamped shop snapshots are kept in a separate
  `GoblinPawnStarsBackups` SavedVariables table, so the backup list can never nest
  inside the next backup.
- Settings → **Rolling backups** opens a window listing the three newest snapshots
  with their timestamp, reason, credits, stock stacks and sales. **Backup now**
  captures a manual snapshot.
- The clock captures the first automatic snapshot after 30 seconds and another every
  10 minutes, but only when the shop has a sale, stock or campaign progress.
- Restore requires a second click on **Confirm**; the first click names the snapshot
  and times out after six seconds. A capture between the clicks cannot shift the
  pending restore onto a different snapshot.
- Every confirmed restore first captures a **Before restore** snapshot of the state
  being replaced. If that safety capture cannot be encoded, the restore is aborted.
  Restoring replaces the active database with the snapshot; it never merges or
  grants credits or stock.

### Tests

- 50 tests pass. Three new tests assert that capture changes neither credits nor
  stock, that four captures leave exactly the newest three, that a restore requires
  confirmation and reproduces the snapshot exactly, that the pre-restore snapshot
  holds the replaced state, and that a corrupt snapshot changes nothing. The UI
  smoke builds the backup window and captures from it.

---

## [1.7.1] — 2026-11-26

### Fixed

- The haggling window shows the exact counteroffer odds again, and that percentage is
  the number the roll uses. The bar is refreshed from the same `Negotiation.Odds`
  function as `Counter`, so a shown chance and a rolled chance cannot disagree.
- The scripted first buyer opens at 45% of their ceiling and is eager: the suggested
  fair counter shows and rolls at about 88%, and the greedy one at about 64%. Other
  archetypes keep their own opening ranges, and the readout shows the real chance so a
  high opening is visible instead of hidden.
- The Low/Fair/Greedy presets are anchored to the customer's visible offer: they
  never suggest a counter below it and keep their increasing order when a
  high-opening customer asks for more than the market-based prices.
- The Make Counteroffer button read only the first return value of
  `Negotiation.Counter` and handed `true` to the result window, so every landed counter
  errored before the payout. It now takes the `(ok, payload)` pair, so a counter win
  completes, pays and displays like an accepted offer.
- A completed sale always displays the amount it paid. `Negotiation.completeSale`
  now returns the exact wallet delta, the negotiation window displays that number,
  and the old "previous sale" fallback is gone. The banner stays up for 2.4 seconds.
- The salesperson's automatic sale refreshes the shop window immediately, so the
  header can no longer keep showing the pre-sale wallet (0 on a new shop) after the
  credits have already been added.
- A saved customer whose opening offer or hidden ceiling is missing is dropped when
  the save loads, instead of rendering `0 gc` and making every counter impossible.

### Tests

- 47 tests pass. They assert the displayed odds equal the rolled value, the scripted
  first buyer is eager and opens below half their ceiling, every sale's reported price
  equals the credits actually added, saved customers without an offer are dropped, and
  every preset stays at or above a high-opening customer's offer. The UI smoke checks
  the accept and counter banners and the auto-sale header against the wallet delta.

---

## [1.7.0] — 2026-11-26

### Added

- `/gps verify` saves, reads the committed journal back off the macro list and compares
  credits, tier, sales and served customers with the run in memory, so a save problem can
  be proven without logging out. It names the generation it read and how much stock that
  save holds. A journal over budget drops low-value stacks on purpose, so stock is reported
  but never treated as a mismatch.
- The header now ends with the save state (`saved 12s ago`, `save pending`, `save error`,
  `save off`), so a broken save path is visible before the next logout instead of after it.
- `/gps uicheck` reports any shop, negotiation, encounter, wholesaler or welcome window
  that sits outside the screen at the current UI scale.
- The first three customers are scripted (gullible, trader, impatient) and the first buyer's
  ceiling rises to 1.45× market value and budget, so a new player's opening counter leaves a
  real margin instead of a coin flip. The money still comes from their own completed sale.
- `/gps motion` turns window fades, pulses, flashes and walk-ins off. Every animation helper
  falls back to its instant path, the same path a client without animation support uses.
- Logging in prints a one-line summary: credits, customers waiting, stock, and how long ago
  the last save landed. Nothing is earned while the shop is closed.

### Fixed

- A full stockroom no longer freezes the game while the journal saves. Trimming
  re-encoded the whole shop every four stacks it dropped, so a big shop paid for dozens
  of full encodes on every save; it now measures the fixed cost once and drops whole
  batches instead (about five times cheaper here, and no longer quadratic).
- A no-change autosave left the journal marked as saving, so nothing else was written
  for the rest of the session. The unchanged path now clears the flag, and a test covers
  the save that follows it.
- Fades and pulses no longer leak animation groups. Every call used to create a new
  group and animations that the client keeps for the frame's lifetime; the credits number
  pulses on every sale, so a long session piled up thousands of them until the client
  crawled. Each region now keeps one group per effect and replays it, and the UI smoke
  test asserts forty fades plus forty pulses build exactly two groups.
- `/gps journal` reports how long the last save took, and an unchanged save is skipped
  before the expensive trimming step.

### Changed

- A tag-driven `Release` workflow builds the ZIP, writes the checksum, takes the notes from
  this file and publishes the GitHub release with the asset attached. CurseForge upload is
  optional and only runs when the repository secrets exist.

### Tests

- Six new diagnostics: the scripted opening customers, `/gps verify` reading a save back,
  a second login restoring the first session's shop through the real login event, the
  codec surviving hostile text plus truncation at every tested byte, a 300-stack stockroom
  trimming down without losing the best stock, and a save that still writes after an
  unchanged autosave. 43 tests pass.

## [1.6.5] — 2026-11-26

### Fixed

- Progress and settings survive a logout again, so the welcome screen stops showing up
  on every login. The client can hand SavedVariables to the addon after the files have
  already built a fresh database; the session kept running on those defaults and the
  next save wrote them over the real character data. `DB.Sync` now adopts the table the
  client supplies, and `DB.Get`/`DB.Save` check for it, so a late handover is used
  instead of being replaced by defaults.
- A save can no longer overwrite a journal the session has not read. Writing now
  requires a settled journal: if the macro list is still arriving, the journal retries
  and refuses to write rather than replacing a good save with fresh defaults.
- An empty first read is provisional. "No chunks" is retried a few times before it is
  treated as a fresh install, so a macro list that lands a moment after login no
  longer looks like a blank account — which is what made the first autosave destroy
  the previous run.
- Journal saves start about ten seconds into a session and retry quickly after a
  failure, so a short logout still lands a save. Unchanged state is detected and not
  rewritten, which keeps the visible macro list quiet.
- Macro writes are judged by reading them back, not by return values: a client that
  answers `CreateMacro`/`EditMacro` with nothing, that returns `(name, body)` from
  `GetMacroInfo`, or that has no `GetNumMacros` no longer fails or switches the journal
  off.
- The welcome screen waits longer for the journal before deciding the player is new.

### Tests

- Three new diagnostics: late SavedVariables are adopted instead of overwritten, a save
  refuses to replace a journal it could not read, and a landed macro write counts even
  when the client returns no index. 37 tests pass.

## [1.6.4] — 2026-11-26

### Fixed

- A save that is interrupted or rejected can no longer destroy the last good run. The
  macro journal now writes to two alternating generations: every chunk is read back and
  compared after it is written, the new generation's header is only marked committed
  after the whole payload verified, and the previous generation is deleted only then.
  If anything fails — a full macro list, a truncated body, a write that reports success
  but stores something else, or a crash before the commit write — the previous save
  stays current and loads at the next login.
- Stock trimming now measures the packed snapshot it actually writes, instead of the
  unpacked one, so a normal shop no longer loses stock to the journal budget.

### Changed

- Each generation holds up to 12 chunks (`GPSA01`–`GPSA12`, `GPSB01`–`GPSB12`), the
  same 24-macro footprint as before. Saves written by 1.6.3 and earlier (`GPSJ01`–
  `GPSJ24`) are still read once and are retired by the next save.
- `/gps journal`, the Deed footer and `/gps report` name the generation a run was
  restored from or saved to.

No save-schema or economy changes.

## [1.6.3] — 2026-11-26

### Added

- `/gps report` prints a compact, pasteable bundle for bug reports: a client
  capability probe (macro API and where each function lives, `SOUNDKIT` keys,
  `C_Container`/`C_Item`, texture paths), journal status, the last recorded Lua errors
  and an economy snapshot (tier, reputation, sales, revenue, stock, staff, campaign,
  museum, Marta, rates, settings).
- The addon remembers the last eight Lua errors from the UI tick, tab refresh, bag
  scans, event handlers and the global error handler. The global handler is chained, so
  the normal error dialog still appears. Errors stay in memory for the session and are
  never written to the save or sent anywhere.

### Changed

- The tier-3 shop costs 5,000 gc instead of 6,500 gc. It previously cost more than the
  second deed note, which pushed it after the note in every measured campaign run.
  With `tools/sim_campaign.js` (three six-hour seeds) the final note lands at 216
  minutes instead of 266 and tier 3 at 116 instead of 171.

No save-schema changes; existing journals still load.

## [1.6.2] — 2026-11-26

### Fixed

- Progress now survives a logout. The macro journal had stopped saving anything once a
  run grew past a fresh save: a new save already used 13 of its 18 chunks and a normal
  shop needed 27, so every save was rejected as too large. Snapshots now drop every
  value that still matches its default and pack stock as compact tuples, and the
  journal has 24 chunks, so a normal twenty-item shop saves without trimming.
- If a save still does not fit, the lowest-value stock is dropped instead of the whole
  save being refused. Credits, tier, staff, upgrades, campaign, museum and achievements
  are always written first.
- The welcome screen no longer appears on every login. Its "already seen" flag is
  flushed as soon as the screen opens instead of waiting for the autosave, and the
  screen waits for the journal to load before deciding whether to show.

### Added

- One chat warning per failing save reason per session, naming what went wrong.
- `/gps journal` prints the save path's state: on or off, chunks, visible macro slots,
  time since the last save, the current run's totals and the last error.

No gameplay, save-schema or economy changes; existing journals still load.

## [1.6.1] — 2026-11-26

### Fixed

- The minimap button draws as a round coin again. The tracking border was anchored
  by its centre even though its art sits in the top-left of the texture, which
  pushed the ring off the coin and let the icon spill out of the frame. The button
  also had no background behind the icon, so the ring looked hollow.
- The waiting-customer alert is a small gold coin pip instead of an 8x8 green
  square that read as a missing texture.

No gameplay, save or economy changes.

## [1.6.0] — 2026-11-25

### Added

- **Questing auto-sell** in Settings serves queued customers with the shop window closed and requires no hired salesperson. It pays one-third of the best possible manual deal in Goblin Credits, rounded down to a minimum of one credit.
- Questing auto-sell defaults to off, waits until combat ends, and leaves active negotiations alone. While enabled, it takes over auto-selling from the salesperson.

### Changed

- Fast, Normal, and Relaxed customer arrival presets each wait twice as long as before. Existing saved countdowns are doubled once on upgrade.

## [1.5.0] — 2026-11-25

### Added

- Native WoW NPC models for customer portraits and walk-ins, with an icon fallback.
- Movable arrival notifications with separate positions for the closed and open shop.
- Adjustable customer arrival pace and the `/gps arrival` and `/gps arrivals` commands.

### Fixed

- Due arrivals wait for stock, a free queue slot, or combat to end. The header shows what is blocking them.
- Settings and other affected buttons update their labels on click.
- Negotiation dialogue uses light text on an opaque background.

## [1.4.0] — 2026-11-25

The "Deed" vertical slice: a reason to play beyond the next tier, plus a save path
that survives the beta client's failure to load SavedVariables.

### Added
- **The Deed** — a three-payment cartel campaign: 1,500 → 6,000 → 25,000 Goblin
  Credits. The first payment unlocks the museum and Marta; the third closes the ledger
  and offers an ending choice. Payments spend existing credits only.
- **The Curious Collection** — one five-slot museum set (weapon, gem, cloth, ore,
  curiosity). Donating consumes one quality-2+ virtual stock unit per slot. Completing
  the set grants a permanent +5% customer offer bonus. State carries through prestige.
- **Marta Copperpin** — a named Dwarf regular with three story visits, a normal
  stock-backed sale each time, and a permanent +3% offer bonus after her third visit.
  She arrives naturally after the first payment, or can be invited from the Deed tab.
- **Endless mode and franchise prestige** — after the debt, keep the shop open forever,
  or start a new deed in a fresh stall. Franchise keeps the museum, Marta, achievements
  and a permanent +5% offer bonus per franchise level; it resets credits, stock, tier,
  upgrades and staff, and grants a new starter crate.
- **Deed tab** with the ledger, payment button, museum slots, Marta panel, ending
  choices, franchise confirmation and journal status. Dashboard shortcut and Next Up
  objectives cover the campaign.
- Three new achievements: *Curator of Curiosities*, *A Regular's Regular*, *Free Goblin*.
- **Macro save journal** — because Forever's beta writes SavedVariables but does not
  load them at login, a compact snapshot is checkpointed into chunked account macro
  bodies (`GPSJ01`…`GPSJ18`). Base64 payloads, checksums, incomplete-chunk detection,
  delayed login retries and a `Checkpoint Now` button are included. Full history and
  the live customer queue are intentionally omitted; low-value stock is trimmed first
  if the journal exceeds 18 chunks. The manual export still restores everything.

### Changed
- A macro-journal restore now rebinds the restored database immediately, so a debt
  payment, museum donation, or reset made before the first autosave is still journaled.
- Franchise sets up the whole new run before replacing the journal, so an interrupted
  reset cannot leave an empty journal in place of the completed shop.
- Version, TOC, package, docs and welcome screen updated to 1.4.0.
- The dashboard Next Up flow now continues from ten sales into the debt, museum and
  Marta objectives.
- Settings explains the automatic journal and keeps the full backup/restore path.
- Released under the MIT License; the installable ZIP now ships `LICENSE`.
- Added an AI disclosure covering the project's human-directed, AI-assisted development.

### Balance / safety
- No offline earnings. The journal restores state at login but never simulates elapsed
  time, arrivals, sales or credits while the client was closed.
- Every campaign credit remains sale-backed: museum donations and Marta visits consume
  stock; franchise starter crates grant stock, not credits; payments only spend credits.

## [1.3.0] — 2026-11-25

The "idle slice" release: visible throughput, a credit-fed wholesaler, and a
salesperson who actually works the queue.

### Added
- **Throughput readout** — the header and dashboard now show Goblin Credits per minute
  and customers served per minute, computed from completed sales over a rolling
  three-minute window (`Modules/Throughput.lua`). A single sale no longer reads as 60
  credits/min.
- **Goblin Wholesaler** — a standalone window (Dashboard → Wholesaler, `/gps wholesale`)
  with three rotating bulk lots. Lots cost credits up front, become one virtual stack
  each, and are priced at 30–34% of live stack-adjusted retail value. Stock refreshes
  every four minutes, or 60 seconds after the last lot is bought. Every lot has a
  quality, item level, unit count and a visible estimated-retail margin.
- **Queue-based salesperson** — once hired, the salesperson automatically serves the
  waiting queue while you are away from the counter, at 76–94% of live market value
  (12 seconds between sales at level 1, down to 6 seconds at level 5). She never
  interrupts an active negotiation, never sells without consuming one unit of stock,
  and pays reduced reputation (1 instead of 3). Toggle her off under Settings.
- **Starter crate** — a new shop receives two low-value virtual items on first login so
  the first customer and first sale do not require leaving to loot. It grants stock,
  never credits.
- `/gps wholesale` command and a Next Up step that teaches the supply loop.
- Diagnostics for wholesaler purchases (exact cost, one stock record, no double-buy),
  salesperson auto-sales (stock consumed, revenue equals credits, queue cleared,
  no sale without stock), and throughput (zero when empty, correct rates after a sale).

### Changed
- **Early traffic is much faster.** Tier 1 now brings a customer roughly every 20
  seconds instead of 110, and every tier starts with at least two waiting slots. First
  login schedules a customer in about 8 seconds, and later logins halve the normal
  interval instead of waiting a full cycle.
- The old once-per-shop-day random inventory sale was removed. The salesperson now
  works queued customers year-round; shop days only charge rent and wages.
- Tier arrivals: 20 / 17 / 14 / 12 / 10 seconds. Waiting slots: 2 / 2 / 3 / 3 / 4 for
  tiers 1–5 (plus lounge and marketing bonuses).
- Employees tab and tour copy now describe the salesperson's lower-margin automation;
  the auto-sell setting controls the queue, not a hidden shop-day roll.
- Docs, README, PROGRESS, TODO and AGENTS updated for 49 files / 19 tests and the
  no-offline-earnings rule.

### Balance
- Hand-tuned against a scripted 30-minute run: the model reaches tier 2 around minute
  15, hires the salesperson, and finishes with live rates around 200–850 credits/min
  depending on how aggressively it reinvests. A closed-window 10-minute probe clears
  the queue with 33 auto-sales and no negative balance. These are headless simulation
  numbers, not live-player pacing.

### Deliberately not included
- **No offline earnings.** The addon still only simulates while the client is running.
  Credits continue to require a virtual item that a customer actually bought.

## [1.2.1] — 2026-11-25

### Fixed
- **Bag scanning aborted on the first empty slot.** `GetContainerItemID` was routed
  through a vararg helper that returns no values for a lone `nil`, and the result was
  passed to `tonumber()`. Every real bag has empty slots, so the scan threw before it
  could stock anything — looting and the scan button appeared completely broken. The
  bag getters now pcall directly and handle nil safely.
- **The first loot after login could be swallowed.** An empty bag snapshot was not
  stored as the baseline, so the first item looted became the baseline instead of
  stock. An empty snapshot is now a valid baseline.
- **Baselines did not follow count drops.** Selling or destroying real items left the
  old counts behind, so re-looting the same item looked like "no gain". The baseline
  now updates on every readable scan.
- **Uncached items were dropped.** Just-looted IDs are often not in the item cache yet.
  The addon now resolves name, class and icon from the bag hyperlink plus
  `GetItemInfoInstant`, retries on `GET_ITEM_INFO_RECEIVED`, and runs a 30-second
  safety scan.
- `Stock Bags Now` (Dashboard) and `/gps importbags` copy eligible items you already
  carry, skip IDs already in stock, and leave a baseline gap for anything that could
  not fit or was not cached, so it can be picked up later.
- `/gps scan` now reports readable containers, stacks/items, baseline size, and
  eligible vs skipped vs uncached stacks.
- Dashboard Next Up starts with stocking the shelves, so a new shop is never told to
  meet a customer while it has nothing to sell.
- New stock now produces a toast instead of silently updating the inventory.

## [1.2.0] — 2026-11-25

The "make it move" release: a guided tour, a proper splash screen, animations and
an always-visible next step.

### Added
- **Guided tour** with seven spotlight steps: the header, the tabs, stocking, haggling,
  reinvesting and the Next Up card. Launch it from the splash screen, the `?` button in
  the title bar, the dashboard card, or `/gps guide`.
- **Splash screen rewritten** into two modes: a first-launch introduction and a
  "what's new" screen whenever the addon version changes. Both credit the authors and
  can start the tour. A toggle controls future update splashes.
- **Next Up objectives** on the dashboard: tour → first customer → first sale → first
  upgrade → tier 2 → first employee → ten sales. Progress is counted, completion is
  celebrated, and the card is one click from the relevant tab.
- **Animation layer** (`UI/Anim.lua`): fade-in windows, tabs, negotiation and event
  popups; tab-selection pulse; credit-count pop; toasts fade in; a slowly spinning
  coin watermark on the splash. Every effect falls back to an instant, visible result.
- `/gps guide` and `/gps tour` commands.
- Saved settings `tourDone` / `tourVersion` (additive, defaulted on old saves).
- Harness coverage for first-vs-update splash modes, every tour step, and goal
  progression including the dashboard card.

### Changed
- The splash toggle now reads "Show on updates" and governs version-change splashes;
  the first launch always explains the loop.
- The main window has a `?` guide button beside the close button.

## [1.1.1] — 2026-11-25

### Fixed
- **Sidebar and tab buttons stretched across the whole window.** The sidebar was
  anchored to both the left and right edges *and* given `SetWidth(188)`; the client
  resolves the anchors, so it filled the window width. Every tab button was anchored to
  both sidebar edges, inherited that width, and its click area covered the tab content,
  making buttons in Dashboard, Customers and the other tabs unclickable. The sidebar is
  now left-anchored with an explicit 188 px width, and each tab button is 172×36.
- Harness assertion added: the sidebar must never anchor to the right edge and every
  tab button must stay 172×36, so the mock catches a regression even though it cannot
  resolve anchors itself.
- Diagnostics: the accepted-offer test now includes the daily request bonus in its
  expected payout. It was flaky on the ~1-in-N days when today's request matched the
  test item's category; the sale payout itself was always correct.

## [1.1.0] — 2026-11-25

Onboarding, modern client integration and a correctness pass. Created by
**ErrorSeib & Buffy (Codebuff)**.

### Added
- First-run **welcome window**: three-step explanation of the loop, author credits,
  "Open the Shop" / "Maybe Later", and a login-greeting toggle. Shown once per addon
  version; reopen with `/gps welcome` or the Welcome button in Settings.
- **Blizzard Settings category** (Options → AddOns → Goblin Pawn Stars) with open-shop,
  welcome, diagnostics, sound, minimap and full-settings shortcuts. Falls back to the
  in-addon Settings tab if the client lacks the Settings API.
- **Addon Compartment** entry (modern minimap button menu) alongside the existing
  draggable coin, registered through the supported TOC metadata fields so it works
  regardless of client load order.
- `/gps welcome` and `/gps options` commands.
- Credits in TOC metadata (`Author`, `Credit`, `X-Credits`), welcome window, options
  panel, Settings About text and version output.
- Harness coverage for welcome gating, Settings/Compartment registration and one
  simulated hour of gameplay ticks.

### Fixed
- **Item class/subclass parsing**: `C_Item.GetItemInfo` returns numeric class IDs at
  positions 12/13, not 6/7 (those are localized strings). Every item would have been
  categorised as a curiosity. Parsing now follows the documented order, with a
  localized type-name fallback for partial rows.
- Removed a texture that covered item icons with a gold rectangle.
- Header no longer overlaps its traffic timer; it shows tier and session playtime.
- Encounter results persist for the Customers tab instead of being cleared on close.
- Guarded the minimap ticker for clients without `C_Timer.NewTicker`.
- Guarded tab label access that could error while switching tabs.
- Settings/backup defaults for welcome, auto-sell and pause state.

## [1.0.0] — 2026-11-25

First complete release, targeting World of Warcraft: Forever (Interface 16001).

### Added

**Shop simulation**
- Virtual pawnshop stock built from real looted items (names, icons, quality, item
  level, tooltips) without ever modifying the player's bags or gold.
- Bag-diff acquisition detection with a first-run baseline, per-scan throttling, and
  idempotent handling so repeated loot or bag events cannot duplicate stock.
- Item stacking, twelve valuation categories, deterministic per-item base values,
  live market multipliers, and capacity limits enforced per shelf slot.
- Fictional **Goblin Credits** currency, lifetime statistics, and a 250-entry ledger.

**Customers and negotiation**
- Nine customer personalities with distinct budgets, offer ranges, hidden ceilings,
  patience, stubbornness, preferred categories and dialogue.
- Procedural names, races, classes, occupations, epithets, greetings and special
  remarks; class-icon portraits.
- Negotiation window with customer dialogue, item card, market estimate, offer,
  segmented patience, accept/reject/counter controls, preset counters and appraisal.
- Probabilistic counteroffer resolution, escalation, walk-outs, absurd-demand
  refusals and hidden-ceiling reveals through appraisals.
- Daily customer requests with a category bonus.

**Market**
- Twelve category demand indices that drift on playtime.
- Eleven market events: War Effort, Alchemist Convention, Mining Shortage, Goblin
  Market Crash, Collector's Festival, Tailoring Boom, Leather Shortage, Enchanting
  Fad, Guild Recipe Rush, Auction Frenzy, Harvest Festival.
- Event countdowns and demand bars in the Market tab.

**Progression**
- Five shop tiers from Roadside Trading Stall to Azeroth Trading Empire.
- Eleven levelled upgrades across storage, appraisal, haggling, traffic, security,
  expenses, waiting room, rare customers and auctions.
- Reputation (0–1000) affecting customer willingness and counteroffer odds.
- Shop days every 15 minutes: rent, wages, auto-sales and request refresh.

**Employees**
- Appraiser, Salesperson, Accountant, Security Guard, Marketing Specialist and
  Treasure Specialist, each with five levels, escalating hire costs, wages and
  concrete effects.
- Auto-sell toggle for the salesperson.

**Random encounters**
- Counterfeit goods, thieves, celebrity adventurers, returning complainers, mystery
  deliveries, rare collectors, rival shops, special auctions, ridiculous lowballs,
  goblin tax audits and traveling merchants, all fully simulated.
- Encounter popup with per-option consequences and a result card in the Customers tab.

**Achievements**
- 23 custom achievements including Best I Can Do, Highway Robbery, Absolutely Not,
  Goblin Millionaire, Professional Lowballer, I Know What I've Got and Let Me Call an
  Expert, with progress bars and fictional shop titles.

**Interface**
- Dark wood, tarnished gold and goblin-green theme built from Blizzard textures.
- Nine tabs, movable main and negotiation windows, toasts, tooltips, item quality
  colouring, live header and a draggable minimap coin with alert and tooltip.
- Optional SOUNDKIT-based cues, window scaling, pause switch and minimap toggle.
- `/gps` and `/goblinpawnstars` with help, version, debug, backup, reset and test.

**Technical**
- SavedVariables schema with normalization/defaults, autosave and logout save.
- Compact copy-paste backup/restore codec (no `loadstring`) as a workaround for the
  beta client not loading SavedVariables.
- Guarded compatibility layer (`pcall`/feature checks) for items, bags, timers,
  sounds, frames, backdrops, fonts and event registration.
- Built-in diagnostics (`/gps test`), a Lua 5.1 syntax checker, a fengari-based mock
  harness with 15 simulation tests, a UI smoke pass, and a ZIP packager.

### Known issues

- The Forever beta writes SavedVariables but does not load them; use export/import
  until the client is fixed.
- Not yet play-tested in the live client (see `PROGRESS.md` for the checklist).
- Multiplayer/market sharing is not implemented.
