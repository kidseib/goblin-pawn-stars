#!/usr/bin/env node
/*
 * Headless test runner.
 *
 * Loads every file listed in the TOC into a real Lua VM (fengari) with a mocked
 * WoW API, then runs ns.Diagnostics.Run(). This exercises the actual addon code
 * — inventory, market, negotiation, encounters, achievements, serialization and
 * the UI build path — without the game client.
 *
 * The mock is not the game. Anything that depends on real Blizzard frames,
 * textures or item data still needs an in-game pass.
 */
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const addonPath = path.join(__dirname, "..", "addon", "GoblinPawnStars");
const tocPath = path.join(addonPath, "GoblinPawnStars.toc");

function tocFiles() {
  const toc = fs.readFileSync(tocPath, "utf8");
  return toc
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"))
    .map((line) => line.replace(/\\/g, path.sep));
}

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function check(status, context) {
  if (status !== lua.LUA_OK) {
    const message = lua.lua_tojsstring(L, -1);
    lua.lua_settop(L, 0);
    console.error(`${context}: ${message}`);
    process.exit(1);
  }
}

function runFile(file, chunkName, pushArgs) {
  const source = fs.readFileSync(file, "utf8");
  const status = lauxlib.luaL_loadbuffer(
    L,
    to_luastring(source),
    null,
    to_luastring(chunkName)
  );
  check(status, `load ${chunkName}`);
  let args = 0;
  if (pushArgs) {
    args = 2;
    lua.lua_pushstring(L, to_luastring("GoblinPawnStars"));
    lua.lua_getglobal(L, to_luastring("__NS"));
  }
  const callStatus = lua.lua_pcall(L, args, 0, 0);
  check(callStatus, `run ${chunkName}`);
  lua.lua_settop(L, 0);
}

// Shared namespace used as the addon's vararg.
runFile(path.join(__dirname, "mock_wow.lua"), "mock_wow.lua", false);
runFile(path.join(__dirname, "..", "tools", "ns_init.lua"), "ns_init.lua", false);

const files = tocFiles();
for (const relative of files) {
  const full = path.join(addonPath, relative);
  if (!fs.existsSync(full)) {
    console.error(`TOC references a missing file: ${relative}`);
    process.exit(1);
  }
  runFile(full, relative, true);
}

lua.lua_getglobal(L, to_luastring("__report"));
const status = lua.lua_pcall(L, 0, 2, 0);
if (status !== lua.LUA_OK) {
  console.error(`diagnostics failed: ${lua.lua_tojsstring(L, -1)}`);
  process.exit(1);
}

let failures = lua.lua_tonumber(L, -1);
const report = lua.lua_tojsstring(L, -2);
console.log(report);
lua.lua_settop(L, 0);

// UI smoke pass: build every tab and overlay with mocked widgets.
runFile(path.join(__dirname, "smoke_ui.lua"), "smoke_ui.lua", false);
lua.lua_getglobal(L, to_luastring("__smoke"));
const smokeStatus = lua.lua_pcall(L, 0, 2, 0);
if (smokeStatus !== lua.LUA_OK) {
  console.error(`UI smoke test failed: ${lua.lua_tojsstring(L, -1)}`);
  process.exit(1);
}
const smokeFailures = lua.lua_tonumber(L, -1);
const smokeReport = lua.lua_tojsstring(L, -2);
if (smokeFailures > 0) {
  console.error(`UI smoke failures:\n${smokeReport}`);
} else {
  console.log("UI smoke: all tabs and overlays built and refreshed.");
}
console.log(`\nLoaded ${files.length} addon files.`);
process.exit(failures > 0 || smokeFailures > 0 ? 1 : 0);
