# Execution plan — Ka0s Multi Meters, review of 2026-09-23

**Upstream milestone: none.** No finding lands in LibKa0s or the test kit. `libs/LibKa0s` and `tests/_kit`
are byte-identical to `../LibKa0s` as of today.

A collection-wide re-vendor of LibKa0s may still arrive from the cross-repo plan this review feeds. If it
does, it lands **before M1**, as its own commit (`Re-vendor LibKa0s vX.Y.Z`). After it, run the full gate
and regenerate `docs/test-cases.md` if the count moves. Nothing in this plan edits `libs/` or
`tests/_kit/`.

**The gate after every task:**

- `~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua` must be all green.
- `~/.claude/wow-addon/bin/ka0s-bounded luacheck .` must report 0/0.
- In any commit that moves the pass count: `lua tests/run.lua --list > docs/test-cases.md`, plus the
  README `Tests-N/N` badge.

---

## M0 — Red-first characterization

**Done when** every case below is committed as **failing for the right reason**: run the gate, see
exactly these cases red, and see nothing else red. Only then does the fix milestone begin. The
repository convention allows a red case in a WIP commit only when that commit is squashed into its fix,
so keep M0 and its fix in the same squash unit.

| Task | Owner role | Findings | Files |
|---|---|---|---|
| T0.1 | test-author | F-002, F-004, F-005 | `tests/test_disabled.lua` (3 cases, `-- red under:` notes) |
| T0.2 | test-author | F-001 | `tests/test_window.lua` (3 cases), `tests/test_aggregator.lua` (1 case) |
| T0.3 | test-author | F-003 | `tests/test_export.lua` (3 cases) |
| T0.4 | test-author | F-006 | `tests/test_degraded.lua` (1 case, partial library load) |

These can run in parallel: T0.1 through T0.4 touch four disjoint files.

**Checkpoint CP0.** The human confirms each new case fails for the reason its note names. For example,
T0.1's first case must report "a window is on screen while the addon is disabled", not raise in setup.

## M1 — The latch owns every show path (Theme A)

**Done when** T0.1's cases are green, `tests/test_lifecycle.lua:288` and `tests/test_disabled.lua` are
green, and SM-01, SM-02 and SM-03 pass in client.

| Task | Owner role | Change | Findings | Files |
|---|---|---|---|---|
| T1.1 | lua-refactorer | C-01 | F-002, F-004, F-005 | `modules/Window_Placement.lua`, `modules/WindowManager.lua`, `modules/Window.lua`, `core/LauncherSetup.lua`, `locales/enUS.lua` |
| T1.2 | lua-refactorer | C-04 | F-006 | `settings/Slash.lua` |

T1.1 and T1.2 are **parallelizable**: their file sets are disjoint. T1.1 touches
`core/LauncherSetup.lua:235-236`, but only the click body, not the `:232` guard T1.2 relies on.

**Checkpoint CP1.** Run SM-01, SM-02 and SM-03 in client before M2 starts, because M2 edits
`modules/Window.lua` again.

## M2 — Self-pin follows the drawn slice (Theme B)

**Done when** T0.2's cases are green, lizard reports `WindowProto` (Render) at CCN ≤ 15, and SM-04
passes.

| Task | Owner role | Change | Findings | Files |
|---|---|---|---|---|
| T2.1 | lua-refactorer | C-02 | F-001 | `modules/Aggregator.lua`, `modules/Window.lua` |

This **must serialize after T1.1**: both edit `modules/Window.lua`.

## M3 — Compat chat sender (Theme C)

**Done when** T0.3's cases are green and SM-05 passes.

| Task | Owner role | Change | Findings | Files |
|---|---|---|---|---|
| T3.1 | wow-api-migrator | C-03 | F-003 | `core/Compat.lua`, `modules/Export.lua`, `locales/enUS.lua` |

Parallelizable with M1 and M2 on code. **`locales/enUS.lua` is shared with T1.1, T5.2 and T5.3**, so
serialize the locale hunks: whoever lands second rebases.

## M4 — Refresh cost (Theme D), measure-first

**Done when** there is a pre-change `docs/perf-analysis/<stamp>/` bundle (SM-07 step 1) and a
post-change bundle. `render` ms/call must be lower. Offline `refresh20x7` must still show api/iter
= 8 and bytes/iter ≤ today's 303438.1.

| Task | Owner role | Change | Findings | Files |
|---|---|---|---|---|
| T4.0 | perf-analyst (human in client) | baseline capture | F-007 | `docs/perf-analysis/<stamp>/` (via `/wow-addon:perf-analysis`) |
| T4.1 | lua-refactorer | C-05 | F-007 | `modules/Window.lua`, `modules/Row.lua` |
| T4.2 | lua-refactorer | C-06 | F-009 | `modules/Visibility.lua`, `tests/test_visibility.lua` |
| T4.3 | lua-refactorer | C-15 (measure only) | F-017 | `core/PerfSetup.lua`, `core/MultiMeters.lua` |

