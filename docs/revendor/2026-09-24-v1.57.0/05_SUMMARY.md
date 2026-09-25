# 05 — Summary: LibKa0s v1.56.0 -> v1.57.0

## The tag, and the per-file minors

The first M5-MM commit (`9df6cc9`) moves the vendored copy from **v1.56.0**, the base the
`CLAUDE.md` provenance line named, to **v1.57.0** (commit `aa37bc9`). It copies both payloads and
rolls the provenance line. One file moves a minor: **Launcher 2 -> 3**. The kit stays at revision 26
with identical bytes. The full record is in `01_DELTA.md`.

## What arrived without being asked for

- **Launcher 3**: the LDB object's `OnTooltipShow` is now the library's own status tooltip, drawn on
  every hover, including while the addon is disabled.

## Contract blockers

**None** (`01_DELTA.md` 3g).

## Adopted

This was fixed by the plan's M5 row rather than put to an interview. The second M5-MM commit adopts
it, in `core/LauncherSetup.lua`:

| Field | What this addon passes | Why |
|---|---|---|
| `version` | `NS.Version()`, the TOC metadata through core/EnvSetup.lua | The reader `/mm version` and the options header use. Not `NS.version`, which is the hardcoded fallback. |
| `isLocked` | `WindowManager:IsLocked()` | The accessor the Master-controls *Lock frame* row reads: Yes only while every window is locked. |
| `isTestMode` | `NS.State.testMode` | The *Test mode* row's store, and the flag `/mm test` toggles. |
| `leftClickLabel` | `L["Toggle windows"]`, asked on every show | Rung (a) in `ADDONS.md`, "its windows". |
| `onTooltipShow` | **removed** | The old hook drew only a title, a version and both click hints, all of which the library now draws (anti-pattern #89). This addon has no lines of its own to add. |

`slash` is not passed. The disabled hint reads `/mm enable` out of `disabledLine()`, which is the
Slash dispatcher's `DisabledLine()`. The two locale keys that only the old hook used are gone, and
`Toggle windows` has been added.

## Declined, skipped

Nothing.

## Gates

Every figure comes from `ka0s-bounded`, run from the repo root.

| Point | Tests | Lint | Complexity |
|---|---|---|---|
| Before the copy (v1.56.0) | 2035 / 0 / 0 | 0 / 0 in 137 files | not run |
| After the copy (v1.57.0) | 2035 / 0 / 0 | 0 / 0 in 137 files | not run (no authored Lua changed) |
| After the adoption | 2041 / 0 / 0 | 0 / 0 in 137 files | 0 functions over CCN 15 |

## Open

- In-game: hover the minimap button enabled, disabled (`/mm disable`), with every window locked,
  and in test mode. This is the owner's smoke #1 re-run after M5.
