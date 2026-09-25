# Findings — Ka0s Multi Meters, full-scope review of 2026-09-23

**Verdict: blocking issues** — three High findings on normal-install paths: *Always show yourself* does
nothing on the default profile once the group is bigger than the window; the addon's off switch can be
bypassed from its own settings panel; and every channel export goes through a deprecated global whose
removal would silently turn "sent to raid" into "printed to yourself". No Critical findings and no
`[upstream]` findings.

Reviewed at `4aefb58` on branch `feat/2026-09-23-review-audit-remediation`, whole repository (not a diff).
Standard cross-check: **Ka0s WoW Addon Standard v2.64.0 (2026-09-23)**, fetched verbatim with `curl` from
`raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md`. All 27 section
files linked from its Sections list were fetched too.

---

## Measurement run (Step 0 — measured today, 2026-09-23)

`ka0s-bounded` is not on `PATH` in this shell. It is present at `~/.claude/wow-addon/bin/ka0s-bounded`,
and every run below went through it by that full path, so the `timeout 900` fallback was not needed.
Output was written to a scratch directory outside the repo. No committed artifact was touched.

| Suite | Result | Command (repo root) |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 125 files | `~/.claude/wow-addon/bin/ka0s-bounded luacheck .` |
| Headless test suite | **pass**: 1948 passed, 0 failed, 0 skipped, 1948 total | `~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua` |
| Fresh `--list` inventory | **pass**: 1948 cases. After CR-normalisation it is byte-identical to the committed `docs/test-cases.md`. The README badge reads `1948/1948` | `… lua5.1 tests/run.lua --list > <scratch>/list.md` |
| Offline perf runner | **ran**, exit 0, 15 scenarios. `refresh20x7` 303438.1 B/iter, 1.31 ms/iter. `refresh20x7Restricted` 412373.3 B/iter. `probeOverheadOff`/`On` 303415.8 / 303420.9 B/iter. `feignTraceAbsent`/`Off` 71544.1 / 71544.1 B/iter. `suspended` 0.0 B/iter | `… lua5.1 tests/perf.lua` |
| lizard | **pass**: 4126 functions, 40425 NLOC, avg CCN 2.4, **0 warnings**. Max CCN 15, reached by 10 functions (none above) | `… lizard -l lua -x "./libs/*" -x "./tests/_kit/*" . > <scratch>/lizard.txt` |
| `make test` | **skipped**: there is no `Makefile` in the repo | n/a |
| Vendor sync | **pass**: `diff -rq` is empty for both pairs | `diff -rq libs/LibKa0s ../LibKa0s/LibKa0s` · `diff -rq tests/_kit ../LibKa0s/testkit` |
| Cross-addon (4 classes) | **pass, all four clean**, run over the **ten** siblings on disk (the roster now includes AuraMaster). Slash roots: 20 across 10 addons, zero duplicates, zero raw `SLASH_*` in TOC-loaded source. Vendored minors: one line agreed by all ten (`Bus:1 Compat:1 Core:7 DebugLog:12 Env:1 Item:1 Launcher:1 Lifecycle:1 Media:3 Options:23 Perf:12 Pool:3 Schema:1 Slash:14 Widgets:9`). Payload bytes: `diff -rq AbsorbTracker/libs/LibKa0s <each>/libs/LibKa0s` is empty for all ten (AbsorbTracker is the reference). `## Interface:` is `120100`, uniform | the four commands in the review brief's *cross-addon pass*, scoped to each TOC's load list |

**Scratch reproductions (not committed).** Three failing headless cases confirm the Highs and Mediums.
They were written to the scratch directory and run through a copy of `tests/run.lua` with its root
pinned and its suite list replaced. The cases:

- *untick Test mode while disabled* printed `windows shown while disabled after test-mode on/off: 1 / 1` (F-002).
- *`/mm toggle` during a perf suspend* printed `windows shown during perf suspend after /mm toggle: 1 / 1` (F-004).
- *default-profile alwaysShowSelf* printed `default window: maxRows=0 alwaysShowSelf=true visible=10 kept=20 self-in-view=false` (F-001).
- *window created while disabled* left an OnUpdate armed (F-005).

