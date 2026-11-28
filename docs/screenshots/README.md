# UI render gallery

These eight 1440×900 PNGs are **HTML/CSS UI renders**, not live World of Warcraft
client captures. They are built from the addon's theme, labels and sample state to
show the intended layout and information hierarchy while the live-client visual pass
is still pending. Every image carries a "not a live-client capture" label.

| File | Screen |
| --- | --- |
| `01-dashboard.png` | Dashboard tab |
| `02-deed.png` | The Deed tab |
| `03-negotiation.png` | Negotiation window |
| `04-inventory.png` | Inventory tab |
| `05-market.png` | Market tab |
| `06-upgrades.png` | Upgrades tab |
| `07-wholesaler.png` | Wholesaler window |
| `08-settings.png` | Settings tab |

`08-settings.html` is the editable source for the Settings render: an HTML/CSS mock
built from the coordinates and labels in `UI/Tabs/Settings.lua` at the addon's
960×640 window size, scaled to 1440×900. Regenerate the PNG after a Settings layout
change by rendering that file at 1440×900 and screenshotting the viewport, then check
it against the tab labels. The other seven renders predate it and have no source in
this repository.

Delete or replace these images once real in-game screenshots are available; update
the README gallery and this note at the same time.

**1.7.9 state — `08-settings.png` is one render behind.** The file in this repository
is still the 1.7.8 Settings panel, taken before the **Auto-load** toggle and the taller
row layout. The 1.7.9 master render (587,727 bytes) is not in this repository yet: it
has to be uploaded whole, and GitHub's file API takes one file per request, so a
base64 body of about 784 KB does not fit in a single one. To finish it, render
`08-settings.html` at 1440×900, then upload the PNG from a checkout
(`git add docs/screenshots/08-settings.png && git commit -m "docs: 1.7.9 settings
render" && git push`) or with **Add file → Upload files** in the GitHub web UI, and
delete this paragraph afterwards.
