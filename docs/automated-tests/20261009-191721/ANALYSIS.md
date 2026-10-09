# Analysis — 20261009-191721

- **Addon:** MultiMeters 1.1.0 → 1.2.0 (release run, `manifest.json` → `"release": "1.2.0"`)
- **Verdict:** green
- **Commit:** b3c8b4f (master), clean
- **Previous run:** [`20260927-030445`](../20260927-030445/)

## Headline

The 1.2.0 release gate passed: all four suites at `pass`, no function above CCN 15, and `blindFiles`
0. Lint is 0/0 over 146 files, 2196 of 2197 cases passed with one declared skip and none failed, and
18 perf scenarios were recorded. This is the first release run on the sighted complexity suite (kit
revision 35 or later), so the function count rose partly because `lizard` now sees functions it used
to drop. One file newly entered the 1000–1500 band, `tests/test_roster.lua`, and has its disposition.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260927-030445` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 146 files | [`lint.txt`](lint.txt) | still 0/0; 144 → 146 files |
| tests | pass | 2196 passed, 1 skipped, 0 failed, 2197 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2092 → 2197 total; skipped 0 → 1 |
| perf | pass | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 17 → 18 (`rosterPartial` new); api/iter and bytes/iter identical on the 17 shared |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | first sighted release run; averages up slightly |

| Metric | Value |
|---|---|
| Total NLOC | 45504 |
| Functions | 4913 |
| Avg NLOC / function | 8.4 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 68.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 23 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

Every figure above comes from the `suites` block in [`manifest.json`](manifest.json). No suite was
skipped. All three tools were present: Lua 5.1.5, Luacheck 1.2.0 and lizard 1.24.0
(`manifest.json` → `host`).

The complexity suite is sighted: `blindFiles` is 0, so `lizard` measured every function in every
file. The previous run's manifest has no `blindFiles` field because it predates kit revision 35, so
its figures were unsighted and undercounted whatever `lizard` dropped. Some of the 4462 → 4913
function rise is therefore newly measured rather than new code. No function above CCN 15 was newly
measured, so there is nothing to re-rule.

The one skipped case is a kit contract case, `diagnostics contract: an addon that opts out lands the
report and leaves logging off` ([`tests.txt`](tests.txt), line 2186). It does not apply here: this
addon keeps the default (`Kit.diagnostics.enablesLogging` is not false), and the case before it holds
that behavior. It is counted in the total and in neither passed nor failed.

### Release gate (`automated-tests-§3`)

| Gate | Result | Detail |
|---|---|---|
| Lint | PASS | `suites.lint.status` pass, 0 warnings / 0 errors in 146 files |
| Tests | PASS | `suites.tests.status` pass, failed 0 of 2197 (1 skipped) |
| Perf | PASS | `suites.perf.status` pass, 18 scenarios measured (not the no-`tests/perf.lua` exception) |
| Complexity | PASS | `suites.complexity.status` pass, lizard 1.24.0 ran |
| CCN <= 15 | PASS | `suites.complexity.warnings` 0, max CCN 15 |
| Sighted | PASS | `suites.complexity.blindFiles` 0 |

## What moved

The run measures 70 commits past the previous run's `abbb29e`: the 1.1.0 release commit, the
LibKa0s re-vendors from v1.63.0 to v1.71.0, the `/mm profile` verb, the debug-coverage fill, the
census adoption (the library's resize grip), the companion-identity fix for classed training dummies
(#56), the 2026-10-07 review remediation (MM-01 to MM-10) and two sync-docs passes.

- **lint.** 0/0, as before. The file count went 144 → 146 with new suites and modules.
- **tests.** 2092 → 2197 cases. The new ones come with the work above, for example the pet-before-
  owner merge cases (MM-01), the case-only rename case (MM-04) and the partial-roster cases (MM-03).
  The single skip is the kit contract case explained above. No case failed.
- **perf.** `rosterPartial` is new, added with MM-03's rebuild-at-most-once-per-pass change. On the
  17 scenarios both runs share, `api/iter` and `bytes/iter` are identical. Wall-clock time rose on
  most of them, for example `refresh20x7` 0.88199 → 1.04734 ms/iter and `applyConfig` 0.15089 →
  0.25980 ms/iter, with the API and allocation figures unchanged, which points at machine load
  rather than code. `rosterBurst` went 16.913 → 17.876 ms over one iteration and stays tracked as
  issue #54.
- **complexity.** NLOC 43863 → 45504, functions 4462 → 4913, avg NLOC 8.2 → 8.4, avg CCN 2.4 → 2.5,
  avg tokens 63.8 → 68.3. Max CCN stays 15 with 0 warnings. The averages moved by a tenth, and part
  of that is the sighted suite counting functions the old one missed.
- **band.** 22 → 23 files. `tests/test_roster.lua` is new at 1014 (904 at the previous run). Of the
  rest, `tests/test_aggregator.lua` grew most (1279 → 1437), followed by `modules/Aggregator.lua`
  (1230 → 1343), `tests/test_export.lua` (1325 → 1408) and `tests/test_window.lua` (1349 → 1398);
  `modules/Tooltip.lua` shrank (1167 → 1153). None passed its recorded re-check line, and the
  tightest file is still `settings/Schema_Compose.lua` at 1410, 90 lines under the cap.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. This is a release run, and zero functions above CCN 15 is what the gate enforced.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_roster.lua` | 1014 | **Newly crossed by growth.** MM-03's partial-roster cases and DL-MM-02's debug-coverage cases; it mirrors `modules/Roster.lua` (764). Re-check at 1300. |

That is the only new row. The other 22 dispositions in [`../RESULTS.md`](../RESULTS.md) carry
forward unchanged. None of the 23 is marked **Accepted**, so no entry is on the three-release shelf
life (anti-pattern #53).

## Actions

None. `tests/test_aggregator.lua` (1437, re-check at 1450) and `tests/test_window.lua` (1398,
re-check at 1450) are the band files closest to their re-check lines, and the next release run
should look at them first.
