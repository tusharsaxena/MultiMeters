-- tests/test_skin_fix.lua — the addon's own gaps on the skin (FS-MM-FIX, causes A1, A2, A3 and the
-- host parts of L4, L6, L8 and L9 of Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING).
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "MultiMeters"

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-3 end

local function sameColor(got, want, msg)
    for i = 1, #want do
        assertTrue(near(got[i], want[i]), ("%s: channel %d is %s, want %s"):format(msg, i,
            tostring(got[i]), tostring(want[i])))
    end
end

local function scene(configure, opts)
    local inst = T.load(opts or {})
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

-- ── A3: gloss ────────────────────────────────────────────────────────────────────────────────

--- A real StatusBar through the paint mock, as S.BarGloss needs, driven by the host's own pass.
local function glossBench(fromSkin)
    local inst, NS, window, row, _, Skin = scene(function(c) c.bars.textureFromSkin = fromSkin end)
    local restore = dofile("tests/_kit/mock_paint.lua")(inst.mocks)
    local cell = statCell(row)
    local bar = inst.mocks.CreateFrame("StatusBar", nil, window.frame)
    bar:SetStatusBarTexture("Interface\\Test\\Fill")
    cell.frame = bar
    cell.bg = bar:CreateTexture()
    return NS, window, cell, Skin, bar, restore
end

local function glossRegion(Skin, bar)
    local rec = Skin.painted[bar]
    return rec and rec.regions and rec.regions.gloss
end

test("Gloss: a cell draws the skin's gloss while its texture follows the skin", function()
    -- red under: no S.BarGloss call in ApplyBarSkin. Asserted drawn first, so the plain case below
    -- is not a pass on an empty bar.
    local _, window, cell, Skin, bar, restore = glossBench(true)
    Skin:SetChoice(OWNER, "ka0s", "glass")
    cell:ApplyBarSkin(window.config.bars)
    local g = glossRegion(Skin, bar)
    assertTrue(g ~= nil and g:IsShown(), "no gloss under Glass")
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    assertFalse(g:IsShown(), "Ka0s Default has no gloss")
    restore()
end)

test("Gloss: a bar with the player's own texture stays plain under Glass", function()
    -- red under: S.BarGloss called with no companion, which shines a player's texture.
    local _, window, cell, Skin, bar, restore = glossBench(false)
    Skin:SetChoice(OWNER, "ka0s", "glass")
    cell:ApplyBarSkin(window.config.bars)
    local g = glossRegion(Skin, bar)
    assertTrue(g == nil or not g:IsShown(), "a player's texture took the gloss")
    restore()
end)

