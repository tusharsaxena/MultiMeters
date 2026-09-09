-- tests/test_layout_cap.lua — the 1500-line cap gate (layout-§1).
--
-- WHAT IT PROVES. That no authored `.lua` file this repository tracks sits over layout-§1's
-- 1500-line cap without a disposition, and that no disposition outlives the breach it was
-- written for. It reads the tracked set from git and the census table from
-- docs/ARCHITECTURE.md, and compares the two in BOTH directions.
--
-- WHY IT EXISTS. The 2026-09-07 audit of this addon filed a layout-§1 MUST against seven source
-- files over the cap and against none of its seven test files over it, in the same bundle:
-- `tests/test_window.lua` was 2737 lines and went unremarked while `modules/Row.lua` at 1702 did
-- not. Four repositories in the collection answered the same silence four different ways.
-- layout-§1 was then revised to say what the cap binds — every authored file the repo tracks,
-- `tests/` included, with vendored code the only carve-out that reaches here — and to name the
-- three terminal states a file over the cap may be in: peeled, an open issue naming the seam, or
-- a ratified deviation row with a re-check trigger. What it does not allow is silence: "the count
-- sitting in a bundle manifest that no document reads".
--
-- A census written once and never re-checked becomes exactly that manifest. Line counts move on
-- their own — `settings/Schema.lua` gained 11 lines and `core/Diagnostics.lua` 98 between the
-- review's measurement and this one — so the file that crosses the cap next is a file nobody was
-- watching. This is the thing that watches.
--
-- WHAT IT DOES NOT ASSERT: the line figures printed in the census. They are dated measurements,
-- and pinning them would redden the suite on every ordinary edit to a large file — a gate with a
-- reason to be switched off. Membership is the invariant; the numbers are prose.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. No `io.popen`, no git, no ARCHITECTURE.md, no
-- census heading — every one of those is a failure, not a skip. A gate that goes quiet when it is
-- blind reports success, which is worse than not existing. Same bargain tests/_kit/test_eol.lua
-- strikes.

local T = _G.MULTIMETERS_TEST
local test, fail = T.test, T.fail
local ROOT = T.root or "."

local CAP = 1500
local ARCHITECTURE = "/docs/ARCHITECTURE.md"
local CENSUS_HEADING = "### Files over the 1500-line cap"

