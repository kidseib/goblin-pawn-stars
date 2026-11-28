// One-shot delivery script: version 1.7.10, its changelog entry and the release copy.
const fs = require('fs');

function edit(path, pairs) {
  let text = fs.readFileSync(path, 'utf8');
  for (const pair of pairs) {
    const oldText = pair[0];
    const newText = pair[1];
    const want = pair.length > 2 ? pair[2] : 1;
    const parts = text.split(oldText);
    const found = parts.length - 1;
    if (found !== want) {
      throw new Error(path + ': expected ' + want + ' for ' +
        JSON.stringify(oldText.slice(0, 70)) + ', found ' + found);
    }
    text = parts.join(newText);
  }
  fs.writeFileSync(path, text);
  console.log('edited ' + path);
}

const entry = `## [1.7.10] — 2026-11-28

Saving to the macro journal works on a shop that has actually been played, and a save
that hits a full macro list, a name collision or an oversized payload now lands instead
of failing for the rest of the character's life. No gameplay, visual or economy changes.

### Fixed

- **The live \`save error\`.** \`Could not save progress to the macro journal: journal is
  too large, even without stock\` refused every save on a small, early shop. One
  generation holds 2,520 base64 characters and the trim could only shed stock, while a
  played shop spent 91% of that budget on field names alone (2,292 characters with no
  stock at all). The payload now packs the stat, settings and market-event sections as
  ordered value arrays, so a played shop with a full stockroom fits: 2,580 -> 2,276
  characters, with 244 to spare and nothing trimmed.
- **A full macro list.** The in-place fallback only ran when \`GetNumMacros()\` reported
  36 or more, a hardcoded guess at the client's limit. It now triggers on the refusal
  itself, rewrites the generation the journal already owns, and never creates a new
  name when none is free.
- **A name collision.** A player macro called \`GPSB01\` used to fail every save with
  \`macro name collision on GPSB01\`. A collision on the new generation is treated exactly
  like a full list; the player's macro is never touched.
- **An oversized payload.** \`journal is too large, even without stock\` was terminal.
  The snapshot now sheds its optional halves in a fixed order - stock, the museum list,
  then cosmetic settings - and still saves credits, tier, stats, campaign and inventory
  essentials.
- **A failed save left its chunks behind.** An abandoned save now sweeps the generation
  it wrote, so a full list can always be retried.

### Changed

- The header and \`/gps journal\` say **\`load error\`** or **\`save error\`**, never both:
  a refused read and a refused write need different fixes.
- Journal payloads carry \`format = 3\`. Payloads written by earlier builds still load, and
  missing positions keep their schema default.

### Verified

- 65 headless tests, \`npm run check\` and \`npm test\` at exit 0 from a clean clone. The new
  tests each fail on the previous loader/encoder. **Not run in the live client.**

`;

edit('addon/GoblinPawnStars/GoblinPawnStars.toc', [
  ['## Version: 1.7.9', '## Version: 1.7.10'],
]);
edit('addon/GoblinPawnStars/Core/Bootstrap.lua', [
  ['ns.VERSION = "1.7.9"', 'ns.VERSION = "1.7.10"'],
]);
edit('package.json', [
  ['"version": "1.7.9"', '"version": "1.7.10"'],
]);
edit('CHANGELOG.md', [
  ['## [1.7.9] — 2026-11-27', entry + '## [1.7.9] — 2026-11-27'],
]);

// The three living documents describe the current release, so their version
// references move together; CHANGELOG history stays as written.
for (const path of ['README.md', 'TESTING.md', 'docs/curseforge/description.md']) {
  let text = fs.readFileSync(path, 'utf8');
  text = text.split('1.7.9').join('1.7.10');
  fs.writeFileSync(path, text);
  console.log('retargeted ' + path);
}

