# 05 — Summary (MultiMeters)

LibKa0s v1.83.0 -> v1.84.0 from the local annotated tag (commit `e917ccd`). The base, v1.83.0, comes from
the CLAUDE.md provenance line and agrees with the last payload commit (`0d603a4`). Kit revision 46 -> 47.
`01_DELTA.md` holds the minor table. No span bundle and no base correction.

- **Blocker, fixed in the copy's commit:** `O.PositionBlock` turned the surface-parity case red. It joins
  the live-only composer group in `tests/test_surface_parity.lua`, because this addon reaches composers
  through the `__AttachCompose` table and does not call this one. The Options stub in
  `settings/OptionsSetup.lua` is unchanged, on purpose.
- **Pins:** `tests/run.lua`'s `EXPECTED` list gains the six peeled files this addon depends on. The load
  list itself comes from `LibKa0s.xml`, so nothing else moved. No suite pins `DebugLogDiagnostics 5`.
- **Icon line kept:** 19 names, unchanged. The prune kept 20 files and removed 5,820. No provenance split.
- **Credits:** unchanged. No `__releaseChrome` mirror.
- **Delivered free:** see `02_CANDIDATES.md`, class A.
- **Adopted:** nothing. **Declined:** all five candidates in `03_DECISIONS.md`, no issue filed, per the brief.

## LibKa0s#67: none

Sweep of every visible row in the expanded schema (170 rows outside `statColors`). No group of rows is
picked by a dropdown or by a set of check boxes, and the schema has no selector-picked section at all.

- The one `disabledIf` form in the schema is the composer's on a media picker, governed by that row's own
  `FromSkin` box. That is the kept form under options-ui §22, *Hidden is not disabled*.
- The color modes offer `class`, `custom`, `skin` or `stat` beside one swatch. The swatch is read for its
  alpha under every mode (options-ui §17), and it is a column inside a shown group.
- `bars.bgColorMode` has a `none` value, which leaves `bars.bgColor` and `bars.bgAlpha` unread. Those are
  two rows inside the Background subgroup with the selector beside them, not a section.
- `bars.border`, `header.divider` and `icons.showIcon` are single booleans, which §22 keeps out of `shownWhen`.

## LibKa0s#68: not applicable

MultiMeters is not in the host table. `grep -rn DragHandle core modules settings` finds no call: windows
move by their title bar, so there is no fitted strip to overflow.

## Gates

Every run through `ka0s-bounded`, after the prune: `lua tests/run.lua` 2449 passed, 0 failed, 1 skipped
(2450 total), `test_vendor_sync` green against v1.84.0; `luacheck .` 0 warnings / 0 errors in 183 files.
The counts did not move, so the README badge and `docs/test-cases.md` stay as they are.

- **Smoke owed (owner):** new DIAG-43, with an empty `Result:`.
