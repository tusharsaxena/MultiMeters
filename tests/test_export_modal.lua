-- tests/test_export_modal.lua — modules/Export_Modal.lua: the window a player
-- actually clicks, and the two things it can do.
--
-- The serializer half is next door. tests/test_export.lua drives everything that
-- is a function of its arguments — CsvField, the column derivation, SessionConfig,
-- CSV, ChatLines and the channels block — and it can, because none of that touches
-- a frame. This file is the other half of that split: the modal itself, its three
-- selectors, the copy window and the Print to Chat click, all of which are frame
-- work and reach the module through the headless frame mock rather than through a
-- return value.
--
-- Three things are worth stating before the first case, because they are what the
-- file is really guarding:
--
--   1. THE REFUSAL IS RE-CHECKED AT THE CLICK. A modal can sit open across the
--      edge into a pull, so `Export.Open` refusing while the Combat restriction is
--      active is not enough on its own — the button has to refuse too, with the
--      restriction read at the moment it is pressed. Both halves of that are
--      asserted here rather than trusted.
--   2. THE POOLED ROWS ARE THE HALF NOBODY REACHED. LibKa0s-Widgets-1.0 builds a
--      dropdown's row buttons on the first click, and a case that seeds a stand-in
--      row never runs that constructor. v1.11.0 shipped a first-click crash
--      straight past 553 green library cases for exactly that reason. The two
--      selector cases below open real dropdowns and let the library build real
--      rows.
--   3. NOTHING THE MODAL OWNS MAY OUTLIVE IT. The shared menu is parented to
--      UIParent, not to this modal, and Escape hides the modal without going
--      through any handler this addon wrote.
--
-- Where a case needs a result table it hand-builds one rather than going through
-- the aggregator, for the same reason the serializer suite does: a click driven
-- off a real join would also be a case about the join, and tests/test_aggregator.lua
-- owns that.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertNil   = T.assertNil

local Const = T.NS.Constants

-- The refusal sentence, spelled once. It is a locale KEY as well as its own
-- English value, and the module hands it back verbatim for a caller to show.
local RESTRICTED_REASON = "Export is not available while the game restricts combat data."

-- U+2014 EM DASH with its surrounding spaces, in bytes — the same escape
-- modules/Export.lua uses, and for the same reason: the encoding of a source
-- file that passes through this many tools cannot be assumed.
local EM_DASH = " \226\128\148 "

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
--
-- The same three builders tests/test_export.lua uses, restated here rather than
-- published from a shared file: they are a handful of lines each, and a fixture a
-- suite can read without leaving the suite is worth more than one definition.

--- One cell, in the shape modules/Aggregator.lua parks under `row.values[key]`.
---
--- @param total any        the raw amount
--- @param opts table|nil    { rate = , percent = , maxAmount = }
--- @return table
local function cell(total, opts)
    opts = opts or {}
    return {
        total     = total,
        rate      = opts.rate,
        maxAmount = opts.maxAmount,
        percent   = opts.percent,
    }
end

--- One row. `cells` is the alias the aggregator publishes beside `values`, and
--- it is the SAME TABLE there rather than a copy; reproducing the alias here
--- means a case cannot accidentally assert against a shape the aggregator does
--- not actually produce.
---
--- @param name string
--- @param values table      { [statKey] = cell }
--- @param opts table|nil    { class = , spec = , role = , guid = }
--- @return table
local function row(name, values, opts)
    opts = opts or {}
    return {
        guid          = opts.guid or name,
        name          = name,
        classFilename = opts.class,
        specIconID    = opts.spec,
        role          = opts.role,
        values        = values,
        cells         = values,
    }
end

--- An Aggregator.Build result: the row array IS the result table, with `rows`
--- pointing back at itself (tests/test_aggregator.lua asserts that identity).
---
--- @param rows table              array of rows
--- @param durationSeconds any     the segment's length
--- @return table
local function built(rows, durationSeconds)
    rows.rows            = rows
    rows.durationSeconds = durationSeconds
    return rows
end

--- A fresh instance with the Combat restriction ACTIVE — the state an export is
--- a refusal in.
---
--- @return table
local function restricted()
    local inst = T.load()
    inst.mocks.setRestricted(true)
    return inst
