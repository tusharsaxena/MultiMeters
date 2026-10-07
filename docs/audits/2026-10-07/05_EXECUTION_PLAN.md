# 05 — Execution plan (Ka0s Multi Meters, 2026-10-07)

This is the hand-off to the remediation engagement. It is keyed to the IDs in `02_DEVIATIONS.md`, and
the design is in `04_TECHNICAL_DESIGN.md`. **Green gate after every step:**
`~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` (0 failed) and
`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0). Commit subjects start with the ID
(`MM-A-27: …`).

**Scope at a glance:** 9 roots plus 1 dependent, all Low or Info, and no player-facing behavior
change. Effort is about half a day. Nothing is blocked upstream. The one owner decision is MM-A-29's
`lizard` pin, step B4.

## Sprint A — record the re-vendors (MM-A-19, MM-A-19a)

- [ ] **A1 (MM-A-19).** Write `docs/revendor/2026-10-07-v1.69.0-v1.70.0/01_DELTA.md`. Line 1 is
      exactly `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.69.0 v1.70.0)`. The body is the payload
      delta from `git -C ../LibKa0s diff --stat v1.68.1 v1.70.0 -- LibKa0s testkit`.
- [ ] **A2 (MM-A-19).** Write `05_SUMMARY.md` in the same folder, one line per tag:
      `v1.69.0 — carried by sweep, nothing adopted (LineChart: no consumer here)` and
      `v1.70.0 — carried by sweep, nothing adopted (Autocomplete: no consumer here)`.
- [ ] **A3 (MM-A-19a).** De-tag or correct the stamps at `docs/settings-panel.md:29` (`v1.68.1`),
      `docs/testing.md:597` (`kit 36`) and `DEPENDENCIES.md:35` (`kit 36`).
- [ ] **Check A.** Re-run the `AUDIT.md` re-vendor script. `UNRECORDED:` must print nothing.
      Run the sweep `git ls-files '*.md' … | xargs grep -nE 'v1\.6[0-9]\.[0-9]+ bundled|kit 3[0-6]\b'`.
      It must print nothing outside frozen bundles.

## Sprint B — docs and comments (MM-A-23, MM-A-24, MM-A-29, MM-A-06)

- [ ] **B1 (MM-A-23).** `core/LifecycleSetup.lua:117`: `architecture-4` → `architecture-§4`.
- [ ] **B2 (MM-A-24).** In `docs/ARCHITECTURE.md`:
  - `:45`: drop "all fifty-eight of them", or make it sixty-three.
  - `:511-512`: "three" → "two".
  - `:444` and `:454`: retitle as `**Retired on <date>: …**`.
- [ ] **B3 (MM-A-24).** Correct the comments at `settings/Slash.lua:82-83` (no README command table)
      and `:857` (the run turns logging on).
- [ ] **B4 (MM-A-29), owner decision first.** Replace the raw `lizard` command at
      `DEPENDENCIES.md:98` and `docs/automated-tests/README.md:38` with
      `bash tests/_kit/run-automated-tests.sh --suite complexity`. Then, on the owner's choice:
  - **(a)** Un-pin `lizard` (`DEPENDENCIES.md:35`, `:58`, `:68-70`) and write the parity sentence.
  - **(b)** File a `documentation-§7` register row for the pin.
- [ ] **B5 (MM-A-06, optional).** Shrink the hub. Fold the five retired-row paragraphs
      (`:413-458`) to one line each with a bundle pointer, and trim the Conditional rows to their
      counts. Target: about 400 lines.
- [ ] **B6 (MM-A-24, optional gate).** If `:45` keeps a count, extend
      `tests/test_doc_structure.lua`'s file-count case to read it. The case must fail red-first
      against "fifty-eight".
- [ ] **Check B.** Re-run the citation sweep (`03_EVIDENCE.md` §23). Malformed and out-of-range
      must both be 0. `grep -n 'lizard -l lua' DEPENDENCIES.md docs/automated-tests/README.md` must
      return nothing. `wc -l docs/ARCHITECTURE.md` should be under 578, and about 400 if B5 was
      done.

## Sprint C — the dead rung and the conformance step (MM-A-27, MM-A-30)

- [ ] **C1 (MM-A-27, red first).** In `tests/test_envsetup.lua`, replace the case at `:146` with
      one that spies a bare `GetAddOnMetadata` mock with `C_AddOns` absent and asserts zero calls.
      Run it: it must fail.
- [ ] **C2 (MM-A-27).** Delete `core/EnvSetup.lua:93-95`. C1 goes green. Reword
      `settings/Slash.lua:64` and `core/PerfSetup.lua:94`.
- [ ] **C3 (MM-A-30).** Extend "Disabled 8" (`tests/test_disabled.lua:479`) with the right-click
      menu half: entry states, zero SV writes, zero frame shows, and a falsification comment. Check
      it falsifies by temporarily breaking the assertion target, without committing that.
- [ ] **C4.** If the case count moved, regenerate `docs/test-cases.md`
      (`lua tests/run.lua --list > docs/test-cases.md`, bounded) and update the README `[tests]`
      badge in the same commit.
- [ ] **Check C.** Green gate. `grep -n '_G.GetAddOnMetadata' core/*.lua` must return nothing.

## At the next release (MM-A-28, MM-A-26)

- [ ] **R1 (MM-A-28).** The next `## Version History` row says, in player words, that
      `/mm set global.minimap.hide <v>` became `/mm set global.minimap.shown <not v>` in 1.1.0.
      Alternatively, append that highlight to the 1.1.0 row now. Run the de-AI pass on the README
      edit.
- [ ] **R2 (MM-A-26).** The release run is the first sighted bundle. Confirm
      `suites.complexity.blindFiles == 0` and that the watch list's dispositions carried over.

## Exit criteria

- [ ] `AUDIT.md`'s re-vendor script reports no unrecorded tag.
- [ ] The citation sweep finds no malformed or out-of-range reference.
- [ ] No live doc names a stale LibKa0s tag or kit revision, or quotes raw `lizard` as a gate.
- [ ] `core/EnvSetup.lua` has no bare-global rung, and a case pins its absence.
- [ ] `tests/test_disabled.lua` step 8 drives both clicks.
- [ ] The re-audit headline drops to MM-A-06 (if B5 is skipped) plus MM-A-26 (Info) until the next
      release.
