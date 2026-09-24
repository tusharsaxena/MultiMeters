local addonName, NS = ...

-- core/LauncherSetup.lua — wires the addon into LibKa0s-Launcher-1.0 (launcher-§1).
--
-- ── WHAT THIS REPLACED ───────────────────────────────────────────────────────────────────────
--
-- `modules/Minimap.lua`, which built the LibDataBroker object, registered it with LibDBIcon,
-- carried its own click handler and its own `Refresh` seam — about 200 lines of wiring that is
-- identical in every Ka0s addon, written once per addon in its own spelling. That is exactly the
-- shape `launcher-§1` names as anti-pattern #81, and the library exists to make it impossible.
-- What is left here is what is genuinely this addon's: its folder name, its logo, what its LEFT
-- button does, how its settings panel opens, and what its tooltip says.
--
-- ── ONE OBJECT, REGISTERED TWICE ─────────────────────────────────────────────────────────────
--
-- The library creates a single LibDataBroker-1.1 object of `type = "launcher"` and hands THAT
-- object to LibDBIcon-1.0. The minimap button and any broker display (Titan Panel, ElvUI data
-- texts, Bazooka) are two renderings of one object, so there is one `OnClick`, one icon and one
-- label, and `launcher-§2`'s rung rule is satisfied on both surfaces by construction rather than
-- by two implementations agreeing.
--
-- ── THE RUNG IS (a): ITS WINDOWS ─────────────────────────────────────────────────────────────
--
-- `launcher-§2`'s three rungs are ordered by what the player most likely wants, first match wins,
-- and this addon matches the first: it HAS a primary window — the meter window, which is the
-- thing it exists to show — so LEFT-click toggles it. `ADDONS.md` records the rung as **(a) its
-- windows**, and that roster row is normative: an audit reads it rather than re-deriving it.
--
-- RIGHT-click always opens the settings panel, on every addon, whatever rung its left click sits
-- on, which is what lets rung (a) spend the left button on something better. The panel is
-- therefore never more than one click away, and neither button is reassignable — the rung is a
-- property of the addon, not a preference, so there is deliberately no setting for it.
--
-- BOTH ACTIONS GO THROUGH THE SAME SEAMS THE SLASH VERBS USE and neither is reimplemented here.
-- `NS.OpenOptionsPanel` in particular carries the combat refusal — the options canvas is a
-- protected frame and opening it mid-pull is refused with a chat notice, not deferred — and a
-- private path from this button would be the one way to reach the panel without that guard.
--
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
-- NS.db, NS.WindowManager, NS.OpenOptionsPanel — is resolved at CALL time, because all three load
-- later. `Register()` itself is called from core/MultiMeters.lua's OnInitialize, after InitDB.

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

--- LibDataBroker hands the tooltip object itself, already anchored and cleared, so this adds lines
--- and nothing more — no Show(), no ClearLines(), and no GameTooltip lookup. Calling Show() here
--- is the classic way to get a tooltip that will not go away when the cursor leaves the button.
---
--- Guarded on `AddLine` rather than trusted: a broker display may hand a minimal object, and a
--- hover must not break because one of them carries fewer members than GameTooltip.
local function onTooltipShow(tt)
    if not (tt and tt.AddLine) then return end
    tt:AddLine(L["Ka0s Multi Meters"])
    if tt.AddDoubleLine then
        tt:AddDoubleLine(L["Version"], tostring(NS.version), 1, 1, 1, 0.6, 0.6, 0.6)
    end
    tt:AddLine(" ")
    tt:AddLine(L["Left-click to show or hide the meter windows."], 0.6, 0.6, 0.6)
    tt:AddLine(L["Right-click to open the settings."], 0.6, 0.6, 0.6)
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

    -- RIGHT-click always, and LEFT-click never reaches it on this rung. Resolved at call time: the
    -- seam is published by settings/OptionsSetup.lua, which loads after core/.
    openSettings = function()
        if NS.OpenOptionsPanel then NS.OpenOptionsPanel() end
    end,

    -- THE RUNG. Its presence is what says this addon is on (a); an addon on (a) or (b) whose
    -- left-click opened the settings panel would have skipped the rule rather than chosen a
    -- different design, since the panel is already on the other button.
    --
    -- `NS.WindowManager:Toggle()` is the SAME seam `/mm toggle` drives, resolved at call time
    -- because modules/ loads after core/. `GetModule` is the Ace fallback for a build where the
    -- namespace publication has not run; a build with neither does nothing rather than raising.
    --
    -- NO GATE IN HERE. The refusal is the library's (Launcher minor 2): `isEnabled` below answers
    -- false and the left click prints `disabledLine()` and never reaches this function. So this
    -- body is the toggle and nothing else.
    onClick = function()
        local wm = NS.WindowManager or (NS.GetModule and NS:GetModule("WindowManager", true))
        if wm and wm.Toggle then wm:Toggle() end
    end,

    -- THE LEFT-CLICK GATE (launcher-\194\1672, slash-commands-\194\1677). This is a rung-(a) left
    -- click, so what it drives is a primary window, and a window is a feature: refused, it prints
    -- the ONE refusal line and DOES NOTHING ELSE. In particular it writes no SavedVariables, which
    -- is what a minimap button with no disabled gate does for an addon the player switched off
    -- (anti-pattern #85).
    --
    -- IT ASKS `NS.IsStoodDown`, NOT the disabled flag alone, so it includes the perf latch: a click during
    -- a capture's suspended arm is refused too, where a disabled-only gate let it through to a
    -- Toggle that refuses with an err nobody printed (MultiMeters-R-04). Resolved at CALL time,
    -- because the seam is published after this file loads.
    --
    -- RUNG (c)'S CARVE-OUT DOES NOT APPLY HERE and is named so a reader does not wonder: a rung-(c)
    -- left click opens the settings panel, which survives the disabled state, so refusing it would
    -- decline one button for doing precisely what the right button beside it is required to keep
    -- doing. This addon is on rung (a), where there is no such contradiction; the library never
    -- gates rung (c) either way.
    --
    -- RIGHT-CLICK IS UNCHANGED, in either state: the ruling narrows the SLASH surface and a mouse
    -- click is not a slash command. The library never gates `openSettings`.
    isEnabled = function() return not (NS.IsStoodDown and NS.IsStoodDown()) end,

    -- THE LINE, per hold. Disabled: the dispatcher's, through NS.Slash:DisabledLine, never written
    -- again here -- one shape, collection-wide, and a second copy in this file is how it drifts.
    -- Resolved at CALL time because settings/ loads after core/. A nil answer prints nothing,
    -- which only a build with no Slash seam at all can reach. Perf-suspended: the same line
    -- `/mm toggle` prints, since `/mm enable` is the wrong advice mid-capture.
    disabledLine = function()
        if NS.IsDisabled and NS.IsDisabled() then
            local Sl = NS.Slash
            return Sl and Sl.DisabledLine and Sl:DisabledLine() or nil
        end
        return L["Windows are suspended while a performance capture runs."]
    end,

    onTooltipShow = onTooltipShow,

    -- Both resolved at CALL time rather than captured, so this file's correctness does not depend
    -- on a TOC line staying where it is (anti-patterns #36).
    print = function(line) if NS.Print then NS.Print(line) end end,
    debug = function(tag, message) if NS.Debug then NS.Debug(tag, "%s", message) end end,
})
