-- core/Diagnostics_Runtime.lua
--
-- The sections of `/mm diagnostics` that describe the ADDON rather than the client
-- (debug-logging-§14, DX-MM): the latch and its holds, the restriction and the
-- session flags, the settings that differ from what shipped (per profile, and per
-- window against NS.DefaultWindow), every window, the sessions the client holds
-- and which one each window reads, the aggregator's last render pass, and the
-- roster and cache counts.
--
-- ---------------------------------------------------------------------------
-- WHY A SIBLING
-- ---------------------------------------------------------------------------
--
-- core/Diagnostics.lua holds the CLIENT probes (atlases, the number ladder, the
-- cells, the targets walk) and sits near layout-§1's 1500-line cap. These sections
-- are a different kind of thing: they read the addon's own state, they write to
-- the library's section writer directly rather than through the shared `out`
-- sink, and none of them answers to one open issue. core/Diagnostics.lua's section
-- list reaches them through `NS.Diagnostics.Runtime` at RUN time, so a failure to
-- load costs one `section <name> failed` line per section and nothing else.
--
-- ---------------------------------------------------------------------------
-- WHAT THESE SECTIONS MAY NOT DO
-- ---------------------------------------------------------------------------
--
-- They run while the addon is disabled and in combat, so they are READ-ONLY:
-- nothing here resets the meter, invalidates a memo, refreshes or builds the
-- roster, dirties a window, or moves the settings panel's window pointer. Where a
-- getter would fill a cache as a side effect (Provider.IsAvailable,
-- Roster.GetGroup), a read-only accessor is used instead.
--
-- They never read geometry off a window frame. A frame handed a secret has secret
-- anchoring data (rule R3), so a window's position and size print from its
-- config. They never inspect a meter value: session names and durations are
-- secret in a pull and go through the writer's `str` before any concatenation,
-- and every format below is `%s` on values the writer stringifies itself.
--
-- Released state reads as released (Q4): while stood down the sessions and
-- aggregator sections say so instead of printing an empty list that looks idle.
--
-- TOC POSITION: after core\Diagnostics.lua, which publishes NS.Diagnostics. The
-- modules these sections read (Provider, Aggregator, Roster, Visibility,
-- WindowManager) load later and are resolved at CALL time.

local _, NS = ...

local Diagnostics = NS.Diagnostics
local Runtime = {}
Diagnostics.Runtime = Runtime

local TAG = "Diag"

-- DX-MM's always-print rows: whatever their values, a maintainer wants these three
-- on every report.
local ALWAYS = { "enabled", "master.visibility", "data.mergePets" }

-- The top-level keys of a window config that are not settings to diff: the id is
-- the window's identity and the name is on its heading line.
local NOT_DIFFED = { id = true, name = true }

local function heading(w, name)
    w:add(TAG, "%s", "-- " .. name .. " --")
end

--- Whether `t` is a plain array (the column list), which diffs as one value.
local function isArray(t)
    return type(t) == "table" and t[1] ~= nil
end

