local _, NS = ...
-- modules/SimWorld.lua — the simulator's invented world and every answer it gives (MultiMeters#60).
--
-- WHAT IT IS. `/mm sim` plays a scripted fight through the real meter: every read the engine makes
-- through NS.Compat is answered, while a session runs, by the providers at the foot of this file,
-- out of one world table. The world holds the group (the real player plus invented mates), the
-- zone, the combat flag, the segments the client would hold and the death recaps. Its functions are
-- pure functions of that table; modules/SimDrivers.lua edits it and fires the events, and
-- modules/Sim.lua builds it in prepare and publishes it as NS.SimHost.world.
--
-- THE VALUES ARE PLAIN INVENTED NUMBERS (CLAUDE.md, "The one rule specific to this addon"). The
-- world never reads a client meter value: every number below comes from this file's own seeded
-- generator and its own arithmetic, so nothing here inspects a value the client handed over, and
-- core/Secrets.lua stays the only inspector of client values. The world never simulates the Combat
-- restriction either: a session cannot coexist with real combat, so no answer here is a secret.
--
-- THE SHIM SCAN. tests/test_provider.lua proves modules/Provider.lua is the only caller of the
-- meter shims by scanning every loaded file for their `Compat.`-prefixed names. This file registers
-- its providers BY KEY STRING on NS.SimSeam and must never spell a meter shim with that prefix.
--
-- FILE SCOPE. The providers register on NS.SimSeam (core/SimSetup.lua) when this file loads: one
-- registration per key, once, which is the LOAD-BEARING note on its TOC line. Each provider reads
-- the active world from NS.SimHost.world at call time and answers fallback(...) when there is none.
--
-- THE LOCAL PLAYER IS THE REAL PLAYER. World.New takes `player = { guid, name, classFilename, role }`,
-- read by the caller inside NS.SimSeam:Live, `role` from the player's live specialization role. In a
-- group the player's member answers that role through UnitGroupRolesAssigned; solo it answers "NONE",
-- as the client does, and modules/Roster.lua then takes the role from the pure
-- GetSpecializationRole, which is the same live spec role. Either way the read Roster uses agrees.

local World = {}
NS.SimHost = NS.SimHost or {}
NS.SimHost.World = World

local floor = math.floor
local sort = table.sort

local SIM_ID_BASE = 1000000
local GUID_FMT = "Player-9998-SIM%04d"
local PET_GUID_FMT = "Pet-0-9998-SIM%04d"
-- Wall-clock base for recap timestamps: fixed, so a replay of one seed is identical.
local CLOCK_BASE = 1787380000

World.SIM_ID_BASE = SIM_ID_BASE

-- { inInstance, instanceType, name }
local ZONES = {
    rookery   = { true,  "party", "The Rookery" },
    priory    = { true,  "party", "Priory of the Sacred Flame" },
    undermine = { true,  "raid",  "Liberation of Undermine" },
    dorn      = { false, "none",  "Isle of Dorn" },
}
World.ZONES = ZONES

-- Forty fixed invented names; a seed shuffles them.
local NAMES = {
    "Aldrenna", "Brakthar", "Caelith", "Dornik", "Elowen", "Fenwick", "Garrosa", "Halvard",
    "Isolde", "Jorrik", "Kaelin", "Lunessa", "Morvane", "Nyreth", "Orlaith", "Pellam",
    "Quorra", "Rhydian", "Sabeth", "Tormund", "Ulvara", "Vashti", "Wendric", "Xyrell",
    "Yselde", "Zoravan", "Ashkettle", "Brindlemoor", "Corvanna", "Duskwhit", "Emberlyn", "Frostvale",
    "Grimtusk", "Hollowen", "Ironhelm", "Jadewind", "Kettleby", "Larkspire", "Mossgrove", "Nightbrook",
}
World.NAMES = NAMES

