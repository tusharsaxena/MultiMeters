-- tests/test_header_buttons.lua — this addon's own title bars on LibKa0s-Widgets-1.0's
-- HeaderButtons (AD-86-MM, LibKa0s#86; standalone-windows, *Title-bar controls*, v2.113.0).
--
-- The owner's ruling Q3 of 2026-11-16: every window's title-bar marks read, left to right, the
-- window's own extras · settings · close, the close in the corner and the settings mark beside it,
-- built by `W.HeaderButtons` and opening this addon's settings. Two windows here carry a title bar
-- of their own:
--
--   * the meter window, whose seven marks are modules/HeaderControls.lua's. HeaderButtons builds
--     them (the order, the settings mark, the close through MakeCloseButton); HeaderControls keeps
--     placing them at the library's HEADER pitch because three player options re-lay the strip on
--     every ApplyHeader (the per-mark toggles, Control size, the header height), recorded in
--     docs/ARCHITECTURE.md's deviation register;
--   * the Export modal, whose close is HeaderButtons' outright. It is a companion of the meter
--     window that opened it (standard v2.119.0, *Settings is on every window but a companion*), so
--     it is built with companion = true and carries no settings mark (FB-MM-01).
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change and an opened modal are session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "MultiMeters"

-- Left to right, as the player reads the strip.
local METER_ORDER = { "export", "reset", "segment", "lock", "minimize", "settings", "close" }

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

local function sameColor(got, want, msg)
    for i = 1, 3 do
        assertTrue(near(got[i], want[i]), ("%s: channel %d is %s, want %s"):format(msg, i,
            tostring(got[i]), tostring(want[i])))
    end
end

--- The x offset `button` was anchored at off `rel`'s right edge (its RIGHT point), from the
--- RECORDED point: the mock's GetLeft/GetRight answer a constant, so a getter would pass anything.
local function offsetOf(button, rel)
    for _, p in ipairs(button.__points or {}) do
        if p.point == "RIGHT" and (rel == nil or p.rel == rel or p.relativeTo == rel) then return p.x end
    end
    return nil
end

local function windowScene()
    local inst = T.load{}
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    NS.WindowManager:Init()
    local window = NS.WindowManager.Get(cfg.id)
    assertTrue(window ~= nil, "the manager built no window for the first config")
    window:ApplyConfig()
    return inst, NS, window
end

local function header(inst)
    local W = inst.mocks.LibStub("LibKa0s-Widgets-1.0")
    assertTrue(type(W.HeaderButtons) == "function", "the vendored Widgets has no HeaderButtons")
    return W.HEADER
end

-- ── the meter window ─────────────────────────────────────────────────────────────────────────

test("Header buttons: the meter window's seven marks are HeaderButtons', extras · settings · close", function()
    -- red under: HeaderControls building its own buttons (no headerButtons record), or the gear left
    -- inward of the padlock and minimize, where the rule puts it beside the close.
    local _, _, window = windowScene()
    local hb = window.headerButtons
    assertTrue(type(hb) == "table", "the meter window's marks were not built by W.HeaderButtons")
    assertEqual(table.concat(hb.order, ","), table.concat(METER_ORDER, ","), "the strip's order")
    assertTrue(hb.close ~= nil and window.controls.close == hb.close, "the close is not HeaderButtons'")
    assertTrue(hb.settings ~= nil and window.controls.settings == hb.settings,
        "the settings mark is not HeaderButtons'")
    for _, key in ipairs({ "export", "reset", "segment", "lock", "minimize" }) do
        assertTrue(hb.extras[key] ~= nil and window.controls[key] == hb.extras[key], key .. " is not an extra")
    end
    assertTrue(hb.optOut == nil, "the meter window opted out of its settings mark")
end)

test("Header buttons: the meter strip sits HEADER.PAD in from the band's corner, HEADER.GAP apart", function()
    -- The standard's one pitch: 6 px from the corner, 6 px between marks, 18 px slots (the shipped
    -- Control size). Re-pinned from the 4 px gap and the player's padding at the corner (AD-86-MM).
    -- red under: GAP = 4, or the corner offset taken from frame.padding less the edge.
    local inst, _, window = windowScene()
    local H = header(inst)
    local x = H.PAD
    for i = #METER_ORDER, 1, -1 do
        local key = METER_ORDER[i]
        assertEqual(offsetOf(window.controls[key], window.headerBand), -x, key .. "'s offset off the band's corner")
        x = x + 18 + H.GAP
    end
end)

test("Header buttons: the meter window's settings mark opens the settings on its own window", function()
    -- Through HeaderButtons' settings click (the mark's own OnClick), which runs this addon's opener:
    -- the active window first, then the panel.
    -- red under: a settings mark whose click is not wired to the opener, or one that opens the panel
    -- on whichever window the picker was left on.
    local _, NS, window = windowScene()
    local opened, activeAtOpen = 0, nil
    NS.State.SetActiveWindow(999)
    NS.OpenOptionsPanel = function()
        opened = opened + 1
        activeAtOpen = NS.State.activeWindowId
    end
    window.headerButtons.settings:_run("OnClick")
    assertEqual(opened, 1, "the settings mark opened nothing")
    assertEqual(activeAtOpen, window.id, "the panel opened on another window")
