-- tests/test_settings_layout.lua
--
-- Item 020, the settings-layout pass: the words and the placements it settled,
-- pinned where tests/test_schema.lua's partition (tab order and counts) and its
-- subsection case do not already reach. tests/test_settings_pin.lua is the other
-- half: that suite proves nothing STORED moved; this one proves what the player
-- now READS.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function rowOf(NS, path)
    local row = NS.FindSchemaRow(path)
    assertTrue(row ~= nil, path .. " is not in the schema")
    return row
end

test("Layout: Frame's Size and position holds Geometry, then Placement with the lock, the clamp and the strata",
function()
    -- MUL-L01/L02. red under: the lock left on a tab of its own, or strata back among the sizes.
    local NS = T.load().NS
    local L = NS.L
    local got = {}
    for _, row in ipairs(NS.SchemaForPage("frame")) do
        if row.group == L["Size and position"] then got[#got + 1] = row.subgroup .. ":" .. row.path end
    end
    assertEqual(table.concat(got, ","), table.concat({
        L["Geometry"] .. ":window.frame.width", L["Geometry"] .. ":window.frame.height",
        L["Geometry"] .. ":window.frame.scale", L["Geometry"] .. ":window.frame.alpha",
        L["Geometry"] .. ":window.frame.padding",
        L["Placement"] .. ":window.frame.locked", L["Placement"] .. ":window.frame.clampToScreen",
        L["Placement"] .. ":window.frame.strata",
    }, ","))
    assertTrue(rowOf(NS, "window.frame.strata").startsLine, "Frame strata does not open its own line")
    -- MUL-L-new3: the per-window pair names its object and says what multiplies it.
    assertEqual(rowOf(NS, "window.frame.scale").label, L["Window scale"])
    assertEqual(rowOf(NS, "window.frame.alpha").label, L["Window opacity"])
    assertTrue(rowOf(NS, "window.frame.scale").desc:find(
        "Multiplied by Master scale on the General page > Master controls.", 1, true) ~= nil)
    assertTrue(rowOf(NS, "window.frame.alpha").desc:find(
        "Multiplied by Master opacity on the General page > Master controls.", 1, true) ~= nil)
end)

test("Layout: Death timestamps lives on Tooltip > Contents > Deaths, first and on its own line", function()
    -- MUL-L09/L13. The PATH is unchanged (window.text.deathTimeFormat); only its page moved.
    -- red under: the row left on Bars, or the killer pair sharing its line.
    local NS = T.load().NS
    local L = NS.L
    local row = rowOf(NS, "window.text.deathTimeFormat")
    assertEqual(row.page, "tooltip")
    assertEqual(row.group, L["Contents"])
    assertEqual(row.subgroup, L["Deaths"])
    assertTrue(row.startsLine, "Death timestamps does not open its own line")
    assertTrue(row.desc:find("Also used by the death list in the window's breakdown.", 1, true) ~= nil)
    local deaths = {}
    for _, r in ipairs(NS.SchemaForPage("tooltip")) do
        if r.subgroup == L["Deaths"] then deaths[#deaths + 1] = r.path end
    end
    assertEqual(table.concat(deaths, ","),
        "window.text.deathTimeFormat,window.tooltip.showDeathCaster,window.tooltip.showDeathSpell")
    assertTrue(rowOf(NS, "window.tooltip.showDeathCaster").startsLine,
        "Name the killer does not open the line after Death timestamps")
    assertEqual(rowOf(NS, "window.tooltip.showDeathSpell").label, L["Name the killing spell"])
    assertEqual(rowOf(NS, "window.tooltip.showAllStatsOnName").label, L["Show all statistics on name hover"])
end)

test("Layout: the composed font blocks wear options-ui-§16's canonical labels", function()
    -- MUL-L-new1: the overrides are gone, so the composer's words show. red under: a `labels`
    -- override put back on any of the four font blocks, or a mode row still saying Text color mode.
    local NS = T.load().NS
    local L = NS.L
    local blocks = {
        { "window.header.", { color = "color", outline = "outline", shadow = "shadow" } },
        { "window.text.", { color = "color", outline = "outline", shadow = "shadow" } },
        { "window.tooltip.", { color = "textColor", outline = "fontOutline", shadow = "fontShadow" } },
        { "window.columnHeader.", { color = "color", outline = "outline", shadow = "shadow" } },
    }
    for _, b in ipairs(blocks) do
        local p, k = b[1], b[2]
        assertEqual(rowOf(NS, p .. k.color).label, "Font color", p .. " color")
        assertEqual(rowOf(NS, p .. k.outline).label, "Font flags", p .. " flags")
        assertEqual(rowOf(NS, p .. k.shadow).label, "Font shadow", p .. " shadow")
        assertEqual(rowOf(NS, p .. "colorMode").label, L["Font color mode"], p .. " color mode")
    end
end)

test("Layout: the relabels of the pass", function()
    -- One assertion per relabel, so a reverted word is a named failure.
    local NS = T.load().NS
    local L = NS.L
    local want = {
        ["window.header.align"]             = "Text alignment",           -- L06
        ["window.header.height"]            = "Title bar height",         -- L25
        ["window.header.bgColor"]           = "Title bar background",     -- L25
        ["window.bars.border"]              = "Show border",              -- L26
        ["window.text.maxNameLength"]       = "Maximum name length",      -- L27
        ["window.tooltip.offsetX"]          = "X offset",                 -- L-new2
        ["window.tooltip.offsetY"]          = "Y offset",                 -- L-new2
        ["window.tooltip.barSpacing"]       = "Line spacing",             -- L12
        ["window.tooltip.barBorderStyle"]   = "Border style",             -- L12
        ["window.tooltip.barBorderSize"]    = "Border thickness",         -- L12
        ["window.tooltip.barBorderColor"]   = "Border color",             -- L12
        ["window.tooltip.barBorderColorMode"] = "Border color mode",      -- L12
        ["window.tooltip.barBgColor"]       = "Background color",         -- L12
        ["window.tooltip.barBgColorMode"]   = "Background color mode",    -- L12
        ["window.tooltip.barBgAlpha"]       = "Background opacity",       -- L12
        ["window.frame.showSegmentText"]    = "Show fight name",          -- L08
        ["master.alpha"]                    = "Master opacity",           -- CALL-02, quoted by L-new3
    }
    for path, label in pairs(want) do
        assertEqual(rowOf(NS, path).label, L[label], path)
    end
    -- Title text moved to the END of its tab, after the composed block (L06).
    local last
    for _, r in ipairs(NS.SchemaForPage("header")) do
        if r.group == L["Title text"] then last = r end
    end
    assertEqual(last.path, "window.header.align")
    assertTrue(last.startsLine, "Text alignment does not open its own line")
    -- L07, L29: the tooltips that described the wrong surface or a removed click target.
    assertEqual(rowOf(NS, "window.header.font").desc, L["Font for the window's title and the fight name beside it."])
    assertTrue(rowOf(NS, "window.frame.showSegment").desc:find("turned on and off by Show fight name", 1, true) ~= nil)
    -- L28: the fade toggle leads Opacity, on its own line, and the pair below it opens its own.
    local hover, alpha = rowOf(NS, "window.frame.hoverReveal"), rowOf(NS, "window.frame.controlAlpha")
    assertEqual(hover.subgroup, L["Opacity"])
    assertTrue(hover.startsLine and alpha.startsLine, "Reveal controls on hover does not sit alone")
end)

test("Layout: every color mode that offers Per-statistic says where that palette is edited", function()
    -- MUL-L21. red under: a mode row with `stat` in its values and no route to the palette.
    local NS = T.load().NS
    local n = 0
    for _, row in ipairs(NS.Schema) do
        if type(row.values) == "table" and row.values.stat ~= nil then
            n = n + 1
            assertTrue((row.desc or ""):find("Per-statistic colors are set on the General page > Statistic colors.", 1, true) ~= nil,
                row.path .. " offers Per-statistic and does not say where the palette is")
        end
    end
    assertTrue(n >= 8, "fewer Per-statistic modes than the bars, text, tooltip and column header carry")
end)
