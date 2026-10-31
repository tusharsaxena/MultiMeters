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
(`automated-tests-§3`, *The release gate*), evaluated by `/dev-copilot:bump-version` from the
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
| [`20261031-202021`](20261031-202021/) | `0d603a4` | clean | 1.2.0 | 0/0 | 178 | 2449/1/2450 | pass | 52646 | 5713 | 8.4 | 2.5 | 15 | 0 | **green** |
| [`20261009-191721`](20261009-191721/) | `b3c8b4f` | clean | 1.1.0 → 1.2.0 | 0/0 | 146 | 2196/1/2197 | pass | 45504 | 4913 | 8.4 | 2.5 | 15 | 0 | **green** |
| [`20260927-030445`](20260927-030445/) | `abbb29e` | clean | 1.0.1 → 1.1.0 | 0/0 | 144 | 2092/0/2092 | pass | 43863 | 4462 | 8.2 | 2.4 | 15 | 0 | **green** |
| [`20260926-193124`](20260926-193124/) | `f53ca7a` | clean | 1.0.1 | 0/0 | 144 | 2092/0/2092 | pass | 43863 | 4462 | 8.2 | 2.4 | 15 | 0 | **green** |
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

**2450 cases** — 2449 passed, 0 failed, 1 skipped. The generated inventory
[`20261031-202021/test-cases.md`](20261031-202021/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **2197 → 2450** since the previous run.

**1 case(s) reported a `skip`.** A skip is counted in the total and never in `passed`, and at
the release gate it is NOT EVALUATED rather than passed (`automated-tests-§3`).

## Lint

**0 warnings / 0 errors over 178 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 5 path(s) from it — `libs/`, `tests/_kit/`, `docs/audits/`, `docs/reviews/`, `_dev/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**18 scenarios** from `tests/perf.lua`; the measurements are in
[`20261031-202021/perf.json`](20261031-202021/perf.json).

| `scenario` | `iters` | `ms/iter` | `api/iter` | `bytes/iter` |
|---|---|---|---|---|
| `refresh20x7` | 300 | 1.10561 | 8.00 | 297237.4 |
| `refresh20x7Restricted` | 300 | 1.33998 | 8.00 | 406173.3 |
| `throttleBurst` | 1 | 23.96600 | 8.00 | 317269.0 |
| `throttleIdle` | 300 | 0.00063 | 0.00 | 0.0 |
| `drillOpenClose` | 300 | 0.03185 | 1.00 | 12746.2 |
| `refreshWhileDrilled` | 300 | 0.06489 | 1.00 | 16170.1 |
| `rosterRebuild` | 300 | 0.83685 | 8.00 | 315144.1 |
| `rosterBurst` | 1 | 1.15600 | 8.00 | 316951.0 |
| `rosterCached` | 300 | 0.76146 | 8.00 | 297216.1 |
| `rosterPartial` | 300 | 0.80737 | 8.00 | 314374.5 |
| `applyConfig` | 300 | 0.48738 | 0.00 | 63874.5 |
| `probeOverheadOff` | 300 | 0.76592 | 8.00 | 297216.1 |
| `probeOverheadOn` | 300 | 0.77921 | 8.00 | 297220.9 |
| `suspended` | 300 | 0.00014 | 0.00 | 0.0 |
| `feignTraceAbsent` | 300 | 0.18365 | 2.00 | 65344.1 |
| `feignTraceOff` | 300 | 0.20420 | 2.00 | 65344.1 |
| `spellEventOff` | 300 | 0.00023 | 0.00 | 0.0 |
| `spellEventOn` | 300 | 0.00038 | 0.00 | 0.7 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20261031-202021`](20261031-202021/) — **this run's measurement, not its diff.** Max CCN **15** across 5713
functions, **0** of them warned on; 24 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Database.lua` | 1387 | **Peeled 2026-10-31 (FX-MM-SIZE), and it should leave the band.** 1387 → 433: the migration ladder and its runner moved to `core/Database_Migrations.lua` (973), the seam this cell named; a pure move. What stays is the AceDB instance, the window shape and the profile callbacks. |
| 1000–1500 (on notice) | `locales/enUS.lua` | 1236 | **On notice, crossed by growth, and it is a flat table rather than code.** 990 lines when first ruled, 1039 when it crossed, 1056 at `20260926-193124`: the 2026-09-23 remediation routed every user-facing slash line through `NS.L` with a plural (MM-22), named unknown windows and empty renames (MM-06), the chat-sender refusal (MM-04) and the enable/disable wording (MM-15). One `L[...]` key per line and no control flow, so its size is the addon's string count, not tangle; `layout-§1` still binds it. The seam, if it needs one, is a second locale file for the diagnostics and debug-console strings, which no player-facing path reads. Re-check at 1300. |
| 1000–1500 (on notice) | `modules/Aggregator.lua` | 1343 | **On notice, peeled in MM-ATS-03 (the 2026-09-26 automated-tests sweep, ATS-12).** 2122 → 1331 on 2026-09-09 (identity mode and the correlation rectangle left for `Aggregator_Identity.lua` / `_Preview.lua`), grown back to 1432, then 1432 → 1230: the orderings (`reverseRows`, `orderByProvider`, `orderByValue`, `orderByName`, `orderByRoster`) and the row cap (`ApplyRowLimit`, `SelfPinIndex`) moved to `modules/Aggregator_Order.lua` (275 lines), a pure move over the `Aggregator._order` seam, which carries only `UNRANKED` out. None of them reads a pass table, so the pipeline was not cut inside: the ladder that picks an ordering (`applySortMode`) and Build stayed. Re-check at 1400; the source-admission helpers (`owningMember` to `rowForSource`, about 310 lines) are the next seam. |
| 1000–1500 (on notice) | `modules/Provider.lua` | 1096 | **On notice, crossed by growth rather than by a peel.** 924 lines when first ruled, 1056 when it crossed, 1084 at `20260926-193124` — the roster/spec identity work. With `core/Database.lua` and `locales/enUS.lua` it is one of three band entries that arrived by growth; the rest are post-peel residue settling, and a module getting bigger is the direction that matters. Its suite, one file exactly on the 1500 cap when this was first ruled, is now three: `tests/test_provider.lua` (773), `tests/test_provider_fields.lua` (305) and `tests/test_provider_recap.lua` (456). Re-check at 1200. |
| 1000–1500 (on notice) | `modules/Row.lua` | 1284 | **On notice, peeled in MM-ATS-02 (the 2026-09-26 automated-tests sweep, ATS-12).** 1446 → 1226: the cell outline (`BORDER_SIDES`/`BORDER_ANCHOR`, `cellBorderColor`, `borderThickness`, the flat and art paths, `Cell:ApplyBorder` and `Cell:ApplyEntryBorderColor`) moved to `modules/Row_Border.lua` (256 lines), a pure move that reaches back only for `Cell`, `RGBA`, `ClassRGB` and `borderEdge` through `NS.RowInternals`. The outline was taken rather than the value cell this cell used to name, because the value cell (`barInterpolation`, `fillBar`, `Cell:SetValue`, `Cell:Clear`, about 157 lines) would have left the parent near 1290, over the item's 1250 target, and it is the secret-handling hot path the header's rules are written around. Still on the refresh path and still where identity, spec-icon and pet-fold changes land. Re-check at 1400; the value cell is the next seam. |
| 1000–1500 (on notice) | `modules/Tooltip.lua` | 1176 | **On notice, post-peel residue.** 2774 → 1167; the four builders and the line drawing left for `Tooltip_Builders.lua` / `Tooltip_Lines.lua`. What remains is the secret-safe primitives, which is the half that must not be touched casually — 333 lines of headroom is ample for a file nothing routinely adds to. Re-check at 1400. |
| 1000–1500 (on notice) | `modules/Tooltip_Builders.lua` | 1047 | **On notice at birth**, which a peel makes ordinary: it landed at 1030 because the seam was drawn for what a reader can hold, not at a line count, and reads 1033 at `20260926-193124`. It is the half a feature adds to, so it is the likelier of the pair to grow. Re-check at 1400. |
| 1000–1500 (on notice) | `modules/Window_Header.lua` | 1370 | **On notice at birth.** 1184 from the peel, 1227 at `20260926-193124`. It has an obvious further seam if it ever needs one — the column-header buttons and the sort-arrow ladder are a coherent ~500 lines — so this file has an answer ready rather than a problem. Re-check at 1400. |
| 1000–1500 (on notice) | `settings/Schema.lua` | 1473 | **On notice, peeled 2026-10-31 (FX-MM-SIZE).** 1473 → 1101 at the page boundary this cell named: the Visibility, Columns and General pages, the generated palette and the two passes moved to `settings/Schema_General.lua` (397), and a dump of `NS.Schema` is identical before and after. Re-check at 1400. |
| 1000–1500 (on notice) | `settings/Schema_Compose.lua` | 1470 | **On notice, peeled 2026-10-31 (FX-MM-SIZE).** 1470 → 1308: the dropdown vocabularies moved to `settings/Schema_Vocab.lua` (248), a cleaner cut than the `dress()` table this cell used to name, because they read only the locale and the constants. It still grows with new *kinds* of control rather than with new settings. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_aggregator.lua` | 1437 | **On notice.** 1840 → 1255 behind its module's peel, 1279 at `20260926-193124`; MM-ATS-03's `modules/Aggregator_Order.lua` peel moved no cases out of it. It was in the band before the peel too. Re-check at 1450. |
| 1000–1500 (on notice) | `tests/test_database_migrations.lua` | 1000 | **On notice, newly crossed by growth.** 981 → 1000 with the case count unchanged at 48: MM-A1's v21 reset widened existing cases. One coherent subject, the migration walk in `core/Database_Migrations.lua`, so the size is case count rather than tangle. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_export.lua` | 1408 | **On notice.** 1892 → 1275 behind the modal peel, and in the band before it as well; 1325 at `20260926-193124`. Re-check at 1450. |
| 1000–1500 (on notice) | `tests/test_headercontrols.lua` | 1311 | **On notice, and never peeled** — 1159 when first ruled, 1177 at `20260926-193124`. It mirrors `modules/HeaderControls.lua` (756), which is under the cap. Named here so the band reads as measured rather than as a list of things the peels produced. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_launchersetup.lua` | 1074 | **On notice, newly crossed by growth.** 922 → 1074, 50 → 56 cases: MM-02's Show window binding cases (+127) and MM-KB's section. It pins `core/LauncherSetup.lua` (364) through the real slash verbs, so the size is case count rather than tangle. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_options_panel.lua` | 1402 | **Peeled 2026-10-31 (FX-MM-SIZE), and it should leave the band.** 1402 → 940: the drawn-page cases (the tab strips, the band, the shared timer, Keybindings) moved to `tests/test_options_tabs.lua` (515); a pure move, case names unchanged. |
| 1000–1500 (on notice) | `tests/test_roster.lua` | 1014 | **On notice, newly crossed by growth.** 904 at the 1.1.0 release run, 1014 here: MM-03 added the partial-roster cases (+78 net) and DL-MM-02 the debug-coverage cases (+32). It mirrors `modules/Roster.lua` (764), which is nowhere near the cap, so the size is case count rather than tangle. The seam, if it needs one, is the partial-rebuild block leaving for a `tests/test_roster_partial.lua` sibling. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_row.lua` | 1234 | **On notice, peeled.** 1490 → 1223 in `f382f23`: the mouse hand-off and inside-a-breakdown cases (15) moved to `tests/test_row_mouse.lua` (324 lines), mirroring `modules/Row.lua`'s mouse-handler section; a pure move, case names unchanged. 1223 → 1229 in MM-ATS-02, when the static R3 getter scan widened to `modules/Row_Border.lua` so the outline's peel did not carry it out of the gate (same case, same name). 271 lines of headroom. It no longer has to peel in lockstep with `modules/Row.lua` (1226). Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1381 | **On notice.** 1573 → 1098 behind the path-machinery peel, grown back to 1354 at `20260926-193124`, 46 lines short of its re-check. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_schema_paths.lua` | 1038 | **On notice, newly crossed by growth.** 991 → 1001 as the settings seam moved onto `LibKa0s-Schema-1.0` minor 2 (MM-14, issue #52) and the minimap row's CLI path was renamed (MM-16). It mirrors `settings/Schema_Paths.lua`, which went *down* (982 → 863) in the same work, because the machinery the suite used to pin is the library's now. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_tooltip_deaths.lua` | 1391 | **On notice at birth.** 1391, the largest of the four files `tests/test_tooltip.lua` became, and deliberately so: the death-event block is one coherent subject (issue #1) and splitting it further would stop mirroring the module. Re-check at 1470. |
| 1000–1500 (on notice) | `tests/test_window.lua` | 1472 | **On notice, peeled 2026-10-31 (FX-MM-SIZE).** 1472 → 1132: the BuildLayout and throttle-clamp cases moved to `tests/test_window_layout.lua` (413); a pure move, case names unchanged. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_window_header.lua` | 1314 | **On notice, peeled.** 1494 → 1177 in `f382f23`, along the seam this cell named: the sort cases and the sort-arrow ladder (16) moved to `tests/test_window_header_sort.lua` (410 lines); a pure move, case names unchanged. What is left is the header band proper. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1393 | **On notice, 107 lines of headroom.** 2270 → 1466 with the secret simulator and the frame model out to `mock_secrets.lua` / `mock_frame.lua`, 1393 at `20260926-193124`. It is not a suite; every `tests/test_*.lua` suite runs against it, so it is also the file where a mistake is a whole-repo red. The peel left it as the builder the kit's README describes, and the next thing added to it should probably go to a third sibling instead. Re-check at 1480. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

