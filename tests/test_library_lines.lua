-- tests/test_library_lines.lua
--
-- The debug lines LibKa0s v1.65.0 writes for this addon, through the gated sink this
-- addon hands each descriptor (debug-logging-§4, "The library's own lines"), and the
-- console's at-enable queue and Clear re-arm (§1, §6, §8, §9).
--
-- WHAT IS OURS AND WHAT IS NOT. The wording of every line below is the library's, and
-- LibKa0s tests it. What this addon owns is the WIRING: that the Slash, Options,
-- Launcher and Lifecycle descriptors each carry `debug` (and the Launcher its
-- `debugAtEnable`), that the lines therefore land in THIS addon's console, and that no
-- host line repeats one. So each case drives the real dispatcher, panel, launcher or
-- latch on a real load and counts what reached `NS.DebugLog.buffer`. A case goes red
-- when the field is dropped from the descriptor (the line never lands) or when a host
-- line is put back beside the library's (the line lands twice).

local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue = T.assertEqual, T.assertTrue

--- How many buffered console lines contain `needle` (a plain find).
local function count(inst, needle)
    local n = 0
    for _, line in ipairs(inst.NS.DebugLog.buffer) do
        if tostring(line):find(needle, 1, true) then n = n + 1 end
    end
    return n
end

--- The console, one line per row, for a failure message.
local function dump(inst)
    return table.concat(inst.NS.DebugLog.buffer, "\n")
end

--- Every chat line one command produced.
local function say(inst, msg)
    local n = #inst.mocks.__chat
    inst.NS.Slash:OnSlash(msg)
    local out = {}
    for i = n + 1, #inst.mocks.__chat do out[#out + 1] = inst.mocks.__chat[i] end
    return out
end

--- A loaded instance with logging on and the console emptied, so each count starts at 0.
local function logging(opts)
    local inst = T.load(opts)
    inst.NS.State.debug = true
    inst.NS.DebugLog:Clear()
    return inst
end

-- ---------------------------------------------------------------------------
-- Slash (minor 18): each refusal the dispatcher decides is one [Cmd] line
-- ---------------------------------------------------------------------------

