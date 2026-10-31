-- settings/Schema_Vocab.lua
--
-- THE DROPDOWN VOCABULARIES the schema rows' `values` and `sorting` point at. Peeled off
-- settings/Schema_Compose.lua for layout-§1 when that file reached 1470 lines: they read nothing
-- but the locale and core/Constants.lua, so they lift out whole. A pure move, published as
-- NS.SchemaVocab. settings/Schema_Compose.lua re-localizes each member under the name it always
-- had and still publishes it on NS.SchemaCompose, so no row file spells anything differently.
--
-- TOC POSITION: LOAD-BEARING. Before settings/Schema_Compose.lua, which resolves every member at
-- FILE SCOPE.

local _, NS = ...

local L     = NS.L
local Const = NS.Constants

-- ---------------------------------------------------------------------------
-- Dropdown vocabularies
-- ---------------------------------------------------------------------------
--
-- Key maps plus an explicit `sorting`, so the list reads in a deliberate order
-- (LOW → DIALOG, never alphabetically as "DIALOG, HIGH, LOW, MEDIUM"). The KEYS
-- are what is stored and what `/mm set` accepts; the values are display strings
-- and may be translated freely without touching a stored profile.

local STRATA_VALUES  = { LOW = L["Low"], MEDIUM = L["Medium"], HIGH = L["High"], DIALOG = L["Dialog"] }
local STRATA_SORT    = { "LOW", "MEDIUM", "HIGH", "DIALOG" }

local ALIGN_VALUES   = { LEFT = L["Left"], CENTER = L["Center"], RIGHT = L["Right"] }
local ALIGN_SORT     = { "LEFT", "CENTER", "RIGHT" }

-- "@skin" is From skin (LibKa0s v1.82.0's FROM_SKIN, ruling D-07), the default of every flags row:
-- the Skin tab's Font outline answers it through S.FontFlags (core/SkinSetup.lua's NS.SkinFontFlags).
-- NONE stays this addon's stored word for none, so every flag a player picked before is still a key.
local OUTLINE_VALUES = {
    ["@skin"]    = L["From skin"],
    NONE         = L["None"],
    OUTLINE      = L["Outline"],
    THICKOUTLINE = L["Thick outline"],
    MONOCHROME   = L["Monochrome"],
}
local OUTLINE_SORT   = { "@skin", "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME" }

local GROWTH_VALUES  = { DOWN = L["Down"], UP = L["Up"] }
local GROWTH_SORT    = { "DOWN", "UP" }

local SIDE_VALUES    = { LEFT = L["Left"], RIGHT = L["Right"] }
local SIDE_SORT      = { "LEFT", "RIGHT" }

local BARCOLOR_VALUES = {
    class  = L["Class color"],
    stat   = L["Per-statistic color"],
    custom = L["Custom color"],
}
local BARCOLOR_SORT  = { "class", "stat", "custom" }

-- The same three, plus an off switch. The background is decoration in a way the
-- bar is not, so it is the one of the two that a player may want gone entirely.
-- The color MODE every text surface offers, and the one the two header
-- backgrounds offer too. Three entries rather than the bar background's four:
-- `none` is a legal answer for a tint drawn behind something and never for the
-- writing itself, and a text surface set to "no color" is one nobody can read.
--
-- WHAT `stat` MEANS DEPENDS ON THE SURFACE, and each reader names which it took.
-- A CELL is about the statistic in its own column; a COLUMN HEADER about the
-- column it labels -- the one surface where "per statistic" is literally per
-- column; the TITLE BAR and the TOOLTIP about the window's SORT COLUMN, the
-- statistic the grid is currently ranked by. One question, answered by whichever
-- statistic the surface actually describes.
local TEXTCOLOR_VALUES = {
    class  = L["Class color"],
    stat   = L["Per-statistic color"],
    custom = L["Custom color"],
}
local TEXTCOLOR_SORT = { "class", "stat", "custom" }

local BARBG_VALUES = {
    class  = L["Class color"],
    stat   = L["Per-statistic color"],
    custom = L["Custom color"],
    none   = L["None"],
}
local BARBG_SORT = { "class", "stat", "custom", "none" }

-- TWO modes, class and custom, for the bar borders' colors (`window.bars.borderColorMode`, the
-- tooltip bars' `barBorderColorMode`). They were the header controls' and the window chrome's
-- too, until those took CHROMECOLOR's three (skin, class, custom; MM-A1). "Per-statistic" was
-- left off because an outline, like a header button, has no statistic of its own to mean.
local CONTROLCOLOR_VALUES = {
    class  = L["Class color"],
    custom = L["Custom color"],
}
local CONTROLCOLOR_SORT = { "class", "custom" }

