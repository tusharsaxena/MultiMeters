Delta: LibKa0s v1.75.2 -> v1.76.0

# 01 — Delta (MultiMeters)

Run 2026-10-23 as item MM-RV of the Ka0sAddonsCommonTasks bundle
`docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`, following the installed `/dev-copilot:wow-revendor-libka0s`
(dev-copilot 2.4.0). The run was non-interactive. The item spec and the run's owner scope
(`inputs/OWNER_SCOPE.md`) settle the source, the icon line and every adoption, so nothing was asked
here.

## Source

The LOCAL annotated tag v1.76.0 (tag object `546e284`, commit `9949368`). It is not on the remote
yet: `git -C ../LibKa0s ls-remote --tags origin v1.76.0` prints nothing, and the push waits on the
owner. Extracted from the tag, never the working tree:

```sh
git -C ../LibKa0s archive v1.76.0 LibKa0s testkit tools | tar -x -C <scratch>/
```

## 3a. Base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 55:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.75.2 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)       # 114ab0f
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.75.2
```

The line and the last payload commit agree. A v1.75.2 extract diffed against the vendored copy
matches: `tests/_kit` is identical, and `libs/LibKa0s` differs only by the undeclared icons the
earlier prune removed. Base **v1.75.2**.

Step 0 pre-flight for this addon: the newest single-tag bundle, `2026-10-22-v1.75.0/`, states base
v1.71.0. The commit that rolled the line to v1.75.0 (`7305974`) had v1.71.0 before it, so the row is
`ok` and no correction is owed.

3h (tags vendored and never recorded) printed `v1.75.1` and `v1.75.2`, the two between-run
re-vendors `ae676be` and `114ab0f`. They are recorded in the span bundle
`2026-10-23-v1.75.1-v1.75.2/`, written in this run.

## 3b and 3c. Per-file minors

The vendored minors matched the v1.75.2 claim. The loop over the tag's `LibKa0s/LibKa0s.xml`, keeping
only the files whose constant moved:

| File | v1.75.2 (vendored) | v1.76.0 |
|---|---|---|
| `Widgets.lua` `MINOR` | 13 | **14** (`LibKa0s-Widgets-1.0` key 14.1.4.3.2) |
| `SimTimeline.lua` `TIMELINE_MINOR` | 2 | **3** |
| `SimPanel.lua` `SIM_PANEL_MINOR` | 4 | **5** (`LibKa0s-Sim-1.0` key 2.3.5; `Sim` stays 2) |

Every other file is unchanged (`git -C ../LibKa0s diff --stat v1.75.2 v1.76.0 -- LibKa0s testkit`
names only these three). After the copy every file is at the tag's minor, so there is no
cross-major skew.

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
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '^libs/' | grep -v '^tests/'
```

The lookups are Core, Launcher, Bus, DebugLog, Env, Compat, Media, Pool, Perf, Lifecycle, Widgets,
Options, Slash and Schema. Three majors in the payload have no lookup here: Item, Glow and **Sim**.
Of the three files that moved, only `Widgets.lua` is consumed. Its `W.TestStrip` draws the test-mode
strip (`modules/Window.lua:668`).

## 3f. Kit revision

`Kit.VERSION` 41 -> **41**, bytes identical. Both payloads were still copied whole in one commit, so
the pairing rule holds by construction.

## 3g. Contract changes under unchanged signatures

Moved and consumed: Widgets only. Read `docs/api/Widgets/version-13.1.4.3.2-docs.md` at v1.75.2
against `version-14.1.4.3.2-docs.md` at v1.76.0:

- **`TestStrip(parent, opts)`** gains `opts.kind` (**Since 14**) and the read-only `strip.kind`. Any
  kind other than exactly `"sim"`, nil included, draws the amber strip "exactly what it drew at
  13" (the 14 document, *What changed at 14.1.4.3.2*). `modules/Window.lua:668` passes no `kind`,
  so its strip is unchanged. Height, mark, inset, font, anchors, the birth-only contract and the
  mouse being off are the same. No MUST appeared under a surface MultiMeters already used.
- MultiMeters has no `__Attach*` call into Widgets. Its one `__AttachCompose` site
  (`settings/Schema_Compose.lua:479`) is in Options, which did not move.
- Sim (SimTimeline 3, SimPanel 5: auto-run, Run all removed) is not consumed. Its "What a consumer
  owes" items (re-true suites that typed `start` then ran, reword docs naming Run all, no
  `RUN_ALL` override) do not apply. `grep -rn 'RUN_ALL\|Run all' locales modules core settings tests`
  finds nothing.
- `__releaseChrome` mirror: none (`grep -rn '__releaseChrome' . --include='*.lua'
  --exclude-dir=libs --exclude-dir=_kit` prints nothing).

**Blockers: none.** The suite was green on the copied payload with no addon change.

## 3i. The icon declaration

The line is kept unchanged. The item spec names it, and no candidate this run adopts in MM-RV draws
a new name:

```
Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0 (MIT).
LibKa0s icons: chat, chevron-down, clear, close, copy, expand, export, info, lock, minimise, reset, segment, settings, sort-down, sort-up, spreadsheet, unlock.
```

Draw sites are as recorded in `2026-10-22-v1.75.0/01_DELTA.md` 3i. Nothing was split. A later item
of this run that passes `kind = "sim"` (MM-17) reuses `info` and needs no new name. Hand lists have
drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`),
and the owner's in-client smoke (INSTALL-10) is the backstop for a forgotten name.

**Prune.** `lua <scratch>/tools/prune-icons.lua .` after the diffs above:
`17 icon(s) declared; kept 18 file(s), removed 5822`. This matches the v1.75.0 prune. The tag's
catalog is unchanged, so 207 Open Iconic marks, the whole `phosphor/` folder (1,435 files) and the
whole `game-icons/` folder (4,180 files) were removed again.

## 3j. Tests that assume the whole icon folder

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
```

The suites the v1.75.0 re-vendor rewrote to the declaration are unchanged, and they stay green. No
blocker.

## Credits

The sets that ship are unchanged (Open Iconic only), so README `## Credits` is not touched.
