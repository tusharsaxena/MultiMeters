-- tests/test_tooltip_lines.lua — modules/Tooltip_Lines.lua: one pooled line, as
-- a widget.
--
-- WHAT IT PROVES. That the carrier frame and its bar draw what the resolved
-- style asks for: the bar fills in the breakdown, the percent slot, the two
-- fixed-width number slots, the bar texture and its border, and the minimum
-- width — which is COMPUTED from character spans rather than measured off a
-- string, because measuring a secret raises.
--
-- WHY IT IS A SEPARATE FILE. modules/Tooltip.lua went past layout-§1's 1500-line
-- cap (issue #28) and the drawing machinery moved to modules/Tooltip_Lines.lua.
-- A suite's seam is not its own to choose — it follows the module's, so that a
-- reader who opens the module knows which file covers it.
--
-- The spells in every fixture ASCEND, for the reason tests/test_tooltip.lua's
-- header gives: it is what makes "did it sort" answerable by looking at the
-- tooltip rather than by trusting a flag.
--
-- THE PREAMBLE IS DUPLICATED, DELIBERATELY. `bench()`, `ascendingSpells()` and the
-- spell-line readers below are ~110 lines that all four files of this peel need.
-- Publishing them to a fifth file would put a reader of one failure into two
-- files, and the kit has no fixture-sharing seam that is not a suite. Copying is
-- the cheaper of the two wrong answers here; if one of them changes, all four
-- change together.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse
local assertNil   = T.assertNil

local CURRENT = 1
local ALPHA   = "Player-1-0000000A"

--- A per-source breakdown whose spells ASCEND, so a legal sort is visible.
local function ascendingSpells()
    return {
        combatSpells = {
            { spellID = 101, totalAmount = 100 },
            { spellID = 102, totalAmount = 200 },
            { spellID = 103, totalAmount = 300 },
        },
        maxAmount = 300, totalAmount = 600,
    }
end

--- A loaded instance with one source detail installed, plus a window config and
--- a bare anchor frame to hang the tooltip on.
local function bench(opts)
    opts = opts or {}
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks

    mocks.setSourceDetail(CURRENT, "*", "*", opts.detail or ascendingSpells())
    if opts.restricted then mocks.setRestricted(true) end

    local cfg = NS.Database.GetWindows()[1]
    -- The shipped default is Overall; this fixture seeds the CURRENT session.
    cfg.data.sessionType = CURRENT
    if opts.configure then opts.configure(cfg) end

    local anchor = mocks.__stubFrame("Frame")
    mocks.GameTooltip:ClearLines()
    return inst, cfg, anchor
end

-- ---------------------------------------------------------------------------
-- Reading the spell lines back
-- ---------------------------------------------------------------------------
--
-- A spell line is NOT one tooltip line any more. The tooltip holds the icon and
-- the spell name; the amount and the share live on our own carrier Frame, in two
-- fixed-width right-aligned slots, because AddDoubleLine right-aligns one string
-- and would let the share column zig-zag behind amounts of different widths.
--
-- So a suite that reads `line.right` is reading a slot the addon stopped using.
-- These two helpers read what the player actually sees.

--- Every shown carrier Frame, keyed by the tooltip line index it sits on.
---
--- The index is recovered from the carrier's own LEFT anchor, which is pinned to
--- `GameTooltipTextLeft<N>` — so this asserts the anchoring incidentally, and a
--- carrier that drifted off its line would simply not be found.
local function tooltipLines(inst)
    local out = {}
    for _, f in ipairs(inst.mocks.__frames) do
        if f.__objectType == "Frame" and f.__parent == inst.mocks.GameTooltip
            and f:IsShown() then
            for _, p in ipairs(f.__points) do
                local rel = p.relativeTo
                local index = rel and rel.__name
                    and rel.__name:match("^GameTooltipTextLeft(%d+)$")
                if index then out[tonumber(index)] = f end
            end
        end
    end
    return out
end

--- The carriers in tooltip-line order, so `[1]` is the first spell line.
local function spellLines(inst)
    local byIndex, keys = tooltipLines(inst), {}
    for index in pairs(byIndex) do keys[#keys + 1] = index end
    table.sort(keys)
    local out = {}
    for _, index in ipairs(keys) do out[#out + 1] = byIndex[index] end
    return out
end

local function makeRow(opts)
    opts = opts or {}
    return {
        guid          = opts.guid or ALPHA,
        windowId      = opts.windowId,
        name          = opts.name or "Alpha",
        classFilename = "MAGE",
        deathRecapID  = opts.deathRecapID,
        values        = {},
    }
end


-- ---------------------------------------------------------------------------
-- Bars in the breakdown
-- ---------------------------------------------------------------------------

--- Every shown bar under the tooltip.
---
--- One level deeper than it used to be: the bar hangs off a carrier Frame rather
--- than off GameTooltip directly, because the carrier survives a hover the bar
--- cannot — mid-pull the amount and the share still have to be drawn.
local function tooltipBars(inst)
    local shown = {}
    for _, f in ipairs(inst.mocks.__frames) do
        local parent = f.__parent
        if f.__objectType == "StatusBar" and parent
            and parent.__parent == inst.mocks.GameTooltip and f:IsShown() then
            shown[#shown + 1] = f
        end
    end
    return shown
end

test("A spell line carries a real class-colored BAR, not a run of characters", function()
    -- Two earlier attempts drew text: block glyphs (not in the game font, drew
    -- boxes) and then `=` (legible, and obviously not a bar). A GameTooltip line
    -- is text and `|T…|t` carries no tint, so the only way to get a real bar is a
    -- StatusBar parented to the tooltip and anchored to the line.
    -- red under: concatenating characters into the right-hand string.
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)

    local bars = tooltipBars(inst)
    assertTrue(#bars > 0, "no bar was drawn")

    local c = inst.mocks.RAID_CLASS_COLORS.MAGE
    assertEqual(bars[1].__barColor[1], c.r, "the bar must wear the row's class color")

    -- And nothing text-shaped is pretending to be one.
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if type(line.right) == "string" then
            assertFalse(line.right:find("==", 1, true) ~= nil,
                "an ASCII bar is still in the line")
        end
    end
end)

test("Bars are released between hovers, never stacked", function()
    -- They are pooled and re-anchored rather than created per line, so a stale
    -- bar would otherwise sit behind a line it no longer describes.
    -- red under: dropping the releaseBars call at the top of CellTooltip.
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)
    local first = #tooltipBars(inst)

    inst.mocks.GameTooltip:ClearLines()
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)
    assertEqual(#tooltipBars(inst), first, "the second hover doubled the bars")
end)

test("The bar is DRAWN mid-pull, because the widget does the division", function()
    -- THE ASSERTION THAT USED TO SAY THE OPPOSITE, and it cost the tooltip its
    -- bars for the whole of every pull. It read: "a bar's length is amount / max,
    -- which raises on two secrets", and gated the bar on CanCompare2 — so in
    -- combat, where every operand is secret, every bar was hidden. The main
    -- window kept its own bars the entire time, which is what gives the lie away.
    --
    -- The rule forbids TAINTED CODE doing the division. It does not forbid the
    -- division: a StatusBar computes its own fill natively, in code that may see
    -- secrets, and core/Secrets.lua lists SetValue and SetMinMaxValues among the
    -- things tainted code MAY do with a handle. modules/Row.lua has always taken
    -- them raw for exactly this reason.
    -- red under: restoring the CanCompare2 gate, or any `max <= 0` beside it.
    local inst, cfg, anchor = bench{ restricted = true }
    inst.mocks.setSecretValues(true)

    local ok, err = pcall(function()
        inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)
    end)
    assertTrue(ok, "the tooltip compared or divided a secret: " .. tostring(err))

    assertEqual(#tooltipBars(inst), 3,
        "the bars were hidden mid-pull, which is the whole bug this pins")
end)

test("A bar spans the FULL line, so its length is comparable down the column", function()
    -- The first shipped version anchored LEFT to the name's RIGHT and RIGHT to the
    -- number's LEFT, which put the bar in the empty gap between the two texts. A
    -- bar in a gap has a length that means nothing: the gap is as wide as the
    -- name is short, so a long spell name shortened its own bar. Every bar has to
    -- start and end where every other bar does — the FILL is what differs.
    -- red under: restoring the LEFT-to-RIGHT / RIGHT-to-LEFT anchoring.
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)

    local carrier = spellLines(inst)[1]
    assertTrue(carrier ~= nil, "no spell line was drawn")

    local seen = {}
    for _, p in ipairs(carrier.__points) do seen[p.point] = p end

    assertTrue(seen.LEFT ~= nil and seen.RIGHT ~= nil, "a line needs both edges pinned")
    assertEqual(seen.LEFT.relativePoint, "LEFT",
        "the track must be measured from the left text's LEFT edge, not from its right")
    assertEqual(seen.RIGHT.relativeTo, inst.mocks.GameTooltip,
        "the track must run out to the tooltip's own right margin")
end)

test("A bar clears the icon rather than running underneath it", function()
    -- The icon is a `|T…|t` escape INSIDE the left line, so the FontString's left
    -- edge is the ICON's left edge. Pinning the track there tints the icon and
    -- makes the row start look ragged; it has to begin where the spell NAME
    -- begins, so the icon reads as its own column the way it does in the grid.
    -- red under: a zero or negative LEFT offset.
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)

    local carrier = spellLines(inst)[1]
    assertTrue(carrier ~= nil, "no spell line was drawn")

    local left
    for _, p in ipairs(carrier.__points) do if p.point == "LEFT" then left = p end end
    assertTrue(left ~= nil, "the track's left edge is unpinned")
    -- 14 is TOOLTIP_ICON_SIZE. Clearing exactly the icon is the point: any less
    -- tints it, any more pushes the track past the spell name and leaves the name
    -- hanging outside its own bar.
    assertEqual(left.x, 14, "the track does not begin at the icon's right edge")
end)