-- The divider's three, and the extra one is the point. `skin` is not "a color
-- that happens to match the skin" -- it is *don't touch the texture*, so whatever
-- LibKa0s-Core-1.0's ApplySkin just wrote stands. That is what keeps a re-skin
-- landing on this window along with the debug console and the perf panel
-- (standalone-windows): the shared value is never copied into this repo, never
-- stored in a profile, and never has to be migrated when it changes.
--
-- NO `stat` MODE, for the reason the header's other surfaces do not have one: the
-- divider is one line across the whole window, so "per statistic" could only ever
-- paint it the sort column's color -- a fact already on screen twice over.
local DIVIDERCOLOR_VALUES = {
    -- "Skin", the word the Skin tab uses: under EllesmereUI or any of the nine skins it
    -- is the skin the window wears, not only a Ka0s one (DECISIONS D16).
    skin   = L["Skin"],
    class  = L["Class color"],
    custom = L["Custom color"],
}
local DIVIDERCOLOR_SORT = { "skin", "class", "custom" }

-- The window chrome's three (MM-A1, DECISIONS D16): the divider's values, where `skin` is the
-- skin's own color (`win.bg`, `title.text`, `icon.tint`, `btn.hover`) and, for the edge, the
-- skin's whole edge. The fill, the edge and the title here; the controls in settings/Schema.lua.
local CHROMECOLOR_VALUES, CHROMECOLOR_SORT = DIVIDERCOLOR_VALUES, DIVIDERCOLOR_SORT

-- ONE set for both slots, and EVERY VALUE IS LITERAL — modules/Row.lua renders
-- exactly what is asked for and never falls back to another figure. `none` in
-- particular means nothing at all, which it did not always: both slots set to
-- None used to still print the total, so the setting appeared to do nothing.
--
-- `smart` is the only value whose meaning depends on the column — the per-second
-- figure where the stat has one, the absolute figure everywhere else — and it is
-- what the left slot ships as. A counting stat still renders nothing for `rate`,
-- because "0.42 interrupts per second" is not a thing a meter should say; that is
-- a property of the STAT, not of the slot.
-- The two smart values are named for what they DO rather than being "smart" and
-- "smarter". Both branch on whether the column has a per-second figure at all --
-- that is what makes them smart -- and they differ in what they do with the
-- answer: one PICKS (the rate where there is one, the total otherwise) and the
-- other SHOWS BOTH, falling back to the total alone on a counting stat where
-- "0.42 interrupts per second" is not a thing a meter should say.
local SLOT_VALUES = {
    none     = L["None"],
    smart    = L["Smart value (Per Second or Absolute)"],
    combined = L["Smart value (Absolute | Per Second)"],
    total    = L["Absolute value"],
    rate     = L["Per second value"],
    percent  = L["Percent"],
}
local SLOT_SORT   = { "none", "smart", "combined", "total", "rate", "percent" }

