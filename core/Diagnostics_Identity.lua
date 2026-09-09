-- core/Diagnostics_Identity.lua
--
-- `/mm debug identity` — the issue #22 identity-correlation measurement.
--
-- ---------------------------------------------------------------------------
-- WHY THIS FILE EXISTS
-- ---------------------------------------------------------------------------
--
-- It is a peel of core/Diagnostics.lua, which sat over layout-§1's 1500-line
-- cap. The seam there is the PROBE: this one is self-contained, answers to one
-- issue, and can therefore be deleted with that issue — which it could not be
-- while it was a block in the middle of an 1800-line file.
--
-- It is NOT part of `/mm debug diag`, so nothing in the frame file reaches into
-- it: the entry point at the foot of this file is the only way in.
--
-- NOTHING WAS REWRITTEN ON THE WAY OUT. What follows is the block that used to
-- sit under the "Identity correlation" banner in core/Diagnostics.lua, in
-- its order.
--
-- The rules that file states — R1 (a stored figure is described, never
-- inspected), R2 and R3 — bind this file exactly as they bind that one, and the
-- `out` below is ITS `out`, taken off the shared table rather than redefined
-- here — so a line printed from this file still follows the route the report it
-- belongs to set.
--
-- TOC POSITION IS LOAD-BEARING: after core\Diagnostics.lua. `NS.Diagnostics`
-- and the `out` it takes off it are resolved at FILE SCOPE, so the file that
-- publishes them must load first.

local _, NS = ...

local Diagnostics = NS.Diagnostics

local out = Diagnostics.out

-- ---------------------------------------------------------------------------
-- Identity correlation — issue #22
-- ---------------------------------------------------------------------------
--
-- WHY A REPORT AND NOT A LOG LINE. At raid size the identity build leaves most
-- secondary cells blank, and the shipped debug line could not say which of the
-- two causes it was, because it counted collided KEYS and the ceiling turns on
-- collided ROWS. modules/Aggregator.lua now measures the rectangle; this prints
-- it, alongside the two things the rectangle cannot answer from inside the
-- addon at all:
--
--   * WHAT THE CLIENT ANNOTATES. The correlation key is `classFilename` plus
--     `specIconID` plus `isLocalPlayer` because those were the three plain
--     fields on a source row. Whether there is a fourth is a property of the
--     running client, not of this code, and the only honest way to find out is
--     to ask a real source row mid-pull.
--   * WHERE A DUPLICATE PAIR SAT. Pairing two same-spec players by POSITION is
--     the only direction left if the key cannot be widened, and it may only be
--     taken if the engine's ordering is stable. Two captures of one pull,
--     compared, answer that. One capture never can, so this prints the seats and
--     draws no conclusion.
--
-- Rule R1 holds throughout. Not one meter value is inspected: a figure is
-- DESCRIBED as plain or secret by the same concat probe the rest of this file
-- uses, and the counts printed are modules/Aggregator.lua's own plain integers.

-- The three fields modules/Aggregator.lua's identityKey is built from, restated
-- here as a list to CHECK AGAINST rather than imported. The point of the audit
-- is to find a field the key does not use, and importing the key's own opinion
-- of what exists is how a probe ends up confirming the code back to itself.
local IDENTITY_KEY_FIELDS = {
    classFilename = true,
    specIconID    = true,
    isLocalPlayer = true,
}

-- Fields on a source row that are plain but useless as a join key, so that a
-- reader is not sent chasing one. `sourceDisplayType` says friend-or-foe and is
-- the same for a whole raid; the recap id identifies a DEATH rather than a
-- player and is absent on every column but one.
-- What a MISSING value actually costs the identity key, for the fields it is
-- built from.
--
-- `isLocalPlayer` IS DELIBERATELY NOT HERE. A missing flag folds to `false`,
-- which is the correct answer for every row but one, so its absence costs
-- nothing — and printing "degraded" beside it in red, next to a line where that
-- IS true, sends a reader after a non-problem.
local ABSENCE_COST = {
    classFilename = "the key falls back to UNKNOWN for that row",
    specIconID    = "the key folds to 0 and collapses to class alone",
}

