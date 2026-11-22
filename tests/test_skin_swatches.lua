-- tests/test_skin_swatches.lua — the cell and tooltip swatches follow the skin (the owner's R-2 of
-- 2026-11-20; SD-SK-MM.2 to .6 of Ka0sAddonsCommonTasks docs/2026-11-20-SKIN_DEFAULTS_AUDIT).
--
-- LibKa0s v1.108.0's composer gives every swatch a "Use the skin's color" companion, default on:
-- `bars.customColorFromSkin` (the skin's bar fill under Custom), `bars.bgColorFromSkin` (`bar.bg`'s
-- color under Custom, the opacity the setting's, SF-MM-3) and `tooltip.barColorFromSkin` (the skin's
-- bar fill under Custom and for a row with no class). A classless row's fill is the owner token
-- `mm.barNeutral` (the old slate under Ka0s Default), and a GameTooltip line with no class or
-- palette reads `gtip.value` / `mm.tipHint`. The companions ship off (owner, 2026-11-23); v29 takes back
-- what the retired v28 step wrote under its record, `skin.swatchesFollow`.
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "MultiMeters"
local COMPANIONS = { "bars.customColorFromSkin", "bars.bgColorFromSkin", "tooltip.barColorFromSkin" }

local function at(t, path)
    for seg in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[seg]
    end
    return t
end

local function rowAt(NS, path)
    for _, row in ipairs(NS.Schema) do
        if row.path == path then return row end
    end
    return nil
end

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-3 end

local function sameColor(got, want, msg)
    for i = 1, #want do
        assertTrue(near(got[i], want[i]), ("%s: channel %d is %s, want %s"):format(msg, i,
            tostring(got[i]), tostring(want[i])))
    end
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
    return inst, NS, window, row, cfg, inst.mocks.LibStub("LibKa0s-Skin-1.0")
end

local function statCell(row)
    for _, cell in pairs(row.cells) do
        if cell.key ~= "name" then return cell end
    end
end

--- `row` drawn for a player of `class` (nil: classless, an NPC or an enemy).
local function draw(window, row, class)
    window:ApplyConfig()
    row:ApplyLayout(window.layout)
    row:Update({ guid = "Player-1-0000000A", name = "Alpha", classFilename = class, values = {} }, 1)
    return statCell(row)
end

--- The tooltip's resolved line style for `cfg`, the hovered row of `class`.
local function tipStyle(inst, cfg, class)
    local I = inst.NS.TooltipInternals
    local color = class and inst.mocks.RAID_CLASS_COLORS[class] or nil
    return I.lineStyle(I.tooltipConfig(cfg), color)
end

-- ── the rows and the defaults ────────────────────────────────────────────────────────────────

test("Swatches: the three companions exist as composed rows beside their swatches, governing none", function()
    -- red under: a companion missing from the template or the schema, or a
    -- swatch disabled by it (options-ui-§17: a composed swatch stays live and keeps its value).
    local NS = T.load().NS
    for _, path in ipairs(COMPANIONS) do
        assertEqual(at(NS.WINDOW_TEMPLATE, path), false, path .. " does not ship off")
        local row = rowAt(NS, "window." .. path)
        assertTrue(row ~= nil, "window." .. path .. " is not a schema row")
        assertEqual(row.type, "bool")
        assertEqual(row.default, false)
        assertEqual(row.composed, true, path .. " is not the composer's row")
        assertEqual(row.label, NS.L["Use the skin's color"])
        local swatch = rowAt(NS, "window." .. path:gsub("FromSkin$", ""))
        assertTrue(swatch ~= nil and swatch.type == "color", path .. " has no swatch")
        assertTrue(swatch.disabledIf == nil, path .. " disables its swatch")
    end
end)

-- ── the cells ─────────────────────────────────────────────────────────────────────────────────

test("Swatches: under Custom a cell draws the skin's bar fill, the swatch with the companion off", function()
    -- red under: the Custom branch reading the swatch past its companion, or no barFill look.
    local _, NS, window, row, cfg, Skin = scene(function(c)
        c.bars.colorMode = "custom"
        c.bars.customColor = { r = 0.1, g = 0.2, b = 0.3, a = 1 }
        c.bars.customColorFromSkin = true
    end)
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local r, g, b = NS.Skin.BarFillColor()
    assertTrue(r ~= nil, "obsidian answers no bar fill: this case asserts nothing")
    sameColor(draw(window, row, "MAGE").frame.__barColor, { r, g, b }, "the companion on")
    cfg.bars.customColorFromSkin = false
    sameColor(draw(window, row, "MAGE").frame.__barColor, { 0.1, 0.2, 0.3 }, "the companion off")
end)

