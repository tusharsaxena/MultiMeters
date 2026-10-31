# Analysis — 20261031-213738

- **Addon:** MultiMeters 1.2.0 (post-remediation run, `manifest.json` → `"label": "findings-remediation"`, not a release run)
- **Verdict:** green
- **Commit:** a309925 (feat/2026-10-31-findings-remediation), clean
- **Previous run:** [`20261031-202021`](../20261031-202021/)

## Headline

All four suites passed. Lint is 0/0 over 183 files, 2449 of 2450 cases passed with the same one
declared skip and none failed, 18 perf scenarios were recorded, and no function is above CCN 15 with
`blindFiles` and `crashedFiles` both 0. The remediation shows up as intended: `applyConfig`'s
`bytes/iter` fell from 63874.5 to 26194.5, the band went from 24 files to 22 and no carried row is
past its re-check line. No new band row arrived, so no disposition was owed.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261031-202021` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 183 files | [`lint.txt`](lint.txt) | still 0/0; 178 → 183 files |
| tests | pass | 2449 passed, 1 skipped, 0 failed, 2450 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | not moved; the case lists match |
| perf | pass | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 18; `api/iter` identical; `bytes/iter` moved on `applyConfig`, `refresh20x7` and `rosterBurst` |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC and functions up a little; every average unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 52828 |
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
report and leaves logging off` ([`tests.txt`](tests.txt), line 2439). It does not apply here: this
addon keeps the default (`Kit.diagnostics.enablesLogging` is not false), and the case before it holds
that behavior. It is a pre-existing condition, counted in the total and in neither passed nor failed.

## What moved

Compared with the previous bundle's `manifest.json`, `perf.json`, `lint.txt` and `tests.txt`.

- **lint.** 0/0, as before. 178 → 183 files, and the five additions are the peels:
  `core/Database_Migrations.lua`, `settings/Schema_General.lua`, `settings/Schema_Vocab.lua`,
  `tests/test_options_tabs.lua` and `tests/test_window_layout.lua` ([`lint.txt`](lint.txt)).
- **tests.** Did not move: 2450 cases, 2449 passed, 1 skipped, 0 failed. The PASS and SKIP lines of
  the two `tests.txt` files are the same set, which is what pure-move peels should leave behind.
- **perf.** All 18 scenarios are shared and `api/iter` is identical on every one.
  - `applyConfig`: 63874.5 → 26194.5 `bytes/iter`, 0.48738 → 0.43624 ms/iter
    ([`perf.json`](perf.json), `buckets`). This is the reading the previous analysis left open. The
    fall is mostly the mock's recycled `SetPoint` records and partly the three tables
    `PlaceTestStrip` no longer builds a pass (`2ff4558`), so it is not all client-side saving.
  - `rosterBurst`: now 300 iterations where it was 1, so 1.156 → 0.73449 ms/iter and
    316951.0 → 315142.0 `bytes/iter` compare a mean with a single sample and are not a speed-up. From
    this run on the scenario can be compared with itself.
  - `refresh20x7`: 297237.4 → 297216.1 `bytes/iter`, which is now the same figure as `rosterCached`
    and `probeOverheadOff`. The other 15 scenarios hold their `bytes/iter`.
  - Timing: most ms/iter figures fell (`refresh20x7` 1.10561 → 0.82672, `throttleBurst`
    23.96600 → 17.61300). With `api/iter` and `bytes/iter` still, that is a machine-load difference
    between the two runs and is not claimed as an improvement. `throttleIdle` (0.00063 → 0.00085),
    `suspended` (0.00014 → 0.00015) and `spellEventOn` (0.00038 → 0.00040) rose by amounts of the same
    kind, each below a microsecond.
- **complexity.** NLOC 52646 → 52828, functions 5713 → 5719. Avg NLOC stays 8.4, avg CCN stays 2.5,
  avg tokens stay 68.8, max CCN stays 15 and warnings stay 0. The peels added a few function shells
  and the addon got no denser.
- **band.** 24 → 22 files, both exits as the previous dispositions predicted: `core/Database.lua`
  and `tests/test_options_panel.lua` left. Three carried rows fell inside the band: `settings/Schema.lua`
  1473 → 1101, `settings/Schema_Compose.lua` 1470 → 1308, `tests/test_window.lua` 1472 → 1132.
  `modules/Window_Header.lua` rose by one, 1370 → 1371. No file entered, and none is over the
  cap.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

None new. No new or changed row is owed a ruling: none of the 22 rows in [`../RESULTS.md`](../RESULTS.md)
arrived with a blank Disposition, and all of them carry forward. None is marked **Accepted**, so no
entry is on the three-release shelf life (anti-pattern #53).

No carried row is past the re-check line its own disposition names. The two closest are
`modules/Window_Header.lua` (1371, re-check 1400) and `tests/test_schema.lua` (1381, re-check 1400).
`tests/test_aggregator.lua` (1437, re-check 1450) is the largest file in the band.

## Actions

1. `#54` (the `rosterBurst` single-shot reading) is still open on GitHub. This run is the first with
   the scenario on 300 iterations, so its issue can be ruled on with the next run as a like-for-like
   second reading. Closing it is the owner's call.

The three actions from `20261031-202021` are done: the three near-cap files are peeled, the two past
their re-check lines left the band, and `applyConfig`'s rise is traced.
