# 02 — Deviations (Ka0s Multi Meters, 2026-10-07)

Audited against **v2.76.1 (2026-10-07)**. Severity means **impact**, not rule strength (`AUDIT.md`
step 5). A doc-only or config-only failure is Low or Info **even when the rule it fails is a MUST**,
and every entry below names the MUST it fails.

Each entry also carries a **Needs addressing?** line. It is an adversarial read of whether the gap
must be closed, could be closed later, or could be ratified instead. It is input to the consolidated
plan and does not change the grade.

## Tally, with its basis stated

- **Headline tally (roots only): 9.**
- **Total including `derived from` dependents: 10.** One dependent: MM-A-19a, derived from MM-A-19.
- By grade, **roots**: High 0 · Medium 0 · **Low 8** · Info 1.
- By grade, **including dependents**: High 0 · Medium 0 · Low 9 · Info 1.
- **MUST failures, roots only: 7.** They are MM-A-19, MM-A-23, MM-A-24, MM-A-27, MM-A-28, MM-A-29
  and MM-A-30. MM-A-06 fails a **SHOULD**, and MM-A-26 is an observation. Dependents are left out of
  the MUST count, so it stays **7** with MM-A-19a, which also fails a MUST.
- **None of these is a player-reachable defect in the current code.** The nearest is MM-A-28. A
  player whose macro still types the pre-1.1.0 minimap path gets the unknown-setting refusal, and the
  release notes never told them the path changed. The code is right. The missing announcement is the
  defect.

**Previous run:** 13 roots and 14 total (2026-09-23, against v2.64.0).

- **Closed:** nine roots (MM-A-03, MM-A-08, MM-A-16, MM-A-18 with MM-A-18a, MM-A-20, MM-A-21,
  MM-A-22, MM-A-25). See the table at the foot of this file.
- **Still open:** five roots, each narrowed: MM-A-19 (28 tags down to 2), MM-A-23 (57 lines down to
  1), MM-A-24, MM-A-06 (762 lines down to 578) and MM-A-26 (Info).
- **New:** four roots (MM-A-27 to MM-A-30). Three of them are visible only against text added since
  v2.64.0: compat's dead-rung rule (v2.65.0), launcher-§3's release-notes MUST (v2.65.0) and the
  sighted-complexity gate line (v2.74.0). MM-A-30's conformance step 8 was rewritten at v2.67.0.

**Nothing here re-opens a ratified register row.** The five rows in `docs/ARCHITECTURE.md` →
`## Documented deviations` were read first. Their cited rules were re-checked against v2.76.1,
their re-check triggers were evaluated against this tree, and their evidence ids were resolved. All
five stand and are recorded as **accepted** in `03_EVIDENCE.md` §R. They do not count toward the MUST
tally.

---

## MM-A-19 — Two LibKa0s tags were vendored with no re-vendor bundle and no register row *(recurs, narrowed)*

- **Section:** `audit-review-history`, *A re-vendor commit implies a bundle*. The **MUST**: every
  re-vendor commit "has a `docs/revendor/` bundle naming the tag that commit vendored, **or** the
  absence is a row in `## Documented deviations`".
- **Grade:** **Low.** It is a missing record. No player, stored data or session is affected
  (`AUDIT.md` step 5. The hard-coded High of v2.64.0 was removed at v2.65.0).