test("The player's name is class-coloured on every tooltip that names one", function()
    -- Every other name this addon draws is class-coloured -- the Player column
    -- has been since the first build -- and the tooltip header was the one place
    -- a name came out white, so a hover read as belonging to nothing.
    -- red under: passing 1, 1, 1 to AddDoubleLine's first colour triple.
    local inst, cfg, anchor = bench()
    local want = inst.mocks.RAID_CLASS_COLORS.MAGE
    assertTrue(want ~= nil, "the mock has no MAGE colour to compare against")

    -- The cell tooltip's header is a DOUBLE line -- name on the left, statistic
    -- on the right -- so its colours are the pair recorded for each side.
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
    local first = inst.mocks.GameTooltip.__lines[1]
    assertEqual(first.leftColor[1], want.r, "the cell tooltip's name is not class-coloured")
    assertEqual(first.leftColor[3], want.b)
    assertEqual(first.rightColor[1], 1, "the statistic beside it lost its gold")

    -- The name tooltip's is a single line.
    inst.NS.Tooltip:NameTooltip(makeRow(), anchor, cfg)
    first = inst.mocks.GameTooltip.__lines[1]
    assertEqual(first.r, want.r, "the name tooltip's name is not class-coloured")
end)

test("A row with no class keeps a white name rather than an invented colour", function()
    local inst, cfg, anchor = bench()
    local r = makeRow()
    r.classFilename = nil
    inst.NS.Tooltip:CellTooltip(r, "DamageDone", anchor, cfg)
    assertEqual(inst.mocks.GameTooltip.__lines[1].leftColor[1], 1)
end)

