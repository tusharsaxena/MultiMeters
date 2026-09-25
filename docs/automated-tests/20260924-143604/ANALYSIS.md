# Analysis — 20260924-143604

- **Addon:** MultiMeters 1.0.0
- **Verdict:** green
- **Commit:** ace15be (feat/2026-09-23-review-audit-remediation), clean
- **Previous run:** [`20260916-184449`](../20260916-184449/)

## Headline

Green on all four suites: lint 0/0 over 132 files, 2030 of 2030 cases passed with nothing skipped,
17 perf scenarios recorded, and **zero** functions above CCN 15. The previous run's one release
blocker, `NS.ValidateSchema` at CCN 19, is gone (CCN 7 now), so this tree meets the tag's
four-suites-plus-zero-warnings bar. This run is not a release run and no tag is proposed; the owner
decides the version (MM-31 names 1.1.0). One thing needs action: `modules/Window.lua` stands at 1490
lines, ten short of the cap, and its disposition is now "peel before the next line-adding change".

## Suites

| Suite | Status | Result | Artifact | Moved since `20260916-184449` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 132 files | [`lint.txt`](lint.txt) | unchanged at 0/0; files 123 → 132 |
| tests | pass | 2030 passed, 0 skipped, 0 failed, 2030 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +146 passed (1884 → 2030) |
| perf | pass | 17 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 15 → 17 scenarios (`spellEventOff`, `spellEventOn` new) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 19 → 15, warnings 1 → 0 |

| Metric | Value |
|---|---|
| Total NLOC | 42299 |
| Functions | 4307 |
| Avg NLOC / function | 8.2 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 63.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 24 |
| Files over the 1500 cap | 0 |

Every figure above comes from [`manifest.json`](manifest.json)'s `suites` block for this run, and the
complexity rows match the footer of [`complexity.txt`](complexity.txt) exactly. **No suite was
skipped.** All four ran, and nothing here stands in for a measurement that was not taken.

All four suites passed cleanly, so no per-suite failure paragraph is owed. The totals grew and the
averages did not: NLOC 39769 → 42299 (+2530) and functions 4040 → 4307 (+267), while avg NLOC per
function held at 8.2, avg CCN at 2.4, and avg tokens went 63.5 → 63.6. The addon got bigger without
getting denser. `libs/` and `tests/_kit/` are outside this measurement, so the growth is the
2026-09-23 remediation's own suites and seams, not the re-vendored kit.

## What moved

- **Commits.** `2d38bbd` → `ace15be` is 76 commits: the LibKa0s v1.56.0 / kit revision 26
  re-vendor (`fca380b`), items MM-00 to MM-31 of the 2026-09-23 remediation plan, and this item's
  two doc commits (`8f7d1fd`, `ace15be`). The previous row has no Commit cell. This run is the first
  with one, and the runner carried the nine earlier rows forward as `unknown`.
