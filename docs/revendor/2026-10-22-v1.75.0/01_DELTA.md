Delta: LibKa0s v1.71.0 -> v1.75.0

# 01 — Delta (MultiMeters)

Run 2026-10-22 as item MM-RV of the Ka0sAddonsCommonTasks bundle
`docs/2026-10-22-LIBKA0S_ISSUES_45_58/`, under `/dev-copilot:wow-revendor-libka0s` as installed
(dev-copilot 2.4.0). Non-interactive: the owner scope (OWNER_SCOPE B, D and #54) pre-decides the
source, the icon line and every adoption, so nothing was asked.

## Source

The LOCAL annotated tag v1.75.0 (tag object `eae0ee5`, commit `265a89e`). It is not on the remote
yet (`git -C ../LibKa0s ls-remote --tags origin v1.75.0` prints nothing); the push waits on the
owner. Extracted from the tag, never the working tree:

```sh
git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools | tar -x -C <scratch>/
```

## 3a. Base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 55:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
# Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0
```

The line and the last payload commit agree, and the payload matches v1.71.0 (`payload-matches`
from the provenance-only check). Base **v1.71.0**. MultiMeters vendored none of v1.72.0, v1.73.0 or
v1.74.0; the range below covers them, and they need no bundle of their own.

Step 0 pre-flight for this addon: the newest bundle, `2026-10-07-v1.71.0/`, states base v1.70.0,
and the commit that rolled the line to v1.71.0 (`d780061`) had v1.70.0 before it. `ok`, no
correction owed.

3h (tags vendored and never recorded): the walk over `libs/LibKa0s`, `tests/_kit` and the
provenance-rolling `CLAUDE.md` commits since the store's first bundle, minus the recorded tags,
prints nothing. No span bundle.

## 3b and 3c. Per-file minors

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+'` over the vendored files before the
copy and over the tag, file list from the tag's `LibKa0s/LibKa0s.xml`. The vendored minors matched
the v1.71.0 claim exactly. Only the files that moved, with the release that moved each one:

| File | v1.71.0 (vendored) | v1.72.0 | v1.73.0 | v1.74.0 | v1.75.0 |
|---|---|---|---|---|---|
| `Perf.lua` `MINOR` | 14 | **15** | 15 | 15 | 15 |
| `Options.lua` `MINOR` | 28 | 28 | **29** | 29 | 29 |
| `OptionsDrawer.lua` `DRAWER_MINOR` | (absent) | (absent) | **1** | 1 | 1 |
| `Media.lua` `MINOR` | 4 | 4 | 4 | **5** | 5 |
| `MediaIcons.lua` `ICONS_MINOR` | (absent) | (absent) | (absent) | **1** | 1 |
| `OptionsTabs.lua` `TABS_MINOR` | 8 | 8 | 8 | 8 | **9** |
| `Core.lua` `MINOR` | 10 | 10 | 10 | 10 | **11** |
| `DebugLog.lua` `MINOR` | 19 | 19 | 19 | 19 | **20** |
| `DebugLogDiagnostics.lua` `DIAG_MINOR` | 2 | 2 | 2 | 2 | **3** |
| `OptionsIdList.lua` `IDLIST_MINOR` | 4 | 4 | 4 | 4 | **5** |
| `Widgets.lua` `MINOR` | 12 | 12 | 12 | 12 | **13** |
| `Item.lua` `MINOR` | 2 | 2 | 2 | 2 | **3** |
| `PerfPanel.lua` `PANEL_MINOR` | 6 | 6 | 6 | 6 | **7** |
| `Glow.lua` (new major `LibKa0s-Glow-1.0`) | (absent) | | | | **1** |
| `Sim.lua` (new major `LibKa0s-Sim-1.0`) | (absent) | | | | **1** |
| `SimTimeline.lua` `TIMELINE_MINOR` | (absent) | | | | **1** |
| `SimPanel.lua` `SIM_PANEL_MINOR` | (absent) | | | | **1** |

Every other file is unchanged. **WidgetsStepPanel:** no such file at v1.75.0. LK-11 came out as
outcome B: `W.StepPanel` is not public, and the step-panel renderer is Sim-private inside
`SimPanel.lua`. No cross-major skew: after the copy every file is at the tag's minor.

## 3d. Both diffs, before the prune

```sh
diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # 0 lines
diff -r                     <scratch>/LibKa0s libs/LibKa0s   # 0 lines
diff -r --strip-trailing-cr <scratch>/testkit tests/_kit     # 0 lines
diff -r                     <scratch>/testkit tests/_kit     # 0 lines
```

Content and bytes clean on both payloads after the whole-folder copy. No `Only in libs/LibKa0s` or
`Only in tests/_kit` line, so the tag dropped no file this copy still carried. Files added: `Glow.lua`,
`MediaIcons.lua`, `OptionsDrawer.lua`, `Sim.lua`, `SimPanel.lua`, `SimTimeline.lua`,
`tests/_kit/latch.lua`, and the Open Iconic, Phosphor and Game-icons marks the prune then removed.

## 3e. Majors this addon consumes

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Core, Launcher, Bus, DebugLog, Env, Compat, Media, Pool, Perf, Lifecycle, Widgets, Options, Slash
and Schema. Present in the payload with no lookup here: **Item**, **Glow** and **Sim**.

## 3f. Kit revision

`Kit.VERSION` 38 -> **41** (v1.72.0 brought 39; v1.73.0 and v1.74.0 stayed at 39; v1.75.0 brought 40
and 41). Both payloads are copied whole in one commit, so the pairing rule holds by construction.

- **39:** `M.__fireUnconditional` reaches method-name and function handlers after unregister; new
  `testkit/latch.lua` with `Kit.assertLatchHoldOrder`.
- **40:** `tests/test_vendor_sync.lua` holds `media/icons/` to the consumer's `LibKa0s icons:`
  declaration (declared == shipped).
- **41:** the sighted complexity suite reports a crashed `lizard` run in its own bucket, never as a
  pass.

## 3g. Contract changes under unchanged signatures, and how each was handled

- **Kit 39 `__fireUnconditional` reach.** `tests/test_disabled.lua`'s 'Disabled 6' fires every
  registered handler unconditionally and now reaches method-name handlers too. It stayed green: no
  handler of this addon writes, prints or shows while stood down. No addon change.
- **Options 29 scroll keep.** A structural refresh of a page on screen keeps its scroll offset. A
  behavior change on every page with nothing to change in the host (this addon never scrolled back to
  the top by hand). Owner smoke PANEL-48.
- **Drawer parity (OptionsDrawer minor 1).** `tests/test_surface_parity.lua` went red:
  `LibKa0s-Options-1.0: the degraded stub diverges from the live surface in 1 place(s) — Drawer is
  missing`. Fixed: `Drawer` joins the no-op list in `settings/OptionsSetup.lua`'s degradation stub,
  with its reason (no page of this addon draws a drawer). No other member was reported.
- **#45 `__releaseChrome` mirror.** MultiMeters has none:
  `grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` prints
  nothing. Nothing to delete.
- **Compat surface parity.** The Sim answer seam added no public member to `LibKa0s-Compat-1.0`
  (`Compat.lua` stays at minor 1); `parity: NS.Compat and NS.Secrets carry every
  LibKa0s-Compat-1.0 member between them` stayed green. No ignore entry added.
- **Kit 40 icon subset.** See 3i and 3j.
- **Kit 41 crashed-complexity bucket.** `bash tests/_kit/run-automated-tests.sh --suite complexity
  --no-bundle`: pass, 0 warnings, max CCN 15, 4914 functions, verdict green, nothing crashed.
- **Prose gate.** The declaration line spells the library's catalog key `minimise`, which the
  US-English gate (localization-§5) flagged at `CLAUDE.md:56`. Waived per file and per word in
  `tests/prose_waivers.lua`, beside the other files that name that key.

## 3i. The icon declaration

Decided by the item spec (OWNER_SCOPE G), not asked. Written directly under the provenance line:

```
Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.75.0 (MIT).
LibKa0s icons: chat, chevron-down, clear, close, copy, expand, export, info, lock, minimise, reset, segment, settings, sort-down, sort-up, spreadsheet, unlock.
```

The provenance line was already its own paragraph (the file's last line), so nothing was split. All
17 names are unprefixed Open Iconic marks. Draw sites, re-derived with
`grep -rn 'NS.Icon\|Icon(' core modules settings` plus the `art =` / `HANDLE_ICON` tables that
feed it:

| Name | Drawn at |
|---|---|
| close | `modules/HeaderControls.lua:121` (drawIcon `:238`); `settings/Schema.lua` Header label; library-drawn by `Core.MakeCloseButton` through `NS.MakeCloseButton` (`core/CoreSetup.lua:294-295`, caller `modules/Export_Modal.lua:226`), the DebugLog console, PerfPanel and `W.CopyWindow` (the CSV window) |
| copy, clear | library-drawn, DebugLog title bar, wired by `core/DebugLogSetup.lua` |
| minimise | `modules/HeaderControls.lua:131`; Header label |
| expand | `modules/HeaderControls.lua:294` (artFor while minimized) |
| lock, unlock | `modules/HeaderControls.lua:135`, `:289`; Header label |
| settings | `modules/HeaderControls.lua:137`; Header label |
| segment | `modules/HeaderControls.lua:139`; Header label; `settings/ColumnBlocks.lua:74` (HANDLE_ICON, drawn at `:248`) |
| reset | `modules/HeaderControls.lua:141`; Header label |
| export | `modules/HeaderControls.lua:143`; Header label |
| sort-up, sort-down | `modules/Window_Header.lua:125-126`, drawn at `:544` |
| chevron-down | `modules/Export_Modal.lua:715` |
| spreadsheet, chat | `modules/Export_Modal.lua:818`, `:822`, drawn by makeButton at `:271` |
| info | host-passed `W.TestStrip` art (MM-01, OptionsIdList's help mark too; the descriptor passes `addonName`) |

The Header labels are built through `settings/Schema_Compose.lua` `controlLabel` (`:373-376`). Hand
lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`). A pruned icon still resolves to a path and draws blank, and the
gate cannot see a name the host forgot to declare, so the owner's in-client smoke (INSTALL-10) is
the backstop.

**Prune.** `lua <scratch>/tools/prune-icons.lua .` from the tag's `tools/`, after the diffs above:
`17 icon(s) declared; kept 18 file(s), removed 5822`. By set: Open Iconic 207 marks removed (224 at
the tag, 17 kept, with `LICENSE-open-iconic.txt`), Phosphor 1,435 files (the whole `phosphor/`
folder, its license included) and Game-icons 4,180 files (the whole `game-icons/` folder, license
and `AUTHORS.txt` included). `libs/LibKa0s/media/icons/` now holds the 17 `.tga` files and
`LICENSE-open-iconic.txt`, and nothing else.

## 3j. Tests that assumed the whole icon folder

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
```

- `tests/test_mediasetup.lua` 'every icon the header strip draws is one the library ships' became
  'every icon this addon draws is declared and ships': the 17 names above, each on the declaration
  (parsed with the kit's `VendorSync.iconDeclaration`, never a second parser), `NS.Icon(name)`
  non-nil, and `libs/LibKa0s/media/icons/<name>.tga` present.
- 'every name the library ships has a file in the vendored copy' was red by design after the prune;
  it became 'every name the declaration lists has a file in the vendored copy'. That undeclared files
  do not ship is the kit gate's job, and the comment says so.
- `tests/test_options_panel.lua` 'the help-mark art the descriptor points at is vendored on disk'
  became 'the help-mark and test-strip art, info, is declared and vendored'.

No assertion was weakened: every replaced case asserts against the declaration what it used to assert
against the catalog, and the kit gate covers the other direction.

## Stale stamps

`rg -n 'kit 3[89]|revision 3[89]|v1\.7[1-4]\.0' README.md DEPENDENCIES.md docs/*.md tests/*.lua core
modules settings` finds only `tests/test_envsetup.lua:148`, a historical citation that stays. No
present-tense stamp of the kit revision or the tag to remove.
