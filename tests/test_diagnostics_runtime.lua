-- tests/test_diagnostics_runtime.lua — core/Diagnostics_Runtime.lua, the sections of
-- `/mm diagnostics` that describe the addon's own state (DX-MM, debug-logging-§14).
--
-- The probes in core/Diagnostics.lua ask the CLIENT what it has. These ask the ADDON
-- what it is doing: the latch and its holds, the restriction, the settings that
-- differ from what shipped (per profile and per window), every window, the sessions
-- the client holds and which one each window reads, the aggregator's last pass, and
-- the roster and caches. A player pastes one report; everything a maintainer would
-- otherwise ask for in a follow-up has to be in it.
--
-- Three properties matter as much as the content, and each has cases here:
--   * READ-ONLY. The report runs while disabled and in combat, so nothing it reaches
--     may reset the meter, invalidate a memo, refresh the roster or dirty a window.
--   * SECRET-SAFE. Session names and durations are secret in a pull; a line that
--     formats one raw goes dark or raises.
--   * NO GEOMETRY OFF A FRAME. A frame handed a secret has secret anchoring data, so
--     a window's position and size come from its config (rule R3).
--
-- STD-19's domain half. The dispatcher half (both forms, while disabled, append,
-- ungated, markers, no alias) is the kit's test_diagnostics_contract, wired in
-- tests/run.lua.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse

--- Run the report and hand back what it wrote: the joined text and the lines.
local function report(inst, spec)
    local D      = inst.NS.DebugLog
    local buffer = D.buffer
    local bufN   = #buffer
    D:RunDiagnostics(spec)
    local lines = {}
    for i = bufN + 1, #buffer do lines[#lines + 1] = buffer[i] end
    return table.concat(lines, "\n"), lines
end

--- The index of the first line carrying `needle`, or nil.
local function indexOf(lines, needle)
    for i, line in ipairs(lines) do
        if line:find(needle, 1, true) then return i end
    end
    return nil
end

