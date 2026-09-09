-- modules/Aggregator_Preview.lua
--
-- The invented meter, for a player laying their columns out at a target dummy.
--
-- ---------------------------------------------------------------------------
-- WHY THIS FILE EXISTS
-- ---------------------------------------------------------------------------
--
-- Placeholder data is required of any addon with a positionable display, and
-- modules/Aggregator.lua is where it lived until that file went over layout-§1's
-- 1500-line cap. Issue #30's identity seam was the first cut and did not get it
-- under on its own, so this block — the file's own `Test rows` banner, whole —
-- is the second. It is the cheapest one available: these four tables and four
-- functions read nothing the aggregator holds and are read by nobody through a
-- file-local, so no upvalue crosses the line in either direction. All this file
-- needs is the module table to hang the four public functions on.
--
-- The consumers — modules/Provider.lua, modules/Roster.lua, modules/Tooltip.lua
-- and modules/DrillDown.lua — reach them as `NS.Aggregator.TestColumn` and the
-- like, at call time and behind an `and`, exactly as they did before the move.

local _, NS = ...

local Aggregator = NS.Aggregator


-- ---------------------------------------------------------------------------
-- Test rows
-- ---------------------------------------------------------------------------
--
-- Placeholder data, required of any addon with a positionable display: a player
-- who unlocks a window at a target dummy must see a full grid to lay their
-- columns out against, and `/mm test` gives the same thing on demand.
--
-- The numbers are DETERMINISTIC — derived from the row's index and the column's
-- position, never randomized. Test data that jitters every refresh is unusable
-- for the exact job it exists to do, which is judging column widths.

-- `spec` is a real specialization icon file id, so the spec-icon slot has
-- something to draw. Test mode is used to judge how a row LOOKS, and a row
-- missing one of its three icons is not the row the player is laying out.
local PREVIEW_MEMBERS = {
    { name = "Ka0stank",   class = "WARRIOR",     role = "TANK",    spec = 132342 },
    { name = "Ka0sheals",  class = "PRIEST",      role = "HEALER",  spec = 135940 },
    { name = "Ka0smage",   class = "MAGE",        role = "DAMAGER", spec = 135846 },
    { name = "Ka0srogue",  class = "ROGUE",       role = "DAMAGER", spec = 132320 },
    { name = "Ka0shunter", class = "HUNTER",      role = "DAMAGER", spec = 461112 },
    { name = "Ka0slock",   class = "WARLOCK",     role = "DAMAGER", spec = 136186 },
    { name = "Ka0smonk",   class = "MONK",        role = "DAMAGER", spec = 608951 },
    { name = "Ka0sdruid",  class = "DRUID",       role = "DAMAGER", spec = 625336 },
    { name = "Ka0spal",    class = "PALADIN",     role = "DAMAGER", spec = 135873 },
    { name = "Ka0sdk",     class = "DEATHKNIGHT", role = "DAMAGER", spec = 135771 },
}

-- HOW MUCH OF EACH STAT A ROLE ACTUALLY PRODUCES.
--
-- The first version gave every row the same smooth falloff in every column, so
-- the tank out-healed the healer and the healer out-damaged the rogue. That is
-- fine for judging a column WIDTH and useless for judging anything else — colors,
-- sort order, which columns are worth showing — because it does not look like a
-- fight. These multipliers make it look like one: a tank does little damage and
-- takes most of it, a healer heals and does neither.
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

-- Spell names for the test breakdown, so hovering a test row shows a tooltip
-- rather than "No data yet".
--
-- The tooltip and the drill-down both go to modules/Provider.lua for a spell
-- list, and the provider has nothing to say about a `Test-N` guid — correctly,
-- because there is no such source. So test mode publishes its own, in the shape
-- the provider would have returned, and Aggregator.TestSourceDetail is what the
-- two consumers ask FIRST.
local PREVIEW_SPELLS = {
    { id = 116858, name = "Chaos Bolt",   icon = 236291 },
    { id = 348,    name = "Immolation",   icon = 135817 },
    { id = 17962,  name = "Conflagrate",  icon = 135807 },
    { id = 29722,  name = "Incinerate",   icon = 135789 },
    { id = 5740,   name = "Rain of Fire", icon = 136186 },
    { id = 6353,   name = "Soul Fire",    icon = 135808 },
}

