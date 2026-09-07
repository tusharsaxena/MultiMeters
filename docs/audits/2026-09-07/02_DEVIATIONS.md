# 02 — Deviations (Ka0s Multi Meters, 2026-09-07)

Audited against **v2.38.0 (2026-09-02)**. Severity is **impact**, not rule strength
(`AUDIT.md` step 5): a doc-only or config-only failure is Low or Info **even when the rule it fails
is a MUST**, and every entry below names the MUST it fails.

## Tally, with its basis stated

- **Headline tally (roots only): 12.**
- **Total including `derived from` dependents: 13.**
- By grade, **roots**: High 0 · Medium 1 · Low 9 · Info 2.
- By grade, **including dependents**: High 0 · Medium 1 · Low 10 · Info 2.
- **MUST failures, roots only: 9** (MM-A-01, -02, -03, -04, -05, -06, -07, -08, -10).
  Including dependents: **9** (the one dependent, MM-A-02a, fails a SHOULD).
- Every MUST failure below is graded **Medium or Low**. That is the grading rule working, not the
  rules being optional: none of them is reachable by a player in the current code except MM-A-04.

Nothing on this list re-opens a ratified register row. The four rows in
`docs/ARCHITECTURE.md` `## Documented deviations` were read first and are recorded as **accepted**
in `03_EVIDENCE.md`; they do not count toward the MUST tally.

---

## MM-A-01 — Seven source files are over `layout-§1`'s 1500 LOC cap

- **Section:** `layout-§1` (**MUST** cap any single `.lua` file at 1500 LOC; a >1500 file is a bug)
- **Grade:** Low — structural. No player can reach a line count; the risk is latent (edit blast
  radius, review cost, an agent rewriting sections it never needed to open).
- **What:** `settings/Schema.lua` 3069, `modules/Tooltip.lua` 2652, `modules/Window.lua` 2644,
  `modules/Aggregator.lua` 2058, `modules/Export.lua` 1743, `core/Diagnostics.lua` 1726,
  `modules/Row.lua` 1702. `RESULTS.md`'s band table still records the last two of these as
  1371 and 1232, in the 1000–1500 *on notice* band — they are now roughly double the cap.
- **Fix:** peel each along the seam its own file header already names — `Schema.lua` by page,
  `Window.lua`'s header build into `modules/Window_Header.lua`, `Tooltip.lua`'s event/drilldown
  tables, `Diagnostics.lua` by probe. One file per change, suite green between each.

## MM-A-02 — The automated-test record is stale: the watch list predates two runs and today's code

- **Section:** `automated-tests-§4` (**MUST** carry the current complexity watch list),
  `anti-patterns` #51 (a record whose numbers no longer match the code)
- **Grade:** Low — a wrong record file. It is a finding about the **release** process, not a claim
  that commits should be gated on complexity.
- **What:** `docs/automated-tests/RESULTS.md:30` reads *"Current as of `20260809-195454`"* while
  two later bundles (`20260825-021705`, `20260825-103437`) sit beside it, and the whole
  settings-revamp-v2 branch has merged since. Measured drift today versus the newest bundle's
  `manifest.json`: CCN warnings **19 → 23**, max CCN **31 → 36**, total nloc **26531 → 31773**,
  functions **2884 → 3276**. Nine functions crossed the threshold since that bundle
  (`NS.ReorderableBlocks` 28, `doDebug` 23, `Window.place` 18, `reportFeignRoster` 17, two more
  `core/Database.lua` migration bodies at 17 and 16, `onPrintToChat` 16, `Row.Cell` 30,
  `scanColumn` 31 → 36), and seven files crossed the 1500 cap (MM-A-01). The watch list's own
  "**None.** `lizard` reports 0 warnings" is now false by 23.
- **Fix:** run `tests/_kit/run-automated-tests.sh` to produce a fresh bundle, let it rewrite
  `RESULTS.md`, then re-author the watch list against the new numbers with a disposition per entry.

### MM-A-02a — the two 2026-08-25 bundles carry no `ANALYSIS.md` *(derived from MM-A-02)*

- **Section:** `automated-tests-§5` (**MUST** at release, **SHOULD** otherwise)
- **Grade:** Low. Both bundles record `"release": null`, so this is the SHOULD, not the MUST.
- **Fix:** write one for the next bundle; do not back-fill a frozen one.

## MM-A-03 — Five Tier 2 docs are owed, and four register rows assert a false *Not applicable*

