# 05 — Summary: LibKa0s v1.29.0 → v1.30.0

## The move

| | |
|---|---|
| From | v1.29.0 |
| To | **v1.30.0** (tag `e369e0f`) |
| Library files that moved | **none**, every minor is v1.29.0's (`01_DELTA.md` §3c) |
| Kit revision | 15 → **16**: `README.md`, `framework.lua`, `mock_base.lua`, `vendor_sync.lua` |
| Files removed upstream | none |
| Cross-major skew found | none |

## What reached this addon for free

- The runner-mode case, `the automated-test runner is recorded executable (100755)`, through the
  existing `tests/test_vendor_sync.lua` delegate. It passes, and it is the whole of the count's
  move: **1748 → 1749**.
- A faithful `AceGUI:Release` and an AceConsole-shaped `Printf` in the kit. This addon calls
  neither, so nothing changes today.

## What was adopted

- **#29:** `tests/wow_mock.lua`'s local AceEvent event half is deleted. `embedAceEvent` now
  chains to the kit's `AceEvent:Embed` for events and keeps its own message half. Same commit as
  the re-vendor. No test expectation was edited.

## What was declined

Nothing. No issue was filed and none is proposed from this bundle.

## Skipped or unreached

Nothing. `LibKa0s-Item-1.0` remains unconsumed and was not re-offered, because its minor did not
move.

## Gates

| Gate | Before the copy | After the copy, shim kept | After the adoption |
|---|---|---|---|
| `lua tests/run.lua` | 1748 / 0 failed / 0 skipped | 1749 / 0 / 0 | **1749 / 0 / 0** |
| `luacheck .` | 0 / 0 in 122 files | — | **0 / 0 in 122 files** |

`tests/test_vendor_sync.lua` ran rather than skipping (0 skipped). It resolves the tag named in
`CLAUDE.md` and compares both payloads against it, so it is the case this re-vendor exists to
satisfy. `luacheck` excludes the vendored payload, so 0/0 says the host is clean. It does include
`tests/wow_mock.lua`, the one file the adoption touched.

The count moved, so `docs/test-cases.md` was regenerated with `lua tests/run.lua --list` and the
README `Tests` badge moved to 1749 in the same commit (`docs/testing.md`, *The inventory*).

## Not pushed

Committed only. Pushing is `/wow-addon:finalize`'s.
