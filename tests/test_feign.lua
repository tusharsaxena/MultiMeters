-- tests/test_feign.lua — modules/Feign.lua, the one source row this addon
-- deliberately throws away.
--
-- `C_DamageMeter` hands a Feign Death a VALID `deathRecapID`, so the Deaths
-- column counts a hunter's feign as a death and the drill-down would list one.
-- Nothing about that is visible offline: the count is correct arithmetic over
-- rows the client really sent, and the row really is there.
--
-- The filter is deliberately narrow. It joins a GUID recorded from a cast
-- against a GUID on a meter source row, and mid-pull the second of those is
-- secret — so it can only run out of combat, and the tests below pin that
-- limitation as behaviour rather than leave it to be discovered.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse

local FEIGN_DEATH = 5384
local ALPHA = "Player-1-0000000A"
local BETA  = "Player-1-0000000B"

--- A loaded instance with a two-player group whose GUIDs the aggregator uses.
local function loaded()
    local inst = T.load{ enable = true }
    inst.mocks.setGroup({
        { guid = ALPHA, name = "Alpha", class = "HUNTER", role = "DAMAGER" },
        { guid = BETA,  name = "Beta",  class = "PRIEST", role = "HEALER"  },
    })
    return inst
end

--- Fire UNIT_SPELLCAST_SUCCEEDED the way the client does.
local function cast(inst, unit, spellID)
    inst.NS:OnSpellSucceeded("UNIT_SPELLCAST_SUCCEEDED", unit, "cast-1", spellID)
end

test("Feign: the module is published and reachable", function()
    local inst = loaded()
    assertEqual(type(inst.NS.Feign), "table")
    assertEqual(type(inst.NS.Feign.IsFeigned), "function")
end)

test("Feign: a Feign Death cast marks that player", function()
    -- red under: no handler, or one that does not resolve the unit's GUID.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    assertTrue(inst.NS.Feign.IsFeigned(ALPHA))
    assertFalse(inst.NS.Feign.IsFeigned(BETA))
end)

test("Feign: any other cast marks nobody", function()
    -- The handler runs on the busiest event this addon listens to — every cast
    -- by every unit — so the non-matching path must do nothing at all.
    -- red under: recording the caster regardless of the spell.
    local inst = loaded()
    cast(inst, "player", 12345)
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA))
end)

test("Feign: a SECRET spell id is not compared", function()
    -- `spellID == 5384` raises on a secret, and this handler runs on every cast
    -- in a raid. The honest answer when the comparison is refused is to record
    -- nothing, which counts the feign as a death — the behaviour that shipped
    -- before this filter existed, and the safe direction to fail in.
    -- red under: comparing before asking whether comparison is legal.
    local inst = loaded()
    inst.mocks.setSecretsAccessible(false)
    local ok = pcall(cast, inst, "player", inst.mocks.secret(FEIGN_DEATH))
    assertTrue(ok, "a secret spell id raised in the cast handler")
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA))
end)

test("Feign: a SECRET guid is never used as a key", function()
    -- Indexing a table with a secret raises outright. The unit API is not a safe
    -- source — core/Secrets.lua records a follower dungeon handing out secret
    -- pet GUIDs — so both the write and the read are gated.
    -- red under: `set[guid] = true` with no IsSafeKey.
    local inst = loaded()
    local secretGUID = inst.mocks.secret(ALPHA)
    inst.mocks.setUnit("player", { guid = secretGUID, name = "Alpha", class = "HUNTER" })
    inst.mocks.setSecretsAccessible(false)

    local ok = pcall(cast, inst, "player", FEIGN_DEATH)
    assertTrue(ok, "a secret guid raised in the cast handler")
    assertFalse(inst.NS.Feign.IsFeigned(secretGUID),
        "asking about a secret guid must answer no, not raise")
end)

test("Feign: a feigner confirmed at 0 HP stops being feigned", function()
    -- A hunter who feigns and then really dies must have that death counted.
    -- UnitIsFeignDeath is not used for this: it can stay true through the
    -- transition, which would hide the real death behind the fake one.
    -- red under: never clearing, or clearing on any health change.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    assertTrue(inst.NS.Feign.IsFeigned(ALPHA))

    inst.mocks.setUnitHealth("player", 0)
    inst.NS.Feign.Prune()
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA), "the real death after a feign was hidden")
end)

