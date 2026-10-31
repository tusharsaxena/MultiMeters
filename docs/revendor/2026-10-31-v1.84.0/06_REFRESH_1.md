# 06 — Refresh 1 (MultiMeters)

The local tag `v1.84.0` was re-cut before it was pushed, on the owner's ruling of 2026-11-01 that
`Ka0sMedia_*` is the only media picker in the collection. `git -C ../LibKa0s ls-remote --tags origin v1.84.0`
prints nothing, so this is a refresh of the tag this bundle records. `01_DELTA.md` stays as it was.

- Old tag commit: `e917ccd`
- New tag commit: `7a8bc0f133ed118d2c79c7c5288b97964e24fae5`
- Kit revision: 47 on both sides. The range changes nothing under `testkit/`.

## Per-file minors

`git -C ../LibKa0s diff --stat e917ccd 7a8bc0f -- LibKa0s testkit` names six files. Every other shipped
file is identical.

| File | Old | New |
|---|---|---|
| `Options.lua` | 35 | 36 |
| `OptionsCompose.lua` | 15 | 16 |
| `OptionsMedia.lua` | 1 | 2 |
| `OptionsScroll.lua` | 9 | 10 |
| `OptionsWidgets.lua` | 40 | 41 |
| `SkinAce.lua` | 5 | 6 |

## Blockers, fixed in the refresh commit

- The composers now write `dialogControl = "Ka0sMedia_*"`. `tests/test_schema.lua`'s font assertion went
  red, and its Border `None` walk would have gone quietly empty, because it matched on `LSM30_Border`.
  Both name `Ka0sMedia_*` now.
- `lib.__PatchLSM30Border` is a no-op that answers false, so the options-panel case that proved its
  registration has nothing to prove. The case is removed. The call itself goes in `M3-MEDIA`.

## Declaration

The `LibKa0s icons:` line is kept. The prune kept 20 files and removed 5820 from the fresh copy.

## Gate

`ka0s-bounded luacheck .`: 0 warnings / 0 errors in 183 files.
`ka0s-bounded lua tests/run.lua`: 2448 passed, 0 failed, 1 skipped.
