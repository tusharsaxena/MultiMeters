-- tests/test_window_simstrip.lua — the simulation strip on every window (MM-17, MultiMeters#60).
--
-- While a /mm sim session runs, every window shows the LibKa0s sim-flavored strip
-- (W.TestStrip(parent, { kind = "sim", ... }), LibKa0s Widgets minor 14) in the test strip's slot
-- under the title, and NO window's title carries a SIMULATION word (OWNER_SCOPE A). The strip is
-- not part of the header, so a window with its header hidden is still marked; a minimized window
-- shows no marker during a simulation (README Known Limitations: the step panel marks the run).
-- The reserve comes from the session state and the library's HEIGHT constant, never off a frame,
-- and like the test strip it takes its room out of the rows, never out of the window.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local S = dofile((T.root or ".") .. "/tests/sim_support.lua")

local SIM_LINE = "SIMULATION: a scripted fight, not your data. /mm sim stop ends it."

--- A fresh enabled instance with the "case" scenario listed and a second window created, so
--- "every window" means more than one.
--- @return table inst, function undo
local function fresh(opts)
    local inst = T.load(opts or { enable = true })
    local undo = S.inject(inst, { { kind = "noop", label = "One", run = function() end } })
    inst.NS.WindowManager:Create("Two")
    return inst, undo
end

local function start(inst)
    local ok, line = inst.NS.Sim:Start{ scenario = "case", seed = 3 }
    assertTrue(ok, "the session did not start: " .. tostring(line))
end

local function windows(inst)
    local all = inst.NS.WindowManager.All()
    assertTrue(#all >= 2, "the fixture expected two windows")
    return all
end

local function titleHasWord(window)
    local text = window.frame.title:GetText() or ""
    return text:find("SIMULATION", 1, true) ~= nil or text:find("TEST MODE", 1, true) ~= nil
end

test("Sim strip: built hidden on every window, sim-flavored, with the localized line", function()
    -- red under: no simStrip built in BuildFrame, or built as the test flavor.
    local inst, undo = fresh()
    for _, w in ipairs(windows(inst)) do
        local strip = w.simStrip
        assertTrue(strip ~= nil, "W.TestStrip{ kind = 'sim' } is built in BuildFrame")
        assertEqual(strip.kind, "sim")
        assertFalse(strip:IsShown(), "born hidden")
        assertEqual(strip.text:GetText(), inst.NS.L[SIM_LINE])
        assertEqual(w.testStrip.kind, "test", "the test strip keeps its own flavor")
    end
    undo()
end)

test("Sim strip: shown on every window while a session runs, the reserve re-anchors the chrome", function()
    -- red under: stripReserve ignoring the session, PlaceTestStrip not placing the sim strip, or
    -- the SIM_CHANGED edge not reaching ApplyTestStrip.
    local inst, undo = fresh()
    local before = {}
    for i, w in ipairs(windows(inst)) do
        local _, headerTop, bodyTop = w:ChromeOffsets()
        before[i] = { headerTop = headerTop, bodyTop = bodyTop, minHeight = w.layout.minHeight }
        assertEqual(w.layout.stripHeight, 0)
    end

    start(inst)
    for i, w in ipairs(windows(inst)) do
        assertTrue(w.simStrip:IsShown(), "window " .. i .. ": the sim strip is the marker")
        assertFalse(w.testStrip:IsShown(), "window " .. i .. ": the test strip stays hidden")
        assertEqual(w.layout.stripHeight, 22, "2 + TEST_STRIP.HEIGHT (18) + 2")
        local _, headerTop, bodyTop = w:ChromeOffsets()
        assertEqual(headerTop, before[i].headerTop + w.layout.stripHeight, "the headers moved down")
        assertEqual(bodyTop, before[i].bodyTop + w.layout.stripHeight, "the body moved down")
        assertEqual(w.layout.minHeight, before[i].minHeight, "the resize floor never moves")
        assertFalse(titleHasWord(w), "window " .. i .. ": no mode word in the title")
    end

    inst.NS.Sim:Stop()
    for i, w in ipairs(windows(inst)) do
        assertFalse(w.simStrip:IsShown(), "window " .. i .. ": the sim strip goes at stop")
        assertFalse(w.testStrip:IsShown())
        assertEqual(w.layout.stripHeight, 0, "the reserve is 0 after stop")
        assertFalse(titleHasWord(w))
    end
    undo()
end)

test("Sim strip: minimized hides it with no title word; a hidden header keeps it", function()
    -- red under: the TEST MODE word rule firing for a simulation, or tying the strip to header.show.
    local inst, undo = fresh()
    local a, b = windows(inst)[1], windows(inst)[2]
    b.config.header.show = false
    b:ApplyConfig()
    start(inst)

    a.config.frame.minimized = true
    a:ApplyMinimized()
    assertFalse(a.simStrip:IsShown(), "the strip goes with the body")
    assertFalse(titleHasWord(a), "a minimized window shows no SIMULATION word")

    a.config.frame.minimized = false
    a:ApplyMinimized()
    assertTrue(a.simStrip:IsShown(), "the strip returns on expand")

    assertTrue(b.simStrip:IsShown(), "a header-less window is still marked")
    assertFalse(b.frame.title:IsShown(), "the hidden title stays hidden")

    inst.NS.Sim:Stop()
    undo()
end)

test("Sim strip: with no Widgets library no strip, no reserve, and nothing raises", function()
    -- red under: an unguarded W.TestStrip read for the sim strip.
    local libs = {}
    for _, path in ipairs(T.libFiles) do
        if not path:find("/Widgets[^/]*%.lua$") then libs[#libs + 1] = path end
    end
    local inst, undo = fresh{ enable = true, libFiles = libs }
    start(inst)
    for _, w in ipairs(windows(inst)) do
        assertNil(w.simStrip)
        assertEqual(w.layout.stripHeight, 0)
        assertFalse(titleHasWord(w))
    end
    inst.NS.Sim:Stop()
    undo()
end)
