-- settings/Schema_Paths.lua
--
-- THE PATH MACHINERY behind settings/Schema.lua, and the seams every reader and
-- writer of a setting lands on: path resolution, window resolution, the one
-- inverted row, the index, the read seam, the write seam, the columns carve-out
-- and the page and validation surfaces.
--
-- A SEPARATE FILE because settings/Schema.lua was 3080 lines against layout-§1's
-- 1500-line cap, and this is the seam issue #27 names: nothing in this file names
-- a single setting. The array is the part that grows; this is the part that is
-- read when something is wrong.
--
-- THE WINDOW-RELATIVE PATH MODEL — the one thing that is not standard-issue
-- ---------------------------------------------------------------------------
--
-- Almost every setting in this addon is PER-WINDOW (design §6), and a window is
-- an instance the user creates at runtime. Written out absolutely, a window row's
-- path would have to be `windows.<id>.frame.width` — dynamic, unknowable when
-- this file loads, and impossible to express in the flat path model the CLI and
-- the panel both read.
--
-- Resolution (design §8): a window row's path is RELATIVE to a window and is
-- spelled `window.frame.width`. NS.GetSetting and NS.SetByPath resolve the
-- `window.` prefix against the session's ACTIVE window — NS.State.activeWindowId,
-- which the panel's window picker moves and which defaults to the first window in
-- the registry. Global rows keep absolute paths (`enabled`, `minimap.hide`),
-- resolved against db.profile.
--
-- What that buys: ONE schema, ONE write seam, and `/mm set window.frame.width 300`
-- means "the window I am editing" on the CLI exactly as it does in the panel. The
-- picker retargets 70-odd rows by moving one integer of session state instead of
-- by rewriting every path.
--
-- ---------------------------------------------------------------------------
-- WHY THE COLUMNS ARE NOT ROWS
-- ---------------------------------------------------------------------------
--
-- `window.columns` is an ORDERED ARRAY of `{ stat, width, showBar }` whose length
-- is the user's, not the schema's. A path model addresses named leaves; it has no
-- vocabulary for "insert a column before index 2". So the columns subtree is a
-- documented CARVE-OUT rather than a row: `/mm get window.columns` reads (the
-- generic resolver reaches it like any other node), and a WRITE to
-- `window.columns` is accepted WHOLE-ARRAY — settings/Columns.lua builds the array
-- it wants and hands the seam all of it, which is the only granularity a path can
-- honestly express.
--
-- The seam still owns the write. It structurally validates the array (every entry
-- names a stat this build has, exactly once, at a width the Columns page's own
-- slider can produce, with a real boolean show-bar), rebuilds it entry by entry so
-- nothing downstream shares a table with the caller, and then takes the SAME debug
-- line, CONFIG_CHANGED message and panel re-sync every scalar write takes. A
-- direct table write in the page would be a second seam that looks identical and
-- announces nothing.
--
-- What is still refused is a write to a path INSIDE the array —
-- `window.columns.2.width`. Addressing one column by ordinal is exactly the
-- vocabulary a path model does not have: the ordinal moves the moment a column is
-- added, removed or reordered, so a stored reference to it is wrong by the next
-- edit.
--
-- TOC POSITION: LAST of the three Schema files, and LOAD-BEARING: the index is
-- built from NS.Schema at FILE SCOPE, so there has to be an array to index --
-- settings/Schema_Compose.lua then settings/Schema.lua must both have run. Still
-- ahead of settings/Slash.lua and settings/OptionsSetup.lua, both of which point
-- their seams at NS.SetByPath / NS.GetSetting / NS.FindSchemaRow /
-- NS.ApplyDefault at load, and ahead of every settings/<page>.lua.
--
-- Nothing here is captured across the load boundary: NS.Helpers, NS.db,
-- NS.WindowManager and NS.Visibility are all resolved at CALL time, because this
-- file loads before all four.

local _, NS = ...

local L     = NS.L
local Const = NS.Constants
local MSG   = Const.MSG

-- ---------------------------------------------------------------------------
-- Path plumbing
-- ---------------------------------------------------------------------------

-- Split results are memoized because the set of paths is CLOSED and small — it is
-- the schema's own key set plus whatever the CLI is handed — while a panel drag
-- re-resolves one path many times a second. The cache is keyed on the path
-- string, so it can never grow beyond the paths that were actually asked for.
local splitCache = {}

