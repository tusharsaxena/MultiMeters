# 01 — Current state (Ka0s Multi Meters, 2026-09-08)

**Audited against the Ka0s WoW Addon Standard v2.39.0 (2026-09-07)** — resolved by fetching
`AUDIT.md`, `standards/STANDARDS.md` and **all 26 section files** the index's Sections list links,
plus `standards/ADDONS.md`, with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`. Line 1 of the fetched
`STANDARDS.md` reads `# Ka0s WoW Addon Standard (v2.39.0, 2026-09-07)`; the amended text is what this
run measured against. `tiered-layout.md` appears in the changelog only — it was retired and `layout`
renumbered — so it is not one of the 26 and its absence is not a fetch failure.

This repo has a `.toc`, so it is audited as an **addon** (the full section set), not against
`library-stack-§7`'s library applicability list.

Read-only run. The only files written are the five under this folder.

---

## Repository

`master` at `990bfc7` (*Merge branch 'feat/2026-09-07-audit-review-remediation'*), clean working
tree. The whole 2026-09-07 remediation cycle has landed on this branch: `M2-09`…`M2-12`, `M4-07`,
`M4-10`, `M4-23`, `M4-26`, `M4c-05`, `M4c-06`, `M5-01`…`M5-05`.

## Layout (`layout`)

Modular tree exactly as `layout-§1` draws it: `core/` (15 files), `defaults/Profile.lua`,
`locales/enUS.lua`, `modules/` (18), `settings/` (13), `libs/`, `media/`, `tests/`, `docs/`.
Casing is PascalCase files under lowercase folders throughout.

**The 1500-LOC cap, measured under v2.39.0's stated scope** (every authored `.lua` the repository
tracks, `tests/` included; `libs/` and `tests/_kit/` the only carve-out that reaches anything here):
**15 files over the cap, 2 in the 1000–1500 band.** Every one of the fifteen sits in one of
`layout-§1`'s three terminal states — eight carry an open issue naming the seam (`#27`–`#34`), seven
mirror-suites are covered by a ratified `## Documented deviations` row dated 2026-09-08 — and the
census is published at `docs/ARCHITECTURE.md:510-557` with `tests/test_layout_cap.lua` asserting its
membership in both directions. `layout-§1` says an audit **MUST NOT** re-file against a file in that
state, and this run does not.

`media/` holds `logos/` (the `.tga` runtime art plus the `.png`/`.jpg` masters) and
`textures/Default.tga`. No file under `media/` duplicates anything in `libs/LibKa0s/media/` — md5s
compared, all distinct, and the library ships no texture of that name.

## TOC (`toc-file`)

`MultiMeters.toc`, 81 lines. Field order matches `toc-file-§1` exactly, single Interface `120007`,
`X-License: MIT`, `X-Standard:` present. `X-Curse-Project-ID` is **absent with the comment in its
position** (`:13-14`) — compliant under `toc-file-§1`, filed as nothing. `#`-sectioned file list:
`# Libraries` → `# Locales` → `# Core` → `# Defaults` → `# Modules` → `# Settings`, matching
`layout-§1`'s folder order. `libs\LibKa0s\LibKa0s.xml` is listed **once** (`:27`), inside
`# Libraries`, after the Ace3 block — never module `.lua` files. Load-bearing positions in `# Core`
each carry a comment naming what resolves (`:38-41` EnvSetup before Namespace's file-scope version
read; `:45-46` MediaSetup before Constants' `FONT_MONO`; `:43` PoolSetup; `:57-58` Diagnostics last).

## Libraries (`library-stack`)

`libs/` carries Ace3 (AceAddon/AceEvent/AceTimer/AceDB/AceDBOptions/AceConsole/AceConfig/AceGUI),
CallbackHandler, LibStub, LibSharedMedia, LibDataBroker, LibDBIcon, AceGUI-SharedMediaWidgets and
`LibKa0s`. The `LibKa0s` payload is the source repo's **whole ship folder** — 14 module files plus
`media/` and `LICENSE`.

**Seven LibKa0s seams, all consuming and none hand-rolling** — `core/CoreSetup.lua:88`,
`core/DebugLogSetup.lua:227`, `core/PerfSetup.lua:41`, `core/MediaSetup.lua:72`,
`core/EnvSetup.lua:71`, `core/PoolSetup.lua:35`, `settings/OptionsSetup.lua:110`, plus the slash
descriptor at `settings/Slash.lua:72`. There is no `modules/DebugLog.lua`, no widget-maker file, no
dispatcher and no test framework of the addon's own; `tests/_kit/` is the vendored harness under
`tests/`, never `libs/`.

**`library-stack-§9` / anti-pattern #76**: there is no `core/LSMPatch.lua`. The Border-widget
re-registration is the library's, called once at file load through `lib.__PatchLSM30Border`
(reasoned at `settings/OptionsSetup.lua:369-413`).

`media` seam: `core/MediaSetup.lua` takes the addon's **own first vararg** (`:70`
`local addonName, NS = ...`) and makes one `Media.RegisterLSM(addonName)` call at `:110`, loading
before `core/Constants.lua` per the TOC comment. The DebugLog descriptor carries `addonName`
(`core/DebugLogSetup.lua:324`).

