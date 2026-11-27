--[[ Goblin Pawn Stars -------------------------------------------------------
    Core/Perf.lua
    Session-only rolling timings for the operations that can stall a frame.
    Samples are taken only when the operation actually runs; there is no frame
    script and no polling loop. /gps profile prints the last and maximum value.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local P = {}
ns.Perf = P

P.metrics = {}

-- GetTime is the same millisecond clock the journal and profile already use.
local function now()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    if not ok or not tonumber(value) then return nil end
    return tonumber(value) * 1000
end

P.Now = now

local function store(key, ms, label)
    local metric = P.metrics[key]
    if not metric then
        metric = { last = 0, max = 0, count = 0 }
        P.metrics[key] = metric
    end
    metric.last = ms
    if ms > metric.max then metric.max = ms end
    metric.count = metric.count + 1
    if label then metric.label = label end
    return metric
end

-- Times an operation that has already been called. Returns nil when the client
-- has no clock or the caller did not capture a start time.
function P.Record(key, started, label)
    if not started then return nil end
    local finished = now()
    if not finished then return nil end
    return store(key, math.max(0, finished - started), label)
end

-- For operations that already measured themselves, such as the journal save.
function P.RecordValue(key, ms, label)
    ms = tonumber(ms)
    if not ms or ms < 0 then return nil end
    return store(key, ms, label)
end

function P.Get(key)
    return P.metrics[key]
end

function P.Reset()
    P.metrics = {}
end
