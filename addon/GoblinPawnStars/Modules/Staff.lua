--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Staff.lua
    Hiring, promoting and paying the fictional employees.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local E = {}
ns.Staff = E

function E.Level(key)
    return tonumber(DB.Get().employees[key]) or 0
end

function E.Slots()
    return ns.Data.Tier(DB.Get().tier).employees or 0
end

function E.Count()
    local count = 0
    for _, level in pairs(DB.Get().employees) do
        if (tonumber(level) or 0) > 0 then count = count + 1 end
    end
    return count
end

function E.IsHired(key)
    return E.Level(key) > 0
end

function E.Cost(key)
    local def = ns.Data.EmployeeByKey[key]
    if not def then return math.huge end
    return ns.Data.EmployeeCost(def, E.Level(key))
end

function E.Wage(key)
    local def = ns.Data.EmployeeByKey[key]
    if not def then return 0 end
    return ns.Data.EmployeeWage(def, E.Level(key))
end

function E.TotalWages()
    local total = 0
    for key, level in pairs(DB.Get().employees) do
        local def = ns.Data.EmployeeByKey[key]
        if def then total = total + ns.Data.EmployeeWage(def, tonumber(level) or 0) end
    end
    return total
end

function E.CanHire(key)
    local def = ns.Data.EmployeeByKey[key]
    if not def then return false, "unknown role" end
    if def.minTier and def.minTier > DB.Get().tier then return false, "requires a bigger shop" end
    if E.IsHired(key) then return false, "already on the payroll" end
    if E.Count() >= E.Slots() then return false, "no free employee slots" end
    return true
end

function E.Hire(key)
    local def = ns.Data.EmployeeByKey[key]
    local ok, reason = E.CanHire(key)
    if not ok then return false, reason end

    local cost = ns.Data.EmployeeCost(def, 0)
    if not ns.Shop.Charge(cost, "hire") then return false, "not enough Goblin Credits" end

    DB.Get().employees[key] = 1
    ns.History.Add({
        kind = "purchase",
        text = "Hired " .. def.name .. " the " .. def.role,
        amount = -cost,
        icon = def.icon,
    })
    ns.Shop.AddReputation(3)
    ns.Achievements.Check()
    return true, def
end

function E.Promote(key)
    local def = ns.Data.EmployeeByKey[key]
    if not def then return false, "unknown role" end
    local level = E.Level(key)
    if level <= 0 then return false, "not hired yet" end
    if level >= (def.maxLevel or 5) then return false, "already at maximum level" end

    local cost = ns.Data.EmployeeCost(def, level)
    if not ns.Shop.Charge(cost, "employee") then return false, "not enough Goblin Credits" end

    DB.Get().employees[key] = level + 1
    ns.History.Add({
        kind = "purchase",
        text = string.format("%s promoted to level %d", def.name, level + 1),
        amount = -cost,
        icon = def.icon,
    })
    ns.Shop.AddReputation(2)
    ns.Achievements.Check()
    return true, cost
end

function E.Fire(key)
    local def = ns.Data.EmployeeByKey[key]
    if not def or not E.IsHired(key) then return false, "nobody to let go" end
    DB.Get().employees[key] = nil
    ns.History.Add({
        kind = "purchase",
        text = "Let " .. def.name .. " go. Awkward.",
        amount = 0,
        icon = def.icon,
    })
    ns.Shop.AddReputation(-5)
    return true
end

function E.Summary()
    local list = {}
    for _, def in ipairs(ns.Data.Employees) do
        local level = E.Level(def.key)
        list[#list + 1] = {
            key = def.key,
            name = def.name,
            role = def.role,
            icon = def.icon,
            level = level,
            maxLevel = def.maxLevel,
            wage = ns.Data.EmployeeWage(def, level),
            cost = ns.Data.EmployeeCost(def, level),
            hired = level > 0,
            unlocked = (def.minTier or 1) <= DB.Get().tier,
        }
    end
    return list
end