## Settings (`options-ui`)

Nine pages — General, Windows, Frame, Header, Bars, Tooltip, Visibility, Columns, Profiles — with
162 schema rows in `settings/Schema.lua`. Every page renders through the flow engine with a tab
strip except the two exempt ones (`Profiles`, AceConfig-drawn; the landing page is the host's own
`buildMain`). The General page's first tab is exactly **`Master controls`**, composed
(`settings/Schema.lua:858-870`). Fourteen font/border/bar/color groups are composed; the two
`LSM30_*` hits outside a composer (`settings/Schema.lua:1565`, `:1573`) are the addon-wide
**broadcast meta rows**, which `options-ui-§16` now names as the one exempt shape and cites as this
addon's own — audited against its five bounds and compliant. No `disabledIf` on a color row, no
chat-scroll reorder art, no `InlineGroup`/backdrop boxing a chrome band.

## Debug / perf / slash

Console is `LibKa0s-DebugLog-1.0`'s; the addon owns a descriptor and a degradation stub.
`MakeCloseButton` grep returns one wrapper (`core/CoreSetup.lua:239`), one call site
(`modules/Export.lua:1067`) and a comment — no `#65`. The perf-panel `decorate` hook is deliberately
absent, reasoned at `core/PerfSetup.lua:215-225`. The harness is wired (`core/PerfSetup.lua`,
`tests/perf.lua`, `MultiMetersPerfDB`), so no `performance-§12` exemption is held and
`docs/perf-analysis/README.md` is required and present. Slash surface: 16 verbs in `NS.COMMANDS`
(`settings/Slash.lua:72-95`) with a `window` sub-verb tree.

## Tests, lint, complexity

- `lua tests/run.lua` — **1534 passed, 0 failed, 0 skipped**. Matches `docs/test-cases.md`'s
  `**Total** | **1534**` and the README badge.
- `luacheck .` — **0 warnings / 0 errors in 94 files**. `.luacheckrc` narrows `exclude_files` to
  exactly the canonical set and puts the harness global in a `files["tests/"]` stanza; **no
  top-level `ignore`** (removed by `M4c-06`), with 12 per-file `<code>/<variable>` stanzas in its
  place.
- `lua tests/perf.lua` — 15 scenarios, exit 0.
- `lizard -l lua -x './libs/*' -x './tests/_kit/*' .` — **23 warnings**, max CCN 34, 33091 nloc,
  3343 functions.
- Latest bundle `docs/automated-tests/20260908-181355/` (non-release, `ANALYSIS.md` present), and
  `RESULTS.md` carries a **per-entry disposition** watch list — 12 *Accepted*, 11 *Peel* each with
  an issue number — plus the `layout-§1` band table.

## `.gitattributes` (`line-endings`)

Present at root, 81 lines, **byte-identical to the canonical client-bound body** (`diff` against the
text extracted from `line-endings-§5` is empty) with no appendix. Pin verbatim at `:26`:

```
* text=auto eol=crlf
```

`*.sh text eol=lf` at `:34`; 20 ` binary` lines. Working tree agrees with the pin: **0** stragglers.
The vendored gate `tests/_kit/test_eol.lua` (kit revision 15) is present and its case is green.

## Root docs

- `README.md` — player-facing, 5-badge row, `## What's new in 0.1.0`, Screenshots, Usage (with both
  mandated subsections and a 16-row slash table generated from `NS.COMMANDS`), How it works, FAQ,
  Troubleshooting, Issues, Version History, Credits (external only — JetBrains Mono and Open
  Iconic). No bundled-library inventory, no angle-bracket placeholders, standard badge **bare**.
  Two structural gaps are filed (MM-A-14, MM-A-15).
- `CLAUDE.md` — a 52-line stub with all six mandated items in order, including the provenance line
  at `:52`: `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT).` **Zero** hits
  for that line in `README.md`.
- `DEPENDENCIES.md` — runtime / development / release split, evidence per entry, `pipx` install
  commands and a verification command per tool.

## `docs/`

Tier 1 all six present under the canonical names. Tier 2: `compat-layer.md` and `midnight-quirks.md`
shipped this cycle; four remain evaluated as *Not applicable* against triggers that fire (MM-A-03).
No retired doc survives — no `file-index.md`, no `conventions.md`, no `complexity.md`, no
`docs/perf-runs/`, no `docs/pending/LEDGER.md`. No non-canonical Tier 1/2 filename. Every live `.md`
under `docs/` is registered exactly once with no dangling row; what fails is the register's **table
shape** (MM-A-13). `docs/ARCHITECTURE.md` is 773 lines with all ten mandated sections present and
every non-register mandated section under the 60-line spill threshold.

## The recorded-deviation register, read first

`docs/ARCHITECTURE.md:439-508` carries **five ratified rows**. Every one was checked three ways —
cited rule still says what the row claims, re-check trigger evaluated **against this tree**, every
evidence id resolved — and all five stand. Details and the resolution of each id are in
`03_EVIDENCE.md`. The issue store was read with `gh issue list --state all --limit 200`: 46 issues,
every one labeled, no `[status]` title prefix anywhere. No `state:will-not-do` issue declines a
standards rule without a register row.