edit('README.md', [
  [`> **1.7.10** brings the saved-shop load back at login with a hard cap of four reads
> and no retry chains, lets **Settings → Auto-load** turn it off, keeps **Settings →
> Backup & Restore → Load saved** as the recovery path, and spreads every macro write
> and delete across ticks so a save can never stall a frame. **1.7.8** added one-click **Performance mode**, arrival-card
> aggregation and rolling \`/gps profile\` timings. See the
> [release notes](https://github.com/kidseib/goblin-pawn-stars/releases/tag/v1.7.10)
> for the full patch notes.`,
  `> **1.7.10** fixes the journal save failure reported after a few hours of play: the
> payload now packs the stat and setting sections by position, so a played shop with a
> full stockroom fits one macro generation again, and a save that meets a full macro
> list, a name collision or an oversized payload degrades to a smaller save instead of
> failing for good. **1.7.9** made the login load bounded and spread every macro write
> across ticks. See the
> [release notes](https://github.com/kidseib/goblin-pawn-stars/releases/tag/v1.7.10)
> for the full patch notes.`],
  [`attached to the same release. The published \`GoblinPawnStars-1.7.10.zip\` is
3,336,136 bytes with SHA-256
\`c116e68c371e6c6e1e221d02b69bbebc097e47ed3b3bd7a8aad8891e7bc2b006\`.`,
  `attached to the same release: it holds the exact size and SHA-256 of the published
\`GoblinPawnStars-1.7.10.zip\`, and the release notes repeat them.`],
]);

edit('docs/curseforge/description.md', [
  [`*   **Your save loads itself, four times at most.** A login reads the macro journal at most four times, two to thirty seconds apart, then settles — one counter, no retry chains. While it runs the header says \`loading saved shop\` and every save is refused, so a fresh session can never stamp a new shop over a run it has not read. **Settings → Auto-load** turns it off, and **Settings → Backup & Restore → Load saved** (press it twice) loads a run by hand at any time.
*   **Saves no longer touch the frame.** A journal save is now written one macro at a time, a few milliseconds a second, instead of the whole generation in a single frame. A big stockroom used to hitch; now the save spreads invisibly over a few seconds. The commit header still goes last, so an interrupted save still leaves your previous run intact.
*   **No more retry storm.** A journal that would not assemble used to schedule three more full macro reads from every failed attempt — enough macro work to stall the client. Every load is now one read that tells you what went wrong, and the login load stops after its fourth attempt.
*   **Everything else stayed put.** No economy, arrival, stock or haggling changes.`,
  `*   **The save error is fixed.** \`Could not save progress to the macro journal: journal is too large, even without stock\` could hit a small, early shop and then refused every later save. A played shop was spending 91% of the journal's 2,520-character budget on field names alone. The payload now packs the stats, settings and market events by position, so a shop with a full stockroom saves with room to spare — and nothing has to be thrown away to make it fit.
*   **A save always finds a way to land.** If every macro slot is taken, if one of your own macros happens to sit on a journal name, or if the payload is larger than one generation, the save now rewrites the copy it already owns and keeps credits, tier, stats, campaign and stock instead of failing for the rest of the character's life.
*   **Failing saves no longer leave debris.** A save that cannot finish clears the chunks it wrote, so the next attempt has room, and your own macros are never touched or overwritten.
*   **Load and save errors are told apart.** The header and \`/gps journal\` now say \`load error\` or \`save error\`, so a refused read is no longer reported as a failed save.
*   **Everything else stayed put.** No economy, arrival, stock, haggling or visual changes.`],
  [`SHA-256 for **GoblinPawnStars-1.7.10.zip** (3,336,136 bytes):

\`c116e68c371e6c6e1e221d02b69bbebc097e47ed3b3bd7a8aad8891e7bc2b006\``,
  `The exact size and SHA-256 of **GoblinPawnStars-1.7.10.zip** are in the file
\`GoblinPawnStars-1.7.10.zip.sha256\`, attached to the release next to the ZIP, and
repeated in its release notes.`],
  [`Until then, compare the SHA-256 above with the [1.7.10 release notes](https://github.com/kidseib/goblin-pawn-stars/releases/tag/v1.7.10), or read the source: the addon is plain Lua.`,
   `Until then, compare the SHA-256 with the [1.7.10 release notes](https://github.com/kidseib/goblin-pawn-stars/releases/tag/v1.7.10), or read the source: the addon is plain Lua.`],
]);

console.log('version 1.7.10 applied');
