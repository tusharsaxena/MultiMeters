-- settings/Schema_Compose.lua
--
-- WHAT settings/Schema.lua's ARRAY IS DECLARED OUT OF, and nothing else: the
-- refresh routing a row's `onChange` reaches for, the dropdown vocabularies its
-- `values` point at, the common validators, and the LibKa0s-Options-1.0
-- composers together with every canonical block composed out of them.
--
-- A SEPARATE FILE because settings/Schema.lua was 3080 lines against layout-§1's
-- 1500-line cap (issue #27). The seam that issue names is the schema array out of
-- the machinery, and the arithmetic needs three files rather than two: the path
-- machinery and the seams went to settings/Schema_Paths.lua, the array stayed in
-- settings/Schema.lua, and this is what the array is built from. It holds no row
-- of its own -- every row it produces is composed, and the composers decide which
-- rows there are while settings/Schema.lua decides where they sit.
--
-- EVERYTHING BELOW WAS A FILE-LOCAL when this was one file, and the array reads
-- all of it at FILE SCOPE. It is therefore published, once, as NS.SchemaCompose
-- at the foot of this file -- the one thing this peel changed that is not a pure
-- move. See the note there.
--
-- TOC POSITION: FIRST of the three Schema files, and LOAD-BEARING: every member
-- of NS.SchemaCompose is resolved at FILE SCOPE by settings/Schema.lua as it
-- declares the array, so this must load before it.
--
-- Nothing here is captured across the load boundary: NS.Helpers, NS.db,
-- NS.WindowManager and NS.Visibility are all resolved at CALL time, because this
-- file loads before all four.

local addonName, NS = ...

local L     = NS.L
local Const = NS.Constants

-- ---------------------------------------------------------------------------
-- Refresh routing
-- ---------------------------------------------------------------------------
--
-- The DEFAULT refresh for every row is the CONFIG_CHANGED message that SetByPath
-- sends, and there is exactly ONE sender of it (architecture-§4) --
-- settings/Schema_Paths.lua, which took SetByPath when this file was peeled off
-- settings/Schema.lua for layout-§1. The sentence used to say "this file", and it
-- was true of the file all three were carved out of. Windows subscribe and
-- re-read their upvalues; the panel re-reads its scalars. A direct call from here
-- into modules/ would be the cross-module reach the standard forbids, and it would
-- also be a second refresh path for anything that already subscribes.
--
-- `onChange` therefore exists only for the handful of settings whose effect the
-- message genuinely cannot express — a decision that is not "this window's config
-- moved" but "the show/hide ladder has to be re-run", or "a Blizzard-side object
-- outside our config tree has to be told". Each resolves its target through NS at
-- CALL time, because every one of them loads after this file.

--- Re-run the visibility ladder for every window. Used by the master enable and by
--- the per-context rules, whose effect is a window appearing or disappearing
--- rather than a window redrawing.
local function refreshVisibility()
    local V = NS.Visibility or (NS.GetModule and NS:GetModule("Visibility", true))
    if V and V.Refresh then V:Refresh() end
end

-- Every colour-mode dropdown in one window, in the order a player meets them.
-- The META ROW on the Frame page writes this whole list; each of them is also
-- still its own row, and setting one individually afterwards is expected rather
-- than an override to defend against.
--
-- WRITTEN THROUGH NS.SetByPath, ONE AT A TIME, and not by poking the config
-- table: each target then gets its own validation, its own debug line and its own
-- CONFIG_CHANGED, which is what makes a broadcast indistinguishable from the
-- player having set all nine by hand. A fan-out that wrote the tree directly
-- would be a second write seam, and the windows would not repaint.
-- THE THREE OTHER THINGS EVERY SURFACE STATES SEPARATELY, and the meta rows that
-- set each of them everywhere at once. Same bargain as the colour mode below: the
-- individual rows all still exist, the meta stores what it last broadcast, and
-- nothing reads it back.
--
-- The tooltip's keys carry a `font` prefix of their own (`fontOutline`, not
-- `outline`), which is why these are lists of PATHS rather than a group list and
-- a suffix assumed to be shared.
local BAR_TEXTURE_PATHS = {
    "window.bars.texture",
    "window.tooltip.barTexture",
}

local FONT_PATHS = {
    "window.text.font",
    "window.header.font",
    "window.columnHeader.font",
    "window.tooltip.font",
}

local OUTLINE_PATHS = {
    "window.text.outline",
    "window.header.outline",
    "window.columnHeader.outline",
    "window.tooltip.fontOutline",
}

-- TWO TEXT SURFACES ARE DELIBERATELY ABSENT: `window.text.colorMode`, the
-- numbers in the grid, and `window.tooltip.colorMode`, the tooltip's own text.
--
-- Both of them are drawn ON TOP OF a surface this list DOES broadcast to. Sending
-- "per statistic" to the whole window therefore painted the Damage number in the
-- Damage colour over a Damage-coloured bar, and the tooltip's text in the sorted
-- stat's colour over bars carrying that same colour -- the one place where making
-- every surface agree makes the text stop being readable at all.
--
-- Foreground text is the surface whose colour has to CONTRAST with the broadcast,
-- not match it, so it stays an explicit choice. Both remain their own rows on
-- their own pages, so a player who wants the match can still ask for it; what
-- they no longer get is it happening to them from a control labelled "all
-- surfaces".
local COLOR_MODE_PATHS = {
    "window.bars.colorMode",
    "window.bars.bgColorMode",
    "window.columnHeader.colorMode",
    "window.columnHeader.bgColorMode",
    "window.tooltip.barColorMode",
    "window.tooltip.barBgColorMode",
}

--- Broadcast one colour mode to every surface of the window.
---
--- THE META ROW IS A SHORTCUT, NOT A SOURCE OF TRUTH. It stores what was last
--- broadcast and nothing reads it back: every surface keeps its own mode, and a
--- player who then changes one individually has changed one, not "overridden" the
--- meta. The alternative -- deriving the meta from the nine and showing "mixed"
--- when they disagree -- makes a control that cannot be set to the thing it is
--- showing, which is worse than a shortcut that goes stale.
---
--- The meta's own path is deliberately absent from the list above, so this cannot
--- re-enter.
---
--- NOT DURING A RESET. "Restore this page's defaults" on the Frame page walks
--- every row of that page through NS.ApplyDefault, and a meta row that broadcast
--- from there would make the Frame page's Defaults button silently reset ten
--- settings on three other pages -- a button reaching past its own page, which is
--- the one thing a per-page reset must not do. The flag is set for exactly the
--- length of that call and is the narrowest way to say "this write is a restore,
--- not a click".
---
--- @param paths table   the surfaces to write
--- @param value any      the value to write to each
local function broadcast(paths, value)
    if NS.__restoring then return end
    if value == nil or value == "" then return end
    for _, path in ipairs(paths) do
        NS.SetByPath(path, value)
    end
