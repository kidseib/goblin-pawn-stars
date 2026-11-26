# AGENTS.md — Goblin Pawn Stars

Instructions for any human or AI agent continuing this addon. Read this before
changing code, then check `PROGRESS.md` and `TODO.md`.

## What this project is

A self-contained World of Warcraft: Forever addon (Interface **16001**) that simulates
a pawnshop: virtual copies of looted items, procedural customers, probabilistic
haggling, a fictional currency, market events, employees, upgrades, encounters and
achievements. Created by **ErrorSeib & Buffy (Codebuff)**; keep the TOC `Author`/
`Credit` fields, the welcome window credit line and the README credits in sync when
shipping a release.

No build step ships to the client. The TOC loads plain Lua 5.1 files.

## Hard invariants — do not break these

1. **Never touch the real inventory, gold or game state.** Bags may only be read via
   `C_Container` lookups. No `PickupContainerItem`, no `UseContainerItem`, no
   `SetCurrentTitle`, no mail, no trades, no auctions, no chat automation.
2. **No protected/secure APIs, no combat-log parsing, no secret values.** This addon
   must stay taint-free and safe to run anywhere.
3. **No external services, no paid APIs, no libraries.** Everything is generated
   locally. Do not add a dependency.
4. **No automation of gameplay.** The addon never performs an action on the player's
   behalf.
5. **Lua 5.1 only.** No `goto`, `//`, `&`, `|`, `<<`, `\z`, integer division or
   `table.unpack`. `unpack` (global) is fine — it exists in 5.1.
6. **No `loadstring`/`load` in addon code.** The backup codec is a hand-written
   tokenizer on purpose.
7. **Every risky API goes through `Core/Compat.lua`.** Do not call `C_Item`,
   `C_Container`, `C_Timer`, `SOUNDKIT` or event registration directly outside that
   file unless the call is already wrapped in `pcall` locally. Unknown events throw
   on Forever and abort the whole file. Never pass a nil-returning API through a
   vararg helper and then into `tonumber()`: a lone nil loses all results (this broke
   bag scanning at the first empty slot). Bag getters use pcall directly.
8. **SavedVariables schema stays additive.** `Core/Persist.lua` normalizes and fills
   defaults; add new fields to `defaults()` and increment `SCHEMA_VERSION` only for
   breaking changes, with a migration in `normalize`.
9. **Balanced economy.** Every credit must come from a sale, an event reward or an
   auction result that consumed a virtual item or an entry fee. Never grant credits
   from a timer, a UI button or a failing condition. Salesperson auto-sales run on a
   timer but must go through `Negotiation.AutoSell`/`completeSale`, which removes one
   virtual unit; a timer alone never pays. Keep the price cap in `Negotiation` and
   `Market`. Campaign offer bonuses only raise sale prices, and museum donations and
   Marta visits consume stock like any other sale.
10. **Deterministic item value.** `Data.BaseValue` uses a hash of the item ID, so the
    same item is always worth the same base. Do not replace it with `math.random`.

## Where things live

