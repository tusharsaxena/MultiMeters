-- tests/test_database.lua — core/Database.lua: the AceDB instance, the window
-- registry's shape, and the profile callbacks. The migration runner and its
-- steps were peeled into tests/test_database_migrations.lua (layout-§1).
--
-- THE CASE THIS SUITE EXISTS FOR is the `== nil` merge (savedvariables-§5,
-- anti-pattern #54). AceDB's defaults merge cannot reach inside an ARRAY — it
-- fills keys of tables it knows about, and it does not know that
-- `profile.windows[3]` is supposed to look like a window — so the fill is this
-- addon's own, and the rule that makes it correct is that a missing key is
-- detected with `stored[k] == nil` and NEVER with `stored[k] or template[k]`.
--
-- `or` cannot tell UNSET from a stored `false`, `""` or `0`, and this profile is
-- full of exactly those values. An `or` merge would reset a user's deliberate
-- "off" back to the shipped "on" on EVERY LOGIN, invisibly — the setting they
-- turned off would simply be on again, with no error and nothing in the log. So
-- the case below stores a false, an empty string and a zero, runs the real merge,
-- and asserts all three survived.

local T = _G.MULTIMETERS_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MSG = NS.Constants.MSG

-- ---------------------------------------------------------------------------
-- Driving a profile swap
-- ---------------------------------------------------------------------------
--
-- core/Database.lua registers its profile callbacks in CallbackHandler's
-- METHOD-NAME form — `db.RegisterCallback(Database, "OnProfileChanged",
-- "OnProfileChanged")` — which AceDB dispatches as `target:method(event, db,
-- key)`. The vendored AceDB fake in tests/_kit/mock_base.lua dispatches FUNCTION
-- callbacks only, so it raises on that form rather than calling the handler.
--
-- The profile STATE has already moved by the time it raises (SetProfile assigns
-- `db.profile` before it fires), so the helpers below let the fake do the state
-- change and then supply the dispatch it cannot. The `if not ok` guard means a
-- future fake that grows the method-name form dispatches once, through itself,
-- and these cases keep asserting the same thing rather than double-firing.
--
-- What a direct dispatch cannot show is that the REGISTRATION is really that
-- form; that half has its own case below, read off the source.

local function dispatchProfileChange(inst, event, key)
    inst.NS.Database[event](inst.NS.Database, event, inst.NS.db, key)
end

--- Switch to `key`, then make sure the handler ran exactly once.
local function swapProfile(inst, key)
    local ok = pcall(inst.NS.db.SetProfile, inst.NS.db, key)
    if not ok then dispatchProfileChange(inst, "OnProfileChanged", key) end
end

--- Reset the active profile, then make sure the handler ran exactly once.
--- AceDB passes nil for the key on OnProfileReset, which is the case the
--- handler's substitution exists for.
local function resetProfile(inst)
    local ok = pcall(inst.NS.db.ResetProfile, inst.NS.db)
    if not ok then dispatchProfileChange(inst, "OnProfileChanged", nil) end
end

--- A loaded instance with NO database yet, so a case can seed the SavedVariables
--- global and then drive the REAL NS:InitDB() against it.
local function preSeeded(saved)
    local inst = T.load{ initDB = false, options = false }
    _G.MultiMetersDB = saved
    inst.NS:InitDB()
    inst.NS:RunMigrations()
    return inst
end

-- ── the AceDB instance ──────────────────────────────────────────────────────

test("Database: InitDB publishes the live instance under both names", function()
    local inst = T.load{}
    assertTrue(inst.NS.db ~= nil, "NS.db is the contract every module relies on")
    assertTrue(inst.NS.Database.db == inst.NS.db, "Database.db must be the same object")
    assertEqual(type(inst.NS.db.profile), "table")
    assertEqual(type(inst.NS.db.global), "table")
end)

test("Database: the profile is the SHARED Default, not a per-character one", function()
    -- AceDB:New's third argument is `true`, which it expands to the shared
    -- "Default" profile. Omitting it falls back to a PER-CHARACTER profile,
    -- which contradicts the documentation and is the source of every "each new
    -- character lands on its own settings" report in the collection.
    -- red under: dropping the third argument from the AceDB:New call.
    local fh = assert(io.open((T.root or ".") .. "/core/Database.lua", "r"))
    local src = fh:read("*a")
    fh:close()
    assertTrue(src:match('AceDB:New%("MultiMetersDB",%s*NS%.defaults,%s*true%)') ~= nil,
        "InitDB must pass `true` for the shared Default profile")
    assertEqual(T.load{}.NS.db:GetCurrentProfile(), "Default")
end)

test("Database: with AceDB absent, InitDB says so and leaves NS.db nil", function()
    -- A broken install. The printer is reached at CALL time rather than captured,
    -- so the TOC order between core/CoreSetup.lua and this file cannot freeze a
    -- nil in.
    local inst = T.load{ initDB = false, options = false,
        mutate = function(m) m.__libs["AceDB-3.0"] = nil end }
    local before = #inst.mocks.__chat
    inst.NS:InitDB()
    assertNil(inst.NS.db)
    assertTrue(#inst.mocks.__chat > before, "a missing AceDB must be reported, not swallowed")
    assertTrue(inst.mocks.__chat[#inst.mocks.__chat]:find("AceDB", 1, true) ~= nil)
end)

-- ── the `== nil` merge — the case this suite exists for ─────────────────────

test("Database: a stored false, \"\" and 0 all survive the window shape merge", function()
    -- savedvariables-§5 / anti-pattern #54, proved rather than asserted about.
    -- Every value here is one the shipped template sets to something TRUTHY, so
    -- an `or` merge would silently overwrite all three.
    -- red under: rewriting fillMissing as `stored[k] = stored[k] or template[k]`.
    local tpl = NS.WINDOW_TEMPLATE
    assertTrue(tpl.frame.clampToScreen == true, "the fixture needs a truthy shipped default")
    assertEqual(tpl.frame.strata, "MEDIUM")
    assertTrue(tpl.frame.scale > 0)
    assertTrue(tpl.rows.alwaysShowSelf == true)
    assertTrue(tpl.tooltip.maxSpells > 0)

    local stored = {
        id = 1,
        frame = { clampToScreen = false, strata = "", scale = 0 },
        rows  = { alwaysShowSelf = false },
        tooltip = { maxSpells = 0 },
    }
    NS.Database.EnsureWindowShape(stored)

    assertEqual(stored.frame.clampToScreen, false, "a stored false was reset to the shipped true")
    assertEqual(stored.frame.strata, "", "a stored empty string was reset to the shipped value")
    assertEqual(stored.frame.scale, 0, "a stored 0 was reset to the shipped 1.0")
    assertEqual(stored.rows.alwaysShowSelf, false)
    assertEqual(stored.tooltip.maxSpells, 0)
end)

test("Database: the same false survives a REAL login — SavedVariables to merged profile",
function()
    -- The unit case above proves the function; this proves the wiring. An `or`
    -- merge anywhere on the InitDB path resets the user's choice on every login,
    -- and the only way to see that is to come in through the saved global.
    local inst = preSeeded({
        profiles = { Default = { windows = { { id = 1, name = "Mine",
            frame = { clampToScreen = false, scale = 0 },
            rows  = { alwaysShowSelf = false } } } } },
        global   = { schemaVersion = 1 },
    })
    local w = inst.NS.Database.FindWindow(1)
    assertTrue(w ~= nil, "the stored window must survive InitDB")
    assertEqual(w.frame.clampToScreen, false)
    assertEqual(w.frame.scale, 0)
    assertEqual(w.rows.alwaysShowSelf, false)
    assertEqual(w.name, "Mine", "and the user's name must not be replaced by the template's")
end)

test("Database: the merge fills every key the stored window is missing", function()
    -- The other half of the same function: an old profile written before a
    -- setting existed must come up with the shipped value rather than nil, or
    -- every reader of that setting gets nil at render time.
    local stored = { id = 9 }
    NS.Database.EnsureWindowShape(stored)
    for group, values in pairs(NS.WINDOW_TEMPLATE) do
        if type(values) == "table" then
            assertEqual(type(stored[group]), "table", "group " .. group .. " was not filled")
            for key in pairs(values) do
                assertTrue(stored[group][key] ~= nil,
                    "window." .. group .. "." .. key .. " was not filled")
            end
        end
    end
end)

test("Database: the merge deep-copies, so no window shares a sub-table with the template",
function()
    -- Two windows aliasing one sub-table is the classic profile bug: editing
    -- window 2's bar color silently edits window 1's. The template is the shared
    -- object both would alias.
    -- red under: `stored[k] = v` instead of `stored[k] = copy(v)`.
    local a, b = { id = 1 }, { id = 2 }
    NS.Database.EnsureWindowShape(a)
    NS.Database.EnsureWindowShape(b)
    assertFalse(a.frame == NS.WINDOW_TEMPLATE.frame, "the window aliases the shipped template")
    assertFalse(a.frame == b.frame, "two windows share one frame table")
    assertFalse(a.frame.backdropColor == b.frame.backdropColor, "two windows share one color table")
    local shipped = NS.WINDOW_TEMPLATE.frame.width
    a.frame.width = shipped + 999
    assertEqual(b.frame.width, shipped, "writing one window moved the other")
    assertEqual(NS.WINDOW_TEMPLATE.frame.width, shipped, "writing a window moved the template")
end)

test("Database: the three profile callbacks are registered in the method-name form", function()
    -- AceDB dispatches `db.RegisterCallback(target, event, "MethodName")` as
    -- `target:MethodName(event, db, key)`, which is the signature
    -- Database:OnProfileChanged is written for. Registering a bare FUNCTION
    -- instead would call it with the event as `self`, and `db` and the key would
    -- land one argument to the left — so `newProfileKey` would be the db table.
    -- All three events must be covered: a copy and a reset change the active
    -- profile just as a swap does. EACH HAS ITS OWN HANDLER, because
    -- debug-logging-§10 words the one line by the event, and one shared handler
    -- called a reset and a copy "switched to".
    -- red under: dropping a registration, or folding two events onto one handler.
    local fh = assert(io.open((T.root or ".") .. "/core/Database.lua", "r"))
    local src = fh:read("*a")
    fh:close()
    for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do
        assertTrue(src:match('RegisterCallback%(Database,%s*"' .. event
            .. '",%s*"' .. event .. '"%)') ~= nil,
            event .. " is not registered against Database:" .. event)
    end
end)

test("Database: each profile event is logged ONCE, in words chosen by the event", function()
    -- debug-logging-§10, the owner's final ruling: AceDB replacing the whole
    -- profile is wholesale replacement, logged once by the profile handler. A
    -- reset and a copy are [Set] lines; a switch keeps the [Profile] line it
    -- always had. The copy names its source, which AceDB passes as the key, and
    -- the rebuild still names the profile now ACTIVE, not the source.
    -- red under: the three events sharing OnProfileChanged.
    local inst = T.load{}
    local NSi = inst.NS
    NSi.State.debug = true
    local keys = {}
    NSi.NewBusTarget():RegisterMessage(MSG.PROFILE_CHANGED, function(_, p)
        keys[#keys + 1] = p and p.newProfileKey
    end)

    local lines, original = {}, NSi.Debug
    NSi.Debug = function(tag, fmt, ...)
        if tag ~= "Set" and tag ~= "Profile" then return end
        local a = { ... }
        for i = 1, select("#", ...) do a[i] = tostring(a[i]) end
        lines[#lines + 1] = "[" .. tag .. "] " .. tostring(fmt):format(a[1], a[2], a[3], a[4])
    end
    local ok, err = pcall(function()
        resetProfile(inst)
        swapProfile(inst, "Raid")
        NSi.db:CopyProfile("Default")
    end)
    NSi.Debug = original
    assertTrue(ok, tostring(err))

    assertEqual(#lines, 3, table.concat(lines, " | "))
    assertEqual(lines[1], "[Set] reset profile 'Default' to defaults")
    assertEqual(lines[2], "[Profile] switched to 'Raid'")
    assertEqual(lines[3], "[Set] copied profile 'Default' \226\134\146 'Raid'")
    assertEqual(keys[3], "Raid", "the copy's rebuild must name the active profile, not the source")
end)

test("Database: the reset line carries NO row count -- never the rows the profile stores", function()
    -- debug-logging-§10: a count on the reset line must be the rows the reset
    -- actually CHANGED, or be left off. The profile's stored-row total is neither:
    -- it is the same on every reset. Here "changed" is not cheap -- a reset deletes
    -- every extra window -- so the line carries none, and with no count handed from
    -- the reset path to this handler there is nothing to go stale between two
    -- resets. So a reset of a moved profile and a reset of an untouched one read
    -- the same.
    -- red under: a `(N rows)` suffix of any kind, including the stored-row total.
    local inst = T.load{}
    local NSi = inst.NS
    NSi.State.debug = true
    assertTrue(NSi.WindowManager:Create("Second"))
    NSi.Database.GetWindows()[1].frame.width = 401

    local lines, original = {}, NSi.Debug
    NSi.Debug = function(tag, fmt, ...)
        if tag ~= "Set" then return end
        local a = { ... }
        for i = 1, select("#", ...) do a[i] = tostring(a[i]) end
        lines[#lines + 1] = tostring(fmt):format(a[1], a[2], a[3], a[4])
    end
    local ok, err = pcall(function()
        resetProfile(inst)   -- a profile with a moved row and a second window
        resetProfile(inst)   -- the same profile, already at its defaults
    end)
    NSi.Debug = original
    assertTrue(ok, tostring(err))

    assertEqual(#lines, 2, table.concat(lines, " | "))
    assertEqual(lines[1], "reset profile 'Default' to defaults")
    assertEqual(lines[2], lines[1], "an untouched profile's reset must read the same, not carry a count")
end)

--- Every [Set] line NS.Debug is handed, formatted, until the returned restore runs.
local function heardSet(NSi)
    local lines, original = {}, NSi.Debug
    NSi.Debug = function(tag, fmt, ...)
        if tag ~= "Set" then return end
        local a = { ... }
        for i = 1, select("#", ...) do a[i] = tostring(a[i]) end
        lines[#lines + 1] = tostring(fmt):format(a[1], a[2], a[3], a[4])
    end
    return lines, function() NSi.Debug = original end
end

test("Database: the reset line is logged AFTER the rebuild, not before it", function()
    -- A line logged first reads as a finished reset even when the rebuild then
    -- raises. So the rebuild runs, then the line. red under: the Debug call
    -- ahead of the pcall.
    local inst = T.load{}
    local NSi = inst.NS
    NSi.State.debug = true
    local lines, restore = heardSet(NSi)
    local seenAtRebuild
    NSi.NewBusTarget():RegisterMessage(MSG.PROFILE_CHANGED, function() seenAtRebuild = #lines end)

    local ok, err = pcall(NSi.Database.OnProfileReset, NSi.Database, "OnProfileReset", NSi.db)
    restore()
    assertTrue(ok, tostring(err))
    assertEqual(seenAtRebuild, 0, "the reset line was logged before the rebuild ran")
    assertEqual(table.concat(lines, " | "), "reset profile 'Default' to defaults")
end)

test("Database: a reset whose rebuild raises is logged once, marked, and re-raised", function()
    -- red under: the line logged before the rebuild (unmarked), or no line at all.
    local inst = T.load{}
    local NSi = inst.NS
    NSi.State.debug = true
    local boom = {}
    NSi.RunMigrations = function() error(boom) end
    local lines, restore = heardSet(NSi)

    local ok, err = pcall(NSi.Database.OnProfileReset, NSi.Database, "OnProfileReset", NSi.db)
    restore()
    assertEqual(ok, false)
    assertEqual(err, boom, "the rebuild's error comes back unwrapped")
    assertEqual(table.concat(lines, " | "), "reset profile 'Default' to defaults (stopped by an error)")
end)

test("Database: a stored columns array is left exactly as the user ordered it", function()
    -- `columns` is an ordered list the user edits. Key-filling it against the
    -- template would re-add columns they removed, on every login.
    -- red under: recursing into arrays in fillMissing.
    local stored = { id = 3, columns = { { stat = "Deaths", width = 44, showBar = false } } }
    NS.Database.EnsureWindowShape(stored)
    assertEqual(#stored.columns, 1, "the user's one-column layout grew back")
    assertEqual(stored.columns[1].stat, "Deaths")
    assertEqual(stored.columns[1].showBar, false)
end)

test("Database: an ABSENT columns array becomes an empty array, never nil", function()
    -- A broken profile, not an older one. Every renderer iterates this
    -- unconditionally, so nil would be an error at draw time.
    local stored = { id = 4 }
    NS.Database.EnsureWindowShape(stored)
    assertEqual(type(stored.columns), "table")
    local wrongType = { id = 5, columns = "not a table" }
    NS.Database.EnsureWindowShape(wrongType)
    assertEqual(type(wrongType.columns), "table")
end)

test("Database: EnsureWindowShape is idempotent", function()
    -- It runs on every login and on every profile swap. A second pass that
    -- changed anything would mean the first pass did not finish.
    local w = { id = 6, frame = { scale = 0 } }
    NS.Database.EnsureWindowShape(w)
    local snapshot = {}
    for k, v in pairs(w.frame) do snapshot[k] = v end
    NS.Database.EnsureWindowShape(w)
    for k, v in pairs(snapshot) do assertEqual(w.frame[k], v, "frame." .. k .. " moved") end
end)

test("Database: EnsureWindowShape refuses a non-table without raising", function()
    NS.Database.EnsureWindowShape(nil)
    NS.Database.EnsureWindowShape("not a window")
    NS.Database.EnsureWindowShape(7)
end)

-- ── the registry ────────────────────────────────────────────────────────────

test("Database: GetWindows answers an empty table before the database is up", function()
    -- Callers iterate it unconditionally. Returning nil would put an existence
    -- check in every consumer for a case none of them can act on.
    local inst = T.load{ initDB = false, options = false }
    assertEqual(type(inst.NS.Database.GetWindows()), "table")
    assertEqual(#inst.NS.Database.GetWindows(), 0)
end)

test("Database: a fresh profile is seeded with exactly one window", function()
    local inst = T.load{}
    local windows = inst.NS.Database.GetWindows()
    assertEqual(#windows, 1)
    assertEqual(windows[1].name, "Multi Meters #1")
    assertEqual(windows[1].id, 1)
    assertTrue(#windows[1].columns > 0, "the seeded window must ship with its default columns")
end)

test("Database: the seed window is NOT an AceDB default, so a deleted last window stays deleted",
function()
    -- If `windows` carried a default entry, AceDB's merge would fold it back
    -- into a profile the user had emptied — resurrecting it on every login with
    -- no way to refuse.
    -- red under: putting a window into defaults/Profile.lua's `profile.windows`.
    assertEqual(#NS.defaults.profile.windows, 0, "the defaults tree must ship an EMPTY registry")
    local inst = preSeeded({
        profiles = { Default = { windows = {} } },
        global   = { schemaVersion = 1 },
    })
    -- A brand-new EMPTY registry does get its seed — that is the "first login"
    -- path — so the distinction is proved by deleting AFTER the seed instead.
    local windows = inst.NS.Database.GetWindows()
    for i = #windows, 1, -1 do windows[i] = nil end
    swapProfile(inst, "Other")
    swapProfile(inst, "Default")
    assertEqual(#inst.NS.Database.GetWindows(), 1,
        "the registry is reseeded by SeedWindows, not resurrected by the defaults merge")
end)

test("Database: FindWindow answers the window and its index, and nil for anything else", function()
    local inst = T.load{}
    local w, i = inst.NS.Database.FindWindow(1)
    assertTrue(w ~= nil)
    assertEqual(i, 1)
    assertNil((inst.NS.Database.FindWindow(999)))
    assertNil((inst.NS.Database.FindWindow(nil)))
end)

test("Database: window ids are monotonic and never reused", function()
    -- A reused id would let a deleted window's id be handed to a new one, which
    -- would silently inherit the settings panel's active-window pointer and
    -- every window-relative schema path aimed at it.
    -- red under: deriving the next id from #windows + 1.
    local inst = T.load{}
    local D = inst.NS.Database
    local first = D.NextWindowId()
    local second = D.NextWindowId()
    assertTrue(second > first, "ids must advance")
    -- Delete every window and ask again: the counter must not rewind.
    local windows = D.GetWindows()
    for i = #windows, 1, -1 do windows[i] = nil end
    assertTrue(D.NextWindowId() > second, "the counter rewound after a delete")
end)

test("Database: NextWindowId answers 1 with no database rather than raising", function()
    local inst = T.load{ initDB = false, options = false }
    assertEqual(inst.NS.Database.NextWindowId(), 1)
end)

test("Database: a stored window with no id is given one rather than dropped", function()
    -- Written by a build that predates the counter, or hand-edited into
    -- SavedVariables. Losing a user's configured window is worse than
    -- renumbering it.
    local inst = preSeeded({
        profiles = { Default = { windows = { { name = "Nameless" } }, nextWindowId = 5 } },
        global   = { schemaVersion = 1 },
    })
    local windows = inst.NS.Database.GetWindows()
    assertEqual(#windows, 1, "the window must not be dropped")
    assertEqual(windows[1].name, "Nameless")
    assertEqual(windows[1].id, 5, "and must be minted the next id, not id 1")
end)

-- ── profile callbacks ───────────────────────────────────────────────────────

test("Database: a profile swap publishes PROFILE_CHANGED exactly once, with the new key",
function()
    -- Everything downstream rebuilds off this one message rather than off a
    -- direct call from core/Database.lua (architecture-§4).
    local inst = T.load{}
    local seen = { n = 0 }
    local target = inst.NS.NewBusTarget()
    target:RegisterMessage(MSG.PROFILE_CHANGED, function(_, payload)
        seen.n = seen.n + 1
        seen.key = payload and payload.newProfileKey
    end)
    swapProfile(inst, "Raid")
    assertEqual(seen.n, 1)
    assertEqual(seen.key, "Raid")
end)

test("Database: core/Database.lua is the only sender of PROFILE_CHANGED", function()
    local senders = {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        local fh = io.open((T.root or ".") .. "/" .. rel, "r")
        local src = fh and fh:read("*a") or ""
        if fh then fh:close() end
        src = src:gsub("%-%-[^\r\n]*", "")
        if src:match("SendMessage%(%s*[%w_%.]*PROFILE_CHANGED") then senders[#senders + 1] = rel end
    end
    assertEqual(table.concat(senders, ", "), "core/Database.lua")
end)

test("Database: a profile swap clears the session state derived from the old profile", function()
    -- The active-window pointer names an id that may not exist in the new
    -- profile, and every cache was keyed against the old one.
    local inst = T.load{}
    inst.NS.State.SetActiveWindow(1)
    inst.NS.State.Cache("Roster").guid = "stale"
    swapProfile(inst, "Raid")
    assertNil(inst.NS.State.activeWindowId, "the active window pointer must be cleared")
    assertNil(inst.NS.State.Cache("Roster").guid, "the caches must be wiped")
end)

test("Database: the profile a swap lands on is migrated and normalized before anything reads it",
function()
    -- A copy may have been authored at an older schema version, and a reset
    -- lands on an empty registry. Both need the full pass before a window is
    -- read, which is why OnProfileChanged calls RunMigrations rather than
    -- assuming Init already did.
    local inst = T.load{}
    swapProfile(inst, "Raid")
    local windows = inst.NS.Database.GetWindows()
    assertEqual(#windows, 1, "the new profile must be seeded")
    assertEqual(type(windows[1].frame), "table", "and normalized")
end)

test("Database: a profile RESET re-seeds rather than leaving an empty registry", function()
    -- AceDB passes nil for the profile key on OnProfileReset, so the handler
    -- substitutes the active one. A nil key reaching the message payload would
    -- be a subscriber told the profile changed to nothing.
    local inst = T.load{}
    local seen = {}
    local target = inst.NS.NewBusTarget()
    target:RegisterMessage(MSG.PROFILE_CHANGED, function(_, p) seen.key = p and p.newProfileKey end)
    resetProfile(inst)
    assertEqual(seen.key, "Default", "the reset must name the active profile, not nil")
    assertEqual(#inst.NS.Database.GetWindows(), 1)
end)