test("The scale reaches the tooltip BEFORE it is placed, and is put back after", function()
    -- Set after SetOwner, the placement is computed against the old size and a
    -- scaled-up tooltip runs off the edge of the screen it was just fitted to.
    -- And GameTooltip is Blizzard's: a scale left behind rescales the next quest
    -- text anybody hovers, with nothing on screen to connect it to this addon.
    -- red under: dropping the restore, or scaling after SetOwner.
    local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.scale = 1.4 end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
    assertEqual(inst.mocks.GameTooltip.__scale, 1.4)

    inst.NS.Tooltip:Hide()
    assertEqual(inst.mocks.GameTooltip.__scale, 1, "the shared tooltip was left scaled")
end)

test("A nonsense scale is bounded rather than handed to the client", function()
    for _, bad in ipairs({ 0, -3, 99, "big" }) do
        local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.scale = bad end }
        inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
        local got = inst.mocks.GameTooltip.__scale
        assertTrue(got >= 0.5 and got <= 2,
            "scale " .. tostring(bad) .. " reached the client as " .. tostring(got))
    end
end)

test("The bar's fill and its backdrop each take their own colour and opacity", function()
    -- The fill used to be the hovered player's class and nothing else, with no
    -- setting reaching it; the backdrop was a hard-coded black at 0.35 set once
    -- at creation, which no setting reached and which a POOLED line carried from
    -- one hover to the next.
    -- red under: hard-coding either.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.barColorMode   = "custom"
        c.tooltip.barColor       = { r = 1, g = 0, b = 0, a = 1 }
        c.tooltip.barAlpha       = 0.5
        c.tooltip.barBgColorMode = "custom"
        c.tooltip.barBgColor     = { r = 0, g = 0, b = 1, a = 1 }
        c.tooltip.barBgAlpha     = 0.25
    end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local b = tooltipBars(inst)[1]
    assertTrue(b ~= nil, "no bar was drawn")
    assertEqual(b.__barColor[1], 1, "the fill ignored its colour")
    assertEqual(b.__barColor[4], 0.5, "the fill ignored its opacity")
    assertEqual(b.bg.__colorTexture[3], 1, "the backdrop ignored its colour")
    assertEqual(b.bg.__colorTexture[4], 0.25, "the backdrop ignored its opacity")
end)

test("Per-statistic mode is the HOVERED column's colour, not the sort column's", function()
    -- THE BUG: it resolved to the window's sort column, so every breakdown of
    -- every column came out in the sort column's colour -- a Healing tooltip in
    -- Damage red. This tooltip IS the breakdown of one statistic, and that
    -- statistic is the one whose cell the pointer is on.
    -- red under: reading window.data.sortColumn in lineStyle.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.barColorMode = "stat"
        c.data.sortColumn      = "DamageDone"
    end }
    local Const = inst.NS.Constants
    local want = Const.STAT_COLORS.HealingDone
    local sorted = Const.STAT_COLORS.DamageDone
    assertTrue(want ~= nil and sorted ~= nil, "the palette has no pair to tell apart")
    assertTrue(want[1] ~= sorted[1], "the two colours are identical; the case proves nothing")

    inst.NS.Tooltip:CellTooltip(makeRow(), "HealingDone", anchor, cfg)
    local b = tooltipBars(inst)[1]
    assertTrue(b ~= nil, "no bar was drawn")
    assertEqual(b.__barColor[1], want[1], "a Healing breakdown took the sort column's colour")
