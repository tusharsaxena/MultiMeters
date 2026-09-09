-- tests/test_tooltip_deaths.lua — the death-event tooltip (issue #1), and the
-- grid's Deaths cell.
--
-- WHAT IT PROVES. That a death reads as a story rather than as a number: the
-- events behind it in the order they happened, the columns they line up in, and
-- what the grid's own Deaths cell says before anyone hovers it. Plus the
-- characterization cases pinned for issue #40 over the three functions `lizard`
-- warned on here.
--
-- WHY IT IS A SEPARATE FILE. It covers modules/Tooltip_Builders.lua like its
-- sibling tests/test_tooltip_builders.lua does, and it is split off because the
-- death-event block is the biggest single thing on that side — enough on its own
-- to put one file back over layout-§1's cap (issue #28). It is also the block
-- with the clearest lifecycle: it exists for issue #1, and it can be deleted
-- with it.
--
-- RULE R1 IS THE POINT OF HALF OF THESE. `#` is never applied to an events
-- array — `SafeIterate` is the only legal measure — and one unreadable caption
-- abandons the WHOLE measurement rather than sizing from the readable half.
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
-- The death-event tooltip (issue #1)
-- ---------------------------------------------------------------------------
--
-- Hovering a death row shows what killed that player: one line per incoming
-- event, oldest first, so the killing blow is the last thing read. Icon and
-- caption on the tooltip's own line; damage and HP percentage in the carrier's
-- two slots; the bar behind them is HP REMAINING, not damage.
--
-- The caption is the risky part. It joins a spell name and an attacker name,
-- both resolved off ids that the client may hand back secret, and this file has
-- never concatenated anything that could be one.

--- Two events, newest first, as the client returns them.
local function recapEvents(opts)
    opts = opts or {}
    return {
        { spellId = 264206, spellName = opts.lastName or "Volley",
          sourceName = opts.lastSource, hideCaster = opts.hideCaster,
          amount = 787300, overkill = 138100, currentHP = 100000,
          event = "SPELL_DAMAGE", timestamp = 1000.0 },
        { spellId = 1301253, spellName = "Gust", sourceName = "Merektha",
          amount = 36900, currentHP = 700000,
          event = "SPELL_DAMAGE", timestamp = 954.6 },
    }
end

--- A drill-down death row plus a client that answers its recap.
local function deathBench(opts)
    opts = opts or {}
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap({
        HasRecapEvents    = function() return true end,
        GetRecapEvents    = function() return opts.events or recapEvents(opts) end,
        GetRecapMaxHealth = function() return opts.maxHealth or 738800 end,
    })
    local row = {
        guid = "death:29", recapID = 29, isDeath = true, name = "Death 3",
        deathClock = "13:01:06",
        classFilename = "PALADIN", isDrillDown = true,
        values = { Deaths = { total = 1, maxAmount = 1, displayText = "13:01:06" } },
        maxAmount = 1,
    }
    return inst, cfg, anchor, row
end

--- Every death line's four slots, joined, so a case can assert on content
--- without caring which column it landed in.
---
--- The tooltip's own line holds ONLY the icon now — time, spell, caster and the
--- two numbers are all carrier slots — so a case that reads GameTooltipTextLeft
--- for a spell name is reading the wrong widget.
local function slotTexts(inst)
    local out = {}
    for _, line in ipairs(spellLines(inst)) do
        out[#out + 1] = table.concat({
            line.time:GetText() or "", line.label:GetText() or "",
            line.caster:GetText() or "", line.amount:GetText() or "",
            line.share:GetText() or "",
        }, " ")
    end
    return table.concat(out, "\n")
end

--- Every tooltip line's text, in order.
local function lineTexts(inst)
    local out, i = {}, 1
    while inst.mocks["GameTooltipTextLeft" .. i] do
        local fs = inst.mocks["GameTooltipTextLeft" .. i]
        if not fs:IsShown() then break end
        out[i] = fs:GetText()
        i = i + 1
    end
    return out
end

test("Tooltip: hovering a death row lists its events, OLDEST first", function()
    -- The killing blow is the last line read, which is the order the whole
    -- surface is meant to be read in. The client returns them newest first.
    -- red under: rendering the array as it arrives.
    local inst, cfg, anchor, row = deathBench()
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local texts = slotTexts(inst)
    local gust, volley = texts:find("Gust", 1, true), texts:find("Volley", 1, true)
    assertTrue(gust ~= nil and volley ~= nil, "both events must be listed")
    assertTrue(gust < volley, "the killing blow must be last")
end)

test("Tooltip: a death row never reaches the client's spell tooltip", function()
    -- SetSpellByID replaces the tooltip's whole content, so a death row that
    -- happened to carry a spellID would silently render a spell page instead of
    -- the event list.
    -- red under: the death branch sitting after the spellID path.
    local inst, cfg, anchor, row = deathBench()
    row.spellID = 264206
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
    assertTrue(#spellLines(inst) > 0, "the event carriers were never drawn")
end)

test("Tooltip: each event line shows the time before death and the attacker", function()
    local inst, cfg, anchor, row = deathBench{ lastSource = "Merektha" }
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local texts = slotTexts(inst)
    assertTrue(texts:find("-45.4s", 1, true) ~= nil,
        "the first event is 45.4s before the killing blow")
    assertTrue(texts:find("Merektha", 1, true) ~= nil, "the attacker was dropped")
end)

test("Tooltip: an event with no attacker renders without the clause", function()
    -- `hideCaster` is true on a real sample and sourceName is simply absent. A
    -- caption reading "Volley ()" is worse than one reading "Volley".
    -- red under: formatting the attacker unconditionally.
    local inst, cfg, anchor, row = deathBench{ hideCaster = true }
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
    assertTrue(slotTexts(inst):find("()", 1, true) == nil,
        "an empty attacker clause was rendered")
end)

test("Tooltip: the bar behind an event is HP REMAINING, handed over raw", function()
    -- The percentage is a division and dividing a secret is what rule R1
    -- forbids. Passing currentHP and maxHealth to the widget lets the engine
    -- divide, which core/Secrets.lua puts on the MAY list.
    -- red under: computing currentHP / maxHealth in Lua.
    local inst, cfg, anchor, row = deathBench()
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local first = spellLines(inst)[1]
    local mn, mx = first.bar:GetMinMaxValues()
    assertEqual(mn, 0)
    assertEqual(mx, 738800, "the max must be the recap's own max health")
    assertEqual(first.bar:GetValue(), 700000, "the value must be HP at that event")
end)

test("Tooltip: the killing blow is the LAST line, and carries no overkill", function()
    -- Overkill was dropped from this surface on purpose — it is the part of a
    -- killing blow that exceeded health the player no longer had, it appears on
    -- one line in ten, and it collided with the HP percentage. What still has to
    -- hold is that the fatal hit reads last.
    local inst, cfg, anchor, row = deathBench()
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local lines = spellLines(inst)
    assertEqual(lines[#lines].label:GetText(), "Volley", "the killing blow must be last")
    assertTrue(slotTexts(inst):lower():find("overkill", 1, true) == nil)
end)

test("Tooltip: a secret spell name never meets concatenation", function()
    -- The whole reason the caption goes through one string.format. Under the
    -- simulated secret the mock traps `..`, so a join raises here rather than
    -- mid-pull in front of a player.
    -- red under: `caption .. " (" .. sourceName .. ")"`.
    local inst, cfg, anchor, row = deathBench{
        lastName = nil, lastSource = nil,
    }
    inst.mocks.setDeathRecap({
        HasRecapEvents    = function() return true end,
        GetRecapEvents    = function()
            return {
                { spellId = 264206, spellName = inst.mocks.secret("Volley"),
                  sourceName = inst.mocks.secret("Merektha"),
                  amount = inst.mocks.secret(787300),
                  currentHP = inst.mocks.secret(100000),
                  timestamp = inst.mocks.secret(1000.0) },
            }
        end,
        GetRecapMaxHealth = function() return inst.mocks.secret(738800) end,
    })
    inst.mocks.setSecretsAccessible(false)

    local ok, err = pcall(function()
        inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
    end)
    assertTrue(ok, "the death tooltip raised on a secret: " .. tostring(err))
end)

test("Tooltip: with the values secret the bar still draws and the share does not lie", function()
    -- A percentage that cannot be computed is rendered as nothing, never as 0%.
    -- The bar is unaffected, because the widget divides.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents    = function() return true end,
        GetRecapEvents    = function()
            return { { spellId = 264206, spellName = "Volley",
                       amount = inst.mocks.secret(787300),
                       currentHP = inst.mocks.secret(100000),
                       timestamp = 1000.0 } }
        end,
        GetRecapMaxHealth = function() return inst.mocks.secret(738800) end,
    })
    inst.mocks.setSecretsAccessible(false)
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local first = spellLines(inst)[1]
    assertTrue(first ~= nil, "no line was drawn at all")
    -- EXACTLY EMPTY, not merely "not 0%". The old assertion was true of the
    -- right answer, of a wrongly computed percentage, and of almost anything
    -- else — deleting the share argument outright kept the suite green.
    assertEqual(first.share:GetText(), "",
        "a refused division must render nothing, never a number")
    local mn, mx = first.bar:GetMinMaxValues()
    assertEqual(mn, 0)
    assertTrue(mx ~= nil and mx ~= 1, "the bar lost its max and fell back to 0..1")
end)

test("Tooltip: with the values plain the share slot carries the percentage", function()
    -- The other half of design §9's requirement, which nothing asserted at all.
    -- red under: passing "" as the share, which deletes the HP column and which
    -- the suite used to accept.
    local inst, cfg, anchor, row = deathBench{ maxHealth = 1000 }
    inst.mocks.setDeathRecap({
        HasRecapEvents    = function() return true end,
        GetRecapEvents    = function()
            return { { spellId = 264206, spellName = "Volley", amount = 250,
                       currentHP = 500, timestamp = 1000.0 } }
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local share = spellLines(inst)[1].share:GetText()
    assertTrue(share:find("50", 1, true) ~= nil,
        "500 of 1000 must render as 50%, got " .. tostring(share))
end)

test("Tooltip: a death whose recap has gone says so instead of drawing nothing", function()
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({ HasRecapEvents = function() return false end })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:find("recap", 1, true) ~= nil, "an empty tooltip reads as a bug")
end)

test("Tooltip: a death with no recap id says so rather than showing a name", function()
    -- It fell through to the one-line displayName path, which on a death row
    -- renders "Death 2" and nothing else — indistinguishable from a tooltip that
    -- failed to build.
    -- red under: keying the death branch on recapID instead of on the row kind.
    local inst, cfg, anchor = deathBench()
    local row = {
        guid = "death:none:2", isDeath = true, name = "Death 2",
        classFilename = "PALADIN", isDrillDown = true,
        values = { Deaths = { total = 1, maxAmount = 1, displayText = "\226\128\148" } },
    }
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:find("recap", 1, true) ~= nil,
        "a death row with no id must explain itself")
end)

test("Tooltip: a death tooltip has a HEADER, so no carrier ever lands on line 1", function()
    -- FOUND BY REVIEW, and it leaks out of this addon entirely. drawLine calls
    -- applyLineFont on the tooltip line it sits behind and records it, and
    -- restoreFonts puts SetFontObject(GameTooltipText) back on teardown. On a
    -- live client GameTooltipTextLeft1 inherits GameTooltipHeaderText, not
    -- GameTooltipText — so a carrier on line 1 means every GameTooltip in the
    -- GAME renders its title in the small body font until /reload.
    --
    -- Every other caller puts a header on line 1 and never hands index 1 to
    -- drawLine, which is exactly what this file's own releaseLines comment
    -- claims: "a spell line is never line 1".
    -- red under: addDeathBreakdown adding no title line.
    local inst, cfg, anchor, row = deathBench()
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local byIndex = tooltipLines(inst)
    assertTrue(byIndex[1] == nil, "an event carrier landed on the tooltip's header line")
    assertTrue(lineTexts(inst)[1] ~= nil, "there must be a header line at all")
end)

test("Tooltip: the death header names the player and when they died", function()
    -- The row itself only says "Death 3"; the tooltip is where the reader finds
    -- out whose death and at what time.
    local inst, cfg, anchor, row = deathBench()
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
    -- AddDoubleLine, as CellTooltip's header is: the player on the left, the
    -- time on the right, so the two read as a caption rather than a sentence.
    local left  = inst.mocks.GameTooltipTextLeft1
    local right = inst.mocks.GameTooltipTextRight1
    assertTrue((right and right:GetText() or ""):find("13:01:06", 1, true) ~= nil,
        "the time of death is missing")
    assertTrue((left and left:GetText() or "") ~= "", "the player is missing")
end)

test("Tooltip: a death with no recap keeps the header too", function()
    -- The empty case takes the same route out, or it reintroduces the bug on the
    -- one path nobody looks at.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({ HasRecapEvents = function() return false end })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
    assertTrue(tooltipLines(inst)[1] == nil, "a carrier landed on the header line")
end)


-- ---------------------------------------------------------------------------
-- The GRID's Deaths cell (issue #1's first complaint)
-- ---------------------------------------------------------------------------
--
-- "The tooltip runs the ordinary spell-breakdown path, which asks the provider
-- for combatSpells on a Deaths source. There is no spell list on a death row, so
-- it renders 'No data yet' — technically honest, and useless. A Deaths cell
-- should not be showing a spell breakdown at all."

--- A grid row for somebody who died three times.
local function deadGridRow()
    return {
        guid = "Player-1-0000000A", name = "Yllarie", classFilename = "PRIEST",
        deaths = { 29, 28, 27 }, deathRecapID = 29,
        values = { Deaths = { total = 3, maxAmount = 3 } },
    }
end

test("Tooltip: a Deaths cell lists the DEATHS, not a spell breakdown", function()
    -- red under: the Deaths cell falling through to addSpellBreakdown, which is
    -- what shipped and what the issue opens with.
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function(id)
            return { { spellId = 1, spellName = "X", amount = 1, currentHP = 1,
                       timestamp = 1000 + id } }
        end,
        GetRecapMaxHealth = function() return 100 end,
    })
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)

    local texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:find("No data yet", 1, true) == nil,
        "the Deaths cell still ran the spell path")
    assertTrue(texts:find("Spell breakdown", 1, true) == nil,
        "a death has no spells and must not claim to")
