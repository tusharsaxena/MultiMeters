-- tests/test_schema.lua
--
-- settings/Schema.lua is the row array itself, and settings/Schema_Compose.lua
-- the vocabularies, validators and composers that build it. So what this suite
-- asserts is what the schema DECLARES: which page a row is filed under, which
-- tab it sits in and in what order, that its label and its tab name are
-- localized rather than bare literals, that every colour swatch has its mode
-- beside it, that a group is contiguous so its heading prints once, and that
-- the two row decorations this addon deliberately ships OFF are still off.
--
-- The counts and orders below are WRITTEN OUT rather than derived from the
-- schema the assertion reads. A row that drifts into another tab, is renamed or
-- silently changes path is then a NAMED failure, instead of a shorter list that
-- still agrees with itself.
--
-- The plumbing underneath -- the window-relative path model, the single write
-- seam, and the columns carve-out that is written whole through it -- is
-- asserted next door in tests/test_schema_paths.lua.
--
-- Everything mutates, so every case builds its OWN instance through T.load()
-- rather than sharing one: a suite whose cases can only pass in the order they
-- happen to be declared in is a suite that will fail for the wrong reason later.

local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue, assertFalse = T.assertEqual, T.assertTrue, T.assertFalse

--- A loaded addon with TWO windows, and their ids.
local function twoWindows()
    local inst = T.load()
    local NS = inst.NS
    assertEqual(#NS.Database.GetWindows(), 1, "InitDB seeds exactly one window")
    assertTrue(NS.WindowManager:Create("Second"))
    local list = NS.Database.GetWindows()
    assertEqual(#list, 2)
    return inst, list[1].id, list[2].id
end

-- ---------------------------------------------------------------------------
-- The Frame page's shape
-- ---------------------------------------------------------------------------

test("Schema: a `hidden` row is writable and listable but draws no control", function()
    -- `frame.minimised` is per-window STATE, not a preference: the header's
    -- minimise control writes it and a window left collapsed comes back
    -- collapsed. As a checkbox it duplicated that control on a page you have to
    -- open to reach. It cannot simply be DELETED, though -- NS.SetByPath refuses
    -- a path with no row, and the minimise control writes through that seam
    -- precisely because it is what publishes CONFIG_CHANGED.
    -- red under: dropping the row, or dropping SchemaForPage's `hidden` filter.
    local inst = T.load()
    local NS = inst.NS

    local found
    for _, row in ipairs(NS.Schema) do
        if row.path == "window.frame.minimised" then found = row end
    end
    assertTrue(found ~= nil, "the path must still resolve, or minimise cannot write")
    assertEqual(found.hidden, true)

    for _, row in ipairs(NS.SchemaForPage("header")) do
        assertTrue(row.path ~= "window.frame.minimised",
            "a state row was rendered as a setting")
    end

    assertTrue((NS.SetByPath("window.frame.minimised", true)),
        "the seam must still accept it")
end)

test("Schema: the sort and the session type are hidden rows the seam validates (issue #50)", function()
    -- A column-header click and the segment menu CHOOSE these, so they are
    -- preferences (architecture-§5), not a remembered view: each has a row, the
    -- header controls write through NS.SetByPath, and `/mm set` reaches them by
    -- the same path. Hidden, because the control that sets each one is on the
    -- window itself, and a panel copy was a second place for the two to disagree.
    -- red under: no rows, or a row that takes a value its control never offers.
    local inst = T.load()
    local NS = inst.NS
    local Const = NS.Constants

    for _, path in ipairs({ "window.data.sessionType", "window.data.sortColumn",
                            "window.data.sortMode", "window.data.sortAscending" }) do
        local row = NS.FindSchemaRow(path)
        assertTrue(row ~= nil, path .. " has no row, so its control writes around the helper")
        assertTrue(row.hidden, path .. " is drawn on the panel")
    end

    assertTrue((NS.SetByPath("window.data.sortColumn", "HealingDone")))
    assertEqual(NS.GetSetting("window.data.sortColumn"), "HealingDone")
    assertFalse((NS.SetByPath("window.data.sortColumn", "NotAStat")), "a stat outside the catalog")
    assertFalse((NS.SetByPath("window.data.sortMode", "sideways")))
    assertFalse((NS.SetByPath("window.data.sortAscending", "yes")))
    assertTrue((NS.SetByPath("window.data.sessionType", Const.SESSION_TYPE.Current)))
    assertFalse((NS.SetByPath("window.data.sessionType", 42)), "a session type the menu never offers")
end)

test("Schema: a sort written from the CLI drops the frozen order, as a click does (issue #50)", function()
    -- The frozen order is a snapshot of the OLD sort. The click used to drop it
    -- itself; now the row does, so `/mm set` cannot leave a stale order behind.
    -- red under: the WipeCache call living only in SortByColumn.
    local inst = T.load()
    local NS = inst.NS
    local id = NS.Database.GetWindows()[1].id
    NS.State.Cache("Aggregator")[id] = { "Player-1-0000000A" }
    assertTrue((NS.SetByPath("window.data.sortColumn", "HealingDone", id)))
    assertTrue(NS.State.Cache("Aggregator")[id] == nil, "the frozen order survived the write")
end)

test("Schema: the export choices are hidden from the panel but NOT from the seam", function()
    -- The modal's own three controls are the ones a player uses, so a second
    -- copy on General was a settings group restating a control met elsewhere --
    -- and a second chance for the two to disagree about what is selected.
    --
    -- HIDDEN RATHER THAN DELETED, and the difference is which seam writes them:
    -- the modal writes through NS.SetByPath, which REFUSES a path with no row, so
    -- deleting these would drop every export choice onto the degraded fallback
    -- and take `/mm set export.channel` with it.
    -- red under: deleting the rows, or leaving one of the three visible.
    local inst = T.load()
    local NS = inst.NS

    for _, path in ipairs({ "export.channel", "export.whisperTo", "export.lines" }) do
        local row = NS.FindSchemaRow(path)
        assertTrue(row ~= nil, path .. " lost its row, and with it the write seam")
        assertTrue(row.hidden, path .. " is still drawn on the panel")
    end

    for _, row in ipairs(NS.SchemaForPage("general")) do
        assertTrue(row.path:find("^export%.") == nil,
            "an export row is still rendered on General: " .. row.path)
    end

    -- And the seam still takes a write, which is the whole reason they stayed.
    assertTrue(NS.SetByPath("export.channel", "PARTY"))
    assertEqual(NS.GetSetting("export.channel"), "PARTY")
end)

test("The meta colour mode sets every bar and header in the window at once", function()
    -- Seven surfaces each carry a colour mode of their own -- the bar and its
    -- background, both header strips, the column strip's background and both of
    -- the tooltip's bars -- which is right when a player wants one of them
    -- different and tedious when they want them all the same.
    --
    -- The title bar's BACKGROUND is deliberately not among them: it is one strip
    -- over the whole window, so a per-statistic mode could only paint it the sort
    -- column's colour, which is on screen twice already. It kept its colour
    -- picker and lost the dropdown.
    -- red under: a path dropped from COLOR_MODE_PATHS.
    local inst = T.load()
    local NS = inst.NS

    assertTrue(NS.SetByPath("window.colorMode", "stat"))

    for _, path in ipairs({
        "window.bars.colorMode", "window.bars.bgColorMode",
        "window.columnHeader.colorMode", "window.columnHeader.bgColorMode",
        "window.tooltip.barColorMode", "window.tooltip.barBgColorMode",
    }) do
        assertEqual(NS.GetSetting(path), "stat", path .. " did not follow the meta")
    end
end)

test("The meta colour mode leaves both TEXT surfaces alone", function()
    -- Text is drawn ON TOP OF a surface the meta broadcasts to. Sending "per
    -- statistic" to the whole window painted the Damage number in the Damage
    -- colour over a Damage-coloured bar, and the tooltip's text in the sorted
    -- stat's colour over bars already carrying it -- the one place where making
    -- every surface agree is what makes the text stop being readable.
    -- red under: window.text.colorMode or window.tooltip.colorMode back in
    -- COLOR_MODE_PATHS.
    local inst = T.load()
    local NS = inst.NS

    local before = {
        text    = NS.GetSetting("window.text.colorMode"),
        tooltip = NS.GetSetting("window.tooltip.colorMode"),
    }

    assertTrue(NS.SetByPath("window.colorMode", "stat"))

    assertEqual(NS.GetSetting("window.text.colorMode"), before.text,
        "the grid's numbers must not follow the meta onto the bars behind them")
    assertEqual(NS.GetSetting("window.tooltip.colorMode"), before.tooltip,
        "the tooltip's text must not follow the meta onto its own bars")

    -- Still its own setting, so a player who WANTS the match can ask for it.
    assertTrue(NS.SetByPath("window.text.colorMode", "stat"))
    assertEqual(NS.GetSetting("window.text.colorMode"), "stat")
end)

test("The other three meta rows broadcast their own kind of setting", function()
    -- Same bargain as the colour mode: the individual rows all still exist, and
    -- each meta sets every surface that has one of its kind.
    -- red under: a path dropped from any of the three lists.
    local inst = T.load()
    local NS = inst.NS
    inst.mocks.__media.statusbar["Ka0s Bar"] = "Interface\\Test\\Bar"
    inst.mocks.__media.font["Ka0s Font"] = "Interface\\Test\\Font"

    assertTrue(NS.SetByPath("window.barTexture", "Ka0s Bar"))
    assertEqual(NS.GetSetting("window.bars.texture"), "Ka0s Bar")
    assertEqual(NS.GetSetting("window.tooltip.barTexture"), "Ka0s Bar")

    assertTrue(NS.SetByPath("window.font", "Ka0s Font"))
    for _, path in ipairs({ "window.text.font", "window.header.font",
                            "window.columnHeader.font", "window.tooltip.font" }) do
        assertEqual(NS.GetSetting(path), "Ka0s Font", path .. " did not follow the meta")
    end

    assertTrue(NS.SetByPath("window.fontOutline", "THICKOUTLINE"))
    -- The tooltip's key is `fontOutline`, not `outline`, which is why the fan-out
    -- is a list of PATHS rather than a suffix assumed to be shared.
    for _, path in ipairs({ "window.text.outline", "window.header.outline",
                            "window.columnHeader.outline", "window.tooltip.fontOutline" }) do
        assertEqual(NS.GetSetting(path), "THICKOUTLINE", path .. " did not follow the meta")
    end
end)

test("A surface changed after the broadcast keeps its own answer", function()
    -- The meta is a SHORTCUT, not a source of truth: a player who then changes one
    -- surface has changed one surface, and the meta does not fight them for it.
    local inst = T.load()
    local NS = inst.NS

    NS.SetByPath("window.colorMode", "class")
    NS.SetByPath("window.text.colorMode", "custom")

    assertEqual(NS.GetSetting("window.text.colorMode"), "custom")
    assertEqual(NS.GetSetting("window.bars.colorMode"), "class",
        "changing one surface reached the others")
end)

test("The Frame page's Defaults button does NOT broadcast", function()
    -- A per-page reset walks that page's rows through ApplyDefault. The meta row
    -- lives on Frame and writes ten rows on three other pages, so a broadcast
    -- from there would make the Frame page's Defaults button silently reset
    -- settings it has no business reaching.
    -- red under: dropping the restore guard from broadcastColorMode.
    local inst = T.load()
    local NS = inst.NS

    NS.SetByPath("window.text.colorMode", "stat")
    NS.Helpers.RestoreDefaults("frame", nil)

    assertEqual(NS.GetSetting("window.text.colorMode"), "stat",
        "the Frame page's reset reached the Bars page")
    assertEqual(NS.GetSetting("window.colorMode"), "custom",
        "the meta itself must still be restored")
end)

-- ---------------------------------------------------------------------------
-- The page/tab partition
-- ---------------------------------------------------------------------------

--- Every page's tabs, in the order the strip draws them, and how many controls each holds.
--- Stated here rather than derived from the schema the assertion reads, so a row that drifts
--- into another tab is a NAMED failure rather than a shorter list that still agrees with
--- itself.
---
--- VISIBLE rows only, because NS.SchemaForPage filters `hidden` and this table describes what
--- the panel DRAWS. So General has no Export tab -- its three export rows are hidden -- and
--- the Header page's Controls counts eight, not the nine rows filed under it. The case below
--- this one is what keeps those hidden rows honest.
---
--- `Master controls` leads the General page and is options-ui-§15's canonical set:
--- enable, general visibility, master scale, master alpha, lock frame and the
--- debug console -- six rows, with the two resets drawn as a button pair rather
--- than as rows. The four counts that grew by one are the colour MODES
--- options-ui-§17 asked for beside the four swatches that had none (the window's
--- fill and its edge, a cell's bar outline, a tooltip bar's outline).
local PARTITION = {
    -- TEN on Master controls, not six: the canonical six, then this addon's own
    -- four appended after them. `General` was a tab of four rows -- a minimap
    -- toggle, two addon-wide data settings and Test mode -- sitting next to the
    -- tab everybody opens, and none of the four is a subject of its own. §15
    -- forbids reordering, renaming or splitting the canonical set; it does not
    -- forbid an addon's own rows after it, and the case below pins that the six
    -- come FIRST and contiguous.
    general    = { { "Master controls", 10 }, { "Statistic colors", 8 } },
    windows    = { { "Window", 1 } },
    frame      = { { "General", 6 }, { "Size and position", 6 },
                   { "Background and border", 6 }, { "Row", 8 } },
    header     = { { "Title bar", 8 }, { "Title text", 6 }, { "Controls", 8 },
                   { "Button style", 8 } },
    bars       = { { "Bar", 5 }, { "Background", 3 }, { "Border", 5 },
                   { "Text content", 5 }, { "Text style", 7 }, { "Icons", 3 } },
    tooltip    = { { "General", 5 }, { "Bar", 5 }, { "Bar background", 3 },
                   { "Bar border", 4 }, { "Text", 6 }, { "Contents", 7 } },
    visibility = { { "Where to show this window", 7 }, { "When to hide this window", 8 },
                   { "Combat", 2 } },
    columns    = { { "Header text", 6 }, { "Header background", 2 } },
}

test("Schema: every page's tabs are the designed ones, in order, at the designed size",
function()
    -- red under: moving a row to another tab, reordering a group, or letting a tab drift
    -- above six controls without the design saying so.
    local inst = T.load()
    local NS, L = inst.NS, inst.NS.L

    for page, expected in pairs(PARTITION) do
        local order, counts, seen = {}, {}, {}
        for _, row in ipairs(NS.SchemaForPage(page)) do
            local g = row.group or "?"
            if not seen[g] then
                seen[g] = true
                order[#order + 1] = g
            end
            counts[g] = (counts[g] or 0) + 1
        end

        local wantNames = {}
        for i, pair in ipairs(expected) do wantNames[i] = L[pair[1]] end
        assertEqual(table.concat(order, " | "), table.concat(wantNames, " | "),
            page .. ": tab order")

        for _, pair in ipairs(expected) do
            assertEqual(counts[L[pair[1]]], pair[2],
                page .. " / " .. pair[1] .. ": control count")
        end
    end
end)

-- ---------------------------------------------------------------------------
-- The Master controls tab (options-ui-§15)
-- ---------------------------------------------------------------------------

--- The canonical set, in the canonical order, with the stored path this addon
--- keeps for each. Written out here rather than derived from the schema the
--- assertion reads: a row that drifted, was renamed or silently changed path is
--- then a NAMED failure rather than a shorter list that still agrees with itself.
---
--- The two RESETS are absent because they are not rows: options-ui-§15 makes them
--- the tab's closing button pair, drawn by the hook the composer hands back
--- (settings/General.lua's afterMaster).
local MASTER_ROWS = {
    { "enabled",            "Enable Multi Meters" },
    { "master.visibility",  "General visibility"  },
    { "master.scale",       "Master scale"        },
    { "master.alpha",       "Master alpha"        },
    { "master.locked",      "Lock frame"          },
    { "state.debugConsole", "Debug console"       },
}

test("Schema: the General page opens on Master controls, holding exactly the canonical set",
function()
    -- options-ui-§15. The set is canonical, not a menu: an addon includes every row
    -- that applies to it and MUST NOT reorder them, rename them, or split them
    -- across tabs.
    -- The canonical rows are the tab's FIRST rows, contiguous and in order. This
    -- addon's own four follow them -- §15 forbids reordering, renaming and
    -- splitting the set, not appending after it -- so the assertion is on the
    -- PREFIX rather than on the whole tab, and the extras are pinned separately
    -- below.
    -- red under: renaming the group, moving it below another tab, dropping a
    -- canonical row, reordering them, or INTERLEAVING one of this addon's own
    -- rows among them.
    local inst = T.load()
    local NS, L = inst.NS, inst.NS.L

    local rows = NS.SchemaForPage("general")
    assertEqual(rows[1].group, L["Master controls"], "the first tab of the General page")

    local got = {}
    for _, row in ipairs(rows) do
        if row.group == L["Master controls"] then
            got[#got + 1] = row.path .. " = " .. tostring(row.label)
        end
    end

    local want = {}
    for i, pair in ipairs(MASTER_ROWS) do want[i] = pair[1] .. " = " .. L[pair[2]] end
    local prefix = {}
    for i = 1, #want do prefix[i] = got[i] end
    assertEqual(table.concat(prefix, "\n"), table.concat(want, "\n"))

    -- ...and what follows them is this addon's four, in the order the retired
    -- General tab had them.
    local extras = {}
    for i = #want + 1, #got do extras[#extras + 1] = got[i] end
    assertEqual(table.concat(extras, "\n"), table.concat({
        "minimap.hide = " .. L["Show minimap button"],
        "data.mergePets = " .. L["Merge pets into their owner"],
        "data.throttle = " .. L["Refresh interval"],
        "state.testMode = " .. L["Test mode"],
    }, "\n"), "the retired General tab's rows must follow the canonical set, in order")
end)

test("Schema: the master controls are ADDON-WIDE, and the per-window three are untouched",
function()
    -- options-ui-§15's per-instance clause. A window is an instance here, so its own
    -- lock, scale and opacity stay on the Frame page and the master rows are the
    -- addon-wide settings beside them -- never a promotion of one, which would
    -- retarget silently every time the window banner moved.
    -- red under: pointing `master.scale` at `window.frame.scale`, or deleting the
    -- per-window row once the master one existed.
    local inst = T.load()
    local NS, L = inst.NS, inst.NS.L

    local perWindow = {
        ["window.frame.locked"] = L["Lock window"],
        ["window.frame.scale"]  = L["Scale"],
        ["window.frame.alpha"]  = L["Opacity"],
    }
    for path, label in pairs(perWindow) do
        local row = NS.FindSchemaRow(path)
        assertTrue(row ~= nil, path .. " left the schema")
        assertEqual(row.page, "frame", path .. " is not on the Frame page any more")
        assertEqual(row.label, label)
    end

    -- And no `master.` path resolves against a WINDOW: they are profile-level.
    for _, pair in ipairs(MASTER_ROWS) do
        local row = NS.FindSchemaRow(pair[1])
        assertTrue(row ~= nil, pair[1] .. " is not in the schema")
        assertTrue(row.path:sub(1, 7) ~= "window.", pair[1] .. " became window-relative")
    end
end)

test("Schema: a moved setting is declared ONCE, not twice", function()
    -- The failure this whole pass exists to remove: two controls over one setting.
    -- `enabled` and `state.debugConsole` MOVED into the Master controls tab, and a
    -- copy left behind on the old General tab would render both.
    -- red under: re-declaring either row beside the minimap toggle.
    local inst = T.load()
    local NS = inst.NS

    local seen = {}
    for _, row in ipairs(NS.Schema) do
        assertTrue(seen[row.path] == nil,
            row.path .. " is declared twice, on pages " ..
            tostring(seen[row.path]) .. " and " .. tostring(row.page))
        seen[row.path] = row.page
    end
end)

-- ---------------------------------------------------------------------------
-- The class-colour companion (options-ui-§17)
-- ---------------------------------------------------------------------------

--- The colour swatch this addon deliberately ships with NO companion beside it,
--- and the only one. Recorded as a documented deviation in docs/ARCHITECTURE.md;
--- the argument is in settings/Schema.lua beside the row.
local NO_COMPANION = { ["window.header.bgColor"] = true }

test("Schema: every colour swatch has its mode beside it, on the same line", function()
    -- options-ui-§17: a swatch on its own asks the player to hand-match a colour
    -- the game already knows. This addon's companion is the DROPDOWN form -- the
    -- richer one the rule names -- because `stat`, `skin` and `none` are answers a
    -- checkbox cannot give, and converting one back would lose them.
    --
    -- ADJACENT AND UNSPLITTABLE: the mode is the row immediately after the swatch,
    -- and the swatch carries `startsLine`, so an odd number of widgets above the
    -- pair cannot push the two onto different lines.
    -- red under: dropping a mode row, declaring it two rows away, or dropping
    -- `startsLine` from a swatch.
    local inst = T.load()
    local NS = inst.NS

    for i, row in ipairs(NS.Schema) do
        if row.type == "color"
            and row.path:sub(1, 11) ~= "statColors."   -- palette swatches are exempt
            and not NO_COMPANION[row.path] then
            local companion = NS.Schema[i + 1]
            assertTrue(companion ~= nil and companion.path:find("[Cc]olorMode$") ~= nil,
                row.path .. " has no colour mode immediately after it")
            assertEqual(companion.group, row.group,
                row.path .. "'s mode is filed under another tab")
            assertEqual(companion.subgroup, row.subgroup,
                row.path .. "'s mode is under another subsection heading")
            assertTrue(row.startsLine == true,
                row.path .. " can be split from its mode by an odd widget above it")
        end
    end
end)

test("Schema: NO colour row is ever disabled, and every one says why in words", function()
    -- options-ui-§17 / anti-patterns #74. The swatch is still read for its ALPHA
    -- under every mode -- no class colour and no palette entry carries one -- so
    -- greying it out tells the player something untrue, and setting a colour before
    -- switching the mode is the normal order of operations.
    -- red under: adding `disabledIf` to a swatch, or dropping the sentence.
    local inst = T.load()
    local NS, L = inst.NS, inst.NS.L
    local note = L["Not read while the color mode beside it is anything but Custom color, except for its opacity, which always applies."]

    local swatches = 0
    for _, row in ipairs(NS.Schema) do
        assertTrue(row.disabledIf == nil, row.path .. " carries disabledIf")
        if row.type == "color" then
            if row.path:sub(1, 11) == "statColors." then
                assertTrue((row.desc or ""):find(note, 1, true) == nil,
                    row.path .. " is a palette swatch and has no mode to warn about")
            else
                swatches = swatches + 1
                assertTrue((row.desc or ""):find(note, 1, true) ~= nil,
                    row.path .. " does not say what the mode beside it does to it")
            end
        end
    end
    assertTrue(swatches >= 15, "only " .. swatches .. " swatches were checked")
end)

test("Schema: which class a colour means is DECLARED, not inferred from its path", function()
    -- options-ui-§17: a control stored under a per-instance prefix can still be
    -- about the local player, so the path cannot be trusted and the intent is
    -- stamped on the row. Here every `window.*` path is per-window and the split is
    -- by SURFACE: a cell and a tooltip are about the row/the hovered player
    -- (`unit`), everything the window itself draws is about you (`player`).
    -- red under: stamping every window-relative row `unit` because of its prefix.
    local inst = T.load()
    local NS = inst.NS

    local WANT = {
        ["window.frame.backdropColorMode"]      = "player",
        ["window.frame.borderColorMode"]        = "player",
        ["window.frame.controlColorMode"]       = "player",
        ["window.frame.controlHoverColorMode"]  = "player",
        ["window.header.colorMode"]             = "player",
        ["window.header.dividerColorMode"]      = "player",
        ["window.columnHeader.colorMode"]       = "player",
        ["window.columnHeader.bgColorMode"]     = "player",
        ["window.bars.colorMode"]               = "unit",
        ["window.bars.bgColorMode"]             = "unit",
        ["window.bars.borderColorMode"]         = "unit",
        ["window.text.colorMode"]               = "unit",
        ["window.tooltip.barColorMode"]         = "unit",
        ["window.tooltip.barBgColorMode"]       = "unit",
        ["window.tooltip.barBorderColorMode"]   = "unit",
        ["window.tooltip.colorMode"]            = "unit",
    }
    for path, source in pairs(WANT) do
        local row = NS.FindSchemaRow(path)
        assertTrue(row ~= nil, path .. " left the schema")
        assertEqual(row.classColorSource, source, path .. ": class-colour source")
    end
end)

-- ---------------------------------------------------------------------------
-- Groups and subsection headings (options-ui-§7, §13)
-- ---------------------------------------------------------------------------

test("Schema: every row on every page carries a group, so no page renders untabbed", function()
    -- options-ui-§13 / anti-patterns #69: a page whose rows declare no group cannot
    -- draw a strip, so the library reports it and renders the page flat. Three
    -- lines, and the one that catches it.
    -- red under: adding a row without a `group`.
    local inst = T.load()
    for _, row in ipairs(inst.NS.Schema) do
        assertTrue(type(row.group) == "string" and row.group ~= "",
            row.path .. " carries no group")
    end
end)

test("Schema: a tab that mixes kinds of control names each kind between them", function()
    -- options-ui-§7. The four tabs here genuinely mix, and the merge is deliberate
    -- in every case -- what the rule adds is the heading that says where one kind
    -- stops and the next starts, never an un-merge.
    -- red under: dropping a subgroup, or naming one after its own tab.
    local inst = T.load()
    local NS, L = inst.NS, inst.NS.L

    local MIXED = {
        { "frame",  L["General"],               { L["Window"], L["All surfaces"] } },
        { "frame",  L["Background and border"], { L["Background"], L["Border"] } },
        { "header", L["Title bar"],             { L["Layout"], L["Background"], L["Divider"] } },
        { "header", L["Button style"],          { L["Icon"], L["Color"], L["Opacity"] } },
    }

    for _, case in ipairs(MIXED) do
        local page, group, want = case[1], case[2], case[3]
        local order, seen = {}, {}
        for _, row in ipairs(NS.SchemaForPage(page)) do
            if row.group == group then
                assertTrue(row.subgroup ~= nil,
                    page .. " / " .. group .. ": " .. row.path .. " has no subsection heading")
                if not seen[row.subgroup] then
                    seen[row.subgroup] = true
                    order[#order + 1] = row.subgroup
                end
            end
        end
        assertEqual(table.concat(order, " | "), table.concat(want, " | "),
            page .. " / " .. group .. ": subsection headings")
        for _, name in ipairs(want) do
            assertTrue(name ~= group, group .. ": a heading repeats its own tab's name")
        end
    end
end)

test("Schema: a subgroup is CONTIGUOUS, or its heading prints twice", function()
    -- The flow engine emits a heading when `subgroup` CHANGES within a group, so an
    -- interleaved block draws the same heading twice and reads as two sections.
    -- red under: moving one row of a subsection above the block it belongs to.
    local inst = T.load()
    local NS = inst.NS

    local closed = {}
    local page, group, current
    for _, row in ipairs(NS.Schema) do
        if row.page ~= page or row.group ~= group then
            page, group, current, closed = row.page, row.group, nil, {}
        end
        if row.subgroup ~= current then
            local key = tostring(row.subgroup)
            assertTrue(closed[key] == nil,
                page .. " / " .. group .. ": the '" .. key .. "' heading is drawn twice")
            if current ~= nil then closed[tostring(current)] = true end
            current = row.subgroup
        end
    end
end)

test("Schema: no tab holds fewer than two controls", function()
    -- A tab over one control is a click that reveals a single checkbox. Windows' Window is the
    -- one exemption and it is exempted BY NAME: a single stored row sharing its tab with
    -- BESPOKE commands that have no stored value and cannot be rows and cannot be counted here
    -- -- the picker and the create/duplicate/delete buttons. General's Maintenance was the
    -- second, and it is gone: one checkbox and two reset buttons were not a subject worth a
    -- tab, and all three sit on General now.
    -- red under: a tab losing rows until one is left, or a new one-row section.
    local inst = T.load()
    local NS, L = inst.NS, inst.NS.L
    local EXEMPT = { [L["Window"]] = true }

    local counts, pageOf = {}, {}
    for _, row in ipairs(NS.Schema) do
        if row.page and row.group then
            counts[row.group] = (counts[row.group] or 0) + 1
            pageOf[row.group] = row.page
        end
    end
    for group, n in pairs(counts) do
        if not EXEMPT[group] then
            assertTrue(n >= 2, pageOf[group] .. " / " .. group .. " holds only " .. n)
        end
    end
end)

test("Schema: a hidden row is filed under a tab that exists, and draws nothing", function()
    -- A hidden row still carries a page and a group -- that is what keeps it writable through
    -- NS.SetByPath, listable in `/mm list` and comparable by the schema-vs-defaults validator
    -- while missing the panel. It cannot produce a phantom tab, because SchemaForPage filters
    -- it before the strip is built; what it CAN do is lose its page and quietly drop out of
    -- `/mm list`, which is the half worth pinning.
    -- red under: dropping page or group from a hidden row "since it never draws".
    local inst = T.load()
    local NS = inst.NS

    local hidden, drawn = 0, {}
    for _, row in ipairs(NS.Schema) do
        if row.hidden then
            hidden = hidden + 1
            assertTrue(row.page ~= nil and row.group ~= nil,
                row.path .. " is hidden but carries no page or group")
        end
    end
    assertEqual(hidden, 8, "eight rows are hidden: frame.minimised, the three export choices "
        .. "and the four the window's own header controls choose (issue #50)")

    -- And the other half: no tab the strip actually draws is empty.
    for _, page in ipairs({ "general", "windows", "frame", "header", "bars", "tooltip",
                            "visibility", "columns" }) do
        for _, row in ipairs(NS.SchemaForPage(page)) do
            drawn[row.group or "?"] = (drawn[row.group or "?"] or 0) + 1
        end
    end
    for group, n in pairs(drawn) do
        assertTrue(n >= 1, group .. " is a drawn tab with nothing in it")
    end
end)

test("Schema: every tab name and row label is a localized string, not a bare literal", function()
    -- A tab label is now the most visible string on a page -- it is the heading AND the control
    -- you click -- and a group declared as a raw literal is a page that cannot be translated
    -- past its own headings. `L` answers its own key when a translation is missing, so the test
    -- is that the key EXISTS in the locale table rather than that the answer differs.
    --
    -- LABELS ARE WALKED TOO, and that is what this case is really for: a regroup moves `group`
    -- and `label` in two different fields, and a retirement checked only the first can retire a
    -- key still carrying the second -- exactly what happened to "Bar background color", which
    -- retired as a group name while still labelling window.bars.bgColor and
    -- window.tooltip.barBgColor. NOT `desc`: several desc strings were already missing their key
    -- before this case existed, and asserting on them here would fail this suite on a pre-existing
    -- gap this case is not the one to fix.
    -- red under: adding a group as "Bar border" instead of L["Bar border"], or retiring a locale
    -- key that is still a row's label.
    local inst = T.load()
    local NS = inst.NS
    local missing = {}

    --- A label with its texture escape taken back off.
    ---
    --- The Header page's Controls rows carry their own icon in front of the words
    --- (settings/Schema.lua's controlLabel), which is a PREFIX and not a
    --- replacement -- so the check is that what remains is still a locale key. A
    --- row that lost its translation while gaining a picture fails here exactly as
    --- a bare literal does.
    local function words(label)
        return (label:gsub("^|T[^|]*|t ", ""))
    end

    for _, row in ipairs(NS.Schema) do
        if row.group and rawget(NS.L, row.group) == nil then
            missing[#missing + 1] = "group: " .. row.group
        end
        if row.label and rawget(NS.L, words(row.label)) == nil then
            missing[#missing + 1] = row.path .. " label: " .. row.label
        end
    end
    table.sort(missing)
    assertEqual(table.concat(missing, ", "), "",
        "these strings are not in locales/enUS.lua")
end)

test("Schema: every Controls row carries its own icon in front of its words", function()
    -- The strip is the index into that tab: eight checkboxes named "Show close",
    -- "Show lock", "Show segment picker" ask a reader to translate a word back
    -- into the glyph they were looking at. The icon removes the translation.
    -- red under: a row added to Controls without one, which is the row a player
    -- then cannot match to anything in the header.
    local inst = T.load()
    local NS, L = inst.NS, inst.NS.L

    -- The one exemption, and it is not a control: `showSegmentText` governs the
    -- session LINE -- the words "Overall" at the left of the header -- which is
    -- text the title face draws and has no glyph in the strip. Giving it one of
    -- the seven would put the same picture beside two different checkboxes,
    -- which is worse than the row sitting a few pixels left of its neighbours.
    local NO_GLYPH = { ["window.frame.showSegmentText"] = true }

    local bare = {}
    for _, row in ipairs(NS.Schema) do
        if row.page == "header" and row.group == L["Controls"]
           and not row.hidden and not NO_GLYPH[row.path] then
            if not row.label:find("^|T") then bare[#bare + 1] = row.path end
        end
    end
    assertEqual(table.concat(bare, ", "), "",
        "these Controls rows draw no icon beside their checkbox")
end)

test("Schema: a control label degrades to its words when there is no art", function()
    -- NS.Icon answers nil on a degraded install -- the art is inside the LibKa0s
    -- payload that is missing (core/MediaSetup.lua) -- and a label built out of
    -- that answer must be the plain sentence rather than a broken escape.
    -- red under: string.format-ing a nil path into the label.
    local inst = T.load{ libFiles = {} }
    local NS, L = inst.NS, inst.NS.L

    for _, row in ipairs(NS.Schema) do
        if row.page == "header" and row.group == L["Controls"] then
            assertFalse(row.label:find("|T") ~= nil,
                row.path .. " drew a texture escape with no texture behind it")
        end
    end
end)

test("Schema: the active tab is session state and has no home in the schema", function()
    -- options-ui-§13: a stored tab is UI position masquerading as a setting. It would make one
    -- page look different to two characters on one account for a reason nobody asked for, and
    -- it turns a cosmetic default into a migration the day the sections are renamed.
    -- red under: adding an activeTab row "so /mm can reach it", which is the argument that
    -- correctly justifies the sessionOnly rows and does not justify this one.
    local inst = T.load()
    for _, row in ipairs(inst.NS.Schema) do
        assertFalse(row.path:find("activeTab") and true or false,
            "the active tab reached the schema: " .. row.path)
    end
end)

test("Schema: the column header strip is styled on the page where columns are chosen",
function()
    -- It LABELS the columns, and it spent three releases as the third group of a 31-control
    -- Header page. The paths stay under window.columnHeader.* -- a row's page is where it is
    -- edited and its path is where it is stored, and the two are allowed to disagree.
    -- red under: moving the group back to header, or renaming the paths to match the page.
    local inst = T.load()
    local NS = inst.NS

    local onColumns = 0
    for _, row in ipairs(NS.SchemaForPage("columns")) do
        onColumns = onColumns + 1
        assertTrue(row.path:find("^window%.columnHeader%."),
            row.path .. " is on the Columns page but is not a column-header setting")
    end
    assertEqual(onColumns, 8, "all eight moved, not some of them")

    for _, row in ipairs(NS.SchemaForPage("header")) do
        assertFalse(row.path:find("^window%.columnHeader%.") and true or false,
            "the Header page kept a column-header row: " .. row.path)
    end
end)


test("Schema: the header controls are EDITED on Header and STORED under frame", function()
    -- A row's page is where it is edited; its path is where it is stored, and the two are
    -- allowed to disagree. Every one of these draws a control into the title bar, so a player
    -- looks for them under Header -- but they are stored at `window.frame.*`, and renaming the
    -- keys for symmetry would migrate every saved profile for a tidiness nobody can see.
    -- red under: moving the group back to Frame, or renaming the paths to match the page.
    local inst = T.load()
    local NS, L = inst.NS, inst.NS.L
    local TABS = { [L["Controls"]] = true, [L["Button style"]] = true }

    -- The four hidden `window.data.*` rows the segment menu and a column-header click write
    -- (issue #50) are filed under Controls too, but they are the window's sort and session,
    -- stored where the aggregator has always read them, and are counted apart.
    local n, view = 0, 0
    for _, row in ipairs(NS.Schema) do
        if row.page == "header" and TABS[row.group] then
            if row.path:find("^window%.data%.") then
                view = view + 1
                assertTrue(row.hidden, row.path .. " is window state and must draw no control")
            else
                n = n + 1
                assertTrue(row.path:find("^window%.frame%.") ~= nil,
                    row.path .. " is a header control and must still be stored under frame")
            end
        end
    end
    -- Exactly 17: Controls (close/showMinimise/showLock/showSettings, the hidden
    -- `window.frame.minimised`, and the four meter buttons) + Button style (8). Walked over
    -- NS.Schema, not SchemaForPage, so the hidden row counts.
    assertEqual(n, 17, "the whole set moved, not one row of it")
    assertEqual(view, 4, "sessionType, sortColumn, sortMode and sortAscending")
end)


test("Schema: every group on every page is CONTIGUOUS, or a heading prints twice", function()
    -- Group headings are emitted when `group` CHANGES between consecutive rows,
    -- so a row filed under a group that has already been left prints that
    -- heading a second time further down the page. Moving a group between pages
    -- -- the header controls, from Frame to Header -- is exactly the edit that
    -- breaks this, and it can break the page it LEFT as well as the one it
    -- joined, which is why this walks every page rather than only Frame.
    local inst = T.load()
    local pages = {}
    for _, row in ipairs(inst.NS.Schema) do
        if row.page then pages[row.page] = true end
    end

    for page in pairs(pages) do
        local seen, previous = {}, nil
        for _, row in ipairs(inst.NS.SchemaForPage(page)) do
            local group = row.group or ""
            if group ~= previous then
                assertFalse(seen[group] or false,
                    page .. ": group returned after being left: " .. tostring(group))
                seen[group] = true
                previous = group
            end
        end
    end
end)

test("Schema: every LSM border setting is one this suite knows honours \"None\"", function()
    -- "None" is LSM's own name for the empty border, and it has to mean NO EDGE on
    -- every surface that offers it. The window frame did not: its resolver fell
    -- back to the library's own edge on anything it could not fetch, and treated a
    -- deliberate "None" as a failed fetch.
    --
    -- This case does not re-test the rendering -- each surface has its own case
    -- for that, named below. It enumerates the border settings, so a THIRD one
    -- added later cannot quietly ship without someone checking it behaves like
    -- these two.
    -- red under: adding an LSM30_Border row without a "None" case behind it.
    local COVERED = {
        -- path -> the case that proves this surface honours "None"
        ["window.frame.borderStyle"] =
            "test_window.lua: Border style None draws NO edge, whatever the library's own is",
        ["window.tooltip.barBorderStyle"] =
            "test_tooltip.lua: A bar border is applied when asked and cleared off the POOLED line when not",
        ["window.bars.borderStyle"] =
            "test_row.lua: Border style None keeps the cheap flat outline and puts no backdrop on a cell",
    }

    local inst = T.load()
    local uncovered = {}
    for _, row in ipairs(inst.NS.Schema) do
        if row.dialogControl == "LSM30_Border" and not COVERED[row.path] then
            uncovered[#uncovered + 1] = row.path
        end
    end
    assertEqual(#uncovered, 0,
        "border settings with no \"None\" case: " .. table.concat(uncovered, ", "))

    -- And the reverse, so a path that is renamed or removed does not leave this
    -- list quietly claiming coverage of something that no longer exists.
    local present = {}
    for _, row in ipairs(inst.NS.Schema) do present[row.path] = true end
    for path in pairs(COVERED) do
        assertTrue(present[path], "this list names a row that is gone: " .. path)
    end
end)

-- ---------------------------------------------------------------------------
-- Every text surface offers the same four controls
-- ---------------------------------------------------------------------------

test("Schema: every text surface offers face, outline, shadow and colour", function()
    -- FOUR SURFACES DRAW TEXT and they used to offer different subsets of the
    -- same controls: the cell text had a shadow and the other three did not, and
    -- none of them could take a class colour. A player styling a window had to
    -- discover which of the four had grown which control.
    --
    -- The table is the contract. A fifth surface, or a fifth control, is a row
    -- added here and then made to pass -- which is the point: it fails until the
    -- surface actually offers it.
    --
    -- THE CLASS-COLOUR CHECKBOX BECAME A THREE-WAY MODE on all four at once, and
    -- "at once" is the property this case is really defending: class / per-
    -- statistic / custom answers a question the checkbox could only answer two
    -- thirds of, and a surface left on the old boolean would be the one a player
    -- discovers by finding it missing.
    -- red under: dropping any row below, on any surface.
    local SURFACES = {
        { label = "Cell text",      prefix = "window.text.",
          font = "font", outline = "outline", shadow = "shadow",
          color = "color", colorMode = "colorMode" },
        -- NO colorMode. The Frame header is the one text surface with a colour
        -- picker and no mode beside it: the title bar is one strip over the whole
        -- window, so "per statistic" could only ever paint it the sort column's
        -- colour and "class" only the local player's, and it is about neither --
        -- it names the window.
        { label = "Frame header",   prefix = "window.header.",
          font = "font", outline = "outline", shadow = "shadow",
          color = "color" },
        { label = "Column headers", prefix = "window.columnHeader.",
          font = "font", outline = "outline", shadow = "shadow",
          color = "color", colorMode = "colorMode" },
        -- The tooltip's keys carry a `font` prefix of their own, which is why
        -- this is a table of names rather than four suffixes assumed to be equal.
        { label = "Tooltip text",   prefix = "window.tooltip.",
          font = "font", outline = "fontOutline", shadow = "fontShadow",
          color = "textColor", colorMode = "colorMode" },
    }

    local inst = T.load()
    local byPath = {}
    for _, row in ipairs(inst.NS.Schema) do byPath[row.path] = row end

    local missing = {}
    for _, surface in ipairs(SURFACES) do
        local function need(control, key, wantType)
            local path = surface.prefix .. key
            local row = byPath[path]
            if not row then
                missing[#missing + 1] = surface.label .. " has no " .. control ..
                    " (" .. path .. ")"
            elseif row.type ~= wantType then
                missing[#missing + 1] = path .. " is a " .. tostring(row.type) ..
                    ", expected " .. wantType
            end
            return row
        end

        -- The face is a MEDIA row, not a free string: it has to be the LSM
        -- picker, or "font selector" is an edit box you can type a typo into.
        local face = need("font selector", surface.font, "string")
        if face then
            assertEqual(face.dialogControl, "LSM30_Font",
                surface.label .. "'s font is not the LSM picker")
        end

        -- The outline is a DROPDOWN over one shared value set, so the four
        -- surfaces cannot offer different outlines from each other.
        local outline = need("outline dropdown", surface.outline, "string")
        if outline then
            assertTrue(type(outline.values) == "table",
                surface.label .. "'s outline has no value list")
            for _, key in ipairs({ "NONE", "OUTLINE", "THICKOUTLINE" }) do
                assertTrue(outline.values[key] ~= nil,
                    surface.label .. "'s outline is missing " .. key)
            end
        end

        need("shadow checkbox", surface.shadow, "bool")
        need("colour picker", surface.color, "color")

        -- THREE MODES, THE SAME THREE, ON EVERY SURFACE THAT HAS ONE. A surface
        -- offering a SUBSET is the drift this table exists to catch: `stat` means
        -- a different statistic per surface, but a surface that offers a mode at
        -- all has to offer all three of them.
        --
        -- Having no mode is a different thing entirely and is not drift -- the
        -- Frame header deliberately has none, because neither `class` nor `stat`
        -- can say anything true about one strip that names the whole window. So
        -- the check is keyed on the table declaring a mode, and the day someone
        -- adds one back it starts applying again on its own.
        local mode = surface.colorMode
            and need("colour mode dropdown", surface.colorMode, "string")
        if mode then
            assertTrue(type(mode.values) == "table",
                surface.label .. "'s colour mode has no value list")
            for _, key in ipairs({ "class", "stat", "custom" }) do
                assertTrue(mode.values[key] ~= nil,
                    surface.label .. "'s colour mode is missing " .. key)
            end
            assertTrue(mode.values.none == nil,
                surface.label .. " offers 'none', which is text nobody can read")
        end
    end

    assertEqual(#missing, 0, table.concat(missing, "; "))
end)

-- ---------------------------------------------------------------------------
-- "Reset all settings" IS a profile reset
-- ---------------------------------------------------------------------------

-- Two row decorations ship OFF, and they are asserted in BOTH places because
-- both are real: the window template a new window is stamped from, and the schema
-- row the panel and `/mm set` read. NS.ValidateSchema already proves the two
-- agree; this says WHICH value they agree on.
--
-- They shipped ON. A meter's job is telling rows apart by their numbers, and two
-- decorations that shade rows for reasons unrelated to the numbers -- one marks
-- you, one stripes every other row -- were doing that work before the player had
-- asked for either. The other two on that tab keep their ON default: `always show
-- yourself` changes WHICH rows are on screen rather than how they are painted,
-- and the mouseover highlight answers the cursor rather than the data.
--
-- red under: flipping either default back, or changing one of the two places and
-- not the other (which ValidateSchema catches, but not with a name).
test("Schema: Highlight yourself and Alternating background ship OFF", function()
    local inst = T.load()
    local NS = inst.NS

    local rows = NS.WINDOW_TEMPLATE and NS.WINDOW_TEMPLATE.rows
    assertTrue(rows ~= nil, "the window template must carry its row block")
    assertEqual(rows.highlightSelf, false, "a new window does not mark your row")
    assertEqual(rows.alternatingBackground, false, "…and does not stripe its rows")
    assertEqual(rows.alwaysShowSelf, true, "…while keeping your row on screen")
    assertEqual(rows.mouseoverHighlight, true, "…and still answering the cursor")

    local want = {
        ["window.rows.highlightSelf"]         = false,
        ["window.rows.alternatingBackground"] = false,
        ["window.rows.alwaysShowSelf"]        = true,
        ["window.rows.mouseoverHighlight"]    = true,
    }
    local seen = 0
    for _, row in ipairs(NS.Schema) do
        if want[row.path] ~= nil then
            seen = seen + 1
            assertEqual(row.default, want[row.path],
                row.path .. "'s schema default")
        end
    end
    assertEqual(seen, 4, "all four row-decoration rows must still be in the schema")
end)

test("RestoreAllDefaults resets EVERY window, not just the selected one", function()
    -- Every `window.` path resolves against ONE window -- whichever
    -- NS.State.activeWindowId names -- which is right for a panel click and for
    -- `/mm set`, and was wrong for the global sweep: the library walks the schema
    -- once, so "Reset all settings" reset the window you had selected and left
    -- the others exactly as they were.
    -- red under: afterRestoreAll going back to a per-row sweep.
    local inst, first = twoWindows()
    local NS = inst.NS

    for _, w in ipairs(NS.Database.GetWindows()) do
        w.frame.width = 999
        w.text.size   = 30
    end

    NS.State.SetActiveWindow(first)
    NS.Helpers.RestoreAllDefaults()

    for _, w in ipairs(NS.Database.GetWindows()) do
        assertEqual(w.frame.width, 694, "window " .. w.id .. " kept its width")
        assertEqual(w.text.size, 11, "window " .. w.id .. " kept its font size")
    end
end)

test("RestoreAllDefaults is the equivalent of a NEW PROFILE", function()
    -- The requirement, stated plainly: it deletes the extra windows rather than
    -- restyling them, and what comes back is one shipped window -- the same thing
    -- Profiles -> Reset Profile gives, because it IS that call.
    -- red under: afterRestoreAll restyling windows in place instead of handing
    -- the profile to AceDB.
    local inst = twoWindows()
    local NS = inst.NS
    assertEqual(#NS.Database.GetWindows(), 2)

    for _, w in ipairs(NS.Database.GetWindows()) do
        w.name        = "Renamed " .. w.id
        w.frame.width = 999
        w.columns     = { { stat = "Deaths", enabled = true } }
    end

    NS.Helpers.RestoreAllDefaults()

    local after = NS.Database.GetWindows()
    assertEqual(#after, 1, "the extra window survived a reset that means 'start over'")
    assertEqual(after[1].name, "Multi Meters #1", "the shipped name is what a new profile has")
    assertEqual(after[1].frame.width, 694)
    assertEqual(#after[1].columns, #NS.DefaultWindow(1).columns,
        "the column array is not a schema row, and only a profile reset reaches it")
end)

test("RestoreAllDefaults leaves the profile LIST alone", function()
    -- The rule the Profiles veto has always been about: resetting a profile is
    -- not deleting the player's profiles. `db:ResetProfile` empties the ACTIVE
    -- profile and touches no other, which is exactly the line to hold.
    -- red under: reaching for DeleteProfile, or resetting every profile.
    local inst = T.load()
    local NS = inst.NS
    NS.db:SetProfile("Spare")
    NS.db:SetProfile("Default")
    local before = #NS.db:GetProfiles()
    assertTrue(before >= 2, "the fixture needs a second profile to prove anything")

    NS.Helpers.RestoreAllDefaults()

    assertEqual(#NS.db:GetProfiles(), before, "a reset deleted a profile")
    assertEqual(NS.db:GetCurrentProfile(), "Default", "a reset switched profile")
end)

test("A profile reset rebuilds through the ONE message, not by direct calls", function()
    -- OnProfileReset lands on core/Database.lua's OnProfileChanged, which runs the
    -- migrations, re-seeds through SeedWindows and publishes PROFILE_CHANGED --
    -- and every window, the open panel and the aggregator's caches rebuild off
    -- that one message, exactly as they do for a profile switch
    -- (architecture-§4). A reset that emptied the profile without it would leave
    -- every live window drawing the settings that are no longer there.
    -- red under: afterRestoreAll emptying the profile itself rather than handing
    -- it to db:ResetProfile.
    --
    -- NOT red under `db:ResetProfile(nil, true)`, the real library's
    -- suppress-callbacks form: the harness's AceDB fires regardless of its
    -- arguments, so that mutation passes here and would break in the client.
    -- Recorded rather than worked around -- the fake is the vendored kit's.
    local inst = T.load()
    local NS = inst.NS

    local seen = 0
    local target = NS.NewBusTarget and NS.NewBusTarget()
    if target and target.RegisterMessage then
        target:RegisterMessage(NS.Const.MSG.PROFILE_CHANGED, function() seen = seen + 1 end)
    end

    NS.Helpers.RestoreAllDefaults()
    assertTrue(seen > 0, "PROFILE_CHANGED was not published, so nothing rebuilt")
end)
