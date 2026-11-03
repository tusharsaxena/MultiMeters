-- tests/test_header_band.lua — the meter window's title band (R5-MM1 and R5-WIN of Ka0sAddonsCommonTasks
-- docs/2026-11-03-SMOKE_ROUND5, the owner's feedback items 2 and 5, the lead's calls 2 and 6).
--
-- The band is one frame, `window.headerBand`, laid flush inside the window's edge at the inset the
-- edge itself needs: S.Shell's rule while the skin draws the edge (a flat edge's `win.borderSize`,
-- else 1), the player's edge size under `class` or `custom`. It is TitleBandHeight() high (30 at the
-- shipped settings, LootHistory's bar). The tinted strip (`headerBG`) fills it, in the skin's title
-- gradient (`title.bgTop` to `title.bgBottom`) while the companion is on and flat otherwise, and
-- the drag strip covers it. Every header child, the title, the session line and each control, is
-- anchored LEFT or RIGHT to the band at y 0, so it sits on the band's middle in every skin. A
-- collapsed window is exactly the band plus its edges. Headless, only the anchor shape is measured
-- (the mock measures no glyph); the glyphs' baseline is the owner's smoke check (WIN-57).
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "MultiMeters"
local SKINS = { "default", "obsidian", "azeroth", "glass", "contrast", "ember", "wow", "midnight", "forever" }

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

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

--- The inset S.Shell lays its bands at under the live skin: a flat edge's size, else 1.
local function shellInset(NS)
    local style = NS.Skin.Token("win.borderStyle") or "flat"
    local size = NS.Skin.Token("win.borderSize")
    return style == "flat" and type(size) == "number" and size or 1
end

local function pointNamed(region, name)
    for i = 1, region:GetNumPoints() do
        local point, rel, relPoint, x, y = region:GetPoint(i)
        if point == name then return rel, relPoint, x, y end
    end
    return nil
end

--- The band sits at (e, -e) from both top corners of the frame, TitleBandHeight() high.
local function assertBandAt(window, e, what)
    local band, frame = window.headerBand, window.frame
    assertTrue(band ~= nil, what .. ": the window has no band frame")
    local rel, relPoint, x, y = pointNamed(band, "TOPLEFT")
    assertEqual(rel, frame, what .. ": the band's TOPLEFT is not on the frame")
    assertEqual(relPoint, "TOPLEFT", what .. ": the band's TOPLEFT")
    assertEqual(x, e, what .. ": the band's left inset")
    assertEqual(y, -e, what .. ": the band's top inset")
    rel, relPoint, x, y = pointNamed(band, "TOPRIGHT")
    assertEqual(rel, frame, what .. ": the band's TOPRIGHT is not on the frame")
    assertEqual(relPoint, "TOPRIGHT", what .. ": the band's TOPRIGHT")
    assertEqual(x, -e, what .. ": the band's right inset")
    assertEqual(y, -e, what .. ": the band's top inset on the right")
    assertEqual(band:GetHeight(), window:TitleBandHeight(), what .. ": the band's height")
    assertEqual(window.headerBG.__allPoints, band, what .. ": the tinted strip does not fill the band")
end

--- `region` has one anchor, LEFT, CENTER or RIGHT, on the band at y 0 (`allowed` names the points).
local function assertOnBand(window, region, what)
    assertTrue(region:GetNumPoints() >= 1, what .. " has no anchor")
    for i = 1, region:GetNumPoints() do
        local point, rel, _, _, y = region:GetPoint(i)
        assertTrue(point == "LEFT" or point == "RIGHT" or point == "CENTER",
            what .. " is anchored " .. tostring(point) .. ", not by its middle")
        assertEqual(rel, window.headerBand, what .. " is not anchored to the band")
        assertEqual(y, 0, what .. " is off the band's middle")
    end
end

--- The strip's two stops (bottom, top), or its flat color twice.
local function stops(tex)
    local g = tex.__gradient
    if g then
        return { g.min.r, g.min.g, g.min.b, g.min.a }, { g.max.r, g.max.g, g.max.b, g.max.a }
    end
    local c = tex.__colorTexture or {}
    return c, c
end

local function sameColor(got, want, msg)
    for i = 1, 4 do
        assertTrue(near(got[i], want[i] or 1), ("%s: channel %d is %s, want %s"):format(msg, i,
            tostring(got[i]), tostring(want[i])))
    end
end

local function tokenColor(NS, name)
    local r, g, b, a = NS.Skin.Color(name)
    return { r, g, b, a or 1 }
end

