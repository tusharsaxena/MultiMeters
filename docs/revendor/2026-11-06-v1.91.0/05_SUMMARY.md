# Summary: LibKa0s v1.90.0 -> v1.91.0 (item FU-RV-MM)

- **Tag:** v1.90.0 -> v1.91.0 (local tag, commit `55bfbb4`, not yet pushed). The base comes from the `CLAUDE.md`
  provenance line (3a), which agrees with the last payload commit `a8d6d71`. Kit revision 51, unchanged.
- **Step 0:** skipped as a roster table, because the installed skill's roster regex matches nothing in ADDONS.md's
  current path format (fixed upstream by FU-DC1). Run for this addon alone with `tag_at` rewritten with named
  variables: `ok`.
- **Per-file minors that moved:** Core 16 -> 17, SkinPaintExtras 18 -> 19, Widgets 25 -> 26, WidgetsLineChart
  6 -> 7. New files: CorePixel 1, SkinPaintHud 1, SkinAceConfirm 1, WidgetsDropdown 1. No removed file, no
  cross-major skew.
- **Span bundle / base correction:** none (3h unrecorded list empty; Step 0 `ok`).
- **Delivered free (class A):** the four peels, as pure moves with no member or behavior change (the Export modal's
  dropdowns and the segment menu draw through the same `W.Dropdown` and `W.ContextMenu`); the line chart's lines in
  physical pixels, which this addon does not draw.
- **Blockers fixed in the re-vendor commit:** `tests/run.lua`'s `EXPECTED` library-file list adds `CorePixel.lua`,
  `SkinPaintHud.lua`, `SkinAceConfirm.lua` and `WidgetsDropdown.lua` in `LibKa0s.xml` order;
  `tests/test_export_modal.lua`'s three comment citations of the shared menu move from `Widgets.lua` to
  `WidgetsDropdown.lua`. No test pins an exact minor of a moved file, and no stub mirrors a moved member. No
  contract change (3g). Dead stub mirrors: none.
- **Icons:** `LibKa0s icons:` line kept unchanged, directly under the rolled provenance line (`CLAUDE.md:62-63`).
  Before the prune both content and byte diffs were empty against the whole tag, and `tests/_kit` matched. The
  prune (`lua /tmp/claude-1000/fu-rv-mm/new/tools/prune-icons.lua .`) printed `23 icon(s) declared; kept 25
  file(s), removed 5815`, the same split as v1.90.0. After it, the only diff lines are the undeclared icons. No
  provenance split.
- **README credits:** unchanged. The shipped sets are still Open Iconic and Phosphor, both credited.
- **Refresh file:** none (a new tag for this addon, not a refresh).
- **Adopted:** nothing. **Declined:** nothing (no class B or C candidate); no issue filed, by the run's instruction.
- **Skipped / unreached:** none.
- **Gate (re-vendor commit):** `ka0s-bounded luacheck .`: 0 warnings / 0 errors in 190 files.
  `ka0s-bounded lua tests/run.lua`: 2586 passed, 0 failed, 1 skipped (the opt-out diagnostics case, which this
  addon does not take), 2587 total. The largest addon file is `modules/Window_Header.lua` at 1475 lines, under the
  1500-line cap. No addon function changed, so the CCN figure is unchanged.
