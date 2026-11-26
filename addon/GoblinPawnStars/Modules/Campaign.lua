--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Campaign.lua
    The Deed: three fixed payments to the Bilgewater Cartel, an ending choice,
    endless mode and a franchise reset that keeps museum, Marta and achievements.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local C = {}
ns.Campaign = C

local function def()
    return ns.Data.Deed
end

local function state()
    local db = DB.Get()
    if type(db.campaign) ~= "table" then
        db.campaign = C.NewState()
    end
    return db.campaign
end

function C.State()
    return state()
end

function C.NewState()
    return {
        payments = 0,
        paid = 0,
        completed = false,
        mode = "campaign",
        ending = nil,
        startedAt = U.now(),
    }
end

function C.Payments()
    return state().payments or 0
end

function C.Completed()
    return state().completed == true
end

function C.Mode()
    return state().mode or "campaign"
end

function C.NextPayment()
    if C.Completed() then return nil end
    return def().payments[C.Payments() + 1]
end

function C.Total()
    return def().total or 0
end

function C.Paid()
    return state().paid or 0
end

function C.Remaining()
    return math.max(0, C.Total() - C.Paid())
end

function C.PaymentCount()
    return #def().payments
end

function C.OfferBonus()
    local db = DB.Get()
    local bonus = (db.prestige and (db.prestige.level or 0) or 0) * 0.05
    if ns.Museum and ns.Museum.Completed() then bonus = bonus + (ns.Museum.Bonus() or 0) end
    if ns.Regular and ns.Regular.Done() then bonus = bonus + (ns.Regular.Bonus() or 0) end
    return math.min(1.0, bonus)
end

function C.Pay()
    local db = DB.Get()
    local campaign = state()
    if campaign.completed then return false, "The debt is already paid." end

    local payment = C.NextPayment()
    if not payment then return false, "The debt is already paid." end
    local amount = math.floor(tonumber(payment.amount) or 0)
    if (db.credits or 0) < amount then
        return false, string.format("You need %s more Goblin Credits.", U.comma(amount - (db.credits or 0)))
    end
    if not ns.Shop.Charge(amount, "deed") then
        return false, "The payment could not be made."
    end

    campaign.payments = campaign.payments + 1
    campaign.paid = (campaign.paid or 0) + amount
    db.stats.debtPaid = (db.stats.debtPaid or 0) + amount

    ns.History.Add({
        kind = "deed",
        text = "Paid the cartel: " .. payment.title,
        amount = -amount,
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        detail = string.format("Payment %d of %d", campaign.payments, C.PaymentCount()),
    })

    if campaign.payments == 1 then
        db.museum.unlocked = true
        if ns.Regular then ns.Regular.Unlock() end
        ns.History.Add({
            kind = "story",
            text = "The Curious Collection and Marta Copperpin are available",
            amount = 0,
            detail = "Donate quality stock to the museum and watch for Marta in the Deed tab.",
        })
    end

    if campaign.payments >= C.PaymentCount() then
        campaign.completed = true
        campaign.mode = "ending"
        ns.History.Add({
            kind = "deed",
            text = "The debt is paid in full",
            amount = 0,
            icon = "Interface\\Icons\\INV_Scroll_03",
            detail = "Choose endless mode or start a franchise in the Deed tab.",
        })
        if ns.UI and ns.UI.Toast then
            ns.UI.Toast("The deed is paid. Decide what happens to the shop.")
        end
    else
        if ns.UI and ns.UI.Toast then
            ns.UI.Toast(string.format("%s paid. The next note is %s gc.",
                payment.title, U.comma(C.NextPayment() and C.NextPayment().amount or 0)))
        end
    end

    if ns.Achievements then ns.Achievements.Check() end
    if ns.Journal then ns.Journal.SaveNow() end
    return true, payment
end

function C.Endless()
    local campaign = state()
    if not campaign.completed then return false, "Pay the debt first." end
    if campaign.mode == "endless" then return false, "The shop is already in endless mode." end

    campaign.mode = "endless"
    campaign.ending = "endless"
    ns.History.Add({
        kind = "story",
        text = def().endings.endless.title,
        amount = 0,
        detail = def().endings.endless.text,
    })
    if ns.UI and ns.UI.Toast then ns.UI.Toast("Endless mode: the shop stays open.") end
    if ns.Journal then ns.Journal.SaveNow() end
    return true
end

-- The prestige hook: begin a new deed in a smaller shop. Museum, Marta,
-- achievements and franchise levels survive; money, stock, upgrades and staff
-- do not. Offer bonuses are permanent and are paid only by future sales.
function C.Franchise()
    local old = DB.Get()
    if not (old.campaign and old.campaign.completed) then
        return false, "Pay the debt and reach an ending first."
    end

    local level = (old.prestige and (old.prestige.level or 0) or 0) + 1
    local marks = (old.prestige and (old.prestige.marks or 0) or 0) + 1
    local franchises = (old.prestige and (old.prestige.franchises or 0) or 0) + 1
    local achievements = old.achievements
    local museum = old.museum
    local regular = old.regular
    local settings = old.settings

    ns.DB.Reset(true)
    local fresh = DB.Get()
    fresh.achievements = achievements
    fresh.museum = museum
    fresh.regular = regular
    fresh.settings = settings
    fresh.settings.starterGranted = false
    fresh.settings.welcomeVersion = ns.VERSION
    fresh.prestige = {
        level = level,
        marks = marks,
        franchises = franchises,
    }
    fresh.campaign = C.NewState()
    fresh.stats.franchises = franchises
    fresh.stats.debtPaid = 0
    fresh.lastSession = { login = U.now(), version = ns.VERSION }

    -- A new shop, but the same regular. If her story is unfinished, she starts
    -- looking for the new stall after a few sales.
    if fresh.regular and not fresh.regular.done and fresh.regular.unlocked then
        fresh.regular.nextAt = 3
    end
    if ns.Throughput then ns.Throughput.Reset() end

    ns.Wholesaler.GrantStarter()
    ns.History.Add({
        kind = "story",
        text = "Franchise " .. tostring(level) .. " opened",
        amount = 0,
        detail = string.format("Permanent +%d%% customer offers. The museum and Marta's story carried over.", level * 5),
    })
    if ns.DB.IsLive() then
        ns.DB.Save()
        if ns.Journal then ns.Journal.SaveNow() end
    end
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    if ns.UI and ns.UI.Toast then
        ns.UI.Toast("Franchise " .. tostring(level) .. " opened. A new deed begins.")
    end
    return true, level
end
