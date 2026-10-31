-- core/Database.lua
--
-- Owns the AceDB-3.0 instance and the window registry's shape. The migration ladder
-- and its runner are core/Database_Migrations.lua. The defaults tree itself lives in defaults/Profile.lua, which is the
-- only place a profile default is hardcoded (savedvariables-§2).
--
-- The one thing this file does that a sibling addon's Database.lua does not is
-- key-fill the WINDOWS. Windows are an ARRAY of config tables, and AceDB's
-- defaults merge cannot reach inside an array — it fills keys of tables it knows
-- about, and it does not know that `profile.windows[3]` is supposed to look like
-- defaults/Profile.lua's WINDOW_TEMPLATE. So the merge is ours, and the rule
-- that makes it correct is spelled out at EnsureWindowShape: test with `== nil`,
-- NEVER `stored.k or D.k`.
--
-- TOC POSITION: after core/State.lua and before core/MultiMeters.lua, whose
-- OnInitialize calls NS:InitDB(). The defaults tree it merges against loads
-- LATER (the `# Defaults` block follows `# Core`), which is fine because every
-- read of NS.defaults here happens at CALL time.

local _, NS = ...

local Database = {}
NS.Database = Database

-- ---------------------------------------------------------------------------
-- Schema version
-- ---------------------------------------------------------------------------

-- Increment ONLY for a non-additive change to the profile's shape — a rename, a
-- restructure, a type change. Additive changes (a new leaf setting, a new window
-- group) are absorbed by AceDB's defaults merge and by EnsureWindowShape below,
-- and need no version bump.
--
-- The version is an addon-wide integer in db.global.schemaVersion, NOT
-- per-profile (savedvariables-§1), so a migration runs once per ACCOUNT.
-- v1 is the shipped shape.
-- v2 makes every column one uniform width (see migrations[1] below).
-- v3 collapses the three row-icon toggles into one.
-- v4 retires the export channel "AUTO".
-- v5 lifts mergePets and throttle from per-window to addon-wide.
-- v6 prunes the two row-background keys nothing ever read.
-- v7 turns four class-color booleans into three-way color modes.
-- v8 prunes the four header keys that said what was already on screen.
-- v9 takes the color mode off the title bar's background.
-- v10 retires the "At cursor" tooltip anchor.
-- v11 takes the color mode off the title bar's text.
-- v12 turns the column array from a chosen subset into the full catalog, ticked.
-- v13 moves the title-bar toggle onto the header and turns the two control
--     class-color flags into modes.
-- v14 carries the addon-wide `master.locked` onto every window's own lock and
--     prunes it.
-- v15 moves LibDBIcon's `minimap` table from the profile to the global store.
-- v16 spells the window's minimize keys the US way.
-- v17 matches the header to Ka0s DPS Race.
-- v18 grows the title bar to Ka0s DPS Race's 30px.
-- v19 grows the shipped window to 228px, ten rows under that bar.
-- v20 puts every window's HUD faces, bar textures and bar borders on the skin, once.
-- v21 puts every window's chrome (fill, edge, title bar, title, controls) on the skin, once.
-- v22 moves every window's font flags still at their old default onto From skin, once.
--
-- The defaults declare `global.schemaVersion = 0`, which means UNSTAMPED: a fresh
-- install or an account from before the runner stamped anything. It is never the
-- current version (savedvariables-§1); see defaults/Profile.lua for why.
local CURRENT_DB_VERSION = 22

--- The runner's target, published under the name savedvariables-§1 gives it.
--- Raising it means registering the step that reaches it; the defaults' 0 never moves.
NS.SCHEMA_VERSION = CURRENT_DB_VERSION

