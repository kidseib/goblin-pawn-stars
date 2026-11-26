#!/usr/bin/env python3
"""One-shot edits for the 1.6.1 minimap fix.

Run from the repository root. Deleted by the release workflow after it commits.
"""
import pathlib
import sys


def read(path):
    return pathlib.Path(path).read_text(encoding="utf-8")


def write(path, text):
    pathlib.Path(path).write_text(text, encoding="utf-8")


def replace_once(path, old, new):
    text = read(path)
    if old not in text:
        sys.exit("missing text in %s: %r" % (path, old[:80]))
    write(path, text.replace(old, new, 1))


def replace_all(path, old, new):
    text = read(path)
    if old not in text:
        sys.exit("missing text in %s: %r" % (path, old[:80]))
    write(path, text.replace(old, new))


# --- version bumps ---------------------------------------------------------
replace_once("addon/GoblinPawnStars/GoblinPawnStars.toc",
             "## Version: 1.6.0", "## Version: 1.6.1")
replace_once("addon/GoblinPawnStars/Core/Bootstrap.lua",
             'ns.VERSION = "1.6.0"', 'ns.VERSION = "1.6.1"')
replace_once("package.json", '"version": "1.6.0"', '"version": "1.6.1"')
replace_all("package-lock.json", '"version": "1.6.0"', '"version": "1.6.1"')
replace_once(".github/workflows/virustotal.yml", "default: v1.6.0", "default: v1.6.1")
replace_all("README.md", "1.6.0", "1.6.1")
replace_all("TESTING.md", "1.6.0", "1.6.1")

# --- minimap button --------------------------------------------------------
MINIMAP = "addon/GoblinPawnStars/UI/MinimapButton.lua"
text = read(MINIMAP)
start_marker = '    local ring = button:CreateTexture(nil, "BACKGROUND")'
end_marker = "    button.alert = alert"
start = text.find(start_marker)
end = text.find(end_marker)
if start < 0 or end < 0 or end < start:
    sys.exit("could not locate the minimap texture block")
end += len(end_marker)
NEW_BLOCK = '''    -- Round body behind the coin. Without it the border reads as a hollow
    -- circle with the minimap showing through it.
    local body = button:CreateTexture(nil, "BACKGROUND")
    body:SetTexture("Interface\\\\Minimap\\\\UI-Minimap-Background")
    body:SetAllPoints(button)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture(T.media.coin)
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    button.icon = icon

    -- The tracking-border art sits in the top-left of its texture, so it has
    -- to be anchored TOPLEFT at 54x54. Centring it shifted the ring off the
    -- coin and let the icon spill out of the frame.
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\\\Minimap\\\\MiniMap-TrackingBorder")
    ring:SetSize(54, 54)
    ring:SetPoint("TOPLEFT")

    -- A waiting customer shows as a small gold coin pip. The old flat 8x8
    -- colour square read as a missing texture next to the coin art.
    local alert = button:CreateTexture(nil, "OVERLAY")
    alert:SetSize(10, 10)
    alert:SetPoint("TOPRIGHT", 4, 4)
    alert:SetTexture(T.media.coin)
    alert:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    alert:Hide()
    button.alert = alert'''
write(MINIMAP, text[:start] + NEW_BLOCK + text[end:])

# --- what's new entry ------------------------------------------------------
WELCOME = "addon/GoblinPawnStars/UI/WelcomeFrame.lua"
replace_once(WELCOME, '    ["1.6.0"] = {', '''    ["1.6.1"] = {
        "The minimap coin is fixed: the ring sits around the coin again instead of drifting off it.",
        "The waiting-customer alert is a small gold pip instead of a green square.",
    },
    ["1.6.0"] = {''')

# --- changelog -------------------------------------------------------------
CHANGELOG = "CHANGELOG.md"
entry = '''## [1.6.1] — 2026-11-26

### Fixed

- The minimap button draws as a round coin again. The tracking border was anchored
  by its centre even though its art sits in the top-left of the texture, which
  pushed the ring off the coin and let the icon spill out of the frame. The button
  also had no background behind the icon, so the ring looked hollow.
- The waiting-customer alert is a small gold coin pip instead of an 8x8 green
  square that read as a missing texture.

No gameplay, save or economy changes.

'''
replace_once(CHANGELOG, "## [1.6.0] — 2026-11-25", entry + "## [1.6.0] — 2026-11-25")

# --- progress --------------------------------------------------------------
PROGRESS = "PROGRESS.md"
replace_once(PROGRESS, "## Current state — v1.6.0", "## Current state — v1.6.1")
replace_once(PROGRESS,
             "endless mode, franchise prestige and the macro save journal.",
             "endless mode, franchise prestige and the macro save journal. **v1.5.0** adds native customer models and movable arrival cards. **v1.6.0**\n"
             "adds questing auto-sell and doubles the arrival waits. **v1.6.1** fixes the minimap\n"
             "coin's ring, background and waiting-customer pip.")

# --- assertions ------------------------------------------------------------
checks = [
    ("addon/GoblinPawnStars/GoblinPawnStars.toc", "## Version: 1.6.1"),
    ("addon/GoblinPawnStars/Core/Bootstrap.lua", 'ns.VERSION = "1.6.1"'),
    ("package.json", '"version": "1.6.1"'),
    (MINIMAP, "UI-Minimap-Background"),
    (MINIMAP, 'ring:SetPoint("TOPLEFT")'),
    (WELCOME, '["1.6.1"]'),
    (CHANGELOG, "## [1.6.1]"),
    (PROGRESS, "v1.6.1"),
]
for path, needle in checks:
    if needle not in read(path):
        sys.exit("verification failed: %s missing %r" % (path, needle))

print("1.6.1 edits applied and verified")
