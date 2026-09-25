# 02 — Deviations (Ka0s Multi Meters, 2026-09-23)

Audited against **v2.64.0 (2026-09-23)**. Severity means **impact**, not rule strength (`AUDIT.md`
step 5). A doc-only or config-only failure is Low or Info **even when the rule it fails is a MUST**,
and every entry names the MUST it fails.

## Tally, with its basis stated

- **Headline tally (roots only): 13.**
- **Total including `derived from` dependents: 14** (MM-A-18a is derived from MM-A-18).
- By grade, **roots**: **High 1** · Medium 0 · **Low 11** · Info 1.
- By grade, **including dependents**: High 1 · Medium 0 · Low 12 · Info 1.
- **MUST failures, roots only: 11.** They are MM-A-19, MM-A-20, MM-A-21, MM-A-03, MM-A-16, MM-A-18,
  MM-A-08, MM-A-22, MM-A-23, MM-A-24 and MM-A-25. MM-A-06 fails a **SHOULD**, and MM-A-26 is an
  observation. Dependents are excluded from the MUST count, so the figure stays **11** with MM-A-18a.
- **The one High is graded by the playbook, not by player impact.** `AUDIT.md` step 4 says: "A tag
  vendored with no bundle naming it and no `## Documented deviations` row saying why is a **High**
  finding." The fetched playbook wins, so MM-A-19 is High. No player, SavedVariables file or session
  is affected by it. Graded by impact alone it would be Low.
- **No finding here is a player-reachable defect in the current code.** The closest are MM-A-18's two
  British locale strings, which are spelling and not wrong values, and MM-A-21's version string. The
  latter shows `1.0.0` for a build CurseForge lists as 1.0.1, and the code in that build is 1.0.0's.

**Previous run:** 9 roots and 10 total (2026-09-08, against v2.39.0).

- **Closed:** four roots (MM-A-13, MM-A-14, MM-A-15, and MM-A-17 superseded).
- **Still open:** five roots (MM-A-03, MM-A-06, MM-A-08, MM-A-16, MM-A-18), each narrowed.
- **New:** eight roots (MM-A-19 to MM-A-26). All but MM-A-24 and MM-A-26 are visible only against
  rules added since v2.39.0 or found by checks the playbook added since.

Details are at the foot of this file.

**Nothing here re-opens a ratified register row.** The five rows in `docs/ARCHITECTURE.md` →
`## Documented deviations` were read first:

- each row's cited rule was re-checked against v2.64.0;
- each re-check trigger was evaluated against this tree;
- each evidence id was resolved.

All five stand, and are recorded as **accepted** in `03_EVIDENCE.md` §R. They do not count toward
the MUST tally.

---

## MM-A-19 *(new)* — 28 LibKa0s tags were vendored with no re-vendor bundle and no register row

