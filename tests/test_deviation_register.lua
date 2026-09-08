-- tests/test_deviation_register.lua — the deviation register's own citations, resolved.
--
-- WHAT IT PROVES. That every deviation id `docs/ARCHITECTURE.md`'s `## Documented deviations`
-- section cites in a **Why** cell is an id some bundle under `docs/audits/` actually assigned.
--
-- WHY IT EXISTS. `audit-review-history` MUSTs it, and the reason it is a MUST is that this is the
-- failure a maintainer cannot see. An id that resolves to nothing has the right shape, sits in the
-- right sentence, and is read past by everybody who knows what an id looks like; only somebody who
-- went to the bundle would find out. Three of AbsorbTracker's four citations were dead for four
-- audits, and four of ConsumableMaster's six.
--
-- THE ONE SUBTLETY, and it is the whole case. "Resolves" is NOT "the string appears somewhere under
-- docs/audits/". A bundle that REPORTS a dead citation quotes the dead id while reporting it, so a
-- substring search goes green on the very defect it was written for -- `testing-§12`'s failure mode
-- installed inside the gate for it. What counts is the id being ASSIGNED: standing at the head of a
-- markdown table cell, a heading or a bullet, which is where a bundle puts a row's own id and is
-- never where prose that merely mentions one puts it.
--
-- WHAT IT DOES NOT DO. It does not read review-finding ids, issue numbers or rule citations. The
-- first two resolve into stores this gate does not open, and the third is a human's to read against
-- the current standard.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. A missing ARCHITECTURE.md, a missing section, no
-- bundles at all and a register citing nothing are each a failure, not a skip -- the same bargain
-- tests/test_complexity_register.lua and tests/_kit/test_eol.lua strike.

local T = _G.MULTIMETERS_TEST
local test, fail = T.test, T.fail
local ROOT = T.root or "."

local ARCHITECTURE = "/docs/ARCHITECTURE.md"

--- docs/ARCHITECTURE.md with line endings normalised, or a failure.
local function architecture()
    local fh = io.open(ROOT .. ARCHITECTURE, "r")
    if not fh then fail("docs/ARCHITECTURE.md could not be opened") end
    local body = fh:read("*a") or ""
    fh:close()
    return (body:gsub("\r\n", "\n"))
end

--- A bundle file's contents, or a failure.
local function readFile(path)
    local fh = io.open(path, "r")
    if not fh then fail("register gate: " .. path .. " could not be opened") end
    local body = fh:read("*a") or ""
    fh:close()
    return body
end

local DEVIATION_ID = { "%f[%w]MM%-[%u%-]*%d+", "%f[%w]MULTIMETERS%-[%u%-]*%d+" }

--- Every `.md` under a dated bundle directory.
local function bundleFiles()
        if not io.popen then
                fail("register gate: io.popen is unavailable, so this gate cannot run and must not be "
                        .. "reported as a pass")
        end
        local p = io.popen("ls -1 " .. ROOT .. "/docs/audits/*/*.md 2>/dev/null")
        if not p then fail("register gate: io.popen returned no handle") end
        local out = {}
        for line in p:lines() do
                if line ~= "" then out[#out + 1] = line end
        end
        p:close()
        return out
end

--- Does `id` head a table cell, a heading or a bullet anywhere in `files`?
local function isAssigned(id, files)
    local function heads(s)
        return s:sub(1, #id) == id and not s:sub(#id + 1, #id + 1):match("[%w%-]")
    end
    for _, path in ipairs(files) do
        for line in (readFile(path) .. "\n"):gmatch("([^\n]*)\n") do
            local trimmed = line:gsub("^%s+", "")
            local lead = trimmed:match("^#+%s*(.*)$") or trimmed:match("^[%-%*]%s+(.*)$")
            if lead and heads((lead:gsub("^[%s%*`%[]+", ""))) then return true end
            if trimmed:sub(1, 1) == "|" then
                for field in (trimmed .. "|"):gmatch("([^|]*)|") do
                    if heads((field:gsub("^[%s%*`%[]+", ""))) then return true end
                end
            end
        end
    end
    return false
end

test("every deviation id the register cites is assigned by a bundle in docs/audits/", function()
  -- The sentinel is what lets the register be the file's LAST `##` section without the slice
  -- silently coming back nil and the case passing on an empty string.
    local body = architecture() .. "\n## \n"
    local section = body:match("\n## Documented deviations\r?\n(.-)\r?\n## ")
    if section == nil then
            fail("docs/ARCHITECTURE.md carries no `## Documented deviations` section, so the register "
                    .. "cannot be read and this gate must not be reported as a pass")
    end

    local files = bundleFiles()
    if #files == 0 then fail("register gate: no bundle file under docs/audits/ to resolve against") end

    local seen, cited, offenders = {}, 0, {}
    for _, pattern in ipairs(DEVIATION_ID) do
        for pos, id in section:gmatch("()(" .. pattern .. ")") do
      -- A hyphen in front means this is the tail of a longer id (a work-item `M1-LK-11`), not a
      -- citation of a bundle row.
            if section:sub(pos - 1, pos - 1) ~= "-" and not id:find("%-R%-") and not seen[id] then
                seen[id] = true
                cited = cited + 1
                if not isAssigned(id, files) then offenders[#offenders + 1] = id end
            end
        end
    end

    if cited == 0 then
            fail("the register cites no deviation id at all -- either the rows changed or DEVIATION_ID did")
    end
    if #offenders > 0 then
            fail("cited by a register row and assigned by no bundle under docs/audits/: "
                    .. table.concat(offenders, ", "))
    end
end)
