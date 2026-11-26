-- Campaign-length progression probe, loaded by tools/sim_campaign.js.
--
-- Plays the real addon under the WoW mock for several hours with a fixed shop
-- policy: sell, pay the deed notes, hire the salesperson, buy tiers and
-- upgrades, donate to the museum and call Marta. It reports time-to-milestone,
-- credits/hour per tier and anything that looks like a grind wall.
--
-- Dev-only. Nothing here ships in the addon and nothing is added to the TOC.

local function clockText(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function perHour(amount, seconds)
    if seconds <= 0 then return 0 end
    return (tonumber(amount) or 0) / (seconds / 3600)
end

local function median(values)
    local copy = {}
    for index = 1, #values do copy[index] = values[index] end
    table.sort(copy)
    local count = #copy
    if count == 0 then return nil end
    if count % 2 == 1 then return copy[(count + 1) / 2] end
    return (copy[count / 2] + copy[count / 2 + 1]) / 2
end

local function comma(value)
    return __NS.Util.comma(math.floor(tonumber(value) or 0))
end

-- Options that end a random encounter without spending credits or stock.
local SAFE_ENCOUNTER_OPTIONS = {
    refuse = true, decline = true, ignore = true, leave = true, pass = true, skip = true,
}

local NOTE_LABELS = { "First note", "Second note", "Final note" }

local TIER_UPGRADE_ORDER = {
    "shelves", "sign", "haggling_manual", "lounge",
    "display_case", "ledger", "lens", "plaque", "security",
}

---------------------------------------------------------------------------
-- One run
---------------------------------------------------------------------------

local function runOne(seed, opts)
    local ns = __NS
    local real = ns.db
    local db = ns.DB.Scratch()
    ns.db = db
    math.randomseed(seed)
    ns.Throughput.Reset()
    db.shop.nextArrival = 18
    db.settings.autoSell = true
    db.settings.questAutoSell = false
    db.settings.arrivalPace = "Normal"
    ns.Wholesaler.GrantStarter()

    local run = {
        seed = seed, opts = opts, milestones = {}, tiers = {}, samples = {},
        museumDone = false, martaDone = false,
    }

    local segment

    local function openSegment(at)
        segment = {
            tier = db.tier,
            start = at,
            revenue = db.stats.revenue or 0,
            wholesale = db.stats.wholesaleSpent or 0,
            expenses = db.stats.expenses or 0,
            spent = db.stats.spent or 0,
            debt = db.stats.debtPaid or 0,
            sales = db.stats.sales or 0,
            credits = db.credits or 0,
        }
    end

    local function closeSegment(at)
        if not segment then return end
        local wholesaleNow = db.stats.wholesaleSpent or 0
        local spentNow = db.stats.spent or 0
        local debtNow = db.stats.debtPaid or 0

        local capitalBase = segment.spent - segment.wholesale - segment.debt
        local revenue = (db.stats.revenue or 0) - segment.revenue
        local wholesale = wholesaleNow - segment.wholesale
        local expenses = (db.stats.expenses or 0) - segment.expenses
        local capital = (spentNow - wholesaleNow - debtNow) - capitalBase

        run.tiers[#run.tiers + 1] = {
            tier = segment.tier,
            seconds = at - segment.start,
            sales = (db.stats.sales or 0) - segment.sales,
            revenue = revenue,
            wholesale = wholesale,
            expenses = expenses,
            capital = capital,
            net = revenue - wholesale - expenses - capital,
            retained = (db.credits or 0) - segment.credits,
        }
        segment = nil
    end

    local function milestone(key, label, at)
        run.milestones[#run.milestones + 1] = {
            key = key,
            label = label,
            at = at,
            credits = db.credits or 0,
        }
    end

    local function hasMilestone(key)
        for _, entry in ipairs(run.milestones) do
            if entry.key == key then return true end
        end
        return false
    end

    local function floatNeeded()
        return 120 + (db.tier or 1) * 100
    end

    local function resolveEncounter()
        local event = ns.Encounters.Pending()
        if not event or type(event.options) ~= "table" or #event.options == 0 then return end
        local choice
        for _, option in ipairs(event.options) do
            if not option.disabled and SAFE_ENCOUNTER_OPTIONS[option.id] then
                choice = option
                break
            end
        end
        if not choice then
            for index = #event.options, 1, -1 do
                if not event.options[index].disabled then
                    choice = event.options[index]
                    break
                end
            end
        end
        if choice then pcall(ns.Encounters.Resolve, choice.id) end
    end

    local function negotiate()
        local customer = db.shop.current
        if not customer then return end

        if not opts.haggle then
            ns.Negotiation.Accept()
            return
        end

        local record = ns.Inventory.Get(customer.itemUid)
        if not record then return end
        local value = ns.Market.Value(record)

        if ns.Negotiation.Unlocked() and not customer.appraised then
            pcall(ns.Negotiation.Appraise)
        end

        local target
        if customer.revealed and customer.maxPay then
            -- Appraisal revealed the ceiling exactly; stay just under it.
            target = math.floor(customer.maxPay * 0.95)
        else
            -- A fair ask a little over market, never near the insult threshold.
            target = math.floor(value * 1.05)
        end

        if target > (customer.offer or 0) then
            local ok, result = ns.Negotiation.Counter(target)
            if ok and result and result.result == "declined" then
                -- Take the raised offer instead of risking a walkout.
                ns.Negotiation.Accept()
            end
        else
            ns.Negotiation.Accept()
        end
    end

    local function missingMuseumKey()
        if not ns.Museum or not ns.Museum.Unlocked() or ns.Museum.Completed() then return nil end
        for _, slot in ipairs(ns.Data.Museum.slots) do
            if not ns.Museum.Donated(slot.key) then return slot.key end
        end
        return nil
    end

    local function buyStock(floorStock)
        local want = missingMuseumKey()
        local lots = ns.Wholesaler.Lots()
        if want then
            for _, lot in ipairs(lots) do
                if not lot.bought and lot.category == want and lot.quality >= 2
                    and (db.credits or 0) >= lot.cost + floatNeeded()
                    and ns.Inventory.Free() > 0 then
                    ns.Wholesaler.Buy(lot.position)
                    return
                end
            end
        end
        if ns.Inventory.Count() >= (floorStock or 8) then return end
        local bought = 0
        for _, lot in ipairs(lots) do
            if not lot.bought
                and (db.credits or 0) - lot.cost >= floatNeeded()
                and ns.Inventory.Free() > 0 then
                if ns.Wholesaler.Buy(lot.position) then bought = bought + 1 end
                if bought >= 2 then break end
            end
        end
    end

    local function buyUpgrade()
        for _, key in ipairs(TIER_UPGRADE_ORDER) do
            local def = ns.Data.UpgradeByKey[key]
            local level = db.upgrades[key] or 0
            if def and level < def.maxLevel and (def.minTier or 1) <= db.tier then
                local cost = ns.Data.UpgradeCost(def, level)
                if (db.credits or 0) - cost >= floatNeeded() then
                    if ns.Shop.BuyUpgrade(key) then return true end
                end
            end
        end
        return false
    end

    -- Rolling revenue rate, used to judge whether the next tier pays for itself.
    local rateBaseRevenue = db.stats.revenue or 0
    local rateBaseAt = 0
    local revenuePerHour = 0

    local function refreshRate(at)
        if at <= rateBaseAt then return end
        revenuePerHour = perHour((db.stats.revenue or 0) - rateBaseRevenue, at - rateBaseAt)
        rateBaseRevenue = db.stats.revenue or 0
        rateBaseAt = at
    end

    local function policy(at)
        resolveEncounter()

        if db.shop.current then
            negotiate()
        elseif #db.shop.waiting > 0 then
            ns.Customers.StartNegotiation(1)
            if db.shop.current then negotiate() end
        end

        local note = ns.Campaign.NextPayment()
        if note and (db.credits or 0) >= note.amount then
            if ns.Campaign.Pay() then
                local paid = db.campaign.payments or 0
                milestone("note" .. paid, NOTE_LABELS[paid] or ("Note " .. paid), at)
            end
        end
        note = ns.Campaign.NextPayment()
        -- A focused player pays the debt first: while the next note is not yet
        -- banked, discretionary purchases wait. Tiers still go ahead when the
        -- payback rule says they will earn the note faster.
        local focused = note ~= nil and (db.credits or 0) < note.amount
        local saving = focused

        if db.tier >= 3 and not saving then
            local salesperson = ns.Data.EmployeeByKey.salesperson
            local level = db.employees.salesperson or 0
            local cost = ns.Data.EmployeeCost(salesperson, level)
            if level == 0 and (db.credits or 0) - cost >= floatNeeded() then
                if ns.Staff.Hire("salesperson") then
                    milestone("salesperson", "Salesperson hired", at)
                end
            elseif level > 0 and level < (salesperson.maxLevel or 5)
                and (db.credits or 0) - cost >= floatNeeded() * 3 then
                ns.Staff.Promote("salesperson")
            end
        end

        -- Buy the next tier when it is affordable and pays itself back inside an
        -- hour of the current revenue rate. Saving for a note does not block a
        -- tier that will earn the next note faster.
        local nextTier = ns.Shop.NextTier()
        if nextTier and (db.credits or 0) >= nextTier.cost + floatNeeded() then
            local payback = revenuePerHour > 0 and (nextTier.cost / (revenuePerHour / 60)) or 999
            if opts.greedyTier or payback <= 60 then
                if ns.Shop.UpgradeTier() then
                    milestone("tier" .. db.tier, "Tier " .. db.tier .. " shop", at)
                end
            end
        end

        -- Marketing shortens the arrival gap, so it is worth buying even while
        -- saving for a note; the appraiser waits until the note is banked.
        if db.tier >= 3 and (db.employees.marketing or 0) == 0 then
            local marketing = ns.Data.EmployeeByKey.marketing
            local cost = ns.Data.EmployeeCost(marketing, 0)
            if (db.credits or 0) >= cost + floatNeeded() then
                if ns.Staff.Hire("marketing") then
                    milestone("marketing", "Marketing hired", at)
                end
            end
        end
        if not saving and db.tier >= 2 and (db.employees.appraiser or 0) == 0 then
            local appraiser = ns.Data.EmployeeByKey.appraiser
            local cost = ns.Data.EmployeeCost(appraiser, 0)
            if (db.credits or 0) >= cost + floatNeeded() + (note and note.amount or 0) then
                if ns.Staff.Hire("appraiser") then
                    milestone("appraiser", "Appraiser hired", at)
                end
            end
        end

        buyStock(saving and 5 or 8)

        -- Polish never eats the next note: upgrades are paid for from credits
        -- above the reserve a focused player would keep for the debt.
        local noteReserve = note and note.amount or 0
        if (db.credits or 0) - noteReserve - floatNeeded() >= 400 then
            buyUpgrade()
        end

        if ns.Museum and ns.Museum.Unlocked() and not ns.Museum.Completed() then
            for _, slot in ipairs(ns.Data.Museum.slots) do
                if ns.Museum.Eligible(slot.key) then
                    pcall(ns.Museum.Donate, slot.key)
                    break
                end
            end
        end
        if ns.Museum and ns.Museum.Completed() and not run.museumDone then
            run.museumDone = true
            milestone("museum", "Museum set complete", at)
        end

        if ns.Regular then
            if ns.Regular.CanCall() then pcall(ns.Regular.Call) end
            if ns.Regular.Done() and not run.martaDone then
                run.martaDone = true
                milestone("marta", "Marta's story complete", at)
            end
        end
    end

    local totalSeconds = math.floor((opts.hours or 4) * 3600)
    local nextSample = 900
    openSegment(0)

    for second = 1, totalSeconds do
        ns.Clock.OnTick(1)
        if second % 2 == 0 then policy(second) end
        if second % 300 == 0 then refreshRate(second) end
        if db.tier ~= segment.tier then
            closeSegment(second)
            openSegment(second)
        end
        if second >= nextSample then
            run.samples[#run.samples + 1] = {
                at = second,
                credits = db.credits or 0,
                tier = db.tier,
                notes = db.campaign.payments or 0,
                revenue = db.stats.revenue or 0,
                sales = db.stats.sales or 0,
                stock = ns.Inventory.Count(),
            }
            nextSample = nextSample + 900
        end
    end

    closeSegment(totalSeconds)

    run.final = {
        seconds = totalSeconds,
        credits = db.credits or 0,
        tier = db.tier,
        notes = db.campaign.payments or 0,
        completed = db.campaign.completed == true,
        revenue = db.stats.revenue or 0,
        sales = db.stats.sales or 0,
        wholesale = db.stats.wholesaleSpent or 0,
        expenses = db.stats.expenses or 0,
        debt = db.stats.debtPaid or 0,
        autoSales = db.stats.autoSales or 0,
        stock = ns.Inventory.Count(),
        museum = run.museumDone,
        marta = run.martaDone,
    }

    ns.db = real
    return run
end

---------------------------------------------------------------------------
-- Reporting
---------------------------------------------------------------------------

local function milestoneAt(run, key)
    for _, entry in ipairs(run.milestones) do
        if entry.key == key then return entry.at end
    end
    return nil
end

local function runFlags(run)
    local flags = {}
    local final = run.final
    local firstNote = milestoneAt(run, "note1")
    local secondNote = milestoneAt(run, "note2")
    local thirdNote = milestoneAt(run, "note3")
    local hourLimit = run.opts.hours * 3600

    if firstNote and firstNote > 30 * 60 then
        flags[#flags + 1] = string.format(
            "Slow opening: the first note takes %s, so the campaign hook lands late.",
            clockText(firstNote))
    end
    if secondNote and firstNote and (secondNote - firstNote) > 75 * 60 then
        flags[#flags + 1] = string.format(
            "Note 1 -> 2 takes %s (>75 min): the 6,000 gc step stalls the mid-game.",
            clockText(secondNote - firstNote))
    end
    if thirdNote and secondNote and (thirdNote - secondNote) > 90 * 60 then
        flags[#flags + 1] = string.format(
            "Note 2 -> 3 takes %s (>90 min): saving 25,000 gc is a grind wall.",
            clockText(thirdNote - secondNote))
    end
    if not final.completed then
        flags[#flags + 1] = string.format(
            "Campaign unfinished after %.1fh: %d/3 notes paid, %s gc banked.",
            run.opts.hours, final.notes, comma(final.credits))
    end
    if final.tier < 4 then
        flags[#flags + 1] = string.format(
            "Never reaches tier 4 (cost 32,000) in a campaign run; tier 5 (150,000) is far out of reach.")
    end

    local bestRate = 0
    for _, tier in ipairs(run.tiers) do
        local rate = perHour(tier.revenue, tier.seconds)
        if tier.seconds >= 600 then
            if bestRate > 0 and rate < bestRate * 0.7 then
                flags[#flags + 1] = string.format(
                    "Income dips at tier %d: %.0f gc/h versus %.0f gc/h earlier.",
                    tier.tier, rate, bestRate)
            end
            if rate > bestRate then bestRate = rate end
        end
    end

    if #flags == 0 then
        flags[#flags + 1] = "No wall detected: every note is reached inside the run and income holds."
    end
    local _ = hourLimit
    return flags
end

local function line(text)
    return text .. "\n"
end

local function reportRun(run, verbose)
    local out = {}
    local final = run.final
    out[#out + 1] = line(string.format(
        "Seed %d | %.1fh | policy %s%s | final %s gc, tier %d, %d/3 notes, %d sales, %.0f gc/h",
        run.seed, run.opts.hours,
        run.opts.haggle and "haggle" or "accept-only",
        run.opts.greedyTier and " + tier-first" or "",
        comma(final.credits), final.tier, final.notes, final.sales,
        perHour(final.revenue, final.seconds)))

    out[#out + 1] = line("")
    out[#out + 1] = line("Milestones")
    for _, entry in ipairs(run.milestones) do
        out[#out + 1] = line(string.format("  %-24s %7s   (%s gc banked)",
            entry.label, clockText(entry.at), comma(entry.credits)))
    end
    if #run.milestones == 0 then
        out[#out + 1] = line("  (none)")
    end

    if verbose then
        out[#out + 1] = line("")
        out[#out + 1] = line("Timeline (15 min)")
        local previous
        for _, sample in ipairs(run.samples) do
            local rate = 0
            if previous then
                rate = perHour(sample.revenue - previous.revenue, sample.at - previous.at)
            end
            out[#out + 1] = line(string.format(
                "  %5s | %8s gc | tier %d | %d/3 notes | %3d stock | %4.0f gc/h",
                clockText(sample.at), comma(sample.credits), sample.tier,
                sample.notes, sample.stock, rate))
            previous = sample
        end
    end

    out[#out + 1] = line("")
    out[#out + 1] = line("Per tier")
    out[#out + 1] = line(string.format(
        "  %-4s %-7s %6s %9s %9s %9s %8s %9s %9s",
        "tier", "time", "sales", "revenue", "rev/h", "stock", "expense", "capital", "net/h"))
    for _, tier in ipairs(run.tiers) do
        out[#out + 1] = line(string.format(
            "  %-4d %-7s %6d %9s %9.0f %9s %8s %9s %9.0f",
            tier.tier, clockText(tier.seconds), tier.sales, comma(tier.revenue),
            perHour(tier.revenue, tier.seconds), comma(tier.wholesale),
            comma(tier.expenses), comma(tier.capital), perHour(tier.net, tier.seconds)))
    end

    out[#out + 1] = line("")
    out[#out + 1] = line("Flags")
    for _, flag in ipairs(runFlags(run)) do
        out[#out + 1] = line("  ! " .. flag)
    end
    return table.concat(out)
end

local function reportAggregate(runs)
    local out = {}
    out[#out + 1] = line(string.format("%d seeds", #runs))
    out[#out + 1] = line(string.format("  %-10s %-10s %-8s %-8s", "seed", "notes", "final gc", "gc/h"))
    for _, run in ipairs(runs) do
        out[#out + 1] = line(string.format("  %-10d %-10s %-8s %-8.0f",
            run.seed, run.final.notes .. "/3", comma(run.final.credits),
            perHour(run.final.revenue, run.final.seconds)))
    end

    local keys = {
        { "note1", "first note" }, { "note2", "second note" }, { "note3", "final note" },
        { "tier2", "tier 2" }, { "tier3", "tier 3" },
        { "museum", "museum set" }, { "marta", "Marta done" },
    }
    out[#out + 1] = line("")
    out[#out + 1] = line("Median time to milestone")
    for _, entry in ipairs(keys) do
        local times = {}
        for _, run in ipairs(runs) do
            local at = milestoneAt(run, entry[1])
            if at then times[#times + 1] = at end
        end
        if #times > 0 then
            out[#out + 1] = line(string.format("  %-14s %s   (%d/%d seeds reached it)",
                entry[2], clockText(median(times)), #times, #runs))
        end
    end
    return table.concat(out)
end

function __campaign()
    local opts = __SIM_OPTS or {}
    local runs = {}
    for index = 1, math.max(1, opts.seeds or 1) do
        local seed = (opts.seed or 424242) + (index - 1) * 7919
        runs[#runs + 1] = runOne(seed, opts)
    end

    local out = {}
    out[#out + 1] = line("Goblin Pawn Stars — campaign simulation")
    out[#out + 1] = line("")
    for _, run in ipairs(runs) do
        out[#out + 1] = reportRun(run, opts.verbose and #runs == 1)
        out[#out + 1] = line("")
    end
    if #runs > 1 then
        out[#out + 1] = reportAggregate(runs)
    end
    return table.concat(out)
end
