local _, NS = ...

-- settings/OptionsSetup.lua — wires the addon into LibKa0s-Options-1.0.
--
-- The settings-canvas shell, the header and breadcrumb, the lazy Defaults button,
-- the five widget makers, the two-column flow engine, the landing-page builder
-- and the always-shown scrollbar patch live in
-- libs/LibKa0s/{Options,OptionsWidgets,OptionsScroll}.lua. This file is only the
-- part that is ours: where a value lives, which rows belong to which page, and
-- what "reset everything" has to clear that no schema row owns.
--
-- NS.Helpers IS the library instance, decorated in place by the page files with
-- the pieces that did not generalize (options-ui-§1). NEVER a fresh table that
-- copies members across: a page helper added later has to be able to call
-- Helpers.RenderRows like any other page does, and a suite that swaps a member
-- out to spy on it must be swapping the one the library's own callers see.
--
-- TOC POSITION: BEFORE every settings/<page>.lua, and load-bearing. Each page
-- file ends by calling `NS.RegisterOptionsPage(...)` at FILE LOAD, and this file
-- is what publishes that function -- below it, every page registers into nil and
-- the tree has no pages in it. What the page files do NOT do is reach a Helpers
-- member at load: their builders guard on `H and H.CreatePanel` and run later,
-- and settings/Schema.lua's `lsmValues` reads NS.Helpers from inside a closure at
-- render time. See the stub below for why that still needs a table.

-- ---------------------------------------------------------------------
-- The one rule about what a global reset must not touch
-- ---------------------------------------------------------------------
--
-- Profiles rows are AceDBOptions-supplied and resetting them deletes user data,
-- which is not what "restore defaults" means to anyone (options-ui-§3).
--
-- EVERYTHING ELSE IN THE PROFILE IS VETOED TOO, and that is not the loophole it
-- looks like. "Reset all settings" IS a profile reset now -- `resetProfile`
-- below hands the whole thing to AceDB -- so walking the schema first and writing
-- each row's default into the profile would announce CONFIG_CHANGED once per row
-- for values that are about to be discarded whole, and would still leave the
-- extra windows the player wanted gone.
--
-- What the row walk is left with is exactly what a profile reset CANNOT reach:
-- `sessionOnly` rows, whose storage is their own `set()` rather than the db
-- (`state.testMode`, `state.debugConsole`). Those have to be restored row by row
-- or they survive a reset that took everything around them. `master.locked` is
-- the third session row and is swept too: its set writes every window's own
-- lock, which the profile reset then replaces anyway, so there the walk is
-- redundant but harmless.
--
-- Named ONCE because it is enforced TWICE -- by the library through
-- descriptor.skipRestoreAll, and by the degradation stub's own reset loop, which
-- has to keep working with no library at all. Two spellings of one predicate is
-- how a reset ends up deleting profiles on exactly the install nobody tests.
-- ---------------------------------------------------------------------
-- The nesting mark
-- ---------------------------------------------------------------------
--
-- Blizzard's Settings tree draws every canvas subcategory of one addon at the
-- SAME depth, and this addon's pages are not one flat set: Frame, Header, Rows,
-- Bars, Text, Icons, Tooltip, Visibility and Columns all edit the window that
-- Windows has selected, while General and Profiles edit the addon. Nine pages
-- that silently retarget when a picker two pages up moves, presented as peers of
-- the two that never do, is the tree lying about what a click will change.
--
-- There is no API for a third level, so the mark is TYPOGRAPHY: two spaces, a
-- hyphen and a space, prefixed to the tree label ONLY. It is deliberately not
-- part of the page's own title -- the canvas heading and the breadcrumb keep the
-- plain name, because a page heading that starts indented reads as a layout bug.
--
-- THE INDENT DOES THE NESTING; THE HYPHEN MARKS THE ITEM. Two earlier spellings
-- got one of those and not the other, and both are recorded because each failed
-- in its own way:
--
--   U+21B3  a rightwards arrow with tip downwards -- exactly the right character,
--           and one Friz Quadrata does not have. The client drew a HOLLOW BOX in
--           front of all nine pages, and the tree offers no way to hand the
--           player a font that has the glyph.
--   "|- "   draws on any font and reads as a bulleted LIST rather than as
--           nesting: with nothing indenting it, the mark sat where the page name
--           should start and competed with it for the eye.
--
-- Whitespace was confirmed in the client to survive -- leading whitespace is the
-- kind of thing a UI toolkit trims, and this one does not -- which is what makes
-- the hyphen safe to add: it is decoration on an indent that is already doing the
-- work, rather than the only thing standing in for it. If a future client does
-- start trimming, the pages keep a visible "- " and degrade to a flat bulleted
-- list rather than to nothing at all.
--
-- TWO spaces rather than four: at four the hyphen sat far enough right that the
-- eye read the indent and the mark as two separate things rather than as one
-- label starting late.
--
-- Not a locale string. It is furniture rather than text, and a translator handed
-- two spaces and a hyphen has nothing to translate and one more chance to drop a
-- space.
local SUBPAGE_MARK = "  - "

