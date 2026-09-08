-- settings/Schema.lua
--
-- THE single source of truth for settings (settings-schema-§1). One ordered
-- array of rows drives three surfaces that would otherwise drift apart: the
-- options panel's widgets, the `/mm get|set|list|reset|resetall` CLI, and the
-- defaults reset. Adding a setting is one row here and nothing else.
--
-- THE ARRAY IS ALL THAT IS LEFT IN THIS FILE. At 3080 lines it was twice
-- layout-§1's cap, and issue #27 named the seam: the path machinery and the read
-- and write seams are settings/Schema_Paths.lua, and the vocabularies, validators
-- and composed blocks these rows are declared out of are
-- settings/Schema_Compose.lua. Three files rather than two because the array
-- alone is over the cap once the machinery leaves. This is the file that grows,
-- and a new setting is still one row in it.
--
-- ---------------------------------------------------------------------------
-- ROW SHAPE
-- ---------------------------------------------------------------------------
--
--   path      resolution path. `window.`-prefixed = active window; else profile.
--   type      "bool" | "number" | "string" | "color". This is the WIDGET
--             DISPATCH KEY — LibKa0s-Options-1.0 selects a maker from it, and
--             LibKa0s-Slash-1.0 selects a parser from the same field, which is
--             what keeps the CLI and the panel agreeing about what a row is.
--             There is deliberately no separate `widget` field: a second
--             selector is a second thing to keep in step. A `number` carrying
--             `values` is INFERRED as a dropdown by both majors; `string` with
--             `dialogControl = "EditBox"` is free text; everything else with
--             `values` is a dropdown.
--   default   the shipped value. MUST equal defaults/Profile.lua's — that
--             agreement is what NS.ValidateSchema() exists to prove.
--   page      the page key. Groups `/mm list`, feeds the panel's rowsForPage,
--             names the CONFIG_CHANGED section, and `page == "profiles"` is the
--             reset-all veto. One key, three jobs, no drift.
--   group     the TAB inside the page. RenderTabbedSchema partitions a page's
--             rows by it, in declaration order, and draws one tab per distinct
--             value -- so one tab is exactly one group and there is no second
--             field naming a tab. EVERY row carries one (options-ui-§13).
--   subgroup  a heading drawn INSIDE a tab, whenever the value changes within a
--             group (options-ui-§7). It names the KIND of control a mixed tab
--             holds, never repeats its tab's name, and must be CONTIGUOUS or its
--             heading prints twice.
--   startsLine  flush the pending line BEFORE this row, so a declared pair cannot
--             be split by an odd number of widgets above it. Every colour swatch
--             carries it, which is what puts its mode beside it whatever precedes.
--   classColorSource  "player" | "unit" -- WHICH class this surface's `class`
--             mode means, DECLARED rather than inferred from the path
--             (options-ui-§17). A cell and the tooltip are about the ROW's
--             player; the window's own chrome is about the local player.
--   composed  stamped by expandBlocks on a row a LibKa0s composer emitted. Inert
--             to every reader; tests/test_degraded.lua is the one consumer.
--   label     / desc    displayed strings, localized at declaration through NS.L.
--   min/max/step/fmt/isPercent   slider shape.
--   values / sorting / dialogControl   dropdown shape.
--   validate  optional predicate; a false answer refuses the write.
--   onChange  optional reaction for the few settings the CONFIG_CHANGED message
--             cannot express on its own (see "Refresh routing" in
--             settings/Schema_Compose.lua).
--   invert    display is the negation of storage (the one minimap row).
--   sessionOnly  never persisted; the row's own get/set are the whole storage.
--
-- TOC POSITION: SECOND of the three Schema files, and LOAD-BEARING at both ends.
-- After settings/Schema_Compose.lua, because every member of NS.SchemaCompose is
-- resolved at FILE SCOPE just below; before settings/Schema_Paths.lua, because
-- that file indexes the finished NS.Schema at file scope.
--
-- Nothing here is captured across the load boundary: NS.Helpers, NS.db,
-- NS.WindowManager and NS.Visibility are all resolved at CALL time, because this
-- file loads before all four.

local _, NS = ...

local L     = NS.L
local Const = NS.Constants

-- Re-localized under the names the rows below already spell, so the array reads
-- as it did when the composers, the vocabularies and the array were one file.
-- See the note at the foot of settings/Schema_Compose.lua.
local SC = NS.SchemaCompose
local ALIGN_SORT           = SC.ALIGN_SORT
local ALIGN_VALUES         = SC.ALIGN_VALUES
local ANCHOR_SORT          = SC.ANCHOR_SORT
local ANCHOR_VALUES        = SC.ANCHOR_VALUES
local BARS_BAR_ROWS        = SC.BARS_BAR_ROWS
local BARS_BG_ROWS         = SC.BARS_BG_ROWS
local BARS_BORDER_ROWS     = SC.BARS_BORDER_ROWS
local BARS_TEXT_ROWS       = SC.BARS_TEXT_ROWS
local CHANNEL_SORT         = SC.CHANNEL_SORT
local CHANNEL_VALUES       = SC.CHANNEL_VALUES
local COLHEAD_BG_ROWS      = SC.COLHEAD_BG_ROWS
local COLHEAD_TEXT_ROWS    = SC.COLHEAD_TEXT_ROWS
local CONTROLCOLOR_SORT    = SC.CONTROLCOLOR_SORT
local CONTROLCOLOR_VALUES  = SC.CONTROLCOLOR_VALUES
local DEATHTIME_SORT       = SC.DEATHTIME_SORT
local DEATHTIME_VALUES     = SC.DEATHTIME_VALUES
local DIVIDERCOLOR_SORT    = SC.DIVIDERCOLOR_SORT
local DIVIDERCOLOR_VALUES  = SC.DIVIDERCOLOR_VALUES
local FRAME_BG_ROWS        = SC.FRAME_BG_ROWS
local FRAME_BORDER_ROWS    = SC.FRAME_BORDER_ROWS
local GROWTH_SORT          = SC.GROWTH_SORT
local GROWTH_VALUES        = SC.GROWTH_VALUES
local HEADER_TEXT_ROWS     = SC.HEADER_TEXT_ROWS
local MASTER_ROWS          = SC.MASTER_ROWS
local NUMFMT_SORT          = SC.NUMFMT_SORT
local NUMFMT_VALUES        = SC.NUMFMT_VALUES
local OUTLINE_SORT         = SC.OUTLINE_SORT
local OUTLINE_VALUES       = SC.OUTLINE_VALUES
local SIDE_SORT            = SC.SIDE_SORT
local SIDE_VALUES          = SC.SIDE_VALUES
local SLOT_SORT            = SC.SLOT_SORT
local SLOT_VALUES          = SC.SLOT_VALUES
local STRATA_SORT          = SC.STRATA_SORT
local STRATA_VALUES        = SC.STRATA_VALUES
local TEXTCOLOR_SORT       = SC.TEXTCOLOR_SORT
local TEXTCOLOR_VALUES     = SC.TEXTCOLOR_VALUES
local TIP_BARBG_ROWS       = SC.TIP_BARBG_ROWS
local TIP_BARBORDER_ROWS   = SC.TIP_BARBORDER_ROWS
local TIP_BAR_ROWS         = SC.TIP_BAR_ROWS
local TIP_TEXT_ROWS        = SC.TIP_TEXT_ROWS
local block                = SC.block
local broadcastBarTexture  = SC.broadcastBarTexture
local broadcastColorMode   = SC.broadcastColorMode
local broadcastFont        = SC.broadcastFont
local broadcastOutline     = SC.broadcastOutline
local controlLabel         = SC.controlLabel
local expandBlocks         = SC.expandBlocks
local isNumberIn           = SC.isNumberIn
local lsmValues            = SC.lsmValues
local refreshMinimap       = SC.refreshMinimap
local refreshVisibility    = SC.refreshVisibility

