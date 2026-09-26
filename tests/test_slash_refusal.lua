-- tests/test_slash_refusal.lua
--
-- The refusals settings/Slash.lua's schema seams hand back to LibKa0s-Slash-1.0
-- (minor 15), and the refusal a disabled addon gives a feature verb
-- (slash-commands-§2, the last section below). A sibling of tests/test_slash.lua;
-- the disabled-state cases moved here from it in MM-ATS-01.
--
-- ── WHY THE SEAMS ANSWER ─────────────────────────────────────────────────────
--
-- CliSet re-reads the stored value and echoes it as `<path> = <value>`. When the
-- write seam refused the value, that echo is the OLD value printed as though the
-- write had landed. From minor 15 the descriptor's `set` MAY answer
-- `false, reason[, why]`, and CliSet prints the INVALID line and the reason
-- instead of the echo. `applyDefault` answering exactly false does the same for
-- CliReset on a row with no default: NO_DEFAULT, not an echo of the unchanged
-- value. The adapters used to swallow NS.SetByPath's and NS.ApplyDefault's
-- answers, so the library never saw a refusal.

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

local function has(text, needle) return text:find(needle, 1, true) ~= nil end

test("Slash refusal: `set` a value the row's validate refuses prints the refusal, not the old value", function()
    local inst = T.load()
    local NSi = inst.NS
    -- The pinned segment has no min/max for the parser to clamp to, so -5 reaches
    -- the seam intact and the row's validate (0, or a positive integer) refuses it.
    -- `window.frame.width -5` cannot show this: the parser clamps it to the row's
    -- min of 160 before the seam sees it, and 160 is a valid width.
    local before = NSi.GetSetting("window.data.sessionID")
    local shown = joined(say(inst, "set window.data.sessionID -5"))
    assertTrue(has(shown, "Invalid value for window.data.sessionID"),
        "the refusal must be printed, got: " .. shown)
    assertTrue(not has(shown, " = "),
        "a refused write must not echo the unchanged value as though it landed, got: " .. shown)
    assertEqual(NSi.GetSetting("window.data.sessionID"), before, "nothing was stored")
end)

test("Slash refusal: `reset` on a row with no default prints NO_DEFAULT and keeps the value", function()
    local inst = T.load()
    local NSi = inst.NS
    NSi.RegisterSchemaRows({
        { path = "window.frame.noDefaultProbe", type = "number", page = "frame" },
    })
    say(inst, "set window.frame.noDefaultProbe 5")
    assertEqual(NSi.GetSetting("window.frame.noDefaultProbe"), 5, "precondition: the probe row holds 5")

    local shown = joined(say(inst, "reset window.frame.noDefaultProbe"))
    assertTrue(has(shown, "window.frame.noDefaultProbe has no default to restore"),
        "the library's NO_DEFAULT line, got: " .. shown)
    assertEqual(NSi.GetSetting("window.frame.noDefaultProbe"), 5,
        "a row with no default is left alone, not written to nil")
end)

-- ── every acknowledgment reads the locale (MultiMeters-R-11) ───────────────
--
-- The feature verbs' acknowledgments used to be raw English, and the
-- reset-positions count built its plural by concatenating "1 window" or
-- "N windows" into a sentence, which no translation can reorder. Each is now a
-- whole-sentence key read through NS.L, with the plural as two distinct keys
-- (localization-§1). A spy on NS.L's reads is what shows a line came through
-- the locale rather than merely printing the same English: the fallback answers
-- every key with itself, so the chat text alone cannot tell the two apart.

--- Record every key read from `inst.NS.L` from now on. The declared entries are
--- moved into a shadow table so that every read, declared or not, reaches the
--- recording `__index`; the table's identity is kept, because settings/Slash.lua
--- captured it at load.
local function spyLocale(inst)
    local L = inst.NS.L
    local store, reads = {}, {}
    for k, v in pairs(L) do store[k] = v end
    for k in pairs(store) do L[k] = nil end
    setmetatable(L, { __index = function(_, k)
        reads[k] = (reads[k] or 0) + 1
        local v = store[k]
        if v == nil then return k end
        return v
    end })
    return reads