--- The tree label for a page nested under Windows.
---
--- Used by the nine window pages at the RegisterCanvasLayoutSubcategory call and
--- nowhere else. General and Profiles do NOT call it: they are not about a
--- window, and marking them would make the mark mean nothing.
---
--- @param name string  the page's own display name
--- @return string
function NS.SubPageLabel(name)
    return SUBPAGE_MARK .. tostring(name)
end

local function vetoedFromResetAll(row)
    if row.page == "profiles" then return true end
    return not row.sessionOnly
end

-- ---------------------------------------------------------------------
-- The one row no reset in this panel may write
-- ---------------------------------------------------------------------
--
-- WHETHER THE MINIMAP BUTTON IS SHOWN IS A PER-INSTALLATION DISPLAY PREFERENCE, in the same class
-- as the ANGLE the player dragged the button to -- which LibDBIcon keeps in the very same table
-- and which no reset anywhere touches. Nobody has ever wanted "reset my settings" to also mean
-- "and put the button back on my minimap". launcher-§3 states that as a PROPERTY of the setting
-- rather than deriving it from where the value is stored, and this is the carve-out that makes it
-- true here. The property is the reason; the scope is not.
--
-- BOTH RESETS ARE REACHED THROUGH ONE SEAM, and only one of them was ever a threat:
--
--   *Reset all settings* (options-ui-§12) never reached the row and still does not. It is a
--   PROFILE reset -- the descriptor's `resetProfile` hands the whole profile to AceDB -- and this
--   table lives in `db.global`, which AceDB leaves alone. The library narrows its row walk to the
--   `sessionOnly` rows before it resets, and `vetoedFromResetAll` above vetoes this one anyway.
--   `db.global.schemaVersion` survives the reset too, so the migration runner that follows is a
--   no-op and cannot carry a fresh profile's table back over the global one.
--
--   THE PAGE-SCOPED *Defaults* BUTTON DID REACH IT, and that is what changed here. The minimap row
--   is a Master-controls row on the General page, so `LibKa0s-Options-1.0`'s `RestoreDefaults`
--   walked it with every other row on that page -- it consults no veto at all, by design, because
--   a page button resets its page -- and wrote the row's default, which is SHOWN. A player who
--   hid the button and later pressed Defaults on General to reset something else got the button
--   back, at the library's default angle.
--
-- HERE, AT `applyDefault`, RATHER THAN AT `skipRestoreAll`: this is the single seam BOTH library
-- walks put a default through, so one clause covers the page button, the global reset and any
-- reset the library grows next. `skipRestoreAll` cannot do the job -- `RestoreDefaults` never asks
-- it -- and a clause per page would be a clause to forget.
--
-- `/mm reset global.minimap.shown` IS NOT A RESET IN THIS SENSE and stays live. It reaches
-- NS.ApplyDefault through the SLASH descriptor (settings/Slash.lua), which this clause does not
-- sit on, and it is a player naming this one row on purpose -- the opposite of a sweep that
-- reached it on the way past. So is the checkbox, and so is `/mm set`.
local function survivesEveryReset(row)
    return row.path ~= nil and row.path == NS.MINIMAP_PATH
end

