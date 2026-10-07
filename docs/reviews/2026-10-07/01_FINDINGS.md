# Findings — Ka0s Multi Meters, full-scope review of 2026-10-07

**Verdict: minor issues, with one High.** With **Merge pets into their owner** ticked, a pet whose source comes before its owner's in a column loses its numbers to the owner's own figures. Out of combat this produces a wrong total and rate, and the window and the export both show it. Everything else is Medium or Low. There are no Critical findings and no `[upstream]` or `[cross-addon]` findings.

**Resolved scope:** the whole repository (`all`), at `a01d1d1` on branch `feat/2026-10-07-review-audit-remediation`, with a clean tree. The measurement covers the whole addon. `libs/` and `tests/_kit/` were checked for byte identity against their source, not reviewed as this addon's code.

**Standards cross-check:** Ka0s WoW Addon Standard **v2.76.1 (2026-10-07)**, fetched with `curl` from `raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md`, along with all 27 section files its Sections list links.

---

## Measurement run (Step 0b, measured today, 2026-10-07)

Every run went through `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded`, from the repo root, with output written to a scratch directory outside the repo. No committed artifact was touched. Interpreter: `lua5.1`. `luajit` is not installed, and `lua5.1` came first in the fallback order anyway.

| Suite | Result | Command and figures |
|---|---|---|
| luacheck | **pass** | `ka0s-bounded luacheck .`: `0 warnings / 0 errors in 146 files`, exit 0 |
| Headless test suite | **pass** | `ka0s-bounded lua5.1 tests/run.lua`: `2187 passed, 0 failed, 1 skipped, 2188 total`, exit 0. The skip is the kit's `diagnostics contract: an addon that opts out lands the report and leaves logging off`, and it is legitimate: this addon keeps the default `enablesLogging` |
| Fresh `--list` inventory | **pass, matches** | `ka0s-bounded lua5.1 tests/run.lua --list > $scratch/list.md`, then `diff <(tr -d '\r' < docs/test-cases.md) <(tr -d '\r' < $scratch/list.md)`: **no output**. Totals row `**Total** \| **2188**`, and the skip is listed with its reason. README badge `Tests-2187%2F2187_passing` agrees with `testing-§5` (a skip is in neither figure) |
| Offline perf runner | **ran** (17 scenarios) | `ka0s-bounded lua5.1 tests/perf.lua`: `refresh20x7` 297237.4 bytes/iter, 8.00 api/iter; `refresh20x7Restricted` 406173.3 bytes/iter; `suspended` 0.0; `spellEventOff` 0.0. These are for orientation only and are not part of the gate |
| Complexity (sighted) | **pass** | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`: `0 warnings (fun rate 0.00), 45299 NLOC / 4895 funcs, avg CCN 2.5 (max 15)`. Kit revision 37 (`tests/_kit/framework.lua:20` `Kit.VERSION = 37`), so the run is sighted, and the console reported **no blind files** |
| `make test` | **not applicable** | no root `Makefile` |
| Vendor sync | **pass** | `diff -rq libs/LibKa0s ../LibKa0s/LibKa0s` and `diff -rq tests/_kit ../LibKa0s/testkit`: **no output** for either. `../LibKa0s` is at tag `v1.70.0`, clean, on `feat/2026-10-07-review-audit-remediation` |
| Cross-addon pass (4 classes) | **clean** | Run from `GIT/` over the eleven rows of `WowAddonStandards/standards/ADDONS.md`, each addon's load list derived from its TOC. **Class 1:** 22 roots, `uniq -d` empty, zero raw `SLASH_*` in loaded source. **Class 2:** one line, `Bus:2 Compat:1 Core:10 DebugLog:19 Env:1 Item:2 Launcher:5 Lifecycle:3 Media:4 Options:28 Perf:14 Pool:3 Schema:2 Slash:19 Widgets:12`. **Class 3:** `diff -rq AbsorbTracker/libs/LibKa0s <each>/libs/LibKa0s` printed nothing for all eleven (159 files in the reference copy, AbsorbTracker). **Class 4:** `## Interface: 120100`, uniform. All eleven `CLAUDE.md` provenance lines read `v1.70.0`. The review brief's baseline (v1.56.0) is a **stale brief, not drift** |

**Committed artifacts that disagree with today's run:**

