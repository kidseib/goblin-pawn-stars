--[[ Goblin Pawn Stars -------------------------------------------------------
    Modules/History.lua
    Newest-first ledger of sales, purchases, expenses and notable events.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local DB = ns.DB
local H = {}
ns.History = H

local MAX_ENTRIES = 250

function H.Add(entry)
    if type(entry) ~= "table" then return end
    local db = DB.Get()
    if type(db.history) ~= "table" then db.history = {} end

    entry.at = entry.at or U.now()
    entry.day = entry.day or U.today()

    table.insert(db.history, 1, entry)
    while #db.history > MAX_ENTRIES do
        table.remove(db.history)
    end
    return entry
end

function H.List(kind, limit)
    local db = DB.Get()
    local list = {}
    for _, entry in ipairs(db.history) do
        if not kind or kind == "all" or entry.kind == kind then
            list[#list + 1] = entry
            if limit and #list >= limit then break end
        end
    end
    return list
end

function H.Clear()
    DB.Get().history = {}
end

function H.Sum(kind)
    local total = 0
    for _, entry in ipairs(DB.Get().history) do
        if entry.kind == kind and entry.amount then total = total + entry.amount end
    end
    return total
end
