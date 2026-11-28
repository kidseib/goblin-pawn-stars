# GOBLIN PAWN STARS

**Loot it. Stock it. Haggle it. Pay off the cartel.**

_A pawnshop management and trading-empire minigame for World of Warcraft: Forever._

_The screenshots below are UI renders of the addon's theme and sample state, not live-client captures. The in-game visual pass is still in progress._

![Goblin Pawn Stars dashboard UI render with credits, stock, customer queue and next goal](https://github.com/kidseib/goblin-pawn-stars/raw/main/docs/screenshots/01-dashboard.png)

_UI render — the Dashboard: credits, reputation, stock, the waiting customer and the next move._

Your bags are full of junk. To a goblin, that's not junk — that's **inventory**.

Goblin Pawn Stars turns the loot you already find into a shop with a big problem: a cartel debt, a growing museum, and a queue of customers who all think they can smell desperation. Stock the shelves, read the market, haggle like you've got a knife in your boot, and turn a roadside stall into an Azeroth Trading Empire.

**No real gold. No real items. No auctions. No automation of the game client.** Just goblin math.

> "I know what I've got." — every customer, eventually.

***

## WHAT'S NEW IN 1.7.9

*   **Your save loads itself, four times at most.** A login reads the macro journal at most four times, two to thirty seconds apart, then settles — one counter, no retry chains. While it runs the header says `loading saved shop` and every save is refused, so a fresh session can never stamp a new shop over a run it has not read. **Settings → Auto-load** turns it off, and **Settings → Backup & Restore → Load saved** (press it twice) loads a run by hand at any time.
*   **Saves no longer touch the frame.** A journal save is now written one macro at a time, a few milliseconds a second, instead of the whole generation in a single frame. A big stockroom used to hitch; now the save spreads invisibly over a few seconds. The commit header still goes last, so an interrupted save still leaves your previous run intact.
*   **No more retry storm.** A journal that would not assemble used to schedule three more full macro reads from every failed attempt — enough macro work to stall the client. Every load is now one read that tells you what went wrong, and the login load stops after its fourth attempt.
*   **Everything else stayed put.** No economy, arrival, stock or haggling changes.

***

## THE 1.7 RUN, IN BRIEF

*   **Loading is bounded.** The journal is read shortly after login at most four times, then settles; **Settings → Auto-load** turns that off, and **Load saved** repeats one read on demand. Autosaves only run once a run is loaded.
*   **Saving stopped stuttering.** A journal save is staged as a queue of single macro operations with an 8 ms budget a tick, so it writes one chunk per frame. Saves wait until the shop window is closed and the counter is empty, and only one generation stays on the macro list. Logout, imports, **/gps verify** and **Save Now** still finish a staged save immediately.
*   **Rolling backups.** Three timestamped snapshots, one every ten minutes and one on demand, kept outside the main save. Restore needs a second click and first captures the state it is about to replace.
*   **Haggling is honest.** The counteroffer percentage shown is the number the roll uses, the Low/Fair/Greedy presets follow the customer's visible offer, and every completed sale displays the exact credits it paid.
*   **Save health you can see.** **/gps verify** reads the journal back off the macro list and compares it with the session, so a save problem is provable without logging out. The header carries the save state: `saved 12s ago`, `save pending`, `save error` or `save off`.
*   **A lighter client.** **Performance mode** swaps 3D customer portraits for class icons, takes the instant path for every animation and compacts the arrival card; **/gps motion** turns animations off, **/gps uicheck** finds windows off-screen at your UI scale, and login prints a one-line summary of credits, queue and stock.

***

## WHAT YOU'RE SIGNING UP FOR

*   **A shop that grows** from a 12-slot roadside stall to a 120-slot Azeroth Trading Empire.
*   **Customers with secrets.** Nine archetypes, hidden ceilings, and a patience bar that does not care about your plans.
*   **A market that bites back.** Twelve categories and eleven demand shocks, including a Goblin Market Crash.
*   **A finish line.** Three cartel notes, a museum set, a named regular, and an ending — then endless mode or a franchise.
*   **A clean conscience.** No real gold, items, auctions, trades or game actions. Your bags are read, not written.

**9** customer archetypes · **12** market categories · **5** shop tiers · **11** upgrades · **6** employees · **26** achievements.

***

## THE LOOP

**Loot → Stock → Appraise → Haggle → Invest → Repeat.**

1.  **Stock the shelves.** Eligible loot you pick up becomes virtual stock. The first scan is a silent baseline, so installing the addon never dumps your existing bags into the shop. Need a top-up? Buy a bulk lot from the Wholesaler.
2.  **Read the room.** Twelve categories move on their own demand curves. Events like the Collector's Festival, Mining Shortage and Goblin Market Crash can turn a shelf-warmer into a bidding war.
3.  **Haggle.** Every customer has a budget, a taste, a hidden ceiling and a patience bar. Accept the offer, reject it, or counter. Push too hard and they walk.
4.  **Reinvest.** Storage, display cases, haggling manuals, security, staff, advertising — then four bigger shop tiers. Hire a salesperson to work the queue while you're busy, at a thinner margin.
5.  **Pay the deed.** The cartel wants three notes: 1,500, 6,000 and 25,000 Goblin Credits. Pay up, or find out what a goblin collection agency looks like.

***

## EVERY CUSTOMER HAS A NUMBER

Nine customer archetypes walk through the door: the wealthy collector who knows exactly what the piece is worth, the bargain hunter who opens so low it's almost a threat, the experienced trader who can smell a fake at ten paces, the rare hunter who will pay stupid money for one very specific thing — and five more.

They all have hidden ceilings. Your counter succeeds on a roll shaped by margin, stubbornness, haggling upgrades, appraisal and reputation. Appraise first to see the value band; a perfect read hints at what they can really pay. Patience runs out. So does yours.

![Goblin Pawn Stars negotiation UI render with a customer offer, counteroffer and patience bar](https://github.com/kidseib/goblin-pawn-stars/raw/main/docs/screenshots/03-negotiation.png)

_UI render — the negotiation window: offer, counter, appraisal and a patience bar that is already judging you._

Rare collectors and celebrity visitors appear with tier, upgrade and staff bonuses. Customers occasionally arrive as events: a returning complainer, a lowball artist, a counterfeit seller or a hooded figure with very specific taste.

***

## THREE NOTES. ONE WAY OUT.

The cartel debt gives the shop a finish line: **1,500 → 6,000 → 25,000 Goblin Credits**. The first payment unlocks The Curious Collection and Marta Copperpin. The third closes the ledger and offers a choice: keep the shop open in endless mode, or open a franchise.

The **Curious Collection** has five slots: weapon, gem, cloth, ore and curiosity. Each donation consumes a quality-2+ virtual stock unit; completing the set adds a permanent **+5% to customer offers**. **Marta Copperpin** is a named Dwarf regular with three story visits. After her third, her referral network adds a permanent **+3%**.

![Goblin Pawn Stars Deed tab UI render with three cartel payments, museum slots and Marta](https://github.com/kidseib/goblin-pawn-stars/raw/main/docs/screenshots/02-deed.png)

_UI render — the Deed: three payments, five museum slots, Marta's visits and the ending choice._

***

## READ THE MARKET. BUY THE DIP.

Demand moves. Twelve categories have their own curves, and eleven market events can bend them: War Effort, Alchemist Convention, Mining Shortage, Goblin Market Crash, Collector's Festival, Auction Frenzy and more. Events run on playtime, so logging out pauses them.

The **Wholesaler** sells three rotating bulk lots for Goblin Credits. Each lot becomes one virtual stack; the price is a discount to live, stack-adjusted market value. A crash after purchase is a real loss. Lots refresh every four minutes, or sooner after the last one is bought.

![Goblin Pawn Stars market UI render with category demand bars and active market events](https://github.com/kidseib/goblin-pawn-stars/raw/main/docs/screenshots/05-market.png)

_UI render — the Market: twelve demand bars, active events and today's request._

![Goblin Pawn Stars wholesaler UI render with three bulk lots priced in Goblin Credits](https://github.com/kidseib/goblin-pawn-stars/raw/main/docs/screenshots/07-wholesaler.png)

_UI render — the Wholesaler: three bulk lots, live margins and a four-minute refresh._

There are no offline earnings. Every credit must come from a virtual item a customer actually bought.

***

## A SHOP, NOT A BUTTON.

Ten tabs cover the dashboard, Deed, customers, inventory, market, upgrades, employees, achievements, ledger and settings. Five shop tiers, eleven permanent upgrades, six employees and 26 achievements give every run a new lever to pull.

![Goblin Pawn Stars inventory UI render with virtual stock, quality and market values](https://github.com/kidseib/goblin-pawn-stars/raw/main/docs/screenshots/04-inventory.png)

_UI render — Inventory: searchable, filterable virtual stock with real item tooltips and live values._

A first-run **splash screen** explains the loop in three steps. After an update it becomes a **what's new** screen. Both can launch a seven-step **guided tour** that spotlights the header, tabs, haggling, upgrades and the campaign. Reopen the splash with **/gps welcome**; replay the tour with **/gps guide**.

![Goblin Pawn Stars upgrades UI render with shop tiers and permanent improvements](https://github.com/kidseib/goblin-pawn-stars/raw/main/docs/screenshots/06-upgrades.png)

_UI render — Upgrades: shop tiers, eleven permanent improvements and the next thing to buy._

Also included: a draggable minimap coin with a waiting-customer alert, toasts, optional sound cues, item tooltips, a Blizzard Settings category and an Addon Compartment entry.

***

## SAFE BY DESIGN.

*   **Bags are read, never written.** No equip, sell, destroy or mail.
*   **No real gold, items, auctions, trades or game actions.** Goblin Credits are fictional.
*   **No protected or secure APIs**, no combat-log reading, no secret values, no automation of gameplay.
*   **No libraries, no external services, no network calls, no telemetry.**
*   **Lua 5.1, Interface 16001.** Every risky client call is guarded or feature-checked.

The salesperson works your virtual queue; she never performs a real game action.

**Beta persistence:** on the current Forever beta, SavedVariables may not load at login. The addon checkpoints into a macro journal — one 12-chunk generation, written one macro per tick every five minutes — and supports a full backup/restore string in Settings. **Loading is automatic but bounded:** a login reads the journal at most four times, then settles, and nothing is written over it until that load settles or a run is reset. Turn **Settings → Auto-load** off and press **Settings → Backup & Restore → Load saved** twice to load by hand. Logout, imports, **/gps verify** and **Checkpoint Now** finish a staged save immediately. The Deed tab shows journal status and a **Checkpoint Now** button.

![Goblin Pawn Stars settings UI render with interface options, backup tools and diagnostics](https://github.com/kidseib/goblin-pawn-stars/raw/main/docs/screenshots/08-settings.png)

_UI render — Settings: interface options, Performance mode, auto-load, backup/restore, diagnostics and the emergency brake._

***

## INSTALL

1.  Download the latest ZIP from the **Files** tab.
2.  Extract the **GoblinPawnStars** folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3.  Restart the client or type **/reload**, then **/gps**.
4.  A saved shop loads by itself shortly after login. To load by hand instead, turn **Settings → Auto-load** off and press **Settings → Backup & Restore → Load saved** twice; on a fresh install there is nothing to find and saving starts from there.

The first bag scan is a silent baseline. Click **Stock Bags Now** on the Dashboard or run **/gps importbags** to copy eligible items you're already carrying. After that, new pickups stock themselves.

**Useful commands:** **/gps** open the shop · **/gps wholesale** open the wholesaler · **/gps welcome** show the splash · **/gps guide** replay the tour · **/gps importbags** stock eligible items already in your bags · **/gps scan** show what the bag reader sees · **/gps backup** jump to Backup & Restore · **/gps profile** timing report · **/gps verify** check the last save · **/gps reset** wipe progress (asks twice) · **Load saved** in Settings loads a saved shop by hand.

***

## VERIFY THE DOWNLOAD

SHA-256 for **GoblinPawnStars-1.7.9.zip** (3,335,096 bytes):

`4afff19964f94f182827001e94d25d5cfcb175c9308d725bf10616446fe81ba3`

**VirusTotal:** the 1.4.0 build was scanned with no vendor detections. Newer scans are attached to their release notes when the repository's automated scan has its `VT_API_KEY` secret configured. Until then, compare the SHA-256 above with the [1.7.9 release notes](https://github.com/kidseib/goblin-pawn-stars/releases/tag/v1.7.9), or read the source: the addon is plain Lua.

The same hash is in the GitHub release notes.

***

## STATUS — 1.7.9

Feature-complete, with a **59-test headless simulation suite** and a full **UI smoke pass** behind it. The live-client visual and persistence checklist is still in progress — it now includes the bounded login load, loading a run from Settings, and a save on a full stockroom. Interface **16001** (World of Warcraft: Forever).

If something looks off in the real client, report it in the comments with your UI scale and what you were doing. That is exactly the feedback this release needs.

_Visual note: the screenshots above are UI renders built from the addon's theme and sample state, not live-client captures. They are labeled accordingly; real in-game screenshots will replace them once the client pass is complete._

***

## CREDITS

Created by **ErrorSeib & Buffy (Codebuff)**. Human-directed, AI-assisted development. The addon has no runtime AI, makes no network requests, and collects no player data. MIT licensed.

Source, changelog and issue tracker: [github.com/kidseib/goblin-pawn-stars](https://github.com/kidseib/goblin-pawn-stars)

Unofficial fan project. Not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft and related marks are trademarks of Blizzard Entertainment.

**Loot it. Stock it. Haggle it. Pay off the cartel.**