test("Feign: a feigner still down stays feigned", function()
    -- The belt on the case above. A feign keeps the player's real health, so
    -- health alone cannot end one — it takes a confirmed zero (they died) or
    -- UnitIsFeignDeath going false on a living unit (they stood up).
    --
    -- This case used to read "still ALIVE stays feigned", which was true only
    -- while nothing could detect a feign ending; that gap is what let a stale
    -- entry eat every real death a hunter had for the rest of a run.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    inst.mocks.setUnitHealth("player", 1)
    inst.mocks.setUnitFeignDeath("player", true)
    inst.NS.Feign.Prune()
    assertTrue(inst.NS.Feign.IsFeigned(ALPHA))
end)

test("Feign: somebody who left the group is forgotten", function()
    -- Untrackable: there is no unit token to read health from any more, so the
    -- entry could never be cleared and would sit there for the session.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    inst.mocks.setGroup({ { guid = BETA, name = "Beta", class = "PRIEST" } })
    inst.NS.Roster.Forget()
    inst.NS.Feign.Prune()
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA))
end)

test("Feign: a meter reset forgets everything", function()
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    inst.NS:SendMessage(inst.NS.Constants.MSG.METER_RESET)
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA))
end)

test("Feign: pruning an empty set costs nothing", function()
    -- It is called once per refresh pass from the Deaths walk, four times a
    -- second, on a run where nobody has ever feigned.
    -- red under: enumerating the group before checking the set is empty.
    local inst = loaded()
    inst.mocks.setGroup(nil)
    local ok = pcall(inst.NS.Feign.Prune)
    assertTrue(ok)
end)

-- ---------------------------------------------------------------------------
-- A feign is a fact about ONE DEATH, not a flag on a player (found by review)
-- ---------------------------------------------------------------------------
--
-- The set began life as a live predicate — "is this GUID feigning right now" —
-- asked of a HISTORICAL list of source rows, and that is wrong in both
-- directions. Clear the entry and every death it was hiding comes back; leave it
-- standing and every real death the player has is eaten. The fix is to mark the
-- individual deaths, and to notice when a feign has ended.

test("Feign: a death judged fake STAYS fake after the player really dies", function()
    -- red under: filtering on the live set alone. The hunter feigns twice, is
    -- correctly filtered, then really dies — and the two feigns reappear in the
    -- count and never leave.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    assertTrue(inst.NS.Feign.ShouldDropDeath(ALPHA, 11))
    assertTrue(inst.NS.Feign.ShouldDropDeath(ALPHA, 10))

    -- They really die: the entry clears.
    inst.mocks.setUnitHealth("player", 0)
    inst.NS.Feign.Prune()
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA))

    assertTrue(inst.NS.Feign.ShouldDropDeath(ALPHA, 11), "an earlier feign came back")
    assertTrue(inst.NS.Feign.ShouldDropDeath(ALPHA, 10), "an earlier feign came back")
    assertFalse(inst.NS.Feign.ShouldDropDeath(ALPHA, 20), "the real death was eaten")
end)

test("Feign: standing back up ends the feign, so the next death is real", function()
    -- THE OTHER DIRECTION, and the one that loses data. Nothing cleared a feign
    -- when the feign simply ENDED, so a hunter who feigned in pull one and died
    -- for real in pull three had that death filtered out for the rest of the
    -- run — unless some pass happened to catch them at exactly 0 HP.
    --
    -- UnitIsFeignDeath is safe to read in THIS direction: it can linger true
    -- through a feign-then-die transition, which is why it cannot be trusted to
    -- clear one, but a FALSE reading on a living unit means they are up.
    -- red under: Prune having only the 0-HP and left-the-group exits.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    inst.mocks.setUnitFeignDeath("player", true)
    inst.NS.Feign.Prune()
    assertTrue(inst.NS.Feign.IsFeigned(ALPHA), "still down, still feigning")

    inst.mocks.setUnitFeignDeath("player", false)
    inst.mocks.setUnitHealth("player", 500)
    inst.NS.Feign.Prune()
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA), "they stood up; the feign is over")
    assertFalse(inst.NS.Feign.ShouldDropDeath(ALPHA, 20),
        "a death after standing up is a real one")
