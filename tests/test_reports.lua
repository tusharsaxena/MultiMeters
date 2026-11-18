-- tests/test_reports.lua — the report verbs on LibKa0s-DebugLog-1.0's `D:Report`
-- (debug-logging-§15, the owner's ruling of 2026-11-08, LibKa0s#79).
--
-- A REPORT is a multi-line read-out a player asks for by name: `/mm window list` (and a bare
-- `/mm window`), and the three topic probes `/mm debug recap`, `/mm debug identity` and
-- `/mm debug feign`. Each lands in the debug console whether or not trace logging is on, reveals
-- a hidden console, and prints exactly ONE chat line pointing at it. A usage or refusal line
-- inside a report verb stays in chat and writes nothing. Without the library the stub streams the
-- report to chat with no pointer.
--
-- What is NOT a report, and so not here: `/mm list` (reserved, kept in chat by the ruling),
-- `/mm export` (a copy window, not a read-out), `/mm profile` (the library's own CliProfile),
-- `/mm version` and every acknowledgment. `/mm diagnostics` is a report already routed by the
-- library's own RunDiagnostics (debug-logging-§14), tested in tests/test_slash_diagnostics.lua.

local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue, assertFalse = T.assertEqual, T.assertTrue, T.assertFalse

--- Run one slash line and hand back what it printed to chat and what it wrote to the console.
local function run(inst, msg)
    local D      = inst.NS.DebugLog
    local buffer = D and D.buffer
    local chatN  = #inst.mocks.__chat
    local bufN   = buffer and #buffer or 0
    inst.NS.Slash:OnSlash(msg)
    local chat, console = {}, {}
    for i = chatN + 1, #inst.mocks.__chat do chat[#chat + 1] = inst.mocks.__chat[i] end
    if buffer then
        for i = bufN + 1, #buffer do console[#console + 1] = buffer[i] end
    end
    return chat, console
end

local function joined(lines) return table.concat(lines, "\n") end

--- The four report verbs, each with the title its header and its pointer name.
local REPORTS = {
    { verb = "window list",    title = "window list" },
    { verb = "debug recap",    title = "debug recap" },
    { verb = "debug identity", title = "debug identity" },
    { verb = "debug feign",    title = "debug feign" },
}

for _, r in ipairs(REPORTS) do
    test(("Reports: `/mm %s` lands in the console with logging off, and leaves it off"):format(r.verb), function()
        -- red under: writing the report through the GATED sink (NS.Debug), which drops every line
        -- while the flag is off -- the state a player is in when asked to run this.
        local inst = T.load{ enable = true }
        assertFalse(inst.NS.State.debug, "the premise: logging starts off")

        local _, console = run(inst, r.verb)
        assertTrue(#console >= 2, ("a header and a body; got %d line(s)"):format(#console))
        assertTrue(joined(console):find("/mm " .. r.title, 1, true) ~= nil,
            "the report opens with its `/mm <title>` header:\n" .. joined(console))
        assertFalse(inst.NS.State.debug, "a report never turns logging on")
    end)

    test(("Reports: `/mm %s` reveals the console and points at it with exactly one chat line"):format(r.verb), function()
        -- red under: streaming the body to chat line by line (the pre-§15 route), or printing the
        -- pointer per line rather than once.
        local inst = T.load{ enable = true }
        local D = inst.NS.DebugLog
        assertFalse(D:IsShown(), "the premise: the console starts hidden")

        local chat = run(inst, r.verb)
        assertEqual(#chat, 1, "exactly one chat line:\n" .. joined(chat))
        assertTrue(chat[1]:find(r.title .. ": ", 1, true) ~= nil, chat[1])
        assertTrue(chat[1]:find("lines written to the debug console", 1, true) ~= nil, chat[1])
        assertTrue(D:IsShown(), "the console opens for the report")
    end)

    test(("Reports: without the library `/mm %s` streams to chat with no pointer"):format(r.verb), function()
        -- red under: a stub Report that writes nothing, which loses the read-out the player asked
        -- for by name on exactly the broken install where they need it.
        local inst = T.load{ libFiles = {} }
        local chat = run(inst, r.verb)
        assertTrue(#chat >= 1, "the report reached chat")
        assertFalse(joined(chat):find("lines written to the debug console", 1, true) ~= nil,
            "and no pointer at a console that is not there:\n" .. joined(chat))
    end)
end

test("Reports: `/mm window list` carries one line per window", function()
    local inst = T.load()
    run(inst, "window new Second")
    local _, console = run(inst, "window list")
    local text = joined(console)
    assertTrue(text:find("Second", 1, true) ~= nil, text)
    assertEqual(#console, 1 + #inst.NS.Database.GetWindows(), "the header and one line per window")
end)

test("Reports: a bare `/mm window` is the same report", function()
    local inst = T.load()
    local chat, console = run(inst, "window")
    assertEqual(#chat, 1, joined(chat))
    assertTrue(joined(console):find("/mm window list", 1, true) ~= nil, joined(console))
end)

test("Reports: a `window` usage line stays in chat and writes no report", function()
    -- red under: routing the whole `window` verb through D:Report, which would put the usage line
    -- in the console and point at it.
    local inst = T.load()
    local D = inst.NS.DebugLog
    local chat, console = run(inst, "window explode")
    assertEqual(#console, 0, "nothing written:\n" .. joined(console))
    assertTrue(joined(chat):find("/mm window list", 1, true) ~= nil, "the usage, in chat")
    assertFalse(D:IsShown(), "and the console stays hidden")
end)

test("Reports: a `debug feign` refusal stays in chat and writes no report", function()
    local inst = T.load{ enable = true }
    local D = inst.NS.DebugLog
    local chat, console = run(inst, "debug feign of")
    assertEqual(#console, 0, "nothing written:\n" .. joined(console))
    assertEqual(#chat, 1, joined(chat))
    assertTrue(chat[1]:find("unknown feign argument", 1, true) ~= nil, chat[1])
    assertFalse(D:IsShown(), "and the console stays hidden")
end)

test("Reports: a topic probe that raises keeps its section-failed line and still points", function()
    -- The probe is typed on a client that is already misbehaving, so a raise is one line in the
    -- report, and the report is still written and pointed at.
    local inst = T.load{ enable = true }
    local P = inst.NS.Provider
    local realRecap = P.RecapAPIs
    P.RecapAPIs = function() error("boom") end
    local chat, console = run(inst, "debug recap")
    P.RecapAPIs = realRecap
    assertTrue(joined(console):find("section failed", 1, true) ~= nil, joined(console))
    assertEqual(#chat, 1, joined(chat))
end)
