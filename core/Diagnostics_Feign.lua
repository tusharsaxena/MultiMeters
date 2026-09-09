-- core/Diagnostics_Feign.lua
--
-- `/mm debug feign` — the issue #25 recording, and the sink the trace writes to.
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
-- It is NOT part of `/mm debug diag`, and it carries STATE the rest of the report
-- does not: the ring, its write index, and the armed flag modules/Aggregator.lua
-- and modules/Feign.lua read through `NS.Diagnostics` at call time.
--
-- NOTHING WAS REWRITTEN ON THE WAY OUT. What follows is the block that used to
-- sit under the "Feign trace" banner in core/Diagnostics.lua, in its order.
--
-- The rules that file states — R1 (a stored figure is described, never
-- inspected), R2 and R3 — bind this file exactly as they bind that one, and the
-- print helpers below are ITS helpers, taken off the shared table rather than
-- redefined here.
--
-- TOC POSITION IS LOAD-BEARING: after core\Diagnostics.lua. `NS.Diagnostics`
-- and the helpers are resolved at FILE SCOPE, so the file that publishes them
-- must load first.

local _, NS = ...

local Diagnostics = NS.Diagnostics

local out, shown, probe = Diagnostics.out, Diagnostics.shown, Diagnostics.probe

-- ---------------------------------------------------------------------------
-- Feign trace — where the party-member filter loses the thread (issue #25)
-- ---------------------------------------------------------------------------
--
-- WHY A RECORDING AND NOT A SNAPSHOT. Every other section here answers a
-- question the client can be asked at the moment the command is typed. This one
-- cannot: the thing to observe is a feign, which is over by the time a player
-- finishes typing, and the whole complaint is that the filter works for the
-- LOCAL player and not for anybody else. So this is armed first, records while
-- the dungeon runs, and is printed afterwards.
--
-- THREE BOUNDARIES, because the symptom has two candidate causes and they are
-- indistinguishable from the count alone:
--
--   cast   — did UNIT_SPELLCAST_SUCCEEDED(5384) arrive at all, and under which
--            unit token? An empty log for a party member means the addon never
--            saw the feign, and no amount of filtering downstream can help.
--   prune  — what did modules/Feign.lua see on the unit each pass, and what did
--            it decide? A feigning party member evicted as "dead" is the other
--            candidate: a feign is presented to OTHER clients as a death, and
--            `hp <= 0` currently wins over `UnitIsFeignDeath` outright.
--   judge  — the verdict modules/Aggregator.lua actually got per death row, for
--            a GUID a `cast` line named. Only those: a death nobody feigned is
--            judged on every refresh and says nothing at all about this, and
--            there are far more of them than there are feigns.
--
-- Whichever of the three goes wrong first is the root cause, and the log says
-- which without anybody having to guess.
--
-- ARMED, NOT ALWAYS ON. `judge` fires once per death source row on every Deaths
-- refresh, which is the one of the three that is not rare, so recording is off
-- until asked for. What "off" costs is decided at the CALL SITES and not here:
-- `TraceFeign` declining the observation is too late, because the fields table
-- was built to make the call. They read `Diagnostics.feignArmed` first, and a
-- disarmed pass therefore allocates nothing at all (tests/perf.lua's
-- `feignTraceOff` scenario measures exactly that).
--
-- WHAT IT MAY HOLD. Strings and booleans, and nothing else — every field is
-- described THROUGH `shown` AT CAPTURE TIME rather than stored raw. A secret
-- kept in this table would be a secret this file later concatenates, and the
-- entry it landed in would take the whole line dark exactly the way the header's
-- session line did. Describing on the way in means a secret costs one field.

local FEIGN_TRACE_MAX = 120

-- THE RING, AND WHY IT IS A WRITE INDEX RATHER THAN A LIST THAT SHIFTS.
--
-- `table.remove(log, 1)` on a full ring moves 119 slots down one, on every
-- single insert past the hundred and twentieth. Nobody but an armed session pays
-- it, so it was never a player-facing cost — but the fix is the same size as the
-- defect: write at an index, wrap it, and have the reader unwrap it. The table
-- reaches FEIGN_TRACE_MAX slots and stops growing.
--
-- `feignWrite` is the NEXT slot to write, so once the ring is full it is also
-- the OLDEST entry — which is what the report reads forward from.
local feignTrace = nil
local feignWrite = 1
local feignWritten = 0

-- WHICH GUIDS A `cast` LINE HAS NAMED, keyed on the DESCRIBED guid rather than
-- the raw one. A secret cannot be a table key — the assignment raises before it
-- stores anything, and the unit API is not a safe source (core/Secrets.lua
-- records a follower dungeon handing out secret pet GUIDs) — so the key is what
-- `shown` made of it. Every secret therefore collapses to one key, which is the
-- honest loss: two secret GUIDs are indistinguishable in this report anyway.
local feignNoted = nil

-- Judge rows refused admission. Counted rather than dropped in silence, because
-- the count is evidence in its own right: a report with no `judge` lines and a
-- large refusal count says the Deaths refresh ran and simply never met the GUID
-- the cast named, which is a different finding from a refresh that never ran.
local feignSuppressed = 0

--- PUBLISHED, and read by the call sites directly rather than through a function.
---
--- `TraceFeign` returns on its first line when nothing is armed — but a Lua call
--- evaluates its arguments first, so a site that builds its fields table AT the
--- call has already paid for the recording by the time this file gets to decline
--- it. modules/Aggregator.lua and modules/Feign.lua therefore read this flag
--- before they build anything, which is what performance-§2 means by dormant
--- instrumentation costing one field read and one boolean test.
---
--- A plain boolean and not the ring itself, deliberately: both readers resolve
--- `NS.Diagnostics` at call time and must survive this file being absent, and a
--- nil-safe read of a boolean field is one index either way.
Diagnostics.feignArmed = false

--- Start or stop recording. Arming CLEARS: a run's evidence is one run's.
---
--- @param on boolean
--- @return boolean  whether recording is now on
function Diagnostics.ArmFeignTrace(on)
    feignTrace = on and {} or nil
    feignNoted = on and {} or nil
    feignWrite = 1
    feignWritten = 0
    feignSuppressed = 0
    -- One state in two shapes, and this is the ONLY writer of either. Let them
    -- disagree and the trace is silently dead in one of two ways: a false flag
    -- over a live ring records nothing, a true flag over a nil ring makes every
    -- site build a table for a function that drops it.
    Diagnostics.feignArmed = feignTrace ~= nil
    return Diagnostics.feignArmed
end

--- The accessor over the published field, and the surface everything that is not
--- on the refresh path should ask through. The two hot sites read the field
--- itself, because a function call is precisely the cost they are avoiding.
---
--- @return boolean
function Diagnostics.IsFeignTraceArmed()
    return Diagnostics.feignArmed
end

--- Record one observation, if anybody asked for observations.
---
--- Called from modules/Feign.lua and modules/Aggregator.lua, resolved through
--- `NS.Diagnostics` at CALL time so neither of them depends on this file loading.
---
--- The log is a ring: a dungeon is long, the interesting part is usually the
--- start, and a buffer that stops recording would lose a late real death — the
--- one entry that proves the filter does not eat those. Oldest goes.
---
--- NOT EVERY OBSERVATION IS ADMITTED. `judge` is taken only for a GUID a `cast`
--- line has already named; the rest are counted and reported as a total. See the
--- comment on the rule below for why a ring that took all three on equal terms
--- could not hold the one line it exists to show.
---
--- @param kind string             "cast" | "prune" | "judge"
--- @param fields table            plain field names to raw values, described here
function Diagnostics.TraceFeign(kind, fields)
    local log = feignTrace
    if log == nil then return end

    -- THE ADMISSION RULE. `judge` fires once per Deaths source on every refresh,
    -- for every death in the column; `cast` fires once per feign. Admit all three
    -- kinds on equal terms and a twenty-source column fills all 120 slots in six
    -- passes with judgements on GUIDs nobody ever feigned — and the `cast` line,
    -- the one entry that says whether the addon was told about the feign at all,
    -- is the first thing pushed out. So a judgement is admitted only for a GUID a
    -- `cast` line has already named, which is also the only judgement that means
    -- anything: `dropped=false` is a finding for a GUID the filter knew about and
    -- is the ordinary case for every other death in the group.
    --
    -- Ordering is not a hazard here. The feign has to be cast before the death it
    -- explains can be judged, so the `cast` line always precedes its judgements.
    local key = shown(fields.guid)
    if kind == "cast" then
        feignNoted[key] = true
    elseif kind == "judge" and not feignNoted[key] then
        feignSuppressed = feignSuppressed + 1
        return
    end

    local parts = {}
    for _, key2 in ipairs(fields.order) do
        parts[#parts + 1] = key2 .. "=" .. shown(fields[key2])
    end

    log[feignWrite] = kind .. "  " .. table.concat(parts, "  ")
    feignWrite = feignWrite % FEIGN_TRACE_MAX + 1
    if feignWritten < FEIGN_TRACE_MAX then feignWritten = feignWritten + 1 end
end

--- What the roster looks like RIGHT NOW, so a reader can put a GUID to a name.
---
--- The trace is all GUIDs, because a GUID is what the join is on. It is also
--- unreadable, so the report prints the group beside it — and prints it at read
--- time rather than storing names in the trace, which would put a name the unit
--- API may make secret into every single entry.
--- One roster member's row: the same three unit reads modules/Feign.lua makes,
--- described rather than returned.
---
--- THE THREE READS ARE DELIBERATELY NOT UNIFORM, and folding them into one reader
--- changes what this row says on a live client. `hp` goes through `probe`, so it
--- reads `<refused>` when UnitHealth raises OR is absent, and a number arrives
--- one-decimal; `dead` and `feigning` are `_G`-guarded and read `nil` when the API
--- is absent. `local` is `and true or false`, so it is never nil.
---
--- @param e table                 one NS.Roster group entry
local function reportFeignRosterRow(e)
    local unit = e.unit
    out(string.format("    %s  guid=%s  hp=%s  dead=%s  feigning=%s  local=%s",
        tostring(unit),
        shown(e.guid),
        unit and probe(_G.UnitHealth, unit) or "nil",
        unit and _G.UnitIsDead and shown(_G.UnitIsDead(unit)) or "nil",
        unit and _G.UnitIsFeignDeath and shown(_G.UnitIsFeignDeath(unit)) or "nil",
        tostring(e.isPlayer and true or false)))
end

local function reportFeignRoster()
    out("  group now:")
    local Roster = NS.Roster
    local group = Roster and Roster.GetGroup and Roster.GetGroup() or nil
    if group == nil or #group == 0 then
        out("    <no group>")
        return
    end
    -- Every member, feigning or not, so the report says what a NON-feigning unit
    -- looks like too. Without the baseline a single feigning row proves nothing:
    -- "party2 reads hp=0" is only evidence if the other four do not.
    for i = 1, #group do
        reportFeignRosterRow(group[i])
    end
end

local function reportFeign()
    out("|cff00ff00-- feign trace (issue #25) --|r")

    local S = NS.Secrets
    out(string.format("  restriction: %s   armed: %s",
        S and tostring(S.IsRestricted()) or "unknown",
        tostring(feignTrace ~= nil)))

    if feignTrace == nil then
        -- Not armed and never armed read identically from here, and both have
        -- the same remedy, so the report gives the remedy rather than a status.
        out("  not recording. `/mm debug feign on`, then run the dungeon with a")
        out("  hunter in the party, then `/mm debug feign` to print this.")
        reportFeignRoster()
        return
    end

    if feignSuppressed > 0 then
        -- Named before the entries, because it changes how an empty list reads.
        out(string.format("  %d judge rows suppressed: no cast line named that GUID.",
            feignSuppressed))
    end

    if feignWritten == 0 then
        -- THE MOST INFORMATIVE OUTCOME THIS REPORT HAS, and it must not read as
        -- a failed capture. No `cast` line at all, after a run with a hunter in
        -- it, IS the answer: UNIT_SPELLCAST_SUCCEEDED never arrived for that
        -- unit and modules/Feign.lua was never told anything to filter.
        out("  nothing recorded.")
        out("  If a hunter feigned during this run, that is the finding: the cast")
        out("  event never reached the addon. Say so in the issue.")
    else
        out(string.format("  %d entries:", feignWritten))
        -- OLDEST FIRST. Below the cap the entries sit at 1..feignWritten in
        -- order; at the cap `feignWrite` is the next slot to be overwritten,
        -- which is the oldest one still standing, and the walk wraps from there.
        local start = feignWritten < FEIGN_TRACE_MAX and 1 or feignWrite
        for i = 0, feignWritten - 1 do
            out("    " .. feignTrace[(start - 1 + i) % FEIGN_TRACE_MAX + 1])
        end
    end

    reportFeignRoster()
end

--- `/mm debug feign` — the issue #25 recording, printed.
---
--- Not part of `/mm debug diag`, for the reason `identity` is not: this says
--- nothing at all unless it was armed before the run it describes.
function Diagnostics.ReportFeign()
    local D = NS.DebugLog
    if D and D.Add and D.Show and D.IsShown then
        pcall(function() D:Show() end)
        if D:IsShown() then
            Diagnostics.SetEmit(function(line) D:Add("Diag", line) end)
        end
    end

    local ok, err = pcall(reportFeign)
    if not ok then out("  |cffff2020section failed:|r " .. tostring(err)) end
    Diagnostics.SetEmit(nil)
end
