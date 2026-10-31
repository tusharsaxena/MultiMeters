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
-- in core/Database_Migrations.lua. Each T.load builds a fresh instance, so a step replaced here is replaced in
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

-- ---------------------------------------------------------------------------
-- v15 -> v16: the window's minimize keys, spelled the US way (localization-§5)
-- ---------------------------------------------------------------------------

--- A v15-shaped profile: two windows, each carrying the two British-spelled frame keys.
local function v15Profile(id)
    local function window(n)
        return { id = n, frame = { minimised = true, showMinimise = false } }
    end
    return { nextWindowId = id + 2, windows = { window(id), window(id + 1) } }
end

test("migrations: v16 moves both minimize keys onto the US spelling in every window of every profile", function()
    -- A find-and-replace on the defaults alone would orphan every stored collapse and every hidden
    -- minimize control: the old keys would sit in the savedvariables read by nothing.
    -- red under: no v15 -> v16 step, or one that walks db.profile alone.
    local inst = initWith({
        profiles = { Default = v15Profile(1), Raid = v15Profile(4) },
        global   = { schemaVersion = 15 },
    })
    assertEqual(inst.NS.db.global.schemaVersion, inst.NS.SCHEMA_VERSION)
    for _, name in ipairs({ "Default", "Raid" }) do
        local windows = inst.NS.db.sv.profiles[name].windows
        assertEqual(#windows, 2, name .. " lost a window")
        for i, w in ipairs(windows) do
            local where = name .. " window " .. i
            assertEqual(w.frame.minimized, true, where .. " lost its collapsed state")
            assertEqual(w.frame.showMinimize, false, where .. " lost its hidden control")
            assertEqual(rawget(w.frame, "minimised"), nil, where .. " kept the old collapse key")
            assertEqual(rawget(w.frame, "showMinimise"), nil, where .. " kept the old control key")
        end
    end
end)

test("migrations: the v16 step run twice is a no-op, and never overwrites a US key", function()
    -- Idempotent: a second run over a migrated account changes nothing. A frame that somehow holds
    -- both spellings keeps the US one, which is the key the addon has been reading.
    -- red under: an unconditional `w.frame.minimized = w.frame.minimised`.
    local inst = initWith({
        profiles = { Default = v15Profile(1) },
        global   = { schemaVersion = 15 },
    })
    local step = inst.NS.Database.__migrations[15]
    local before = diff(inst.NS.db.sv.profiles, {})
    step(inst.NS.db)
    local after = diff(inst.NS.db.sv.profiles, {})
    assertEqual(table.concat(after, "; "), table.concat(before, "; "),
        "a second run of the v16 step changed the account")

    local frame = inst.NS.db.sv.profiles.Default.windows[1].frame
    frame.minimised, frame.minimized = true, false
    step(inst.NS.db)
    assertEqual(frame.minimized, false, "the British key overwrote the US one")
    assertEqual(frame.minimised, nil, "the British key survived beside the US one")
end)

test("migrations: a fresh install stores frame.minimized and no British key", function()
    -- red under: defaults/Profile.lua still declaring `minimised` or `showMinimise`.
    local inst = initWith({})
    local frame = inst.NS.Database.GetWindows()[1].frame
    assertEqual(frame.minimized, false)
    assertEqual(frame.showMinimize, true)
    assertEqual(frame.minimised, nil, "the fresh window carries the British collapse key")
    assertEqual(frame.showMinimise, nil, "the fresh window carries the British control key")
end)

-- ---------------------------------------------------------------------------
-- v16 -> v17: the header matched to Ka0s DPS Race's title bar
-- ---------------------------------------------------------------------------

--- A v16-shaped window holding the header and control values every window stored before the
--- match: the template is copied whole into each window (core/Database.lua fillMissing), so these
--- sit in the savedvariables whether or not the player ever touched them.
local function v16Window(id)
    return {
        id = id,
        frame  = { hoverReveal = true, controlSize = 16, controlColorMode = "custom",
                   controlColor = { r = 1, g = 1, b = 1, a = 1 } },
        header = { outline = "OUTLINE", shadow = false },
    }
end

test("migrations: v17 moves every window still on the old shipped header onto the DPS Race match", function()
    -- AceDB's defaults cannot reach inside the windows array, so a changed template alone leaves
    -- every existing window on the old look.
    -- red under: no v16 -> v17 step, or one that walks db.profile alone.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 3, windows = { v16Window(1), v16Window(2) } },
                     Raid    = { nextWindowId = 8, windows = { v16Window(7) } } },
        global   = { schemaVersion = 16 },
    })
    assertEqual(inst.NS.db.global.schemaVersion, inst.NS.SCHEMA_VERSION)
    for _, name in ipairs({ "Default", "Raid" }) do
        for i, w in ipairs(inst.NS.db.sv.profiles[name].windows) do
            local where = name .. " window " .. i
            -- v17 wrote NONE; the walk goes on to v22, which carries that old default onto From
            -- skin (LibKa0s v1.82.0, ruling D-07).
            assertEqual(w.header.outline, "@skin", where .. " kept the outline")
            assertEqual(w.header.shadow, true, where .. " has no shadow")
            assertEqual(w.frame.hoverReveal, false, where .. " still fades its controls")
            assertEqual(w.frame.controlSize, 18, where .. " kept the 16px slot")
            local c = w.frame.controlColor
            assertEqual(("%s/%s/%s/%s"):format(c.r, c.g, c.b, c.a), "0.7/0.7/0.72/1",
                where .. " kept the white controls")
        end
    end