- **Section:** `documentation-§3` (Tier 2 — **MUST** ship under the canonical name when the trigger
  fires; *Not applicable* is a valid state and **MUST** be stated, but it must be true)
- **Grade:** Low — docs. Graded **above a bare omission**, per `AUDIT.md` step 4(b): a row that
  asserts something false is worse than an absent doc, because it tells the next reader the
  question is settled.
- **What**, each trigger re-measured against the code today:
  | Doc | Trigger, as the standard states it | Measured | Register row says |
  |---|---|---|---|
  | `slash-dispatch.md` | ≥ 8 commands **or any** subcommand tree | 16 commands **and** a `window` sub-verb tree | "Not applicable" |
  | `message-bus.md` | **more than ten** distinct messages | 14 | "Not applicable" |
  | `compat-layer.md` | addon-specific shims beyond LibKa0s | 761 lines, 28 shims | "Re-measure — the trigger now fires" |
  | `profiles.md` | AceDB profiles **user-visible** (a profile control ships in the UI) | `settings/Profiles.lua` registers a Profiles page | "Not applicable" |
  | `debug.md` | debug surfaces **beyond** the LibKa0s console | `/mm debug diag\|recap\|identity`, `core/Diagnostics.lua` 1726 lines | "Not applicable" |
  The rows argue *the material is small / carried elsewhere*, which is a good argument and a
  different one from the trigger the standard wrote. Three of them (`slash-dispatch`,
  `message-bus`, `profiles`) are refuted by their **own** stated numbers.
- **Fix:** ship the five docs (each is a spill from an `ARCHITECTURE.md` section that is already
  over length — see MM-A-06, which this closes half of), and replace the five evaluation rows with
  registered Tier 2 rows. If a trigger is genuinely wrong for the collection, that is a
  **standards-upstream** change to `documentation-§3`, filed there, not a "Not applicable" row here.

## MM-A-04 — `.pkgmeta` ships `.claude/` and `.superpowers/` to players

- **Section:** `packaging` (**MUST** ignore dev-only entries; every root dot-entry accounted for)
- **Grade:** **Medium** — reachable and concrete. A player's `Interface/AddOns/MultiMeters/`
  receives **90 files and 2.4 MB** of agent tooling: SDD task briefs, reports, reviews and raw
  `.diff` files. Not a crash, so not High; not latent either, so not Low.
- **What:** `.pkgmeta:5-18` lists `.luacheckrc`, `.gitignore`, `.gitattributes`, `.pkgmeta`,
  `docs`, `tests`, `_dev`, `*.bak`, `media/logos/*.png`, `media/logos/*.jpg`. `.claude` and
  `.superpowers` are absent from the list and present in the repo.
- **Fix:** add `  - .claude` and `  - .superpowers` to the `ignore:` block. Then adopt the
  enumeration-proof check (`AUDIT.md` step 4, packaging (b)) so the next new dot-directory cannot
  ship silently.

## MM-A-05 — 21 tracked files disagree with the declared CRLF pin

- **Section:** `line-endings-§1` / `line-endings-§7` (**MUST**: the working tree agrees with the
  declared pin)
- **Grade:** Low — hygiene. Reported as **one** rolled-up finding with the command, never a file
  list: the fix is a single action.
- **What:** `.gitattributes` itself is correct and complete — the pin at `:26`, the mandatory
  `*.sh` carve-out at `:34`, 20 ` binary` lines, body matching the canonical client-bound file.
  The tree is what disagrees: **21** tracked non-binary files hold LF where `eol=crlf` is declared.
  Command and output are in `03_EVIDENCE.md`. This is the corrected v2.28.1+ check, which counts
  neither binaries nor JSON; a pre-v2.28.1 number for this repo would have been several times
  larger and is not comparable.
- **Fix:** `git add --renormalize .`, commit, then delete and re-checkout the tree. One commit.

## MM-A-06 — `docs/ARCHITECTURE.md` has stopped being a hub

- **Section:** `documentation-§3`, *`ARCHITECTURE.md` is a hub, and the spill rule keeps it one*
  (**MUST** spill a mandated section past ~60 lines into its canonical topic doc; **SHOULD** keep
  the file under ~400 lines)
