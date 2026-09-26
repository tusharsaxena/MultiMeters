-- settings/Schema_Paths.lua
--
-- THE SETTINGS RUNTIME'S DESCRIPTOR, and the seams every reader and writer of a
-- setting lands on. The machinery itself -- path splitting and walking, the row
-- index, the single write seam, the all-or-nothing batch and the bulk bracket --
-- is LibKa0s-Schema-1.0's (minor 2, LibKa0s v1.56.0; issue #52). What stays here
-- is what is genuinely this addon's: where a path lives (the window-relative
-- model below), what a write announces, the one row whose value is an array, the
-- page and validation surfaces, and the stub a library-less install runs on.
--
-- A SEPARATE FILE because settings/Schema.lua was 3080 lines against layout-§1's
-- 1500-line cap, and this is the seam issue #27 names: nothing in this file names
-- a single setting but the two carve-outs. The array is the part that grows; this
-- is the part that is read when something is wrong.
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
-- spelled `window.frame.width`. The runtime's `resolveRoot` resolves the
-- `window.` prefix against the window id it is handed, or, with none, against the
-- session's ACTIVE window — NS.State.activeWindowId, which the panel's window
-- picker moves and which defaults to the first window in the registry. Global
-- rows keep absolute paths (`enabled`, `master.scale`), resolved against
-- db.profile -- except `global.minimap.shown`, whose row stores itself (see "The
-- minimap row").
--
-- What that buys: ONE schema, ONE write seam, and `/mm set window.frame.width 300`
-- means "the window I am editing" on the CLI exactly as it does in the panel. The
-- picker retargets 70-odd rows by moving one integer of session state instead of
-- by rewriting every path.
--
-- ---------------------------------------------------------------------------
-- THE COLUMNS ROW
-- ---------------------------------------------------------------------------
--
-- `window.columns` is an ORDERED ARRAY of `{ stat, enabled }` whose order is the
-- user's, not the schema's. A path model addresses named leaves; it has no
-- vocabulary for "move this column above that one". So the array is ONE hidden
-- row, written WHOLE: settings/Columns.lua builds the array it wants and hands
-- the seam all of it, which is the only granularity a path can honestly express.
-- The row's `validate` refuses what is not a table and its `normalize` (Schema
-- minor 2) repairs the rest into the catalog; the library then stores a copy,
-- logs, reacts and announces exactly as for any other row. `hidden` keeps it off
-- the panel, whose Columns page draws the array its own way.
--
-- What is still refused is a write to a path INSIDE the array —
-- `window.columns.2.enabled`. No row declares that path, so the library refuses
-- it; NS.SetByPath says why in words that point at the Columns page. Addressing
-- one column by ordinal is exactly the vocabulary a path model does not have: the
-- ordinal moves the moment a column is reordered, so a stored reference to it is
-- wrong by the next edit.
--
-- TOC POSITION: LAST of the three Schema files, and LOAD-BEARING: the runtime's
-- index is built from NS.Schema at FILE SCOPE, so there has to be an array to
-- index -- settings/Schema_Compose.lua then settings/Schema.lua must both have
-- run. Still ahead of settings/Slash.lua and settings/OptionsSetup.lua, both of
-- which point their seams at NS.SetByPath / NS.GetSetting / NS.FindSchemaRow /
-- NS.ApplyDefault, and ahead of every settings/<page>.lua.
--
-- Nothing here is captured across the load boundary: NS.Helpers, NS.db,
-- NS.WindowManager and NS.Database are all resolved at CALL time, because this
-- file loads before all four.

local _, NS = ...

local L     = NS.L
local Const = NS.Constants
local MSG   = Const.MSG

-- Read-only stand-in for an absent tree, so ValidateSchema indexes one shape rather than
-- branching on nil at every step.
local EMPTY_TREE = {}

-- ---------------------------------------------------------------------------
-- The runtime's library, or the stub that stands in for it
-- ---------------------------------------------------------------------------

