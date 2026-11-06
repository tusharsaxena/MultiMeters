Delta: LibKa0s v1.89.0 -> v1.90.0

Written before the copy. Payload extracted with
`git -C ../LibKa0s archive v1.90.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/rv190-mm`
(commit `4485b8f`). v1.90.0 is a local tag, not yet pushed: `git ls-remote --tags origin v1.90.0` prints nothing,
which is expected, and this is a new tag for this addon, not a refresh. Run:
`../Ka0sAddonsCommonTasks/docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/`, item SF1-RV-MM. Decisions come from that run's
`SF1_SMOKE_FEEDBACK.md` (no interview, no issue filed).

## 3a. Claimed version (the base)

`grep -n '[Bb]undles' CLAUDE.md` -> `62:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0 (MIT).`

Cross-check: `git log -1 --format=%H -- libs/LibKa0s tests/_kit` -> `2746ad0` (V89-MM: Re-vendor LibKa0s v1.89.0),
whose `CLAUDE.md` line names v1.89.0. The two agree: base **v1.89.0**.

Step 0 pre-flight for this addon: newest single-tag bundle `2026-11-06-v1.89.0`, line 1
`Delta: LibKa0s v1.85.0 -> v1.89.0`; `git show 2746ad0^:CLAUDE.md` names v1.85.0. `ok`, no base correction.

Range: `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0` (4 commits: `7d42f4e` SF1-L1, `b9f7651` SF1-L2,
`4ac9f3c` and `4485b8f` SF1-L3). `git -C ../LibKa0s diff --stat v1.89.0 v1.90.0 -- LibKa0s testkit tools`: 7 files,
all under `LibKa0s/` (Core, OptionsAppearance, Skin, SkinPaint, SkinPaintExtras, Widgets, WidgetsAutocomplete);
`testkit/` and `tools/` unchanged.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` agrees with v1.89.0
(Core 15, Widgets 23, Skin 16, ...). Line and bytes agree.

## 3c. Per-file minor delta (only the files that moved; the loop over the tag's `LibKa0s.xml`)

| File | Old | New |
|---|---|---|
| `Core.lua` | Core 15 | Core 16 |
| `Skin.lua` | Skin 16 | Skin 17 |
| `SkinPaint.lua` | PAINT 18 | PAINT 19 |
| `SkinPaintExtras.lua` | EXTRAS 17 | EXTRAS 18 |
| `Widgets.lua` | Widgets 23 | Widgets 24 |
| `WidgetsAutocomplete.lua` | AUTOCOMPLETE 7 | AUTOCOMPLETE 8 |
| `OptionsAppearance.lua` | APPEARANCE 6 | APPEARANCE 7 |

No new file and no removed file. No cross-major skew.

## 3d. Diffs, before the copy

`diff -rq --strip-trailing-cr /tmp/claude-1000/rv190-mm/LibKa0s libs/LibKa0s` (the undeclared-icon `Only in` lines
aside): the seven files above differ. No `Only in libs/LibKa0s` line: nothing removed upstream.
`diff -rq --strip-trailing-cr /tmp/claude-1000/rv190-mm/testkit tests/_kit`: empty.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:
Bus, Compat, Core (`core/CoreSetup.lua`), DebugLog, Env, Launcher, Lifecycle, Media, Options
(`settings/OptionsSetup.lua`, `settings/Schema_Compose.lua`), Perf, Pool, Schema, Sim, Skin (`core/SkinSetup.lua`,
`core/Database_Migrations.lua`), Slash, Widgets (`modules/Export_Modal.lua`, `modules/Window.lua`,
`modules/Window_Frame.lua`, `modules/Window_Header.lua`, `settings/ColumnBlocks.lua`). Unchanged from v1.89.0.
Every moved major is consumed.

## 3f. Kit revision

`grep -n 'Kit.VERSION' /tmp/claude-1000/rv190-mm/testkit/framework.lua tests/_kit/framework.lua` -> 51 and 51.
Both payloads still move together in one commit (the pairing rule; the whole-folder copy satisfies it).

## 3g. Contract delta

Moved and consumed: Core (15 -> 16), Widgets (23.5.12.6.7.5 -> 24.5.12.6.8.5), Skin (16.1.27.8.18.17.17.4.9 ->
17.1.27.8.19.18.17.4.9), Options (OptionsAppearance 6 -> 7).

- Core 16: `__PixelSize`, `__WatchPixels`, `__OnPixelScale`, `__PixelBackdrop`, all internal (`__`); no member
  manifest moves (`docs/api/Core/version-16-docs.md`). Widgets and Skin resolve them at call time and draw as
  before without them, so `core/CoreSetup.lua`'s degradation stub owes nothing.
- Widgets 24: `docs/api/Widgets/version-24.5.12.6.8.5-docs.md:27` "What a host owes: nothing. A host's own
  `edgeSize = 1` backdrops are its own". `GetBackdrop()` answers the table as given, so a test reading a
  backdrop back reads `edgeSize = 1`.
- Skin 17: `RegisterOwner(owner, { keepScope = true })`, an additive opt-out. This addon has no documented
  Scope deviation that a copy must keep, and the run assigns `keepScope` only to the Skin Tester (`SF1-ST`).
- OptionsAppearance 7: `lib.__copySkinTo` honours `keepScope`; every other target takes the Scope as before.
- `__Attach*` sites: `settings/Schema_Compose.lua:344` (`optlib.__AttachCompose`). Compose did not move.

### Blockers

None found in the documents. The gate after the copy is the check for stubs and tests (none expected: the CHANGELOG
v1.90.0 block says "No host owes a facade or stub member").

## 3h. Span check

The listing from the skill (horizon `2026-08-25`): vendored 69 tags, recorded 69, unrecorded: none. No span bundle.

## 3i. Icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `63:LibKa0s icons: chat, ph:chat-text, chevron-down, chevron-up, clear,
close, confirm, copy, expand, export, eye, info, lock, minimise, move, reset, segment, settings, sort-down, sort-up,
spreadsheet, unlock, volume-high.` It is the next non-blank line after the provenance line. Kept as is: no
library-drawn name arrives in this range (v1.90.0 changes edges, not art). Hand lists have drifted before (KickCD
`tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client smoke is the
backstop.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: `tests/test_mediasetup.lua:90,115,126`
and `tests/test_options_panel.lua:889-890` open only declared names (green at v1.89.0 after the same prune). No blocker.
