# 06 — Refresh 2 (MultiMeters)

The local tag `v1.84.0` was re-cut again before it was pushed, on the owner's ruling of 2026-11-01 that
`lib.__PatchLSM30Border` goes with no stub. `git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints
nothing, so this is a refresh of the tag this bundle records. `01_DELTA.md` stays as it was.

- Old tag commit: `7a8bc0f133ed118d2c79c7c5288b97964e24fae5`
- New tag commit: `b5229b876e803768322fb4d8c66be69f01c8e4a1`
- Kit revision: 47 on both sides. The range changes nothing under `testkit/`.

## Per-file minors

`git -C ../LibKa0s diff --stat 7a8bc0f b5229b8 -- LibKa0s testkit` names three files. Every other shipped
file is identical.

| File | Old | New | What moved |
|---|---|---|---|
| `Options.lua` | 36 | 37 | `lib.__PatchLSM30Border` deleted |
| `OptionsDrawer.lua` | 3 | 4 | a comment's pointer into `Options.lua` |
| `OptionsMedia.lua` | 2 | 3 | a comment's pointer into `Options.lua` |

## Blockers

None. `M3-MEDIA` already removed the only call, so nothing in the addon reaches the deleted member.

## The test

`tests/test_options_panel.lua`'s SharedMediaWidgets case also asserted that `settings/OptionsSetup.lua`
never named the member. The member no longer exists, so that assertion is removed and the case now
covers the TOC and the disk. No guard replaces it. `grep -rn '__PatchLSM30Border'` over the addon's own
Lua, `libs/` and `tests/_kit/` excluded, prints nothing.

## Declaration

The `LibKa0s icons:` line is kept. The prune kept 20 files and removed 5820 from the fresh copy.

## Gate

`ka0s-bounded luacheck .`: 0 warnings / 0 errors in 183 files.
`ka0s-bounded lua tests/run.lua`: 2450 passed, 0 failed, 1 skipped.