end)

test("The text mode follows the hovered column too", function()
    -- One tooltip, one statistic: the bar and the writing on it must not disagree
    -- about which.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.colorMode = "stat"
        c.data.sortColumn   = "DamageDone"
    end }
    local want = inst.NS.Constants.STAT_COLORS.HealingDone
    inst.NS.Tooltip:CellTooltip(makeRow(), "HealingDone", anchor, cfg)

    local b = tooltipBars(inst)[1]
    local carrier = b.__parent
    assertEqual(carrier.amount.__textColor[1], want[1],
        "the amount took a different statistic's colour from its own bar")
end)

test("Class mode paints the bar with the hovered player's class", function()
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.barColorMode = "class"
    end }
    local want = inst.mocks.RAID_CLASS_COLORS.MAGE
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local b = tooltipBars(inst)[1]
    assertEqual(b.__barColor[1], want.r)
    assertEqual(b.__barColor[3], want.b)
end)

test("The bar border is drawn on the BAR, where it can be seen", function()
    -- IT DID NOTHING AT ANY THICKNESS. The carrier is the parent and the bar is a
    -- child covering it edge to edge, so a backdrop on the carrier was drawn
    -- underneath the bar.
    -- red under: putting the backdrop back on the carrier.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.barBorderStyle = "Ka0s Edge"
        c.tooltip.barBorderSize  = 4
    end }
    inst.mocks.__media.border["Ka0s Edge"] = "Interface\\Test\\Edge"
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local b = tooltipBars(inst)[1]
    assertTrue(b ~= nil, "no bar was drawn")
    assertTrue(b.__backdrop ~= nil, "the border did not reach the bar")
    assertEqual(b.__backdrop.edgeSize, 4, "the thickness slider does not reach the art")
    assertNil(b.__parent.__backdrop, "the carrier kept a backdrop nobody can see")
end)

test("The bar border answers a colour mode, and its class is the HOVERED player's", function()
    -- options-ui-§17. A tooltip is opened over ONE row and is about that row, so
    -- `class` here is the player being hovered -- the same class the fill it
    -- surrounds takes, and not the local player's, which is what the window's own
    -- edge means. The swatch's ALPHA survives the mode.
    -- red under: resolving it through the local player's class, or reading the
    -- swatch and ignoring the mode entirely.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.barBorderStyle     = "Ka0s Edge"
        c.tooltip.barBorderSize      = 4
        c.tooltip.barBorderColor     = { r = 1, g = 0, b = 0, a = 0.6 }
        c.tooltip.barBorderColorMode = "class"
    end }
    inst.mocks.__media.border["Ka0s Edge"] = "Interface\\Test\\Edge"
    local want = inst.mocks.RAID_CLASS_COLORS.MAGE
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local b = tooltipBars(inst)[1]
    local edge = b.__backdropBorderColor
    assertTrue(edge ~= nil, "the border was never coloured")
    assertEqual(edge[1], want.r, "the outline did not take the hovered player's class")
    assertEqual(edge[3], want.b)
    assertEqual(edge[4], 0.6, "the swatch's alpha did not survive the mode")
end)

test("The bar border's shipped mode is Custom, so it still reads the swatch", function()
    -- red under: a default of "class", which would recolour every existing
    -- tooltip's spell-bar outline on upgrade.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.barBorderStyle = "Ka0s Edge"
        c.tooltip.barBorderSize  = 4
        c.tooltip.barBorderColor = { r = 1, g = 0, b = 0, a = 1 }
    end }
    inst.mocks.__media.border["Ka0s Edge"] = "Interface\\Test\\Edge"
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    assertEqual(tooltipBars(inst)[1].__backdropBorderColor[1], 1)
end)

test("A bar sits UNDER the tooltip's text, not over it", function()
    -- GameTooltip draws its line FontStrings in ARTWORK, and a frame at the
    -- tooltip's own level interleaves its draw layers with the tooltip's. So the
    -- fill goes at the BOTTOM of the stack: any higher and a full-width bar paints
    -- over the very spell name it is behind.
    --
    -- BACKGROUND rather than BORDER, and the sublevel is the point. BORDER is
    -- where a BACKDROP draws its edge, so a fill sitting there was level with the
    -- border that is supposed to outline it -- which is why "Bar border" appeared
    -- to do nothing at any thickness. Sublevel 1 keeps it above the bar's own
    -- backdrop texture at sublevel 0.
    -- red under: leaving the fill on the StatusBar's default layer, or putting it
    -- back on BORDER where the outline lives.
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)

    local b = tooltipBars(inst)[1]
    assertTrue(b ~= nil, "no bar was drawn")
    assertEqual(b.__level, inst.mocks.GameTooltip:GetFrameLevel(),
        "a bar above the tooltip's level cannot interleave with its text")
    assertEqual(b.__parent.__level, inst.mocks.GameTooltip:GetFrameLevel(),
        "the carrier must share the level too, or it lifts the bar with it")

    local fill = b:GetStatusBarTexture()
    assertTrue(fill ~= nil, "a StatusBar with no texture draws nothing at all")
    assertEqual(fill.__drawLayer and fill.__drawLayer[1], "BACKGROUND",
        "the fill must draw below the tooltip's ARTWORK text")
    assertEqual(fill.__drawLayer and fill.__drawLayer[2], 1,
        "the fill must still sit above the bar's own backdrop")
