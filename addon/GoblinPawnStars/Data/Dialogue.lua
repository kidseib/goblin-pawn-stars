--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Dialogue.lua
    Contextual customer lines.

    Data/Personalities.lua keeps each archetype's voice: the generic greet, offer,
    accept, refuse and leave pools. This file owns what changes that voice line by
    line - the piece on the counter, its quality, the price band, the customer's
    patience and the shop's reputation - plus a small bounded memory so the same
    line does not come back twice in a row.

    Nothing here runs per frame: a line is chosen when a customer arrives, when a
    counteroffer resolves or when someone walks out, which is a handful of times
    per minute at most.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local Data = ns.Data
local U = ns.Util
local D = {}
Data.Dialogue = D

-- The save keeps the last few chosen lines as one number each: scope * 16 + index.
-- Six entries is enough to cover the current customer's greeting, offer and
-- verdict without growing the journal payload.
local MAX_RECENT = 6
local SLOTS_PER_SCOPE = 16

--[[ Which pool a key prefers -----------------------------------------------
    Tags are context flags from D.Context. The first tag whose pool exists wins;
    the personality's base pool in Data/Personalities.lua is the next fallback,
    and D.Fallback below the last resort. Order matters: an insult outranks a
    patient customer's ordinary refusal.
--------------------------------------------------------------------------- ]]
D.Variants = {
    greet = { "order", "orderAsk", "patron", "return", "prefer", "fine" },
    offer = { "rich", "cheap" },
    accept = { "order", "counter", "rich" },
    refuse = { "insult", "over", "furious" },
    leave = { "furious" },
}

-- Never nil, never empty: a missing pool must still produce a readable line.
D.Fallback = {
    greet = { "They look over the shelves and wait for you to start." },
    offer = { "They offer {offer} and fold their arms." },
    accept = { "Done. {price} it is." },
    refuse = { "They shake their head at {counter}." },
    leave = { "They turn around and walk out." },
}

local KEY_ORDER = { greet = 1, offer = 2, accept = 3, refuse = 4, leave = 5 }

---------------------------------------------------------------------------
-- Context
---------------------------------------------------------------------------

--[[ Mood, price band and item match -----------------------------------------
    Everything is derived from the customer record and the item it points at, so
    a line never needs state the save does not already carry. `flags` lets the
    caller add what only it knows: whether the last counter was above the hidden
    ceiling, an insult, or a landing counter.
--------------------------------------------------------------------------- ]]
function D.Context(customer, personality, item, flags)
    flags = flags or {}
    local ctx = {
        prefer = false, fine = false,
        rich = false, cheap = false,
        counter = flags.counter == true,
        insult = flags.insult == true,
        over = flags.over == true,
        returning = false,
        order = false,
        orderAsk = false,
        patron = false,
        furious = false,
        mood = "calm",
        band = "fair",
        quality = 1,
        value = 0,
        reputation = 0,
    }

    if not customer then return ctx end
    ctx.returning = (tonumber(customer.returning) or 0) > 0
    -- Collecting a special order outranks asking for one: the same tag would
    -- otherwise let a customer say "I want a {category}" while buying it.
    ctx.order = customer.order == true
    ctx.orderAsk = (not ctx.order) and customer.orderCategory ~= nil
    -- A patron is a standing relationship, so they get their own greeting: the
    -- shop should feel like it knows them, not like they are a lucky roll.
    ctx.patron = customer.patron == true

    local max = tonumber(customer.patienceMax) or 0
    local left = tonumber(customer.patience) or 0
    local ratio = 0
    if max > 0 then ratio = U.clamp(left / max, 0, 1) end
    if ratio <= 0.34 then
        ctx.furious = true
        ctx.mood = "furious"
    elseif ratio <= 0.67 then
        ctx.mood = "edgy"
    end
    -- A customer out of rounds is furious whatever the arithmetic says.
    if left <= 0 then ctx.furious = true; ctx.mood = "furious" end

    if personality and item then
        ctx.prefer = U.contains(personality.prefer, item.category)
    end

    if item then
        ctx.quality = tonumber(item.quality) or 1
        ctx.fine = ctx.quality >= 3
        ctx.value = tonumber(ns.Market.Value(item)) or 0
    end

    local price = tonumber(flags.price) or tonumber(customer.offer) or 0
    if ctx.value > 0 and price > 0 then
        if price >= ctx.value * 1.15 then
            ctx.rich = true
            ctx.band = "rich"
        elseif price <= ctx.value * 0.75 then
            ctx.cheap = true
            ctx.band = "cheap"
        end
    end

    if ns.Shop and ns.Shop.Reputation then
        local ok, reputation = pcall(ns.Shop.Reputation)
        if ok then ctx.reputation = tonumber(reputation) or 0 end
    end
    return ctx
