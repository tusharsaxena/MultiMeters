# 05 — Summary

**LibKa0s v1.58.0 -> v1.60.0** (tag `v1.60.0`, commit `bed0eb1`; crosses v1.59.0). Item DR-MM-01
of the 2026-09-25 diagnostics rollout.

| File | v1.58.0 | v1.60.0 |
|---|---|---|
| `DebugLog.lua` | 13 | 14 |
| `DebugLogDiagnostics.lua` | — | 1 (new) |
| `Slash.lua` | 15 | 16 |
| `WidgetsDragHandle.lua` | 2 | 3 |
| kit (`Kit.VERSION`) | 26 | 27 |

After the copy both payloads diff clean against the tag, content and bytes; nothing was deleted.

## Reached the addon for free

- Debug console buffer 3000 lines, slack 128.
- `lib.TIME_COPY`, the copy-timing switch.
- `diagnostics` in the library's live-while-disabled set (the addon takes the default).
- Kit suite `test_diagnostics_contract.lua`, declared in `tests/run.lua`; one declared skip until
  `Kit.diagnostics` is wired (DR-MM-03).

## Contract blocker, resolved in the re-vendor commit

The DebugLog instance surface gained `RunDiagnostics`, `BuildDiagnostics` and `DebugVerb`
(`DebugLog/version-14.1-docs.md:525-526`, `:615-619`). The library-absent stub in
`core/DebugLogSetup.lua` now carries all three: `RunDiagnostics` prints
`/mm diagnostics is unavailable: the LibKa0s library did not load.` (a new `locales/enUS.lua` key),
writes nothing and returns 0; `BuildDiagnostics` returns the empty report; `DebugVerb` returns
`false`. A new case in `tests/test_debuglogsetup.lua` pins that, and the existing "the stub carries
the WHOLE live surface" parity case covers the members.

## Other edits in the same commit

- `CLAUDE.md` provenance line v1.58.0 -> v1.60.0.
- `settings/Slash.lua` comments: the live set is thirteen verbs, and `diagnostics` answers
  `unknown command` until this addon registers it.
- `tests/test_disabled.lua`: the `RESERVED` comment says why `diagnostics` is not in the list yet.
  An unregistered reserved verb answers `unknown command` plus the index, which carries the
  disabled notice, so listing it now would fail "Disabled 7". It joins the list with the verb.
- `docs/test-cases.md` regenerated (2047 cases), README test badge 2046/2047.

## Adopted, declined, unreached

Nothing adopted in this commit. The helper and the verb are adopted later in the rollout
(DR-MM-02, DR-MM-03). Nothing was declined and no issue was filed (per the plan). Nothing was unreached.

## Gates at the re-vendor commit (all through `ka0s-bounded`)

- `lua tests/run.lua`: 2046 passed, 0 failed, 1 skipped (the declared diagnostics-contract skip),
  2047 total.
- `luacheck .`: 0 warnings / 0 errors in 138 files. `.luacheckrc` excludes `libs/` and `tests/_kit/`;
  the stub and the host edits are inside the checked set.
- `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .`: no function above CCN 15.
