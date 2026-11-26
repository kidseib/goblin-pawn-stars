# CurseForge listing kit

Everything needed to publish the Goblin Pawn Stars project page, without pretending
the current UI renders are live-client screenshots.

**Current version:** 1.6.1.

## Files

| File | Use |
| --- | --- |
| `description.html` | **Primary version** — paste into the CurseForge WYSIWYG source view; eight screenshots already placed |
| `description.md` | Markdown fallback, if you prefer that editor |
| `description-long.md` | Longer, more technical Markdown version |
| `build_preview.py` | Generates the local preview, copy page and index from `description.html` |

Run `python3 build_preview.py` to produce three local helpers:

- `description-preview.html` — the layout at CurseForge's 836 px description width;
- `description-copy.html` — a one-click copy page for the raw HTML;
- `index.html` — the preview with a "Copy description HTML" button.

Those three are generated output and are not committed. The optional 1280×340
gallery banners are editable SVGs in `banners/*.svg`, which are committed so the
art cannot be lost; render them at 1280×340 into `banner-*.png` when you need the
flattened images, and keep those PNGs out of the repository.

## Suggested project fields

**Name:** Goblin Pawn Stars

**Summary:**

> Run a goblin pawnshop in World of Warcraft: Forever. Stock virtual loot, haggle
> with procedural customers, read the market, and pay off a three-note cartel debt.
> No real gold or items touched.

**Categories:** Auction & Economy; Miscellaneous.

**Tags:** pawnshop, economy, minigame, simulation, goblin, single-player, trading,
roleplay.

**Version:** 1.6.1.

**License:** MIT.

## Pasting the description

1. Run `python3 build_preview.py`, open `description-copy.html` in a browser and
   click **Copy description HTML**.
2. In the CurseForge description editor, choose **WYSIWYG** and open its
   **HTML/source view** (`</>`).
3. Paste the whole block and switch back to the normal preview. The eight screenshot
   renders are already placed between the sections.
4. The images use public GitHub URLs on `github.com`, which CurseForge allows. If one
   is blocked or stripped, upload the matching PNG from `../screenshots/` through the
   editor's image button and replace that one URL.
5. `description-preview.html` shows the layout at 836 px before you paste it.
6. The banner images are optional. Use them in the CurseForge image gallery/carousel
   rather than inside the HTML; the description already has the screenshots and does
   not need a second set of banners.
7. Set the project avatar separately. The goblin coin from the hero banner is the
   obvious starting point if you want a 400×400 export.

If CurseForge's WYSIWYG source view is unavailable, use the **Markdown** editor and
paste `description.md` instead. The HTML version is the better-looking one and is the
one that includes the renders inline.

## Gallery

The eight images in [`../screenshots/`](../screenshots/) are **1440×900 UI renders**,
not live-client captures. If they are used in the CurseForge carousel:

- title each one with “UI render” and keep the label visible;
- do not describe them as in-game screenshots;
- replace them with real client captures as soon as the in-game pass is done.

The description includes a visual note for this reason. Remove that note only after
the gallery contains real screenshots.

## Before publishing

- **Forever is not a standard CurseForge game version.** Upload under the closest
  available World of Warcraft addon version and state **Interface 16001** in the
  description and file metadata.
- **Live-client pass still in progress.** The 30-diagnostic suite and the UI smoke
  pass are green; the in-game checklist is open. The description says so on purpose.
- **The repository is public.** The description links to the source at the bottom;
  keep that link when you paste the Markdown.
- **VirusTotal:** the 1.4.0 ZIP has a public report with no vendor detections. The
  1.6.1 scan is still pending — the release workflow needs a repository secret named
  `VT_API_KEY` — and future scans are appended to their release notes automatically.
- **Checksums:** `description.html`, `description.md` and `description-long.md` carry
  the SHA-256 of `GoblinPawnStars-1.6.1.zip`. Rebuild the ZIP and all three need the
  new hash.
- **No runtime downloads.** The addon has no libraries, external services, network
  calls or telemetry, and it never touches real gold, items, bags or game actions.
- **Free distribution.** Keep the project free; the MIT license is included in the
  ZIP. Blizzard's addon policy independently requires free distribution.
