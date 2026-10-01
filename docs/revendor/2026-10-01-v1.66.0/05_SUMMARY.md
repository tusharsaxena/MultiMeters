# 05 — Summary (MultiMeters)

LibKa0s v1.65.0 -> v1.66.0 from the local tag (`e4c5ef7`), base from the CLAUDE.md provenance line; kit
revision 34 -> 35; CLAUDE.md provenance rolled in the same commit. Minors: Widgets 11->12, DebugLog 18->19,
Slash 18->19, OptionsWidgets 33->34, OptionsTabs 7->8, Perf 13->14, and four new secondary files
(WidgetsReorder 1, SlashParse 1, PerfSampler 1, PerfCommands 1). No file deleted, no blocker.

- Span bundle written beside this one: `2026-10-01-v1.64.0-v1.65.0/` (two tags vendored without a bundle).
- Delivered free (class A): the zero-count declared parent in perf records, Slash's resolver, RenderGrid's
  no-gap failed item.
- Adopted: nothing. Declined: nothing. Unreached: the three class B candidates (Perf budgets, RenderGrid
  `opts.gap`, the three `RenderTabbedSchema` fields), left for GI-LK-13.
- Wired: `test_lizard_sighted` in `tests/run.lua`; the four new files in its expected load list.
- Gate after the copy: tests 2145 passed, 0 failed, 1 skipped, 2146 total (2137/0/1/2138 before);
  luacheck 0 warnings / 0 errors in 146 files; vendor `diff -r` against the tag empty for both payloads.
- Sighted complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity`, lizard 1.24.0):
  pass, 8 warnings, maxCcn 39, blindFiles 0, 4815 functions. The eight above CCN 15 are GI-MM-02's:
  `reportTargets` 39 (core/Diagnostics.lua), `WindowProto.Render` 22 (modules/Window.lua),
  `Targets.ForPlayer` 21 and `buildMap` 19 (modules/Targets.lua), `DrillDown.BuildRows` 18,
  `normalizeColumns` 18 (settings/Schema_Paths.lua), `Export.Send` 18, `build` 16 (modules/Roster.lua).
