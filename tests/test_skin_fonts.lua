-- tests/test_skin_fonts.lua — every font setting is the minimum set, its flags default to From
-- skin, and the HUD's sizes scale with the skin (MM-01 of Ka0sAddonsCommonTasks
-- docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK; rulings D-07 and D-09, LibKa0s v1.82.0).
--
-- D-07. The four font groups a window carries (the title, the column labels, the cell text and the
-- tooltip) each have a size, a color with a class-color option (the color mode beside the swatch),
-- flags and a shadow. Their flags lead with "From skin" ("@skin", the composer's flagsFromSkin),
-- the default, which draws through S.FontFlags: the owner's Font outline answers it (All text and
-- HUD text only: OUTLINE; Off: none). A flag the player picked wins; "NONE" stays this addon's
-- word for none. The v21 -> v22 step moves a stored flag equal to the old default onto From skin,
-- once, in every window of every profile (Addendum 01); a flag the player changed stays.
--
-- D-09. A HUD element whose face follows the skin (`fontFromSkin` on) draws at
-- S.HudFontSize(stored, true); its own face, or Ignore fonts, draws the stored size. The stored
-- value is never rewritten.
--
-- EACH CASE ON ITS OWN INSTANCE: a skin and its outline are library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "MultiMeters"

-- The four font groups: their prefix, and the leaf of each member of the set.
local GROUPS = {
    { prefix = "window.header.",       size = "size",     color = "color",     flags = "outline",     shadow = "shadow" },
    { prefix = "window.columnHeader.", size = "size",     color = "color",     flags = "outline",     shadow = "shadow" },
    { prefix = "window.text.",         size = "size",     color = "color",     flags = "outline",     shadow = "shadow" },
    { prefix = "window.tooltip.",      size = "fontSize", color = "textColor", flags = "fontOutline", shadow = "fontShadow" },
}

-- The flags each stored window carried as its default before v22, which the step moves.
local OLD_DEFAULTS = {
    { "header", "outline", "NONE" }, { "columnHeader", "outline", "OUTLINE" },
    { "text", "outline", "NONE" }, { "tooltip", "fontOutline", "NONE" }, { nil, "fontOutline", "NONE" },
}

local function rowAt(NS, path)
    for _, row in ipairs(NS.Schema) do
        if row.path == path then return row end
    end
    return nil
end

--- A fresh instance with its first window managed, configured, and one pooled row built.
local function scene(configure)
    local inst = T.load{}
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    cfg.columns = { { stat = "DamageDone", enabled = true } }
    cfg.data.sortColumn = "DamageDone"
    if configure then configure(cfg) end
    NS.WindowManager:Init()
    local window = NS.WindowManager.Get(cfg.id)
    window:ApplyConfig()
    local row = window:Acquire()
    row:ApplyLayout(window.layout)
    return inst, NS, window, row, cfg
end

local function skin(inst) return inst.mocks.LibStub("LibKa0s-Skin-1.0") end

--- An instance with no database yet, initialized against `saved` as the SavedVariables global.
local function initWith(saved)
    local inst = T.load{ initDB = false, options = false }
    _G.MultiMetersDB = saved
    inst.NS:InitDB()
    return inst
end

-- ── the set ──────────────────────────────────────────────────────────────────────────────────

test("Skin fonts: every font group carries size, color with a class option, flags and shadow", function()
    -- red under: a group that loses a member of D-07's minimum set.
    local NS = T.load{}.NS
    for _, g in ipairs(GROUPS) do
        for _, leaf in ipairs({ g.size, g.color, g.flags, g.shadow }) do
            assertTrue(rowAt(NS, g.prefix .. leaf) ~= nil, g.prefix .. leaf .. " is not a row")
        end
        local mode = rowAt(NS, g.prefix .. "colorMode")
        assertTrue(mode ~= nil and mode.values and mode.values.class ~= nil,
            g.prefix .. "colorMode offers no class color")
    end
end)

