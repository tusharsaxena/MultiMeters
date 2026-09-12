# 01 — Delta: LibKa0s v1.30.0 → v1.31.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.31.0 LibKa0s testkit | tar -x -C <scratch>/`. The tag is
`e7e1962` ("The v1.31.0 release record, re-taken on the review-fixed tree"), local only: it was
re-cut after the library's review and has not been pushed. That does not matter here, because this
addon's `tests/test_vendor_sync.lua` resolves the **tag** its provenance line names in the sibling
checkout and compares both payloads against it, file by file.

This folder carries a `-v1.31.0` suffix because `docs/revendor/2026-09-12/` already holds the
v1.30.0 re-vendor of the same day, and that bundle is frozen.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' MultiMeters/CLAUDE.md
```

> 52: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.30.0** (MIT).

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
grep -n 'MINOR' libs/LibKa0s/OptionsCompose.lua     # COMPOSE_MINOR, which the pattern above misses
```

Core 7, Env 1, Pool 3, Item 1, Media 3, Widgets 9, DebugLog 12, Slash 7, Options 15,
OptionsWidgets 14, OptionsCompose 3, OptionsScroll 3, Perf 10, PerfPanel 5: exactly v1.30.0's.
The line and the bytes **agreed**.

## 3c — Per-file minor delta

File list read from the tag's `LibKa0s/LibKa0s.xml` (14 files).

| File | Constant | v1.30.0 | v1.31.0 |
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
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 14 | **15** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 3 | **4** |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | 3 |
| `Perf.lua` | `MINOR` | 10 | **11** |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

Three files move. **No cross-major skew**: the consumer was behind on all three, and the whole-folder
copy moves all three at once.

## 3d — Both diffs, both directions

Before the copy:

```
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # OptionsCompose.lua, OptionsWidgets.lua, Perf.lua
diff -rq                    <tag>/LibKa0s libs/LibKa0s   # the same 3
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua
diff -rq                    <tag>/testkit tests/_kit     # the same 3
```

Content and bytes list the same files, so every difference is a real content change and none is a
line-ending disagreement. No `Only in libs/LibKa0s` or `Only in tests/_kit` line: nothing was removed
upstream, and nothing was deleted here.

After the copy all four are empty, and so are the same four against the sibling's working tree
(`../LibKa0s` is checked out at `v1.31.0`). CR count equals LF count in all six changed files.
`tests/_kit/run-automated-tests.sh` stays `100755` in the index (`git ls-files -s`).

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

Every major but **Item** has a lookup, the same map as v1.30.0. Item has no minor move this release.
The two Options and two Widgets sites were already recorded in the v1.30.0 bundle.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
```

16 → **17**. Both payloads are copied whole in one commit, so the pairing rule (LibKa0s v1.9.0 or
newer takes kit revision 11 or newer in the same commit) holds by construction. That rule is why the
two payloads move together.

## Gate after the copy

```
lua tests/run.lua     # 1779 passed, 0 failed, 0 skipped, 1779 total  (baseline before the copy: 1779/0/0)
luacheck .            # 0 warnings / 0 errors in 122 files
```

`tests/test_vendor_sync.lua` ran rather than skipped (0 skipped), so both payloads were compared
against the `v1.31.0` tag. `.luacheckrc` excludes `libs/` and `tests/_kit/`, so the 0/0 covers the
addon's own seams (`core/PerfSetup.lua`, `settings/*`) and not the vendored bytes.
