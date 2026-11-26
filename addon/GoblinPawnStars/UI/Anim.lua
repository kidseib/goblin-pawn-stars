--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Anim.lua
    Small, defensive animation helpers built on Blizzard's animation system.
    Every helper degrades to an instant, visible result if animations are not
    available, so the UI never ends up stuck transparent or half-scaled.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local A = {}
local customerSteps = setmetatable({}, { __mode = "k" })
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

-- Alternate two stride poses across four translations, then stand still.
function A.CustomerWalk(region, setPose)
    if customerSteps[region] == nil then
        customerSteps[region] = {}
        for i = 1, 4 do
            local group = groupFor(region)
            local step = animationFor(group, "Translation")
            if not (set(step, "SetDuration", 0.20) and set(step, "SetOffset", 10, 0)) then
                customerSteps[region] = false
                break
            end
            customerSteps[region][i] = group
        end
    end
    local steps = customerSteps[region]
    if not steps then
        setPose(0)
        return
    end

    for _, group in ipairs(steps) do set(group, "Stop") end
    local function walk(step)
        if not steps[step] then
            setPose(0)
            return
        end
        setPose((step - 1) % 2 + 1, step)
        if not set(steps[step], "SetScript", "OnFinished", function() walk(step + 1) end)
            or not play(steps[step]) then
            setPose(0)
        end
    end
    walk(1)
end
