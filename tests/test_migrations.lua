-- tests/test_migrations.lua — who owns the schema stamp (savedvariables-§1, v2.65.0).
--
-- The rule these cases pin is the executable form of savedvariables-§1's stamp ownership:
--
--   * the defaults declare `global.schemaVersion = 0`, never the current version. AceDB strips a
--     stored value equal to its default at logout, and backfills a declared default onto a legacy
--     account that stored no stamp; 0 has neither problem.
--   * the RUNNER advances the stamp, and only past a step that returned without raising. A step
--     never writes `schemaVersion` itself, so a step that raises leaves the stamp where it was and
--     the next load retries it.
--   * a profile-scoped step reaches every stored profile, not only the active one.
--   * every step is idempotent against a fresh default profile, which is why an unstamped account
--     (a fresh install reads 0) can safely walk the whole ladder from v1.
--
-- The runner's step table is reached through `NS.Database.__migrations`, the documented test seam
-- in core/Database.lua. Each T.load builds a fresh instance, so a step replaced here is replaced in
-- that instance alone, and every case restores what it replaced before it asserts.

local T = _G.MULTIMETERS_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

--- A loaded instance with no database yet, its step table optionally rewritten by `patch` before
--- the REAL NS:InitDB() runs against `saved` as the SavedVariables global.
local function initWith(saved, patch)
    local inst = T.load{ initDB = false, options = false }
    if patch then patch(inst.NS.Database.__migrations) end
    _G.MultiMetersDB = saved
    inst.NS:InitDB()
    return inst
end

