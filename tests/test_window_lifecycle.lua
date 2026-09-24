-- tests/test_window_lifecycle.lua — modules/Window_Lifecycle.lua: how a window
-- is born, re-pointed, stood down and put away, and the bus wiring that keeps it
-- listening in between.
--
-- The suite follows the module's seam (docs/testing.md): these cases lived in
-- tests/test_window.lua until the bus wiring and the lifecycle tail were peeled
-- out of modules/Window.lua for layout-§1, and they moved with them, names
-- unchanged. What they protect is the contract the refresh chain relies on: a
-- window hears exactly the twelve messages it answers, on a PRIVATE target, every
-- data message only marks it dirty, and Suspend / Destroy take the clock and the
-- bus away without touching what the player configured.
--
-- THE FIXTURE IS DUPLICATED, DELIBERATELY, as it is in tests/test_window.lua,
-- tests/test_window_header.lua and tests/test_window_placement.lua. Copies stay
-- copies: if one drifts, the case that depended on the drift is the one that goes
-- red.


local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse
local assertNil   = T.assertNil


local CURRENT = 1

local ALPHA = "Player-1-0000000A"
local BETA  = "Player-1-0000000B"

local GROUP = {
    { guid = ALPHA, name = "Alpha", class = "PALADIN", role = "TANK"    },
    { guid = BETA,  name = "Beta",  class = "PRIEST",  role = "HEALER"  },
}

local function src(guid, total, opts)
    opts = opts or {}
    return {
        sourceGUID      = guid,
        name            = opts.name or guid,
        classFilename   = opts.class or "MAGE",
        totalAmount     = total,
        amountPerSecond = opts.rate or 1,
    }
end

--- A loaded instance, a group, a session, and ONE live window instance whose
--- config has been made unconditionally visible and locked.
---
--- Locked matters: an unlocked window implies preview mode (a player
--- positioning a window at a target dummy needs a full grid), and preview data
--- never touches the provider — which would make every case below vacuous.
local function scene(opts)
    opts = opts or {}
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks

    mocks.setGroup(GROUP)
    NS.Roster.Refresh()
    mocks.setSession(CURRENT, "*", {
        combatSources = opts.sources or { src(ALPHA, 100), src(BETA, 50) },
        maxAmount     = 100,
        totalAmount   = 150,
    })
    mocks.setSessionDuration(CURRENT, 212)
    if opts.restricted then mocks.setRestricted(true) end

    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked  = true
    cfg.visibility    = { dungeon = true, raid = true, arena = true,
                          battleground = true, world = true,
                          hideWhenSolo = false, hideInVehicle = false }
    cfg.data.sortMode = opts.sortMode or "provider"
    -- The shipped default is Overall; these fixtures seed the CURRENT session,
    -- so the window is pointed at it explicitly rather than every case having to
    -- seed two sessions to assert one thing.
    cfg.data.sessionType = CURRENT
    if opts.configure then opts.configure(cfg) end

    local window = NS.Window.New(cfg)
    window:RefreshVisibility()
    return inst, window, cfg
end

-- ---------------------------------------------------------------------------
-- Suspend and teardown
-- ---------------------------------------------------------------------------

test("Suspend takes the OnUpdate away and Resume puts it back", function()
    local _, window = scene()

    window:Suspend()
    assertNil(window.frame:GetScript("OnUpdate"),
        "a pass already queued must not fire once more inside a measurement window")

    window:Resume()
    assertTrue(window.frame:GetScript("OnUpdate") ~= nil)
end)

