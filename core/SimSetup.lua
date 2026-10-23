local addonName, NS = ...
-- core/SimSetup.lua — the simulator's answer seam, on LibKa0s-Sim-1.0 (library-stack-§7;
-- MultiMeters#60, LibKa0s#54; the host contract H1-H10 is in libs/LibKa0s's docs/api/Sim/).
--
-- THE SEAM. At load, straight after core/Compat.lua and before any other file can read a member
-- (the LOAD-BEARING TOC slot, host contract H2), Sim:NewSeam wraps every NS.Compat function member in
-- place, once, except the PURE ones below. While a simulation session runs, a wrapped member asks the
-- simulator's provider first; idle, it calls straight through to the live member, so the whole cost
-- of the seam is one field test per call. This file names no client API: core/Compat.lua stays the
-- only caller (compat). A member added to NS.Compat after this file loads, or one replaced by
-- assignment, escapes the wrap; the seam's Unwrapped() lists it, and tests/test_sim_seam.lua asserts
-- that list is empty after the whole addon loads.
--
-- PURE. The members that answer for nobody: the real player's spec and real spells (the simulator's
-- invented group casts real spell IDs, so the client names them), the number formatters, the menu
-- and art helpers, the bar interpolation enum, the real player's travel state, and the recap
-- discovery probes the diagnostics dump runs against the real API. Never wrapped.
--
-- GUARDED. The three members that act on the world. While a session runs their live bodies never
-- run, whatever a provider or a caller does (inside Live included):
--   * ResetAllCombatSessions clears the simulated world's segments and fires the client's reply,
--     DAMAGE_METER_RESET, on the session's timer, as the real reset's would arrive. It never calls
--     the client, so a reset during a simulation leaves the real meter's data alone.
--   * ChatSender answers a sender that prints `[sim] <chatType>[ -> target]: <text>` through NS.Print
--     and counts the send on the session. The export's staggered timer may call it after a stop; it
--     still only prints.
--   * OpenDeathRecap prints one line and answers false, so modules/DrillDown.lua falls back to its
--     own breakdown: Blizzard's recap cannot open a death the client never saw.
-- Each reads NS.Sim and NS.SimHost at call time. modules/SimWorld.lua supplies NS.SimHost.World and
-- the session's NS.SimHost.world; until both exist the reset's world step is a no-op.
--
-- HOST TABLES (OWNER_SCOPE C.4). NS.SimHost is the host's own table for host fields (its world, the
-- GUARDED table the seam suite reads); NS.SimSeam is the seam, held for SetProvider and Live.
-- Nothing host-side is ever written onto the library instance or the seam.
--
-- LIBRARY ABSENT. Nothing is wrapped. NS.SimSeam is the inert seam stub and NS.Sim the inert
-- session stub, both the library's reference copies (LibKa0s tests/test_sim_stub.lua): every member
-- answers, nothing simulates, and /mm sim says the simulator needs the library. When the library is
-- present NS.Sim is the live instance modules/Sim.lua builds with Sim:New.

local Sim = LibStub and LibStub("LibKa0s-Sim-1.0", true)
local L = NS.L

NS.SimHost = NS.SimHost or {}

-- The members that answer for nobody. Never wrapped.
local PURE = {
    -- the real player and real spells
    GetSpellInfo = true, GetSpellTexture = true,
    GetSpecialization = true, GetSpecializationInfo = true, GetSpecializationRole = true,
    -- diagnostics probes of the real recap API (core/Diagnostics_DeathRecap.lua)
    RecapMembers = true, RecapAPIs = true, CallRecap = true,
    -- text helpers: the client's number formatters
    CreateAbbreviatedNumberFormatter = true, GetDefaultAbbreviationBreakpoints = true,
    CreateNumericRuleFormatter = true,
    -- the context menu, texture and atlas helpers, and the bar interpolation enum
    OpenContextMenu = true, FirstTexture = true, FirstAtlas = true, BarInterpolation = true,
    -- the real player's travel state
    IsSkyriding = true, IsInHousing = true,
}

-- ── the guarded answers ───────────────────────────────────────────────────────────────────────

--- Clear the simulated world's segments; the client's reply arrives on the session's timer.
--- @return boolean  always true: the simulated reset was made
local function guardedReset()
    local H = NS.SimHost
    if H.World and H.World.ResetSegments and H.world then H.World.ResetSegments(H.world) end
    local sim = NS.Sim
    if sim then sim:After(0, function() sim:Fire("DAMAGE_METER_RESET") end) end
    return true
end

--- One simulated send: printed, counted, never sent.
local function simSend(text, chatType, _, target)
    NS.Print(("[sim] %s%s: %s"):format(chatType or "SAY", target and (" -> " .. target) or "",
        tostring(text)))
    local sim = NS.Sim
    local session = sim and sim:Session() or {}
    session.mmSends = (session.mmSends or 0) + 1
end

--- @return function  the simulated sender, in place of the client's SendChatMessage
local function guardedChatSender()
    return simSend
end

--- @return boolean  false: the client's recap UI was not called
local function guardedOpenDeathRecap()
    NS.Print(L["Blizzard\226\128\153s death recap cannot open a simulated death."])
    return false
end

local GUARDED = {
    ResetAllCombatSessions = guardedReset,
    ChatSender = guardedChatSender,
    OpenDeathRecap = guardedOpenDeathRecap,
}
NS.SimHost.Guarded = GUARDED

-- ── the degradation stubs (host contract H9) ──────────────────────────────────────────────────

local function newSeamStub()
    local seam = {}
    function seam.SetProvider() end
    function seam.Live(_, fn, ...) return fn(...) end
    function seam.Keys() return {} end
    function seam.Unwrapped() return {} end
    return seam
end

local function newSimStub(say)
    local line = L["The simulator needs LibKa0s-Sim-1.0."]
    local sim = {}
    local function no() return false end
    local function noop() end
    local function absent() return false, "absent" end
    sim.IsActive, sim.IsDelivering, sim.IsPanelShown = no, no, no
    function sim.Fire() return 0 end
    function sim.DeliverForCleanup() return 0 end
    function sim.After() return nil end
    function sim.Start() say(line); return false, line end
    sim.Stop = no
    sim.OnStop, sim.OnStopGuarded, sim.AddListener = noop, noop, noop
    function sim.Status() return { active = false } end
    function sim.Session() return nil end
    function sim.Steps() return {} end
    function sim.Step() return nil, "absent" end
    sim.Run, sim.Pause, sim.Resume, sim.Restart = absent, absent, absent, absent
    function sim.RunVerb() say(line); return false, "absent" end
    sim.ShowPanel, sim.TogglePanel = no, no
    sim.HidePanel, sim.RefreshPanel, sim.ResetPanelPosition = noop, noop, noop
    function sim.PanelRows() return {} end
    return sim
end

-- ── the seam ──────────────────────────────────────────────────────────────────────────────────

if Sim then
    NS.SimSeam = Sim:NewSeam(NS.Compat, {
        name = addonName,
        pure = PURE,
        guarded = GUARDED,
        -- Resolved at call time: core/DebugLogSetup.lua, which publishes NS.Debug, loads later.
        debug = function(tag, fmt, ...) if NS.Debug then NS.Debug(tag, fmt, ...) end end,
    })
else
    NS.SimSeam = newSeamStub()
    -- NS.Print is resolved at call time: core/CoreSetup.lua, which publishes it, loads later.
    NS.Sim = newSimStub(function(line) NS.Print(line) end)
end