**Committed artifacts that disagree with today's run:**

- `docs/automated-tests/RESULTS.md` (run `20260916-184449`) reports 1884 tests and a max CCN of 19, with
  `NS.ValidateSchema` on the watch list. Today's run has 1948 tests, a max CCN of 15 and no warned
  function. The report is **stale, not wrong**: it is regenerated at release (`automated-tests-§3`).
- `docs/automated-tests/20260916-184449/perf.json` records `suspended` at 5202.3 B/iter. Today's run
  measures 0.0. It also records `"version":"0.1.0"` (see F-013).
- `docs/performance.md:289` says both feign arms measured **71224.1** B/iter. Today both measure
  **71544.1** (see F-015).
- The **cross-addon baseline** in the review brief (2026-09-07: nine addons, ten majors, `## Interface: 120007`) has
  moved: there are now ten addons, fifteen majors and `120100`. The move is **uniform** across the
  collection, so it is not a finding. It is recorded here so the next reviewer diffs against today's
  line and not the stale one.

**Census scopes used below.** LOC figures use the default scope,
`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, which covers 125 files and includes `tests/`. Under
that scope nothing is over the 1500-line cap (`layout-§1`) and 23 files sit in the 1000–1500 band.
Four of those are worth naming: `modules/Row.lua` at 1469 lines, `modules/Window.lua` at 1424,
`tests/test_provider.lua` at exactly 1500, and `tests/test_window_header.lua` at 1494. The
runtime-behaviour claims (event registrations, slash roots) use the TOC-derived load list.

In-client checks are deliberately absent from this block. They are in `03_SMOKE_TESTS.md`.

---

## High

### F-001 — *Always show yourself* does nothing on the default profile `[design]` `[ux]`

- **Where:** `modules/Aggregator.lua:1289-1314` (`Aggregator.ApplyRowLimit`): `local cap = tonumber(rowsConfig and rowsConfig.maxRows) or 0` … `if cap <= 0 or cap > Const.MAX_ROWS then cap = Const.MAX_ROWS end` … `if #rows <= cap then return rows end`. The render cut is at `modules/Window.lua:1206-1207` (`for i = 1 + offset, #entries do` / `if drawn >= layout.maxRows then break end`). The visible count comes from `rowCapacity`, `modules/Window.lua:324-335`.
- **Problem:** the self-pin runs against `rows.maxRows`. On the shipped default of `0` ("as many as fit"), `ApplyRowLimit` uses `MAX_ROWS` (40) as its cap. The window then draws only the `layout.maxRows` rows its height allows, which is 10 at the default 220 px. The pin therefore never sees the cut that actually drops the player. It also ignores the scroll offset.
- **Impact:** in any group larger than the window, a player ranked below the visible rows is not on screen, even though the "Always show yourself" box is ticked. That box ships ticked (`defaults/Profile.lua:281`, `alwaysShowSelf = true`).
- **Reachability:** any player on a default profile, in any raid, or in any group larger than their window's visible row count, who is not in the top rows. Measured in the scratch reproduction: 20 rows with the player at rank 15, a default window showing 10 rows, and the player not in view.
- **Coverage asleep:** `tests/test_aggregator.lua:411-424` (*"alwaysShowSelf spends the last visible slot on the player"*) exercises only an explicit `maxRows = 3`. The inventory claims the behaviour is covered, but nothing covers the default configuration.

### F-002 — The disabled addon re-shows its windows when *Test mode* is unticked `[design]` `[ux]`

