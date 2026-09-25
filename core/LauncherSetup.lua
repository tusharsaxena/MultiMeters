local addonName, NS = ...

-- core/LauncherSetup.lua — wires the addon into LibKa0s-Launcher-1.0 (launcher-§1).
--
-- ── WHAT THIS REPLACED ───────────────────────────────────────────────────────────────────────
--
-- `modules/Minimap.lua`, which built the LibDataBroker object, registered it with LibDBIcon,
-- carried its own click handler and its own `Refresh` seam — about 200 lines of wiring that is
-- identical in every Ka0s addon, written once per addon in its own spelling. That is exactly the
-- shape `launcher-§1` names as anti-pattern #81, and the library exists to make it impossible.
-- What is left here is what is genuinely this addon's: its folder name, its logo, how its settings
-- panel opens, and the accessor-and-toggle pairs its status tooltip and options menu read.
--
-- ── ONE OBJECT, REGISTERED TWICE ─────────────────────────────────────────────────────────────
--
-- The library creates a single LibDataBroker-1.1 object of `type = "launcher"` and hands THAT
-- object to LibDBIcon-1.0. The minimap button and any broker display (Titan Panel, ElvUI data
-- texts, Bazooka) are two renderings of one object, so there is one `OnClick`, one icon and one
-- label, and `launcher-§2`'s click rule is satisfied on both surfaces by construction rather than
-- by two implementations agreeing.
--
-- ── THE BUTTONS: LEFT OPENS SETTINGS, RIGHT OPENS THE OPTIONS MENU ──────────────────────────
--
-- `launcher-§2` at standard v2.67.0 (Launcher minor 4, the owner's M6 ruling): the buttons mean the
-- same thing on every Ka0s addon and neither is reassignable. LEFT-click opens the settings panel,
-- in either state; RIGHT-click opens the client's own context menu, titled with the label, with a
-- checkbox per toggle this addon really has. The library builds both; this file only answers.
--
-- THIS ADDON HAS ALL FOUR, and `ADDONS.md` records them as its menu entries:
--
--     [x] Enabled         isEnabled     + setEnabled     /mm enable | /mm disable
--     [ ] Locked          isLocked      + toggleLock     /mm lock
--     [ ] Test mode       isTestMode    + toggleTestMode /mm test
--     [ ] Show window     isWindowShown + toggleWindow   /mm toggle   (its meter windows)
--
-- While the addon is disabled the library grays the last three with "enable the addon first" and
-- leaves Enabled live. The left button's old job here, toggling the windows (the retired rung
-- (a)), is the Show window entry now.
--
-- EVERY TOGGLE IS THE SLASH VERB'S OWN HANDLER, looked up in `NS.COMMANDS` at click time and called
-- exactly as the dispatcher calls it, with no argument (`/mm lock`, `/mm test`, `/mm toggle` bare
-- are the toggles). Nothing is reimplemented here: the verb's refusals (test mode refuses to start
-- in combat), its chat acknowledgment and its write seam are what the menu gets. A private path
-- from this file would be a second implementation of each verb, free to drift from the first.
--
-- `openSettings` goes through `NS.OpenOptionsPanel`, the seam the `config` verb uses, and that
-- seam carries the combat refusal — the options canvas is a protected frame and opening it
-- mid-pull is refused with a chat notice, not deferred — so a private path from this button
-- would be the one way to reach the panel without that guard.

