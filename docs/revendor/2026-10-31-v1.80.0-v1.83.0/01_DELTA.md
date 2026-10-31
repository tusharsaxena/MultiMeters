Delta: LibKa0s v1.80.0 -> v1.83.0 (span: v1.80.0 v1.81.0 v1.82.0 v1.83.0)

# 01 — Delta: the consolidated span bundle (MultiMeters)

Written 2026-10-31 with item FX-MM-DOCS of the Ka0sAddonsCommonTasks bundle
`docs/2026-10-31-FINDINGS_REMEDIATION/`, on branch `feat/2026-10-31-findings-remediation`. This bundle
re-vendors nothing. It records four tags that landed between bundles, each vendored inside a
cross-repo run whose own bundle carries the reasoning:

- `6b64c7f` (2026-10-29) `MM-RV: Re-vendor LibKa0s v1.80.0 and meet its consumer obligations`
- `462ebf0` (2026-10-30) `MM-RV: Re-vendor LibKa0s v1.81.0 and roll the provenance line`
- `3aa2c9f` (2026-10-30) `MM-01: Re-vendor LibKa0s v1.82.0 from the local tag`
- `aad6a8d` (2026-10-31) `MM-F01: Re-vendor LibKa0s v1.83.0, default the outline to HUD text only`,
  then `0dd7027` and `0d603a4`, which took the re-cut tag (LK-A1, LK-A2, LK-A3)

v1.78.0 and v1.79.0 were never vendored here: the provenance line goes from v1.77.0 straight to
v1.80.0, so the first step below spans them.

## Base

The span's base is **v1.77.0**, the provenance line before `6b64c7f` and the newest recorded bundle,
`2026-10-24-v1.77.0/`.

## Per-file minors

From `git -C ../LibKa0s diff --name-only <a> <b> -- LibKa0s testkit`, each touched file's `*_MINOR`
constant on both sides. The commits are the tags as they stand today.

| Step (commit) | Files | New files | Minors moved |
|---|---|---|---|
| v1.77.0 -> v1.80.0 (`315c79e`) | 74 | `Skin`, `SkinAce`, `SkinDefs`, `SkinEUI`, `SkinPaint`, `SkinPaintControls`, `SkinPaintExtras`, `OptionsAppearance`, `OptionsSkinPicker`, `DebugLogWindow`, `Toast`, `WidgetsCopyWindow` | 21 existing files, including `OptionsCompose` 11 -> 13, `OptionsScroll` 4 -> 8, `OptionsRegistry` 2 -> 4, `OptionsWidgets` 34 -> 35, `OptionsTabs` 9 -> 10, `PerfPanel` 9 -> 10, `SimPanel` 6 -> 7 |
| v1.80.0 -> v1.81.0 (`56ebc24`) | 24 | none | 21 files by one each, including `OptionsWidgets` 36, `OptionsTabs` 11, `SkinDefs` 16, `SkinPaint` 12, `PerfPanel` 11, `SimPanel` 8 |
| v1.81.0 -> v1.82.0 (`5eca031`) | 31 | `OptionsSwitch` | `OptionsAppearance` 4, `OptionsCompose` 14, `OptionsSkinPicker` 3, `OptionsWidgets` 37, `SkinDefs` 17, `SkinPaint` 13, `SkinPaintControls` 11, `SkinPaintExtras` 7, `WidgetsDragHandle` 8 |
| v1.82.0 -> v1.83.0 (`c88588a`) | 33 | `OptionsMedia` | `OptionsAppearance` 5, `OptionsSkinPicker` 4, `OptionsWidgets` 38, `SkinAce` 5, `SkinDefs` 18 |

## Consumption

The skin family is the span's whole subject, and MultiMeters consumes it through
`core/SkinSetup.lua`. What each step asked of this addon is in the commits above and in their runs:
`docs/2026-10-29-SKINNING_ROLLOUT/`, `docs/2026-10-30-SKIN_LIBRARY_FOLLOWUPS/`,
`docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK/` and `docs/2026-10-31-FONT_PICKERS_AND_SKIN_FACES/`, all in
Ka0sAddonsCommonTasks.
