Delta: LibKa0s v1.76.0 -> v1.77.0

# 01 — Delta (MultiMeters)

Run 2026-10-24 as item MM-RV of the Ka0sAddonsCommonTasks bundle
`docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`, following the installed `/dev-copilot:wow-revendor-libka0s`
(dev-copilot 2.4.0). The run was non-interactive. The item spec settles the source, the icon line
and the adoptions, so nothing was asked here.

## Source

The LOCAL annotated tag v1.77.0 (tag object `7380d36`, commit `78240f7`). It is not on the remote
yet: `git -C ../LibKa0s ls-remote --tags origin v1.77.0` prints nothing, and the push waits on the
owner. Extracted from the tag, never the working tree:

```sh
git -C ../LibKa0s archive v1.77.0 LibKa0s testkit tools | tar -x -C <scratch>/
```

## 3a. Base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 60:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)       # e8771f8 (MM-RV2 of the 2026-10-23 run)
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0
```

The line and the last payload commit agree, and no `CLAUDE.md` commit since rolled the line. A
v1.76.0 extract diffed against the vendored copy matches: `tests/_kit` is identical, and
`libs/LibKa0s` differs only by the undeclared icons the earlier prune removed. Base **v1.76.0**.

Step 0 pre-flight for this addon: the newest single-tag bundle, `2026-10-23-v1.76.0/`, states base
v1.75.2. The commit that rolled the line to v1.76.0 (`0af76e6`) had v1.75.2 before it, so the row is
`ok` and no correction is owed.

3h (tags vendored and never recorded) printed nothing: no span bundle is written.

## 3b and 3c. Per-file minors

The vendored minors matched the v1.76.0 claim. The loop over the tag's `LibKa0s/LibKa0s.xml`, keeping
only the files whose constant moved:

| File | v1.76.0 (vendored) | v1.77.0 |
|---|---|---|
| `Core.lua` `MINOR` | 11 | **12** |
| `DebugLog.lua` `MINOR` | 20 | **21** (`LibKa0s-DebugLog-1.0` key 21.3.1) |
| `PerfPanel.lua` `PANEL_MINOR` | 8 | **9** (`LibKa0s-Perf-1.0` key 15.1.1.9) |
| `SimPanel.lua` `SIM_PANEL_MINOR` | 5 | **6** (`LibKa0s-Sim-1.0` key 2.3.6) |
| `Widgets.lua` `MINOR` | 14 | **15** |
| `WidgetsDragHandle.lua` `DRAG_MINOR` | 4 | **5** |
| `WidgetsAutocomplete.lua` `AUTOCOMPLETE_MINOR` | 2 | **3** (`LibKa0s-Widgets-1.0` key 15.1.5.3.3) |
| `Options.lua` `MINOR` | 29 | **30** |
| `OptionsIds.lua` `IDS_MINOR` | 2 | **3** |
| `OptionsCombat.lua` `COMBAT_MINOR` | 1 | **2** |
| `OptionsCompose.lua` `COMPOSE_MINOR` | 7 | **8** |
| `OptionsKeybinds.lua` `KEYBINDS_MINOR` | (new file) | **3** (`LibKa0s-Options-1.0` key 30.2.34.3.5.9.2.8.4.2.1.3) |

Every other file is unchanged (`git -C ../LibKa0s diff --stat v1.76.0 v1.77.0 -- LibKa0s testkit`
names these twelve files, `LibKa0s.xml` and the kit). `OptionsKeybinds.lua` is new and the XML loads
it; the addon loads the XML from its TOC and `tests/run.lua` derives its list from the same XML, so
no wiring moved. After the copy every file is at the tag's minor, so there is no cross-major skew.

## 3d. Both diffs, before the prune

```sh
diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # 0 lines
diff -r                     <scratch>/LibKa0s libs/LibKa0s   # 0 lines
diff -r --strip-trailing-cr <scratch>/testkit tests/_kit     # 0 lines
diff -r                     <scratch>/testkit tests/_kit     # 0 lines
```

Content and bytes were clean on both payloads after the whole-folder copy. There was no
`Only in libs/LibKa0s` or `Only in tests/_kit` line, so the tag dropped no file. After the prune, the
only difference is `Only in <scratch>/LibKa0s/media/icons…` for the undeclared icons.

## 3e. Majors this addon consumes

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '^./libs/' | grep -v '^./tests/'
```

