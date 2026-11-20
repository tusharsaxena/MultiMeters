-- tests/skin_facts.lua — this addon's facts for the kit's two skin gates (kit revision 50, skinning-§1;
-- FS-MM-GATE of Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING). Not a suite: tests/run.lua calls
-- it with the instance factory and hands the answer to Kit.skinValues and Kit.skinSwitch.
--
-- THE ROWS. What no kit category takes, each with the cause that leaves it alone. A typed value with
-- a token goes through the token instead of getting a row.
--
-- THE SURFACES. One entry per thing this addon paints itself on a meter window and a tooltip; what the
-- library paints for it (the console, the Steps panel, the options chrome) is the library's own suite's.
-- On one instance of its own, enabled and on the paint recorder, so a surface with no `paint` is redrawn
-- by the real listener, WindowManager:Reskin, and a listener dropped goes red here.
--
-- CLASS AND STATISTIC COLORS ARE NOT HERE. They carry a meaning (MC), so no skin moves them: a cell's
-- fill, a name in its class color. The sample below is classless, so its name is the skin's.

local loadInstance = ...

local inst, scene

--- The one enabled instance, built on first use, on the paint recorder.
local function live()
    if not inst then
        inst = loadInstance{
            enable = true,
            mutate = function(m) dofile("tests/_kit/mock_paint.lua")(m) end,
        }
    end
    return inst
end

--- The first window with one column and one drawn row, the same every call.
local function window()
    if scene then return scene end
    local NS = live().NS
    local cfg = NS.Database.GetWindows()[1]
    cfg.columns = { { stat = "DamageDone", enabled = true } }
    cfg.data.sortColumn = "DamageDone"
    NS.WindowManager:Init()
    local w = NS.WindowManager.Get(cfg.id)
    w:ApplyConfig()
    local row = w:Acquire()
    row:ApplyLayout(w.layout)
    row:Update({ guid = "Player-1-0000000A", name = "Alpha", values = {} }, 1)
    scene = { NS = NS, cfg = cfg, w = w, row = row }
    return scene
end

--- A cell that holds a number: every cell but the name's.
local function statCell()
    for _, cell in pairs(window().row.cells) do
        if cell.key ~= "name" then return cell end
    end
end

--- A companion writer: each dotted `path` into the window's config is set to `on`.
local function rows(...)
    local paths = { ... }
    return function(on)
        for _, path in ipairs(paths) do
            local t, leaf = window().cfg, nil
            for seg in path:gmatch("[^%.]+") do
                if leaf then t = t[leaf] end
                leaf = seg
            end
            t[leaf] = on
        end
        window().w:ApplyConfig()
    end
end

--- A window surface redrawn as the window draws it, its row with it.
local function layout()
    local s = window()
    s.row:ApplyLayout(s.w.layout)
end

