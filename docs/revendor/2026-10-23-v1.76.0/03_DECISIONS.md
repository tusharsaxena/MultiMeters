# 03 — Decisions (MultiMeters)

No interview. This re-vendor ran as item MM-RV of the Ka0sAddonsCommonTasks bundle
`docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`. The item spec says to list the candidates without
adopting them here, because the run's own items do that. The decisions come from that bundle's
`inputs/OWNER_SCOPE.md` and `03_SPEC.md`.

| Candidate | Decision | Source |
|---|---|---|
| `W.TestStrip` `kind = "sim"` | Adopt, in item MM-17 (its own commit) | OWNER_SCOPE A, C; 03_SPEC end state 2 and 4 |
| Header word gone while the strip shows | Adopt, in item MM-01 (its own commit) | OWNER_SCOPE A; 03_SPEC D-WORD |
| `LibKa0s-Sim-1.0` | Adopt, in items MM-10 to MM-20; MultiMeters#60 closes on merge | OWNER_SCOPE B4; 03_SPEC end state 4 |
| `LibKa0s-Item-1.0`, `LibKa0s-Glow-1.0` | Not adopted: no use in this addon | lead, as in `2026-10-22-v1.75.0/` |

No GitHub issue is filed. The item spec forbids it, and nothing here is declined beyond what the
v1.75.0 bundle already recorded.