end)

test("Bars come down when GameTooltip closes, whoever closed it", function()
    -- GameTooltip is SHARED and RECYCLED, and hiding it does not un-Show the
    -- frames parented to it. A bar left Shown reappears the instant a unit or an
    -- item opens GameTooltip, re-anchored onto THAT tooltip's lines — which is how
    -- this addon put class-colored bars through the middle of a player's unit
    -- tooltip. The only signal that catches every route out is the tooltip's own
    -- OnHide.
    -- red under: dropping the HookScript("OnHide", releaseBars) install.
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)
    assertTrue(#tooltipBars(inst) > 0, "no bar was drawn")

    -- Somebody ELSE hides the tooltip. Nothing routes this through our module.
    inst.mocks.GameTooltip:Show()
    inst.mocks.GameTooltip:Hide()

    assertEqual(#tooltipBars(inst), 0, "a bar outlived the tooltip that owned it")
end)


-- ---------------------------------------------------------------------------
-- The percent slot
-- ---------------------------------------------------------------------------

--- Every share slot the tooltip filled in, as one blob.
local function shareText(inst)
    local out = {}
    for _, carrier in ipairs(spellLines(inst)) do
        out[#out + 1] = tostring(carrier.share.__text or "")
    end
    return table.concat(out, "\n")
end

test("A spell line carries its SHARE of the player's total beside the amount", function()
    -- The amount alone answers "how much"; the share answers "how much of what I
    -- did", which is the question a breakdown exists for. The denominator is the
    -- source's own total for this column, not the column max.
    -- red under: dropping the sourceTotal argument, or passing maxAmount instead.
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)

    -- The fixture totals 600, and its largest spell is 300 — exactly half.
    assertTrue(shareText(inst):find("50.0%%") ~= nil,
        "the top spell's share of a 600 total is not on the line")
    -- 100/600 rounds to 16.7, which no other reading of the numbers produces:
    -- against maxAmount (300) the same spell would read 33.3%.
    assertTrue(shareText(inst):find("16.7%%") ~= nil,
        "the share is being taken against the wrong denominator")
end)

test("The percent slot GOES QUIET mid-pull rather than approximating", function()
    -- A share is a DIVISION, so it is the one slot on a spell line that cannot
    -- survive the Combat restriction. modules/Format.lua answers an empty string
    -- when the operands may not be divided, and an empty answer must append
    -- NOTHING — never a zero, never a guess. The amount is untouched either way,
    -- so a mid-pull tooltip loses the share and keeps the figure.
    -- red under: reading Format.Percent's "" as a number, or dividing unguarded.
    local inst, cfg, anchor = bench{ restricted = true }
    inst.mocks.setSecretValues(true)

    local ok = pcall(function()
        inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)
    end)
    assertTrue(ok, "the tooltip divided a secret to get a percentage")

    assertFalse(shareText(inst):find("%%") ~= nil,
        "a percentage was rendered from values we may not divide")
    -- And the tooltip still drew its spell lines: the share went, the data did not.
    assertTrue(#inst.mocks.GameTooltip.__lines > 3, "the breakdown vanished with the shares")
end)


-- ---------------------------------------------------------------------------
-- The two number slots
-- ---------------------------------------------------------------------------

test("The amount and the share sit in FIXED right-aligned slots", function()
    -- AddDoubleLine right-aligns ONE string, so "5.7M 36.5%" and "398.9K 2.1%"
    -- line up at their right edge and nowhere else — the share column zig-zags
    -- behind amounts of different widths. Two right-justified FontStrings at fixed
    -- widths are the only way to get two columns out of one line; the game font is
    -- proportional, so padding with spaces cannot substitute.
    -- red under: putting either number back in the tooltip's own right column.
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)

    local carriers = spellLines(inst)
    assertEqual(#carriers, 3, "the breakdown did not draw its three lines")

    for _, carrier in ipairs(carriers) do
        assertEqual(carrier.amount.__justifyH, "RIGHT", "the amount slot is not right-aligned")
        assertEqual(carrier.share.__justifyH, "RIGHT", "the share slot is not right-aligned")
        assertTrue(carrier.amount.__w > 0, "the amount slot has no fixed width")
        assertTrue(carrier.share.__w > 0, "the share slot has no fixed width")
    end

    -- Same widths on every line, which is what makes them columns rather than
    -- two numbers that happen to be near each other.
    assertEqual(carriers[1].amount.__w, carriers[3].amount.__w,
        "the amount slot changes width between lines")
    assertEqual(carriers[1].share.__w, carriers[3].share.__w,
        "the share slot changes width between lines")

    -- And nothing is left in a SPELL line's own right column to fight them. The
    -- header line keeps its right side — that is the column's name, not a number.
    for index in pairs(tooltipLines(inst)) do
        local line = inst.mocks.GameTooltip.__lines[index]
        assertTrue(line ~= nil, "a carrier is anchored to a line that does not exist")
        assertTrue(line.right == nil or line.right == "",
            "a number is still being drawn in the tooltip's right column")
    end
end)

test("Both number slots are white by default, not two kinds of number", function()
    -- The amount used to be gold and the share white. They are one row's two
    -- figures, and colouring them differently made the line read as two.
    -- red under: reinstating either hardcoded colour.
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)

    local carrier = spellLines(inst)[1]
    for _, slot in ipairs({ "share", "amount" }) do
        local c = carrier[slot].__textColor
        assertEqual(c[1], 1, slot .. " is not white")
        assertEqual(c[2], 1, slot .. " is not white")
        assertEqual(c[3], 1, slot .. " is not white")
    end
end)

