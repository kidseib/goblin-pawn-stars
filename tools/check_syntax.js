#!/usr/bin/env node
/*
 * Lua 5.1 syntax check for every addon source file.
 * WoW uses Lua 5.1, so parsing with luaparse's 5.1 grammar catches constructs
 * that would work in Lua 5.3 but fail in the client (goto, integer division,
 * bitwise operators, \z escapes and so on).
 */
const fs = require("fs");
const path = require("path");
const parser = require("luaparse");

const root = path.join(__dirname, "..", "addon", "GoblinPawnStars");

function collect(dir, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) collect(full, out);
    else if (entry.name.endsWith(".lua")) out.push(full);
  }
  return out;
}

const files = collect(root, []).sort();
let errors = 0;
let lines = 0;

for (const file of files) {
  const code = fs.readFileSync(file, "utf8");
  lines += code.split("\n").length;
  try {
    parser.parse(code, { luaVersion: "5.1", comments: false, locations: true });
  } catch (error) {
    errors += 1;
    const relative = path.relative(process.cwd(), file);
    console.error(`${relative}:${error.line}:${error.column} — ${error.message}`);
  }
}

if (errors > 0) {
  console.error(`\nLua 5.1 syntax check failed: ${errors} error(s) in ${files.length} files.`);
  process.exit(1);
}

console.log(`Lua 5.1 syntax OK: ${files.length} files, ${lines} lines.`);
