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
-- button belongs to the INSTALLATION. A profile switch must not move the player's buttons, and
-- `options-ui-§12`'s *Reset all settings* — a profile reset by definition — must not un-hide a
-- button they deliberately hid. core/Database.lua's v15 step carries the table across from
-- `db.profile.minimap`, `minimapPos` included.
--
-- ── THE INVERSION IS NOT HERE ────────────────────────────────────────────────────────────────
--
-- The Master-controls row says SHOWN and LibDBIcon's key says HIDDEN, so the row's get/set invert
-- — at settings/Schema_Paths.lua's single write seam (options-ui-§1), with every other row, which
-- is also where `Launcher:SetShown` is called so the button follows the checkbox immediately
-- rather than at the next reload. Nothing about that inversion lives in this file, and the
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

    -- What a broker display prints beside the icon. The addon's TITLE rather than its folder name,
    -- because this one is read by a human in a list of plugins.
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
    onClick = function()
        local wm = NS.WindowManager or (NS.GetModule and NS:GetModule("WindowManager", true))
        if wm and wm.Toggle then wm:Toggle() end
    end,

    onTooltipShow = onTooltipShow,

    -- Both resolved at CALL time rather than captured, so this file's correctness does not depend
    -- on a TOC line staying where it is (anti-patterns #36).
    print = function(line) if NS.Print then NS.Print(line) end end,
    debug = function(tag, message) if NS.Debug then NS.Debug(tag, "%s", message) end end,
})