local NOT_A_KEY = {
    sourceDisplayType = "same for the whole group",
    deathRecapID      = "identifies a death, not a player",
}

--- The client's own inventory of a raw source row, or an empty list.
---
--- IT FOLLOWS THE STATS, not the profile. The rectangle was built on a
--- particular session and column, and asking the first stored window instead
--- answers about a different session or about none at all: the first version of
--- this printed "no source row to audit" in the middle of a pull that had three.
--- With no stats to follow there is nothing to be consistent with, and the
--- stored window is the best guess available.
---
--- Through modules/Provider.lua, which is the only file that may reach the meter
--- — and through its RAW probe rather than through GetColumn, because GetColumn
--- projects a source onto a fixed field list and an audit reading that could
--- only ever report the fields this addon already copies. Confirming our own
--- opinion back to ourselves is the failure this whole file exists to prevent.
local function sourceFields(stats)
    local P = NS.Provider
    if not (P and P.ProbeSourceFields) then return {} end

    local sessionType, sessionID, statKey
    if stats then
        sessionType, sessionID, statKey = stats.sessionType, stats.sessionID, stats.sortColumn
    else
        local windows = NS.Database and NS.Database.GetWindows and NS.Database.GetWindows()
        local data = windows and windows[1] and windows[1].data or {}
        sessionType, sessionID = data.sessionType, data.sessionID
    end

    local ok, fields = pcall(function()
        return P:ProbeSourceFields(sessionType or 1, statKey or "DamageDone", sessionID)
    end)
    return (ok and type(fields) == "table") and fields or {}
end

--- One field's verdict: the state word, and the note that says what to do.
---
--- THREE STATES, NOT TWO. A field the client sends for SOME sampled rows is
--- neither present nor absent, and it is the state that matters most: in a raid
--- `specIconID` arrives for the local player's row and no other (#24), which a
--- two-state verdict reports as a flat "plain" and buries.
---
--- A CANDIDATE IS ONLY A CANDIDATE IF IT DISCRIMINATES. `classification` is
--- plain and outside the key, so it printed as a candidate for one round — but a
--- field carrying one value for the whole raid is no more a join key than no
--- field at all. `distinct` is what separates the two, and it is why the probe
--- counts rather than samples one row.
local function fieldVerdict(field)
    if field.absent or field.present == 0 then
        local note = "  |cffff2020<- the addon READS this|r"
        local cost = ABSENCE_COST[field.name]
        if cost then note = note .. " — " .. cost end
        return "ABSENT", note
    end

    if field.present < field.sampled then
        local note = "  |cffff2020<- present on SOME rows only|r"
        if field.local_ then note = note .. ", including yours" end
        local cost = ABSENCE_COST[field.name]
        if cost then note = note .. " — on the rows without it, " .. cost end
        return "PARTIAL", note
    end

    if not field.plain then return "SECRET", "" end

    if IDENTITY_KEY_FIELDS[field.name] then return "plain", "  (already in the key)" end
    if NOT_A_KEY[field.name] then return "plain", "  (" .. NOT_A_KEY[field.name] .. ")" end

    local n = field.distinct
    if n == nil then return "plain", "" end
    if n <= 1 then
        return "plain", string.format(
            "  (one value across %d rows — no use as a key)", field.sampled)
    end
    return "plain", string.format(
        "  |cffffd100<- %d values across %d rows: WOULD widen the key|r", n, field.sampled)
end

--- One line per field, and a tally of the three states worth acting on.
local function printFieldRows(fields)
    local counts = { candidates = 0, absent = 0, partial = 0 }
    for _, field in ipairs(fields) do
        local state, note = fieldVerdict(field)
        if state == "ABSENT"  then counts.absent  = counts.absent + 1  end
        if state == "PARTIAL" then counts.partial = counts.partial + 1 end
        if note:find("WOULD widen", 1, true) then
            counts.candidates = counts.candidates + 1
        end
        out(string.format("  %-22s %-8s %-8s %-7s %-8s%s",
            field.name, field.type or "?", state,
            string.format("%d/%d", field.present or 0, field.sampled or 0),
            field.distinct and tostring(field.distinct) or "-", note))
    end
    return counts