-- Per-stat magnitude, so the test grid looks like a meter rather than like ten
-- copies of one number: damage and healing are in the millions, kicks and deaths
-- are single digits. Anything absent falls back to the counting shape.
local PREVIEW_SCALE = {
    DamageDone           = 4200000,
    HealingDone          = 2600000,
    Absorbs              =  480000,
    DamageTaken          =  910000,
    AvoidableDamageTaken =  120000,
    Interrupts           =       9,
    Dispels              =       7,
    Deaths               =       3,
}

--- The test GROUP, in exactly the shape modules/Roster.lua builds.
---
--- The unit API is a data source too, and mocking only the meter would have left
--- the roster filter dropping every test row as "not in your group" — which is
--- the live behavior, correctly applied to invented data, and useless. So both
--- sources are mocked and everything between them is the live path.
---
--- @return table  array of { guid, unit, name, classFilename, role, isPlayer }
function Aggregator.TestGroup()
    local group = {}
    for index, member in ipairs(PREVIEW_MEMBERS) do
        group[index] = {
            guid          = string.format("Player-9999-TEST%04d", index),
            unit          = (index == 1) and "player" or ("party" .. (index - 1)),
            name          = member.name,
            classFilename = member.class,
            role          = member.role,
            isPlayer      = (index == 3),
        }
    end
    return group
end

--- One test COLUMN, in exactly the shape modules/Provider.lua returns.
---
--- This is where test mode now lives. It used to be a whole parallel result
--- table handed to the renderer (BuildTestRows), which made test mode and normal
--- mode two code paths that looked alike and diverged at every seam nobody
--- thought to duplicate. Substituting the PROVIDER's output instead means the
--- aggregator, the sorter, the row pool, the tooltip and the drill-down are all
--- the live code, reading numbers that happen to be invented.
---
--- The GUIDs are `Player-…` shaped rather than `Test-N`: modules/Roster.lua's
--- membership filter and modules/Row.lua's realm strip both key off that prefix,
--- and a test grid that skipped them would be testing a layout the live path
--- never produces.
---
--- @param sessionType number
--- @param statKey string
--- @return table  a provider column
function Aggregator.TestColumn(a, b, c)
    local statKey = b
    if a == Aggregator then statKey = c end

    local top = PREVIEW_SCALE[statKey or ""] or 8
    local column = { stat = statKey, maxAmount = top, totalAmount = top * 6, sources = {} }

    for index, member in ipairs(PREVIEW_MEMBERS) do
        local shape = ROLE_SHAPE[member.role] or ROLE_SHAPE.DAMAGER
        local total = math.floor(top * (1 - (index - 1) * 0.085) * (shape[statKey] or 1))
        if total < 0 then total = 0 end

        -- DEATHS EMITS ONE SOURCE PER DEATH, because that is what the client
        -- does — see the catalog note in core/Constants.lua. Emitting one per
        -- member made every preview player die exactly once, and a list of
        -- length one is the length at which every ordering bug hides. `total`
        -- is already the role-shaped figure, so it doubles as how many times
        -- this member died.
        if statKey == "Deaths" then
            local deaths = total
            if deaths < 1 then deaths = 1 end
            for n = deaths, 1, -1 do
                column.sources[#column.sources + 1] = {
                    guid            = string.format("Player-9999-TEST%04d", index),
                    name            = member.name,
                    classFilename   = member.class,
                    specIconID      = member.spec,
                    isLocalPlayer   = (index == 3),
                    totalAmount     = 0,
                    -- Newest first, so the ids descend exactly as the live
                    -- client's do.
                    deathRecapID    = 100 + index * 10 + n,
                }
            end
        else
            column.sources[#column.sources + 1] = {
                guid            = string.format("Player-9999-TEST%04d", index),
                name            = member.name,
                classFilename   = member.class,
                specIconID      = member.spec,
                isLocalPlayer   = (index == 3),
                totalAmount     = total,
                amountPerSecond = math.floor(total / 300),
            }
        end
    end

    return column
