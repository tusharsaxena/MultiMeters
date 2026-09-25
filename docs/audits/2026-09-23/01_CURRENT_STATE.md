# 01 — Current state (Ka0s Multi Meters, 2026-09-23)

**Audited against the Ka0s WoW Addon Standard v2.64.0 (2026-09-23).** The rules were resolved by
fetching `AUDIT.md`, `standards/STANDARDS.md`, `standards/ADDONS.md` and **all 27 section files** the
index's Sections list links, with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`. Line 1 of the fetched index
reads `# Ka0s WoW Addon Standard (v2.64.0, 2026-09-23)`. Two independent curl fetches of the section
files made in this session were compared with `cmp` and were byte-identical (27 of 27), so no file was
read mid-transfer.

**Repo kind: addon.** The repo has a `.toc` (`MultiMeters.toc`) and is the `Ka0s Multi Meters` row of
`ADDONS.md`'s addon table, so the full addon rule set applies, section by section. Neither the
`library-stack-§7` library list nor the `documentation-§8` documentation-and-tooling list was used.

**Deviation-ID prefix: `MM-A-`**, reused from the 2026-09-07 and 2026-09-08 bundles.

Read-only run. The only files written are the five under this folder. **Bounded runs:** the
harness note said `ka0s-bounded` was not on `PATH`. It is installed at
`~/.claude/wow-addon/bin/ka0s-bounded`, and every `luacheck`, `lua tests/run.lua` and `lizard` run in
this bundle went through it by that absolute path. No run exited 124 or 137.

---

## Repository

