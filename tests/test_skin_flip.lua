-- tests/test_skin_flip.lua — the HUD's colors, borders and shadows follow the skin (FS-MM-FLIP,
-- causes D2, D4 and D6 of Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING).
--
-- What this addon owes (LibKa0s Options doc, "Moving to this version"): each color and shadow has a
-- "Use the skin's ..." companion, default on, read after a class or per-statistic mode and before
-- the stored swatch; Ka0s Default keeps this addon's pixels through its owner tokens; and the one
-- per-profile step moves existing profiles onto the skin, naming companions and the From skin flags
-- only, so every stored pick and color survives for a player who turns a companion off.
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "MultiMeters"

local NEW_COMPANIONS = {
    "text.colorFromSkin", "columnHeader.colorFromSkin", "tooltip.textColorFromSkin",
    "bars.borderColorFromSkin", "tooltip.barBorderColorFromSkin", "tooltip.barBgColorFromSkin",
    "header.shadowFromSkin", "columnHeader.shadowFromSkin", "text.shadowFromSkin",
    "tooltip.fontShadowFromSkin", "rows.highlightSelfFromSkin", "rows.alternatingBackgroundFromSkin",
}
local FLAGS = { "header.outline", "columnHeader.outline", "text.outline", "tooltip.fontOutline", "fontOutline" }

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

