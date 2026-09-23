# 05 — Summary: LibKa0s v1.55.0 -> v1.56.0

## The tag, and the per-file minors

The re-vendor commit moves the tag from **v1.55.0** (the base the `CLAUDE.md` provenance line
named, cross-checked against `a5a1014`) to **v1.56.0** (`4622018`): both payloads, the provenance
line, and kit revision 25 -> 26. Fifteen files moved a minor: Core 8, Lifecycle 2, Bus 2, Schema 2,
Item 2, Media 4, Widgets 10, DebugLog 13, Slash 15, Launcher 2, Options 24, OptionsWidgets 31,
OptionsTabs 4, OptionsScroll 4, Perf 13. Env, Compat, Pool, WidgetsDragHandle, OptionsCompose and
PerfPanel are unchanged. The full table is `01_DELTA.md` 3c.

No span bundle was written and no base correction was owed (`01_DELTA.md` Step 0 and 3h; the span
record is MM-30's).

## Delivered for free (class A)

- **OptionsWidgets 31**: the slider's live commit and the color picker drag get their 50 ms throttle
  with this addon's nil-returning `scheduleTimer`, where before they committed about once a frame.
- **OptionsTabs 4**: a banner page no longer leaks a `Dropdown`, a frame and a texture per render.
- **Options 24**: a login or `/reload` in combat registers the settings category once combat ends.
- **Widgets 10**: a column-block drag no longer borrows the block's `OnUpdate`, and the drop line
  no longer rides back into AceGUI's pool.
- **Core 8**: `printer.Format` survives a secret value in a numeric slot.
- **Test kit revision 26**: shared asserts, a recording `EventRegistry`, frames created shown, an
  AceDB fake that raises and strips defaults, the lone-CR `test_eol` count, and `§` in kit case names.

## Contract blockers

**None** (`01_DELTA.md` 3g). Each behavioral change that arrives unasked was bound to the host
surface it meets; none finds the host wrong.

## Adopted, declined, skipped

Nothing adopted or declined in this run. The opt-ins (Core's `SafeRegisterEvent` family, Launcher's
`isEnabled` / `disabledLine`, Slash's refusal echo, Schema minor 2, `RenderTabbedSchema`'s `opts`,
`Kit.assertLibraryConstant`) are decided by this addon's M3 items (MM-02, MM-07, MM-09, MM-14,
MM-17, MM-18) of the 2026-09-23 remediation plan.

## Gates

Each figure comes from `ka0s-bounded`, run from the repo root.

| Point | Tests | Lint |
|---|---|---|
| Before the copy (v1.55.0) | 1948 / 0 / 0 | 0 / 0 in 125 files |
| After the copy (v1.56.0) | 1941 / 7 / 0 | 0 / 0 in 125 files |

The seven reds are listed in `01_DELTA.md`, *The suite after the copy*: one prose hit
(`synchronis` in `tests/test_options_panel.lua:1091`) and six column-block drag cases whose test
driver fires the block's `OnUpdate`, which Widgets 10 moved to the drag ghost. The host code is
correct in every case. The M3 items clear them, by MM-DOCS at the latest. Lizard and the perf
scenarios were not run: this commit changes no authored Lua.

## Open

- `docs/test-cases.md` and the README test badge still describe kit revision 25; MM-DOCS
  regenerates them.
- In-game: open the Columns page and drag a block, to confirm the ghost-driven poll in the client
  (MM-18's smoke).
