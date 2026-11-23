-- tests/test_aggregator_certain.lua — only what is certain mid-fight (owner ruling R4).
--
-- While the meter's identities are secret, the identity build correlated every column onto
-- the sort column's rows by class, spec and "is it me", and refused only a key that some
-- column listed twice. That proof fails in ordinary play (the 2026-11-23 critic, C1): a player
-- leaves mid-fight, the roster is half built, the remembered members are incomplete, or an
-- ungrouped ally or an unfolded pet wears a grouped player's class. In each case a column
-- names the key once and the number lands on the wrong player's row, with no header warning.
--
-- The owner's rule (R4, 2026-11-23, Retail): a cell is filled only for the SORTED column, on
-- every row, because that row IS that source; and on the LOCAL player's row, whose
-- `isLocalPlayer` is plain. Every other cell of another player stays blank until combat ends,
-- and the existing header note counts those rows. Out of combat the GUID join runs and nothing
-- changes.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertNil   = T.assertNil

local CURRENT = 1
local OVERALL = 0

local ALPHA = "Player-1-0000000A"
local BETA  = "Player-1-0000000B"
local GAMMA = "Player-1-0000000C"
local STRANGER = "Player-1-0000000F"

local GROUP = {
    { guid = ALPHA, name = "Alpha", class = "PALADIN", role = "TANK"    },
    { guid = BETA,  name = "Beta",  class = "PRIEST",  role = "HEALER"  },
    { guid = GAMMA, name = "Gamma", class = "ROGUE",   role = "DAMAGER" },
}

local function src(guid, total, opts)
    opts = opts or {}
    return {
        sourceGUID        = guid,
        name              = opts.name or guid,
        classFilename     = opts.class or "MAGE",
        specIconID        = opts.specIconID,
        isLocalPlayer     = opts.localPlayer,
        totalAmount       = total,
        amountPerSecond   = opts.rate,
        deathRecapID      = opts.recapID,
        sourceDisplayType = opts.displayType,
    }
end

