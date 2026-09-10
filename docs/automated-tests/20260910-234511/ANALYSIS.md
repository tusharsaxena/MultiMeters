# Analysis — 20260910-234511

- **Addon:** MultiMeters 0.1.0 → 1.0.0
- **Verdict:** green
- **Commit:** 3b7018398e46 (master), clean
- **Previous run:** [`20260909-120608`](../20260909-120608/)

## Headline

The release run for **1.0.0**, the first published release — green on all four suites with zero functions above CCN 15. Twenty new test cases and 390 more NLOC. The band is twenty files deep, but nineteen of those are post-peel residue settling; the one that matters is `modules/Provider.lua`, which crossed this cycle by growing.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260909-120608` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 122 files | [`lint.txt`](lint.txt) | see below |
| tests | pass | 1748 passed, 0 skipped, 0 failed, 1748 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | see below |
| perf | pass | 15 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 37079 |
| Functions | 3777 |
| Avg NLOC / function | 8.1 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 63.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 20 |
| Files over the 1500 cap | 0 |

## What moved

- **lint** — 122 files in both runs. Still 0 warnings / 0 errors.
- **tests** — 1748 passed, up 20 from 1728. No skips, no failures. The largest suite in the collection.
- **perf** — 15 scenarios, unchanged, and the most of any addon here.
- **complexity** — NLOC 36689 → 37079 (+390) over 3752 → 3777 functions (+25). Avg NLOC flat at 8.1, avg CCN flat at 2.4, avg tokens 62.8 → 63.0. Max CCN 15, zero warnings in both. Band files 19 → 20: `modules/Provider.lua` crossed at 1056.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

None. Zero functions above CCN 15 is what the release gate required, and it is what this run measured — max CCN 15.

### Files by `layout-§1` band

20 file(s) in the 1000–1500 on-notice band, 0 over the 1500 cap. Each carries a disposition in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band). The band is not part of the release gate.

## Actions

1. `modules/Provider.lua` newly entered the band (924 → 1056 raw lines) on the roster/spec identity work and is ruled in `RESULTS.md`. It is the only band entry in this repository that arrived by growth rather than by a peel, which makes it the one to watch.
2. `tests/test_provider.lua` sits at exactly 1500 — on the cap, not over it. One more case takes it into breach. It is named in the same disposition.
