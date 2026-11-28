# TODO

## Refinement roadmap (branch `refinement-polish`, branched from `main` @ `41a4da7`)

`main` stays at 1.8.0 until the owner says otherwise. Work lands here first.

### Done on this branch

- [x] Reputation milestones: Known / Respected / Trusted / Legendary now unlock a
      waiting slot, a rare-customer bonus, an extra haggling round and an offer bonus,
      all from one data table, all visible on the Dashboard tile tooltip.
- [x] Shop events remember the last two draws, so no event repeats back to back or
      alternates A-B-A, and a relog does not repeat the event you just dismissed.
- [x] Two new headless tests (67 total) covering both changes.
- [x] Contextual customer dialogue: greeting and every haggling reaction drawn from
      personality pools that know the item's category/quality/price band, the `prefer`
      match, patience and reputation; 9 archetypes x 6 pools, one Data file.
- [x] Anti-repeat dialogue memory: the last six chosen lines are packed into numbers in
      the save (bounded, no strings) and skipped while another line exists.
- [x] Negotiation window text fix: no per-second re-wrap, three-line cap, no empty
      quotes, greeting follows the customer and item.
- [x] Four new headless tests (71 total): archetype sweep, contextual selection and
      fallbacks, anti-repeat plus save round trip, old and broken saves.
- [x] Return-visit memory: a sale near the customer's own ceiling remembers them, they
      can take an ordinary arrival with their own name and archetype, earn one extra
      haggling round from visit two and a 5% loyalty premium from visit four. Three
      faces, bounded, sale-backed, with a `greetReturn` pool per personality so a
      familiar customer greets you like one.
- [x] Four more headless tests (75 total) and a 30-minute probe showing three regulars
      formed with 2/2/1 visits.
- [x] Special orders: a regular who has bought something can come back wanting one
      specific shelf, with a named budget and a two-shop-day deadline. Delivering pays
      1.35x market value inside that budget, +8 reputation and extra goodwill, and two
      deliveries make a patron (permanent 2% offer lift). Lapsing costs 4 reputation and a
      remembered visit, and the regular survives. Capped at three, normalized additively,
      stripped from the journal, shown in the wanted panel, the queue row and the counter,
      with order-greeting and order-acceptance pools for all nine archetypes.
- [x] Five more headless tests (80 total) and a six-seed on/off/ignore probe: orders
      average 3.2 placed and 2.8 delivered per 30 minutes, order revenue is ~11% of
      gross, and ignoring them shows up as lapses and lost reputation.

### Iteration 5 — finishing the order loop

- [x] **Order awareness outside the Customers tab.** One chip in the shop title bar names
      the shelf and the days left, turns red on the last day, has a full tooltip and opens
      the Customers tab. Same styling as the rest of the status strip, no new window.
- [x] **`WANTED TODAY` survives non-100% scale and large fonts.** Bar anchored to the card
      bottom, bounded text box, pure `Widgets.FitLines` decision that drops the daily
      buyer line before the order line, and names elided past 16 characters.
- [x] **Patron rewards with teeth.** Bigger budget (3.2x tier), +1 shop day, 1.5x market
      value on their order, 12 reputation, two goodwill visits, 4% standing offer lift,
      1.5x arrival weight, 75% ask rate, an order handed over at promotion, patron-only
      greetings and a visible `Patron` badge.
- [x] **Fixed a real save bug found while doing it:** the regulars rebuild in
      `Persist.normalize` dropped `patron`, `fulfilled` and `souredDay`, so patron status
      did not survive a reload.
- [x] Three new headless tests (83 total), new UI smoke assertions, a six-seed
      on/off/ignored/patron-disabled probe and both sims re-run (numbers in PROGRESS).

### Iteration 6 — streak, ceremony and the ten-feature plan

- [x] **Counter streak ("clean deal").** Landed counters in a row fill a meter in the
      negotiation title bar; five in a row arms a clean deal that pays +10% on the next
      landed counter plus 2 reputation, then resets. Session-only (never saved), resets on
      a botched counter, and an already-earned perk survives the reset.