end

local ACK_KEYS = {
    { "lock on",    "Windows are locked." },
    { "lock off",   "Windows are unlocked \226\128\148 drag them into place." },
    { "test on",    "test mode on \226\128\148 showing placeholder rows" },
    { "test off",   "test mode off" },
    { "debug feign on",  "feign trace ON \226\128\148 run the dungeon, then `/mm debug feign`." },
    { "debug feign off", "feign trace off." },
    { "debug feign of",
      "unknown feign argument '%s' \226\128\148 `/mm debug feign on|off`, or `/mm debug feign` to print the recording." },
}

test("Slash locale: every feature-verb acknowledgment reads its whole-sentence key", function()
    for _, case in ipairs(ACK_KEYS) do
        local inst = T.load()
        local reads = spyLocale(inst)
        local shown = joined(say(inst, case[1]))
        assertTrue((reads[case[2]] or 0) > 0,
            ("`/mm %s` must read L[%q], printed: %s"):format(case[1], case[2], shown))
    end
end)

test("Slash locale: `debug tooltip` reads the key for the state it landed in", function()
    local inst = T.load()
    local reads = spyLocale(inst)
    say(inst, "debug tooltip")
    assertTrue((reads["tooltip logging ON \226\128\148 mouse over a row and read the console."] or 0) > 0,
        "turning tooltip logging on reads its key")
    say(inst, "debug tooltip")
    assertTrue((reads["tooltip logging off."] or 0) > 0, "turning it off reads its key")
end)

