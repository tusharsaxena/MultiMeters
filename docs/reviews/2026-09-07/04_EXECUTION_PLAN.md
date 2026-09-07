# Execution plan — Ka0s Multi Meters, review of 2026-09-07

Implements `02_PROPOSED_CHANGES.md`. Five milestones, ordered by risk and by file contention.

**No milestone here has an upstream half.** No finding this pass landed in `libs/` or
`tests/_kit/`, and no task below touches a path under either. If one appears to, it is the
wrong task.

---

## M1 — Make the trace free when disarmed

**Done when:** `lua tests/perf.lua`'s `probeOverheadOff` figure is back within ~200 bytes/iter of
the `0e74319` baseline of **303,415.8**, and `luacheck .` plus `lua tests/run.lua` are both clean.

| Task | Role | Implements | Files |
|---|---|---|---|
| M1-T1 | lua-refactorer | C-01 (publish `Diagnostics.feignArmed`, keep `IsFeignTraceArmed` over it) | `core/Diagnostics.lua` |
| M1-T2 | lua-refactorer | C-01 (gate the two `cast` sites and the `prune` site; add the local `armed()`) | `modules/Feign.lua` |
| M1-T3 | perf-engineer | C-01 (hoist `D` and `traceArmed` above the source loop at `:1472`; gate the `judge` table build) | `modules/Aggregator.lua` |
| M1-T4 | doc-corrector | C-01's comment half — the two comments asserting the false cost | `modules/Aggregator.lua:1485-1486`, `modules/Feign.lua:99-100` |

**Concurrency:** M1-T1 must land first — T2 and T3 read the field it publishes. **T2 and T3 are
parallelizable** (disjoint files). T4 touches the same two files as T2/T3 and must **serialize
after both**; better still, fold T4 into T2 and T3 so the comment moves with the code it
describes.

**Checkpoint C1.** Human runs `lua tests/perf.lua` and reads `probeOverheadOff` before M2 opens.
This is the only milestone whose success is a *number*, and it is cheap to confirm.

---

## M2 — Make the recording answer its question

**Done when:** a synthetic 200-observation `judge` burst leaves the first `cast` entry present,
and a not-in-group eviction produces a `prune` line naming a real prior state.

| Task | Role | Implements | Files |
|---|---|---|---|
| M2-T1 | lua-refactorer | C-02 part 1 (the `castSeen` admission filter + suppressed counter) | `core/Diagnostics.lua` |
| M2-T2 | perf-engineer | C-02 part 2 (write-index ring, replacing `table.remove(log, 1)`) — R-09 | `core/Diagnostics.lua` |
| M2-T3 | lua-refactorer | C-03 (trace the `unit == nil` branch; hoist `wasState` above `:266`) — R-03, R-13 | `modules/Feign.lua` |
| M2-T4 | lua-refactorer | C-02's report half — print the suppressed-`judge` counter in `reportFeign` | `core/Diagnostics.lua` |

**Concurrency:** M2-T1, T2 and T4 all touch `core/Diagnostics.lua` in the same ~40 lines →
**must serialize**, in the order T2 → T1 → T4 (the ring shape first, then what is admitted into
it, then what the report says about it). **M2-T3 is parallelizable** with all three — disjoint
file, and it only depends on M1-T2's `armed()` helper already existing.

**Risk callout for M2-T1.** The admission filter changes what the report *contains*. It is the
one task here that can lose evidence if it is wrong. Do not merge it without M3-T2's case.

---

## M3 — Close the coverage the defects came through

**Done when:** `lua tests/run.lua` reports **1502 passed, 0 failed**, and each new case has a
`-- red under:` comment naming a mutation that has been **verified to actually redden it** by
applying that mutation locally and watching the case fail.

| Task | Role | Implements | Files |
|---|---|---|---|
| M3-T1 | test-author | C-05 — the `judge` boundary case | `tests/test_diagnostics.lua` |
| M3-T2 | test-author | C-05 — the ring-overflow case (**the M2-T1 gate**) | `tests/test_diagnostics.lua` |
| M3-T3 | test-author | C-05 — the disarmed-allocation case, or its `tests/perf.lua` scenario if a robust count is unavailable | `tests/test_diagnostics.lua` **or** `tests/perf.lua` |
| M3-T4 | test-author | C-05 — the two `Feign` cases (traced eviction, pre-decision state) | `tests/test_feign.lua` |
| M3-T5 | test-author | C-05 — the armed-field / armed-accessor agreement case | `tests/test_diagnostics.lua` |

**Concurrency:** T1, T2, T3, T5 all append to `tests/test_diagnostics.lua` → **serialize**, or
have one agent write all four in one pass (preferred — they share fixtures). **T4 is
parallelizable** (disjoint file).

**M3-T3 has a standards fork in it.** If the case lands in `tests/perf.lua`, it is a
**scenario**, not a test case, and must **not** appear in `docs/test-cases.md` or move the
badge (`testing-§7`). Decide which before writing, and say which in the commit message — the
expected count in M4 depends on it (1502 if in the suite, 1501 if the allocation case goes to
`perf.lua`).

**Checkpoint C2.** Human confirms every `-- red under:` was actually falsified, not merely
written. This is the specific failure mode that produced R-04's gap in the first place, and
asserting it is cheap now and expensive later.

---

## M4 — Re-align the evidence

**Done when:** `docs/test-cases.md`'s total, `README.md:7`'s badge and `lua tests/run.lua`'s
output are the same number, and `tests/perf.lua`'s recorded figure matches a run made after M1.