end)

test("Tooltip: a Deaths cell shows one line per death, newest first", function()
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function(id)
            return { { spellId = 1, spellName = "X", amount = 1, currentHP = 1,
                       timestamp = id } }
        end,
        GetRecapMaxHealth = function() return 100 end,
    })
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)

    -- The times sit in the carrier's AMOUNT slot, so they line up in a column
    -- instead of ragging against labels of two lengths.
    local slots = {}
    for _, line in ipairs(spellLines(inst)) do slots[#slots + 1] = line.amount:GetText() end
    local joined = table.concat(slots, "\n")
    for _, id in ipairs({ 29, 28, 27 }) do
        local clock = inst.mocks.date("%H:%M:%S", id)
        assertTrue(joined:find(clock, 1, true) ~= nil,
            "the death at " .. clock .. " is missing from the cell tooltip")
    end
    assertEqual(slots[1], inst.mocks.date("%H:%M:%S", 29), "newest first")
end)

--- "Take this field OFF the event", which `nil` cannot say: a nil in a table
--- literal is a key that was never written, so `pairs` never sees it and the
--- override silently does nothing. Half of these cases are about a field the
--- client did NOT send, so the absence has to be expressible.
local ABSENT = {}

--- A recap whose killing blow names a caster and a spell.
local function killerRecap(overrides)
    return {
        HasRecapEvents = function() return true end,
        GetRecapEvents = function(id)
            local newest = { spellId = 1, spellName = "Sulfuras Smash",
                             sourceName = "Ragnaros", amount = 1, currentHP = 1,
                             timestamp = id }
            for k, v in pairs(overrides or {}) do
                if v == ABSENT then v = nil end
                newest[k] = v
            end
            -- Two events, so the case also pins that it is the NEWEST one that
            -- gets read: element two is a hit that did not kill anybody.
            return { newest, { spellId = 2, spellName = "Living Meteor",
                               sourceName = "Sulfuron Harbinger", amount = 1,
                               currentHP = 50, timestamp = id - 4 } }
        end,
        GetRecapMaxHealth = function() return 100 end,
    }
