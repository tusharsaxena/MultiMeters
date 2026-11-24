-- tests/test_sample_names.lua — every named sample person comes from the library (FB2-MM-01;
-- Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH/R2_SMOKE_FEEDBACK.md, decision D1;
-- LibKa0s#104; LibKa0s-Sim-1.0 minor 5, `Sample()` and `SampleCrowd()`).
--
-- The owner, 2026-11-24: "adopt the predefined test mode names consistently across all addon's
-- test/sim modes". The convention's rule 6 ("roster pools do not converge") is retired: no addon
-- keeps a list of sample names. This addon draws named people in two places:
--   * test mode and the unlock preview (modules/Aggregator_Preview.lua): the five protagonists,
--     `Sample("retail")`, then five of the crowd, `SampleCrowd("retail", 13, 1)`, the first five
--     whose class the grid does not hold yet, so its ten rows are ten classes;
--   * the simulator's invented mates (modules/SimWorld.lua): `SampleCrowd("retail", 39, seed)`,
--     seeded with the world's own seed, so one seed is one group on every load.
-- Without the library test mode still draws ten rows, each named by its class, and the simulator
-- does not run at all. The last case holds the addon's source to the rule: no `Sample*`/`Mock*`
-- name literal outside tests/ (and the vendored libs/).

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local PLAYER = { guid = "Player-1-00000001", name = "Me", classFilename = "MAGE", role = "DAMAGER" }

local function row(name, class, role) return name .. "/" .. class .. "/" .. role end

test("Sample names: test mode's last five are the library's crowd, each a class the grid lacks", function()
    -- red under: a host list of its own five (Mockshade, Samplehex and the rest).
    local inst = T.load()
    local Sim = inst.mocks.LibStub("LibKa0s-Sim-1.0", true)
    assertTrue(Sim and type(Sim.SampleCrowd) == "function", "the premise: the library ships SampleCrowd")
    local want, used = {}, {}
    for _, r in ipairs(Sim.Sample("retail")) do used[r.classFile] = true end
    for _, r in ipairs(Sim.SampleCrowd("retail", 13, 1)) do
        if #want < 5 and not used[r.classFile] then
            want[#want + 1] = row(r.name, r.classFile, r.role)
            used[r.classFile] = true
        end
    end
    local group, got = inst.NS.Aggregator.TestGroup(), {}
    for i = 6, #group do got[#got + 1] = row(group[i].name, group[i].classFilename, group[i].role) end
    assertEqual(table.concat(got, ","), table.concat(want, ","))
    local classes = {}
    for _, m in ipairs(group) do classes[m.classFilename] = true end
    local n = 0
    for _ in pairs(classes) do n = n + 1 end
    assertEqual(n, 10, "ten rows, ten classes")
    for _, src in ipairs(inst.NS.Aggregator.TestColumn(1, "DamageDone").sources) do
        assertTrue(src.specIconID ~= nil, src.name .. " (" .. src.classFilename .. ") has a spec icon")
    end
end)

test("Sample names: the simulator's mates are the library's crowd for the world's seed", function()
    -- red under: SimWorld's own forty names, shuffled by the seed. The one reorder allowed: a
    -- five-player group with no pet owner takes the crowd's first damage dealer with a pet into its
    -- first damage slot (the two trade places), so every seed's dungeon shows a pet row.
    local inst = T.load()
    local Sim = inst.mocks.LibStub("LibKa0s-Sim-1.0", true)
    local W = inst.NS.SimHost.World
    local swapped = 0
    for seed = 1, 24 do
        local w = W.New(seed, PLAYER)
        local crowd = Sim.SampleCrowd("retail", 39, seed)
        assertEqual(#w.pool, 39, "a forty-player raid is the player and 39 of the crowd")
        local moved = {}
        for k, m in ipairs(w.pool) do
            local r = crowd[k]
            if m.name ~= r.name then moved[#moved + 1] = k end
            assertEqual(m.role, r.role, ("seed %d, mate %d keeps the crowd slot's role"):format(seed, k))
            local from
            for _, c in ipairs(crowd) do if c.name == m.name then from = c end end
            assertTrue(from ~= nil, ("seed %d, mate %d (%s) is one of the crowd"):format(seed, k, m.name))
            assertEqual(row(m.name, m.classFilename, m.role), row(from.name, from.classFile, from.role),
                ("seed %d, mate %d"):format(seed, k))
            assertEqual(m.pet and m.pet.name, from.pet, ("seed %d, mate %d's pet"):format(seed, k))
        end
        assertTrue(#moved == 0 or #moved == 2, ("seed %d: at most one trade"):format(seed))
        if #moved == 2 then
            swapped = swapped + 1
            assertTrue(moved[1] <= 4 and w.pool[moved[1]].pet ~= nil,
                ("seed %d: the pet joins the group"):format(seed))
        end
        local pets = 0
        for k = 1, 4 do if w.pool[k].pet then pets = pets + 1 end end
        assertTrue(pets >= 1, ("seed %d: the five-player group shows a pet"):format(seed))
    end
    assertTrue(swapped > 0, "the trade is exercised by some seed in 1 to 24")
end)

test("Sample names: one seed is one group, two seeds two groups", function()
    local inst = T.load()
    local W = inst.NS.SimHost.World
    local function names(seed)
        local out = {}
        for _, m in ipairs(W.New(seed, PLAYER).pool) do out[#out + 1] = m.name end
        return table.concat(out, ",")
    end
    assertEqual(names(9), names(9))
    assertTrue(names(9) ~= names(10), "two seeds gave the same crowd order")
end)

test("Sample names: without the library test mode draws ten rows named by their class", function()
    -- red under: a hand-kept copy of the library's rows.
    local inst = T.load{ libFiles = {} }
    local group = inst.NS.Aggregator.TestGroup()
    assertEqual(#group, 10, "ten rows")
    for _, m in ipairs(group) do
        assertTrue(not m.name:match("^Sample") and not m.name:match("^Mock"),
            "no sample name of this addon's own: " .. m.name)
        assertTrue(m.name ~= "", "a row has a name")
    end
end)

--- Every .lua file of the addon's own, outside tests/ and libs/.
local function sourceFiles()
    local root = T.root or "."
    local cmd = ("cd %q && find . -name '*.lua' -not -path './tests/*' -not -path './libs/*'"):format(root)
    local fh = assert(io.popen(cmd))
    local out = {}
    for line in fh:lines() do out[#out + 1] = line:gsub("^%./", "") end
    fh:close()
    table.sort(out)
    return out
end

--- The string literals on one line of code, comments stripped (a `--` outside a string).
local function literals(line)
    local out, i, n = {}, 1, #line
    while i <= n do
        local c = line:sub(i, i)
        if c == "-" and line:sub(i, i + 1) == "--" then break end
        if c == '"' or c == "'" then
            local j = i + 1
            while j <= n and line:sub(j, j) ~= c do
                if line:sub(j, j) == "\\" then j = j + 1 end
                j = j + 1
            end
            out[#out + 1] = line:sub(i + 1, j - 1)
            i = j + 1
        else
            i = i + 1
        end
    end
    return out
end

test("Sample names: no Sample*/Mock* name literal lives outside tests/ (D1)", function()
    -- red under: modules/Aggregator_Preview.lua's SAMPLE_COPY and HOST_MEMBERS.
    local files = sourceFiles()
    assertTrue(#files > 50, "the scan found the addon's files, got " .. #files)
    local offenders = {}
    for _, path in ipairs(files) do
        local fh = assert(io.open((T.root or ".") .. "/" .. path, "r"))
        local n = 0
        for line in fh:lines() do
            n = n + 1
            for _, s in ipairs(literals(line)) do
                if s:match("%f[%a]Sample%l") or s:match("%f[%a]Mock%l") then
                    offenders[#offenders + 1] = ("%s:%d: %s"):format(path, n, s)
                end
            end
        end
        fh:close()
    end
    assertEqual(table.concat(offenders, "\n"), "")
end)

test("Sample names: the literal scan is falsifiable", function()
    assertEqual(#literals([[local x = { name = "Mockshade" } -- "Samplehex"]]), 1)
    assertTrue(literals([[f('Samplegrove', "a\"b")]])[1] == "Samplegrove")
end)
