# 01 — Current state (Ka0s Multi Meters, 2026-10-07)

**Audited against the Ka0s WoW Addon Standard v2.76.1 (2026-10-07).** The rules were fetched with
`curl -fsSL` from `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`:
`AUDIT.md`, `standards/STANDARDS.md`, `standards/ADDONS.md` and **all 27 section files** the index's
Sections list links. Line 1 of the fetched index reads
`# Ka0s WoW Addon Standard (v2.76.1, 2026-10-07)`. Each fetched file was compared with `cmp` against the
sibling checkout `../WowAddonStandards` at `f472389` (which equals `origin/master`), and all 30 were
byte-identical, so no file was read part-way through a transfer.

**Repo kind: addon.** `dev-copilot-profile` reports `profile=wow`, `kind=addon` (reason
`toc:## Interface`). The repo has `MultiMeters.toc` and is the *Ka0s Multi Meters* row of
`ADDONS.md`'s in-scope table, so the detector and the table agree. The full addon rule set was
applied, section by section. Neither `library-stack-§7`'s library list nor `documentation-§8`'s
documentation-and-tooling list was used.

**Deviation-ID prefix: `MM-A-`**, reused from the 2026-09-07, 2026-09-08 and 2026-09-23 bundles.

**Run conditions.** Read-only. The only files written are the five in this folder. The tree was
clean at `a01d1d1` on `feat/2026-10-07-review-audit-remediation` when the audit started. During the
run another agent created an untracked `docs/reviews/2026-10-07/` beside it. That folder is not part
of this audit and was not read as evidence. Every `luacheck`, `lua tests/run.lua` and complexity run
went through `~/.claude/dev-copilot/bin/ka0s-bounded`. None of them exited 124 or 137.

