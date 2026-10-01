# 02 — Candidates (MultiMeters)

Listed, **not interviewed** this cycle (spec S4 step 1). GI-LK-13's consumer census picks them up.

| Class | Candidate | Evidence | Would touch | Note |
|---|---|---|---|---|
| A | `P.BuildRecord` emits a declared parent that never fired | LibKa0s `CHANGELOG.md` v1.66.0, "Perf minor 14: a declared parent" | — | Delivered by the copy |
| A | Slash 19's resolver reaches every parse refusal | v1.66.0 "Slash minor 19" | — | Delivered; this host's `L` has no `ERR_*` key, so no wording moves |
| A | `RenderGrid` releases a failed wide item with no gap | v1.66.0 "OptionsWidgets minor 34" | — | Delivered; no wide item here |
| B | Per-bucket Perf `budget = { msPerSec, maxMs }`, report-only | `docs/api/Perf/version-14.1.1.6-docs.md`; v1.66.0 "report-only per-bucket budgets" | `core/PerfSetup.lua` | Additive. Ceilings would come from the committed captures under `docs/perf-analysis/` |
| B | `RenderGrid(ctx, items, parent, opts)` with `opts.gap` | `docs/api/Options/version-27.2.34.2.2.8.1.7.4.2-docs.md` | `settings/Windows.lua`, `settings/ColumnBlocks.lua` | Additive; no visible gap problem recorded here |
| B | `RenderTabbedSchema` `untabbedSkipRender` / `disabledReplaces` / `rerender` | same document, OptionsTabs 8 | `settings/General.lua`, `settings/OptionsSetup.lua` | Additive; no recorded need |

No class C: every major in the payload is already consumed.
