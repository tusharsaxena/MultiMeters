Delta: LibKa0s v1.55.0 -> v1.56.0

# 01 — Delta

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.56.0 LibKa0s testkit | tar -x -C <scratch>/new`. The tag resolves to
`4622018` (`git -C ../LibKa0s rev-parse --short v1.56.0`) and is the newest tag
(`git -C ../LibKa0s tag --sort=-v:refname | head -1`). At the time of this run it exists only as a
local tag in the sibling checkout; it has not been pushed.

This bundle covers the delta and the copy (Steps 2-4 of the local
`../wow-addon/commands/revendor-libka0s.md`, as amended by WA-01). The adoption decisions are not
taken here: they are this addon's M3 items of the 2026-09-23 remediation plan (MM-01 .. MM-DOCS),
so there is no `02_CANDIDATES.md`, `03_DECISIONS.md` or `04_EXECUTION_PLAN.md` in this folder.

## Step 0 — Base check of the newest single-tag bundle

```
git show a5a1014^:CLAUDE.md | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
git show a5a1014:CLAUDE.md  | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
```

`docs/revendor/2026-09-23-v1.55.0/` states base v1.54.2; the provenance line before its vendoring
commit `a5a1014` named v1.54.2, and `a5a1014` itself names v1.55.0. **ok**, no correction owed.

## 3a — Claimed version, and the base

```
grep -n '[Bb]undles' CLAUDE.md
```

> 53: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.55.0** (MIT).

Cross-check against the last commit that touched either payload:

```
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)     # a5a1014, "Re-vendor LibKa0s v1.55.0, ..."
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'   # v1.55.0
```

The two agree. **The base is v1.55.0**, the tag the provenance line names (not "the library's
previous tag", which happens to be the same tag here). `README.md` carries no provenance line.

```
git -C ../LibKa0s log --oneline v1.55.0..v1.56.0     # 51 commits, LK-01 .. LK-34 plus two sweeps
git -C ../LibKa0s diff --stat v1.55.0 v1.56.0        # 145 files, +27087 / -1880
```

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/<file>
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit && echo payload-matches
```

`payload-matches` printed: every vendored byte was v1.55.0's before the copy. The line and the
bytes agree.

## 3c — Per-file minor delta

Read from the tag's `LibKa0s/LibKa0s.xml`, in its load order, with the one grep above on each side.

