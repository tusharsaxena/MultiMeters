# Analysis — 20260926-160431

- **Addon:** MultiMeters 1.0.1
- **Verdict:** green
- **Commit:** c125001 (master), clean
- **Previous run:** [`20260924-163600`](../20260924-163600/)

## Headline

All four suites passed. Lint is 0/0 over 141 files, all 2092 cases passed with none skipped, 17 perf
scenarios were recorded, and **no** function is above CCN 15. The run measures 28 commits since the
previous one: the 1.0.1 stamp, the launcher options menu, the diagnostics rollout and the NavRail
Windows page. Two things need a ruling, and neither is a gate. `tests/test_slash.lua` grew to 1411
and crossed its own "Re-check at 1400". `doDebug` in `settings/Slash.lua` rose from CCN 14 to CCN
15, which is exactly on the release line. This is not a release run.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260924-163600` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 141 files | [`lint.txt`](lint.txt) | unchanged at 0/0; files 137 → 141 |
| tests | pass | 2092 passed, 0 skipped, 0 failed, 2092 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +57 passed (2035 → 2092) |
| perf | pass | 17 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 17 scenarios; api/iter and bytes/iter identical on all 17 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 15 → 15, warnings 0 → 0 |

| Metric | Value |
|---|---|
| Total NLOC | 43815 |
| Functions | 4459 |
| Avg NLOC / function | 8.2 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 63.9 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 23 |
| Files over the 1500 cap | 0 |

Every figure above comes from the `suites` block in [`manifest.json`](manifest.json), and the
complexity rows match the footer of [`complexity.txt`](complexity.txt). **No suite was skipped.** All
three tools were present: Lua 5.1.5, Luacheck 1.2.0 and lizard 1.24.0 (`manifest.json` → `host`).
`lizard`'s own verdict line reads "No thresholds exceeded", covering CCN > 15, length > 1000 and
parameter count > 100.

Every suite passed cleanly, so no suite needs a paragraph of its own.

## What moved

- **lint.** 0/0 again. The file count went from 137 to 141. Seven `.lua` files arrived between the two
  commits: `core/Diagnostics_Runtime.lua`, `tests/mock_menu.lua`, `tests/test_diagnostics_runtime.lua`,
  `tests/test_windows_rail.lua`, `tests/_kit/test_diagnostics_contract.lua` and two files under
  `libs/LibKa0s/`. `libs/` and `tests/_kit/` are excluded from lint, which leaves the four counted.
- **tests.** 2035 → 2092 (+57), with 0 skipped and 0 failed. [`tests.txt`](tests.txt) shows the new
  `diagnostics contract` cases from the re-vendored kit, plus the new Windows-rail and
  diagnostics-runtime suites.
- **perf.** The same 17 scenarios ran. `api/iter` and `bytes/iter` are identical on all 17, so no
  scenario changed what it does or what it allocates. Wall-clock time went up across the board, for
  example `refresh20x7` from 0.89803 to 0.99861 ms/iter and `throttleBurst` from 16.942 to 21.189 ms
  over a single iteration. Neither the API counts nor the allocation moved with it. The timings are
  for orientation only, and this looks like machine load, since sibling repositories' batteries were
  running at the same time. `rosterBurst` read 13.614 ms against 12.606 ms. It remains tracked as
  issue #54.
- **complexity.** Total NLOC went from 42513 to 43815 (+1302) and functions from 4319 to 4459 (+140).
  Avg NLOC held at 8.2 and avg CCN at 2.4. Avg tokens went from 63.6 to 63.9. The addon grew without
  getting denser. Max CCN stayed at 15 and warnings stayed at 0. Twelve functions now sit exactly at
  CCN 15, one more than the previous run's eleven. The newcomer is `doDebug` at
  `settings/Slash.lua:736-806`, which went from CCN 14, NLOC 32 to CCN 15, NLOC 36 in the diagnostics
  rollout. It is a verb dispatcher, so the CCN comes from branches rather than from defaulting. It is
  not warned on. It is recorded here because one more branch would make it the first function to
  block a tag since `20260916-184449`.
- **band.** The band still holds 23 files, and it is the same set of 23. Five of them changed length:
  `modules/Aggregator.lua` 1394 → 1432 (18 lines short of its 1450 re-check), `locales/enUS.lua`
  1039 → 1056, `modules/Provider.lua` 1074 → 1084, `tests/test_options_panel.lua` 1210 → 1194, and
  `tests/test_slash.lua` 1373 → 1411, **past its "Re-check at 1400"**.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1411 | **Re-checked, past its 1400 trigger.** 1373 → 1411 in the diagnostics rollout (DR-MM-02/03 retired `diag` and re-hosted the report under both forms). 89 lines of headroom. The seam is the diagnostics-verb cases, which can move to a `tests/test_slash_diagnostics.lua` sibling. Peel before the next change that adds verbs. Re-check at 1450. |
| 1000–1500 (on notice) | `modules/Aggregator.lua` | 1432 | Carried forward, still true. It is 18 lines short of its 1450 re-check. |

The other 21 band rows are unchanged, or shrank, below their re-check lines. Their dispositions carry
forward in [`../RESULTS.md`](../RESULTS.md). None of them is marked **Accepted**, so no entry has
passed the three-release shelf life.

## Actions

1. `tests/test_slash.lua` (1411): peel the diagnostics-verb cases into a sibling suite before it
   grows again. This is new here and has no issue yet.
2. `settings/Slash.lua` `doDebug` (CCN 15, lines 736-806): extract a sub-verb table before adding
   another `/mm debug` branch, or the next release gate fails. This is new here.
3. `modules/Aggregator.lua` (1432): its next growth reaches the 1450 re-check. The seam its
   disposition names still stands.
