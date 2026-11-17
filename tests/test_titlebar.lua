-- tests/test_titlebar.lua — every title-bar control this addon draws itself (smoke round 1, SR-MM).
--
-- The owner's rulings 3 and 4 of 2026-11-16 (Ka0sAddonsCommonTasks
-- docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/SR1_SMOKE_ROUND1.md), for this addon's own windows:
--
--   * every title-bar control shows a one-line tooltip on hover, attached above it through
--     LibKa0s-Tooltip-1.0 (AttachTitleTip, PlaceAttached), in the owner's `gtip.title`;
--   * at rest every control paints the skin's `icon.tint`, under the pointer `text.link`; the close
--     X paints `icon.tint` at rest (the library's `close.rest` follows it in every skin) and
--     `close.hot` under the pointer.
--
-- Two windows carry a title bar of their own: the meter window (seven controls, modules/
-- HeaderControls.lua) and the Export modal (the library's close, modules/Export_Modal.lua). The
-- copy window the modal opens is the library's, and its own suite holds it.
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "MultiMeters"

-- Ka0s Default and one skin whose `icon.tint`, `text.link` and `close.hot` differ from it.
local SKINS = { "ka0s", "obsidian" }

-- The seven controls, every one switched on by default.
local KEYS = { "close", "minimize", "lock", "settings", "segment", "reset", "export" }

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

local function windowScene(skin)
    local inst = T.load{}
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    NS.WindowManager:Init()
    local window = NS.WindowManager.Get(cfg.id)
    assertTrue(window ~= nil, "the manager built no window for the first config")
    window:ApplyConfig()
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    if skin ~= "ka0s" then Skin:SetChoice(OWNER, "ka0s", skin) end
    return inst, NS, window
end

--- Hover `button` and answer what the game tooltip says, its color, and where it is placed.
local function hoverTip(inst, button)
    local tip = inst.mocks.GameTooltip
    local said
    local set = tip.SetText
    tip.SetText = function(self, text, r, g, b, ...)
        said = { text = text, r = r, g = g, b = b }
        return set(self, text, r, g, b, ...)
    end
    tip:Hide()
    button:_run("OnEnter")
    tip.SetText = set
    return said, tip
end

local function controlTint(button)
    if button.mmRung == "ascii" then return { button.glyph:GetTextColor() } end
    return button.tex.__vertexColor or {}
end

local function closeTint(button)
    if button.icon then return button.icon.__vertexColor or {} end
    return { button.glyph:GetTextColor() }
end

-- ── the meter window ─────────────────────────────────────────────────────────────────────────

test("Title bar: every meter-window header control shows a tooltip in gtip.title, and hides it on leave", function()
    -- red under: a control with no AttachTitleTip (no SetText on hover), words that are empty, or a
    -- tooltip left standing after the pointer leaves.
    for _, skin in ipairs(SKINS) do
        local inst, NS, window = windowScene(skin)
        local title = token(NS, "gtip.title")
        for _, key in ipairs(KEYS) do
            local button = window.controls[key]
            assertTrue(button ~= nil and button:IsShown(), skin .. ": the " .. key .. " control is not drawn")
            local said, tip = hoverTip(inst, button)
            assertTrue(said ~= nil, skin .. ": the " .. key .. " control shows no tooltip")
            assertTrue(type(said.text) == "string" and said.text ~= "",
                skin .. ": the " .. key .. " control's tooltip is empty")
            sameColor({ said.r, said.g, said.b }, title, skin .. ": the " .. key .. " tooltip is gtip.title")
            assertTrue(tip:GetOwner() == button, skin .. ": the " .. key .. " tooltip is not owned by its control")
            button:_run("OnLeave")
            assertTrue(not tip:IsShown(), skin .. ": the " .. key .. " tooltip outlives the pointer")
        end
    end
end)

test("Title bar: the two state controls say what a click does, and change their words with the state", function()
    -- red under: fixed words on the lock or the minimize, which then lie in one of their two states.
    local inst, _, window = windowScene("ka0s")
    local cfg = window.config.frame
    cfg.locked, cfg.minimized = false, false
    local lockOff = hoverTip(inst, window.controls.lock).text
    local minOff = hoverTip(inst, window.controls.minimize).text
    cfg.locked, cfg.minimized = true, true
    local lockOn = hoverTip(inst, window.controls.lock).text
    local minOn = hoverTip(inst, window.controls.minimize).text
    assertEqual(lockOff, "Lock window")
    assertEqual(lockOn, "Unlock window")
    assertEqual(minOff, "Minimize window")
    assertEqual(minOn, "Expand window")
    assertEqual(hoverTip(inst, window.controls.close).text, "Close")
end)

test("Title bar: meter-window controls rest in icon.tint and light in text.link; the close lights in close.hot", function()
    -- red under: the hover still on btn.hover, the close resting in a color of its own, or the close
    -- lighting in text.link instead of its red.
    for _, skin in ipairs(SKINS) do
        local _, NS, window = windowScene(skin)
        local rest, hot, closeHot = token(NS, "icon.tint"), token(NS, "text.link"), token(NS, "close.hot")
        for _, key in ipairs(KEYS) do
            local button = window.controls[key]
            sameColor(controlTint(button), rest, skin .. ": " .. key .. " at rest is icon.tint")
            button:_run("OnEnter")
            sameColor(controlTint(button), key == "close" and closeHot or hot,
                skin .. ": " .. key .. " under the pointer")
            button:_run("OnLeave")
            sameColor(controlTint(button), rest, skin .. ": " .. key .. " back at rest")
        end
    end
end)

-- ── the Export modal ─────────────────────────────────────────────────────────────────────────

test("Title bar: the Export modal's close says Close above it and paints icon.tint, then close.hot", function()
    -- red under: a close built without the owner (no skin, no tooltip), or one whose rest color is
    -- not the skin's control tint.
    for _, skin in ipairs(SKINS) do
        local inst = T.load{}
        local NS = inst.NS
        local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
        if skin ~= "ka0s" then Skin:SetChoice(OWNER, "ka0s", skin) end
        local modal = NS.Export.Open({})
        assertTrue(type(modal) == "table", skin .. ": the modal opened")
        local close = modal.closeButton
        assertTrue(close ~= nil, skin .. ": the modal has no close")
        sameColor(closeTint(close), token(NS, "icon.tint"), skin .. ": the close at rest")
        local said, tip = hoverTip(inst, close)
        assertTrue(said ~= nil and said.text == "Close", skin .. ": the close says " .. tostring(said and said.text))
        sameColor({ said.r, said.g, said.b }, token(NS, "gtip.title"), skin .. ": the close's tooltip")
        sameColor(closeTint(close), token(NS, "close.hot"), skin .. ": the close under the pointer")
        close:_run("OnLeave")
        assertTrue(not tip:IsShown(), skin .. ": the close's tooltip outlives the pointer")
        modal:Hide()
    end
end)
