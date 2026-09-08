-- tests/test_window_placement.lua — modules/Window_Placement.lua: where a
-- window sits, how big it is, whether it moves, and whether it is on screen.
--
-- Peeled out of tests/test_window.lua alongside the module it mirrors. Two
-- separate things live here and they meet at the lock.
--
-- GEOMETRY, and rule R3. A StatusBar handed a secret meter value is marked
-- HasSecretValues and its POSITION data goes secret with it, so drag and resize
-- act on a bare ANCHOR frame that never holds a value; the visible frame is
-- anchored to it and every other coordinate comes from config. The save cases
-- below prove that the hard way — they POISON `GetPoint`, `GetWidth` and
-- `GetHeight` on the value-carrying frame and then drive a save through them, so
-- a read that crept back in is a stack trace rather than something a reviewer
-- has to spot.
--
-- THE SHOW LADDER. Whether a window is drawn at all is a ladder, and the order
-- of its rungs is the whole point: a perf suspend sits above even the master
-- enable, an explicit `/mm show` outranks every CONTEXT rule but not the master
-- switch or a suspend, and a zone change is what makes an explicit show stale.
-- The edge cases underneath it — combat, vehicles, gliding — are about a state
-- that lags its own event, which is why a settle pass exists and why it is
-- scheduled ONCE however many edges land together.
--
-- THE FIXTURE IS DUPLICATED, DELIBERATELY. `scene()` and the group data under it
-- are copied from tests/test_window.lua rather than shared: ~50 lines are
-- cheaper to keep in three places than a fourth file every suite loads and
-- nobody proves anything about.


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

test("Closing HIDES the window; it never deletes it", function()
    -- `/mm toggle` and the X are the same action. A window you closed comes back
    -- with every setting and every column exactly as you left it; deleting one is
    -- a Windows-page action behind a confirmation.
    local inst, window = scene()
    local before = #inst.NS.Database.GetWindows()

    window:Hide("closed")
    assertEqual(window.frame:IsShown(), false)
    assertEqual(#inst.NS.Database.GetWindows(), before,
        "the configuration survives being closed")
end)

test("Dragging moves the ANCHOR, never the frame that holds the cells", function()
    local _, window, cfg = scene()
    cfg.frame.locked = false
    window:RefreshUpvalues()

    -- Dragging is the TITLE BAR's job. The body no longer takes the mouse at all,
    -- because taking it stole every hover from the cells underneath — and since a
    -- window ships unlocked, that meant tooltips did not work by default.
    window.dragBar:_run("OnDragStart")
    assertEqual(window.anchor.__moves, 1)
    assertNil(window.frame.__moves, "the value-carrying frame is never moved directly")

    window.dragBar:_run("OnDragStop")
    assertEqual(window.anchor.__stops, 1)
end)

test("A locked window refuses the drag entirely", function()
    local _, window, cfg = scene()
    cfg.frame.locked = true
    window:RefreshUpvalues()

    window.dragBar:_run("OnDragStart")
    assertNil(window.anchor.__moves, "a locked window does not move")
end)

test("SavePosition reads GetPoint off the anchor and off nothing else", function()
    local inst, window, cfg = scene()

    -- Poison the visible frame's getter. Reading position back off a frame whose
    -- cells have held a secret is exactly rule R3's prohibition; it would work
    -- today and become a Lua error the first time a cell received a value.
    window.frame.GetPoint = function()
        error("rule R3: GetPoint was read off the value-carrying frame", 2)
    end

    window.anchor:ClearAllPoints()
    window.anchor:SetPoint("TOPLEFT", inst.mocks.UIParent, "TOPLEFT", 120, -80)
    window:SavePosition()

    assertEqual(cfg.frame.position.point, "TOPLEFT")
    assertEqual(cfg.frame.position.x, 120)
    assertEqual(cfg.frame.position.y, -80)
end)

