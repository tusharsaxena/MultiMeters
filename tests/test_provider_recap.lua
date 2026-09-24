-- tests/test_provider_recap.lua — modules/Provider.lua's death-recap reads:
-- the three death-recap probe rounds of issue #1, Provider.GetRecap, and the
-- death and segment offset notes.
--
-- Peeled out of tests/test_provider.lua along its section seams, byte for byte;
-- that file keeps the R1a/R1b claims (one caller, no value inspected) and every
-- other provider read. The file-top locals are restated here rather than shared,
-- because a helper handed across suites through a global is a coupling no case
-- would catch.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse
local assertNil   = T.assertNil

-- ---------------------------------------------------------------------------
-- The death-recap probe (issue #1)
-- ---------------------------------------------------------------------------
--
-- Issue #1 wants a two-pane Death Recap window, and it cannot be designed until
-- three things are known about the LIVE CLIENT: whether a `deathRecapID`
-- resolves for a non-local player, whether it resolves for a death from earlier
-- in the run, and whether any reader exists that hands back the per-event
-- breakdown at all. Nothing in this addon reads a recap today — modules/
-- DrillDown.lua only HANDS ONE OFF to Blizzard's frame — so all three are
-- guesses, and the issue says outright that guessing wrong re-scopes the work
-- into its own combat-log capture.
--
-- The two functions below are the client half of the answer. They discover and
-- they call; they never conclude. core/Diagnostics.lua does the describing.

--- A namespace installed on the fake client, with the members a test names.
local function withRecapAPI(members)
    local inst = T.load()
    inst.mocks.setDeathInfo(members)
    return inst
end

test("Provider: with no recap namespace the probe finds nothing, and says so", function()
    -- A CLIENT THAT CARRIES NO READER IS ONE OF THE FOUR ANSWERS, and it is the
    -- one that re-scopes issue #1 entirely. It must arrive as an empty list, not
    -- as a raise and not as a stub that looks like a reader.
    -- red under: indexing the namespace without checking it is there.
    local inst = T.load()
    assertEqual(type(inst.NS.Provider.RecapAPIs), "function")
    assertEqual(#inst.NS.Provider.RecapAPIs(), 0)
end)

test("Provider: it reports the readers the CLIENT has, not a list we wrote", function()
    -- The same principle core/Diagnostics.lua's atlas probe rests on: naming the
    -- functions we expect would report our own opinion back to us, and our own
    -- opinion is exactly what is in doubt here.
    -- red under: a hardcoded candidate list.
    local inst = withRecapAPI({
        GetRecapEvent      = function() end,
        SomethingUnrelated = function() end,
    })

    local found = {}
    for _, api in ipairs(inst.NS.Provider.RecapAPIs()) do found[api.name] = api.ns end

    assertEqual(found.GetRecapEvent, "C_DeathInfo")
    assertNil(found.SomethingUnrelated,
        "a member with nothing to do with a recap was reported as a reader")
end)

test("Provider: a non-function member is not a reader", function()
    -- red under: keeping every recap-shaped key regardless of type.
    local inst = withRecapAPI({ recapLimit = 3, GetRecapEvent = function() end })
    assertEqual(#inst.NS.Provider.RecapAPIs(), 1)
end)

test("Provider: the reader list is in a stable order", function()
    -- The output of this probe is pasted into an issue and compared against
    -- another player's paste. `pairs` order would make two identical clients
    -- produce two different reports.
    -- red under: emitting in pairs order.
    local inst = withRecapAPI({
        GetRecapEvent = function() end, GetDeathRecapLink = function() end,
        HasRecapData  = function() end,
    })

    local names = {}
    for _, api in ipairs(inst.NS.Provider.RecapAPIs()) do names[#names + 1] = api.name end
    assertEqual(table.concat(names, ","), "GetDeathRecapLink,GetRecapEvent,HasRecapData")
end)

test("Provider: a reader that raises comes back as a refusal", function()
    -- THE INTERESTING ANSWER. "This client refuses a past death" is the finding
    -- the whole probe exists for, and a probe that dies on it reports nothing at
    -- all — which reads exactly like a client with no deaths in the session.
    -- red under: calling the reader without pcall.
    local inst = withRecapAPI({
        GetRecapEvent = function() error("no recap for that id") end,
    })

    local ok, err = inst.NS.Provider.CallRecap("C_DeathInfo", "GetRecapEvent", 42, 1)
    assertFalse(ok, "the raise escaped the probe")
    assertTrue(tostring(err):find("no recap", 1, true) ~= nil, "the reason was lost")
end)

test("Provider: a reader that is not there comes back as a refusal too", function()
    -- red under: `_G[ns][name](...)` on an absent namespace.
    local inst = T.load()
    assertFalse((inst.NS.Provider.CallRecap("C_DeathInfo", "GetRecapEvent", 42)))
end)

test("Provider: the value comes back unexamined", function()
    -- Rule R1. An event's amount and its HP figure are meter values, so the
    -- probe may pass one on and may not ask what it is — including not asking
    -- whether it is truthy.
    -- red under: `if value then`, `#value`, or any comparison on the result.
    local inst = withRecapAPI({})
    local payload = inst.mocks.secret(4200)
    inst.mocks.setDeathInfo({ GetRecapEvent = function() return payload end })

    local ok, value = inst.NS.Provider.CallRecap("C_DeathInfo", "GetRecapEvent", 42, 1)
    assertTrue(ok, "reading a secret result raised")
    assertEqual(inst.mocks.reveal(value), 4200, "the value did not survive the probe")
end)

-- ---------------------------------------------------------------------------
-- The death-recap probe, round two: the walk is not trusted (issue #1)
-- ---------------------------------------------------------------------------
--
-- ROUND ONE CAME BACK WITH ONE FUNCTION, and it was the wrong one:
-- `C_DeathInfo.GetDeathReleasePosition`, a corpse coordinate, on a live 12.x
-- client with nine deaths in the session. `GetRecapEvent` and
-- `GetDeathRecapLink` are the documented readers and both match the walk's own
-- name filter, so their absence is either real or the walk cannot see them —
-- some retail `C_*` namespaces are `__index` proxies whose members never appear
-- in `pairs`. One hit where three were expected is exactly the shape a partial
-- enumeration makes, and Blizzard's recap frame demonstrably opens on this
-- client, so SOMETHING reads recaps.
--
-- Concluding "no reader exists" from a walk that may not enumerate would be the
-- third guess. So the walk is now one of two searches, and the dump below is
-- unfiltered so the naming stops being guesswork at all.

test("Provider: the member dump lists EVERY member, not only recap-shaped ones", function()
    -- The filter is what makes round one's result ambiguous. An unfiltered dump
    -- of the whole surface is what ends the ambiguity: a healthy namespace with
    -- no recap function in it is conclusive, and a namespace with two members in
    -- it is a proxy.
    -- red under: reusing isRecapShaped here.
    local inst = withRecapAPI({
        GetRecapEvent        = function() end,
        GetGraveyardsForMap  = function() end,
        GetSelfResurrectOptions = function() end,
    })

    local dump = inst.NS.Provider.RecapMembers()
    local byNS = {}
    for _, entry in ipairs(dump) do byNS[entry.ns] = entry end

    assertTrue(byNS.C_DeathInfo ~= nil, "the namespace was not reported at all")
    assertTrue(byNS.C_DeathInfo.present, "a namespace that is there must read present")
    assertEqual(table.concat(byNS.C_DeathInfo.names, ","),
        "GetGraveyardsForMap,GetRecapEvent,GetSelfResurrectOptions")
end)

test("Provider: an absent namespace is reported absent, not empty", function()
    -- "This client has no C_DeathInfo" and "it has one and it is empty" are
    -- different findings and only one of them is plausible; collapsing them
    -- would hide a load-order problem behind a design conclusion.
    -- red under: returning names = {} with no presence flag.
    local inst = T.load()
    local byNS = {}
    for _, entry in ipairs(inst.NS.Provider.RecapMembers()) do byNS[entry.ns] = entry end
    assertFalse(byNS.C_DeathInfo.present)
end)

test("Provider: a reader behind a PROXY namespace is still found", function()
    -- THE WHOLE REASON FOR ROUND TWO. A namespace that answers through __index
    -- enumerates as empty, so the walk reports no reader on a client that has
    -- one. Asking for the documented names directly is the only search that
    -- survives that.
    -- red under: discovery by pairs alone.
    local inst = T.load()
    local hidden = setmetatable({}, { __index = function(_, key)
        if key == "GetRecapEvent" then return function() return { spellID = 5 } end end
        return nil
    end })
    inst.mocks.setDeathInfo(hidden)

    assertEqual(#inst.NS.Provider.RecapMembers()[1].names, 0,
        "the fixture is only meaningful if the walk really sees nothing")

    local found = {}
    for _, api in ipairs(inst.NS.Provider.RecapAPIs()) do found[api.name] = api.how end
    assertEqual(found.GetRecapEvent, "named",
        "a reader the walk cannot see was lost, which is round one's whole doubt")
end)

test("Provider: a named candidate that is not there is not called a reader", function()
    -- The candidate list is a list of QUESTIONS, not of answers. Reporting every
    -- name we asked about as a reader would make the report say yes to a client
    -- that said no.
    -- red under: emitting the candidate list verbatim.
    local inst = withRecapAPI({ GetRecapEvent = function() end })
    for _, api in ipairs(inst.NS.Provider.RecapAPIs()) do
        assertTrue(api.name ~= "GetDeathRecapLink",
            "a candidate the client lacks was reported as present")
    end
end)

test("Provider: a reader found BOTH ways is reported once", function()
    -- red under: concatenating the two searches without dedup.
    local inst = withRecapAPI({ GetRecapEvent = function() end })
    local seen = 0
    for _, api in ipairs(inst.NS.Provider.RecapAPIs()) do
        if api.ns == "C_DeathInfo" and api.name == "GetRecapEvent" then seen = seen + 1 end
    end
    assertEqual(seen, 1)
end)

test("Provider: the walk still wins the label when it can see the member", function()
    -- `how` is the finding, not decoration: "the walk saw it" and "only a direct
    -- index saw it" are the two answers that decide whether round one's empty
    -- result was the client or the search.
    local inst = withRecapAPI({ GetRecapEvent = function() end })
    for _, api in ipairs(inst.NS.Provider.RecapAPIs()) do
        if api.name == "GetRecapEvent" then assertEqual(api.how, "walk") end
    end
end)

-- ---------------------------------------------------------------------------
-- Round three: the namespace list was the flaw (issue #1)
-- ---------------------------------------------------------------------------
--
-- Rounds one and two both concluded "no recap reader on this client", and both
-- were wrong. The reader is `C_DeathRecap.GetRecapEvents` — a THIRD namespace
-- neither round ever looked at. EllesmereUIDamageMeters calls it on the same
-- client this addon reported empty.
--
-- The instructive part is how the second round missed it. Round one's doubt was
-- "the walk may not enumerate", so round two added a direct-index search — and
-- ran it over the SAME TWO NAMESPACES. Widening the names while leaving the
-- haystack alone re-asked the question that was already answered and left the
-- one that mattered untouched. A search is only as wide as its narrowest axis.

test("Provider: C_DeathRecap is searched — the namespace rounds one and two missed", function()
    -- red under: RECAP_NAMESPACES holding only C_DeathInfo and C_DamageMeter.
    local inst = T.load()
    local seen = {}
    for _, entry in ipairs(inst.NS.Provider.RecapMembers()) do seen[entry.ns] = true end
    assertTrue(seen.C_DeathRecap, "the namespace that actually carries the reader is not searched")
end)

test("Provider: GetRecapEvents is asked for BY NAME as well as walked", function()
    -- The name list is the belt for a proxy namespace, and it is worthless if it
    -- does not carry the name that turned out to matter.
    -- red under: leaving the candidate list at the C_DeathInfo pair.
    local inst = T.load()
    inst.mocks.setDeathRecap(setmetatable({}, { __index = function(_, key)
        if key == "GetRecapEvents" then return function() return { { spellId = 5 } } end end
        return nil
    end }))

    local found = {}
    for _, api in ipairs(inst.NS.Provider.RecapAPIs()) do found[api.name] = api.how end
    assertEqual(found.GetRecapEvents, "named")
end)

test("Provider: GetRecapMaxHealth is searched too", function()
    -- The HP percentage on issue #1's right pane is `currentHP / maxHealth`, and
    -- the max comes from its own call. A probe that found the events and not the
    -- denominator would leave the pane's hardest column unanswered.
    local inst = T.load()
    inst.mocks.setDeathRecap({ GetRecapMaxHealth = function() return 500000 end })
    local found = {}
    for _, api in ipairs(inst.NS.Provider.RecapAPIs()) do found[api.name] = true end
    assertTrue(found.GetRecapMaxHealth)
end)

-- ---------------------------------------------------------------------------
-- Provider.GetRecap — the one reader of a death (issue #1)
-- ---------------------------------------------------------------------------

--- An instance whose client answers a recap for `id`, counting the calls.
local function withRecap(events, maxHealth)
    local inst = T.load()
    local calls = { events = 0, maxHealth = 0 }
    inst.mocks.setDeathRecap({
        HasRecapEvents    = function() return true end,
        GetRecapEvents    = function()
            calls.events = calls.events + 1
            return events
        end,
        GetRecapMaxHealth = function()
            calls.maxHealth = calls.maxHealth + 1
            return maxHealth
        end,
    })
    return inst, calls
end

test("Provider.GetRecap hands back the events and the denominator together", function()
    -- One call site, one answer. The HP percentage needs both halves and getting
    -- them from two places is how they end up describing different deaths.
    local inst = withRecap({ { spellId = 100, amount = 900 } }, 738800)
    local recap = inst.NS.Provider.GetRecap(29)
    assertEqual(type(recap), "table")
    assertEqual(recap.events[1].spellId, 100)
    assertEqual(recap.maxHealth, 738800)
end)

test("Provider.GetRecap is MEMOIZED — a past death never changes", function()
    -- Not an optimization. The drill-down needs one read PER DEATH just to label
    -- its rows with a wall-clock time, and the render path runs four times a
    -- second: without a memo that is forty client calls a second for a list that
    -- cannot change.
    -- red under: dropping the cache.
    local inst, calls = withRecap({ { spellId = 100 } }, 500)
    for _ = 1, 5 do inst.NS.Provider.GetRecap(29) end
    assertEqual(calls.events, 1, "the recap was re-read on every call")
end)

test("Provider.GetRecap memoizes per id, not globally", function()
    -- red under: a single-slot cache that answers every id with the first one.
    local inst = T.load()
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function(id) return { { spellId = id } } end,
    })
    assertEqual(inst.NS.Provider.GetRecap(29).events[1].spellId, 29)
    assertEqual(inst.NS.Provider.GetRecap(28).events[1].spellId, 28)
end)

test("Provider.GetRecap drops its memo when the meter is invalidated", function()
    -- The ids are session-scoped counters — 18..29 in a live dump — so id 29 in
    -- the next run is a DIFFERENT death. A memo that outlived a reset would show
    -- one player the recap of another.
    -- red under: never clearing the cache.
    local inst = T.load()
    local seen = 0
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() return true end,
        GetRecapEvents = function() seen = seen + 1 return { { spellId = seen } } end,
    })
    assertEqual(inst.NS.Provider.GetRecap(29).events[1].spellId, 1)
    inst.NS.Provider.InvalidateRecaps()
    assertEqual(inst.NS.Provider.GetRecap(29).events[1].spellId, 2)
end)

test("Provider.GetRecap answers nil when the death has no recap", function()
    -- A death the client no longer holds still has to draw a row, so "no recap"
    -- must be an answer rather than an error.
    -- red under: returning an empty table, which reads as a recap with no events.
    local inst = T.load()
    inst.mocks.setDeathRecap({ HasRecapEvents = function() return false end })
    assertNil(inst.NS.Provider.GetRecap(29))
end)

test("Provider.GetRecap answers nil for an id it may not use", function()
    -- `deathRecapID` is documented NeverSecret and the reader still does not bet
    -- a raise on it: forwarding a secret into a client function is the `bad
    -- argument #4` that already shipped once through modules/Targets.lua.
    -- red under: passing the id through without the safe-key gate.
    local inst = T.load()
    local touched = false
    inst.mocks.setDeathRecap({
        HasRecapEvents = function() touched = true return true end,
    })
    inst.mocks.setSecretsAccessible(false)
    assertNil(inst.NS.Provider.GetRecap(inst.mocks.secret(29)))
    assertFalse(touched, "a secret id reached the client")
end)

test("Provider.GetRecap never inspects an event", function()
    -- Rule R1, under the simulated secret: the mock traps arithmetic,
    -- comparison, concatenation and indexing, so an inspection raises here
    -- rather than mid-pull in front of a player.
    local inst = T.load()
    inst.mocks.setDeathRecap({
        HasRecapEvents    = function() return true end,
        GetRecapEvents    = function()
            return { inst.mocks.secretTable({ amount = 900, currentHP = 100 }) }
        end,
        GetRecapMaxHealth = function() return inst.mocks.secret(738800) end,
    })
    inst.mocks.setSecretsAccessible(false)
    local recap = inst.NS.Provider.GetRecap(29)
    assertEqual(type(recap), "table")
    assertEqual(inst.mocks.reveal(recap.maxHealth), 738800)
end)

test("Provider.GetRecap is inert while the perf harness has it suspended", function()
    -- performance-§6: a suspended capture must stop the addon ASKING, not merely
    -- stop drawing. Every other read in this file already obeys that.
    -- red under: reading the recap above the suspend gate.
    local inst, calls = withRecap({ { spellId = 100 } }, 500)
    inst.NS.Provider:Suspend()
    assertNil(inst.NS.Provider.GetRecap(29))
    assertEqual(calls.events, 0, "a suspended provider still called the client")
end)

test("Provider.GetRecap answers a PREVIEW recap in test mode", function()
    -- Test mode substitutes the data source and nothing else — that is the whole
    -- reason the mock lives at the one function that talks to the client. A
    -- GetRecap that did not follow suit would leave the preview's death list all
    -- dashes and its tooltips empty, which is exactly the "test mode and normal
    -- mode are two code paths that look alike and behave differently at every
    -- seam nobody duplicated" failure this file's header describes.
    -- red under: no test-mode branch in GetRecap.
    local inst = T.load()
    inst.NS.State.testMode = true
    inst.mocks.setDeathRecap(nil)

    local recap = inst.NS.Provider.GetRecap(113)
    assertEqual(type(recap), "table")
    assertTrue(#recap.events > 1, "a preview death needs more than one event")
    assertTrue(recap.maxHealth > 0)
    assertTrue(recap.events[1].timestamp > recap.events[2].timestamp,
        "newest first, exactly as the client returns them")
    assertTrue(recap.events[1].currentHP < recap.events[2].currentHP,
        "and health falls towards the killing blow")
end)

test("Provider.GetRecap in test mode does not poison the live memo", function()
    local inst = T.load()
    inst.NS.State.testMode = true
    assertEqual(type(inst.NS.Provider.GetRecap(113)), "table")
    inst.NS.State.testMode = false
    inst.mocks.setDeathRecap(nil)
    assertNil(inst.NS.Provider.GetRecap(113), "a preview recap survived into the live path")
end)

-- ---------------------------------------------------------------------------
-- Death offsets — where "time into the fight" actually comes from
-- ---------------------------------------------------------------------------
--
-- `deathTimeSeconds` reads -1 on the OVERALL session, and Overall is what a
-- window shows by default — so a death list dated "time into the fight" fell
-- back to the wall clock for almost everybody, which made the option look
-- broken rather than degraded.
--
-- The Current session carries the real figure for the same deaths, and the
-- recap ids are identical across the two in the same order (measured over three
-- live runs). That was the reasoning behind attempt two. The block below
-- supersedes it: measured on a live client, the Current session held no deaths
-- to join to at all, so nothing reads the field now (core/Diagnostics.lua:677).

-- ---------------------------------------------------------------------------
-- Segment offsets — the anchor the client does not supply
-- ---------------------------------------------------------------------------
--
-- MEASURED, not assumed. On a live client reviewed after the run: the Current
-- session held ZERO deaths and the Overall session held eighteen, every one of
-- them reporting `deathTimeSeconds = -1`. So there is no offset on the client to
-- join to, and the session's own duration is combat time rather than wall time
-- — 32 minutes of it spanning a run whose deaths were three hours back — so it
-- cannot anchor one either. The only clock left is the one this addon keeps.
