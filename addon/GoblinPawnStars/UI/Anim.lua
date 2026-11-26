--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Anim.lua
    Small, defensive animation helpers built on Blizzard's animation system.
    Every helper degrades to an instant, visible result if animations are not
    available, so the UI never ends up stuck transparent or half-scaled.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local A = {}
-- Animation groups are children of their region and live as long as it does, so
-- they must be created once and replayed, never created per call. The old code
-- built a fresh group (and its animations) on every fade and every pulse; with
-- the credits number pulsing on each sale that grew without bound and slowly
-- ground the client to a halt. The caches are weak-keyed by region.
local customerWalks = setmetatable({}, { __mode = "k" })
local flashes = setmetatable({}, { __mode = "k" })
local fadeGroups = setmetatable({}, { __mode = "k" })
local scaleGroups = setmetatable({}, { __mode = "k" })
ns.Anim = A

-- Settings → Motion can turn every effect off. Each helper then takes its
-- instant path, which is the same fallback a client without animation support
-- already uses, so the UI is fully usable either way.
local function still()
    local db = ns.DB
    if not db or type(db.Get) ~= "function" then return false end
    local ok, current = pcall(db.Get)
    return ok and current and current.settings and current.settings.animations == false
end

local function groupFor(region)
    if not region or type(region.CreateAnimationGroup) ~= "function" then return nil end
    local ok, group = pcall(region.CreateAnimationGroup, region)
    if not ok or not group then return nil end
    return group
end

local function animationFor(group, kind)
    if not group or type(group.CreateAnimation) ~= "function" then return nil end
    local ok, animation = pcall(group.CreateAnimation, group, kind)
    if not ok or not animation then return nil end
    return animation
end

local function set(animation, method, ...)
    if not animation or type(animation[method]) ~= "function" then return false end
    local ok = pcall(animation[method], animation, ...)
    return ok
end

local function play(group)
    if not group or type(group.Play) ~= "function" then return false end
    return pcall(group.Play, group)
end

-- Restarting a finished group needs a Stop first; Play alone can leave it at
-- its final values.
local function replay(group)
    if not group then return false end
    if type(group.Stop) == "function" then pcall(group.Stop, group) end
    return play(group)
end

local function fadeFor(region)
    local cached = fadeGroups[region]
    if cached ~= nil then return cached or nil end
    local group = groupFor(region)
    local alpha = group and animationFor(group, "Alpha") or nil
    local ready = alpha ~= nil
        and set(alpha, "SetFromAlpha", 0)
        and set(alpha, "SetToAlpha", 1)
    if ready then
        set(alpha, "SetSmoothing", "OUT")
        if type(group.SetScript) == "function" then
            pcall(group.SetScript, group, "OnFinished", function()
                if type(region.SetAlpha) == "function" then pcall(region.SetAlpha, region, 1) end
            end)
        end
        cached = { group = group, alpha = alpha }
        fadeGroups[region] = cached
        return cached
    end
    fadeGroups[region] = false
    return nil
end

local function scaleFor(region)
    local cached = scaleGroups[region]
    if cached ~= nil then return cached or nil end
    local group = groupFor(region)
    local up = group and animationFor(group, "Scale") or nil
    local down = group and animationFor(group, "Scale") or nil
    local ready = up ~= nil and down ~= nil
        and set(up, "SetSmoothing", "OUT")
        and set(down, "SetSmoothing", "IN")
    if ready then
        cached = { group = group, up = up, down = down, restore = 1 }
        if type(group.SetScript) == "function" then
            pcall(group.SetScript, group, "OnFinished", function()
                if type(region.SetScale) == "function" then
                    pcall(region.SetScale, region, cached.restore or 1)
                end
            end)
        end
        scaleGroups[region] = cached
        return cached
    end
    scaleGroups[region] = false
    return nil
end

