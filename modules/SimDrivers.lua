local _, NS = ...
-- modules/SimDrivers.lua — the simulator's drivers: each edits the world, then fires the client's
-- events (MultiMeters#60; Ka0sAddonsCommonTasks docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/inputs/design-mm-sim.md §2.6).
--
-- ONE RULE PER DRIVER. A driver changes the world (NS.SimHost.world, modules/SimWorld.lua) FIRST,
-- then fires the client's events through NS.Sim:Fire, with the client's payloads, in the client's
-- order. The engine is then on its own: no driver sends a bus message, writes a setting, touches a
-- window or calls the client's meter. The meter numbers the engine reads come back to it through
-- NS.Compat, which core/SimSetup.lua's seam answers out of the same world.
--
-- CALL TIME. NS.Sim is read at every call (modules/Sim.lua replaces core/SimSetup.lua's stub, and a
-- test points it at a throwaway session), and so is NS.SimHost.world (the session's prepare builds
-- it). Every timer is NS.Sim:After, never C_Timer or AceTimer: a session timer dies with its
-- session, so a fight booked before a stop never ticks into the real meter after it.
--
-- A FIGHT is a plain table the scenarios declare (modules/SimScenario.lua):
--   { name, enemy = { creatureID, name }|nil, ticks, secondsPerTick, ends = boolean,
--     deaths = { { tick, guid = <guid> | role = <role> | all = true }, ... }|nil }
-- The tick counter lives on the world (w.tick), never on the fight: a scenario's fight table is
-- shared by every run of that scenario.
--
-- FILE SCOPE. NS.SimHost.World is captured at load, so this file loads after modules/SimWorld.lua
-- (its LOAD-BEARING TOC note).

NS.SimHost = NS.SimHost or {}
local Host = NS.SimHost
local D = Host.Drivers or {}
Host.Drivers = D

local World = assert(Host.World, "modules/SimDrivers.lua loads after modules/SimWorld.lua")

--- Seconds between two booked ticks of one fight.
D.TICK = 0.5

local function fire(event, ...) return NS.Sim:Fire(event, ...) end

local function world() return Host.world end

-- ── the group and the zone ────────────────────────────────────────────────────────────────────

--- Form a group of `n` (the player first); `raid` for raid tokens.
function D.FormGroup(n, raid)
    local w = world()
    if not w then return end
    World.SetGroup(w, n, raid)
    fire("GROUP_ROSTER_UPDATE")
end

--- Leave the group: the player alone again.
function D.Disband()
    local w = world()
    if not w then return end
    World.SetGroup(w, 1)
    fire("GROUP_ROSTER_UPDATE")
end

--- Zone into `key` (SimWorld's ZONES). The client's order: the loading screen's
--- PLAYER_ENTERING_WORLD (neither a login nor a reload), then ZONE_CHANGED_NEW_AREA.
function D.Zone(key)
    local w = world()
    if not w then return end
    World.SetZone(w, key)
    fire("PLAYER_ENTERING_WORLD", false, false)
    fire("ZONE_CHANGED_NEW_AREA")
end

-- ── a fight ───────────────────────────────────────────────────────────────────────────────────

--- The living members a death entry names.
local function victims(w, death)
    if death.guid then return { death.guid } end
    local seg, out = w.current, {}
    for _, m in ipairs(w.members) do
        local alive = not (seg and seg.dead[m.guid])
        if alive and (death.all or (m.role == death.role and not m.isLocalPlayer)) then
            out[#out + 1] = m.guid
            if not death.all then break end
        end
    end
    return out
end

local function runDeaths(w, fight)
    for _, death in ipairs(fight.deaths or {}) do
        if death.tick == w.tick then
            for _, guid in ipairs(victims(w, death)) do World.Die(w, guid) end
        end
    end
end

--- One tick: the world's numbers grow by fight.secondsPerTick, any death booked for this tick
--- happens, and the meter says the current session moved.
function D.Tick(fight)
    local w = world()
    if not w then return end
    w.tick = (w.tick or 0) + 1
    World.Tick(w, fight.secondsPerTick or 1)
    runDeaths(w, fight)
    fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
end

--- The pull. The client's order: a new current segment, the player in combat,
--- PLAYER_REGEN_DISABLED, and only then the meter's first DAMAGE_METER_CURRENT_SESSION_UPDATED
--- (the first tick, which this driver runs).
function D.Pull(fight)
    local w = world()
    if not w then return end
    World.OpenSegment(w, fight.name, fight.enemy)
    w.tick = 0
    w.combat = true
    fire("PLAYER_REGEN_DISABLED")
    D.Tick(fight)
end

--- The fight ends. The client's order: out of combat and PLAYER_REGEN_ENABLED first, then the
--- meter closes the segment with one DAMAGE_METER_COMBAT_SESSION_UPDATED(type, sessionID) per
--- stat, in the catalog's order, then a last DAMAGE_METER_CURRENT_SESSION_UPDATED.
function D.EndFight(_)
    local w = world()
    if not w then return end
    w.combat = false
    World.CloseSegment(w)
    fire("PLAYER_REGEN_ENABLED")
    local seg = w.current
    if seg then
        for _, stat in ipairs(NS.Constants.STATS) do
            fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", stat.enumValue, seg.sessionID)
        end
    end
    fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
end

--- The meter reset, down the player's own path: Provider.Reset reaches the guarded
--- ResetAllCombatSessions (core/SimSetup.lua), which clears the world's segments and fires
--- DAMAGE_METER_RESET on the session's timer. The client's meter is never called.
function D.Reset()
    return NS.Provider.Reset()
end

--- One booked tick: runs only while the world it was booked on is still the session's.
local function bookedTick(w, fight, last)
    return function()
        if Host.world ~= w then return end
        w.pending = math.max(0, (w.pending or 0) - 1)
        D.Tick(fight)
        if last and fight.ends then D.EndFight(fight) end
    end
end

--- A whole fight: the pull and its first tick now, ticks 2..fight.ticks booked TICK apart on the
--- session's timer, the last one ending the fight when fight.ends. w.pending counts the bookings
--- still to run (the host's gate holds the next step while it is above 0).
--- @return string|nil  the step's detail line
function D.Fight(fight, _)
    local w = world()
    if not w then return nil end
    local ticks = math.max(1, fight.ticks or 1)
    D.Pull(fight)
    if ticks == 1 then
        if fight.ends then D.EndFight(fight) end
        return ("%d ticks booked"):format(0)
    end
    local sim = NS.Sim
    for k = 2, ticks do
        w.pending = (w.pending or 0) + 1
        sim:After(D.TICK * (k - 1), bookedTick(w, fight, k == ticks))
    end
    return ("%d ticks booked"):format(ticks - 1)
end
