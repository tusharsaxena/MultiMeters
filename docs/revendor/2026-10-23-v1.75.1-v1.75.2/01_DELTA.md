Delta: LibKa0s v1.75.1 -> v1.75.2 (span: v1.75.1 v1.75.2)

# 01 — Delta: the consolidated span bundle (MultiMeters)

Written 2026-10-23 with item MM-RV of the Ka0sAddonsCommonTasks bundle
`docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`, on branch `feat/2026-10-23-sim-preview-mode-strips`.
This bundle re-vendors nothing. It records two re-vendors that landed between runs, each touching
only `libs/LibKa0s/`, `tests/_kit/` and the CLAUDE.md provenance line:

- `ae676be` (2026-10-23) `Re-vendor LibKa0s v1.75.1 (SimPanel minor 3)`
- `114ab0f` (2026-10-23) `Re-vendor LibKa0s v1.75.2 (SimPanel minor 4)`

The `/dev-copilot:wow-revendor-libka0s` 3h walk, run before this run's copy, goes from the store's
horizon (2026-08-25) over `libs/LibKa0s`, `tests/_kit` and the CLAUDE.md commits that roll the
provenance line. It subtracts the tags `docs/revendor/` records (for span folders, the tags on line 1
of 01_DELTA.md) and printed:

```
v1.75.1
v1.75.2
```

## Base

The span's base is **v1.75.0**, the provenance line before `ae676be`. It is also the newest
recorded bundle, `2026-10-22-v1.75.0/`, as refreshed by its `06_REFRESH.md`.

## Per-file LibStub minors and kit revision

From `git -C ../LibKa0s diff --stat <a> <b> -- LibKa0s testkit` per step, each touched file's
`*_MINOR` constant on both sides, and the tags' `CHANGELOG.md` version blocks.

| Tag (commit) | Moved | Unchanged | Kit |
|---|---|---|---|
| v1.75.1 (`39dfb98`) | `SimPanel.lua` `SIM_PANEL_MINOR` 2 -> **3** (`LibKa0s-Sim-1.0` key 2.2.3): a disabled step row or control keeps its hover tip | every other file at its v1.75.0 minor | 41 (bytes unchanged) |
| v1.75.2 (`154599c`) | `SimPanel.lua` `SIM_PANEL_MINOR` 3 -> **4** (key 2.2.4): the picker's scenario dropdown takes the width the bar leaves | every other file as at v1.75.1 | 41 (bytes unchanged) |

No `NEEDS_*` floor rose, no major was added and no member was removed. The payload stays at
seventeen majors across forty files.

## Consumption

MultiMeters looks up no `LibKa0s-Sim-1.0` outside `libs/` and `tests/`:
`grep -rnoE 'LibStub\("LibKa0s-Sim-1\.0", true\)' . --include='*.lua'` finds only the library's own
`SimPanel.lua:49` and `SimTimeline.lua:62`. The only file that moved in the span is not reached by
this addon, so no contract under a consumed surface moved.
