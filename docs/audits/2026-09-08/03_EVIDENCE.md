# 03 — Evidence (Ka0s Multi Meters, 2026-09-08)

Every `file:line` below was **re-read at the time this file was written** and the cited text is
quoted beside it. Every count is produced by a **recorded command whose scope is stated** — which
paths it swept and which it did not. Nothing here is re-typed from the 2026-09-07 bundle.

Machine: WSL2 / Ubuntu. Repo: `/mnt/d/Profile/Users/Tushar/Documents/GIT/MultiMeters`, `master` at
`990bfc7`, clean.

---

## 0. The standard this run resolved

```
$ curl -fsSL https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md -o STANDARDS.md
$ head -1 STANDARDS.md
# Ka0s WoW Addon Standard (v2.39.0, 2026-09-07)
```

`AUDIT.md` (583 lines), `standards/STANDARDS.md` (175 lines) and **all 26 files** the Sections list
links were fetched with `curl -fsSL` and read from disk. The Sections list was extracted rather than
hard-coded:

```
$ awk '/^## Sections/,/^## [^S]/' STANDARDS.md | grep -oE '^\- \*\*\[[a-z0-9-]*\]' | wc -l
26
```

A 27th path, `standards/standards/tiered-layout.md`, appears in the changelog prose and returns 404;
the changelog says that section was **retired** and `layout` renumbered around it, so it is not in
the Sections list and its absence is not a failed fetch.

---

## 1. The recorded-deviation register — read before anything was filed

### 1a. `docs/ARCHITECTURE.md` `## Documented deviations` (`:439-509`, five rows)

Each row was checked three ways, as `audit-review-history`'s third MUST now requires: the cited rule
still says what the row claims **under v2.39.0**; the re-check trigger evaluated **against this
tree**; every evidence id resolved.