- `docs/automated-tests/RESULTS.md`: its newest bundle `20260927-030445` measured `abbb29e`, and the runner itself reports it is "53 commit(s) behind HEAD". It records 4462 funcs / 43863 NLOC, against 4895 / 45299 today, and 2092 cases, against 2188 today. That is **stale, not non-compliant**: it is regenerated at release (`/dev-copilot:bump-version`). The watch list (0 warned functions; 22 files in the 1000–1500 band; 0 over the cap) still matches today's figures. The band count was re-derived with `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | tr '\n' '\0' | xargs -0 wc -l | awk '$2!="total" && $1>=1000 && $1<=1500' | wc -l` → **22**, over 146 tracked authored Lua files (`tests/` included).
- `docs/test-cases.md`: identical to the fresh `--list`.
- `docs/performance.md`: its restricted-pass prose quotes `412373.3` bytes. Today's run gives `406173.3`. The doc labels its figures as the closing run's, kept as recorded, so this is a dated figure and not a defect.

**Scratch experiments.** Three findings below were confirmed by running a probe case against a `git archive HEAD` copy of the repo under the session scratch directory. Nothing was written into the repo. The copy's layout-cap cases fail because the copy has no `.git`, and those failures are unrelated to the probes.

---

## High

### F-001: With *Merge pets* on, a pet ahead of its owner in a column loses its numbers to the owner's own cell `[correctness]`

- **Where:** `modules/Aggregator.lua:265-273`. `foldPet` creates the owner's cell from the pet's figures when the owner has none yet (`if cell == nil then setCell(row, statKey, src, nil) return true end`). Then `modules/Aggregator.lua:927-928`, `if isOwn then setCell(row, statKey, src, maxAmount, isCount)`, runs when the owner's own source arrives later. That `setCell` replaces the cell outright: `modules/Aggregator.lua:240` `row.values[statKey] = {`.
- **Problem:** the fold depends on order. Pet after owner sums correctly. Pet before owner is overwritten. Sources arrive in the provider's order for each column, so a pet that out-did its owner in a column is always "before".
- **Impact:** the owner's total and rate silently drop the pet's share. The percent column follows, and so does the export: `Export.SessionConfig` passes the same `mergePets`, `modules/Export.lua:292`. The README's promise that a merged pet's damage only "goes missing until the pull ends" is broken: it stays missing after the pull.
- **Reachability:** any player who ticks General → Behavior → **Merge pets into their owner** (default off, `settings/Schema.lua:1247`). It happens out of combat (the only state the fold runs in), on the Current, Overall and pinned-segment views and in `/mm export`, whenever one of their pets placed above them in any shown column. Pet classes hit it routinely. The Damage column is the obvious case, and so is any column where the owner did less than the pet.
- **Measured:** a probe case built on `tests/test_aggregator.lua`'s helpers used sources `PET 400 → BETA 200 → ALPHA 100` with `mergePets` on. It got `expected 500, got 100` for ALPHA's `DamageDone.total`.
- **Fix direction:** make the own-source write add to a cell that a pet fold created, under the same `Secrets.CanCompare2` and type guards `foldPet` already uses. Add a case that goes red under the current code (`testing-§12`).

---

## Medium

### F-002: The suite covers the pet-before-owner path but never checks the total, so the F-001 bug passes green `[tests]`

- **Where:** `tests/test_aggregator.lua:341-357`, `"A pet's position never moves its owner in the provider order"`. It installs exactly F-001's shape (`src(PET, 400, …)` at index 1 and `src(ALPHA, 100)` at index 3, with `mergePets(inst)`), then asserts only `#result`, the order and `providerIndex` (`assertEqual(result[2].providerIndex, 3, …)`).
- **Problem:** the inventory lists a case over this exact input, but no assertion reads the folded total. The neighbouring total-checking case (`:305`, `"Aggregator sums an attributed pet into its owner out of combat"`) only covers owner-before-pet order.
- **Impact:** the High above passes green under a case whose title suggests the path is covered.
- **Reachability:** only the test inventory. The shipped defect is F-001.
- **Fix direction:** add a separate case that asserts the folded total and rate for the pet-first order. Do not rewrite the existing case (`testing-§12`, `testing-§5`).

### F-003: An under-populated roster is rebuilt on every lookup, not once per refresh, and the comments say the opposite `[perf]` `[naming]`

- **Where:** `modules/Roster.lua:537-541`:
  ```lua
  local function ensure()
      local group = cache.group
      if group and not cache.partial then return group end
      return build()
  end
  ```
  `Roster.Get`, `Roster.IsGroupMember`, `Roster.OwnerOf` and `Roster.LocalGUID` all call `ensure()`. The aggregator calls them several times for each source in each column (`newRow` → `Roster.Get`, `owningMember` → `IsGroupMember` + `OwnerOf`). Two comments describe a different cost: `modules/Roster.lua:405` says the build "is retried on every refresh, four times a second", and `:535` says "Retrying costs one unit walk per refresh".