- [x] **Deed and tier ceremony.** Crossing a reputation tier or completing a deed fires a
      1.25 s celebration (three-icon burst + pulse + native achievement fanfare) and lights
      one permanent **shop standing** pip in the sidebar. `db.shop.celebratedTier` is saved
      so a relog restores the pips without replaying the fanfare.
- [x] Six new headless tests (89 total), new UI-smoke assertions and a headless benchmark
      comparing this build to the previous head (no measurable refresh cost).

### The ten-feature plan (persistent roadmap)

Ordered by value for the player per unit of risk. Inspiration column is what the top
CurseForge minigames sell (Peggle/Bejeweled downtime loops, Peg'Gul/balatro run structure,
Cross Gambling dice, All The Things completion sets, shared leaderboards).

1. [x] **Counter streak / clean deal** — a 30-second hot-hand loop with visible escalation
       and one bounded reward. *Shipped in iteration 6.*
2. [x] **Deed and tier ceremony** — milestones with a flourish and a permanent visual
       change. *Shipped in iteration 6.*
3. [ ] **Desperate customer's double-or-nothing** — one archetype offers to gamble the
       difference at stated odds (win: their ceiling; lose: a nominal discount and a small
       reputation sting). Gambling is the biggest minigame category by downloads; bounded
       to once per customer with slightly negative EV.
4. [ ] **Daily specials board** — one advertised deal per shop day ("today: rings +15%")
       on the existing door/arrival card, so there is a reason to return and a plan for
       stock. Rides the existing day clock and market events.
5. [ ] **Weekly Curator's Request** — the museum asks for a themed three-item set;
       completing it pays a display and a small permanent perk. Bounded completion (3 of 3)
       is the stickiest collection pattern.
6. [ ] **Named rival pawnbroker** — a recurring competitor who outbids at the wholesaler,
       snipes the occasional patron order and keeps a running tally. The leaderboard hook
       that keeps score-based minigames installed.
7. [ ] **Market Week run mode** — an optional seven-day run with three drafted shop quirks
       and a scored tally saved to a local best list. Run structure + modifiers over the
       existing economy, no new simulation.
8. [ ] **Apprentice with a personality** — a hireable goblin who levels from watching
       deals, comments on them and eventually runs one category of auto-sales.
9. [ ] **Appraisal skill round** — replace the passive appraise click with a short
       "what's it worth?" gauge; accuracy reveals a hidden fact or nudges the opening offer.
10. [ ] **"Beat my shop" async duel** — export a shop code, a guildmate imports it as a
        ten-minute scored scenario, both compare takings. Uses the existing backup codec
        and a scratch database only.

Not planned, on purpose: a literal match-3/Peggle clone (off-theme and the market is
saturated), real player-to-player networking (an addon cannot), and any reward that pays
credits outside a completed sale.

### Next up (planned order)

Honest read after this pass: the order loop is complete and visible from every tab, and
patron status is a real upgrade. What is left is mostly *presentation depth*: the shop's
typography is still even everywhere, long-term relationship building has no counter, and
the Customers tab is the only place the cast exists as people.

- [ ] **UI pass on typography and spacing.** Audit every tab against a single scale for
      caption/value/label text, tighten the header, and give the negotiation window a
      clearer hierarchy between offer, odds and actions. Weakest area overall now.
- [ ] **Order and regulars history.** A delivered order leaves a history line and nothing
      else. A small "regulars served / orders filled" counter in the Deed tab would make
      long-term relationship building legible beyond the three remembered faces.
- [ ] **A patron's standing request.** Patrons still order one shelf at a time. A patron
      who keeps a permanent want ("always buying gems, top price") would give the shop a
      passive, readable demand line and something to shop around.
- [ ] **Encounter variety around the cast.** Events are still shop-wide. A regular-specific
      event (a rival tries to poach a patron, a patron asks for a favour) would tie the
      encounter system to the relationship system.