end

---------------------------------------------------------------------------
-- Anti-repeat memory
---------------------------------------------------------------------------

local function memory()
    local db = ns.DB.Get()
    local list = db.shop and db.shop.recentLines
    if type(list) ~= "table" then
        list = {}
        db.shop.recentLines = list
    end
    return list
end

local function scopeFor(personality, key, slot)
    local index = 0
    if personality and personality.key and Data.PersonalityIndex then
        index = Data.PersonalityIndex[personality.key] or 0
    end
    local keyIndex = KEY_ORDER[key] or 6
    return (index * 8 + keyIndex) * 8 + math.min(tonumber(slot) or 0, 7)
end

--[[ Choosing an index -------------------------------------------------------
    Indices already used for this scope are skipped while at least one remains,
    which makes a two-line pool strictly alternate. A pool smaller than its own
    memory (or a single-line pool) stops filtering rather than starving, exactly
    like the shop-event picker.
--------------------------------------------------------------------------- ]]
local function chooseIndex(scope, count)
    if count <= 1 then return 1 end

    local list = memory()
    local blocked, newest = {}, nil
    for _, entry in ipairs(list) do
        local packed = tonumber(entry) or 0
        if math.floor(packed / SLOTS_PER_SCOPE) == scope then
            local index = packed % SLOTS_PER_SCOPE
            if index >= 1 and index <= count then
                blocked[index] = true
                if not newest then newest = index end
            end
        end
    end

    local candidates = {}
    for index = 1, count do
        if not blocked[index] then candidates[#candidates + 1] = index end
    end

    -- A two-line pool fills its own memory after two draws. Rather than handing
    -- back the line the customer just said, drop only the newest entry and pick
    -- among everything else.
    if #candidates == 0 then
        for index = 1, count do
            if index ~= newest then candidates[#candidates + 1] = index end
        end
    end
    if #candidates == 0 then candidates[1] = 1 end

    -- Deliberately not math.random: cosmetic text must never consume draws from
    -- the shared gameplay stream (it would silently change loot, haggling and
    -- encounter rolls), and a deterministic rotation is also easier to audit.
    local chosen = candidates[((#list + scope) % #candidates) + 1] or candidates[1]

    -- Newest first, then trim. The list is the only thing this file writes to
    -- the save, and it never exceeds MAX_RECENT entries.
    table.insert(list, 1, scope * SLOTS_PER_SCOPE + chosen)
    while #list > MAX_RECENT do table.remove(list) end
    return chosen
end

---------------------------------------------------------------------------
-- Contextual pools
---------------------------------------------------------------------------

--[[ One table, nine voices ---------------------------------------------------
    Kept here rather than inside Data/Personalities.lua so the archetype tables
    stay a description of behaviour and this file stays the description of what
    the customer actually says. Placeholders are filled by D.Line: {item},
    {category}, {offer}, {price}, {counter}.
--------------------------------------------------------------------------- ]]
D.Lines = {
    cheap = {
        greetReturn = {
            "Back again. The prices still haven't improved, I see.",
            "You remember what I paid last time. So do I.",
        },
        greetPrefer = {
            "Oh, {category}. Fine, show me. I still won't pay much.",
            "I know what {item} goes for. Go on, then.",
        },
        greetFine = {
            "\"Quality\", they say. I say it's a price tag with extra steps.",
            "That one looks expensive. That's the whole problem with it.",
        },
        acceptRich = {
            "Ugh. {price}. I'll be eating turnips for a month.",
            "{price}? You've ruined me. Wrap it before I reconsider.",
        },
        refuseOver = {
            "No. Not {counter}. You've added a zero for fun.",
            "I could buy a cart for {counter}. Get serious.",
        },
        refuseInsult = {
            "You've insulted me. I'll tell everyone on the road.",
            "A goblin of principle, that's me. Gone.",
        },
        leaveFurious = {
            "I'm done. There's a stall down the road that prices like a person.",
            "Keep it. I'll wait for the crash. It always comes.",
        },
    },
    collector = {
        greetReturn = {
            "I came back for the rest of your collection.",
            "Last visit I left with something good. Show me more.",
        },
        greetPrefer = {
            "Ah. A {category} piece. You have my attention at last.",
            "{item}, is it? My hall has a gap exactly that shape.",
        },
        greetFine = {
            "The finish on that is not terrible. Do continue.",
            "At last, something in this shop that isn't scrap.",
        },
        acceptRich = {
            "Splendid. {price}, and a crate that does not smell.",
            "Agreed. {price}. Bill it to the account nobody audits.",
        },
        refuseOver = {
            "{counter}? My dear, my appraisers would faint.",
            "That is not a price, that is a bedtime story. {counter}.",
        },
        refuseInsult = {
            "How dreadfully common. I shall pretend that never happened.",
            "You have mistaken me for someone who haggles in the street.",
        },
        leaveFurious = {
            "I shall take my collection budget somewhere with a door.",
            "Good day. Do not expect a second.",
        },
    },
    trader = {
        greetReturn = {
            "We've done business before. Let's do it properly.",
            "You know me, I know the shelves. Let's talk numbers.",
        },
        greetPrefer = {
            "{category}? Now we can talk like professionals.",
            "That's the sort of thing that actually moves. Show me.",
        },
        greetFine = {
            "Good condition. I'll price it accordingly, which is to say low.",
            "Quality stock. Rare in this district.",
        },
        acceptRich = {
            "Done. {price}. You read the market better than most.",
            "{price}. Fine. The margin is thin but the day is long.",
        },
        refuseOver = {
            "Above the going rate by a mile. {counter} is fiction.",
            "You've been reading auction listings again. No.",
        },
        refuseInsult = {
            "I've traded through three wars. That number offends them too.",
            "Insults are free. So is that number. Still no.",
        },
        leaveFurious = {
            "Noted. I'll remember this shop's prices.",
            "I'll take my coin where the numbers make sense.",
        },
    },
    gullible = {
        greetReturn = {
            "It's you! I told everyone about this shop!",
            "Hello again! I brought a bigger purse this time.",
        },
        greetPrefer = {
            "You have {category} things?! That's my favourite kind!",
            "Oh, {item}! Is it magic? It looks magic.",
        },
        greetFine = {
            "It's so shiny. My guild says shiny means expensive.",
            "This looks like something from a real dungeon!",
        },
        acceptRich = {
            "{price}! Wow! I'll tell everyone! I'll tell the parrot!",
            "Deal! {price}! Wait until they hear about this.",
        },
        refuseOver = {
            "{counter}? I don't have that. I don't have half of that.",
            "Is that a lot? That sounds like a lot.",
        },
        refuseInsult = {
            "Oh no. Did I do something wrong?",
            "I'll just... go. Sorry. Sorry!",
        },
        leaveFurious = {
            "I'll come back when I've looted something. Bye!",
            "I'll ask the other shop. The one with the parrot.",
        },
    },
    desperate = {
        greetReturn = {
            "I'm back. I still need what I needed last time.",
            "You helped me before. Please. Again.",
        },
        greetPrefer = {
            "You have {category}? Tell me you have {category}.",
            "That's it. That's exactly what I need. How much?",
        },
        greetFine = {
            "It's in one piece? Good. I don't have time for repairs.",
            "Fine condition. Fine. Name your number.",
        },
        acceptRich = {
            "{price}. Done. Don't gloat, I can hear gloating.",
            "Take {price}. I'll sort out the rest later.",
        },
        refuseOver = {
            "I don't have time for {counter}. Truly.",
            "That's robbery, and I'm the one in a hurry.",
        },
        refuseInsult = {
            "Forget it. Forget this. I'll find it elsewhere.",
            "You've wasted the one thing I don't have.",
        },
        leaveFurious = {
            "I'm going. Don't follow me with numbers.",
            "Useless. Absolutely useless.",
        },
    },
    suspicious = {
        greetReturn = {
            "You again. I have been watching this place.",
            "I came back, which should tell you something.",
        },
        greetPrefer = {
            "{category}? Always {category}. What's the catch?",
            "That one's been sitting there. Why? What's wrong with it?",
        },
        greetFine = {
            "Good condition. Suspiciously good. Who had it before?",
            "It looks clean. Too clean, if you ask me.",
        },
        acceptRich = {
            "{price}. Fine. I'll be counting the coin twice.",
            "Take it. And a receipt. And the receipt for the receipt.",
        },
        refuseOver = {
            "{counter}? What are you, a pirate? Don't answer that.",
            "Inflated. Suspiciously inflated. {counter}, no.",
        },
        refuseInsult = {
            "There it is. The hidden fee. The real shop.",
            "I knew it. I knew this counter was a trap.",
        },
        leaveFurious = {
            "Shady. I'm leaving before I get swindled.",
            "Count your own coppers. I'm done.",
        },
    },
    impatient = {
        greetReturn = {
            "I know the way here. Skip the small talk.",
            "Back. Don't make me wait this time.",
        },
        greetPrefer = {
            "{category}. Good. Price. Now.",
            "That one. How much. Quickly.",
        },
        greetFine = {
            "Looks fine. Doesn't matter. Price.",
            "Good enough. I have a duel at four.",
        },
        acceptRich = {
            "{price}. Finally. Somebody understands urgency.",
            "Done. {price}. Stop talking.",
        },
        refuseOver = {
            "{counter}? You're spending my time on numbers.",
            "No. Too much. I'm already late.",
        },
        refuseInsult = {
            "I'm not doing this. I have a duel.",
            "Waste someone else's afternoon.",
        },
        leaveFurious = {
            "Forget it. I'll fight with the old one.",
            "Gone. Don't follow.",
        },
    },
    merchant = {
        greetReturn = {
            "A familiar counter. Familiar prices, I hope.",
            "We have an understanding, you and I. Show me the stock.",
        },
        greetPrefer = {
            "{category} in bulk? Now that's a caravan load.",
            "That's the sort of crate I can move. Price it.",
        },
        greetFine = {
            "Good stock. I'll take the lot if the number's honest.",
            "Condition's decent. My cart is already loaded.",
        },
        acceptRich = {
            "{price}. I'll take it, and two more like it.",
            "Agreed. {price}. My ox will complain.",
        },
        refuseOver = {
            "{counter}? I'd have to sell the ox. And the ox is family.",
            "Not at {counter}. I'm a merchant, not a charity.",
        },
        refuseInsult = {
            "I've been insulted by professionals. That was better.",
            "No deal. Even the ogres price fairer.",
        },
        leaveFurious = {
            "Caravan's leaving. So am I.",
            "No deal. Try Stormwind. They're desperate.",
        },
    },
    rare_hunter = {
        greetReturn = {
            "Back for another look. Anything new in the back?",
            "I returned. That is the highest praise I offer.",
        },
        greetPrefer = {
            "{category}. You keep the odd things out of sight. Wise.",
            "That piece. It hums, does it not? Name a price.",
        },
        greetFine = {
            "Worn in the right places. It has been somewhere.",
            "Not new. Good. New things have no story.",
        },
        acceptRich = {
            "{price}. A fine addition. You did not ask why. Good.",
            "Done. {price}. My order will be... satisfied.",
        },
        refuseOver = {
            "{counter}? You mistake curiosity for desperation.",
            "That figure is fanciful. I collect objects, not grudges.",
        },
        refuseInsult = {
            "You have wasted a rare thing: my patience.",
            "I have been threatened by worse. Farewell.",
        },
        leaveFurious = {
            "I shall return to the whispers. They had better leads.",
            "A pity. I had plans for it.",
        },
    },
}

---------------------------------------------------------------------------
-- Resolution
---------------------------------------------------------------------------

local function basePool(personality, key)
    local lines = personality and personality.lines
    local pool = lines and lines[key]
    if type(pool) == "table" and #pool > 0 then return pool end
    return nil
end

local function contextPool(personality, key, ctx)
    local extra = personality and (personality.context
        or (personality.key and D.Lines[personality.key]))
    if type(extra) ~= "table" then return nil end
    for slot, tag in ipairs(D.Variants[key] or {}) do
        if ctx[tag] then
            local name = key .. tag:sub(1, 1):upper() .. tag:sub(2)
            local pool = extra[name]
            if type(pool) == "table" and #pool > 0 then
                return pool, slot, name
            end
        end
    end
end

local function fillVars(customer, vars, ctx)
    local out = {}
    if vars then
        for key, value in pairs(vars) do out[key] = value end
    end
    out.offer = out.offer or U.comma(tonumber(customer and customer.offer) or 0)
    out.price = out.price or out.offer
    out.counter = out.counter or "0"
    out.mood = out.mood or ctx.mood
    if out.item == nil then
        local item = customer and ns.DB.Get().inventory[customer.itemUid]
        out.item = item and item.name or "it"
        out.category = ns.Data.CategoryName(item and item.category) or "curiosities"
    end
    out.category = out.category or "curiosities"
    return out
end

--[[ D.Line -----------------------------------------------------------------
    Returns a filled line for `key` ("greet", "offer", "accept", "refuse",
    "leave") for this customer. Always a non-empty string.
--------------------------------------------------------------------------- ]]
function D.Line(customer, key, vars, flags)
    key = D.Variants[key] and key or "greet"
    local personality = customer and Data.PersonalityByKey[customer.personality]
    local item = customer and ns.DB.Get().inventory[customer.itemUid]
    local ctx = D.Context(customer, personality, item, flags)

    local pool, slot = contextPool(personality, key, ctx)
    if not pool then
        pool, slot = basePool(personality, key), 0
    end
    if not pool then
        pool, slot = D.Fallback[key] or D.Fallback.greet, 7
    end

    local count = math.min(#pool, SLOTS_PER_SCOPE - 1)
    if count < 1 then
        return D.Fallback[key][1]
    end

    local index = chooseIndex(scopeFor(personality, key, slot), count)
    local template = pool[index] or pool[1] or ""
    local line = U.trim(U.fill(template, fillVars(customer, vars, ctx)))
    if line == "" then
        return D.Fallback[key][1]
    end
    return line
end

-- Diagnostic surface: which contextual pool would answer for this customer,
-- without drawing a line or touching the anti-repeat memory.
function D.Explain(customer, key)
    local personality = customer and Data.PersonalityByKey[customer.personality]
    local item = customer and ns.DB.Get().inventory[customer.itemUid]
    local ctx = D.Context(customer, personality, item)
    local pool, slot, name = contextPool(personality, key, ctx)
    if pool then return name, #pool, ctx end
    local base = basePool(personality, key)
    if base then return "base", #base, ctx end
    return "fallback", #(D.Fallback[key] or {}), ctx
end

---------------------------------------------------------------------------
-- Special orders
---------------------------------------------------------------------------
--[[ Asking for a shelf, and collecting it ----------------------------------
    Iteration 4 lets a regular turn up wanting one specific shelf of goods. The
    pools live in one block so the archetype tables above stay a description of
    behaviour; the merge below attaches them to the contextual pools D.Line
    already looks up, so no other file has to know they exist.
--------------------------------------------------------------------------- ]]
local ORDER_POOLS = {
    cheap = {
        greetOrder = {
            "The {category}. I said I'd be back for one, and here I am.",
            "Still after a {category}. Small purse, long memory.",
        },
        greetOrderAsk = {
            "I want a {category}. Something cheap, before the week is out.",
            "Find me a {category} worth its price and I'll come back for it.",
        },
        acceptOrder = {
            "{price} for a {category} I asked for. Fair. Take it.",
            "There. That's the {category} I wanted. Don't gloat about it.",
        },
    },
    collector = {
        greetOrder = {
            "The {category}. I've been thinking about it all week.",
            "You kept it. A {category}, just as I asked.",
        },
        greetOrderAsk = {
            "I'm hunting a {category}. Something with a story on it.",
            "Find me a {category} and I'll pay what it deserves.",
        },
        acceptOrder = {
            "Yes. {price}, and it belongs in my collection.",
            "The {category}. {price} is nothing for the missing piece.",
        },
    },
    trader = {
        greetOrder = {
            "My {category}. You found one, as promised.",
            "I placed an order, not a wish. Let's see it.",
        },
        greetOrderAsk = {
            "I need a {category} by market day. Can you source one?",
            "A {category}, decent, and I'll make it worth your while.",
        },
        acceptOrder = {
            "{price}. Clean trade, and the {category} is mine.",
            "Goods first, coin second. {price}, as agreed.",
        },
    },
    gullible = {
        greetOrder = {
            "You got the {category}! I told everyone you would.",
            "Is that it? The {category}? It's better than I imagined.",
        },
        greetOrderAsk = {
            "Could you find a {category}? I'd be ever so grateful.",
            "I've been hoping for a {category}. Anything shiny will do.",
        },
        acceptOrder = {
            "{price}? Here, take it all. It's beautiful.",
            "I'd have paid twice. {price} it is.",
        },
    },
    desperate = {
        greetOrder = {
            "The {category}. Please tell me you still have it.",
            "I came back. I need that {category} more than I need the coin.",
        },
        greetOrderAsk = {
            "A {category}. Soon. I can pay, I just can't wait.",
            "Find me a {category} and I'll owe you one.",
        },
        acceptOrder = {
            "{price} — take it, take it, just hand it over.",
            "Yes. {price}. I'll not haggle with my own luck.",
        },
    },
    suspicious = {
        greetOrder = {
            "The {category}. Let me look at it before I believe you.",
            "I asked for a {category}. This had better be one.",
        },
        greetOrderAsk = {
            "I want a {category}. Untouched, mind. No repairs, no tricks.",
            "A {category}, and I'll be checking it myself.",
        },
        acceptOrder = {
            "{price}. It's honest work, for once.",
            "Fine. {price}, and I'll be telling people it was fair.",
        },
    },
    impatient = {
        greetOrder = {
            "The {category}. Quickly, I've wasted enough of the morning.",
            "I asked for a {category}. You have ten seconds to show me.",
        },
        greetOrderAsk = {
            "One {category}. Today, not next week.",
            "I want a {category} and I want to be done with it.",
        },
        acceptOrder = {
            "{price}. Done. Wrapped, if you can manage it.",
            "Finally. {price}, and I'm out the door.",
        },
    },
    merchant = {
        greetOrder = {
            "The {category}. I trust it's the pick of the shelf.",
            "I ordered a {category}, not an excuse. Show me.",
        },
        greetOrderAsk = {
            "Source me a {category}, and don't insult me with the dregs.",
            "A {category}, top of the pile. You'll be paid properly.",
        },
        acceptOrder = {
            "{price} for a piece this good. We have an arrangement.",
            "There it is. {price}, and I'll be back with more orders.",
        },
    },
    rare_hunter = {
        greetOrder = {
            "The {category}. I've chased one of these across three valleys.",
            "You found it. A {category} worth the trip.",
        },
        greetOrderAsk = {
            "I'm after a particular {category}. Quality, not quantity.",
            "Find me a {category} with some age to it. I'll pay for pedigree.",
        },
        acceptOrder = {
            "{price}, and it's finally mine. Worth every coin.",
            "The {category}. {price} is a fair finder's fee.",
        },
    },
}

for key, pools in pairs(ORDER_POOLS) do
    local target = D.Lines[key]
    if not target then
        target = {}
        D.Lines[key] = target
    end
    for name, lines in pairs(pools) do target[name] = lines end
end

-- Patron greetings: the regulars who have delivered enough to become fixtures of
-- the shop. Only used once, on the arrival of a patron, so the tone has to carry
-- "we know each other" without reading as a new character.
local PATRON_POOLS = {
    cheap = {
        greetPatron = {
            "Your best shelf, same as always. I trust you to have it.",
            "I told my sister about this place. Don't make me a liar.",
        },
    },
    collector = {
        greetPatron = {
            "I keep the pieces I buy here on one shelf. It's getting crowded.",
            "Your stock has better taste than most of my acquaintances.",
        },
    },
    trader = {
        greetPatron = {
            "My partner sends his regards. And his list.",
            "You and I have an understanding. Let's keep it profitable.",
        },
    },
    gullible = {
        greetPatron = {
            "I tell everyone you're the honest one. You are, aren't you?",
            "I brought a friend's coin this time. Be gentle with it.",
        },
    },
    desperate = {
        greetPatron = {
            "You've never let me down. I'm counting on that again.",
            "I came straight here. I always come straight here now.",
        },
    },
    suspicious = {
        greetPatron = {
            "I've decided to trust you. Don't make me reconsider.",
            "You've been fair twice. I'm keeping count, but kindly.",
        },
    },
    impatient = {
        greetPatron = {
            "Skip the small talk. You know what I like.",
            "I'm in a hurry, but I made time for you. Be flattered.",
        },
    },
    merchant = {
        greetPatron = {
            "Still the best counter in the district. Show me something.",
            "I've started recommending you. That's worth something.",
        },
    },
    rare_hunter = {
        greetPatron = {
            "I came back for the shelf, not the coin. You understand that.",
            "Your back room has ruined my collection. Keep ruining it.",
        },
    },
}

for key, pools in pairs(PATRON_POOLS) do
    local target = D.Lines[key]
    if not target then
        target = {}
        D.Lines[key] = target
    end
    for name, lines in pairs(pools) do target[name] = lines end
end
