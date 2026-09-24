local _, NS = ...
NS.Slash = NS.Slash or {}
local Sl = NS.Slash

-- settings/Slash.lua — wires the addon into LibKa0s-Slash-1.0.
--
-- The dispatcher, the help renderer, the row and key/value formatters, the list
-- builder and the type-aware value parser live in libs/LibKa0s/Slash.lua and are
-- shared across every Ka0s addon. What stays ours is what is genuinely ours: the
-- verb table, the six host verbs that act on windows rather than on schema rows,
-- and the adapters that point the library's schema seams at this addon's write
-- seam.
--
-- ── WHY NS.COMMANDS IS POSITIONAL ───────────────────────────────────────────────
--
-- The entries are ORDERED POSITIONAL TRIPLES `{ name, description, handler }`.
-- That is the shape the library reads — `entry[1]`, `entry[2]`, `entry[3]` — and
-- a table of named fields (`{ name =, desc =, fn = }`) does not fail loudly: it
-- loads, dispatches nothing, and answers every verb the user types with "unknown
-- command". There is no error to read and nothing in the log.
--
-- The table STAYS THIS ADDON'S and is passed IN rather than owned, and that is
-- the load-bearing decision rather than an oversight: the settings landing page
-- renders these same rows, and if the library owned the table then the options
-- major drawing that page would have to resolve the slash major to read it — a
-- real dependency cycle between two majors at load time. Crossing between them as
-- plain data is what keeps them independent.
--
-- ── WHY THE HANDLERS RESOLVE LATE ───────────────────────────────────────────────
--
-- `cli` and every host verb below are FORWARD-DECLARED as locals above the table
-- and assigned beneath it. A handler therefore closes over the upvalue rather
-- than over its value, and resolves at CALL time — which is what lets the verb
-- table sit above the dispatcher it dispatches through, and lets the window verbs
-- reach modules/WindowManager.lua, which loads long after this file.
--
-- TOC POSITION: settings/, after core/CoreSetup.lua (the printer) and after the
-- schema seam this file's adapters call. Everything else is resolved through NS
-- at call time, so nothing further binds.

local L = NS.L

local function out(line)
    if NS.Print then NS.Print(line) end
end

--- The version the help header and `/mm version` both report. Read from the TOC
--- metadata first, so it cannot drift from the packaged manifest
--- (slash-commands-§3), with the in-code constant as the fallback for a client
--- without the metadata API. core/PerfSetup.lua resolves the same pair the same
--- way, so a capture record and `/mm version` cannot disagree.
---
--- The manifest is read through NS.Meta rather than by naming C_AddOns here:
--- core/EnvSetup.lua owns the seam over LibKa0s-Env-1.0 (architecture-§1), so an
--- inline re-spelling would both duplicate the ladder and drop the pre-11.x rung
--- it exists to keep. NS.Version() is that pair — manifest first, constant after
--- — resolved once, in one place.
Sl.Version = NS.Version

-- Forward declarations. See "WHY THE HANDLERS RESOLVE LATE" above — every one of
-- these is assigned below the verb table that references it.
local cli
local doLock, doTest, doToggle, doWindow, doResetPositions, doExport, doDebug, doPerf, doResetAll
local doEnabled

-- ---------------------------------------------------------------------
-- The verb table
-- ---------------------------------------------------------------------
--
-- The ten reserved verbs first, in the order slash-commands-§2 fixes, then this
-- addon's own. Every sub-verb a handler accepts is named in its own `desc`,
-- because the generated help index, the settings landing page and the README's
-- command table all read these strings and nothing else — a sub-verb missing here
-- is a sub-verb nobody can discover (slash-commands-§4).
NS.COMMANDS = {
    { "help",     "Show this help",            function() cli:PrintHelp() end },
    { "config",   "Open the settings panel",   function() if NS.OpenOptionsPanel then NS.OpenOptionsPanel() end end },
    -- RESERVED ALIASES, NOT A SECOND SWITCH (slash-commands-§2). Both write the path the
    -- `Enable Multi Meters` checkbox writes, through the seam it writes through, so the two
    -- surfaces can never show the player different answers and one onChange runs whichever
    -- was used. They hold NO state of their own -- no second key, no session flag, no
    -- `NS.enabled` local -- and `/mm set enabled true|false` is the same write by its long name.
    { "enable",   "Turn the addon on",         function() doEnabled(true) end },
    { "disable",  "Turn the addon off without unloading it",  function() doEnabled(false) end },
    { "list",     "List every setting",        function() cli:CliList() end },
    { "get",      "Read one setting: /mm get <path>",      function(a) cli:CliGet(a) end },
    { "set",      "Write one setting: /mm set <path> <value>", function(a) cli:CliSet(a) end },
    { "reset",    "Reset one setting: /mm reset <path>",   function(a) cli:CliReset(a) end },
    { "resetall", "Reset all settings (asks first; deletes extra windows)", function() doResetAll() end },
    { "debug",    "Console; 'on'/'off' set logging, 'tooltip' toggles the noisy tooltip channel, 'diag' a diagnostic report, 'recap' the death-recap probe, 'identity' the mid-pull correlation capture, 'feign on|off' the feign recording",
                                                                     function(a) doDebug(a) end },
    { "perf",     "Performance capture; try /mm perf help", function(a) doPerf(a) end },
    { "version",  "Print the addon version",   function() cli:CliVersion() end },

    { "lock",     "Lock or unlock all windows for dragging",         function(a) doLock(a) end },
    { "test",     "Toggle test mode \226\128\148 placeholder rows for positioning",
                                                                     function(a) doTest(a) end },
    { "toggle",   "Show or hide a window by name, or all windows",   function(a) doToggle(a) end },
    { "window",   "Window management \226\128\148 list, new, delete, copy",
                                                                     function(a) doWindow(a) end },
    { "reset-positions", "Move every window back to the center of the screen",
                                                                     function(a) doResetPositions(a) end },
    { "export",   "Export a window's segment \226\128\148 /mm export [window]",
                                                                     function(a) doExport(a) end },
}

