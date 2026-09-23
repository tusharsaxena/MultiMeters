# 05 — Summary: LibKa0s v1.54.2 → v1.55.0

## The tag, and the per-file minors

Phase 5 moved the tag from **v1.54.2** to **v1.55.0** (`bb161b7`) in `a5a1014`: both payloads, the
provenance line, and kit revision 24 → 25. The per-file minor table is in `01_DELTA.md` 3c. No
existing file's minor moved. Three new majors arrived at minor 1: `Compat.lua`, `Bus.lua` and
`Schema.lua`.

## Delivered for free (class A)

- **Test kit revision 25**: the layout-§1 cap census gate, the `.gitattributes` body case in
  `test_eol`, suite declaration keyed by `(basename, directory)`, and the commit SHA in the
  automated-test record. All of it was wired in `a5a1014`.
- No consumed major changed, so nothing else arrived through the re-vendor alone.

## Contract blockers

**None** (`01_DELTA.md` 3g). No consumed major moved a minor, and the one `__Attach*` site,
`settings/Schema_Compose.lua:479` (`__AttachCompose`), sits on Compose minor 7, which is unchanged.

## Adopted

| Candidate | Commit | Cases | Gate after |
|---|---|---|---|
| C1 `LibKa0s-Compat-1.0`: the four spell and spec readers on `NS.Compat`, the three guards on `NS.Secrets`, and `modules/Roster.lua` routed through the seam | `6ace3c2` | 2 characterization cases (green before the move), 5 new, 1 corrected fixture, 2 `SEAMS` rows | 1939 passed, 0 failed, 0 skipped; lint 0/0 in 125 files |
| C2 `LibKa0s-Bus-1.0`: the stand-down record, the stand-up moved first, the fourteen wire strings renamed to PascalCase, and `Constants.MSG` through `Catalog` | `0aee02a` | 3 characterization cases (green before the move), 6 new, 2 `SEAMS` rows | 1948 passed, 0 failed, 0 skipped; lint 0/0 in 125 files |

The runner's `Kit.setSurfaceSource{...}` map gained the `LibKa0s-Compat-1.0` and `LibKa0s-Bus-1.0`
rows, which the compat spec's §4 gate amendment requires. Each adopted seam names its major in
`docs/ARCHITECTURE.md`:

- the module map rows for `Compat.lua` and `Secrets.lua`
- the compat-layer documentation-map row
- `## Message bus`
- `## Known limitations` (the degraded bus)

`docs/compat-layer.md`, `docs/module-map.md`, `docs/disabled-state.md`, `docs/common-tasks.md` and
`docs/scope.md` follow. No `## Documented deviations` row covered either adoption, so none retires.

## Declined

| Candidate | Why | Issue |
|---|---|---|
| C3 `LibKa0s-Schema-1.0`, partial adoption (primitives, registry, bracket) | The spec and the API document both say this repo MAY defer (`3b-specs/schema.md:548`; `docs/api/Schema/version-1-docs.md:372-373`). Adopting deletes no host line, and it forks every primitive into two code paths. MultiMeters' all-or-nothing `SetByPaths` keeps it off `Set` in minor 1. | [#52](https://github.com/tusharsaxena/MultiMeters/issues/52), `state:triaged`, `severity:medium` |

## Skipped or unreached

None. All three candidates were decided.

## Gates

Each figure comes from `ka0s-bounded lua tests/run.lua` and `ka0s-bounded luacheck .`, run from the
repo root.

| Point | Tests | Lint |
|---|---|---|
| Baseline, at `a5a1014` | 1932 / 0 / 0 | 0 / 0 in 125 files |
| C1 characterization added, code unchanged | 1934 / 0 / 0 | — |
| After `6ace3c2` (Compat) | 1939 / 0 / 0 | 0 / 0 in 125 files |
| C2 characterization added, code unchanged | 1942 / 0 / 0 | — |
| After `0aee02a` (Bus) | 1948 / 0 / 0 | 0 / 0 in 125 files |

`ka0s-bounded lua tests/perf.lua` exited 0 after the Bus commit. Its timings are for orientation
only. `lizard` was not run: no adopted function is long enough to need it, and it is not part of
the commit gate.

## Open

- **`modules/Roster.lua` still reads `_G.GetSpecializationRole` directly.** The compat spec leaves it
  inline (OPEN-6): it is a single-consumer member with no shim in the library. It belongs in this
  repo's own `core/Compat.lua` if it is to leave the feature module.
- **The kit fails when run from outside the repo root.** `lua <repo>/tests/run.lua` gives 10
  failures from another working directory (Phase 5's report). That is an [upstream] kit behavior,
  and it was not re-checked here.
- **Checks owed in game:**
  - Tooltip and drill-down spell names and icons are unchanged, since both now come from the library.
  - Disable and enable with `/mm disable` and `/mm enable`: every window's refresh and the Profiles
    page's live refresh come back, and nothing fires while the addon is disabled.
  - A mid-pull `/reload` renders the same, which confirms the guards are the library's.
