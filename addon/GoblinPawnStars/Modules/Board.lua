--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Board.lua
    The sidewalk A-board. Each shop day the shop may chalk one advertised
    category: every sale of it pays the placard's lift and buyers carrying it
    walk in more often. The choice is the morning's decision; the day decides
    which two lines are offered, so two players on the same day choose between
    the same pair.

    Deterministic on purpose: the placard and its lift are hashed from the day
    string and the category, exactly like Data.BaseValue hashes an item. Nothing
    here is rolled, so a reload cannot reroll a bad board and the save needs to
    remember only which line was chalked, never the number.

    Cost: one table lookup per sale, one per arrival, two fields in the save.
    No timer, no polling, no per-frame work: the day is read through U.today()
    when something asks, and a board from an earlier day simply stops counting.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local B = {}
ns.Board = B

-- Deterministic 0..1 from the shop day and the category. Same day, same line.
local function roll(day, key)
    local seed = tostring(day or "day-0") .. "|" .. tostring(key or "?")
    return (U.hash(seed) % 1000) / 999
end

--[[ The placard a category would carry on a given day. The lift is solved from
     the data band and rounded to a half percent, so the label can state it. ]]
function B.Placard(categoryKey, day)
    if not categoryKey then return nil end
    local def = ns.Data.BoardByCategory and ns.Data.BoardByCategory[categoryKey]
    if not def then return nil end
    day = day or U.today()

    local low = tonumber(def.low) or 0
    local high = tonumber(def.high) or low
    if high < low then high = low end
    local raw = low + (high - low) * roll(day, def.category)
    local step = ns.Data.BoardStep or 0.005
    local bonus = math.floor(raw / step + 0.5) * step
    -- Guard the label: a rounded band can never state 0%.
    if bonus < step then bonus = step end

    return {
        key = def.category,
        name = ns.Data.CategoryName(def.category),
        headline = def.headline,
        blurb = def.blurb,
        icon = ns.Data.BoardIcon(def.category),
        bonus = bonus,
        percent = math.floor(bonus * 100 + 0.5),
        day = day,
    }
end

--[[ Categories with stock, sorted by key so the pair is stable while the
     shelves are. One pass over the inventory, which the dashboard refresh and
     the arrival pick already do elsewhere. ]]
local function stockedKeys()
    local db = DB.Get()
    local keys, seen = {}, {}
    for _, record in pairs(db.inventory or {}) do
        local key = record and record.category
        if key and not seen[key] and ns.Data.BoardByCategory[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    return keys
end

--[[ Today's two placards: a rotation over the categories you actually stock,
     stepped by the day. No stock means no board — the sign cannot advertise
     something that is not on the shelves. ]]
function B.Candidates(day)
    day = day or U.today()
    local keys = stockedKeys()
    local total = #keys
    if total == 0 then return {} end

    local out = {}
    local start = U.hash(day) % total + 1
    for offset = 0, math.min(1, total - 1) do
        local placard = B.Placard(keys[(start - 1 + offset) % total + 1], day)
        if placard then out[#out + 1] = placard end
    end
    return out
end

--[[ The chalked board, or nil. A board from an earlier shop day is ignored:
     that is the whole expiry rule, and it costs one string compare. ]]
function B.Active()
    local db = DB.Get()
    local saved = db.shop and db.shop.board
    if type(saved) ~= "table" then return nil end
    if type(saved.key) ~= "string" then return nil end
    local day = U.today()
    if saved.day ~= day then return nil end
    return B.Placard(saved.key, day)
end

--[[ Chalk a line. Only a line that is on today's board may be written, and only
     once a day: this is the one decision the board asks for. Returns the
     placard so the caller can celebrate it. ]]
function B.Chalk(key)
    if B.Active() then
        return false, "The board is already written for today."
    end
    local offered = nil
    for _, placard in ipairs(B.Candidates()) do
        if placard.key == key then offered = placard break end
    end
    if not offered then
        return false, "That line is not on today's board."
    end

    local db = DB.Get()
    db.shop.board = { day = offered.day, key = offered.key }
    return true, offered
end

--[[ The lift a sale of this record pays right now, as a fraction. ]]
function B.Bonus(record)
    if not record then return 0 end
    local placard = B.Active()
    if not placard or placard.key ~= record.category then return 0 end
    return placard.bonus
end

--[[ Multiplier for the arrival interval while the board is chalked. Footfall,
     not assortment: the sign brings people in and never decides what they
     carry, so an advertised cheap line cannot crowd out the valuable stock. ]]
function B.Traffic()
    if not B.Active() then return 1 end
    return tonumber(ns.Data.BoardTraffic) or 0.88
end
