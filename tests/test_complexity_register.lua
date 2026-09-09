-- tests/test_complexity_register.lua — the complexity watch list's disposition gate
-- (performance-§10, automated-tests-§3/§4, anti-pattern #53).
--
-- WHAT IT PROVES. That docs/ARCHITECTURE.md's `## Complexity register` still says something a
-- reader can act on: that its own stated tally matches the table under it, that every row points at
-- a file that exists, that no row is entered twice, and that every disposition is FOLLOWABLE — an
-- issue number to open, or an accept carrying the re-check trigger that stops it being a permanent
-- opt-out wearing a table's clothes.
--
-- WHY IT EXISTS. `performance-§10` asks for a one-line disposition per warned function; the
-- release gate in `automated-tests-§3` refuses a tag while any function sits above CCN 15, and this
-- addon has 23 of them. Anti-pattern #53 is the failure this guards against, and it is
-- self-concealing: every entry is defensible in isolation, and the list only fails collectively, at
-- the moment a genuinely alarming function arrives into a list of twenty-three and cannot be told
-- apart from them. A blanket "accepted" is the shape that failure takes, so a row without a trigger
-- is red here.
--
-- Two rows have a second reason to live in ARCHITECTURE.md rather than in RESULTS.md. The kit's
-- runner keys a carried-forward disposition on function name plus file, tie-broken by CCN
-- (tests/_kit/run-automated-tests.sh:537-556). Three of this addon's rows are named `]` in
-- core/Database.lua — lizard's spelling of `migrations[n] = function` — and two of those three are
-- CCN 16, so they are unique on neither key and their generated cells read blank on every run. The
-- register is where their disposition exists at all.
--
-- WHAT IT DOES NOT DO, DELIBERATELY: run `lizard`. `performance-§10` says a commit MUST NOT be
-- gated on complexity — "a threshold that fails a build turns a useful signal into an obstacle to
-- route around" — and a suite that shelled out to lizard would be that gate wearing a test's
-- clothes. It also does not assert the CCN figures or the line ranges: those are dated
-- measurements, and pinning them would redden the suite on every ordinary edit to a warned
-- function, which is a gate with a standing reason to be switched off. Membership and disposition
-- are the invariants. The figures are re-measured by the runner, never here.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. A missing ARCHITECTURE.md, a missing heading, a
-- missing tally line and an empty table are each a failure, not a skip — the same bargain
-- tests/test_layout_cap.lua and tests/_kit/test_eol.lua strike.

local T = _G.MULTIMETERS_TEST
local test, fail = T.test, T.fail
local ROOT = T.root or "."

local ARCHITECTURE = "/docs/ARCHITECTURE.md"
local HEADING = "## Complexity register"

-- `lizard`'s own warn threshold. A row for a function at or below it is a row for a function the
-- watch list does not carry, which means the table and the report have drifted apart.
local WARN_ABOVE = 15

--- docs/ARCHITECTURE.md with line endings normalised, or a failure.
local function architecture()
    local fh = io.open(ROOT .. ARCHITECTURE, "r")
    if not fh then fail("docs/ARCHITECTURE.md could not be opened") end
    local body = fh:read("*a") or ""
    fh:close()
    return (body:gsub("\r\n", "\n"))
end

--- Every line of the `## Complexity register` section, in order.
---
--- Reading stops at the next heading of any level, so a later section growing a table of its own
--- cannot leak into this one — and an earlier one cannot leak in either, which matters here because
--- the cap census immediately above also carries a four-column table with a Disposition column.
local function sectionLines()
    local lines, inside, found = {}, false, false
    for line in (architecture() .. "\n"):gmatch("([^\n]*)\n") do
        if line == HEADING then
            inside, found = true, true
        elseif inside and line:sub(1, 1) == "#" then
            break
        elseif inside then
            lines[#lines + 1] = line
        end
    end
    -- Absence is REPORTED, not raised. `performance-§10` asks for a disposition per
    -- warned function, and the terminal state of that rule is a repository with no
    -- warned function and therefore no table — reached here on 2026-09-09, when the
    -- last of twenty-three came under CCN 15. What the rule is actually against is a
    -- disposition that outlives the function it was written for, and that is caught
    -- by the cases below rather than by insisting the heading exist.
    return lines, found
end

--- The register's rows as { fn, ccn, path, first, last, disposition }.
---
--- A row is a four-cell table line whose first cell opens with a backticked name and whose third
--- cell is a backticked `path:first-last`. The heading row and the `|---|` separator match neither
--- and fall out on their own.
local function registerRows()
    local rows = {}
    for _, line in ipairs(sectionLines()) do
        local fn, ccn, loc, disposition =
            line:match("^|%s*`([^`]+)`[^|]*|%s*(%d+)%s*|%s*`([^`]+)`%s*|%s*(.-)%s*|%s*$")
        if fn then
            local path, first, last = loc:match("^(.-):(%d+)%-(%d+)$")
            if not path then
                fail("register row for `" .. fn .. "` has Location `" .. loc .. "`, which is not " ..
                     "`path:first-last` — the line range is what separates the three `]` rows in " ..
                     "core/Database.lua from each other")
            end
            rows[#rows + 1] = {
                fn = fn, ccn = tonumber(ccn), path = path,
                first = tonumber(first), last = tonumber(last),
                disposition = disposition,
            }
        end
    end
    -- No rows is a RESULT, exactly as an empty watch list is a result rather than a
    -- missing one (`performance-§10`: "An empty watch list is a result — write
    -- 'None.'"). Every case below is written to hold vacuously over an empty table,
    -- so the emptiness needs no special pleading here.
    return rows
end

--- The per-folder tally the section states in prose, as { ["core/"] = n, … }.
---
--- Parsed rather than hard-coded so the test carries no figure of its own: the doc states the split
--- and the table has to agree with it, which is a property a reader can check by eye and a rewrite
--- cannot quietly break.
local function statedTally()
    for _, line in ipairs(sectionLines()) do
        local core, modules, settings =
            line:match("`core/`%s*%*%*(%d+)%*%*.-`modules/`%s*%*%*(%d+)%*%*.-`settings/`%s*%*%*(%d+)%*%*")
        if core then
            return { ["core/"] = tonumber(core), ["modules/"] = tonumber(modules),
                     ["settings/"] = tonumber(settings) }
        end
    end
    -- No tally sentence and no rows agree with each other: there is nothing to state.
    -- A tally is only owed once the table has something in it.
    if #registerRows() == 0 then return nil end
    fail("the '" .. HEADING .. "' section states no core/ modules/ settings/ tally; that sentence " ..
         "is what the table below it is checked against, and without it this suite is blind")
end

-- ---------------------------------------------------------------------------
-- The register agrees with itself
-- ---------------------------------------------------------------------------

test("complexityregister: the stated folder tally matches the table under it", function()
    local tally = statedTally()
    if tally == nil then return end
    local counted, total = { ["core/"] = 0, ["modules/"] = 0, ["settings/"] = 0 }, 0

    for _, row in ipairs(registerRows()) do
        local folder = row.path:match("^([^/]+/)")
        if counted[folder] == nil then
            fail("register row `" .. row.fn .. "` lives in " .. tostring(folder) ..
                 ", which the stated tally does not name — every warned function measured so far " ..
                 "is in core/, modules/ or settings/, so a fourth folder needs the sentence " ..
                 "rewritten rather than the row hidden")
        end
        counted[folder] = counted[folder] + 1
        total = total + 1
    end

    for folder, stated in pairs(tally) do
        if counted[folder] ~= stated then
            fail("the register says " .. stated .. " warned function(s) in " .. folder ..
                 " and its table carries " .. counted[folder] ..
                 " — re-measure with the fixed lizard invocation and correct both together")
        end
    end

    local sum = tally["core/"] + tally["modules/"] + tally["settings/"]
    if sum ~= total then
        fail("the stated tally sums to " .. sum .. " and the table has " .. total .. " rows")
    end
end)

test("complexityregister: every row points at a file that still exists", function()
    local broken = {}
    for _, row in ipairs(registerRows()) do
        local fh = io.open(ROOT .. "/" .. row.path, "r")
        if fh then
            fh:close()
        else
            broken[#broken + 1] = row.fn .. " → " .. row.path
        end
        -- The range is not checked against the file's length: line numbers drift under every
        -- ordinary edit and a suite that reddened on that would be switched off. What is checked
        -- is that it reads as a range at all, which is what makes the three `]` rows tellable
        -- apart.
        if row.first > row.last then
            fail("register row `" .. row.fn .. "` has Location " .. row.path .. ":" ..
                 row.first .. "-" .. row.last .. ", which runs backwards")
        end
        if row.ccn <= WARN_ABOVE then
            fail("register row `" .. row.fn .. "` records CCN " .. row.ccn .. ", at or under " ..
                 "lizard's threshold of " .. WARN_ABOVE .. " — the watch list does not carry it, " ..
                 "so either the figure is stale or the row has been peeled and should be retired")
        end
    end

    if #broken > 0 then
        fail("register rows naming a file that no longer exists: " .. table.concat(broken, ", ") ..
             " — a file that moved takes its row with it; a file that went takes its row away")
    end
end)

test("complexityregister: no function is entered twice", function()
    local seen, duplicates = {}, {}
    for _, row in ipairs(registerRows()) do
        -- Keyed on name AND location, because `Cell` is genuinely two functions in
        -- modules/Row.lua and `]` is genuinely three in core/Database.lua. A duplicate here is a
        -- row copied and half-edited, which is how a disposition ends up attached to the wrong
        -- function — worse than a blank cell, because a blank cell asks for a decision and a wrong
        -- one answers a question nobody asked.
        local key = row.fn .. "@" .. row.path .. ":" .. row.first .. "-" .. row.last
        if seen[key] then duplicates[#duplicates + 1] = key end
        seen[key] = true
    end
    if #duplicates > 0 then
        fail("the complexity register enters the same function twice: " ..
             table.concat(duplicates, ", "))
    end
end)

test("complexityregister: every disposition can be followed", function()
    local unfollowable = {}
    for _, row in ipairs(registerRows()) do
        local d = row.disposition
        local peel = d:find("%*%*Peel%*%*") ~= nil
        local accepted = d:find("%*%*Accepted%.%*%*") ~= nil

        if peel == accepted then
            -- Both, or neither. `performance-§10` gives a warned function two terminal states short
            -- of the split itself, and a cell that claims both has not decided.
            unfollowable[#unfollowable + 1] = row.fn .. " (neither Peel nor Accepted, or both)"
        elseif peel and not d:find("#%d") then
            unfollowable[#unfollowable + 1] = row.fn .. " (a peel naming no issue)"
        elseif accepted and not d:find("Re%-check:") then
            -- The rule the register's own preamble states: a row without a re-check trigger is a
            -- permanent opt-out wearing a table's clothes, and anti-pattern #53 is what it grows
            -- into twenty-three at a time.
            unfollowable[#unfollowable + 1] = row.fn .. " (an accept with no re-check trigger)"
        end
    end

    if #unfollowable > 0 then
        fail("complexity register rows whose disposition cannot be followed: " ..
             table.concat(unfollowable, ", ") ..
             " — each row is a peel with an issue number, or an accept with the condition that " ..
             "ends it")
    end
end)
