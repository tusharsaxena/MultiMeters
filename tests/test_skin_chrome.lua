-- tests/test_skin_chrome.lua — the chrome this addon draws, painted through its skin facade
-- (core/SkinSetup.lua, skinning-§1, the rollout's MM-02).
--
-- Two properties per surface. Under Ka0s Default it draws exactly the pixels it drew before the
-- facade (DECISIONS X1: the near-miss reds and the dim gray are owner tokens, not snapped to the
-- nearest library token); under another skin it draws that skin's tokens. The meter window's
-- fill and edge stay the PLAYER's until the HUD style rows learn a `skin` mode (MM-03), so a skin
-- switch must re-lay them over the Shell's replay, not lose them to it.
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "MultiMeters"

--- A fresh instance with its first window built and configured.
local function scene()
    local inst = T.load{}
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    local window = NS.WindowManager.Get(cfg.id) or NS.Window.New(cfg)
    window:ApplyConfig()
    return inst, NS, window, inst.mocks.LibStub("LibKa0s-Skin-1.0")
end

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

local function sameColor(got, want, msg)
    for i = 1, #want do
        assertTrue(near(got[i], want[i]), ("%s: channel %d is %s, want %s"):format(msg, i,
            tostring(got[i]), tostring(want[i])))
    end
end

-- The frame mock records the backdrop colors and answers no getter for them.
local function fill(f) return f.__backdropColor or {} end
local function edgeColor(f) return f.__backdropBorderColor or {} end

--- The color a skin token answers for this owner, or a clear one for a token the skin leaves unset
--- (the Shell then leaves Core's inner rule cleared).
local function tokenOr(NS, name)
    local r, g, b, a = NS.Skin.Color(name)
    if r == nil then return { 0, 0, 0, 0 } end
    return { r, g, b, a }
end

local function source(path)
    local fh = assert(io.open((T.root or ".") .. "/" .. path, "r"))
    local s = fh:read("*a")
    fh:close()
    return s
end

test("Skin chrome: the meter window keeps its Ka0s Default pixels through the Shell", function()
    -- red under: the Shell drawing its own flat edge and inner rule over the player's edge
    -- (noBorder dropped), or ApplyBorder leaving the inner rule the Shell cleared at (0,0,0,0).
    local _, NS, window = scene()
    local f = window.frame
    assertEqual(type(f.innerBorder), "table", "Core built no inner border: this case asserts nothing")
    assertTrue(f.innerBorder:IsShown(), "the inner rule sits inside the shipped edge")
    sameColor(edgeColor(f.innerBorder), { 0.24, 0.24, 0.27, 0.85 }, "the inner rule is win.inner")
    sameColor(fill(f), { 0, 0, 0, 0.75 }, "the fill is the player's")
    local bd = f.__backdrop or {}
    assertTrue(bd.bgFile ~= nil, "the fill texture is the one the skin wrote")
    assertTrue(bd.edgeFile ~= nil, "the player's edge is drawn")
    assertEqual(NS.SkinEscape("mm.testWord"), "|cffff2020", "the TEST MODE red keeps its bytes")
end)

test("Skin chrome: a skin switch repaints the window and re-lays the player's edge over it", function()
    -- red under: no OnLooksChanged listener (the Shell's replay would leave win.bg as the fill and
    -- a cleared inner rule), or a listener that re-ran the Shell without ApplyBorder.
    local _, NS, window, Skin = scene()
    local f = window.frame
    local edge = (f.__backdrop or {}).edgeFile
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    sameColor(edgeColor(f.innerBorder), tokenOr(NS, "win.inner"), "the inner rule follows the new skin")
    sameColor(fill(f), { 0, 0, 0, 0.75 }, "the player's fill survived the replay")
    assertEqual((f.__backdrop or {}).edgeFile, edge, "the player's edge survived the replay")
end)

test("Skin chrome: the TEST MODE word and the restricted notes follow the skin", function()
    -- red under: the |cffff2020 or NS.GRAY literal back in modules/Window_Header.lua.
    local _, NS, window, Skin = scene()
    window.aggregate = { identityMode = true }
    assertEqual(window:RestrictedNotice(false):sub(1, 10), "|cff9d9d9d", "Ka0s Default keeps NS.GRAY's bytes")
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local dim = NS.SkinEscape("mm.dim")
    assertFalse(dim == "|cff9d9d9d", "obsidian's muted text is not Ka0s Default's gray: the case is moot")
    assertEqual(window:RestrictedNotice(false):sub(1, 10), dim, "the note takes the skin's dim")
    window.aggregate = nil

    local src = source("modules/Window_Header.lua")
    for line in src:gmatch("[^\n]+") do
        if not line:match("^%s*%-%-") then
            assertFalse(line:find("|cff", 1, true) ~= nil, "a typed color escape: " .. line)
        end
    end
end)

test("Skin chrome: the empty state and the notice take the skin's text tokens", function()
    local _, NS, window = scene()
    assertTrue(NS.SkinColor("text.highlight") ~= nil, "no highlight token")
    sameColor({ window.notice:GetTextColor() }, { NS.SkinColor("text.highlight") }, "the notice")
end)

test("Skin chrome: the export modal paints through the facade, its refusal in mm.warn", function()
    -- red under: makeButton's NS.SKIN backdrop and OnEnter/OnLeave colors, the whisper row's
    -- typed backdrop, or the warning's 0.9, 0.25, 0.25 typed back in.
    local inst, NS, _, Skin = scene()
    local modal = inst.NS.Export.Open({})
    assertTrue(modal ~= nil, "the modal did not open")
    sameColor({ modal.warning:GetTextColor() }, { 0.9, 0.25, 0.25 }, "the refusal keeps its pixel")
    sameColor({ modal.csvButton.text:GetTextColor() }, { NS.Skin.Color("btn.text") }, "the label is btn.text")

    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    sameColor({ modal.warning:GetTextColor() }, { NS.Skin.Color("mm.warn") }, "the refusal follows the skin")
    assertFalse(near(NS.Skin.Color("mm.warn"), 0.9) and near(select(2, NS.Skin.Color("mm.warn")), 0.25),
        "obsidian draws the refusal in Ka0s Default's red: the case is moot")

    local src = source("modules/Export_Modal.lua")
    assertFalse(src:find("NS.SKIN", 1, true) ~= nil, "a constants-table look read (#107)")
    assertFalse(src:find("applySkin%s*=") ~= nil, "applySkin runs INSTEAD of the owner's skin")
    -- The frame mock's backdrop methods are not the frame's own (rawget), so the primitive paints
    -- the row as regions here; the source is what says the row's look is the skin's.
    assertFalse(src:find(":SetBackdrop(", 1, true) ~= nil, "a typed backdrop on a modal control")
    assertTrue(src:find("NS.Skin.Inset(whisperRow)", 1, true) ~= nil, "the whisper row is an inset")
    for line in src:gmatch("[^\n]+") do
        if not line:match("^%s*%-%-") then
            assertFalse(line:find("Set%a*Color%(%s*[%d%.]") ~= nil, "a typed color: " .. line)
        end
    end
end)
