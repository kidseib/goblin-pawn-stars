--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Theme.lua
    Dark wood, tarnished gold, parchment and goblin green. Uses only built-in
    Blizzard textures so the addon ships without binary art assets.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
ns.UI = ns.UI or {}
ns.UI.Tabs = ns.UI.Tabs or {}
ns.UI.TabOrder = ns.UI.TabOrder or {}

local T = {}
ns.Theme = T

T.font = "Fonts\\FRIZQT__.TTF"
T.fontNumber = "Fonts\\ARIALN.TTF"

T.media = {
    window = "Interface\\DialogFrame\\UI-DialogBox-Background",
    windowDark = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    border = "Interface\\DialogFrame\\UI-DialogBox-Border",
    inset = "Interface\\Tooltips\\UI-Tooltip-Background",
    borderDim = "Interface\\Tooltips\\UI-Tooltip-Border",
    white = "Interface\\Buttons\\WHITE8X8",
    highlight = "Interface\\Buttons\\UI-Listbox-Highlight2",
    coin = "Interface\\Icons\\INV_Misc_Coin_01",
    goblin = "Interface\\Icons\\INV_Misc_Coin_07",
}

T.colors = {
    text = { 0.94, 0.90, 0.80 },
    muted = { 0.63, 0.58, 0.47 },
    dim = { 0.45, 0.41, 0.34 },
    gold = { 0.94, 0.78, 0.33 },
    goldDim = { 0.62, 0.50, 0.24 },
    green = { 0.49, 0.84, 0.42 },
    greenDark = { 0.16, 0.34, 0.13 },
    parchment = { 0.91, 0.85, 0.69 },
    red = { 0.86, 0.32, 0.26 },
    blue = { 0.45, 0.70, 0.95 },
    wood = { 0.13, 0.10, 0.06 },
    woodLight = { 0.21, 0.16, 0.09 },
}

T.tierIcons = {
    "Interface\\Icons\\INV_Misc_Bag_10",
    "Interface\\Icons\\INV_Misc_Bag_14",
    "Interface\\Icons\\INV_Misc_Bag_17",
    "Interface\\Icons\\INV_Box_01",
    "Interface\\Icons\\INV_Misc_Map_01",
}

function T.RGB(color, alpha)
    return color[1], color[2], color[3], alpha or 1
end

function T.Hex(color)
    return string.format("|cff%02x%02x%02x",
        math.floor((color[1] or 1) * 255 + 0.5),
        math.floor((color[2] or 1) * 255 + 0.5),
        math.floor((color[3] or 1) * 255 + 0.5))
end

function T.Credits(amount)
    return "|cffffd700" .. ns.Util.comma(amount or 0) .. "|r |cff9c8a5agc|r"
end

function T.PlainCredits(amount)
    return ns.Util.comma(amount or 0) .. " gc"
end

function T.Quality(quality)
    return ns.Compat.QualityColor(quality or 1)
end

function T.ItemName(record)
    if not record then return "|cff888888unknown|r" end
    return T.Quality(record.quality) .. (record.name or "item") .. "|r"
end

-- Applies the default "trading post" look to any frame.
function T.Decorate(frame, style)
    if not frame then return frame end
    style = style or "panel"

    local background = T.media.window
    local border = T.media.border
    local bg = { 0.11, 0.09, 0.05, 0.97 }
    local edge = { 0.55, 0.44, 0.20, 1 }

    if style == "window" then
        bg = { 0.15, 0.12, 0.07, 0.98 }
        edge = { 0.72, 0.58, 0.26, 1 }
    elseif style == "inset" then
        background = T.media.inset
        border = T.media.borderDim
        bg = { 0.06, 0.05, 0.03, 0.88 }
        edge = { 0.36, 0.30, 0.16, 1 }
    elseif style == "parchment" then
        bg = { 0.20, 0.16, 0.10, 0.96 }
        edge = { 0.50, 0.41, 0.22, 1 }
    end

    if ns.Compat.SetBackdrop(frame, background, border, style == "window" and 18 or 12, 4) then
        if frame.SetBackdropColor then
            frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        end
        if frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
        end
        frame.hasBackdrop = true
    else
        -- Fallback: flat fill with a simple frame, for clients without
        -- BackdropTemplate support.
        local fill = frame:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        T.Fill(fill, bg[1], bg[2], bg[3], bg[4])
        local strips = {}
        for index = 1, 4 do
            local strip = frame:CreateTexture(nil, "BORDER")
            T.Fill(strip, edge[1], edge[2], edge[3], 0.9)
            strips[index] = strip
        end
        strips[1]:SetPoint("TOPLEFT")
        strips[1]:SetPoint("TOPRIGHT")
        strips[1]:SetHeight(1)
        strips[2]:SetPoint("BOTTOMLEFT")
        strips[2]:SetPoint("BOTTOMRIGHT")
        strips[2]:SetHeight(1)
        strips[3]:SetPoint("TOPLEFT")
        strips[3]:SetPoint("BOTTOMLEFT")
        strips[3]:SetWidth(1)
        strips[4]:SetPoint("TOPRIGHT")
        strips[4]:SetPoint("BOTTOMRIGHT")
        strips[4]:SetWidth(1)
    end

    return frame
end

-- Solid colour fill that works with or without SetColorTexture.
function T.Fill(texture, r, g, b, a)
    if not texture then return end
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a or 1)
    else
        texture:SetTexture(T.media.white)
        texture:SetVertexColor(r, g, b, a or 1)
    end
    return texture
end

function T.GoldLine(parent, height)
    local line = parent:CreateTexture(nil, "ARTWORK")
    T.Fill(line, 0.62, 0.50, 0.22, 0.85)
    line:SetHeight(height or 1)
    return line
end
