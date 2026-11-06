Delta: LibKa0s v1.90.0 -> v1.91.0

Written before the copy. Payload extracted with
`git -C ../LibKa0s archive v1.91.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/fu-rv-mm/new`
(commit `55bfbb4`). v1.91.0 is a local tag, not yet pushed: `git ls-remote --tags origin v1.91.0` prints nothing,
which is expected, and this is a new tag for this addon, not a refresh. Run:
`../Ka0sAddonsCommonTasks/docs/2026-11-06-FOLLOWUPS_V1_91/`, item FU-RV-MM. Decisions come from that run's
`00_PLAN.md` (no interview, no issue filed).

## Step 0

Skipped as a roster-wide table. The installed skill's roster regex (`\]\(\.\./\.\./…/\)`) matches nothing in
ADDONS.md's current `` `../../<Folder>/` `` format, and its `tag_at` helper arrived with its positionals
substituted. Both are fixed upstream by this run (FU-DC1). For this addon alone, with `tag_at` rewritten with named
variables: newest single-tag bundle `2026-11-06-v1.90.0`, line 1 `Delta: LibKa0s v1.89.0 -> v1.90.0`; the
re-vendor commit that first names v1.90.0 is `67fdb87`, and `67fdb87^:CLAUDE.md` names v1.89.0. `ok`, no base
correction.

## 3a. Claimed version (the base)

`grep -n '[Bb]undles' CLAUDE.md` -> `62:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0 (MIT).`

Cross-check: `git log -1 --format=%H -- libs/LibKa0s tests/_kit` -> `a8d6d71` (SF2-RV-MM: Refresh LibKa0s v1.90.0),
whose `CLAUDE.md` line names v1.90.0. The two agree. A `diff -rq` of the v1.90.0 extract against
`libs/LibKa0s` (pruned icons aside) and `tests/_kit` is empty: base **v1.90.0**.

Range: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0` (7 commits: `55d3b0f` FU-L1; `d72dc4a`, `c1ed261`,
`acc9640`, `3f7be30` FU-L2; `1938837`, `55bfbb4` FU-L3). `git -C ../LibKa0s diff --stat v1.90.0 v1.91.0 -- LibKa0s
testkit`: 9 files, all under `LibKa0s/` (Core, CorePixel new, LibKa0s.xml, SkinAceConfirm new, SkinPaintExtras,
SkinPaintHud new, Widgets, WidgetsDropdown new, WidgetsLineChart); `testkit/` unchanged.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` agrees with v1.90.0
(Core 16, Widgets 25, EXTRAS 18, CHART 6, ...). Line and bytes agree.

## 3c. Per-file minor delta (only the files that moved; the loop over the tag's `LibKa0s.xml`)

| File | Old | New |
|---|---|---|
| `Core.lua` | Core 16 | Core 17 |
| `CorePixel.lua` | (new) | PIXEL 1 |
| `SkinPaintExtras.lua` | EXTRAS 18 | EXTRAS 19 |
| `SkinPaintHud.lua` | (new) | HUD 1 |
| `SkinAceConfirm.lua` | (new) | CONFIRM 1 |
| `Widgets.lua` | Widgets 25 | Widgets 26 |
| `WidgetsDropdown.lua` | (new) | DROPDOWN 1 |
| `WidgetsLineChart.lua` | CHART 6 | CHART 7 |

Four new files, each in the tag's `LibKa0s.xml` directly after the file it was peeled from (CorePixel after Core;
SkinPaintHud and SkinAceConfirm after SkinPaintExtras; WidgetsDropdown after Widgets). No removed file. No
cross-major skew.

## 3d. Diffs, before the copy

`diff -r --strip-trailing-cr /tmp/claude-1000/fu-rv-mm/new/LibKa0s libs/LibKa0s` (the undeclared-icon `Only in`
lines aside): `Core.lua`, `LibKa0s.xml`, `SkinPaintExtras.lua`, `Widgets.lua` and `WidgetsLineChart.lua` differ;
`Only in` the extract: `CorePixel.lua`, `SkinAceConfirm.lua`, `SkinPaintHud.lua`, `WidgetsDropdown.lua`. No
`Only in libs/LibKa0s` line: nothing removed upstream. `diff -rq /tmp/claude-1000/fu-rv-mm/new/testkit tests/_kit`:
empty.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:
Bus, Compat, Core (`core/CoreSetup.lua`), DebugLog, Env, Launcher, Lifecycle, Media, Options
(`settings/OptionsSetup.lua`, `settings/Schema_Compose.lua`), Perf, Pool, Schema, Sim, Skin (`core/SkinSetup.lua`,
`core/Database_Migrations.lua`), Slash, Widgets (`modules/Export_Modal.lua`, `modules/Window.lua`,
`modules/Window_Frame.lua`, `modules/Window_Header.lua`, `settings/ColumnBlocks.lua`). Unchanged from v1.90.0.
Every moved major (Core, Skin, Widgets) is consumed. This addon draws no `W.LineChart`
(`grep -rn LineChart --include='*.lua' . | grep -v libs/` finds nothing).

