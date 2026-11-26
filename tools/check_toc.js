#!/usr/bin/env node
/*
 * TOC integrity check:
 *  - Interface is the Forever build (16001)
 *  - SavedVariables is declared
 *  - every .lua on disk is listed exactly once
 *  - every listed file exists
 */
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..", "addon", "GoblinPawnStars");
const tocPath = path.join(root, "GoblinPawnStars.toc");
const toc = fs.readFileSync(tocPath, "utf8").split(/\r?\n/);

const listed = toc
  .map((line) => line.trim())
  .filter((line) => line && !line.startsWith("#"))
  .map((line) => line.replace(/\\/g, "/"));

let errors = 0;
const fail = (message) => {
  errors += 1;
  console.error(`TOC: ${message}`);
};

if (!/^## Interface:\s*16001/m.test(toc.join("\n"))) fail("## Interface must be 16001");
if (!/^## SavedVariables:\s*GoblinPawnStarsDB/m.test(toc.join("\n"))) {
  fail("## SavedVariables: GoblinPawnStarsDB is missing");
}
if (!/^## Author:\s*ErrorSeib & Buffy/m.test(toc.join("\n"))) {
  fail("author credit missing from the TOC");
}

const duplicates = listed.filter((entry, index) => listed.indexOf(entry) !== index);
for (const entry of new Set(duplicates)) fail(`duplicate entry ${entry}`);

for (const entry of listed) {
  if (!fs.existsSync(path.join(root, entry))) fail(`missing file ${entry}`);
}

const onDisk = [];
(function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.name.endsWith(".lua")) {
      onDisk.push(path.relative(root, full).replace(/\\/g, "/"));
    }
  }
})(root);

for (const file of onDisk) {
  if (!listed.includes(file)) fail(`file not loaded by the TOC: ${file}`);
}

if (errors > 0) {
  console.error(`TOC check failed with ${errors} problem(s).`);
  process.exit(1);
}

console.log(`TOC OK: ${listed.length} files listed, all present, Interface 16001, credits set.`);
