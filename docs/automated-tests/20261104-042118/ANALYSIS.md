# Analysis — 20261104-042118

- **Addon:** MultiMeters 1.2.0 (round 6 finish, R6-AT, not a release run)
- **Verdict:** green
- **Commit:** 8f63e8a (feat/2026-11-01-full-skinning), clean
- **Previous run:** 20261103-023822

## Headline

The run records the tree at the end of smoke rounds 4 to 6 (26 commits since `786a008`): R4-SEP, R5-MM1/R5-WIN's title band, R6-RV2's LibKa0s v1.85.0 re-cut, R6-SIM's Sim mode checkbox, R6-MM2's export glyph crop and R6-NAME. Both gating suites pass: lint 0/0 over 190 files, 2579 passed, 1 skipped, 0 failed of 2580 ([`manifest.json`](manifest.json)). Complexity records two functions newly at CCN 16, both crossed by R5's title-band commit; they gate nothing today but are owed before the next tag.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261103-023822 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 190 files | [`lint.txt`](lint.txt) | files 187 → 190 |
| tests | pass | 2579 passed, 1 skipped, 0 failed, 2580 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2548 → 2580 |
| perf | pass (recorded; gates the tag, not the commit) | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `applyConfig` bytes/iter 25092.2 → 26668.2; the rest timing only |
| complexity | pass (recorded; gates the tag, not the commit) | see below | [`complexity.txt`](complexity.txt) | max CCN 15 → 16, warnings 0 → 2 |

| Metric | Value |
|---|---|
| Total NLOC | 55482 |
| Functions | 6039 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.5 |
| Max CCN | 16 |
| Avg tokens / function | 69.0 |
| Warnings (CCN > 15) | 2 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 24 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The complexity suite passes as a suite: it is sighted (0 blind files) and nothing crashed. Its two warnings, `WindowProto.ApplyMinimized` and `HeaderControls.Apply`, both at CCN 16, are a regression against the previous run's max of 15, not a newly measured pre-existing condition: the kit and the sighting did not change between the two runs, and both functions gained their extra decisions in `da42b0c` (R5-MM1 + R5-WIN). Under the release gate (zero above CCN 15) this tree could not be tagged as it stands.

The one skip in [`tests.txt`](tests.txt) is the kit's diagnostics-contract case for an addon that opts out of turning logging on; this addon keeps the default, so the case does not apply. It is the same skip the previous run carried, counted in the total and never in passed.

## What moved

- **lint**: 187 → 190 files, still 0/0. The new files are the round's new suites (below).
- **tests**: 2548 → 2580 (+32). New suites: `test_header_band.lua` (11, R5's title band), `test_sim_checkbox.lua` (5, R6-SIM) and `test_header_glyph_size.lua` (2, R6-MM2). Grown: `test_skin_picker.lua` 12 → 21, `test_sim_e2e.lua` 10 → 13, `test_tooltip_deaths.lua` 58 → 60, and one each in `test_database_migrations.lua`, `test_row_namecell.lua` and `test_skin_fix.lua`. `test_window_header.lua` fell 63 → 60, which matches R4-SEP removing the divider and its setting. Counts are from [`test-cases.md`](test-cases.md) against the previous bundle's.
- **perf**: the same 18 scenarios; every `api/iter` figure is unchanged, and every `bytes/iter` except `applyConfig`, 25092.2 → 26668.2 per pass, up 1576 bytes; the round's header-band and header-strip work is on that path, but this run does not isolate which line allocates ([`perf.json`](perf.json)). `ms/iter` rose 20 to 60 per cent across the board, including scenarios whose code did not change (`throttleIdle`, `spellEventOff`), so it reads as host load during the collection-wide sweep rather than a cost.
- **complexity**: NLOC 54661 → 55482 and functions 5942 → 6039; avg NLOC 8.3 and avg CCN 2.5 unchanged, avg tokens 68.8 → 69.0. The addon grew and did not get denser on average, but two functions crossed CCN 15. The band count stays 24, none over the cap; `modules/Window_Header.lua` moved 1457 → 1476, 24 lines under the cap, and `core/Database_Migrations.lua` 1088 → 1106.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `WindowProto.ApplyMinimized` | 16 | `modules/Window_Header.lua` | **Peel next, newly crossed.** Guarding, not tangle: presence checks and `and true or false` coercions around one collapse/expand fork. The collapsed-height block (`if band > 0`) is the seam. |
| `HeaderControls.Apply` | 16 | `modules/HeaderControls.lua` | **Peel next, newly crossed.** Defaulting, not tangle: the `y`, `band` and `e` fallbacks for a window without a title band. One helper returning all three is the seam. |

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Window_Header.lua` | 1476 | Carried forward, now past its re-check at 1400 and 24 lines under the cap: the column-header seam is owed before anything else lands here. |

The other 23 band entries carry their dispositions forward unchanged; see `RESULTS.md`. No file newly entered the band.

## Actions

1. Peel `WindowProto.ApplyMinimized` (`modules/Window_Header.lua`) and `HeaderControls.Apply` (`modules/HeaderControls.lua`) under CCN 16 before the next tag. Pure moves, characterization first. New here; no issue tracks them yet.
2. Take the column-header seam out of `modules/Window_Header.lua` (1476) before the next feature touches it. Carried from the band disposition.
