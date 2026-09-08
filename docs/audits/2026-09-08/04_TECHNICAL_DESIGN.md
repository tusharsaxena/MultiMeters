# 04 — Technical design (Ka0s Multi Meters, 2026-09-08)

How to close the nine root deviations in `02_DEVIATIONS.md`. Every heading is keyed to a deviation
ID. Nothing here touches the addon's behavior: eight of the nine are documents, configuration or
test coverage, and the ninth (MM-A-18) is a spelling sweep whose only behavioral edge is carved out
into MM-A-18a and deliberately left as a decision rather than a change.

**Read the ordering constraints first.** Three pairs collide:

- **MM-A-13 before MM-A-03.** Both rewrite `## Documentation map`. MM-A-13 renames and reorders the
  tables; MM-A-03 moves four rows between them. Doing MM-A-03 first means writing rows into tables
  that are about to be renamed.
- **MM-A-13 before MM-A-06.** MM-A-13 renumbers everything below `docs/ARCHITECTURE.md:370`, and
  MM-A-06 is a set of moves keyed to line ranges under it.
- **MM-A-18's gate before MM-A-18's sweep.** The gate is what makes the sweep checkable; writing it
  after the sweep means the sweep is verified by the person who did it.

---

## MM-A-18 — the US-English sweep, and the gate that keeps it swept

**Files:** a new case in `tests/test_locale.lua`; then 65 files across `core/`, `modules/`,
`settings/`, `defaults/`, `locales/`, `tests/`, `docs/` and `README.md`.

### The gate first

`localization-§5` specifies exactly how a gate reads the two lists, and each clause is a design
constraint rather than advice:

- **Both lists whole.** Copy the 91 `BRITISH` substrings and the 30 `ALLOWED` whole words verbatim
  out of `localization-§5`'s canonical list. **MUST NOT** carry an entry that is not published
  there, and **MUST NOT** carry a subset — a subset's green is unreadable, which is the state this
  repo is in now.
- **`ALLOWED` is removed as whole words, before the scan.** Delimit on non-letters, drop matched
  tokens, then run the `BRITISH` substrings over what is left. Substring-matching `ALLOWED` would
  swallow *analysed* inside the allowance for *analyses*.
- **The four exclusions are named path by path in the gate**, never inferred from a pattern:
  `libs/`, `tests/_kit/` (vendored); `docs/audits/`, `docs/reviews/`, `docs/superpowers/`,
  `docs/revendor/`, `docs/automated-tests/<run>/` (frozen record); `locales/enGB.lua` (does not
  exist here, and is listed anyway so adding one does not silently redden the suite); and the gate's
  own copy of the lists.
- **Where it lives.** `tests/test_locale.lua`, beside the eleven cases that already read the locale
  file. It walks the tracked set the same way `tests/test_texture_paths.lua` and
  `tests/test_layout_cap.lua` do, so the file-walking idiom is already in this repo and does not
  need inventing.

The case must **fail before it passes**: land it red, with the 830 lines it reports printed, then
fix in the order below until it is green. A gate written after the sweep is a gate nobody has seen
fail.

### The sweep, in four commits

1. **`docs/` and `README.md`** — prose only, no identifier risk. The largest single file is
   `docs/smoke-tests.md` (73 lines). `README.md:109` and `:113` are the only player-facing prose.
2. **Comments in `core/`, `modules/`, `settings/`, `defaults/`** — no identifier changes, so no call
   site moves and the suite cannot go red for a reason that is not a typo.
3. **Non-stored identifiers** — locals, function names, table keys that are **not** a settings path
   and **not** a locale key. Each one is a rename plus its call sites, and `luacheck` catches a
   missed site as an undefined global, which is the whole reason this step is separable.
4. **Locale keys and values** — `locales/enUS.lua:213` and `:230`. `localization-§5`: "A spelling
   fix in a locale key **is** a key change", so the key, every `L[...]` call site and every other
   `locales/*.lua` file move **in the same commit**. There is only one locale file here, which makes
   this cheap now and expensive the day a second one lands — an argument for doing it now.

**Risk.** Step 3 is where a rename can reach a stored path by accident. The defense is mechanical:
before step 3, list every settings path from the schema and every locale key, and treat that list as
a rename blacklist. `tests/test_schema_defaults.lua` and `tests/test_database.lua` fail loudly if a
stored path moves, which is the second net.

## MM-A-18a — the two stored British keys

**Files:** `defaults/Profile.lua`, `core/Database.lua`, `settings/Schema.lua`, `tests/test_database.lua`.

This is a **decision, not a task**. Two paths are British: `showMinimise` (`defaults/Profile.lua:130`)
and `window.frame.minimised` (schema, `hidden`). Two answers, both compliant, and the wrong one is
doing neither:

- **Correct them.** A new `migrations[13]` step that moves each old key to its US spelling and prunes
  the old one, `schemaVersion` 13 → 14, and a case in `tests/test_database.lua` that seeds the old
  shape and asserts the new. Never a rename: AceDB merges defaults by key, so a bare rename leaves
  the player's stored value orphaned under a key nothing reads and silently reverts their setting.
