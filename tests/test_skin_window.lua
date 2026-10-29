-- tests/test_skin_window.lua — the meter window's chrome following the skin (the rollout's MM-A1,
-- the owner's ruling R-3 over DECISIONS X4 for this window: the inventory's D1, D3, D4 and D16).
--
-- Five chrome settings take a `skin` value beside `class` and `custom`, and ship on it: the window
-- fill (`frame.backdropColorMode`, `win.bg`), the window edge (`frame.borderColorMode`: the Shell
-- draws the skin's own edge, its style, size, color and inner rule), the title text
-- (`header.colorMode`, `title.text`) and the two header-control colors (`frame.controlColorMode`,
-- `icon.tint`; `frame.controlHoverColorMode`, `btn.hover`). The title bar background has no mode and
-- takes a companion instead, `header.bgColorFromSkin` (`title.bg`). The v21 step puts every stored
-- window on all six once; a pick made after it is kept.
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "MultiMeters"

-- The five modes and the companion, as dotted paths into a window.
local MODES = {
    "frame.backdropColorMode", "frame.borderColorMode", "header.colorMode",
    "frame.controlColorMode", "frame.controlHoverColorMode",
}
local COMPANION = "header.bgColorFromSkin"

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

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

local function sameColor(got, want, msg)
    for i = 1, #want do
        assertTrue(near(got[i], want[i]), ("%s: channel %d is %s, want %s"):format(msg, i,
            tostring(got[i]), tostring(want[i])))
    end
end

--- A token's color for this owner; a clear one for a token the skin sets to none.
local function token(NS, name)
    local r, g, b, a = NS.Skin.Color(name)
    if r == nil then return { 0, 0, 0, 0 } end
    return { r, g, b, a or 1 }
end

--- A fresh instance with its first window managed and configured, so the OnLooksChanged listener
--- (WindowManager:Reskin) reaches it.
local function scene(configure)
    local inst = T.load{}
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    if configure then configure(cfg) end
    NS.WindowManager:Init()
    local window = NS.WindowManager.Get(cfg.id)
    assertTrue(window ~= nil, "the manager built no window for the first config")
    window:ApplyConfig()
    return inst, NS, window, cfg, inst.mocks.LibStub("LibKa0s-Skin-1.0")
end

local function fill(f) return f.__backdropColor or {} end

--- The Shell's edge ring on the window's edge holder, or nil while it draws none.
local function shellEdge(Skin, f)
    local regions = Skin.__regions and Skin.__regions[f]
    local t = regions and regions.edgeTop
    if t and t:IsShown() then return t.__colorTexture or {} end
    return nil
end

local function tint(button) return button.tex.__vertexColor or {} end

--- Every chrome surface against the skin's tokens: the fill, the Shell's edge, the title bar
--- background, the title, and both control colors.
local function assertFollows(NS, window, Skin, label)
    local f = window.frame
    sameColor(fill(f), token(NS, "win.bg"), label .. ": the fill is win.bg")
    local edge = shellEdge(Skin, f)
    assertTrue(edge ~= nil, label .. ": the Shell draws no edge, so the window wears the player's")
    sameColor(edge, token(NS, "win.border"), label .. ": the edge is win.border")
    sameColor(window.headerBG.__colorTexture or {}, token(NS, "title.bg"), label .. ": the title bar is title.bg")
    local tt = token(NS, "title.text")
    sameColor({ f.title:GetTextColor() }, { tt[1], tt[2], tt[3] }, label .. ": the title is title.text")
    local rest, hover = token(NS, "icon.tint"), token(NS, "btn.hover")
    local button = window.controls.settings
    sameColor(tint(button), { rest[1], rest[2], rest[3] }, label .. ": a control at rest is icon.tint")
    button:_run("OnEnter")
    sameColor(tint(button), { hover[1], hover[2], hover[3] }, label .. ": a hovered control is btn.hover")
    button:_run("OnLeave")
end

-- ── what ships ───────────────────────────────────────────────────────────────────────────────

test("Skin window: the five chrome modes and the title bar companion ship on the skin", function()
    -- red under: a mode still shipping `custom` (a new or reset window would wear the pre-ruling
    -- chrome), a row whose default disagrees with the template, or a mode row with no Skin value.
    local inst = T.load()
    local NS = inst.NS
    for _, path in ipairs(MODES) do
        assertEqual(at(NS.WINDOW_TEMPLATE, path), "skin", path .. " does not ship on the skin")
        local row = rowAt(NS, "window." .. path)
        assertTrue(row ~= nil, "window." .. path .. " is not a schema row")
        assertEqual(row.default, "skin", "window." .. path .. "'s row does not default to skin")
        for _, v in ipairs({ "skin", "class", "custom" }) do
            assertTrue(row.values[v] ~= nil, "window." .. path .. " offers no " .. v)
        end
        assertEqual(row.sorting[1], "skin", "window." .. path .. " does not list Skin first")
    end
    assertEqual(at(NS.WINDOW_TEMPLATE, COMPANION), true, COMPANION .. " does not ship on")
    local row = rowAt(NS, "window." .. COMPANION)
    assertTrue(row ~= nil and row.type == "bool" and row.default == true, "no companion row defaulted on")
    assertTrue(rowAt(NS, "window.header.bgColor").disabledIf == nil,
        "options-ui-§17: a color row is never disabled, the swatch is read when the companion is off")
end)

-- ── following ────────────────────────────────────────────────────────────────────────────────

test("Skin window: under Ka0s Default the window wears Ka0s Default's own chrome", function()
    -- red under: ApplyBorder laying the shipped black fill or the LSM edge over the Shell, the
    -- Shell still called with noBorder, or a header surface read off its stored color.
    local _, NS, window, _, Skin = scene()
    assertTrue(near(token(NS, "win.bg")[4], 0.92), "Ka0s Default's win.bg moved: this case reads the wrong token")
    assertFollows(NS, window, Skin, "Ka0s Default")
end)

test("Skin window: the chrome follows each skin live, and ApplyBorder re-runs after the repaint", function()
    -- red under: no OnLooksChanged re-ApplyConfig (the old skin's fill and title bar stay), or a
    -- chrome color cached anywhere a skin switch does not refresh.
    local _, NS, window, _, Skin = scene()
    local calls, real = 0, window.ApplyBorder
    window.ApplyBorder = function(self, ...) calls = calls + 1; return real(self, ...) end
    local ka0s = token(NS, "win.bg")
    for _, key in ipairs({ "obsidian", "azeroth" }) do
        local before = calls
        Skin:SetChoice(OWNER, "ka0s", key)
        assertTrue(calls > before, key .. ": ApplyBorder did not re-run after the repaint")
        local now = token(NS, "win.bg")
        assertFalse(near(now[1], ka0s[1]) and near(now[2], ka0s[2]) and near(now[3], ka0s[3]) and near(now[4], ka0s[4]),
            key .. "'s win.bg is Ka0s Default's: the case is moot")
        assertFollows(NS, window, Skin, key)
    end
    window.ApplyBorder = real
end)

test("Skin window: hovering a control reads no token", function()
    -- red under: controlColor calling NS.Skin.Color per hover (R2: the colors are resolved once,
    -- into the window's skinLooks, on ApplyConfig).
    local _, NS, window = scene()
    local calls, real = 0, NS.Skin.Color
    NS.Skin.Color = function(...) calls = calls + 1; return real(...) end
    local button = window.controls.settings
    for _ = 1, 3 do
        button:_run("OnEnter")
        button:_run("OnLeave")
    end
    window:ApplyTitle()
    NS.Skin.Color = real
    assertEqual(calls, 0, "a hover or a title pass read a token")
end)

-- ── the player's own picks ───────────────────────────────────────────────────────────────────

test("Skin window: switched back to custom, every surface draws the player's color again", function()
    -- red under: a `skin` mode that rewrote the stored color, or a custom edge that kept the
    -- Shell's ring drawn under the player's LSM edge.
    local inst, NS, window, cfg, Skin = scene()
    inst.mocks.__media.border["Grid Edge"] = [[Interface\GridEdge]]
    cfg.frame.backdropColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }
    cfg.frame.borderStyle, cfg.frame.borderSize = "Grid Edge", 3
    cfg.frame.borderColor = { r = 0.5, g = 0.6, b = 0.7, a = 1 }
    cfg.header.bgColor = { r = 0.9, g = 0.1, b = 0.1, a = 0.5 }
    cfg.header.color = { r = 0.2, g = 0.9, b = 0.2, a = 1 }
    cfg.frame.controlColor = { r = 0, g = 0, b = 1, a = 1 }
    cfg.frame.controlHoverColor = { r = 0, g = 1, b = 0, a = 1 }
    window:ApplyConfig()
    assertFollows(NS, window, Skin, "still on the skin")
    assertEqual(cfg.frame.backdropColor.r, 0.1, "following the skin rewrote the stored fill")

    for _, path in ipairs(MODES) do NS.SetByPath("window." .. path, "custom") end
    NS.SetByPath("window." .. COMPANION, false)
    local f = window.frame
    sameColor(fill(f), { 0.1, 0.2, 0.3, 0.4 }, "the fill")
    assertEqual((f.__backdrop or {}).edgeFile, [[Interface\GridEdge]], "the player's edge style")
    assertEqual((f.__backdrop or {}).edgeSize, 3, "the player's edge thickness")
    sameColor(f.__backdropBorderColor or {}, { 0.5, 0.6, 0.7, 1 }, "the edge color")
    assertTrue(shellEdge(Skin, f) == nil, "the Shell's edge is still drawn under the player's")
    sameColor(window.headerBG.__colorTexture or {}, { 0.9, 0.1, 0.1, 0.5 }, "the title bar")
    sameColor({ f.title:GetTextColor() }, { 0.2, 0.9, 0.2 }, "the title")
    local button = window.controls.settings
    sameColor(tint(button), { 0, 0, 1 }, "a control at rest")
    button:_run("OnEnter")
    sameColor(tint(button), { 0, 1, 0 }, "a hovered control")
    button:_run("OnLeave")

    -- And the player's picks hold across a skin switch.
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    sameColor(fill(f), { 0.1, 0.2, 0.3, 0.4 }, "the fill after a skin switch")
    assertEqual((f.__backdrop or {}).edgeFile, [[Interface\GridEdge]], "the edge after a skin switch")
    sameColor(window.headerBG.__colorTexture or {}, { 0.9, 0.1, 0.1, 0.5 }, "the title bar after a skin switch")
end)

test("Skin window: class mode still takes the local player's class on every chrome surface", function()
    local inst, _, window, cfg = scene(function(c)
        for _, path in ipairs(MODES) do
            local group, leaf = path:match("^([^.]+)%.(.+)$")
            c[group][leaf] = "class"
        end
    end)
    local cr, cg, cb = inst.NS.PlayerClassRGB()
    assertTrue(cr ~= nil, "the scene has no readable class to color with")
    local f = window.frame
    local a = cfg.frame.backdropColor.a
    sameColor(fill(f), { cr, cg, cb, a }, "the fill keeps its alpha under class")
    sameColor({ f.title:GetTextColor() }, { cr, cg, cb }, "the title")
    sameColor(tint(window.controls.settings), { cr, cg, cb }, "a control at rest")
end)

test("Skin window: without the library the Skin modes draw the stored colors, the pre-skin look", function()
    -- DEGRADED-11: with no LibKa0s there is no skin to follow, so a `skin` mode falls back to the
    -- swatch beside it, as the HUD companions fall back to the stored pick (NS.SkinMediaKey).
    -- red under: NS.SkinWindowLooks answering the host copy for the chrome, or the edge left to a
    -- Shell that cannot draw one.
    local inst = T.load{ libFiles = {} }
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.backdropColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }
    cfg.header.color = { r = 0.2, g = 0.9, b = 0.2, a = 1 }
    cfg.header.bgColor = { r = 0.9, g = 0.1, b = 0.1, a = 0.5 }
    cfg.frame.controlColor = { r = 0, g = 0, b = 1, a = 1 }
    local window = NS.Window.New(cfg)
    window:ApplyConfig()
    assertEqual(cfg.frame.backdropColorMode, "skin", "the case is moot off the Skin mode")
    for _, field in ipairs({ "winBg", "titleText", "titleBg", "controlRest", "controlHover" }) do
        assertTrue(window.skinLooks[field] == nil, field .. " answered a color with no skin to follow")
    end
    local f = window.frame
    sameColor(fill(f), { 0.1, 0.2, 0.3, 0.4 }, "the fill")
    sameColor({ f.title:GetTextColor() }, { 0.2, 0.9, 0.2 }, "the title")
    sameColor(window.headerBG.__colorTexture or {}, { 0.9, 0.1, 0.1, 0.5 }, "the title bar")
    if window.controls and window.controls.settings then
        sameColor(tint(window.controls.settings), { 0, 0, 1 }, "a control at rest")
    end
end)

-- ── the one-time reset (O2, the owner's ruling R-3) ──────────────────────────────────────────

--- A v20-shaped window: the chrome on the player's own modes, no title bar companion.
local function v20Window(id, mode)
    return {
        id = id,
        frame = { backdropColorMode = mode, borderColorMode = mode, controlColorMode = mode,
                  controlHoverColorMode = mode, backdropColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 },
                  borderStyle = "Blizzard Tooltip", borderSize = 2 },
        header = { colorMode = mode, bgColor = { r = 0.9, g = 0.1, b = 0.1, a = 0.5 } },
    }
end

local function initWith(saved)
    local inst = T.load{ initDB = false, options = false }
    _G.MultiMetersDB = saved
    inst.NS:InitDB()
    return inst
end

local function assertOnSkin(w, where)
    for _, path in ipairs(MODES) do
        assertEqual(at(w, path), "skin", where .. ": " .. path .. " is not on the skin")
    end
    assertEqual(at(w, COMPANION), true, where .. ": " .. COMPANION .. " is not on")
end

test("Skin window: the v21 step puts every window of every profile's chrome on the skin", function()
    -- red under: no v20 -> v21 step, one that walks db.profile alone, one that leaves a `class`
    -- pick, or one that rewrites a stored color or the edge style.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 3, windows = { v20Window(1, "custom"), v20Window(2, "class") } },
                     Raid    = { nextWindowId = 8, windows = { v20Window(7, "custom") } } },
        global   = { schemaVersion = 20 },
    })
    local NS = inst.NS
    assertEqual(NS.SCHEMA_VERSION, 21)
    assertEqual(NS.db.global.schemaVersion, 21)
    for _, name in ipairs({ "Default", "Raid" }) do
        for i, w in ipairs(NS.db.sv.profiles[name].windows) do
            local where = name .. " window " .. i
            assertOnSkin(w, where)
            assertEqual(w.frame.backdropColor.r, 0.1, where .. ": the stored fill was rewritten")
            assertEqual(w.header.bgColor.r, 0.9, where .. ": the stored title bar color was rewritten")
            assertEqual(w.frame.borderStyle, "Blizzard Tooltip", where .. ": the edge style was rewritten")
        end
    end
