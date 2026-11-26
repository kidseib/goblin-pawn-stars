--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Museum.lua
    One five-slot museum set. Donating consumes a real virtual stock unit, so
    the permanent offer bonus is always paid for with something the shop owned.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local DB = ns.DB
local M = {}
ns.Museum = M

local function def()
    return ns.Data.Museum
end

local function state()
    local db = DB.Get()
    if type(db.museum) ~= "table" then db.museum = { donated = {}, completed = false } end
    if type(db.museum.donated) ~= "table" then db.museum.donated = {} end
    return db.museum
end

local function validSlot(key)
    for _, slot in ipairs(def().slots) do
        if slot.key == key then return slot end
    end
    return nil
end

function M.State()
    return state()
end

function M.Unlocked()
    local db = DB.Get()
    local museum = state()
    return museum.unlocked == true
        or museum.completed == true
        or M.Count() > 0
        or (db.campaign and (db.campaign.payments or 0) >= 1) or false
end

function M.Donated(key)
    return state().donated[key]
end

function M.Count()
    local count = 0
    for _, slot in ipairs(def().slots) do
        if state().donated[slot.key] then count = count + 1 end
    end
    return count
end

function M.Total()
    return #def().slots
end

function M.Completed()
    local museum = state()
    return museum.completed == true or M.Count() >= M.Total()
end

function M.Bonus()
    return M.Completed() and (def().bonus or 0) or 0
end

-- The cheapest eligible piece is offered first so donating never quietly
-- throws away the shop's best stock.
function M.Eligible(key)
    if not M.Unlocked() or state().donated[key] then return nil end
    local slot = validSlot(key)
    if not slot then return nil end

    local best
    for _, record in pairs(DB.Get().inventory or {}) do
        if record.category == key
            and (tonumber(record.quality) or 1) >= (def().minQuality or 2)
            and not record.counterfeit then
            local value = ns.Market.Value(record)
            if not best or value < best.value then
                best = { record = record, value = value }
            end
        end
    end
    return best and best.record or nil
end

function M.Donate(key)
    local slot = validSlot(key)
    if not slot then return false, "Unknown museum slot." end
    if not M.Unlocked() then return false, "The museum unlocks after the first debt payment." end
    if state().donated[key] then return false, "That slot is already filled." end

    local record = M.Eligible(key)
    if not record then
        return false, "You need a non-counterfeit " .. tostring(slot.hint or key) .. " in stock."
    end
    if not ns.Inventory.Remove(record.uid, 1) then
        return false, "That piece is no longer in stock."
    end

    local museum = state()
    museum.donated[key] = {
        name = record.name,
        quality = record.quality,
        ilvl = record.ilvl,
        icon = record.icon,
        at = ns.Util.now(),
    }
    local db = DB.Get()
    db.stats.museumDonated = (db.stats.museumDonated or 0) + 1

    ns.History.Add({
        kind = "museum",
        text = "Donated " .. tostring(record.name) .. " to The Curious Collection",
        amount = 0,
        icon = record.icon,
        detail = slot.label,
    })

    local completed = M.Count() >= M.Total()
    if completed then
        museum.completed = true
        ns.History.Add({
            kind = "museum",
            text = "The Curious Collection is complete",
            amount = 0,
            detail = "Permanent +" .. math.floor((def().bonus or 0) * 100) .. "% customer offers",
        })
        if ns.UI and ns.UI.Toast then
            ns.UI.Toast("The Curious Collection is complete. Offers improve permanently.")
        end
    else
        if ns.UI and ns.UI.Toast then
            ns.UI.Toast(string.format("Donated %s. %d of %d slots filled.",
                record.name, M.Count(), M.Total()))
        end
    end

    if ns.Achievements then ns.Achievements.Check() end
    if ns.Journal then ns.Journal.SaveNow() end
    return true, record, completed
end
