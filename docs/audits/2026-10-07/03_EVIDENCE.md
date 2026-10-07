# 03 — Evidence (Ka0s Multi Meters, 2026-10-07)

Every `file:line` below was re-read at `a01d1d1` before it was written down, and the quoted text is
what is there. **Every count comes from a recorded command, with its scope stated.** Unless a section
says otherwise, the scope is `git ls-files`, with the exclusions written into the command.

---

## §0 Standard resolution

```sh
RAW=https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master
curl -fsSL $RAW/AUDIT.md -o AUDIT.md
curl -fsSL $RAW/standards/STANDARDS.md -o standards/STANDARDS.md
# Sections list -> 27 files, each curl'd to standards/standards/<file>.md; plus standards/ADDONS.md
for f in standards/standards/*.md standards/STANDARDS.md standards/ADDONS.md AUDIT.md; do
  cmp -s $f ../WowAddonStandards/$f || echo DIFF $f; done          # -> (no output)
git -C ../WowAddonStandards rev-parse HEAD origin/master             # -> f472389… f472389…
```

`head -1 standards/STANDARDS.md` returns `# Ka0s WoW Addon Standard (v2.76.1, 2026-10-07)`. The
first-pass fetches of `anti-patterns.md` and `layout.md` timed out at 60 s. Both were re-fetched in
full and then passed `cmp`.

Repo kind: `dev-copilot-profile` printed `profile=wow kind=addon … reason=toc:## Interface`.

## §M Mechanical checks

### luacheck

`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` exited 0, and its last line was:

```
Total: 0 warnings / 0 errors in 146 files
```

Scope: `.luacheckrc:10` `exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "_dev/" }`.
`tests/` is in scope, and the harness global is in `files["tests/"]` (`.luacheckrc:116`). There is no
top-level `ignore`; `.luacheckrc:12` reads "NO TOP-LEVEL `ignore`, and none is coming back".

### Headless suite

`~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` exited 0, and its last line was:

```
2187 passed, 0 failed, 1 skipped, 2188 total
```

The one `SKIP` is the kit's declared opt-out case: `SKIP  diagnostics contract: an addon that opts
out lands the report and leaves logging off — this addon keeps the default …`. It is disclosed in
`docs/test-cases.md:2424` (`… (skipped: this addon keeps the default …)`). The README badge
(`README.md:7`) reads `Tests-2187%2F2187_passing`, which is right under `testing-§5` ("**MUST NOT**
be folded into either the passed count or the total").

`lua tests/run.lua --list` (bounded) was diffed against the committed `docs/test-cases.md`, with CR
stripped. **The diff is empty.**

### Sighted complexity

`~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`:

```
MultiMeters 1.1.0 — automated tests — 20261007-155311
  complexity  pass  — 0 warnings (fun rate 0.00), 45299 NLOC / 4895 funcs, avg NLOC 8.4, avg CCN 2.5 (max 15), avg tokens 68.2 (recorded, non-gating)
  verdict: green
  record:  newest bundle 20260927-030445 measured abbb29e, 53 commit(s) behind HEAD — its figures describe a tree this one is no longer
exit=0
```

`lizard` was not run over the tree by hand. `git rev-list --count abbb29e..HEAD` returned `53`.
`tests/_kit/framework.lua:20` reads `Kit.VERSION = 37`. `tests/run.lua:359` reads
`{ name = "test_lizard_sighted", dir = "tests/_kit/" },`.

**Drift against the newest bundle** (`docs/automated-tests/20260927-030445/manifest.json`, `"release": "1.1.0"`, sha `abbb29ed…`, `"dirty": false`):

| | bundle | today |
|---|---|---|
| warnings | 0 | 0 |
| max CCN | 15 | 15 |
| functions | 4462 | 4895 |
| `blindFiles` | *(absent: pre-kit-35)* | parity passed (suite `pass`) |
| band files | 22 | 22 (same set) |

The commit `048639e` records the first sighted run: "status pass, warnings 8, maxCcn 39,
blindFiles 0, 4815 functions". Commits `775f921` and `257ff49` (GI-MM-02) brought those functions
under 15. No function crossed a threshold after that.

**Watch list.** `docs/automated-tests/RESULTS.md` → `### Functions lizard warned on` reads "None.".
The band table has 22 rows, every one with an "On notice" disposition and none `Accepted`, so
anti-pattern #53 has nothing to fire on.

