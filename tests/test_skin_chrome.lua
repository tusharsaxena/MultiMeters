-- tests/test_skin_chrome.lua — the chrome this addon draws, painted through its skin facade
-- (core/SkinSetup.lua, skinning-§1, the rollout's MM-02).
--
-- Two properties per surface. Under Ka0s Default it draws exactly the pixels it drew before the
-- facade (DECISIONS X1: the near-miss reds and the dim gray are owner tokens, not snapped to the
-- nearest library token); under another skin it draws that skin's tokens. The meter window's
-- fill and edge stay the PLAYER's (MM-03 put only the HUD's faces, bar textures and bar borders
-- on the skin; its colors and the window's own edge are not reset, DECISIONS X4), so a skin
-- switch must re-lay them over the Shell's replay, not lose them to it.
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "MultiMeters"

--- A fresh instance with its first window managed and configured: managed, so the
--- OnLooksChanged listener (WindowManager:Reskin) reaches it, as it reaches every live window.
local function scene()
    local inst = T.load{}
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    NS.WindowManager:Init()
    local window = NS.WindowManager.Get(cfg.id)
    assertTrue(window ~= nil, "the manager built no window for the first config")
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


-- ---------------------------------------------------------------------------
-- The rows: hover wash, stripe, self edge and the classless name (MM-G1, MM-G2)
-- ---------------------------------------------------------------------------

--- A row of the window's own pool, configured to draw every row look.
local function rowScene()
    local inst, NS, window, Skin = scene()
    local rows = window.config.rows
    rows.highlightSelf, rows.mouseoverHighlight, rows.alternatingBackground = true, true, true
    window:ApplyConfig()
    return inst, NS, window, Skin, window:Acquire()
end

local function classless()
    return { guid = "Creature-0-1", name = "Training Dummy", role = "NONE", isPlayer = false,
             cells = { DamageDone = { total = 1, maxAmount = 1 } } }
end

--- The four row looks as the row drew them: wash, stripe, edge (alpha the setting's), name.
local function rowLooks(row)
    row:Update(classless(), 2)
    return row.mouseHighlight.__colorTexture or {}, row.bg.__colorTexture or {},
        row.selfHighlight.__colorTexture or {}, { row.nameCell.left:GetTextColor() }
end

test("Skin chrome: the rows keep their Ka0s Default pixels through the owner tokens", function()
    -- red under: the row looks not painted at all (a nil color), or a token whose default moved.
    local _, _, _, _, row = rowScene()
    local wash, stripe, edge, name = rowLooks(row)
    sameColor(wash, { 1, 1, 1, 0.10 }, "the hover wash")
    sameColor(stripe, { 1, 1, 1, 0.05 }, "the stripe")
    sameColor(edge, { 1, 0.82, 0, 1 }, "the self edge")
    sameColor(name, { 1, 1, 1 }, "a classless name")
end)

test("Skin chrome: a skin switch repaints the rows from the skin's tokens", function()
    -- red under: the literals typed back into modules/Row.lua, or the looks cached anywhere
    -- ApplyConfig (so WindowManager:Reskin) does not re-read them.
    local _, NS, _, Skin, row = rowScene()
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local hover = tokenOr(NS, "mm.rowHover")
    assertFalse(near(hover[1], 1) and near(hover[2], 1) and near(hover[3], 1),
        "obsidian's hover is Ka0s Default's white: the case is moot")
    local wash, stripe, edge, name = rowLooks(row)
    sameColor(wash, hover, "the hover wash is mm.rowHover")
    sameColor(stripe, tokenOr(NS, "mm.rowStripe"), "the stripe is mm.rowStripe")
    local accent = tokenOr(NS, "text.accent")
    sameColor(edge, { accent[1], accent[2], accent[3], 1 }, "the self edge is text.accent")
    local hi = tokenOr(NS, "text.highlight")
    sameColor(name, { hi[1], hi[2], hi[3] }, "a classless name is text.highlight")

    local src = source("modules/Row.lua")
    for line in src:gmatch("[^\n]+") do
        if not line:match("^%s*%-%-") then
            assertFalse(line:find("Set%a*Color%a*%(%s*[%d%.]") ~= nil, "a typed color: " .. line)
        end
    end
end)

test("Skin chrome: the session line's escapes are cached on ApplyConfig, not read per refresh", function()
    -- red under: NS.SkinEscape called from RestrictedNotice or ApplyTitle (a token read on every
    -- throttled refresh of a pull, R2).
    local _, NS, window = scene()
    local calls, real = 0, NS.SkinEscape
    NS.SkinEscape = function(...) calls = calls + 1; return real(...) end
    window.aggregate = { identityMode = true }
    window:RestrictedNotice(false)
    NS.State = NS.State or {}
    local was = NS.State.testMode
    NS.State.testMode = true
    window:ApplyTitle()
    NS.State.testMode = was
    window.aggregate = nil
    NS.SkinEscape = real
    assertEqual(calls, 0, "a refresh-path token read")
    assertEqual(window.skinLooks.dim, "|cff9d9d9d", "the cached dim keeps NS.GRAY's bytes")
    assertEqual(window.skinLooks.testWord, "|cffff2020", "the cached TEST MODE red keeps its bytes")
end)
