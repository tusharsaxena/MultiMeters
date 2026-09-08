-- tests/test_columnblocks.lua
--
-- settings/ColumnBlocks.lua — the ROW of a reorderable list, and its wiring.
--
-- IT KNOWS NOTHING ABOUT STATISTICS, which is why it is its own file and why
-- this suite drives it with a made-up item list. A suite that reached for
-- Const.STATS would be quietly asserting the coupling the file exists to avoid;
-- everything statistic-shaped is settings/Columns.lua's.
--
-- THE GESTURE ITSELF IS NOT TESTED HERE ANY MORE. It belongs to
-- LibKa0s-Widgets-1.0's ReorderList since minor 8 -- the handle, the carried
-- copy, the insertion line, the clamp -- and LibKa0s' own tests/test_widgets.lua
-- covers it once for every consumer. Re-asserting it here would be two suites
-- claiming the same thing, and one of them going stale.
--
-- What is left is what this file owns: the row, and the wiring. Drags still run
-- through their real scripts, because the WIRING is what is under test -- a
-- boundary passed from the wrong end, or a controller nobody cancels, both look
-- exactly like a working list right up until you drag one.

local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue, assertFalse = T.assertEqual, T.assertTrue, T.assertFalse

local ITEMS = {
    { key = "a", label = "Alpha",   enabled = true  },
    { key = "b", label = "Bravo",   enabled = true  },
    { key = "c", label = "Charlie", enabled = true  },
    { key = "d", label = "Delta",   enabled = false },
    { key = "e", label = "Echo",    enabled = false },
}

