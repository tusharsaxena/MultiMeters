-- tests/test_sim_checkbox.lua — the Sim mode checkbox on General > Master controls (R6-SIM).
--
-- The owner's rule (Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND6/, 2026-11-04): "a sim
-- checkbox in settings (next to test)". LibKa0s' MasterControls draws the row (compose minor 19)
-- from two host hooks, the SAME pair the launcher's Sim mode entry carries (core/LauncherSetup.lua's
-- NS.IsSimMode and NS.ToggleSim), so the box, the launcher entry and `/mm sim` are one act. The box
-- follows the live state: modules/Sim.lua's listener calls RefreshScalars whenever the session
-- starts, steps or stops, whoever started or stopped it.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local S = dofile((T.root or ".") .. "/tests/sim_support.lua")

--- The Sim mode row on the General page, and its index there.
local function simRow(NS)
    local rows = NS.SchemaForPage("general")
    for i, row in ipairs(rows) do
        if row.path == "state.sim" then return row, i, rows end
    end
    return nil
end

--- A stand-in NS.Sim that records every RunVerb argument. Both hooks read NS.Sim at call time.
local function fakeSim(NS, active)
    local calls = {}
    NS.Sim = {
        IsActive = function() return active end,
        RunVerb  = function(_, arg) calls[#calls + 1] = arg end,
    }
    return calls
end

test("Sim checkbox: Master controls carries a composed, session-only Sim mode row after Test mode",
function()
    -- red under: no isSimMode/toggleSim on the MasterControls spec (no row at all), or a
    -- hand-written row in its place (no `composed` stamp).
    local inst = T.load()
    local NS, L = inst.NS, inst.NS.L
    local row, at, rows = simRow(NS)

    assertTrue(row ~= nil, "no state.sim row on the General page")
    assertEqual(row.composed, true, "the row must come from the composer, not the schema's own text")
    assertEqual(row.group, L["Master controls"])
    assertEqual(row.label, L["Sim mode"])
    assertEqual(row.type, "bool")
    assertEqual(row.sessionOnly, true, "a sim is session state: a reload ends it")
    assertEqual(row.default, false, "Reset all settings must stop a running sim, not start one")
    assertEqual(rows[at - 1].path, "state.testMode", "Sim mode sits straight after Test mode")
    -- Test mode is the second column of Minimap button's line, so Sim mode opens the next one.
    assertEqual(row.startsLine, true)
    assertTrue(row.desc ~= nil and row.desc:find("/mm sim", 1, true) ~= nil,
        "the tooltip names the slash verb the box is")
end)

test("Sim checkbox: the hooks are one NS pair, the launcher's own", function()
    -- red under: the pair still built inline in the launcher descriptor (no NS.IsSimMode /
    -- NS.ToggleSim), which leaves the box with nothing to share.
    local inst = T.load()
    local NS = inst.NS
    assertEqual(type(NS.IsSimMode), "function")
    assertEqual(type(NS.ToggleSim), "function")

    local calls = fakeSim(NS, false)
    NS.ToggleSim()
    assertEqual(table.concat(calls, ","), "", "an idle sim takes the bare verb")
    calls = fakeSim(NS, true)
    NS.ToggleSim()
    assertEqual(table.concat(calls, ","), "stop", "a running sim takes the stop verb")
    assertEqual(NS.IsSimMode(), true)
end)

test("Sim checkbox: ticking runs /mm sim's own act, unticking stops, a no-change write does nothing",
function()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local row = simRow(NS)
    assertTrue(row ~= nil, "no state.sim row")

    local calls = fakeSim(NS, false)
    assertEqual(row.get(), false)
    row.set(true)
    assertEqual(table.concat(calls, ","), "", "ticking an idle sim runs the bare verb, as /mm sim does")
    row.set(false)
    assertEqual(#calls, 1, "unticking an idle sim must not toggle it")

    calls = fakeSim(NS, true)
    assertEqual(row.get(), true)
    row.set(false)
    assertEqual(table.concat(calls, ","), "stop", "unticking a running sim stops it")
    row.set(true)
    assertEqual(#calls, 1, "ticking a running sim must not toggle it")
end)

test("Sim checkbox: the box reads the real session, and unticking it ends that session", function()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local undo = S.inject(inst, { { kind = "noop", label = "One", run = function() end } })
    local row = simRow(NS)
    assertTrue(row ~= nil, "no state.sim row")

    assertFalse(row.get())
    assertTrue(NS.Sim:Start{ scenario = "case", seed = 3 })
    assertTrue(row.get(), "a sim started from the verb reads ticked")
    assertTrue(NS.SetByPath("state.sim", false), "the write seam refused the row")
    assertFalse(NS.Sim:IsActive(), "unticking did not stop the session")
    assertFalse(row.get())
    undo()
end)

test("Sim checkbox: a sim started or stopped elsewhere refreshes the open page", function()
    -- red under: no Sim:AddListener in modules/Sim.lua, so a sim started by /mm sim or the
    -- step panel, or one that stopped itself, leaves an open page's box stale.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local undo = S.inject(inst, { { kind = "noop", label = "One", run = function() end } })
    local refreshes = 0
    local H = NS.Helpers
    local real = H.RefreshScalars
    H.RefreshScalars = function(...) refreshes = refreshes + 1; return real(...) end

    assertTrue(NS.Sim:Start{ scenario = "case", seed = 3 })
    assertTrue(refreshes > 0, "starting the sim did not refresh the page")
    local before = refreshes
    NS.Sim:Stop("combat")
    assertTrue(refreshes > before, "a sim that stopped itself did not refresh the page")

    H.RefreshScalars = real
    undo()
end)
