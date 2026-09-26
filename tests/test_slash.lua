-- tests/test_slash.lua
--
-- settings/Slash.lua's half of the CLI. The dispatcher, the help renderer, the
-- row formatter and the value parser are LibKa0s-Slash-1.0's and are tested in
-- that repo (testing-§8); what is ours is the verb table, the five host verbs,
-- the adapters that point the library's schema seams at NS.SetByPath, and the
-- registration.
--
-- Two siblings carry the rest: tests/test_slash_diagnostics.lua has the
-- diagnostics verbs (`perf` and the `/mm debug` ladder), and
-- tests/test_slash_refusal.lua has the refusals, including the disabled state's.
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