--- The keys of two tables, sorted as strings, so a diff reads in a stable order.
local function unionKeys(a, b)
    local seen, keys = {}, {}
    for _, t in ipairs({ a, b }) do
        if type(t) == "table" then
            for k in pairs(t) do
                if not seen[k] then seen[k] = true keys[#keys + 1] = k end
            end
        end
    end
    table.sort(keys, function(x, y) return tostring(x) < tostring(y) end)
    return keys
end

--- A window's column list as one compact value: `DamageDone+ Dps- ...`.
local function compactColumns(columns)
    if type(columns) ~= "table" then return tostring(columns) end
    local parts = {}
    for i, col in ipairs(columns) do
        parts[i] = tostring(type(col) == "table" and col.stat) .. ((type(col) == "table" and col.enabled) and "+" or "-")
    end
    return table.concat(parts, " ")
end

-- ---------------------------------------------------------------------------
-- state
-- ---------------------------------------------------------------------------

local function latchLine(w)
    local stored = NS.GetSetting and NS.GetSetting("enabled")
    w:add(TAG, "stored enabled=%s disabled=%s stood down=%s", stored,
        NS.IsDisabled and NS.IsDisabled() or false,
        NS.IsStoodDown and NS.IsStoodDown() or false)
    local lc = NS.lifecycle
    w:joined(TAG, "holds:", lc and lc.Holds and lc:Holds() or {})
end

local function profileLines(w)
    local db = NS.db
    local stored = db and db.global and db.global.schemaVersion
    w:add(TAG, "schema: stored=%s code=%s", stored, NS.SCHEMA_VERSION)
    local current = db and db.GetCurrentProfile and db:GetCurrentProfile()
    w:add(TAG, "profile: '%s'", current)
    local names = db and db.GetProfiles and db:GetProfiles() or {}
    w:list(TAG, "profiles:", names)
end

local function restrictionLine(w)
    local S = NS.Secrets
    w:add(TAG, "restriction: mirror=%s authority=%s state=%s",
        NS.State and NS.State.restricted,
        S and S.IsRestricted and S.IsRestricted(),
        S and S.GetRestrictionState and S.GetRestrictionState())
end

local function sessionFlags(w)
    local State, P, M = NS.State or {}, NS.Provider, NS.WindowManager
    w:add(TAG, "flags: test mode=%s debug tooltip=%s active window=%s all locked=%s",
        State.testMode, State.debugTooltip, State.activeWindowId,
        M and M.IsLocked and M:IsLocked())
    w:add(TAG, "provider suspended=%s", P and P.IsSuspended and P.IsSuspended())
    if P and P.AvailabilityMemo then
        local checked, ok, reason = P.AvailabilityMemo()
        w:add(TAG, "meter: memo checked=%s available=%s reason=%s", checked, ok, reason)
    end
end

function Runtime.state(w)
    heading(w, "state")
    latchLine(w)
    profileLines(w)
    restrictionLine(w)
    sessionFlags(w)
end

-- ---------------------------------------------------------------------------
-- settings: the profile's rows, and each window against NS.DefaultWindow
-- ---------------------------------------------------------------------------

function Runtime.settings(w)
    heading(w, "settings")
    local rows = {}
    for _, row in ipairs(NS.Schema or {}) do
        if type(row.path) == "string" and row.path:sub(1, 7) ~= "window." then
            rows[#rows + 1] = row
        end
    end
    w:nonDefaults(rows, function(row) return NS.GetSetting(row.path) end, nil, nil,
        { always = ALWAYS, tag = TAG })
end

--- One window's diff rows: every leaf of the stored table and of a fresh
--- NS.DefaultWindow for the same id and name, one level of groups deep. A group's
--- own tables (a color, the position) are one value each, and so is the column
--- list, rendered compactly.
local function addRows(rows, key, tv, sv)
    local path = "window." .. tostring(key)
    if key == "columns" then
        rows[#rows + 1] = { path = path, default = compactColumns(tv), value = compactColumns(sv) }
    elseif type(tv) == "table" and not isArray(tv) and type(sv) == "table" then
        for _, sub in ipairs(unionKeys(tv, sv)) do
            rows[#rows + 1] = { path = path .. "." .. tostring(sub), default = tv[sub], value = sv[sub] }
        end
    else
        rows[#rows + 1] = { path = path, default = tv, value = sv }
    end
end

local function windowRows(stored, template)
    local rows = {}
    for _, key in ipairs(unionKeys(template, stored)) do
        if not NOT_DIFFED[key] then addRows(rows, key, template[key], stored[key]) end
    end
    return rows
end

function Runtime.windowSettings(w)
    heading(w, "window settings")
    local Database = NS.Database
    local windows = Database and Database.GetWindows and Database.GetWindows() or {}
    if #windows == 0 then w:add(TAG, "%s", "no windows") return end
    for _, cfg in ipairs(windows) do
        w:add(TAG, "window #%s '%s':", cfg.id, cfg.name)
        local template = NS.DefaultWindow and NS.DefaultWindow(cfg.id, cfg.name) or {}
        local n = w:nonDefaults(windowRows(cfg, template), function(row) return row.value end,
            nil, nil, { tag = TAG })
        if n == 0 then w:add(TAG, "%s", "  as shipped") end
    end
end

-- ---------------------------------------------------------------------------
-- windows: the inventory
-- ---------------------------------------------------------------------------

local function contextLine(w)
    local V = NS.Visibility
    local inInstance, kind = false, "none"
    if _G.IsInInstance then inInstance, kind = _G.IsInInstance() end
    w:add(TAG, "context: resolved=%s inInstance=%s type=%s inGroup=%s",
        V and V.GetContext and V.GetContext(), inInstance, kind,
        _G.IsInGroup and _G.IsInGroup())
end

--- The live instances keyed by window id, without building any.
local function instancesById()
    local byId = {}
    local M = NS.WindowManager
    for _, inst in ipairs(M and M.All and M.All() or {}) do
        local id = inst.id or (inst.config and inst.config.id)
        if id ~= nil then byId[id] = inst end
    end
    return byId
end

--- The ladder's live answer and the debug pass's remembered one, as text.
local function ladderText(cfg)
    local show, reason = "?", "?"
    if NS.ShouldShow then show, reason = NS.ShouldShow(cfg) end
    local last = "not evaluated"
    local V = NS.Visibility
    if V and V.LastResult then
        local s, r = V.LastResult(cfg.id)
        if s ~= nil then last = (s and "shown" or "hidden") .. " (" .. tostring(r) .. ")" end
    end
    return tostring(show) .. " (" .. tostring(reason) .. ")", last
end

--- Position and size, FROM CONFIG (rule R3).
local function placementText(cfg)
    local f = cfg.frame or {}
    local p = f.position or {}
    return tostring(f.width) .. "x" .. tostring(f.height) .. " scale=" .. tostring(f.scale),
        tostring(p.point) .. " " .. tostring(p.relativePoint) .. " " .. tostring(p.x) .. "," .. tostring(p.y)
end

local function windowLine(w, cfg, inst)
    local frame = cfg.frame or {}
    local should, last = ladderText(cfg)
    local size, at = placementText(cfg)
    local drawn = inst and inst.pool and type(inst.pool.active) == "table" and #inst.pool.active or 0
    w:add(TAG, "#%s '%s' built=%s shown=%s forcedShow=%s minimized=%s locked=%s dirty=%s rows drawn=%s",
        cfg.id, cfg.name, inst ~= nil, inst ~= nil and inst:IsShown(), inst and inst.forcedShow,
        frame.minimized, frame.locked, inst and inst.dirty, drawn)
    w:add(TAG, "  ShouldShow=%s last pass=%s size=%s at=%s", should, last, size, at)
end

function Runtime.windows(w)
    heading(w, "windows")
    contextLine(w)
    local Database = NS.Database
    local windows = Database and Database.GetWindows and Database.GetWindows() or {}
    local byId = instancesById()
    w:add(TAG, "registry: %s window(s), next id %s", #windows,
        NS.db and NS.db.profile and NS.db.profile.nextWindowId)
    for _, cfg in ipairs(windows) do windowLine(w, cfg, byId[cfg.id]) end
end

-- ---------------------------------------------------------------------------
-- sessions: what the client holds, and what each window reads
-- ---------------------------------------------------------------------------

local function stoodDown(w, what)
    if NS.IsStoodDown and NS.IsStoodDown() then
        w:add(TAG, "stood down: %s", what)
        return true
    end
    return false
end

--- What one window reads: its type, its pin, and the fallback a stale pin takes.
local function pinLine(w, cfg, P)
    local data = cfg.data or {}
    local pinned = NS.Database.PinnedSegment(data)
    if pinned == nil then
        w:add(TAG, "  window #%s type=%s pinned=none -> reads type %s", cfg.id, data.sessionType,
            data.sessionType)
        return
    end
    local held = P.HasSession(pinned)
    local reads = held and ("segment " .. tostring(pinned))
        or ("falls back to type " .. tostring(data.sessionType))
    w:add(TAG, "  window #%s type=%s pinned=%s held=%s -> %s", cfg.id, data.sessionType, pinned,
        held, reads)
end

function Runtime.sessions(w)
    heading(w, "sessions")
    if stoodDown(w, "the provider is suspended, so every read answers empty") then return end
    local P = NS.Provider
    if not (P and P.GetAvailableSessions) then w:add(TAG, "%s", "provider unavailable") return end
    local list = P.GetAvailableSessions()
    w:add(TAG, "held: %s", #list)
    local items = {}
    for i, entry in ipairs(list) do
        if type(entry) == "table" then
            items[i] = "#" .. w:str(entry.sessionID) .. " " .. w:str(entry.name) .. " "
                .. w:str(entry.durationSeconds) .. "s"
        else
            items[i] = w:str(entry)
        end
    end
    w:list(TAG, "  sessions:", items)
    for _, cfg in ipairs(NS.Database.GetWindows()) do pinLine(w, cfg, P) end
end

-- ---------------------------------------------------------------------------
-- aggregator: the last render pass per window
-- ---------------------------------------------------------------------------

local function passLine(w, id, pass)
    if pass == nil then
        w:add(TAG, "#%s no render pass recorded (hidden, minimized or not drawn yet)", id)
        return
    end
    local now = _G.GetTime and _G.GetTime() or 0
    local age = math.floor(((now - (pass.at or now)) * 10) + 0.5) / 10
    w:add(TAG, "#%s cols=%s rows=%s dropped=%s unfolded=%s sort=%s/%s identity=%s ambiguous=%s reason=%s age=%ss",
        id, pass.cols, pass.rows, pass.dropped, pass.unfolded, pass.mode, pass.applied,
        pass.identityMode, pass.ambiguousRows, pass.reason or "ok", age)
end

function Runtime.aggregator(w)
    heading(w, "aggregator")
    if stoodDown(w, "no pass runs while the addon is down") then return end
    local A = NS.Aggregator
    if not (A and A.LastPass) then w:add(TAG, "%s", "aggregator unavailable") return end
    for _, cfg in ipairs(NS.Database.GetWindows()) do passLine(w, cfg.id, A.LastPass(cfg.id)) end
    local stats = A.LastIdentityStats and A.LastIdentityStats()
    w:add(TAG, "identity stats: %s", stats and "recorded (see /mm debug identity)" or "none")
end

-- ---------------------------------------------------------------------------
-- roster and caches
-- ---------------------------------------------------------------------------

local function countKeys(t)
    local n = 0
    for _ in pairs(type(t) == "table" and t or {}) do n = n + 1 end
    return n
end

function Runtime.rosterAndCaches(w)
    heading(w, "roster and caches")
    local State = NS.State or {}
    local caches = type(State.cache) == "table" and State.cache or {}
    -- The live group as it stands. Roster.GetGroup would BUILD on a miss and write
    -- the remembered map, so the cache is read directly.
    local group = type(caches.Roster) == "table" and caches.Roster.group
    if type(group) == "table" then
        w:add(TAG, "live group: %s member(s) partial=%s", #group, caches.Roster.partial and true or false)
    else
        w:add(TAG, "%s", "live group: not built")
    end
    local g = NS.db and NS.db.global
    local seen = g and g.roster
    if type(seen) == "table" then
        w:add(TAG, "remembered: members=%s pets=%s", countKeys(seen.byGuid), countKeys(seen.pets))
    else
        w:add(TAG, "%s", "remembered: none stored")
    end
    local names = {}
    for name in pairs(caches) do names[#names + 1] = tostring(name) end
    table.sort(names)
    local parts = {}
    for i, name in ipairs(names) do parts[i] = name .. "=" .. countKeys(caches[name]) end
    w:joined(TAG, "caches:", parts)
end
