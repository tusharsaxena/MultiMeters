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
    -- R6-PV: the preview contract (LibKa0s OptionsSkinPicker 11), test mode, and never the
    -- one-shot onPreview, which spec.preview would win over anyway.
    local pv = spec.preview
    assertEqual(type(pv), "table", "spec.preview: the eye's mode")
    assertEqual(pv.mode, "test", "00_PLAN.md call 2: MultiMeters previews in test mode")
    for _, k in ipairs({ "enter", "exit", "isActive", "isShown" }) do
        assertEqual(type(pv[k]), "function", "spec.preview." .. k)
    end
    assertEqual(spec.onPreview, nil, "the one-shot eye is gone")
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

-- ── the preview (R6-PV; LibKa0s OptionsSkinPicker 11, spec.preview) ───────────────────────────
--
-- The owner's rule (Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND6): the picker shown with no
-- meter window on screen puts the windows in test mode; the eye toggles it; every close puts back
-- the state the picker opened on. Each enter and exit goes through M:SetTestMode, the switch
-- `/mm test`, the General page's box and the launcher share, so its refusals hold and the box follows.

--- An enabled scene with every meter window hidden by General visibility "Only in combat", out of
--- combat and out of test mode. (A window `/mm toggle` hid comes back at the next ladder re-run,
--- the picker's own seen write included, so a rule is the hidden state a close can be held to.)
local function hiddenScene()
    local _, NS, mocks = scene(true)
    local M = NS.WindowManager
    mocks.setInCombat(false)
    assertTrue(NS.SetByPath("master.visibility", "inCombat"), "the visibility write")
    for _, inst in ipairs(M.All()) do inst:RefreshVisibility() end
    assertFalse(M:AnyShown(), "the scene hides every window")
    assertFalse(M:IsTest(), "the scene starts out of test mode")
    return NS, mocks, M
end

--- The library's real picker for this addon's own spec.
local function openPicker(NS)
    local f = NS.Helpers.SkinPicker(NS.SkinPickerSpec())
    assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
    return f
end

test("Skin picker preview: shown with every window hidden, it enters test mode", function()
    -- red under: the one-shot onPreview (nothing runs at show), or an enter that skips the seam.
    local NS, mocks, M = hiddenScene()
    quietly(mocks, function()
        openPicker(NS)
        assertTrue(M:IsTest(), "the picker did not enter test mode")
        assertTrue(M:AnyShown(), "test mode put no window on screen")
        assertEqual(NS.GetSetting("state.testMode"), true, "the General page's box reads the same switch")
        NS.Helpers.HideSkinPicker()
    end)
end)

test("Skin picker preview: the eye toggles test mode off and back on", function()
    -- red under: an enter-only eye (a second press kept test mode on).
    local NS, mocks, M = hiddenScene()
    quietly(mocks, function()
        local f = openPicker(NS)
        assertTrue(M:IsTest())
        f.preview:__fire("OnClick")
        assertFalse(M:IsTest(), "the eye did not turn test mode off")
        assertFalse(M:AnyShown(), "turning the preview off left a window the player had hidden")
        assertFalse(f.preview.lit, "the eye reads dimmed")
        f.preview:__fire("OnClick")
        assertTrue(M:IsTest(), "the eye did not turn test mode back on")
        assertTrue(f.preview.lit, "the eye reads lit")
        NS.Helpers.HideSkinPicker()
    end)
end)

--- Every close route the player has, each on a fresh scene, each by its own act on the window.
local CLOSES = {
    { "the close control", function(f) f.close:__fire("OnClick") end },
    { "Escape", function(f) f:Hide() end },
    { "Apply", function(f) f.apply:__fire("OnClick") end },
    { "Apply to all", function(f) f.applyAll:__fire("OnClick") end },
    { "the addon's own hide", function(_, NS) NS.HideSkinPicker() end },
}

test("Skin picker preview: every close puts the hidden windows back, out of test mode", function()
    -- red under: no restore (test mode stays on after the close). The manual turn-off's Show is
    -- pinned by the forced-show case below: the close's re-hide masks it here.
    for _, route in ipairs(CLOSES) do
        local NS, mocks, M = hiddenScene()
        quietly(mocks, function()
            local f = openPicker(NS)
            assertTrue(M:IsTest(), route[1] .. ": not entered")
            route[2](f, NS)
            assertFalse(f:IsShown(), route[1] .. ": the picker stayed up")
            assertFalse(M:IsTest(), route[1] .. ": test mode stayed on after the close")
            assertFalse(M:AnyShown(), route[1] .. ": a window stayed on screen after the close")
        end)
    end
end)

test("Skin picker preview: the close leaves no forced show, so a later ladder re-run keeps them hidden", function()
    -- The re-hide at the close covers what is on screen at that moment; a turn-off through the
    -- manual Show also marks every window forcedShow, which the next ladder re-run (a zone change,
    -- a settings write) obeys, putting the windows back over a rule that hides them.
    -- red under: previewExit's SetTestMode(false) without { keepShown = false }.
    for _, route in ipairs(CLOSES) do
        local NS, mocks, M = hiddenScene()
        quietly(mocks, function()
            local f = openPicker(NS)
            f.preview:__fire("OnClick")
            f.preview:__fire("OnClick")
            route[2](f, NS)
            for _, inst in ipairs(M.All()) do inst:RefreshVisibility() end
            assertFalse(M:IsTest(), route[1] .. ": test mode stayed on")
            assertFalse(M:AnyShown(), route[1] .. ": a ladder re-run after the close showed a window")
        end)
    end
end)

test("Skin picker preview: shown in combat with nothing on screen, the refused enter leaves no residue", function()
    -- The picker's own enter at show is refused in combat (the window manager's line); the
    -- recorded state stays "off", so the close enters nothing. (The close's pickerSeen write still
    -- re-runs the ladder, which brings back a window `/mm toggle` hid, as any settings write does.)
    local _, NS, mocks = scene(true)
    local M = NS.WindowManager
    quietly(mocks, function()
        NS.SetByPath(PATH, true)
        if M:AnyShown() then assertTrue(M:Toggle()) end
        assertFalse(M:AnyShown(), "the scene hides every window by hand")
        mocks.setInCombat(true)
        local f = openPicker(NS)
        assertFalse(M:IsTest(), "the picker started test mode in combat")
        f.close:__fire("OnClick")
        assertFalse(M:IsTest(), "the close entered test mode")
        mocks.setInCombat(false)
    end)
end)

