# 02 — Candidates (MultiMeters)

Sources: `git -C ../LibKa0s log --oneline v1.76.0..v1.77.0`, the v1.77.0 `CHANGELOG.md` block and the
documents it links, chiefly `docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md` and
`docs/api/testkit/version-42-docs.md`. The Options stub blocker in 01_DELTA.md 3g is not a candidate:
it was fixed in the re-vendor commit.

## Class A: reached the addon on the copy

- **Toplevel tool windows** (Core 12, DebugLog 21, PerfPanel 9, SimPanel 6): the debug console, the
  perf panel, the copy window and the `/mm sim` step panel come to the front on a click and re-raise a
  shown confirmation popup. MultiMeters wires all four.
- **Popups clamped to the screen** (Widgets 15, WidgetsAutocomplete 3): the shared dropdown menu and
  the autocomplete list no longer run off the screen edge.
- **The IdList suggestion list closes at combat start** (OptionsIds 3, OptionsCombat 2). It ships,
  but MultiMeters draws no id widget.

## Class B: host change required

- **The settings-panel Keybindings tab**: `O.KeybindingsTab`, `O.KeybindRows` and
  `O.KEYBINDS_UNCHANGED` (OptionsKeybinds 2-3; `CHANGELOG.md:257-350`, Options document *The
  Keybindings tab*), with the kit's `mock_bindings.lua`, `Kit.assertBindingsXml` and
  `Kit.keybindThroughTab` for its tests. It touches `Bindings.xml`, the General page, the locales and
  the tests, and it is additive. **Item MM-KB of this run** adopts it.
- **`O.StrataTooltip`** (OptionsCompose 8; `CHANGELOG.md:181-211`): one shared tooltip for the strata
  rows, replacing MultiMeters' own tier sentences, with the kit's `mock_layers.lua` for its tests. It
  replaces code the addon owns. **Item MM-ZS of this run** adopts it, held for the owner.
- **DragHandle `level`, `ignoreParentAlpha` and `ApplyLevel`** (WidgetsDragHandle 5). MultiMeters
  draws no DragHandle. Deferred (run 2026-10-24).

## Class C: whole-module adoption

- **`LibKa0s-Glow-1.0`**: no use in this addon, unchanged from `2026-10-22-v1.75.0/02_CANDIDATES.md`,
  and it did not move in this range. Deferred (run 2026-10-24).
