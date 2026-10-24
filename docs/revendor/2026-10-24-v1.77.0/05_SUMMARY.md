# 05 — Summary (MultiMeters)

LibKa0s v1.76.0 -> v1.77.0 from the local annotated tag (`7380d36`, commit `78240f7`). The base,
v1.76.0, comes from the CLAUDE.md provenance line and agrees with the last payload commit
(`e8771f8`). Kit revision 41 -> 42. Minors: Core 11 -> 12, DebugLog 20 -> 21, PerfPanel 8 -> 9,
SimPanel 5 -> 6, Widgets 14 -> 15, WidgetsDragHandle 4 -> 5, WidgetsAutocomplete 2 -> 3,
Options 29 -> 30, OptionsIds 2 -> 3, OptionsCombat 1 -> 2, OptionsCompose 7 -> 8, and the new
OptionsKeybinds at 3. Every other file is unchanged.

One commit carries both payloads, the provenance line, the prune and the stub fix. No span bundle
(3h printed nothing) and no base correction was needed.

- **Blocker, fixed here:** the Options degradation stub in `settings/OptionsSetup.lua` gained
  `KeybindingsTab` and `KeybindRows` (inert no-ops), `StrataTooltip` (answers `""`) and
  `KEYBINDS_UNCHANGED` (`""`). Without them the surface-parity case was red on the copy.
- **Icon line kept:** the 18 names, unchanged. No provenance split. The prune kept 19 files (the 18
  icons and the Open Iconic license) and removed 5,821, the same as at v1.76.0. There is no
  `__releaseChrome` mirror.
- **Credits:** unchanged (Open Iconic is still the only set that ships).
- **Delivered free:** toplevel tool windows with the popup re-raise (debug console, perf panel, copy
  window, sim step panel), and the dropdown menu and autocomplete list clamped to the screen.
- **Adopted here:** nothing. The Keybindings tab lands in MM-KB and `O.StrataTooltip` in MM-ZS.
- **Deferred (run 2026-10-24):** DragHandle `level` / `ignoreParentAlpha` / `ApplyLevel` and
  `LibKa0s-Glow-1.0`, neither used by this addon. No issue filed.
- **Standard reference:** the same commit records the `/dev-copilot:wow-revendor-standards` pass
  against standard v2.88.0 (2026-10-24), read from the local WowAddonStandards run branch
  (`897fbd3`). The three-place reference (TOC `## X-Standard:`, the bare README badge, CLAUDE.md
  `## Standards compliance (read first)`) was already right and needed no edit. The procedure keeps
  the standard's version out of the reference, so none of the three carries `2.88.0`. Every
  `filename-§N` citation outside the frozen bundles resolves against v2.88.0 (973 checked); the
  seven `§N.M` hits cite design docs, not the standard; `.gitattributes` is the canonical CRLF body
  with 0 stragglers; every gate statement in `docs/testing.md` and `docs/automated-tests/README.md`
  names its checkpoint. The `docs/automated-tests/RESULTS.md` lead-in is runner-generated and out of
  that sweep's reach. The standard carries no quirks catalog section, so there is no vendored block.
- **Smoke owed (owner):** none new. INSTALL-10 still covers the pruned icon set.
- **Gate after the prune**, every run through `ka0s-bounded`: `lua tests/run.lua` 2320 passed,
  0 failed, 1 skipped (2321 total), `test_vendor_sync` green against v1.77.0; `luacheck .`
  0 warnings / 0 errors in 159 files; no authored `.lua` file over 1500 lines (largest
  `tests/test_window.lua`, 1481).

## Re-vendor after the tag moved (M3)

LK-95 moved the local annotated tag v1.77.0 to carry the settings-layout surfaces. Old tag `7380d36`
(commit `78240f7`), new tag `b2b8ee2` (commit `afae2f75cb7ff61c57156d9a3d8a6b2b9f4c5e10`). The
provenance line stays v1.77.0 and records no sha or kit revision, so it did not move. Both payloads
were copied whole from `git -C ../LibKa0s archive v1.77.0 LibKa0s testkit`; both diffs were empty
before the prune.

- **Minors that moved:** OptionsCompose 8 -> 11 (the only file that changed; it adds
  `O.ResetAllTooltip`). Kit revision 42 -> 42, `tests/_kit/` byte-identical.
- **Blocker, fixed here:** the surface-parity case went red on `ResetAllTooltip`. The Options
  degradation stub in `settings/OptionsSetup.lua` now carries it as an inert member answering `""`.
- **Icon line kept:** the 18 names; the prune kept 19 files and removed 5,821, as before.
- **Adopted here:** nothing. MM-LY adopts the layout surfaces.
- **Standard reference:** standard still v2.88.0. WS-95 and the commits since `897fbd3` only add
  text (options-ui §21, open-evolutions entries) and remove no section, so every citation still
  resolves and the three-place reference needs no edit.
- **Gate**, through `ka0s-bounded`: `lua tests/run.lua` 2336 passed, 0 failed, 1 skipped (2337
  total); `luacheck .` 0 warnings / 0 errors in 160 files; no authored `.lua` file over 1500 lines
  (largest `tests/test_window.lua`, 1481).

## Re-vendor after the tag moved again (one key button)

LK-96 moved the local annotated tag v1.77.0 again, for the owner's one-key-button follow-up to 015.
Old tag `b2b8ee2` (commit `afae2f7`), new tag `e9b126d` (commit `2f2b2e2`). The provenance line stays
v1.77.0 and records no sha, so it did not move. Both payloads were copied whole from
`git -C ../LibKa0s archive v1.77.0 LibKa0s testkit`; both diffs were empty before the prune.

- **Minors that moved:** OptionsKeybinds 3 -> 4 (the only library file that changed): a row is one
  key button and Clear; the button binds slot 1 and reads `<key> +N` when the game's page holds more,
  with a tooltip naming every key. The words KEY1 / KEY2 are gone; KEY, KEY_MORE, KEYS_ALL and
  KEYS_OTHER are new. No public Options member was added or removed, so the degradation stub needed
  no change. Kit revision 42 -> 42; `tests/_kit/bindings_xml.lua` and its README row changed
  (`Kit.keybindThroughTab` slot 2 now writes through the model on a one-button row).
- **Blocker, fixed here:** the suite's one-store case read `rows[1].slots[2]`, which a minor-4 row
  no longer draws. It now asserts the row has no second slot and a Clear button, and that a second
  key set elsewhere shows as `K +1` on the one button after UPDATE_BINDINGS.
- **Docs:** `docs/settings-panel.md` and smoke checks SLASH-31 and SLASH-32 describe one key button
  and Clear; both are rewritten, pending, and listed under Pending sign-off (SM-MM-RV3).
- **Icon line kept:** the 18 names; the prune kept 19 files and removed 5,821, as before.
- **Gate**, through `ka0s-bounded`: `lua tests/run.lua` 2345 passed, 0 failed, 1 skipped (2346
  total); `luacheck .` 0 warnings / 0 errors in 162 files; no authored `.lua` file over 1500 lines
  (largest `tests/test_window.lua`, 1481).
