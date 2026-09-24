Delta: LibKa0s v1.57.0 -> v1.58.0

# 01 — Delta

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.58.0 LibKa0s testkit | tar -x -C <scratch>/new`. The tag points at
commit `34931c9` (`git -C ../LibKa0s rev-list -n1 v1.58.0`) and is the newest tag
(`git -C ../LibKa0s tag --sort=-v:refname | head -1`). When this ran it existed only as a local tag
in the sibling checkout and had not been pushed.

This bundle covers the delta and the copy. The adoption is fixed in advance by the remediation
plan's M6 row (`M6_LAUNCHER_MENU.md`, item M6-MM) rather than chosen candidate by candidate, so
there is no `02_CANDIDATES.md`, `03_DECISIONS.md` or `04_EXECUTION_PLAN.md` in this folder.
`05_SUMMARY.md` records what the second M6-MM commit adopted.

## Step 0 — Base check of the newest single-tag bundle

```
git show 9df6cc9^:CLAUDE.md | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
git show 9df6cc9:CLAUDE.md  | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
```

`docs/revendor/2026-09-24-v1.57.0/` states base v1.56.0. The provenance line before its vendoring
commit `9df6cc9` named v1.56.0, and `9df6cc9` itself names v1.57.0. **ok**, no correction owed.

## 3a — Claimed version, and the base

```
grep -n '[Bb]undles' CLAUDE.md
```

> 54: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.57.0** (MIT).

Cross-check against the last commit that touched either payload:

```
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)     # 9df6cc9, "M5-MM: Re-vendor LibKa0s v1.57.0 ..."
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'   # v1.57.0
```

They agree, so **the base is v1.57.0**.

```
git -C ../LibKa0s log --oneline v1.57.0..v1.58.0     # 2 commits, both LK-37
git -C ../LibKa0s diff --stat v1.57.0 v1.58.0        # 19 files, +9787 / -367; one payload file
```

## 3b — Actual version, before this run

```
git -C ../LibKa0s archive v1.57.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit && echo payload-matches
```

`payload-matches` printed: before the copy, every vendored byte matched v1.57.0. The provenance line
and the bytes agree.

## 3c — Per-file minor delta

| File | Constant | v1.57.0 (vendored) | v1.58.0 |
|---|---|---|---|
| `Launcher.lua` | `MINOR` | 3 | **4** |

Every other file is byte-identical: `Core` 8, `Env` 1, `Compat` 1, `Lifecycle` 2, `Bus` 2,
`Schema` 2, `Pool` 3, `Item` 2, `Media` 4, `Widgets` 10, `WidgetsDragHandle` 2, `DebugLog` 13,
`Slash` 15, `Options` 24, `OptionsWidgets` 31, `OptionsTabs` 4, `OptionsCompose` 7,
`OptionsScroll` 4, `Perf` 13, `PerfPanel` 5. No file was added or removed, and no `NEEDS_*` floor
rises (LibKa0s `CHANGELOG.md`, v1.58.0 header paragraph).

## 3d — Both diffs, both directions (before the copy)

```
diff -rq <scratch>/old <scratch>/new
```

- `LibKa0s/`: one file differs, `Launcher.lua` (+163 / -94). `LibKa0s.xml` and the media are
  unchanged.
- `testkit/`: no difference.
- No `Only in` line on either side, so **nothing to delete** inside either payload.

After the copy (`rm -rf` of both folders, then `cp -r` from the tag, runner still executable),
`diff -r` of both payloads against the tag is **empty**, bytes included.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core modules settings
```

The only major that moved is Launcher, and this addon reaches it from one site:
`core/LauncherSetup.lua:79`. The rest of the map is unchanged from the v1.57.0 bundle.

## 3f — Kit revision, and the pairing rule

`tests/_kit/framework.lua:20: Kit.VERSION = 26` on both sides. The kit does not move in this
release, and the pairing rule holds because both payloads come whole from one tag in one commit.

The library's new menu stand-in, `tests/mock_menu.lua`, is **repo-local to LibKa0s and not in the
kit** (`docs/api/Launcher/version-4-docs.md`, "Testing a host"), so it did not arrive. The host
suite owes its own `MenuUtil` fake for the menu cases, modeled on that file. That lands with the
adoption commit.

## 3g — Contract delta

**The moved major this addon consumes:** Launcher, 3 -> 4. Read
`LibKa0s/docs/api/Launcher/version-4-docs.md`, `What changed at this version`, against version 3.
The library's own summary is `CHANGELOG.md`, v1.58.0, `### What a consumer owes on re-vendoring
v1.58.0`.

What reaches this addon without being asked for:

- **Left-click opens the settings panel**, in either state. This addon's `onClick` (the rung-(a)
  window toggle through `WindowManager:Toggle`) stops running, and the minor-2 disabled refusal is
  gone, so `disabledLine` is never read.
- **The tooltip's hints are fixed** at `Left-click: Open settings` / `Right-click: Options menu`.
  `leftClickLabel` is never read.
- **Right-click** still opens the settings panel until the descriptor passes at least one
  accessor-and-toggle pair, since this addon passes `isEnabled` but not yet `setEnabled`.
- `onClick`, `leftClickLabel`, `disabledLine` and `slash` are ignored if passed. `New` raises on none
  of them, so nothing breaks the moment the bytes land.

Nine host cases pinned the retired contracts and went red after the copy: the rung-(a) left click
(`tests/test_launchersetup.lua`), the disabled and perf-suspend left-click refusals (the same file,
`tests/test_disabled.lua` "Disabled 8" and `tests/test_degraded.lua`'s Slash-missing case), and four
tooltip cases pinning minor 3's hints, the disabled hint, the bare perf-suspend hint and the
rung-(a) label. This commit re-pins them to what arrived: left-click opens the panel in either state
and prints nothing, and the tooltip's hints are the fixed pair. The perf-suspend hint and the
locale-label cases are deleted, because the contracts they pinned no longer exist.

Owed by `launcher-§2` (standard v2.67.0), in the second M6-MM commit: `setEnabled` beside
`isEnabled`, and `toggleLock`, `toggleTestMode`, `isWindowShown` + `toggleWindow`, each wired to the
handler its slash verb runs; the retired fields deleted from the descriptor.

### Blockers

**None.** The host code does nothing wrong the moment the bytes land. It carries dead
configuration, and its window toggle is unreachable from the button until the menu is wired.

## What the copy owes

- Whole-folder copy of both payloads from the tag. Done, and both diffs are empty afterwards.
- `CLAUDE.md` provenance line `v1.57.0` -> `v1.58.0`, in the same commit. Done.
- No `tests/run.lua` wiring, since the kit did not change.

## The suite after the copy

```
/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .            # 0 / 0 in 137 files
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua  # 2037 passed, 0 failed, 0 skipped
```

Before the copy the suite stood at 2041 passed, 0 failed. Straight after the copy it stood at 2032
passed, 9 failed (the nine cases above). After the re-pins it stands at 2037. Six of the nine are
rewritten in place and three are removed: the perf-suspend left click (merged into the disabled
one), the perf-suspend tooltip hint and the rung-(a) locale label. One passing case is removed too,
the separate right-click case, which the adoption commit replaces with the menu cases.