- [ ] **Valuation depth.** `Market.Value` still produces one number per item; a piece's
      story (provenance, a collector's specific want) would give the haggling something
      to be *about* beyond a price band.
- [ ] Read-path salvage for the macro journal: a partial payload should keep the fields
      that validate instead of refusing the load outright.
- [ ] First-run pacing review: the first five minutes currently teach haggling well but
      say nothing about the market index, the daily request or the deed.

## Must do in-game for the bounded login load and staged saves (1.7.9)

The 1.7.9 suite is 59 tests (the 55 from 1.7.8 plus the load gate, the staged-save
ordering and the bounded login load). None of it has run in World of Warcraft; this
block is the release gate for the load and save changes.

- [ ] Fresh login with a saved macro journal: the header reads **loading saved shop**,
      then the run loads on its own within about half a minute and the header moves to
      `save pending`. Confirm credits, stock, tier, sales and the campaign match the
      saved state, and that the macro list holds one generation.
- [ ] `/gps journal` after that login reports `loaded this session (login)`.
- [ ] Log in with no saved journal: the bounded reads must pass quietly, the header
      ends on `save pending`, and chat does not claim a save was recovered.
- [ ] Turn **Settings → Auto-load** off and relog with a saved journal: nothing is read,
      the header stays **load progress**, chat prints `Saved shop not loaded.`, and
      **Save Now** refuses to write. Confirm the macro list still holds the save.
- [ ] With auto-load still off, press **Load saved** once; the label becomes
      **Confirm load**. Click again and confirm the run loads, the badge clears, and
      saving resumes. A press on a genuinely fresh install answers
      `No saved run was found`.
- [ ] `/reload` and relog twice with auto-load on: the saved run comes back each time
      and no `save error` should appear.
- [ ] Press **Reset all progress** twice: saving must turn on and the header must go
      `save pending` → `saved … ago` with one fresh generation.
- [ ] Break the journal on purpose (rename one `GPSA`/`GPSB` macro or edit a chunk in
      the macro UI), then relog: the load must stop within four reads, report the
      error, and let the next save replace the bad generation.
- [ ] Fill the stockroom to the 12-chunk limit and let an autosave run with the shop
      window closed: no visible freeze while it writes, the commit header lands last,
      and the previous generation disappears afterwards. `/gps journal` reports one
      generation.
- [ ] Watch `/gps profile` across a save: the journal time must stay small per slice
      instead of one multi-hundred-millisecond batch.
- [ ] Start a save with the shop window open and a customer at the counter: nothing
      writes, and the save lands once both are clear.
- [ ] Mid-save, click **Save Now**: it must complete rather than report a half-written
      save. Then close the client and confirm the run restores.
- [ ] After a load, `/gps verify` reports matching credits, tier, sales and served.

## Must do in-game before calling 1.7.5 final

The 1.7.5 mock suite has 53 tests (50 through 1.7.2, plus three save-path
regressions). None of it has run in World of Warcraft; this block is the release
gate. The older 1.4.0 list below is still open.

- [ ] Upgrade from a 1.7.4 save with both `GPSA` and `GPSB` generations. The first
      autosave may take five minutes; when it lands, the header must read **saved 0s
      ago**, one generation must remain, and the old chunks must disappear.
- [ ] Fill the macro list close to the client cap and confirm the save still recovers
      (or reports a specific `save error` without deleting the last good save).
- [ ] Keep the shop open for ten minutes: no autosave should write while the window or
      a customer is up. Close the window, wait, and confirm the header saves without a
      visible freeze.
- [ ] Click **Settings → Save Now**: it should report the chunk count, clear the
      header error, and leave one journal generation.
- [ ] Fresh save, first NPC: the scripted gullible buyer opens around 65% of market,
      below Low/Fair/Greedy; the presets read about 94/88/64%.
- [ ] Land a Low/Fair counter: the window completes, the payout banner and feedback
      equal the header credit delta, and two sales in a row show their own amounts.
- [ ] Accept the opening: it pays the opening, never 0; a failed counter changes no
      credits.
- [ ] Salesperson or questing auto-sale: the header updates immediately and matches the
      toast.
- [ ] Relog with a customer at the counter: a valid customer has a positive offer and
      working odds; an invalid saved customer is dropped, never shown as `0 gc`.
- [ ] High-opening customer: Low/Fair/Greedy never fall below the current offer and stay
      increasing.
- [ ] Run the full in-game checklist in `PROGRESS.md`.

## Must do in-game for rolling backups (shipped in 1.7.2)

- [ ] With stock and a sale recorded, open Settings → **Rolling backups** and click
      **Backup now**. Confirm the row shows the timestamp, credits, stock stacks and
      sales, and the header credits and stock do not change.
- [ ] Wait 30 seconds after login, then 10 minutes; confirm automatic snapshots appear
      without spending or granting credits or stock. A paused shop should not capture.
- [ ] Click **Restore** once and confirm the warning names the snapshot; click
      **Confirm** and verify credits, stock and tier match that snapshot exactly. The
      newest row must be the **Before restore** snapshot of the state just replaced.
- [ ] Restore the pre-restore snapshot back and confirm the two states round-trip
      exactly, with no extra stock, credits or sale payouts.
- [ ] Corrupt or remove a snapshot in `GoblinPawnStarsBackups`; confirm a failed
      restore leaves the current shop untouched and keeps the safety snapshot.
- [ ] `/reload` and relog: confirm `GoblinPawnStarsBackups` persists, keeps only the
      three newest, and the 1.7.1 full export path still works.
- [x] Released as 1.7.2; the 1.7.1 ZIP stays superseded.

## Older in-game checklist (1.4.0) — still open
- [ ] Cold-restart after a campaign payment and confirm the macro journal restores
      credits, campaign, museum, Marta and prestige. Confirm `/reload` does not replay
      payments or duplicate stock.
- [ ] Confirm macro creation/editing is available at login, count the real account macro
      slots, and test with a nearly-full macro list. Check the Deed error message if the
      journal cannot be written.
- [ ] Check the Deed tab at 0.8/1.0/1.2 scale: payment button, five museum rows, Marta
      panel, ending buttons, franchise confirmation and footer journal text.
- [ ] Play through all three payments and both endings; decide whether 1,500 / 6,000 /
      25,000 gc fits a real session and whether Marta appears too often.
- [ ] Confirm museum donations consume the displayed stock unit, never the player's real
      item, and that completion adds exactly +5% to offers.
- [ ] Confirm franchise reset keeps the museum, Marta, achievements and prestige bonus,
      and starts a fresh campaign with a starter crate.
- [ ] Confirm the splash shows the intro on a fresh save and "what's new" after a version change.
- [ ] Walk the guided tour at 0.8/1.0/1.2 window scale; check the spotlight tracks the header,
      sidebar, tab buttons and Next Up card, and that Esc exits and marks it seen.
- [ ] Confirm animations play on 16001 (fades, tab pulse, credit pop, splash coin) and that
      the UI is still usable if they do not.
- [ ] Confirm Options → AddOns → Goblin Pawn Stars appears, and that the Addon
      Compartment entry opens the shop (if that frame exists on 16001).
- [ ] Confirm the layout at 960×640, at 0.8/1.0/1.2 scale and with ElvUI-style skins.
- [ ] Verify every referenced texture exists (dialog frames, tooltip borders, icons,
      `ClassIcon_*`, `INV_*`).
- [ ] Verify `C_Container` shapes and that reagent-bag scanning does not double count.
- [ ] Loot 2–3 items without touching the shop; confirm they stock automatically and a toast appears.
- [ ] Sell/destroy a real item, then re-loot it; confirm it stocks again (baseline follows drops).
- [ ] Run `/gps scan` and confirm readable containers, eligible/skipped/uncached counts look right.
- [ ] Click Stock Bags Now with existing loot; confirm it imports once and a second click adds nothing.
- [ ] Verify `GameTooltip:SetItemByID` shows real tooltips for stocked items.
- [ ] Open the Wholesaler, buy all three lots, confirm exact costs, one stack per lot,
      sold-out buttons, and the 60-second fast restock after the last lot.
- [ ] Reach tier 2, hire the salesperson, leave the counter idle, and confirm she clears
      the queue at a visibly lower price than manual haggling. Toggle auto-sell off.
- [ ] Watch credits/min and customers/min for five minutes; confirm they rise with
      sales, decay when trading stops, and never show a rate without a sale.
- [ ] Confirm the starter crate appears once on a fresh save, grants no credits, and
      does not overwrite existing stock.
- [ ] Check the Wholesaler window and the header rate line at 0.8/1.0/1.2 scale.
- [ ] Verify `SOUNDKIT` keys; remove any that do not exist on 16001.
- [ ] Verify `/gps` and `/goblinpawnstars` registration and Esc behaviour.
- [ ] Re-check SavedVariables loading after Blizzard fixes the beta bug; the macro journal
      is a fallback, not a replacement for the full backup.
- [ ] Watch for taint/blocked-action messages during a full raid and dungeon run.

## Balance and feel

- [ ] Campaign economy: check whether the first note is affordable before the player
      loses interest, whether the second note competes sensibly with tier upgrades, and
      whether 25,000 gc is a long-term goal rather than a grind wall.
- [ ] Franchise: check whether +5% offers per level stays meaningful without making
      later runs trivial, and whether keeping Marta's stories is the right reward.
- [ ] After the in-game 30-minute pass, decide whether 20-second tier-1 traffic is too
      busy, whether the salesperson is too strong at 12 seconds, and whether wholesale
      margins (30–34% of retail) leave enough room for market crashes.
- [ ] Play 2–3 hours and record credits/hour per tier; tune `Data.Tiers` costs and
      budgets if progression is too fast or too slow.
- [ ] Check whether the 2.8× price cap makes *Highway Robbery* too rare before tier 3.
- [ ] Consider a visible "customer is interested" anticipation beat before the popup.
- [ ] Tune patience: one round for the Impatient Warrior may feel too punishing at
      tier 1 without the haggling manual.
- [ ] Confirm expenses matter but do not bankrupt an idle player unfairly.

## Polish

- [ ] Add a small parchment "shop sign" flourish to the dashboard (texture-based, no
      binary assets).
- [ ] Inventory: show stack value vs. unit value more clearly; add "best category
      today" hint.
- [ ] Ledger: day separators and a per-day profit summary.
- [ ] Negotiation: show the customer's last offer delta after a failed counter.
- [ ] Settings: remember the last active tab between sessions.
- [ ] Achievements: add a "nearly there" sort option.
- [ ] Add optional tooltips explaining reputation and haggling odds (spoiler-lite).

## Onboarding / modern integration

- [x] Add a first-run splash and a "what's new" screen for version changes.
- [x] Add a guided tour (`/gps guide`) and a persistent next-step card.
- [ ] Localise the splash and tour text (currently English only).
- [ ] Consider an option to disable animations for players who prefer reduced motion.
- [ ] Drive the "what's new" list from a single data table shared with `CHANGELOG.md`.

## Features deliberately deferred

- [ ] **Offline earnings** — deliberately deferred. Do not add until the beta's
      SavedVariables loading is fixed and login-time catch-up can be made exploit-safe;
      every simulated offline sale must consume stored stock and respect capacity.
- [ ] **Phase 5 — multiplayer/market sharing** via supported addon comms
      (`C_ChatInfo.SendAddonMessage`). Scope: share anonymous market indices and
      "shop of the day" between guild members; never share inventory or credits.
      Requires: channel opt-in, prefix whitelisting, message throttling, and a
      graceful fallback when comms are unavailable. Not started intentionally.
- [ ] Customer visit history with repeat buyers and relationship memory.
- [ ] Layaway/credit sales with default risk (needs careful anti-exploit design).
- [ ] Seasonal events tied to in-game holidays.
- [ ] Data-driven item flavour text for appraisal results.
- [ ] Per-character vs. account-wide shop toggle.

## Technical debt / known limits

- [ ] Bag scanning calls `C_Container.GetContainerItemInfo` per slot; on very large
      reagent bags consider caching the snapshot for the current BAG_UPDATE cycle.
- [ ] Import skips an entire item ID if any copy is already stocked; a partial stack
      in the bags is therefore not topped up by the button (automatic scans do top up).

- [ ] `Data.IsEligible` cannot detect unique/quest-adjacent items beyond class IDs;
      add more exclusions once real item data is observed.
- [ ] Stacks above 20 units create a second record instead of splitting; consider a
      proper stack splitter.
- [ ] Encounter results persist until the next encounter; decide whether to expire
      them at the next shop day.
- [ ] `History` is capped at 250 entries; consider archiving daily totals.
- [ ] Add a SavedVariables migration test once schema v2 exists.
- [ ] Mock coverage does not include real frame anchoring; consider a screenshot pass
      when an in-game screenshot pipeline is available.
