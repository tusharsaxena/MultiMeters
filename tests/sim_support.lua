-- tests/sim_support.lua — shared helpers for the simulator suites (MultiMeters#60).
--
-- Loaded with dofile by the suites that need a running session; it registers no case of its own.
--
local S = {}

-- AN INJECTED SCENARIO. modules/Sim.lua binds the instance's one seam to the live NS.Sim at load,
-- and one seam binds one session for good, so every suite drives that instance. `S.inject` lists a
-- scenario named "case" whose timeline is the case's own steps, each played by its `run` function,
-- and answers a function that takes it back out. It changes nothing else: the start still runs
-- the host's real refusal and prepare (tests/test_sim_session.lua relies on exactly that).
--
-- A THROWAWAY SESSION. `S.testSession` starts that scenario for a suite that wants the seam's
-- providers answering out of a world it built itself (tests/test_sim_world.lua,
-- tests/test_sim_drivers.lua): the host's refusal and prepare are swapped for the case, so the
-- world the case put on NS.SimHost.world stays the session's. `done()` stops the session and puts
-- everything back. Each case takes a FRESH instance (T.load{}).

--- List the "case" scenario on `inst`'s host.
--- @param inst table  a fresh instance from T.load{}
--- @param steps table|nil  the scenario's timeline: { { label, run = fn }, ... }
--- @return function  undo
function S.inject(inst, steps)
    local Host = inst.NS.SimHost
    local names, defs = Host.SCENARIOS.names, Host.SCENARIOS.defs
    local savedPlay = Host.Play
    names[#names + 1] = "case"
    defs.case = { label = "Case", timeline = function() return steps or {} end }
    Host.Play = function(step) if step.run then return step.run() end end
    return function()
        for i = #names, 1, -1 do if names[i] == "case" then table.remove(names, i) end end
        defs.case = nil
        Host.Play = savedPlay
    end
end

--- Start the injected scenario on the live NS.Sim, keeping the case's own world.
--- @param inst table  a fresh instance from T.load{}
--- @param steps table|nil  the scenario's timeline
--- @return table sim, function done
function S.testSession(inst, steps)
    local ns = inst.NS
    local Host, sim = ns.SimHost, ns.Sim
    local preset = Host.world
    local undo = S.inject(inst, steps)
    local savedPrepare, savedRefusal = Host.Prepare, Host.Refusal
    Host.Prepare = function(_, _, _, ready) Host.world = preset; ready() end
    Host.Refusal = function() return nil end
    assert(sim:Start{ scenario = "case" }, "the test session did not start")
    local function done()
        sim:Stop()
        Host.Prepare, Host.Refusal = savedPrepare, savedRefusal
        undo()
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

-- THE SNAPSHOT. A deep serialization of NS.db.profile and NS.db.global, keys sorted, so a suite can
-- prove a session leaves both SavedVariables stores byte-identical (H4).

local function serialize(v, out, seen)
    local t = type(v)
    if t == "string" then out[#out + 1] = ("%q"):format(v); return end
    if t ~= "table" then out[#out + 1] = tostring(v); return end
    if seen[v] then out[#out + 1] = "<cycle>"; return end
    seen[v] = true
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta < tb end
        if ta == "number" or ta == "string" then return a < b end
        return tostring(a) < tostring(b)
    end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
        serialize(k, out, seen)
        out[#out + 1] = "="
        serialize(v[k], out, seen)
        out[#out + 1] = ","
    end
    out[#out + 1] = "}"
    seen[v] = nil
end

--- The instance's profile and global stores as one string.
--- @param ns table  inst.NS
--- @return string
function S.snapshot(ns)
    local out = {}
    serialize({ profile = ns.db.profile, global = ns.db.global }, out, {})
    return table.concat(out)
end

return S