end)

test("migrations: v17 leaves every value a player chose for themselves", function()
    -- A value other than the old shipped one is a choice, and the step has no business with it.
    -- The outline and shadow move only as the old shipped PAIR: an outline kept with a shadow
    -- turned on was chosen.
    -- red under: rewriting any of these keys unconditionally.
    local w = v16Window(1)
    w.header.outline = "THICKOUTLINE"
    w.frame.controlSize = 20
    w.frame.controlColor = { r = 1, g = 0, b = 0, a = 1 }
    local paired = v16Window(2)
    paired.header.shadow = true
    paired.frame.controlColorMode = "class"
    local inst = initWith({
        profiles = { Default = { nextWindowId = 3, windows = { w, paired } } },
        global   = { schemaVersion = 16 },
    })
    local a, b = inst.NS.Database.FindWindow(1), inst.NS.Database.FindWindow(2)
    assertEqual(a.header.outline, "THICKOUTLINE")
    assertEqual(a.header.shadow, false, "a chosen outline lost its shadow choice")
    assertEqual(a.frame.controlSize, 20)
    assertEqual(a.frame.controlColor.g, 0, "a chosen control color was overwritten")
    assertEqual(b.header.outline, "OUTLINE", "an outline kept beside a chosen shadow was dropped")
    assertEqual(b.header.shadow, true)
    assertEqual(b.frame.controlColor.r, 1, "a class-mode window's stored color was rewritten")
end)

test("migrations: the v17 step run twice is a no-op, and survives a junk window", function()
    -- red under: a step that indexes a window or its groups without a type guard.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 2, windows = { v16Window(1) } },
                     Odd     = { windows = { "junk", v16Window(2), { id = 3 } } } },
        global   = { schemaVersion = 16 },
    })
    local step = inst.NS.Database.__migrations[16]
    local before = diff(inst.NS.db.sv.profiles, {})
    step(inst.NS.db)
    local after = diff(inst.NS.db.sv.profiles, {})
    assertEqual(table.concat(after, "; "), table.concat(before, "; "),
        "a second run of the v17 step changed the account")
    assertEqual(inst.NS.db.sv.profiles.Odd.windows[1], "junk", "the step rewrote a non-window")
    assertEqual(inst.NS.db.sv.profiles.Odd.windows[2].header.outline, "@skin",
        "the window after the junk entry was skipped (v17's NONE, carried on by v22)")
end)

-- ---------------------------------------------------------------------------
-- v17 -> v18: the title bar grown to Ka0s DPS Race's 30px
-- ---------------------------------------------------------------------------

--- A v17-shaped window on the old shipped 18px header height, which the template copied into every
--- stored window -- including the owner's, already stamped v17 by the first header-match build.
local function v17Window(id, height)
    return { id = id, header = { height = height or 18, outline = "NONE", shadow = true } }
end

test("migrations: v18 moves every window still on the 18px header onto the 30px bar", function()
    -- An account already at v17 never runs migrations[16] again, so the height needs its own step.
    -- red under: no v17 -> v18 step, or one that walks db.profile alone.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 3, windows = { v17Window(1), v17Window(2) } },
                     Raid    = { nextWindowId = 8, windows = { v17Window(7) } } },
        global   = { schemaVersion = 17 },
    })
    assertEqual(inst.NS.db.global.schemaVersion, inst.NS.SCHEMA_VERSION)
    for _, name in ipairs({ "Default", "Raid" }) do
        for i, w in ipairs(inst.NS.db.sv.profiles[name].windows) do
            assertEqual(w.header.height, 26, name .. " window " .. i .. " kept the 22px bar")
        end
    end