end

test("Tooltip: the death line ships naming the KILLER and not the spell", function()
    -- The split a death list is actually read for. "Death 3" alone says nothing
    -- the reader did not already know -- the count is in the cell they hovered to
    -- get here -- and the caster closes that. The spell is the longest thing on
    -- the line, the half most often absent, and it answers a question a reader has
    -- after clicking into the recap rather than while scanning the list.
    -- red under: shipping both on, which is what this shipped as first.
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap(killerRecap())
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)

    local shipped = table.concat(lineTexts(inst), "\n")
    assertTrue(shipped:find("Death 3 | Ragnaros", 1, true) ~= nil,
        "the shipped death line does not name the killer")
    assertTrue(shipped:find("Sulfuras Smash", 1, true) == nil,
        "the spell is drawn on a fresh profile; it ships off")
end)

test("Tooltip: a death line names who and what landed the killing blow", function()
    -- "Death 3 | Ragnaros | Sulfuras Smash". The recap's newest event IS the
    -- killing blow -- the array arrives newest first -- which is the same fact
    -- the timestamp is read off one line above.
    -- red under: reading events[#events], or dropping either half of the label.
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap(killerRecap())
    -- Asked for explicitly: the spell half ships OFF, and this case is about what
    -- the line draws when both are on rather than about what a fresh profile does.
    inst.NS.Database.GetWindows()[1].tooltip.showDeathSpell = true
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)

    local texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:find("Death 3 | Ragnaros | Sulfuras Smash", 1, true) ~= nil,
        "the death line did not name the killing blow")
    assertTrue(texts:find("Living Meteor", 1, true) == nil,
        "an earlier event was read as the killing blow")
end)

test("Tooltip: either half of a death line can be switched off on its own", function()
    -- Who killed me is a positioning question and what killed me is a cooldown
    -- question, which is why they are two settings and not one.
    -- red under: one switch governing both, or a separator left behind by the
    -- half that was turned off.
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap(killerRecap())

    local window = inst.NS.Database.GetWindows()[1]
    window.tooltip.showDeathSpell  = true          -- ships off; this case needs both live
    window.tooltip.showDeathCaster = false
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)
    local texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:find("Death 3 | Sulfuras Smash", 1, true) ~= nil,
        "the spell did not survive the caster being switched off")
    assertTrue(texts:find("Ragnaros", 1, true) == nil, "the caster was still drawn")

    window.tooltip.showDeathCaster = true
    window.tooltip.showDeathSpell  = false
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)
    texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:find("Death 3 | Ragnaros", 1, true) ~= nil,
        "the caster did not survive the spell being switched off")
    assertTrue(texts:find("Sulfuras Smash", 1, true) == nil, "the spell was still drawn")
end)

test("Tooltip: a death with nothing to name is still a numbered death", function()
    -- An environmental kill sets `hideCaster` and a melee swing has no spell name
    -- at all. Neither is a failure and neither may take the line down with it --
    -- what is missing is simply not drawn.
    -- red under: printing "nil", a dangling separator, or skipping the line.
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap(killerRecap({
        hideCaster = true, spellName = ABSENT, spellId = ABSENT,
        event = "ENVIRONMENTAL_DAMAGE",
    }))
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)

    local texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:find("Death 3", 1, true) ~= nil, "the death line went missing")
    assertTrue(texts:find("Death 3 |", 1, true) == nil, "a separator was left behind")
    assertTrue(texts:find("nil", 1, true) == nil, "a missing name rendered as 'nil'")