--- Every difference between two values, as "path: a vs b" lines.
local function diff(a, b, path, out)
    path, out = path or "profile", out or {}
    if type(a) ~= "table" or type(b) ~= "table" then
        if a ~= b then out[#out + 1] = ("%s: %s vs %s"):format(path, tostring(a), tostring(b)) end
        return out
    end
    for k, v in pairs(a) do diff(v, b[k], path .. "." .. tostring(k), out) end
    for k, v in pairs(b) do
        if a[k] == nil then diff(nil, v, path .. "." .. tostring(k), out) end
    end
    return out
end

--- AceDB-3.0's removeDefaults, the logout strip: a stored scalar equal to its default is removed,
--- and a default table left empty goes with it. Run here over `global` because that is the section
--- the stamp lives in.
local function stripDefaults(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dest[k]) == "table" then
            stripDefaults(dest[k], v)
            if next(dest[k]) == nil then dest[k] = nil end
        elseif dest[k] == v then
            dest[k] = nil
        end
    end
end

--- A v1-shaped profile: per-stat column widths and the old showBar flag, which the ladder turns
--- into the full catalog of ticked columns with no width.
local function v1Profile(id)
    return {
        nextWindowId = id + 1,
        windows = { {
            id = id,
            frame   = { width = 480, padding = 6 },
            columns = {
                { stat = "DamageDone", width = 92, showBar = true },
                { stat = "Deaths",     width = 44, showBar = true },
            },
        } },
    }
end

test("migrations: the defaults declare schemaVersion 0, never the current version", function()
    -- red under: `schemaVersion = 1` (or the current version) in defaults/Profile.lua.
    assertEqual(NS.defaults.global.schemaVersion, 0,
        "a default equal to a stored stamp is stripped at logout; 0 is never a stored stamp")
    assertTrue(NS.SCHEMA_VERSION > 0, "the runner's target is published as NS.SCHEMA_VERSION")
end)

test("migrations: a fresh install runs every step and lands on the default profile", function()
    -- An unstamped account reads 0 and starts the walk at v1, so every step runs over the fresh
    -- default profile. That is only safe because every step is idempotent against one: the
    -- profile the walk leaves must be exactly the one a migration-free InitDB builds.
    -- red under: a step that rewrites a fresh default profile, or a runner that skips steps.
    local ran = {}
    local walked = initWith({}, function(steps)
        for from, step in pairs(steps) do
            steps[from] = function(db) ran[#ran + 1] = from; return step(db) end
        end
    end)
    local target = walked.NS.SCHEMA_VERSION
    assertEqual(#ran, target - 1, "every step from v1 to the target must run on a fresh install")
    for i, from in ipairs(ran) do assertEqual(from, i, "the steps run in order") end
    assertEqual(walked.NS.db.global.schemaVersion, target)

    local plain = initWith({}, function(steps)
        for from in pairs(steps) do steps[from] = function() end end
    end)
    assertEqual(plain.NS.db.global.schemaVersion, target,
        "the runner, not the step, advances the stamp: no-op steps still reach the target")
    local found = diff(walked.NS.db.profile, plain.NS.db.profile)
    assertEqual(#found, 0, "a step changed a fresh default profile: " .. table.concat(found, "; "))
end)

test("migrations: a step that raises leaves the stamp at its from value", function()
    -- The stamp moves only past a step that returned. A raising v3 step must leave the account at
    -- v3 so the next load retries it, rather than stamped past a step that never finished.
    -- red under: advancing the stamp before calling the step, or a step stamping itself.
    local inst = T.load{ initDB = false, options = false }
    local steps = inst.NS.Database.__migrations
    local original = steps[3]
    steps[3] = function() error("step 3 failed") end
    _G.MultiMetersDB = { profiles = { Default = v1Profile(1) }, global = { schemaVersion = 1 } }
    local ok = pcall(inst.NS.InitDB, inst.NS)
    steps[3] = original
    assertFalse(ok, "the raising step must surface its error")
    assertEqual(inst.NS.db.global.schemaVersion, 3,
        "v1 and v2 completed, so the stamp is 3 and v3 is retried next load")

    inst.NS:RunMigrations()
    assertEqual(inst.NS.db.global.schemaVersion, inst.NS.SCHEMA_VERSION,
        "the retry walks the rest of the ladder")
end)

test("migrations: the stamp is stored raw and survives AceDB's logout strip", function()
    -- The kit's AceDB fake strips defaults from a profile on a swap but never touches `global`,
    -- so the logout strip is applied here by hand, as AceDB-3.0's removeDefaults does it.
    -- red under: a `global.schemaVersion` default equal to the current version.
    local inst = initWith({})
    local sv = _G.MultiMetersDB
    assertEqual(rawget(sv.global, "schemaVersion"), inst.NS.SCHEMA_VERSION,
        "the walk must leave the target in the raw SavedVariables table")
    stripDefaults(sv.global, inst.NS.defaults.global)
    assertEqual(sv.global.schemaVersion, inst.NS.SCHEMA_VERSION,
        "the stamp was stripped at logout, so the next login would read the default back")
end)

test("migrations: a legacy unstamped account migrates every stored profile", function()
    -- An account from before the runner stamped anything stores no schemaVersion at all. It reads
    -- 0, walks from v1, and a profile-scoped step reaches the inactive profile as well as the
    -- active one.
    -- red under: a current-version default that makes the account read as already migrated, or a
    -- profile-scoped step gated to db.profile alone.
    local inst = initWith({
        profiles = { Default = v1Profile(1), Raid = v1Profile(4) },
        global   = {},
    })
    local Const = inst.NS.Constants
    for _, name in ipairs({ "Default", "Raid" }) do
        local w = inst.NS.db.sv.profiles[name].windows[1]
        assertEqual(#w.columns, #Const.STATS, name .. " was left in the v1 column shape")
        assertEqual(w.columns[1].stat, "DamageDone", name .. " lost the player's column order")
        assertEqual(w.columns[1].width, nil, name .. " kept the retired per-column width")
        assertTrue(w.columns[1].enabled, name .. "'s shown column must arrive enabled")
    end
    assertEqual(inst.NS.db.global.schemaVersion, inst.NS.SCHEMA_VERSION)
end)
