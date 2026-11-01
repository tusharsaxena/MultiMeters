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
    return inst, NS, window, row, cfg, inst.mocks.LibStub("LibKa0s-Skin-1.0", true)
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
    -- red under: lineStyle dropping the companion. The draw itself: tests/test_tooltip_lines.lua.
    local _, NS, _, _, cfg = scene()
    local style = NS.TooltipInternals.lineStyle(NS.TooltipInternals.tooltipConfig(cfg), nil)
    assertEqual(style.textureFromSkin, true)
    cfg.tooltip.barTextureFromSkin = false
    style = NS.TooltipInternals.lineStyle(NS.TooltipInternals.tooltipConfig(cfg), nil)
    assertEqual(style.textureFromSkin, false)
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
    NS.Skin.IconBorder = function(target, o)
        seen = seen + 1
        assertEqual(o.fromSkin, true)
        assertEqual(target, cell.iconBorder or target)
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

--- The picker opened through the real W.ContextMenu: the anchor, the rows, the opts and its answer.
local function openPicker(inst, window)
    local W = inst.mocks.LibStub("LibKa0s-Widgets-1.0", true)
    local real, got = W.ContextMenu, {}
    W.ContextMenu = function(anchor, rows, opts)
        got.anchor, got.rows, got.opts = anchor, rows, opts
        got.menu = real(anchor, rows, opts)
        return got.menu
    end
    local opened = window:OpenSegmentMenu()
    W.ContextMenu = real
    assertTrue(opened)
    return got
end

