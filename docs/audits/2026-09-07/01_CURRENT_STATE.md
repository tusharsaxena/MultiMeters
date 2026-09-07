# 01 — Current state (Ka0s Multi Meters, 2026-09-07)

**Audited against:** Ka0s WoW Addon Standard **v2.38.0 (2026-09-02)** — `standards/STANDARDS.md`
plus every one of the 26 section files its Sections list links (`layout`, `architecture`,
`toc-file`, `library-stack`, `compat`, `localization`, `savedvariables`, `options-ui`,
`slash-commands`, `debug-logging`, `standalone-windows`, `preview-mode`, `events-frames-taint`,
`performance`, `testing`, `automated-tests`, `lint`, `line-endings`, `packaging`, `documentation`,
`versioning-git`, `public-api`, `naming-cheatsheet`, `anti-patterns`, `audit-review-history`,
`open-evolutions`). Playbook: `AUDIT.md` at the same ref. `tiered-layout.md` is listed only as a
historical rename note and 404s at `standards/standards/`; it is not a live section.

**Repo:** `/mnt/d/Profile/Users/Tushar/Documents/GIT/MultiMeters`, branch `main`, clean at
`0e74319` (*Merge branch 'feat/settings-revamp-v2'*).

**Rule set:** the addon rule set. `MultiMeters.toc` exists, so this is an addon repo, not a
Ka0s-owned library repo.

**Prefix:** `MM-` (first audit for this repo; reuse thereafter).

---

## Layout (`layout`)

The modular layout is in place and correct: `core/`, `defaults/`, `locales/`, `modules/`,
`settings/`, `libs/`, `tests/`, `media/`. Folder load order in `MultiMeters.toc` is
`libs/ → locales/ → core/ → defaults/ → modules/ → settings/`.

`media/` holds `logos/` and `textures/` only — `media/textures/Default.tga` is the addon's own
statusbar art (`core/LSMPatch.lua:28`) and is **not** a copy of anything under
`libs/LibKa0s/media/textures/` (which ships `gradient`, `overline-*`, `underline-*`). The 49 icons
and JetBrains Mono this addon once shipped privately were moved into the library payload
(`core/MediaSetup.lua:1-50`).

**File sizes (measured today, `wc -l`):** seven files are past `layout-§1`'s 1500 LOC cap —
`settings/Schema.lua` 3069, `modules/Tooltip.lua` 2652, `modules/Window.lua` 2644,
`modules/Aggregator.lua` 2058, `modules/Export.lua` 1743, `core/Diagnostics.lua` 1726,
`modules/Row.lua` 1702. Nothing else is in or over the 1000–1500 band except `locales/enUS.lua`
(928) and `modules/Provider.lua` (924), which are under it.

## TOC (`toc-file`)

`MultiMeters.toc` carries `Interface: 120007`, `Title`, `Notes`, `Author`, `Version 0.1.0`,
`IconTexture`, `SavedVariables: MultiMetersDB, MultiMetersPerfDB`, `OptionalDeps`, `DefaultState`,
`Category-enUS`, `X-License: MIT`, `X-Standard`. `X-Curse-Project-ID` / `X-Wago-ID` are **absent
with a comment in their position** saying the addon is unpublished (`MultiMeters.toc:14-15`) —
`toc-file-§1`'s compliant state, not a deviation.

Position annotations (`toc-file-§5`) are present and name what resolves, not merely "order
matters": `core/EnvSetup.lua` (the version resolved at file scope in `core/Namespace.lua`),
`core/PoolSetup.lua`, `core/MediaSetup.lua` (`Constants.FONT_MONO`), `core/Diagnostics.lua` (why it
is *not* load-bearing), and `settings/General.lua` (page registration order). `libs\LibKa0s\LibKa0s.xml`
is listed once, in `# Libraries`, after Ace3 — no individual LibKa0s `.lua` file appears.

## Libraries and the shared subsystems (`library-stack`)

Ace3 + LibStub + CallbackHandler + LibSharedMedia + LibDataBroker + LibDBIcon, all vendored.
`libs/LibKa0s/` is the whole ship folder; `tests/_kit/` is the vendored harness, under `tests/`,
not `libs/`. Provenance is in root `CLAUDE.md:52` — `Bundles [LibKa0s](…) v1.25.0 (MIT).` — and
**not** in `README.md` (0 hits), which is the shape `documentation-§2` item 6 and the consumer-side
gate want.

The addon owns descriptors and stubs, not implementations: `core/CoreSetup.lua`,
`core/DebugLogSetup.lua`, `core/PerfSetup.lua`, `core/EnvSetup.lua`, `core/PoolSetup.lua`,
`core/MediaSetup.lua`, `settings/OptionsSetup.lua`, and the slash descriptor in
`settings/Slash.lua:174`. There is no hand-rolled console, widget maker, dispatcher or test
framework anywhere outside `libs/`. `tests/test_degraded.lua` exercises every stub branch (23 cases
in the degraded block alone), including the deliberately load-completing Options stub.

Close-button wrapper: exactly one definition at `core/CoreSetup.lua:239`
(`lib.MakeCloseButton(parent, onClick, addonName)`), one call site at `modules/Export.lua:1067`
through `NS.MakeCloseButton`, and `core/PerfSetup.lua:206` documents the deliberate **absence** of a
`decorate` hook now that the library draws the perf panel's own close control.

## Settings (`options-ui`)

