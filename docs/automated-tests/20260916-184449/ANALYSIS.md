# Analysis — 20260916-184449

- **Addon:** MultiMeters 1.0.0
- **Verdict:** green
- **Commit:** 2d38bbd7633127e061f14daf1d29b714a9af8a33 (master), clean
- **Previous run:** [`20260916-094247`](../20260916-094247/)

## Headline

Green on all four suites — lint 0/0 over 123 files, 1884 of 1884 cases passed with nothing skipped,
15 perf scenarios recorded. The one thing that moved against the addon is complexity: `lizard` warns
on a function for the first time since `20260908-181355`, `NS.ValidateSchema` at CCN **19**, which
breaks a max-CCN of exactly 15 that had held across the last four runs. That fails nothing here —
complexity never gates a run or a commit — but it *is* the release gate (`automated-tests-§3`: all
four suites plus zero functions above CCN 15), so it is owed a fix before the next tag rather than
before the next commit.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260916-094247` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 123 files | [`lint.txt`](lint.txt) | unchanged at 0/0 over the same file count, over a changed file set |
| tests | pass | 1884 passed, 0 skipped, 0 failed, 1884 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +36 passed (1848 → 1884) |
| perf | pass | 15 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged at 15 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 15 → 19, warnings 0 → 1 |

| Metric | Value |
|---|---|
| Total NLOC | 39769 |
| Functions | 4040 |
| Avg NLOC / function | 8.2 |
| Avg CCN | 2.4 |
| Max CCN | 19 |
| Avg tokens / function | 63.5 |
| Warnings (CCN > 15) | 1 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 23 |
| Files over the 1500 cap | 0 |

Every figure above is [`manifest.json`](manifest.json)'s `suites` block for this run, which records
all eight of `lizard`'s footer fields, and each is reproduced verbatim in
[`complexity.txt`](complexity.txt)'s footer. Nothing here is derived by hand. **No suite was
skipped** — all four ran, all four are recorded, and nothing in this write-up stands in for a
measurement that was not taken.

Reading the complexity figures in full is the point, because totals and averages say different
things here. Total NLOC rose 39238 → 39769 (+531) and function count 3984 → 4040 (+56), which is the
addon getting **bigger**: the launcher adoption replaced `modules/Minimap.lua` with
`core/LauncherSetup.lua`, and the LibKa0s v1.39.0 re-vendor brought a Launcher major with it. The
averages did **not** follow — avg NLOC per function is flat at 8.2, avg CCN is flat at 2.4, and avg
tokens per function actually fell 63.6 → 63.5. So the body of code grew by about 1.3% without
getting denser, which is growth and not degradation. The single complexity signal in this run is the
outlier, not the population.

`NS.ValidateSchema` is the outlier, and it is **dense guarding rather than tangled control flow**.
[`complexity.txt`](complexity.txt) places it at `settings/Schema_Paths.lua:883-931` — 38 NLOC, 262
tokens, 0 parameters. It is one `for` loop over `NS.Schema` asking two questions per row (does the
path resolve, does the default agree), where each decision is a `nil` test, a `type(...) == "table"`
test or an `if out then` print guard. There is no nesting past the loop. `lizard` scores every
`and`/`or` short-circuit as a decision, and Lua validation code of this shape accumulates CCN
without accumulating branching a reader has to hold. What pushed it over was the extra arm the
launcher work added for the minimap path — the one row whose stored value is the inverse of what it
displays — and that arm is also the obvious seam back under 15. The ruling is recorded in
[`RESULTS.md`](../RESULTS.md#functions-lizard-warned-on).

## What moved

- **Against the previous run's commit** (`c115ec06` → `2d38bbd7`) there are fifteen commits, not one.
  The task's context names the last of them, `2d38bbd` — the `docs/ARCHITECTURE.md` Documentation map
  moving onto the standard's four canonical tables, with `tests/test_docmap.lua` updated to match (it
  reads `### Conditional`, anchored at a line start, and its row floor rose to 7). That commit is
  documentation and a test rewrite: it changed 22 lines of `tests/test_docmap.lua` and moved **no**
  case count — `test_docmap.lua`'s entry in [`test-cases.md`](test-cases.md) is identical in both
  bundles. The figures that moved came from the thirteen commits before it, chiefly the LibKa0s
  v1.39.0 re-vendor (`dfbb40e`) and the launcher adoption (`84e9ed3`).
