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

**Commit** is the short sha the run measured and **Tree** is whether that tree was clean at the
time. Both are read from git by the runner; neither is ever typed. A **dirty** row measured bytes
that no sha can bring back, so it is kept as an experiment honestly labeled rather than dropped —
and a release record is refused outright on a dirty tree, so no release row can be one.

A row reading `unknown` in both cells was recorded before the runner emitted them. That is what
the record holds about those runs — it is not `clean`, and it is not reconstructed from git
archaeology, for the same reason a skip is never a pass (`automated-tests-§4`).

| Run | Commit | Tree | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260926-160431`](20260926-160431/) | `c125001` | clean | 1.0.1 | 0/0 | 141 | 2092/0/2092 | pass | 43815 | 4459 | 8.2 | 2.4 | 15 | 0 | **green** |
| [`20260924-163600`](20260924-163600/) | `a77688a` | clean | 1.0.0 | 0/0 | 137 | 2035/0/2035 | pass | 42513 | 4319 | 8.2 | 2.4 | 15 | 0 | **green** |
| [`20260924-143604`](20260924-143604/) | `ace15be` | clean | 1.0.0 | 0/0 | 132 | 2030/0/2030 | pass | 42299 | 4307 | 8.2 | 2.4 | 15 | 0 | **green** |
| [`20260916-184449`](20260916-184449/) | unknown | unknown | 1.0.0 | 0/0 | 123 | 1884/0/1884 | pass | 39769 | 4040 | 8.2 | 2.4 | 19 | 1 | **green** |
| [`20260916-094247`](20260916-094247/) | unknown | unknown | 1.0.0 | 0/0 | 123 | 1848/0/1848 | pass | 39238 | 3984 | 8.2 | 2.4 | 15 | 0 | **green** |
| [`20260910-234511`](20260910-234511/) | unknown | unknown | 0.1.0 → 1.0.0 | 0/0 | 122 | 1748/0/1748 | pass | 37079 | 3777 | 8.1 | 2.4 | 15 | 0 | **green** |
| [`20260909-120608`](20260909-120608/) | unknown | unknown | 0.1.0 | 0/0 | 122 | 1728/0/1728 | pass | 36689 | 3752 | 8.1 | 2.4 | 15 | 0 | **green** |
| [`20260908-181355`](20260908-181355/) | unknown | unknown | 0.1.0 | 0/0 | 93 | 1530/0/1530 | pass | 32913 | 3337 | 8.2 | 2.6 | 34 | 23 | **green** |
| [`20260825-103437`](20260825-103437/) | unknown | unknown | 0.1.0 | 0/0 | 47 | 1257/1257 | fail | 26531 | 2884 | 7.7 | 2.5 | 31 | 19 | **amber** |
| [`20260825-021705`](20260825-021705/) | unknown | unknown | 0.1.0 | 0/0 | 46 | 1246/1246 | fail | 26457 | 2867 | 7.7 | 2.5 | 31 | 19 | **amber** |
| [`20260809-195454`](20260809-195454/) | unknown | unknown | 0.1.0 | 0/0 | 40 | 676/676 | pass | 15173 | 1677 | 7.3 | 2.4 | 15 | 0 | **green** |
| [`20260809-194203`](20260809-194203/) | unknown | unknown | 0.1.0 | 0/0 | 40 | 676/676 | pass | 15005 | 1627 | 7.4 | 2.4 | 41 | 13 | **green** |

## Test suite

**2092 cases** — 2092 passed, 0 failed, 0 skipped. The generated inventory
[`20260926-160431/test-cases.md`](20260926-160431/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **2035 → 2092** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 141 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 5 path(s) from it — `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`, `_dev/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**17 scenarios** from `tests/perf.lua`; the measurements are in
[`20260926-160431/perf.json`](20260926-160431/perf.json).

