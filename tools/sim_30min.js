#!/usr/bin/env node
/*
 * 30-minute progression probe. Loads the real addon under the WoW mock, runs
 * 1800 one-second ticks with a simple shop policy, and prints snapshots.
 * This is a tuning aid, not a shipping artifact.
 */
const fs = require("fs");
const path = require("path");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const addonPath = path.join(__dirname, "..", "addon", "GoblinPawnStars");
const tocPath = path.join(addonPath, "GoblinPawnStars.toc");

function tocFiles() {
  return fs
    .readFileSync(tocPath, "utf8")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"))
    .map((line) => line.replace(/\\/g, path.sep));
}

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function check(status, context) {
  if (status !== lua.LUA_OK) {
    console.error(`${context}: ${lua.lua_tojsstring(L, -1)}`);
    process.exit(1);
  }
}

function runFile(file, chunkName) {
  const source = fs.readFileSync(file, "utf8");
  const status = lauxlib.luaL_loadbuffer(
    L,
    to_luastring(source),
    null,
    to_luastring(chunkName)
  );
  check(status, `load ${chunkName}`);
  lua.lua_pushstring(L, to_luastring("GoblinPawnStars"));
  lua.lua_getglobal(L, to_luastring("__NS"));
  check(lua.lua_pcall(L, 2, 0, 0), `run ${chunkName}`);
  lua.lua_settop(L, 0);
}

runFile(path.join(__dirname, "mock_wow.lua"), "mock_wow.lua");
runFile(path.join(__dirname, "ns_init.lua"), "ns_init.lua");
for (const relative of tocFiles()) {
  runFile(path.join(addonPath, relative), relative);
}
runFile(path.join(__dirname, "sim_30min.lua"), "sim_30min.lua");

lua.lua_getglobal(L, to_luastring("__sim30"));
check(lua.lua_pcall(L, 0, 1, 0), "simulation");
console.log(lua.lua_tojsstring(L, -1));

lua.lua_getglobal(L, to_luastring("__sim_idle"));
check(lua.lua_pcall(L, 0, 1, 0), "idle simulation");
console.log(lua.lua_tojsstring(L, -1));
