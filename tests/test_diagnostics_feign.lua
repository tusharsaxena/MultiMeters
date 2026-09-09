-- tests/test_diagnostics_feign.lua — core/Diagnostics_Feign.lua, the
-- `/mm debug feign` recording.
--
-- Peeled out of tests/test_diagnostics.lua alongside the module, because a probe
-- written for an issue is meant to be deleted with the issue and that only works
-- if its cases can go out with it. Everything issue #25 records — the three
-- boundaries, and the ring that decides what is allowed into them — is here.
--
-- The property the parent suite protects protects this one too: the recording
-- must run to completion on a hostile client, print rather than raise, and never
-- be the reason a player cannot describe what they are seeing.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse
local assertNil   = T.assertNil

-- ---------------------------------------------------------------------------
-- `/mm debug feign` — the issue #25 recording
-- ---------------------------------------------------------------------------
--
-- The Deaths column counts a party member's feign as a death while filtering the
-- local player's correctly, and the count alone cannot say why: either the cast
-- never reached the addon for that unit, or it did and the entry was evicted
-- before the death row was judged. This recording is how the two are told apart
-- on a live client, so what the cases below pin is that it RECORDS the three
-- boundaries and prints them — the readings themselves are the player's to paste.

--- Run the feign report and hand back everything it printed.
local function feignReport(inst)
    local D      = inst.NS.DebugLog
    local buffer = D and D.buffer
    local chatN  = #inst.mocks.__chat
    local bufN   = buffer and #buffer or 0

    inst.NS.Diagnostics.ReportFeign()

    local lines = {}
    if buffer then
        for i = bufN + 1, #buffer do lines[#lines + 1] = buffer[i] end
    end
    for i = chatN + 1, #inst.mocks.__chat do lines[#lines + 1] = inst.mocks.__chat[i] end
    return table.concat(lines, "\n"), lines
end

local FEIGN_SPELL = 5384

--- A two-player group whose second member is a party unit, not the local player.
--- The asymmetry under investigation is exactly "player" versus everybody else,
--- so a fixture with only a player in it could not show it.
local function feignGroup(inst)
    inst.mocks.setGroup({
        { guid = "Player-1-0000000A", name = "Alpha", class = "MAGE",   role = "DAMAGER" },
        { guid = "Player-1-0000000B", name = "Beta",  class = "HUNTER", role = "DAMAGER" },
    })
    return inst
end

test("Diagnostics: the feign report is published and reachable", function()
    local inst = T.load{ enable = true }
    assertEqual(type(inst.NS.Diagnostics.ReportFeign), "function")
    assertEqual(type(inst.NS.Diagnostics.ArmFeignTrace), "function")
    assertEqual(type(inst.NS.Diagnostics.TraceFeign), "function")
end)

test("Diagnostics: the feign trace records nothing until it is armed", function()
    -- red under: a recording that is always on. `judge` fires once per death
    -- source on every Deaths refresh, which is the reason arming exists.
    local inst = feignGroup(T.load{ enable = true })
    assertFalse(inst.NS.Diagnostics.IsFeignTraceArmed())
    inst.NS:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-1", FEIGN_SPELL)
    local text = feignReport(inst)
    assertTrue(text:find("not recording", 1, true) ~= nil,
        "a disarmed trace says how to arm it")
end)

test("Diagnostics: an armed trace records the cast and the unit token it arrived under", function()
    -- THE FIRST OF THE THREE BOUNDARIES, and the one that decides between the
    -- two candidate causes: no `cast` line for a party token means the addon was
    -- never told about the feign at all.
    -- red under: a trace that records the GUID without the token — the token is
    -- the whole difference between the working case and the broken one.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS.Diagnostics.ArmFeignTrace(true)
    inst.NS:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-1", FEIGN_SPELL)

    local text = feignReport(inst)
    assertTrue(text:find("cast", 1, true) ~= nil, "the cast was recorded")
    assertTrue(text:find("unit=party1", 1, true) ~= nil, "the unit token was recorded")
    assertTrue(text:find("kept=true", 1, true) ~= nil, "the GUID was keyed on")
end)