end)

test("Skin window: the v21 reset runs once, so a pick made after it is kept", function()
    -- red under: the reset re-run on every load, which would take back every mode the player set.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 2, windows = { v20Window(1, "custom") } } },
        global   = { schemaVersion = 20 },
    })
    local NS = inst.NS
    local w = NS.Database.FindWindow(1)
    assertOnSkin(w, "after the step")
    NS.SetByPath("window.frame.backdropColorMode", "custom")
    NS.SetByPath("window." .. COMPANION, false)
    assertEqual(w.frame.backdropColorMode, "custom", "the write did not land: this case asserts nothing")
    NS:RunMigrations()
    assertEqual(w.frame.backdropColorMode, "custom", "a second walk took the player's pick back")
    assertEqual(w.header.bgColorFromSkin, false, "a second walk took the player's pick back")

    local again = initWith(_G.MultiMetersDB)
    assertEqual(again.NS.db.global.schemaVersion, 21)
    local w2 = again.NS.Database.FindWindow(1)
    assertEqual(w2.frame.backdropColorMode, "custom", "a reload re-ran the reset")
    assertEqual(w2.header.bgColorFromSkin, false, "a reload re-ran the reset")
    assertEqual(w2.frame.borderColorMode, "skin")
end)

test("Skin window: a v19 account takes both resets in one walk", function()
    -- red under: the v21 step depending on a group the v20 step backfills, or the runner stopping
    -- at v20.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 2, windows = { v20Window(1, "custom") } } },
        global   = { schemaVersion = 19 },
    })
    local w = inst.NS.Database.FindWindow(1)
    assertEqual(inst.NS.db.global.schemaVersion, 21)
    assertOnSkin(w, "v19 window")
    assertEqual(w.header.fontFromSkin, true, "the v20 companions did not land")
end)

test("Skin window: the v21 step survives a junk window and leaves an absent group to the template", function()
    local inst = initWith({
        profiles = { Default = { nextWindowId = 2, windows = { { id = 1, frame = "junk" } } },
                     Odd     = { windows = { "junk", v20Window(3, "custom") } } },
        global   = { schemaVersion = 20 },
    })
    local NS = inst.NS
    assertEqual(NS.db.sv.profiles.Odd.windows[1], "junk", "the step rewrote a non-window")
    assertOnSkin(NS.db.sv.profiles.Odd.windows[2], "Odd window 2")
    local w = NS.db.sv.profiles.Default.windows[1]
    assertEqual(type(w.header), "table", "the shape fill did not run")
    assertEqual(w.header.colorMode, "skin", "an absent group did not take the template's mode")
    assertEqual(w.header.bgColorFromSkin, true, "an absent group did not take the template's companion")
end)
