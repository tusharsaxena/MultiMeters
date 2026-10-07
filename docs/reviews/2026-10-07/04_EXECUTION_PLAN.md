# Execution plan — Ka0s Multi Meters, review of 2026-10-07

The green gate after **every** task: `lua tests/run.lua` (0 failed) and `luacheck .` (0/0), both run through `ka0s-bounded`. Every task that moves the pass count regenerates `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) and updates the README `[tests]` badge in its own commit (`testing-§5`). The commit prefixes below are placeholders, and the collection-wide plan may renumber them.

## Milestones

### M1: Correctness (C-01, C-03, C-04)

**Done when:** the three new cases are green and were seen red against the old code (`testing-§12`), the inventory and badge match, and the gate is green.

| Task | Role | Implements | Files |
|---|---|---|---|
| T1 | lua-fixer | C-01 (F-001, F-002) | `modules/Aggregator.lua`, `tests/test_aggregator.lua`, `docs/test-cases.md`, `README.md` |
| T2 | ux-cleanup | C-03 (F-004) | `modules/WindowManager.lua`, `tests/test_windowmanager.lua`, `docs/test-cases.md`, `README.md` |
| T3 | ux-cleanup | C-04 (F-005) | `settings/Slash.lua`, `tests/test_slash.lua`, `docs/slash-dispatch.md`, `docs/test-cases.md`, `README.md` |

### M2: Roster retry (C-02)

**Done when:** the new case is green and was seen red, `tests/test_roster.lua:330` passes **unedited**, and the new `rosterPartial` scenario in `tests/perf.lua` reports at most one walk per pass.

| Task | Role | Implements | Files |
|---|---|---|---|
| T4 | lua-perf | C-02 (F-003) | `modules/Roster.lua`, `modules/Aggregator.lua`, `tests/test_roster.lua` (new case only), `tests/perf.lua`, `docs/performance.md` (scenario row), `docs/test-cases.md`, `README.md` |

### M3: Hygiene (C-05, C-06)

**Done when:** `grep -rn 'local function plainTruth' core modules` returns nothing, `grep -rn BackButton core modules settings tests` returns nothing, and the gate is green.

| Task | Role | Implements | Files |
|---|---|---|---|
| T5 | lua-refactorer | C-05 (F-006, F-007) | `core/Secrets.lua`, `modules/Aggregator.lua`, `modules/Tooltip.lua`, `modules/Provider.lua`, `tests/test_secrets.lua`, `docs/test-cases.md`, `README.md` |
| T6 | dead-code-remover | C-06 (F-008) | `modules/DrillDown.lua`, `modules/Window.lua`, `tests/test_drilldown.lua`, `docs/module-map.md`, `docs/test-cases.md`, `README.md` |

### Deferred

F-009 (vehicle pair): no task. The reason is recorded in `02_PROPOSED_CHANGES.md`, *Deferred*.

## Critical path and concurrency map

- **`docs/test-cases.md` and `README.md` (the badge) are touched by T1–T6.** These must be serialized, or regenerated once at each task's commit in sequence. Never merge two inventories by hand.
- **`modules/Aggregator.lua`** is touched by T1 (`placeSource`/`foldPet`), T4 (`Build`) and T5 (`plainTruth`), so these serialize as T1 → T4 → T5.
- T2 (`WindowManager.lua`) and T3 (`Slash.lua`) are disjoint from each other and from T1 in source. They are **parallelizable** in source, but their inventory and badge commits still go in sequence.
- T6 (`DrillDown.lua`, `Window.lua`) is disjoint from every other task's source.

Order: T1 → T2 → T3 → **checkpoint A** → T4 → **checkpoint B** → T5 → T6 → **checkpoint C**.

## Checkpoints

- **A (after M1):** gate green. A coordinator re-runs the probe from `01_FINDINGS.md` F-001 (pet 400 ahead of owner 100) and confirms 500.
- **B (after M2):** gate green, plus `ka0s-bounded lua5.1 tests/perf.lua` with `rosterPartial` present. Its `api/iter` is within one walk of `refresh20x7`'s.
- **C (after M3):** gate green, plus the sighted complexity run (`ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`), checking that `placeSource` is still at or under CCN 15. Then hand `03_SMOKE_TESTS.md` to the owner.

## Commit strategy

One commit per task:

- `RV-MM-01: fold a pet that outranks its owner into the owner's total (F-001, F-002)`
- `RV-MM-02: rename keeps a case-only change of the window's own name (F-004)`
- `RV-MM-03: /mm window copy resolves names with spaces (F-005)`
- `RV-MM-04: retry a partial roster once per pass, not per lookup (F-003)`
- `RV-MM-05: Secrets.PlainTruth is the one secret-boolean read (F-006, F-007)`
- `RV-MM-06: remove the retired drill-down back button (F-008)`

Each commit carries the session attribution trailers. No version bump, tag or merge without the owner's go-ahead.
