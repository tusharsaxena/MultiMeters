-- tests/test_skin_hud.lua — the HUD following the skin (skinning-§6, the rollout's MM-03).
--
-- Every HUD media pick has a "Use the skin's ..." companion beside it, `<key>FromSkin`: the four
-- faces follow `hud.font`, the two bar textures `bar.texture` and the two bar border styles
-- `bar.borderStyle`. While a companion is on the surface draws the skin's token (core/SkinSetup.lua's
-- NS.SkinMediaKey); off, the player's pick, which is never rewritten. The companions ship on
-- (DECISIONS X3), and the v20 step (core/Database.lua) put every stored window on them once (O2):
-- a pick made after it is kept. Only texture, border and font follow; no color moves (X4).
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "MultiMeters"

--- The picker each companion governs, as the template stores it (`<group>.<key>`).
local function pickerOf(path) return (path:gsub("FromSkin$", "")) end

local function rowAt(NS, path)
    for _, row in ipairs(NS.Schema) do
        if row.path == path then return row end
    end
    return nil
end

local function at(t, path)
    for seg in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[seg]
    end
    return t
end

--- A fresh instance with its first window managed, configured, and one pooled row built.
local function scene(configure)
    local inst = T.load{}
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    cfg.columns = { { stat = "DamageDone", enabled = true } }
    cfg.data.sortColumn = "DamageDone"
    if configure then configure(cfg) end
    -- Managed, so the OnLooksChanged listener (WindowManager:Reskin) reaches it.
    NS.WindowManager:Init()
    local window = NS.WindowManager.Get(cfg.id)
    assertTrue(window ~= nil, "the manager built no window for the first config")
    window:ApplyConfig()
    local row = window:Acquire()
    row:ApplyLayout(window.layout)
    return inst, NS, window, row, cfg
end

local function media(inst) return inst.mocks.__libs["LibSharedMedia-3.0"] end

--- The file the skin's token `token` resolves to for this owner.
local function skinFile(inst, NS, kind, token)
    local path = media(inst):Fetch(kind, NS.Skin.Token(token), true)
    assertTrue(path ~= nil, token .. " resolves to no " .. kind .. ": this case asserts nothing")
    return path
end

--- An instance with no database yet, initialized against `saved` as the SavedVariables global.
local function initWith(saved)
    local inst = T.load{ initDB = false, options = false }
    _G.MultiMetersDB = saved
    inst.NS:InitDB()
    return inst
end

-- ── the companions ───────────────────────────────────────────────────────────────────────────

