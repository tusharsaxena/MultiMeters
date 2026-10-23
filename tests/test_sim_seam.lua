-- tests/test_sim_seam.lua — the simulator's answer seam (core/SimSetup.lua) on LibKa0s-Sim-1.0.
--
-- MM-12 (MultiMeters#60). core/SimSetup.lua wraps NS.Compat with Sim:NewSeam straight after
-- core/Compat.lua: the PURE members are left alone, three members are GUARDED, and every other
-- function member is wrapped. These cases pin the host contract the library cannot enforce for us
-- (LibKa0s docs/api/Sim, H1, H2 and H9): nothing escapes the wrap, the TOC slot, the three guarded
-- answers never reach the client while a session runs, and the degradation stubs carry the whole
-- live surface.
--
-- A SESSION NEVER RUNS ON THE INSTANCE'S OWN SEAM. One seam binds one session for good, and the
-- addon's simulator module binds NS.SimSeam itself, so the guarded cases build a SECOND, test-only
-- seam over a copy of an isolated instance's Compat table, hand it the GUARDED table this file
-- publishes on NS.SimHost, and bind a bare session to that. The guarded answers read NS.Sim at
-- call time, so the case points the isolated instance's NS.Sim at the test session.

local T = _G.MULTIMETERS_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- The members that answer for nobody: the real player, real spells, text and texture helpers and
-- the diagnostics probes. Kept in step with core/SimSetup.lua's PURE by the cases below.
local PURE = {
    "BarInterpolation", "CallRecap", "CreateAbbreviatedNumberFormatter", "CreateNumericRuleFormatter",
    "FirstAtlas", "FirstTexture", "GetDefaultAbbreviationBreakpoints", "GetSpecialization",
    "GetSpecializationInfo", "GetSpecializationRole", "GetSpellInfo", "GetSpellTexture",
    "IsInHousing", "IsSkyriding", "OpenContextMenu", "RecapAPIs", "RecapMembers",
}
local GUARDED = { "ChatSender", "OpenDeathRecap", "ResetAllCombatSessions" }

local function set(list)
    local out = {}
    for _, k in ipairs(list) do out[k] = true end
    return out
end

--- A bare session on a second, test-only seam whose guarded answers are core/SimSetup.lua's.
--- @return table sim, table compat (the second seam's wrapped copy), table fired (delivered events)
local function guardedSession(inst)
    local ns, m = inst.NS, inst.mocks
    local Sim = m.LibStub("LibKa0s-Sim-1.0", true)
    assertTrue(Sim ~= nil, "the instance has no LibKa0s-Sim-1.0")
    assertTrue(type(ns.SimHost.Guarded) == "table", "core/SimSetup.lua does not publish its GUARDED table")
    local compat = {}
    for k, v in pairs(ns.Compat) do compat[k] = v end
    local seam = Sim:NewSeam(compat, { name = "MultiMetersTest", pure = set(PURE), guarded = ns.SimHost.Guarded })
    local fired = {}
    local sim = Sim:New{
        name = "MultiMetersTest", seam = seam, slash = "/mm sim",
        deliver = function(event) fired[#fired + 1] = event; return 1 end,
        isStoodDown = function() return false end,
        scenarios = { names = { "bare" }, defs = { bare = { label = "Bare", timeline = function() return {} end } } },
        prepare = function(_, _, _, ready) ready() end,
        play = function() end,
        print = function() end,
    }
    ns.Sim = sim
    assertTrue(sim:Start{ scenario = "bare" }, "the bare session did not start")
    return sim, compat, fired
end

-- ── the seam on the fully-loaded addon ────────────────────────────────────────────────────────

test("Sim seam: the vendored LibKa0s-Sim-1.0 registered and NS.SimSeam is its seam", function()
    assertTrue(T.mocks.LibStub("LibKa0s-Sim-1.0", true) ~= nil, "LibKa0s-Sim-1.0 did not register")
    assertTrue(type(NS.SimSeam) == "table" and type(NS.SimSeam.Unwrapped) == "function",
        "NS.SimSeam is not a seam")
    assertTrue(type(NS.SimHost) == "table", "NS.SimHost, the host's own table, is missing")
end)

test("Sim seam: Unwrapped() is EMPTY after the whole addon loads (host contract H2)", function()
    local escaped = NS.SimSeam:Unwrapped()
    assertEqual(#escaped, 0, "Compat members escaped the wrap: " .. table.concat(escaped, ", "))
end)

test("Sim seam: Keys() is every non-PURE Compat function, and no PURE key is wrapped", function()
    local pure, keys = set(PURE), set(NS.SimSeam:Keys())
    for _, k in ipairs(PURE) do
        assertTrue(type(NS.Compat[k]) == "function", k .. " is not a Compat function member")
        assertTrue(not keys[k], k .. " is pure and must not be wrapped")
    end
    local want = {}
    for k, v in pairs(NS.Compat) do
        if type(v) == "function" and not pure[k] then want[#want + 1] = k end
    end
    table.sort(want)
    assertTrue(#want >= 20, "the Compat scan found only " .. #want .. " members")
    assertEqual(table.concat(NS.SimSeam:Keys(), ","), table.concat(want, ","))
    for _, k in ipairs(GUARDED) do assertTrue(keys[k], k .. " is guarded, so it must be wrapped") end
end)

test("Sim seam: idle, a wrapped member reaches the client", function()
    local inst = T.load{}
    assertEqual(inst.NS.Compat.UnitGUID("player"), inst.mocks.UnitGUID("player"),
        "an idle wrapped UnitGUID did not answer the client's GUID")
    assertTrue(inst.NS.Compat.UnitGUID("player") ~= nil, "the mock has no player GUID to compare")
end)

-- ── the three guarded answers, while a session runs ───────────────────────────────────────────

test("Sim seam: a guarded ResetAllCombatSessions never reaches the client and replies by timer", function()
    local inst = T.load{}
    local m = inst.mocks
    local resets = {}
    inst.NS.SimHost.World = { ResetSegments = function(w) resets[#resets + 1] = w end }
    inst.NS.SimHost.world = { segments = {} }
    local sim, compat, fired = guardedSession(inst)
    local before = m.__meter.calls.ResetAllCombatSessions or 0
    assertEqual(compat.ResetAllCombatSessions(), true, "the guarded reset did not answer true")
    assertEqual(m.__meter.calls.ResetAllCombatSessions or 0, before, "the guarded reset reached the client")
    assertEqual(#resets, 1, "the guarded reset did not reset the simulated world")
    assertTrue(resets[1] == inst.NS.SimHost.world, "the guarded reset did not pass the simulated world")
    assertEqual(#fired, 0, "DAMAGE_METER_RESET fired synchronously")
    m.__fireTimers()
    assertEqual(table.concat(fired, ","), "DAMAGE_METER_RESET", "the reset's reply did not fire")
    sim:Stop()
end)

test("Sim seam: a guarded ResetAllCombatSessions is inert with no simulated world", function()
    local inst = T.load{}
    local sim, compat = guardedSession(inst)
    local before = inst.mocks.__meter.calls.ResetAllCombatSessions or 0
    assertEqual(compat.ResetAllCombatSessions(), true)
    assertEqual(inst.mocks.__meter.calls.ResetAllCombatSessions or 0, before)
    sim:Stop()
end)

test("Sim seam: a guarded ChatSender prints '[sim] RAID: x' and sends nothing", function()
    local inst = T.load{}
    local m = inst.mocks
    local sent = 0
    m.C_ChatInfo = m.C_ChatInfo or {}
    m.C_ChatInfo.SendChatMessage = function() sent = sent + 1 end
    m.SendChatMessage = function() sent = sent + 1 end
    local sim, compat = guardedSession(inst)
    local sender = compat.ChatSender()
    assertTrue(type(sender) == "function", "the guarded ChatSender answered no sender")
    local chatBefore = #m.__chat
    sender("x", "RAID")
    sender("y", "WHISPER", nil, "Someone")
    assertEqual(sent, 0, "the guarded sender reached the client's SendChatMessage")
    local said = table.concat(m.__chat, "\n", chatBefore + 1, #m.__chat)
    assertTrue(said:find("[sim] RAID: x", 1, true) ~= nil, "no '[sim] RAID: x' line: " .. said)
    assertTrue(said:find("[sim] WHISPER -> Someone: y", 1, true) ~= nil, "no whisper line: " .. said)
    assertEqual(sim:Session().mmSends, 2, "the session did not count the simulated sends")
    sim:Stop()
    -- After the stop the seam is idle again, and the live sender is the client's.
    assertTrue(compat.ChatSender() == m.C_ChatInfo.SendChatMessage, "the stopped seam still guards")
end)

test("Sim seam: a guarded OpenDeathRecap prints, answers false and never opens the client's recap", function()
    local inst = T.load{}
    local m = inst.mocks
    local sim, compat = guardedSession(inst)
    local opened = m.__deathRecaps or 0
    local chatBefore = #m.__chat
    assertEqual(compat.OpenDeathRecap(7), false, "the guarded recap did not answer false")
    assertEqual(m.__deathRecaps or 0, opened, "the guarded recap opened the client's recap UI")
    local said = table.concat(m.__chat, "\n", chatBefore + 1, #m.__chat)
    assertTrue(said:find("cannot open a simulated death", 1, true) ~= nil, "no recap line: " .. said)
    sim:Stop()
end)

-- ── the TOC slot (H2) ─────────────────────────────────────────────────────────────────────────

test("TOC: core/SimSetup.lua loads immediately after core/Compat.lua, annotated LOAD-BEARING", function()
    local toc = T.loadedAddonFiles
    local at
    for i, p in ipairs(toc) do if p == "core/Compat.lua" then at = i end end
    assertTrue(at ~= nil, "core/Compat.lua is not in MultiMeters.toc")
    assertEqual(toc[at + 1], "core/SimSetup.lua")
    local fh = assert(io.open((T.root or ".") .. "/MultiMeters.toc", "r"))
    local src = fh:read("*a")
    fh:close()
    local lines = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = (line:gsub("\r$", "")) end
    local found = false
    for i, line in ipairs(lines) do
        if line == "core\\SimSetup.lua" then
            found = true
            local block, j = {}, i - 1
            while j >= 1 and lines[j]:match("^#") do block[#block + 1] = lines[j]; j = j - 1 end
            assertTrue(table.concat(block, "\n"):find("LOAD-BEARING", 1, true) ~= nil,
                "core\\SimSetup.lua carries no LOAD-BEARING comment directly above it")
        end
    end
    assertTrue(found, "MultiMeters.toc names no core\\SimSetup.lua line")
end)

-- ── the library absent (H9) ───────────────────────────────────────────────────────────────────

test("Sim seam: with LibKa0s absent, NS.SimSeam and NS.Sim are the stubs, at full parity", function()
    local deg = T.load{ libFiles = {} }
    local ns = deg.NS
    assertTrue(deg.mocks.LibStub("LibKa0s-Sim-1.0", true) == nil, "the library is not absent")
    assertTrue(type(ns.SimSeam) == "table" and type(ns.Sim) == "table", "the stubs are missing")
    assertEqual(#ns.SimSeam:Keys(), 0, "the seam stub wraps nothing")
    assertEqual(ns.SimSeam:Live(function(a, b) return a + b end, 2, 3), 5, "the stub's Live does not call through")
    assertEqual(ns.Sim:IsActive(), false)

    -- The live halves: a real seam over a throwaway table and a real instance bound to it.
    local Sim = T.mocks.LibStub("LibKa0s-Sim-1.0", true)
    local liveSeam = Sim:NewSeam({ Probe = function() end }, { name = "MultiMetersParity" })
    local liveSim = Sim:New{
        name = "MultiMetersParity", seam = liveSeam, slash = "/mm sim",
        deliver = function() return 0 end, isStoodDown = function() return false end,
        scenarios = { names = {}, defs = {} },
        prepare = function(_, _, _, ready) ready() end, play = function() end,
        print = function() end,
    }
    -- Both ways: the stub carries every live member, and nothing the live surface does not.
    T.assertSurfaceParity(liveSim, ns.Sim, "the session stub over the live instance", {})
    T.assertSurfaceParity(ns.Sim, liveSim, "the live instance over the session stub", {})
    T.assertSurfaceParity(liveSeam, ns.SimSeam, "the seam stub over the live seam", {})
    T.assertSurfaceParity(ns.SimSeam, liveSeam, "the live seam over the seam stub", {})

    local chatBefore = #deg.mocks.__chat
    local ok, code = ns.Sim:RunVerb("")
    assertEqual(ok, false)
    assertEqual(code, "absent")
    local said = table.concat(deg.mocks.__chat, "\n", chatBefore + 1, #deg.mocks.__chat)
    assertTrue(said:find("The simulator needs LibKa0s-Sim-1.0.", 1, true) ~= nil,
        "RunVerb did not print the NEEDS line: " .. said)
end)
