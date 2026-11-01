# Analysis — 20261101-145605

- **Addon:** MultiMeters 1.2.0
- **Verdict:** green
- **Commit:** f950fcd37810e50e4b0a28a91383de5e796278ed (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-025831

## Headline

All four suites pass on a clean tree, with no function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). This run measures LibKa0s v1.85.0 with the addon's half of the full skinning run (FS-MM-RV, FS-MM-FLIP, FS-MM-FIX). An earlier run of the same day was discarded uncommitted: it measured `followSkinOnce`, `ApplyColumnHeaders` and `ApplyConfig` at CCN 17, 24 and 16, which the second FS-MM-FIX commit took back under 15.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-025831 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 185 files | [`lint.txt`](lint.txt) | +2 files, `tests/test_skin_flip.lua` and `tests/test_skin_fix.lua` |
| tests | pass | 2484 passed, 1 skipped, 0 failed, 2485 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +34 cases |
| perf | pass | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `applyConfig` bytes down, the rest unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +987, functions +101 |

| Metric | Value |
|---|---|
| Total NLOC | 53825 |
| Functions | 5819 |
| Avg NLOC / function | 8.4 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 69.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 23 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The one skipped case is the kit contract case `diagnostics contract: an addon that opts out lands the report and leaves logging off`. This addon keeps the default, so it does not apply.

## What moved

- **tests.** 2451 → 2485 cases. New suites: `test_skin_flip.lua` and `test_skin_fix.lua`, plus the kit's own growth at revision 49. Earlier cases that set a swatch now set its companion off, and the v17 and v22 ladder cases seed the record, so each stays about its own subject.
- **perf.** `applyConfig` 26194.5 → 25090.5 bytes/iter, under the 27100 ceiling, which did not move. The rise a first run showed (29267) was this harness's: `tests/mock_frame.lua` built a table for every `SetShadowOffset` and `SetShadowColor`, and `S.HudFont` writes both on every string of every pass. The two records are recycled now, as SetPoint's are; the client's C setters allocate nothing. The drop against the previous run comes from the same recycling. Every `api/iter` is unchanged, and the refresh path's bytes are unchanged.
- **complexity.** Max CCN 15, no warning. `S.HudFont`'s opts are one table refilled per call (`NS.SkinHudFont`).

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

One new row: `core/Database_Migrations.lua`, 1050, crossed by the v23 step. Its Disposition is written in [`../RESULTS.md`](../RESULTS.md). `modules/Window_Header.lua` is at 1444, 56 lines under the cap, the band's tightest file after `tests/test_aggregator.lua`.

## Look changes the host owes in its report

The host carries strip and Sim (LibKa0s `docs/releasing.md` Step 8 for v1.85.0): the Sim steps panel's title band is 30 high, an owned tooltip title takes `gtip.title`, and an owned strip's icon takes `icon.tint`. Under Ka0s Default the meter window also gains the faint column band, the icon border and a centered title, each listed in `docs/smoke-tests.md` SKIN-28.

## Actions

1. `modules/Window_Header.lua` needs a peel before its next growth: 56 lines of headroom.
2. In-client: SKIN-28 to SKIN-37 and the nine re-opened checks are the owner's to run.
