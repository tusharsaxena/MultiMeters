-- tests/test_row_mouse.lua — modules/Row.lua's mouse hand-off: what a row does
-- under the cursor, on the grid and inside a breakdown.
--
-- Peeled from tests/test_row.lua (layout-§1) along the mouse-handler section of
-- modules/Row.lua (cellOnEnter / rowOnEnter / the two OnMouseUp handlers). On the
-- grid a stat cell asks the tooltip the narrow question and a click routes to
-- the drill-down; inside a breakdown the row is a SPELL, the row owns the mouse
-- and a right click leaves. What stays in tests/test_row.lua: geometry, values,
-- color, borders, highlights and the pool contract, and displayText.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse
local assertNil   = T.assertNil

--- A window instance with a known column set, plus one row built off its pool.
--- Duplicated from tests/test_row.lua rather than published (see
--- tests/test_row_namecell.lua for the reasoning).
local function bench(configure)
    local inst = T.load()
    local NS = inst.NS

    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked = true
    cfg.columns = {
        { stat = "DamageDone", enabled = true },
        { stat = "Interrupts", enabled = true },
    }
    cfg.data.sortColumn = "DamageDone"
    if configure then configure(cfg) end

    local window = NS.Window.New(cfg)
    local row = NS.Row.New(window)
    row:ApplyLayout(window.layout)
    return inst, window, row, cfg
end

--- An aggregator-shaped entry.
local function entry(values, opts)
    opts = opts or {}
    return {
        guid          = opts.guid or "Player-1-0000000A",
        name          = opts.name or "Alpha",
        classFilename = opts.classFilename or "MAGE",
        specIconID    = opts.specIconID,
        role          = opts.role or "DAMAGER",
        isPlayer      = opts.isPlayer or false,
        isDrillDown   = opts.isDrillDown,
        icon          = opts.icon,
        maxAmount     = opts.maxAmount,
        values        = values,
        cells         = values,
    }
end

-- ---------------------------------------------------------------------------
-- Mouse hand-off
-- ---------------------------------------------------------------------------

test("Hovering a stat cell asks the tooltip the narrow question", function()
    local inst, _, row, cfg = bench()
    local seen
    inst.NS.Tooltip.CellTooltip = function(_, e, key) seen = { e, key } end
    inst.NS.Tooltip.NameTooltip = function() seen = { "name" } end

    row:Update(entry{ DamageDone = { total = 1, maxAmount = 1 } }, 1)
    row.cells.DamageDone.frame:_run("OnEnter")

    assertEqual(seen[2], "DamageDone")
    assertTrue(seen[1] == row.entry)

    -- Hovering the NAME cell summarizes every stat, which is the cross-column
    -- read the whole addon exists for.
    row.nameCell.frame:_run("OnEnter")
    assertEqual(seen[1], "name")

    cfg.tooltip.showAllStatsOnName = false
    seen = nil
    row.nameCell.frame:_run("OnEnter")
    assertNil(seen, "the setting switches the summary off entirely")
end)