local surfaces = {
    { name = "the window's fill and edge", build = function() return window().w.frame end },
    { name = "the window's title",
      companion = rows("header.fontFromSkin", "header.shadowFromSkin"),
      build = function() return window().w.frame.title end },
    { name = "the title bar's band",
      companion = rows("header.bgColorFromSkin"),
      build = function() return window().w.headerBG end },
    { name = "the session line",
      companion = rows("header.fontFromSkin", "header.shadowFromSkin"),
      build = function() return window().w.sessionText end },
    { name = "a column label",
      companion = rows("columnHeader.colorFromSkin", "columnHeader.fontFromSkin", "columnHeader.shadowFromSkin"),
      build = function() return window().w.columnHeaders[1].text end },
    { name = "the column header band",
      companion = rows("columnHeader.bgColorFromSkin"),
      build = function() return window().w.headerBg end },
    { name = "the sort arrow",
      companion = rows("columnHeader.colorFromSkin"),
      build = function()
          for _, button in ipairs(window().w.columnHeaders) do
              if button.arrowTex and button.arrowTex:IsShown() then return button.arrowTex end
          end
      end,
      paint = function() window().w:ApplyColumnHeaders() end },
    { name = "the unavailable notice",
      build = function()
          window().w:ShowNotice("mute")
          return window().w.notice
      end,
      paint = function() window().w:ShowNotice("mute") end },
    { name = "a header control's tint",
      build = function() return window().w.controls.settings end },
    { name = "a cell's number",
      companion = rows("text.colorFromSkin", "text.fontFromSkin", "text.shadowFromSkin"),
      build = function() return statCell().left end, paint = layout },
    { name = "a cell's bar texture",
      companion = rows("bars.textureFromSkin"),
      build = function() return statCell().frame end, paint = layout },
    { name = "a cell's outline",
      companion = rows("bars.borderColorFromSkin", "bars.borderStyleFromSkin"),
      build = function()
          local s = window()
          s.cfg.bars.border = true
          s.w:ApplyConfig()
          layout()
          return statCell().frame
      end,
      paint = layout },
    { name = "the row's mouseover wash",
      build = function() return window().row.mouseHighlight end },
    { name = "the row's self edge",
      companion = rows("rows.highlightSelfFromSkin"),
      build = function() return window().row.selfHighlight end,
      paint = function() window().row:Update({ guid = "Player-1-0000000A", name = "Alpha", values = {} }, 1) end },
    { name = "the unit icon's border",
      companion = rows("icons.borderFromSkin"),
      build = function() return window().row.nameCell.frame end },
    { name = "the Export modal", build = function() return live().NS.Export.Open({}) end },
    { name = "a tooltip's spell bar",
      companion = rows("tooltip.barBgColorFromSkin", "tooltip.barBorderColorFromSkin", "tooltip.textColorFromSkin"),
      build = function()
          local proxy = { SetVertexColor = function() end, SetBackdropBorderColor = function() end,
                          SetTextColor = function() end }
          return proxy
      end,
      paint = function(proxy)
          local s, I = window(), live().NS.TooltipInternals
          local style = I.lineStyle(I.tooltipConfig(s.cfg), nil)
          local c = style.barBgColor
          proxy:SetVertexColor(c[1], c[2], c[3], c[4])
          c = style.borderColor
          proxy:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
          c = style.textColor
          proxy:SetTextColor(c[1], c[2], c[3])
      end },
}