test("Library lines: the disabled gate's refusal is one [Cmd] line, and chat is unchanged", function()
    -- debug-logging-§8, Diagnosis: a refusal names its guard. The gate is the library's,
    -- so the line is too; this host matches no chat line to find it.
    -- red under: no `debug` on settings/Slash.lua's descriptor.
    local inst = logging{ enable = true }
    assertTrue(inst.NS.SetByPath("enabled", false))
    local chat = say(inst, "lock")
    assertEqual(#chat, 1, "the refusal's chat changed: " .. table.concat(chat, " | "))
    assertTrue(chat[1]:find(inst.NS.Slash:DisabledLine(), 1, true) ~= nil, chat[1])
    assertEqual(count(inst, "[Cmd] refused lock: disabled"), 1, dump(inst))
    assertEqual(count(inst, "refused lock"), 1, "the refusal was logged twice:\n" .. dump(inst))
end)

test("Library lines: an unknown verb is one [Cmd] line naming it", function()
    local inst = logging()
    say(inst, "frobnicate")
    assertEqual(count(inst, "[Cmd] refused frobnicate: unknown verb"), 1, dump(inst))
end)

test("Library lines: a get, set or reset of a path that does not exist is one [Cmd] line each", function()
    local inst = logging()
    say(inst, "get no.such.path")
    say(inst, "set no.such.path 1")
    say(inst, "reset no.such.path")
    assertEqual(count(inst, "[Cmd] refused get no.such.path: not found"), 1, dump(inst))
    assertEqual(count(inst, "[Cmd] refused set no.such.path: not found"), 1, dump(inst))
    assertEqual(count(inst, "[Cmd] refused reset no.such.path: not found"), 1, dump(inst))
end)

test("Library lines: a slash refusal writes nothing while logging is off", function()
    -- The sink handed over is the GATED one (debug-logging-§4), never the ungated append.
    local inst = T.load()
    inst.NS.State.debug = false
    local before = #inst.NS.DebugLog.buffer
    say(inst, "frobnicate")
    assertEqual(#inst.NS.DebugLog.buffer, before, "a refusal was written with logging off")
end)

-- ---------------------------------------------------------------------------
-- Lifecycle (minor 3): one [Lifecycle] line per edge, and no host line beside it
-- ---------------------------------------------------------------------------

test("Library lines: a perf hold's edges are the library's [Lifecycle] lines, once each", function()
    -- The perf hold is the one the player cannot see in settings, which is why the line
    -- names it. tests/test_disabled.lua covers the `disabled` hold the same way.
    -- red under: no `debug` on core/LifecycleSetup.lua's descriptor.
    local inst = logging{ enable = true }
    local lc = inst.NS.lifecycle
    lc:Hold("perf")
    lc:Release("perf")
    assertEqual(count(inst, "[Lifecycle] stood down: added perf (holds: perf)"), 1, dump(inst))
    assertEqual(count(inst, "[Lifecycle] stood up: released perf (holds: none)"), 1, dump(inst))
    assertEqual(count(inst, "[Init] stood"), 0, "a host edge line is back beside the library's")
end)

test("Library lines: a hold that moves no edge writes no [Lifecycle] line", function()
    local inst = logging{ enable = true }
    local lc = inst.NS.lifecycle
    lc:Hold("perf")
    lc:Hold("disabled")    -- already down: no edge
    lc:Release("perf")     -- still held by `disabled`: no edge
    assertEqual(count(inst, "[Lifecycle]"), 1, dump(inst))
    lc:Release("disabled")
    assertEqual(count(inst, "[Lifecycle] stood up: released disabled (holds: none)"), 1, dump(inst))
end)

-- ---------------------------------------------------------------------------
-- Options (minor 27): a combat-lock refusal is one [Cfg] line per combat
-- ---------------------------------------------------------------------------

test("Library lines: an open refused in combat is one [Cfg] line", function()
    -- red under: no `debug` on settings/OptionsSetup.lua's descriptor.
    local inst = logging()
    inst.mocks.Settings.OpenToCategory = function() end
    inst.mocks.setRestricted(true)
    inst.NS.OpenOptionsPanel()
    inst.NS.OpenOptionsPanel()
    assertEqual(count(inst, "[Cfg] open refused (in combat)"), 2, dump(inst))
end)

test("Library lines: a page shown in combat is one [Cfg] refusal line per combat", function()
    local inst = logging()
    local ctx = inst.NS.Helpers.__panelFor("windows")
    assertTrue(ctx ~= nil, "no windows page")
    inst.mocks.setRestricted(true)
    ctx.panel:Hide()
    ctx.panel:Show()
    ctx.panel:Hide()
    ctx.panel:Show()
    local n = 0
    for _, line in ipairs(inst.NS.DebugLog.buffer) do
        if line:find("[Cfg] show ", 1, true) and line:find("refused (in combat)", 1, true) then
            n = n + 1
        end
    end
    assertEqual(n, 1, "expected one show refusal for the combat:\n" .. dump(inst))
end)

-- ---------------------------------------------------------------------------
-- The at-enable queue (DebugLog minor 18): state lines written at login land
-- ---------------------------------------------------------------------------

test("Library lines: the launcher's registration, written at login, lands when logging turns on", function()
    -- Launcher minor 5: Register runs from OnInitialize while the session-only flag is off,
    -- so through `debug` its state lines never landed (debug-logging-§8).
    -- red under: no `debugAtEnable` on core/LauncherSetup.lua's descriptor.
    local inst = T.load()          -- registers the launcher with logging off
    assertTrue(inst.NS.Launcher:IsRegistered())
    assertEqual(count(inst, "[Launcher] registered"), 0, "a line landed with logging off")
    inst.NS.DebugLog:SetEnabled(true)
    assertEqual(count(inst, "[Launcher] registered"), 1, dump(inst))
    -- One-shot: a second enable edge does not write it again.
    inst.NS.DebugLog:SetEnabled(false)
    inst.NS.DebugLog:SetEnabled(true)
    assertEqual(count(inst, "[Launcher] registered"), 1, "the held line was written twice")
end)

test("Library lines: rejected events, recorded at OnEnable, land when logging turns on", function()
    -- core/MultiMeters.lua's OnEnable runs at login, with logging off.
    -- red under: writing the line through NS.Debug instead of NS.DebugAtEnable.
    local inst = T.load{ enable = true, mutate = function(m)
        m.__badEvents = { UNIT_SPELLCAST_SUCCEEDED = true }
    end }
    assertEqual(count(inst, "rejected events"), 0)
    inst.NS.DebugLog:SetEnabled(true)
    assertEqual(count(inst, "[Init] rejected events: UNIT_SPELLCAST_SUCCEEDED"), 1, dump(inst))
end)

-- ---------------------------------------------------------------------------
-- Clear re-arms the steady-state sink (DebugLog minor 18's onClear)
-- ---------------------------------------------------------------------------

test("Library lines: after a Clear, an unchanged steady-state pass speaks again", function()
    -- Before the hook, a cleared console stayed silent until the next change, which read as
    -- "nothing is happening". red under: no `onClear` on core/DebugLogSetup.lua's descriptor.
    local inst = logging{ enable = true }
    for _ = 1, 3 do inst.NS.DebugSteady(1, "Render", "drew %d rows", 2) end
    assertEqual(count(inst, "[Render] drew 2 rows"), 1, dump(inst))
    inst.NS.DebugLog:Clear()
    inst.NS.DebugSteady(1, "Render", "drew %d rows", 2)
    assertEqual(count(inst, "[Render] drew 2 rows"), 1, "the first pass after a Clear was silent")
end)