--- A rendered block list, plus a log of what it asked its host for.
---
--- `ctx` is optional and is how the recycling cases are written: passing the SAME
--- context back re-renders into the same scroll, which is what makes AceGUI hand
--- the same pooled SimpleGroups over and the raw blocks on them come back. A
--- fresh panel per render would never pool anything, and the stacking bug this
--- widget was rebuilt for would be invisible.
local function render(inst, items, ctx)
    local NS  = inst.NS
    local log = { toggled = {}, moved = {} }

    ctx = ctx or NS.Helpers.CreatePanel("MultiMetersBlockTestPanel", "Blocks", {})
    -- Exactly what settings/Columns.lua's render does, and in that order: cancel, THEN clear. A
    -- helper that skipped the cancel would be testing a page nobody ships.
    if NS.CancelReorder then NS.CancelReorder(ctx) end
    NS.Helpers.ClearScroll(ctx)

    local blocks = NS.ReorderableBlocks(ctx, {
        items    = items or ITEMS,
        onToggle = function(i) log.toggled[#log.toggled + 1] = i end,
        onMove   = function(from, to) log.moved[#log.moved + 1] = { from, to } end,
    })
    return blocks, log, ctx
end

--- Pick block `from` up, move the cursor `rows` rows DOWN, and release.
--- Negative `rows` drags upward. Screen y DECREASES downward.
---
--- Driven the way the client drives it: press, move, let go. The drop is decided
--- by the OnUpdate that first sees the button released, not by a separate
--- OnDragStop -- which is the whole reason the widget stopped using
--- RegisterForDrag.
local function drag(inst, blocks, from, rows)
    local block  = blocks[from]
    local handle = block.mmHandle

    inst.mocks.setMouseDown("LeftButton", true)
    inst.mocks.setCursor(0, 1000)
    handle:_run("OnMouseDown")

    inst.mocks.setCursor(0, 1000 - rows * inst.NS.BLOCK_STRIDE)
    block:_run("OnUpdate", 0.1)

    inst.mocks.setMouseDown("LeftButton", false)
    block:_run("OnUpdate", 0.1)
end

test("Blocks: one block per item, each carrying its index and its label", function()
    local inst = T.load()
    local blocks = render(inst)

    assertEqual(#blocks, #ITEMS)
    for i, item in ipairs(ITEMS) do
        assertEqual(blocks[i].mmIndex, i)
        assertEqual(blocks[i].mmLabel:GetText(), item.label)
    end
end)

test("Blocks: the glyph says enabled or disabled, and clicking it toggles", function()
    local inst = T.load()
    local blocks, log = render(inst)

    assertFalse(blocks[1].mmGlyphTexture == blocks[4].mmGlyphTexture,
        "an enabled block and a disabled one must not wear the same glyph")

    blocks[4].mmGlyph:_run("OnClick")
    assertEqual(#log.toggled, 1)
    assertEqual(log.toggled[1], 4, "the glyph must report ITS OWN index")
end)

test("Blocks: the glyph's tooltip says what the CLICK will do", function()
    -- A tick that said "shown" would describe the thing you are already looking at. The question a
    -- player has over a control is what happens if they press it.
    -- red under: keying the tooltip on the glyph's meaning instead of its effect, or reading the
    -- enabled flag at wire time rather than at hover time.
    local inst = T.load()
    local L = inst.NS.L
    local blocks = render(inst)

    blocks[1].mmGlyph:_run("OnEnter")
    assertEqual(inst.mocks.GameTooltip.__lines[1].text, L["Click to hide this column"],
        "a shown column's glyph must offer to hide it")

    inst.mocks.GameTooltip.__lines = {}
    blocks[4].mmGlyph:_run("OnEnter")
    assertEqual(inst.mocks.GameTooltip.__lines[1].text, L["Click to show this column"],
        "a hidden column's glyph must offer to show it")
end)

test("Blocks: a repaint gives every block back before it takes any out", function()
    -- THE GHOST LABEL OVER ROW ONE. The blocks are CreateFrame children, not AceGUI widgets, so
    -- ClearScroll's ReleaseChildren neither hides them nor knows they exist -- they ride a released
    -- SimpleGroup into whatever asks for one next. On an options page that is almost everything,
    -- and what it was in practice was the SPACER between the page's intro line and the first block:
    -- a container handed out with a live block still parented to it, drawn exactly over row one.
    --
    -- So the blocks are pooled here and released on the next render. The count out must equal the
    -- count in, or something is still parented to a frame the page has already given away.
    -- red under: caching a block on slot.frame instead of pooling it.
    local inst = T.load()
    local first, _, ctx = render(inst)
    assertEqual(#first, #ITEMS)

    local before = {}
    for i, b in ipairs(first) do before[i] = b end

    local second = render(inst, nil, ctx)
    assertEqual(#second, #ITEMS, "the repaint must still draw one block per item")

    -- Every block from the first render came back and went out again: the pool is the only source.
    local seen = {}
    for _, b in ipairs(second) do seen[b] = true end
    for i, b in ipairs(before) do
        assertTrue(seen[b], "block " .. i .. " was abandoned rather than released")
    end
end)

test("Blocks: a released block is off its AceGUI frame, not merely hidden", function()
    -- Hiding is not enough. The frame goes back to a process-wide pool and the next widget to take
    -- it inherits whatever is still parented to it -- shown or not, a stray child is a stray child
    -- the moment something calls Show on the container.
    local inst = T.load()
    local blocks, _, ctx = render(inst)
    local block = blocks[1]
    local slot  = block:GetParent()
    assertTrue(slot ~= nil)

    inst.NS.CancelReorder(ctx)

    assertFalse(block:IsShown(), "a released block must not be visible")
    assertFalse(block:GetParent() == slot,
        "a released block is still on the AceGUI frame the page is about to give away")
end)

test("Blocks: a reused block reports the index it now carries, not the one it was built with", function()
    -- The other half of the stacking bug. Every script reads block.mmIndex at
    -- FIRE time; a closure over the index it was wired with meant the glyph you
    -- could see belonged to the newest block while the click it delivered carried
    -- an older render's index -- so ticking one statistic toggled a different one.
    -- red under: glyph:SetScript closing over `index`.
    local inst = T.load()
    local _, _, ctx = render(inst)

    -- Same slots, ITEMS reversed, so every block now carries a different index.
    local reversed = {}
    for i = #ITEMS, 1, -1 do reversed[#reversed + 1] = ITEMS[i] end
    local blocks, log = render(inst, reversed, ctx)

    blocks[1].mmGlyph:_run("OnClick")
    assertEqual(log.toggled[1], 1, "the block reported a stale index")
    assertEqual(blocks[1].mmLabel:GetText(), reversed[1].label,
        "and it must be showing the item that index now names")
end)

test("Blocks: a drag reports where it landed", function()
    local inst = T.load()
    local blocks, log = render(inst)

    drag(inst, blocks, 1, 2)
    assertEqual(#log.moved, 1)
    assertEqual(log.moved[1][1], 1)
    assertEqual(log.moved[1][2], 3, "two rows down from index 1 is index 3")
end)

test("Blocks: the page hands LibKa0s the boundary, so a shown column stops at the rule", function()
    -- THE CLAMP IS THE LIBRARY'S; passing it the right divide is this file's. A shown column may
    -- not be dragged among the hidden ones -- the tick is what moves a block between them, and a
    -- drag that crossed would have to silently turn a column off.
    -- red under: boundary not passed, or counted from the wrong end.
    local inst = T.load()
    local blocks, log = render(inst)   -- ITEMS is three enabled, then two disabled

    drag(inst, blocks, 1, 4)
    assertEqual(log.moved[1][2], 3, "an enabled block stopped somewhere other than the divide")
end)

test("Blocks: a hidden column has no handle, because its order means nothing", function()
    -- The hidden group HAS an order -- it is where a column lands when you tick it back on -- but
    -- nothing reads it, so dragging one was a gesture that appeared to do something and did not.
    --
    -- The row is still REGISTERED with the library, which is why the case checks both halves: drop
    -- the registration and the indices shift, and the rule a shown column clamps against is the
    -- first hidden row's own top edge.
    -- red under: draggable not passed, or the hidden rows not registered at all.
    local inst = T.load()
    local blocks = render(inst)

    assertTrue(blocks[1].mmHandle ~= nil, "a shown column must be draggable")
    assertTrue(blocks[3].mmHandle ~= nil, "the last shown column too")
    assertEqual(blocks[4].mmHandle, nil, "a hidden column must not offer a handle")
    assertEqual(blocks[5].mmHandle, nil)
end)

test("Blocks: a repaint cancels the controller the render before it built", function()
    -- A drag must not outlive the list it was describing. The chrome it leaves on screen -- the
    -- carried copy, the insertion line -- names rows that may not be there any more, and putting
    -- it away is the library's job once this file says the list is gone.
    -- red under: ReorderableBlocks not calling Cancel on ctx.mmReorder.
    local inst = T.load()
    local blocks, _, ctx = render(inst)

    inst.mocks.setMouseDown("LeftButton", true)
    inst.mocks.setCursor(0, 1000)
    blocks[1].mmHandle:_run("OnMouseDown")

    local before = ctx.mmReorder
    assertTrue(before ~= nil, "no controller was built")

    render(inst, nil, ctx)
    assertTrue(before.dead, "the previous render's controller was left live")
    assertFalse(ctx.mmReorder == before, "a repaint must build a fresh controller")
end)

test("Blocks: a drag that lands where it started reports nothing", function()
    -- Reporting it would rewrite the array and repaint the page for no change.
    local inst = T.load()
    local blocks, log = render(inst)

    drag(inst, blocks, 2, 0)
    assertEqual(#log.moved, 0, "a drag with no movement is not a reorder")
end)

test("Blocks: an enabled block cannot be dragged past the last enabled one", function()
    -- The tick is what moves a block between groups. A drag that crossed the rule
    -- would have to silently disable it -- a state change from a gesture that
    -- means "move", not "turn off".
    local inst = T.load()
    local blocks, log = render(inst)

    drag(inst, blocks, 1, 4)
    assertEqual(#log.moved, 1)
    assertEqual(log.moved[1][2], 3, "clamped to the last enabled index, not index 5")
end)

test("Blocks: a list with nothing disabled drags end to end", function()
    local inst = T.load()
    local allOn = {}
    for i, item in ipairs(ITEMS) do
        allOn[i] = { key = item.key, label = item.label, enabled = true }
    end
    local blocks, log = render(inst, allOn)

    drag(inst, blocks, 1, 4)
    assertEqual(log.moved[1][2], 5, "with no rule to clamp against, every index is reachable")
end)

-- ---------------------------------------------------------------------------
-- The row box belongs to the library (options-ui-§18)
-- ---------------------------------------------------------------------------

test("Blocks: this file draws NO row background of its own", function()
    -- It used to. `block.bg` was a texture at 1,1,1 / 0.06 -- the exact fill
    -- options-ui-§8 now pins and LibKa0s-Widgets-1.0 minor 9 draws for every
    -- draggable list in the collection -- so keeping it would paint two fills over
    -- each other and make every row a shade darker than the standard says.
    -- red under: re-adding the texture "so the list looks right without the
    -- library", which is exactly the drift the shared widget exists to end.
    local inst = T.load()
    local blocks = render(inst)
    for i, block in ipairs(blocks) do
        assertTrue(block.bg == nil, "block " .. i .. " still carries a host-drawn background")
    end
end)

test("Blocks: the library's box is behind every row, muted for a hidden column", function()
    -- The box is the widget's and the values are options-ui-§8's; what this file
    -- still decides is WHICH rows are dimmed, and it says so with one word on the
    -- row's spec rather than by painting anything.
    -- red under: dropping `dimmed`, which would draw a hidden column at full
    -- strength and lose the only thing telling it from a shown one at a glance.
    local inst = T.load()
    local W = inst.mocks.LibStub("LibKa0s-Widgets-1.0", true)
    assertTrue(W ~= nil, "the fixture needs the vendored widget library")

    local _, _, ctx = render(inst)
    local rows = ctx.mmReorder and ctx.mmReorder.rows
    assertTrue(rows ~= nil and #rows == #ITEMS, "the controller registered every row")

    for i, item in ipairs(ITEMS) do
        local box = rows[i].box
        assertTrue(box ~= nil, "row " .. i .. " got no box")
        local want = item.enabled and W.ROW_BOX.FILL or W.ROW_BOX.FILL_DIM
        local got = box.fill.__colorTexture
        assertEqual(got[4], want[4],
            "row " .. i .. " (" .. item.label .. ") is painted at the wrong strength")
    end
end)

test("Blocks: the handle's gutter is the library's, never restated here", function()
    -- options-ui-§8 pins it at 30 and `Widgets.ROW_BOX.HANDLE_W` is where it lives;
    -- a host copy is the copy that goes stale the day the collection retunes it.
    -- red under: passing `handleSize` again, with any number in it.
    local inst = T.load()
    local W = inst.mocks.LibStub("LibKa0s-Widgets-1.0", true)
    local blocks = render(inst)
    assertEqual(blocks[1].mmHandle:GetWidth(), W.ROW_BOX.HANDLE_W)
end)

test("Blocks: the rule is drawn once, under the last enabled block", function()
    -- It marks where the shown columns stop. A list with nothing disabled has no
    -- boundary to mark, and drawing one would claim a group that is not there.
    local inst = T.load()
    local blocks = render(inst)
    assertEqual(#blocks, #ITEMS, "the rule must not be counted as a block")

    local allOn = {}
    for i, item in ipairs(ITEMS) do
        allOn[i] = { key = item.key, label = item.label, enabled = true }
    end
    local onlyOn = render(inst, allOn)
    assertEqual(#onlyOn, #ITEMS)
end)

-- ---------------------------------------------------------------------------
-- Characterization: the shape of ReorderableBlocks, ahead of its split (#44)
-- ---------------------------------------------------------------------------
--
-- The member is CCN 28 and its loop body does three jobs at once -- the AceGUI
-- slot, the library row descriptor and the boundary rule. A later wave splits
-- those apart. The cases below exist for that wave: they pin the arms and the
-- exact values a split can drop without any of the cases above going red, and
-- they were written and run AGAINST THE UNSPLIT CODE (performance-§11).

test("Blocks: a spec that is not a table is refused, and refused without touching the page",
function()
    -- The guard is the first line of the member and it runs BEFORE ctx.mmReorder and ctx.mmBlocks
    -- are re-parked -- which is the half that matters. A refusal that cleared them would strand the
    -- previous render's blocks on AceGUI frames the page is free to hand out, with nothing left
    -- holding a reference to release them. That is the ghost-label bug arriving through the door
    -- marked "bad input".
    -- red under: moving the ctx writes above the guard, or returning nil instead of {}.
    local inst = T.load()
    local blocks, _, ctx = render(inst)
    local liveList, liveCtl = ctx.mmBlocks, ctx.mmReorder

    for _, bad in ipairs({ "nope", 7, true }) do
        local got = inst.NS.ReorderableBlocks(ctx, bad)
        assertEqual(type(got), "table", "a refusal must still answer a list")
        assertEqual(#got, 0)
    end
    local got = inst.NS.ReorderableBlocks(ctx)   -- and no spec at all
    assertEqual(#got, 0)

    assertTrue(ctx.mmBlocks == liveList, "a refusal orphaned the previous render's blocks")
    assertTrue(ctx.mmReorder == liveCtl, "a refusal dropped the live controller on the floor")
    assertEqual(#liveList, #blocks, "and the parked list must still name every one of them")
end)

test("Blocks: with AceGUI absent the page refuses rather than half-drawing", function()
    -- The other arm of the same three-way guard. Nothing here can be built without the widget
    -- factory -- the slot is an AceGUI SimpleGroup -- so the member answers an empty list and
    -- leaves the ctx alone, exactly as it does for a bad spec.
    -- red under: splitting the guard so the loop is entered and each slot creation fails on its own.
    local inst = T.load()
    local ctx = inst.NS.Helpers.CreatePanel("MultiMetersBlockNoAceGUI", "Blocks", {})
    local saved = inst.NS.AceGUI
    inst.NS.AceGUI = nil
    local ok, got = pcall(inst.NS.ReorderableBlocks, ctx, { items = ITEMS })
    inst.NS.AceGUI = saved

    assertTrue(ok, "the refusal raised instead of returning: " .. tostring(got))
    assertEqual(#got, 0)
    assertEqual(ctx.mmReorder, nil, "no controller may be built on a page that cannot draw rows")
    assertEqual(ctx.mmBlocks, nil)
end)

test("Blocks: an empty item list still builds and finishes a controller", function()
    -- `items` absent is not the same refusal as a bad spec: the member falls through to an empty
    -- walk and still hands the library a list, because the ctx must end the render owning a LIVE
    -- controller -- it is what the next repaint calls Cancel on. A version that returned early on
    -- `count == 0` would leave the previous render's controller parked and cancelled twice, and the
    -- one after that never cancelled at all.
    -- red under: an early return for the empty case.
    local inst = T.load()
    local ctx = inst.NS.Helpers.CreatePanel("MultiMetersBlockEmptyPanel", "Blocks", {})
    local blocks = inst.NS.ReorderableBlocks(ctx, { items = {} })

    assertEqual(#blocks, 0)
    assertTrue(ctx.mmReorder ~= nil, "an empty list still owns a controller")
    assertEqual(#ctx.mmReorder.rows, 0)
    assertEqual(ctx.mmReorder.boundary, 0)
    assertTrue(ctx.mmReorder.line ~= nil, "Finish must run even with nothing to finish")
end)

test("Blocks: the boundary is a COUNT of enabled items, never a scan for the first disabled",
function()
    -- normalizeColumns guarantees the shown ones come first, so on any list the page actually
    -- renders the two agree and the difference is invisible. It stops being invisible the moment a
    -- caller hands over an unsorted list -- a half-migrated profile, a test fixture, a future
    -- caller that has not normalized yet -- and the two answers diverge. This file COUNTS, and the
    -- comment above the loop says so: the ordering is normalizeColumns' guarantee rather than
    -- something arranged here.
    -- red under: `for i, item ... if not item.enabled then boundary = i - 1; break end`, which is
    -- the obvious simplification and answers 1 for the list below instead of 2.
    local inst = T.load()
    local mixed = {
        { key = "a", label = "Alpha", enabled = true  },
        { key = "b", label = "Bravo", enabled = false },
        { key = "c", label = "Charlie", enabled = true  },
    }
    local _, _, ctx = render(inst, mixed)
    assertEqual(ctx.mmReorder.boundary, 2, "the boundary counted, it did not scan")
end)

test("Blocks: the rule is an empty AceGUI Heading, sitting after the boundary block", function()
    -- What "the rule" IS, rather than what it is not. The cases above only check that it is not
    -- counted as a block; a split that dropped the widget entirely, or drew it with text in it, or
    -- put it after the wrong row, passes every one of them.
    -- red under: hoisting the rule out of the loop and appending it at the end, which draws it under
    -- the LAST block rather than the last enabled one.
    local inst = T.load()
    local _, _, ctx = render(inst)          -- ITEMS is three enabled, then two disabled
    local kids = ctx.scroll.children

    assertEqual(#kids, #ITEMS + 1, "one slot per item, plus exactly one rule")
    for i = 1, #kids do
        assertEqual(kids[i].type, i == 4 and "Heading" or "SimpleGroup",
            "child " .. i .. " is the wrong widget")
    end
    local rule = kids[4]
    assertEqual(rule.text, "", "the rule is a bare line: a caption would name a group that has none")
    assertEqual(rule.height, 12)
    assertTrue(rule.fullWidth, "a rule that stops short of the edge does not read as a divide")
end)

test("Blocks: no rule is drawn when there is no divide to mark, at either end", function()
    -- Two arms of `i == boundary and boundary < count`, and they fail differently. All enabled:
    -- boundary equals count, so the rule would sit under the last row with nothing beneath it.
    -- All disabled: boundary is 0, so `i == boundary` is never true and there is no last-enabled
    -- row to hang it from -- a version that anchored the rule to `boundary + 1` instead would draw
    -- one above row one.
    -- red under: dropping the `boundary < count` half, or rewriting the test as `i > boundary`.
    local inst = T.load()

    local function shapes(items)
        local _, _, ctx = render(inst, items)
        local out = {}
        for i, kid in ipairs(ctx.scroll.children) do out[i] = kid.type end
        return table.concat(out, ",")
    end

    local allOn, allOff = {}, {}
    for i, item in ipairs(ITEMS) do
        allOn[i]  = { key = item.key, label = item.label, enabled = true }
        allOff[i] = { key = item.key, label = item.label, enabled = false }
    end

    assertEqual(shapes(allOn), "SimpleGroup,SimpleGroup,SimpleGroup,SimpleGroup,SimpleGroup",
        "a list with nothing hidden has no boundary to mark")
    assertEqual(shapes(allOff), "SimpleGroup,SimpleGroup,SimpleGroup,SimpleGroup,SimpleGroup",
        "a list with nothing shown has no boundary to mark either")
end)

test("Blocks: the label is gold when the column is shown and grey when it is not", function()
    -- Greyed rather than hidden, and the exact pair is the contract: a label you cannot read is a
    -- block you cannot aim at, and aiming at it is how you turn the column back on. The gold is the
    -- collection's 1, 0.82, 0.
    -- red under: hiding the label for a disabled column, or dimming it by alpha on the block --
    -- which would take the glyph down with it.
    local inst = T.load()
    local blocks = render(inst)

    local function color(block)
        local r, g, b = block.mmLabel:GetTextColor()
        return string.format("%.2f,%.2f,%.2f", r, g, b)
    end
    assertEqual(color(blocks[1]), "1.00,0.82,0.00", "a shown column's label must be gold")
    assertEqual(color(blocks[3]), "1.00,0.82,0.00")
    assertEqual(color(blocks[4]), "0.50,0.50,0.50", "a hidden column's label must be grey")
    assertTrue(blocks[4].mmLabel:IsShown(), "a hidden column's label is dimmed, never hidden")
end)

test("Blocks: the carried copy says the same thing the row does", function()
    -- The ghost is drawn by the library out of what this file put on the row descriptor, and it is
    -- the only part of a drag the player reads while the drag is in flight. Text, icon and colour
    -- all come off the SAME item the block was applied from -- a ghost that named a different row
    -- than the one under the cursor is a drag you cannot trust.
    -- red under: a split that builds the row descriptor from `items[i]` while the block was applied
    -- from something else, or that forgets ghostIcon and leaves the carried copy blank.
    local inst = T.load()
    local blocks, _, ctx = render(inst)
    local rows = ctx.mmReorder.rows

    for i, item in ipairs(ITEMS) do
        assertEqual(rows[i].ghostText, item.label, "row " .. i .. " carries the wrong name")
        assertEqual(rows[i].ghostIcon, blocks[i].mmGlyphTexture,
            "row " .. i .. "'s ghost wears a different glyph than the block does")
        local c = rows[i].ghostTextColor
        assertTrue(c ~= nil, "row " .. i .. " got no ghost colour")
        assertEqual(c[1], item.enabled and 1 or 0.5)
        assertEqual(c[2], item.enabled and 0.82 or 0.5)
        assertEqual(c[3], item.enabled and 0 or 0.5)
    end
end)

test("Blocks: every hidden row is registered, so the indices the library moves are the real ones",
function()
    -- The half the handle case cannot see. `draggable = false` returns nil from AddRow, so a split
    -- that skipped AddRow entirely for a hidden column would leave `blocks[i].mmHandle` nil either
    -- way and pass -- while the library's row list silently lost two entries, the boundary stopped
    -- matching anything, and a shown column dragged down ran off the end of a three-row list.
    -- red under: `if item.enabled then list:AddRow(...) end`.
    local inst = T.load()
    local blocks, _, ctx = render(inst)
    local rows = ctx.mmReorder.rows

    assertEqual(#rows, #ITEMS, "the hidden rows were not registered")
    for i = 1, #ITEMS do
        assertEqual(rows[i].index, i, "row " .. i .. " is registered out of order")
        assertTrue(rows[i].frame == blocks[i], "row " .. i .. " names a frame that is not its block")
    end
    assertEqual(#ctx.mmReorder.handles, 3, "exactly the three shown columns may be picked up")
end)

test("Blocks: the geometry handed to the library is the published pair, not a private copy",
function()
    -- settings/Columns.lua's suite computes drop distances from NS.BLOCK_STRIDE, so the number the
    -- controller does its arithmetic on and the number that is published have to be the one number.
    -- A split that passed a literal here would still drag correctly and would make that suite lie.
    -- red under: `stride = 34` or `height = 30` written out in the descriptor.
    local inst = T.load()
    local NS = inst.NS
    local _, _, ctx = render(inst)

    assertEqual(NS.BLOCK_STRIDE, NS.BLOCK_HEIGHT + 4, "the stride is the height plus its gap")
    assertEqual(ctx.mmReorder.stride, NS.BLOCK_STRIDE, "the library is doing its arithmetic on a copy")
    for i = 1, #ITEMS do
        assertEqual(ctx.mmReorder.rows[i].height, NS.BLOCK_HEIGHT, "row " .. i .. " is the wrong height")
    end
    -- The SLOT is a stride tall and the BLOCK is a height tall: the difference is the gap between
    -- one row and the next, and a slot sized to the block would close it up.
    for i = 1, #ITEMS do
        assertEqual(ctx.scroll.children[i <= 3 and i or i + 1].height, NS.BLOCK_STRIDE,
            "slot " .. i .. " is not one stride tall")
    end
end)

test("Blocks: the handle offers the localized drag tooltip, and the catalogued icon", function()
    -- Both are passed once, on the descriptor, and neither is visible anywhere else: a split that
    -- dropped `handleTooltip` leaves a control with no explanation, and one that dropped
    -- `handleIcon` falls back to the library's own art and quietly leaves this list wearing
    -- different furniture than the rest of the collection.
    -- red under: either key going missing from the ReorderList descriptor.
    local inst = T.load()
    local blocks = render(inst)
    local handle = blocks[1].mmHandle

    assertEqual(handle.__tooltip, inst.NS.L["Drag to reorder"])
    assertEqual(handle.art:GetTexture(), inst.NS.Icon("segment"),
        "the handle is wearing art the media catalog did not hand it")
end)

test("Blocks: the glyph sits clear of the library's handle gutter", function()
    -- The gutter is the library's 30px and the glyph is this file's, so the one thing that keeps
    -- them off each other is an inset larger than the gutter -- computed nowhere, just chosen. It
    -- is pinned as a RELATION rather than as the literal 42, because the number that matters is
    -- "outside the gutter" and the day options-ui-§8 retunes the gutter is the day a literal here
    -- would still pass while the glyph sat under the handle.
    -- red under: retuning the gutter without moving the glyph, or anchoring the glyph to LEFT 0.
    local inst = T.load()
    local W = inst.mocks.LibStub("LibKa0s-Widgets-1.0", true)
    local blocks = render(inst)

    local point, _, _, x = blocks[1].mmGlyph:GetPoint(1)
    assertEqual(point, "LEFT")
    assertTrue(x > W.ROW_BOX.HANDLE_W,
        "the glyph is inside the drag gutter (at " .. tostring(x) .. ", gutter "
        .. tostring(W.ROW_BOX.HANDLE_W) .. ")")
end)

test("Blocks: a reused block comes back at full alpha", function()
    -- A block the library faded for a drag is a block the pool hands out faded. The library restores
    -- its own row on Cancel, but the block that comes OUT of this file's pool has been through a
    -- Hide, a reparent and an unanchor since then, and applyBlock is the only place that can speak
    -- for it. Skipping the restore left a ghost-pale row on the next render, which reads as a
    -- disabled column that is not one.
    -- red under: dropping SetAlpha from applyBlock on the grounds that the library already did it.
    local inst = T.load()
    local blocks, _, ctx = render(inst)
    blocks[1]:SetAlpha(0.35)

    local again = render(inst, nil, ctx)
    for i, block in ipairs(again) do
        assertEqual(block:GetAlpha(), 1, "block " .. i .. " came out of the pool faded")
        assertTrue(block:IsShown(), "block " .. i .. " came out of the pool hidden")
    end
end)

test("Blocks: an item with no label draws an empty string, not a nil", function()
    -- FontString:SetText(nil) is a raise in the client, and a column key that outlived its locale
    -- entry is exactly how a nil label arrives -- a migrated profile naming a statistic this build
    -- no longer has a name for. An empty row is a row you can still tick back off; a raise takes
    -- the whole options page down mid-render.
    -- red under: `block.mmLabel:SetText(item.label)`.
    local inst = T.load()
    local nameless = { { key = "x", enabled = true }, { key = "y", enabled = false } }
    local ok, blocks = pcall(render, inst, nameless)

    assertTrue(ok, "a label-less item raised: " .. tostring(blocks))
    assertEqual(blocks[1].mmLabel:GetText(), "")
    assertEqual(blocks[2].mmLabel:GetText(), "")
end)

test("Blocks: CancelReorder survives a page that never rendered a list", function()
    -- It is called unconditionally at the top of every render, including the first one and including
    -- pages that turn out to have no list on them at all. A guard that assumed a live ctx would turn
    -- the first paint of the columns page into a raise.
    -- red under: `ctx.mmReorder:Cancel()` without the nil check, or indexing ctx before testing it.
    local inst = T.load()
    local NS = inst.NS

    assertTrue(pcall(NS.CancelReorder), "CancelReorder(nil) raised")
    assertTrue(pcall(NS.CancelReorder, {}), "CancelReorder on a bare table raised")

    local ctx = NS.Helpers.CreatePanel("MultiMetersBlockVirginPanel", "Blocks", {})
    assertTrue(pcall(NS.CancelReorder, ctx), "CancelReorder on an unrendered page raised")
    assertEqual(ctx.mmReorder, nil)
end)

test("Blocks: cancelling twice releases the blocks once", function()
    -- The parked list is emptied as it is walked, so the second Cancel finds nothing. It matters
    -- because Cancel runs at the top of every render AND from the page's own teardown: a release
    -- that ran twice would push each block into the free list twice and hand the same frame to two
    -- rows of the next render -- one visible block, two indices, and a click that toggles whichever
    -- of them was applied last.
    -- red under: releaseBlocks reading `ctx.mmBlocks` without clearing it as it goes.
    local inst = T.load()
    local blocks, _, ctx = render(inst)
    inst.NS.CancelReorder(ctx)
    inst.NS.CancelReorder(ctx)

    assertEqual(#ctx.mmBlocks, 0, "the parked list was not emptied as it was walked")

    -- The pool must not be holding any block twice: a second render asks for exactly as many
    -- blocks as there are items and every one of them must be a different frame.
    local again = render(inst, nil, ctx)
    local seen = {}
    for i, b in ipairs(again) do
        assertFalse(seen[b], "block " .. i .. " is the same frame as an earlier one in the same render")
        seen[b] = true
    end
    assertEqual(#again, #ITEMS)
    for _, b in ipairs(blocks) do assertTrue(seen[b], "a released block never came back") end
end)

test("Blocks: the release is announced on the debug log, with the count", function()
    -- debug-logging: the release count is the one number that says whether the pool is balanced, and
    -- a leak shows up here as a count that stops matching the row count. It is gated on the flag and
    -- on there being something to say -- a render that released nothing must stay silent, or every
    -- first paint in the game logs a zero.
    -- red under: logging unconditionally, or losing the count from the line.
    local inst = T.load()
    local NS = inst.NS
    NS.State.debug = true

    local ctx = NS.Helpers.CreatePanel("MultiMetersBlockDebugPanel", "Blocks", {})
    NS.CancelReorder(ctx)
    assertEqual(NS.DebugLog:FindLine("released 0 blocks"), nil,
        "a render with nothing to release must say nothing")

    NS.Helpers.ClearScroll(ctx)
    NS.ReorderableBlocks(ctx, { items = ITEMS, onToggle = function() end, onMove = function() end })
    NS.CancelReorder(ctx)
    NS.State.debug = false

    local line = NS.DebugLog:FindLine("released " .. #ITEMS .. " blocks")
    assertTrue(line ~= nil, "the release count never reached the log; last line: "
        .. tostring(NS.DebugLog:LastLine()))
end)

test("Blocks: the returned list and the list parked on the ctx are two tables, same contents",
function()
    -- The caller gets a list it may keep; the ctx gets the one the NEXT render empties. Handing back
    -- the SAME table means the next release wipes the caller's copy out from under it -- and
    -- settings/Columns.lua holds on to what it was given.
    -- red under: `ctx.mmBlocks = blocks`.
    local inst = T.load()
    local blocks, _, ctx = render(inst)

    assertFalse(blocks == ctx.mmBlocks, "the caller was handed the ctx's own working list")
    assertEqual(#blocks, #ctx.mmBlocks)
    for i = 1, #blocks do assertTrue(blocks[i] == ctx.mmBlocks[i], "the two lists diverge at " .. i) end

    inst.NS.CancelReorder(ctx)
    assertEqual(#blocks, #ITEMS, "the caller's list was emptied by a release it does not own")
end)
