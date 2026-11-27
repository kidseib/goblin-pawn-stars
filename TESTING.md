# Testing Goblin Pawn Stars 1.7.5 in-game

This is the live-client pass for **The Deed**. The headless suite already covers the
economy and state math; this checklist covers what mocks cannot: real macros,
SavedVariables, textures, fonts, layout, and whether the campaign feels right.

If something fails, [open an issue](../../issues) with the exact chat/toast text, what
you clicked, whether it happened after `/reload` or a full client restart, your UI
scale, and any Lua error.

## Before you start

- Install `GoblinPawnStars-1.7.5.zip` from the
  [v1.7.5 release](https://github.com/kidseib/goblin-pawn-stars/releases/tag/v1.7.5).
  The folder layout must be
  `Interface/AddOns/GoblinPawnStars/GoblinPawnStars.toc`.
- `/gps version` should report **1.7.5** and interface **16001**.
- `/gps test` should report **53 passed, 0 failed**. The macro-journal tests skip
  themselves in the live client so they never touch your real macros; the journal is
  tested for real in the cold-restart pass below.
- Run `/console scriptErrors 1` before testing.
- Run `/gps report` once and keep the output; it is the first thing to paste into
  a bug report.
- The journal keeps up to 12 macros in one committed generation
  (`GPSA01`–`GPSA12` or `GPSB01`–`GPSB12`). A save briefly writes the other generation
  before retiring it. Leave macro slots free, and do not rename
  or delete those macros while testing. `/gps reset` removes them. A save written by
  1.6.3 or earlier lives in `GPSJ01`–`GPSJ24`; it is read once and retired by the next
  save.

## 1. Cold-restart journal restore

1. Start clean with `/gps reset` twice within 20 seconds (the first call only warns).
2. Make progress: sell a few items, then note **credits, sales, tier, and stock count**.
3. Open **The Deed** and click **Checkpoint Now**. Expect a toast like
   `Journal saved: N chunks.` and a footer reading `Journal: N chunks · saved 0s ago`.
4. `/reload` once; state should survive the soft reload.
5. Quit the client completely, restart it, and log back in.
6. Within a few seconds the chat should print
   `Progress restored from the macro journal (...)`. Verify credits, stock, tier,
   sales, campaign payments, museum, and Marta state.

Expected, not bugs: the ledger and live customer queue are intentionally omitted, very
large stock can be trimmed (the footer says `inventory trimmed`), and the next customer
may take about 8 seconds to arrive.

**Report:** journal empty/error text, different credits, or progress silently resetting
after login.

## 2. Payment immediately after a restore

1. Straight after the cold restart — before any sale or `/reload` — open **The Deed**.
2. With 1,500+ gc, click **Pay 1,500 gc** immediately.
3. Expect payment **1 of 3**, 1,500 deducted, Snix's first-note story, and the museum
   and Marta sections unlocking.
4. `/reload` and confirm the Deed still shows **1 of 3**, with both sections unlocked.

This is the regression test for the stale-database bug: the first action after a
journal restore must write to the restored save.

## 3. `/gps reset`

1. `/gps reset` once; it warns and asks for a second confirmation within 20 seconds.
2. Wait at least 21 seconds, then `/gps reset` once; it should warn again.
3. `/gps reset` twice within 20 seconds. Expect
   `Shop reset. The goblin council has confiscated everything.`
4. Verify credits are back to 250 and stock, tier, upgrades, staff, museum, Marta,
   achievements, campaign, and prestige are cleared. No `GPSA`, `GPSB` or `GPSJ`
   macros should remain.
5. `/reload` and confirm the shop is still fresh — old progress must not return from the
   journal.
6. Optional: repeat from **Settings → Backup & Restore → Reset all progress** (click
   twice; the confirmation disarms after 8 seconds).

## 4. Three-note Deed flow

The amounts are fixed: **1,500 → 6,000 → 25,000** (32,500 total). There is deliberately
no cheat command, so the final note is the slow part. If you already have a save with
enough credits, export it first under **Settings → Backup & Restore**, then import it on
the test character.

1. With under 1,500 gc, **Pay** is disabled and clicking it does nothing.
2. Pay note 1 (1,500): progress becomes **1 of 3**, the button relabels to
   `Pay 6,000 gc`, and the museum and Marta unlock with the first story beat.
3. Pay note 2 (6,000): progress becomes **2 of 3** and Marta's second-visit setup line
   appears.
4. Pay note 3 (25,000): the header reads `Paid in full: 32,500 / 32,500 gc`, the Pay
   button disappears, and **Keep the Shop Open** and **Open a Franchise** appear.

Check the whole panel at your normal UI scale: title, story, amounts, and footer should
not clip or overlap.

## 5. Museum — The Curious Collection

Unlocked after the first payment.

1. Five slots: **weapon, gem, cloth, ore, misc**, each requiring quality 2+.
2. A slot with no matching stock shows `No item`; with matching stock, **Donate** is
   clickable.
3. Donate one item and confirm the **Inventory** stack drops by exactly one unit, the
   row shows the donated item name and `Donated · ...`, and no real bag item changes.
4. A quality-1 item and a wrong-category item must both be refused.
5. Complete all five: the footer gains `Museum +5%` and the total offer bonus rises by
   5.
6. The donated pieces must survive `/reload` and a cold restart.

## 6. Marta Copperpin

1. She unlocks after payment 1. The Deed section explains why she cannot come
   (`Not ready`, `Locked`, or `Marta is already at the shop`).
2. **Invite Marta** needs stock and a free waiting slot. Click it; the toast reads
   `Marta Copperpin is waiting at the counter.` and a named Dwarf customer appears.
3. Serve her through the normal haggling window. Serving advances the visit count and
   shows the visit story (`visit 1 of 3`, and so on).
4. After the third visit: `Marta's story is complete...`, the footer gains `Marta +3%`,
   and the button becomes `Story complete`.
5. Rejecting her must not advance the story, and her visits must be normal stock-backed
   sales — no free credits.

## 7. Endings, endless, and franchise

1. After the final payment, click **Keep the Shop Open**; the shop continues with
   credits and stock intact, and the Deed shows the endless ending.
2. Click **Open a Franchise** once; the label becomes `Click again to confirm`. Click
   again; expect `Franchise 1 opened. A new deed begins.`
3. Verify the reset:
   - Credits are back to **250** plus a starter crate; stock, tier, upgrades, and staff
     are reset.
   - **Kept:** museum donations and their +5%, Marta's visits and +3%, achievements, and
     settings.
   - Prestige level is 1 (+5% offers) and the new deed is **Payment 1 of 3** at 1,500.
4. Immediately `/reload` and cold-restart: franchise level, museum, and Marta must all
   persist (this exercises the deferred-reset journal path).
5. Open a second franchise later; the offer bonus should become +10% and the museum and
   Marta should still carry over.

## 9. Save state, motion and layout (1.7.0)

1. The header now ends with a save state. A fresh session reads **save pending**
   until the first five-minute save; it must then read **saved 0s ago**. Autosaves
   wait until the shop window is closed and no customer is at the counter, so close
   the window and wait before expecting one. If it settles on **save error** or
   **save off**, run `/gps journal` and paste the result.
2. Run `/gps verify`. It should print **Save verified — generation A/B verified: N gc,
   N sales, N stock stacks**, and the header should then read **saved 0s ago**. If it
   fails, the message names the field that differs (credits, tier, sales, served).
3. Log out (not `/reload`) and back in. Expect the **Welcome back** line with credits,
   waiting customers, stock and how long ago the save landed.
4. `/gps motion` should stop fades, pulses and walk-ins. Run it again to turn them back on;
   the UI must stay fully usable with animations off.
5. `/gps uicheck` at 0.8, 1.0 and 1.2 UI scale. It must print **no window sits
   off-screen**; if it names a window, screenshot it at that scale.
6. Make the first sale on a fresh save. The first three customers are scripted; the low
   preset should be a comfortable win so a new player learns the haggle.
7. Freeze check with a full stockroom: fill the shelves, then `/gps journal`. A save
   reports **took N ms**; confirm the client does not hitch when it runs with the
   window closed. A logout or `/gps verify` runs the same batch immediately and may
   be slower.
8. Long-session check: leave the shop open with auto-sell running for ten minutes. The
   client must stay as responsive at the end as at the start; the credits number pulses
   on every sale and must not build anything up.

## What to send back

- `/gps test` summary line.
- Exact chat/toast/error text for anything unexpected.
- Whether it happened after `/reload` or a full client restart.
- UI scale and a screenshot of the Deed tab if anything looks clipped.
- Pacing feedback: was the first note affordable, did the second compete with upgrades,
  and did 25,000 feel like a goal rather than a wall?

## Known gaps

- No screenshots or layout checks are possible without a client; the Deed tab, tooltips,
  fonts, and textures have only been reviewed in the mock harness.
- SavedVariables loading is broken on the current Forever beta, which is why the macro
  journal exists. Once Blizzard fixes it, re-test the normal save path.
