# 05 — Summary: LibKa0s v1.30.0 → v1.31.0

| | |
|---|---|
| From | v1.30.0, kit revision 16 |
| To | **v1.31.0** (local tag `e7e1962`, re-cut after review and not pushed), kit revision **17** |
| Branch | `fix/2026-09-12-triage` |

## Per-file minors

| File | v1.30.0 | v1.31.0 |
|---|---|---|
| `OptionsWidgets.lua` (`WIDGETS_MINOR`) | 14 | **15** |
| `OptionsCompose.lua` (`COMPOSE_MINOR`) | 3 | **4** |
| `Perf.lua` (`MINOR`) | 10 | **11** |
| every other file | unchanged | unchanged |

The addon had no cross-major skew before or after the copy. No file was removed upstream, and nothing
was deleted from `libs/` or `tests/_kit/`. `tests/_kit/run-automated-tests.sh` stays `100755`.

## What reached the addon for free (class A)

- The perf capture ring's prune is traced (Perf 11), through this addon's console path, with debug
  logging off. A test now pins that.
- A path-less Options row reads and writes through its own `get` / `set` (OptionsWidgets 15). No row
  here lacks a path.
- The kit's real AceTimer, AceConsole and AceAddon object model on `NS`, and its review fixes
  (`handle.cancelled`, the repeating timer's period, the narrowed no-name `NewAddon`). No test here
  read the old shapes.

## Adopted

- **B1 + B2**, commit `58023d8`: the harness's own AceEvent message half and AceAddon module layer are
  deleted, and the suites read the kit's surfaces.

## Declined

- **B3**, OptionsCompose `spec.bind`: not applicable, since no page here edits registry records.
  **Not filed**, because filing was skipped by instruction for this run.

## Gates

| Step | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Baseline, before the copy (`9a486ed`) | 1779 / 0 / 0 | 0 / 0 |
| After the copy (`48fa075`) | 1779 / 0 / 0 | 0 / 0 |
| Characterization, mock changed and tests not ported | 1747 / 32 failed | — |
| After B1 + B2 (`58023d8`) | 1779 / 0 / 0 | 0 / 0 |

`tests/perf.lua` exits 0 after the adoption. `lizard -C 15 -w` over every Lua file the branch touched
reports no function above CCN 15. `tests/test_vendor_sync.lua` ran rather than skipped at every step.

The branch's later commits in this wave are not part of the re-vendor: `48804ad` (the pinned segment
as a row), `8546df9` (the Roster forget and its trace), `d9a0834` (`export.metric` as a row) and
`16bbfe0` (named state). With them the suite stands at 1796 / 0 / 0.
