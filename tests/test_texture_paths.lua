-- tests/test_texture_paths.lua — the hard-coded texture-path census gate (library-stack-§8).
--
-- WHAT IT PROVES. That every hard-coded `Interface\` path in the `.lua` this repository authors is
-- named in docs/ARCHITECTURE.md's "Hard-coded texture paths" census, and that no census row
-- outlives the path it records. It reads the tracked set from git and the table from the doc, and
-- compares them in BOTH directions.
--
-- WHY IT EXISTS. `library-stack-§8` makes LibKa0s-Media's catalog the vocabulary for marks: where
-- the addon needs one it uses the catalog's. The 2026-09-07 collection review found the rule
-- bypassed across all nine addons and could not say by how much, because three passes measured
-- three different numbers over three scopes nobody wrote down -- and the figure that was believed
-- was believed because it was the biggest. The plan's answer was that a hard-coded path is a
-- DECISION PER SITE, not a sweep: each one either has no catalog equivalent, carries a reason, or
-- is covered by a ratified register row.
--
-- A decision written once and never re-checked is the manifest nobody reads. This is the thing
-- that re-checks it: a new path arriving in this addon has to be argued for in the census before
-- the suite goes green again.
--
-- THE QUOTE IS PART OF THE PATTERN, and it is where the plan's own census went wrong here. Its
-- per-repo tally put this addon at 8, which is what matching the DOUBLED backslash of an escaped
-- string returns. Seven of this repository's paths are written as Lua LONG-BRACKET literals, the
-- form that needs no escaping and is what modules/ reaches for, and a pattern keyed on the doubled
-- backslash cannot see one of them. So an occurrence counts here when it OPENS A STRING, in either
-- of the two forms Lua has, and not otherwise: a comment quoting a path is prose about a texture
-- rather than a texture, and four such lines exist in this addon today.
--
-- WHAT IT DOES NOT ASSERT: the line and pair totals printed in the census prose. They are dated
-- measurements. Membership of the distinct file/path pair is the invariant, because a line number
-- moves on every ordinary edit while the arrival of a NEW path is the only event the rule has an
-- opinion about.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. No io.popen, no git, no ARCHITECTURE.md, no
-- census heading -- every one of those is a failure, not a skip. A gate that goes quiet when it is
-- blind reports success, which is worse than not existing. Same bargain tests/test_layout_cap.lua
-- strikes, and this file is deliberately built to its shape.

local T = _G.MULTIMETERS_TEST
local test, fail = T.test, T.fail
local ROOT = T.root or "."

local CENSUS_HEADING = "### Hard-coded texture paths"
local REGISTER_HEADING = "## Documented deviations"

-- The rule the two ColumnBlocks rows defer to. Spelled as the register writes it, so a row
-- retired by deletion cannot leave the reference dangling quietly.
local COLUMNBLOCKS_RULE = "library-stack §8"

--- Split a NUL-delimited blob. `git ls-files -z` because a path may contain anything but NUL, and
--- the line-oriented form quotes such a path instead of printing it -- a quoted path would not
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
--- `libs/` is dropped because vendored code arrives by whole-folder copy and is audited where it is
--- written; this repo MUST NOT edit it, so a rule it could not act on is not a rule. `tests/` is
--- dropped for a different reason and it is the plan's own scope: a path in a fixture is an
--- assertion ABOUT a string -- tests/test_mediasetup.lua spells out the vendored icon prefix
--- precisely so a wrong one is caught -- and no player ever sees it drawn.
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
        if not (path:find("^libs/") or path:find("^tests/")) then
            paths[#paths + 1] = path
        end
    end
    if #paths == 0 then
        fail("`git ls-files` reported no tracked .lua files outside libs/ and tests/, " ..
             "which cannot be true here")
    end
    return paths
end

--- Every hard-coded texture path in `body`, de-escaped, as a set.
---
--- An occurrence counts when it OPENS A STRING, in either form Lua offers: `"Interface\\...` or
--- `[[Interface\...]]`. Anything else -- a path inside a comment, a path inside a Markdown
--- backtick quoted in a banner -- is prose about a texture rather than a texture, and four such
--- lines exist in this addon today. They are named in the census, not given rows.
---
--- The doubled backslashes of the quoted form collapse to single, so both forms answer the one
--- spelling the census table carries and the one the client is handed.
local function pathsIn(body)
    local found = {}
    for opener, raw in body:gmatch('(["%[])%[?(Interface[\\%w%._%-]+)') do
        -- `["%[]` also matches a lone `[`, which is not a long bracket. Requiring the second `[`
        -- would need a back-reference Lua patterns do not have, so the opener is checked here.
        local ok = (opener == '"') or (body:find("[[" .. raw, 1, true) ~= nil)
        if ok then
            found[(raw:gsub("\\\\", "\\"))] = true
        end
    end
    return found
end

--- The whole of a repo-relative file, newline-normalised, or nil.
local function slurp(path)
    local fh = io.open(ROOT .. "/" .. path, "r")
    if not fh then return nil end
    local body = fh:read("*a") or ""
    fh:close()
    return (body:gsub("\r\n", "\n"))
end

