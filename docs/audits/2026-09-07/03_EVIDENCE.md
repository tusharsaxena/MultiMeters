# 03 — Evidence (Ka0s Multi Meters, 2026-09-07)

Every citation below was re-read at the line given and the cited text is quoted beside it. Every
count is produced by a recorded command whose **scope** is stated. Nothing here is re-typed from an
earlier bundle or from memory.

---

## 0. Mechanical checks — run, with scope

### 0.1 Lint

```
$ cd /mnt/d/Profile/Users/Tushar/Documents/GIT/MultiMeters && luacheck .
…
Total: 0 warnings / 0 errors in 45 files
```

**Scope:** whole repo minus `.luacheckrc`'s `exclude_files` — `libs/`, `tests/`, `docs/audits/`,
`docs/reviews/`, `_dev/`. So `core/`, `defaults/`, `locales/`, `modules/`, `settings/` = 45 files.

### 0.2 Headless suite

```
$ lua tests/run.lua
…
1496 passed, 0 failed, 0 skipped, 1496 total
```

**Scope:** every `tests/test_*.lua`. Excludes `tests/perf.lua` (run separately) and the vendored
`tests/_kit/` harness itself.

### 0.3 Offline perf

```
$ lua tests/perf.lua ; echo "exit=$?"
Ka0s Multi Meters — offline perf  (v0.1.0, label 'offline')
20 group members, 7 columns, throttle 0.25s, 200 events per burst

scenario                  iters     ms/iter   api/iter   bytes/iter
refresh20x7                 300     1.03564       8.00     310158.1
refresh20x7Restricted       300     1.31502       8.00     412373.3
throttleBurst                 1    24.71900       8.00     387789.0
throttleIdle                300     0.00067       0.00          0.0
drillOpenClose              300     0.02850       1.00      13098.2
refreshWhileDrilled         300     0.06651       1.00      19906.2
rosterRebuild               300     0.89665       8.00     328572.5
rosterBurst                   1    18.16000       8.00     334351.0
rosterCached                300     0.79838       8.00     310136.1
applyConfig                 300     0.15998       0.00      47696.3
probeOverheadOff            300     0.78082       8.00     310135.8
probeOverheadOn             300     0.75058       8.00     310140.9
suspended                   300     0.05383       0.00       5202.3
exit=0
```

**Scope:** 13 offline scenarios. Exit 0 means every allocation assertion passed. This is the
evidence for **MM-A-11**.

### 0.4 Complexity — the standard's invocation, verbatim

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
…
!!!! Warnings (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100) !!!!
      24     16    185      1      27 ]@270-296@./core/Database.lua
      19     17    193      1      30 ]@372-401@./core/Database.lua
      24     16    170      1      26 ]@659-684@./core/Database.lua
      35     25    272      1      42 reportDeathDating@648-689@./core/Diagnostics.lua
      20     17    143      0      24 reportFeignRoster@1652-1675@./core/Diagnostics.lua
      58     36    422      2     102 scanColumn@1439-1540@./modules/Aggregator.lua
      20     18    153      0      34 DrillDown@395-428@./modules/DrillDown.lua
      38     27    366      4      66 Export.ChatLines@535-600@./modules/Export.lua
      38     16    254      0      66 onPrintToChat@1427-1492@./modules/Export.lua
      41     26    283      0      59 Feign.Prune@227-285@./modules/Feign.lua
      15     19    135      3      20 Format.DeathTime@646-665@./modules/Format.lua
      30     24    208      1      51 onClick@322-372@./modules/HeaderControls.lua
      63     20    378      0     118 build@249-366@./modules/Roster.lua
      59     30    478      0      81 Cell@646-726@./modules/Row.lua
      43     19    387      0      77 Cell@1155-1231@./modules/Row.lua
      29     19    198      2      54 eventColumns@1859-1912@./modules/Tooltip.lua
      47     26    411      2      72 (anonymous)@1961-2032@./modules/Tooltip.lua
      39     20    326      0      63 Tooltip@2335-2397@./modules/Tooltip.lua
      21     23    203      1      38 Visibility.ShouldShow@239-276@./modules/Visibility.lua
      57     24    442      0     102 WindowProto@312-413@./modules/Window.lua
      88     18    757      5     133 place@1277-1409@./modules/Window.lua
      54     28    417      2      96 NS.ReorderableBlocks@215-310@./settings/ColumnBlocks.lua
      38     23    224      1      61 doDebug@434-494@./settings/Slash.lua
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
     31773       8.1     2.5       63.1     3276           23      0.01    0.03
