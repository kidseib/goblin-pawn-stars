--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Tabs/History.lua
    The ledger: sales, purchases, expenses, market events and achievements.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

local FILTERS = {
    { key = "all", label = "All" },
    { key = "sale", label = "Sales" },
    { key = "purchase", label = "Purchases" },
    { key = "expense", label = "Expenses" },
    { key = "market", label = "Market" },
    { key = "achievement", label = "Achievements" },
}

ns.UI.Tabs.history = {
    title = "History",
    icon = "Interface\\Icons\\INV_Misc_Note_01",
    Create = function(parent)
        local ui = { rows = {}, filter = "all" }

        local filterButtons = {}
        local offset = 0
        for _, filter in ipairs(FILTERS) do
            local button = W.Button(parent, filter.label, 96, 24, function(self)
                ui.filter = filter.key
                for key, other in pairs(filterButtons) do
                    other:SetTone(key == filter.key and "gold" or "neutral")
                end
                ui.Refresh()
            end, filter.key == "all" and "gold" or "neutral")
            button:SetPoint("TOPLEFT", offset, 0)
            filterButtons[filter.key] = button
            offset = offset + 102
        end

        ui.summary = W.Text(parent, "", 10, T.colors.muted)
        ui.summary:SetPoint("TOPRIGHT", 0, -7)
        ui.summary:SetJustifyH("RIGHT")

        local list = W.Panel(parent, "panel")
        list:SetPoint("TOPLEFT", 0, -32)
        list:SetPoint("BOTTOMRIGHT", 0, 0)

        local scroll, content = W.Scroll(list)
        scroll:SetPoint("TOPLEFT", 6, -8)
        scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        ui.scroll = scroll

        local ROW_HEIGHT = 38
        for index = 1, 60 do
            local row = W.Create(content, "Frame")
            row:SetHeight(ROW_HEIGHT - 4)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
            row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
            row:Hide()

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            T.Fill(bg, 0.09, 0.075, 0.045, index % 2 == 0 and 0.45 or 0.2)

            local icon = W.Icon(row, 24, "Interface\\Icons\\INV_Misc_Note_01")
            icon:SetPoint("LEFT", 6, 0)

            local when = W.Text(row, "", 9, T.colors.dim)
            when:SetPoint("LEFT", 38, 0)
            when:SetWidth(64)

            local text = W.Text(row, "", 10, T.colors.parchment)
            text:SetPoint("TOPLEFT", 104, -5)
            text:SetPoint("TOPRIGHT", -120, -5)

            local detail = W.Text(row, "", 9, T.colors.muted)
            detail:SetPoint("TOPLEFT", 104, -19)
            detail:SetPoint("TOPRIGHT", -120, -19)

            local amount = W.Number(row, "", 11, T.colors.gold)
            amount:SetPoint("RIGHT", -10, 0)
            amount:SetJustifyH("RIGHT")
            amount:SetWidth(100)

            row.icon = icon
            row.when = when
            row.text = text
            row.detail = detail
            row.amount = amount
            ui.rows[index] = row
        end

        ui.empty = W.Text(list, "Nothing in the ledger yet. Sell something, or buy something shiny.",
            11, T.colors.dim)
        ui.empty:SetPoint("CENTER", 0, 0)
        ui.empty:SetPoint("LEFT", 30, 0)
        ui.empty:SetPoint("RIGHT", -30, 0)
        ui.empty:SetWordWrap(true)

        function ui.Refresh()
            local entries = ns.History.List(ui.filter, #ui.rows)
            local db = ns.DB.Get()
            ui.summary:SetText(string.format("Lifetime: %s earned · %s spent · %s expenses",
                U.comma(db.stats.earned or 0), U.comma(db.stats.spent or 0), U.comma(db.stats.expenses or 0)))

            local shown = 0
            for index, row in ipairs(ui.rows) do
                local entry = entries[index]
                if entry then
                    shown = index
                    row:Show()
                    row.icon:SetIcon(entry.icon or "Interface\\Icons\\INV_Misc_Note_01")
                    local stamp = "—"
                    if entry.at and type(date) == "function" then
                        stamp = date("%H:%M", entry.at)
                    end
                    row.when:SetText(stamp)
                    row.text:SetText(entry.text or "Transaction")
                    row.detail:SetText(entry.detail or entry.kind or "")

                    if entry.amount and entry.amount ~= 0 then
                        local positive = entry.amount > 0
                        row.amount:SetText((positive and "+" or "") .. U.comma(entry.amount))
                        row.amount:SetTextColor(positive and T.colors.green[1] or T.colors.red[1],
                            positive and T.colors.green[2] or T.colors.red[2],
                            positive and T.colors.green[3] or T.colors.red[3])
                    else
                        row.amount:SetText("")
                    end
                else
                    row:Hide()
                end
            end

            ui.empty:SetShown(#entries == 0)
            scroll:SetContentHeight(math.max(shown * 38 + 8, 40))
        end

        return ui
    end,
}
