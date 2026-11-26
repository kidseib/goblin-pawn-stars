--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Tabs/Achievements.lua
    Custom milestones and the fictional shop titles they unlock.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

ns.UI.Tabs.achievements = {
    title = "Achievements",
    icon = "Interface\\Icons\\INV_Misc_Note_02",
    Create = function(parent)
        local ui = { rows = {} }

        local header = W.Panel(parent, "panel")
        header:SetPoint("TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", 0, 0)
        header:SetHeight(66)

        ui.score = W.Number(header, "0", 24, T.colors.gold)
        ui.score:SetPoint("TOPLEFT", 14, -14)

        ui.scoreLabel = W.Text(header, "achievement points", 9, T.colors.muted)
        ui.scoreLabel:SetPoint("TOPLEFT", 14, -42)

        ui.count = W.Text(header, "", 12, T.colors.parchment)
        ui.count:SetPoint("TOPLEFT", 160, -16)

        ui.titles = W.Text(header, "", 10, T.colors.green)
        ui.titles:SetPoint("TOPLEFT", 160, -38)
        ui.titles:SetPoint("TOPRIGHT", -12, -38)
        ui.titles:SetWordWrap(true)

        local list = W.Panel(parent, "panel")
        list:SetPoint("TOPLEFT", 0, -74)
        list:SetPoint("BOTTOMRIGHT", 0, 0)

        local scroll, content = W.Scroll(list)
        scroll:SetPoint("TOPLEFT", 6, -8)
        scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        ui.scroll = scroll

        local ROW_HEIGHT = 58
        for index, def in ipairs(ns.Data.Achievements) do
            local row = W.Create(content, "Frame")
            row:SetHeight(ROW_HEIGHT - 5)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
            row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            T.Fill(bg, 0.09, 0.075, 0.045, index % 2 == 0 and 0.5 or 0.25)

            local icon = W.Icon(row, 32, def.icon)
            icon:SetPoint("LEFT", 8, 2)

            local name = W.Text(row, def.name, 12, T.colors.parchment)
            name:SetPoint("TOPLEFT", 50, -7)
            name:SetPoint("TOPRIGHT", -60, -7)

            local desc = W.Text(row, def.description, 9, T.colors.muted)
            desc:SetPoint("TOPLEFT", 50, -23)
            desc:SetPoint("TOPRIGHT", -60, -23)

            local bar = W.Bar(row, 300, 5, T.colors.gold)
            bar:SetPoint("BOTTOMLEFT", 50, 7)

            local progress = W.Text(row, "", 9, T.colors.dim)
            progress:SetPoint("BOTTOMRIGHT", -10, 8)
            progress:SetJustifyH("RIGHT")

            local done = W.Text(row, "", 9, T.colors.green)
            done:SetPoint("TOPRIGHT", -10, -9)
            done:SetJustifyH("RIGHT")

            row.icon = icon
            row.name = name
            row.desc = desc
            row.bar = bar
            row.progress = progress
            row.done = done
            ui.rows[index] = row
        end

        function ui.Refresh()
            local list_ = ns.Achievements.List()
            local unlocked, total = ns.Achievements.Count()
            ui.score:SetText(tostring(ns.Achievements.Score()))
            ui.count:SetText(string.format("%d / %d unlocked", unlocked, total))

            local titles = ns.Achievements.Titles()
            if #titles > 0 then
                ui.titles:SetText("Shop titles: " .. table.concat(titles, ", "))
            else
                ui.titles:SetText("No titles yet. Sell something, then sell everything else.")
            end

            for index, row in ipairs(ui.rows) do
                local entry = list_[index]
                if entry then
                    row.name:SetText(entry.name)
                    row.desc:SetText(entry.description)
                    row.icon:SetIcon(entry.icon)
                    row.bar:SetValue(entry.progress, math.max(1, entry.target))
                    if entry.unlocked then
                        row.name:SetTextColor(T.colors.green[1], T.colors.green[2], T.colors.green[3])
                        row.progress:SetText(entry.target .. " / " .. entry.target)
                        row.bar:SetColor(T.colors.green)
                        row.done:SetText(entry.title and ("|cffffd700Title: " .. entry.title .. "|r") or "Unlocked")
                    else
                        row.name:SetTextColor(T.colors.parchment[1], T.colors.parchment[2], T.colors.parchment[3])
                        row.progress:SetText(U.comma(entry.progress) .. " / " .. U.comma(entry.target))
                        row.bar:SetColor(T.colors.goldDim)
                        row.done:SetText("")
                    end
                end
            end

            scroll:SetContentHeight(#ns.Data.Achievements * 58 + 8)
        end

        return ui
    end,
}
