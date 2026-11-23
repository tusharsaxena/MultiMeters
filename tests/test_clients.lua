-- tests/test_clients.lua — Retail only, by the owner's decision (clients-§7, toc-file-§3).
--
-- The owner ruled on 2026-11-23 that Multi Meters is not ported to WoW Forever: there the
-- built-in meter hides each player's specialization as well as their identity, so a number
-- in the middle of a fight cannot be tied to the player it belongs to. The shape that ruling
-- asks for is four facts, and each one here is a file a reader can open:
--
--   1. the TOC carries ONE interface number and both load-gating lines, so the Forever
--      client never lists the addon (the exclude line is the one that holds when an
--      allow-list is not understood, clients-§7);
--   2. the README says "Retail only." at the start of its description and gives the reason;
--   3. docs/ARCHITECTURE.md records the same reason, and its documentation map files the
--      Forever catalog Not applicable under the `Retail` value, not under port pending;
--   4. no shipped file carries a Forever branch, which would be dead code here.

local T = _G.MULTIMETERS_TEST
local test, assertTrue, assertEqual = T.test, T.assertTrue, T.assertEqual

local ROOT = T.root or "."

local function readFile(rel)
    local fh = io.open(ROOT .. "/" .. rel, "rb")
    if not fh then return nil end
    local body = fh:read("*a")
    fh:close()
    return (body:gsub("\r", ""))
end

local function tocLines()
    local body = assert(readFile("MultiMeters.toc"), "MultiMeters.toc is missing")
    local lines = {}
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
    return lines
end

test("clients: the TOC carries one interface number and both Retail gating lines", function()
    -- red under: a second number on the Interface line, or either gating line dropped.
    local lines = tocLines()
    local interface = lines[1]:match("^## Interface:%s*(.-)%s*$")
    assertTrue(interface ~= nil, "the TOC's first line is not ## Interface")
    assertTrue(interface:match("^%d+$") ~= nil, "## Interface must be ONE number, got: " .. tostring(interface))
    assertEqual(lines[2], "## AllowLoadGameType: standard", "line 2 of the TOC")
    assertEqual(lines[3], "## ExcludeLoadGameType: camelot", "line 3 of the TOC")
end)

test("clients: the README says Retail only and why, with no port-pending wording", function()
    -- red under: the port-pending sentence ("WoW Forever support is planned") left in place.
    local body = assert(readFile("README.md"))
    assertTrue(body:find("\nRetail only%. ") ~= nil, "the description does not open with \"Retail only.\"")
    assertTrue(body:find("hides each player's specialization", 1, true) ~= nil,
        "the README does not give the owner's reason")
    assertTrue(body:find("support is planned", 1, true) == nil, "the README still says the port is planned")
end)

test("clients: docs/ARCHITECTURE.md records the reason and files Clients as Retail", function()
    local body = assert(readFile("docs/ARCHITECTURE.md"))
    assertTrue(body:find("Retail only by the owner's decision", 1, true) ~= nil,
        "ARCHITECTURE does not record the Retail-only decision")
    assertTrue(body:find("hides each player's specialization", 1, true) ~= nil,
        "ARCHITECTURE does not give the owner's reason")
    assertTrue(body:find("port pending", 1, true) == nil, "ARCHITECTURE still says port pending")
    assertTrue(readFile("docs/forever-quirks.md") == nil, "a Retail-only addon carries no docs/forever-quirks.md")
end)

test("clients: no shipped file reads the Forever client", function()
    -- red under: an `IsForever()` or `ForClient(...)` call in addon code, dead in a Retail-only addon.
    local files = T.loadedAddonFiles
    assertTrue(#files > 0, "the TOC-derived file list is empty")
    for _, rel in ipairs(files) do
        if rel:match("%.lua$") and not rel:match("^libs/") then
            local src = readFile(rel) or ""
            assertTrue(src:find("IsForever%s*%(") == nil, rel .. " reads IsForever()")
            assertTrue(src:find("ForClient%s*%(") == nil, rel .. " gates on ForClient()")
        end
    end
end)