```

**Scope:** whole repo except `./libs/*` and `./tests/_kit/*`. So `tests/*.lua` (including
`tests/wow_mock.lua`) **is** counted, exactly as the standard's invocation intends. Not narrowed,
not re-thresholded, no extra flag.

**Drift, versus the newest committed bundle** `docs/automated-tests/20260825-103437/manifest.json`,
which reads `"complexity": { … "warnings": 19, "maxCcn": 31, "nloc": 26531, "functions": 2884 … }`:

| | Recorded (2026-08-25) | Measured (2026-09-07) |
|---|---|---|
| CCN warnings | 19 | **23** |
| Max CCN | 31 | **36** |
| Total nloc | 26531 | **31773** |
| Functions | 2884 | **3276** |

New over the line since that bundle, with the reading `performance-§10` asks for:

- `NS.ReorderableBlocks` CCN 28 (`settings/ColumnBlocks.lua:215-310`) — **genuine control flow**: a
  drag state machine with pick-up, carry, insertion-index and clamp branches.
- `doDebug` CCN 23 (`settings/Slash.lua:434-494`) — **verb dispatch**, a chain of word comparisons.
- `Window.place` CCN 18 (`modules/Window.lua:1277-1409`) — **dense defaulting/guarding**; a long run
  of `x = cfg.x or D.x` anchor arithmetic, each `or` scored as a decision.
- `reportFeignRoster` CCN 17, and the three unnamed `core/Database.lua` migration bodies at
  17/16/16 — **defaulting and guarding** in migration steps.
- `onPrintToChat` CCN 16 (`modules/Export.lua:1427-1492`) — channel/recipient guarding.
- `scanColumn` rose 31 → **36** (`modules/Aggregator.lua:1439-1540`) — mixed; the secret-value
  guards are defaulting, the per-column stat branches are real flow.

**The watch list versus this.** `docs/automated-tests/RESULTS.md:30` reads verbatim:

> `Current as of [`20260809-195454`](20260809-195454/), the v0.1.0 release run.`

and its *Functions over threshold* table reads `**None.** `lizard` reports 0 warnings and a maximum
CCN of 15`. Both are false against the code today. Its band table cites
`RESULTS.md:65` — `` | 1000–1500 (on notice) | `settings/Schema.lua` | 1371 | `` — and
`RESULTS.md:66` — `` | 1000–1500 (on notice) | `modules/Window.lua` | 1232 | ``. Evidence for
**MM-A-02**.

**No `Accepted` entry anywhere in the watch list** — the file states so itself at the end of its
band table (*"No entry in either table is carried as a bare **Accepted**"*), so `anti-patterns` #53's
three-release shelf-life rule has nothing outstanding — there is no accepted-entry backlog here, the
finding is staleness. `git log --oneline -- docs/automated-tests/RESULTS.md` returns three commits
(`84558e5` 2026-08-25, `b81f514`, `c445ec1`). `git show 84558e5 --stat -- docs/automated-tests/RESULTS.md`
is **`1 file changed, 1 insertion(+)`** — the newest run row was prepended and nothing else moved;
`git show 84558e5:docs/automated-tests/RESULTS.md` still reads *"Current as of `20260809-195454`"* at
`:30`. The run table is being maintained by the runner; the watch list beneath it has not been
re-authored since the release run.

### 0.5 File sizes (MM-A-01)

```
$ wc -l core/*.lua defaults/*.lua modules/*.lua settings/*.lua locales/*.lua | sort -rn | head -8
  30443 total
   3069 settings/Schema.lua
   2652 modules/Tooltip.lua
   2644 modules/Window.lua
   2058 modules/Aggregator.lua
   1743 modules/Export.lua
   1726 core/Diagnostics.lua
   1702 modules/Row.lua
```

**Scope:** shipped addon source only — `core/`, `defaults/`, `modules/`, `settings/`, `locales/`.
Excludes `libs/`, `tests/` and `docs/`. Seven files over `layout-§1`'s 1500 MUST cap.

### 0.6 Line endings (MM-A-05)

```
$ grep -n -F -e '* text=auto eol=crlf' -e '*.sh text eol=lf' .gitattributes
26:* text=auto eol=crlf
34:*.sh text eol=lf

$ grep -c ' binary$' .gitattributes
20

$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
21
```

**Scope:** every tracked file (`git ls-files`), with `binary`-marked files skipped by the
`text = unset` test, files with no `\n` skipped, and the JSON/binary over-count of the pre-v2.28.1
command removed. **Reported as one rolled-up number, never a file list** — the fix is
`git add --renormalize .` plus a re-checkout. This repo has no earlier frozen audit bundle, so
there is no older number sitting beside this one to reconcile.

`.gitattributes:1-13` is the canonical collection header; `:15-25` the client-bound rationale;
`:26` the pin; `:28-33` the `*.sh` rationale; `:34` the carve-out; `:36+` the binary block. The
file is **not** the `*.sh`-only near-miss `line-endings-§1` names.

### 0.7 Packaging (MM-A-04)

```
$ for e in .luacheckrc .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
NOT IGNORED — .claude
NOT IGNORED — .superpowers

$ for e in .[!.]*; do [ -e "$e" ] || continue
    grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .claude
UNACCOUNTED — .git
UNACCOUNTED — .superpowers

$ du -sh .superpowers .claude ; find .superpowers -type f | wc -l
2.4M	.superpowers
0	.claude
90
```

`.git` is the one entry the packager never sees and needs no row. `.claude` and `.superpowers` do.
`.pkgmeta:5-18` quoted in full:

```
ignore:
  - .luacheckrc
  - .gitignore
  - .gitattributes
  - .pkgmeta
  - docs
  - tests
  - _dev
  - "*.bak"
  # Only the .tga logo is loadable at runtime; WoW cannot read .png or .jpg at all. …
  - media/logos/*.png
  - media/logos/*.jpg
```

### 0.8 Vendored Ka0s library drift — both diffs empty

Provenance, `CLAUDE.md:52`, quoted:

> `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.25.0 (MIT).`

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md README.md
CLAUDE.md:52:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.25.0 (MIT).
```

One hit, in `CLAUDE.md`, none in `README.md`. Not anti-pattern #58, not #59.

Sibling repo present at `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s`; `v1.25.0` resolves.
Diffed against **that tag**, not `HEAD`:

```
$ git -C .../LibKa0s archive v1.25.0 LibKa0s testkit | tar -x -C /tmp/lk
$ diff -r /tmp/lk/LibKa0s   .../MultiMeters/libs/LibKa0s   ; echo rc=$?
rc=0
$ diff -r /tmp/lk/testkit   .../MultiMeters/tests/_kit     ; echo rc=$?
rc=0
```

Both empty. No **#45** drift and no **#48** partial vendoring — every module of the ship folder is
present, including the ones this addon does not wire (`Item.lua`, `OptionsScroll.lua`).
`tests/_kit/run-automated-tests.sh` is present and executable (`-rwxrwxrwx`).

### 0.9 README / `CLAUDE.md` one-line greps

```
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries|Credits)' README.md
209:## Credits

$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

`README.md:6` is the **bare** badge form — not `[![Standard](…)](…)`. `README.md:209`'s `## Credits`
body (`:211-213`) credits JetBrains Mono and Open Iconic and explicitly says both *"ship inside the
bundled LibKa0s payload"* — external credit, not a bundled-library inventory. The intro prose
(`:9-28`) carries no library roll-call.

`README.md:7`, quoted: `![Tests](https://img.shields.io/badge/Tests-1487%2F1487_passing-green)` —
against 1496/1496 measured in 0.2. Evidence for **MM-A-09**.

### 0.10 Issue store and the deviation register

```
$ gh issue list --state all --limit 200 --json number,title,state,labels
```

26 issues. Every one carries a `state:` label and a `severity:` label; **no `[status]` title
prefix** on any (anti-pattern #62 clear). `docs/pending/` does not exist. Terminal
`state:will-not-do`: **#15**, **#16**, **#20**. None declines a *standard rule* — #20's body reads
*"MultiMeters reads `C_DamageMeter` and the group roster … there is no item domain at all"*, which
is inapplicability of `LibKa0s-Item-1.0`, not a rule declined. So no missing register row is owed
by the issue store, and the inverse rule (`documentation-§3`, a `will-not-do` with no row) is
**not** triggered here.

`docs/ARCHITECTURE.md:700-756` — the four **ratified, accepted** rows, each with Rule, Decided and
Re-check trigger. Recorded as accepted, **not** counted toward the MUST tally, and none cites a rule
the standard has since changed:

1. `debug-logging §8` — throttled steady-state summary line. Decided **2026-08-21**.
2. `options-ui §17` — `window.header.bgColor` ships without a class-colour companion.
   Decided **2026-09-02**. *(This is why the §17 companion sweep reports four of five, not a gap.)*
3. `options-ui §17` — `NS.ClassRGB` stays a second `RAID_CLASS_COLORS` reader for GUID/classFilename
   rows. Decided **2026-09-02**.
4. `options-ui §15, §16` — composed blocks absent from `NS.Schema` on a library-less install.
   Decided **2026-09-02**.

Two further rows are recorded as **retired on their own trigger** (the reorder widget, 2026-08-27;
root `TODO.md`, 2026-08-11), which is the register being maintained rather than accumulating.

---

## 1. Evidence per deviation

### MM-A-01 — see 0.5.

`RESULTS.md:65-66` still bands two of the seven at 1371 and 1232.

### MM-A-02 — see 0.4.

Bundle list, for the "predates two runs" claim:

```
$ ls docs/automated-tests/
20260809-194203  20260809-195454  20260825-021705  20260825-103437  README.md  RESULTS.md
```

`RESULTS.md:30` names `20260809-195454` as the watch list's basis. `ls docs/automated-tests/*/ANALYSIS.md`
returns only `docs/automated-tests/20260809-195454/ANALYSIS.md` — evidence for **MM-A-02a**; both
2026-08-25 manifests carry `"release": null`, so this is `automated-tests-§5`'s SHOULD.

### MM-A-03 — the five triggers, measured against the code

**`slash-dispatch.md`.** `settings/Slash.lua:72` — `NS.COMMANDS = {`. Counted structurally:

```
$ sed -n '72,175p' settings/Slash.lua | grep -c '^    {'
16
```

Sixteen rows: `help config list get set reset resetall debug perf version lock test toggle window
export` (+1). The `window` verb carries `list/new/delete/copy`, a subcommand tree. Trigger is
"**eight or more** commands, **or any** subcommand tree" — fired on both limbs.
`docs/ARCHITECTURE.md:693` says `| `slash-dispatch.md` | Not applicable | **16 verbs in
`NS.COMMANDS`.** …` — the row states the number that fires the trigger and then answers *Not
applicable*.

**`message-bus.md`.** `core/Constants.lua:489` — `Constants.MSG = {`. Fourteen distinct message
constants read at `:493-533`: `METER_UPDATED`, `METER_SESSION`, `METER_RESET`, `ROSTER_CHANGED`,
`ZONE_CHANGED`, `ENTERING_WORLD`, `RESTRICTION_CHANGED`, `COMBAT_CHANGED`, `PLAYER_STATE_CHANGED`,
`PROFILE_CHANGED`, `CONFIG_CHANGED`, `WINDOWS_CHANGED`, `TEST_MODE_CHANGED`, `DRILLDOWN_CHANGED`.
Trigger is "**more than ten**". `docs/ARCHITECTURE.md:694` says `| `message-bus.md` | Not applicable
| **14 distinct messages** …`.

**`compat-layer.md`.** `wc -l core/Compat.lua` → **761**. `docs/ARCHITECTURE.md:695` is the register
itself flagging it: `| `compat-layer.md` | **Re-measure — the trigger now fires** | …` and closing
*"Raise the doc, or re-argue the trigger, through `/wow-addon:standards-audit`; it is not this
register's call to make."* This audit is that call: the trigger — *"`core/Compat.lua` carries
**addon-specific** shims beyond what `LibKa0s` supplies"* — is met by the eight `C_DamageMeter`
shims alone, which no library supplies. Raise the doc.

**`profiles.md`.** `settings/Profiles.lua:112` — `NS.RegisterOptionsPage(PAGE, L["Profiles"], Build)`
— and `:75` registers AceDBOptions' table. A profile control **ships in the options UI**, which is
the trigger verbatim. `docs/ARCHITECTURE.md:697` answers *Not applicable* on the different ground
that the addon adds no profile semantics.

**`debug.md`.** `docs/ARCHITECTURE.md:698` states the surface itself: *"This addon's own surface is
`/mm debug diag`, `/mm debug recap` and `/mm debug identity` — `core/Diagnostics.lua`"*. That is
three debug surfaces **beyond** the LibKa0s console, which is the trigger. `wc -l
core/Diagnostics.lua` → **1726** (the row's own estimate of "~1570" is itself now 156 lines stale).

### MM-A-04 — see 0.7.

### MM-A-05 — see 0.6.

### MM-A-06 — hub shape

```
$ wc -l docs/ARCHITECTURE.md
787 docs/ARCHITECTURE.md
$ grep -n '^## ' docs/ARCHITECTURE.md
11:## Overview          77:## Module map          101:## Settings schema
152:## Message bus       193:## Slash commands      233:## Event subscriptions
304:## Taint notes       409:## The segment selector 452:## Known limitations
636:## Documentation map 700:## Documented deviations 756:## Load order
```

Section spans, by subtraction: *Known limitations* 452→636 = **184**; *Taint notes* 304→409 = 105;
*Event subscriptions* 233→304 = 71; *Overview* 11→77 = 66. The four the spill rule names by name —
*Module map* 24, *Settings schema* 51, *Message bus* 41, *Slash commands* 40 — are all under the
threshold and are **not** part of this finding. Shape reported; arithmetic not argued.

### MM-A-07 — one-off mark where the catalog has the glyph

`settings/ColumnBlocks.lua:58-61`, quoted verbatim:

```lua
-- The same two textures ConsumableMaster's priority list wears, so a player who
-- runs both reads one glyph vocabulary rather than two.
local ENABLED_TEX  = "Interface\\RaidFrame\\ReadyCheck-Ready"
local DISABLED_TEX = "Interface\\RaidFrame\\ReadyCheck-NotReady"
```

Catalog entries that answer the same question, from `ls libs/LibKa0s/media/icons/`:
`circle-check.tga`, `confirm.tga`, `ban.tga`, `cancel.tga`. `:62` — `local HANDLE_ICON = "segment"`
— shows the same file correctly drawing from the catalog for the drag handle, so the seam is
already wired and only these two paths bypass it.

Whole-repo sweep for other one-offs, **scope `core/ modules/ settings/ defaults/`, excluding
`libs/` and `tests/`**:

```
$ grep -rn 'Interface\\\\' --include='*.lua' core/ modules/ settings/ defaults/ | grep -v AddOns
modules/Export.lua:1092,1093,1579,1580   Interface\Buttons\WHITE8x8
settings/ColumnBlocks.lua:60,61          Interface\RaidFrame\ReadyCheck-*
modules/Tooltip.lua:712                  Interface\Buttons\WHITE8X8
```

`WHITE8x8` is a solid-fill primitive, not a mark, and the catalog has no equivalent — not a finding.
`SetAtlas` hits are `modules/HeaderControls.lua:252` and `modules/Window.lua:1383`, both rungs of a
documented art ladder below `NS.Icon`, not replacements for it.

### MM-A-08 — the missing case

Library side is correct. `libs/LibKa0s/OptionsWidgets.lua:423-428`, quoted:

```lua
--- How far apart two rows of tabs sit: the UNSELECTED tab art's own height, so a wrapped row is
--- FLUSH with the one above it rather than separated by the empty strip along each button's top.
…
local function tabArtHeight()
  if measuredArtH then return measuredArtH end
```

— unselected atlas (`TAB_ATLAS[false][1]`, `:436`), cached in `measuredArtH` (`:438-440`).
`:601-602` records the same discipline for the width measurement.

Addon side: `tests/test_options_panel.lua:630-638`, quoted:

```lua
test("Panel: every tabbed page opens on its first tab and draws a strip", function()
    …
        assertEqual(ctx.activeTab, L[firstTab], page .. ": opens on its first tab")
        assertTrue(#(ctx.__tabKids or {}) >= 2, page .. ": drew a strip")
```

That asserts the strip exists, not that its geometry is selection-invariant.
`grep -rn 'wrap\|Wrap' tests/test_options_panel.lua` returns **no hits** — no case exists. Widest
page today is six tabs (`bars`, `tooltip`), so nothing wraps yet and no user can reach it.

### MM-A-09 — see 0.9.

### MM-A-10 — the map, and what it does not name

`docs/ARCHITECTURE.md:636-639` states the map's own contract, quoted:

> `Every `.md` under `docs/` appears in exactly one of the three tables below (`documentation-§3`).`
> `**A store gets one row; its dated bundles get none.**`

Store rows present: `superpowers/` and `revendor/` (`:680-681`). `grep -n 'audits'
docs/ARCHITECTURE.md` → **no hits**. Every live `.md` under `docs/` is covered exactly once and no
row dangles — verified by listing `docs/**/*.md` minus the dated bundles against the three tables.

### MM-A-11 — see 0.3, plus the issue text

Issue **#17**, `bug` / `state:untriaged` / `severity:medium`: *"Both allocation ceilings in
`tests/perf.lua` are breached on master"*. `docs/automated-tests/20260825-103437/manifest.json`
records `"perf": { "status": "fail", … }`. Today's run (0.3) exits 0.

### MM-A-12 — the two `LSM30_*` rows

```
$ grep -rn 'LSM30_Font\|LSM30_Border\|LSM30_Statusbar' settings/
settings/Schema.lua:1554:        values = lsmValues("statusbar"), dialogControl = "LSM30_Statusbar",
settings/Schema.lua:1562:        values = lsmValues("font"), dialogControl = "LSM30_Font",
```

**Scope:** `settings/` only; `libs/` excluded. `settings/Schema.lua:1553-1567` quoted in part:

```lua
        path = "window.barTexture", …  page = "frame", group = L["General"], subgroup = L["All surfaces"],
        label = L["Bar texture (all surfaces)"],
        …  onChange = broadcastBarTexture,
        path = "window.font", …        label = L["Font (all surfaces)"],
        …  onChange = broadcastFont,
```

Two broadcast metas, not a block. The fourteen real groups are composed —
`grep -n 'compose("' settings/Schema.lua` returns lines 847, 945, 968, 1003, 1044, 1094, 1121,
1168, 1215, 1258, 1287, 1325, 1372, 1417.

---

## 2. Compliance evidence (claims made in `01` and in `02`'s compliant table)

- **Master controls.** `settings/Schema.lua:847-849`, quoted:
  `local MASTER_ROWS, MASTER_TAIL = compose("MasterControls", {` / `page = "general",` /
  `group    = L["Master controls"],`. The closing button pair is `settings/Schema.lua:936` —
  `NS.MasterControlsAfterGroup = MASTER_TAIL` — wired as the group's `afterGroup` hook.
  Canonical labels declared at `:865-872`: `Enable Multi Meters`, `General visibility`,
  `Master scale`, `Master alpha`, `Lock frame`, `Debug console`; resets at `:881` and `:891`.
- **No migration owed for `General visibility`.** The dropdown's stored path is the **new**
  `master.visibility` (`settings/Schema.lua:860`); no pre-existing boolean lived there, so no
  stored value changed type. The runner exists and is current — `core/Database.lua:683`,
  `db.global.schemaVersion = 13`, dispatched by the `while g.schemaVersion < CURRENT_DB_VERSION`
  loop at `:695-697`.
- **Close button.** `core/CoreSetup.lua:239`, quoted:
  `return lib.MakeCloseButton(parent, onClick, addonName)` — the one wrapper, name supplied. Sole
  call site `modules/Export.lua:1067`: `local close = NS.MakeCloseButton(bar, function() frame:Hide() end)`.
  `core/PerfSetup.lua:206-212` documents the absent `decorate` hook and names the exact anti-pattern
  it avoids (`NS.DebugLog.MakeCloseButton(frame, api.Hide)` — two arguments, no name).
- **`X-Curse-Project-ID`.** `MultiMeters.toc:13-14`, quoted:
  `# X-Curse-Project-ID / X-Wago-ID are deliberately absent: the addon is not published yet, and a`
  `# placeholder ID here would make the packager upload to somebody else's project.`
- **TOC positions.** `MultiMeters.toc:38-41` names `core/Namespace.lua`'s file-scope version
  resolution as what `core/EnvSetup.lua`'s position protects; `:45-46` names `Constants.FONT_MONO`
  as what `core/MediaSetup.lua`'s position protects; `:58-59` explains why
  `core/Diagnostics.lua` is *not* load-bearing; `:86-88` explains `settings/General.lua` first.
- **Media seam.** `core/MediaSetup.lua:27-30` states the addon's own first vararg is what is passed,
  and why a hand-typed constant would not do.
- **Degradation stubs.** `tests/test_degraded.lua` asserts, among 23 cases,
  *"every `NS.Perf` member the addon actually reaches exists on the stub"*, *"the options stub
  publishes every Helpers member the page files touch"*, and *"the addon still enables end to end
  with no library"* — all green in 0.2.
