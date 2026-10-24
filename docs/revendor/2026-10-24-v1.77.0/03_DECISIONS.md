# 03 — Decisions (MultiMeters)

No interview. This re-vendor ran as item MM-RV of the Ka0sAddonsCommonTasks bundle
`docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`. The item spec says the adoptions this run needs are the
MM-KB and MM-ZS items, that every other candidate is recorded as deferred, and that nothing is filed.

| Candidate | Decision | Source |
|---|---|---|
| Keybindings tab (`KeybindingsTab`, `KeybindRows`, `KEYBINDS_UNCHANGED`, kit 42 binding mock and checks) | Adopt, in item MM-KB (its own commit) | MM-RV item spec; OWNER_SCOPE 015 |
| `O.StrataTooltip` (kit 42 layer recorder for its tests) | Adopt, in item MM-ZS (held for the owner) | MM-RV item spec; OWNER_SCOPE 030 |
| DragHandle `level`, `ignoreParentAlpha`, `ApplyLevel` | Deferred (run 2026-10-24): MultiMeters draws no DragHandle | MM-RV item spec |
| `LibKa0s-Glow-1.0` | Deferred (run 2026-10-24): no use in this addon | MM-RV item spec; as in `2026-10-22-v1.75.0/` |

No GitHub issue is filed. The item spec forbids it.
