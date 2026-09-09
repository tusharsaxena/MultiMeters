-- tests/test_tooltip_builders.lua — modules/Tooltip_Builders.lua: the tooltips
-- the primitives build.
--
-- WHAT IT PROVES. The per-spell cell breakdown — which kick, which dispel, which
-- avoidable hit; the Deaths cell; and the NAME tooltip, which summarizes EVERY
-- tracked statistic for one player including the columns this window is not
-- showing. That cross-column read is the thing the whole addon exists for, so it
-- is the one hover whose absence would not look like a bug.
--
-- WHY IT IS A SEPARATE FILE. modules/Tooltip.lua went past layout-§1's 1500-line
-- cap (issue #28) and the four builders moved to modules/Tooltip_Builders.lua.
-- The death-event half of that module has a suite of its own next door
-- (tests/test_tooltip_deaths.lua) — it is the largest block on either side and
-- it answers a question none of the other three do.
--
-- The spells in every fixture ASCEND, for the reason tests/test_tooltip.lua's
-- header gives.
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

--- The spell IDs the tooltip listed, in the order it listed them.
local function listedSpellIDs(mocks)
    local out = {}
    for _, line in ipairs(mocks.GameTooltip.__lines) do
        local text = line.text
        if type(text) == "string" then
            local id = text:match("Mock Spell (%d+)")
            if id then out[#out + 1] = tonumber(id) end
        end
    end
    return out
end


-- ---------------------------------------------------------------------------
-- The cell tooltip
-- ---------------------------------------------------------------------------

test("CellTooltip opens on the hovered cell and heads with the player and the stat", function()
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local tt = inst.mocks.GameTooltip
    assertTrue(tt:GetOwner() == anchor, "GameTooltip is re-owned on every hover")
    assertEqual(tt.__lines[1].text, "Alpha")
    assertEqual(tt.__lines[1].right, "Damage", "localized at the use site, from the catalog")
end)

test("CellTooltip honors the anchor setting and falls back to the default", function()
    local inst, cfg, anchor = bench()
    cfg.tooltip.anchor = "BOTTOMRIGHT"
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
    assertEqual(inst.mocks.GameTooltip.__anchor, "ANCHOR_BOTTOMRIGHT")

    -- TOP, because it is the shipped default: an anchor this build does not
    -- offer -- a typo, or a profile that escaped the v9 -> v10 step still
    -- carrying "CURSOR" -- lands where a new window does rather than somewhere
    -- nothing else uses.
    cfg.tooltip.anchor = "SOMETHINGWRONG"
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
    assertEqual(inst.mocks.GameTooltip.__anchor, "ANCHOR_TOP",
        "a typo'd token must not silently become a broken anchor")

    local tip, _, rel = inst.mocks.GameTooltip:GetPoint(1)
    assertEqual(tip, "BOTTOM", "the fallback must be PLACED as well as owned")
    assertEqual(rel, "TOP")
end)

test("CellTooltip sorts biggest-first when comparison is legal", function()
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    -- The fixture ascends; a sorted tooltip descends.
    local ids = listedSpellIDs(inst.mocks)
    assertEqual(#ids, 3)
    assertEqual(ids[1], 103)
    assertEqual(ids[2], 102)
    assertEqual(ids[3], 101)
end)

test("CellTooltip REFUSES the sort while comparison is illegal", function()
    local inst, cfg, anchor = bench{ restricted = true }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    -- Not a degradation: the API already returns a meaningful sequence, and the
    -- alternative is a Lua error on every hover for the whole of a pull.
    local ids = listedSpellIDs(inst.mocks)
    assertEqual(#ids, 3)
    assertEqual(ids[1], 101, "the provider's own order, unreversed")
    assertEqual(ids[3], 103)
end)

test("CellTooltip refuses the sort when an amount is MISSING, not merely secret", function()
    -- CanAccess(nil) is TRUE — nil is not a secret — so a spell row with no
    -- totalAmount sails through a comparability check and then raises inside the
    -- comparator with "attempt to compare nil with number". This was a real bug.
    local inst, cfg, anchor = bench{ detail = {
        combatSpells = {
            { spellID = 101, totalAmount = 100 },
            { spellID = 102 },                      -- no amount at all
            { spellID = 103, totalAmount = 300 },
        },
        maxAmount = 300, totalAmount = 400,
    } }

    local ok = pcall(function()
        inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
    end)
    assertTrue(ok, "a missing amount must refuse the sort, not raise inside it")

    local ids = listedSpellIDs(inst.mocks)
    assertEqual(ids[1], 101, "and the whole list keeps the provider's order")
    assertEqual(ids[2], 102)
    assertEqual(ids[3], 103)
end)

test("CellTooltip caps the list at maxSpells and says how many were left out", function()
    local inst, cfg, anchor = bench{
        detail = { combatSpells = {
            { spellID = 101, totalAmount = 500 }, { spellID = 102, totalAmount = 400 },
            { spellID = 103, totalAmount = 300 }, { spellID = 104, totalAmount = 200 },
            { spellID = 105, totalAmount = 100 },
        }, maxAmount = 500, totalAmount = 1500 },
        configure = function(cfg) cfg.tooltip.maxSpells = 2 end,
    }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    assertEqual(#listedSpellIDs(inst.mocks), 2)

    -- The count comes from NS.Secrets.SafeCount, which never applies `#` to a
    -- possibly-secret array — which is what lets this line be honest at all.
    local more = false
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if type(line.text) == "string" and line.text:find("and 3 more", 1, true) then
            more = true
        end
    end
    assertTrue(more, "the tooltip must say what it left out")
end)

test("CellTooltip renders secret amounts through the formatter, untouched", function()
    local inst, cfg, anchor = bench{ restricted = true }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local amounts = {}
    for _, carrier in ipairs(spellLines(inst)) do
        amounts[#amounts + 1] = carrier.amount.__text
    end
    assertEqual(#amounts, 3)
    -- Nothing added them, nothing compared them; they went through the native
    -- formatter and straight to the widget.
    assertEqual(amounts[1], "100")
    assertEqual(amounts[3], "300")
end)

test("CellTooltip says 'no data' rather than showing an empty frame", function()
    local inst = T.load()
    local cfg = inst.NS.Database.GetWindows()[1]
    local anchor = inst.mocks.__stubFrame("Frame")
    inst.mocks.GameTooltip:ClearLines()

    -- No source detail installed at all: the provider refuses and the tooltip
    -- has to say something.
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
    local found = false
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if line.text == inst.NS.L["No data yet"] then found = true end
    end
    assertTrue(found)
end)

test("showSpells = false keeps the header and drops the breakdown", function()
    local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.showSpells = false end }
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
    assertEqual(#listedSpellIDs(inst.mocks), 0)
end)

test("hideInCombat refuses the hover outright", function()
    local inst, cfg, anchor = bench{ configure = function(c) c.tooltip.hideInCombat = true end }
    inst.mocks.setInCombat(true)

    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
    assertEqual(#inst.mocks.GameTooltip.__lines, 0, "nothing is added at all")

    -- The test is UnitAffectingCombat, not InCombatLockdown: what the setting
    -- means is "while I am fighting, keep this out of my way", which is a
    -- statement about the player rather than about secure writes.
    inst.mocks.setInCombat(false)
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
    assertTrue(#inst.mocks.GameTooltip.__lines > 0)
end)

test("An unresolvable spell is shown by ID rather than dropped", function()
    local inst, cfg, anchor = bench{
        detail = { combatSpells = { { spellID = 909, totalAmount = 10 } },
                   maxAmount = 10, totalAmount = 10 },
    }
    inst.mocks.C_Spell.GetSpellInfo = function() return nil end

    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)

    local found = false
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if type(line.text) == "string" and line.text:find("#909", 1, true) then found = true end
    end
    assertTrue(found, "an unnamed row is still evidence; a silently missing row is not")
end)


-- ---------------------------------------------------------------------------
-- Avoidable damage carries its own facts
-- ---------------------------------------------------------------------------

test("The avoidable column tags nothing per spell — no Deadly, no Overkill", function()
    local inst, cfg, anchor = bench{ detail = {
        combatSpells = {
            { spellID = 101, totalAmount = 100, isAvoidable = true, isDeadly = true,
              overkillAmount = 40 },
        },
        maxAmount = 100, totalAmount = 100,
    } }
    inst.NS.Tooltip:CellTooltip(makeRow(), "AvoidableDamageTaken", anchor, cfg)

    local text = ""
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if type(line.text) == "string" then text = text .. line.text .. "\n" end
    end

    -- EVERY spell in an Avoidable Damage breakdown is avoidable, and the header
    -- above the list already says so — a gray "Avoidable" / "Avoidable, Deadly"
    -- sub-line beneath each bar restated the column once per row and broke the
    -- list into ragged groups. It was most visible in test mode, where the
    -- preview detail sets both flags on alternating spells.
    -- red under: restoring addAvoidableDetail.
    assertFalse(text:find("Deadly", 1, true) ~= nil,
        "the per-spell flag lines are noise inside a column that IS the flag")

    -- Overkill is the part of a KILLING BLOW that exceeded the target's remaining
    -- health — a fact about damage DEALT. On damage the player took it is either
    -- zero or the amount by which they were already dead, and neither answers
    -- "could I have stepped out of this". Blizzard still ships the field; we have
    -- no column it belongs to.
    assertFalse(text:find("Overkill", 1, true) ~= nil,
        "the overkill line is noise on damage taken")
end)

test("Those flags are never truth-tested anywhere — a secret boolean would raise", function()
    local inst, cfg, anchor = bench{ restricted = true, detail = {
        combatSpells = {
            { spellID = 101, totalAmount = 100, isAvoidable = true, isDeadly = true,
              overkillAmount = 40 },
        },
        maxAmount = 100, totalAmount = 100,
    } }

    -- `if spell.isAvoidable then` is the natural way to write it and raises the
    -- moment the restriction is active. Nothing reads these flags today, and this
    -- case is what keeps a reader that comes back from reading them the raising
    -- way — the spells still carry them, so a direct truth test would fail here.
    local ok = pcall(function()
        inst.NS.Tooltip:CellTooltip(makeRow(), "AvoidableDamageTaken", anchor, cfg)
    end)
    assertTrue(ok)

    local text = ""
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if type(line.text) == "string" then text = text .. line.text .. "\n" end
    end
    -- Reaching this line at all is the assertion: the simulator raises on a
    -- boolean test of a secret, so a `if spell.isAvoidable then` that crept back
    -- in would have failed the pcall above rather than produced a wrong string.
    assertFalse(text:find("Overkill", 1, true) ~= nil)
end)


-- ---------------------------------------------------------------------------
-- The Deaths cell
-- ---------------------------------------------------------------------------

test("The Deaths cell advertises the click that opens the recap", function()
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow{ deathRecapID = 4242 }, "Deaths", anchor, cfg)

    local found = false
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if line.text == inst.NS.L["Click for details"] then found = true end
    end
    assertTrue(found, "it is the one cell where a click does something else")
end)

test("A death with no recap id advertises nothing", function()
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow(), "Deaths", anchor, cfg)
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        assertFalse(line.text == inst.NS.L["Click for details"])
    end
end)


-- ---------------------------------------------------------------------------
-- The name tooltip
-- ---------------------------------------------------------------------------

test("NameTooltip lists EVERY tracked stat, dimming the ones not on screen", function()
    local inst, cfg, anchor = bench()
    cfg.columns = { { stat = "DamageDone", width = 90 } }

    inst.NS.Tooltip:NameTooltip(makeRow(), anchor, cfg)

    local labels = {}
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if line.double then labels[#labels + 1] = line.text end
    end
    -- Showing the hidden columns is the requirement: the reason to hover a name
    -- is to ask "what else did they do".
    assertEqual(#labels, #inst.NS.Constants.STATS)

    local Const = inst.NS.Constants
    local lines = {}
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if line.double then lines[#lines + 1] = line end
    end

    local onScreen, dimmed = 0, 0
    for i, stat in ipairs(Const.STATS) do
        local full = Const.STAT_COLORS[stat.key]
        local red  = lines[i].leftColor[1]
        if math.abs(red - full[1]) < 0.001 then
            onScreen = onScreen + 1
        elseif math.abs(red - full[1] * Const.STAT_DIM) < 0.001 then
            dimmed = dimmed + 1
        end
    end
    assertEqual(onScreen, 1, "the window's own column is drawn in full color")
    assertEqual(dimmed, #Const.STATS - 1)
end)

test("NameTooltip colors each stat by the catalog palette, whatever colorMode says", function()
    -- THE PALETTE IS NOT THE BAR SETTING. `bars.colorMode` governs the bars in the
    -- grid; this list is the one surface where all nine statistics appear at once,
    -- and the color is what ties a line here to its column in the window behind
    -- it. So it wears the palette even with the bars set to class color.
    -- red under: gating the line color on bars.colorMode == "stat".
    local inst, cfg, anchor = bench()
    cfg.bars.colorMode = "class"
    cfg.columns = { { stat = "DamageDone", width = 90 }, { stat = "HealingDone", width = 90 } }

    inst.NS.Tooltip:NameTooltip(makeRow(), anchor, cfg)

    local Const = inst.NS.Constants
    local lines = {}
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if line.double then lines[#lines + 1] = line end
    end

    -- The catalog's order is the tooltip's order: Damage first, Healing second.
    local damage, healing = Const.STAT_COLORS.DamageDone, Const.STAT_COLORS.HealingDone
    assertEqual(lines[1].leftColor[1], damage[1])
    assertEqual(lines[1].leftColor[2], damage[2])
    assertEqual(lines[2].leftColor[1], healing[1])
    assertEqual(lines[2].leftColor[2], healing[2])
    assertTrue(damage[1] ~= healing[1] or damage[2] ~= healing[2],
        "two statistics must not share one color, or the palette says nothing")
end)

test("NameTooltip colors the AMOUNT the same as its label, on both sides of the line", function()
    -- A colored name beside a white number reads as two things; the line is one
    -- fact. It was also plainly inconsistent — the dimmed rows carried a gray
    -- number while the rest carried white ones.
    -- red under: passing 1, 1, 1 for the right-hand side again.
    local inst, cfg, anchor = bench()
    cfg.columns = { { stat = "DamageDone", width = 90 } }

    inst.NS.Tooltip:NameTooltip(makeRow(), anchor, cfg)

    local Const = inst.NS.Constants
    local lines = {}
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if line.double then lines[#lines + 1] = line end
    end

    for i, stat in ipairs(Const.STATS) do
        local line = lines[i]
        for channel = 1, 3 do
            assertEqual(line.rightColor[channel], line.leftColor[channel],
                stat.key .. "'s amount must wear its label's color")
        end
    end

    -- And the dimming reaches the amount too: the second statistic has no column
    -- in this window, so its whole line is the dimmed hue.
    local hidden = Const.STATS[2]
    assertEqual(lines[2].rightColor[1], Const.STAT_COLORS[hidden.key][1] * Const.STAT_DIM)
end)

test("NameTooltip works while restricted, adding nothing up", function()
    local inst, cfg, anchor = bench{ restricted = true }
    local ok = pcall(function() inst.NS.Tooltip:NameTooltip(makeRow(), anchor, cfg) end)
    assertTrue(ok)
    assertTrue(#inst.mocks.GameTooltip.__lines > 1)
end)

test("showAllStatsOnName = false stops after the name", function()
    local inst, cfg, anchor = bench{
        configure = function(c) c.tooltip.showAllStatsOnName = false end }
    inst.NS.Tooltip:NameTooltip(makeRow(), anchor, cfg)
    assertEqual(#inst.mocks.GameTooltip.__lines, 1)
end)

test("NameTooltip says 'no data' when the meter has nothing for the player", function()
    local inst = T.load()
    local cfg = inst.NS.Database.GetWindows()[1]
    local anchor = inst.mocks.__stubFrame("Frame")
    inst.mocks.GameTooltip:ClearLines()

    inst.NS.Tooltip:NameTooltip(makeRow(), anchor, cfg)
    local found = false
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if line.text == inst.NS.L["No data yet"] then found = true end
    end
    assertTrue(found)
end)

test("A tooltip resolves its window from row.windowId when it was not handed one", function()
    local inst, cfg, anchor = bench()
    -- The row-pool call sites hold a window ID on the frame, not the table.
    inst.NS.Tooltip:CellTooltip(makeRow{ windowId = cfg.id }, "DamageDone", anchor)
    assertTrue(#inst.mocks.GameTooltip.__lines > 0)
end)

test("Tooltip:Hide is unconditional", function()
    local inst, cfg, anchor = bench()
    inst.NS.Tooltip:CellTooltip(makeRow(), "DamageDone", anchor, cfg)
    inst.NS.Tooltip:Hide()
    -- A hide the addon did not need to do is invisible; a tooltip left pinned
    -- under the cursor is the single most reported meter bug there is.
    assertEqual(inst.mocks.GameTooltip:IsShown(), false)
end)
