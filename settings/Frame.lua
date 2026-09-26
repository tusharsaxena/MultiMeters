-- settings/Frame.lua
--
-- The Windows page's Frame entry: the window's own geometry, chrome and lock state.
--
-- Every widget on this page is a row in NS.Schema with a `window.frame.*` path,
-- so the page body is one RenderSchema call. Adding a frame option means adding
-- one row in settings/Schema.lua and nothing here.
--
-- NO BESPOKE CONTROLS. "Reset position" used to sit at the bottom of this page
-- and now sits on General beside "Reset all settings", where the player looks
-- for a reset. It still acts on the ACTIVE window — position is per-window and
-- there is nothing addon-wide about it — so settings/General.lua says which
-- window it means rather than leaving the page's scope to imply the wrong one.
--
-- The Header controls group left this page too, for the Header page. Both moves
-- are page placement only: `window.frame.*` is still where every one of those
-- settings is STORED.

local _, NS = ...

local L = NS.L

-- The Frame entry of the Windows page (MultiMeters#55). Its rows are drawn by the page's
-- renderer (settings/OptionsSetup.lua, Helpers.RenderWindowPage) through
-- H.RenderTabbedSchema(ctx, "frame"): the entry's tabs are the rows' groups.
NS.RegisterWindowSection("frame", L["Frame"], {
    tooltip = L["This window's size, position, background, border and rows."],
})
