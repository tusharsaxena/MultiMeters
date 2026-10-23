-- tests/test_sim_drivers.lua — the simulator's drivers (modules/SimDrivers.lua).
--
-- MM-14 (MultiMeters#60). Each case runs a throwaway session (tests/sim_support.lua) on a fresh,
-- enabled instance, with a world built for it, and drives the world through NS.SimHost.Drivers.
-- What the engine then reads it reads the way it always does: through NS.Compat, which the seam
-- answers out of the world, and the bus messages core/MultiMeters.lua's dispatch sends.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local S = dofile((T.root or ".") .. "/tests/sim_support.lua")

local PLAYER = { guid = "Player-1-00000001", name = "Me", classFilename = "MAGE", role = "DAMAGER" }

--- A fresh enabled instance with a world and a running test session.
--- @return table inst, table drivers, table world, table clock, function done
local function session(seed)
    local inst = T.load{ enable = true }
    local ns = inst.NS
    local D = assert(ns.SimHost.Drivers, "modules/SimDrivers.lua publishes no NS.SimHost.Drivers")
    local w = ns.SimHost.World.New(seed or 11, PLAYER)
    ns.SimHost.world = w
    local _, stop = S.testSession(inst)
    local function done()
        stop()
        ns.SimHost.world = nil
    end
    return inst, D, w, S.clock(inst.mocks), done
end

--- Count publications of each message on an instance.
local function watch(inst, ...)
    local seen = {}
    local target = inst.NS.NewBusTarget()
    for _, key in ipairs({ ... }) do
        local message = inst.NS.Constants.MSG[key]
        seen[key] = 0
        target:RegisterMessage(message, function() seen[key] = seen[key] + 1 end)
    end
    return seen
end

local function meterCalls(m)
    local n = 0
    for _, c in pairs(m.__meter.calls) do n = n + c end
    return n
end

local function damageOf(inst, guid)
    local ns = inst.NS
    local col = ns.Provider.GetColumn(ns.Constants.SESSION_TYPE.Current, "DamageDone")
    for _, src in ipairs(col.sources or {}) do
        if src.guid == guid or src.sourceGUID == guid then return src.totalAmount end
    end
    return 0
end

local FIGHT = { name = "Trash", ticks = 4, secondsPerTick = 3, ends = true }

-- ── the group and the zone ────────────────────────────────────────────────────────────────────

test("SimDrivers: FormGroup(5) leaves Roster.GetGroup() with 5 members, player first", function()
    local inst, D, _, _, done = session()
    local seen = watch(inst, "ROSTER_CHANGED")
    D.FormGroup(5)
    local group = inst.NS.Roster.GetGroup()
    assertEqual(#group, 5)
    assertEqual(group[1].guid, PLAYER.guid)
    assertTrue(group[1].isPlayer, "the first member is not the player")
    assertEqual(seen.ROSTER_CHANGED, 1)
    D.Disband()
    assertEqual(#inst.NS.Roster.GetGroup(), 1)
    done()
end)

test("SimDrivers: Zone('rookery') reads as a dungeon and sends ENTERING_WORLD and ZONE_CHANGED", function()
    local inst, D, _, _, done = session()
    local seen = watch(inst, "ENTERING_WORLD", "ZONE_CHANGED")
    assertEqual(inst.NS.Visibility.GetContext(), "world")
    D.Zone("rookery")
    assertEqual(inst.NS.Visibility.GetContext(), "dungeon")
    assertEqual(seen.ENTERING_WORLD, 1)
    assertEqual(seen.ZONE_CHANGED, 1)
    done()
end)

-- ── a fight ───────────────────────────────────────────────────────────────────────────────────

test("SimDrivers: Pull puts the player in combat, and test mode cannot start", function()
    local inst, D, _, _, done = session()
    local seen = watch(inst, "COMBAT_CHANGED", "METER_UPDATED")
    D.FormGroup(5)
    D.Pull(FIGHT)
    assertEqual(inst.NS.Compat.UnitAffectingCombat("player"), true)
    assertEqual(seen.COMBAT_CHANGED, 1)
    assertEqual(seen.METER_UPDATED, 1)
    assertEqual(inst.NS.WindowManager:SetTestMode(true), false)
    assertTrue(not inst.NS.State.testMode, "test mode started in a simulated pull")
    done()
end)

test("SimDrivers: Fight books its ticks, grows the totals and ends with one session event per stat", function()
    local inst, D, w, clock, done = session()
    local ns = inst.NS
    local seen = watch(inst, "METER_SESSION", "METER_UPDATED", "COMBAT_CHANGED")
    D.FormGroup(5)
    local detail = D.Fight(FIGHT)
    assertEqual(detail, "3 ticks booked")
    assertEqual(w.pending, FIGHT.ticks - 1)
    local last = damageOf(inst, PLAYER.guid)
    assertTrue(last > 0, "the first tick dealt nothing")
    for _ = 2, FIGHT.ticks do
        clock.advance(D.TICK)
        local now = damageOf(inst, PLAYER.guid)
        assertTrue(now > last, ("DamageDone did not grow: %s -> %s"):format(tostring(last), tostring(now)))
        last = now
    end
    assertEqual(w.pending, 0)
    assertEqual(ns.Compat.UnitAffectingCombat("player"), false)
    assertEqual(seen.METER_SESSION, #ns.Constants.STATS)
    assertEqual(seen.METER_UPDATED, FIGHT.ticks + 1)
    assertEqual(seen.COMBAT_CHANGED, 2)
    local sessions = ns.Compat.GetAvailableCombatSessions()
    assertEqual(#sessions, 1)
    assertEqual(sessions[1].sessionID, w.segments[1].sessionID)
    assertEqual(sessions[1].name, "Trash")
    done()
end)

test("SimDrivers: EndFight sends the stats' session events in catalog order, after REGEN", function()
    local inst, D, w, _, done = session()
    local ns = inst.NS
    local order = {}
    local target = ns.NewBusTarget()
    target:RegisterMessage(ns.Constants.MSG.COMBAT_CHANGED, function() order[#order + 1] = "combat" end)
    target:RegisterMessage(ns.Constants.MSG.METER_SESSION, function(_, p)
        order[#order + 1] = tostring(p.type) .. "@" .. tostring(p.sessionID)
    end)
    D.Pull(FIGHT)
    order = {}
    D.EndFight(FIGHT)
    local id = w.segments[1].sessionID
    assertEqual(order[1], "combat")
    for i, stat in ipairs(ns.Constants.STATS) do
        assertEqual(order[i + 1], tostring(stat.enumValue) .. "@" .. tostring(id), stat.key)
    end
    done()
end)

test("SimDrivers: a death booked for a tick happens on that tick", function()
    local _, D, w, clock, done = session()
    D.FormGroup(5)
    local fight = { name = "Boss", ticks = 3, secondsPerTick = 2, ends = true,
        deaths = { { tick = 2, role = "DAMAGER" } } }
    D.Fight(fight)
    assertEqual(#w.current.deaths, 0)
    clock.advance(D.TICK)
    assertEqual(#w.current.deaths, 1)
    assertTrue(w.current.deaths[1].guid ~= PLAYER.guid, "the player died for a mate")
    clock.advance(D.TICK)
    assertEqual(#w.current.deaths, 1)
    done()
end)

-- ── the reset ─────────────────────────────────────────────────────────────────────────────────

test("SimDrivers: Reset empties the segments and reaches DAMAGE_METER_RESET through the dispatch", function()
    local inst, D, w, clock, done = session()
    local ns, m = inst.NS, inst.mocks
    D.FormGroup(5)
    D.Fight({ name = "Trash", ticks = 1, secondsPerTick = 2, ends = true })
    assertEqual(#ns.Compat.GetAvailableCombatSessions(), 1)
    local delivered = 0
    local real = ns.OnMeterReset
    ns.OnMeterReset = function(self, ...) delivered = delivered + 1; return real(self, ...) end
    local seen = watch(inst, "METER_RESET")
    local resets = m.__meter.resets
    D.Reset()
    assertEqual(#w.segments, 0)
    assertEqual(#ns.Compat.GetAvailableCombatSessions(), 0)
    assertEqual(delivered, 0, "the reset's reply arrived before its timer")
    local before = seen.METER_RESET
    clock.advance(0.1)
    assertEqual(delivered, 1, "DAMAGE_METER_RESET did not reach the dispatch")
    assertEqual(seen.METER_RESET, before + 1)
    assertEqual(m.__meter.resets, resets, "the mock meter's reset ran")
    ns.OnMeterReset = real
    done()
end)

test("SimDrivers: no driver reaches the mock's C_DamageMeter", function()
    local inst, D, _, clock, done = session()
    local m = inst.mocks
    m.resetMeterCalls()
    local before = meterCalls(m)
    D.FormGroup(5)
    D.Zone("rookery")
    D.Pull(FIGHT)
    D.Tick(FIGHT)
    D.EndFight(FIGHT)
    D.Fight(FIGHT)
    clock.advance(D.TICK * FIGHT.ticks)
    D.Reset()
    clock.advance(0.1)
    D.Disband()
    assertEqual(meterCalls(m), before)
    for name, n in pairs(m.__meter.calls) do assertEqual(n, 0, name .. " reached the client's meter") end
    done()
end)

test("SimDrivers: with no world, every driver changes and fires nothing", function()
    local inst = T.load{ enable = true }
    local ns = inst.NS
    local D = assert(ns.SimHost.Drivers, "no NS.SimHost.Drivers")
    ns.SimHost.world = nil
    local seen = watch(inst, "ROSTER_CHANGED", "ZONE_CHANGED", "COMBAT_CHANGED", "METER_UPDATED")
    D.FormGroup(5)
    D.Disband()
    D.Zone("rookery")
    D.Pull(FIGHT)
    D.Tick(FIGHT)
    D.EndFight(FIGHT)
    assertEqual(D.Fight(FIGHT), nil)
    for key, n in pairs(seen) do assertEqual(n, 0, key) end
end)