end

--- What the tally means, said in words rather than left to be inferred.
---
--- ABSENT AND PARTIAL COME FIRST, because they are the only lines in this
--- section reporting a DEFECT rather than a fact about the client. A field the
--- projection reads and the client does not send is silently nil everywhere
--- downstream, and one of them — `specIconID` — is what the identity key rests
--- on.
local function reportFieldTally(counts)
    if counts.absent > 0 or counts.partial > 0 then
        out(string.format("  |cffff2020%d field(s) absent, %d on some rows only.|r",
            counts.absent, counts.partial))
        out("  Absent is not secret: it is nil out of combat too, so nothing")
        out("  downstream ever sees it. Report these first.")
    end

    if counts.candidates > 0 then
        out(string.format("  %d field(s) are plain, outside the key, and actually VARY.",
            counts.candidates))
        out("  Widening the key by one of them is issue #22's first direction.")
    else
        out("  No usable candidates: nothing outside the key is both plain and")
        out("  varying, so the key cannot be widened on this client.")
    end

    out("  `values` counts DISTINCT plain values across the sampled rows — a field")
    out("  with one value for the whole group cannot tell two players apart. It")
    out("  reads `-` for a secret field, which cannot be compared at all (rule R1);")
    out("  capture again AFTER the pull to get counts for those.")
end

--- Every field on a source row, with whether this context may put it in a line.
---
--- PLAIN IS THE WHOLE TEST for whether a field COULD be a key. A field this
--- context may put in a string is one the correlation could key on; a field it
--- may not is one it may not compare, add, or `..` — which is exactly what a
--- join key does. Whether it WOULD work is the `values` column beside it, and
--- the two questions are different: `classification` passes the first and fails
--- the second.
local function reportSourceFields(fields)
    out("|cff00ff00-- source fields, as the CLIENT annotates them --|r")
    if fields[1] == nil then
        out("  no source row to audit — run this mid-pull, with a session running")
        return
    end

    local sampled = fields[1].sampled or 1
    out(string.format("  %d %s sampled (the local player's included wherever it sits)",
        sampled, sampled == 1 and "row" or "rows"))
    out("  field                  type     state    rows    values")

    reportFieldTally(printFieldRows(fields))
end

--- The correlation rectangle, per column.
local function reportRectangle(stats)
    out(string.format("  last pass: rows=%d keys=%d collidedKeys=%d collidedRows=%d "
        .. "filled=%d/%d", stats.rows, stats.keys, stats.collidedKeys,
        stats.collidedRows, stats.filled, stats.possible))
    out(string.format("  sort column: %s (nothing is correlated onto it)",
        tostring(stats.sortColumn)))
    out("  column               rows  filled  collided  absent  unmatched")
    for _, statKey in ipairs(stats.order) do
        local c = stats.columns[statKey]
        out(string.format("  %-20s %4d  %6d  %8d  %6d  %9d",
            statKey, c.rows, c.filled, c.collided, c.absent, c.unmatched))
    end
    out("  filled   = the correlation worked.")
    out("  collided = it refused, because two players share one class+spec.")
    out("  absent   = the column never named this key: an HONEST blank.")
    out("  unmatched= the column DID name it and produced no cell. That is the")
    out("             fault this line exists to surface — paste it into issue #22.")
end

