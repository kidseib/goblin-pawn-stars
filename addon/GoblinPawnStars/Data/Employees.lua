--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Employees.lua
    Fictional staff: what each role does, what they cost to hire, how their pay
    scales and what every level adds.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local Data = ns.Data

Data.Employees = {
    {
        key = "appraiser",
        name = "Grizzle Farsight",
        role = "Appraiser",
        icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
        quote = "That's not a relic. That's a door handle.",
        description = "Sharpens valuations and reads customers better than they read themselves.",
        baseCost = 450, costGrowth = 1.9, wage = 22, wageGrowth = 14, maxLevel = 5,
        fx = { appraisal = 10, haggle = 0.02 },
        fxText = "+10 appraisal, +2% counteroffers per level",
        minTier = 2,
    },
    {
        key = "salesperson",
        name = "Nixi Brightcoin",
        role = "Salesperson",
        icon = "Interface\\Icons\\INV_Misc_Coin_04",
        quote = "Everything's a bargain if you talk fast enough.",
        description = "Works the waiting queue while you are busy, closing sales at a lower margin than your own haggling.",
        baseCost = 600, costGrowth = 1.9, wage = 28, wageGrowth = 16, maxLevel = 5,
        fx = { autosale = 0.04 },
        fxText = "+4% auto-sale margin per level",
        minTier = 2,
    },
    {
        key = "accountant",
        name = "Ledger Deepdelve",
        role = "Accountant",
        icon = "Interface\\Icons\\INV_Misc_Note_02",
        quote = "No, you cannot claim the blimp as a medical expense.",
        description = "Finds deductions in places the tax office would rather not look.",
        baseCost = 700, costGrowth = 1.85, wage = 30, wageGrowth = 15, maxLevel = 5,
        fx = { expense = 0.08 },
        fxText = "-8% operating expenses per level",
        minTier = 2,
    },
    {
        key = "guard",
        name = "Sergeant Grubb",
        role = "Security Guard",
        icon = "Interface\\Icons\\INV_Shield_02",
        quote = "Touch the display case. I dare you.",
        description = "Discourages thieves, counterfeiters and people who haggle too loudly.",
        baseCost = 800, costGrowth = 1.9, wage = 32, wageGrowth = 17, maxLevel = 5,
        fx = { theft = 0.18, forgery = 0.10 },
        fxText = "-18% theft and better forgery detection per level",
        minTier = 2,
    },
    {
        key = "marketing",
        name = "Blix Advertwhistle",
        role = "Marketing Specialist",
        icon = "Interface\\Icons\\INV_Misc_Horn_02",
        quote = "Have you considered shouting about it?",
        description = "Brings in more customers, louder and slightly faster than usual.",
        baseCost = 950, costGrowth = 1.95, wage = 36, wageGrowth = 18, maxLevel = 5,
        fx = { arrival = 6, waiting = 0.2 },
        fxText = "-6s between customers per level",
        minTier = 3,
    },
    {
        key = "treasure",
        name = "Vexa Shardhunter",
        role = "Treasure Specialist",
        icon = "Interface\\Icons\\INV_Misc_Gem_02",
        quote = "Rare is just expensive with better manners.",
        description = "Knows which collectors to write to when something unusual arrives.",
        baseCost = 1400, costGrowth = 2.0, wage = 45, wageGrowth = 20, maxLevel = 5,
        fx = { rare = 0.03, offer = 0.01 },
        fxText = "+3% rare customers and +1% offers per level",
        minTier = 3,
    },
}

Data.EmployeeByKey = {}
for _, employee in ipairs(Data.Employees) do
    Data.EmployeeByKey[employee.key] = employee
end

function Data.EmployeeCost(employee, currentLevel)
    if not employee then return math.huge end
    currentLevel = math.max(0, tonumber(currentLevel) or 0)
    if currentLevel == 0 then return employee.baseCost end
    return math.floor(employee.baseCost * (employee.costGrowth ^ currentLevel))
end

function Data.EmployeeWage(employee, level)
    if not employee or (level or 0) <= 0 then return 0 end
    return employee.wage + (level - 1) * (employee.wageGrowth or 0)
end
