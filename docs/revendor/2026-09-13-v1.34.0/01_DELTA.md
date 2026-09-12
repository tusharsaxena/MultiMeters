# 01 — Delta: LibKa0s v1.33.0 → v1.34.0

Recorded before anything was copied. The payload was extracted from the tag, not from the
sibling's working tree:

```sh
git -C ../LibKa0s rev-parse v1.34.0 'v1.34.0^{commit}'
# 916504409cb3508bd71af77c1b1a70a00bcd249c   (tag object)
# 33bae81ecf6de8e8d196ea87663882aceb140945   (commit)
git -C ../LibKa0s archive v1.34.0 LibKa0s testkit | tar -x -C <scratch>/
```

The tag is local to `../LibKa0s` (branch `feat/2026-09-13-v1.34.0`). `tests/test_vendor_sync.lua`
compares against the sibling at the tag `CLAUDE.md` names, so a local tag is enough.

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 52:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.33.0 (MIT).
```

## 3b. Actual version

Options 17, OptionsCompose 4 and Slash 9, with every other file at the minor v1.33.0 shipped. The
claim and the bytes agree.

## 3c. Per-file minor delta

| File | Constant | Old | Tag |
|---|---|---|---|
| `Options.lua` | `MINOR` | 17 | **18** |
| `OptionsCompose.lua` | `_MINOR` | 4 | **5** |
| `Slash.lua` | `MINOR` | 9 | **10** |
| every other shipped file | its `MINOR` / `*_MINOR` | unchanged | unchanged |

This matches the v1.34.0 block of `CHANGELOG.md` at the tag. There is no cross-major skew.

## 3d. What moved, and both diffs

```sh
git -C ../LibKa0s diff --name-status v1.33.0 v1.34.0 -- LibKa0s testkit
# M LibKa0s/Options.lua   M LibKa0s/OptionsCompose.lua   M LibKa0s/Slash.lua
# M testkit/README.md     M testkit/framework.lua        M testkit/mock_base.lua
```

No additions or deletions. After the whole-folder `rsync -rt --delete` from the extracted archive,
both `diff -r` forms, with and without `--strip-trailing-cr`, are empty for both payloads.
`tests/_kit/run-automated-tests.sh` is still recorded `100755`.

## 3e. Consumption map

`Options` is looked up at `settings/OptionsSetup.lua:110` and `settings/Schema_Compose.lua:476`;
the descriptor supplies `resetProfile` at `settings/OptionsSetup.lua:197`, and
`settings/Schema_Compose.lua:628` composes the General page's Master controls through
`MasterControls`, the composer whose Reset-all tooltip moved. `Slash` is looked up at
`settings/Slash.lua:110`. All three files that moved are consumed.

## 3f. Kit revision, and the pairing rule

`Kit.VERSION` goes from 18 to **19**. Both payloads were copied whole in one commit.

Kit 19's `OnProfileReset` change is unreachable here. `tests/wow_mock.lua` wraps the kit's AceDB
and re-fires string-form handlers itself, already with no key on a reset; only function-form
callbacks reach the kit's `fire`, and production registers none.

## Baseline (before the copy, at `e66fa0c`)

```sh
lua tests/run.lua   # 1823 passed, 0 failed, 0 skipped, 1823 total
luacheck .          # 0 warnings / 0 errors in 123 files
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .   # no warnings
```
