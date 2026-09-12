-- modules/Aggregator.lua
--
-- The join. Columns in, ordered rows out — and the file where design rule R2
-- ("row order is never computed from values while comparison is illegal") is
-- actually enforced rather than merely stated.
--
-- ---------------------------------------------------------------------------
-- THE ALGORITHM, IN THE ORDER THE CODE RUNS IT
-- ---------------------------------------------------------------------------
--
--   1. Read one column per enabled stat from modules/Provider.lua.
--   2. Index every source by sourceGUID. Nothing here is ever keyed on a VALUE;
--      that is an immediate Lua error in combat and the single most tempting
--      mistake in the whole addon.
--   3. Filter to group members (modules/Roster.lua) and fold pets into owners.
--   4. Order, per the window's sortMode.
--   5. Cap to rows.maxRows, honoring rows.alwaysShowSelf.
--
-- THAT IS THE UNRESTRICTED BUILD, AND IT IS HALF THE FILE. `sourceGUID` is
-- annotated SecretWhenInCombat, so for the whole of a pull there is no join key
-- at all: it cannot be keyed on, compared or looked up. The second build —
-- IDENTITY MODE, further down — is what runs then, and it correlates on the
-- fields that stay plain instead. The choice is made once per pass.
--
-- ---------------------------------------------------------------------------
-- PET FOLDING IS ADDITION, AND ADDITION IS THE THING WE MAY NOT DO
-- ---------------------------------------------------------------------------
--
-- Adding a pet's damage to its owner's is arithmetic on two meter values. Out of
-- combat that is ordinary Lua. While the Combat restriction is active it raises,
-- and there is no native escape hatch for it the way there is for formatting —
-- NumericRuleFormatter renders, it does not sum.
--
-- So the behavior is honestly different in the two states, and it is logged once
-- per pass rather than hidden:
--   * unrestricted — the pet's value is summed into the owner's row.
--   * restricted   — the pet's row is DROPPED. The owner's number is low by
--                    whatever the pet contributed, which is a visible,
--                    explainable inaccuracy; the alternatives are a phantom pet
--                    row or a Lua error mid-pull.
-- Deferring the scoring feature rests on exactly this fact (design §7).
--
-- ---------------------------------------------------------------------------
-- THE SORT FREEZE, AND WHY IT IS GONE
-- ---------------------------------------------------------------------------
--
-- `value` mode sorts by the sort column's numbers, which requires comparing
-- them, which is illegal while restricted. This file used to answer that by
-- caching each successful value-sort as a guid -> position map, taking one last
-- sort at the ADDON_RESTRICTION_STATE_CHANGED `Activating` edge, and reapplying
-- that frozen order for the rest of the pull so nothing reshuffled.
--
-- ALL OF IT RESTED ON ROWS HAVING GUIDS MID-PULL, AND THEY DO NOT. A frozen
-- order is a map keyed on the one field that turns out to be secret exactly when
-- the freeze is needed, so it could never have been reapplied to a single row.
--
-- Identity mode replaces it with something better rather than poorer: the sort
-- column's `combatSources` arrives ALREADY RANKED by that column, so the order
-- is the engine's, it is live rather than a snapshot of the pull's first frame,
-- and it costs no comparison of ours. Rows re-rank as the fight moves, which is
-- what a meter is for.
--
-- ---------------------------------------------------------------------------
-- WHAT BUILD RETURNS
-- ---------------------------------------------------------------------------
--
--   {
--     rows            = { row, ... },          -- ordered, capped
--     columns         = { [statKey] = column },-- the provider's column tables
--     columnTotals    = { [statKey] = opaque },-- the column's group total
--     sortColumn      = string|nil,            -- which column the order came from
--     sortTotal       = opaque,                -- columnTotals[sortColumn]
--     durationSeconds = opaque,                -- for the header
--     sessionName     = string|nil,
--     identityMode    = boolean,               -- rows correlated, not GUID-joined
--     ambiguous       = boolean,               -- a class+spec pair could not be told apart
--     reason          = string|nil,            -- why a column came back empty
--   }
--
-- `columnTotals` exists so the render layer never has to issue a SECOND
-- Provider.GetColumn just to learn what a column's percentages are out of. The
-- build already holds every column table it read, and a per-column total is one
-- table read away from them; asking the provider again would double the number
-- of C_DamageMeter session reads on the refresh path for a number this file
-- already has. It is the same opaque handle the provider returned — a consumer
-- may hand it to NS.Format or to a widget setter and may do nothing else with
-- it (rule R1), which is exactly why the DIVIDED form (`cell.percent`) is
-- computed here, where core/Secrets.lua can gate the division, rather than
-- there.
--
-- and the result table IS ALSO THE ROW ARRAY: `result[1]` is `result.rows[1]`,
-- so `ipairs(Aggregator.Build(w))` and `Build(w).rows` are the same rows. That
-- is not decoration — the build brief specifies an ordered array and
-- modules/Window.lua was written against the result table, and satisfying both
-- with one object is cheaper and safer than a second shape that can drift.
--
-- A row is:
--
--   { guid, windowId, name, classFilename, specIconID, role,
--     isPlayer, isLocalPlayer,          -- the same fact under both names
--     providerIndex, sortValue, deathRecapID, deaths,
--     values = { [statKey] = { total, rate, maxAmount, columnTotal, percent,
--                              deathRecapID, deathTime, displayText } } }
--
-- `deaths` is a FLAT array of recap ids, `{ 29, 28, 27 }`, NEWEST FIRST, with
-- `false` in place of an id the client did not give. It exists only on a row
-- that has a Deaths cell — nil everywhere else, built lazily, and never a field
-- of the row literal, because that literal runs for every row in every window
-- four times a second. Flat rather than `{ { recapID = n } }` for the same
-- reason: a wrapper table per death is one allocation per death per pass, and
-- the perf harness measures bytes per refresh. `deathRecapID` beside it is the newest death alone and is
-- what the tooltip hint and the cell click read; the array is what the death
-- drill-down lists (modules/DrillDown.lua).
--
-- `cells` is published as an ALIAS of `values` (one table, two names) for the
-- same reason: the design brief calls the map `cells`, modules/Row.lua reads
-- `values`, and an alias costs one assignment while a copy costs a divergence.
--
-- `total`, `rate` and the column's `maxAmount` are OPAQUE HANDLES. A consumer
-- may pass them to StatusBar:SetValue / SetMinMaxValues, to FontString:SetText
-- and to NS.Format, and may do nothing else with them (rule R1). `percent` is
-- the exception and is a PLAIN number or nil: computing it is a division, so it
-- exists only when the operands were accessible, which is only out of combat.

local _, NS = ...

local Aggregator = NS:NewModule("Aggregator", "AceEvent-3.0")
NS.Aggregator = Aggregator

local Provider = NS.Provider
local Roster   = NS.Roster
local Secrets  = NS.Secrets
local State    = NS.State
local Const    = NS.Constants
local MSG      = Const.MSG

-- Perf bracket upvalue, resolved ONCE at load — never an NS lookup on the build
-- path (performance-§2). PerfSetup is in the core block, so this is always the
-- real instance or its stub.
local Perf = NS.Perf


-- ---------------------------------------------------------------------------
-- Row assembly
-- ---------------------------------------------------------------------------

