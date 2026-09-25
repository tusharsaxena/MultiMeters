# 05 — Summary: LibKa0s v1.57.0 -> v1.58.0

## The tag, and the per-file minors

The first M6-MM commit (`3500c15`) moves the vendored copy from **v1.57.0**, the base the
`CLAUDE.md` provenance line named, to **v1.58.0** (commit `34931c9`). It copies both payloads,
rolls the provenance line, and re-pins the nine host cases that tested contracts the library
retired. One file moves a minor: **Launcher 3 -> 4**. The kit stays at revision 26 with identical
bytes. The full record is in `01_DELTA.md`.

## What arrived without being asked for

- **Launcher 4**: left-click opens the settings panel in either state; the tooltip's hints are
  fixed at *Open settings* / *Options menu*; the disabled left-click refusal is gone; `onClick`,
  `leftClickLabel`, `disabledLine` and `slash` are ignored.

## Contract blockers

**None** (`01_DELTA.md` 3g).

## Adopted

This was fixed by the plan's M6 row rather than put to an interview. The second M6-MM commit adopts
it, in `core/LauncherSetup.lua`. The entries match the row standard v2.67.0's `ADDONS.md` records for
this addon: *Enabled · Locked · Test mode · Show window (its meter windows)*.

| Field | What this addon passes | Why |
|---|---|---|
| `isEnabled` | `not NS.IsDisabled()` (**changed** from `not NS.IsStoodDown()`) | The Enabled box has to read the store `setEnabled` writes. The perf latch belonged to the retired left-click gate, and as a menu box it would untick Enabled during a capture. |
| `setEnabled` | the `enable` / `disable` verb's `NS.COMMANDS` handler | The same path `/mm enable` and `/mm disable` run (`cli:CliSet("enabled …")`). |
| `isLocked` | `WindowManager:IsLocked()` (M5, kept) | The *Lock frame* row's accessor. |
| `toggleLock` | the `lock` verb's handler, bare | `/mm lock` with no argument toggles. |
| `isTestMode` | `NS.State.testMode` (M5, kept) | The *Test mode* row's store. |
| `toggleTestMode` | the `test` verb's handler, bare | `/mm test`; its combat refusal is the verb's. |
| `isWindowShown` | `WindowManager:AnyShown()` (new) | The question a bare `/mm toggle` asks. `Toggle` now calls it, so the checkbox and the click act on one answer. |
| `toggleWindow` | the `toggle` verb's handler, bare | `/mm toggle`; its perf-suspend refusal line is the verb's. |
| `version` | `NS.Version()` (M5, kept) | |
| `onClick`, `leftClickLabel`, `disabledLine` | **removed** | Retired at minor 4. |

The handlers are looked up in `NS.COMMANDS` at click time, not published separately from
`settings/Slash.lua`. That way the menu and the verb are one function, and a test that swaps a
verb's handler sees the menu click arrive there.

The `Toggle windows` locale key is removed. The Minimap button row's help text now describes the new
clicks.

Tests: `tests/mock_menu.lua` is the library's `MenuUtil` fake, carried into this repo because the
kit does not ship it. The eight new cases in `tests/test_launchersetup.lua` cover entries and order,
each toggle landing on its verb's handler, Enabled both ways, the three feature entries acting and
reading back, graying while disabled, the perf capture leaving the menu live, the no-`MenuUtil`
fallback, and no retired field in the source.

## Declined, skipped

Nothing.

## Gates

Every figure comes from `ka0s-bounded`, run from the repo root.

| Point | Tests | Lint | Complexity |
|---|---|---|---|
| Before the copy (v1.57.0) | 2041 / 0 / 0 | 0 / 0 in 137 files | not run |
| After the copy and re-pins (v1.58.0) | 2037 / 0 / 0 | 0 / 0 in 137 files | not run (no authored production Lua changed) |
| After the adoption | 2045 / 0 / 0 | 0 / 0 in 138 files | 0 functions over CCN 15 |

## Open

- In-game: smoke SM-11a, SM-11b and SM-02's launcher half (`docs/smoke-tests.md`). That means hover,
  left-click and each right-click entry while enabled, then while disabled (grayed entries), then
  during a perf capture. This is the owner's re-check of the minimap buttons after M6.