test("Skin fonts: every flags row leads with From skin and defaults to it, the template too", function()
    -- red under: a flags row whose values or default leave "@skin" out (the Skin tab's Font outline
    -- would never reach that text), or a template still shipping "NONE".
    local NS = T.load{}.NS
    local paths = { "window.fontOutline" }
    for _, g in ipairs(GROUPS) do paths[#paths + 1] = g.prefix .. g.flags end
    for _, path in ipairs(paths) do
        local row = rowAt(NS, path)
        assertTrue(row ~= nil, path .. " is not a row")
        assertEqual(row.default, "@skin", path .. ": the default")
        assertEqual(row.sorting[1], "@skin", path .. ": From skin leads the list")
        assertEqual(row.values["@skin"], "From skin", path .. ": its label")
        assertTrue(row.values.NONE ~= nil and row.values.THICKOUTLINE ~= nil, path .. ": the picks stay")
    end
    local t = NS.WINDOW_TEMPLATE
    assertEqual(t.fontOutline, "@skin")
    assertEqual(t.header.outline, "@skin")
    assertEqual(t.columnHeader.outline, "@skin")
    assertEqual(t.text.outline, "@skin")
    assertEqual(t.tooltip.fontOutline, "@skin")
end)

-- ── the flags drawn ──────────────────────────────────────────────────────────────────────────

test("Skin fonts: From skin draws the Font outline: OUTLINE under All text and HUD only, none under Off", function()
    -- red under: a draw site passing the stored "@skin" to SetFont, or one reading the stored value
    -- past S.FontFlags (the Skin tab's Font outline would change nothing on the meter).
    local inst, NS, window, row, cfg = scene()
    local cell = row.cells.DamageDone
    assertEqual(cell.left.__font.flags, "OUTLINE", "the cell under All text")
    assertEqual(window.frame.title.__font.flags, "OUTLINE", "the title under All text")
    local _, _, tipFlags = NS.TooltipInternals.tooltipFont(NS.TooltipInternals.tooltipConfig(cfg))
    assertEqual(tipFlags, "OUTLINE", "the tooltip under All text")

    skin(inst):SetOutline(OWNER, "hud")
    row:ApplyLayout(window.layout)
    assertEqual(cell.left.__font.flags, "OUTLINE", "the meter is HUD text: HUD only keeps it")

    skin(inst):SetOutline(OWNER, "off")
    window:ApplyConfig()
    row:ApplyLayout(window.layout)
    assertEqual(cell.left.__font.flags, nil, "Off takes the cell's outline")
    assertEqual(window.frame.title.__font.flags, nil, "Off takes the title's")
    _, _, tipFlags = NS.TooltipInternals.tooltipFont(NS.TooltipInternals.tooltipConfig(cfg))
    assertEqual(tipFlags, nil, "Off takes the tooltip's")
end)

test("Skin fonts: a flag the player picked wins over the Font outline, and NONE draws none", function()
    local inst, _, window, row, cfg = scene(function(c)
        c.text.outline, c.header.outline = "THICKOUTLINE", "NONE"
    end)
    skin(inst):SetOutline(OWNER, "off")
    window:ApplyConfig()
    row:ApplyLayout(window.layout)
    assertEqual(row.cells.DamageDone.left.__font.flags, "THICKOUTLINE", "the pick wins under Off")
    skin(inst):SetOutline(OWNER, "all")
    window:ApplyConfig()
    assertEqual(window.frame.title.__font.flags, nil, "NONE stays none under All text")
    assertEqual(cfg.text.outline, "THICKOUTLINE", "nothing rewrote the pick")
end)

test("Skin fonts: the all-surfaces flags row writes From skin to every surface", function()
    local NS = T.load{}.NS
    local cfg = NS.Database.GetWindows()[1]
    NS.SetByPath("window.fontOutline", "NONE")
    assertEqual(cfg.text.outline, "NONE")
    NS.SetByPath("window.fontOutline", "@skin")
    for _, g in ipairs({ "header", "columnHeader", "text" }) do
        assertEqual(cfg[g].outline, "@skin", g .. " did not follow the meta row")
    end
    assertEqual(cfg.tooltip.fontOutline, "@skin")
end)

-- ── the one-time move (Addendum 01) ──────────────────────────────────────────────────────────

--- A v21-shaped window: the old defaults stored, or the player's own flags.
local function v21Window(id, own)
    return {
        id = id, fontOutline = own and "THICKOUTLINE" or "NONE",
        header = { outline = own and "OUTLINE" or "NONE" },
        columnHeader = { outline = own and "NONE" or "OUTLINE" },
        text = { outline = own and "MONOCHROME" or "NONE" },
        tooltip = { fontOutline = own and "THICKOUTLINE" or "NONE" },
    }
end

local function flagOf(w, group, leaf)
    if group then return w[group][leaf] end
    return w[leaf]
end

test("Skin fonts: the v22 step moves every stored old-default flag onto From skin, in every profile", function()
    -- red under: no v21 -> v22 step, one that walks db.profile alone, or one that moves a flag the
    -- player changed.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 3, windows = { v21Window(1), v21Window(2, true) } },
                     Raid    = { nextWindowId = 8, windows = { v21Window(7) } } },
        global   = { schemaVersion = 21 },
    })
    local NS = inst.NS
    assertEqual(NS.SCHEMA_VERSION, 22)
    assertEqual(NS.db.global.schemaVersion, 22)
    for _, name in ipairs({ "Default", "Raid" }) do
        local w = NS.db.sv.profiles[name].windows[1]
        for _, d in ipairs(OLD_DEFAULTS) do
            assertEqual(flagOf(w, d[1], d[2]), "@skin", name .. ": " .. tostring(d[1]) .. "." .. d[2])
        end
    end
    local own = NS.db.sv.profiles.Default.windows[2]
    assertEqual(own.fontOutline, "THICKOUTLINE", "a changed flag moved")
    assertEqual(own.header.outline, "OUTLINE", "the header's changed flag moved")
    assertEqual(own.columnHeader.outline, "NONE", "the column labels' changed flag moved")
    assertEqual(own.text.outline, "MONOCHROME")
    assertEqual(own.tooltip.fontOutline, "THICKOUTLINE")
