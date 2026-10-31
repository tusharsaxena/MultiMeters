-- tests/test_skin_verb.lua — the reserved `skin` verb (LibKa0s v1.82.0, OptionsSkinPicker minor 3's
-- O.SkinVerb; MM-01 of Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-16):
-- a `skin` row right after `config` runs NS.RunSkinVerb, which hands O.SkinVerb the first-run spec,
-- so `/mm skin` shows the picker a new profile shows whatever skin.pickerSeen says. Refused while
-- the addon is disabled (the dispatcher's gate: `skin` is not a LIVE_VERB), a gray line on every
-- call in combat (the library's), and the library-absent line without LibKa0s. The reference is
-- LibKa0sSkinTester's tests/test_skin_verb.lua.
--
-- EACH CASE ON ITS OWN INSTANCE: the picker's window and its queue are library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function chatSince(inst, n)
    local out = {}
    for i = n + 1, #inst.mocks.__chat do out[#out + 1] = tostring(inst.mocks.__chat[i]) end
    return out
end

local function say(inst, msg)
    local n = #inst.mocks.__chat
    inst.NS.Slash:OnSlash(msg)
    return chatSince(inst, n)
end

local function anyLine(lines, fragment)
    for _, l in ipairs(lines) do if l:find(fragment, 1, true) then return true end end
    return false
end

local function strings(inst) return inst.mocks.LibStub("LibKa0s-Options-1.0").SKIN_PICKER_STRINGS end

--- Logged in, the first-run picker closed by the player, so only the verb can bring it back.
local function seenProfile()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.SetByPath("skin.pickerSeen", true)
    NS.HideSkinPicker()
    assertEqual(NS.MaybeShowSkinPicker(), nil, "the first-run picker is down")
    return inst, NS
end

--- Run `fn(calls)` with O.SkinVerb replaced by a recorder answering `...`.
local function spying(NS, fn, ...)
    local O = NS.Helpers
    local real, answer = O.SkinVerb, { ... }
    local calls = {}
    O.SkinVerb = function(spec)
        calls[#calls + 1] = spec
        return unpack(answer)
    end
    local ok, err = pcall(fn, calls)
    O.SkinVerb = real
    if not ok then error(err, 0) end
end

test("Skin verb: the row sits right after config, with the library's help words", function()
    local inst = T.load{}
    local at
    for i, c in ipairs(inst.NS.COMMANDS) do
        if c[1] == "skin" then at = i end
    end
    assertTrue(at ~= nil, "a skin row")
    assertEqual(inst.NS.COMMANDS[at - 1][1], "config", "after config")
    assertEqual(inst.NS.COMMANDS[at][2], strings(inst).VERB_HELP, "one wording for every host")
    assertEqual(type(inst.NS.COMMANDS[at][3]), "function")
end)

test("Skin verb: /mm skin shows the real picker on a profile that has closed it", function()
    -- red under: no skin row (the dispatcher answers "unknown command").
    local inst, NS = seenProfile()
    local O = NS.Helpers
    local real, shown = O.SkinVerb, nil
    O.SkinVerb = function(spec)
        local f, why = real(spec)
        shown = f
        return f, why
    end
    local ok, lines = pcall(say, inst, "skin")
    O.SkinVerb = real
    if not ok then error(lines, 0) end
    assertFalse(anyLine(lines, "unknown command"), "a known verb")
    assertTrue(shown ~= nil and shown:IsShown(), "the picker is up")
    NS.HideSkinPicker()
end)

test("Skin verb: NS.RunSkinVerb hands O.SkinVerb this addon's first-run spec", function()
    local _, NS = seenProfile()
    spying(NS, function(calls)
        local win, why = NS.RunSkinVerb()
        assertEqual(#calls, 1)
        assertEqual(calls[1].owner, "MultiMeters")
        assertTrue(rawequal(calls[1].set, NS.WriteSkinChoice), "the spec the first-run start builds")
        assertEqual(calls[1].tab, NS.SKIN_TAB)
        assertEqual(win, nil, "nothing shown")
        assertEqual(why, "queued", "the library's reason, passed on")
    end, nil, "queued")
end)

test("Skin verb: in combat every call prints the library's gray line and shows nothing", function()
    local inst, NS = seenProfile()
    inst.mocks.__restricted = true
    local first = say(inst, "skin")
    local second = say(inst, "skin")
    inst.mocks.__restricted = false
    assertTrue(anyLine(first, strings(inst).VERB_COMBAT), "the first call says why")
    assertTrue(anyLine(second, strings(inst).VERB_COMBAT), "and so does every later one")
    assertEqual(NS.GetSetting("skin.pickerSeen"), true, "nothing closed, nothing written")
end)

test("Skin verb: refused while the addon is disabled, and O.SkinVerb is never reached", function()
    local inst, NS = seenProfile()
    assertTrue(NS.SetByPath("enabled", false))
    spying(NS, function(calls)
        local lines = say(inst, "skin")
        assertEqual(#lines, 1, "one refusal line")
        assertTrue(lines[1]:find("is disabled", 1, true) ~= nil, "the disabled line")
        assertEqual(#calls, 0, "the verb's act never ran")
    end)
end)

test("Skin verb: without LibKa0s the verb prints the library-absent line", function()
    local inst = T.load{ libFiles = {} }
    local lines = say(inst, "skin")
    assertTrue(anyLine(lines, "/mm skin is unavailable"), "names the verb")
    assertFalse(anyLine(lines, "unknown command"), "a declared verb, degraded too")
end)