test("Diagnostics: an armed trace records what prune saw and what it decided", function()
    -- THE SECOND BOUNDARY. `hp` and `feigning` are the two raw readings whose
    -- collision is the leading hypothesis: a feign is shown to OTHER clients as
    -- a death, and `hp <= 0` currently evicts ahead of `UnitIsFeignDeath`.
    -- red under: recording the verdict without the readings behind it, which
    -- would say the entry went without saying why.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-1", FEIGN_SPELL)
    inst.NS.Diagnostics.ArmFeignTrace(true)

    inst.mocks.setUnitHealth("party1", 0)
    inst.mocks.setUnitFeignDeath("party1", true)
    inst.NS.Feign.Prune()

    local text = feignReport(inst)
    assertTrue(text:find("prune", 1, true) ~= nil, "the prune pass was recorded")
    assertTrue(text:find("hp=0", 1, true) ~= nil, "the health reading was recorded")
    assertTrue(text:find("feigning=true", 1, true) ~= nil, "the feign reading was recorded")
    assertTrue(text:find("evicted=true", 1, true) ~= nil, "the verdict was recorded")
end)

test("Diagnostics: the entry that simply LEFT THE GROUP says so, instead of going quiet", function()
    -- THE THIRD BOUNDARY, and the one most likely to explain issue #25. Of the
    -- three ways out of the set this is the only one that used to leave no line
    -- at all: the walk found no unit token for the GUID, dropped the entry and
    -- moved on, so a report showing a cast and then nothing could not say whether
    -- the death was judged before the entry went or the entry went first.
    -- red under: an eviction branch with no trace call.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-1", FEIGN_SPELL)
    inst.NS.Diagnostics.ArmFeignTrace(true)

    inst.mocks.setGroup({
        { guid = "Player-1-0000000A", name = "Alpha", class = "MAGE", role = "DAMAGER" },
    })
    inst.NS.Roster.Forget()
    inst.NS.Feign.Prune()

    local text = feignReport(inst)
    assertTrue(text:find("unit=<not in group>", 1, true) ~= nil,
        "the eviction named its own verdict")
    assertTrue(text:find("guid=Player-1-0000000B", 1, true) ~= nil,
        "and named the GUID that left")
end)

test("Diagnostics: an evicted entry still reads noted or down, never <evicted>", function()
    -- The two states are the whole race the set exists to close, and the trace
    -- reported the state AFTER the eviction had cleared it — so every evicted row
    -- read the same and the one thing a reader needed from it was gone. An entry
    -- the client never confirmed ("noted") going at 0 HP is a different finding
    -- from one it did confirm ("down") going at 0 HP: the first says the feign was
    -- never visible, the second says it was visible and the health reading beat it.
    -- red under: reporting `feigned[guid]` after the eviction has nilled it.
    local noted = feignGroup(T.load{ enable = true })
    noted.NS:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-1", FEIGN_SPELL)
    noted.NS.Diagnostics.ArmFeignTrace(true)
    noted.mocks.setUnitHealth("party1", 0)
    noted.NS.Feign.Prune()
    local text = feignReport(noted)
    assertTrue(text:find("state=noted", 1, true) ~= nil,
        "an entry the client never confirmed was evicted as `noted`")

    local down = feignGroup(T.load{ enable = true })
    down.NS:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-1", FEIGN_SPELL)
    down.mocks.setUnitFeignDeath("party1", true)
    down.mocks.setUnitHealth("party1", 500)
    down.NS.Feign.Prune()
    down.NS.Diagnostics.ArmFeignTrace(true)
    down.mocks.setUnitHealth("party1", 0)
    down.NS.Feign.Prune()
    local downText = feignReport(down)
    assertTrue(downText:find("state=down", 1, true) ~= nil,
        "an entry the client had confirmed was evicted as `down`")
end)

test("Diagnostics: arming a trace clears the one before it", function()
    -- A run's evidence is one run's. red under: a buffer that accumulates across
    -- arms, which would put a previous dungeon's casts in this dungeon's report.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS.Diagnostics.ArmFeignTrace(true)
    inst.NS:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-1", FEIGN_SPELL)
    inst.NS.Diagnostics.ArmFeignTrace(true)

    local text = feignReport(inst)
    assertTrue(text:find("nothing recorded", 1, true) ~= nil, "re-arming emptied the log")
end)

test("Diagnostics: an empty armed trace is reported as a FINDING, not as a failure", function()
    -- The single most informative outcome this report has: a run with a hunter
    -- in it and no `cast` line means UNIT_SPELLCAST_SUCCEEDED never arrived.
    -- red under: printing "no data" and leaving the player to assume they did it
    -- wrong, which loses the answer.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS.Diagnostics.ArmFeignTrace(true)
    local text = feignReport(inst)
    assertTrue(text:find("never reached the addon", 1, true) ~= nil,
        "an empty log names what an empty log means")
end)