-- HOW MANY DECIMALS, plus the un-abbreviated form. The three abbreviating entries
-- are ONE ladder at three fraction divisors (modules/Format.lua's scaledLadder);
-- `full` is the other formatter entirely.
--
-- NO THOUSANDS-SEPARATOR ENTRY, and there cannot be one. Grouping a number means
-- reading its digits, and every figure in this grid is a SECRET value for the
-- whole of a pull -- BreakUpLargeNumbers takes a plain number and raises on a
-- handle (design §4). What "Full" renders is every digit, unseparated, which is
-- what the client's own formatter can produce without inspecting anything.
local NUMFMT_VALUES  = {
    abbreviated      = L["Abbreviated (12.4M)"],
    abbreviatedWhole = L["Abbreviated, no decimals (12M)"],
    abbreviatedTwo   = L["Abbreviated, two decimals (12.40M)"],
    full             = L["Full (12400000)"],
}
local NUMFMT_SORT    = { "abbreviated", "abbreviatedWhole", "abbreviatedTwo", "full" }

-- How a death is labeled. A third value, "time into the fight", was built and
-- removed: nothing on the client can date a past death against the run it
-- happened in. See the note on modules/Format.lua's DeathTime.
local DEATHTIME_VALUES = {
    clock = L["Time of day"],
    ago   = L["How long ago"],
}
local DEATHTIME_SORT = { "clock", "ago" }

-- Every ANCHOR_* token GameTooltip:SetOwner accepts, minus ANCHOR_NONE and
-- ANCHOR_PRESERVE — both of which mean "the caller places it itself", which is
-- the one thing this addon may not do: a cell handed a secret value has secret
-- geometry, so there is no legal way to compute a point from it (rule R3).
-- Ordered cursor first, then the four edges, then the four corners.
-- NO "At cursor". It was the shipped default and it is what every other tooltip
-- in the game does, which is exactly the trouble: over a grid it lands wherever
-- the pointer happens to be inside a cell, so the same hover puts the tooltip in
-- a different place every time and reads as jitter rather than as a choice. TOP
-- is the deliberate version of the same thing -- above the cell, in one place --
-- and is the default now.
local ANCHOR_VALUES  = {
    TOP         = L["Top"],
    BOTTOM      = L["Bottom"],
    LEFT        = L["Left"],
    RIGHT       = L["Right"],
    TOPLEFT     = L["Top left"],
    TOPRIGHT    = L["Top right"],
    BOTTOMLEFT  = L["Bottom left"],
    BOTTOMRIGHT = L["Bottom right"],
}
local ANCHOR_SORT    = {
    "TOP", "BOTTOM", "LEFT", "RIGHT",
    "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
}

-- THE SORT AND SESSION LISTS ARE GONE with the rows that used them. `sortMode`,
-- `sortColumn`, `sortAscending` and `sessionType` are written by the window's own
-- controls -- a click on a column header, a pick from the header's segment
-- dropdown -- and are no longer settings-panel rows or CLI paths. The value lists
-- went with them rather than sitting here unreferenced.

-- The export destinations, derived from the channel catalog the export module
-- reads, for the same reason: one list, two consumers, and no chance of the
-- dropdown offering a channel nothing knows how to send to. The catalog stores
-- plain English in `label` and the localization happens HERE, at the use site,
-- because core/Constants.lua may load before locales/enUS.lua.
local CHANNEL_VALUES, CHANNEL_SORT = {}, {}
for i, channel in ipairs(Const.EXPORT_CHANNELS) do
    CHANNEL_VALUES[channel.key] = L[channel.label]
    CHANNEL_SORT[i] = channel.key
end

-- Published to settings/Schema_Compose.lua, and read nowhere else.
NS.SchemaVocab = {
    ALIGN_SORT          = ALIGN_SORT,
    ALIGN_VALUES        = ALIGN_VALUES,
    ANCHOR_SORT         = ANCHOR_SORT,
    ANCHOR_VALUES       = ANCHOR_VALUES,
    BARBG_SORT          = BARBG_SORT,
    BARBG_VALUES        = BARBG_VALUES,
    BARCOLOR_SORT       = BARCOLOR_SORT,
    BARCOLOR_VALUES     = BARCOLOR_VALUES,
    CHANNEL_SORT        = CHANNEL_SORT,
    CHANNEL_VALUES      = CHANNEL_VALUES,
    CHROMECOLOR_SORT    = CHROMECOLOR_SORT,
    CHROMECOLOR_VALUES  = CHROMECOLOR_VALUES,
    CONTROLCOLOR_SORT   = CONTROLCOLOR_SORT,
    CONTROLCOLOR_VALUES = CONTROLCOLOR_VALUES,
    DEATHTIME_SORT      = DEATHTIME_SORT,
    DEATHTIME_VALUES    = DEATHTIME_VALUES,
    DIVIDERCOLOR_SORT   = DIVIDERCOLOR_SORT,
    DIVIDERCOLOR_VALUES = DIVIDERCOLOR_VALUES,
    GROWTH_SORT         = GROWTH_SORT,
    GROWTH_VALUES       = GROWTH_VALUES,
    NUMFMT_SORT         = NUMFMT_SORT,
    NUMFMT_VALUES       = NUMFMT_VALUES,
    OUTLINE_SORT        = OUTLINE_SORT,
    OUTLINE_VALUES      = OUTLINE_VALUES,
    SIDE_SORT           = SIDE_SORT,
    SIDE_VALUES         = SIDE_VALUES,
    SLOT_SORT           = SLOT_SORT,
    SLOT_VALUES         = SLOT_VALUES,
    STRATA_SORT         = STRATA_SORT,
    STRATA_VALUES       = STRATA_VALUES,
    TEXTCOLOR_SORT      = TEXTCOLOR_SORT,
    TEXTCOLOR_VALUES    = TEXTCOLOR_VALUES,
}