end)

test("Feign: a client with no UnitIsFeignDeath keeps the old behaviour", function()
    -- The API is read through _G at call time and may be absent. Missing must
    -- mean "cannot tell", which leaves the entry standing — the pre-existing
    -- behaviour, not a silent clear that would let feigns through.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    inst.mocks.setUnitFeignDeath("player", true)
    inst.mocks.setUnitHealth("player", 500)
    inst.NS.Feign.Prune()

    inst.mocks.UnitIsFeignDeath = nil
    inst.NS.Feign.Prune()
    assertTrue(inst.NS.Feign.IsFeigned(ALPHA))
end)

test("Feign: a reset forgets the fake deaths too", function()
    -- Recap ids are session-scoped counters, so id 11 after a reset is somebody
    -- else's death entirely. A surviving mark would hide a real one.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    assertTrue(inst.NS.Feign.ShouldDropDeath(ALPHA, 11))
    inst.NS:SendMessage(inst.NS.Constants.MSG.METER_RESET)
    assertFalse(inst.NS.Feign.ShouldDropDeath(ALPHA, 11))
end)

test("Feign: ShouldDropDeath answers no for anything it cannot key on", function()
    -- A secret recap id, an absent one, a secret guid. "Cannot tell" must mean
    -- "not a feign", because the alternative is dropping a real death.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    inst.mocks.setSecretsAccessible(false)
    assertFalse(inst.NS.Feign.ShouldDropDeath(inst.mocks.secret(ALPHA), 11))
    assertTrue(inst.NS.Feign.ShouldDropDeath(ALPHA, inst.mocks.secret(11)) ~= nil,
        "a secret id must answer, not raise")
end)

-- ---------------------------------------------------------------------------
-- Feign.Prune, arm by arm (issue #37)
-- ---------------------------------------------------------------------------
--
-- Prune is CCN 25 and issue #37 will split it along the `if unit == nil` fork
-- into an absent-member verdict and a present-member one. Everything below this
-- line exists so that split can be proved to have changed nothing: each arm of
-- the walk reached and its distinct outcome asserted, the three orderings the
-- function's own comments call load-bearing, and the exact shape of the issue
-- #25 trace lines — which are the only output this function has.

local assertNil = T.assertNil

--- Record what modules/Feign.lua hands the recording, without the ring in the
--- way. Armed through the real `ArmFeignTrace` on purpose: the call sites read
--- `Diagnostics.feignArmed` directly (performance-§2), so a test that set the
--- flag by hand would not be pinning the field they actually read.
local function captureTrace(inst)
    local seen = {}
    inst.NS.Diagnostics.ArmFeignTrace(true)
    inst.NS.Diagnostics.TraceFeign = function(kind, fields)
        seen[#seen + 1] = { kind = kind, fields = fields }
    end
    return seen
end

--- The one captured line of `kind` naming `guid`, or nil.
local function lineFor(seen, kind, guid)
    for i = 1, #seen do
        if seen[i].kind == kind and seen[i].fields.guid == guid then return seen[i].fields end
    end
    return nil
end

--- The prune line's field order, spelled out so a refactor that rebuilds the
--- table cannot quietly reorder or drop a field. `order` is what
--- core/Diagnostics.lua walks to render the line, so it IS the output format.
local function assertPruneOrder(fields)
    local want = { "unit", "guid", "hp", "feigning", "state", "evicted" }
    assertEqual(type(fields.order), "table", "the prune line carried no order")
    assertEqual(#fields.order, #want, "the prune line's field count changed")
    for i = 1, #want do
        assertEqual(fields.order[i], want[i], "prune field " .. i .. " changed")
    end
end

--- A Roster stub answering `group`, counting the asks. Prune resolves
--- `NS.Roster` at call time, which is what makes this substitution honest.
local function stubRoster(inst, group)
    local calls = { n = 0 }
    inst.NS.Roster = { GetGroup = function() calls.n = calls.n + 1; return group end }
    return calls
end

test("Feign: a confirmed 0 HP evicts even while the client still reads feigning", function()
    -- THE LINE ISSUE #25 TURNS ON: `dead` wins outright, ahead of `nowFeigning`.
    -- UnitIsFeignDeath lingers true through a feign-then-die transition, so an
    -- eviction that deferred to it would hide the real death behind the fake one
    -- — and the hunter's genuine death would never reach the Deaths column.
    -- red under: `if nowFeigning then keep end` ordered ahead of the 0-HP exit.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    inst.mocks.setUnitFeignDeath("player", true)
    inst.mocks.setUnitHealth("player", 0)
    inst.NS.Feign.Prune()
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA),
        "a still-feigning reading outranked the confirmed death")
end)

test("Feign: an entry the client never confirmed is not evicted by a false reading", function()
    -- THE RACE THE TWO STATES EXIST TO CLOSE. `UnitIsFeignDeath` reads false in
    -- the instant between the cast succeeding and the aura becoming visible, so
    -- an entry that has never been SEEN down must not take the "stood back up"
    -- exit — clearing on that first reading would undo every entry immediately,
    -- every time, and the filter would never drop anything.
    -- red under: `evicted = dead or (alive and nowFeigning == false)`, with the
    -- seenDown half of the condition dropped as redundant.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    inst.mocks.setUnitHealth("player", 500)
    inst.mocks.setUnitFeignDeath("player", false)
    inst.NS.Feign.Prune()
    assertTrue(inst.NS.Feign.IsFeigned(ALPHA),
        "the entry went on the reading taken before the aura was visible")

    -- And once the client HAS confirmed it, the same reading evicts. Both halves
    -- in one case because it is the transition between them that is the rule.
    inst.mocks.setUnitFeignDeath("player", true)
    inst.NS.Feign.Prune()
    inst.mocks.setUnitFeignDeath("player", false)
    inst.NS.Feign.Prune()
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA), "a confirmed feigner never stood up")
end)

