-- tests/test_schema_batch.lua
--
-- NS.SetByPaths, the batch write, pinned by what a caller can observe rather than by how the seam
-- does it. Written GREEN AGAINST THE HOST'S OWN SEAM first, as a characterization, and then kept
-- green across the move onto LibKa0s-Schema-1.0 minor 2 (issue #52, MM-14), where the batch became
-- `S.SetMany` and the single write `S.Set`. So nothing here names a host internal or a library
-- member: every case drives NS.SetByPaths / NS.SetByPath / NS.GetSetting and reads the store, the
-- bus and the debug sink.
--
-- What is pinned, one case each:
--   (a) all or nothing -- one refused entry stores no entry, and the answer is `false, err`;
--   (b) one CONFIG_CHANGED per batch, however many rows it wrote;
--   (c) a bulk act (a `summary`) logs exactly one `[Set] <summary>: N rows` line;
--   (d) the window id addresses THAT window, never the active one;
--   (e) `window.columns` is written whole, normalized and deep-copied, and a path into the array
--       is refused;
--   (f) the minimap row reads SHOWN and stores LibDBIcon's `hide`, inverted;
--   (g) every entry is stored before any row reacts, so an onChange sees the whole batch.
--   Minimap path (a)-(f): the row's CLI path is `global.minimap.shown` (launcher-§3 v2.65.0), the
--       old `global.minimap.hide` path is unknown, and a stored `hide` carries over with no
--       SavedVariables step and no `shown` key ever written.
--
-- tests/test_schema_paths.lua covers the single write in depth; this file is the batch's.

local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue, assertFalse = T.assertEqual, T.assertTrue, T.assertFalse

--- A loaded addon with TWO windows, the FIRST one active. Returns the instance and both ids.
local function twoWindows()
    local inst = T.load()
    local NS = inst.NS
    assertTrue(NS.WindowManager:Create("Second"))
    local list = NS.Database.GetWindows()
    assertEqual(#list, 2)
    NS.State.SetActiveWindow(list[1].id)
    return inst, list[1].id, list[2].id
end

--- Every CONFIG_CHANGED payload, on a private bus target.
local function heardConfig(NS)
    local seen = {}
    NS.NewBusTarget():RegisterMessage(NS.Constants.MSG.CONFIG_CHANGED, function(_, payload)
        seen[#seen + 1] = payload
    end)
    return seen
end

--- Every [Set] debug line from here on, FORMATTED with all of its arguments; call the second
--- answer to stop listening. Formatted here rather than compared argument by argument, because
--- how many arguments a line is split into is the seam's business and the text is the contract.
local function heardSetLines(NS)
    local original, lines = NS.Debug, {}
    NS.Debug = function(tag, fmt, ...)
        if tag ~= "Set" then return end
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        lines[#lines + 1] = fmt:gsub("%%d", "%%s"):format(unpack(args, 1, select("#", ...)))
    end
    return lines, function() NS.Debug = original end
end

test("SetByPaths (a): one refused entry stores NO entry, and answers false with a reason", function()
    -- red under: a batch that stores each entry as it validates it.
    local inst, first = twoWindows()
    local NS = inst.NS
    local w = NS.Database.FindWindow(first)
    local width, height = w.frame.width, w.frame.height
    local seen = heardConfig(NS)

    local ok, err = NS.SetByPaths({
        { "window.frame.width", width + 11 },
        { "window.frame.scale", 99 },          -- outside the row's 0.5..2 range
        { "window.frame.height", height + 7 },
    })
    assertFalse(ok)
    assertEqual(type(err), "string")
    assertTrue(err:find("window.frame.scale", 1, true) ~= nil, "the refusal names the path: " .. err)
    assertEqual(w.frame.width, width, "the entry ahead of the refusal was stored")
    assertEqual(w.frame.height, height, "the entry after the refusal was stored")
    assertEqual(#seen, 0, "a refused batch announced")
end)

test("SetByPaths (b): a three-row batch sends exactly ONE CONFIG_CHANGED", function()
    -- red under: an announce per entry, which re-applies the window three times for one click.
    local inst, first = twoWindows()
    local NS = inst.NS
    local seen = heardConfig(NS)

    assertTrue(NS.SetByPaths({
        { "window.frame.width", 401 },
        { "window.frame.height", 302 },
        { "window.frame.scale", 1.25 },
    }))
    assertEqual(#seen, 1)
    assertEqual(seen[1].section, "frame", "one page, so the announcement names it")
    assertEqual(seen[1].windowId, first)
end)

test("SetByPaths (c): a bulk act logs exactly one '[Set] <summary>: N rows' line", function()
    -- red under: a per-row [Set] line inside a bulk act, or a summary that is split and
    -- re-joined differently from how the caller spelled it.
    local inst, _, second = twoWindows()
    local NS = inst.NS
    local lines, restore = heardSetLines(NS)
    local ok = NS.SetByPaths({
        { "window.frame.width", 433 },
        { "window.frame.height", 244 },
        { "window.bars.border", true },
    }, second, "copy from 'Main' to 'Second'")
    restore()

    assertTrue(ok)
    assertEqual(#lines, 1, "lines: " .. table.concat(lines, " | "))
    assertEqual(lines[1], "copy from 'Main' to 'Second': 3 rows")
end)

test("SetByPaths (d): a window id writes THAT window, not the active one", function()
    -- red under: the id dropped on the way to the seam, so the active window takes the write.
    local inst, first, second = twoWindows()
    local NS = inst.NS
    local before = NS.Database.FindWindow(first).frame.width

    assertTrue(NS.SetByPaths({ { "window.frame.width", 517 } }, second))
    assertEqual(NS.Database.FindWindow(second).frame.width, 517)
    assertEqual(NS.Database.FindWindow(first).frame.width, before, "the active window moved")
    assertEqual(NS.State.activeWindowId, first, "the picker moved")
end)

test("SetByPaths (e): window.columns is written whole, normalized and copied; a path into it is refused", function()
    -- red under: storing the caller's table, skipping the repair, or accepting an ordinal path.
    local inst, first = twoWindows()
    local NS = inst.NS
    local mine = {
        { stat = "HealingDone", enabled = false },
        { stat = "DamageDone",  enabled = true, smuggled = 1 },
    }
    assertTrue(NS.SetByPaths({ { "window.columns", mine } }))

    local stored = NS.Database.FindWindow(first).columns
    assertEqual(#stored, #NS.Constants.STATS, "the array was not repaired into the whole catalog")
    assertEqual(stored[1].stat, "DamageDone", "the enabled column was not sorted first")
    assertTrue(stored[1].enabled)
    assertEqual(stored[1].smuggled, nil, "an extra key was persisted")
    assertTrue(stored ~= mine and stored[1] ~= mine[2], "the caller's tables were stored")
    mine[2].stat = "Deaths"
    assertEqual(stored[1].stat, "DamageDone", "the caller can still reach into the profile")

    local ok, err = NS.SetByPaths({ { "window.columns.2.enabled", true } })
    assertFalse(ok)
    assertEqual(type(err), "string")
end)

test("SetByPaths (f): the minimap row reads SHOWN and stores hide, inverted", function()
    -- red under: the row storing its own sense, or reading LibDBIcon's key back uninverted.
    local inst = T.load()
    local NS = inst.NS
    assertTrue(NS.SetByPaths({ { NS.MINIMAP_PATH, false } }))
    assertEqual(NS.db.global.minimap.hide, true, "display false stores hide = true")
    assertEqual(NS.GetSetting(NS.MINIMAP_PATH), false)
    assertTrue(NS.SetByPaths({ { NS.MINIMAP_PATH, true } }))
    assertEqual(NS.db.global.minimap.hide, false)
    assertEqual(NS.GetSetting(NS.MINIMAP_PATH), true)
    assertEqual(NS.db.profile.global, nil, "the row leaked into the profile")
end)

test("SetByPaths (g): every entry is stored before the first row reacts", function()
    -- The batch stores every entry, THEN runs every onChange, so a reaction reading a sibling
    -- row sees the whole batch. Both the host seam and LibKa0s-Schema-1.0's SetMany do this.
    -- red under: store-and-react per entry, where the first onChange reads the old height.
    local inst, first = twoWindows()
    local NS = inst.NS
    local row = NS.FindSchemaRow("window.visibility.world")
    local original, sawDungeon = row.onChange, "unset"
    row.onChange = function(_, id)
        sawDungeon = NS.Database.FindWindow(id).visibility.dungeon
    end
    local before = NS.Database.FindWindow(first).visibility.dungeon

    local ok = NS.SetByPaths({
        { "window.visibility.world", true },
        { "window.visibility.dungeon", not before },
    })
    row.onChange = original

    assertTrue(ok)
    assertEqual(sawDungeon, not before, "the first onChange ran before the second entry was stored")
end)

-- ---------------------------------------------------------------------------
-- The minimap row's CLI path reads in its own SHOWN sense (launcher-§3, standard v2.65.0)
-- ---------------------------------------------------------------------------
--
-- The path is `global.minimap.shown`: the CLI name says what the checkbox says. The STORE did not
-- move and did not change sense -- it is LibDBIcon's `db.global.minimap.hide`, and a stored
-- `shown` key beside it would be two records of one state (anti-pattern #81). So the rename is a
-- CLI and schema rename only, with no SavedVariables step and no schema-version bump, and the
-- cases below pin both halves: the new name answers, the old one does not, and an existing
-- player's stored choice reads through the new name unchanged.

local SHOWN_PATH = "global.minimap.shown"
local OLD_PATH   = "global.minimap.hide"

local function say(inst, msg)
    local n = #inst.mocks.__chat
    inst.NS.Slash:OnSlash(msg)
    local out = {}
    for i = n + 1, #inst.mocks.__chat do out[#out + 1] = inst.mocks.__chat[i] end
    return table.concat(out, "\n")
end

--- A load driven the way the client drives one, against `saved` as the SavedVariables global:
--- InitDB, the migration runner, then the launcher registration and the panel.
local function loadWith(saved)
    local inst = T.load{ initDB = false, options = false }
    _G.MultiMetersDB = saved
    inst.NS:InitDB()
    inst.NS:RunMigrations()
    inst.NS.Launcher:Register()
    inst.NS.CreateOptionsPanel()
    return inst
end

--- Every key in the RAW SavedVariables minimap table, and whether any profile still holds one.
local function rawMinimap()
    local sv = _G.MultiMetersDB
    return sv and rawget(sv, "global") and rawget(sv.global, "minimap")
end

test("Minimap path (a): `/mm get global.minimap.shown` answers true while hide is false", function()
    local inst = T.load()
    inst.NS.db.global.minimap.hide = false
    local out = say(inst, "get " .. SHOWN_PATH)
    assertTrue(out:find("true", 1, true) ~= nil, out)
    assertEqual(out:find("false", 1, true), nil, out)
end)

test("Minimap path (b): `/mm set global.minimap.shown false` stores hide = true and hides the button", function()
    local inst = T.load()
    assertTrue(inst.NS.Launcher:IsShown(), "the button ships shown")
    say(inst, "set " .. SHOWN_PATH .. " false")
    assertEqual(inst.NS.db.global.minimap.hide, true, "display false stores LibDBIcon's hide = true")
    assertFalse(inst.NS.Launcher:IsShown(), "and the button went away now, not at the next reload")
    say(inst, "set " .. SHOWN_PATH .. " true")
    assertEqual(inst.NS.db.global.minimap.hide, false)
    assertTrue(inst.NS.Launcher:IsShown())
end)

test("Minimap path (c): the old `global.minimap.hide` path is an unknown setting", function()
    local inst = T.load()
    assertEqual(inst.NS.FindSchemaRow(OLD_PATH), nil, "no row answers to the retired path")
    local out = say(inst, "get " .. OLD_PATH)
    assertTrue(out:find("Setting not found", 1, true) ~= nil, out)
    say(inst, "set " .. OLD_PATH .. " true")
    assertEqual(inst.NS.db.global.minimap.hide, false, "the retired path wrote nothing")
end)

test("Minimap path (d): no `shown` key is ever stored, raw, after a set", function()
    local inst = T.load()
    say(inst, "set " .. SHOWN_PATH .. " false")
    local raw = rawMinimap()
    assertTrue(raw ~= nil, "the global minimap table is in the raw SavedVariables")
    assertEqual(rawget(raw, "shown"), nil, "a stored `shown` key is anti-pattern #81")
    assertEqual(rawget(raw, "hide"), true)
    assertEqual(inst.NS.db.global.minimap.shown, nil)
end)

test("Minimap path (e): a legacy global store carries over, button hidden, position untouched", function()
    -- An account saved before the rename: LibDBIcon's own table, hidden, dragged to 200 degrees.
    local inst = loadWith({
        global = { schemaVersion = 16, minimap = { hide = true, minimapPos = 200 } },
    })
    local out = say(inst, "get " .. SHOWN_PATH)
    assertTrue(out:find("false", 1, true) ~= nil, out)
    assertFalse(inst.NS.Launcher:IsShown(), "the button stays hidden after load")
    assertEqual(inst.NS.db.global.minimap.minimapPos, 200, "the dragged angle is untouched")
    assertEqual(inst.NS.db.global.schemaVersion, inst.NS.SCHEMA_VERSION,
        "the rename adds no migration step")

    say(inst, "set " .. SHOWN_PATH .. " false")
    local raw = rawMinimap()
    assertEqual(rawget(raw, "shown"), nil, "no `shown` key after a set")
    assertEqual(rawget(raw, "hide"), true)
    assertEqual(rawget(raw, "minimapPos"), 200)
end)

test("Minimap path (f): a pre-v15 profile-scoped store, migrated, reads shown = false", function()
    local inst = loadWith({
        global   = { schemaVersion = 14 },
        profileKeys = {},
        profiles = { Default = { minimap = { hide = true, minimapPos = 75 } } },
    })
    assertEqual(inst.NS.db.global.schemaVersion, inst.NS.SCHEMA_VERSION)
    assertEqual(inst.NS.GetSetting(SHOWN_PATH), false)
    assertTrue(say(inst, "get " .. SHOWN_PATH):find("false", 1, true) ~= nil)
    assertFalse(inst.NS.Launcher:IsShown())
    local raw = rawMinimap()
    assertEqual(rawget(raw, "shown"), nil, "no `shown` key in the raw SavedVariables")
    assertEqual(rawget(raw, "hide"), true)
    assertEqual(rawget(raw, "minimapPos"), 75)
end)