- **tests: 1884 → 2030, +146.** The two bundles' inventories agree on where it came from. There are
  new suites: `test_disabled.lua` (22), `test_prose.lua` (15, the kit's), `test_schema_batch.lua`
  (13), `test_migrations.lua` (8), `test_slash_refusal.lua` (5) and `test_row_cells.lua` (1).
  `test_provider.lua` was peeled 78 → 41 into `test_provider_recap.lua` (26) and
  `test_provider_fields.lua` (11), which is +0 net for those cases. The kit's own
  `test_layout_cap.lua` went 3 → 13. The largest in-repo growth is `test_degraded.lua` +8,
  `test_schema_defaults.lua` +8, `test_compat.lua` +6 and `test_window.lua` +6. No case reported a
  skip, and `docs/test-cases.md` is byte-identical to this bundle's [`test-cases.md`](test-cases.md).
- **lint: 0/0, and 123 → 132 files.** Ten files arrived and one left. The ten are
  `core/LifecycleSetup.lua`, `modules/Row_Cells.lua`, `tests/prose_waivers.lua` and the seven new
  in-repo suites listed above. The one that left is the hand-written `tests/test_layout_cap.lua`,
  whose gate is the kit's now. The scope is unchanged and is stated under the table in
  [`RESULTS.md`](../RESULTS.md#lint).
- **perf: 15 → 17 scenarios.** The two new ones are `spellEventOff` and `spellEventOn` (0.00020 /
  0.00038 ms/iter). Per [`perf.json`](perf.json) against the previous bundle's, the steady-state
  scenarios are all faster and lighter. `refresh20x7` went 0.97824 → 0.78952 ms/iter and
  303438.1 → 297237.4 B/iter. `refresh20x7Restricted` went 1.25598 → 0.93760 ms and `rosterRebuild`
  went 1.03637 → 0.64547 ms. `refreshWhileDrilled` went 0.10410 → 0.05048 ms and
  19906.2 → 16170.1 B. `suspended` went from 5202.3 B/iter to 0.0, which was the figure finding
  MultiMeters-A-26 called stale. The header in [`perf.txt`](perf.txt) now reads `v1.0.0` where the
  previous one read `v0.1.0`. The one scenario that went the other way is `rosterBurst`,
  1.783 → 6.095 ms. It is a **single-iteration** scenario (`iters` 1), and its bytes fell
  323151 → 316951, so this reads as one timer sample rather than a regression. `throttleBurst`, the
  other single-shot scenario, fell 22.347 → 15.334 ms in the same run. Worth a second look only if
  the next run repeats it. The in-client render gain from MM-20 is recorded separately in
  `docs/perf-analysis/20260924-133043/` and `20260924-141756/`.
- **complexity: max CCN 19 → 15, warnings 1 → 0.** `NS.ValidateSchema` is at CCN 7,
  `settings/Schema_Paths.lua:834-851` (15 NLOC, 98 tokens), after the `LibKa0s-Schema-1.0` adoption
  (MM-14) took the minimap arm out of it. Eleven functions sit at exactly 15 per
  [`complexity.txt`](complexity.txt). None is over, and they are the population to watch.
- **Band: 23 → 24 files, 0 over the cap.** Two joined: `locales/enUS.lua` (990 → 1039) and
  `tests/test_schema_paths.lua` (991 → 1001). One left: `tests/test_provider.lua`, peeled by MM-23.
  Two band files crossed their own re-check lines this run: `modules/Window.lua` 1423 → 1490 (past
  1470) and `settings/Schema_Compose.lua` 1375 → 1410 (past 1400).

## Complexity watch list

The dispositions are recorded in [`RESULTS.md`](../RESULTS.md#complexity-watch-list). This section
covers only what is new.

**Functions `lizard` warned on:** None.

**Files by `layout-§1` band:** 24 entries, none over the cap. Four were ruled this run and the
other twenty carry forward:

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Window.lua` | 1490 | Past its 1470 re-check. Peel `Bus wiring` + `Lifecycle` (outside issue #29's chain) before the next line-adding change |
| 1000–1500 (on notice) | `settings/Schema_Compose.lua` | 1410 | Past its 1400 re-check by the MM-14 adoption; grows by control kind; re-check at 1470 |
| 1000–1500 (on notice) | `locales/enUS.lua` | 1039 | New; a flat string table grown by the remediation's `NS.L` routing; re-check at 1300 |
| 1000–1500 (on notice) | `tests/test_schema_paths.lua` | 1001 | New; grew by the MM-14 adoption while its module shrank; re-check at 1300 |

Three carried entries already sat past their own re-check lines at the previous run and did not move
here: `tests/test_row.lua` at 1490 (re-check 1470), `tests/test_window_header.lua` at 1494 (1470) and
`tests/test_database.lua` at 1470 (1200). Their dispositions stand, but the trigger each one wrote
has fired, and item 2 below asks for a ruling. No release run has happened since `20260910-234511`,
so no entry has been *Accepted* across three consecutive release runs.

## Actions

1. `modules/Window.lua`: before the next change that adds lines to it, peel the `Bus wiring` and
   `Lifecycle` sections into a sibling on `NS.WindowProto` (TOC right after `modules\Window.lua`,
   load-bearing). This is new here, and no issue tracks it yet.
2. `tests/test_row.lua`, `tests/test_window_header.lua`, `tests/test_database.lua`: each is past
   the re-check line its own disposition set. Either re-rule each one in `RESULTS.md` or peel it
   along the seam its disposition names (the sort-arrow ladder for the header suite; `test_row`
   peels together with `modules/Row.lua`). New here.
3. `rosterBurst`: if the next run repeats the single-shot 6 ms reading, look at it. Otherwise
   nothing to do.