test("Feign: a health figure that cannot be compared leaves the entry standing", function()
    -- Nil-ness first, then CanCompare, and only then the comparison. A health
    -- figure is not a meter value, but nothing says the client cannot make one
    -- secret, and `hp > 0` on a secret raises. Refused comparison must read as
    -- neither alive nor dead, which leaves the entry exactly where it is.
    -- red under: comparing before asking whether comparison is legal.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    inst.mocks.setUnitHealth("player", inst.mocks.secret(0))
    inst.mocks.setSecretsAccessible(false)
    local ok = pcall(inst.NS.Feign.Prune)
    assertTrue(ok, "an unreadable health figure raised in the prune walk")
    assertTrue(inst.NS.Feign.IsFeigned(ALPHA),
        "an unreadable figure was read as a confirmed death")
end)

test("Feign: an evicted entry is traced with the state it HELD", function()
    -- `M2-11`. The trace used to report `feigned[guid]`, which the eviction three
    -- lines above had already nilled, so every evicted row read `<evicted>` and
    -- the two states collapsed into one. They are the race this set exists to
    -- close: an entry going at 0 HP from "noted" (the cast arrived, the client
    -- never confirmed) and one going at 0 HP from "down" are different findings.
    -- red under: reading the state after the eviction — the shape a refactor
    -- that moves the eviction into a helper falls into first.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    cast(inst, "party1", FEIGN_DEATH)
    local seen = captureTrace(inst)

    -- Alpha was never confirmed feigning; Beta is confirmed in this very pass.
    inst.mocks.setUnitHealth("player", 0)
    inst.mocks.setUnitHealth("party1", 0)
    inst.mocks.setUnitFeignDeath("party1", true)
    inst.NS.Feign.Prune()

    local a = lineFor(seen, "prune", ALPHA)
    local b = lineFor(seen, "prune", BETA)
    assertTrue(a ~= nil, "the evicted local player left no prune line")
    assertTrue(b ~= nil, "the evicted party member left no prune line")
    assertEqual(a.state, "noted", "an unconfirmed eviction lost its state")
    assertEqual(b.state, "down", "a confirmed eviction lost its state")
    assertEqual(a.evicted, true)
    assertEqual(b.evicted, true)
    assertPruneOrder(a)
end)