| Task | Role | Implements | Files |
|---|---|---|---|
| M4-T1 | release-hygiene | C-04 — `lua tests/run.lua --list > docs/test-cases.md` | `docs/test-cases.md` (generated) |
| M4-T2 | release-hygiene | C-04 — badge | `README.md:7` |
| M4-T3 | perf-engineer | C-06 — re-record the measured figure, re-derive `PROBE_OFF_BYTES_CEILING`, write the reason | `tests/perf.lua:539-564` |
| M4-T4 | doc-corrector | C-06 — the two quoted figures | `docs/performance.md:225,244` |
| M4-T5 | doc-corrector | C-08 — the LibKa0s version quote | `tests/test_vendor_sync.lua:14` |
| M4-T6 | ux-cleanup | C-08 — the rejected-argument message | `settings/Slash.lua:474-482` |

**Concurrency:** M4-T1 **must run after M3 completes** — it is a generator over the final case
set, and running it early bakes in a number that then goes stale again. T2 depends on T1's
output. T3, T4, T5, T6 are **all parallelizable** with each other and with T1/T2 (disjoint files).

**M4-T6 caveat:** it adds a branch that M3 does not cover. Either add a case for it (moving the
count again — do it **before** M4-T1) or accept it uncovered and say so. Do not let M4-T1 run
between the two.

**Never hand-edit** `docs/test-cases.md` or the badge number. `docs/automated-tests/RESULTS.md`
is **not in this milestone and not in this plan** — its checkpoint is release.

---

## M5 — Peel `core/Diagnostics.lua` back under the cap

**Done when:** every shipped `.lua` file that this changeset touched is ≤1500 LOC, the suite is
still green at M4's count, and the TOC's new entry carries an annotation saying why it loads
where it does.

| Task | Role | Implements | Files |
|---|---|---|---|
| M5-T1 | lua-refactorer | C-07 — extract the feign-trace section | `core/Diagnostics.lua` → new `core/DiagnosticsFeign.lua` |
| M5-T2 | lua-refactorer | C-07 — publish `out` / `shown` / `probe` on the `Diagnostics` table rather than duplicating them | `core/Diagnostics.lua` |
| M5-T3 | toc-maintainer | C-07 — TOC entry, annotated (`toc-file`) | `MultiMeters.toc` |
| M5-T4 | test-author | C-07 — `tests/test_loadorder.lua` already asserts TOC/disk agreement in both directions; confirm it reddens for a missing entry, then greens | `tests/test_loadorder.lua` (verify only) |

**Concurrency:** strictly serial, T2 → T1 → T3 → T4. T2 first because T1 depends on the helpers
being reachable from the new file.

**This milestone is last on purpose.** It moves the code the whole review is about, and it is the
only task set here with no behaviour change to justify itself — so it runs after the
characterization cases from M3 exist and are green, per the standard's rule against refactoring
untested code.

**Checkpoint C3.** Human runs the full pre-flight (`luacheck .`, `lua tests/run.lua`) and
confirms the count is unchanged by M5. A moved case count during a pure extraction means
something was lost.

---

## Critical path

```
M1-T1 ──┬── M1-T2 ──┐
        └── M1-T3 ──┼── [C1: perf figure] ── M2 (T2→T1→T4) ──┐
                    │            └── M2-T3 (parallel) ───────┤
                    │                                        ├── M3 ── [C2: red-under verified] ── M4-T1 → M4-T2
                    │                                        │              M4-T3/T4/T5/T6 (parallel, any time after M1)
                    └────────────────────────────────────────┘
                                                                                    └── M5 (serial) ── [C3]
```

**File-contention serialization points, explicit:**

- `core/Diagnostics.lua` — M1-T1, M2-T1, M2-T2, M2-T4, M5-T1, M5-T2. **Six tasks, one file.**
  This is the plan's real bottleneck; consider assigning all six to one agent in sequence rather
  than coordinating handoffs.
- `modules/Feign.lua` — M1-T2, M1-T4, M2-T3. Serialize.
- `modules/Aggregator.lua` — M1-T3, M1-T4. Serialize (or fold).
- `tests/test_diagnostics.lua` — M3-T1, T2, T3, T5. Serialize or single-agent.
- Everything in M4 except T1/T2 is genuinely disjoint and can run whenever M1 is done.

---

## Commit strategy

One commit per milestone, except M4 which splits so the generated file has its own boundary.

1. `perf(feign): the trace costs nothing while nobody is recording` — M1. Body cites R-01 with
   the 310158.1 → 303416 figure and names `performance-§2`.
2. `fix(feign): the recording keeps the lines it exists to keep` — M2. Body cites R-02, R-03,
   R-09, R-13, and states plainly that the pre-fix report could not answer issue #25.
3. `test(feign): cases for the three boundaries nothing was pinning` — M3. Body cites R-04 and
   lists each `-- red under:` and the mutation it was falsified against.
4. `docs: the inventory and the badge catch up with the suite` — M4-T1, M4-T2. Generated file
   only; no hand edits.
5. `chore: re-record the perf baseline, and three one-liners` — M4-T3…T6. Body cites R-07 with
   the recorded-vs-actual gap and the reason for the new ceiling.
6. `refactor(diagnostics): peel the feign trace into its own file` — M5. Body cites R-08 and
   `layout-§1`, and notes that this changeset is what pushed the file over the cap.

Commit 4 must not be squashed into 3: a generated artifact with its own commit is what lets a
future reader see the count move for a reason.
