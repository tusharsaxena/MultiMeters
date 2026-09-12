# 02 — Candidates: what v1.32.0 carries for MultiMeters

## Sources

```
git -C ../LibKa0s log --oneline v1.31.0..v1.32.0
git -C ../LibKa0s show v1.32.0:CHANGELOG.md                                  # block "## v1.32.0 — 2026-09-12"
git -C ../LibKa0s show v1.32.0:docs/api/Options/version-16.15.4.3-docs.md
git -C ../LibKa0s show v1.32.0:docs/api/Slash/version-8-docs.md
git -C ../WowAddonStandards show 7883278:standards/standards/debug-logging.md # §10, final text
```

The range holds these commits:
- `f7d78cd`: Options 16 and Slash 8 bracket their reset walks.
- `4083889`: the review, where bulkEnd's `info` names a profile reset.
- `c6314d6`: a CLAUDE.md luacheck-scope note.
- `4353908` and `e18dd12`: two release-record commits.

## Class A: reached the addon on the copy alone

None. A host that supplies neither `bulkBegin` nor `bulkEnd` runs v1.31.0's walk exactly, with no
`pcall` on the path, and this host supplied neither at the copy. The suite total did not move
(1804 / 0 / 0 before and after).

## Class B: host change required

### B1. The Options bracket around `RestoreDefaults` and `RestoreAllDefaults`

- **What.** Two optional descriptor fields. `bulkBegin(act, scope)` runs before the walk.
  `bulkEnd(act, scope, count, err, info)` runs once after it, always, with
  `info = { profileReset = boolean }`.
- **Evidence.** `version-16.15.4.3-docs.md`, "The two fields" and "What the host logs — the
  contract".
- **Why this addon needs it.** Before it, each Defaults press logged one `[Set]` line per row it
  wrote. A General press logged 18, and the Columns page logged 9 including its array. §10 makes
  that one line.
- **Touches.** `settings/OptionsSetup.lua` (the descriptor), `settings/Schema_Paths.lua` (the mute
  and the count), `settings/Columns.lua` (its array write joins the bracket).
- **Recommendation.** Adopt. The standard's MUST binds, and the library's `count` is not the
  standard's N. It counts rows `applyDefault` returned, including rows already at their default, so
  the seam counts rows whose stored value moved.

### B2. The Slash bracket around `CliResetAll`

- **What.** The same pair on the Slash descriptor.
- **Evidence.** `version-8-docs.md`.
- **Touches.** `settings/Slash.lua`.
- **Finding.** `/mm resetall` reached `CliResetAll`, and that is the bug the rollout names.
  `CliResetAll` walks every row through `applyDefault`, and every `window.` path resolves against
  the active window. The verb therefore reset one window's rows, logged 169 `[Set]` lines, and
  deleted no window, while four docs called it a profile reset (options-ui-§12). The fix routes the
  verb to `Helpers.RestoreAllDefaults`, so nothing reaches `CliResetAll` any more.
- **Recommendation.** Adopt the pair defensively. It is one line, and it keeps any future caller of
  `CliResetAll` to one line.

## Class C: whole-module adoption

None. The consumption map (`01_DELTA.md` §3e) is v1.31.0's.