| Path | Responsibility |
| --- | --- |
| `Core/Bootstrap.lua` | Namespace, utilities, chat helpers, `fill` templates |
| `Core/Compat.lua` | All guarded WoW API access, item/bag helpers, tooltips, frames |
| `Core/Persist.lua` | SavedVariables schema/defaults/normalization, codec, compact snapshot, export/import |
| `Core/Journal.lua` | Macro-chunk save fallback for the beta client, checksums, retries, trimming, status |
| `Core/Slash.lua` | `/gps` and `/goblinpawnstars` |
| `Data/*` | Pure data: items/categories/valuation, names/races, personalities, tiers/upgrades, employees, market events, encounters, achievements, deed/museum/Marta |
| `Modules/Market.lua` | Demand indices, market events, price resolution |
| `Modules/Inventory.lua` | Virtual stock, stacking, capacity, filtering |
| `Modules/Loot.lua` | Bag-diff acquisition detection, baseline repair, one-shot import, `/gps scan` diagnostics |
| `Modules/Shop.lua` | Tiers, upgrades, reputation, expenses, shop days, daily request |
| `Modules/Wholesaler.lua` | Credit-priced bulk lots, restock timer, starter crate |
| `Modules/Staff.lua` | Hiring/promotion/wages |
| `Modules/Customers.lua` | Customer generation, queue, arrival timing |
| `Modules/Negotiation.lua` | Offers, counters, appraisals, sale completion |
| `Modules/Encounters.lua` | Random event construction and resolution |
| `Modules/Achievements.lua` | Progress checks and unlocks |
| `Modules/History.lua` | Ledger (250 entries, newest first) |
| `Modules/Throughput.lua` | Rolling 3-minute credits/min and customers/min from completed sales |
| `Modules/Goals.lua` | Ordered starter and campaign objectives for the dashboard Next Up card |
| `Modules/Museum.lua` | The Curious Collection set, stock-consuming donations and offer bonus |
| `Modules/Regular.lua` | Marta Copperpin's named visits, story beats and referral bonus |
| `Modules/Campaign.lua` | The Deed payments, endings, endless mode and franchise prestige |
| `Modules/Sound.lua` | Optional guarded sound cues |
| `Modules/Diagnostics.lua` | Self-tests, also used by the Node harness |
| `UI/Theme.lua` | Colours, textures, backdrops |
| `UI/Widgets.lua` | Panels, text, buttons, icons, portraits, bars, scroll lists, edit boxes |
| `UI/Anim.lua` | Guarded fade/pulse/spin helpers with instant fallbacks |
| `UI/MainFrame.lua` | Window, sidebar, header, tab host, toasts |
| `UI/Tour.lua` | Seven-step spotlight tour, splash/`/gps guide` entry points |
| `UI/WelcomeFrame.lua` | First-run welcome window, author credits, login toggle |
| `UI/OptionsPanel.lua` | Blizzard Settings category + Addon Compartment registration |
| `UI/Tabs/*` | One file per tab; each registers `ns.UI.Tabs.<id> = { title, icon, Create }` |
| `UI/NegotiationFrame.lua` | Haggling window |
| `UI/EventFrame.lua` | Encounter popup |
| `UI/WholesalerFrame.lua` | Standalone three-lot wholesaler window |
| `UI/MinimapButton.lua` | Draggable coin |
| `tools/*` | Syntax check, fengari harness, WoW mock, UI smoke, packager |

## Adding content

**New personality:** append to `Data/Personalities.lua` with `key`, `name`, `weight`,
`opening`, `maxWill`, `budget`, `patience`, `stubborn`, `prefer`, `lines`
(`greet`, `offer`, `accept`, `refuse`, `leave`). Keep `prefer` categories valid. The
diagnostics check asserts nine personalities; update that count when adding one.

**New achievement:** append to `Data/Achievements.lua`. Use `stat` + `target`, or a
`check(db)` function returning `progress, target`. Keys must be unique. The dashboard
and achievements tab pick it up automatically.

**Campaign content:** payments, museum slots and Marta's visits live in `Data/Deed.lua`.
Every campaign reward must be stock-backed or purely a sale-price modifier. When adding
a reset or prestige path, preserve the museum, regular, achievements and settings in
`Campaign.Franchise`, and add a diagnostics test for the retention.

**New upgrade/employee/market event/encounter:** append to the relevant data file.
Effects use the `fx` keys consumed in `Shop.Bonuses()` (`storage`, `arrival`,
`appraisal`, `haggle`, `rare`, `expense`, `theft`, `waiting`, `patience`, `offer`,
`repGain`, `forgery`, `autosale`, `storage`). `autosale` raises the salesperson's
automatic margin, not a shop-day chance. Encounters also need a builder in
`Modules/Encounters.lua` keyed by `def.key` and a resolution branch.

