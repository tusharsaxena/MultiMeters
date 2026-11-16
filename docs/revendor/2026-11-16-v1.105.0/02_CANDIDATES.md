# 02 Candidates

Sources: the CHANGELOG blocks v1.94.0 to v1.105.0 at the tag, and the `docs/api/` documents of the
majors whose minors moved (01_DELTA.md 3c). This run is the copy and bundle half only. Every candidate
below is **owed in phase [3]** of Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/`
(`03_ADOPTION_PLAN.md`). There was no interview and no issue filing here.

## A. Reached the addon on the copy alone (delivered, not offered)

- **The library's own tooltips are placed by `LibKa0s-Tooltip-1.0`** (LK-92B, Widgets 27,
  WidgetsDropdown 2, WidgetsReorder 7). MultiMeters' skinned segment menu (`W.ContextMenu`,
  `modules/Window_Header.lua:1236`), the Export modal's `W.Dropdown` (`modules/Export_Modal.lua:679`) and
  the column `W.ReorderList` (`settings/ColumnBlocks.lua:261`) now open their tips beside the menu or
  window and never at the cursor.
- **A settings mark in each library window's header** (LK-86: the debug console, the copy window, the
  perf panel and the sim panel). It opens the settings through the launcher's `openSettings`, keyed by
  `name = addonName` (`core/LauncherSetup.lua:335`), and the windows' `addonName` is the same folder name
  (`core/DebugLogSetup.lua:393`, `core/PerfSetup.lua:83`), so R9 C8 holds. The skin picker's gear moves
  into its header.
- **Plain-text Copy and a footer counter on the debug console** (LK-79, LK-90).
- **The slider box reverts junk text on Enter and on focus loss** (OptionsWidgets 46, v1.101.0) on every
  number row.
- **Ka0s Default rows and hot marks read more clearly** (LK-82 + LK-84: stripe .08, hover .16, sel .26,
  new `icon.hot` values in six skins).
- **Two more fonts** in every font picker (Media 13: Ka0s Bebas Neue, Ka0s Russo One).
- **The diagnostics header names Role, Callout, WaypointArrow and Tooltip** (DebugLogDiagnostics 8 to 11).

## B. Host change required (candidates, owed in phase [3])

| Issue | Surface | Sites here (approximate, from R8 section 3; re-check at adoption) |
|---|---|---|
| LibKa0s#92 | Tooltip placers `PlaceBeside` / `PlaceAttached` | `modules/Tooltip.lua:610` (player-chosen anchor from `ANCHOR_VALUES`, so the owner rules on whether that choice survives), `settings/ColumnBlocks.lua:177` |
| LibKa0s#88 | Docked test/sim strip (`dock = "title"`) | `modules/Window_Frame.lua:215,388`, placed by `PlaceTestStrip` (`modules/Window_Header.lua:865`), undocked today |
| LibKa0s#89 | `W.Footer` | the meter window's own header/status line (`modules/Window_Header.lua`); check whether it has a footer to replace |
| LibKa0s#86 | `W.HeaderButtons` on the addon's own windows | `modules/HeaderControls.lua:124` (the meter header's marks), `modules/Export_Modal.lua:212-218` |
| LibKa0s#79 | `D:Report` / `D:Serialize` for report verbs | `export`, `profile`, `window` candidates (confirm each verb against its handler) |
| LibKa0s#87 | `Sim.Sample(client)` | the simulator's sample names. The seeded crowd list stays (03_ADOPTION_PLAN.md) |
| — | `DefaultSkin()` in the profile defaults (skinning-§2 MUST since v1.94.0) | `grep -rn DefaultSkin core modules settings` finds nothing today. This is a compliance gap, first in the phase [3] order |

LibKa0s#85 (Callout), #80 (`W.Bar`) and #81 (`extraEntries`) do not apply to MultiMeters.

## C. Whole-module adoption

Tooltip (under #92 above), Role, Item, Glow, Toast, Callout, WaypointArrow, Charts and IconBrowser have no
lookup here. None has a recorded MultiMeters use, and none is proposed beyond #92.
