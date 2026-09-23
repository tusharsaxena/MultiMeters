# 05 — Execution plan (Ka0s Multi Meters, 2026-09-23)

The ordered hand-off to the remediation engagement. Every step names its deviation ID(s). The plan
covers **all 14 entries** (13 roots and 1 dependent), including the Low, the SHOULD and the Info.

**Resumability.** Each step is one commit on a green gate: `lua tests/run.lua` and `luacheck .`
through `ka0s-bounded`. A step's checkbox is its checkpoint, and a resumed session starts at the
first unchecked box. Figures to re-verify at the start of any resumed session:

- 1948 cases;
- `lizard` 0 warnings;
- `diff -r` against `v1.55.0` empty.

## Sprint 0 — upstream (LibKa0s), before anything here

- [ ] **S0-1 (MM-A-25, only if option (a) is chosen and a hover state is wanted).**
  - Add the `resize` hover variant, or a tinted-state contract, to `LibKa0s-Media-1.0` in the
    **LibKa0s repo**, through its generator.
  - Bump the minor and tag it.
  - Otherwise nothing upstream is needed, because the payload is already `v1.55.0` and diff-clean.
- [ ] **S0-2 (collection re-vendor, if the cross-repo plan re-vendors a newer LibKa0s tag).**
  - Re-vendor the **whole** payload (`libs/LibKa0s/` and `tests/_kit/`) and roll `CLAUDE.md:53` in
    the same commit.
  - Re-run both `diff -r` checks against the new tag.
  - Write its own `docs/revendor/<date>-v<tag>/` bundle, so that MM-A-19 does not recur.

## Sprint 1 — records and docs (no runtime change)

- [ ] **S1-1 (MM-A-16).** Three spaced `gh issue edit` calls:
  - `#21` → `state:done`;
  - `#4` → terminal, after reading it;
  - `#24` → terminal, after reading it.

  Verify that `gh issue list --state closed --label state:triaged` and `--label state:untriaged`
  both return nothing.
- [ ] **S1-2 (MM-A-19).** Write the consolidated re-vendor bundle, spanning `v1.15.0`/`v1.34.0` →
  `v1.54.2`, with `01_DELTA.md` and `05_SUMMARY.md`. Re-run the `AUDIT.md` step-4 comparison, and
  expect `grep -vxF -f recorded vendored` to print nothing.
- [ ] **S1-3 (MM-A-23).** Run the citation sweep:
  - 4 `library-stack §8` → `library-stack-§8`, with `tests/test_texture_paths.lua:48` in the same
    commit;
  - 18 §-less citations;
  - 35 `\194\167` comment citations.

  Re-run §23's three greps, and expect 0, 0 and 0 in authored scope.
- [ ] **S1-4 (MM-A-24).** Fix `docs/ARCHITECTURE.md:14` (58 / 19 `core/`). Optionally add the
  derived-count assertion.
- [ ] **S1-5 (MM-A-22).** Add three at-line TOC comments (`core\CoreSetup.lua`, `core\PerfSetup.lua`,
  `settings\OptionsSetup.lua`) and the per-group "conventional" notes. Optionally add the pair
  assertions to `tests/test_loadorder.lua`.
- [ ] **S1-6 (MM-A-25).** The owner picks (a) adopt or (b) ratify. For (b), add two
  `library-stack-§8` register rows and extend `tests/test_texture_paths.lua`'s register assertion.
  For (a), go to S2-3.

## Sprint 2 — code with player reach

- [ ] **S2-1 (MM-A-20).**
  - Add a single `pcall`ed `registerEvent` helper, a module-level `EVENTS` list, and
    `NS.State.rejectedEvents`, reset on each `OnEnable`.
  - Add the `/mm debug diag` line.
  - Add a `tests/test_lifecycle.lua` case driven by `M.__badEvents`.
  - Correct the `core/MultiMeters.lua:153-156` comment and add a note in `docs/midnight-quirks.md`.
  - Confirm `Disabled 3` and `Disabled 9` stay green.
- [ ] **S2-2 (MM-A-18, MM-A-18a).**
  - (a) Prose, comments, README (with the de-AI pass), the header control key and art name, and the
    locale keys and values, with every call site.
  - (b) The `v15 → v16` migration for `frame.minimised` → `frame.minimized` and `showMinimise` →
    `showMinimize` across every profile, plus defaults, schema rows and a migration case.
  - (c) Delete every `minimis` waiver.

  Afterwards, `grep -rniE minimis` over the authored scope returns 0, and `test_prose` stays green
  with no waiver file.
- [ ] **S2-3 (MM-A-25, option (a) only).** `TARGET_ICON` becomes `NS.Icon("target")` with the Blizzard
  path as the nil fallback. The grip moves to `NS.Icon("resize")`, using the S0-1 variant if one was
  shipped. Update the texture census table and `tests/test_texture_paths.lua`.
- [ ] **S2-4 (MM-A-08).** Add the wrapped-strip geometry case in `tests/test_options_panel.lua`. The
  mock answers a distinct selected-art height. Confirm the case goes red under the documented
  mutation, then restore.

## Sprint 3 — docs shape (after Sprint 2, so the docs describe the final code)

- [ ] **S3-1 (MM-A-03).** Spill `docs/slash-dispatch.md`, `docs/message-bus.md` and
  `docs/profiles.md`. Flip the three `### Conditional` rows to *Present*. `tests/test_docmap.lua` and
  `tests/test_doc_structure.lua` must be green.
- [ ] **S3-2 (MM-A-06).** Move `### Hard-coded texture paths` to a Tier 3 doc and register it.
  Repoint `tests/test_texture_paths.lua`. Report `wc -l docs/ARCHITECTURE.md`, with a target of 560
  or less.
- [ ] **S3-3.** Regenerate `docs/test-cases.md` and update the README `[tests]` badge in the same
  change (`documentation-§1`). Run `/wow-addon:sync-docs`.

## Sprint 4 — release (closes MM-A-21 and MM-A-26)

- [ ] **S4-1 (MM-A-21, MM-A-26).** `/wow-addon:bump-version` to `1.1.0`, since S2-2 bumps
  `schemaVersion`, or `1.0.2` if S2-2 is deferred.
  - Roll `## Version History`, optionally with a `1.0.1` "re-published 1.0.0 unchanged" row.
  - Run the release battery (`run-automated-tests.sh`, `"release": "<version>"`), with all four
    suites at pass and `complexity.warnings == 0`.
  - `RESULTS.md` regenerates with commit cells, which drops the stale `NS.ValidateSchema` row.
  - Tag only after the manifest is green. The owner pushes and merges on their own go-ahead.

## Ordering constraints

| Constraint | Why |
|---|---|
| S0 before anything that re-vendors | Upstream first. The re-vendor bundle (S0-2) must exist before S1-2 closes the backlog span. |
| S1-3 before S3-2 | Both edit `docs/ARCHITECTURE.md:671-679` and `tests/test_texture_paths.lua`. |
| S2-2 before S3-1/S3-3 | Case names containing `minimise` change, and the inventory regenerates once. |
| S2-1 before S4-1 | The release carries the registration fix. |
| S3-* before S4-1 | `documentation-§5`: the docs are checked at release. |

## Done means

Re-running this audit's commands gives:

- 0 unrecorded re-vendor tags;
- 0 malformed citations in authored scope;
- 0 `minimis` in authored scope;
- three Tier 2 docs *Present*;
- a hub of 560 lines or less;
- every closed issue terminally labeled;
- 22 registrations behind one `pcall`ed helper with a player-reachable rejected list;
- a released version at or above 1.0.2 with its history row and release bundle.