-- ── the band's geometry ───────────────────────────────────────────────────────────────────────

test("Header band: flush inside the edge at Shell's inset, TitleBandHeight high, in every skin", function()
    -- red under: headerBG anchored at the row padding (6, -6), the round 4 "black strip" (image 33).
    local _, NS, window, _, Skin = scene()
    assertBandAt(window, 1, "Ka0s Default")
    assertEqual(window:TitleBandHeight(), 30, "the shipped band is LootHistory's 30px")
    for _, key in ipairs(SKINS) do
        Skin:SetChoice(OWNER, "ka0s", key)
        assertBandAt(window, shellInset(NS), key)
    end
end)

test("Header band: a 2 px flat edge puts the band 2 px in; a nine-slice edge keeps it 1 px in", function()
    -- The skeptic's correction: Shell insets by `win.borderSize` only for a flat edge (WoW Midnight's
    -- 2 px gold), never by `win.inset`; WoW Default's 32 px dialog art and Glass keep 1.
    -- red under: a band at win.inset, or at 1 in every skin.
    local _, _, window, _, Skin = scene()
    Skin:SetChoice(OWNER, "ka0s", "midnight")
    assertBandAt(window, 2, "WoW Midnight")
    Skin:SetChoice(OWNER, "ka0s", "wow")
    assertBandAt(window, 1, "WoW Default")
    Skin:SetChoice(OWNER, "ka0s", "glass")
    assertBandAt(window, 1, "Glass")
end)

test("Header band: under the player's own edge the band sits inside that edge", function()
    -- borderColorMode custom: the Shell draws no edge and ApplyBorder draws the player's, 3 px.
    -- red under: the skin's inset under the player's edge (the art would overlap the band).
    local inst, _, window, cfg = scene()
    inst.mocks.__media.border["Grid Edge"] = [[Interface\GridEdge]]
    cfg.frame.borderColorMode = "custom"
    cfg.frame.borderStyle, cfg.frame.borderSize = "Grid Edge", 3
    window:ApplyConfig()
    assertBandAt(window, 3, "a 3 px custom edge")
    cfg.frame.borderStyle = "None"
    window:ApplyConfig()
    assertBandAt(window, 0, "no edge at all")
end)

test("Header band: the band follows the player's header height and padding", function()
    local _, _, window, cfg = scene()
    cfg.header.height, cfg.frame.padding = 36, 8
    window:ApplyConfig()
    assertEqual(window:TitleBandHeight(), 42)
    assertBandAt(window, 1, "a taller header")
end)

test("Header band: the drag strip covers the band", function()
    local _, _, window = scene()
    local rel, _, x, y = pointNamed(window.dragBar, "TOPLEFT")
    assertEqual(rel, window.headerBand, "the drag strip is not on the band")
    assertEqual(x, 0)
    assertEqual(y, 0)
    assertEqual(window.dragBar:GetHeight(), window:TitleBandHeight(), "the drag strip stops short of the band")
end)

-- ── its fill ──────────────────────────────────────────────────────────────────────────────────

test("Header band: the strip draws the skin's title gradient, and flat for a flat skin", function()
    -- LootHistory's band: title.bgTop at the top, title.bgBottom at the bottom (P.fill's VERTICAL,
    -- min = bottom). A flat skin (Obsidian) sets both stops to none and draws its title.bg.
    -- red under: the flat title.bg blend under Ka0s Default (the round 4 meter, image 33).
    local _, NS, window, _, Skin = scene()
    local bottom, top = stops(window.headerBG)
    sameColor(bottom, tokenColor(NS, "title.bgBottom"), "Ka0s Default's bottom stop")
    sameColor(top, tokenColor(NS, "title.bgTop"), "Ka0s Default's top stop")
    sameColor(window.headerBG.__colorTexture or {}, { 1, 1, 1, 1 }, "the gradient's white base")
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    bottom, top = stops(window.headerBG)
    sameColor(bottom, tokenColor(NS, "title.bg"), "Obsidian's flat band")
    sameColor(top, tokenColor(NS, "title.bg"), "Obsidian's flat band, top")
    Skin:SetChoice(OWNER, "ka0s", "midnight")
    bottom, top = stops(window.headerBG)
    sameColor(bottom, tokenColor(NS, "title.bgBottom"), "WoW Midnight's bottom stop")
    sameColor(top, tokenColor(NS, "title.bgTop"), "WoW Midnight's top stop")
end)

