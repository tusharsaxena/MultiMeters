# Analysis — 20260916-094247

- **Addon:** MultiMeters 1.0.0
- **Verdict:** green
- **Commit:** c115ec06baa1 (master), clean
- **Previous run:** [`20260910-234511`](../20260910-234511/)

## Headline

Green on all four suites, with zero functions above CCN 15 and max CCN still pinned at exactly 15.
One hundred new cases (1748 → 1848) and 2159 more NLOC came in with the v1.37.0/v1.38.0 re-vendors,
the per-window Lock view, the Test mode row and the bare-`/mm` panel open. The band grew from 20
files to 23, and all three newcomers — `core/Database.lua`, `tests/test_options_panel.lua`,
`tests/test_slash.lua` — crossed by **growth**, not by a peel, which is the direction worth noticing;
each is ruled in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band). Nothing to act on before a tag.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260910-234511` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 123 files | [`lint.txt`](lint.txt) | +1 file, still 0/0 |
| tests | pass | 1848 passed, 0 skipped, 0 failed, 1848 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +100 passed |
| perf | pass | 15 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 39238 |
| Functions | 3984 |
| Avg NLOC / function | 8.2 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 63.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 23 |
| Files over the 1500 cap | 0 |

Every figure above is [`manifest.json`](manifest.json)'s `suites` block for this run, which records
all eight of `lizard`'s footer fields; nothing here is derived by hand. No suite was skipped —
`luacheck` 1.2.0, `lizard` 1.24.0 and Lua 5.1.5 were all present on the host, so all four suites
were measured rather than assumed.

## What moved

- **lint** — 122 → 123 files in scope, 0 warnings / 0 errors in both runs. The extra file is source
  the re-vendor cycle added, not a change in `.luacheckrc`'s exclusions, which still hold
  `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/` and `_dev/` out of scope.
- **tests** — 1748 → 1848 passed (+100), with 0 skipped and 0 failed in both runs. Passed and total
  agree, so no case is claiming coverage it did not exercise.
- **perf** — 15 scenarios in both runs, still the most of any addon in the collection. This is the
  offline scenario set from `tests/perf.lua`; it says nothing about in-game cost, which is
  `/wow-addon:perf-analysis`'s to capture.
- **complexity** — NLOC 37079 → 39238 (+2159) over 3777 → 3984 functions (+207). The averages are
  the signal and they barely moved: avg NLOC 8.1 → 8.2, avg CCN flat at 2.4, avg tokens 63.0 → 63.6.
  The addon got **bigger**, not denser. Max CCN 15 and zero warnings in both runs. Band files
  20 → 23, cap breaches 0 → 0.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on
every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

None. Max CCN is 15, which is the threshold itself and not over it, so the functions table is empty
by measurement. The release gate's second half — zero functions above CCN 15 — is satisfied at this
commit.

### Files by `layout-§1` band

23 file(s) in the 1000–1500 on-notice band, 0 over the 1500 cap. Three entered this cycle and each
arrived with a blank disposition, which has been ruled in
[`RESULTS.md`](../RESULTS.md#files-by-layout-1-band):

| Band | File | LOC | Arrived by |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database.lua` | 1008 | growth, 878 → 1008 |
| 1000–1500 (on notice) | `tests/test_options_panel.lua` | 1095 | growth, 928 → 1095 |
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1009 | growth, 787 → 1009 |

The band is not part of the release gate. The twenty carried-forward entries keep the dispositions
they were given, which are still true; none has yet been carried as Accepted across three
consecutive release runs, since 1.0.0 is the only release run in this record.

## Actions

1. `core/Database.lua` newly entered the band by growth (878 → 1008). Its mirror suite
   `tests/test_database.lua` is at 1470, 30 lines from the cap and the tightest pair in the
   repository after `modules/Row.lua` / `tests/test_row.lua`. If the migration runner is touched
   again, peel it to a sibling rather than adding to the file.
2. `tests/test_provider.lua` remains at exactly 1500 — on the cap, not over it. Unchanged from the
   previous run, and one case takes it into breach.
3. `tests/test_row.lua` moved 1456 → 1490 and `modules/Row.lua` 1446 → 1469; both are now inside
   30 lines of the cap and, per their standing dispositions, they peel together when they cross.
