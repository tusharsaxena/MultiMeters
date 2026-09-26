-- tests/test_columns.lua
--
-- settings/Columns.lua — the ONLY place a window's column list can be edited.
--
-- Every other meter lets you drag a column edge in the window itself. This one
-- deliberately cannot: resizing by drag means reading a cell's geometry back
-- (GetWidth, GetLeft, GetPoint), and a cell that has been handed a secret meter
-- value through StatusBar:SetValue has secret geometry from that moment on
-- (design §4, rule R3). So the whole editor lives on a settings page, and that
-- page is what this suite drives.
--
-- IT IS DRIVEN THROUGH THE RENDERED WIDGETS, not through the file's internals.
-- Every mutation in settings/Columns.lua is a file-local reachable only from a
-- widget callback, and that is the honest surface: a control whose onClick is
-- unreachable from a test is a control that ships untested, which is how a page's
-- button once shipped wired to nothing at all.
--
-- THE PAGE IS BLOCKS NOW, not a list of chosen columns with four controls each.
-- The properties worth the setup have moved with it:
--
--   * a toggle is also a MOVE, and the two ends are the interaction: ticking
--     sends a block to the end of the enabled group, unticking to the top of the
--     disabled one, so the player can always see where it went;
--   * a drag really reorders the STORED array, driven through the real handle
--     scripts rather than by calling the page's reorder function;
--   * the last shown column cannot be unticked, and the refusal is REPORTED —
--     a window with nothing but names in it reads as a broken addon;
--   * commit() checks the seam's ANSWER. A refusal followed by an unconditional
--     repaint is the worst outcome available: the page redraws from the unchanged
--     array, so the control looks like it did nothing rather than like it failed.
--
-- The mechanics of the blocks themselves — the clamp, the glyphs, the rule —
-- belong to tests/test_columnblocks.lua, which drives them with a made-up item
-- list. This suite is about what the PAGE does with the indices it gets back.

local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue, assertFalse = T.assertEqual, T.assertTrue, T.assertFalse

local PANEL = "MultiMetersWindowsPanel"

local function columnsPanel(inst)
    for _, ctx in ipairs(inst.NS.Helpers.__panels()) do
        if ctx.panel and ctx.panel:GetName() == PANEL then return ctx end
    end
    return nil
end

local function storedColumns(inst)
    return inst.NS.Database.GetWindows()[1].columns
end

local function statKeys(inst)
    local keys = {}
    for i, c in ipairs(storedColumns(inst)) do keys[i] = c.stat end
    return keys
end

local function shownCount(inst)
    local n = 0
    for _, c in ipairs(storedColumns(inst)) do
        if c.enabled then n = n + 1 end
    end
    return n
end

--- The blocks currently on the page.
---
--- They come off the mock's creation register rather than off a widget list,
--- because they are raw frames: settings/ColumnBlocks.lua builds them with
--- CreateFrame, so AceGUI's `__created` never sees them.
---
--- SCANNED BACKWARDS, taking the first block found per index. Every repaint
--- appends a fresh set and the old ones are still in the register, so forwards
--- would answer with the page as it looked before the edit — which is exactly the
--- stale-widget bug the old suite's `repaint` helper existed to avoid.
local function blocksNow(inst)
    local frames, blocks = inst.mocks.__frames, {}
    for i = #frames, 1, -1 do
        local f = frames[i]
        if f.mmIndex and blocks[f.mmIndex] == nil then blocks[f.mmIndex] = f end
    end
    return blocks
end

--- Show the page and hand back its context and its blocks.
local function openPage(inst)
    inst = inst or T.load()
    local ctx = columnsPanel(inst)
    assertTrue(ctx ~= nil, "the Windows page did not register a panel")

    ctx.panel:Hide()
    ctx.panel:Show()
    -- The editor is the Windows page's Columns entry (MultiMeters#55).
    assertTrue(inst.NS.Helpers.SelectSection("columns"), "the Windows page lists no Columns entry")
    assertEqual(ctx.activeSection, "columns")
    assertTrue(ctx._rendered, "the Windows page did not render; the renderer raised "
        .. "and was swallowed by pcall")

    return inst, ctx, blocksNow(inst)
end

-- ---------------------------------------------------------------------------
-- The page draws what is stored
-- ---------------------------------------------------------------------------

