--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Tabs/Upgrades.lua
    Shop tiers and the permanent upgrades that make the business run better.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

ns.UI.Tabs.upgrades = {
    title = "Upgrades",
    icon = "Interface\\Icons\\INV_Misc_Bag_14",
    Create = function(parent)
        local ui = { rows = {} }

        local tierPanel = W.Panel(parent, "parchment")
        tierPanel:SetPoint("TOPLEFT", 0, 0)
        tierPanel:SetPoint("TOPRIGHT", 0, 0)
        tierPanel:SetHeight(104)

        local tierIcon = W.Icon(tierPanel, 54, T.tierIcons[1])
        tierIcon:SetPoint("LEFT", 14, 0)

        ui.tierName = W.Text(tierPanel, "", 18, T.colors.gold)
        ui.tierName:SetPoint("TOPLEFT", 82, -12)
        ui.tierName:SetPoint("TOPRIGHT", -230, -12)

        ui.tierBlurb = W.Text(tierPanel, "", 10, T.colors.muted)
        ui.tierBlurb:SetPoint("TOPLEFT", 82, -36)
        ui.tierBlurb:SetPoint("TOPRIGHT", -230, -36)
        ui.tierBlurb:SetWordWrap(true)

        ui.tierStats = W.Text(tierPanel, "", 10, T.colors.text)
        ui.tierStats:SetPoint("BOTTOMLEFT", 82, 12)
        ui.tierStats:SetPoint("BOTTOMRIGHT", -16, 12)

        ui.tierButton = W.Button(tierPanel, "Upgrade Shop", 200, 34, function()
            local ok, result = ns.Shop.UpgradeTier()
            if not ok then
                ns.UI.Toast(result)
                return
            end
            ns.UI.Toast("Welcome to " .. result.name .. "!")
            ns.UI.Refresh()
        end, "primary")
        ui.tierButton:SetPoint("TOPRIGHT", -14, -18)

        ui.tierButtonNote = W.Text(tierPanel, "", 9, T.colors.muted)
        ui.tierButtonNote:SetPoint("TOPRIGHT", -14, -58)
        ui.tierButtonNote:SetWidth(190)
        ui.tierButtonNote:SetJustifyH("RIGHT")

        local list = W.Panel(parent, "panel")
        list:SetPoint("TOPLEFT", 0, -112)
        list:SetPoint("BOTTOMRIGHT", 0, 0)

        local scroll, content = W.Scroll(list)
        scroll:SetPoint("TOPLEFT", 6, -8)
        scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        ui.scroll = scroll

        local ROW_HEIGHT = 66
        for index, def in ipairs(ns.Data.Upgrades) do
            local row = W.Create(content, "Frame")
            row:SetHeight(ROW_HEIGHT - 6)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
            row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            T.Fill(bg, 0.09, 0.075, 0.045, index % 2 == 0 and 0.5 or 0.25)

            local icon = W.Icon(row, 34, def.icon)
            icon:SetPoint("LEFT", 8, 0)

            local name = W.Text(row, def.name, 12, T.colors.parchment)
            name:SetPoint("TOPLEFT", 52, -8)
            name:SetPoint("TOPRIGHT", -150, -8)

            local level = W.Text(row, "", 9, T.colors.goldDim)
            level:SetPoint("TOPLEFT", 52, -25)

            local fx = W.Text(row, def.fxText or "", 9, T.colors.green)
            fx:SetPoint("TOPLEFT", 180, -25)

            local desc = W.Text(row, def.description or "", 9, T.colors.muted)
            desc:SetPoint("TOPLEFT", 52, -38)
            desc:SetPoint("TOPRIGHT", -150, -38)

            local buy = W.Button(row, "Buy", 120, 26, function()
                local ok, result = ns.Shop.BuyUpgrade(def.key)
                if not ok then
                    ns.UI.Toast(result)
                    return
                end
                ns.UI.Toast(def.name .. " improved.")
                ns.UI.Refresh()
            end, "gold")
            buy:SetPoint("RIGHT", -10, 0)

            row.icon = icon
            row.name = name
            row.level = level
            row.fx = fx
            row.desc = desc
            row.buy = buy
            row.def = def
            ui.rows[index] = row
        end

        function ui.Refresh()
            local db = ns.DB.Get()
            local tier = ns.Shop.TierInfo()
            local nextTier = ns.Shop.NextTier()

            tierIcon:SetIcon(T.tierIcons[db.tier] or T.tierIcons[1])
            ui.tierName:SetText(tier.name)
            ui.tierBlurb:SetText(tier.blurb or "")
            ui.tierStats:SetText(string.format(
                "Storage %d  ·  New customer every %ds  ·  Budget %s gc  ·  Appraisal %d%%  ·  Employees %d",
                ns.Inventory.Capacity(), ns.Shop.ArrivalInterval(), U.comma(tier.budget),
                ns.Shop.Appraisal(), tier.employees or 0))

            if nextTier then
                if db.credits >= nextTier.cost then
                    ui.tierButton:SetLabel("Upgrade — " .. U.comma(nextTier.cost) .. " gc")
                    ui.tierButton:SetState(true)
                    ui.tierButtonNote:SetText("Unlocks: " .. tostring(nextTier.storage) .. " storage, " ..
                        tostring(nextTier.employees) .. " staff slots, wealthier customers")
                else
                    ui.tierButton:SetLabel(U.comma(nextTier.cost) .. " gc needed")
                    ui.tierButton:SetState(false)
                    ui.tierButtonNote:SetText("Keep trading, or sell a few rare pieces.")
                end
            else
                ui.tierButton:SetLabel("Top tier reached")
                ui.tierButton:SetState(false)
                ui.tierButtonNote:SetText("The council sends its grudging respect.")
            end

            for _, row in ipairs(ui.rows) do
                local def = row.def
                local level = db.upgrades[def.key] or 0
                local unlocked = ns.Data.UpgradeUnlocked(def, db.tier)
                local cost = ns.Data.UpgradeCost(def, level)
                row.level:SetText(string.format("Level %d / %d", level, def.maxLevel or 1))

                if not unlocked then
                    row.buy:SetLabel("Requires tier " .. tostring(def.minTier))
                    row.buy:SetState(false)
                    row.name:SetTextColor(0.55, 0.5, 0.4)
                elseif level >= (def.maxLevel or 1) then
                    row.buy:SetLabel("Maxed")
                    row.buy:SetState(false)
                    row.name:SetTextColor(T.colors.parchment[1], T.colors.parchment[2], T.colors.parchment[3])
                else
                    row.buy:SetLabel(U.comma(cost) .. " gc")
                    row.buy:SetState(db.credits >= cost)
                    row.name:SetTextColor(T.colors.parchment[1], T.colors.parchment[2], T.colors.parchment[3])
                end
            end

            scroll:SetContentHeight(#ns.Data.Upgrades * 66 + 8)
        end

        return ui
    end,
}