--- The lines of one section: from its `-- name --` heading up to the next heading.
local function sectionOf(lines, name)
    local start = indexOf(lines, "-- " .. name .. " --")
    if not start then return nil end
    local out = {}
    for i = start + 1, #lines do
        if lines[i]:find("%-%- [%w ]+ %-%-") then break end
        out[#out + 1] = lines[i]
    end
    return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------
-- Order and shape
-- ---------------------------------------------------------------------------

test("Diagnostics runtime: the addon's state leads, the probes follow, rejected events close", function()
    -- STD-10's order: identity and state flags, then the settings that differ, then
    -- the domain sections, then the rejected events. The events section used to
    -- open the report; it now sits last, where (e) puts it.
    -- red under: the old section list, which led with `events`.
    local inst = T.load{ enable = true }
    local _, lines = report(inst)
    local order = { "state", "settings", "window settings", "windows", "sessions",
                    "aggregator", "roster and caches", "atlases", "provider order", "events" }
    local last = 0
    for _, name in ipairs(order) do
        local at = indexOf(lines, "-- " .. name .. " --")
        assertTrue(at ~= nil, "missing section: " .. name)
        assertTrue(at > last, "section out of order: " .. name)
        last = at
    end
end)

-- ---------------------------------------------------------------------------
-- State: the latch, the restriction, the session flags
-- ---------------------------------------------------------------------------

test("Diagnostics runtime: the state section prints the latch, its holds and the schema stamps", function()
    local inst = T.load{ enable = true }
    local section = sectionOf(select(2, report(inst)), "state")
    assertTrue(section ~= nil, "no state section")
    assertTrue(section:find("stored enabled=true disabled=false stood down=false", 1, true) ~= nil,
        "the latch line is missing or wrong:\n" .. section)
    assertTrue(section:find("holds: -", 1, true) ~= nil, "an empty hold set reads `-`:\n" .. section)
    assertTrue(section:find("schema: stored=" .. tostring(inst.NS.SCHEMA_VERSION)
        .. " code=" .. tostring(inst.NS.SCHEMA_VERSION), 1, true) ~= nil,
        "both schema stamps belong on the line:\n" .. section)
    assertTrue(section:find("profile: 'Default'", 1, true) ~= nil, "the active profile:\n" .. section)
end)

test("Diagnostics runtime: while disabled the state section names the hold and says stood down", function()
    -- STD-05: the report runs while the addon is off, and the first thing a reader
    -- needs is that it IS off, and why.
    -- red under: a state section that reads only the stored switch.
    local inst = T.load{ enable = true }
    inst.NS.SetByPath("enabled", false)
    local section = sectionOf(select(2, report(inst)), "state")
    assertTrue(section:find("stored enabled=false disabled=true stood down=true", 1, true) ~= nil,
        section)
    assertTrue(section:find("holds: disabled", 1, true) ~= nil, "the hold is named:\n" .. section)
end)

test("Diagnostics runtime: the restriction is printed as mirror, authority and raw state", function()
    -- NS.State.restricted is a fast mirror; Secrets.IsRestricted is the authority.
    -- The report prints both, because the bug worth catching is the two disagreeing.
    local inst = T.load{ enable = true }
    inst.mocks.setRestricted(true)
    local section = sectionOf(select(2, report(inst)), "state")
    assertTrue(section:find("restriction: mirror=false authority=true state=2", 1, true) ~= nil,
        "the restriction line:\n" .. section)
    assertTrue(section:find("test mode=false", 1, true) ~= nil, "the test-mode flag:\n" .. section)
    assertTrue(section:find("provider suspended=false", 1, true) ~= nil,
        "the provider's suspend flag:\n" .. section)
    assertTrue(section:find("meter: memo checked=", 1, true) ~= nil,
        "the provider's availability memo:\n" .. section)
end)

-- ---------------------------------------------------------------------------
-- Settings: per profile, and per window against NS.DefaultWindow
-- ---------------------------------------------------------------------------

test("Diagnostics runtime: profile settings print the three always-rows and only what changed", function()
    -- DX-MM's always-print rows are `enabled`, `master.visibility` and
    -- `data.mergePets`, whatever their values. Everything else prints only when it
    -- differs from the schema default, as `path = value (default)`.
    local inst = T.load{ enable = true }
    inst.NS.SetByPath("data.throttle", 0.5)
    local section = sectionOf(select(2, report(inst)), "settings")
    assertTrue(section ~= nil, "no settings section")
    for _, path in ipairs({ "enabled = true (true)", "master.visibility = ",
                            "data.mergePets = false (false)" }) do
        assertTrue(section:find(path, 1, true) ~= nil, "always-row missing: " .. path .. "\n" .. section)
    end
    assertTrue(section:find("data.throttle = 0.5 (0.25)", 1, true) ~= nil,
        "a changed row prints value and default:\n" .. section)
    assertTrue(section:find("master.scale", 1, true) == nil,
        "an unchanged row prints nothing:\n" .. section)
    assertTrue(section:find("window.", 1, true) == nil,
        "window rows belong to the per-window diff, not the profile one:\n" .. section)
end)

test("Diagnostics runtime: each window is diffed against NS.DefaultWindow, position from config", function()
    -- The per-window half: a window's stored table against a fresh NS.DefaultWindow
    -- for the same id and name. The position is a config value like any other and
    -- prints from the config (rule R3), never off the frame.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local w = NS.Database.GetWindows()[1]
    w.frame.width = 300
    w.frame.position = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 12, y = -40 }
    local section = sectionOf(select(2, report(inst)), "window settings")
    assertTrue(section ~= nil, "no window settings section")
    assertTrue(section:find("window #" .. tostring(w.id), 1, true) ~= nil, "the window is named:\n" .. section)
    assertTrue(section:find("window.frame.width = 300 (694)", 1, true) ~= nil,
        "a changed window value:\n" .. section)
    assertTrue(section:find("window.frame.position = {point=TOPLEFT", 1, true) ~= nil,
        "the stored position, from config:\n" .. section)
    assertTrue(section:find("window.frame.height", 1, true) == nil,
        "an unchanged window value prints nothing:\n" .. section)
end)

test("Diagnostics runtime: a window's column list diffs as one compact line", function()
    local inst = T.load{ enable = true }
    local w = inst.NS.Database.GetWindows()[1]
    w.columns[1].enabled = false
    local section = sectionOf(select(2, report(inst)), "window settings")
    local line = section:match("window%.columns = [^\n]*")
    assertTrue(line ~= nil, "the changed column list:\n" .. section)
    assertTrue(line:find(w.columns[1].stat .. "-", 1, true) ~= nil,
        "a column reads stat+ or stat-: " .. line)
end)

-- ---------------------------------------------------------------------------
-- Windows, sessions, aggregator, roster
-- ---------------------------------------------------------------------------

