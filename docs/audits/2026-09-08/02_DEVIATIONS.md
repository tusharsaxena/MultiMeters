# 02 — Deviations (Ka0s Multi Meters, 2026-09-08)

Audited against **v2.39.0 (2026-09-07)**. Severity is **impact**, not rule strength (`AUDIT.md`
step 5): a doc-only or config-only failure is Low or Info **even when the rule it fails is a MUST**,
and every entry below names the MUST it fails.

## Tally, with its basis stated

- **Headline tally (roots only): 9.**
- **Total including `derived from` dependents: 10.**
- By grade, **roots**: High 0 · Medium 0 · **Low 8** · Info 1.
- By grade, **including dependents**: High 0 · Medium 0 · Low 9 · Info 1.
- **MUST failures, roots only: 7** — MM-A-03, MM-A-08, MM-A-13, MM-A-14, MM-A-15, MM-A-16,
  MM-A-18. MM-A-06 fails a **SHOULD**; MM-A-17 is an observation. Dependents are excluded from the
  MUST count, so including MM-A-18a the number is still **7**.
- **Nothing on this list is reachable by a player except the two locale values under MM-A-18**, and
  those are a spelling, not a wrong value — which is why nothing here is graded above Low.

**Previous run:** 12 roots / 13 total (2026-09-07, against v2.38.0). **Nine of those twelve are
closed**; the closures are itemized at the foot of this file, with the evidence in `03_EVIDENCE.md`.

**Nothing here re-opens a ratified register row.** The five rows in `docs/ARCHITECTURE.md`
`## Documented deviations` were read **first**, each row's cited rule re-checked against v2.39.0,
each re-check trigger evaluated against this tree, and each evidence id resolved. All five stand and
are recorded as **accepted** in `03_EVIDENCE.md`; they do not count toward the MUST tally. Neither
does `layout-§1` — all fifteen over-cap files sit in one of that rule's three terminal states, and
the rule forbids re-filing against them.

---

## MM-A-18 *(new)* — British spellings across authored source, locale values, identifiers and docs

