-- settings/Schema_Skin.lua
--
-- THE SKIN ROWS (skinning-§2, §3): which skin this addon wears, its Scope's two exceptions, its
-- font and texture overrides, and the first-run picker's memory. Seven schema rows appended to
-- the one array, on the General page, in the Skin tab's group.
--
-- A FILE OF ITS OWN because settings/Schema.lua sits within sixty lines of layout-§1's 1500-line
-- cap, and these rows name nothing that file's vocabularies or composers hold: their values come
-- from core/SkinSetup.lua.
--
-- SKIP-RENDER, EVERY ONE. The tab is the library's O.AppearanceTab (settings/General.lua), which
-- draws the source and the skin as its choice grids, the Scope as check boxes and the overrides
-- as LibSharedMedia dropdowns, so the flow engine draws none of them. They stay schema rows so the
-- defaults resolve, every reset reaches them (the page's Defaults and Reset all settings put the
-- skin back on Ka0s Default, skinning-§3), and `/mm get|set skin.skin` validates against `values`.
-- Their group is NS.SKIN_TAB, the key the library's tab answers, so that tab takes the group's
-- place in the strip: after Statistic colors, before the library's Keybindings, which stays last
-- (options-ui-§20).
--
-- Each onChange applies ONLY its own half (core/SkinSetup.lua says why): the tab and another
-- addon's "Copy to every Ka0s addon" call Skin:SetChoice before they write, so the write is a
-- no-op, and a bare `/mm set` still repaints.
--
-- TOC POSITION: LOAD-BEARING. After settings/Schema.lua, whose NS.Schema array these rows are
-- appended to, and before settings/Schema_Paths.lua, which indexes the finished array at file
-- scope; core/SkinSetup.lua (the value tables, read here at file load) is far above.

local _, NS = ...

local L = NS.L
local PD = NS.defaults.profile.skin

local TAB = NS.SKIN_TAB

local ROWS = {
    {
        path = "skin.source", type = "string", default = PD.source, skipRender = true,
        values = NS.SKIN_SOURCE_VALUES, sorting = NS.SKIN_SOURCE_SORT,
        page = "general", group = TAB,
        label = L["Skin source"],
        desc = L["Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."],
        onChange = function(v) if NS.ApplySkinChoice then NS.ApplySkinChoice(v, nil) end end,
    },
    {
        path = "skin.skin", type = "string", default = PD.skin, skipRender = true,
        values = NS.SKIN_VALUES, sorting = NS.SKIN_SORT,
        page = "general", group = TAB,
        label = L["Skin"],
        desc = L["The Ka0s skin this addon wears. Changes every window and panel right away."],
        onChange = function(v) if NS.ApplySkinChoice then NS.ApplySkinChoice(nil, v) end end,
    },
    -- The Scope's two exceptions (LibKa0s-Skin-1.0 minor 5), drawn by the same tab as check boxes.
    {
        path = "skin.ignorePanel", type = "bool", default = PD.ignorePanel, skipRender = true,
        page = "general", group = TAB,
        label = L["Ignore settings panel"],
        desc = L["Keep this addon's settings panel in the game's own look. Its windows still wear the skin."],
        onChange = function(v) if NS.ApplySkinIgnore then NS.ApplySkinIgnore(v, nil) end end,
    },
    {
        path = "skin.ignoreFonts", type = "bool", default = PD.ignoreFonts, skipRender = true,
        page = "general", group = TAB,
        label = L["Ignore fonts"],
        desc = L["Keep every font in this addon as the game draws it. The skin still colors the text."],
        onChange = function(v) if NS.ApplySkinIgnore then NS.ApplySkinIgnore(nil, v) end end,
    },
    -- The Font and texture section's two overrides (LibKa0s-Skin-1.0 minor 6), drawn by the same
    -- tab as dropdowns of LibSharedMedia keys; "" is the skin's own. Free text rather than a
    -- dropdown with `values`: a media pack may register its keys after this file loads, and
    -- `/mm set` takes any key.
    {
        path = "skin.font", type = "string", default = PD.font, skipRender = true,
        dialogControl = "EditBox",
        page = "general", group = TAB,
        label = L["Font"],
        desc = L["The font this addon's text uses, over the skin's own. Empty keeps the skin's."],
        onChange = function(v) if NS.ApplySkinOverride then NS.ApplySkinOverride(v, nil) end end,
    },
    {
        path = "skin.texture", type = "string", default = PD.texture, skipRender = true,
        dialogControl = "EditBox",
        page = "general", group = TAB,
        label = L["Texture"],
        desc = L["The texture this addon's bars use, over the skin's own. Empty keeps the skin's."],
        onChange = function(v) if NS.ApplySkinOverride then NS.ApplySkinOverride(nil, v) end end,
    },
    -- The first-run skin picker's memory: set when the picker closes, so it shows once per profile.
    -- Drawn by nothing; a reset puts it back to false (owner ruling O3).
    {
        path = "skin.pickerSeen", type = "bool", default = PD.pickerSeen, skipRender = true,
        page = "general", group = TAB,
        label = L["Skin picker seen"],
        desc = L["Whether the first-run skin picker was closed on this profile."],
    },
}

for _, row in ipairs(ROWS) do NS.Schema[#NS.Schema + 1] = row end
