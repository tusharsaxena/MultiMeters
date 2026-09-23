# 03 — Evidence (Ka0s Multi Meters, 2026-09-23)

Every command below ran from the repo root, `/mnt/d/Profile/Users/Tushar/Documents/GIT/MultiMeters`,
at `4aefb58` on `feat/2026-09-23-review-audit-remediation`, with a clean tree. Each `file:line` was
re-read before it was written here, and its quoted text sits beside the citation. Each count gives
the command that produced it, what it covered and what it excluded.

**The default census scope**, per `layout-§1`, is
`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`: **125 files** (58 under the five source
folders, 67 under `tests/`). Where a count uses a different scope, the entry says so.

---

## §0 The standard, resolved

```
curl -fsSL $RAW/AUDIT.md ; curl -fsSL $RAW/standards/STANDARDS.md ; curl -fsSL $RAW/standards/ADDONS.md
# Sections list → 27 files, each fetched from $RAW/standards/standards/<file>.md
head -1 STANDARDS.md  →  # Ka0s WoW Addon Standard (v2.64.0, 2026-09-23)
```

Two independent fetches of the 27 section files were compared with `cmp`, and all 27 were identical.
`grep -c '^### [0-9]' <file>` gives the range bound for each section:

architecture 7 · automated-tests 7 · debug-logging 13 · documentation 9 · events-frames-taint 8 ·
launcher 5 · layout 4 · library-stack 9 · line-endings 7 · localization 5 · options-ui 18 ·
performance 12 · savedvariables 5 · slash-commands 8 · testing 15 · toc-file 5

The other eleven have no numbered subsections.

## §1 Mechanical runs (bounded)

`~/.claude/wow-addon/bin/ka0s-bounded` exists on this machine although it is not on `PATH`. Every run
below went through it by absolute path.

```
~/.claude/wow-addon/bin/ka0s-bounded luacheck .
  Total: 0 warnings / 0 errors in 125 files          (exit 0)
~/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua
  1948 passed, 0 failed, 0 skipped, 1948 total       (exit 0)
~/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
  No thresholds exceeded (cyclomatic_complexity > 15 …)
  Total nloc 40425 · Avg.NLOC 8.2 · AvgCCN 2.4 · Fun Cnt 4126 · Warning cnt 0   (exit 0)
```

- **Lint scope:** `.luacheckrc:10` is
  `exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "_dev/" }`.
  `tests/` is linted, the harness global is declared in `files["tests/"]` (`.luacheckrc:116`), and
  there is no top-level `ignore`. The per-file stanzas are narrow `212/self` ignores.
- **Complexity:** max CCN is **15**, shared by `scanColumn`, `artFor`, `buildMap`, `deathRow`,
  `WindowProto@758-803` and `NS.ValidateSchema@943-960`. Compared with the latest bundle
  `docs/automated-tests/20260916-184449/`:
  - `manifest.json` records `"git": { "sha": "2d38bbd…", "dirty": false }`, `"warnings": 1`,
    `"maxCcn": 19`, `"bandFiles": 23` and `"overCapFiles": 0`.
  - `git rev-list --count 2d38bbd..HEAD` gives **32**.
  - **Drift:** `NS.ValidateSchema` went from 19 to 15 and left the warn list. No function crossed a
    threshold. The band is unchanged at 23 files.
  - The watch list (`docs/automated-tests/RESULTS.md`, one entry) is stale by that one row, and that
    row has one run of history. This is MM-A-26.
- **Suite wiring:**
  - `tests/run.lua:225` `{ name = "test_layout_cap", dir = "tests/_kit/" },`
  - `:242` `{ name = "test_prose", dir = "tests/_kit/" },`
  - `:300` `"test_disabled",`
  - `test_eol` is `{ name = "test_eol", dir = "tests/_kit/" }` at `:316`.
  - `grep -n 'heapBudgetMB\|leakBudgetMB\|caseSeconds\|KA0S_KIT_GUARD' tests/run.lua tests/perf.lua`
    returns nothing, so the kit's default budgets apply and no raised budget owes a row
    (`testing-§15`).

## §2 Vendored LibKa0s (`library-stack-§7`, anti-patterns #45, #48, #59)