test("A2: the segment picker is the shared context menu, titled, the active entry marked", function()
    -- red under: MenuUtil, the client's stock menu, while the labels can be read, or W.Dropdown,
    -- which draws no title row.
    local inst, _, window = scene()
    inst.mocks.setAvailableSessions{ { sessionID = 4, name = "Guard", durationSeconds = 22 } }
    inst.mocks.__lastMenu = nil
    local got = openPicker(inst, window)
    assertTrue(inst.mocks.__lastMenu == nil, "the client's menu opened")
    assertTrue(got.menu ~= nil and got.menu:IsShown(), "no menu on screen")
    assertEqual(got.opts.owner, OWNER, "the menu must wear this addon's skin")
    local rows = got.rows
    assertEqual(#rows, 5)
    assertEqual(rows[1].title, true)
    assertEqual(rows[1].label, inst.NS.L["Segment"])
    assertEqual(rows[2].label, "Guard   0:22")
    assertEqual(rows[2].value, 4)
    assertEqual(rows[3].divider, true)
    assertFalse(rows[2].isActive(), "the segment is not what the window shows")
    assertTrue(rows[5].isActive(), "the window's own session, marked")
end)

test("A2: a pinned segment is the marked row, and a window hidden closes the menu", function()
    -- red under: the mark read off the session type, or no OnHide close, which leaves the shared
    -- menu floating with no window under it.
    local inst, _, window = scene()
    inst.mocks.setAvailableSessions{ { sessionID = 4, name = "Guard", durationSeconds = 22 } }
    window:SetSegment(4)
    local got = openPicker(inst, window)
    assertTrue(got.rows[2].isActive(), "the pin, marked")
    assertFalse(got.rows[5].isActive(), "Overall is not what the window shows")
    assertEqual(window.segmentAnchor, got.anchor, "one anchor per window")
    window.frame:Hide()
    assertFalse(got.menu:IsShown(), "the menu outlived its window")
end)

test("A2: under the Combat restriction the client's menu stays, because a label may be secret", function()
    -- red under: W.Dropdown handed a secret label, whose menu measures and concatenates each row,
    -- which raises in tainted code.
    local inst, _, window = scene()
    inst.mocks.setAvailableSessions{ { sessionID = 4, name = "Guard", durationSeconds = 22 } }
    inst.mocks.setRestricted(true)
    assertTrue(window:OpenSegmentMenu())
    assertTrue(inst.mocks.__lastMenu ~= nil, "no menu while restricted")
    assertTrue(window.segmentAnchor == nil, "the widget took labels it may not measure")
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

-- ── Review pins: each case reads what was drawn, through the real path ──────────────────────

--- The first skin past Ka0s Default whose `pick(S)` answers true, chosen, or a failed case.
local function chooseSkin(NS, Skin, pick, what)
    for _, def in ipairs(Skin:Skins()) do
        if def.key ~= "ka0s" then
            Skin:SetChoice(OWNER, "ka0s", def.key)
            if pick(NS.Skin) then return def.key end
        end
    end
    assertTrue(false, "no skin " .. what)
end

--- A row with its config applied, as a settings change leaves it.
local function reapply(window, row)
    window:ApplyConfig()
    row:ApplyLayout(window.layout)
end

local PLAYER = { guid = "Player-1-0000000A", name = "Alpha", classFilename = "MAGE", isPlayer = true, values = {} }
PLAYER.cells = PLAYER.values

test("A1: turning Show icons off takes the border down through the settings path", function()
    -- red under: no SyncIconBorder in ApplyIcons, since SetPlayer returns early with the icons off.
    local _, _, window, row, cfg = scene()
    row:Update(PLAYER, 1)
    local cell = row.nameCell
    assertTrue(cell.iconBorder:IsShown(), "the border never came up, so this proves nothing")
    cfg.icons.showIcon = false
    reapply(window, row)
    row:Update(PLAYER, 1)
    assertFalse(cell.icons.unit:IsShown(), "the icon stayed")
    assertFalse(cell.iconBorder:IsShown(), "an empty border")
end)

test("A1: the companion off takes the border down with no new row drawn", function()
    -- red under: the border left up until the next SetPlayer.
    local _, _, window, row, cfg = scene()
    row:Update(PLAYER, 1)
    cfg.icons.borderFromSkin = false
    reapply(window, row)
    assertFalse(row.nameCell.iconBorder:IsShown(), "the companion off")
    cfg.icons.borderFromSkin = true
    reapply(window, row)
    assertTrue(row.nameCell.iconBorder:IsShown(), "the companion back on")
end)

test("D4: Ka0s Default draws no stripe and no self edge with both settings off", function()
    -- red under: the companions reading `mm.rowStripe` or `text.accent`, which moves its pixels.
    local _, _, _, row = scene()
    row:Update(PLAYER, 2)
    assertFalse(row.bg:IsShown(), "a stripe under Ka0s Default")
    assertFalse(row.selfHighlight:IsShown(), "an edge under Ka0s Default")
end)

test("D4: a skin draws its stripe and self edge with both settings off", function()
    -- red under: alternatingBackground or highlightSelf still the only gate.
    local _, NS, window, row, _, Skin = scene()
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    reapply(window, row)
    row:Update(PLAYER, 2)
    assertTrue(row.bg:IsShown(), "no stripe")
    sameColor(row.bg.__colorTexture, NS.Skin.Token("list.stripe"), "the stripe is the skin's list.stripe")
    assertTrue(row.selfHighlight:IsShown(), "no edge")
    local accent = NS.Skin.Token("text.accent")
    sameColor(row.selfHighlight.__colorTexture, { accent[1], accent[2], accent[3], 1 }, "the edge")
    row:Update(PLAYER, 1)
    assertFalse(row.bg:IsShown(), "an odd row")
end)

test("D4: each companion off gives its row back to its setting, under a skin", function()
    -- red under: a companion nothing reads.
    local _, _, window, row, cfg, Skin = scene()
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    cfg.rows.alternatingBackgroundFromSkin = false
    cfg.rows.highlightSelfFromSkin = false
    reapply(window, row)
    row:Update(PLAYER, 2)
    assertFalse(row.bg:IsShown(), "the stripe stayed")
    assertFalse(row.selfHighlight:IsShown(), "the edge stayed")
    cfg.rows.alternatingBackground = true
    cfg.rows.highlightSelf = true
    reapply(window, row)
    row:Update(PLAYER, 2)
    assertTrue(row.bg:IsShown(), "the setting draws it")
    assertTrue(row.selfHighlight:IsShown(), "the setting draws it")
end)

test("D4: without the library the companions draw nothing", function()
    -- red under: the looks answered by the degraded arm, or a nil look raising on the row.
    local _, _, _, row = scene(nil, { libFiles = {} })
    row:Update(PLAYER, 2)
    assertFalse(row.bg:IsShown(), "a stripe with no skin")
    assertFalse(row.selfHighlight:IsShown(), "an edge with no skin")
end)

test("L8: the header strip draws the skin's title face, and the player's without the companion", function()
    -- red under: hud.font under the title. Azeroth's title face is not its HUD face.
    local _, NS, window, _, cfg, Skin = scene()
    local faces = {}
    local real = NS.SkinHudFont
    NS.SkinHudFont = function(fs, face, ...)
        faces[fs] = face
        return real(fs, face, ...)
    end
    Skin:SetChoice(OWNER, "ka0s", "azeroth")
    assertFalse(NS.Skin.Token("font.title") == NS.Skin.Token("hud.font"), "the case is moot")
    local title = NS.WindowFontPath(NS.Skin.Token("font.title"))
    window:ApplyConfig()
    assertEqual(faces[window.frame.title], title)
    assertEqual(faces[window.sessionText], title, "the strip's second string left the title's face")

    Skin:SetIgnore(OWNER, nil, true)
    assertEqual(NS.Skin.Token("hud.font"), nil, "Ignore fonts is not on")
    window:ApplyConfig()
    assertEqual(faces[window.frame.title], NS.WindowFontPath(cfg.header.font), "Ignore fonts")
    Skin:SetIgnore(OWNER, nil, false)

    cfg.header.fontFromSkin = false
    window:ApplyConfig()
    NS.SkinHudFont = real
    assertEqual(faces[window.frame.title], NS.WindowFontPath(cfg.header.font), "the player's face")
end)

test("L8: the sort arrow draws its own look, not its label's", function()
    -- Every shipped skin's icon.arrow is its hud.label, so the cached look is moved apart by hand.
    -- red under: the arrow keeping the label's tint.
    local _, _, window = scene()
    window.skinLooks.sortArrow = { 0.1, 0.2, 0.3, 1 }
    window:ApplyColumnHeaders()
    local found
    for _, button in ipairs(window.columnHeaders) do
        if button.arrowTex and button.arrowTex:IsShown() then found = button.arrowTex end
    end
    assertTrue(found ~= nil, "no arrow drawn")
    sameColor(found.__vertexColor, { 0.1, 0.2, 0.3 }, "the sort arrow")
end)

test("D4: a skin's border art takes the class tint with Show border off", function()
    -- red under: the re-tint gated on `bars.border`, which is off under a skin's own border.
    local inst, _, _, row, cfg, Skin = scene(function(c)
        c.bars.border, c.bars.borderColorMode = false, "class"
    end)
    Skin:RegisterSkin({ key = "probe", tokens = { ["bar.borderStyle"] = "Probe Edge" } })
    inst.mocks.__media.border["Probe Edge"] = [[Interface\ProbeEdge]]
    Skin:SetChoice(OWNER, "ka0s", "probe")
    local cell = statCell(row)
    local painted
    cell.frame.SetBackdropBorderColor = function(_, ...) painted = { ... } end
    cell:ApplyBorder(cfg.bars)
    assertTrue(cell.borderShown, "the skin's border did not show")
    painted = nil
    cell:ApplyEntryBorderColor({ classFilename = "MAGE" })
    assertTrue(painted ~= nil, "no re-tint")
    local c = inst.mocks.RAID_CLASS_COLORS.MAGE
    sameColor(painted, { c.r, c.g, c.b }, "the class color")
end)

test("D4: the tooltip's bar border thickness is the skin's real style's, the player's under None", function()
    -- red under: the stored size past the companion, or a skin's None taking the player's away.
    local _, NS, _, _, cfg, Skin = scene(function(c) c.tooltip.barBorderSize = 7 end)
    local tipConfig = NS.TooltipInternals.tooltipConfig
    assertEqual(NS.Skin.Token("bar.borderStyle"), "None")
    assertEqual(tipConfig(cfg).barBorderSize, 7, "a skin's None hands the stored thickness back")
    chooseSkin(NS, Skin, function(S)
        return S.Token("bar.borderStyle") ~= "None" and S.Token("bar.borderSize") ~= 7
    end, "a real style, off the stored 7")
    assertEqual(tipConfig(cfg).barBorderSize, NS.Skin.Token("bar.borderSize"))
    cfg.tooltip.barBorderStyleFromSkin = false
    assertEqual(tipConfig(cfg).barBorderSize, 7, "the player's own")
end)

test("D4: with no library the tooltip bar's backdrop is the player's color and opacity", function()
    -- red under: the degraded facade's owner default, 0,0,0,0.10, over the stored swatch.
    local _, NS, _, _, cfg = scene(function(c)
        c.tooltip.barBgColor, c.tooltip.barBgAlpha = { r = 0.2, g = 0.3, b = 0.4, a = 1 }, 0.6
        c.tooltip.barBgColorMode = "custom"
    end, { libFiles = {} })
    assertEqual(cfg.tooltip.barBgColorFromSkin, true, "the fixture needs the companion on")
    local style = NS.TooltipInternals.lineStyle(NS.TooltipInternals.tooltipConfig(cfg), nil)
    sameColor(style.barBgColor, { 0.2, 0.3, 0.4, 0.6 }, "the stored backdrop")
end)

test("L9: the Export modal's title bar places its own text", function()
    -- red under: S.TitleBar without `place`, which leaves the title where the build put it.
    local inst = T.load{}
    local NS = inst.NS
    local seen
    local real = NS.Skin.TitleBar
    NS.Skin.TitleBar = function(bar, o) seen = o; return real(bar, o) end
    local modal = NS.Export.Open(NS.Database.GetWindows()[1])
    NS.Skin.TitleBar = real
    assertTrue(seen ~= nil, "no S.TitleBar")
    assertEqual(seen.place, true)
    assertEqual(seen.text, modal.title)
end)
