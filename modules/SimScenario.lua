local _, NS = ...
-- modules/SimScenario.lua — the simulator's four scenarios, their steps and how each step plays
-- (MultiMeters#60; design-mm-sim.md §2.7).
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

local SHADOWCROWN = { creatureID = 211290, name = "Speaker Shadowcrown" }
local VEXIE = { creatureID = 225821, name = "Vexie and the Geargrinders" }

local FIGHTS = {
    dungeonTrash = { name = "Trash", ticks = 6, secondsPerTick = 4, ends = true },
    dungeonBoss = { name = SHADOWCROWN.name, enemy = SHADOWCROWN, ticks = 10, secondsPerTick = 18, ends = true,
        deaths = { { tick = 7, role = "DAMAGER" } } },
    raidBoss = { name = VEXIE.name, enemy = VEXIE, ticks = 12, secondsPerTick = 25, ends = true,
        deaths = { { tick = 6, role = "DAMAGER" }, { tick = 9, role = "HEALER" } } },
    -- Everyone dies once by the last tick: a damage dealer, then a healer, then the rest together.
    wipeBoss = { name = SHADOWCROWN.name .. " (wipe)", enemy = SHADOWCROWN, ticks = 8, secondsPerTick = 15,
        ends = true, deaths = { { tick = 5, role = "DAMAGER" }, { tick = 6, role = "HEALER" }, { tick = 8, all = true } } },
    wipeRepull = { name = "Trash", ticks = 4, secondsPerTick = 4, ends = true },
    zoneTrash = { name = "Trash", ticks = 5, secondsPerTick = 4, ends = true },
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

local function fight(f)
    return { kind = "fight", fight = f,
        label = L["Pull %s (%d ticks x %d s)"]:format(f.name, f.ticks, f.secondsPerTick), tip = {
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