```
grep -n 'Bundles \[LibKa0s\]' CLAUDE.md     → CLAUDE.md:53: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).
grep -n 'Bundles \[LibKa0s\]' README.md     → (none)
grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md → (none)
grep -n 'WoW_Addon_Standard' README.md      → README.md:6: ![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)   (bare, not a link)

git -C ../LibKa0s rev-parse v1.55.0         → bb161b730f2691be39a0dfbbe5c66fd7ca5e8db1
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>
diff -r <scratch>/LibKa0s libs/LibKa0s      → (empty, exit 0)
diff -r <scratch>/testkit tests/_kit        → (empty, exit 0)
```

Both payloads are whole and byte-identical to the tag the provenance line names, and the TOC lists
`libs\LibKa0s\LibKa0s.xml` once. The comparison is against the tag, not the sibling's `HEAD`.

**Seam and stub coverage.** The suite's parity and degraded cases pass, among them:

- `parity: the Options stub carries every public member of the live Helpers surface`
- `parity: NS.Compat and NS.Secrets carry every LibKa0s-Compat-1.0 member between them`
- `parity: the bus stub carries the LibKa0s-Bus-1.0 surface, and its record the instance's`
- `Degraded: every NS.Perf member the addon actually reaches exists on the stub`
- `Degraded: the bus stub still hands every receiver a target, untracked`

`core/LifecycleSetup.lua` has a stub for a major no section rules on yet. It answers `Hold`,
`Release`, `Set`, `IsHeld`, `IsDown`, `Holds`, `Reevaluate` and `PrintHolds`, and is a real latch
rather than a no-op.

**Close-button grep (MUST).** Scope: tracked `*.lua` minus `libs/` and `tests/`.

```
git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -n 'MakeCloseButton('
core/CoreSetup.lua:239:    return lib.MakeCloseButton(parent, onClick, addonName)
core/PerfSetup.lua:185:    -- `NS.DebugLog.MakeCloseButton(frame, api.Hide)` — two arguments onto a      (comment)
modules/Export_Modal.lua:226:        local close = NS.MakeCloseButton(bar, function() frame:Hide() end)
```

That is one wrapper and one call to it. Compliant.

## §3 Line endings (`line-endings`)

```
test -f .gitattributes                              → present
grep -n '^\* text=auto eol=\(crlf\|lf\)$'           → 26:* text=auto eol=crlf
grep -nE '^\*\.(sh|py) text eol=lf$'                → 36:*.sh text eol=lf · 37:*.py text eol=lf
grep -c ' binary$'                                  → 20
wc -l .gitattributes                                → 84
diff <(head -84 .gitattributes | tr -d '\r') <canonical client-bound body from line-endings-§5>   → (empty)
tail -n +85 .gitattributes                          → (nothing: no appendix)
(e) the playbook's git ls-files -z … | wc -l, run verbatim   → 0
```

Scope for (e) is the whole tracked set with no exclusions. The result is compliant, and the kit gate
agrees (`PASS  eol: every tracked file carries the terminator .gitattributes declares for it`).

## §4 Packaging (`packaging`)

Run under `bash`: in `zsh` an unquoted `$entries` does not word-split, and the first attempt printed a
false result.

```
(a) NOT IGNORED — (nothing)
(b) UNACCOUNTED — .git            (the one exempt entry)
(c) FALSE CLAIM — (nothing)       (.claude and .superpowers both exist)
git ls-files '*.py' '*.sh'        → tests/_kit/run-automated-tests.sh   (vendored; not a generator)
```

## §5 LOC cap (`layout-§1`)

```
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | sort -n | awk '$1>=1000'
```

This returns **23** files between 1033 and 1500 lines and **none over 1500**. The top of the list is
`1500 tests/test_provider.lua`, `1494 tests/test_window_header.lua`,
`1490 tests/test_row.lua` and `1469 modules/Row.lua`. The census matches:
`docs/ARCHITECTURE.md:594` reads "Nothing is over the cap today." No generated-data exemption is
declared, so nothing was subtracted.

## §R The deviation register, read first (`audit-review-history`, three MUSTs)

