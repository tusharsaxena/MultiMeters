-- tests/test_slash_profile.lua
--
-- `/mm profile`: list the profiles, or switch to one by name. A sibling of tests/test_slash.lua.
--
-- WHAT IS OURS AND WHAT IS NOT. The verb's behavior is LibKa0s-Slash-1.0's (minor 17,
-- `CliProfile`), tested in that repo: the quote stripping, the list order, the did-you-mean, the
-- combat refusal, the rule that an unknown name is never created. What this addon owns is the
-- COMMANDS row, the `profiles` descriptor field pointing at NS.db, the verb staying live while the
-- addon is disabled, and the stub's answer with no library. So these cases drive the REAL
-- dispatcher against the REAL AceDB fake and assert on what reaches this addon: the store's
-- current profile, core/Database.lua's OnProfileChanged running, and the lines printed.
--
-- THE SWITCH IS REAL, NOT DISPATCHED BY HAND. core/Database.lua registers its profile callbacks in
-- CallbackHandler's method-name form, which the kit's AceDB fake cannot call (see the header of
-- tests/test_database.lua). tests/wow_mock.lua wraps that fake so SetProfile dispatches the
-- method-name form after the state change, the order CallbackHandler gives. So `/mm profile Raid`
-- here runs the whole path the client runs: CliProfile, SetProfile, OnProfileChanged, the rebuild
-- and the one `[Profile]` debug line. The handler is counted by wrapping it on the Database table,
-- which the dispatch looks up at call time.

local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue, assertFalse, assertNil =
    T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DESCRIPTION = "List profiles, or switch to one: profile <name>"

--- Every chat line one command produced.
local function say(inst, msg)
    local n = #inst.mocks.__chat
    inst.NS.Slash:OnSlash(msg)
    local out = {}
    for i = n + 1, #inst.mocks.__chat do out[#out + 1] = inst.mocks.__chat[i] end
    return out
end

local function joined(lines) return table.concat(lines, "\n") end

local function has(text, needle) return text:find(needle, 1, true) ~= nil end

--- The index of the first line carrying `needle`, or nil.
local function lineWith(lines, needle)
    for i, line in ipairs(lines) do
        if has(line, needle) then return i end
    end
    return nil
end

--- The library's own wording for one string, so a reworded line moves the case with it.
local function text(inst, key)
    return inst.mocks.LibStub("LibKa0s-Slash-1.0").STRINGS[key]
end

