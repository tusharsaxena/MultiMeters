# Automated test results

<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->
<!-- Everything here is generated EXCEPT the watch list's Disposition column. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

The **Tests** cell reads `passed/skipped/total`.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260909-120608`](20260909-120608/) | 0.1.0 | 0/0 | 122 | 1728/0/1728 | pass | 36689 | 3752 | 8.1 | 2.4 | 15 | 0 | **green** |
| [`20260908-181355`](20260908-181355/) | 0.1.0 | 0/0 | 93 | 1530/0/1530 | pass | 32913 | 3337 | 8.2 | 2.6 | 34 | 23 | **green** |
| [`20260825-103437`](20260825-103437/) | 0.1.0 | 0/0 | 47 | 1257/1257 | fail | 26531 | 2884 | 7.7 | 2.5 | 31 | 19 | **amber** |
| [`20260825-021705`](20260825-021705/) | 0.1.0 | 0/0 | 46 | 1246/1246 | fail | 26457 | 2867 | 7.7 | 2.5 | 31 | 19 | **amber** |
| [`20260809-195454`](20260809-195454/) | 0.1.0 | 0/0 | 40 | 676/676 | pass | 15173 | 1677 | 7.3 | 2.4 | 15 | 0 | **green** |
| [`20260809-194203`](20260809-194203/) | 0.1.0 | 0/0 | 40 | 676/676 | pass | 15005 | 1627 | 7.4 | 2.4 | 41 | 13 | **green** |

## Test suite

**1728 cases** — 1728 passed, 0 failed, 0 skipped. The generated inventory
[`20260909-120608/test-cases.md`](20260909-120608/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **1530 → 1728** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 122 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` sets `exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "_dev/" }`, so those paths
are not in it. A `0/0` that never moves is partly a statement about what was never looked at, which
is why the exclusion is restated on every run.

## Perf