test("The tooltip text colour is configurable, and reaches every slot", function()
    -- Including the target label, which lives on the carrier rather than in the
    -- tooltip's own line and would otherwise keep the default silently.
    -- red under: colouring only the amount, or reading the colour once at
    -- widget-creation time rather than on every draw.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.textColor = { r = 1, g = 0, b = 0, a = 1 }
    end }
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)

    local carrier = spellLines(inst)[1]
    for _, slot in ipairs({ "amount", "share", "label" }) do
        local c = carrier[slot].__textColor
        assertEqual(c[1], 1, slot .. " did not take the configured colour")
        assertEqual(c[2], 0, slot .. " did not take the configured colour")
    end
end)

test("The AMOUNT rides on the carrier, not on the bar", function()
    -- This is the inversion the carrier Frame exists to prevent: the amount is
    -- the INFORMATION, and hanging the number slots off the bar would tie them
    -- to whether the bar draws. That is a live risk even now that the bar
    -- survives a pull, because a bar still goes when a line has no max to scale
    -- against — and an empty tooltip is the exact opposite of the rule.
    -- red under: parenting the amount and share to the bar instead of the carrier.
    local inst, cfg, anchor = bench{ restricted = true }
    inst.mocks.setSecretValues(true)

    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)

    local carriers = spellLines(inst)
    assertEqual(#carriers, 3, "the spell lines went down with the restriction")
    for _, carrier in ipairs(carriers) do
        assertTrue(carrier.amount.__text ~= nil, "a spell line lost its amount")
        -- Asserted non-nil first, so the parent check below cannot pass by being
        -- vacuous on a mock that never recorded a parent at all.
        assertTrue(carrier.amount.__parent ~= nil, "the mock recorded no parent to check")
        assertTrue(carrier.amount.__parent ~= carrier.bar,
            "the amount is parented to the bar, so it dies whenever the bar does")
    end
end)

test("The tooltip is widened for the slots, and put back afterwards", function()
    -- GameTooltip sizes itself from its own text, and the slots are not its text —
    -- so without a minimum width it shrinks to the width of the spell names and
    -- the numbers sit on top of them. The minimum is a property of the SHARED
    -- tooltip, so leaving ours on it makes the next addon's item tooltip
    -- inexplicably wide: the same class of bug as a bar left Shown.
    -- red under: dropping either the applyMinimumWidth call or the reset.
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow{ classFilename = "MAGE" }, "DamageDone", anchor, cfg)

    assertTrue(inst.mocks.GameTooltip:GetMinimumWidth() > 0,
        "the tooltip was never widened for the number slots")

    inst.mocks.GameTooltip:Show()
    inst.mocks.GameTooltip:Hide()

    assertEqual(inst.mocks.GameTooltip:GetMinimumWidth(), 0,
        "our minimum width outlived our tooltip")
end)


-- ---------------------------------------------------------------------------
-- Bar texture and border
-- ---------------------------------------------------------------------------

test("The tooltip's own bar texture is used, not the grid's", function()
    -- These were one setting and are now two, deliberately: a 14px spell line and
    -- a 90px cell are different surfaces, and a texture that reads across one
    -- often does not across the other. Two DISTINCT files are registered so the
    -- assertion can tell which setting was read — with one file, or with none,
    -- both settings resolve to the same path and the test proves nothing.
    -- red under: reading window.bars.texture here again.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.bars.texture       = "GridTexture"
        c.tooltip.barTexture = "TipTexture"
    end }
    local media = inst.mocks.__libs["LibSharedMedia-3.0"]
    media:Register("statusbar", "GridTexture", [[Interface\Grid]])
    media:Register("statusbar", "TipTexture",  [[Interface\Tip]])

    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local lines = spellLines(inst)
    assertTrue(#lines > 0, "no spell lines were drawn")
    assertEqual(lines[1].bar.__barTexture, [[Interface\Tip]],
        "the tooltip bar took the GRID's texture instead of its own")
end)

