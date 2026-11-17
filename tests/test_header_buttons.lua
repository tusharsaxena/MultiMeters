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
--   * the Export modal, whose settings mark and close are HeaderButtons' outright. It sits at
--     DIALOG, over the settings panel, so it hides itself before the panel opens (hideOnSettings).
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

local function token(NS, name)
    local r, g, b = NS.Skin.Color(name)
    assertTrue(r ~= nil, name .. " answers no color")
    return { r, g, b }
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

-- ── the Export modal ─────────────────────────────────────────────────────────────────────────

local function modalScene(skin)
    local inst = T.load{}
    local NS = inst.NS
    if skin and skin ~= "ka0s" then inst.mocks.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", skin) end
    local modal = NS.Export.Open({})
    assertTrue(type(modal) == "table", "the modal opened")
    return inst, NS, modal
end

test("Header buttons: the Export modal's title bar reads settings · close, HeaderButtons'", function()
    -- red under: the modal's close built alone through NS.MakeCloseButton (no settings mark).
    local inst, _, modal = modalScene()
    local H = header(inst)
    local hb = modal.headerButtons
    assertTrue(type(hb) == "table", "the modal's marks were not built by W.HeaderButtons")
    assertEqual(table.concat(hb.order, ","), "settings,close", "the modal's order")
    assertTrue(modal.closeButton == hb.close and hb.close ~= nil, "the modal's close is not HeaderButtons'")
    assertTrue(modal.settingsButton == hb.settings and hb.settings ~= nil, "the modal has no settings mark")
    assertEqual(offsetOf(hb.close, modal.titleBar), -H.PAD, "the close's corner offset")
    assertEqual(offsetOf(hb.settings, modal.titleBar), -(H.PAD + H.SIZE + H.GAP), "the settings mark's offset")
    modal:Hide()
end)

test("Header buttons: the Export modal's settings mark hides the modal, then opens this addon's settings", function()
    -- The modal is DIALOG strata and would sit over the settings panel, so it goes first
    -- (hideOnSettings); the panel is the launcher's registered opener for this folder.
    -- red under: no hideOnSettings (the modal stays up over the panel), or an owner other than the
    -- launcher's `name` (the mark opens nothing).
    local _, NS, modal = modalScene()
    local opened, shownAtOpen = 0, nil
    NS.OpenOptionsPanel = function()
        opened = opened + 1
        shownAtOpen = modal:IsShown()
    end
    assertTrue(modal:IsShown(), "the modal is not open")
    modal.settingsButton:_run("OnClick")
    assertEqual(opened, 1, "the modal's settings mark opened nothing")
    assertEqual(shownAtOpen, false, "the modal was still up when the panel opened")
end)

test("Header buttons: the Export modal's settings mark says Open settings, icon.tint at rest, text.link hovered", function()
    -- red under: a settings mark with no tooltip, or painted outside the title-bar color rule.
    for _, skin in ipairs({ "ka0s", "obsidian" }) do
        local inst, NS, modal = modalScene(skin)
        local mark = modal.settingsButton
        local tip = inst.mocks.GameTooltip
        local said
        local set = tip.SetText
        tip.SetText = function(self, text, r, g, b, ...)
            said = { text = text, r = r, g = g, b = b }
            return set(self, text, r, g, b, ...)
        end
        assertTrue(mark.icon ~= nil, skin .. ": the settings mark draws no art")
        sameColor(mark.icon.__vertexColor or {}, token(NS, "icon.tint"), skin .. ": the settings mark at rest")
        mark:_run("OnEnter")
        tip.SetText = set
        assertTrue(said ~= nil and said.text == "Open settings", skin .. ": the settings mark says " ..
            tostring(said and said.text))
        sameColor({ said.r, said.g, said.b }, token(NS, "gtip.title"), skin .. ": its tooltip")
        sameColor(mark.icon.__vertexColor or {}, token(NS, "text.link"), skin .. ": the settings mark hovered")
        mark:_run("OnLeave")
        assertTrue(not tip:IsShown(), skin .. ": the tooltip outlives the pointer")
        sameColor(mark.icon.__vertexColor or {}, token(NS, "icon.tint"), skin .. ": back at rest")
        modal:Hide()
    end
end)