-- Per class: the role it plays here, a real spec icon file id, three real spell ids (so the pure
-- GetSpellInfo names them) and whether it brings a pet.
local CLASSES = {
    WARRIOR     = { name = "Warrior",      role = "TANK",    specIconID = 132342, spells = { 23922, 6572, 6343 } },
    PALADIN     = { name = "Paladin",      role = "TANK",    specIconID = 236264, spells = { 31935, 53600, 275779 } },
    PRIEST      = { name = "Priest",       role = "HEALER",  specIconID = 135940, spells = { 2061, 2060, 596 } },
    DRUID       = { name = "Druid",        role = "HEALER",  specIconID = 136041, spells = { 774, 8936, 48438 } },
    SHAMAN      = { name = "Shaman",       role = "HEALER",  specIconID = 136052, spells = { 61295, 77472, 1064 } },
    MAGE        = { name = "Mage",         role = "DAMAGER", specIconID = 135846, spells = { 116, 30455, 44614 } },
    ROGUE       = { name = "Rogue",        role = "DAMAGER", specIconID = 132320, spells = { 196819, 185438, 53 } },
    HUNTER      = { name = "Hunter",       role = "DAMAGER", specIconID = 461112, spells = { 34026, 193455, 217200 },
                    hasPet = true },
    WARLOCK     = { name = "Warlock",      role = "DAMAGER", specIconID = 136145, spells = { 172, 980, 686 },
                    hasPet = true },
    DEATHKNIGHT = { name = "Death Knight", role = "DAMAGER", specIconID = 135773, spells = { 49020, 49143, 49184 } },
    MONK        = { name = "Monk",         role = "DAMAGER", specIconID = 608951, spells = { 100780, 100784, 107428 } },
    DEMONHUNTER = { name = "Demon Hunter", role = "DAMAGER", specIconID = 1247264, spells = { 162794, 188499, 198013 } },
    EVOKER      = { name = "Evoker",       role = "DAMAGER", specIconID = 4511811, spells = { 357208, 356995, 361469 } },
}
World.CLASSES = CLASSES