test("Tooltip text takes the HOVERED player's class color when asked", function()
    -- A tooltip is about ONE player, which is what makes the question answerable
    -- here where the window header has to fall back to the local player's class
    -- instead. The bars have always worn this colour; the text can now too.
    -- red under: colouring the tooltip from NS.PlayerClassRGB, or ignoring the
    -- setting.
    local inst, cfg, anchorFrame = bench{ configure = function(c)
        c.tooltip.colorMode = "class"
        c.tooltip.textColor  = { r = 1, g = 1, b = 1, a = 1 }
    end }
    -- The mock ships every class the same colour, so one is given its own.
    inst.mocks.RAID_CLASS_COLORS.MAGE = { r = 0.41, g = 0.8, b = 0.94 }

    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchorFrame, cfg)

    local lines = spellLines(inst)
    assertTrue(#lines > 0, "no spell lines were drawn")
    assertEqual(lines[1].amount.__textColor[1], 0.41)
    assertEqual(lines[1].share.__textColor[3], 0.94,
        "both number slots, or one line carries two kinds of number")
end)

test("With the class colour off, the tooltip keeps its configured text colour", function()
    -- red under: the class colour applying whether or not it was asked for.
    local inst, cfg, anchorFrame = bench{ configure = function(c)
        c.tooltip.colorMode = "custom"
        c.tooltip.textColor  = { r = 0.2, g = 0.4, b = 0.6, a = 1 }
    end }
    inst.mocks.RAID_CLASS_COLORS.MAGE = { r = 0.41, g = 0.8, b = 0.94 }

    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchorFrame, cfg)
    local lines = spellLines(inst)
    assertEqual(lines[1].amount.__textColor[1], 0.2)
end)