| File | Constant | v1.55.0 (vendored) | v1.56.0 |
|---|---|---|---|
| `Core.lua` | `MINOR` | 7 | **8** |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Compat.lua` | `MINOR` | 1 | 1 |
| `Lifecycle.lua` | `MINOR` | 1 | **2** |
| `Bus.lua` | `MINOR` | 1 | **2** |
| `Schema.lua` | `MINOR` | 1 | **2** |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 1 | **2** |
| `Media.lua` | `MINOR` | 3 | **4** |
| `Widgets.lua` | `MINOR` | 9 | **10** |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 2 | 2 |
| `DebugLog.lua` | `MINOR` | 12 | **13** |
| `Slash.lua` | `MINOR` | 14 | **15** |
| `Launcher.lua` | `MINOR` | 1 | **2** |
| `Options.lua` | `MINOR` | 23 | **24** |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 30 | **31** |
| `OptionsTabs.lua` | `TABS_MINOR` | 3 | **4** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 7 | 7 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | **4** |
| `Perf.lua` | `MINOR` | 12 | **13** |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

No new file and no removed file. **No cross-major skew** before or after: the copy is whole, and no
`NEEDS_*` floor rises in this release (LibKa0s `CHANGELOG.md`, v1.56.0 header paragraph).

## 3d — Both diffs, both directions (before the copy)

```
diff -rq --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s
diff -rq                     <scratch>/new/LibKa0s libs/LibKa0s
diff -rq --strip-trailing-cr <scratch>/new/testkit tests/_kit
diff -rq                     <scratch>/new/testkit tests/_kit
```

- `LibKa0s/`: 15 files differ, exactly the 15 whose minor moved in 3c (`Bus`, `Core`, `DebugLog`,
  `Item`, `Launcher`, `Lifecycle`, `Media`, `Options`, `OptionsScroll`, `OptionsTabs`,
  `OptionsWidgets`, `Perf`, `Schema`, `Slash`, `Widgets`). `LibKa0s.xml` and the media are unchanged.
- `testkit/`: `Only in <tag>`: `asserts.lua`, `mock_events.lua`, `prose_lists.lua`; differ:
  `README.md`, `framework.lua`, `mock_base.lua`, `mock_record.lua`, `run-automated-tests.sh`,
  `test_eol.lua`, `test_layout_cap.lua`, `test_prose.lua`.
- Content and bytes give the **same** answer on both payloads: no line-ending drift.
- No `Only in libs/LibKa0s` or `Only in tests/_kit` line: **nothing to delete** inside either payload.

After the copy (`rm -rf` of both folders, then `cp -r` from the tag, runner kept executable) all
four diffs are **empty**.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

| Major | Lookup sites |
|---|---|
| Core | `core/CoreSetup.lua:88` |
| Env | `core/EnvSetup.lua:71` |
| Compat | `core/Compat.lua:73`, `core/Secrets.lua:160` |
| Lifecycle | `core/LifecycleSetup.lua:37` |
| Bus | `core/Namespace.lua:211`, `core/Constants.lua:575` |
| Pool | `core/PoolSetup.lua:35` |
| Media | `core/MediaSetup.lua:72` |
| Widgets | `modules/Export_Modal.lua:39`, `settings/ColumnBlocks.lua:78` |
| DebugLog | `core/DebugLogSetup.lua:227` |
| Slash | `settings/Slash.lua:169` |
| Launcher | `core/LauncherSetup.lua:79` |
| Options | `settings/OptionsSetup.lua:153`, `settings/Schema_Compose.lua:463` |
| Perf | `core/PerfSetup.lua:42` |

**Unconsumed:** `Item` (reached only by the library itself) and `Schema` (declined at v1.55.0,
issue #52; MM-14 revisits it at minor 2).

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua
```

`tests/_kit/framework.lua:20: Kit.VERSION = 25` -> `<tag>/testkit/framework.lua:20: Kit.VERSION = 26`.

The pairing rule (a consumer on LibKa0s v1.9.0 or newer takes kit revision 11 or newer in the same
commit) is satisfied by construction: both payloads are copied whole, from one tag, in one commit.
Revision 26's adoption notes are in `LibKa0s/docs/api/testkit/version-26-docs.md`, section
`Adoption` (`:830`).

## 3g — Contract delta

**Majors whose minor moved, intersected with majors this addon consumes:** Core, Lifecycle, Bus,
Media, Widgets, DebugLog, Slash, Launcher, Options (key 23.30.3.7.3 -> 24.31.4.7.4) and Perf
(12.5 -> 13.5). Each new document's `What changed` section was read against the old one:
`Core/version-8-docs.md:22`, `Lifecycle/version-2-docs.md:18`, `Bus/version-2-docs.md:18`,
`Media/version-4-docs.md:18`, `Widgets/version-10.2-docs.md:18`, `DebugLog/version-13-docs.md:47`,
`Slash/version-15-docs.md:37`, `Launcher/version-2-docs.md:19`,
`Options/version-24.31.4.7.4-docs.md:31`, `Perf/version-13.5-docs.md:37`. The library's own
summary is `CHANGELOG.md`, v1.56.0, `### What a consumer owes on re-vendoring v1.56.0`.

Every change is additive or an opt-in. The ones that reach this addon without being asked for,
each bound to what the host hands over:

- **Options 24: `CreateOptionsPanel` parks under `InCombatLockdown()` and replays at
  `PLAYER_REGEN_ENABLED`; a host MUST NOT add its own park.** This addon has none:
  `settings/OptionsSetup.lua:510` calls `Helpers.CreateOptionsPanel()` straight through. Not a
  blocker; the in-combat `/reload` now shows the category when the fight ends.
