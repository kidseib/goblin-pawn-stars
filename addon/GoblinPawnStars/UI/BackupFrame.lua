--[[ Goblin Pawn Stars -------------------------------------------------------
    UI/BackupFrame.lua
    Three rolling snapshots with a two-click restore. Restore is intentionally
    destructive: it replaces the whole database and first writes a pre-restore
    snapshot. Opening this window never changes the shop.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local T = ns.Theme
local W = ns.Widgets
local B = ns.Backups

ns.UI = ns.UI or {}
local F = {}
ns.UI.BackupFrame = F

local frame
local rows = {}
local nowButton
local status
local pendingIndex
local pendingSnapshot
local pendingToken = 0

local function restore(index)
    local snapshot = B.Slots()[index]
    if not snapshot then
        F.Refresh()
        return
    end
    if pendingIndex ~= index then
        pendingIndex = index
        pendingSnapshot = snapshot
        pendingToken = pendingToken + 1
        local token = pendingToken
        status:SetText("|cffffcc55Restore the snapshot from " .. B.Stamp(snapshot.at) ..
            "? This replaces the current shop; click Confirm within 6 seconds.|r")
        F.Refresh()
        ns.Compat.After(6, function()
            if token == pendingToken and pendingIndex == index and pendingSnapshot == snapshot then
                pendingIndex = nil
                pendingSnapshot = nil
                F.Refresh()
            end
        end)
        return
    end

    -- A capture between the two clicks shifts indices. Refuse to confirm a
    -- different snapshot than the one the warning named.
    if pendingSnapshot ~= snapshot then
        pendingIndex = nil
        pendingSnapshot = nil
        pendingToken = pendingToken + 1
        status:SetText("|cffffcc55The snapshot list changed. Choose the restore again.|r")
        F.Refresh()
        return
    end

    pendingIndex = nil
    pendingSnapshot = nil
    pendingToken = pendingToken + 1
    local ok, err = B.Restore(index, true)
    if not ok then
        status:SetText("|cffff6b5e" .. tostring(err or "restore failed") .. "|r")
        F.Refresh()
        return
    end
    status:SetText("|cff5fd64fRestored " .. B.Stamp(snapshot.at) ..
        ". The state being replaced is now the newest snapshot.|r")
    if ns.UI.Refresh then ns.UI.Refresh(true) end
    F.Refresh()
end

local function build()
    frame = W.Panel(UIParent, "panel")
    if not frame then return end
    frame:SetSize(440, 306)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()

    local title = W.Text(frame, "ROLLING BACKUPS", 17, T.colors.gold)
    title:SetPoint("TOPLEFT", 16, -12)

    local subtitle = W.Text(frame,
        "Three local snapshots. A restore replaces the whole shop and saves the current state first.",
        9, T.colors.muted)
    subtitle:SetPoint("TOPLEFT", 16, -34)
    subtitle:SetPoint("TOPRIGHT", -50, -34)
    subtitle:SetHeight(24)
    subtitle:SetWordWrap(true)

    local close = W.Button(frame, "X", 26, 24, function() frame:Hide() end, "neutral")
    close:SetPoint("TOPRIGHT", -12, -12)

    local divider = W.Divider(frame, 408, 1)
    divider:SetPoint("TOPLEFT", 16, -58)

    for index = 1, 3 do
        local slot = index
        local row = W.Panel(frame, "inset")
        row:SetPoint("TOPLEFT", 14, -68 - (index - 1) * 58)
        row:SetPoint("TOPRIGHT", -14, -68 - (index - 1) * 58)
        row:SetHeight(50)

        local stamp = W.Text(row, "", 10, T.colors.parchment)
        stamp:SetPoint("TOPLEFT", 10, -7)
        stamp:SetWidth(280)

        local detail = W.Text(row, "", 9, T.colors.muted)
        detail:SetPoint("TOPLEFT", 10, -25)
        detail:SetWidth(280)

        local button = W.Button(row, "Restore", 86, 24, function() restore(slot) end, "neutral")
        button:SetPoint("RIGHT", -8, 0)

        rows[index] = { stamp = stamp, detail = detail, button = button }
    end

    nowButton = W.Button(frame, "Backup now", 126, 26, function()
        pendingIndex = nil
        pendingSnapshot = nil
        pendingToken = pendingToken + 1
        local snapshot, err = B.Capture("manual")
        if not snapshot then
            status:SetText("|cffff6b5e" .. tostring(err or "could not save a snapshot") .. "|r")
            return
        end
        status:SetText("|cff5fd64fSnapshot saved. Nothing was bought or sold.|r")
        F.Refresh()
    end, "primary")
    nowButton:SetPoint("BOTTOMLEFT", 16, 16)

    status = W.Text(frame, "", 9, T.colors.muted)
    status:SetPoint("LEFT", nowButton, "RIGHT", 12, 0)
    status:SetPoint("RIGHT", -16, 0)
    status:SetHeight(30)
    status:SetWordWrap(true)

    frame:SetScript("OnHide", function()
        pendingIndex = nil
        pendingSnapshot = nil
        pendingToken = pendingToken + 1
    end)
end

function F.Refresh()
    if not frame then return end
    local slots = B.Slots()
    for index = 1, 3 do
        local row = rows[index]
        local snapshot = slots[index]
        if snapshot then
            row.stamp:SetText(B.Stamp(snapshot.at) .. " · " .. B.Reason(snapshot.reason))
            row.detail:SetText(B.Summary(snapshot))
            row.button:Show()
            row.button:SetLabel(pendingIndex == index and "Confirm" or "Restore")
            row.button:SetTone(pendingIndex == index and "danger" or "neutral")
        else
            row.stamp:SetText("Empty slot")
            row.detail:SetText("No snapshot captured yet.")
            row.button:Hide()
        end
    end
end

function F.Show()
    if not frame then build() end
    if not frame then return end
    pendingIndex = nil
    pendingSnapshot = nil
    pendingToken = pendingToken + 1
    frame:Show()
    F.Refresh()
end

function F.Hide()
    if frame then frame:Hide() end
end

function F.Frame()
    return frame
end