test("Clicking a stat cell routes to the drill-down; the name cell does not", function()
    local inst, _, row = bench()
    local clicks = {}
    inst.NS.DrillDown.OnCellClick = function(_, _, _, key) clicks[#clicks + 1] = key end

    row:Update(entry{ DamageDone = { total = 1, maxAmount = 1 } }, 1)
    row.cells.DamageDone.frame:_run("OnMouseUp")
    assertEqual(#clicks, 1)
    assertEqual(clicks[1], "DamageDone")

    -- The name column's question is "how is this player doing overall", which
    -- the tooltip already answers.
    row.nameCell.frame:_run("OnMouseUp")
    assertEqual(#clicks, 1)
end)

test("A cell with no entry does nothing under the cursor", function()
    local inst, _, row = bench()
    local touched = false
    inst.NS.Tooltip.CellTooltip = function() touched = true end
    inst.NS.DrillDown.OnCellClick = function() touched = true end

    row:Release()
    row.cells.DamageDone.frame:_run("OnEnter")
    row.cells.DamageDone.frame:_run("OnMouseUp")
    assertFalse(touched)
end)

-- ---------------------------------------------------------------------------
-- Inside a breakdown, the row is a SPELL
-- ---------------------------------------------------------------------------
--
-- The rows of a drill-down are spells, and the two player tooltips answer the
-- wrong question about one. Both answers were honest and both were useless: the
-- cell tooltip asked the provider for a spell breakdown OF a spell and rendered
-- "No data yet"; the name tooltip listed every tracked statistic for a source
-- that is not a source and rendered a column of zeros.

local function spellEntry(opts)
    opts = opts or {}
    local e = entry({ DamageDone = { total = 9900 } },
        { guid = "spell:49998", name = "Death Strike", isDrillDown = true })
    e.spellID = opts.spellID ~= false and (opts.spellID or 49998) or nil
    return e
end

test("Hovering a breakdown ROW shows the client's spell tooltip", function()
    -- The ROW, not a cell: a breakdown row is one thing rather than a grid of
    -- independent numbers, so the whole of it asks one question and one frame
    -- owns the answer.
    -- red under: routing a drill row to CellTooltip / NameTooltip.
    local inst, _, row = bench()
    row:Update(spellEntry(), 1)

    row.frame:_run("OnEnter")
    assertEqual(inst.mocks.GameTooltip.__spellID, 49998,
        "the row did not hand the client a spell id")
end)

test("A breakdown row takes the mouse, and its cells give theirs up", function()
    -- WHY THE ROW TOOLTIP SHIPPED DEAD. A cell is a child of the row frame and
    -- so sits ON TOP of it, and a mouse-enabled frame consumes motion — so
    -- rowOnEnter fired only in the seams between cells and in the margin past
    -- the last column. Letting the motion through is not an option: the API for
    -- it is protected and the client answers ADDON_ACTION_BLOCKED. So the cells
    -- give the mouse up, which costs nothing because a breakdown cell has no job
    -- left. The harness calls `_run("OnEnter")` directly and never hit-tests,
    -- which is why every tooltip case here stayed green while the client showed
    -- nothing.
    -- red under: dropping the drill branch from RowProto:ApplyMouse.
    local _, _, row = bench()
    row:Update(spellEntry(), 1)

    assertEqual(row.frame:IsMouseEnabled(), true, "the row did not take the mouse")
    assertEqual(row.nameCell.frame:IsMouseEnabled(), false,
        "the name cell kept the mouse and shadows the row")
    for key, cell in pairs(row.cells) do
        assertEqual(cell.frame:IsMouseEnabled(), false,
            "cell " .. key .. " kept the mouse and shadows the row")
    end

    -- And back again: a pooled row re-pointed at a player is a grid row.
    row:Update(entry{ DamageDone = { total = 10 } }, 1)
    assertEqual(row.nameCell.frame:IsMouseEnabled(), true,
        "the cells never got the mouse back on the way out of a breakdown")
end)

test("Hovering a breakdown row lights its highlight, since no cell can", function()
    -- red under: dropping SetMouseOver from rowOnEnter/rowOnLeave.
    local _, _, row = bench()
    row:Update(spellEntry(), 1)

    -- Explicitly down first. The overlay's resting state is already hidden, so
    -- an OnEnter that does nothing at all looks exactly like a pass otherwise —
    -- which is how the first draft of this case went green against the bug.
    row:SetMouseOver(false)
    assertEqual(row.mouseHighlight:IsShown(), false, "the bench did not start dark")

    row.frame:_run("OnEnter")
    assertEqual(row.mouseHighlight:IsShown(), true)
    row.frame:_run("OnLeave")
    assertEqual(row.mouseHighlight:IsShown(), false)
end)

test("Crossing a cell boundary does NOT blink the breakdown tooltip", function()
    -- THE FLICKER. Each cell has its own OnEnter/OnLeave, so dragging the cursor
    -- sideways across a row fired hide-then-show at every seam — a tooltip
    -- blinking for no reason the player can see, on a row where every cell
    -- describes the same spell.
    -- red under: cellOnLeave hiding the tooltip for a drill row.
    local inst, _, row = bench()
    row:Update(spellEntry(), 1)

    row.frame:_run("OnEnter")
    assertEqual(inst.mocks.GameTooltip.__spellID, 49998)

    -- The cursor moves from one cell to the next, inside the same row.
    row.cells.DamageDone.frame:_run("OnEnter")
    row.cells.DamageDone.frame:_run("OnLeave")
    row.cells.Interrupts.frame:_run("OnEnter")

    assertTrue(inst.mocks.GameTooltip:IsShown(),
        "a cell seam hid the tooltip the row is still hovering")
    assertEqual(inst.mocks.GameTooltip.__spellID, 49998,
        "and it is still the same spell")
end)

test("Leaving the row hides the breakdown tooltip", function()
    -- The other half: the row owns the hide too, or the tooltip never goes away.
    -- red under: rowOnLeave not calling Tooltip:Hide.
    local inst, _, row = bench()
    row:Update(spellEntry(), 1)
    row.frame:_run("OnEnter")
    assertTrue(inst.mocks.GameTooltip:IsShown())

    row.frame:_run("OnLeave")
    assertFalse(inst.mocks.GameTooltip:IsShown(), "the tooltip outlived the row hover")
end)

test("On the GRID a cell still owns its own tooltip", function()
    -- Each column asks a different question there, so per-cell is correct rather
    -- than a bug — the row-level behavior must not leak out of the breakdown.
    -- red under: giving every row the spell tooltip.
    local inst, _, row = bench()
    local seen
    inst.NS.Tooltip.CellTooltip = function(_, _, key) seen = key end

    row:Update(entry{ DamageDone = { total = 1, maxAmount = 1 } }, 1)
    row.cells.DamageDone.frame:_run("OnEnter")
    assertEqual(seen, "DamageDone", "a grid cell stopped showing its own tooltip")
end)

test("A breakdown row with no resolvable spell still says which spell it is", function()
    -- An empty tooltip frame is worse than a plain one. The row is still telling
    -- the player something even when the client cannot name the spell.
    -- red under: returning early when spellID is nil.
    local inst, _, row = bench()
    row:Update(spellEntry{ spellID = false }, 1)
    row.frame:_run("OnEnter")

    assertNil(inst.mocks.GameTooltip.__spellID)
    local lines = inst.mocks.GameTooltip.__lines
    assertTrue(#lines > 0, "an unresolvable spell produced an empty tooltip")
    assertEqual(lines[1].text, "Death Strike")
end)

test("A left click inside a breakdown does nothing", function()
    -- It used to reach OnCellClick with a spell row, which asked the provider
    -- for a breakdown of a spell, got nothing, and rendered an EMPTY WINDOW —
    -- which reads as a broken addon rather than as "there is nothing here".
    -- red under: falling through to DrillDown:OnCellClick.
    local inst, _, row, cfg = bench()
    row:Update(spellEntry(), 1)

    local calls = 0
    local real = inst.NS.DrillDown.OnCellClick
    inst.NS.DrillDown.OnCellClick = function(...) calls = calls + 1; return real(...) end

    row.cells.DamageDone.frame:_run("OnMouseUp", "LeftButton")
    assertEqual(calls, 0, "a left click on a spell row still tried to drill into it")
    assertTrue(cfg ~= nil)
end)

test("A right click leaves the breakdown", function()
    -- The only way out that does not require finding the cell you came in on.
    -- red under: OnMouseUp ignoring the button argument.
    local inst, _, row, cfg = bench()
    local D = inst.NS.DrillDown

    D:Enter(cfg, entry({ DamageDone = { total = 100 } }), "DamageDone")
    assertTrue(D.IsActive(cfg), "the fixture never entered a breakdown")

    row:Update(spellEntry(), 1)
    row.cells.DamageDone.frame:_run("OnMouseUp", "RightButton")

    assertFalse(D.IsActive(cfg), "right click did not leave the breakdown")
end)

test("A right click on the ROW ITSELF leaves the breakdown", function()
    -- Distinct from the cell case, and not covered by it: the cells do not tile
    -- the row. There are seams between them and a margin past the last column,
    -- and a right-click landing in one of those used to do nothing at all.
    -- red under: dropping rowOnMouseUp from the row frame.
    local inst, _, row, cfg = bench()
    local D = inst.NS.DrillDown

    D:Enter(cfg, entry({ DamageDone = { total = 100 } }), "DamageDone")
    assertTrue(D.IsActive(cfg), "the fixture never entered a breakdown")

    row:Update(spellEntry(), 1)
    row.frame:_run("OnMouseUp", "RightButton")

    assertFalse(D.IsActive(cfg), "a right click on the row's own frame did nothing")
end)

test("A right click on the GRID is a harmless no-op", function()
    -- Exit answers false when there is no view to leave, so a stray right click
    -- costs nothing and needs no special case at the call site.
    -- red under: an Exit that errors or a handler that drills on right click.
    local inst, _, row, cfg = bench()
    row:Update(entry({ DamageDone = { total = 100 } }), 1)

    row.cells.DamageDone.frame:_run("OnMouseUp", "RightButton")
    assertFalse(inst.NS.DrillDown.IsActive(cfg), "a right click on the grid opened something")
end)

test("Cells register for BOTH buttons, or the right click never arrives", function()
    -- A right-click handler on a frame that never called RegisterForClicks is a
    -- silent failure: the code is correct and the client never calls it.
    -- red under: dropping the RegisterForClicks call.
    local _, _, row = bench()
    local clicks = row.cells.DamageDone.frame.__clicks
    assertTrue(clicks ~= nil, "the cell never registered for clicks at all")

    local seen = {}
    for _, b in ipairs(clicks) do seen[b] = true end
    assertTrue(seen["LeftButtonUp"], "left clicks are not registered")
    assertTrue(seen["RightButtonUp"], "right clicks are not registered")
end)