--- Every `| ... |` row under `heading` in docs/ARCHITECTURE.md, as arrays of trimmed cells.
---
--- Reading stops at the next heading of any level, so a later section growing a table of its own
--- cannot leak into this one. The header row and the `|---|` separator come back too; callers
--- filter them by asking for the shape they want.
local function rowsUnder(heading)
    local body = slurp("docs/ARCHITECTURE.md")
    if not body then fail("docs/ARCHITECTURE.md could not be opened") end

    local rows, inside, found = {}, false, false
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        if line == heading then
            inside, found = true, true
        elseif inside and line:sub(1, 1) == "#" then
            break
        elseif inside and line:sub(1, 1) == "|" then
            local cells = {}
            for cell in line:sub(2):gmatch("([^|]*)|") do
                cells[#cells + 1] = (cell:gsub("^%s+", ""):gsub("%s+$", ""))
            end
            rows[#rows + 1] = cells
        end
    end

    if not found then
        fail("docs/ARCHITECTURE.md carries no '" .. heading .. "' section; it is where this " ..
             "repository's decision about each hard-coded path is written down, and it must " ..
             "not be removed")
    end
    return rows
end

--- The census as { file, path, disposition } rows. A row is a table line whose first two cells are
--- each a single backticked value; the header and separator have no backticks and fall out.
local function censusRows()
    local out = {}
    for _, cells in ipairs(rowsUnder(CENSUS_HEADING)) do
        local file = cells[1] and cells[1]:match("^`([^`]+)`$")
        local path = cells[2] and cells[2]:match("^`([^`]+)`$")
        if file and path then
            out[#out + 1] = { file = file, path = path, disposition = cells[3] or "" }
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The two directions, then the two things a row has to be good for
-- ---------------------------------------------------------------------------

test("texturepaths: every hard-coded path in authored source is named in the ARCHITECTURE.md census",
function()
    local listed = {}
    for _, row in ipairs(censusRows()) do listed[row.file .. "|" .. row.path] = true end

    local unremarked = {}
    for _, file in ipairs(trackedAuthoredLua()) do
        local body = slurp(file)
        if body == nil then
            fail("git tracks " .. file .. " but it cannot be opened")
        end
        for path in pairs(pathsIn(body)) do
            if not listed[file .. "|" .. path] then
                unremarked[#unremarked + 1] = file .. " -> " .. path
            end
        end
    end

    if #unremarked > 0 then
        table.sort(unremarked)
        fail("hard-coded texture paths remarked on nowhere: " .. table.concat(unremarked, ", ") ..
             " -- library-stack-§8 wants the catalog's mark where the catalog has one. Use it, " ..
             "or add the row to docs/ARCHITECTURE.md's 'Hard-coded texture paths' census saying " ..
             "why the catalog cannot answer here")
    end
end)

test("texturepaths: no census row outlives the path it records", function()
    local rows = censusRows()
    if #rows == 0 then
        fail("the census table under '" .. CENSUS_HEADING .. "' has no rows; if this repository " ..
             "really hard-codes no path any more, delete the section rather than leaving an " ..
             "empty table behind")
    end

    local spent = {}
    for _, row in ipairs(rows) do
        local body = slurp(row.file)
        if body == nil then
            spent[#spent + 1] = row.file .. " (no such file)"
        elseif not pathsIn(body)[row.path] then
            spent[#spent + 1] = row.file .. " -> " .. row.path .. " (no longer present)"
        end
    end

    if #spent > 0 then
        fail("docs/ARCHITECTURE.md's texture-path census carries rows for paths that are gone: " ..
             table.concat(spent, ", ") .. " -- delete the row, and retire the register row that " ..
             "backs it if it had one. The register must not become a graveyard")
    end
end)

test("texturepaths: every census row carries a disposition that can be followed", function()
    local unfollowable = {}
    for _, row in ipairs(censusRows()) do
        -- The three terminal states the plan allows, and nothing else: a rule citation saying the
        -- catalog does not answer for this class, or the deviation register above. A cell that
        -- names neither is a note, and a note is what this whole section exists to stop being
        -- enough.
        if not (row.disposition:find("%-§%d") or row.disposition:find("[Rr]egister row")) then
            unfollowable[#unfollowable + 1] = row.file .. " -> " .. row.path
        end
    end

    if #unfollowable > 0 then
        fail("census rows whose disposition cites neither a rule nor the register row: " ..
             table.concat(unfollowable, ", "))
    end
end)

test("texturepaths: the deviation register carries the row the ColumnBlocks sites point at",
function()
    -- The one site in this addon where the catalog HAS the mark and the addon declines it, so the
    -- one row whose disposition is a promise about another table rather than an argument in
    -- itself. If that row is ever retired -- ConsumableMaster adopts the catalog, or the colour
    -- and degraded-install arguments are answered upstream -- this is what says so out loud
    -- instead of leaving "Register row above" pointing at nothing.
    local ratified = false
    for _, cells in ipairs(rowsUnder(REGISTER_HEADING)) do
        if cells[1] and cells[1]:find(COLUMNBLOCKS_RULE, 1, true) then ratified = true end
    end

    if not ratified then
        fail("docs/ARCHITECTURE.md's deviation register carries no '" .. COLUMNBLOCKS_RULE ..
             "' row, but settings/ColumnBlocks.lua's two census rows defer to one. Either the " ..
             "row was retired -- in which case the two textures move to NS.Icon in the same " ..
             "commit -- or it was lost")
    end
end)
