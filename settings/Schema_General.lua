-- settings/Schema_General.lua
--
-- THE TAIL OF THE ONE ROW ARRAY: the Visibility, Columns and General pages' rows, the generated
-- statistic palette, and the two passes that run over the finished array. Peeled off
-- settings/Schema.lua for layout-§1, at the page boundary that peel left available, because that
-- file sat 27 lines under the cap. A pure move: every row, every comment and the order are as they
-- were, so `/mm list`, the panel and the path index see the same array.
--
-- TOC POSITION: LOAD-BEARING. After settings/Schema.lua, whose NS.Schema these rows are appended
-- to, and before settings/Schema_Skin.lua, whose rows come last and are not swatches the second
-- pass below should read.

local _, NS = ...

local L     = NS.L
local Const = NS.Constants

local SC = NS.SchemaCompose
local CHANNEL_SORT      = SC.CHANNEL_SORT
local CHANNEL_VALUES    = SC.CHANNEL_VALUES
local COLHEAD_BG_ROWS   = SC.COLHEAD_BG_ROWS
local COLHEAD_TEXT_ROWS = SC.COLHEAD_TEXT_ROWS
local MASTER_ROWS       = SC.MASTER_ROWS
local block             = SC.block
local expandBlocks      = SC.expandBlocks
local isNumberIn        = SC.isNumberIn
local refreshVisibility = SC.refreshVisibility

