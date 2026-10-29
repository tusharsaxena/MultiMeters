-- tests/test_skin_picker.lua — the first-run skin picker on this addon's seam (core/SkinSetup.lua;
-- LibKa0s OptionsSkinPicker 1, owner ruling O3, the rollout's DECISIONS X6).
--
-- What this addon owes the picker, and nothing the library pins itself: the spec it hands
-- O.SkinPicker (its owner, its two seams, the General page and the Skin tab's key, the eye, the
-- close); WHEN it shows (a profile whose `skin.pickerSeen` is false, once after login and after
-- every profile event, never while the addon stands down, held through combat on the one
-- PLAYER_REGEN_ENABLED edge core/MultiMeters.lua already owns); and that only the player's close
-- marks it seen. The trigger cases spy on O.SkinPicker; the window cases drive the library's real
-- picker.
--
-- EACH CASE ON ITS OWN INSTANCE: the picker's window and its queue are library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "MultiMeters"
local PATH = "skin.pickerSeen"

--- A fresh instance; `enable` runs the AceAddon cascade (the windows, the events).
local function scene(enable)
    local inst = T.load{ enable = enable or nil }
    return inst, inst.NS, inst.mocks
end

--- Run `fn(calls)` with O.SkinPicker replaced by a recorder: each call's spec, in order.
local function spying(NS, fn)
    local O = NS.Helpers
    local real = O.SkinPicker
    local calls = {}
    O.SkinPicker = function(spec)
        calls[#calls + 1] = spec
        return { spy = true }
    end
    local ok, err = pcall(fn, calls)
    O.SkinPicker = real
    if not ok then error(err, 0) end
end

--- Chat output swallowed (the stand-down and test mode each print a line).
local function quietly(mocks, fn)
    local cf = mocks.DEFAULT_CHAT_FRAME
    local add = cf.AddMessage
    cf.AddMessage = function() end
    local ok, err = pcall(fn)
    cf.AddMessage = add
    if not ok then error(err, 0) end
end

-- ── the spec ─────────────────────────────────────────────────────────────────────

test("Skin picker: the spec names this owner, its seams, the General page's Skin tab and the eye", function()
    -- red under: a set that is not the write seam (a pick would never reach the profile), or a page
    -- or tab key O.SelectTab does not know (the gear would open the panel on the wrong tab).
    local _, NS = scene()
    local spec = NS.SkinPickerSpec()
    assertEqual(spec.owner, OWNER)
    assertTrue(rawequal(spec.get, NS.SkinChoice), "get is the read seam")
    assertTrue(rawequal(spec.set, NS.WriteSkinChoice), "set is the write seam")
    assertEqual(spec.page, "general", "DECISIONS X6: the General page")
    assertEqual(spec.tab, NS.SKIN_TAB, "the Skin tab's key")
    assertEqual(type(spec.onPreview), "function", "the eye: the meter windows in test mode")
    assertEqual(type(spec.onClose), "function")
end)

-- ── when it shows ────────────────────────────────────────────────────────────────────────────

test("Skin picker: an unseen profile shows it; a seen one does not", function()
    local _, NS = scene()
    spying(NS, function(calls)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 1, "pickerSeen false: the picker shows")
        assertEqual(calls[1].owner, OWNER)
        NS.SetByPath(PATH, true)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 1, "pickerSeen true: it does not show again")
    end)
end)