### Band census (layout-§1 on-notice band)

```sh
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | awk '$2!="total" && $1>=1000' | wc -l   # -> 22
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | awk '$2!="total" && $1>1500'          # -> (none)
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | wc -l                                              # -> 146
```

Scope: `layout-§1`'s default denominator (`tests/` in, `libs/` and `tests/_kit/` out). No
generated-data exemption is declared. The largest file is `settings/Schema_Compose.lua` at 1410.

### Vendored-library drift (`library-stack-§7`, anti-patterns #45/#48)

The tag is read from `CLAUDE.md:55`: `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).`

```sh
T=$(mktemp -d); git -C ../LibKa0s archive v1.70.0 LibKa0s testkit | tar -x -C $T
diff -r $T/LibKa0s libs/LibKa0s   # -> (empty), rc=0
diff -r $T/testkit tests/_kit     # -> (empty), rc=0
ls $T/LibKa0s | wc -l; ls libs/LibKa0s | wc -l          # -> 37 / 37
grep -c '<Script file=' libs/LibKa0s/LibKa0s.xml          # -> 34
```

Provenance greps: `grep -n 'Bundles \[LibKa0s\]' CLAUDE.md` gives `55:` (one hit).
`… README.md` gives nothing. The `^## (Libraries|…)` grep on `README.md` gives nothing.
`grep -n 'WoW_Addon_Standard' README.md` gives
`6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)`, which is bare.
The numbered-list grep `grep -nE '^[[:space:]]*[0-9]+[.)][[:space:]]' README.md` gives nothing.
The logo grep `grep -nE '!\[[^]]*\]\(media/logos|<img' README.md` gives nothing.

### Line endings (`line-endings`)

```
test -f .gitattributes                                  -> present
grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes -> 26:* text=auto eol=crlf
grep -nE '^\*\.(sh|py) text eol=lf$' .gitattributes      -> 36:*.sh text eol=lf / 37:*.py text eol=lf
grep -c ' binary$' .gitattributes                       -> 20
wc -l < .gitattributes                                  -> 84
diff <(head -n 84 .gitattributes | tr -d '\r') <canonical client-bound body from line-endings-§5>   -> (empty)
tail -n +85 .gitattributes | wc -l                      -> 0   (no appendix)
(e) the AUDIT.md working-tree one-liner, verbatim       -> 0
```

Scope of (e): the whole tracked set, with no exclusions (`git ls-files -z`). The kit gate is
`tests/run.lua:351` `{ name = "test_eol", dir = "tests/_kit/" },`, and it is green.

### Packaging (`packaging`)

Run under `bash`, because zsh does not word-split `$entries`:

```
(a) NOT IGNORED   -> (none)
(b) UNACCOUNTED   -> .git        (exempt)
(c) FALSE CLAIM   -> (none)
```

`.pkgmeta` ignores `.luacheckrc .gitignore .gitattributes .pkgmeta docs tests _dev "*.bak" .claude
.superpowers CLAUDE.md DEPENDENCIES.md media/screenshots media/logos/*.png media/logos/*.jpg`.

### Generators (`layout-§1`)

`git ls-files '*.py' '*.sh'` returns `tests/_kit/run-automated-tests.sh` only. It is vendored, and it
is a runner rather than a generator.

### Re-vendor bundle coverage (`audit-review-history`) — MM-A-19

The `AUDIT.md` script, run verbatim under `bash`:

```
horizon=2026-08-25
vendored: v1.14.0 … v1.68.0 v1.68.1 v1.69.0 v1.70.0      (56 tags)
recorded: v1.14.0 … v1.68.0 v1.68.1                      (54 tags)
UNRECORDED: v1.69.0 v1.70.0
```

`git log --format='%h %s' -- libs/LibKa0s tests/_kit | head -2`:
`1ee53cf chore: re-vendor LibKa0s v1.70.0` and
`824999b chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)`.
`git show --stat` for each, with `libs/` and `tests/_kit/` filtered out, lists `CLAUDE.md | 2 +-`
alone. `ls docs/revendor` ends at `2026-10-04-v1.68.1`.

### Bus (`architecture-§4`, `naming-cheatsheet`)

