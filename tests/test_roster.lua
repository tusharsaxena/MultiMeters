-- tests/test_roster.lua — modules/Roster.lua: who is in the group, and whose
-- pet that is.
--
-- Nothing in this module touches a meter value, which is exactly why it matters:
-- it is the source of every fact the grid can still be sure of mid-pull. The
-- cases below therefore care about two things — that the map is built from the
-- unit API in the right ORDER, and that pet attribution is honest about what it
-- cannot know.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse
local assertNil   = T.assertNil

local PARTY = {
    { guid = "Player-1-0000000A", name = "Tankadin", class = "PALADIN", role = "TANK"    },
    { guid = "Player-1-0000000B", name = "Healbot",  class = "PRIEST",  role = "HEALER"  },
    { guid = "Player-1-0000000C", name = "Stabby",   class = "ROGUE",   role = "DAMAGER" },
}

--- A fresh instance whose group is `spec`. The roster cache is cold, so the
--- first read of every case builds it.
local function grouped(spec, opts)
    local inst = T.load()
    inst.mocks.setGroup(spec, opts)
    inst.NS.Roster.Refresh()
    return inst
end

-- ---------------------------------------------------------------------------
-- The group array
-- ---------------------------------------------------------------------------

test("Roster.GetGroup is player-first, then party order", function()
    local inst = grouped(PARTY)
    local group = inst.NS.Roster.GetGroup()

    assertEqual(#group, 3)
    -- Player-first is not cosmetic: `roster` sort mode uses this order verbatim,
    -- and a player wants to find themselves at a fixed place in the list.
    assertEqual(group[1].unit, "player")
    assertEqual(group[1].isPlayer, true)
    assertEqual(group[1].guid, "Player-1-0000000A")
    assertEqual(group[2].unit, "party1")
    assertEqual(group[2].isPlayer, false)
    assertEqual(group[3].unit, "party2")
end)

test("Roster.GetGroup carries name, class and role off the unit API", function()
    local entry = grouped(PARTY).NS.Roster.GetGroup()[2]
    assertEqual(entry.name, "Healbot")
    assertEqual(entry.classFilename, "PRIEST")
    assertEqual(entry.role, "HEALER")
end)

test("Roster de-duplicates the player, who is both `player` and `raidN`", function()
    local inst = grouped(PARTY, { raid = true })
    local group = inst.NS.Roster.GetGroup()

    -- In a raid the walk visits "player" and then raid1..N, and raid1 IS the
    -- player. The duplicate is filtered by GUID rather than by working out which
    -- raid index we are, which changes on every regroup.
    assertEqual(#group, 3, "the player must appear exactly once")
    assertEqual(group[1].unit, "player", "and the `player` entry is the one that wins")
    local seen = {}
    for _, member in ipairs(group) do
        assertNil(seen[member.guid], "duplicate GUID " .. tostring(member.guid))
        seen[member.guid] = true
    end
end)

test("Roster answers a one-entry group when solo", function()
    local inst = T.load()
    inst.mocks.setSolo("Player-1-00000001", "Loner", "MAGE")
    inst.NS.Roster.Refresh()

    -- Solo still yields { player } rather than {}, so every consumer has a
    -- one-entry roster instead of an empty-case branch.
    local group = inst.NS.Roster.GetGroup()
    assertEqual(#group, 1)
    assertEqual(group[1].name, "Loner")
    assertEqual(group[1].isPlayer, true)
end)

test("Roster skips a unit the API cannot see", function()
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    -- party2 exists as far as GetNumGroupMembers is concerned but the unit is
    -- out of range: UnitExists answers false and the member is left out rather
    -- than entered with a nil GUID.
    inst.mocks.setUnit("party2", nil)
    inst.NS.Roster.Refresh()

    local group = inst.NS.Roster.GetGroup()
    assertEqual(#group, 2)
    assertEqual(inst.NS.Roster.IsGroupMember("Player-1-0000000C"), false)
end)

-- ---------------------------------------------------------------------------
-- Lookups
-- ---------------------------------------------------------------------------

test("Roster.IsGroupMember is a plain GUID lookup, legal at any point in a pull", function()
    local inst = grouped(PARTY)
    inst.mocks.setRestricted(true)

    local R = inst.NS.Roster
    assertEqual(R.IsGroupMember("Player-1-0000000B"), true)
    assertEqual(R.IsGroupMember("Creature-0-1234"), false)
    assertEqual(R.IsGroupMember(nil), false, "nil is not a member and is not an error")
end)

test("Roster.Get answers the entry, and nil for a stranger", function()
    local R = grouped(PARTY).NS.Roster
    assertEqual(R.Get("Player-1-0000000C").name, "Stabby")
    assertNil(R.Get("Player-1-0000FFFF"))
    assertNil(R.Get(nil))
end)

test("Roster.RoleOf answers NONE rather than nil for a non-member", function()
    local R = grouped(PARTY).NS.Roster
    assertEqual(R.RoleOf("Player-1-0000000A"), "TANK")
    -- A row icon has one code path; a caller that needs "not in the group" asks
    -- IsGroupMember, which is the question it actually means.
    assertEqual(R.RoleOf("Creature-0-999"), "NONE")
end)

test("Roster normalizes an unrecognized role to NONE", function()
    local inst = T.load()
    inst.mocks.setGroup{ { guid = "Player-1-00000001", name = "Nobody",
                           class = "MAGE", role = "SOMETHINGNEW" } }
    inst.NS.Roster.Refresh()
    assertEqual(inst.NS.Roster.GetGroup()[1].role, "NONE")
end)

-- ---------------------------------------------------------------------------
-- Pet attribution — best effort, and it says so
-- ---------------------------------------------------------------------------

test("Roster.OwnerOf maps a unit-frame pet to its owner", function()
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    inst.mocks.setPet("player", "Pet-0-1111")
    inst.mocks.setPet("party2", "Pet-0-3333")
    inst.NS.Roster.Refresh()

    local R = inst.NS.Roster
    assertEqual(R.OwnerOf("Pet-0-1111"), "Player-1-0000000A")
    assertEqual(R.OwnerOf("Pet-0-3333"), "Player-1-0000000C",
        "the pet token is derived from the owner's unit token, so it cannot mismatch")
end)

test("Roster.OwnerOf answers nil for anything that is not a unit-frame pet", function()
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    inst.mocks.setPet("player", "Pet-0-1111")
    inst.NS.Roster.Refresh()

    -- Guardians, totems, temporary summons, a second pet, and a pet belonging to
    -- a member out of range all land here. nil means "this addon cannot prove
    -- whose this is", and the aggregator's contract is to DROP the row.
    assertNil(inst.NS.Roster.OwnerOf("Creature-0-2222"))
    assertNil(inst.NS.Roster.OwnerOf(nil))
end)

test("Roster never keys the map on a secret GUID", function()
    -- FROM A LIVE FOLLOWER DUNGEON: UnitGUID("party3pet") answered a SECRET
    -- string, and `pets[petGuid] = guid` raised "attempted to perform indexed
    -- assignment on a table that cannot be indexed with secret keys" on every
    -- refresh. The addon's design note said a GUID is never secret; it is not
    -- true of the unit API, only of the meter's own sourceGUID.
    --
    -- The harness cannot trap a secret used as a key (tests/wow_mock.lua says so
    -- outright — it is legal Lua), so the assertion is on the map itself: no key
    -- in it may be a secret. That is the invariant the client enforces for us.
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    inst.mocks.setPet("party1", "Pet-0-2222")
    local secretPet = inst.mocks.secret("Pet-0-SECRET")
    inst.mocks.setPet("party2", secretPet)
    inst.NS.Roster.Refresh()

    local R = inst.NS.Roster
    assertEqual(#R.GetGroup(), 3, "an unreadable pet must not cost us its owner")

    for key in pairs(inst.NS.State.Cache("Roster").pets) do
        assertFalse(inst.mocks.isSimulatedSecret(key),
            "a secret GUID reached the pet map as a KEY")
    end
    for key in pairs(inst.NS.State.Cache("Roster").byGuid) do
        assertFalse(inst.mocks.isSimulatedSecret(key),
            "a secret GUID reached the member index as a KEY")
    end

    assertEqual(R.OwnerOf("Pet-0-2222"), "Player-1-0000000B",
        "the readable pet is still attributed")
    assertNil(R.OwnerOf(secretPet),
        "and an unreadable one is unattributable, which the aggregator drops")
    assertFalse(R.IsGroupMember(secretPet), "lookups refuse a secret rather than raising")
    assertNil(R.Get(secretPet))
end)

test("Roster does not attribute a pet to a member it skipped", function()
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    inst.mocks.setPet("party1", "Pet-0-2222")
    inst.mocks.setUnit("party1", nil)   -- the owner went out of range
    inst.NS.Roster.Refresh()

    assertNil(inst.NS.Roster.OwnerOf("Pet-0-2222"),
        "a pet whose owner was not enumerated is unattributable, not misattributed")
end)

-- ---------------------------------------------------------------------------
-- Caching and invalidation
-- ---------------------------------------------------------------------------

test("Roster builds lazily and holds the map until it is invalidated", function()
    local inst = grouped(PARTY)
    local R = inst.NS.Roster

    assertEqual(#R.GetGroup(), 3)

    -- A raid regroup can fire GROUP_ROSTER_UPDATE a dozen times a second while
    -- nothing is on screen. Until something says the map is stale, the cached
    -- one is what every reader gets.
    inst.mocks.setSolo("Player-1-0000000A", "Tankadin", "PALADIN")
    assertEqual(#R.GetGroup(), 3, "the map is cached, not recomputed per read")

    R.Refresh()
    assertEqual(#R.GetGroup(), 1, "and the next read after an invalidation rebuilds it")
end)

test("Roster.Refresh drops the cache without rebuilding it eagerly", function()
    local inst = grouped(PARTY)
    local NS = inst.NS

    NS.Roster.GetGroup()
    local cache = NS.State.Cache("Roster")
    assertTrue(cache.group ~= nil, "the build populated the shared cache")

    NS.Roster.Refresh()
    assertNil(cache.group, "Refresh drops it")
    assertNil(cache.byGuid)
    assertNil(cache.pets)
end)

test("Roster shares core/State.lua's cache seam rather than owning a private one", function()
    local inst = grouped(PARTY)
    local NS = inst.NS

    NS.Roster.GetGroup()
    -- One invalidation seam for the roster map, the formatter instances and the
    -- frozen sort orders. A wipe-all must reach this module.
    NS.State.WipeCache()
    assertNil(NS.State.Cache("Roster").group)
    assertEqual(#NS.Roster.GetGroup(), 3, "and the next read rebuilds cleanly")
end)

test("Entering or leaving test mode invalidates the map", function()
    -- THE EMPTY TEST GRID. Test mode substitutes BOTH data sources — the meter
    -- in modules/Provider.lua and the unit API in this file's build() — but the
    -- substitution here only takes effect on a BUILD, and the live client always
    -- has a warm map by the time anybody types `/mm test`. So the invented
    -- sources were joined against the REAL group, every one of them was dropped
    -- as "not in your group", and the window drew nothing at all — with no
    -- notice, because preview suppresses it.
    --
    -- Leaving test mode is the same bug pointing the other way: the mocked group
    -- stayed cached and every real source was dropped until the next regroup.
    -- red under: no TEST_MODE_CHANGED subscription.
    local inst = grouped(PARTY)
    local NS = inst.NS
    NS.Roster:OnEnable()

    assertEqual(#NS.Roster.GetGroup(), 3, "the map is warm before test mode is touched")

    NS.State.SetTestMode(true)
    local group = NS.Roster.GetGroup()
    assertEqual(#group, #NS.Aggregator.TestGroup(),
        "test mode must be joined against the mocked group, or every row is dropped")
    assertTrue(NS.Roster.IsGroupMember(group[1].guid))

    NS.State.SetTestMode(false)
    assertEqual(#NS.Roster.GetGroup(), 3, "and the real group comes straight back")
end)

-- ---------------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------------

test("Roster subscribes to the roster message; it never sends one", function()
    local inst = grouped(PARTY)
    local NS, mocks = inst.NS, inst.mocks
    local MSG = NS.Constants.MSG

    NS.Roster:OnEnable()
    for _, message in ipairs{ MSG.ROSTER_CHANGED, MSG.ENTERING_WORLD, MSG.PROFILE_CHANGED,
                              MSG.TEST_MODE_CHANGED } do
        assertTrue((mocks.__msgRegistry[message] or {})[NS.Roster] ~= nil,
            "Roster must listen on " .. message)
    end

    NS.Roster.GetGroup()
    inst.mocks.setSolo("Player-1-0000000A", "Tankadin", "PALADIN")
    NS:SendMessage(MSG.ROSTER_CHANGED)
    assertEqual(#NS.Roster.GetGroup(), 1, "the message invalidates the map")
end)

test("modules/Roster.lua registers no game event of its own", function()
    -- core/MultiMeters.lua is the addon's single game-event listener
    -- (architecture-§4). A second GROUP_ROSTER_UPDATE registration here would be
    -- a second source of truth for one transition.
    local fh = assert(io.open(T.root .. "/modules/Roster.lua", "r"))
    local n = 0
    for line in fh:lines() do
        n = n + 1
        if not line:match("^%s*%-%-") then
            local code = line:gsub("%s%-%-.*$", "")
            assertFalse(code:find("RegisterEvent", 1, true) ~= nil,
                "modules/Roster.lua:" .. n .. " registers a game event")
        end
    end
    fh:close()
end)

test("A partial build is NOT cached, so the next read retries", function()
    -- THE EMPTY WINDOW. The roster is invalidated on GROUP_ROSTER_UPDATE and
    -- PLAYER_ENTERING_WORLD, and both fire before the unit API has populated. The
    -- next read built a map with almost nobody in it, cached that, and nothing
    -- invalidated it again — so for an entire boss fight every source the meter
    -- reported was dropped as "not in your group". The live debug log showed
    -- `rows=0 dropped=10` for forty seconds, then one build after combat and
    -- `rows=5` immediately.
    -- red under: caching unconditionally at the end of build().
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    -- The API knows there are three; only one unit token has resolved yet.
    inst.mocks.setUnit("party1", nil)
    inst.mocks.setUnit("party2", nil)
    inst.NS.Roster.Refresh()

    assertEqual(#inst.NS.Roster.GetGroup(), 1, "it renders with what there is")
    assertTrue(inst.NS.State.Cache("Roster").partial,
        "but it must know the map is short, so the next read rebuilds")

    -- The units arrive; the very next read is correct, with no event needed.
    inst.mocks.setGroup(PARTY)
    assertEqual(#inst.NS.Roster.GetGroup(), 3, "and self-corrects on the next refresh")
end)

test("A complete build IS cached", function()
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    inst.NS.Roster.Refresh()

    assertEqual(#inst.NS.Roster.GetGroup(), 3)
    assertTrue(inst.NS.State.Cache("Roster").group ~= nil)
    assertNil(inst.NS.State.Cache("Roster").partial,
        "a full map must not be rebuilt on every read")
end)

test("Solo is complete, not partial", function()
    -- GetNumGroupMembers answers 0 when solo, and one member is the whole group.
    local inst = T.load()
    inst.mocks.setSolo("Player-1-00000001", "Loner", "MAGE")
    inst.NS.Roster.Refresh()

    assertEqual(#inst.NS.Roster.GetGroup(), 1)
    assertNil(inst.NS.State.Cache("Roster").partial,
        "a solo roster must cache, or it rebuilds four times a second forever")
end)

-- ---------------------------------------------------------------------------
-- The remembered half — db.global.roster
-- ---------------------------------------------------------------------------
--
-- The live map answers "who is in the group RIGHT NOW", which was the wrong
-- question for the grid: leave a dungeon and the live roster collapses to
-- { player }, so modules/Aggregator.lua's filter threw away a session that still
-- held everybody's numbers. Everything the build learns is therefore ALSO written
-- to `db.global.roster`, which is SavedVariables and so is contract in its own
-- right — its keys and its shape survive a reload and a refactor must not move
-- either.

test("Every member the build learns is remembered in db.global, as a plain copy", function()
    local inst = grouped(PARTY)
    inst.NS.Roster.GetGroup()

    local entry = inst.NS.db.global.roster.byGuid["Player-1-0000000B"]
    assertTrue(entry ~= nil, "the build must write what it learned to SavedVariables")
    assertEqual(entry.guid, "Player-1-0000000B")
    assertEqual(entry.name, "Healbot")
    assertEqual(entry.classFilename, "PRIEST")
    assertEqual(entry.role, "HEALER")
    assertEqual(entry.isPlayer, false)

    -- A COPY, not the live entry, and `unit` is deliberately not part of it: this
    -- table goes to SavedVariables, the live entry is wiped on every regroup, and
    -- a unit token is a statement about a group that will not exist by the time
    -- the copy is read back.
    assertNil(entry.unit, "a unit token must not be persisted; it is true for one regroup")
    assertFalse(entry == inst.NS.State.Cache("Roster").byGuid["Player-1-0000000B"],
        "the remembered entry must not alias the live one, which gets wiped")
end)

test("A pet link is remembered too, and a secret one never reaches SavedVariables", function()
    -- Both halves matter. The link is what keeps a pet row alive after the group
    -- is gone (there is no `party1pet` once you have left the party), and the
    -- refusal is the follower-dungeon bug in its most expensive form: a secret
    -- used as a key in a table that is then SERIALISED at logout.
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    inst.mocks.setPet("player", "Pet-0-1111")
    inst.mocks.setPet("party1", inst.mocks.secret("Pet-0-SECRET"))
    inst.NS.Roster.Refresh()
    inst.NS.Roster.GetGroup()

    local pets = inst.NS.db.global.roster.pets
    assertEqual(pets["Pet-0-1111"], "Player-1-0000000A")
    local n = 0
    for key in pairs(pets) do
        n = n + 1
        assertFalse(inst.mocks.isSimulatedSecret(key),
            "a secret GUID reached SavedVariables as a KEY")
    end
    assertEqual(n, 1, "the unreadable pet must be left out, not entered under some other key")
end)

test("Refresh forgets the group but not the people; Forget forgets both", function()
    -- THE BUG THE SPLIT EXISTS TO FIX. Leaving a dungeon group fires the roster
    -- message, and wiping the remembered map there would empty the window of
    -- everyone you had just fought beside while their numbers were still on it.
    local inst = grouped(PARTY)
    local R = inst.NS.Roster
    R.GetGroup()

    inst.mocks.setSolo("Player-1-0000000A", "Tankadin", "PALADIN")
    R.Refresh()

    assertEqual(#R.GetGroup(), 1, "the LIVE map is only who is actually here")
    assertTrue(R.IsGroupMember("Player-1-0000000B"),
        "but they were in the group while this data was collected, which is the question meant")
    assertEqual(R.Get("Player-1-0000000B").name, "Healbot")

    -- A meter reset is the one thing that clears it: the moment the numbers those
    -- GUIDs belonged to stopped existing.
    R.Forget()
    local stored = inst.NS.db.global.roster
    assertNil(next(stored.byGuid), "Forget must empty the remembered members")
    assertNil(next(stored.pets), "and the remembered pet links with them")
    assertEqual(type(stored.byGuid), "table", "both maps must survive as tables")
    assertEqual(type(stored.pets), "table", "or the next build indexes a nil")
    assertFalse(R.IsGroupMember("Player-1-0000000B"), "and a stranger is a stranger again")
end)

test("The live entry is preferred over the remembered one, never the other way round", function()
    -- The live entry is the fresher of the two — a player who respecced has a new
    -- role — and the remembered one is a snapshot from whenever they were last
    -- built. Reversing the two `or` arms would pin every row to its oldest known
    -- name and role for the life of the meter's data.
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    inst.mocks.setPet("party1", "Pet-0-2222")
    local R = inst.NS.Roster
    R.Refresh()
    R.GetGroup()   -- the live map is WARM, so nothing below rebuilds it

    -- Poisoned after the build, and read back with no invalidation in between: a
    -- rebuild rewrites the remembered snapshot from the live walk, so the two
    -- only ever disagree while the cache is warm, which is exactly when every
    -- lookup in a refresh happens.
    inst.NS.db.global.roster.byGuid["Player-1-0000000B"].name = "StaleName"
    inst.NS.db.global.roster.pets["Pet-0-2222"] = "Player-1-0000000C"

    assertEqual(R.Get("Player-1-0000000B").name, "Healbot", "the live entry answers first")
    assertEqual(R.OwnerOf("Pet-0-2222"), "Player-1-0000000B",
        "and the live pet map answers before the remembered one")
end)

-- ---------------------------------------------------------------------------
-- The guards, arm by arm
-- ---------------------------------------------------------------------------

test("A member whose own GUID is unreadable is left out, pet and all", function()
    -- IsSafeKey guards the WHOLE member block, pet lookup included, and the
    -- nesting is the contract: a pet attributed to a member who was never entered
    -- would be a row pointing at an owner no lookup can resolve.
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    inst.mocks.setUnit("party1", { guid = inst.mocks.secret("Player-1-SECRET"),
                                   name = "Ghost", class = "PRIEST", role = "HEALER" })
    inst.mocks.setPet("party1", "Pet-0-2222")
    inst.NS.Roster.Refresh()

    local R = inst.NS.Roster
    assertEqual(#R.GetGroup(), 2, "an unjoinable member is left out rather than keyed on")
    assertNil(R.OwnerOf("Pet-0-2222"),
        "and its pet goes with it — unattributable, which the aggregator drops")
end)

test("The raid duplicate is skipped WHOLE, its pet unit included", function()
    -- In a raid the player is visited twice, as "player" and as raidN, and the
    -- first entry wins. The skip is of the entire block, so `raid1pet` is never
    -- asked about — which costs nothing live, because the same pet answers to
    -- "playerpet", and is exactly what stops the second pass rewriting the map.
    local inst = T.load()
    inst.mocks.setGroup(PARTY, { raid = true })
    inst.mocks.setPet("raid1", "Pet-0-RAID1")
    inst.mocks.setPet("raid2", "Pet-0-RAID2")
    inst.NS.Roster.Refresh()

    local R = inst.NS.Roster
    assertEqual(R.Get("Player-1-0000000A").unit, "player",
        "the GUID index must hold the `player` entry, not the raidN one")
    assertEqual(R.OwnerOf("Pet-0-RAID2"), "Player-1-0000000B",
        "a raid member that is NOT the duplicate has its pet read as normal")
    assertNil(R.OwnerOf("Pet-0-RAID1"), "the duplicate's pet unit is never consulted")
end)

test("An empty unit API yields an empty group rather than a raise", function()
    -- A client missing the unit APIs, and the frame after a zone-in before any
    -- token has resolved, both land here. Nothing is entered and nothing raises.
    local inst = T.load()
    inst.mocks.setGroup{}
    inst.NS.Roster.Refresh()

    assertEqual(#inst.NS.Roster.GetGroup(), 0)
    assertNil(inst.NS.Roster.LocalGUID(), "with no player entry there is no local GUID")
end)

test("A partial build is still STORED, so the lookups have something to answer from", function()
    -- MARKED, not withheld. `partial` only makes `ensure` build again on the next
    -- read; withholding the map as well would leave every lookup answering nil
    -- for the quarter-second the group takes to resolve, which is the empty
    -- window all over again in a shorter form.
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    inst.mocks.setUnit("party1", nil)
    inst.mocks.setUnit("party2", nil)
    inst.NS.Roster.Refresh()
    inst.NS.Roster.GetGroup()

    local cache = inst.NS.State.Cache("Roster")
    assertTrue(cache.byGuid["Player-1-0000000A"] ~= nil, "the short map is cached, not discarded")
    assertTrue(cache.pets ~= nil, "and all three outputs are stored, not just the array")
    assertTrue(inst.NS.Roster.IsGroupMember("Player-1-0000000A"))
end)

-- ---------------------------------------------------------------------------
-- The local player
-- ---------------------------------------------------------------------------

test("Roster.LocalGUID reads the player's GUID off the built map", function()
    -- THE ONE IDENTITY THAT SURVIVES THE RESTRICTION. C_DamageMeter hands back a
    -- SECRET sourceGUID mid-pull, so a source can only say `isLocalPlayer` for
    -- itself; this is the plain GUID that claim resolves to. Read off the MAP
    -- rather than from UnitGUID("player") so the answer is the same string the
    -- rest of the map is keyed on and the row joins its own name and class.
    local inst = grouped(PARTY)
    assertEqual(inst.NS.Roster.LocalGUID(), "Player-1-0000000A")

    local raid = grouped(PARTY, { raid = true })
    assertEqual(raid.NS.Roster.LocalGUID(), "Player-1-0000000A",
        "and the raid duplicate must not cost us the isPlayer flag")
end)

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------

test("The player's role falls back to their specialization; another unit's cannot", function()
    -- The role icon silently disappeared for a player who had the setting on and
    -- could see it five minutes earlier in a dungeon: solo, or in a party that
    -- never assigned roles, UnitGroupRolesAssigned answers "NONE". The fallback is
    -- the player's own spec, which is what they are actually doing whether or not
    -- anybody wrote it down — and GetSpecializationRole reads the ACTIVE spec, so
    -- there is no such answer for an arbitrary unit.
    local inst = T.load()
    inst.mocks.setGroup{
        { guid = "Player-1-0000000A", name = "Tankadin", class = "PALADIN", role = "NONE" },
        { guid = "Player-1-0000000B", name = "Healbot",  class = "PRIEST",  role = "NONE" },
    }
    inst.mocks.setSpecRole("TANK")
    inst.NS.Roster.Refresh()

    local group = inst.NS.Roster.GetGroup()
    assertEqual(group[1].role, "TANK", "the player's own spec answers where the group did not")
    assertEqual(group[2].role, "NONE", "a party member has no such call and stays NONE")
end)

test("An assigned role beats the specialization fallback", function()
    -- The order is load-bearing: the group's assignment is what the raid is
    -- actually playing to, and a tank in a DPS spec doing a tank's job would
    -- otherwise get the wrong icon.
    local inst = T.load()
    inst.mocks.setSolo("Player-1-00000001", "Loner", "PALADIN")   -- role DAMAGER
    inst.mocks.setSpecRole("TANK")
    inst.NS.Roster.Refresh()

    assertEqual(inst.NS.Roster.GetGroup()[1].role, "DAMAGER")
end)

-- ---------------------------------------------------------------------------
-- Test mode
-- ---------------------------------------------------------------------------

test("Test mode replaces the pet map and writes nothing to SavedVariables", function()
    -- The invented group is a rendering fixture, not a fact about this account.
    -- Persisting `Player-9999-TEST0001` would leave ten strangers in the
    -- remembered map for the life of the meter's data, and every one of them
    -- would pass IsGroupMember long after test mode was switched off.
    local inst = grouped(PARTY)
    local NS = inst.NS
    NS.Roster:OnEnable()
    inst.mocks.setPet("player", "Pet-0-1111")
    NS.Roster.Refresh()
    NS.Roster.GetGroup()

    NS.State.SetTestMode(true)
    local group = NS.Roster.GetGroup()
    assertEqual(group[1].name, "Ka0stank", "the invented group is what the map describes")
    assertTrue(NS.Roster.IsGroupMember(group[1].guid))
    assertNil(NS.db.global.roster.byGuid[group[1].guid],
        "an invented member must not reach SavedVariables")
    -- The LIVE pet map is replaced rather than carried over, so a real pet is not
    -- attributed to an invented owner. (OwnerOf still answers it from the
    -- remembered map, which is the point of the remembered map.)
    assertNil(NS.State.Cache("Roster").pets["Pet-0-1111"],
        "test mode must not leave a real pet in the live map")
end)

test("The test-mode map is cached whole, never marked partial", function()
    -- build() returns EARLY in test mode, before the GetNumGroupMembers
    -- cross-check. That is deliberate: the invented group is complete by
    -- definition, and measuring it against the size of the REAL group would mark
    -- it short and rebuild it on every refresh for as long as test mode was on.
    local spec = {}
    for i = 1, 12 do
        spec[i] = { guid = string.format("Player-1-%08X", i), name = "Raider" .. i,
                    class = "MAGE", role = "DAMAGER" }
    end
    local inst = grouped(spec, { raid = true })
    local NS = inst.NS
    NS.Roster:OnEnable()
    assertEqual(#NS.Roster.GetGroup(), 12)

    NS.State.SetTestMode(true)
    assertEqual(#NS.Roster.GetGroup(), #NS.Aggregator.TestGroup())
    assertNil(NS.State.Cache("Roster").partial,
        "a preview group smaller than the real one is not a short build")
end)

test("Test mode with no preview group falls back to the real unit walk", function()
    -- `A and A.TestGroup` is resolved at CALL time because modules/Aggregator.lua
    -- loads after this file, so the reference can genuinely be missing. The arm
    -- has to fall THROUGH to the real build: returning an empty group here would
    -- drop every source in the window with no notice to explain it.
    local inst = grouped(PARTY)
    local NS = inst.NS
    NS.Roster:OnEnable()
    NS.Aggregator.TestGroup = nil

    NS.State.SetTestMode(true)
    assertEqual(#NS.Roster.GetGroup(), 3, "the real group, rather than an empty map or a raise")
end)

-- ---------------------------------------------------------------------------
-- The debug line
-- ---------------------------------------------------------------------------
--
-- ONE line per build, format deferred, and the counters in it are the loop's own
-- (debug-logging-§3). It is the line that diagnosed the empty window — `rows=0
-- dropped=10` for forty seconds, then one `[Roster] built members=5` after
-- combat — so its wording is what a bug report is grepped for.

test("A completed build logs one line, with the counters the loop kept", function()
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    inst.mocks.setPet("player", "Pet-0-1111")
    inst.mocks.setPet("party1", inst.mocks.secret("Pet-0-SECRET"))
    inst.NS.Roster.Refresh()
    inst.NS.State.debug = true
    inst.NS.Roster.GetGroup()

    local line = inst.NS.DebugLog:LastLine()
    -- pets=1, not 2: the unreadable pet was never entered, and a counter that
    -- disagreed with the map would make the log lie about the interesting case.
    assertTrue(line:find("built members=3 pets=1 raid=no", 1, true) ~= nil,
        "got: " .. tostring(line))
end)

test("The build line says whether this was a raid", function()
    local inst = T.load()
    inst.mocks.setGroup(PARTY, { raid = true })
    inst.NS.Roster.Refresh()
    inst.NS.State.debug = true
    inst.NS.Roster.GetGroup()

    local line = inst.NS.DebugLog:LastLine()
    assertTrue(line:find("built members=3 pets=0 raid=yes", 1, true) ~= nil,
        "got: " .. tostring(line))
end)

test("A short build says so, and does not also claim it built the group", function()
    -- The two are exclusive by construction — the partial arm returns — and that
    -- is what makes "built members=" a reliable grep for a build that STUCK.
    local inst = T.load()
    inst.mocks.setGroup(PARTY)
    inst.mocks.setUnit("party1", nil)
    inst.mocks.setUnit("party2", nil)
    inst.NS.Roster.Refresh()
    inst.NS.State.debug = true
    inst.NS.Roster.GetGroup()

    local line = inst.NS.DebugLog:LastLine()
    assertTrue(line:find("partial build (1 of 3) — will retry", 1, true) ~= nil,
        "got: " .. tostring(line))
    assertFalse(line:find("built members=", 1, true) ~= nil,
        "a short build must not be logged as a completed one")
end)

-- ---------------------------------------------------------------------------
-- Forgetting the remembered map (debug-logging-§8, §10)
-- ---------------------------------------------------------------------------

test("Roster.Forget traces what it forgot, in one line", function()
    -- A forget of learned data is a data mutation debug-logging-§8 traces, and
    -- one line for the whole map rather than one per member (§9).
    -- red under: a Forget that wipes db.global.roster silently.
    local inst = grouped(PARTY)
    local NS = inst.NS
    NS.Roster.GetGroup()
    NS.State.debug = true

    NS.Roster.Forget()

    local found = NS.DebugLog:FindLine("forgot the remembered roster")
    assertTrue(found ~= nil, "the forget left no line in the log")
    assertTrue(found:find("3 members", 1, true) ~= nil, "got: " .. tostring(found))
    assertNil(next(NS.db.global.roster.byGuid), "and the map is empty afterwards")
end)

test("A meter reset forgets the remembered roster, through the bus", function()
    -- The module's own header, Forget's docstring and the aggregator case "A meter
    -- reset is what forgets them" all say the reset is what clears the map. The
    -- reset handler wipes the SESSION caches only; nothing called Forget, so the
    -- map only ever grew.
    -- red under: a Roster that does not subscribe to METER_RESET.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    inst.mocks.setGroup(PARTY)
    NS.Roster.Refresh()
    NS.Roster.GetGroup()
    assertTrue(NS.db.global.roster.byGuid["Player-1-0000000B"] ~= nil,
        "the fixture needs a remembered member first")

    inst.mocks.setSolo("Player-1-0000000A", "Tankadin", "PALADIN")
    inst.mocks.__fireEvent("DAMAGE_METER_RESET")

    assertNil(NS.db.global.roster.byGuid["Player-1-0000000B"],
        "a stranger from before the reset is still remembered")
end)
