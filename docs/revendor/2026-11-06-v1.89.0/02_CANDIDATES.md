# Candidates

Sources: `git -C ../LibKa0s log --oneline v1.85.0..v1.89.0`, the CHANGELOG blocks v1.86.0..v1.89.0, and the
`Since` markers in `docs/api/Widgets/version-23.5.12.6.7.5-docs.md` (against `version-22.5.12.6.7.5-docs.md`).

## A. Delivered on the re-vendor alone

- **DebugLogDiagnostics 7**: the diagnostics report names `IconBrowser` among the majors it lists.
- **Widgets 23, flat menus**: every single-level `W.ContextMenu` draws what 22 drew (doc :19-40, "What a
  consumer owes: nothing for a flat menu", :36).
- **Kit 51**: the CallbackHandler unregister guard (a flake fix in `tests/_kit/mock_ace.lua`).
- **Toast 4**: delivered and unused here (no Toast lookup, no stub).

## B. Host change required

1. **Widgets 23 `radio` + `selected` on the skinned segment menu.** Evidence: `docs/api/Widgets/version-23.5.12.6.7.5-docs.md`
   :28-29 (`radio`, `selected`, Since 23). Touches `modules/Window_Header.lua:1211-1236` (`OpenSkinnedSegmentMenu`,
   whose rows already carry the `isActive` predicate) and the stale comment in the client fallback at :1281-1284.
   Recommendation: adopt; the menu then ticks the segment the window shows, which the client fallback's comment
   records as the missing piece. Blast radius: additive (two row fields; no code removed).
2. **Widgets 23 `submenu` rows.** Not applicable: the segment menu has one level; the only `W.ContextMenu` use site is
   `modules/Window_Header.lua:1234`.
3. **Widgets 23 `opts.check`.** Not applicable: the default tick (an owned menu's Ka0s `confirm`, which this addon
   declares) serves.

## C. Whole-module adoption

- **`LibKa0s-IconBrowser-1.0` (v1.86.0)**: MultiMeters has no icon chooser (its art is a fixed declared set, the
  `LibKa0s icons:` line). Settled by owner ruling for every addon without a chooser; no issue.
- **Toast** (not consumed): MultiMeters raises no alert toasts; nothing in this range changes that premise.