test("Columns: the page draws one block per statistic in the catalog", function()
    -- Every statistic gets a block, shown or not. There is no add button, so a
    -- statistic that was not already there would be unreachable.
    local inst, _, blocks = openPage()
    assertEqual(#blocks, #inst.NS.Constants.STATS)
    assertEqual(#blocks, #storedColumns(inst))
end)

test("Columns: the blocks are in the STORED order, ticked ones first", function()
    local inst, _, blocks = openPage()
    local cols = storedColumns(inst)
    for i, c in ipairs(cols) do
        assertTrue(blocks[i] ~= nil, "no block at index " .. i)
        local stat = inst.NS.Constants.STAT_BY_KEY[c.stat]
        assertEqual(blocks[i].mmLabel:GetText(), inst.NS.L[stat.label],
            "block " .. i .. " does not label the statistic stored there")
    end
end)

-- ---------------------------------------------------------------------------
-- Toggling
-- ---------------------------------------------------------------------------

test("Columns: unticking a column drops it to the TOP of the disabled group", function()
    -- The shortest travel available: the player watches it land just below the
    -- rule rather than hunting the list for where it went.
    local inst, _, blocks = openPage()
    local before = shownCount(inst)
    local key = storedColumns(inst)[1].stat

    blocks[1].mmGlyph:_run("OnClick")

    assertEqual(shownCount(inst), before - 1)
    local cols = storedColumns(inst)
    assertEqual(cols[before].stat, key, "the unticked block did not land below the rule")
    assertFalse(cols[before].enabled)
end)

test("Columns: ticking a statistic adds it as the RIGHTMOST column", function()
    -- Where a column you just added belongs.
    local inst, _, blocks = openPage()
    local before = shownCount(inst)
    local key = storedColumns(inst)[before + 1].stat

    blocks[before + 1].mmGlyph:_run("OnClick")

    assertEqual(shownCount(inst), before + 1)
    local cols = storedColumns(inst)
    assertEqual(cols[before + 1].stat, key, "a newly ticked column must go to the right")
    assertTrue(cols[before + 1].enabled)
end)

test("Columns: the last shown column cannot be unticked, and the refusal is said", function()
    -- A window with nothing but names in it reads as a broken addon rather than
    -- as a configuration.
    local inst = T.load()

    -- Down to one, always unticking the SECOND block so the first survives. Each
    -- toggle repaints, so the blocks are re-read rather than held across it.
    openPage(inst)
    while shownCount(inst) > 1 do
        blocksNow(inst)[2].mmGlyph:_run("OnClick")
    end

    local chatBefore = #inst.mocks.__chat
    blocksNow(inst)[1].mmGlyph:_run("OnClick")

    assertEqual(shownCount(inst), 1, "the last column was taken away")
    assertTrue(#inst.mocks.__chat > chatBefore,
        "a refusal with nothing printed looks like a control wired to nothing")
end)

-- ---------------------------------------------------------------------------
-- Dragging
-- ---------------------------------------------------------------------------

test("Columns: dragging a block reorders the stored array", function()
    local inst, _, blocks = openPage()
    local before = statKeys(inst)

    -- The drag's poll is the library's ghost from LibKa0s-Widgets-1.0 minor 10, not the block:
    -- see the drag() driver in tests/test_columnblocks.lua.
    local W = inst.mocks.LibStub("LibKa0s-Widgets-1.0", true)
    local block = blocks[1]
    inst.mocks.setMouseDown("LeftButton", true)
    inst.mocks.setCursor(0, 1000)
    block.mmHandle:_run("OnMouseDown")
    local ghost = W and W.__DragGhost
    assertTrue(ghost ~= nil, "the press built no drag ghost to carry the poll")
    inst.mocks.setCursor(0, 1000 - 2 * inst.NS.BLOCK_STRIDE)
    ghost:_run("OnUpdate", 0.1)
    inst.mocks.setMouseDown("LeftButton", false)
    ghost:_run("OnUpdate", 0.1)

    local after = statKeys(inst)
    assertEqual(after[3], before[1], "the dragged block did not land two rows down")
    assertEqual(after[1], before[2], "what it passed did not move up")
    assertEqual(#after, #before, "a reorder must not add or lose a statistic")
end)

test("Columns: a drag that goes nowhere writes nothing", function()
    local inst, ctx, blocks = openPage()
    local before = table.concat(statKeys(inst), ",")
    local rendered = ctx._rendered

    local W = inst.mocks.LibStub("LibKa0s-Widgets-1.0", true)
    local block = blocks[2]
    inst.mocks.setMouseDown("LeftButton", true)
    inst.mocks.setCursor(0, 1000)
    block.mmHandle:_run("OnMouseDown")
    local ghost = W and W.__DragGhost
    assertTrue(ghost ~= nil, "the press built no drag ghost to carry the poll")
    ghost:_run("OnUpdate", 0.1)
    inst.mocks.setMouseDown("LeftButton", false)
    ghost:_run("OnUpdate", 0.1)

    assertEqual(table.concat(statKeys(inst), ","), before)
    assertTrue(rendered)
end)

-- ---------------------------------------------------------------------------
-- The seam
-- ---------------------------------------------------------------------------

test("Columns: no change is applied under combat lockdown, and the reason is said", function()
    -- The library's combat cover takes the mouse off a page shown in combat, but
    -- a write that gets past it (a handle drag already in flight) would rebuild
    -- cells holding secret values -- options-ui-§2's gate for a frame-building
    -- setter -- which is why every mutation re-checks rather than trusting the
    -- cover. The harness fires the glyph directly, as that stray write would.
    local inst, _, blocks = openPage()
    local before = table.concat(statKeys(inst), ",")

    inst.mocks.setRestricted(true)
    local chatBefore = #inst.mocks.__chat
    blocks[1].mmGlyph:_run("OnClick")

    assertEqual(table.concat(statKeys(inst), ","), before,
        "the stored array must be untouched under lockdown")
    assertTrue(#inst.mocks.__chat > chatBefore, "the refusal must be reported")
end)

test("Columns: a refused write is REPORTED and the page is not repainted", function()
    -- Repainting after a refusal redraws the UNCHANGED array, so the control
    -- looks like it did nothing rather than like it failed.
    local inst, _, blocks = openPage()
    local repaints = 0
    local realRefresh = inst.NS.RefreshOptionsPanel
    local realSet     = inst.NS.SetByPath
    inst.NS.RefreshOptionsPanel = function() repaints = repaints + 1 end
    inst.NS.SetByPath = function() return false, "the seam said no" end

    local chatBefore = #inst.mocks.__chat
    blocks[1].mmGlyph:_run("OnClick")

    inst.NS.RefreshOptionsPanel = realRefresh
    inst.NS.SetByPath = realSet

    assertEqual(repaints, 0, "a refused change must not repaint")
    local said = table.concat(inst.mocks.__chat, "\n", chatBefore + 1, #inst.mocks.__chat)
    assertTrue(said:find("the seam said no", 1, true) ~= nil,
        "the seam's own reason must be printed, got: " .. said)
end)

test("Columns: an accepted write IS repainted", function()
    -- The other half of the case above: without this, "never repaints" would pass
    -- it just as happily.
    local inst, _, blocks = openPage()
    local repaints = 0
    local real = inst.NS.RefreshOptionsPanel
    inst.NS.RefreshOptionsPanel = function() repaints = repaints + 1 end

    blocks[1].mmGlyph:_run("OnClick")
    inst.NS.RefreshOptionsPanel = real

    assertTrue(repaints > 0, "the page's SHAPE changed and it must redraw")
end)

test("Columns: the stored array is never the page's own working copy", function()
    -- The page builds a fresh array per edit and hands the whole thing over. A
    -- table it still holds afterwards is a table it can edit past every check the
    -- seam performs.
    local inst, _, blocks = openPage()
    local handed
    local real = inst.NS.SetByPath
    inst.NS.SetByPath = function(path, value)
        if path == "window.columns" then handed = value end
        return real(path, value)
    end

    blocks[1].mmGlyph:_run("OnClick")
    inst.NS.SetByPath = real

    assertTrue(handed ~= nil, "the page did not write through the seam at all")
    assertFalse(handed == storedColumns(inst),
        "the seam stored the caller's own table")
end)

-- ---------------------------------------------------------------------------
-- The three tabs (MM-18: the pin the RenderTabbedSchema decline, issue #53, leaves standing)
-- ---------------------------------------------------------------------------
--
-- The page hand-builds its strip with H.TabStrip rather than handing it to
-- H.RenderTabbedSchema's host tabs, because the library's tab click clears the scroll ITSELF and
-- re-enters RenderTabbedSchema, not this page's render -- so NS.CancelReorder could no longer run
-- before the clear. These three cases pin what the page does today, so any later adoption has to
-- keep all three.

--- Every tab button of the strip, by its label, in strip order.
local function tabLabels(ctx)
    local out = {}
    for i, b in ipairs(ctx.__tabKids or {}) do out[i] = b.__ka0sTabTipLabel end
    return out
end

test("Columns: the page draws three tabs, Columns then Header text then Header background",
function()
    -- red under: letting a group partition order the strip, which would put the block editor last.
    local inst, ctx = openPage()
    local L = inst.NS.L
    assertEqual(table.concat(tabLabels(ctx), "|"),
        table.concat({ L["Columns"], L["Header text"], L["Header background"] }, "|"))
    assertEqual(ctx.activeTab, L["Columns"], "the page opens on the block editor")
end)

test("Columns: the Header text tab renders exactly its group's rows, with no headings",
function()
    -- red under: rendering the whole page's rows on a schema tab, or dropping noHeadings so the
    -- tab's own name is repeated as a heading under it.
    local inst, ctx = openPage()
    local L, NS = inst.NS.L, inst.NS
    local calls = {}
    local real = NS.Helpers.RenderRows
    NS.Helpers.RenderRows = function(c, rows, afterGroup, pairWith, opts)
        calls[#calls + 1] = { rows = rows, opts = opts }
        return real(c, rows, afterGroup, pairWith, opts)
    end
    local ok, err = pcall(function() ctx.__tabKids[2]:__fire("OnClick") end)
    NS.Helpers.RenderRows = real
    assertTrue(ok, tostring(err))

    assertEqual(ctx.activeTab, L["Header text"])
    assertEqual(#calls, 1, "the Header text tab must render one row list")
    local want = {}
    for _, row in ipairs(NS.SchemaForPage("columns")) do
        if row.group == L["Header text"] then want[#want + 1] = row.path end
    end
    local got = {}
    for i, row in ipairs(calls[1].rows) do got[i] = row.path end
    assertTrue(#want > 0, "the page declares no Header text rows")
    assertEqual(table.concat(got, ","), table.concat(want, ","))
    assertTrue(calls[1].opts and calls[1].opts.noHeadings == true, "the tab drew headings")
end)

test("Columns: leaving the Columns tab mid-drag cancels the reorder BEFORE the scroll clear",
function()
    -- ClearScroll hands the page's AceGUI containers back to a process-wide pool, and a drag
    -- handle stays parented to one until the controller is canceled. Canceling after the clear
    -- hands some unrelated widget a frame with a live handle on it.
    -- red under: an H.ClearScroll in the tab's onSelect, or any tab switch that clears without
    -- re-entering render() -- which is what RenderTabbedSchema's own click does.
    local inst, ctx, blocks = openPage()
    local NS = inst.NS
    inst.mocks.setMouseDown("LeftButton", true)
    inst.mocks.setCursor(0, 1000)
    blocks[1].mmHandle:_run("OnMouseDown")
    assertTrue(ctx.mmReorder ~= nil, "the press left no live reorder to cancel")

    local order = {}
    local realCancel, realClear = NS.CancelReorder, NS.Helpers.ClearScroll
    NS.CancelReorder = function(c)
        order[#order + 1] = c.mmReorder and "cancel-live" or "cancel"
        return realCancel(c)
    end
    NS.Helpers.ClearScroll = function(c)
        order[#order + 1] = "clear"
        return realClear(c)
    end
    local ok, err = pcall(function() ctx.__tabKids[2]:__fire("OnClick") end)
    NS.CancelReorder, NS.Helpers.ClearScroll = realCancel, realClear
    inst.mocks.setMouseDown("LeftButton", false)
    assertTrue(ok, tostring(err))

    assertEqual(ctx.activeTab, NS.L["Header text"], "the tab click did not switch tabs")
    assertEqual(order[1], "cancel-live", "the first thing the switch did was not the cancel: "
        .. table.concat(order, ","))
    assertEqual(order[2], "clear", "no scroll clear followed the cancel: " .. table.concat(order, ","))
    assertTrue(ctx.mmReorder == nil, "the reorder controller survived the switch")
end)