test("Skin picker preview: windows the player closed with /mm toggle are closed again after it", function()
    -- red under: a turn-off through the manual Show, or no re-hide after the seen write, whose
    -- ladder re-run shows a window `/mm toggle` hid.
    local _, NS, mocks = scene(true)
    local M = NS.WindowManager
    quietly(mocks, function()
        NS.SetByPath(PATH, true)                -- seen, so its own write is not the first one here
        if M:AnyShown() then assertTrue(M:Toggle()) end
        assertFalse(M:AnyShown(), "the scene hides every window by hand")
        local f = openPicker(NS)
        assertTrue(M:IsTest(), "not entered")
        f.preview:__fire("OnClick")
        assertFalse(M:AnyShown(), "the eye's exit left a window the player had closed")
        f.preview:__fire("OnClick")
        f.close:__fire("OnClick")
        assertFalse(M:IsTest())
        assertFalse(M:AnyShown(), "the close left a window the player had closed on screen")
    end)
end)

test("Skin picker preview: the eye turned off and the close leaves it off", function()
    local NS, mocks, M = hiddenScene()
    quietly(mocks, function()
        local f = openPicker(NS)
        f.preview:__fire("OnClick")
        f.close:__fire("OnClick")
        assertFalse(M:IsTest(), "a close turned back on what the eye had turned off")
        assertFalse(M:AnyShown())
    end)
end)

test("Skin picker preview: a window already on screen is left alone, the eye undone at the close", function()
    -- red under: an enter at show whatever the surface (the windows were already showing).
    local _, NS, mocks = scene(true)
    local M = NS.WindowManager
    if not M:AnyShown() then assertTrue(M:Toggle()) end
    assertTrue(M:AnyShown(), "the scene shows its windows")
    quietly(mocks, function()
        local f = openPicker(NS)
        assertFalse(M:IsTest(), "the picker entered test mode over windows already shown")
        f.preview:__fire("OnClick")
        assertTrue(M:IsTest(), "the eye did not enter test mode")
        f.close:__fire("OnClick")
        assertFalse(M:IsTest(), "the close left the eye's test mode on")
        assertTrue(M:AnyShown(), "the close hid a window that was on screen when the picker opened")
    end)
end)

test("Skin picker preview: test mode the player had on stays on, and the eye's exit is undone", function()
    local NS, mocks, M = hiddenScene()
    quietly(mocks, function()
        assertTrue(M:SetTestMode(true), "/mm test's own switch")
        local f = openPicker(NS)
        assertTrue(M:IsTest())
        f.preview:__fire("OnClick")
        assertFalse(M:IsTest(), "the eye did not turn the player's test mode off")
        f.close:__fire("OnClick")
        assertTrue(M:IsTest(), "the close did not put the player's test mode back")
        M:SetTestMode(false)
    end)
end)

test("Skin picker preview: in combat the eye's start is refused and the close undoes nothing", function()
    -- the window manager's own refusal, the one `/mm test` and the box print, holds for the eye.
    local _, NS, mocks = scene(true)
    local M = NS.WindowManager
    if not M:AnyShown() then assertTrue(M:Toggle()) end
    quietly(mocks, function()
        local f = openPicker(NS)
        mocks.setInCombat(true)
        f.preview:__fire("OnClick")
        assertFalse(M:IsTest(), "the eye started test mode in combat")
        f.close:__fire("OnClick")
        mocks.setInCombat(false)
        assertFalse(M:IsTest(), "the close entered test mode")
        assertTrue(M:AnyShown(), "the close hid the windows")
    end)
end)