-- What every colour swatch's tooltip says about the mode beside it. IN WORDS,
-- because the swatch is NEVER disabled (options-ui-§17, anti-patterns #74): it is
-- still read for its ALPHA under every mode -- no class colour and no palette
-- entry carries one -- so greying it out would tell the player something untrue,
-- and setting a colour before switching the mode to Custom is the normal order of
-- operations rather than a mistake to defend against.
--
-- Appended to every non-palette colour row's `desc` in ONE pass below, rather than
-- written into fifteen sentences: a rule restated fifteen times is a rule fourteen
-- of them can drift from.
local SWATCH_NOTE = L["Not read while the color mode beside it is anything but Custom color, except for its opacity, which always applies."]

-- ---------------------------------------------------------------------------
-- THE SCHEMA
-- ---------------------------------------------------------------------------
--
-- Ordered: pages in the order the panel lists them, and rows in the order they
-- render inside a page (the flow engine pairs consecutive rows two to a line, so
-- neighbours here are neighbours on screen).
--
-- Every default below is the SAME LITERAL defaults/Profile.lua ships. It is
-- restated rather than read out of the template because the row's default is what
-- a widget shows before the db exists and what a reset restores, and because two
-- independent statements of one value are exactly what NS.ValidateSchema() can
-- check — a single shared reference would agree with itself by construction and
-- prove nothing.

NS.Schema = {
    -- ── Windows ───────────────────────────────────────────────────────
    -- The picker, the create/duplicate/delete buttons and the copy-settings-from
    -- control are BESPOKE (settings/Windows.lua): they act on the registry, not on
    -- a leaf, so they have no path. The window's NAME is a leaf and is here, in the
    -- one-row "Window" tab it shares with those bespoke buttons.
    {
        path = "window.name", type = "string", default = "Multi Meters",
        dialogControl = "EditBox", maxLetters = 32,
        page = "windows", group = L["Window"],
        label = L["Window name"], desc = L["Name shown in this picker and, optionally, in the window's own header."],
        validate = function(v) return type(v) == "string" and v ~= "" end,
    },

    -- ── Frame ──────────────────────────────────────────────
    -- The chrome itself is LibKa0s-Core-1.0's shared SKIN, which tints the title
    -- and the divider on its own, so the edge colors are not settings. What the
    -- player owns is geometry, the backdrop and the LSM border.
    --
    -- FOUR TABS: the window-wide answers a player reaches for first (general --
    -- the two frame-level toggles and the four "set every surface at once" meta
    -- rows), then what the window IS (size and position), what is drawn behind
    -- and around it (background and border), and last the grid it draws (row).
    -- The title bar itself moved to the Header page, first in its own "Title
    -- bar" tab -- it is what the header strip draws, not what the frame is.

    -- ── General ──────────────────────────────────────────────
    -- FIRST, because it is where a player who has just opened this page wants to
    -- land: the two window-wide toggles, and the four meta rows that set every
    -- surface in the window at once. The meta rows arrived here when the "All
    -- surfaces" tab was retired -- a tab of four shortcuts sat at the far end of
    -- the strip, which is the last place someone reaching for "make it all one
    -- font" would look.
    --
    -- Locking implies preview mode: a player positioning a window at a target
    -- dummy needs a full grid to aim at, which is why the two are one control here
    -- and why modules/WindowManager.lua owns the coupling rather than this row.
    --
    -- NO `resizeGrip` ROW, and no setting behind it. The grip is drawn whenever
    -- the window is UNLOCKED and hidden whenever it is locked, which is the same
    -- question the lock already answers. Locking a window is how you put the
    -- grip away.
    --
    -- `frame.position` is deliberately NOT a row either. It is written by a drag,
    -- it is four values with one meaning, and -- rule R3 -- it is never read back
    -- off the live frame. A global reset reaches it the way it reaches everything
    -- else: "Reset all settings" is a PROFILE reset, and a position lives in the
    -- profile. `/mm reset-positions` is the targeted verb, and it goes to
    -- modules/WindowManager.lua, which owns re-anchoring a live frame.
    -- TWO KINDS OF CONTROL ON ONE TAB, so two subsection headings (options-ui-§7).
    -- The pair below are about THIS window; the four under "All surfaces" are
    -- broadcasts that set several other rows at once and are read by nothing --
    -- which is exactly what a reader has to be told before they meet a row called
    -- "Font (all surfaces)" three inches under a row called "Font".
    {
        path = "window.frame.locked", type = "bool", default = false,
        page = "frame", group = L["General"], subgroup = L["Window"],
        label = L["Lock window"],
        desc = L["When unlocked you can drag the window to reposition it and drag its corner to resize. Nothing else changes \226\128\148 for placeholder rows use Test mode on the General page. Lock frame on the General page locks every window at once, whatever this says."],
    },
    {
        path = "window.frame.clampToScreen", type = "bool", default = true,
        page = "frame", group = L["General"], subgroup = L["Window"],
        label = L["Keep on screen"], desc = L["Prevent the window from being dragged off the edge of the screen."],
    },
    -- THE FOUR META ROWS. Each sets several other rows at once rather than being
    -- read by anything itself (see the comment on the color-mode row below for
    -- the full argument, which applies to all four).
    --
    -- TWO OF THEM CARRY AN `LSM30_*` dialogControl and are NOT a font or bar
    -- group, so a grep for `LSM30_` under settings/ finds them outside any
    -- composer call site and that is correct. options-ui-§16 fixes the shape of a
    -- GROUP: contiguous, over one surface, with a colour row and its companion. A
    -- write-only setter over seven surfaces has no size, no colour, no flags and
    -- no second surface to be contiguous with, and a composer asked to emit one
    -- would have to emit five rows this addon must not store. The `All surfaces`
    -- subgroup heading is what stops a reader mistaking them for the real font
    -- group on the Header page. Recorded in docs/settings-panel.md under `The
    -- composed blocks`; it is a judgement about scope, not a deviation.
    --
    -- `closeButton` and the rest
    -- of the header's own controls, and the column-header strip, are edited on
    -- the Header and Columns pages now -- every one of them is still
    -- `window.frame.*` or `window.columnHeader.*` under the hood, unrenamed.
    {
        -- A META ROW: it sets seven others rather than being read by anything.
        -- Every surface in a window carries its own colour mode -- the bar and its
        -- background, both header strips and both of their backgrounds, and both
        -- of the tooltip's bars -- which is right when a player wants one of them
        -- different and tedious when they want them all the same, which is the
        -- usual case.
        --
        -- IT SKIPS THE TWO TEXT SURFACES, and COLOR_MODE_PATHS says why at
        -- length: text is drawn on top of a surface this row broadcasts to, so
        -- making it agree is what makes it unreadable.
        --
        -- IT STORES WHAT WAS LAST BROADCAST AND NOTHING READS IT BACK. A player
        -- who then changes one surface individually has changed one surface; the
        -- meta does not fight them for it and does not claim to describe them
        -- afterwards. Deriving it instead -- showing "mixed" when the seven
        -- disagree -- would make a control that cannot be set to the value it is
        -- displaying, which is worse than a shortcut that goes stale.
        path = "window.colorMode", type = "string", default = "custom",
        values = TEXTCOLOR_VALUES, sorting = TEXTCOLOR_SORT,
        page = "frame", group = L["General"], subgroup = L["All surfaces"],
        label = L["Color mode (all surfaces)"],
        desc = L["Set the color mode of every bar and header in this window at once. Text colors are left alone — they sit on top of these surfaces and have to contrast with them. Each surface is still its own setting, so you can change one afterwards without changing the rest."],
        onChange = broadcastColorMode,
    },
    {
        path = "window.barTexture", type = "string", default = "Blizzard Raid Bar",
        values = lsmValues("statusbar"), dialogControl = "LSM30_Statusbar",
        page = "frame", group = L["General"], subgroup = L["All surfaces"],
        label = L["Bar texture (all surfaces)"],
        desc = L["Set the bar texture for the grid and the tooltip at once. Each of them is still its own setting."],
        onChange = broadcastBarTexture,
    },
    {
        path = "window.font", type = "string", default = "Friz Quadrata TT",
        values = lsmValues("font"), dialogControl = "LSM30_Font",
        page = "frame", group = L["General"], subgroup = L["All surfaces"],
        label = L["Font (all surfaces)"],
        desc = L["Set the font for the cell text, both header strips and the tooltip at once. Each of them is still its own setting."],
        onChange = broadcastFont,
    },
    {
        path = "window.fontOutline", type = "string", default = "NONE",
        values = OUTLINE_VALUES, sorting = OUTLINE_SORT,
        page = "frame", group = L["General"], subgroup = L["All surfaces"],
        label = L["Font outline (all surfaces)"],
        desc = L["Set the font outline for the cell text, both header strips and the tooltip at once. Each of them is still its own setting."],
        onChange = broadcastOutline,
    },
    {
        path = "window.frame.width", type = "number", default = 694,
        min = 160, max = 1400, step = 10, fmt = "%d px",
        page = "frame", group = L["Size and position"],
        label = L["Width"], desc = L["Window width in pixels."],
    },
    {
        path = "window.frame.height", type = "number", default = 220,
        min = 60, max = 900, step = 10, fmt = "%d px",
        page = "frame", group = L["Size and position"],
        label = L["Height"], desc = L["Window height in pixels."],
    },
    {
        path = "window.frame.scale", type = "number", default = 1.0,
        min = 0.5, max = 2.0, step = 0.05, fmt = "%.2fx",
        page = "frame", group = L["Size and position"],
        label = L["Scale"], desc = L["Scale multiplier applied to the whole window."],
        validate = isNumberIn(0.5, 2.0),
    },
    {
        path = "window.frame.alpha", type = "number", default = 1.0,
        min = 0, max = 1, step = 0.01, isPercent = true,
        page = "frame", group = L["Size and position"],
        label = L["Opacity"], desc = L["Overall opacity of the window."],
        validate = isNumberIn(0, 1),
    },
    {
        path = "window.frame.strata", type = "string", default = "MEDIUM",
        values = STRATA_VALUES, sorting = STRATA_SORT,
        page = "frame", group = L["Size and position"],
        label = L["Frame strata"], desc = L["Which layer the window sits in relative to the rest of your interface."],
    },
    {
        path = "window.frame.padding", type = "number", default = 6,
        min = 0, max = 32, step = 1, fmt = "%d px",
        page = "frame", group = L["Size and position"],
        label = L["Padding"], desc = L["Gap in pixels between the window edge and the rows inside it."],
    },
    -- ── Background and border ────────────────────────────────────────
    -- Both the fill inside the window and the edge around it, together: they used
    -- to be split across "Size and position" and "Border style" for no reason
    -- beyond having been declared that way, and a player looking for "what color
    -- is my window" was looking under a heading that said border.
    -- THE FILL INSIDE THE WINDOW FIRST, then the edge around it, each under its
    -- own subsection heading (options-ui-§7): one tab, two kinds of control, and a
    -- player scanning it can now see where one stops. Both blocks are composed --
    -- see FRAME_BG_ROWS and FRAME_BORDER_ROWS above.
    block(FRAME_BG_ROWS),
    block(FRAME_BORDER_ROWS),
    -- ── Row ──────────────────────────────────────────
    -- FROM THE BARS PAGE. What the first four decide -- how tall a row is, how
    -- many there are and which way they grow -- shapes every bar the window
    -- draws, so they sit with the rest of the frame's own geometry rather than
    -- with the bar's appearance. The four under them are how a row BEHAVES: who
    -- is pinned, who is highlighted, and the stripe behind every other one.
    --
    -- ONE TAB, not the two it was. "Rows" and "Row behavior" were four controls
    -- each and one subject between them, and a player deciding how their grid
    -- reads was clicking between the two to do it.
    --
    -- The PATHS stay `window.rows.*`; a row's page is where it is edited, its
    -- path is where it is stored.
    {
        path = "window.rows.maxRows", type = "number", default = 0,
        min = 0, max = Const.MAX_ROWS, step = 1,
        page = "frame", group = L["Row"],
        label = L["Maximum rows"],
        desc = L["Largest number of rows to draw. Set to 0 to draw as many as the window has room for."],
        validate = isNumberIn(0, Const.MAX_ROWS),
    },
    {
        path = "window.rows.height", type = "number", default = 16,
        min = 8, max = 40, step = 1, fmt = "%d px",
        page = "frame", group = L["Row"],
        label = L["Row height"], desc = L["Height of one row in pixels."],
    },
    {
        path = "window.rows.spacing", type = "number", default = 1,
        min = 0, max = 10, step = 1, fmt = "%d px",
        page = "frame", group = L["Row"],
        label = L["Row spacing"], desc = L["Gap in pixels between adjacent rows."],
    },
    {
        path = "window.rows.growthDirection", type = "string", default = "DOWN",
        values = GROWTH_VALUES, sorting = GROWTH_SORT,
        page = "frame", group = L["Row"],
        label = L["Growth direction"], desc = L["Whether rows stack downward from the header or upward from the bottom."],
    },
    -- `rows.alternatingBackground` joined these from Bars' "Bar background color"
    -- group. `rows.classBackground` and `rows.classBackgroundAlpha` are gone
    -- entirely, and were doing nothing before they went: the row tint is painted
    -- per CELL from `bars.bgColorMode` and `bars.bgAlpha` (modules/Row.lua's
    -- cellBackground) -- it moved there when tinting the row itself turned out to
    -- lose the separators between columns -- and these two were left behind
    -- pointing at keys nothing reads.
    {
        path = "window.rows.alwaysShowSelf", type = "bool", default = true,
        page = "frame", group = L["Row"],
        label = L["Always show yourself"],
        desc = L["Keep your own row visible even when it would fall outside the maximum row count."],
    },
    {
        path = "window.rows.highlightSelf", type = "bool", default = false,
        page = "frame", group = L["Row"],
        label = L["Highlight yourself"], desc = L["Mark your own row so it stands out at a glance."],
    },
    {
        path = "window.rows.mouseoverHighlight", type = "bool", default = true,
        page = "frame", group = L["Row"],
        label = L["Highlight on mouseover"], desc = L["Brighten the row under the cursor."],
    },
    {
        -- FROM THE ROWS PAGE, into the group that owns the other thing drawn
        -- behind a row. It is a ROW-level fact (modules/Row.lua's RowProto:Update
        -- draws it, not the cells), and its PATH says so -- but a player choosing
        -- between a class tint and a stripe was reading two pages to do it.
        path = "window.rows.alternatingBackground", type = "bool", default = false,
        page = "frame", group = L["Row"],
        label = L["Alternating background"],
        desc = L["Shade every other row slightly so the grid is easier to read across. Sits behind the bar background above, so a strong tint will hide it."],
    },

    -- ── Header ────────────────────────────────────────────────────
    --
    -- FOUR ROWS LIVED AT THE TOP OF THIS PAGE and all four are gone, because each
    -- of them said something that was already on screen.
    --
    --   `title`            a second name for a window that already has one. The
    --                      header draws `window.name` now, always, so renaming a
    --                      window renames its header and there is no way for the
    --                      two to disagree.
    --   `showSessionName`  "Overall" written beside a window the player called
    --                      Overall.
    --   `showDuration`     the segment's own length, over a header whose segment
    --                      picker names the segment.
    --   `showTotals`       a group total, over a column holding the same figure
    --                      per player.
    --
    -- What the right-hand header line still says is in modules/Window.lua's
    -- UpdateHeaderText, and it is state rather than preference: the drill-down
    -- title and the restricted notice.
    --
    -- FOUR TABS: the title bar's own shape (Title bar), the face drawn on it
    -- (Title text), then every toggle for the icon strip it carries (Controls),
    -- and how every one of those controls is drawn (Button style). The
    -- column-header strip that used to sit here as a third group moved to the
    -- Columns page it labels -- see the note there.

    -- ── Title bar ────────────────────────────────────────────────
    -- Whether it draws, and its shape: alignment, height and background. This
    -- toggle is the header page's master switch, so its path moved with it:
    -- `window.header.show`, not `window.frame.titleBar` -- a path naming `frame`
    -- for a row on the Header page misleads the next reader and reads wrong in
    -- `/mm set`.
    -- THREE KINDS OF CONTROL ON ONE TAB, so three subsection headings
    -- (options-ui-§7): the strip's own shape, the fill behind it, and the hairline
    -- under it. The rows are re-ordered to make each block contiguous -- a heading
    -- is emitted when `subgroup` CHANGES, so an interleaved block would print one
    -- of them twice -- and nothing stored moved.
    {
        path = "window.header.show", type = "bool", default = true,
        page = "header", group = L["Title bar"], subgroup = L["Layout"],
        label = L["Show title bar"], desc = L["Draw the title strip along the top of the window."],
    },
    {
        path = "window.header.align", type = "string", default = "LEFT",
        values = ALIGN_VALUES, sorting = ALIGN_SORT,
        page = "header", group = L["Title bar"], subgroup = L["Layout"],
        label = L["Alignment"], desc = L["Where the header text sits horizontally."],
    },
    {
        path = "window.header.height", type = "number", default = 18,
        min = 8, max = 48, step = 1, fmt = "%d px",
        page = "header", group = L["Title bar"], subgroup = L["Layout"],
        label = L["Header height"], desc = L["Height of the header strip in pixels."],
    },
    -- THE ONE SWATCH IN THIS ADDON WITH NO COLOUR MODE BESIDE IT, and the absence
    -- is argued rather than overlooked -- see the note on the column-header strip's
    -- own background on the Columns page, which keeps one for a reason this strip
    -- does not have. Neither of the two modes says anything true here: "per
    -- statistic" over ONE strip spanning the whole window could only ever mean the
    -- sort column's colour, a fact already on screen twice, and the same argument
    -- took the mode off this strip's TEXT background. Recorded as a documented
    -- deviation against options-ui-§17 in docs/ARCHITECTURE.md.
    {
        path = "window.header.bgColor", type = "color",
        default = { r = 0, g = 0, b = 0, a = 0.5 },
        page = "header", group = L["Title bar"], subgroup = L["Background"],
        startsLine = true,
        label = L["Header background"], desc = L["Color drawn behind the title bar. The column-header strip has its own, on the Columns page."],
    },
    -- THE HAIRLINE BETWEEN THE TITLE BAR AND THE COLUMN LABELS, and the one piece
    -- of the window's chrome that is a setting. It earns its keep when both
    -- strips are drawn plainly and is a line across the window for nothing once
    -- the title bar's own background is doing the separating -- which is a look,
    -- so it is the player's call rather than a rule.
    --
    -- ON by default: it is what the window has always drawn, and a chrome
    -- element that disappears on upgrade is a bug report.
    --
    -- THREE ROWS, NOT ONE, and the colour mode below is where the interesting
    -- part is. `NS.ApplySkin` tints `frame.divider` from LibKa0s-Core-1.0's shared
    -- SKIN; the mode's shipped value, `skin`, does not read that table and write
    -- it -- it writes NOTHING, leaving the library's tint standing. That is what
    -- keeps standalone-windows intact through a per-window picker: the rule is
    -- "never restate SKIN's values", and nothing here restates them.
    {
        path = "window.header.divider", type = "bool", default = true,
        page = "header", group = L["Title bar"], subgroup = L["Divider"],
        label = L["Show divider"],
        desc = L["Draw the hairline between the title bar and the column labels."],
    },
    {
        path = "window.header.dividerThickness", type = "number", default = 1,
        min = 1, max = 8, step = 1, fmt = "%d px",
        page = "header", group = L["Title bar"], subgroup = L["Divider"],
        label = L["Divider thickness"],
        desc = L["How thick the hairline under the title bar is, in pixels. It grows downward, into the gap above the column labels."],
        validate = isNumberIn(1, 8),
    },
    {
        -- A MID GREY, and deliberately not the skin's own values. Seeding this
        -- with SKIN.divider would be the copy standalone-windows forbids -- the
        -- one that drifts a hex digit at a time and then has to be migrated -- and
        -- it would also be a lie about what the row is: this is the colour the
        -- player CHOSE, and it is read only under `custom`, where the skin has
        -- already been declined.
        path = "window.header.dividerColor", type = "color",
        default = { r = 0.5, g = 0.5, b = 0.5, a = 0.85 },
        page = "header", group = L["Title bar"], subgroup = L["Divider"],
        startsLine = true,
        label = L["Divider color"],
        desc = L["Color of the hairline under the title bar, used when the mode beside it is Custom color."],
        classColorSource = "player",
    },
    {
        path = "window.header.dividerColorMode", type = "string", default = "skin",
        values = DIVIDERCOLOR_VALUES, sorting = DIVIDERCOLOR_SORT,
        page = "header", group = L["Title bar"], subgroup = L["Divider"],
        label = L["Divider color mode"],
        classColorSource = "player",
        desc = L["What colors the hairline. Ka0s skin leaves it to the shared collection skin, so a re-skin reaches this window along with the debug console and the perf panel; Class color is your own class."],
    },
    -- ── Title text ──────────────────────────────────────────────
    -- TWO MODES, NOT THREE, and the half that is missing is the interesting half.
    --
    -- NO `stat`. Per-statistic could only ever paint this the SORT column's
    -- colour -- a fact already on screen twice, in that column's own header and
    -- in its arrow -- and the title bar is ONE strip over the whole window rather
    -- than a thing belonging to a column. That is the same argument that took the
    -- mode off the title bar's BACKGROUND, and it still holds, which is why this
    -- row takes the CONTROLS' pair rather than the three every cell surface answers.
    --
    -- CLASS DID NOT SURVIVE THE SAME ARGUMENT, and this note used to say it had:
    -- "class could only be the local player's, which the title bar is not about --
    -- it names the window". What settled it the other way is the rest of the
    -- strip. The controls wear a class colour and so does the divider under them;
    -- a title that alone could not was the odd one out rather than the principled
    -- one, and "this header is mine" is a perfectly good thing for a player to
    -- want a window to say. It is still the LOCAL player's class, because that is
    -- the only class a window-wide strip can mean.
    -- options-ui-§16's font block, composed rather than written out here -- see
    -- HEADER_TEXT_ROWS above. The colour MODE sits where the composer's boolean
    -- companion would, immediately to the swatch's right.
    block(HEADER_TEXT_ROWS),
    -- ── The meter's controls (issue #6) ────────────────────────────────────
    -- ON THE HEADER PAGE, which is where a player looks for them. They were on
    -- Frame for as long as `frame.closeButton` was the only one of them, and the
    -- stored PATHS are still `window.frame.*` -- every one of these draws into the
    -- frame's title bar, and renaming the keys to `window.header.*` for symmetry
    -- would migrate every stored profile in exchange for a tidiness nobody can
    -- see. A row's page is where it is EDITED; its path is where it is STORED.
    --
    -- ONE GROUP, not the two it was. They were split by what they act on --
    -- "Window buttons" for close, minimise, lock and settings; "Meter buttons"
    -- for the segment text, the segment picker, reset and export -- which is a
    -- true distinction and a useless one to click through: they are eight
    -- toggles for eight icons in one strip, and a player turning that strip down
    -- to the four they use was reading two tabs to find them. Kept CONTIGUOUS,
    -- because a group heading is emitted only when `group` CHANGES between
    -- consecutive rows.
    --
    -- Every default here is stated a SECOND time in defaults/Profile.lua, and
    -- both statements are checked against each other -- see the note above on
    -- why the two are deliberately not factored into one shared constant.
    --
    -- DECLARED IN THE ORDER THE STRIP READS, left to right: the segment line,
    -- then export, reset, the segment picker, settings, lock, minimise and
    -- close. modules/HeaderControls.lua's CONTROLS table is the same set written
    -- RIGHT to left -- index 0 sits against the frame's right edge -- so the two
    -- lists are deliberately mirror images and neither is the other's source.
    -- What matters is that a player ticking a box here can find the icon it
    -- governs by counting from the same end.
    {
        -- THE TEXT, not the button below it, and they are deliberately two rows.
        -- The picker is a click target in the icon strip; this is the line that
        -- says which fight you are looking at. A player who keeps the strip tidy
        -- and still wants to know what the window is showing needs to be able to
        -- turn one off without the other.
        path = "window.frame.showSegmentText", type = "bool", default = true,
        page = "header", group = L["Controls"],
        label = L["Show segment"],
        desc = L["Name the fight this window is showing, in the header to the left of the controls."],
    },
    {
        path = "window.frame.showExport", type = "bool", default = true,
        page = "header", group = L["Controls"],
        label = controlLabel("export", L["Show export"]), desc = L["Export this window's segment to CSV or to chat."],
    },
    {
        path = "window.frame.showReset", type = "bool", default = true,
        page = "header", group = L["Controls"],
        label = controlLabel("reset", L["Show reset"]), desc = L["Clear every recorded combat session. Asks first -- it wipes the game's own meter data too, not just this addon's."],
    },
    {
        path = "window.frame.showSegment", type = "bool", default = true,
        page = "header", group = L["Controls"],
        label = controlLabel("segment", L["Show segment picker"]), desc = L["Choose which fight this window shows. The session line stays clickable either way."],
    },
    {
        path = "window.frame.showSettings", type = "bool", default = true,
        page = "header", group = L["Controls"],
        label = controlLabel("settings", L["Show settings"]), desc = L["Open this addon's settings at the window you clicked."],
    },
    {
        path = "window.frame.showLock", type = "bool", default = true,
        page = "header", group = L["Controls"],
        label = controlLabel("lock", L["Show lock"]), desc = L["Lock or unlock the window for dragging."],
    },
    {
        path = "window.frame.showMinimise", type = "bool", default = true,
        page = "header", group = L["Controls"],
        label = controlLabel("minimise", L["Show minimise"]), desc = L["Collapse the window to its title bar and back."],
    },
    {
        path = "window.frame.closeButton", type = "bool", default = true,
        page = "header", group = L["Controls"],
        label = controlLabel("close", L["Show close"]), desc = L["Draw a close button in the title bar."],
    },
    -- `frame.minimised` is a HIDDEN row: it exists so the path is writable and
    -- listable, and it draws no control on the panel. It is STATE, not a
    -- preference -- the header's minimise control writes it, and a window left
    -- collapsed comes back collapsed. As a checkbox it duplicated that control on
    -- a page you have to open to reach, and read as a setting when it is a
    -- record of what you last did. `showMinimise` -- whether the control is
    -- drawn at all -- is the preference, and it stays a checkbox above. It cannot
    -- simply be DELETED the way `frame.position` is absent, and that is the
    -- whole reason `hidden` exists: NS.SetByPath refuses a path with no row, and
    -- the minimise control writes through that seam rather than poking the
    -- config table, because SetByPath is what publishes CONFIG_CHANGED. Filed
    -- with the other controls, contiguous with them, because that is the group
    -- it would draw in if it drew at all.
    {
        path = "window.frame.minimised", type = "bool", default = false, hidden = true,
        page = "header", group = L["Controls"],
        label = L["Minimised"], desc = L["Collapsed to the title bar. The window's stored height is untouched, so expanding restores it exactly."],
    },
    -- ── Button style ──────────────────────────────────────────────
    -- How every one of the eight controls above is drawn, not what any one of
    -- them does. THREE KINDS OF CONTROL, so three subsection headings
    -- (options-ui-§7): how big the icons are and whether they fade, what colours
    -- them, and how opaque each state is.
    --
    -- THE PAIRING CHANGED, and it is options-ui-§17 that changed it. It used to
    -- read ACROSS -- rest beside hover, down three lines of mode, colour, opacity
    -- -- which put `controlColor` two rows away from the mode that governs it. A
    -- colour swatch's companion goes IMMEDIATELY TO ITS RIGHT, so each state is now
    -- one line of its own (swatch, then mode) and rest against hover is read down
    -- the two lines rather than across one. The opacity pair is unaffected and
    -- still reads across, which is what it always did.
    {
        path = "window.frame.hoverReveal", type = "bool", default = true,
        page = "header", group = L["Button style"], subgroup = L["Icon"],
        label = L["Reveal controls on hover"], desc = L["Fade every control except the one under the pointer. Off keeps them all visible."],
    },
    {
        path = "window.frame.controlSize", type = "number", default = 16,
        min = 10, max = 32, step = 1,
        page = "header", group = L["Button style"], subgroup = L["Icon"],
        label = L["Control size"], desc = L["How large each header control is drawn, in pixels."],
    },
    -- Two modes rather than one, because rest and hover are two independent answers: a player who
    -- wants their class colour under the pointer has not asked for the whole strip in it at rest,
    -- and a shared mode would make hover and rest the same colour for anyone who chose class --
    -- the one thing a hover colour must never be.
    --
    -- CLASS IS THE LOCAL PLAYER'S on both: a header control belongs to the WINDOW
    -- and not to any row in it, which is the same call modules/Window.lua's
    -- headerColor makes for the title beside them.
    {
        path = "window.frame.controlColor", type = "color",
        default = { r = 1, g = 1, b = 1, a = 1 },
        page = "header", group = L["Button style"], subgroup = L["Color"],
        startsLine = true,
        label = L["Control color"], desc = L["Color the header controls are drawn in."],
        classColorSource = "player",
    },
    {
        path = "window.frame.controlColorMode", type = "string", default = "custom",
        values = CONTROLCOLOR_VALUES, sorting = CONTROLCOLOR_SORT,
        page = "header", group = L["Button style"], subgroup = L["Color"],
        label = L["Control color mode"],
        classColorSource = "player",
        desc = L["What colors the header controls at rest."],
    },
    {
        path = "window.frame.controlHoverColor", type = "color",
        default = { r = 1, g = 0.82, b = 0, a = 1 },
        page = "header", group = L["Button style"], subgroup = L["Color"],
        startsLine = true,
        label = L["Control hover color"],
        desc = L["Color the control under the pointer is drawn in."],
        classColorSource = "player",
    },
    {
        path = "window.frame.controlHoverColorMode", type = "string", default = "custom",
        values = CONTROLCOLOR_VALUES, sorting = CONTROLCOLOR_SORT,
        page = "header", group = L["Button style"], subgroup = L["Color"],
        label = L["Control hover color mode"],
        classColorSource = "player",
        desc = L["What colors a header control while the pointer is over it."],
    },
    -- THE TWO ENDS OF THE REVEAL, and they were a hardcoded 0.25 and 1 until now.
    -- Both defaults are those two numbers, so a window that never touches either
    -- slider is drawn exactly as it was.
    --
    -- `controlAlpha` IS READ ONLY WHILE THE REVEAL IS ON -- with fading off there
    -- is no faded state to have an opacity -- and it is deliberately NOT disabled
    -- on the panel when it is off, which is the same bargain `bars.customColor`
    -- gets under a non-custom colour mode: setting the faded level before
    -- switching fading on is the normal order of operations, and a greyed-out
    -- slider makes that a two-visit job. See modules/HeaderControls.lua's
    -- stripAlphas.
    {
        path = "window.frame.controlAlpha", type = "number", default = 0.25,
        min = 0, max = 1, step = 0.01, isPercent = true,
        page = "header", group = L["Button style"], subgroup = L["Opacity"],
        label = L["Control opacity"],
        desc = L["How faint a control NOT under the pointer is drawn, while Reveal controls on hover is on. With the reveal off there is nothing faded and this is not read."],
        validate = isNumberIn(0, 1),
    },
    {
        path = "window.frame.controlHoverAlpha", type = "number", default = 1.0,
        min = 0, max = 1, step = 0.01, isPercent = true,
        page = "header", group = L["Button style"], subgroup = L["Opacity"],
        label = L["Control hover opacity"],
        desc = L["How opaque the control under the pointer is drawn. With Reveal controls on hover off, every control sits at this."],
        validate = isNumberIn(0, 1),
    },

    -- ── Bars ────────────────────────────────────────────────────
    -- `class` is the default because classFilename is NeverSecret: a class-colored
    -- bar is still correct at the height of a pull, when every number on the row is
    -- an opaque handle.
    --
    -- SIX TABS: the bar's own fill (Bar), what sits behind it (Background), its
    -- edge (Border), what the cell says (Text content, then Text style), and the
    -- row icon (Icons). "Background" and "Border" say bar without spelling it --
    -- every tab on this page is about the bar, so the word carried nothing. Row
    -- layout and row behaviour moved to the Frame page -- they shape the grid
    -- every bar here is drawn in, not the bar itself.
    -- THE BAR, WHAT SITS BEHIND IT AND ITS EDGE, in that order and one composed
    -- block each (options-ui-§16) -- see BARS_BAR_ROWS, BARS_BG_ROWS and
    -- BARS_BORDER_ROWS above. `fillDirection` is a legitimate extra and is appended
    -- AFTER the mandated four rather than interleaved with them; the background is
    -- a backdrop with no fill texture, so it is a colour pair and not a bar group.
    block(BARS_BAR_ROWS),
    -- ── Background ──────────────────────────────────────────────────
    block(BARS_BG_ROWS),
    -- ── Border ────────────────────────────────────────────────────
    block(BARS_BORDER_ROWS),
    -- ── Text content ──────────────────────────────────────────────
    -- Two slots per cell. Nothing here divides anything: `numberFormat` picks WHICH
    -- NumericRuleFormatter instance modules/Format.lua hands the value to, and the
    -- formatter does the division natively -- the only legal way to render "12.4M"
    -- from a secret (design section 4).
    --
    -- WHAT the cell says, split from HOW it is drawn below: content here, style
    -- in the next tab.
    {
        path = "window.text.leftSlot", type = "string", default = "smart",
        values = SLOT_VALUES, sorting = SLOT_SORT,
        page = "bars", group = L["Text content"],
        label = L["Left text"], desc = L["What to show on the left of each cell. The two smart values both follow the column: one shows the per-second figure where there is one and the absolute figure everywhere else, the other shows both side by side and falls back to the absolute alone. None means none: the cell is left empty."],
    },
    {
        path = "window.text.rightSlot", type = "string", default = "none",
        values = SLOT_VALUES, sorting = SLOT_SORT,
        page = "bars", group = L["Text content"],
        label = L["Right text"],
        desc = L["What to show on the right of each cell, beside the left figure. Per-second figures exist only for Damage and Healing; a column without one renders nothing rather than substituting its total."],
    },
    {
        path = "window.text.numberFormat", type = "string", default = "abbreviated",
        values = NUMFMT_VALUES, sorting = NUMFMT_SORT,
        page = "bars", group = L["Text content"],
        label = L["Number format"],
        desc = L["How large numbers are written. The three abbreviated forms differ only in how many decimal places they keep; Full writes every digit. There is no thousands-separated form -- separating digits means reading them, and a meter value cannot be read while a pull is running."],
    },
    {
        path = "window.text.deathTimeFormat", type = "string", default = "clock",
        values = DEATHTIME_VALUES, sorting = DEATHTIME_SORT,
        page = "bars", group = L["Text content"],
        label = L["Death timestamps"],
        desc = L["How a death is labelled in the Deaths tooltip and the death list."],
    },
    {
        -- 15 rather than WoW's 12-character player-name limit: a group meter also
        -- shows NPC names — follower-dungeon companions, and the enemy rows the
        -- damage-taken columns are made of — and those are not bound by it. It
        -- shipped at 20, which is wider than any name in a full group of players
        -- and spent that width on the columns beside it.
        -- 0 is the explicit off switch.
        path = "window.text.maxNameLength", type = "number", default = 15,
        min = 0, max = 40, step = 1, fmt = "%d",
        page = "bars", group = L["Text content"],
        label = L["Max name length"],
        desc = L["Truncate a name past this many characters. 0 shows the whole name. The realm is always stripped."],
    },
    -- ── Text style ──────────────────────────────────────────────
    -- options-ui-§16's font block, composed -- see BARS_TEXT_ROWS above. Text
    -- opacity is this addon's own and is appended after the mandated six.
    block(BARS_TEXT_ROWS),
    -- ── Icons ────────────────────────────────────────────────────
    -- classFilename and specIconID are NeverSecret, so these render correctly even
    -- mid-pull when every number beside them is opaque.
    {
        path = "window.icons.showIcon", type = "bool", default = true,
        page = "bars", group = L["Icons"],
        label = L["Show icon"],
        desc = L["Show one icon beside each player's name: their specialization where it is known, and their class where it is not."],
    },
    {
        path = "window.icons.position", type = "string", default = "LEFT",
        values = SIDE_VALUES, sorting = SIDE_SORT,
        page = "bars", group = L["Icons"],
        label = L["Icon position"], desc = L["Which side of the player's name the icons sit on."],
    },
    {
        path = "window.icons.size", type = "number", default = 14,
        min = 8, max = 32, step = 1, fmt = "%d px",
        page = "bars", group = L["Icons"],
        label = L["Icon size"], desc = L["Size of the row icons in pixels."],
    },

    -- ── Tooltip ────────────────────────────────────────────────────
    -- SIX TABS: where it goes and how big it is (General), the spell bar's own
    -- fill, background and border, the face it is drawn in (Text), and last what
    -- it lists (Contents). The two tabs a player sets once and leaves are at the
    -- END -- the three bar tabs are the ones they come back to, and they now sit
    -- together in the middle rather than with a text tab wedged in front of them.
    -- No "At cursor" anchor: over a grid it lands wherever the pointer
    -- happens to be inside a cell, so the same hover puts the tooltip somewhere
    -- different every time. TOP is the deliberate version of the same thing --
    -- above the cell, in one place -- and is the default now.
    {
        path = "window.tooltip.anchor", type = "string", default = "TOP",
        values = ANCHOR_VALUES, sorting = ANCHOR_SORT,
        page = "tooltip", group = L["General"],
        label = L["Tooltip anchor"], desc = L["Where the tooltip appears relative to the cursor or the window."],
    },
    {
        -- The tooltip's own, not the window's: a player who wants a bigger grid
        -- and a small tooltip, or the reverse, is asking two questions. Bounded
        -- rather than free -- below 0.5 the text stops being readable and above 2
        -- the tooltip stops fitting beside the window it came from.
        path = "window.tooltip.scale", type = "number", default = 1.0,
        min = 0.5, max = 2.0, step = 0.05, fmt = "%.2fx",
        page = "tooltip", group = L["General"],
        label = L["Tooltip scale"],
        desc = L["How large the tooltip is drawn. It is put back to normal when the tooltip closes, so nothing else in the interface inherits it."],
        validate = isNumberIn(0.5, 2.0),
    },
    {
        path = "window.tooltip.offsetX", type = "number", default = 0,
        min = -400, max = 400, step = 1, fmt = "%d px",
        page = "tooltip", group = L["General"],
        label = L["Horizontal offset"],
        desc = L["Nudge the tooltip sideways from wherever the anchor puts it. Positive moves it right."],
        validate = isNumberIn(-400, 400),
    },
    {
        path = "window.tooltip.offsetY", type = "number", default = 0,
        min = -400, max = 400, step = 1, fmt = "%d px",
        page = "tooltip", group = L["General"],
        label = L["Vertical offset"],
        desc = L["Nudge the tooltip up or down from wherever the anchor puts it. Positive moves it up."],
        validate = isNumberIn(-400, 400),
    },
    -- Off by default. Nothing about a tooltip is unsafe in combat -- its numbers go
    -- through the formatter like every other -- but a tooltip under the cursor
    -- during a pull is in the way, so this is a preference rather than a guard.
    {
        path = "window.tooltip.hideInCombat", type = "bool", default = false,
        page = "tooltip", group = L["General"],
        label = L["Hide tooltips in combat"],
        desc = L["Suppress tooltips while you are in combat so nothing sits under your cursor mid-pull."],
    },
    -- ── Bar ────────────────────────────────────────────────────
    -- Tooltip bars are configured SEPARATELY from the grid's, rather than
    -- inherited from `window.bars`. They are a different surface at a different
    -- size -- a 14px spell line against a 90px cell -- and a texture that reads
    -- well across one often does not across the other. The fill and the backdrop
    -- each answer the same three modes every text surface answers.
    -- THE FILL AND THE BACKDROP EACH ANSWER THE SAME THREE MODES, the same three
    -- every text surface answers. The fill used to be the hovered player's class
    -- and nothing else, with no setting reaching it, and the backdrop was a
    -- hard-coded black at 0.35 that no setting reached either. Composed as
    -- options-ui-§16's bar block -- see TIP_BAR_ROWS above; bar spacing is this
    -- addon's own extra and is appended after the mandated four.
    block(TIP_BAR_ROWS),
    -- ── Bar background ──────────────────────────────────────────────
    -- The backdrop used to be a hard-coded black at 0.35 that no setting reached.
    -- It ships at 0.1 now: the tooltip's bars sit on the tooltip's own backdrop,
    -- which is already dark, so a third of a screen of black on top of it read as
    -- a smear rather than as an unfilled bar.
    block(TIP_BARBG_ROWS),
    -- ── Bar border ─────────────────────────────────────────────────
    -- Defaults to None, and that is not timidity. Most LibSharedMedia border art
    -- carries an 8-16px corner inset, and a spell bar is 14px tall -- so on a
    -- majority of the list the corners eat the whole edge. The option is here
    -- because it was asked for; the default is the one that always looks right.
    block(TIP_BARBORDER_ROWS),
    -- ── Text ────────────────────────────────────────────────────
    -- The font reaches GameTooltip's own line FontStrings, which are SHARED with
    -- every other addon -- so modules/Tooltip.lua restores every line it touched
    -- when the tooltip hides. See that file's `releaseLines`.
    block(TIP_TEXT_ROWS),
    -- ── Contents ──────────────────────────────────────────────
    {
        path = "window.tooltip.showSpells", type = "bool", default = true,
        page = "tooltip", group = L["Contents"],
        label = L["Show spell breakdown"], desc = L["List the individual spells behind a cell's number when you hover it."],
    },
    -- 0 is the explicit "no cap" value, the same spelling `rows.maxRows` and
    -- `text.maxNameLength` already use. It is honest rather than infinite: the
    -- collector stops at 64 rows however this is set, and the "and N more" line
    -- says so.
    {
        path = "window.tooltip.maxSpells", type = "number", default = 10,
        min = 0, max = 30, step = 1,
        page = "tooltip", group = L["Contents"],
        label = L["Maximum spells"],
        desc = L["How many spells to list in the breakdown before stopping. 0 lists every spell the breakdown found."],
        validate = isNumberIn(0, 30),
    },
    -- OFF by default, and for two reasons that are worth stating separately.
    -- It costs one provider call per enemy on a hover (modules/Targets.lua keeps
    -- built once per session), and it is a SUMMATION -- so it is absent for a pull
    -- rather than approximated. A player who wants it gets it; nobody pays for it
    -- without asking.
    {
        path = "window.tooltip.showTargets", type = "bool", default = false,
        page = "tooltip", group = L["Contents"],
        label = L["Show targets"],
        desc = L["On a Damage cell, list which enemies this player hit. Cross-referenced from the enemy damage taken column, so it is unavailable while a pull is in progress."],
    },
    {
        path = "window.tooltip.maxTargets", type = "number", default = 3,
        min = 1, max = 10, step = 1,
        page = "tooltip", group = L["Contents"],
        label = L["Maximum targets"], desc = L["How many enemies to list before stopping."],
        validate = isNumberIn(1, 10),
    },
    -- WHAT ENDED EACH DEATH, on the death list's own line: "Death 3 | Ragnaros |
    -- Sulfuras Smash". Two switches rather than one, because the two answer
    -- different questions -- who killed me is a positioning question and what
    -- killed me is a cooldown question -- and a player who wants one of them
    -- should not have to take the other with it.
    --
    -- THE CASTER SHIPS ON AND THE SPELL SHIPS OFF, which is the split a death
    -- list is actually read for. "Death 3" alone says nothing the reader did not
    -- already know -- the count is in the cell they hovered to get here -- and
    -- one name closes that. The SECOND name is what makes the line long: a spell
    -- name is the longest thing on it, it is the half most often absent (a melee
    -- swing, an environmental kill, a client that will not resolve the id), and
    -- it answers a question a reader has after they have clicked into the recap
    -- rather than while they are scanning the list. Available to anyone who wants
    -- it, and not paid for by everyone who does not.
    --
    -- Either half goes quiet on its own terms and neither is a failure: an
    -- environmental death has no caster, a melee swing has no spell name, and a
    -- restricted pull can withhold either -- see modules/Tooltip.lua's
    -- killingBlowOf, which draws what it can read plainly and nothing else.
    {
        path = "window.tooltip.showDeathCaster", type = "bool", default = true,
        page = "tooltip", group = L["Contents"],
        label = L["Name the killer"],
        desc = L["Add whoever landed the killing blow to each line of the Deaths list. Left off a death with no caster to name, such as a fall or a fire."],
    },
    {
        path = "window.tooltip.showDeathSpell", type = "bool", default = false,
        page = "tooltip", group = L["Contents"],
        label = L["Name the killing blow"],
        desc = L["Add the spell that landed the killing blow to each line of the Deaths list. A melee swing is named Melee; a spell the client cannot name is left off."],
    },
    {
        path = "window.tooltip.showAllStatsOnName", type = "bool", default = true,
        page = "tooltip", group = L["Contents"],
        label = L["Summarize on the name"],
        desc = L["Hovering a player's name shows every enabled statistic for that player at once."],
    },

    -- ── Visibility ─────────────────────────────────────────────────
    -- Refused AT THE SOURCE (performance section 6): a hidden window does not
    -- merely skip its draw, it stops asking the provider for data. That is why
    -- every row here carries an onChange -- the effect is a window appearing or
    -- disappearing, which is the show ladder's decision and not a redraw.
    {
        path = "window.visibility.dungeon", type = "bool", default = true,
        page = "visibility", group = L["Where to show this window"],
        label = L["Dungeons"], desc = L["Show this window in five-player dungeons, including Mythic+."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.raid", type = "bool", default = true,
        page = "visibility", group = L["Where to show this window"],
        label = L["Raids"], desc = L["Show this window in raid instances."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.arena", type = "bool", default = true,
        page = "visibility", group = L["Where to show this window"],
        label = L["Arenas"], desc = L["Show this window in arena matches."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.battleground", type = "bool", default = true,
        page = "visibility", group = L["Where to show this window"],
        label = L["Battlegrounds"], desc = L["Show this window in battlegrounds."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.delve", type = "bool", default = true,
        page = "visibility", group = L["Where to show this window"],
        label = L["Delves"], desc = L["Show this window inside delves."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.scenario", type = "bool", default = true,
        page = "visibility", group = L["Where to show this window"],
        label = L["Scenarios"],
        desc = L["Show this window in scenarios and follower dungeons. Delves have their own setting."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.world", type = "bool", default = true,
        page = "visibility", group = L["Where to show this window"],
        label = L["Open world"], desc = L["Show this window outside instances."],
        onChange = refreshVisibility,
    },
    -- Every rule below is HIDE-shaped, and deliberately so: a key missing from a
    -- stored window must read as "nothing objects". See modules/Visibility.lua.
    {
        path = "window.visibility.hideWhenSolo", type = "bool", default = false,
        page = "visibility", group = L["When to hide this window"],
        label = L["Hide when solo"], desc = L["Hide the window whenever you are not in a party or raid."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideInVehicle", type = "bool", default = false,
        page = "visibility", group = L["When to hide this window"],
        label = L["Hide in vehicles"], desc = L["Hide the window while you are controlling a vehicle."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideWhenMounted", type = "bool", default = false,
        page = "visibility", group = L["When to hide this window"],
        label = L["Hide when mounted"],
        desc = L["Hide the window while you are mounted, including a druid's travel forms."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideWhenSkyriding", type = "bool", default = false,
        page = "visibility", group = L["When to hide this window"],
        label = L["Hide when skyriding"],
        desc = L["Hide the window while you are on a skyriding mount, from the moment it can glide rather than once you are airborne."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideOnTaxi", type = "bool", default = false,
        page = "visibility", group = L["When to hide this window"],
        label = L["Hide on flight paths"], desc = L["Hide the window while you are riding a flight path."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideInHousing", type = "bool", default = false,
        page = "visibility", group = L["When to hide this window"],
        label = L["Hide in player housing"],
        desc = L["Hide the window while you are inside your house or on your plot."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideInPetBattle", type = "bool", default = false,
        page = "visibility", group = L["When to hide this window"],
        label = L["Hide in pet battles"], desc = L["Hide the window while a pet battle is on screen."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideWhenDead", type = "bool", default = false,
        page = "visibility", group = L["When to hide this window"],
        label = L["Hide while dead"],
        desc = L["Hide the window while you are dead or a ghost. Off by default: reading the meter while dead is most of what it is for."],
        onChange = refreshVisibility,
    },
    -- Two independent rules rather than one tri-state control. Ticking both is a
    -- window that never shows, which is the player's business; `/mm debug diag` still
    -- names the side of the pull that decided.
    {
        path = "window.visibility.hideInCombat", type = "bool", default = false,
        page = "visibility", group = L["Combat"],
        label = L["Hide in combat"], desc = L["Hide the window while you are fighting."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideOutOfCombat", type = "bool", default = false,
        page = "visibility", group = L["Combat"],
        label = L["Hide out of combat"], desc = L["Hide the window whenever you are not fighting."],
        onChange = refreshVisibility,
    },

    -- ── Columns ──────────────────────────────────────────────
    -- The array itself has NO ROWS. See "WHY THE COLUMNS ARE NOT ROWS" at the top
    -- of this file; the page exists in the panel and in `/mm list`, and its
    -- contents are the array, drawn by a bespoke block picker rather than by any
    -- row below.
    --
    -- The column-header STRIP that labels those columns is styled here, though,
    -- and used to sit on the Header page as a third group beside the title
    -- strip -- three clicks from the page where the columns it labels are chosen.
    -- It used to borrow the font and size from `text` and the outline and colour
    -- from `header`, which meant changing the cell font silently restyled it too;
    -- every default here is the value that arrangement already produced. The
    -- PATHS stay `window.columnHeader.*` -- a row's page is where it is edited,
    -- its path is where it is stored.
    block(COLHEAD_TEXT_ROWS),
    block(COLHEAD_BG_ROWS),

    -- ── General ──────────────────────────────────────────────
    -- The only genuinely addon-wide settings. Everything else is per-window.
    --
    -- ONE VISIBLE TAB of settings, plus the palette. **Master controls** is
    -- options-ui-§15's canonical set and is FIRST on this page in every Ka0s addon
    -- -- enable, general visibility, the two master multipliers, the addon-wide
    -- lock and the debug console -- and this addon's own four follow it: the
    -- minimap button, the two addon-wide data settings and Test mode. The two
    -- resets close the tab as a button pair.
    --
    -- **THE `General` TAB IS GONE**, and its four rows are that tail. It was four
    -- rows with nothing in common but "addon-wide", sitting behind a click next to
    -- the tab everybody opens -- the same argument that retired Maintenance and
    -- Data before it, arriving one tab later. §15 forbids REORDERING, RENAMING or
    -- SPLITTING the canonical set; it does not forbid an addon's own rows after
    -- it, and the six stay contiguous and first, which is what
    -- tests/test_schema.lua pins. Nothing moved in storage: a `group` is not a
    -- stored path.
    --
    -- `enabled` AND `state.debugConsole` MOVED INTO THE COMPOSED BLOCK and are
    -- declared nowhere else -- two controls over one setting is the thing this
    -- whole pass exists to remove. Their stored paths are unchanged, because a
    -- `group` is not a stored path and needs no migration.
    --
    -- TWO TABS BECAME NONE BEFORE THAT, ONE AT A TIME. "Maintenance" was one
    -- visible row -- the debug console -- carrying a tab of its own next to the two
    -- reset buttons keyed to it: a click to reach three controls that were never a
    -- subject. "Data" was two rows, and the same argument retired it. That merge
    -- STANDS; what §15 moved out of the merged tab is only the canonical rows,
    -- which belong at the top of the page under their own name.
    --
    -- The three hidden export choices stay last so the tabs above them stay
    -- CONTIGUOUS: a group heading is emitted only when `group` CHANGES, so a
    -- block wedged between two "General" rows would print that heading twice.
    block(MASTER_ROWS),
    -- The one inverted row: LibDBIcon owns this table and its key is `hide`, while
    -- a checkbox the user reads has to be phrased positively. See "Inversion".
    {
        path = "minimap.hide", type = "bool", default = false, invert = true,
        page = "general", group = L["Master controls"],
        label = L["Show minimap button"], desc = L["Show the minimap button for opening these settings."],
        onChange = refreshMinimap,
    },
    -- `data.mergePets` and `data.throttle` were `window.data.*` and are not
    -- per-window questions: one says what a pet's damage IS, the other is a
    -- refresh rate, and two windows disagreeing about either is two answers to
    -- one question. core/Database.lua's v4 -> v5 step lifts a stored pair off the
    -- first window in each profile. There is no Data PAGE any more -- the sort
    -- and session rows that used to share it with these two were deleted rather
    -- than moved, because the window's own controls already write them directly
    -- (modules/Window.lua's SortByColumn and the header's segment picker), and a
    -- settings page restating a control the player already has, three inches
    -- from where they are looking, was a second place for the same answer to
    -- live.
    {
        path = "data.mergePets", type = "bool", default = false,
        page = "general", group = L["Master controls"],
        label = L["Merge pets into their owner"],
        desc = L["Add a pet's numbers to its owner's row instead of giving it its own. Blizzard's combat restriction forbids the addition while you are fighting, so a merged pet's numbers are missing until the pull ends."],
    },
    {
        path = "data.throttle", type = "number", default = 0.25,
        min = Const.THROTTLE_MIN, max = Const.THROTTLE_MAX, step = 0.05, fmt = "%.2fs",
        page = "general", group = L["Master controls"],
        label = L["Refresh interval"],
        desc = L["Seconds between refreshes. Lower is more responsive and costs more; the display updates at most this often no matter how fast the game reports numbers."],
        validate = isNumberIn(Const.THROTTLE_MIN, Const.THROTTLE_MAX),
    },
    -- ── Session-only rows ──
    --
    -- Never persisted, so they have no home in the defaults tree and are exempt
    -- from ValidateSchema's resolution check. They are rows anyway because they
    -- belong on the page and in `/mm list` beside the settings they sit next to --
    -- a toggle that exists only in the panel is a toggle the CLI cannot reach.
    {
        path = "state.testMode", type = "bool", default = false, sessionOnly = true,
        page = "general", group = L["Master controls"],
        label = L["Test mode"],
        desc = L["Fill every window with placeholder data so you can lay out columns without being in combat."],
        get = function() return NS.State and NS.State.testMode or false end,
        set = function(v)
            -- Through the registry when it is up (unlocking and preview are coupled
            -- there), and through the state writer otherwise, which is the sole
            -- sender of TEST_MODE_CHANGED either way.
            local M = NS.WindowManager
            if M and M.SetTestMode then
                M:SetTestMode(v)
                -- Same rule as `/mm test`: leaving test mode is not closing the
                -- window. See settings/Slash.lua's doTest.
                if not v then
                    for _, inst in ipairs(M.All()) do inst:Show() end
                end
                return
            end
            if NS.State then NS.State.SetTestMode(v) end
        end,
    },

    -- ── Export ──────────────────────────────────────────────
    --
    -- Addon-wide rather than per-window, and last on the page so the tabs above
    -- stay contiguous. ALL THREE ARE `hidden`. They are the choices the EXPORT
    -- MODAL remembers -- its own three controls are the ones a player uses,
    -- sitting in the dialog they are exporting from -- so a second copy on the
    -- General page restated a control the player only ever meets in the other
    -- place, and gave the two a chance to disagree about what is selected.
    --
    -- HIDDEN RATHER THAN DELETED, unlike the sort and session rows that went with
    -- the old Data page, and the difference is which seam does the writing.
    -- Those were written directly by the window's own controls; these are
    -- written by the modal through NS.SetByPath -- which REFUSES a path with no
    -- row. Deleting them would drop every export choice onto writeExport's
    -- degraded fallback, losing the validation, the debug line and
    -- CONFIG_CHANGED, and would take `/mm set export.channel WHISPER` with it.
    --
    -- THE METRIC IS NOT AMONG THEM, and its absence is deliberate. It used to be,
    -- with a "Match the window" entry the sort column had no use for. Export.Open
    -- now seeds the metric from the window it was opened from, so a value set
    -- here would be overwritten before it was ever read.
    {
        path = "export.channel", type = "string", default = "SELF", hidden = true,
        values = CHANNEL_VALUES, sorting = CHANNEL_SORT,
        page = "general", group = L["Export"],
        label = L["Default channel"],
        desc = L["Where 'Print to Chat' sends its lines. Self only prints to your own chat frame and sends nothing to the group, which is why it is the default: a misclick cannot reach a raid."],
    },
    {
        -- No non-empty check, unlike the window-name row this otherwise copies:
        -- the empty string is this row's shipped default and a legal value, and
        -- it is what every channel but Whisper means. The validator is here to
        -- refuse a table typed in from a hand-edited SavedVariables, nothing
        -- more; whether the name resolves to a character is the server's answer
        -- to give, not this seam's.
        path = "export.whisperTo", type = "string", default = "", hidden = true,
        dialogControl = "EditBox", maxLetters = 48,
        page = "general", group = L["Export"],
        label = L["Whisper recipient"],
        desc = L["Who to whisper when the channel is Whisper. Cross-realm names need the realm, as Name-Realm."],
        validate = function(v) return type(v) == "string" end,
    },
    {
        -- Ceiling shared with the row cap rather than restated: the aggregator
        -- clamps an export to MAX_ROWS anyway, so a slider that offered 60 would
        -- be offering a number the send could not honor.
        path = "export.lines", type = "number", default = 5, hidden = true,
        min = 1, max = Const.MAX_ROWS, step = 1, fmt = "%d",
        page = "general", group = L["Export"],
        label = L["Chat lines"],
        -- The one desc carrying a number: stating the ceiling as a literal here
        -- would be a second copy of Const.MAX_ROWS in a sentence nobody would
        -- think to update.
        desc = L["How many ranked lines 'Print to Chat' sends, after the header line. The meter never holds more than %d rows, so that is the ceiling."]:format(Const.MAX_ROWS),
        validate = isNumberIn(1, Const.MAX_ROWS),
    },

    -- ── Profiles ──────────────────────────────────────────────
    -- No rows, and that is enforced twice: AceDBOptions supplies the controls, and
    -- `page == "profiles"` is the reset-all veto in settings/OptionsSetup.lua,
    -- because resetting a profile row deletes user data rather than restoring a
    -- default (options-ui section 3).
}

-- ---------------------------------------------------------------------------
-- The statistic palette (General -> Statistic colors)
-- ---------------------------------------------------------------------------
--
-- THE ONE GENERATED BLOCK IN THIS FILE, and the reason is that the rows are not
-- a design decision -- they are one swatch per entry of core/Constants.lua's
-- palette, and writing them out by hand would be a second copy of that table
-- that goes stale the day a statistic is added. The catalog decides what exists;
-- this decides how it is edited.
--
-- IN CATALOG ORDER, not `pairs` order, so the tab reads in the same left-to-right
-- order as a window's columns and two players comparing screenshots see the same
-- list. A stat with no palette entry gets no row rather than a black swatch --
-- see the note in defaults/Profile.lua's statColorDefaults.
--
-- ADDON-WIDE (`statColors.*`, no `window.` prefix) for the reason that file
-- states: the palette's job is telling one column from another at a glance, and
-- per-window would let two windows disagree about what green means.
--
-- Appended AFTER the literal above rather than woven into it, which puts the
-- group after the hidden Export block. That is fine and deliberate: Export draws
-- no tab, so the general page's visible strip is Master controls then Statistic
-- colors, and each group is still CONTIGUOUS, which is the property the heading
-- logic actually needs.
for _, stat in ipairs(Const.STATS) do
    local c = Const.STAT_COLORS[stat.key]
    if c then
        NS.Schema[#NS.Schema + 1] = {
            path = "statColors." .. stat.key, type = "color",
            default = { r = c[1], g = c[2], b = c[3], a = 1 },
            page = "general", group = L["Statistic colors"],
            label = L[stat.label],
            desc = L["Color for this statistic wherever it identifies a column: bars set to Per-statistic, the column header, and the tooltip's all-statistics list."],
        }
    end
end

-- ---------------------------------------------------------------------------
-- The two passes over the finished array
-- ---------------------------------------------------------------------------

-- ONE: the composed blocks are unpacked where they sit, so what every reader
-- downstream sees is a flat array of ordinary rows and nothing has to know a
-- composer was involved.
expandBlocks(NS.Schema)

-- TWO: every colour swatch is told, in words, what the mode beside it does to it.
-- options-ui-§17 forbids `disabledIf` on a colour row -- the swatch is still read
-- for its ALPHA under every mode, so greying it out would be a lie -- and this is
-- the sentence that replaces the greying.
--
-- THE PALETTE IS EXEMPT and is the only exemption the rule has: `statColors.*` is
-- one colour per STATISTIC, identifying a column rather than a player, so there is
-- no class for it to take and no mode beside it to warn about.
for _, row in ipairs(NS.Schema) do
    if row.type == "color" and row.path:sub(1, 11) ~= "statColors." then
        row.desc = (row.desc or "") .. " " .. SWATCH_NOTE
    end
end