- **Keep them.** A `## Documented deviations` row citing `localization-§5`, with the reason (a
  stored key is a migration and the two words are invisible to a player) and a re-check trigger
  (the next migration that touches `window.frame.*` for another reason carries this one with it).

Either is a real answer. What the audit files against is the third state — a spelling sweep that
quietly skips them and leaves no record of why.

## MM-A-03 — the four Tier 2 docs

**Files:** `docs/slash-dispatch.md`, `docs/message-bus.md`, `docs/profiles.md`, `docs/debug.md` (new);
`docs/ARCHITECTURE.md`.

Each is a **spill, not new writing** — the material already exists in the hub, which is why this
deviation and MM-A-06 close each other's halves:

| New doc | Source | What stays in the hub |
|---|---|---|
| `slash-dispatch.md` | `## Slash commands` (`:159-198`) plus the sub-verb trees under `debug`, `perf`, `window` | The `NS.COMMANDS` table and one link |
| `message-bus.md` | `## Message bus` (`:118-158`) — the 14 messages with sender, payload, consumers | The catalog names and one link |
| `profiles.md` | `## Settings schema`'s reset-all veto plus the `PROFILE_CHANGED` fan-out, and what `settings/Profiles.lua` does and does not own | One paragraph and one link |
| `debug.md` | The four `/mm debug` sub-verbs and what each of `core/Diagnostics.lua`'s probes prints | One paragraph and one link |

Then the four `## Documentation map` rows change from an *evaluation record* to **Tier 2
registrations in `### Conditional`**, each carrying `Present` and the trigger that fired with its
measured number. The `compat-layer.md` and `midnight-quirks.md` rows are already in that shape and
are the template.

**A note on scope.** `documentation-§3` is explicit that a Tier 2 doc is not eight copies of the
library's documentation: `slash-dispatch.md` covers **this addon's** dispatch, not
`LibKa0s-Slash-1.0`'s, and `debug.md` covers `core/Diagnostics.lua`, not the console. Writing the
library's half is the way these four docs go stale.

**If a trigger is wrong**, the change is upstream in `documentation-§3` and this repo conforms after
it lands. What is not available is a *Not applicable* row over a number that refutes it.

## MM-A-13 — the four mandated tables

**File:** `docs/ARCHITECTURE.md:370-438`.

A pure restructure of one section. Target shape, from `documentation-§3`'s template:

```
## Documentation map                     ← ":372  … exactly one of the four tables below"
### Required (documentation-§3, Tier 1)          scope, module-map, schema, settings-panel,
                                                 data-flow, common-tasks  (+ the optional
                                                 ARCHITECTURE.md self-row, first, which is a MAY)
### Conditional (documentation-§3, Tier 2)       | Doc | Status | Trigger |
                                                 the 7 Tier 2 docs incl. perf-analysis/README.md
### Verification and record (documentation-§3)   | Doc | Covers |
                                                 exactly 6: testing, smoke-tests, test-cases,
                                                 performance, automated-tests/README,
                                                 automated-tests/RESULTS
### Addon-specific (documentation-§3, Tier 3)    superpowers/, revendor/, audits/, reviews/
```

Four moves and two deletions:

1. `testing.md` and `smoke-tests.md` — out of `### Canonical trio`, into `### Verification and
   record`, taking it from five rows to six.
2. `perf-analysis/README.md` — out of `### Verification and record`, into `### Conditional` with its
   trigger (`the performance harness is wired`, `performance-§12`) and status `Present`. The
   standard settles this explicitly: "the trigger decides the table".
3. `### Topic detail` splits: the six Tier 1 docs to `### Required`; the four stores to
   `### Addon-specific`; `compat-layer.md` and `midnight-quirks.md` to `### Conditional` beside the
   four MM-A-03 adds.
4. `### Tier 2 conditional docs — evaluated at v0.1.0` becomes `### Conditional
   (documentation-§3, Tier 2)` and moves to second position.
5. `:372` — "three tables" → "four tables".
6. `:427` — the "not a fourth register table" note is **deleted**, not reworded. The standard says
   so in as many words: the table is now the rule.

The `ARCHITECTURE.md` self-row at `:390` stays or goes as the maintainer prefers — a **MAY**, and an
audit files neither state. If it stays it is the first row of `### Required`.

**Test impact.** `tests/test_docmap.lua` and `tests/test_doc_structure.lua` read this section. Both
will need their table names updating in the same commit; that is the change telling you it is doing
real work, and a docmap gate that passes unchanged after this restructure would itself be a finding.

## MM-A-06 — get the hub back under ~400 lines

**Files:** `docs/ARCHITECTURE.md`; a new Tier 3 doc; `docs/automated-tests/RESULTS.md`.

The MUST is met — every mandated section with a topic doc to spill to is under 60 lines. What is
left is 372 lines of register in a 773-line file. Three candidates, in descending value:

