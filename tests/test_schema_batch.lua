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