-- ---------------------------------------------------------------------
-- The Windows page's entries (MultiMeters#55)
-- ---------------------------------------------------------------------
--
-- ONE PAGE PER WINDOW. The Windows page draws the Active window band, a nav rail
-- (LibKa0s-Options' O.NavRail, options-ui-§13) whose entries are registered here,
-- and the selected entry's own tab strip. An entry IS a page key: its schema rows
-- keep `page`, their window-relative paths and their defaults, so `/mm get`,
-- `/mm set`, `/mm list`, profiles and every reset never see the rail. Each
-- settings/<entry>.lua registers at FILE LOAD, so the registry lives HERE, above
-- the fork: a library-absent load still knows the entries, and a page file never
-- has to ask which build it is on.
local sections = {}

-- The rail's order. General first -- options-ui-§14's escape: the acts on the
-- window whole live on the FIRST entry, named General, and the page opens on it --
-- then the window's surfaces. Fixed here, not taken from the TOC.
local GENERAL_SECTION = "windows"
local SECTION_ORDER = { GENERAL_SECTION, "frame", "header", "bars", "tooltip", "visibility", "columns" }

--- Register one entry of the Windows page.
--- @param key string    the entry's page key: the `page` its schema rows carry
--- @param label string  the rail entry's label
--- @param spec table    { tooltip = the rail entry's tooltip,
---                        render = fn(ctx), drawing the entry's strip and body under the band and
---                                 the rail (default: H.RenderTabbedSchema(ctx, key)),
---                        defaults = fn(ctx), the entry's Defaults (default: H.RestoreDefaults(key, ctx)) }
function NS.RegisterWindowSection(key, label, spec)
    spec = spec or {}
    sections[key] = { key = key, label = label, tooltip = spec.tooltip, spec = spec }
end

--- The registered entry `key`, or nil. Read-only: for the suite and the Windows page.
function NS.WindowSection(key) return sections[key] end

local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

local function helpers() return NS.Helpers end

-- ---------------------------------------------------------------------
-- The descriptor
-- ---------------------------------------------------------------------
--
-- Every callback reaches through the schema seam or through `helpers()` at CALL
-- time rather than capturing a member: the page files decorate this instance
-- AFTER this file has run, so a captured reference would be nil forever.

local descriptor = {
    parentTitle   = "Ka0s Multi Meters",
    -- Named rather than anonymous so /framestack attributes the canvas to this
    -- addon and two addons cannot collide on it.
    mainPanelName = "MultiMetersMainPanel",

    print = function(line) if NS.Print then NS.Print(line) end end,
    debug = function(tag, fmt, ...) if NS.Debug then NS.Debug(tag, fmt, ...) end end,

    -- The schema seams — the SAME three settings/Slash.lua passes, so a panel
    -- click and a `/mm set` are one event: same validation, same debug line at
    -- the write seam, same onChange, same refresh (options-ui-§1). The
    -- window-relative path resolution (`window.frame.width` against the active
    -- window) lives behind NS.GetSetting / NS.SetByPath, not here, which is what
    -- lets the panel's window picker retarget every window row by changing one
    -- piece of session state rather than by rewriting paths.
    get          = function(path) return NS.GetSetting and NS.GetSetting(path) or nil end,
    set          = function(path, value) if NS.SetByPath then NS.SetByPath(path, value) end end,
    -- THE ONE EXEMPTION IS HERE, not per page and not per reset. See "The one row no reset in
    -- this panel may write" above: the minimap row is a display preference the player arranged
    -- once, and neither the page's Defaults button nor Reset all settings may write it.
    applyDefault = function(row)
        if survivesEveryReset(row) then return end
        if NS.ApplyDefault then NS.ApplyDefault(row) end
    end,

    -- `filter` is ctx.unit, passed through by the library without interpreting
    -- it. Here it carries the active WINDOW, so one page definition renders the
    -- selected window's rows rather than every window's.
    --
    -- Resolved off NS, not off the library instance: SchemaForPage is
    -- settings/Schema.lua's, and reaching for it on `helpers()` found nothing and
    -- fell through to the inline loop below forever — a silent second grouping
    -- rule that could not follow the schema's. Read at CALL time even though
    -- Schema.lua loads first, so a TOC reshuffle cannot freeze a nil in.
    --
    -- The inline loop stays as the last resort for a half-loaded install (a page
    -- file that raised took RegisterSchemaRows with it), and is deliberately the
    -- same predicate NS.SchemaForPage uses.
    rowsForPage = function(pageKey, filter)
        if NS.SchemaForPage then return NS.SchemaForPage(pageKey, filter) end
        local rows = {}
        for _, row in ipairs(NS.Schema or {}) do
            if row.page == pageKey and not row.hidden then rows[#rows + 1] = row end
        end
        return rows
    end,
    allRows = function() return NS.Schema or {} end,

    skipRestoreAll = vetoedFromResetAll,

    -- RESET ALL SETTINGS IS A PROFILE RESET (options-ui-§12), and `resetProfile` is the
    -- library field that says so (LibKa0s-Options-1.0 minor 9). It used to be a
    -- hand-written `afterRestoreAll` here, and in eight sibling addons -- one policy
    -- the standard forbids varying, restated once per repo.
    --
    -- With the field supplied the library narrows its own row walk to the sessionOnly
    -- rows before calling this, so the veto above is belt to that braces on the live
    -- path; it is the WHOLE policy on the degraded one, where there is no library to
    -- do the narrowing.
    --
    -- The player asked for the equivalent of a brand-new profile, and that is one
    -- call: AceDB empties this profile (and only this one -- the profile LIST is
    -- untouched, which is the rule the Profiles veto exists for), the defaults merge
    -- back, and `OnProfileReset` lands on core/Database.lua's OnProfileChanged, which
    -- runs the migrations, re-seeds a single default window through SeedWindows and
    -- publishes PROFILE_CHANGED. Every window, the open panel and the aggregator's
    -- caches rebuild off that one message, exactly as they do for a profile switch.
    --
    -- It is deliberately DESTRUCTIVE in the one way the old sweep was not: extra
    -- windows are deleted rather than restyled, and window names go back to the
    -- shipped one. That is what "a new profile" means, and the popup asks first.
    --
    -- Positions come back for free -- they live in the profile -- so there is no
    -- ResetPositions call any more. A degraded install with no db has nothing to
    -- reset and says so by doing nothing, which is honest.
    --
    -- ANSWERS WHETHER IT RESET. The library ignores the answer and reports its own
    -- `info.profileReset`; the degradation stub below has no library and reads it,
    -- so a reset-all on an install with no db logs its row count instead of
    -- staying silent for a handler that will never fire.
    resetProfile = function()
        local db = NS.db
        if not (db and db.ResetProfile) then return false end
        db:ResetProfile()
        return true
    end,

    -- THE BULK BRACKET (LibKa0s-Options-1.0 minor 16, debug-logging-§10). The
    -- library calls it around RestoreDefaults (scope: the page key) and
    -- RestoreAllDefaults (scope "all", spanning the session-row walk AND the
    -- profile reset). The seam mutes its per-row `[Set]` line inside it and logs
    -- one `[Set] reset <scope>: N rows` at the close, N the rows whose stored
    -- value moved -- or nothing, when the act reset the profile, because
    -- OnProfileReset logs that once. The SAME pair goes to settings/Slash.lua's
    -- descriptor. Both halves are supplied: a mute with no close would stick.
    bulkBegin = function(act, scope) if NS.Bulk then NS.Bulk.begin(act, scope) end end,
    bulkEnd   = function(act, scope, count, err, info)
        if NS.Bulk then NS.Bulk.finish(act, scope, count, err, info) end
    end,

    -- Backs the color picker's 50 ms drag throttle. A descriptor field rather
    -- than an AceTimer embed, because embedding would be the library's second
    -- dependency-budget breach. Without it a drag commits every frame — and this
    -- addon has a color row per column, so the omission would be felt.
    -- The return is deliberately nil. From LibKa0s-Options-1.0 24.31.x
    -- (OptionsWidgets minor 31; libs/LibKa0s docs/api/Options/
    -- version-24.31.4.7.4-docs.md, "The drag throttles keep their own armed
    -- flag") the library arms its own flag around this call and never reads
    -- what it returns, so the 50 ms slider/color throttle holds with this
    -- nil-returning wrapper. Through minor 30 it read the return as "armed", and
    -- a nil defeated the throttle. C_Timer.NewTimer would buy nothing now and
    -- allocate a cancelable object per drag frame, so it stays After.
    scheduleTimer = function(fn, delay)
        if C_Timer and C_Timer.After then C_Timer.After(delay, fn) end
    end,

    getLSM   = function() return LibStub and LibStub("LibSharedMedia-3.0", true) end,
    -- The validator is settings/Schema.lua's — NS.ValidateSchema — and not a
    -- member of the library instance. Read off `helpers()` it was nil, so the
    -- path-resolution and default-agreement checks never ran in game and the one
    -- bug they exist to catch (a row whose writes land on a key nothing reads)
    -- could only ever surface in the headless suite. Resolved at CALL time for the
    -- same reason as rowsForPage above.
    validate = function()
        if NS.ValidateSchema then NS.ValidateSchema() end
    end,

    -- library-stack-§4: resolve AceGUI once and hand it over, so the page
    -- builders read NS.AceGUI instead of each resolving it again.
    onAceGUI = function(AceGUI) NS.AceGUI = AceGUI end,

    -- The landing page. Its command list is GENERATED from NS.COMMANDS through
    -- Sl:LandingRows() — never a second hand-written list, which is how a panel
    -- and a help block drift into disagreeing about what the addon can do.
    --
    -- `rows` is a FUNCTION rather than an array because the library calls it at
    -- render time: a re-render then picks up a verb registered since this spec
    -- was declared, and this file loads before some of them.
    buildMain = function(ctx)
        local H = helpers()
        if not (H and H.BuildLandingPage) then return end
        H.BuildLandingPage(ctx, {
            logo  = NS.Constants and NS.Constants.LOGO,
            -- Through NS.Meta, never by naming C_AddOns here: core/EnvSetup.lua
            -- owns the seam over LibKa0s-Env-1.0 (architecture-§1). The `or ""`
            -- stays: NS.Meta answers nil for a TOC without a `## Notes` line, and
            -- the landing page wants a string.
            notes = function()
                return NS.Meta("Notes") or ""
            end,
            sections = {
                {
                    heading = "Slash commands",
                    rows    = function()
                        return (NS.Slash and NS.Slash.LandingRows
                            and NS.Slash:LandingRows()) or {}
                    end,
                },
            },
        })
    end,

    -- Colors are stored in the keyed { r =, g =, b =, a = } shape, which IS the
    -- library's default. Written out anyway rather than omitted, because the
    -- stored shape is a real contract with the rest of the addon — every bar and
    -- text color read in modules/ unpacks it — and a silent default is a poor
    -- place for a contract to live.
    colorDecode = function(c)
        if type(c) ~= "table" then c = {} end
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end,
    colorEncode = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end,
}

-- Published for settings/Schema_Compose.lua's compose descriptor, whose
-- `resetProfile` forwards to this one at call time rather than restating the reset.
NS.OptionsDescriptor = descriptor

-- ---------------------------------------------------------------------
-- The degradation stub — VALUE-ANSWERING, not message-answering
-- ---------------------------------------------------------------------
--
-- Every other setup file in this addon degrades to a table whose members each
-- print an honest "not installed" line. This one MUST NOT, and the reason is not
-- importance but WHEN the missing code is reached (options-ui-§1, the documented
-- exception).
--
-- THE PAGE FILES GUARD ON THE MEMBER, NOT ON THE TABLE — `if not (H and
-- H.CreatePanel) then return nil end` — so what they need from a missing library
-- is a table whose members are the right SHAPE, not a table whose members
-- announce themselves. A member that printed "not installed" where a caller
-- expects a value is not a degradation, it is a different bug: `H.LSMValues` has
-- to answer something a dropdown can open AND `/mm set` can parse against, and a
-- chat line is neither.
--
-- So this branch's job is to keep every page file's guards ANSWERABLE. A member
-- reached for a value returns a usable one; a member reached from a builder or a
-- user action is a no-op, because by then there is no panel to draw into and a
-- no-op is honest.
--
-- WHAT THE OLD NOTE HERE CLAIMED, AND WHY IT WAS WRONG. It said the page files
-- evaluate Helpers members inside schema-row literals at FILE LOAD, so a nil
-- member would raise and take a third of NS.Schema with it. Nothing does that.
-- settings/Schema.lua's `lsmValues` returns a CLOSURE and reads NS.Helpers from
-- inside it, at render and parse time, guarded, answering `{}` when it is absent
-- — and its own header says why: that file loads BEFORE this one, so the
-- library's LSMValues cannot be called at declaration at all. The conclusion
-- survived the argument that was supposed to support it; the argument is now the
-- one above.
--
-- Note what is NOT here: no widget maker, no flow engine, no header, and none of
-- the library's LAYOUT constants. A host copy of a library constant is the copy
-- that goes stale, and hand-copying the code whose drift the extraction exists to
-- end is the one duplicate testing-§8 most specifically forbids.
if not lib then
    -- The cause half is core/CoreSetup.lua's shared clause (NS.LIBKA0S_MISSING);
    -- only the consequence is this seam's.
    local MISSING = NS.LIBKA0S_MISSING .. ", so the settings panel is unavailable."

    local Helpers = {}
    NS.Helpers = Helpers

    -- Reached for a VALUE rather than for an effect, so these have to answer with
    -- something the caller can use rather than with nil or with a chat line.
    --
    -- LSMValues is a DEFERRED closure on the live path — the media hash is pulled
    -- at dropdown-render time, because the addons that register media have not
    -- run when a row is declared. The stub keeps the deferral and answers a
    -- single placeholder, for the same reason the library never answers empty: a
    -- dropdown with no options cannot be opened, and the CLI would then refuse
    -- even the value already stored.
    Helpers.LSMValues = function() return function() return { None = "None" } end end

    -- Reached only from a builder or a user action, so a no-op is honest.
    for _, name in ipairs({
        "CreatePanel", "EnsureDefaultsButton", "EnsureScroll", "ClearScroll", "Section",
        "AddSpacer", "TextRow", "BuildLandingPage", "AttachTooltip", "InlineButtonPair",
        "RenderField", "RenderRows", "RenderSchema", "RenderGrid", "SessionCheckbox",
        "SetRenderer", "RefreshAllPanels", "RefreshScalars", "RefreshPanel", "RestoreDefaults",
        "PatchAlwaysShowScrollbar", "RegisterOptionsPage", "CreateOptionsPanel",
        "SetChromeHeight", "TabStrip", "PageBanner", "RenderTabbedSchema",
        "ChoiceGrid", "IdInput", "IdList",
        -- SelectTab, new at LibKa0s v1.36.0: reached only from a tab click on an already-rendered
        -- page. This addon does not adopt tab-scoped refresh, so the same inert no-op applies.
        "SelectTab",
        -- NavRail, new at LibKa0s v1.61.0 (OptionsNav minor 1): drawn only by the Windows page's
        -- render, which never runs with no library, so the same inert no-op applies.
        "NavRail",
        -- The Windows page's own members (MultiMeters#55), decorated onto the live
        -- instance below the fork. settings/Windows.lua's builder is their only caller,
        -- and it never runs here; the degraded scan and the parity case read them anyway.
        "RenderWindowPage", "RestoreActiveSection", "__bindWindowsPage", "SelectSection",
    }) do
        Helpers[name] = function() end
    end
    -- The id-picker's pure lookups (Options minor 18). No page calls them yet; with no
    -- library there is nothing to resolve against, so nil ("no id") is the inert answer,
    -- and an empty hint table the inert vocabulary. No copy of the library's kinds.
    Helpers.ResolveId         = function() return nil end
    Helpers.UnnamedCandidates = function() return nil end
    Helpers.ID_NAME_HINT      = {}
    Helpers.__pages    = function() return {} end
    Helpers.__panels   = function() return {} end
    Helpers.__panelFor = function() return nil end

    -- Kept REAL even though it is call-time: the user whose panel will not open
    -- is exactly the user who needs "reset everything", and the schema loaded
    -- fine, so the reset still works with no panel at all. It uses the same
    -- vetoedFromResetAll predicate the descriptor does, so a profiles row is safe
    -- on both paths rather than on the one somebody remembered.
    --
    -- BRACKETED THE WAY THE LIBRARY BRACKETS IT (Options minor 16): the session-row
    -- walk and the profile reset share one bulk bracket, so the rows written first
    -- are muted and the reset logs one line, OnProfileReset's. `resetProfile`
    -- answers whether it reset, and `info.profileReset` is how the walk tells the
    -- bracket (LibKa0s-Schema-1.0's BulkRun shape), which keeps the close silent.
    Helpers.RestoreAllDefaults = function()
        NS.Bulk.run("reset", "all", function(info)
            for _, row in ipairs(NS.Schema or {}) do
                if not vetoedFromResetAll(row) and NS.ApplyDefault then
                    NS.ApplyDefault(row)
                end
            end
            -- Then the profile itself, which IS the reset. On the live path the library
            -- calls this (LibKa0s-Options-1.0 minor 9's `resetProfile`); here there is no
            -- library, so the stub makes the same call. It exists because the LIBRARY is
            -- missing, not the db, and the user whose panel will not open is exactly the
            -- user who needs "reset everything".
            if descriptor.resetProfile and descriptor.resetProfile() then info.profileReset = true end
        end)
    end

    NS.RegisterOptionsPage = function() end
    NS.RefreshOptionsPanel = function() end
    NS.CreateOptionsPanel  = function()
        if NS.Print then NS.Print(MISSING) end
    end
    -- The one member a user actually reaches for. Same function as
    -- CreateOptionsPanel: there is nothing to create and nothing to open, and one
    -- honest line answers both.
    NS.OpenOptionsPanel = NS.CreateOptionsPanel
    -- And the page-targeted open (MultiMeters#55): the same honest line, because
    -- there is no page to open either.
    NS.OpenOptionsPage = NS.CreateOptionsPanel
    return
end

-- ---------------------------------------------------------------------
-- The live wiring
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- The LSM30_Border fixup, and why it is a call rather than a file
-- ---------------------------------------------------------------------
--
-- A LIBRARY ACT, NOT AN ADDON ONE. AceGUI's widget registry is process-global:
-- one slot named "LSM30_Border" that every addon in the client shares, Ka0s or
-- not, and the highest version registered for the name owns it for the rest of
-- the session. This addon carried the fixup privately in core/LSMPatch.lua, and
-- so did AbsorbTracker, ConsumableMaster, KickCD and PanelMaster -- five copies,
-- five distinct md5s, each wrapping whatever it found and registering one
-- version above it. Load all five and the wrapper a Border dropdown actually
-- gets belongs to whichever addon the client reached last. Nothing in any of the
-- five repos could see it: each suite loads a single copy, registers once and
-- passes -- and this one could not even do that, because the private copy did
-- its work from a PLAYER_LOGIN frame that never fires headlessly.
--
-- lib.__PatchLSM30Border (LibKa0s-Options-1.0 minor 15) is the same wrapper
-- published once, behind lib.__lsmBorderPatched. LibStub hands five vendored
-- copies of the library the same instance, so five callers produce one
-- registration and the return value says which call made it. Calling it is
-- unconditional and needs no agreement with any sibling addon.
--
-- HERE, AT FILE LOAD, is early enough, and the timing did change: the private
-- copy waited for PLAYER_LOGIN and this line does not. MultiMeters.toc pulls
-- libs\AceGUI-3.0-SharedMediaWidgets\widget.xml in with the other libraries
-- (:29), well before settings\OptionsSetup.lua (:85), so the slot already holds
-- AGSMW's own constructor when this runs. A registration whose version is not
-- strictly higher than the one already held is refused, so another addon's later
-- copy of AGSMW cannot take the slot back at its own fixed version. (Worded
-- around the AceGUI entry point on purpose: C02's acceptance is a grep for that
-- identifier over core/, modules/ and settings/ returning nothing, and a prose
-- mention is a hit an auditor has to read and dismiss.)
--
-- It sits in THIS file because this is where the addon's options surface is
-- wired, which is where the library's own note on the member says to call it
-- from -- and because this is the live arm, below the fork: an install with no
-- libs/LibKa0s took the stub's `return` above and has no library to ask. That
-- install also has no settings panel at all, so it has no Border dropdown to
-- misalign.
--
-- core/LSMPatch.lua IS GONE, deleted in the same commit that added this line.
-- Keeping it would have been a second registration of a wrapper the library has
-- already installed -- harmless in effect, since both hide the same tile and
-- re-anchor the same two regions, but it is the exact shape the promotion exists
-- to remove.
lib.__PatchLSM30Border()

NS.Helpers = lib:New(descriptor)

local Helpers = NS.Helpers

-- Every page's Blizzard category, by page key. The library's registry drops the
-- builder's return value, and Settings.OpenToCategory takes the category's id --
-- so NS.OpenOptionsPage (below) has no other way to send the player to one page.
-- Captured here rather than in the builders, so a page added later gets it free.
local categories = {}

NS.RegisterOptionsPage = function(key, name, builder)
    Helpers.RegisterOptionsPage(key, name, function(mainCategory)
        local cat = builder(mainCategory)
        if cat then categories[key] = cat end
        return cat
    end)
end
NS.CreateOptionsPanel  = function() Helpers.CreateOptionsPanel() end

-- OpenOptionsPanel REFUSES under combat lockdown and never defers-and-replays —
-- the library owns that refusal, and it is the standard's one documented
-- exception to "gate and defer" (options-ui-§1). A panel that opened three
-- seconds after the pull ended, because the user asked for it mid-pull and the
-- addon queued it, is a window nobody asked for at a moment nobody wanted it.
NS.OpenOptionsPanel = function() Helpers.OpenOptionsPanel() end

-- AceDB profile changes call this so any open page re-reads its values, and so do
-- `/mm set`, `/mm reset` and `/mm resetall` through the write seam.
NS.RefreshOptionsPanel = function() Helpers.RefreshAllPanels() end

-- ---------------------------------------------------------------------
-- The Windows page: the band, the nav rail, the selected entry (#55)
-- ---------------------------------------------------------------------
--
-- AuraMaster's Containers page (#6) is the pattern. The entry on screen and each
-- entry's tab are session state on the ctx and never persisted (options-ui-§13);
-- the band stays the only picker, and a window switch leaves both alone
-- (options-ui-§14).

-- The Windows page's ctx, bound by settings/Windows.lua's builder: the one page
-- SelectSection moves (NR-MM-03).
local windowsCtx

--- The entries the rail lists, in rail order. Every window has every entry, so
--- nothing is filtered by the window; an entry whose file did not load is absent.
local function railSections()
    local out = {}
    for _, key in ipairs(SECTION_ORDER) do
        if sections[key] then out[#out + 1] = sections[key] end
    end
    return out
end

--- The entry to draw: the one the page holds while the rail lists it, else General.
local function settleSection(ctx, list)
    for _, s in ipairs(list) do
        if s.key == ctx.activeSection then return s end
    end
    return list[1]
end

--- Keep the tab the page is on for the entry it last drew. Called before ANYTHING
--- moves the entry: the library's own strip click never calls back here
--- (RenderTabbedSchema re-renders the strip and the rows itself), so leaving is the
--- one moment the host sees the tab.
local function stashTab(ctx)
    local drawn = ctx.__renderedSection
    if drawn then ctx.sectionTabs[drawn] = ctx.activeTab end
    ctx.__renderedSection = nil
end

--- Bind the Windows page's ctx (settings/Windows.lua's builder). The page opens on General.
function Helpers.__bindWindowsPage(ctx)
    windowsCtx = ctx
    ctx.sectionTabs = {}
    ctx.activeSection = GENERAL_SECTION
end

--- Render the Windows page: the Active window band, the nav rail, then the entry's
--- strip and body -- the library's draw order, PageBanner, NavRail, TabStrip.
function Helpers.RenderWindowPage(ctx)
    -- FIRST, before anything clears. The Columns entry's drag handles stay parented
    -- to the scroll's pooled containers until the controller is canceled
    -- (settings/ColumnBlocks.lua), and the seven entries share this one ctx: a rail
    -- click, a window switch and Columns' own tab click all land here, and each
    -- clears the scroll next. A no-op when nothing is being dragged.
    if NS.CancelReorder then NS.CancelReorder(ctx) end
    ctx.sectionTabs = ctx.sectionTabs or {}
    stashTab(ctx)
    local list = railSections()
    local section = settleSection(ctx, list)
    if not section then return end
    ctx.activeSection = section.key
    ctx.activeTab = ctx.sectionTabs[section.key]
    -- Every window.* row resolves against the ACTIVE window; the id is also the
    -- library's row filter (the descriptor's rowsForPage), as on the sub-pages.
    ctx.unit = NS.State and NS.State.activeWindowId or nil
    Helpers.ClearScroll(ctx)
    Helpers.WindowBanner(ctx)
    local entries = {}
    for i, s in ipairs(list) do entries[i] = { key = s.key, label = s.label, tooltip = s.tooltip } end
    Helpers.NavRail(ctx, {
        entries  = entries,
        value    = section.key,
        onSelect = function(key)
            stashTab(ctx)
            ctx.activeSection = key
            Helpers.RefreshPanel(ctx, true)
        end,
    })
    if section.spec.render then
        section.spec.render(ctx)
    else
        Helpers.RenderTabbedSchema(ctx, section.key)
    end
    Helpers.Relayout(ctx)
    ctx.__renderedSection = section.key
end

--- The Windows page's Defaults: the entry on screen, read at CLICK time. The library
--- builds the button once, at the first show, and captures this handler with it, so
--- a closure that read the entry at build time would reset General's set from Frame.
function Helpers.RestoreActiveSection(ctx)
    local s = sections[ctx and ctx.activeSection] or sections[GENERAL_SECTION]
    if not s then return end
    if s.spec.defaults then return s.spec.defaults(ctx) end
    Helpers.RestoreDefaults(s.key, ctx)
end

--- Test seam: the ctx the Windows page bound, or nil before its builder ran.
function Helpers.__windowsCtx() return windowsCtx end

--- Select entry `key` on the Windows page, and optionally its tab: the one seam a
--- link, a deep link or a suite moves the entry through. A hidden page is marked
--- owed a render and draws the entry on its next show. Refused in combat, as a tab
--- switch is (options-ui-§2, §13).
--- @return boolean  whether the entry was selected
function Helpers.SelectSection(key, tabKey)
    if Helpers.__combatRefused() then return false end
    local ctx = windowsCtx
    if not (ctx and sections[key]) then return false end
    stashTab(ctx)
    ctx.activeSection = key
    if tabKey ~= nil then ctx.sectionTabs[key] = tabKey end
    Helpers.RefreshPanel(ctx, true)
    return true
end

-- The library's SelectTab moves one PAGE's tab. An entry key is no page of its own
-- (MultiMeters#55): it routes to SelectSection, so a link written against a page
-- key still lands. Any other key -- General, Profiles -- is the library's.
local selectTab = Helpers.SelectTab
function Helpers.SelectTab(pageKey, tabKey)
    if sections[pageKey] then return Helpers.SelectSection(pageKey, tabKey) end
    return selectTab(pageKey, tabKey)
end

--- Open the settings window at one page. An entry key opens the Windows page on
--- that entry; "windows" itself keeps the entry the player left. Under combat
--- lockdown the library's own open answers -- it refuses with its one line and
--- never defers (options-ui-§2) -- and nothing is selected.
function NS.OpenOptionsPage(pageKey)
    local target = sections[pageKey] and GENERAL_SECTION or pageKey
    local cat = categories[target]
    if lib.__IsCombatLocked() or not (cat and cat.GetID and Settings and Settings.OpenToCategory) then
        return Helpers.OpenOptionsPanel()
    end
    if pageKey ~= target then Helpers.SelectSection(pageKey) end
    Settings.OpenToCategory(cat:GetID())
end