**15 scenarios** from `tests/perf.lua`; the measurements are in
[`20260909-120608/perf.json`](20260909-120608/perf.json).

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20260909-120608`](20260909-120608/) — **this run's measurement, not its diff.** Max CCN **15** across 3752
functions, **0** of them warned on; 19 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Aggregator.lua` | 1331 |**On notice, post-peel residue.** 2122 → 1331 on 2026-09-09; identity mode and the correlation rectangle left for `Aggregator_Identity.lua` / `_Preview.lua`. What is left is the build pipeline, which its own header narrates in the order the code runs it and which must not be cut inside. Re-check at 1450. |
| 1000–1500 (on notice) | `modules/Row.lua` | 1442 |**On notice — the one to watch.** 1829 → 1442 after the name cell left for `Row_NameCell.lua`, and 58 lines of headroom is the tightest of any source file. It is on the refresh path and it is where every identity, spec-icon and pet-fold change has historically landed. The next seam is the value cell, which is already the largest block in it. Re-check at 1470, or on the next change that touches the cell. |
| 1000–1500 (on notice) | `modules/Tooltip.lua` | 1167 |**On notice, post-peel residue.** 2774 → 1167; the four builders and the line drawing left for `Tooltip_Builders.lua` / `Tooltip_Lines.lua`. What remains is the secret-safe primitives, which is the half that must not be touched casually — 333 lines of headroom is ample for a file nothing routinely adds to. Re-check at 1400. |
| 1000–1500 (on notice) | `modules/Tooltip_Builders.lua` | 1030 |**On notice at birth**, which a peel makes ordinary: it landed at 1030 because the seam was drawn for what a reader can hold, not at a line count. It is the half a feature adds to, so it is the likelier of the pair to grow. Re-check at 1400. |
| 1000–1500 (on notice) | `modules/Window.lua` | 1418 |**On notice, post-peel residue.** 2746 → 1418; the header band and placement left for `Window_Header.lua` / `Window_Placement.lua`. What is left is one causal chain — refresh contract, rule R3, cached config, frame construction, row pool, refresh — and splitting it would put a reader on two files to follow one frame. Second-tightest source file at 82 lines. Re-check at 1470. |
| 1000–1500 (on notice) | `modules/Window_Header.lua` | 1184 |**On notice at birth.** 1184 from the peel. It has an obvious further seam if it ever needs one — the column-header buttons and the sort-arrow ladder are a coherent ~500 lines — so this file has an answer ready rather than a problem. Re-check at 1400. |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1350 |**On notice, post-peel residue.** 3080 → 1350 across three files. This is the row array alone, and it is the part that grows: a page gains rows every time a setting is added. It is the band entry most likely to cross by ordinary work. The next cut is a page boundary, which the peel deliberately left available by not splitting one. Re-check at 1450. |
| 1000–1500 (on notice) | `settings/Schema_Compose.lua` | 1288 |**On notice at birth.** 1288 — the vocabularies, validators, composers and the twelve composed blocks. It grows with new *kinds* of control rather than with new settings, so it moves far more slowly than `Schema.lua` beside it. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_aggregator.lua` | 1255 |**On notice.** 1840 → 1255 behind its module's peel. It was in the band before the peel too. Re-check at 1450. |
| 1000–1500 (on notice) | `tests/test_database.lua` | 1263 | **On notice, and that is the compliant state** under `layout-§1` — a band entry is not a breach. Four lines over the line. It mirrors `core/Database.lua`, which is under the cap, so it has no seam waiting on anything. Re-check at 1200. |
| 1000–1500 (on notice) | `tests/test_export.lua` | 1275 |**On notice.** 1892 → 1275 behind the modal peel, and in the band before it as well. Re-check at 1450. |
| 1000–1500 (on notice) | `tests/test_headercontrols.lua` | 1159 |**On notice, and untouched by this cycle** — 1159, no peel, no growth. It mirrors `modules/HeaderControls.lua`, which is under the cap. Named here so the band reads as measured rather than as a list of things the peel produced. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_provider.lua` | 1359 | **On notice.** The larger of the two band files and the one closer to the cap. It mirrors `modules/Provider.lua`, which is under the cap; if it crosses 1500 it takes an issue of its own rather than joining a module's peel, because there is no module peel for it to join. Re-check at 1450. |
| 1000–1500 (on notice) | `tests/test_row.lua` | 1456 |**On notice.** 1960 → 1456 behind the name-cell peel — 44 lines of headroom, second-tightest in the repo, and it mirrors the source file with the tightest. The two will cross together, and they peel together when they do. Re-check at 1470. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1098 |**On notice.** 1573 → 1098 behind the path-machinery peel; the only suite this cycle took *out* of breach and well clear now. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_tooltip_deaths.lua` | 1391 |**On notice at birth.** 1391, the largest of the four files `tests/test_tooltip.lua` became, and deliberately so: the death-event block is one coherent subject (issue #1) and splitting it further would stop mirroring the module. Re-check at 1470. |
| 1000–1500 (on notice) | `tests/test_window.lua` | 1240 |**On notice.** 3159 → 1240 across three suites, the largest single reduction in the repository. Re-check at 1450. |
| 1000–1500 (on notice) | `tests/test_window_header.lua` | 1421 |**On notice at birth.** 1421 — the biggest of the three files `tests/test_window.lua` became, because the header band is where most of that suite's cases were. It has the same further seam its module has (the sort-arrow ladder) if it needs one. Re-check at 1470. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1466 |**On notice — tightest in the repository at 34 lines.** 2270 → 1466 with the secret simulator and the frame model out to `mock_secrets.lua` / `mock_frame.lua`. It is not a suite; every one of the 60 suites runs against it, so it is also the file where a mistake is a whole-repo red. The peel left it as the builder the kit's README describes, and the next thing added to it should probably go to a third sibling instead. Re-check at 1480. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