--- The window's enabled columns as an array of stat keys, in display order.
---
--- A stored column whose stat is not in the catalog is skipped rather than
--- rendered blank — that is a window configured against a build which offered
--- more stats than this one (core/Constants.lua says the same).
local function columnKeys(window)
    local keys = {}
    local columns = window and window.columns
    if type(columns) ~= "table" then return keys end
    for _, column in ipairs(columns) do
        local key = column and column.stat
        if key and Const.STAT_BY_KEY[key] then keys[#keys + 1] = key end
    end
    return keys
end

--- Start a row for `guid` from whichever column first mentioned it.
---
--- Identity comes from the ROSTER where the roster has it, and from the meter's
--- source row only as a fallback. That ordering is deliberate: the meter's
--- `name` field is ConditionalSecret and may be opaque mid-pull, while
--- UnitName's answer is always plain text. `classFilename` and `specIconID` are
--- NeverSecret on the source row, so those come from the meter, which knows the
--- source's spec and the unit API does not always.
local function newRow(guid, src, windowId)
    local member = Roster.Get(guid)
    local isPlayer = (member and member.isPlayer) or false
    local values = {}
    return {
        guid          = guid,
        windowId      = windowId,
        name          = (member and member.name) or (src and src.name),
        classFilename = (src and src.classFilename) or (member and member.classFilename),
        specIconID    = src and src.specIconID,
        role          = (member and member.role) or "NONE",
        isPlayer      = isPlayer,
        -- The same fact under the name modules/Row.lua reads. One boolean, two
        -- keys, assigned together so they cannot disagree.
        isLocalPlayer = isPlayer,
        values        = values,
        cells         = values,   -- alias, not a copy — see the header
    }
end

--- Write one source's numbers into a row's cell for `statKey`.
---
--- Pure copying. Not one of these fields is examined, compared or coerced on the
--- way through — they land in table VALUES, which is explicitly permitted, and
--- travel on as opaque handles.
local function setCell(row, statKey, src, maxAmount, isCount)
    -- A COUNTED STAT TALLIES ROWS. Deaths reports one source row per death, with
    -- totalAmount 0 on every one, so the figure is how many rows this GUID has —
    -- see the catalog note in core/Constants.lua. The counter is ours, so
    -- incrementing it is not arithmetic on a meter value and stays legal mid-pull.
    if isCount then
        local cell = row.values[statKey]
        if cell == nil then
            cell = { total = 0, maxAmount = maxAmount }
            row.values[statKey] = cell
        end
        cell.total = cell.total + 1

        -- EVERY DEATH LANDS ON THE ROW, in the order the API returned them —
        -- newest first. The scalar below keeps the newest one and four call
        -- sites read it; this array is what the death drill-down lists, and
        -- dropping all but the first is exactly what issue #1 exists to undo.
        --
        -- Built lazily and hung on the ROW, never on the cell literal below and
        -- never in newRow: those two run for every row in every column on every
        -- pass, and a field only Deaths ever fills would widen the whole grid to
        -- carry it — the same reasoning the comment in fillCorrelated records.
        local deaths = row.deaths
        if deaths == nil then deaths = {} row.deaths = deaths end
        -- FALSE, NEVER NIL, for a death the client gave no recap id for.
        -- `deaths[#deaths + 1] = nil` is a no-op: the array silently stayed short
        -- while the counter above went up, so the cell said 3 and the drill-down
        -- listed 2 — the one disagreement this whole feature must not have. A
        -- death with no id cannot be opened, but it certainly happened.
        local id = src.deathRecapID
        if id == nil then id = false end
        deaths[#deaths + 1] = id

        -- The FIRST row wins the SCALAR recap: the API returns deaths
        -- newest-first, and the death a player wants to look at is the one that
        -- just happened.
        if cell.deathRecapID == nil then
            cell.deathRecapID = src.deathRecapID
            cell.deathTime    = src.deathTimeSeconds
            if src.deathRecapID ~= nil then row.deathRecapID = src.deathRecapID end
        end
        return
    end

    row.values[statKey] = {
        total        = src.totalAmount,
        rate         = src.amountPerSecond,
        maxAmount    = maxAmount,
        deathRecapID = src.deathRecapID,
        deathTime    = src.deathTimeSeconds,
    }

    -- deathRecapID is NeverSecret, and both the tooltip and the drill-down read
    -- it off the ROW rather than off a cell (it identifies the player's death,
    -- not a column's number). Promoted here so neither has to know which column
    -- it arrived on.
    if src.deathRecapID ~= nil then row.deathRecapID = src.deathRecapID end
end

--- Fold a pet's numbers into its owner's existing cell.
---
--- Returns true when the sum happened, false when it was refused. The caller
--- counts the refusals and reports them once per pass; it does not retry and it
--- does not approximate.
---
--- CanCompare2 is the gate rather than IsRestricted because it asks the question
--- that actually decides — "may this execution context access both of these" —
--- and it is right on a client with no restriction system at all, where the
--- honest answer is yes.
local function foldPet(row, statKey, src)
    local cell = row.values[statKey]
    if cell == nil then
        -- The owner has no cell in this column yet (a pet that did damage its
        -- owner did not). Adopting the pet's numbers wholesale is not a sum, so
        -- it is legal in either state — and it is the correct answer: the owner
        -- DID that damage, through the pet.
        setCell(row, statKey, src, nil)
        return true
    end

    if not Secrets.CanCompare2(cell.total, src.totalAmount) then return false end
    if type(cell.total) ~= "number" or type(src.totalAmount) ~= "number" then return false end

    cell.total = cell.total + src.totalAmount
    if type(cell.rate) == "number" and type(src.amountPerSecond) == "number" then
        cell.rate = cell.rate + src.amountPerSecond
    end
    return true
end

--- `value` as a percentage of `total`, as a PLAIN NUMBER, or nil.
---
--- The only arithmetic this file performs on meter data other than the pet fold,
--- and it is gated the same way: a division on an inaccessible operand raises,
--- so an inaccessible operand yields nil and the cell's percent slot renders
--- empty. nil means "cannot be known right now", never "zero percent" — and the
--- text slots default to total/rate precisely because percent is the slot that
--- goes quiet in combat.
---
--- Returns a number rather than text because modules/Row.lua hands the result to
--- NS.Format.Percent for rendering; formatting here would format twice.
local function percentOf(value, total)
    if value == nil or total == nil then return nil end
    if not Secrets.CanCompare2(value, total) then return nil end
    if type(value) ~= "number" or type(total) ~= "number" then return nil end
    if total == 0 then return nil end
    return value / total * 100
end

-- Base position for a row that never appeared in the sort column, and for a row
-- with no frozen place. Large enough that it can never collide with a real
-- index — a session cannot hold more sources than the iteration limit
-- core/Secrets.lua enforces — and finite so the sort stays deterministic rather
-- than falling back on table order.
local UNRANKED = 100000

-- ---------------------------------------------------------------------------
-- Ordering
-- ---------------------------------------------------------------------------

--- Turn an ordered array back to front, in place.
---
--- THE ONE REORDERING THAT IS ALWAYS LEGAL. It is a permutation: no element is
--- compared with another, added to another, used as a table key, or measured
--- with `#` beyond the array this file built itself. So it works on a list of
--- rows carrying secret values at exactly the moment `orderByValue` has to
--- refuse, which is what makes an ascending grid available mid-pull at all.
local function reverseRows(rows)
    local i, j = 1, #rows
    while i < j do
        rows[i], rows[j] = rows[j], rows[i]
        i, j = i + 1, j - 1
    end
end

--- Order by the position modules/Provider.lua returned for the sort column.
---
--- Needs no comparison of any meter value — `providerIndex` is a plain integer
--- this file assigned during the scan — so it is legal at any point in a pull.
--- It is also the fallback every other mode degrades TO, which is why it is the
--- simplest thing here.
local function orderByProvider(rows, ascending)
    table.sort(rows, function(a, b) return a.providerIndex < b.providerIndex end)
    if ascending then reverseRows(rows) end
end

--- Order by the sort column's values — or refuse.
---
--- Comparability is checked in a SEPARATE PASS BEFORE table.sort runs, not
--- inside the comparator. That is the whole trick of this function: a comparator
--- that discovers an illegal comparison halfway through has already raised, and
--- there is no way to unwind a partially sorted array. One linear pass that
--- touches nothing but CanCompare turns a possible mid-sort error into a clean
--- "no".
---
--- A MISSING CELL COUNTS AS ZERO, so it flips with the direction like any other
--- figure: last descending, first ascending. It used to sort last in both
--- directions, on the reading that "this player has no dispels" is an absence
--- rather than a low score — but for a contribution column an absence IS zero.
--- The meter omits a source row because the player did none of that thing, not
--- because it declined to say, and "sort ascending by Avoidable" is a question
--- about who took the least: the people who took none are the answer, and they
--- belong at the top.
---
--- The genuine "cannot be known" case never reaches here. A cell left empty
--- because two rows shared an identity key happens only while restricted, and
--- this function does not run there — the identity build orders by the engine's
--- own ranking instead.
---
--- Substituting zero is safe for the same reason the sort itself is: the pass
--- above has already established that every value present is ACCESSIBLE, so
--- comparing one against a plain 0 is an ordinary comparison.
---
--- @param ascending boolean|nil
--- @return boolean  whether the sort was taken
local function orderByValue(rows, statKey, ascending)
    for i = 1, #rows do
        local cell = rows[i].values[statKey]
        local v = cell and cell.total
        if v ~= nil and not Secrets.CanCompare(v) then return false end
    end

    table.sort(rows, function(a, b)
        local ac, bc = a.values[statKey], b.values[statKey]
        local av = ac and ac.total
        local bv = bc and bc.total
        -- `== nil` rather than `or 0`, which is a truth test and raises on a
        -- secret. Two zeros — whether absent or genuinely zero — fall back to
        -- provider order so the sort stays deterministic (table.sort is not
        -- stable).
        if av == nil then av = 0 end
        if bv == nil then bv = 0 end
        if av == bv then return a.providerIndex < b.providerIndex end
        if ascending then return av < bv end
        return av > bv
    end)
    return true
end

--- Order alphabetically by the name on the row.
---
--- WHAT THE PLAYER COLUMN'S HEADER MEANS. It used to toggle between `roster` and
--- `value`, which is a reasonable thing for some header to do and not what that
--- one says: a column labelled "Player" sorts by player.
---
--- Guarded exactly like orderByValue, and for the same reason: `name` is
--- ConditionalSecret, `<` on a secret raises, and `tostring()` does not launder
--- one — it survives it. So comparability is proved in a SEPARATE PASS before
--- table.sort is entered, and a name that cannot be compared refuses the whole
--- sort rather than raising inside the comparator.
---
--- A row with NO name at all sorts last in both directions. That is not the same
--- decision as a missing number counting as zero: an empty string is not a
--- position in the alphabet, and there is nothing for it to be "least" of.
---
--- @return boolean  whether the sort was taken
local function orderByName(rows, ascending)
    for i = 1, #rows do
        local n = rows[i].name
        if n ~= nil and not Secrets.CanCompare(n) then return false end
    end

    table.sort(rows, function(a, b)
        local an, bn = a.name, b.name
        if an == nil and bn == nil then return a.providerIndex < b.providerIndex end
        if an == nil then return false end
        if bn == nil then return true end
        -- Both proved comparable above, so tostring is reading a plain string.
        local x, y = tostring(an):lower(), tostring(bn):lower()
        if x == y then return a.providerIndex < b.providerIndex end
        if ascending then return x < y end
        return x > y
    end)
    return true
end

--- Order by group position, then role, then name — the mode that never moves.
---
--- Roles sort tank, healer, damager rather than alphabetically, because that is
--- how a raid frame reads and the point of this mode is predictability.
local ROLE_RANK = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }

local function orderByRoster(rows)
    local position = {}
    for index, member in ipairs(Roster.GetGroup()) do position[member.guid] = index end

    table.sort(rows, function(a, b)
        local ap = position[a.guid] or (UNRANKED + a.providerIndex)
        local bp = position[b.guid] or (UNRANKED + b.providerIndex)
        if ap ~= bp then return ap < bp end
        local ar = ROLE_RANK[a.role] or 4
        local br = ROLE_RANK[b.role] or 4
        if ar ~= br then return ar < br end
        -- The name tiebreak is reached ONLY by rows absent from the roster --
        -- pets, enemies, cross-realm strays -- and that is exactly the
        -- population whose `name` came from the meter's ConditionalSecret
        -- src.name rather than from a unit token. `<` on two of those raises
        -- mid-combat, and `tostring()` does not launder a secret: it survives
        -- it. So compare names only when the values are comparable, and
        -- otherwise fall back to providerIndex, the deterministic escape
        -- orderByValue already uses.
        if not Secrets.CanCompare2(a.name, b.name) then
            return a.providerIndex < b.providerIndex
        end
        return tostring(a.name) < tostring(b.name)
    end)
end

-- ---------------------------------------------------------------------------
-- Build, one stage at a time
-- ---------------------------------------------------------------------------
--
-- Build is the join, and the join is five stages: decide what to read, read and
-- index it, order it, cap it, derive the per-row numbers. Each stage below is
-- one of those, and they share ONE mutable pass table rather than a chain of
-- tuple returns — the counters the debug line reports (dropped, unfolded,
-- reason, applied) are gathered by different stages, and threading them through
-- return values would mean every stage carrying numbers it has no opinion about.
--
-- The pass table is allocated once per Build, which is the same allocation the
-- old body made for its locals' worth of tables.

--- Everything the pass needs to know before it reads a single column.
---
--- A stored sortColumn whose stat is not in the catalog falls back to the first
--- enabled column, for the same reason columnKeys skips it: the window was
--- configured against a build that offered more stats than this one.
local function newPass(window)
    local data = window.data or {}
    local keys = columnKeys(window)

    local sortColumn = data.sortColumn
    if not (sortColumn and Const.STAT_BY_KEY[sortColumn]) then sortColumn = keys[1] end

    return {
        windowId    = window.id,
        sessionType = data.sessionType or Const.SESSION_TYPE.Current,
        -- The segment the header dropdown is pointed at, or nil for "whichever
        -- session sessionType names" -- Database.PinnedSegment turns the row's
        -- NO_SEGMENT into that nil. Read straight off the config rather than off
        -- the window instance because modules/Window.lua CLEARS a stale id before
        -- it aggregates, so the config is the resolved answer by the time this
        -- runs — one source of truth rather than two.
        sessionID   = NS.Database.PinnedSegment(data),
        keys        = keys,
        sortColumn  = sortColumn,
        mode        = data.sortMode or "value",
        -- Direction is a per-window setting the column headers toggle. Descending
        -- is the default because a meter is read top-down for "who did the most".
        sortAscending = data.sortAscending and true or false,
        -- Off by default: see rowForSource. Merging is arithmetic, and arithmetic
        -- on a secret raises, so the merged mode is exact out of combat and lossy
        -- inside it.
        --
        -- ADDON-WIDE, not this window's: it says what a pet's damage IS, which is
        -- not a question two windows may answer differently. NS.DataSetting is
        -- the one reader (defaults/Profile.lua).
        mergePets   = NS.DataSetting and NS.DataSetting("mergePets") and true or false,
        applied     = nil,
        -- Whether this pass must build without the GUID join. Asked of
        -- core/Secrets.lua rather than of State.restricted, which is a mirror
        -- for the render path: this decides which algorithm runs and has to be
        -- right rather than fast.
        identityMode = Secrets.IsRestricted(),
        -- Set by the identity build when two sources shared one identity key.
        ambiguous    = false,
        -- ...and how many ROWS that cost, which is what the header says out loud.
        -- Zero on a GUID pass and on an identity pass that collided nothing;
        -- never nil, so a reader never has to tell "not measured" from "none".
        ambiguousRows = 0,
        -- Correlation tallies for the one debug line the identity build emits.
        -- `filled` against `possible` is the figure that matters: a grid whose
        -- secondary columns are blank is either colliding (collisions > 0) or
        -- not matching at all (collisions == 0 and filled == 0), and those are
        -- different faults with different fixes.
        corrFilled   = 0,
        corrPossible = 0,
        corrKeys     = 0,
        -- statKey -> the set of identity keys that column MENTIONED, kept for
        -- the correlation rectangle. Allocated only while the debug flag is on:
        -- nothing on the render path reads it, and `nil` is what the fill checks.
        corrSeen     = State.debug and {} or nil,

        byGuid  = {},
        -- identity key -> the FIRST row carrying it, for the identity build's
        -- "does any row already stand for this source" question. Distinct from
        -- byGuid: two players of one class and spec are two rows sharing one
        -- key, and this holds the first of them.
        byIdentity = {},
        rows    = {},
        columns = {},
        -- statKey -> the column's group total, lifted out of the column table it
        -- was already read from. Published so nothing downstream re-reads the
        -- session for a number this pass already has (see the header).
        columnTotals = {},

        dropped  = 0,
        unfolded = 0,
        reason   = nil,
    }
end

--- The group member a source's numbers belong to, or nil to drop the source.
---
--- A group member owns their own numbers; anyone else is a pet and belongs to
--- whoever the roster says summoned them. Best effort, and nil is a real answer:
--- an unattributable pet is dropped rather than shown as a phantom row
--- (design §5).
local function owningMember(guid)
    if Roster.IsGroupMember(guid) then return guid end
    local owner = Roster.OwnerOf(guid)
    if owner and Roster.IsGroupMember(owner) then return owner end
    return nil
end

--- Truth-test a field that MIGHT be a secret boolean.
---
--- `if src.isLocalPlayer then` is the natural way to write this and it raises the
--- moment that field is secret, because a boolean test on a secret boolean is
--- exactly what tainted code may not do. Asking core/Secrets.lua first keeps the
--- inspection in the one file allowed to make it, and an inaccessible flag reads
--- as "no claim" — the same shape modules/Tooltip.lua uses for isAvoidable.
local function plainTruth(v)
    if not Secrets.CanAccess(v) then return false end
    return v and true or false
end

--- The plain GUID a source with an UNKEYABLE GUID can still be attributed to.
---
--- THE MEASURED FACT THIS EXISTS FOR: `C_DamageMeter` returns a SECRET
--- `sourceGUID` while the Combat restriction is active. The design assumed the
--- opposite — "a GUID is never secret, so it is the ONLY thing in a session
--- legal as a table KEY" — and on that assumption the entire join rests. It does
--- not hold: NS.Secrets.IsSafeKey correctly refuses the key, every source is
--- dropped, and the window emptied for the whole of every pull.
---
--- A secret GUID cannot be keyed on, compared, or looked up, so for most sources
--- there is genuinely nothing left to join on and they stay dropped (see the
--- header on why a phantom row is worse). ONE identity survives: `isLocalPlayer`
--- is plain, so a source that says it is us can be attributed to the roster's own
--- plain GUID. That is the source's own statement about itself, not a guess.
---
--- Deliberately narrow. `classFilename` is plain too and would "identify" a
--- group member whenever no two of them share a class — which is a coin flip in
--- a party and false in a raid, and getting it wrong prints one player's numbers
--- under another player's name. Dropping a row is a visible absence; mislabeling
--- one is a lie the player cannot see.
---
--- @return string|nil  the local player's roster GUID, or nil for no claim
local function localClaim(src)
    if not plainTruth(src.isLocalPlayer) then return nil end
    return Roster.LocalGUID()
end

--- Say WHY a source was refused, on the first drop of the pass only.
---
--- `rows=0 dropped=N` is the shape every "my window is empty" report takes, and
--- the counter alone cannot say which of the causes it was: a GUID this context
--- may not key on, a source belonging to nobody in the group, or a pet with no
--- owner link. They need different fixes, so the refusal names itself.
---
--- `lookup` asks whether the CLIENT will resolve a source from a GUID we may not
--- resolve ourselves (modules/Provider.lua's ProbeSourceByGuid) — the question
--- that decides whether a future build can do better than identity correlation.
---
--- Every argument goes through NS.SafeToString: a GUID this branch could not use
--- is exactly the one that is likely secret, and a secret raises inside
--- string.format.
local function logDrop(pass, src, guid)
    NS.Debug("Aggregator",
        "dropped guid=%s secret=%s access=%s member=%s owner=%s local=%s/%s class=%s/%s display=%s lookup=%s",
        NS.SafeToString(guid), tostring(Secrets.IsSecret(guid)),
        tostring(Secrets.CanAccess(guid)),
        tostring(Roster.IsGroupMember(guid)), NS.SafeToString(Roster.OwnerOf(guid)),
        NS.SafeToString(src.isLocalPlayer), tostring(Secrets.IsSecret(src.isLocalPlayer)),
        NS.SafeToString(src.classFilename), tostring(Secrets.IsSecret(src.classFilename)),
        NS.SafeToString(src.sourceDisplayType),
        Provider.ProbeSourceByGuid(pass.sessionType, pass.sortColumn, guid))
end

--- The local player's row, started on first sight of it.
---
--- Reached only when the GUID join could not place the source and the source
--- claimed to be us — a mixed pass, where most GUIDs are plain and this one is
--- not. `claimed` is the ROSTER's own GUID, so the row keys, names and roles
--- exactly like any other, and nothing here touches the secret one.
local function claimedRow(pass, src, index, isSortColumn, claimed)
    local row = pass.byGuid[claimed]
    if row == nil then
        row = newRow(claimed, src, pass.windowId)
        row.providerIndex = isSortColumn and index or (UNRANKED + index)
        pass.byGuid[claimed] = row
        pass.rows[#pass.rows + 1] = row
    elseif isSortColumn then
        row.providerIndex = index
    end
    return row
end

--- The row `src` should be written into, started on first sight of its owner.
---
--- @return table|nil row  nil when the source was dropped (and counted)
--- @return boolean isOwn  true when the source IS the member, false for a pet
--- Refuse a source, count it, and say why the first time in each pass.
---
--- First-drop only, because a raid pull drops every enemy in the pack and forty
--- lines a quarter second is a log nobody can read (debug-logging-§4).
local function dropSource(pass, src, guid)
    pass.dropped = pass.dropped + 1
    if State.debug and pass.dropped == 1 then logDrop(pass, src, guid) end
    return nil, false
end

--- The row a placed source belongs on, started on first sight of its owner.
---
--- A PET GETS ITS OWN ROW unless the window asked for it to be merged. Merging
--- is ADDITION, so it runs only where the operands are accessible; a separate row
--- has no arithmetic in it at all, is exact in both states, and is what
--- Blizzard's own meter shows. That is why it is the default and merging is the
--- option rather than the other way round.
---
--- A pet's row is keyed on the PET's guid and carries its own name and class off
--- the source, so it reads as the pet it is rather than as a second copy of its
--- owner. `ownerGuid` is kept on it for the tooltip and for anything that later
--- wants to group them.
local function placedRow(pass, src, index, isSortColumn, ownerGuid, isOwn)
    local petOwner
    if not isOwn and not pass.mergePets then
        petOwner  = ownerGuid
        ownerGuid = src.guid
        isOwn     = true
    end

    local row = pass.byGuid[ownerGuid]
    if row == nil then
        row = newRow(ownerGuid, isOwn and src or nil, pass.windowId)
        if petOwner then
            row.isPet     = true
            row.ownerGuid = petOwner
        end
        -- Provider position comes from the SORT column, because that is what
        -- `provider` mode means: "the order Blizzard returned for the column
        -- this window is ordered by", not "the order of whichever column
        -- happened to mention this player first". A player who appears in some
        -- other column but not in the sort one (a death, with no damage) is
        -- parked past every ranked row, in first-seen order, rather than
        -- interleaved.
        row.providerIndex = isSortColumn and index or (UNRANKED + index)
        pass.byGuid[ownerGuid] = row
        pass.rows[#pass.rows + 1] = row
    end

    -- ONLY the member's own source sets the position. A pet's index is a
    -- position in the source list, not in the row list, and letting it through
    -- moved its owner to wherever the pet happened to sit.
    if isSortColumn and isOwn then row.providerIndex = index end

    return row, isOwn
end

--- Whether this source is an enemy rather than one of us.
---
--- `sourceDisplayType` is a plain enum, which is what makes it usable here: the
--- unrestricted path filters mobs out by asking the roster, and the roster
--- cannot answer for a source it cannot key on.
local function isEnemySource(src)
    local kind = src.sourceDisplayType
    if kind == nil or Secrets.IsSecret(kind) then return false end
    return kind == Const.SOURCE_DISPLAY_TYPE.Enemy
end

--- The class filename of a source the client filed under `None`, or nil.
---
--- TWO CONDITIONS, and neither is sufficient alone. The display type must be
--- exactly `None` — an absent or secret one is not "probably a companion", it is
--- an unknown, and unknowns keep being dropped. And the class must be one the
--- client itself recognizes, which is what separates a delve companion from a
--- humanoid mob that happens to reach this function.
---
--- THE SECRECY GUARD IS NOT DEFENSIVE PADDING. `sourceDisplayType` is SECRET for
--- the whole of a pull — a live `/mm debug diag` mid-pull printed `display types:
--- <secret> x5` across a five-enemy column — which nothing in this file or its
--- docs had recorded until it was measured. `==` against a secret is permitted
--- and simply answers false, so the comparison below would refuse a companion
--- rather than raise, and the refusal would be correct: mid-pull the GUID join
--- is not running at all and identity mode builds the grid instead. The guard is
--- here so that the reason is a stated one rather than a lucky one.
---
--- The lookup is `rawget`-free and deliberately so: RAID_CLASS_COLORS is a plain
--- global table on every client this addon runs on, and a metatable on it would
--- be Blizzard's own answer about what a class is, which is the answer wanted.
---
--- @param src table
--- @return string|nil  the class filename, when it identifies a real class
local function companionClass(src)
    local kind = src.sourceDisplayType
    if kind == nil or Secrets.IsSecret(kind) then return nil end
    if kind ~= Const.SOURCE_DISPLAY_TYPE.None then return nil end

    local class = src.classFilename
    -- NeverSecret per Blizzard's annotations, and asked anyway: an annotation is
    -- a promise about the live client, and this file does not stake a raise on
    -- one it can cheaply check.
    if class == nil or Secrets.IsSecret(class) then return nil end
    if type(class) ~= "string" or class == "" then return nil end

    local classes = _G.RAID_CLASS_COLORS
    if type(classes) ~= "table" or classes[class] == nil then return nil end
    return class
end

--- A row for an ALLY nobody in the group owns.
---
--- ---------------------------------------------------------------------------
--- WHY THIS IS NOT "MISLABELING A ROW"
--- ---------------------------------------------------------------------------
---
--- Everything else in this file drops a source it cannot attribute, on the rule
--- that a dropped row is a visible absence and a mislabeled one is a lie. That
--- rule is about ATTRIBUTION — putting one player's numbers under another
--- player's name — and it does not apply here, because this row makes no claim
--- about an owner at all. It carries the source's OWN name and the source's own
--- figures. Nothing is inferred.
---
--- What was being lost: a warlock's felguard, a shaman's elemental, a death
--- knight's ghoul, every totem and every temporary guardian. Their owner link
--- needs the unit API to have seen them, which for a guardian it often never
--- does — so their damage and their interrupts simply vanished off the grid,
--- while Blizzard's own meter and every other addon showed them.
---
--- ENEMIES ARE STILL REFUSED, and that is what keeps this safe: without the
--- `sourceDisplayType` gate any read that reaches an enemy source would put a mob
--- on the grid as a row. No column asks for one today — EnemyDamageTaken is no
--- longer in the catalog (issue #2) — but the gate is what makes that a fact
--- about this function rather than a fact about the column list. `mergePets` is not consulted, because merging
--- is addition into an OWNER's row and there is no owner to add into — the whole
--- reason we are here.
---
--- ---------------------------------------------------------------------------
--- AND A THIRD KIND: A COMPANION THE CLIENT FILES UNDER `None`
--- ---------------------------------------------------------------------------
---
--- This gate was written to admit ONLY an explicit `Ally`, on the belief that
--- anything of ours carries that flag. A delve says otherwise. Valeera
--- Sanguinar fought a nine-and-a-half minute delve, did 24.98M of the run's
--- 61.31M, and never reached the grid — while the header total counted her,
--- because a session total is the client's own sum and does not consult this
--- function. Measured on the live client:
---
---     dropped guid=Creature-0-3748-2933-99554-248567-… member=false owner=nil
---             class=ROGUE/false display=0 lookup=resolved
---
--- `display=0` is `None`: the client files a delve companion as neither `Ally`
--- nor `Enemy`. The old comment here predicted this exact failure — "the failure
--- mode is this fix doing nothing" — and this is it, four columns wide.
---
--- SO `None` IS ADMITTED, BUT ONLY WITH A REAL PLAYER CLASS ON IT, and the
--- narrowness is the point. `classFilename` is NeverSecret, so the test is legal
--- in a pull as well as out of it, and a mob would have to report `None` AND
--- carry a genuine class filename to slip through.
---
--- RAID_CLASS_COLORS is the oracle rather than a list of our own, because
--- modules/Row.lua ALREADY looks a row up in that same table to color its bar
--- and pick its class icon. A source that fails this test would draw as an
--- uncolored, iconless row — so the gate admits precisely the set that can be
--- rendered honestly and refuses the rest. One table, one answer, and a client
--- that gains a class gains it in both places at once.
---
--- @return table|nil row, boolean isOwn
local function unownedAllyRow(pass, src, index, isSortColumn, guid)
    local kind = src.sourceDisplayType
    if kind == nil or Secrets.IsSecret(kind) then return dropSource(pass, src, guid) end
    if kind ~= Const.SOURCE_DISPLAY_TYPE.Ally and not companionClass(src) then
        return dropSource(pass, src, guid)
    end
    -- Keyed on its own GUID, so it needs to BE a legal key. Mid-pull it is not,
    -- and identity mode is running instead anyway.
    if not Secrets.IsSafeKey(guid) then return dropSource(pass, src, guid) end

    local row = pass.byGuid[guid]
    if row == nil then
        row = newRow(guid, src, pass.windowId)
        -- `isPet` drives the row's presentation, and it is the honest flag even
        -- for a totem or a guardian: what it means downstream is "not a group
        -- member of its own right". `ownerGuid` stays nil — there is no owner.
        row.isPet = true
        row.isUnowned = true
        row.providerIndex = isSortColumn and index or (UNRANKED + index)
        pass.byGuid[guid] = row
        pass.rows[#pass.rows + 1] = row
    elseif isSortColumn then
        row.providerIndex = index
    end
    return row, true
end

--- The row `src` should be written into.
---
--- @return table|nil row  nil when the source was dropped (and counted)
--- @return boolean isOwn  true when the source IS the member, false for a pet
local function rowForSource(pass, src, index, isSortColumn)
    local guid = src.guid
    local ownerGuid = owningMember(guid)

    if ownerGuid == nil then
        -- The local-player fallback returns EARLY rather than joining the path
        -- below, which compares `ownerGuid` against `guid` — and `guid` is
        -- exactly the secret value that got us here. `==` on a secret is a
        -- comparison, and a comparison raises. The row is the member's own by
        -- construction, so there is nothing to work out.
        local claimed = localClaim(src)
        if claimed ~= nil then
            return claimedRow(pass, src, index, isSortColumn, claimed), true
        end
        -- Not a member, not a member's pet, and not us — but possibly still one
        -- of ours. See `unownedAllyRow`.
        return unownedAllyRow(pass, src, index, isSortColumn, guid)
    end

    return placedRow(pass, src, index, isSortColumn, ownerGuid, ownerGuid == guid)
end

-- ---------------------------------------------------------------------------
-- IDENTITY MODE — peeled to modules/Aggregator_Identity.lua
-- ---------------------------------------------------------------------------
--
-- The second build — the grid drawn while `sourceGUID` is secret — and the
-- correlation rectangle that measures it sit in modules/Aggregator_Identity.lua,
-- which loads immediately after this file. They left under layout-§1's 1500-line
-- cap, along the seam issue #30 names: together they answer a question the
-- aggregator proper does not ask, while the pipeline above and below them is one
-- algorithm this file's header narrates end to end and must not be cut inside.
--
-- It is the SAME code, and it still needs the row-assembly helpers above, which
-- are file-locals. This table is the entire seam between the two files: what is
-- listed here travels out to the sibling, and `buildByIdentity` and
-- `lastIdentityStats` come back on it. The sibling resolves them at FILE SCOPE,
-- once at load, so no build-path call pays a namespace lookup for the split.
Aggregator._identity = {
    newRow        = newRow,
    setCell       = setCell,
    isEnemySource = isEnemySource,
    plainTruth    = plainTruth,
    UNRANKED      = UNRANKED,
}

--- The `judge` recorder for this pass, or nil when nobody is recording.
---
--- Resolved through `NS.Diagnostics` at CALL time, because core/Diagnostics.lua
--- is optional and this file does not depend on it loading. What is new is that
--- the ARMED FLAG is read here too, before the caller builds anything: Lua
--- evaluates a call's arguments first, so passing a freshly built fields table to
--- a `TraceFeign` that will decline it still costs the table. Disarmed, that was
--- two tables — the fields and its nested order list — per Deaths source per
--- refresh, on the addon's hot path, for a recording nobody had asked for.
---
--- Returning the function rather than a boolean is what lets scanColumn spend one
--- test instead of three, and keeps the resolution out of a function that is
--- already the most complex in the addon.
---
--- @param active any        the Feign module, or nil where the column is not counted
--- @return function|nil     Diagnostics.TraceFeign while armed, otherwise nil
local function judgeTracer(active)
    if not active then return nil end
    local D = NS.Diagnostics
    if D ~= nil and D.feignArmed == true then return D.TraceFeign end
    return nil
end

--- The feign verdict for one Deaths source, plus the record of it.
---
--- ASKED PER DEATH, not per player. `ShouldDropDeath` remembers the individual
--- deaths it judges fake, so a hunter who later dies for real does not bring
--- every earlier feign back into the count with them — which is exactly what
--- asking the live set here used to do. It answers false for anything it cannot
--- key on, including a secret guid, and that is the honest answer: "cannot tell"
--- must mean "real death", because the alternative is silently dropping one.
---
--- The verdict is recorded for the issue #25 trace. Last of the three boundaries
--- that recording covers: a death row that reaches here with `dropped=false` for
--- a GUID the `cast` line named is the filter losing the thread between the two,
--- and the `prune` lines in between say where. While nobody is recording this is
--- one nil test and the table below is never built — which is what the comment
--- used to claim and did not do.
---
--- @param active any            the Feign module, or nil where the column is not counted
--- @param traceJudge function|nil  the armed recorder from judgeTracer, or nil
--- @param src table             the provider source under judgement
--- @return boolean|nil          truthy only for a death the filter drops
local function judgeDeath(active, traceJudge, src)
    local feigned = active and active.ShouldDropDeath
        and active.ShouldDropDeath(src.guid, src.deathRecapID)
    if traceJudge then
        traceJudge("judge", {
            order = { "guid", "recap", "dropped" },
            guid = src.guid, recap = src.deathRecapID,
            dropped = feigned and true or false,
        })
    end
    return feigned
end

--- Put ONE source's figure where it belongs: its own cell, a counted pet's tally,
--- or folded into its owner.
---
--- The drop stays here, ahead of `rowForSource`, because that function creates and
--- appends the row as a side effect in all three of its branches — filtering after
--- it would leave a phantom empty row instead of no row.
---
--- Every decision below is about a single source; none is about the column, which
--- is why the walk's body is its own function.
---
--- @param maxAmount number|nil  the column max, nil on a counted column
--- @param isCount boolean       whether the column tallies events rather than amounts
--- @param touched table|nil     the counted column's set of rows to rescale, else nil
local function placeSource(pass, statKey, src, index, isSortColumn, feigned, maxAmount, isCount, touched)
    -- Spelled as a branch and not as `not feigned and rowForSource(...) or nil`:
    -- that idiom truncates a multiple return to one value, which silently
    -- drops `isOwn` and sends every ordinary source down the pet-fold path.
    local row, isOwn
    if not feigned then
        row, isOwn = rowForSource(pass, src, index, isSortColumn)
    end
    if not row then return end

    if isOwn then
        setCell(row, statKey, src, maxAmount, isCount)
        if touched then touched[row] = true end
    elseif isCount then
        -- A pet cannot die, and nothing else counts events. Reaching here
        -- would mean a counted stat grew a pet-shaped source; tally it on
        -- the pet's own row rather than inventing a fold for it.
        setCell(row, statKey, src, maxAmount, true)
        touched[row] = true
    elseif not foldPet(row, statKey, src) then
        pass.unfolded = pass.unfolded + 1
    end

    -- The column max belongs on every cell in the column, including ones
    -- a pet fold created without it.
    local cell = row.values[statKey]
    if cell and cell.maxAmount == nil and not isCount then
        cell.maxAmount = maxAmount
    end
end

--- Scale a counted column to the largest tally this pass produced, and withdraw
--- its column total.
---
--- Exists only for counted columns, and only because `column.maxAmount` is 0 for
--- Deaths: a bar scaled to 0 draws full for everybody. The max here is computed
--- out of counters this file produced — plain integers, so comparing them is
--- legal mid-pull where comparing two meter values would not be.
---
--- The total is DELETED rather than republished: the session's totalAmount is not
--- this column's, and leaving it would put a header total and a percent column of
--- nonsense on the grid.
local function normalizeCountedMax(pass, statKey, touched)
    local highest = 0
    for row in pairs(touched) do
        local cell = row.values[statKey]
        if cell and cell.total > highest then highest = cell.total end
    end
    if highest < 1 then highest = 1 end
    for row in pairs(touched) do
        row.values[statKey].maxAmount = highest
    end
    pass.columnTotals[statKey] = nil
end

--- Read one column from the provider and index every source in it by GUID.
---
--- The pet fold lives here, and so does its refusal: foldPet holds the
--- CanCompare2 gate and answers false while restricted, at which point the pet's
--- contribution is simply not counted (see the header's note on why dropping
--- beats a phantom row or a mid-pull error). The refusals are tallied on the
--- pass and reported once, not per source.
local function scanColumn(pass, statKey)
    -- "aggregate": the bracket this runs inside (issue #47).
    local column = Provider.GetColumn(pass.sessionType, statKey, pass.sessionID, "aggregate")
    pass.columns[statKey] = column
    pass.columnTotals[statKey] = column.totalAmount
    if column.reason and pass.reason == nil then pass.reason = column.reason end

    local stat = Const.STAT_BY_KEY[statKey]
    local isCount = stat and stat.isCount or false

    -- A COUNTED COLUMN HAS NO USABLE MAX FROM THE SESSION. Deaths reports
    -- maxAmount 0 along with its zero totals, and a bar scaled to 0 draws full
    -- for everybody. The max is computed by normalizeCountedMax below, after the
    -- tally.
    local maxAmount = not isCount and column.maxAmount or nil
    local isSortColumn = (statKey == pass.sortColumn)
    local touched = isCount and {} or nil

    -- THE FEIGN FILTER, and it lives here rather than anywhere downstream.
    --
    -- C_DamageMeter hands a Feign Death a valid deathRecapID, so a hunter's
    -- feign arrives as an ordinary Deaths source and is counted like one. The
    -- drop has to happen BEFORE rowForSource — see placeSource, which carries it.
    --
    -- Pruned once per pass rather than per source: modules/Feign.lua walks the
    -- group to find anyone confirmed dead, and doing that per source would walk
    -- it once per death. It exits on one boolean when nobody has ever feigned,
    -- which is every run but a hunter's.
    local Feign = isCount and NS.Feign or nil
    if Feign and Feign.Prune then Feign.Prune() end

    -- HOISTED OUT OF THE LOOP, and out of this function. Nothing inside the walk
    -- can arm or disarm a recording, so the whole question is settled once per
    -- column instead of once per death row.
    local traceJudge = judgeTracer(Feign)

    for index, src in ipairs(column.sources) do
        local feigned = judgeDeath(Feign, traceJudge, src)
        placeSource(pass, statKey, src, index, isSortColumn, feigned, maxAmount, isCount, touched)
    end

    if touched then normalizeCountedMax(pass, statKey, touched) end
end

--- Put the pass's rows in the window's order, and say which order that was.
---
--- Written as a ladder because the fallbacks are the interesting part: every
--- mode ends at `provider`, which cannot fail. The name returned is the mode
--- that ACTUALLY took effect, which is what the debug line records.
---
--- ONLY EVER REACHED UNRESTRICTED. While the Combat restriction is active the
--- pass takes the identity build instead, which has its own order — the engine's
--- — so the ladder below never has to degrade for secrecy. That is what retired
--- the sort freeze: it existed to hold a GUID order steady through a pull, and
--- mid-pull rows no longer have GUIDs to hold.
---
--- @return string  the mode applied: the window's own, or "provider"
local function applySortMode(pass)
    local rows, mode = pass.rows, pass.mode

    if mode == "roster" then
        orderByRoster(rows)
        return mode
    end

    if mode == "name" then
        if orderByName(rows, pass.sortAscending) then return mode end
        orderByProvider(rows, pass.sortAscending)
        return "provider"
    end

    -- THE DIRECTION SURVIVES THE FALLBACK, and it applies to `provider` mode
    -- chosen outright as well. It used to be dropped on both counts, so a window
    -- on `provider` mode had a header arrow that flipped over rows which never
    -- moved — the same defect the restricted build had, one rung up the ladder.
    if mode ~= "value" then
        orderByProvider(rows, pass.sortAscending)
        return "provider"
    end

    if orderByValue(rows, pass.sortColumn, pass.sortAscending) then return mode end

    orderByProvider(rows, pass.sortAscending)
    return "provider"
end

--- Fill in `sortValue` and each cell's `columnTotal` / `percent`.
---
--- Taken in ONE pass over the rows that survived the cap rather than over every
--- source: `sortValue` scales the name column's bar, and `percent` is the only
--- number in the whole addon this file computes rather than copies. Both are
--- done after the cap because doing them earlier would divide for rows nobody
--- will see.
local function deriveRowFacts(kept, pass)
    local columnTotals = pass.columnTotals

    for i = 1, #kept do
        local row = kept[i]
        local cell = row.values[pass.sortColumn]
        row.sortValue = cell and cell.total

        for _, statKey in ipairs(pass.keys) do
            local c = row.values[statKey]
            if c then
                -- The column's total on the CELL as well as on the result, so a
                -- renderer holding one cell can show "x of y" without carrying
                -- the result table down with it. Opaque, exactly as it arrived.
                c.columnTotal = columnTotals[statKey]
                -- A division, and therefore legal only on accessible operands.
                -- percentOf holds that gate and answers nil rather than
                -- approximating, which is most of a pull — the percent text
                -- slots go quiet in combat by design (modules/Format.lua).
                c.percent = percentOf(c.total, c.columnTotal)
            end
        end
    end
end

--- ONE line per pass, arguments only — the format string is never built at the
--- call site and nothing here concatenates (debug-logging-§3).
---
--- Through DebugSteady rather than Debug, because a pass on a 0.25s timer reports
--- the same eight fields four times a second and evicts the buffer with them. A
--- CHANGE still emits on the pass it happens; see core/DebugLogSetup.lua.
local function logPass(pass, keptCount)
    if not State.debug then return end
    NS.DebugSteady(pass.windowId, "Aggregator",
        "window=%s cols=%d rows=%d dropped=%d unfolded=%d sort=%s/%s reason=%s",
        tostring(pass.windowId), #pass.keys, keptCount, pass.dropped, pass.unfolded,
        pass.mode, pass.applied, pass.reason or "ok")
end

--- Hang the named result fields on the row array itself.
---
--- The result table IS the row array (see the header), so `result.rows` and
--- `ipairs(result)` walk one object. `sortTotal` rides along because the
--- header's "group total" is the sort column's, and the window would otherwise
--- have to know which column that was.
local function assembleResult(kept, pass)
    kept.rows            = kept
    kept.columns         = pass.columns
    kept.columnTotals    = pass.columnTotals
    kept.sortColumn      = pass.sortColumn
    kept.sortTotal       = pass.columnTotals[pass.sortColumn]
    -- Published so the window can say WHY a mid-pull grid reads differently:
    -- rows came from identity correlation rather than the GUID join, and
    -- `ambiguous` means at least one class+spec pair could not be told apart and
    -- had its secondary cells left empty on purpose.
    -- WHICH ORDER ACTUALLY TOOK EFFECT, as opposed to the one the window asked
    -- for. Mid-pull every mode degrades to `provider`, and modules/Window.lua has
    -- no other way to tell the player that the arrow on the header is describing
    -- a request rather than the grid under it.
    kept.applied         = pass.applied
    kept.identityMode    = pass.identityMode
    kept.ambiguous       = pass.ambiguous
    -- How many rows `ambiguous` actually cost. modules/Window_Header.lua puts it
    -- on screen: issue #22 measured both alternatives to the blanking rule dead,
    -- so the blanks are permanent and saying how many there are is the whole of
    -- what is left to do about them.
    kept.ambiguousRows   = pass.ambiguousRows or 0
    -- Present only on an identity pass with the debug flag on — see the
    -- rectangle's header. nil is the normal answer and means "not measured",
    -- never "nothing was wrong".
    kept.identityStats   = pass.identityStats
    kept.reason          = pass.reason
    kept.durationSeconds = Provider.GetSessionDuration(pass.sessionType, pass.sessionID)
    return kept
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------

--- Every row for one window, ordered and capped, plus the columns they came
--- from and the header's facts.
---
--- Callable as `Aggregator.Build(window)` or `Aggregator:Build(window)` —
--- modules/Window.lua uses the colon form, and a silent argument shift there
--- would build the wrong window rather than error.
---
--- `parentKey` is the perf bracket the CALLER runs inside, handed to Perf.Note so
--- a capture observes the nesting instead of trusting the descriptor
--- (performance-§3, issue #47). modules/Window.lua's refresh passes "refresh".
--- An export build passes nothing, because it runs inside no bracket, and naming
--- one it is not in would be the false claim this argument exists to replace.
---
--- @param window table  a window config from the profile
--- @param parentKey string|nil
--- @return table  the result table, which is also the row array (see the header)
function Aggregator.Build(a, b, c)
    local window, parentKey = a, b
    if a == Aggregator then window, parentKey = b, c end
    if type(window) ~= "table" then return { rows = {}, columns = {} } end

    local t0 = Perf.on and debugprofilestop()

    local pass = newPass(window)

    -- TWO BUILDS, chosen by whether the join key exists at all. The GUID join is
    -- the exact one and runs whenever `sourceGUID` is plain; under the Combat
    -- restriction it is secret, and identity correlation is what stands in for
    -- it (see the section header). The choice is made ONCE per pass rather than
    -- per source, so a grid is never half one shape and half the other.
    if pass.identityMode then
        Aggregator._identity.buildByIdentity(pass)
        -- Engine order IS the ranking, and it is the only order available: value
        -- sorting needs comparisons, and the frozen order is keyed on GUIDs that
        -- no longer resolve. `applied` reports what actually happened.
        --
        -- THE DIRECTION STILL APPLIES. It used to be discarded here, which is why
        -- clicking a header to flip the grid did nothing for the whole of a pull.
        -- Reversing is a permutation rather than a comparison (see reverseRows),
        -- so it is legal on secrets — and it puts the rows the sort column never
        -- named first, which is the same answer `value` mode gives out of combat
        -- for a missing cell.
        orderByProvider(pass.rows, pass.sortAscending)
        pass.applied = "provider"
    else
        for _, statKey in ipairs(pass.keys) do scanColumn(pass, statKey) end
        pass.applied = applySortMode(pass)
    end

    local kept = Aggregator.ApplyRowLimit(pass.rows, window.rows or {})
    deriveRowFacts(kept, pass)

    if t0 then Perf.Note("aggregate", debugprofilestop() - t0, parentKey) end

    logPass(pass, #kept)
    return assembleResult(kept, pass)
end

--- The most recent identity pass's correlation stats, or nil.
---
--- KEPT BEYOND THE PASS because `/mm debug identity` is typed after the pull it
--- is about and has no window handle to ask. One pass's worth, replaced by the
--- next: a history would be a memory leak on a 0.25s timer, and the question the
--- report answers is about the grid the player is looking at.
---
--- nil means the stats were never built — the debug flag was off, or the pass
--- was the GUID join, which correlates nothing. It never means "measured, and
--- clean".
---
--- @return table|nil
function Aggregator.LastIdentityStats()
    return Aggregator._identity.lastIdentityStats
end

--- Apply rows.maxRows and rows.alwaysShowSelf.
---
--- Split out of Build because it is the one piece of this file a settings change
--- can exercise on its own, and because the self-pinning rule reads as a rule
--- rather than as three lines at the bottom of a long function.
---
--- @param rows table  ordered rows, modified in place
--- @param rowsConfig table  the window's `rows` config group
--- @return table  the same array, truncated
function Aggregator.ApplyRowLimit(rows, rowsConfig)
    local cap = tonumber(rowsConfig and rowsConfig.maxRows) or 0
    -- 0 means "as many as fit", which the WINDOW decides from its own height;
    -- the aggregator only enforces the hard ceiling that stops a corrupted
    -- config asking the row pool for thousands of frames.
    if cap <= 0 or cap > Const.MAX_ROWS then cap = Const.MAX_ROWS end
    if #rows <= cap then return rows end

    -- Find the player BEFORE truncating, so the pin below knows whether they
    -- were about to fall off.
    local selfRow = nil
    for i = cap + 1, #rows do
        if rows[i].isPlayer then selfRow = rows[i] break end
    end

    for i = #rows, cap + 1, -1 do rows[i] = nil end

    -- The most-requested behavior of every meter ever written: never lose
    -- yourself off the bottom of the list. The last visible slot is spent on the
    -- player, keeping the row count exactly at the cap.
    if selfRow and rowsConfig and rowsConfig.alwaysShowSelf and cap > 0 then
        rows[cap] = selfRow
    end

    return rows
end

-- ---------------------------------------------------------------------------
-- Test rows — peeled to modules/Aggregator_Preview.lua
-- ---------------------------------------------------------------------------
--
-- `Aggregator.TestGroup`, `TestColumn`, `TestRecap` and `TestSourceDetail`, and
-- the four preview tables behind them, sit in modules/Aggregator_Preview.lua,
-- which loads immediately after this file. They are placeholder DATA and hold no
-- upvalue of this file's at all — nothing crosses the line in either direction —
-- which is what made them the second cut layout-§1's cap needed once issue #30's
-- identity seam had been taken.

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
--
-- Bus subscriptions only — core/MultiMeters.lua owns every game event.
--
-- THE `Activating` EDGE IS NO LONGER LISTENED FOR. It used to be the last legal
-- moment to take a value-sort, and that sort's result was frozen and reapplied
-- for the whole pull. Both halves are gone: mid-pull rows are keyed on their
-- position rather than on a GUID, so there is no order to freeze and nothing to
-- reapply it to. The engine's own ranking of the sort column is the order now,
-- and it is live rather than a snapshot. modules/Window.lua still redraws on the
-- transition, which is all that was ever needed here.

function Aggregator:OnEnable()
    self:RegisterMessage(MSG.METER_RESET,     "OnMeterReset")
    self:RegisterMessage(MSG.PROFILE_CHANGED, "OnMeterReset")
end

--- The cache this module owns describes a fight that no longer exists once the
--- meter is reset or the profile changes.
function Aggregator:OnMeterReset()
    State.WipeCache("Aggregator")
end
