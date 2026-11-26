--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Market.lua
    Dynamic category demand, market events and the price a virtual item actually
    fetches today. All timers use playtime, so logging out freezes the market.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local M = {}
ns.Market = M

local EVENT_INTERVAL = 240      -- seconds of play between event rolls
local EVENT_CHANCE = 0.42
local DRIFT_INTERVAL = 300      -- seconds of play between slow price drifts
local MAX_EVENTS = 2

function M.Index(category)
    local db = DB.Get()
    return tonumber(db.market.idx[category]) or 1.0
end

function M.EventMultiplier(category)
    local db = DB.Get()
    local multiplier = 1.0
    for _, active in ipairs(db.market.events) do
        local def = ns.Data.MarketEventByKey[active.key]
        local effect = def and def.effect and def.effect[category]
        if effect then multiplier = multiplier * effect end
    end
    return multiplier
end

function M.Multiplier(category)
    if not category then return 1.0 end
    return U.clamp(M.Index(category) * M.EventMultiplier(category), 0.45, 2.4)
end

function M.Value(record)
    if not record then return 0 end
    return ns.Data.MarketValue(record, M.Multiplier(record.category))
end

function M.ValueRange(record)
    local value = M.Value(record)
    return math.max(1, U.floor(value * 0.9)), U.floor(value * 1.1)
end

function M.Prune()
    local db = DB.Get()
    local now = db.stats.playtime or 0
    local kept = {}
    for _, active in ipairs(db.market.events) do
        if (tonumber(active.untilPlay) or 0) > now then
            kept[#kept + 1] = active
        end
    end
    db.market.events = kept
    return kept
end

function M.Active()
    local db = DB.Get()
    M.Prune()
    local now = db.stats.playtime or 0
    local list = {}
    for _, active in ipairs(db.market.events) do
        local def = ns.Data.MarketEventByKey[active.key]
        if def then
            list[#list + 1] = {
                key = def.key,
                name = def.name,
                description = def.description,
                icon = def.icon,
                remaining = math.max(0, math.floor((active.untilPlay or now) - now)),
                effect = def.effect,
            }
        end
    end
    return list
end

function M.StartEvent(key)
    local db = DB.Get()
    local def
    if key then
        def = ns.Data.MarketEventByKey[key]
    else
        def = ns.Data.MarketEventPick(db.tier)
    end
    if not def then return nil end

    M.Prune()
    for _, active in ipairs(db.market.events) do
        if active.key == def.key then
            active.untilPlay = (db.stats.playtime or 0) + 300
            return def
        end
    end

    if #db.market.events >= MAX_EVENTS then
        table.remove(db.market.events, 1)
    end

    local duration = U.randomInt(def.duration[1], def.duration[2])
    db.market.events[#db.market.events + 1] = {
        key = def.key,
        startedPlay = db.stats.playtime or 0,
        untilPlay = (db.stats.playtime or 0) + duration,
    }

    if ns.History then
        ns.History.Add({ kind = "market", text = "Market event began: " .. def.name, icon = def.icon })
    end
    return def
end

function M.StopEvent(key)
    local db = DB.Get()
    local kept = {}
    for _, active in ipairs(db.market.events) do
        if active.key ~= key then kept[#kept + 1] = active end
    end
    db.market.events = kept
end

function M.Tick(dt)
    local db = DB.Get()

    M.Prune()

    db.market.drift = (db.market.drift or 0) + dt
    if db.market.drift >= DRIFT_INTERVAL then
        db.market.drift = db.market.drift - DRIFT_INTERVAL
        for _, category in ipairs(ns.Data.Categories) do
            local current = db.market.idx[category.key] or 1.0
            current = current + U.randomBetween(-0.045, 0.045)
            db.market.idx[category.key] = U.clamp(current, 0.82, 1.26)
        end
    end

    db.market.lastEventAt = (db.market.lastEventAt or 0) + dt
    if db.market.lastEventAt >= EVENT_INTERVAL then
        db.market.lastEventAt = 0
        if #db.market.events < MAX_EVENTS and U.chance(EVENT_CHANCE) then
            M.StartEvent()
        end
    end
end

function M.Summary()
    local db = DB.Get()
    local cheapest, priciest
    for _, category in ipairs(ns.Data.Categories) do
        local multiplier = M.Multiplier(category.key)
        if not cheapest or multiplier < cheapest.multiplier then
            cheapest = { key = category.key, name = category.name, multiplier = multiplier }
        end
        if not priciest or multiplier > priciest.multiplier then
            priciest = { key = category.key, name = category.name, multiplier = multiplier }
        end
    end
    return {
        cheapest = cheapest,
        priciest = priciest,
        events = M.Active(),
    }
end