end)

test("Skin fonts: the v22 move runs once, so a NONE picked after it is kept", function()
    local inst = initWith({
        profiles = { Default = { nextWindowId = 2, windows = { v21Window(1) } } },
        global   = { schemaVersion = 21 },
    })
    local NS = inst.NS
    local w = NS.Database.FindWindow(1)
    assertEqual(w.text.outline, "@skin")
    NS.SetByPath("window.text.outline", "NONE")
    NS:RunMigrations()
    assertEqual(w.text.outline, "NONE", "a second walk took the player's pick back")
    local again = initWith(_G.MultiMetersDB)
    assertEqual(again.NS.Database.FindWindow(1).text.outline, "NONE", "a reload re-ran the move")
end)

test("Skin fonts: the v22 step survives a junk window and a group that is not a table", function()
    local inst = initWith({
        profiles = { Default = { nextWindowId = 2, windows = { { id = 1, text = "junk" } } },
                     Odd     = { windows = { "junk", v21Window(3) } } },
        global   = { schemaVersion = 21 },
    })
    local NS = inst.NS
    assertEqual(NS.db.sv.profiles.Odd.windows[1], "junk", "the step rewrote a non-window")
    assertEqual(NS.db.sv.profiles.Odd.windows[2].text.outline, "@skin")
end)

-- ── the HUD size scale (D-09) ────────────────────────────────────────────────────────────────

test("Skin fonts: a HUD size follows the skin's scale while the face does, never rewritten", function()
    -- red under: a draw site passing the stored size past S.HudFontSize, or one that writes the
    -- scaled size back into the profile.
    local inst, NS, window, row, cfg = scene(function(c) c.text.size, c.header.size = 12, 12 end)
    skin(inst):SetChoice(OWNER, "ka0s", "obsidian")
    local scaled = NS.Skin.HudFontSize(12, true)
    assertTrue(scaled ~= 12, "Obsidian's HUD scale is 1: this case asserts nothing")
    row:ApplyLayout(window.layout)
    local cell = row.cells.DamageDone
    assertEqual(cell.left.__font.size, scaled, "the cell under Obsidian")
    assertEqual(window.frame.title.__font.size, scaled, "the title under Obsidian")
    assertEqual(cfg.text.size, 12, "the stored size was rewritten")

    cfg.text.fontFromSkin = false
    row:ApplyLayout(window.layout)
    assertEqual(cell.left.__font.size, 12, "its own face draws the stored size")

    cfg.text.fontFromSkin = true
    skin(inst):SetIgnore(OWNER, nil, true)
    row:ApplyLayout(window.layout)
    assertEqual(cell.left.__font.size, 12, "Ignore fonts draws the stored size")
end)

test("Skin fonts: the tooltip's size scales with the skin too", function()
    local inst, NS, _, _, cfg = scene(function(c) c.tooltip.fontSize = 12 end)
    skin(inst):SetChoice(OWNER, "ka0s", "obsidian")
    local _, size = NS.TooltipInternals.tooltipFont(NS.TooltipInternals.tooltipConfig(cfg))
    assertEqual(size, NS.Skin.HudFontSize(12, true))
    cfg.tooltip.fontFromSkin = false
    _, size = NS.TooltipInternals.tooltipFont(NS.TooltipInternals.tooltipConfig(cfg))
    assertEqual(size, 12)
end)

test("Skin fonts: degraded, From skin draws OUTLINE and a size draws as stored", function()
    local NS = T.load{ libFiles = {} }.NS
    assertEqual(NS.SkinFontFlags("@skin"), "OUTLINE")
    assertEqual(NS.SkinFontFlags("NONE"), nil)
    assertEqual(NS.SkinFontFlags("THICKOUTLINE"), "THICKOUTLINE")
    assertEqual(NS.SkinHudFontSize(14, true), 14)
end)
