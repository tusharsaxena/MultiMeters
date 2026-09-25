-- modules/Row_Cells.lua
--
-- Which of a row's cells are LIVE, and handing the row back to the pool. Peeled
-- out of modules/Row.lua (layout-§1) when review F-007 made the cell set a thing
-- the refresh reads rather than a thing it re-derives: both halves here walk the
-- same set, so they sit together.
--
-- A CELL IS NEVER DESTROYED. A column toggled off keeps its widget, hidden and
-- blank, so toggling it back on re-uses what it had. `row.cells` therefore holds
-- every cell the row has EVER had, and walking it on a refresh wrote into hidden
-- cells four times a second. `row.liveCells` is the ordered array of the cells
-- the layout shows, rebuilt here and ONLY here, on a layout pass — and rebuilt IN
-- PLACE: the table is cleared with a numeric loop and refilled, never replaced,
-- because a settings pass runs over every pooled row and a table per row per pass
-- is garbage for nothing. RowProto:Update walks it with a numeric loop.
--
-- The rules modules/Row.lua's header sets out apply here unchanged: no arithmetic
-- and no inspection of a meter value, and no GetWidth / GetLeft / GetPoint
-- anywhere (rule R3).

local _, NS = ...

-- Resolved at FILE SCOPE, which is what makes this file's TOC line load-bearing:
-- it must sit after modules\Row.lua, which publishes both.
local Internals = NS.RowInternals
local RowProto  = Internals.RowProto
local newCell   = Internals.newCell

--- Grow the cell set to the layout's columns, rebuild `self.liveCells` in place,
--- and hide and blank every cell whose column the layout dropped.
---
--- The `isLive` mark is how a dropped cell is found without a per-call set: every
--- cell is marked dead, the columns mark theirs live, and what is still dead is
--- hidden.
---
--- @param layout table  the window's layout (modules/Window.lua BuildLayout)
function RowProto:BindLiveCells(layout)
    local cells, live = self.cells, self.liveCells
    for _, cell in pairs(cells) do cell.isLive = false end

    local n = 0
    for _, col in ipairs(layout.columns) do
        local cell = cells[col.key]
        if not cell then
            cell = newCell(self, col.key)
            cells[col.key] = cell
        end
        cell:ApplyLayout(layout, col)
        cell.frame:Show()
        cell.isLive = true
        n = n + 1
        live[n] = cell
    end
    for i = #live, n + 1, -1 do live[i] = nil end

    for _, cell in pairs(cells) do
        if not cell.isLive then
            cell.frame:Hide()
            cell:Clear()
        end
    end
end

--- Return the row to the pool: hidden, blank, and holding no reference to the
--- player it was drawing. Every cell is blanked, the hidden ones included —
--- this runs only when a row leaves the screen, not on a refresh.
function RowProto:Release()
    self.entry = nil
    self.index = nil
    self.frame:Hide()
    self.mouseHighlight:Hide()
    self.selfHighlight:Hide()
    self.bg:Hide()
    self.nameCell:Clear()
    for _, cell in pairs(self.cells) do cell:Clear() end
end
