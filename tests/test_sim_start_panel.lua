-- tests/test_sim_start_panel.lua — every start of a simulation shows the step panel (FB2-MM-01;
-- Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH/R2_SMOKE_FEEDBACK.md, decision D2).
--
-- The owner, 2026-11-24: "sim mode whether started from a command like /xx sim start <scenario> or
-- from just plain /xx sim should always show the sim stepper window". From LibKa0s v1.113.0 (Sim
-- minor 5) that is the library's job: a successful sim:Start shows the panel, at the one choke
-- point every start goes through. modules/Sim.lua's Host.Prepare used to show it too; it leaves the
-- panel to the library now, so each start shows it once and from one place. One case per start
-- path this addon has: the bare `/mm sim`, the typed `/mm sim start <scenario>`, the panel's Start
-- row and its picker's Start, a Restart, the Master controls Sim box and the launcher's Sim mode
-- entry (both NS.ToggleSim, the bare verb, then the panel's Start), and the host's own
-- NS.Sim:Start. Each opens on a closed panel, so a path that skips the panel fails.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local S = dofile((T.root or ".") .. "/tests/sim_support.lua")

local STEPS = { { kind = "noop", label = "One", run = function() end },
    { kind = "noop", label = "Two", run = function() end } }

--- A fresh, enabled instance with the "case" scenario listed first, so the panel's Start row and
--- picker (which start the chosen scenario, the first listed) start it too.
local function fresh()
    local inst = T.load{ enable = true }
    local undo = S.inject(inst, STEPS)
    local names = inst.NS.SimHost.SCENARIOS.names
    table.remove(names, #names)
    table.insert(names, 1, "case")
    return inst, undo
end

--- The step panel's frame, `<name>SimPanel` (the Sim major's documented frame name).
local function panelFrame(inst) return inst.mocks.__frameByName["MultiMetersSimPanel"] end

--- Open the panel with the bare verb, then close it again, so the frame and its rows exist.
local function builtThenClosed(inst)
    inst.NS.Sim:RunVerb("")
    inst.NS.Sim:HidePanel()
    assertFalse(inst.NS.Sim:IsPanelShown(), "the panel is closed before the start")
    return panelFrame(inst)
end

test("Sim start panel: a start shows the panel once, from the library's start, not the host's prepare",
function()
    -- red under: Host.Prepare calling sim:ShowPanel itself as well as the library's Start (two shows).
    local inst, undo = fresh()
    local NS = inst.NS
    local shows, show = 0, NS.Sim.ShowPanel
    NS.Sim.ShowPanel = function(...) shows = shows + 1; return show(...) end
    assertTrue(NS.Sim:Start{ scenario = "case", seed = 3 })
    assertEqual(shows, 1, "one start, one show")
    assertTrue(NS.Sim:IsPanelShown())
    NS.Sim:Stop()
    NS.Sim.ShowPanel = show
    undo()
end)

test("Sim start panel: the bare /mm sim shows the panel and starts nothing", function()
    local inst, undo = fresh()
    inst.NS.Slash:OnSlash("sim")
    assertTrue(inst.NS.Sim:IsPanelShown(), "/mm sim opened the step panel")
    assertFalse(inst.NS.Sim:IsActive(), "the bare verb starts nothing")
    undo()
end)

test("Sim start panel: /mm sim start <scenario> shows the panel", function()
    -- the owner's report, on Loot History's /lh sim start loot.
    local inst, undo = fresh()
    builtThenClosed(inst)
    inst.NS.Slash:OnSlash("sim start case")
    assertTrue(inst.NS.Sim:IsActive(), "the typed start started")
    assertTrue(inst.NS.Sim:IsPanelShown(), "/mm sim start case opened the step panel")
    inst.NS.Sim:Stop()
    undo()
end)

test("Sim start panel: the host's own NS.Sim:Start shows the panel", function()
    local inst, undo = fresh()
    builtThenClosed(inst)
    assertTrue(inst.NS.Sim:Start{ scenario = "case", seed = 3 })
    assertTrue(inst.NS.Sim:IsPanelShown(), "the member start opened the step panel")
    inst.NS.Sim:Stop()
    undo()
end)

test("Sim start panel: the panel's Start row and its picker's Start start with the panel shown", function()
    local inst, undo = fresh()
    local NS = inst.NS
    NS.Sim:RunVerb("")
    local f = panelFrame(inst)
    assertTrue(f ~= nil and f.__rowButtons ~= nil, "the panel drew its rows")
    f.__rowButtons[1]:__fire("OnClick")
    assertTrue(NS.Sim:IsActive(), "the Start row started a session")
    assertTrue(NS.Sim:IsPanelShown())
    NS.Sim:RunVerb("stop")
    assertTrue(f.picker ~= nil and f.picker.start ~= nil, "the panel has a picker")
    f.picker.start:__fire("OnClick")
    assertTrue(NS.Sim:IsActive(), "the picker's Start started a session")
    assertTrue(NS.Sim:IsPanelShown())
    NS.Sim:Stop()
    undo()
end)

test("Sim start panel: a Restart shows a panel the player closed mid-run", function()
    local inst, undo = fresh()
    local NS = inst.NS
    assertTrue(NS.Sim:Start{ scenario = "case", seed = 3 })
    NS.Sim:HidePanel()
    assertFalse(NS.Sim:IsPanelShown())
    assertTrue(NS.Sim:Restart())
    assertTrue(NS.Sim:IsActive(), "the restart is running")
    assertTrue(NS.Sim:IsPanelShown(), "the restarted session shows its panel")
    NS.Sim:Stop()
    undo()
end)

test("Sim start panel: the Master controls Sim box and the launcher entry open the panel a start keeps",
function()
    -- Both are NS.ToggleSim: the bare verb, which opens the panel; its Start row then starts.
    local inst, undo = fresh()
    local NS = inst.NS
    assertTrue(NS.SetByPath("state.sim", true), "the write seam refused the tick")
    assertTrue(NS.Sim:IsPanelShown(), "the box opened the step panel")
    panelFrame(inst).__rowButtons[1]:__fire("OnClick")
    assertTrue(NS.Sim:IsActive() and NS.Sim:IsPanelShown(), "the panel's start kept the panel shown")
    assertTrue(NS.SetByPath("state.sim", false))
    assertFalse(NS.Sim:IsActive())
    NS.ToggleSim()                                  -- the launcher's Sim mode entry
    assertTrue(NS.Sim:IsPanelShown(), "the launcher entry opened the step panel")
    undo()
end)

test("Sim start panel: a refused start shows nothing", function()
    local inst, undo = fresh()
    local NS = inst.NS
    builtThenClosed(inst)
    NS.State.testMode = true
    local ok = NS.Sim:Start{ scenario = "case", seed = 3 }
    assertFalse(ok, "test mode refuses the start")
    assertFalse(NS.Sim:IsPanelShown(), "a refused start opens no panel")
    NS.State.testMode = false
    undo()
end)