- **Grade:** Low — docs.
- **What (shape reported, arithmetic not argued):** the file is **787** lines. Four mandated
  sections have not spilled: *Known limitations* `:452-636` (**~184 lines**), *Taint notes*
  `:304-409` (~105), *Event subscriptions* `:233-304` (~71), *Overview* `:11-77` (~66). The four
  sections that the rule names explicitly — Module Map, Settings Schema, Slash Commands, Message Bus
  — **have** spilled and are 24/51/40/41 lines; those are compliant and are not the finding.
- **Fix:** spill *Taint notes* into `docs/midnight-quirks.md`, *Slash Commands* detail into the
  `slash-dispatch.md` MM-A-03 already owes, and *Known limitations* into `docs/scope.md`'s
  out-of-scope half, leaving a summary and one link each. Ordering constraint: do MM-A-03 first —
  three of its five docs are where these sections spill **to**.

## MM-A-07 — Blizzard `ReadyCheck` art where the shared catalog has the glyph

- **Section:** `library-stack-§8` / `layout-§3` (draw marks from the shared catalog, not one-offs)
- **Grade:** Low — a cosmetic inconsistency in the surface a player compares between addons; not a
  wrong value and not a failure.
- **What:** `settings/ColumnBlocks.lua:60-61` hard-codes
  `Interface\RaidFrame\ReadyCheck-Ready` / `-NotReady` for a block's enabled/disabled mark while
  `libs/LibKa0s/media/icons/` ships `circle-check`, `confirm`, `ban` and `cancel`. The comment at
  `:58-59` gives the reason — matching ConsumableMaster's priority list — which makes this
  **cross-cutting**: two addons drawing the same non-catalog pair is the catalog not being adopted
  twice, not a local choice.
- **Fix:** move both to `NS.Icon("circle-check")` / `NS.Icon("ban")` in *both* addons in one change,
  or ratify the pair as a register row in both. Do not fix one side alone.

## MM-A-08 — No suite case pins a wrapped tab strip's geometry against the selection

- **Section:** `options-ui-§13` (a wrapped strip's geometry **MUST NOT** move with the selection),
  `testing-§12` (the case that would fail is the case that counts)
- **Grade:** Low — not reachable today. No page currently declares enough tabs to wrap (the widest
  is `bars` and `tooltip` at six), so the defect this case guards is latent until a label is added.
- **What:** the library side is correct — `libs/LibKa0s/OptionsWidgets.lua:423-442` takes the row
  pitch from the **unselected** tab art and caches it, and `:601-602` records the same reasoning
  for the wrap index. The addon's suite does not pin it: `tests/test_options_panel.lua` has no
  case asserting the reserved band and every row's y offset are identical for every value of the
  selection. Its nearest case, `:630-638`, asserts only that each page opens on its first tab and
  drew a strip.
- **Fix:** add one case that renders each page under every selection and asserts the chrome height
  and each tab row's y offset are equal across all of them. The mutation it must die under:
  make `tabArtHeight()` read the **selected** button's art.

## MM-A-09 — The README's tests badge is stale

- **Section:** `documentation-§1` (badge row; the README carries the `[tests]` badge and the
  contributor detail stays in `docs/testing.md`)
- **Grade:** Low — a wrong doc line, and the direction is the harmless one (understated).
- **What:** `README.md:7` reads `Tests-1487%2F1487_passing`; `lua tests/run.lua` reports
  **1496 passed / 1496 total** today.
- **Fix:** update the badge as part of the same change that adds a test, or generate it from the
  run bundle's `manifest.json` so it cannot drift again.

## MM-A-10 — `docs/audits/` and `docs/reviews/` are not registered in the `## Documentation map`

- **Section:** `documentation-§3`, *`## Documentation map`* (**MUST** name each frozen store as a
  directory, once each — `docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`,
  `docs/perf-analysis/<run>/`, `docs/superpowers/`, `docs/investigations/`)
- **Grade:** Low — docs.
- **What:** the map (`docs/ARCHITECTURE.md:636-699`) registers `superpowers/` and `revendor/` as
  stores and every live `.md`, with no dangling row and no orphan — it was **correct** before this
  run. This bundle creates `docs/audits/2026-09-07/`, and a concurrent review run has created
  `docs/reviews/2026-09-07/`, so **two** store rows are owed the moment they land. Filed rather than
  waived because the map is checked in both directions and an unregistered directory is exactly what
  the check exists to surface.
- **Fix:** two rows — `` | `audits/` | Frozen — one dated bundle per standards audit | `` and
  `` | `reviews/` | Frozen — one dated bundle per code review | `` — in the *Topic detail* table
  beside `revendor/`. **Do not** add a row per audit or per review.

## MM-A-11 *(Info)* — Issue #17's perf-ceiling claim no longer reproduces

- **Section:** `audit-review-history` (the issue store is the working queue; a `state:untriaged`
  issue is an open claim)
- **Grade:** Info — an observation about the queue, not a defect in the addon.
- **What:** issue **#17** (`bug`, `state:untriaged`, `severity:medium`) reads *"Both allocation
  ceilings in `tests/perf.lua` are breached on master"*, and both 2026-08-25 manifests record
  `"perf": {"status": "fail"}`. `lua tests/perf.lua` today runs all 13 scenarios and exits **0**,
  with `refresh20x7` at 310158.1 and `refresh20x7Restricted` at 412373.3 bytes/iter, both under
  their asserted ceilings.
- **Fix:** re-run, then close #17 as `state:done` citing the run, or re-triage it with the
  measurement that still fails. Leaving it untriaged makes the release gate's amber verdict
  unreadable.

## MM-A-12 *(Info)* — `options-ui-§16`'s composer grep flags two rows that are not a group

- **Section:** `options-ui-§16` (*every* `LSM30_*` hit **MUST** be a composer call site)
- **Grade:** Info — recorded so the next audit does not re-file it, and so the ambiguity reaches
  the standard.
- **What:** `settings/Schema.lua:1554` (`LSM30_Statusbar`) and `:1562` (`LSM30_Font`) are
  **not** composer call sites. They are two single meta-rows on the Frame page's *All surfaces*
  subgroup (`window.barTexture`, `window.font`) that broadcast to the composed groups elsewhere —
  `broadcastBarTexture` / `broadcastFont` — rather than a hand-written font or bar block. The
  addon's fourteen actual font/border/bar/color groups are all composed. The rule's mechanical
  form catches these; the rule's stated intent (anti-pattern #73, a hand-written *copy* of a
  block) does not.