test("Gloss: the tooltip's spell bars take it too, on their own companion", function()
    local _, NS, _, _, cfg = scene()
    local seen = {}
    local real = NS.Skin.BarGloss
    NS.Skin.BarGloss = function(_, fromSkin) seen[#seen + 1] = fromSkin end
    local style = NS.TooltipInternals.lineStyle(NS.TooltipInternals.tooltipConfig(cfg), nil)
    assertEqual(style.textureFromSkin, true)
    cfg.tooltip.barTextureFromSkin = false
    style = NS.TooltipInternals.lineStyle(NS.TooltipInternals.tooltipConfig(cfg), nil)
    assertEqual(style.textureFromSkin, false)
    NS.Skin.BarGloss = real
end)

-- ── A1: the header band and the unit icon ────────────────────────────────────────────────────

test("A1: the column header strip wears the skin's band, under Custom, with its companion", function()
    -- red under: the band read from the swatch, or the companion reaching a per-statistic strip.
    local _, NS, window, _, cfg, Skin = scene()
    local r, g, b, a = NS.Skin.Color("list.header.bg")
    sameColor(window.headerBg.__colorTexture, { r, g, b, a }, "Ka0s Default's faint band")
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    r, g, b, a = NS.Skin.Color("list.header.bg")
    if r then sameColor(window.headerBg.__colorTexture, { r, g, b, a }, "obsidian's band") end
    cfg.columnHeader.bgColorFromSkin = false
    cfg.columnHeader.bgColor = { r = 0, g = 0, b = 1, a = 0.5 }
    window:ApplyConfig()
    sameColor(window.headerBg.__colorTexture, { 0, 0, 1, 0.5 }, "the swatch, companion off")
end)

test("A1: the unit icon wears the skin's icon border, with its companion", function()
    -- red under: no holder, a holder left up with no icon, or a border drawn with the row off.
    local _, NS, _, row, cfg = scene()
    local cell = row.nameCell
    local seen = 0
    local real = NS.Skin.IconBorder
    NS.Skin.IconBorder = function(_, o)
        seen = seen + 1
        assertEqual(o.fromSkin, true)
    end
    cell.iconBorder = nil
    row:Update({ guid = "Player-1-0000000A", name = "Alpha", classFilename = "MAGE", values = {} }, 1)
    NS.Skin.IconBorder = real
    assertEqual(seen, 1)
    assertTrue(cell.iconBorder ~= nil)
    cell.icons.unit:Hide()
    cell:SyncIconBorder()
    assertFalse(cell.iconBorder:IsShown(), "a border with no icon in it")
    cell.icons.unit:Show()
    cell:SyncIconBorder()
    assertTrue(cell.iconBorder:IsShown())
    cfg.icons.borderFromSkin = false
    cell:SyncIconBorder()
    assertFalse(cell.iconBorder:IsShown(), "the companion off")
end)

-- ── A2: the segment picker ───────────────────────────────────────────────────────────────────

test("A2: the segment picker drops the skinned menu, the active entry marked", function()
    -- red under: MenuUtil, the client's stock menu, while the labels can be read.
    local inst, _, window = scene()
    inst.mocks.setAvailableSessions{ { sessionID = 4, name = "Guard", durationSeconds = 22 } }
    inst.mocks.__lastMenu = nil
    assertTrue(window:OpenSegmentMenu())
    assertTrue(inst.mocks.__lastMenu == nil, "the client's menu opened")
    local dd = window.segmentDropdown
    assertEqual(dd.__owner, OWNER, "the menu must wear this addon's skin")
    local opts = dd._options
    assertEqual(#opts, 3)
    assertEqual(opts[1].label, "Guard   0:22")
    assertEqual(opts[1].value, 4)
    assertEqual(dd._value, "Overall", "the window's own session, marked")
end)

test("A2: under the Combat restriction the client's menu stays, because a label may be secret", function()
    -- red under: W.Dropdown handed a secret label, whose menu measures and concatenates each row,
    -- which raises in tainted code.
    local inst, _, window = scene()
    inst.mocks.setAvailableSessions{ { sessionID = 4, name = "Guard", durationSeconds = 22 } }
    inst.mocks.setRestricted(true)
    assertTrue(window:OpenSegmentMenu())
    assertTrue(inst.mocks.__lastMenu ~= nil, "no menu while restricted")
    assertTrue(window.segmentDropdown == nil, "the widget took labels it may not measure")
end)

-- ── L6, L4: the Columns editor ───────────────────────────────────────────────────────────────

test("L6: the column glyph takes a Ka0s mark in the skin's tint, the stock art while the panel is ignored", function()
    -- red under: ReadyCheck art with the Scope cleared, or no stock arm.
    local inst, NS = scene()
    local calls = {}
    local real = NS.Skin.Mark
    NS.Skin.Mark = function(tex, opts) calls[#calls + 1] = { tex = tex, opts = opts } end
    local tex = { SetTexture = function(self, art) self.art = art end }
    NS.ColumnBlocksInternals.markGlyph(tex, true)
    NS.ColumnBlocksInternals.markGlyph(tex, false)
    NS.Skin.Mark = real
    assertEqual(calls[1].opts.art, NS.Icon("confirm"))
    assertEqual(calls[1].opts.token, "sem.good")
    assertEqual(calls[1].opts.panel, true)
    assertEqual(calls[2].opts.art, NS.Icon("close"))
    assertEqual(calls[2].opts.token, "sem.bad")
    calls[1].opts.stock(tex)
    assertEqual(tex.art, "Interface\\RaidFrame\\ReadyCheck-Ready")
    assertTrue(inst ~= nil)
end)

-- ── L8 ───────────────────────────────────────────────────────────────────────────────────────

test("L8: the sort arrow takes icon.arrow while the label follows the skin", function()
    -- red under: the tint inherited from the label.
    local _, NS, window, _, _, Skin = scene()
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    window:ApplyColumnHeaders()
    local r, g, b = NS.Skin.Color("icon.arrow")
    local found
    for _, button in ipairs(window.columnHeaders) do
        if button.arrowTex and button.arrowTex:IsShown() then found = button.arrowTex end
    end
    assertTrue(found ~= nil, "no arrow drawn")
    sameColor(found.__vertexColor, { r, g, b }, "the sort arrow")
end)

test("L8: the close control takes the close tokens under the Skin mode", function()
    -- red under: close wearing icon.tint and btn.hover.
    local _, NS, window = scene()
    local button = window.controls.close
    local r, g, b = NS.Skin.Color("close.rest")
    sameColor(button.tex.__vertexColor, { r, g, b }, "close at rest")
    button:_run("OnEnter")
    r, g, b = NS.Skin.Color("close.hot")
    sameColor(button.tex.__vertexColor, { r, g, b }, "close under the pointer")
    button:_run("OnLeave")
end)

test("L8: the meter-unavailable notice draws the Font outline", function()
    -- red under: flags typed as "".
    local _, _, window = scene()
    assertEqual(window.notice.__font.flags, "OUTLINE")
end)

test("L8: the window's resize grip names its skin owner", function()
    -- red under: MakeResizable with no owner, so the grip ignores icon.grip under every skin.
    local inst = T.load{}
    local NS = inst.NS
    local seen
    local real = NS.MakeResizable
    NS.MakeResizable = function(frame, opts) seen = opts; return real(frame, opts) end
    NS.WindowManager:Init()
    NS.MakeResizable = real
    assertEqual(seen and seen.owner, OWNER)
end)

test("L8: the Export whisper box is a skinned input", function()
    -- red under: S.Font alone, which paints neither input.text nor the focus edge.
    local inst = T.load{}
    local NS = inst.NS
    local seen = 0
    local real = NS.Skin.EditBox
    NS.Skin.EditBox = function(...) seen = seen + 1; return real(...) end
    NS.Export.Open(NS.WindowManager.All and NS.Database.GetWindows()[1])
    NS.Skin.EditBox = real
    assertTrue(seen >= 1, "the whisper box took no S.EditBox")
end)

-- ── L9 ───────────────────────────────────────────────────────────────────────────────────────

test("L9: the title takes the skin's alignment while its companion is on", function()
    -- red under: the stored LEFT past the companion.
    local _, NS, window, _, cfg = scene()
    assertEqual(window.frame.title.__justifyH, NS.Skin.Token("title.align"))
    cfg.header.alignFromSkin = false
    cfg.header.align = "RIGHT"
    window:ApplyConfig()
    assertEqual(window.frame.title.__justifyH, "RIGHT")
end)

test("L9: the Export modal's title bar is the skin's height", function()
    -- red under: the typed 26. Its rows moved down with it.
    local inst = T.load{}
    local NS = inst.NS
    assertEqual(NS.Export.__geometry.metricTop, 40)
    assertEqual(NS.Export.__geometry.height, 240)
end)
