--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/Widgets.lua
    Reusable widgets: panels, text, buttons, icons, bars, scroll lists, edit
    boxes and item tooltips. Everything degrades gracefully if a template is
    unavailable on the client.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local T = ns.Theme
local U = ns.Util
local C = ns.Compat
local W = {}
ns.Widgets = W

function W.Create(parent, frameType, template)
    return C.CreateFrame(frameType or "Frame", nil, parent or UIParent, template)
end

function W.Panel(parent, style)
    local frame = W.Create(parent, "Frame", "BackdropTemplate")
    if not frame then return nil end
    T.Decorate(frame, style or "panel")
    return frame
end

function W.Text(parent, text, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(T.font, size or 12, "")
    if not fs:GetFont() then fs:SetFontObject(GameFontNormal) end
    color = color or T.colors.text
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

--[[ Text that has to fit a fixed card --------------------------------------
    The Customers card stacks a buyer line and a special-order line above a bar.
    At a large font or a small UI scale those lines wrap and push the bar out of
    the card. These helpers let the card drop its least important line and
    shorten overlong names instead of growing. Pure functions so they can be
    exercised without a client.
--------------------------------------------------------------------------- ]]

--- Cuts text to `limit` characters, marking the cut with an ellipsis.
function W.Shorten(text, limit)
    text = tostring(text or "")
    limit = math.max(1, math.floor(tonumber(limit) or 40))
    if #text <= limit then return text end
    if limit <= 1 then return "\226\128\166" end
    return text:sub(1, limit - 1) .. "\226\128\166"
end

--- Keeps the longest run of lines taken from the *end* (the last line is the
--- important one) whose measured height fits `areaHeight`. Always returns at
--- least one line. `measure` maps the joined text to a height, so this stays a
--- pure function and the tests can pretend the font is any size.
function W.FitLines(lines, areaHeight, measure)
    if type(lines) ~= "table" or #lines == 0 then return {}, 0 end
    areaHeight = math.max(1, tonumber(areaHeight) or 1)
    for count = #lines, 1, -1 do
        local kept = {}
        for index = #lines - count + 1, #lines do kept[#kept + 1] = lines[index] end
        local text = table.concat(kept, "\n")
        local height = 0
        if measure then
            local ok, value = pcall(measure, text)
            if ok then height = tonumber(value) or 0 end
        end
        if height <= areaHeight or count == 1 then return kept, height end
    end
    return { lines[#lines] }, 0
end

function W.Number(parent, text, size, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(T.fontNumber, size or 12, "")
    if not fs:GetFont() then fs:SetFontObject(GameFontNormal) end
    color = color or T.colors.gold
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    fs:SetText(text or "")
    return fs
end

local TONES = {
    primary = { 0.20, 0.38, 0.16, 1 },
    gold = { 0.42, 0.33, 0.13, 1 },
    danger = { 0.40, 0.15, 0.12, 1 },
    neutral = { 0.24, 0.20, 0.13, 1 },
    blue = { 0.15, 0.25, 0.38, 1 },
}

function W.Button(parent, label, width, height, onClick, tone)
    local button = W.Create(parent, "Button")
    if not button then return nil end
    button:SetSize(width or 100, height or 22)
    button:RegisterForClicks("AnyUp")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    button.bg = bg

    local border = button:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT")
    border:SetPoint("BOTTOMRIGHT")
    T.Fill(border, 0.55, 0.45, 0.22, 0.8)
    local inner = button:CreateTexture(nil, "BORDER")
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    T.Fill(inner, 0.10, 0.08, 0.05, 1)
    button.inner = inner

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", 1, -1)
    highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    T.Fill(highlight, 0.9, 0.8, 0.45, 0.12)

    local text = W.Text(button, label or "", 12, T.colors.text)
    text:SetPoint("CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    button.label = text
    button.enabled = true
    button.tone = tone or "neutral"

    function button:SetTone(newTone)
        local color = TONES[newTone] or TONES.neutral
        self.tone = newTone
        T.Fill(self.bg, color[1], color[2], color[3], color[4])
    end

    function button:SetLabel(newLabel)
        self.label:SetText(newLabel or "")
    end

    function button:SetState(isEnabled)
        self.enabled = isEnabled and true or false
        if self.enabled then
            self.label:SetTextColor(T.colors.text[1], T.colors.text[2], T.colors.text[3])
            self:SetAlpha(1)
        else
            self.label:SetTextColor(0.45, 0.42, 0.36)
            self:SetAlpha(0.65)
        end
    end

    button:SetTone(button.tone)
    button:SetScript("OnClick", function(self, mouseButton)
        if not self.enabled then return end
        if ns.Sound then ns.Sound.Play("open") end
        if onClick then onClick(mouseButton, self) end
    end)

    return button
end

function W.Icon(parent, size, texture)
    local frame = W.Create(parent, "Frame")
    if not frame then return nil end
    frame:SetSize(size or 32, size or 32)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    frame.icon = icon

    -- Draw a 1px inset border using four strips so it works on all builds.
    local strips = {}
    for index = 1, 4 do
        local strip = frame:CreateTexture(nil, "OVERLAY")
        T.Fill(strip, 0.55, 0.45, 0.22, 0.9)
        strips[index] = strip
    end
    strips[1]:SetPoint("TOPLEFT")
    strips[1]:SetPoint("TOPRIGHT")
    strips[1]:SetHeight(1)
    strips[2]:SetPoint("BOTTOMLEFT")
    strips[2]:SetPoint("BOTTOMRIGHT")
    strips[2]:SetHeight(1)
    strips[3]:SetPoint("TOPLEFT")
    strips[3]:SetPoint("BOTTOMLEFT")
    strips[3]:SetWidth(1)
    strips[4]:SetPoint("TOPRIGHT")
    strips[4]:SetPoint("BOTTOMRIGHT")
    strips[4]:SetWidth(1)

    function frame:SetIcon(newTexture)
        self.icon:SetTexture(newTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    end

    return frame
end

-- Use built-in game artwork until the native customer model loads.
function W.SetClassIcon(icon, class)
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[tostring(class or ""):upper()]
    if type(coords) == "table" and #coords >= 4 then
        icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        icon:SetTexture(134400) -- INV_Misc_QuestionMark
        icon:SetTexCoord(0, 1, 0, 1)
    end
end

function W.Portrait(parent, size, class, rareColor)
    local frame = W.Create(parent, "Frame")
    if not frame then return nil end
    frame:SetSize(size or 48, size or 48)

    local ring = frame:CreateTexture(nil, "BACKGROUND")
    ring:SetAllPoints()
    T.Fill(ring, rareColor and rareColor[1] or 0.5,
        rareColor and rareColor[2] or 0.42, rareColor and rareColor[3] or 0.22, 1)

    local inner = frame:CreateTexture(nil, "ARTWORK")
    inner:SetPoint("TOPLEFT", 2, -2)
    inner:SetPoint("BOTTOMRIGHT", -2, 2)
    T.Fill(inner, 0.08, 0.07, 0.04, 1)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    W.SetClassIcon(icon, class)

    local model
    function frame:SetCustomer(customer)
        W.SetClassIcon(icon, customer.class)
        if ns.Util.PerformanceMode() then
            if model and model.SetVisible then pcall(model.SetVisible, model, false) end
            icon:Show()
            return
        end
        if model == nil then
            local factory = ns.UI.CustomerModel
            local ok, widget = pcall(function()
                return factory and factory.Attach(frame, icon, 0.85)
            end)
            model = ok and widget or false
        end
        if model then
            if model.SetVisible then pcall(model.SetVisible, model, true) end
            pcall(model.SetCustomer, model, customer)
        end
    end

    return frame
end

function W.Bar(parent, width, height, color)
    local frame = W.Create(parent, "Frame")
    if not frame then return nil end
    frame:SetSize(width or 100, height or 8)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    T.Fill(bg, 0.04, 0.035, 0.02, 0.95)

    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetHeight((height or 8) - 2)
    fill:SetWidth(1)
    color = color or T.colors.green
    T.Fill(fill, color[1], color[2], color[3], 1)
    frame.fill = fill
    frame.fullWidth = (width or 100) - 2
    frame.fillColor = color

    function frame:SetValue(value, max)
        max = math.max(1, max or 1)
        local ratio = U.clamp((value or 0) / max, 0, 1)
        self.fill:SetWidth(math.max(0.1, self.fullWidth * ratio))
    end

    function frame:SetColor(newColor)
        self.fillColor = newColor
        T.Fill(self.fill, newColor[1], newColor[2], newColor[3], 1)
    end

    return frame
end

function W.Scroll(parent)
    local scroll = W.Create(parent, "ScrollFrame", "UIPanelScrollFrameTemplate")
    if not scroll then return nil end
    scroll:EnableMouseWheel(true)

    local content = W.Create(scroll, "Frame")
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)

    function scroll:SetContentHeight(height)
        local width = self:GetWidth()
        if width <= 1 then width = 400 end
        content:SetWidth(math.max(40, width - 20))
        content:SetHeight(math.max(height, 10))
    end

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local maxScroll = math.max(0, content:GetHeight() - (self:GetHeight() or 0))
        self:SetVerticalScroll(U.clamp(current - delta * 36, 0, maxScroll))
    end)
    scroll:SetScript("OnSizeChanged", function(self, width, height)
        content:SetWidth(math.max(40, (width or 400) - 20))
    end)

    scroll.content = content
    return scroll, content
end

function W.EditBox(parent, width, height, placeholder)
    local box = W.Create(parent, "EditBox", "InputBoxTemplate")
    if not box then return nil end
    box:SetSize(width or 120, height or 22)
    box:SetAutoFocus(false)
    box:SetMaxLetters(12)
    box:SetFont(T.fontNumber, 13, "")
    box:SetTextInsets(4, 4, 0, 0)
    if box.SetTextColor then box:SetTextColor(0.94, 0.90, 0.80, 1) end
    if placeholder then
        box.placeholder = W.Text(box, placeholder, 11, T.colors.dim)
        box.placeholder:SetPoint("LEFT", 5, 0)
        box:SetScript("OnEditFocusGained", function(self)
            if self.placeholder then self.placeholder:Hide() end
        end)
        box:SetScript("OnEditFocusLost", function(self)
            if self.placeholder and (self:GetText() or "") == "" then
                self.placeholder:Show()
            end
        end)
    end
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

function W.MultiLine(parent, width, height, maxLetters)
    local box = W.Create(parent, "EditBox")
    if not box then return nil end
    box:SetSize(width or 300, height or 80)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetMaxLetters(maxLetters or 60000)
    box:SetFont(T.fontNumber, 11, "")
    box:SetTextInsets(4, 4, 2, 2)
    if box.SetTextColor then box:SetTextColor(0.90, 0.87, 0.75, 1) end
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    T.Fill(bg, 0.03, 0.03, 0.02, 0.9)
    return box
end

function W.ItemTooltip(frame, getRecord)
    frame:SetScript("OnEnter", function(self)
        local record = getRecord and getRecord() or self.record
        if not record then return end
        ns.Compat.ShowItemTooltip(self, record)
    end)
    frame:SetScript("OnLeave", function()
        ns.Compat.HideTooltip()
    end)
end

function W.Divider(parent, width, height)
    local line = parent:CreateTexture(nil, "ARTWORK")
    T.Fill(line, 0.40, 0.33, 0.16, 0.7)
    line:SetSize(width or 200, height or 1)
    return line
end

function W.LabelValue(parent, label, value, width)
    local holder = W.Create(parent, "Frame")
    holder:SetSize(width or 150, 34)
    local title = W.Text(holder, label, 10, T.colors.muted)
    title:SetPoint("TOPLEFT", 0, 0)
    local val = W.Number(holder, value, 15, T.colors.gold)
    val:SetPoint("TOPLEFT", 0, -12)
    holder.value = val
    holder.title = title
    return holder
end