end)

test("Tooltip: a melee killing blow is named Melee rather than left blank", function()
    -- The same call Blizzard's own recap makes, and the same one eventColumns
    -- makes one screen down: a swing has no spell at all, and "#?" reads as a bug
    -- in the addon rather than as a melee hit.
    -- red under: falling through to the spell-id placeholder in a one-line summary.
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap(killerRecap({
        spellName = ABSENT, spellId = ABSENT, event = "SWING_DAMAGE",
    }))
    inst.NS.Database.GetWindows()[1].tooltip.showDeathSpell = true
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)

    local texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:find("Death 3 | Ragnaros | Melee", 1, true) ~= nil,
        "a melee killing blow was not named")
end)

test("Tooltip: a secret caster or spell name is left off rather than joined", function()
    -- Both are resolved off ids the client may hand back SECRET, and the label is
    -- built with `..`. So everything goes through plainWord on the way out and a
    -- name that cannot be read is simply absent -- "not available" and "secret
    -- right now" are the same thing to a reader.
    -- red under: concatenating a secret name into the line, which raises on a
    -- coalesced refresh ticker rather than in front of anybody.
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap(killerRecap({
        sourceName = inst.mocks.secret("Ragnaros"),
        spellName  = inst.mocks.secret("Sulfuras Smash"),
    }))
    inst.mocks.setRestricted(true)

    local ok = pcall(function()
        inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)
    end)
    assertTrue(ok, "joining a secret name raised")

    local texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:find("Death 3", 1, true) ~= nil, "the death line went missing")
    assertTrue(texts:find("Death 3 |", 1, true) == nil, "a separator was left behind")
end)

test("Tooltip: a Deaths cell still says a click opens the list", function()
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function() return { { spellId = 1, timestamp = 5 } } end,
    })
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)
    local texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:lower():find("click", 1, true) ~= nil)
end)

test("Tooltip: a cell for a player who has NOT died is unchanged", function()
    -- The Deaths column with a zero in it, and every other column, must keep
    -- exactly the tooltip they have.
    local inst, cfg, anchor = bench()
    local row = { guid = ALPHA, name = "Alpha", classFilename = "MAGE",
                  values = { DamageDone = { total = 100, maxAmount = 100 } } }
    inst.NS.Tooltip:CellTooltip(row, "DamageDone", anchor, cfg)
    local texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:find("Spell breakdown", 1, true) ~= nil,
        "an ordinary cell lost its spell breakdown")
end)

test("Tooltip: the death breakdown gets the same gap and caption every section has", function()
    -- The header sat flush against the first bar, which no other tooltip in the
    -- addon does — a spell breakdown puts a paragraph gap and a caption between
    -- the two, and the death list has to read the same way or it looks like a
    -- different addon drew it.
    -- red under: the death branch going straight from AddDoubleLine to drawLine.
    local inst, cfg, anchor, row = deathBench()
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local texts = lineTexts(inst)
    assertTrue((texts[2] or ""):find("%S") == nil,
        "line 2 must be the section gap, got " .. tostring(texts[2]))
    assertTrue((texts[3] or "") ~= "", "line 3 must be the caption")
    -- and the first event carrier therefore starts at line 4, exactly where a
    -- spell line does.
    local byIndex = tooltipLines(inst)
    assertTrue(byIndex[1] == nil and byIndex[2] == nil and byIndex[3] == nil,
        "an event carrier landed on the header, the gap or the caption")
    assertTrue(byIndex[4] ~= nil, "the first event should sit on line 4")
end)


-- ---------------------------------------------------------------------------
-- The event tooltip's columns
-- ---------------------------------------------------------------------------
--
-- One string held the time, the spell, the caster and the overkill, so a long
-- name pushed the numbers off the right edge and the killing blow rendered as
-- "355.8Kove…37.3%". Four slots now, each a reservation the engine clips
-- against — never a truncation this code performs, because a spell name and a
-- caster name can both be secret and cutting one up is inspecting it.

test("Tooltip: an event's time, spell and caster are three separate slots", function()
    -- red under: one composed caption in the label slot.
    local inst, cfg, anchor, row = deathBench{ lastSource = "Merektha" }
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local last = spellLines(inst)[2]
    assertEqual(last.time:GetText(), "-0.0s")
    assertEqual(last.label:GetText(), "Volley")
    assertEqual(last.caster:GetText(), "Merektha")
end)

test("Tooltip: each slot has a reserved width, so a long name cannot push the numbers off", function()
    -- The widths are fixed and the engine clips into them. Measuring the names
    -- to size the columns is what rule R3 forbids — a caption is secret mid-pull.
    local inst, cfg, anchor, row = deathBench{
        lastName = "Ritual of the Fang of the Loa Speaker Nanea and Friends",
        lastSource = "High Channeler Ryvati of the Bleeding Hollow",
    }
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local first, second = spellLines(inst)[1], spellLines(inst)[2]
    assertTrue(second.label:GetWidth() > 0, "the spell slot has no reserved width")
    assertEqual(first.label:GetWidth(), second.label:GetWidth(),
        "a longer name widened its column instead of being clipped into it")
    assertEqual(first.caster:GetWidth(), second.caster:GetWidth())
end)

test("Tooltip: the amount slot carries the damage ALONE", function()
    -- Overkill is dropped from this surface entirely. It is the part of a
    -- killing blow that exceeded health the player no longer had, it only ever
    -- appears on one line, and it was colliding with the HP percentage.
    -- red under: appending an overkill clause anywhere on the line.
    local inst, cfg, anchor, row = deathBench()
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local texts = table.concat(lineTexts(inst), "\n")
    for _, line in ipairs(spellLines(inst)) do
        texts = texts .. "\n" .. line.amount:GetText() .. "\n" .. line.label:GetText()
    end
    assertTrue(texts:lower():find("overkill", 1, true) == nil,
        "overkill is still on the death tooltip")
end)

test("Tooltip: a spell line gets its slots BACK after an event line used them", function()
    -- THE POOL HAZARD. A carrier is keyed by tooltip line index, so line 4 of
    -- this hover is the frame that drew line 4 of the last one. An event line
    -- narrows the label and shows two extra slots; a spell line after it must
    -- not inherit either.
    -- red under: laying the columns out once at creation instead of per draw.
    local inst, cfg, anchor, row = deathBench()
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
    local eventWidth = spellLines(inst)[1].label:GetWidth()

    inst.NS.Tooltip:CellTooltip(
        { guid = ALPHA, name = "Alpha", classFilename = "MAGE",
          values = { DamageDone = { total = 100, maxAmount = 100 } } },
        "DamageDone", anchor, cfg)

    local spell = spellLines(inst)[1]
    assertTrue(spell ~= nil, "no spell line was drawn")
    assertEqual(spell.time:IsShown(), false, "a spell line kept the event's time slot")
    assertEqual(spell.caster:IsShown(), false, "a spell line kept the event's caster slot")
    assertTrue(spell.label:GetWidth() ~= eventWidth,
        "a spell line inherited the event line's narrowed name column")
end)