- **What:** the vendored-tag walk, run from horizon `2026-08-25 00:00`, resolves 56 tags. The
  recorded walk resolves 54. The two left over are **v1.69.0** (`824999b`, "chore: re-vendor LibKa0s
  v1.69.0 (kit 37; adds the line chart widget)") and **v1.70.0** (`1ee53cf`, "chore: re-vendor
  LibKa0s v1.70.0"). Both commits change `libs/`, `tests/_kit/` and the `CLAUDE.md` provenance line
  and nothing else. The 28-tag backlog filed on 2026-09-23 is gone: the span bundle
  `2026-09-24-v1.14.0-v1.54.2/` and the per-tag bundles after it discharge it.
- **Fix:** write one span bundle, `docs/revendor/2026-10-07-v1.69.0-v1.70.0/`, holding
  `01_DELTA.md` and `05_SUMMARY.md` only. Line 1 is
  `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.69.0 v1.70.0)`. `05_SUMMARY.md` has one line per tag,
  *carried by sweep, nothing adopted*. Neither tag adds a consumer obligation for this addon:
  `LineChart` and `Autocomplete` are new `Widgets` members, and the addon calls neither.
- **Needs addressing?** **Yes, cheaply.** This is the third time in a row this check has fired here,
  and both times the cause was a re-vendor done outside `/dev-copilot:wow-revendor-libka0s`. Closing
  it costs two small files. Adopting the widgets is a separate question and is not owed.

### MM-A-19a — The same two re-vendors left three documents naming the previous tag or kit *(derived from MM-A-19)*

- **Section:** `documentation-§5` (**MUST** "keep the doc set in sync with code").
- **Grade:** Low. Doc drift.
- **What:**
  - `docs/settings-panel.md:29` says `v1.68.1 bundled`.
  - `docs/testing.md:597` says `kit 36` on the complexity row.
  - `DEPENDENCIES.md:35` says `(kit 36)`.
  - The payload is v1.70.0 with kit revision 37 (`tests/_kit/framework.lua:20`). Both `chore:`
    commits touched `CLAUDE.md` alone among the docs.
- **Why derived:** it has the same single cause as MM-A-19 (a re-vendor that skipped the command's
  bundle and doc sync), it is not player-reachable, and it is not graded higher than its root.
- **Fix:** bump the three stamps in the same change as the span bundle. Better still, word them so
  they do not name a tag. The provenance line is the one place a tag is owed.

## MM-A-23 — One standard citation still does not parse as `filename-§N` *(recurs, narrowed)*

- **Section:** `documentation-§6`, *Citing the standard*. The rule: "A **malformed** … reference is
  a **MUST** fix".
- **Grade:** **Low.** It is in a comment.
- **What:** `core/LifecycleSetup.lua:117` reads `(architecture-4)`. Down from 57 lines on
  2026-09-23. The per-match sweep over the live tracked set (scope in `03_EVIDENCE.md` §23) finds no
  other malformed citation and **no out-of-range** citation among 957 `filename-§N` hits. The one
  other hit, `docs/ARCHITECTURE.md:503`, is the anchor slug `#files-by-layout-1-band` and not a
  citation. The retired dotted form returns 2 hits, both `Spec §2.5` inside
  `docs/superpowers/plans/2026-08-24-shared-dropdown-and-export-ux.md`. Those cite a spec, not the
  standard, and are not filed.
- **Fix:** change the comment to `architecture-§4`.
- **Needs addressing?** **Yes, trivially.** It is one comment, and the fix should ride with any
  commit that touches the file.

## MM-A-24 — The hub still contradicts itself and the tree in four places *(recurs)*

- **Section:** `documentation-§5` (**MUST** "keep the doc set in sync with code").
- **Grade:** **Low.** Doc drift.
- **What:**
  - **`docs/ARCHITECTURE.md:45`** reads "Every file — all fifty-eight of them —". The same file's
    `:14` and `docs/module-map.md:6` say **sixty-three**, which matches `git ls-files` (63 authored
    `.lua` outside `libs/` and `tests/`). The 2026-09-23 fix corrected `:14` and added the
    `test_doc_structure.lua` gate (`:327`). That gate reads only the
    "`<N>` non-vendored source files" line, so `:45` drifted unseen.
  - **`:511-512`** reads "Its three `library-stack-§8` declines … are ratified in the register above".
    The register has **two** `library-stack-§8` rows (`:409`, `:410`). The grip row was retired on
    2026-10-02 (`:413-418`).
  - **`:444`** and **`:454`** each open with "**One row is ratified.**". Each paragraph then
    describes a row that was **retired** (2026-08-27 and 2026-08-11). The wording is backwards for
    a register reader.
  - Two code comments make the same kind of false statement:
    - `settings/Slash.lua:82-83` says the verb `desc` strings feed "the README's command table".
      The README has none, because documentation-§1 forbids one.
    - `settings/Slash.lua:857` says the report "lands with logging off". Since v2.71.0 the run turns
      logging on, and `docs/debug.md` says so.
- **Fix:** correct the four hub phrases and the two comments. Widen the `test_doc_structure` gate to
  catch any spelled-out "all *N* of them" count, or drop the count from `:45`.
- **Needs addressing?** **Yes, as part of the doc-sync pass.** None of it is reachable. But `:45`
  is the same drift this audit filed last cycle, and the register sentence at `:511-512` is the line an
  auditor reads first.

## MM-A-27 *(new)* — A library-absent fallback ladder keeps a rung no admitted client can reach

- **Section:** `compat`, *A dead fallback rung is deleted, not shimmed* (v2.65.0). The **MUST**: "a
  fallback rung that calls a global **no** client the addon's `## Interface` line admits provides is
  dead code … **MUST** be deleted … wherever it sits — in a library-absent stub". The section's own
  first worked case is "`GetAddOnMetadata` behind `C_AddOns.GetAddOnMetadata` in a library-absent
  stub", and it names `core/EnvSetup.lua` as where the collection carried it.
- **Grade:** **Low.** Not reachable. `## Interface: 120100` admits no client with a bare
  `GetAddOnMetadata` and no `C_AddOns`.
- **What:** `core/EnvSetup.lua:93-94` (`if _G.GetAddOnMetadata then return _G.GetAddOnMetadata(...)`)
  sits below the `C_AddOns` rung (`:90-91`), in the branch taken when `LibKa0s-Env-1.0` is absent.
  `tests/test_envsetup.lua:146` pins it ("the deprecated bare global is still a live rung"). The
  comments at `settings/Slash.lua:64` and `core/PerfSetup.lua:94` defend "the pre-11.x rung".
- **Fix:** delete the rung and the case that pins it, and reword the two comments. Deleting the rung
  does not create a Compat shim (`compat`: "deleting it does not bring a `Compat.lua` into being").
- **Needs addressing?** **Yes, but it is the lowest-value item here.** The standard names this exact
  site as its worked case, so ratifying it instead would contradict the rule's own text. The fix is
  three lines and one test case.

## MM-A-28 *(new)* — The 1.1.0 release notes never told players the minimap row's CLI path changed

- **Section:** `launcher-§3`, *The row's schema path reads in the row's own sense*. The **MUST**:
  "The release notes **MUST** say that `/<slash> set <root>.minimap.hide <v>` became
  `/<slash> set <root>.minimap.shown <not v>`, because a player's macro is the one thing the rename
  can break". Commencement is "each addon's next release".
- **Grade:** **Low.** The rename is correct and needs no migration. What is missing is the player
  notice. A player with an old macro gets the unknown-setting refusal with nothing to say why.
  (Medium was considered and rejected. Nothing breaks unless such a macro exists, and the refusal is
  loud.)
- **What:** the rename landed in `e979ef0` ("MM-16: Rename the minimap row's CLI path to
  global.minimap.shown"), which is an ancestor of the 1.1.0 release commit `4c368c4`. The 1.1.0
  highlights (`README.md:97`) mention the minimap button's clicks and tooltip, but not the path.
  The README `## Version History` table is this addon's only player-facing history
  (documentation-§1 item 11).
- **Fix:** add the sentence to the next release's notes as a dated catch-up ("since 1.1.0,
  `/mm set global.minimap.hide <v>` is `/mm set global.minimap.shown <not v>`"). The owner may
  instead add it as a highlight to the 1.1.0 row. Either way the release-notes step of
  `/dev-copilot:bump-version` should check the launcher-§3 sentence.
- **Needs addressing?** **Yes, at the next release, at no cost now.** Once 1.1.0 has shipped, the
  only fix is the note itself, and it should not wait for a separate change.

## MM-A-29 *(new)* — Two documents still quote raw `lizard` as the complexity check, and `DEPENDENCIES.md` pins its version

- **Section:**
  - `automated-tests-§3`, *The complexity gate is sighted* (**MUST**). The rule is that
    `bash tests/_kit/run-automated-tests.sh --suite complexity` "is the one every gate line, every
    playbook and every `CLAUDE.md` quotes … the raw `lizard -l lua ...` line is the blind one".
    Anti-pattern #92 says the same.
  - `documentation-§7` (**MUST** "name versions where a version matters and say when it does
    not"). It states that "`lizard` stays 'any recent' … because the kit's sighted complexity suite
    checks function-count parity on every run".
- **Grade:** **Low.** This is documentation. The runner and the gate themselves are sighted and
  wired, so no measurement is blind.
- **What:**
  - `DEPENDENCIES.md:98`, the "Am I set up correctly?" block, reads
    `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .     # the complexity report (release-time)`.
    That is the raw, blind command, and it also lacks the kit's `-L 1500`.
  - `docs/automated-tests/README.md:38` gives the same raw command as the `complexity` suite's
    command. `docs/testing.md:597` already has it right.
  - `DEPENDENCIES.md:35`, `:58` (`pipx install lizard==1.24.0`) and `:68-70` pin `lizard` at
    1.24.0, "because the kit's sighted shadow is built against that release's blind spots". The
    standard rejects that reasoning in as many words: "parity, not a pinned version, is what notices
    a reader change".
- **Fix:** replace both raw commands with the runner's suite command, and return `lizard` to "any
  recent" with the parity sentence. If the owner wants the pin kept, it needs a register row citing
  `documentation-§7` with a re-check trigger, because a pin with no row is not ratified.
- **Needs addressing?** **The raw-command half, yes.** It is a copy-paste trap that undercounts in
  exactly the way #92 records. **The pin half is a judgment call.** It came from an owner-run sync
  (`8d09388`, "lizard pinned 1.24.0"), so the owner decides between un-pinning and filing a row.
  Silently leaving it is not one of the options.

## MM-A-30 *(new)* — The conformance suite's launcher step drives the left click only

- **Section:** `slash-commands-§7`, *The conformance test every addon ships* (**MUST**). Its step 8
  (rewritten at v2.67.0) says: drive `"LeftButton"` and assert the panel opener ran with no writes
  and no frame shows; then "drive it with `"RightButton"` through the kit's headless menu mock and
  assert the options menu opened with *Enabled* clickable and every other entry … grayed, and that
  opening it wrote nothing and showed no frame".
- **Grade:** **Low.** This is a test-coverage gap. The behavior itself is the library's and is
  correct.
- **What:** `tests/test_disabled.lua:479` ("Disabled 8: left-click opens the panel and writes
  nothing") drives `obj.OnClick(obj, "LeftButton")` (`:498`) and nothing else. The right-click half
  is in another suite, `tests/test_launchersetup.lua:373` ("Launcher menu: while disabled, everything
  but Enabled is grayed and inert"). That case asserts the grayed texts and that no verb ran. It
  never reads `__svWrites()` or the shown-frame set after opening the menu, so the "wrote nothing
  and showed no frame" clause is pinned nowhere.
- **Fix:** add the right-click half to step 8 in `tests/test_disabled.lua`, reusing
  `test_launchersetup.lua`'s `openMenu` helper. Assert the entry states and zero SV writes and frame
  shows after the menu opens, and add a falsification comment (`testing-§12`).
- **Needs addressing?** **Yes, small.** The suite is the standard's named executable form of the
  disabled contract, and step 8 is the only step it skips. It is about a dozen lines.

## MM-A-06 — `docs/ARCHITECTURE.md` is 578 lines, past the hub's ~400-line ceiling *(recurs, narrowed)*

- **Section:** `documentation-§3`, *`ARCHITECTURE.md` is a hub*. This is the **SHOULD**: "The whole
  file **SHOULD** stay under roughly 400 lines". The spill **MUST** is met.
- **Grade:** **Low.** Docs, and a SHOULD.
- **What (shape, not arithmetic):** down from 762 lines on 2026-09-23. Every mandated section that
  has a canonical topic doc has spilled. What holds the size is `## Documentation map` (`:317-390`,
  74 lines, including the conditional rows' measurement prose) and `## Documented deviations`
  (`:391-513`, 123 lines, including five paragraphs on retired rows, `:413-458`).
- **Fix:** move the retired-row narratives (`:413-458`) into the frozen bundles they cite, keeping a
  one-line pointer. Trim the Conditional table's measurement prose to the count. Either cut alone
  brings the file near the ceiling.
- **Needs addressing?** **Optional.** It is a SHOULD, and `AUDIT.md` says to report the shape and
  not argue the arithmetic. It is worth doing alongside MM-A-24's edits to the same sections, and not
  on its own.

## MM-A-26 *(Info)* — The newest automated-test record is unsighted and 53 commits behind HEAD *(recurs, updated)*

- **Section:** `automated-tests-§3`/`§6`. The checkpoint is the **release**, and the record **MUST
  NOT** gate commits.
- **Grade:** **Info.** Not a deviation.
- **What:** `20260927-030445` (the 1.1.0 release run, `abbb29e`, clean) predates kit revision 35. Its
  manifest therefore has no `suites.complexity.blindFiles`, and its "max CCN 15, 0 warnings" was
  measured blind. The first sighted run (`048639e`'s message: 8 functions above 15, max 39) was
  recorded only in a commit message. The GI-MM-02 refactors since have brought the sighted count to
  **0** (this run: pass, 0 warnings, max CCN 15, 4895 functions). `RESULTS.md`'s watch list still
  describes the unsighted run. Its band set (22 files) still matches the tree, but most LOC figures
  have moved.
- **Fix:** none now. The next release run writes the first sighted bundle, with `blindFiles`, the
  commit cell and a refreshed watch list.
- **Needs addressing?** **No action owed before the next release.**

---

## Closed since 2026-09-23

| ID | 2026-09-23 finding | Status today |
|---|---|---|
| MM-A-03 | Three Tier 2 docs owed, rows saying *Not applicable* | **Closed.** `slash-dispatch.md`, `message-bus.md` and `profiles.md` ship, and each row reads *Present* with its count (`docs/ARCHITECTURE.md:365-367`). |
| MM-A-08 | No wrapped-strip geometry case | **Closed by the standard.** Since v2.65.0 the library suite pins strips the library draws (`O.TabStrip`, `O.RenderTabbedSchema`), and a consumer **MUST NOT** duplicate the case (`options-ui-§13`). The addon's strips, the Windows General entry included, are library-drawn, and its suite carries no duplicate. |
| MM-A-16 | Closed issues carrying open-state labels | **Closed.** #4, #21 and #24 now carry `state:done`. All 58 issues carry exactly one state and one severity label. |
| MM-A-18 / 18a | `minimise` in player strings and stored keys, held by a debt waiver | **Closed.** The stored keys moved in schema v16 (`core/Database.lua:935-936`, `migrations[15]`). The waiver now covers only the two sanctioned shapes: a library's catalog key, and stored data matched on its own token (`tests/prose_waivers.lua:14-31`). |
| MM-A-20 | Bare event-registration block, no rejected record | **Closed.** All 22 registrations go through `NS.SafeRegisterEvent`, and rejected names are recorded and reachable (`core/MultiMeters.lua:214-223`, `core/Diagnostics.lua:224`). |
| MM-A-21 | Tag `1.0.1-release` shipped a `1.0.0` TOC | **Closed.** 1.1.0 was released with the bump, the history row and a release run (`20260927-030445`, `"release": "1.1.0"`). A 1.0.1 row records the re-publish (`README.md:98`). |
| MM-A-22 | Three load-bearing TOC lines unannotated | **Closed.** `MultiMeters.toc:55-57`, `:59-67` and `:163-164`, plus per-group "conventional order" headers. |
| MM-A-25 | Two `library-stack-§8` declines with no register row | **Closed.** The Tooltip target icon has a ratified row (`docs/ARCHITECTURE.md:410`, 2026-09-23). The grip moved into `LibKa0s-Core-1.0`'s `MakeResizable`, and its row was retired (`:413-418`). |