test("Skin HUD: the eight companions ship on, as rows defaulted on, each governing its picker", function()
    -- red under: a companion missing from the template or the schema, one shipped off (a new or
    -- reset window would draw the pre-skin look, X3), or a picker the composer does not disable.
    local inst = T.load()
    local NS = inst.NS
    local keys = NS.Database.FROM_SKIN_KEYS
    assertEqual(#keys, 8, "four faces, two textures, two borders")
    for _, path in ipairs(keys) do
        assertEqual(at(NS.WINDOW_TEMPLATE, path), true, path .. " does not ship on")
        local row = rowAt(NS, "window." .. path)
        assertTrue(row ~= nil, "window." .. path .. " is not a schema row")
        assertEqual(row.type, "bool")
        assertEqual(row.default, true, "window." .. path .. "'s row does not default on")
        local picker = rowAt(NS, "window." .. pickerOf(path))
        assertTrue(picker ~= nil, "no picker beside window." .. path)
        assertEqual(picker.disabledIf, "window." .. path, picker.path .. " is not governed by its companion")
    end
    -- The meta pair on Frame > Quick style.
    for _, path in ipairs({ "window.barTextureFromSkin", "window.fontFromSkin" }) do
        local row = rowAt(NS, path)
        assertTrue(row ~= nil and row.default == true, path .. " is not a meta row defaulted on")
    end
    -- No color, size, outline or thickness is governed (X4, D12).
    for _, row in ipairs(NS.Schema) do
        if row.disabledIf ~= nil then
            assertTrue(row.type ~= "color" and row.type ~= "number",
                row.path .. " follows the skin, but only faces, textures and borders may")
        end
    end
end)

test("Skin HUD: a cell draws the skin's texture, face and border while on, the player's picks off", function()
    -- red under: Row.lua reading `bars.texture` / `text.font` / `bars.borderStyle` directly, or
    -- NS.SkinMediaKey rewriting the stored pick.
    local inst, NS, window, row, cfg = scene(function(c)
        c.bars.texture, c.text.font = "GridTexture", "GridFont"
        c.bars.border, c.bars.borderStyle = true, "Grid Edge"
    end)
    local lsm = media(inst)
    lsm:Register("statusbar", "GridTexture", [[Interface\Grid]])
    lsm:Register("font", "GridFont", [[Interface\GridFont.ttf]])
    inst.mocks.__media.border["Grid Edge"] = [[Interface\GridEdge]]
    row:ApplyLayout(window.layout)
    local cell = row.cells.DamageDone
    assertEqual(cell.frame.__barTexture, skinFile(inst, NS, "statusbar", "bar.texture"), "the bar is not the skin's")
    assertEqual(cell.left.__font.path, skinFile(inst, NS, "font", "hud.font"), "the number is not in the skin's face")
    assertEqual(NS.Skin.Token("bar.borderStyle"), "None")
    assertTrue(cell.frame.__backdrop == nil or cell.frame.__backdrop.edgeFile == nil,
        "Ka0s Default's border style is None: the flat outline, no edge art")
    assertEqual(cfg.bars.texture, "GridTexture", "following the skin rewrote the stored pick")

    cfg.bars.textureFromSkin, cfg.text.fontFromSkin, cfg.bars.borderStyleFromSkin = false, false, false
    row:ApplyLayout(window.layout)
    assertEqual(cell.frame.__barTexture, [[Interface\Grid]], "the player's texture did not come back")
    assertEqual(cell.left.__font.path, [[Interface\GridFont.ttf]], "the player's face did not come back")
    assertEqual((cell.frame.__backdrop or {}).edgeFile, [[Interface\GridEdge]], "the player's border did not come back")
end)

test("Skin HUD: the title, the column labels and the tooltip resolve through the skin too", function()
    -- red under: Window_Header's headerFont / columnHeaderFont, or Tooltip's tooltipConfig,
    -- reading the stored pick past its companion.
    local inst, NS, window, _, cfg = scene()
    local face = skinFile(inst, NS, "font", "hud.font")
    assertEqual(window.frame.title.__font.path, face, "the title is not in the skin's face")
    local tip = NS.TooltipInternals.tooltipConfig(cfg)
    assertEqual(tip.font, NS.Skin.Token("hud.font"))
    assertEqual(tip.barTexture, NS.Skin.Token("bar.texture"))
    assertEqual(tip.barBorderStyle, NS.Skin.Token("bar.borderStyle"))

    cfg.tooltip.fontFromSkin, cfg.tooltip.barTextureFromSkin = false, false
    cfg.tooltip.barBorderStyleFromSkin = false
    tip = NS.TooltipInternals.tooltipConfig(cfg)
    assertEqual(tip.font, cfg.tooltip.font)
    assertEqual(tip.barTexture, cfg.tooltip.barTexture)
    assertEqual(tip.barBorderStyle, cfg.tooltip.barBorderStyle)

    cfg.header.fontFromSkin = false
    window:ApplyConfig()
    assertTrue(window.frame.title.__font.path ~= face, "the title kept the skin's face with its companion off")
end)

test("Skin HUD: a skin switch repaints the bars, and every color stays the player's", function()
    -- red under: the HUD not reached by OnLooksChanged (the bars keep the old skin's texture), or a
    -- skin switch writing a color (X4).
    local inst, NS, _, row, cfg = scene()
    local before = skinFile(inst, NS, "statusbar", "bar.texture")
    local color = { cfg.bars.customColor.r, cfg.bars.customColor.g, cfg.bars.customColor.b }
    inst.mocks.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "obsidian")
    local after = skinFile(inst, NS, "statusbar", "bar.texture")
    assertTrue(after ~= before, "Obsidian's bar texture is Ka0s Default's: this case asserts nothing")
    assertEqual(row.cells.DamageDone.frame.__barTexture, after, "the bars kept the old skin's texture")
    assertEqual(table.concat(color, ","), table.concat({ cfg.bars.customColor.r, cfg.bars.customColor.g,
        cfg.bars.customColor.b }, ","), "the skin switch moved a color")
end)

test("Skin HUD: the meta pair turns every surface's companion at once", function()
    -- red under: no meta row, or one that writes past the seam (no per-surface onChange).
    local inst = T.load()
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    NS.SetByPath("window.fontFromSkin", false)
    for _, g in ipairs({ "text", "header", "columnHeader", "tooltip" }) do
        assertEqual(cfg[g].fontFromSkin, false, g .. " kept following the skin's font")
    end
    NS.SetByPath("window.barTextureFromSkin", false)
    assertEqual(cfg.bars.textureFromSkin, false)
    assertEqual(cfg.tooltip.barTextureFromSkin, false)
    assertEqual(cfg.bars.borderStyleFromSkin, true, "the texture meta reached a border")
end)

-- ── the one-time reset (O2) ──────────────────────────────────────────────────────────────────

--- A v19-shaped window: the old template copied whole, no companions, the player's own picks.
local function v19Window(id)
    return {
        id = id,
        header = { font = "Arial Narrow", color = { r = 0.2, g = 0.4, b = 0.6, a = 1 } },
        text = { font = "Arial Narrow", size = 14 },
        bars = { texture = "Smooth", borderStyle = "None", customColor = { r = 1, g = 0, b = 0, a = 1 } },
        tooltip = { font = "Arial Narrow", barTexture = "Smooth", barBorderStyle = "None" },
        columnHeader = { font = "Arial Narrow" },
    }
end

test("Skin HUD: the v20 step puts every window of every profile on the skin, keeping the picks", function()
    -- red under: no v19 -> v20 step, one that walks db.profile alone, one that writes the "@skin"
    -- sentinel into a pick, or one that touches a color or a size.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 3, windows = { v19Window(1), v19Window(2) } },
                     Raid    = { nextWindowId = 8, windows = { v19Window(7) } } },
        global   = { schemaVersion = 19 },
    })
    local NS = inst.NS
    -- The walk goes on to v21 (MM-A1's chrome reset, tests/test_skin_window.lua), which touches
    -- no companion this case reads.
    assertEqual(NS.SCHEMA_VERSION, 21)
    assertEqual(NS.db.global.schemaVersion, 21)
    for _, name in ipairs({ "Default", "Raid" }) do
        for i, w in ipairs(NS.db.sv.profiles[name].windows) do
            local where = name .. " window " .. i
            for _, path in ipairs(NS.Database.FROM_SKIN_KEYS) do
                assertEqual(at(w, path), true, where .. ": " .. path .. " is not on the skin")
            end
            assertEqual(w.header.font, "Arial Narrow", where .. ": the face pick was rewritten")
            assertEqual(w.bars.texture, "Smooth", where .. ": the texture pick was rewritten")
            assertEqual(w.tooltip.barBorderStyle, "None", where .. ": the border pick was rewritten")
            assertEqual(w.header.color.b, 0.6, where .. ": a color moved")
            assertEqual(w.bars.customColor.r, 1, where .. ": a color moved")
            assertEqual(w.text.size, 14, where .. ": a size moved")
        end
    end
end)