test("Skin picker: a login or reload books it two seconds in; a zone-in books nothing", function()
    -- red under: dropping the booking from NS:OnEnteringWorld, booking it on every loading screen,
    -- or a C_Timer.After the stand-down's CancelAllTimers cannot reach.
    local _, NS, mocks = scene()
    spying(NS, function(calls)
        mocks.__timers = {}
        NS:OnEnteringWorld("PLAYER_ENTERING_WORLD", false, false)
        mocks.__fireTimers()
        assertEqual(#calls, 0, "a zone-in shows no picker")
        NS:OnEnteringWorld("PLAYER_ENTERING_WORLD", true, false)
        local booked
        for _, t in ipairs(mocks.__timers) do if t.delay == 2 then booked = t end end
        assertTrue(booked ~= nil, "the login booked no two-second timer")
        mocks.__fireTimers()
        assertEqual(#calls, 1, "the login timer shows the picker")
        NS:OnEnteringWorld("PLAYER_ENTERING_WORLD", false, true)
        mocks.__fireTimers()
        assertEqual(#calls, 2, "a reload is a new session: it shows again while unseen")
    end)
end)

test("Skin picker: in combat a start waits for PLAYER_REGEN_ENABLED, once", function()
    -- red under: showing in combat, or a held start the combat edge never resumes (the edge is
    -- core/MultiMeters.lua's own OnCombatChanged: no file but that one registers a game event).
    local _, NS, mocks = scene()
    spying(NS, function(calls)
        mocks.__restricted = true
        assertEqual(NS.MaybeShowSkinPicker(), nil)
        NS.MaybeShowSkinPicker()
        assertEqual(#calls, 0, "nothing shows in combat")
        mocks.__restricted = false
        NS:OnCombatChanged("PLAYER_REGEN_DISABLED")
        assertEqual(#calls, 0, "the start of combat resumes nothing")
        NS:OnCombatChanged("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 1, "the combat edge shows it, once for two held starts")
        NS:OnCombatChanged("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 1, "the hold is spent")
    end)
end)

test("Skin picker: a held start is dropped by HideSkinPicker", function()
    local _, NS, mocks = scene()
    spying(NS, function(calls)
        mocks.__restricted = true
        NS.MaybeShowSkinPicker()
        NS.HideSkinPicker()
        mocks.__restricted = false
        NS:OnCombatChanged("PLAYER_REGEN_ENABLED")
        assertEqual(#calls, 0, "a dropped start must not fire on the combat edge")
    end)
end)

test("Skin picker: never while the addon is switched off", function()
    local _, NS, mocks = scene(true)
    quietly(mocks, function()
        spying(NS, function(calls)
            assertTrue(NS.SetByPath("enabled", false))
            assertTrue(NS.IsStoodDown(), "the switch stood the addon down")
            NS.MaybeShowSkinPicker()
            assertEqual(#calls, 0, "a disabled addon shows no picker")
        end)
    end)
end)

test("Skin picker: a new profile and a reset profile show it again", function()
    -- Both start from the defaults, pickerSeen false (O3). red under: no call on the profile
    -- rebuild path, or one before the latch re-reads the new profile's switch.
    local _, NS, mocks = scene()
    local db = NS.db
    NS.SetByPath(PATH, true)
    quietly(mocks, function()
        spying(NS, function(calls)
            db:SetProfile("PickerProbe")
            assertEqual(#calls, 1, "a new profile shows the picker")
            NS.SetByPath(PATH, true)
            db:ResetProfile()
            assertEqual(#calls, 2, "a reset profile shows it again")
            NS.SetByPath(PATH, true)
            db:SetProfile("Default")
            assertEqual(#calls, 2, "back on a profile that has seen it: no picker")
        end)
    end)
end)

test("Skin picker: a profile event takes a shown picker down before the new skin is applied", function()
    -- A showing belongs to the profile it opened on; taking it down first puts back a pending
    -- preview, so the new profile's own skin is the last one written.
    -- red under: the HideSkinPicker call after NS.ApplySkinChoice in core/Database.lua's rebuild.
    local _, NS = scene()
    local order = {}
    local hide, apply = NS.HideSkinPicker, NS.ApplySkinChoice
    NS.HideSkinPicker = function(...) order[#order + 1] = "hide"; return hide(...) end
    NS.ApplySkinChoice = function(...) order[#order + 1] = "apply"; return apply(...) end
    local ok, err = pcall(function() NS.db:SetProfile("PickerOrder") end)
    NS.HideSkinPicker, NS.ApplySkinChoice = hide, apply
    if not ok then error(err, 0) end
    assertEqual(order[1], "hide", "the picker went down first")
    assertEqual(order[2], "apply")
end)

-- ── the real window ──────────────────────────────────────────────────────────────────────────

test("Skin picker: the player's close marks it seen; this addon's own hide does not", function()
    local _, NS, mocks = scene()
    quietly(mocks, function()
        local f = NS.MaybeShowSkinPicker()
        assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
        NS.HideSkinPicker()
        assertEqual(NS.GetSetting(PATH), false, "the addon's own hide is not the player's close")
        assertFalse(f:IsShown(), "HideSkinPicker took it down")
        f = NS.MaybeShowSkinPicker()
        assertTrue(f ~= nil and f:IsShown(), "it shows again while unseen")
        NS.Helpers.HideSkinPicker()
        assertEqual(NS.GetSetting(PATH), true, "the player's close sets pickerSeen")
        assertEqual(NS.MaybeShowSkinPicker(), nil, "and it does not show again")
    end)
end)

test("Skin picker: a profile that has seen it takes a shown picker down, unmarked", function()
    local _, NS, mocks = scene()
    quietly(mocks, function()
        local f = NS.MaybeShowSkinPicker()
        assertTrue(f ~= nil and f:IsShown())
        NS.db.profile.skin.pickerSeen = true
        NS.MaybeShowSkinPicker()
        assertFalse(f:IsShown(), "the picker stayed up on a profile that has seen it")
    end)
end)

test("Skin picker: the stand-down takes a shown picker down, unmarked", function()
    -- red under: no HideSkinPicker in core/LifecycleSetup.lua's standDown.
    local _, NS, mocks = scene(true)
    quietly(mocks, function()
        local f = NS.MaybeShowSkinPicker()
        assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
        assertTrue(NS.SetByPath("enabled", false))
        assertFalse(f:IsShown(), "the stand-down left the picker up")
        assertEqual(NS.GetSetting(PATH), false, "a stand-down is not the player's close")
    end)
end)

test("Skin picker: the eye puts the meter windows in test mode", function()
    -- red under: an eye that writes a stored setting, or one that shows nothing to preview on.
    local _, NS, mocks = scene(true)
    local M = NS.WindowManager
    quietly(mocks, function()
        assertFalse(M:IsTest(), "the scene starts out of test mode")
        NS.SkinPickerSpec().onPreview()
        assertTrue(M:IsTest(), "the eye did not start test mode")
        assertTrue(M:AnyShown(), "the eye showed no window")
        NS.SkinPickerSpec().onPreview()
        assertTrue(M:IsTest(), "a second press keeps test mode on")
        M:SetTestMode(false)
    end)
end)