--- A loaded instance holding the profiles `names` besides Default, debug on, every debug line
--- captured and OnProfileChanged counted. Answers the instance, the lines, the call count (a
--- function, since it is read after the act) and a function that puts everything back.
local function scene(names)
    local inst = T.load()
    local NSi = inst.NS
    for _, name in ipairs(names or { "Raid" }) do NSi.db.sv.profiles[name] = {} end
    NSi.State.debug = true

    local lines, realDebug = {}, NSi.Debug
    NSi.Debug = function(tag, fmt, ...)
        local a = { ... }
        for i = 1, select("#", ...) do a[i] = tostring(a[i]) end
        lines[#lines + 1] = "[" .. tag .. "] " .. tostring(fmt):format(a[1], a[2], a[3], a[4])
    end

    local calls, realHandler = 0, NSi.Database.OnProfileChanged
    NSi.Database.OnProfileChanged = function(...)
        calls = calls + 1
        return realHandler(...)
    end

    return inst, lines, function() return calls end, function()
        NSi.Debug = realDebug
        NSi.Database.OnProfileChanged = realHandler
    end
end

--- The profiles the store holds, sorted, as one string a diff can be read from.
local function storeNames(NSi)
    local names = NSi.db:GetProfiles({})
    table.sort(names)
    return table.concat(names, ",")
end

-- ---------------------------------------------------------------------------
-- The row
-- ---------------------------------------------------------------------------

test("Slash profile: the verb follows the thirteen reserved ones, with its localized description",
function()
    -- A host verb (slash-commands.md:7, not reserved), so it goes AFTER `version`, next to the
    -- settings verbs rather than among the window verbs. Its description is a locale key, so the
    -- help index and the landing page both read one string a translation can reach.
    --
    -- enUS answers the key itself, so the row read off the shared instance cannot tell `L[...]`
    -- from the bare literal. The second half therefore gives a fresh instance a translation that
    -- differs from its key and re-runs settings/Slash.lua over it, the way a deDE.lua loaded after
    -- enUS would present: only a row that reads through L picks the translation up.
    -- red under: a row reading the literal instead of L, or one placed among the reserved thirteen.
    local NSi = T.NS
    local names = {}
    for i, entry in ipairs(NSi.COMMANDS) do names[entry[1]] = i end
    assertEqual(names.profile, names.version + 1, "`profile` should sit right after `version`")
    assertEqual(NSi.COMMANDS[names.profile][2], DESCRIPTION)
    assertEqual(rawget(NSi.L, DESCRIPTION), DESCRIPTION, "locales/enUS.lua carries no key for it")

    local inst = T.load{}
    local TRANSLATED = "Profile auflisten oder zu einem wechseln: profile <Name>"
    rawset(inst.NS.L, DESCRIPTION, TRANSLATED)
    T.Loader.load(T.root .. "/settings/Slash.lua", inst.NS, inst.mocks)
    local row
    for _, entry in ipairs(inst.NS.COMMANDS) do
        if entry[1] == "profile" then row = entry end
    end
    assertTrue(row ~= nil, "the reloaded table has no `profile` row")
    assertEqual(row[2], TRANSLATED, "the row reads the literal, not L")
end)

-- ---------------------------------------------------------------------------
-- Listing
-- ---------------------------------------------------------------------------

test("Slash profile: a bare `profile` lists every profile, sorted, the current one marked", function()
    -- red under: a row handing CliProfile nothing to read (no `profiles` descriptor field), which
    -- prints the unavailable line instead of the list.
    local inst, _, calls, restore = scene({ "raid", "Mythic" })
    local ok, err = pcall(function()
        local lines = say(inst, "profile")
        local shown = joined(lines)
        assertNil(lineWith(lines, text(inst, "PROFILE_UNAVAILABLE")), shown)
        local header = lineWith(lines, text(inst, "PROFILE_LIST_HEADER"))
        assertEqual(header, 1, "the header comes first: " .. shown)
        assertTrue(lines[1]:match(":%s*|?r?$") == nil, "the header carries no trailing colon: " .. lines[1])
        local d = lineWith(lines, "Default " .. text(inst, "PROFILE_CURRENT_MARK"))
        local m, r = lineWith(lines, "  Mythic"), lineWith(lines, "  raid")
        assertTrue(d and m and r, "every profile is listed, Default marked current: " .. shown)
        assertTrue(d < m and m < r, "sorted case-insensitively: " .. shown)
        assertTrue(has(lines[#lines], text(inst, "PROFILE_HINT"):format("/mm")),
            "the hint names this addon's slash: " .. shown)
        assertEqual(calls(), 0, "listing switched a profile")
        assertEqual(inst.NS.db:GetCurrentProfile(), "Default")
    end)
    restore()
    assertTrue(ok, tostring(err))
end)

-- ---------------------------------------------------------------------------
-- Switching
-- ---------------------------------------------------------------------------

test("Slash profile: `profile <name>` switches to that profile and the handler runs once", function()
    -- The whole client path: the store moves, core/Database.lua's OnProfileChanged runs (the
    -- rebuild every window and the settings panel follow), and the one switch line is the
    -- handler's own `[Profile]` line (debug-logging-§10). The chat acknowledgment is the library's.
    -- red under: a `profiles` field answering something other than NS.db, or a row calling
    -- SetProfile itself and skipping the library's existence check.
    local inst, debugLines, calls, restore = scene({ "Raid" })
    local NSi = inst.NS
    local ok, err = pcall(function()
        local lines = say(inst, "profile Raid")
        assertEqual(NSi.db:GetCurrentProfile(), "Raid")
        assertEqual(calls(), 1, "OnProfileChanged should run exactly once")
        assertTrue(has(joined(lines), text(inst, "PROFILE_SWITCHED"):format("Raid")), joined(lines))
        local switched = 0
        for _, line in ipairs(debugLines) do
            if line == "[Profile] switched to 'Raid'" then switched = switched + 1 end
        end
        assertEqual(switched, 1, "one switch line: " .. joined(debugLines))
        assertTrue(NSi.db.profile == NSi.db.sv.profiles.Raid, "db.profile is not the Raid profile")
        assertTrue(#NSi.Database.GetWindows() >= 1, "the rebuild left the new profile with no window")
    end)
    restore()
    assertTrue(ok, tostring(err))
end)

test("Slash profile: surrounding quotes are stripped; case and inner spaces are kept", function()
    -- A profile name is user data and AceDB's names are case-sensitive, so `"Raid Team"` switches
    -- to `Raid Team` and `raid team` does not. The dispatcher lowercases only the verb.
    -- red under: a row that lowercases or trims its argument before handing it on.
    local inst, _, calls, restore = scene({ "Raid Team" })
    local NSi = inst.NS
    local ok, err = pcall(function()
        say(inst, "profile raid team")
        assertEqual(NSi.db:GetCurrentProfile(), "Default", "a case-folded name switched")
        say(inst, 'profile "Raid Team"')
        assertEqual(NSi.db:GetCurrentProfile(), "Raid Team")
        say(inst, "profile 'Default'")
        assertEqual(NSi.db:GetCurrentProfile(), "Default")
        assertEqual(calls(), 2)
    end)
    restore()
    assertTrue(ok, tostring(err))
end)

test("Slash profile: an unknown name is refused with the list, and nothing is created", function()
    -- AceDB's SetProfile creates a missing profile, which is how a typo becomes a stray profile.
    -- red under: a row calling NS.db:SetProfile(rest) directly.
    local inst, _, calls, restore = scene({ "Raid" })
    local NSi = inst.NS
    local ok, err = pcall(function()
        local before = storeNames(NSi)
        local lines = say(inst, "profile Raidd")
        local shown = joined(lines)
        assertTrue(has(shown, text(inst, "PROFILE_UNKNOWN"):format("Raidd")), shown)
        assertTrue(lineWith(lines, text(inst, "PROFILE_LIST_HEADER")) ~= nil, "no list: " .. shown)
        assertEqual(storeNames(NSi), before, "a refused name was created")
        assertNil(NSi.db.sv.profiles.Raidd)

        -- One stored name matching case-insensitively is offered, and still not switched to.
        shown = joined(say(inst, "profile RAID"))
        assertTrue(has(shown, text(inst, "PROFILE_DID_YOU_MEAN"):format("Raid")), shown)
        assertEqual(NSi.db:GetCurrentProfile(), "Default")
        assertEqual(calls(), 0, "a refused name ran the profile handler")
    end)
    restore()
    assertTrue(ok, tostring(err))
end)

test("Slash profile: naming the current profile says so and rebuilds nothing", function()
    -- SetProfile on the current key still fires OnProfileChanged in AceDB, and every window would
    -- rebuild for nothing. red under: a row calling SetProfile without the library's check.
    local inst, _, calls, restore = scene()
    local ok, err = pcall(function()
        local shown = joined(say(inst, "profile Default"))
        assertTrue(has(shown, text(inst, "PROFILE_ALREADY"):format("Default")), shown)
        assertEqual(calls(), 0)
    end)
    restore()
    assertTrue(ok, tostring(err))
end)

test("Slash profile: in combat the switch is refused and nothing moves", function()
    -- The Profiles page cannot be used in combat, and a switch rebuilds every window and wipes the
    -- caches mid-pull. The list still answers.
    local inst, _, calls, restore = scene({ "Raid" })
    local NSi = inst.NS
    local realLockdown = inst.mocks.InCombatLockdown
    inst.mocks.InCombatLockdown = function() return true end
    local ok, err = pcall(function()
        local shown = joined(say(inst, "profile Raid"))
        assertTrue(has(shown, text(inst, "PROFILE_COMBAT")), shown)
        assertEqual(NSi.db:GetCurrentProfile(), "Default")
        assertEqual(calls(), 0)
        assertTrue(lineWith(say(inst, "profile"), text(inst, "PROFILE_LIST_HEADER")) ~= nil,
            "the list must still answer in combat")
    end)
    inst.mocks.InCombatLockdown = realLockdown
    restore()
    assertTrue(ok, tostring(err))
end)

test("Slash profile: with no database the verb says profiles are unavailable", function()
    -- core/Database.lua leaves NS.db nil when AceDB is missing. The descriptor asks for the store at
    -- call time, so the verb answers one line rather than raising on a nil db.
    local inst = T.load()
    local realDb = inst.NS.db
    inst.NS.db = nil
    local ok, lines = pcall(say, inst, "profile Raid")
    inst.NS.db = realDb
    assertTrue(ok, tostring(lines))
    assertEqual(#lines, 1, joined(lines))
    assertTrue(has(lines[1], text(inst, "PROFILE_UNAVAILABLE")), lines[1])
end)

-- ---------------------------------------------------------------------------
-- The disabled state
-- ---------------------------------------------------------------------------

test("Slash profile: the verb answers and switches while the addon is disabled", function()
    -- `enabled` is a stored setting and a profile switch can flip it, so the player standing the
    -- addon down in one profile must still be able to reach one where it is on. This host passes
    -- lib.LIVE_VERBS plus `profile`, and nothing else. red under: no `liveVerbs`, or one without
    -- `profile`.
    local inst, _, calls, restore = scene({ "Raid" })
    local NSi = inst.NS
    local ok, err = pcall(function()
        assertTrue(NSi.SetByPath("enabled", false))
        local refusal = inst.NS.Slash:DisabledLine()
        for _, command in ipairs({ "profile", "profile Raid" }) do
            for _, line in ipairs(say(inst, command)) do
                assertFalse(has(line, refusal), "`/mm " .. command .. "` was refused: " .. line)
            end
        end
        assertEqual(NSi.db:GetCurrentProfile(), "Raid")
        assertEqual(calls(), 1)
        -- The Raid profile never stored `enabled`, so it reads the shipped on and the addon is back.
        assertFalse(NSi.IsDisabled(), "switching to an enabled profile left the addon disabled")
    end)
    restore()
    assertTrue(ok, tostring(err))
end)

-- ---------------------------------------------------------------------------
-- LibKa0s absent
-- ---------------------------------------------------------------------------

--- An instance with no LibKa0s at all, the same load tests/test_degraded.lua drives.
local function degraded()
    local inst = T.load{ libFiles = {} }
    inst.NS.db.sv.profiles.Raid = {}
    return inst
end

test("Slash profile: with no library `/mm profile` names what is missing and switches nothing",
function()
    -- The stub's CliProfile takes the route every other schema-CLI verb on it takes: one line naming
    -- the verb and the shared cause clause. There is no library to ask whether the name exists, so
    -- nothing is switched and nothing is created.
    -- red under: a stub CliProfile that calls SetProfile, or one missing so the row raises.
    local inst = degraded()
    local NSi = inst.NS
    local before = storeNames(NSi)
    for _, command in ipairs({ "profile", "profile Raid", "profile Nope" }) do
        local ok, lines = pcall(say, inst, command)
        assertTrue(ok, "`/mm " .. command .. "` raised: " .. tostring(lines))
        assertEqual(#lines, 1, joined(lines))
        assertTrue(has(lines[1], "/mm profile"), lines[1])
        assertTrue(has(lines[1], NSi.LIBKA0S_MISSING), lines[1])
    end
    assertEqual(NSi.db:GetCurrentProfile(), "Default")
    assertEqual(storeNames(NSi), before)
end)

test("Slash profile: the stub's ProfileSwitch answers false with the same line", function()
    -- The live instance has both members from Slash minor 17, so the stub carries both
    -- (LibKa0s docs/api/Slash/version-17-docs.md, "The degradation stub"). Nothing in this addon
    -- reaches ProfileSwitch yet; the member is here so the stub keeps the live shape, and this case
    -- is what makes it more than a name. Reached through the `__dispatcher` debug seam.
    local inst = degraded()
    local stub = inst.NS.Slash.__dispatcher
    assertEqual(type(stub), "table", "settings/Slash.lua publishes no __dispatcher")
    local n = #inst.mocks.__chat
    local ok, answer = pcall(stub.ProfileSwitch, stub, "Raid")
    assertTrue(ok, tostring(answer))
    assertEqual(answer, false)
    assertEqual(#inst.mocks.__chat - n, 1)
    assertTrue(has(inst.mocks.__chat[#inst.mocks.__chat], "/mm profile"))
    assertEqual(inst.NS.db:GetCurrentProfile(), "Default")
end)
