--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Throughput.lua
    A rolling three-minute view of the shop's actual output. Only completed
    sales feed it, so the rate always reflects stock that was really consumed.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local DB = ns.DB
local T = {}
ns.Throughput = T

local WINDOW = 180
local BUCKET = 30
local BUCKETS = 6

local buckets = {}
local index = 1
local bucketAge = 0
local elapsed = 0

local function resetBuckets()
    buckets = {}
    for position = 1, BUCKETS do
        buckets[position] = { credits = 0, sales = 0 }
    end
    index = 1
    bucketAge = 0
    elapsed = 0
end

resetBuckets()

function T.Reset()
    resetBuckets()
end

function T.RecordSale(price)
    price = math.max(0, tonumber(price) or 0)
    local bucket = buckets[index]
    bucket.credits = bucket.credits + price
    bucket.sales = bucket.sales + 1
end

function T.Tick(dt)
    dt = tonumber(dt) or 0
    if dt <= 0 then return end

    elapsed = math.min(WINDOW, elapsed + dt)
    bucketAge = bucketAge + dt
    while bucketAge >= BUCKET do
        bucketAge = bucketAge - BUCKET
        index = index % BUCKETS + 1
        buckets[index] = { credits = 0, sales = 0 }
    end
end

local function totals()
    local credits, sales = 0, 0
    for _, bucket in ipairs(buckets) do
        credits = credits + bucket.credits
        sales = sales + bucket.sales
    end
    return credits, sales
end

-- Use a minimum denominator so the first sale after login is not reported as
-- 60 credits per minute.
function T.Rates()
    local credits, sales = totals()
    local seconds = math.max(30, elapsed)
    return (credits / seconds) * 60, (sales / seconds) * 60
end

function T.CreditsPerMinute()
    local credits = T.Rates()
    return credits
end

function T.CustomersPerMinute()
    local _, sales = T.Rates()
    return sales
end
