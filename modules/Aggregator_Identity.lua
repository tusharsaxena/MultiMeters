-- modules/Aggregator_Identity.lua
--
-- The grid drawn while the GUID is secret, and the rectangle that measures it.
--
-- ---------------------------------------------------------------------------
-- WHY THIS FILE EXISTS
-- ---------------------------------------------------------------------------
--
-- It is one half of modules/Aggregator.lua, moved rather than rewritten. That
-- file was over layout-§1's 1500-line cap and issue #30 names this as the seam:
-- the build pipeline — row assembly, ordering, the one-stage-at-a-time scan,
-- Build — is a single algorithm whose header narrates it in the order the code
-- runs it, and cutting inside that would cost a reader more than the cap saves.
-- The two blocks here are not part of it. They exist because the client stopped
-- handing out GUIDs, they answer a question the aggregator proper never asks,
-- and they read as one subject end to end.
--
-- Nothing changed on the way across. The code, its comments and its order are
-- what they were; what is new is the seam. modules/Aggregator.lua publishes the
-- row-assembly helpers this build shares with the GUID join on
-- `Aggregator._identity`, and this file resolves them into upvalues at FILE
-- SCOPE — which is why its TOC position is load-bearing and says so — then hands
-- `buildByIdentity` back on the same table. `lastIdentityStats` is the one
-- private the peel had to publish: it is written at the end of a pass here and
-- read by `Aggregator.LastIdentityStats` there, so it lives on the seam table
-- instead of in a file-local nobody else could reach.

local _, NS = ...

local Aggregator = NS.Aggregator

local Provider = NS.Provider
local Roster   = NS.Roster
local Secrets  = NS.Secrets
local Const    = NS.Constants

-- The seam modules/Aggregator.lua publishes, resolved ONCE at load — never a
-- namespace lookup on the build path (performance-§2). This file loads
-- immediately after that one, so the table is always there.
local Seam          = Aggregator._identity
local newRow        = Seam.newRow
local setCell       = Seam.setCell
local isEnemySource = Seam.isEnemySource
local plainTruth    = Seam.plainTruth
local UNRANKED      = Seam.UNRANKED


-- ---------------------------------------------------------------------------
-- IDENTITY MODE — the grid while the GUID is secret
-- ---------------------------------------------------------------------------
--
-- Under the Combat restriction `sourceGUID` is SecretWhenInCombat, so the GUID
-- join below cannot run: a source can be neither keyed on, compared, nor looked
-- up. Two fields that IDENTIFY a source do stay plain — `classFilename` and
-- `isLocalPlayer` — and a third, `specIconID`, was believed to (see the note at
-- the end of this header: it is not secret, it is absent). That is enough to
-- build the grid a different way, and not enough to build it well:
--
--   * the SORT column's `combatSources` is the row list, in the order the engine
--     returned it, which is the ranking. Row identity is its POSITION;
--   * every other column is read on its own and correlated to those rows by an
--     identity key built from the three plain fields;
--   * a key that appears twice in ANY column is AMBIGUOUS — two players of the
--     same class and spec — and every secondary cell for it is left empty rather
--     than filled with a number that might belong to the other one. Every column
--     is swept for that BEFORE any cell is written (detectCollisions): the sweep
--     used to run column by column as the fill walked them, which let a key the
--     third column proved ambiguous keep the cells the second had already
--     written.
--
-- That last rule is the whole reason this is honest. An empty cell is a visible
-- absence; a mislabeled number is a lie the player cannot see.
--
-- WHAT THE KEY COSTS AT RAID SIZE, and why that is not a defect in the key.
--
-- This header used to say the key was really class plus "is it me", because
-- `specIconID` was believed absent from a raid source row for every player but
-- the local one. That was issue #24, and it is CLOSED AS NOT REPRODUCING.
-- Measured 2026-09-09 on an 18-member raid, mid-pull, restriction active:
-- `specIconID` reads `plain 10/10` with six distinct values, and the collided
-- keys carry real icon ids (`MAGE_135846_false`, not `MAGE_0_false`). The key
-- has all three parts it was designed to have.
--
-- What a raid has is DUPLICATE CLASS-AND-SPEC PAIRS -- two hunters, three mages,
-- three paladins and two priests in that one pull -- which is precisely the case
-- the refusal above exists for. The cost is real and permanent: 23 of 126
-- correlated cells filled, 10 of 18 rows wearing a collided key, and `unmatched`
-- ZERO in every column across three captures of the pull. The correlation is not
-- failing to match. There is nothing left to tell those players apart with.
--
-- ALL THREE WAYS OUT WERE MEASURED DEAD ON THE SAME DAY, which is why this code
-- is not going to get cleverer and the honest thing to do was to say so on
-- screen instead:
--
--   * WIDEN THE KEY. The mid-pull field audit answers "No usable candidates":
--     every field that varies per player is secret, and every plain field is
--     already in the key or carries one value for the whole group.
--   * PAIR BY POSITION. A column returns a SUBSET of a collided key's players --
--     a key covering three rows was named by Absorbs with a single seat -- so
--     there is no N-to-N pairing to make, whatever the ordering's stability.
--   * LET THE CLIENT DO THE JOIN. Handing a source's own secret `sourceGUID`
--     back to the meter answers `raised`: the client refuses the argument.
--
-- So `pass.ambiguousRows` is published beside `pass.ambiguous`, and
-- modules/Window_Header.lua puts the count on the header line. Issue #22 is now
-- that line and nothing else.
--
-- The local player is the one row that keeps a real GUID: `isLocalPlayer` is
-- plain and `UnitGUID("player")` never was secret, so their row is keyed on the
-- roster's own GUID and carries the roster's name and role.
--
-- Verified against Blizzard's field annotations and against Scoot's Damage Meter
-- Y, which solves it the same way.