- **Section:** `localization-§5` (**MUST** — "Every English word a Ka0s addon **authors MUST use US
  English spelling**", binding locale keys and values, everything the player reads, prose in
  `README.md` and every file under `docs/`, **and code: comments and identifiers")
- **Grade:** **Low.** Nothing breaks, no value is wrong, no path errors. The two `locales/enUS.lua`
  entries are the only player-reachable part and they read as correct English in the wrong dialect.
  The rest is comments, identifiers and prose — a convention gap, which is what Low is for.
- **What:** the published `BRITISH`/`ALLOWED` lists (`localization-§5`, *The canonical list*), run
  whole over the authored set with the four exclusions the section names, match **830 lines across
  65 files**. Command, scope and output in `03_EVIDENCE.md`. The concentration is `colour` (481
  hits), `minimis` (107), `behaviour` (49), `centre` (41), `labelled` (35), `grey` (28), `honour`
  (18), `neighbour` (14), `judgement` (10), `cancelling` (9), `catalogue` (6), `recognis` (5). The
  player-facing subset is small and specific:
  - `locales/enUS.lua:213` — `L["Show minimise"] = "Show minimise"` (a Header-page option label)
  - `locales/enUS.lua:230` — `L["Minimised"] = "Minimised"` (a window control's caption)
  - `README.md:109`, `:113` — `colour` in the settings-panel table's prose
- **Why it went unfound:** the repo ships **no US-English gate**. `tests/test_locale.lua`'s eleven
  cases assert key shape, fallbacks, format specifiers and uniqueness, and none of them reads a
  spelling. `localization-§5` published the two lists in v2.39.0 precisely because every private
  gate in the collection was a subset; this repo's is the empty subset.
- **Fix:** three changes, in this order. (1) Vendor the published `BRITISH` and `ALLOWED` lists
  **whole** into a new case in `tests/test_locale.lua` with the four exclusions named file by file,
  so the sweep cannot regress. (2) Fix comments, prose and non-stored identifiers — mechanical, one
  commit per folder, suite green between each. (3) The locale-key ripple and the stored paths are
  MM-A-18a and are **not** part of (2).

### MM-A-18a — the British spelling reaches two stored paths, so it needs a migration and not a rename *(derived from MM-A-18)*

- **Section:** `localization-§5` (identifiers, settings keys) with `savedvariables` (a stored key
  change is a `schemaVersion` bump plus a migration step)
- **Grade:** Low. Latent: nothing is wrong today, and it is the *fix* that carries the risk.
- **What:** `defaults/Profile.lua:130` declares `showMinimise = true` and the header's collapse
  state is stored at `window.frame.minimised`, declared `hidden` in the schema. Both are British.
  A find-and-replace would silently drop every player's stored value, because AceDB merges defaults
  by key and an unknown old key is simply orphaned.
- **Fix:** if these are corrected at all, they go through `core/Database.lua`'s migration runner as
  a keyed move (old → new, then prune), with a `schemaVersion` bump and a case pinning the move —
  never a rename. Deciding **not** to correct a stored key is a legitimate answer and is then a
  `## Documented deviations` row citing `localization-§5`, not a silent exception.

## MM-A-03 — Four Tier 2 docs are owed, and four register rows assert a *Not applicable* the trigger refutes

- **Section:** `documentation-§3`, *Tier 2* (**MUST** ship under the canonical name when the stated
  trigger fires; *Not applicable* is a valid state and **MUST** be stated, but it must be true)
- **Grade:** **Low** — docs. Graded **above a bare omission** per `AUDIT.md` step 4(b): a row that
  asserts something false tells the next reader the question is settled.
- **What**, each trigger re-measured against the code today and against the **v2.39.0** wording:
  | Doc | Trigger, as `documentation-§3` states it | Measured today | Register row says |
  |---|---|---|---|
  | `slash-dispatch.md` | `NS.COMMANDS` carries **eight or more** commands, **or any** subcommand tree | **16** commands **and** a `window` sub-verb tree | "Not applicable" (`docs/ARCHITECTURE.md:432`) |
  | `message-bus.md` | the addon defines **more than ten** distinct messages | **14** | "Not applicable" (`:433`) |
  | `profiles.md` | AceDB profiles are **user-visible** (a profile control ships in the options UI) | `settings/Profiles.lua:57` declares `local PAGE = "profiles"` and the file hosts AceDBOptions' create/switch/copy/reset/delete tree in the panel | "Not applicable" (`:436`) |
  | `debug.md` | the addon ships debug surfaces **beyond** the LibKa0s default console | `/mm debug diag`, `recap`, `identity`, `feign`; `core/Diagnostics.lua` is **1824** lines | "Not applicable" (`:437`) |
  Three of the four rows are refuted by **their own stated numbers**. The fourth understates its
  own evidence: the `debug.md` row says Diagnostics is "~1570 lines" and it is 1824.
- **Two Tier 2 docs did close this cycle** and are not in this entry: `compat-layer.md` and
  `midnight-quirks.md` are written and registered. The `compat-layer` trigger is now a number —
  three or more shims, counted by `documentation-§3`'s own grep — and this addon measures **28**.
- **Not covered by the register:** these are `## Documentation map` evaluation rows, and
  `documentation-§3` says in as many words that a *Not applicable* row is **deliberately not** a
  `## Documented deviations` row. So nothing here is a ratified decision that this run is
  re-litigating; they are compliance claims, and four of them are false.
- **Fix:** ship the four docs — each is a spill from an `ARCHITECTURE.md` section that already
  exists, so this is a move, not new writing — and convert the four rows to Tier 2 registrations in
  `### Conditional`. If a trigger is genuinely wrong for the collection, that is an upstream change
  to `documentation-§3`, filed there. Do this **with** MM-A-13, which rewrites the same table.

## MM-A-13 *(new, visible only against the amended standard)* — `## Documentation map`'s tables are not the four the standard now mandates

- **Section:** `documentation-§3`, *`### Verification and record` — the fourth table* (**MUST** carry
  four tables — `### Required`, `### Conditional`, `### Verification and record`,
  `### Addon-specific` — with the third placed **after Conditional and before Addon-specific**, and
  the verification table holding **exactly six** named rows)
- **Grade:** **Low** — docs. No reader is misled about a *file*; the register's coverage is complete
  in both directions. What is wrong is its shape.
- **What:** the register ships four tables under four different headings, in the wrong order and
  with the wrong membership:
  - `docs/ARCHITECTURE.md:386` `### Canonical trio (Tier 1)` — holds `ARCHITECTURE.md`,
    `testing.md`, `smoke-tests.md`. Two of those three belong in `### Verification and record`.
  - `:394` `### Verification and record` — **second**, where the MUST puts it third, and holding
    **five** rows rather than six: `testing.md` and `smoke-tests.md` are missing, and
    `perf-analysis/README.md` is present although the standard settles it explicitly —
    "**`perf-analysis/README.md` registers in `### Conditional`, not here**", in both of its states.
  - `:404` `### Topic detail` — mixes Tier 1 (the six canonical docs), Tier 2 (`compat-layer.md`,
    `midnight-quirks.md`) and Tier 3 (`superpowers/`, `revendor/`, `audits/`, `reviews/`) in one
    table where the standard has three.
  - `:421` `### Tier 2 conditional docs — evaluated at v0.1.0` — the conditional table, **last**.
  - `:372` still reads *"Every `.md` under `docs/` appears in exactly one of the **three** tables
    below"* above four tables — the old three-table MUST, quoted in the file that now breaks it.
  - `:427` reads *"This is an evaluation record, **not a fourth register table**"* — exactly the
    note `documentation-§3` says is deleted: "any repo carrying a note that justifies the extra
    table against the old three-table MUST deletes that note: the table is now the rule."
- **Not filed:** the `ARCHITECTURE.md` self-row at `:390`. `documentation-§3` makes it a **MAY** and
  forbids an audit filing its presence *or* its absence.
- **Fix:** rename and reorder to the four mandated headings; move `testing.md` and `smoke-tests.md`
  into `### Verification and record` and `perf-analysis/README.md` out of it into
  `### Conditional`; split `### Topic detail` into `### Required` (the six Tier 1 docs) and
  `### Addon-specific` (the four stores); correct "three" to "four" at `:372`; delete `:427`'s note.
  One edit, and it is the same edit MM-A-03 needs — do them together.

## MM-A-06 — `docs/ARCHITECTURE.md` is 773 lines, past the hub's ~400-line ceiling

- **Section:** `documentation-§3`, *`ARCHITECTURE.md` is a hub, and the spill rule keeps it one*
  (the **SHOULD**: "The whole file **SHOULD** stay under roughly 400 lines")
- **Grade:** **Low** — docs, and a **SHOULD**, not a MUST. Named separately from every other entry
  because the MUST half of the same rule is now **met**.
- **What (shape reported, arithmetic not argued):** 787 → **773** lines. Every mandated section that
  has a canonical topic doc to spill to has spilled and is now well under the 60-line threshold —
  Overview 32, Module map 24, Settings schema 51, Message bus 41, Slash commands 40, Event
  subscriptions 45, Taint notes 56, Known limitations 27. That is the 2026-09-07 finding closed, and
  `tests/test_doc_structure.lua` now asserts it. What keeps the file at 773 is three register
  sections that have nowhere to spill to and are the hub's own content: `## Documentation map`
  (`:370-438`, 69 lines), `## Documented deviations` (`:439-619`, 181) and `## Complexity register`
  (`:620-741`, 122) — **372 lines between them**. Of the 181, the register table itself is 71 and
  the two census tables beneath it are `### Files over the 1500-line cap` (`:510-558`, 49) and
  `### Hard-coded texture paths` (`:559-619`, 61).
- **Fix:** the two census tables under `## Documented deviations` are the movable part. The over-cap
  census duplicates `docs/automated-tests/RESULTS.md`'s own band table almost row for row; the
  texture census is a Tier 3 subject. Move both out (a Tier 3 doc registered in
  `### Addon-specific`, or into `RESULTS.md` for the first), leave a summary and one link each, and
  the hub lands near 660. Under 400 needs the complexity register to move too. **Ordering:** after
  MM-A-13, which renumbers everything below `:370`.

## MM-A-08 — No suite case pins a wrapped tab strip's geometry against the selection

- **Section:** `options-ui-§13` (**MUST**: "on a strip wide enough to **wrap**, the total reserved
  band and every row's y offset are **identical for every value of the selection**"), `testing-§12`
- **Grade:** **Low** — not reachable today. No page declares enough tabs to wrap (the widest are
  `bars` and `tooltip` at six), so the defect the case guards is latent until a label is added.
- **What:** the library side is correct and, since the v1.27.0 payload, **testable** — `tabArtHeight`
  reads the unselected art (`libs/LibKa0s/OptionsWidgets.lua:441`) and the arithmetic is published
  as seams at `:994` (`O.__tabArtHeight`, `O.__tabPlacement`, `O.__tabBand`). LibKa0s' own suite
  exercises those seams. **This addon's does not**: `grep -n '__tabPlacement\|__tabBand\|__tabArtHeight' tests/`
  returns nothing, and the nearest case — `tests/test_options_panel.lua:760-768` — asserts only that
  each page opens on its first tab and drew ≥2 tab kids.
- **This is the one entry the 2026-09-07 cycle deliberately deferred** (`MULTIMETERS-A-08` →
  `M1-LK-08`). The library half of that item landed; the addon half did not, and was not scheduled
  to.
- **Fix:** one case that renders each page under every value of the selection and asserts the chrome
  band and each tab row's y offset are equal across all of them, driven through the published seams
  so no live client is needed. The harness **MUST** answer a different height for selected-state art
  or the case is green against nothing. **The mutation it must die under:** make `tabArtHeight()`
  read the selected button's art.

## MM-A-14 *(new)* — The README badge row carries a non-canonical `Version` badge in slot 2

- **Section:** `documentation-§1` item 2 (**MUST**: "a fixed set of five shields.io badges, in this
  exact order, matching these canonical templates verbatim"; slot 2 is the live
  `![CurseForge Version](https://img.shields.io/curseforge/v/<projectId>)`, "add it only after first
  publish")
- **Grade:** **Low** — a wrong doc line. Nothing a player can act on wrongly.
- **What:** `README.md:4` is `![Version](https://img.shields.io/badge/Version-0.1.0-blue)` — a
  static badge matching no template in the table, sitting in the slot reserved for the live
  published-version endpoint. MultiMeters is unpublished, so the compliant row is **four** badges,
  which is what the other eight addons in the collection ship (each has the CurseForge endpoint in
  slot 2 because each is published; none carries a static `Version` badge). It is also a second
  hand-maintained copy of the TOC's `## Version: 0.1.0` with no keep-in-sync rule behind it.
- **Fix:** delete `README.md:4`. Add the CurseForge endpoint badge in that position at first
  publish, in the same change that adds `X-Curse-Project-ID` to the TOC.

## MM-A-15 *(new)* — The README ships no logo image

- **Section:** `documentation-§1` item 3 (**MUST**: "**Logo** — the addon logo image")
- **Grade:** **Low** — a missing doc element. Not reachable in the game.
- **What:** `grep -n '!\[' README.md` returns exactly five lines, all of them badges (`:3`–`:7`).
  There is no `![Logo](…)` between the badge row and the description, which is where the
  canonical structure puts it and where all eight sibling addons carry one. The art exists —
  `media/logos/multimeters.logo.png`, `.jpg` and `.tga` are committed — so this is an omission in
  the README, not a missing asset.
- **Fix:** one line after the badge row, pointing at the committed `.jpg` (or at the CDN copy once
  published, which is what the siblings do).

## MM-A-16 *(new)* — Four **closed** issues carry `state:triaged`, a label the vocabulary binds to **open**

- **Section:** `audit-review-history` (**MUST** carry status as a label "drawn from a closed
  vocabulary of four", whose table binds `state:triaged` to issue state **open** and gives closed
  issues `state:done` or `state:will-not-do`)
- **Grade:** **Low** — a record defect in the working queue. No user reaches a label.
- **What:** `gh issue list --state all --limit 200` returns 46 issues; **four are CLOSED and labeled
  `state:triaged`** — **#4** ("Wire up the shipped bar texture"), **#6** ("Move every window control
  into the header"), **#7** ("Ship custom icons for the addon's own glyphs"), **#21** ("Promote the
  Columns page's drag-to-reorder block list to LibKa0s"). Each therefore appears in a
  `--label "state:triaged"` query, which is the query a triage session runs to find what is open and
  accepted, and none of them is. The rest of the store is clean: every issue carries exactly one
  `state:` and one `severity:` label, and no title carries a `[status]` prefix (anti-pattern #62).
- **Fix:** re-label each to its terminal value — #21 is implemented (the widget shipped as
  `LibKa0s-Widgets-1.0`'s `ReorderList`, and the register records the retirement) so it is
  `state:done`; #4, #6 and #7 are read against what shipped and take `state:done` or
  `state:will-not-do`. Four `gh issue edit` calls, spaced.

## MM-A-17 *(Info)* — The newest run bundle predates `master` by four commits

- **Section:** `automated-tests-§6` (the checkpoint is **release**, and it **MUST NOT** gate commits)
- **Grade:** **Info** — recorded so the next run does not read the two numbers as a stale record.
  It is not a deviation: `automated-tests-§6` explicitly forbids gating commits on a bundle.
- **What:** `docs/automated-tests/20260908-181355/manifest.json` stamps `a348545` on the feature
  branch; `master` is four commits ahead at `990bfc7`. The bundle records 1530 cases over 93 lint
  files; today's tree runs **1534** over **94** — `M4c-06` added `tests/test_lintconfig.lua` after
  the run. Complexity is **unmoved**: 23 warnings and max CCN 34 in both, with nloc 32913 → 33091.
  No function crossed a threshold and no file entered or left a `layout-§1` band.
- **Fix:** none needed now. The next **release** run reconciles it, and this addon has never cut a
  tag — the release gate is `suites.complexity.warnings == 0` and it stands at 23, which
  `## Complexity register` and the watch list both state plainly.

---

## Closed since 2026-09-07 — nine of twelve, with the evidence

| ID | 2026-09-07 finding | Status today |
|---|---|---|
| MM-A-01 | Seven source files over the 1500 LOC cap | **Closed by disposition.** Fifteen files (v2.39.0's scope) each in a `layout-§1` terminal state: eight issues `#27`–`#34`, seven under a register row. The rule forbids re-filing. |
| MM-A-02 | Automated-test record stale; watch list said "None" over 19 warnings | **Closed.** Bundle `20260908-181355`; `RESULTS.md` regenerated with a disposition per warned function (11 Accepted, 12 Peel, each with an issue). |
| MM-A-02a | The two 2026-08-25 bundles carry no `ANALYSIS.md` | **Closed forward**, as `automated-tests-§5` requires: the new bundle has one, and it notes the gap once (`docs/automated-tests/20260908-181355/ANALYSIS.md:118-124`). No backfill. |
| MM-A-03 | Five Tier 2 docs owed | **Partially closed** — two shipped, four remain. See above. |
| MM-A-04 | `.pkgmeta` ships `.claude/` and `.superpowers/` | **Closed.** Both listed (`.pkgmeta:20-21`); enumeration-proof sweep prints only `.git`. |
| MM-A-05 | 21 tracked files disagree with the CRLF pin | **Closed.** The `line-endings-§7` command returns **0**, and `tests/_kit/test_eol.lua` (kit revision 15) now owns the check. |
| MM-A-06 | The hub had stopped being a hub | **Partially closed** — the spill MUST is met; the ~400 SHOULD is not. See above. |
| MM-A-07 | Blizzard `ReadyCheck` art where the catalog has the glyph | **Closed by ratification**, not by the fix the plan named. A `library-stack §8` row was filed 2026-09-08; ConsumableMaster's three sites still stand, so the parity argument holds and the row's trigger has not fired. |
| MM-A-08 | No wrapped-strip geometry case | **Still open** (deliberately deferred). See above. |
| MM-A-09 | Stale tests badge | **Closed.** Badge, `docs/test-cases.md` and the run all read **1534**. |
| MM-A-10 | `audits/` and `reviews/` unregistered | **Closed.** Both rows present (`docs/ARCHITECTURE.md:418-419`). |
| MM-A-11 | Issue #17's perf claim no longer reproduces | **Closed.** #17 is CLOSED, `state:done`; `lua tests/perf.lua` runs 15 scenarios and exits 0. |
| MM-A-12 | `options-ui-§16`'s grep flags two rows that are not a group | **Closed upstream, and this is the amendment doing its job.** v2.39.0 names the addon-wide broadcast meta row as the one exemption and cites `MultiMeters/settings/Schema.lua:1553-1566` as the live case — the two rows sit at `settings/Schema.lua:1563-1579` in this tree today, the standard's line range having been taken a few edits earlier. Re-audited against the five bounds it attaches: compliant. |
