# Analysis — 20260924-163600

- **Addon:** MultiMeters 1.0.0
- **Verdict:** green
- **Commit:** a77688a (feat/2026-09-23-review-audit-remediation), clean
- **Previous run:** [`20260924-143604`](../20260924-143604/)

## Headline

All four suites are green. Lint is 0/0 over 137 files, 2035 of 2035 cases passed with none skipped,
17 perf scenarios were recorded, and **no** function is above CCN 15. The previous run had two peel
actions and both are done. `modules/Window.lua` went from 1490 to 1321 lines and three suites came
out from under the cap, which takes the band from 24 files to 23. The one open item is `rosterBurst`.
It repeated, at 12.606 ms against 6.095 ms, and it is already tracked as issue #54. This is not a
release run.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260924-143604` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 137 files | [`lint.txt`](lint.txt) | unchanged at 0/0; files 132 → 137 |
| tests | pass | 2035 passed, 0 skipped, 0 failed, 2035 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +5 passed (2030 → 2035) |
| perf | pass | 17 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 17 scenarios; api/iter and bytes/iter identical on all 17 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 15 → 15, warnings 0 → 0 |

| Metric | Value |
|---|---|
| Total NLOC | 42513 |
| Functions | 4319 |
| Avg NLOC / function | 8.2 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 63.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 23 |
| Files over the 1500 cap | 0 |

Every figure above comes from the `suites` block in [`manifest.json`](manifest.json), and the
complexity rows match the footer of [`complexity.txt`](complexity.txt). **No suite was skipped.** All
four ran, and every figure here is a measurement.

Every suite passed, so this section has no failures to explain. The totals rose a little and the
averages held. NLOC went from 42299 to 42513 (+214) and functions from 4307 to 4319 (+12). Avg NLOC
per function stayed at 8.2, avg CCN at 2.4 and avg tokens at 63.6. The growth comes from peels, and
peels add file headers and duplicated fixtures. None of it is new logic.

## What moved

- **Commits.** `ace15be` → `a77688a` is 7 commits. Two are the previous run's records: the MM-DOCS
  bundle commit `a78eb84` and the MM-32 standards re-sweep `7761bbe`. The other five are the two
  peels and their review fixes, as follows. `d4c76aa` pins Window.lua's bus wiring and lifecycle.
  `c650485` does the Window.lua peel, and `550a432` fixes the comments that peel left stale.
  `f382f23` peels the three suites, and `a77688a` fixes their stale comments.
- **Previous run's actions.**
  1. *`modules/Window.lua` peel*: **done.** `d4c76aa` pinned the seam with five characterization
     cases. `c650485` moved the `Bus wiring` and `Lifecycle` tail into `modules/Window_Lifecycle.lua`.
     That file loads right after `modules\Window.lua` on a LOAD-BEARING TOC line. `550a432` fixed the
     stale subscriber comments. Window.lua is 1490 → 1321 in this run's band table.
  2. *`tests/test_row.lua`, `tests/test_window_header.lua`, `tests/test_database.lua`*: **done** in
     `f382f23`, with a comment follow-up in `a77688a`. Each suite was peeled rather than re-ruled.
     Every case kept its name, and the case names in [`test-cases.md`](test-cases.md) match the
     previous bundle's apart from the five pins. `test_row.lua` went 1490 → 1223 and
     `test_window_header.lua` went 1494 → 1177. `test_database.lua` left the band: `f382f23` records
     1470 → 518.
  3. *`rosterBurst`*: **tracked in GitHub issue #54.** It is compared under perf below.
- **tests: 2030 → 2035, +5.** The five new cases are `d4c76aa`'s pins, all in `test_window.lua`:
  `RegisterBus subscribes exactly the twelve messages a window answers`, `Every data message marks the
  window dirty`, `CONFIG_CHANGED for ANOTHER window leaves this one alone`, `Destroy takes the window
  off EVERY message, not just the meter`, and `SetConfig re-points the window at a new config without
  rebuilding it`. Every other change is a move between suites. `test_database.lua` 76 → 28 plus
  `test_database_migrations.lua` 48. `test_row.lua` 77 → 62 plus `test_row_mouse.lua` 15.
  `test_window_header.lua` 73 → 57 plus `test_window_header_sort.lua` 16. `test_window.lua` 65 → 62,
  which is 5 pins in and 8 cases out to `test_window_lifecycle.lua`. No case reported a skip.
  `docs/test-cases.md` is byte-identical to this bundle's [`test-cases.md`](test-cases.md).
- **lint: 0/0, and 132 → 137 files.** Five files are new: `modules/Window_Lifecycle.lua`,
  `tests/test_window_lifecycle.lua`, `tests/test_row_mouse.lua`, `tests/test_window_header_sort.lua`
  and `tests/test_database_migrations.lua`. No file left. The lint scope has not changed and is
  stated under the table in [`RESULTS.md`](../RESULTS.md#lint).
- **perf: same 17 scenarios, and every deterministic column is unchanged.** In
  [`perf.txt`](perf.txt) and the previous bundle's, `api/iter` and `bytes/iter` match on all 17
  scenarios. The wall-clock column went up in most scenarios by roughly 10–20%. For example,
  `refresh20x7` went 0.78952 → 0.89803 ms, `rosterCached` 0.58532 → 0.72617 ms and
  `probeOverheadOn` 0.60100 → 0.72314 ms. A few stayed flat or fell: `applyConfig` went
  0.15621 → 0.14430 ms and `feignTraceAbsent` 0.15995 → 0.15936 ms. The peels only moved code
  between files, and the reads and allocations are identical, so this is timer drift and not a code
  change. [`perf.txt`](perf.txt) says the timings are for orientation only.
  **`rosterBurst`: 6.095 → 12.606 ms, so the reading repeated and got higher.** Its `bytes/iter`
  (316951.0) and `api/iter` (8.00) are identical to the previous run's. It is still a single-iteration
  scenario (`iters` 1). The other single-shot scenario, `throttleBurst`, went 15.334 → 16.942 ms.
  So the addon does the same work for a roster burst and the time taken is what varies. The
  previous run's rule was to look at it if it repeats, and it did. Issue #54 already tracks that look.
- **complexity: max CCN 15, warnings 0, both unchanged.** Eleven functions sit at exactly 15 in
  [`complexity.txt`](complexity.txt), the same count as the previous run. None is over 15.
- **Band: 24 → 23 files, 0 over the cap.** `tests/test_database.lua` left and nothing joined.
  Three entries shrank because they were peeled: `modules/Window.lua` 1490 → 1321,
  `tests/test_row.lua` 1490 → 1223 and `tests/test_window_header.lua` 1494 → 1177.
  `tests/test_window.lua` went 1387 → 1349, because the pins came in and the lifecycle cases went out.
  The new siblings all land under 1000 lines. The largest is `tests/test_database_migrations.lua`,
  which `f382f23` records at 981 lines, so it is the one sibling that could join the band.

## Complexity watch list

The dispositions are in [`RESULTS.md`](../RESULTS.md#complexity-watch-list). This section covers only
what changed.

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band:** 23 entries and none over the cap. Three were re-ruled this run and the
other twenty carry forward:

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Window.lua` | 1321 | Peeled in `c650485` (bus wiring + lifecycle → `Window_Lifecycle.lua`); issue #29's chain intact; next seam outside it is `ApplyConfig`; re-check at 1450 |
| 1000–1500 (on notice) | `tests/test_row.lua` | 1223 | Peeled in `f382f23` (mouse cases → `test_row_mouse.lua`); no longer tied to `modules/Row.lua`; re-check at 1400 |
| 1000–1500 (on notice) | `tests/test_window_header.lua` | 1177 | Peeled in `f382f23` along the named seam (sort → `test_window_header_sort.lua`); re-check at 1400 |

`tests/test_database.lua` left the band because of the `f382f23` peel, and under the runner's rules
its row is gone. No new file entered the band, so no row came in with a blank disposition.

## Actions

1. `rosterBurst`: already tracked as GitHub issue #54. Add this run's reading to that issue:
   12.606 ms, with `bytes/iter` and `api/iter` unchanged. Nothing new is opened here.
