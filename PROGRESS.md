# PROGRESS

## Current state — v1.4.0

Phases 1–4 are implemented. Phase 5 (optional multiplayer) is deliberately not
started. The addon is feature-complete for a single-player shop simulation and is
packaged as an installable ZIP. Created by **ErrorSeib & Buffy (Codebuff)**.

v1.1.0 added the welcome window, Settings category, Addon Compartment entry and an
item-parsing correctness pass. v1.1.1 fixed the sidebar/tab hit area. v1.2.0 added the
guided tour, splash/update screens, Next Up and animations. v1.2.1 fixed bag scanning's
nil handling and baseline behaviour. v1.3.0 added visible throughput, the wholesaler,
queue-based salesperson auto-sales, faster early traffic and a tuned first 30-minute
arc. **v1.4.0** adds The Deed campaign, the Curious Collection museum, Marta Copperpin,
endless mode, franchise prestige and the macro save journal.

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Shop UI, virtual loot inventory, customer generation, negotiation, fictional currency, persistent saving | **Done** |
| 2 | Market fluctuation, personalities, reputation, shop upgrades | **Done** |
| 3 | Employees, random events, achievements, special customers | **Done** |
| 4 | Interface polish, economy balancing, sound effects, bug fixing | **Done** (sound + polish complete; balance validated by simulation, not live play) |
| 5 | Optional multiplayer via addon comms | **Not started** — see `TODO.md` |

## Customer arrival preview

The Lua 5.1 check, diagnostics and mocked UI smoke test cover the arrival card's
closed/open layout selection, queue count, click-through, Compact/Off modes and
overlapping dismissal timers. The smoke test also covers the original toast
fallback and the `/gps arrival` preview on an empty queue. The Forever client
still needs a visual pass for
the sprite textures, stride animation and card placement.

## What exists

* 55 Lua files, 12,976 lines, loaded by a single TOC at Interface 16001.
* Ten-tab main window, movable negotiation window, wholesaler window, encounter popup,
  minimap coin, toasts, tooltips, optional sound.
* The Deed: three payments, an ending choice, endless mode, franchise prestige, one
  five-slot museum set, one named regular and three campaign achievements.
* Throughput tracker, wholesale lot generator, starter crate and queue-based
  salesperson automation.
* 12 inventory categories, 13 races, 9 personalities, 5 shop tiers, 11 upgrades,
  6 employees, 11 market events, 11 encounter types, 26 achievements.
* Standard SavedVariables, a chunked macro journal for the beta save bug, and a
  full copy-paste backup/restore path.
* One guarded compatibility layer for every risky client API.

## Verification performed

Commands, run from the repository root:

```
npm run check              -> Lua 5.1 syntax OK: 55 files, 12,976 lines; TOC OK
npm test                   -> 27 passed, 0 failed; UI smoke: all tabs and overlays
node tools/sim_30min.js    -> scripted 30-minute progression + 10-minute idle probe
```

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
20. **Macro journal** saves a run into ≤18 chunks (each body ≤255 characters), restores
    credits/campaign/museum/sales, omits history, and rejects a corrupted checksum.
21. **Journal trimming** fits 80 bulk stock records into 18 chunks, trims low-value
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

The separate `tools/sim_30min.js` probe still describes the **1.3 economy baseline**:
tier 2 around minute 15, salesperson hired at tier 2, 2.3–3.0 customers/min, and roughly
3,400–4,100 credits left at minute 30. Its policy does not pay the debt, so those
numbers are not a campaign pacing test. The debt amounts (1,500 / 6,000 / 25,000) are
unchanged from the outlined design and need a real play pass.

## Not verified — needs an in-game pass

No part of this addon has been run inside World of Warcraft. Specifically unverified:

- **Macro journal:** whether `CreateMacro`/`EditMacro` are usable at login on Forever,
  whether macro bodies survive a full client restart as expected, the real account
  macro slot limit, and whether the macro list is populated before the first autosave.
  The code retries at `PLAYER_LOGIN`, 2/5/10 seconds and `PLAYER_ENTERING_WORLD`, but
  only a live cold restart can prove the path.
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
2. `/gps test` prints 27 PASS lines in chat.
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
8. Cold-logout and restart the client. Confirm the journal status in the Deed tab and
   that campaign/museum/Marta/prestige progress return. If macro slots are full, confirm
   the UI reports the error instead of silently losing progress.
9. Use **Checkpoint Now**, then `/reload`, and confirm no duplicate stocks, credits or
   campaign payments are replayed.
10. Let a shop day pass (15 minutes), confirm rent/wages appear in the Ledger.
11. Trigger an event naturally; resolve both options over a couple of occurrences.
12. Export a full backup, reset, import; confirm full progress including history returns.
13. Watch for taint or "blocked" messages (there should be none; no secure APIs are used).

## Notes for the next agent

- `Modules/Diagnostics.lua` is the shared test surface for both `/gps test` and the
  harness. Add an economic test for every new reward or reset.
- `tools/smoke_ui.lua` only exercises UI the harness can show; the Deed tab is included
  in the tab sweep, but its click flows still need the live checklist.
- Journal persistence is deliberately **state restoration only**. Do not add offline
  catch-up earnings without a separate exploit review and stock-consumption proof.
- Keep the macro journal's campaign fields ahead of inventory if the 18-chunk budget is
  ever tightened; trimming lowest-value inventory first is intentional.
