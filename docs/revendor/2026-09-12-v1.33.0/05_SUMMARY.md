# 05 — Summary: LibKa0s v1.32.0 → v1.33.0

## The move

| | |
|---|---|
| From | v1.32.0 (`e18dd12`) |
| To | **v1.33.0** (tag `7d5e061`, commit `06ee368`) |
| Files that moved in `libs/LibKa0s/` | `Options.lua` (`MINOR` 16 → 17), `Slash.lua` (`MINOR` 8 → 9) |
| Kit revision | 17 → **18** (`README.md`, `framework.lua`, `mock_base.lua`) |
| Files removed upstream | none |
| Cross-major skew found | none |

## What reached this addon for free

- **Font dropdowns draw every row on their first open.** This covers the Header, Bars, Tooltip and
  Columns text-font rows. It still needs an in-game check. On a fresh session, open Settings →
  MultiMeters → Bars → the font dropdown, and every row should draw on the first open.
- Slash 9 and kit 18 change nothing observable here (see 02_CANDIDATES).

## What was adopted, and what was declined

Nothing needed a host change. No issue was filed.

## Gates

| When | `lua tests/run.lua` | `luacheck .` | lizard `-C 15` |
|---|---|---|---|
| Baseline, `1bf536f` | 1822 passed, 0 failed, 0 skipped | 0 / 0 in 123 files | clean |
| Re-vendor (this bundle's commit) | 1822 passed, 0 failed, 0 skipped | 0 / 0 in 123 files | clean |

`tests/test_vendor_sync.lua` compared both payloads against the tag and skipped none. Every changed
file is CRLF, with CR equal to LF. Nothing was pushed.