- `git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -nE '(Send|Register)Message\("Ka0s_'` returns nothing.
- The wire-string grep returns 14 distinct PascalCase tails and one `"Ka0s_MultiMeters_METER_UPDATED"`.
  That hit is `core/Constants.lua:525` `-- into the wire string ("Ka0s_MultiMeters_METER_UPDATED"); the wire strings were`, which is a comment.

### Close button, settings window, reorder art, tooltip

- The `MakeCloseButton(` grep outside `libs/` and `tests/` finds `core/CoreSetup.lua:295`
  `return lib.MakeCloseButton(parent, onClick, addonName)` (the wrapper), `modules/Export_Modal.lua:226`
  `local close = NS.MakeCloseButton(bar, function() frame:Hide() end)` (a call to it), and
  `core/PerfSetup.lua:192` (a comment).
- `SettingsPanel|HideUIPanel|ToggleGameMenu|OpenToCategory` outside `libs/`, `tests/_kit/` and
  comments finds only `settings/OptionsSetup.lua:673`
  `if lib.__IsCombatLocked() or not (cat and cat.GetID and Settings and Settings.OpenToCategory) then`
  and `:677` `Settings.OpenToCategory(cat:GetID())`. That is the page jump to one of the addon's own
  subcategories, combat-gated, by the integer id.
- `ScrollUp-Up|ScrollDown-Up` in `settings/` returns nothing. `OnTooltipShow` in code (outside
  comments) returns nothing.

---

## §R The register, read first (accepted, not counted)

`docs/ARCHITECTURE.md:405` is the header `| Rule | What differs | Why | Decided | Re-check trigger |`.
The rows:

| Line | Rule cell begins | Decided | Trigger evaluated against the tree | Evidence ids |
|---|---|---|---|---|
| `:407` | `` `options-ui-§17` — every color picker carries a "use class color" companion `` | 2026-09-02 | The title bar still has no per-row or per-column surface. **Not fired.** | — |
| `:408` | `` `options-ui-§17` — "one resolver": the class-color lookup is the library's `` | 2026-09-02 | `libs/LibKa0s/Core.lua:344` `function lib.ClassColor(unit)` is still unit-keyed, and Core has no filename overload. **Not fired.** | — |
| `:409` | `library-stack-§8 — "where the addon needs a mark it MUST use the catalog's"` (ColumnBlocks) | 2026-09-08 | `../ConsumableMaster/settings/StatPriority.lua:108` `local INCLUDED_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready"`, `../ConsumableMaster/modules/KCMItemRow.lua:35-36` and `../ConsumableMaster/settings/Category.lua:83-84` all still carry the pair. `libs/LibKa0s/Media.lua:202` `function lib.Icon(addonName, name, vendorPath)` has no tinted state pair. **Not fired.** The cited site is still there: `settings/ColumnBlocks.lua:72-73` `local ENABLED_TEX  = "Interface\\RaidFrame\\ReadyCheck-Ready"` / `local DISABLED_TEX = "Interface\\RaidFrame\\ReadyCheck-NotReady"`. | `MM-A-07` resolves in `docs/audits/2026-09-07/02_DEVIATIONS.md` (1 hit) |
| `:410` | `library-stack-§8 — …` (Tooltip target icon) | 2026-09-23 | The catalog still has no colored `target`, and the tooltip still draws spell icons. **Not fired.** The cited site is still there: `modules/Tooltip.lua:107` `local TARGET_ICON = [[Interface\ICONS\Ability_Hunter_FocusedAim]]`. | `MM-A-25` resolves in `docs/audits/2026-09-23/02_DEVIATIONS.md` (2 hits) |
| `:411` | `options-ui-§15 — the per-instance scale, alpha and lock stay on the instance's own page` | 2026-09-16 | Per-window locks still exist, and the standard defines no coexisting master lock. **Not fired.** The fetched `slash-commands-§8` text names this row as out of that section's reach. | — |

No cited rule has changed in a way that mandates or permits the recorded behavior outright. **All
five are accepted.**

**Issue store:**
`gh issue list --state all --limit 200 --json number,title,state,labels` returned 58 issues. Every
CLOSED issue carries `state:done` or `state:will-not-do`, and every OPEN one carries `state:triaged`.
Each has one `severity:` label. The `state:will-not-do` issues are #53 (Columns `opts.tabs`), #46
(split for the cap, now moot), #25, #16, #15 and #20. These are features or optional library
adoptions, and no rule of the standard is declined, so no register row is owed.