-- What every color swatch's tooltip says about the mode beside it. IN WORDS,
-- because the swatch is NEVER disabled (options-ui-§17, anti-patterns #74): it is
-- still read for its ALPHA under every mode -- no class color and no palette
-- entry carries one -- so graying it out would tell the player something untrue,
-- and setting a color before switching the mode to Custom is the normal order of
-- operations rather than a mistake to defend against.
--
-- Appended to every non-palette color row's `desc` in ONE pass below, rather than
-- written into fifteen sentences: a rule restated fifteen times is a rule fourteen
-- of them can drift from.
local SWATCH_NOTE = L["Not read while the color mode beside it is anything but Custom color, except for its opacity, which always applies."]

-- What every color MODE that offers Per-statistic says about where that palette
-- lives (item 020, MUL-L21): on another page, so a player choosing the mode is
-- told where the colors it reads are edited. Appended in the same pass as
-- SWATCH_NOTE, and for the same reason: one sentence stated once.
local STAT_NOTE = L["Per-statistic colors are set on the General page > Statistic colors."]

local ROWS = {
    -- ── Visibility ─────────────────────────────────────────────────
    -- Refused AT THE SOURCE (performance section 6): a hidden window does not
    -- merely skip its draw, it stops asking the provider for data. That is why
    -- every row here carries an onChange -- the effect is a window appearing or
    -- disappearing, which is the show ladder's decision and not a redraw.
    --
    -- ONE TAB, "Rules", with three subsections (item 020, MUL-L15): Show in, Hide
    -- when, Combat. "Why is my window hidden?" needs every one of these, and it
    -- was three tabs; the order inside each block is kept.
    {
        path = "window.visibility.dungeon", type = "bool", default = true,
        page = "visibility", group = L["Rules"], subgroup = L["Show in"],
        label = L["Dungeons"], desc = L["Show this window in five-player dungeons, including Mythic+."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.raid", type = "bool", default = true,
        page = "visibility", group = L["Rules"], subgroup = L["Show in"],
        label = L["Raids"], desc = L["Show this window in raid instances."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.arena", type = "bool", default = true,
        page = "visibility", group = L["Rules"], subgroup = L["Show in"],
        label = L["Arenas"], desc = L["Show this window in arena matches."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.battleground", type = "bool", default = true,
        page = "visibility", group = L["Rules"], subgroup = L["Show in"],
        label = L["Battlegrounds"], desc = L["Show this window in battlegrounds."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.delve", type = "bool", default = true,
        page = "visibility", group = L["Rules"], subgroup = L["Show in"],
        label = L["Delves"], desc = L["Show this window inside delves."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.scenario", type = "bool", default = true,
        page = "visibility", group = L["Rules"], subgroup = L["Show in"],
        label = L["Scenarios"],
        desc = L["Show this window in scenarios and follower dungeons. Delves have their own setting."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.world", type = "bool", default = true,
        page = "visibility", group = L["Rules"], subgroup = L["Show in"],
        label = L["Open world"], desc = L["Show this window outside instances."],
        onChange = refreshVisibility,
    },
    -- Every rule below is HIDE-shaped, and deliberately so: a key missing from a
    -- stored window must read as "nothing objects". See modules/Visibility.lua.
    {
        path = "window.visibility.hideWhenSolo", type = "bool", default = false,
        page = "visibility", group = L["Rules"], subgroup = L["Hide when"],
        label = L["Hide when solo"], desc = L["Hide the window whenever you are not in a party or raid."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideInVehicle", type = "bool", default = false,
        page = "visibility", group = L["Rules"], subgroup = L["Hide when"],
        label = L["Hide in vehicles"], desc = L["Hide the window while you are controlling a vehicle."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideWhenMounted", type = "bool", default = false,
        page = "visibility", group = L["Rules"], subgroup = L["Hide when"],
        label = L["Hide when mounted"],
        desc = L["Hide the window while you are mounted, including a druid's travel forms."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideWhenSkyriding", type = "bool", default = false,
        page = "visibility", group = L["Rules"], subgroup = L["Hide when"],
        label = L["Hide when skyriding"],
        desc = L["Hide the window while you are on a skyriding mount, from the moment it can glide rather than once you are airborne."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideOnTaxi", type = "bool", default = false,
        page = "visibility", group = L["Rules"], subgroup = L["Hide when"],
        label = L["Hide on flight paths"], desc = L["Hide the window while you are riding a flight path."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideInHousing", type = "bool", default = false,
        page = "visibility", group = L["Rules"], subgroup = L["Hide when"],
        label = L["Hide in player housing"],
        desc = L["Hide the window while you are inside your house or on your plot."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideInPetBattle", type = "bool", default = false,
        page = "visibility", group = L["Rules"], subgroup = L["Hide when"],
        label = L["Hide in pet battles"], desc = L["Hide the window while a pet battle is on screen."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideWhenDead", type = "bool", default = false,
        page = "visibility", group = L["Rules"], subgroup = L["Hide when"],
        label = L["Hide while dead"],
        desc = L["Hide the window while you are dead or a ghost. Off by default: reading the meter while dead is most of what it is for."],
        onChange = refreshVisibility,
    },
    -- Two independent rules rather than one tri-state control. Ticking both is a
    -- window that never shows, which is the player's business; `/mm diagnostics` still
    -- names the side of the pull that decided.
    {
        path = "window.visibility.hideInCombat", type = "bool", default = false,
        page = "visibility", group = L["Rules"], subgroup = L["Combat"],
        label = L["Hide in combat"], desc = L["Hide the window while you are fighting."],
        onChange = refreshVisibility,
    },
    {
        path = "window.visibility.hideOutOfCombat", type = "bool", default = false,
        page = "visibility", group = L["Rules"], subgroup = L["Combat"],
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
    -- It used to borrow the font and size from `text` and the outline and color
    -- from `header`, which meant changing the cell font silently restyled it too;
    -- every default here is the value that arrangement already produced. The
    -- PATHS stay `window.columnHeader.*` -- a row's page is where it is edited,
    -- its path is where it is stored. One tab, "Column header", with Text and
    -- Background subsections (item 020, MUL-L16); settings/Columns.lua draws it.
    block(COLHEAD_TEXT_ROWS),
    block(COLHEAD_BG_ROWS),

    -- ── General ──────────────────────────────────────────────
    -- The only genuinely addon-wide settings. Everything else is per-window.
    --
    -- ONE VISIBLE TAB of settings, plus the palette. **Master controls** is
    -- options-ui-§15's canonical set and is FIRST on this page in every Ka0s addon
    -- -- enable, general visibility, the two master multipliers, the addon-wide
    -- lock, the debug console and Test mode -- and this addon's own three follow
    -- it: the minimap button and the two addon-wide data settings. The two resets
    -- close the tab as a button pair.
    --
    -- **THE `General` TAB IS GONE**, and three of its four rows are that tail; the
    -- fourth, Test mode, became a canonical row (standard v2.47.0). It was four
    -- rows with nothing in common but "addon-wide", sitting behind a click next to
    -- the tab everybody opens -- the same argument that retired Maintenance and
    -- Data before it, arriving one tab later. §15 forbids REORDERING, RENAMING or
    -- SPLITTING the canonical set; it does not forbid an addon's own rows after
    -- it, and the seven stay contiguous and first, which is what
    -- tests/test_schema.lua pins. Nothing moved in storage: a `group` is not a
    -- stored path.
    --
    -- `enabled`, `state.debugConsole` AND `state.testMode` MOVED INTO THE COMPOSED
    -- BLOCK and are declared nowhere else -- two controls over one setting is the
    -- thing this whole pass exists to remove. Their paths are unchanged, because a
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
    -- ── Behavior ─────────────────────────────────────────
    --
    -- THEIR OWN TAB, not Master controls. options-ui-§15 makes that tab a canonical
    -- set -- the addon-wide switch, visibility, scale, alpha, the lock, the console
    -- and Test mode -- and these two are neither canonical nor about turning the
    -- addon up and down: one says what a pet's damage IS and the other is a refresh
    -- rate. They sat there because there was nowhere else on the page to put them.
    --
    -- `data.mergePets` and `data.throttle` were `window.data.*` and are not
    -- per-window questions: two windows disagreeing about either is two answers to
    -- one question. core/Database_Migrations.lua's v4 -> v5 step lifts a stored pair off the
    -- first window in each profile. There is no Data PAGE any more -- the sort
    -- and session rows that used to share it with these two were deleted rather
    -- than moved, because the window's own controls already write them directly
    -- (modules/Window_Header.lua's SortByColumn and the header's segment picker), and a
    -- settings page restating a control the player already has, three inches
    -- from where they are looking, was a second place for the same answer to
    -- live.
    {
        path = "data.mergePets", type = "bool", default = false,
        page = "general", group = L["Behavior"],
        label = L["Merge pets into their owner"],
        desc = L["Add a pet's numbers to its owner's row instead of giving it its own. Blizzard's combat restriction forbids the addition while you are fighting, so a merged pet's numbers are missing until the pull ends."],
    },
    {
        path = "data.throttle", type = "number", default = 0.25,
        min = Const.THROTTLE_MIN, max = Const.THROTTLE_MAX, step = 0.05, fmt = "%.2fs",
        page = "general", group = L["Behavior"],
        label = L["Refresh interval"],
        desc = L["Seconds between refreshes. Lower is more responsive and costs more; the display updates at most this often no matter how fast the game reports numbers."],
        validate = isNumberIn(Const.THROTTLE_MIN, Const.THROTTLE_MAX),
    },

    -- ── Export ──────────────────────────────────────────────
    --
    -- Addon-wide rather than per-window, and last on the page so the tabs above
    -- stay contiguous. ALL FOUR ARE `hidden`. They are the choices the EXPORT
    -- MODAL remembers -- its own three controls are the ones a player uses,
    -- sitting in the dialog they are exporting from -- so a second copy on the
    -- General page restated a control the player only ever meets in the other
    -- place, and gave the two a chance to disagree about what is selected.
    --
    -- HIDDEN RATHER THAN DELETED, unlike the sort and session rows that went with
    -- the old Data page, and the difference is which seam does the writing.
    -- Those were written directly by the window's own controls; these are
    -- written by the modal through NS.SetByPath -- which REFUSES a path with no
    -- row. Deleting one would leave the modal's writes nowhere to go: the seam
    -- refuses the path, and nothing stores a choice around it.
    --
    -- THE METRIC IS AMONG THEM AGAIN (architecture-§5). It was dropped with the
    -- panel's "Default metric" control, because Export.Open seeds it from the
    -- window the modal opens on and a panel value would be overwritten before it
    -- was read. But the modal's own Metric dropdown still CHOOSES it between
    -- opens, and a control that chooses a value makes it a preference: with no
    -- row, every pick and every seed was refused here and stored around the seam.
    -- Hidden, like the other three, so no panel copy comes back.
    {
        path = "export.metric", type = "string", default = Const.STATS[1].key, hidden = true,
        page = "general", group = L["Export"],
        validate = function(v) return type(v) == "string" and Const.STAT_BY_KEY[v] ~= nil end,
        label = L["Metric"],
        desc = L["Which statistic Print to Chat ranks by. Opening the export from a window picks that window's sort column."],
    },
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

for _, row in ipairs(ROWS) do
    NS.Schema[#NS.Schema + 1] = row
end

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

-- TWO: every color swatch is told, in words, what the mode beside it does to it.
-- options-ui-§17 forbids `disabledIf` on a color row -- the swatch is still read
-- for its ALPHA under every mode, so graying it out would be a lie -- and this is
-- the sentence that replaces the graying.
--
-- THE PALETTE IS EXEMPT and is the only exemption the rule has: `statColors.*` is
-- one color per STATISTIC, identifying a column rather than a player, so there is
-- no class for it to take and no mode beside it to warn about.
--
-- And every color MODE whose value set offers Per-statistic is told where that
-- palette is edited.
for _, row in ipairs(NS.Schema) do
    if row.type == "color" and row.path:sub(1, 11) ~= "statColors." then
        row.desc = (row.desc or "") .. " " .. SWATCH_NOTE
    elseif type(row.values) == "table" and row.values.stat ~= nil then
        row.desc = (row.desc or "") .. " " .. STAT_NOTE
    end
end
