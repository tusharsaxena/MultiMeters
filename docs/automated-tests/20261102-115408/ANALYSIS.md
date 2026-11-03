# Analysis — 20261102-115408

- **Addon:** MultiMeters 1.2.0 (smoke round 2, SG-MM-1 plus the LibKa0s v1.85.0 refresh, not a release run)
- **Verdict:** green
- **Commit:** 493783b plus SG-MM-1 (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** 20261102-004456

## Headline

The run records SG-MM-1 (the column-header strip now clips during a resize drag) and the re-vendored LibKa0s v1.85.0. Lint 0/0 over 187 files, 2541 passed and 0 failed of 2542 tests, 18 perf scenarios at `pass`, complexity at `pass` with max CCN 15 ([`manifest.json`](manifest.json)). Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261102-004456 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 187 files | [`lint.txt`](lint.txt) | files 186 → 187 |
| tests | pass | 2541 passed, 1 skipped, 0 failed, 2542 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2538 → 2542 |
| perf | pass (recorded, non-gating) | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | timing noise only |
| complexity | pass (recorded, non-gating) | see below | [`complexity.txt`](complexity.txt) | NLOC 54437 → 54519, functions 5912 → 5929 |

| Metric | Value |
|---|---|
| Total NLOC | 54519 |
| Functions | 5929 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 68.7 |
| Warnings (CCN > 15) | 0 |
| Blind files | 0 |
| Crashed files | 0 |

## What moved

- **tests**: one new SG-MM-1 case in `tests/test_skin_fix.lua`; the rest of the growth came with the vendored kit and library refresh. The one skip is the pre-existing release-gate skip.
- **complexity**: average CCN unchanged, max CCN unchanged.

## Watch list

See `RESULTS.md`: nothing newly crossed a threshold.
