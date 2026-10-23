-- tests/test_dispatch.lua — core/MultiMeters.lua's ONE dispatch entry for game
-- events (MultiMeters#60, Sim host contract H3).
--
-- Every row of the EVENTS array is registered with the one handler name
-- "OnGameEvent". That entry consults NS.RealEventFilter (the simulator host's
-- hook, set only while a session runs) and otherwise hands the event to
-- NS.DeliverEvent, which looks the event up in NS.HANDLER_BY_EVENT and calls
-- exactly the method the client's registration used to call. The simulator
-- passes NS.DeliverEvent as its `deliver`, so a synthetic event and a real one
-- reach the same handler through the same table.

local T = _G.MULTIMETERS_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertNil

local MSG = NS.Constants.MSG

--- Count publications of `message` on an instance.
local function watch(inst, message)
    local seen = { n = 0 }
    local target = inst.NS.NewBusTarget()
    target:RegisterMessage(message, function(_, payload)
        seen.n = seen.n + 1
        seen.last = payload
    end)
    return seen
end

--- Replace NS[method] with a recorder for the rest of the case; answers the log.
local function spy(ns, method)
    local log = {}
    ns[method] = function(_, ...) log[#log + 1] = { n = select("#", ...), ... } end
    return log
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

test("Dispatch: every EVENTS row is registered with the one handler OnGameEvent", function()
    -- red under: per-event method names handed to the registration.
    local inst = T.load{ enable = true }
    local registered = inst.NS.__events
    assertTrue(count(registered) > 0, "nothing is registered")
    for event, handler in pairs(registered) do
        assertEqual(handler, "OnGameEvent", event .. " is not registered to OnGameEvent")
    end
    assertEqual(type(inst.NS.OnGameEvent), "function")
end)

test("Dispatch: HANDLER_BY_EVENT has exactly one row per registered event", function()
    local inst = T.load{ enable = true }
    local map = inst.NS.HANDLER_BY_EVENT
    assertEqual(type(map), "table", "NS.HANDLER_BY_EVENT is not published")
    assertEqual(count(map), count(inst.NS.__events), "the table and the registrations disagree")
    for event, method in pairs(map) do
        assertTrue(inst.NS.__events[event] ~= nil, event .. " has a row but no registration")
        assertEqual(type(inst.NS[method]), "function", method .. " is not a function on NS")
    end
    assertEqual(map.GROUP_ROSTER_UPDATE, "OnRosterUpdate")
    assertEqual(map.PLAYER_REGEN_DISABLED, "OnCombatChanged")
    assertEqual(map.DAMAGE_METER_RESET, "OnMeterReset")
end)

test("Dispatch: OnGameEvent('GROUP_ROSTER_UPDATE') sends ROSTER_CHANGED", function()
    local inst = T.load{ enable = true }
    local seen = watch(inst, MSG.ROSTER_CHANGED)
    inst.NS:OnGameEvent("GROUP_ROSTER_UPDATE")
    assertEqual(seen.n, 1)
end)

test("Dispatch: a fired game event reaches its handler through the dispatch row", function()
    local inst = T.load{ enable = true }
    local seen = watch(inst, MSG.ROSTER_CHANGED)
    inst.mocks.__fireEvent("GROUP_ROSTER_UPDATE")
    assertEqual(seen.n, 1)
end)

test("Dispatch: DeliverEvent answers 1 for a known event and 0 for an unknown one", function()
    local inst = T.load{ enable = true }
    local seen = watch(inst, MSG.ZONE_CHANGED)
    assertEqual(inst.NS.DeliverEvent("ZONE_CHANGED_NEW_AREA"), 1)
    assertEqual(seen.n, 1)
    assertEqual(inst.NS.DeliverEvent("NOT_A_REAL_EVENT"), 0)
    assertEqual(seen.n, 1)
end)

test("Dispatch: DeliverEvent answers 0 for a rejected event and calls nothing", function()
    -- The client never registered it, so the real path could never have called
    -- the handler; a simulated delivery must not either.
    local inst = T.load{ enable = true, mutate = function(m)
        m.__badEvents = { UNIT_SPELLCAST_SUCCEEDED = true }
    end }
    assertEqual(table.concat(inst.NS.State.rejectedEvents, ","), "UNIT_SPELLCAST_SUCCEEDED")
    local log = spy(inst.NS, "OnSpellSucceeded")
    assertEqual(inst.NS.DeliverEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 5384), 0)
    assertEqual(#log, 0, "a rejected event reached its handler")
end)

test("Dispatch: a RealEventFilter answering true consumes the event", function()
    local inst = T.load{ enable = true }
    local ns = inst.NS
    local seen = watch(inst, MSG.ROSTER_CHANGED)
    local delivered = 0
    local real = ns.DeliverEvent
    ns.DeliverEvent = function(...) delivered = delivered + 1; return real(...) end
    local asked
    ns.RealEventFilter = function(event, ...) asked = { event, ... }; return true end
    ns:OnGameEvent("GROUP_ROSTER_UPDATE", "x")
    assertEqual(seen.n, 0, "a consumed event was sent")
    assertEqual(delivered, 0, "a consumed event reached DeliverEvent")
    assertEqual(asked[1], "GROUP_ROSTER_UPDATE")
    assertEqual(asked[2], "x", "the filter did not get the event's arguments")

    ns.RealEventFilter = function() return false end
    ns:OnGameEvent("GROUP_ROSTER_UPDATE")
    assertEqual(seen.n, 1, "a filter answering false must let the event through")
    assertEqual(delivered, 1)
    ns.RealEventFilter = nil
end)

test("Dispatch: RealEventFilter is nil until the simulator sets it", function()
    local inst = T.load{ enable = true }
    assertNil(inst.NS.RealEventFilter)
end)

test("Dispatch: DeliverEvent ignores the filter", function()
    local inst = T.load{ enable = true }
    local seen = watch(inst, MSG.ROSTER_CHANGED)
    inst.NS.RealEventFilter = function() return true end
    assertEqual(inst.NS.DeliverEvent("GROUP_ROSTER_UPDATE"), 1)
    assertEqual(seen.n, 1)
    inst.NS.RealEventFilter = nil
end)

test("Dispatch: the event's arguments reach the handler", function()
    local inst = T.load{ enable = true }
    local ns = inst.NS
    local session = spy(ns, "OnMeterSession")
    local world = spy(ns, "OnEnteringWorld")
    ns:OnGameEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", 2, 17)
    ns.DeliverEvent("PLAYER_ENTERING_WORLD", false, true)
    assertEqual(#session, 1)
    assertEqual(session[1][1], "DAMAGE_METER_COMBAT_SESSION_UPDATED")
    assertEqual(session[1][2], 2, "statType was lost")
    assertEqual(session[1][3], 17, "sessionID was lost")
    assertEqual(#world, 1)
    assertEqual(world[1][1], "PLAYER_ENTERING_WORLD")
    assertEqual(world[1][2], false, "isLogin was lost")
    assertEqual(world[1][3], true, "isReload was lost")
    assertEqual(world[1].n, 3)
end)

test("Dispatch: the real payload still reaches the bus through OnGameEvent", function()
    local inst = T.load{ enable = true }
    local seen = watch(inst, MSG.METER_SESSION)
    inst.NS:OnGameEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED", 2, 17)
    assertEqual(seen.n, 1)
    assertEqual(seen.last.type, 2)
    assertEqual(seen.last.sessionID, 17)
end)
