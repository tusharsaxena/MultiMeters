-- tests/test_row_cells.lua — modules/Row_Cells.lua: which of a row's cells are
-- LIVE, and giving the row back to the pool.
--
-- Peeled beside tests/test_row.lua, which sits at the layout-§1 cap, along the
-- seam modules/Row.lua was peeled on. A cell is never destroyed: a column toggled
-- off keeps its widget, hidden and blank, for when it comes back. So `self.cells`
-- holds every cell the row has EVER had, and the refresh must not walk it. It
-- walks `self.liveCells` instead, the ordered array ApplyLayout rebuilds IN PLACE
-- of the cells the layout actually shows (review F-007 / MultiMeters-R-07).

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue

--- A window instance with two known columns, plus one row built off it.
--- Duplicated from tests/test_row.lua rather than published (see
--- tests/test_row_namecell.lua for the reasoning).
local function bench()
    local inst = T.load()
    local NS = inst.NS

    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked = true
    cfg.columns = {
        { stat = "DamageDone", enabled = true },
        { stat = "Interrupts", enabled = true },
    }
    cfg.data.sortColumn = "DamageDone"

    local window = NS.Window.New(cfg)
    local row = NS.Row.New(window)
    row:ApplyLayout(window.layout)
    return inst, window, row, cfg
end

test("Update never touches a cell the layout hid, and the live list is reused in place", function()
    -- red under: a Row:Update that walks pairs(self.cells), or an ApplyLayout
    -- that allocates a fresh live set every call.
    local _, window, row, cfg = bench()
    local live = row.liveCells
    assertTrue(type(live) == "table", "ApplyLayout keeps the live cells on the row")
    assertEqual(#live, 2)
    assertTrue(live[1] == row.cells.DamageDone and live[2] == row.cells.Interrupts,
        "in the layout's column order")

    cfg.columns = { { stat = "DamageDone", enabled = true } }
    window:RefreshUpvalues()
    row:ApplyLayout(window.layout)
    assertTrue(row.liveCells == live, "the same table, cleared and refilled, never reallocated")
    assertEqual(#live, 1)
    assertTrue(live[1] == row.cells.DamageDone)

    local hidden = row.cells.Interrupts
    local touched = 0
    local real = hidden.SetValue
    hidden.SetValue = function(...) touched = touched + 1; return real(...) end
    row:Update({ guid = "Player-1-0000000A", name = "Alpha", classFilename = "MAGE",
                 values = {}, cells = {} }, 1)
    assertEqual(touched, 0, "the hidden Interrupts cell is not written on a refresh")
    assertEqual(hidden.frame:IsShown(), false)
end)
