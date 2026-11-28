--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Tabs/Settings.lua
    Options, the minimap toggle, diagnostics and a copy-paste backup/restore
    path. The backup exists because the current Forever beta writes
    SavedVariables but does not load them back.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local U = ns.Util
local T = ns.Theme
local W = ns.Widgets

ns.UI.Tabs.settings = {
    title = "Settings",
    icon = "Interface\\Icons\\INV_Misc_Gear_01",
    Create = function(parent)
        local ui = {}
        local resetArmed = false

        local options = W.Panel(parent, "panel")
        options:SetPoint("TOPLEFT", 0, 0)
        options:SetSize(380, 410)

        local optionsTitle = W.Text(options, "OPTIONS", 10, T.colors.goldDim)
        optionsTitle:SetPoint("TOPLEFT", 12, -10)

        local toggles = {}

        local function toggle(label, getter, setter, offset)
            local row = W.Create(options, "Frame")
            row:SetPoint("TOPLEFT", 12, offset)
            row:SetPoint("TOPRIGHT", -12, offset)
            row:SetHeight(32)

            local name = W.Text(row, label, 11, T.colors.parchment)
            name:SetPoint("LEFT", 0, 0)

            local value = getter()
            local button = W.Button(row, value and "On" or "Off", 64, 22, function()
                local newValue = not getter()
                setter(newValue)
                ui.Refresh()
            end, value and "primary" or "neutral")
            button:SetPoint("RIGHT", 0, 0)
            toggles[#toggles + 1] = function()
                local enabled = getter()
                button:SetLabel(enabled and "On" or "Off")
                button:SetTone(enabled and "primary" or "neutral")
            end
        end

        toggle("Sound effects", function()
            return ns.DB.Get().settings.sound ~= false
        end, function(value)
            ns.DB.Get().settings.sound = value
            if ns.Sound then ns.Sound.Play("open") end
        end, -30)

        toggle("Minimap coin button", function()
            return ns.DB.Get().settings.minimap ~= false
        end, function(value)
            ns.DB.Get().settings.minimap = value
            if ns.UI.UpdateMinimap then ns.UI.UpdateMinimap() end
        end, -66)

        toggle("Collect items from bags", function()
            return ns.DB.Get().settings.autoCollect ~= false
        end, function(value)
            ns.DB.Get().settings.autoCollect = value
        end, -102)

        toggle("Salesperson works the queue", function()
            return ns.DB.Get().settings.autoSell ~= false
        end, function(value)
            ns.DB.Get().settings.autoSell = value
        end, -138)

        toggle("Pause the simulation", function()
            return ns.DB.Get().settings.paused == true
        end, function(value)
            ns.DB.Get().settings.paused = value
            ns.UI.Refresh()
        end, -174)

        local nextArrivalMode = { Animated = "Compact", Compact = "Off", Off = "Animated" }
        local function arrivalMode()
            local value = ns.DB.Get().settings.customerArrival
            return nextArrivalMode[value] and value or "Animated"
        end

        local arrivalLabel = W.Text(options, "Arrival notification", 11, T.colors.parchment)
        arrivalLabel:SetPoint("TOPLEFT", 12, -236)
        local arrivalButton = W.Button(options, arrivalMode(), 90, 22, function(_, self)
            local value = nextArrivalMode[arrivalMode()]
            ns.DB.Get().settings.customerArrival = value
            if ns.UI.CustomerArrival then ns.UI.CustomerArrival.Hide() end
            self:SetLabel(value)
        end, "neutral")
        arrivalButton:SetPoint("TOPRIGHT", -12, -232)

        local nextPace = { Normal = "Fast", Fast = "Relaxed", Relaxed = "Normal" }
        local paceLabel = W.Text(options, "Customer arrival pace", 11, T.colors.parchment)
        paceLabel:SetPoint("TOPLEFT", 12, -266)
        local paceButton = W.Button(options, ns.Shop.ArrivalPace(), 90, 22, function()
            ns.Shop.SetArrivalPace(nextPace[ns.Shop.ArrivalPace()])
            ns.UI.Refresh()
        end, "neutral")
        paceButton:SetPoint("TOPRIGHT", -12, -262)

        local scaleLabel = W.Text(options, "Window scale", 11, T.colors.parchment)
        scaleLabel:SetPoint("TOPLEFT", 12, -208)

        local scaleValue = W.Text(options, "100%", 10, T.colors.gold)
        scaleValue:SetPoint("TOPLEFT", 130, -209)
        scaleValue:SetWidth(60)

        local function applyScale(delta)
            local db = ns.DB.Get()
            db.settings.scale = U.clamp((db.settings.scale or 1) + delta, 0.8, 1.2)
            if ns.UI.MainFrame and ns.UI.MainFrame.SetScale then
                ns.UI.MainFrame:SetScale(db.settings.scale)
            end
            scaleValue:SetText(math.floor(db.settings.scale * 100 + 0.5) .. "%")
        end

        local minus = W.Button(options, "−", 30, 22, function() applyScale(-0.05) end, "neutral")
        minus:SetPoint("TOPLEFT", 250, -204)
        local plus = W.Button(options, "+", 30, 22, function() applyScale(0.05) end, "neutral")
        plus:SetPoint("TOPLEFT", 286, -204)

        toggle("Questing auto-sell (1/3 max offer)", function()
            return ns.DB.Get().settings.questAutoSell == true
        end, function(value)
            ns.DB.Get().settings.questAutoSell = value
        end, -286)

        local scan = W.Button(options, "Scan bags", 110, 24, function()
            local added, deferred = ns.Loot.Scan(true)
            if added > 0 then
                ns.UI.Toast(string.format("%d new stack%s stocked.", added, added == 1 and "" or "s"))
            elseif deferred > 0 then
                ns.UI.Toast("A gain is waiting for item data or free storage. Try again shortly.")
            else
                ns.UI.Toast("No new eligible items since the last scan. Use Stock Bags Now to import current bags.")
            end
            ns.UI.Refresh()
        end, "gold")
        scan:SetPoint("TOPLEFT", 12, -322)

        local diag = W.Button(options, "Diagnostics", 110, 24, function()
            ns.Diagnostics.Report()
            ns.UI.Toast("Diagnostics printed to chat.")
        end, "neutral")
        diag:SetPoint("TOPLEFT", 126, -322)

        local welcome = W.Button(options, "Welcome", 110, 24, function()
            if ns.UI.Welcome then ns.UI.Welcome.Show() end
        end, "neutral")
        welcome:SetPoint("TOPLEFT", 240, -322)

        local about = W.Text(options,
            "|cff9c8a5aWorld of Warcraft: Forever · Interface 16001 · Created by ErrorSeib & Buffy (Codebuff).\n" ..
            "All currency, items and customers are fictional. Nothing here touches your real bags, gold or the game world.|r",
            9, T.colors.dim)
        about:SetPoint("TOPLEFT", 12, -354)
        about:SetPoint("TOPRIGHT", -12, -354)
        about:SetHeight(46)
        about:SetWordWrap(true)

        -----------------------------------------------------------------
        -- Backup
        -----------------------------------------------------------------
        local backup = W.Panel(parent, "panel")
        backup:SetPoint("TOPLEFT", 388, 0)
        backup:SetPoint("TOPRIGHT", 0, 0)
        backup:SetHeight(400)

        local backupTitle = W.Text(backup, "BACKUP & RESTORE", 10, T.colors.goldDim)
        backupTitle:SetPoint("TOPLEFT", 12, -10)

        local saveNowButton = W.Button(backup, "Save Now", 90, 20, function()
            if not ns.Journal then return end
            local ok, status = ns.Journal.SaveNow(true)
            if ok then
                ui.status:SetText(string.format("|cff5fd64fJournal saved: %d chunks.|r",
                    status and status.chunks or 0))
            else
                ui.status:SetText("|cffff6b5e" .. tostring(ns.Journal.StatusText()) .. "|r")
            end
            if ns.UI.Refresh then ns.UI.Refresh() end
        end, "primary")
        saveNowButton:SetPoint("TOPRIGHT", -126, -26)

        local rollingButton = W.Button(backup, "Rolling backups", 110, 20, function()
            if ns.UI.BackupFrame then ns.UI.BackupFrame.Show() end
        end, "neutral")
        rollingButton:SetPoint("TOPRIGHT", -12, -26)

        -- Loading is automatic but bounded: a short login load reads the macro
        -- journal at most four times and then settles. This button repeats one
        -- read on demand, and asks twice because it replaces the run in memory.
        local loadArmed = false
        local loadButton = W.Button(backup, "Load saved", 90, 20, function(_, self)
            if not loadArmed then
                loadArmed = true
                self:SetLabel("Confirm load")
                self:SetTone("danger")
                ns.Compat.After(8, function()
                    loadArmed = false
                    self:SetLabel("Load saved")
                    self:SetTone("neutral")
                end)
                ui.status:SetText("|cffffcc55Load the saved shop? This replaces the run in memory.|r")
                return
            end
            loadArmed = false
            self:SetLabel("Load saved")
            self:SetTone("neutral")
            if not ns.Journal or not ns.Journal.Load then return end
            local ok, detail = ns.Journal.Load()
            ui.status:SetText((ok and "|cff5fd64f" or "|cffff6b5e") .. tostring(detail) .. "|r")
            if ns.UI.Refresh then ns.UI.Refresh(true) end
        end, "neutral")
        loadButton:SetPoint("TOPRIGHT", -220, -26)

        local backupNote = W.Text(backup,
            "Copy this string somewhere safe, or paste an old one and restore.\n" ..
            "|cffffcc55Beta workaround:|r Forever does not load SavedVariables. Progress checkpoints into macro bodies; a load runs shortly after login unless auto-load is off.",
            9, T.colors.muted)
        backupNote:SetPoint("TOPLEFT", 12, -52)
        backupNote:SetPoint("TOPRIGHT", -12, -52)
        backupNote:SetHeight(52)
        backupNote:SetWordWrap(true)
        backupNote:SetSpacing(2)

        local box = W.MultiLine(backup, 320, 112, 120000)
        box:SetPoint("TOPLEFT", 12, -110)
        box:SetPoint("TOPRIGHT", -12, -110)
        box:SetText("")

        local exportButton = W.Button(backup, "Export", 96, 26, function()
            box:SetText(ns.DB.Export())
            box:SetFocus()
            box:HighlightText()
            ui.status:SetText("|cff5fd64fBackup generated. Copy it somewhere safe.|r")
        end, "gold")
        exportButton:SetPoint("TOPLEFT", 12, -236)

        local importButton = W.Button(backup, "Import", 96, 26, function()
            local text = box:GetText() or ""
            local ok, err = ns.DB.Import(text)
            if not ok then
                ui.status:SetText("|cffff6b5e" .. tostring(err) .. "|r")
                return
            end
            ui.status:SetText("|cff5fd64fBackup restored.|r")
            if ns.UI.Refresh then ns.UI.Refresh() end
        end, "primary")
        importButton:SetPoint("TOPLEFT", 116, -236)

        local clearButton = W.Button(backup, "Clear box", 96, 26, function()
            box:SetText("")
        end, "neutral")
        clearButton:SetPoint("TOPLEFT", 220, -236)

        ui.status = W.Text(backup, "", 9, T.colors.muted)
        ui.status:SetPoint("TOPLEFT", 12, -268)
        ui.status:SetPoint("TOPRIGHT", -12, -268)
        ui.status:SetHeight(24)
        ui.status:SetWordWrap(true)

        -- Auto-load is the one read that happens without being asked. Turning it
        -- off leaves Load saved as the only way in; nothing else changes.
        local autoToggle = W.Button(backup, "Auto-load: On", 132, 22, function()
            local db = ns.DB.Get()
            db.settings.autoLoadJournal = db.settings.autoLoadJournal == false
            if ns.UI.Refresh then ns.UI.Refresh() end
        end, "primary")
        autoToggle:SetPoint("TOPLEFT", 12, -296)

        local resetButton = W.Button(backup, "Reset all progress", 170, 28, function(_, self)
            if not resetArmed then
                resetArmed = true
                self:SetLabel("Click again to confirm")
                self:SetTone("danger")
                ns.Compat.After(8, function()
                    resetArmed = false
                    self:SetLabel("Reset all progress")
                    self:SetTone("neutral")
                end)
                return
            end
            resetArmed = false
            ns.DB.Reset()
            self:SetLabel("Reset all progress")
            self:SetTone("neutral")
            ui.status:SetText("|cffff6b5eShop reset. A fresh start, a fresh debt.|r")
            if ns.UI.Refresh then ns.UI.Refresh(true) end
        end, "danger")
        resetButton:SetPoint("BOTTOMLEFT", 12, 16)

        -- Short enough to sit beside the reset button instead of under it.
        local version = W.Text(backup, string.format("v%s · schema %d",
            ns.VERSION, ns.DB.SchemaVersion()), 9, T.colors.dim)
        version:SetPoint("BOTTOMRIGHT", -12, 18)
        version:SetJustifyH("RIGHT")

        -- One switch for a lighter client: class icons instead of PlayerModels,
        -- instant animation paths, and the compact arrival card. It is an
        -- overlay, so turning it off restores the player's existing choices.
        local performanceButton = W.Button(options, "Performance: Off", 132, 22, function()
            local db = ns.DB.Get()
            db.settings.performance = db.settings.performance ~= true
            if ns.UI.CustomerArrival then ns.UI.CustomerArrival.Hide() end
            if ns.UI.Negotiation and ns.UI.Negotiation.Refresh then
                pcall(ns.UI.Negotiation.Refresh)
            end
            if ns.UI and ns.UI.Refresh then ns.UI.Refresh(true) end
        end, "neutral")
        performanceButton:SetPoint("TOPRIGHT", -12, -4)

        function ui.Refresh()
            for _, refreshToggle in ipairs(toggles) do refreshToggle() end
            paceButton:SetLabel(ns.Shop.ArrivalPace())
            arrivalButton:SetLabel(arrivalMode())
            scaleValue:SetText(math.floor((ns.DB.Get().settings.scale or 1) * 100 + 0.5) .. "%")
            local performance = ns.DB.Get().settings.performance == true
            performanceButton:SetLabel("Performance: " .. (performance and "On" or "Off"))
            performanceButton:SetTone(performance and "primary" or "neutral")
            local autoLoad = ns.DB.Get().settings.autoLoadJournal ~= false
            autoToggle:SetLabel("Auto-load: " .. (autoLoad and "On" or "Off"))
            autoToggle:SetTone(autoLoad and "primary" or "neutral")
        end

        return ui
    end,
}