test("Skin HUD: the v20 reset runs once, so a pick made after it is kept", function()
    -- red under: the reset re-run on every load (a shape fill or an unversioned pass), which would
    -- take back every companion the player turned off.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 2, windows = { v19Window(1) } } },
        global   = { schemaVersion = 19 },
    })
    local NS = inst.NS
    local w = NS.Database.FindWindow(1)
    assertEqual(w.bars.textureFromSkin, true)
    NS.SetByPath("window.bars.textureFromSkin", false)
    assertEqual(w.bars.textureFromSkin, false, "the write did not land: this case asserts nothing")
    NS:RunMigrations()
    assertEqual(w.bars.textureFromSkin, false, "a second walk took the player's pick back")

    -- And across a reload: the stamp the first load wrote holds the step off.
    local saved = _G.MultiMetersDB
    local again = initWith(saved)
    assertEqual(again.NS.db.global.schemaVersion, 21)
    assertEqual(again.NS.Database.FindWindow(1).bars.textureFromSkin, false, "a reload re-ran the reset")
    assertEqual(again.NS.Database.FindWindow(1).text.fontFromSkin, true)
end)

test("Skin HUD: the v20 step survives a junk window and leaves an absent group to the template", function()
    -- red under: a step that indexes a window or its group without a type guard.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 2, windows = { { id = 1, bars = "junk" } } },
                     Odd     = { windows = { "junk", v19Window(3) } } },
        global   = { schemaVersion = 19 },
    })
    local NS = inst.NS
    assertEqual(NS.db.sv.profiles.Odd.windows[1], "junk", "the step rewrote a non-window")
    assertEqual(NS.db.sv.profiles.Odd.windows[2].tooltip.fontFromSkin, true)
    local w = NS.db.sv.profiles.Default.windows[1]
    assertEqual(type(w.columnHeader), "table", "the shape fill did not run")
    assertEqual(w.columnHeader.fontFromSkin, true, "an absent group did not take the template's companion")
end)