Branch `feat/2026-09-23-review-audit-remediation` at `4aefb58` (*Merge branch
'suite/2026-09-22-standards-sweep'*), and `git status` was clean when the audit started. The
LibKa0s v1.55.0 re-vendor (`a5a1014`, 2026-09-23) and the v1.55.0 adoption commits (Compat and Bus
majors adopted, Schema deferred under issue #52) are in the tree. Tags: `1.0.0-release` (`823710c`)
and `1.0.1-release` (`71e5742`).

## Layout (`layout`)

`core/` (19 files), `defaults/` (1), `locales/` (1), `modules/` (22), `settings/` (15): 58 authored
source files, PascalCase files in lowercase folders, plus `libs/`, `media/`, `tests/`, `docs/`. No
authored generator: `git ls-files '*.py' '*.sh'` returns only the vendored
`tests/_kit/run-automated-tests.sh`.

**The 1500-line cap.** `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'` gives 125 files
(58 source, 67 under `tests/`). **None is over 1500.** 23 files sit in the 1000–1500 on-notice band;
the largest is `tests/test_provider.lua` at exactly 1500 and the largest source file is
`modules/Row.lua` at 1469. The census heading `### Files over the 1500-line cap` sits under
`## Documented deviations` (`docs/ARCHITECTURE.md:592`) and says "Nothing is over the cap today"
(`:594`), which is the result `layout-§1` asks for. The kit's gate is wired by path
(`tests/run.lua:225`, `{ name = "test_layout_cap", dir = "tests/_kit/" }`) and passes.

**Media.** `media/logos/` (runtime `.tga` files plus `.png` and `.jpg` masters) and `media/screenshots/`.
No `fonts/`, `icons/` or `textures/` duplicates anything in `libs/LibKa0s/media/`.

## TOC (`toc-file`)

Field order matches `toc-file-§1`. `## Interface: 120100`, `## Version: 1.0.0`, `X-License: MIT`,
`X-Standard:` present, `X-Curse-Project-ID: 1690082` (the addon is published). `## IconTexture:`
names `Interface\AddOns\MultiMeters\media\logos\multimeters.logo.128.tga`. Its header bytes are image
type 2 (uncompressed), 128 × 128, 32 bpp, so it passes `layout-§4`. The sections run
`# Libraries → # Locales → # Core → # Defaults → # Modules → # Settings`, and `libs\LibKa0s\LibKa0s.xml`
appears once, after Ace3. Most load-bearing lines carry their comment. Three pairs do not (MM-A-22).

**Tag vs TOC.** Tag `1.0.1-release` points at a commit whose TOC still says `## Version: 1.0.0`,
and README `## Version History` has no 1.0.1 row (MM-A-21).

## Libraries (`library-stack`)

Ace3, CallbackHandler, LibStub, LibSharedMedia, AceGUI-SharedMediaWidgets, LibDataBroker, LibDBIcon
and `LibKa0s`. The root `CLAUDE.md:53` provenance line reads `Bundles [LibKa0s](…) v1.55.0 (MIT).`
Against tag `v1.55.0` (`bb161b7`), both `diff -r` runs come back **empty**: `LibKa0s/` against
`libs/LibKa0s/` and `testkit/` against `tests/_kit/`. That means whole-folder vendoring with no drift
(no #45, no #48).

**Seams, all consuming and none hand-rolling:** `core/EnvSetup.lua`, `core/PoolSetup.lua`,
`core/MediaSetup.lua`, `core/CoreSetup.lua`, `core/LifecycleSetup.lua`, `core/PerfSetup.lua`,
`core/DebugLogSetup.lua`, `core/LauncherSetup.lua`, `settings/OptionsSetup.lua` and the slash
descriptor in `settings/Slash.lua`. The v1.55.0 majors: `LibKa0s-Compat-1.0` is consumed through
`core/Compat.lua` and `core/Secrets.lua` (a reader arm plus a guard arm). `LibKa0s-Bus-1.0` is consumed
through `core/Constants.lua` (`Catalog`) and `core/Namespace.lua` (stand-down record), with an
untracked-target stub. `LibKa0s-Schema-1.0` is deferred as a partial adopter under open issue #52,
which v2.64.0 permits (`library-stack-§7`: no host is required to adopt the three). The stub-parity
cases pass (`parity: …` and `Degraded: …` in the suite run). No `core/LSMPatch.lua`.

**Shared media.** One `MakeCloseButton` wrapper (`core/CoreSetup.lua:239`) and one call to it
(`modules/Export_Modal.lua:226`), so no #65. The hard-coded `Interface\` census is 15 lines
(`libs/` and `tests/` excluded), matching the table at `docs/ARCHITECTURE.md:659-672`. Two of its
dispositions decline a catalog mark the payload does carry and have no register row (MM-A-25).

## Patterns (`architecture`, `events-frames-taint`)

`NS` is the AceAddon object. There is no `_G` namespace and no hand-rolled dispatcher. The bus has 14
messages, all declared in `core/Constants.lua`'s `MSG` catalog through `LibKa0s-Bus-1.0`'s `Catalog`.
Wire strings are `Ka0s_MultiMeters_<PascalCase>`. The one SCREAMING_SNAKE hit (`core/Constants.lua:513`)
is inside a comment. No call site types a message literal.

**Event registration** happens in one place (`core/MultiMeters.lua`, `NS:OnEnable`): 21 bare
`self:RegisterEvent` calls plus one probed `registerIfValid` call (`:195`). The block is not isolated
per event, and nothing records rejected names (MM-A-20).

**Write paths (`architecture-§5`).** The registry writer is named (`modules/WindowManager.lua` plus
`Database.NextWindowId` and `Database.EnsureWindowShape`), and so is the load pass
(`Database.SeedWindows` via `NS:RunMigrations`). Named non-setting state (`frame.position`,
`db.global.roster`, `minimapPos`, `MultiMetersPerfDB`) is tabulated at `docs/ARCHITECTURE.md:119-124`.
The grep for stored-tree writes outside the seam turns up only the migration runner, the registry
writer and the named owners.

## Settings (`options-ui`)

Nine pages. The schema holds 169 rows across 8 page keys, and Profiles is AceConfig-drawn with zero
rows. Every schema page draws a tab strip. The General page's first tab is `Master controls`,
composed by `LibKa0s-Options-1.0`. Font, border and bar groups are composed, and the broadcast meta
rows are the named exempt shape. No `disabledIf` on a color row. No chat-scroll reorder art, since
the Columns page uses `LibKa0s-Widgets-1.0`'s `ReorderList`. The only `SettingsPanel|HideUIPanel|
ToggleGameMenu|OpenToCategory` hits outside `libs/` are in `tests/`, so the addon has no second open
and no in-combat close (#88). Test mode is a composed session-only checkbox, refused in combat. One
ratified row covers `options-ui-§15`'s master lock. **Not yet present:** a suite case pinning the
wrapped tab strip's geometry against the selection (MM-A-08).

## Launcher (`launcher`)

`core/LauncherSetup.lua` builds one `LibKa0s-Launcher-1.0` object, registered with both LDB and
LibDBIcon. Its label is `L["Ka0s Multi Meters"]`. The icon is the addon's own 128 logo. Left-click
toggles the windows, which is rung (a) and matches `ADDONS.md:25`. Right-click opens the panel. The
visibility row is `global.minimap.hide`, stored globally and carved out of both resets.

## Slash and the disabled state (`slash-commands`)

`NS.COMMANDS` holds 18 verbs: the twelve reserved ones first, then `lock`, `test`, `toggle`,
`window`, `reset-positions` and `export`. `enable` and `disable` write `enabled` through
`NS.SetByPath`. **The disabled state is total.** `core/LifecycleSetup.lua` is one
`LibKa0s-Lifecycle-1.0` latch with two holds, `disabled` (persisted) and `perf` (session-only). The
stand-down unregisters all game events (`:62`), cancels timers (`:63`), unregisters every module's
messages, takes the bus down (`NS.BusStandDown`), suspends windows and the provider, and cancels a
queued export. `tests/test_disabled.lua` (`tests/run.lua:300`) asserts on the mock's registration set
(`Disabled 3`). The whole slash surface stays live while disabled; the six feature verbs refuse on one
line, which is the SHOULD taken. LibKa0s v1.55.0 is at or above the v1.42.0 floor. This area is
compliant.

## Debug, perf, tests, lint, complexity

- Console: `LibKa0s-DebugLog-1.0` descriptor plus stub in `core/DebugLogSetup.lua`. The harness is
  wired (`core/PerfSetup.lua`, `tests/perf.lua`, `MultiMetersPerfDB`), so `docs/perf-analysis/README.md`
  is owed, and it is present with one bundle (`20260909-014604/`) carrying `ANALYSIS.md`.
- `lua tests/run.lua` gives **1948 passed, 0 failed, 0 skipped**. That matches `docs/test-cases.md`'s
  `**Total** | **1948**` and the README badge `Tests-1948%2F1948_passing`.
- `luacheck .` gives **0 warnings / 0 errors in 125 files**. `exclude_files` is `libs/`, `tests/_kit/`,
  `docs/audits/`, `docs/reviews/`, `_dev/`. The harness global sits in `files["tests/"]`, and there
  is no top-level blanket `ignore`.
- `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` gives **0 warnings**, max CCN 15, 40425 NLOC,
  4126 functions.
- Latest run bundle: `docs/automated-tests/20260916-184449/` (sha `2d38bbd`, clean, 32 commits behind
  HEAD, 7 days old). It records 1884 cases and one warned function (`NS.ValidateSchema`, CCN 19),
  which now measures 15. That drift is Info (MM-A-26). The checkpoint is release, not commit.
- The kit gates are wired by path: `test_layout_cap`, `test_prose`, `test_eol`, plus
  `test_vendor_sync`. Runner budgets are the kit's defaults, with no raised `heapBudgetMB`,
  `leakBudgetMB` or `caseSeconds`.

## Packaging (`packaging`)

`.pkgmeta` ignores every named dev entry. The root dot-entry sweep prints only `.git`, which is
exempt, and the false-claim check prints nothing, because `.claude` and `.superpowers` both exist.
Compliant.

## `.gitattributes` (`line-endings`)

Present, 84 lines, and the body is **byte-identical to the canonical client-bound body** (the diff of
the first 84 lines against the text extracted from `line-endings-§5` is empty), with no appendix.
The pin, verbatim, at `.gitattributes:26`:

```
* text=auto eol=crlf
```

`*.sh text eol=lf` sits at `:36` and `*.py text eol=lf` at `:37`; there are 20 ` binary` lines. The
working-tree agreement check (e) returns **0**. The kit gate `tests/_kit/test_eol.lua` is wired and
green.

## Root docs

- `README.md`: H1, the five canonical badges (the published version endpoint is in slot 2, and the
  standard badge is **bare**, not a link), description, Screenshots, Usage (five paragraphs of prose
  closing on one configuration line, with no command or tab table), `## How it works`, FAQ,
  Troubleshooting, Issues, Version History (bulleted `- ` highlights), Credits (external only). No
  logo image (#79), no library inventory (#58), no provenance line (#59).
  The British `minimise` at `:50` is filed under MM-A-18.
- `CLAUDE.md`: a stub with all six items in order. The provenance line is at `:53`, and it is the
  only one in the repo.
- `DEPENDENCIES.md`: runtime, development and release groups, with install and verify commands.

## `docs/`

- Tier 1: all six are present under the canonical names.
- Tier 2: four are present (`perf-analysis/README.md`, `compat-layer.md`, `midnight-quirks.md`,
  `debug.md`). Three are recorded *Not applicable* against triggers that have fired (MM-A-03).
- `## Documentation map` is present, with four tables in the mandated order:
  - Required, Conditional, Verification and record, Addon-specific. The self-row is a MAY and is
    not filed either way.
  - The fourth table holds exactly the six required rows.
  - All 18 live `.md` files under `docs/` are registered once, with no dangling row.
  - Frozen stores (`superpowers/`, `revendor/`, `audits/`, `reviews/`) get one row each.
- Nothing retired survives: no `file-index.md`, `conventions.md`, `complexity.md`, `perf-runs/`,
  `pending/LEDGER.md`, `agent-context.md` or `TODO.md`.
- Hub shape: `docs/ARCHITECTURE.md` is **762 lines** (MM-A-06). Every mandated section that has a
  canonical topic doc sits under 60 lines. The two register sections run 73 and 182 lines, and they
  have nowhere to spill.
- The hub's own inventory line (`:14`) disagrees with the tree and with `module-map.md:6` (MM-A-24).

## The recorded-deviation register, read first

`docs/ARCHITECTURE.md:514-520` carries **five ratified rows**. Each was checked three ways:

- the cited rule still says what the row claims;
- the re-check trigger, evaluated against this tree, has not fired;
- every evidence id resolves.

All five stand and are recorded as **accepted** in `03_EVIDENCE.md`. None counts toward the MUST
tally. One row's Rule cell is written `library-stack §8` rather than `library-stack-§8` (MM-A-23).

**The issue store** was read with `gh issue list --state all --limit 200 --json number,title,state,labels`:

- 52 issues, each carrying exactly one `state:` label and one `severity:` label.
- No `[status]` title prefix and no `docs/pending/LEDGER.md`.
- Three closed issues carry an open-state label (MM-A-16).
- The `state:will-not-do` issues decline features rather than standards rules. The exceptions are
  #20 (LibKa0s-Item, optional) and #46 (splitting for the cap), which the 2026-09-09 peels made moot.
  So no decline needs a register row.

**Re-vendor bundle coverage.** The `audit-review-history` check finds **28 vendored tags with no
bundle** since the store's horizon (2026-08-25) (MM-A-19).