local SchemaLib = LibStub and LibStub("LibKa0s-Schema-1.0", true)

if not SchemaLib then
    -- Degraded: the payload is missing. THIS STUB IS A DELIBERATE, DOCUMENTED DUPLICATION -- the
    -- runtime-completing stub LibKa0s docs/api/Schema/version-2-docs.md prescribes in "The
    -- degradation stub", modeled on BankLedger's (settings/Schema.lua) and trimmed to what this
    -- addon calls. The settings are written by more than the panel and the CLI: the header
    -- controls, the window placement, the copy-from, the lock sweep and the degraded Reset All in
    -- settings/OptionsSetup.lua all go through this seam, and slash-commands-§1 says the host verbs
    -- keep working without the library. So reads, writes, `validate`, `normalize`, the row's
    -- `onChange`, the announce, the batch, the sweep veto and `writeThrough` are real here.
    --
    -- LOG-SILENT, on purpose: no [Set] line and no bracket tally. The degraded DebugLog stub
    -- (core/DebugLogSetup.lua) discards every line anyway.
    --
    -- TRIMMED, each with no caller in this addon: STRINGS (the refusals are the descriptor's own
    -- words), AllRows (both descriptors read NS.Schema), Reindex (nothing splices by hand),
    -- Default, BulkAdd, InBulk, CountOffDefault, ResetCounted and ConsumeResetCount (the profile
    -- reset logs its own line without a count; core/Database.lua), and Validate (ValidateSchema
    -- below is this addon's own check). tests/test_surface_parity.lua names each one.
    local stub = {}

    local function copy(v)
        if type(v) ~= "table" then return v end
        local out = {}
        for k, x in pairs(v) do out[k] = copy(x) end
        return out
    end
    function stub.SplitPath(path)
        local parts = {}
        if path ~= nil then
            for seg in tostring(path):gmatch("[^%.]+") do parts[#parts + 1] = seg end
        end
        return parts
    end
    local function partsOf(p) return type(p) == "table" and p or stub.SplitPath(p) end
    function stub.Read(root, p, first)
        local parts, node = partsOf(p), root
        first = first or 1
        if type(root) ~= "table" or #parts < first then return nil end
        for i = first, #parts do
            if type(node) ~= "table" then return nil end
            node = node[parts[i]]
        end
        return node
    end
    function stub.Write(root, p, value, first)
        local parts, node = partsOf(p), root
        first = first or 1
        if type(root) ~= "table" or #parts < first then return end
        for i = first, #parts - 1 do
            if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
            node = node[parts[i]]
        end
        node[parts[#parts]] = value
    end
    function stub.SameValue(a, b)
        if a == b then return true end
        if type(a) ~= "table" or type(b) ~= "table" then return false end
        for k, v in pairs(a) do if not stub.SameValue(v, b[k]) then return false end end
        for k in pairs(b) do if a[k] == nil then return false end end
        return true
    end

    function stub.New(_, d)   -- colon-called, as the library's New is
        local R, depth, rows = {}, 0, d.rows
        local function words(key, path) return (d.L[key]):format(tostring(path)) end
        -- writeThrough, as the library reads it: once, here, one synthetic row per listed path,
        -- handed out by identity. A listed path with no row is stored raw (no validate, no
        -- normalize, no onChange) and announced with that row; every other row-less path is
        -- still refused, and FindRow never answers one.
        local through = {}
        for _, p in ipairs(type(d.writeThrough) == "table" and d.writeThrough or {}) do
            if type(p) == "string" and p ~= "" then through[p] = { path = p, writeThrough = true } end
        end

        function R.FindRow(path)
            if type(path) ~= "string" then return nil end
            for _, row in ipairs(rows) do
                if type(row) == "table" and row.path == path then return row end
            end
        end
        function R.AddRows(list, at)
            if type(list) ~= "table" then return 0 end
            at = type(at) == "number" and math.floor(at) or #rows + 1
            if at > #rows + 1 then at = #rows + 1 elseif at < 1 then at = 1 end
            for i, row in ipairs(list) do table.insert(rows, at + i - 1, row) end
            return #list
        end
        function R.Get(path, id)
            local row = R.FindRow(path)
            if row and type(row.get) == "function" then return row.get(id) end
            if type(path) ~= "string" or (row and row.sessionOnly) then return nil end
            local parts = stub.SplitPath(path)
            local root, first = d.resolveRoot(parts, id)
            return stub.Read(root, parts, first)
        end
        -- The value half of the seam: validate, then normalize (its answer is what is stored;
        -- nil refuses). Answers the value to store, or nil and the refusal.
        local function checked(row, path, value, rid)
            if type(row.validate) == "function" then
                local ok, why = row.validate(value, rid)
                if not ok then return nil, words("INVALID", path), why end
            end
            if type(row.normalize) ~= "function" then return value end
            local out, why = row.normalize(value, rid)
            if out == nil then return nil, words("INVALID", path), why end
            return out
        end
        -- Everything the seam checks before it stores, shared by Set and SetMany: a plan, or
        -- nil and the refusal. A missing root is refused after a bad value, as the library does.
        local function prepare(path, value, id)
            local row = R.FindRow(path) or (type(path) == "string" and through[path] or nil)
            if not row then return nil, words("NOT_FOUND", path) end
            local stored = type(row.set) ~= "function" and not row.sessionOnly
            local parts, root, first, rid, reason = nil, nil, nil, id, nil
            if stored then
                parts = stub.SplitPath(path)
                root, first, rid = d.resolveRoot(parts, id)
                if type(root) ~= "table" then reason, rid = first, id end
                if rid == nil then rid = id end
            end
            local v, err, why = checked(row, path, value, rid)
            if err then return nil, err, why end
            if stored and type(root) ~= "table" then return nil, reason or words("NO_ROOT", path) end
            return { row = row, path = path, value = v, rid = rid, parts = parts, root = root, first = first }
        end
        local function store(p)
            if type(p.row.set) == "function" then
                p.row.set(p.value)
            elseif p.root then
                stub.Write(p.root, p.parts, copy(p.value), p.first)
            end
        end
        local function react(p)
            if type(p.row.onChange) == "function" then p.row.onChange(p.value, p.rid) end
        end
        -- The seam's order without its log and tally: refuse, store, react, announce.
        function R.Set(path, value, id)
            local p, err, why = prepare(path, value, id)
            if not p then return false, err, why end
            store(p)
            react(p)
            d.announce(p.row, p.path, p.value, p.rid)
            return true
        end
        local function commit(plans)
            for _, p in ipairs(plans) do store(p) end
            for _, p in ipairs(plans) do react(p) end
        end
        -- All or nothing: every entry prepared before any is stored; then every store, every
        -- onChange, and one announceBatch. `opts.act` holds the depth the sweep veto reads.
        function R.SetMany(entries, opts)
            opts = type(opts) == "table" and opts or {}
            local plans = {}
            for i, e in ipairs(type(entries) == "table" and entries or {}) do
                local p, err, why = prepare(type(e) == "table" and e.path or nil,
                    type(e) == "table" and e.value or nil, opts.instanceId)
                if not p then return false, err, why, i end
                plans[i] = p
            end
            if opts.act ~= nil then R.BulkRun(opts.act, opts.scope, function() commit(plans) end)
            else commit(plans) end
            if plans[1] then d.announceBatch(plans, plans[1].rid) end
            return true
        end
        function R.ApplyDefault(row, id)
            if type(row) ~= "table" or type(row.path) ~= "string" or row.default == nil then return false end
            if depth > 0 and d.resetExempt[row.path] then return false end
            return R.Set(row.path, copy(row.default), id)
        end
        -- The bracket keeps its depth, because the sweep veto above reads it; it counts nothing.
        function R.BulkBegin() depth = depth + 1 end
        function R.BulkEnd() if depth > 0 then depth = depth - 1 end end
        function R.BulkRun(_, _, walk)
            R.BulkBegin()
            local ok, err = pcall(walk, { profileReset = false })
            R.BulkEnd()
            if not ok then error(err, 0) end
        end
        return R
    end
    SchemaLib = stub
end

-- Published for introspection only: tests/test_surface_parity.lua holds the stub to the live major.
NS.__schemaLib = SchemaLib

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

--- The runtime's `resolveRoot`: where a path lives, as its root table, the index
--- of its first segment inside that root, and the id of the window it landed in
--- (nil for a global row) -- or nil and the refusal when there is nowhere.
---
--- An EXPLICIT window id is taken literally. It is never swapped for the active
--- window when it names nothing: a writer that asked for window 7 and quietly got
--- window 1 has written the wrong window, which is worse than being refused.
---
--- @param parts table  the split path
--- @param windowId number|nil  the window a `window.*` path addresses; nil means the active one
--- @return table|nil root, number|string first_or_reason, number|nil windowId
local function resolveRoot(parts, windowId)
    local root, first, id
    if parts[1] == WINDOW_PREFIX then
        first = 2
        if windowId ~= nil then
            root = NS.Database and NS.Database.FindWindow(windowId)
            id = root and windowId or nil
        else
            root, id = activeWindow()
        end
    else
        local db = NS.db
        root, first = db and db.profile or nil, 1
    end
    if not root then return nil, L["No window is selected."] end
    return root, first, id
end

-- ---------------------------------------------------------------------------
-- The minimap row
-- ---------------------------------------------------------------------------
--
-- ONE ROW IS NEITHER PROFILE-SCOPED NOR STORED IN ITS OWN SENSE: the one the `MasterControls`
-- composer emits for `minimapPath`. launcher-§3 fixes LibDBIcon's `minimap` table at
-- `db.global.minimap`, and LibDBIcon's key says HIDDEN while the checkbox says SHOWN. Both facts
-- live in the row's own get/set pair, declared with the row in settings/Schema_Compose.lua: the
-- runtime hands a row carrying `set` its value and stores nothing itself, so `/mm set`, the
-- checkbox and `/mm reset` all reach the inversion (and the button's immediate show or hide) by
-- one route.
--
-- THE PATH READS IN THE ROW'S OWN SENSE, `global.minimap.shown` (launcher-§3, standard v2.65.0):
-- the CLI name says what the checkbox says, and `/mm set global.minimap.shown false` hides the
-- button. `global.` is kept so the CLI name says where it lives. The PATH IS NOT A STORAGE KEY:
-- what is stored is still LibDBIcon's own `db.global.minimap.hide`, so a player's choice saved
-- under the old `global.minimap.hide` path carries over with no SavedVariables step, and no
-- `shown` key is ever written (a second record of one state is anti-pattern #81). The old path
-- is simply an unknown setting now.

local MINIMAP_PATH = "global.minimap.shown"

--- PUBLISHED, because more files have to name this row. settings/OptionsSetup.lua exempts
--- exactly this path from the settings panel's two resets (launcher-§3's survival property), and
--- it loads after this file, so it reads the constant instead of spelling the string again.
NS.MINIMAP_PATH = MINIMAP_PATH

-- ---------------------------------------------------------------------------
-- The enabled path, written through
-- ---------------------------------------------------------------------------
--
-- `enabled` is a composed Master-controls row: LibKa0s-Options-1.0's MasterControls declares
-- it (settings/Schema_Compose.lua), so a load without that major has no row, and options-ui-§1
-- forbids a host copy of the composer. `/mm enable` and `/mm disable` still have to work there.
-- Route (a): the descriptor below names the path in `writeThrough`, as data, and the seam (the
-- library or the stub above) stores it raw when no row claims it. On a full load the composed
-- row claims it and nothing here applies. It is the ONLY composed row a host verb writes:
-- `/mm lock` writes each window's hand-written `window.frame.locked`, and `/mm test` goes
-- through modules/WindowManager.lua.
local ENABLED_PATH = "enabled"

-- ---------------------------------------------------------------------------
-- The announce
-- ---------------------------------------------------------------------------

--- The window a write moved: its resolved id for a `window.` path, nil for any
--- other. A global row is handed the caller's id by the runtime when one was
--- passed; no window moved, so none is announced.
local function windowOf(path, rid)
    if type(path) == "string" and path:sub(1, #WINDOW_PREFIX + 1) == WINDOW_PREFIX .. "." then
        return rid
    end
    return nil
end

--- The tail EVERY write shares: announce once, re-sync the panel.
---
--- @param page string|nil  the CONFIG_CHANGED section
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

--- The runtime's `announce`, after a single write's onChange.
---
--- A WRITTEN-THROUGH `enabled` IS THE ONE WRITE THAT REACTS HERE. On a load without
--- LibKa0s-Options-1.0 (the library absent, or a partial payload) the composed
--- `enabled` row does not exist, so its onChange -- the latch -- is not there either;
--- the seam stores the path raw through `writeThrough` (options-ui-§1 route (a)) and
--- hands this function a synthetic row flagged `writeThrough`. The latch is pulled
--- here instead, in the same place the row's onChange would have run: after the
--- store, before the message.
local function announceOne(row, path, _, rid)
    if row.writeThrough and path == ENABLED_PATH and NS.SyncEnabledHold then
        NS.SyncEnabledHold()
    end
    announceWrite(row.page, windowOf(path, rid))
end

--- The runtime's `announceBatch`: a batch announces ONCE, naming the page when
--- every row shares one and none when they do not, because a subscriber skipping
--- a section must not skip part of a change. The same for the window.
local function announceMany(writes)
    local page, id = writes[1].row.page, windowOf(writes[1].path, writes[1].rid)
    local latch = false
    for _, w in ipairs(writes) do
        latch = latch or (w.row.writeThrough and w.path == ENABLED_PATH)
        if w.row.page ~= page then page = nil end
        if windowOf(w.path, w.rid) ~= id then id = nil end
    end
    -- The batch half of announceOne's latch: a written-through `enabled` among the writes.
    if latch and NS.SyncEnabledHold then NS.SyncEnabledHold() end
    announceWrite(page, id)
end

-- ---------------------------------------------------------------------------
-- The columns row
-- ---------------------------------------------------------------------------
--
-- See "THE COLUMNS ROW" at the top of this file. Everything downstream
-- (modules/Row.lua's cell builder, modules/Window.lua's header) indexes `stat`
-- and `enabled` without re-checking either, so the row's normalize is the check.

local COLUMNS_PATH = WINDOW_PREFIX .. ".columns"

--- Repair a candidate column array into the catalog, in the caller's order.
---
--- REPAIRING RATHER THAN REJECTING. The array IS the catalog, there is no remove
--- button, and a row for a statistic that does not exist is a row nobody can act
--- on. So an unknown statistic is DROPPED and one this build gained is APPENDED
--- disabled, and a profile carried back from a newer build heals itself instead
--- of growing a dead row.
---
--- ENABLED-FIRST IS ENFORCED HERE, WHICH IS WHY THE PAGE DOES NOT HAVE TO. The
--- Columns page sinks a disabled block below its rule, but `/mm set
--- window.columns ...` and a hand-edited SavedVariables reach this seam without
--- ever drawing a block. Partitioning here is what makes those three routes
--- agree, and the two-list build below is a STABLE partition: relative order
--- inside each group is exactly the caller's.
---
--- Rebuilding rather than accepting the caller's table means any extra key
--- someone smuggled in is dropped rather than persisted into a profile the
--- renderer will not read. (The runtime then stores a copy of the answer, so the
--- stored array never shares a table with anyone either.)
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
--- at MIGRATION time rather than at load time: the ladder runs on Init, long after
--- every file is in memory. A second implementation of "what shape is a column
--- array" is how the migration and the write seam end up disagreeing about it.
NS.NormalizeColumns = normalizeColumns

--- The row's `validate`: the one refusal that needs no repair attempt.
local function isColumnList(value)
    if type(value) == "table" then return true end
    return false, L["Columns must be a list of columns, not %s."]:format(type(value))
end

--- HOW MANY ARE SHOWN, not how many there are. Every array is the catalog, so
--- `#cols` is the same number on every write, and a log line that never changes
--- is a log line nobody can read a change out of.
local function shownCount(cols)
    local shown = 0
    for _, c in ipairs(cols) do
        if c.enabled then shown = shown + 1 end
    end
    return shown
end

-- The row itself. `hidden` keeps it off the panel (NS.SchemaForPage); it has NO
-- `default`, so no reset reaches it -- the Columns page's Defaults button writes
-- the shipped array itself (settings/Columns.lua), inside the page's bracket.
local COLUMNS_ROW = {
    path      = COLUMNS_PATH,
    page      = "columns",
    group     = L["Columns"],
    label     = L["Columns"],
    hidden    = true,
    validate  = isColumnList,
    normalize = normalizeColumns,
}
NS.Schema[#NS.Schema + 1] = COLUMNS_ROW

-- ---------------------------------------------------------------------------
-- The runtime
-- ---------------------------------------------------------------------------

--- The [Set] line's value (debug-logging-§10). Handed back AS IS for every row but
--- one, so NS.Debug's own deferred, secret-safe formatting renders it exactly as
--- it did before the adoption; the column array logs how many are shown.
local function formatValue(row, value)
    if row == COLUMNS_ROW and type(value) == "table" then
        return ("%d shown"):format(shownCount(value))
    end
    return value
end

--- The debug sink, resolved at CALL time so a suite that swaps NS.Debug hears it.
local function debugSink(tag, fmt, ...)
    if NS.Debug then NS.Debug(tag, fmt, ...) end
end

-- ONE INSTANCE FOR THE ADDON: the bracket and the index are per instance. The
-- descriptor is read at CALL time, which is why nothing below captures NS.db.
--
-- No `debugEnabled`: NS.Debug is already the gated sink, and `formatValue` hands
-- the value through untouched, so there is nothing to spare while logging is off.
local S = SchemaLib:New({
    rows          = NS.Schema,
    resolveRoot   = resolveRoot,
    announce      = announceOne,
    announceBatch = announceMany,
    debug         = debugSink,
    format        = formatValue,
    resetExempt   = { [MINIMAP_PATH] = true },
    writeThrough  = { ENABLED_PATH },
    L = {
        NOT_FOUND = L["Setting not found: %s"],
        INVALID   = L["Invalid value for %s"],
        NO_ROOT   = L["No window is selected."],
    },
})
NS.SchemaRuntime = S

-- ---------------------------------------------------------------------------
-- The public seams, kept by name so no caller moves
-- ---------------------------------------------------------------------------

--- The row for `path`, or nil.
NS.FindSchemaRow = S.FindRow

--- Append rows declared elsewhere (a page file with a row whose `values` cannot be
--- expressed until that page's helpers exist), so such a row still lands in THIS
--- array — the one the CLI, the panel and the reset all read.
--- TEST-ONLY TODAY: no in-addon caller; the seam is exercised by
--- tests/test_schema_defaults.lua and tests/test_options_panel.lua.
function NS.RegisterSchemaRows(rows) S.AddRows(rows) end

--- The current value of `path`, in DISPLAY terms (the minimap row reads SHOWN).
--- Also resolves paths that are not rows — a sub-table like `window.frame` —
--- because `/mm get` is a debugging tool as much as a settings reader. `windowId`
--- reads a named window instead of the active one; an id that names no window
--- reads nil.
function NS.GetSetting(path, windowId) return S.Get(path, windowId) end

--- Write one setting. THE single write seam (architecture-§5): the panel's
--- widgets, `/mm set`, `/mm reset` and the defaults restore all land here.
--- The runtime's order: refuse an unknown path, validate, normalize, refuse a
--- missing root, store (a copy), log once, react, announce.
---
--- `windowId` IS THE INSTANCE ARGUMENT (architecture-§5, issue #49). Omitted, a
--- `window.*` path means the active window. Given, it means THAT window and never
--- another: an id that names no window is refused. Ignored by a global row.
---
--- One refusal is this addon's own: a path INTO the column array names the page
--- that can do it, rather than falling through to "not a row". No row matches
--- such a path, so no reset or batch can reach it; the gate is wording only.
---
--- @return boolean ok, string|nil err, string|nil why
function NS.SetByPath(path, value, windowId)
    if type(path) == "string" and path:sub(1, #COLUMNS_PATH + 1) == COLUMNS_PATH .. "." then
        return false, L["A single column is not a setting — edit columns under Windows > Columns."]
    end
    return S.Set(path, value, windowId)
end

--- Write several settings as ONE change, through the runtime's SetMany: every
--- entry is checked first and one refusal stores nothing (ALL OR NOTHING, the
--- refusal naming its path); then every entry is stored, every row reacts, and
--- the change is announced ONCE -- a copy-from touches seventy-odd rows of one
--- window, and seventy CONFIG_CHANGED messages would be seventy re-applies.
---
--- THE LOG FOLLOWS debug-logging-§10. A batch logs every row it writes as its own
--- `[Set] <path> = <value>` line. A BULK copy or reset is the one exception, and
--- `summary` is how the caller says it is one: its first word is the act and the
--- rest the scope, so `copy from 'A' to 'B'` logs one `[Set] copy from 'A' to 'B':
--- N rows` line, N the rows whose stored value moved.
---
--- @param writes table         array of `{ path, value }`
--- @param windowId number|nil  as NS.SetByPath's
--- @param summary string|nil   ONLY for a bulk copy or reset, e.g. "copy from 'A' to 'B'"
--- @return boolean ok, string|nil err, string|nil why  (`why`: the row's own reason, e.g. a column
---                                                    array's repair refusal)
function NS.SetByPaths(writes, windowId, summary)
    if type(writes) ~= "table" then return false, L["Setting not found: %s"]:format(tostring(writes)) end
    local entries = {}
    for i, entry in ipairs(writes) do entries[i] = { path = entry[1], value = entry[2] } end
    local opts = { instanceId = windowId }
    if summary then
        local act, scope = tostring(summary):match("^(%S+)%s+(.*)$")
        opts.act, opts.scope = act or tostring(summary), scope or ""
    end
    local ok, err, why = S.SetMany(entries, opts)
    if ok then return true end
    return false, err, why
end

--- Restore one row to its shipped default, through the same seam everything else
--- writes through (the runtime deep-copies a table default on the way in).
---
--- A row with no `default` is NOT written and answers exactly false, which is what
--- LibKa0s-Slash-1.0 (minor 15) reads to print its NO_DEFAULT line. A refusal
--- answers nil, err -- never false, which would read as NO_DEFAULT.
---
--- A RESTORE IS NOT A CLICK, and one row cares: the Frame page's meta color mode
--- broadcasts to ten rows on three other pages when it is SET, and must not when
--- the page's own Defaults button walks it. NS.__restoring is set around the write
--- rather than passed, because every other row is indifferent to the difference.
---
--- @param row table
--- @param windowId number|nil
--- @return boolean|nil ok, string|nil err
function NS.ApplyDefault(row, windowId)
    local was = NS.__restoring
    NS.__restoring = true
    local ok, err = S.ApplyDefault(row, windowId)
    NS.__restoring = was
    if ok == false and err ~= nil then return nil, err end
    return ok
end

-- The bulk bracket (debug-logging-§10): the runtime's, handed to both library
-- majors' descriptors (bulkBegin / bulkEnd) and to the host's own bulk acts --
-- the Columns page's Defaults, the degraded Reset All -- through `run`, whose
-- walk is handed `info` and sets `info.profileReset` when it reset the profile.
-- One `[Set] <act> <scope>: N rows` at the outermost close, N the rows whose
-- read-back moved; nothing after a profile reset (core/Database.lua logs that).
-- Built from named members rather than function literals in the constructor:
-- lizard 1.24.0's Lua reader raises on anonymous functions in a table assigned
-- to a dotted name, and a crashed complexity run measures nothing.
NS.Bulk = { begin = S.BulkBegin, finish = S.BulkEnd, run = S.BulkRun }

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
        -- hidden when something else in the UI already writes it: per-window STATE
        -- (`frame.minimized`) or the column array the Columns page draws itself.
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

--- Judge the minimap row, which is the one row whose STORED value is the inverse of
--- what the row SHOWS. Both checks, against the GLOBAL tree and through the inversion:
--- the row's default is SHOWN and the tree ships HIDDEN, so "agreement" here means they
--- are opposites -- which is the one comparison a reader would otherwise have to work
--- out from two files, and the one a copy-paste of this row into a second addon gets
--- wrong. It sits out here rather than inline so the loop below reads as cases handed
--- to judges rather than one body carrying all of them.
---
--- @param row table
--- @param out function|nil  NS.Print when something is listening, nil when nothing is
--- @return number  1 when the row failed, 0 when it passed
local function checkMinimapRow(row, out)
    -- Read out in two steps, NEVER `type(t) == "table" and t.hide or nil`: the shipped
    -- value IS `false`, and that idiom collapses a stored false to nil -- which would
    -- report the path as unresolvable on the one healthy load this check exists to bless.
    local table_ = ((NS.defaults or EMPTY_TREE).global or EMPTY_TREE).minimap
    local shipped
    if type(table_) == "table" then shipped = table_.hide end
    if shipped == nil then
        if out then out("schema path does not resolve against the defaults: " .. row.path) end
        return 1
    elseif shipped ~= (not row.default) then
        if out then out("schema default disagrees with defaults/Profile.lua: " .. row.path) end
        return 1
    end
    return 0
end

--- Judge an ordinary row against the defaults tree -- window rows against
--- WINDOW_TEMPLATE, everything else against defaults.profile. The caller has already
--- decided the row is neither the minimap row nor `sessionOnly`; this one only picks
--- the root the path hangs off and runs the two checks. The column row has no
--- `default` by design (see COLUMNS_ROW), so it is held to resolution alone.
---
--- @param row table
--- @param profile table   defaults.profile, the root for a global path
--- @param template table  NS.WINDOW_TEMPLATE, the root for a `window.` path
--- @param out function|nil  NS.Print when something is listening, nil when nothing is
--- @return number  1 when the row failed, 0 when it passed
local function checkTreeRow(row, profile, template, out)
    local parts = SchemaLib.SplitPath(row.path)
    local root, first
    if parts[1] == WINDOW_PREFIX then
        root, first = template, 2
    else
        root, first = profile, 1
    end

    local shipped = SchemaLib.Read(root, parts, first)
    if shipped == nil then
        if out then out("schema path does not resolve against the defaults: " .. row.path) end
        return 1
    elseif row ~= COLUMNS_ROW and not sameDefault(shipped, row.default) then
        if out then out("schema default disagrees with defaults/Profile.lua: " .. row.path) end
        return 1
    end
    return 0
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
        if row.path == MINIMAP_PATH then
            failed = failed + checkMinimapRow(row, out)
        elseif not row.sessionOnly then
            failed = failed + checkTreeRow(row, profile, template, out)
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
