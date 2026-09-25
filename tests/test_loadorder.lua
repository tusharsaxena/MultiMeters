-- tests/test_loadorder.lua — the TOC is the load list, and the load list is right.
--
-- Three separate failures live here, and only the third is about ORDER:
--
--   1. a TOC line naming a file nobody shipped. The client logs it and carries
--      on, so the addon loads with a module missing and nothing says so.
--   2. a `.lua` on disk that no TOC line names. It is dead in the client and
--      alive in the editor, which is how a "fixed" bug comes back — the fix went
--      into a file the game never reads.
--   3. a file-scope `local X = NS.Y` capturing a symbol a LATER file publishes.
--      That is the silent one. The local is nil forever, no error is raised at
--      load, and the consequence surfaces as "this feature does nothing" months
--      later. This addon is unusually exposed to it: nine of eleven core files
--      publish something the modules capture at file scope, and the TOC order
--      between them is stated only in prose at the top of each file.
--
-- The order case reads the SOURCE rather than the loaded namespace on purpose.
-- By the time a suite can look at NS every file has run, so every capture
-- resolved — a runtime check cannot see the ordering at all.

local T = _G.MULTIMETERS_TEST
local test, assertTrue, assertEqual = T.test, T.assertTrue, T.assertEqual

local ROOT = T.root or "."

