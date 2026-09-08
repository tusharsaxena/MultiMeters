# 05 — Execution plan (Ka0s Multi Meters, 2026-09-08)

Ordered, checkable remediation for the nine roots and one dependent in `02_DEVIATIONS.md`, designed
in `04_TECHNICAL_DESIGN.md`. Read the two as one document: every number quoted here is the number
quoted there, and both come from `03_EVIDENCE.md`'s recorded commands.

**Green gate between every step:** `lua tests/run.lua` and `luacheck .` (0/0). Commit only on green
(`versioning-git`). No step below changes what the addon does in the game; the only step that can is
Sprint 4, and it is a decision before it is a change.

**Nothing here is urgent.** Zero High, zero Medium. The sequence is chosen so the cheap
irreversible-by-nobody edits land first and the one step with a stored-data edge lands last, behind
an explicit decision.

---

## Sprint 1 — the two-line README, and four labels (half an hour)

| # | Step | Closes | Done when |
|---|---|---|---|
| 1.1 | Delete `README.md:4`, the static `![Version]` badge. Leave four badges: WoW, License, Standard, Tests. | MM-A-14 | `grep -c 'img.shields.io' README.md` → 4 |
| 1.2 | Add the logo image after the badge row, before the description prose — `media/logos/multimeters.logo.jpg`. | MM-A-15 | `grep -n '!\[' README.md` shows one non-badge image between the badge row and `## What's new` |
| 1.3 | Extend `tests/test_doc_structure.lua`'s README walk with two assertions: the badge row is four or five badges each matching a canonical `documentation-§1` template, and exactly one non-badge image sits between the badge row and the first `##`. | MM-A-14, MM-A-15 | Both assertions red before 1.1/1.2 and green after |
| 1.4 | Re-label the four closed issues, **spaced** — `gh issue edit 21 --remove-label state:triaged --add-label state:done`, then #4, #6, #7 after reading what shipped for each. | MM-A-16 | `gh issue list --state closed --label "state:triaged" --json number` returns `[]` |

Land 1.3 **before** 1.1 and 1.2 so the gate is seen to fail. One commit for 1.1–1.3; #1.4 touches no
file and is not a commit.

## Sprint 2 — `## Documentation map`, then the four Tier 2 docs

Ordering is a hard constraint: **2.1 before 2.2**, because 2.2 writes rows into tables 2.1 renames.

| # | Step | Closes | Done when |
|---|---|---|---|
| 2.1 | Restructure `docs/ARCHITECTURE.md:370-438` into the four mandated tables — `### Required`, `### Conditional`, `### Verification and record`, `### Addon-specific`, in that order. Move `testing.md` + `smoke-tests.md` **into** the verification table (six rows), `perf-analysis/README.md` **out** of it into `### Conditional`, split `### Topic detail`. Correct `:372` "three" → "four". **Delete** `:427`'s "not a fourth register table" note. | MM-A-13 | The four headings read exactly as `documentation-§3` names them, in its order; the verification table has exactly the six named rows |
| 2.2 | Update `tests/test_docmap.lua` and `tests/test_doc_structure.lua` for the new table names, and assert the verification table's six-row membership by name. | MM-A-13 | Suite green; the docmap gate would go red if a row moved back |
| 2.3 | Write `docs/slash-dispatch.md` — spilled from `## Slash commands`, covering **this addon's** 6 own verbs and the `window`/`debug` sub-verb trees, not `LibKa0s-Slash-1.0`'s reserved set. | MM-A-03 | File exists; the hub section keeps the `NS.COMMANDS` table plus one link |
| 2.4 | Write `docs/message-bus.md` — the 14 messages with sender, payload and consumers, spilled from `## Message bus`. | MM-A-03 | File exists; hub keeps a summary and one link |
| 2.5 | Write `docs/profiles.md` — what `settings/Profiles.lua` hosts, the `PROFILE_CHANGED` fan-out, the reset-all veto, and a link to `schema.md` for the persisted shape. | MM-A-03 | File exists |
| 2.6 | Write `docs/debug.md` — the four `/mm debug` sub-verbs and what each `core/Diagnostics.lua` probe prints. Not the console, which is the library's. | MM-A-03 | File exists |
| 2.7 | Convert the four `## Documentation map` rows from *Not applicable* to Tier 2 registrations in `### Conditional`, each `Present` with the trigger and its measured number (16 commands + a sub-tree; 14 messages; a profile control ships; four `/mm debug` surfaces over an 1824-line `Diagnostics`). | MM-A-03 | No `Not applicable` row survives whose trigger fires |

One commit per doc (2.3–2.6), then one for 2.7. Five commits keeps five bisect points if the docmap
gate disagrees with a row.

## Sprint 3 — the hub's shape, and the strip's geometry case

