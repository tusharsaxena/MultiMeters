-- settings/Header.lua
--
-- The Windows page's Header entry: the strip above the rows — its title, what it reports about
-- the session, and how it is drawn.
--
-- Pure schema. Every widget is a `window.header.*` row in NS.Schema, so this
-- file is the entry's registration and nothing else; adding a header
-- option is one row in settings/Schema.lua.
--
-- Worth knowing while reading the rows this page renders: the accent the SKIN
-- owns -- `frame.title` -- is configurable here, and the rule it was once
-- withheld under is intact rather than waived.
--
-- The rule (standalone-windows) is "never RESTATE Core.SKIN's values", because a
-- copy drifts a hex digit at a time and then has to be migrated. It is not "never
-- let a player choose". So ApplySkin runs first and owns the accent, and a
-- setting that claims to govern it writes AFTER the library rather than instead
-- of it.
--
-- There is no divider: no Ka0s window draws a line under its title (R4-SEP, the
-- owner's 2026-11-03 sign-off), so its four rows are gone.

local _, NS = ...

local L = NS.L

-- The Header entry of the Windows page (MultiMeters#55). Its rows are drawn by the page's
-- renderer (settings/OptionsSetup.lua, Helpers.RenderWindowPage) through
-- H.RenderTabbedSchema(ctx, "header"): the entry's tabs are the rows' groups.
NS.RegisterWindowSection("header", L["Header"], {
    tooltip = L["This window's title bar, its text and its buttons."],
})