--- The plain triple that stands in for a GUID while the GUID is secret.
local function identityKey(src)
    local class = src.classFilename
    if Secrets.IsSecret(class) then class = nil end
    local icon = src.specIconID
    if Secrets.IsSecret(icon) then icon = nil end
    -- Concatenation only, on values just proved plain. Never `..` on a secret.
    return (class or "UNKNOWN") .. "_" .. tostring(icon or 0)
        .. "_" .. tostring(plainTruth(src.isLocalPlayer))
end

--- One correlated column: identity key -> the figures to show, plus the keys
--- that turned out to be ambiguous.
---
--- THREE PARALLEL MAPS RATHER THAN ONE MAP OF TABLES. A cell needs the total,
--- the rate and (for a counted stat) the recap id, and a table per source would
--- be one allocation per source per column — twenty players times six columns on
--- every refresh, four times a second. Three maps is three allocations per
--- column whatever the group size.
---
--- THE RATE IS NOT OPTIONAL, which is what its absence proved. The shipped text
--- layout is `leftSlot = "smart"`, which on a RATE stat is `amountPerSecond`, so
--- for Damage and Healing the figure on screen IS the rate: a cell carrying only
--- the total draws its bar and renders no text at all (modules/Row.lua, where no
--- slot has a fallback). Damage looked right because it is the sort column and
--- goes through setCell; every other rate column was silent.
---
--- A counted stat (Deaths) reports one source row per event, so repeats of a key
--- are the same player dying twice and are TALLIED. For every other stat a
--- repeat is a genuine collision, because a player appears at most once — and
--- the collision was already found by detectCollisions, before any column was
--- filled. All this does with a repeat now is keep the FIRST figure, which is
--- the one the row would have taken anyway; whether the row may keep it at all
--- is fillCorrelated's question, asked against the whole-pass set.
local function correlateColumn(column, isCount, keys)
    -- byRecap only exists for a counted stat, which is the only kind that has a
    -- recap id to carry: five columns out of six would otherwise allocate a map
    -- per refresh to hold nothing.
    -- `seen` is the set of keys this column MENTIONED, which is not the same
    -- question as `byKey`, which is the set it produced a FIGURE for. The
    -- difference between them is the diagnosis: a key the column named and still
    -- could not fill is the fault the identity line exists to surface, and a key
    -- it never named is a player who simply did none of this stat.
    local byKey, byRate, seen, keyCount = {}, {}, {}, 0
    local byRecap = isCount and {} or nil
    -- The identity build's half of `row.deaths`. One array per DYING identity
    -- key, not one table per source per column — the allocation the note above
    -- refuses. Counted stats are one column of six and most keys never appear
    -- here at all, so this costs nothing on a run where nobody dies.
    local byDeaths = isCount and {} or nil
    for i, src in ipairs(column.sources) do
        local key = keys[i]
        -- nil is an enemy source, dropped by the sweep that built these.
        if key ~= nil then
            if isCount then
                seen[key] = true
                byKey[key] = (byKey[key] or 0) + 1
                -- The FIRST row wins the recap, as it does in setCell: the API
                -- returns deaths newest-first and the death a player wants to
                -- look at is the one that just happened. `deathRecapID` is
                -- NeverSecret, so it is a plain value in a plain map.
                if byRecap[key] == nil then byRecap[key] = src.deathRecapID end
                -- ...and every row lands in the array, newest first, exactly as
                -- setCell accumulates it on the GUID path. Two builds, one
                -- shape: a change made to one and not the other is invisible
                -- until somebody drills in mid-pull.
                local list = byDeaths[key]
                if list == nil then list = {} byDeaths[key] = list end
                -- False, never nil — see setCell. Two builds, one shape.
                local id = src.deathRecapID
                if id == nil then id = false end
                list[#list + 1] = id
            elseif not seen[key] then
                seen[key] = true
                keyCount = keyCount + 1
                -- Copied, never examined — opaque exactly as they arrived, and
                -- they reach a widget setter or the formatter.
                byKey[key]  = src.totalAmount
                byRate[key] = src.amountPerSecond
            end
        end
    end
    return byKey, keyCount, byRate, byRecap, byDeaths, seen
end

--- Read one column onto the pass and hand it back. Shared by both halves of the
--- identity build so the bookkeeping is written once.
---
--- IDEMPOTENT, because the collision sweep below reads every column before the
--- fill does and the fill then reads them again. A second Provider.GetColumn per
--- column per refresh is a second trip through the meter shims four times a
--- second; the first answer is the one the whole pass is built on, so it is the
--- one kept. `reason` and `columnTotals` are recorded on that first take only,
--- which is what keeps the sort column's reason winning as it always has.
local function takeColumn(pass, statKey)
    local isCount = (Const.STAT_BY_KEY[statKey] or {}).isCount or false
    local column = pass.columns[statKey]
    if column ~= nil then return column, isCount end

    column = Provider.GetColumn(pass.sessionType, statKey, pass.sessionID)
    pass.columns[statKey] = column
    pass.columnTotals[statKey] = column.totalAmount
    if column.reason and pass.reason == nil then pass.reason = column.reason end
    return column, isCount
end

--- Every identity key standing for more than one source, across EVERY column,
--- found before a single cell is written.
---
--- ORDER MUST NOT DECIDE HONESTY, and for one release it did. `collisions` used
--- to be filled column by column as the fill walked them, so a key the third
--- column proved ambiguous had already been written into cells by the second —
--- and those cells stayed, carrying one priest's number under a row that might
--- be the other priest. The sort column's own pre-pass hid it whenever the sort
--- column named both players, which in a raid it usually does; the case that
--- escaped is a pair who appear in no column the window happens to sort on.
--- Nothing about that is a fill-order question, so the answer is computed before
--- the fill starts.
---
--- A COUNTED STAT IS NOT SWEPT. Deaths reports one row per event, so the same
--- key appearing twice is one player dying twice and says nothing about how many
--- players wear it.
---
--- THE KEYS IT BUILDS ARE KEPT, in `pass.keyOf[statKey][sourceIndex]`, and every
--- later reader takes them from there. identityKey is two concatenations, and it
--- used to be called twice per source per column — once in the fill and once
--- again in the union walk. Adding a third call for this sweep put 21% on a
--- restricted refresh, measured; handing the answers forward instead puts the
--- count at ONE and leaves the pass cheaper than it was before the sweep
--- existed. An enemy source gets no entry, which is not a shortcut: it is the
--- same source the fill drops, and nothing may key on it.
local function sweepColumn(pass, statKey, collisions, keyOf)
    if keyOf[statKey] ~= nil then return end

    local column, isCount = takeColumn(pass, statKey)
    local keys = {}
    local seen = (not isCount) and {} or nil
    for i, src in ipairs(column.sources) do
        if not isEnemySource(src) then
            local key = identityKey(src)
            keys[i] = key
            if seen then
                if seen[key] then collisions[key] = true end
                seen[key] = true
            end
        end
    end
    keyOf[statKey] = keys
end

local function detectCollisions(pass)
    local collisions = {}
    local keyOf = {}
    for _, statKey in ipairs(pass.keys) do
        sweepColumn(pass, statKey, collisions, keyOf)
    end
    -- THE SORT COLUMN NEED NOT BE ONE OF THE WINDOW'S OWN. `sortColumn` is kept
    -- whenever it names a real stat, and a stored config can point at a stat
    -- whose column was since removed — the build reads it anyway, to rank rows
    -- by. Sweeping `pass.keys` alone left that column with no keys and the row
    -- loop indexing nil.
    sweepColumn(pass, pass.sortColumn, collisions, keyOf)
    pass.keyOf = keyOf
    return collisions
end

--- A counted column scales every bar to the highest COUNT.
---
--- Those counters are ours and plain, so comparing them is legal mid-pull where
--- comparing two meter values would not be. The session's own max is useless
--- here: Deaths reports 0, and a bar scaled to 0 draws full for everybody.
local function rescaleCounted(pass, statKey)
    local highest = 0
    for i = 1, #pass.rows do
        local cell = pass.rows[i].values[statKey]
        if cell and cell.total > highest then highest = cell.total end
    end
    if highest < 1 then highest = 1 end
    for i = 1, #pass.rows do
        local cell = pass.rows[i].values[statKey]
        if cell then cell.maxAmount = highest end
    end
    pass.columnTotals[statKey] = nil
end

--- The row this source belongs on, started on first sight of it.
---
--- The local player keeps a REAL guid — `isLocalPlayer` is plain and
--- `UnitGUID("player")` is not secret — so their row joins the roster's name and
--- role. Everyone else is keyed on their POSITION, a plain string the row pool
--- and the drill-down can hold without ever touching the secret one.
local function identityRow(pass, src, index, localGuid, key, unranked)
    local isLocal = plainTruth(src.isLocalPlayer)

    -- A row built from a NON-sort column is keyed on its identity rather than on
    -- a rank, because it has no rank: it is here precisely because the sort
    -- column never mentioned it. The key is a plain string, and a stable one, so
    -- the same healer keeps the same row identity between refreshes.
    local rowGuid = (isLocal and localGuid) or
        (unranked and ("ident:" .. key)) or ("rank_" .. index)

    local row = pass.byGuid[rowGuid]
    if row ~= nil then return row end

    row = newRow(rowGuid, src, pass.windowId)
    -- newRow takes identity from the roster where the roster has it, which here
    -- is the local player and nobody else. For every other row the source's own
    -- fields are all there is — and `name` among them is ConditionalSecret, so it
    -- travels to SetText and nowhere else.
    if not isLocal then
        row.isPlayer      = false
        row.isLocalPlayer = false
    end
    row.identityKey   = key
    -- Past every ranked row, in first-seen order, exactly as the GUID join parks
    -- a player who appears in some other column but not in the sort one.
    row.providerIndex = unranked and (UNRANKED + index) or index
    pass.byGuid[rowGuid] = row
    if pass.byIdentity[key] == nil then pass.byIdentity[key] = row end
    pass.rows[#pass.rows + 1] = row
    return row
end

--- A SOURCE THIS COLUMN KNOWS AND NO ROW STANDS FOR GETS ITS OWN ROW.
---
--- Without this the row list was whatever the SORT column happened to mention,
--- so a healer who did no damage and a player whose only contribution was one
--- interrupt simply were not on the grid for the whole of a pull — they
--- reappeared the moment it ended, which reads as rows flickering into existence
--- rather than as a rule. The GUID join has always taken the union of every
--- column; this is the same union, reached without a key.
---
--- Only for a key that is unambiguous AND has a figure: a row invented for a
--- collided key could never be filled from any column, and an always-empty row
--- is noise.
local function adoptUnknownSources(pass, column, keys, byKey, collisions, localGuid)
    for index, src in ipairs(column.sources) do
        local key = keys[index]
        if key ~= nil
            and pass.byIdentity[key] == nil and byKey[key] ~= nil and not collisions[key] then
            identityRow(pass, src, index, localGuid, key, true)
        end
    end
end

--- Fill one non-sort column by correlating it back onto the rows already built.
local function fillCorrelated(pass, statKey, collisions, localGuid)
    local column, isCount = takeColumn(pass, statKey)
    local keys = pass.keyOf[statKey]
    local byKey, keyCount, byRate, byRecap, byDeaths, seen =
        correlateColumn(column, isCount, keys)
    pass.corrKeys = pass.corrKeys + keyCount
    -- Kept for the rectangle, which cannot be built while the fill is running:
    -- it is scored against the FINAL row list, and the fill is still adding rows
    -- to it. Debug-only, so a normal pass allocates neither map.
    if pass.corrSeen then pass.corrSeen[statKey] = seen end

    adoptUnknownSources(pass, column, keys, byKey, collisions, localGuid)

    for i = 1, #pass.rows do
        local row = pass.rows[i]
        local value = byKey[row.identityKey]
        -- A collided key is left EMPTY rather than filled from a source that
        -- might be the other player's. That refusal is the whole warrant for
        -- correlating on class and spec at all.
        pass.corrPossible = pass.corrPossible + 1
        if value ~= nil and not collisions[row.identityKey] then
            pass.corrFilled = pass.corrFilled + 1
            -- Three fields in the constructor, never four: the literal's size
            -- is fixed at compile time, so spelling `deathRecapID` here would
            -- widen every cell in every column to carry a field only Deaths ever
            -- fills.
            local cell = {
                total     = value,
                rate      = byRate[row.identityKey],
                maxAmount = not isCount and column.maxAmount or nil,
            }
            row.values[statKey] = cell

            -- INSIDE the collision guard, deliberately. A collided key is
            -- left empty above because the source might be the other player's,
            -- and a death list attached outside that refusal would put one
            -- player's deaths under the other player's name — the one
            -- mislabelling this file refuses everywhere else.
            local deaths = byDeaths and byDeaths[row.identityKey]
            if deaths ~= nil then row.deaths = deaths end

            local recap = byRecap and byRecap[row.identityKey]
            if recap ~= nil then
                cell.deathRecapID = recap
                -- Promoted onto the ROW as well, because it identifies the
                -- player's death rather than a column's number — the same
                -- promotion setCell makes, so the tooltip and the death view
                -- read one place.
                row.deathRecapID = recap
            end
        end
    end

    if isCount then rescaleCounted(pass, statKey) end
end

-- ---------------------------------------------------------------------------
-- The correlation rectangle — issue #22's instrumentation
-- ---------------------------------------------------------------------------
--
-- WHAT THE SHIPPED LINE COULD NOT ANSWER, and why this exists.
--
-- `identity rows=N keys=N collisions=N filled=N/N` was written to separate two
-- faults — ambiguity doing its job, versus keys not matching between columns at
-- all — and at raid size it could separate neither:
--
--   * `collisions` counted KEYS. Six collided keys over eighteen rows bounds
--     nothing until you know how many rows those keys cover, which is the number
--     a capture has to be read against.
--   * `keys` summed each column's key count into one figure, so it was neither a
--     cardinality nor comparable to `rows`.
--   * `possible` accumulated inside the fill, against a row list the fill was
--     still GROWING. It was not rows x columns, so the arithmetic anybody would
--     do on a live capture was wrong before it started.
--
-- What replaces it is a rectangle scored AFTER the fill, over the final row
-- list: every row against every correlated column, each cell landing in exactly
-- one of four buckets. `filled` and `collided` are the correlation working and
-- the correlation refusing. `absent` is the honest blank — the player did none
-- of this stat. `unmatched` is the fault: the column named this key and still
-- produced no cell, which means a field the correlation trusts is less stable
-- than it looks.
--
-- DEBUG-ONLY, all of it. Thirty rows times six columns four times a second buys
-- nothing the render path reads, and a diagnostic that costs frames is one the
-- player turns off before the pull you needed it for.

--- The most recent identity pass's stats, for a report typed after the pull.
---
--- ON THE SEAM TABLE rather than in a file-local, because the reader is
--- `Aggregator.LastIdentityStats` in modules/Aggregator.lua and a local here
--- would be unreachable from there. It is the one private the peel had to
--- publish; nothing else about this block changed.
Seam.lastIdentityStats = nil

--- Where each collided key's sources sat in every column.
---
--- ORDINALS AMONG THE GROUP SOURCES, not raw list indices: enemies are dropped
--- before the fill sees them, and numbering past them would describe a list this
--- addon never builds.
---
--- Collected for collided keys ONLY, because the question it answers is asked
--- about nothing else — whether two same-spec players could be paired by
--- POSITION when they cannot be told apart by key. That is a question about a
--- live client's ordering, so what ships is the capture and not the conclusion.
local function probePositions(pass, collisions)
    local positions = {}
    for _, statKey in ipairs(pass.keys) do
        local column = pass.columns[statKey]
        local keys = pass.keyOf[statKey] or {}
        local ordinal = 0
        for i in ipairs(column and column.sources or {}) do
            local key = keys[i]
            if key ~= nil then
                ordinal = ordinal + 1
                if collisions[key] then
                    local seats = positions[key]
                    if seats == nil then seats = {} positions[key] = seats end
                    local list = seats[statKey]
                    if list == nil then list = {} seats[statKey] = list end
                    list[#list + 1] = ordinal
                end
            end
        end
    end
    return positions
end

--- How many ROWS wear each identity key, off the final row list.
---
--- Rows rather than sources, because a row is what the player is looking at and
--- what a blank cell appears on. The histogram it feeds — `{ [1] = 14, [2] = 5 }`
--- reading as "fourteen keys worn alone, five worn by a pair" — is the one
--- measurement that bounds what widening the key could buy, before anything is
--- spent finding out whether it can be widened at all.
local function rowsPerKey(rows)
    local perKey = {}
    for i = 1, #rows do
        local key = rows[i].identityKey
        if key ~= nil then perKey[key] = (perKey[key] or 0) + 1 end
    end
    return perKey
end

--- Score one correlated column against every row on the grid.
local function scoreColumn(pass, statKey, collisions)
    local seen = pass.corrSeen[statKey] or {}
    local col = { rows = #pass.rows, filled = 0, collided = 0, absent = 0, unmatched = 0 }
    for i = 1, #pass.rows do
        local row = pass.rows[i]
        local key = row.identityKey
        -- Order matters: a collided key may also have been mentioned and may
        -- also have no cell, and reporting it as `unmatched` would send the next
        -- change hunting a matching bug that is not there.
        if key ~= nil and collisions[key] then
            col.collided = col.collided + 1
        elseif row.values[statKey] ~= nil then
            col.filled = col.filled + 1
        elseif key ~= nil and seen[key] then
            col.unmatched = col.unmatched + 1
        else
            col.absent = col.absent + 1
        end
    end
    return col
end

--- Everything `/mm debug identity` prints, built once at the end of a pass.
local function identityStats(pass, collisions)
    local stats = {
        rows         = #pass.rows,
        sortColumn   = pass.sortColumn,
        -- WHICH SESSION THIS RECTANGLE DESCRIBES. The field audit in
        -- core/Diagnostics.lua reads a source row to ask what the client
        -- annotates plain, and it has to read it from the session the pass was
        -- built on — asking the profile's first window instead answers about
        -- some other session, or about none, and prints "no source row" in the
        -- middle of a pull that plainly had one.
        sessionType  = pass.sessionType,
        sessionID    = pass.sessionID,
        keys         = 0,
        collidedKeys = 0,
        collidedRows = 0,
        filled       = 0,
        possible     = 0,
        multiplicity = {},
        columns      = {},
        -- Fill order, so two captures of one pull print in one order and can be
        -- read side by side.
        order        = {},
        positions    = probePositions(pass, collisions),
    }

    -- The size of the collision SET, not of the collided keys that reached a
    -- row: a pair who appear in no column the window sorts on get no rows at
    -- all, and their loss is the largest one this correlation can suffer.
    for _ in pairs(collisions) do stats.collidedKeys = stats.collidedKeys + 1 end

    for key, n in pairs(rowsPerKey(pass.rows)) do
        stats.keys = stats.keys + 1
        stats.multiplicity[n] = (stats.multiplicity[n] or 0) + 1
        if collisions[key] then stats.collidedRows = stats.collidedRows + n end
    end

    for _, statKey in ipairs(pass.keys) do
        -- THE SORT COLUMN IS NOT IN THE RECTANGLE. Nothing is correlated onto
        -- it: every row on the grid came from it, and counting it as filled
        -- would inflate the one ratio the capture is read for.
        if statKey ~= pass.sortColumn then
            local col = scoreColumn(pass, statKey, collisions)
            stats.columns[statKey] = col
            stats.order[#stats.order + 1] = statKey
            stats.filled   = stats.filled + col.filled
            stats.possible = stats.possible + col.rows
        end
    end

    Seam.lastIdentityStats = stats
    return stats
end

--- How many ROWS wear a collided key — the figure the header shows (issue #22).
---
--- ROWS, NOT KEYS, and the difference is the whole point. Two mages of one spec
--- beside a lone priest is one collided KEY and two blanked ROWS, and a header
--- that said "1" would be describing the addon's bookkeeping rather than what the
--- player is looking at. This is the same distinction the correlation rectangle
--- had to be rewritten for, arrived at from the other direction.
---
--- NOT THE RECTANGLE'S FIGURE, deliberately, even though it is the same number.
--- `identityStats` exists only while the debug flag is on and costs a walk of
--- every row against every column; the header needs this on every pass, for every
--- player, with no flag. One walk of the final row list is what that costs.
---
--- Every count here is over OUR OWN plain integers and a set keyed on plain
--- strings, so it is legal mid-pull where arithmetic on a meter value would not
--- be.
local function countAmbiguousRows(rows, collisions)
    local n = 0
    for i = 1, #rows do
        local key = rows[i].identityKey
        if key ~= nil and collisions[key] then n = n + 1 end
    end
    return n
end

--- Build every row from the sort column's source list, then fill the rest of the
--- grid by identity correlation.
local function buildByIdentity(pass)
    local sortKey = pass.sortColumn
    -- The sort column FIRST, so it still wins `pass.reason`, then every column
    -- swept for collisions before a cell is written. takeColumn is idempotent,
    -- so the sweep costs no second read.
    local column, sortCount = takeColumn(pass, sortKey)
    local collisions = detectCollisions(pass)
    local localGuid = Roster.LocalGUID()

    for index, src in ipairs(column.sources) do
        if isEnemySource(src) then
            pass.dropped = pass.dropped + 1
        else
            local row = identityRow(pass, src, index, localGuid, pass.keyOf[sortKey][index])
            setCell(row, sortKey, src, not sortCount and column.maxAmount or nil, sortCount)
        end
    end

    for _, statKey in ipairs(pass.keys) do
        if statKey ~= sortKey then fillCorrelated(pass, statKey, collisions, localGuid) end
    end

    if sortCount then rescaleCounted(pass, sortKey) end
    pass.ambiguous = next(collisions) ~= nil
    pass.ambiguousRows = countAmbiguousRows(pass.rows, collisions)

    -- ONE line per pass, and only while the flag is on. Every figure on it is
    -- now a whole-pass one: `keys` is a cardinality, `rows` next to `collided`
    -- gives the ceiling, and `filled/possible` is a real rectangle. The per
    -- column split that says WHICH bucket the misses fell in is too much for a
    -- standing log at four passes a second, so it waits on `/mm debug identity`.
    if pass.corrSeen then
        local stats = identityStats(pass, collisions)
        pass.identityStats = stats
        NS.DebugSteady(pass.windowId, "Aggregator",
            "identity rows=%d keys=%d collided=%d/%d filled=%d/%d",
            stats.rows, stats.keys, stats.collidedKeys, stats.collidedRows,
            stats.filled, stats.possible)
    end
end

-- The build itself goes back to modules/Aggregator.lua, which chooses between it
-- and the GUID join once per pass.
Seam.buildByIdentity = buildByIdentity
