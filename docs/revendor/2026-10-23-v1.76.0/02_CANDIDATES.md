# 02 — Candidates (MultiMeters)

Sources: `git -C ../LibKa0s log --oneline v1.75.2..v1.76.0`, the v1.76.0 `CHANGELOG.md` block and the
documents it links, `docs/api/Widgets/version-14.1.4.3.2-docs.md` and
`docs/api/Sim/version-2.3.5-docs.md`. 01_DELTA.md found no blockers.

## Class A: reached the addon on the copy

- **Widgets 14, unchanged default.** `TestStrip` without `opts.kind` still draws the amber test-mode
  strip, so the strip under each window's title is the same with no host change.
- **SimTimeline 3 / SimPanel 5** (auto-run, Run all removed). These ship in the payload, but nothing
  reaches them until MultiMeters becomes a Sim host.

## Class B: host change required

- **`W.TestStrip(parent, { kind = "sim" })` and `strip.kind`** (Widgets minor 14, Since 14,
  `docs/api/Widgets/version-14.1.4.3.2-docs.md` *What changed at 14.1.4.3.2*). This is a cyan
  simulation strip on every MultiMeters window while a simulation runs. It touches
  `modules/Window.lua` and `modules/Window_Header.lua`, and it is additive (a second strip at the
  same anchor). **Recommendation: adopt, in item MM-17 of this run**, not here.
- **Header word while the strip shows** (standard v2.87.0 preview-mode *One marker per mode on
  screen*, SHOULD NOT). This is the standard's rule, not a library surface. It is listed because the
  strip carries it. **Item MM-01 of this run** owns it.

## Class C: whole-module adoption

- **`LibKa0s-Sim-1.0`** (key 2.3.5). It is now in scope for this addon: MultiMeters#60, OWNER_SCOPE
  B4. **Adopt, in items MM-10 to MM-20 of this run** (`core/SimSetup.lua`, `modules/SimWorld.lua`,
  `modules/SimDrivers.lua`, `modules/Sim.lua`, `modules/SimScenario.lua`). The v1.75.0 bundle's
  decline for that run is superseded by the owner's scope for this one.
- **`LibKa0s-Item-1.0`, `LibKa0s-Glow-1.0`**: no use in this addon, unchanged from
  `2026-10-22-v1.75.0/02_CANDIDATES.md`, and neither moved in this range.