test("Diagnostics: the feign report prints the group beside the trace", function()
    -- The trace is all GUIDs, because the join is on GUIDs. A reader needs the
    -- non-feigning members too: "party2 reads hp=0" is only evidence if the
    -- others do not. red under: a report that prints the log alone.
    local inst = feignGroup(T.load{ enable = true })
    inst.mocks.setUnitHealth("party1", 0)
    local text = feignReport(inst)
    assertTrue(text:find("group now", 1, true) ~= nil, "the roster is printed")
    assertTrue(text:find("local=", 1, true) ~= nil, "each member says whether it is the player")
end)

test("Diagnostics: the feign report survives a client with none of the unit APIs", function()
    -- The report is what a player runs when something is already wrong, so it
    -- may not be the thing that raises.
    --
    -- ASSERTING "IT DID NOT RAISE" IS NOT ENOUGH HERE, and used to be all this
    -- case did. `Diagnostics.ReportFeign` pcalls its own body and prints
    -- `section failed:` on a catch, so the pcall in this test returns true no
    -- matter what the guards do -- the case could not go red under the very
    -- mutation it names. What proves the guards held is the OUTPUT: the roster
    -- still printed, every member still got a row, each unavailable read was
    -- NAMED as `nil` rather than dropping its field, and the one API that IS
    -- present still answered.
    -- red under: an unguarded _G call, which trips the section pcall and
    -- replaces the whole roster with one `section failed:` line.
    local inst = feignGroup(T.load{ enable = true })
    inst.mocks.UnitIsFeignDeath = nil
    inst.mocks.UnitIsDead = nil

    local ok, text = pcall(function() return (feignReport(inst)) end)
    assertTrue(ok, "the report ran with the unit APIs missing")
    assertNil(text:find("section failed", 1, true),
        "and it ran to the end rather than being caught by its own pcall")

    assertTrue(text:find("group now", 1, true) ~= nil, "the roster still printed")
    assertTrue(text:find("guid=Player-1-0000000A", 1, true) ~= nil,
        "the local player kept a row")
    assertTrue(text:find("guid=Player-1-0000000B", 1, true) ~= nil,
        "and so did the party member -- the walk did not stop at the first miss")
    assertEqual(select(2, text:gsub("dead=nil", "")), 2,
        "both rows named the absent UnitIsDead instead of omitting the field")
    assertEqual(select(2, text:gsub("feigning=nil", "")), 2,
        "and both named the absent UnitIsFeignDeath")
    assertTrue(text:find("hp=", 1, true) ~= nil,
        "UnitHealth is still there and still answered: the guard is per field, not per row")
end)

test("Diagnostics: a secret GUID costs one field and not the line", function()
    -- Every field is described THROUGH `shown` at capture time, so a secret is
    -- never stored and never concatenated later. red under: storing raw values,
    -- which takes the whole line dark the way the header's session line went.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS.Diagnostics.ArmFeignTrace(true)
    inst.NS.Diagnostics.TraceFeign("cast", {
        order = { "unit", "guid", "kept" },
        unit = "party1", guid = inst.mocks.secret("Player-1-0000000B"), kept = false,
    })
    local text = feignReport(inst)
    assertTrue(text:find("unit=party1", 1, true) ~= nil, "the plain field survived")
    assertTrue(text:find("<secret>", 1, true) ~= nil, "the secret field was described")
end)

test("Diagnostics: every roster row carries all six fields, in one fixed order", function()
    -- The join is on GUIDs and the GUID is unreadable, so this row is the only
    -- thing that lets a reader put "party1" to an entry in the trace. Each field
    -- is load-bearing: the token, the GUID it joins on, the three readings
    -- modules/Feign.lua makes, and whether this is the local player — the
    -- asymmetry under investigation in issue #25 is exactly player versus
    -- everybody else.
    --
    -- The health goes through `probe`, which renders a number to ONE DECIMAL. It
    -- looks like a stray format and is not: it is the same describe-do-not-read
    -- path every possibly-secret value in this file takes, and "hp=0.0" beside
    -- "hp=100.0" is the whole shape of the evidence a feign leaves.
    -- red under: reordering the fields, dropping the baseline members, or
    -- reading UnitHealth directly instead of through probe.
    local inst = feignGroup(T.load{ enable = true })
    inst.mocks.setUnitHealth("party1", 0)

    local text = feignReport(inst)
    assertTrue(text:find(
        "    player  guid=Player-1-0000000A  hp=100.0  dead=false  feigning=false  local=true",
        1, true) ~= nil, "the local player's row")
    assertTrue(text:find(
        "    party1  guid=Player-1-0000000B  hp=0.0  dead=false  feigning=false  local=false",
        1, true) ~= nil,
        "and the party member's, so the feigning row has a baseline to be read against")
end)

