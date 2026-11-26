--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Wholesaler.lua
    The supply side of the idle loop. Lots cost Goblin Credits up front and
    become virtual stock; profit only exists when a customer buys a unit.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local W = {}
ns.Wholesaler = W

local LOT_COUNT = 3
local RESTOCK = 240
local FAST_RESTOCK = 60

local function ensureState()
    local db = DB.Get()
    if type(db.shop) ~= "table" then db.shop = {} end
    local state = db.shop.wholesale
    if type(state) ~= "table" then
        state = {}
        db.shop.wholesale = state
    end
    if type(state.lots) ~= "table" then state.lots = {} end
    state.nextRestock = tonumber(state.nextRestock) or 0
    state.restocks = tonumber(state.restocks) or 0
    return state
end

local function rollQuality(tier)
    local roll = math.random()
    if roll < 0.06 + tier * 0.02 then return 3 end
    if roll < 0.36 + tier * 0.02 then return 2 end
    return 1
end

local function makeLot(template, position)
    local db = DB.Get()
    local tier = math.max(1, tonumber(db.tier) or 1)
    local quality = rollQuality(tier)
    local ilvl = math.max(2, (template.ilvl or 8) + (tier - 1) * 12 + math.random(-3, 4))
    local count = math.min(16, math.random(4, 6 + tier * 2))

    local info = {
        name = template.itemName,
        icon = template.icon,
        quality = quality,
        ilvl = ilvl,
        classID = template.classID,
        subclassID = template.subclassID,
        category = template.category,
        description = "Bulk stock from a supplier with no questions and worse paperwork.",
    }
    info.value = ns.Data.BaseValue(info)

    -- Price against the live, stack-discounted retail value so a lot bought
    -- during a demand spike is genuinely more expensive.
    local sample = { value = info.value, count = count, category = template.category }
    local unitRetail = ns.Market.Value(sample)
    local retail = math.max(1, unitRetail * count)
    local factor = U.clamp(0.34 - (tier - 1) * 0.01, 0.30, 0.34)
    local cost = math.max(1, U.floor(retail * factor))

    return {
        position = position,
        key = template.key,
        name = template.lotName,
        itemName = template.itemName,
        icon = template.icon,
        category = template.category,
        quality = quality,
        ilvl = ilvl,
        count = count,
        unitValue = info.value,
        retail = retail,
        cost = cost,
        info = info,
        bought = false,
    }
end

function W.Restock()
    local state = ensureState()
    local pool = {}
    for _, template in ipairs(ns.Data.Wholesale or {}) do
        pool[#pool + 1] = template
    end

    for position = #pool, 2, -1 do
        local swap = math.random(position)
        pool[position], pool[swap] = pool[swap], pool[position]
    end

    local lots = {}
    for position = 1, math.min(LOT_COUNT, #pool) do
        lots[position] = makeLot(pool[position], position)
    end
    state.lots = lots
    state.nextRestock = RESTOCK
    state.restocks = (state.restocks or 0) + 1
    return lots
end

function W.Ensure()
    local state = ensureState()
    if #state.lots == 0 then W.Restock() end
    return state
end

function W.Lots()
    local state = W.Ensure()
    return state.lots, state
end

function W.TimeLeft()
    local state = ensureState()
    return math.max(0, math.floor(state.nextRestock or 0))
end

function W.Tick(dt)
    local state = ensureState()
    if #state.lots == 0 then
        W.Restock()
        return
    end

    state.nextRestock = (state.nextRestock or 0) - (tonumber(dt) or 0)
    if state.nextRestock <= 0 then
        W.Restock()
    end
end

function W.Buy(index)
    local db = DB.Get()
    local state = W.Ensure()
    local lot = state.lots[tonumber(index) or 0]
    if not lot then return false, "That lot is already gone." end
    if lot.bought then return false, "That lot has been sold." end
    if (db.credits or 0) < lot.cost then
        return false, string.format("You need %s more Goblin Credits.", U.comma(lot.cost - (db.credits or 0)))
    end
    if ns.Inventory.Free() < 1 then return false, "There is no shelf space for another stack." end

    local record, err = ns.Inventory.Add(lot.info, {
        count = lot.count,
        forceNew = true,
        source = "wholesale",
    })
    if not record then return false, err or "The lot could not be unloaded." end

    if not ns.Shop.Charge(lot.cost, "wholesale") then
        -- Should be unreachable after the credits check, but never keep free stock.
        ns.Inventory.Remove(record.uid, record.count)
        return false, "Not enough Goblin Credits."
    end

    lot.bought = true
    db.stats.wholesaleSpent = (db.stats.wholesaleSpent or 0) + lot.cost
    db.stats.wholesaleBought = (db.stats.wholesaleBought or 0) + 1

    ns.History.Add({
        kind = "purchase",
        text = string.format("Bought %s from the wholesaler", lot.name),
        amount = -lot.cost,
        icon = lot.icon,
        detail = string.format("%d units · estimated retail %s gc", lot.count, U.comma(lot.retail)),
    })

    local allBought = true
    for _, entry in ipairs(state.lots) do
        if not entry.bought then allBought = false break end
    end
    if allBought then
        state.nextRestock = math.min(state.nextRestock or FAST_RESTOCK, FAST_RESTOCK)
    end

    if ns.Achievements then ns.Achievements.Check() end
    return true, record
end

-- A tiny opening crate so a brand-new shop can make its first sale without
-- requiring the player to leave and loot first. It contains stock, not credits.
function W.GrantStarter()
    local db = DB.Get()
    if db.settings.starterGranted then return false end
    db.settings.starterGranted = true

    if ns.Inventory.Count() > 0 then return false end

    local items = {
        {
            name = "Tarnished Brass Lamp",
            icon = "Interface\\Icons\\INV_Misc_Orb_03",
            quality = 1,
            ilvl = 6,
            classID = 15,
            subclassID = 0,
            category = "misc",
            description = "The starter crate's finest piece. The shade is optional.",
        },
        {
            name = "Chipped Iron Dagger",
            icon = "Interface\\Icons\\INV_Weapon_ShortBlade_01",
            quality = 1,
            ilvl = 7,
            classID = 2,
            subclassID = 7,
            category = "weapon",
            description = "It has seen one fight and lost it.",
        },
    }

    for _, info in ipairs(items) do
        info.value = ns.Data.BaseValue(info)
        ns.Inventory.Add(info, { forceNew = true, source = "starter" })
    end

    ns.History.Add({
        kind = "system",
        text = "A departing trader left a starter crate on the counter.",
        amount = 0,
    })
    return true
end
