-- tests/test_tooltip_place.lua — where a meter tooltip opens (AD-92-MM, LibKa0s#92).
--
-- WowAddonStandards standalone-windows, *Tooltip placement*: a meter row is a BODY element, so its
-- tooltip opens beside the window group, outside its outer edge, right when it fits and left
-- otherwise, its top level with the hovered row's, never on the cursor and never at a corner offset
-- from the cell. The owner's ruling of 2026-11-17 (option A) keeps a player choice of two: "Beside
-- the window" (the default, right first) and "Beside, prefer left". The X/Y offsets stay as a nudge.
--
-- Every case drives the kit's fake screen (tests/_kit/mock_screen.lua, revision 57) through the
-- vendored LibKa0s-Tooltip-1.0, so the side, the top alignment and the 2 px gap are read off the
-- point the placer wrote on GameTooltip, in screen units from UIParent's bottom-left.
--
-- THE GROUP IS THE WINDOW'S ANCHOR FRAME, the clean geometry frame that never holds a value
-- (modules/Window_Frame.lua); the ELEMENT is the hovered cell's row. Neither is the cell, which a
-- secret value may have been handed to (rule R3).

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local CURRENT = 1
local GAP = 2
local TIP_W, TIP_H = 250, 90

local function makeRow()
    return { guid = "Player-1-0000000A", name = "Alpha", classFilename = "MAGE", values = {} }
end

--- A loaded instance on a 1920x1080 fake screen, with one meter window at `left` (300 wide, 400
--- tall, bottom 300), one row on it (top 600) and a cell on the row. Answers what a case needs.
local function scene(left, configure)
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks
    mocks.setSourceDetail(CURRENT, "*", "*", {
        combatSpells = { { spellID = 101, totalAmount = 100 } }, maxAmount = 100, totalAmount = 100,
    })
    local cfg = NS.Database.GetWindows()[1]
    cfg.data.sessionType = CURRENT
    if configure then configure(cfg.tooltip) end

    local scr = dofile(T.root .. "/tests/_kit/mock_screen.lua")(mocks, { width = 1920, height = 1080 })
    local anchor = scr.frame{ left = left, bottom = 300, width = 300, height = 400 }
    local winFrame = scr.frame{ left = left, bottom = 300, width = 300, height = 400 }
    local rowFrame = scr.frame{ left = left, bottom = 580, width = 300, height = 20, parent = winFrame }
    local cell = scr.frame{ left = left + 120, bottom = 580, width = 60, height = 20, parent = rowFrame }
    local window = { frame = winFrame, anchor = anchor, config = cfg }
    local row = { frame = rowFrame, window = window }
    cell.mmCell = { row = row, window = window, key = "DamageDone" }
    rowFrame.mmRow = row

    local tip = mocks.GameTooltip
    rawset(tip, "GetWidth", function() return TIP_W end)
    rawset(tip, "GetHeight", function() return TIP_H end)
    tip:ClearLines()
    return { inst = inst, NS = NS, cfg = cfg, scr = scr, tip = tip, cell = cell, row = rowFrame }
end

local function finish(s)
    rawset(s.tip, "GetWidth", nil)
    rawset(s.tip, "GetHeight", nil)
    s.scr.restore()
end

--- The tooltip's one point, as point, relative frame, relative point, x, y.
local function pointOf(tip) return tip:GetPoint(1) end

local function assertBeside(s, side, what)
    local p, rel, relP, x, y = pointOf(s.tip)
    assertTrue(rel == s.inst.mocks.UIParent, what .. ": not one absolute point on UIParent")
    assertEqual(relP, "BOTTOMLEFT", what .. ": the point is not on UIParent's bottom-left")
    assertEqual(s.tip.__anchor, "ANCHOR_NONE", what .. ": owned at a client anchor, not placed")
    if side == "right" then
        assertEqual(p, "TOPLEFT", what .. ": a right-side tooltip hangs from its TOPLEFT")
        assertEqual(x, s.left + 300 + GAP, what .. ": not 2 px outside the window's right edge")
    else
        assertEqual(p, "TOPRIGHT", what .. ": a left-side tooltip hangs from its TOPRIGHT")
        assertEqual(x, s.left - GAP, what .. ": not 2 px outside the window's left edge")
    end
    assertEqual(y, 600, what .. ": its top is not level with the hovered row's top")
end

-- ── the body rule ────────────────────────────────────────────────────────────────────────────

test("Tooltip place: a cell tooltip opens beside the window, on the right when it fits", function()
    -- red under: the cell's old 3x3 box (BOTTOM on the cell's TOP), a SetOwner token, the cursor.
    local s = scene(100); s.left = 100
    s.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", s.cell, s.cfg)
    assertBeside(s, "right", "cell, room on the right")
    assertTrue(s.tip:GetOwner() == s.cell, "the tooltip is not owned by the hovered cell")
    finish(s)
end)

test("Tooltip place: with no room on the right, it opens on the window's left", function()
    -- red under: a placer that ignores the screen's right edge, or one measuring the cell, not the window.
    local s = scene(1500); s.left = 1500
    s.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", s.cell, s.cfg)
    assertBeside(s, "left", "cell, no room on the right")
    finish(s)
end)

