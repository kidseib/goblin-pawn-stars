--[[ Goblin Pawn Stars -------------------------------------------------------
    Core/Compat.lua
    Every WoW call that may be missing on the Forever client (Retail-derived,
    Interface 16001) lives here behind a pcall. Nothing outside this file should
    touch a raw C_* namespace, a Classic-era global or a protected API.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local C = {}
ns.Compat = C

---------------------------------------------------------------------------
-- Generic guards
---------------------------------------------------------------------------

-- Calls fn with up to 16 arguments/results, returning nil on any error.
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local results = { pcall(fn, ...) }
    if not results[1] then
        ns.Debug("guarded call failed: " .. tostring(results[2]))
        return nil
    end
    table.remove(results, 1)
    return unpack(results)
end

C.Call = call

function C.Exists(name)
    return type(_G[name]) ~= "nil"
end

function C.HasMethod(object, method)
    return object ~= nil and type(object[method]) == "function"
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

function C.CreateFrame(frameType, name, parent, template)
    local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
    if ok and frame then return frame end
    ok, frame = pcall(CreateFrame, frameType, name, parent)
    if ok and frame then return frame end
    return nil
end

function C.SetBackdrop(frame, background, border, edgeSize, insets)
    if not frame or type(frame.SetBackdrop) ~= "function" then return false end
    local inset = insets or 3
    local ok = pcall(frame.SetBackdrop, frame, {
        bgFile = background,
        edgeFile = border,
        tile = true,
        tileSize = 0,
        edgeSize = edgeSize or 14,
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    return ok
end

function C.RegisterEvent(frame, event)
    if not frame or type(event) ~= "string" then return false end
    -- Registering an event the client does not know throws on Forever and
    -- aborts the calling file, so it must always be guarded.
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok then ns.Debug("event unavailable on this client: " .. event) end
    return ok
end

-- Creates a frame whose OnEvent calls handlers[event]. Unknown events are
-- skipped instead of exploding.
function C.EventFrame(handlers)
    local frame = C.CreateFrame("Frame")
    if not frame then return nil end
    frame.handlers = handlers
    frame:SetScript("OnEvent", function(self, event, ...)
        local handler = self.handlers[event]
        if not handler then return end
        local ok, err = pcall(handler, ...)
        if not ok then
            ns.RecordError("event:" .. tostring(event), err)
            ns.Print("|cffff5555Error|r in " .. tostring(event) .. ": " .. tostring(err))
        end
    end)
    for event in pairs(handlers) do
        C.RegisterEvent(frame, event)
    end
    return frame
end

function C.After(seconds, callback)
    if C_Timer and C_Timer.After then
        pcall(C_Timer.After, seconds, callback)
    end
end

---------------------------------------------------------------------------
-- Combat / player state (never reads secret values)
---------------------------------------------------------------------------

function C.InCombat()
    if type(InCombatLockdown) == "function" then
        local ok, result = pcall(InCombatLockdown)
        if ok then return result and true or false end
    end
    if type(UnitAffectingCombat) == "function" then
        local ok, result = pcall(UnitAffectingCombat, "player")
        if ok then return result and true or false end
    end
    return false
end

function C.IsSecret(value)
    if type(issecretvalue) == "function" then
        local ok, result = pcall(issecretvalue, value)
        return ok and result or false
    end
    return false
end

function C.CanRead(value)
    if type(canaccessvalue) == "function" then
        local ok, result = pcall(canaccessvalue, value)
        if ok then return result and true or false end
    end
    return true
end

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------

local function rawItemInfo(identifier)
    if C_Item and type(C_Item.GetItemInfo) == "function" then
        return call(C_Item.GetItemInfo, identifier)
    end
    if type(GetItemInfo) == "function" then
        return call(GetItemInfo, identifier)
    end
    return nil
end

-- Cached-independent basics (icon, class and subclass). Unlike GetItemInfo this
-- works before the client has loaded the item's full tooltip data, which is the
-- normal state for an item that was just looted.
function C.ItemInstant(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end
    local fn = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if type(fn) ~= "function" then return nil end

    local id, itemType, itemSubType, equipLoc, icon, classID, subclassID = call(fn, itemID)
    if not id then return nil end
    return {
        id = tonumber(id) or itemID,
        typeName = type(itemType) == "string" and itemType or nil,
        subTypeName = type(itemSubType) == "string" and itemSubType or nil,
        equipLoc = equipLoc,
        icon = icon,
        classID = tonumber(classID) or 0,
        subclassID = tonumber(subclassID) or 0,
    }
end

function C.RequestItemData(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return false end
    local fn = C_Item and C_Item.RequestLoadItemDataByID
    if type(fn) ~= "function" then return false end
    return pcall(fn, itemID)
end

-- Returns a normalized table for an item ID, or nil when the client has no
-- data for it (uncached items report nil until the client sees them).
function C.Item(itemID, linkHint)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then return nil end

    -- Documented return order (C_Item.GetItemInfo): name, link, quality, itemLevel,
    -- requiredLevel, itemType, itemSubType, maxStack, equipLoc, icon, sellPrice,
    -- classID, subclassID, bindType, expansionID, setID, isCraftingReagent, description.
    -- Positions 6/7 are localized strings; the numeric IDs live at 12/13.
    local name, link, quality, itemLevel, requiredLevel, itemType, itemSubType,
        maxStack, equipLoc, icon, sellPrice, classID, subclassID, bindType,
        expansionID, setID, isCraftingReagent, itemDescription = rawItemInfo(itemID)

    local iconID
    if C_Item and type(C_Item.GetItemIconByID) == "function" then
        iconID = call(C_Item.GetItemIconByID, itemID)
    end

    -- Just-looted items are often not cached yet. GetItemInfoInstant still knows
    -- the class and icon, and the bag hyperlink always carries the localized
    -- name, so a stock record can be built instead of silently dropping the item.
    local instant = C.ItemInstant(itemID)
    if not name and type(linkHint) == "string" then
        name = linkHint:match("%[(.-)%]")
    end
    if not name and C_Item and type(C_Item.GetItemNameByID) == "function" then
        name = call(C_Item.GetItemNameByID, itemID)
    end
    if not name then return nil end

    local info = {
        id = itemID,
        name = name,
        link = link or linkHint,
        quality = tonumber(quality) or 1,
        ilvl = tonumber(itemLevel) or 1,
        requiredLevel = tonumber(requiredLevel) or 0,
        classID = tonumber(classID) or (instant and instant.classID) or 0,
        subclassID = tonumber(subclassID) or (instant and instant.subclassID) or 0,
        typeName = type(itemType) == "string" and itemType or (instant and instant.typeName),
        subTypeName = type(itemSubType) == "string" and itemSubType or (instant and instant.subTypeName),
        bindType = tonumber(bindType) or 0,
        maxStack = tonumber(maxStack) or 1,
        equipLoc = equipLoc or (instant and instant.equipLoc),
        icon = iconID or icon or (instant and instant.icon),
        sellPrice = tonumber(sellPrice) or 0,
        description = type(itemDescription) == "string" and itemDescription or nil,
    }
    if type(info.icon) == "string" and not info.icon:find("\\", 1, true) then
        info.icon = nil
    end
    return info
end

function C.IsConjured(itemID)
    if C_Item and type(C_Item.IsItemConjured) == "function" then
        local result = call(C_Item.IsItemConjured, itemID)
        return result and true or false
    end
    return false
end

function C.QualityColor(quality)
    local colors = ITEM_QUALITY_COLORS
    if colors and colors[quality] then
        local color = colors[quality].color or colors[quality]
        if color and color.r then
            return string.format("|cff%02x%02x%02x",
                math.floor(color.r * 255 + 0.5),
                math.floor(color.g * 255 + 0.5),
                math.floor(color.b * 255 + 0.5))
        end
    end
    local fallback = {
        [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00",
        [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000",
        [6] = "|cffe6cc80", [7] = "|cff00ccff",
    }
    return fallback[quality] or fallback[1]
end

function C.ShowItemTooltip(owner, record)
    if not GameTooltip or not record then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local shown = false
    if record.id and GameTooltip.SetItemByID then
        shown = pcall(GameTooltip.SetItemByID, GameTooltip, record.id)
    end
    if not shown and record.link and GameTooltip.SetHyperlink then
        shown = pcall(GameTooltip.SetHyperlink, GameTooltip, record.link)
    end
    if not shown then
        GameTooltip:SetText(record.name or "Unknown item", 1, 1, 1)
        if record.description then
            GameTooltip:AddLine(record.description, 1, 0.92, 0.75, true)
        end
    end
    GameTooltip:Show()
end

function C.HideTooltip()
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
end

---------------------------------------------------------------------------
-- Bags (read-only; the player's real inventory is never modified)
---------------------------------------------------------------------------

function C.GetContainerNumSlots(bag)
    -- Do not route these through call(): a function that returns a single nil
    -- produces no results after the pcall table round-trip, and tonumber() then
    -- throws. On a real bag the first empty slot returns nil, which used to abort
    -- every scan before any stock was added.
    local fn = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    if type(fn) ~= "function" then return 0 end
    local ok, slots = pcall(fn, bag)
    if not ok then return 0 end
    return tonumber(slots) or 0
end

function C.GetContainerItemID(bag, slot)
    local fn = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    if type(fn) ~= "function" then return nil end
    local ok, itemID = pcall(fn, bag, slot)
    if not ok then return nil end
    return tonumber(itemID)
end

function C.GetContainerItemInfo(bag, slot)
    if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
        return call(C_Container.GetContainerItemInfo, bag, slot)
    end
    return nil
end

function C.GetContainerItemLink(bag, slot)
    if C_Container and type(C_Container.GetContainerItemLink) == "function" then
        return call(C_Container.GetContainerItemLink, bag, slot)
    end
    if type(GetContainerItemLink) == "function" then
        return call(GetContainerItemLink, bag, slot)
    end
    return nil
end

function C.ItemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

function C.BagSlots()
    local bags = {}
    local normal = tonumber(NUM_BAG_SLOTS) or 4
    for bag = 0, normal do bags[#bags + 1] = bag end
    -- Reagent / extra bags exist on some builds; probe a few safe indexes.
    for bag = normal + 1, normal + 3 do
        if C.GetContainerNumSlots(bag) > 0 then bags[#bags + 1] = bag end
    end
    return bags
end

---------------------------------------------------------------------------
-- Panels, sounds, minimap
---------------------------------------------------------------------------

function C.SoundKit(key)
    if SOUNDKIT and SOUNDKIT[key] and type(PlaySound) == "function" then
        pcall(PlaySound, SOUNDKIT[key])
        return true
    end
    return false
end

function C.AddMinimapButton(frame)
    if Minimap and type(Minimap.GetChildren) == "function" then
        pcall(function() frame:SetParent(Minimap) end)
        return true
    end
    return false
end

-- Macros are server-side and survive a cold client restart. Forever's beta
-- currently writes SavedVariables but does not load them back, so the journal
-- uses macro bodies as a last-resort save path. Every call stays guarded.
local function macroFunction(name)
    if type(_G[name]) == "function" then return _G[name] end
    if C_Macro and type(C_Macro[name]) == "function" then return C_Macro[name] end
    return nil
end

function C.MacroCount()
    local fn = macroFunction("GetNumMacros")
    if fn then
        local ok, account, character = pcall(fn)
        if ok and tonumber(account) then
            return (tonumber(account) or 0) + (tonumber(character) or 0)
        end
    end
    -- No usable GetNumMacros: count through GetMacroInfo, which every client has.
    -- Reporting "unavailable" here used to switch the whole journal off.
    local info = macroFunction("GetMacroInfo")
    if not info then return nil end
    local count = 0
    for index = 1, 40 do
        local ok, name = pcall(info, index)
        if not ok then return nil end
        if name == nil then break end
        count = count + 1
    end
    return count
end

function C.MacroInfo(index)
    local fn = macroFunction("GetMacroInfo")
    if not fn then return nil end
    local ok, name, icon, body = pcall(fn, index)
    if not ok or not name then return nil end
    -- Some builds answer with only (name, body), which puts the body in the icon
    -- slot. Reading it there beats treating every journal chunk as unreadable.
    if body == nil and type(icon) == "string" then return name, icon end
    return name, body, icon
end

function C.MacroIndexByName(name)
    local fn = macroFunction("GetMacroIndexByName")
    if not fn then return 0 end
    local ok, index = pcall(fn, name)
    if not ok then return 0 end
    return tonumber(index) or 0
end

function C.CreateMacro(name, icon, body)
    local fn = macroFunction("CreateMacro")
    if not fn then return nil end
    local ok, index = pcall(fn, name, icon or 134400, body or "", false)
    if ok and tonumber(index) and tonumber(index) > 0 then return tonumber(index) end
    return nil
end

function C.EditMacro(index, name, icon, body)
    local fn = macroFunction("EditMacro")
    if not fn then return false end
    local ok, result = pcall(fn, index, name, icon or 134400, body or "")
    if not ok then return false end
    return result ~= false
end

function C.DeleteMacro(index)
    local fn = macroFunction("DeleteMacro")
    if not fn then return false end
    local ok = pcall(fn, index)
    return ok
end

function C.IsAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return call(C_AddOns.IsAddOnLoaded, name)
    end
    return false
end