--- How many rows share one identity key, as a histogram.
local function reportMultiplicity(stats)
    local sizes = {}
    for n in pairs(stats.multiplicity) do sizes[#sizes + 1] = n end
    table.sort(sizes)

    local parts = {}
    for _, n in ipairs(sizes) do
        local count = stats.multiplicity[n]
        parts[#parts + 1] = string.format("%d %s worn by %d %s",
            count, count == 1 and "key" or "keys", n, n == 1 and "row" or "rows")
    end
    out("  rows per key: " .. (parts[1] and table.concat(parts, ", ") or "none"))
    if sizes[#sizes] and sizes[#sizes] > 1 then
        out("  Anything past 1 row is a key that blanks every secondary cell for")
        out("  every row wearing it. This is what widening the key would buy.")
    end
end

--- Where each collided key's sources sat, per column.
local function reportSeats(stats)
    local keys = {}
    for key in pairs(stats.positions) do keys[#keys + 1] = key end
    table.sort(keys)
    if keys[1] == nil then return end

    out("  collided key seats (ordinal among GROUP sources, engine order):")
    for _, key in ipairs(keys) do
        local seats = stats.positions[key]
        local cols = {}
        for statKey in pairs(seats) do cols[#cols + 1] = statKey end
        table.sort(cols)
        local parts = {}
        for _, statKey in ipairs(cols) do
            parts[#parts + 1] = statKey .. "=" .. table.concat(seats[statKey], ",")
        end
        out(string.format("    %-24s %s", key, table.concat(parts, "  ")))
    end
    out("  ONE capture proves nothing. Run this twice in one pull: if a key's")
    out("  seats hold the same order in every column and in both captures, the")
    out("  pair could be matched by position — and that trades a guaranteed-honest")
    out("  blank for a possibly-wrong number, which is the trade to argue before")
    out("  it is made.")
end

--- `/mm debug identity` — everything issue #22 needs measured, in one paste.
local function reportIdentity()
    out("|cff00ff00-- identity correlation (issue #22) --|r")

    local S = NS.Secrets
    out(string.format("  restriction: %s   debug flag: %s",
        S and tostring(S.IsRestricted()) or "unknown",
        tostring(NS.State and NS.State.debug)))

    local A = NS.Aggregator
    local stats = A and A.LastIdentityStats and A.LastIdentityStats()
    if stats == nil then
        -- nil is "not measured", and it must never be printed as a clean
        -- rectangle of zeroes: the two read identically and mean opposite things.
        out("  no identity pass has been measured.")
        out("  It is built only while the debug flag is on AND the grid was built")
        out("  by identity correlation — so: `/mm debug on`, then mid-pull, then")
        out("  this command.")
    else
        -- A RECTANGLE OUTLIVES THE PULL IT DESCRIBES, deliberately — the whole
        -- point of keeping it is that the command is typed after the fact. But
        -- printed beside `restriction: false` with no comment, the two halves
        -- read as one moment, and the field audit below IS current: every field
        -- goes plain again the instant combat ends, which is why a post-combat
        -- audit shows candidates a mid-pull one does not.
        if not (S and S.IsRestricted()) then
            out("  |cffffd100the pull has ENDED|r — the rectangle below is the LAST")
            out("  identity pass, not the grid now. The field audit at the bottom is")
            out("  current, and out of combat nothing is secret: to learn what is")
            out("  plain MID-PULL, capture again inside one.")
        end
        reportRectangle(stats)
        reportMultiplicity(stats)
        reportSeats(stats)
    end

    reportSourceFields(sourceFields(stats))
end

--- `/mm debug identity` — the issue #22 capture on its own.
---
--- NOT part of `/mm debug diag`. That report is what a player runs when
--- something looks wrong and is read once; this one is a MEASUREMENT, taken
--- twice in one pull and compared, and it says nothing at all outside a pull.
function Diagnostics.ReportIdentity()
    local D = NS.DebugLog
    if D and D.Add and D.Show and D.IsShown then
        pcall(function() D:Show() end)
        if D:IsShown() then
            Diagnostics.SetEmit(function(line) D:Add("Diag", line) end)
        end
    end

    local ok, err = pcall(reportIdentity)
    if not ok then out("  |cffff2020section failed:|r " .. tostring(err)) end
    Diagnostics.SetEmit(nil)
end
