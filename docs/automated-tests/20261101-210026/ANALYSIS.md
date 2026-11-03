# Analysis — 20261101-210026

- **Addon:** MultiMeters 1.2.0 (label `final review findings`, not a release run)
- **Verdict:** green
- **Commit:** 93c42e1 (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** 20261101-202709

## Headline

The run records FS-MM-GATE: the tooltip allow row names A7 in place of the undefined FS-MM-01. One new case holds every row to a defined cause. Lint 0/0 over 186 files, 2533 passed and 0 failed of 2534 tests, 18 perf scenarios at `pass`, complexity at `pass` with max CCN 15 ([`manifest.json`](manifest.json)). Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-202709 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 186 files | [`lint.txt`](lint.txt) | files unchanged |
| tests | pass | 2533 passed, 1 skipped, 0 failed, 2534 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2533 → 2534 |
| perf | pass | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 54400 → 54411, functions 5906 → 5907 |

**Complexity is reported in full**, from `manifest.json`'s `suites.complexity`:

| Metric | Value |
|---|---|
| Total NLOC | 54411 |
| Functions | 5907 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 68.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 24 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The one skipped case is the same pre-existing skip as the previous run, NOT EVALUATED at the release gate.

## What moved

- **lint**: files unchanged, still 0/0.
- **tests**: total 2533 → 2534, passed 2532 → 2533, skipped unchanged, failed unchanged. `tests/test_skin_fix.lua` gains `skin gate: every allow row names a cause of the run's SKIN_CAUSES.md, or MC`, red against the old row.
- **perf**: calls and bytes per iteration unchanged on every scenario. `ms/iter` moves are timing noise between runs.
- **complexity**: average CCN unchanged, average tokens unchanged, max CCN unchanged.

## Watch list

See `RESULTS.md`: no entry newly crossed a threshold (0 functions above CCN 15).
