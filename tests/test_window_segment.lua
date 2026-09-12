-- tests/test_window_segment.lua — `window.data.sessionID`, the pinned segment,
-- as a schema row.
--
-- A new file rather than more of tests/test_window_header.lua, which sits at the
-- 1500-line cap's edge (layout-§1). The segment MENU's own cases stay there; this
-- file holds what the row changed.
--
-- WHAT THE ROW IS. The header's segment menu chooses the pin, so under
-- architecture-§5 it is a preference, and a preference goes through the helper.
-- Its unpinned state used to be `nil`, which no row default can state, so it is
-- now Constants.NO_SEGMENT (0): the row's default, the value the validator
-- accepts beside a real session id, and what Database.PinnedSegment -- the one
-- reader every consumer asks -- answers as "no pin". The client's session ids
-- are positive, so 0 names none of them.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse
local assertNil   = T.assertNil

local CURRENT = 1
local PATH    = "window.data.sessionID"

local ALPHA = "Player-1-0000000A"
local BETA  = "Player-1-0000000B"

local GROUP = {
    { guid = ALPHA, name = "Alpha", class = "PALADIN", role = "TANK"   },
    { guid = BETA,  name = "Beta",  class = "PRIEST",  role = "HEALER" },
}

local function src(guid, total)
    return { sourceGUID = guid, name = guid, classFilename = "MAGE",
             totalAmount = total, amountPerSecond = 1 }
end

--- A window pointed at the Current session of a client holding two stored
--- segments, 4 and 5, with a second window beside it and the settings panel's
--- picker on that second one -- so a write that follows the picker instead of
--- the window is caught.
local function scene()
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks

    mocks.setGroup(GROUP)
    NS.Roster.Refresh()
    mocks.setSession(CURRENT, "*", {
        combatSources = { src(ALPHA, 100), src(BETA, 50) },
        maxAmount = 100, totalAmount = 150,
    })
    mocks.setSessionDuration(CURRENT, 212)
    mocks.setAvailableSessions{
        { sessionID = 4, name = "Bribed Guard", durationSeconds = 22 },
        { sessionID = 5, name = "Bribed Guard", durationSeconds = 17 },
    }

    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked = true
    cfg.visibility   = { dungeon = true, raid = true, arena = true, battleground = true,
                         world = true, hideWhenSolo = false, hideInVehicle = false }
    cfg.data.sortMode    = "provider"
    cfg.data.sessionType = CURRENT

    assertTrue(NS.WindowManager:Create("Second"))
    local other = NS.Database.GetWindows()[2]
    NS.State.SetActiveWindow(other.id)

    local window = NS.Window.New(cfg)
    window:RefreshVisibility()
    return inst, window, cfg, other
end