local function dump(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys, out = {}, {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local byName = {}
    for k, x in pairs(v) do byName[tostring(k)] = x end
    for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. dump(byName[k]) end
    return "{" .. table.concat(out, ";") .. "}"
end

--- Every `@skin` in `v`, by path, for the "no key holds the sentinel but the flags named" check.
local function sentinels(v, prefix, into)
    for k, x in pairs(v) do
        local path = prefix == "" and tostring(k) or (prefix .. "." .. tostring(k))
        if type(x) == "table" then sentinels(x, path, into) elseif x == "@skin" then into[path] = true end
    end
    return into
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

--- The calls `fn` makes to `obj:method`, each as its argument list. The spy goes back after.
local function spy(obj, method, fn)
    local calls, real = {}, obj[method]
    obj[method] = function(self, ...)
        calls[#calls + 1] = { ... }
        return real(self, ...)
    end
    local ok, err = pcall(fn)
    obj[method] = real
    if not ok then error(err, 0) end
    return calls
end

local function last(calls, msg)
    assertTrue(#calls > 0, msg .. ": the setter was never called, so this proves nothing")
    return calls[#calls]
end

--- An instance with no database yet, initialized against `saved` as the SavedVariables global.
local function initWith(saved)
    local inst = T.load{ initDB = false, options = false }
    _G.MultiMetersDB = saved
    inst.NS:InitDB()
    return inst
end

--- A stored partial window of the shape a v22 account holds: some companions false, some absent,
--- a color table with one key, a sub-table missing.
local function storedWindow(id)
    return {
        id = id, name = "W" .. id,
        header = { font = "Arial Narrow", fontFromSkin = false, shadow = false, shadowFromSkin = false,
                   outline = "NONE" },
        columnHeader = { color = { r = 0.3 }, colorMode = "class", outline = "THICKOUTLINE" },
        text = { color = { r = 0.2, g = 0.3, b = 0.4, a = 1 }, colorFromSkin = false, colorMode = "stat",
                 outline = "OUTLINE", shadow = true },
        bars = { texture = "Smooth", colorMode = "class", customColor = { r = 1, g = 0, b = 0, a = 1 },
                 borderColor = { r = 0.5 }, borderStyle = "Blizzard Tooltip" },
        fontOutline = "NONE",
        -- no `tooltip` table at all: the step skips it and the shape fill brings the template's
    }
end

-- ── the rows and the defaults ────────────────────────────────────────────────────────────────

--- Every leaf under `t` for which `keep(leaf name, value)` answers true, as a dotted path.
local function leaves(t, keep, prefix, into)
    for k, v in pairs(t) do
        local path = prefix and (prefix .. "." .. k) or k
        if type(v) == "table" then leaves(v, keep, path, into) elseif keep(k, v) then into[#into + 1] = path end
    end
    return into
end

test("Skin flip: the one step's list is every companion and flag a window has, and nothing else", function()
    -- A list that loops over itself cannot miss an entry, so this one comes from the template.
    -- red under: a companion or a flags key added to the template and left off FOLLOW_ONCE_KEYS,
    -- which leaves every existing profile off the skin for that key, or a stale entry.
    local NS = T.load{}.NS
    local want = leaves(NS.WINDOW_TEMPLATE, function(k, v)
        -- header.alignFromSkin ships off (SF-MM-1): the skin's alignment is opt-in, never moved.
        return v == "@skin" or (k:match("FromSkin$") and type(v) == "boolean" and v == true)
    end, nil, {})
    assertTrue(#want > 20, "the walk found no companions, so this proves nothing")
    local got = { unpack(NS.Database.FOLLOW_ONCE_KEYS) }
    table.sort(want)
    table.sort(got)
    assertEqual(table.concat(got, "\n"), table.concat(want, "\n"))
end)

test("Skin flip: every new companion ships on, in the template and as a row, and governs no swatch", function()
    -- red under: a companion missing from the template or the schema, or one a swatch is disabled by
    -- (options-ui-§17: a composed swatch stays live and keeps its value).
    local inst = T.load()
    local NS = inst.NS
    for _, path in ipairs(NEW_COMPANIONS) do
        assertEqual(at(NS.WINDOW_TEMPLATE, path), true, path .. " does not ship on")
        local row = rowAt(NS, "window." .. path)
        assertTrue(row ~= nil, "window." .. path .. " is not a schema row")
        assertEqual(row.type, "bool")
        assertEqual(row.default, true)
        assertTrue(row.page ~= nil and row.group ~= nil, path .. " landed on no page")
    end
    for _, row in ipairs(NS.Schema) do
        if row.type == "color" then
            assertTrue(row.disabledIf == nil, row.path .. ": a swatch is never disabled by a companion")
        end
    end
end)

test("Skin flip: the picks' defaults are the Ka0s picks, in the template and on the rows", function()
    -- red under: a font or texture leaf left in spec.defaults (it wins), or the two disagreeing, so
    -- Defaults and a new profile land on different picks.
    local inst = T.load()
    local NS = inst.NS
    for _, path in ipairs({ "header.font", "columnHeader.font", "text.font", "tooltip.font", "font" }) do
        assertEqual(at(NS.WINDOW_TEMPLATE, path), "Ka0s Prototype", path)
        assertEqual(rowAt(NS, "window." .. path).default, "Ka0s Prototype", "window." .. path)
    end
    for _, path in ipairs({ "bars.texture", "tooltip.barTexture", "barTexture" }) do
        assertEqual(at(NS.WINDOW_TEMPLATE, path), "Ka0s Default", path)
        assertEqual(rowAt(NS, "window." .. path).default, "Ka0s Default", "window." .. path)
    end
end)

test("Skin flip: the border groups put the thickness on the skin with the style", function()
    -- red under: BorderGroup{ fromSkin = true }, which leaves the thickness the player's.
    -- A predicate since OptionsCompose minor 18: live under a skin's None, governed under a real style.
    local inst = T.load()
    local NS = inst.NS
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0", true)
    local cfg = NS.Database.GetWindows()[1]
    NS.State.SetActiveWindow(cfg.id)
    for _, path in ipairs({ "window.bars.borderThickness", "window.tooltip.barBorderSize", "window.bars.border" }) do
        local row = rowAt(NS, path)
        assertEqual(type(row.disabledIf), "function", path)
        assertFalse(row.disabledIf(row), path .. " under Ka0s Default's None draws the stored value")
    end
    Skin:SetChoice(OWNER, "ka0s", "azeroth")
    for _, path in ipairs({ "window.bars.borderThickness", "window.tooltip.barBorderSize", "window.bars.border" }) do
        local row = rowAt(NS, path)
        assertTrue(row.disabledIf(row), path .. " under a real style is the skin's")
    end
end)

test("Skin flip: the two scope rows and their defaults do not move", function()
    local inst = T.load()
    assertEqual(inst.NS.defaults.profile.skin.ignorePanel, true)
    assertEqual(inst.NS.defaults.profile.skin.ignoreFonts, false)
end)

-- ── Ka0s Default keeps its pixels ────────────────────────────────────────────────────────────

test("Skin flip: under Ka0s Default every surface draws what it drew before the flip", function()
    -- red under: a default that differs from its token with no owner token behind it. White numbers,
    -- gold labels and a tooltip bar backdrop of black at 0.1, where `bar.bg` is 0.5.
    local inst, NS, window, row, cfg = scene()
    local cell = statCell(row)
    local r, g, b = cell.left:GetTextColor()
    sameColor({ r, g, b }, { 1, 1, 1 }, "a cell's number")
    local label = window.columnHeaders[1].text
    r, g, b = label:GetTextColor()
    sameColor({ r, g, b }, { 1, 0.82, 0 }, "a column label")
    local style = NS.TooltipInternals.lineStyle(NS.TooltipInternals.tooltipConfig(cfg), nil)
    sameColor(style.textColor, { 1, 1, 1 }, "a tooltip line")
    sameColor(style.barBgColor, { 0, 0, 0, 0.1 }, "a tooltip bar's backdrop")
    assertEqual(inst.NS.SKIN_TOKENS["mm.tipBarBg"].follow, "bar.bg")
end)

test("Skin flip: under Ka0s Default the header and the cells keep their shadow, the others none", function()
    -- red under: S.HudFont's own answer, which is none under Ka0s Default, on the two surfaces that
    -- ship a shadow.
    local inst = T.load{}
    local NS = inst.NS
    local fs = NS.WindowManager and {} or {}
    local seen = {}
    local real = NS.Skin.HudFont
    NS.Skin.HudFont = function(_, o)
        seen[#seen + 1] = { shadow = o.shadow, fromSkin = o.shadowFromSkin }
        return nil
    end
    NS.SkinHudFont(fs, "Face", 12, nil, true, true, { 0, 0, 0, 1 })
    NS.SkinHudFont(fs, "Face", 12, nil, false, true)
    NS.Skin.HudFont = real
    assertEqual(seen[1].fromSkin, false, "the owner token draws as the stored arm")
    assertEqual(table.concat(seen[1].shadow, ","), "1,-1,0,0,0,1")
    assertEqual(seen[2].fromSkin, true)
end)

test("Skin flip: no flags means none, never From skin", function()
    -- red under: nil handed to S.HudFont, which S.FontFlags reads as From skin: a window with its
    -- outline on NONE would draw OUTLINE.
    local inst = T.load{}
    local NS = inst.NS
    local got
    local real = NS.Skin.HudFont
    NS.Skin.HudFont = function(_, o) got = o.flags end
    NS.SkinHudFont({}, "Face", 12, NS.SkinFontFlags("NONE"), false, false)
    NS.Skin.HudFont = real
    assertEqual(got, "")
end)

-- ── a skin switch changes what is drawn ──────────────────────────────────────────────────────

test("Skin flip: a skin switch redraws each flipped color, on the setter", function()
    -- red under: a surface still reading its swatch, or a look not refreshed by Reskin.
    local _, NS, window, row, cfg, Skin = scene()
    local cell = statCell(row)
    local label = window.columnHeaders[1].text
    local cellCalls
    local labelCalls = spy(label, "SetTextColor", function()
        cellCalls = spy(cell.left, "SetTextColor", function()
            Skin:SetChoice(OWNER, "ka0s", "obsidian")
            window:ApplyConfig()
            row:ApplyLayout(window.layout)
        end)
    end)
    local r, g, b = NS.Skin.HudTextColor()
    assertFalse(near(r, 1) and near(g, 1) and near(b, 1), "obsidian's hud.text is white: the case is moot")
    local call = last(cellCalls, "the cell")
    sameColor(call, { r, g, b }, "the cell's number")
    r, g, b = NS.Skin.HudLabelColor()
    assertFalse(near(r, 1) and near(g, 0.82) and near(b, 0), "obsidian's hud.label is gold: the case is moot")
    sameColor(last(labelCalls, "the label"), { r, g, b }, "the column label")

    local style = NS.TooltipInternals.lineStyle(NS.TooltipInternals.tooltipConfig(cfg), nil)
    r, g, b = NS.Skin.HudTextColor()
    sameColor(style.textColor, { r, g, b }, "the tooltip line")
    local br, bg, bb, ba = NS.Skin.Color("bar.bg")
    sameColor(style.barBgColor, { br, bg, bb, ba }, "the tooltip bar's backdrop")
    local er, eg, eb = NS.Skin.Color("bar.border")
    sameColor({ style.borderColor.r, style.borderColor.g, style.borderColor.b }, { er, eg, eb }, "the border")
end)

test("Skin flip: a companion off draws the stored color under every skin", function()
    -- red under: a surface that reads the skin past its companion, or a stored color rewritten.
    local _, NS, _, row, cfg, Skin = scene(function(c)
        c.text.colorFromSkin = false
        c.text.color = { r = 0.1, g = 0.2, b = 0.3, a = 1 }
        c.tooltip.textColorFromSkin = false
        c.tooltip.textColor = { r = 0.4, g = 0.5, b = 0.6, a = 1 }
    end)
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    row:ApplyLayout(row.window.layout)
    local r, g, b = statCell(row).left:GetTextColor()
    sameColor({ r, g, b }, { 0.1, 0.2, 0.3 }, "the cell")
    local style = NS.TooltipInternals.lineStyle(NS.TooltipInternals.tooltipConfig(cfg), nil)
    sameColor(style.textColor, { 0.4, 0.5, 0.6 }, "the tooltip line")
end)

test("Skin flip: a class color comes first and the companion never reaches it", function()
    -- red under: the companion read ahead of a class or per-statistic mode.
    local inst, NS, _, row, cfg, Skin = scene(function(c)
        c.text.colorMode = "class"
        c.tooltip.colorMode = "class"
        c.tooltip.barBgColorMode = "class"
    end)
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local cell = statCell(row)
    cell:ApplyEntryTextColor({ classFilename = "MAGE" })
    local r, g, b = cell.left:GetTextColor()
    local want = inst.mocks.RAID_CLASS_COLORS.MAGE
    sameColor({ r, g, b }, { want.r, want.g, want.b }, "the cell")
    local style = NS.TooltipInternals.lineStyle(NS.TooltipInternals.tooltipConfig(cfg),
        { r = 0.1, g = 0.2, b = 0.3 })
    sameColor(style.textColor, { 0.1, 0.2, 0.3 }, "the tooltip line")
    sameColor({ style.barBgColor[1], style.barBgColor[2], style.barBgColor[3] }, { 0.1, 0.2, 0.3 }, "the backdrop")
    assertEqual(style.barBgColor[4], cfg.tooltip.barBgAlpha, "a class backdrop keeps the stored opacity")
end)

test("Skin flip: the cell's outline takes the skin's color and thickness with the companions", function()
    -- red under: Row_Border reading the swatch or the thickness past its companions.
    local _, NS, _, row, _, Skin = scene(function(c)
        c.bars.border = true
        c.bars.borderThickness = 3
        c.bars.borderColor = { r = 1, g = 0, b = 0, a = 1 }
    end)
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local cell = statCell(row)
    local top = cell.border.top
    local colors
    local sizes = spy(top, "SetHeight", function()
        colors = spy(top, "SetColorTexture", function() cell:ApplyBorder(cell.window.config.bars) end)
    end)
    local r, g, b = NS.Skin.Color("bar.border")
    sameColor(last(colors, "the outline"), { r, g, b }, "the outline's color")
    assertEqual(NS.Skin.Token("bar.borderStyle"), "None", "the case is moot")
    assertEqual(last(sizes, "the outline")[1], 3, "a skin's None hands the player's thickness back")
end)

test("Skin flip: Show border alone decides whether a cell has an outline, in every skin (SF-MM-2)", function()
    -- red under: a skin's real style drawing an outline with Show border off.
    local _, NS, _, row, cfg, Skin = scene()
    local bars = statCell(row).window.config.bars
    assertEqual(NS.Skin.Token("bar.borderStyle"), "None")
    assertFalse(NS.SkinBorderShown(bars), "None, Show border off")
    bars.border = true
    assertTrue(NS.SkinBorderShown(bars), "None, Show border on")
    Skin:SetChoice(OWNER, "ka0s", "azeroth")
    assertFalse(NS.Skin.Token("bar.borderStyle") == "None", "azeroth states a real style")
    bars.border = false
    assertFalse(NS.SkinBorderShown(bars), "a real style, Show border off")
    bars.border = true
    assertTrue(NS.SkinBorderShown(bars), "a real style, Show border on")
    bars.borderStyleFromSkin = false
    assertTrue(NS.SkinBorderShown(bars), "the companion off: the toggle decides")
    assertTrue(cfg ~= nil)
end)

test("Skin flip: with no library a cell draws the stored border, through the stub's BarBorder", function()
    -- red under: a no-op BarBorder, whose nil takes a player's Show border away.
    local inst = T.load{ libFiles = {} }
    local NS = inst.NS
    assertEqual(select("#", NS.Skin.BarBorder("Grid", true, 3, true)), 3)
    local style, show, size = NS.Skin.BarBorder("Grid", true, 3, true)
    assertEqual(style, "Grid")
    assertEqual(show, true)
    assertEqual(size, 3)
    assertTrue(NS.SkinBorderShown({ border = true, borderStyleFromSkin = true }), "Show border on")
    assertFalse(NS.SkinBorderShown({ border = false, borderStyleFromSkin = true }), "Show border off")
    assertEqual(NS.Skin.HoverArt({}), nil, "a no-op")
end)

test("Skin flip: a probe skin's real style and size reach the cell and the tooltip's bar", function()
    -- red under: a stored style or thickness read past S.BarBorder, or a tooltip border with no skin.
    local inst, NS, _, row, cfg, Skin = scene(function(c)
        c.bars.borderThickness, c.tooltip.barBorderSize = 3, 3
        c.bars.border = true
    end)
    Skin:RegisterSkin({ key = "probe", tokens = { ["bar.borderStyle"] = "Probe Edge", ["bar.borderSize"] = 5 } })
    inst.mocks.__media.border["Probe Edge"] = [[Interface\ProbeEdge]]
    Skin:SetChoice(OWNER, "ka0s", "probe")
    local cell = statCell(row)
    cell.frame.SetBackdropBorderColor = function() end
    cell:ApplyBorder(cfg.bars)
    assertTrue(cell.borderShown, "the skin's style did not show with Show border on")
    assertEqual((cell.frame.__backdrop or {}).edgeFile, [[Interface\ProbeEdge]])
    assertEqual((cell.frame.__backdrop or {}).edgeSize, 5)
    local tip = NS.TooltipInternals.tooltipConfig(cfg)
    assertEqual(tip.barBorderStyle, "Probe Edge")
    assertEqual(tip.barBorderSize, 5)
end)

test("Skin flip: a shadow reaches a font object, a skin's own and the stored one", function()
    -- red under: a surface keeping its SetShadowOffset, which a 12.0.7 client does not draw, or a
    -- skin change that leaves the last skin's shadow on a string that already drew.
    local _, NS, _, row, _, Skin = scene()
    local made = {}
    rawset(_G, "CreateFont", function(name)
        local obj = { name = name }
        function obj:SetFont(...) self.font = { ... } return true end
        function obj:SetShadowColor(...) self.color = { ... } end
        function obj:SetShadowOffset(...) self.offset = { ... } end
        -- A real font object answers its face (LibKa0s R3-DR-1L reads it back to hold the face).
        function obj:GetFont() return unpack(self.font or {}) end
        made[#made + 1] = obj
        return obj
    end)
    local cell = statCell(row)
    Skin.__hudFonts[cell.left] = nil
    local objects = spy(cell.left, "SetFontObject", function()
        Skin:SetChoice(OWNER, "ka0s", "obsidian")
        row:ApplyLayout(row.window.layout)
    end)
    local x, y, r, g, b = NS.Skin.HudShadow()
    assertTrue(type(x) == "number", "obsidian draws no shadow: the case is moot")
    local obj = last(objects, "the cell")[1]
    assertEqual(obj.offset[1], x)
    assertEqual(obj.offset[2], y)
    sameColor(obj.color, { r, g, b }, "the shadow's color")

    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    row:ApplyLayout(row.window.layout)
    assertEqual(obj.offset[1], 1, "Ka0s Default keeps the cell's 1, -1")
    assertEqual(obj.offset[2], -1)
    rawset(_G, "CreateFont", nil)
end)

-- ── the one step ─────────────────────────────────────────────────────────────────────────────

test("Skin flip: the step puts every window of every profile on the skin and keeps every pick", function()
    -- red under: a walk through dotted `windows.1...` paths, which Skin's walk cannot follow into a
    -- numeric array, or a stored pick or color rewritten.
    local a, b, c = storedWindow(1), storedWindow(2), storedWindow(7)
    local before = dump(a.bars.customColor) .. dump(a.text.color) .. a.columnHeader.color.r
    local inst = initWith({
        profiles = { Default = { nextWindowId = 3, windows = { a, b }, skin = { ignorePanel = false, ignoreFonts = true } },
                     Raid    = { nextWindowId = 8, windows = { c } } },
        global   = { schemaVersion = 22 },
    })
    local NS = inst.NS
    assertEqual(NS.SCHEMA_VERSION, 26)
    assertEqual(NS.db.global.schemaVersion, 26)
    for _, name in ipairs({ "Default", "Raid" }) do
        local p = NS.db.sv.profiles[name]
        assertEqual(p.skin.fullSkinReset, true, name .. ": no record")
        for i, w in ipairs(p.windows) do
            local where = name .. " window " .. i
            for _, path in ipairs(NS.Database.FOLLOW_ONCE_KEYS) do
                if path:match("FromSkin$") and at(w, path:match("^(.*)%.") or "") ~= nil then
                    assertEqual(at(w, path), true, where .. ": " .. path)
                end
            end
            assertEqual(w.skin, nil, where .. " grew a stray skin table")
            assertEqual(w.header.font, "Arial Narrow", where .. ": the face pick")
            assertEqual(w.bars.texture, "Smooth", where .. ": the texture pick")
            assertEqual(w.bars.borderStyle, "Blizzard Tooltip", where .. ": the border pick")
            assertEqual(w.bars.colorMode, "class", where .. ": a class mode")
            assertEqual(w.text.colorMode, "stat", where .. ": a meaning mode")
            assertEqual(w.columnHeader.colorMode, "class", where .. ": a class mode")
            assertEqual(w.text.shadow, true, where .. ": a stored shadow")
            assertEqual(w.header.shadow, false, where .. ": a stored shadow")
            for _, flag in ipairs(FLAGS) do
                -- A window with no `tooltip` table gets the template's, which is From skin too.
                local got = at(w, flag)
                assertTrue(got == "@skin" or (got == nil and flag:find("tooltip", 1, true) ~= nil), where .. ": " .. flag)
            end
        end
    end
    -- `.r` alone: the shape fill, not the step, gives a one-key color its other channels.
    assertEqual(dump(a.bars.customColor) .. dump(a.text.color) .. a.columnHeader.color.r, before)
    local p = NS.db.sv.profiles.Default
    assertEqual(p.skin.ignorePanel, false, "the Scope is the player's")
    assertEqual(p.skin.ignoreFonts, true, "the Scope is the player's")
    local allowed = {}
    for _, f in ipairs(FLAGS) do allowed["windows.1." .. f] = true end
    allowed["skin.outline"] = true
    for path in pairs(sentinels({ windows = { a } }, "", {})) do
        assertTrue(allowed[path], path .. " holds the sentinel, and only the flags may")
    end
end)

test("Skin flip: a second run writes nothing, and a companion turned off stays off", function()
    -- red under: no record, or a record the step does not read.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 2, windows = { storedWindow(1) } } },
        global   = { schemaVersion = 22 },
    })
    local NS = inst.NS
    local w = NS.db.sv.profiles.Default.windows[1]
    local once = dump(w)
    NS:RunMigrations()
    assertEqual(dump(w), once, "a second run moved something")
    w.text.colorFromSkin = false
    NS.Database.__migrations[22](NS.db)
    NS:RunMigrations()
    NS.Database:OnProfileChanged(nil, NS.db, "Default")
    assertEqual(w.text.colorFromSkin, false, "the step ran again over the player's choice")
end)

test("Skin flip: the record has no schema row, so no Defaults button walks it", function()
    -- red under: a row at skin.fullSkinReset that a Defaults pass would put back to false, which
    -- runs the step again over companions the player turned off (the AbsorbTracker pilot's bug).
    local inst = T.load()
    local NS = inst.NS
    assertEqual(NS.defaults.profile.skin.fullSkinReset, false)
    assertTrue(rowAt(NS, "skin.fullSkinReset") == nil, "the record must not be a row")
end)

test("Skin flip: a new profile takes the step against a template that shows nothing new", function()
    -- red under: the step only in the ladder, so a profile made after the stamp never gets a record.
    local inst = T.load{}
    local NS = inst.NS
    NS.db.profile.skin.fullSkinReset = false
    NS:RunMigrations()
    assertEqual(NS.db.profile.skin.fullSkinReset, true)
end)

test("Skin flip: without the library the step sets the companions by hand and writes the record", function()
    -- red under: the no-Skin arm leaving a profile unrecorded, so the library's first load would run
    -- the step over choices made since, or creating a table on the way.
    local inst = T.load{ initDB = false, options = false }
    local NS = inst.NS
    local skinMajor = inst.mocks.LibStub("LibKa0s-Skin-1.0", true)
    local follow, reset = skinMajor.FollowOnce, skinMajor.ResetToSkin
    skinMajor.FollowOnce, skinMajor.ResetToSkin = nil, nil
    local w = storedWindow(1)
    _G.MultiMetersDB = { profiles = { Default = { nextWindowId = 2, windows = { w } } },
                         global = { schemaVersion = 22 } }
    NS:InitDB()
    skinMajor.FollowOnce, skinMajor.ResetToSkin = follow, reset
    assertEqual(NS.db.sv.profiles.Default.skin.fullSkinReset, true)
    assertEqual(w.text.colorFromSkin, true)
    assertEqual(w.header.outline, "@skin")
    assertEqual(w.header.font, "Arial Narrow")
end)