test("Diagnostics: with no group the roster says so instead of printing a bare header", function()
    -- Both arms of the same guard, because both happen: `/mm debug feign` run
    -- solo has an empty group, and run before the roster module has built has no
    -- roster at all. Either way the report must SAY there is nobody rather than
    -- printing "group now:" and then nothing, which reads as a walk that broke.
    -- red under: dropping either half of the nil-or-empty test.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS.Roster.GetGroup = function() return {} end
    local text = feignReport(inst)
    assertTrue(text:find("    <no group>", 1, true) ~= nil, "an empty group says so")
    assertNil(text:find("  hp=", 1, true), "and prints no member rows")

    local bare = feignGroup(T.load{ enable = true })
    bare.NS.Roster = nil
    local bareText = feignReport(bare)
    assertTrue(bareText:find("    <no group>", 1, true) ~= nil,
        "and so does a report run before there is a Roster to ask")
end)

test("Diagnostics: a unit read that REFUSES is named, and the row survives it", function()
    -- Geometry and unit reads off a restricted client raise rather than return,
    -- and a refusal is itself the finding: "this unit is in the secret set" is
    -- exactly what tells a reader why the filter could not see the feign. The
    -- read is wrapped for that reason and not for tidiness.
    --
    -- `<refused>` is also what an ABSENT UnitHealth reads as, unlike `dead` and
    -- `feigning`, which are guarded and read `nil`. The asymmetry is real and
    -- worth keeping: a refactor that folds the three reads into one uniform
    -- helper changes what this row says on a live client.
    -- red under: an unwrapped UnitHealth call, which trips the section pcall and
    -- replaces the whole roster with one `section failed:` line.
    local inst = feignGroup(T.load{ enable = true })
    inst.mocks.UnitHealth = function() error("this unit is restricted") end

    local text = feignReport(inst)
    assertNil(text:find("section failed", 1, true), "the refusal did not take the report down")
    assertEqual(select(2, text:gsub("hp=<refused>", "")), 2,
        "both rows named the refusal rather than dropping the field")
    assertTrue(text:find("local=true", 1, true) ~= nil,
        "and the fields beside it still printed")
end)

test("Diagnostics: the roster is printed BELOW the entries, on the armed path too", function()
    -- The roster is the key to the trace, so it is printed once the trace has
    -- been read rather than above it — and it is printed on every path, armed or
    -- not, because a reader given entries and no names has GUIDs and nothing to
    -- join them to.
    -- red under: hanging the roster off the disarmed early return alone.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS.Diagnostics.ArmFeignTrace(true)
    inst.NS:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-1", FEIGN_SPELL)

    local text = feignReport(inst)
    local entries = text:find("entries:", 1, true)
    local roster  = text:find("group now:", 1, true)
    assertTrue(entries ~= nil, "the armed trace printed its entries")
    assertTrue(roster ~= nil, "and the roster came with them")
    assertTrue(roster > entries, "the roster reads below the trace it explains")
end)

-- ---------------------------------------------------------------------------
-- The ring, and what is allowed into it
-- ---------------------------------------------------------------------------
--
-- `judge` is the one of the three boundaries that is not rare: it fires once per
-- Deaths source on every refresh, for every death in the column, while `cast`
-- fires once per feign. A ring that admits all three on equal terms therefore
-- fills with judgements on GUIDs nobody ever feigned, and the `cast` line the
-- report exists to show is the first thing pushed out of it. So `judge` is
-- admitted only for a GUID a `cast` line has already named, and the refusals are
-- counted rather than dropped in silence — the count is itself evidence that the
-- Deaths refresh ran at all.