test("Feign: a surviving entry is traced with evicted=false and its raw readings", function()
    -- The verdict is recorded beside the readings it was drawn from, which is
    -- what makes the report evidence rather than an opinion — issue #25 is
    -- exactly the question of what another client is SHOWN for a feigner.
    -- `evicted` is normalised to a boolean, never left nil: a missing field and
    -- a false one render differently, and a reader cannot tell the difference
    -- between "not evicted" and "the field was dropped".
    -- red under: `evicted = evicted` with the `and true or false` lost.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    cast(inst, "party1", FEIGN_DEATH)
    local seen = captureTrace(inst)

    inst.mocks.setUnitHealth("player", 500)
    inst.mocks.setUnitFeignDeath("player", true)
    inst.mocks.setUnitHealth("party1", 700)
    inst.mocks.setUnitFeignDeath("party1", false)
    inst.NS.Feign.Prune()

    local a = lineFor(seen, "prune", ALPHA)
    local b = lineFor(seen, "prune", BETA)
    assertTrue(a ~= nil and b ~= nil, "a surviving member left no prune line")
    assertEqual(a.unit, "player")
    assertEqual(a.hp, 500)
    assertEqual(a.feigning, true)
    assertEqual(a.state, "down", "the confirmed reading was recorded before the trace")
    assertEqual(a.evicted, false, "a survivor must report false, not nil")
    -- Beta was never confirmed, so the false reading does not evict and the
    -- state it is traced with is still the one the cast created.
    assertEqual(b.state, "noted")
    assertEqual(b.evicted, false)
    assertPruneOrder(b)
end)

test("Feign: leaving the group is traced as <not in group>", function()
    -- THE EXIT THAT USED TO LEAVE NO LINE. A recording that showed a cast and
    -- then silence could not say whether the death was judged before the entry
    -- went or the entry went first — which is the fork issue #25 turns on. The
    -- absence IS the verdict, so it is spelled in the unit field, and hp and
    -- feigning stay nil because there was no token left to read them from.
    -- red under: an absent-member arm that drops the entry and returns.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    local seen = captureTrace(inst)

    inst.mocks.setGroup({ { guid = BETA, name = "Beta", class = "PRIEST" } })
    inst.NS.Roster.Forget()
    inst.NS.Feign.Prune()

    local a = lineFor(seen, "prune", ALPHA)
    assertTrue(a ~= nil, "the member who left the group left no prune line")
    assertEqual(a.unit, "<not in group>")
    assertEqual(a.state, "noted", "the state the entry held was lost")
    assertEqual(a.evicted, true)
    assertNil(a.hp, "an untrackable member cannot have a health reading")
    assertNil(a.feigning, "an untrackable member cannot have a feign reading")
    assertPruneOrder(a)
end)

test("Feign: the armed flag is read once per prune, not once per member", function()
    -- Hoisted deliberately: nothing between the read and the end of the walk can
    -- arm or disarm a recording, so this is one field read per prune rather than
    -- one per group member on a path that runs four times a second.
    -- red under: a per-member helper that asks `armed()` for itself, which is
    -- the shape issue #37's `judgeMember` split invites.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    cast(inst, "party1", FEIGN_DEATH)

    local real = inst.NS.Diagnostics
    real.ArmFeignTrace(true)
    local reads = 0
    inst.NS.Diagnostics = setmetatable({}, { __index = function(_, k)
        if k == "feignArmed" then reads = reads + 1 end
        return real[k]
    end })

    inst.NS.Feign.Prune()
    assertEqual(reads, 1, "the armed flag was read per member instead of per prune")
end)

test("Feign: a disarmed prune hands the recording nothing at all", function()
    -- What "off" costs is decided at the call sites, not inside TraceFeign: a
    -- Lua call evaluates its arguments first, so a site that builds its fields
    -- table AT the call has already paid for a recording nobody asked for.
    -- red under: `trace(...)` called unguarded and left to decline for itself.
    local inst = loaded()
    local calls = 0
    inst.NS.Diagnostics.TraceFeign = function() calls = calls + 1 end

    cast(inst, "player", FEIGN_DEATH)
    inst.mocks.setUnitHealth("player", 0)
    inst.NS.Feign.Prune()
    assertEqual(calls, 0, "a disarmed pass still built and handed over a fields table")
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA), "and the eviction itself still happened")
end)

