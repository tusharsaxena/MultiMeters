-- settings/Bars.lua
--
-- The Windows page's Bars entry — EVERYTHING ONE CELL DRAWS, in three tabs: Bar (the
-- StatusBar's Fill -- texture, color, opacity, fill direction -- then the tint behind it
-- and its border, one subsection each), Text (what the two text slots say, then how
-- they are written) and Icons (the name column's icon).
--
-- THE TEXT AND ICONS PAGES FOLDED IN HERE. They were their own tree entries and their
-- own canvases, which meant styling one cell — the bar behind the number, the number,
-- and the icon beside the name — was three pages and two clicks between each change you
-- wanted to compare. The ROWS left again, for Windows > Frame > Rows: how tall a row
-- is, how many there are and which way they grow shape the grid every bar is drawn in,
-- not the bar itself. Death timestamps left too, for Windows > Tooltip > Contents >
-- Deaths: no cell reads it (item 020).
--
-- Pure schema — every widget is a `window.bars.*`, `window.text.*` or
-- `window.icons.*` row in NS.Schema. The PATHS did not move with the page and
-- must not: a row's page is where it is edited, its path is where it is stored,
-- and renaming `text.size` to `bars.textSize` for tidiness would migrate every
-- saved profile in the collection for nothing anybody can see.
--
-- THE CONSTRAINT BEHIND THE COLOR MODES. A bar's LENGTH comes from
-- `SetMinMaxValues(0, maxAmount)` + `SetValue(totalAmount)`, and under
-- Blizzard's combat restriction both of those are secret values — legal to hand
-- to a widget setter, illegal to compare, divide or test (design §4). So the
-- addon can never ask "is this bar more than half full" to decide anything, and
-- a color mode that depended on the value would be unimplementable mid-pull,
-- which is exactly when a meter is read.
--
-- The three shipped modes are therefore all value-independent:
--
--   class   the source's `classFilename`, which the API marks NeverSecret
--   stat    one color per column, decided by the column, not by its contents
--   custom  one color everywhere
--
-- A "color by rank" or "color above threshold" mode is not a missing feature
-- here; it is a thing this data source cannot express while a pull is running.

local _, NS = ...

local L = NS.L

-- The Bars entry of the Windows page (MultiMeters#55). Its rows are drawn by the page's
-- renderer (settings/OptionsSetup.lua, Helpers.RenderWindowPage) through
-- H.RenderTabbedSchema(ctx, "bars"): the entry's tabs are the rows' groups.
NS.RegisterWindowSection("bars", L["Bars"], {
    tooltip = L["How this window's bars, their text and their icons look."],
})
