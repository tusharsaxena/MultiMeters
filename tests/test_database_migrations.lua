-- tests/test_database_migrations.lua — core/Database.lua's migration runner and
-- every step it walks.
--
-- Peeled from tests/test_database.lua (layout-§1) along the `Migrations` section
-- of core/Database.lua: the runner (the stamp, the account-wide version, the
-- walk forward, the unconditional shape normalization), each step from v1 -> v2
-- onward, and the branch arms of the steps the complexity register warns on.
-- What stays in tests/test_database.lua: the AceDB instance, the `== nil` merge,
-- the window registry and the profile callbacks. Who OWNS the stamp is
-- tests/test_migrations.lua's subject, not this file's.
--
-- Every case drives the REAL NS:InitDB() and NS:RunMigrations() against a seeded
-- SavedVariables global, through preSeeded() below.

local T = _G.MULTIMETERS_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

--- A loaded instance with NO database yet, so a case can seed the SavedVariables
--- global and then drive the REAL NS:InitDB() against it. Duplicated from
--- tests/test_database.lua rather than shared: it is seven lines.
local function preSeeded(saved)
    local inst = T.load{ initDB = false, options = false }
    _G.MultiMetersDB = saved
    inst.NS:InitDB()
    inst.NS:RunMigrations()
    return inst
end

-- ── migrations ──────────────────────────────────────────────────────────────

test("Database: RunMigrations stamps and holds the current schema version", function()
    local inst = T.load{}
    local v = inst.NS.db.global.schemaVersion
    assertEqual(type(v), "number")
    inst.NS:RunMigrations()
    assertEqual(inst.NS.db.global.schemaVersion, v, "a second run must be a no-op")
end)

test("Database: the schema version is account-wide, not per-profile", function()
    -- savedvariables-§1: a migration runs once per ACCOUNT. In `profile` it
    -- would re-run for every profile the user has, and a non-idempotent step
    -- would then run several times over data it had already moved.
    local inst = T.load{}
    assertTrue(inst.NS.db.global.schemaVersion ~= nil, "schemaVersion must live in db.global")
    assertNil(inst.NS.db.profile.schemaVersion, "schemaVersion must NOT live in db.profile")
    assertNil(NS.defaults.profile.schemaVersion)
    assertTrue(NS.defaults.global.schemaVersion ~= nil)
end)

test("Database: a version ahead of any registered step is walked forward, not spun on", function()
    -- The runner has no migrator at v1 by design. A `while` loop with no step
    -- and no bump would hang the client at login, which is the one failure worse
    -- than a bad migration.
    -- red under: `break`ing out of the loop without setting schemaVersion.
    local inst = preSeeded({
        profiles = { Default = {} },
        global   = { schemaVersion = 0 },
    })
    assertTrue(inst.NS.db.global.schemaVersion >= 1,
        "an older account must be walked forward to the current version")
end)

-- ── v1 -> v2: one uniform column width ──────────────────────────────────────

--- A v1 account whose windows carry the old per-stat widths.
local function v1Account(frameWidth)
    return preSeeded({
        profiles = {
            Default = {
                nextWindowId = 2,
                windows = { {
                    id = 1,
                    frame   = { width = frameWidth, padding = 6 },
                    columns = {
                        { stat = "DamageDone",           width = 92, showBar = true },
                        { stat = "Interrupts",           width = 48, showBar = true },
                        { stat = "Deaths",               width = 44, showBar = true },
                    },
                } },
            },
        },
        global = { schemaVersion = 1 },
    })
end