-- ── WHY `minimap` IS A FUNCTION AND NOT A TABLE ──────────────────────────────────────────────
--
-- `db.global.minimap` does not exist when this file runs: the TOC reaches core/ long before
-- `NS:InitDB()` builds the AceDB instance. A table captured at file load would therefore be nil,
-- and a table captured after a profile operation would be one AceDB later replaces — either way
-- LibDBIcon would hold a table nothing else writes, and the button's dragged position would go
-- back to the library's default angle on the next login. The library resolves the closure at
-- Register time instead, which is what keeps the object LibDBIcon holds and the table the
-- settings row writes the same table.
--
-- GLOBAL, not profile, and that is `launcher-§3`'s decision rather than an accident: a minimap
-- button belongs to the INSTALLATION, so a profile switch must not move the player's buttons.
-- core/Database.lua's v15 step carries the table across from `db.profile.minimap`, `minimapPos`
-- included.
--
-- SURVIVING A RESET IS A SEPARATE PROPERTY AND THE SCOPE IS NOT THE ARGUMENT FOR IT. Whether the
-- button is shown is a per-installation display preference, in the same class as the ANGLE the
-- player dragged it to; the derivation this comment used to carry -- *Reset all settings* is a
-- profile reset, the table is global, therefore it cannot be reached -- is retired at standard
-- v2.54.0, because it only ever spoke about one of the two resets this addon ships and a page's
-- own Defaults button walked straight past it. The exemption that makes the property true lives
-- in settings/OptionsSetup.lua, at the one seam both resets put a default through.
--
-- ── THE INVERSION IS NOT HERE ────────────────────────────────────────────────────────────────
--
-- The Master-controls row says SHOWN and LibDBIcon's key says HIDDEN, so the row's own get/set
-- invert (settings/Schema_Compose.lua), reached through the single write seam (options-ui-§1) like
-- every other row, and its `set` is also where `Launcher:SetShown` is called so the button follows
-- the checkbox immediately rather than at the next reload. Nothing about that inversion lives in this file, and the
-- library declines to own it too.
--
-- ── TOC POSITION ─────────────────────────────────────────────────────────────────────────────
--
-- In core/ rather than modules/, with the other `<Module>Setup.lua` seams, and AFTER
-- core/Constants.lua: `NS.Constants.LOGO_128` is read at FILE SCOPE below, because the library
-- raises on a descriptor with no icon and a launcher wearing nothing would be the one failure
-- this section says is worse than not adopting at all. Everything else the descriptor names —
-- NS.db, NS.WindowManager, NS.OpenOptionsPanel, NS.COMMANDS — is resolved at CALL time, because
-- all four load later. `Register()` itself is called from core/MultiMeters.lua's OnInitialize, after InitDB.

local Launcher = LibStub and LibStub("LibKa0s-Launcher-1.0", true)

local L = NS.L

-- NO PERF BRACKET in this file, deliberately. Nothing here runs on a timer or per frame: the
-- launcher's callbacks fire on a human click and on a tooltip hover, and a bracket around either
-- would measure the player's reflexes rather than the addon's cost.

--- LibDBIcon's own table, resolved at CALL time. See the header for why this is a closure.
--- @return table|nil
local function minimapTable()
    local db = NS.db
    return db and db.global and db.global.minimap or nil
end

if not Launcher then
    -- A missing vendored library must degrade, not error at load. The stub answers every member
    -- the addon reaches — `Register` from OnInitialize and `SetShown` from the write seam — plus
    -- the three a suite drives, because a stub that omits one is not a fallback, it is a crash
    -- moved to a rarer code path (testing-§8).
    --
    -- `IsShown` and `SetShown` still read and write the STORE, and that is not a copy of the
    -- library: the boolean is the host's own `db.global.minimap.hide`, the seam writes it either
    -- way, and answering `true` here because nothing contradicted it would tell the checkbox
    -- something untrue. What is genuinely lost is the BUTTON, which is why `Register` and
    -- `SetShown` both answer false — the honest answer that the section's headline surface is not
    -- there.
    --
    -- The cause half is core/CoreSetup.lua's shared clause (NS.LIBKA0S_MISSING); only the
    -- consequence is this seam's. Do not re-spell the cause here.
    local missing = NS.LIBKA0S_MISSING .. ", so there is no minimap button and no broker plugin."
    local announced = false

    NS.Launcher = {
        Register = function()
            if not announced then
                announced = true
                if NS.Print then NS.Print(missing) end
            end
            return false
        end,
        IsRegistered = function() return false end,
        Object       = function() return nil end,
        IsShown      = function()
            local t = minimapTable()
            return not (t and t.hide)
        end,
        SetShown = function(_, shown)
            local t = minimapTable()
            if t then t.hide = not shown end
            return false
        end,
    }
    return
