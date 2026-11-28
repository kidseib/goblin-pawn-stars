--[[ Goblin PawnStars --------------------------------------------------------
    Modules/Achievements.lua
    Custom milestones with fictional shop titles. Unlocks are permanent and are
    checked after every stat change rather than on a timer.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local A = {}
ns.Achievements = A

local function progressOf(def, db)
    if def.check then
        local progress, target = def.check(db)
        return tonumber(progress) or 0, tonumber(target) or def.target or 1
    end
    if not def.stat then return 0, def.target or 1 end
    if def.stat == "tier" then
        return db.tier or 1, def.target or 1
    end
    if def.stat == "reputation" then
        return db.reputation or 0, def.target or 1
    end
    return tonumber(db.stats[def.stat]) or 0, def.target or 1
end

function A.Progress(def)
    return progressOf(def, DB.Get())
end

function A.Unlocked(key)
    return DB.Get().achievements[key] ~= nil
end

function A.Check()
    local db = DB.Get()
    local unlocked = {}
    for _, def in ipairs(ns.Data.Achievements) do
        if not db.achievements[def.key] then
            local progress, target = progressOf(def, db)
            if target > 0 and progress >= target then
                db.achievements[def.key] = {
                    at = U.now(),
                    day = U.today(),
                }
                unlocked[#unlocked + 1] = def
                ns.History.Add({
                    kind = "achievement",
                    text = "Achievement unlocked: " .. def.name,
                    icon = def.icon,
                    amount = 0,
                })
            end
        end
    end

    if #unlocked > 0 then
        for _, def in ipairs(unlocked) do
            ns.Print(string.format("|cffffd200Achievement unlocked:|r %s |cff888888(%s)|r", def.name, def.description))
            if def.title then
                ns.Print("New shop title: |cff7bd66b" .. def.title .. "|r")
            end
        end
        -- The deed celebration is quiet: the lines above already announce the
        -- unlock, so Ceremony only adds the burst and the fanfare.
        if ns.Ceremony and ns.Ceremony.Deed then
            for _, def in ipairs(unlocked) do pcall(ns.Ceremony.Deed, def) end
        end
        if ns.Sound then ns.Sound.Play("achievement") end
        if ns.UI and ns.UI.Toast then
            ns.UI.Toast("Achievement: " .. unlocked[#unlocked].name)
        end
    end
    return unlocked
end

function A.List()
    local db = DB.Get()
    local list = {}
    for _, def in ipairs(ns.Data.Achievements) do
        local progress, target = progressOf(def, db)
        local unlockedAt = db.achievements[def.key]
        list[#list + 1] = {
            key = def.key,
            name = def.name,
            description = def.description,
            icon = def.icon,
            points = def.points or 0,
            title = def.title,
            progress = math.min(progress, target),
            target = target,
            unlocked = unlockedAt ~= nil,
            unlockedAt = unlockedAt and unlockedAt.at or nil,
        }
    end
    return list
end

function A.Score()
    local total = 0
    for _, def in ipairs(ns.Data.Achievements) do
        if A.Unlocked(def.key) then total = total + (def.points or 0) end
    end
    return total
end

function A.Titles()
    local list = {}
    for _, def in ipairs(ns.Data.Achievements) do
        if def.title and A.Unlocked(def.key) then list[#list + 1] = def.title end
    end
    return list
end

function A.BestTitle()
    local titles = A.Titles()
    return titles[#titles]
end

function A.Count()
    local count = 0
    for _, def in ipairs(ns.Data.Achievements) do
        if A.Unlocked(def.key) then count = count + 1 end
    end
    return count, #ns.Data.Achievements
end

A.events = ns.Compat.EventFrame({
    PLAYER_LOGIN = function()
        A.Check()
    end,
})
