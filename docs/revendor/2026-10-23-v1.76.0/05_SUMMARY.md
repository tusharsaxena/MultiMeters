# 05 — Summary (MultiMeters)

LibKa0s v1.75.2 -> v1.76.0 from the local annotated tag (`546e284`, commit `9949368`). The base,
v1.75.2, comes from the CLAUDE.md provenance line and agrees with the last payload commit
(`114ab0f`). Kit revision 41, unchanged. Minors: Widgets 13 -> 14, SimTimeline 2 -> 3,
SimPanel 4 -> 5, every other file unchanged.

One commit carries both payloads, the provenance line and the prune. The between-run tags v1.75.1
and v1.75.2 are recorded in the span bundle `2026-10-23-v1.75.1-v1.75.2/` (two tags). No base
correction was needed.

- **Icon line kept:** the 17 names, unchanged. No provenance split. The prune removed 5,822 files:
  207 Open Iconic marks, the whole Phosphor folder (1,435) and the whole Game-icons folder (4,180).
- **Blockers:** none. The Widgets 14 default is the old amber strip, and MultiMeters does not
  consume Sim, so the auto-run fallout (Run all removed) does not touch its suites. There is no
  `__releaseChrome` mirror.
- **Credits:** unchanged (Open Iconic still the only set that ships).
- **Delivered free:** Widgets 14 with an unchanged default; SimTimeline 3 and SimPanel 5 sit in the
  payload for the run's Sim host items.
- **Adopted here:** nothing. The sim strip lands in MM-17, the header word in MM-01, and the Sim-1.0
  host in MM-10 to MM-20.
- **Declined:** nothing new. No issue filed.
- **Standard reference:** the same commit records the `/dev-copilot:wow-revendor-standards` pass
  against standard v2.87.0 (2026-10-23), read from the local WowAddonStandards run branch. The
  three-place reference was already right and needed no edit.
- **Smoke owed (owner):** none new. INSTALL-10 still covers the pruned icon set.
- **Gate after the prune**, every run through `ka0s-bounded`: `lua tests/run.lua` 2210 passed,
  0 failed, 1 skipped (2211 total), `test_vendor_sync` green against v1.76.0; `luacheck .`
  0 warnings / 0 errors in 146 files; no authored `.lua` file over 1500 lines (largest
  `tests/test_window.lua`, 1480).

## Addendum: the tag moved (MM-RV2, LK-91)

The local tag v1.76.0 moved after MM-RV, from commit `9949368` to `e692491`. Two LibKa0s commits
sit between them: `7e81ff7` (LK-91, step-panel labels bounded before the command column, so a long
label truncates instead of running under the command) and `e692491` (LK-92, README only). The
payload at the new tag equals `7e81ff7`.

MM-RV2 re-copied both payloads whole from the moved tag (`git archive`, never a checkout) and ran
the tag's `tools/prune-icons.lua` against the unchanged `LibKa0s icons:` line. Only two files
changed:

- `libs/LibKa0s/SimPanel.lua`: the LK-91 label anchoring (`SIM_PANEL_MINOR` stays 5).
- `libs/LibKa0s/PerfPanel.lua`: the same bound on the perf panel (`PANEL_MINOR` 7 -> 8).

`tests/_kit` is byte-identical (kit revision 41). The icon tree did not change either: the tool
reported 18 names declared, 19 files kept (the 18 icons and the Open Iconic license) and 5,821
removed. The figures above (17 names, 5,822 removed) were miscounted; the files were the same.
After the prune, `diff -r` against the tag copy shows only the pruned icons. The provenance line
already reads v1.76.0 and is kept. No standard change. MultiMeters' `/mm sim` (MM-15) uses the step
panel, so it gets the label fix at no cost.

Gate after the re-vendor, every run through `ka0s-bounded`: `lua tests/run.lua` 2304 passed,
0 failed, 1 skipped (2305 total), `test_vendor_sync` green against the moved tag; `luacheck .`
0 warnings / 0 errors in 159 files; no authored `.lua` file over 1500 lines (largest
`tests/test_window.lua`, 1480).