local function makeWindow(columns, sortColumn, sessionType)
    local list = {}
    for _, key in ipairs(columns) do list[#list + 1] = { stat = key, width = 80, showBar = true } end
    return {
        id = 1, name = "Test", columns = list, rows = {},
        data = { sessionType = sessionType or CURRENT, sortMode = "provider", sortColumn = sortColumn },
    }
end

local function restricted(group)
    local inst = T.load()
    inst.mocks.setGroup(group or GROUP)
    inst.NS.Roster.Refresh()
    inst.mocks.setRestricted(true)
    return inst
end

local function install(inst, statKey, sources, sessionType)
    inst.mocks.setSession(sessionType or CURRENT, inst.NS.Constants.STAT_BY_KEY[statKey].enumValue,
        { combatSources = sources, maxAmount = 1000 })
end

local function rowOf(rows, guid)
    for _, row in ipairs(rows) do if row.guid == guid then return row end end
    return nil
end

local function build(inst, columns, sortColumn, sessionType)
    return inst.NS.Aggregator.Build(makeWindow(columns, sortColumn, sessionType))
end

-- ── the rule ───────────────────────────────────────────────────────────────────────────────

test("Certain: another player's secondary cell is blank mid-fight, even with a unique class", function()
    -- red under: correlating by class and spec onto another player's row.
    local inst = restricted()
    install(inst, "DamageDone", { src(ALPHA, 100, { class = "PALADIN" }), src(BETA, 50, { class = "PRIEST" }) })
    install(inst, "HealingDone", { src(BETA, 500, { class = "PRIEST" }) })
    local rows = build(inst, { "DamageDone", "HealingDone" }, "DamageDone")
    assertEqual(#rows, 2)
    for _, row in ipairs(rows) do
        assertTrue(row.values.DamageDone ~= nil, "the sort column fills every row")
        assertNil(row.values.HealingDone, "another player's healing was correlated onto a row")
    end
end)

test("Certain: the local player's row fills every column", function()
    local inst = restricted()
    install(inst, "DamageDone", { src(ALPHA, 100, { class = "PALADIN", localPlayer = true }),
        src(BETA, 50, { class = "PRIEST" }) })
    install(inst, "HealingDone", { src(BETA, 500, { class = "PRIEST" }),
        src(ALPHA, 300, { class = "PALADIN", localPlayer = true, rate = 30 }) })
    local rows = build(inst, { "DamageDone", "HealingDone" }, "DamageDone")
    local me = rowOf(rows, ALPHA)
    assertTrue(me ~= nil, "the local row keeps its real GUID")
    assertEqual(inst.mocks.reveal(me.values.HealingDone.total), 300)
    assertEqual(inst.mocks.reveal(me.values.HealingDone.rate), 30)
end)

test("Certain: the local player absent from the sort column still gets a row with their cells", function()
    local inst = restricted()
    install(inst, "DamageDone", { src(BETA, 50, { class = "PRIEST" }) })
    install(inst, "HealingDone", { src(ALPHA, 300, { class = "PALADIN", localPlayer = true }) })
    local rows = build(inst, { "DamageDone", "HealingDone" }, "DamageDone")
    assertEqual(#rows, 2)
    local me = rowOf(rows, ALPHA)
    assertTrue(me ~= nil, "the local player has no row")
    assertEqual(inst.mocks.reveal(me.values.HealingDone.total), 300)
end)

test("Certain: another player absent from the sort column has no row until combat ends", function()
    -- The visible cost the owner accepted: a healer with no damage is off a Damage-sorted grid.
    local inst = restricted()
    install(inst, "DamageDone", { src(ALPHA, 100, { class = "PALADIN" }) })
    install(inst, "HealingDone", { src(BETA, 500, { class = "PRIEST" }) })
    local rows = build(inst, { "DamageDone", "HealingDone" }, "DamageDone")
    assertEqual(#rows, 1, "a row was invented from a correlated column")
end)

test("Certain: out of combat the GUID join fills every cell as before", function()
    local inst = restricted()
    inst.mocks.setRestricted(false)
    install(inst, "DamageDone", { src(ALPHA, 100, { class = "PALADIN" }), src(BETA, 50, { class = "PRIEST" }) })
    install(inst, "HealingDone", { src(BETA, 500, { class = "PRIEST" }) })
    local rows = build(inst, { "DamageDone", "HealingDone" }, "DamageDone")
    assertEqual(inst.mocks.reveal(rowOf(rows, BETA).values.HealingDone.total), 500)
end)

-- ── the four ways the old uniqueness proof failed (critic C1) ───────────────────────────────

test("Certain: a member who left mid-fight cannot lend their number to a row", function()
    -- C1.1: Gamma left; the Interrupts column still names a ROGUE once.
    local inst = restricted({ GROUP[1], GROUP[2] })
    install(inst, "DamageDone", { src(ALPHA, 100, { class = "PALADIN" }), src(STRANGER, 80, { class = "ROGUE" }) })
    install(inst, "Interrupts", { src(GAMMA, 3, { class = "ROGUE" }) })
    local rows = build(inst, { "DamageDone", "Interrupts" }, "DamageDone")
    for _, row in ipairs(rows) do assertNil(row.values.Interrupts, "a leaver's interrupts were mislabeled") end
end)

test("Certain: a half-built roster cannot make a shared class look unique", function()
    -- C1.2: the roster knows one priest; two priests appear, one per column.
    local inst = restricted({ GROUP[1], GROUP[2] })
    install(inst, "DamageDone", { src(BETA, 100, { class = "PRIEST" }) })
    install(inst, "HealingDone", { src(GAMMA, 900, { class = "PRIEST" }) })
    local rows = build(inst, { "DamageDone", "HealingDone" }, "DamageDone")
    assertEqual(#rows, 1)
    assertNil(rows[1].values.HealingDone, "the other priest's healing landed on this row")
end)

test("Certain: the Overall segment cannot join a past member onto a present one", function()
    -- C1.3: Overall holds everyone since the last reset; a remembered rogue and a present one.
    local inst = restricted()
    install(inst, "DamageDone", { src(GAMMA, 100, { class = "ROGUE" }) }, OVERALL)
    install(inst, "Interrupts", { src(STRANGER, 9, { class = "ROGUE" }) }, OVERALL)
    local rows = build(inst, { "DamageDone", "Interrupts" }, "DamageDone", OVERALL)
    for _, row in ipairs(rows) do assertNil(row.values.Interrupts, "a past member's number was joined") end
end)

test("Certain: an ungrouped ally or an unfolded pet cannot wear a grouped player's number", function()
    -- C1.4: an Ally source with the paladin's class, in a column the paladin is absent from.
    local inst = restricted()
    install(inst, "DamageDone", { src(ALPHA, 100, { class = "PALADIN" }) })
    install(inst, "HealingDone", { src(STRANGER, 700, { class = "PALADIN", displayType = inst.NS.Constants.SOURCE_DISPLAY_TYPE.Ally }) })
    local rows = build(inst, { "DamageDone", "HealingDone" }, "DamageDone")
    for _, row in ipairs(rows) do assertNil(row.values.HealingDone, "a stranger's healing was mislabeled") end
end)

-- ── the paths that read a row: deaths, the tooltip, the header note ─────────────────────────

test("Certain: another player's deaths list and recap stay empty; the local player's are kept", function()
    local inst = restricted()
    install(inst, "DamageDone", { src(ALPHA, 100, { class = "PALADIN", localPlayer = true }),
        src(BETA, 50, { class = "PRIEST" }) })
    install(inst, "Deaths", { src(BETA, 0, { class = "PRIEST", recapID = 71 }),
        src(ALPHA, 0, { class = "PALADIN", localPlayer = true, recapID = 72 }) })
    local rows = build(inst, { "DamageDone", "Deaths" }, "DamageDone")
    local other = rows[1].guid == ALPHA and rows[2] or rows[1]
    assertNil(other.deaths, "another player's death list was correlated")
    assertNil(other.deathRecapID, "another player's recap was correlated")
    assertNil(other.values.Deaths)
    local me = rowOf(rows, ALPHA)
    assertEqual(me.deathRecapID, 72)
    assertEqual(#me.deaths, 1)
end)

test("Certain: with Deaths sorted, every death is its own filled row", function()
    local inst = restricted()
    install(inst, "Deaths", { src(BETA, 0, { class = "PRIEST", recapID = 1 }),
        src(GAMMA, 0, { class = "ROGUE", recapID = 2 }) })
    install(inst, "DamageDone", { src(BETA, 50, { class = "PRIEST" }) })
    local rows = build(inst, { "Deaths", "DamageDone" }, "Deaths")
    assertEqual(#rows, 2)
    for _, row in ipairs(rows) do
        assertTrue(row.values.Deaths ~= nil, "a death row lost its own cell")
        assertNil(row.values.DamageDone, "a death row was given a correlated number")
    end
end)

test("Certain: another player's Deaths tooltip shows no correlated death mid-fight", function()
    local inst = restricted()
    install(inst, "DamageDone", { src(BETA, 50, { class = "PRIEST" }) })
    install(inst, "Deaths", { src(BETA, 0, { class = "PRIEST", recapID = 71 }) })
    local rows = build(inst, { "DamageDone", "Deaths" }, "DamageDone")
    local cfg = inst.NS.Database.GetWindows()[1]
    cfg.data.sessionType = CURRENT
    inst.mocks.GameTooltip:ClearLines()
    inst.NS.Tooltip:CellTooltip(rows[1], "Deaths", inst.mocks.__stubFrame("Frame"), cfg)
    local noData = false
    for _, line in ipairs(inst.mocks.GameTooltip.__lines) do
        if line.text == inst.NS.L["No data yet"] then noData = true end
    end
    assertTrue(noData, "the tooltip drew a death the build could not tie to this player")
end)

test("Certain: the pass counts every row whose cells wait for the end of combat", function()
    local inst = restricted()
    install(inst, "DamageDone", { src(ALPHA, 100, { class = "PALADIN", localPlayer = true }),
        src(BETA, 50, { class = "PRIEST" }), src(GAMMA, 40, { class = "ROGUE" }) })
    install(inst, "HealingDone", { src(BETA, 500, { class = "PRIEST" }) })
    local rows = build(inst, { "DamageDone", "HealingDone" }, "DamageDone")
    assertTrue(rows.ambiguous, "the header note was not told cells are withheld")
    assertEqual(rows.ambiguousRows, 2, "two other players' rows wait for combat to end")
    -- A grid with nothing to correlate withholds nothing.
    local single = build(inst, { "DamageDone" }, "DamageDone")
    assertTrue(not single.ambiguous)
    assertEqual(single.ambiguousRows, 0)
end)