-- ---------------------------------------------------------------------
-- The disabled gate -- the LIBRARY's, and the live set is its DATA
-- ---------------------------------------------------------------------
--
-- slash-commands-§2: a disabled addon SHOULD refuse a verb that DRIVES ITS
-- FEATURES rather than act on it. Acting is the wrong answer twice over -- the
-- player asked for something the addon is currently standing down from doing, and
-- a silent no-op leaves them with no clue why nothing happened -- so a feature
-- verb answers on ONE tagged line that names `/mm enable` and does nothing else.
--
-- THIS FILE USED TO WRAP `NS.COMMANDS` ITSELF, with its own ALWAYS_LIVE set and
-- its own re-spelling of the refusal line. Both are gone, and neither was wrong
-- when it was written: the wrap predated LibKa0s-Slash minor 12, and the wording
-- predated slash-commands-§7 fixing ONE shape for the line collection-wide. What
-- is left is two descriptor fields.
--
--   * `isEnabled` is asked at DISPATCH TIME, never cached, so the command after
--     `/mm enable` works.
--   * the live set is `lib.LIVE_VERBS` -- the standard's TWELVE reserved verbs --
--     and this host DELIBERATELY PASSES NO `liveVerbs` TO NARROW IT. The library
--     defaults to the right set, a narrowing here would be this addon deciding for
--     itself which half of the standard to keep, and v2.57.0 reversed exactly such
--     a narrowing after the owner hit `/mm` on a disabled addon and got a refusal
--     instead of the settings panel he was trying to reach.
--   * the refusal line is `cli:DisabledLine()`, built from `brandName` and the
--     library's own format string. Eleven addons each wording it slightly
--     differently is the drift the shared printer exists to end.
--
-- WHAT STILL ANSWERS WHILE DISABLED: `help`, `config`, `version`, `enable`,
-- `disable`, `debug`, `perf`, `get`, `set`, `list`, `reset`, `resetall`, and the
-- BARE `/mm`, which opens the settings panel through the host's `config` verb. A
-- player must be able to read and repair settings and reach the panel while the
-- addon is off -- which is exactly when they are most likely to need to -- and
-- `enable` above all, or the pair is one-way.
--
-- WHAT IS REFUSED: this addon's own six feature verbs -- `lock`, `test`,
-- `toggle`, `window`, `reset-positions`, `export`. Taking the SHOULD is a
-- judgment and this addon takes it: six of them is enough that a silent no-op
-- would be a real puzzle. `lock` is on that list under slash-commands-§8's own
-- ruling -- unlocking a frame that is not drawn is not a coherent request -- and
-- that says nothing about what `lock` MEANS here, which is this addon's ratified
-- deviation and is untouched.
--
-- IT ASKS `NS.IsDisabled`, NOT `NS.IsStoodDown`, and the difference is the one
-- case where the two disagree: a PERF-SUSPENDED addon is stood down and is not
-- disabled. The refusal line names `/mm enable`, which is the wrong advice for
-- someone mid-capture, and slash-commands-§7 keeps `perf` live for the same
-- reason -- the harness is a diagnostic, not a feature.

-- ---------------------------------------------------------------------
-- The degradation stub
-- ---------------------------------------------------------------------
--
-- `/mm` is registered unconditionally in Sl:Register, so something has to answer
-- it. The host verbs never went to the library, so they keep working untouched;
-- what is lost is the schema CLI, and each of those verbs NAMES the missing
-- library rather than going quiet.
--
-- Note what is NOT here: no copy of the row formatter, no copy of the key/value
-- shape, no copy of the value parser. Hand-copying the strings whose drift the
-- extraction exists to end is the one duplicate testing-§8 most specifically
-- forbids, so a degraded help row renders plainly and says so.
local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)

-- Set only in the stub branch below. doEnabled reads it: the stub's CliSet names the missing
-- library, so `/mm enable` and `/mm disable` write through the seam directly instead.
local degraded = false