end

--- @param value string  "class" | "stat" | "custom"
local function broadcastColorMode(value) broadcast(COLOR_MODE_PATHS, value) end

--- @param value string  an LSM statusbar key
local function broadcastBarTexture(value) broadcast(BAR_TEXTURE_PATHS, value) end

--- @param value string  an LSM font key
local function broadcastFont(value) broadcast(FONT_PATHS, value) end

--- @param value string  NONE | OUTLINE | THICKOUTLINE | MONOCHROME
local function broadcastOutline(value) broadcast(OUTLINE_PATHS, value) end

--- Show or hide the minimap button. LibDBIcon holds the button and reads the same
--- `minimap` table this row writes, so it has to be told to look again. Guarded on
--- its registry rather than pcall'd: an unregistered button is the normal state of
--- an install whose broker never came up, not an error.
local function refreshMinimap()
    local icon = LibStub and LibStub("LibDBIcon-1.0", true)
    if not (icon and icon.objects and icon.objects[addonName]) then return end
    local db = NS.db
    if icon.Refresh and db and db.profile then
        icon:Refresh(addonName, db.profile.minimap)
    end
end

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

local OUTLINE_VALUES = {
    NONE         = L["None"],
    OUTLINE      = L["Outline"],
    THICKOUTLINE = L["Thick outline"],
    MONOCHROME   = L["Monochrome"],
}
local OUTLINE_SORT   = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME" }

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
-- The colour MODE every text surface offers, and the one the two header
-- backgrounds offer too. Three entries rather than the bar background's four:
-- `none` is a legal answer for a tint drawn behind something and never for the
-- writing itself, and a text surface set to "no colour" is one nobody can read.
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

-- TWO modes, not the three every text surface offers. "Per-statistic" cannot say anything true
-- about a header BUTTON: a close box does not belong to a statistic, so the option could only
-- ever paint it the sort column's colour -- which is a fact already on screen in that column's
-- own header and in its arrow.
local CONTROLCOLOR_VALUES = {
    class  = L["Class color"],
    custom = L["Custom color"],
}
local CONTROLCOLOR_SORT = { "class", "custom" }

-- The divider's three, and the extra one is the point. `skin` is not "a colour
-- that happens to match the skin" -- it is *don't touch the texture*, so whatever
-- LibKa0s-Core-1.0's ApplySkin just wrote stands. That is what keeps a re-skin
-- landing on this window along with the debug console and the perf panel
-- (standalone-windows): the shared value is never copied into this repo, never
-- stored in a profile, and never has to be migrated when it changes.
--
-- NO `stat` MODE, for the reason the header's other surfaces do not have one: the
-- divider is one line across the whole window, so "per statistic" could only ever
-- paint it the sort column's colour -- a fact already on screen twice over.
local DIVIDERCOLOR_VALUES = {
    skin   = L["Ka0s skin"],
    class  = L["Class color"],
    custom = L["Custom color"],
}
local DIVIDERCOLOR_SORT = { "skin", "class", "custom" }

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

-- How a death is labelled. A third value, "time into the fight", was built and
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

--- One header-control label with that control's own icon in front of it.
---
--- THE STRIP IS THE INDEX INTO THIS TAB. Eight checkboxes named "Show close",
--- "Show lock", "Show segment picker" ask a player to translate a word back into
--- the glyph they were actually looking at, and the two that draw a padlock and a
--- gear were the two hardest to name. Putting the icon in the label removes the
--- translation: the tick, the picture, the words.
---
--- BAKED INTO `label` because that is the only string the library draws --
--- LibKa0s' makeCheckbox reads `row.label` and nothing else, so an `icon` field
--- beside it would be a field with no renderer. The texture escape is a PREFIX,
--- never a replacement: tests/test_schema.lua's localization case strips it and
--- checks the rest is still a locale key, so a row cannot lose its translation by
--- gaining a picture.
---
--- NIL IS A REAL ANSWER from NS.Icon -- a degraded install has no art payload at
--- all (core/MediaSetup.lua) -- and it degrades to the plain label, which is what
--- this tab drew before. The size is the shipped `controlSize` default rather
--- than the player's, because a schema row is declared once at load and a label
--- that tracked the setting would need re-declaring every time it changed.
---
--- @param art string   an entry of the library's ICONS catalog
--- @param text string   the localized label
--- @return string
local function controlLabel(art, text)
    local path = NS.Icon and NS.Icon(art)
    if not path then return text end
    return string.format("|T%s:14:14:0:0|t %s", path, text)
end

--- A DEFERRED LibSharedMedia list, pulled at render and at parse time.
---
--- Deferred is load-bearing twice over here. First for the usual reason — the
--- addons that register media have not run when a schema row is declared, so a
--- snapshot would freeze the list at whatever loaded first. Second because this
--- file loads BEFORE settings/OptionsSetup.lua, so NS.Helpers does not exist yet
--- and the library's own LSMValues cannot be called at declaration at all.
---
--- The library's closure is CONSUMED, never reimplemented: it owns the
--- never-answer-empty rule (a dropdown with no options cannot be opened, and the
--- CLI would then refuse even the value already stored), and a private copy here
--- would be the copy that goes stale.
local function lsmValues(mediaType)
    return function()
        local H = NS.Helpers
        local maker = H and H.LSMValues
        if not maker then return {} end
        local list = maker(mediaType)
        return (type(list) == "function" and list()) or list or {}
    end
end

-- ---------------------------------------------------------------------------
-- Common validators
-- ---------------------------------------------------------------------------

local function isNumberIn(minimum, maximum)
    return function(v)
        return type(v) == "number" and v >= minimum and v <= maximum
    end
end