Ordering constraints:

- T4.1 **must serialize after T2.1**, because both edit `modules/Window.lua`.
- T4.2 is parallelizable with T4.1.
- T4.3 is parallelizable with T4.1 and T4.2, and must not touch any file of M1, M2 or M3 other than
  `core/MultiMeters.lua`, which no earlier task edits.

`modules/Row.lua` has 31 lines of headroom under the cap. T4.1 must not grow it, and it must stay at
1500 lines or fewer.

**Checkpoint CP4.** A human compares the two bundles' **bucket figures**. If `render` did not move,
revert T4.1 rather than keep an unmeasured refactor.

## M5 — Hygiene and evidence (Theme E)

**Done when** every case is green, lint is 0/0, and SM-08, SM-09 and SM-10 pass.

| Task | Owner role | Change | Findings | Files |
|---|---|---|---|---|
| T5.1 | ux-cleanup | C-07 | F-010 | `modules/WindowManager.lua`, `locales/enUS.lua`, `tests/test_windowmanager.lua` |
| T5.2 | ux-cleanup | C-08 | F-011 | `settings/Slash.lua`, `locales/enUS.lua` |
| T5.3 | ux-cleanup | C-13 | F-016 | `modules/DrillDown.lua`, `tests/test_drilldown.lua` |
| T5.4 | docs-cleanup | C-09 | F-012 | `core/MultiMeters.lua`, `modules/Window_Placement.lua`, `modules/HeaderControls.lua`, `core/LauncherSetup.lua` |
| T5.5 | test-author | C-10 | F-013 | `tests/wow_mock.lua` (+ any case asserting `0.1.0`) |
| T5.6 | lint | C-11 | F-014 | `.luacheckrc` |
| T5.7 | docs-cleanup | C-12 | F-015 | `docs/performance.md` |
| T5.8 | lua-refactorer | C-14 (branch chosen by SM-06) | F-008 | `modules/Roster.lua`, `tests/test_roster.lua` |

These overlap with earlier tasks and must serialize:

- T5.1 after T1.1 (`modules/WindowManager.lua`).
- T5.2 after T1.2 (`settings/Slash.lua`).
- T5.4 after T4.3 (`core/MultiMeters.lua`) and after T1.1 (`core/LauncherSetup.lua`, `modules/Window_Placement.lua`).

T5.3, T5.5, T5.6, T5.7 and T5.8 are **parallelizable**. T5.8 is **blocked on SM-06** being run and recorded.

## Critical path

```
M0 (T0.1‖T0.2‖T0.3‖T0.4) → CP0 → T1.1 → CP1 → T2.1 → T4.0 → T4.1 → CP4 → T5.4
                                  ↘ T1.2 → T5.2
                    T3.1 (after CP0, any time; serialize locale hunks)
                    SM-06 (in client, any time) → T5.8
```

Serialization edges, by shared file:

| Shared file | Task order |
|---|---|
| `modules/Window.lua` | T1.1 → T2.1 → T4.1 |
| `modules/WindowManager.lua` | T1.1 → T5.1 |
| `settings/Slash.lua` | T1.2 → T5.2 |
| `core/LauncherSetup.lua` | T1.1 → T5.4 |
| `core/MultiMeters.lua` | T4.3 → T5.4 |
| `locales/enUS.lua` | T1.1, T3.1, T5.1, T5.2: land one at a time |

## Commit strategy

One commit per task, on `feat/2026-09-23-review-audit-remediation`. Each commit that moves the count
carries `docs/test-cases.md` and the README badge.

Messages follow the repo's plain-sentence style:

1. `Make the latch answer every show path, and arm no refresh clock while stood down` (T0.1 + T1.1, squashed)
2. `Publish the Slash wrapper's DisabledLine only when the dispatcher has one` (T0.4 + T1.2)
3. `Pin the player into the rows the window actually draws` (T0.2 + T2.1)
4. `Send chat through Compat, and say so when no sender exists` (T0.3 + T3.1)
5. `Record the pre-change render capture` (T4.0)
6. `Keep rows bound to slots across refreshes; walk only live cells` (T4.1, plus the post-change bundle)
7. `Evaluate visibility for the debug line only when debug is on` (T4.2)
8. One commit each for T4.3 and for T5.1 through T5.8.

**Checkpoint CP-final.** Complete the `03_SMOKE_TESTS.md` sign-off table. The version bump and the
automated-test record regeneration belong to `/wow-addon:bump-version`, not to this plan.
