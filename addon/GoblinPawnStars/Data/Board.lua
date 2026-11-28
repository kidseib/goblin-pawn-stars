--[[ Goblin Pawn Stars -------------------------------------------------------
    Data/Board.lua
    The sidewalk A-board: the one line the shop advertises for a shop day.
    Every number and every word of the placards lives here, so the board is a
    data feature and the sale code only asks for a percentage.

    Bulk lines get the biggest lift because they need it to compete with the
    daily request; the premium lines (gems, weapons, companions) move on their
    own and only get a nudge. `draw` is how much more often a buyer walks in
    carrying a line that is on the board.
--------------------------------------------------------------------------- ]]

local ADDON, ns = ...
local Data = ns.Data or {}
ns.Data = Data

-- Step the solved lift is rounded to. The label and the tooltip both print a
-- whole percent, so half points are as fine as the board can honestly state.
Data.BoardStep = 0.005

-- Advertising is footfall: while a line is chalked the wait for the next
-- customer is multiplied by this (0.88 is roughly 14% more people through the
-- door). The board deliberately does not change *what* a customer brings: that
-- would let a cheap advertised line crowd out the valuable stock.
Data.BoardTraffic = 0.88

Data.Board = {
    { category = "weapon", headline = "STEEL WEEK", low = 0.08, high = 0.11,
      blurb = "Every blade on the shelf reads as an honest bargain." },
    { category = "armor", headline = "IRON WEEK", low = 0.08, high = 0.11,
      blurb = "Plates, mail and leather all look like a good deal today." },
    { category = "ore", headline = "SMELTER WEEK", low = 0.11, high = 0.14,
      blurb = "The forge crowd is out and their purses are open." },
    { category = "herb", headline = "GREEN THUMB WEEK", low = 0.12, high = 0.15,
      blurb = "Alchemists are stocking up and paying for the privilege." },
    { category = "leather", headline = "HIDE WEEK", low = 0.11, high = 0.14,
      blurb = "Tanners are outbidding each other on good scrap." },
    { category = "cloth", headline = "THREAD WEEK", low = 0.12, high = 0.16,
      blurb = "Tailors are short and your bolts look like treasure." },
    { category = "gem", headline = "SPARKLE WEEK", low = 0.08, high = 0.11,
      blurb = "Cut stones catch the light and the light catches buyers." },
    { category = "enchant", headline = "DUST WEEK", low = 0.09, high = 0.12,
      blurb = "Enchanters want the powder and will not haggle hard." },
    { category = "consumable", headline = "FLASK WEEK", low = 0.13, high = 0.16,
      blurb = "Adventurers restock before the next delve, at any price." },
    { category = "recipe", headline = "PLAN WEEK", low = 0.10, high = 0.13,
      blurb = "Every scribe in town wants the patterns you have." },
    { category = "misc", headline = "CURIOSITY WEEK", low = 0.10, high = 0.14,
      blurb = "Oddities sell themselves when the sign leans on them." },
    { category = "pet", headline = "COMPANION WEEK", low = 0.08, high = 0.10,
      blurb = "Collectors bring their purses and their patience." },
}

Data.BoardByCategory = {}
for _, def in ipairs(Data.Board) do
    Data.BoardByCategory[def.category] = def
end

-- Category icons are already declared once, in Data/Items.lua.
Data.CategoryIcons = {}
for _, category in ipairs(Data.Categories or {}) do
    Data.CategoryIcons[category.key] = category.icon
end

function Data.BoardIcon(key)
    return Data.CategoryIcons[key] or "Interface\\Icons\\INV_Misc_Note_01"
end

-- One line for the tooltip and the toast: "STEEL WEEK — +9% on weapons".
function Data.BoardLine(placard)
    if not placard then return "" end
    return string.format("%s — +%d%% on %s", placard.headline or "A-BOARD",
        math.floor((placard.bonus or 0) * 100 + 0.5),
        string.lower(placard.name or "stock"))
end