---

## Evidence for each deviation

### §19 MM-A-19 / MM-A-19a

See §M, *Re-vendor bundle coverage*. For the stale stamps:

- `docs/settings-panel.md:29` reads ``the always-shown scrollbar patch belong to `LibKa0s-Options-1.0` (`libs/LibKa0s/Options*.lua`, v1.68.1``.
- `docs/testing.md:597` reads ``| `complexity` | `bash tests/_kit/run-automated-tests.sh --suite complexity` (kit 36: `lizard -l lua -L 1500 …``.
- `DEPENDENCIES.md:35` reads `` … over the sighted shadow `tests/_kit/lizard_sighted.lua` builds (kit 36); … ``.
- The installed kit: `tests/_kit/framework.lua:20` `Kit.VERSION = 37`.

The sweep for other tag stamps, over every tracked live `.md` (excluding `docs/audits`, `docs/reviews`,
`docs/revendor`, `docs/superpowers`, dated `docs/automated-tests/2*` and `docs/perf-analysis/2*`,
and `tests/_kit`), searched for `v1\.(6[89]|70)\.[0-9]`. It returned `CLAUDE.md:55:v1.70.0` and
`docs/settings-panel.md:29:v1.68.1`, and nothing else.

### §23 MM-A-23

The per-match sweep, scope `git ls-files -z ':!libs' ':!tests/_kit' ':!docs/audits' ':!docs/reviews' ':!docs/automated-tests' ':!docs/revendor'`
(the `documentation-§6` frozen-store exclusions; `docs/superpowers/` stays **in**):

```sh
grep -noE "\b(<27 section names>)( §|-|-§ | -§)[0-9]+" | grep -vE -- "-§[0-9]"
# -> core/LifecycleSetup.lua:117:architecture-4
#    docs/ARCHITECTURE.md:503:layout-1        (anchor slug, not a citation)
grep -noE '\b[a-z-]+-§[0-9]+'  | wc -l       # -> 957 citations
# range check of each against `grep -c '^### [0-9]' standards/standards/<file>` -> 0 out of range
grep -nE '§[0-9]+\.[0-9]'                   # -> 2, both "Spec §2.5" in docs/superpowers/plans/2026-08-24-shared-dropdown-and-export-ux.md:1055, :1158
git ls-files '*.lua' ':!libs' ':!tests/_kit' | xargs grep -n '\\194\\167' | wc -l   # -> 0
```

- `core/LifecycleSetup.lua:117` reads `--- core/MultiMeters.lua is the ONLY file that owns one (architecture-4) and`.
- `docs/ARCHITECTURE.md:503` reads `tabulated in [automated-tests/RESULTS.md](automated-tests/RESULTS.md#files-by-layout-1-band), not`.

### §24 MM-A-24

- `docs/ARCHITECTURE.md:14` reads ``Sixty-three non-vendored source files: 1 locale, 20 `core/`, 1 `defaults/`, 26 `modules/`, 15 `settings/`.``
- `docs/ARCHITECTURE.md:45` reads `Every file — all fifty-eight of them — what it owns, what it publishes, what it consumes, plus TOC`.
- `docs/module-map.md:6` reads ``Sixty-three non-vendored source files: 1 locale, 20 `core/`, 1 `defaults/`, 26 `modules/`,``.
- `git ls-files '*.lua' | grep -vE '^(libs/|tests/)' | wc -l` returns 63. Per folder: core 20,
  defaults 1, locales 1, modules 26, settings 15.
- `tests/test_doc_structure.lua:327` reads `test("the hub's file count matches git ls-files", function()`.
  Its matcher is `body:match("([%w%-]+) non%-vendored source files:(.-)%.%s")`, so `:45` is not read.
- `docs/ARCHITECTURE.md:511-512` carries the sentence
  ``…`tests/test_texture_paths.lua` compares it with the tree in both directions. Its three
  `library-stack-§8` declines of a mark the catalog does carry are ratified in the register above.``
  The register's `library-stack-§8` rows are `:409` and `:410`, which is two. `:413` reads
  `**Retired on 2026-10-02: the window's size-grabber pair.**`.
- `docs/ARCHITECTURE.md:444` reads ``**One row is ratified.** The register also carried a row for the drag-to-reorder block list living``
  and `:447` reads `That row was retired on 2026-08-27`.
- `docs/ARCHITECTURE.md:454` reads ``**One row is ratified.** The register also carried a row for a root `TODO.md` ``
  and `:456` reads `That row was retired on 2026-08-11`.
- `settings/Slash.lua:82-83` reads `-- because the generated help index, the settings landing page and the README's`
  / `-- command table all read these strings and nothing else`. `README.md` has no command table.
- `settings/Slash.lua:857` reads `--- verb is live while disabled, and the report lands with logging off.`
  Against it, `docs/debug.md:209` reads `**Running it turns debug logging on for the session** (`debug-logging-§14`, LibKa0s`.

### §27 MM-A-27

- `MultiMeters.toc:1` reads `## Interface: 120100`.
- `core/EnvSetup.lua:88` reads `function NS.Meta(field)`, and `:89` reads
  `    if Env then return Env.GetAddOnMetadata(addonName, field) end` (the library branch).
- `core/EnvSetup.lua:90-91` reads `    if _G.C_AddOns and _G.C_AddOns.GetAddOnMetadata then` /
  `        return _G.C_AddOns.GetAddOnMetadata(addonName, field)`.
- `core/EnvSetup.lua:93-94` reads `    if _G.GetAddOnMetadata then` /
  `        return _G.GetAddOnMetadata(addonName, field)`. **This is the dead rung.**
- `tests/test_envsetup.lua:146` reads `test("EnvSetup: the deprecated bare global is still a live rung, all the way to NS.version",`.
- `settings/Slash.lua:64` reads `--- inline re-spelling would both duplicate the ladder and drop the pre-11.x rung`.
- `core/PerfSetup.lua:94` reads `    -- how a call site quietly dropped the pre-11.x rung. settings/Slash.lua asks`.
- The standard (`compat`) gives the worked cases: "`GetAddOnMetadata` behind
  `C_AddOns.GetAddOnMetadata` in a library-absent stub (the global survives only as the newer
  namespace's member)". The v2.65.0 changelog adds: "the rung both addons carried in
  `core/EnvSetup.lua`".

### §28 MM-A-28

- `git log --oneline -S'minimap.shown' -- settings/ | tail -1` returns
  `e979ef0 MM-16: Rename the minimap row's CLI path to global.minimap.shown`.
- `git merge-base --is-ancestor e979ef0 4c368c4` succeeds, so the rename is in 1.1.0.
  `git rev-parse --short 1.1.0-release^{commit}` returns `4c368c4`.
- `settings/Schema_Compose.lua:659` reads `    minimapPath      = "global.minimap.shown",`.
- `README.md:97` is the 1.1.0 row. Its minimap highlight reads `- New minimap button: left-click
  opens settings, right-click switches Enabled, Locked, Test mode and Show window, and hovering shows
  the version and status`. `grep -n 'minimap.shown\|minimap.hide' README.md` returns nothing.

### §29 MM-A-29

- `DEPENDENCIES.md:98` reads `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .     # the complexity report (release-time)`.
- `docs/automated-tests/README.md:38` reads ``| `complexity` | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | **no — recorded only** | **yes** |``.
- `docs/testing.md:597`, the compliant row, reads ``| `complexity` | `bash tests/_kit/run-automated-tests.sh --suite complexity` (kit 36: …``.
- `DEPENDENCIES.md:35` reads ``| `lizard` | **1.24.0** (pinned) | …``.
- `DEPENDENCIES.md:58` reads `pipx install lizard==1.24.0`.
- `DEPENDENCIES.md:68-69` reads ``Versions are pinned only where a version matters: `lua5.1` is hard, `lizard` is held at 1.24.0`` /
  `because the kit's sighted shadow is built against that release's blind spots, and `.
- The pin's origin: `8d09388 SD-FIN-01: sync docs (git needed by the suite; lizard pinned 1.24.0; test-only exports labeled)`.
- `CLAUDE.md` quotes no `lizard` line (`grep -n lizard CLAUDE.md` returns nothing).

### §30 MM-A-30

- `tests/test_disabled.lua:479` reads `test("Disabled 8: left-click opens the panel and writes nothing, in either state",`.
- `tests/test_disabled.lua:498` reads `    obj.OnClick(obj, "LeftButton")`, and the case drives no other click.
- `grep -rn 'RightButton' tests/test_disabled.lua` returns nothing.
- `tests/test_launchersetup.lua:373` reads `test("Launcher menu: while disabled, everything but Enabled is grayed and inert", function()`.
  Its assertions are the menu texts, `Find("Enabled").enabled`, the grayed entries and `#seen == 0`
  per spied verb. It has no `__svWrites` and no shown-frame read.

### §06 MM-A-06

- `wc -l docs/ARCHITECTURE.md` returns `578`.
- `grep -n '^## \|^### ' docs/ARCHITECTURE.md` gives `317:## Documentation map`,
  `391:## Documented deviations`, `479:### Files over the 1500-line cap`,
  `507:### Hard-coded texture paths` and `514:## Complexity register`.

### §26 MM-A-26

See §M, *Sighted complexity*. The manifest's `complexity` object
(`docs/automated-tests/20260927-030445/manifest.json`) has no `blindFiles` key.

---

## Compliance evidence (selected; the descriptor, not the behavior)

| Claim | Citation (quoted) |
|---|---|
| Events isolated per name | `core/MultiMeters.lua:215` `    local register = NS.SafeRegisterEvent`; `:217` `        register(self, EVENTS[i][1], EVENTS[i][2], rejected)` |
| Rejected record reachable | `core/MultiMeters.lua:214` `    if NS.State then NS.State.rejectedEvents = rejected end`; `core/Diagnostics.lua:224` `    local rejected = NS.State and NS.State.rejectedEvents` |
| Core stub carries the helper | `core/CoreSetup.lua:106` `local function stubSafeRegisterEvent(target, event, handler, rejected)`; `:249` `NS.SafeRegisterEvent     = lib.SafeRegisterEvent     or stubSafeRegisterEvent` |
| Stand-down unregisters, does not gate | `core/LifecycleSetup.lua:62` `    if NS.UnregisterAllEvents then NS:UnregisterAllEvents() end`; `:63` `    if NS.CancelAllTimers then NS:CancelAllTimers() end` |
| Lifecycle sink passed | `core/LifecycleSetup.lua:240` `    debug     = function(tag, message) if NS.Debug then NS.Debug(tag, "%s", message) end end,` |
| Slash sink passed, live verbs from the library | `settings/Slash.lua:344` `    debug   = function(tag, message) …`; `:325` `    liveVerbs = (function()` |
| Diagnostics forms | `settings/Slash.lua:106` `    { "diagnostics", "Write the diagnostics report to the debug console",`; `:802` `    if word == "diagnostics" then` |
| DebugLog stub answers the report | `core/DebugLogSetup.lua:335` `        RunDiagnostics  = function()` |
| Host gate re-armed from Clear | `core/DebugLogSetup.lua:410` `    onClear = function()` |
| Options descriptor names the folder | `settings/OptionsSetup.lua:153` `    addonName     = addonName,`; `:156` `    debug = function(tag, fmt, ...) …` |
| Degraded `enable` route (a) | `settings/Schema_Paths.lua:614` `    writeThrough  = { ENABLED_PATH },` |
| Launcher toggles are the verbs' handlers | `core/LauncherSetup.lua:282` `    setEnabled     = function(on) runVerb(on and "enable" or "disable") end,`; `:284`, `:286`, `:288` (`lock`, `test`, `toggle`); `:266` `    label = L["Ka0s Multi Meters"],` |
| Migration stamp floor and ownership | `defaults/Profile.lua:826` `        schemaVersion = 0,   -- unstamped; never the current version (see above)`; `core/Database.lua:998` `        g.schemaVersion = v + 1` |
| Resize through the seam | `modules/Window_Placement.lua:80-82` `    local wrote = NS.SetByPaths and NS.SetByPaths({` / `{ "window.frame.width",  width },` / `{ "window.frame.height", height },` |
| Logo TGA header | `od -An -tu1 -N18 media/logos/multimeters.logo.128.tga` returns `0 0 2 0 0 0 0 0 0 0 0 0 128 0 128 0 32 8` |
| Disabled-state orientation greps | `Register…` over `git ls-files '*.lua' ':!libs' ':!tests'` (comments excluded) returns 56 sites: one `SafeRegisterEvent` loop plus the module and bus `RegisterMessage` calls. Every one is undone by `UnregisterAllEvents`, the module `UnregisterAllMessages` loop or `NS.BusStandDown`, and `tests/test_disabled.lua`'s "Disabled 3" pins the empty set. |