--- Shell out for a recursive `.lua` listing. Lua 5.1 has no directory API and
--- this repo does not depend on LuaFileSystem, so the listing goes through the
--- same `io.popen` seam the kit's own directory walk uses.
---
--- An EMPTY result means "could not look", never "no files": a gate that goes
--- quiet when it cannot look is worse than no gate, so every caller asserts the
--- listing is non-empty before drawing a conclusion from it.
local function findLua()
    local out = {}
    if not io.popen then return out end
    local cmd = ('find "%s" -name "*.lua" -not -path "*/libs/*" -not -path "*/tests/*" 2>/dev/null')
        :format(ROOT)
    local pipe = io.popen(cmd)
    if not pipe then return out end
    for line in pipe:lines() do
        local path = line:gsub("[\r\n]+$", "")
        -- Back to repo-relative, and forward-slashed, so it compares against a
        -- TOC entry as Loader.tocFiles hands it over.
        path = path:gsub("\\", "/"):gsub("^" .. ROOT:gsub("%p", "%%%0") .. "/", "")
        if path ~= "" then out[#out + 1] = path end
    end
    pipe:close()
    table.sort(out)
    return out
end

--- Whole-file source, or nil when it cannot be opened.
local function readFile(path)
    local fh = io.open(path, "r")
    if not fh then return nil end
    local body = fh:read("*a")
    fh:close()
    return body
end

-- ── the two directions of the TOC ───────────────────────────────────────────

test("loadorder: every file the TOC names exists on disk", function()
    -- red under: renaming any core/ or settings/ file without touching the TOC.
    assertTrue(#T.loadedAddonFiles > 0, "the TOC-derived file list is empty")
    for _, rel in ipairs(T.loadedAddonFiles) do
        local fh = io.open(ROOT .. "/" .. rel, "r")
        assertTrue(fh ~= nil, "MultiMeters.toc names a file that is not on disk: " .. rel)
        if fh then fh:close() end
    end
end)

test("loadorder: AceGUI-3.0 loads before AceConfig-3.0", function()
    -- AceConfigDialog-3.0 runs `local gui = LibStub("AceGUI-3.0")` at file load, without the silent
    -- flag, so it raises unless AceGUI is already registered. Listed first, AceConfig only loaded
    -- when some earlier addon in the client had happened to load AceGUI already.
    -- red under: MultiMeters.toc listing libs\AceConfig-3.0\AceConfig-3.0.xml above
    -- libs\AceGUI-3.0\AceGUI-3.0.xml.
    local src = readFile(ROOT .. "/MultiMeters.toc")
    assertTrue(src ~= nil, "MultiMeters.toc could not be read")
    local gui = src:find("libs\\AceGUI-3.0\\AceGUI-3.0.xml", 1, true)
    local cfg = src:find("libs\\AceConfig-3.0\\AceConfig-3.0.xml", 1, true)
    assertTrue(gui ~= nil and cfg ~= nil, "the TOC names both AceGUI-3.0 and AceConfig-3.0")
    assertTrue(gui < cfg, "AceGUI-3.0 must load before AceConfig-3.0: AceConfigDialog needs it at load")
end)

test("loadorder: every shipped .lua on disk is named by the TOC", function()
    -- `libs/` is excluded because vendored libraries come in through their own
    -- XML, which the TOC scan deliberately cannot see inside; `tests/` is
    -- excluded because the harness is not shipped and has no TOC line to have.
    -- Everything else — core/, defaults/, locales/, modules/, settings/ — is
    -- addon code, and addon code the client never loads is worse than absent.
    local onDisk = findLua()
    assertTrue(#onDisk > 0,
        "could not list the repo's .lua files — this gate cannot run and must not pass quietly")

    local declared = {}
    for _, rel in ipairs(T.loadedAddonFiles) do declared[rel:lower()] = true end

    local orphans = {}
    for _, rel in ipairs(onDisk) do
        if not declared[rel:lower()] then orphans[#orphans + 1] = rel end
    end
    assertEqual(table.concat(orphans, ", "), "",
        "these .lua files are on disk but in no TOC line, so the client never loads them")
end)

test("loadorder: the TOC declares no duplicate file line", function()
    -- A file listed twice runs twice. Every core/ file here is written to be
    -- loaded once — core/MultiMeters.lua calls AceAddon:NewAddon, and
    -- core/MediaSetup.lua registers the shipped face with LibSharedMedia — so a
    -- duplicated line is a second bootstrap, not a no-op.
    local seen, dupes = {}, {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        local key = rel:lower()
        if seen[key] then dupes[#dupes + 1] = rel end
        seen[key] = true
    end
    assertEqual(table.concat(dupes, ", "), "", "duplicate TOC entries")
end)

-- ── the ordering itself ─────────────────────────────────────────────────────

--- Every NS symbol a file PUBLISHES, in any of the four spellings the addon uses.
local function publishedBy(src)
    local names = {}
    for name in src:gmatch("NS%.([%w_]+)%s*=") do names[name] = true end
    for name in src:gmatch("function%s+NS%.([%w_]+)") do names[name] = true end
    for name in src:gmatch("function%s+NS:([%w_]+)") do names[name] = true end
    return names
end

--- Every NS symbol a file captures AT FILE SCOPE — a `local x = NS.y` starting
--- in column 1, which is the only place a load-time capture can live in these
--- files. A capture inside a function body is resolved at call time and is
--- deliberately not matched: several files rely on exactly that (core/PerfSetup's
--- `mod()`, settings/OptionsSetup's `helpers()`).
local function capturedBy(src)
    local names = {}
    for line in src:gmatch("[^\r\n]+") do
        local name = line:match("^local%s+[%w_]+%s*=%s*NS%.([%w_]+)")
        if name then names[#names + 1] = name end
    end
    return names
end

test("loadorder: no file captures an NS symbol a later file publishes", function()
    -- red under: moving core/Constants.lua below core/Namespace.lua in the TOC,
    -- or below defaults/Profile.lua, whose `local Const = NS.Constants` is the
    -- capture that would go nil.
    local files, sources = T.loadedAddonFiles, {}
    for _, rel in ipairs(files) do
        local src = readFile(ROOT .. "/" .. rel)
        assertTrue(src ~= nil, "cannot read " .. rel)
        sources[rel] = src or ""
    end

    -- symbol -> index of the FIRST file that publishes it.
    local firstPublisher = {}
    for i, rel in ipairs(files) do
        for name in pairs(publishedBy(sources[rel])) do
            if firstPublisher[name] == nil then firstPublisher[name] = i end
        end
    end

    -- Guard against a vacuous pass: if the capture scan finds nothing, the
    -- regexes have drifted from the source and this case is asserting over an
    -- empty set.
    local captures = 0
    local problems = {}
    for i, rel in ipairs(files) do
        for _, name in ipairs(capturedBy(sources[rel])) do
            captures = captures + 1
            local at = firstPublisher[name]
            -- An UNPUBLISHED symbol is not this case's business: NS.Perf,
            -- NS.Helpers and NS.RGBA all come from a LibKa0s seam rather than
            -- from an `NS.x =` line, and their absence is test_degraded's.
            if at and at > i then
                problems[#problems + 1] = ("%s captures NS.%s at file scope, but %s publishes it")
                    :format(rel, name, files[at])
            end
        end
    end
    assertTrue(captures >= 20,
        "the file-scope capture scan found only " .. captures ..
        " captures — the pattern has drifted and this case is asserting nothing")
    assertEqual(table.concat(problems, "; "), "", "file-scope capture ahead of its publisher")
end)

test("loadorder: locales/ loads ahead of every file that captures NS.L", function()
    -- Called out separately from the general case because NS.L is the one symbol
    -- whose absence is INVISIBLE: the locale table answers the key itself on a
    -- miss, so a nil `L` upvalue does not error at load — it errors on the first
    -- indexed lookup, deep inside a page builder, long after the mistake.
    local localeAt, firstReader
    for i, rel in ipairs(T.loadedAddonFiles) do
        if rel:lower():match("^locales/") then localeAt = localeAt or i end
        local src = readFile(ROOT .. "/" .. rel) or ""
        if not firstReader and src:match("[\r\n]local%s+L%s*=%s*NS%.L") then firstReader = i end
    end
    assertTrue(localeAt ~= nil, "the TOC declares no locales/ file")
    assertTrue(firstReader ~= nil, "no file captures NS.L — the scan found nothing to order")
    assertTrue(localeAt < firstReader,
        "locales/ must load before the first `local L = NS.L`")
end)

test("loadorder: the LibKa0s seams load in the order their headers pin", function()
    -- core/CoreSetup.lua sets NS.LIBKA0S_MISSING, and four of the others APPEND
    -- their own consequence to it. A seam loading ahead of CoreSetup would
    -- concatenate a nil and take the whole file down at load, on exactly the
    -- degraded install the clause exists to explain.
    local index = {}
    for i, rel in ipairs(T.loadedAddonFiles) do index[rel:lower()] = i end

    local core = index["core/coresetup.lua"]
    assertTrue(core ~= nil, "core/CoreSetup.lua is not in the TOC")

    -- TWO SEAMS ARE THE ODD ONES, AND THEIR POSITIONS ARE LOAD-BEARING THE OTHER
    -- WAY: both publish something an EARLIER-numbered file resolves at load, so
    -- both sit ahead of core/CoreSetup.lua rather than after it.
    --
    -- core/EnvSetup.lua is the sharper of the two. core/Namespace.lua calls the
    -- NS.Meta it publishes at FILE SCOPE, and a seam that loaded later would not
    -- raise and would not log -- NS.version would simply be the hardcoded
    -- FALLBACK_VERSION for the session, stamped on every capture record and every
    -- `/mm version`, and entirely plausible.
    local env = index["core/envsetup.lua"]
    assertTrue(env ~= nil, "core/EnvSetup.lua is not in the TOC")
    assertTrue(env < index["core/namespace.lua"],
        "core/EnvSetup.lua must load before core/Namespace.lua, which calls NS.Meta at file scope")

    -- core/MediaSetup.lua touches NS.LIBKA0S_MISSING not at all -- missing
    -- art degrades silently down the header's own ladder rather than explaining
    -- itself -- so it is free to load before CoreSetup, and it MUST: core/
    -- Constants.lua resolves FONT_MONO from the NS.MediaFont it publishes, and a
    -- Constants that loaded first would resolve it to the fallback on a perfectly
    -- healthy install.
    local media = index["core/mediasetup.lua"]
    assertTrue(media ~= nil, "core/MediaSetup.lua is not in the TOC")
    assertTrue(media < index["core/constants.lua"],
        "core/MediaSetup.lua must load before core/Constants.lua, which reads NS.MediaFont")
    for _, rel in ipairs({
        "core/perfsetup.lua", "core/debuglogsetup.lua", "core/launchersetup.lua",
        "settings/slash.lua", "settings/optionssetup.lua",
    }) do
        local at = index[rel]
        assertTrue(at ~= nil, rel .. " is not in the TOC")
        assertTrue(at > core, rel .. " must load after core/CoreSetup.lua")
    end

    -- core/LauncherSetup.lua reads NS.Constants.LOGO_128 at FILE SCOPE, because
    -- LibKa0s-Launcher-1.0 raises on a descriptor with no icon and a launcher wearing
    -- nothing draws nothing and raises nothing (launcher-§4, anti-pattern #82). A seam
    -- that loaded first would hand it nil and take the addon down at load.
    local launcher = index["core/launchersetup.lua"]
    assertTrue(launcher > index["core/constants.lua"],
        "core/LauncherSetup.lua must load after core/Constants.lua, which publishes LOGO_128")

    -- settings/OptionsSetup.lua publishes NS.RegisterOptionsPage, and every
    -- settings/<page>.lua CALLS it at file load -- so a page above this one
    -- registers into nil and the tree quietly has no pages in it.
    local optionsSetup = index["settings/optionssetup.lua"]
    for _, rel in ipairs({
        "settings/windows.lua", "settings/frame.lua", "settings/columns.lua",
        "settings/general.lua",
    }) do
        assertTrue(index[rel] > optionsSetup,
            rel .. " must load after settings/OptionsSetup.lua")
    end

    -- settings/Schema.lua declares the rows the page files register into, and
    -- both settings/Slash.lua and settings/OptionsSetup.lua point their seams at
    -- NS.GetSetting / NS.SetByPath.
    local schema = index["settings/schema.lua"]
    assertTrue(schema ~= nil, "settings/Schema.lua is not in the TOC")
    assertTrue(schema < index["settings/slash.lua"], "Schema must load before Slash")
    assertTrue(schema < optionsSetup, "Schema must load before OptionsSetup")
end)

test("loadorder: core/MultiMeters.lua loads after every core/ setup file", function()
    -- Its AceConsole reclaim reads NS.Util.print back off core/CoreSetup.lua,
    -- and its OnInitialize calls NS:InitDB from core/Database.lua at CALL time.
    -- Only the first of those is a load-order constraint, and it is the one an
    -- innocent-looking TOC reshuffle would break: the reclaim silently does
    -- nothing and every chat line comes out in AceConsole green.
    local index = {}
    for i, rel in ipairs(T.loadedAddonFiles) do index[rel:lower()] = i end
    assertTrue(index["core/multimeters.lua"] > index["core/coresetup.lua"],
        "core/MultiMeters.lua must load after core/CoreSetup.lua or the printer reclaim is a no-op")
    assertTrue(index["core/envsetup.lua"] < index["core/namespace.lua"],
        "core/Namespace.lua reads the TOC manifest through NS.Meta at LOAD time")
end)

-- ── the at-line annotations (toc-file-§5) ───────────────────────────────────

--- Index of every addon file in TOC load order, keyed lower-case and forward-slashed.
local function tocIndex()
    local index = {}
    for i, rel in ipairs(T.loadedAddonFiles) do index[rel:lower()] = i end
    return index
end

test("loadorder: the file-scope readers of CoreSetup, EnvSetup and OptionsSetup load after them", function()
    -- These pairs are the constraints the three LOAD-BEARING notes in the TOC state.
    -- red under: swapping any pair in MultiMeters.toc.
    local index = tocIndex()
    local function before(a, b, why)
        assertTrue(index[a] ~= nil and index[b] ~= nil, a .. " and " .. b .. " are both in the TOC")
        assertTrue(index[a] < index[b], a .. " must load before " .. b .. ": " .. why)
    end
    -- NS.LIBKA0S_MISSING is concatenated at file scope in both seams' degraded branch.
    before("core/coresetup.lua", "core/debuglogsetup.lua", "reads NS.LIBKA0S_MISSING at load")
    before("core/coresetup.lua", "core/launchersetup.lua", "reads NS.LIBKA0S_MISSING at load")
    -- The perf descriptor calls NS.Version() at file scope and takes `lifecycle`.
    before("core/envsetup.lua", "core/perfsetup.lua", "the descriptor calls NS.Version() at load")
    before("core/lifecyclesetup.lua", "core/perfsetup.lua", "the descriptor takes lifecycle at load")
    -- Aggregator captures both modules as upvalues at file scope.
    before("modules/provider.lua", "modules/aggregator.lua", "captures NS.Provider at load")
    before("modules/roster.lua", "modules/aggregator.lua", "captures NS.Roster at load")
    -- Every page file captures NS.Helpers, or registers through its seam, at load.
    for _, page in ipairs({
        "general", "windows", "frame", "header", "bars", "tooltip", "visibility",
        "columnblocks", "columns", "profiles",
    }) do
        before("settings/optionssetup.lua", "settings/" .. page .. ".lua", "the page reads NS.Helpers at load")
    end
end)

test("loadorder: each load-bearing seam line carries a LOAD-BEARING comment at the line", function()
    -- toc-file-§5: a load-bearing position MUST say so at the line. The comment
    -- block is the run of `#` lines directly above the entry.
    -- red under: deleting the note above any of these lines in MultiMeters.toc.
    local src = readFile(ROOT .. "/MultiMeters.toc")
    assertTrue(src ~= nil, "MultiMeters.toc could not be read")
    local lines = {}
    for line in (src or ""):gmatch("([^\n]*)\n?") do lines[#lines + 1] = (line:gsub("\r$", "")) end
    for _, entry in ipairs({
        "core\\CoreSetup.lua", "core\\PerfSetup.lua", "modules\\Aggregator.lua",
        "settings\\OptionsSetup.lua",
    }) do
        local at
        for i, line in ipairs(lines) do
            if line == entry then at = i end
        end
        assertTrue(at ~= nil, "MultiMeters.toc names " .. entry)
        local block, i = {}, (at or 1) - 1
        while i >= 1 and lines[i]:match("^#") do
            block[#block + 1] = lines[i]
            i = i - 1
        end
        assertTrue(table.concat(block, "\n"):find("LOAD-BEARING", 1, true) ~= nil,
            entry .. " is load-bearing but carries no LOAD-BEARING comment directly above it")
    end
end)