**What changed since the last audit.** 145 commits since `4aefb58` (the 2026-09-23 baseline). They
include release 1.1.0 (`4c368c4`, tag `1.1.0-release`), the nav-rail Windows page (#55), the
diagnostics report, the debug-coverage pass, the automated-tests sweep, the census adoption (#58),
and re-vendors from LibKa0s v1.56.0 through **v1.70.0**.

---

## Layout (`layout`)

`core/` (20 files), `defaults/` (1), `locales/` (1), `modules/` (26) and `settings/` (15) make 63
authored source files. PascalCase files sit in lowercase folders. No authored generator exists:
`git ls-files '*.py' '*.sh'` returns only the vendored `tests/_kit/run-automated-tests.sh`.

**The 1500-line cap.** The default census scope is
`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, which returns 146 files (63 source plus 83
under `tests/`). No file is over 1500 lines. **22** files are in the 1000–1500 on-notice band. The
largest is `settings/Schema_Compose.lua` at 1410 lines. The hub's census heading
`### Files over the 1500-line cap` (`docs/ARCHITECTURE.md:479`) reads "Nothing is over the cap today"
(`:481`). The kit gate is wired by path (`tests/run.lua:242`) and passes.

**Media.** `media/logos/` holds the two runtime `.tga` files plus the `.png` and `.jpg` masters.
`media/screenshots/` holds the project-page captures. Nothing in the addon's own `media/` tree
duplicates `libs/LibKa0s/media/` (`fonts/`, `icons/`, `textures/`).

## TOC (`toc-file`)

The metadata block is in `toc-file-§1` order: `## Interface: 120100`, `## Version: 1.1.0`,
`X-License: MIT`, `X-Standard:`, and `X-Curse-Project-ID: 1690082`. `## IconTexture:` names
`…\media\logos\multimeters.logo.128.tga`. The file header bytes read type 2 (uncompressed),
128 × 128, 32 bpp, so `layout-§4` is met. `libs\LibKa0s\LibKa0s.xml` is listed once, after Ace3
(`MultiMeters.toc:26`). **Every load-bearing `# Core` line now carries its at-line note**, and each
group has a "conventional order" header (`:36-39`, `:93-95`). That closes MM-A-22.

## Libraries (`library-stack`)

The libraries are Ace3, CallbackHandler, LibStub, LibSharedMedia, AceGUI-SharedMediaWidgets,
LibDataBroker, LibDBIcon and LibKa0s. The provenance line `CLAUDE.md:55` reads
`Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).`, and it is the only copy in
the repo. Both payloads were diffed against tag `v1.70.0`, extracted with `git archive`, and both
diffs are **empty**: `LibKa0s/` against `libs/LibKa0s/` (37 entries each, 34 `<Script file=` lines),
and `testkit/` against `tests/_kit/`. So the vendoring is whole and has not drifted (no #45, no #48).
The kit is revision **37** (`tests/_kit/framework.lua:20`).

**Seams.** All of them consume the library, and none is hand-rolled: `core/EnvSetup.lua`,
`core/PoolSetup.lua`, `core/MediaSetup.lua`, `core/CoreSetup.lua`, `core/LifecycleSetup.lua`,
`core/PerfSetup.lua`, `core/DebugLogSetup.lua`, `core/LauncherSetup.lua`,
`settings/OptionsSetup.lua`, the slash descriptor in `settings/Slash.lua`, and the Schema runtime in
`settings/Schema_Paths.lua` (LibKa0s-Schema-1.0 minor 2, adopted under issue #52). The stub-parity
and degraded suites pass. There is one `MakeCloseButton` wrapper (`core/CoreSetup.lua:295`) and one
call to it (`modules/Export_Modal.lua:226`). `core/PerfSetup.lua` deliberately passes no `decorate`
hook (`:188`).

**Compat (`compat`).** `core/Compat.lua` is present and owns 30 shims, so the applicability
condition holds and the file is owed. One **library-absent** fallback ladder outside it still keeps
a dead bare-global rung: `core/EnvSetup.lua:93-94` `_G.GetAddOnMetadata`. That is MM-A-27.

## Patterns (`architecture`, `events-frames-taint`)

`NS` is the AceAddon object. Every authored source file opens with `local addonName, NS = ...` or
`local _, NS = ...` (checked over all 63). The bus carries 14 messages, all declared in
`core/Constants.lua`'s `MSG` catalog. Wire strings are `Ka0s_MultiMeters_<PascalCase>`. No call site
types a literal. The one SCREAMING_SNAKE hit (`core/Constants.lua:525`) is inside a comment.

**Event registration is now isolated per event.** `NS:OnEnable` walks the module-level `EVENTS`
array (`core/MultiMeters.lua:125`) through `NS.SafeRegisterEvent` (`:215-217`). That is
`LibKa0s-Core-1.0`'s helper, with a one-rung `pcall` stub (`core/CoreSetup.lua:106`, `:249`).
Rejected names land in `NS.State.rejectedEvents` (`:214`). `/mm diagnostics` prints them
(`core/Diagnostics.lua:224`), and the at-enable queue writes them as an `[Init]` line (`:223`). That
closes MM-A-20.

**Write paths (`architecture-§5`).** The registry writer is named (`modules/WindowManager.lua`, with
`Database.NextWindowId` and `Database.EnsureWindowShape`), and so is the load pass
(`Database.SeedWindows` via `NS:RunMigrations`). Named non-setting state is tabulated at
`docs/ARCHITECTURE.md:120-125`. Window resize goes through the seam:
`WindowProto:SaveSize` → `NS.SetByPaths` (`modules/Window_Placement.lua:75-83`).

## SavedVariables (`savedvariables`)

The defaults declare `global.schemaVersion = 0` (`defaults/Profile.lua:826`). The runner owns the
stamp and advances it only after a step returns (`core/Database.lua:996-998`). Profile-scoped steps
walk every stored profile (for example `migrations[15]`, `:961-969`). `NS.SCHEMA_VERSION` is the
target (`:62`). This is the v2.65.0 shape.

## Settings (`options-ui`)

There are three registered pages: General, Windows (a nav rail with seven entries, #55) and Profiles.
The descriptor passes `addonName = addonName` (`settings/OptionsSetup.lua:153`, `options-ui-§1` as of
v2.75.0). The General page's first tab is `Master controls`, composed by the library. The minimap row
is declared at `global.minimap.shown` (`settings/Schema_Compose.lua:659`) over the stored
`minimap.hide`, and is carved out of both resets. On a degraded load, `enable`/`disable` take route
(a), `writeThrough = { ENABLED_PATH }` (`settings/Schema_Paths.lua:614`). The only `OpenToCategory`
hit is the combat-gated page jump against `cat:GetID()` (`settings/OptionsSetup.lua:673-677`). No
host combat lock or close was found, and no chat-scroll reorder art. The addon's own suite carries no
wrapped-strip geometry case. Since v2.65.0 the library pins the strips it draws, and a consumer
**MUST NOT** duplicate that case, so MM-A-08 is closed by the standard.

## Launcher (`launcher`)

One `LibKa0s-Launcher-1.0` object is built (`core/LauncherSetup.lua:237`), and its label is
`L["Ka0s Multi Meters"]` (`:266`). The descriptor passes `openSettings` and all four
accessor-and-toggle pairs. Each toggle runs its slash verb's own `NS.COMMANDS` handler (`:282-288`),
which matches `ADDONS.md`'s *Enabled · Locked · Test mode · Show window*. It also passes `debug` and
`debugAtEnable` (`:296-303`). There is no host `OnTooltipShow`, `MenuUtil` or `onClick`. The 1.1.0
release notes do not mention the minimap row's CLI path rename (MM-A-28).

## Slash and the disabled state (`slash-commands`)

`NS.COMMANDS` holds 20 verbs: the thirteen reserved verbs (`diagnostics` included,
`settings/Slash.lua:106`), then `profile`, `lock`, `test`, `toggle`, `window`, `reset-positions` and
`export`. `liveVerbs` is built from `SlashLib.LIVE_VERBS` (`:325`). **The disabled state is total.**
`core/LifecycleSetup.lua` is one Lifecycle latch with the `disabled` and `perf` holds. The stand-down
unregisters every game event and cancels every timer (`:62-63`), unregisters module messages, takes
the bus down, suspends the windows (whose `OnUpdate` scripts are cleared,
`modules/Window_Lifecycle.lua:185`) and the provider, and cancels the export queue.
`tests/test_disabled.lua` asserts on the mock's registration set and passes. Its step 8 drives only
the **left** click. The right-click menu half lives in `tests/test_launchersetup.lua:373`, which does
not assert the no-write and no-frame-show part (MM-A-30). The vendored tag v1.70.0 is above the
v1.42.0 adoption floor.

**Diagnostics (`debug-logging-§14`).** Both forms are wired, and the `debug` handler tests
`diagnostics` first (`settings/Slash.lua:802`). There is no alias. The report runs while disabled, and
the conformance suite dispatches both forms. There is no host `SetEnabled` around `RunDiagnostics`
and no opt-out. The stub prints the library-absent line (`core/DebugLogSetup.lua:335`).
`docs/debug.md` documents the report, the enable-on-run, the sections and the caps.
`README.md:80-86` carries `## Reporting a bug` verbatim.

**The library's own debug lines (`debug-logging-§4`, v1.65.0+).** `debug` is passed to the Slash
(`settings/Slash.lua:344`), Options (`settings/OptionsSetup.lua:156`), Launcher and Lifecycle
(`core/LifecycleSetup.lua:240`) descriptors. The host writes no duplicate edge or refusal line. The
addon keeps its own steady-state sink `NS.DebugSteady` and gives the reason in the code
(`core/DebugLogSetup.lua:220-225`). It re-arms that sink from `onClear` (`:410`), which is the shape
the §9 SHOULD allows.

## Debug, perf, tests, lint, complexity

- `luacheck .` reports **0 warnings / 0 errors in 146 files**. `exclude_files` is `libs/`,
  `tests/_kit/`, `docs/audits/`, `docs/reviews/` and `_dev/` (`.luacheckrc:10`). The harness global
  sits in `files["tests/"]` (`:116`). There is no top-level `ignore`.
- `lua tests/run.lua` reports **2187 passed, 0 failed, 1 skipped, 2188 total**. The skip is the kit's
  declared opt-out case, which is disclosed in `docs/test-cases.md:2424`. The README badge reads
  `2187/2187`, which is right because a skip counts toward neither figure (`testing-§5`).
- Sighted complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`):
  **pass, 0 warnings, max CCN 15**, 45299 NLOC across 4895 functions. The newest bundle,
  `20260927-030445` (the 1.1.0 release run, sha `abbb29e`), is **53 commits behind HEAD**. It predates
  kit revision 35, so it is unsighted and its manifest has no `blindFiles` (MM-A-26, Info). The watch
  list carries no `Accepted` disposition, so anti-pattern #53 has nothing to fire on.
  `test_lizard_sighted` is wired (`tests/run.lua:359`).
- Two documents still quote the raw `lizard -l lua …` command as the complexity check, and
  `DEPENDENCIES.md` pins `lizard` 1.24.0 (MM-A-29).
- `docs/perf-analysis/` holds three bundles, each with `report.md`, `dump.json` and `ANALYSIS.md`.

## Packaging (`packaging`)

Checks (a), (b) and (c), run under `bash`, print only `UNACCOUNTED — .git`, and `.git` is exempt.
`.claude` and `.superpowers` exist and are ignored. `media/logos/*.png` and `*.jpg` are ignored. The
packaging checks pass.

## `.gitattributes` (`line-endings`)

The file is present and 84 lines long. Its body is **byte-identical** to `line-endings-§5`'s
client-bound canonical body, with no appendix. The pin, verbatim, at `.gitattributes:26`:

```
* text=auto eol=crlf
```

`*.sh text eol=lf` is at `:36` and `*.py text eol=lf` at `:37`. There are 20 ` binary` lines. The
working-tree agreement check (e) returns **0**. `tests/_kit/test_eol.lua` is wired (`tests/run.lua:351`)
and green.

## Root docs

- `README.md` has the H1, the five badges (the Standard badge is **bare**, `:6`), the description,
  Screenshots, Usage, `## How it works`, FAQ, Troubleshooting (with the Reporting-a-bug row),
  `## Reporting a bug`, Issues, Version History and Credits (external only). It has no logo (#79), no
  library inventory (#58), no provenance line (#59) and no numbered list.
- `CLAUDE.md` is a stub that carries the six items in order. The provenance line is at `:55`.
- `DEPENDENCIES.md` has runtime, development and release groups. Two problems are recorded:
  `lizard` is pinned (`:35`, `:58`, `:68-70`), and the "Am I set up correctly?" block quotes raw
  `lizard` (`:98`) (MM-A-29). The line `kit 36` (`:35`) is stale because kit 37 is vendored
  (MM-A-19a).

## `docs/`

- **Tier 1:** all six are present under their canonical names.
- **Tier 2:** all seven are **present**: `perf-analysis/README.md`, `compat-layer.md`,
  `midnight-quirks.md`, `debug.md`, `slash-dispatch.md`, `message-bus.md` and `profiles.md`. Each one's
  trigger was measured as fired: 20 verbs plus a sub-tree, 14 messages, a Profiles page, 30 shims, and
  a diagnostics dump. That closes MM-A-03.
- **`## Documentation map`** has four tables in the mandated order (`docs/ARCHITECTURE.md:340`,
  `:352`, `:369`, `:380`). The fourth table holds exactly the six rows. All 22 live `.md` files under
  `docs/` are registered once, with no dangling row. The frozen stores get one row each. There is no
  retired doc: no `file-index.md`, `conventions.md`, `complexity.md`, `perf-runs/` or
  `pending/LEDGER.md`.
- **Hub shape:** `docs/ARCHITECTURE.md` is **578 lines** (it was 762). Every mandated section that
  has a canonical topic doc has spilled. The size comes from `## Documentation map` (`:317-390`) and
  `## Documented deviations` (`:391-513`) (MM-A-06).
- **Hub drift:** `:45` still reads "all fifty-eight of them" against the 63 at `:14`. `:511-512` counts
  "three" register declines where two rows exist. `:444` and `:454` head two retired-row notes with
  "One row is ratified." (MM-A-24). `docs/settings-panel.md:29` names v1.68.1 as bundled
  (MM-A-19a).

## The recorded-deviation register, read first

`docs/ARCHITECTURE.md:405-411` carries **five ratified rows**: two under `options-ui-§17`, two under
`library-stack-§8` and one under `options-ui-§15`. Each was checked three ways: the cited rule still
says what the row claims, the re-check trigger has not fired against this tree, and every cited
evidence id resolves (`MM-A-07` in `docs/audits/2026-09-07/`, `MM-A-25` in `docs/audits/2026-09-23/`).
All five stand and are recorded as **accepted** in `03_EVIDENCE.md` §R. None counts toward the MUST
tally. The `slash-commands-§8` text names this addon's master-lock row as out of that section's
reach, and it was not re-litigated.

**The issue store**, read with `gh issue list --state all --limit 200 --json …`, holds 58 issues.
Each carries exactly one `state:` label and one `severity:` label. No closed issue carries an open
state, so MM-A-16 is closed. There is no `[status]` title prefix and no `LEDGER.md`. The
`state:will-not-do` issues (#15, #16, #20, #25, #46 and #53) decline features or library options, not
rules of the standard, so none of them owes a register row.

**Re-vendor bundle coverage.** The `audit-review-history` check finds **two** vendored tags with no
bundle, **v1.69.0** (`824999b`) and **v1.70.0** (`1ee53cf`). Both were committed as bare `chore:`
re-vendors. The 28-tag backlog of 2026-09-23 has been discharged by the span bundle
`docs/revendor/2026-09-24-v1.14.0-v1.54.2/` and the per-tag bundles after it (MM-A-19, narrowed).
