# Analysis — 20261101-025831

- **Addon:** MultiMeters 1.2.0 (final pre-merge run, `manifest.json` → `"label": "final-pre-merge"`, not a release run)
- **Verdict:** green
- **Commit:** c9c4ab1 (feat/2026-10-31-findings-remediation), clean
- **Previous run:** [`20261101-000911`](../20261101-000911/)

## Headline

All four suites passed on the branch's final tree, which takes the re-cut LibKa0s v1.84.0 and makes
`Ka0sMedia_*` the only media picker. Lint is 0/0 over 183 files, 2450 of 2451 cases passed with the
same one declared skip and none failed, 18 perf scenarios were recorded, and no function is above
CCN 15 with `blindFiles` and `crashedFiles` both 0. The case count moved by one and NLOC by 7; perf
timing rose on all but one of the 18 scenarios, but `api/iter` and `bytes/iter` are identical on
all 18. There is nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261101-000911` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 183 files | [`lint.txt`](lint.txt) | not moved |
| tests | pass | 2450 passed, 1 skipped, 0 failed, 2451 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +1 case, net of one removed and two added |
| perf | pass | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 18; `api/iter` and `bytes/iter` identical; timing only |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +7, functions -1; every other figure unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 52838 |
| Functions | 5718 |
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
report and leaves logging off` ([`tests.txt`](tests.txt), line 2440). This addon keeps the default, so
the case does not apply. It is a pre-existing condition, counted in the total and in neither passed
nor failed.

## What moved

Compared with the previous bundle's `manifest.json`, `perf.txt` and `test-cases.md`.

- **lint.** Did not move: 0/0 over 183 files.
- **tests.** 2450 → 2451 cases, 2449 → 2450 passed, 1 skipped, 0 failed. [`test-cases.md`](test-cases.md)
  shows one case gone from `test_options_panel.lua`, `Options: the shared LSM30_Border slot is
  re-registered once, above what AGSMW left in it`, and two added, `Options: every media row asks for a
  Ka0sMedia_* picker, the two broadcast rows included` and `Options: AceGUI-3.0-SharedMediaWidgets is
  gone from the load, the disk and the wiring`. That file goes 36 → 37 and no other file's count
  changed. This ends the flat run of 2450 that the previous two records flagged.
- **perf.** All 18 scenarios are shared. `api/iter` and `bytes/iter` are identical on every one
  ([`perf.txt`](perf.txt)), so the media change and the re-cut library allocate and call exactly as
  before on these paths. Timing rose almost across the board: `refresh20x7` 0.80213 → 1.21587,
  `refresh20x7Restricted` 1.05381 → 1.58669, `throttleBurst` 14.50500 → 28.31800, `rosterBurst`
  0.80277 → 1.05026 and `applyConfig` 0.51705 → 0.62114, with `spellEventOff` 0.00022 → 0.00021 the
  one decrease. The other suites slowed too (`manifest.json` → tests `durationMs` 31602 → 44793), and
  `throttleBurst` is a single iteration. With the counters still, this reads as load difference
  between two runs and is claimed as neither a gain nor a loss.
- **complexity.** NLOC 52831 → 52838, functions 5719 → 5718. Avg NLOC 8.4, avg CCN 2.5, avg tokens
  68.8, max CCN 15 and warnings 0 are unchanged, so this is not a density signal.
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