--- Split a NUL-delimited blob. `git ls-files -z` because a path may contain anything but NUL, and
--- the line-oriented form quotes such a path instead of printing it — a quoted path would not
--- match a file on disk and this gate would then report a breach that is really a parse failure.
local function splitNul(blob)
    local out, start = {}, 1
    while true do
        local i = blob:find("\0", start, true)
        if not i then break end
        if i > start then out[#out + 1] = blob:sub(start, i - 1) end
        start = i + 1
    end
    return out
end

--- Every authored `.lua` path git tracks, in git's order.
---
--- The tracked set rather than a directory walk: Lua 5.1 has no directory API, and an untracked
--- scratch file is not something the cap has an opinion about. `libs/` and `tests/_kit/` are
--- dropped because they are the one carve-out that reaches this repository — vendored code
--- arrives by whole-folder copy and is audited where it is written, so the cap does not bind a
--- file this repo MUST NOT edit. The second carve-out, generated non-shipping data, has no
--- instance here; if one ever arrives it needs a rule in this function, and a red is the prompt.
local function trackedAuthoredLua()
    if not io.popen then
        fail("io.popen is unavailable, so the tracked set cannot be read")
    end
    local pipe = io.popen("git -C '" .. ROOT .. "' ls-files -z -- '*.lua'")
    if not pipe then fail("could not start `git ls-files`") end
    local blob = pipe:read("*a") or ""
    pipe:close()

    local paths = {}
    for _, path in ipairs(splitNul(blob)) do
        if not (path:find("^libs/") or path:find("^tests/_kit/")) then
            paths[#paths + 1] = path
        end
    end
    if #paths == 0 then
        fail("`git ls-files` reported no tracked .lua files, which cannot be true here")
    end
    return paths
end

--- Lines in `path`, counted as `wc -l` counts them, plus a final unterminated line if there is
--- one. Returns nil when the file cannot be opened, which the callers report rather than skip.
local function countLines(path)
    local fh = io.open(ROOT .. "/" .. path, "r")
    if not fh then return nil end
    local body = fh:read("*a") or ""
    fh:close()
    if body == "" then return 0 end
    local n = 0
    for _ in body:gmatch("\n") do n = n + 1 end
    if body:sub(-1) ~= "\n" then n = n + 1 end
    return n
end

--- The census table under CENSUS_HEADING in docs/ARCHITECTURE.md, as { path, disposition } rows.
---
--- A row is a table line whose first cell is a single backticked path; the heading row and the
--- `|---|` separator have no backticks and fall out on their own. Reading stops at the next
--- heading of any level, so a later section growing a table of its own cannot leak into this one.
local function censusRows()
    local fh = io.open(ROOT .. ARCHITECTURE, "r")
    if not fh then fail("docs/ARCHITECTURE.md could not be opened") end
    local body = fh:read("*a") or ""
    fh:close()

    local text = body:gsub("\r\n", "\n")
    local rows, inside, found = {}, false, false
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line == CENSUS_HEADING then
            inside, found = true, true
        elseif inside and line:sub(1, 1) == "#" then
            break
        elseif inside then
            local path, _, disposition = line:match("^|%s*`([^`]+)`%s*|%s*(.-)%s*|%s*(.-)%s*|%s*$")
            if path then
                rows[#rows + 1] = { path = path, disposition = disposition }
            end
        end
    end

    -- The ABSENCE of the section is not a failure by itself, and this is the one
    -- place that judgement lives. layout-§1's terminal state for a repository with
    -- no breach left is no breach AND no census — a table standing with no rows in
    -- it is the graveyard the section's own prose warns about. So absence is
    -- reported to the callers, which each decide what it means: a breach with no
    -- census to name it is red, and a census with no breach under it is red, but
    -- neither red is this function's to raise.
    return rows, found
end

-- ---------------------------------------------------------------------------
-- The two directions
-- ---------------------------------------------------------------------------

test("layoutcap: every authored file over 1500 lines is named in the ARCHITECTURE.md census", function()
    local rows, found = censusRows()
    local listed = {}
    for _, row in ipairs(rows) do listed[row.path] = true end

    local unremarked = {}
    for _, path in ipairs(trackedAuthoredLua()) do
        local n = countLines(path)
        if n == nil then
            fail("git tracks " .. path .. " but it cannot be opened")
        elseif n > CAP and not listed[path] then
            unremarked[#unremarked + 1] = path .. " (" .. n .. ")"
        end
    end

    if #unremarked > 0 then
        fail("over layout-§1's " .. CAP .. "-line cap and remarked on nowhere: " ..
             table.concat(unremarked, ", ") ..
             " — peel it, open an issue naming the seam it would peel on, or ratify a register " ..
             "row with a re-check trigger; then add the row to docs/ARCHITECTURE.md's census" ..
             (found and "" or " under a '" .. CENSUS_HEADING .. "' heading, which the file " ..
              "does not currently carry — it was removed when the last breach was peeled"))
    end
end)

test("layoutcap: no census row outlives the breach it records", function()
    local spent = {}
    for _, row in ipairs((censusRows())) do
        local n = countLines(row.path)
        if n == nil then
            spent[#spent + 1] = row.path .. " (no such file)"
        elseif n <= CAP then
            spent[#spent + 1] = row.path .. " (" .. n .. ", under the cap)"
        end
    end

    if #spent > 0 then
        fail("docs/ARCHITECTURE.md's cap census carries rows for files that no longer breach: " ..
             table.concat(spent, ", ") ..
             " — delete the row, and retire the register row or close the issue that backs it. " ..
             "The register must not become a graveyard")
    end
end)

test("layoutcap: every census row carries a disposition that can be followed", function()
    local rows = censusRows()

    -- NO ROWS IS A RESULT when nothing breaches, and on 2026-09-09 that is what this
    -- repository became: the last of fifteen files over the cap was peeled, the table
    -- came out, and the section above it stayed as prose saying so. Holding the old
    -- "a table with no rows is a graveyard" rule against THAT would be asking the hub
    -- to carry a row for a breach that does not exist.
    --
    -- The graveyard the rule was written against is a row that outlives its breach,
    -- and the case above this one is what catches it — in the other direction, by
    -- measuring the file rather than by counting the table. So the honest test here
    -- is: rows are only owed when something is over the cap.
    if #rows == 0 then
        local breaching = {}
        for _, path in ipairs(trackedAuthoredLua()) do
            local n = countLines(path)
            if n and n > CAP then breaching[#breaching + 1] = path end
        end
        if #breaching > 0 then
            fail("nothing is listed under '" .. CENSUS_HEADING .. "' and yet " ..
                 table.concat(breaching, ", ") .. " sits over the cap")
        end
        return
    end

    local unfollowable = {}
    for _, row in ipairs(rows) do
        -- layout-§1's second and third terminal states, and nothing else: an issue number to
        -- open, or the register row above to read. A disposition cell that names neither is a
        -- note, and a note is what this whole section exists to stop being enough.
        if not (row.disposition:find("#%d") or row.disposition:find("[Rr]egister row")) then
            unfollowable[#unfollowable + 1] = row.path
        end
    end

    if #unfollowable > 0 then
        fail("cap census rows whose disposition names neither an issue nor the register row: " ..
             table.concat(unfollowable, ", "))
    end
end)