test("Feign: an absent Diagnostics file is not an error", function()
    -- core/Diagnostics.lua is resolved through NS at call time and is allowed to
    -- be absent — this module does not depend on the diagnostic existing. An
    -- absent file answers "not armed" rather than raising.
    -- red under: `NS.Diagnostics.feignArmed` read without the nil test.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    inst.NS.Diagnostics = nil
    inst.mocks.setUnitHealth("player", 0)
    local ok = pcall(inst.NS.Feign.Prune)
    assertTrue(ok, "prune raised with the diagnostics file absent")
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA), "and the walk still reached the eviction")
end)

test("Feign: a group entry with no token or a secret guid counts as absent", function()
    -- The present map is built under two guards, and both are load-bearing: a
    -- secret GUID cannot be a table key at all (the assignment raises before it
    -- stores anything, and core/Secrets.lua records a follower dungeon handing
    -- out secret pet GUIDs), and an entry with no unit token has nothing to read
    -- health from — which is the same untrackable state as leaving the group.
    -- red under: `present[entry.guid] = entry.unit` with either guard dropped.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    cast(inst, "party1", FEIGN_DEATH)
    stubRoster(inst, {
        { guid = ALPHA },                                              -- no token
        { guid = inst.mocks.secret("Player-1-0000000C"), unit = "party2" },
        { guid = BETA, unit = "party1" },
    })

    local ok = pcall(inst.NS.Feign.Prune)
    assertTrue(ok, "a secret guid in the group raised while the map was built")
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA),
        "an entry with no unit token stayed in the set and could never be cleared")
    assertTrue(inst.NS.Feign.IsFeigned(BETA), "the trackable member was evicted with it")
end)

test("Feign: with no Roster at all every entry is evicted", function()
    -- Roster is resolved through NS at call time and may be absent on a degraded
    -- load. No group means no unit token for anybody, and an entry that can
    -- never be read again must not sit in the set for the rest of the session.
    -- red under: `Roster.GetGroup()` called without the nil guards.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    cast(inst, "party1", FEIGN_DEATH)
    inst.NS.Roster = nil
    local ok = pcall(inst.NS.Feign.Prune)
    assertTrue(ok, "prune raised with the roster module absent")
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA))
    assertFalse(inst.NS.Feign.IsFeigned(BETA))
end)

test("Feign: the set stops being walked once the last entry goes", function()
    -- `remaining` is the accumulator the whole walk feeds, and `anyFeigned` is
    -- what the refresh path tests before it touches the roster at all. Set it
    -- from a partial answer and either the walk stops while somebody is still
    -- feigning, or it keeps enumerating the group four times a second on a run
    -- where nobody is.
    -- red under: `anyFeigned = false` written inside the eviction arm, or
    -- `remaining` set true before the verdict.
    local inst = loaded()
    cast(inst, "player", FEIGN_DEATH)
    cast(inst, "party1", FEIGN_DEATH)
    local calls = stubRoster(inst, {
        { guid = ALPHA, unit = "player" },
        { guid = BETA,  unit = "party1" },
    })

    inst.mocks.setUnitHealth("player", 0)
    inst.NS.Feign.Prune()
    assertEqual(calls.n, 1)
    assertFalse(inst.NS.Feign.IsFeigned(ALPHA))
    assertTrue(inst.NS.Feign.IsFeigned(BETA))

    -- One survivor is enough to keep the walk alive.
    inst.NS.Feign.Prune()
    assertEqual(calls.n, 2, "the walk stopped while somebody was still feigning")

    -- And when the last one goes, it stops asking the roster anything.
    inst.mocks.setUnitHealth("party1", 0)
    inst.NS.Feign.Prune()
    assertEqual(calls.n, 3)
    inst.NS.Feign.Prune()
    assertEqual(calls.n, 3, "an empty set still enumerated the group")
end)
