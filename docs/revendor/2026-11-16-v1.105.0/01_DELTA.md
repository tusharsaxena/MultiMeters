Delta: LibKa0s v1.93.0 -> v1.105.0

Recorded for item RV-MM of Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/` (phase [2],
the copy and bundle half of `/dev-copilot:wow-revendor-libka0s` 2.10.0). The payload comes from the local
annotated tag, never the sibling tree: `git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools`
(tag commit `79b1d9c`, not yet pushed to origin, which is expected for this run).

## Step 0 pre-flight (this addon)

The newest single-tag bundle is `2026-11-07-v1.93.0`. Its line 1 says base v1.92.0. The provenance
line before its re-vendor commit `87a0620` was v1.92.0. Result: ok, so there is no base correction.

## 3a Base

- `grep -n '[Bb]undles' CLAUDE.md` named v1.93.0 (CLAUDE.md:62) before the roll.
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` returned `3236484` ("WFP-RV2-MM: Re-copy LibKa0s
  v1.93.0 after the final-review fixes"), and its CLAUDE.md names v1.93.0. The two agree.
- Before the copy the payload matched the library at v1.93.0. `diff -rq` of a v1.93.0 extract against
  `libs/LibKa0s` printed only `Only in <extract>/LibKa0s/media/icons` lines, which are the undeclared
  icons. `diff -rq` against `tests/_kit` printed nothing.
- Range: `git -C ../LibKa0s log --oneline v1.93.0..v1.105.0` is 117 commits, which carry the tags
  v1.94.0 to v1.105.0. `git -C ../LibKa0s diff --stat v1.93.0 v1.105.0 -- LibKa0s testkit` is 419 files,
  +10325 / -721 (most of it the new `media/waypoint/`, the two fonts and the callout sounds).

## 3b/3c Per-file minors that moved (old = this addon before the copy, new = v1.105.0)

Run with the spec's loop over the tag's `LibKa0s.xml`. Files not listed did not move.

| File | Old | New |
|---|---|---|
| Core.lua | Core 17 | 18 |
| Tooltip.lua | (new) | Tooltip 1 |
| Compat.lua | Compat 3 | 4 |
| Role.lua | (new) | Role 1 |
| Callout.lua | (new) | Callout 4 |
| CalloutSettings.lua | (new) | SETTINGS_MINOR 5 |
| WaypointArrow.lua | (new) | WaypointArrow 2 |
| WaypointArrowSettings.lua | (new) | SETTINGS_MINOR 2 |
| Charts.lua | Charts 1 | 2 |
| Media.lua | Media 12 | 13 |
| Skin.lua | Skin 17 | 18 |
| SkinDefs.lua | DEFS_MINOR 27 | 28 |
| SkinDefsOthers.lua | OTHERS_MINOR 8 | 10 |
| Widgets.lua | Widgets 26 | 27 |
| WidgetsDropdown.lua | DROPDOWN_MINOR 1 | 2 |
| WidgetsReorder.lua | REORDER_MINOR 6 | 7 |
| WidgetsDragHandle.lua | DRAG_MINOR 13 | 14 |
| WidgetsDragHandleTip.lua | (new) | DRAGTIP_MINOR 1 |
| WidgetsCopyWindow.lua | COPY_MINOR 5 | 6 |
| WidgetsHeader.lua | (new) | HEADER_MINOR 1 |
| WidgetsBar.lua | (new) | BAR_MINOR 1 |
| DebugLog.lua | DebugLog 22 | 23 |
| DebugLogDiagnostics.lua | DIAG_MINOR 7 | 11 |
| DebugLogWindow.lua | WINDOW_MINOR 4 | 5 |
| Launcher.lua | Launcher 9 | 11 |
| OptionsWidgets.lua | WIDGETS_MINOR 45 | 46 |
| OptionsNav.lua | NAV_MINOR 6 | 7 |
| OptionsSkinPicker.lua | PICKER_MINOR 11 | 12 |
| OptionsSkinPickerQueue.lua | (new) | QUEUE_MINOR 1 |
| IconBrowserWindow.lua | WINDOW_MINOR 1 | 2 |
| IconBrowser.lua | BROWSER_MINOR 1 | 2 |
| PerfPanel.lua | PANEL_MINOR 13 | 14 |
| Sim.lua | Sim 2 | 3 |
| SimPanel.lua | SIM_PANEL_MINOR 10 | 11 |
| SimPanelRender.lua | RENDER_MINOR 3 | 4 |

Every file matched v1.93.0 before the copy, so there is no cross-major skew.

## 3d Diffs

After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against
the v1.105.0 extract were both empty. After the prune the only differences are
`Only in <extract>/LibKa0s/media/icons` (1636 undeclared icons) and
`Only in <extract>/LibKa0s/media/sounds` (the callout set, since there is no `LibKa0s sounds:` line and
none means none). `tests/_kit` is byte-identical to `testkit`. No file was removed upstream, so nothing
was deleted by hand.

## 3e Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/`
gives the same sites as at v1.93.0:

- Bus: `core/Constants.lua:591`, `core/Namespace.lua:211`
- Compat: `core/Compat.lua:73`, `core/Secrets.lua:160`
- Core: `core/CoreSetup.lua:122`
- DebugLog: `core/DebugLogSetup.lua:254`
- Env: `core/EnvSetup.lua:74`
- Launcher: `core/LauncherSetup.lua:91`
- Lifecycle: `core/LifecycleSetup.lua:37`
- Media: `core/MediaSetup.lua:74`
- Options: `settings/OptionsSetup.lua:134`, `settings/Schema_Compose.lua:325`
- Perf: `core/PerfSetup.lua:42`
- Pool: `core/PoolSetup.lua:35`
- Schema: `settings/Schema_Paths.lua:85`
- Sim: `core/SimSetup.lua:41`, `modules/Sim.lua:325`, `core/Diagnostics_Runtime.lua:422`
- Skin: `core/SkinSetup.lua:112`, `core/Database_Migrations.lua:859`, `:987`
- Slash: `settings/Slash.lua:209`
- Widgets: `modules/Export_Modal.lua:39`, `modules/Window.lua:73`, `modules/Window_Frame.lua:32`,
  `modules/Window_Header.lua:78`, `settings/ColumnBlocks.lua:94`

Majors in the payload with no lookup here: Tooltip, Role, Item, Glow, Toast, Callout, WaypointArrow,
Charts, IconBrowser. These are unadopted and feed 02.

## 3f Kit revision

`grep -n 'Kit.VERSION' testkit/framework.lua tests/_kit/framework.lua` gave 57 (tag) and 53 (before). Both
payloads move together in one commit, which satisfies the pairing rule by construction (v1.9.0+ needs kit
revision 11 or later in the same commit).

## 3g Contract delta

The moved majors this addon consumes are Core, Compat, Media, Skin, Widgets, DebugLog, Launcher, Options
(OptionsWidgets, OptionsNav, OptionsSkinPicker) and Sim.

- `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds one host
  attach site, `settings/Schema_Compose.lua:344` (`optlib.__AttachCompose`). `OptionsCompose.lua` did not
  move a minor in this range, so its contract is unchanged.
- Widgets 27 / DragHandle 14: `tooltipOwner`, `tooltipAnchor` and a descriptor's `owner`/`anchor` are
  retired. `grep -rn 'tooltipOwner\|tooltipAnchor\|tooltipPlace' core modules settings` finds nothing, so
  nothing of this addon's is retired.
- DebugLog 23: `Add` now stores the plain text in `buffer`, and the view keeps the color. No MultiMeters
  suite pins a color code in a buffered line. The console's counter is now a `W.Footer`
  (`grep -rn 'log.count\|statusDivider\|lineCount' tests` finds nothing).

**Blockers: none.** The red suites below were the documented "what a consumer owes" items, not contract
changes under an unmoved surface.

### What went red at the copy, and the fix in the same commit

The first gate run after the copy was 2585 passed, 4 failed, 1 skipped (2590). Each failure:

1. `DebugLogSetup degraded: the stub carries the WHOLE live surface` (`tests/test_debuglogsetup.lua:210`):
   `Report`, `Serialize` and `__view` were missing. DebugLog minor 23 owes the first two (CHANGELOG
   v1.105.0, *What a consumer owes*, and `docs/api/DebugLog/version-23.11.1.5-docs.md` lines 50-65). They
   are added to the stub in `core/DebugLogSetup.lua` as the API document prescribes: the report streams to
   chat with no pointer, and a serialize answers one line. `__view` is the shell's private
   colored-message array, and the same document (line 36) says "`__view` is private (`__`), so it is no
   member of the surface and no stub carries it." This case uses the kit's two-table form, which compares
   every key and does not filter `__` the way the by-name form does, so `__view` joins the case's existing
   ignore list of library-internal fields with that reason. (R9 C4 counted MultiMeters as having no
   by-name DebugLog parity case. It has the two-table case instead, which this re-vendor also had to fix.)
2. `Settings pin: the schema holds exactly the pinned rows, keys and defaults unchanged`
   (`tests/test_settings_pin.lua`): Media minor 13 (v1.97.0) adds Ka0s Bebas Neue and Ka0s Russo One to
   the font list. The pin moves on all **five** font rows (`window.font`, `window.header.font`,
   `window.columnHeader.font`, `window.text.font`, `window.tooltip.font`). R8 named only one. Defaults
   are unchanged (`Ka0s Prototype`).
3. `parity: the Options stub carries every public member of the live Helpers surface`: `SideTabs`
   (OptionsNav minor 7, v1.100.0). It joins the stub's inert no-op list in `settings/OptionsSetup.lua`,
   because no page here calls it.
4. `parity: NS.Compat and NS.Secrets carry every LibKa0s-Compat-1.0 member between them`: `CharacterKey`,
   `RealmKey`, `RegionalNames` and `UnitCharacterName` (Compat minor 4, v1.94.0). They are wired on
   `NS.Compat` in `core/Compat.lua`, with the library's member or the absent table's answer
   (`docs/api/Compat/version-4-docs.md`, "The absent table": `false`, `nil, nil`, `nil`, `nil`), the same
   reader-arm pattern as the spell readers. In `tests/test_surface_parity.lua` the four join
   `COMPAT_READERS`, the list of readers that live on NS.Compat rather than on NS.Secrets.

Wiring four new `NS.Compat` members also reached the simulator seam, which wraps every Compat function.
That turned two more cases red, and both are fixed in the same commit:

- `SimWorld: every wrapped key that is not guarded has a provider`, then `Sim seam: Keys() is every
  non-PURE Compat function`. `RegionalNames`, `CharacterKey` and `RealmKey` answer for the real character
  (a SavedVariables key is never a simulated one), so they join `PURE` in `core/SimSetup.lua` and the
  test's mirror list in `tests/test_sim_seam.lua`. `UnitCharacterName(unit)` is a unit read, so
  `modules/SimWorld.lua` answers it from the world (the unit's name, no realm), next to `UnitName`.
- `docs/compat-layer.md` gains the Identity row and the pure count (seventeen to twenty).

Nothing calls the four identity readers yet, so no behaviour changes.

## 3h Unrecorded tags

The spec's walk (vendored tags since the store's horizon, minus the tags recorded in a bundle) printed
nothing. Every tag this addon vendored has a bundle, so no span bundle is owed.

## 3i Icon declaration

The existing CLAUDE.md:63 line is kept unchanged: `chat, ph:chat-text, chevron-down, chevron-up, clear,
close, confirm, copy, expand, export, eye, info, lock, minimise, move, reset, segment, settings, sort-down,
sort-up, spreadsheet, unlock, volume-high`. It is the next non-blank line after the provenance line. The
tag's library-drawn set (`docs/releasing.md` at v1.105.0: `chevron-down, chevron-up, close, confirm, info,
move, reset, settings, volume-high`, plus `copy, clear` for the console) is all declared. `settings` is
new to kit revision 57's `LIBRARY_MARKS` and was already declared. `lua <extract>/tools/prune-icons.lua .`
kept 25 files (the 23 icons plus the license files) and removed every other icon and the whole callout
sound set ("sounds none (no `LibKa0s sounds:` line)"). Hand lists have drifted before (KickCD, WhatGroup),
and the owner's in-client smoke is the backstop.

## 3j Whole-folder icon tests

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v /_kit/` gives
`tests/test_mediasetup.lua:90-126` and `tests/test_options_panel.lua:889`. Both already assert declared
names only, from earlier re-vendors, and both are green.