-- The ONE Ka0s_MultiMeters_ProfileChanged emitter (architecture-§4: one sender
-- per message). Every path that makes the active profile a different thing — a
-- swap, a copy, a reset — routes here rather than writing its own SendMessage,
-- so the bus catalog in docs/message-bus.md names one site and stays true.
local function fireProfileChanged(key)
    -- A profile swap, copy or reset ends a simulation first (MultiMeters#60):
    -- its pin snapshot belongs to the profile that is going away.
    if NS.Sim and NS.Sim:IsActive() then NS.Sim:Stop("profile") end
    if NS.SendMessage then
        NS:SendMessage(NS.Constants.MSG.PROFILE_CHANGED, { newProfileKey = key })
    end
end

-- File-local recursive deep-copy, deliberately independent of NS.Util: this file
-- is reached during OnInitialize and must not depend on a helper module's load
-- order.
local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

-- core/Database_Migrations.lua's v14 -> v15 step copies with this too.
Database._copy = copy

-- ---------------------------------------------------------------------------
-- Window shape
-- ---------------------------------------------------------------------------

--- Fill any key a stored window is missing from the shipped template, in place
--- and recursively.
---
--- CRITICAL, and the reason this is a named function with a comment rather than
--- three inline lines (savedvariables-§5, anti-pattern #54): the presence test is
--- `stored[k] == nil`. It is NEVER `stored[k] or template[k]`.
---
--- `or` cannot tell UNSET from a stored `false`, `""` or `0`. This profile is
--- full of exactly those values — `frame.locked = false`, `header.title = ""`,
--- `rows.maxRows = 0`, `bars.border = false` — so an `or` merge would silently
--- reset a user's deliberate "off" back to the shipped "on" on every single
--- login, and would do it invisibly, because the setting they turned off would
--- simply be on again.
---
--- Arrays are left ALONE when present. `columns` is an ordered list the user
--- edits; key-filling it against the template would re-add columns they removed.
--- An absent columns array is a broken profile, not an older one, and gets the
--- template's copy so the window renders something.
---
--- @param stored table    the window config from SavedVariables
--- @param template table  defaults/Profile.lua's WINDOW_TEMPLATE (or a sub-table)
local function fillMissing(stored, template)
    for k, v in pairs(template) do
        if stored[k] == nil then
            stored[k] = copy(v)
        elseif type(v) == "table" and type(stored[k]) == "table" and v[1] == nil then
            -- Recurse into KEYED sub-tables only. `v[1] ~= nil` marks an array
            -- (the template's `columns` is empty, so this guard is about future
            -- array-shaped groups), and an array is the user's ordering to keep.
            fillMissing(stored[k], v)
        end
    end
end

--- Bring one stored window up to the current shape. Idempotent, shape-driven,
--- and safe to run on every login and every profile swap.
---
--- Shape-driven rather than version-gated on purpose. AceDB's defaults merge
--- backfills the declared `db.global.schemaVersion` default, 0, onto an account
--- that stored no stamp, so the version says only "unstamped" and nothing about
--- which keys a stored window already has. A window also arrives from a copy, a
--- reset or a hand edit whatever the stamp says. Keying on "is this key missing"
--- asks the only question that has a reliable answer.
---
--- @param w table
function Database.EnsureWindowShape(w)
    if type(w) ~= "table" then return end
    local template = NS.WINDOW_TEMPLATE
    if type(template) ~= "table" then return end
    fillMissing(w, template)
    if type(w.columns) ~= "table" then
        w.columns = {}
    end
end

--- The stored segment a window's `data` pins, or nil when it pins none.
---
--- THE ONE READER of `window.data.sessionID`. The row's "no pin" is
--- Constants.NO_SEGMENT (0), not nil, so a reader asking `~= nil` -- the test
--- every consumer used while the unpinned state was nil -- would take 0 for a
--- session and send it to the ID shim, which answers an empty session. Every
--- consumer asks here instead: the aggregator, the tooltip, the target list, the
--- drill-down, the export, the header and the diagnostics.
---
--- @param data table|nil  a window's `data` group
--- @return number|nil
function Database.PinnedSegment(data)
    local id = type(data) == "table" and data.sessionID or nil
    if type(id) == "number" and id > 0 then return id end
    return nil
end

--- The live window array. THE traversal seam: every consumer that reads or
--- mutates the registry goes through here, so the `db.profile.windows` walk
--- lives in exactly one place.
---
--- Returns an empty table rather than nil when the database is not up yet, so a
--- caller can iterate unconditionally. Callers that need to MUTATE the registry
--- at runtime go through modules/WindowManager.lua, which owns create / delete /
--- rename / duplicate and is the sender of WINDOWS_CHANGED. The one other writer
--- is the load pass, SeedWindows below, reached only through NS:RunMigrations.
---
--- @return table  array of window config tables
function Database.GetWindows()
    local db = NS.db
    if not (db and db.profile) then return {} end
    db.profile.windows = db.profile.windows or {}
    return db.profile.windows
end

--- One window by id, plus its index in the registry.
--- @param id number
--- @return table|nil window, number|nil index
function Database.FindWindow(id)
    if id == nil then return nil, nil end
    for i, w in ipairs(Database.GetWindows()) do
        if w.id == id then return w, i end
    end
    return nil, nil
end

--- Hand out the next window id and advance the counter.
---
--- Ids are monotonic and never reused. A reused id would let a deleted window's
--- id be handed to a new one, which would silently inherit the settings panel's
--- active-window pointer and every window-relative schema path aimed at it
--- (design §8).
---
--- @return number
function Database.NextWindowId()
    local db = NS.db
    if not (db and db.profile) then return 1 end
    local id = db.profile.nextWindowId or 1
    db.profile.nextWindowId = id + 1
    return id
end

--- The shipped display name for the nth window: "Multi Meters #3".
---
--- Lives here, beside the id counter, because two callers mint a default name
--- and neither may disagree with the other: SeedWindows below names the first
--- window of a fresh profile, and modules/WindowManager.lua names every window
--- created after it. The number is a plain one-up count of the windows that
--- exist, NOT the id — ids are never reused, so a player who deletes and
--- recreates would otherwise watch the name climb forever.
---
--- @param n number
--- @return string
function Database.WindowName(n)
    return NS.L["Multi Meters #%d"]:format(n)
end

-- True only while Database:OnProfileReset rebuilds (see SeedWindows below). A
-- file-local rather than a Database field: nothing outside this file may set it.
local reseedQuietly = false

--- Seed a brand-new profile with exactly one window, and normalize every window
--- already there.
---
--- "Brand new" is detected by an EMPTY registry, not by a version, for the same
--- reason EnsureWindowShape is shape-driven. And the seed lives here rather than
--- in defaults/Profile.lua's tree because AceDB's defaults merge would fold a
--- default window back into a profile the user had deleted their last window
--- from — resurrecting it on every login, with no way to refuse it.
---
--- Traced, except while OnProfileReset rebuilds: that handler's own line says
--- the profile is back to its one shipped window (debug-logging-§10 logs a
--- profile reset ONCE), so a second line here would restate it.
function Database.SeedWindows()
    local windows = Database.GetWindows()

    if #windows == 0 then
        local id = Database.NextWindowId()
        windows[1] = NS.DefaultWindow(id, Database.WindowName(1))
        if NS.State and NS.State.debug and not reseedQuietly then
            NS.Debug("Init", "seeded default window id=%d", id)
        end
    end

    for _, w in ipairs(windows) do
        -- An id can be missing on a window written by a build that predates the
        -- counter, or hand-edited into SavedVariables. Mint one rather than
        -- dropping the window: losing a user's configured window is worse than
        -- renumbering it.
        if w.id == nil then w.id = Database.NextWindowId() end
        Database.EnsureWindowShape(w)
    end
end

-- ---------------------------------------------------------------------------
-- Profile callbacks
-- ---------------------------------------------------------------------------

--
-- ONE HANDLER PER EVENT, because the one line each logs is worded by the event
-- (debug-logging-§10, the owner's final ruling). AceDB replacing the whole
-- profile -- a reset, a copy, a switch -- is wholesale replacement rather than a
-- write through the seam, so no `[Set]` line per row comes from any of them, and
-- each is logged ONCE, here:
--
--   reset   [Set] reset profile '<name>' to defaults
--   copy    [Set] copied profile '<source>' -> '<name>'
--   switch  [Profile] switched to '<name>'
--
-- A reset-all accepted from the General page's popup, which `/mm resetall`
-- opens too, reaches the reset line from inside the library's bulk bracket,
-- which then adds nothing (NS.Bulk, the settings runtime's bracket). The three
-- share one rebuild. The reset line is logged after it, and ends " (stopped by
-- an error)" when it raised.
--
-- THE RESET LINE CARRIES NO ROW COUNT, deliberately. debug-logging-§10 allows
-- one only where it is cheap to know, and it must be the rows the reset actually
-- CHANGED -- never every row the profile stores, which is the same number on
-- every reset and says nothing. Here it is not cheap and not even well defined:
-- a reset deletes every extra window, so "rows changed" would have to count
-- rows that no longer exist, and AceDBOptions' own Reset Profile button reaches
-- this handler with no chance to look at the profile first. So there is no count
-- to hand off, and none to go stale between two resets.

--- The profile now active. AceDB passes no key with OnProfileReset, and the key
--- it passes with OnProfileCopied is the SOURCE, so neither can be trusted for this.
local function activeKey(db)
    if db and db.GetCurrentProfile then return db:GetCurrentProfile() end
    return (db and db.keys and db.keys.profile) or "Default"
end

local function debugOn() return NS.State and NS.State.debug end

--- Everything downstream — every window, the settings panel, the aggregator's
--- caches — rebuilds off the single PROFILE_CHANGED message rather than off a
--- direct call from here (architecture-§4).
--- Re-take or release the `disabled` hold for the profile now active.
---
--- slash-commands-§7 names this explicitly: `enabled` is a stored setting like any
--- other and A PROFILE SWITCH CAN FLIP IT, with no verb and no checkbox touched.
--- A player switching to a profile where the addon is enabled expects it to come
--- up, so the latch has to be re-evaluated on all three AceDB callbacks -- which
--- is also why those callbacks are on the section's *what MUST survive* list and
--- cannot be dropped by the stand-down.
---
--- `Reevaluate` after `Set` rather than instead of it: `Set` fires an edge only
--- when the hold actually changes, and `Reevaluate` is idempotent, so a profile
--- that agrees with the old one produces no stand-down and no stand-up at all.
local function resyncEnabledHold()
    if NS.SyncEnabledHold then NS.SyncEnabledHold() end
    local lc = NS.lifecycle
    if lc and lc.Reevaluate then lc:Reevaluate() end
end

local function rebuild(key)
    -- FIRST, the first-run skin picker down, quietly (core/SkinSetup.lua): a showing belongs to the
    -- profile it opened on, and taking it down puts back a pending preview, so it lands before
    -- NS.ApplySkinChoice below and the new profile's own skin is the last one written.
    if NS.HideSkinPicker then NS.HideSkinPicker() end

    -- The newly-active profile may be a copy authored at an older schema
    -- version, or a reset back to an empty registry. Both need the full
    -- migrate-then-normalize pass before anything reads a window.
    NS:RunMigrations()

    -- The new profile's skin (core/SkinSetup.lua), before anything rebuilds: a switch, a copy and
    -- a reset each hand over a profile with its own `skin.*` pair, Scope and overrides.
    -- Skin:SetChoice repaints every frame recorded for this owner and fires OnLooksChanged
    -- whether or not a window was ever built, so the skin cannot depend on PROFILE_CHANGED.
    if NS.ApplySkinChoice then NS.ApplySkinChoice() end

    -- Per-session state that was derived from the OLD profile is now wrong.
    if NS.State then
        NS.State.SetActiveWindow(nil)
        NS.State.WipeCache()
    end

    resyncEnabledHold()

    fireProfileChanged(key)

    -- The first-run skin picker (core/SkinSetup.lua): a new or reset profile starts from the
    -- defaults, `pickerSeen` false, so it shows, a fresh showing over the new profile's skin; one
    -- that has seen it stays down. After the latch, so a profile with the addon off shows nothing.
    if NS.MaybeShowSkinPicker then NS.MaybeShowSkinPicker() end
end

--- AceDB calls each of these as `obj:method(event, db, key)`.
function Database:OnProfileChanged(_, db, newProfileKey)
    local key = newProfileKey or activeKey(db)
    if debugOn() then NS.Debug("Profile", "switched to '%s'", tostring(key)) end
    rebuild(key)
end

function Database:OnProfileReset(_, db)
    local key = activeKey(db)
    -- The line below says the profile is back to its one shipped window, so the
    -- seed's own [Init] trace would be a second line about the same act.
    -- Released under pcall, so a raising rebuild cannot silence every later seed.
    reseedQuietly = true
    local ok, err = pcall(rebuild, key)
    reseedQuietly = false
    -- Logged AFTER the rebuild, so a line never reads as a finished reset when
    -- the rebuild then raised: that one ends " (stopped by an error)", the
    -- marker NS.Bulk's line carries (LibKa0s-Schema-1.0's bracket).
    if debugOn() then
        NS.Debug("Set", "reset profile '%s' to defaults%s", tostring(key),
            ok and "" or " (stopped by an error)")
    end
    if not ok then error(err, 0) end
end

function Database:OnProfileCopied(_, db, sourceKey)
    local key = activeKey(db)
    if debugOn() then
        NS.Debug("Set", "copied profile '%s' \226\134\146 '%s'", tostring(sourceKey), tostring(key))
    end
    rebuild(key)
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

--- Build the AceDB instance. Called once, from NS:OnInitialize().
---
--- After this returns, NS.db is the live AceDB object — a contract every module
--- relies on and the reason the call is first in OnInitialize.
function NS:InitDB()
    local AceDB = LibStub and LibStub("AceDB-3.0", true)
    if not AceDB then
        -- Reached at call time, not captured: core/CoreSetup.lua publishes the
        -- printer and the TOC order between the two files must not be able to
        -- freeze a nil in.
        local out = NS.Util and NS.Util.print
        if out then out("AceDB-3.0 is missing — settings cannot be loaded.") end
        return
    end

    -- The third argument is `true`, which AceDB expands to the shared "Default"
    -- profile. Omitting it falls back to a PER-CHARACTER profile, which
    -- contradicts the documentation and is the source of every "each new
    -- character lands on its own settings" report in the collection. Players who
    -- want per-character opt in through the Profiles page.
    local db = AceDB:New("MultiMetersDB", NS.defaults, true)
    NS.db         = db
    Database.db   = db

    -- Migrate, then seed and normalize the window registry. RunMigrations does
    -- both, so Init and a profile swap share one path.
    NS:RunMigrations()

    -- AceDB calls these as `obj:method(event, db, key)` given the
    -- (self, "OnProfileChanged", "OnProfileChanged") registration form.
    -- One handler per event: each logs its own line (see "Profile callbacks").
    db.RegisterCallback(Database, "OnProfileChanged", "OnProfileChanged")
    db.RegisterCallback(Database, "OnProfileCopied",  "OnProfileCopied")
    db.RegisterCallback(Database, "OnProfileReset",   "OnProfileReset")
end
