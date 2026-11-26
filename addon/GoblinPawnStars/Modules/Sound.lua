--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/Sound.lua
    Optional UI sounds. Every lookup is guarded: a missing SOUNDKIT entry (or a
    client that does not expose PlaySound) is silently ignored.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local DB = ns.DB
local S = {}
ns.Sound = S

local CUES = {
    coin = { "COIN_PICKUP", "IG_MAINMENU_OPTION_CHECKBOX_ON", "LOOT_WINDOW_OPEN" },
    open = { "IG_MAINMENU_OPEN", "IG_CHARACTER_INFO_OPEN" },
    close = { "IG_MAINMENU_CLOSE" },
    customer = { "IG_QUEST_LIST_OPEN", "AUCTION_WINDOW_OPEN" },
    event = { "IG_MAINMENU_OPEN", "UI_WARSONG_ALERT" },
    reject = { "IG_MAINMENU_CLOSE", "LOOT_WINDOW_CLOSE" },
    achievement = { "ACHIEVEMENT_MENU_OPEN", "IG_CHARACTER_INFO_OPEN" },
    error = { "IG_MAINMENU_CLOSE" },
}

function S.Enabled()
    local db = DB.Get()
    return db.settings and db.settings.sound ~= false
end

function S.Play(cue)
    if not S.Enabled() then return false end
    local keys = CUES[cue]
    if not keys then return false end
    for index = 1, #keys do
        if ns.Compat.SoundKit(keys[index]) then return true end
    end
    return false
end

function S.Toggle()
    local db = DB.Get()
    db.settings.sound = not (db.settings.sound ~= false)
    if db.settings.sound then S.Play("open") end
    return db.settings.sound
end
