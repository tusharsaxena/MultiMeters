-- settings/Header.lua
--
-- The Windows page's Header entry: the strip above the rows — its title, what it reports about
-- the session, and how it is drawn.
--
-- Pure schema. Every widget is a `window.header.*` row in NS.Schema, so this
-- file is the entry's registration and nothing else; adding a header
-- option is one row in settings/Schema.lua.
--
-- Worth knowing while reading the rows this page renders: the two accents the
-- SKIN owns -- `frame.title` and `frame.divider` -- are both configurable here
-- now, and the rule they were once withheld under is intact rather than waived.
--
-- The rule (standalone-windows) is "never RESTATE Core.SKIN's values", because a
-- copy drifts a hex digit at a time and then has to be migrated. It is not "never
-- let a player choose". So both accents are reached the same way: ApplySkin runs
-- first and owns the accent, and a setting that claims to govern it writes AFTER
-- the library rather than instead of it.
--
-- The divider goes one better, because it is the only one with a *default* that
-- has to mean "whatever the collection says". Its `skin` mode -- the shipped one
-- -- resolves nothing and writes nothing, leaving ApplySkin's tint standing. So
-- the shared value is never copied into this repo and never into a profile, and a
-- re-skin still lands on this window along with the debug console and the perf
-- panel. See modules/Window.lua's ApplyHeaderStrip.

local _, NS = ...

local L = NS.L

-- The Header entry of the Windows page (MultiMeters#55). Its rows are drawn by the page's
-- renderer (settings/OptionsSetup.lua, Helpers.RenderWindowPage) through
-- H.RenderTabbedSchema(ctx, "header"): the entry's tabs are the rows' groups.
NS.RegisterWindowSection("header", L["Header"], {
    tooltip = L["This window's title bar, its text and its buttons."],
})