-- ---------------------------------------------------------------------------
-- The composers
-- ---------------------------------------------------------------------------
--
-- options-ui-§15, §16 and §17's canonical blocks -- the master controls, and every
-- font, border and bar group -- are EMITTED by LibKa0s-Options-1.0 rather than
-- written out below (anti-patterns #73). Nine addons hand-writing the same six
-- font rows in six different orders is the drift the composers exist to end, and a
-- tenth copy here would be the drift.
--
-- REACHED OFF A TABLE OF THIS FILE'S OWN rather than off NS.Helpers, and the
-- reason is load order. `lib.__AttachCompose` is what `lib:New` calls to hang the
-- composers on an instance, and settings/OptionsSetup.lua does not build one until
-- after this file has run -- so `NS.Helpers.FontGroup` does not exist at the
-- moment these rows are declared. Every composer is a PURE FUNCTION that reads no
-- state and creates no widget, so a bare table is a complete home for them --
-- given the two members they forward through, below.
--
-- LSMValues IS SUPPLIED AS THE FACTORY ITSELF, NOT AS A CALLER OF IT. The
-- composer emits its media rows as `values = O.LSMValues(kind)` and reads this
-- member ONCE, at row-declaration time, assigning whatever comes back straight
-- into `values` -- because the flow engine's `enumList` unwraps a row's `values`
-- exactly once. So the member has to answer a FUNCTION: the deferred reader that
-- the dropdown calls when it opens. `lsmValues` is exactly that factory, so it is
-- handed over bare.
--
-- IT USED TO BE WRAPPED, and the wrapper was right at the time. Up to LibKa0s
-- v1.25.0 the composer declared `values = function() return O.LSMValues(kind) end`
-- and so called this member at RENDER time, one unwrap later -- where answering a
-- function would have reached enumList as a function and drawn an empty dropdown.
-- v1.26.0 moved the read to declaration time, which inverts the requirement: the
-- old wrapper now hands the composer a table built before any media addon has
-- registered anything, and a list frozen at file load raises nothing, warns
-- nothing and reddens no case. It is the failure the deferral exists to prevent.
-- The wrapper and the vendored payload therefore move in the same commit; neither
-- is correct against the other's version.
--
-- WITH NO LIBRARY THERE ARE NO COMPOSERS and every block below is EMPTY. That is
-- the deliberate cost of composing rather than copying, and it costs nothing a
-- player can reach: a degraded install has no settings panel
-- (settings/OptionsSetup.lua) and no schema CLI (settings/Slash.lua), so the rows
-- those two surfaces are made of have no reader left. Recorded as a documented
-- deviation in docs/ARCHITECTURE.md.
--
-- TWO INSTANCE MEMBERS ARE FORWARDED ONTO IT, and they are the whole of what the
-- composers reach for. `LSMValues` is read once, as a media row is declared;
-- `InlineButtonPair` is called by the ONE composer product that is not a pure
-- function -- MasterControls' `afterGroup` hook, which draws the tab's closing
-- button pair and therefore has to touch a widget. Both forward to NS.Helpers at
-- CALL time, which is long after settings/OptionsSetup.lua has built it.
local C = {}
do
    local optlib = LibStub and LibStub("LibKa0s-Options-1.0", true)
    if optlib and optlib.__AttachCompose then
        C.LSMValues = lsmValues
        C.InlineButtonPair = function(ctx, left, right)
            local H = NS.Helpers
            if H and H.InlineButtonPair then return H.InlineButtonPair(ctx, left, right) end
        end
        optlib.__AttachCompose(C)
    end
end

--- Compose one canonical block, or nothing at all when there is no library.
---
--- @param name string  the composer's member name
--- @param spec table   its declaration
--- @return table rows, function|nil afterGroup
local function compose(name, spec)
    local maker = C[name]
    if not maker then return {} end
    return maker(spec)
end

--- Re-dress composed rows with this addon's own shipped ranges and sentences.
---
--- The composers take `keys`, `defaults` and `labels`, so a block can be composed
--- without moving a stored path, a shipped value or a row name. They take nothing
--- for the REST of a row -- the slider bounds, the `%d px` suffix, the validator,
--- the stored value SET behind a dropdown, and the sentence in the tooltip -- and
--- every one of those is already a shipped promise here. A `fontFlags` row that
--- arrived carrying the library's own flag vocabulary would refuse this addon's
--- stored `"NONE"`; a `borderSize` slider that stopped at 16 would put a stored 24
--- out of reach. So the composer decides WHICH rows there are and in what order,
--- and this restores what each of them already was.
---
--- Keyed by PATH, which is the one name a composed row and this file agree on.
--- `desc` is set rather than `tooltip` because the flow engine reads
--- `row.tooltip or row.desc` and this addon's rows have always spelled it `desc`;
--- the composer's English sentence is cleared with it.
---
--- @param rows table    the composed block
--- @param byPath table  path -> a table of fields to write onto that row
--- @return table rows
local function dress(rows, byPath)
    for _, row in ipairs(rows) do
        local fields = byPath[row.path]
        if fields then
            for k, v in pairs(fields) do row[k] = v end
            if fields.desc ~= nil then row.tooltip = nil end
        end
    end
    return rows
end

--- Put this addon's colour-MODE row where the composer's boolean companion was.
---
--- options-ui-§17 names a colour-mode dropdown whose value set includes `class` as
--- the RICHER form of the same control, and forbids converting one back: this
--- addon migrated its `classColor` booleans into three- and four-value modes on
--- purpose (core/Database.lua's v10 and v13 steps), and `stat`, `skin` and `none`
--- are answers a checkbox cannot give. So every composed block omits the boolean
--- companion and this splices the mode into the slot it vacated -- immediately
--- after the swatch, which is where the companion goes and what puts it to the
--- swatch's right.
---
--- @param rows table   the composed block
--- @param after string the swatch's path; the mode lands directly behind it
--- @param modeRow table
--- @return table rows
local function withMode(rows, after, modeRow)
    -- HAND-WRITTEN, and stamped so, even though it lands inside a composed block:
    -- it is declared here in full and it survives a load with no library, which is
    -- exactly what `composed` is read to mean (see expandBlocks).
    modeRow.composed = false
    for i, row in ipairs(rows) do
        if row.path == after then
            table.insert(rows, i + 1, modeRow)
            return rows
        end
    end
    -- No swatch means no library and no block at all; the mode row still has to
    -- exist, because it is a stored path the CLI and the validator both know.
    rows[#rows + 1] = modeRow
    return rows
end

--- Mark a composed block for expansion where it sits. See expandBlocks below.
---
--- A Lua table literal cannot splice an array into itself, and these blocks sit in
--- the MIDDLE of their pages rather than at the end -- a tab's position in the
--- strip is its group's first appearance in declaration order, so appending them
--- would reorder the strip. The literal therefore holds the block whole, at the
--- place it belongs, and one pass afterwards unpacks it.
local function block(rows) return { __block = rows } end

--- Flatten every composed block into the array around it, in place.
---
--- Every row that comes out of a block is stamped `composed`. It is inert to every
--- reader of the schema and it is not decoration: it is the ONE thing that tells a
--- library-emitted row from a hand-written one, and tests/test_degraded.lua reads
--- it to say exactly which rows a library-less install is allowed to be missing.
--- Without it that case can only compare two totals and cannot name what went.
local function expandBlocks(schema)
    local i = 1
    while i <= #schema do
        local entry = schema[i]
        if entry.__block then
            local rows = entry.__block
            table.remove(schema, i)
            for k = #rows, 1, -1 do
                -- `== nil` rather than a plain assignment: withMode's colour-mode
                -- rows sit inside these blocks and have already said they are not
                -- the library's.
                if rows[k].composed == nil then rows[k].composed = true end
                table.insert(schema, i, rows[k])
            end
            i = i + #rows
        else
            i = i + 1
        end
    end
    return schema
end

-- The four general-visibility answers, in this addon's own strings. The KEYS are
-- the library's -- `always`, `inCombat`, `outOfCombat`, `never` -- because they are
-- what is stored and what `/mm set master.visibility` accepts; only the display
-- side is ours.
local MASTERVIS_VALUES = {
    always      = L["Always"],
    inCombat    = L["Only in combat"],
    outOfCombat = L["Only out of combat"],
    never       = L["Never"],
}
local MASTERVIS_SORT = { "always", "inCombat", "outOfCombat", "never" }

-- ── Master controls (options-ui-§15) ────────────────────────────────────────
--
-- THE FIRST TAB OF THE GENERAL PAGE, and the canonical set in the canonical
-- order: enable, general visibility, master scale, master alpha, lock frame,
-- debug console, then the two resets as the tab's closing button pair.
--
-- WHAT IS NOT HERE, DELIBERATELY. `window.frame.locked`, `window.frame.scale` and
-- `window.frame.alpha` stay on the Frame page. They are PER-WINDOW, they are
-- reached through the window banner, and promoting one of them here would give the
-- General page -- which draws no banner -- a control that silently retargeted
-- whenever the picker moved two pages away. The four `master.*` rows are the
-- addon-wide answers those three do not have, and modules/Window.lua composes each
-- pair rather than choosing between them (options-ui-§15's per-instance clause).
--
-- `enabled` and `state.debugConsole` MOVED here from the old General tab and are
-- declared nowhere else; their stored paths did not change, because a `group` is
-- not a stored path.
local MASTER_ROWS, MASTER_TAIL = compose("MasterControls", {
    page             = "general",
    group            = L["Master controls"],
    addonName        = "Multi Meters",
    -- VERBATIM and unprefixed: session state lives outside the block's own prefix,
    -- and this is the path the row this addon already had was stored under.
    debugConsolePath = "state.debugConsole",
    -- The four new addon-wide settings live under `master.` rather than at the
    -- profile root, which is where every other grouped answer in this addon lives
    -- (`data.`, `minimap.`, `export.`) and what keeps `master.scale` from reading
    -- like a synonym for `window.frame.scale` on the CLI. `enabled` keeps the root
    -- path it has always had.
    keys = {
        visibility = "master.visibility",
        scale      = "master.scale",
        alpha      = "master.alpha",
        locked     = "master.locked",
    },
    labels = {
        enabled      = L["Enable Multi Meters"],
        visibility   = L["General visibility"],
        scale        = L["Master scale"],
        alpha        = L["Master alpha"],
        locked       = L["Lock frame"],
        debugConsole = L["Debug console"],
    },
    -- Resolved at CALL time, both of them: the popup is declared by
    -- settings/General.lua and the registry by modules/WindowManager.lua, and this
    -- file loads before either.
    --
    -- RESET POSITION KEEPS ITS PER-WINDOW MEANING. It is reached from the General
    -- page, which draws no banner, so what it moves is the window the Windows page
    -- has selected -- see the note beside the pair in settings/General.lua, which
    -- is where that sentence can still be said on screen.
    onResetPosition = function()
        local M = NS.WindowManager
        if M and M.ResetPosition then
            M:ResetPosition(NS.State and NS.State.activeWindowId)
        end
    end,
    -- options-ui-§12's global reset, through the confirmation this addon has always
    -- asked first: it DELETES the extra windows, which "reset settings" does not
    -- sound like.
    onResetAll = function()
        if _G.StaticPopup_Show then _G.StaticPopup_Show("MULTIMETERS_RESET_ALL") end
    end,
})

dress(MASTER_ROWS, {
    ["enabled"] = {
        desc = L["Master switch for the addon. When off, no window is drawn and no data is read."],
        onChange = refreshVisibility,
    },
    ["master.visibility"] = {
        values = MASTERVIS_VALUES, sorting = MASTERVIS_SORT,
        desc = L["When this addon's windows are shown at all, whatever one window's own Visibility page says. Never is the master switch's quieter half and is read beside it; the two combat answers are read with the per-window context rules, so Test mode still forces a window on."],
        onChange = refreshVisibility,
    },
    ["master.scale"] = {
        fmt = "%.2fx",
        desc = L["Scale multiplier for every window, multiplied into each window's own Scale on the Frame page. A window at 0.80 under a master of 0.50 draws at 0.40."],
        validate = isNumberIn(0.5, 2.0),
    },
    ["master.alpha"] = {
        desc = L["Opacity multiplier for every window, multiplied into each window's own Opacity on the Frame page."],
        validate = isNumberIn(0, 1),
    },
    ["master.locked"] = {
        desc = L["Lock every window at once. A window can be dragged only while neither this nor its own Lock window is on, so unticking this leaves the windows you locked one at a time locked."],
    },
    -- The console WINDOW's visibility, NOT the logging flag: logging runs with the
    -- console closed so a bug can be reproduced first and the log read afterwards,
    -- and the flag itself is session-only state that `/mm debug on|off` owns
    -- (debug-logging section 5). The composer marks the row `sessionOnly`; the two
    -- accessors below ARE its whole storage.
    ["state.debugConsole"] = {
        desc = L["Show or hide the on-screen debug console. Session only; it does not turn debug logging on."],
        get = function() return NS.DebugLog ~= nil and NS.DebugLog:IsShown() end,
        set = function(v)
            local D = NS.DebugLog
            if not D then return end
            if v then D:Show() else D:Hide() end
        end,
    },
})

-- Published for settings/General.lua, which wires it as the Master controls
-- group's `afterGroup` hook. The GROUP NAME IS THE HOOK KEY, so the two have to be
-- the same string and both are `L["Master controls"]`.
NS.MasterControlsAfterGroup = MASTER_TAIL

-- ── Frame > Background and border (options-ui-§7's subsection headings) ─────
--
-- THE MERGE STAYS. The fill inside the window and the edge around it spent a
-- release split across "Size and position" and "Border style", and a player
-- looking for "what colour is my window" found it under neither. What
-- options-ui-§7 adds is the two headings that say where one stops and the next
-- starts, not a second tab.
local FRAME_BG_ROWS = compose("ColorPair", {
    prefix = "window.frame.",
    page = "frame", group = L["Background and border"], subgroup = L["Background"],
    key = "backdropColor", label = L["Background color"],
    omit = { useClassColorBackdropColor = true },
    defaults = { backdropColor = { r = 0, g = 0, b = 0, a = 0.75 } },
    -- The window's chrome is about the WINDOW, so the only class it can mean is
    -- the local player's (modules/Window.lua's headerColor makes the same call for
    -- the strip above it).
    classColor = { source = "player" },
})
dress(FRAME_BG_ROWS, {
    ["window.frame.backdropColor"] = { desc = L["Color drawn behind the rows."] },
})
withMode(FRAME_BG_ROWS, "window.frame.backdropColor", {
    path = "window.frame.backdropColorMode", type = "string", default = "custom",
    values = CONTROLCOLOR_VALUES, sorting = CONTROLCOLOR_SORT,
    page = "frame", group = L["Background and border"], subgroup = L["Background"],
    label = L["Background color mode"],
    classColorSource = "player",
    desc = L["What colors the fill inside the window. Class color is your own -- a window is not about any one row."],
})

local FRAME_BORDER_ROWS = compose("BorderGroup", {
    prefix = "window.frame.",
    page = "frame", group = L["Background and border"], subgroup = L["Border"],
    omit = { useClassColorBorder = true },
    labels = {
        borderStyle = L["Border style"], borderSize = L["Border thickness"],
        borderColor = L["Border color"],
    },
    defaults = {
        borderStyle = "Blizzard Tooltip", borderSize = 2,
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
    },
    classColor = { source = "player" },
})
dress(FRAME_BORDER_ROWS, {
    ["window.frame.borderStyle"] = {
        values = lsmValues("border"),
        desc = L["LibSharedMedia border texture drawn around the window."],
    },
    ["window.frame.borderSize"] = {
        min = 0, max = 32, step = 1, fmt = "%d px",
        desc = L["Border edge size in pixels."],
    },
    ["window.frame.borderColor"] = { desc = L["Color of the window border."] },
})
withMode(FRAME_BORDER_ROWS, "window.frame.borderColor", {
    path = "window.frame.borderColorMode", type = "string", default = "custom",
    values = CONTROLCOLOR_VALUES, sorting = CONTROLCOLOR_SORT,
    page = "frame", group = L["Background and border"], subgroup = L["Border"],
    label = L["Border color mode"],
    classColorSource = "player",
    desc = L["What colors the edge around the window. Class color is your own."],
})

-- ── Header > Title text (options-ui-§16's font block) ───────────────────────
local HEADER_TEXT_ROWS = compose("FontGroup", {
    prefix = "window.header.",
    page = "header", group = L["Title text"],
    keys = { fontSize = "size", fontColor = "color", fontFlags = "outline", fontShadow = "shadow" },
    omit = { useClassColorFont = true },
    labels = {
        font = L["Font"], fontSize = L["Font size"], fontColor = L["Text color"],
        fontFlags = L["Font outline"], fontShadow = L["Text shadow"],
    },
    defaults = {
        font = "Friz Quadrata TT", fontSize = 12,
        fontColor = { r = 1, g = 0.82, b = 0, a = 1 },
        fontFlags = "OUTLINE", fontShadow = false,
    },
    classColor = { source = "player" },
})
dress(HEADER_TEXT_ROWS, {
    ["window.header.font"] = {
        values = lsmValues("font"),
        desc = L["Font used for every number in the grid. A monospace font such as JetBrains Mono keeps columns from shifting as the numbers change; the default matches the window header."],
    },
    ["window.header.size"] = { fmt = "%d px", desc = L["Text size in pixels."] },
    ["window.header.color"] = { desc = L["Color of the header's own lines."] },
    ["window.header.outline"] = {
        values = OUTLINE_VALUES, sorting = OUTLINE_SORT,
        desc = L["Outline and monochrome flags applied to the text."],
    },
    ["window.header.shadow"] = {
        desc = L["Draw a drop shadow behind the header text so it stays readable over a bright backdrop."],
    },
})
withMode(HEADER_TEXT_ROWS, "window.header.color", {
    path = "window.header.colorMode", type = "string", default = "custom",
    values = CONTROLCOLOR_VALUES, sorting = CONTROLCOLOR_SORT,
    page = "header", group = L["Title text"],
    label = L["Text color mode"],
    classColorSource = "player",
    desc = L["What colors the window's title and the session line beside it. Class color is your own -- a window-wide strip has no other class it could mean."],
})

-- ── Bars > Bar, Background and Border (options-ui-§16) ──────────────────────
local BARS_BAR_ROWS = compose("BarGroup", {
    prefix = "window.bars.",
    page = "bars", group = L["Bar"],
    keys = { barTexture = "texture", barAlpha = "alpha", barColor = "customColor" },
    omit = { useClassColorBar = true },
    labels = {
        barTexture = L["Bar texture"], barAlpha = L["Bar opacity"], barColor = L["Bar color"],
    },
    defaults = {
        barTexture = "Blizzard Raid Bar", barAlpha = 1.0,
        barColor = { r = 0.35, g = 0.55, b = 0.85, a = 1 },
    },
    -- A CELL IS ABOUT THE ROW IT IS DRAWN ON, so `class` here is the class of the
    -- player that row belongs to and never the local player's -- modules/Row.lua's
    -- ApplyEntryTextColor is where that is decided, off the entry's own
    -- classFilename. There is no unit TOKEN to name: a meter row is identified by
    -- the GUID and class the provider hands over, and half a raid has no token.
    classColor = { source = "unit" },
    extra = { {
        path = "window.bars.fillDirection", type = "string", default = "LEFT",
        values = SIDE_VALUES, sorting = SIDE_SORT,
        label = L["Fill direction"], desc = L["Which edge of the cell each bar grows from."],
    } },
})
dress(BARS_BAR_ROWS, {
    ["window.bars.texture"] = {
        values = lsmValues("statusbar"),
        desc = L["LibSharedMedia statusbar texture used for every cell's bar."],
    },
    ["window.bars.alpha"] = {
        step = 0.01, desc = L["Opacity of the filled part of each bar."],
        validate = isNumberIn(0, 1),
    },
    ["window.bars.customColor"] = {
        desc = L["Fill color used when the color mode is set to Custom color."],
    },
})
withMode(BARS_BAR_ROWS, "window.bars.customColor", {
    path = "window.bars.colorMode", type = "string", default = "class",
    values = BARCOLOR_VALUES, sorting = BARCOLOR_SORT,
    page = "bars", group = L["Bar"],
    label = L["Bar color mode"],
    classColorSource = "unit",
    desc = L["Color bars by the player's class, by which statistic the column shows, or with one color everywhere."],
})

-- A GROUP OVER A BACKGROUND IS NOT A BAR GROUP (options-ui-§16): the tint behind a
-- bar has no fill texture of its own, so it takes the swatch and its mode and
-- nothing else. Inventing a texture picker here would be a control wired to
-- nothing.
local BARS_BG_ROWS = compose("ColorPair", {
    prefix = "window.bars.",
    page = "bars", group = L["Background"],
    key = "bgColor", label = L["Bar background color"],
    omit = { useClassColorBgColor = true },
    defaults = { bgColor = { r = 0, g = 0, b = 0, a = 1 } },
    classColor = { source = "unit" },
    extra = { {
        path = "window.bars.bgAlpha", type = "number", default = 0.1,
        min = 0, max = 1, step = 0.01, isPercent = true,
        label = L["Bar background opacity"],
        desc = L["Opacity of the unfilled part of each bar."],
        validate = isNumberIn(0, 1),
    } },
})
dress(BARS_BG_ROWS, {
    ["window.bars.bgColor"] = { desc = L["Color drawn behind the unfilled part of each bar."] },
})
withMode(BARS_BG_ROWS, "window.bars.bgColor", {
    path = "window.bars.bgColorMode", type = "string", default = "class",
    values = BARBG_VALUES, sorting = BARBG_SORT,
    page = "bars", group = L["Background"],
    label = L["Bar background color mode"],
    classColorSource = "unit",
    desc = L["What colors the tint behind each bar. Class is the default and keeps working mid-fight, because a class is never hidden the way a number is."],
})

local BARS_BORDER_ROWS = compose("BorderGroup", {
    prefix = "window.bars.",
    page = "bars", group = L["Border"],
    -- The group's own "Show border" toggle, which options-ui-§16 allows to lead the
    -- block and is the only thing that may.
    show = true,
    keys = { borderShow = "border", borderSize = "borderThickness" },
    omit = { useClassColorBorder = true },
    labels = {
        borderShow = L["Bar border"], borderStyle = L["Border style"],
        borderSize = L["Border thickness"], borderColor = L["Border color"],
    },
    defaults = {
        borderShow = false, borderStyle = "None", borderSize = 1,
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
    },
    classColor = { source = "unit" },
})
dress(BARS_BORDER_ROWS, {
    ["window.bars.border"] = { desc = L["Draw an outline around each bar."] },
    ["window.bars.borderStyle"] = {
        values = lsmValues("border"),
        -- "None" IS A CHOICE, NOT A MISSING VALUE, and modules/Row.lua's borderEdge
        -- treats it as one -- it is what keeps the cheap four-texture outline as the
        -- default and puts a backdrop on a cell only for a player who has actually
        -- asked for edge art.
        desc = L["Edge art drawn around each bar. None is a flat outline in the color below, which is what this setting has always drawn."],
    },
    ["window.bars.borderThickness"] = {
        min = 1, max = 8, step = 1, fmt = "%d px",
        desc = L["How thick the outline around each bar is, in pixels."],
        validate = isNumberIn(1, 8),
    },
    ["window.bars.borderColor"] = {
        desc = L["Color of the outline around each bar. It used to be the skin's own edge color, which no setting could reach."],
    },
})
withMode(BARS_BORDER_ROWS, "window.bars.borderColor", {
    path = "window.bars.borderColorMode", type = "string", default = "custom",
    values = CONTROLCOLOR_VALUES, sorting = CONTROLCOLOR_SORT,
    page = "bars", group = L["Border"],
    label = L["Border color mode"],
    classColorSource = "unit",
    desc = L["What colors the outline around each bar. Class is the class of the row being drawn."],
})

-- ── Bars > Text style (options-ui-§16's font block) ─────────────────────────
local BARS_TEXT_ROWS = compose("FontGroup", {
    prefix = "window.text.",
    page = "bars", group = L["Text style"],
    keys = { fontSize = "size", fontColor = "color", fontFlags = "outline", fontShadow = "shadow" },
    omit = { useClassColorFont = true },
    labels = {
        font = L["Font"], fontSize = L["Font size"], fontColor = L["Text color"],
        fontFlags = L["Font outline"], fontShadow = L["Text shadow"],
    },
    defaults = {
        font = "Friz Quadrata TT", fontSize = 11,
        fontColor = { r = 1, g = 1, b = 1, a = 1 },
        fontFlags = "NONE", fontShadow = true,
    },
    classColor = { source = "unit" },
    extra = { {
        path = "window.text.alpha", type = "number", default = 1.0,
        min = 0, max = 1, step = 0.01, isPercent = true,
        label = L["Text opacity"], desc = L["Opacity of the numbers and names."],
        validate = isNumberIn(0, 1),
    } },
})
dress(BARS_TEXT_ROWS, {
    ["window.text.font"] = {
        values = lsmValues("font"),
        desc = L["Font used for every number in the grid. A monospace font such as JetBrains Mono keeps columns from shifting as the numbers change; the default matches the window header."],
    },
    ["window.text.size"] = { fmt = "%d px", desc = L["Text size in pixels."] },
    ["window.text.color"] = { desc = L["Color of the numbers and names."] },
    ["window.text.outline"] = {
        values = OUTLINE_VALUES, sorting = OUTLINE_SORT,
        desc = L["Outline and monochrome flags applied to the text."],
    },
    ["window.text.shadow"] = {
        desc = L["Draw a drop shadow behind the text so it stays readable over a bright bar."],
    },
})
withMode(BARS_TEXT_ROWS, "window.text.color", {
    path = "window.text.colorMode", type = "string", default = "custom",
    values = TEXTCOLOR_VALUES, sorting = TEXTCOLOR_SORT,
    page = "bars", group = L["Text style"],
    label = L["Text color mode"],
    classColorSource = "unit",
    desc = L["What colors the numbers and names. Class is the class of the row being drawn; Per-statistic is the color of the column each cell sits in."],
})

-- ── Tooltip > Bar, Bar background, Bar border and Text ──────────────────────
local TIP_BAR_ROWS = compose("BarGroup", {
    prefix = "window.tooltip.",
    page = "tooltip", group = L["Bar"],
    omit = { useClassColorBar = true },
    labels = {
        barTexture = L["Bar texture"], barAlpha = L["Bar opacity"], barColor = L["Bar color"],
    },
    defaults = {
        barTexture = "Blizzard Raid Bar", barAlpha = 0.85,
        barColor = { r = 0.6, g = 0.6, b = 0.6, a = 1 },
    },
    -- The hovered PLAYER's class, not the local player's: a tooltip is opened over
    -- one row and is about that row (modules/Tooltip.lua's modeColor).
    classColor = { source = "unit" },
    extra = { {
        path = "window.tooltip.barSpacing", type = "number", default = 1,
        min = 0, max = 12, step = 1, fmt = "%d px",
        label = L["Bar spacing"], desc = L["Gap in pixels between one tooltip line and the next."],
        validate = isNumberIn(0, 12),
    } },
})
dress(TIP_BAR_ROWS, {
    ["window.tooltip.barTexture"] = {
        values = lsmValues("statusbar"),
        desc = L["LibSharedMedia statusbar texture drawn behind each spell line."],
    },
    ["window.tooltip.barAlpha"] = {
        step = 0.01, desc = L["Opacity of the filled part of each tooltip bar."],
        validate = isNumberIn(0, 1),
    },
    ["window.tooltip.barColor"] = {
        desc = L["Color of the filled part, when the mode beside it is Custom."],
    },
})
withMode(TIP_BAR_ROWS, "window.tooltip.barColor", {
    path = "window.tooltip.barColorMode", type = "string", default = "class",
    values = TEXTCOLOR_VALUES, sorting = TEXTCOLOR_SORT,
    page = "tooltip", group = L["Bar"],
    label = L["Bar color mode"],
    classColorSource = "unit",
    desc = L["What colors the filled part of each tooltip bar. Class is the player you are hovering; Per-statistic is the color of the column the grid is sorted by."],
})

local TIP_BARBG_ROWS = compose("ColorPair", {
    prefix = "window.tooltip.",
    page = "tooltip", group = L["Bar background"],
    key = "barBgColor", label = L["Bar background color"],
    omit = { useClassColorBarBgColor = true },
    defaults = { barBgColor = { r = 0, g = 0, b = 0, a = 1 } },
    classColor = { source = "unit" },
    extra = { {
        path = "window.tooltip.barBgAlpha", type = "number", default = 0.1,
        min = 0, max = 1, step = 0.01, isPercent = true,
        label = L["Bar background opacity"],
        desc = L["Opacity of the unfilled part of each tooltip bar."],
        validate = isNumberIn(0, 1),
    } },
})
dress(TIP_BARBG_ROWS, {
    ["window.tooltip.barBgColor"] = {
        desc = L["Color of the unfilled part, when the mode beside it is Custom."],
    },
})
withMode(TIP_BARBG_ROWS, "window.tooltip.barBgColor", {
    path = "window.tooltip.barBgColorMode", type = "string", default = "custom",
    values = TEXTCOLOR_VALUES, sorting = TEXTCOLOR_SORT,
    page = "tooltip", group = L["Bar background"],
    label = L["Bar background color mode"],
    classColorSource = "unit",
    desc = L["What colors the unfilled part of each tooltip bar."],
})

local TIP_BARBORDER_ROWS = compose("BorderGroup", {
    prefix = "window.tooltip.",
    page = "tooltip", group = L["Bar border"],
    keys = { borderStyle = "barBorderStyle", borderSize = "barBorderSize", borderColor = "barBorderColor" },
    omit = { useClassColorBorder = true },
    labels = {
        borderStyle = L["Bar border style"], borderSize = L["Bar border thickness"],
        borderColor = L["Bar border color"],
    },
    defaults = {
        borderStyle = "None", borderSize = 1,
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
    },
    classColor = { source = "unit" },
})
dress(TIP_BARBORDER_ROWS, {
    ["window.tooltip.barBorderStyle"] = {
        values = lsmValues("border"),
        desc = L["LibSharedMedia border drawn around each spell bar. Most border art is cut for a window rather than a 14px line, so it may look heavy here."],
    },
    ["window.tooltip.barBorderSize"] = {
        min = 0, max = 16, step = 1, fmt = "%d px",
        desc = L["Border edge size in pixels."],
        validate = isNumberIn(0, 16),
    },
    ["window.tooltip.barBorderColor"] = {
        desc = L["Color of the border around each spell bar."],
    },
})
withMode(TIP_BARBORDER_ROWS, "window.tooltip.barBorderColor", {
    path = "window.tooltip.barBorderColorMode", type = "string", default = "custom",
    values = CONTROLCOLOR_VALUES, sorting = CONTROLCOLOR_SORT,
    page = "tooltip", group = L["Bar border"],
    label = L["Bar border color mode"],
    classColorSource = "unit",
    desc = L["What colors the border around each spell bar. Class is the player you are hovering."],
})

local TIP_TEXT_ROWS = compose("FontGroup", {
    prefix = "window.tooltip.",
    page = "tooltip", group = L["Text"],
    keys = { fontColor = "textColor", fontFlags = "fontOutline" },
    omit = { useClassColorFont = true },
    labels = {
        font = L["Font"], fontSize = L["Font size"], fontColor = L["Text color"],
        fontFlags = L["Font outline"], fontShadow = L["Text shadow"],
    },
    defaults = {
        font = "Friz Quadrata TT", fontSize = 12,
        fontColor = { r = 1, g = 1, b = 1, a = 1 },
        fontFlags = "NONE", fontShadow = false,
    },
    classColor = { source = "unit" },
})
dress(TIP_TEXT_ROWS, {
    ["window.tooltip.font"] = {
        values = lsmValues("font"),
        desc = L["Font used for the tooltip's spell names and numbers."],
    },
    ["window.tooltip.fontSize"] = {
        min = 6, max = 32, step = 1, fmt = "%d px",
        desc = L["Tooltip text size in pixels."],
        validate = isNumberIn(6, 32),
    },
    ["window.tooltip.textColor"] = {
        desc = L["Color of the amount and percentage on each tooltip line."],
    },
    ["window.tooltip.fontOutline"] = {
        values = OUTLINE_VALUES, sorting = OUTLINE_SORT,
        desc = L["Outline and monochrome flags applied to the tooltip text."],
    },
    ["window.tooltip.fontShadow"] = {
        desc = L["Draw a drop shadow behind the tooltip text so it stays readable over a bright bar."],
    },
})
withMode(TIP_TEXT_ROWS, "window.tooltip.textColor", {
    path = "window.tooltip.colorMode", type = "string", default = "custom",
    values = TEXTCOLOR_VALUES, sorting = TEXTCOLOR_SORT,
    page = "tooltip", group = L["Text"],
    label = L["Text color mode"],
    classColorSource = "unit",
    desc = L["What colors the tooltip's text. Class is the class of the player you are hovering; Per-statistic is the color of the column the grid is sorted by."],
})

-- ── Columns > Header text and Header background ─────────────────────────────
local COLHEAD_TEXT_ROWS = compose("FontGroup", {
    prefix = "window.columnHeader.",
    page = "columns", group = L["Header text"],
    keys = { fontSize = "size", fontColor = "color", fontFlags = "outline", fontShadow = "shadow" },
    omit = { useClassColorFont = true },
    labels = {
        font = L["Font"], fontSize = L["Font size"], fontColor = L["Text color"],
        fontFlags = L["Font outline"], fontShadow = L["Text shadow"],
    },
    defaults = {
        font = "Friz Quadrata TT", fontSize = 11,
        fontColor = { r = 1, g = 0.82, b = 0, a = 1 },
        fontFlags = "OUTLINE", fontShadow = false,
    },
    -- One strip across the whole window, so `class` can only be the local player's,
    -- exactly as it is for the title bar above it.
    classColor = { source = "player" },
})
dress(COLHEAD_TEXT_ROWS, {
    ["window.columnHeader.font"] = {
        values = lsmValues("font"),
        desc = L["Font used for the column header strip above the rows."],
    },
    ["window.columnHeader.size"] = {
        fmt = "%d px", desc = L["Column header text size in pixels."],
        validate = isNumberIn(6, 32),
    },
    ["window.columnHeader.color"] = { desc = L["Color of the column header labels."] },
    ["window.columnHeader.outline"] = {
        values = OUTLINE_VALUES, sorting = OUTLINE_SORT,
        desc = L["Outline and monochrome flags applied to the column headers."],
    },
    ["window.columnHeader.shadow"] = {
        desc = L["Draw a drop shadow behind the column labels so they stay readable over a bright backdrop."],
    },
})
withMode(COLHEAD_TEXT_ROWS, "window.columnHeader.color", {
    path = "window.columnHeader.colorMode", type = "string", default = "custom",
    values = TEXTCOLOR_VALUES, sorting = TEXTCOLOR_SORT,
    page = "columns", group = L["Header text"],
    label = L["Text color mode"],
    classColorSource = "player",
    desc = L["What colors the column labels. Per-statistic gives each label its own column's color, which is the one surface where that is literally per column."],
})

local COLHEAD_BG_ROWS = compose("ColorPair", {
    prefix = "window.columnHeader.",
    page = "columns", group = L["Header background"],
    key = "bgColor", label = L["Background color"],
    omit = { useClassColorBgColor = true },
    defaults = { bgColor = { r = 0, g = 0, b = 0, a = 0 } },
    classColor = { source = "player" },
})
dress(COLHEAD_BG_ROWS, {
    ["window.columnHeader.bgColor"] = {
        desc = L["Color drawn behind the column header strip. Transparent by default \226\128\148 the strip has never had a backdrop."],
    },
})
-- NO `bgColorMode` on the title bar's own background, but this strip keeps one: it
-- labels the COLUMNS, so "per statistic" tints each label with its own column's
-- colour and means something, where the same mode on the title bar -- one strip
-- over the whole window -- could only ever mean the sort column's colour.
withMode(COLHEAD_BG_ROWS, "window.columnHeader.bgColor", {
    path = "window.columnHeader.bgColorMode", type = "string", default = "custom",
    values = TEXTCOLOR_VALUES, sorting = TEXTCOLOR_SORT,
    page = "columns", group = L["Header background"],
    label = L["Background color mode"],
    classColorSource = "player",
    desc = L["What colors the strip behind the column labels. Per-statistic tints each label's own cell with that column's color, which is the one surface where that is literally per column."],
})

-- ---------------------------------------------------------------------------
-- Published to settings/Schema.lua
-- ---------------------------------------------------------------------------
--
-- ONE table rather than fifty fields on NS, so the peel adds a single name to the
-- namespace, and so the array file can re-localize each member under the name its
-- rows already spell -- which is what lets the array read exactly as it did when
-- all of this was one file. Nothing outside settings/Schema.lua reads this table,
-- and a member is here because the array names it, not because it is public.
--
-- `MASTER_TAIL` is not in the list: it is already published on its own, as
-- NS.MasterControlsAfterGroup above, because settings/General.lua is its reader.
NS.SchemaCompose = {
    ALIGN_SORT           = ALIGN_SORT,
    ALIGN_VALUES         = ALIGN_VALUES,
    ANCHOR_SORT          = ANCHOR_SORT,
    ANCHOR_VALUES        = ANCHOR_VALUES,
    BARS_BAR_ROWS        = BARS_BAR_ROWS,
    BARS_BG_ROWS         = BARS_BG_ROWS,
    BARS_BORDER_ROWS     = BARS_BORDER_ROWS,
    BARS_TEXT_ROWS       = BARS_TEXT_ROWS,
    CHANNEL_SORT         = CHANNEL_SORT,
    CHANNEL_VALUES       = CHANNEL_VALUES,
    COLHEAD_BG_ROWS      = COLHEAD_BG_ROWS,
    COLHEAD_TEXT_ROWS    = COLHEAD_TEXT_ROWS,
    CONTROLCOLOR_SORT    = CONTROLCOLOR_SORT,
    CONTROLCOLOR_VALUES  = CONTROLCOLOR_VALUES,
    DEATHTIME_SORT       = DEATHTIME_SORT,
    DEATHTIME_VALUES     = DEATHTIME_VALUES,
    DIVIDERCOLOR_SORT    = DIVIDERCOLOR_SORT,
    DIVIDERCOLOR_VALUES  = DIVIDERCOLOR_VALUES,
    FRAME_BG_ROWS        = FRAME_BG_ROWS,
    FRAME_BORDER_ROWS    = FRAME_BORDER_ROWS,
    GROWTH_SORT          = GROWTH_SORT,
    GROWTH_VALUES        = GROWTH_VALUES,
    HEADER_TEXT_ROWS     = HEADER_TEXT_ROWS,
    MASTER_ROWS          = MASTER_ROWS,
    NUMFMT_SORT          = NUMFMT_SORT,
    NUMFMT_VALUES        = NUMFMT_VALUES,
    OUTLINE_SORT         = OUTLINE_SORT,
    OUTLINE_VALUES       = OUTLINE_VALUES,
    SIDE_SORT            = SIDE_SORT,
    SIDE_VALUES          = SIDE_VALUES,
    SLOT_SORT            = SLOT_SORT,
    SLOT_VALUES          = SLOT_VALUES,
    STRATA_SORT          = STRATA_SORT,
    STRATA_VALUES        = STRATA_VALUES,
    TEXTCOLOR_SORT       = TEXTCOLOR_SORT,
    TEXTCOLOR_VALUES     = TEXTCOLOR_VALUES,
    TIP_BARBG_ROWS       = TIP_BARBG_ROWS,
    TIP_BARBORDER_ROWS   = TIP_BARBORDER_ROWS,
    TIP_BAR_ROWS         = TIP_BAR_ROWS,
    TIP_TEXT_ROWS        = TIP_TEXT_ROWS,
    block                = block,
    broadcastBarTexture  = broadcastBarTexture,
    broadcastColorMode   = broadcastColorMode,
    broadcastFont        = broadcastFont,
    broadcastOutline     = broadcastOutline,
    controlLabel         = controlLabel,
    expandBlocks         = expandBlocks,
    isNumberIn           = isNumberIn,
    lsmValues            = lsmValues,
    refreshMinimap       = refreshMinimap,
    refreshVisibility    = refreshVisibility,
}