test("Tooltip shadow reaches the line, and survives the post-Show re-font", function()
    -- `reapplyFonts` runs AFTER Show, because the show path re-fonts the
    -- tooltip's own lines. A shadow set only on the first pass would be put back
    -- without it -- the same trap the font size fell into.
    -- red under: recording the font in `fontedLines` without its shadow.
    local inst, cfg, anchorFrame = bench{ configure = function(c)
        c.tooltip.fontShadow = true
    end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchorFrame, cfg)

    local lines = spellLines(inst)
    assertTrue(#lines > 0, "no spell lines were drawn")
    assertEqual(lines[1].amount.__shadow[1], 1)
    assertEqual(lines[1].amount.__shadow[2], -1)
end)

test("The tooltip puts a SHARED line's shadow back when it lets go", function()
    -- GameTooltip is Blizzard's and every addon in the game draws on it. A
    -- SetFont left behind is a leak this file has always cleaned up; a shadow is
    -- the same leak, and a font OBJECT does not carry one -- so restoring the
    -- face is not enough to take the shadow off.
    -- red under: restoreFonts putting back SetFontObject alone.
    local inst, cfg, anchorFrame = bench{ configure = function(c)
        c.tooltip.fontShadow = true
    end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchorFrame, cfg)

    -- The shared line widgets are reachable exactly the way an addon reaches
    -- them in the client: by global name. Collected BEFORE the hide, and the
    -- collection is asserted non-empty -- a loop over nothing would pass forever.
    local shared = {}
    for index = 1, inst.mocks.GameTooltip:NumLines() do
        local fs = inst.mocks["GameTooltipTextLeft" .. index]
        if type(fs) == "table" and fs.__shadow and fs.__shadow[1] ~= 0 then
            shared[#shared + 1] = fs
        end
    end
    assertTrue(#shared > 0, "no shared line carried our shadow -- nothing to restore")

    inst.NS.Tooltip:Hide()

    for _, fs in ipairs(shared) do
        assertEqual(fs.__shadow[1], 0,
            "our shadow was left on a line the next addon will draw on")
        assertEqual(fs.__shadow[2], 0)
    end
end)

test("A bar border is applied when asked and cleared off the POOLED line when not", function()
    -- The carrier drawing line 4 of this hover drew line 4 of the last one, so a
    -- player who turns the border off between two hovers keeps it unless the
    -- clear is explicit.
    -- red under: skipping the SetBackdrop(nil) branch.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.barBorderStyle = "None"
        c.tooltip.barBorderSize  = 1
    end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local lines = spellLines(inst)
    assertTrue(#lines > 0, "no spell lines were drawn")
    assertEqual(lines[1].__backdrop, nil, "\"None\" still drew a border")
end)

test("Border size zero drops the border FILE with it", function()
    -- A zero edgeSize with a texture still present is the combination WoW draws
    -- as a hard 1px line, which is the setting doing the opposite of what it says.
    -- red under: keeping edgeFile when borderSize is 0.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.barBorderStyle = "Blizzard Tooltip"
        c.tooltip.barBorderSize  = 0
    end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local lines = spellLines(inst)
    assertEqual(lines[1].__backdrop, nil, "a zero-thickness border still carried a file")
end)


-- ---------------------------------------------------------------------------
-- The minimum width is COMPUTED, never measured
-- ---------------------------------------------------------------------------

test("The tooltip is widened without measuring anything inside GameTooltip", function()
    -- THE BUG THIS PINS. The width used to be read off GameTooltip's own line
    -- FontStrings. `GetStringWidth` inside a shared Blizzard frame answers a
    -- SECRET number to tainted code — even when every value on the line is
    -- plainly readable, because it is the FRAME that is out of bounds rather
    -- than the values — so `w > widest` raised and took every cell tooltip with
    -- it. The harness models that now (wow_mock marks GameTooltip tainted), so
    -- reintroducing any measurement raises here rather than only in game.
    -- red under: any GetStringWidth call on a widget inside GameTooltip.
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    assertTrue(inst.mocks.GameTooltip:GetMinimumWidth() > 0,
        "the tooltip was not widened for the number slots at all")
end)

test("The width follows the font size, because it is computed", function()
    -- Proves it is derived from config rather than from the widget: a bigger
    -- font on the same spells must ask for a wider tooltip.
    -- red under: a flat pixel constant, which would fit the small font and clip
    -- the large one.
    local function widthAt(size)
        local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.fontSize = size end }
        inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
        return inst.mocks.GameTooltip:GetMinimumWidth()
    end

    assertTrue(widthAt(20) > widthAt(8),
        "the minimum width ignored the configured font size")
end)

test("A name that cannot be read does not change the width, because none is read", function()
    -- The captions in a spell breakdown ARE secret in combat: C_DamageMeter
    -- hands out a secret spellID, so the name resolved from it is secret too. It
    -- renders — SetText takes a secret happily — but it cannot be measured, and
    -- an earlier version that tried left the tooltip un-widened and the numbers
    -- sitting on top of the names. Nothing here reads a caption at all now, so a
    -- secret one is simply not an event.
    -- red under: any reintroduction of caption measurement.
    local inst, cfg, anchor = bench()
    local ok, err = pcall(function()
        inst.NS.Tooltip:CellTooltip(
            { guid = "Player-1-0000000A", name = inst.mocks.secret("Alpha"), values = {} },
            "DamageDone", anchor, cfg)
    end)
    assertTrue(ok, "a secret name raised inside the width computation: " .. tostring(err))
end)

test("The name's room is a FIXED span, not the length of the names on screen", function()
    -- THE BUG THIS PINS, and it took a live client to see. Two versions sized
    -- the name span from the names themselves — first by reading GameTooltip's
    -- own FontStrings, then by measuring the captions on a ruler of our own —
    -- and both collapsed to zero width in combat, because every caption is
    -- secret there and a refused name widens nothing. The tooltip was never
    -- widened at all and the amounts drew straight through the names.
    --
    -- So the span is a RESERVATION: NAME_COLUMN_CHARS characters at the
    -- configured font, identical whatever the names are. Two different sets of
    -- spells must therefore ask for exactly the same width.
    -- red under: any width that varies with the captions.
    local SIZE = 10
    local function widthFor(spells)
        local inst, cfg, anchor = bench{
            detail = { combatSpells = spells, maxAmount = 655000, totalAmount = 655000 },
            configure = function(c) c.tooltip.fontSize = SIZE end,
        }
        inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
        return inst.mocks.GameTooltip:GetMinimumWidth()
    end

    local short = widthFor{ { spellID = 1, totalAmount = 655000 } }
    local long  = widthFor{ { spellID = 1234567, totalAmount = 655000 },
                            { spellID = 7654321, totalAmount = 100 } }
    assertEqual(short, long,
        "the width moved with the spell names, so it will collapse in combat")

    -- And it is the reservation, exactly: 25 'n' on the mock's ruler (0.5px per
    -- character per point), plus the slots. Asserting the figure catches a
    -- silent fall back to the character estimate, which uses 0.55.
    local nameSpan = 25 * SIZE * 0.5
    local share    = math.max(#"100.0%" * SIZE * 0.5 + 3, 44)
    assertEqual(short, nameSpan + 10 + 66 + 6 + share + 20,
        "the reserved span is not 25 characters at the configured font")
end)

test("The share slot fits a full 100.0%, at any configured font size", function()
    -- WHAT WENT WRONG. The slot was a flat 36px, sized for "xx.x%" on the
    -- reasoning that a share cannot exceed 100% and so cannot get wider. But
    -- Format.Percent renders "%.1f%%", so a capped row is "100.0%" — six glyphs,
    -- not five — and it drew as "100...." on screen. The font size is the
    -- player's to choose besides, so no pixel constant can be the answer: the
    -- slot is measured per font, with the old constant kept only as a floor.
    -- red under: a fixed share slot, at the default size or at a large one.
    for _, size in ipairs({ 8, 10, 16, 24 }) do
        local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.fontSize = size end }
        inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

        local carriers = spellLines(inst)
        assertTrue(#carriers > 0, "the breakdown drew no lines to measure")

        -- The mock's ruler is 0.5px per character per point.
        local needed = #"100.0%" * size * 0.5
        assertTrue(carriers[1].share.__w >= needed, string.format(
            "the share slot is %s at font size %d, which clips 100.0%% at %s",
            tostring(carriers[1].share.__w), size, tostring(needed)))
    end
end)

