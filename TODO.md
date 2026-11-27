# TODO

## Must do in-game before calling 1.7.4 final

The 1.7.4 mock suite has 53 tests (50 through 1.7.2, plus three save-path
regressions). None of it has run in World of Warcraft; this block is the release
gate. The older 1.4.0 list below is still open.

- [ ] Upgrade from a 1.7.0 save with old `GPSJ01`–`GPSJ24` macros. The header may
      read **save pending** while the journal writes one macro per second; it must
      settle on **saved 0s ago** and the old chunks must disappear. It must not freeze
      for a second on each autosave.
- [ ] Fill the macro list close to the client cap and confirm the save still recovers
      (or reports a specific `save error` without deleting the last good save).
- [ ] Accept an offer during an autosave: the negotiation window and payout must stay
      responsive, and `/gps journal` should say the save was written one macro per tick.
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