| # | Row's Rule | Trigger fired? | Evidence ids resolve? | Verdict |
|---|---|---|---|---|
| 1 | `debug-logging §8` — the unchanged-summary heartbeat | **No.** `debug-logging` §8 and §9 were re-read in full at v2.39.0: §9 bounds **per-item** emission on a repeating path and still says nothing about a pass repeating unchanged on a timer. No new rule for timer-driven passes exists. | n/a (points at `core/DebugLogSetup.lua`'s steady-state sink, which exists) | **Accepted, stands** |
| 2 | `options-ui §17` — `window.header.bgColor` ships with no class-color companion | **No.** The trigger is "the title bar grows a surface that belongs to one column or to one player". `settings/Schema.lua:1772` is still `path = "window.header.bgColor", type = "color",` with no per-column surface; the contrasting row `window.columnHeader.bgColorMode` still exists at `:1446`. | `settings/Schema.lua` note resolves | **Accepted, stands** |
| 3 | `options-ui §17` — `NS.ClassRGB` as a second `RAID_CLASS_COLORS` reader | **No.** Trigger is "`LibKa0s-Core-1.0` grows a class-**filename** overload of `ClassColor`". The vendored v1.27.0 payload has exactly one: `libs/LibKa0s/Core.lua:344` `function lib.ClassColor(unit)` — unit-keyed. `core/Namespace.lua:68` `function NS.ClassRGB(classFilename)` still answers the other question. | resolves | **Accepted, stands** |
| 4 | `layout §1` — the seven mirror suites over the cap | **No.** Trigger is "the mirrored module is peeled, or its issue (#27–#33) reaches a terminal state". None is peeled; all of `#27`–`#33` are OPEN. | `#27`–`#34` all resolve to open issues in this repo's store (listed in §7 below) | **Accepted, stands** |
| 5 | `library-stack §8` — the `ReadyCheck` pair at `settings/ColumnBlocks.lua:72-73` | **No.** Trigger is "ConsumableMaster's three sites adopt the catalog, or its priority list is retired". All three still carry the pair — verified in the sibling repo, §8 below. | `MM-A-07` resolves to `docs/audits/2026-09-07/02_DEVIATIONS.md`; the LootHistory precedent resolves | **Accepted, stands** |

**No row cites a rule the standard has since changed** in a way that mandates or permits the
behavior. Row 4 cites `layout-§1`, which v2.39.0 **did** amend — but the row was written on
2026-09-08 *against the amended text* and quotes it ("`layout-§1` is explicit that it does"), so it
is current rather than stale.

The two register rows carried as retired (`options-ui §15, §16` composed blocks; the `ReorderList`
row) were re-read: the first retires on `options-ui-§1`'s hollow-composer ruling, which v2.39.0 does
carry; the second on issue #21, which exists. Neither is a graveyard entry.

Cited row text, re-read (row 5, the one this bundle relies on most):

```
docs/ARCHITECTURE.md:459  | library-stack §8 — "where the addon needs a mark it MUST use the
                          catalog's" | `settings/ColumnBlocks.lua:72-73`'s column-block
                          enable/disable glyph stays on Blizzard's `ReadyCheck-Ready` /
                          `ReadyCheck-NotReady` pair …
settings/ColumnBlocks.lua:72  local ENABLED_TEX  = "Interface\\RaidFrame\\ReadyCheck-Ready"
settings/ColumnBlocks.lua:73  local DISABLED_TEX = "Interface\\RaidFrame\\ReadyCheck-NotReady"
```

The row's own citation resolves to the exact two lines — checked because the 2026-09-07 bundle cited
`:60-61` for the same pair and those line numbers have since moved.

### 1b. The issue store

```
$ gh issue list --state all --limit 200 --json number,title,state,labels,url
```
**46 issues.** Scope: this repo's store only. Every issue carries exactly one `state:` label and one
`severity:` label; **no title carries a `[status]` prefix** (anti-pattern #62 clean). Terminal
closures relevant to this run:

- `#17 CLOSED [bug,state:done,severity:medium]` — "Both allocation ceilings in `tests/perf.lua` are
  breached on master". Closes MM-A-11.
- `#46 CLOSED [state:will-not-do,severity:low]` — "Split any file for the 1500-line cap: declined".
  **Checked against the inverse rule**: a `state:will-not-do` with no register row is itself a
  finding. It is not one here — the decline is a *scheduling* decision, and every file it covers
  already sits in a `layout-§1` terminal state (eight open issues, seven register-row rows), which
  the issue body itself enumerates.
- `#20 CLOSED [state:will-not-do,severity:low]` — "LibKa0s-Item-1.0: declined". Body read: it
  records a library module as **not applicable** (zero item-domain hits in a recorded sweep), which
  is not a decline of any MUST, so no register row is owed.

**Four closed issues carry `state:triaged`** — #4, #6, #7, #21 — which is MM-A-16.

### 1c. The other homes of a decision

Root `CLAUDE.md` (52 lines, read whole) records no accepted deviation; it points at
`docs/ARCHITECTURE.md` `## Documented deviations` as "the single home" (`:18-20`). `docs/scope.md`
carries known limitations with issue numbers, not rule declines. `docs/pending/LEDGER.md` does not
exist (`ls docs/pending` → No such file or directory).

---

## 2. Line endings (`line-endings`) — five checks, run

Scope: **every tracked file in the repo**, `libs/` and frozen bundles included, because
`git ls-files` is the denominator the rule names.

```
$ test -f .gitattributes && echo present
present

$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes
26:* text=auto eol=crlf

$ grep -n '^\*\.sh text eol=lf$' .gitattributes
34:*.sh text eol=lf

$ grep -c ' binary$' .gitattributes
20

$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
0
```

**(e) is 0.** The 2026-09-07 bundle recorded **21** for this same repo with this same command; that
bundle is frozen and is not edited — the difference is `M4-10`'s renormalize, not a change of
method.

Kind check: the repo has a `.toc`, so it is client-bound and `eol=crlf` is the correct pin. Body
check is a **diff, not a reading** — the canonical client-bound body was extracted from
`line-endings-§5` and compared:

```
$ diff <(sed -n '1,81p' .gitattributes | tr -d '\r') /tmp/claude-1000/canon-crlf.gitattributes && echo "BODY IDENTICAL"
BODY IDENTICAL
$ wc -l .gitattributes
81 .gitattributes
```

81 of 81 lines, so there is no tail and therefore no `line-endings-§5 appendix` question to answer.

**The gate has an owner.** `tests/_kit/framework.lua:20` reads `Kit.VERSION = 15`, so the vendored
`tests/_kit/test_eol.lua` is present at the revision `line-endings-§7` MUSTs, and its case is green
in the run below:

```
PASS  eol: every tracked file carries the terminator .gitattributes declares for it
```

Gate green **and** (e) zero — so there is no gate finding.

---

## 3. Lint, suite, perf

```
$ luacheck .
Total: 0 warnings / 0 errors in 94 files
```

Scope, read off `.luacheckrc:10` before quoting the `0/0`:

```
.luacheckrc:10  exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "_dev/" }
```

That is **exactly** `lint`'s canonical list — it narrows to `tests/_kit/` and nothing wider, so the
94 files include the whole `tests/` tree. The harness global is in the stanza, not at top level:

```
.luacheckrc:102  files["tests/"] = {
.luacheckrc:104      "_G.MULTIMETERS_TEST",
```

There is **no top-level `ignore`** — `.luacheckrc:12` reads `-- NO TOP-LEVEL \`ignore\`, and none is
coming back (lint-§1, \`M4-11\`)`, and the twelve replacements are per-file `<code>/<variable>`
stanzas (`:137`–`:191`). `tests/test_lintconfig.lua` is what keeps the blanket out.

```
$ lua tests/run.lua | tail -1
1534 passed, 0 failed, 0 skipped, 1534 total

$ lua tests/perf.lua ; echo "EXIT=$?"
… 15 scenarios …
EXIT=0
```

Badge reconciliation, because three documents quote this number and they are read as one:

```
README.md:7                 ![Tests](https://img.shields.io/badge/Tests-1534%2F1534_passing-green)
docs/test-cases.md (last)   | **Total** | **1534** |
lua tests/run.lua           1534 passed … 1534 total
```

All three agree. (The 2026-09-07 bundle's MM-A-09 recorded 1487 against 1496; both numbers are
history and neither is re-used here.)

---

## 4. Complexity — measured with the standard's exact invocation

```
$ lizard -l lua -x './libs/*' -x './tests/_kit/*' .
     33091       8.2     2.6       63.7     3343           23      0.01    0.03
   (Total nloc | Avg.NLOC | AvgCCN | Avg.token | Fun Cnt | Warning cnt | Fun Rt | nloc Rt)
```

Verbatim invocation from `performance-§10` / `automated-tests`; no extra flag, no narrowed path.
Scope: the whole repo minus `libs/` and `tests/_kit/`, so `tests/` **is** counted.

Compared against the latest bundle — `docs/automated-tests/20260908-181355/manifest.json`, read
today:

```
"complexity": { "status": "pass", … "warnings": 23, "maxCcn": 34, "nloc": 32913,
                "functions": 3337, … "bandFiles": 2, "overCapFiles": 15 … }
"tests": { … "passed": 1530, … "total": 1530 … }
"lint": { … "files": 93 … }
"git": { "sha": "a34854537ec79ef3cecd75f69db7c37d98e414c1", "branch": "feat/2026-09-07-audit-review-remediation" }
```

**Drift since that bundle: none that matters.** Warnings 23 → 23; max CCN 34 → 34 (`scanColumn`);
nloc 32913 → 33091; functions 3337 → 3343. **No function crossed a `lizard` threshold and no file
entered or left a `layout-§1` band.** The bundle's own stamp dates it to today, four commits behind
`master`:

```
$ git log --oneline a3485453..HEAD
990bfc7 Merge branch 'feat/2026-09-07-audit-review-remediation'
03e9b75 M4c-06: the blanket ignore goes, and thirty-two of the eighty-four were real
1049a15 M4c-05: two documents disagreed about which watch-list cells go blank
083ca8f M4c-05: the register named a commit and was wrong about it
8ff9335 M5-01: the record stops saying zero warnings above a row recording nineteen
```

`M4c-06` added `tests/test_lintconfig.lua`, which is the whole of the 1530 → 1534 and 93 → 94 gap.
That is MM-A-17, and it is Info because `automated-tests-§6` forbids gating commits on a bundle.

**The artifact itself, audited against `automated-tests`:** the runner is vendored and executable
(`tests/_kit/run-automated-tests.sh`), `docs/automated-tests/README.md` and `RESULTS.md` both exist,
and there is **no** retired `docs/complexity.md` (`ls` → No such file or directory).

### The watch list read as a decision record, not an inventory

`docs/automated-tests/RESULTS.md:70-97` carries **23 rows, one per warned function, each with a
disposition**: **12 Accepted** and **11 Peel**, each Peel naming an issue — `#35` (`scanColumn`)
through `#45` (`doDebug`), eleven rows and eleven issues. Not every entry reads "accepted", and the list is one screen — so
anti-pattern #53's two failure shapes are both absent.

How many consecutive release runs has any entry carried "Accepted"? **One, and it is this one.**

```
$ git log --oneline -- docs/automated-tests/RESULTS.md
8ff9335 M5-01: the record stops saying zero warnings above a row recording nineteen
84558e5 Record the 6.34s gate, and stop smoke-testing a bug LibKa0s fixed
b81f514 Re-vendor LibKa0s v1.14.0 — the green gate goes from 2m10.8s to 7.3s
c445ec1 Initial commit ... yay!
```

Four commits in the file's whole history, and the watch list in its present shape arrived in the
newest of them.

Before `8ff9335` the file's watch list read *"**None.** `lizard` reports 0 warnings"* over a table
row recording 19 — which is the stale record MM-A-02 filed and `M5-01` fixed. So no disposition has
survived three runs and #53's three-run trigger cannot have fired.

**Dense defaulting versus tangled control flow**, as `performance-§10` asks: the 12 Accepted are
defaulting/guarding — `Format.DeathTime` is 15 NLOC at CCN 19 with no branch in it, the three
`core/Database.lua` migration steps are `type(x) == "table"` guards — and the 11 Peel are genuine
control flow (`onClick`'s seven-way `elseif`, `Visibility.ShouldShow`'s eight copies of one line,
`Feign.Prune`'s two eviction paths). The record says which is which per row.

### Complexity refactors this cycle, audited against `performance-§11`

`M2-09` took `scanColumn` from 36 → 34 by hoisting `judgeTracer` out — a named extraction, not a
body dumped into an unnamed helper (#52). No dispatch or defaults table was introduced **inside** a
function (#43): the four Peel rows that propose one say "module-level" in as many words and none is
implemented yet. And:

```
$ git diff a3485453..HEAD -- '*.lua' | grep -E '^\+.*= *[a-z]+\.[a-zA-Z]+ or '
(no output)
```

So no `t.k = stored.k or D.k` defaulting was introduced over fields whose stored `false`/`""` is a
user choice (#54, `savedvariables-§5`).

---

## 5. Vendored Ka0s-owned library drift — both diffs, at the tag the addon names

Provenance, re-read:

```
CLAUDE.md:52   Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT).
$ grep -n 'Bundles \[LibKa0s\]' README.md
(no output)
```

The sibling repo is present at `/mnt/d/…/GIT/LibKa0s`. Diffed **at the tag `CLAUDE.md` names**, not
at `HEAD`:

```
$ git -C ../LibKa0s worktree add --detach /tmp/claude-1000/libka0s-v1270 v1.27.0
HEAD is now at 43c32ea M1-LK-15: the v1.27.0 release record

$ diff -r /tmp/claude-1000/libka0s-v1270/LibKa0s libs/LibKa0s && echo EMPTY
EMPTY

$ diff -r /tmp/claude-1000/libka0s-v1270/testkit tests/_kit && echo EMPTY
EMPTY
```

Both empty — **no #45 drift, no #48 partial vendoring**, over the whole folder rather than the
modules the addon happens to wire. `v1.27.0` is the newest tag in the library repo (`git tag
--sort=-v:refname | head -1`), with 4 unreleased commits past it, so the pin is current as well as
honest.

TOC listing, re-read: `MultiMeters.toc:27` is `libs\LibKa0s\LibKa0s.xml` — the single aggregate,
listed once, inside `# Libraries` after the Ace3 block. No individual LibKa0s `.lua` appears.

### The three README/`CLAUDE.md` greps

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md        → 52:Bundles [LibKa0s](…) v1.27.0 (MIT).
$ grep -n 'Bundles \[LibKa0s\]' README.md        → (none)   ← not #59, not #58
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md
                                                 → (none)
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

The badge is the **bare** form, not link-wrapped. `README.md`'s headings were listed
(`grep -n '^## '`) and read: `## Credits` at `:209` holds JetBrains Mono and Open Iconic — external
credit only, no library roll-call, and the intro prose (`:9-28`) names no library either.

---

## 6. Packaging — both checks, run

```
$ for e in .luacheckrc .pkgmeta .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
(no output)

$ for e in .[!.]*; do [ -e "$e" ] || continue; grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .git
```

`.git` is the one entry the packager never sees. The two that MM-A-04 filed are now present with
their justification:

```
.pkgmeta:20    - .claude        # untracked; listed under packaging.md:28
.pkgmeta:21    - .superpowers   # untracked; listed under packaging.md:28
```

MM-A-04 is **closed**.

---

## 7. `layout-§1` — the cap, and why nothing is filed against it

Scope: authored `.lua` the repo tracks, `libs/` and `tests/_kit/` excluded — the denominator
`layout-§1` states, `tests/` included.

```
$ git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn
   3080 settings/Schema.lua        2737 tests/test_window.lua      2708 tests/test_tooltip.lua
   2659 modules/Tooltip.lua        2650 modules/Window.lua         2270 tests/wow_mock.lua
   2083 modules/Aggregator.lua     1824 core/Diagnostics.lua       1748 modules/Export.lua
   1715 modules/Row.lua            1606 tests/test_row.lua         1605 tests/test_aggregator.lua
   1583 tests/test_diagnostics.lua 1573 tests/test_schema.lua      1509 tests/test_export.lua
   1359 tests/test_provider.lua    1004 tests/test_database.lua
```

**15 over the cap, 2 in the band** — the same 15 and 2 the manifest records (`"bandFiles": 2,
"overCapFiles": 15`).

Terminal states, resolved one by one:

```
$ gh issue list --state open --json number,title | grep '1500-line cap'
#27 settings/Schema.lua (3080)   #28 modules/Tooltip.lua (2652)   #29 modules/Window.lua (2644)
#30 modules/Aggregator.lua (2083) #31 core/Diagnostics.lua (1824) #32 modules/Export.lua (1743)
#33 modules/Row.lua (1702)        #34 tests/wow_mock.lua (2266)
```

Eight files, eight open issues naming a seam. The seven mirror suites are covered by register row 4
(`docs/ARCHITECTURE.md:458`). The census is published at `docs/ARCHITECTURE.md:510-558` and its
membership is asserted in both directions by `tests/test_layout_cap.lua`, whose three cases are
green. `layout-§1` says an audit **MUST NOT** re-file against a file in the second or third state,
so MM-A-01 is closed by disposition rather than by a peel.

---

## 8. Shared media and the close-button wrapper

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
core/PerfSetup.lua:219:    -- `NS.DebugLog.MakeCloseButton(frame, api.Hide)` — two arguments onto a
core/CoreSetup.lua:239:    return lib.MakeCloseButton(parent, onClick, addonName)
modules/Export.lua:1067:        local close = NS.MakeCloseButton(bar, function() frame:Hide() end)
```

One wrapper definition (`core/CoreSetup.lua:239`, three-argument, name supplied), one call to the
wrapper (`modules/Export.lua:1067`), and a **comment** at `core/PerfSetup.lua:219` describing the
anti-pattern-#65 shape in order to say the addon does not do it. No direct `lib.` or
`Core.MakeCloseButton` call site. Nothing to file.

Perf-panel `decorate` hook: absent by decision —

```
core/PerfSetup.lua:215   -- NO `decorate`, DELIBERATELY, and its absence is the fix rather than an
```

Private media copy:

```
$ md5sum media/textures/Default.tga libs/LibKa0s/media/textures/*.tga
431b3e17c2fd8778176077a4a193c9cb  media/textures/Default.tga
84f240661c5f0246bb1dbb31aea48668  libs/LibKa0s/media/textures/gradient.tga
… six more, all distinct …
```

No byte-copy of a library asset, and no `media/fonts/` at all — the monospace face is reached
through `NS.MediaFont` (`core/MediaSetup.lua:93-96`). Anti-pattern #63 clean.

One-off marks: the whole-repo census is published at `docs/ARCHITECTURE.md:559-619` (twelve distinct
file/path pairs, with the command and the scope printed above the table) and pinned by
`tests/test_texture_paths.lua`. The one site where the catalog **does** have the mark —
`settings/ColumnBlocks.lua:72-73` — is register row 5, checked in §1a. ConsumableMaster's half of
that parity argument was verified in the sibling repo:

```
$ grep -rn 'ReadyCheck-Ready\|ReadyCheck-NotReady' ../ConsumableMaster --include='*.lua' | grep -v '/libs/'
modules/KCMItemRow.lua:35,36    settings/Category.lua:82,83    settings/StatPriority.lua:108,109
```

All three sites stand, so row 5's trigger has **not** fired.

---

## 9. `options-ui` — the nine checks

- **(a) every page draws a strip.** Pages and their distinct `group` values were read out of
  `settings/Schema.lua`: general 3, windows 1, frame 4, header 4, bars 6, tooltip 6, visibility 3,
  columns 3. `windows`' single-section page still declares a `group` and draws a one-tab strip,
  which `options-ui-§13` requires rather than forbids. The two exempt pages are Profiles
  (AceConfig-drawn) and the landing page (`settings/OptionsSetup.lua:220` — "The landing page. Its
  command list is GENERATED from NS.COMMANDS"). No fallback to an untabbed renderer exists.
- **(b) General's first tab.** `settings/Schema.lua:858-860`:
  ```
  local MASTER_ROWS, MASTER_TAIL = compose("MasterControls", {
      page             = "general",
      group            = L["Master controls"],
  ```
  The canonical rows follow as a subsequence, composed by the library. **No migration is owed**:
  `master.visibility` is a **new** path, not a re-typed boolean, and the runner sits at v13
  (`core/Database.lua:683` — `db.global.schemaVersion = 13`) with `migrations[12]` the newest step — verified by reading the runner, not
  by assuming.
- **(c) class-color companions** — present on every non-exempt color row; the single gap is
  register row 2 (`window.header.bgColor`), accepted.
- **(d) `disabledIf` on a color row** —
  `grep -rn 'disabledIf' settings/` returns **one** line, `settings/Schema.lua:2634`, and it is a
  comment reading `-- options-ui-§17 forbids \`disabledIf\` on a colour row`. Zero real hits.
- **(e) ordering is a drag** —
  `grep -rn 'ScrollUp-Up\|ScrollDown-Up' --include='*.lua' settings/` → **no output**. The shared
  `ReorderList` is used.
- **(f) no hand-written font/border/bar group** — `grep -rn 'LSM30_' settings/` returns four lines,
  two of them comments (`Schema.lua:1523-1524`) and two real rows (`:1565` `LSM30_Statusbar`,
  `:1573` `LSM30_Font`). Both are the **broadcast meta rows** v2.39.0 exempts, re-read at
  `:1563-1579` against §16's five bounds: one row per media kind ✓, own `All surfaces` subgroup with
  a scope-naming label ✓ (`L["Bar texture (all surfaces)"]`, `L["Font (all surfaces)"]`), `onChange`
  through the single seam ✓ (`broadcastBarTexture` / `broadcastFont`), no companions ✓, per-surface
  composed groups behind them ✓ (fourteen of them).
- **(g) one chrome block, not boxed twice** —
  `grep -rn 'InlineGroup\|SimpleGroup' settings/` returns `ColumnBlocks.lua` (a SimpleGroup **per
  block**, inside the scroll) and `Profiles.lua:90` (the AceConfig host container). Neither wraps a
  chrome band. `tests/test_options_panel.lua:897` pins the other half: "The banner's own dropdown is
  parented into the chrome band, NOT added to the scroll".
- **(h) wrapped-strip geometry** — the finding. Library side correct and now testable:
  ```
  libs/LibKa0s/OptionsWidgets.lua:441   local function tabArtHeight()
  libs/LibKa0s/OptionsWidgets.lua:994     O.__tabArtHeight      = tabArtHeight
  ```
  Addon side:
  ```
  $ grep -rn '__tabPlacement\|__tabBand\|__tabArtHeight' tests/
  (no output)
  ```
  Nearest case, re-read: `tests/test_options_panel.lua:760` `test("Panel: every tabbed page opens on
  its first tab and draws a strip", …)`, asserting only `ctx.activeTab` (`:767`) and
  `#(ctx.__tabKids or {}) >= 2` (`:768`). That is MM-A-08.
- **(i) secondary strip / no third level** — Columns' block editor and the Windows page draw their
  strips directly with `H.TabStrip`; no nested strip and no `subgroup` faking one.

**Degradation stubs.** `tests/test_degraded.lua` (27 cases) is green, including *"every NS.Perf
member the addon actually reaches exists on the stub"* and *"the namespace publishes the same seam
members with and without the library"*, plus *"parity: the Options stub carries every public member
of the live Helpers surface"*. The Options stub is the documented exception and says so at
`settings/OptionsSetup.lua:264`: `-- The degradation stub — VALUE-ANSWERING, not message-answering`.
Not a finding.

---

## 10. Documentation shape — measured as a directory listing

```
$ find docs -name '*.md' | grep -vE '^docs/(audits|reviews|superpowers|revendor)/' \
    | grep -vE '^docs/automated-tests/[0-9]' | sort
docs/ARCHITECTURE.md            docs/automated-tests/README.md   docs/automated-tests/RESULTS.md
docs/common-tasks.md            docs/compat-layer.md             docs/data-flow.md
docs/midnight-quirks.md         docs/module-map.md               docs/perf-analysis/README.md
docs/performance.md             docs/schema.md                   docs/scope.md
docs/settings-panel.md          docs/smoke-tests.md              docs/test-cases.md
docs/testing.md
```

Scope: live docs only; the four frozen stores and the dated automated-test bundles are excluded
because `documentation-§3` registers each store as a **directory, once**.

- **(a) Tier 1** — all six present under the canonical names.
- **(b) Tier 2** — measured against the code, in §11 below. Four rows assert a false *Not
  applicable* (MM-A-03).
- **(c) coverage** — all 16 live docs are registered, exactly once, and no row points at a missing
  file. `audits/` and `reviews/` are now rows (`docs/ARCHITECTURE.md:418-419`), closing MM-A-10.
  What fails is the **table shape** (MM-A-13):
  ```
  docs/ARCHITECTURE.md:372  Every `.md` under `docs/` appears in exactly one of the three tables below (`documentation-§3`).
  docs/ARCHITECTURE.md:386  ### Canonical trio (Tier 1)
  docs/ARCHITECTURE.md:394  ### Verification and record
  docs/ARCHITECTURE.md:404  ### Topic detail
  docs/ARCHITECTURE.md:421  ### Tier 2 conditional docs — evaluated at v0.1.0
  docs/ARCHITECTURE.md:427  moved it. This is an evaluation record, not a fourth register table — every doc below that *does*
  ```
  Four tables under a sentence that says three, in an order the amended MUST does not allow, with
  the note the amendment says to delete. The `ARCHITECTURE.md` self-row at `:390` is a **MAY** and
  is filed neither way.
- **(d) non-canonical filenames** — none. No `data-model.md`, `saved-variables.md`, `pipeline.md`,
  `settings-system.md`, `wow-quirks.md`, `slash-commands.md` or `debug-console.md` anywhere under
  `docs/`.
- **(e) retired docs** — `ls docs/complexity.md docs/file-index.md docs/conventions.md docs/pending`
  → four "No such file or directory"; `ls -d docs/perf-runs` → No such file or directory. The
  capture store is `docs/perf-analysis/` with a `README.md` carrying `## Capture index` (`:201`).
- **(f) hub shape** — 773 lines. Section spans measured, not estimated:
  ```
  11- 42 ( 32) ## Overview          43- 66 ( 24) ## Module map      67-117 ( 51) ## Settings schema
 118-158 ( 41) ## Message bus      159-198 ( 40) ## Slash commands  199-243 ( 45) ## Event subscriptions
 244-299 ( 56) ## Taint notes      343-369 ( 27) ## Known limitations
 370-438 ( 69) ## Documentation map   439-619 (181) ## Documented deviations
 620-741 (122) ## Complexity register
  ```
  Every mandated section with somewhere to spill to is **under** the 60-line threshold — that is the
  MM-A-06 MUST closed, and `tests/test_doc_structure.lua` asserts it with the two registers exempted
  (`:56` `local REGISTERS = { ["documentation map"] = true, ["documented deviations"] = true }`,
  `:60` `local SPILL_LINES = 60`). The ~400-line SHOULD is what remains.

---

## 11. Tier 2 triggers, each measured against the code

```
$ grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua      → 28   (trigger: ≥3) ✔ doc shipped
$ wc -l core/Compat.lua                                                   → 761
$ sed -n '72,95p' settings/Slash.lua | grep -c '^    { "'                 → 16   (trigger: ≥8, or any sub-tree)
$ awk '/MSG *= *\{/,/^}/' core/Constants.lua | grep -cE '^\s+[A-Z_]+ *='  → 14   (trigger: >10)
$ wc -l core/Diagnostics.lua                                              → 1824
```

`core/Constants.lua:489` is `Constants.MSG = {`; the 14 names are `METER_UPDATED`, `METER_SESSION`,
`METER_RESET`, `ROSTER_CHANGED`, `ZONE_CHANGED`, `ENTERING_WORLD`, `RESTRICTION_CHANGED`,
`COMBAT_CHANGED`, `PLAYER_STATE_CHANGED`, `PROFILE_CHANGED`, `CONFIG_CHANGED`, `WINDOWS_CHANGED`,
`TEST_MODE_CHANGED`, `DRILLDOWN_CHANGED`. `settings/Slash.lua:72` is `NS.COMMANDS = {`, and `window`
takes `list/new/delete/copy` (`:89-90`), which is a subcommand tree on its own.

The four rows asserting *Not applicable* against those numbers are at `docs/ARCHITECTURE.md:432`,
`:433`, `:436`, `:437` — quoted in `02_DEVIATIONS.md`. The `debug.md` row's own figure ("~1570 lines
of print statements") is 254 lines short of the file it describes.

---

## 12. US English (`localization-§5`) — the published lists, run whole

The `BRITISH` (91 substrings) and `ALLOWED` (30 whole words) lists were copied **whole** out of
`localization-§5`'s canonical list — not a subset, which is the failure the section was amended to
end. `ALLOWED` is removed as whole words first, then `BRITISH` runs as substrings over what remains,
exactly as *How a gate MUST read them* specifies.

**Scope, stated:** `git ls-files` filtered to `.lua`/`.md`/`.toc`, then the four exclusions
`localization-§5` names, each by path: `libs/`, `tests/_kit/` (vendored); `docs/audits/`,
`docs/reviews/`, `docs/superpowers/`, `docs/revendor/`, `docs/automated-tests/<run>/` and
`.superpowers/` (frozen record); `locales/enGB.lua` (does not exist here); and this section's own
quoting document (this bundle is written after the sweep and is not in it). **114 files scanned.**

```
$ python3 <sweep>            # full script printed above; BRITISH/ALLOWED copied verbatim from localization-§5
files scanned: 114
lines with >=1 hit: 830   files with hits: 65
top substrings: colour 481, minimis 107, behaviour 49, centre 41, labelled 35, grey 28,
                honour 18, neighbour 14, judgement 10, cancelling 9, catalogue 6, recognis 5
top files: docs/smoke-tests.md 73, settings/Schema.lua 68, modules/Window.lua 62,
           docs/schema.md 60, tests/test_window.lua 58, docs/test-cases.md 54,
           tests/test_headercontrols.lua 54, tests/test_schema.lua 41,
           modules/HeaderControls.lua 39, tests/test_tooltip.lua 31,
           defaults/Profile.lua 25, modules/Tooltip.lua 25
```

Player-reachable and persisted hits, each re-read and quoted:

```
locales/enUS.lua:213   L["Show minimise"] = "Show minimise"
locales/enUS.lua:230   L["Minimised"] = "Minimised"
defaults/Profile.lua:130           showMinimise    = true,
README.md:109  … the addon master switch, general visibility, master scale and opacity …
README.md:113  | `  - `Bars | Everything drawn inside a cell: the bar's texture, colour mode, …
```

(The two README hits are `colour` inside the settings-panel table's prose at `:109` and `:113`.)

**No gate owns this.** `tests/test_locale.lua` holds eleven cases —
`grep -n 'test("' tests/test_locale.lua` — and none reads a spelling; `grep -n 'BRITISH\|ALLOWED'
tests/*.lua` returns two hits, both unrelated comments (`test_doc_structure.lua:63`,
`test_perfsetup.lua:51`). That is why 830 lines went unremarked through a green suite, a green lint
run and a prior audit.

---

## 13. README and `CLAUDE.md` structure

```
$ grep -n '!\[' README.md
3:![WoW](https://img.shields.io/badge/WoW-Midnight_12.0.7-purple)
4:![Version](https://img.shields.io/badge/Version-0.1.0-blue)
5:![License](https://img.shields.io/badge/License-MIT-orange)
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
7:![Tests](https://img.shields.io/badge/Tests-1534%2F1534_passing-green)
```

Five images, all badges — **no `![Logo]` anywhere** (MM-A-15), and `:4` is a static `Version` badge
matching no canonical template (MM-A-14). For contrast, read in the sibling repos rather than
recalled: `AbsorbTracker/README.md:4` and `BankLedger/README.md:4` both read
`![CurseForge Version](https://img.shields.io/curseforge/v/…)`, and both carry `![Logo](…)` at `:9`.

Section order (`grep -n '^## ' README.md`): What's new `:30` → Screenshots `:58` → Usage `:63` →
How it works `:119` → FAQ `:134` → Troubleshooting `:166` → Issues and feature requests `:198` →
Version History `:203` → Credits `:209`. Order holds. `### Slash commands` (`:67`) and
`### Settings panel` (`:92`) both present; the slash table's 16 rows match `NS.COMMANDS`.
`grep -nE '<[a-z][a-z ]*>' README.md` → no output, so no angle-bracket placeholder can be stripped
by CurseForge.

`CLAUDE.md` — six mandated items in order: H1 `:1`, adherence line `:3-4`,
`## Standards compliance (read first)` `:6-24`, docs pointer list `:41-47`, green-gate line `:49-50`,
provenance `:52`. It is a stub (52 lines), not an agent brief, and points at no
`docs/agent-context.md` (which does not exist).

`DEPENDENCIES.md` — runtime / development / release sections present, a table with an **Evidence**
column per tool, `lua5.1` stated as a hard requirement with `setfenv` as the reason, and per-tool
verification commands.

---

## 14. Sections checked and compliant — recorded so the next run does not re-derive them

| Check | Result |
|---|---|
| `diff -r LibKa0s@v1.27.0/LibKa0s libs/LibKa0s` | empty |
| `diff -r LibKa0s@v1.27.0/testkit tests/_kit` | empty |
| Provenance line | `CLAUDE.md:52` only; 0 hits in `README.md` |
| Standard badge | bare `![Standard](…)`, `README.md:6` |
| README library inventory | none; `## Credits` external only |
| `MakeCloseButton` | one wrapper, one call, one comment |
| Perf `decorate` hook | absent by decision, `core/PerfSetup.lua:215` |
| Degradation stubs | 27 degraded cases green; Options stub is the documented exception |
| `X-Curse-Project-ID` | absent **with** the comment in position, `MultiMeters.toc:13-14` |
| TOC field order / annotations | matches `toc-file-§1`; load-bearing lines annotated |
| `libs\LibKa0s\LibKa0s.xml` | once, `MultiMeters.toc:27` |
| Tier 1 docs | six of six |
| Non-canonical / retired docs | none |
| `## Documentation map` coverage | complete both ways (shape is MM-A-13) |
| `.pkgmeta` | both checks clean but `.git` |
| `.gitattributes` | canonical body, pin + `*.sh` + 20 binaries, tree agrees (0) |
| `.luacheckrc` | canonical `exclude_files`, stanza'd harness global, no blanket ignore |
| `core/LSMPatch.lua` | absent — `library-stack-§9` / #76 clean |
| Private media copy | none (#63 clean) |
| `disabledIf` on a color row | none |
| Reorder art | none; shared `ReorderList` |
| `[status]` title prefixes | none |
| `docs/pending/LEDGER.md` | absent |
| `public-api` | nothing exposed — rule not applicable |
| `preview-mode` | `/mm test` verb present and clears on toggle-off |
| `compat` | `core/Compat.lua` is the only caller of shimmed APIs; no `WOW_PROJECT_ID` branch |
| `performance-§12` | not claimed — harness wired, so the exemption does not apply |
