# 01 — Delta: LibKa0s v1.29.0 → v1.30.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.30.0 LibKa0s testkit | tar -x -C <scratch>/`. The tag is
`e369e0f`, on the library's `fix/kit-27-30` branch and not yet merged to its `master` —
which does not matter here, because this addon's `tests/test_vendor_sync.lua` resolves the
**tag** its provenance line names and compares both payloads against that, file by file.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' MultiMeters/CLAUDE.md
```

> 52: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.29.0** (MIT).

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

The vendored minors are exactly v1.29.0's (Core 7, Env 1, Pool 3, Item 1, Media 3, Widgets 9,
DebugLog 12, Slash 7, Options 15, OptionsWidgets 14, OptionsCompose 3, OptionsScroll 3, Perf 10,
PerfPanel 5). The line and the bytes **agreed**: nothing had been rolled without its payload, in
either direction.

## 3c — Per-file minor delta

File list read from the tag's `LibKa0s/LibKa0s.xml` (14 files).

| File | Constant | v1.29.0 | v1.30.0 |
|---|---|---|---|
| `Core.lua` | `MINOR` | 7 | 7 |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 1 | 1 |
| `Media.lua` | `MINOR` | 3 | 3 |
| `Widgets.lua` | `MINOR` | 9 | 9 |
| `DebugLog.lua` | `MINOR` | 12 | 12 |
| `Slash.lua` | `MINOR` | 7 | 7 |
| `Options.lua` | `MINOR` | 15 | 15 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 14 | 14 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 3 | 3 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | 3 |
| `Perf.lua` | `MINOR` | 10 | 10 |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

**No minor moved and there is no cross-major skew.** The sorted minor lines of the vendored
copy and of the tag hash identically. LibStub sees no difference between v1.29.0 and v1.30.0.

## 3d — Both diffs, both directions

```
diff -r --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # empty
diff -rq                    <tag>/LibKa0s libs/LibKa0s   # empty
diff -r --strip-trailing-cr <tag>/testkit tests/_kit     # 4 files
diff -rq                    <tag>/testkit tests/_kit     # the same 4 files
```

The library payload is content- **and** byte-identical to the tag. The kit is content-dirty in
exactly four files, which is the release itself: `README.md`, `framework.lua`
(`Kit.VERSION` 15 → 16), `mock_base.lua` (the Ace-fake fixes) and `vendor_sync.lua` (the
runner-mode case). The byte diff names the same four and no others, so there is no line-ending
drift on either side. **No `Only in` lines**: nothing was removed upstream, so no deletion inside
`libs/` or `tests/_kit/` is warranted by this run.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v 'libs/' | grep -v 'tests/'
```

Majors reached from this addon's own source: Core (`core/CoreSetup.lua:88`), Env
(`core/EnvSetup.lua:71`), Media (`core/MediaSetup.lua:72`), DebugLog
(`core/DebugLogSetup.lua:227`), Pool (`core/PoolSetup.lua:35`), Perf (`core/PerfSetup.lua:41`),
Widgets (`modules/Export_Modal.lua:39`, `settings/ColumnBlocks.lua:78`), Options
(`settings/Schema_Compose.lua:476`, `settings/OptionsSetup.lua:110`) and Slash
(`settings/Slash.lua:110`). **Item** is in the payload with no lookup, unchanged from the last
run and untouched by this release (its minor did not move).

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
```

`Kit.VERSION = 16` at the tag, `15` in the addon. **This release is the kit revision.** Both
payloads are copied whole in the same commit, which is the rule and not an optimisation: from
revision 11 on, `vendor_sync.lua` stopped treating `media` as a file and stopped normalising line
endings across binaries, so the two payloads move together and a consumer never holds a kit that
cannot compare the library it ships.

## Baseline gates, before the copy

```
lua tests/run.lua   →  1748 passed, 0 failed, 0 skipped, 1748 total
luacheck .          →  0 warnings / 0 errors in 122 files
```