- **Section:** `audit-review-history`, *A re-vendor commit implies a bundle* (**MUST**: "every
  re-vendor commit in the repo's history has a `docs/revendor/` bundle naming the tag that commit
  vendored, **or** the absence is a row in `## Documented deviations`").
- **Grade:** **High, because the playbook assigns it** (`AUDIT.md` step 4: "a **High** finding").
  Impact on a player is nil: this is a missing record of what arrived with each library release.
- **What:** the store's first bundle is `docs/revendor/2026-08-25/`, which sets the horizon.
  - Since then, `git log -- libs/LibKa0s` finds commits whose `CLAUDE.md` provenance line names
    **34** distinct tags.
  - The eight bundles name **8** tags: `v1.15.0`, `v1.25.0`, `v1.30.0` (bare-dated folders, read
    from `01_DELTA.md` line 1), `v1.31.0`, `v1.32.0`, `v1.33.0`, `v1.34.0` and `v1.55.0`.
  - **28 vendored tags have no bundle**, from `v1.18.0` through `v1.53.0`.
  - The newest bundle, `2026-09-23-v1.55.0`, opens `Delta: LibKa0s v1.54.2 → v1.55.0`. It does not
    name the span it would have to cover to discharge the backlog.
  - One more tag, `v1.54.2`, re-vendored `tests/_kit/` only (`d2169d4`), because the library bytes
    were identical to v1.53.0's. The check's trigger (`-- libs/LibKa0s`) cannot see that commit, so
    `v1.54.2` is **not** in the 28. It is named here so the omission is visible.
- **Fix:** write **one consolidated bundle**, `docs/revendor/<date>-v1.34.0-to-v1.54.2/`, whose
  `01_DELTA.md` first line names the span. `audit-review-history` says "One bundle naming the span it
  covers discharges them." Do not back-fill a folder per tag.

## MM-A-20 *(new)* — The event-registration block does not survive one bad name, and a deaf event is not recorded

- **Section:** `events-frames-taint-§1`, *An unknown event name raises, and takes the rest of the
  block with it*. Two **MUST**s: "Registration is **isolated per event**: every `RegisterEvent` goes
  through a single `pcall`ed helper", and "The rejected names **MUST** be recorded, and the record
  **MUST** be reachable by the player".
- **Grade:** **Low.** Latent. Every name registers on the 12.1 client this TOC targets, so no player
  hits this today. The first client that retires or lacks one of these names turns it into a
  silently deaf addon: every registration after the throw goes unbound.
- **What:**
  - `NS:OnEnable` (`core/MultiMeters.lua:149-213`) makes **21 bare `self:RegisterEvent` calls** in
    sequence. The first unknown name aborts the function, and every later registration is lost,
    including the three `DAMAGE_METER_*` events at `:211-213`.
  - The one helper (`registerIfValid`, `:124-132`) guards a single event (`:195`). Its
    `IsEventValid` branch calls `target:RegisterEvent` outside the `pcall` (`:127-128`), which is the
    "relied on alone" shape the rule forbids.
  - Nothing records a rejected name, and neither `/mm debug` nor the console can show one.
  - The comment at `:153-156` claims an unknown event "never fires [and] costs nothing". On modern
    retail an unknown event name **raises**, so the comment is wrong in the direction that matters.
- **Fix:** route **all 22** registrations through one `pcall`ed helper that keeps `IsEventValid`
  as a front gate and appends failures to a list on `NS.State`. Surface that list in
  `/mm debug diag`. Add a suite case using the kit mock's `M.__badEvents` to prove that one bad name
  leaves the rest registered and is reported. Correct the `:153-156` comment.

## MM-A-21 *(new)* — Tag `1.0.1-release` ships a TOC that says `1.0.0`, with no Version History row and no release run

- **Section:** `versioning-git` (**MUST** "bump in TOC `## Version:`, and in any code constants and
  README badges/Version History tables"); `automated-tests-§3`, *The release gate* (**MUST NOT** "cut
  a release — bump the version, roll `## Version History`, tag — unless the release run's
  `manifest.json` shows all four suites at `pass`").
- **Grade:** **Low.**
  - A player who installs the build CurseForge lists as 1.0.1 sees `1.0.0` from `/mm version` and in
    the AddOns list.
  - The code in that build *is* 1.0.0's: the tagged commit `71e5742` changes only a blank line in
    `README.md`. So the value is not wrong about the code.
  - What is broken is the record: a tag with no version bump, no history row and no release bundle.
- **What:**
  - `git show 1.0.1-release:MultiMeters.toc` shows `## Version: 1.0.0`.
  - `README.md:101-104` tops out at `1.0.0`.
  - No `docs/automated-tests/<run>/manifest.json` carries `"release": "1.0.1"`. The release runs are
    `0.1.0` and `1.0.0` only.
- **Fix:** at the next release, bump **past** the published tag (to `1.0.2` or `1.1.0`, never
  `1.0.1` again). Roll `## Version History` and run the release battery first, per
  `/wow-addon:bump-version`. Optionally add a one-line `1.0.1` history row saying it re-published
  1.0.0 unchanged. Never cut a "trigger a build" tag without the bump again.

## MM-A-03 — Three Tier 2 docs are owed, and their register rows say *Not applicable* against triggers that fire

- **Section:** `documentation-§3`, *Tier 2*. **MUST** ship under the canonical name when the trigger
  fires. *Not applicable* is a valid state that **MUST** be stated, and the statement must be true.
- **Grade:** **Low.** Docs only. Per `AUDIT.md` step 4(b) it is graded above a bare omission,
  because each row asserts something false.
- **What**, each trigger measured today against v2.64.0's wording:

  | Doc | Trigger (`documentation-§3`) | Measured | Row says |
  |---|---|---|---|
  | `slash-dispatch.md` | `NS.COMMANDS` carries **eight or more** commands, **or any** subcommand tree | **18** verbs **and** the `window` sub-verb tree | "Not applicable" (`docs/ARCHITECTURE.md:475`) |
  | `message-bus.md` | **more than ten** distinct messages | **14** | "Not applicable" (`:476`) |
  | `profiles.md` | a profile control ships in the options UI | `settings/Profiles.lua` hosts AceDBOptions' tree as a registered page | "Not applicable" (`:477`) |

  Each row refutes itself with its own number. The rows argue that the hub already carries the
  content. The trigger is a count, not a judgment, and the hub is the thing the spill rule exists to
  keep small.

  `tests/test_docmap.lua` pins these rows' *status* against the directory. Its header says it
  "deliberately does not judge whether a trigger has fired", so it is green over false rows.
- **Since 2026-09-08:** `debug.md` shipped (its row is now *Present*). That leaves three of the four
  docs owed.
- **Fix:** spill the Slash commands, Message bus and Profiles material into the three canonical docs
  (a move, not new writing). Convert the three rows to *Present*. This also shrinks the hub, which
  is MM-A-06.

## MM-A-16 — Three **closed** issues carry an open-state label

- **Section:** `audit-review-history`, *Pending-audit decisions live in GitHub issues*. **MUST** carry
  status from the closed vocabulary. The table binds `state:triaged` and `state:untriaged` to issue
  state **open**, and `state:done` and `state:will-not-do` to **closed**.
- **Grade:** **Low.** A record defect in the working queue. No user reaches a label.
- **What:** **#4** ("Wire up the shipped bar texture") and **#21** ("Promote the Columns page's
  drag-to-reorder block list to LibKa0s") are CLOSED with `state:triaged`. **#24** ("Spec icon is
  missing for every raid row but the local player's") is CLOSED with `state:untriaged`. Each one
  appears in the `--label` queries a triage session runs.
  - Two of the four from 2026-09-08 (#6, #7) are fixed.
  - #24 is new.
  - #21 shipped as `LibKa0s-Widgets-1.0`'s `ReorderList`, so it is `state:done`.
- **Fix:** relabel each issue to its terminal value with `gh issue edit`, spaced out:
  - #21 → `state:done`.
  - #4: read against what shipped (`core/LSMPatch.lua` is gone; LibKa0s ships bar textures). Most
    likely `state:will-not-do`.
  - #24: read against issue #22's outcome (`state:done` or `state:will-not-do`).

## MM-A-18 — `minimise`/`minimised` survive in player-visible strings, README prose, identifiers and a stored path, held by a waiver the rule does not sanction

- **Section:** `localization-§5` (**MUST**: "Every English word a Ka0s addon **authors MUST use US
  English spelling**"). Also its waiver clause, which **MAY** waive "a spelling that is **not the
  repository's English to correct**" in three named shapes: a library's field name, game data matched
  on its own token, and a generated dump of the client's strings.
- **Grade:** **Low.** Two player-visible locale values are spelled in the wrong dialect. Nothing is
  wrong or broken.
- **What:**
  - The British list is otherwise clean: the kit gate `tests/_kit/test_prose.lua` is wired
    (`tests/run.lua:242`) and green.
  - What keeps it green is `tests/prose_waivers.lua`, which waives `minimis` in **25 files**
    (`:30-57`).
  - **154 lines across 22 authored files** still carry `minimis`. That count covers the tracked set
    minus `libs/`, `tests/_kit/` and the frozen stores, and includes the waiver file itself.
  - Player-visible: `locales/enUS.lua:214` `L["Show minimise"]`, `:231` `L["Minimised"]`, and
    `README.md:50` ("close, minimise, lock").
  - None of the three sanctioned shapes applies. This is the addon's own English, and the waiver
    file says so itself: "this waiver is a DEBT, not a decision" (`tests/prose_waivers.lua:24`).
  - No `## Documented deviations` row covers it.
- **Fix:**
  1. Correct the prose, comments, README and locale **values** now. The README line and the doc
     prose need no migration.
  2. Move each locale **key** with all its call sites in one change (`localization-§5`: a key change
     is a key change).
  3. Take the stored paths through MM-A-18a.
  4. Remove each waiver entry in the same change that clears its file.

### MM-A-18a — The spelling reaches two stored paths, so it needs a migration, not a rename *(derived from MM-A-18)*

- **Section:** `localization-§5` (settings keys) with `versioning-git` / `savedvariables` (a stored-key
  change bumps `schemaVersion` and adds a migration step).
- **Grade:** Low. Latent: nothing is wrong today, and the risk is in the *fix*.
- **What:** `defaults/Profile.lua:130` declares `showMinimise = true`, and `:148` declares
  `minimised = false`, stored at `window.frame.minimised`. A find-and-replace would orphan every
  player's stored value.
- **Fix:** a keyed move in `core/Database.lua`'s runner (v15 → v16: copy old → new in every profile,
  then prune), with a case pinning it. Declining to rename a stored key is legitimate, but then it is
  a `localization-§5` register row, not a waiver.

## MM-A-08 — No suite case pins a wrapped tab strip's geometry against the selection

- **Section:** `options-ui-§13` (**MUST**: on a strip wide enough to wrap, "the total reserved band
  and every row's y offset are **identical for every value of the selection**"), with `testing-§12`.
- **Grade:** **Low.** Not reachable today. No page declares enough tabs to wrap; the widest are Bars
  and Tooltip at six.
- **What:** the library publishes the seams (`libs/LibKa0s/OptionsTabs.lua:691` `O.__tabPlacement`,
  plus `__tabBand`), but `grep -rn '__tabPlacement\|__tabBand\|__tabArtHeight' tests/*.lua` returns
  nothing. Unchanged since 2026-09-08.
- **Fix:** one case that renders each page under every selection value and asserts the band and
  each row's y offset are equal. The harness must answer a different height for selected-state art.
  The case must go red when `tabArtHeight()` reads the selected button's art.

## MM-A-22 *(new)* — Three load-bearing TOC positions carry no comment at the line

- **Section:** `toc-file-§5` (**MUST**: "A line whose position is **load-bearing MUST** carry a
  comment saying so, at the line, naming **what resolves at load**"). Also the **SHOULD** to mark
  conventional positions once per group.
- **Grade:** **Low.** A convention and a latent risk (anti-pattern #66). A wrong move fails silently.
- **What:**
  - **`settings\OptionsSetup.lua` (`MultiMeters.toc:134`).** Page files capture
    `local H = NS.Helpers or {}` at file scope (`settings/General.lua:61`, likewise `Windows.lua:62`,
    `Columns.lua:63`, `ColumnBlocks.lua:48`) and register their pages at file load
    (`settings/General.lua:257`). With the `or {}`, a page loading before `OptionsSetup` degrades
    silently to an empty helper table. The line has no comment. The comment above
    `settings\Schema_Paths.lua` (`:128-131`) is about that file.
  - **`core\PerfSetup.lua` (`:58`).** Its descriptor reads `version = NS.Version()` at file scope
    (`core/PerfSetup.lua:96`). The file's own header calls its position "a HARD constraint". The TOC
    line is bare. The comment at `:52-56` states only the Lifecycle half of its constraints.
  - **`core\CoreSetup.lua` (`:51`).** It defines `NS.LIBKA0S_MISSING` (`core/CoreSetup.lua:55`).
    `core/DebugLogSetup.lua` reads that at file scope in its library-absent branch (`:229`, `:253`),
    as does `core/LauncherSetup.lua:109`. Neither line carries the constraint.
  - Conventional positions (`Constants`, `Namespace`, `State`, `Secrets`, most of `# Modules`) carry
    no "conventional" marker, which is the SHOULD half.
- **Fix:** three at-line comments naming what resolves, plus one "conventional" note per group.
  Consider extending `tests/test_loadorder.lua` to assert each pair.

## MM-A-23 *(new)* — Citations that do not parse as `filename-§N`, one of them in a register Rule cell

- **Section:** `documentation-§6`, *Citing the standard* ("A **malformed** … reference is a **MUST**
  fix"; "Malformed means it does not parse as `filename-§N` at all"). Also `documentation-§3` (the
  register's **Rule** "is a `filename-§N` reference into this standard").
- **Grade:** **Low.** Comments and docs. A reader decodes them, but no sweep or gate can resolve them.
- **What** (the MUST half is enumerated in `03_EVIDENCE.md` §23):
  - The register row at `docs/ARCHITECTURE.md:519` cites `library-stack §8` (space, no hyphen). The
    same form appears at `:671` and `:679`, and `tests/test_texture_paths.lua:48`
    (`COLUMNBLOCKS_RULE = "library-stack §8"`) pins that form, so a correction must move the test
    with it.
  - **18 authored lines** use a §-less form (`slash-commands-7`, `performance-6`, `localization-5`,
    `architecture-4`, `testing-12`, `slash-commands-2`, `slash-commands-8`, `localization-1/2`):
    `core/LifecycleSetup.lua` ×8, `modules/Export.lua` ×1, `tests/prose_waivers.lua` ×2,
    `tests/test_disabled.lua` ×7.
  - **35 authored lines in 18 files** write the section sign as the literal text `\194\167`
    inside a **comment**, e.g. `core/MultiMeters.lua:135` `(slash-commands-\194\1677)`. Lua decodes
    that escape only inside a string literal. In a comment it stays nine characters, and the
    citation reads `slash-commands-\194\1677`, which does not parse as `filename-§N`.
  - Not counted: `docs/test-cases.md` (generated from the vendored kit's own case names) and the
    anchor slug at `docs/ARCHITECTURE.md:615`.
- **Retired dotted form:** the standard's own sweep command returns **2** hits, both in
  `docs/superpowers/plans/2026-08-24-shared-dropdown-and-export-ux.md`, a frozen planning bundle.
  Not filed.
- **Fix:** rewrite all 57 lines (4 + 18 + 35) as `library-stack-§8`, `slash-commands-§7` and so on,
  with `test_texture_paths.lua` in the same commit. The files are already UTF-8 (other comments in
  `core/MultiMeters.lua` carry a raw `§`), so the raw character is the correct spelling in a comment.
  The escape belongs only inside a string literal.

## MM-A-24 *(new)* — The hub's inventory line disagrees with the tree and with `module-map.md`

- **Section:** `documentation-§5` (**MUST** "keep the doc set in sync with code").
- **Grade:** **Low.** Doc drift.
- **What:** `docs/ARCHITECTURE.md:14` reads "Fifty-seven non-vendored source files: 1 locale, 18
  `core/`…". `git ls-files` counts **58**, with **19** under `core/`. `docs/module-map.md:6` and the
  hub's own `:45` ("all fifty-eight of them") both say 58, so the hub contradicts itself 31 lines
  later.
- **Fix:** correct `:14` to 58 / 19. Consider a `test_doc_structure` assertion that derives the
  count, so the next file added cannot leave it behind.

## MM-A-25 *(new)* — Two `library-stack-§8` declines live only as census dispositions, with no register row

- **Section:** `library-stack-§8` (**MUST**: "Where the addon needs a mark, it **MUST** use the
  catalog's") with `documentation-§3` and `audit-review-history` ("a deviation not in the register is
  not ratified").
- **Grade:** **Low.** Visual consistency, and a record gap.
- **What:**
  - **`modules/Tooltip.lua:107`** `TARGET_ICON = [[Interface\ICONS\Ability_Hunter_FocusedAim]]`,
    while the catalog carries `target` (`libs/LibKa0s/Media.lua:136`, `media/icons/target.tga`).
  - **`modules/Window.lua:645-646`**, the chat size-grabber pair, while the catalog carries `resize`
    (`Media.lua:103`).
  - Both are reasoned in the `### Hard-coded texture paths` table (`docs/ARCHITECTURE.md:667`,
    `:669-670`), whose rows are `File | Path | Disposition` with no Decided date and no re-check
    trigger. The disposition itself calls the first "a considered decline".
  - The one comparable decline, `settings/ColumnBlocks.lua`, **has** a register row (`:519`), which
    shows the shape these two are missing.
- **Fix:** either adopt the marks (`NS.Icon("target")`; a two-state grip from `resize` with a hover
  tint), or file two register rows citing `library-stack-§8`, each with a Decided date and a trigger.
  A good trigger for the grip is "`LibKa0s-Media-1.0` publishes a hover variant". Retain the census
  rows either way.

## MM-A-06 — `docs/ARCHITECTURE.md` is 762 lines, past the hub's ~400-line ceiling

- **Section:** `documentation-§3`, *`ARCHITECTURE.md` is a hub* (the **SHOULD**: "The whole file
  **SHOULD** stay under roughly 400 lines").
- **Grade:** **Low.** Docs, and a SHOULD. The spill **MUST** half is met.
- **What (shape, not arithmetic):** the file was 773 lines and is now **762**. Every mandated section
  with a canonical topic doc is under 60 lines. What holds the size is `## Documentation map`
  (`:427-499`, 73 lines), `## Documented deviations` (`:500-681`, 182 lines, with the two census
  sub-tables) and `## Complexity register` (`:682-717`).
- **Fix:** MM-A-03's three spills are the first cut. After that, move the texture census
  (`:621-681`) to a Tier 3 doc registered in `### Addon-specific`, leaving a summary and one link.

## MM-A-26 *(Info)* — The newest automated-test run is 32 commits and one warned function behind HEAD

- **Section:** `automated-tests-§6` (the checkpoint is **release**, and the record **MUST NOT** gate
  commits).
- **Grade:** **Info.** Not a deviation.
- **What:**
  - `20260916-184449` (sha `2d38bbd`) records 1884 cases and one warned function, `NS.ValidateSchema`
    at CCN 19. Today the suite runs **1948** cases, and `lizard` reports **0** warnings.
    `NS.ValidateSchema` measures 15 at `settings/Schema_Paths.lua:943-960`.
  - `RESULTS.md`'s watch list therefore still carries a row the code has left. The band count is
    unchanged at 23 files.
  - That row's `Accepted between releases` disposition has run for one release run only, so there is
    no #53.
  - The table has no commit cell. It is a pre-rule row, carried as *unknown*. Kit revision 25, which
    emits the cells, was vendored after the run.
- **Fix:** none needed now. The next release run (MM-A-21) regenerates `RESULTS.md`, drops the row
  and writes the commit cells.

---

## Closed or narrowed since 2026-09-08

| ID | 2026-09-08 finding | Status today |
|---|---|---|
| MM-A-03 | Four Tier 2 docs owed | **Narrowed to three.** `debug.md` shipped and its row reads *Present*. |
| MM-A-06 | Hub 773 lines | **Narrowed to 762.** Still over the SHOULD. |
| MM-A-08 | No wrapped-strip geometry case | **Unchanged.** |
| MM-A-13 | `## Documentation map` not the four mandated tables | **Closed.** Four tables in order (`:450`, `:462`, `:479`, `:490`); the fourth holds exactly the six; `:429` says "four"; the three-table justification note is gone. |
| MM-A-14 | Static `Version` badge in slot 2 | **Closed.** Slot 2 is the live `curseforge/v/1690082` endpoint (`README.md:4`), and the TOC carries `X-Curse-Project-ID: 1690082`. |
| MM-A-15 | README ships no logo | **Closed by the standard.** v2.45.0 reversed the rule: a README **MUST NOT** carry a logo (#79). The README has none, which is compliant. |
| MM-A-16 | Four closed issues labeled `state:triaged` | **Narrowed and changed:** #6 and #7 fixed, #4 and #21 remain, #24 added (closed but `state:untriaged`). |
| MM-A-17 | Newest bundle four commits behind | **Superseded** by MM-A-26. |
| MM-A-18 | 830 British-spelling lines | **Narrowed** to one family (`minimis`, 154 lines), now held by a waiver. |
