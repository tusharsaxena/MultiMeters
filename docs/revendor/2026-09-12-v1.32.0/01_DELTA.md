# 01 — Delta: LibKa0s v1.31.0 → v1.32.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.32.0 LibKa0s testkit | tar -x -C <scratch>/`. The tag is `e18dd12`
("The v1.32.0 release record, re-taken on the final tree"), local only and not pushed. This addon's
`tests/test_vendor_sync.lua` resolves the **tag** its provenance line names in the sibling checkout
and compares both payloads against it, file by file, so an unpushed tag is enough.

This folder carries a `-v1.32.0` suffix because `docs/revendor/2026-09-12/` and
`docs/revendor/2026-09-12-v1.31.0/` already hold the same day's earlier re-vendors, and both are
frozen.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
```

> 52: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.31.0** (MIT).

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR|COMPOSE_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, OptionsCompose 4, OptionsScroll 3,
OptionsWidgets 15, Perf 11, PerfPanel 5, Pool 3, Slash 7, Widgets 9: exactly v1.31.0's. The line and
the bytes **agreed**.

## 3c — Per-file minor delta

| File | Constant | v1.31.0 | v1.32.0 |
|---|---|---|---|
| `Core.lua` | `MINOR` | 7 | 7 |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 1 | 1 |
| `Media.lua` | `MINOR` | 3 | 3 |
| `Widgets.lua` | `MINOR` | 9 | 9 |
| `DebugLog.lua` | `MINOR` | 12 | 12 |
| `Slash.lua` | `MINOR` | 7 | **8** |
| `Options.lua` | `MINOR` | 15 | **16** |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 15 | 15 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 4 | 4 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | 3 |
| `Perf.lua` | `MINOR` | 11 | 11 |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

Two files move. **No cross-major skew**: the consumer was behind on both, and the whole-folder copy
moves both at once.

## 3d — Both diffs, both directions

Before the copy:

```
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # Options.lua, Slash.lua
diff -rq                    <tag>/LibKa0s libs/LibKa0s   # the same 2
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit     # nothing
diff -rq                    <tag>/testkit tests/_kit     # nothing
```

Content and bytes list the same files, so every difference is a real content change and none is a
line-ending disagreement. No `Only in` line: nothing was removed upstream and nothing was deleted
here. The kit does not move at all.

After the copy all four are empty. CR count equals LF count in both changed files (Options.lua
1114 / 1114, Slash.lua 652 / 652). `tests/_kit/run-automated-tests.sh` stays `100755` in the index
(`git ls-files -s`).

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -vE '^\./(libs|tests)/'
```

| Major | Lookup sites |
|---|---|
| Core | `core/CoreSetup.lua:88` |
| DebugLog | `core/DebugLogSetup.lua:227` |
| Media | `core/MediaSetup.lua:72` |
| Env | `core/EnvSetup.lua:71` |
| Pool | `core/PoolSetup.lua:35` |
| Perf | `core/PerfSetup.lua:42` |
| Options | `settings/OptionsSetup.lua:110`, `settings/Schema_Compose.lua:476` |
| Widgets | `settings/ColumnBlocks.lua:78`, `modules/Export_Modal.lua:39` |
| Slash | `settings/Slash.lua:110` |

The same map as v1.31.0. Both majors that move, Options and Slash, have a lookup here, so both are
consumed.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
```

17 → **17**. The kit does not move. The pairing rule (LibKa0s v1.9.0 or newer takes kit revision 11
or newer in the same commit) holds.

## Gate after the copy

```
lua tests/run.lua     # 1804 passed, 0 failed, 0 skipped, 1804 total  (baseline before the copy: 1804/0/0)
luacheck .            # 0 warnings / 0 errors in 123 files
```

`tests/test_vendor_sync.lua` ran rather than skipped (0 skipped), so both payloads were compared
against the `v1.32.0` tag. A host that supplies neither new field runs v1.31.0's walk exactly, and
this host supplied neither at the copy, which is why nothing moved.
