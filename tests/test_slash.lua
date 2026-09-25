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
    -- THIRTEEN now. `enable` and `disable` are reserved across the collection (slash-commands-§2)
    -- and sit where the standard's own COMMANDS example puts them: after `config`, ahead of the
    -- schema verbs. They are ALIASES for the `enabled` row -- the assertions below pin that they
    -- hold no state of their own. `diagnostics` (debug-logging-§14) follows `debug`, where the
    -- standard's example puts it.
    local RESERVED = {
        "help", "config", "enable", "disable", "list", "get", "set",
        "reset", "resetall", "debug", "diagnostics", "perf", "version",
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
-- `enable` / `disable` — aliases, never a second switch
-- ---------------------------------------------------------------------------
--
-- slash-commands-§2 reserves both verbs collection-wide and fixes what they mean: they write the
-- stored path the `Enable Multi Meters` checkbox writes, through the same single write seam, and
-- they hold NO state of their own. The cases below pin both halves of that — the write lands where
-- the checkbox's does, and nothing else anywhere changed — plus the clause that keeps the pair from
-- being one-way: the dispatcher survives the disabled state.

test("Slash: `enable` and `disable` write the Master-controls Enable path", function()
    local inst = T.load()
    local NSi = inst.NS

    say(inst, "disable")
    assertFalse(NSi.db.profile.enabled, "`disable` must write the row's own stored path")
    assertFalse(NSi.GetSetting("enabled"), "and the seam must read it back the same way")

    say(inst, "enable")
    assertTrue(NSi.db.profile.enabled)
end)

test("Slash: they are the SAME write `/mm set enabled` makes", function()
    local inst = T.load()
    local NSi = inst.NS

    -- Proven by intercepting the one seam rather than by comparing outcomes: two routes that
    -- happen to agree today are exactly what drifts on the next behavior change.
    local seen = {}
    local real = NSi.SetByPath
    NSi.SetByPath = function(path, value, windowId)
        seen[#seen + 1] = tostring(path) .. "=" .. tostring(value)
        return real(path, value, windowId)
    end

    say(inst, "disable")
    say(inst, "set enabled false")
    NSi.SetByPath = real

    assertEqual(seen[1], "enabled=false")
    assertEqual(seen[2], seen[1], "the verb must take the path the long form takes, not a copy")
end)

test("Slash: they hold no state of their own", function()
    local inst = T.load()
    local NSi = inst.NS

    say(inst, "disable")
    -- No second key, no session flag, no `NS.enabled` local. A second record of one state is free
    -- to disagree with the checkbox, and the first time it does the player is told two things.
    assertEqual(NSi.enabled, nil)
    assertEqual(NSi.State.enabled, nil)
    assertEqual(NSi.db.profile.disabled, nil)

    -- And the checkbox reads the verb's write, because there is only one place to read.
    local row = NSi.FindSchemaRow("enabled")
    assertTrue(row ~= nil)
    assertFalse(NSi.GetSetting(row.path))
end)

test("Slash: the acknowledgment is slash-commands-§5's `path = value` line", function()
    local inst = T.load()
    -- The library's shared formatter, re-read after the write. A verb that answered in its own
    -- words would be untidy rather than broken, which is why this is the house shape and not a
    -- second sentence to keep in step.
    local lines = joined(say(inst, "disable"))
    assertTrue(lines:find("enabled", 1, true) ~= nil, lines)
    assertTrue(lines:find("false", 1, true) ~= nil, lines)
end)

test("Slash: the reactor runs, so the windows follow the verb", function()
    local inst = T.load{ enable = true }
    local refreshes = 0
    inst.NS.Visibility.Refresh = function() refreshes = refreshes + 1 end

    say(inst, "disable")
    -- `enabled` carries `onChange = refreshVisibility`, because the effect is a window appearing
    -- or disappearing rather than a window redrawing, which CONFIG_CHANGED cannot express. Going
    -- around the seam would skip it and leave every window on screen with the addon off.
    assertTrue(refreshes > 0, "the row's onChange did not run")
end)

test("Slash: the dispatcher survives the disabled state, so the pair is not one-way", function()
    local inst = T.load{ enable = true }
    local NSi = inst.NS

    say(inst, "disable")
    assertFalse(NSi.db.profile.enabled)

    -- *Disabled* means the addon stands its features down. It does NOT mean it unregisters its
    -- chat command, tears down NS.COMMANDS or drops its dispatcher — an addon that did any of
    -- those has built a switch that only goes one way, and the only route back is the settings
    -- panel the player was trying not to open (slash-commands-§2).
    assertTrue(#say(inst, "help")    > 0, "`/mm help` went silent with the addon off")
    assertTrue(#say(inst, "version") > 0, "`/mm version` went silent with the addon off")

    -- A bare `/mm` runs the host's `config` verb (slash-commands-§4), so what proves it is
    -- alive is the panel opening rather than a chat line.
    local opened = 0
    NSi.OpenOptionsPanel = function() opened = opened + 1 end
    say(inst, "")
    say(inst, "config")
    assertEqual(opened, 2, "`/mm` and `/mm config` went silent with the addon off")

    -- And the verb that matters most still works.
    say(inst, "enable")
    assertTrue(NSi.db.profile.enabled, "`/mm enable` could not turn the addon back on")
end)

test("Slash: NOTHING reads the raw `enabled` key any more", function()
    -- What makes the case above structural rather than a lucky observation: the STORED PATH is read
    -- in exactly one place, and it is not on any path that could reach the dispatcher.
    --
    -- THE EXPECTED ANSWER IS NOW *NOTHING AT ALL*, and the move is the stand-down
    -- (slash-commands-§7). `NS.ShouldShow` used to read `db.profile.enabled` directly as one rung
    -- of its show ladder -- which was this addon's draw gate, and anti-pattern #85. The one reader left is
    -- core/LifecycleSetup.lua's NS.SyncEnabledHold, and it goes through NS.GetSetting, the read
    -- seam, exactly as the checkbox and `/mm get enabled` do. What this case forbids is any reader
    -- of the RAW profile key -- a place the addon can decide for itself what "off" means without
    -- the latch hearing about it -- not a second caller of the one seam.
    local hits = {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        local fh = io.open(T.root .. "/" .. rel, "r")
        if fh then
            local n = 0
            for line in fh:lines() do
                n = n + 1
                if line:find("profile.enabled", 1, true) then
                    hits[#hits + 1] = rel .. ":" .. n
                end
            end
            fh:close()
        end
    end
    assertEqual(table.concat(hits, ", "):gsub(":%d+", ""), "",
        "a raw reader of the master switch is a place it can turn something off behind the latch")
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

test("Slash: a boolean that is OFF reads back as false, not nil", function()
    local inst = T.load()
    -- THE `and ... or nil` COLLAPSE, caught by the `/mm disable` echo. The descriptor's `get`
    -- adapter was `NS.GetSetting and NS.GetSetting(path) or nil`, which turns a stored `false`
    -- into nil -- so every boolean row that was off printed `nil` through `/mm get`, and every
    -- `/mm set <bool> false` echoed `nil` as the value it had just stored: a read-back
    -- contradicting the write it was confirming. slash-commands-§5 says booleans render
    -- `true` / `false` and a nil STORED value renders `nil`, so the two were indistinguishable.
    say(inst, "set window.frame.locked false")
    local shown = joined(say(inst, "get window.frame.locked"))
    assertTrue(shown:find("false", 1, true) ~= nil, shown)
    assertTrue(shown:find("nil", 1, true) == nil, shown)
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

test("Slash: the column array lists and reads as how many columns are shown", function()
    -- `window.columns` is a row since issue #52 (hidden, written whole), so `/mm list` and
    -- `/mm get` reach it. A table has no formatter of the library's own, and its generic
    -- renderer masks anything it cannot concatenate, so without the descriptor's `format` the
    -- listing printed the secret sentinel for a value that is not secret at all.
    -- red under: no `format` on the Slash descriptor.
    local inst = T.load()
    local shown = 0
    for _, c in ipairs(inst.NS.GetSetting("window.columns")) do
        if c.enabled then shown = shown + 1 end
    end
    local want = ("%d shown"):format(shown)
    local got = joined(say(inst, "get window.columns"))
    assertTrue(got:find("window.columns", 1, true) ~= nil and got:find(want, 1, true) ~= nil, got)
    local listed = joined(say(inst, "list"))
    assertTrue(listed:find("window.columns|r = |cFFFFFFFF" .. want, 1, true) ~= nil, listed)
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
-- A bare `/mm` (slash-commands-§4, standard v2.50.0)
-- ---------------------------------------------------------------------------

--- Chat text with WoW color escapes removed, so a verb reads as `/mm help`
--- whether or not the renderer painted it.
local function plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

test("Slash: a bare `/mm`, and a whitespace-only one, run the `config` verb with \"\"", function()
    -- LibKa0s-Slash minor 11: an empty or whitespace-only message goes to the
    -- host's registered `config` verb, called with "". The index is `/mm help`.
    -- red under: a library below minor 11, or `config` dropped from NS.COMMANDS.
    local inst = T.load()
    local entry = findVerb(inst.NS.COMMANDS, "config")
    assertTrue(entry ~= nil, "`config` is not registered, so a bare `/mm` falls back to help")

    local realHandler, got = entry[3], {}
    entry[3] = function(a) got[#got + 1] = a end
    local printed = {}
    for _, msg in ipairs({ "", "   ", "\t  \t" }) do
        printed[#printed + 1] = joined(say(inst, msg))
    end
    printed[#printed + 1] = joined(say(inst, nil))
    entry[3] = realHandler

    assertEqual(#got, 4, "not every bare `/mm` reached config")
    for i, a in ipairs(got) do assertEqual(a, "", "config was called with a remainder, case " .. i) end
    assertEqual(table.concat(printed), "", "a bare `/mm` printed instead of running config")
end)

test("Slash: a bare `/mm` opens the settings panel, the same act as `/mm config`", function()
    -- The verb is not replaced, only reached: the same NS.OpenOptionsPanel call,
    -- so the library's combat refusal is what a player in a fight sees.
    local inst = T.load()
    local opened, real = 0, inst.NS.OpenOptionsPanel
    inst.NS.OpenOptionsPanel = function() opened = opened + 1 end
    say(inst, "")
    say(inst, "  ")
    say(inst, "config")
    inst.NS.OpenOptionsPanel = real
    assertEqual(opened, 3, "a bare `/mm` and `/mm config` must both open the panel")
end)

test("Slash: a bare `/mm` lands on the top-level category, not a sub-page", function()
    -- `config` goes through LibKa0s-Options' OpenOptionsPanel, which opens the
    -- PARENT category -- the landing page -- by the id Settings handed back when
    -- it was registered. The harness's parent category answers id 1 and its
    -- subcategories answer none, so any other id is a sub-page.
    local inst = T.load()
    local ids = {}
    inst.mocks.Settings.OpenToCategory = function(id) ids[#ids + 1] = id end
    say(inst, "")
    assertEqual(#ids, 1, "a bare `/mm` did not open the settings window")
    assertEqual(ids[1], 1, "a bare `/mm` opened something other than the landing category")
end)

test("Slash: `/mm help` prints every verb, and does not open the panel", function()
    -- red under: `help` re-pointed at config, or the index losing a verb.
    local inst = T.load()
    local opened, real = 0, inst.NS.OpenOptionsPanel
    inst.NS.OpenOptionsPanel = function() opened = opened + 1 end
    local text = plain(joined(say(inst, "help")))
    inst.NS.OpenOptionsPanel = real

    assertEqual(opened, 0, "`/mm help` opened the panel")
    for _, entry in ipairs(inst.NS.COMMANDS) do
        assertTrue(text:find("/mm " .. entry[1], 1, true) ~= nil,
            "`/mm help` does not list `" .. entry[1] .. "`: " .. text)
    end
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

test("Slash: `test` repaints the panel on both edges, so the Test mode box follows the verb",
function()
    -- options-ui-§15: the Master controls box must be ticked exactly while test mode
    -- is on, whichever switch moved it. An open panel is only redrawn when asked.
    -- red under: WindowManager:SetTestMode not repainting the panel.
    local inst = T.load()
    local ns = inst.NS
    local row
    for _, r in ipairs(ns.Schema) do
        if r.path == "state.testMode" then row = r end
    end
    local repaints, real = 0, ns.RefreshOptionsPanel
    ns.RefreshOptionsPanel = function() repaints = repaints + 1 end

    say(inst, "test on")
    local afterOn = repaints
    local tickedOn = row.get()
    say(inst, "test off")
    ns.RefreshOptionsPanel = real

    assertTrue(afterOn > 0, "turning test mode on did not repaint the panel")
    assertTrue(repaints > afterOn, "turning test mode off did not repaint the panel")
    assertTrue(tickedOn, "the box did not read ticked after `/mm test on`")
    assertFalse(row.get(), "the box still reads ticked after `/mm test off`")
end)

test("Slash: `test` refuses to START in combat with one line, and still stops there", function()
    -- preview-mode (standard v2.48.0): a start during combat is refused, in one
    -- line, whether asked for with `on` or by a bare toggle; turning it off in
    -- combat stays allowed. red under: no combat check on the start, a check that
    -- also blocks the stop, or the verb printing its "on" line after a refusal.
    local inst = T.load()
    local M = inst.NS.WindowManager
    inst.mocks.setInCombat(true)

    local lines = say(inst, "test on")
    assertFalse(M:IsTest(), "`/mm test on` started test mode in combat")
    assertEqual(#lines, 1, "the refusal is one line: " .. joined(lines))
    assertTrue(lines[1]:find("Cannot start test mode during combat", 1, true) ~= nil, lines[1])

    lines = say(inst, "test")
    assertFalse(M:IsTest(), "a bare `/mm test` started test mode in combat")
    assertEqual(#lines, 1, joined(lines))
    assertTrue(lines[1]:find("Cannot start test mode during combat", 1, true) ~= nil, lines[1])

    inst.mocks.setInCombat(false)
    say(inst, "test on")
    assertTrue(M:IsTest())
    inst.mocks.setInCombat(true)
    say(inst, "test off")
    assertFalse(M:IsTest(), "turning test mode off in combat must stay allowed")
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

test("Slash: a bare `window delete` says nothing is selected, not a blank name", function()
    -- red under: WINDOW_VERBS.delete passing doWindow's "" tail to Delete, and
    -- unknownWindow formatting it into "No window named ''." (MM-06 review).
    local inst = T.load()
    local text = joined(say(inst, "window delete"))
    assertTrue(text:find("No window is selected.", 1, true) ~= nil, text)
    assertTrue(text:find("No window named", 1, true) == nil, text)
    assertEqual(#inst.NS.Database.GetWindows(), 1, "and nothing was deleted")
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
