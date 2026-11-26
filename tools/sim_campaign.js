#!/usr/bin/env node
/*
 * Campaign-length progression probe. Loads the real addon under the WoW mock,
 * plays several simulated hours with the policy in sim_campaign.lua, pays the
 * deed notes, buys tiers and upgrades, and prints time-to-milestone and
 * credits/hour per tier.
 *
 * Usage:
 *   node tools/sim_campaign.js [--hours 4] [--seeds 3] [--seed 424242]
 *                              [--accept-only] [--tier-first] [--verbose]
 *
 * Dev-only: this file is not part of the addon and is not in the TOC.
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

const args = process.argv.slice(2);

function option(name, fallback) {
  const index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) return fallback;
  return args[index + 1];
}

const hours = Number(option("--hours", "4"));
const seeds = Number(option("--seeds", "1"));
const seed = Number(option("--seed", "424242"));
const haggle = !args.includes("--accept-only");
const greedyTier = args.includes("--tier-first");
const verbose = args.includes("--verbose") || seeds === 1;

if (!Number.isFinite(hours) || hours <= 0) {
  console.error("--hours must be a positive number");
  process.exit(2);
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
  let argv = 0;
  if (pushArgs) {
    argv = 2;
    lua.lua_pushstring(L, to_luastring("GoblinPawnStars"));
    lua.lua_getglobal(L, to_luastring("__NS"));
  }
  check(lua.lua_pcall(L, argv, 0, 0), `run ${chunkName}`);
  lua.lua_settop(L, 0);
}

function runChunk(source, chunkName) {
  const status = lauxlib.luaL_loadbuffer(
    L,
    to_luastring(source),
    null,
    to_luastring(chunkName)
  );
  check(status, `load ${chunkName}`);
  check(lua.lua_pcall(L, 0, 0, 0), `run ${chunkName}`);
  lua.lua_settop(L, 0);
}

runFile(path.join(__dirname, "mock_wow.lua"), "mock_wow.lua", false);
runFile(path.join(__dirname, "ns_init.lua"), "ns_init.lua", false);
for (const relative of tocFiles()) {
  runFile(path.join(addonPath, relative), relative, true);
}

runChunk(
  `__SIM_OPTS = { hours = ${hours}, seeds = ${seeds}, seed = ${seed}, ` +
    `haggle = ${haggle}, greedyTier = ${greedyTier}, verbose = ${verbose} }`,
  "sim_opts.lua"
);
runFile(path.join(__dirname, "sim_campaign.lua"), "sim_campaign.lua", false);

lua.lua_getglobal(L, to_luastring("__campaign"));
check(lua.lua_pcall(L, 0, 1, 0), "campaign simulation");
console.log(lua.lua_tojsstring(L, -1));
