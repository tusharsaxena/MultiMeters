-- tests/test_diagnostics_deathrecap.lua — core/Diagnostics_DeathRecap.lua, the
-- `/mm debug recap` probe.
--
-- Peeled out of tests/test_diagnostics.lua alongside the module, because a probe
-- written for an issue is meant to be deleted with the issue and that only works
-- if its cases can go out with it. The frame, the entry point and the short
-- probes stayed behind in test_diagnostics.lua; everything issue #1 asks the
-- client is here, in the two rounds it was asked in.
--
-- The property the parent suite protects protects this one too: the probe must
-- run to completion on a hostile client, print rather than raise, and never be
-- the reason a player cannot describe what they are seeing.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertNil   = T.assertNil

--- Run the FULL report and hand back everything it printed, as one string.
---
--- The same helper test_diagnostics.lua opens with, duplicated rather than
--- published, because it is four lines of buffer arithmetic and a shared copy
--- would tie two suites together for no gain. BOTH SINKS are drained, because
--- the report has two and picks between them at run time: the debug console when
--- one is open, and chat when it is not. Three cases below assert that the recap
--- probe rides along in the full report, and those are the ones that need it.
local function report(inst)
    local D      = inst.NS.DebugLog
    local buffer = D and D.buffer
    local chatN  = #inst.mocks.__chat
    local bufN   = buffer and #buffer or 0

    inst.NS.Diagnostics.Report()

    local lines = {}
    if buffer then
        for i = bufN + 1, #buffer do lines[#lines + 1] = buffer[i] end
    end
    for i = chatN + 1, #inst.mocks.__chat do lines[#lines + 1] = inst.mocks.__chat[i] end
    return table.concat(lines, "\n"), lines
end