test("Destroy takes the window off screen and off the bus", function()
    local inst, window = scene()
    window:Refresh()
    window:Destroy()

    assertEqual(window:IsShown(), false)
    assertEqual(#window.pool.active, 0)
    assertNil(window.frame:GetScript("OnUpdate"))

    local MSG = inst.NS.Constants.MSG
    assertNil((inst.mocks.__msgRegistry[MSG.METER_UPDATED] or {})[window.bus])
end)

test("Each window owns a PRIVATE bus target, so two windows cannot clobber each other", function()
    local inst, first, cfg = scene()
    local second = inst.NS.Window.New(cfg)

    assertFalse(first.bus == second.bus,
        "CallbackHandler keys callbacks by (message, target); a shared target loses all but one")

    first.dirty, second.dirty = false, false
    inst.NS:SendMessage(inst.NS.Constants.MSG.METER_UPDATED)
    assertEqual(first.dirty, true)
    assertEqual(second.dirty, true, "both windows heard it")
end)

--- The messages WindowProto:RegisterBus subscribes, and nothing else.
local BUS_MESSAGES = {
    "METER_UPDATED", "METER_SESSION", "METER_RESET", "RESTRICTION_CHANGED",
    "ROSTER_CHANGED", "ZONE_CHANGED", "ENTERING_WORLD", "PLAYER_STATE_CHANGED",
    "COMBAT_CHANGED", "TEST_MODE_CHANGED", "DRILLDOWN_CHANGED", "CONFIG_CHANGED",
}

--- Every message the window's private target is registered for, as a set.
local function busSubscriptions(inst, window)
    local out, n = {}, 0
    for message, targets in pairs(inst.mocks.__msgRegistry) do
        if targets[window.bus] ~= nil then out[message], n = true, n + 1 end
    end
    return out, n
end

test("RegisterBus subscribes exactly the twelve messages a window answers", function()
    -- red under: dropping, or adding, any RegisterMessage in WindowProto:RegisterBus.
    local inst, window = scene()
    local MSG = inst.NS.Constants.MSG
    local seen, n = busSubscriptions(inst, window)
    for _, key in ipairs(BUS_MESSAGES) do
        assertTrue(seen[MSG[key]] ~= nil, "the window must listen on " .. key)
    end
    assertEqual(n, #BUS_MESSAGES, "a subscription nobody wrote down")
end)

test("Every data message marks the window dirty", function()
    -- red under: any data handler in RegisterBus that forgets MarkDirty.
    local inst, window = scene()
    local MSG = inst.NS.Constants.MSG
    for _, key in ipairs{ "METER_UPDATED", "METER_SESSION", "METER_RESET",
                          "RESTRICTION_CHANGED", "ROSTER_CHANGED", "TEST_MODE_CHANGED" } do
        window.dirty = false
        inst.NS:SendMessage(MSG[key])
        assertEqual(window.dirty, true, key .. " did not mark the window dirty")
    end
end)

test("CONFIG_CHANGED for ANOTHER window leaves this one alone", function()
    -- red under: dropping the windowId filter from the CONFIG_CHANGED handler.
    local inst, window = scene()
    local MSG = inst.NS.Constants.MSG
    window.dirty = false
    inst.NS:SendMessage(MSG.CONFIG_CHANGED, { windowId = window.id + 1000 })
    assertEqual(window.dirty, false, "a twenty-window profile would re-apply nineteen for nothing")
    inst.NS:SendMessage(MSG.CONFIG_CHANGED, { windowId = window.id })
    assertEqual(window.dirty, true)
end)

test("Destroy takes the window off EVERY message, not just the meter", function()
    -- red under: an UnregisterBus that drops one message rather than all of them.
    local inst, window = scene()
    window:Destroy()
    local _, n = busSubscriptions(inst, window)
    assertEqual(n, 0, "a destroyed window still hears the bus")
end)

test("SetConfig re-points the window at a new config without rebuilding it", function()
    -- red under: a SetConfig that keeps the old id, or that forgets MarkDirty.
    local _, window, cfg = scene()
    local frame, bus = window.frame, window.bus
    local copy = {}
    for k, v in pairs(cfg) do copy[k] = v end
    copy.id = cfg.id + 7
    window.dirty = false

    window:SetConfig(copy)

    assertEqual(window.config, copy)
    assertEqual(window.id, cfg.id + 7)
    assertEqual(window.dirty, true)
    assertTrue(window.frame == frame and window.bus == bus, "a settings change must not rebuild")
end)