- **Options 24: `OpenOptionsPanel` answers a boolean.** `settings/OptionsSetup.lua:517` discards it.
  No effect.
- **OptionsWidgets 31: `scheduleTimer`'s return value is unused.** This addon passes a
  `C_Timer.After` wrapper that answers nil (`settings/OptionsSetup.lua:270`); it gains the 50 ms drag
  throttle it was missing. MM-17 documents and pins it.
- **OptionsTabs 4: the banner `Dropdown` is Released by the library under a private key;
  `ctx.__bannerWidget` stays the host's.** `settings/Windows.lua:242` writes it and never Releases
  it, so there is no double release.
- **Slash 15: `CliSet` / `CliReset` print the write seam's refusal when `set` / `applyDefault`
  answer exactly `false`.** This addon's `set` (`settings/Slash.lua:295`) answers nothing, which
  still reads as "the write landed". Unchanged behavior; MM-09 adopts the refusal.
- **Launcher 2: the missing-library notice prints once, without the `[LibKa0s] ` prefix.** Cosmetic.
- **Widgets 10: `ReorderList` polls on the drag ghost, not on the host's row frame, and `Finish`
  no longer builds or returns the drop line.** The host (`settings/ColumnBlocks.lua:361`) ignores
  `Finish`'s return and sets no `OnUpdate` of its own on a block, so the host is correct. The test
  driver in `tests/test_columnblocks.lua` is not: it fires the block's `OnUpdate` (`:65-78`) and
  asserts `ctx.mmReorder.line` after `Finish` (`:414`). Those cases go red here; see below.

`__Attach*` sites: `settings/Schema_Compose.lua:479`, `optlib.__AttachCompose(C, ...)`. Compose
minor 7 is unchanged, so every member supplied there keeps its contract.

### Blockers

**None.** No host code is wrong the moment the bytes land.

## 3h — Unrecorded vendored tags

The listing (the standards audit's re-vendor check, run before the copy) reports v1.14.0,
v1.16.0 .. v1.29.0 (less the recorded v1.15.0 and v1.25.0) and v1.35.0 .. v1.54.2 as vendored and
unrecorded. **No span bundle is written in this run**: the remediation plan gives that record to its
own item, MM-30 (consolidated span bundle for the unrecorded tags), so this commit stays a payload
copy.

## What the copy owes

- Whole-folder copy of both payloads from the tag. Done; all four diffs empty afterwards.
- `CLAUDE.md` provenance line `v1.55.0` -> `v1.56.0`, same commit. Done.
- No `tests/run.lua` wiring: kit revision 26 adds no suite a consumer must declare, and the three
  new kit files are loaded by the kit itself.
- `docs/test-cases.md` and the README test badge are **not** regenerated here (revision 26's `§` case
  names change them); MM-DOCS does that.

## The suite after the copy

```
/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .            # 0 / 0 in 125 files
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua  # 1941 passed, 7 failed, 0 skipped
```

Before the copy: 1948 passed, 0 failed. The seven reds are all the stricter kit or library meeting
this addon's own tests, and none is host code:

| Case | Cause |
|---|---|
| `prose: no authored file carries a British spelling ...` | kit 26 lists `synchronis`; `tests/test_options_panel.lua:1091` carries it |
| `Blocks: a drag reports where it landed` | Widgets 10 polls on the ghost; the driver fires the block's `OnUpdate` |
| `Blocks: the page hands LibKa0s the boundary, ...` | same |
| `Blocks: an enabled block cannot be dragged past the last enabled one` | same |
| `Blocks: a list with nothing disabled drags end to end` | same |
| `Blocks: an empty item list still builds and finishes a controller` | Widgets 10: `Finish` builds no line, so `ctx.mmReorder.line` is nil |
| `Columns: dragging a block reorders the stored array` | same driver as the `Blocks` drag cases |

This addon's M3 items clear them, and the suite is green again by MM-DOCS at the latest.
