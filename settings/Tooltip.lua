-- settings/Tooltip.lua
--
-- The Windows page's Tooltip entry: the per-cell spell breakdown, the all-statistics summary on
-- a player's name, and where the tooltip anchors.
--
-- Pure schema — every widget is a `window.tooltip.*` row in NS.Schema.
--
-- WHY "HIDE IN COMBAT" DEFAULTS TO OFF, WHICH READS BACKWARDS. The tooltip is
-- an ordinary unprotected frame and its numbers go through the same native
-- formatter every cell does, so there is nothing about a pull that makes it
-- unsafe to show — the secret-value rules constrain what the addon may COMPUTE,
-- not what it may draw (design §4). The only argument for hiding it is that a
-- tooltip parked under the cursor is in the way, and that is a preference, not
-- a correctness matter. So it is a setting that defaults to the honest answer
-- rather than to the cautious-looking one.
--
-- `maxSpells` is a real cost control rather than a taste one: the breakdown is
-- a second API call (`GetCombatSessionSourceFromType` for one source) and the
-- spell list it returns is unbounded, so the cap is what keeps a hover over a
-- twenty-minute Overall session from building a hundred lines.

local _, NS = ...

local L = NS.L

-- The Tooltip entry of the Windows page (MultiMeters#55). Its rows are drawn by the page's
-- renderer (settings/OptionsSetup.lua, Helpers.RenderWindowPage) through
-- H.RenderTabbedSchema(ctx, "tooltip"): the entry's tabs are the rows' groups.
NS.RegisterWindowSection("tooltip", L["Tooltip"], {
    tooltip = L["What this window's tooltip shows, and how it looks."],
})