| `scenario` | `iters` | `ms/iter` | `api/iter` | `bytes/iter` |
|---|---|---|---|---|
| `refresh20x7` | 300 | 0.99861 | 8.00 | 297237.4 |
| `refresh20x7Restricted` | 300 | 1.14829 | 8.00 | 406173.3 |
| `throttleBurst` | 1 | 21.18900 | 8.00 | 317269.0 |
| `throttleIdle` | 300 | 0.00102 | 0.00 | 0.0 |
| `drillOpenClose` | 300 | 0.03538 | 1.00 | 12746.2 |
| `refreshWhileDrilled` | 300 | 0.09676 | 1.00 | 16170.1 |
| `rosterRebuild` | 300 | 0.87326 | 8.00 | 315144.1 |
| `rosterBurst` | 1 | 13.61400 | 8.00 | 316951.0 |
| `rosterCached` | 300 | 0.74285 | 8.00 | 297216.1 |
| `applyConfig` | 300 | 0.17340 | 0.00 | 46232.3 |
| `probeOverheadOff` | 300 | 0.70254 | 8.00 | 297216.1 |
| `probeOverheadOn` | 300 | 0.75187 | 8.00 | 297220.9 |
| `suspended` | 300 | 0.00022 | 0.00 | 0.0 |
| `feignTraceAbsent` | 300 | 0.19493 | 2.00 | 65344.1 |
| `feignTraceOff` | 300 | 0.17894 | 2.00 | 65344.1 |
| `spellEventOff` | 300 | 0.00035 | 0.00 | 0.0 |
| `spellEventOn` | 300 | 0.00068 | 0.00 | 0.7 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20260926-160431`](20260926-160431/) — **this run's measurement, not its diff.** Max CCN **15** across 4459
functions, **0** of them warned on; 23 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database.lua` | 1159 | **On notice, newly crossed, and it arrived by growth rather than by a peel.** 878 lines at the previous run's commit, 1008 now — the per-window lock view and the test-mode work both landed in the window registry's shape and the migration runner. It is dense *defaulting and guarding*, not tangled control flow: `EnsureWindowShape` key-fills an array AceDB's merge cannot reach, one `== nil` test per key, which is why nothing in it warns at CCN. Its suite `tests/test_database.lua` is already at 1470. The seam, if it needs one, is the migration runner leaving for a sibling. Re-check at 1200. |
| 1000–1500 (on notice) | `locales/enUS.lua` | 1056 | **On notice, newly crossed by growth, and it is a flat table rather than code.** 990 lines at the previous run's commit, 1039 now: the 2026-09-23 remediation routed every user-facing slash line through `NS.L` with a plural (MM-22), named unknown windows and empty renames (MM-06), the chat-sender refusal (MM-04) and the enable/disable wording (MM-15). One `L[...]` key per line and no control flow, so its size is the addon's string count, not tangle; `layout-§1` still binds it. The seam, if it needs one, is a second locale file for the diagnostics and debug-console strings, which no player-facing path reads. Re-check at 1300. |
| 1000–1500 (on notice) | `modules/Aggregator.lua` | 1432 | **On notice, post-peel residue.** 2122 → 1331 on 2026-09-09; identity mode and the correlation rectangle left for `Aggregator_Identity.lua` / `_Preview.lua`. What is left is the build pipeline, which its own header narrates in the order the code runs it and which must not be cut inside. Re-check at 1450. |
| 1000–1500 (on notice) | `modules/Provider.lua` | 1084 | **On notice, newly crossed, and it is the only entry here that arrived by growth rather than by a peel.** 924 lines at the previous run's commit, 1056 now — the roster/spec identity work. Every other band file in this repository is post-peel residue settling; this one is a module getting bigger, which is the direction that matters. Its suite `tests/test_provider.lua` is at 1500, exactly on the cap. Re-check both at 1200 / 1500. |
| 1000–1500 (on notice) | `modules/Row.lua` | 1446 | **On notice — the one to watch.** 1829 → 1442 after the name cell left for `Row_NameCell.lua`, and 58 lines of headroom is the tightest of any source file. It is on the refresh path and it is where every identity, spec-icon and pet-fold change has historically landed. The next seam is the value cell, which is already the largest block in it. Re-check at 1470, or on the next change that touches the cell. |
| 1000–1500 (on notice) | `modules/Tooltip.lua` | 1167 | **On notice, post-peel residue.** 2774 → 1167; the four builders and the line drawing left for `Tooltip_Builders.lua` / `Tooltip_Lines.lua`. What remains is the secret-safe primitives, which is the half that must not be touched casually — 333 lines of headroom is ample for a file nothing routinely adds to. Re-check at 1400. |
| 1000–1500 (on notice) | `modules/Tooltip_Builders.lua` | 1033 | **On notice at birth**, which a peel makes ordinary: it landed at 1030 because the seam was drawn for what a reader can hold, not at a line count. It is the half a feature adds to, so it is the likelier of the pair to grow. Re-check at 1400. |
| 1000–1500 (on notice) | `modules/Window.lua` | 1321 | **On notice, peeled.** 1490 → 1321 in `c650485`, per the ruling this cell carried: the `Bus wiring` and `Lifecycle` tail (`RegisterBus`, `UnregisterBus`, `Window.New`, `SetConfig`, `Destroy`, `Suspend`, `Resume`) left whole for `modules/Window_Lifecycle.lua` (205 lines), which re-opens `NS.Window` / `NS.WindowProto` and loads right after this file on a LOAD-BEARING TOC line; five characterization cases pinned it first (`d4c76aa`). What remains is issue #29's causal chain (refresh contract, R3, cached config, frame construction, row pool, refresh), which still must not be cut inside. 179 lines of headroom. The next seam outside that chain, if it needs one, is the `Applying config to the frames` section (`WindowProto:ApplyConfig`, about 200 lines). Re-check at 1450. |
| 1000–1500 (on notice) | `modules/Window_Header.lua` | 1227 | **On notice at birth.** 1184 from the peel. It has an obvious further seam if it ever needs one — the column-header buttons and the sort-arrow ladder are a coherent ~500 lines — so this file has an answer ready rather than a problem. Re-check at 1400. |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1392 | **On notice, post-peel residue.** 3080 → 1350 across three files. This is the row array alone, and it is the part that grows: a page gains rows every time a setting is added. It is the band entry most likely to cross by ordinary work. The next cut is a page boundary, which the peel deliberately left available by not splitting one. Re-check at 1450. |
| 1000–1500 (on notice) | `settings/Schema_Compose.lua` | 1410 | **On notice, past its 1400 re-check by growth.** 1375 → 1410: the minimap row's own get/set moved in from `Schema_Paths.lua` with the `LibKa0s-Schema-1.0` adoption (MM-14), plus the refusal wording MM-09 routes back to Slash and the MM-16 rename. It still grows with new *kinds* of control rather than with new settings, and the `dress()` table is its seam if it needs one. Re-check at 1470. |
| 1000–1500 (on notice) | `tests/test_aggregator.lua` | 1279 | **On notice.** 1840 → 1255 behind its module's peel. It was in the band before the peel too. Re-check at 1450. |
| 1000–1500 (on notice) | `tests/test_export.lua` | 1325 | **On notice.** 1892 → 1275 behind the modal peel, and in the band before it as well. Re-check at 1450. |
| 1000–1500 (on notice) | `tests/test_headercontrols.lua` | 1177 | **On notice, and untouched by this cycle** — 1159, no peel, no growth. It mirrors `modules/HeaderControls.lua`, which is under the cap. Named here so the band reads as measured rather than as a list of things the peel produced. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_options_panel.lua` | 1194 | **On notice, newly crossed by growth.** 928 → 1095 as the Test mode row and the Lock-as-a-view descriptor were composed; +167 lines of cases against +70 in `settings/OptionsSetup.lua`, which is 475 lines and nowhere near the cap. A suite growing four lines for each line of module is what wiring coverage costs here, and it is the intended trade. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_row.lua` | 1223 | **On notice, peeled.** 1490 → 1223 in `f382f23`: the mouse hand-off and inside-a-breakdown cases (15) moved to `tests/test_row_mouse.lua` (324 lines), mirroring `modules/Row.lua`'s mouse-handler section; a pure move, case names unchanged. 277 lines of headroom. It no longer has to peel in lockstep with `modules/Row.lua` (1446), whose own seam is still the value cell. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1354 | **On notice.** 1573 → 1098 behind the path-machinery peel; the only suite this cycle took *out* of breach and well clear now. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_schema_paths.lua` | 1001 | **On notice, newly crossed by growth.** 991 → 1001 as the settings seam moved onto `LibKa0s-Schema-1.0` minor 2 (MM-14, issue #52) and the minimap row's CLI path was renamed (MM-16). It mirrors `settings/Schema_Paths.lua`, which went *down* (982 → 863) in the same work, because the machinery the suite used to pin is the library's now. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1411 | **On notice, past its 1400 re-check — re-ruled 20260926-160431.** 1373 → 1411 in the diagnostics rollout (DR-MM-02/03 retired `diag` and re-hosted the report under both forms); 89 lines of headroom. It is verb-table and adapter assertion, not tangle. The seam is the diagnostics-verb cases, which go to a `tests/test_slash_diagnostics.lua` sibling; peel before the next change that adds verbs. Re-check at 1450. |
| 1000–1500 (on notice) | `tests/test_tooltip_deaths.lua` | 1391 | **On notice at birth.** 1391, the largest of the four files `tests/test_tooltip.lua` became, and deliberately so: the death-event block is one coherent subject (issue #1) and splitting it further would stop mirroring the module. Re-check at 1470. |
| 1000–1500 (on notice) | `tests/test_window.lua` | 1349 | **On notice.** 3159 → 1240 across three suites, the largest single reduction in the repository. Re-check at 1450. |
| 1000–1500 (on notice) | `tests/test_window_header.lua` | 1177 | **On notice, peeled.** 1494 → 1177 in `f382f23`, along the seam this cell named: the sort cases and the sort-arrow ladder (16) moved to `tests/test_window_header_sort.lua` (410 lines); a pure move, case names unchanged. What is left is the header band proper. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1393 | **On notice — tightest in the repository at 34 lines.** 2270 → 1466 with the secret simulator and the frame model out to `mock_secrets.lua` / `mock_frame.lua`. It is not a suite; every one of the 60 suites runs against it, so it is also the file where a mistake is a whole-repo red. The peel left it as the builder the kit's README describes, and the next thing added to it should probably go to a third sibling instead. Re-check at 1480. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