- **Where:** `modules/WindowManager.lua:659` (`applyTestMode(enabled, not enabled and not (NS.Perf and NS.Perf.suspended))`) and `:630` (`if keepShown then inst:Show() end`). `modules/Window_Placement.lua:231-242`: `WindowProto:Show()` sets `forcedShow` and calls `self.frame:Show()` without asking `NS.ShouldShow`. The row is at `settings/Schema_Compose.lua:794-801` (`["state.testMode"]`, whose `set` calls `M:SetTestMode(v)`).
- **Problem:** the "keep windows on screen after leaving test mode" guard tests only `Perf.suspended`. That is the **perf** hold alone: `libs/LibKa0s/Perf.lua:426` answers it with `lc:IsHeld(HOLD)`. It never asks the latch (`NS.IsStoodDown()`), so leaving test mode while the `disabled` hold is taken calls `WindowProto:Show()`, which is the one show path that skips the ladder.
- **Impact:** a window appears on screen while the addon is disabled, and it stays up. Every event is unregistered, so no later edge re-runs the ladder that would hide it. This breaks the rule that every frame is "hidden, and stays hidden … enforced at the source" (`slash-commands-§7`, anti-pattern #85). No meter data is read (`Provider.GetColumn` answers `"suspended"`) and no SavedVariables write happens, so the damage is a stuck, empty window the player has to close by hand.
- **Reachability:** any player who turns the addon off during a session and then ticks and unticks General → Master controls → *Test mode*. That panel is the documented surface that survives the disabled state. Reproduced headless: `1 / 1` windows shown.
- **Coverage gap:** `tests/test_disabled.lua` *"Disabled 5: every frame that was shown is hidden"* covers the moment of disabling, but nothing covers a later show path. `tests/test_lifecycle.lua:288` covers the same `SetTestMode(false)` path, but only under a **perf** suspend.

### F-003 — Channel exports call a deprecated global from a feature module, and would fail silently to "print to self" `[deprecated-api]`

- **Where:** `modules/Export.lua:879`: `local send = chatType and _G.SendChatMessage`. The fallback is at `:885-889`: `if not send then … for _, line in ipairs(lines) do NS.Print(line) end return true end`.
- **Problem:** `SendChatMessage` has been deprecated since **11.2.0**. It lives in `Deprecated_ChatInfo.lua`, and the wiki's notice reads "will be removed in the future"; its replacement is `C_ChatInfo.SendChatMessage`. The call is made directly from a feature module, although `compat` says every deprecated call MUST be routed through `core/Compat.lua`. When the global is absent, the fallback prints the dump to the player's own chat frame and returns `true`.
- **Impact:** on the patch that removes the deprecated global, every export to Party, Raid, Instance, Guild or a whisper will look like it worked, because the player sees the lines, yet nobody else receives them. There is no error and no notice. The fallback exists for the headless harness, but it is also the one a live client will take.
- **Reachability:** every player who exports to any channel other than *Self only*, on the first client build without the deprecated global. The removal patch is **not yet announced**, so this is a scheduled break rather than a live one. It is graded High under the "deprecated API that will break" bucket, and because the failure is silent.

---

## Medium

### F-004 — During a perf capture's suspended arm, `/mm toggle` and the launcher's left-click still show windows `[perf]` `[design]`

- **Where:** `modules/WindowManager.lua:690-708` (`M:Toggle` → `inst:Show()` at `:697` and `:706`). The launcher is at `core/LauncherSetup.lua:229-237`, and its only gate is `if NS.IsDisabled and NS.IsDisabled() then`. The root cause is the same `WindowProto:Show()` as F-002.
- **Problem:** `toggle` is a feature verb. The library refuses feature verbs only while **disabled** (`isEnabled` at `settings/Slash.lua:254`), and the launcher does the same. While the **perf** hold is taken, both paths reach `Show()`, and `Show()` skips the ladder that would answer `"suspended"`.
- **Impact:** a window is drawn during arm B of a capture, and `performance-§6` says that arm must be inert. The frame-time comparison is then contaminated by a frame that should not be on screen. The window's `OnUpdate` is cleared, so no refresh runs, but the chrome is drawn.
- **Reachability:** a player running `/mm perf` who, during the suspended arm, types `/mm toggle` or left-clicks the minimap/broker button. `perf` is a documented reserved verb. Reproduced headless: `1 / 1` windows shown.

### F-005 — A window created while the addon is stood down is armed with an `OnUpdate` `[design]`

- **Where:** `modules/Window.lua:1382`, `inst.frame:SetScript("OnUpdate", onUpdate)`, is called unconditionally from `Window.New`. The callers are `WindowManager:Create` (`:253`) and `:Duplicate` (`:341`), which the Windows settings page reaches while the addon is disabled.
- **Problem:** `slash-commands-§7` requires that "every `OnUpdate` [is] cleared" while stood down. `Window.New` arms it regardless, and the latch's `standDown` cannot reach an instance that did not exist when it ran.
- **Impact:** it is inert as long as the frame stays hidden, because a hidden frame gets no `OnUpdate`. Combined with F-002, though, a window created while disabled and then force-shown would run its refresh clock. It also breaks the invariant `tests/test_disabled.lua` *"Disabled 4"* exists to pin, on a path that test does not exercise.
- **Reachability:** any player who disables the addon and then adds or duplicates a window from the settings panel. Reproduced headless.

### F-006 — The Slash degradation stub has no `DisabledLine`, and the launcher calls it `[design]` `[tests]`

- **Where:** the stub is `settings/Slash.lua:185-236` (`function SlashLib:New(d)`). Its members are `SetRowAnnotator`, `Cli*`, `LandingRows`, `HelpRows`, `PrintHelp` and `OnSlash`, with no `DisabledLine`. At `settings/Slash.lua:743`, `function Sl:DisabledLine() return cli:DisabledLine() end`. At `core/LauncherSetup.lua:232`, `if Sl and Sl.DisabledLine and NS.Print then NS.Print(Sl:DisabledLine()) end`.
- **Problem:** the launcher's guard checks the **wrapper**, which always exists, so on the stub it calls a nil method and raises "attempt to call method 'DisabledLine'". This is the "crash relocated to a rarer code path" that `testing-§8` names. `tests/test_surface_parity.lua`'s header records the Slash seam as "not compared … recorded rather than done", which is why nothing caught it.
- **Impact:** a Lua error on every left-click of the minimap button while disabled.
- **Reachability:** no shipping configuration reaches it. It needs `LibKa0s-Launcher-1.0` to register while `LibKa0s-Slash-1.0` does not, and the library is vendored whole. The reachability line caps it at Medium.

### F-007 — Every refresh releases and rebuilds every visible row `[perf]`

- **Where:** `modules/Window.lua:1168`, `self:HideAll()`. That releases the whole pool (`:912-914`), and `Row:Release` then calls `Cell:Clear` on every cell (`modules/Row.lua:1446-1455`, `1199-1204`: `SetValue(0)` plus two `SetText("")`). The same rows are then re-acquired, and each gets `ClearAllPoints` + `SetPoint` + `Update` (`modules/Window.lua:1206-1220`). `RowProto:Update` also calls `SetValue` on **hidden** cells for columns the player turned off (`modules/Row.lua:1376-1378`: `for _, cell in pairs(self.cells)`).
- **Problem:** at the throttle rate (4 per second in combat, through `ShouldPoll`), every drawn cell is written twice per pass, once to clear it and once to fill it, and every row is re-anchored even when its slot did not change.
- **Evidence:** in the committed capture `docs/perf-analysis/20260909-014604/report.md`, taken solo, `render` is 198.73 ms over 265 calls, which is 0.75 ms per pass. `renderRow` is 137.29 ms over 1325 calls, which is 0.10 ms per row. That leaves about 0.23 ms per pass in `Render`'s own work before any row is filled. The capture is **dated** (v0.1.0, solo, 2026-09-09). The 20-row raid cost is **unverified**; the offline `refresh20x7` measures 1.31 ms/iter today, for orientation only.
- **Reachability:** every player, on every refresh pass while a window is shown in combat. The actual saving is unmeasured, which is why this is Medium rather than High.

### F-008 — The remembered roster is persisted with no bound and survives logout `[design]`

- **Where:** `modules/Roster.lua:355-361`. Every `build()` records each member into `seenMap.byGuid` (`db.global.roster`). The only clear is `Roster.Forget` (`:572-582`), reached from `METER_RESET` (`:621`, `:628-630`). Reads fall back to the remembered map at `:489` (`Roster.Get`), `:506` (`IsGroupMember`) and `:519` (`OwnerOf`).
- **Problem:** nothing clears the map on a fresh **login**. The meter's data survives `/reload`, which is why the map is persisted, but whether it survives a logout is **unverified**. Nothing bounds its size either.
- **Impact, if the meter does not reset at login:** the map grows by every player ever grouped with, and `IsGroupMember` answers `true` for players from earlier sessions, so the group filter can admit a stranger who was in the player's group last week.
- **Reachability:** any player who never presses the meter reset, across sessions. **Unverified:** whether the client fires `DAMAGE_METER_RESET` at login. That check is in `03_SMOKE_TESTS.md` (SM-06), and the fix direction depends on it.

---

## Low

### F-009 — `Visibility:Evaluate` runs the whole ladder to feed a cache nothing ships reads `[perf]` `[design]`

- **Where:** `modules/Visibility.lua:389-419` (`Evaluate` → `remember`, `lastResult`). `Visibility.LastResult` (`:373`) has **zero** callers in `core/`, `modules/` or `settings/`; only `tests/test_visibility.lua` reads it. The module subscribes to six messages to do this (`:461-471`).
- **Impact:** every window's visibility rules are evaluated twice on every context edge, once here and once in the window's own `RefreshVisibility`. Each changed result also allocates a table. The only live output is a debug line.
- **Reachability:** every player, on every combat, zone, roster or player-state edge. The cost per edge is tiny.

### F-010 — Window commands answer with the wrong error string `[ux]`

- **Where:** `modules/WindowManager.lua:704`: `/mm toggle <unknown>` answers `"Setting not found: %s"`. `:272`, `:307`, `:324` and `:471-472`: `/mm window delete|copy <unknown name>` answers `"No window is selected."`, although the player named a window. `:309`: renaming to an empty name answers `L["Window name"]`, a label rather than a message.
- **Impact:** the reply does not tell the player the name was not found. `locales/enUS.lua:901` already carries `L["No window named '%s'."]`, which `settings/Slash.lua:574` uses for `/mm export`.
- **Reachability:** any player who mistypes a window name in a documented `/mm window` or `/mm toggle` command.

### F-011 — Feature-verb acknowledgements are raw English beside routed neighbours `[locale]`

- **Where:** `settings/Slash.lua:415` (`"windows " .. … "locked"`), `:428` (`"test mode " …`), `:446-447` (`"moved %s back to the center of the screen"` with hand-built plurals), `:580` (`"there is no window to export."`), and the debug acknowledgements at `:632-633` and `:696-697`. The same file routes `NS.L["No window named '%s'."]` at `:574`.
- **Impact:** some chat lines would translate and some would not, and the plural at `:447` is built by string concatenation.
- **Reachability:** English clients see no difference today. No other locale file exists.

### F-012 — Stale and misplaced comments on the show ladder and around it `[naming]`

- `core/MultiMeters.lua:459-463`: `NS.ShouldShow`'s doc block ("Whether `window` should be on screen …") sits directly above `local function fighting()`, merged into that function's own doc (`:464-470`).
- `core/MultiMeters.lua:346-361`: `OnSpellSucceeded`'s doc block runs straight into `OnSystemMessage`'s (`:362`) and is attached to the wrong function. `OnSpellSucceeded` itself (`:377`) has no doc.
- `core/MultiMeters.lua:500,522`: the ladder is numbered STEP 0, then STEP 2; step 1 was removed with the draw gate. `modules/Window_Placement.lua:202`, `["disabled"] = true, -- step 1: the master switch …`, still points at that removed rung.
- `modules/HeaderControls.lua:302` and `:372` say "settings/ loads ahead of modules/". The TOC loads `settings/` **last** (`MultiMeters.toc`, "Settings (last …)"), so the stated reason is backwards, even though resolving at call time is still correct.
- `core/LauncherSetup.lua:213-214` says "`WindowManager:Toggle` writes each window's stored `shown`". It writes nothing (`modules/WindowManager.lua:690-708`), and no `shown` key exists.
- **Reachability:** comments only; no runtime effect.

### F-013 — The test mock hard-codes the addon version, so perf records carry the wrong version `[tests]`

- **Where:** `tests/wow_mock.lua:1087`, `Version = "0.1.0"`, while `MultiMeters.toc` says `## Version: 1.0.0`. `tests/perf.lua:753-754` prints `NS.version`, and the committed `docs/automated-tests/20260916-184449/perf.json` records `"version":"0.1.0"`.
- **Impact:** offline perf records can no longer be tied to the release that produced them, and version-reading cases assert against a number the TOC does not carry.
- **Reachability:** test and perf evidence only; the shipped code is correct.

### F-014 — `.luacheckrc` whitelists a removed global nothing calls `[lint]`

- **Where:** `.luacheckrc:69` puts `"GetSpellInfo"` in `read_globals`. Addon code calls it only as `Compat.GetSpellInfo` (`modules/DrillDown.lua:549-550`, `modules/Tooltip_Lines.lua:660-661`).
- **Impact:** a future bare `GetSpellInfo(` call, a global removed in 11.0, would lint clean.
- **Reachability:** a future contributor only.

### F-015 — `docs/performance.md` quotes a feign figure the runner no longer produces `[tests]`

- **Where:** `docs/performance.md:289` ("both arms measured 71224.1 bytes/iter exactly"). Today's `tests/perf.lua` run gives `feignTraceAbsent` and `feignTraceOff` at **71544.1** each.
- **Impact:** the two arms still agree with each other, which is the property the section is about, but the absolute figure a reader might check against is stale.
- **Reachability:** documentation only.

### F-016 — The drill-down closes when its window is renamed `[ux]`

- **Where:** `modules/DrillDown.lua:850-855` exits the view on **any** `WINDOWS_CHANGED` addressed to that window. `WindowManager:Rename` announces `"renamed"` (`modules/WindowManager.lua:316`).
- **Impact:** renaming a window from the settings panel throws away the breakdown the player had open. Copying settings into it (`"copied"`) is a reasonable reason to exit; a rename is not.
- **Reachability:** any player who renames a window while it shows a breakdown. This is uncommon.

### F-017 — Two chatty events stay registered all session to serve narrow windows, and neither is measured `[perf]`

- **Where:** `core/MultiMeters.lua:201` registers `UNIT_SPELLCAST_SUCCEEDED`, which fires for every cast by every unit in a raid and matters only with a Deaths column shown and a hunter present. `:208` registers `CHAT_MSG_SYSTEM`, which matters only while a whisper dump is in flight (`modules/Export.lua:839-856`).
- **Impact:** no perf bucket brackets either handler, so their cost is **unverified**. Both handlers return early, but the client still dispatches every event into Lua.
- **Reachability:** every player in a group, for every cast or system line. The cost per event is small and unmeasured.

---

## Upstream findings

None. `libs/LibKa0s` and `tests/_kit` are byte-identical to `../LibKa0s/LibKa0s` and `../LibKa0s/testkit`,
and no defect was traced into vendored code. F-006 is a defect in this addon's **own** degradation stub
and wiring, not in the library.

## Not findings (checked and cleared)

- **Perf buckets and brackets agree.** All eight declared buckets are reached (`grep -rhoE 'Note\("[a-zA-Z]+"'`).
  Every bracket is the `Perf.on and debugprofilestop()` idiom behind a load-time upvalue, apart from
  `core/MultiMeters.lua`'s call-time read, which is documented as an event-path choice. `providerRead`
  is deliberately left undeclared-parent and passes its observed parent.
- **Migrations.** Migrations walk every stored profile through `db.sv.profiles`
  (`core/Database.lua:271-281`), not just the active one.
- **Secret handling on the arithmetic paths.** The arithmetic sites are guarded: the pet fold uses
  `CanCompare2` plus `type` checks, the spell sort does an accessibility pre-pass, and the counted
  columns use the addon's own counters.
- **Launcher descriptor.** The icon is read at file scope and `minimap` is passed as a closure. The
  left-click is refused while disabled, and the right-click is ungated.