Rows are at `docs/ARCHITECTURE.md:516-520`. Each was checked for (1) whether the cited rule still says
it, (2) whether the trigger has fired, and (3) whether the evidence ids resolve.

| Row | (1) Rule still says it | (2) Trigger | (3) Evidence | Verdict |
|---|---|---|---|---|
| `debug-logging-§8` (repeating summary suppressed) | §8 still says "one gated line" per flow event, and §9 still caps the buffer at 500. No rule for a pass repeating unchanged on a timer exists (`grep -n -i 'repeat\|heartbeat\|unchanged' debug-logging.md` finds nothing of the kind). | Not fired | `core/DebugLogSetup.lua:49` "-- The steady-state sink — one line per CHANGE, not one line per pass" resolves | **Accepted**, decided 2026-08-21 |
| `options-ui-§17` (`window.header.bgColor`, no companion) | `options-ui.md:412` "Every color-picker control … MUST be accompanied by a way to say *use the class color*" | Not fired: the title bar has no per-row or per-column surface | `window.columnHeader.bgColorMode` is present in `settings/Schema_Compose.lua:116` | **Accepted**, decided 2026-09-02 |
| `options-ui-§17` (`NS.ClassRGB` second reader) | `options-ui.md:420` "**One resolver.** The lookup is the library's" | Not fired: `libs/LibKa0s/Core.lua:344` `function lib.ClassColor(unit)` is still unit-keyed, with no filename overload | `core/Namespace.lua:68` `function NS.ClassRGB(classFilename)` | **Accepted**, decided 2026-09-02 |
| `library-stack §8` (ReadyCheck pair) | `library-stack.md:328` "Where the addon needs a mark, it **MUST** use the catalog's" | Not fired: `../ConsumableMaster/settings/StatPriority.lua:108` `local INCLUDED_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready"` and `modules/KCMItemRow.lua:35` still stand | `settings/ColumnBlocks.lua:72` `local ENABLED_TEX  = "Interface\\RaidFrame\\ReadyCheck-Ready"`. `MM-A-07` resolves in `docs/audits/2026-09-07/02_DEVIATIONS.md` (1 hit) | **Accepted**, decided 2026-09-08. The Rule cell is malformed, which is MM-A-23 |
| `options-ui-§15` (master Lock frame is a view) | `options-ui.md:361` "…the per-instance scale/alpha/lock stay on the instance's own page — the two are different settings and **MUST NOT** be conflated." | Not fired | `modules/WindowManager.lua:584` `function M:SetLocked(locked)`, `:600` `function M:IsLocked()`, `modules/Window.lua:393` `function WindowProto:RefreshUpvalues()`, and `core/Database.lua:50` "-- v14 carries the addon-wide `master.locked` onto every window's own lock" | **Accepted**, decided 2026-09-16. Out of `slash-commands-§8`'s reach |

**The issue store.**

```
gh issue list --state all --limit 200 --json number,title,state,labels   → 52 issues, exit 0
```

- Every issue carries exactly one `state:` label and exactly one `severity:` label.
- No title carries a `[status]` prefix, and there is no `docs/pending/`.
- Closed issues carrying an open-state label (**MM-A-16**):
  - `4	CLOSED	enhancement,state:triaged,severity:medium	Wire up the shipped bar texture`
  - `21	CLOSED	enhancement,state:triaged,severity:medium	Promote the Columns page's drag-to-reorder block list to LibKa0s`
  - `24	CLOSED	bug,state:untriaged,severity:high	Spec icon is missing for every raid row but the local player's`
- `state:will-not-do` issues: #46, #25, #20, #16 and #15. #25, #16 and #15 decline features. #20
  declines an optional major, and nothing requires adopting `LibKa0s-Item-1.0`. #46 declined
  splitting for the cap. Its closure predates the 2026-09-09 peels, which put every file under
  1500, so there is no live deviation for it to ratify. **No missing register row.**
- Open `state:triaged`: #52 defers `LibKa0s-Schema-1.0`. v2.64.0 requires no adoption, so this is
  not a deviation.

## §19 MM-A-19 — re-vendor bundle coverage (the playbook's commands, verbatim)

