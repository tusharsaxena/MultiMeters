-- core/Diagnostics_DeathRecap.lua
--
-- `/mm debug recap` — can issue #1's Death Recap window be built at all?
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
-- It also rides along in `/mm debug diag`, so the section function is published
-- back onto the shared table at the foot of the block — see the comment there.
--
-- NOTHING WAS REWRITTEN ON THE WAY OUT. What follows is the block that used to
-- sit under the "Death recap" banner in core/Diagnostics.lua, in its order.
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

local out, shown, safe = Diagnostics.out, Diagnostics.shown, Diagnostics.safe

-- ---------------------------------------------------------------------------
-- Death recap — can issue #1's window be built at all?
-- ---------------------------------------------------------------------------
--
-- Issue #1 wants a two-pane Death Recap window: a left pane listing every death
-- in the run, a right pane breaking the selected one down into incoming events.
-- Every `deathRecapID` it needs is already arriving — modules/Provider.lua
-- copies one off each Deaths source row — and this addon does nothing with them
-- but hand ONE to Blizzard's own frame, which answers "Death Recap unavailable".
--
-- Three things about the live client decide whether that window is a reader over
-- `deathRecapID` or a combat-log capture of our own, and every one of them is
-- currently a guess:
--
--   1. does an id resolve for a NON-LOCAL player? Blizzard's recap frame is
--      built around the local player's own deaths.
--   2. does one resolve for a death from EARLIER IN THE RUN, or only the most
--      recent? The whole left pane is past deaths.
--   3. is there a READER for the per-event breakdown at all, or only the
--      frame-opening call this addon already uses?
--
-- Answer them wrong and the feature is a materially larger job than the issue
-- describes. So this section measures instead of guessing: it dumps every id the
-- session holds, asks the client which recap functions it carries, and calls
-- each one against four deliberately chosen ids — the local player's newest and
-- an older one, another player's newest and an older one. What comes back is
-- printed verbatim-ish and NOT interpreted, beyond naming which fork each
-- outcome puts the issue on.
--
-- Rule R1 holds throughout. Every read goes through modules/Provider.lua, no
-- amount is inspected, and a recap payload's fields are rendered through
-- `shown` — which describes a secret rather than asking what it is.

-- How many death rows the dump prints. A raid night can hold dozens and the
-- report is pasted into an issue by hand; twelve is enough to show repeats of
-- one player, which is the shape that matters.
local RECAP_DUMP_LIMIT = 12

-- The four ids worth calling, in the order they are chosen. The labels are the
-- open questions restated as slots: anything that answers `local/newest` and
-- refuses the other three is Blizzard's frame behaviour, and that answer sinks
-- the design as written.
local RECAP_SLOTS = { "local/newest", "local/older", "other/newest", "other/older" }

--- The Deaths column for one session, or nil.
local function deathsColumn(sessionType, sessionID)
    local P = NS.Provider
    if not (P and P.GetColumn) then return nil end
    local column = P:GetColumn(sessionType, "Deaths", sessionID)
    if type(column) ~= "table" then return nil end
    return column
end

--- Which of the four slots a source row belongs in, or nil for a row we already
--- have a slot filled for.
---
--- `isLocalPlayer` is read the way modules/Aggregator.lua reads it — it stays
--- plain under the restriction, which is the whole reason identity survives a
--- pull — but it is vetted first anyway. A row we cannot classify goes in no
--- slot rather than in the wrong one.
---
--- THE BOOLEAN CASE IS CHECKED BEFORE `safe`, exactly as `shown` does it: this
--- file's `safe` is a CONCAT probe, and `table.concat{ false }` raises, so a
--- plain `false` — which is every non-local player — reads as unprintable and
--- would have put the whole `other/*` half of the probe in the "no such death"
--- branch. The two questions this section exists to answer are both on that
--- half.
---
--- @param slots table   label -> source, filled in place
--- @param src table
--- @return string|nil   the label filled, when one was
local function fillRecapSlot(slots, src)
    local isLocal = src.isLocalPlayer
    if type(isLocal) ~= "boolean" and not safe(isLocal) then return nil end
    local mine = (isLocal == true)
    local newest = mine and "local/newest" or "other/newest"
    local older  = mine and "local/older"  or "other/older"
    if slots[newest] == nil then slots[newest] = src return newest end
    if slots[older]  == nil then slots[older]  = src return older  end
    return nil
end

