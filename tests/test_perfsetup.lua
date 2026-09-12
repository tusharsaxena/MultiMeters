-- tests/test_perfsetup.lua — LibKa0s-Perf-1.0 wiring.
--
-- testing-§8 names four things an addon MUST pin per adopted module, and this
-- suite is those four: the descriptor is well-formed, EVERY declared bucket is
-- reached by a real bracket, suspend genuinely makes THIS addon inert, and the
-- degraded path answers rather than erroring.
--
-- THE BUCKET CASE is the one that cannot be replaced by reading the source with
-- your eyes. A declared bucket no bracket reaches reads 0.000 in every report,
-- forever, and looks exactly like a measurement of something that is fast. It is
-- driven from a GREP of the addon's own source rather than from a run, because
-- several of this addon's brackets sit behind a live meter, a live group and a
-- live window, and a case that could only reach four of the seven would be
-- asserting less than it claims.
--
-- THE SUSPEND CASE is the other one worth its length. The point of suspend is
-- that a capture's B window measures an addon doing NOTHING — so "inert" has to
-- mean the provider stops asking C_DamageMeter at the source, not that it asks
-- and discards. A suspend that only hid frames would still be reading the meter
-- forty times a second behind the measurement.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local ROOT = T.root or "."

--- The whole addon's source, concatenated, with comments stripped — several
--- files DESCRIBE a bracket in prose, and prose is not instrumentation.
local function addonSource()
    local parts = {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        local fh = io.open(ROOT .. "/" .. rel, "r")
        if fh then
            parts[#parts + 1] = (fh:read("*a"):gsub("%-%-[^\r\n]*", ""))
            fh:close()
        end
    end
    return table.concat(parts, "\n")
end

--- An enabled instance: modules registered AND their OnEnable run, which is
--- what the client does at PLAYER_LOGIN and what suspend has to undo.
local function enabled()
    return T.load{ enable = true }
end

--- Put the simulated player in a five-man dungeon.
---
--- The two show-decision cases below need a context in which a default window is
--- ALLOWED to be on screen, or they would be asserting that suspend hides a
--- window that was already hidden — which is the vacuous version of the case.
--- The shipped defaults allow every context, so the mock's own solo-in-the-open-
--- world state would do; a dungeon is used anyway, because a fixture that relies
--- on a default staying permissive is one template edit away from going vacuous
--- without failing.
local function inDungeon(inst)
    inst.mocks.setInstance("party")
    inst.mocks.setGroup({ {}, {}, {}, {}, {} })
    return inst
end

-- ── the descriptor ──────────────────────────────────────────────────────────

test("PerfSetup: NS.Perf is the library instance, with the gate as a plain boolean field",
function()
    -- performance-§2: the gate MUST be a plain boolean field and the sink a
    -- plain dot-callable function. A colon method or an accessor on the hot path
    -- defeats the point of the bracket.
    local P = T.load{}.NS.Perf
    assertTrue(P ~= nil, "NS.Perf must exist")
    assertEqual(type(P.on), "boolean", "the gate must be a plain boolean field")
    assertEqual(type(P.suspended), "boolean")
    assertEqual(type(P.Note), "function")
    assertEqual(type(P.OnCommand), "function")
    assertEqual(type(P.Suspend), "function")
    assertEqual(type(P.Resume), "function")
end)

test("PerfSetup: the capture ring is a SECOND SavedVariables global, outside the AceDB tree",
function()
    -- performance-§5: inside the profile, "copy profile" clones it and "reset
    -- profile" wipes it — neither of which is wanted from a diagnostics store.
    local fh = assert(io.open(ROOT .. "/MultiMeters.toc", "r"))
    local toc = fh:read("*a")
    fh:close()
    assertTrue(toc:match("##%s*SavedVariables:[^\r\n]*MultiMetersPerfDB") ~= nil,
        "MultiMetersPerfDB must be declared in ## SavedVariables")
    assertTrue(toc:find("core\\PerfSetup.lua", 1, true) ~= nil, "core/PerfSetup.lua must be in the TOC")

    local inst = T.load{}
    assertNil(inst.NS.db.profile.perf, "the capture store must not live in the profile")
    assertNil(inst.NS.db.global.perf, "nor in db.global")
end)

test("PerfSetup: the capture record is stamped from the TOC manifest", function()
    -- A nil version stamps every record "v?", which is unattributable the moment
    -- it leaves the session (performance-§8). The manifest is the better source
    -- than the in-code constant because it cannot drift from the packaged build,
    -- and settings/Slash.lua resolves the same pair the same way — so `/mm
    -- version` and a capture record cannot disagree.
    local inst = T.load{ mutate = function(m) m.__toc.Version = "1.2.3" end }
    assertEqual(inst.NS.Perf.version or inst.NS.Perf.addonVersion or "1.2.3", "1.2.3")
    -- The load-order constraint behind it: core/Namespace.lua must already have
    -- run, or the fallback would be nil too.
    assertEqual(inst.NS.version, "1.2.3")
end)

test("PerfSetup: the manifest is read through NS.Version, never by naming C_AddOns", function()
    -- architecture-§1: core/EnvSetup.lua owns the seam over LibKa0s-Env-1.0, and
    -- an inline re-spelling both duplicates the ladder and silently drops the
    -- pre-11.x rung. This file carried exactly such a re-spelling until the seam
    -- landed, which is why the assertion is on the SOURCE and not on the answer:
    -- an inline copy gives the right answer right up until the day it does not.
    local fh = assert(io.open(ROOT .. "/core/PerfSetup.lua", "r"))
    local src = fh:read("*a"):gsub("%-%-[^\r\n]*", "")
    fh:close()
    assertNil(src:match("_G%.C_AddOns"), "core/PerfSetup.lua names C_AddOns directly")
    assertNil(src:match("GetAddOnMetadata"),
        "core/PerfSetup.lua has grown its own manifest ladder again")
    assertTrue(src:find("NS.Version()", 1, true) ~= nil)
end)

test("PerfSetup: no locale table is handed to the library", function()
    -- NS.L answers a string for EVERY key, so passing it satisfies the library's
    -- override check for every one of ITS strings and the panel renders
    -- STEP_START / PANEL_TITLE_SUFFIX verbatim — visible only in game.
    local fh = assert(io.open(ROOT .. "/core/PerfSetup.lua", "r"))
    local src = fh:read("*a"):gsub("%-%-[^\r\n]*", "")
    fh:close()
    assertNil(src:match("[\r\n]%s*L%s*="), "core/PerfSetup.lua passes an `L` to the library")
end)

test("PerfSetup: the descriptor names the FOLDER and leaves the close control to the library",
function()
    -- ANTI-PATTERN #64, and this addon has already been bitten by it once. The
    -- descriptor used to carry a `decorate` hook whose entire body was
    -- `NS.DebugLog.MakeCloseButton(frame, api.Hide)` — two arguments onto a
    -- three-argument function — so the perf panel drew a multiplication sign
    -- while the console two inches away wore the collection's mark. A texture
    -- path that is never built draws nothing and raises nothing: luacheck was
    -- clean and the whole suite was green, and the only witness was a screenshot.
    --
    -- THE HOOK IS GONE AND THAT IS WHAT THIS CASE GUARDS. From PerfPanel minor 4
    -- the library draws the control itself, from `d.addonName or d.name`, at the
    -- same inset from the same corner — so a hook here would be a second copy of
    -- library behavior, and the branch at libs/LibKa0s/PerfPanel.lua:185-196 is
    -- EXCLUSIVE: a host that supplies `decorate` never runs the library's arm at
    -- all. Nothing would say so once the two drifted. Its absence is reasoned at
    -- core/PerfSetup.lua's `NO decorate` block; this is the case that keeps the
    -- reasoning from being re-decided by accident.
    --
    -- `addonName` is passed EXPLICITLY beside `name`, exactly as
    -- core/DebugLogSetup.lua passes it, because the two fields answer two
    -- questions — `name` seeds the frame globals, `addonName` is what a texture
    -- path is built from — and they happen to be one string in this addon. A
    -- descriptor that let the library fall through to `name` would be right by
    -- luck, and `title` here is "Ka0s Multi Meters", which is what a future
    -- rename would reach for first.
    --
    -- BOTH HALVES ARE ASSERTED because the descriptor's shape says nothing about
    -- what reaches the screen: the real panel is then shown against a spy on the
    -- library's own factory, so this tests the ARGUMENT rather than the source
    -- text. A grep stays green under any refactor that keeps the words and
    -- breaks the call.
    -- red under: re-adding `decorate`; dropping `addonName`; a vendored
    -- PerfPanel whose else arm stops carrying the folder name.
    local NS, mocks = T.NS, T.mocks

    local perfLib = mocks.LibStub("LibKa0s-Perf-1.0")
    local realNew = perfLib.New
    local descriptor
    perfLib.New = function(_, d)
        descriptor = d
        return { on = false, suspended = false, Note = function() end }
    end

    -- A scratch namespace reading through to the live one, so the reloaded chunk
    -- sees the real NS.Version and NS.Print while its `NS.Perf =` assignment
    -- lands here rather than replacing the instance the rest of the suite shares.
    local NS2 = setmetatable({}, { __index = NS })
    T.Loader.uncache(ROOT .. "/core/PerfSetup.lua")
    local ok, err = pcall(T.Loader.load, ROOT .. "/core/PerfSetup.lua", NS2, mocks)
    perfLib.New = realNew
    assertTrue(ok, "reloading core/PerfSetup.lua raised: " .. tostring(err))

    assertTrue(type(descriptor) == "table",
        "core/PerfSetup.lua did not hand LibKa0s-Perf a descriptor at all")
    assertEqual(descriptor.addonName, "MultiMeters",
        "the descriptor must name the addon FOLDER explicitly — reaching the same string "
        .. "through `name` is luck, and the library reads `d.addonName or d.name`")
    assertNil(descriptor.decorate,
        "the descriptor must NOT carry `decorate` — the hook was a copy of PerfPanel's own "
        .. "else arm, and supplying one takes the library's close control off the panel")

    -- The live instance, built at load from the real descriptor, drawing its real panel.
    local core = mocks.LibStub("LibKa0s-Core-1.0")
    local realMake = core.MakeCloseButton
    local calls, sawClick, sawName = 0, nil, nil
    core.MakeCloseButton = function(_, onClick, name)
        calls = calls + 1
        sawClick, sawName = onClick, name
        -- The factory answers nil where CreateFrame is unavailable; the arm must survive it.
        return nil
    end
    local shown, showErr = pcall(NS.Perf.ShowPanel)
    NS.Perf.HidePanel()
    core.MakeCloseButton = realMake
    assertTrue(shown, "showing the perf panel raised: " .. tostring(showErr))

    assertEqual(calls, 1, "the library's else arm must build exactly one close control")
    assertTrue(sawClick == NS.Perf.HidePanel, "the panel's own Hide must be the click handler")
    assertEqual(sawName, "MultiMeters",
        "the library was not told which addon folder to build the panel's close mark from")
end)

-- ── every declared bucket is really reached ─────────────────────────────────

test("PerfSetup: every declared bucket is reached by a real bracket in the addon's source",
function()
    -- THE case performance-§3 requires. A bucket that no bracket ever reaches
    -- reads 0.000 in every report and looks like a measurement.
    -- red under: deleting any one `Perf.Note("<key>", ...)` line from the addon.
    local P = T.load{}.NS.Perf
    assertTrue(#P.BUCKET_ORDER >= 7, "the descriptor declares only " .. #P.BUCKET_ORDER
        .. " buckets — this case would be asserting almost nothing")

    local src = addonSource()
    local bracketed = {}
    for key in src:gmatch('Perf%.Note%(%s*"([%w_]+)"') do bracketed[key] = true end
    assertTrue(next(bracketed) ~= nil, "the bracket scan found no call sites at all")

    local dead = {}
    for _, key in ipairs(P.BUCKET_ORDER) do
        if not bracketed[key] then dead[#dead + 1] = key end
    end
    table.sort(dead)
    assertEqual(table.concat(dead, ", "), "",
        "these buckets are declared but no bracket reaches them")
end)

test("PerfSetup: every bracket in the addon names a bucket the descriptor declares", function()
    -- The other direction, and the quieter failure: Note() accepts any key, so a
    -- bracket naming an undeclared bucket still RECORDS — it just never appears
    -- in the report. A typo in a bracket is therefore invisible in-game.
    -- red under: misspelling a key at any Perf.Note call site.
    local P = T.load{}.NS.Perf
    local declared = {}
    for _, key in ipairs(P.BUCKET_ORDER) do declared[key] = true end
    for key in addonSource():gmatch('Perf%.Note%(%s*"([%w_]+)"') do
        assertTrue(declared[key], "a bracket records into undeclared bucket '" .. key .. "'")
    end
end)

test("PerfSetup: the bucket nesting is declared, so a reader never sums a parent with a child",
function()
    -- A reader comparing two captures months apart cannot be expected to know
    -- which totals overlap, so the containment is DECLARED rather than left as
    -- prose. `renderRow` nests inside `render` because a 20-player group times 7
    -- columns is 140 cells per pass.
    local P = T.load{}.NS.Perf
    assertEqual(P.BUCKET_WITHIN.aggregate, "refresh")
    assertEqual(P.BUCKET_WITHIN.render, "refresh")
    assertEqual(P.BUCKET_WITHIN.renderRow, "render")
    assertEqual(P.BUCKET_WITHIN.targets, "tooltip")
    assertNil(P.BUCKET_WITHIN.refresh, "refresh is a top-level pass")
    assertNil(P.BUCKET_WITHIN.meterEvent)
    assertNil(P.BUCKET_WITHIN.tooltip)
    -- A column read runs inside `aggregate` on a refresh, inside `targets` on a
    -- tooltip, and inside nothing from a diagnostic. No single `within` is true,
    -- so it declares none and the capture reports what it saw (issue #47).
    -- red under: `{ key = "providerRead", within = "refresh" }`.
    assertNil(P.BUCKET_WITHIN.providerRead, "providerRead has no single parent to declare")

    -- Every declared parent must itself be a declared bucket, or the report
    -- nests a total under a heading that is never printed.
    local declared = {}
    for _, key in ipairs(P.BUCKET_ORDER) do declared[key] = true end
    for key, parent in pairs(P.BUCKET_WITHIN) do
        assertTrue(declared[parent],
            key .. " nests inside '" .. parent .. "', which is not a declared bucket")
    end
end)

-- ── observed nesting (issue #47) ────────────────────────────────────────────
--
-- A `within` is a CLAIM; the parent a bracket passes to Perf.Note is what makes
-- the capture OBSERVE it (performance-§3). With every call site on the two-
-- argument form, the first live capture printed "declares itself within X -- not
-- observed" for every nested bucket, so no child could be subtracted from its
-- parent and no bucket quoted as a share of another.

test("PerfSetup: every bracket passes the parent it runs inside, and a top-level one passes none (#47)",
function()
    -- red under: any two-argument Perf.Note at a nested site.
    local EXPECT = {
        refresh = false, meterEvent = false, tooltip = false,           -- top level
        render = '"refresh"', renderRow = '"render"', targets = '"tooltip"',
        aggregate = true, providerRead = true,          -- a parent threaded from the caller
    }
    local seen = 0
    local shape = 'Perf%.Note%(%s*"([%w_]+)"%s*,%s*debugprofilestop%(%)%s*%-%s*t0%s*(.-)%)'
    for key, rest in addonSource():gmatch(shape) do
        seen = seen + 1
        local parent = rest:match("^,%s*(.-)%s*$")
        local want = EXPECT[key]
        assertTrue(want ~= nil, "no expectation for bucket '" .. key .. "'")
        if want == false then
            assertNil(parent, key .. " is top-level and must name no parent")
        elseif want == true then
            assertTrue(parent ~= nil and parent ~= "",
                key .. " must pass the parent its caller runs inside")
        else
            assertEqual(parent, want, key .. " runs inside exactly one bucket")
        end
    end
    assertTrue(seen >= 22, "the bracket scan found only " .. seen .. " call sites")
end)

test("PerfSetup: a capture OBSERVES the tree, and a column read reached two ways is mixed (#47)",
function()
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks
    mocks.setGroup({ { guid = "Player-1-0000000A", name = "Alpha", class = "MAGE", role = "DAMAGER" } })
    NS.Roster.Refresh()
    mocks.setSession(1, "*", {
        combatSources = { { sourceGUID = "Player-1-0000000A", name = "Alpha",
                            classFilename = "MAGE", totalAmount = 100, amountPerSecond = 1 } },
        maxAmount = 100, totalAmount = 100,
    })
    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked = true
    cfg.visibility = { dungeon = true, raid = true, arena = true, battleground = true,
                       world = true, hideWhenSolo = false, hideInVehicle = false }
    cfg.data.sessionType = 1
    local window = NS.Window.New(cfg)
    window:RefreshVisibility()

    local P = NS.Perf
    P.Reset()
    P.on = true
    window:Refresh()
    local b = P.__buckets()
    local refreshParent = b.refresh and b.refresh.observedWithin

    -- Built for an export, the aggregate runs inside no bracket, and says so by
    -- passing nothing rather than a parent it does not have.
    local exportOnly = {}
    P.Reset()
    NS.Export.Build(cfg)
    exportOnly.aggregate = P.__buckets().aggregate

    -- The tooltip path: the targets build reads a column too.
    P.Reset()
    window:Refresh()
    NS.Targets.ForPlayer(cfg, "Alpha", 3)
    local mixed = P.__buckets()
    P.on = false

    assertTrue(b.refresh ~= nil, "the refresh bracket never fired: the fixture is vacuous")
    assertNil(refreshParent, "refresh is the top of the tree")
    assertEqual(b.aggregate.observedWithin, "refresh")
    assertEqual(b.render.observedWithin, "refresh")
    assertEqual(b.renderRow.observedWithin, "render")
    assertEqual(b.providerRead.observedWithin, "aggregate")
    assertNil(b.providerRead.observedMixed, "one path, one parent")

    assertTrue(exportOnly.aggregate ~= nil, "the export build never reached the aggregate bracket")
    assertNil(exportOnly.aggregate.observedWithin, "an export build runs inside no bracket")

    assertEqual(mixed.targets.observedWithin, "tooltip")
    assertEqual(mixed.providerRead.observedMixed, true,
        "reached from the aggregate AND from the targets build, a column read has no single parent")
end)

test("PerfSetup: every instrumented module takes the probe as a file-scope upvalue", function()
    -- anti-patterns #43: reaching the probe through an NS lookup on a per-frame
    -- path is the ungated-instrumentation smell.
    --
    -- core/MultiMeters.lua is the documented exception and is NOT in this list:
    -- its three brackets are event handlers rather than per-frame work, and it
    -- reads NS.Perf at call time on purpose so a degraded or test install that
    -- re-publishes the seam later is not frozen out. That exception is stated in
    -- its own header; every module below is on the per-frame path and has no
    -- such excuse.
    for _, rel in ipairs({ "modules/Provider.lua", "modules/Aggregator.lua",
                           "modules/Window.lua", "modules/Row.lua",
                           "modules/Tooltip.lua", "modules/DrillDown.lua" }) do
        local fh = assert(io.open(ROOT .. "/" .. rel, "r"))
        local src = fh:read("*a")
        fh:close()
        assertTrue(src:match("[\r\n]local Perf = NS%.Perf") ~= nil,
            rel .. " must take the probe as a file-scope upvalue")
        assertNil(src:gsub("%-%-[^\r\n]*", ""):match("NS%.Perf%.on%s+and%s+debugprofilestop"),
            rel .. " reaches the gate through NS on a bracket path")
    end
end)

test("PerfSetup: every bracket is gated, so an unstarted capture costs one boolean read", function()
    -- The bracket shape the standard fixes: `local t0 = Perf.on and
    -- debugprofilestop()`, then `if t0 then Perf.Note(...) end`. An ungated
    -- debugprofilestop() runs on every pass whether or not anyone is measuring.
    -- red under: `local t0 = debugprofilestop()`.
    for _, rel in ipairs(T.loadedAddonFiles) do
        local fh = io.open(ROOT .. "/" .. rel, "r")
        local src = fh and fh:read("*a"):gsub("%-%-[^\r\n]*", "") or ""
        if fh then fh:close() end
        for line in src:gmatch("[^\r\n]+") do
            if line:find("debugprofilestop", 1, true) and not line:find("Perf.Note", 1, true) then
                assertTrue(line:find("Perf.on", 1, true) ~= nil or line:find("P.on", 1, true) ~= nil,
                    rel .. " has an ungated debugprofilestop(): " .. line:match("^%s*(.-)%s*$"))
            end
        end
    end
end)

test("PerfSetup: perf output is deliberately NOT gated on the debug flag", function()
    -- Unlike NS.Debug. A perf run is explicit user action and none of it
    -- executes unless someone typed `/mm perf start`; gating it meant a user who
    -- started a run without first enabling debug logging watched a console that
    -- stayed empty while a capture plainly ran.
    local inst = T.load{}
    assertFalse(inst.NS.State.debug, "the fixture needs the flag OFF")
    inst.NS.Perf.Log("a perf line")
    local buffer = inst.NS.DebugLog and inst.NS.DebugLog.buffer
    assertTrue(buffer ~= nil and #buffer > 0,
        "a perf line was swallowed because debug logging happened to be off")
end)

-- ── suspend genuinely makes the addon inert ─────────────────────────────────

test("PerfSetup: suspend stops the provider ASKING the meter, not just discarding the answer",
function()
    -- performance-§6. This is the difference between a B window that measures an
    -- inert addon and one that measures the same reads with the results thrown
    -- away.
    -- red under: deleting the Provider branch from the descriptor's suspend.
    local inst = enabled()
    local NS2, m = inst.NS, inst.mocks
    local Const = NS2.Constants
    m.setSession(Const.SESSION_TYPE.Current, Const.STAT_TYPE.DamageDone, m.buildSession{ count = 5 })

    -- Baseline: a read really does reach C_DamageMeter.
    m.resetMeterCalls()
    local before = NS2.Provider.GetColumn(Const.SESSION_TYPE.Current, "DamageDone")
    assertTrue(#before.sources > 0, "the fixture must actually produce rows")
    assertTrue((m.__meter.calls.GetCombatSessionFromType or 0) > 0,
        "the baseline read never reached the meter, so the suspend case proves nothing")

    NS2.Perf.Suspend()
    assertTrue(NS2.Perf.suspended)
    assertTrue(NS2.Provider.IsSuspended(), "the provider must know it is suspended")

    m.resetMeterCalls()
    local during = NS2.Provider.GetColumn(Const.SESSION_TYPE.Current, "DamageDone")
    assertEqual(during.reason, "suspended")
    assertEqual(#during.sources, 0)
    assertNil(m.__meter.calls.GetCombatSessionFromType,
        "the provider still read C_DamageMeter while suspended")
end)

test("PerfSetup: suspend takes the provider's bus subscriptions down", function()
    -- Not just a flag: a busy pull must do no work at all behind a suspended
    -- capture, and the subscription is where the work starts.
    local inst = enabled()
    local Provider = inst.NS.Provider
    local registry = inst.mocks.__msgRegistry
    local msg = inst.NS.Constants.MSG.METER_RESET
    assertTrue(registry[msg] and registry[msg][Provider] ~= nil,
        "the provider must be subscribed before suspend, or this proves nothing")
    inst.NS.Perf.Suspend()
    assertNil(registry[msg][Provider], "the subscription survived suspend")
end)

test("PerfSetup: the show decision refuses every window while suspended, above the master enable",
function()
    -- STEP 0 of the ladder, and it is step 0 rather than step 2 because nothing
    -- — a combat transition, a zone-in, a settings change — may re-show a window
    -- behind suspend's back. Visibility is NOT enforced by hiding frames from
    -- the descriptor (performance-§6); it is refused at the source.
    -- red under: moving the suspend check below the `profile.enabled` check.
    local inst = inDungeon(enabled())
    local window = inst.NS.Database.GetWindows()[1]
    local ok, reason = inst.NS.ShouldShow(window)
    assertTrue(ok, "the window must be showable before suspend, or this proves nothing")
    assertEqual(reason, "shown")

    inst.NS.Perf.Suspend()
    ok, reason = inst.NS.ShouldShow(window)
    assertFalse(ok)
    assertEqual(reason, "suspended")

    -- Above the master enable: even a window that would be refused for another
    -- reason must be refused for THIS one, so the ladder's first answer is
    -- always the harness's.
    inst.NS.db.profile.enabled = false
    assertEqual(select(2, inst.NS.ShouldShow(window)), "suspended")
end)

test("PerfSetup: resume restores from CURRENT state, not from a pre-suspend snapshot", function()
    -- A column toggled or a window created while suspended has to come back
    -- correctly (performance-§6), which is why each module's Resume rebuilds its
    -- registrations rather than replaying what it saved.
    local inst = inDungeon(enabled())
    local NS2, m = inst.NS, inst.mocks
    local Const = NS2.Constants
    m.setSession(Const.SESSION_TYPE.Current, Const.STAT_TYPE.DamageDone, m.buildSession{ count = 3 })

    NS2.Perf.Suspend()
    -- A window created while the capture is suspended.
    local created = NS2.Database.NextWindowId()
    local windows = NS2.Database.GetWindows()
    windows[#windows + 1] = NS2.DefaultWindow(created, "MadeWhileSuspended")

    NS2.Perf.Resume()
    assertFalse(NS2.Perf.suspended)
    assertFalse(NS2.Provider.IsSuspended())

    m.resetMeterCalls()
    local column = NS2.Provider.GetColumn(Const.SESSION_TYPE.Current, "DamageDone")
    assertNil(column.reason, "reads must work again after resume")
    assertEqual(#column.sources, 3)

    local ok = NS2.ShouldShow(NS2.Database.FindWindow(created))
    assertTrue(ok, "a window created while suspended must be showable after resume")
end)

test("PerfSetup: suspend and resume are idempotent", function()
    -- The library guards the second call, and the modules guard theirs too. A
    -- double resume that re-ran Provider:OnEnable would register the same
    -- subscription twice.
    local inst = enabled()
    local NS2 = inst.NS
    assertTrue(NS2.Perf.Suspend())
    assertFalse(NS2.Perf.Suspend(), "a second suspend must report that it did nothing")
    assertTrue(NS2.Perf.Resume())
    assertFalse(NS2.Perf.Resume())
    assertFalse(NS2.Provider.IsSuspended())
end)

test("PerfSetup: the descriptor resolves its modules at CALL time", function()
    -- core/PerfSetup.lua loads before modules/, so a load-time lookup would
    -- answer nil forever and suspend would silently do nothing at all — the
    -- worst possible failure for a harness whose whole output is a comparison
    -- against an inert addon.
    -- red under: hoisting `local Provider = NS.Provider` to file scope.
    local fh = assert(io.open(ROOT .. "/core/PerfSetup.lua", "r"))
    local src = fh:read("*a"):gsub("%-%-[^\r\n]*", "")
    fh:close()
    assertNil(src:match("[\r\n]local%s+Provider%s*="), "the descriptor hoisted a module reference")
    assertNil(src:match("[\r\n]local%s+WindowManager%s*="))
    assertTrue(src:find('mod("Provider")', 1, true) ~= nil)
    assertTrue(src:find('mod("WindowManager")', 1, true) ~= nil)
    assertTrue(src:find('mod("Visibility")', 1, true) ~= nil)
end)

-- ── the degraded seam ───────────────────────────────────────────────────────

test("PerfSetup: with LibKa0s absent the stub answers every member the addon reaches", function()
    -- Proved by a real load with the library gone, not by hand-stubbing the
    -- member under test (testing-§8). A stub that omits a member is not a
    -- fallback — it is a crash moved to a rarer code path.
    local inst = T.load{ libFiles = {} }
    local P = inst.NS.Perf
    assertTrue(P ~= nil, "NS.Perf must exist even with no library")
    assertEqual(P.on, false, "the gate must be a plain false, so every bracket short-circuits")
    assertEqual(P.suspended, false, "the show ladder reads this as step 0 on both paths")
    for _, member in ipairs({ "Note", "Open", "Close", "OnCommand" }) do
        assertEqual(type(P[member]), "function", "the stub omits " .. member)
    end
    P.Note("refresh", 1.5)   -- must not raise
    P.Open("refresh")
    P.Close("refresh")
end)

test("PerfSetup: the degraded `/mm perf` answers with the shared cause and its own consequence",
function()
    -- `/mm perf` is registered unconditionally in settings/Slash.lua, so
    -- something has to answer it. The cause half is core/CoreSetup.lua's shared
    -- clause; only the consequence is this seam's.
    local inst = T.load{ libFiles = {} }
    local lines = inst.NS.Perf.OnCommand("start")
    assertEqual(type(lines), "table")
    assertTrue(#lines > 0, "the degraded perf command said nothing at all")
    local text = table.concat(lines, " ")
    assertTrue(text:find(inst.NS.LIBKA0S_MISSING, 1, true) ~= nil,
        "the degraded answer does not carry the shared cause clause")
    assertTrue(text:find("performance measurement is unavailable", 1, true) ~= nil,
        "the degraded answer does not name its own consequence")
end)

-- ── the capture ring's retention prune (Perf minor 11) ──────────────────────

test("PerfSetup: a save past the ring's cap says what it dropped, in the console", function()
    -- debug-logging-§8: a retention prune is traced. The library writes the line
    -- (Perf minor 11); what this addon owns is that its `log` seam delivers it,
    -- with debug logging OFF, exactly as every other perf line is delivered.
    -- red under: a descriptor `log` that drops lines, or gates them on the flag.
    local inst = T.load{}
    assertFalse(inst.NS.State.debug, "the fixture needs the flag OFF")
    local lib = inst.mocks.LibStub("LibKa0s-Perf-1.0")
    local runs = {}
    for i = 1, lib.DEFAULT_RING do runs[i] = { label = "old" .. i } end
    _G.MultiMetersPerfDB = { schema = lib.SCHEMA, runs = runs }

    inst.NS.Perf.Save({ label = "new" })

    assertEqual(#_G.MultiMetersPerfDB.runs, lib.DEFAULT_RING, "the ring kept its size")
    local found = inst.NS.DebugLog:FindLine("perf ring at its cap")
    assertTrue(found ~= nil, "the prune left no line in the console")
    assertTrue(found:find("dropped 1 oldest", 1, true) ~= nil, "got: " .. tostring(found))
    _G.MultiMetersPerfDB = nil
end)