- **Fix:** upstream — narrow `options-ui-§16`'s grep clause to hits that reproduce a mandated
  **block**, or have the library expose a composer for the addon-wide broadcast meta. No local
  change is warranted meanwhile.

---

## Checked and compliant — recorded so the next run does not re-derive them

| Check | Result |
|---|---|
| `diff -r LibKa0s@v1.25.0/LibKa0s libs/LibKa0s` | empty — no #45 drift, no #48 partial vendoring |
| `diff -r LibKa0s@v1.25.0/testkit tests/_kit` | empty |
| LibKa0s provenance line | `CLAUDE.md:52` only; 0 hits in `README.md` — not #59, not #58 |
| Standard badge | bare `![Standard](…)` at `README.md:6`, not link-wrapped |
| README bundled-library inventory | none; `## Credits` holds external font/icon credit only |
| `MakeCloseButton` grep | one wrapper (`core/CoreSetup.lua:239`), one call site, no #65 |
| Perf-panel `decorate` hook | deliberately absent, reasoned at `core/PerfSetup.lua:206` |
| Degradation stubs | every reached member answered; 23 degraded cases green |
| `X-Curse-Project-ID` | absent **with** the comment in its position — `toc-file-§1` compliant |
| TOC position annotations | every load-bearing line names what resolves |
| `libs\LibKa0s\LibKa0s.xml` in TOC | listed once, in `# Libraries`, after Ace3 |
| Tier 1 docs | all six present under the canonical names |
| Non-canonical Tier 1/2 filenames | none |
| Retired docs (`file-index`, `conventions`, `complexity.md`, `perf-runs/`, `pending/LEDGER.md`) | none present |
| `## Documentation map` | no orphan, no dangling row (see MM-A-10 for the store owed) |
| `[status]` title prefixes on issues | none — labels are the store |
| `disabledIf` on a color row | none |
| Chat-scroll reorder art | none; shared `ReorderList` used |
| Class-color companions | present on every non-exempt color row; the one gap is a ratified row |
| General page's first tab | exactly `Master controls`, composed (`settings/Schema.lua:849`) |
| Master-controls migration | no stored-type change to migrate — `master.visibility` is a **new** path, and the runner is at v13 (`core/Database.lua:683`) |
| `.luacheckrc` | matches the canonical body; both perf entries present and warranted |
| `.gitattributes` body | canonical client-bound variant, pin + `*.sh` + binaries |
| Private media copy | none — `media/` holds the logo and one statusbar texture |
