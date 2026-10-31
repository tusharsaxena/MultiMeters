-- core/Database_Migrations.lua
--
-- THE MIGRATION LADDER AND ITS RUNNER: every `migrations[N]` step and NS:RunMigrations. Peeled off
-- core/Database.lua for layout-§1 along the seam that file's watch-list row named, when it stood
-- 187 lines past its re-check. A pure move: Database.lua keeps CURRENT_DB_VERSION and the window
-- shape, and this file reads the version off NS.SCHEMA_VERSION and the deep copy off Database._copy.
--
-- TOC POSITION: LOAD-BEARING. Straight after core/Database.lua, because both are read at FILE
-- SCOPE; before core/Diagnostics.lua and every other reader, none of which needs it before
-- OnInitialize.

local _, NS = ...

local Database = NS.Database
local CURRENT_DB_VERSION = NS.SCHEMA_VERSION
local copy = Database._copy

-- ---------------------------------------------------------------------------
-- Migrations
-- ---------------------------------------------------------------------------
--
-- The savedvariables-§1 rules (WowAddonStandards v2.65.0), which every step and
-- the runner below keep:
--
--   * `migrations[N]` takes the account from vN to vN+1. It reads and writes db
--     and NEVER writes `schemaVersion`: the RUNNER owns the stamp, and advances it
--     to N+1 only after the step returned without raising. A step that raises
--     leaves the stamp at N, so the next load retries it.
--   * A profile-scoped step walks EVERY stored profile through allProfiles(db),
--     never db.profile alone: the stamp is account-wide, so a profile the step
--     skipped would never get a second chance.
--   * Every step is idempotent against a fresh default profile. An unstamped
--     account (0) walks the whole ladder from v1, and a fresh install is one.
--
-- Adding a step means appending `migrations[N] = function(db) ... end` and
-- raising core/Database.lua's CURRENT_DB_VERSION to N+1. No bootstrap change is required.
--
local migrations = {}

--- The step table, a test seam: tests/test_migrations.lua replaces a step in a
--- freshly loaded instance to prove the runner's stamp ownership. Nothing in the
--- addon reads it.
Database.__migrations = migrations

