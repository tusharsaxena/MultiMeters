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
| [`20260908-181355`](20260908-181355/) | 0.1.0 | 0/0 | 93 | 1530/0/1530 | pass | 32913 | 3337 | 8.2 | 2.6 | 34 | 23 | **green** |
| [`20260825-103437`](20260825-103437/) | 0.1.0 | 0/0 | 47 | 1257/1257 | fail | 26531 | 2884 | 7.7 | 2.5 | 31 | 19 | **amber** |
| [`20260825-021705`](20260825-021705/) | 0.1.0 | 0/0 | 46 | 1246/1246 | fail | 26457 | 2867 | 7.7 | 2.5 | 31 | 19 | **amber** |
| [`20260809-195454`](20260809-195454/) | 0.1.0 | 0/0 | 40 | 676/676 | pass | 15173 | 1677 | 7.3 | 2.4 | 15 | 0 | **green** |
| [`20260809-194203`](20260809-194203/) | 0.1.0 | 0/0 | 40 | 676/676 | pass | 15005 | 1627 | 7.4 | 2.4 | 41 | 13 | **green** |

## Test suite

**1530 cases** — 1530 passed, 0 failed, 0 skipped. The generated inventory
[`20260908-181355/test-cases.md`](20260908-181355/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **1257 → 1530** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 93 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` sets `exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "_dev/" }`, so those paths
are not in it. A `0/0` that never moves is partly a statement about what was never looked at, which
is why the exclusion is restated on every run.

## Perf

**15 scenarios** from `tests/perf.lua`; the measurements are in
[`20260908-181355/perf.json`](20260908-181355/perf.json).

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20260908-181355`](20260908-181355/) — **this run's measurement, not its diff.** Max CCN **34** across 3337
functions, **23** of them warned on; 2 file(s) in the 1000–1500 band and 15 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `]` | 16 | `core/Database.lua` | **Accepted** — `migrations[1]`, `core/Database.lua:270-296`. A shipped migration step is frozen the day it lands; the count is `type(x) == "table"` guards down profiles → windows → columns, and the one decision in it is the frame-widening `if`. Re-check: any step gains a branch that is not a type guard, or passes 40 NLOC. **This row and the CCN-16 row below it cannot be told apart on the runner's keys** (both `]` in the same file at the same CCN), so both read blank on every regeneration; `docs/ARCHITECTURE.md` § *Complexity register* is their home of record. |
| `]` | 17 | `core/Database.lua` | **Accepted** — `migrations[4]`, `core/Database.lua:372-401`. Same shape and the same freeze: the lift of `mergePets` / `throttle` to profile level, guarded twice per key because "already set" cannot be told from "just merged in". Re-check: as above. |
| `]` | 16 | `core/Database.lua` | **Accepted** — `migrations[12]`, `core/Database.lua:659-684`. Same again: `titleBar` moves to `header.show` and two class-colour booleans become modes, each behind a `~= nil` and a prune. Re-check: as above. See the note on the CCN-16 row above about why this cell cannot carry forward. |
| `reportDeathDating` | 25 | `core/Diagnostics.lua` | **Accepted.** Developer-only print code behind `/mm debug diag`; the count is `x and y or "nil"` inside two `string.format` argument lists, and the function's whole value is that it prints inputs rather than a conclusion. Re-check: the `debug.md` Tier 2 trigger — a probe section gains state or an option. |
| `reportFeignRoster` | 17 | `core/Diagnostics.lua` | **Accepted.** Same class: three guarded unit reads per group member in one formatted line, printed for the whole group so a non-feigning baseline sits beside the feigning row. Re-check: as above. |
| `scanColumn` | 34 | `modules/Aggregator.lua` | **Peel** — [#35](https://github.com/tusharsaxena/MultiMeters/issues/35). The per-source loop body, and the counted-column max pass under it. `M2-09` already took 36 → 34 by hoisting `judgeTracer` out, so the seam is proven rather than proposed. |
| `DrillDown` | 18 | `modules/DrillDown.lua` | **Accepted** — `DrillDown:OnCellClick`, `modules/DrillDown.lua:395-428`; `lizard` reports a method under its receiver. 20 NLOC; the count is three `f() and "x" or "none"` returns plus the Deaths ladder, and the ladder's **order** is the only thing the function records. Re-check: a second `statKey` grows a ladder of its own — two ladders are a table. |
| `Export.ChatLines` | 27 | `modules/Export.lua` | **Peel** — [#36](https://github.com/tusharsaxena/MultiMeters/issues/36). The header build and the ranked line are two functions sharing a name; the `hasExtra` bookkeeping belongs entirely to the second. |
| `onPrintToChat` | 16 | `modules/Export.lua` | **Accepted.** Four refusals, each with a recorded reason and each asked at the click because the answer changes between opening the modal and pressing the button, then a linear send. One point over. Re-check: a fifth refusal, or CCN 20. |
| `Feign.Prune` | 25 | `modules/Feign.lua` | **Peel** — [#37](https://github.com/tusharsaxena/MultiMeters/issues/37). The `unit == nil` fork: the member who left the group and the member whose health is read are two verdicts, and the function's own comments already treat them as separate findings. |
| `Format.DeathTime` | 19 | `modules/Format.lua` | **Accepted.** 15 NLOC at CCN 19 is `performance-§10`'s own documented artefact in its purest form: every `or` fallback scores as a decision and not one of them branches. Re-check: a third style beyond `clock` and `ago`. |
| `onClick` | 24 | `modules/HeaderControls.lua` | **Peel** — [#38](https://github.com/tusharsaxena/MultiMeters/issues/38). A seven-way `elseif` on the control name, sharing no state across arms; a module-level dispatch table is the shape `performance-§11` permits, built once rather than per click. |
| `build` | 20 | `modules/Roster.lua` | **Accepted.** One unit walk with three outputs, and the header says why it is not three walks; the count is `unitExists` / `IsSafeKey` guards plus the nested pet read. Re-check: a fourth output joins the walk, or the pet lookup grows a second kind — then the per-unit body peels to `addMember`. |
| `Cell` | 30 | `modules/Row.lua` | **Peel** — [#39](https://github.com/tusharsaxena/MultiMeters/issues/39). `Cell:ApplyBorder`, `modules/Row.lua:659-739`. Its own comment names the seam — the art path and the flat path are mutually exclusive — and the per-side anchor chain under it is a data table. **Its ceiling row's trigger has fired**: the v0.1.0 watch list recorded it at exactly 15 with zero headroom, and it is 30. |
| `Cell` | 19 | `modules/Row.lua` | **Accepted** — `Cell:ApplyIcons`, `modules/Row.lua:1168-1244`. The slot array is `{ "unit" }` or `{}` today, so the loop is degenerate and what remains is defaulting and the left/right mirror. Re-check: a second slot returns — [#8](https://github.com/tusharsaxena/MultiMeters/issues/8) would do it — at which point the loop is real and the peel is worth taking. |
| `eventColumns` | 19 | `modules/Tooltip.lua` | **Accepted.** A name-resolution ladder over one recap event where each arm is a documented client behaviour: a melee swing carries no spell at all, a heal names none, an unnamed spell shows its id rather than being dropped. Re-check: a fourth event kind. |
| `(anonymous)` | 26 | `modules/Tooltip.lua` | **Peel** — [#40](https://github.com/tusharsaxena/MultiMeters/issues/40). This is `drawDeathEvents`, `modules/Tooltip.lua:1957-2039`, and it is neither anonymous nor starting where the parser says: the entry opens at the `function(_, event)` handed to `Secrets.SafeIterate` and closes at the enclosing function's `end`, so callback and host are reported as one row under the callback's name. Collect, measure, draw are already three phases in sequence; the measuring pass carries all of the `namesReadable` bookkeeping and none of the drawing. |
| `Tooltip` | 20 | `modules/Tooltip.lua` | **Accepted** — `Tooltip:CellTooltip`, `modules/Tooltip.lua:2342-2404`. Linear composition — release, open, header, style, one Deaths/spell branch, five appends, then `Show` and the two fixups that must follow it. The count is defaulting; there is no tangle here to peel. Re-check: a third path joins the Deaths/spell branch. |
| `Visibility.ShouldShow` | 23 | `modules/Visibility.lua` | **Peel** — [#41](https://github.com/tusharsaxena/MultiMeters/issues/41). Eight copies of one line in 21 NLOC; a module-level `{ flag, probe, reason }` table and one loop is `performance-§11`'s permitted shape, and it makes the veto **order** — which the comment says is the point — data rather than line position. |
| `WindowProto` | 24 | `modules/Window.lua` | **Peel** — [#42](https://github.com/tusharsaxena/MultiMeters/issues/42). `WindowProto:BuildLayout`, `modules/Window.lua:312-413`. The middle third: the visible-column filter, the equal share and the placement loop. Rule R3 is the constraint on the peel — config in, numbers out, no frame read back. **Its ceiling row's trigger has fired**: 15 → 24. |
| `place` | 18 | `modules/Window.lua` | **Peel** — [#43](https://github.com/tusharsaxena/MultiMeters/issues/43). 133 lines and 5 parameters, and create-once-then-dress is the split `LIBKA0S-R-01` already cut in the library's `TabStrip`. Being a closure over the enclosing method is the work, and the reason it is worth more than CCN 18 suggests. |
| `NS.ReorderableBlocks` | 28 | `settings/ColumnBlocks.lua` | **Peel** — [#44](https://github.com/tusharsaxena/MultiMeters/issues/44). The loop body is doing three jobs — draw the block, register the row, draw the boundary rule — and everything outside it is one refusal and a descriptor. |
| `doDebug` | 25 | `settings/Slash.lua` | **Peel** — [#45](https://github.com/tusharsaxena/MultiMeters/issues/45). The only verb that takes an argument is the only nested ladder; the other three name a `Diagnostics` method and collapse to a table. **The only warned function that got worse this cycle** — 23 → 25 under `M2-11`, for a good reason, which is exactly the move a watch list exists to catch. |

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_database.lua` | 1004 | **On notice, and that is the compliant state** under `layout-§1` — a band entry is not a breach. Four lines over the line. It mirrors `core/Database.lua`, which is under the cap, so it has no seam waiting on anything. Re-check at 1200. |
| 1000–1500 (on notice) | `tests/test_provider.lua` | 1359 | **On notice.** The larger of the two band files and the one closer to the cap. It mirrors `modules/Provider.lua`, which is under the cap; if it crosses 1500 it takes an issue of its own rather than joining a module's peel, because there is no module peel for it to join. Re-check at 1450. |
| > 1500 (over cap) | `core/Diagnostics.lua` | 1824 | **In breach, owned: issue [#31](https://github.com/tusharsaxena/MultiMeters/issues/31)** — one file per long-lived probe. Census row in `docs/ARCHITECTURE.md` § *Files over the 1500-line cap*. |
| > 1500 (over cap) | `modules/Aggregator.lua` | 2083 | **In breach, owned: issue [#30](https://github.com/tusharsaxena/MultiMeters/issues/30)** — identity mode and the correlation rectangle out of the build pipeline. Census row in `docs/ARCHITECTURE.md`. |
| > 1500 (over cap) | `modules/Export.lua` | 1748 | **In breach, owned: issue [#32](https://github.com/tusharsaxena/MultiMeters/issues/32)** — the pure serializer out of the modal, the split its own `:50` banner already names. Census row in `docs/ARCHITECTURE.md`. |
| > 1500 (over cap) | `modules/Row.lua` | 1715 | **In breach, owned: issue [#33](https://github.com/tusharsaxena/MultiMeters/issues/33)** — the name cell out to its own file. Census row in `docs/ARCHITECTURE.md`. |
| > 1500 (over cap) | `modules/Tooltip.lua` | 2659 | **In breach, owned: issue [#28](https://github.com/tusharsaxena/MultiMeters/issues/28)** — the four tooltip builders out from under the secret-safe primitives. Census row in `docs/ARCHITECTURE.md`. |
| > 1500 (over cap) | `modules/Window.lua` | 2650 | **In breach, owned: issue [#29](https://github.com/tusharsaxena/MultiMeters/issues/29)** — header art, sorting and the segment selector out of the refresh chain. Census row in `docs/ARCHITECTURE.md`. |
| > 1500 (over cap) | `settings/Schema.lua` | 3080 | **In breach, owned: issue [#27](https://github.com/tusharsaxena/MultiMeters/issues/27)** — the schema array out of the path machinery. The largest file in the repository. Census row in `docs/ARCHITECTURE.md`. |
| > 1500 (over cap) | `tests/test_aggregator.lua` | 1605 | **In breach, register row** — peels with `modules/Aggregator.lua` ([#30](https://github.com/tusharsaxena/MultiMeters/issues/30)). A suite that mirrors an over-cap module has no seam of its own: peeling it first would commit to a partition the module has not chosen. |
| > 1500 (over cap) | `tests/test_diagnostics.lua` | 1583 | **In breach, register row** — peels with `core/Diagnostics.lua` ([#31](https://github.com/tusharsaxena/MultiMeters/issues/31)). Same reason as the row above. |
| > 1500 (over cap) | `tests/test_export.lua` | 1509 | **In breach, register row** — peels with `modules/Export.lua` ([#32](https://github.com/tusharsaxena/MultiMeters/issues/32)). Nine lines over the cap, and the shallowest breach here. |
| > 1500 (over cap) | `tests/test_row.lua` | 1606 | **In breach, register row** — peels with `modules/Row.lua` ([#33](https://github.com/tusharsaxena/MultiMeters/issues/33)). |
| > 1500 (over cap) | `tests/test_schema.lua` | 1573 | **In breach, register row** — peels with `settings/Schema.lua` ([#27](https://github.com/tusharsaxena/MultiMeters/issues/27)). |
| > 1500 (over cap) | `tests/test_tooltip.lua` | 2708 | **In breach, register row** — peels with `modules/Tooltip.lua` ([#28](https://github.com/tusharsaxena/MultiMeters/issues/28)). |
| > 1500 (over cap) | `tests/test_window.lua` | 2737 | **In breach, register row** — peels with `modules/Window.lua` ([#29](https://github.com/tusharsaxena/MultiMeters/issues/29)). The largest suite in the repository. |
| > 1500 (over cap) | `tests/wow_mock.lua` | 2270 | **In breach, owned: issue [#34](https://github.com/tusharsaxena/MultiMeters/issues/34)** — the secret simulator and the frame model out to siblings. The one test file here with a seam of its own rather than a module's. Census row in `docs/ARCHITECTURE.md`. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

