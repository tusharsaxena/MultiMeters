-- tests/test_sim_session.lua — the simulator's session host (modules/Sim.lua).
--
-- MM-15 (MultiMeters#60). Every case runs the live NS.Sim on a fresh, enabled instance, with a
-- one-step injected scenario (tests/sim_support.lua's S.inject), so the start goes through the
-- host's REAL refusal and prepare: the refusals, the real-event classifier, the stops and their
-- resync, the session-only stores, and the before/after SavedVariables snapshot (H4).

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local S = dofile((T.root or ".") .. "/tests/sim_support.lua")

--- A fresh enabled instance with the "case" scenario listed.
--- @return table inst, function undo
local function fresh()
    local inst = T.load{ enable = true }
    local undo = S.inject(inst, { { kind = "noop", label = "One", run = function() end } })
    return inst, undo
end

--- The chat lines `fn` produced.
local function said(inst, fn)
    local chat = inst.mocks.__chat
    local n = #chat
    fn()
    local out = {}
    for i = n + 1, #chat do out[#out + 1] = chat[i] end
    return table.concat(out, "\n")
end

local function contains(text, line)
    return text:find(line, 1, true) ~= nil
end

--- Record every publication of each named message: { [key] = { payload, ... } }.
local function watch(inst, ...)
    local seen = {}
    local target = inst.NS.NewBusTarget()
    for _, key in ipairs({ ... }) do
        seen[key] = {}
        target:RegisterMessage(inst.NS.Constants.MSG[key], function(_, payload)
            local list = seen[key]
            list[#list + 1] = { payload = payload, active = inst.NS.Sim:IsActive() }
        end)
    end
    return seen
end

local function start(inst)
    local ok, line = inst.NS.Sim:Start{ scenario = "case", seed = 3 }
    assertTrue(ok, "the session did not start: " .. tostring(line))
end

--- After any stop: no filter, the live solo roster, and the SIM_CHANGED false edge last.
local function assertIdle(inst, seen)
    local ns = inst.NS
    assertFalse(ns.Sim:IsActive(), "the session is still active")
    assertEqual(ns.RealEventFilter, nil, "the real-event filter outlived the session")
    local group = ns.Roster.GetGroup()
    assertEqual(#group, 1)
    assertEqual(group[1].guid, inst.mocks.UnitGUID("player"), "the roster is not the live solo one")
    local edges = seen.SIM_CHANGED
    assertTrue(#edges >= 2, "the SIM_CHANGED edges were not both sent")
    assertEqual(edges[#edges].payload.active, false)
end

-- ── refusals ──────────────────────────────────────────────────────────────────────────────────

local REFUSALS = {
    { "stood down", function(inst) inst.NS.SetByPath("enabled", false) end,
        function(inst) return inst.NS.Slash:DisabledLine() end },
    { "test mode", function(inst) inst.NS.WindowManager:SetTestMode(true) end,
        "Turn test mode off before starting a simulation." },
    { "combat", function(inst) inst.mocks.setInCombat(true) end, "A simulation cannot start in combat." },
    { "the restriction", function(inst) inst.mocks.setRestricted(true) end, "A simulation cannot start in combat." },
    { "an instance", function(inst) inst.mocks.setInstance("party") end, "A simulation cannot start in an instance." },
    { "a group", function(inst) inst.mocks.setGroup({ {}, {} }) end, "Leave your group before starting a simulation." },
    { "General visibility never", function(inst) inst.NS.SetByPath("master.visibility", "never") end,
        "A simulation cannot start while General visibility hides every window." },
}

for _, r in ipairs(REFUSALS) do
    test("Sim session: " .. r[1] .. " refuses the start with its own line and leaves no session", function()
        local inst, undo = fresh()
        r[2](inst)
        local line = type(r[3]) == "function" and r[3](inst) or r[3]
        local out = said(inst, function() inst.NS.Sim:Start{ scenario = "case" } end)
        assertTrue(contains(out, line), "expected `" .. line .. "`, got: " .. out)
        assertFalse(inst.NS.Sim:IsActive(), "a refused start left a session")
        assertEqual(inst.NS.Sim:Session(), nil)
        assertEqual(inst.NS.RealEventFilter, nil)
        undo()
    end)
end

-- ── the start ─────────────────────────────────────────────────────────────────────────────────

test("Sim session: a typed start prints STARTED, shows the panel and installs the filter", function()
    local inst, undo = fresh()
    local ns = inst.NS
    local seen = watch(inst, "SIM_CHANGED", "METER_RESET")
    local out = said(inst, function() ns.Sim:RunVerb("start case") end)
    assertTrue(contains(out, "a scripted fight through the real meter. Nothing is saved or sent"), out)
    assertTrue(ns.Sim:IsActive(), "the typed start did not start")
    assertTrue(ns.Sim:IsPanelShown(), "the step panel is not shown")
    assertTrue(#ns.Sim:PanelRows() > 0, "the panel has no rows")
    assertEqual(ns.RealEventFilter, ns.SimHost.OnRealEvent)
    assertEqual(#seen.SIM_CHANGED, 1)
    assertEqual(seen.SIM_CHANGED[1].payload.active, true)
    assertTrue(#seen.METER_RESET >= 1, "the start did not reset the meter through the real handlers")
    local session = ns.Sim:Session()
    assertTrue(session.mm == ns.SimHost.world and session.mm ~= nil, "the session holds no world")
    assertEqual(session.mm.player.guid, inst.mocks.UnitGUID("player"), "the local player is not the real one")
    assertTrue(session.mmPins[1] ~= nil, "the window pins were not snapshotted")
    ns.Sim:Stop()
    assertIdle(inst, seen)
    undo()
end)

test("Sim session: the gate holds while fight ticks are booked", function()
    local inst, undo = fresh()
    start(inst)
    local Host = inst.NS.SimHost
    assertTrue(Host.Gate(inst.NS.Sim:Session()), "an idle world closed the gate")
    Host.world.pending = 2
    local open, line = Host.Gate(inst.NS.Sim:Session())
    assertFalse(open)
    assertEqual(line, "The fight is still running.")
    Host.world.pending = 0
    inst.NS.Sim:Stop()
    undo()
end)

test("Sim session: the status verb adds segments, ticks pending and sends", function()
    local inst, undo = fresh()
    start(inst)
    local out = said(inst, function() inst.NS.Sim:RunVerb("") end)
    assertTrue(contains(out, "Segments held: 0, ticks pending: 0, sends: 0."), out)
    inst.NS.Sim:Stop()
    undo()
end)

-- ── auto-stop on real events ──────────────────────────────────────────────────────────────────

test("Sim session: real combat stops with `combat` and then runs the real handler", function()
    local inst, undo = fresh()
    local seen = watch(inst, "SIM_CHANGED", "COMBAT_CHANGED")
    start(inst)
    local out = said(inst, function() inst.NS:OnGameEvent("PLAYER_REGEN_DISABLED") end)
    assertTrue(contains(out, "Simulation stopped: you entered combat."), out)
    assertEqual(inst.NS.SimHost.lastStop.reason, "combat")
    -- The stop's resync sends one, and the real handler the other, after the stop.
    assertEqual(#seen.COMBAT_CHANGED, 2)
    assertFalse(seen.COMBAT_CHANGED[2].active, "the real handler ran inside the session")
    assertIdle(inst, seen)
    undo()
end)

test("Sim session: a restriction edge other than Inactive stops with `combat`", function()
    local inst, undo = fresh()
    start(inst)
    local STATE = inst.NS.Secrets.STATE
    inst.NS:OnGameEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, STATE.Inactive)
    assertTrue(inst.NS.Sim:IsActive(), "an Inactive edge stopped the session")
    inst.NS:OnGameEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, STATE.Active)
    assertFalse(inst.NS.Sim:IsActive())
    assertEqual(inst.NS.SimHost.lastStop.reason, "combat")
    undo()
end)

test("Sim session: a solo roster update is consumed; a real group stops with `group`", function()
    local inst, undo = fresh()
    local seen = watch(inst, "SIM_CHANGED", "ROSTER_CHANGED")
    start(inst)
    inst.NS:OnGameEvent("GROUP_ROSTER_UPDATE")
    assertTrue(inst.NS.Sim:IsActive(), "a solo roster update stopped the session")
    assertEqual(#seen.ROSTER_CHANGED, 0, "the consumed roster update reached the handler")
    inst.mocks.setGroup({ {}, {} })
    inst.NS:OnGameEvent("GROUP_ROSTER_UPDATE")
    assertFalse(inst.NS.Sim:IsActive())
    assertEqual(inst.NS.SimHost.lastStop.reason, "group")
    assertEqual(#seen.ROSTER_CHANGED, 1, "the real roster update was not delivered after the stop")
    undo()
end)

test("Sim session: a zone move outside an instance is consumed; an instance stops with `instance`", function()
    local inst, undo = fresh()
    local seen = watch(inst, "SIM_CHANGED", "ZONE_CHANGED")
    start(inst)
    inst.NS:OnGameEvent("ZONE_CHANGED_NEW_AREA")
    assertTrue(inst.NS.Sim:IsActive(), "a zone move in the open world stopped the session")
    assertEqual(#seen.ZONE_CHANGED, 0)
    inst.mocks.setInstance("party")
    inst.NS:OnGameEvent("ZONE_CHANGED_NEW_AREA")
    assertFalse(inst.NS.Sim:IsActive())
    assertEqual(inst.NS.SimHost.lastStop.reason, "instance")
    assertEqual(#seen.ZONE_CHANGED, 1)
    undo()
end)

test("Sim session: a world entry stops with `world`", function()
    local inst, undo = fresh()
    local seen = watch(inst, "SIM_CHANGED")
    start(inst)
    inst.NS:OnGameEvent("PLAYER_ENTERING_WORLD", false, false)
    assertEqual(inst.NS.SimHost.lastStop.reason, "world")
    assertIdle(inst, seen)
    undo()
end)

test("Sim session: a real meter update is consumed: the world owns the meter", function()
    local inst, undo = fresh()
    local seen = watch(inst, "METER_UPDATED")
    start(inst)
    inst.NS:OnGameEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED", 0)
    inst.NS:OnGameEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 1)
    assertEqual(#seen.METER_UPDATED, 0)
    assertTrue(inst.NS.Sim:IsActive())
    inst.NS.Sim:Stop()
    undo()
end)

test("Sim session: an event the classifier has no rule for runs live and keeps the session", function()
    local inst, undo = fresh()
    local seen = watch(inst, "PLAYER_STATE_CHANGED")
    start(inst)
    inst.NS:OnGameEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    assertTrue(inst.NS.Sim:IsActive())
    assertTrue(#seen.PLAYER_STATE_CHANGED >= 1, "an unclassified event was consumed")
    inst.NS.Sim:Stop()
    undo()
end)

-- ── the other stops ───────────────────────────────────────────────────────────────────────────

test("Sim session: the stand-down stops the session first, with `standDown`", function()
    local inst, undo = fresh()
    local seen = watch(inst, "SIM_CHANGED")
    start(inst)
    inst.NS.SetByPath("enabled", false)
    assertFalse(inst.NS.Sim:IsActive())
    assertEqual(inst.NS.SimHost.lastStop.reason, "standDown")
    assertEqual(inst.NS.RealEventFilter, nil)
    assertEqual(seen.SIM_CHANGED[#seen.SIM_CHANGED].payload.active, false)
    undo()
end)

test("Sim session: a profile change stops the session with `profile`", function()
    local inst, undo = fresh()
    start(inst)
    inst.NS.db:SetProfile("Other")
    assertFalse(inst.NS.Sim:IsActive())
    assertEqual(inst.NS.SimHost.lastStop.reason, "profile")
    undo()
end)

test("Sim session: test mode is refused while a session runs", function()
    local inst, undo = fresh()
    start(inst)
    local applied
    local out = said(inst, function() applied = inst.NS.WindowManager:SetTestMode(true) end)
    assertEqual(applied, false)
    assertFalse(inst.NS.State.testMode, "test mode started inside a simulation")
    assertTrue(contains(out, "Test mode is not available while a simulation runs."), out)
    inst.NS.Sim:Stop()
    assertTrue(inst.NS.WindowManager:SetTestMode(true), "test mode is still refused after the stop")
    inst.NS.WindowManager:SetTestMode(false)
    undo()
end)

-- ── the stores (H4) ───────────────────────────────────────────────────────────────────────────

test("Sim session: SavedVariables come back byte-identical after a session that pins and resets", function()
    local inst, undo = fresh()
    local ns = inst.NS
    -- A real remembered roster first, so a stop that wiped it would show.
    ns.Roster.GetGroup()
    local before = S.snapshot(ns)
    assertTrue(before:find("Player%-1%-") ~= nil, "the real roster was not remembered before the start")
    local clock = S.clock(inst.mocks)
    start(inst)
    local Host = ns.SimHost
    Host.Drivers.FormGroup(5)
    ns.Roster.GetGroup()
    local seg = Host.World.OpenSegment(Host.world, "Boss")
    Host.World.Tick(Host.world, 3)
    local win = ns.WindowManager.All()[1]
    win:SetSegment(seg.sessionID)
    assertEqual(win.config.data.sessionID, seg.sessionID, "the simulated pin was not written")
    ns.Provider.Reset()
    clock.advance(0.1)
    ns.Roster.GetGroup()
    ns.Sim:Stop()
    assertEqual(win.config.data.sessionID, ns.Constants.NO_SEGMENT, "the pin was not restored")
    assertEqual(S.snapshot(ns), before, "the session changed SavedVariables")
    undo()
end)

test("Sim session: DropStaleSegment writes nothing while a session runs", function()
    local inst, undo = fresh()
    local ns = inst.NS
    start(inst)
    local win = ns.WindowManager.All()[1]
    win.config.data.sessionID = 42
    local writes = 0
    local real = ns.SetByPath
    ns.SetByPath = function(...) writes = writes + 1; return real(...) end
    win:DropStaleSegment()
    ns.SetByPath = real
    assertEqual(writes, 0, "the stale-pin repair wrote during a session")
    assertEqual(win.config.data.sessionID, 42)
    win.config.data.sessionID = ns.Constants.NO_SEGMENT
    ns.Sim:Stop()
    undo()
end)
