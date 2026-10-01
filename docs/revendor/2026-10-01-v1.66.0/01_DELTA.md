Delta: LibKa0s v1.65.0 -> v1.66.0

# 01 — Delta (MultiMeters)

Item GI-MM-RV of the 2026-10-01 GitHub issue pass (`Ka0sAddonsCommonTasks/docs/2026-10-01-GITHUB_ISSUE_PASS/`,
spec S4), branch `feat/2026-10-01-github-issue-pass`. Copied from the **local** tag `v1.66.0` (`e4c5ef7`)
with `git -C ../LibKa0s archive v1.66.0 LibKa0s testkit | tar -x -C <scratch>`, never a branch tip.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` named v1.65.0. The last payload commit is `8911e52` (DG-MM-01), whose
CLAUDE.md names v1.65.0, and `diff -rq` of the payload against `git archive v1.65.0` printed
`payload-matches`. Base v1.65.0. `git -C ../LibKa0s log --oneline v1.65.0..v1.66.0`: 24 commits;
`git diff --stat v1.65.0 v1.66.0 -- LibKa0s testkit`: 20 files changed, 2693 insertions, 1651 deletions.

Step 0 for this addon: the newest single-tag bundle, `2026-09-29-v1.63.0/`, states base v1.62.0, and
`git show 070c0f6^:CLAUDE.md` names v1.62.0. No correction. (Its line 1 is a heading, not the
`Delta:` shape; it is frozen and not edited.)

## 3b/3c. Per-file minors (every file whose constant moved; the rest are unchanged)

Loop over `git -C ../LibKa0s show v1.66.0:LibKa0s/LibKa0s.xml`, old from `libs/LibKa0s/`, new from the tag:

| File | Old | New |
|---|---|---|
| Widgets.lua | 11 | 12 |
| WidgetsReorder.lua | (new) | REORDER_MINOR 1 |
| DebugLog.lua | 18 | 19 |
| Slash.lua | 18 | 19 |
| SlashParse.lua | (new) | PARSE_MINOR 1 |
| OptionsWidgets.lua | WIDGETS_MINOR 33 | 34 |
| OptionsTabs.lua | TABS_MINOR 7 | 8 |
| Perf.lua | 13 | 14 |
| PerfSampler.lua | (new) | SAMPLER_MINOR 1 |
| PerfCommands.lua | (new) | COMMANDS_MINOR 1 |

No cross-major skew: the claimed line and the bytes agreed before the copy.

## 3d. Diffs

Before the copy, `diff -rq <scratch>/LibKa0s libs/LibKa0s` listed the seven changed files and four
`Only in <scratch>` files (above); `diff -rq <scratch>/testkit tests/_kit` listed seven changed files and
`lizard_sighted.lua`, `test_lizard_sighted.lua` as new. No `Only in` on the addon side, so nothing was
deleted. After the copy both `diff -r` (bytes) are empty.

## 3e. Consumption

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside libs/ and tests/: Compat, Bus, Core,
DebugLog, Env, Launcher, Lifecycle, Media, Perf, Pool (core/), Widgets (modules/Export_Modal.lua,
settings/ColumnBlocks.lua), Options, Schema, Slash (settings/). Every moved major is consumed.

## 3f. Kit revision

`Kit.VERSION` 34 -> 35 (`tests/_kit/framework.lua:20`). Both payloads move together in one commit.

## 3g. Contract delta — blockers

None. Read against this addon's calls:

- OptionsWidgets 34 `RenderGrid`: a wide item that raised, or a `make` answering exactly `false`, now takes
  no space. `settings/Windows.lua:410,438` passes three non-wide items whose makers answer a widget or
  `nil` (`renderNameBox` :352, `renderCopySource` :373, `renderCopyGroup` :396), never `false`, so what
  is drawn is unchanged.
- Widgets 12 / WidgetsReorder 1: `ReorderList` moved file with no member change; `settings/ColumnBlocks.lua:241`
  calls `W.ReorderList` as before. The payload ships the new file.
- Slash 19 / SlashParse 1: the optional resolver is additive; this addon's Slash `L` carries no `ERR_*`
  key (`grep -rn ERR_BOOL core settings locales` is empty), so the wording is unchanged.
- Perf 14 / PerfSampler 1 / PerfCommands 1: no member moves; budgets are opt-in; the parent row is additive.
- OptionsTabs 8: three opt-in `RenderTabbedSchema` fields, off by default.
- DebugLog 19: refactor only.

Gate after the copy: tests 2145 passed, 0 failed, 1 skipped, 2146 total (2137/0/1/2138 before; +8 is
the kit's new `test_lizard_sighted`), luacheck 0/0 in 146 files.
