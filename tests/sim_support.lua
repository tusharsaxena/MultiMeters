-- tests/sim_support.lua — shared helpers for the simulator suites (MultiMeters#60).
--
-- Loaded with dofile by the suites that need a running session; it registers no case of its own.
--
-- A THROWAWAY SESSION. Until modules/Sim.lua builds the live NS.Sim, a case that wants the seam's
-- providers to answer needs a session bound to the instance's NS.SimSeam. `S.testSession` builds
-- one in the shape of LibKa0s tests/test_sim_host.lua: a bare `LibKa0s-Sim-1.0` instance over
-- that seam, delivering through NS.DeliverEvent, with one scenario whose timeline is the case's own
-- steps, and points NS.Sim at it for the case. One seam binds one session for good, so every case
-- takes a FRESH instance (T.load{}) and hands it here; `done()` stops the session and restores
-- NS.Sim.

local S = {}

--- Start a bare session on `inst`'s own seam.
--- @param inst table  a fresh instance from T.load{}
--- @param steps table|nil  the scenario's timeline: { { label, run = fn }, ... }
--- @return table sim, function done
function S.testSession(inst, steps)
    local ns, m = inst.NS, inst.mocks
    local Sim = assert(m.LibStub("LibKa0s-Sim-1.0", true), "the instance has no LibKa0s-Sim-1.0")
    local saved = ns.Sim
    local sim = Sim:New{
        name = "MultiMetersTest", seam = ns.SimSeam, slash = "/mm sim",
        deliver = ns.DeliverEvent,
        isStoodDown = function() return false end,
        scenarios = { names = { "case" }, defs = { case = {
            label = "Case", timeline = function() return steps or {} end,
        } } },
        prepare = function(_, _, _, ready) ready() end,
        play = function(step) if step.run then step.run() end end,
        print = function() end,
    }
    ns.Sim = sim
    assert(sim:Start{ scenario = "case" }, "the test session did not start")
    local function done()
        sim:Stop()
        ns.Sim = saved
    end
    return sim, done
end

-- THE CLOCK (copied from ../LootHistory/tests/sim_support.lua). Every timer in the kit's queue is
-- given a due time when first seen, and `advance` moves the mock's GetTime and runs what falls due,
-- earliest first, so the session's NS.Sim:After bookings (a fight's ticks, the reset's reply) run in
-- the order and at the times they would in the client.

--- The clock over one instance's mocks.
--- @param m table  inst.mocks
--- @return table  { advance = function(dt) }
function S.clock(m)
    local C = {}

    local function stamp()
        for _, t in ipairs(m.__timers) do
            if t.__due == nil then t.__due = m.__now + (tonumber(t.delay) or 0) end
        end
    end

    -- The canceled flag is the kit mock's own field, under AceTimer's name for it
    -- (tests/_kit/mock_record.lua): a library field name, waived in tests/prose_waivers.lua.
    local function canceled(t) return t.cancelled or (t.timer and t.timer.cancelled) end

    --- Move the clock `dt` seconds, running every timer that falls due, earliest first (a timer
    --- set while running is due from the moment it was set).
    function C.advance(dt)
        stamp()
        local target = m.__now + dt
        while true do
            stamp()
            local best, at
            for i, t in ipairs(m.__timers) do
                if t.__due <= target and (best == nil or t.__due < best.__due) then best, at = t, i end
            end
            if not best then break end
            table.remove(m.__timers, at)
            if best.__due > m.__now then m.__now = best.__due end
            if not canceled(best) then best.fn() end
        end
        m.__now = target
    end

    return C
end

return S
