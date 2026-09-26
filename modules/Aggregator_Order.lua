-- modules/Aggregator_Order.lua
--
-- How the aggregator's rows are put in order, and how many of them are kept.
--
-- ---------------------------------------------------------------------------
-- WHY THIS FILE EXISTS
-- ---------------------------------------------------------------------------
--
-- It is a part of modules/Aggregator.lua, moved rather than rewritten. That
-- file had grown back to 1432 lines after its first peel (issue #30), and the
-- 2026-09-26 automated-tests sweep (ATS-12) took it back under 1250 along this
-- seam. The build pipeline itself still reads end to end in that file: the
-- ladder that CHOOSES an ordering (`applySortMode`) is a stage and reads the
-- pass table, so it stayed. What moved is what the ladder and Build call: the
-- orderings, each a function of a row array and a direction, and the row cap,
-- which was already public. None of them reads a pass table or a file-local of
-- the parent except `UNRANKED`.
--
-- Nothing changed on the way across. The code, its comments and its order are
-- what they were. modules/Aggregator.lua publishes `Aggregator._order` with
-- `UNRANKED` on it; this file resolves that at FILE SCOPE — which is why its
-- TOC position after the parent is load-bearing and says so — and hangs the
-- orderings back on the same table. `ApplyRowLimit` and `SelfPinIndex` stay on
-- the module table, where modules/Window.lua and the tests already reach them.

local _, NS = ...

local Aggregator = NS.Aggregator

local Roster  = NS.Roster
local Secrets = NS.Secrets
local Const   = NS.Constants

-- The seam modules/Aggregator.lua publishes, resolved ONCE at load.
local Order    = Aggregator._order
local UNRANKED = Order.UNRANKED


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
--- one says: a column labeled "Player" sorts by player.
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
-- The row cap
-- ---------------------------------------------------------------------------

--- Apply rows.maxRows and rows.alwaysShowSelf.
---
--- Split out of Build because it is the one piece of the aggregator a settings change
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

--- Where the window's own "always show yourself" pin should come from.
---
--- ApplyRowLimit pins against ITS cap, which is the 40-row ceiling whenever
--- `rows.maxRows` is 0 (the shipped default) — but the window draws only what
--- fits its height, from wherever the scroll offset puts it. So the pin that
--- reaches the screen is this one, asked about the slice the window actually
--- draws: `entries[first .. first + visible - 1]`. ApplyRowLimit keeps its own
--- pin for the explicit-cap case, where the two agree.
---
--- Pure and allocation-free: WindowProto:Render calls it on every draw.
---
--- @param entries table  the ordered rows the window is about to draw
--- @param first number  index of the first drawn row (1 + scroll offset)
--- @param visible number  how many rows the window draws (`layout.maxRows`)
--- @param rowsConfig table|nil  the window's `rows` config group
--- @return number|nil  the player's index when it lies outside the slice and
---   the flag is on; nil otherwise
function Aggregator.SelfPinIndex(entries, first, visible, rowsConfig)
    if not (rowsConfig and rowsConfig.alwaysShowSelf) then return nil end
    if (visible or 0) < 1 then return nil end
    local n = #entries
    local last = first + visible - 1
    if last > n then last = n end
    for i = first, last do
        local e = entries[i]
        if e and e.isPlayer then return nil end
    end
    for i = 1, n do
        local e = entries[i]
        if e and e.isPlayer then return i end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Back across the seam
-- ---------------------------------------------------------------------------
--
-- `applySortMode` and Build in modules/Aggregator.lua call these through
-- `Aggregator._order`. `reverseRows` is not published: only orderByProvider
-- reaches it.
Order.orderByProvider = orderByProvider
Order.orderByValue    = orderByValue
Order.orderByName     = orderByName
Order.orderByRoster   = orderByRoster
