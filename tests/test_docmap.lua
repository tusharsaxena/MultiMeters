-- tests/test_docmap.lua — the Tier 2 register says what docs/ actually holds
-- (documentation-§3).
--
-- WHAT IT PROVES. That every row in docs/ARCHITECTURE.md's `### Conditional` table
-- agrees with the directory: a doc filed **Present** exists, and a doc filed **Not applicable** does
-- not.
--
-- WHY IT EXISTS. `documentation-§3` makes *Not applicable* a valid state that MUST be stated rather
-- than inferred from an empty directory, and that is the right rule — `ls docs/` alone cannot tell
-- "this addon does not need the page" from "nobody has written it yet". The cost is that the row
-- becomes the only witness, and a wrong row is then worse than a missing page. This addon's own
-- `compat-layer.md` row is the case in point: it read *re-measure — the trigger now fires* for long
-- enough to be quoted in two audit bundles, which is a register describing a state of affairs rather
-- than recording a decision.
--
-- WHAT IT DELIBERATELY DOES NOT DO: judge whether a trigger has fired. That is measurement and
-- prose — line counts, shim counts, "of the addon's own" — and it stays a human's to make and this
-- table's to record, exactly as the sibling registers do. The STATUS is not prose. It is the half a
-- machine can hold, and holding it is what stops the table describing a repository that no longer
-- exists.
--
-- It is the fourth register gate in this suite and strikes the same bargain as the other three
-- (tests/_kit/test_layout_cap.lua, tests/test_complexity_register.lua, tests/test_texture_paths.lua): it
-- reads a table out of docs/ARCHITECTURE.md, checks membership rather than the measurements beside
-- it, and FAILS rather than passes when it cannot look. A missing file, a missing heading or a table
-- that parses to nothing is red, not a skip — a gate that goes quiet when it is blind reports
-- success.

local T = _G.MULTIMETERS_TEST
local test, fail = T.test, T.fail
local ROOT = T.root or "."

local ARCHITECTURE = "/docs/ARCHITECTURE.md"
-- The heading is `documentation-§3`'s own, shared with the other ten repositories. It was
-- `### Tier 2 conditional docs` while this register carried a bespoke four-section shape of its
-- own; the register was moved onto the standard's four tables and the gate followed it here, in
-- the same change. Matching the canonical spelling is what keeps this gate portable.
local HEADING = "### Conditional"

local function architecture()
    local fh = io.open(ROOT .. ARCHITECTURE, "r")
    if not fh then fail("docs/ARCHITECTURE.md could not be opened, so this gate cannot run", 2) end
    local body = fh:read("*a") or ""
    fh:close()
    return (body:gsub("\r\n", "\n"))
end

--- Whether `docs/<name>` exists in the working tree.
local function docExists(name)
    local fh = io.open(ROOT .. "/docs/" .. name, "r")
    if fh then fh:close() return true end
    return false
end

test("doc map: every Tier 2 row agrees with what docs/ holds", function()
    local body = architecture()
    -- ANCHORED AT A LINE START, and that is load-bearing rather than tidy: the register's own
    -- preamble names `### Conditional` in prose a few paragraphs above the heading, and an
    -- unanchored match lands on the sentence instead — handing this gate a section with no table
    -- in it, which reads as "the shape changed" rather than "the pattern is wrong".
    -- Reading stops at the next heading of ANY level, so a later section's table cannot leak in.
    local section = body:match("\n" .. HEADING .. "[^\n]*\n(.-)\n##")
    if not section then
        fail("docs/ARCHITECTURE.md has no `" .. HEADING .. "` section followed by another heading, "
            .. "so the Tier 2 rows cannot be read and this gate is measuring nothing", 2)
    end

    local rows, offenders = 0, {}
    -- A row is `| `<doc>` | <status> | <trigger> |`. The doc cell may carry a parenthetical after
    -- the backticked name, which is why the name is taken from the backticks rather than the cell.
    for doc, status in section:gmatch("|%s*`([^`]+)`[^|]*|%s*([^|]-)%s*|") do
        if status == "Present" or status == "Not applicable" then
            rows = rows + 1
            local present = docExists(doc)
            if status == "Present" and not present then
                offenders[#offenders + 1] = doc .. ": filed Present, docs/" .. doc .. " is absent"
            elseif status == "Not applicable" and present then
                offenders[#offenders + 1] = doc .. ": filed Not applicable, docs/" .. doc .. " exists"
            end
        end
    end

    -- Seven rows, seven counted: a status cell that is decorated (`**Present**`) does not
    -- parse, and a gate resting on its own threshold cannot tell that from a deleted row.
    if rows < 7 then
        fail("read " .. rows .. " Tier 2 rows with a status this gate understands; the table "
            .. "carried seven when this was written, so either the shape changed or a status cell "
            .. "now says something other than Present / Not applicable", 2)
    end

    if #offenders > 0 then
        fail(#offenders .. " Tier 2 row(s) disagree with the directory. The row is the only thing "
            .. "an audit reads, so a wrong one is worse than a missing page:\n          "
            .. table.concat(offenders, "\n          "), 2)
    end
end)