## 3f. Kit revision

`grep -n 'Kit.VERSION' /tmp/claude-1000/fu-rv-mm/new/testkit/framework.lua tests/_kit/framework.lua` -> 51 and 51.
Both payloads still move together in one commit (the pairing rule; the whole-folder copy satisfies it).

## 3g. Contract delta

Moved and consumed: Core (16 -> 17.1), Widgets (25.6.13.6.8.5 -> 26.1.6.13.7.8.5), Skin
(17.1.27.8.19.18.17.4.9 -> 17.1.27.8.19.19.1.1.17.4.9).

- Core 17 / CorePixel 1 (`docs/api/Core/version-17.1-docs.md`): the pixel edges section (`__PixelSize`,
  `__OnPixelScale`, `__WatchPixels`, `__PixelBackdrop`, `__RefreshPixelBackdrops`) moved to `CorePixel.lua`
  unchanged. All internal; nothing in this addon outside `libs/` names them
  (`grep -rnE '__Pixel|__WatchPixels|__OnPixelScale' --include='*.lua' . | grep -v libs/` finds nothing), so no
  stub mirrors a moved member.
- Widgets 26 / WidgetsDropdown 1 (`docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md`): `lib.Dropdown`,
  `lib.ContextMenu`, `lib.CloseMenu` moved unchanged to `WidgetsDropdown.lua`. Same members, same descriptors.
  WidgetsLineChart 7 draws its lines in physical pixels; not consumed here.
- SkinPaintExtras 19 / SkinPaintHud 1 / SkinAceConfirm 1 (`docs/api/Skin/version-17.1.27.8.19.19.1.1.17.4.9-docs.md`):
  `S.BarGloss`, `S.HudFont` and the AceConfigDialog confirmation box moved unchanged.
- `__Attach*` sites: `settings/Schema_Compose.lua` (`optlib.__AttachCompose`). Compose did not move.

CHANGELOG `## v1.91.0`: "No member, option or behavior changes", "No host owes a facade or stub member", and "a
host test loader or file list that names library files adds the four new ones".

### Blockers

- `tests/run.lua`'s `EXPECTED` list of library files (the belt over `Loader.xmlFiles`) adds the four new files, in
  `LibKa0s.xml` order (`CorePixel.lua`, `SkinPaintHud.lua`, `SkinAceConfirm.lua`, `WidgetsDropdown.lua`). The
  loaders themselves (`tests/run.lua`, `tests/perf.lua`) derive their lists from `LibKa0s.xml` and need no change.
- `tests/test_export_modal.lua`'s comments (three places) cite the shared menu and `makeMenuRow` as living in
  `Widgets.lua`; they now live in `WidgetsDropdown.lua`. File-path citations corrected, comment-only.
- No test pins an exact minor of a moved file (`tests/test_coresetup.lua:279` reads `lib.MODULES.Core >= 10`,
  still true). No stub mirrors a moved member.

## 3h. Span check

The listing from the skill, its `tag_at` rewritten with a named variable (horizon `2026-08-25`): unrecorded: none.
No span bundle.

## 3i. Icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `63:LibKa0s icons: chat, ph:chat-text, chevron-down, chevron-up, clear,
close, confirm, copy, expand, export, eye, info, lock, minimise, move, reset, segment, settings, sort-down, sort-up,
spreadsheet, unlock, volume-high.` It is the next non-blank line after the provenance line. Kept as is: no
library-drawn name arrives in this range (the peels move code, FU-L1 changes line thickness). Hand lists have
drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's
in-client smoke is the backstop.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: `tests/test_mediasetup.lua:90,115,126`
and `tests/test_options_panel.lua:889-890` open only declared names (green at v1.90.0 after the same prune). No blocker.
