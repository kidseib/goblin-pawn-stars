--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Tabs/Employees.lua
    Staff roster: who works here, what they cost and what each level adds.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

ns.UI.Tabs.employees = {
    title = "Employees",
    icon = "Interface\\Icons\\INV_Misc_Head_Gnome_01",
    Create = function(parent)
        local ui = { rows = {} }

        local header = W.Panel(parent, "panel")
        header:SetPoint("TOPLEFT", 0, 0)
        header:SetPoint("TOPRIGHT", 0, 0)
        header:SetHeight(62)

        ui.slots = W.Text(header, "Staff slots: 0 / 0", 12, T.colors.parchment)
        ui.slots:SetPoint("TOPLEFT", 12, -10)

        ui.wages = W.Text(header, "Wages: 0 gc per shop day", 10, T.colors.muted)
        ui.wages:SetPoint("TOPLEFT", 12, -30)

        ui.autoButton = W.Button(header, "Auto-sell: on", 140, 26, function(self)
            local db = ns.DB.Get()
            db.settings.autoSell = not (db.settings.autoSell ~= false)
            self:SetLabel("Auto-sell: " .. (db.settings.autoSell and "on" or "off"))
            self:SetTone(db.settings.autoSell and "primary" or "neutral")
        end, "primary")
        ui.autoButton:SetPoint("RIGHT", -12, 0)

        local hint = W.Text(header, "The salesperson sells one piece per shop day when auto-sell is on.", 9, T.colors.dim)
        hint:SetPoint("RIGHT", -164, 0)
        hint:SetJustifyH("RIGHT")
        hint:SetWidth(230)

        local list = W.Panel(parent, "panel")
        list:SetPoint("TOPLEFT", 0, -70)
        list:SetPoint("BOTTOMRIGHT", 0, 0)

        local scroll, content = W.Scroll(list)
        scroll:SetPoint("TOPLEFT", 6, -8)
        scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        ui.scroll = scroll

        local ROW_HEIGHT = 84
        for index, def in ipairs(ns.Data.Employees) do
            local row = W.Create(content, "Frame")
            row:SetHeight(ROW_HEIGHT - 6)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
            row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            T.Fill(bg, 0.09, 0.075, 0.045, index % 2 == 0 and 0.5 or 0.25)

            local icon = W.Icon(row, 44, def.icon)
            icon:SetPoint("LEFT", 10, 6)

            local name = W.Text(row, def.name, 13, T.colors.gold)
            name:SetPoint("TOPLEFT", 66, -8)
            name:SetPoint("TOPRIGHT", -160, -8)

            local role = W.Text(row, def.role .. " · level 0", 10, T.colors.muted)
            role:SetPoint("TOPLEFT", 66, -26)

            local quote = W.Text(row, '"' .. (def.quote or "") .. '"', 10, T.colors.parchment)
            quote:SetPoint("TOPLEFT", 66, -42)
            quote:SetPoint("TOPRIGHT", -160, -42)
            quote:SetWordWrap(true)

            local fx = W.Text(row, def.fxText or "", 9, T.colors.green)
            fx:SetPoint("BOTTOMLEFT", 66, 8)

            local wage = W.Text(row, "", 9, T.colors.goldDim)
            wage:SetPoint("BOTTOMRIGHT", -160, 8)
            wage:SetJustifyH("RIGHT")
            wage:SetWidth(120)

            local action = W.Button(row, "Hire", 140, 28, function()
                local level = ns.Staff.Level(def.key)
                local ok, result
                if level <= 0 then
                    ok, result = ns.Staff.Hire(def.key)
                else
                    ok, result = ns.Staff.Promote(def.key)
                end
                if not ok then
                    ns.UI.Toast(result)
                    return
                end
                ns.UI.Toast(level <= 0 and (def.name .. " joined the shop.") or (def.name .. " was promoted."))
                ns.UI.Refresh()
            end, "primary")
            action:SetPoint("RIGHT", -12, 0)

            row.icon = icon
            row.name = name
            row.role = role
            row.quote = quote
            row.fx = fx
            row.wage = wage
            row.action = action
            row.def = def
            ui.rows[index] = row
        end

        function ui.Refresh()
            local db = ns.DB.Get()
            local tier = ns.Shop.TierInfo()
            ui.slots:SetText(string.format("Staff slots: %d / %d", ns.Staff.Count(), ns.Staff.Slots()))
            ui.wages:SetText(string.format("Wages: %s gc per shop day · rent and wages are charged every 15 minutes of play",
                U.comma(ns.Staff.TotalWages())))
            ui.autoButton:SetLabel("Auto-sell: " .. (db.settings.autoSell ~= false and "on" or "off"))
            ui.autoButton:SetTone(db.settings.autoSell ~= false and "primary" or "neutral")

            for _, row in ipairs(ui.rows) do
                local def = row.def
                local level = ns.Staff.Level(def.key)
                local maxLevel = def.maxLevel or 5
                local unlocked = (def.minTier or 1) <= db.tier
                local cost = ns.Data.EmployeeCost(def, level)
                local wage = ns.Data.EmployeeWage(def, level)

                row.role:SetText(string.format("%s · level %d / %d%s",
                    def.role, level, maxLevel, level > 0 and "" or " (not hired)"))
                row.wage:SetText(wage > 0 and (U.comma(wage) .. " gc / day") or "no wages")

                if not unlocked then
                    row.action:SetLabel("Requires " .. ns.Data.Tier(def.minTier or 1).name)
                    row.action:SetState(false)
                    row.name:SetTextColor(0.55, 0.5, 0.4)
                elseif level >= maxLevel then
                    row.action:SetLabel("Max level")
                    row.action:SetState(false)
                    row.name:SetTextColor(T.colors.gold[1], T.colors.gold[2], T.colors.gold[3])
                elseif level == 0 then
                    row.action:SetLabel("Hire — " .. U.comma(cost))
                    row.action:SetState(db.credits >= cost and ns.Staff.Count() < ns.Staff.Slots())
                    row.name:SetTextColor(T.colors.gold[1], T.colors.gold[2], T.colors.gold[3])
                else
                    row.action:SetLabel("Promote — " .. U.comma(cost))
                    row.action:SetState(db.credits >= cost)
                    row.name:SetTextColor(T.colors.green[1], T.colors.green[2], T.colors.green[3])
                end
            end

            scroll:SetContentHeight(#ns.Data.Employees * 84 + 8)
        end

        return ui
    end,
}
