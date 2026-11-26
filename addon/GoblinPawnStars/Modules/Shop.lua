--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Shop.lua
    Progression: tiers, upgrades, reputation, capacity, customer traffic,
    operating expenses, shop days and the daily customer request.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local S = {}
ns.Shop = S

local SHOP_DAY = 900 -- 15 minutes of playtime between shop days

function S.TierInfo()
    return ns.Data.Tier(DB.Get().tier)
end

function S.Tier()
    return DB.Get().tier
end

function S.NextTier()
    return ns.Data.NextTier(DB.Get().tier)
end

function S.Bonuses()
    local db = DB.Get()
    local fx = {
        storage = 0, arrival = 0, appraisal = 0, haggle = 0, rare = 0,
        expense = 0, theft = 0, waiting = 0, patience = 0, offer = 0,
        repGain = 0, forgery = 0, autosale = 0,
    }

    for key, level in pairs(db.upgrades) do
        local def = ns.Data.UpgradeByKey[key]
        if def and def.fx then
            for stat, value in pairs(def.fx) do
                fx[stat] = (fx[stat] or 0) + value * (tonumber(level) or 0)
            end
        end
    end

    for key, level in pairs(db.employees) do
        local def = ns.Data.EmployeeByKey[key]
        if def and def.fx then
            for stat, value in pairs(def.fx) do
                fx[stat] = (fx[stat] or 0) + value * (tonumber(level) or 0)
            end
        end
    end

    return fx
end

function S.Appraisal()
    local tier = S.TierInfo()
    return U.clamp((tier.appraisal or 25) + (S.Bonuses().appraisal or 0), 10, 99)
end

function S.RareChance()
    local tier = S.TierInfo()
    return U.clamp((tier.rareChance or 0) + (S.Bonuses().rare or 0), 0, 0.6)
end

function S.WaitingSlots()
    local tier = S.TierInfo()
    local base = 2 + math.floor((tier.tier - 1) / 2)
    return math.max(2, math.floor(base + (S.Bonuses().waiting or 0) + 0.001))
end

function S.ArrivalInterval()
    local tier = S.TierInfo()
    local interval = (tier.arrival or 110) - (S.Bonuses().arrival or 0)
    return U.clamp(interval, 8, 300)
end

function S.BaseBudget()
    return S.TierInfo().budget or 280
end

function S.Reputation()
    return DB.Get().reputation or 0
end

-- Reputation nudges what customers believe you are worth.
function S.ReputationFactor()
    return 0.88 + math.min(0.22, (S.Reputation() / 1000) * 0.22)
end

function S.AddReputation(amount)
    local db = DB.Get()
    local gain = (tonumber(amount) or 0) * (1 + (S.Bonuses().repGain or 0))
    db.reputation = U.clamp((db.reputation or 0) + gain, 0, 1000)
    return db.reputation
end

function S.ReputationLabel()
    local rep = S.Reputation()
    if rep >= 800 then return "Legendary", "|cffff8000" end
    if rep >= 500 then return "Trusted", "|cffa335ee" end
    if rep >= 250 then return "Respected", "|cff0070dd" end
    if rep >= 100 then return "Known", "|cff1eff00" end
    return "Nobody", "|cff9d9d9d"
end

function S.Credits()
    return DB.Get().credits or 0
end

function S.Charge(amount, kind)
    local db = DB.Get()
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if (db.credits or 0) < amount then return false end
    db.credits = db.credits - amount
    if kind ~= "expense" then
        db.stats.spent = (db.stats.spent or 0) + amount
    end
    return true
end

function S.Earn(amount)
    local db = DB.Get()
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    db.credits = (db.credits or 0) + amount
    db.stats.earned = (db.stats.earned or 0) + amount
    return amount
end

function S.DailyExpenses()
    local tier = S.TierInfo()
    local rent = 18 + tier.tier * 32
    local wages = ns.Staff.TotalWages()
    local discount = 1 - math.min(0.7, S.Bonuses().expense or 0)
    return math.max(0, math.floor((rent + wages) * discount))
end

