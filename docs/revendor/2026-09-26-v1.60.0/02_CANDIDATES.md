# 02 — Candidates

Sources, in order:

```
git -C ../LibKa0s log --oneline v1.58.0..v1.60.0
git -C ../LibKa0s show v1.60.0:CHANGELOG.md          # the v1.59.0 and v1.60.0 blocks
git -C ../LibKa0s show v1.60.0:docs/api/DebugLog/version-14.1-docs.md
git -C ../LibKa0s show v1.60.0:docs/api/Slash/version-16-docs.md
git -C ../LibKa0s show v1.60.0:docs/api/Widgets/version-10.3-docs.md
git -C ../LibKa0s show v1.60.0:docs/api/testkit/version-27-docs.md
```

## A. Delivered on the copy (not offered)

| What | Evidence | Note |
|---|---|---|
| Debug console buffer 1500 -> 3000 lines, slack 64 -> 128, `lib.BUFFER_SLACK` published | `DebugLog/version-14.1-docs.md:50-51` | No host test pins the literal (`01_DELTA.md`, 3g). The buffer prose in this addon's docs is DR-MM-05's. Not an adoption (the plan says so). |
| `lib.TIME_COPY` copy-timing flag | `DebugLog/version-14.1-docs.md:183-191` | Owner-only switch, off by default. |
| `diagnostics` in `lib.LIVE_VERBS` | `Slash/version-16-docs.md`, the `lib.LIVE_VERBS` row | MultiMeters takes the library default, so it has it now. |
| Kit revision 27 and `test_diagnostics_contract.lua` | `testkit/version-27-docs.md` | Declared in `tests/run.lua`; one declared skip until `Kit.diagnostics` is wired. |

## Blocker resolved in the re-vendor commit (not a candidate)

The DebugLog stub's `RunDiagnostics`, `BuildDiagnostics`, `DebugVerb` (`01_DELTA.md`, 3g).

## B. Host change required (candidates)

| # | Candidate | Evidence | Touches | Blast radius |
|---|---|---|---|---|
| B1 | The diagnostics helper, `D:RunDiagnostics` with the host's `diagnostics()` sections, and `brandName` on the DebugLog descriptor | `DebugLog/version-14.1-docs.md:48-87`, `:525-526` | `core/DebugLogSetup.lua`, `core/Diagnostics*.lua`, `settings/Slash.lua`, tests | Replaces code the addon owns: the `/mm debug diag` report is re-hosted onto the helper and `diag` retired |
| B2 | Registering `diagnostics` as a verb, live while disabled (Slash 16) | `Slash/version-16-docs.md` | `settings/Slash.lua`, `tests/test_disabled.lua` | Additive |

## C. Whole-module adoption

| # | Candidate | Note |
|---|---|---|
| C1 | WidgetsDragHandle close mark (`DRAG_MINOR` 3) | This addon builds no `DragHandle`, so it is not a candidate here. |
