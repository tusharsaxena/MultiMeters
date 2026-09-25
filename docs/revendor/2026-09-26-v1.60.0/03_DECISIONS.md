# 03 — Decisions

No interview was held. Every candidate was decided in advance by the owner-approved diagnostics
rollout plan (`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND/03_EXECUTION_PLAN.md`, the
M3 section, and `OWNER_RULINGS.md`). That plan says to file **no decline issues** for these, so none
was filed.

| # | Candidate | Decision | Where it lands |
|---|---|---|---|
| B1 | Diagnostics helper and `brandName` | **adopt, later in this run** | DR-MM-02 (re-host the `diag` report on the helper, retire `diag`) and DR-MM-03 (the missing DX-MM sections, `Kit.diagnostics` wiring) |
| B2 | `diagnostics` verb, live while disabled | **adopt, later in this run** | DR-MM-02 / DR-MM-03, with the verb itself; `tests/test_disabled.lua`'s `RESERVED` gains it then |
| C1 | WidgetsDragHandle close mark | not a candidate (no DragHandle in this addon) | — |
| A | Buffer 3000 / slack 128 | not an adoption (plan ruling) | Buffer prose is DR-MM-05 |

Nothing is implemented from this bundle in the re-vendor commit beyond the blocker fix, so there is
no `04_EXECUTION_PLAN.md`; the rollout plan is the execution plan.
