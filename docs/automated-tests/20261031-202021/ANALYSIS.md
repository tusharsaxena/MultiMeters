# Analysis — 20261031-202021

- **Addon:** MultiMeters 1.2.0 (pre-merge run, `manifest.json` → `"label": "pre-merge"`, not a release run)
- **Verdict:** green
- **Commit:** 0d603a4 (feat/2026-10-31-font-pickers-skin-faces), clean
- **Previous run:** [`20261009-191721`](../20261009-191721/)

## Headline

All four suites passed. Lint is 0/0 over 178 files, 2449 of 2450 cases passed with the same one
declared skip and none failed, 18 perf scenarios were recorded, and no function is above CCN 15 with
`blindFiles` and `crashedFiles` both 0. Nothing is over the 1500 cap, so the CCN and NLOC watch needs
no code change. Five band files are past their recorded re-check lines, and `settings/Schema.lua` is
now 27 lines under the cap, which is the thing to plan for.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261009-191721` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 178 files | [`lint.txt`](lint.txt) | still 0/0; 146 → 178 files |
| tests | pass | 2449 passed, 1 skipped, 0 failed, 2450 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2197 → 2450 total; skipped stays 1 |
| perf | pass | 18 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 18; `api/iter` identical; `bytes/iter` moved on `applyConfig` only |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC and functions up; avg CCN unchanged, avg tokens up a little |

| Metric | Value |
|---|---|
| Total NLOC | 52646 |
| Functions | 5713 |
| Avg NLOC / function | 8.4 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 68.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 24 |
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

The run measures 103 commits past the previous run's `b3c8b4f`.

- **lint.** 0/0, as before. The file count went 146 → 178 with new suites and modules.
- **tests.** 2197 → 2450 cases, 253 more, with 0 failed. The single skip is the same kit contract
  case.
- **perf.** All 18 scenarios are shared with the previous run, and `api/iter` is identical on every
  one. `bytes/iter` is identical on 17. `applyConfig` is the exception: 46232.3 → 63874.5 bytes/iter
  and 0.25980 → 0.48738 ms/iter ([`perf.json`](perf.json), `buckets`). The allocation rise is a real
  reading rather than machine load, because the other figures held still. This run did not trace its
  cause. `applyConfig` is a settings-change path and not per-frame, so it is recorded for reading
  here. `rosterBurst` went 17.876 → 1.156 ms over a single iteration; issue #54 is about that
  single-shot reading and is still open, so one low sample does not settle it.
- **complexity.** NLOC 45504 → 52646, functions 4913 → 5713, avg tokens 68.3 → 68.8. Avg NLOC stays
  8.4, avg CCN stays 2.5, max CCN stays 15 and warnings stay 0. The addon grew and did not get denser.
- **band.** 23 → 24 files. `modules/Window.lua` left the band (1330 at the previous run, 414 now,
  after MM-04 split it into `Window_Frame` and `Window_Render`). `tests/test_launchersetup.lua` (1074)
  and `tests/test_database_migrations.lua` (1000) entered it. The largest risers are
  `core/Database.lua` (1159 → 1387), `tests/test_options_panel.lua` (1223 → 1402), `locales/enUS.lua`
  (1061 → 1236), `modules/Window_Header.lua` (1232 → 1370) and `tests/test_window_header.lua`
  (1177 → 1314). No file is over the cap.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_database_migrations.lua` | 1000 | **On notice, newly crossed by growth.** 981 → 1000 with the case count unchanged at 48: MM-A1's v21 reset widened existing cases. One coherent subject, the migration walk in `core/Database.lua`, so the size is case count rather than tangle. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_launchersetup.lua` | 1074 | **On notice, newly crossed by growth.** 922 → 1074, 50 → 56 cases: MM-02's Show window binding cases (+127) and MM-KB's section. It pins `core/LauncherSetup.lua` (364) through the real slash verbs, so the size is case count rather than tangle. Re-check at 1300. |

Those are the only two new rows. The other 22 dispositions in [`../RESULTS.md`](../RESULTS.md) carry
forward unchanged. None of the 24 is marked **Accepted**, so no entry is on the three-release shelf
life (anti-pattern #53).

Five carried rows are past the re-check line their own disposition names:

| File | LOC | Re-check | Room under 1500 |
|---|---|---|---|
| `settings/Schema.lua` | 1473 | 1450 | 27 |
| `settings/Schema_Compose.lua` | 1470 | 1470 | 30 |
| `tests/test_window.lua` | 1472 | 1450 | 28 |
| `tests/test_options_panel.lua` | 1402 | 1400 | 98 |
| `core/Database.lua` | 1387 | 1200 | 113 |

## Actions

1. `settings/Schema.lua`, `settings/Schema_Compose.lua` and `tests/test_window.lua` are each within
   30 lines of the cap. Each needs a peel or a fresh re-check before the next feature lands in it.
   New here; no issue tracks them.
2. `core/Database.lua` and `tests/test_options_panel.lua` are past their re-check lines with room
   left. Their dispositions need re-ruling at the next pass. New here; no issue tracks them.
3. `applyConfig`'s rise in `bytes/iter` needs a read of what the settings pass now allocates. New
   here; no issue tracks it.
