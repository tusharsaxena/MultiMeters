Delta: LibKa0s v1.70.0 -> v1.71.0

# 01 — Delta (MultiMeters)

Item RV-MM of the 2026-10-07 review and standards audit remediation, branch
`feat/2026-10-07-review-audit-remediation`. Copied from the **local** annotated tag `v1.71.0` (tag
object `3bf1b97`, commit `cb274a4`, not pushed) with `git -C ../LibKa0s archive v1.71.0 LibKa0s testkit
| tar -x -C <scratch>`, never a branch tip, then `rsync -a --delete` of `LibKa0s/` onto
`libs/LibKa0s/` and of `testkit/` onto `tests/_kit/`.

## Base

The CLAUDE.md provenance line before this commit named **v1.70.0**, and the last payload commit,
`1ee53cf`, rolled it there. `diff -rq` of the v1.70.0 archive against both payloads printed nothing,
so the tree and the line agree. Base v1.70.0 (from the provenance line, not the library's previous
tag; here the two coincide). The two tags between v1.68.1 and this base are recorded by the span
bundle `docs/revendor/2026-10-07-v1.69.0-v1.70.0/`.

## Files

`diff -rq` of the v1.70.0 and v1.71.0 archives: `LibKa0s/Env.lua`, `OptionsIdList.lua`, `Slash.lua`,
`SlashParse.lua`, `WidgetsAutocomplete.lua`, `WidgetsLineChart.lua`; `testkit/README.md`,
`framework.lua`, `inventory.lua`; `testkit/secrets.lua` only in v1.71.0. Nothing was dropped, so the
`--delete` removed nothing. No payload file is added under `LibKa0s/` (fifteen majors, thirty-four
files).

## Per-file minors

| File | v1.70.0 | v1.71.0 | Major key |
|---|---|---|---|
| `WidgetsLineChart.lua` | 2 | **3** | `LibKa0s-Widgets-1.0` 12.1.4.3.2 |
| `WidgetsAutocomplete.lua` | 1 | **2** | (same) |
| `Slash.lua` | 19 | **20** | `LibKa0s-Slash-1.0` 20.2 |
| `SlashParse.lua` | 1 | **2** | (same) |
| `Env.lua` | 1 | **2** | `LibKa0s-Env-1.0` 2 |
| `OptionsIdList.lua` | 3 | **4** | `LibKa0s-Options-1.0` 28.2.34.2.4.8.1.7.4.2 |

Every other file stays at its v1.70.0 minor (`Core` 10, `Compat` 1, `Lifecycle` 3, `Bus` 2, `Schema`
2, `Pool` 3, `Item` 2, `Media` 4, `DebugLog` key 19.2.1, `Launcher` 5, `Perf` key 14.1.1.6, `Widgets`
12, `WidgetsReorder` 1, `WidgetsDragHandle` 4). No `NEEDS_*` floor rises, no cross-major skew.

## Kit revision

`Kit.VERSION` 37 -> **38**. Two changes: the `--list` renderer moves to `inventory.lua` and its
`## Totals` table counts only the cases that run, with a `| Skipped | N |` row before Total when a
declared skip is registered (LibKa0s LK-01, from AM-R-03); and the new `secrets.lua` adds the opt-in
`Kit.secret`, `Kit.isSecret`, `Kit.reveal`, `Kit.SECRET_ERROR` and `Kit.installSecretValue()` (from
WG-R-09). Nothing installs `issecretvalue` by default and `Kit.expose` copies none of them.

## Consumption

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0"' --include='*.lua'` outside `libs/` and `tests/`: Bus 4,
Compat 7, Core 28, DebugLog 4, Env 2, Item 2, Launcher 2, Lifecycle 2, Media 8, Options 15, Perf 6,
Pool 4, Schema 3, Slash 8, Widgets 13. Of the majors that moved a minor, MultiMeters consumes **Env**
(`core/EnvSetup.lua`'s `NS.Meta`), **Slash** (`settings/Slash.lua`, `/mm set` on the schema's 28
number rows), **Options** (the panel) and **Widgets** (the shell). It calls no `LineChart`,
`ChartMath`, `Autocomplete` or `O.IdList` row: `IdList` appears only in `settings/OptionsSetup.lua`'s
degraded stub-name list.

## Contract changes under unchanged signatures

- **Env 2 (LK-06):** `Env.GetAddOnMetadata` no longer falls back to the bare `GetAddOnMetadata`
  global; with no `C_AddOns` it answers `nil`, so `Version` answers its fallback. Signature
  unchanged. This turned one MultiMeters case red:
  `tests/test_envsetup.lua` "the deprecated bare global is still a live rung, all the way to
  NS.version" pinned the library's minor-1 rung reaching `NS.version`. It is replaced, in the same
  commit, by "with the library loaded, the bare global is no rung; NS.version takes its constant",
  which plants a counting bare-global reader with `C_AddOns` absent and asserts it is never called,
  `NS.Meta("Version")` is nil and `NS.version` is `FALLBACK_VERSION` (red against the v1.70.0
  payload: `assertNil (got 9.9.9)`; green against v1.71.0). MultiMeters' own library-absent rung in
  `NS.Meta` (`core/EnvSetup.lua`) is untouched here; dropping it is MM-07.
- **SlashParse 2 (LK-05):** `ParseValue` refuses `nan`, `inf`, `-inf` and overflowing literals on a
  number row with `ERR_NUMBER`. `/mm set <path> nan` on any of the 28 number rows is now refused
  instead of storing NaN. No MultiMeters case pinned the old acceptance.
- **OptionsIdList 4:** the help-art guard drops the bare `IsAddOnLoaded` rung. No IdList row here.
- **WidgetsLineChart 3 / WidgetsAutocomplete 2:** clipping, hover re-sync, hook re-install,
  `maxRows` floor. Unused surfaces.
- **Kit 38 Totals:** `docs/test-cases.md` regenerated. Its Total moves 2188 -> **2187** with a
  `| Skipped | 1 |` row (the diagnostics contract's opt-out case), so the inventory now equals the
  README badge (2187/2187), which did not move.