test("Tooltip: an event with no caster leaves that column empty, not absent", function()
    -- The columns must line up down the whole tooltip; a missing caster that
    -- collapsed its slot would shift every column on that row.
    local inst, cfg, anchor, row = deathBench{ hideCaster = true }
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local last = spellLines(inst)[2]
    assertEqual(last.caster:GetText(), "")
    assertTrue(last.caster:IsShown(), "the empty caster slot was hidden, moving the row")
end)

test("Tooltip: the death tooltip reserves a WIDER minimum than a spell breakdown", function()
    -- Two more columns have to be paid for, or they overlap the numbers.
    local inst, cfg, anchor, row = deathBench()
    local parts = inst.NS.Tooltip.WidthParts()
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
    assertTrue(inst.mocks.GameTooltip.__minWidth > parts.total,
        "the death tooltip is no wider than a spell one, so its columns collide")
end)

test("Tooltip: a Deaths cell's rows carry a FULL bar, not an empty one", function()
    -- An empty bar behind every line reads as a value that failed to load. A
    -- death is not a quantity, so the bar is the row's backing rather than a
    -- measure — full, from plain ones, the same way a death row's cell in the
    -- drill-down does it.
    -- red under: passing nil for value and max, which draws 0 of 1.
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function(id) return { { spellId = 1, timestamp = id } } end,
    })
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)

    for _, line in ipairs(spellLines(inst)) do
        local mn, mx = line.bar:GetMinMaxValues()
        assertEqual(mn, 0)
        assertEqual(mx, 1)
        assertEqual(line.bar:GetValue(), 1, "a death line's bar drew empty")
    end
end)

test("Tooltip: every death line in a Deaths cell carries the skull icon", function()
    -- The line had no icon at all, so it sat a glyph-width left of every other
    -- tooltip in the addon and read as a missing texture.
    -- red under: adding the line without a |T…|t head.
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function(id) return { { spellId = 1, timestamp = id } } end,
    })
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)

    local texts = table.concat(lineTexts(inst), "\n")
    assertTrue(texts:find("|T237275:", 1, true) ~= nil,
        "the skull icon is missing from the death lines")
end)

test("Tooltip: a Deaths cell's time sits at the right edge, where a share does", function()
    -- It was in the AMOUNT slot, which is inset by the width of the share slot
    -- beside it — so the times floated a column short of the bar's right edge
    -- while every other tooltip's rightmost figure sits against it.
    -- red under: leaving the clock in the amount slot with the share slot shown.
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function(id) return { { spellId = 1, timestamp = id } } end,
    })
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)

    local line = spellLines(inst)[1]
    assertEqual(line.share:IsShown(), false,
        "the empty share slot is still holding the time away from the edge")
    local _, relTo, relPoint = line.amount:GetPoint(1)
    assertTrue(relTo == line and relPoint == "RIGHT",
        "the time must be anchored to the carrier's own right edge")
end)

test("Tooltip: the caster column's CAP is narrower than the spell column's", function()
    -- Both columns size to their content now, so which is wider on any given
    -- hover is up to the data. What still holds is the ceiling each may reach: a
    -- caster name is shorter than a spell name in almost every case, and the
    -- reservation reflects that. Forced onto the reserved path with secret
    -- captions, which is also the mid-pull case.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return { { spellId = 1, spellName = inst.mocks.secret("X"),
                       sourceName = inst.mocks.secret("Y"),
                       amount = inst.mocks.secret(1),
                       currentHP = inst.mocks.secret(1), timestamp = 1000 } }
        end,
        GetRecapMaxHealth = function() return inst.mocks.secret(1000) end,
    })
    inst.mocks.setSecretsAccessible(false)
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local line = spellLines(inst)[1]
    assertTrue(line.caster:GetWidth() < line.label:GetWidth(),
        "the caster column's cap is no narrower than the spell column's")
end)

test("Tooltip: both name columns refuse to wrap, so the engine clips them", function()
    -- This is the whole truncation story. A spell name and a caster name can
    -- both be secret, so neither may be cut up here — `string.sub` on a secret
    -- raises, and measuring one to decide where to cut is an inspection. A fixed
    -- width with wrapping off leaves the clipping to the engine, which is
    -- allowed to look.
    -- red under: dropping SetWordWrap(false), which makes a long name wrap onto
    -- a second line and push every row below it down.
    local inst, cfg, anchor, row = deathBench{
        lastName = "Ritual of the Fang of the Loa Speaker Nanea",
        lastSource = "High Channeler Ryvati of the Bleeding Hollow",
    }
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local line = spellLines(inst)[2]
    assertEqual(line.label.__wordWrap, false, "the spell column may wrap")
    assertEqual(line.caster.__wordWrap, false, "the caster column may wrap")
end)

test("Tooltip: a melee swing reads as Melee, not as #?", function()
    -- A swing carries NO spellId and no spellName — Blizzard's own recap draws
    -- it as "Melee" with the weapon icon. Ours fell all the way through to the
    -- "the client could not name this" placeholder and printed "#?", which reads
    -- as a bug in the addon rather than as a melee hit.
    -- red under: keying the fallback on the spell id alone.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return { { event = "SWING_DAMAGE", amount = 115666, currentHP = 200,
                       sourceName = "Ruthless Totemcaller", timestamp = 1000 } }
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local line = spellLines(inst)[1]
    assertEqual(line.label:GetText(), "Melee")
    assertTrue(table.concat(lineTexts(inst), "\n"):find("|T135274:", 1, true) ~= nil,
        "a swing must wear the weapon icon")
end)

test("Tooltip: a heal with no spell id reads as Heal", function()
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return { { event = "SPELL_PERIODIC_HEAL", amount = 500,
                       currentHP = 800, timestamp = 1000 } }
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
    assertEqual(spellLines(inst)[1].label:GetText(), "Heal")
end)

test("Tooltip: an event with an id the client cannot name still shows the id", function()
    -- The placeholder still has a job — it just is not the melee case.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return { { spellId = 999001, event = "SPELL_DAMAGE", amount = 1,
                       currentHP = 1, timestamp = 1000 } }
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })
    inst.mocks.__spells = setmetatable({}, { __index = function() return nil end })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
    assertTrue(spellLines(inst)[1].label:GetText():find("999001", 1, true) ~= nil)
