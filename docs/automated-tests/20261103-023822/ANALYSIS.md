# Analysis — 20261103-023822

- **Addon:** MultiMeters 1.2.0 (smoke round 3, R3-SIM-MM, not a release run)
- **Verdict:** green
- **Commit:** 786a008 (feat/2026-11-01-full-skinning), clean
- **Previous run:** 20261102-115408

## Headline

The run records R3-SIM-MM, the Simulation step delay slider (`sim.stepDelay`, 0.5 to 10 s, 1 s by default) the other sims have, on top of the round's re-vendored LibKa0s v1.85.0 and the R3-FRIZ font move. All four suites pass: lint 0/0 over 187 files, 2547 passed, 0 failed, 1 skipped of 2548, 18 perf scenarios, and complexity with max CCN 15 and 0 warnings ([`manifest.json`](manifest.json)). Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261102-115408 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 187 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 2547 passed, 1 skipped, 0 failed, 2548 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2542 → 2548 |
| perf | pass (recorded; gates the tag, not the commit) | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | timing noise only |
| complexity | pass (recorded; gates the tag, not the commit) | see below | [`complexity.txt`](complexity.txt) | NLOC 54519 → 54661, functions 5929 → 5942 |

| Metric | Value |
|---|---|
| Total NLOC | 54661 |
| Functions | 5942 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 68.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 24 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every suite is a clean pass. The one skip in [`tests.txt`](tests.txt) is the kit's diagnostics-contract case for an addon that opts out of turning logging on; this addon keeps the default, so the case does not apply. It is the same skip the previous run carried, counted in the total and never in passed.

## What moved

- **lint**: 187 files, 0/0, as before.
- **tests**: 2542 → 2548. Four of the six new cases are R3-SIM-MM's in `tests/test_sim_session.lua` (the default and the row, the validator, `Host.StepDelay`'s read and fallback, and a playing run's pace); the other two arrived with the commits between the two runs: SG-MM-1's clip-box case in `tests/test_skin_fix.lua` and R3-FRIZ's v25 migration case in `tests/test_skin_fonts.lua`. The pins in `tests/test_defaults.lua`, `tests/test_schema.lua` and `tests/test_settings_pin.lua` moved for the new setting.
- **perf**: the same 18 scenarios; every `api/iter` and `bytes/iter` figure is unchanged, and the `ms/iter` changes are timing noise.
- **complexity**: NLOC 54519 → 54661 and functions 5929 → 5942, with every average unchanged except avg tokens 68.7 → 68.8. The addon grew and did not get denser. Max CCN stays 15 with 0 warnings, and the band count stays 24 with none over the cap.

## Complexity watch list

Functions: none warned on (see `RESULTS.md`). Files: the same 24 band entries, every one carrying its disposition forward. None crossed a threshold in this run. `settings/Schema_General.lua` grew to 409 and `modules/Sim.lua` to 349, both far from the band.

## Actions

None.
