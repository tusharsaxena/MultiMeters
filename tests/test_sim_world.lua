-- tests/test_sim_world.lua — the simulator's invented world and its providers (modules/SimWorld.lua).
--
-- MM-13 (MultiMeters#60). The world is pure functions of one table, so most cases drive it
-- directly; the provider cases run a throwaway session (tests/sim_support.lua) on a fresh
-- instance's seam and read through NS.Compat, the way the engine does.

local T = _G.MULTIMETERS_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local S = dofile((T.root or ".") .. "/tests/sim_support.lua")

local PLAYER = { guid = "Player-1-00000001", name = "Me", classFilename = "MAGE", role = "DAMAGER" }

local function World() return assert(NS.SimHost.World, "modules/SimWorld.lua publishes no NS.SimHost.World") end
local function stat(key) return NS.Constants.STAT_TYPE[key] end

--- A world with a five-player group in a fight of `ticks` ticks of 2 s each.
local function fought(seed, ticks, n, raid)
    local W = World()
    local w = W.New(seed, PLAYER)
    W.SetGroup(w, n or 5, raid)
    W.OpenSegment(w, "Boss")
    for _ = 1, ticks or 5 do W.Tick(w, 2) end
    return w
end

local function names(w)
    local out = {}
    for _, m in ipairs(w.members) do out[#out + 1] = m.guid .. "=" .. m.name .. "/" .. m.classFilename end
    return table.concat(out, ",")
end

local function totals(session)
    local out = {}
    for _, src in ipairs(session.combatSources) do
        out[#out + 1] = tostring(src.sourceGUID or src.sourceCreatureID) .. ":" .. src.totalAmount
    end
    return table.concat(out, ",")
end

-- ── the world ─────────────────────────────────────────────────────────────────────────────────

test("SimWorld: the same seed gives the same members, names and totals after N ticks", function()
    local W = World()
    local a, b = fought(42, 6), fought(42, 6)
    assertEqual(names(a), names(b))
    for _, key in ipairs({ "DamageDone", "HealingDone", "Interrupts" }) do
        assertEqual(totals(W.Session(a, "current", stat(key))), totals(W.Session(b, "current", stat(key))), key)
    end
    assertTrue(names(fought(7, 6)) ~= names(a), "two seeds gave the same group")
end)

test("SimWorld: the local player is the real player, first, with the live role", function()
    local W = World()
    local w = W.New(1, { guid = "Player-1-0000ABCD", name = "Real", classFilename = "PRIEST", role = "HEALER" })
    W.SetGroup(w, 5)
    local me = w.members[1]
    assertEqual(me.guid, "Player-1-0000ABCD")
    assertEqual(me.name, "Real")
    assertEqual(me.classFilename, "PRIEST")
    assertEqual(me.role, "HEALER")
    assertTrue(me.isLocalPlayer, "the player's member is not the local player")
    assertTrue(W.Unit(w, "player") == me, "the player token does not resolve the player")
    for i = 2, #w.members do
        assertTrue(w.members[i].guid:find("^Player%-9998%-SIM%d%d%d%d$") ~= nil, w.members[i].guid)
        assertTrue(not w.members[i].isLocalPlayer, "an invented mate is the local player")
    end
end)

test("SimWorld: SetGroup(5) gives party tokens", function()
    local W = World()
    local w = W.New(3, PLAYER)
    W.SetGroup(w, 5)
    assertEqual(w.group.size, 5)
    assertTrue(w.group.inGroup and not w.group.inRaid, "a party reads as a raid or as solo")
    for i = 1, 4 do assertTrue(W.Unit(w, "party" .. i) == w.members[i + 1], "party" .. i) end
    assertEqual(W.Unit(w, "party5"), nil)
    assertEqual(W.Unit(w, "raid1"), nil)
end)

test("SimWorld: SetGroup(20, true) gives raid tokens with the player once and the pets resolvable", function()
    local W = World()
    local w = W.New(11, PLAYER)
    W.SetGroup(w, 20, true)
    assertTrue(w.group.inRaid, "a raid does not read as a raid")
    local seen, mine, pets = {}, 0, 0
    for i = 1, 20 do
        local m = W.Unit(w, "raid" .. i)
        assertTrue(m ~= nil, "raid" .. i .. " resolves nothing")
        assertTrue(not seen[m.guid], m.guid .. " holds two raid tokens")
        seen[m.guid] = true
        if m.guid == PLAYER.guid then mine = mine + 1 end
        local pet = W.Unit(w, "raid" .. i .. "pet")
        if m.pet then
            assertTrue(pet == m.pet, "raid" .. i .. "pet does not resolve the pet")
            assertTrue(pet.guid:find("^Pet%-0%-9998%-SIM%d%d%d%d$") ~= nil, pet.guid)
            pets = pets + 1
        end
    end
    assertEqual(mine, 1, "the player is not in the raid exactly once")
    assertTrue(pets >= 2, "the raid carries no hunter and warlock pets")
    assertEqual(W.Unit(w, "raid21"), nil)
end)

test("SimWorld: Session('current') is sorted descending with maxAmount first and the true total", function()
    local W = World()
    local w = fought(5, 8)
    for _, key in ipairs({ "DamageDone", "HealingDone", "DamageTaken", "Interrupts" }) do
        local s = W.Session(w, "current", stat(key))
        local sum = 0
        for i, src in ipairs(s.combatSources) do
            sum = sum + src.totalAmount
            if i > 1 then assertTrue(s.combatSources[i - 1].totalAmount >= src.totalAmount, key .. " not descending") end
            assertTrue(src.sourceGUID ~= nil and src.sourceCreatureID == nil, key .. " has a non-ally source")
        end
        assertEqual(s.maxAmount, s.combatSources[1].totalAmount, key)
        assertEqual(s.totalAmount, sum, key)
        assertEqual(s.durationSeconds, 16, key)
    end
end)

test("SimWorld: pets deal a quarter of their owner's damage as their own row", function()
    local W = World()
    local w = fought(9, 4)
    local hunter
    for _, m in ipairs(w.members) do if m.classFilename == "HUNTER" then hunter = m end end
    assertTrue(hunter and hunter.pet, "the five-player group has no hunter pet")
    local byGuid = {}
    for _, src in ipairs(W.Session(w, "current", stat("DamageDone")).combatSources) do byGuid[src.sourceGUID] = src end
    local own, pet = byGuid[hunter.guid].totalAmount, byGuid[hunter.pet.guid].totalAmount
    assertTrue(math.abs(pet - own * 0.25) <= 1, ("pet %d vs owner %d"):format(pet, own))
end)

test("SimWorld: enemies appear only in EnemyDamageTaken, with a creature id and no GUID", function()
    local W = World()
    local w = fought(5, 3)
    local s = W.Session(w, "current", stat("EnemyDamageTaken"))
    assertEqual(#s.combatSources, 1)
    local e = s.combatSources[1]
    assertTrue(e.sourceGUID == nil and type(e.sourceCreatureID) == "number", "the enemy row is not a creature")
    assertEqual(e.sourceDisplayType, NS.Constants.SOURCE_DISPLAY_TYPE.Enemy)
    local dealt = 0
    for _, src in ipairs(W.Session(w, "current", stat("DamageDone")).combatSources) do dealt = dealt + src.totalAmount end
    assertTrue(math.abs(e.totalAmount - dealt) <= #w.members * 2, "the enemy did not take the group's damage")
end)

test("SimWorld: Overall equals the sum of two segments", function()
    local W = World()
    local w = fought(5, 4)
    W.CloseSegment(w)
    W.OpenSegment(w, "Trash")
    for _ = 1, 3 do W.Tick(w, 3) end
    W.CloseSegment(w)
    local first, second = w.segments[2].sessionID, w.segments[1].sessionID
    local key = stat("HealingDone")
    local a, b = W.Session(w, first, key), W.Session(w, second, key)
    local o = W.Session(w, "overall", key)
    assertEqual(o.durationSeconds, a.durationSeconds + b.durationSeconds)
    local sum = {}
    for _, s in ipairs({ a, b }) do
        for _, src in ipairs(s.combatSources) do sum[src.sourceGUID] = (sum[src.sourceGUID] or 0) + src.totalAmount end
    end
    for _, src in ipairs(o.combatSources) do
        assertTrue(math.abs(src.totalAmount - sum[src.sourceGUID]) <= 1, src.sourceGUID)
    end
    assertEqual(W.Session(w, "current", key).durationSeconds, 9, "Current is not the last segment")
end)

test("SimWorld: a session id the world does not hold answers nil", function()
    local W = World()
    local w = fought(5, 2)
    assertEqual(W.Session(w, 12345, stat("DamageDone")), nil)
    assertEqual(W.Session(w, w.segments[1].sessionID + 999, stat("DamageDone")), nil)
    assertTrue(W.Session(w, w.segments[1].sessionID, stat("DamageDone")) ~= nil, "the held id answers nil")
end)

test("SimWorld: Die gives a Deaths row and a recap with events newest first", function()
    local W = World()
    local w = fought(5, 3)
    local victim = w.members[3]
    local id = W.Die(w, victim.guid)
    assertTrue(type(id) == "number", "Die answered no recap id")
    local s = W.Session(w, "current", stat("Deaths"))
    assertEqual(#s.combatSources, 1)
    local row = s.combatSources[1]
    assertEqual(row.sourceGUID, victim.guid)
    assertEqual(row.totalAmount, 1)
    assertEqual(row.deathTimeSeconds, 6)
    assertEqual(row.deathRecapID, id)
    local recap = w.recaps[id]
    assertTrue(recap and #recap.events >= 2 and recap.maxHealth > 0, "the recap is empty")
    for i = 2, #recap.events do
        assertTrue(recap.events[i - 1].timestamp > recap.events[i].timestamp, "recap events are not newest first")
    end
    -- The dead stop producing.
    local before = W.Session(w, "current", stat("DamageDone"))
    W.Tick(w, 2)
    local after = W.Session(w, "current", stat("DamageDone"))
    local function amountOf(sess)
        for _, src in ipairs(sess.combatSources) do if src.sourceGUID == victim.guid then return src.totalAmount end end
    end
    assertEqual(amountOf(after), amountOf(before), "a dead member kept dealing damage")
end)

test("SimWorld: ResetSegments empties the list", function()
    local W = World()
    local w = fought(5, 2)
    W.Die(w, w.members[2].guid)
    W.ResetSegments(w)
    assertEqual(#w.segments, 0)
    assertEqual(w.current, nil)
    assertEqual(#W.AvailableSessions(w), 0)
    assertEqual(W.Session(w, "overall", stat("DamageDone")), nil)
    assertEqual(next(w.recaps), nil, "a recap survived the reset")
end)

test("SimWorld: every answer is a fresh table, so mutating one leaves the next alone", function()
    local W = World()
    local w = fought(5, 3)
    local key = stat("DamageDone")
    local first = W.Session(w, "current", key)
    local want = totals(first)
    first.combatSources[1].totalAmount = -1
    table.remove(first.combatSources)
    assertEqual(totals(W.Session(w, "current", key)), want)
    local list = W.AvailableSessions(w)
    list[1].name = "edited"
    assertEqual(W.AvailableSessions(w)[1].name, "Boss")
    local detail = W.SourceDetail(w, "current", key, w.members[1].guid)
    detail.combatSpells[1].totalAmount = -1
    assertTrue(W.SourceDetail(w, "current", key, w.members[1].guid).combatSpells[1].totalAmount > 0)
end)

test("SimWorld: a source breakdown is three real spells, descending, summing to the source", function()
    local W = World()
    local w = fought(5, 4)
    local me = w.members[1]
    local d = W.SourceDetail(w, "current", stat("DamageDone"), me.guid)
    assertEqual(#d.combatSpells, 3)
    local sum = 0
    for i, sp in ipairs(d.combatSpells) do
        sum = sum + sp.totalAmount
        assertEqual(sp.spellID, me.spells[i])
        if i > 1 then assertTrue(d.combatSpells[i - 1].totalAmount >= sp.totalAmount, "not descending") end
    end
    assertEqual(sum, d.totalAmount)
    assertEqual(d.maxAmount, d.combatSpells[1].totalAmount)
    assertEqual(W.SourceDetail(w, "current", stat("DamageDone"), "Player-0-NOBODY"), nil)
end)

-- ── the providers ─────────────────────────────────────────────────────────────────────────────

test("SimWorld: every provider calls fallback when there is no world", function()
    local W = World()
    local saved = NS.SimHost.world
    NS.SimHost.world = nil
    for _, key in ipairs(W.PROVIDED) do
        local seen
        local out = W.PROVIDERS[key](function(...) seen = select("#", ...); return "fallback" end, "a", "b")
        assertEqual(out, "fallback", key)
        assertEqual(seen, 2, key .. " did not pass its arguments to fallback")
    end
    NS.SimHost.world = saved
end)

test("SimWorld: every wrapped key that is not guarded has a provider", function()
    local W = World()
    local provided = {}
    for _, key in ipairs(W.PROVIDED) do provided[key] = true end
    local missing = {}
    for _, key in ipairs(NS.SimSeam:Keys()) do
        if not provided[key] and not NS.SimHost.Guarded[key] then missing[#missing + 1] = key end
    end
    assertEqual(#missing, 0, "wrapped keys with no provider: " .. table.concat(missing, ", "))
    for _, key in ipairs(W.PROVIDED) do assertTrue(not NS.SimHost.Guarded[key], key .. " is guarded and provided") end
end)

test("SimWorld: during a session every meter read answers from the world, never the client", function()
    local inst = T.load{}
    local ns, m = inst.NS, inst.mocks
    local W = ns.SimHost.World
    local w = W.New(5, PLAYER)
    W.SetGroup(w, 5)
    W.SetZone(w, "rookery")
    W.OpenSegment(w, "Boss")
    W.Tick(w, 4)
    W.Die(w, w.members[2].guid)
    w.combat = true
    ns.SimHost.world = w
    local _, done = S.testSession(inst)
    m.resetMeterCalls()
    local C, ST = ns.Compat, ns.Constants.SESSION_TYPE
    local dd = stat("DamageDone")
    assertEqual(C.IsDamageMeterAvailable(), true)
    assertEqual(totals(C.GetCombatSessionFromType(ST.Current, dd)), totals(W.Session(w, "current", dd)))
    assertEqual(#C.GetCombatSessionFromType(ST.Overall, dd).combatSources, 7)
    assertEqual(C.GetCombatSessionFromType(ST.Expired, dd), nil)
    local id = w.segments[1].sessionID
    assertTrue(C.GetCombatSessionFromID(id, dd) ~= nil, "FromID missed the simulated segment")
    assertEqual(C.GetCombatSessionFromID(1, dd), nil)
    assertTrue(C.GetCombatSessionSourceFromType(ST.Current, dd, PLAYER.guid) ~= nil, "no source detail")
    assertTrue(C.GetCombatSessionSourceFromID(id, dd, PLAYER.guid) ~= nil, "no source detail by id")
    assertEqual(C.GetAvailableCombatSessions()[1].sessionID, id)
    assertEqual(C.GetSessionDurationSeconds(ST.Current), 4)
    local recapID = w.segments[1].deaths[1].recapID
    assertEqual(C.HasDeathRecap(), true)
    assertEqual(C.HasRecapEvents(recapID), true)
    assertEqual(C.HasRecapEvents(42), false)
    assertTrue(#C.GetRecapEvents(recapID) > 0, "no recap events")
    assertEqual(C.GetRecapMaxHealth(recapID), w.recaps[recapID].maxHealth)
    for name, n in pairs(m.__meter.calls) do assertEqual(n, 0, name .. " reached the client's meter") end
    -- The world reads.
    assertEqual(C.UnitGUID("player"), PLAYER.guid)
    assertEqual(C.UnitGUID("party1"), w.members[2].guid)
    assertEqual(C.UnitName("party2"), w.members[3].name)
    assertEqual(C.UnitExists("party4"), true)
    assertEqual(C.UnitExists("party5"), false)
    assertEqual(select(2, C.UnitClass("party1")), w.members[2].classFilename)
    assertEqual(C.UnitGroupRolesAssigned("party1"), w.members[2].role)
    assertEqual(C.GetNumGroupMembers(), 5)
    assertEqual(C.IsInRaid(), false)
    assertEqual(C.IsInGroup(), true)
    local inInstance, kind = C.IsInInstance()
    assertEqual(inInstance, true)
    assertEqual(kind, "party")
    assertEqual(C.IsInDelve(), false)
    assertEqual(C.UnitAffectingCombat("player"), true)
    assertEqual(C.UnitAffectingCombat("target"), false)
    done()
    -- Idle again: the seam answers the client.
    assertEqual(C.UnitGUID("party1"), m.UnitGUID("party1"))
end)

test("SimWorld: solo, the player's role is left to the spec read, as the client's is", function()
    local inst = T.load{}
    local ns = inst.NS
    local W = ns.SimHost.World
    local w = W.New(5, { guid = "Player-1-00000009", name = "Solo", classFilename = "WARRIOR", role = "TANK" })
    ns.SimHost.world = w
    local _, done = S.testSession(inst)
    assertEqual(ns.Compat.UnitGroupRolesAssigned("player"), "NONE")
    assertEqual(ns.Compat.GetNumGroupMembers(), 0)
    assertEqual(ns.Compat.IsInGroup(), false)
    local inInstance, kind = ns.Compat.IsInInstance()
    assertEqual(inInstance, false)
    assertEqual(kind, "none")
    done()
end)
