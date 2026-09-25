Delta: LibKa0s v1.56.0 -> v1.57.0

# 01 — Delta

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.57.0 LibKa0s testkit | tar -x -C <scratch>/new`. The tag points at
commit `aa37bc9` (`git -C ../LibKa0s rev-list -n1 v1.57.0`) and is the newest tag
(`git -C ../LibKa0s tag --sort=-v:refname | head -1`). When this ran it existed only as a local tag
in the sibling checkout and had not been pushed.

This bundle covers the delta and the copy. The adoption is fixed in advance by the remediation
plan's M5 row (`M5_LAUNCHER_TOOLTIP.md`, item M5-MM) rather than chosen candidate by candidate, so
there is no `02_CANDIDATES.md`, `03_DECISIONS.md` or `04_EXECUTION_PLAN.md` in this folder.
`05_SUMMARY.md` records what the second M5-MM commit adopted.

## Step 0 — Base check of the newest single-tag bundle

```
git show fca380b^:CLAUDE.md | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
git show fca380b:CLAUDE.md  | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
```

`docs/revendor/2026-09-23-v1.56.0/` states base v1.55.0. The provenance line before its vendoring
commit `fca380b` named v1.55.0, and `fca380b` itself names v1.56.0. **ok**, no correction owed.

## 3a — Claimed version, and the base

```
grep -n '[Bb]undles' CLAUDE.md
```

> 54: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.56.0** (MIT).

Cross-check against the last commit that touched either payload:

```
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)     # fca380b, "RV-MM: Re-vendor LibKa0s v1.56.0 ..."
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'   # v1.56.0
```

They agree, so **the base is v1.56.0**.

```
git -C ../LibKa0s log --oneline v1.56.0..v1.57.0     # 2 commits, both LK-36
git -C ../LibKa0s diff --stat v1.56.0 v1.57.0        # 17 files, +9507 / -35; one payload file
```

## 3b — Actual version, before this run

```
git -C ../LibKa0s archive v1.56.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit && echo payload-matches
```

`payload-matches` printed: before the copy, every vendored byte matched v1.56.0. The provenance line
and the bytes agree.

## 3c — Per-file minor delta

| File | Constant | v1.56.0 (vendored) | v1.57.0 |
|---|---|---|---|
| `Launcher.lua` | `MINOR` | 2 | **3** |

Every other file is byte-identical: `Core` 8, `Env` 1, `Compat` 1, `Lifecycle` 2, `Bus` 2,
`Schema` 2, `Pool` 3, `Item` 2, `Media` 4, `Widgets` 10, `WidgetsDragHandle` 2, `DebugLog` 13,
`Slash` 15, `Options` 24, `OptionsWidgets` 31, `OptionsTabs` 4, `OptionsCompose` 7,
`OptionsScroll` 4, `Perf` 13, `PerfPanel` 5. No file was added or removed, and no `NEEDS_*` floor
rises (LibKa0s `CHANGELOG.md`, v1.57.0 header paragraph).

## 3d — Both diffs, both directions (before the copy)

```
diff -rq <scratch>/old <scratch>/new
```

- `LibKa0s/`: one file differs, `Launcher.lua` (+109 / -4). `LibKa0s.xml` and the media are
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
`core/LauncherSetup.lua:79`. The rest of the map is unchanged from the v1.56.0 bundle, except that
`Schema` is now consumed (`settings/Schema_Paths.lua:85`, since MM-14).

## 3f — Kit revision, and the pairing rule

`tests/_kit/framework.lua:20: Kit.VERSION = 26` on both sides. The kit does not move in this
release, and the pairing rule holds because both payloads come whole from one tag in one commit.

## 3g — Contract delta

**The moved major this addon consumes:** Launcher, 2 -> 3. Read
`LibKa0s/docs/api/Launcher/version-3-docs.md`, `What changed at this version`, against version 2.
The library's own summary is `CHANGELOG.md`, v1.57.0, `### What a consumer owes on re-vendoring
v1.57.0`.

What reaches this addon without being asked for:

- **The LDB object's `OnTooltipShow` is now the library's `drawTooltip`, on every host.** The host
  hook `onTooltipShow` is called inside it, between the status block and the click hints. This
  addon's hook (`core/LauncherSetup.lua:146-154`) draws the addon's title, a `Version` double line
  and both click hints. After the copy those lines appear a second time, inside the library's own
  title and hints (anti-pattern #89). Nothing raises and no test goes red; the duplicate is the
  owed adoption below.
- **The tooltip draws while the addon is disabled**, and the left-click hint reads
  `disabled — /mm enable`, read out of `disabledLine()`. This addon's `disabledLine` answers
  `NS.Slash:DisabledLine()` while disabled and the perf-suspend line while suspended. The suspend
  line names no `/<slash> enable`, so under a perf suspend the hint reads the bare
  `Left-click: disabled`. That is accurate: the click is refused, and `/mm enable` would be the
  wrong advice mid-capture.

Owed by `launcher-§1` (standard v2.66.0), in the second M5-MM commit: `version`, `leftClickLabel`
for rung (a), `isLocked` / `isTestMode` for the states this addon has, and a hook cut down to the
addon's own lines, which here means no hook.

### Blockers

**None.** The host code does nothing wrong the moment the bytes land. It is only redundant.

## What the copy owes

- Whole-folder copy of both payloads from the tag. Done, and both diffs are empty afterwards.
- `CLAUDE.md` provenance line `v1.56.0` -> `v1.57.0`, in the same commit. Done.
- No `tests/run.lua` wiring, since the kit did not change.

## The suite after the copy

```
/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .            # 0 / 0 in 137 files
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua  # 2035 passed, 0 failed, 0 skipped
```

Before the copy the suite stood at 2035 passed, 0 failed. Between the copy and the provenance roll,
`libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles` was the one red, which is
the vendor-sync gate working as designed. The roll clears it.