test("SaveSize uses the size OnSizeChanged was handed, never a getter", function()
    local _, window, cfg = scene()

    window.frame.GetWidth = function() error("rule R3: GetWidth off the frame", 2) end
    window.frame.GetHeight = function() error("rule R3: GetHeight off the frame", 2) end

    -- The handler ARGUMENTS are the new size. Taking them there keeps the resize
    -- path from ever asking a frame a question.
    window.anchor:_run("OnSizeChanged", 640.4, 300.6)
    window:SaveSize()

    assertEqual(cfg.frame.width, 640)
    assertEqual(cfg.frame.height, 301)
end)

test("The window refuses to be dragged smaller than the grid needs", function()
    -- Enforced by the CLIENT through SetResizeBounds rather than by clamping in
    -- Lua on every tick, so there is no frame in which the window is drawn at an
    -- illegal size.
    -- red under: never calling SetResizeBounds.
    local inst, window, cfg = scene()
    local Const = inst.NS.Constants
    window:ApplyConfig()

    local minW, minH = window.anchor:GetResizeBounds()
    assertEqual(minW, window.layout.minWidth)
    assertEqual(minH, window.layout.minHeight)

    -- The height floor is the title bar, the column-header strip and ONE row: a
    -- window with room for no rows shows nothing, which is not a size anybody
    -- means to drag to.
    local pad = cfg.frame.padding or 6
    assertEqual(minH, pad * 2 + window.layout.titleHeight
        + window.layout.headerHeight + (cfg.rows.height or 16))
    assertTrue(minW >= Const.NAME_COLUMN_WIDTH + #window.layout.columns * Const.COLUMN_MIN_WIDTH)
end)

-- ---------------------------------------------------------------------------
-- The show ladder
-- ---------------------------------------------------------------------------

test("ShouldShow STEP 0 is NS.Perf.suspended, above even the master enable", function()
    local inst = T.load()
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    cfg.visibility.world = true
    cfg.visibility.hideWhenSolo = false

    assertEqual(select(2, NS.ShouldShow(cfg)), "shown")

    -- Nothing may re-show a window behind suspend's back — not preview, not the
    -- master enable, not a context change (performance-§6).
    NS.State.SetTestMode(true)
    NS.Perf.suspended = true
    local show, reason = NS.ShouldShow(cfg)
    NS.Perf.suspended = false
    NS.State.SetTestMode(false)

    assertEqual(show, false)
    assertEqual(reason, "suspended")
end)

test("ShouldShow's ladder reads master enable, then test mode, then context", function()
    local inst = T.load()
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]

    NS.db.profile.enabled = false
    assertEqual(select(2, NS.ShouldShow(cfg)), "disabled")
    NS.db.profile.enabled = true

    -- The open world ships ON now, so the fixture has to switch it off itself to
    -- get a context that refuses — which is the step this case is measuring.
    cfg.visibility.world = false
    -- ...refused by context...
    assertEqual(NS.ShouldShow(cfg), false)
    -- ...until test mode, which shows regardless: the whole point is to lay a
    -- layout out wherever the player happens to be standing.
    --
    -- ONE-WAY. Test mode can force a window ON and never forces one off, which is
    -- what stops `/mm test` from reading as a close button with a confusing name.
    NS.State.SetTestMode(true)
    local show, reason = NS.ShouldShow(cfg)
    NS.State.SetTestMode(false)
    assertEqual(show, true)
    assertEqual(reason, "test")

    assertEqual(select(2, NS.ShouldShow(nil)), "no window")
end)