```
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)      → 2026-08-25
vendored (CLAUDE.md tag at each `git log --since=$horizon -- libs/LibKa0s` commit, sort -uV):
  v1.18.0 v1.18.1 v1.19.0 v1.20.0 v1.21.0 v1.22.0 v1.23.0 v1.24.0 v1.25.0 v1.26.0 v1.27.0 v1.28.0
  v1.29.0 v1.31.0 v1.32.0 v1.33.0 v1.34.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0
  v1.42.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.55.0          (34)
recorded (folder tag, else 01_DELTA.md line 1):
  v1.15.0 v1.25.0 v1.30.0 v1.31.0 v1.32.0 v1.33.0 v1.34.0 v1.55.0                          (8)
grep -vxF -f recorded vendored | wc -l                             → 28
```

- The bare-dated bundles were read, not guessed:
  - `docs/revendor/2026-08-25/01_DELTA.md:1` `# 01 — Delta: MultiMeters vs LibKa0s v1.15.0`
  - `docs/revendor/2026-09-03/01_DELTA.md:1` `# 01 — Delta: LibKa0s v1.24.0 → v1.25.0`
  - `docs/revendor/2026-09-12/01_DELTA.md:1` `# 01 — Delta: LibKa0s v1.29.0 → v1.30.0`
- `docs/revendor/2026-09-23-v1.55.0/01_DELTA.md:1` reads `# 01 — Delta: LibKa0s v1.54.2 → v1.55.0`,
  which is a single-step delta, not a span.
- **Outside the check's scope, named for completeness:** `d2169d4` bumped `CLAUDE.md` to `v1.54.2`
  and re-vendored `tests/_kit/` only. Its message says "The library bytes are identical to v1.53.0",
  so `-- libs/LibKa0s` does not select it, and v1.54.2 is **not** in the 28.
- No `## Documented deviations` row covers the gap.

## §20 MM-A-20 — event registration (`events-frames-taint-§1`)

Scope: tracked `*.lua` minus `libs/`, `tests/_kit/` and `tests/`, which is the addon's own
registrations.

```
git ls-files '*.lua' ':!libs' ':!tests/_kit' | grep -v '^tests/' | xargs grep -nE 'Register(Unit)?Event|RegisterMessage|RegisterBucketEvent'
grep -c 'RegisterEvent("' core/MultiMeters.lua      → 21
```

Every game-event registration is in `core/MultiMeters.lua`, and no other file registers one:

- `:124` `local function registerIfValid(target, event, handler)`
- `:127` `if not utils.IsEventValid(event) then return false end`
- `:128` `target:RegisterEvent(event, handler)` — outside any `pcall`
- `:131` `return pcall(target.RegisterEvent, target, event, handler)` — reached only when
  `C_EventUtils.IsEventValid` is absent
- `:149` `self:RegisterEvent("PLAYER_ENTERING_WORLD",  "OnEnteringWorld")` — the first of 21 bare calls
- `:153-154` "Registered even on a client without C_RestrictedActions: an event that never fires
  costs nothing"
- `:157` `self:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", "OnRestrictionChanged")`
- `:195` `registerIfValid(self, "PLAYER_IS_GLIDING_CHANGED", "OnPlayerStateChanged")` — the only
  probed event
- `:213` `self:RegisterEvent("DAMAGE_METER_RESET",                   "OnMeterReset")`

