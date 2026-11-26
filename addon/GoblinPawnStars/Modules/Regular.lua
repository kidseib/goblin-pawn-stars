--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Regular.lua
    Marta Copperpin is a named regular, not a random archetype. She visits three
    times after the first debt payment. Each visit is a normal sale, so every
    credit she pays is still backed by a sold stock unit.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local DB = ns.DB
local R = {}
ns.Regular = R

local function def()
    return ns.Data.Regular
end

local function state()
    local db = DB.Get()
    if type(db.regular) ~= "table" then
        db.regular = { visits = 0, done = false, unlocked = false, nextAt = 0 }
    end
    db.regular.visits = math.max(0, math.floor(tonumber(db.regular.visits) or 0))
    return db.regular
end

function R.State()
    return state()
end

function R.Unlocked()
    local db = DB.Get()
    local record = state()
    if (db.campaign and (db.campaign.payments or 0) >= 1) then record.unlocked = true end
    return record.unlocked == true
end

function R.Done()
    return state().done == true
end

function R.Visits()
    return state().visits
end

function R.TotalVisits()
    return #def().visits
end

function R.Bonus()
    return R.Done() and (def().bonus or 0) or 0
end

function R.NextAt()
    return state().nextAt or 0
end

function R.IsPresent()
    local db = DB.Get()
    if db.shop.current and db.shop.current.regular then return true end
    for _, customer in ipairs(db.shop.waiting or {}) do
        if customer.regular then return true end
    end
    return false
end

function R.Unlock()
    local record = state()
    if record.done or record.unlocked then return false end
    record.unlocked = true
    record.nextAt = (DB.Get().stats.sales or 0) + 3
    ns.History.Add({
        kind = "story",
        text = "Marta Copperpin heard about the shop",
        amount = 0,
        detail = "She will visit after a few more sales, or you can invite her from the Deed tab.",
    })
    return true
end

function R.CanCall()
    if not R.Unlocked() then return false, "She unlocks after the first debt payment." end
    if R.Done() then return false, "Marta's story is complete." end
    if R.IsPresent() then return false, "Marta is already at the shop." end
    if ns.Inventory.Count() == 0 then return false, "You need stock for her to buy." end
    if not ns.Customers.CanAccept() then return false, "The waiting room is full." end
    return true
end

function R.NextVisitNumber()
    return math.min(R.TotalVisits(), R.Visits() + 1)
end

function R.SpawnOptions(force)
    local db = DB.Get()
    local record = state()
    if not R.Unlocked() or record.done or R.IsPresent() then return nil end
    if not force and (db.stats.sales or 0) < (record.nextAt or 0) then return nil end
    if ns.Inventory.Count() == 0 or not ns.Customers.CanAccept() then return nil end

    local visit = math.min(R.TotalVisits(), record.visits + 1)
    -- Reserve the slot as soon as she is generated. If the player rejects her,
    -- she does not immediately reappear on the next ordinary arrival.
    record.nextAt = (db.stats.sales or 0) + (visit == 1 and 8 or 15)

    return {
        name = def().name,
        race = def().race,
        class = def().class,
        occupation = def().occupation,
        personality = def().personality,
        greeting = def().greeting,
        regular = true,
        regularVisit = visit,
        rare = false,
    }
end

function R.Call()
    local canCall, reason = R.CanCall()
    if not canCall then return false, reason end
    local options = R.SpawnOptions(true)
    if not options then return false, "Marta cannot visit right now." end
    local customer, err = ns.Customers.TrySpawn(options)
    if not customer then return false, err or "Marta could not enter the shop." end
    ns.Customers.NotifyArrival(customer)
    return true, customer
end

function R.OnServed(customer)
    if not customer or not customer.regular then return false end
    local record = state()
    local visit = math.max(record.visits + 1, tonumber(customer.regularVisit) or 1)
    visit = math.min(visit, R.TotalVisits())

    local db = DB.Get()
    record.visits = visit
    db.stats.regularVisits = (db.stats.regularVisits or 0) + 1
    local beat = def().visits[visit]
    record.lastStory = beat and beat.story or nil

    ns.History.Add({
        kind = "story",
        text = string.format("Marta Copperpin, visit %d of %d", visit, R.TotalVisits()),
        amount = 0,
        detail = record.lastStory,
    })

    if visit >= R.TotalVisits() then
        record.done = true
        record.nextAt = 0
        ns.History.Add({
            kind = "story",
            text = "Marta Copperpin's story is complete",
            amount = 0,
            detail = string.format("Permanent +%d%% customer offers", math.floor((def().bonus or 0) * 100)),
        })
        if ns.UI and ns.UI.Toast then
            ns.UI.Toast("Marta's story is complete. Her referral network improves offers permanently.")
        end
    else
        record.nextAt = (db.stats.sales or 0) + (visit == 1 and 10 or 18)
        if ns.UI and ns.UI.Toast then
            ns.UI.Toast(beat and beat.title or "Marta will return.")
        end
    end

    if ns.Achievements then ns.Achievements.Check() end
    if ns.Journal then ns.Journal.SaveNow() end
    return true, visit, record.done
end
