-- tests/test_schema_paths.lua
--
-- settings/Schema_Paths.lua: the path machinery, and the ONE seam every write
-- goes through. Two ideas here are not standard-issue:
--
--   1. THE WINDOW-RELATIVE PATH MODEL (design 8). A `window.`-prefixed path has
--      no window in it. It resolves against the SESSION'S ACTIVE WINDOW, so the
--      panel's picker retargets seventy-odd rows by moving one integer of session
--      state, and `/mm set window.frame.width 300` means "the window I am
--      editing" on the CLI exactly as it does in the panel. The test that matters
--      is therefore not "a path reads a value" but "the SAME path reads a
--      DIFFERENT window's value once the active window moves".
--
--   2. THE COLUMNS CARVE-OUT. `window.columns` is an ordered array, which a path
--      model has no vocabulary for, so it is written WHOLE through the same seam
--      and validated there instead of by a row's `validate`. That validator
--      REPAIRS rather than rejects -- it drops a statistic this build does not
--      have, appends one it gained, and sorts the enabled ones ahead of the
--      disabled ones -- so what is exercised here is both halves: what it fixes
--      silently, and the short list of shapes it genuinely cannot invent an
--      answer for.
--
-- What the SCHEMA ITSELF declares -- the pages, the tabs, the rows and their
-- labels, and what the defaults ship as -- is asserted next door in
-- tests/test_schema.lua. This file is about the plumbing underneath it.
--
-- Everything mutates, so every case builds its OWN instance through T.load()
-- rather than sharing one: a suite whose cases can only pass in the order they
-- happen to be declared in is a suite that will fail for the wrong reason later.

local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue, assertFalse = T.assertEqual, T.assertTrue, T.assertFalse