end)

test("Tooltip: a SECRET event type is not compared", function()
    -- The melee and heal fallbacks both test `event.event`, which comes off a
    -- recap like everything else here.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return { { event = inst.mocks.secret("SWING_DAMAGE"),
                       amount = inst.mocks.secret(1),
                       currentHP = inst.mocks.secret(1), timestamp = 1000 } }
        end,
        GetRecapMaxHealth = function() return inst.mocks.secret(1000) end,
    })
    inst.mocks.setSecretsAccessible(false)
    assertTrue(pcall(function() inst.NS.Tooltip:SpellTooltip(row, anchor, cfg) end),
        "a secret event type raised")
end)

test("Tooltip: the time column is sized to the widest time in THIS recap", function()
    -- It was reserved for "-100.0s" whatever the recap held, so a list whose
    -- longest was "-81.2s" carried a character of slack down its left edge. The
    -- offsets are numbers this addon computed, so measuring them is legal —
    -- unlike the names beside them.
    -- red under: a constant reservation.
    local function widthFor(events)
        local inst, cfg, anchor, row = deathBench()
        inst.mocks.setDeathRecap({
            HasRecapEvents = function() return true end,
            GetRecapEvents = function() return events end,
            GetRecapMaxHealth = function() return 1000 end,
        })
        inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
        return spellLines(inst)[1].time:GetWidth()
    end

    local narrow = widthFor({ { spellId = 1, currentHP = 1, timestamp = 1000 },
                              { spellId = 1, currentHP = 1, timestamp = 998 } })
    local wide   = widthFor({ { spellId = 1, currentHP = 1, timestamp = 1000 },
                              { spellId = 1, currentHP = 1, timestamp = 100 } })
    assertTrue(wide > narrow,
        "a recap spanning 900s must reserve more room than one spanning 2s")
end)

test("Tooltip: the name columns shrink to the names actually in this recap", function()
    -- Reserved at 22 and 16 characters whatever the recap held, so a list of
    -- "Melee" and "Cryo Surge" carried half a column of slack while the numbers
    -- went short. Measured when every name is readable, which out of combat is
    -- all of them — and that is when a death recap is read.
    -- red under: a constant reservation.
    local function widths(spell, caster)
        local inst, cfg, anchor, row = deathBench()
        inst.mocks.setDeathRecap({
            HasRecapEvents = function() return true end,
            GetRecapEvents = function()
                return { { spellId = 1, spellName = spell, sourceName = caster,
                           amount = 1, currentHP = 1, timestamp = 1000 } }
            end,
            GetRecapMaxHealth = function() return 1000 end,
        })
        inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
        local line = spellLines(inst)[1]
        return line.label:GetWidth(), line.caster:GetWidth()
    end

    local shortSpell, shortCaster = widths("Melee", "Frostfang")
    local longSpell,  longCaster  = widths("Rumbling Ward of the Deep", "Avatar of Determination")
    assertTrue(longSpell > shortSpell, "the spell column did not shrink to its content")
    assertTrue(longCaster > shortCaster, "the caster column did not shrink to its content")
end)

test("Tooltip: a name column never grows past its character cap", function()
    -- Shrinking to fit must not become growing to fit: a boss ability with a
    -- forty-character name would push the numbers off the edge, which is the
    -- thing the reservation was there to stop.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return { { spellId = 1, amount = 1, currentHP = 1, timestamp = 1000,
                       spellName = string.rep("W", 80), sourceName = string.rep("W", 80) } }
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local capped = spellLines(inst)[1]
    local parts = inst.NS.Tooltip.WidthParts()
    assertTrue(capped.label:GetWidth() < parts.total,
        "an 80-character spell name took the whole tooltip")
end)

test("Tooltip: a SECRET name falls back to the fixed reservation", function()
    -- Measuring the widest of several is a comparison, and comparing a secret
    -- raises. Mid-pull the captions are secret, so the columns go back to being
    -- reserved rather than measured — the same trade applyMinimumWidth records.
    -- red under: measuring without asking whether the name may be read.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return { { spellId = 1, spellName = inst.mocks.secret("Melee"),
                       sourceName = inst.mocks.secret("Frostfang"),
                       amount = inst.mocks.secret(1),
                       currentHP = inst.mocks.secret(1), timestamp = 1000 } }
        end,
        GetRecapMaxHealth = function() return inst.mocks.secret(1000) end,
    })
    inst.mocks.setSecretsAccessible(false)

    assertTrue(pcall(function() inst.NS.Tooltip:SpellTooltip(row, anchor, cfg) end),
        "measuring a secret name raised")
    local line = spellLines(inst)[1]
    assertTrue(line.label:GetWidth() > 0, "the column lost its reservation entirely")
end)


-- ---------------------------------------------------------------------------
-- Characterization: the three warned functions (issue #40)
-- ---------------------------------------------------------------------------
--
-- `eventColumns`, `drawDeathEvents` and `Tooltip:CellTooltip` are all above the
-- complexity ceiling and are queued for a split — collect / measure / draw, in
-- drawDeathEvents' case. Everything below pins behaviour that has never been
-- asserted anywhere and that a seam cut through the middle of these functions
-- could take with it: the arms of the naming chain nothing reached, the four
-- refusals, the collect ceiling, and the all-or-nothing measurement rule the
-- issue names under "what must not change".
--
-- Every case here was written and run against the UNREFACTORED code, which is
-- the only order in which a characterization test proves anything
-- (performance-§11).

test("Tooltip: an event with no id and no name reads as #? under the question mark", function()
    -- The LAST arm of eventColumns' naming chain, and the only one nothing
    -- reached: not a swing, not a heal, and no spell id to fall back on either.
    -- The explicit nil branch is there because string.format("%s", nil) raises in
    -- Lua 5.1, so a refactor that "simplifies" it to one format call takes the
    -- whole tooltip down on an event the client declined to name.
    -- red under: formatting the nil id, or dropping the fallback icon.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return { { event = "SPELL_DAMAGE", amount = 1, currentHP = 1,
                       timestamp = 1000 } }
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    assertEqual(spellLines(inst)[1].label:GetText(), "#?")
    -- No id means no texture lookup either, so the line heads with the addon's
    -- own fallback rather than with an empty `|T|t`.
    assertTrue(table.concat(lineTexts(inst), "\n"):find(
        "|T" .. [[Interface\ICONS\INV_Misc_QuestionMark]] .. ":14:14:0:0|t", 1, true) ~= nil,
        "an unnamed event lost its fallback icon")
end)

test("Tooltip: a DIRECT heal with no spell id reads as Heal too", function()
    -- The heal arm tests two event types and the suite only ever reached
    -- SPELL_PERIODIC_HEAL. A refactor that rewrites the chain as a lookup table
    -- is exactly the kind that keeps one of a pair and loses the other.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return { { event = "SPELL_HEAL", amount = 500, currentHP = 800,
                       timestamp = 1000 } }
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)
    assertEqual(spellLines(inst)[1].label:GetText(), "Heal")
end)

