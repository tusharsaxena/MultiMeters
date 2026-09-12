# 05 — Summary: LibKa0s v1.33.0 → v1.34.0

## The move

| | |
|---|---|
| From | v1.33.0 (tag `7d5e061`, commit `06ee368`) |
| To | **v1.34.0** (tag `9165044`, commit `33bae81`) |
| Files that moved in `libs/LibKa0s/` | `Options.lua` (`MINOR` 17 → 18), `OptionsCompose.lua` (`_MINOR` 4 → 5), `Slash.lua` (`MINOR` 9 → 10) |
| Kit revision | 18 → **19** (`README.md`, `framework.lua`, `mock_base.lua`) |
| Files removed upstream | none |
| Cross-major skew found | none |

## What reached this addon for free

- **Window names and whisper targets keep every word from the slash.** `/mm set window.name Raid
  Damage` stores `"Raid Damage"`, not `"Raid"`.
- **The Reset-all tooltip says "current profile"** on the copy alone, because the descriptor
  supplies `resetProfile`.
- Kit 19 changes nothing observable here (see 01_DELTA §3f).

## What was adopted, and what was declined

B1, `profilesPage = true`, is adopted in its own commit (see 04_EXECUTION_PLAN). Nothing was
declined. No issue was filed.

## Gates

| When | `lua tests/run.lua` | `luacheck .` | lizard `-C 15` |
|---|---|---|---|
| Baseline, `e66fa0c` | 1823 passed, 0 failed, 0 skipped | 0 / 0 in 123 files | clean |
| Re-vendor (this bundle's commit) | 1823 passed, 0 failed, 0 skipped | 0 / 0 in 123 files | clean |

`tests/test_vendor_sync.lua` compared both payloads against the tag and skipped none. Every changed
file is CRLF, with CR equal to LF. Nothing was pushed.