test("Tooltip place: the name tooltip and a breakdown row's spell tooltip follow the same rule", function()
    -- red under: one builder still on the old placement.
    local s = scene(100); s.left = 100
    s.NS.Tooltip:NameTooltip(makeRow(), s.cell, s.cfg)
    assertBeside(s, "right", "name tooltip")
    finish(s)

    s = scene(1500); s.left = 1500
    local spellRow = { isDrillDown = true, spellID = 133, name = "Fireball" }
    s.NS.Tooltip:SpellTooltip(spellRow, s.row, s.cfg)
    assertBeside(s, "left", "breakdown row")
    assertTrue(s.tip:GetOwner() == s.row, "a breakdown row's tooltip is owned by the row")
    finish(s)
end)

test("Tooltip place: \"Beside, prefer left\" opens on the left when both sides fit", function()
    -- red under: the choice not reaching the placer's `prefer`.
    local s = scene(700, function(t) t.anchor = "BESIDE_LEFT" end); s.left = 700
    s.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", s.cell, s.cfg)
    assertBeside(s, "left", "prefer left, both sides fit")
    finish(s)

    -- And flips right when the left has no room.
    s = scene(100, function(t) t.anchor = "BESIDE_LEFT" end); s.left = 100
    s.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", s.cell, s.cfg)
    assertBeside(s, "right", "prefer left, no room on the left")
    finish(s)
end)

test("Tooltip place: a stored value this build does not offer opens beside, on the right", function()
    -- A profile that escaped the migration still carrying "TOP" or "CURSOR" lands where a new window does.
    -- red under: an unknown value reaching a client anchor token, or no placement at all.
    for _, stale in ipairs({ "TOP", "CURSOR", "BOTTOMRIGHT", 7 }) do
        local s = scene(100, function(t) t.anchor = stale end); s.left = 100
        s.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", s.cell, s.cfg)
        assertBeside(s, "right", "stored " .. tostring(stale))
        finish(s)
    end
end)

-- ── the nudge ────────────────────────────────────────────────────────────────────────────────

test("Tooltip place: the X/Y offsets nudge the placed tooltip by exactly that much", function()
    -- red under: dropping the offsets, applying them twice, or applying them to the side choice only.
    local s = scene(100, function(t) t.offsetX, t.offsetY = 25, -40 end); s.left = 100
    s.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", s.cell, s.cfg)
    local p, _, _, x, y = pointOf(s.tip)
    assertEqual(p, "TOPLEFT")
    assertEqual(x, 100 + 300 + GAP + 25, "the horizontal nudge never arrived")
    assertEqual(y, 600 - 40, "the vertical nudge never arrived")
    finish(s)
end)

test("Tooltip place: a junk offset off an old profile is clamped, never handed to the placer", function()
    -- A string here would raise inside the arithmetic; 99999 would throw the tooltip off screen.
    -- red under: passing config.offsetX straight through.
    local s = scene(100, function(t) t.offsetX, t.offsetY = "left a bit", 99999 end); s.left = 100
    s.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", s.cell, s.cfg)
    local _, _, _, x, y = pointOf(s.tip)
    assertEqual(x, 100 + 300 + GAP, "a non-number offset was not neutralized")
    -- 600 + 400 = 1000 still fits a 90 px tooltip on a 1080 screen, so the clamp is the offset's own.
    assertEqual(y, 1000, "an out-of-range offset was not clamped to 400")
    finish(s)
end)

-- ── never the cursor ─────────────────────────────────────────────────────────────────────────

test("Tooltip place: unreadable geometry attaches the tooltip above the row, never the cursor", function()
    -- The placer writes nothing when it cannot read the screen (a secret, an unplaced frame); the
    -- fallback is the chrome rule's attach above the element. red under: leaving the tooltip at
    -- ANCHOR_NONE with no point, or falling back to a cursor or a corner token.
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks
    local cfg = NS.Database.GetWindows()[1]
    local rowFrame = mocks.__stubFrame("Frame")
    local cell = mocks.__stubFrame("StatusBar")
    cell.mmCell = { row = { frame = rowFrame, window = { config = cfg } }, key = "DamageDone" }
    NS.Tooltip:CellTooltip(makeRow(), "DamageDone", cell, cfg)
    local tip = mocks.GameTooltip
    assertEqual(tip.__anchor, "ANCHOR_NONE")
    local p, rel, relP, x, y = pointOf(tip)
    assertEqual(p, "BOTTOM", "the fallback does not hang the tooltip above the element")
    assertTrue(rel == rowFrame, "the fallback is attached to something other than the hovered row")
    assertEqual(relP, "TOP")
    assertEqual(x, 0)
    assertEqual(y, GAP)
end)

test("Tooltip place: no meter tooltip is ever owned at a client anchor token", function()
    -- Static: modules/Tooltip*.lua names no ANCHOR_CURSOR, ANCHOR_CURSOR_RIGHT, corner or edge token,
    -- and no OnUpdate follows the pointer. red under: any of them coming back.
    for _, file in ipairs({ "modules/Tooltip.lua", "modules/Tooltip_Builders.lua", "modules/Tooltip_Lines.lua",
        "modules/Row.lua", "settings/ColumnBlocks.lua" }) do
        local fh = assert(io.open(T.root .. "/" .. file, "r"))
        local src = fh:read("*a")
        fh:close()
        for code in src:gmatch("[^\n]+") do
            local stripped = code:gsub("%-%-.*$", "")
            assertTrue(not stripped:find("\"ANCHOR_[A-Z_]+\"") or stripped:find("\"ANCHOR_NONE\""),
                file .. " places a tooltip at a client token: " .. code)
            assertTrue(not stripped:find("GetCursorPosition"), file .. " follows the cursor: " .. code)
        end
    end
end)