test("Tooltip: an event AFTER the moment of death keeps the sign OFF", function()
    -- The positive arm of the time column. Element one is the killing blow and
    -- the client sends the array newest first, so every offset is normally zero
    -- or negative — but the sign is SPELLED rather than left to the subtraction,
    -- and that is only visible on an offset the spelling has to leave alone.
    -- red under: string.format("-%.1fs", math.abs(off)) for every offset, which
    -- renders a later event as though it preceded the death.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return { { spellId = 1, spellName = "Blow", amount = 1,
                       currentHP = 1, timestamp = 1000 },
                     { spellId = 2, spellName = "After", amount = 1,
                       currentHP = 1, timestamp = 1004 } }
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    -- The draw runs backwards, so the second element is the FIRST line.
    local first = spellLines(inst)[1]
    assertEqual(first.label:GetText(), "After", "the draw stopped running backwards")
    assertEqual(first.time:GetText(), "4.0s")
end)

test("Tooltip: a refused offset empties the time slot and reserves the column", function()
    -- Two facts in one, because they are the same arm seen from both ends.
    -- eventOffset refuses the subtraction while the timestamps are secret, so
    -- `secondsBefore` is nil and the time text is EXACTLY empty — never "0.0s",
    -- which would claim every event landed at the moment of death. And `widest`
    -- is then never set, so the column falls back to the "-9.9s" reservation
    -- rather than collapsing to nothing.
    -- red under: defaulting the offset to zero, or sizing the column from a nil.
    local function timeSlot(events, secretsOff)
        local inst, cfg, anchor, row = deathBench()
        inst.mocks.setDeathRecap({
            HasRecapEvents = function() return true end,
            GetRecapEvents = function() return events(inst) end,
            GetRecapMaxHealth = function() return 1000 end,
        })
        if secretsOff then inst.mocks.setSecretsAccessible(false) end
        assertTrue(pcall(function() inst.NS.Tooltip:SpellTooltip(row, anchor, cfg) end),
            "a refused offset raised")
        return spellLines(inst)[1]
    end

    -- A recap spanning 900 seconds measures "-900.0s", which is wider than the
    -- constant floor — so the fallback below is falsifiable.
    local measured = timeSlot(function()
        return { { spellId = 1, amount = 1, currentHP = 1, timestamp = 1000 },
                 { spellId = 1, amount = 1, currentHP = 1, timestamp = 100 } }
    end)
    local refused = timeSlot(function(inst)
        return { { spellId = 1, amount = 1, currentHP = 1,
                   timestamp = inst.mocks.secret(1000) },
                 { spellId = 1, amount = 1, currentHP = 1,
                   timestamp = inst.mocks.secret(100) } }
    end, true)

    assertEqual(refused.time:GetText(), "",
        "a refused subtraction must render nothing, never a figure")
    assertTrue(refused.time:IsShown(), "the time column collapsed instead of reserving")
    assertTrue(refused.time:GetWidth() > 0, "the time column lost its reservation")
    assertTrue(refused.time:GetWidth() < measured.time:GetWidth(),
        "the refused column was not sized from the constant floor")
end)

test("Tooltip: a recap whose events are not an array says so and draws nothing", function()
    -- The first of drawDeathEvents' four refusals. The client is allowed to hand
    -- back something that is not an array and modules/Compat.lua passes it
    -- through untouched on purpose, so the type test here is the only thing
    -- between it and an iteration.
    -- red under: hoisting the type test into a collect helper that is called
    -- after the array has already been indexed.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function() return "not an array" end,
    })
    assertTrue(pcall(function() inst.NS.Tooltip:SpellTooltip(row, anchor, cfg) end),
        "a non-array recap raised")

    assertEqual(#spellLines(inst), 0, "a carrier was drawn for a recap with no events")
    assertTrue(table.concat(lineTexts(inst), "\n"):find(
        "No recap stored for this death", 1, true) ~= nil,
        "the refusal must say so rather than leave an empty frame")
end)

test("Tooltip: an EMPTY event array is a refusal, not an empty list", function()
    -- The `total == 0` arm, which is the one a split into collect/measure/draw
    -- has to keep on the DRAW side: an ordered array of length zero must still
    -- reach the caller as `false`, or the death gets a header, a gap, a caption
    -- and then nothing at all — the empty tooltip the sentence exists to avoid.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function() return {} end,
    })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    assertEqual(#spellLines(inst), 0)
    assertTrue(table.concat(lineTexts(inst), "\n"):find(
        "No recap stored for this death", 1, true) ~= nil,
        "an empty array drew a headless section instead of the sentence")
end)

test("Tooltip: a SECRET event array is refused whole, never indexed", function()
    -- The CanAccessTable guard. Indexing a secret table RAISES — the mock traps
    -- it, exactly as the client does — so this is not a tidiness check: without
    -- the gate the walk below it takes the tooltip down mid-pull.
    -- red under: moving the guard inside the SafeIterate callback, where the
    -- first index has already happened.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return inst.mocks.secretTable({
                { spellId = 1, spellName = "Volley", amount = 1,
                  currentHP = 1, timestamp = 1000 },
            })
        end,
        GetRecapMaxHealth = function() return inst.mocks.secret(1000) end,
    })
    inst.mocks.setSecretsAccessible(false)

    assertTrue(pcall(function() inst.NS.Tooltip:SpellTooltip(row, anchor, cfg) end),
        "the secret event array was indexed")
    assertEqual(#spellLines(inst), 0)
    assertTrue(table.concat(lineTexts(inst), "\n"):find(
        "No recap stored for this death", 1, true) ~= nil)
end)

