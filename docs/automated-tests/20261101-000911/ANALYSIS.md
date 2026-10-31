# Analysis — 20261101-000911

- **Addon:** MultiMeters 1.2.0 (LibKa0s v1.84.0 adoption run, `manifest.json` → `"label": "v1.84.0-adoption"`, not a release run)
- **Verdict:** green
- **Commit:** ee356f1 (feat/2026-10-31-findings-remediation), clean
- **Previous run:** [`20261031-213738`](../20261031-213738/)

## Headline

All four suites passed on the re-vendored LibKa0s v1.84.0. Lint is 0/0 over 183 files, 2449 of 2450
cases passed with the same one declared skip and none failed, 18 perf scenarios were recorded, and no
function is above CCN 15 with `blindFiles` and `crashedFiles` both 0. Nothing moved except 3 NLOC and
perf timing; `api/iter` and `bytes/iter` are identical on all 18 scenarios. There is nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261031-213738` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 183 files | [`lint.txt`](lint.txt) | not moved |
| tests | pass | 2449 passed, 1 skipped, 0 failed, 2450 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | not moved; `test-cases.md` is byte-identical |
| perf | pass | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 18; `api/iter` and `bytes/iter` identical; timing only |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +3; every other figure unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 52831 |
| Functions | 5719 |
| Avg NLOC / function | 8.4 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 68.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 22 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every figure above comes from the `suites` block in [`manifest.json`](manifest.json). No suite was
skipped. All three tools were present: Lua 5.1.5, Luacheck 1.2.0 and lizard 1.24.0
(`manifest.json` → `host`).

The one skipped case is the kit contract case `diagnostics contract: an addon that opts out lands the
report and leaves logging off` ([`tests.txt`](tests.txt), line 2439). This addon keeps the default, so
the case does not apply. It is a pre-existing condition, counted in the total and in neither passed
nor failed.

## What moved

Compared with the previous bundle's `manifest.json`, `perf.json` and `test-cases.md`.

- **lint.** Did not move: 0/0 over 183 files.
- **tests.** Did not move: 2450 cases, 2449 passed, 1 skipped, 0 failed. The two `test-cases.md` files
  are byte-identical, so the re-vendor neither added nor removed a case. The total has now been flat
  across three runs, which `RESULTS.md` flags; none of the three changed addon runtime behavior, so
  the flat count is not a gap this run opens.
- **perf.** All 18 scenarios are shared. `api/iter` and `bytes/iter` are identical on every one
  ([`perf.json`](perf.json), `buckets`), so the new library allocates and calls exactly as the old one
  did on these paths. Only timing moved, and in both directions: `refresh20x7` 0.82672 → 0.80213,
  `refresh20x7Restricted` 1.17754 → 1.05381 and `throttleBurst` 17.61300 → 14.50500 fell, while
  `applyConfig` 0.43624 → 0.51705, `rosterBurst` 0.73449 → 0.80277 and `feignTraceOff`
  0.15697 → 0.18375 rose. With the counters still, that is load difference between two runs and is
  claimed as neither a gain nor a loss.
- **complexity.** NLOC 52828 → 52831. Functions stay 5719, avg NLOC 8.4, avg CCN 2.5, avg tokens 68.8,
  max CCN 15 and warnings 0. The three lines match the adoption's three code lines in the authored
  tests: two in `tests/run.lua` and one in `tests/test_surface_parity.lua`.
- **band.** Did not move: 22 files, 0 over the cap, and no row changed LOC.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

None new. None of the 22 rows in [`../RESULTS.md`](../RESULTS.md) arrived with a blank Disposition, so
no ruling is owed and all of them carry forward. None is marked **Accepted**, so no entry is on the
three-release shelf life (anti-pattern #53).

## Actions

None.