test("Swatches: a classless row's fill is mm.barNeutral, the old slate under Ka0s Default", function()
    -- red under: the `return 0.45, 0.45, 0.5` literal back, which no skin reaches (SD-SK-MM.3).
    local inst, NS, window, row, _, Skin = scene()
    sameColor(draw(window, row, nil).frame.__barColor, { 0.45, 0.45, 0.5 }, "Ka0s Default")
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local r, g, b = NS.Skin.Color("bar.fill")
    assertFalse(near(r, 0.45) and near(g, 0.45) and near(b, 0.5), "obsidian's bar fill is the slate: moot")
    sameColor(draw(window, row, nil).frame.__barColor, { r, g, b }, "another skin's bar fill")
    -- A class still comes first (skinning-§9, meaning colors).
    local c = inst.mocks.RAID_CLASS_COLORS.MAGE
    sameColor(draw(window, row, "MAGE").frame.__barColor, { c.r, c.g, c.b }, "the class color")
end)

test("Swatches: under Custom the cell background takes bar.bg's color and keeps its opacity", function()
    -- red under: the swatch read past bars.bgColorFromSkin, or bar.bg's own alpha over bgAlpha (SF-MM-3).
    local _, NS, window, row, cfg, Skin = scene(function(c)
        c.bars.bgColorMode = "custom"
        c.bars.bgColor = { r = 0.1, g = 0.2, b = 0.3, a = 1 }
        c.bars.bgAlpha = 0.4
        c.bars.bgColorFromSkin = true
    end)
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local r, g, b = NS.Skin.Color("bar.bg")
    sameColor(draw(window, row, "MAGE").bg.__colorTexture, { r, g, b, 0.4 }, "the companion on")
    cfg.bars.bgColorFromSkin = false
    sameColor(draw(window, row, "MAGE").bg.__colorTexture, { 0.1, 0.2, 0.3, 0.4 }, "the companion off")
end)

test("Swatches: degraded, a window has no fill looks, so every swatch draws as stored", function()
    -- red under: barFill or barBg resolved with no live skin (CHROME_LOOKS), which would draw Ka0s
    -- Default's fill over a stored pick on an install without the library.
    local NS = T.load().NS
    local live = NS.SKIN_LIVE
    NS.SKIN_LIVE = false
    local looks = NS.SkinWindowLooks({})
    NS.SKIN_LIVE = live
    assertEqual(looks.barFill, nil)
    assertEqual(looks.barBg, nil)
    sameColor(looks.barNeutral, { 0.45, 0.45, 0.5, 1 }, "the neutral keeps its pixel")
end)

-- ── the tooltip ───────────────────────────────────────────────────────────────────────────────

test("Swatches: the tooltip bar takes the skin's fill under Custom and for a classless row", function()
    -- red under: the gray swatch reaching an NPC's tooltip under the default Class mode (SD-SK-MM.5).
    local inst, NS, _, _, cfg, Skin = scene(function(c) c.tooltip.barColorFromSkin = true end)
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local r, g, b = NS.Skin.BarFillColor()
    sameColor(tipStyle(inst, cfg, nil).barColor, { r, g, b }, "a classless row under Class")
    local c = inst.mocks.RAID_CLASS_COLORS.MAGE
    sameColor(tipStyle(inst, cfg, "MAGE").barColor, { c.r, c.g, c.b }, "the class color first")
    cfg.tooltip.barColorMode = "custom"
    sameColor(tipStyle(inst, cfg, "MAGE").barColor, { r, g, b }, "Custom")
    cfg.tooltip.barColorFromSkin = false
    sameColor(tipStyle(inst, cfg, "MAGE").barColor, { 0.6, 0.6, 0.6 }, "the companion off: the swatch")
end)

