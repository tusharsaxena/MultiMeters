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

-- ── the window rule (R7-SIM) ──────────────────────────────────────────────────────────────────
--
-- The owner's round 7 rule (Ka0sAddonsCommonTasks docs/2026-11-04-SMOKE_ROUND7, call 2): the box,
-- and the launcher's Sim mode entry, which reads the same NS.IsSimMode, is ticked exactly while the
-- sim window (the library's step panel) is shown OR a sim runs, and unticked when neither. Ticking is
-- the bare `/mm sim`, which opens the window, so the box stays ticked; unticking stops a running sim
-- and closes the window. LibKa0s needs no change for it (R7-L1): the row's get is NS.IsSimMode
-- verbatim and its set calls NS.ToggleSim only on a difference.

--- The step panel's frame, `<name>SimPanel` (the Sim major's documented frame name).
local function panelFrame(inst) return inst.mocks.__frameByName["MultiMetersSimPanel"] end

test("Sim checkbox: an open, idle sim window reads ticked, and closing it unticks (R7-SIM)", function()
    -- red under: NS.IsSimMode answering "running" alone, so `/mm sim`'s idle window reads unticked.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local row = simRow(NS)
    assertTrue(row ~= nil, "no state.sim row")
    assertFalse(row.get())

    NS.Sim:RunVerb("")
    assertTrue(NS.Sim:IsPanelShown(), "the bare verb did not open the sim window")
    assertFalse(NS.Sim:IsActive(), "the bare verb started a sim")
    assertTrue(row.get(), "window open, idle: the box must read ticked")
    assertTrue(NS.IsSimMode(), "the launcher's entry reads the same function")

    panelFrame(inst):Hide()                 -- the window's close mark, or Escape
    assertFalse(row.get(), "window closed, nothing running: the box must read unticked")
end)

test("Sim checkbox: ticking opens the sim window and stays ticked; unticking closes it (R7-SIM)", function()
    -- red under: a toggle that re-runs the bare verb from "window open, idle", so an untick
    -- re-opens the window and the box snaps back to ticked.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    assertTrue(NS.SetByPath("state.sim", true), "the write seam refused the tick")
    assertTrue(NS.Sim:IsPanelShown(), "ticking did not open the sim window")
    assertFalse(NS.Sim:IsActive(), "ticking started a sim: it is the bare verb, which only opens the window")
    assertTrue(simRow(NS).get(), "the box snapped back to unticked after the tick")

    assertTrue(NS.SetByPath("state.sim", false), "the write seam refused the untick")
    assertFalse(NS.Sim:IsPanelShown(), "unticking left the sim window open")
    assertFalse(simRow(NS).get())
end)

test("Sim checkbox: a sim running with its window hidden reads ticked; unticking stops it (R7-SIM)",
function()
    -- red under: an untick that only hides the window, or a box that reads the window alone.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local undo = S.inject(inst, { { kind = "noop", label = "One", run = function() end } })
    assertTrue(NS.Sim:Start{ scenario = "case", seed = 3 })
    NS.Sim:HidePanel()
    assertTrue(NS.Sim:IsActive())
    assertFalse(NS.Sim:IsPanelShown())
    assertTrue(simRow(NS).get(), "running, window hidden: the box must read ticked")

    assertTrue(NS.SetByPath("state.sim", false), "the write seam refused the untick")
    assertFalse(NS.Sim:IsActive(), "unticking did not stop the sim")
    assertFalse(NS.Sim:IsPanelShown(), "unticking opened the window")
    assertFalse(simRow(NS).get())
    undo()
end)

test("Sim checkbox: unticking a running sim with its window open stops it and closes the window (R7-SIM)",
function()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local undo = S.inject(inst, { { kind = "noop", label = "One", run = function() end } })
    assertTrue(NS.Sim:Start{ scenario = "case", seed = 3 })
    assertTrue(NS.Sim:IsPanelShown(), "the start did not open the step panel")
    assertTrue(NS.SetByPath("state.sim", false), "the write seam refused the untick")
    assertFalse(NS.Sim:IsActive(), "unticking did not stop the sim")
    assertFalse(NS.Sim:IsPanelShown(), "unticking left the window open")
    assertFalse(simRow(NS).get(), "a stopped sim whose window stayed up would still read ticked")
    undo()
end)

test("Sim checkbox: the sim window's own show and hide refresh an open page (R7-SIM)", function()
    -- red under: no OnShow / OnHide hook on the step panel, so `/mm sim`, the window's close mark or
    -- Escape leaves an open page's box stale (the sim's listener fires on start and stop only).
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local refreshes = 0
    local H = NS.Helpers
    local real = H.RefreshScalars
    H.RefreshScalars = function(...) refreshes = refreshes + 1; return real(...) end

    NS.Sim:RunVerb("")
    assertTrue(refreshes > 0, "opening the sim window did not refresh the page")
    local frame = panelFrame(inst)
    assertTrue(frame ~= nil, "no MultiMetersSimPanel frame")
    local before = refreshes
    frame:Hide()
    assertTrue(refreshes > before, "the window's own hide did not refresh the page")
    before = refreshes
    frame:Show()
    assertTrue(refreshes > before, "the window's own show did not refresh the page")

    H.RefreshScalars = real
end)
