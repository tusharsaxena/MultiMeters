Delta: LibKa0s v1.69.0 -> v1.70.0 (span: v1.69.0 v1.70.0)

# 01 — Delta: the consolidated span bundle (MultiMeters)

Written 2026-10-07 with RV-MM of the 2026-10-07 review and standards audit remediation (finding
MM-A-01, the audit's MM-A-19, cluster C03), on branch `feat/2026-10-07-review-audit-remediation`.
Nothing is re-vendored by this bundle. It records two re-vendors that landed as bare `chore:`
commits outside `/dev-copilot:wow-revendor-libka0s`, each touching only `libs/LibKa0s/`, `tests/_kit/`
and the CLAUDE.md provenance line:

- `824999b` (2026-10-06) `chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)`
- `1ee53cf` (2026-10-07) `chore: re-vendor LibKa0s v1.70.0`

The audit's vendored-tag walk from the store's horizon (2026-08-25) over `libs/LibKa0s`, `tests/_kit`
and the CLAUDE.md provenance rolls, minus the tags `docs/revendor/` records (span folders: line 1 of
01_DELTA.md), printed `v1.69.0` and `v1.70.0`.

## Base

The span's true base is **v1.68.1**, the provenance line before `824999b`
(`git show 824999b^:CLAUDE.md | tail -1` -> `Bundles [LibKa0s](...) v1.68.1 (MIT).`), which is also the
newest recorded bundle, `2026-10-04-v1.68.1/`.

## Per-file LibStub minors and kit revision

Taken from `git -C ../LibKa0s archive <tag> LibKa0s testkit` of v1.68.1, v1.69.0 and v1.70.0, the
per-file `*_MINOR` constants and each major's `MINOR`, and the tags' CHANGELOG version blocks.

| Tag | Moved | Unchanged | Kit |
|---|---|---|---|
| v1.69.0 | `WidgetsLineChart.lua` new at `CHART_MINOR` 1 (`LibKa0s-Widgets-1.0` key 12.1.4.1); `LibKa0s.xml` lists it | every other file at its v1.68.1 minor: `Core` 10, `Env` 1, `Compat` 1, `Lifecycle` 3, `Bus` 2, `Schema` 2, `Pool` 3, `Item` 2, `Media` 4, `Slash` key 19.1, `DebugLog` key 19.2.1, `Launcher` 5, `Options` key 28.2.34.2.3.8.1.7.4.2, `Perf` key 14.1.1.6; `Widgets` 12, `WidgetsReorder` 1, `WidgetsDragHandle` 4 | 36 -> **37** (`testkit/mock_lines.lua` new: `CreateLine` on every tracked frame; `mock_base.lua` loads it) |
| v1.70.0 | `WidgetsAutocomplete.lua` new at `AUTOCOMPLETE_MINOR` 1; `WidgetsLineChart` 1 -> 2 (`opts.pxPerPoint`); Widgets key 12.1.4.2.1 | every other file as at v1.69.0 | 37 (kit bytes unchanged) |

No `NEEDS_*` floor rose, no major was added, no member was removed; the payload grew from 32 to 34
files, fifteen majors throughout.

## Consumption

MultiMeters looks up `LibKa0s-Widgets-1.0` (13 sites outside `libs/` and `tests/`), but nothing in
`core/`, `settings/`, `modules/` or `defaults/` calls `LineChart`, `ChartMath`, `LINE_CHART`,
`Autocomplete` or `AUTOCOMPLETE`. Neither new file is reached by this addon, so no contract under a
consumed surface moved in the span. The kit-37 `CreateLine` mock is additive.