test("Tooltip: an entry that is not a table is skipped, and the rest still draw", function()
    -- The per-entry gate inside the collect. SafeIterate stops at the first NIL
    -- and at nothing else, so a junk entry mid-array is reached and has to be
    -- stepped over rather than taken as the end of the list.
    -- red under: returning false from the callback on a bad entry, which would
    -- stop the walk and silently drop every event behind it.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return { { spellId = 1, spellName = "Newest", amount = 1,
                       currentHP = 1, timestamp = 1000 },
                     "junk",
                     { spellId = 2, spellName = "Oldest", amount = 1,
                       currentHP = 1, timestamp = 900 } }
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local lines = spellLines(inst)
    assertEqual(#lines, 2, "the junk entry ended the walk instead of being skipped")
    assertEqual(lines[1].label:GetText(), "Oldest", "oldest still reads first")
    assertEqual(lines[2].label:GetText(), "Newest")
end)

test("Tooltip: the collect stops at 64 events, keeping the NEWEST of them", function()
    -- COLLECT_LIMIT, which nothing reached: every fixture in this file holds two
    -- events and a live recap holds ten. The ceiling is a real bound on the
    -- number of carrier frames one hover creates, and WHICH end it drops matters
    -- — the client sends newest first, so the walk keeps the events nearest the
    -- death and discards the far end of a very long pull.
    -- red under: a collect helper that walks the array without the stop, or one
    -- that reverses before capping and so keeps the OLDEST 64.
    local inst, cfg, anchor, row = deathBench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            local out = {}
            for i = 1, 70 do
                out[i] = { spellId = i, spellName = "E" .. i, amount = 1,
                           currentHP = 1, timestamp = 1000 - i }
            end
            return out
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })
    inst.NS.Tooltip:SpellTooltip(row, anchor, cfg)

    local lines = spellLines(inst)
    assertEqual(#lines, 64, "the collect ceiling moved")
    -- Drawn backwards, so the last line is element one — the killing blow — and
    -- the first line is element 64, the oldest event that survived the cap.
    assertEqual(lines[#lines].label:GetText(), "E1", "the killing blow was capped away")
    assertEqual(lines[1].label:GetText(), "E64", "the wrong end of the array was kept")
end)

test("Tooltip: ONE unreadable caption abandons the whole measurement", function()
    -- ISSUE #40's headline invariant, and the one a measure helper extracted out
    -- of this loop is most likely to lose: `namesReadable` is all-or-nothing on
    -- purpose. A column sized from the four names that happened to be readable
    -- fits four names out of ten, which is worse than one reserved for all of
    -- them — the reader cannot tell a clipped name from a short one.
    -- red under: sizing from the readable half, or breaking out of the loop on
    -- the first unreadable name (which would also skip the TIME measurement of
    -- every event behind it).
    local function spellWidth(secondName)
        local inst, cfg, anchor, row = deathBench()
        inst.mocks.setDeathRecap({
            HasRecapEvents = function() return true end,
            GetRecapEvents = function()
                return { { spellId = 1, spellName = "Ka", sourceName = "Kb",
                           amount = 1, currentHP = 1, timestamp = 1000 },
                         { spellId = 2, spellName = secondName(inst),
                           sourceName = "Kb", amount = 1, currentHP = 1,
                           timestamp = 900 } }
            end,
            GetRecapMaxHealth = function() return 1000 end,
        })
        inst.mocks.setSecretsAccessible(false)
        assertTrue(pcall(function() inst.NS.Tooltip:SpellTooltip(row, anchor, cfg) end),
            "a mixed-readability recap raised")
        return spellLines(inst)[1].label:GetWidth()
    end

    local allReadable = spellWidth(function() return "Kc" end)
    local oneSecret   = spellWidth(function(inst) return inst.mocks.secret("Kc") end)
    assertTrue(oneSecret > allReadable,
        "one secret caption sized the column from the readable half")
end)

test("modules/Tooltip.lua never applies `#` to a recap's event array", function()
    -- Rule R1 on the death path, stated as a source check because the failure it
    -- guards cannot be provoked from outside: `#` on a secret table raises, and
    -- the recap array is exactly the table this file is handed by the client.
    -- `#ordered` is fine and deliberately not matched — that is the plain array
    -- this file built for itself, which is the whole reason the collect exists.
    -- red under: a collect helper that measures `events` before walking it.
    local fh = assert(io.open(T.root .. "/modules/Tooltip.lua", "r"))
    local n, offenders, sawSafeIterate = 0, {}, false
    for line in fh:lines() do
        n = n + 1
        if not line:match("^%s*%-%-") then
            local code = line:gsub("%s%-%-.*$", "")
            if code:find("SafeIterate", 1, true) then sawSafeIterate = true end
            if code:find("#%s*events") or code:find("#%s*recap%.events") then
                offenders[#offenders + 1] = "modules/Tooltip.lua:" .. n
            end
        end
    end
    fh:close()
    assertTrue(sawSafeIterate, "the event walk must go through NS.Secrets.SafeIterate")
    assertEqual(#offenders, 0, table.concat(offenders, ", "))
end)

test("Tooltip: a stat key the catalog does not know heads with the key itself", function()
    -- CellTooltip's header arm nothing reached. `Const.STAT_BY_KEY` is a lookup
    -- that can miss — a column added to a saved profile and later renamed leaves
    -- exactly this — and the fallback is the raw key rather than a blank right
    -- half, so the tooltip still says which column it is the breakdown of.
    -- red under: `L[stat.label]` without the guard, which raises on the nil.
    local inst, cfg, anchor = bench()
    assertTrue(pcall(function()
        inst.NS.Tooltip:CellTooltip(makeRow(), "NotAStatKey", anchor, cfg)
    end), "an unknown stat key raised")
    assertEqual(inst.mocks.GameTooltip.__lines[1].right, "NotAStatKey")
end)

test("Tooltip: a Deaths cell reads deathTimeFormat off the WINDOW's text block", function()
    -- The setting lives at `window.text.deathTimeFormat` (settings/Schema.lua)
    -- and the tooltip config block has no copy of it, so CellTooltip's two-term
    -- `or` is the ONLY thing that carries the player's choice to the formatter.
    -- Nothing asserted it, and a refactor that reads only `config` would leave
    -- the option in the panel with no effect at all.
    -- red under: dropping the window.text fallback.
    local inst, cfg, anchor = bench()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function(id) return { { spellId = 1, timestamp = id } } end,
        GetRecapMaxHealth = function() return 100 end,
    })
    local window = inst.NS.Database.GetWindows()[1]
    window.text.deathTimeFormat = "ago"
    inst.NS.Tooltip:CellTooltip(deadGridRow(), "Deaths", anchor, cfg)

    local slots = {}
    for _, line in ipairs(spellLines(inst)) do slots[#slots + 1] = line.amount:GetText() end
    local joined = table.concat(slots, "\n")
    assertTrue(joined:find("ago", 1, true) ~= nil,
        "the window's timestamp style never reached the formatter, got " .. joined)
    assertTrue(joined:find(inst.mocks.date("%H:%M:%S", 29), 1, true) == nil,
        "the clock was drawn although the window asked for elapsed time")
end)