--- Print one death row.
local function reportDeathRow(index, src)
    out(string.format("    [%2d] name=%-14s local=%-5s deathTime=%-8s recap=%s",
        index, shown(src.name), shown(src.isLocalPlayer),
        shown(src.deathTimeSeconds), shown(src.deathRecapID)))
end

--- Dump one session's Deaths column and hand back its sources.
---
--- EVERY ROW, not one per player. The client reports one source row PER DEATH
--- with the same GUID repeated, and modules/Aggregator.lua keeps only the first
--- recap id it sees — which is precisely the discard issue #1 exists to undo. A
--- probe that read the aggregated grid would confirm our own bug back to us.
---
--- @return table|nil sources
local function reportDeathsSession(label, sessionType, sessionID)
    local column = deathsColumn(sessionType, sessionID)
    if not column then
        out(string.format("  -- deaths, %s -- provider unavailable", label))
        return nil
    end

    out(string.format("  -- deaths, %s -- %d rows, reason=%s",
        label, #column.sources, tostring(column.reason)))
    for i = 1, math.min(#column.sources, RECAP_DUMP_LIMIT) do
        reportDeathRow(i, column.sources[i])
    end
    if #column.sources > RECAP_DUMP_LIMIT then
        out(string.format("    ... %d more rows not printed",
            #column.sources - RECAP_DUMP_LIMIT))
    end
    return column.sources
end

--- One table's string-keyed fields, sorted for a stable paste.
--- @return string|nil  nil when the table has no string keys at all
local function describeRecapFields(tbl)
    local keys = {}
    for k in pairs(tbl) do
        if type(k) == "string" then keys[#keys + 1] = k end
    end
    if #keys == 0 then return nil end
    table.sort(keys)

    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = k .. "=" .. shown(tbl[k])
    end
    return "table{ " .. table.concat(parts, ", ") .. " }"
end

--- Describe whatever a reader handed back, without asking what it is.
---
--- THE ARRAY CASE IS THE ONE THAT MATTERS. `GetRecapEvents` returns an ARRAY of
--- event tables, and issue #1's whole right pane is made of their fields — spell,
--- time, amount, HP. Described by string keys alone, which is all the first two
--- rounds of this probe could do, an array prints as `table{}`: the report would
--- find the reader and then say it handed back nothing useful, which is the same
--- wrong answer arriving by a new route.
---
--- The length comes from core/Secrets.lua's counter rather than from `#`, and
--- the walk from SafeIterate: a recap event's fields may be secret mid-pull, and
--- `#` on a secret is the operator rule R1 names outright.
---
--- AN EMPTY ARRAY IS A REAL "NO". `#raw == 0` is how a working addon detects
--- "this id carries no recap", so the second return exists to keep a
--- zero-length reply out of the answered tally — counting it would hand back
--- the green light for a client that refused every id.
---
--- @param value any
--- @return string description, boolean answered
local function describeRecapValue(value)
    if value == nil then return "nil", false end
    if type(value) ~= "table" then return shown(value), true end
    -- NS.Secrets is read at CALL time, not captured at file scope: this file
    -- loads last in the core block and reaches every module the same way.
    local S = NS.Secrets
    if not S or not S.CanAccessTable(value) then return "<inaccessible table>", true end

    local first, count = nil, 0
    S.SafeIterate(value, function(index, entry)
        count = index
        if first == nil and type(entry) == "table"
            and S.CanAccessTable(entry) then first = entry end
    end)

    if count > 0 then
        local shape = first and describeRecapFields(first) or "<entries are not tables>"
        return string.format("array[%d] of %s", count, shape), true
    end

    local fields = describeRecapFields(value)
    if fields then return fields, true end
    return "array[0] — the client has no recap for this id", false
end

--- Call one reader against one id, both ways round, and print both outcomes.
---
--- TWO ARITIES, because nobody knows which the reader takes. Blizzard's own
--- recap UI walks events by index, so `(id)` and `(id, 1)` are both plausible
--- and trying both costs two lines. A refusal on one and an answer on the other
--- IS the shape of the API.
--- @return boolean  whether either call came back with anything at all
local function probeRecapReader(api, recapID)
    local P = NS.Provider
    local path = api.ns .. "." .. api.name
    local answered = false

    -- `~= nil` IS THE ONLY QUESTION ASKED OF THE RESULT, and it is the one
    -- question rule R1 permits of a possibly-secret value: nil-ness, never
    -- truthiness and never a comparison against anything else.
    local function line(label, ok, value)
        if not ok then
            out(string.format("      %s%-8s -> refused: %s", path, label,
                tostring(value)))
            return
        end
        local description, gotSomething = describeRecapValue(value)
        if gotSomething then answered = true end
        out(string.format("      %s%-8s -> %s", path, label, description))
    end

    line("(id)",    P.CallRecap(api.ns, api.name, recapID))
    line("(id, 1)", P.CallRecap(api.ns, api.name, recapID, 1))
    return answered
end

--- The four chosen ids, each put to every reader the client carries.
---
--- @return table answered, number probed  slot labels that got an answer, and
---         how many slots there was actually a death to ask about
local function reportRecapProbes(apis, slots)
    local S = NS.Secrets
    local answered, probed = {}, 0
    for _, label in ipairs(RECAP_SLOTS) do
        local src = slots[label]
        if src == nil then
            out(string.format("    %-13s no such death in this session", label))
        else
            local recapID = src.deathRecapID
            -- THE ID IS GATED BEFORE IT IS PASSED. `deathRecapID` is documented
            -- NeverSecret and the probe still does not bet a raise on it:
            -- forwarding a secret into a client function is the `bad argument
            -- #4` that already shipped once through modules/Targets.lua.
            if not (S and S.IsSafeKey(recapID)) then
                out(string.format("    %-13s id is secret or absent — not called", label))
            else
                probed = probed + 1
                out(string.format("    %-13s id=%s  name=%s", label,
                    tostring(recapID), shown(src.name)))
                for _, api in ipairs(apis) do
                    if probeRecapReader(api, recapID) then
                        if answered[#answered] ~= label then
                            answered[#answered + 1] = label
                        end
                    end
                end
            end
        end
    end
    return answered, probed
end

--- The whole surface of every candidate namespace, unfiltered.
---
--- THE SECTION THAT RESOLVES ROUND ONE'S AMBIGUITY. A walk of a live 12.x client
--- turned up one recap-shaped function and it was a corpse coordinate, which
--- reads as "this client has no reader" and reads equally well as "the walk
--- cannot see this namespace". A filtered list cannot tell those apart. An
--- unfiltered one can: a `C_DeathInfo` with seven ordinary members and no recap
--- function among them is a conclusive no, and one that enumerates as empty or
--- near-empty is a proxy, where the fault is the search.
local function reportRecapSurface()
    local P = NS.Provider
    out("  -- namespace surface (unfiltered) --")
    for _, entry in ipairs(P.RecapMembers()) do
        if not entry.present then
            out(string.format("    %s: not on this client", entry.ns))
        elseif #entry.names == 0 then
            out(string.format("    %s: present, enumerates as EMPTY — a proxy;"
                .. " the walk is blind here", entry.ns))
        else
            out(string.format("    %s: %d members", entry.ns, #entry.names))
            -- Wrapped rather than one per line: a meter namespace runs to a
            -- dozen names and this report is pasted by hand.
            local line = "     "
            for _, name in ipairs(entry.names) do
                if #line + #name + 2 > 92 then out(line) line = "     " end
                line = line .. " " .. name
            end
            if line ~= "     " then out(line) end
        end
    end
end

--- The reader list, each entry carrying which search found it.
local function reportRecapReaders(apis)
    if #apis == 0 then
        out("  readers on this client: none, by either search")
        return
    end
    for _, api in ipairs(apis) do
        local note = (api.how == "named")
            and "  <-- found by direct index; the walk cannot see it"
            or  ""
        out(string.format("  reader: %-44s [%s]%s",
            api.ns .. "." .. api.name, api.how, note))
    end
end

--- The dating section's header: window 1's session type, and the death-time
--- format that window is ACTUALLY set to.
---
--- THE FORMAT IS READ OFF `cfg.text`, NOT `cfg.data.text`. `data` is where the
--- session fields live, and both hang off the same window table, so a folded
--- lookup prints nil for a setting the player can see in the options panel.
local function reportDatingHeader()
    local windows = NS.Database and NS.Database.GetWindows and NS.Database.GetWindows()
    local cfg = windows and windows[1]
    local text = cfg and cfg.text or {}
    out(string.format("    window 1: sessionType=%s  text.deathTimeFormat=%s",
        tostring(cfg and cfg.data and cfg.data.sessionType),
        tostring(text.deathTimeFormat)))
end

--- One death's inputs, dated in both styles — or the notice that it cannot be
--- dated at all.
---
--- THE SAFE-KEY GATE IS WHAT KEEPS A SECRET OUT of `P.GetRecap` and out of
--- `string.format`. A row whose id is secret prints the notice and nothing else,
--- and the caller still spends one of its four on it: see the cap.
---
--- @param F table                 the formatter, already proven to carry DeathTime
--- @param P table                 the recap provider
--- @param S table|nil             NS.Secrets, absent on an old client
--- @param src table               one Deaths source row
local function reportDatingRow(F, P, S, src)
    local id = src.deathRecapID
    if not (S and S.IsSafeKey(id)) then
        out("    [id is secret — nothing can be dated from it]")
        return
    end

    local recap = P.GetRecap and P.GetRecap(id) or nil
    -- THE CLIENT HANDS THE EVENTS BACK NEWEST FIRST, so events[1] is the killing
    -- blow. Dating off the last element puts the death at the fight's first
    -- damage instead, and nothing in this output would look wrong.
    local newest = recap and recap.events and recap.events[1]
    local when = newest and newest.timestamp

    -- `deathTimeSeconds` is printed although nothing reads it any more.
    -- It is the field three separate attempts were built on, and seeing
    -- it read -1 here is what a reader needs before trying a fourth.
    out(string.format("    id=%s  row deathTimeSeconds=%s  recap timestamp=%s",
        tostring(id), shown(src.deathTimeSeconds), shown(when)))
    out(string.format("      clock=%s  ago=%s",
        tostring(F.DeathTime(when, "clock")),
        tostring(F.DeathTime(when, "ago"))))
end

--- Why each death is dated the way it is.
---
--- KEPT AFTER THE FEATURE IT WAS WRITTEN FOR WAS REMOVED. "Time into the fight"
--- never worked and is gone, and this section is what proved it could not: it
--- prints the INPUTS rather than the conclusion, which is how the third failed
--- derivation was caught instead of shipped. Anything that later tries to date a
--- death against its run will need exactly this again.
local function reportDeathDating(sources)
    out("  -- dating --")

    local S = NS.Secrets
    local F = NS.Numbers or NS.Format
    local P = NS.Provider
    if not (F and F.DeathTime and P) then
        out("    formatter or provider unavailable")
        return
    end

    reportDatingHeader()

    local printed = 0
    for i = 1, #(sources or {}) do
        reportDatingRow(F, P, S, sources[i])
        -- FOUR ROWS WALKED, not four rows dated. Mid-pull every id is secret, and
        -- an increment moved inside the dated arm would walk the whole column
        -- looking for a fourth datable row that cannot exist.
        printed = printed + 1
        if printed >= 4 then break end
    end
end

--- What the outcome above means for issue #1, said out loud.
---
--- The reader list being empty is not a detail a reader of the report should
--- have to infer from silence: it is the answer that re-scopes the issue.
---
--- THE VERDICT RESTS ON BOTH SEARCHES, and says so. Round one claimed "no recap
--- reader" on the strength of a walk alone, and a walk alone cannot support it —
--- the same output comes back from a client with a reader behind a proxy. Two
--- independent searches agreeing is a materially stronger claim than one, and
--- the wording has to carry that difference or the next person re-scopes a
--- feature on the weaker evidence.
--- THE VERDICT FOLLOWS THE ANSWERS, NOT THE LIST. Measured: round one found
--- exactly one recap-shaped function on a live client —
--- `C_DeathInfo.GetDeathReleasePosition`, a corpse coordinate — which returned
--- nil for all four ids, and the report printed "all four answering is the green
--- light" underneath it because the LIST was non-empty. A verdict that reads a
--- found name as a working reader is the diagnostic lying about its own finding.
---
--- THE DENOMINATOR IS WHAT WAS ASKED, NOT WHAT EXISTS. Measured: a run where
--- the local player never died probed two slots, both answered in full, and the
--- verdict still warned "some slots answered and some did not" — the wording
--- reserved for a client that REFUSED. Nothing had refused; two slots had no
--- death to ask about. A diagnostic crying wolf over its own missing fixture
--- teaches a reader to discount it.
---
--- @param apis table
--- @param answered table  slot labels that got an answer
--- @param probed number   slots there was actually a death to ask about
local function reportRecapVerdict(apis, answered, probed)
    local RESCOPE = {
        "  Issue #1's window would need its own event capture: a materially",
        "  larger job. Re-scope the issue before starting it.",
    }

    if #apis == 0 then
        out("  |cffff2020no recap reader, by both searches|r — neither the walk nor a")
        out("  direct index of the documented names found one, so the only recap")
        out("  call this addon has is Blizzard's frame-opening one, which cannot")
        out("  fill a pane.")
        for _, line in ipairs(RESCOPE) do out(line) end
        return
    end

    if #answered == 0 then
        out("  |cffff2020every reader answered for no id|r — functions were found and")
        out("  none of them handed back a recap, so what the searches turned up is")
        out("  not a reader for this. Same conclusion as finding nothing at all.")
        for _, line in ipairs(RESCOPE) do out(line) end
        return
    end

    out(string.format("  answered: %s   (%d of %d slots had a death to ask about)",
        table.concat(answered, ", "), #answered, probed))
    if #answered >= probed then
        out("  |cff20ff20every death this session could offer resolved|r — issue #1's")
        out("  window can be built on deathRecapID. A run covering all four slots")
        out("  confirms it hardest, but nothing here refused.")
    else
        out("  |cffffd100some slots answered and some did not|r. A reader that answers")
        out("  local/newest alone is Blizzard's own frame behaviour, and sinks the")
        out("  window as designed; the left pane is made of past deaths and the")
        out("  column covers the whole group.")
    end
    out("  Paste this into issue #1.")
end

--- The whole probe. Safe to run at any time; most useful straight after a run
--- with several deaths spread across it.
local function reportDeathRecap()
    out("|cff00ff00-- death recap (issue #1) --|r")

    local P = NS.Provider
    if not (P and P.GetColumn and P.RecapAPIs and P.CallRecap and P.RecapMembers) then
        out("  provider unavailable")
        return
    end

    local windows = NS.Database and NS.Database.GetWindows and NS.Database.GetWindows()
    local cfg = windows and windows[1]
    local sessionID = NS.Database.PinnedSegment(cfg and cfg.data)
    local ST = NS.Constants.SESSION_TYPE

    -- BOTH SESSIONS, because they disagree and the disagreement matters. A live
    -- dump showed `deathTimeSeconds = -1` on Overall and a real figure on
    -- Current, and issue #1's left pane is keyed on timestamps — so which
    -- session carries a usable time is a design input, not trivia.
    reportDeathsSession("Current", ST.Current, sessionID)
    local sources = reportDeathsSession("Overall", ST.Overall, sessionID)
    -- Current is preferred for the probe: it is the session whose times are
    -- believed real. Overall is the fallback so a probe run after a reset still
    -- has ids to call.
    local current = deathsColumn(ST.Current, sessionID)
    if current and #current.sources > 0 then sources = current.sources end

    reportRecapSurface()
    local apis = P.RecapAPIs()
    reportRecapReaders(apis)

    local slots = {}
    for i = 1, #(sources or {}) do fillRecapSlot(slots, sources[i]) end

    out("  -- probes --")
    local answered, probed = reportRecapProbes(apis, slots)
    reportDeathDating(sources)
    reportRecapVerdict(apis, answered, probed)
end

-- PUBLISHED so core/Diagnostics.lua's Report() can still include this section.
-- The entry point stayed with the frame when the probe moved out here, and a
-- file-local of this file is no longer reachable from there. It is read at CALL
-- time off the shared table, so it constrains load order no further than the
-- file-scope resolution at the top of this file already does.
Diagnostics.reportDeathRecap = reportDeathRecap

--- `/mm debug recap` — the probe on its own.
---
--- It rides along in the full report too, so a player running `/mm debug diag`
--- after a dungeon hands the evidence over for free. The dedicated verb exists
--- because the answer wanted here is specific enough to ask for on its own, and
--- forty lines of atlas and font output around it makes it harder to read.
function Diagnostics.ReportDeathRecap()
    local D = NS.DebugLog
    if D and D.Add and D.Show and D.IsShown then
        pcall(function() D:Show() end)
        if D:IsShown() then
            Diagnostics.SetEmit(function(line) D:Add("Diag", line) end)
        end
    end

    local ok, err = pcall(reportDeathRecap)
    if not ok then out("  |cffff2020section failed:|r " .. tostring(err)) end
    Diagnostics.SetEmit(nil)
end