-- ---------------------------------------------------------------------------
-- The death-recap probe (issue #1)
-- ---------------------------------------------------------------------------
--
-- Issue #1 wants a two-pane Death Recap window whose left pane lists every death
-- and whose right pane breaks the selected one down. Three things about the live
-- client decide whether that window can be built on `deathRecapID` at all, and
-- all three are currently guesses:
--
--   * does an id resolve for a NON-LOCAL player?
--   * does one resolve for a death from EARLIER IN THE RUN?
--   * is there any reader for the per-event breakdown, or only Blizzard's
--     frame-opening call?
--
-- If the answers are no, the window needs its own combat-log capture and the
-- issue is a materially larger job. This section is what turns that fork into
-- something a player can paste back instead of something we guess at twice.

--- Run only the recap probe and hand back everything it printed.
local function recapReport(inst)
    local D      = inst.NS.DebugLog
    local buffer = D and D.buffer
    local chatN  = #inst.mocks.__chat
    local bufN   = buffer and #buffer or 0

    inst.NS.Diagnostics.ReportDeathRecap()

    local lines = {}
    if buffer then
        for i = bufN + 1, #buffer do lines[#lines + 1] = buffer[i] end
    end
    for i = chatN + 1, #inst.mocks.__chat do lines[#lines + 1] = inst.mocks.__chat[i] end
    return table.concat(lines, "\n"), lines
end

--- A client that answers a recap for every id.
local function withRecapsFor(inst)
    inst.mocks.setDeathRecap({
        HasRecapEvents    = function() return true end,
        GetRecapEvents    = function(id)
            return { { spellId = 1, spellName = "X", amount = 1, currentHP = 1,
                       timestamp = 1787381686 + id } }
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })
end

--- Seed the Deaths column with raw source rows and point window 1 at Current.
local function deathsSession(inst, rows)
    inst.NS.Database.GetWindows()[1].data.sessionType = 1
    inst.mocks.setSession(1, inst.mocks.Enum.DamageMeterType.Deaths, {
        combatSources = rows, maxAmount = 0, totalAmount = 0,
    })
end

--- The shape the client actually reports: ONE ROW PER DEATH, newest first, the
--- same `sourceGUID` repeated, a distinct `deathRecapID` on each.
local function death(guid, name, isLocal, recapID, when)
    return { sourceGUID = guid, name = name, isLocalPlayer = isLocal,
             totalAmount = 0, deathRecapID = recapID, deathTimeSeconds = when }
end

test("Diagnostics: `/mm debug recap` reaches the probe without the debug log", function()
    -- Same reasoning as `diag`: it is what a player is asked to run, and making
    -- them open a console first is one more step between us and the answer.
    -- red under: hanging the verb off the DebugLog branch in doDebug.
    local inst = T.load{ enable = true }
    inst.NS.DebugLog = nil

    local n = #inst.mocks.__chat
    inst.NS.Slash:OnSlash("debug recap")
    assertTrue(#inst.mocks.__chat > n, "the probe printed nothing")
end)

test("Diagnostics: the probe lists EVERY death, not just the newest per player", function()
    -- THE WHOLE POINT OF THE DUMP. modules/Aggregator.lua keeps one recap id per
    -- player and throws the rest away, which is exactly what issue #1 says has to
    -- stop. A probe that reported the aggregator's view would confirm the bug
    -- instead of measuring the client.
    -- red under: reading row.deathRecapID off the aggregated grid.
    local inst = T.load{ enable = true }
    deathsSession(inst, {
        death("Player-1-0000000A", "Pillows", false, 1003, 210),
        death("Player-1-0000000A", "Pillows", false, 1002, 118),
        death("Player-1-0000000A", "Pillows", false, 1001, 42),
    })

    local text = recapReport(inst)
    for _, id in ipairs({ "1001", "1002", "1003" }) do
        assertTrue(text:find(id, 1, true) ~= nil, "recap id " .. id .. " was dropped")
    end
end)

test("Diagnostics: it probes a NON-LOCAL id and an OLDER id, not only the newest", function()
    -- These two ARE the open questions. A probe that only ever called the local
    -- player's most recent death would come back green on a client that answers
    -- nothing else, and issue #1 would be designed on it.
    -- red under: probing sources[1] alone.
    local inst = T.load{ enable = true }
    deathsSession(inst, {
        death("Player-1-0000000A", "Me",     true,  2002, 300),
        death("Player-1-0000000A", "Me",     true,  2001, 100),
        death("Player-1-0000000B", "Notme",  false, 3002, 280),
        death("Player-1-0000000B", "Notme",  false, 3001, 90),
    })
    inst.mocks.setDeathInfo({ GetRecapEvent = function() return nil end })

    local text = recapReport(inst)
    assertTrue(text:find("local/newest", 1, true) ~= nil)
    assertTrue(text:find("local/older", 1, true) ~= nil)
    assertTrue(text:find("other/newest", 1, true) ~= nil)
    assertTrue(text:find("other/older", 1, true) ~= nil)
    -- and each of those four labels must carry the id it actually called with.
    for _, id in ipairs({ "2002", "2001", "3002", "3001" }) do
        assertTrue(text:find("id=" .. id, 1, true) ~= nil,
            "the probe did not call with id " .. id)
    end
end)

test("Diagnostics: a client with no reader is the answer that RE-SCOPES the issue", function()
    -- The fork the whole probe exists to resolve, and the one outcome a reader
    -- of the report must not have to infer from silence.
    -- red under: printing an empty reader list and moving on.
    local inst = T.load{ enable = true }
    deathsSession(inst, { death("Player-1-0000000A", "Me", true, 2001, 100) })
    inst.mocks.setDeathInfo(nil)

    local text = recapReport(inst)
    assertTrue(text:find("no recap reader", 1, true) ~= nil,
        "the probe must name the absence")
    assertTrue(text:find("its own event capture", 1, true) ~= nil,
        "and name what that costs issue #1")
end)

test("Diagnostics: a reader that refuses an id is reported, not swallowed", function()
    -- "Death Recap unavailable" for a past death is the observed behaviour issue
    -- #1 opens with. A refusal per id is the finding; a probe that died on the
    -- first one would print nothing for the three ids after it.
    -- red under: calling the reader outside the provider's pcall.
    local inst = T.load{ enable = true }
    deathsSession(inst, {
        death("Player-1-0000000A", "Me",    true,  2002, 300),
        death("Player-1-0000000B", "Notme", false, 3002, 280),
    })
    inst.mocks.setDeathInfo({
        GetRecapEvent = function(id)
            if id == 2002 then return { spellID = 5, amount = 12 } end
            error("no recap for that id")
        end,
    })

    local text = recapReport(inst)
    assertTrue(text:find("refused", 1, true) ~= nil, "the refusal was swallowed")
    assertTrue(text:find("spellID", 1, true) ~= nil,
        "and the id that DID answer must show what it answered")
end)

test("Diagnostics: the probe survives a client that answers nothing at all", function()
    -- No deaths, no reader, no window pointed anywhere useful. The report must
    -- still run to completion — a diagnostic that dies halfway looks like the
    -- thing it was diagnosing.
    local inst = T.load{ enable = true }
    local ok = pcall(recapReport, inst)
    assertTrue(ok, "the probe raised on an empty client")
end)

test("Diagnostics: a secret id is described rather than called", function()
    -- `deathRecapID` is documented NeverSecret and the probe still may not bet a
    -- raise on it: passing a secret into a client function is the `bad argument
    -- #4` that already shipped once through modules/Targets.lua.
    -- red under: forwarding the id without the safe-key gate.
    local inst = T.load{ enable = true }
    deathsSession(inst, {
        death("Player-1-0000000A", "Me", true, inst.mocks.secret(2002), 300),
    })
    inst.mocks.setSecretsAccessible(false)
    inst.mocks.setDeathInfo({
        GetRecapEvent = function() error("should never have been called") end,
    })

    local text = recapReport(inst)
    assertTrue(text:find("secret", 1, true) ~= nil,
        "a secret id must be described as one")
    assertTrue(text:find("should never have been called", 1, true) == nil,
        "the probe called the client with a secret")
end)

test("Diagnostics: the recap probe also rides along in the full report", function()
    -- A player running `/mm debug diag` after a dungeon hands over the evidence
    -- for free, which is worth more than a tidier report.
    local inst = T.load{ enable = true }
    local text = report(inst)
    assertTrue(text:find("death recap", 1, true) ~= nil, "missing section: death recap")
end)

-- ---------------------------------------------------------------------------
-- The death-recap probe, round two (issue #1)
-- ---------------------------------------------------------------------------
--
-- Round one, on a live 12.x client with nine deaths in the session, found ONE
-- recap-shaped function and it was `C_DeathInfo.GetDeathReleasePosition` — a
-- corpse coordinate. Read literally that re-scopes issue #1 into its own
-- combat-log capture. It is not read literally, because the same client opens
-- Blizzard's recap frame, and because a walk that misses a proxy namespace
-- produces exactly that output on a client that has a reader.
--
-- So the report now has to make the difference VISIBLE: the whole namespace
-- surface unfiltered, and a per-name verdict for the documented readers the walk
-- did not turn up.

test("Diagnostics: the probe prints the whole namespace surface, unfiltered", function()
    -- A healthy namespace with no recap function in it is conclusive; a namespace
    -- with two members in it is a proxy and the walk is at fault. A filtered list
    -- cannot tell those apart, which is the ambiguity round one shipped.
    -- red under: printing only the reader list.
    local inst = T.load{ enable = true }
    inst.mocks.setDeathInfo({
        GetGraveyardsForMap     = function() end,
        GetSelfResurrectOptions = function() end,
    })

    local text = recapReport(inst)
    assertTrue(text:find("GetGraveyardsForMap", 1, true) ~= nil,
        "a member with nothing to do with a recap is exactly what the dump is for")
    assertTrue(text:find("GetSelfResurrectOptions", 1, true) ~= nil)
end)

test("Diagnostics: an absent namespace reads absent, not empty", function()
    -- red under: printing `C_DeathInfo: 0 members` for a client that has none.
    local inst = T.load{ enable = true }
    inst.mocks.setDeathInfo(nil)
    local text = recapReport(inst)
    assertTrue(text:find("C_DeathInfo: not on this client", 1, true) ~= nil)
end)

test("Diagnostics: it says WHICH search found each reader", function()
    -- The single word the fork turns on. `walk` means round one's empty result
    -- was the client speaking; `named` means it was the search.
    -- red under: printing a bare list of names.
    local inst = T.load{ enable = true }
    deathsSession(inst, { death("Player-1-0000000A", "Me", true, 25, 100) })
    local hidden = setmetatable({}, { __index = function(_, key)
        if key == "GetRecapEvent" then return function() return { spellID = 5 } end end
        return nil
    end })
    inst.mocks.setDeathInfo(hidden)

    local text = recapReport(inst)
    assertTrue(text:find("named", 1, true) ~= nil,
        "a reader only a direct index could see must be labelled as such")
    assertTrue(text:find("the walk cannot see", 1, true) ~= nil,
        "and the report must say what that means")
end)

test("Diagnostics: with both searches empty the verdict says so CONCLUSIVELY", function()
    -- Round one's verdict said "no recap reader" off one search. Two searches
    -- agreeing is a different claim and has to read like one, or the next person
    -- re-scopes the issue on the weaker evidence.
    -- red under: keeping the one-search wording.
    local inst = T.load{ enable = true }
    inst.mocks.setDeathInfo({ GetGraveyardsForMap = function() end })

    local text = recapReport(inst)
    assertTrue(text:find("both searches", 1, true) ~= nil,
        "the verdict must rest on the pair, not on the walk alone")
    assertTrue(text:find("its own event capture", 1, true) ~= nil)
end)

test("Diagnostics: a reader that answers NOTHING is not a green light", function()
    -- MEASURED ON A LIVE CLIENT, and the reason this branch exists. Round one
    -- found exactly one recap-shaped function — `GetDeathReleasePosition`, a
    -- corpse coordinate — which returned nil for all four ids, and the verdict
    -- printed the "all four answering is the green light" wording underneath it
    -- because the LIST was non-empty. A verdict must follow what came back, not
    -- what was found.
    -- red under: branching on #apis instead of on the answers.
    local inst = T.load{ enable = true }
    deathsSession(inst, {
        death("Player-1-0000000A", "Me",    true,  25, 100),
        death("Player-1-0000000B", "Notme", false, 26, 90),
    })
    inst.mocks.setDeathInfo({ GetDeathReleasePosition = function() return nil end })

    local text = recapReport(inst)
    assertTrue(text:find("answered for no id", 1, true) ~= nil,
        "the verdict must say the readers came back empty")
    assertTrue(text:find("green light", 1, true) == nil,
        "a client that answered nothing was told it was good to go")
end)

test("Diagnostics: the verdict names WHICH of the four slots answered", function()
    -- The two open questions are slots, not totals. A reader that answers the
    -- local player's newest death and nothing else is Blizzard's frame
    -- behaviour, and the report has to make that visible at a glance rather than
    -- leaving it to be counted out of twenty probe lines.
    -- red under: reporting a bare answered/not-answered count.
    local inst = T.load{ enable = true }
    deathsSession(inst, {
        death("Player-1-0000000A", "Me",    true,  25, 100),
        death("Player-1-0000000A", "Me",    true,  18, 50),
        death("Player-1-0000000B", "Notme", false, 26, 90),
    })
    inst.mocks.setDeathInfo({
        GetRecapEvent = function(id)
            if id == 25 then return { spellID = 5, amount = 12 } end
            return nil
        end,
    })

    local text = recapReport(inst)
    assertTrue(text:find("answered: local/newest", 1, true) ~= nil,
        "the slot that answered must be named")
    assertTrue(text:find("Blizzard's own frame behaviour", 1, true) ~= nil,
        "and local/newest alone is exactly the outcome that sinks the design")
end)

test("Diagnostics: a reader found by name is actually CALLED", function()
    -- Finding it and not calling it would answer the cheap question and leave the
    -- expensive one — does it resolve for a past death, or another player's —
    -- exactly as open as before.
    -- red under: probing only the walk's results.
    local inst = T.load{ enable = true }
    deathsSession(inst, { death("Player-1-0000000A", "Me", true, 25, 100) })
    local called = {}
    local hidden = setmetatable({}, { __index = function(_, key)
        if key ~= "GetRecapEvent" then return nil end
        return function(id) called[#called + 1] = id return { spellID = 5, amount = 12 } end
    end })
    inst.mocks.setDeathInfo(hidden)

    local text = recapReport(inst)
    assertEqual(called[1], 25, "the reader was listed but never called")
    assertTrue(text:find("spellID", 1, true) ~= nil, "and what it answered was not printed")
end)

test("Diagnostics: an ARRAY of events is described as one, with its fields", function()
    -- `GetRecapEvents` hands back an array of event tables, and the whole right
    -- pane of issue #1 is made of their fields. Described by string keys alone —
    -- which is all rounds one and two ever met — an array prints as `table{}`:
    -- the report would find the reader and then say it returned nothing useful.
    -- red under: describing only string-keyed members.
    local inst = T.load{ enable = true }
    deathsSession(inst, { death("Player-1-0000000A", "Me", true, 25, 100) })
    inst.mocks.setDeathRecap({
        GetRecapEvents = function()
            return {
                { spellId = 100, spellName = "Crush", amount = 900, currentHP = 0,
                  timestamp = 1000.5, event = "SPELL_DAMAGE", overkill = 40 },
                { spellId = 101, spellName = "Bite", amount = 400, currentHP = 900,
                  timestamp = 998.4, event = "SPELL_DAMAGE" },
            }
        end,
    })

    local text = recapReport(inst)
    assertTrue(text:find("array[2]", 1, true) ~= nil, "the length was not reported")
    for _, field in ipairs({ "spellId", "spellName", "amount", "currentHP",
                             "timestamp", "event", "overkill" }) do
        assertTrue(text:find(field, 1, true) ~= nil,
            "the event field " .. field .. " never reached the report")
    end
end)

test("Diagnostics: an empty array is not mistaken for an answer", function()
    -- `#raw == 0` is how a working addon detects "this id has no recap", so it
    -- is a real client answer and must not count toward a slot answering.
    -- red under: treating any non-nil return as an answer.
    local inst = T.load{ enable = true }
    deathsSession(inst, { death("Player-1-0000000A", "Me", true, 25, 100) })
    inst.mocks.setDeathRecap({ GetRecapEvents = function() return {} end })

    local text = recapReport(inst)
    assertTrue(text:find("array[0]", 1, true) ~= nil)
    assertTrue(text:find("answered for no id", 1, true) ~= nil,
        "an empty array was counted as a recap")
end)

test("Diagnostics: a slot with no death is not counted as a slot that refused", function()
    -- MEASURED. A run where the local player never died probed only the two
    -- `other/*` slots, both answered in full — and the verdict still printed
    -- "some slots answered and some did not", warning about the local-only
    -- signature that sinks the design. Nothing had refused: two slots had no
    -- death to ask about. A report that cries wolf about its own missing
    -- fixture is worse than one that says less.
    -- red under: comparing the answered count against #RECAP_SLOTS.
    local inst = T.load{ enable = true }
    deathsSession(inst, {
        death("Player-1-0000000B", "Notme", false, 29, 1356),
        death("Player-1-0000000C", "Alsonotme", false, 28, 673),
    })
    inst.mocks.setDeathRecap({
        GetRecapEvents = function() return { { spellId = 5, amount = 12 } } end,
    })

    local text = recapReport(inst)
    assertTrue(text:find("every death this session could offer", 1, true) ~= nil,
        "two of two probed slots answering is a clean result and must read as one")
    assertTrue(text:find("some slots answered and some did not", 1, true) == nil,
        "the report warned about slots that were never asked")
end)

test("Diagnostics: a slot that WAS probed and refused still raises the warning", function()
    -- The belt on the fix above. Narrowing the verdict to probed slots must not
    -- turn off the finding it exists for.
    -- red under: dropping the partial branch entirely.
    local inst = T.load{ enable = true }
    deathsSession(inst, {
        death("Player-1-0000000A", "Me",    true,  25, 100),
        death("Player-1-0000000B", "Notme", false, 29, 90),
    })
    inst.mocks.setDeathRecap({
        GetRecapEvents = function(id)
            if id == 25 then return { { spellId = 5 } } end
            return nil
        end,
    })

    local text = recapReport(inst)
    assertTrue(text:find("some slots answered and some did not", 1, true) ~= nil)
end)

test("Diagnostics: the recap probe reports why a death is dated the way it is", function()
    -- Kept after the feature it was written for was removed. "Time into the
    -- fight" never worked, and this section is what proved it could not: it
    -- prints the INPUTS rather than the conclusion, which is how the third
    -- failed derivation was caught instead of shipped. Anything that later tries
    -- to date a death against its run will need exactly this again.
    -- red under: printing the dates without the inputs that produced them.
    local inst = T.load{ enable = true }
    deathsSession(inst, {
        death("Player-1-0000000A", "Me", true, 29, 1356),
        death("Player-1-0000000B", "Notme", false, 28, -1),
    })
    withRecapsFor(inst)

    local text = recapReport(inst)
    assertTrue(text:find("-- dating --", 1, true) ~= nil, "the section must appear")
    assertTrue(text:find("deathTimeFormat", 1, true) ~= nil,
        "the setting in force has to be printed, not assumed")
    assertTrue(text:find("deathTimeSeconds", 1, true) ~= nil,
        "the field three failed derivations were built on has to be visible")
    -- Both styles, side by side, so a reader can see them agreeing.
    for _, style in ipairs({ "clock", "ago" }) do
        assertTrue(text:find(style, 1, true) ~= nil, "missing style: " .. style)
    end
end)

test("Diagnostics: the dating header prints the format the window is ACTUALLY set to", function()
    -- The section's whole value is that it prints its INPUTS, and the format in
    -- force is the first of them: read "clock" out of a window set to "ago" and
    -- every line below it is being read against the wrong ladder.
    --
    -- It is read off the window's own `text` table, NOT off `data`. The two sit
    -- side by side on a window and `data` is where the session fields live, so a
    -- refactor that folds both lookups into one path is exactly how this line
    -- starts printing nil for a setting the player can see in the panel.
    -- red under: reading cfg.data.deathTimeFormat, or defaulting the format.
    local inst = T.load{ enable = true }
    deathsSession(inst, { death("Player-1-0000000A", "Me", true, 901, 1356) })
    inst.NS.Database.GetWindows()[1].text.deathTimeFormat = "ago"

    local text = recapReport(inst)
    assertTrue(text:find("    window 1: sessionType=1  text.deathTimeFormat=ago", 1, true) ~= nil,
        "the dating header must name the session and the format, both from window 1")
end)

test("Diagnostics: the formatter is resolved as Numbers first, and asked for both styles by name", function()
    -- `NS.Numbers` and `NS.Format` are two names for one table today, which is
    -- what makes the preference invisible until it is pinned: swap the order and
    -- nothing here changes until the day the printer takes `NS.Format` back.
    -- The stub answers only to the first name, so it answering IS the ordering.
    --
    -- It also pins the call itself: the style is the SECOND argument, and both
    -- styles are printed side by side, clock before ago, so a reader can see the
    -- two agreeing on one death.
    -- red under: resolving NS.Format first, or dropping either style.
    local inst = T.load{ enable = true }
    deathsSession(inst, { death("Player-1-0000000A", "Me", true, 901, 1356) })
    withRecapsFor(inst)
    inst.NS.Numbers = { DeathTime = function(_, style) return "NUM:" .. tostring(style) end }

    local text = recapReport(inst)
    assertTrue(text:find("clock=NUM:clock  ago=NUM:ago", 1, true) ~= nil,
        "NS.Numbers must win, and must be called with the style as its second argument")
end)

test("Diagnostics: with NS.Numbers gone the dating falls through to NS.Format", function()
    -- The fallback is not decoration: `NS.Numbers` is an alias modules/Format.lua
    -- publishes, and a diagnostic that goes silent because an alias moved would
    -- be reporting on this addon's naming rather than on the client.
    -- red under: reading only one of the two names.
    local inst = T.load{ enable = true }
    deathsSession(inst, { death("Player-1-0000000A", "Me", true, 901, 1356) })
    withRecapsFor(inst)
    inst.NS.Numbers = nil

    local text = recapReport(inst)
    assertTrue(text:find("clock=%d%d:%d%d:%d%d") ~= nil,
        "NS.Format still dates the death when the alias is gone")
end)

test("Diagnostics: with no formatter at all it says so and dates nothing", function()
    -- The refusal path. Printing a header and then four rows of `nil` would read
    -- as a client that answered nothing, which is a different finding entirely —
    -- so the section names its own missing tool and stops.
    -- red under: dropping the guard, or continuing past it.
    local inst = T.load{ enable = true }
    deathsSession(inst, { death("Player-1-0000000A", "Me", true, 901, 1356) })
    withRecapsFor(inst)
    -- One assignment reaches both names: they are the same table.
    inst.NS.Format.DeathTime = nil

    local text = recapReport(inst)
    assertTrue(text:find("    formatter or provider unavailable", 1, true) ~= nil,
        "the section must name what it is missing")
    assertNil(text:find("row deathTimeSeconds=", 1, true),
        "and print no rows below it")
end)

test("Diagnostics: the dating stops at four deaths", function()
    -- This report is pasted by hand into an issue. A twenty-death wipe would
    -- bury the sections below it, so the section takes the first four and stops
    -- — the same four the probes above it cover.
    -- red under: dating every source, or dating fewer than four.
    local inst = T.load{ enable = true }
    deathsSession(inst, {
        death("Player-1-0000000A", "Me",  true,  901, 111),
        death("Player-1-0000000B", "Bee", false, 902, 222),
        death("Player-1-0000000C", "Cee", false, 903, 333),
        death("Player-1-0000000D", "Dee", false, 904, 444),
        death("Player-1-0000000E", "Eee", false, 905, 555),
        death("Player-1-0000000F", "Eff", false, 906, 666),
    })
    withRecapsFor(inst)

    local text = recapReport(inst)
    assertEqual(select(2, text:gsub("row deathTimeSeconds=", "")), 4,
        "exactly four deaths are dated")
    assertTrue(text:find("row deathTimeSeconds=111", 1, true) ~= nil,
        "and they are the FIRST four, in the order the column reported them")
    assertNil(text:find("row deathTimeSeconds=555", 1, true),
        "the fifth death is not dated")
end)

test("Diagnostics: a secret id costs the row its dating, and still spends one of the four", function()
    -- Two behaviours in one, because they are one line apart and a refactor that
    -- tidies the loop will meet both at once.
    --
    -- A secret `deathRecapID` cannot be dated from AT ALL — it cannot be handed
    -- to the client and it cannot be printed — so the row says that instead of
    -- printing a line of nils that reads like a client refusal.
    --
    -- And the count advances anyway. The cap is on ROWS WALKED, not on rows
    -- successfully dated: mid-pull every id is secret, and a cap that only
    -- counted the successes would walk the whole column looking for a fourth
    -- that cannot exist.
    -- red under: moving the increment inside the else arm.
    local inst = T.load{ enable = true }
    deathsSession(inst, {
        death("Player-1-0000000A", "Me",  true,  inst.mocks.secret(901), 111),
        death("Player-1-0000000B", "Bee", false, inst.mocks.secret(902), 222),
        death("Player-1-0000000C", "Cee", false, inst.mocks.secret(903), 333),
        death("Player-1-0000000D", "Dee", false, inst.mocks.secret(904), 444),
        death("Player-1-0000000E", "Eee", false, 905, 777),
    })
    inst.mocks.setSecretsAccessible(false)

    local text = recapReport(inst)
    assertEqual(select(2, text:gsub("%[id is secret", "")), 4,
        "each secret id is named as one, and four of them fill the cap")
    assertNil(text:find("row deathTimeSeconds=777", 1, true),
        "so the plain fifth death is never reached")
end)

test("Diagnostics: a death the client holds no recap for still gets its row", function()
    -- The absent recap IS a finding — it is the answer to "does an id resolve
    -- for a death from earlier in the run" — and it only reads as one if the row
    -- prints with the gaps named. A row skipped for want of a timestamp looks
    -- like a death the report never saw.
    -- red under: `if recap then` around the printing.
    local inst = T.load{ enable = true }
    deathsSession(inst, { death("Player-1-0000000A", "Me", true, 901, 1356) })
    inst.mocks.setDeathRecap({ HasRecapEvents = function() return false end })

    local text = recapReport(inst)
    assertTrue(text:find("id=901  row deathTimeSeconds=1356  recap timestamp=nil", 1, true) ~= nil,
        "the row still names the id and the field the failed derivations were built on")
    assertTrue(text:find("clock=nil  ago=nil", 1, true) ~= nil,
        "and both styles say nil rather than the row vanishing")
end)

test("Diagnostics: the death is dated off the NEWEST event, which is events[1]", function()
    -- The client hands the recap back newest-first, and dating a death off the
    -- wrong end of that array puts the death at the moment the fight's first
    -- damage landed instead of at the moment it killed them. Nothing in the
    -- output would look wrong; the number would just be minutes out.
    -- red under: events[#events], or the last event seen by a walk.
    local inst = T.load{ enable = true }
    deathsSession(inst, { death("Player-1-0000000A", "Me", true, 901, 1356) })
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function()
            return {
                { spellId = 1, spellName = "Killing blow", amount = 1, timestamp = 1700009999 },
                { spellId = 2, spellName = "First hit",    amount = 1, timestamp = 1700000001 },
            }
        end,
        GetRecapMaxHealth = function() return 1000 end,
    })

    local text = recapReport(inst)
    assertTrue(text:find("recap timestamp=1700009999", 1, true) ~= nil,
        "the first entry in the array is the one the death is dated from")
end)

test("Diagnostics: the header section covers every control, by walking them", function()
    -- IT HAS ALREADY FAILED SILENTLY ONCE HERE. The previous version named three
    -- button fields inside `if button then`, so when the controls moved to
    -- modules/HeaderControls.lua the loop printed nothing at all: no error, just
    -- a report that had quietly stopped covering the header. Walking the
    -- registry is what makes a control added later appear without anyone
    -- remembering to add it.
    -- red under: naming fields instead of walking window.controls.
    local inst = T.load{ enable = true }
    local text = report(inst)
    for _, key in ipairs({ "close", "minimise", "lock", "settings",
                           "segment", "reset", "export" }) do
        assertTrue(text:find(key, 1, true) ~= nil,
            "the header section never mentions " .. key)
    end
end)

test("Diagnostics: a window with no controls says so rather than printing nothing", function()
    -- The failure mode that hid the last one: an empty section reads exactly
    -- like a section with nothing to report.
    local inst = T.load{ enable = true }
    local win = inst.NS.WindowManager.All()[1]
    if win then win.controls = nil end

    local text = report(inst)
    assertTrue(text:find("none built", 1, true) ~= nil,
        "an absent control set printed silence")
end)
