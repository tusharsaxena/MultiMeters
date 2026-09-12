-- tests/test_slash.lua
--
-- settings/Slash.lua's half of the CLI. The dispatcher, the help renderer, the
-- row formatter and the value parser are LibKa0s-Slash-1.0's and are tested in
-- that repo (testing-§8); what is ours is the verb table, the five host verbs,
-- the adapters that point the library's schema seams at NS.SetByPath, and the
-- registration.
--
-- ── THE SHAPE CASE ────────────────────────────────────────────────────────────
--
-- NS.COMMANDS entries are ORDERED POSITIONAL TRIPLES `{ name, desc, handler }`,
-- because `entry[1]` / `entry[2]` / `entry[3]` is what the library reads. A table
-- of named fields (`{ name =, desc =, fn = }`) does not fail loudly: it loads
-- clean, `findCommand` matches nothing, and EVERY verb the user types answers
-- "unknown command" with no error to read and nothing in the log. It is the
-- cheapest possible mistake and the most expensive one to notice, so the shape is
-- asserted directly rather than inferred from one verb happening to work.

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

local function verbNames(commands)
    local names = {}
    for _, entry in ipairs(commands) do names[#names + 1] = entry[1] end
    return names
end

local function findVerb(commands, name)
    for _, entry in ipairs(commands) do
        if entry[1] == name then return entry end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- The verb table's shape
-- ---------------------------------------------------------------------------

test("Slash: NS.COMMANDS entries are positional triples, not named fields", function()
    assertEqual(type(NS.COMMANDS), "table")
    assertTrue(#NS.COMMANDS >= 15, "the table is an ARRAY; a keyed table has length 0")

    for i, entry in ipairs(NS.COMMANDS) do
        local where = "NS.COMMANDS[" .. i .. "]"
        assertEqual(type(entry), "table", where)
        assertEqual(type(entry[1]), "string", where .. "[1] must be the verb name")
        assertEqual(type(entry[2]), "string", where .. "[2] must be the description")
        assertEqual(type(entry[3]), "function", where .. "[3] must be the handler")
        assertTrue(entry[1] ~= "", where .. " has an empty verb name")
        assertTrue(entry[2] ~= "", where .. " has an empty description")

        -- The named-field spelling, asserted absent. This is the whole case: an
        -- entry carrying BOTH shapes would satisfy the three checks above and
        -- still be the wrong table to hand the library.
        assertEqual(entry.name, nil, where .. " carries a `name` field — the library reads entry[1]")
        assertEqual(entry.desc, nil, where .. " carries a `desc` field — the library reads entry[2]")
        assertEqual(entry.fn,   nil, where .. " carries an `fn` field — the library reads entry[3]")
        assertEqual(entry.handler, nil, where .. " carries a `handler` field")
    end
end)

test("Slash: no verb is declared twice", function()
    local seen = {}
    for _, name in ipairs(verbNames(NS.COMMANDS)) do
        assertEqual(seen[name], nil, "the verb '" .. tostring(name) .. "' is declared twice")
        seen[name] = true
    end
end)

test("Slash: every reserved verb is present, in the order the standard fixes", function()
    local RESERVED = {
        "help", "config", "list", "get", "set",
        "reset", "resetall", "debug", "perf", "version",
    }
    local names = verbNames(NS.COMMANDS)
    for i, want in ipairs(RESERVED) do
        assertEqual(names[i], want,
            "reserved verb " .. i .. " should be '" .. want .. "', got '" .. tostring(names[i]) .. "'")
    end
end)

test("Slash: the host verbs are declared and each carries a real handler", function()
    for _, name in ipairs({ "lock", "test", "toggle", "window", "reset-positions" }) do
        local entry = findVerb(NS.COMMANDS, name)
        assertTrue(entry ~= nil, "the host verb '" .. name .. "' is missing")
        assertEqual(type(entry[3]), "function")
    end
end)

test("Slash: `reset` takes a PATH, not a page", function()
    local entry = findVerb(NS.COMMANDS, "reset")
    local desc = entry[2]
    assertTrue(desc:find("<path>", 1, true) ~= nil,
        "the help index and the README both render this string; it must name a path, got: " .. desc)
    assertTrue(desc:lower():find("page") == nil,
        "a page-shaped reset is what the panel's own Defaults button is for, got: " .. desc)
end)

test("Slash: every sub-verb a handler accepts is named in its own description", function()
    -- The generated help index, the settings landing page and the README's
    -- command table read these strings and nothing else, so a sub-verb missing
    -- here is a sub-verb nobody can discover (slash-commands-§4).
    assertTrue(findVerb(NS.COMMANDS, "debug")[2]:find("on", 1, true) ~= nil)
    assertTrue(findVerb(NS.COMMANDS, "debug")[2]:find("off", 1, true) ~= nil)
    local window = findVerb(NS.COMMANDS, "window")[2]
    for _, sub in ipairs({ "list", "new", "delete", "copy" }) do
        assertTrue(window:find(sub, 1, true) ~= nil,
            "`/mm window " .. sub .. "` is implemented but undocumented: " .. window)
    end
end)

-- ---------------------------------------------------------------------------
-- Dispatch
-- ---------------------------------------------------------------------------

test("Slash: an unknown verb says so and prints the help", function()
    local inst = T.load()
    local lines = say(inst, "wibble")
    assertTrue(#lines > 1, "an unknown verb should be answered and then helped")
    assertTrue(joined(lines):lower():find("wibble") ~= nil, joined(lines))
end)

test("Slash: `options` is an alias for `config`, not a second command", function()
    assertEqual(findVerb(NS.COMMANDS, "options"), nil,
        "the back-compat spelling is an ALIAS; a second entry would be a second thing to keep in step")
    local inst = T.load()
    local opened = 0
    inst.NS.OpenOptionsPanel = function() opened = opened + 1 end
    say(inst, "options")
    say(inst, "config")
    assertEqual(opened, 2, "both spellings must reach the same handler")
end)

test("Slash: `version` reports the TOC's version rather than a hardcoded string", function()
    local inst = T.load()
    inst.mocks.__toc.Version = "9.9.9"
    assertTrue(joined(say(inst, "version")):find("9.9.9", 1, true) ~= nil,
        "the version must be read from the packaged manifest (slash-commands-§3)")
end)

test("Slash: `get` and `set` land on the addon's own schema seam", function()
    local inst = T.load()
    say(inst, "set window.frame.width 300")
    assertEqual(inst.NS.GetSetting("window.frame.width"), 300)
    assertTrue(joined(say(inst, "get window.frame.width")):find("300", 1, true) ~= nil)
end)

test("Slash: `set` on a window path writes the ACTIVE window", function()
    local inst = T.load()
    local NSi = inst.NS
    assertTrue(NSi.WindowManager:Create("Second"))
    local list = NSi.Database.GetWindows()
    NSi.State.SetActiveWindow(list[2].id)

    say(inst, "set window.frame.width 360")
    assertEqual(list[2].frame.width, 360)
    assertEqual(list[1].frame.width, 694, "the window the picker is NOT on must be untouched")
end)

test("Slash: `reset <path>` restores exactly that one setting", function()
    local inst = T.load()
    local NSi = inst.NS
    say(inst, "set window.frame.width 300")
    say(inst, "set window.frame.height 400")
    say(inst, "reset window.frame.width")
    assertEqual(NSi.GetSetting("window.frame.width"), 694, "the shipped width")
    assertEqual(NSi.GetSetting("window.frame.height"), 400, "reset must not sweep the page")
end)

-- ── resetall: the General page's popup, then the profile reset ───────────────
--
-- The owner's decision of 2026-09-12: `/mm resetall` is a real profile reset, so
-- it DELETES every extra window, and it asks first with the SAME "Reset all
-- settings?" popup the General page's button opens. Nothing is reset until the
-- player accepts.

--- A loaded instance with two moved windows, debug on, the popup key the verb
--- asks for captured, and every debug line formatted. Answers the instance, the
--- captured keys, the lines, and a function that puts NS.Debug back.
local function resetallScene()
    local inst = T.load()
    local NSi = inst.NS
    assertTrue(NSi.WindowManager:Create("Second"))
    local list = NSi.Database.GetWindows()
    assertEqual(#list, 2)
    assertTrue(NSi.SetByPath("window.frame.width", 300, list[1].id))
    assertTrue(NSi.SetByPath("window.frame.width", 310, list[2].id))
    NSi.State.SetActiveWindow(list[1].id)
    NSi.State.debug = true

    local asked = {}
    inst.mocks.StaticPopup_Show = function(key) asked[#asked + 1] = key end
    local lines, original = {}, NSi.Debug
    NSi.Debug = function(tag, fmt, ...)
        local a = { ... }
        for i = 1, select("#", ...) do a[i] = tostring(a[i]) end
        lines[#lines + 1] = "[" .. tag .. "] " .. tostring(fmt):format(a[1], a[2], a[3], a[4])
    end
    return inst, asked, lines, function() NSi.Debug = original end
end

--- The two windows are still there, each at the width it was given.
local function assertUntouched(NSi, why)
    local list = NSi.Database.GetWindows()
    assertEqual(#list, 2, why .. ": a window was deleted")
    assertEqual(list[1].frame.width, 300, why .. ": the first window was reset")
    assertEqual(list[2].frame.width, 310, why .. ": the second window was reset")
end

test("Slash: `resetall` opens the Reset all settings popup and changes nothing", function()
    -- It used to reset on the spot. A reset that deletes windows asks first,
    -- through the one popup the General page's button uses, so the two cannot
    -- word the warning differently or reset different things.
    -- red under: doResetAll calling Helpers.RestoreAllDefaults directly.
    local inst, asked, lines, restore = resetallScene()
    local ok, err = pcall(say, inst, "resetall")
    restore()
    assertTrue(ok, tostring(err))

    assertEqual(table.concat(asked, ","), "MULTIMETERS_RESET_ALL")
    assertEqual(type(inst.mocks.StaticPopupDialogs.MULTIMETERS_RESET_ALL.OnAccept), "function",
        "the verb asked for a popup the General page does not declare")
    assertUntouched(inst.NS, "showing the popup")
    assertEqual(#lines, 0, "showing the popup logged: " .. table.concat(lines, " | "))
end)

test("Slash: accepting the `resetall` popup resets the profile and logs ONE line", function()
    -- A profile reset leaves one fresh window at the shipped defaults, whichever
    -- window the picker was on, and the one line is OnProfileReset's.
    -- red under: an OnAccept that walks the rows of the active window alone.
    local inst, asked, lines, restore = resetallScene()
    local NSi = inst.NS
    local ok, err = pcall(function()
        say(inst, "resetall")
        inst.mocks.StaticPopupDialogs[asked[1]].OnAccept()
    end)
    restore()
    assertTrue(ok, tostring(err))

    local after = NSi.Database.GetWindows()
    assertEqual(#after, 1, "a profile reset leaves one fresh window, not the second one restyled or kept")
    assertEqual(after[1].frame.width, 694, "the window left is at the shipped width")
    assertEqual(#lines, 1, "resetall logged: " .. table.concat(lines, " | "))
    assertEqual(lines[1], "[Set] reset profile 'Default' to defaults")
end)

test("Slash: declining the `resetall` popup does nothing", function()
    -- No, Escape and the popup closing on its own all end without OnAccept.
    -- red under: an OnCancel (or OnHide) that resets anyway.
    local inst, asked, lines, restore = resetallScene()
    local ok, err = pcall(function()
        say(inst, "resetall")
        local dialog = inst.mocks.StaticPopupDialogs[asked[1]]
        if dialog.OnCancel then dialog.OnCancel() end
        if dialog.OnHide then dialog.OnHide() end
    end)
    restore()
    assertTrue(ok, tostring(err))

    assertUntouched(inst.NS, "declining the popup")
    assertEqual(#lines, 0, "declining logged: " .. table.concat(lines, " | "))
end)

test("Slash: `list` groups by the row's PAGE, the same key the panel pages use", function()
    local inst = T.load()
    local text = joined(say(inst, "list"))
    -- `groupKey` is written out on the descriptor precisely so the CLI listing
    -- and the panel cannot disagree about where a row belongs.
    assertTrue(text:find("window.frame.width", 1, true) ~= nil, text)
    assertTrue(text:lower():find("frame") ~= nil, text)
end)

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

-- ---------------------------------------------------------------------------
-- export: the verb, and the two ways it refuses
-- ---------------------------------------------------------------------------

--- Replace NS.Export.Open with a spy and hand back the call log.
---
--- @param inst table
--- @return table  array of the windows Open was called with
local function spyOnExport(inst)
    local opened = {}
    inst.NS.Export.Open = function(a, b)
        opened[#opened + 1] = (a == inst.NS.Export) and b or a
    end
    return opened
end

test("Slash: `export` opens the modal on the window the player named", function()
    local inst = T.load()
    assertTrue(findVerb(inst.NS.COMMANDS, "export") ~= nil,
        "the verb table is the ONE place every command is declared")

    assertTrue(inst.NS.WindowManager:Create("Cleave"))
    local opened = spyOnExport(inst)

    say(inst, "export Cleave")
    assertEqual(#opened, 1, "one window named, one modal opened")
    assertEqual(opened[1].name, "Cleave", "the CONFIG of the named window, not another")
end)

test("Slash: `export` with no name falls back to a window rather than to nothing", function()
    -- `/mm export` typed on a fresh login, where nothing has ever set
    -- activeWindowId, has to mean something: the CLI has no picker.
    local inst = T.load()
    local opened = spyOnExport(inst)

    say(inst, "export")
    assertEqual(#opened, 1)
    assertTrue(opened[1] ~= nil, "a window, not nil")
end)

test("Slash: `export` names a window it cannot find rather than opening another", function()
    local inst = T.load()
    local opened = spyOnExport(inst)

    local lines = say(inst, "export NoSuchWindow")
    assertEqual(#opened, 0, "a typo must never export somebody else's window")
    assertTrue(joined(lines):find("NoSuchWindow", 1, true) ~= nil,
        "the message has to name what was typed")
end)

test("Slash: `export` refuses while the game restricts combat data", function()
    -- red under: dropping the Available() call, which would open a modal with two
    -- dead buttons instead of saying why.
    local inst = T.load()
    inst.mocks.setRestricted(true)
    local opened = spyOnExport(inst)

    local lines = say(inst, "export")
    assertEqual(#opened, 0, "no modal opens mid-pull")
    assertTrue(joined(lines):lower():find("restrict", 1, true) ~= nil,
        "the refusal must say why: " .. joined(lines))
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
-- The host verbs
-- ---------------------------------------------------------------------------

test("Slash: `lock` sets, and a bare `lock` toggles", function()
    local inst = T.load()
    local M = inst.NS.WindowManager
    say(inst, "lock on")
    assertTrue(M:IsLocked())
    say(inst, "lock off")
    assertFalse(M:IsLocked())
    say(inst, "lock")
    assertTrue(M:IsLocked(), "a bare verb toggles, which is what a nil boolean parse means")
end)

test("Slash: `test` sets and toggles through the registry", function()
    local inst = T.load()
    local M = inst.NS.WindowManager
    say(inst, "test on")
    assertTrue(M:IsTest())
    say(inst, "test off")
    assertFalse(M:IsTest())
end)

test("Slash: `lock` moves the lock and NOTHING else", function()
    -- One verb, one effect. `/mm lock off` used to switch placeholder data on as
    -- a side effect, which is how a player ends up with a window full of Ka0stank
    -- and no idea which control put it there.
    -- red under: restoring the SetTestMode call in WindowManager:SetLocked.
    local inst = T.load()
    local M = inst.NS.WindowManager
    say(inst, "lock off")
    assertFalse(M:IsLocked())
    assertFalse(M:IsTest(), "unlocking is not a request for test data")

    say(inst, "test on")
    say(inst, "lock on")
    assertTrue(M:IsLocked())
    assertTrue(M:IsTest(), "and locking does not take it away again")
end)

test("Slash: `window new` and `window delete` act on the registry", function()
    local inst = T.load()
    local NSi = inst.NS
    assertEqual(#NSi.Database.GetWindows(), 1)
    say(inst, "window new Raid Frame")
    assertEqual(#NSi.Database.GetWindows(), 2)
    assertEqual(NSi.Database.GetWindows()[2].name, "Raid Frame",
        "a window name is user data and keeps its case and its spacing")
    say(inst, "window delete Raid Frame")
    assertEqual(#NSi.Database.GetWindows(), 1)
end)

test("Slash: `window list` prints one line per window", function()
    local inst = T.load()
    say(inst, "window new Second")
    local lines = say(inst, "window list")
    assertTrue(#lines >= 2, "two windows, at least two lines; got " .. #lines)
end)

test("Slash: `window` with an unknown sub-verb prints the usage", function()
    local inst = T.load()
    local text = joined(say(inst, "window explode"))
    assertTrue(text:find("/mm window list", 1, true) ~= nil, text)
end)

test("Slash: `toggle` reaches the registry and reports its refusal", function()
    local inst = T.load()
    local lines = say(inst, "toggle NoSuchWindow")
    assertTrue(#lines >= 1, "a named window that does not exist must be answered")
end)

test("Slash: `reset-positions` moves every window and says how many", function()
    local inst = T.load()
    local NSi = inst.NS
    say(inst, "window new Second")
    for _, w in ipairs(NSi.Database.GetWindows()) do
        w.frame.position = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 111, y = -222 }
    end
    local text = joined(say(inst, "reset-positions"))
    assertTrue(text:find("2 windows", 1, true) ~= nil, text)
    for _, w in ipairs(NSi.Database.GetWindows()) do
        assertEqual(w.frame.position.point, "CENTER")
        assertEqual(w.frame.position.x, 0)
    end
end)

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
    -- property is "no call site was missed" and a behavioural test can only ever
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
-- `/mm debug`: the read verbs, the feign recording, and the console toggle
-- ---------------------------------------------------------------------------
--
-- doDebug is a ladder over one word, and its arms are NOT interchangeable.
-- `diag`, `recap` and `identity` sit ABOVE the `NS.DebugLog` guard on purpose —
-- they are what a player is asked to type when something looks wrong, and a
-- console they have to open first is one more step between a bug and its report.
-- The comment in settings/Slash.lua says so three times, once per verb, which is
-- how much the ordering is worth. The cases below pin each arm to its own
-- outcome, so a ladder rewritten as a lookup cannot cross-wire two verbs, drop
-- one below the guard, or turn the final toggle into a refusal.

--- Replace the three report entry points with counters and hand back the tally.
---
--- Spied rather than run: each real report prints dozens of lines into the
--- console sink, and what is being pinned here is WHICH report a verb reaches,
--- not what that report says.
local function spyReports(inst)
    local calls = { diag = 0, recap = 0, identity = 0 }
    local D = inst.NS.Diagnostics
    D.Report           = function() calls.diag     = calls.diag     + 1 end
    D.ReportDeathRecap = function() calls.recap    = calls.recap    + 1 end
    D.ReportIdentity   = function() calls.identity = calls.identity + 1 end
    return calls
end

test("Slash: `diag`, `recap` and `identity` each reach their OWN report and no other", function()
    -- Three verbs, three entry points, and the three reports are different
    -- lengths for a reason: `recap` is the issue #1 probe on its own and
    -- `identity` the issue #22 capture, both extracted precisely so a player
    -- mid-pull is not handed the forty lines of atlas and font output `diag`
    -- carries. A lookup table that maps two of them to the same member would
    -- undo that and still print something plausible.
    local inst = T.load()
    local calls = spyReports(inst)

    say(inst, "debug diag")
    assertEqual(calls.diag, 1, "`diag` runs the full report")
    assertEqual(calls.recap + calls.identity, 0, "and reaches nothing else")

    say(inst, "debug recap")
    assertEqual(calls.recap, 1, "`recap` runs the death-recap probe alone")
    assertEqual(calls.diag + calls.identity, 1, "the full report must not run a second time")

    say(inst, "debug identity")
    assertEqual(calls.identity, 1, "`identity` runs the mid-pull correlation capture alone")
    assertEqual(calls.diag + calls.recap, 2, "and neither of the other two again")
end)

test("Slash: the three read verbs run with no debug console seam at all", function()
    -- THE ORDERING THE COMMENTS CALL LOAD-BEARING, asserted rather than trusted.
    -- All three sit above `if not NS.DebugLog then return end`; move any of them
    -- below it and the verb a player was asked to type answers with silence on
    -- exactly the broken install where the answer matters most.
    -- red under: folding the read verbs into the console-toggle ladder.
    local inst = T.load()
    local calls = spyReports(inst)

    local realLog = inst.NS.DebugLog
    inst.NS.DebugLog = nil
    local ok, err = pcall(function()
        say(inst, "debug diag")
        say(inst, "debug recap")
        say(inst, "debug identity")
    end)
    inst.NS.DebugLog = realLog

    assertTrue(ok, "a read verb must not raise when the console seam is absent: " .. tostring(err))
    assertEqual(calls.diag, 1, "`diag` ran without the console")
    assertEqual(calls.recap, 1, "`recap` ran without the console")
    assertEqual(calls.identity, 1, "`identity` ran without the console")
end)

test("Slash: a read verb moves neither the console window nor the logging flag", function()
    -- The other half of the same ordering: the read verbs `return`, so none of
    -- them may fall through to the toggle at the bottom of the ladder. A `diag`
    -- that also opened or closed the console would be a report the player has to
    -- undo a window change to read.
    local inst = T.load()
    spyReports(inst)
    local D = inst.NS.DebugLog
    local shownBefore = D:IsShown()

    say(inst, "debug diag")
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
    say(inst, "debug DIAG")
    assertEqual(calls.diag, 1, "`DIAG` is `diag`")
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
    assertTrue(D:IsShown() ~= shownBefore, "an unrecognised word toggles the window")
    assertTrue(not inst.NS.State.debug, "and does not touch the logging flag")
end)

test("Slash: with core/Diagnostics.lua absent the debug verbs go quiet, not through", function()
    -- Every one of the four guards on the module and returns either way. On a
    -- half-installed addon a `diag` must not fall through to the console toggle
    -- and move a window the player never asked about — the failure would look
    -- like the command working.
    local inst = T.load()
    local realD = inst.NS.Diagnostics
    inst.NS.Diagnostics = nil
    local D = inst.NS.DebugLog
    local shownBefore = D:IsShown()

    local ok, err = pcall(function()
        for _, tail in ipairs({ "diag", "recap", "identity", "feign", "feign on" }) do
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

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

test("Slash: registration goes through AceConsole, on both tokens", function()
    local inst = T.load()
    local target = inst.NS.addon or inst.NS
    local registered = {}
    local real = target.RegisterChatCommand
    target.RegisterChatCommand = function(_, token, handler)
        registered[token] = handler
    end
    inst.NS.Slash:Register()
    target.RegisterChatCommand = real

    assertEqual(type(registered["mm"]), "function")
    assertEqual(type(registered["multimeters"]), "function")
end)

test("Slash: both registered tokens reach the SAME dispatcher", function()
    local inst = T.load()
    local target = inst.NS.addon or inst.NS
    local registered = {}
    local real = target.RegisterChatCommand
    target.RegisterChatCommand = function(_, token, handler) registered[token] = handler end
    inst.NS.Slash:Register()
    target.RegisterChatCommand = real

    local opened = 0
    inst.NS.OpenOptionsPanel = function() opened = opened + 1 end
    registered["mm"]("config")
    registered["multimeters"]("config")
    assertEqual(opened, 2, "the alias must be a real alias, not a second command with its own drift")
end)

test("Slash: no raw SLASH_* global is claimed anywhere", function()
    -- AceConsole owns the deregistration a /reload needs and the collision check
    -- two addons claiming one token need; a hand-rolled SLASH_MM1 has neither.
    local inst = T.load()
    inst.NS.Slash:Register()
    for _, name in ipairs({
        "SLASH_MM1", "SLASH_MM2", "SLASH_MULTIMETERS1", "SLASH_MULTIMETERS2",
        "SLASH_KA0SMULTIMETERS1",
    }) do
        assertEqual(_G[name], nil, name .. " was set — registration must go through AceConsole")
        assertEqual(inst.mocks[name], nil, name .. " was set on the simulated client")
    end
    assertEqual(_G.SlashCmdList, nil)
    assertEqual(inst.mocks.SlashCmdList, nil)
end)

test("Slash: Register is a no-op rather than a raise when there is no AceConsole", function()
    local inst = T.load()
    local target = inst.NS.addon or inst.NS
    local real = target.RegisterChatCommand
    target.RegisterChatCommand = nil
    local ok = pcall(function() inst.NS.Slash:Register() end)
    target.RegisterChatCommand = real
    assertTrue(ok, "a half-installed Ace stack must not take the load down")
end)

test("Slash: /mm list heads each block with the page AND the tab", function()
    -- `page` was the whole heading while a page was one scroll. It is now a page and a tab, and
    -- a CLI that named only the first half would send someone to a page with no way to say
    -- which of its six tabs the setting is on.
    -- red under: reverting groupKey to row.page, or joining with a plain "/" the panel never shows.
    local inst = T.load()
    local text = joined(say(inst, "list"))
    assertTrue(text:find("frame \226\128\186 ", 1, true) ~= nil,
        "no page \226\128\186 tab heading in the listing")
end)

test("Slash: `set window.name` keeps every word of a multi-word name", function()
    -- LibKa0s-Slash-1.0 minor 10 hands a string row the whole remainder, trimmed.
    -- Through minor 9 it took the first word, so `/mm set window.name Raid Damage
    -- Meter` renamed the window "Raid".
    -- red under: Slash.lua minor 9 (the parse splitting a string row's value).
    local inst = T.load()
    local out = say(inst, "set window.name  Raid Damage Meter ")
    assertEqual(inst.NS.GetSetting("window.name"), "Raid Damage Meter", joined(out))
    assertEqual(inst.NS.Database.GetWindows()[1].name, "Raid Damage Meter",
        "the window record carries the whole name")
end)
