--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Anim.lua
    Small, defensive animation helpers built on Blizzard's animation system.
    Every helper degrades to an instant, visible result if animations are not
    available, so the UI never ends up stuck transparent or half-scaled.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local A = {}
local customerWalks = setmetatable({}, { __mode = "k" })
local flashes = setmetatable({}, { __mode = "k" })
ns.Anim = A

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

-- Alpha fade-in. Used for windows, tabs, toasts and the splash screen.
function A.Reveal(region, duration, fromAlpha)
    if not region then return false end
    local start = tonumber(fromAlpha) or 0

    local group = groupFor(region)
    local alpha = group and animationFor(group, "Alpha") or nil
    local ready = alpha ~= nil
        and set(alpha, "SetDuration", tonumber(duration) or 0.2)
        and set(alpha, "SetFromAlpha", start)
        and set(alpha, "SetToAlpha", 1)
    set(alpha, "SetSmoothing", "OUT")

    if not ready or not group then
        if type(region.SetAlpha) == "function" then pcall(region.SetAlpha, region, 1) end
        return false
    end

    if type(group.SetScript) == "function" then
        pcall(group.SetScript, group, "OnFinished", function()
            if type(region.SetAlpha) == "function" then pcall(region.SetAlpha, region, 1) end
        end)
    end

    if not play(group) then
        if type(region.SetAlpha) == "function" then pcall(region.SetAlpha, region, 1) end
        return false
    end
    return true
end

-- Quick scale "pop" for a card or number that just changed. Restores the
-- region's original scale when it finishes.
function A.Pulse(region, factor, duration)
    if not region or type(region.GetScale) ~= "function" then return false end
    local base = tonumber(region:GetScale()) or 1
    local peak = base * (tonumber(factor) or 1.06)
    local half = (tonumber(duration) or 0.24) / 2

    local group = groupFor(region)
    if not group then return false end
    local up = animationFor(group, "Scale")
    local down = animationFor(group, "Scale")
    if not up or not down then return false end

    local ready = set(up, "SetDuration", half)
        and set(up, "SetScaleFrom", base)
        and set(up, "SetScaleTo", peak)
        and set(up, "SetSmoothing", "OUT")
        and set(down, "SetDuration", half)
        and set(down, "SetStartDelay", half)
        and set(down, "SetScaleFrom", peak)
        and set(down, "SetScaleTo", base)
        and set(down, "SetSmoothing", "IN")
    if not ready then return false end

    if type(group.SetScript) == "function" then
        pcall(group.SetScript, group, "OnFinished", function()
            if type(region.SetScale) == "function" then pcall(region.SetScale, region, base) end
        end)
    end
    if not play(group) then
        if type(region.SetScale) == "function" then pcall(region.SetScale, region, base) end
        return false
    end
    return true
end

-- Slow continuous rotation for decorative coins on the splash screen.
function A.Spin(texture, seconds)
    if not texture then return false end
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
