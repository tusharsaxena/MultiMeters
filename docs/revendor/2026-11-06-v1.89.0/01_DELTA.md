Delta: LibKa0s v1.85.0 -> v1.89.0

Written before the copy. Payload extracted with
`git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/v89-mm/x`
(tag object `0bd4839`, commit `df00e5f`). Run: `../Ka0sAddonsCommonTasks/docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/`, item V89-MM.

## 3a. Claimed version (the base)

`grep -n '[Bb]undles' CLAUDE.md` -> `62:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).`

Cross-check: `git log -1 --format=%H -- libs/LibKa0s tests/_kit` -> `47fa201` (R6-RV2: Re-vendor LibKa0s v1.85.0),
whose `CLAUDE.md` line names v1.85.0. `git log "47fa201..HEAD" -- CLAUDE.md` lists no roll. The two agree:
base **v1.85.0**. Payload today == v1.85.0 at the tag (`diff -rq` against the v1.85.0 extract, pruned to the same
declaration: no output for `libs/LibKa0s`; `tests/_kit` prints `kit-matches`).

Step 0 pre-flight (`inputs/step0-preflight.txt` of the run): `2026-11-01-v1.85.0  base v1.84.0  vendored-before v1.84.0@b7f93a8  ok`.
No base correction.

Range: `git -C ../LibKa0s log --oneline v1.85.0..v1.89.0` (27 commits); `git -C ../LibKa0s diff --stat v1.85.0 v1.89.0`
(83 files changed).

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` agrees with v1.85.0
file for file (Toast 3, Widgets 22, DIAG 6, no IconBrowser). Line and bytes agree.

## 3c. Per-file minor delta (only the files that moved; the loop over the tag's `LibKa0s.xml`)

| File | Old | New |
|---|---|---|
| `Toast.lua` | Toast 3 | Toast 4 |
| `Widgets.lua` | Widgets 22 | Widgets 23 |
| `DebugLogDiagnostics.lua` | DIAG 6 | DIAG 7 |
| `IconBrowserSources.lua` | (new) | `LibKa0s-IconBrowser-1.0` 1 |
| `IconBrowserWindow.lua` | (new) | WINDOW 1 |
| `IconBrowser.lua` | (new) | BROWSER 1 |

No consumer file is ahead of or behind the tag in any other way. No cross-major skew.

## 3d. Diffs, before the copy

`diff -rq --strip-trailing-cr x/LibKa0s libs/LibKa0s` (icon `Only in` lines aside): `DebugLogDiagnostics.lua`,
`LibKa0s.xml`, `Toast.lua`, `Widgets.lua` differ; `IconBrowser.lua`, `IconBrowserSources.lua`,
`IconBrowserWindow.lua` only in the tag. No `Only in libs/LibKa0s` line: nothing removed upstream.
`diff -rq --strip-trailing-cr x/testkit tests/_kit`: `README.md`, `framework.lua`, `mock_ace.lua` differ.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:
Bus, Compat, Core, DebugLog, Env, Launcher, Lifecycle, Media, Options, Perf, Pool, Schema, Sim, Skin, Slash,
Widgets (`modules/Export_Modal.lua`, `modules/Window.lua`, `modules/Window_Frame.lua`, `modules/Window_Header.lua`,
`settings/ColumnBlocks.lua`). Not looked up: Toast, IconBrowser, Charts, Glow, Item.

The one `W.ContextMenu` use site is `modules/Window_Header.lua:1234` (`OpenSkinnedSegmentMenu`).

## 3f. Kit revision

`grep -n 'Kit.VERSION' x/testkit/framework.lua tests/_kit/framework.lua` -> 51 (tag) vs 50 (addon). Both payloads
move together in one commit (the pairing rule; whole-folder copy satisfies it by construction).

## 3g. Contract delta

Moved and consumed: Widgets (22 -> 23) and DebugLog (DIAG 6 -> 7).

- Widgets: `diff` of `docs/api/Widgets/version-22.5.12.6.7.5-docs.md` (v1.85.0) against
  `docs/api/Widgets/version-23.5.12.6.7.5-docs.md` (v1.89.0). Additive only: `submenu`, `radio`, `selected`,
  `opts.check` all **Since 23** (v1.89.0 doc lines 19-40, field rows :27-29, member table :891-893). "Every single-level menu,
  a dropdown's and a host's, is unchanged"; "What a consumer owes: nothing for a flat menu". The segment menu is flat.
- DebugLog: `git -C ../LibKa0s diff v1.85.0 v1.89.0 -- LibKa0s/DebugLogDiagnostics.lua`: the MAJORS list gains
  `IconBrowser`. No host-supplied member.
- `__Attach*` sites: `settings/Schema_Compose.lua:344` (`optlib.__AttachCompose`). Compose did not move.
- Toast 3 -> 4 adds `SetStack`, `Visible`, `FrameFor`; this addon has no Toast lookup and no Toast stub
  (`grep -rn Toast --include='*.lua' modules settings core tests` finds nothing), so nothing is owed.

### Blockers

None.

## 3h. Span check

The listing from the skill (horizon `2026-08-25`): vendored 68 tags, recorded 68, unrecorded: none. No span bundle.

## 3i. Icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `63:LibKa0s icons: chat, ph:chat-text, chevron-down, chevron-up, clear, close, confirm, copy, expand, export, eye, info, lock, minimise, move, reset, segment, settings, sort-down, sort-up, spreadsheet, unlock, volume-high.`
It is the next non-blank line after the provenance line, which ends its own sentence. Kept as is (run plan:
keep it unless a fact forces a change). No new library-drawn name arrives in this range for a surface this addon
wires: the Widgets 23 tick and submenu arrow draw only for rows that ask for them, and the arrow is client art.
Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`);
the owner's in-client smoke is the backstop for a name the host forgot to declare.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: `tests/test_mediasetup.lua:90,115,126`
and `tests/test_options_panel.lua:889-890` open declared names only (green at v1.85.0 against the same declaration);
`tests/prose_waivers.lua:16` and `tests/test_headercontrols.lua:604` are comments. No blocker.

Dead stub mirrors: `grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds nothing.

## Step 4. The copy (recorded after it)

The copy was resumed from an interrupted session. The payload was re-extracted fresh
(`git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/v89-mm-1559358`) and both
payloads were copied whole again (`cp -r x/LibKa0s/. libs/LibKa0s/`, `cp -r x/testkit/. tests/_kit/`). Before the
prune, `diff -r --strip-trailing-cr` and `diff -rq` printed nothing for either payload. After the provenance roll,
`lua x/tools/prune-icons.lua .` printed `23 icon(s) declared; kept 25 file(s), removed 5815`. The post-prune
`diff -r --strip-trailing-cr x/LibKa0s libs/LibKa0s` prints only `Only in x/LibKa0s/media/icons…` lines, and
`diff -r x/testkit tests/_kit` prints nothing.
