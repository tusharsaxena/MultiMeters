Delta: LibKa0s v1.66.0 -> v1.67.0

# 01 — Delta (MultiMeters)

Item CA-MM-RV of the 2026-10-02 LibKa0s census adoption
(`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_CENSUS_ADOPTION/`), branch
`feat/2026-10-02-libka0s-census-adoption`. Copied from the **local** tag `v1.67.0` (`0bccf4c`) with
`git -C ../LibKa0s archive v1.67.0 LibKa0s testkit | tar -x -C <scratch>`, never a branch tip. The
library's checkout was at the tag (`rev-parse HEAD` equals `rev-parse v1.67.0^{commit}`) and clean, and the
archive matched its working tree byte for byte (CRLF, as the addon's vendored copy has been since the
last re-vendor).

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` named v1.66.0, written by `048639e` (GI-MM-RV). Base v1.66.0.
`git -C ../LibKa0s log --oneline v1.66.0..v1.67.0`: 6 commits (one merge, the GI-LK-13 census, then
CA-LK-01..03). `git diff --stat v1.66.0 v1.67.0 -- LibKa0s testkit`: 3 files changed, 125 insertions,
36 deletions, all under `LibKa0s/`.

## 3b/3c. Per-file minors (every file whose constant moved; the rest are unchanged)

| File | Old | New |
|---|---|---|
| Core.lua | 9 | 10 |
| Options.lua | 27 | 28 |
| OptionsIdList.lua | IDLIST_MINOR 2 | 3 |

The Options member key moves 27.2.34.2.2.8.1.7.4.2 -> 28.2.34.2.3.8.1.7.4.2. No file added, no file
removed: still fifteen majors across thirty-two files. No cross-major skew.

## 3d. Diffs

Before the copy, `diff -rq <scratch>/LibKa0s libs/LibKa0s` listed exactly `Core.lua`, `Options.lua` and
`OptionsIdList.lua`; `diff -rq <scratch>/testkit tests/_kit` was empty. No `Only in` on either side, so
nothing was added or deleted. After the copy both `diff -r` (bytes) are empty, and
`diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s` is empty.

## 3e. Consumption

Core and Options are consumed (core/, settings/). The two moved surfaces are not yet reached:

- `MakeResizable` has no caller here (`grep -rn MakeResizable core modules settings` is empty); the
  window grip is still hand-rolled in `modules/Window.lua`. CA-MM-02 adopts it.
- `O.IdList` is never drawn here; `settings/OptionsSetup.lua:387` names it only in the library-absent
  stub list. The descriptor's `addonName` is read by the IdList help art alone, so the new
  loaded-addon rung has nothing to check in this host until a list is drawn.

## 3f. Kit revision

`Kit.VERSION` stays 35 (`tests/_kit/framework.lua:20`); the kit payload is byte-identical to v1.66.0's.

## 3g. Contract delta — blockers

None.

- Core 10: `canResize`, `onResizeStop` and `gripParent` are optional; a caller passing none behaves as on
  minor 9, and this host has no caller. No member is added, so `core/CoreSetup.lua`'s degradation stub
  needs no new name.
- OptionsIdList 3: the help art's `addonName` rung now checks the addon is loaded; no IdList here.
- Options 28: docblock only; no member, field, string or floor moves.

Gate after the copy: tests 2168 passed, 0 failed, 1 skipped, 2169 total (identical to before the copy,
once CLAUDE.md's provenance line was rolled; with the line still at v1.66.0 the provenance test failed, as
it should). luacheck 0/0 in 146 files.