--- A loaded addon with TWO windows, and their ids. Duplicated from
--- tests/test_schema.lua rather than published: nine lines are cheaper to carry
--- twice than a shared fixture file is to keep honest.
local function twoWindows()
    local inst = T.load()
    local NS = inst.NS
    assertEqual(#NS.Database.GetWindows(), 1, "InitDB seeds exactly one window")
    assertTrue(NS.WindowManager:Create("Second"))
    local list = NS.Database.GetWindows()
    assertEqual(#list, 2)
    return inst, list[1].id, list[2].id
end

-- ---------------------------------------------------------------------------
-- The window-relative path model
-- ---------------------------------------------------------------------------

test("Schema: a window path resolves against the session's ACTIVE window", function()
    local inst, first, second = twoWindows()
    local NS = inst.NS

    NS.State.SetActiveWindow(first)
    assertTrue(NS.SetByPath("window.frame.width", 320))
    NS.State.SetActiveWindow(second)
    assertTrue(NS.SetByPath("window.frame.width", 640))

    -- One path, two answers, decided entirely by NS.State.activeWindowId.
    NS.State.SetActiveWindow(first)
    assertEqual(NS.GetSetting("window.frame.width"), 320)
    NS.State.SetActiveWindow(second)
    assertEqual(NS.GetSetting("window.frame.width"), 640)

    -- And the stored tables really are separate, not one table read twice.
    assertEqual(NS.Database.FindWindow(first).frame.width, 320)
    assertEqual(NS.Database.FindWindow(second).frame.width, 640)
end)

test("Schema: a global path is unaffected by which window is active", function()
    local inst, first, second = twoWindows()
    local NS = inst.NS

    NS.State.SetActiveWindow(first)
    assertTrue(NS.SetByPath("enabled", false))
    NS.State.SetActiveWindow(second)
    assertEqual(NS.GetSetting("enabled"), false,
        "`enabled` lives on the profile; moving the picker must not change it")

    assertTrue(NS.SetByPath("enabled", true))
    NS.State.SetActiveWindow(first)
    assertEqual(NS.GetSetting("enabled"), true)
    -- Neither window grew an `enabled` key on the way.
    assertEqual(NS.Database.FindWindow(first).enabled, nil)
    assertEqual(NS.Database.FindWindow(second).enabled, nil)
end)

test("Schema: an unset active window falls back to the FIRST window, never to nil", function()
    -- The CLI has no picker. `/mm set window.frame.width 300` typed on a fresh
    -- login must mean something rather than fail with a message about an internal
    -- pointer the user has never heard of.
    local inst, first = twoWindows()
    local NS = inst.NS
    assertEqual(NS.State.activeWindowId, nil, "nothing has moved the picker yet")

    assertTrue(NS.SetByPath("window.frame.height", 333))
    assertEqual(NS.Database.FindWindow(first).frame.height, 333)
end)

test("Schema: a stale active-window id falls back to the first window", function()
    local inst, first = twoWindows()
    local NS = inst.NS
    NS.State.SetActiveWindow(9999)
    assertEqual(NS.GetSetting("window.frame.width"),
        NS.Database.FindWindow(first).frame.width)
end)

test("Schema: the inverted row stores the negation of what it displays", function()
    local inst = T.load()
    local NS = inst.NS
    -- LibDBIcon owns `minimap.hide`; the checkbox says "Show minimap button".
    assertTrue(NS.SetByPath("minimap.hide", false))
    assertEqual(NS.db.profile.minimap.hide, true, "display false stores hide = true")
    assertEqual(NS.GetSetting("minimap.hide"), false, "and reads back in display terms")
end)

-- ---------------------------------------------------------------------------
-- The single write seam
-- ---------------------------------------------------------------------------

test("SetByPath: refuses a value the row's validate() rejects, and stores nothing", function()
    local inst = T.load()
    local NS = inst.NS
    local before = NS.GetSetting("window.frame.scale")
    local ok, err = NS.SetByPath("window.frame.scale", 9)   -- range is 0.5 .. 2.0
    assertFalse(ok)
    assertEqual(type(err), "string")
    assertEqual(NS.GetSetting("window.frame.scale"), before)
end)

test("SetByPath: refuses a path that is not a row", function()
    local inst = T.load()
    local ok, err = inst.NS.SetByPath("window.frame.wdith", 300)
    assertFalse(ok)
    assertEqual(type(err), "string")
end)

test("SetByPath: fires the row's onChange exactly once, with the value and window id", function()
    local inst, first = twoWindows()
    local NS = inst.NS
    NS.State.SetActiveWindow(first)

    local row = NS.FindSchemaRow("window.visibility.world")
    assertEqual(type(row.onChange), "function", "the visibility rows carry an onChange")

    local original = row.onChange
    local calls, sawValue, sawWindow = 0, nil, nil
    row.onChange = function(v, id) calls = calls + 1; sawValue, sawWindow = v, id end

    local ok = NS.SetByPath("window.visibility.world", true)
    row.onChange = original

    assertTrue(ok)
    assertEqual(calls, 1)
    assertEqual(sawValue, true)
    assertEqual(sawWindow, first, "a window row's onChange is told WHICH window moved")
end)

test("SetByPath: onChange runs AFTER the write, never before", function()
    local inst = T.load()
    local NS = inst.NS
    local row = NS.FindSchemaRow("enabled")
    local original = row.onChange
    local seen
    row.onChange = function() seen = NS.db.profile.enabled end
    NS.SetByPath("enabled", false)
    row.onChange = original
    assertEqual(seen, false,
        "reacting before the write would hand every refresher the OLD value")
end)

test("SetByPath: logs the change exactly ONCE", function()
    local inst = T.load()
    local NS = inst.NS
    local original = NS.Debug
    local lines = {}
    NS.Debug = function(tag, fmt, a, b) lines[#lines + 1] = { tag, fmt, a, b } end
    NS.SetByPath("window.frame.width", 500)
    NS.Debug = original

    assertEqual(#lines, 1,
        "a settings change that appears twice in the log is two changes to a reader")
    assertEqual(lines[1][1], "Set")
    assertEqual(lines[1][3], "window.frame.width", "the format is DEFERRED, not built at the seam")
    assertEqual(lines[1][4], 500)
end)

test("SetByPath: announces CONFIG_CHANGED once, tagged with the row's page and window", function()
    local inst, first = twoWindows()
    local NS = inst.NS
    NS.State.SetActiveWindow(first)

    local seen = {}
    NS:RegisterMessage(NS.Constants.MSG.CONFIG_CHANGED, function(_, payload)
        seen[#seen + 1] = payload
    end)

    assertTrue(NS.SetByPath("window.bars.border", true))
    assertEqual(#seen, 1)
    assertEqual(seen[1].section, "bars", "the section IS the row's page key")
    assertEqual(seen[1].windowId, first)

    -- A global row announces with no window id, because no window moved.
    assertTrue(NS.SetByPath("enabled", false))
    assertEqual(#seen, 2)
    assertEqual(seen[2].section, "general")
    assertEqual(seen[2].windowId, nil)
end)

test("SetByPath: re-syncs open panels IN PLACE, never structurally", function()
    local inst = T.load()
    local NS = inst.NS
    local scalars, structural = 0, 0
    local realScalars = NS.Helpers.RefreshScalars
    local realAll     = NS.Helpers.RefreshAllPanels
    NS.Helpers.RefreshScalars    = function() scalars = scalars + 1 end
    NS.Helpers.RefreshAllPanels  = function() structural = structural + 1 end

    NS.SetByPath("window.rows.height", 20)

    NS.Helpers.RefreshScalars   = realScalars
    NS.Helpers.RefreshAllPanels = realAll

    assertEqual(scalars, 1)
    assertEqual(structural, 0,
        "a structural rebuild would tear the page down under a slider mid-drag")
end)

test("SetByPath: a table value is COPIED in, never stored by reference", function()
    local inst, first, second = twoWindows()
    local NS = inst.NS
    local shared = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }

    NS.State.SetActiveWindow(first)
    assertTrue(NS.SetByPath("window.bars.customColor", shared))
    NS.State.SetActiveWindow(second)
    assertTrue(NS.SetByPath("window.bars.customColor", shared))

    local a = NS.Database.FindWindow(first).bars.customColor
    local b = NS.Database.FindWindow(second).bars.customColor
    assertTrue(a ~= shared, "the caller's table must not be the stored table")
    assertTrue(a ~= b, "two windows must not share one color table")
    a.r = 0.99
    assertEqual(b.r, 0.1, "editing one window's color edited the other's")
end)

test("ApplyDefault: restores through the same seam, deep-copying a table default", function()
    local inst = T.load()
    local NS = inst.NS
    local row = NS.FindSchemaRow("window.bars.customColor")

    assertTrue(NS.SetByPath("window.bars.customColor", { r = 1, g = 0, b = 0, a = 1 }))
    NS.ApplyDefault(row)

    local stored = NS.GetSetting("window.bars.customColor")
    assertEqual(stored.r, row.default.r)
    assertEqual(stored.a, row.default.a)
    assertTrue(stored ~= row.default,
        "storing the row's own default table would alias every profile onto it")
end)

test("ApplyDefault: round-trips the inverted row back to its SHIPPED stored value", function()
    local inst = T.load()
    local NS = inst.NS
    assertTrue(NS.SetByPath("minimap.hide", false))       -- display false -> stored true
    assertEqual(NS.db.profile.minimap.hide, true)
    NS.ApplyDefault(NS.FindSchemaRow("minimap.hide"))
    assertEqual(NS.db.profile.minimap.hide, false,
        "`default` is the STORED value, so the restore must land on false")
end)

-- ---------------------------------------------------------------------------
-- The columns carve-out
-- ---------------------------------------------------------------------------

local function goodColumns()
    return {
        { stat = "DamageDone",  enabled = true },
        { stat = "HealingDone", enabled = true },
    }
end

--- How many of the stored columns are shown.
local function shownCount(cols)
    local n = 0
    for _, c in ipairs(cols) do
        if c.enabled then n = n + 1 end
    end
    return n
end

test("SetByPath: window.columns repairs any array into the WHOLE catalog", function()
    -- The array used to be the SUBSET the player had assembled. It is the catalog
    -- now -- one entry per statistic, each carrying `enabled` -- because the page
    -- that reads it is a fixed list of blocks you tick rather than a list you add
    -- to, and a page that cannot add a column needs every column already there.
    local inst, first = twoWindows()
    local NS = inst.NS
    local Const = NS.Constants
    NS.State.SetActiveWindow(first)

    local ok, err = NS.SetByPath("window.columns", {
        { stat = "HealingDone", enabled = true },
        { stat = "DamageDone",  enabled = true },
    })
    assertTrue(ok, tostring(err))

    local stored = NS.Database.FindWindow(first).columns
    assertEqual(#stored, #Const.STATS,
        "the stored array IS the catalog now, however short the input was")
    assertEqual(stored[1].stat, "HealingDone", "the caller's order is kept for the enabled ones")
    assertEqual(stored[2].stat, "DamageDone")
    assertTrue(stored[1].enabled)
    assertTrue(stored[2].enabled)
    for i = 3, #stored do
        assertFalse(stored[i].enabled,
            "every statistic the caller did not name arrives disabled, not missing")
    end
    assertEqual(stored[1].width, nil, "width is not part of the shape any more")
    assertEqual(stored[1].showBar, nil, "showBar is not part of the shape any more")
end)

test("SetByPath: window.columns DROPS a statistic this build does not have", function()
    -- The old code STORED an unknown stat and listed it so the player could remove
    -- it. There is no remove button now and the list IS the catalog, so there is
    -- nothing they could do with the row -- self-healing beats surfacing a dead
    -- one.
    local inst, first = twoWindows()
    local NS = inst.NS
    NS.State.SetActiveWindow(first)

    local ok, err = NS.SetByPath("window.columns", {
        { stat = "DamageDone", enabled = true },
        { stat = "FutureStat", enabled = true },
    })
    assertTrue(ok, "an unknown statistic must not fail the whole write: " .. tostring(err))

    local stored = NS.Database.FindWindow(first).columns
    for _, c in ipairs(stored) do
        assertFalse(c.stat == "FutureStat", "the unknown statistic must not be stored")
    end
    assertEqual(#stored, #NS.Constants.STATS)
end)

test("SetByPath: window.columns keeps a repeated statistic's FIRST appearance only", function()
    local inst, first = twoWindows()
    local NS = inst.NS
    NS.State.SetActiveWindow(first)

    assertTrue((NS.SetByPath("window.columns", {
        { stat = "DamageDone",  enabled = true },
        { stat = "HealingDone", enabled = true },
        { stat = "DamageDone",  enabled = false },
    })))

    local stored = NS.Database.FindWindow(first).columns
    local seen = 0
    for _, c in ipairs(stored) do
        if c.stat == "DamageDone" then seen = seen + 1 end
    end
    assertEqual(seen, 1, "two Damage columns show identical numbers twice")
    assertEqual(stored[1].stat, "DamageDone")
    assertTrue(stored[1].enabled,
        "the first appearance wins, so a later duplicate cannot quietly untick it")
end)

test("SetByPath: window.columns stores the enabled ones ahead of the disabled ones", function()
    -- Sink-to-bottom is a STORED invariant rather than something the page
    -- maintains. `/mm set window.columns ...` and a hand-edited SavedVariables
    -- reach this seam without ever drawing a block, and three routes to one shape
    -- is three chances to disagree about it.
    local inst, first = twoWindows()
    local NS = inst.NS
    NS.State.SetActiveWindow(first)

    assertTrue((NS.SetByPath("window.columns", {
        { stat = "DamageDone",  enabled = false },
        { stat = "HealingDone", enabled = true },
        { stat = "Interrupts",  enabled = false },
        { stat = "Dispels",     enabled = true },
    })))

    local stored = NS.Database.FindWindow(first).columns
    assertEqual(stored[1].stat, "HealingDone", "relative order inside a group is the caller's")
    assertEqual(stored[2].stat, "Dispels")

    local sawDisabled = false
    for i, c in ipairs(stored) do
        if not c.enabled then sawDisabled = true end
        if c.enabled then
            assertFalse(sawDisabled,
                "entry " .. i .. " is enabled and follows a disabled one")
        end
    end
end)

test("SetByPath: window.columns REBUILDS the array rather than adopting the caller's", function()
    local inst, first = twoWindows()
    local NS = inst.NS
    NS.State.SetActiveWindow(first)

    local mine = goodColumns()
    mine[1].smuggled = "keep me out of the profile"
    assertTrue(NS.SetByPath("window.columns", mine))

    local stored = NS.Database.FindWindow(first).columns
    assertTrue(stored ~= mine, "the stored array must not be the caller's table")
    assertTrue(stored[1] ~= mine[1], "nor any of its entries")
    assertEqual(stored[1].smuggled, nil, "an extra key is dropped, not persisted")

    mine[1].stat = "Deaths"
    assertEqual(stored[1].stat, "DamageDone", "the caller can no longer reach into the profile")
end)

test("SetByPath: window.columns takes the same log, message and refresh a scalar takes", function()
    local inst, first = twoWindows()
    local NS = inst.NS
    NS.State.SetActiveWindow(first)

    local logs, messages, scalars = 0, {}, 0
    local realDebug, realScalars = NS.Debug, NS.Helpers.RefreshScalars
    NS.Debug = function() logs = logs + 1 end
    NS.Helpers.RefreshScalars = function() scalars = scalars + 1 end
    NS:RegisterMessage(NS.Constants.MSG.CONFIG_CHANGED, function(_, payload)
        messages[#messages + 1] = payload
    end)

    assertTrue(NS.SetByPath("window.columns", goodColumns()))

    NS.Debug = realDebug
    NS.Helpers.RefreshScalars = realScalars

    assertEqual(logs, 1, "a carve-out that announced nothing would be a silent second seam")
    assertEqual(#messages, 1)
    assertEqual(messages[1].section, "columns")
    assertEqual(messages[1].windowId, first)
    assertEqual(scalars, 1)
end)

test("SetByPath: window.columns is readable through the generic resolver", function()
    local inst, first = twoWindows()
    local NS = inst.NS
    NS.State.SetActiveWindow(first)
    assertTrue(NS.SetByPath("window.columns", goodColumns()))

    local read = NS.GetSetting("window.columns")
    assertEqual(type(read), "table")
    assertEqual(#read, #NS.Constants.STATS)
    assertEqual(read[1].stat, "DamageDone")
    assertEqual(shownCount(read), 2)
end)

-- Each refusal, one case per rule, because "it refused" without saying which rule
-- fired passes just as happily on a typo in the fixture.
--
-- THE LIST IS SHORTER THAN IT WAS, and that is the change rather than a gap in
-- coverage. An unknown statistic, a repeat, a width outside its range and a
-- non-boolean show-bar flag were four separate refusals; the first two are
-- repaired now and the last two name fields that no longer exist. What is left is
-- what the normalizer genuinely cannot invent an answer for.

local REFUSALS = {
    { "a non-table value",            "not a table" },
    { "an empty array",               {} },
    { "a gap or a string key",        { { stat = "DamageDone", enabled = true },
                                        extra = true } },
    { "an entry that is not a table", { "DamageDone" } },
    { "an array with nothing enabled",
                                      { { stat = "DamageDone", enabled = false } } },
    { "an array whose every statistic this build dropped",
                                      { { stat = "Nonsense", enabled = true } } },
}

for _, case in ipairs(REFUSALS) do
    local label, value = case[1], case[2]
    test("SetByPath: window.columns REFUSES " .. label .. ", with a message", function()
        local inst, first = twoWindows()
        local NS = inst.NS
        NS.State.SetActiveWindow(first)
        local before = NS.Database.FindWindow(first).columns

        local ok, err = NS.SetByPath("window.columns", value)
        assertFalse(ok, "the write was accepted")
        assertEqual(type(err), "string", "a refusal with no message tells the user nothing")
        assertTrue(#err > 0)
        assertEqual(NS.Database.FindWindow(first).columns, before,
            "a refused write must leave the stored array untouched")
    end)
end

test("SetByPath: a path INTO the column array is refused by name", function()
    local inst = T.load()
    local ok, err = inst.NS.SetByPath("window.columns.2.enabled", true)
    assertFalse(ok)
    assertEqual(type(err), "string")
    -- The ordinal moves on the next toggle or drag, so a stored reference to it is
    -- wrong by the next edit. It must not fall through to "not a row".
    assertTrue(err:find("Columns page", 1, true) ~= nil,
        "the refusal should point at the page that CAN do it, got: " .. err)
end)

test("Schema: NS.NormalizeColumns is published for the migration ladder", function()
    -- core/Database.lua's migrations[10] needs this rule and cannot reach a local
    -- in a file eighteen TOC entries later. A private copy there is how the
    -- migration and the write seam end up disagreeing about the shape.
    local inst = T.load()
    local NS = inst.NS
    assertEqual(type(NS.NormalizeColumns), "function")

    local out = NS.NormalizeColumns({ { stat = "Deaths", enabled = true } })
    assertEqual(type(out), "table")
    assertEqual(#out, #NS.Constants.STATS)
    assertEqual(out[1].stat, "Deaths")
    assertTrue(out[1].enabled)

    assertEqual(NS.NormalizeColumns({}), nil, "it refuses what it cannot repair")
end)