test("Diagnostics runtime: one inventory line per window, with the ladder's answer", function()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.WindowManager:Create("Second")
    local windows = NS.Database.GetWindows()
    local section = sectionOf(select(2, report(inst)), "windows")
    assertTrue(section ~= nil, "no windows section")
    assertTrue(section:find("context: ", 1, true) ~= nil, "the resolved context:\n" .. section)
    for _, w in ipairs(windows) do
        -- two lines per window: the instance facts, then the ladder and the placement.
        local line = section:match("#" .. w.id .. " '[^\n]*\n[^\n]*")
        assertTrue(line ~= nil, "no line for window #" .. w.id .. ":\n" .. section)
        assertTrue(line:find("built=true", 1, true) ~= nil, line)
        assertTrue(line:find("ShouldShow=", 1, true) ~= nil, line)
        assertTrue(line:find("last pass=", 1, true) ~= nil, line)
        assertTrue(line:find("size=", 1, true) ~= nil, line)
    end
end)

test("Diagnostics runtime: the inventory never reads geometry off a window frame", function()
    -- Rule R3: a frame given a secret has secret anchoring data, so asking it where
    -- it is raises in a pull. The inventory reads position and size from config.
    -- red under: inst.frame:GetPoint() / GetSize() in the windows section.
    local inst = T.load{ enable = true }
    for _, wi in ipairs(inst.NS.WindowManager.All()) do
        local f = wi.frame
        for _, m in ipairs({ "GetPoint", "GetSize", "GetWidth", "GetHeight", "GetLeft", "GetTop" }) do
            f[m] = function() error("geometry read on a window frame: " .. m, 2) end
        end
    end
    local text = report(inst)
    assertTrue(text:find("section windows failed", 1, true) == nil, text)
    assertTrue(text:find("geometry read", 1, true) == nil, text)
end)

test("Diagnostics runtime: the sessions the client holds are listed, and a stale pin names its fallback", function()
    local inst = T.load{ enable = true }
    inst.mocks.setAvailableSessions({
        { sessionID = 7, name = "Trash", durationSeconds = 41 },
        { sessionID = 9, name = "Boss",  durationSeconds = 212 },
    })
    local w = inst.NS.Database.GetWindows()[1]
    w.data.sessionID = 4   -- a segment the client no longer holds
    local section = sectionOf(select(2, report(inst)), "sessions")
    assertTrue(section ~= nil, "no sessions section")
    assertTrue(section:find("held: 2", 1, true) ~= nil, "the count:\n" .. section)
    assertTrue(section:find("#7 Trash 41s", 1, true) ~= nil, "a session entry:\n" .. section)
    assertTrue(section:find("pinned=4 held=false", 1, true) ~= nil,
        "a stale pin is flagged:\n" .. section)
    assertTrue(section:find("falls back to type", 1, true) ~= nil,
        "and names what the window reads instead:\n" .. section)
end)

test("Diagnostics runtime: secret session names and durations print as <secret>, not a failure", function()
    local inst = T.load{ enable = true }
    local m = inst.mocks
    m.setAvailableSessions({ { sessionID = 3, name = m.secret("Pull"), durationSeconds = m.secret(30) } })
    m.setRestricted(true)
    local text, lines = report(inst)
    assertTrue(text:find("section sessions failed", 1, true) == nil, text)
    local section = sectionOf(lines, "sessions")
    assertTrue(section:find("#3 ", 1, true) ~= nil, "the plain id survives:\n" .. section)
end)

test("Diagnostics runtime: the aggregator's last render pass is reported per window", function()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local w = NS.Database.GetWindows()[1]
    local before = sectionOf(select(2, report(inst)), "aggregator")
    assertTrue(before ~= nil, "no aggregator section")

    NS.Aggregator.Build(w, "refresh")
    local pass = NS.Aggregator.LastPass(w.id)
    assertTrue(pass ~= nil, "a render pass is recorded")
    local after = sectionOf(select(2, report(inst)), "aggregator")
    assertTrue(after:find("#" .. w.id .. " cols=" .. pass.cols .. " rows=" .. pass.rows, 1, true) ~= nil,
        "the recorded pass is printed:\n" .. after)
end)

test("Diagnostics runtime: an export build does not overwrite the window's last render pass", function()
    -- The export builds a synthetic config and passes no perf parent. Recording it
    -- would make the report describe a grid nobody is looking at.
    -- red under: recordPass without the `parentKey ~= "refresh"` guard.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local w = NS.Database.GetWindows()[1]
    assertEqual(NS.Aggregator.LastPass(w.id), nil, "nothing recorded before a pass")
    NS.Aggregator.Build(w)
    assertEqual(NS.Aggregator.LastPass(w.id), nil, "a build with no `refresh` parent is not a render pass")
end)