- **tests: 1848 → 1884, +36 net**, and the composition is more interesting than the net. From the two
  bundles' inventories: `test_launchersetup.lua` is new at **38** cases, `test_minimap.lua` is gone
  at **-17**, `test_slash.lua` went 59 → **73** (+14) for `/mm enable` and `/mm disable`, and
  `test_options_panel.lua` went 42 → **43** (+1). No other suite's count moved, and no case reported
  a skip, so passed and total agree.
- **lint: 0/0 over 123 files, both runs.** The file count is flat by coincidence rather than by
  stillness — `modules/Minimap.lua` and `tests/test_minimap.lua` left, `core/LauncherSetup.lua` and
  `tests/test_launchersetup.lua` arrived. Scope is unchanged and stated below the table in
  [`RESULTS.md`](../RESULTS.md#lint).
- **perf: 15 scenarios, unchanged**, and the scenario names in [`perf.txt`](perf.txt) are the same
  fifteen as the previous run. Nothing was added to cover the launcher, which is defensible — it is
  an out-of-combat click path — but it is a fact worth stating rather than leaving silent.
- **complexity: max CCN 15 → 19, warnings 0 → 1.** This is the only threshold crossing in the run.
  Totals rose, averages did not (see above).
- **Band membership did not move: 23 files in 1000–1500, 0 over the 1500 cap, both runs** — and it is
  the same 23 files, only their line counts shifted. The largest single movers are
  `tests/test_slash.lua` (1009 → 1324) and `core/Database.lua` (1008 → 1090). The seven-suite
  over-cap deviation this repository retired on 2026-09-09 stays retired: nothing it tracks is over
  1500, and the closest entry, `tests/test_provider.lua` at 1500, is *on* the band's upper edge and
  therefore compliant, not in breach.

## Complexity watch list

Ruled in [`RESULTS.md`](../RESULTS.md#complexity-watch-list), which is where the dispositions live;
this section says what is new.

**Functions `lizard` warned on** — one, and it is new:

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `NS.ValidateSchema` | 19 | `settings/Schema_Paths.lua` | Accepted between releases; dense guarding, not tangle; owed before the next tag |

**Files by `layout-§1` band** — 23 entries, none of them new, none over cap. No file crossed into or
out of the band this run, so every disposition carried forward unchanged and there was nothing to
rule on. The full table with its per-file reasoning is in
[`RESULTS.md`](../RESULTS.md#files-by-layout-1-band).

On the shelf life of a disposition: this repository has produced **three** release runs in total —
`20260809-194203` and `20260809-195454` (0.1.0) and `20260910-234511` (1.0.0), per each bundle's
`manifest.json` `release` field. No entry on either table has been carried as *Accepted* across
three consecutive **release** runs, so nothing is yet owed the conversion into a tracked deviation
with an ID and an owner that `automated-tests-§4` requires. The band entries to watch when that
clock does start are the post-peel residue rows that have now appeared on three ordinary runs
running.

## Actions

1. **`settings/Schema_Paths.lua` — bring `NS.ValidateSchema` back under CCN 15 before the next
   version bump.** Lift the minimap arm (the `row.path == MINIMAP_PATH` branch, lines 892–909) into
   its own local predicate so the loop body has one shape again. This is new here and has no owner in
   the addon's tracking yet — no deviation ID, no open review finding — so it needs one if it is not
   fixed directly.
2. **Nothing else.** Lint, tests and perf are clean, the band is static, and no disposition has aged
   out.
