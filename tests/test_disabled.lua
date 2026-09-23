-- tests/test_disabled.lua -- the conformance suite for slash-commands-7, `The
-- disabled state is total`.
--
-- WHAT THIS SUITE IS FOR, and why it asserts where it does. Eleven addons in this
-- collection implemented "disabled" as a DRAW GATE: a stored boolean read as one
-- rung of a show ladder, handlers that early-return on it, and every event, message
-- and bucket the addon owns still registered underneath. This addon was one of
-- them. From the outside a draw gate is indistinguishable from an addon that stood
-- down -- the frames go away either way -- which is exactly how the shape survived
-- eleven audits.
--
-- So EVERY ASSERTION BELOW IS ON THE REGISTRATION SET, the timer set, the shown
-- set, the SavedVariables writes and the printed lines, taken from the kit's
-- recording mock. NOT ONE of them is "call a handler and assert it returned
-- early": an early return is what a draw gate does, so a suite written that way
-- certifies the very thing it exists to catch (testing-12).
--
-- The mock has to REMOVE on unregister for any of this to be falsifiable, which
-- kit revision 22's `__registrations()` does -- a registry that only ever grew
-- would report a perfectly torn-down addon as still watching everything, and a
-- suite written against it would be tuned until it stopped asking the question.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- slash-commands-2's twelve reserved verbs: the whole live set while disabled.
-- Spelled out rather than read off the library so a narrowing there is caught
-- here rather than ratified by it.
local RESERVED = {
    "help", "config", "version", "enable", "disable", "debug", "perf",
    "get", "set", "list", "reset", "resetall",
}

--- One registration, as a string a diff can be read from. Keyed by TARGET as well
--- as by name because "the addon registers UNIT_SPELLCAST_SUCCEEDED" and "the
--- addon registers it on the object that has the handler" are different claims,
--- and a stand-up that rebuilt onto a fresh target would satisfy only the first.
local function regKey(r)
    return ("%s|%s|%s|%s"):format(tostring(r.target), r.kind, tostring(r.event),
        tostring(r.unit))
end

local function regSet(inst)
    local out, n = {}, 0
    for _, r in ipairs(inst.mocks.__registrations()) do
        out[regKey(r)] = r
        n = n + 1
    end
    return out, n
end

