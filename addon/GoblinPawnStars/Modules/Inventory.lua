--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Inventory.lua
    The virtual pawnshop stock. Nothing here touches the player's real bags:
    records are copies made from item IDs and never written back to the client.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local Inv = {}
ns.Inventory = Inv

local STACK_LIMIT = 20

function Inv.Capacity()
    local db = DB.Get()
    local capacity = ns.Data.Tier(db.tier).storage
    for key, level in pairs(db.upgrades) do
        local def = ns.Data.UpgradeByKey[key]
        if def and def.fx and def.fx.storage then
            capacity = capacity + def.fx.storage * (tonumber(level) or 0)
        end
    end
    return capacity
end

function Inv.Count()
    local count = 0
    for _ in pairs(DB.Get().inventory) do count = count + 1 end
    return count
end

function Inv.Free()
    return math.max(0, Inv.Capacity() - Inv.Count())
end

function Inv.Get(uid)
    return DB.Get().inventory[uid]
end

function Inv.FindByItemID(itemID, includeCounterfeit)
    for _, record in pairs(DB.Get().inventory) do
        if record.id == itemID and (includeCounterfeit or not record.counterfeit) then
            return record
        end
    end
    return nil
end

-- Adds a virtual copy. Returns the record, or nil plus a reason.
function Inv.Add(info, options)
    options = options or {}
    local db = DB.Get()
    if not info or not info.name then return nil, "unknown item" end

    local count = math.max(1, math.floor(tonumber(options.count) or 1))
    local record

    if info.id and not options.counterfeit and not options.forceNew then
        local existing = Inv.FindByItemID(info.id, false)
        if existing and existing.count < STACK_LIMIT then
            existing.count = existing.count + count
            record = existing
        end
    end

    if not record then
        if Inv.Count() >= Inv.Capacity() then
            return nil, "storage full"
        end
        local uid = db.nextUid
        db.nextUid = uid + 1
        record = {
            uid = uid,
            id = info.id,
            name = info.name,
            icon = info.icon,
            quality = tonumber(info.quality) or 1,
            ilvl = tonumber(info.ilvl) or 1,
            classID = tonumber(info.classID) or 0,
            subclassID = tonumber(info.subclassID) or 0,
            category = info.category or ns.Data.CategoryOf(info),
            value = tonumber(info.value) or ns.Data.BaseValue(info),
            count = count,
            acquired = U.now(),
            source = options.source or "loot",
            counterfeit = options.counterfeit and true or false,
            description = info.description,
        }
        db.inventory[uid] = record
    end

    db.stats.itemsCollected = (db.stats.itemsCollected or 0) + count
    return record
end

function Inv.Remove(uid, count)
    local db = DB.Get()
    local record = db.inventory[uid]
    if not record then return false end

    count = math.max(1, math.floor(tonumber(count) or 1))
    if record.count > count then
        record.count = record.count - count
        return true
    end

    db.inventory[uid] = nil

    -- Anyone waiting for this exact item loses interest and leaves.
    local waiting = {}
    for _, customer in ipairs(db.shop.waiting) do
        if customer.itemUid ~= uid then waiting[#waiting + 1] = customer end
    end
    db.shop.waiting = waiting

    if db.shop.current and db.shop.current.itemUid == uid then
        db.shop.current = nil
    end
    return true
end

function Inv.Matches(record, filter)
    filter = filter or {}
    if filter.category and filter.category ~= "all" and record.category ~= filter.category then
        return false
    end
    if filter.quality and filter.quality ~= "all" then
        if (tonumber(filter.quality) or -1) ~= (record.quality or 1) then return false end
    end
    if filter.search and filter.search ~= "" then
        local needle = U.lower(filter.search)
        local haystack = U.lower(record.name or "") .. " " .. U.lower(ns.Data.CategoryName(record.category))
        if not haystack:find(needle, 1, true) then return false end
    end
    return true
end

local SORTS = {
    name = function(a, b) return (a.name or "") < (b.name or "") end,
    rarity = function(a, b)
        if (a.quality or 0) == (b.quality or 0) then
            return (a.name or "") < (b.name or "")
        end
        return (a.quality or 0) > (b.quality or 0)
    end,
    recent = function(a, b) return (a.acquired or 0) > (b.acquired or 0) end,
    count = function(a, b) return (a.count or 1) > (b.count or 1) end,
}

function Inv.List(filter)
    filter = filter or {}
    local list = {}
    for _, record in pairs(DB.Get().inventory) do
        if Inv.Matches(record, filter) then list[#list + 1] = record end
    end

    local sortKey = filter.sort or "value"
    if SORTS[sortKey] then
        table.sort(list, SORTS[sortKey])
        return list
    end

    -- Value is the default and the fallback for an unknown sort key. Market.Value
    -- depends on demand and active events, so it is not a cheap comparator. The
    -- old value sort recalculated it several times per comparison; a large
    -- stockroom then spent a long time sorting on every inventory refresh.
    -- Resolve each stack once and sort the numbers.
    local values = {}
    for _, record in ipairs(list) do
        values[record] = ns.Market.Value(record)
    end
    table.sort(list, function(a, b)
        local av, bv = values[a], values[b]
        if av == bv then return (a.name or "") < (b.name or "") end
        return av > bv
    end)
    return list
end

function Inv.TotalMarketValue()
    local total = 0
    for _, record in pairs(DB.Get().inventory) do
        total = total + ns.Market.Value(record) * (record.count or 1)
    end
    return total
end

function Inv.RandomRecord()
    local list = {}
    for _, record in pairs(DB.Get().inventory) do list[#list + 1] = record end
    if #list == 0 then return nil end
    return list[math.random(#list)]
end

function Inv.RemoveRandom()
    local record = Inv.RandomRecord()
    if not record then return nil end
    Inv.Remove(record.uid, 1)
    return record
end

function Inv.CategoriesWithStock()
    local seen = {}
    local list = {}
    for _, record in pairs(DB.Get().inventory) do
        if not seen[record.category] then
            seen[record.category] = true
            list[#list + 1] = record.category
        end
    end
    table.sort(list)
    return list
end
