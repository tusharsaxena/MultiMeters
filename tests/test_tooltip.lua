-- tests/test_tooltip.lua — modules/Tooltip.lua: the primitives a hover is built
-- out of, and the two real bugs a tooltip invites.
--
-- A tooltip LOOKS like the safest place in a meter — unprotected, built out of
-- strings, nothing secure about it. It is in fact the most dangerous, because it
-- is where the instinct is to say "just show the top five spells" and "put the
-- total at the bottom". A top-N is a COMPARISON and a total is ARITHMETIC, and
-- both raise while the Combat restriction is active.
--
-- Every fixture below therefore lists its spells in ASCENDING order. That is the
-- one detail that makes the sort cases falsifiable: a sort that ran shows the
-- list reversed, and a sort that was correctly refused shows the API's own
-- order, so "did it sort" is answered by looking at the tooltip rather than by
-- trusting a flag.
--
-- WHAT THIS FILE KEEPS. The primitives that modules/Tooltip.lua kept when it was
-- peeled for layout-§1 (issue #28): the static guarantees, placement and the
-- anchor offsets, line spacing, the font that has to be put back after the
-- client hands one back, and the `maxSpells = 0` cap. Three siblings took the
-- rest, each mirroring the module file it covers —
-- tests/test_tooltip_lines.lua, tests/test_tooltip_builders.lua and
-- tests/test_tooltip_deaths.lua.
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
-- Static guarantees
-- ---------------------------------------------------------------------------

test("modules/Tooltip.lua never applies `#` to a meter array", function()
    -- `#spells` on the LOCAL array this file built is fine — it is a plain
    -- table. `#` on combatSpells is the forbidden one, and SafeCount is the
    -- reason it never has to happen.
    local fh = assert(io.open(T.root .. "/modules/Tooltip.lua", "r"))
    local n, offenders, sawSafeCount = 0, {}, false
    for line in fh:lines() do
        n = n + 1
        if not line:match("^%s*%-%-") then
            local code = line:gsub("%s%-%-.*$", "")
            if code:find("SafeCount", 1, true) then sawSafeCount = true end
            if code:find("#%s*source%.combatSpells") or code:find("#combatSpells") then
                offenders[#offenders + 1] = "modules/Tooltip.lua:" .. n
            end
        end
    end
    fh:close()
    assertTrue(sawSafeCount, "the count must come from NS.Secrets.SafeCount")
    assertEqual(#offenders, 0, table.concat(offenders, ", "))
end)


-- ---------------------------------------------------------------------------
-- Anchoring and offsets
-- ---------------------------------------------------------------------------

test("Every anchor the schema offers resolves to a real GameTooltip token", function()
    -- The token is the FALLBACK now, not the placement: SetOwner is called with
    -- one so the tooltip always has a valid position, and placeTooltip lays the
    -- exact box over it. A missing token would leave a tooltip with nothing to
    -- fall back to if our own SetPoint raises.
    -- red under: dropping any entry from ANCHOR_TOKENS.
    local expected = {
        TOP         = "ANCHOR_TOP",
        BOTTOM      = "ANCHOR_BOTTOM",
        LEFT        = "ANCHOR_LEFT",
        RIGHT       = "ANCHOR_RIGHT",
        TOPLEFT     = "ANCHOR_TOPLEFT",
        TOPRIGHT    = "ANCHOR_TOPRIGHT",
        BOTTOMLEFT  = "ANCHOR_BOTTOMLEFT",
        BOTTOMRIGHT = "ANCHOR_BOTTOMRIGHT",
    }

    for value, token in pairs(expected) do
        local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.anchor = value end }
        inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
        assertEqual(inst.mocks.GameTooltip.__anchor, token,
            "anchor " .. value .. " did not reach the client")
    end
end)

test("Each anchor puts the tooltip in the box of a 3x3 around the cell", function()
    -- "Top left" is the box ABOVE AND TO THE LEFT of the cell, not the box above
    -- it aligned to its left edge -- so it grows away from the thing you are
    -- hovering rather than across it. Blizzard's tokens cannot say that: their
    -- TOPLEFT and TOPRIGHT are both directly above, and there is no token at all
    -- for the four diagonals.
    -- red under: going back to SetOwner's placement.
    local EXPECTED = {
        TOPLEFT     = { "BOTTOMRIGHT", "TOPLEFT" },
        TOP         = { "BOTTOM",      "TOP" },
        TOPRIGHT    = { "BOTTOMLEFT",  "TOPRIGHT" },
        LEFT        = { "RIGHT",       "LEFT" },
        RIGHT       = { "LEFT",        "RIGHT" },
        BOTTOMLEFT  = { "TOPRIGHT",    "BOTTOMLEFT" },
        BOTTOM      = { "TOP",         "BOTTOM" },
        BOTTOMRIGHT = { "TOPLEFT",     "BOTTOMRIGHT" },
    }

    for value, want in pairs(EXPECTED) do
        local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.anchor = value end }
        inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

        local tip, relTo, rel = inst.mocks.GameTooltip:GetPoint(1)
        assertTrue(tip ~= nil, value .. ": the tooltip was never placed")
        assertEqual(tip, want[1], value .. ": the tooltip's own corner")
        assertEqual(rel, want[2], value .. ": the corner of the cell it is put against")
        assertTrue(relTo == anchor, value .. ": anchored to something other than the cell")
    end
end)

test("There is no \"At cursor\" anchor, and TOP is what shipped instead", function()
    -- It was the default and it is what every other tooltip in the game does,
    -- which is exactly the trouble: over a grid it lands wherever the pointer
    -- happens to be inside a cell, so the same hover puts the tooltip somewhere
    -- different every time and reads as jitter rather than as a choice. TOP is
    -- the deliberate version of the same thing.
    -- red under: putting the entry back without deciding what it means.
    local inst = T.load()
    local row = inst.NS.FindSchemaRow("window.tooltip.anchor")
    assertTrue(row ~= nil)
    assertEqual(row.default, "TOP")
    assertNil(row.values.CURSOR, "the dropdown still offers the cursor")
end)

test("The anchor dropdown offers nothing the token table cannot resolve", function()
    -- Two independent statements of one list is exactly what a test can check. A
    -- value offered by the dropdown with no token behind it does not error — it
    -- falls back to the cursor, which reads as "the setting does nothing".
    -- red under: adding a value to ANCHOR_VALUES without adding its token.
    local probe = T.load()
    local anchorRow
    for _, r in ipairs(probe.NS.Schema) do
        if r.path == "window.tooltip.anchor" then anchorRow = r end
    end
    assertTrue(anchorRow ~= nil, "the anchor row left the schema")

    for value in pairs(anchorRow.values) do
        local inst, cfg, frame = bench{ configure = function(c) c.tooltip.anchor = value end }
        inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", frame, cfg)
        local token = inst.mocks.GameTooltip.__anchor
        if value == "CURSOR" then
            assertEqual(token, "ANCHOR_CURSOR")
        else
            assertTrue(token ~= "ANCHOR_CURSOR",
                "anchor " .. value .. " silently fell back to the cursor")
        end
        assertTrue(anchorRow.values[value] ~= nil)
    end

    -- Sorting and values must agree, or the dropdown lists an option it cannot order.
    for _, key in ipairs(anchorRow.sorting) do
        assertTrue(anchorRow.values[key] ~= nil, "sorted anchor " .. key .. " has no label")
    end
    local sorted = 0
    for _ in pairs(anchorRow.values) do sorted = sorted + 1 end
    assertEqual(#anchorRow.sorting, sorted, "the sort order and the value list disagree")
end)

test("The x/y offset reaches SetOwner rather than a SetPoint of our own", function()
    -- The offsets go to the CLIENT, as SetOwner's third and fourth arguments, so
    -- the client still does the placing and still keeps the tooltip on screen.
    -- Nudging it ourselves would mean reading a point back off a frame that has
    -- held a secret value, which is rule R3 exactly.
    -- red under: dropping the offsets from the SetOwner call.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.offsetX, c.tooltip.offsetY = 25, -40
    end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    assertEqual(inst.mocks.GameTooltip.__ownerX, 25, "the horizontal offset never arrived")
    assertEqual(inst.mocks.GameTooltip.__ownerY, -40, "the vertical offset never arrived")
end)

test("A junk offset off an old profile is clamped, never handed to the client", function()
    -- A string here raises inside Blizzard's own code, where the traceback names
    -- neither this addon nor the setting that caused it.
    -- red under: passing config.offsetX straight through.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.offsetX, c.tooltip.offsetY = "left a bit", 99999
    end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    assertEqual(inst.mocks.GameTooltip.__ownerX, 0, "a non-number offset was not neutralized")
    assertEqual(inst.mocks.GameTooltip.__ownerY, 400, "an out-of-range offset was not clamped")
end)


-- ---------------------------------------------------------------------------
-- Line spacing
-- ---------------------------------------------------------------------------

test("Bar spacing is applied to the tooltip, and taken back off when it hides", function()
    -- Line spacing belongs to the SHARED GameTooltip, like the minimum width, and
    -- a value left on it silently respaces the next addon's item tooltip.
    -- red under: dropping either the SetCustomLineSpacing call or its reset.
    local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.barSpacing = 5 end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    assertEqual(inst.mocks.GameTooltip:GetCustomLineSpacing(), 5,
        "the configured spacing never reached the tooltip")

    inst.mocks.GameTooltip:Show()
    inst.mocks.GameTooltip:Hide()

    assertEqual(inst.mocks.GameTooltip:GetCustomLineSpacing(), 0,
        "our line spacing outlived our tooltip")
end)


-- ---------------------------------------------------------------------------
-- The font, and putting it back
-- ---------------------------------------------------------------------------

test("The configured font reaches both number slots and the spell name", function()
    -- The names are the bulk of the tooltip's text, so a font that reached only
    -- our own two slots would look half-applied — which is why this asserts the
    -- shared line FontString as well as the carrier's.
    -- red under: dropping the applyLineFont call.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.fontSize    = 17
        c.tooltip.fontOutline = "THICKOUTLINE"
    end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local lines = spellLines(inst)
    assertTrue(#lines > 0, "no spell lines were drawn")

    local _, size, flags = lines[1].amount:GetFont()
    assertEqual(size, 17, "the amount slot did not take the configured size")
    assertEqual(flags, "THICKOUTLINE", "the amount slot did not take the outline flag")

    local _, shareSize = lines[1].share:GetFont()
    assertEqual(shareSize, 17, "the share slot did not take the configured size")

    local left = inst.mocks["GameTooltipTextLeft4"]
    assertTrue(left ~= nil, "the first spell line has no left FontString")
    local _, lineSize = left:GetFont()
    assertEqual(lineSize, 17, "the spell NAME kept the game's tooltip font")
end)

test("NONE is an absent outline flag, not the literal string", function()
    -- WoW wants nil here. The string "NONE" is not a flag it knows, and the
    -- difference is invisible until a font renders wrong.
    -- red under: passing config.fontOutline through unconditionally.
    local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.fontOutline = "NONE" end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local lines = spellLines(inst)
    local _, _, flags = lines[1].amount:GetFont()
    assertEqual(flags, nil, "\"NONE\" was passed to SetFont as a flag string")
end)

test("Every tooltip line we restyled is put back when the tooltip hides", function()
    -- THE ONE THAT MATTERS. GameTooltipTextLeft<N> is SHARED with every other
    -- addon and with every unit, item and quest hover in the game. A SetFont left
    -- on one is this addon silently restyling somebody else's tooltip until the
    -- next reload — the same class of bug as a bar left Shown, and less visible.
    -- red under: dropping restoreFonts from releaseLines.
    local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.fontSize = 19 end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local left = inst.mocks["GameTooltipTextLeft4"]
    assertTrue(select(2, left:GetFont()) == 19, "the line never took our font to begin with")

    inst.mocks.GameTooltip:Show()
    inst.mocks.GameTooltip:Hide()

    assertEqual(left:GetFont(), nil, "our font outlived our tooltip on a SHARED line")
    assertEqual(left:GetFontObject(), inst.mocks.GameTooltipText,
        "the line was cleared but never put back on the game's own font object")
end)


-- ---------------------------------------------------------------------------
-- maxSpells = 0
-- ---------------------------------------------------------------------------

test("maxSpells 0 lists every spell the breakdown collected", function()
    -- 0 is the same "no cap" spelling rows.maxRows and text.maxNameLength use.
    -- red under: the old `cap < 1 then return 10` clamp, which turns 0 into 10.
    local spells = {}
    for i = 1, 18 do spells[i] = { spellID = 100 + i, totalAmount = i * 1000 } end

    local inst, cfg, anchor = bench{
        detail = { combatSpells = spells, maxAmount = 18000, totalAmount = 171000 },
        configure = function(c) c.tooltip.maxSpells = 0 end,
    }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    assertEqual(#spellLines(inst), 18, "a 0 cap did not list every spell")
end)

test("maxSpells 0 is bounded by the collector, and says so", function()
    -- "Every spell" is honest only up to COLLECT_LIMIT, because that is all
    -- collectSpells ever pulls. What must not happen is a silent truncation: the
    -- "and N more" line counts the remainder with SafeCount and keeps saying so.
    -- red under: returning math.huge from spellLineCap, which drops the more-line.
    local spells = {}
    for i = 1, 80 do spells[i] = { spellID = 100 + i, totalAmount = i * 1000 } end

    local inst, cfg, anchor = bench{
        detail = { combatSpells = spells, maxAmount = 80000, totalAmount = 1 },
        configure = function(c) c.tooltip.maxSpells = 0 end,
    }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    assertEqual(#spellLines(inst), 64, "the collector's own ceiling was not respected")

    local sawMore = false
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if type(line.text) == "string" and line.text:match("^and %d+ more$") then sawMore = true end
    end
    assertTrue(sawMore, "80 spells were cut to 64 with nothing said about it")
end)

test("A negative or non-numeric cap still falls back to the shipped default", function()
    -- 0 gained a meaning; junk did not.
    -- red under: treating every non-positive number as "no cap".
    local spells = {}
    for i = 1, 18 do spells[i] = { spellID = 100 + i, totalAmount = i * 1000 } end
    local detail = { combatSpells = spells, maxAmount = 18000, totalAmount = 171000 }

    for _, junk in ipairs({ -4, "ten" }) do
        local inst, cfg, anchor = bench{
            detail = detail,
            configure = function(c) c.tooltip.maxSpells = junk end,
        }
        inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
        assertEqual(#spellLines(inst), 10,
            "a junk cap (" .. tostring(junk) .. ") did not fall back to 10")
    end
end)

test("The font survives a UI skin that re-fonts every line on show", function()
    -- MEASURED ON A LIVE CLIENT, not imagined. The in-game probe reported the
    -- SetFont taking (asked 10/OUTLINE, read back 10/OUTLINE) and the SAME
    -- FontString reading 11/no-flags after Show — the signature of a tooltip skin
    -- hooking OnShow and re-applying its own face at its own size. Setting the
    -- font before Show is therefore not enough, however correct it looks.
    --
    -- The skin is modelled with a real OnShow hook so the ORDERING is the real
    -- one: Show fires the hook, the hook restyles, and our second pass runs after
    -- Show returns. A test that just called SetFont twice would prove nothing.
    -- red under: applying the font only inside drawLine.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.fontSize    = 17
        c.tooltip.fontOutline = "THICKOUTLINE"
    end }

    local mocks = inst.mocks
    -- Hidden first, deliberately. The mock fires OnShow only on a hide->show
    -- TRANSITION, and a GameTooltip left shown by an earlier case makes the hook
    -- below never run — which made this case pass against the very code it was
    -- written to catch. `restyled` is asserted at the end for the same reason: a
    -- skin that never ran proves nothing about surviving one.
    mocks.GameTooltip:Hide()
    local restyled = 0
    mocks.GameTooltip:HookScript("OnShow", function()
        restyled = restyled + 1
        local i = 1
        while mocks["GameTooltipTextLeft" .. i] do
            local fs = mocks["GameTooltipTextLeft" .. i]
            local path = fs:GetFont()
            if path then fs:SetFont(path, 11, "") end
            i = i + 1
        end
    end)

    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    assertTrue(restyled > 0, "the simulated skin never ran, so this proves nothing")
    local left = mocks["GameTooltipTextLeft4"]
    assertTrue(left ~= nil, "the first spell line has no left FontString")
    local _, size, flags = left:GetFont()
    assertEqual(size, 17, "the skin's re-font on Show won — our pass runs too early")
    assertEqual(flags, "THICKOUTLINE", "the outline flag was lost to the skin")
end)

test("The post-layout pass still restores every line it touched", function()
    -- Applying the font twice must not leave twice as much to clean up. The
    -- lines are SHARED with every other addon, so a second pass that escaped the
    -- restore bookkeeping would be the original leak with an extra step.
    -- red under: reapplyFonts writing to lines it never recorded.
    local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.fontSize = 19 end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local left = inst.mocks["GameTooltipTextLeft4"]
    assertEqual(select(2, left:GetFont()), 19, "the line never took our font")

    inst.mocks.GameTooltip:Show()
    inst.mocks.GameTooltip:Hide()

    assertEqual(left:GetFont(), nil, "our font outlived our tooltip on a SHARED line")
end)

test("A target's name is drawn on our own carrier, not on the tooltip's line", function()
    -- A target has no icon — a unit is not a spell — but its name still has to
    -- start where a spell NAME starts rather than where a spell ICON starts, or
    -- the two sections read as two unrelated tables. There is no way to indent
    -- GameTooltip's own line text (a `|T…|t` spacer needs a transparent texture
    -- to point at, and padding with spaces is font-dependent), so the name goes
    -- on the carrier's own label slot, which is already anchored past the icon.
    -- red under: passing the name to AddLine and leaving the label empty.
    local inst, cfg, anchor = bench{ configure = function(c)
        c.tooltip.showTargets = true
        c.tooltip.maxTargets  = 2
    end }

    local mocks = inst.mocks
    local ENEMY_STAT = mocks.Enum.DamageMeterType.EnemyDamageTaken
    local sources = {}
    for i, enemy in ipairs({ "Primal Thundercloud", "Storm Warrior" }) do
        local guid = string.format("Creature-0-0000-0-0-%04d", i)
        sources[i] = { sourceGUID = guid, guid = guid, sourceCreatureID = 7000 + i,
                       name = enemy, totalAmount = 1 }
        local detail = { combatSpells = { { spellID = i, totalAmount = 900 - i * 100,
            combatSpellDetails = { unitName = "Alpha" } } } }
        mocks.setSourceDetail(CURRENT, ENEMY_STAT, guid, detail)
        mocks.setSourceDetail(CURRENT, ENEMY_STAT, "creature:" .. (7000 + i), detail)
    end
    mocks.setSession(CURRENT, ENEMY_STAT,
        { combatSources = sources, maxAmount = 1, totalAmount = 1 })

    inst.NS.Tooltip:CellTooltip(makeRow{ name = "Alpha" }, "DamageDone", anchor, cfg)

    local labels = {}
    for _, carrier in ipairs(spellLines(inst)) do
        local text = carrier.label and carrier.label:GetText()
        if text and text ~= "" then labels[#labels + 1] = text end
    end

    assertEqual(#labels, 2, "the target names never reached a carrier label")
    assertEqual(labels[1], "Primal Thundercloud")

    -- And the tooltip's own line for a target is blank, so nothing is drawn
    -- twice at two different indents.
    local sawNameInLine = false
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if type(line.text) == "string" and line.text:find("Primal Thundercloud") then
            sawNameInLine = true
        end
    end
    assertFalse(sawNameInLine, "the name was also written into the tooltip's own line")
end)

test("The gap above a section is half the text size, not a whole blank line", function()
    -- A blank AddLine is a WHOLE line of the tooltip's font, which read as a
    -- paragraph gap above "Spell breakdown" and again above "Targets". There is
    -- no half-line in GameTooltip, but a line's HEIGHT follows its font — so the
    -- spacer takes the same face at half the size.
    -- red under: a bare AddLine(" ") before the section header.
    local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.fontSize = 20 end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    -- Line 2 is the gap: line 1 is the "<player> / <stat>" header, line 3 is
    -- "Spell breakdown", and the spell lines follow.
    local gap = inst.mocks["GameTooltipTextLeft2"]
    assertTrue(gap ~= nil, "there is no line where the section gap should be")
    assertEqual(select(2, gap:GetFont()), 10, "the gap is not half the configured size")

    -- The header beneath it keeps the full size, or the section title shrinks too.
    local spell = inst.mocks["GameTooltipTextLeft4"]
    assertEqual(select(2, spell:GetFont()), 20, "the spell line was shrunk along with the gap")
end)

test("The half-size gap survives the post-layout pass", function()
    -- The re-apply after Show walks every line it touched. Remembering ONE font
    -- for the hover would have it stamp full size back over the gap and quietly
    -- restore the blank line this just halved.
    -- red under: reapplyFonts using a single remembered font.
    local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.fontSize = 20 end }
    local mocks = inst.mocks

    mocks.GameTooltip:Hide()
    mocks.GameTooltip:HookScript("OnShow", function()
        local i = 1
        while mocks["GameTooltipTextLeft" .. i] do
            local fs = mocks["GameTooltipTextLeft" .. i]
            local path = fs:GetFont()
            if path then fs:SetFont(path, 11, "") end
            i = i + 1
        end
    end)

    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
    assertEqual(select(2, mocks["GameTooltipTextLeft2"]:GetFont()), 10,
        "the gap was restored to full size by the re-apply")
end)

test("The gap is restored with every other line it was applied alongside", function()
    -- A shrunken font left on a SHARED line is the same leak as any other, and
    -- it would land on whatever the next addon puts there.
    -- red under: applying the gap's font outside the restore bookkeeping.
    local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.fontSize = 20 end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local gap = inst.mocks["GameTooltipTextLeft2"]
    assertEqual(select(2, gap:GetFont()), 10, "the gap never took the half size")

    inst.mocks.GameTooltip:Show()
    inst.mocks.GameTooltip:Hide()
    assertEqual(gap:GetFont(), nil, "a shrunken font outlived our tooltip on a shared line")
end)
