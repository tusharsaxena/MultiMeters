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
- **The Reset-all tooltip did not move on the copy.** The composers were attached without a
  descriptor, so it kept *"Restore every setting in this addon to its default."* (02_CANDIDATES B1).
- Kit 19 changes nothing observable here (see 01_DELTA §3f).

## What was adopted, and what was declined

A multi-word slash pin landed in its own commit, with B1 withheld: the `lib:New` field cannot reach
this addon's button. B1 was then adopted through a compose descriptor, and the tooltip now reads
*"Reset the current profile to its defaults — the same thing Profiles → Reset Profile does. Your
other profiles are not affected."* (02_CANDIDATES B1). No issue was filed.

## Gates

| When | `lua tests/run.lua` | `luacheck .` | lizard `-C 15` |
|---|---|---|---|
| Baseline, `e66fa0c` | 1823 passed, 0 failed, 0 skipped | 0 / 0 in 123 files | clean |
| Re-vendor (`7366a64`) | 1823 passed, 0 failed, 0 skipped | 0 / 0 in 123 files | clean |
| Slash pin (`00837e9`) | 1824 passed, 0 failed, 0 skipped | 0 / 0 in 123 files | clean |
| Adoption, B1 (this bundle's last commit) | 1825 passed, 0 failed, 0 skipped | 0 / 0 in 123 files | clean |

The pin commit adds one case. `tests/test_slash.lua` sets `window.name` to `Raid Damage Meter`
through `/mm set`; it was red with v1.33.0's `Slash.lua` swapped in (stored `"Raid"`) and green on
minor 10. The adoption commit adds the tooltip case in `tests/test_options_panel.lua`, which fires
the General page's real button and reads the `GameTooltip:AddLine` body. It was red before the
compose descriptor (it read *"Restore every setting in this addon to its default."*) and is green
with it.

`tests/test_vendor_sync.lua` compared both payloads against the tag and skipped none. Every changed
file is CRLF, with CR equal to LF. Nothing was pushed.