return {
    values = {
        rows = {
            { file = "core/Namespace.lua", substring = 'NS.GRAY = "|cff9d9d9d"',
              why = "the opener of a chat notice line, and the degraded arm of mm.dim", cause = "L13" },
            { file = "modules/WindowManager.lua", substring = "|cFFFFFF00%s|r  %s  %s%d %s|r",
              why = "the /mm window list line, a report written to the debug console", cause = "L13" },
            { file = "modules/Row_NameCell.lua", substring = "SetStatusBarColor(0, 0, 0, 0)",
              why = "the name column's bar drawn clear: no color reaches the screen", cause = "A7" },
            { file = "modules/Tooltip.lua", substring = "fontString:SetTextColor(1, 1, 1)",
              why = "a GameTooltip line handed back to the client, which every addon shares, so a skin token here would leak into the next addon's tooltip; no MultiMeters surface draws it",
              cause = "A7" },
            -- Kit revision 58 reads tables, keyed r/g/b tables, return triples and RGBA fallbacks
            -- (SD-LK-97.19). What it finds that draws no look of its own:
            { file = "modules/HeaderControls.lua", substring = "FULL_TEXTURE = { 0, 1, 0, 1 }",
              why = "a control's texcoords, the whole of its art", category = "not a color" },
            { file = "modules/SimWorld.lua", substring = "SPELL_SHARE = { 0.5, 0.3, 0.2 }",
              why = "the simulator's split of a unit's amount across its spells", category = "not a color" },
            { file = "modules/Row.lua", substring = "rowHover  = { 1, 1, 1, 0.15 }",
              why = "a row's look before its window resolved any (NS.SkinWindowLooks runs on every ApplyConfig, before a row draws)",
              category = "unreachable default" },
            { file = "modules/Row.lua", substring = "rowStripe = { 1, 1, 1, 0.08 }",
              why = "a row's look before its window resolved any", category = "unreachable default" },
            { file = "modules/Row.lua", substring = "selfEdge  = { 1, 0.82, 0, 1 }",
              why = "a row's look before its window resolved any", category = "unreachable default" },
            { file = "modules/Row.lua", substring = "nameText  = { 1, 1, 1, 1 }",
              why = "a row's look before its window resolved any", category = "unreachable default" },
            -- RGBA(stored, r, g, b, a): the literal is drawn only for a stored swatch that is not a
            -- color, and AceDB fills every one from defaults/Profile.lua first.
            { file = "modules/Row.lua", substring = "RGBA(bars.customColor,",
              why = "the bar's Custom swatch read with its last-resort fallback", category = "unreachable default" },
            { file = "modules/Row.lua", substring = "RGBA(bars and bars.bgColor,",
              why = "the cell background's swatch read with its last-resort fallback", category = "unreachable default" },
            { file = "modules/Row.lua", substring = "RGBA(text and text.color,",
              why = "the text swatch's alpha read with its last-resort fallback", category = "unreachable default" },
            { file = "modules/Row.lua", substring = "return RGBA(text.color,",
              why = "the text swatch read with its last-resort fallback", category = "unreachable default" },
            { file = "modules/Row_Border.lua", substring = "RGBA(skin.border,",
              why = "the degraded NS.SKIN border read with its last-resort fallback", category = "unreachable default" },
            { file = "modules/Window_Header.lua", substring = "RGBA(header.color,",
              why = "the title swatch read with its last-resort fallback", category = "unreachable default" },
            { file = "modules/Window_Header.lua", substring = "RGBA(header.bgColor,",
              why = "the title bar swatch read with its last-resort fallback", category = "unreachable default" },
            { file = "modules/Tooltip.lua", substring = "SLOT_COLOR_DEFAULT = { 1, 1, 1 }",
              why = "the number slots' color when the resolved config carries none; tooltipConfig fills it from the stored swatch first",
              category = "unreachable default" },
            -- A stored swatch's default, the value defaults/Profile.lua holds (the kit's "defaults
            -- swatch"): drawn only while its mode is Custom or Class falls through, or while its Use
            -- the skin's color is off. Every one has a Skin mode or a FromSkin companion on by default.
            { file = "settings/Schema_Compose.lua", substring = "= { r = ",
              why = "a composed swatch's default, the companion-off or Custom-mode look", cause = "D4" },
            { file = "settings/Schema.lua", substring = "default = { r = ",
              why = "a swatch row's default, read only while its Skin mode or companion is off", cause = "D4" },
            { file = "core/Database_Migrations.lua", substring = "frame.controlColor = { r = 0.7,",
              why = "the v17 step's new Custom control color, written only for a profile already on Custom (the Skin mode is the default, MM-A1)",
              cause = "L6" },
            -- GAP rows of the skin-defaults audit, fixed under SD-SK-MM of the same run.
            { file = "modules/Row.lua", substring = "return 0.45, 0.45, 0.5",
              why = "a classless row's fill (SD-SK-MM.3)", cause = "D3" },
            { file = "modules/Tooltip.lua", substring = "return 1, 1, 1",
              why = "a classless tooltip name line (SD-SK-MM.6)", cause = "L2" },
            { file = "modules/Tooltip_Builders.lua", substring = "return 1, 1, 1",
              why = "an unpaletted stat line (SD-SK-MM.6)", cause = "L2" },
            { file = "modules/Tooltip_Builders.lua", substring = "return 0.62, 0.62, 0.62",
              why = "an unpaletted, unshown stat line (SD-SK-MM.6)", cause = "L2" },
        },
    },
    switch = {
        owner = "MultiMeters",
        skin  = function() return live().mocks.LibStub("LibKa0s-Skin-1.0") end,
        surfaces = surfaces,
    },
}
