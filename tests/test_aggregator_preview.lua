-- tests/test_aggregator_preview.lua — modules/Aggregator_Preview.lua: the grid
-- with nobody in the group.
--
-- Peeled out of tests/test_aggregator.lua behind the module it mirrors. The
-- build pipeline stays there, the restricted build is in
-- tests/test_aggregator_identity.lua, ordering in tests/test_aggregator_sort.lua.
--
-- The one thing every case here is about: test mode substitutes the DATA, at
-- modules/Provider.lua, and NOT the render path. That is the whole design. A
-- separate preview result table built by a separate function is what shipped
-- once, and the two modes then diverged at every seam nobody thought to
-- duplicate — the tooltip found no source, the drill-down opened on nothing, and
-- every fix had to be applied twice. So the cases below assert what the preview
-- reaches (the live code) and what it must never reach (the meter API), and that
-- what it invents is deterministic, because a jittering grid cannot be laid out
-- against.
--
-- The fixtures are copies of tests/test_aggregator.lua's, small enough that a
-- duplicate is cheaper to read than a shared file to find.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue

local CURRENT = 1   -- Enum.DamageMeterSessionType.Current

local ALPHA = "Player-1-0000000A"
local BETA  = "Player-1-0000000B"
local GAMMA = "Player-1-0000000C"

local GROUP = {
    { guid = ALPHA, name = "Alpha", class = "PALADIN", role = "TANK"    },
    { guid = BETA,  name = "Beta",  class = "PRIEST",  role = "HEALER"  },
    { guid = GAMMA, name = "Gamma", class = "ROGUE",   role = "DAMAGER" },
}

--- A window config shaped exactly like a stored one, but small enough that a
--- case names only what it is about.
local function makeWindow(opts)
    opts = opts or {}
    local columns = {}
    for _, key in ipairs(opts.columns or { "DamageDone" }) do
        columns[#columns + 1] = { stat = key, width = 80, showBar = true }
    end
    return {
        id      = opts.id or 1,
        name    = "Test",
        columns = columns,
        rows    = opts.rows or {},
        data    = {
            sessionType = CURRENT,
            sortMode    = opts.sortMode or "provider",
            sortColumn  = opts.sortColumn,
        },
    }
end

--- A loaded instance with the standard three-player group.
local function loaded(opts)
    opts = opts or {}
    local inst = T.load()
    inst.mocks.setGroup(opts.group or GROUP)
    inst.NS.Roster.Refresh()
    return inst
end

-- ---------------------------------------------------------------------------
-- Preview
-- ---------------------------------------------------------------------------

test("Test mode substitutes the DATA, and the render path stays one path", function()
    -- It used to hand the renderer a whole separate result table built by a
    -- separate function, and the two modes then diverged at every seam nobody
    -- thought to duplicate: the tooltip found no source and said "No data yet",
    -- the drill-down opened on nothing, and every fix had to be applied twice.
    -- Substituting modules/Provider.lua's output instead means everything
    -- downstream is the live code reading invented numbers.
    -- red under: a `if testMode then BuildTestRows()` branch in the renderer.
    local inst = loaded()
    inst.NS.State.SetTestMode(true)

    local result = inst.NS.Aggregator.Build(makeWindow{ columns = { "DamageDone" } })
    assertTrue(#result > 1, "test mode must produce a full grid through Build")
    assertTrue(result[1].values.DamageDone ~= nil, "shaped exactly like live rows")
    assertTrue(result[1].name ~= nil)
end)

test("A test row's tooltip finds a breakdown, because it goes to the provider", function()
    -- The seam that was broken for a release. The tooltip asks the provider; the
    -- provider is what test mode replaces; so the tooltip needs no idea which
    -- mode it is in.
    local inst = loaded()
    inst.NS.State.SetTestMode(true)

    local result = inst.NS.Aggregator.Build(makeWindow{ columns = { "DamageDone" } })
    local detail = inst.NS.Provider.GetSourceDetail(CURRENT, "DamageDone", result[1].guid)
    assertTrue(type(detail) == "table", "a test row must have a spell breakdown")
    assertTrue(#detail.combatSpells > 0)
end)

test("Test mode reaches no meter API at all", function()
    -- The substitution is at the provider, so nothing behind it is ever asked.
    local inst = loaded()
    inst.NS.State.SetTestMode(true)
    inst.mocks.resetMeterCalls()

    inst.NS.Aggregator.Build(makeWindow{ columns = { "DamageDone", "Deaths" } })
    for name, count in pairs(inst.mocks.__meter.calls) do
        assertEqual(count, 0, "test mode called " .. name)
    end
end)

test("Test data is deterministic — a jittering grid cannot be laid out against", function()
    local inst = loaded()
    inst.NS.State.SetTestMode(true)
    local window = makeWindow{ columns = { "DamageDone" } }

    local first  = inst.NS.Aggregator.Build(window)
    local second = inst.NS.Aggregator.Build(window)
    assertEqual(#first, #second)
    for i = 1, #first do
        assertEqual(first[i].values.DamageDone.total, second[i].values.DamageDone.total)
    end
end)

test("Test mode produces a player with several deaths to drill into", function()
    -- The preview is how the drill-down is looked at without dying repeatedly in
    -- a dungeon. One death per member exercises the list at length 1 only, which
    -- is the length at which every ordering bug hides.
    -- red under: TestColumn emitting one Deaths source per member.
    local inst = T.load()
    inst.NS.State.testMode = true
    local rows = inst.NS.Aggregator.Build(makeWindow{ columns = { "Deaths" } })

    local most = 0
    for _, row in ipairs(rows) do
        local n = row.deaths and #row.deaths or 0
        if n > most then most = n end
        if row.deaths then
            assertEqual(n, row.values.Deaths.total, "preview count and list disagree")
        end
    end
    assertTrue(most > 1, "no preview player has more than one death")
end)
