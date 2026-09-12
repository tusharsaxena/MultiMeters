# 04 — Execution plan (B1 + B2, one commit)

**Characterization.** Delete only the local layers from `tests/wow_mock.lua` and run the suite
before porting any test. The run is 1747 passed and 32 failed. Every failure reads a retired name
(`__busRegistry`, `NS:__fireEvent`, `__moduleOrder`, `__modules`), or runs un-enabled because
`tests/run.lua` gated its enable kick on `NS.__enableAll`. None was a behavior difference. That makes
the port mechanical and tells us what "green again" has to mean.

**Files.**

- `tests/wow_mock.lua`: the header's list of what the file overwrites loses the Ace bullets. The
  message half and the `NewAddon` wrapper are deleted, and a note in their place lists the kit
  surfaces a suite reaches instead.
- `tests/run.lua` and `tests/perf.lua`: `NS:__enableAll()` becomes
  `mocks.LibStub("AceAddon-3.0"):EnableAddon(NS)`, guarded on `NS.name`, which `NewAddon` stamps.
- Test ports, identifier for identifier:
  - `mocks.__busRegistry` becomes `mocks.__msgRegistry` in `test_aggregator_sort`, `test_perfsetup`,
    `test_provider`, `test_roster`, `test_visibility` and `test_window`.
  - `inst.NS:__fireEvent(...)` becomes `inst.mocks.__fireEvent(...)` in `test_lifecycle` and
    `test_degraded`. It answers a count, so the one `assertTrue` on it becomes `assertEqual(…, 1)`.
  - `NS.__moduleOrder` becomes the `moduleName`s of `NS.orderedModules`, and `NS.__modules` becomes
    `NS.modules`.
- `docs/testing.md`: the "What the mock models" section says AceEvent and AceAddon are the kit's.

**The proving assertion.** Every case that ran before still runs, and none of their expectations is
loosened, so the total is 1779 / 0 / 0 again. `tests/perf.lua` exits 0 on the kit's cascade. One
ordering changes: the addon's `OnEnable` now runs before its modules', as the client orders it, and
no case depended on the old order.

**Commit boundary.** `58023d8`, "Tests: the harness takes kit 17's AceEvent and AceAddon whole".
