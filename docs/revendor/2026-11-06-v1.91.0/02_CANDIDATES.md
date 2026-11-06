# Candidates: LibKa0s v1.90.0 -> v1.91.0

Sources: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0`, the CHANGELOG `## v1.91.0` block, and the new
API documents `docs/api/Core/version-17.1-docs.md`, `docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md` and
`docs/api/Skin/version-17.1.27.8.19.19.1.1.17.4.9-docs.md`.

## A. Delivered on the re-vendor alone

- **The band peels (FU-L2; Core 17 + CorePixel 1, Widgets 26 + WidgetsDropdown 1, SkinPaintExtras 19 +
  SkinPaintHud 1 + SkinAceConfirm 1).** Pure moves: the pixel edges, the dropdown and its shared menu, the HUD
  looks and the AceConfigDialog confirmation box now live in their own files, with the same members and the same
  behavior (CHANGELOG v1.91.0: "No member, option or behavior changes"). The Export modal's dropdowns
  (`modules/Export_Modal.lua`) and the skinned segment menu (`modules/Window_Header.lua`) keep drawing through the
  same `W.Dropdown` and `W.ContextMenu`. The only host work is the test file list, done in the re-vendor commit
  (01_DELTA.md, Blockers).
- **Line-chart lines in physical pixels (FU-L1; WidgetsLineChart 7).** Arrives on the copy. This addon draws no
  `W.LineChart`, so nothing on screen changes here.

## B. Host change required

None. No new member, option or descriptor field in the range.

## C. Whole-module adoption

None: no new major in this range.