if not SlashLib then
    degraded = true
    -- The cause half is core/CoreSetup.lua's shared clause (NS.LIBKA0S_MISSING);
    -- only the consequence is this seam's. This is the one of the five whose
    -- consequence comes FIRST — the verb has to lead, or "/mm list" is buried
    -- mid-sentence — so it reads "<verb> is unavailable. <cause>."
    local missing = " is unavailable. " .. NS.LIBKA0S_MISSING .. "."

    SlashLib = {}
    SlashLib.ParseValue = function() return nil, "the LibKa0s library is missing" end
    -- Answers the member without owning the vocabulary. `nil` is the library's
    -- own "not a boolean word" signal, so `/mm lock on` degrades to a toggle
    -- rather than to a Lua error — see doLock.
    SlashLib.ParseBool  = function() return nil end
    -- THE ONE LIBRARY STRING THIS STUB CARRIES (LibKa0s docs/api/Slash/version-15-docs.md, "The
    -- degradation stub"): a byte copy of the live `lib.DISABLED_LINE_FORMAT`, so a degraded build
    -- refuses in the collection's words (slash-commands-\194\1677). tests/test_degraded.lua pins
    -- it against the library through `NS.Slash.__stubFormat`, a debug seam set only here.
    SlashLib.DISABLED_LINE_FORMAT = "%s is disabled \226\128\148 enable it with |cFFFFFF00%s|r"
    Sl.__stubFormat = SlashLib.DISABLED_LINE_FORMAT

    function SlashLib:New(d)
        local stub = { SetRowAnnotator = function() end }
        local function absent(verb)
            return function() out(d.slash .. " " .. verb .. missing) end
        end
        for _, verb in ipairs({ "List", "Get", "Set", "Reset", "ResetAll" }) do
            stub["Cli" .. verb] = absent(verb:lower())
        end
        -- Formatted the way the live `cli:DisabledLine()` does: the plain-text brand, then
        -- `<slash> enable`. core/LauncherSetup.lua's refused left click reaches it through
        -- Sl:DisabledLine, so a stub without it raised there (MultiMeters-R-06).
        stub.DisabledLine = function()
            return SlashLib.DISABLED_LINE_FORMAT:format(tostring(d.brandName or d.slash),
                d.slash .. " enable")
        end
        stub.CliVersion = function() out("v" .. tostring(d.version and d.version() or "?")) end
        stub.LandingRows = function()
            local rows = {}
            for _, e in ipairs(d.commands or {}) do
                rows[#rows + 1] = d.slash .. " " .. e[1] .. " \226\128\148 " .. e[2]
            end
            return rows
        end
        stub.HelpRows = function()
            local rows = {}
            for _, r in ipairs(stub.LandingRows()) do rows[#rows + 1] = "  " .. r end
            return rows
        end
        stub.PrintHelp = function()
            out("v" .. tostring(d.version and d.version() or "?") .. " slash commands")
            for _, r in ipairs(stub.HelpRows()) do out(r) end
        end
        local function findVerb(name)
            for _, e in ipairs(d.commands or {}) do
                if e[1] == name then return e end
            end
        end
        stub.OnSlash = function(_, msg)
            local raw = (msg or ""):match("^%s*(.-)%s*$") or ""
            -- A bare `/mm` (empty or whitespace only) runs the host's `config`
            -- verb with "", exactly as LibKa0s-Slash minor 11 does
            -- (slash-commands-§4); the index is `/mm help`. With no library,
            -- `config` answers that the panel is unavailable, which is still an
            -- answer. No `config` entry falls back to the index, as the library does.
            if raw == "" then
                local config = findVerb("config")
                if config then return config[3]("") end
                return stub.PrintHelp()
            end
            local verb, rest = raw:match("^(%S+)%s*(.*)$")
            verb = (verb or ""):lower()
            verb = (d.aliases or {})[verb] or verb
            local entry = findVerb(verb)
            if entry then return entry[3](rest or "") end
            out("unknown command '" .. verb .. "'")
            stub.PrintHelp()
        end
        return stub
    end
end

-- ---------------------------------------------------------------------
-- The dispatcher
-- ---------------------------------------------------------------------

cli = SlashLib:New({
    slash        = "/mm",
    slashAliases = { "/multimeters" },
    commands     = NS.COMMANDS,
    aliases      = { options = "config" },   -- back-compat with the collection's older spelling

    -- The disabled gate (Slash minor 13). See "The disabled gate" above.
    --
    -- Resolved at CALL time through the seam rather than captured: this file loads
    -- before NS:InitDB has built a store, and `NS.IsDisabled` answers false until
    -- there is one -- absent means "nothing has said otherwise", which is not off.
    isEnabled = function() return not (NS.IsDisabled and NS.IsDisabled()) end,

    -- THE BRAND NAME IN PLAIN TEXT -- `Ka0s <Name>` -- and the SAME string
    -- core/LauncherSetup.lua hands the LDB object as its `label` (launcher-\194\1671).
    -- Reusing it is not an aesthetic choice: launcher-\194\1671 already forbids escape
    -- sequences in that field, which is what makes it safe to drop into a colored
    -- line, and it means this addon has one brand spelling rather than a second one
    -- invented for this message. NEVER the TOC `Title`, which MAY carry color
    -- escapes.
    brandName = L["Ka0s Multi Meters"],

    -- NO `liveVerbs`. The library's default IS the standard's twelve reserved
    -- verbs; naming a set here could only narrow it, and narrowing it is what
    -- standard v2.57.0 reversed.

    print   = function(line) out(line) end,
    version = NS.Version,

    -- ── The schema seams ──────────────────────────────────────────────────
    --
    -- All five point at the addon's ONE write seam and ONE reader
    -- (architecture-§5), so a `/mm set` takes exactly the path a panel
    -- checkbox takes: same validation, same debug line at the seam, same
    -- onChange, same panel refresh.
    --
    -- This addon's twist is that a window row's path is RELATIVE — `window.frame.width`
    -- rather than `windows.<id>.frame.width` — and NS.GetSetting / NS.SetByPath
    -- resolve it against the session's active window. That resolution lives
    -- behind the seam rather than here, which is exactly why the CLI can be this
    -- thin: `/mm set window.frame.width 300` is one path lookup from the library's
    -- point of view, and the active-window question is the schema's to answer.
    -- NOT `NS.GetSetting and NS.GetSetting(path) or nil`. That idiom collapses a stored
    -- `false` to nil, so EVERY boolean row that is off printed `enabled = nil` through
    -- `/mm get`, and every `/mm set <bool> false` echoed `nil` back as the value it had
    -- just stored -- a read-back that contradicts the write it is confirming. The guard is
    -- an explicit branch for that reason; the same shape NS.GetSetting itself uses for a
    -- session row, and for the same defect.
    get          = function(path)
        if not NS.GetSetting then return nil end
        return NS.GetSetting(path)
    end,
    -- THE REFUSAL IS RETURNED, NOT SWALLOWED (Slash minor 15). NS.SetByPath answers
    -- `false, reason` when a row's validate rejects the value or no window is
    -- selected, and stores nothing. CliSet echoes the re-read value after a write;
    -- handed nothing back, it printed the OLD value as though the write had landed.
    -- Returning the seam's answer makes CliSet print the INVALID line and the
    -- reason instead. A missing seam is a refusal too, named by the shared clause.
    set          = function(path, v)
        if not NS.SetByPath then return false, NS.LIBKA0S_MISSING end
        return NS.SetByPath(path, v)
    end,
    findRow      = function(path) return NS.FindSchemaRow and NS.FindSchemaRow(path) or nil end,
    allRows      = function() return NS.Schema or {} end,
    -- Handed the ROW, not the path: NS.ApplyDefault owns the deep copy a table
    -- default needs, so two profiles resetting to the same color default do not
    -- end up sharing one table. Its answer is returned for the same reason `set`'s
    -- is: exactly false (a row with no default) makes CliReset print the library's
    -- NO_DEFAULT line instead of echoing the value it left alone.
    applyDefault = function(row)
        if not NS.ApplyDefault then return false end
        return NS.ApplyDefault(row)
    end,

    -- The bulk bracket (Slash minor 8), the same pair settings/OptionsSetup.lua hands
    -- the Options major. No verb here reaches CliResetAll any more -- `resetall` is
    -- the profile reset below -- so this is the guard for whoever calls it next:
    -- a walk through it would log one `[Set] reset all: N rows`, not a line per row.
    bulkBegin = function(act, scope) if NS.Bulk then NS.Bulk.begin(act, scope) end end,
    bulkEnd   = function(act, scope, count, err, info)
        if NS.Bulk then NS.Bulk.finish(act, scope, count, err, info) end
    end,

    -- Written out rather than omitted, and it names BOTH halves of where a setting lives. `page`
    -- was the whole answer while a page was one scroll; a page is now a strip of tabs
    -- (options-ui-§13), and a listing that named only the page would send someone to a screen
    -- with no word on which of its six tabs to click. The separator is a byte escape for the
    -- same reason every other non-ASCII string in this addon is: a literal depends on the file's
    -- encoding surviving every editor between here and a client.
    groupKey = function(row)
        return (row.page or "?") .. " \226\128\186 " .. (row.group or "?")
    end,

    -- The echo for every list/get/set/reset line (Slash minor 5). The library's own renderer for
    -- every row but one: the column array (`window.columns`, one hidden row since issue #52) is a
    -- table the library has no formatter for, and its generic fallback masks what it cannot
    -- concatenate as a secret. It reads as how many columns are shown, the same words its
    -- `[Set]` line uses.
    format = function(row, value)
        if row and row.path == "window.columns" and type(value) == "table" then
            local shown = 0
            for _, c in ipairs(value) do if type(c) == "table" and c.enabled then shown = shown + 1 end end
            return ("%d shown"):format(shown)
        end
        return SlashLib.FormatValue and SlashLib.FormatValue(row, value) or tostring(value)
    end,
})

-- ---------------------------------------------------------------------
-- resetall — Reset all settings, not a schema walk
-- ---------------------------------------------------------------------
--
-- `/mm resetall` IS the General page's "Reset all settings" (options-ui-§12): one
-- act behind the button and the verb. It used to be the library's CliResetAll,
-- which walks the schema ONCE through NS.ApplyDefault -- and every `window.` path
-- resolves against the ACTIVE window, so the verb reset the window the picker
-- happened to be on, left every other window exactly as it was, and logged a
-- [Set] line per row, while four docs called it a profile reset.
--
-- IT ASKS FIRST, with the SAME popup the button opens (the owner's decision of
-- 2026-09-12). A profile reset deletes every extra window, and a verb that did
-- that on the spot was the one path to it with no warning. NS.ShowResetAll
-- (settings/General.lua) opens MULTIMETERS_RESET_ALL, and only its OnAccept
-- resets: Helpers.RestoreAllDefaults, the session rows then db:ResetProfile()
-- inside the library's bulk bracket, and one `[Set] reset profile ...` line from
-- core/Database.lua's OnProfileReset. No and Escape do nothing. The popup is
-- declared at file load, so a library-less install asks too, and its OnAccept
-- reaches the options stub's own real reset.
--
-- No chat line: the popup is the answer, and the reset happens after the verb
-- has returned.
doResetAll = function()
    if NS.ShowResetAll then NS.ShowResetAll() end
end

-- ---------------------------------------------------------------------
-- The host verbs
-- ---------------------------------------------------------------------
--
-- These act on WINDOWS — instances the registry owns, created and deleted at
-- runtime — not on schema rows, so the library's schema CLI has nothing to say
-- about them and they are untouched by its absence. Each is a thin router: the
-- rule, the validation and the message bus all live in modules/WindowManager.lua,
-- and duplicating any of it here would give the CLI and the settings panel two
-- different ideas of what "delete a window" means.

--- The registry, resolved at CALL time, with one honest line when the module
--- layer has not loaded (a half-installed addon, or a headless suite driving the
--- CLI alone).
local function wm()
    local m = NS.WindowManager
    if m then return m end
    out("window management is unavailable \226\128\148 modules/WindowManager.lua did not load.")
    return nil
end

--- `on` / `off` / anything, through the library's own boolean vocabulary rather
--- than a private one. A `nil` answer means "not a boolean word", which is
--- exactly the signal that distinguishes `/mm lock` (toggle) from `/mm lock off`
--- (set) without re-reading the raw text.
local function boolArg(rest)
    local word = tostring(rest or ""):match("^%s*(%S*)")
    return SlashLib.ParseBool(word)
end

--- `/mm enable` and `/mm disable`, as ALIASES of the one stored path.
---
--- STRAIGHT THROUGH `CliSet`, which is what makes them aliases rather than look-alikes: it is
--- the same call `/mm set enabled true` makes, so the write lands on NS.SetByPath with the
--- row's own validation, the seam's `[Set]` line, the row's `onChange` (the show ladder's
--- refresh) and the panel re-sync -- and the acknowledgment comes out in slash-commands-§5's
--- `path = value` shape, from the library's shared formatter, RE-READ after the write rather
--- than echoing what was asked for.
---
--- Spelling the boolean as a word rather than passing `true` is not a detour: `CliSet` takes
--- the raw rest of a command line and parses it against the row, which is the one place the
--- vocabulary for a boolean lives.
---
--- THE DISPATCHER SURVIVES THE DISABLED STATE, which is what keeps this pair from being
--- one-way. Nothing anywhere unregisters the chat command, tears down NS.COMMANDS or drops
--- the dispatcher. `/mm`, `/mm enable`, `/mm help`, `/mm config` and `/mm version` all keep
--- working with the addon off, so the player who turned it off can turn it back on without
--- opening the settings panel they were trying not to open.
---
--- WHAT DOES CHANGE WITH THE ADDON OFF is what a FEATURE verb answers -- see "The disabled
--- gate" above the dispatcher. `enable` is named on that gate's live list, so this handler is
--- reached unwrapped; a gate over it would BE the one-way switch the clause above exists to
--- prevent, which is why the live list is data rather than a judgment made per verb.
---
--- WITHOUT THE COMPOSED ROW, OR WITHOUT THE SLASH MAJOR, CliSet cannot carry the write: the
--- stub's CliSet names the missing library, and the live one finds no `enabled` row to parse
--- against on a load where LibKa0s-Options-1.0 (whose MasterControls composes it) is absent.
--- options-ui-§1 route (a): the pair then writes NS.SetByPath directly, which stores the path
--- through the Schema seam's `writeThrough` list and pulls the latch in its announce
--- (settings/Schema_Paths.lua). Same `path = value` acknowledgment, or the seam's refusal.
--- It never raises.
---
--- @param want boolean
function doEnabled(want)
    if not degraded and NS.FindSchemaRow and NS.FindSchemaRow("enabled") then
        cli:CliSet("enabled " .. tostring(want))
        return
    end
    local ok, err = false, NS.LIBKA0S_MISSING
    if NS.SetByPath then ok, err = NS.SetByPath("enabled", want) end
    out(ok and L["enabled = %s"]:format(tostring(want)) or tostring(err))
end

function doLock(rest)
    local M = wm()
    if not (M and M.SetLocked) then return end
    local want = boolArg(rest)
    if want == nil then want = not (M.IsLocked and M:IsLocked()) end
    M:SetLocked(want)
    out("windows " .. (want and "locked" or "unlocked \226\128\148 drag them into place"))
end

function doTest(rest)
    local M = wm()
    if not (M and M.SetTestMode) then return end
    local want = boolArg(rest)
    if want == nil then want = not (M.IsTest and M:IsTest()) end
    -- The one manual switch, shared with the General page's Test mode box: it
    -- keeps the windows on screen when the mode goes off, repaints the panel so
    -- the box follows, and refuses a start during combat, printing its own line
    -- (modules/WindowManager.lua) -- so a refusal prints nothing more here.
    if not M:SetTestMode(want) then return end
    out("test mode " .. (want and "on \226\128\148 showing placeholder rows" or "off"))
end

--- `/mm toggle` flips every window; `/mm toggle <name>` flips one. The name keeps
--- its case and its internal spacing, because a window name is user data and
--- folding it would resolve something the user did not name.
function doToggle(rest)
    local M = wm()
    if not (M and M.Toggle) then return end
    local name = tostring(rest or ""):match("^%s*(.-)%s*$")
    local ok, err = M:Toggle(name ~= "" and name or nil)
    if not ok and err then out(err) end
end

function doResetPositions()
    local M = wm()
    if not (M and M.ResetPositions) then return end
    local moved = M:ResetPositions()
    out(("moved %s back to the center of the screen"):format(
        tonumber(moved) == 1 and "1 window" or tostring(moved or 0) .. " windows"))
end

--- `/mm window <verb> [args]` — the four registry actions, each routed straight
--- through. The sub-verb is lowercased because it is an identifier; the remainder
--- is left exactly as typed because it is a window name.
local WINDOW_USAGE = "Usage: |cFFFFFF00/mm window list|r, "
    .. "|cFFFFFF00new <name>|r, |cFFFFFF00delete <name>|r, "
    .. "|cFFFFFF00copy <source> <target>|r"

-- The sub-verb table, built ONCE at file scope. slash-commands names an
-- `if verb == "x" then ... elseif` sub-dispatcher as an anti-pattern for the
-- reason visible in the version this replaced: the verb, the registry member it
-- needs and the usage fallback were smeared across a ladder, so "which sub-verbs
-- exist" could only be answered by reading every branch. A table answers it by
-- being read.
--
-- Every handler takes the registry and the untouched remainder of the line, and
-- answers modules/WindowManager.lua's own `ok, err` pair — including for the two
-- local refusals (a registry too old to carry the member, and a malformed copy),
-- which report WINDOW_USAGE through that same channel so doWindow has exactly one
-- place that prints a failure.
local WINDOW_VERBS = {}

--- `/mm window list`, and a bare `/mm window` — the registry renders its own
--- listing, because the columns belong with the data.
function WINDOW_VERBS.list(M)
    if not M.BuildListLines then return false, WINDOW_USAGE end
    for _, line in ipairs(M:BuildListLines()) do out(line) end
    return true
end

function WINDOW_VERBS.new(M, tail)
    if not M.Create then return false, WINDOW_USAGE end
    return M:Create(tail)
end

function WINDOW_VERBS.delete(M, tail)
    if not M.Delete then return false, WINDOW_USAGE end
    return M:Delete(tail)
end

--- `<source> <target>`: the source is the first word, the target the rest, so a
--- target name with spaces is expressible and a source with spaces is addressed
--- from the settings panel instead. A two-name command line has no unambiguous
--- split for both, and inventing one is a syntax the user has to learn for a job
--- the panel already does well.
function WINDOW_VERBS.copy(M, tail)
    if not M.CopyFrom then return false, WINDOW_USAGE end
    local source, target = tail:match("^(%S+)%s+(.+)$")
    if not source then return false, WINDOW_USAGE end
    return M:CopyFrom(source, target)
end

function doWindow(rest)
    local M = wm()
    if not M then return end
    local verb, tail = tostring(rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
    verb = (verb or ""):lower()

    -- A bare `/mm window` means "show me what I have", which is the listing.
    local handler = WINDOW_VERBS[verb == "" and "list" or verb]
    if not handler then return out(WINDOW_USAGE) end

    local ok, err = handler(M, tail)
    if not ok and err then out(err) end
end

--- The window `/mm export` means when the player named none.
---
--- The same three-step ladder settings/Schema.lua walks for a window-relative
--- path, and it falls back to the first window rather than to nil for the same
--- reason: the CLI has no picker, and `/mm export` typed on a fresh login —
--- where nothing has ever set `activeWindowId` — has to mean something rather
--- than fail with a message about an internal pointer the player has never
--- heard of.
---
--- @param M table the window registry
--- @return table|nil config
local function defaultWindow(M)
    local id = NS.State and NS.State.activeWindowId
    if id ~= nil then
        local cfg = M.Resolve(id)
        if cfg then return cfg end
    end

    local Database = NS.Database
    local list = Database and Database.GetWindows and Database.GetWindows()
    return list and list[1] or nil
end

--- `/mm export` exports the window being edited; `/mm export <name>` exports the
--- one named. The name keeps its case and its internal spacing for the reason
--- `/mm toggle` does — a window name is user data, and folding it would resolve
--- something the player did not name.
---
--- The CONFIG is handed over rather than the live instance: a window in the
--- registry that has never been built still points at a segment, and its numbers
--- are as exportable as a drawn one's.
---
--- The restriction is asked about through `NS.Export.Available()` and nowhere
--- else here. Whether an export may run is the export module's answer to give,
--- and a second copy of the question in this file would be the copy that keeps
--- saying yes after the rule changes.
---
--- @param rest string|nil the raw remainder of the command line
function doExport(rest)
    local E = NS.Export
    if not (E and E.Open) then
        out("export is unavailable \226\128\148 modules/Export.lua did not load.")
        return
    end

    local ok, reason = E.Available()
    if not ok then
        out(reason or "export is not available right now.")
        return
    end

    local M = wm()
    if not (M and M.Resolve) then return end

    local name = tostring(rest or ""):match("^%s*(.-)%s*$")
    local cfg
    if name ~= "" then
        cfg = M.Resolve(name)
        if not cfg then
            out(NS.L["No window named '%s'."]:format(name))
            return
        end
    else
        cfg = defaultWindow(M)
        if not cfg then
            out("there is no window to export.")
            return
        end
    end

    E:Open(cfg)
end

-- ---------------------------------------------------------------------
-- The two harness verbs
-- ---------------------------------------------------------------------

--- The three READ verbs, one entry each, reaching the report that verb names.
--- Built once at file scope: this is a slash path, but a table rebuilt per call
--- is an allocation the branches it replaced never made (performance-§11).
---
--- Each entry spells its call out as a LITERAL field access, exactly as the three
--- branches this table replaced did, rather than indexing NS.Diagnostics by a
--- stored method name. A Diagnostics that loaded but is missing the member — a
--- stale or half-loaded core/Diagnostics.lua — must still fail the way it always
--- did, naming the method it could not call; `D[name]()` would raise on `'?'`
--- instead and cost the reader the one word that identifies the gap.
---
--- The mapping is the whole contract: one verb reaches one report and never
--- another, so a typo here cross-wires two commands while still printing
--- something plausible.
local DEBUG_REPORTS = {
    diag     = function(D) return D.Report() end,
    recap    = function(D) return D.ReportDeathRecap() end,
    identity = function(D) return D.ReportIdentity() end,
}

--- `feign` is the issue #25 recording, and it is the only debug verb here that
--- takes an argument, because it is the only one that is not a read. The other
--- three ask the client a question at the moment they are typed; a feign is over
--- before a player finishes typing, so this one has to be armed before the run
--- and printed after it.
---
--- It lives out of line because it is the only branch with a nested ladder over
--- an argument, and it carries two invariants: the parse is LENIENT (the whole
--- remainder is lowercased and only the second word is read), and the printed
--- line follows what ARMING RETURNED rather than what was asked for, so nobody
--- runs a dungeon for a trace that was never armed.
local function doDebugFeign(rest)
    local D = NS.Diagnostics
    if not D then return end
    local arg = tostring(rest or ""):lower():match("^%s*%S+%s+(%S+)")
    if arg == nil then
        if D.ReportFeign then D.ReportFeign() end
    elseif arg == "on" or arg == "off" then
        local on = D.ArmFeignTrace and D.ArmFeignTrace(arg == "on") or false
        local line = on
            and "feign trace ON — run the dungeon, then `/mm debug feign`."
            or  "feign trace off."
        if NS.Print then NS.Print(line) end
    else
        -- NAMED AND REFUSED, following the dispatcher's own unknown-verb
        -- pattern above. Anything that was not `on`, `off` or nothing at all
        -- used to fall through to the report — so `/mm debug feign of`, typed
        -- by somebody who meant `off`, printed an empty recording and left the
        -- trace armed for the rest of the session with no line saying so. A
        -- typo in a diagnostic verb must cost the typo and nothing else.
        if NS.Print then
            NS.Print("unknown feign argument '" .. arg ..
                "' — `/mm debug feign on|off`, or `/mm debug feign` to print the recording.")
        end
    end
end

--- `/mm debug` toggles the WINDOW only; `/mm debug on|off` sets the session-only
--- logging flag through the DebugLog seam. They are separate on purpose: logging
--- runs with the console closed, so a bug can be reproduced first and the log
--- read afterwards.
function doDebug(rest)
    local word = tostring(rest or ""):lower():match("^%s*(%S*)") or ""

    -- The three read verbs run WITHOUT the debug log, deliberately, which is why
    -- this lookup sits ABOVE the `NS.DebugLog` guard below. They are what a
    -- player is asked to run when something looks wrong, and requiring them to
    -- enable a console first is one more step between a bug and its report.
    --
    -- `recap` is the issue #1 probe on its own — the same report the full `diag`
    -- carries, without the forty lines of atlas and font output around it.
    --
    -- `identity` is the issue #22 capture, and it is typed mid-pull, by a player
    -- who was asked to type it, so a console they must open first is a step
    -- between us and the measurement. The report itself says what it needs — the
    -- flag on, and a pull running — rather than going quiet when it has neither.
    local report = DEBUG_REPORTS[word]
    if report then
        if NS.Diagnostics then report(NS.Diagnostics) end
        return
    end

    if word == "feign" then
        doDebugFeign(rest)
        return
    end

    -- `tooltip` is a CHANNEL switch, not a report and not the console. It sits
    -- above the DebugLog guard with the read verbs because it is a flag on
    -- NS.State, which exists whether or not the console seam loaded -- and a
    -- player who types it on a degraded client should get the same answer as
    -- anybody else rather than silence.
    --
    -- A PURE TOGGLE, and it always prints the state it landed in. `feign` reads
    -- an argument because it is armed before a run and read after one; this is
    -- flipped and observed in the same second, so an argument would be a word to
    -- remember for no benefit. Printing the result is what makes it unambiguous
    -- without one.
    if word == "tooltip" then
        local S = NS.State
        if S then
            S.debugTooltip = not S.debugTooltip
            if NS.Print then
                NS.Print(S.debugTooltip
                    and "tooltip logging ON — mouse over a row and read the console."
                    or  "tooltip logging off.")
            end
        end
        return
    end

    if not NS.DebugLog then return end
    if word == "on" then
        NS.DebugLog:SetEnabled(true)
    elseif word == "off" then
        NS.DebugLog:SetEnabled(false)
    else
        -- A word the ladder does not know toggles the window, exactly as a bare
        -- `debug` does. The console verb never validated an argument; only
        -- `feign` refuses one, because only `feign` reads one.
        NS.DebugLog:Toggle()
    end
end

--- `perf` is registered HERE, by the addon, and never by the harness. The library
--- owns the run; the addon owns which slash command reaches it, because the verb
--- table above is the one place every command in this addon is declared and a
--- verb registered behind its back would be a verb the help index, the landing
--- page and the README all miss.
function doPerf(rest)
    if not (NS.Perf and NS.Perf.OnCommand) then return end
    local lines = NS.Perf.OnCommand(rest)
    if type(lines) ~= "table" then return end
    for _, line in ipairs(lines) do out(line) end
end

-- ---------------------------------------------------------------------
-- The published surface
-- ---------------------------------------------------------------------

function Sl:OnSlash(msg)  return cli:OnSlash(msg)  end

--- slash-commands-\194\1677's one refusal line, built by the library from `brandName`
--- and the collection's own format string.
---
--- Published because core/LauncherSetup.lua needs the SAME line for a refused
--- left-click, and launcher-\194\1672 says to call this rather than write the line
--- again: the wording is the collection's, it MUST NOT be re-spelled per call
--- site, and a second copy here is how eleven addons ended up with eleven
--- wordings. The degradation stub above answers it too, for the same reason it
--- answers every other member the addon reaches.
---
--- Published ONLY when the dispatcher has the member (MultiMeters-R-06). The
--- launcher guards on `Sl.DisabledLine` before calling it, so a wrapper that
--- always existed let a stub without the member raise through it.
if cli.DisabledLine then
    function Sl:DisabledLine() return cli:DisabledLine() end
end
function Sl:PrintHelp()   return cli:PrintHelp()   end
function Sl:HelpRows()    return cli:HelpRows()    end

--- The command list the settings landing page renders. The SAME formatter
--- `/mm help` prints through, minus the chat indent — so the panel and the help
--- block cannot drift, which is the whole reason settings/OptionsSetup.lua's
--- landing spec feeds this function rather than a second hand-written list.
function Sl:LandingRows() return cli:LandingRows() end

--- Registration goes through AceConsole, never through a raw SLASH_* global:
--- AceConsole owns the deregistration a `/reload` needs and the collision check
--- two addons claiming one token need, and a hand-rolled SLASH_MM1 has neither.
---
--- Both tokens reach the same dispatcher, so the alias is a real alias rather
--- than a second command with its own drift.
function Sl:Register()
    local target = NS.addon or NS
    if not target.RegisterChatCommand then return end
    target:RegisterChatCommand("mm", function(input) Sl:OnSlash(input) end)
    target:RegisterChatCommand("multimeters", function(input) Sl:OnSlash(input) end)
end