end)

test("migrations: v18 leaves a header height a player chose", function()
    -- Only the old shipped 18 is taken for the default; any other height is a choice.
    -- red under: writing 26 unconditionally.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 4,
                                 windows = { v17Window(1, 24), v17Window(2, 30), v17Window(3, 8) } } },
        global   = { schemaVersion = 17 },
    })
    local D = inst.NS.Database
    assertEqual(D.FindWindow(1).header.height, 24)
    assertEqual(D.FindWindow(2).header.height, 30)
    assertEqual(D.FindWindow(3).header.height, 8)
    -- The stored NONE is v21's shipped default, which the v22 step (not this one) moves to From skin.
    assertEqual(D.FindWindow(1).header.outline, "@skin", "the step touched another header key")
end)

test("migrations: the v18 step run twice is a no-op, and survives a junk window", function()
    -- red under: a step that indexes a window or its header without a type guard.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 2, windows = { v17Window(1) } },
                     Odd     = { windows = { "junk", { id = 2, header = "junk" }, v17Window(3) } } },
        global   = { schemaVersion = 17 },
    })
    local step = inst.NS.Database.__migrations[17]
    local before = diff(inst.NS.db.sv.profiles, {})
    step(inst.NS.db)
    local after = diff(inst.NS.db.sv.profiles, {})
    assertEqual(table.concat(after, "; "), table.concat(before, "; "),
        "a second run of the v18 step changed the account")
    assertEqual(inst.NS.db.sv.profiles.Odd.windows[1], "junk", "the step rewrote a non-window")
    assertEqual(inst.NS.db.sv.profiles.Odd.windows[3].header.height, 26,
        "the window after the junk entries was skipped")
end)

-- ---------------------------------------------------------------------------
-- v18 -> v19: the default window grown back to ten rows under the 30px bar
-- ---------------------------------------------------------------------------

--- A v18-shaped window on the old shipped 220px frame height, which the template copied into every
--- stored window. The 30px bar of v18 took the tenth row out of it.
local function v18Window(id, height)
    return { id = id, frame = { width = 694, height = height or 220, padding = 6 } }
end

test("migrations: v19 moves every window still on the 220px height to 228, in every profile", function()
    -- An account already at v18 holds the old 220 verbatim in every window, active profile or not.
    -- red under: no v18 -> v19 step, or one that walks db.profile alone.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 3, windows = { v18Window(1), v18Window(2) } },
                     Raid    = { nextWindowId = 8, windows = { v18Window(7) } } },
        global   = { schemaVersion = 18 },
    })
    assertEqual(inst.NS.db.global.schemaVersion, inst.NS.SCHEMA_VERSION)
    for _, name in ipairs({ "Default", "Raid" }) do
        for i, w in ipairs(inst.NS.db.sv.profiles[name].windows) do
            assertEqual(w.frame.height, 228, name .. " window " .. i .. " kept the nine-row 220px")
        end
    end
end)

test("migrations: v19 leaves a frame height a player chose", function()
    -- Only the old shipped 220 is taken for the default; any other height is a choice.
    -- red under: writing 228 unconditionally.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 4,
                                 windows = { v18Window(1, 300), v18Window(2, 221), v18Window(3, 60) } } },
        global   = { schemaVersion = 18 },
    })
    local D = inst.NS.Database
    assertEqual(D.FindWindow(1).frame.height, 300)
    assertEqual(D.FindWindow(2).frame.height, 221)
    assertEqual(D.FindWindow(3).frame.height, 60)
    assertEqual(D.FindWindow(1).frame.width, 694, "the step touched another frame key")
end)

test("migrations: the v19 step run twice is a no-op, and survives a junk window", function()
    -- red under: a step that indexes a window or its frame without a type guard.
    local inst = initWith({
        profiles = { Default = { nextWindowId = 2, windows = { v18Window(1) } },
                     Odd     = { windows = { "junk", { id = 2, frame = "junk" }, v18Window(3) } } },
        global   = { schemaVersion = 18 },
    })
    local step = inst.NS.Database.__migrations[18]
    local before = diff(inst.NS.db.sv.profiles, {})
    step(inst.NS.db)
    local after = diff(inst.NS.db.sv.profiles, {})
    assertEqual(table.concat(after, "; "), table.concat(before, "; "),
        "a second run of the v19 step changed the account")
    assertEqual(inst.NS.db.sv.profiles.Odd.windows[1], "junk", "the step rewrote a non-window")
    assertEqual(inst.NS.db.sv.profiles.Odd.windows[3].frame.height, 228,
        "the window after the junk entries was skipped")
end)