--- "window.frame.width" -> { "window", "frame", "width" }, memoized.
--- @param path string
--- @return table  array of segments (shared; callers must not mutate it)
local function splitPath(path)
    local parts = splitCache[path]
    if parts then return parts end
    parts = {}
    for segment in tostring(path):gmatch("[^%.]+") do
        parts[#parts + 1] = segment
    end
    splitCache[path] = parts
    return parts
end

--- Walk `parts` from `first` and return the leaf, or nil if any step is missing.
local function readFrom(root, parts, first)
    local node = root
    for i = first, #parts do
        if type(node) ~= "table" then return nil end
        node = node[parts[i]]
    end
    return node
end

--- Walk `parts` from `first`, creating missing tables, and write the leaf.
local function writeInto(root, parts, first, value)
    local node = root
    for i = first, #parts - 1 do
        local key = parts[i]
        if type(node[key]) ~= "table" then node[key] = {} end
        node = node[key]
    end
    node[parts[#parts]] = value
end

--- Recursive copy. A table default (every color) must never be handed out by
--- reference: two profiles reset to the same default would then share one table,
--- and editing one window's bar color would silently edit the other's.
local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

-- ---------------------------------------------------------------------------
-- Window resolution
-- ---------------------------------------------------------------------------

local WINDOW_PREFIX = "window"

--- The window a `window.`-prefixed path resolves against: the picker's selection,
--- or the first window in the registry when nothing is selected.
---
--- Falling back to the first window rather than to nil is deliberate. The CLI has
--- no picker, and `/mm set window.frame.width 300` typed on a fresh login — where
--- nothing has ever set activeWindowId — must mean something rather than fail with
--- a message about an internal pointer the user has never heard of.
---
--- @return table|nil window, number|nil id
local function activeWindow()
    local Database = NS.Database
    if not Database then return nil, nil end

    local id = NS.State and NS.State.activeWindowId
    if id ~= nil then
        local w = Database.FindWindow(id)
        if w then return w, id end
    end

    local first = Database.GetWindows()[1]
    if first then return first, first.id end
    return nil, nil
end

--- Where a path lives: its root table, the index of its first segment inside that
--- root, and the id of the window it landed in (nil for a global row).
---
--- An EXPLICIT window id is taken literally. It is never swapped for the active
--- window when it names nothing: a writer that asked for window 7 and quietly got
--- window 1 has written the wrong window, which is worse than being refused.
---
--- @param parts table  the split path
--- @param windowId number|nil  the window a `window.*` path addresses; nil means the active one
--- @return table|nil root, number first, number|nil windowId
local function resolveRoot(parts, windowId)
    if parts[1] == WINDOW_PREFIX then
        if windowId ~= nil then
            local w = NS.Database and NS.Database.FindWindow(windowId)
            return w, 2, w and windowId or nil
        end
        local w, id = activeWindow()
        return w, 2, id
    end
    local db = NS.db
    return db and db.profile or nil, 1, nil
end

-- ---------------------------------------------------------------------------
-- Inversion
-- ---------------------------------------------------------------------------
--
-- Exactly one row stores the negation of what it displays: LibDBIcon owns the
-- shape of `minimap`, and its key is `hide`, while the checkbox a user reads has
-- to say "Show minimap button" — a checkbox labelled with a negative is the
-- classic settings-panel double-negative that everyone mis-clicks once.
--
-- Rather than let that one row grow a private get/set pair (which the CLI would
-- then have to know about separately), the seam carries a two-line concept used at
-- three call sites and nowhere else. `default` is always the STORED value, so the
-- validator still compares like with like against defaults/Profile.lua.

local function toStored(row, v)
    if row.invert then return not v end
    return v
end

local function toDisplay(row, v)
    if row.invert then return not v end
    return v
end

-- ---------------------------------------------------------------------------
-- The index
-- ---------------------------------------------------------------------------
--
-- path -> row, so a lookup is a hash hit rather than a walk of ~75 rows. Rebuilt
-- rather than appended to, so it cannot fall out of step with the array after a
-- late registration.

local index = {}

local function reindex()
    for k in pairs(index) do index[k] = nil end
    for _, row in ipairs(NS.Schema) do
        index[row.path] = row
    end
end

reindex()

--- The row for `path`, or nil.
--- @param path string
--- @return table|nil
function NS.FindSchemaRow(path)
    if type(path) ~= "string" then return nil end
    return index[path]
end

--- Append rows declared elsewhere (a page file with a row whose `values` cannot be
--- expressed until that page's helpers exist) and rebuild the index.
---
--- The append seam exists so such a row still lands in THIS array — the one the
--- CLI, the panel and the reset all read — rather than in a second list one of the
--- three would inevitably miss.
---
--- @param rows table  array of rows
function NS.RegisterSchemaRows(rows)
    if type(rows) ~= "table" then return end
    for _, row in ipairs(rows) do
        NS.Schema[#NS.Schema + 1] = row
    end
    reindex()
end

-- ---------------------------------------------------------------------------
-- The read seam
-- ---------------------------------------------------------------------------

--- The current value of `path`, in DISPLAY terms (inverted rows are un-inverted
--- here, which is why the panel and the CLI both agree with the label).
---
--- Also resolves paths that are not rows — `window.columns`, or a sub-table like
--- `window.frame` — because `/mm get` is a debugging tool as much as a settings
--- reader and refusing to show a node that plainly exists helps nobody.
---
--- `windowId` reads a named window instead of the active one, exactly as it
--- writes one in NS.SetByPath; an id that names no window reads nil.
---
--- @param path string
--- @param windowId number|nil
--- @return any
function NS.GetSetting(path, windowId)
    if type(path) ~= "string" then return nil end

    local row = index[path]
    if row and row.sessionOnly then
        -- Returned rather than `and`-ed through: a session row answering `false` is
        -- a real answer, and `row.get() or nil` would turn every "off" into "no
        -- such setting" — which reads to the CLI as a missing row.
        if row.get then return row.get() end
        return nil
    end

    local parts = splitPath(path)
    local root, first = resolveRoot(parts, windowId)
    if not root then return nil end

    local value = readFrom(root, parts, first)
    if row then return toDisplay(row, value) end
    return value
end

-- ---------------------------------------------------------------------------
-- The write seam
-- ---------------------------------------------------------------------------

local COLUMNS_PREFIX = WINDOW_PREFIX .. ".columns"

--- The tail EVERY write shares: announce once, re-sync the panel. The log line
--- is the caller's, because a single write and a batch log differently.
---
--- Factored out because the columns carve-out below is a second writer into the
--- same config tree, and a carve-out that skipped the announcement would be a
--- setting that changes without any window hearing about it — which is precisely
--- the failure the single-seam rule exists to prevent.
---
--- @param page string      the CONFIG_CHANGED section
--- @param windowId number|nil
local function announceWrite(page, windowId)
    -- The ONE sender of CONFIG_CHANGED (architecture-§4). `section` is the row's
    -- page key, which is also the window config group it lives in, so a subscriber
    -- can skip work for a group it does not draw.
    if NS.SendMessage then
        NS:SendMessage(MSG.CONFIG_CHANGED, { section = page, windowId = windowId })
    end

    -- In-place scalar refresh, never a structural one. A widget's own set() already
    -- calls this, so the cost of repeating it is one pcall'd loop; a structural
    -- RefreshAllPanels here would rebuild the page under a slider mid-drag, which
    -- is what writing a value emphatically does not change (no row appeared or
    -- disappeared). It is what keeps a `/mm set` visible on an open panel.
    local H = NS.Helpers
    if H and H.RefreshScalars then H.RefreshScalars() end
end

-- ---------------------------------------------------------------------------
-- The columns carve-out
-- ---------------------------------------------------------------------------
--
-- See "WHY THE COLUMNS ARE NOT ROWS" at the top of this file. A column array has
-- no schema row, so it gets none of a row's `validate` — which means the check
-- has to live here and has to be at least as strict. Everything downstream
-- (modules/Row.lua's cell builder, modules/Window.lua's header) indexes
-- `stat`, `width` and `showBar` without re-checking any of them.

--- Repair a candidate column array into the catalog, in the caller's order.
---
--- REPAIRING RATHER THAN REJECTING, and that is the change. The array used to be
--- a SUBSET the player assembled, so an entry naming a statistic this build does
--- not have was a real editing problem and was surfaced as one: stored, listed on
--- the page, and removable. There is nothing to surface now. The array IS the
--- catalog, there is no remove button, and a row for a statistic that does not
--- exist is a row nobody can act on. So an unknown statistic is DROPPED and one
--- this build gained is APPENDED disabled, and a profile carried back from a
--- newer build heals itself instead of growing a dead row.
---
--- ENABLED-FIRST IS ENFORCED HERE, WHICH IS WHY THE PAGE DOES NOT HAVE TO. The
--- Columns page sinks a disabled block below its rule, but `/mm set
--- window.columns ...` and a hand-edited SavedVariables reach this seam without
--- ever drawing a block. Partitioning here is what makes those three routes
--- agree, and the two-list build below is a STABLE partition: relative order
--- inside each group is exactly the caller's.
---
--- Rebuilding rather than accepting the caller's table also means the stored
--- array can never share a sub-table with whoever handed it over (the classic
--- profile-aliasing bug), and any extra key someone smuggled in is dropped
--- rather than persisted into a profile the renderer will not read.
---
--- @param value any
--- @return table|nil columns, string|nil err
local function normalizeColumns(value)
    if type(value) ~= "table" then
        return nil, L["Columns must be a list of columns, not %s."]:format(type(value))
    end

    local n = #value

    -- A hole or a string key would make `#value` an arbitrary answer, so the array
    -- shape is proved rather than assumed before anything is read out of it.
    local keys = 0
    for _ in pairs(value) do keys = keys + 1 end
    if keys ~= n then
        return nil, L["Columns must be a plain ordered list with no gaps."]
    end

    local enabled, disabled, seen = {}, {}, {}
    for i = 1, n do
        local c = value[i]
        if type(c) ~= "table" then
            return nil, L["Column %d is not a column."]:format(i)
        end

        -- An unknown statistic and a repeat are both dropped, silently and on
        -- purpose. THE FIRST APPEARANCE WINS: a later duplicate carrying a
        -- different `enabled` cannot quietly overrule the position the caller
        -- already gave it.
        local stat = c.stat
        if type(stat) == "string" and Const.STAT_BY_KEY[stat] and not seen[stat] then
            seen[stat] = true
            local entry = { stat = stat, enabled = c.enabled and true or false }
            local into  = entry.enabled and enabled or disabled
            into[#into + 1] = entry
        end
    end

    -- Every catalog statistic the caller did not mention, appended disabled in
    -- catalog order -- which is what makes a statistic added to core/Constants.lua
    -- appear on every existing profile's page with no migration of its own.
    for _, stat in ipairs(Const.STATS) do
        if not seen[stat.key] then
            disabled[#disabled + 1] = { stat = stat.key, enabled = false }
        end
    end

    -- A window with nothing but names in it reads as a broken addon rather than as
    -- a configuration. This is the one thing the repair cannot invent an answer
    -- for: which column did they mean to keep?
    if #enabled == 0 then
        return nil, L["A window must keep at least one column."]
    end

    local out = {}
    for _, entry in ipairs(enabled)  do out[#out + 1] = entry end
    for _, entry in ipairs(disabled) do out[#out + 1] = entry end
    return out
end

--- Published because core/Database.lua's migration ladder needs this same rule and
--- cannot reach a local in a file that loads eighteen TOC entries after it. Read
--- at MIGRATION time rather than at load time, which is the pattern `migrations[1]`
--- already uses for `NS.WINDOW_TEMPLATE`: the ladder runs on Init, long after
--- every file is in memory. A second implementation of "what shape is a column
--- array" is how the migration and the write seam end up disagreeing about it.
NS.NormalizeColumns = normalizeColumns

-- ---------------------------------------------------------------------------
-- One write, in two halves
-- ---------------------------------------------------------------------------
--
-- PREPARE decides whether a write may happen and where it lands, and stores
-- nothing. STORE and REACT then do it. Split so the batch entry below can check
-- EVERY write before committing ANY of them -- a batch that stored half its rows
-- and then refused one would leave a window that matches neither the source nor
-- what it was before -- while the single-row entry is the same three steps back
-- to back, and so cannot drift from the batch.

--- Everything a write needs before it touches the tree, or why it may not happen.
---
--- @param path string
--- @param value any
--- @param windowId number|nil  the window a `window.*` path addresses; nil means the active one
--- @return table|nil plan, string|nil err
local function prepareWrite(path, value, windowId)
    if type(path) ~= "string" then return nil, L["Setting not found: %s"]:format(tostring(path)) end

    -- The columns carve-out. The array as a WHOLE is writable — that is the only
    -- granularity a path can express — while a path INTO it is refused, because the
    -- ordinal it would address moves on the next add, remove or reorder.
    if path == COLUMNS_PREFIX then
        local cols, err = normalizeColumns(value)
        if not cols then return nil, err end
        local w, _, id = resolveRoot(splitPath(path), windowId)
        if not w then return nil, L["No window is selected."] end
        return { columns = cols, root = w, windowId = id, page = "columns" }
    end
    if path:sub(1, #COLUMNS_PREFIX + 1) == COLUMNS_PREFIX .. "." then
        return nil, L["A single column is not a setting — edit columns on the Columns page."]
    end

    local row = index[path]
    if not row then return nil, L["Setting not found: %s"]:format(path) end
    if row.validate and not row.validate(value) then
        return nil, L["Invalid value for %s"]:format(path)
    end

    local plan = { row = row, path = path, value = value, page = row.page }
    if not row.sessionOnly then
        local parts = splitPath(path)
        local root, first, id = resolveRoot(parts, windowId)
        if not root then return nil, L["No window is selected."] end
        plan.parts, plan.root, plan.first, plan.windowId = parts, root, first, id
    end
    return plan
end

-- ---------------------------------------------------------------------------
-- The bulk bracket (debug-logging-§10)
-- ---------------------------------------------------------------------------
--
-- A BULK COPY OR RESET IS ONE [Set] LINE. An act whose purpose is to rewrite a
-- set of rows wholesale -- a page's Defaults button, a copy from one window onto
-- another -- is logged as `[Set] <act> <scope>: N rows` and never as a line per
-- row. Validation and each row's onChange still run per row; only the log
-- collapses. Every other batch (a sort, a resize, a segment pick) logs per row,
-- because a reader needs its values.
--
-- ONE MUTE FOR EVERY BULK ACT. The library's walks reach it through the
-- descriptors' bulkBegin / bulkEnd (Options minor 16, Slash minor 8); the
-- Columns page, the degraded reset-all and NS.SetByPaths' copy reach it through
-- NS.Bulk.run. A DEPTH, not a flag: the Columns page brackets its array write
-- around the library's page bracket, so brackets nest, and only the close that
-- brings the depth back to 0 emits -- once, with what every level wrote.
--
-- N IS COUNTED HERE, NOT TAKEN FROM bulkEnd. The library's `count` is the rows
-- its applyDefault returned, and a row already at its default is one of them;
-- the rule is the rows the act actually WROTE. So while a bracket is open the
-- seam reads each row's stored value before and after its write and counts the
-- row -- once, however often it is written -- only when the value moved. The
-- column array, which no applyDefault reaches, is counted the same way.
--
-- A PROFILE RESET IS NOT OURS TO LOG. When a level says the act included a
-- whole-profile reset, core/Database.lua's OnProfileReset has already logged
-- `[Set] reset profile '<name>' to defaults (N rows)`, and a line from here
-- would be a second one. The close emits nothing; the mute is still released.
local bulk = { depth = 0, label = nil, seen = {}, changed = 0, profileReset = false }

local function bulkOpen(label)
    if bulk.depth == 0 then
        bulk.label, bulk.seen, bulk.changed, bulk.profileReset = label, {}, 0, false
    end
    bulk.depth = bulk.depth + 1
end

--- Close one level. Only the outermost close emits, and not after a profile reset.
local function bulkClose(profileReset)
    if bulk.depth == 0 then return end   -- an unpaired close must not go negative
    bulk.depth = bulk.depth - 1
    if profileReset then bulk.profileReset = true end
    if bulk.depth > 0 or bulk.profileReset then return end
    if NS.Debug then NS.Debug("Set", "%s: %d rows", bulk.label, bulk.changed) end
end

--- Run `fn` inside a bracket that always closes, then re-raise what it raised,
--- unwrapped -- the library's own rule, so a raising row cannot leave the seam
--- muted for the rest of the session. `fn` answers true when it reset the whole
--- profile, which silences the close.
local function runBulk(label, fn)
    bulkOpen(label)
    local ok, res = pcall(fn)
    bulkClose(ok and res == true)
    if not ok then error(res, 0) end
end

--- Equal all the way down. A color is `{ r, g, b, a }` and the column array is
--- a list of `{ stat, enabled }`, so one level is not deep enough.
local function sameValue(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if not sameValue(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

--- What a write replaces, read where the write lands. A session row is read
--- through its own getter, and `false` and `nil` read alike there: the debug
--- console's getter answers either one for "closed".
local function storedOf(plan)
    if plan.columns then return plan.root.columns end
    if plan.row.sessionOnly then
        return plan.row.get and plan.row.get() or nil
    end
    return readFrom(plan.root, plan.parts, plan.first)
end

--- Count one write toward the open bracket: once per row, and only if it moved.
local function tally(plan, before)
    local key = tostring(plan.windowId) .. "|" .. tostring(plan.path or COLUMNS_PREFIX)
    if bulk.seen[key] or sameValue(before, storedOf(plan)) then return end
    bulk.seen[key] = true
    bulk.changed = bulk.changed + 1
end

-- The pair both library majors take as bulkBegin / bulkEnd.
local function bulkBegin(act, scope) bulkOpen(tostring(act) .. " " .. tostring(scope)) end
local function bulkEnd(_, _, _, _, info)
    bulkClose(type(info) == "table" and info.profileReset == true)
end

-- A bracket of the host's own. Named the way the library names a page reset, so
-- both read `[Set] reset <scope>: N rows`.
local function bulkRun(act, scope, fn) runBulk(tostring(act) .. " " .. tostring(scope), fn) end

-- Built from named locals rather than function literals in the constructor:
-- lizard 1.24.0's Lua reader raises on anonymous functions in a table assigned
-- to a dotted name, and a crashed complexity run measures nothing.
NS.Bulk = { begin = bulkBegin, finish = bulkEnd, run = bulkRun }

--- Put a prepared write into the tree.
local function putWrite(plan)
    if plan.columns then
        -- No copy() on the way in: normalizeColumns already returned a table
        -- built here, held by nobody else.
        plan.root.columns = plan.columns
        return
    end
    local row = plan.row
    if row.sessionOnly then
        -- No db write by definition; the row's own set() IS the storage.
        if row.set then row.set(plan.value) end
        return
    end
    -- copy() on the way in: a color table handed straight from a widget (or
    -- from a row's default) would otherwise be shared with whoever else holds
    -- it, and editing one window's color would edit theirs.
    writeInto(plan.root, plan.parts, plan.first, copy(toStored(row, plan.value)))
end

--- Put a prepared write into the tree, and count it when a bulk act is open.
--- Outside a bracket nothing is read back, so a lone write costs what it did.
local function storeWrite(plan)
    if bulk.depth == 0 then return putWrite(plan) end
    local before = storedOf(plan)
    putWrite(plan)
    tally(plan, before)
end

--- Fire a stored write's `onChange`, told which window moved.
local function reactWrite(plan)
    local row = plan.row
    if row and row.onChange then row.onChange(plan.value, plan.windowId) end
end

--- HOW MANY ARE SHOWN, not how many there are. Every array is the catalog now,
--- so `#cols` is the same number on every write, and a log line that never
--- changes is a log line nobody can read a change out of.
local function shownCount(cols)
    local shown = 0
    for _, c in ipairs(cols) do
        if c.enabled then shown = shown + 1 end
    end
    return shown
end

--- The `[Set] <path> = <value>` line for one stored write (debug-logging-§10).
---
--- Logged ONCE, here. Downstream reactors must not re-echo the same value: a
--- settings change that appears three times in the log is three changes as far
--- as a reader can tell. The format is DEFERRED into NS.Debug rather than built
--- here, so a disabled log costs nothing.
local function logWrite(plan)
    -- Muted inside a bulk bracket: the act logs its one line when it closes.
    if bulk.depth > 0 or not NS.Debug then return end
    if plan.columns then
        NS.Debug("Set", "%s = %d shown", COLUMNS_PREFIX, shownCount(plan.columns))
    else
        NS.Debug("Set", "%s = %s", plan.path, plan.value)
    end
end

--- Write one setting. THE single write seam (settings-schema-§1): the panel's
--- widgets, `/mm set`, `/mm reset` and the defaults restore all land here, so
--- validation, the debug line, the row's reaction and the refresh cannot be
--- skipped by whichever caller forgot one.
---
--- Order is load-bearing: write, then react, then log ONCE, then announce, then
--- re-sync the panel. Reacting before the write would hand a refresher the old
--- value; logging in the reactor would log it per subscriber.
---
--- `windowId` IS THE INSTANCE ARGUMENT (architecture-§5, issue #49). Omitted,
--- a `window.*` path means the active window, which is what the panel and
--- `/mm set` want. Given, it means THAT window and never another: an id that
--- names no window is refused rather than quietly redirected to the active one.
--- It is how modules/WindowManager.lua renames, copies into and locks a window
--- the picker is not pointed at, and how a resize drag saves the window that was
--- dragged. Moving NS.State.activeWindowId so the seam points at the target
--- would be going around the seam, so nothing does. Ignored by a global row.
---
--- @param path string
--- @param value any
--- @param windowId number|nil
--- @return boolean ok, string|nil err
function NS.SetByPath(path, value, windowId)
    local plan, err = prepareWrite(path, value, windowId)
    if not plan then return false, err end

    storeWrite(plan)
    reactWrite(plan)
    logWrite(plan)
    announceWrite(plan.page, plan.windowId)
    return true
end

--- Write several settings as ONE change: every write is checked first, then all
--- are stored, then each row reacts and is logged, then the change is announced
--- once.
---
--- THE SAME SEAM, NOT A SECOND ONE. Each entry goes through exactly what
--- NS.SetByPath does -- the columns carve-out, the row lookup, the row's
--- `validate`, the deep copy on the way in, the row's `onChange` -- and the
--- difference is the tail. A copy-from touches seventy-odd rows of one window,
--- and seventy CONFIG_CHANGED messages would be seventy re-applies of that
--- window for a single click. So the batch announces ONCE, naming the page when
--- every row shares one and none when they do not, because a subscriber
--- skipping a section must not skip part of a change.
---
--- THE LOG FOLLOWS debug-logging-§10 (ruled 2026-09-12). A batch logs every row
--- it writes as its own `[Set] <path> = <value>` line: a sort, a resize or a
--- segment pick is two or three settings, and a reader needs their values, not
--- a count. A BULK copy or reset is the one exception, and `summary` is how the
--- caller says it is one: the batch runs inside a bulk bracket, which mutes
--- the per-row line and logs ONE `[Set] <summary>: N rows` when it closes --
--- `[Set] copy from 'A' to 'B': 42 rows` -- with N the rows whose stored value
--- moved (see "The bulk bracket" above). The tag is [Set], never a tag of its
--- own (standard v2.44.0). Seventy per-row lines for one click would evict the
--- rest of the log.
---
--- ALL OR NOTHING. One refused entry stores no entry at all, and the refusal
--- names its path.
---
--- @param writes table         array of `{ path, value }`
--- @param windowId number|nil  as NS.SetByPath's
--- @param summary string|nil   ONLY for a bulk copy or reset: the act, naming
---                             its source and target, e.g. "copy from 'A' to 'B'"
--- @return boolean ok, string|nil err
function NS.SetByPaths(writes, windowId, summary)
    if type(writes) ~= "table" then return false, L["Setting not found: %s"]:format(tostring(writes)) end

    local plans = {}
    for i, entry in ipairs(writes) do
        local plan, err = prepareWrite(entry[1], entry[2], windowId)
        if not plan then return false, err end
        plans[i] = plan
    end
    if plans[1] == nil then return true end

    local page, id = plans[1].page, plans[1].windowId
    local function apply()
        for _, plan in ipairs(plans) do storeWrite(plan) end
        for _, plan in ipairs(plans) do
            reactWrite(plan)
            logWrite(plan)
            if plan.page ~= page then page = nil end
            if plan.windowId ~= id then id = nil end
        end
    end
    if summary then runBulk(summary, apply) else apply() end

    announceWrite(page, id)
    return true
end

--- Restore one row to its shipped default, through the same seam everything else
--- writes through.
---
--- Takes the ROW rather than the path because both library majors hand the row,
--- and because the deep copy a table default needs belongs on this side of the
--- seam: two profiles restored to the same color default must not end up holding
--- one table between them.
---
--- @param row table
function NS.ApplyDefault(row)
    if type(row) ~= "table" or row.path == nil then return end
    -- A RESTORE IS NOT A CLICK, and one row cares: the Frame page's meta colour
    -- mode broadcasts to ten rows on three other pages when it is SET, which is
    -- the point of it -- and must not when the page's own Defaults button walks
    -- it, or that button silently resets settings on pages it has no business
    -- reaching. Set around the write rather than passed as an argument, because
    -- every other row and every other seam is indifferent to the difference.
    local was = NS.__restoring
    NS.__restoring = true
    -- toDisplay, because SetByPath expects display terms and will invert back. The
    -- round trip is what keeps `default` meaning "the stored value" for the
    -- validator while the seam still sees what a user would have clicked.
    NS.SetByPath(row.path, toDisplay(row, copy(row.default)))
    NS.__restoring = was
end

-- ---------------------------------------------------------------------------
-- Page and validation surfaces
-- ---------------------------------------------------------------------------

--- The rows of one page, in declaration order.
---
--- `filter` is the library's `ctx.unit`, passed through untouched. This addon does
--- not interpret it, and that is the whole point of the window-relative path
--- model: the panel does not filter rows per window, it MOVES the window every row
--- resolves against (NS.State.activeWindowId). The parameter is accepted so the
--- descriptor's signature is honest and so a later per-window row exclusion has
--- somewhere to go.
---
--- @param pageKey string
--- @param filter any
--- @return table  array of rows
function NS.SchemaForPage(pageKey, filter)   -- luacheck: ignore 212/filter
    local rows = {}
    for _, row in ipairs(NS.Schema) do
        -- `hidden` rows are skipped HERE and nowhere else, so they stay writable
        -- through NS.SetByPath, listable through `/mm list` and comparable by the
        -- schema-vs-defaults validator, and only ever miss the panel. A row is
        -- hidden when it is per-window STATE that something else in the UI already
        -- writes -- `frame.minimised` is the one -- rather than a preference.
        if row.page == pageKey and not row.hidden then rows[#rows + 1] = row end
    end
    return rows
end

--- Compare a schema default against a defaults-tree default. Tables are compared
--- field-wise one level deep, which is exactly as deep as this schema's table
--- defaults go (a color is `{ r, g, b, a }`).
local function sameDefault(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

--- Prove the schema against the defaults tree. Returns the number of rows that
--- FAILED, which is 0 on a healthy load and is what the headless suite asserts on.
---
--- Two independent checks, and the second is the one this validator exists for:
---
--- 1. RESOLUTION. Every non-session path must resolve against defaults/Profile.lua
---    — window rows against WINDOW_TEMPLATE, global rows against defaults.profile.
---    A path that does not resolve is a setting whose writes land on a key nothing
---    reads: the panel renders, the widget shows the row's own default, the write
---    succeeds, and nothing anywhere says so. The row's own `default` is NOT an
---    escape hatch from this, because a row with a good default and a typo'd path
---    is the worst case rather than the exempt one.
---
--- 2. AGREEMENT. The row's `default` must EQUAL the value the defaults tree ships.
---    They are restated in two files on purpose — one is what a widget shows before
---    the db exists, the other is what a fresh profile is built from — and a
---    disagreement means a Defaults click silently moves a setting somewhere the
---    addon never shipped it. This is the bug the whole function is here to catch.
---
--- @return number  count of failing rows
function NS.ValidateSchema()
    local profile  = NS.defaults and NS.defaults.profile
    local template = NS.WINDOW_TEMPLATE
    if not (profile and template) then return 0 end

    local out = NS.Print
    local failed = 0

    for _, row in ipairs(NS.Schema) do
        if not row.sessionOnly then
            local parts = splitPath(row.path)
            local root, first
            if parts[1] == WINDOW_PREFIX then
                root, first = template, 2
            else
                root, first = profile, 1
            end

            local shipped = readFrom(root, parts, first)
            if shipped == nil then
                failed = failed + 1
                if out then out("schema path does not resolve against the defaults: " .. row.path) end
            elseif not sameDefault(shipped, row.default) then
                failed = failed + 1
                if out then out("schema default disagrees with defaults/Profile.lua: " .. row.path) end
            end
        end
    end

    return failed
end

-- ---------------------------------------------------------------------------
-- Positions
-- ---------------------------------------------------------------------------
--
-- `NS.ResetPositions` USED TO LIVE HERE and no longer does. It existed because
-- positions are not schema rows, so NS.ApplyDefault could not reach them, and the
-- options descriptor's `afterRestoreAll` called it to finish a global reset. That
-- reset is a PROFILE reset now (settings/OptionsSetup.lua): positions live in the
-- profile, so they come back with everything else and the seam had no caller
-- left. `/mm reset-positions` has always gone straight to
-- modules/WindowManager.lua, which owns re-anchoring a live frame.
