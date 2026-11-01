# Analysis — 20261101-202709

- **Addon:** MultiMeters 1.2.0
- **Verdict:** green
- **Commit:** a5de38b1a13c8f7e20b3004d666e3b0d807d0ed4 (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-145605

## Headline

All four suites pass on a clean tree, with no function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). This run measures the re-cut LibKa0s v1.85.0 and kit revision 50, with the kit's typed-value and skin-switch gates adopted (FS-MM-GATE).

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-145605 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 186 files | [`lint.txt`](lint.txt) | +1 file, `tests/skin_facts.lua` |
| tests | pass | 2532 passed, 1 skipped, 0 failed, 2533 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +48 cases |
| perf | pass | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `applyConfig` 25090.5 → 25092.1 bytes/iter; no other byte column moved in the table |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +575, functions +87 |

| Metric | Value |
|---|---|
| Total NLOC | 54400 |
| Functions | 5906 |
| Avg NLOC / function | 8.3 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 68.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 24 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The one skipped case is the kit contract case for an addon that opts out of the diagnostics default. This addon keeps the default, so it does not apply. The two skin suites are not skips: `Kit.skinValues` and `Kit.skinSwitch` are set.

## What moved

- **tests.** 2485 → 2533 cases: the two kit suites over `tests/skin_facts.lua`'s surfaces, and new cases for a skin's None, a real style, the stub's `BarBorder` and the titled menu. Pins that read a bar family row's `disabledIf` as a string now read a function.
- **perf.** No scenario's bytes moved beyond `applyConfig`'s 1.6 per iteration, under its ceiling. The menu, the icon edge and `S.BarBorder` are off the refresh path.
- **complexity.** Average CCN holds at 2.5 and max at 15. NLOC rose with the vendored library and the new tests.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

One new row: `tests/test_tooltip_lines.lua`, 1011. Its Disposition is written in [`../RESULTS.md`](../RESULTS.md). `modules/Window_Header.lua` is at 1453, 47 lines under the cap.

## Actions

1. `modules/Window_Header.lua` needs a peel before its next growth: 47 lines of headroom.
2. In-client: SKIN-28 to SKIN-40 and the re-opened checks are the owner's to run.