test("Diagnostics runtime: roster and cache counts are printed without building the roster", function()
    -- Roster.GetGroup builds on a miss and writes the remembered map, so the report
    -- reads the cache as it stands and says `not built` rather than building it.
    -- red under: the section calling Roster.GetGroup.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.State.WipeCache("Roster")
    local built = 0
    local realGet = NS.Roster.GetGroup
    NS.Roster.GetGroup = function(...) built = built + 1 return realGet(...) end
    local section = sectionOf(select(2, report(inst)), "roster and caches")
    NS.Roster.GetGroup = realGet
    assertTrue(section ~= nil, "no roster section")
    assertTrue(section:find("live group: not built", 1, true) ~= nil, section)
    assertTrue(section:find("remembered: ", 1, true) ~= nil, section)
    assertTrue(section:find("caches: ", 1, true) ~= nil and section:find("Roster=", 1, true) ~= nil,
        "cache counts by name:\n" .. section)
    -- the targets probe still asks the roster for names; only this section must not.
    assertTrue(built <= 1, "the roster section built the group")
end)

-- ---------------------------------------------------------------------------
-- Read-only, stood down, capped
-- ---------------------------------------------------------------------------

test("Diagnostics runtime: the report resets, invalidates, refreshes and dirties nothing", function()
    -- DX-MM's never-list: Provider.Reset / Invalidate*, Roster.Refresh, MarkAllDirty.
    -- It also leaves the settings panel's window pointer where it was.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local calls = {}
    local function spy(tbl, name, label)
        local real = tbl[name]
        tbl[name] = function(...) calls[#calls + 1] = label return real(...) end
    end
    spy(NS.Provider, "Reset", "Provider.Reset")
    spy(NS.Provider, "InvalidateAvailability", "Provider.InvalidateAvailability")
    spy(NS.Provider, "InvalidateRecaps", "Provider.InvalidateRecaps")
    spy(NS.Roster, "Refresh", "Roster.Refresh")
    spy(NS.Roster, "Forget", "Roster.Forget")
    spy(NS.WindowManager, "MarkAllDirty", "WindowManager.MarkAllDirty")
    local D = NS.DebugLog
    spy(D, "Clear", "DebugLog.Clear")
    NS.State.activeWindowId = nil
    inst.mocks.resetMeterCalls()

    report(inst)
    assertEqual(table.concat(calls, ", "), "", "the report mutated state")
    assertEqual(inst.mocks.__meter.calls.ResetAllCombatSessions, nil, "the report reset the meter")
    assertEqual(NS.State.activeWindowId, nil, "the report moved the settings panel's window pointer")
end)

test("Diagnostics runtime: while stood down the runtime sections say so instead of printing empty", function()
    -- STD-05 (Q4): released runtime state is reported as released, not as idle.
    -- red under: the sessions section without its stood-down branch, which lists
    -- the suspended provider's empty answer as if the client held nothing.
    local inst = T.load{ enable = true }
    inst.NS.SetByPath("enabled", false)
    local _, lines = report(inst)
    for _, name in ipairs({ "sessions", "aggregator" }) do
        local section = sectionOf(lines, name)
        assertTrue(section ~= nil and section:find("stood down", 1, true) ~= nil,
            name .. " does not say it is stood down:\n" .. tostring(section))
    end
end)

test("Diagnostics runtime: an over-cap report ends in the truncated line, then the end marker", function()
    -- STD-15 / STD-19: a capped report is still whole at its end.
    local inst = T.load{ enable = true }
    local _, lines = report(inst, { maxLines = 30 })
    assertEqual(#lines, 30, "the cap bounds the report")
    assertTrue(lines[#lines - 1]:find("truncated: ", 1, true) ~= nil, lines[#lines - 1])
    assertTrue(lines[#lines]:find("diagnostics end: 30 line(s)", 1, true) ~= nil, lines[#lines])
end)

test("Diagnostics runtime: under the restriction with secret values no runtime section fails", function()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Aggregator.Build(NS.Database.GetWindows()[1], "refresh")
    inst.mocks.setRestricted(true)
    inst.mocks.setSecretValues(true)
    local text = report(inst)
    for _, name in ipairs({ "state", "settings", "window settings", "windows", "sessions",
                            "aggregator", "roster and caches" }) do
        assertFalse(text:find("section " .. name .. " failed", 1, true) ~= nil, text)
    end
end)
