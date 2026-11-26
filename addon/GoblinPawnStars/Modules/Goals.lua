--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Goals.lua
    Ordered starter objectives shown on the dashboard as "Next up". They give
    the shop a flow beyond waiting for customers: one clear next action at a
    time, with the relevant tab one click away.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local G = {}
ns.Goals = G

local function upgradeCount(db)
    local count = 0
    for _, level in pairs(db.upgrades or {}) do
        if (tonumber(level) or 0) > 0 then count = count + 1 end
    end
    return count
end

local function staffCount(db)
    local count = 0
    for _, level in pairs(db.employees or {}) do
        if (tonumber(level) or 0) > 0 then count = count + 1 end
    end
    return count
end

local function hasStock(db)
    for _ in pairs(db.inventory or {}) do return true end
    return (db.stats and (db.stats.itemsCollected or 0) > 0) or false
end

local function hasMetCustomer(db)
    local stats = db.stats or {}
    return (stats.customers or 0) > 0
        or (stats.customersServed or 0) > 0
        or (stats.negotiations or 0) > 0
        or (stats.sales or 0) > 0
end

G.List = {
    {
        key = "tour",
        label = "Take the 60-second tour",
        hint = "A quick walk through the counter, the haggling and the upgrades.",
        action = "tour",
        check = function(db)
            return (db.settings or {}).tourDone == true
        end,
    },
    {
        key = "stock",
        label = "Put something on the shelves",
        hint = "Loot in the world, or click Stock Bags Now to import eligible items you are already carrying.",
        action = "import",
        check = hasStock,
    },
    {
        key = "customer",
        label = "Meet your first customer",
        hint = "Customers wander in while the shop is open. Open the counter when one arrives.",
        tab = "customers",
        check = hasMetCustomer,
    },
    {
        key = "sale",
        label = "Make your first sale",
        hint = "Accept an offer, or counter it. Sold items leave the shelves and pay Goblin Credits.",
        tab = "customers",
        check = function(db)
            return ((db.stats or {}).sales or 0) > 0
        end,
    },
    {
        key = "wholesale",
        label = "Buy a wholesale lot",
        hint = "The wholesaler sells bulk stock for credits. Buy low, let customers buy it one piece at a time.",
        action = "wholesaler",
        check = function(db)
            return ((db.stats or {}).wholesaleBought or 0) > 0
        end,
    },
    {
        key = "upgrade",
        label = "Buy your first upgrade",
        hint = "Shelves add storage, a haggling manual improves counteroffers, a sign brings more traffic.",
        tab = "upgrades",
        check = function(db)
            return upgradeCount(db) > 0
        end,
    },
    {
        key = "tier",
        label = "Upgrade to a Goblin Pawnshop",
        hint = "Tier 2 adds staff slots, wealthier customers and more storage.",
        tab = "upgrades",
        check = function(db)
            return (db.tier or 1) >= 2
        end,
    },
    {
        key = "staff",
        label = "Hire your first employee",
        hint = "Employees add passive bonuses. Their wages are charged every shop day.",
        tab = "employees",
        check = function(db)
            return staffCount(db) > 0
        end,
    },
    {
        key = "sales10",
        label = "Serve ten customers",
        hint = "Build a reputation, then chase the rare collectors and the auction-house tier.",
        tab = "customers",
        check = function(db)
            return ((db.stats or {}).sales or 0) >= 10
        end,
    },
    {
        key = "deed1",
        label = "Pay the first cartel note",
        hint = "Snix Brassknuckle is waiting. Pay 1,500 gc to unlock the museum and Marta Copperpin.",
        action = "deed",
        check = function(db)
            return ((db.campaign or {}).payments or 0) >= 1
        end,
    },
    {
        key = "museum1",
        label = "Donate a piece to the museum",
        hint = "The Curious Collection needs quality stock. Donating consumes one virtual item and adds a permanent offer bonus.",
        action = "deed",
        check = function(db)
            for _ in pairs((db.museum or {}).donated or {}) do return true end
            return false
        end,
    },
    {
        key = "deed2",
        label = "Pay the second cartel note",
        hint = "The next note is 6,000 gc. Keep the shelves stocked and the counter moving.",
        action = "deed",
        check = function(db)
            return ((db.campaign or {}).payments or 0) >= 2
        end,
    },
    {
        key = "marta1",
        label = "Serve Marta Copperpin",
        hint = "Marta visits after a few sales once the first note is paid. Invite her from the Deed tab if you are impatient.",
        action = "deed",
        check = function(db)
            return ((db.regular or {}).visits or 0) >= 1
        end,
    },
    {
        key = "deed3",
        label = "Pay the final cartel note",
        hint = "25,000 gc closes the ledger. Then decide whether the shop keeps its doors open.",
        action = "deed",
        check = function(db)
            return ((db.campaign or {}).payments or 0) >= 3
        end,
    },
    {
        key = "ending",
        label = "Choose what happens to the shop",
        hint = "Endless mode keeps the store running. A franchise starts a new deed and keeps the museum, Marta and every offer bonus.",
        action = "deed",
        check = function(db)
            return ((db.campaign or {}).mode or "campaign") ~= "ending"
                and ((db.campaign or {}).completed == true)
        end,
    },
}

function G.Current(db)
    db = db or ns.DB.Get()
    for _, step in ipairs(G.List) do
        if not step.check or not step.check(db) then
            return step
        end
    end
    return nil
end

function G.Progress(db)
    db = db or ns.DB.Get()
    local done = 0
    for _, step in ipairs(G.List) do
        if step.check and step.check(db) then done = done + 1 end
    end
    return done, #G.List
end