test("Swatches: a GameTooltip line with no class or palette reads the skin's tooltip colors", function()
    -- red under: the white and 0.62 gray literals back (SD-SK-MM.6, skinning-§7).
    local inst = T.load()
    local NS, I = inst.NS, inst.NS.TooltipInternals
    inst.mocks.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "obsidian")
    local vr, vg, vb = NS.SkinColor("gtip.value")
    sameColor({ I.nameColor({ name = "Ogre" }) }, { vr, vg, vb }, "a classless name")
    local reader = NS.StatColor
    NS.StatColor = function() return nil end
    local shown = { I.statColor("Unknown", true) }
    local hidden = { I.statColor("Unknown", false) }
    NS.StatColor = reader
    sameColor(shown, { vr, vg, vb }, "an unpaletted statistic on screen")
    local hr, hg, hb = NS.SkinColor("mm.tipHint")
    sameColor(hidden, { hr, hg, hb }, "an unpaletted statistic off screen")
    local c = inst.mocks.RAID_CLASS_COLORS.MAGE
    sameColor({ I.nameColor({ classFilename = "MAGE" }) }, { c.r, c.g, c.b }, "a class comes first")
end)

-- ── the one step ──────────────────────────────────────────────────────────────────────────────

--- An instance with no database yet, initialized against `saved` as the SavedVariables global.
local function initWith(saved)
    local inst = T.load{ initDB = false, options = false }
    _G.MultiMetersDB = saved
    inst.NS:InitDB()
    return inst
end

--- A stored v27 window: every swatch at its shipped color but the ones `picks` names.
local function storedWindow(id, picks)
    picks = picks or {}
    return {
        id = id, name = "W" .. id,
        bars = { colorMode = "custom", customColor = picks.customColor or { r = 0.35, g = 0.55, b = 0.85, a = 1 },
                 bgColor = picks.bgColor or { r = 0, g = 0, b = 0, a = 1 } },
        tooltip = { barColor = picks.barColor or { r = 0.6, g = 0.6, b = 0.6, a = 1 } },
    }
end

test("Swatches: the three companions ship off, in the template and on the rows (owner 2026-11-23)", function()
    local NS = T.load{}.NS
    local w = NS.Database.GetWindows()[1]
    for _, path in ipairs(COMPANIONS) do
        -- red under: a follow-the-skin sweep flipping one (SD-SK-MM, 2026-11-20)
        assertEqual(at(w, path), false, path)
        assertEqual(rowAt(NS, "window." .. path).default, false, path .. " row default agrees")
    end
end)

test("Swatches: an account at v27 is never put on the skin, active or parked", function()
    local inst = initWith({
        profiles = {
            Default = { nextWindowId = 2, skin = { fullSkinReset = true }, windows = { storedWindow(1) } },
            Raid    = { nextWindowId = 3, skin = { fullSkinReset = true }, windows = { storedWindow(2) } },
        },
        global = { schemaVersion = 27 },
    })
    local sv = inst.NS.db.sv.profiles
    for _, w in ipairs({ sv.Default.windows[1], sv.Raid.windows[1] }) do
        -- red under: the v28 step still moving, or a backfill of true
        for _, path in ipairs(COMPANIONS) do assertTrue(at(w, path) ~= true, path) end
    end
    assertEqual(inst.NS.db.global.schemaVersion, 29)
end)

test("Swatches: v29 takes back what v28 wrote, in every profile it reached", function()
    local function moved(id, picks)
        local w = storedWindow(id, picks)
        w.bars.customColorFromSkin, w.bars.bgColorFromSkin, w.tooltip.barColorFromSkin = true, true, true
        return w
    end
    local function skin(reached) return { fullSkinReset = true, swatchesFollow = reached or nil } end
    local inst = initWith({
        profiles = {
            Default = { nextWindowId = 2, skin = skin(true), windows = { moved(1) } },
            Raid    = { nextWindowId = 3, skin = skin(true), windows = {
                "junk", moved(2, { barColor = { r = 0, g = 1, b = 0, a = 1 } }) } },
            Kept    = { nextWindowId = 4, skin = skin(false), windows = { moved(3) } },
        },
        global = { schemaVersion = 28 },
    })
    local sv = inst.NS.db.sv.profiles
    local w1, w2, w3 = sv.Default.windows[1], sv.Raid.windows[2], sv.Kept.windows[1]
    for _, path in ipairs(COMPANIONS) do assertEqual(at(w1, path), false, path) end
    assertEqual(w2.bars.customColorFromSkin, false, "the parked profile too")
    assertEqual(w2.tooltip.barColorFromSkin, true, "on beside a picked color was never v28's write")
    for _, path in ipairs(COMPANIONS) do assertEqual(at(w3, path), true, "no record, untouched: " .. path) end
    assertEqual(sv.Default.skin.swatchesFollow, nil, "the record cleared")
    assertEqual(sv.Raid.skin.swatchesFollow, nil, "the record cleared")
end)