test("Database v1: a v1 account walks all the way to the catalog shape", function()
    -- v2 lifted every column to one uniform width, and v12 deleted width
    -- altogether -- so the END state of a full walk is the new shape, not v2's.
    -- The step still runs and still matters to the frame widening below; what it
    -- wrote to the columns is simply not what survives the ladder.
    -- red under: bumping CURRENT_DB_VERSION without registering every step.
    local inst = v1Account(480)
    local Const = inst.NS.Constants
    local w = inst.NS.Database.FindWindow(1)

    assertEqual(#w.columns, #Const.STATS, "the array is the catalog after the walk")
    assertEqual(w.columns[1].stat, "DamageDone", "the player's order survives every step")
    assertEqual(w.columns[2].stat, "Interrupts")
    assertEqual(w.columns[3].stat, "Deaths")
    for i = 1, 3 do
        assertTrue(w.columns[i].enabled, "a column that was SHOWN arrives enabled")
    end
    for i = 4, #w.columns do
        assertFalse(w.columns[i].enabled, "a statistic that was not a column arrives disabled")
    end
    assertEqual(w.columns[1].width, nil, "width must not survive the walk")
    assertEqual(w.columns[1].showBar, nil, "showBar must not survive the walk")

    assertEqual(inst.NS.db.global.schemaVersion, 16,
        "the walk must run all the way to the current version, not stop partway")
end)

test("Database v2: the frame is widened to hold the new grid", function()
    -- The full default column set at one uniform width no longer fits the old
    -- 480 default, and a frame that clips its rightmost column reads as a broken
    -- window rather than as one that needs dragging.
    -- red under: migrating widths without touching frame.width.
    local Const = T.load{}.NS.Constants
    local columns = {}
    for _, key in ipairs(Const.DEFAULT_STAT_KEYS) do
        columns[#columns + 1] = { stat = key, width = 48, showBar = true }
    end

    local inst = preSeeded({
        profiles = { Default = { windows = { {
            id = 1, frame = { width = 480, padding = 6 }, columns = columns,
        } } } },
        global = { schemaVersion = 1 },
    })

    local needed = Const.NAME_COLUMN_WIDTH
        + #columns * (Const.COLUMN_WIDTH + Const.COLUMN_GAP) + 12
    assertEqual(inst.NS.Database.FindWindow(1).frame.width, needed,
        "480 could not hold the uniform grid and had to grow")
    assertEqual(needed, inst.NS.WINDOW_TEMPLATE.frame.width,
        "and the shipped default is that same computed width, not a guess")
end)

test("Database v2: a frame that already fits the grid is left alone", function()
    -- Three columns fit inside 480 comfortably, so there is nothing to fix and
    -- the migration must not resize a window for the sake of resizing it.
    assertEqual(v1Account(480).NS.Database.FindWindow(1).frame.width, 480)
end)

test("Database v2: a frame already wider than the grid is left alone", function()
    -- Only ever WIDENED. A player who dragged their window out to 900 chose that,
    -- and a migration that narrowed it would be undoing their layout to satisfy
    -- an arithmetic minimum.
    -- red under: `frame.width = needed` unconditionally.
    local inst = v1Account(900)
    assertEqual(inst.NS.Database.FindWindow(1).frame.width, 900)
end)

test("Database: EVERY saved profile is walked, not just the active one", function()
    -- A profile the player has not activated this session is still theirs. Lifting
    -- only db.profile leaves the others stale AFTER schemaVersion has been stamped
    -- forward, so the step never gets a second chance at them.
    -- red under: iterating `{ db.profile }` instead of db.sv.profiles.
    local inst = preSeeded({
        profiles = {
            Default = { windows = { { id = 1,
                frame = { width = 480, padding = 6 },
                columns = { { stat = "Deaths", width = 44, showBar = true } } } } },
            Raid    = { windows = { { id = 7,
                frame = { width = 480, padding = 6 },
                columns = { { stat = "Deaths", width = 44, showBar = true } } } } },
        },
        global = { schemaVersion = 1 },
    })

    local raid = inst.NS.db.sv.profiles.Raid
    assertEqual(#raid.windows[1].columns, #inst.NS.Constants.STATS,
        "the inactive Raid profile was left in the old shape")
    assertEqual(raid.windows[1].columns[1].stat, "Deaths")
    assertTrue(raid.windows[1].columns[1].enabled)
    assertEqual(raid.windows[1].columns[1].width, nil)
end)

test("Database v2: the step is idempotent and survives a malformed window", function()
    -- Migrations run on every Init and every profile swap. A second pass must
    -- change nothing, and a hand-edited profile must not take the login down.
    local inst = preSeeded({
        profiles = { Default = { windows = {
            { id = 1, frame = "not a table", columns = { "not a column" } },
            { id = 2 },
        } } },
        global = { schemaVersion = 1 },
    })
    inst.NS:RunMigrations()
    assertEqual(inst.NS.db.global.schemaVersion, 16)
end)

test("Database: RunMigrations with no database is a no-op, not an error", function()
    local inst = T.load{ initDB = false, options = false }
    inst.NS:RunMigrations()
end)

test("Database: RunMigrations normalizes every window whatever the version claims", function()
    -- Shape normalization runs AFTER the version walk and unconditionally, so a
    -- profile that arrived from a copy or a hand edit is brought to the current
    -- shape even when its version says it is already current.
    local inst = preSeeded({
        profiles = { Default = { windows = { { id = 1 } } } },
        global   = { schemaVersion = 99 },
    })
    local w = inst.NS.Database.FindWindow(1)
    assertEqual(type(w.frame), "table", "a version-current profile was left unnormalized")
    assertEqual(w.frame.width, NS.WINDOW_TEMPLATE.frame.width)
end)

-- ---------------------------------------------------------------------------
-- v2 -> v3: the three row-icon toggles collapse into one
-- ---------------------------------------------------------------------------

--- A v2 account whose single window carries the three old icon flags.
local function v2Icons(flags)
    return preSeeded({
        profiles = {
            Default = {
                nextWindowId = 2,
                windows = { { id = 1, icons = flags } },
            },
        },
        global = { schemaVersion = 2 },
    })
end

test("Database v3: ANY of the three old icon flags means the icon stays on", function()
    -- Somebody running the ROLE icon alone had asked for an icon. Reading only
    -- showClass would take it away from them without asking — the new slot
    -- answers the same question better rather than withdrawing the answer.
    -- red under: `icons.showIcon = icons.showClass`.
    for _, flags in ipairs({
        { showClass = true,  showSpec = false, showRole = false },
        { showClass = false, showSpec = true,  showRole = false },
        { showClass = false, showSpec = false, showRole = true  },
    }) do
        local inst = v2Icons(flags)
        assertEqual(inst.NS.Database.FindWindow(1).icons.showIcon, true,
            "a window with an icon on lost it in the migration")
    end
end)

test("Database v3: all three off stays off", function()
    -- The one combination that must NOT turn an icon on: a player who had
    -- deliberately cleared the name column keeps it clear.
    -- red under: defaulting showIcon to true regardless.
    local inst = v2Icons{ showClass = false, showSpec = false, showRole = false }
    assertEqual(inst.NS.Database.FindWindow(1).icons.showIcon, false,
        "a deliberately icon-free window got one back")
end)

test("Database v3: the three dead keys are REMOVED, not left to rot", function()
    -- AceDB merges defaults into a stored profile but never prunes what the
    -- defaults stopped naming, so without this they sit in every saved profile
    -- forever and the next reader has to work out which of four keys the code
    -- honors.
    -- red under: setting showIcon without clearing the old flags.
    local inst = v2Icons{ showClass = true, showSpec = true, showRole = true }
    local icons = inst.NS.Database.FindWindow(1).icons

    assertNil(icons.showClass, "showClass survived the migration")
    assertNil(icons.showSpec,  "showSpec survived the migration")
    assertNil(icons.showRole,  "showRole survived the migration")
    assertEqual(inst.NS.db.global.schemaVersion, 16)
end)

-- ---------------------------------------------------------------------------
-- v3 -> v4: the export channel "AUTO" is retired
-- ---------------------------------------------------------------------------

--- A v3 account whose profiles carry the given export channels.
local function v3Channels(channels)
    local profiles = {}
    for name, channel in pairs(channels) do
        profiles[name] = {
            nextWindowId = 2,
            windows = { { id = 1 } },
            export = { channel = channel, whisperTo = "" },
        }
    end
    return preSeeded({ profiles = profiles, global = { schemaVersion = 3 } })
end

test("Database v4: a stored AUTO channel folds to SELF, in EVERY profile", function()
    -- AUTO resolved its own destination at send time and was removed as
    -- ambiguous. Left in a profile it would reach SendChatMessage as a chat type
    -- of "AUTO", which is not one — and SELF is the only landing that cannot put
    -- a ranking in front of people the player did not choose.
    -- red under: lifting only the active profile, or leaving the key alone.
    local inst = v3Channels{ Default = "AUTO", Alt = "AUTO" }
    local sv = inst.NS.db.sv or _G.MultiMetersDB

    assertEqual(sv.profiles.Default.export.channel, "SELF")
    assertEqual(sv.profiles.Alt.export.channel, "SELF")
    assertEqual(inst.NS.db.global.schemaVersion, 16)
end)

test("Database v4: every other channel is left exactly as the player set it", function()
    -- red under: a step that rewrites the key unconditionally, which would take
    -- a deliberate raid default away on login.
    local inst = v3Channels{ Default = "RAID", Alt = "WHISPER" }
    local sv = inst.NS.db.sv or _G.MultiMetersDB

    assertEqual(sv.profiles.Default.export.channel, "RAID")
    assertEqual(sv.profiles.Alt.export.channel, "WHISPER")
end)

test("Database v4: a profile with no export block at all survives the step", function()
    -- Every profile written before the export feature existed is this one.
    local inst = preSeeded({
        profiles = { Default = { nextWindowId = 2, windows = { { id = 1 } } } },
        global   = { schemaVersion = 3 },
    })
    assertEqual(inst.NS.db.global.schemaVersion, 16)
end)

-- ---------------------------------------------------------------------------
-- v4 -> v5: mergePets and throttle become addon-wide
-- ---------------------------------------------------------------------------

--- A v4 account whose windows carry the two lifted keys.
local function v4Data(windows, existing)
    return preSeeded({
        profiles = {
            Default = {
                nextWindowId = #windows + 1,
                windows = windows,
                data = existing,
            },
        },
        global = { schemaVersion = 4 },
    })
end

test("Database v5: the FIRST window's values are the ones lifted", function()
    -- There is no merge rule that is right for a player who set two windows
    -- differently. The first window is the one at the top of their own picker.
    -- red under: taking the last window, or taking the shipped default.
    local inst = v4Data({
        { id = 1, data = { mergePets = true,  throttle = 0.5 } },
        { id = 2, data = { mergePets = false, throttle = 2   } },
    })
    local profile = inst.NS.db.profile

    assertEqual(profile.data.mergePets, true)
    assertEqual(profile.data.throttle, 0.5)
    assertEqual(inst.NS.db.global.schemaVersion, 16)
end)

test("Database v5: the per-window keys are REMOVED from EVERY window", function()
    -- AceDB merges defaults in and never prunes what they stopped naming, so a
    -- stale `throttle` would sit in every saved window forever, beside the live
    -- one, with nothing to say which the addon honors.
    -- red under: lifting without clearing.
    local inst = v4Data({
        { id = 1, data = { mergePets = true, throttle = 0.5, sortColumn = "Healing" } },
        { id = 2, data = { mergePets = true, throttle = 2 } },
    })

    for _, id in ipairs({ 1, 2 }) do
        local data = inst.NS.Database.FindWindow(id).data
        assertNil(data.mergePets, "window " .. id .. " kept mergePets")
        assertNil(data.throttle,  "window " .. id .. " kept throttle")
    end
    -- And nothing else in the group was touched: the sort keys are still the
    -- window's own, and the migration is not a rewrite of `data`.
    assertEqual(inst.NS.Database.FindWindow(1).data.sortColumn, "Healing")
end)

test("Database v5: the window's value beats whatever sits at the profile address", function()
    -- The `== nil` rule that governs EnsureWindowShape does NOT apply to this
    -- step, and the reason is AceDB: its defaults merge runs before any
    -- migration, so `profile.data` is already filled with the shipped values and
    -- "the player set this" cannot be told from "the merge just wrote it". The
    -- window's value is the only one that carries intent, because before v5 the
    -- profile-level key did not exist and nothing read it.
    -- red under: an `if profile.data.throttle == nil` guard, which would discard
    -- every deliberate per-window value in favor of the merged default.
    local inst = v4Data({ { id = 1, data = { throttle = 2 } } }, { throttle = 0.75 })
    assertEqual(inst.NS.db.profile.data.throttle, 2)
end)

test("Database v5: a profile whose windows never carried the keys survives", function()
    -- Every profile written before either setting existed is this one, and the
    -- shipped defaults are what it should land on.
    local inst = v4Data({ { id = 1, data = { sortColumn = "Healing" } } })
    assertEqual(inst.NS.db.global.schemaVersion, 16)
    assertEqual(inst.NS.DataSetting("throttle"), 0.25)
    assertEqual(inst.NS.DataSetting("mergePets"), false)
end)

test("Database v6: the two dead row-background keys are pruned from every window", function()
    -- They were settings-panel rows pointing at keys NOTHING read: the row tint
    -- is `bars.bgColorMode`, painted per cell. AceDB never prunes what the
    -- defaults stopped naming, so without this they sit in every saved window
    -- forever and the next reader has to work out which of two keys is honored.
    -- red under: deleting the schema rows and leaving the stored keys.
    local inst = preSeeded({
        profiles = {
            Default = {
                nextWindowId = 3,
                windows = {
                    { id = 1, rows = { classBackground = true, classBackgroundAlpha = 0.4,
                                       highlightSelf = false } },
                    { id = 2, rows = { classBackground = false } },
                },
            },
        },
        global = { schemaVersion = 5 },
    })

    for _, id in ipairs({ 1, 2 }) do
        local rows = inst.NS.Database.FindWindow(id).rows
        assertNil(rows.classBackground, "window " .. id .. " kept classBackground")
        assertNil(rows.classBackgroundAlpha, "window " .. id .. " kept classBackgroundAlpha")
    end
    -- And nothing else in the group was touched.
    assertEqual(inst.NS.Database.FindWindow(1).rows.highlightSelf, false)
    assertEqual(inst.NS.db.global.schemaVersion, 16)
end)

test("Database v7: a class-color boolean becomes a color mode, on every surface", function()
    -- The checkbox could only ever answer two thirds of the question. `true` is
    -- "class" and `false` is "custom", which is exactly what it meant.
    -- red under: migrating only `text`, or leaving the dead key behind.
    local inst = preSeeded({
        profiles = {
            Default = {
                nextWindowId = 2,
                windows = {
                    {
                        id = 1,
                        text         = { classColor = true },
                        header       = { classColor = false },
                        columnHeader = { classColor = true },
                        tooltip      = { classColor = true, fontSize = 14 },
                    },
                },
            },
        },
        global = { schemaVersion = 6 },
    })

    local w = inst.NS.Database.FindWindow(1)
    assertEqual(w.text.colorMode, "class")
    -- v7 set this, v10 PRUNES it, and the shipped default fills it back in -- the
    -- ladder runs all the way, so what a middle step wrote is not what the end
    -- state holds. `window.header.colorMode` exists again with TWO modes rather
    -- than three, so what the prune is worth today is scrubbing a stored `stat`
    -- the new row would not accept. A profile that had `class` reverts to the
    -- picker; the key was dead for the releases in between and re-deriving intent
    -- from a value nothing read would be inventing a preference nobody expressed.
    assertEqual(w.header.colorMode, "custom")
    assertEqual(w.columnHeader.colorMode, "class")
    assertEqual(w.tooltip.colorMode, "class")

    for _, group in ipairs({ "text", "header", "columnHeader", "tooltip" }) do
        assertNil(w[group].classColor, group .. " kept the dead boolean")
    end
    -- Nothing else in a migrated group was touched.
    assertEqual(w.tooltip.fontSize, 14)
    assertEqual(inst.NS.db.global.schemaVersion, 16)
end)

test("Database v7: a window that never set one is left to the shipped default", function()
    local inst = preSeeded({
        profiles = { Default = { nextWindowId = 2, windows = { { id = 1, text = {} } } } },
        global   = { schemaVersion = 6 },
    })
    -- The defaults merge supplies it; the step must not invent a different one.
    assertEqual(inst.NS.Database.FindWindow(1).text.colorMode, "custom")
end)

test("Database v8: the four redundant header keys are pruned from every window", function()
    -- Each said something already on screen. AceDB never prunes what the defaults
    -- stopped naming, so without this they sit in every saved window forever.
    -- red under: deleting the schema rows and leaving the stored keys.
    local inst = preSeeded({
        profiles = {
            Default = {
                nextWindowId = 2,
                windows = {
                    { id = 1, name = "Raid",
                      header = { title = "Overall", showSessionName = true,
                                 showDuration = true, showTotals = true, size = 14 } },
                },
            },
        },
        global = { schemaVersion = 7 },
    })

    local header = inst.NS.Database.FindWindow(1).header
    for _, key in ipairs({ "title", "showSessionName", "showDuration", "showTotals" }) do
        assertNil(header[key], "the header kept " .. key)
    end
    assertEqual(header.size, 14, "the rest of the group was touched")
    assertEqual(inst.NS.db.global.schemaVersion, 16)
end)

test("Database v8: a typed header title becomes the window's NAME, not nothing", function()
    -- That is what the box was being used for: naming the window, in the only
    -- field that changed what the header said. Dropping it would silently rename
    -- their windows back.
    -- red under: pruning the key without rescuing the value.
    local inst = preSeeded({
        profiles = {
            Default = {
                nextWindowId = 2,
                windows = { { id = 1, header = { title = "Mythic+" } } },
            },
        },
        global = { schemaVersion = 7 },
    })
    assertEqual(inst.NS.Database.FindWindow(1).name, "Mythic+")
end)

test("Database v8: a window that was named itself keeps its own name", function()
    -- A player who set both meant the one in the picker: it is the name every
    -- other surface already used.
    local inst = preSeeded({
        profiles = {
            Default = {
                nextWindowId = 2,
                windows = { { id = 1, name = "Raid", header = { title = "Overall" } } },
            },
        },
        global = { schemaVersion = 7 },
    })
    assertEqual(inst.NS.Database.FindWindow(1).name, "Raid")
end)

test("Database v9: the title bar's background mode is pruned, the column strip's is kept", function()
    -- The two looked like a matched pair and are not: "per statistic" means
    -- something per COLUMN and nothing over one strip.
    -- red under: pruning both, or neither.
    local inst = preSeeded({
        profiles = {
            Default = {
                nextWindowId = 2,
                windows = {
                    { id = 1,
                      header       = { bgColorMode = "stat", bgColor = { r = 1 } },
                      columnHeader = { bgColorMode = "stat" } },
                },
            },
        },
        global = { schemaVersion = 8 },
    })

    local w = inst.NS.Database.FindWindow(1)
    assertNil(w.header.bgColorMode, "the title bar kept a mode it no longer has")
    assertEqual(w.columnHeader.bgColorMode, "stat", "the column strip lost the mode it keeps")
    assertEqual(w.header.bgColor.r, 1, "the color picker went with the dropdown")
    assertEqual(inst.NS.db.global.schemaVersion, 16)
end)

test("Database v10: a stored cursor anchor becomes TOP, and other anchors are left alone", function()
    -- The value in the profile should be the value the dropdown shows, rather
    -- than something only the reader's fallback knows how to interpret.
    -- red under: relying on the fallback and leaving "CURSOR" stored.
    local inst = preSeeded({
        profiles = {
            Default = {
                nextWindowId = 3,
                windows = {
                    { id = 1, tooltip = { anchor = "CURSOR" } },
                    { id = 2, tooltip = { anchor = "BOTTOMLEFT" } },
                },
            },
        },
        global = { schemaVersion = 9 },
    })

    assertEqual(inst.NS.Database.FindWindow(1).tooltip.anchor, "TOP")
    assertEqual(inst.NS.Database.FindWindow(2).tooltip.anchor, "BOTTOMLEFT")
    assertEqual(inst.NS.db.global.schemaVersion, 16)
end)

test("Database: v12 -> v13 moves the title-bar toggle onto the header", function()
    -- The control moved to the Header page, and a path naming `frame` for a row on the Header
    -- page misleads the next reader and reads wrong in `/mm set`. Carried across rather than
    -- dropped: a player who turned their title bar OFF must not log in to it back on.
    -- red under: writing the default instead of the stored value, or forgetting the prune.
    local inst = preSeeded({
        profiles = { Default = { windows = { { id = 1, name = "Mine",
            frame = { titleBar = false } } } } },
        global   = { schemaVersion = 12 },
    })
    local w = inst.NS.Database.FindWindow(1)

    assertEqual(inst.NS.db.global.schemaVersion, 16)
    assertFalse(w.header.show, "the stored value carried across")
    assertNil(w.frame.titleBar,
        "AceDB merges defaults in and never removes what they stopped naming")
end)

test("Database: v12 -> v13 leaves a window that never stored the toggle alone", function()
    -- An absent key means "never changed from the default", and writing one during a migration
    -- would freeze today's default into every profile -- so the default could never move again.
    -- The merge fills it from the template afterwards, which is a different thing: what this
    -- pins is that the MIGRATION did not decide the value.
    -- red under: unconditionally assigning header.show inside the step.
    local inst = preSeeded({
        profiles = { Default = { windows = { { id = 1, name = "Mine", frame = {} } } } },
        global   = { schemaVersion = 12 },
    })
    local w = inst.NS.Database.FindWindow(1)
    assertNil(w.frame.titleBar, "nothing to carry, nothing left behind")
    assertEqual(w.header.show, true, "the shipped default arrived through the merge, not the step")
end)

test("Database: v12 -> v13 turns the control class-color flags into modes", function()
    -- The two booleans sat beside color pickers while every other surface in this addon
    -- expresses the same choice as a mode dropdown. A stored `true` becomes "class"; a stored
    -- `false` becomes "custom", which is what it already meant.
    -- red under: mapping false to nil, which leaves the row reading the schema default.
    local inst = T.load()
    local db = inst.NS.db

    db.global.schemaVersion = 12
    local w = db.profile.windows[1]
    w.frame.controlClassColor      = true
    w.frame.controlHoverClassColor = false

    inst.NS:RunMigrations()

    assertEqual(w.frame.controlColorMode, "class")
    assertEqual(w.frame.controlHoverColorMode, "custom")
    assertNil(w.frame.controlClassColor)
    assertNil(w.frame.controlHoverClassColor)
end)

-- ---------------------------------------------------------------------------
-- Branch arms of the three warned steps
-- ---------------------------------------------------------------------------
--
-- migrations[1], [4] and [12] are the three steps the complexity register warns
-- on, and a wave is going to take each of them apart into helpers. The cases
-- above pin the headline behavior of each; the cases below pin the arms that
-- headline never reaches — the fallbacks, the guards, and the "what if the key
-- the step keys off is missing HERE and present THERE" shapes. Every one of them
-- is a shape a real SavedVariables file can hold, and none of them is asserted
-- anywhere else in this suite.

test("Database v2: the widening uses the window's OWN padding, not the template's", function()
    -- `pad = frame.padding or defaultPad` has two arms and every case above takes
    -- the same one, because every fixture above stores padding = 6, which is also
    -- what the template says. A player who set a wider inset needs the extra
    -- inset counted on BOTH edges or the widening lands short and clips exactly
    -- the column it was computed to fit.
    --
    -- The junk entry in `columns` is here on purpose too: the width loop skips a
    -- non-table entry (`type(col) == "table"`) but the ARITHMETIC counts the
    -- array's length, junk and all, so this window is sized for two columns. That
    -- is today's behavior rather than an opinion about it — a refactor that
    -- filters the array before measuring it is a deliberate change to the width a
    -- hand-edited profile lands on, and should have to come and edit this line.
    -- red under: `pad = defaultPad`, or measuring a filtered column list.
    local inst = preSeeded({
        profiles = { Default = { nextWindowId = 2, windows = { {
            id = 1,
            frame   = { padding = 20 },
            columns = { { stat = "Deaths", width = 44 }, "junk" },
        } } } },
        global = { schemaVersion = 1 },
    })
    local Const = inst.NS.Constants

    assertEqual(inst.NS.Database.FindWindow(1).frame.width,
        Const.NAME_COLUMN_WIDTH + 2 * (Const.COLUMN_WIDTH + Const.COLUMN_GAP) + 40,
        "the stored padding of 20 must be counted on both edges, not the template's 6")
end)

test("Database v2: a frame with no numeric width is given one, and every window gets its own",
function()
    -- Two arms nothing above reaches. `type(frame.width) ~= "number"` is the arm
    -- for a frame that never stored a width and for one a hand edit left holding
    -- the STRING "480" — a string compares fine against a number under `<` in
    -- neither Lua nor anyone's intent, so the type test is what stops the step
    -- raising on it and what makes the window render at a sane size.
    --
    -- And the needed width is computed per WINDOW, from that window's own column
    -- count: window 2 has no columns array at all, so it is sized for zero
    -- columns rather than inheriting window 1's arithmetic.
    -- red under: hoisting `needed` out of the window loop, or dropping the type
    -- test in favor of `frame.width < needed` alone.
    local inst = preSeeded({
        profiles = { Default = { nextWindowId = 3, windows = {
            { id = 1, frame = { width = "480", padding = 6 },
              columns = { { stat = "Deaths", width = 44 }, { stat = "Interrupts", width = 48 } } },
            { id = 2, frame = { width = 100, padding = 6 } },
        } } },
        global = { schemaVersion = 1 },
    })
    local Const = inst.NS.Constants

    assertEqual(inst.NS.Database.FindWindow(1).frame.width,
        Const.NAME_COLUMN_WIDTH + 2 * (Const.COLUMN_WIDTH + Const.COLUMN_GAP) + 12,
        "a non-number width must be replaced, not compared against")
    assertEqual(inst.NS.Database.FindWindow(2).frame.width, Const.NAME_COLUMN_WIDTH + 12,
        "a window with no columns is sized for none of them")
end)

test("Database v5: a stored false and a stored 0 are lifted, not read as unset", function()
    -- The same trap the `== nil` merge exists for, one step over. `mergePets` is a
    -- BOOLEAN and `throttle` is a number whose floor is 0, so a step written as
    -- `lifted.mergePets = data.mergePets or profile.data.mergePets` would take a
    -- deliberate "off" and a deliberate "as fast as it goes" and quietly replace
    -- both with whatever AceDB had already merged in at the profile address.
    -- The window's value wins outright, whatever that value is.
    -- red under: any truthiness test in place of `~= nil`.
    local inst = v4Data({ { id = 1, data = { mergePets = false, throttle = 0 } } },
        { mergePets = true, throttle = 5 })

    assertEqual(inst.NS.db.profile.data.mergePets, false, "a stored false is a value, not an absence")
    assertEqual(inst.NS.db.profile.data.throttle, 0, "a stored 0 is a value, not an absence")
end)

test("Database v5: only the key the window actually carried is lifted", function()
    -- The two keys are lifted independently. A window that set `mergePets` and
    -- never touched `throttle` must not drag a throttle along with it — whatever
    -- sits at the profile address stays there, because the window expressed no
    -- intent about it.
    -- red under: lifting both keys whenever either is present.
    local inst = v4Data({ { id = 1, data = { mergePets = true } } }, { throttle = 5 })

    assertEqual(inst.NS.db.profile.data.mergePets, true)
    assertEqual(inst.NS.db.profile.data.throttle, 5, "an untouched key must be left where it was")
end)

test("Database v5: only the FIRST window is consulted, even when it carries neither key", function()
    -- The rule is "the first window's values win", not "the first window that has
    -- an opinion wins". A first window with no `data` block at all means nothing
    -- is lifted and the profile keeps the shipped defaults — the second window
    -- does NOT get a vote, because a window the player had forgotten about
    -- outvoting the one at the top of their picker is exactly the alternative the
    -- step's comment rules out.
    --
    -- The prune still runs over every window, though: it is outside the lift.
    -- red under: scanning for the first window that has the keys, or moving the
    -- prune inside the `if data and ...` block.
    local inst = v4Data({
        { id = 1, data = { sortColumn = "Healing" } },
        { id = 2, data = { mergePets = true, throttle = 2 } },
    })

    assertEqual(inst.NS.DataSetting("throttle"), 0.25, "the second window must not have been lifted")
    assertEqual(inst.NS.DataSetting("mergePets"), false)
    assertNil(inst.NS.Database.FindWindow(2).data.throttle, "the prune runs whether or not a lift did")
    assertNil(inst.NS.Database.FindWindow(2).data.mergePets)
end)

test("Database v5: a first window whose data block is not a table lifts nothing", function()
    -- A hand-edited profile. `type(first.data) == "table"` is the guard, and what
    -- it buys is that the step declines rather than raising at login — losing a
    -- migration is recoverable, a login that raises is not.
    local inst = v4Data({
        { id = 1, data = "junk" },
        { id = 2, data = { throttle = 3 } },
    })

    assertEqual(inst.NS.DataSetting("throttle"), 0.25)
    assertEqual(inst.NS.db.global.schemaVersion, 16)
end)

test("Database v5: EVERY profile lifts from its OWN first window", function()
    -- The same reason the v2 case walks every profile: a profile the player has
    -- not activated this session is still theirs, and schemaVersion is stamped
    -- account-wide, so a step that skips it never gets a second chance.
    --
    -- The inactive profile also proves the `or {}` arm: it had no `data` table of
    -- its own, so one is created holding exactly what was lifted.
    -- red under: lifting into db.profile rather than into each walked profile.
    local inst = preSeeded({
        profiles = {
            Default = { windows = { { id = 1, name = "A", data = { throttle = 0.5 } } } },
            Raid    = { windows = { { id = 7, name = "R",
                data = { throttle = 3, mergePets = true } } } },
        },
        global = { schemaVersion = 4 },
    })
    local raid = inst.NS.db.sv.profiles.Raid

    assertEqual(inst.NS.db.profile.data.throttle, 0.5, "the active profile took its own window's")
    assertEqual(raid.data.throttle, 3, "and the inactive Raid profile took its own")
    assertEqual(raid.data.mergePets, true)
    assertNil(raid.windows[1].data.throttle, "the inactive profile's window was pruned too")
end)

test("Database: v12 -> v13 keeps the rest of an existing header block", function()
    -- The `type(w.header) ~= "table"` arm builds a header when there is none; the
    -- other arm has to leave the one that is there alone apart from `show`. A step
    -- that assigned `w.header = { show = frame.titleBar }` would take every font,
    -- color and height the player set on their title bar with it.
    -- red under: replacing the header table instead of writing one key into it.
    local inst = preSeeded({
        profiles = { Default = { nextWindowId = 3, windows = {
            { id = 1, name = "A", header = { show = true, fontSize = 17 },
              frame = { titleBar = false } },
            { id = 2, name = "B", header = { show = false }, frame = { titleBar = true } },
        } } },
        global = { schemaVersion = 12 },
    })
    local w1, w2 = inst.NS.Database.FindWindow(1), inst.NS.Database.FindWindow(2)

    assertEqual(w1.header.fontSize, 17, "the rest of the header block must survive the move")
    -- And the moved value WINS over whatever `header.show` already held. The two
    -- keys are the same switch at two addresses for exactly one release, and the
    -- one the player's Frame page was writing is the one that means something.
    assertFalse(w1.header.show, "the stored frame.titleBar beat the stale header.show")
    assertTrue(w2.header.show, "and a stored true carries across as readily as a false")
    assertNil(w1.frame.titleBar)
    assertNil(w2.frame.titleBar)
end)

test("Database: v12 -> v13 overwrites a control color mode that was already there", function()
    -- Deliberately NOT the `== nil` guard migrations[6] uses, and the difference is
    -- easy to lose in a refactor that folds the two boolean-to-mode steps into one
    -- shared helper. `controlColorMode` did not exist as a setting before v13, so
    -- anything sitting at that address arrived from a hand edit or a merge and
    -- carries no intent; the boolean is the only value the player ever set.
    -- red under: `if frame.controlColorMode == nil then`.
    local inst = preSeeded({
        profiles = { Default = { nextWindowId = 2, windows = { { id = 1, name = "A", frame = {
            controlColorMode      = "custom", controlClassColor      = true,
            controlHoverColorMode = "class",  controlHoverClassColor = false,
        } } } } },
        global = { schemaVersion = 12 },
    })
    local frame = inst.NS.Database.FindWindow(1).frame

    assertEqual(frame.controlColorMode, "class", "the boolean is the value with intent behind it")
    assertEqual(frame.controlHoverColorMode, "custom")
    assertNil(frame.controlClassColor)
    assertNil(frame.controlHoverClassColor)
end)

test("Database: v12 -> v13 maps each control flag on its own", function()
    -- The mirror image of the case above the v13 block ends on, which sets the
    -- base flag true and the hover flag false. The two are read and written
    -- separately, so a helper that took one flag and applied it to both surfaces
    -- would pass that case and fail this one.
    -- red under: deriving the hover mode from the base flag.
    local inst = preSeeded({
        profiles = { Default = { nextWindowId = 2, windows = { { id = 1, name = "A",
            frame = { controlClassColor = false, controlHoverClassColor = true } } } } },
        global = { schemaVersion = 12 },
    })
    local frame = inst.NS.Database.FindWindow(1).frame

    assertEqual(frame.controlColorMode, "custom")
    assertEqual(frame.controlHoverColorMode, "class")
end)

test("Database: v12 -> v13 leaves a window with no frame block at all alone", function()
    -- `type(frame) == "table"` guards both halves of the step. A window written
    -- before the frame group existed, or hand-edited down to nothing, must reach
    -- the shipped defaults through the merge rather than take the login down or
    -- pick up a mode the step invented for it.
    local inst = preSeeded({
        profiles = { Default = { nextWindowId = 2,
            windows = { { id = 1, name = "A" } } } },
        global   = { schemaVersion = 12 },
    })
    local w = inst.NS.Database.FindWindow(1)

    assertEqual(inst.NS.db.global.schemaVersion, 16)
    assertTrue(w.header.show, "the shipped default arrived through the merge")
    assertEqual(w.frame.controlColorMode, "custom", "and so did the mode, not from the step")
end)

test("Database: v12 -> v13 walks every saved profile, not just the active one", function()
    -- The third step to need this said about it, for the third time for the same
    -- reason: schemaVersion is account-wide, so the inactive profile's one chance
    -- at v13 is this pass.
    -- red under: iterating `{ db.profile }` instead of db.sv.profiles.
    local inst = preSeeded({
        profiles = {
            Default = { windows = { { id = 1, name = "A", frame = { titleBar = false } } } },
            Raid    = { windows = { { id = 7, name = "R",
                frame = { titleBar = false, controlClassColor = true } } } },
        },
        global = { schemaVersion = 12 },
    })
    local raid = inst.NS.db.sv.profiles.Raid.windows[1]

    assertFalse(raid.header.show, "the inactive profile's title bar stayed off")
    assertEqual(raid.frame.controlColorMode, "class")
    assertNil(raid.frame.titleBar)
end)

-- ---------------------------------------------------------------------------
-- v13 -> v14: the addon-wide lock becomes every window's own
-- ---------------------------------------------------------------------------

test("Database: v13 -> v14 turns a stored master lock into every window's own lock", function()
    -- General > Lock frame stopped being a lock of its own and became a view over
    -- each window's `frame.locked`. A profile that had it ticked had every window
    -- pinned, and must log in to every window still pinned rather than to a key
    -- nothing reads any more.
    -- red under: pruning master.locked without carrying it onto the windows.
    local inst = preSeeded({
        profiles = { Default = { nextWindowId = 3, master = { locked = true, scale = 0.8 },
            windows = {
                { id = 1, name = "A", frame = { locked = false } },
                { id = 2, name = "B" },
            } } },
        global = { schemaVersion = 13 },
    })
    local profile = inst.NS.db.profile

    assertEqual(inst.NS.db.global.schemaVersion, 16)
    assertTrue(inst.NS.Database.FindWindow(1).frame.locked, "window 1 arrived unlocked")
    assertTrue(inst.NS.Database.FindWindow(2).frame.locked,
        "a window with no frame block arrived unlocked")
    assertNil(rawget(profile.master, "locked"), "the retired key outlived its reader")
    assertEqual(profile.master.scale, 0.8, "the step touched a master key it had no business with")
end)

test("Database: v13 -> v14 clears an unticked master lock and leaves the windows alone", function()
    -- A `false` or absent master lock pinned nothing, so nothing is pinned now:
    -- each window keeps exactly the lock it had.
    -- red under: locking (or unlocking) every window whatever the stored value said.
    for _, stored in ipairs({ false, "absent" }) do
        local master = {}
        if stored ~= "absent" then master.locked = stored end
        local inst = preSeeded({
            profiles = { Default = { nextWindowId = 3, master = master, windows = {
                { id = 1, name = "A", frame = { locked = true } },
                { id = 2, name = "B", frame = { locked = false } },
            } } },
            global = { schemaVersion = 13 },
        })
        local what = "master.locked = " .. tostring(stored)
        assertEqual(inst.NS.db.global.schemaVersion, 16, what)
        assertTrue(inst.NS.Database.FindWindow(1).frame.locked, what .. ": a locked window was unlocked")
        assertFalse(inst.NS.Database.FindWindow(2).frame.locked, what .. ": an unlocked window was locked")
        assertNil(rawget(inst.NS.db.profile.master, "locked"), what .. ": the key survived")
    end
end)

test("Database: v13 -> v14 walks every saved profile, not just the active one", function()
    -- schemaVersion is account-wide, so the inactive profile's one chance at v14
    -- is this pass.
    -- red under: iterating `{ db.profile }` instead of db.sv.profiles.
    local inst = preSeeded({
        profiles = {
            Default = { windows = { { id = 1, name = "A", frame = { locked = false } } } },
            Raid    = { master = { locked = true },
                        windows = { { id = 7, name = "R", frame = { locked = false } } } },
        },
        global = { schemaVersion = 13 },
    })
    local raid = inst.NS.db.sv.profiles.Raid

    assertTrue(raid.windows[1].frame.locked, "the inactive profile's window arrived unlocked")
    assertNil(raid.master.locked, "the inactive profile kept the retired key")
    assertFalse(inst.NS.Database.FindWindow(1).frame.locked,
        "the active profile had no master lock to carry")
end)

test("Database: v13 -> v14 survives a profile with no master block and a junk window", function()
    -- A hand-edited profile can hold anything. The step guards every table it
    -- reads, so it neither takes the login down nor skips the good window.
    local inst = preSeeded({
        profiles = {
            Default = { windows = { { id = 1, name = "A" } } },
            Odd     = { master = { locked = true }, windows = { "junk", { id = 4, name = "D" } } },
        },
        global = { schemaVersion = 13 },
    })
    local odd = inst.NS.db.sv.profiles.Odd

    assertEqual(inst.NS.db.global.schemaVersion, 16)
    assertEqual(odd.windows[1], "junk", "the step rewrote an entry that is not a window")
    assertTrue(odd.windows[2].frame.locked, "the window after the junk entry arrived unlocked")
    assertNil(odd.master.locked)
end)