end)

-- ── a skin switch keeps the player's control colors (AD-86-MM review) ─────────────────────────
--
-- Every HeaderButton records a repaint with the library (Widgets' __onSkin), and that listener is
-- registered when the window is built, after WindowManager's file-load Reskin listener. So on a
-- switch the library's rest paint (icon.tint) ran LAST, over the Custom or Class color Reskin had
-- just laid. HeaderControls re-lays the strip from a listener of its own, registered after the
-- library's.

local CUSTOM = { 0.2, 0.4, 0.6 }

local function customScene(configure)
    local inst = T.load{}
    local NS = inst.NS
    if configure then configure(inst) end
    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.controlColorMode = "custom"
    cfg.frame.controlColor = { r = CUSTOM[1], g = CUSTOM[2], b = CUSTOM[3], a = 1 }
    NS.WindowManager:Init()
    local window = NS.WindowManager.Get(cfg.id)
    assertTrue(window ~= nil, "the manager built no window for the first config")
    window:ApplyConfig()
    return inst, NS, window
end

test("Header buttons: a Custom control color survives a skin switch on all seven marks", function()
    -- red under: the library's per-mark repaint running after Reskin (six marks back at icon.tint).
    local inst, _, window = customScene()
    for _, key in ipairs(METER_ORDER) do
        sameColor(window.controls[key].tex.__vertexColor or {}, CUSTOM, key .. " before the switch")
    end
    inst.mocks.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "obsidian")
    for _, key in ipairs(METER_ORDER) do
        sameColor(window.controls[key].tex.__vertexColor or {}, CUSTOM, key .. " after the switch")
    end
end)

test("Header buttons: on the ASCII rung a skin switch keeps the glyphs' header font and Custom color", function()
    -- With no art at build the library hands each extra a skin-fonted word, which this file adopts as
    -- its glyph. red under: the skin's font record or the library's repaint replaying over drawIcon's.
    local inst, NS, window = customScene(function(i)
        i.mocks.LibStub("LibKa0s-Media-1.0").Icon = function() return nil end
        i.mocks.setAtlases({})
    end)
    local style = NS.HeaderControls.Style(window)
    local function check(when)
        for _, key in ipairs(METER_ORDER) do
            local b = window.controls[key]
            assertEqual(b.mmRung, "ascii", key .. " " .. when .. ": the rung")
            if key ~= "close" then
                sameColor({ b.glyph:GetTextColor() }, CUSTOM, key .. " " .. when .. ": the glyph color")
            end
            local path, size = b.glyph:GetFont()
            assertEqual(path, style.path, key .. " " .. when .. ": the glyph face")
            assertEqual(size, style.size, key .. " " .. when .. ": the glyph size")
        end
    end
    check("before the switch")
    inst.mocks.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", "obsidian")
    style = NS.HeaderControls.Style(window)
    check("after the switch")
end)

-- ── the Export modal ─────────────────────────────────────────────────────────────────────────

local function modalScene(skin)
    local inst = T.load{}
    local NS = inst.NS
    if skin and skin ~= "ka0s" then inst.mocks.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", skin) end
    local modal = NS.Export.Open({})
    assertTrue(type(modal) == "table", "the modal opened")
    return inst, NS, modal
end

test("Header buttons: the Export modal is a companion, its title bar reads the close alone", function()
    -- The modal opens only from a meter window's export mark (or /mm export, through that window),
    -- exports that window's segment and keeps no position of its own, so it is a companion
    -- (standalone-windows, *Settings is on every window but a companion*, standard v2.119.0):
    -- W.HeaderButtons with companion = true, no settings mark and no waiver reason.
    -- red under: the modal still building the gear (no companion key), or a waiver in its place.
    local inst, _, modal = modalScene()
    local H = header(inst)
    local hb = modal.headerButtons
    assertTrue(type(hb) == "table", "the modal's marks were not built by W.HeaderButtons")
    assertEqual(hb.companion, true, "the modal is not built as a companion")
    assertEqual(hb.settings, nil, "the modal still carries a settings mark")
    assertEqual(hb.optOut, nil, "the modal took the waiver path, not the companion one")
    assertEqual(table.concat(hb.order, ","), "close", "the modal's order")
    assertTrue(modal.closeButton == hb.close and hb.close ~= nil, "the modal's close is not HeaderButtons'")
    assertEqual(modal.settingsButton, nil, "the modal still records a settings mark")
    assertEqual(offsetOf(hb.close, modal.titleBar), -H.PAD, "the close's corner offset")
    modal:Hide()
end)

test("Header buttons: the Export modal's close hides it, in every skin", function()
    -- red under: a close wired to anything but the modal's own Hide.
    for _, skin in ipairs({ "ka0s", "obsidian" }) do
        local _, _, modal = modalScene(skin)
        assertTrue(modal:IsShown(), skin .. ": the modal is not open")
        modal.closeButton:_run("OnClick")
        assertEqual(modal:IsShown(), false, skin .. ": the close left the modal up")
    end
end)
