--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Tabs/Inventory.lua
    Virtual stock with search, category filter, sorting and real item tooltips.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

ns.UI.Tabs.inventory = {
    title = "Inventory",
    icon = "Interface\\Icons\\INV_Misc_Bag_10",
    Create = function(parent)
        local ui = {
            search = "",
            category = "all",
            sort = "value",
            rows = {},
        }

        local ROW_HEIGHT = 44
        local MAX_ROWS = 120

        local categories = { "all" }
        for _, category in ipairs(ns.Data.Categories) do
            categories[#categories + 1] = category.key
        end

        local searchBox = W.EditBox(parent, 210, 24, "Search the shelves...")
        searchBox:SetPoint("TOPLEFT", 0, 0)
        searchBox:SetMaxLetters(40)
        searchBox:SetText("")
        searchBox:SetScript("OnTextChanged", function(self)
            ui.search = self:GetText() or ""
            ui.Refresh()
        end)

        local filterButton = W.Button(parent, "Filter: All", 150, 24, function(_, self)
            local index = 1
            for position, key in ipairs(categories) do
                if key == ui.category then index = position end
            end
            index = index % #categories + 1
            ui.category = categories[index]
            self:SetLabel("Filter: " .. (ui.category == "all" and "All" or ns.Data.CategoryName(ui.category)))
            ui.Refresh()
        end, "neutral")
        filterButton:SetPoint("TOPLEFT", 218, 0)

        local sortButton = W.Button(parent, "Sort: Value", 130, 24, function(_, self)
            local order = { "value", "rarity", "name", "recent", "count" }
            local labels = { value = "Value", rarity = "Rarity", name = "Name", recent = "Recent", count = "Stack" }
            local index = 1
            for position, key in ipairs(order) do
                if key == ui.sort then index = position end
            end
            index = index % #order + 1
            ui.sort = order[index]
            self:SetLabel("Sort: " .. labels[ui.sort])
            ui.Refresh()
        end, "neutral")
        sortButton:SetPoint("TOPLEFT", 356, 0)

        ui.countText = W.Text(parent, "0 / 0 slots used", 10, T.colors.muted)
        ui.countText:SetPoint("TOPRIGHT", 0, -7)
        ui.countText:SetJustifyH("RIGHT")

        local listPanel = W.Panel(parent, "panel")
        listPanel:SetPoint("TOPLEFT", 0, -32)
        listPanel:SetPoint("BOTTOMRIGHT", 0, 0)

        local scroll, content = W.Scroll(listPanel)
        scroll:SetPoint("TOPLEFT", 6, -8)
        scroll:SetPoint("BOTTOMRIGHT", -6, 8)
        ui.scroll = scroll
        ui.content = content

        ui.empty = W.Text(listPanel, "The shelves are bare. Loot something in the world and it will appear here.",
            12, T.colors.dim)
        ui.empty:SetPoint("CENTER", 0, 0)
        ui.empty:SetPoint("LEFT", 20, 0)
        ui.empty:SetPoint("RIGHT", -20, 0)
        ui.empty:SetWordWrap(true)

        local function buildRow(index)
            local row = W.Create(content, "Button")
            row:SetHeight(ROW_HEIGHT - 4)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
            row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            T.Fill(bg, 0.09, 0.075, 0.045, index % 2 == 0 and 0.5 or 0.25)

            local highlight = row:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            T.Fill(highlight, 0.9, 0.8, 0.45, 0.08)

            local icon = W.Icon(row, 32)
            icon:SetPoint("LEFT", 6, 0)

            local name = W.Text(row, "", 12, T.colors.parchment)
            name:SetPoint("TOPLEFT", 48, -7)
            name:SetPoint("TOPRIGHT", -140, -7)

            local meta = W.Text(row, "", 9, T.colors.muted)
            meta:SetPoint("BOTTOMLEFT", 48, 7)
            meta:SetPoint("BOTTOMRIGHT", -140, 7)

            local value = W.Number(row, "", 13, T.colors.gold)
            value:SetPoint("RIGHT", -12, 0)
            value:SetJustifyH("RIGHT")

            row.icon = icon
            row.name = name
            row.meta = meta
            row.value = value

            W.ItemTooltip(row, function() return row.record end)
            return row
        end

        function ui.Refresh()
            local items, marketValues = ns.Inventory.List({
                search = ui.search,
                category = ui.category,
                sort = ui.sort,
            })
            local used, max = ns.Inventory.Count(), ns.Inventory.Capacity()
            ui.countText:SetText(string.format("%d / %d slots used · %d shown", used, max, #items))
            ui.countText:SetTextColor(used >= max and T.colors.red[1] or T.colors.muted[1],
                used >= max and T.colors.red[2] or T.colors.muted[2],
                used >= max and T.colors.red[3] or T.colors.muted[3])

            local shown = math.min(#items, MAX_ROWS)
            for index = 1, shown do
                local row = ui.rows[index]
                if not row then
                    row = buildRow(index)
                    ui.rows[index] = row
                end
                local record = items[index]
                row.record = record
                row:Show()
                row.icon:SetIcon(record.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.name:SetText(T.ItemName(record))
                local market = marketValues and marketValues[record] or ns.Market.Value(record)
                local delta = market - (record.value or 0)
                local deltaText = ""
                if math.abs(delta) >= 1 then
                    deltaText = string.format(" · |cff%s%s%d%%|r",
                        delta >= 0 and "5fd64f" or "ff6b5e",
                        delta >= 0 and "+" or "",
                        math.floor(delta / math.max(1, record.value or 1) * 100))
                end
                row.meta:SetText(string.format("%s · %s%s%s",
                    ns.Data.CategoryName(record.category),
                    record.count > 1 and ("x" .. record.count .. " · ") or "",
                    record.counterfeit and "|cffff5555counterfeit|r" or "quality " .. tostring(record.quality),
                    deltaText))
                row.value:SetText(T.Credits(market * (record.count or 1)))
            end

            for index = shown + 1, #ui.rows do
                ui.rows[index]:Hide()
            end

            ui.empty:SetShown(#items == 0)
            scroll:SetContentHeight(math.max(shown * ROW_HEIGHT + 8, 40))
        end

        return ui
    end,
}