test("Slash locale: reset-positions says its plural through two distinct keys", function()
    local ONE, MANY = "Moved 1 window back to the center.", "Moved %d windows back to the center."
    local inst = T.load()
    local reads = spyLocale(inst)
    assertEqual(#inst.NS.Database.GetWindows(), 1, "precondition: a fresh profile holds one window")
    local shown = joined(say(inst, "reset-positions"))
    assertTrue((reads[ONE] or 0) > 0 and not reads[MANY], "one window reads the singular key, got: " .. shown)
    assertTrue(has(shown, ONE), "and prints it: " .. shown)

    inst = T.load()
    say(inst, "window new Second")
    say(inst, "window new Third")
    reads = spyLocale(inst)
    shown = joined(say(inst, "reset-positions"))
    assertTrue((reads[MANY] or 0) > 0 and not reads[ONE], "three windows read the plural key, got: " .. shown)
    assertTrue(has(shown, MANY:format(3)), "and print the count: " .. shown)
end)

-- ---------------------------------------------------------------------------
-- A disabled addon refuses a FEATURE verb, and refuses nothing else
-- ---------------------------------------------------------------------------
--
-- slash-commands-§2. A verb that DRIVES THE ADDON'S FEATURES answers on ONE tagged line naming
-- `/mm enable` and does nothing else: acting is the wrong answer twice over, because the player
-- asked for something the addon is standing down from doing and a silent no-op leaves them with no
-- clue why nothing happened.
--
-- THE LIVE LIST IS RESTATED HERE ON PURPOSE. settings/Slash.lua names it once as data and the
-- cases below name it again, because this half is the STANDARD's list rather than this addon's
-- choice: a verb moving between the two sets has to be a deliberate edit in two files rather than
-- a quiet consequence of editing one. Read literally, "refuse while disabled" takes the entire
-- command surface down with it, and what §2 does NOT leave to the addon is that these keep
-- answering -- a player must be able to read and repair settings, and to reach the panel, while
-- the addon is off, and `enable` above all or the pair is one-way again.
local LIVE_WHILE_DISABLED = {
    help = true, config = true, version = true,
    enable = true, disable = true,
    debug = true, diagnostics = true, perf = true,
    get = true, set = true, list = true, reset = true, resetall = true,
}

--- The rendered refusal, READ OUT OF THE LOCALE TABLE rather than retyped, so a reworded line
--- moves the case with it instead of quietly making it match nothing.
-- slash-commands-§7's ONE refusal line, collection-wide, built from the library's own format
-- string rather than re-typed here: the wording is not this addon's to spell, and a literal in the
-- suite would be a second copy free to drift from the one the dispatcher prints. The brand name is
-- the plain-text `Ka0s <Name>` the LDB object also wears (launcher-§1).
local REFUSAL = T.load().mocks.LibStub("LibKa0s-Slash-1.0").DISABLED_LINE_FORMAT
    :format(NS.L["Ka0s Multi Meters"], "/mm enable")

--- Did this line refuse? Matched on the WHOLE sentence and not on `/mm enable` alone: the help
--- index prints a row for that very verb, so the shorter match called every help block a refusal.
local function isRefusal(line)
    return line:find(REFUSAL, 1, true) ~= nil
end

local function refusedOnly(lines)
    return #lines == 1 and isRefusal(lines[1])
end

test("Slash: a feature verb refuses while disabled AND does not act", function()
    -- BOTH HALVES, because a case that only read the message would pass over a verb that printed
    -- and then acted anyway -- which is the exact failure a refusal exists to prevent.
    -- red under: dropping `isEnabled` from settings/Slash.lua's descriptor.
    local inst = T.load{ enable = true }
    local NSi = inst.NS
    say(inst, "disable")

    local toggled = 0
    local realToggle = NSi.WindowManager.Toggle
    NSi.WindowManager.Toggle = function(...) toggled = toggled + 1; return realToggle(...) end

    local lines = say(inst, "toggle")
    NSi.WindowManager.Toggle = realToggle

    assertTrue(refusedOnly(lines), "expected one refusal line, got: " .. joined(lines))
    assertEqual(toggled, 0, "`/mm toggle` refused and then reached the registry anyway")
end)

test("Slash: a refused verb leaves no side effect in the store", function()
    -- The same rule against a verb whose act is a WRITE rather than a call: `window new` creates a
    -- window, which outlives both the session and the message. "No partial work, no side effect."
    local inst = T.load{ enable = true }
    local NSi = inst.NS
    local before = #NSi.Database.GetWindows()
    say(inst, "disable")

    local lines = say(inst, "window new Second")
    assertTrue(refusedOnly(lines), joined(lines))
    assertEqual(#NSi.Database.GetWindows(), before, "a window was created by a refused verb")

    -- And the positions verb, whose act is neither a call into a module nor a row write.
    local moved = 0
    local realReset = NSi.WindowManager.ResetPositions
    NSi.WindowManager.ResetPositions = function(...) moved = moved + 1; return realReset(...) end
    assertTrue(refusedOnly(say(inst, "reset-positions")))
    NSi.WindowManager.ResetPositions = realReset
    assertEqual(moved, 0)
end)

test("Slash: EVERY verb off the live list refuses, so a new one is gated by default", function()
    -- THE STRUCTURAL HALF. The gate is the LIBRARY's, sitting on the one dispatch path rather than
    -- as a guard pasted into each handler, and the polarity is the point: a verb is refused unless
    -- it is on the standard's thirteen-verb live list, so the next verb this addon adds is refused
    -- while it is off without anyone remembering to say so.
    -- red under: passing a `liveVerbs` that names this addon's feature verbs.
    local inst = T.load{ enable = true }
    say(inst, "disable")

    local gated = 0
    for _, entry in ipairs(inst.NS.COMMANDS) do
        local verb = entry[1]
        if not LIVE_WHILE_DISABLED[verb] then
            gated = gated + 1
            local lines = say(inst, verb)
            assertTrue(refusedOnly(lines),
                "`/mm " .. verb .. "` did not refuse on exactly one line: " .. joined(lines))
        end
    end
    assertTrue(gated >= 6, "only " .. gated .. " feature verbs were found; the gate proves nothing")
end)

test("Slash: every verb on the live list still answers with the addon off", function()
    -- THE OTHER SIDE OF THE SAME RULE, and the one that matters most: read literally, "refuse while
    -- disabled" takes the whole command surface down, the verb that undoes the state included. Each
    -- is driven with a real argument where it needs one, because a verb answering a usage line
    -- would satisfy a weaker assertion while being just as broken.
    local inst = T.load{ enable = true }
    local NSi = inst.NS
    assertTrue(NSi.SetByPath("master.scale", 1.5))
    say(inst, "disable")

    local opened = 0
    NSi.OpenOptionsPanel = function() opened = opened + 1 end

    for _, command in ipairs({
        "version", "config", "list", "get enabled", "set master.alpha 0.5",
        "reset master.scale", "debug", "perf help", "diagnostics",
    }) do
        local lines = say(inst, command)
        for _, line in ipairs(lines) do
            assertFalse(isRefusal(line), "`/mm " .. command .. "` was refused: " .. line)
        end
    end

    -- `help` IS ON THE LIVE LIST AND IS NOT REFUSED, and it is driven apart from the rest because
    -- it wears the refusal line as a NOTICE rather than as an answer (LibKa0s-Slash version 13).
    -- The index prints in full -- the player has to be able to SEE `enable` in the list -- and the
    -- line sits immediately under the header, unindented, because a reader scanning the rows needs
    -- to know that most of what they are reading is standing down.
    local help = say(inst, "help")
    assertTrue(#help > 6, "the index must print in full, not collapse to the notice")
    local refusals = 0
    for _, line in ipairs(help) do if isRefusal(line) then refusals = refusals + 1 end end
    assertEqual(refusals, 1, "exactly one notice, under the header")
    assertTrue(joined(help):find("/mm enable", 1, true) ~= nil, "`enable` must still be listed")

    assertEqual(opened, 1, "`/mm config` must still open the panel with the addon off")
    -- The schema CLI really WROTE, rather than merely answering: repairing a setting is the whole
    -- reason it stays live.
    assertEqual(NSi.GetSetting("master.alpha"), 0.5)
    assertEqual(NSi.GetSetting("master.scale"), NSi.FindSchemaRow("master.scale").default)

    -- And `enable` above all, or the pair is one-way.
    say(inst, "enable")
    assertTrue(NSi.db.profile.enabled)
end)

test("Slash: enabling the addon again gives the feature verbs back", function()
    -- A GATE RATHER THAN A REMOVAL. The verb keeps its row in the help index and on the settings
    -- landing page throughout -- a verb that vanished from the help block while the addon was off
    -- would be a second way to lose it -- so what changes is only what the handler does.
    local inst = T.load{ enable = true }
    local NSi = inst.NS
    say(inst, "disable")
    assertTrue(refusedOnly(say(inst, "window new Second")))

    say(inst, "enable")
    local before = #NSi.Database.GetWindows()
    local lines = say(inst, "window new Second")
    assertEqual(#NSi.Database.GetWindows(), before + 1, joined(lines))

    -- The help index never lost the verb.
    assertTrue(joined(say(inst, "help")):find("window", 1, true) ~= nil)
end)

test("Slash: nothing refuses on an install whose store has not been built", function()
    -- The descriptor's `isEnabled` reaches NS.IsDisabled, which tests the seam for FALSE rather
    -- than for truthiness: NS.GetSetting answers nil before NS:InitDB has run, and "nothing has
    -- said otherwise" is not "off". A truthiness test would refuse every feature verb on a
    -- half-loaded install, where the player is least equipped to work out why.
    local inst = T.load{ initDB = false, options = false }
    local lines = say(inst, "toggle")
    for _, line in ipairs(lines) do
        assertFalse(isRefusal(line), "a store-less install refused a feature verb: " .. line)
    end
end)