-- Alpha fade-in. Used for windows, tabs, toasts and the splash screen.
function A.Reveal(region, duration, fromAlpha)
    if not region then return false end
    if still() then
        if type(region.SetAlpha) == "function" then pcall(region.SetAlpha, region, 1) end
        return false
    end
    local cached = fadeFor(region)
    if not cached then
        if type(region.SetAlpha) == "function" then pcall(region.SetAlpha, region, 1) end
        return false
    end
    local ready = set(cached.alpha, "SetDuration", tonumber(duration) or 0.2)
        and set(cached.alpha, "SetFromAlpha", tonumber(fromAlpha) or 0)
        and set(cached.alpha, "SetToAlpha", 1)
    if not ready or not replay(cached.group) then
        if type(region.SetAlpha) == "function" then pcall(region.SetAlpha, region, 1) end
        return false
    end
    return true
end

-- Quick scale "pop" for a card or number that just changed. Restores the
-- region's original scale when it finishes.
function A.Pulse(region, factor, duration)
    if not region or type(region.GetScale) ~= "function" then return false end
    if still() then return false end
    local base = tonumber(region:GetScale()) or 1
    local peak = base * (tonumber(factor) or 1.06)
    local half = (tonumber(duration) or 0.24) / 2

    local cached = scaleFor(region)
    if not cached then return false end
    cached.restore = base

    local ready = set(cached.up, "SetDuration", half)
        and set(cached.up, "SetScaleFrom", base)
        and set(cached.up, "SetScaleTo", peak)
        and set(cached.down, "SetDuration", half)
        and set(cached.down, "SetStartDelay", half)
        and set(cached.down, "SetScaleFrom", peak)
        and set(cached.down, "SetScaleTo", base)
    if not ready or not replay(cached.group) then
        if type(region.SetScale) == "function" then pcall(region.SetScale, region, base) end
        return false
    end
    return true
end

-- Slow continuous rotation for decorative coins on the splash screen.
function A.Spin(texture, seconds)
    if not texture or still() then return false end
    local group = groupFor(texture)
    if not group then return false end
    local rotation = animationFor(group, "Rotation")
    if not rotation then return false end
    if not set(rotation, "SetDuration", tonumber(seconds) or 8) then return false end
    set(rotation, "SetDegrees", 360)
    if type(group.SetLooping) == "function" then
        pcall(group.SetLooping, group, "REPEAT")
    end
    return play(group)
end

-- The model plays its own walk cycle while its frame crosses the doorway.
function A.StopCustomerWalk(region)
    local animation = customerWalks[region]
    if animation then set(animation.group, "Stop") end
end

function A.CustomerWalk(region, distance, finish)
    if still() then
        finish()
        return
    end
    if customerWalks[region] == nil then
        local group = groupFor(region)
        local step = animationFor(group, "Translation")
        if set(step, "SetDuration", 1.1) then
            customerWalks[region] = { group = group, step = step }
        else
            customerWalks[region] = false
        end
    end
    local animation = customerWalks[region]
    if not animation
        or not set(animation.step, "SetOffset", distance, 0)
        or not set(animation.group, "SetScript", "OnFinished", finish)
        or not play(animation.group) then
        finish()
    end
end

function A.Flash(region)
    if still() then
        if region and type(region.SetAlpha) == "function" then pcall(region.SetAlpha, region, 0) end
        return
    end
    if flashes[region] == nil then
        local group = groupFor(region)
        local alpha = animationFor(group, "Alpha")
        local ready = set(alpha, "SetDuration", 0.55)
            and set(alpha, "SetFromAlpha", 1)
            and set(alpha, "SetToAlpha", 0)
            and set(group, "SetScript", "OnFinished", function() region:SetAlpha(0) end)
        flashes[region] = ready and group or false
    end
    local group = flashes[region]
    if group then
        set(group, "Stop")
        region:SetAlpha(1)
        if play(group) then return end
    end
    region:SetAlpha(0)
end
