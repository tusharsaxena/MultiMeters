# 05 — Summary: LibKa0s v1.31.0 → v1.32.0

| | |
|---|---|
| From | v1.31.0, kit revision 17 |
| To | **v1.32.0** (local tag `e18dd12`, not pushed), kit revision **17** |
| Branch | `fix/2026-09-12-triage` |

## Per-file minors

| File | v1.31.0 | v1.32.0 |
|---|---|---|
| `Options.lua` (`MINOR`) | 15 | **16** |
| `Slash.lua` (`MINOR`) | 7 | **8** |
| every other file | unchanged | unchanged |

There was no cross-major skew before or after the copy. Nothing was removed upstream or deleted
here, and `tests/_kit/run-automated-tests.sh` stays `100755`.

## Adopted

- **B1 + B2**, commit `3c41618`: the bulk bracket, with the seam's own changed-rows count, and the
  `/mm resetall` fix.

## Lines each act now logs

| Act | Line |
|---|---|
| A page's Defaults | `[Set] reset <page>: N rows` (`0 rows` when already at defaults) |
| Columns' Defaults | `[Set] reset columns: N rows` |
| Copy from one window to another | `[Set] copy from '<src>' to '<dst>': N rows` |
| Reset all settings, `/mm resetall`, degraded reset-all, AceDBOptions Reset Profile | `[Set] reset profile '<name>' to defaults` |
| AceDBOptions Copy From | `[Set] copied profile '<src>' → '<dst>'` |
| Profile switch | `[Profile] switched to '<name>'` (unchanged) |
| A sort, resize or segment pick | one `[Set] <path> = <value>` per row (unchanged) |

## Gates

| Step | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Baseline, before the copy (`73dde5f`) | 1804 / 0 / 0 | 0 / 0 |
| After the copy (`f60e229`) | 1804 / 0 / 0 | 0 / 0 |
| Tests written, host unchanged | 1800 / 15 failed | — |
| After B1 + B2 (`3c41618`) | 1816 / 0 / 0 | 0 / 0 |

`tests/perf.lua` exits 0. `lizard -l lua -C 15 -w -x "./libs/*" -x "./tests/_kit/*" .` reports no
function above CCN 15. `tests/test_vendor_sync.lua` ran rather than skipped at every step.