-- Class pools per role, sorted, so a seeded pick is the same on every client.
local BY_ROLE = { TANK = {}, HEALER = {}, DAMAGER = {} }
for file, spec in pairs(CLASSES) do
    local list = BY_ROLE[spec.role]
    list[#list + 1] = file
end
for _, list in pairs(BY_ROLE) do sort(list) end

-- Pets and enemies cast real spells too.
local PET_SPELLS = { 17253, 16827, 3110 }
local PET_NAMES = { HUNTER = "Wolf", WARLOCK = "Imp" }
local ENEMY_SPELLS = {
    { id = 6603, name = "Auto Attack" }, { id = 133, name = "Fireball" },
    { id = 589, name = "Shadow Word: Pain" }, { id = 8921, name = "Moonfire" },
}

-- How much of each stat a role produces: the proportions of modules/Aggregator_Preview.lua's
-- ROLE_SHAPE, copied (that file's locals are its own).
local ROLE_SHAPE = {
    TANK    = { DamageDone = 0.45, HealingDone = 0.10, Absorbs = 0.30,
                DamageTaken = 1.00, AvoidableDamageTaken = 0.85,
                Interrupts = 1.00, Dispels = 0.30, Deaths = 0.35 },
    HEALER  = { DamageDone = 0.15, HealingDone = 1.00, Absorbs = 1.00,
                DamageTaken = 0.30, AvoidableDamageTaken = 0.55,
                Interrupts = 0.35, Dispels = 1.00, Deaths = 0.60 },
    DAMAGER = { DamageDone = 1.00, HealingDone = 0.12, Absorbs = 0.10,
                DamageTaken = 0.45, AvoidableDamageTaken = 1.00,
                Interrupts = 0.70, Dispels = 0.45, Deaths = 1.00 },
}

-- Per second at a shape of 1.0. Deaths is not a rate: World.Die makes those rows.
local BASE_RATE = {
    DamageDone = 90000, HealingDone = 60000, Absorbs = 12000, DamageTaken = 30000,
    AvoidableDamageTaken = 4000, Interrupts = 0.05, Dispels = 0.04,
}
local RATE_STATS = { "DamageDone", "HealingDone", "Absorbs", "DamageTaken", "AvoidableDamageTaken",
    "Interrupts", "Dispels" }
local INCOMING = { DamageTaken = true, AvoidableDamageTaken = true }
local SPELL_SHARE = { 0.5, 0.3, 0.2 }
local PET_SHARE = 0.25

-- ── the generator ─────────────────────────────────────────────────────────────────────────────

--- A seeded Park-Miller generator: exact in Lua 5.1's doubles, so one seed is one world anywhere.
--- @return function  rng() -> a number in [0, 1)
local function newRng(seed)
    local state = (floor(tonumber(seed) or 1) % 2147483646) + 1
    return function()
        state = (state * 16807) % 2147483647
        return (state - 1) / 2147483646
    end
end

local function pick(rng, list) return list[floor(rng() * #list) + 1] end

-- ── members ───────────────────────────────────────────────────────────────────────────────────

local function rates(rng, role)
    local shape, out = ROLE_SHAPE[role] or ROLE_SHAPE.DAMAGER, {}
    for _, stat in ipairs(RATE_STATS) do
        out[stat] = BASE_RATE[stat] * shape[stat] * (0.8 + 0.4 * rng())
    end
    return out
end

local function newMember(w, guid, name, classFilename, role)
    local spec = CLASSES[classFilename] or CLASSES.WARRIOR
    local m = {
        guid = guid, name = name, classFilename = classFilename, role = role,
        specIconID = spec.specIconID, spells = spec.spells, rates = rates(w.rng, role),
    }
    w.known[guid] = m
    return m
end

local function attachPet(w, m, n)
    local guid = PET_GUID_FMT:format(n)
    m.pet = { guid = guid, name = PET_NAMES[m.classFilename] or "Pet", isPet = true, owner = m,
        spells = PET_SPELLS }
    w.known[guid] = m.pet
end

--- The role an invented mate plays: two tanks, four healers, the rest damage dealers.
local function poolRole(k)
    if k == 1 or k == 5 then return "TANK" end
    if k == 2 or (k >= 6 and k <= 8) then return "HEALER" end
    return "DAMAGER"
end

--- The fixed seeded order of invented mates, so a regroup of one seed keeps the same faces.
local function buildPool(w)
    local names = {}
    for i, n in ipairs(NAMES) do names[i] = n end
    for i = #names, 2, -1 do
        local j = floor(w.rng() * i) + 1
        names[i], names[j] = names[j], names[i]
    end
    local pool = {}
    for k = 1, #NAMES - 1 do
        local role = poolRole(k)
        local class = (k == 3 and "HUNTER") or (k == 4 and "WARLOCK") or pick(w.rng, BY_ROLE[role])
        local m = newMember(w, GUID_FMT:format(k), names[k], class, role)
        if CLASSES[class].hasPet then attachPet(w, m, k) end
        pool[k] = m
    end
    return pool
end

local VALID_ROLE = { TANK = true, HEALER = true, DAMAGER = true }

--- A new world. `player` is the real player, read by the caller inside NS.SimSeam:Live.
--- @param seed number
--- @param player table|nil  { guid, name, classFilename, role }
--- @return table  the world
function World.New(seed, player)
    player = player or {}
    local w = {
        rng = newRng(seed), group = { inGroup = false, inRaid = false, size = 0 }, zone = ZONES.dorn,
        combat = false, segments = {}, current = nil, recaps = {}, nextId = 1, pending = 0, known = {},
    }
    local class = CLASSES[player.classFilename] and player.classFilename or "WARRIOR"
    local role = VALID_ROLE[player.role] and player.role or "DAMAGER"
    local me = newMember(w, player.guid or GUID_FMT:format(0), player.name or "Player", class, role)
    me.isLocalPlayer = true
    me.classFilename = player.classFilename or class
    if CLASSES[class].hasPet then attachPet(w, me, 0) end
    w.player = me
    w.pool = buildPool(w)
    World.SetGroup(w, 1)
    return w
end

-- ── the group and the unit tokens ─────────────────────────────────────────────────────────────

local function bindUnit(units, token, m)
    units[token] = m
    if m.pet then units[token .. "pet"] = m.pet end
end

--- Members 1..n, the player first. `raid` gives raid1..n with the player at a seeded index.
function World.SetGroup(w, n, raid)
    n = math.max(1, math.min(floor(tonumber(n) or 1), #w.pool + 1))
    local members, units = { w.player }, {}
    for k = 1, n - 1 do members[k + 1] = w.pool[k] end
    bindUnit(units, "player", w.player)
    if n > 1 and raid then
        local at = floor(w.rng() * n) + 1
        local others = 1
        for i = 1, n do
            if i == at then bindUnit(units, "raid" .. i, w.player)
            else others = others + 1; bindUnit(units, "raid" .. i, members[others]) end
        end
    else
        for i = 2, n do bindUnit(units, "party" .. (i - 1), members[i]) end
    end
    w.members, w.units = members, units
    w.group = { inGroup = n > 1, inRaid = (n > 1 and raid) and true or false, size = n > 1 and n or 0 }
end

--- The member (or pet) a unit token names, or nil.
function World.Unit(w, token)
    return w.units[token]
end

function World.SetZone(w, key)
    w.zone = assert(ZONES[key], "SimWorld: unknown zone " .. tostring(key))
end

-- ── segments ──────────────────────────────────────────────────────────────────────────────────

local function nextId(w)
    local id = SIM_ID_BASE + w.nextId
    w.nextId = w.nextId + 1
    return id
end

--- Open a segment and make it the current one. `enemy` is { creatureID, name }.
function World.OpenSegment(w, name, enemy)
    local id = nextId(w)
    enemy = enemy or {}
    local seg = {
        sessionID = id, name = name or "Trash", duration = 0, totals = {}, deaths = {}, dead = {},
        enemy = { creatureID = enemy.creatureID or (200000 + id - SIM_ID_BASE), name = enemy.name or name or "Trash",
            total = 0 },
    }
    for _, stat in ipairs(RATE_STATS) do seg.totals[stat] = {} end
    table.insert(w.segments, 1, seg)
    w.current = seg
    return seg
end

--- Close the current segment; it stays what Current reads, as the client's does.
function World.CloseSegment(w)
    if w.current then w.current.closed = true end
end

local function add(bucket, guid, amount)
    bucket[guid] = (bucket[guid] or 0) + amount
end

local function tickMember(seg, m, seconds)
    for _, stat in ipairs(RATE_STATS) do add(seg.totals[stat], m.guid, m.rates[stat] * seconds) end
    local dealt = m.rates.DamageDone * seconds
    if m.pet then
        local petDealt = dealt * PET_SHARE
        add(seg.totals.DamageDone, m.pet.guid, petDealt)
        dealt = dealt + petDealt
    end
    return dealt
end

--- Grow every living member's numbers by rate x seconds; the enemy takes the group's damage.
function World.Tick(w, seconds)
    local seg = w.current
    if not seg or seg.closed then return end
    seconds = tonumber(seconds) or 0
    seg.duration = seg.duration + seconds
    local dealt = 0
    for _, m in ipairs(w.members) do
        if not seg.dead[m.guid] then dealt = dealt + tickMember(seg, m, seconds) end
    end
    seg.enemy.total = seg.enemy.total + dealt
end

--- The recap behind one death, in Aggregator.TestRecap's shape: events newest first.
local function buildRecap(seg)
    local maxHealth, hp, events = 650000, 650000, {}
    for i, spell in ipairs(ENEMY_SPELLS) do
        local amount = floor(maxHealth * (0.34 - (i - 1) * 0.03))
        events[i] = {
            spellId = spell.id, spellName = spell.name, sourceName = seg.enemy.name, amount = amount,
            currentHP = hp, event = "SPELL_DAMAGE",
            timestamp = CLOCK_BASE + seg.duration - (#ENEMY_SPELLS - i) * 1.5,
        }
        hp = hp - amount
        if hp < 0 then events[i].overkill, hp = -hp, 0 end
    end
    local newestFirst = {}
    for i = #events, 1, -1 do newestFirst[#newestFirst + 1] = events[i] end
    return { events = newestFirst, maxHealth = maxHealth }
end

--- One death in the current segment: a Deaths row and its recap. Answers the recap id.
function World.Die(w, guid)
    local seg = w.current
    if not seg or not w.known[guid] then return nil end
    local recapID = nextId(w)
    table.insert(seg.deaths, 1, { guid = guid, time = seg.duration, recapID = recapID })
    seg.dead[guid] = true
    w.recaps[recapID] = buildRecap(seg)
    return recapID
end

--- The meter reset: every segment and recap goes.
function World.ResetSegments(w)
    w.segments, w.current, w.recaps = {}, nil, {}
end

-- ── sessions (fresh tables on every call) ─────────────────────────────────────────────────────

local STAT_KEY
local function statKeyOf(statEnum)
    if not STAT_KEY then
        STAT_KEY = {}
        for key, value in pairs(NS.Constants.STAT_TYPE) do STAT_KEY[value] = key end
    end
    return STAT_KEY[statEnum]
end

local function displayType(name)
    local SDT = NS.Constants.SOURCE_DISPLAY_TYPE
    return SDT[name]
end

--- The segments a session reads: "current", "overall" or a simulated session id.
local function segmentsFor(w, which)
    if which == "current" then return w.current and { w.current } or nil end
    if which == "overall" then return (#w.segments > 0) and w.segments or nil end
    for _, seg in ipairs(w.segments) do
        if seg.sessionID == which then return { seg } end
    end
    return nil
end

local function durationOf(segs)
    local d = 0
    for _, seg in ipairs(segs) do d = d + seg.duration end
    return d
end

local function allyRow(w, guid, total, duration)
    local m = w.known[guid]
    return {
        sourceGUID = guid, name = m.name, classFilename = (not m.isPet) and m.classFilename or nil,
        specIconID = (not m.isPet) and m.specIconID or nil,
        isLocalPlayer = m.isLocalPlayer and true or false,
        totalAmount = total, amountPerSecond = duration > 0 and floor(total / duration) or 0,
        sourceDisplayType = displayType("Ally"),
    }
end

--- Per source, the sum of each segment's WHOLE amount: floored per segment, so Overall is exactly
--- the sum of the segments it spans, as the client's is.
local function sumBy(segs, statKey)
    local sums, order = {}, {}
    for _, seg in ipairs(segs) do
        for guid, amount in pairs(seg.totals[statKey]) do
            if sums[guid] == nil then order[#order + 1] = guid end
            sums[guid] = (sums[guid] or 0) + floor(amount)
        end
    end
    sort(order)
    return sums, order
end

local function allyRows(w, segs, statKey, duration)
    local sums, order = sumBy(segs, statKey)
    local rows = {}
    for _, guid in ipairs(order) do rows[#rows + 1] = allyRow(w, guid, floor(sums[guid]), duration) end
    return rows
end

local function deathRows(w, segs)
    local rows = {}
    for _, seg in ipairs(segs) do
        for _, d in ipairs(seg.deaths) do
            local row = allyRow(w, d.guid, 1, seg.duration)
            row.amountPerSecond, row.deathTimeSeconds, row.deathRecapID = 0, d.time, d.recapID
            rows[#rows + 1] = row
        end
    end
    return rows
end

local function enemyRows(segs, duration)
    -- Summed in plain locals: the rows are only written, never added to (tests/test_compat.lua's
    -- arithmetic scan reads every loaded file, and this one's numbers are all its own anyway).
    local order, sums, names = {}, {}, {}
    for _, seg in ipairs(segs) do
        local e = seg.enemy
        if sums[e.creatureID] == nil then order[#order + 1], names[e.creatureID] = e.creatureID, e.name end
        sums[e.creatureID] = (sums[e.creatureID] or 0) + floor(e.total)
    end
    local rows = {}
    for i, cid in ipairs(order) do
        local sum = sums[cid]
        rows[i] = { sourceCreatureID = cid, name = names[cid], totalAmount = sum,
            amountPerSecond = duration > 0 and floor(sum / duration) or 0, classification = "elite",
            sourceDisplayType = displayType("Enemy") }
    end
    return rows
end

--- Sort descending by totalAmount, ties kept in build order (table.sort is not stable).
local function sortDescending(rows)
    local rank = {}
    for i, row in ipairs(rows) do rank[row] = i end
    sort(rows, function(a, b)
        if a.totalAmount ~= b.totalAmount then return a.totalAmount > b.totalAmount end
        return rank[a] < rank[b]
    end)
    return rows
end

local function rowsFor(w, segs, statKey, duration)
    if statKey == "Deaths" then return deathRows(w, segs) end
    if statKey == "EnemyDamageTaken" then return enemyRows(segs, duration) end
    return allyRows(w, segs, statKey, duration)
end

--- One session for one stat, in the client's shape, built fresh.
--- @param which string|number  "current", "overall" or a simulated session id
--- @return table|nil  { combatSources, maxAmount, totalAmount, durationSeconds }
function World.Session(w, which, statEnum)
    local statKey = statKeyOf(statEnum)
    local segs = statKey and segmentsFor(w, which)
    if not segs then return nil end
    local duration = durationOf(segs)
    local rows = sortDescending(rowsFor(w, segs, statKey, duration))
    local total = 0
    for _, row in ipairs(rows) do total = total + row.totalAmount end
    return {
        combatSources = rows, maxAmount = rows[1] and rows[1].totalAmount or 0, totalAmount = total,
        durationSeconds = duration,
    }
end

local function spellsOf(m, statKey)
    if INCOMING[statKey] then
        return { ENEMY_SPELLS[1].id, ENEMY_SPELLS[2].id, ENEMY_SPELLS[3].id }
    end
    return m.spells
end

--- One source's spell breakdown, or nil for an enemy, a death row or a source the session lacks.
function World.SourceDetail(w, which, statEnum, guid)
    local statKey = statKeyOf(statEnum)
    local segs = statKey and BASE_RATE[statKey] and guid and w.known[guid] and segmentsFor(w, which)
    if not segs then return nil end
    local sums = sumBy(segs, statKey)
    local total = sums[guid] and floor(sums[guid])
    if not total then return nil end
    local duration, spells, left = durationOf(segs), {}, total
    for i, id in ipairs(spellsOf(w.known[guid], statKey)) do
        local amount = (i == #SPELL_SHARE) and left or floor(total * SPELL_SHARE[i])
        left = left - amount
        spells[i] = { spellID = id, totalAmount = amount,
            amountPerSecond = duration > 0 and floor(amount / duration) or 0 }
    end
    return { combatSpells = spells, maxAmount = spells[1].totalAmount, totalAmount = total }
end

--- The segments the client would list, newest first.
function World.AvailableSessions(w)
    local out = {}
    for i, seg in ipairs(w.segments) do
        out[i] = { sessionID = seg.sessionID, name = seg.name, durationSeconds = seg.duration }
    end
    return out
end

local function copyEvents(events)
    local out = {}
    for i, e in ipairs(events) do
        local c = {}
        for k, v in pairs(e) do c[k] = v end
        out[i] = c
    end
    return out
end

-- ── providers ─────────────────────────────────────────────────────────────────────────────────

local function sessionWhich(sessionType)
    local ST = NS.Constants.SESSION_TYPE
    if sessionType == ST.Current then return "current" end
    if sessionType == ST.Overall then return "overall" end
    return nil
end

local function unitField(field)
    return function(w, token)
        local m = World.Unit(w, token)
        return m and m[field] or nil
    end
end

local ANSWERS = {
    IsDamageMeterAvailable = function() return true, nil end,
    GetCombatSessionFromType = function(w, sessionType, statEnum)
        local which = sessionWhich(sessionType)
        return which and World.Session(w, which, statEnum) or nil
    end,
    GetCombatSessionFromID = function(w, id, statEnum)
        if type(id) ~= "number" then return nil end
        return World.Session(w, id, statEnum)
    end,
    GetCombatSessionSourceFromType = function(w, sessionType, statEnum, guid)
        local which = sessionWhich(sessionType)
        return which and World.SourceDetail(w, which, statEnum, guid) or nil
    end,
    GetCombatSessionSourceFromID = function(w, id, statEnum, guid)
        if type(id) ~= "number" then return nil end
        return World.SourceDetail(w, id, statEnum, guid)
    end,
    GetAvailableCombatSessions = function(w) return World.AvailableSessions(w) end,
    GetSessionDurationSeconds = function(w, sessionType)
        local which = sessionWhich(sessionType)
        local segs = which and segmentsFor(w, which)
        return segs and durationOf(segs) or nil
    end,
    HasDeathRecap = function() return true end,
    HasRecapEvents = function(w, id) return w.recaps[id] ~= nil end,
    GetRecapEvents = function(w, id)
        local r = w.recaps[id]
        return r and copyEvents(r.events) or nil
    end,
    GetRecapMaxHealth = function(w, id)
        local r = w.recaps[id]
        return r and r.maxHealth or nil
    end,
    UnitGUID = unitField("guid"),
    UnitName = unitField("name"),
    UnitExists = function(w, token) return World.Unit(w, token) ~= nil end,
    UnitClass = function(w, token)
        local m = World.Unit(w, token)
        if not m or m.isPet then return nil end
        local spec = CLASSES[m.classFilename]
        return spec and spec.name or m.classFilename, m.classFilename
    end,
    UnitGroupRolesAssigned = function(w, token)
        local m = World.Unit(w, token)
        if not m or m.isPet or not w.group.inGroup then return "NONE" end
        return m.role
    end,
    GetNumGroupMembers = function(w) return w.group.size end,
    IsInRaid = function(w) return w.group.inRaid end,
    IsInGroup = function(w) return w.group.inGroup end,
    IsInInstance = function(w) return w.zone[1], w.zone[2] end,
    IsInDelve = function() return false end,
    UnitAffectingCombat = function(w, token)
        return (w.combat and World.Unit(w, token) ~= nil) and true or false
    end,
}

--- The keys this file answers, sorted. Every wrapped NS.Compat key that is not guarded is here.
World.PROVIDED = {}
--- key -> provider(fallback, ...), as registered on the seam.
World.PROVIDERS = {}

for key, answer in pairs(ANSWERS) do
    World.PROVIDED[#World.PROVIDED + 1] = key
    World.PROVIDERS[key] = function(fallback, ...)
        local w = NS.SimHost.world
        if not w then return fallback(...) end
        return answer(w, ...)
    end
end
sort(World.PROVIDED)

for _, key in ipairs(World.PROVIDED) do
    NS.SimSeam:SetProvider(key, World.PROVIDERS[key])
end
