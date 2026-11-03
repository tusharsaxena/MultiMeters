local _, NS = ...
-- modules/SimScenario.lua — the simulator's four scenarios, their steps and how each step plays
-- (MultiMeters#60; Ka0sAddonsCommonTasks docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/inputs/design-mm-sim.md §2.7).
--
-- WHAT IT FILLS. modules/Sim.lua builds NS.Sim with NS.SimHost.SCENARIOS and hands the library
-- `play = Host.Play`, read at call time. This file fills both IN PLACE when it loads, which is the
-- LOAD-BEARING note on its TOC line: it loads after modules/SimDrivers.lua, whose Drivers table it
-- captures at file scope.
--
-- A SCENARIO is `{ label, timeline = function(def, opts) return steps end }`, with no `sizes`: the
-- issue fixes the group sizes (5 and 20). The timeline builds FRESH step tables on every call,
-- because the library stamps ranAt, detail and index onto the steps of the run it plays; the
-- fight tables the steps carry are shared, which is safe because the drivers keep the tick
-- counter on the world (modules/SimDrivers.lua's header).
--
-- A STEP is `{ kind, label, tip, ... }`. The label is localized, and the tip (the step panel's
-- tooltip, modules/Sim.lua's P.stepTip) names the events the step fires and what the world holds
-- once it has run. PLAY[kind](step, session) calls the drivers and answers the step's detail.
--
-- NO DRIVER WORK HERE. Every world edit and every event is a driver's (one rule per driver); this
-- file only says which drivers run, in which order, with which fight.

NS.SimHost = NS.SimHost or {}
local Host = NS.SimHost
local L = NS.L

local D = assert(Host.Drivers, "modules/SimScenario.lua loads after modules/SimDrivers.lua")
local World = assert(Host.World, "modules/SimScenario.lua loads after modules/SimWorld.lua")

-- ── the fights ────────────────────────────────────────────────────────────────────────────────
--
-- modules/SimDrivers.lua's fight shape: { name, enemy, ticks, secondsPerTick, ends, deaths }.
-- A death names a role (the first living mate of that role, never the player), or `all`.
--
-- WALL TIME (R4-MM1, Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND4). Every fight plays for
-- FIGHT_SECONDS of wall time: the pull and tick 1 at once, then a tick every D.TICK, so TICKS =
-- FIGHT_SECONDS / D.TICK + 1 (21: two meter updates a second). The host's gate holds the next step
-- until the last tick, so a playing fight step lasts max(sim.stepDelay, FIGHT_SECONDS), and the
-- slider tops out at FIGHT_SECONDS (modules/Sim.lua's STEP_DELAY_MAX). secondsPerTick is the
-- SIMULATED time each tick adds, picked so each segment models about what it did before the fights
-- were stretched (trash about 20 s, the dungeon boss about 3 minutes, the raid boss about 5), and the
-- deaths sit at the same point of the fight as they did over the old tick counts.

Host.FIGHT_SECONDS = 10
local TICKS = math.floor(Host.FIGHT_SECONDS / D.TICK + 0.5) + 1

local SHADOWCROWN = { creatureID = 211290, name = "Speaker Shadowcrown" }
local VEXIE = { creatureID = 225821, name = "Vexie and the Geargrinders" }

local FIGHTS = {
    dungeonTrash = { name = "Trash", ticks = TICKS, secondsPerTick = 1, ends = true },
    dungeonBoss = { name = SHADOWCROWN.name, enemy = SHADOWCROWN, ticks = TICKS, secondsPerTick = 9, ends = true,
        deaths = { { tick = 15, role = "DAMAGER" } } },
    raidBoss = { name = VEXIE.name, enemy = VEXIE, ticks = TICKS, secondsPerTick = 15, ends = true,
        deaths = { { tick = 11, role = "DAMAGER" }, { tick = 16, role = "HEALER" } } },
    -- Everyone dies once by the last tick: a damage dealer, then a healer, then the rest together.
    wipeBoss = { name = SHADOWCROWN.name .. " (wipe)", enemy = SHADOWCROWN, ticks = TICKS, secondsPerTick = 6,
        ends = true, deaths = { { tick = 13, role = "DAMAGER" }, { tick = 16, role = "HEALER" },
            { tick = TICKS, all = true } } },
    wipeRepull = { name = "Trash", ticks = TICKS, secondsPerTick = 1, ends = true },
    zoneTrash = { name = "Trash", ticks = TICKS, secondsPerTick = 1, ends = true },
}
Host.FIGHTS = FIGHTS

-- ── the steps ─────────────────────────────────────────────────────────────────────────────────

local FIRES, HOLDS = L["Fires"], L["World"]

local function form(n, raid)
    local label = raid and L["Form a %d-player raid"] or L["Form a %d-player group"]
    return { kind = "form", size = n, raid = raid and true or false, label = label:format(n), tip = {
        { FIRES, "GROUP_ROSTER_UPDATE" },
        { HOLDS, L["%d members, you first"]:format(n) },
    } }
end

local function zone(key)
    local z = World.ZONES[key]
    local inside = z[1]
    local label = inside and L["Enter %s"] or L["Leave to %s (open world)"]
    return { kind = "zone", zone = key, label = label:format(z[3]), tip = {
        { FIRES, "PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA" },
        { HOLDS, inside and L["inside %s (%s)"]:format(z[3], z[2]) or L["the open world (%s)"]:format(z[3]) },
    } }
end

local function deathsOf(fight)
    local n = 0
    for _, death in ipairs(fight.deaths or {}) do
        if death.all then return L["everyone dies"] end
        n = n + 1
    end
    return n == 0 and L["no deaths"] or L["%d deaths"]:format(n)
end

--- The fight step. The label shows the step's wall duration ("Pull Trash (10 s)"); the tip says
--- how the ticks map to the segment's simulated length.
local function fight(f)
    local wall = math.floor((f.ticks - 1) * D.TICK + 0.5)
    return { kind = "fight", fight = f, label = L["Pull %s (%d s)"]:format(f.name, wall), tip = {
            { L["Plays"], L["%d meter ticks in %d s, a %d s fight"]:format(f.ticks, wall, f.ticks * f.secondsPerTick) },
            { FIRES, "PLAYER_REGEN_DISABLED, DAMAGE_METER_CURRENT_SESSION_UPDATED" },
            { L["Ends with"], "PLAYER_REGEN_ENABLED, DAMAGE_METER_COMBAT_SESSION_UPDATED" },
            { HOLDS, L["a new segment, %s; %s"]:format(f.name, deathsOf(f)) },
        } }
end

local function reset()
    return { kind = "reset", label = L["Reset meter data"], tip = {
        { FIRES, "DAMAGE_METER_RESET" },
        { HOLDS, L["no segments; Blizzard's own meter is not touched"] },
    } }
end

-- ── how a step plays ──────────────────────────────────────────────────────────────────────────

local PLAY = {
    form = function(step)
        D.FormGroup(step.size, step.raid)
        return L["%d members"]:format(step.size)
    end,
    zone = function(step)
        D.Zone(step.zone)
        return World.ZONES[step.zone][3]
    end,
    fight = function(step, session) return D.Fight(step.fight, session) end,
    reset = function()
        D.Reset()
        return L["segments cleared"]
    end,
}
Host.PLAY = PLAY

--- The descriptor's play: the step's driver work, answering its detail line.
function Host.Play(step, session)
    local play = type(step) == "table" and PLAY[step.kind]
    if not play then error("SimScenario: no play for step kind " .. tostring(step and step.kind)) end
    return play(step, session)
end

-- ── the scenarios ─────────────────────────────────────────────────────────────────────────────

local DEFS = {
    dungeon = { label = L["Dungeon: pull and boss (5)"], timeline = function()
        return { form(5), zone("rookery"), fight(FIGHTS.dungeonTrash), fight(FIGHTS.dungeonBoss) }
    end },
    raid = { label = L["Raid boss (20)"], timeline = function()
        return { form(20, true), zone("undermine"), fight(FIGHTS.raidBoss) }
    end },
    wipe = { label = L["Wipe and reset (5)"], timeline = function()
        return { form(5), zone("rookery"), fight(FIGHTS.wipeBoss), reset(), fight(FIGHTS.wipeRepull) }
    end },
    zone = { label = L["Zone change between segments (5)"], timeline = function()
        return { form(5), zone("rookery"), fight(FIGHTS.zoneTrash), zone("dorn"), zone("priory"),
            fight(FIGHTS.zoneTrash) }
    end },
}

local SC = Host.SCENARIOS
for _, name in ipairs({ "dungeon", "raid", "wipe", "zone" }) do
    SC.names[#SC.names + 1] = name
    SC.defs[name] = DEFS[name]
end
