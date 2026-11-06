# Candidates: LibKa0s v1.89.0 -> v1.90.0

Sources: `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0`, the CHANGELOG `## v1.90.0` block, and the new
API documents `docs/api/Core/version-16-docs.md`, `docs/api/Widgets/version-24.5.12.6.8.5-docs.md`,
`docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md`,
`docs/api/Options/version-37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4-docs.md`.

## A. Delivered on the re-vendor alone

- **One physical pixel (SF1-L1; Core 16, Widgets 24, WidgetsAutocomplete 8, SkinPaint 19, SkinPaintExtras 18).**
  `W.Dropdown`'s box, `W.SearchBox`, the shared menu (every cascade level) and the autocomplete list draw a
  1-physical-pixel edge at any UI scale. Here that reaches the Export modal's dropdown
  (`modules/Export_Modal.lua`) and the skinned segment menu (`W.ContextMenu`, `modules/Window_Header.lua`,
  `OpenSkinnedSegmentMenu`). Widgets 24 doc line 27: "What a host owes: nothing."
- **A copy honours `keepScope` (OptionsAppearance 7).** This addon's *Apply to all* / *Copy to all* now leave a
  `keepScope` target's Scope alone (the Skin Tester, after SF1-ST). No host change.

## B. Host change required

- **`RegisterOwner(owner, { keepScope = true })` (Skin 17).** Additive opt-out for an addon whose documented
  Scope deviates from what another addon's copy would write. Touches `core/SkinSetup.lua`. Recommendation: do not
  adopt. MultiMeters documents no Scope deviation that a copy must keep, and the run's feedback file assigns the
  opt-out to the Skin Tester alone (`SF1_SMOKE_FEEDBACK.md`, item SF1-ST). Blast radius: additive.

## C. Whole-module adoption

None: no new major in this range.