1. **`### Files over the 1500-line cap` (`:510-558`, 49 lines) → delete, and point at
   `RESULTS.md`.** `docs/automated-tests/RESULTS.md:98-118` already carries the same fifteen files
   with the same dispositions, generated by the runner. Two hand-synced copies of one table is the
   drift `automated-tests-§4` was amended to stop. Keep the register **row** (which is the ratified
   decision) and replace the census with a link. **Constraint:** `tests/test_layout_cap.lua` asserts
   the census's membership — re-point it at `RESULTS.md` in the same commit, or the gate goes green
   against a deleted table.
2. **`### Hard-coded texture paths` (`:559-619`, 61 lines) → a Tier 3 doc**, registered in
   `### Addon-specific`. It is addon-specific subject matter with a test behind it
   (`tests/test_texture_paths.lua`), which is exactly what Tier 3 is for. Re-point the test's
   table reader at the new path.
3. **`## Complexity register` (`:620-741`, 122 lines) → the same Tier 3 doc, or its own.** Lowest
   priority: it duplicates `RESULTS.md`'s watch list, so the same argument as (1) applies, but the
   two are not row-for-row identical today and reconciling them is real work.

(1) and (2) alone take the hub to roughly **660**; all three take it to about **540**. Under 400
needs `## Documented deviations`' 71-line table to shrink, which happens by retiring rows and not by
moving them — the register is the hub's own content and has nowhere to spill to. Report the shape
and stop there.

## MM-A-08 — one case, pinning the strip's geometry against the selection

**File:** `tests/test_options_panel.lua`; `tests/wow_mock.lua`.

Two halves, and the second is the one that makes the first mean anything.

- **The harness must answer a different height for selected-state art.** `options-ui-§13`:
  "A harness that answers one height for every atlas cannot fail this — the harness **MUST** answer
  a different height for the selected-state art, or the case is green against nothing." So
  `tests/wow_mock.lua`'s texture model gains a per-atlas height, with the selected-state atlas taller
  than the unselected one. This is the change that would have caught the original defect.
- **The case.** Drive `O.__tabArtHeight`, `O.__tabPlacement` and `O.__tabBand` — published on the
  vendored payload at `libs/LibKa0s/OptionsWidgets.lua:994`, so no live client and no page render is
  needed — over a tab-width list wide enough to wrap, once per value of the selection. Assert the
  reserved band and **every** row's y offset are identical across all of them.
- **The mutation it must die under, stated in the case's own comment:** make `tabArtHeight()` read
  the **selected** button's art. If the case still passes under that mutation, the harness half was
  not done.

**What this is not.** It is not a re-audit of the library, whose own suite covers the arithmetic.
It is this repo's own coverage of a MUST that binds this repo's panel, and it is why the deviation
survived the library-side fix.

## MM-A-14 / MM-A-15 — the README's badge row and logo

**File:** `README.md:3-8`.

One edit each, and they belong in the same commit:

- Delete `:4`, the static `![Version]` badge. The compliant unpublished row is four badges. At first
  publish, the same commit that adds `X-Curse-Project-ID` to the TOC adds
  `![CurseForge Version](https://img.shields.io/curseforge/v/<id>)` in that slot.
- Add the logo image immediately after the badge row, before the description. Locally that is
  `media/logos/multimeters.logo.jpg`; the eight sibling addons point at the CurseForge CDN copy,
  which is what to switch to at publish.

`tests/test_doc_structure.lua` already asserts `README_ORDER`; extending it to assert **four or five
badges matching the canonical templates** and **one non-badge image between the badge row and the
first `##`** is two more assertions in a file that already walks the README, and is what stops this
recurring.

## MM-A-16 — four mislabeled closed issues

**No files.** Four `gh issue edit` calls, **spaced** — the collection's rule is that bulk issue
writes are throttled:

```
gh issue edit 21 --remove-label state:triaged --add-label state:done
gh issue edit 4  --remove-label state:triaged --add-label <state:done|state:will-not-do>
gh issue edit 6  --remove-label state:triaged --add-label <state:done|state:will-not-do>
gh issue edit 7  --remove-label state:triaged --add-label <state:done|state:will-not-do>
```

#21 is unambiguous — the widget shipped as `LibKa0s-Widgets-1.0`'s `ReorderList` and the register
records the row's retirement on that trigger, so it is `state:done`. The other three are read
against what shipped before the label is chosen; guessing a terminal label from a title is exactly
what `audit-review-history` forbids the read-only commands from doing.

## MM-A-17 — nothing to build

Info. The next release run reconciles the bundle with the tree, and `automated-tests-§6` forbids
gating commits on a bundle in the meantime. Worth knowing when the tag is finally cut: the release
gate is all four suites `pass` **plus zero functions above CCN 15**, and this addon stands at 23 —
`## Complexity register` and `RESULTS.md`'s watch list both say so, with an issue per Peel row.