local function sortedKeys(set)
    local out = {}
    for key in pairs(set) do out[#out + 1] = key end
    table.sort(out)
    return out
end

--- Every distinct EVENT NAME the addon is registered for, for step 6's fan-out.
local function eventNames(inst)
    local seen, out = {}, {}
    for _, r in ipairs(inst.mocks.__registrations()) do
        if r.event and not seen[r.event] then
            seen[r.event] = true
            out[#out + 1] = r.event
        end
    end
    table.sort(out)
    return out
end

--- Every frame this addon has made that is currently ON SCREEN.
---
--- THE ADDON'S OWN REGISTRY, NOT `mocks.__shownFrames()`, and the divergence is
--- tests/wow_mock.lua's rather than this suite's: this addon replaces the kit's
--- frame stub wholesale with tests/mock_frame.lua, because its entire output is
--- text and bar values written onto per-cell FontStrings and StatusBars and the
--- base's blanket metatable answers every region with the frame itself. Its frames
--- therefore never land in the kit's own frame registry, and the kit's shown
--- survey would answer an empty list for an addon drawing twenty windows -- which
--- would make step 5 unfalsifiable, the exact failure mode the kit's fidelity
--- rules warn about. The survey below is the same claim taken from the registry
--- this addon's frames DO land in.
--- `IsVisible`, NOT `IsShown`, and the distinction is the client's rather than
--- this suite's. `IsShown` is a frame's OWN flag: a row cell parented onto a
--- window body keeps its flag set when the body is hidden, exactly as it does in
--- game, and this addon draws forty of them. What "on screen" means is the whole
--- ancestor chain, which is what `IsVisible` walks -- and it is what makes the
--- assertion honest in the other direction too, because a stand-down that hid the
--- cells and left the body up would still be caught.
---
--- THE SETTINGS PANEL BODY IS EXCLUDED, and that is slash-commands-§7's own *What
--- MUST survive* rather than a convenience: the addon stays listed in Blizzard's
--- Options -> AddOns tree while disabled and its *Enable Ka0s Multi Meters*
--- checkbox is live there, which is one of the two routes the section nominates
--- back from the disabled state. Those canvases are parented into Blizzard's own
--- panel, which decides whether they are on screen; asserting them hidden would be
--- asserting the opposite of the rule.
local function isPanelChrome(frame)
    local f, guard = frame, 0
    while f and guard < 40 do
        local name = f.__name
        if type(name) == "string" and name:match("^MultiMeters.*Panel$") then return true end
        f, guard = f.__parent, guard + 1
    end
    return false
end

local function shownFrames(inst)
    local out = {}
    for _, f in ipairs(inst.mocks.__frames) do
        if f.IsVisible and f:IsVisible() and not isPanelChrome(f) then out[#out + 1] = f end
    end
    return out
end

local function chatSince(inst, n)
    local out = {}
    for i = n + 1, #inst.mocks.__chat do out[#out + 1] = inst.mocks.__chat[i] end
    return out
end

local function say(inst, msg)
    local n = #inst.mocks.__chat
    inst.NS.Slash:OnSlash(msg)
    return chatSince(inst, n)
end

--- The suite's one fixture: an enabled, fully-enabled instance with at least one
--- window on screen, plus the three baseline snapshots step 1 demands.
local function scene()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    -- A window the ladder will actually show, so `F_on` is not empty and step 5
    -- has something to prove.
    for _, w in ipairs(NS.WindowManager.All()) do w:Show() end
    inst.mocks.__watchSv("MultiMetersDB")
    inst.mocks.__watchSv("MultiMetersPerfDB")
    return inst, NS
end

local function refusalLine(inst)
    return inst.mocks.LibStub("LibKa0s-Slash-1.0").DISABLED_LINE_FORMAT
        :format(inst.NS.L["Ka0s Multi Meters"], "/mm enable")
end

-- ---------------------------------------------------------------------------
-- 1. Baseline
-- ---------------------------------------------------------------------------

test("Disabled 1: enabled, the addon registers, arms and draws something at all", function()
    -- The trivially-passing case this step exists to exclude: an addon that
    -- registers nothing when it is ON satisfies every later assertion by doing
    -- nothing at all, and the suite would be green over a dead addon.
    local inst = select(1, scene())
    local _, count = regSet(inst)
    assertTrue(count > 0, "the baseline registration set is empty; nothing below can fail")
    assertTrue(#shownFrames(inst) > 0, "nothing is on screen to be hidden")
end)

-- ---------------------------------------------------------------------------
-- 3. The registration set is empty
-- ---------------------------------------------------------------------------

test("Disabled 3: every registration the addon made is actually UNREGISTERED", function()
    -- THE ASSERTION THE WHOLE SUITE EXISTS FOR, and the one that reddens a draw
    -- gate. Not "the handler returned early" -- an early return means the addon
    -- did not stop watching, it stopped reacting, and the client still walks the
    -- registration list, still builds the argument frame and still enters Lua.
    --
    -- red under: dropping the `NS:UnregisterAllEvents()` from
    --            core/LifecycleSetup.lua's standDown -- or the module loop, or the
    --            bus loop, each of which reddens it on its own.
    local inst, NS = scene()
    local before, beforeN = regSet(inst)
    assertTrue(beforeN > 0)

    -- THROUGH THE SINGLE WRITE SEAM, never by calling the teardown directly: the
    -- test has to exercise the route the checkbox and the verb take, or it proves
    -- only that a function it called did what it says.
    assertTrue(NS.SetByPath("enabled", false))

    local after, afterN = regSet(inst)
    assertEqual(afterN, 0,
        "still registered: " .. table.concat(sortedKeys(after), ", "))

    -- And by NAME as well as by count, so a survivor is named rather than counted.
    for _, key in ipairs(sortedKeys(before)) do
        assertTrue(after[key] == nil, "survivor: " .. key)
    end
end)

test("Disabled 3b: standDown runs its seven steps in the documented order", function()
    -- core/LifecycleSetup.lua's `standDown` is split into one local helper per
    -- numbered step (issue #51, keeping the function under the collection's CCN
    -- limit). This pins the ORDER those steps fire in -- events, then modules,
    -- then the bus, then windows, then the provider, then the export cancel,
    -- then visibility -- so a future split of the same function cannot reorder
    -- them silently. Each subsystem entry point is wrapped rather than replaced,
    -- so the real teardown still runs and every other assertion in this suite
    -- stays honest.
    -- red under: any reordering of the calls inside `standDown`.
    local _, NS = scene()
    local order = {}

    local function wrap(owner, key)
        local original = owner[key]
        owner[key] = function(...)
            order[#order + 1] = key
            return original(...)
        end
    end

    wrap(NS, "UnregisterAllEvents")
    wrap(NS, "CancelAllTimers")
    wrap(NS, "ResetStatePending")
    wrap(NS, "IterateModules")
    wrap(NS, "BusStandDown")
    wrap(NS.WindowManager, "Suspend")
    wrap(NS.Provider, "Suspend")
    wrap(NS.Export, "CancelSend")
    wrap(NS.Visibility, "Refresh")

    assertTrue(NS.SetByPath("enabled", false))

    assertEqual(table.concat(order, ","),
        "UnregisterAllEvents,CancelAllTimers,ResetStatePending,IterateModules,"
        .. "BusStandDown,Suspend,Suspend,CancelSend,Refresh")
end)

-- ---------------------------------------------------------------------------
-- 4. Nothing is still going to wake up
-- ---------------------------------------------------------------------------

test("Disabled 4: no timer, ticker or OnUpdate is left armed", function()
    -- A coalescing repaint timer that re-arms ten times a second in combat and
    -- then finds nothing to paint is the single most expensive shape this rule
    -- exists to kill, and this addon's window throttle is exactly one.
    -- red under: dropping `wm:Suspend()` from standDown, which is what clears the
    --            per-window OnUpdate.
    local inst, NS = scene()

    -- ARM ONE FIRST, or this step is vacuous. Nothing in this addon is on a clock
    -- until something happens: a player-state edge books the settle pass
    -- core/MultiMeters.lua schedules, and that is the AceTimer the stand-down has
    -- to cancel. A suite that asserted "no timer is armed" over an addon that had
    -- never armed one would be green over any teardown at all, including none.
    inst.mocks.__fireEvent("PLAYER_MOUNT_DISPLAY_CHANGED", "player")
    assertEqual(#inst.mocks.__timers(), 1, "the fixture needs one armed timer")

    assertTrue(NS.SetByPath("enabled", false))

    local live = inst.mocks.__timers()
    assertEqual(#live, 0, "#armed = " .. #live)

    -- And nothing arms one for the rest of the run: the settle pass, the throttle
    -- and the export stagger are all downstream of registrations that are gone.
    inst.mocks.__fireTimers()
    assertEqual(#inst.mocks.__timers(), 0, "something re-armed itself while disabled")
end)

-- ---------------------------------------------------------------------------
-- 5. Nothing is on screen
-- ---------------------------------------------------------------------------

test("Disabled 5: every frame that was shown is hidden", function()
    -- red under: making NS.ShouldShow's step 0 ignore the latch.
    local inst, NS = scene()
    local shownBefore = shownFrames(inst)
    assertTrue(#shownBefore > 0)

    assertTrue(NS.SetByPath("enabled", false))

    for _, frame in ipairs(shownBefore) do
        assertFalse(frame:IsVisible() == true, "a frame on screen at baseline is still on screen")
    end
end)

-- ---------------------------------------------------------------------------
-- 6. Fire everything anyway
-- ---------------------------------------------------------------------------

test("Disabled 6: every event fired anyway writes nothing, prints nothing, shows nothing",
function()
    -- The client will not fire these, because nothing is registered -- but a
    -- SURVIVOR would hear them, so they are fired both ways. `__fire` goes to the
    -- live set only and is the honest half; `__fireUnconditional` reaches the
    -- handler whether or not its registration is still there, and is what proves
    -- a survivor WOULD have been caught rather than that the harness went quiet.
    --
    -- PLAYER_REGEN_DISABLED is named explicitly because the collection's live
    -- example of this failure is an addon that writes `locked = true` and prints a
    -- line to chat on entering combat WHILE DISABLED -- and the player's evidence
    -- that the addon is off is the absence of exactly that line.
    --
    -- red under: giving any handler an early return instead of unregistering it,
    --            which is the draw gate and would leave the handler reachable.
    local inst, NS = scene()
    local events = eventNames(inst)
    assertTrue(#events > 10, "only " .. #events .. " events at baseline")

    local targets = {}
    for _, r in ipairs(inst.mocks.__registrations()) do targets[r.target] = true end

    assertTrue(NS.SetByPath("enabled", false))

    inst.mocks.__resetSvWrites()
    local chatN = #inst.mocks.__chat

    for _, event in ipairs(events) do
        inst.mocks.__fire(event, "player")
        for target in pairs(targets) do
            inst.mocks.__fireUnconditional(target, event, "player")
        end
    end
    inst.mocks.__fireTimers()

    local writes = inst.mocks.__svWrites()
    local paths = {}
    for i, w in ipairs(writes) do paths[i] = w.path end
    assertEqual(#writes, 0, "wrote: " .. table.concat(paths, ", "))

    local printed = chatSince(inst, chatN)
    assertEqual(#printed, 0, "said: " .. table.concat(printed, " / "))
    assertEqual(#shownFrames(inst), 0, "an event re-showed a frame")
end)

-- ---------------------------------------------------------------------------
-- 7. The slash surface -- NOT the stand-down
-- ---------------------------------------------------------------------------
--
-- A green step 7 says nothing about whether the addon is inert; steps 3 to 6 are
-- what say that. This step pins the OTHER half: the command surface is not the
-- addon, and it is deliberately unchanged.

test("Disabled 7: every reserved verb and the bare command answer normally", function()
    -- THIS STEP INVERTED AT STANDARD v2.57.0. The previous ruling narrowed the
    -- disabled surface to `enable` and `help` and refused the rest; it was
    -- reversed on contact with use, when `/mm` on a disabled addon answered with a
    -- refusal instead of opening the settings panel -- which is the one surface a
    -- player uses to switch it back on by hand.
    -- red under: passing a narrowed `liveVerbs` in settings/Slash.lua.
    local inst, NS = scene()
    assertTrue(NS.SetByPath("enabled", false))

    local refusal = refusalLine(inst)
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end

    local ARGS = {
        get = "enabled", set = "master.alpha 0.5", reset = "master.scale",
        perf = "help",
    }
    for _, verb in ipairs(RESERVED) do
        local lines = say(inst, verb .. (ARGS[verb] and (" " .. ARGS[verb]) or ""))
        for _, line in ipairs(lines) do
            -- `help` is the one verb that carries the line as a NOTICE under its
            -- header rather than as its answer: the index prints in full, because
            -- the player has to be able to SEE `enable` in the list.
            if verb ~= "help" then
                assertTrue(line:find(refusal, 1, true) == nil,
                    "`/mm " .. verb .. "` was refused: " .. line)
            end
        end
    end

    -- THE CASE THAT SETTLED THE REVERSAL: the bare command opens the panel.
    local bare = say(inst, "")
    for _, line in ipairs(bare) do
        assertTrue(line:find(refusal, 1, true) == nil, "the bare `/mm` was refused")
    end
    assertTrue(opened >= 1, "the bare `/mm` must open the settings panel while disabled")

    -- The schema CLI really READ AND WROTE rather than merely answering: repairing
    -- a setting is the whole reason it stays live.
    assertEqual(NS.GetSetting("master.alpha"), 0.5)
    assertEqual(NS.GetSetting("master.scale"), NS.FindSchemaRow("master.scale").default)
end)

test("Disabled 7: every FEATURE verb refuses on exactly one line and reaches no seam", function()
    -- This addon TAKES slash-commands-2's SHOULD, and the suite pins that choice
    -- so it cannot drift silently: an addon that declined it would assert its
    -- feature verbs act normally instead, and either is conformant.
    --
    -- `lock` is on this list under slash-commands-8's own ruling -- unlocking a
    -- frame that is not drawn is not a coherent request -- and that says nothing
    -- about what `lock` MEANS in this addon, which is its ratified deviation.
    -- red under: naming a feature verb in a `liveVerbs` array.
    local inst, NS = scene()
    assertTrue(NS.SetByPath("enabled", false))

    local refusal = refusalLine(inst)
    local live = {}
    for _, verb in ipairs(RESERVED) do live[verb] = true end

    inst.mocks.__resetSvWrites()
    local gated = 0
    for _, entry in ipairs(NS.COMMANDS) do
        local verb = entry[1]
        if not live[verb] then
            gated = gated + 1
            local lines = say(inst, verb)
            assertEqual(#lines, 1, "`/mm " .. verb .. "` said " .. #lines .. " lines")
            assertTrue(lines[1]:find(refusal, 1, true) ~= nil,
                "`/mm " .. verb .. "` did not print the collection's refusal line: " .. lines[1])
        end
    end
    assertTrue(gated >= 6, "only " .. gated .. " feature verbs; the gate proves nothing")

    local writes = inst.mocks.__svWrites()
    assertEqual(#writes, 0, "a refused verb still reached the write seam")
    assertEqual(#shownFrames(inst), 0, "a refused verb still showed something")
end)

-- ---------------------------------------------------------------------------
-- 8. The launcher
-- ---------------------------------------------------------------------------

test("Disabled 8: left-click refuses and writes nothing; right-click still opens the panel",
function()
    -- The audit found a minimap button with NO disabled gate at all, so clicking
    -- it wrote the stored tree of an addon the player had switched off. This
    -- addon's rung-(a) left click drives `WindowManager:Toggle`, which writes each
    -- window's stored `shown`, so it was exactly that bug.
    -- red under: removing the NS.IsDisabled branch from core/LauncherSetup.lua.
    local inst, NS = scene()
    assertTrue(NS.SetByPath("enabled", false))

    local obj = NS.Launcher.Object and NS.Launcher:Object()
    assertTrue(obj ~= nil and type(obj.OnClick) == "function", "no LDB object to click")

    inst.mocks.__resetSvWrites()
    local chatN = #inst.mocks.__chat
    obj.OnClick(obj, "LeftButton")

    local printed = chatSince(inst, chatN)
    assertEqual(#printed, 1, "the refused click said " .. #printed .. " lines")
    assertTrue(printed[1]:find(refusalLine(inst), 1, true) ~= nil, printed[1])
    assertEqual(#inst.mocks.__svWrites(), 0, "a refused click wrote SavedVariables")
    assertEqual(#shownFrames(inst), 0, "a refused click showed a window")

    -- RIGHT-CLICK IS UNCHANGED, in either state: the ruling narrows the SLASH
    -- surface, and a mouse click is not a slash command. It is also one of the two
    -- routes slash-commands-7 nominates to the panel while the addon is off.
    local opened = 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    obj.OnClick(obj, "RightButton")
    assertEqual(opened, 1, "right-click must still open the settings panel")
end)

-- ---------------------------------------------------------------------------
-- 9. Restoration, from CURRENT state
-- ---------------------------------------------------------------------------

test("Disabled 9: re-enabling restores the registration set it had", function()
    -- red under: a standUp that rebuilt from a snapshot taken on the way down.
    local inst, NS = scene()
    local before = regSet(inst)

    assertTrue(NS.SetByPath("enabled", false))
    assertTrue(NS.SetByPath("enabled", true))

    local after = regSet(inst)
    for _, key in ipairs(sortedKeys(before)) do
        assertTrue(after[key] ~= nil, "not restored: " .. key)
    end
end)

test("Disabled 9: the rebuild reflects a setting changed WHILE disabled", function()
    -- performance-6's restore-from-current-state rule, and the case that tells a
    -- replay from a rebuild: a window created while the addon was off must come
    -- back with the others, not be forgotten because it was not in the snapshot.
    -- red under: `WindowManager:Resume` skipping its `Init()`.
    local _, NS = scene()
    local beforeCount = #NS.WindowManager.All()

    assertTrue(NS.SetByPath("enabled", false))
    local ok = NS.WindowManager.Create and NS.WindowManager:Create("Late")
    assertTrue(ok ~= nil and ok ~= false, "the fixture needs a window created while disabled")
    assertTrue(NS.SetByPath("enabled", true))

    assertEqual(#NS.WindowManager.All(), beforeCount + 1,
        "a window created while disabled was not rebuilt")
end)

-- ---------------------------------------------------------------------------
-- 10. The latch
-- ---------------------------------------------------------------------------

test("Disabled 10: releasing one hold does not resurrect an addon the other holds down",
function()
    -- THE TRAP, and it is reachable in game: `/mm disable` is a live verb, so a
    -- player can switch the addon off DURING a suspended capture -- and `/mm
    -- enable` is live too, so they can switch it back on there as well. A resume
    -- that called a bare stand-up would bring the addon back mid-capture and
    -- silently ruin the run.
    -- red under: a `StandUp()` called directly from Perf's Resume, or from the
    --            enable verb, instead of going through release-and-re-evaluate.
    local inst, NS = scene()

    -- perf first, then disabled.
    NS.Perf.Suspend()
    assertTrue(NS.SetByPath("enabled", false))
    NS.Perf.Resume()
    assertEqual(select(2, regSet(inst)), 0,
        "releasing `perf` stood the addon up while `disabled` was still held")

    assertTrue(NS.SetByPath("enabled", true))
    assertTrue(select(2, regSet(inst)) > 0, "the last release must stand the addon up")

    -- And in the other order.
    assertTrue(NS.SetByPath("enabled", false))
    NS.Perf.Suspend()
    assertTrue(NS.SetByPath("enabled", true))
    assertEqual(select(2, regSet(inst)), 0,
        "releasing `disabled` stood the addon up while `perf` was still held")
    NS.Perf.Resume()
    assertTrue(select(2, regSet(inst)) > 0)
end)

test("Disabled 10: the perf hold is session-only and the disabled hold is stored", function()
    -- The two holds have different lifetimes and neither inherits the other's
    -- rule. `perf` re-taken across a reload would leave a player's addon dead with
    -- no visible cause; `disabled` NOT surviving one is the whole point of the
    -- setting.
    local inst, NS = scene()
    NS.Perf.Suspend()
    assertTrue(NS.SetByPath("enabled", false))

    local holds = NS.lifecycle:Holds()
    assertEqual(table.concat(holds, ","), "disabled,perf")

    local writes = inst.mocks.__svWrites()
    local stored = {}
    for _, w in ipairs(writes) do
        if tostring(w.path):find("perf", 1, true) then stored[#stored + 1] = w.path end
    end
    assertEqual(#stored, 0, "the perf hold reached SavedVariables: "
        .. table.concat(stored, ", "))
    assertEqual(NS.GetSetting("enabled"), false, "the disabled hold IS the stored setting")
end)

-- ---------------------------------------------------------------------------
-- 11. The bus record
-- ---------------------------------------------------------------------------
--
-- Every bus receiver that is not an AceAddon module owns a private target from
-- `NS.NewBusTarget()`, and the record behind that factory is what lets step 3 take
-- those registrations down and step 9 put them back. Written BEFORE the record moved
-- onto LibKa0s-Bus-1.0 (LibKa0s v1.55.0, docs/revendor/2026-09-23/) and green against
-- the hand-written one it replaced: what a receiver can observe is whether a message
-- reaches it, so that is what these assert -- not the record's internals.

--- A probe receiver on the addon's own factory, counting deliveries of `message`.
local function probe(NS, message)
    local seen = { n = 0 }
    seen.target = NS.NewBusTarget()
    seen.target:RegisterMessage(message, function() seen.n = seen.n + 1 end)
    return seen
end

test("Disabled 11: a bus receiver goes down with the addon and comes back with it", function()
    -- red under: a stand-down that skips the bus record (the receiver still hears
    -- the message while disabled), or a stand-up that forgets to replay it.
    local _, NS = scene()
    local MSG = NS.Constants.MSG
    local seen = probe(NS, MSG.ZONE_CHANGED)

    NS:SendMessage(MSG.ZONE_CHANGED)
    assertEqual(seen.n, 1, "the probe never heard the message while enabled")

    assertTrue(NS.SetByPath("enabled", false))
    NS:SendMessage(MSG.ZONE_CHANGED)
    assertEqual(seen.n, 1, "a disabled addon's bus receiver still heard the message")

    assertTrue(NS.SetByPath("enabled", true))
    NS:SendMessage(MSG.ZONE_CHANGED)
    assertEqual(seen.n, 2, "the receiver was not put back when the addon came back")
end)

test("Disabled 11: a receiver its owner retired stays retired across the round trip", function()
    -- `WindowProto:UnregisterBus` on a destroyed window is the real caller: a stand-up
    -- that resurrected what its owner dropped would wake a window nobody can see.
    -- red under: a record that the Unregister* wrappers do not clear.
    local _, NS = scene()
    local MSG = NS.Constants.MSG
    local all = probe(NS, MSG.ZONE_CHANGED)
    local one = probe(NS, MSG.ZONE_CHANGED)
    all.target:UnregisterAllMessages()
    one.target:UnregisterMessage(MSG.ZONE_CHANGED)

    assertTrue(NS.SetByPath("enabled", false))
    assertTrue(NS.SetByPath("enabled", true))
    NS:SendMessage(MSG.ZONE_CHANGED)
    assertEqual(all.n, 0, "UnregisterAllMessages was undone by the stand-up")
    assertEqual(one.n, 0, "UnregisterMessage was undone by the stand-up")
end)

test("Disabled 11: a receiver that subscribes while disabled hears the bus once enabled", function()
    -- The settings panel and a window created while the addon is off both do this.
    -- red under: a stand-up that replays only what was recorded before the stand-down.
    local _, NS = scene()
    local MSG = NS.Constants.MSG
    assertTrue(NS.SetByPath("enabled", false))
    local late = probe(NS, MSG.ZONE_CHANGED)
    assertTrue(NS.SetByPath("enabled", true))
    NS:SendMessage(MSG.ZONE_CHANGED)
    assertEqual(late.n, 1, "a subscription made while disabled never went live")
end)

test("Disabled 11: a subscription made while disabled is recorded, not made", function()
    -- LibKa0s-Bus-1.0's while-down rule: a registration on a tracked target while the
    -- bus is down goes into the record and goes live at StandUp. So a stood-down addon
    -- registers NOTHING, structurally, rather than by each receiver remembering to ask
    -- the latch first. The hand-written record this replaced made it live at once.
    -- red under: a bus that makes the raw registration while down.
    local inst, NS = scene()
    local MSG = NS.Constants.MSG
    assertTrue(NS.SetByPath("enabled", false))
    local late = probe(NS, MSG.ZONE_CHANGED)
    NS:SendMessage(MSG.ZONE_CHANGED)
    assertEqual(late.n, 0, "a receiver subscribed while disabled heard the bus while disabled")
    assertEqual(select(2, regSet(inst)), 0, "the late subscription reached the registry")
    assertTrue(NS.SetByPath("enabled", true))
    NS:SendMessage(MSG.ZONE_CHANGED)
    assertEqual(late.n, 1)
end)

test("Disabled 11: standUp brings the bus up FIRST, before any module re-enables", function()
    -- The order is what makes the rule above safe: a module's OnEnable, or a window
    -- WindowManager:Resume builds, registers on a bus that is already up, so it is live
    -- at once and anything published later in the stand-up reaches it.
    -- red under: `NS.BusStandUp()` anywhere below `NS:OnEnable()` in standUp.
    local _, NS = scene()
    local order = {}
    for _, key in ipairs({ "BusStandUp", "OnEnable" }) do
        local original = NS[key]
        NS[key] = function(...)
            order[#order + 1] = key
            return original(...)
        end
    end
    assertTrue(NS.SetByPath("enabled", false))
    assertTrue(NS.SetByPath("enabled", true))
    assertEqual(table.concat(order, ","), "BusStandUp,OnEnable")
end)
