-- tests/test_slash_diagnostics.lua
--
-- The diagnostics verbs of settings/Slash.lua's CLI: `perf`, and the `/mm debug`
-- ladder with its `diagnostics`, `recap` and `identity` reports, the feign
-- recording, the tooltip channel and the console toggle. A sibling of
-- tests/test_slash.lua, peeled out of it along that seam when the parent passed
-- its line-cap re-check (MM-ATS-01). The verb table's shape, dispatch, the host
-- verbs and registration stay in the parent.

local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue, assertFalse = T.assertEqual, T.assertTrue, T.assertFalse

local NS = T.NS

--- Every chat line one command produced, on a fresh instance.
local function say(inst, msg)
    local n = #inst.mocks.__chat
    inst.NS.Slash:OnSlash(msg)
    local out = {}
    for i = n + 1, #inst.mocks.__chat do out[#out + 1] = inst.mocks.__chat[i] end
    return out
end

local function joined(lines) return table.concat(lines, "\n") end

--- The same, plus anything the command wrote to the debug console instead.
---
--- core/Diagnostics.lua redirects its own output into the DebugLog sink while a
--- report is running, so a report typed at the slash command lands in the console
--- buffer and never in chat. A case reading only chat would call a report that ran
--- perfectly "no output".
local function sayAndLog(inst, msg)
    local buffer = inst.NS.DebugLog and inst.NS.DebugLog.buffer
    local bufN   = buffer and #buffer or 0
    local out    = say(inst, msg)
    if buffer then
        for i = bufN + 1, #buffer do out[#out + 1] = buffer[i] end
    end
    return out
end

local function findVerb(commands, name)
    for _, entry in ipairs(commands) do
        if entry[1] == name then return entry end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- perf: registered by the ADDON, never by the library
-- ---------------------------------------------------------------------------

