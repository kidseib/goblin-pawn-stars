// One-shot delivery script: roll the release number from 1.7.10 to 1.8.0.
const fs = require('fs');

function edit(path, pairs) {
  let text = fs.readFileSync(path, 'utf8');
  for (const pair of pairs) {
    const oldText = pair[0];
    const newText = pair[1];
    const want = pair.length > 2 ? pair[2] : 1;
    const found = text.split(oldText).length - 1;
    if (found !== want) {
      throw new Error(path + ': expected ' + want + ' for ' +
        JSON.stringify(oldText.slice(0, 70)) + ', found ' + found);
    }
    text = text.split(oldText).join(newText);
  }
  fs.writeFileSync(path, text);
  console.log('edited ' + path);
}

edit('addon/GoblinPawnStars/GoblinPawnStars.toc', [
  ['## Version: 1.7.10', '## Version: 1.8.0'],
]);
edit('addon/GoblinPawnStars/Core/Bootstrap.lua', [
  ['ns.VERSION = "1.7.10"', 'ns.VERSION = "1.8.0"'],
]);
edit('package.json', [
  ['"version": "1.7.10"', '"version": "1.8.0"'],
]);
edit('CHANGELOG.md', [
  ['## [1.7.10] — 2026-11-28', '## [1.8.0] — 2026-11-28'],
]);

// The living documents track the current release, so the number moves with it.
for (const path of ['README.md', 'TESTING.md', 'docs/curseforge/description.md']) {
  const text = fs.readFileSync(path, 'utf8').split('1.7.10').join('1.8.0');
  fs.writeFileSync(path, text);
  console.log('retargeted ' + path);
}

edit('PROGRESS.md', [
  ['## Current state — v1.7.9\n',
   `## Current state — v1.8.0

**v1.8.0** ships the journal payload format described below: the stat, settings and
market-event sections travel as ordered value arrays, so a played shop with a full
stockroom fits one generation (2,580 -> 2,276 base64 characters, nothing trimmed) and
the live \`save error\` stops. Version numbering jumped to 1.8.0 because the payload
format changes; \`main\`, the tag and every document carry the same number.

`],
]);

console.log('version 1.8.0 applied');