| # | Step | Closes | Done when |
|---|---|---|---|
| 3.1 | Delete `### Files over the 1500-line cap` (`docs/ARCHITECTURE.md:510-558`) and link to `docs/automated-tests/RESULTS.md:98-118`, which the runner regenerates with the same fifteen files and the same dispositions. **Keep** the ratified register row itself. Re-point `tests/test_layout_cap.lua` at `RESULTS.md` in the same commit. | MM-A-06 | Hub ≈ 724 lines; `test_layout_cap` still red if a file crosses 1500 unlisted |
| 3.2 | Move `### Hard-coded texture paths` (`:559-619`) to a Tier 3 doc, registered in `### Addon-specific`. Re-point `tests/test_texture_paths.lua` at the new file. | MM-A-06 | Hub ≈ 663; the texture gate still red both ways |
| 3.3 | *(Optional, judgment call)* Move `## Complexity register` (`:620-741`) beside it, reconciling it with `RESULTS.md`'s watch list rather than keeping two copies. | MM-A-06 | Hub ≈ 540 |
| 3.4 | Give `tests/wow_mock.lua`'s texture model a **per-atlas height**, with the selected-state tab atlas taller than the unselected one. | MM-A-08 | A case that reads a selected atlas gets a different number than one that reads the unselected one |
| 3.5 | Add the case: drive `O.__tabArtHeight` / `O.__tabPlacement` / `O.__tabBand` over a wrapping tab-width list, once per value of the selection, asserting the reserved band and **every** row's y offset are identical across all of them. Comment names the mutation it dies under — `tabArtHeight()` reading the selected button's art. | MM-A-08 | The case is red under that mutation and green otherwise |

3.4 **before** 3.5, and verify by mutation, not by the case passing. A green case over a harness that
answers one height for every atlas is `testing-§12`'s exact failure and would close nothing.

The hub does not reach ~400 even after 3.3; `02_DEVIATIONS.md` says why (the registers are the hub's
own content and have nowhere to spill). Report the shape and stop — the standard's own instruction
is not to argue the arithmetic.

## Sprint 4 — the US-English sweep

The largest step and the last, because it touches 65 files and because its final commit is the only
one in this plan that can reach a player's stored data.

| # | Step | Closes | Done when |
|---|---|---|---|
| 4.1 | Add the gate to `tests/test_locale.lua`: the 91 `BRITISH` substrings and 30 `ALLOWED` whole words copied **whole** from `localization-§5`, `ALLOWED` removed as whole words first, the four exclusions named path by path. **Land it red.** | MM-A-18 | The case fails and prints the 830 lines across 65 files `03_EVIDENCE.md` §12 records |
| 4.2 | Fix `docs/` and `README.md` prose. | MM-A-18 | Gate's doc half green |
| 4.3 | Fix comments under `core/`, `modules/`, `settings/`, `defaults/`. | MM-A-18 | Gate's comment half green; no identifier moved |
| 4.4 | Fix non-stored identifiers, working from a rename blacklist built from the schema's stored paths and the locale keys. | MM-A-18 | `luacheck .` still 0/0; `tests/test_schema_defaults.lua` and `tests/test_database.lua` green |
| 4.5 | Fix `locales/enUS.lua:213` and `:230` — key **and** value, with every `L[...]` call site, in **one** commit (`localization-§5`: a spelling fix in a key is a key change). | MM-A-18 | Gate green except the two stored paths |
| 4.6 | **Decide** MM-A-18a: either `migrations[13]` moving `showMinimise` / `window.frame.minimised` to their US spellings with `schemaVersion` 13 → 14 and a seeded case, **or** a `## Documented deviations` row citing `localization-§5` with a re-check trigger. | MM-A-18a | Whichever is chosen is written down; the gate either goes fully green or names the two exceptions against that register row |

4.6 is a decision for the maintainer, not for the remediation session. Both answers are compliant.
Silently skipping the two paths is the only outcome that is not.

---

## Order, and why

1. **Sprint 1** — smallest edits, no dependency, and 1.3 buys a gate against recurrence for two
   README rules nothing has ever checked.
2. **Sprint 2** — the register's shape before its contents; the four docs are moves out of the hub,
   so they also do half of Sprint 3's work.
3. **Sprint 3** — the rest of the hub, plus the one test-coverage gap. Independent of Sprint 4.
4. **Sprint 4** — last: the biggest diff, and the only stored-data edge, behind an explicit decision.

## What this plan deliberately does not do

- **It does not peel a file for `layout-§1`.** All fifteen over-cap files sit in a terminal state the
  rule accepts (eight open issues, seven under a ratified register row), and `layout-§1` says an
  audit **MUST NOT** re-file against them. Issue **#46** records that decline with its reasoning.
- **It does not move `settings/ColumnBlocks.lua:72-73` to the catalog.** That is register row 5,
  ratified 2026-09-08, and its re-check trigger — ConsumableMaster's three sites adopting the
  catalog — has not fired; all three still carry the `ReadyCheck` pair. Moving one side alone
  converts a shared glyph vocabulary into a split one, which is worse than the ratified state.
- **It does not reduce the 23 complexity warnings.** Each has a disposition: twelve read *Accepted*, and each
  of the eleven *Peel* rows carries an issue (`#35`–`#45`). That is `automated-tests-§4` satisfied; the peels are
  ordinary scheduled work, not audit remediation, and the release gate they block is not near.
- **It does not re-run the automated-test bundle to close MM-A-17.** `automated-tests-§6` forbids
  gating commits on a bundle; the next **release** run reconciles it, and the drift measured today
  is 178 nloc and four test cases with no threshold crossed.
- **It does not touch the library.** `diff -r` against `LibKa0s@v1.27.0` is empty for both the ship
  folder and the test kit. Any change wanted in `libs/LibKa0s/` or `tests/_kit/` is made in the
  library repo and arrives here as a re-vendor commit.
