# Analysis — 20261102-004456

- **Addon:** MultiMeters 1.2.0 (smoke feedback SF-MM-1 to SF-MM-5, not a release run)
- **Verdict:** green
- **Commit:** a50d696 (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** 20261101-210026

## Headline

The run records the smoke-feedback fixes: title LEFT by default, cell outline only with Show border, bar background opacity 15%, body clipping during a resize drag, and the chat-text export glyph. Lint 0/0 over 186 files, 2537 passed and 0 failed of 2538 tests, 18 perf scenarios at `pass`, complexity at `pass` with max CCN 15 ([`manifest.json`](manifest.json)). Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-210026 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 186 files | [`lint.txt`](lint.txt) | files unchanged |
| tests | pass | 2537 passed, 1 skipped, 0 failed, 2538 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 2534 → 2538 |
| perf | pass | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | timing noise only |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 54411 → 54437, functions 5907 → 5912 |

| Metric | Value |
|---|---|
| Total NLOC | 54437 |
| Functions | 5912 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 68.8 |
| Warnings (CCN > 15) | 0 |
| Blind files | 0 |
| Crashed files | 0 |

## What moved

- **tests**: four new SF-MM cases in `tests/test_skin_fix.lua`; three existing cases changed to the new defaults. The one skip is the pre-existing release-gate skip.
- **complexity**: average CCN and tokens unchanged, max CCN unchanged.

## Watch list

See `RESULTS.md`: nothing newly crossed a threshold.