The lookups are Bus, Compat, Core, DebugLog, Env, Item, Launcher, Lifecycle, Media, Options, Perf,
Pool, Schema, Sim, Slash and Widgets. Of the majors that moved, Core, DebugLog, Perf, Sim, Widgets and
Options are all consumed. MultiMeters draws no DragHandle and no id widget, so the
`WidgetsDragHandle` and `OptionsIds` changes reach code it does not call.

## 3f. Kit revision

`Kit.VERSION` 41 -> **42** (`mock_bindings.lua`, `mock_layers.lua` and `bindings_xml.lua` new;
`framework.lua` and `README.md` changed). Both payloads were copied whole in one commit, so the
pairing rule holds by construction.

## 3g. Contract changes under unchanged signatures

Moved and consumed: Core, DebugLog, Perf, Sim, Widgets and Options. Read against the v1.77.0
`CHANGELOG.md` block and `docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md` (the addon was
on `version-29.2.34.2.5.9.1.7.4.2.1-docs.md`):

- **Blocker: the Options degradation stub owes four new instance members**, `StrataTooltip`
  (OptionsCompose 8), `KeybindingsTab`, `KeybindRows` and `KEYBINDS_UNCHANGED` (OptionsKeybinds 2).
  Evidence: the tag's `CHANGELOG.md:198`, `:294` and `:373` (*What a consumer owes*), and the Options
  document `:2787-2791`. On the copied payload
  `parity: the Options stub carries every public member of the live Helpers surface` went red
  naming exactly those four. **Fixed in this commit**, in `settings/OptionsSetup.lua`:
  `KeybindingsTab` and `KeybindRows` join the inert no-op list (builder-only, and `KeybindRows`
  answers nil when degraded on the live path too, `:401-404`); `StrataTooltip` answers `""` and
  `KEYBINDS_UNCHANGED` is `""` (value-answering, `:419-424`), so no copy of the library's words
  lives in the addon.
- Core 12, DebugLog 21, PerfPanel 9 and SimPanel 6 make the tool windows toplevel and re-raise a
  shown StaticPopup. The only obligation (`CHANGELOG.md:90`) is a LAYERS note for an addon whose own
  surface sits at DIALOG or above; that is the strata item MM-ZS's to record, not this re-vendor's.
- Widgets 15 / WidgetsAutocomplete 3 clamp popups to the screen; OptionsIds 3 / OptionsCombat 2 close
  the suggestion list at combat start. Each owes nothing (`CHANGELOG.md:141`, `:168`).
- Options 30 / OptionsKeybinds 1 and 3 add `__` names and one lib-level table only (`:248`, `:335`).
- MultiMeters' one `__Attach*` site is `settings/Schema_Compose.lua:479` (`__AttachCompose`). Compose 8
  adds `O.StrataTooltip` and changes no member the addon supplies there.
- `__releaseChrome` mirror: none (`grep -rn '__releaseChrome' . --include='*.lua'
  --exclude-dir=libs --exclude-dir=_kit` prints nothing).

The kit's new `Kit.assertBindingsXml` is opt-in: no MultiMeters suite calls it yet, so the addon's
`Bindings.xml` needs no change in this item. MM-KB owns the shape.

## 3i. The icon declaration

The line is kept unchanged. The item spec names no new name, and no surface this release adds is
library-drawn (the tag's `docs/releasing.md:338-345` table is unchanged: `close`, `clear`, `copy`,
`info`):

```
Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.77.0 (MIT).
LibKa0s icons: chat, chevron-down, clear, close, confirm, copy, expand, export, info, lock, minimise, reset, segment, settings, sort-down, sort-up, spreadsheet, unlock.
```

Nothing was split. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`), and the owner's in-client smoke (INSTALL-10) is the backstop for a
forgotten name.

**Prune.** `lua <scratch>/tools/prune-icons.lua .` after the diffs above:
`18 icon(s) declared; kept 19 file(s), removed 5821`, the same as the v1.76.0 refresh. The icon tree
in git did not change (`git status --porcelain | grep -c media/icons` prints 0).

## 3j. Tests that assume the whole icon folder

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
```

The suites the v1.75.0 re-vendor rewrote to the declaration are unchanged, and they stay green. No
blocker.

## Credits

The sets that ship are unchanged (Open Iconic only), so README `## Credits` is not touched.