--- Every profile in the account, active or not.
---
--- Real AceDB-3.0 exposes the raw SavedVariables table as `db.sv`, and a
--- migration has to reach `sv.profiles` rather than `db.profile`: a profile the
--- player has not activated this session is still THEIR profile, and lifting only
--- the active one leaves the others to surprise them on the next swap — after
--- schemaVersion has already been stamped forward, so the step never runs again.
---
--- Falls back to the active profile alone where `db.sv` is absent, which is the
--- degraded case rather than the normal one.
---
--- @param db table
--- @return table  array of profile tables
local function allProfiles(db)
    local sv = db.sv
    if type(sv) == "table" and type(sv.profiles) == "table" then
        local out = {}
        for _, profile in pairs(sv.profiles) do
            if type(profile) == "table" then out[#out + 1] = profile end
        end
        return out
    end
    return type(db.profile) == "table" and { db.profile } or {}
end

--- Stamp Const.COLUMN_WIDTH onto every column entry of one window.
---
--- A non-table entry in a hand-edited `columns` array is stepped over rather
--- than replaced, and nothing but `col.width` is written: the rest of a column
--- is the player's.
local function v2SetUniformColumnWidths(columns)
    local Const = NS.Constants
    for _, col in ipairs(columns) do
        if type(col) == "table" then col.width = Const.COLUMN_WIDTH end
    end
end

--- Widen one window's frame to the width its own grid now needs.
---
--- WIDENED, NEVER NARROWED: a player who had already dragged their window wider
--- than the grid needs keeps that. The `type(width) ~= "number"` arm is not
--- redundant with the `<` -- a frame carrying no numeric width at all has
--- nothing to compare, and must still be given one.
---
--- `columnCount` is the RAW array length of that window's columns, junk entries
--- included, and the padding counted on both edges is the window's OWN. Both
--- are per window: hoisting either out of the caller's loop sizes every frame
--- for whichever window happened to be first.
local function v2WidenFrameForGrid(frame, columnCount, defaultPad)
    if type(frame) ~= "table" then return end
    local Const = NS.Constants
    local pad = frame.padding or defaultPad
    local needed = Const.NAME_COLUMN_WIDTH
        + columnCount * (Const.COLUMN_WIDTH + Const.COLUMN_GAP)
        + pad * 2
    if type(frame.width) ~= "number" or frame.width < needed then
        frame.width = needed
    end
end

--- v1 -> v2: ONE UNIFORM COLUMN WIDTH.
---
--- Widths are written into a window when it is CREATED (defaults/Profile.lua),
--- not read live from the catalog, so moving every stat's defaultWidth to
--- Const.COLUMN_WIDTH would have changed nothing for a window that already
--- existed. This is the step that reaches them.
---
--- IT DISCARDS A HAND-TUNED WIDTH, deliberately and once. That is the feature
--- being asked for — "make the columns the same width" is not satisfiable while
--- honoring per-column widths a previous version chose — and per-column width
--- remains a setting afterwards, so anything deliberate can be set again.
---
--- The frame is only ever WIDENED, never narrowed: a player who had already
--- dragged their window wider than the grid needs keeps that, while one still at
--- the old 480 default gets a frame that actually holds the new grid instead of
--- clipping its rightmost column.
migrations[1] = function(db)
    local template = NS.WINDOW_TEMPLATE or {}
    local defaultPad = ((template.frame or {}).padding) or 6

    for _, profile in ipairs(allProfiles(db)) do
        for _, w in ipairs(type(profile.windows) == "table" and profile.windows or {}) do
            local columns = type(w.columns) == "table" and w.columns or {}
            v2SetUniformColumnWidths(columns)
            v2WidenFrameForGrid(w.frame, #columns, defaultPad)
        end
    end
end

--- v2 -> v3: the three row-icon toggles collapse into one.
---
--- `icons.showClass` / `showSpec` / `showRole` become a single `icons.showIcon`,
--- and the slot decides for itself which icon to draw (modules/Row.lua's
--- drawUnitIcon: spec where it is known, class where it is not, never a role).
---
--- ANY of the three counts as "on". Somebody running the role icon alone had
--- asked for AN icon, and reading only `showClass` would take it away from them
--- without asking — the new slot answers the same question better rather than
--- withdrawing the answer.
---
--- The old keys are REMOVED rather than left to rot. AceDB merges defaults into
--- a stored profile but never prunes what the defaults stopped naming, so three
--- dead booleans would sit in every saved profile forever, and the next reader
--- of the file would have to work out which of the four keys the code honors.
migrations[2] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        for _, w in ipairs(type(profile.windows) == "table" and profile.windows or {}) do
            local icons = w.icons
            if type(icons) == "table" then
                if icons.showIcon == nil then
                    icons.showIcon = (icons.showClass or icons.showSpec or icons.showRole)
                        and true or false
                end
                icons.showClass, icons.showSpec, icons.showRole = nil, nil, nil
            end
        end
    end
end

--- v3 -> v4: THE "AUTO" EXPORT CHANNEL IS RETIRED.
---
--- It resolved itself at send time — instance chat, then raid, then party, then
--- say — and the objection to it is not that the ladder was wrong. It is that a
--- player pressing "Print to Chat" is choosing an AUDIENCE, and a row that picks
--- the audience for them makes the one fact they need to be sure of the one fact
--- the dialog does not state. core/Constants.lua no longer offers the row.
---
--- A profile still holding the key would otherwise reach SendChatMessage with a
--- chat type of "AUTO", which is not one, so it folds to SELF — the shipped
--- default, and the only landing that cannot put a ranking somewhere the player
--- did not ask for. modules/Export.lua's ResolveChannel names the retired key as
--- well, for a profile that arrives from a copy or a hand edit after this ran.
migrations[3] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        local export = profile.export
        if type(export) == "table" and export.channel == "AUTO" then
            export.channel = "SELF"
        end
    end
end

-- The two keys v5 moves off the window and onto the profile. Built once here at
-- file scope, and shared by the lift and the prune below so the two halves
-- cannot name different keys.
local V5_LIFTED_KEYS = { "mergePets", "throttle" }

--- The data block v5 lifts FROM: window ONE's, or nil.
---
--- `windows[1]` only — not "the first window with an opinion". A first window
--- with no usable `data` lifts nothing even when a later window carries values,
--- because "the first window is the one at the top of their own picker" is the
--- whole rule; a scan for an opinion would hand it to whichever window shouted
--- loudest instead.
local function v5FirstWindowData(windows)
    local first = windows[1]
    if type(first) ~= "table" or type(first.data) ~= "table" then return nil end
    return first.data
end

--- Move whichever of the lifted keys that window actually carried onto the
--- profile, each key on its own.
---
--- `~= nil`, NEVER truthiness: a stored `mergePets = false` and a stored
--- `throttle = 0` are choices a player made, and truthiness would discard both.
--- The profile's own data table is reused when it has one and CREATED when it
--- does not, so a profile that never had the address still gets the value.
local function v5LiftWindowData(profile, data)
    local lifted
    for _, key in ipairs(V5_LIFTED_KEYS) do
        if data[key] ~= nil then
            lifted = lifted or (type(profile.data) == "table" and profile.data or {})
            lifted[key] = data[key]
        end
    end
    if lifted then profile.data = lifted end
end

--- Remove the lifted keys from EVERY window of one profile.
---
--- AceDB merges defaults in and never prunes what the defaults stopped naming,
--- so leaving them would put a stale `throttle` in every saved window forever,
--- next to the live one, with nothing to say which the addon honors.
local function v5PruneWindowData(windows)
    for _, w in ipairs(windows) do
        if type(w) == "table" and type(w.data) == "table" then
            for _, key in ipairs(V5_LIFTED_KEYS) do w.data[key] = nil end
        end
    end
end

--- v4 -> v5: `mergePets` AND `throttle` BECOME ADDON-WIDE.
---
--- Neither was ever a property of a window. `mergePets` says what a pet's damage
--- IS — one row or its owner's — and `throttle` is how often the addon redraws.
--- Two windows on one screen disagreeing about either is two answers to one
--- question, and the settings tree was the only thing asking it twice.
---
--- THE FIRST WINDOW'S VALUES WIN, per profile. There is no merge rule that is
--- right for a player who set two windows differently, and the alternatives are
--- worse than arbitrary: taking the shipped default would discard a deliberate
--- choice from every profile that made one, and taking "any window that differs
--- from the default" would let a window the player had forgotten about outvote
--- the one they use. The first window is the one at the top of their own picker.
---
--- The per-window keys are then REMOVED. AceDB merges defaults in and never
--- prunes what the defaults stopped naming, so leaving them would put a stale
--- `throttle` in every saved window forever, next to the live one, with nothing
--- to say which the addon honors.
migrations[4] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        local windows = type(profile.windows) == "table" and profile.windows or {}

        -- THE WINDOW'S VALUE WINS OUTRIGHT, and the `== nil` rule that governs
        -- EnsureWindowShape deliberately does not apply here. AceDB's defaults
        -- merge has already run by the time a migration does, so `profile.data`
        -- is never nil to test — it is sitting there filled with the shipped
        -- values, and "already set" cannot be told from "just merged in". Before
        -- this step the profile-level key did not exist and nothing read it, so
        -- there is no player intent to preserve at that address and every
        -- intent to preserve at the window's.
        local data = v5FirstWindowData(windows)
        if data then v5LiftWindowData(profile, data) end

        -- The prune sits OUTSIDE the lift: it runs whether or not window one
        -- had anything to give.
        v5PruneWindowData(windows)
    end
end

--- v5 -> v6: THE TWO DEAD ROW-BACKGROUND KEYS ARE PRUNED.
---
--- `rows.classBackground` and `rows.classBackgroundAlpha` were settings-panel
--- rows pointing at keys NOTHING READ. The row tint is painted per cell from
--- `bars.bgColorMode` and `bars.bgAlpha` (modules/Row.lua's cellBackground) --
--- it moved there when tinting the row itself turned out to tint the two-pixel
--- seams between the columns and lose the separators the grid is read by -- and
--- these two were left behind, answering a question already answered one page
--- over, into a void.
---
--- Removed rather than left to rot, for the reason the v2 -> v3 icon step gives:
--- AceDB merges defaults into a stored profile and never prunes what the defaults
--- stopped naming, so without this they sit in every saved window forever and the
--- next reader has to work out which of two keys the code honors. Neither had a
--- reader, which is exactly why nobody would guess.
migrations[5] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        for _, w in ipairs(type(profile.windows) == "table" and profile.windows or {}) do
            local rows = type(w) == "table" and w.rows
            if type(rows) == "table" then
                rows.classBackground, rows.classBackgroundAlpha = nil, nil
            end
        end
    end
end

--- v6 -> v7: FOUR CLASS-COLOR BOOLEANS BECOME COLOR MODES.
---
--- Every text surface -- the cells, the title bar, the column labels and the
--- tooltip -- carried a `classColor` checkbox, which could only ever answer two
--- thirds of the question a player was asking: class, the statistic's own color,
--- or the one they picked. `colorMode` answers all three, and the two header
--- BACKGROUNDS gained the same three, which they had none of before.
---
--- `true` becomes "class" and `false` becomes "custom", which is exactly what the
--- boolean meant. The key is REMOVED afterwards for the reason the v2 -> v3 icon
--- step gives: AceDB merges defaults in and never prunes what they stopped
--- naming, so a stale `classColor` would sit beside the live `colorMode` in every
--- saved profile with nothing to say which the addon honors.
---
--- The tooltip's key is in the same group as its `fontOutline` and `fontShadow`
--- siblings rather than under `text`, which is why this walks a list of GROUPS
--- rather than assuming one shape.
migrations[6] = function(db)
    local GROUPS = { "text", "header", "columnHeader", "tooltip" }

    for _, profile in ipairs(allProfiles(db)) do
        for _, w in ipairs(type(profile.windows) == "table" and profile.windows or {}) do
            for _, key in ipairs(GROUPS) do
                local group = type(w) == "table" and w[key]
                if type(group) == "table" and group.classColor ~= nil then
                    if group.colorMode == nil then
                        group.colorMode = group.classColor and "class" or "custom"
                    end
                    group.classColor = nil
                end
            end
        end
    end
end

--- v7 -> v8: THE HEADER'S FOUR REDUNDANT KEYS ARE PRUNED.
---
--- `title`, `showSessionName`, `showDuration` and `showTotals` each said
--- something already on screen: a second name for a window that has one,
--- "Overall" beside a window the player called Overall, the length of a segment
--- the header's own picker names, and a group total over a column holding the
--- same figure per player. The header draws `window.name` now.
---
--- A TITLE THE PLAYER ACTUALLY TYPED IS NOT DISCARDED -- it becomes the window's
--- NAME. That is what they were doing with it: naming the window, in the only box
--- that changed what the header said. Dropping it would silently rename their
--- windows back, which is the one outcome this step must not have.
---
--- The name is only taken where the window has not been named itself: a player
--- who set both meant the one in the picker, since that is the one every other
--- surface already used.
migrations[7] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        for _, w in ipairs(type(profile.windows) == "table" and profile.windows or {}) do
            local header = type(w) == "table" and w.header
            if type(header) == "table" then
                local title = header.title
                if type(title) == "string" and title ~= ""
                    and (w.name == nil or w.name == "") then
                    w.name = title
                end
                header.title = nil
                header.showSessionName = nil
                header.showDuration = nil
                header.showTotals = nil
            end
        end
    end
end

--- v8 -> v9: THE TITLE BAR'S BACKGROUND LOSES ITS COLOR MODE.
---
--- `header.bgColorMode` and `columnHeader.bgColorMode` looked like a matched pair
--- and are not. The column strip labels the COLUMNS, so "per statistic" tints
--- each label with its own column's color and means something. The title bar is
--- ONE strip over the whole window, so the same mode could only ever paint it one
--- color -- the sort column's -- which is a fact already on screen twice over.
--- It keeps its color picker, which is what the setting was before the mode was
--- added to it.
---
--- Pruned rather than left, for the reason every step here gives: AceDB merges
--- defaults in and never removes what they stopped naming.
migrations[8] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        for _, w in ipairs(type(profile.windows) == "table" and profile.windows or {}) do
            local header = type(w) == "table" and w.header
            if type(header) == "table" then header.bgColorMode = nil end
        end
    end
end

--- v9 -> v10: THE "At cursor" TOOLTIP ANCHOR IS RETIRED.
---
--- It was the shipped default and it is what every other tooltip in the game
--- does, which is exactly what was wrong with it here: over a GRID it lands
--- wherever the pointer happens to be inside a cell, so the same hover puts the
--- tooltip somewhere different every time and reads as jitter rather than as a
--- choice. TOP is the deliberate version of the same thing -- above the cell, in
--- one place -- and is the default now.
---
--- A stored "CURSOR" becomes "TOP" rather than being left to the reader's
--- fallback, so the value in the profile is the value the dropdown shows.
migrations[9] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        for _, w in ipairs(type(profile.windows) == "table" and profile.windows or {}) do
            local tooltip = type(w) == "table" and w.tooltip
            if type(tooltip) == "table" and tooltip.anchor == "CURSOR" then
                tooltip.anchor = "TOP"
            end
        end
    end
end

--- v10 -> v11: THE TITLE BAR'S TEXT LOSES ITS THREE-MODE COLOR SETTING.
---
--- WHAT THIS STEP CLEARED, AND WHY IT STILL RUNS. At the time it removed the row
--- outright: the title bar is ONE strip over the whole window, and neither mode
--- it offered was thought to say anything true about it.
---
--- `window.header.colorMode` EXISTS AGAIN, and half of that argument was later
--- overturned -- `class` is back, because the controls and the divider on the same
--- strip both wear one and a title that alone could not was the odd one out. See
--- settings/Schema.lua's Title text note. The other half stands: there is still no
--- `stat`, for the reason above.
---
--- SO THIS STEP IS NOT A HISTORICAL NO-OP, and it must not be retired into one. A
--- profile below v11 can be holding `colorMode = "stat"`, which the two-mode row
--- does not accept and no reader would resolve; clearing it lets the shipped
--- default (`custom`) fill in, which is the same answer that profile has been
--- rendering since v10 anyway. A profile holding `"class"` loses it and reverts to
--- the picker -- deliberate, and not worth a guess: the key was genuinely dead for
--- the releases in between, and re-deriving intent from a value nothing read is
--- how a migration invents a preference nobody expressed.
---
--- Pruned rather than left, for the reason every step here gives: AceDB merges
--- defaults in and never removes what they stopped naming, so a field nobody
--- prunes is a field that outlives its reader.
migrations[10] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        for _, w in ipairs(type(profile.windows) == "table" and profile.windows or {}) do
            local header = type(w) == "table" and w.header
            if type(header) == "table" then header.colorMode = nil end
        end
    end
end

--- v11 -> v12: THE COLUMN ARRAY BECOMES THE CATALOG.
---
--- `window.columns` was the columns the player had CHOSEN; it is now every
--- statistic this build offers, in their order, each carrying `enabled`. The page
--- that reads it is a fixed list of blocks you tick and drag rather than a list
--- you add to and remove from, and a page that cannot add a column needs every
--- column already present to tick.
---
--- `width` and `showBar` are pruned rather than left. Width has been dead since
--- the window began auto-sizing -- BuildLayout divides the frame width evenly
--- across the visible columns and has never read `col.width` -- and the bar is
--- unconditional now. AceDB merges defaults in and never removes what they
--- stopped naming, so a field nobody prunes is a field that outlives its reader.
---
--- IT GOES THROUGH NS.NormalizeColumns RATHER THAN RESTATING THE RULE. That
--- function is settings/Schema.lua's, which loads eighteen TOC entries after this
--- file -- but the ladder RUNS on Init, long after every file is in memory, which
--- is the same deferred read `migrations[1]` already makes for NS.WINDOW_TEMPLATE.
--- A private copy of "what shape is a column array" here is how the migration and
--- the write seam end up disagreeing about it.
migrations[11] = function(db)
    local normalize = NS.NormalizeColumns

    for _, profile in ipairs(allProfiles(db)) do
        for _, w in ipairs(type(profile.windows) == "table" and profile.windows or {}) do
            if type(w) == "table" and type(w.columns) == "table" then
                -- Every stored column was a column the player was SHOWN, so every
                -- one of them arrives enabled. The normalizer appends the rest
                -- disabled and drops anything this build no longer has.
                local carried = {}
                for _, col in ipairs(w.columns) do
                    if type(col) == "table" and type(col.stat) == "string" then
                        carried[#carried + 1] = { stat = col.stat, enabled = true }
                    end
                end

                -- The refusal case is a profile whose every column named a
                -- statistic this build dropped, which leaves nothing enabled and
                -- no way to guess what they meant. The shipped list is the only
                -- honest answer, and it is what a new window would have had.
                w.columns = (normalize and normalize(carried))
                    or (NS.DefaultWindow and NS.DefaultWindow(w.id).columns)
                    or w.columns
            end
        end
    end
end

-- v13's two control-color pairs: the stored boolean, and the mode key it
-- becomes. File scope, built once — never rebuilt per window.
local V13_CONTROL_COLOR_KEYS = {
    { flag = "controlClassColor",      mode = "controlColorMode"      },
    { flag = "controlHoverClassColor", mode = "controlHoverColorMode" },
}

--- Move the title-bar toggle off the frame and onto the header block.
---
--- An ABSENT `frame.titleBar` is left absent, because absent means "never
--- changed from the default" — writing one here would freeze today's default
--- into every stored profile and the default could never move again.
---
--- The header block is MUTATED IN PLACE, never replaced: the fonts, colors and
--- heights already stored on it must survive. A present `titleBar` OVERWRITES
--- whatever `header.show` held, since it is the value the player last set.
local function v13MoveTitleBarToHeader(w, frame)
    if frame.titleBar == nil then return end
    if type(w.header) ~= "table" then w.header = {} end
    w.header.show = frame.titleBar
    frame.titleBar = nil
end

--- Turn the two control class-color booleans into mode strings: `true` ->
--- "class", `false` -> "custom", which is what `false` already meant. Mapping
--- it to nil instead would leave the row reading the schema default, the same
--- value today but not necessarily tomorrow.
---
--- Each pair is read and written on its own, and there is deliberately NO
--- `== nil` guard on the mode being written: an existing
--- `controlColorMode` / `controlHoverColorMode` is OVERWRITTEN here. That is
--- what makes this step different from migrations[6], and why the two must not
--- be folded into one shared boolean-to-mode helper.
local function v13LiftControlColorModes(frame)
    for _, pair in ipairs(V13_CONTROL_COLOR_KEYS) do
        if frame[pair.flag] ~= nil then
            frame[pair.mode] = frame[pair.flag] and "class" or "custom"
            frame[pair.flag] = nil
        end
    end
end

--- v12 -> v13: THE TITLE-BAR TOGGLE MOVES ONTO THE HEADER, AND THE HEADER CONTROLS' TWO
--- CLASS-COLOR FLAGS BECOME MODES.
---
--- `Show title bar` was on the Frame page, under "Frame behavior", switching a surface the
--- Header page owns -- so it sat three clicks from every control that styles the thing it turns
--- off. The control moved with the settings redesign; the PATH moved with it, because a row on
--- the Header page whose path says `frame` misleads the next reader of the schema and reads
--- wrong in `/mm set window.frame.titleBar`.
---
--- Carried across rather than defaulted: a player who turned their title bar off must not log
--- in to it back on. An ABSENT key is left absent, because absent means "never changed from the
--- default" -- writing one here would freeze today's default into every stored profile and the
--- default could never move again.
---
--- The two `controlClassColor` / `controlHoverClassColor` booleans get the same redesign every
--- other colorable surface already has: a mode dropdown. A stored `true` becomes "class"; a
--- stored `false` becomes "custom", which is what it already meant -- mapping it to nil instead
--- would leave the row reading the schema default, which happens to be the same value today but
--- need not be tomorrow.
---
--- Pruned rather than left, for the reason every step here gives: AceDB merges defaults in and
--- never removes what they stopped naming, so a field nobody prunes outlives its reader.
migrations[12] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        for _, w in ipairs(type(profile.windows) == "table" and profile.windows or {}) do
            local frame = type(w) == "table" and w.frame
            if type(frame) == "table" then
                v13MoveTitleBarToHeader(w, frame)
                v13LiftControlColorModes(frame)
            end
        end
    end
end

--- Lock every window of one profile, through the lock each window owns.
---
--- A non-table entry in a hand-edited `windows` array is stepped over. A window
--- with no frame block gets one holding just the lock: EnsureWindowShape fills
--- the rest from the template after the walk, and never over a key already set.
local function v14LockEveryWindow(windows)
    for _, w in ipairs(windows) do
        if type(w) == "table" then
            if type(w.frame) ~= "table" then w.frame = {} end
            w.frame.locked = true
        end
    end
end

--- v13 -> v14: THE ADDON-WIDE LOCK BECOMES EVERY WINDOW'S OWN.
---
--- General > Master controls' Lock frame was `master.locked`, a second lock ORed
--- over every window's `frame.locked`. `/mm lock` writes the windows' own, so
--- after it the box could neither unlock a window nor visibly lock one. The box is
--- now a session-only view over the windows' own locks (settings/Schema_Compose.lua)
--- and `master.locked` has no reader.
---
--- A TICKED MASTER LOCK IS CARRIED, NOT DROPPED. It had every window of that
--- profile pinned, and the player must not log in to every window loose, so a
--- stored `true` locks every window -- which is what they were looking at. A
--- `false` or absent one pinned nothing, and each window keeps the lock it had.
---
--- The key is then pruned in every case, for the reason every step here gives:
--- AceDB merges defaults in and never removes what they stopped naming.
migrations[13] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        local master = profile.master
        if type(master) == "table" then
            if master.locked == true and type(profile.windows) == "table" then
                v14LockEveryWindow(profile.windows)
            end
            master.locked = nil
        end
    end
end

--- The `minimap` table a profile still carries, preferring the ACTIVE one.
---
--- There is one button per installation and there may be many profiles, so the move has to pick,
--- and the active profile is the only defensible pick: it is the one whose button the player was
--- looking at when they last dragged or hid it. A profile the player has not activated this
--- session is still theirs, though, so an inactive one is taken when the active profile has no
--- table at all -- which is what a fresh profile created after the button was placed looks like.
---
--- FIRST NON-EMPTY WINS among the inactive ones. Their order is `pairs` over the savedvariables,
--- which is not stable, and that is acceptable precisely because the active profile is tried
--- first: the arbitrary choice is only ever between profiles the player is not using.
---
--- @param db table
--- @return table|nil
local function v15SourceMinimap(db)
    local active = db.profile
    if type(active) == "table" and type(active.minimap) == "table" then
        return active.minimap
    end
    for _, profile in ipairs(allProfiles(db)) do
        if type(profile.minimap) == "table" and next(profile.minimap) ~= nil then
            return profile.minimap
        end
    end
    return nil
end

--- v14 -> v15: THE MINIMAP TABLE MOVES FROM THE PROFILE TO THE GLOBAL STORE.
---
--- `launcher-§3` fixes LibDBIcon's own `minimap` table at `db.global.minimap`, and this addon was
--- the collection's one outlier -- Bank Ledger and Loot History already stored it globally. The
--- scope is the rule's point rather than tidiness: a minimap button belongs to the INSTALLATION,
--- so a profile switch must not move the player's buttons. That no RESET may move them either is a
--- separate property of the setting, not a consequence of this move, and settings/OptionsSetup.lua
--- is where it is enforced -- including for the page Defaults button the scope never reached.
---
--- IT CARRIES BOTH KEYS, and neither may be stranded. `hide` is the player's own answer to a
--- checkbox; `minimapPos` is the ANGLE they dragged the button to, written by LibDBIcon itself,
--- and dropping it would put an adopted button back at the library's default position -- a silent
--- loss that looks like the adoption broke something. The whole table is copied rather than three
--- named keys, because its shape is the library's: it may also hold a free-position pair for a
--- button dragged off the minimap, and enumerating what we think it contains is exactly what
--- defaults/Profile.lua warns against.
---
--- NOTHING ALREADY GLOBAL IS OVERWRITTEN. AceDB's defaults merge materializes
--- `db.global.minimap = { hide = false }` the moment `db.global` is first touched, so "already
--- there" cannot be tested with `== nil`; what it is tested against is whether the global table
--- says anything a default does not -- a `hide` of true, or any position key. An account that has
--- already adopted keeps what it has.
---
--- The profile keys are then pruned in every case, for the reason every step here gives: AceDB
--- merges defaults in and never removes what they stopped naming, so a `minimap` left under
--- `profile` would sit in the savedvariables for good, writable by nothing and readable by a
--- reader who would reasonably believe it.
migrations[14] = function(db)
    local global = db.global
    if type(global.minimap) ~= "table" then global.minimap = {} end

    local placed = global.minimap.hide == true
    if not placed then
        for key in pairs(global.minimap) do
            if key ~= "hide" then placed = true break end
        end
    end

    if not placed then
        local source = v15SourceMinimap(db)
        if source then
            for key, value in pairs(source) do
                global.minimap[key] = copy(value)
            end
        end
    end

    for _, profile in ipairs(allProfiles(db)) do
        profile.minimap = nil
    end
end

--- The two stored frame keys v16 renames, old spelling -> US spelling.
---
--- The old names are the player's SavedVariables, matched verbatim off disk: the
--- step has to spell them the way the file on disk does or it reads nothing
--- (localization-§5, waived per file and word in tests/prose_waivers.lua).
local V16_FRAME_KEYS = {
    { from = "minimised",    to = "minimized" },
    { from = "showMinimise", to = "showMinimize" },
}

--- Move one window frame's keys onto their US spelling.
---
--- A US key already present WINS: it is the one the addon has been reading, so an
--- old key beside it is a leftover, dropped rather than copied over it.
local function v16RenameFrameKeys(frame)
    if type(frame) ~= "table" then return end
    for _, key in ipairs(V16_FRAME_KEYS) do
        if frame[key.to] == nil then frame[key.to] = frame[key.from] end
        frame[key.from] = nil
    end
end

--- v15 -> v16: THE WINDOW'S MINIMIZE KEYS, SPELLED THE US WAY.
---
--- `window.frame.minimized` (the collapsed state the header's control writes) and
--- `window.frame.showMinimize` (whether that control is drawn) were stored under
--- their British spelling. Renaming only the defaults would orphan every stored
--- value: a collapsed window would come back open and a hidden control would come
--- back drawn, while the old keys sat in the file read by nothing.
---
--- Every window of every profile, for the reason allProfiles gives. Idempotent: a
--- frame with no old key is left exactly as it was.
migrations[15] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        if type(profile.windows) == "table" then
            for _, w in pairs(profile.windows) do
                if type(w) == "table" then v16RenameFrameKeys(w.frame) end
            end
        end
    end
end

--- True when a stored color is exactly the old shipped white control color.
local function v17IsOldControlColor(c)
    return type(c) == "table" and c.r == 1 and c.g == 1 and c.b == 1 and c.a == 1
end

--- Move one window's header and control keys off the values every window shipped with before
--- 2026-10-24, and ONLY those: a value equal to the old default is rewritten, and any other value
--- is the player's choice and is left alone. The outline and shadow move as a pair, since an
--- outline kept beside a shadow that was turned on was chosen. The control color moves only in
--- "custom" mode, the one mode that draws it.
local function v17MatchHeader(w)
    local header, frame = w.header, w.frame
    if type(header) == "table" and header.outline == "OUTLINE" and header.shadow == false then
        header.outline, header.shadow = "NONE", true
    end
    if type(frame) ~= "table" then return end
    if frame.controlColorMode == "custom" and v17IsOldControlColor(frame.controlColor) then
        frame.controlColor = { r = 0.7, g = 0.7, b = 0.72, a = 1 }
    end
    if frame.hoverReveal == true then frame.hoverReveal = false end
    if frame.controlSize == 16 then frame.controlSize = 18 end
end

--- v16 -> v17: THE HEADER MATCHED TO KA0S DPS RACE'S TITLE BAR.
---
--- defaults/Profile.lua's WINDOW_TEMPLATE changed four groups of values (an unoutlined, shadowed
--- title; gray controls at full strength; an 18px slot). Changing the template alone reaches only
--- windows created afterwards: AceDB's defaults cannot reach inside the windows array, and
--- fillMissing copied the whole old template into every stored window, so each one holds the old
--- values verbatim. A stored old value cannot be told apart from a deliberate choice of it; the
--- step takes it for the shipped default, which is what nearly every one of them is.
---
--- Every window of every profile, for the reason allProfiles gives. Idempotent: no value the step
--- writes is one it rewrites.
migrations[16] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        if type(profile.windows) == "table" then
            for _, w in pairs(profile.windows) do
                if type(w) == "table" then v17MatchHeader(w) end
            end
        end
    end
end

--- v17 -> v18: THE TITLE BAR GROWN TO KA0S DPS RACE'S 30PX.
---
--- `header.height` shipped 18 (6 padding + 18 - 2 = a 22px bar to the divider) and ships 26 now
--- (30px, DPS Race's `Style.TITLE_BAR_H`). A separate step rather than an edit to migrations[16]:
--- that step has already run on accounts that tried the v17 build, and a step that has run is
--- never rewritten. Same rule as v17: only a stored 18, the old shipped value, moves; any other
--- height is the player's and is left alone, and a stored 18 cannot be told apart from a chosen 18.
---
--- Every window of every profile, for the reason allProfiles gives. Idempotent: 26 is not 18.
migrations[17] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        if type(profile.windows) == "table" then
            for _, w in pairs(profile.windows) do
                if type(w) == "table" and type(w.header) == "table" and w.header.height == 18 then
                    w.header.height = 26
                end
            end
        end
    end
end

--- v18 -> v19: THE SHIPPED WINDOW GROWN BACK TO TEN ROWS.
---
--- `frame.height` shipped 220, which fitted ten rows under the 22px bar and nine under v18's 30px
--- one. It ships 228 now, which fits ten again with the 5px of slack 220 had: 228 - 2 * 6 padding - 26 title -
--- 16 labels = 174, and floor((174 + 1) / 17) = 10, with 5px spare. fillMissing copied the old template
--- into every stored window, so each one holds 220 verbatim. Same rule as v17 and v18: only a
--- stored 220, the old shipped value, moves; any other height is the player's and is left alone,
--- and a stored 220 cannot be told apart from a chosen 220.
---
--- Every window of every profile, for the reason allProfiles gives. Idempotent: 228 is not 220.
migrations[18] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        if type(profile.windows) == "table" then
            for _, w in pairs(profile.windows) do
                if type(w) == "table" and type(w.frame) == "table" and w.frame.height == 220 then
                    w.frame.height = 228
                end
            end
        end
    end
end

--- The eight "Use the skin's ..." companions of a window (skinning-§6), as dotted paths into it:
--- the four faces, the two bar textures and the two bar border styles, each beside the pick it
--- governs (defaults/Profile.lua, settings/Schema_Compose.lua's FROM_SKIN_ROWS). The v20 step's
--- list, and tests/test_skin_hud.lua's.
Database.FROM_SKIN_KEYS = {
    "header.fontFromSkin", "columnHeader.fontFromSkin", "text.fontFromSkin", "tooltip.fontFromSkin",
    "bars.textureFromSkin", "tooltip.barTextureFromSkin",
    "bars.borderStyleFromSkin", "tooltip.barBorderStyleFromSkin",
}

--- One window's companions put back on the skin. The list names each companion itself
--- (`header.fontFromSkin`), and LibKa0s-Skin-1.0's ResetToSkin sets a listed `*FromSkin` key to
--- true whether or not it is stored (Skin minor 8, the skin library follow-ups' LK-07), so a stored
--- group that lacks one (every window stored before v20 does) needs no seeding first; a group that
--- is absent altogether is left to EnsureWindowShape, whose template says true already. Without the
--- library the companions are set directly: they mean nothing until it loads, and then they must
--- already say "follow".
local function v20FollowSkin(w, resetToSkin)
    local keys = {}
    for _, path in ipairs(Database.FROM_SKIN_KEYS) do
        local group, leaf = path:match("^([^.]+)%.(.+)$")
        local g = w[group]
        if type(g) == "table" then
            if resetToSkin then keys[#keys + 1] = path else g[leaf] = true end
        end
    end
    if resetToSkin and #keys > 0 then resetToSkin(w, keys) end
end

--- v19 -> v20: THE HUD BACK ON THE SKIN, ONCE (skinning-§6, the owner's ruling O2).
---
--- Every window's four faces, two bar textures and two bar border styles follow the skin again,
--- for every player: each window's companions are set on through Skin.ResetToSkin, ONE CALL PER
--- WINDOW, because its dotted walk cannot reach into the numeric `windows` array. The stored picks
--- are kept (a companion turned off brings them back) and no color, size, outline or thickness is
--- touched (DECISIONS X4, D12). The account-wide stamp is what makes it once: a player who unticks
--- a companion afterwards keeps that pick, because this step never runs again.
---
--- Every window of every profile, for the reason allProfiles gives. Idempotent: true stays true.
migrations[19] = function(db)
    local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)
    local resetToSkin = Skin and type(Skin.ResetToSkin) == "function" and Skin.ResetToSkin or nil
    for _, profile in ipairs(allProfiles(db)) do
        if type(profile.windows) == "table" then
            for _, w in pairs(profile.windows) do
                if type(w) == "table" then v20FollowSkin(w, resetToSkin) end
            end
        end
    end
end

--- The window chrome's five `skin` color modes (MM-A1, DECISIONS D1, D4, D16), as dotted paths
--- into a window: the fill, the edge, the title, the controls at rest and under the pointer. The
--- v21 step's list, and tests/test_skin_window.lua's.
Database.CHROME_SKIN_MODES = {
    "frame.backdropColorMode", "frame.borderColorMode", "header.colorMode",
    "frame.controlColorMode", "frame.controlHoverColorMode",
}

--- v20 -> v21: THE WINDOW'S CHROME ON THE SKIN, ONCE (the owner's ruling R-3, which overrules
--- DECISIONS X4 for the meter window; O2's one-time reset carried over to it).
---
--- Every window's five chrome modes go to `skin`, whatever they were (`custom` or `class`), and the
--- title bar's `header.bgColorFromSkin` companion on (D3). Set directly: a mode is a string the
--- library's ResetToSkin knows nothing of, and the companion is a plain bool. The stored colors,
--- the edge style and its thickness are kept, so a mode set back to Custom draws them again. A
--- group absent from a stored window is left to EnsureWindowShape, whose template ships the same.
--- The account-wide stamp is what makes it once: a pick made after it is kept.
migrations[20] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        if type(profile.windows) == "table" then
            for _, w in pairs(profile.windows) do
                if type(w) == "table" then
                    for _, path in ipairs(Database.CHROME_SKIN_MODES) do
                        local group, leaf = path:match("^([^.]+)%.(.+)$")
                        if type(w[group]) == "table" then w[group][leaf] = "skin" end
                    end
                    if type(w.header) == "table" then w.header.bgColorFromSkin = true end
                end
            end
        end
    end
end

--- A window's five font flags with the default each shipped before v22 (LibKa0s v1.82.0, ruling
--- D-07): the four surfaces' own and the all-surfaces meta. The v22 step's list.
Database.FONT_FLAG_DEFAULTS_V21 = {
    { "header", "outline", "NONE" }, { "columnHeader", "outline", "OUTLINE" },
    { "text", "outline", "NONE" }, { "tooltip", "fontOutline", "NONE" },
    { false, "fontOutline", "NONE" },
}

--- v21 -> v22: THE FONT FLAGS ON FROM SKIN, ONCE (ruling D-07; the run's Addendum 01).
---
--- Every flags row now leads with From skin ("@skin"), its default, which the Skin tab's Font
--- outline answers. A window stores its whole config (it is an array entry, never an AceDB
--- default), so every window stored before v22 holds the old default explicitly. A flag still
--- equal to the default it shipped moves to From skin; one the player changed (any other value)
--- stays. Every window of every profile, so the move is per profile; the account-wide stamp makes
--- it once, so a NONE picked after it is kept. A group that is not a table is left to
--- EnsureWindowShape, whose template ships From skin already. `false` as the group is the window.
migrations[21] = function(db)
    for _, profile in ipairs(allProfiles(db)) do
        if type(profile.windows) == "table" then
            for _, w in pairs(profile.windows) do
                if type(w) == "table" then
                    for _, d in ipairs(Database.FONT_FLAG_DEFAULTS_V21) do
                        local t = d[1] and w[d[1]] or w
                        if type(t) == "table" and t[d[2]] == d[3] then t[d[2]] = "@skin" end
                    end
                end
            end
        end
    end
end

--- Walk the account forward to CURRENT_DB_VERSION. Runs on Init and on every
--- profile swap, and is a no-op once at the current version.
function NS:RunMigrations()
    local db = NS.db
    if not (db and db.global) then return end
    local g = db.global

    -- 0 (or nothing) is UNSTAMPED: a fresh install or a legacy account. v1 is
    -- the shipped shape and every step is idempotent against a fresh default
    -- profile, so both start the walk at v1.
    local v = tonumber(g.schemaVersion) or 0
    if v < 1 then v = 1 end

    while v < CURRENT_DB_VERSION do
        local step = migrations[v]
        if not step then
            -- No registered migrator for this jump. Stamp the current version
            -- rather than spinning: a real schema change would have registered
            -- its step before CURRENT_DB_VERSION moved.
            if NS.State and NS.State.debug then
                NS.Debug("Migrate", "no step registered at v%d; stamped v%d", v, CURRENT_DB_VERSION)
            end
            g.schemaVersion = CURRENT_DB_VERSION
            break
        end
        step(db)
        -- Reached only when the step returned: the runner owns the stamp.
        g.schemaVersion = v + 1
        if NS.State and NS.State.debug then
            NS.Debug("Migrate", "v%d -> v%d", v, v + 1)
        end
        v = v + 1
    end

    -- Shape normalization runs AFTER the version walk and unconditionally, so a
    -- profile that arrives from a copy or a hand edit is brought to the current
    -- window shape whatever its version claims.
    Database.SeedWindows()
end