- **Problem:** while `cache.partial` is set (`GetNumGroupMembers()` reports more members than the unit walk resolved), every lookup does a full unit walk. Each walk calls `UnitExists`/`UnitGUID`/`UnitName`/`UnitClass`/`UnitGroupRolesAssigned` per member, plus the pet probe and a `db.global.roster` rewrite per member.
- **Measured:** a probe counted `UnitGUID` calls during one `Aggregator.Build` of a seven-column window over a three-member group. Complete roster: **3** calls (one walk). Partial roster, with `party2` unresolved: **60** calls (twenty walks). That multiplier grows with sources × columns, and the refresh runs every 0.25 s.
- **Impact:** the per-refresh cost of a window spikes for as long as the roster stays partial. The `Roster.lua` header says this can be a while: "a group whose unit API never fills (a member the client cannot see)". The cost is unbracketed: `rosterBurst` in `tests/perf.lua` measures a complete roster, so no scenario covers the partial case.
- **Reachability:** any grouped player while the unit API lags behind `GetNumGroupMembers`. That happens briefly after every `GROUP_ROSTER_UPDATE` or zone-in, and lasts as long as a member stays unresolvable. It is transient for most players and long-lived in the case the header names.
- **Fix direction:** retry at most once per refresh pass, so the code matches what the comments already promise. Add an offline perf scenario for the partial case (`performance-§9`).

---

## Low

### F-004: Renaming a window to a different case of its own name appends " 2" `[ux]`

- **Where:** `modules/WindowManager.lua:325`, `NS.SetByPath("window.name", uniqueName(newName), cfg.id)`. `uniqueName` (`:187-194`) asks `M.Resolve(base)`, which matches names case-insensitively (`:125-127`), and the window being renamed counts as a collision with itself. The panel's guard, `settings/Windows.lua:290` `if newName == "" or newName == w.name then return end`, catches only an exact match.
- **Measured:** a probe renamed a window to `Raid`, then to `raid`, and the stored name became **`raid 2`**.
- **Impact:** a player fixing a name's capitalization gets a numbered duplicate name instead.
- **Reachability:** any player who changes only the case of a window's name in Windows → Window name.

### F-005: `/mm window copy` cannot name a source window whose name contains a space, and that includes every default window name `[ux]`

- **Where:** `settings/Slash.lua:617`, `local source, target = tail:match("^(%S+)%s+(.+)$")`. Default names are `Multi Meters #%d` (`core/Database.lua:216-217`).
- **Measured:** `/mm window copy Multi Meters #1 Second` printed `No window named 'Multi'.` For a window named `raid 2`, `/mm window copy raid 2 Second` printed `No window named 'raid'.`
- **Impact:** the documented slash route (`WINDOW_USAGE`, `copy <source> <target>`) fails for the common case. The ids `Resolve` would accept are not shown by `/mm window list`. The panel's Copy settings from route works.
- **Reachability:** any player who uses `/mm window copy` with a source window whose name contains a space, including any window still on its default name.

### F-006: `plainTruth` is defined twice, both copies outside `core/Secrets.lua` `[design]`

- **Where:** `modules/Aggregator.lua:446` `local function plainTruth(v)` and `modules/Tooltip.lua:224` `local function plainTruth(v)`. The Tooltip copy also guards against a missing `NS.Secrets`.
- **Problem:** `CLAUDE.md`'s second invariant says "`core/Secrets.lua` is the only file that inspects a value". The truth-test on a possibly-secret boolean is exactly such an inspection, and it lives in two copies that have already drifted apart.
- **Impact:** maintainability. The next change to the secret-boolean rule has to land in two places. Each copy defers to `Secrets.CanAccess`, so neither is wrong today.
- **Reachability:** no runtime effect today.

### F-007: The source-row diagnostics compare `isLocalPlayer` without a guard, and the field-census short-circuits booleans as plain `[correctness]`

- **Where:** `modules/Provider.lua:551` `if src.isLocalPlayer == true then`; `:649` `if localRow == nil and isLocal == true then localRow = src end`; `:676` `local plain = type(value) == "boolean" or not Secrets.IsSecret(value)`. A boolean that passes the check is then turned into a string and used as a table key (`:687-689`).
- **Problem:** the aggregator calls this exact comparison unsafe (`modules/Aggregator.lua` documents that `if src.isLocalPlayer then` "raises the moment that field is secret") and routes it through `plainTruth`. The probes do not. The census walks *every* client field with `pairs(src)`, so a secret boolean on any field would be keyed.
- **Impact:** `docs/data-flow.md` says `isLocalPlayer` stays plain, so today nothing raises. If any sampled field ever arrives as a secret boolean, the probe section raises. Each probe is `pcall`-wrapped (`core/Diagnostics_Identity.lua:159`, `:208`), so the damage is a lost diagnostics section, not a broken session.
- **Reachability:** a player or developer running `/mm debug identity` (or the diagnostics sections that call these probes) during a pull, and only if the client ever ships one of those fields as a secret boolean. Unverified in-client.