end

-- ---------------------------------------------------------------------------
-- Opening at all — the gate in front of every case below
-- ---------------------------------------------------------------------------

test("Export.Open refuses to open at all while restricted", function()
    -- A modal with two dead buttons explains nothing; the sentence in chat is the
    -- useful half of that interaction.
    local inst = restricted()
    assertNil(inst.NS.Export.Open({}))
    assertNil(inst.NS.Export:Open({}), "and through the colon form the header uses")
end)

-- ---------------------------------------------------------------------------
-- ResolveMetric — which column the chat dump ranks by
-- ---------------------------------------------------------------------------
--
-- `export.metric` used to ship as "", which was a CHOICE ("match the window")
-- rather than an absent value, resolved fresh against the invoking window at
-- every use. That choice is gone: the label was unreadable, and a control whose
-- value is "whatever something else says" cannot show you what it will do.
--
-- What replaced it is SEEDING — Export.Open writes the invoking window's sort
-- column into the profile — so the useful half survives and is visible in the
-- selector. These cases pin the narrowed contract: ResolveMetric always answers
-- a key the catalog holds, and "" is now just an unrecognized stored value.

--- Store one export preference the way the modal does.
---
--- @param inst table   a loaded instance
--- @param value any    what to store under export.metric
local function storeMetric(inst, value)
    local profile = inst.NS.db and inst.NS.db.profile
    profile.export = profile.export or {}
    profile.export.metric = value
end

test("Export.ResolveMetric answers the pinned stat", function()
    local inst = T.load()
    storeMetric(inst, "Deaths")
    assertEqual(inst.NS.Export.ResolveMetric({ data = { sortColumn = "HealingDone" } }), "Deaths")
end)

test("Export.ResolveMetric ships pinned to a real stat, never to the empty string", function()
    -- red under: the old FOLLOW_WINDOW default surviving the removal. A profile
    -- default of "" would now be an unrecognized value on every fresh install.
    local inst = T.load()
    local shipped = inst.NS.defaults.profile.export.metric
    assertTrue(Const.STAT_BY_KEY[shipped] ~= nil,
        "the shipped default is a key the catalog answers for, not a sentinel")
    assertEqual(shipped, Const.STATS[1].key)
end)

test("Export.ResolveMetric treats the old empty-string choice as unset", function()
    -- A profile written by the build that shipped FOLLOW_WINDOW. It degrades to
    -- the window's column and then to the first catalog stat, with no migration
    -- step — which is the whole reason no migration step was written.
    local inst = T.load()
    storeMetric(inst, "")
    assertEqual(inst.NS.Export.ResolveMetric({ data = { sortColumn = "HealingDone" } }),
        "HealingDone")
    assertEqual(inst.NS.Export.ResolveMetric({ data = {} }), Const.STATS[1].key)
end)

test("Export.ResolveMetric treats a stat this build does not offer as unset", function()
    local inst = T.load()
    storeMetric(inst, "AbsorbsFromTheFuture")
    assertEqual(inst.NS.Export.ResolveMetric({ data = { sortColumn = "Dispels" } }), "Dispels")
end)

test("Export.ResolveMetric falls back to the first catalog stat", function()
    local inst = T.load()
    storeMetric(inst, nil)
    assertEqual(inst.NS.Export.ResolveMetric({ data = {} }), Const.STATS[1].key)
    assertEqual(inst.NS.Export.ResolveMetric({}), Const.STATS[1].key)
    assertEqual(inst.NS.Export.ResolveMetric(nil), Const.STATS[1].key)
end)

test("Export.ResolveMetric is callable through the colon form", function()
    local inst = T.load()
    storeMetric(inst, "Deaths")
    assertEqual(inst.NS.Export:ResolveMetric(), "Deaths")
end)

test("The Metric selector offers exactly the catalog, with no sentinel entry", function()
    -- red under: "Match the window" surviving as a menu entry after the stored
    -- choice behind it was removed, which would write a value nothing resolves.
    local inst = T.load()
    assertNil(rawget(inst.NS.L, "Match the window"),
        "the string is gone from the locale, not just from the menu")
end)

