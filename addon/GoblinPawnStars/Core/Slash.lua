--[[ Goblin Pawn Stars -------------------------------------------------------
    Core/Slash.lua
    /gps and /goblinpawnstars. Kept deliberately thin: every command delegates
    to a module or the UI, so nothing here runs at load time.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...

local pendingReset = 0

local function printHelp()
    ns.Print("Commands:")
    ns.Print("  |cff7bd66b/gps|r — open or close the shop")
    ns.Print("  |cff7bd66b/gps arrival|r — preview the customer entrance")
    ns.Print("  |cff7bd66b/gps test|r — run the built-in diagnostics")
    ns.Print("  |cff7bd66b/gps debug|r — toggle debug messages")
    ns.Print("  |cff7bd66b/gps reset|r — wipe all shop progress (asks twice)")
    ns.Print("  |cff7bd66b/gps backup|r — open Settings > Backup & Restore")
    ns.Print("  |cff7bd66b/gps welcome|r — show the welcome/update screen")
    ns.Print("  |cff7bd66b/gps guide|r — replay the guided tour")
    ns.Print("  |cff7bd66b/gps scan|r — scan bags and report what the addon sees")
    ns.Print("  |cff7bd66b/gps importbags|r — stock eligible items already in your bags")
    ns.Print("  |cff7bd66b/gps wholesale|r — open the wholesaler's bulk stock")
    ns.Print("  |cff7bd66b/gps options|r — open the game's AddOn options panel")
    ns.Print("  |cff7bd66b/gps version|r — print the version and interface number")
end

local function handleReset()
    local now = ns.Util.now()
    if now - pendingReset > 20 then
        pendingReset = now
        ns.Warn("This wipes every Goblin Credit, item, upgrade and achievement.")
        ns.Warn("Type |cffffffff/gps reset|r again within 20 seconds to confirm.")
        return
    end
    pendingReset = 0
    ns.DB.Reset()
    if ns.Throughput then ns.Throughput.Reset() end
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh(true) end
    ns.Print("Shop reset. The goblin council has confiscated everything.")
end

local function handler(message)
    local command = ns.Util.trim(ns.Util.lower(message or ""))
    local first = command:match("^(%S*)") or ""

    if first == "" then
        if ns.UI and ns.UI.Toggle then ns.UI.Toggle() end
        return
    end

    if first == "test" or first == "diag" or first == "diagnostics" then
        ns.Diagnostics.Report()
        return
    end

    if first == "arrival" then
        local arrival = ns.UI and ns.UI.CustomerArrival
        if not arrival then
            ns.Warn("Customer arrival preview did not load.")
            return
        end
        local ok, result = pcall(arrival.Show, {
            name = "Goblin merchant", race = "Goblin", class = "ROGUE",
        }, true)
        if not ok then
            pcall(arrival.Hide)
            ns.Warn("Customer arrival preview failed: " .. tostring(result))
        elseif not result then
            ns.Warn("Could not create the customer arrival card.")
        end
        return
    end

    if first == "debug" then
        ns.debugEnabled = not ns.debugEnabled
        ns.Print("Debug messages " .. (ns.debugEnabled and "enabled" or "disabled") .. ".")
        return
    end

    if first == "reset" then
        handleReset()
        return
    end

    if first == "backup" then
        if ns.UI and ns.UI.ShowTab then
            ns.UI.ShowTab("settings")
            ns.UI.Open()
        end
        ns.Print("Backup and restore live in the Settings tab.")
        return
    end

    if first == "welcome" then
        if ns.UI.Welcome then ns.UI.Welcome.Show() end
        return
    end

    if first == "guide" or first == "tour" then
        if ns.UI.Tour then
            ns.UI.Tour.Start(1)
        else
            ns.Print("The guided tour is unavailable.")
        end
        return
    end

    if first == "scan" or first == "bags" then
        local added, deferred = ns.Loot.Scan(true)
        local d = ns.Loot.Diagnose()
        ns.Print(string.format("Bag scan: %d bag(s), %d stack(s), %d item(s); baseline: %d stack(s).",
            d.bags, d.stacks, d.items, d.baselineStacks))
        ns.Print(string.format("Eligible stacks: %d · skipped: %d (grey, quest, key) · uncached: %d.",
            d.eligible, d.skipped, d.uncached))
        if not d.readable then
            ns.Warn("No readable containers. The bag API may be unavailable on this client.")
        end
        if added > 0 then
            ns.Print(string.format("Stocked %d new stack(s).", added))
        elseif deferred > 0 then
            ns.Warn(string.format("%d gain(s) waiting for item data or free storage.", deferred))
        else
            ns.Print("No new eligible items since the last scan.")
        end
        return
    end

    if first == "importbags" or first == "stockbags" then
        local added, items, readable = ns.Loot.ImportCurrentBags()
        if not readable then
            ns.Warn("No readable containers. Nothing to import.")
        elseif added > 0 then
            ns.Print(string.format("Imported %d stack(s), %d item(s) from your bags.", added, items))
        else
            ns.Print("Nothing new to import: eligible items are already stocked.")
        end
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        return
    end

    if first == "wholesale" or first == "supplier" then
        if ns.UI and ns.UI.Wholesaler then
            ns.UI.Wholesaler.Show()
        else
            ns.Print("The wholesaler is unavailable.")
        end
        return
    end

    if first == "options" or first == "config" then
        if ns.UI.OpenOptions then
            ns.UI.OpenOptions()
        elseif ns.UI.ShowTab then
            ns.UI.ShowTab("settings")
            ns.UI.Open()
        end
        return
    end

    if first == "version" then
        ns.Print(string.format("Version %s · Interface %d · by %s · %d customers served.",
            ns.VERSION, ns.INTERFACE, ns.CREDIT, ns.DB.Get().stats.customersServed or 0))
        return
    end

    if first == "help" then
        printHelp()
        return
    end

    printHelp()
end

SLASH_GOBLINPAWNSTARS1 = "/gps"
SLASH_GOBLINPAWNSTARS2 = "/goblinpawnstars"
SlashCmdList["GOBLINPAWNSTARS"] = handler