### F-008: The drill-down back button was retired but its code still runs on every render `[dead-code]`

- **Where:** `modules/DrillDown.lua:802` `function DrillDown:AcquireBackButton(...)` (labeled `TEST-ONLY TODAY` at `:794`); `:826` `function DrillDown:ReleaseBackButton(window)`, which `modules/Window.lua:1296-1297` calls on **every** `Render`; the `backButtons` lookups in `Exit`/`ExitAll` (`:356`, `:372`); and `BACK_BUTTON_WIDTH`/`HEIGHT` (`:144-145`). `modules/Row.lua` records why it went away: right-click "replaced a Back button drawn above the rows".
- **Census:** `AcquireBackButton` has 1 hit in source (the definition) and 4 in `tests/`. Three cases cover it: `tests/test_drilldown.lua:376`, `:393`, `:405`.
- **Impact:** every refresh pays a lookup for a button that can never exist. Three inventory cases count coverage of behavior the addon no longer ships.
- **Reachability:** no player-visible effect. The cost is one table lookup per render, and the inventory overstates live coverage by three cases.

### F-009: The vehicle pair is registered for every unit and filtered to the player in Lua `[perf]`

- **Where:** `core/MultiMeters.lua:160-161` registers `UNIT_ENTERED_VEHICLE`/`UNIT_EXITED_VEHICLE` through AceEvent, and `:366` `if UNIT_STATE_EVENTS[event] and arg1 ~= "player" then return end` drops every other unit. `docs/midnight-quirks.md` records this as a deliberate filter.
- **Impact:** small and **unverified**, because no bucket brackets this handler. Each group member entering a vehicle costs one dispatch into Lua and an early return.
- **Reachability:** any grouped player, whenever any group member enters or leaves a vehicle. That is rare outside vehicle encounters.
- **Fix direction:** keep it as it is, unless a capture shows a cost. `events-frames-taint-§1`'s unit-filter frame carve-out would allow `RegisterUnitEvent(…, "player")`, but it adds a frame that the `slash-commands-§7` teardown and the mock's registration recording must cover. That outweighs the saving unless a measurement says otherwise.

---

## Upstream findings

None. `libs/LibKa0s` and `tests/_kit` are byte-identical to `../LibKa0s/LibKa0s` and `../LibKa0s/testkit` at `v1.70.0`, and no defect traced into vendored code.

## Checked and cleared (not findings)

- **Disabled state** (`slash-commands-§7`, anti-pattern #85): `core/LifecycleSetup.lua:135-178` runs one latch with two holds. Stand-down calls `UnregisterAllEvents`, `CancelAllTimers`, the module message teardown, the bus stand-down, `WindowManager:Suspend` (which removes each window's `OnUpdate`), `Provider:Suspend` and `Export.CancelSend`. Every module's `OnEnable` returns early while stood down. `Window.New` does not arm `OnUpdate` while stood down (`modules/Window_Lifecycle.lua:163`). The launcher's Show window entry is `gated = true` in the library, so the `WindowManager:Toggle` perf-capture refusal string is reached only under the perf hold, where it is accurate.
- **Secret discipline on the render and data paths:** every arithmetic or comparison site found by grepping meter-value field names in `core/` and `modules/` is behind `Secrets.CanCompare`/`CanCompare2`/`CanAccess` or works on the addon's own counters (`Aggregator` counted cells, `Targets` sums of values already checked accessible, `Format.Duration`/`Percent`).
- **Export:** a staggered send is generation-guarded and cancelled at stand-down. A `TARGET` with no target is refused in the modal (`modules/Export_Modal.lua:624-628`) before `ResolveChannel` can quietly fall back to printing to yourself.
- **Degradation stubs:** `tests/test_surface_parity.lua` pins the Options, Compat/Secrets, Bus, Schema and Slash stubs to their live surfaces.
- **Lint config:** `.luacheckrc` excludes only vendored and frozen paths. The only `212/self` ignores are per file, and there are 5 inline `luacheck: ignore` lines across authored Lua (`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs grep -h 'luacheck: ignore' | wc -l` → 5), with no sprawl.
- **Exported functions with no in-addon caller:** of 306 `function X.Y`/`X:Y` definitions in `core/`, `modules/`, `settings/` and `defaults/`, the census found `AcquireBackButton` (F-008), `Diagnostics.IsFeignTraceArmed`, `WindowManager:MarkAllDirty`, `NS.RegisterSchemaRows`, `Roster.RoleOf`, `NS.WindowSection` and `Helpers.__windowsCtx`. All except `AcquireBackButton` are labeled test-only exports with live semantics (commit `8d09388`). `AcquireBackButton` is reported separately because its *feature* is retired.
