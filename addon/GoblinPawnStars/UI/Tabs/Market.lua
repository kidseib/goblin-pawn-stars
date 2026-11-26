--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Tabs/Market.lua
    Demand per category, active market events and what they mean for prices.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

ns.UI.Tabs.market = {
    title = "Market",
    icon = "Interface\\Icons\\INV_Misc_Coin_03",
    Create = function(parent)
        local ui = { rows = {} }

        local header = W.Panel(parent, "panel")
        header:SetPoint("TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", 0, 0)
        header:SetHeight(72)

        local title = W.Text(header, "ACTIVE MARKET EVENTS", 9, T.colors.goldDim)
        title:SetPoint("TOPLEFT", 12, -9)

        ui.eventLines = {}
        for index = 1, 2 do
            local line = W.Text(header, "", 10, T.colors.parchment)
            line:SetPoint("TOPLEFT", 12, -24 - (index - 1) * 22)
            line:SetPoint("TOPRIGHT", -12, -24 - (index - 1) * 22)
            ui.eventLines[index] = line
        end

        local list = W.Panel(parent, "panel")
        list:SetPoint("TOPLEFT", 0, -80)
        list:SetPoint("BOTTOMRIGHT", 0, -26)

        local scroll, content = W.Scroll(list)
        scroll:SetPoint("TOPLEFT", 6, -8)
        scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        ui.scroll = scroll
        ui.content = content

        local ROW_HEIGHT = 40
        for index, category in ipairs(ns.Data.Categories) do
            local row = W.Create(content, "Frame")
            row:SetHeight(ROW_HEIGHT - 4)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
            row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            T.Fill(bg, 0.09, 0.075, 0.045, index % 2 == 0 and 0.45 or 0.22)

            local icon = W.Icon(row, 26, category.icon)
            icon:SetPoint("LEFT", 6, 0)

            local name = W.Text(row, category.name, 12, T.colors.parchment)
            name:SetPoint("LEFT", 40, 0)
            name:SetWidth(150)

            local bar = W.Bar(row, 220, 8, T.colors.green)
            bar:SetPoint("LEFT", 200, 0)

            local percent = W.Number(row, "100%", 13, T.colors.gold)
            percent:SetPoint("RIGHT", -12, 0)
            percent:SetJustifyH("RIGHT")

            row.name = name
            row.bar = bar
            row.percent = percent
            row.category = category.key
            ui.rows[index] = row
        end

        local footer = W.Text(parent,
            "|cff9c8a5aDemand drifts slowly on its own. Events push categories up or down for a while.|r",
            9, T.colors.dim)
        footer:SetPoint("BOTTOMLEFT", 2, -20)
        footer:SetPoint("BOTTOMRIGHT", -2, -20)
        footer:SetWordWrap(true)

        function ui.Refresh()
            local events = ns.Market.Active()
            for index, line in ipairs(ui.eventLines) do
                local event = events[index]
                if event then
                    line:SetText(string.format("|cffffd700%s|r (%s remaining) — %s",
                        event.name, U.clock(event.remaining), event.description or ""))
                    line:Show()
                elseif index == 1 then
                    line:SetText("|cff9c8a5aNo events. The market is suspiciously calm.|r")
                    line:Show()
                else
                    line:Hide()
                end
            end

            for _, row in ipairs(ui.rows) do
                local multiplier = ns.Market.Multiplier(row.category)
                local percent = math.floor(multiplier * 100 + 0.5)
                row.percent:SetText(percent .. "%")
                row.bar:SetValue(math.min(multiplier, 2.0), 2.0)

                local color
                if multiplier >= 1.18 then
                    color = T.colors.green
                elseif multiplier <= 0.9 then
                    color = T.colors.red
                else
                    color = T.colors.goldDim
                end
                row.bar:SetColor(color)
                row.percent:SetTextColor(color[1], color[2], color[3])
            end

            scroll:SetContentHeight(#ns.Data.Categories * 40 + 8)
        end

        return ui
    end,
}