**New wholesale template:** append to `Data/Wholesale.lua` with `key`, `lotName`,
`itemName`, `category`, `classID`, `subclassID`, `ilvl` and `icon`. Keep the lot
category consistent with the class/subclass pair; the wholesaler prices it from live
`Market.Value` and gives each purchase a new virtual stack.

**Wholesaler pricing:** lots are bought with credits and become virtual stock. The
purchase price must stay below live stack-adjusted retail value; never make a lot free,
and never let buying or auto-selling bypass `Inventory.Remove` for the sold unit.

**Animations:** put new effects in `UI/Anim.lua` and always keep the instant fallback:
if the animation API is missing, the region must end fully visible at its normal scale.
Do not add `OnUpdate` loops for animation; use animation groups. Keep gameplay logic out
of animation callbacks, because a missing animation must never change state.

**Guided tour:** steps live in `UI/Tour.lua`; a step may set `tab` (switch before
highlighting) and `target` (`header`, `sidebar`, `goal`, or a tab id whose button is in
`ns.UI.TabButtons`). Targets may be nil on a client without that frame; the tour then
centres the card without a spotlight. New targets must be exposed through `ns.UI`.

**New tab:** add `UI/Tabs/<Name>.lua` with
`ns.UI.Tabs.<id> = { title, icon, Create = function(parent) ... return api end }`,
add the file to the TOC **before** `UI/MainFrame.lua`, and add the id to
`ns.UI.TabOrder` in `MainFrame`. `Create` returns a table with `Refresh()`.

## Testing workflow

```bash
npm install      # once; luaparse + fengari are dev-only
npm run check    # Lua 5.1 parse of every file (fails on 5.3-only syntax)
npm test         # fengari harness: diagnostics + UI smoke
node tools/sim_30min.js  # optional 30-minute progression + idle probe (dev only)
npm run package  # dist/GoblinPawnStars-<version>.zip
```

Rules:

* Add a test to `Modules/Diagnostics.lua` for any economic or state change. Tests run
  inside a scratch database (`ns.DB.Scratch()`), never the player's save. Scratch
  databases disable the macro journal by default; journal tests opt back in and call
  `__clearMacros()` afterwards.
* The macro journal is a compact fallback: it deliberately omits history and the live
  customer queue. Do not rely on it for exact ledger restoration, and never overwrite a
  newer SavedVariables snapshot with an older journal.
* Extend `tools/smoke_ui.lua` when adding UI that is built lazily; the mock only
  builds what the smoke script shows.
* Never weaken an assertion to make a run green. Fix the cause.
* The mock is not the game: frame layout, textures, fonts, real item data, bag
  behaviour and SavedVariables loading all need an in-game pass. State clearly in
  `PROGRESS.md` what was verified only under mocks.

## Code style

* 4-space indent, explicit `local`, one module per file, no globals beyond the TOC
  contract (`ADDON`, `ns`, slash globals).
* Prefix private helpers with `local function`; expose only the module table.
* Guard callbacks that can run from events/timers with `pcall` where a failure would
  spam errors during gameplay.
* Comment economy formulas and any non-obvious invariant. Do not write comments that
  restate the code.
* Keep the 1-second clock the only recurring simulation driver. No `OnUpdate` polling
  except the clock accumulator and the minimap drag handler.

## Packaging

`tools/build_zip.sh` reads the version from the TOC and produces
`dist/GoblinPawnStars-<version>.zip` containing a single `GoblinPawnStars/` folder
with the addon plus `README.md` and `CHANGELOG.md`. Bump the TOC version, `ns.VERSION`,
`package.json` and the changelog together, then rebuild and delete the superseded ZIP.

Optional modern integrations must stay optional: the Settings category and Addon
Compartment registration live in `UI/OptionsPanel.lua` behind feature checks, and the
in-addon Settings tab must remain fully usable without them.