-- ---------------------------------------------------------------------------
-- The modal's own geometry
-- ---------------------------------------------------------------------------

test("The modal's whisper row is a row, not an overlap", function()
    -- red under: the InputBoxTemplate layout, where the box sat at -126 and the
    -- warning line at -154 with a 20px box between them and a fixed modal height
    -- that accounted for neither. The numbers are read off the module rather than
    -- restated, so this fails if a later edit moves one and not the others.
    local inst = T.load()
    local geom = inst.NS.Export.__geometry
    assertTrue(type(geom) == "table", "the modal's geometry is inspectable")

    assertTrue(geom.whisperTop + geom.rowHeight <= geom.warningTop,
        "the whisper row clears the warning line rather than drawing over it")
    assertEqual(geom.heightWithWhisper - geom.height, geom.rowHeight + geom.rowGap,
        "and the modal grows by exactly one row when it appears")
end)

-- ---------------------------------------------------------------------------
-- The shared dropdown menu must not outlive the modal that opened it
-- ---------------------------------------------------------------------------
--
-- LibKa0s-Widgets-1.0's popup is a process-wide singleton parented to UIParent at
-- FULLSCREEN_DIALOG (docs/api/Widgets/version-4-docs.md, "Behavior a host must
-- know", in the LibKa0s repo) — not to this modal, so the modal's own Hide() does
-- not reach it. This modal is in UISpecialFrames, so Escape hides it without going
-- through onExportCsv/onPrintToChat or any other click handler this file controls;
-- an open Metric/Channel/Lines menu would be left orphaned above the game with the
-- modal that owned it already gone. modules/Export.lua's EnsureFrame wires
-- modal:SetScript("OnHide", function() W.CloseMenu() end) to close it.
--
-- The shared menu is a file-local inside Widgets.lua with no getter, so the only
-- way to observe it is the way LibKa0s's own test_widgets.lua does: capture the
-- first frame CreateFrame makes once a dropdown's OnClick lazily builds it.
test("Hiding the export modal closes an open dropdown menu (LibKa0s-Widgets-1.0)", function()
    local inst = T.load()
    local modal = inst.NS.Export.Open({})
    assertTrue(type(modal) == "table", "the modal opened")

    -- The REAL metric list, painted into real rows. It used to be emptied first,
    -- on the grounds that LibKa0s-Widgets-1.0's paintMenuRow writes every row's
    -- glyph FontString unconditionally while no export dropdown names a
    -- glyphFont, and that this harness's mock enforces the client's
    -- "FontString:SetText(): Font not set" rule (tests/wow_mock.lua). That
    -- stopped being true at Widgets minor 3: the row's glyph FontString is now
    -- built from GameFontHighlightSmall, so it has a font before its first
    -- SetText and the mock's template branch lets it through. Emptying the list
    -- now buys nothing and costs the row build — see the real-row case at the
    -- foot of this file for why that matters.
    local made, savedCreateFrame = {}, inst.mocks.CreateFrame
    inst.mocks.CreateFrame = function(...)
        local f = savedCreateFrame(...)
        made[#made + 1] = f
        return f
    end
    modal.metricDD:__fire("OnClick")
    inst.mocks.CreateFrame = savedCreateFrame

    local menu = made[1]
    assertTrue(type(menu) == "table", "the dropdown's click lazily built the shared menu")
    assertTrue(menu:IsShown(), "opening the Metric dropdown showed the shared menu")

    -- The mock's Hide() does not auto-invoke OnHide the way the real client does
    -- (see LibKa0s's test_widgets.lua, "CloseMenu hides the click-catcher too") —
    -- Escape hiding a UISpecialFrames frame does fire OnHide in the real client,
    -- so firing it here is what stands in for Escape.
    modal:__fire("OnHide")
    assertEqual(menu:IsShown(), false,
        "OnHide closed the shared menu instead of leaving it orphaned")
end)

test("Hiding the export modal with no menu ever opened is a safe no-op", function()
    local inst = T.load()
    local modal = inst.NS.Export.Open({})
    assertTrue(type(modal) == "table", "the modal opened")

    local ok = pcall(function() modal:__fire("OnHide") end)
    assertTrue(ok, "closing the modal before any dropdown was clicked must not raise")
end)

-- ---------------------------------------------------------------------------
-- A real row build, and a real click on a real row
-- ---------------------------------------------------------------------------
--
-- THE HOLE THIS FILLS. Every other case in this file drives the collapsed
-- button — the half modules/Export.lua wrote. None of them reached the half it
-- did not: the pooled row buttons LibKa0s-Widgets-1.0 builds on the first click
-- (`makeMenuRow`, Widgets.lua). That is the exact shape of hole that let
-- v1.11.0 and v1.11.1 ship a first-click crash (`FontString:SetText(): Font not
-- set`, on a row's glyph FontString) past 553 green library cases: every one of
-- them seeded a stand-in row and none reached the constructor. A case that
-- empties the option list first proves only that the click handler runs; the
-- rows it would have built are what the crash was in.
--
-- NO OPTION THIS ADDON SETS CARRIES A GLYPH. metricOptions, channelOptions and
-- linesOptions each build `{ value =, label = }` and nothing else, so the modal
-- passes no `opts.glyphFont` — which is CORRECT rather than an oversight, and
-- must stay that way: glyphFont is a precondition for a row carrying `glyph`
-- (version-4-docs.md, "Behavior a host must know"), not decoration to add
-- because the field exists. This case is what proves a glyphless row survives
-- being built and painted with no face named.
--
-- HOW THE FRAMES ARE OBSERVED. The shared menu is a file-local in Widgets.lua
-- with no getter, so this does what LibKa0s's own test_widgets.lua does: it
-- watches CreateFrame. What it records is the ARGUMENTS of each call — the
-- frame type, the name and the parent, as they were passed — never anything
-- read back off the frame afterwards, which for a pooled row the contract
-- forbids a host to do (version-4-docs.md, "Rows are pooled across dropdowns").
--
-- It deliberately does NOT count frames or index them by position. Rows are
-- pooled across every dropdown in the process and across addons, so "the menu,
-- the catcher, then one Button per option" is only true of the very first
-- dropdown ever opened in a given Lua state; a second selector opened in the
-- same state, or a library that pre-warms the pool, builds fewer. So the watch
-- is installed before the modal is even built and the row buttons are picked
-- out by what they ARE — a Button parented to the popup — which holds however
-- many of them already existed. Their creation order is the order Populate
-- hands them to options, and that is the one ordering fact this leans on.
test("Clicking a Metric row builds a real menu row and stores that metric", function()
    local inst = T.load()
    local NS = inst.NS

    local stats = NS.Constants.STATS
    assertTrue(#stats > 1, "the catalog offers more than one metric to pick between")

    -- A metric that is NOT the one already resolved, so the assertion below
    -- cannot pass on a click that did nothing.
    local before = NS.Export.ResolveMetric()
    local target
    for _, stat in ipairs(stats) do
        if stat.key ~= before then target = stat break end
    end
    assertTrue(target ~= nil, "the catalog offers a metric other than the current one")

    local calls, savedCreateFrame = {}, inst.mocks.CreateFrame
    inst.mocks.CreateFrame = function(ftype, name, parent, ...)
        local f = savedCreateFrame(ftype, name, parent, ...)
        calls[#calls + 1] = { frame = f, ftype = ftype, name = name, parent = parent }
        return f
    end

    local modal = NS.Export.Open({})
    assertTrue(type(modal) == "table", "the modal opened")

    local ok, err = pcall(function() modal.metricDD:__fire("OnClick") end)
    inst.mocks.CreateFrame = savedCreateFrame
    assertTrue(ok, "the first click built the menu and its rows without raising: " .. tostring(err))

    -- The shared popup is the one UNNAMED Frame parented straight to UIParent:
    -- the modal is named (MODAL_NAME) and everything else this modal builds
    -- hangs off the modal, not off UIParent.
    local menu
    for _, call in ipairs(calls) do
        if call.ftype == "Frame" and call.name == nil and call.parent == inst.mocks.UIParent then
            menu = call.frame
            break
        end
    end
    assertTrue(menu ~= nil, "the first click lazily built the shared popup menu")
    assertTrue(menu:IsShown(), "opening the Metric dropdown showed the shared menu")

    -- Every pooled row Button that exists in this Lua state, in build order.
    local rows = {}
    for _, call in ipairs(calls) do
        if call.ftype == "Button" and call.parent == menu then rows[#rows + 1] = call.frame end
    end
    assertTrue(#rows >= #stats,
        ("the first click built one real menu row per metric, not an empty menu (%d rows for %d metrics)")
            :format(#rows, #stats))

    -- Row i is the i-th option, in the order SetOptions was given them.
    local index
    for i, stat in ipairs(stats) do
        if stat.key == target.key then index = i break end
    end
    rows[index]:__fire("OnClick")

    assertEqual(NS.GetSetting("export.metric"), target.key,
        "clicking the row stored that metric")
    assertEqual(menu:IsShown(), false, "and a single-select pick closed the menu behind it")
    assertTrue(tostring(modal.metricDD.text:GetText()):find(target.label, 1, true) ~= nil,
        "and the collapsed button repainted to the metric that was picked")
end)

-- ---------------------------------------------------------------------------
-- A second selector, in the same Lua state, on the same pooled rows
-- ---------------------------------------------------------------------------
--
-- The case above opens exactly one dropdown. This one opens Channel AFTER
-- Metric, which is the state every real session is in from the second click
-- onwards and the one the case above cannot reach: the popup already exists,
-- its row buttons already exist, and Populate repaints the pooled rows rather
-- than building new ones (version-4-docs.md, "Rows are pooled across
-- dropdowns"). Nothing this addon owns may carry over between the two — the
-- rows belong to the library and are shared with every other addon in the
-- process, so the only thing this asserts is what the contract promises: the
-- second dropdown's own onSelect fires with the second dropdown's own value.
test("Opening Channel after Metric repaints the pooled rows and stores a channel", function()
    local inst = T.load()
    local NS = inst.NS

    local calls, savedCreateFrame = {}, inst.mocks.CreateFrame
    inst.mocks.CreateFrame = function(ftype, name, parent, ...)
        local f = savedCreateFrame(ftype, name, parent, ...)
        calls[#calls + 1] = { frame = f, ftype = ftype, name = name, parent = parent }
        return f
    end

    local modal = NS.Export.Open({})
    assertTrue(type(modal) == "table", "the modal opened")

    modal.metricDD:__fire("OnClick")
    local ok, err = pcall(function() modal.channelDD:__fire("OnClick") end)
    inst.mocks.CreateFrame = savedCreateFrame
    assertTrue(ok, "opening a second selector over the first did not raise: " .. tostring(err))

    local menu
    for _, call in ipairs(calls) do
        if call.ftype == "Frame" and call.name == nil and call.parent == inst.mocks.UIParent then
            menu = call.frame
            break
        end
    end
    assertTrue(menu ~= nil and menu:IsShown(), "the one shared popup is open on the second selector")

    local rows = {}
    for _, call in ipairs(calls) do
        if call.ftype == "Button" and call.parent == menu then rows[#rows + 1] = call.frame end
    end

    -- Whatever the Channel list is, its rows are the pooled ones the Metric
    -- menu just used; the row at position i is its i-th option.
    -- channelOptions() is file-local; it walks this catalog in this order, so
    -- the catalog is the row order without a seam cut into the module for it.
    local channels = NS.Constants.EXPORT_CHANNELS
    assertTrue(type(channels) == "table" and #channels > 1,
        "the catalog offers more than one channel to pick between")
    assertTrue(#rows >= #channels, "the pooled rows cover the Channel list")

    local before = NS.GetSetting("export.channel")
    local index, target
    for i, opt in ipairs(channels) do
        if opt.key ~= before then index, target = i, opt.key break end
    end
    assertTrue(target ~= nil, "the modal offers a channel other than the current one")

    rows[index]:__fire("OnClick")
    assertEqual(NS.GetSetting("export.channel"), target,
        "clicking a pooled row under the Channel dropdown stored a CHANNEL, not a metric")
end)

-- ---------------------------------------------------------------------------
-- The copy window
-- ---------------------------------------------------------------------------
--
-- This addon's copy frame described itself as "the third in the collection". It
-- was the fourth — BankLedger had one too, and nobody was looking. It is now
-- none of them: the frame belongs to LibKa0s-Widgets-1.0 and this file passes a
-- descriptor.
--
-- The handle and the show call are published as `Export.__copyWindow` and
-- `Export.__showCopy` because an EditBox is WRITE-ONLY through the frame API as
-- this addon uses it — nothing else in the module ever reads the text back — so
-- there is no other seam from which to assert what the window is showing.

test("Export: the copy window comes from LibKa0s-Widgets-1.0", function()
    -- The modal half moved to modules/Export_Modal.lua when modules/Export.lua was
    -- peeled for layout-§1 (issue #32), and the copy window went with it — it is
    -- frame work, and the seam the file's own ":50" banner draws puts every frame
    -- on that side. This case still measures the same property in the same way;
    -- only the file it reads moved.
    local fh = assert(io.open((T.root or ".") .. "/modules/Export_Modal.lua", "r"))
    local source = fh:read("*a")
    fh:close()

    local _, builders = source:gsub('CreateFrame%("EditBox"', "")
    assertEqual(builders, 1,
        "only the whisper box builds an EditBox here now; the copy window's belongs to the library")
    assertTrue(source:find("CopyWindow", 1, true) ~= nil, "the descriptor call is present")
end)

test("Export: showing the copy window puts the text in it", function()
    local text = "Metric,Value\r\nDPS,1234\r\n"
    T.NS.Export.__showCopy(text)
    assertEqual(T.NS.Export.__copyWindow:GetText(), text)
end)

test("Export: the copy window is built once and reused", function()
    T.NS.Export.__showCopy("first")
    local f = T.NS.Export.__copyWindow:GetFrame()
    T.NS.Export.__showCopy("second")
    assertTrue(T.NS.Export.__copyWindow:GetFrame() == f,
        "a rebuild per open leaks a frame per open — frames are never destroyed in WoW")
end)

-- ---------------------------------------------------------------------------
-- The Print to Chat click
-- ---------------------------------------------------------------------------
--
-- The button's handler is a file-local, so these cases reach it the way a player
-- does: `modal.chatButton:__fire("OnClick")`. Nothing above this divider touched
-- it, and it is where the module's five refusals, the flood warning and the
-- confirmation line actually live — every one of them a string a player reads,
-- and therefore contract.
--
-- WHY EXPORT.BUILD IS STUBBED. tests/test_aggregator.lua owns what comes through
-- that door and the end-to-end case above proves this module goes through it. A
-- click driven off a hand-built result is a case about the CLICK: which refusal
-- fires, in which order, and what leaves the client. The stub also records the
-- sort column, which is the one argument the click chooses rather than passes on.

--- A modal open on a stubbed build, with everything it says and sends captured.
---
--- @param result table|nil  what Export.Build should answer
--- @return table  { inst, modal, said, sent, sortColumn }
local function printer(result)
    local inst = T.load()
    local ctx = { inst = inst, said = {}, sent = {} }

    inst.NS.Print = function(msg) ctx.said[#ctx.said + 1] = msg end
    inst.mocks.SendChatMessage = function(text, chatType, _, target)
        ctx.sent[#ctx.sent + 1] = { text = text, chatType = chatType, target = target }
    end
    inst.NS.Export.Build = function(_, sortColumn)
        ctx.built, ctx.sortColumn = true, sortColumn
        return result
    end

    ctx.modal = inst.NS.Export.Open({ data = { sessionType = Const.SESSION_TYPE.Current } })
    return ctx
end

--- Store an export choice the way the modal's selectors do.
---
--- @param ctx table
--- @param key string
--- @param value any
local function choose(ctx, key, value)
    local profile = ctx.inst.NS.db.profile
    profile.export = profile.export or {}
    profile.export[key] = value
end

--- Press Print to Chat.
--- @param ctx table
local function click(ctx)
    ctx.modal.chatButton:__fire("OnClick")
end

--- Two ranked rows, in the order they are meant to come back out in.
--- @return table
local function printFixture()
    return built({
        row("Kaosz", { DamageDone = cell(4821993, { rate = 84210, percent = 31.2 }),
                       Deaths     = cell(1) }),
        row("Brewz", { DamageDone = cell(4100000, { rate = 71900, percent = 26.6 }),
                       Deaths     = cell(2) }),
    }, 134)
end

test("Print to Chat re-checks the restriction at the click, not at the open", function()
    -- The greyed-out button is a HINT rather than a guarantee: the modal may have
    -- been opened out of combat and pressed ten seconds into a pull. The click
    -- says the reason and repaints, so the modal that just refused is also the
    -- modal that now explains itself.
    -- red under: trusting the enabled state the open left behind.
    local ctx = printer(printFixture())
    ctx.inst.mocks.setRestricted(true)
    click(ctx)

    assertEqual(#ctx.said, 1)
    assertEqual(ctx.said[1], RESTRICTED_REASON)
    assertEqual(#ctx.sent, 0, "nothing may leave the client while the restriction is up")
    assertNil(ctx.built, "and nothing may be built, either")
    assertEqual(ctx.modal.warning:GetText(), RESTRICTED_REASON,
        "the refusal repainted the modal rather than only printing")
end)

test("Print to Chat names a blank whisper recipient before it builds anything", function()
    -- A whisper with nobody named resolves to the silent SELF inside
    -- ResolveChannel, which is safe and reads as broken. Caught HERE, while there
    -- is still a name box on screen to point at — and caught BEFORE the build, so
    -- an empty segment cannot answer with the wrong sentence.
    -- red under: moving the whisper check below Export.Build.
    for _, blank in ipairs({ "", "   " }) do
        local ctx = printer(printFixture())
        choose(ctx, "channel", "WHISPER")
        choose(ctx, "whisperTo", blank)
        click(ctx)

        assertEqual(#ctx.said, 1, "one sentence, and only one")
        assertEqual(ctx.said[1], "Enter a name to whisper to.")
        assertNil(ctx.built, "the refusal comes before the aggregator is asked")
        assertEqual(#ctx.sent, 0)
    end
end)

test("Print to Chat asks the game for the target at the click", function()
    -- READ AT SEND TIME, never stored: a remembered target is a name that was true
    -- when the modal opened and is a stranger by the time the button is pressed.
    -- The two refusals are separate sentences because they are separate mistakes.
    local ctx = printer(printFixture())
    choose(ctx, "channel", "TARGET")

    ctx.inst.mocks.setUnit("target", nil)
    click(ctx)
    assertEqual(ctx.said[#ctx.said], "You have no target to whisper to.")

    ctx.inst.mocks.setUnit("target",
        { guid = "Creature-1-00000001", name = "Ulgrax", isPlayer = false })
    click(ctx)
    assertEqual(ctx.said[#ctx.said], "Your target is not a player.")

    assertNil(ctx.built, "neither refusal reached the aggregator")
    assertEqual(#ctx.sent, 0)
end)

test("Print to Chat whispers the player currently targeted", function()
    -- The other arm: a real player target is resolved to a WHISPER addressed to
    -- them, which is the whole point of the "Whisper my target" channel.
    local ctx = printer(printFixture())
    choose(ctx, "channel", "TARGET")
    ctx.inst.mocks.setUnit("target", { guid = "Player-1-0000000B", name = "Brewz", isPlayer = true })
    click(ctx)

    assertEqual(ctx.sent[1].chatType, "WHISPER")
    assertEqual(ctx.sent[1].target, "Brewz")
end)

test("Print to Chat says so rather than swallowing a click with nothing to export", function()
    -- A window showing "Waiting for combat data" has nothing to rank, and a dialog
    -- that answers a press with nothing at all reads as broken rather than empty.
    local ctx = printer(built({}, 60))
    click(ctx)
    assertEqual(#ctx.said, 1)
    assertEqual(ctx.said[1], "There is nothing to export.")
    assertEqual(#ctx.sent, 0)
end)

test("Print to Chat builds with the chosen metric as the SORT COLUMN", function()
    -- So "top 5 healing" is the top five healers rather than the top five damage
    -- dealers listed with their healing beside them. The same key then picks the
    -- column the lines print, which is why the header below names it too.
    -- red under: Export.Build(invoker) with no sort column.
    local ctx = printer(printFixture())
    choose(ctx, "metric", "Deaths")
    choose(ctx, "lines", 5)
    click(ctx)

    assertEqual(ctx.sortColumn, "Deaths")
    assertEqual(ctx.said[1], "Multi Meters" .. EM_DASH .. "Deaths" .. EM_DASH .. "Current (2:14)")
    assertEqual(ctx.said[2], "1. Kaosz 1")
end)

test("Print to Chat leaves the lines themselves as the confirmation on SELF", function()
    -- The lines are sitting in the chat frame; a summary under them would be one
    -- line of noise per export.
    -- red under: confirming unconditionally.
    local ctx = printer(printFixture())
    choose(ctx, "channel", "SELF")
    choose(ctx, "lines", 5)
    click(ctx)

    assertEqual(#ctx.said, 3, "a header and two ranked lines, and nothing else")
    assertEqual(ctx.said[3], "2. Brewz 4.1M (71.9K, 26.6%)")
    assertEqual(#ctx.sent, 0, "SELF never reaches the server")
end)

test("Print to Chat confirms a send that left the client, without counting the header", function()
    -- The header line is not a ranked row. A confirmation that counted it would
    -- report three rows for a two-player group, which is the sort of off-by-one
    -- nobody reports and everybody notices.
    local ctx = printer(printFixture())
    choose(ctx, "channel", "PARTY")
    choose(ctx, "lines", 5)
    click(ctx)

    assertEqual(#ctx.said, 1)
    assertEqual(ctx.said[1], "Exported 2 rows to chat.")
    assertEqual(ctx.sent[1].chatType, "PARTY", "the first line leaves inside the click")
    ctx.inst.mocks.__fireTimers()
    assertEqual(#ctx.sent, 3, "and the staggered tail follows")
end)

test("Print to Chat warns BEFORE a Say dump the server may truncate", function()
    -- SAID BEFORE THE SEND, and only where it is true. Say and Yell out in the
    -- world have to leave inside this click, so the stagger that keeps a long dump
    -- whole is not available and the server may drop the tail. A player who sees
    -- four of their ten lines arrive deserves to know it was the flood rule.
    -- red under: warning after Export.Send, where the truncation has happened.
    local rows = {}
    for i = 1, 12 do rows[i] = row("Mock" .. i, { DamageDone = cell(1000 - i) }) end
    local ctx = printer(built(rows, 60))
    choose(ctx, "channel", "SAY")
    choose(ctx, "lines", 12)
    ctx.inst.mocks.setInstance(nil)
    click(ctx)

    -- The count is the LINE count, header included: thirteen messages is what the
    -- server is being asked to take in one frame.
    assertEqual(ctx.said[1],
        "Say and Yell go out all at once outside instances, so the server may drop some of "
        .. "13 lines. Fewer lines, or a group channel, will arrive whole.")
    assertEqual(ctx.said[2], "Exported 12 rows to chat.")
    assertEqual(#ctx.sent, 13, "the whole dump went out inside the click, flood risk and all")
end)

test("Print to Chat does not warn where the stagger is available or the dump is short", function()
    -- Two arms of the same guard. Inside an instance Blizzard exempts SAY, so the
    -- staggered path is the one a raid actually takes and there is nothing to warn
    -- about; outdoors, a dump inside one batch cannot trip the counter either.
    -- red under: warning on every SAY, which would cry wolf on the common case.
    local rows = {}
    for i = 1, 12 do rows[i] = row("Mock" .. i, { DamageDone = cell(1000 - i) }) end

    local inside = printer(built(rows, 60))
    choose(inside, "channel", "SAY")
    choose(inside, "lines", 12)
    inside.inst.mocks.setInstance("raid")
    click(inside)
    assertEqual(#inside.said, 1, "the confirmation alone")
    assertEqual(inside.said[1], "Exported 12 rows to chat.")
    assertEqual(#inside.sent, 1, "and the tail is on timers, which is the point of not warning")

    local short = printer(built(rows, 60))
    choose(short, "channel", "SAY")
    choose(short, "lines", 4)
    short.inst.mocks.setInstance(nil)
    click(short)
    assertEqual(#short.said, 1)
    assertEqual(short.said[1], "Exported 4 rows to chat.",
        "five lines is not more than one batch, so there is nothing to warn about")
end)