--- Every CONFIG_CHANGED from here on, payload by payload.
local function heardConfig(NS)
    local seen = {}
    NS.NewBusTarget():RegisterMessage(NS.Constants.MSG.CONFIG_CHANGED, function(_, payload)
        seen[#seen + 1] = payload or {}
    end)
    return seen
end

-- ---------------------------------------------------------------------------
-- The row
-- ---------------------------------------------------------------------------

test("Segment row: the pin is a hidden window row whose default is no pin", function()
    -- red under: a schema with no row for window.data.sessionID.
    local NS = T.NS
    local row = NS.FindSchemaRow(PATH)
    assertTrue(row ~= nil, "window.data.sessionID has no row")
    assertTrue(row.hidden, "the menu is the control; the panel draws no copy of it")
    assertEqual(row.default, NS.Constants.NO_SEGMENT)
    assertEqual(NS.Constants.NO_SEGMENT, 0)
end)

test("Segment row: it takes a session id or the sentinel, and nothing else", function()
    local inst, _, cfg = scene()
    local NS = inst.NS
    for _, bad in ipairs({ -1, 1.5, "4", true }) do
        assertFalse((NS.SetByPath(PATH, bad, cfg.id)), "accepted " .. tostring(bad))
    end
    assertTrue(NS.SetByPath(PATH, 7, cfg.id))
    assertEqual(cfg.data.sessionID, 7)
    assertTrue(NS.SetByPath(PATH, NS.Constants.NO_SEGMENT, cfg.id))
    assertEqual(cfg.data.sessionID, 0)
end)

test("Segment row: a stored window with no pin backfills to the sentinel", function()
    -- Load-pass backfill (savedvariables-§1): an account saved before the row
    -- existed has no key at all, and the shape pass fills it in.
    local NS = T.NS
    local w = { data = {} }
    NS.Database.EnsureWindowShape(w)
    assertEqual(w.data.sessionID, 0)
end)

-- ---------------------------------------------------------------------------
-- The menu's writes go through the seam
-- ---------------------------------------------------------------------------

test("Segment: picking a stored segment writes the pin through the seam for ITS window", function()
    -- red under: SetSegment assigning data.sessionID straight into the config.
    local inst, window, cfg, other = scene()
    local NS = inst.NS
    local seen = heardConfig(NS)

    window:OpenSegmentMenu()
    inst.mocks.__lastMenu:Nth("button", 2).callback()

    assertEqual(cfg.data.sessionID, 5)
    assertEqual(#seen, 1, "one change, announced once")
    assertEqual(seen[1].windowId, cfg.id, "addressed to the clicked window")
    assertEqual(other.data.sessionID, 0, "the picker's window is not the one clicked")
    assertEqual(NS.State.activeWindowId, other.id, "and the picker did not move")
end)

test("Segment: picking Current clears the pin and sets the type as ONE change", function()
    -- red under: a pin cleared around the seam, beside a separate type write.
    local inst, window, cfg = scene()
    local NS = inst.NS
    window:SetSegment(4)
    local seen = heardConfig(NS)

    window:SetSessionType(NS.Constants.SESSION_TYPE.Overall)
    assertEqual(#seen, 1)
    assertEqual(seen[1].windowId, cfg.id)
    assertEqual(cfg.data.sessionID, NS.Constants.NO_SEGMENT)
    assertEqual(cfg.data.sessionType, NS.Constants.SESSION_TYPE.Overall)
end)

test("Segment: a stale pin is cleared through the seam", function()
    -- A row wins (architecture-§5): the staleness check writes a field a row
    -- addresses, so it writes it through the helper like any other writer.
    local inst, window, cfg = scene()
    cfg.data.sessionID = 99
    local seen = heardConfig(inst.NS)

    window:DropStaleSegment()
    assertEqual(cfg.data.sessionID, 0)
    assertEqual(#seen, 1)
    assertEqual(seen[1].windowId, cfg.id)
end)

test("Segment: an unpinned window is left alone by the staleness check", function()
    -- The sentinel is not a session the client has lost. red under: a check
    -- that asks HasSession(0) and "clears" it on every refresh.
    local inst, window, cfg = scene()
    local seen = heardConfig(inst.NS)
    window:DropStaleSegment()
    assertEqual(cfg.data.sessionID, 0)
    assertEqual(#seen, 0, "nothing to clear, so nothing announced")
end)

-- ---------------------------------------------------------------------------
-- Every reader treats the sentinel as no pin
-- ---------------------------------------------------------------------------

test("Segment: the sentinel reads the session TYPE, never the ID shim", function()
    -- red under: an aggregator handing 0 to Provider.GetColumn, which routes any
    -- non-nil id to GetCombatSessionFromID and reads an empty session.
    local inst, window, cfg = scene()
    assertEqual(cfg.data.sessionID, 0)
    inst.mocks.resetMeterCalls()
    window:Refresh()
    assertNil(inst.mocks.__meter.calls.GetCombatSessionFromID, "0 was read as a session id")
    assertTrue((inst.mocks.__meter.calls.GetCombatSessionFromType or 0) > 0)
end)

test("Segment: the labels and the export read the sentinel as no pin", function()
    local inst, window, cfg = scene()
    local NS = inst.NS
    assertEqual(window:SessionLabel(false), NS.L["Current"])

    assertEqual(NS.Export.SessionLabel({ data = { sessionType = CURRENT, sessionID = 0 } }), "Current")
    assertNil(NS.Export.SessionConfig({ data = { sessionID = 0 } }).data.sessionID)

    cfg.data.sessionID = 4
    assertEqual(window:SessionLabel(false), "Bribed Guard   0:22", "and a real pin still names itself")
end)

test("Segment: Database.PinnedSegment answers nil for every spelling of no pin", function()
    local PinnedSegment = T.NS.Database.PinnedSegment
    assertNil(PinnedSegment(nil))
    assertNil(PinnedSegment({}))
    assertNil(PinnedSegment({ sessionID = 0 }))
    assertNil(PinnedSegment({ sessionID = false }))
    assertNil(PinnedSegment({ sessionID = -3 }))
    assertEqual(PinnedSegment({ sessionID = 5 }), 5)
end)