end

-- ---------------------------------------------------------------------------
-- The tooltip
-- ---------------------------------------------------------------------------
--
-- THE LIBRARY DRAWS IT, and this file only answers its questions (Launcher minor 3, launcher-§1
-- at standard v2.66.0; the click hints are fixed since minor 4). The block is the same in all
-- eleven addons and it shows while the addon is disabled:
--
--     Ka0s Multi Meters  v<version>      label + `version`, the TOC's
--     Enabled: Yes|No                    `isEnabled`, the `enabled` setting
--     Locked: Yes|No                     `isLocked`, every window's own lock
--     Test mode: On|Off                  `isTestMode`, the session flag
--     Left-click: Open settings
--     Right-click: Options menu
--
-- NO `onTooltipShow`. Through Launcher minor 2 this file drew the whole tooltip: the title, a
-- Version line and both click hints. All four are the library's now, and a hook that drew them
-- again would draw a second copy of each (anti-pattern #89). This addon has no line of its own to
-- add below the status block, so it passes no hook at all rather than an empty one.
--
-- EVERY STATE IS ONE THIS ADDON REALLY HAS, and each is read through the accessor its
-- Master-controls row or its slash verb reads, so the tooltip, the menu and the General page
-- cannot disagree:
--
--   Enabled is `not NS.IsDisabled()`: the `enabled` setting, the store `setEnabled` writes. NOT
--   `NS.IsStoodDown`, which the retired left-click gate asked so a perf capture refused the click
--   too. As a menu box that answer would untick Enabled mid-capture over a setting that is on,
--   and gray three entries whose verbs answer the capture themselves (`/mm toggle` prints the
--   suspend line).
--   Locked is `WindowManager:IsLocked()`, which is true only while EVERY window's own
--   `frame.locked` is on. That is the *Lock frame* row's `get` (settings/Schema_Compose.lua),
--   a view over the per-window locks rather than a lock of its own, and the answer `/mm lock`
--   flips.
--   Test mode is `NS.State.testMode`, the `state.testMode` row's store and the flag `/mm test`
--   toggles.
--   Show window is `WindowManager:AnyShown()`, the question a bare `/mm toggle` asks before it
--   hides them all or shows them all. Menu only: the tooltip draws no window line.
--
-- All accessors are resolved at CALL time and read on every show and every menu open: modules/
-- loads after core/, and a cached answer would go stale the moment the player clicked the lock in
-- a window's header.

--- Whether the addon is enabled: the stored setting, not the perf hold. See above.
--- @return boolean
local function isEnabled()
    return not (NS.IsDisabled and NS.IsDisabled())
end

--- Whether every window is locked. False on a build with no window manager, as the row answers.
--- @return boolean
local function isLocked()
    local M = NS.WindowManager
    return M ~= nil and M.IsLocked ~= nil and M:IsLocked() or false
end

--- Whether test mode is on.
--- @return boolean
local function isTestMode()
    return NS.State ~= nil and NS.State.testMode == true
end

--- Whether any meter window is on screen. False on a build with no window manager.
--- @return boolean
local function isWindowShown()
    local M = NS.WindowManager
    return M ~= nil and M.AnyShown ~= nil and M:AnyShown() or false
end

--- Run one slash verb's OWN handler, exactly as the dispatcher would for `/mm <verb>` with no
--- argument. Looked up in NS.COMMANDS at call time (settings/Slash.lua loads after core/), so the
--- menu and the verb are one function rather than two that agree. A build with no such verb does
--- nothing rather than raising.
--- @param verb string
local function runVerb(verb)
    for _, entry in ipairs(NS.COMMANDS or {}) do
        if entry[1] == verb then return entry[3]("") end
    end
end

--- The version from the TOC metadata, through the one reader `/mm version` and the options header
--- use (core/EnvSetup.lua). Never NS.version alone: that is the hardcoded fallback.
--- @return string|nil
local function version()
    return NS.Version and NS.Version() or nil
end

-- ---------------------------------------------------------------------------
-- The one object
-- ---------------------------------------------------------------------------

NS.Launcher = Launcher:New({
    -- THE FOLDER NAME, and it is not cosmetic: LibDBIcon keys the button's SAVED POSITION by it,
    -- so a second spelling here would drop the angle the player dragged the button to and label a
    -- broker display's row with the other name (launcher-§1). Taken from the vararg rather than
    -- written out, which is the one spelling neither this file nor the client can typo.
    name = addonName,

    -- This addon's own logo — never a Blizzard icon path and never a numeric file id, because a
    -- borrowed icon makes the addon look like something else in the one list where the player is
    -- choosing what to turn off (anti-pattern #82). The SAME file `MultiMeters.toc`'s
    -- `## IconTexture` names (launcher-§4), read at file scope so a payload without it fails here
    -- rather than drawing an empty button.
    icon = NS.Constants and NS.Constants.LOGO_128,

    -- THE BRAND NAME IN PLAIN TEXT -- `Ka0s <Name>` -- and launcher-§1 fixes that spelling because
    -- this string is printed BESIDE THE OTHER TEN. A broker display lists every plugin it has
    -- together, so `label` is the single field that decides whether the collection reads as one
    -- collection in Titan Panel or as eleven unrelated addons that happen to be installed at once;
    -- across the collection's adoptions it came out three ways, and one sorted under `A` while the
    -- rest sat under `K`.
    --
    -- DELIBERATELY NOT THE TOC'S `## Title`, and the two are not wired to each other even where
    -- they agree, as they happen to here. A Title MAY carry color escapes and one in the
    -- collection does -- Ka0s Pretty Chat's is `Ka0s |cffff0000P|cffff9900r|…` -- which a display
    -- that draws the string raw splatters across a row where every other row is plain text, and
    -- one that strips escapes mangles instead. No escape sequence of any kind belongs here.
    --
    -- NOT THE FOLDER NAME EITHER: that is the registration `name` above, which LibDBIcon keys the
    -- saved position by. `MultiMeters` is an identifier, `Ka0s Multi Meters` is a name.
    label = L["Ka0s Multi Meters"],

    -- A FUNCTION, not the table — see the header.
    minimap = minimapTable,

    -- LEFT-click, always, in either state (Launcher minor 4); and right-click on a client with no
    -- context-menu API. Resolved at call time: the seam is published by settings/OptionsSetup.lua,
    -- which loads after core/.
    openSettings = function()
        if NS.OpenOptionsPanel then NS.OpenOptionsPanel() end
    end,

    -- THE OPTIONS MENU'S PAIRS (Launcher minor 4) -- see "THE BUTTONS" in the header. Each toggle
    -- is the slash verb's own handler; each accessor is the one the tooltip or the verb reads.
    -- `setEnabled` is handed the state the addon is moving TO, which picks the verb.
    isEnabled      = isEnabled,
    setEnabled     = function(on) runVerb(on and "enable" or "disable") end,
    isLocked       = isLocked,
    toggleLock     = function() runVerb("lock") end,
    isTestMode     = isTestMode,
    toggleTestMode = function() runVerb("test") end,
    isWindowShown  = isWindowShown,
    toggleWindow   = function() runVerb("toggle") end,

    -- The tooltip's title. The rest of the status block reads the accessors above.
    version        = version,

    -- Both resolved at CALL time rather than captured, so this file's correctness does not depend
    -- on a TOC line staying where it is (anti-patterns #36).
    print = function(line) if NS.Print then NS.Print(line) end end,
    debug = function(tag, message) if NS.Debug then NS.Debug(tag, "%s", message) end end,
})
