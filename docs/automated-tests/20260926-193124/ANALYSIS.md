# Analysis — 20260926-193124

- **Addon:** MultiMeters 1.0.1
- **Verdict:** green
- **Commit:** f53ca7a (feat/2026-09-26-automated-tests-sweep), clean
- **Previous run:** [`20260926-160431`](../20260926-160431/)

## Headline

All four suites passed. Lint is 0/0 over 144 files, all 2092 cases passed with none skipped, 17 perf
scenarios were recorded, and **no** function is above CCN 15. This is the closing run of the
2026-09-26 automated-tests sweep, and both items the previous run raised are resolved:
`tests/test_slash.lua` peeled 1411 → 834 and left the band, and `doDebug` in `settings/Slash.lua`
dropped from CCN 15 to CCN 11. `modules/Aggregator.lua` (1432 → 1230) and `modules/Row.lua`
(1446 → 1226) were peeled as well. Nothing needs acting on. This is not a release run.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260926-160431` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 144 files | [`lint.txt`](lint.txt) | unchanged at 0/0; files 141 → 144 |
| tests | pass | 2092 passed, 0 skipped, 0 failed, 2092 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged at 2092; 26 cases moved between suites |
| perf | pass | 17 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 17 scenarios; api/iter and bytes/iter identical on all 17 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 15 → 15, warnings 0 → 0, CCN-15 functions 12 → 11 |

| Metric | Value |
|---|---|
| Total NLOC | 43863 |
| Functions | 4462 |
| Avg NLOC / function | 8.2 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 63.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 22 |
| Files over the 1500 cap | 0 |

Every figure above comes from the `suites` block in [`manifest.json`](manifest.json), and the
complexity rows match the footer of [`complexity.txt`](complexity.txt). **No suite was skipped.** All
three tools were present: Lua 5.1.5, Luacheck 1.2.0 and lizard 1.24.0 (`manifest.json` → `host`).
`lizard`'s own verdict line reads "No thresholds exceeded", covering CCN > 15, length > 1000 and
parameter count > 100.

Every suite passed cleanly, so no suite needs a paragraph of its own.

## What moved

The run measures 9 commits since the previous one, all of them the sweep's: the LibKa0s v1.62.0
re-vendor (MM-ATS-RV), three peels (MM-ATS-01/02/03) with their citation repoints (MM-ATS-02R/03R),
and the `doDebug` extraction (MM-ATS-04).

- **lint.** 0/0 again. Files 141 → 144: the three authored files the peels created,
  `modules/Aggregator_Order.lua`, `modules/Row_Border.lua` and `tests/test_slash_diagnostics.lua`. The
  re-vendor's new `libs/LibKa0s/` and `tests/_kit/` files sit under the two excluded paths and are not
  counted.
- **tests.** 2092 → 2092, with 0 skipped and 0 failed. The count held because every peel was a pure
  move: [`test-cases.md`](test-cases.md) against the previous bundle's shows `tests/test_slash.lua`
  76 → 50, the new `tests/test_slash_diagnostics.lua` at 20 and `tests/test_slash_refusal.lua` 5 → 11,
  with no case name added or lost.
- **perf.** The same 17 scenarios ran, and `api/iter` and `bytes/iter` are identical on all 17, so the
  peels changed neither what a scenario calls nor what it allocates. Wall-clock time fell across the
  board, for example `refresh20x7` 0.99861 → 0.76653 ms/iter and `throttleBurst` 21.189 → 12.929 ms
  over one iteration. The previous analysis read its own rise as machine load, and this fall is the
  same noise in the other direction: no code on those paths changed. `rosterBurst` read 6.917 ms
  against 13.614 ms; it remains tracked as issue #54.
- **complexity.** Total NLOC 43815 → 43863 (+48) and functions 4459 → 4462 (+3). Avg NLOC held at
  8.2 and avg CCN at 2.4; avg tokens 63.9 → 63.8. Max CCN stayed at 15 and warnings at 0. Functions
  sitting exactly at CCN 15 went from twelve to eleven: `doDebug` at `settings/Slash.lua:758-811` is
  now CCN 11, NLOC 28, with the tooltip toggle out in `doDebugTooltip` (`:743-752`, CCN 5). The other
  eleven are unchanged; `scanColumn` only moved from `modules/Aggregator.lua:1033` to `:901` with the
  orderings' peel.
- **band.** 23 → 22 files. `tests/test_slash.lua` left the band at 834. `modules/Aggregator.lua`
  1432 → 1230 and `modules/Row.lua` 1446 → 1226 stayed in it, each now about 170 lines short of its
  1400 re-check. `tests/test_row.lua` went 1223 → 1229 when its static R3 getter scan widened to
  `modules/Row_Border.lua`. No file newly entered the band and no other band file changed length.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Aggregator.lua` | 1230 | Peeled in MM-ATS-03. Re-check at 1400; the source-admission helpers are the next seam. |
| 1000–1500 (on notice) | `modules/Row.lua` | 1226 | Peeled in MM-ATS-02. Re-check at 1400; the value cell is the next seam. |
| 1000–1500 (on notice) | `tests/test_row.lua` | 1229 | +6 in MM-ATS-02, same case. Re-check at 1400. |

The other 19 band rows did not change length. Their dispositions are in
[`../RESULTS.md`](../RESULTS.md), where the stale figures in 13 of them were refreshed to this run's
line counts with the rulings unchanged. None of them is marked **Accepted**, so no entry has passed
the three-release shelf life. The tightest file is `settings/Schema_Compose.lua` at 1410, 90 lines
under the cap.

## Actions

None. Both actions the previous run raised (`tests/test_slash.lua`, `doDebug`) are done, and
`modules/Aggregator.lua` is no longer near its re-check.