function S.BuyUpgrade(key)
    local db = DB.Get()
    local def = ns.Data.UpgradeByKey[key]
    if not def then return false, "unknown upgrade" end
    if (def.minTier or 1) > db.tier then return false, "requires a bigger shop" end

    local level = db.upgrades[key] or 0
    if level >= def.maxLevel then return false, "already fully upgraded" end

    local cost = ns.Data.UpgradeCost(def, level)
    if not S.Charge(cost, "upgrade") then return false, "not enough Goblin Credits" end

    db.upgrades[key] = level + 1
    ns.History.Add({
        kind = "purchase",
        text = string.format("Upgraded %s to level %d", def.name, level + 1),
        amount = -cost,
        icon = def.icon,
    })
    S.AddReputation(2)
    ns.Achievements.Check()
    return true, cost
end

function S.UpgradeTier()
    local db = DB.Get()
    local nextTier = ns.Data.NextTier(db.tier)
    if not nextTier then return false, "already at the top tier" end
    if not S.Charge(nextTier.cost, "tier") then return false, "not enough Goblin Credits" end

    db.tier = nextTier.tier
    ns.History.Add({
        kind = "purchase",
        text = "Shop upgraded to " .. nextTier.name,
        amount = -nextTier.cost,
        icon = "Interface\\Icons\\INV_Misc_Map_01",
    })
    S.AddReputation((nextTier.reputation or 0) + 8)
    if ns.UI and ns.UI.Toast then
        ns.UI.Toast("Shop upgraded: " .. nextTier.name)
    end
    ns.Achievements.Check()
    return true, nextTier
end

function S.ExpensesPaid()
    return DB.Get().stats.expenses or 0
end

function S.PayExpenses(amount)
    local db = DB.Get()
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local paid = math.min(amount, db.credits or 0)
    db.credits = (db.credits or 0) - paid
    db.stats.expenses = (db.stats.expenses or 0) + paid
    return paid, amount - paid
end

function S.RefreshDailyRequest()
    local db = DB.Get()
    local day = U.today()
    if db.shop.requestDay == day and db.shop.request then
        db.shop.request.fulfilled = db.shop.request.fulfilled or false
        return db.shop.request
    end
    local category = ns.Data.Categories[math.random(#ns.Data.Categories)]
    db.shop.requestDay = day
    db.shop.request = {
        day = day,
        category = category.key,
        label = category.name,
        bonus = 0.12 + math.random() * 0.2,
        fulfilled = false,
    }
    return db.shop.request
end

function S.DailyRequest()
    local db = DB.Get()
    if not db.shop.request or db.shop.request.day ~= U.today() then
        return S.RefreshDailyRequest()
    end
    return db.shop.request
end

function S.EndShopDay()
    local db = DB.Get()
    db.stats.shopDays = (db.stats.shopDays or 0) + 1

    local owed = S.DailyExpenses()
    if owed > 0 then
        local paid, missed = S.PayExpenses(owed)
        local label = string.format("Shop day %d: rent and wages", db.stats.shopDays)
        ns.History.Add({ kind = "expense", text = label, amount = -paid })
        if missed > 0 then
            S.AddReputation(-6)
            ns.History.Add({
                kind = "expense",
                text = "Could not pay " .. U.comma(missed) .. " credits in full",
                amount = 0,
            })
        end
    end

    S.RefreshDailyRequest()
end

function S.Tick(dt)
    local db = DB.Get()
    db.shop.shopDayProgress = (db.shop.shopDayProgress or 0) + dt
    if db.shop.shopDayProgress >= SHOP_DAY then
        db.shop.shopDayProgress = db.shop.shopDayProgress - SHOP_DAY
        S.EndShopDay()
    end
end

function S.ShopDayProgress()
    local db = DB.Get()
    return U.clamp((db.shop.shopDayProgress or 0) / SHOP_DAY, 0, 1)
end

function S.Summary()
    local db = DB.Get()
    local stats = db.stats
    return {
        credits = db.credits,
        reputation = db.reputation,
        tier = db.tier,
        tierName = S.TierInfo().name,
        storageUsed = ns.Inventory.Count(),
        storageMax = ns.Inventory.Capacity(),
        customersWaiting = #db.shop.waiting,
        waitingSlots = S.WaitingSlots(),
        nextArrival = math.max(0, math.floor(db.shop.nextArrival or 0)),
        expenses = S.DailyExpenses(),
        sales = stats.sales or 0,
        revenue = stats.revenue or 0,
        earned = stats.earned or 0,
        bestSale = stats.bestSale or 0,
        reputationLabel = S.ReputationLabel(),
    }
end
