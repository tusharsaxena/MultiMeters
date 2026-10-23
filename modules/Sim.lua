local _, NS = ...
-- modules/Sim.lua — the simulator's session host, on LibKa0s-Sim-1.0 (MultiMeters#60; the host
-- contract H1-H10 is in libs/LibKa0s's docs/api/Sim/). Binds NS.SimSeam (core/SimSetup.lua) to one
-- session with Sim:New and publishes it as NS.Sim. Everything that is MultiMeters' own lives on
-- NS.SimHost, never on the library's instance or the seam.
--
-- ── THE PRINCIPLE ────────────────────────────────────────────────────────────────────────────
--
-- `/mm sim` plays a scripted fight through the REAL meter. The simulator invents the inputs at the
-- edges (the seam's providers, modules/SimWorld.lua; the events modules/SimDrivers.lua fires through
-- NS.Sim:Fire, which this descriptor hands to NS.DeliverEvent, core/MultiMeters.lua) and the engine
-- reads, joins, sorts and draws every row exactly as it does in game. Test mode is the opposite
-- (fixed preview data at the provider), so each refuses while the other runs.
--
-- ── LOAD ORDER (LOAD-BEARING) ────────────────────────────────────────────────────────────────
--
-- This file builds NS.Sim with the host's own tables, Host.SCENARIOS and Host.PANEL, and the files
-- after it in the TOC (modules/SimWorld.lua, modules/SimDrivers.lua, modules/SimScenario.lua) fill
-- them in place. The library reads every descriptor table at use, so a later fill is seen.
--
-- ── SAVED DATA STAYS UNTOUCHED (H4) ──────────────────────────────────────────────────────────
--
-- A session reaches two SavedVariables stores, and neither is written:
--   * db.global.roster, the remembered roster: modules/Roster.lua's remembered() answers the
--     session's own `mmRoster` while a session is active, and Roster.Forget replaces only that.
--   * each window's pin (`window.data.sessionID` / `sessionType`): snapshotted by the start into
--     `session.mmPins` and written back by the stop; WindowProto:DropStaleSegment does nothing while
--     a session is active, because the simulated session list is not the client's holdings.
-- tests/test_sim_session.lua's before/after snapshot proves the profile and global stores come back
-- byte-identical.
--
-- ── REAL INPUT DURING A SESSION ──────────────────────────────────────────────────────────────
--
-- Every real game event reaches NS:OnGameEvent, which asks NS.RealEventFilter first. The start sets
-- it to Host.OnRealEvent and the stop puts nil back. The classifier (EVENT_RULES) either stops the
-- session and lets the event run live (combat, a world entry, a real group, a real instance), or
-- consumes it (the client's meter events: the world owns the meter; a solo roster or zone move).
-- Anything else runs live. The stand-down stops a session first of all (core/LifecycleSetup.lua,
-- H6), and a profile swap, copy or reset stops it (core/Database.lua's fireProfileChanged).
--
-- ── THE STOP ─────────────────────────────────────────────────────────────────────────────────
--
-- The library's two-phase stop runs STOP_STEPS with the seam already off, each under pcall. The
-- resync goes through ENTERING_WORLD, METER_SESSION and COMBAT_CHANGED and NEVER through
-- METER_RESET: that message makes Roster.Forget wipe the REAL db.global.roster once the seam is off.

NS.SimHost = NS.SimHost or {}
local Host = NS.SimHost
local L = NS.L
local MSG = NS.Constants.MSG

--- The pause, in seconds, after each step before a playing simulation plays the next one. A fixed
--- constant, as KickCD's is: no settings row (the run's lead decision on MM-18).
Host.STEP_DELAY = 1

--- The seconds a playing simulation waits between steps (the descriptor's stepDelay).
function Host.StepDelay()
    return Host.STEP_DELAY
end

--- The scenarios, filled in place by modules/SimScenario.lua (the library reads them at use).
Host.SCENARIOS = Host.SCENARIOS or { names = {}, defs = {} }

--- The step panel's presentation fields, filled below; the step's own label and tip are written
--- onto each step by modules/SimScenario.lua.
Host.PANEL = Host.PANEL or {}

local function debug(fmt, ...)
    if NS.State and NS.State.debug and NS.Debug then NS.Debug("Sim", fmt, ...) end
end

-- ── refusals ──────────────────────────────────────────────────────────────────────────────────

local function disabledLine()
    local Sl = NS.Slash
    if Sl and Sl.DisabledLine then return Sl:DisabledLine() end
    return L["A simulation cannot start while the addon is disabled."]
end

-- Each answers (line, guard) or nil, checked in this order. The library runs the refusal inside
-- NS.SimSeam:Live, so every read below answers the real client.
local CHECKS = {
    function()
        if NS.IsStoodDown() then return disabledLine(), "stoodDown" end
    end,
    function()
        if NS.State.testMode then return L["Turn test mode off before starting a simulation."], "testMode" end
    end,
    function()
        local lockdown = _G.InCombatLockdown and _G.InCombatLockdown()
        if NS.Compat.UnitAffectingCombat("player") or lockdown then
            return L["A simulation cannot start in combat."], "combat"
        end
    end,
    function()
        if (NS.Compat.IsInInstance()) then return L["A simulation cannot start in an instance."], "instance" end
    end,
    function()
        if NS.Compat.IsInGroup() then return L["Leave your group before starting a simulation."], "group" end
    end,
    function()
        if NS.MasterSetting("visibility") == "never" then
            return L["A simulation cannot start while General visibility hides every window."], "visibility"
        end
    end,
}

--- Why a simulation may not start now, as the one line to print, or nil when it may. The library
--- has already refused an unknown scenario and a second session.
function Host.Refusal(opts)
    for i = 1, #CHECKS do
        local line, guard = CHECKS[i](opts)
        if line then
            debug("start refused: %s", guard)
            return line
        end
    end
    return nil
end

--- The host gate: closed while booked fight ticks are still to run.
--- @return boolean open, string|nil line
function Host.Gate(_)
    local w = Host.world
    if w and (w.pending or 0) > 0 then return false, L["The fight is still running."] end
    return true
end

-- ── the real-event classifier ─────────────────────────────────────────────────────────────────

local function liveInGroup() return NS.SimSeam:Live(function() return NS.Compat.IsInGroup() end) end
local function liveInInstance()
    return NS.SimSeam:Live(function() return (NS.Compat.IsInInstance()) end)
end

local function stop(reason) NS.Sim:Stop(reason) end

-- Each answers true to consume the real event, false to let it run live.
local function stopThenDeliver(reason)
    return function() stop(reason); return false end
end

local function stopWhen(reason, read)
    return function()
        if read() then stop(reason); return false end
        return true
    end
end

local function consume() return true end

local function restrictionEdge(_, state)
    local inactive = NS.Secrets and NS.Secrets.STATE and NS.Secrets.STATE.Inactive
    if state ~= inactive then stop("combat") end
    return false
end

local EVENT_RULES = {
    PLAYER_REGEN_DISABLED = stopThenDeliver("combat"),
    ADDON_RESTRICTION_STATE_CHANGED = restrictionEdge,
    PLAYER_ENTERING_WORLD = stopThenDeliver("world"),
    GROUP_ROSTER_UPDATE = stopWhen("group", liveInGroup),
    ZONE_CHANGED_NEW_AREA = stopWhen("instance", liveInInstance),
    DAMAGE_METER_CURRENT_SESSION_UPDATED = consume,
    DAMAGE_METER_COMBAT_SESSION_UPDATED = consume,
    DAMAGE_METER_RESET = consume,
}
Host.EVENT_RULES = EVENT_RULES

--- NS.RealEventFilter while a session runs (the real path only): true consumes the event, false
--- lets it run live, after stopping the session when it ends one.
function Host.OnRealEvent(event, ...)
    local sim = NS.Sim
    if not (sim and sim:IsActive()) then return false end
    local rule = EVENT_RULES[event]
    if not rule then return false end
    local consumed = rule(...)
    debug("real %s: %s", tostring(event), consumed and "consumed" or "delivered")
    return consumed
end

-- ── the start (the descriptor's prepare) ──────────────────────────────────────────────────────

local function realPlayer()
    local C = NS.Compat
    local _, classFilename = C.UnitClass("player")
    local spec = C.GetSpecialization and C.GetSpecialization()
    local role = spec and C.GetSpecializationRole and C.GetSpecializationRole(spec) or nil
    return { guid = C.UnitGUID("player"), name = C.UnitName("player"), classFilename = classFilename, role = role }
end

local function snapshotPins()
    local pins = {}
    for _, w in ipairs(NS.Database.GetWindows()) do
        local d = type(w.data) == "table" and w.data or {}
        if w.id ~= nil then pins[w.id] = { sessionID = d.sessionID, sessionType = d.sessionType } end
    end
    return pins
end

--- Build the session: the world (the real player as its local player), the pin snapshot, the real
--- event filter, the SIM_CHANGED edge and the empty simulated meter, the step panel, then ready.
--- No window is force-shown: each window's visibility rules answer the simulated world.
function Host.Prepare(session, _, opts, ready)
    local player = NS.SimSeam:Live(realPlayer)
    local World = Host.World
    Host.world = World and World.New(opts and opts.seed, player) or nil
    session.mm = Host.world
    session.mmPins = snapshotPins()
    NS.RealEventFilter = Host.OnRealEvent
    NS:SendMessage(MSG.SIM_CHANGED, { active = true })
    NS.Sim:Fire("DAMAGE_METER_RESET")
    local sim = NS.Sim
    if sim and sim.ShowPanel then sim:ShowPanel() end
    debug("world built for %s (seed %s)", tostring(opts and opts.scenario), tostring(opts and opts.seed))
    ready()
end

-- ── the stop ──────────────────────────────────────────────────────────────────────────────────

local function restorePins(session, reason)
    -- A profile change's snapshot belongs to the profile that is gone. A simulated id left in the
    -- old one heals through DropStaleSegment the next time that profile is shown.
    if reason == "profile" then return end
    for id, v in pairs(session.mmPins or {}) do
        local inst = NS.WindowManager.Get(id)
        local d = inst and inst.config and inst.config.data
        if d and (d.sessionID ~= v.sessionID or d.sessionType ~= v.sessionType) then
            NS.SetByPaths({ { "window.data.sessionID", v.sessionID }, { "window.data.sessionType", v.sessionType } }, id)
        end
    end
end

local function resync()
    -- NEVER MSG.METER_RESET here: with the seam off it makes Roster.Forget wipe the REAL
    -- db.global.roster. ENTERING_WORLD rebuilds the live roster, invalidates the Provider memo,
    -- forgets the feign state and re-asks visibility; METER_SESSION re-reads the meter.
    NS:SendMessage(MSG.ENTERING_WORLD, { isLogin = false, isReload = false })
    NS:SendMessage(MSG.METER_SESSION, {})
    NS:SendMessage(MSG.COMBAT_CHANGED)
end

local STOP_STEPS = {
    function()
        if NS.RealEventFilter == Host.OnRealEvent then NS.RealEventFilter = nil end
    end,
    restorePins,
    function() NS.State.WipeCache() end,
    resync,
    function()
        local D = NS.DrillDown
        if D and D.OnMeterReset then D:OnMeterReset() end
    end,
    function() NS:SendMessage(MSG.SIM_CHANGED, { active = false }) end,
    function(session, reason)
        local w = session.mm or Host.world
        Host.lastStop = { reason = tostring(reason), events = session.events or 0, sends = session.mmSends or 0,
            segments = w and #w.segments or 0 }
        debug("simulation stopped (%s): %d events, %d sends", tostring(reason), Host.lastStop.events,
            Host.lastStop.sends)
        Host.world = nil
    end,
}

-- ── the descriptor ────────────────────────────────────────────────────────────────────────────

local STOP_TEXT = {
    combat    = L["Simulation stopped: you entered combat."],
    world     = L["Simulation stopped: you entered the world (a loading screen)."],
    group     = L["Simulation stopped: you joined a group."],
    instance  = L["Simulation stopped: you entered an instance."],
    profile   = L["Simulation stopped: the profile changed."],
    standDown = L["Simulation stopped: the addon stood down (disabled, or a performance capture)."],
}

-- STARTED makes the saved-data claim the library leaves to its host (H4); the before/after
-- snapshot in tests/test_sim_session.lua backs it.
local LINES = {
    STARTED = L["Simulation started (%s): a scripted fight through the real meter. Nothing is saved or sent; /mm sim stop ends it."],
}

--- The status verb's extra line: segments the world holds, fight ticks still booked, sends printed.
function Host.StatusLine(_, session)
    if not session then return nil end
    local w = session.mm or Host.world
    return L["Segments held: %d, ticks pending: %d, sends: %d."]:format(w and #w.segments or 0,
        w and w.pending or 0, session.mmSends or 0)
end

--- The step panel docks to the first shown window, else floats.
function Host.PanelAnchor()
    for _, inst in ipairs(NS.WindowManager.All()) do
        if inst:IsShown() then return inst.frame end
    end
    return nil
end

local P = Host.PANEL
P.title = L["Multi Meters - Simulation"]
P.anchorTo = function() return Host.PanelAnchor() end
P.check = NS.Icon("confirm")
P.startTip = {
    { L["Plays"], L["a scripted fight through the real meter"] },
    { L["Saves"], L["nothing: your roster and segment pins are not touched"] },
}
P.stopTip = {
    { L["Ends"], L["the simulation"] },
    { L["Restores"], L["your live meter in every window"] },
}
P.stepLabel = function(step) return type(step) == "table" and step.label or nil end
P.stepTip = function(step) return type(step) == "table" and step.tip or nil end

local Lib = LibStub and LibStub("LibKa0s-Sim-1.0", true)
if Lib then
    NS.Sim = Lib:New({
        name = "MultiMeters",
        seam = NS.SimSeam,
        slash = "/mm sim",
        deliver = function(e, ...) return NS.DeliverEvent(e, ...) end,
        isStoodDown = function() return NS.IsStoodDown() end,
        scenarios = Host.SCENARIOS,
        prepare = function(...) return Host.Prepare(...) end,
        play = function(step, s) return Host.Play and Host.Play(step, s) end,
        refusal = function(opts) return Host.Refusal(opts) end,
        gate = function(session) return Host.Gate(session) end,
        stepDelay = function() return Host.StepDelay() end,
        stopText = STOP_TEXT,
        L = LINES,
        print = function(line) NS.Print(line) end,
        debug = function(_, fmt, ...) debug(fmt, ...) end,
        panel = P,
        statusLine = function(status, session) return Host.StatusLine(status, session) end,
    })
end
-- Library absent: NS.Sim stays core/SimSetup.lua's inert stub, whose OnStop does nothing.

for _, step in ipairs(STOP_STEPS) do NS.Sim:OnStop(step) end