test("Header band: a custom color uses the same geometry, drawn flat, after a gradient", function()
    -- The reset the skeptic asked for: a swatch drawn after the gradient is not tinted by it.
    -- red under: a gradient left on the texture under the swatch.
    local _, _, window, cfg = scene()
    cfg.header.bgColorFromSkin = false
    cfg.header.bgColor = { r = 0.9, g = 0.1, b = 0.1, a = 0.5 }
    window:ApplyConfig()
    local bottom, top = stops(window.headerBG)
    sameColor(bottom, { 0.9, 0.1, 0.1, 0.5 }, "the swatch, bottom")
    sameColor(top, { 0.9, 0.1, 0.1, 0.5 }, "the swatch, top")
    assertBandAt(window, 1, "the custom color")
end)

-- ── the header on it ──────────────────────────────────────────────────────────────────────────

test("Header band: the title, the session line and every control sit on the band's middle, every skin", function()
    -- red under: the round 4 TitleRowMid offsets off the frame's top edge (-15), which sat 4 px
    -- above the strip's middle with the strip at the padding and 1 px above it at the edge inset.
    local _, _, window, _, Skin = scene()
    for _, key in ipairs(SKINS) do
        Skin:SetChoice(OWNER, "ka0s", key)
        assertOnBand(window, window.frame.title, key .. ": the title")
        assertOnBand(window, window.sessionLine, key .. ": the session line")
        for name, button in pairs(window.controls) do
            if button:IsShown() then assertOnBand(window, button, key .. ": the " .. name .. " control") end
        end
    end
end)

test("Header band: the header keeps its left and right offsets off the frame's edges", function()
    -- The title starts 8 px in from the frame's left edge and the controls chain in from its right
    -- by the padding, as before, whatever the band's inset.
    local _, _, window, _, Skin = scene()
    Skin:SetChoice(OWNER, "ka0s", "midnight")
    local e = 2
    local _, _, x = pointNamed(window.frame.title, "LEFT")
    assertEqual(x + e, 8, "the title's left offset off the frame")
    local _, _, cx = pointNamed(window.controls.close, "RIGHT")
    assertEqual(cx - e, -window.layout.padding, "the close control's right offset off the frame")
end)

-- ── collapsed ─────────────────────────────────────────────────────────────────────────────────

test("Header band: a collapsed window is exactly the band plus its edges", function()
    -- The skeptic's correction: band + 2 * edge (32 under Ka0s Default), not band + edge.
    -- red under: padding * 2 + titleHeight (38), a 7 px strip of body color under the band.
    local _, _, window, cfg, Skin = scene()
    cfg.frame.minimized = true
    window:ApplyConfig()
    assertEqual(window.frame.__h, 32, "Ka0s Default's collapsed height")
    Skin:SetChoice(OWNER, "ka0s", "midnight")
    assertEqual(window.frame.__h, 34, "WoW Midnight's collapsed height (a 2 px edge)")
end)

-- ── the Export modal ──────────────────────────────────────────────────────────────────────────

test("Header band: the Export modal's bar takes its band's rect, its title and close on the middle", function()
    -- R5-WIN (the round 5 hosts-owe, R5-L3): under noTopBar a child TitleBar takes S.Band's rect, so
    -- the bar, its centered caption and its close sit on the band Shell lays, at its inset in every
    -- skin. red under: the bar's own TOPLEFT (1, -1) anchor, 1 px high under a 2 px edge.
    local inst, NS, _, _, Skin = scene()
    local modal = inst.NS.Export.Open({})
    assertTrue(modal ~= nil, "the modal did not open")
    for _, key in ipairs({ "default", "midnight", "wow" }) do
        Skin:SetChoice(OWNER, "ka0s", key)
        local band = NS.Skin.Band(modal)
        assertTrue(band ~= nil, key .. ": the modal has no band")
        assertEqual(modal.titleBar.__allPoints, band, key .. ": the bar does not take the band's rect")
        local _, rel, _, _, y = modal.closeButton:GetPoint(1)
        assertEqual(rel, modal.titleBar, key .. ": the close is not on the bar")
        assertEqual(y, 0, key .. ": the close is off the bar's middle")
        for i = 1, modal.title:GetNumPoints() do
            local point, trel, _, _, ty = modal.title:GetPoint(i)
            assertTrue(point == "LEFT" or point == "RIGHT" or point == "CENTER",
                key .. ": the caption is anchored " .. tostring(point))
            assertEqual(trel, modal.titleBar, key .. ": the caption is not on the bar")
            assertEqual(ty or 0, 0, key .. ": the caption is off the bar's middle")
        end
    end
end)