end

--- The death recap behind one preview death, in the client's own shape.
---
--- Test mode substitutes the DATA SOURCE and nothing else — that is the whole
--- reason the mock lives at the one function that talks to the client. Without
--- this, a preview death list is a column of dashes and every tooltip in it is
--- empty, which is precisely the "two code paths that look alike and behave
--- differently at every seam nobody duplicated" failure modules/Provider.lua's
--- header describes.
---
--- Deterministic, like every other preview: the same id gives the same recap on
--- every run, so a screenshot of the preview is reproducible.
---
--- @param recapID number  a preview id, `100 + index * 10 + n`
--- @return table|nil  { events = newest first, maxHealth }
function Aggregator.TestRecap(a, b)
    local recapID = a
    if a == Aggregator then recapID = b end
    if type(recapID) ~= "number" or recapID < 100 then return nil end

    local maxHealth = 700000
    -- Wall-clock, spread so two deaths never share a timestamp: the drill-down
    -- labels its rows with these and identical labels would read as a bug.
    local died = 1787380000 + recapID * 37

    local events, hp = {}, maxHealth
    for i = 1, #PREVIEW_SPELLS do
        local spell = PREVIEW_SPELLS[i]
        local amount = math.floor(maxHealth * (0.30 - (i - 1) * 0.04))
        if amount < 1000 then amount = 1000 end
        -- Built oldest-first so health falls, then reversed: the client returns
        -- newest first, and a fixture that did not would let a bug in the
        -- reversal pass unnoticed.
        events[#events + 1] = {
            spellId    = spell.id,
            spellName  = spell.name,
            sourceName = (i % 3 == 0) and nil or "Preview Trash",
            hideCaster = (i % 3 == 0) or nil,
            amount     = amount,
            currentHP  = hp,
            event      = "SPELL_DAMAGE",
            timestamp  = died - (#PREVIEW_SPELLS - i) * 4.7,
        }
        hp = hp - amount
        if hp < 0 then
            events[#events].overkill = -hp
            hp = 0
        end
    end

    local newestFirst = {}
    for i = #events, 1, -1 do newestFirst[#newestFirst + 1] = events[i] end
    return { events = newestFirst, maxHealth = maxHealth }
end

--- The spell breakdown behind one test row, in the provider's own shape.
---
--- modules/Tooltip.lua and modules/DrillDown.lua ask this BEFORE the provider
--- whenever test mode is on. Without it, hovering a test row reached
--- Provider.GetSourceDetail with a `Test-N` guid, got nil — correctly, there is
--- no such source — and drew "No data yet", which reads as a broken tooltip
--- rather than as placeholder data.
---
--- Deterministic, like every other number in this section, and derived from the
--- row's own guid so the same row always shows the same breakdown.
---
--- @param guid string|nil    a `Test-N` guid
--- @param statKey string|nil
--- @return table|nil  { combatSpells, maxAmount, totalAmount }
function Aggregator.TestSourceDetail(a, b, c)
    local guid, statKey = a, b
    if a == Aggregator then guid, statKey = b, c end
    if type(guid) ~= "string" then return nil end

    local index = tonumber(guid:match("^Player%-9999%-TEST(%d+)$"))
    if index == nil then return nil end

    local top = PREVIEW_SCALE[statKey or ""] or 8
    local scaled = math.floor(top * (1 - (index - 1) * 0.085))
    if scaled < 1 then scaled = 1 end

    local spells, total = {}, 0
    for i, spell in ipairs(PREVIEW_SPELLS) do
        local amount = math.floor(scaled * (1 - (i - 1) * 0.14))
        if amount < 1 then amount = 1 end
        total = total + amount
        spells[i] = {
            spellID     = spell.id,
            name        = spell.name,
            spellIcon   = spell.icon,
            totalAmount = amount,
            isAvoidable = (statKey == "AvoidableDamageTaken") and (i % 2 == 1) or nil,
            isDeadly    = (statKey == "AvoidableDamageTaken") and (i == 1) or nil,
        }
    end

    return { combatSpells = spells, maxAmount = spells[1].totalAmount, totalAmount = total }
end