--- Feed the trace one `judge` observation for `guid`.
local function judge(inst, guid, dropped)
    inst.NS.Diagnostics.TraceFeign("judge", {
        order = { "guid", "recap", "dropped" },
        guid = guid, recap = "recap-1", dropped = dropped and true or false,
    })
end

--- Feed the trace one `cast` observation for `guid`.
local function cast(inst, unit, guid)
    inst.NS.Diagnostics.TraceFeign("cast", {
        order = { "unit", "guid", "kept" },
        unit = unit, guid = guid, kept = true,
    })
end

test("Diagnostics: a judge row for a GUID no cast line named is counted, not recorded", function()
    -- red under: a ring that admits every judge row. A death nobody feigned is
    -- judged on every refresh and says nothing about issue #25 — it is the noise
    -- the admission rule exists to keep out.
    -- A GUID DELIBERATELY OUTSIDE THE GROUP. The report prints the live roster
    -- beside the trace, so asserting on a member's GUID would match the roster
    -- line and pass whatever the ring did with it.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS.Diagnostics.ArmFeignTrace(true)
    judge(inst, "Player-1-000000FF", false)

    local text = feignReport(inst)
    assertTrue(text:find("guid=Player-1-000000FF", 1, true) == nil,
        "the unnamed GUID's judgement was not recorded")
    assertTrue(text:find("1 judge", 1, true) ~= nil,
        "the refusal was counted and reported")
end)

test("Diagnostics: a judge row for a GUID a cast line named is recorded", function()
    -- The other side of the same boundary, and the reason the rule is admission
    -- rather than exclusion: a death row reaching `judge` with dropped=false for
    -- a GUID a cast line named IS the finding. red under: refusing every judge
    -- row, which would keep the ring clean and lose the answer with it.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS.Diagnostics.ArmFeignTrace(true)
    cast(inst, "party1", "Player-1-0000000B")
    judge(inst, "Player-1-0000000B", false)

    local text = feignReport(inst)
    assertTrue(text:find("judge", 1, true) ~= nil, "the judgement was recorded")
    assertTrue(text:find("dropped=false", 1, true) ~= nil, "the verdict was recorded")
end)

test("Diagnostics: a cast line survives a full ring of judge rows", function()
    -- THE DEFECT THIS SECTION IS FOR. A twenty-source Deaths column judged on
    -- every refresh reaches the ring's 120 entries in six passes, and under an
    -- oldest-goes ring the single `cast` line — the one entry that says the addon
    -- was told about the feign at all — is the first casualty.
    -- red under: the eviction ring, where 200 judge rows push the cast out.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS.Diagnostics.ArmFeignTrace(true)
    cast(inst, "party1", "Player-1-0000000B")
    for i = 1, 200 do judge(inst, string.format("Player-1-%09d", i), false) end

    local text = feignReport(inst)
    assertTrue(text:find("unit=party1", 1, true) ~= nil, "the cast line survived")
    assertTrue(text:find("guid=Player-1-0000000B", 1, true) ~= nil,
        "the cast line still names its GUID")
    assertTrue(text:find("200 judge", 1, true) ~= nil,
        "every refused row was counted")
end)

test("Diagnostics: the ring keeps its newest entries and reads them oldest first", function()
    -- The ring is a write index into a fixed table rather than a shift, so the
    -- read has to unwrap it. red under: a reader that walks the table from index
    -- 1 after the write index has wrapped, which prints the newest ten entries
    -- ahead of the hundred and ten older ones and reads as a reordered run.
    local inst = feignGroup(T.load{ enable = true })
    inst.NS.Diagnostics.ArmFeignTrace(true)
    for i = 1, 130 do cast(inst, "party1", string.format("G%03d", i)) end

    local text, lines = feignReport(inst)
    assertTrue(text:find("120 entries", 1, true) ~= nil, "the ring is bounded at 120")
    assertTrue(text:find("guid=G001", 1, true) == nil, "the oldest ten were dropped")
    assertTrue(text:find("guid=G130", 1, true) ~= nil, "the newest was kept")

    local first, last
    for i = 1, #lines do
        if lines[i]:find("guid=G", 1, true) then
            first = first or lines[i]
            last = lines[i]
        end
    end
    assertTrue(first ~= nil and first:find("guid=G011", 1, true) ~= nil,
        "the oldest surviving entry is printed first")
    assertTrue(last ~= nil and last:find("guid=G130", 1, true) ~= nil,
        "the newest entry is printed last")
end)