test("Slash: `perf` is declared in NS.COMMANDS and routed to NS.Perf.OnCommand", function()
    local inst = T.load()
    local entry = findVerb(inst.NS.COMMANDS, "perf")
    assertTrue(entry ~= nil, "the verb table is the ONE place every command is declared")

    local seen = {}
    inst.NS.Perf.OnCommand = function(rest)
        seen[#seen + 1] = rest
        return { "perf line" }
    end
    local lines = say(inst, "perf start pulls")
    assertEqual(#seen, 1)
    assertEqual(seen[1], "start pulls", "the remainder keeps its case and its spacing")
    assertTrue(joined(lines):find("perf line", 1, true) ~= nil,
        "the handler must print what the library's run answers")
end)

test("Slash: the library did not register `perf` behind the addon's back", function()
    -- A verb registered outside NS.COMMANDS is a verb the help index, the settings
    -- landing page and the README all miss. LandingRows is generated FROM
    -- NS.COMMANDS, so anything the dispatcher answers that is not in that list
    -- would be invisible in all three.
    local rows = NS.Slash:LandingRows()
    local perfRows = 0
    for _, line in ipairs(rows) do
        if line:find("/mm perf", 1, true) then perfRows = perfRows + 1 end
    end
    assertEqual(perfRows, 1, "`/mm perf` must appear exactly once in the generated list")
    assertEqual(#rows, #NS.COMMANDS,
        "the landing list is generated from NS.COMMANDS; a different length means a verb "
        .. "was registered somewhere else")
end)

-- ---------------------------------------------------------------------------
-- `/mm debug`: the logging flag, the tooltip channel, the feign read
-- ---------------------------------------------------------------------------

test("Slash: `debug on` / `debug off` set the logging flag; a bare `debug` moves the window", function()
    local inst = T.load()
    local D = inst.NS.DebugLog
    assertTrue(D ~= nil, "the debug console seam must have loaded")
    say(inst, "debug on")
    assertTrue(inst.NS.State.debug, "`on` sets the session-only logging flag")
    say(inst, "debug off")
    assertFalse(inst.NS.State.debug)
    -- The window and the flag are separate on purpose: logging runs with the
    -- console closed so a bug can be reproduced first and read afterwards.
    local shownBefore = D:IsShown()
    say(inst, "debug")
    assertTrue(D:IsShown() ~= shownBefore, "a bare `debug` toggles the console window")
    assertFalse(inst.NS.State.debug, "and must not touch the logging flag")
end)

test("Slash: `debug tooltip` toggles the tooltip channel and says which way", function()
    -- THE CHANNEL THAT DROWNS THE LOG. A tooltip is rebuilt on every mouse-over
    -- and on every refresh the cursor sits through, so its lines arrive faster
    -- than the mouse moves and a capped buffer loses the pass somebody was
    -- reading. Off by default, and the reply names the state it landed in --
    -- there is no argument to get wrong, so the print is what makes it certain.
    local inst = T.load{ enable = true }
    assertFalse(inst.NS.State.debugTooltip, "it must start OFF")

    local text = joined(sayAndLog(inst, "debug tooltip"))
    assertTrue(inst.NS.State.debugTooltip, "the first call turns it on")
    assertTrue(text:lower():find("on", 1, true) ~= nil, "and says so")

    say(inst, "debug tooltip")
    assertFalse(inst.NS.State.debugTooltip, "the second turns it off again")
end)

test("Slash: EVERY tooltip-channel line is behind the flag, not just some", function()
    -- THE BUG THIS CASE EXISTS FOR. The first cut of `/mm debug tooltip` gated
    -- the two lines in modules/Tooltip_Builders.lua and missed a third in
    -- modules/Row.lua -- which fires on MOUSE MOTION rather than on a tooltip
    -- being built, and is therefore the loudest of the three. Half a fix reads
    -- exactly like a whole one from the console.
    --
    -- Asserted over the SOURCE rather than by driving three widgets, because the
    -- property is "no call site was missed" and a behavioral test can only ever
    -- cover the call sites somebody remembered to drive.
    local missed = {}
    for _, rel in ipairs({ "modules/Row.lua", "modules/Tooltip_Builders.lua" }) do
        local fh = assert(io.open(T.root .. "/" .. rel, "r"))
        local prev = ""
        local n = 0
        for line in fh:lines() do
            n = n + 1
            if line:find('Debug("Tooltip"', 1, true) and not line:find("^%s*%-%-") then
                if not prev:find("State.debugTooltip", 1, true) then
                    missed[#missed + 1] = rel .. ":" .. n
                end
            end
            prev = line
        end
        fh:close()
    end
    assertEqual(#missed, 0,
        "tooltip lines not behind State.debugTooltip: " .. table.concat(missed, ", "))
end)

test("Slash: `debug tooltip` touches neither the logging flag nor the console", function()
    -- Three switches, three jobs. red under: folding the channel into `debug on`,
    -- which is exactly the coupling that made it unreadable in the first place.
    local inst = T.load{ enable = true }
    local D = inst.NS.DebugLog
    local shownBefore = D and D:IsShown()

    say(inst, "debug tooltip")
    assertFalse(inst.NS.State.debug, "the session logging flag is not its business")
    if D then
        assertEqual(D:IsShown(), shownBefore, "and the window did not move")
    end
end)

test("Slash: `debug feign` with no argument prints the recording", function()
    -- The bare verb is the READ, and it has to stay the read: a player is asked to
    -- arm the trace before a dungeon and type this after it. The rejection added
    -- below must not swallow it.
    local inst = T.load()
    local text = joined(sayAndLog(inst, "debug feign"))
    assertTrue(text:find("feign trace", 1, true) ~= nil, text)
end)

test("Slash: `debug feign of` names the rejected argument and leaves the trace alone", function()
    -- THE TYPO THAT COST A RUN. `on` and `off` armed and disarmed; anything else
    -- fell through to the report — so `/mm debug feign of`, typed before a
    -- dungeon by a player who meant `off`, printed the empty report and left the
    -- recording armed for the rest of the session, and the player had no way to
    -- know either. This is the addon's own unknown-verb pattern: name it, then say
    -- what was expected.
    -- red under: an else branch that reports instead of rejecting.
    local inst = T.load()
    inst.NS.Diagnostics.ArmFeignTrace(true)
    local text = joined(sayAndLog(inst, "debug feign of"))
    assertTrue(text:find("'of'", 1, true) ~= nil,
        "the rejection names the argument that was refused: " .. text)
    assertTrue(text:find("feign trace (issue #25)", 1, true) == nil,
        "a rejected argument must not print the report: " .. text)
    assertTrue(inst.NS.Diagnostics.IsFeignTraceArmed(),
        "a rejected argument changes nothing about the recording")
end)

-- ---------------------------------------------------------------------------
-- `/mm debug`: the report, the read verbs, the feign recording, the console toggle
-- ---------------------------------------------------------------------------
--
-- doDebug is a ladder over one word, and its arms are NOT interchangeable.
-- `diagnostics` is tested FIRST (debug-logging-§14): it is the same report the
-- `diagnostics` verb runs, through the same LibKa0s helper. `recap` and
-- `identity` sit ABOVE the `NS.DebugLog` guard on purpose -- they are what a
-- player is asked to type when something looks wrong, and a console they have
-- to open first is one more step between a bug and its report. The cases below
-- pin each arm to its own outcome, so a ladder rewritten as a lookup cannot
-- cross-wire two verbs, drop one below the guard, or turn the final toggle into
-- a refusal.
--
-- `diag` is GONE. It was this report's old name, and the standard now forbids any
-- other name for it (debug-logging-§14; the owner's Q7 ruling (a)): it is an
-- ordinary unknown word, which toggles the console like any other, with no hint.

--- Replace the report entry points with counters and hand back the tally.
---
--- Spied rather than run: each real report prints dozens of lines into the
--- console sink, and what is being pinned here is WHICH report a verb reaches,
--- not what that report says. The full report is the DebugLog instance's own
--- `RunDiagnostics`, so that is what is spied for it.
local function spyReports(inst)
    local calls = { diagnostics = 0, recap = 0, identity = 0 }
    local D = inst.NS.Diagnostics
    D.ReportDeathRecap = function() calls.recap    = calls.recap    + 1 end
    D.ReportIdentity   = function() calls.identity = calls.identity + 1 end
    inst.NS.DebugLog.RunDiagnostics = function()
        calls.diagnostics = calls.diagnostics + 1
        return 0
    end
    return calls
end

test("Slash: `diagnostics`, `recap` and `identity` each reach their OWN report and no other", function()
    -- Three words, three entry points, and the three reports are different
    -- lengths for a reason: `recap` is the issue #1 probe on its own and
    -- `identity` the issue #22 capture, both extracted precisely so a player
    -- mid-pull is not handed the whole diagnostics report. A lookup table that
    -- maps two of them to the same member would undo that and still print
    -- something plausible.
    local inst = T.load()
    local calls = spyReports(inst)

    say(inst, "debug diagnostics")
    assertEqual(calls.diagnostics, 1, "`debug diagnostics` runs the full report")
    assertEqual(calls.recap + calls.identity, 0, "and reaches nothing else")

    say(inst, "diagnostics")
    assertEqual(calls.diagnostics, 2, "the `diagnostics` verb runs the same report")

    say(inst, "debug recap")
    assertEqual(calls.recap, 1, "`recap` runs the death-recap probe alone")
    assertEqual(calls.diagnostics + calls.identity, 2, "the full report must not run again")

    say(inst, "debug identity")
    assertEqual(calls.identity, 1, "`identity` runs the mid-pull correlation capture alone")
    assertEqual(calls.diagnostics + calls.recap, 3, "and neither of the other two again")
end)

test("Slash: `diag` is an ordinary unknown word now, and runs no report", function()
    -- debug-logging-§14 allows exactly two forms, and the owner ruled Q7 (a): the
    -- retired name gets no hint and no special case, because a word the ladder
    -- still recognizes is one edit away from an alias. So `debug diag` does what
    -- `debug wibble` does -- toggles the window -- and `/mm diag` is an unknown
    -- verb.
    -- red under: `diag` kept in the debug ladder, as a report or as a hint.
    local inst = T.load()
    local calls = spyReports(inst)
    local D = inst.NS.DebugLog
    local shownBefore = D:IsShown()

    say(inst, "debug diag")
    assertEqual(calls.diagnostics, 0, "`debug diag` ran the report")
    assertTrue(D:IsShown() ~= shownBefore, "`debug diag` toggles the window, as any unknown word does")

    local text = joined(say(inst, "diag"))
    assertEqual(calls.diagnostics, 0, "`/mm diag` ran the report")
    assertTrue(text:lower():find("unknown", 1, true) ~= nil,
        "`/mm diag` answers as an unknown verb: " .. text)
end)

test("Slash: the two read verbs run with no debug console seam at all", function()
    -- THE ORDERING THE COMMENTS CALL LOAD-BEARING, asserted rather than trusted.
    -- Both sit above `if not NS.DebugLog then return end`; move either below it
    -- and the verb a player was asked to type answers with silence on exactly
    -- the broken install where the answer matters most. `diagnostics` needs the
    -- console seam (the report is its method), so with no seam at all it goes
    -- quiet rather than raising.
    -- red under: folding the read verbs into the console-toggle ladder.
    local inst = T.load()
    local calls = spyReports(inst)

    local realLog = inst.NS.DebugLog
    inst.NS.DebugLog = nil
    local ok, err = pcall(function()
        say(inst, "debug diagnostics")
        say(inst, "debug recap")
        say(inst, "debug identity")
    end)
    inst.NS.DebugLog = realLog

    assertTrue(ok, "a debug word must not raise when the console seam is absent: " .. tostring(err))
    assertEqual(calls.recap, 1, "`recap` ran without the console")
    assertEqual(calls.identity, 1, "`identity` ran without the console")
end)

test("Slash: a report word moves neither the console window nor the logging flag", function()
    -- The other half of the same ordering: the report words `return`, so none of
    -- them may fall through to the toggle at the bottom of the ladder. A report
    -- that also closed the console would be a report the player has to undo a
    -- window change to read. (The real `diagnostics` report OPENS a hidden
    -- console, which is the library's doing and pinned in test_diagnostics; the
    -- ladder itself adds nothing on top.)
    local inst = T.load()
    spyReports(inst)
    local D = inst.NS.DebugLog
    local shownBefore = D:IsShown()

    say(inst, "debug diagnostics")
    say(inst, "debug recap")
    say(inst, "debug identity")

    assertEqual(D:IsShown(), shownBefore, "a report is a read, not a window toggle")
    assertTrue(not inst.NS.State.debug, "and it must not switch session logging on")
end)

test("Slash: the debug sub-verb is matched case-insensitively", function()
    -- The word is lowercased before the ladder sees it, so a player typing what
    -- they were sent in a chat message gets the report rather than the toggle.
    local inst = T.load()
    local calls = spyReports(inst)
    say(inst, "debug DIAGNOSTICS")
    assertEqual(calls.diagnostics, 1, "`DIAGNOSTICS` is `diagnostics`")
    say(inst, "debug Identity")
    assertEqual(calls.identity, 1, "`Identity` is `identity`")
end)

test("Slash: `debug feign on` arms the recording and says exactly what to do next", function()
    -- The line is the contract. It is the ONLY place the player is told that the
    -- recording is now running and which command prints it afterwards, so a
    -- reworded or dropped line strands somebody with an armed trace they never
    -- read. The separator is a byte escape for the reason every non-ASCII string
    -- in this addon is.
    local inst = T.load()
    inst.NS.Diagnostics.ArmFeignTrace(false)
    local text = joined(say(inst, "debug feign on"))
    assertTrue(text:find(
        "feign trace ON \226\128\148 run the dungeon, then `/mm debug feign`.", 1, true) ~= nil,
        "the armed line must survive verbatim: " .. text)
    assertTrue(inst.NS.Diagnostics.IsFeignTraceArmed(), "`on` actually arms the recording")
end)

test("Slash: `debug feign off` stops the recording and says so", function()
    local inst = T.load()
    inst.NS.Diagnostics.ArmFeignTrace(true)
    local text = joined(say(inst, "debug feign off"))
    assertTrue(text:find("feign trace off.", 1, true) ~= nil,
        "the off line must survive verbatim: " .. text)
    assertFalse(inst.NS.Diagnostics.IsFeignTraceArmed(), "`off` actually stops the recording")
end)

test("Slash: the feign argument is case-folded, and a word after it is ignored", function()
    -- The whole remainder is lowercased and only the SECOND word is read. Both
    -- halves are lenient on purpose, and both are one refactor away from turning
    -- into the unknown-argument refusal next door — which would reject `feign ON`
    -- and `feign off now` as typos when neither is one.
    local inst = T.load()
    say(inst, "debug feign ON")
    assertTrue(inst.NS.Diagnostics.IsFeignTraceArmed(), "`ON` is `on`")
    say(inst, "debug feign OFF now")
    assertFalse(inst.NS.Diagnostics.IsFeignTraceArmed(),
        "only the second word is read; a trailing word is not a refusal")
end)

test("Slash: a refused feign argument does not fall through to the console toggle", function()
    -- The refusal `return`s, and has to: without it the rejected word would also
    -- land on the ladder's final arm and move the console window, so one typo
    -- would cost two surprises. The companion case above pins the message and the
    -- untouched trace; this one pins the window.
    local inst = T.load()
    local D = inst.NS.DebugLog
    local shownBefore = D:IsShown()
    say(inst, "debug feign of")
    assertEqual(D:IsShown(), shownBefore, "a refusal is not a request to move the console")
end)

test("Slash: a word the ladder does not know toggles the console, as a bare `debug` does", function()
    -- The final arm is a TOGGLE, not a refusal, and that asymmetry with `feign`
    -- is deliberate: `feign` takes an argument and can therefore be typed wrong,
    -- while the console verb never validated one. A lookup table that answered
    -- everything it could not find with "unknown" would change what
    -- `/mm debug please` has always done.
    local inst = T.load()
    local D = inst.NS.DebugLog
    local shownBefore = D:IsShown()
    say(inst, "debug wibble")
    assertTrue(D:IsShown() ~= shownBefore, "an unrecognized word toggles the window")
    assertTrue(not inst.NS.State.debug, "and does not touch the logging flag")
end)

test("Slash: with core/Diagnostics.lua absent the debug verbs go quiet, not through", function()
    -- Every one of the four guards on the module and returns either way. On a
    -- half-installed addon a `recap` must not fall through to the console toggle
    -- and move a window the player never asked about — the failure would look
    -- like the command working.
    local inst = T.load()
    local realD = inst.NS.Diagnostics
    inst.NS.Diagnostics = nil
    local D = inst.NS.DebugLog
    local shownBefore = D:IsShown()

    local ok, err = pcall(function()
        for _, tail in ipairs({ "recap", "identity", "feign", "feign on" }) do
            say(inst, "debug " .. tail)
        end
    end)
    inst.NS.Diagnostics = realD

    assertTrue(ok, "a missing diagnostics module must not take the command down: " .. tostring(err))
    assertEqual(D:IsShown(), shownBefore, "none of the four may reach the console toggle")
end)

test("Slash: a Diagnostics too old to arm a trace reports off rather than promising one", function()
    -- `local on = D.ArmFeignTrace and D.ArmFeignTrace(...) or false` — the printed
    -- line follows what arming ACTUALLY returned, never what was asked for. A
    -- module that cannot record says off, so nobody runs a dungeon for a trace
    -- that was never armed.
    local inst = T.load()
    local D = inst.NS.Diagnostics
    local real = D.ArmFeignTrace
    D.ArmFeignTrace = nil
    local text = joined(say(inst, "debug feign on"))
    D.ArmFeignTrace = real

    assertTrue(text:find("feign trace off.", 1, true) ~= nil,
        "an unarmable trace must still answer: " .. text)
    assertTrue(text:find("feign trace ON", 1, true) == nil,
        "and must not print the armed line: " .. text)
end)