test("RefreshVisibility shows, hides, and marks dirty exactly once on the way in", function()
    local inst, window, cfg = scene()
    assertEqual(window:IsShown(), true)

    cfg.visibility.world = false
    inst.mocks.setInstance(nil)
    local show, reason = window:RefreshVisibility()
    assertEqual(show, false)
    assertEqual(reason, "world")
    assertEqual(window:IsShown(), false)
    assertEqual(#window.pool.active, 0, "hiding releases the rows")

    cfg.visibility.world = true
    window.dirty = false
    assertEqual(window:RefreshVisibility(), true)
    assertEqual(window.dirty, true)
    assertEqual(window.elapsed, window.throttle, "it draws on the next tick, not in 0.25s")
end)

test("An explicit Show draws on the next tick too, not a throttle later", function()
    -- The `/mm toggle` half of the same fact. Show puts the frame on screen
    -- itself rather than going through RefreshVisibility, so it did not inherit
    -- that file's clock nudge: the chrome appeared instantly and the rows landed
    -- up to a full `data.throttle` later, which reads as the window assembling
    -- itself in two stages.
    -- red under: WindowProto:Show leaving `elapsed` where the hide left it.
    local _, window = scene()
    window:Hide("toggled")
    window.dirty, window.elapsed = false, 0

    window:Show()
    assertTrue(window.dirty, "the request marks it dirty")
    assertEqual(window.elapsed, window.throttle,
        "and hands the clock a full tick, so the first draw is the next frame")
end)

test("Leaving test mode does not close the window", function()
    -- Test mode forces a window visible. Without a matching Show on the way out,
    -- turning it off just stopped forcing and the ordinary visibility rules hid a
    -- window the player was looking at — so `/mm test` read as a close button
    -- with a confusing name.
    -- red under: dropping the Show loop from settings/Slash.lua's doTest.
    local inst = T.load()
    local cfg = inst.NS.Database.GetWindows()[1]
    cfg.visibility = { dungeon = false, raid = false, arena = false,
                       battleground = false, world = false,
                       hideWhenSolo = false, hideInVehicle = false }
    inst.NS.WindowManager:Init()

    inst.NS.Slash:OnSlash("test on")
    assertTrue(inst.NS.WindowManager.All()[1]:IsShown(), "test mode forces it visible")

    inst.NS.Slash:OnSlash("test off")
    assertTrue(inst.NS.WindowManager.All()[1]:IsShown(),
        "and leaving test mode is not the same keystroke as closing it")
end)

test("A player-state edge re-runs the show ladder on the window itself", function()
    -- THE BUG THE FIRST CUT OF THE PLAYER-STATE RULES SHIPPED WITH. The rules
    -- lived in modules/Visibility.lua and were correct; the window never asked
    -- them again. modules/Visibility.lua is a PREDICATE and publishes nothing by
    -- design, and WindowProto:RefreshVisibility only runs off a bus message — so
    -- a rule with no message the WINDOW listens to takes effect on the next zone
    -- change, group change or settings write, and never on its own edge. Ticking
    -- "hide when skyriding" appeared to work only because the tick itself fires
    -- CONFIG_CHANGED; mounting up afterwards did nothing.
    -- red under: dropping PLAYER_STATE_CHANGED from WindowProto:RegisterBus.
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks
    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked = true
    cfg.visibility = { world = true, hideWhenSkyriding = true }

    local window = NS.Window.New(cfg)
    assertTrue(window:IsShown(), "the window starts visible in the open world")

    -- Nothing else moves: no zone change, no group change, no settings write.
    -- The player simply got on a skyriding mount.
    mocks.setCanGlide(true)
    NS:SendMessage(NS.Constants.MSG.PLAYER_STATE_CHANGED)
    assertFalse(window:IsShown(), "the window did not hear its own rule's edge")

    mocks.setCanGlide(false)
    NS:SendMessage(NS.Constants.MSG.PLAYER_STATE_CHANGED)
    assertTrue(window:IsShown(), "and it must come back on the other edge")
end)

test("A combat edge re-runs the show ladder on the window itself", function()
    -- Same defect, other message. A hidden window's OnUpdate does not fire, so
    -- without this subscription a window hidden in combat could never come back
    -- when the pull ended.
    -- red under: dropping COMBAT_CHANGED from WindowProto:RegisterBus.
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks
    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked = true
    cfg.visibility = { world = true, hideInCombat = true }

    local window = NS.Window.New(cfg)
    assertTrue(window:IsShown())

    mocks.setInCombat(true)
    NS:SendMessage(NS.Constants.MSG.COMBAT_CHANGED)
    assertFalse(window:IsShown())

    mocks.setInCombat(false)
    NS:SendMessage(NS.Constants.MSG.COMBAT_CHANGED)
    assertTrue(window:IsShown(), "a hidden window's OnUpdate never fires, so only the message can lift it")
end)

test("The show ladder is re-run ONLY from a message, never from the refresh tick", function()
    -- The property the two cases above rest on, stated once so it cannot rot
    -- unnoticed: onUpdate refreshes DATA. It does not re-ask NS.ShouldShow, so
    -- there is no per-tick fallback for a rule whose edge nothing announces —
    -- every visibility input needs a message the window subscribes to.
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks
    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked = true
    cfg.visibility = { world = true, hideWhenMounted = true }

    local window = NS.Window.New(cfg)
    assertTrue(window:IsShown())

    mocks.setMounted(true)
    for _ = 1, 20 do
        window:MarkDirty()
        window.frame:_run("OnUpdate", 0.5)
    end
    assertTrue(window:IsShown(),
        "if this ever goes red the tick has started re-running the ladder — " ..
        "rewrite the comments in modules/Window.lua and modules/Visibility.lua that say it does not")

    NS:SendMessage(NS.Constants.MSG.PLAYER_STATE_CHANGED)
    assertFalse(window:IsShown())
end)

test("Entering a vehicle hides the window on its own edge", function()
    -- hideInVehicle shipped in the first release and had NEVER fired on its own:
    -- no vehicle event reached core/MultiMeters.lua's fan-out, and the module
    -- header's claim that the answer would be right "at worst one refresh
    -- interval later" was wrong, because the tick does not re-ask the ladder.
    -- The rule only ever took effect if a zone change happened to follow.
    -- red under: dropping UNIT_ENTERED_VEHICLE from core/MultiMeters.lua.
    local inst = T.load{ enable = true }
    local NS, mocks = inst.NS, inst.mocks
    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked = true
    cfg.visibility = { world = true, hideInVehicle = true }

    -- The registration is asserted as well as the behaviour: calling the handler
    -- by hand proves the fan-out works and proves nothing about whether the game
    -- can ever reach it, which is exactly the gap this rule fell into.
    assertEqual(NS.__events["UNIT_ENTERED_VEHICLE"], "OnPlayerStateChanged")
    assertEqual(NS.__events["UNIT_EXITED_VEHICLE"], "OnPlayerStateChanged")

    local window = NS.Window.New(cfg)
    assertTrue(window:IsShown())

    mocks.setInVehicle(true)
    NS:OnPlayerStateChanged("UNIT_ENTERED_VEHICLE", "player")
    assertFalse(window:IsShown())

    mocks.setInVehicle(false)
    NS:OnPlayerStateChanged("UNIT_EXITED_VEHICLE", "player")
    assertTrue(window:IsShown())
end)

test("A vehicle event about somebody else is not republished", function()
    -- UNIT_ENTERED_VEHICLE fires for every unit, so in a raid it is one of the
    -- busier events the addon could listen to. The unit filter is the only
    -- decision in this handler and it is a FILTER, not a rule: nothing about
    -- another player's vehicle can change where this player's window belongs.
    -- red under: dropping the unit check from NS:OnPlayerStateChanged.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local seen = 0
    local bus = NS.NewBusTarget()
    bus:RegisterMessage(NS.Constants.MSG.PLAYER_STATE_CHANGED, function() seen = seen + 1 end)

    NS:OnPlayerStateChanged("UNIT_ENTERED_VEHICLE", "raid7")
    assertEqual(seen, 0, "a raider's vehicle woke every window in the raid")

    NS:OnPlayerStateChanged("UNIT_ENTERED_VEHICLE", "player")
    assertEqual(seen, 1)

    -- An event with no unit argument at all still passes: nil is not somebody
    -- else, it is "this event is not about a unit".
    NS:OnPlayerStateChanged("PLAYER_MOUNT_DISPLAY_CHANGED")
    assertEqual(seen, 2)
end)

test("A state that lags its own event is caught by the settle pass", function()
    -- THE SKYRIDING DISMOUNT. A ground mount works on the edge alone, because
    -- IsMounted() has already flipped by the time PLAYER_MOUNT_DISPLAY_CHANGED
    -- arrives. GetGlidingInfo's canGlide has not: at the dismount edge the client
    -- still reports the player as glide-capable, the ladder correctly re-hides,
    -- and then NOTHING asks again — a hidden window has no OnUpdate running, so
    -- it stayed hidden until the next zone change or settings write.
    -- red under: dropping the deferred pass from NS:OnPlayerStateChanged.
    local inst = T.load{ enable = true }
    local NS, mocks = inst.NS, inst.mocks
    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked = true
    cfg.visibility = { world = true, hideWhenSkyriding = true }

    local window = NS.Window.New(cfg)
    mocks.setCanGlide(true)
    NS:OnPlayerStateChanged("PLAYER_MOUNT_DISPLAY_CHANGED")
    assertFalse(window:IsShown(), "mounting up hides it")

    -- The dismount edge, read while the client still says canGlide. This is the
    -- read that used to be the last word.
    NS:OnPlayerStateChanged("PLAYER_MOUNT_DISPLAY_CHANGED")
    assertFalse(window:IsShown())

    -- The client settles a moment later, and the deferred pass asks again.
    mocks.setCanGlide(false)
    mocks.__fireTimers()
    assertTrue(window:IsShown(), "the window never came back after the state settled")
end)

test("The settle pass is scheduled once, however many edges land together", function()
    -- Mounting fires several of these at once — the mount display, the glide
    -- capability, sometimes a shapeshift. One deferred pass answers all of them,
    -- and scheduling one per event would put a burst of timers on the frame that
    -- fires them for no additional answer.
    -- red under: dropping the pending guard in NS:OnPlayerStateChanged.
    local inst = T.load{ enable = true }
    local NS, mocks = inst.NS, inst.mocks

    local before = #mocks.__timers
    NS:OnPlayerStateChanged("PLAYER_MOUNT_DISPLAY_CHANGED")
    NS:OnPlayerStateChanged("PLAYER_CAN_GLIDE_CHANGED")
    NS:OnPlayerStateChanged("UPDATE_SHAPESHIFT_FORM")
    assertEqual(#mocks.__timers - before, 1, "one settle pass, not one per event")

    -- And the guard reopens once it has run, or the second mount of the session
    -- would have no settle pass at all.
    mocks.__fireTimers()
    NS:OnPlayerStateChanged("PLAYER_MOUNT_DISPLAY_CHANGED")
    assertEqual(#mocks.__timers, 1, "the guard never reopened")
end)

test("A glide event's boolean payload is not mistaken for a unit token", function()
    -- THE BUG THAT MADE SKYRIDING LOOK SPECIAL. Both glide events carry a
    -- BOOLEAN as arg1 — oUF_Fader spells it out: "unit is true/false with the
    -- event being PLAYER_IS_GLIDING_CHANGED", and ElvUI reads
    -- PLAYER_CAN_GLIDE_CHANGED's arg as canGlide. A filter that tested arg1
    -- against "player" for EVERY event in the block therefore dropped every
    -- skyriding edge, while ground mounts kept working because
    -- PLAYER_MOUNT_DISPLAY_CHANGED carries no argument at all.
    -- red under: filtering on arg1 without keying on the event name.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local seen = 0
    local bus = NS.NewBusTarget()
    bus:RegisterMessage(NS.Constants.MSG.PLAYER_STATE_CHANGED, function() seen = seen + 1 end)

    NS:OnPlayerStateChanged("PLAYER_CAN_GLIDE_CHANGED", true)
    NS:OnPlayerStateChanged("PLAYER_CAN_GLIDE_CHANGED", false)
    NS:OnPlayerStateChanged("PLAYER_IS_GLIDING_CHANGED", true)
    NS:OnPlayerStateChanged("PLAYER_IS_GLIDING_CHANGED", false)
    assertEqual(seen, 4, "a skyriding edge was swallowed by the unit filter")
end)

test("A filtered-out unit event schedules nothing", function()
    -- The unit filter runs FIRST. A raid full of vehicle events must not each
    -- put a timer on the frame to answer a question about somebody else.
    -- red under: moving the ScheduleTimer above the unit check.
    local inst = T.load{ enable = true }
    local NS, mocks = inst.NS, inst.mocks

    local before = #mocks.__timers
    NS:OnPlayerStateChanged("UNIT_ENTERED_VEHICLE", "raid7")
    assertEqual(#mocks.__timers - before, 0)
end)

test("Changing a setting does not close a window the player asked for", function()
    -- The ladder is consulted on every CONFIG_CHANGED, and a window that is on
    -- screen because the player asked for it is not on screen because the ladder
    -- said so. So the first unrelated settings edit re-ran the ladder, got "no"
    -- from a context rule, and hid it — which reads as "the settings panel closes
    -- my meter", and is a wrong explanation as well as a baffling one.
    -- red under: RefreshVisibility ignoring forcedShow.
    local inst = T.load{ enable = true }
    local cfg = inst.NS.Database.GetWindows()[1]
    cfg.visibility = { dungeon = false, raid = false, arena = false,
                       battleground = false, world = false,
                       hideWhenSolo = false, hideInVehicle = false }

    local window = inst.NS.WindowManager.All()[1]
    window:Show()
    assertTrue(window:IsShown(), "an explicit request shows it")

    inst.NS:SendMessage(inst.NS.Constants.MSG.CONFIG_CHANGED, { windowId = window.id })
    assertTrue(window:IsShown(), "and an unrelated settings edit must not take it away")
end)

test("The master switch closes a window the player asked for", function()
    -- forcedShow used to override the WHOLE ladder, which made "Enable Multi
    -- Meters" do nothing: any window that had ever been shown carried the flag, so
    -- unticking the master switch re-ran the ladder, got "disabled", and was
    -- overruled by a flag that means "I asked for this window in this zone" -- a
    -- far narrower statement than the one the master switch makes.
    -- red under: `if not show and self.forcedShow then` with no UNFORCEABLE check.
    local inst = T.load{ enable = true }
    local NS = inst.NS

    local window = NS.WindowManager.All()[1]
    window:Show()
    assertTrue(window:IsShown(), "an explicit request shows it")

    assertTrue(NS.SetByPath("enabled", false))
    assertFalse(window:IsShown(), "the master switch is not a context rule")
end)

test("A perf suspend closes a window the player asked for", function()
    -- Step 0 of the ladder exists to say a suspended capture is INERT: nothing --
    -- a combat transition, a zone-in, a settings change -- may re-show a window
    -- behind suspend's back. forcedShow was doing exactly that.
    -- red under: forcedShow overriding a "suspended" answer.
    local inst = T.load{ enable = true }
    local NS = inst.NS

    local window = NS.WindowManager.All()[1]
    window:Show()
    assertTrue(window:IsShown())

    NS.Perf.suspended = true
    window:RefreshVisibility()
    assertFalse(window:IsShown(), "a suspended capture must be inert")
end)

test("A CONTEXT rule still cannot close a window the player asked for", function()
    -- The other half of the same fix, and the reason forcedShow exists at all: it
    -- must still outrank the context rules, or narrowing the override would have
    -- brought back the bug it was written for.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    cfg.visibility = { dungeon = false, raid = false, arena = false,
                       battleground = false, world = false,
                       hideWhenSolo = false, hideInVehicle = false }

    local window = NS.WindowManager.All()[1]
    window:Show()
    window:RefreshVisibility()
    assertTrue(window:IsShown(), "every context says no, and the request still wins")
end)

test("A zone change is what makes an explicit show stale", function()
    -- Deliberately not permanent: the visibility rules exist to follow you between
    -- a dungeon and a city, and a flag that outlived that would quietly disable
    -- the whole page.
    local inst = T.load{ enable = true }
    local cfg = inst.NS.Database.GetWindows()[1]
    cfg.visibility = { dungeon = false, raid = false, arena = false,
                       battleground = false, world = false,
                       hideWhenSolo = false, hideInVehicle = false }

    local window = inst.NS.WindowManager.All()[1]
    window:Show()
    inst.NS:SendMessage(inst.NS.Constants.MSG.ZONE_CHANGED)
    assertFalse(window:IsShown(), "the context rules get their say again")
end)

test("Closing cancels the request, so it does not reappear", function()
    -- The same bug pointed the other way.
    local inst = T.load{ enable = true }
    local window = inst.NS.WindowManager.All()[1]
    -- A context that refuses, so what is being measured is forcedShow being
    -- cleared rather than the ladder happening to say yes. With the shipped
    -- defaults every context says yes, and a closed window DOES come back on the
    -- next settings write — see the note on Hide in modules/Window.lua.
    window.config.visibility.world = false
    inst.mocks.setInstance(nil)
    window:Show()
    window:Hide("closed")

    inst.NS:SendMessage(inst.NS.Constants.MSG.CONFIG_CHANGED, { windowId = window.id })
    assertFalse(window:IsShown(), "a closed window stays closed")
end)

test("The resize grip is built unconditionally and follows the LOCK", function()
    -- There used to be a `resizeGrip` setting read inside BuildFrame, which runs
    -- ONCE per window -- so unticking it did nothing at all until a reload. The
    -- lock already answers this question, and now it is the only thing that does.
    -- red under: restoring the `if frameCfg.resizeGrip ~= false then` gate.
    local _, window, cfg = scene()
    assertTrue(window.grip ~= nil, "the grip was not built")

    cfg.frame.locked = false
    window:ApplyConfig()
    assertEqual(window.grip:IsShown(), true, "an unlocked window offers its grip")

    cfg.frame.locked = true
    window:ApplyConfig()
    assertEqual(window.grip:IsShown(), false, "locking is how you put the grip away")
end)

test("`resizeGrip` is gone from the code, not just from the panel", function()
    -- The BEHAVIOURAL guard above cannot catch this one coming back. A resurrected
    -- `if frameCfg.resizeGrip ~= false then` reads a key no profile has any more,
    -- so it is always true and every case still passes -- right up until someone
    -- re-adds the schema row and the old bug with it. So the guard is static.
    -- red under: any read of frameCfg.resizeGrip anywhere in these two files.
    local offenders = {}
    for _, path in ipairs{ "/modules/Window.lua", "/settings/Schema.lua",
                           "/defaults/Profile.lua" } do
        local fh = assert(io.open(T.root .. path, "r"))
        local n = 0
        for line in fh:lines() do
            n = n + 1
            local code = line:gsub("%s*%-%-.*$", "")
            if code:find("resizeGrip", 1, true) then
                offenders[#offenders + 1] = path .. ":" .. n
            end
        end
        fh:close()
    end
    assertEqual(#offenders, 0, table.concat(offenders, ", "))
end)

test("Unlocking does not resurrect the grip on a collapsed window", function()
    -- ApplyLock and ApplyMinimised are two authors of one property, so whichever
    -- runs last wins unless they ask the same question. `/mm lock off` was the
    -- path that put the grip back.
    -- red under: ApplyLock doing grip:SetShown(not locked).
    local _, window, cfg = scene()
    cfg.frame.minimised = true
    cfg.frame.locked = false
    window:ApplyConfig()
    window:ApplyLock()
    if window.grip then
        assertEqual(window.grip:IsShown(), false, "unlocking put the grip back")
    end
end)

test("Either lock pins the window, and the master lock erases neither", function()
    -- ORed rather than overriding: unticking the addon-wide lock must leave the
    -- windows a player locked one at a time locked, and an override would silently
    -- unlock all of them.
    -- red under: `self.locked = masterLocked` instead of `master or own`.
    local inst, window, cfg = scene()

    cfg.frame.locked = false
    inst.NS.db.profile.master.locked = false
    window:RefreshUpvalues()
    assertFalse(window.locked, "neither lock is on")

    inst.NS.db.profile.master.locked = true
    window:RefreshUpvalues()
    assertTrue(window.locked, "the master lock did not reach the window")

    inst.NS.db.profile.master.locked = false
    cfg.frame.locked = true
    window:RefreshUpvalues()
    assertTrue(window.locked, "the window's own lock stopped being read")
end)
