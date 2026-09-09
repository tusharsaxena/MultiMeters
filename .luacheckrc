std = "lua51"
max_line_length = false
codes = true
-- libs/ is vendored third-party code, upstreamed from the LibKa0s repo and linted there, not here.
-- tests/_kit/ is the same fact one level down: it is a byte copy of the library's testkit/, linted
-- in LibKa0s as source, and linting the copy too would report every finding twice while letting the
-- copy drift green as the original went red -- the one state the vendor-sync gate exists to make
-- impossible. Everything else under tests/ is ours and is linted (lint.md). The docs/audits and
-- docs/reviews bundles are frozen snapshots and must never be "fixed" by a lint pass.
exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "_dev/" }

-- NO TOP-LEVEL `ignore`, and none is coming back (lint.md, `M4-11`). This file carried
-- `ignore = { "212/self", "212/event", "211/addonName" }` until `M4c-06`. Every entry named
-- something that exists in this tree, but a top-level ignore reaches all 122 files, so it silenced
-- those codes in every file that has no business producing them too -- and one of the three was
-- silencing thirty-two live defects rather than a convention.
--
-- Removing the three lines reported EIGHTY-FOUR findings: fifty-two `212/self`, thirty-two
-- `211/addonName`, and -- worth stating -- zero `212/event`, an entry that had been earning its
-- place in the config by naming a warning this repository does not produce. The thirty-two
-- `211/addonName` were fixed at source, not moved into a narrower suppression: thirty-two files
-- opened `local addonName, NS = ...` over a folder name they never read and now open
-- `local _, NS = ...`, which is what core/PoolSetup.lua already spelled and what ConsumableMaster
-- does. Exactly TEN files do read it -- CoreSetup, DebugLogSetup, EnvSetup, MediaSetup,
-- MultiMeters, Namespace, PerfSetup, modules/Export_Modal, modules/Minimap and
-- settings/Schema_Compose -- each handing it to a vendored library or a registry that cannot
-- infer which folder it was copied into, and those keep the name. Two of those ten answer to a
-- different name than they did at `M4c-06`, and the count still reading TEN is a coincidence
-- rather than a sign that nothing moved: the layout-§1 peels (issue #28) split
-- modules/Export.lua and settings/Schema.lua, and in both cases the vararg went with the half
-- that was carved out. modules/Export.lua, settings/Schema.lua and the second Schema sibling,
-- settings/Schema_Paths.lua, all three now open `local _, NS = ...`; modules/Export_Modal.lua
-- and settings/Schema_Compose.lua are the readers. A list left as it stood would have named two
-- files that no longer read the name and missed the two that do. A thirty-third file,
-- settings/ColumnBlocks.lua, was hiding the same defect behind an inline
-- `-- luacheck: ignore 211/addonName` rather than behind the blanket; it is fixed the same way.
-- core/CoreSetup.lua carried a `-- luacheck: ignore addonName` over a header that DOES read the
-- name, so the directive was silencing nothing and is gone.
--
-- The fifty-two that remain are below, as per-file `files[...]` stanzas in luacheck's
-- `<code>/<variable>` form. tests/test_lintconfig.lua is what keeps the blanket from re-entering.
read_globals = {
  -- core Lua/WoW globals
  "_G", "LibStub", "CreateFrame", "GetTime", "GetTimePreciseSec",
  "UIParent", "GameTooltip", "GameTooltip_SetDefaultAnchor",
  -- Where the pointer is, in SCALED coordinates, for a caller that divides by
  -- UIParent:GetEffectiveScale(). That caller is no longer in this tree. The column-reorder
  -- drag settings/ColumnBlocks.lua used to run per OnUpdate is now the library's drag
  -- controller (ColumnBlocks.lua:236), and the per-frame cursor read went with it into
  -- libs/LibKa0s/Widgets.lua -- which exclude_files keeps out of this lint. No linted file
  -- names either global today, so both entries are declarations nothing needs; dropping them
  -- is a change to what luacheck enforces and not a correction to a comment, so they stay
  -- until that is decided on its own terms.
  "GetCursorPosition", "IsMouseButtonDown",
  "GameFontNormal", "GameFontHighlight", "GameFontDisable", "STANDARD_TEXT_FONT",
  "hooksecurefunc", "securecallfunction", "PlaySound",
  -- Perf bracket timer (performance-§2). The bracket CALL SITES are addon code and are
  -- linted, even though the lib under libs/ is not.
  "debugprofilestop",
  -- Secret values (WoW 12.0). core/Secrets.lua is the ONLY file permitted to call these;
  -- they are declared here so that one file lints, not so that others may use them.
  "issecretvalue", "canaccessvalue", "issecrettable", "canaccesstable",
  "C_RestrictedActions",
  -- the meter itself — modules/Provider.lua is the only caller
  "C_DamageMeter",
  -- native formatting / curve evaluation: the only legal arithmetic on a secret value
  "C_StringUtil", "C_CurveUtil",
  "C_Timer", "C_Spell", "C_SpecializationInfo", "C_AddOns", "C_ChallengeMode",
  "Enum", "GetLocale", "GetSpellInfo",
  -- combat state. InCombatLockdown() gates secure writes; UnitAffectingCombat() drives
  -- combat-reactive display logic (they are not interchangeable).
  "InCombatLockdown", "UnitAffectingCombat",
  -- units / roster
  "UnitExists", "UnitGUID", "UnitName", "UnitClass", "UnitIsUnit", "UnitIsPlayer",
  "UnitGroupRolesAssigned", "UnitInVehicle", "UnitIsDead", "UnitIsDeadOrGhost",
  -- player state, for the visibility rules (modules/Visibility.lua). The
  -- namespaced probes those rules also need — C_PlayerInfo, C_Housing,
  -- C_DelvesUI, C_PartyInfo — reach the client through core/Compat.lua and are
  -- read off _G there, so they need no entry here.
  "UnitOnTaxi", "IsMounted", "GetShapeshiftFormID",
  "IsInGroup", "IsInRaid", "IsInInstance", "GetNumGroupMembers", "GetRaidRosterInfo",
  "GetInstanceInfo", "IsLoggedIn",
  -- settings panel / frame plumbing
  "Settings", "SettingsPanel", "UISpecialFrames", "HideUIPanel", "ShowUIPanel",
  "DEFAULT_CHAT_FRAME", "UIDropDownMenu_AddButton",
  -- death recap hand-off (modules/DrillDown.lua)
  "OpenDeathRecapUI", "DeathRecapFrame",
  -- color / util
  "CreateColor", "CreateColorFromHexString", "WrapTextInColorCode", "RAID_CLASS_COLORS",
  "CopyTable", "wipe", "tContains", "tinsert", "tremove", "strsplit", "strtrim", "strjoin",
  "date", "time",
  "BackdropTemplateMixin", "Mixin", "CreateFromMixins",
  "NORMAL_FONT_COLOR", "HIGHLIGHT_FONT_COLOR", "RED_FONT_COLOR", "GREEN_FONT_COLOR", "GRAY_FONT_COLOR",
  -- static popups
  "StaticPopup_Show",
}
globals = {
  "MultiMetersDB",     -- SavedVariables write target (the AceDB tree)
  "MultiMetersPerfDB", -- LibKa0s-Perf capture ring; a SECOND top-level SV global, deliberately
                       -- outside the AceDB tree so "copy profile" does not clone it and
                       -- "reset profile" does not wipe it
  "StaticPopupDialogs", -- addon registers named popups by adding fields to this table
}

-- The test tree is linted, and these are the three globals it WRITES. Every suite READS the
-- harness table as `_G.MULTIMETERS_TEST`, and a field read off the already-declared `_G` needs no
-- entry at all; what needs one is tests/run.lua:315 writing it, plus the two SavedVariables tables
-- a case clears to assert on the absent-saved-variable path. Hence `globals` and not
-- `read_globals`. Hence also the `_G.` qualification -- spelled bare, all six writes are still
-- reported as W122 "setting read-only field of global '_G'", which is checked both ways.
--
-- Declared HERE rather than at the top level on purpose, and the difference is not cosmetic. A name
-- granted at the top level is granted to core/, modules/ and settings/ as much as to a suite, and
-- no shipped file may ever reach for the test harness. With this stanza in place the same write
-- planted in core/State.lua still reports, which is the scoping the stanza is here to buy.
files["tests/"] = {
  globals = {
    "_G.MULTIMETERS_TEST",
    "_G.MultiMetersDB", "_G.MultiMetersPerfDB",
  },
}

-- ---------------------------------------------------------------------------
-- The narrowed 212s (lint.md, `M4c-06`)
-- ---------------------------------------------------------------------------
--
-- Every stanza below names ONE file, and every entry inside it names the code AND the variable, in
-- luacheck's `<code>/<variable>` form. That is the whole difference from the blanket this replaced:
-- a newly-unused argument under any OTHER name -- `window`, `key`, `event`, `statKey` -- still
-- reports in these files, and `212/self` still reports in the other hundred and seven.
--
-- Measured, not assumed, and the measurement has to be chosen carefully because the old top-level
-- list was already spelled `212/self` rather than a bare `212`. A dead trailing parameter named
-- anything else therefore reported under BOTH configs, and quoting that as proof would have been
-- proof of nothing. What the blanket actually hid is the two shapes it named: planting an unread
-- `local addonName, NS = ...` header AND an unused `self` in core/State.lua -- a file with no
-- stanza -- reports both under this config (`:24:7 (W211)`, `:155:15 (W212)`) and reports zero
-- warnings under the blanket. That is the thirty-two live defects, restated as one experiment.
--
-- Every one is a receiver a CALLING CONVENTION forces on a body that has no use for it, which is
-- the only shape that earns a stanza here. Each was checked the same way -- the method is reached
-- through a colon call, or by a library that invokes it by name as `self[name](self, ...)`.
-- Anything else -- a parameter this addon chose to accept and then never read -- is dead code, and
-- would be deleted rather than listed.

-- `NS:InitDB` and `NS:RunMigrations` are reached as `NS:InitDB()` from core/MultiMeters.lua's
-- OnInitialize and from the database suite; both read the AceDB handle through this file's own
-- upvalue rather than off the namespace. `Database:OnProfileChanged` is AceDB-3.0's callback
-- convention -- the library passes the handle and the profile key as arguments precisely so the
-- callee does not have to reach for them through a receiver.
files["core/Database.lua"] = { ignore = { "212/self" } }

-- AceEvent-3.0 invokes a handler registered by name as `self[name](self, event, ...)`, so `self`
-- arrives whether the body reads it or not. `OnSystemMessage` (registered at :194) hands the line
-- straight to modules/Export.lua; `OnSpellSucceeded` (:187) reads only the spell id. Both read the
-- namespace through this file's own upvalue.
files["core/MultiMeters.lua"] = { ignore = { "212/self" } }

-- Four more AceEvent message handlers registered by name, each named after the invalidation it
-- answers: `Aggregator:OnMeterReset` (registered at :1323), `Feign:OnForget` (:373) and
-- `Feign:OnRosterChanged` (:375), `Provider:OnMeterInvalidated` (:887),
-- `Roster:OnRosterChanged` (:583). None has a colon call site anywhere in the addon, because the
-- library is the only caller -- which is exactly why the receiver cannot be dropped from the
-- signature.
files["modules/Aggregator.lua"] = { ignore = { "212/self" } }
files["modules/Feign.lua"]      = { ignore = { "212/self" } }
files["modules/Provider.lua"]   = { ignore = { "212/self" } }
files["modules/Roster.lua"]     = { ignore = { "212/self" } }

-- Module surfaces published on `NS` and reached by colon call from the window pipeline and from the
-- suites -- `DrillDown:Enter/Exit/ExitAll/BuildRows/AcquireBackButton/ReleaseBackButton`,
-- `HeaderControls:Attach/Apply/HookHover`, `Tooltip:CellTooltip/NameTooltip/SpellTooltip/Hide`,
-- `Visibility:Allows/Evaluate`. Each takes the window (or the row) it operates on as an explicit
-- argument and holds its own state in file-local tables, so the receiver is the call syntax and
-- nothing more. They stay method-sugar because that is the surface docs/module-map.md publishes and
-- the shape every call site already spells.
files["modules/DrillDown.lua"]      = { ignore = { "212/self" } }
files["modules/HeaderControls.lua"] = { ignore = { "212/self" } }
files["modules/Tooltip.lua"]        = { ignore = { "212/self" } }
-- `Tooltip:CellTooltip/NameTooltip/SpellTooltip` moved to the sibling when
-- modules/Tooltip.lua was peeled for layout-§1 (issue #28); `Tooltip:Hide` stayed.
-- Same three methods, same colon call sites, same reason -- just a second file now.
files["modules/Tooltip_Builders.lua"] = { ignore = { "212/self" } }
files["modules/Visibility.lua"]     = { ignore = { "212/self" } }

-- `WindowProto:IsTest` is a window PROTOTYPE method: it is reached as `window:IsTest()` through the
-- metatable every window carries, so the receiver is what finds the method even when the body
-- answers from module state.
files["modules/Window.lua"] = { ignore = { "212/self" } }

-- The seventeen-method manager surface -- Init, Create, Delete, Rename, Duplicate, CopyFrom,
-- RefreshAll, MarkAllDirty, ResetPosition(s), SetLocked, IsLocked, SetTestMode, IsTest, Toggle,
-- BuildListLines, Suspend. Every one is called as `NS.WindowManager:Method(...)` from the settings
-- panel, the slash verbs and the suites, and every one reads the window registry through this
-- file's own upvalue rather than off the receiver. Seventeen is a lot of stanzalessness to justify
-- in one line, so the honest statement is the one the count makes: this file's whole public surface
-- is method-sugar over module state, deliberately and consistently.
files["modules/WindowManager.lua"] = { ignore = { "212/self" } }

-- The published slash surface -- `Sl:OnSlash`, `PrintHelp`, `HelpRows`, `LandingRows`, `Register` --
-- all five forwarding to the LibKa0s-Slash-1.0 instance in this file's `cli` upvalue, and all five
-- listed as `NS.Slash`'s surface in docs/module-map.md. `SlashLib:New` (:126) is the
-- library-absent stub's constructor, which has to accept the receiver because the real library's
-- `New` is a colon call at the one site that builds `cli`.
files["settings/Slash.lua"] = { ignore = { "212/self" } }

-- The MenuUtil root stub. `root:CreateTitle/CreateDivider/CreateButton` mirror the client's own
-- menu-root API, which production code calls as `rootDescription:CreateButton(...)` -- a mock that
-- quietly narrowed the signature would let a caller pass here and fail in the client.
files["tests/wow_mock.lua"] = { ignore = { "212/self" } }