`grep -rn 'rejected\|badEvent\|unknown event' core/ modules/ settings/` returns only
`core/Namespace.lua:273-275`, which is the **bus** record's stand-up (`local replayed, rejected =
NS.busRecord:StandUp()`) and has nothing to do with game events. No record of rejected event names
exists.

**The disabled-state census, for completeness.** The same grep finds bus registrations in 13 modules
and targets. The unregistration grep:

```
git ls-files '*.lua' ':!libs' ':!tests/_kit' | grep -v '^tests/' | xargs grep -nE 'Unregister(All)?Events?|UnregisterMessage|UnregisterBucket|CancelTimer|CancelAllTimers|:Cancel\(|SetScript\("OnUpdate", *nil\)'
core/LifecycleSetup.lua:62:    if NS.UnregisterAllEvents then NS:UnregisterAllEvents() end
core/LifecycleSetup.lua:63:    if NS.CancelAllTimers then NS:CancelAllTimers() end
modules/Window.lua:1404 / :1417   self.frame:SetScript("OnUpdate", nil)
settings/ColumnBlocks.lua:212     ctx.mmReorder:Cancel()
```

Each module's messages are unregistered by `standDownModules` (`m:UnregisterAllMessages()`), and
the anonymous targets by `NS.BusStandDown()`. `tests/test_disabled.lua` `Disabled 3` asserts
`assertEqual(afterN, 0, "still registered: " …)` on the mock's registration set after
`NS.SetByPath("enabled", false)`. The disabled state is **compliant**.

## §21 MM-A-21 — the 1.0.1 tag

```
git log -1 --format='%h %ad' --date=short 1.0.1-release   → 71e5742 2026-09-11
git show --stat 1.0.1-release                             → "Dummy commit to trigger a new build" · README.md | 1 +
git show 1.0.1-release:MultiMeters.toc | grep '^## Version' → ## Version: 1.0.0
MultiMeters.toc:5                                          → ## Version: 1.0.0
README.md:103  | 1.0.0 | 2026-09-10 | - First published release — …   (top row; there is no 1.0.1 row)
grep -o '"release": "[^"]*"' docs/automated-tests/*/manifest.json → "0.1.0" (×2), "1.0.0" (×1); others null
```

## §3a MM-A-03 — Tier 2 triggers

- `docs/ARCHITECTURE.md:475` `| slash-dispatch.md | Not applicable | **18 verbs in NS.COMMANDS.** …`
  The trigger is "eight or more", or any subcommand tree, and `window` is one:
  `docs/ARCHITECTURE.md:217` `| window | list · new <name> · delete <name> · copy <source> <target> |`.
- `docs/ARCHITECTURE.md:476` `| message-bus.md | Not applicable | **14 distinct messages** …` The
  trigger is "more than ten". The 14 are in the table at `:147-162`.
- `docs/ARCHITECTURE.md:477` `| profiles.md | Not applicable | settings/Profiles.lua is 133 lines
  hosting AceDBOptions-3.0's own tree …`. The trigger is a profile control in the options UI. The
  row itself describes one.
- `tests/test_docmap.lua:15` "WHAT IT DELIBERATELY DOES NOT DO: judge whether a trigger has fired."
- `docs/` holds no `slash-dispatch.md`, `message-bus.md` or `profiles.md` (`git ls-files 'docs/*.md'`).

## §16 MM-A-16 — see §R above.

## §18 MM-A-18 — `minimis`

Scope: the tracked set minus `libs/`, `tests/_kit/` and the frozen stores (`docs/audits`, `reviews`,
`revendor`, `superpowers`, `automated-tests/<run>`, `perf-analysis/<run>`).

```
git ls-files | grep -vE '^(libs/|tests/_kit/|docs/(audits|reviews|revendor|superpowers|automated-tests/[0-9]|perf-analysis/[0-9]))' \
  | xargs grep -niE 'minimis' | wc -l        → 154   (22 files, tests/prose_waivers.lua included)
grep -c '= { minimis = true }' tests/prose_waivers.lua   → 25
```

- `locales/enUS.lua:214` `L["Show minimise"] = "Show minimise"`
- `locales/enUS.lua:231` `L["Minimised"] = "Minimised"`
- `README.md:50` "Seven controls can sit in the title bar — close, minimise, lock, settings, segment,
  reset, export —"
- `defaults/Profile.lua:130` `showMinimise    = true,`
- `defaults/Profile.lua:148` `minimised       = false,`
- `tests/prose_waivers.lua:24` "-- So this waiver is a DEBT, not a decision, …"
- `tests/prose_waivers.lua:30` `["README.md"] = { minimis = true },`
- The gate result: `PASS  prose: no authored file carries a British spelling from localization-5's
  published list`.

## §8 MM-A-08

```
grep -rn '__tabPlacement\|__tabBand\|__tabArtHeight\|tabArtHeight' tests/*.lua   → (none)
libs/LibKa0s/OptionsTabs.lua:691:  function O.__tabPlacement(widths, available, gap, top, rowPitch)
```

## §22 MM-A-22 — TOC annotations

- `MultiMeters.toc:51` `core\CoreSetup.lua`, with no comment.
  - `core/CoreSetup.lua:55` `NS.LIBKA0S_MISSING = "The LibKa0s library is missing from this installation of Ka0s Multi Meters " ..`
  - `core/DebugLogSetup.lua:229` `if not lib then`
  - `core/DebugLogSetup.lua:253` `local missing = NS.LIBKA0S_MISSING .. ", so the debug console window is unavailable."`
    This is at file scope inside the library-absent branch.
  - `core/LauncherSetup.lua:109` `local missing = NS.LIBKA0S_MISSING .. ", so there is no minimap button and no broker plugin."`
- `MultiMeters.toc:58` `core\PerfSetup.lua` and `:59` `core\DebugLogSetup.lua`, with no comments.
  - `core/PerfSetup.lua:96` `version = NS.Version(),` is a file-scope read inside `lib:New({ … })`.
  - The file's own header, `core/PerfSetup.lua:18`: "This is a HARD constraint: move this file
    above Namespace and captures go anonymous."
- `MultiMeters.toc:134` `settings\OptionsSetup.lua`, with no comment.
  - `settings/General.lua:61` `local H = NS.Helpers or {}`
  - `settings/General.lua:257` `if NS.RegisterOptionsPage then`
  - The same capture appears at `settings/Windows.lua:62`, `settings/Columns.lua:63` and
    `settings/ColumnBlocks.lua:48`.
- For contrast, `MultiMeters.toc:37-40` (EnvSetup), `:44-45` (MediaSetup), `:52-56` (LifecycleSetup),
  `:60-64` (LauncherSetup) and `:128-131` (Schema_Paths) are properly annotated.

## §23 MM-A-23 — citation notation (`documentation-§6`)

Scope: the tracked set minus `libs/`, `tests/_kit/` and the frozen stores.

```
# (1) retired dotted form — the standard's own command
grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=libs --exclude-dir=_kit --exclude-dir=audits \
  --exclude-dir=reviews --exclude-dir=automated-tests --exclude-dir=revendor --exclude-dir=.git | wc -l   → 2
  (both in docs/superpowers/plans/2026-08-24-shared-dropdown-and-export-ux.md, a frozen bundle; not filed)

# (2) space form in a standard citation
… | xargs grep -nE 'library-stack §8'   → 4 lines
  docs/ARCHITECTURE.md:519  | library-stack §8 — "where the addon needs a mark it MUST use the catalog's" | …
  docs/ARCHITECTURE.md:671  … **Register row above** — `library-stack §8`, ratified 2026-09-08 …
  docs/ARCHITECTURE.md:679  asserts that the two `ColumnBlocks.lua` rows have a `library-stack §8` row …
  tests/test_texture_paths.lua:48  local COLUMNBLOCKS_RULE = "library-stack §8"

# (3) §-less form, over the 27 section basenames:  <name>-<digits>
… | xargs grep -nE '\b(<27 basenames>)-[0-9]+\b' | wc -l   → 23
  minus docs/test-cases.md ×4 (generated from the vendored kit's own case names)
  minus docs/ARCHITECTURE.md:615 (an anchor slug)                                   → 18 authored
  core/LifecycleSetup.lua :5 :13 :80 :113 :118 :126 :145 :279   modules/Export.lua :812
  tests/prose_waivers.lua :3 :21   tests/test_disabled.lua :1 :16 :27 :382 :386 :445 :471

# (4) the literal text \194\167 in a comment
… | xargs grep -nF '\194\167' | wc -l   → 35   (18 files)
  e.g. core/MultiMeters.lua:135  -- THE LATCH DECIDES WHETHER REGISTRATIONS EXIST AT ALL (slash-commands-\194\1677).
       settings/Slash.lua:257    -- … (launcher-\194\1671).
       tests/run.lua:299         -- it exists to catch (testing-\194\16712).
```

The 18 files in (4) are:

- `core/`: `Database.lua`, `LauncherSetup.lua`, `MultiMeters.lua`
- `modules/`: `Aggregator.lua`, `DrillDown.lua`, `Feign.lua`, `Provider.lua`, `Roster.lua`,
  `Visibility.lua`, `WindowManager.lua`
- `settings/`: `Schema_Compose.lua`, `Slash.lua`
- `tests/`: `run.lua`, `test_lifecycle.lua`, `test_perfsetup.lua`, `test_schema_paths.lua`,
  `test_slash.lua`, `test_window_placement.lua`

Every well-formed `filename-§N` in the same scope is in range, checked against §0's bounds (the
highest cited are `options-ui-§18`, `testing-§12` and `debug-logging-§12`).

## §24 MM-A-24 — inventory

```
for d in core modules settings defaults locales; do git ls-files "$d/*.lua" | wc -l; done
  → core 19 · modules 22 · settings 15 · defaults 1 · locales 1   (= 58)
```

- `docs/ARCHITECTURE.md:14` "Fifty-seven non-vendored source files: 1 locale, 18 `core/`, 1
  `defaults/`, 22 `modules/`, 15 `settings/`."
- `docs/ARCHITECTURE.md:45` "Every file — all fifty-eight of them — …"
- `docs/module-map.md:6` "Fifty-eight non-vendored source files: 1 locale, 19 `core/`, …"

## §25 MM-A-25 — texture declines

Scope: tracked `*.lua` minus `libs/` and `tests/`, the same scope as the hub's own census.

```
git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/' | xargs grep -nE '("|\[\[)Interface\\' | wc -l   → 15
```

- `modules/Tooltip.lua:107` `local TARGET_ICON = [[Interface\ICONS\Ability_Hunter_FocusedAim]]`
- `modules/Window.lua:645` `grip:SetNormalTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up]])`
- `modules/Window.lua:646` `grip:SetHighlightTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight]])`
- `libs/LibKa0s/Media.lua:103` `"move", "resize", "fullscreen-enter", …`
- `libs/LibKa0s/Media.lua:136` `"person", "people", "target", "shield",`
- `ls libs/LibKa0s/media/icons` includes `resize.tga` and `target.tga`.
- `docs/ARCHITECTURE.md:667` "…the second site where the catalog **does** have a candidate —
  `target`. A considered decline, not an oversight…". The row is shaped `File | Path | Disposition`,
  with no Decided date and no re-check trigger.
- The register (`:514-520`) has no row for either decline.

## §6 MM-A-06 — hub shape

```
wc -l docs/ARCHITECTURE.md → 762
grep -n '^## \|^### ' docs/ARCHITECTURE.md
  11 Overview · 43 Module map · 76 Settings schema · 133 Message bus · 188 Slash commands ·
  246 Event subscriptions · 293 Taint notes · 350 The segment selector · 394 Known limitations ·
  427 Documentation map · 500 Documented deviations (592 Files over the cap · 621 Hard-coded texture paths) ·
  682 Complexity register · 718 Load order
```

The mandated sections with a spill target run 32, 33, 57, 55, 58, 47 and 57 lines, all under 60.
The two register sections run 73 and 182.

## §D The docs shape (`documentation-§3`)

```
git ls-files 'docs/*.md' | grep -vE '^docs/(audits|reviews|superpowers|revendor|investigations)/' \
  | grep -vE '^docs/(automated-tests|perf-analysis)/[0-9]'      → 18 files
```

Each of the 18 appears once in the four tables (`:450`, `:462`, `:479`, `:490`); the
`ARCHITECTURE.md` self-row is a MAY. No dangling row. No non-canonical Tier 1 or Tier 2 filename,
and no retired doc. `docs/perf-analysis/20260909-014604/` carries `report.md`, `dump.json` and
`ANALYSIS.md`.

## §L Launcher, README, TOC icon

- `core/LauncherSetup.lua:189` `label = L["Ka0s Multi Meters"],`
- `core/LauncherSetup.lua:192` `minimap = minimapTable,`
- `settings/Schema_Compose.lua:658` `minimapPath      = "global.minimap.hide",`
- `python3` read of the header of `media/logos/multimeters.logo.128.tga` → `type 2 w 128 h 128 bpp 32`
- `README.md:4` `![CurseForge Version](https://img.shields.io/curseforge/v/1690082)` and
  `README.md:7` `![Tests](https://img.shields.io/badge/Tests-1948%2F1948_passing-green)`
- `docs/test-cases.md:2217` `| **Total** | **1948** |`
