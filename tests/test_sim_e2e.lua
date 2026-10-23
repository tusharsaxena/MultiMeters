-- tests/test_sim_e2e.lua — the four /mm sim scenarios end to end (modules/SimScenario.lua).
--
-- MM-16 (MultiMeters#60). Every scenario runs twice on a fresh, enabled instance, through the host's
-- REAL refusal and prepare:
--
--   * STEPPED: the member NS.Sim:Start{ scenario, seed } (it arms nothing: LibKa0s v1.76.0's
--     auto-run contract), then NS.Sim:Step() per step, the kit clock advanced only to drain a fight's
--     booked ticks, so the gate opens for the next step.
--   * AUTO-RUN: the typed NS.Sim:RunVerb("start <name>"), which arms the run, then the clock moved
--     1 s at a time until the run has FINISHED and the last fight has drained.
--
-- Both runs take the same observation after every step: the engine's own output, read through
-- NS.Aggregator.Build(windowCfg), Provider.GetAvailableSessions, Visibility.GetContext and
-- Roster.GetGroup. The auto-run observes step i just before step i+1 plays (the gate has opened,
-- so step i's fight has ended) by wrapping NS.SimHost.Play, and the last step after the drain.
-- The same assertions then run over both runs' observations.
--
-- Cross-cutting, in every run: no call reaches the mock's C_DamageMeter while the session runs; an
-- Export.Send(lines, "RAID") mid-run prints `[sim] RAID` lines and sends nothing; the
-- SavedVariables snapshot is byte-identical after the stop; Build answers from the mock's live
-- meter again after it; and NS.SimSeam:Unwrapped() is empty.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local S = dofile((T.root or ".") .. "/tests/sim_support.lua")

local LIVE_DAMAGE = 4242

-- ── the window the engine is read through ─────────────────────────────────────────────────────

local function windowCfg(ns, which, sessionID)
    local ST = ns.Constants.SESSION_TYPE
    local columns = {}
    for _, key in ipairs({ "DamageDone", "DamageTaken", "Deaths" }) do
        columns[#columns + 1] = { stat = key, width = 80, showBar = true }
    end
    return {
        id = 1, name = "E2E", columns = columns, rows = {},
        data = { sessionType = which == "overall" and ST.Overall or ST.Current, sessionID = sessionID,
            sortMode = "value", sortColumn = "DamageDone" },
    }
end

local function cell(row, key)
    local c = row.values and row.values[key]
    return c and c.total or 0
end

--- One Build, flattened to plain data.
local function grid(ns, which, sessionID)
    local result = ns.Aggregator.Build(windowCfg(ns, which, sessionID))
    local out = { reason = result.reason, ddTotal = result.columnTotals and result.columnTotals.DamageDone,
        rows = {} }
    for i, row in ipairs(result) do
        out.rows[i] = { guid = row.guid, isPet = row.isPet and true or false, dd = cell(row, "DamageDone"),
            dt = cell(row, "DamageTaken"), deaths = cell(row, "Deaths"), recapID = row.deathRecapID,
            isPlayer = row.isLocalPlayer and true or false, owner = row.ownerGuid }
    end
    return out
end

--- What the engine shows after a step.
local function observe(inst, pos)
    local ns = inst.NS
    -- The session's roster store as the step left it, read before GetGroup can refill it.
    local live = ns.Sim:Session()
    local store = live and live.mmRoster
    local storeCount = store and store.count or 0
    local group = ns.Roster.GetGroup()
    local roster = {}
    for i, m in ipairs(group) do roster[i] = m.guid end
    local sessions = {}
    for i, s in ipairs(ns.Provider.GetAvailableSessions()) do sessions[i] = { id = s.sessionID, name = s.name } end
    local o = {
        pos = pos, roster = roster, firstIsPlayer = group[1] and group[1].isPlayer and true or false,
        context = ns.Visibility.GetContext(), sessions = sessions,
        current = grid(ns, "current"), overall = grid(ns, "overall"), bySegment = {},
        shown = ns.WindowManager.All()[1]:IsShown(),
    }
    for _, s in ipairs(sessions) do o.bySegment[s.id] = grid(ns, "current", s.id) end
    local session = ns.Sim:Session()
    o.mmRosterCount = session and session.mmRoster and session.mmRoster.count or 0
    o.mmRosterStore, o.mmRosterStoreCount = store, storeCount
    o.world = ns.SimHost.world
    return o
end

-- ── the cross-cutting harness ─────────────────────────────────────────────────────────────────

local function meterCalls(m)
    local n = 0
    for _, c in pairs(m.__meter.calls) do n = n + c end
    return n
end

local function chatSince(inst, from)
    local out = {}
    for i = from + 1, #inst.mocks.__chat do out[#out + 1] = tostring(inst.mocks.__chat[i]) end
    return table.concat(out, "\n")
end

--- A fresh enabled instance with a live meter holding one row, and the chat sends counted.
local function fresh()
    local inst = T.load{ enable = true }
    local m = inst.mocks
    local ST = inst.NS.Constants.SESSION_TYPE
    m.setSession(ST.Current, "*", { combatSources = { { sourceGUID = m.UnitGUID("player"), name = "Live",
        classFilename = "MAGE", isLocalPlayer = true, totalAmount = LIVE_DAMAGE, amountPerSecond = 1 } },
        maxAmount = LIVE_DAMAGE, totalAmount = LIVE_DAMAGE, durationSeconds = 10 })
    inst.sends = 0
    local function count() inst.sends = inst.sends + 1 end
    m.SendChatMessage = count
    m.C_ChatInfo = { SendChatMessage = count }
    return inst
end

--- Everything a run needs set before the snapshot, per scenario.
local SETUP = {
    zone = function(inst)
        -- The window hides in the open world (the instance-type rule): Visibility's `world` context.
        inst.NS.SetByPath("window.visibility.world", false, 1)
    end,
}

--- The live baseline both runs share: the real roster remembered, the snapshot taken.
local function begin(inst, name)
    if SETUP[name] then SETUP[name](inst) end
    inst.NS.Roster.GetGroup()
    inst.before = S.snapshot(inst.NS)
    inst.globalRoster = S.snapshot({ db = { profile = {}, global = { roster = inst.NS.db.global.roster } } })
    inst.mocks.resetMeterCalls()
    inst.chatFrom = #inst.mocks.__chat
end

local EXPORT_AT = 2
local MID   -- per scenario, filled below

--- The mid-run export, sent while step EXPORT_AT's world is shown.
local function export(inst)
    inst.NS.Export.Send({ "Multi Meters: Damage Done", "1. Someone 1.2M" }, "RAID")
end

--- After the stop: every cross-cutting claim.
local function finishRun(inst, name, mode)
    local ns, m = inst.NS, inst.mocks
    local tag = name .. "/" .. mode .. ": "
    assertEqual(meterCalls(m), 0, tag .. "the session reached the mock's C_DamageMeter")
    local chat = chatSince(inst, inst.chatFrom)
    local _, simLines = chat:gsub("%[sim%] RAID", "")
    assertEqual(simLines, 2, tag .. "the export's lines were not printed as [sim] RAID: " .. chat)
    assertEqual(inst.sends, 0, tag .. "the export reached the client's chat send")
    ns.Sim:Stop()
    assertEqual(S.snapshot(ns), inst.before, tag .. "the session changed SavedVariables")
    if SETUP[name] then ns.SetByPath("window.visibility.world", true, 1) end
    local after = grid(ns, "current")
    assertEqual(#after.rows, 1, tag .. "the live meter is not what Build reads after the stop")
    assertEqual(after.rows[1].dd, LIVE_DAMAGE, tag .. "the live meter's number did not come back")
    assertTrue(meterCalls(m) > 0, tag .. "the stop did not go back to the live meter")
    assertEqual(next(ns.SimSeam:Unwrapped()), nil, tag .. "a Compat key escaped the seam")
end

-- ── the two runs ──────────────────────────────────────────────────────────────────────────────

local SEED = 7

--- Drain the booked fight ticks so the gate opens.
local function drain(inst, clock)
    local w = inst.NS.SimHost.world
    local guard = 0
    while w and (w.pending or 0) > 0 and guard < 200 do
        clock.advance(inst.NS.SimHost.Drivers.TICK)
        guard = guard + 1
    end
end

--- STEPPED: the member start (nothing plays), then Step per step.
local function stepped(name)
    local inst = fresh()
    local ns = inst.NS
    inst.mid = MID[name]
    begin(inst, name)
    local clock = S.clock(inst.mocks)
    local ok, line = ns.Sim:Start{ scenario = name, seed = SEED }
    assertTrue(ok, "the stepped start was refused: " .. tostring(line))
    clock.advance(1)
    assertEqual(ns.Sim:Status().pos, 0, "the member start played a step (LK-01: it arms nothing)")
    local obs, total = {}, #ns.Sim:Steps()
    for i = 1, total do
        local step, code = ns.Sim:Step()
        assertTrue(step ~= nil, ("%s step %d did not play: %s"):format(name, i, tostring(code)))
        drain(inst, clock)
        obs[i] = observe(inst, i)
        if i == EXPORT_AT then export(inst) end
        if inst.mid and inst.mid[i] then inst.mid[i](inst, obs[i]) end
    end
    clock.advance(2)
    return inst, obs
end

--- AUTO-RUN: the typed start arms the run; the clock moves 1 s at a time to the end.
local function autoRun(name)
    local inst = fresh()
    local ns = inst.NS
    inst.mid = MID[name]
    begin(inst, name)
    local clock = S.clock(inst.mocks)
    local Host = ns.SimHost
    local real = Host.Play
    local obs, errors = {}, {}
    Host.Play = function(step, session)
        local pos = ns.Sim:Status().pos
        -- pos is already this step's index: the one before it has ended (the gate is open).
        if pos > 1 then
            local okObs, err = pcall(function()
                obs[pos - 1] = observe(inst, pos - 1)
                if pos - 1 == EXPORT_AT then export(inst) end
                if inst.mid and inst.mid[pos - 1] then inst.mid[pos - 1](inst, obs[pos - 1]) end
            end)
            if not okObs then errors[#errors + 1] = tostring(err) end
        end
        return real(step, session)
    end
    local ok = ns.Sim:RunVerb("start " .. name)
    assertTrue(ok, "the typed start was refused")
    local total, guard = #ns.Sim:Steps(), 0
    while (ns.Sim:Status().pos < total or (Host.world and Host.world.pending or 0) > 0) and guard < 300 do
        clock.advance(1)
        guard = guard + 1
    end
    Host.Play = real
    assertEqual(#errors, 0, table.concat(errors, "\n"))
    assertEqual(ns.Sim:Status().pos, total, name .. ": the auto-run did not finish")
    assertFalse(ns.Sim:Status().playing, name .. ": the auto-run is still playing")
    obs[total] = observe(inst, total)
    if inst.mid and inst.mid[total] then inst.mid[total](inst, obs[total]) end
    clock.advance(2)
    return inst, obs
end

-- ── the shared assertions ─────────────────────────────────────────────────────────────────────

local function sum(rows, key)
    local n = 0
    for _, r in ipairs(rows) do n = n + r[key] end
    return n
end

--- The member rows: with Merge pets off (the shipped default) a pet has its own row, owned by
--- its member, so a grid is the members plus their pets.
local function members(g)
    local out = {}
    for _, r in ipairs(g.rows) do if not r.isPet then out[#out + 1] = r end end
    return out
end

--- Every pet row is owned by a member row of the same grid.
local function assertPetsOwned(g, tag)
    local byGuid = {}
    for _, r in ipairs(g.rows) do byGuid[r.guid] = r end
    for _, r in ipairs(g.rows) do
        if r.isPet then
            assertTrue(r.owner ~= nil and byGuid[r.owner] ~= nil and not byGuid[r.owner].isPet,
                tag .. ": a pet row has no member owner")
        end
    end
end

local function assertDescending(rows, tag)
    for i = 2, #rows do
        assertTrue(rows[i - 1].dd >= rows[i].dd, tag .. ": rows are not sorted descending by DamageDone")
    end
end

local function assertGroup(o, n, tag)
    assertEqual(#o.roster, n, tag .. ": roster size")
    assertTrue(o.firstIsPlayer, tag .. ": the player is not first")
    assertEqual(o.roster[1], o.world.player.guid, tag .. ": the first member is not the player")
end

local function memberOf(o, role)
    for _, m in ipairs(o.world.members) do
        if m.role == role then return m end
    end
end

local function rowOf(g, guid)
    for _, r in ipairs(g.rows) do if r.guid == guid then return r end end
end

local CHECK = {}

CHECK.dungeon = function(obs, tag)
    assertGroup(obs[1], 5, tag)
    assertEqual(obs[2].context, "dungeon", tag .. ": context after the zone step")
    local trash = obs[3]
    assertEqual(#trash.sessions, 1, tag .. ": segments after the trash")
    assertEqual(trash.sessions[1].name, "Trash")
    assertEqual(#members(trash.current), 5, tag .. ": Current member rows after the trash")
    assertPetsOwned(trash.current, tag)
    assertDescending(trash.current.rows, tag)
    assertEqual(trash.current.ddTotal, sum(trash.current.rows, "dd"), tag .. ": columnTotals.DamageDone")
    local boss = obs[4]
    assertEqual(#boss.sessions, 2, tag .. ": segments after the boss")
    assertEqual(boss.sessions[1].name, "Speaker Shadowcrown", tag .. ": newest first")
    assertEqual(boss.sessions[2].name, "Trash")
    local a, b = boss.bySegment[boss.sessions[1].id], boss.bySegment[boss.sessions[2].id]
    assertEqual(boss.overall.ddTotal, a.ddTotal + b.ddTotal, tag .. ": Overall is the two segments' sum")
    local dead = boss.world.segments[1].deaths
    assertEqual(#dead, 1, tag .. ": one boss death")
    local row = rowOf(a, dead[1].guid)
    assertEqual(boss.world.known[dead[1].guid].role, "DAMAGER", tag .. ": the boss death is a damage dealer")
    assertEqual(row.deaths, 1, tag .. ": the dead member's Deaths cell")
    assertTrue(dead[1].recapID ~= nil, tag .. ": the world's death carries no recap id")
    assertEqual(row.recapID, dead[1].recapID, tag .. ": the dead member's row lost its deathRecapID")
    assertEqual(boss.recapRowID, row.recapID, tag .. ": GetRecap was not called with the row's id")
    local recap = boss.recap
    assertTrue(type(recap) == "table" and recap.events and #recap.events > 0,
        tag .. ": Provider.GetRecap answers no events for the death")
    local tank = memberOf(boss, "TANK")
    local topDt, top = -1, nil
    for _, r in ipairs(a.rows) do if r.dt > topDt then topDt, top = r.dt, r.guid end end
    assertEqual(top, tank.guid, tag .. ": the tank does not top DamageTaken")
end

CHECK.raid = function(obs, tag)
    assertGroup(obs[1], 20, tag)
    assertEqual(obs[2].context, "raid", tag .. ": context after the zone step")
    local o = obs[3]
    assertEqual(#members(o.current), 20, tag .. ": a 20-member grid")
    assertTrue(#o.current.rows < 40, tag .. ": the grid hit MAX_ROWS")
    assertPetsOwned(o.current, tag)
    local seen, players = {}, 0
    for _, r in ipairs(o.current.rows) do
        assertFalse(seen[r.guid], tag .. ": a duplicate row " .. tostring(r.guid))
        seen[r.guid] = true
        if r.isPlayer then players = players + 1 end
    end
    assertEqual(players, 1, tag .. ": the player has exactly one row")
    assertEqual(#o.world.segments[1].deaths, 2, tag .. ": two deaths")
    -- Merge pets on (set for the case in `mid`, then restored): the owner's cell includes the pet's.
    -- Merge pets off: the hunter pet's damage is not in its owner's cell; it is its own pet row.
    local hunter = o.world.pool[3]
    local alone = rowOf(o.current, hunter.guid)
    local petRow = rowOf(o.current, hunter.pet.guid)
    local petDamage = math.floor(o.world.segments[1].totals.DamageDone[hunter.pet.guid] or 0)
    assertTrue(petDamage > 0, tag .. ": the hunter pet dealt nothing")
    assertEqual(alone.dd, math.floor(o.world.segments[1].totals.DamageDone[hunter.guid]),
        tag .. ": the owner's cell carries the pet's damage with Merge pets off")
    assertTrue(petRow ~= nil and petRow.isPet and petRow.owner == hunter.guid, tag .. ": no owned pet row")
    -- Merge pets on: no pet row, and the owner's cell includes the pet's.
    for _, r in ipairs(o.merged.rows) do assertFalse(r.isPet, tag .. ": a pet row with Merge pets on") end
    assertEqual(#o.merged.rows, 20, tag .. ": the merged grid is the 20 members")
    assertEqual(rowOf(o.merged, hunter.guid).dd, alone.dd + petDamage, tag .. ": the owner's merged cell")
end

CHECK.wipe = function(obs, tag)
    assertGroup(obs[1], 5, tag)
    local wipe = obs[3]
    assertEqual(wipe.sessions[1].name, "Speaker Shadowcrown (wipe)")
    assertEqual(#members(wipe.current), 5)
    for _, r in ipairs(members(wipe.current)) do
        assertEqual(r.deaths, 1, tag .. ": a member's Deaths after the wipe")
    end
    local reset = obs[4]
    assertEqual(#reset.sessions, 0, tag .. ": GetAvailableSessions after the reset")
    assertEqual(reset.current.reason, "no session", tag .. ": the Current window's reason after the reset")
    assertEqual(#reset.current.rows, 0)
    assertTrue(wipe.mmRosterStore ~= nil and wipe.mmRosterStoreCount == 5, tag .. ": no session roster before the reset")
    assertTrue(reset.mmRosterStore ~= wipe.mmRosterStore, tag .. ": the reset kept the session's roster store")
    assertEqual(reset.mmRosterStoreCount, 0, tag .. ": the session roster was not emptied by the reset")
    assertEqual(reset.mmRosterCount, 5, tag .. ": the session roster was not rebuilt after the reset")
    assertEqual(reset.globalRoster, reset.globalBefore, tag .. ": the reset touched db.global.roster")
    local repull = obs[5]
    assertEqual(#repull.sessions, 1, tag .. ": segments after the re-pull")
    assertEqual(repull.sessions[1].name, "Trash")
end

CHECK.zone = function(obs, tag)
    assertGroup(obs[1], 5, tag)
    assertEqual(obs[2].context, "dungeon")
    assertTrue(obs[2].shown, tag .. ": the window is hidden in The Rookery")
    assertEqual(#obs[3].sessions, 1)
    assertEqual(obs[4].context, "world", tag .. ": context at the Isle of Dorn")
    assertFalse(obs[4].shown, tag .. ": the window set to hide in the world still shows at the Isle of Dorn")
    assertEqual(obs[5].context, "dungeon", tag .. ": context in the Priory")
    assertTrue(obs[5].shown, tag .. ": the window did not come back in the Priory")
    local last = obs[6]
    assertEqual(#last.sessions, 2, tag .. ": two segments")
    assertTrue(last.sessions[1].id ~= last.sessions[2].id, tag .. ": the segments share an id")
end

--- Per scenario, work done right after a step's observation (both runs).
MID = {
    dungeon = {
        [4] = function(inst, o)
            -- The recap id comes from the engine's row (what SM-MM-29's tooltip reads), not the world.
            local dead = o.world.segments[1].deaths[1]
            local row = dead and o.sessions[1] and rowOf(o.bySegment[o.sessions[1].id], dead.guid)
            o.recapRowID = row and row.recapID
            o.recap = o.recapRowID and inst.NS.Provider.GetRecap(o.recapRowID)
        end,
    },
    raid = {
        [3] = function(inst, o)
            local ns = inst.NS
            local data = ns.db.profile.data
            local raw = rawget(data, "mergePets")
            ns.SetByPath("data.mergePets", true)
            o.merged = grid(ns, "current")
            ns.SetByPath("data.mergePets", false)
            rawset(data, "mergePets", raw)
        end,
    },
    wipe = {
        [4] = function(inst, o)
            o.globalBefore = inst.globalRoster
            o.globalRoster = S.snapshot({ db = { profile = {}, global = { roster = inst.NS.db.global.roster } } })
        end,
    },
}

local NAMES = { "dungeon", "raid", "wipe", "zone" }

test("Sim e2e: SimScenario lists the four #60 scenarios, each with labeled, tipped steps", function()
    local inst = T.load{ enable = true }
    local SC = inst.NS.SimHost.SCENARIOS
    for i, name in ipairs(NAMES) do
        assertEqual(SC.names[i], name)
        local def = SC.defs[name]
        assertTrue(type(def.label) == "string" and def.label ~= "", name .. " has no label")
        assertEqual(def.sizes, nil, name .. " declares sizes")
        for _, step in ipairs(def.timeline(def, { scenario = name, seed = 1 })) do
            assertTrue(type(step.label) == "string" and step.label ~= "", name .. ": a step has no label")
            assertTrue(type(step.tip) == "table" and #step.tip > 0, name .. ": a step has no tip")
            assertTrue(inst.NS.SimHost.PLAY[step.kind] ~= nil, name .. ": no play for " .. tostring(step.kind))
        end
    end
    local def = SC.defs.dungeon
    assertTrue(def.timeline(def, {}) [1] ~= def.timeline(def, {})[1], "the timeline reuses its step tables")
end)

for _, name in ipairs(NAMES) do
    for _, mode in ipairs({ "step", "run" }) do
        test(("Sim e2e: %s by %s"):format(name, mode), function()
            local runner = mode == "step" and stepped or autoRun
            local inst, obs = runner(name)
            CHECK[name](obs, name .. "/" .. mode)
            finishRun(inst, name, mode)
        end)
    end
end

test("Sim e2e: the panel's rows are the step labels, and a step waits while the gate is closed", function()
    local inst = fresh()
    local ns = inst.NS
    local clock = S.clock(inst.mocks)
    assertTrue(ns.Sim:Start{ scenario = "dungeon", seed = SEED }, "the start was refused")
    clock.advance(1)
    local steps = ns.Sim:Steps()
    local rows = ns.Sim:PanelRows()
    assertEqual(#rows, #steps + 2, "Start, one row per step, Stop")
    for i, step in ipairs(steps) do assertEqual(rows[i + 1].label, step.label, "panel row " .. i) end
    ns.Sim:Step()
    ns.Sim:Step()
    ns.Sim:Step()   -- the trash pull: its ticks are booked, the gate is closed
    assertTrue(ns.SimHost.world.pending > 0, "the trash booked no ticks")
    local from = #inst.mocks.__chat
    local ok, code = ns.Sim:RunVerb("step")
    assertFalse(ok, "a step played while the fight ran")
    assertEqual(code, "settling")
    assertEqual(ns.Sim:Status().pos, 3, "the click-ahead advanced past a closed gate")
    assertTrue(chatSince(inst, from):find("The fight is still running.", 1, true) ~= nil, "no gate line")
    drain(inst, clock)
    assertTrue(ns.Sim:RunVerb("step"), "the step did not play once the gate opened")
    assertEqual(ns.Sim:Status().pos, 4)
    ns.Sim:Stop()
end)