Nine registered pages plus the host's landing page: `general`, `windows`, `frame`, `header`,
`bars`, `tooltip`, `visibility`, `columns`, `profiles`. Every non-exempt page declares `group`
values and draws a strip; `Profiles` is the AceConfig-drawn exemption. The General page's first tab
is exactly `Master controls` (`settings/Schema.lua:849`), composed by the library's
`MasterControls` composer with the full canonical set including the closing reset pair
(`NS.MasterControlsAfterGroup`, `settings/Schema.lua:936`). Fourteen composer call sites in all
(`compose("ColorPair"|"BorderGroup"|"FontGroup"|"BarGroup"|"MasterControls", …)`).

Five color rows; four carry their class-color companion as the next declaration
(`window.header.dividerColor`, `window.frame.controlColor`, `window.frame.controlHoverColor`, plus
every composed pair), one — `window.header.bgColor` — is a **ratified register row**, and
`statColors.*` is a per-statistic palette, which `options-ui-§17` exempts. No `disabledIf` on a
color row. No `ScrollUp-Up`/`ScrollDown-Up` art anywhere; ordering is the shared `ReorderList`
gesture wired in `settings/ColumnBlocks.lua`. Chrome band is one block per page via
`H.WindowBanner` (`settings/Windows.lua:218`) over the library's `PageBanner`; no `InlineGroup` or
hand-drawn box around it.

## SavedVariables (`savedvariables`)

`core/Database.lua` owns the AceDB instance. `db.global.schemaVersion` is account-wide
(`core/Database.lua:34-35`), with a twelve-step migration runner (`migrations[1]` … `migrations[12]`,
dispatched at `core/Database.lua:697`) currently landing at v13. Defaults live only in
`defaults/Profile.lua`.

## Slash, debug, performance

`NS.COMMANDS` is a positional table of **16** verbs (`settings/Slash.lua:72`), including a
`window` sub-verb tree. Debug console is `LibKa0s-DebugLog-1.0`'s, plus this addon's own
`/mm debug diag|recap|identity` surface in `core/Diagnostics.lua` (1726 lines). Perf harness is
wired: `core/PerfSetup.lua`, `MultiMetersPerfDB` in the TOC, `tests/perf.lua` with 13 scenarios,
`docs/performance.md` and `docs/perf-analysis/README.md` present (store empty of captures).

## `.gitattributes` (`line-endings`)

Present at the repo root, client-bound kind. Recorded verbatim: the pin is `* text=auto eol=crlf`
(`.gitattributes:26`), the mandatory carve-out `*.sh text eol=lf` (`.gitattributes:34`), and 20
lines ending ` binary`. The file itself is CRLF and matches the canonical client-bound body.

## Root doc set (`documentation-§1/§2/§7`)

`README.md` (213 lines) — badges at `:3-7`, the standard badge **bare** at `:6`, no
`## Libraries` / `## Bundled libraries` heading, a `## Credits` at `:209` holding external font/icon
credit only, `## What's new in 0.1.0`, `## Version History`, no `CHANGELOG.md` anywhere.
`CLAUDE.md` (52 lines) — the stub, with `## Standards compliance (read first)`, the addon-specific
rule, and the provenance line last. `DEPENDENCIES.md` (96 lines) present.

## `docs/`

Tier 1 complete under the canonical names: `scope.md`, `module-map.md`, `schema.md`,
`settings-panel.md`, `data-flow.md`, `common-tasks.md`. Canonical trio complete:
`ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`. Verification-and-record five complete:
`test-cases.md`, `performance.md`, `perf-analysis/README.md`, `automated-tests/README.md`,
`automated-tests/RESULTS.md`. **No** non-canonical Tier 1/2 filename (`data-model.md`,
`saved-variables.md`, `pipeline.md`, `settings-system.md`, `wow-quirks.md`, `slash-commands.md`,
`debug-console.md`), **no** retired `file-index.md`, `conventions.md`, `complexity.md`,
`docs/perf-runs/` or `docs/pending/LEDGER.md`.

`docs/ARCHITECTURE.md` is 787 lines with all ten mandated sections present, including
`## Documentation map` (`:636`) and `## Documented deviations` (`:700`). The register holds four
ratified rows and two retirement notes.

## Registers read before filing (`audit-review-history`)

- `docs/ARCHITECTURE.md` `## Documented deviations` — four ratified rows (debug-logging §8 throttled
  summary; options-ui §17 `window.header.bgColor` companion; options-ui §17 second class-colour
  reader `NS.ClassRGB`; options-ui §15/§16 composed blocks absent in a degraded install). All four
  carry a Rule, a Decided date and a Re-check trigger. None cites a rule the standard has since
  changed.
- GitHub issue store — 26 issues read with
  `gh issue list --state all --limit 200 --json number,title,state,labels`. Every issue carries a
  `state:` and a `severity:` label; **no `[status]` title prefix survives** anywhere. Three
  `state:will-not-do` issues (#15, #16, #20); none declines a *standard rule* — #20 records
  `LibKa0s-Item-1.0` as inapplicable to a damage meter, which is not a deviation and owes no
  register row.
- `docs/scope.md` and root `CLAUDE.md` carry no accepted-deviation prose competing with the register.

## Suites as observed today

- `luacheck .` → **0 warnings / 0 errors in 45 files**.
- `lua tests/run.lua` → **1496 passed, 0 failed, 0 skipped, 1496 total**.
- `lua tests/perf.lua` → 13 scenarios, exit **0** (assertions pass).
- `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` → **23 warnings**, max CCN **36**, total
  nloc **31773**, 3276 functions.
- `diff -r <LibKa0s@v1.25.0>/LibKa0s libs/LibKa0s` → **empty**.
  `diff -r <LibKa0s@v1.25.0>/testkit tests/_kit` → **empty**.
