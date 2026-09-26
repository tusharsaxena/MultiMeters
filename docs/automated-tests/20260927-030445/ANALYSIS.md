# Analysis — 20260927-030445

- **Addon:** MultiMeters 1.0.1 → 1.1.0 (release run, `manifest.json` → `"release": "1.1.0"`)
- **Verdict:** green
- **Commit:** abbb29e (master), clean
- **Previous run:** [`20260926-193124`](../20260926-193124/)

## Headline

The 1.1.0 release gate passed: all four suites at `pass` and no function above CCN 15. Lint is 0/0
over 144 files, all 2092 cases passed with none skipped, and 17 perf scenarios were recorded. Nothing
the gate reads moved since `20260926-193124`: the only code change in between is a comment in
`settings/Schema.lua`, and the rest is README prose. Nothing needs acting on.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260926-193124` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 144 files | [`lint.txt`](lint.txt) | unchanged at 0/0 over 144 files |
| tests | pass | 2092 passed, 0 skipped, 0 failed, 2092 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged; `test-cases.md` identical to the previous bundle's |
| perf | pass | 17 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 17 scenarios; api/iter and bytes/iter identical on all 17 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | every footer figure unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 43863 |
| Functions | 4462 |
| Avg NLOC / function | 8.2 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 63.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 22 |
| Files over the 1500 cap | 0 |

Every figure above comes from the `suites` block in [`manifest.json`](manifest.json). **No suite was
skipped.** All three tools were present: Lua 5.1.5, Luacheck 1.2.0 and lizard 1.24.0
(`manifest.json` → `host`).

### Release gate (`automated-tests-§3`)

| Gate | Result | Detail |
|---|---|---|
| Lint | PASS | `suites.lint.status` pass, 0 warnings / 0 errors in 144 files |
| Tests | PASS | `suites.tests.status` pass, failed 0 of 2092 |
| Perf | PASS | `suites.perf.status` pass, 17 scenarios measured (not the no-`tests/perf.lua` exception) |
| Complexity | PASS | `suites.complexity.status` pass, lizard 1.24.0 ran |
| CCN <= 15 | PASS | `suites.complexity.warnings` 0, max CCN 15 |

Every suite passed cleanly, so no suite needs a paragraph of its own.

## What moved

The run measures 5 commits past the previous run's `f53ca7a`: the sweep's final-run record
(`9f28ee1`), its sync-docs pass (`54a8214`), the merge to master (`b2ea2ab`), and two README commits
(`cacfa31`, `abbb29e`), the second of which also rewords one comment in `settings/Schema.lua` without
changing its line count.

- **lint.** 0/0 over 144 files, as before.
- **tests.** 2092 → 2092 with 0 skipped and 0 failed. [`test-cases.md`](test-cases.md) is
  byte-identical to the previous bundle's, so no case was added, lost or renamed.
- **perf.** The same 17 scenarios ran, with `api/iter` and `bytes/iter` identical on all 17. Wall-clock
  time rose, for example `refresh20x7` 0.76653 → 0.88199 ms/iter, `throttleBurst` 12.929 → 18.420 ms
  and `rosterBurst` 6.917 → 16.913 ms over one iteration. No code on any measured path changed between
  the two runs, so this is machine load, the same noise the previous two analyses saw in each
  direction. `rosterBurst` stays tracked as issue #54.
- **complexity.** Every footer figure is unchanged: NLOC 43863, functions 4462, avg NLOC 8.2, avg CCN
  2.4, avg tokens 63.8, max CCN 15, 0 warnings.
- **band.** 22 files, the same 22 at the same line counts. Nothing entered or left the band.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. This is a release run, and zero functions above CCN 15 is what the gate enforced.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

No band row changed length and none arrived new, so every disposition in
[`../RESULTS.md`](../RESULTS.md) is carried forward unchanged. None of the 22 is marked **Accepted**,
so no entry is on the three-release shelf life (anti-pattern #53). The tightest file is still
`settings/Schema_Compose.lua` at 1410, 90 lines under the cap.

## Actions

None.
