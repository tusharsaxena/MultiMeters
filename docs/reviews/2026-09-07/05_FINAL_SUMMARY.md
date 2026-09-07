# Final summary — Ka0s Multi Meters, review cycle of 2026-09-07

> **Written ahead of implementation.** This artifact assumes every change in
> `02_PROPOSED_CHANGES.md` was applied and every check in `03_SMOKE_TESTS.md` passed. Where it
> states a post-change number, that number is an **expectation to be confirmed**, not a
> measurement — each such figure is marked. Fill in the sign-off table in `03_SMOKE_TESTS.md`
> and replace the marked figures with the observed ones before this text is used as a PR body.

---

## Headline

The issue-#25 feign-death instrumentation shipped working in the small and not working in the
large: it recorded the right three boundaries, but it built its records on the addon's hot path
whether or not anybody was recording, and it kept them in a single 120-entry buffer that the
busiest of the three boundaries overwrites within seconds. A player who armed the trace, ran a
dungeon and typed `/mm debug feign` would have got a few seconds of the least interesting
boundary and none of the two that answer the question. This cycle makes the instrumentation free
when disarmed, makes it keep the lines it exists to keep, traces the one eviction path that was
silent — the path most likely to explain why the filter works for the local player and not for a
party member — and brings four pieces of committed evidence back into agreement with the code
they describe.

---

## Counts

**Critical fixed: 0 · High fixed: 3 · Medium fixed: 4 · Low fixed: 5**

- High: MULTIMETERS-R-01, R-02, R-03
- Medium: R-04, R-06, R-07, R-08 *(partial — see deferrals)*
- Low: R-09, R-10, R-11, R-12, R-13, R-14 *(R-14 folded into M3's rewrite of the degraded case)*

**Deferred, with reasons:**

| ID | Why deferred |
|---|---|
| R-05 | `docs/automated-tests/RESULTS.md` regenerates at **release** under `/wow-addon:bump-version` (`automated-tests-§3`). Hand-editing it would make a stale report read as measured, which is worse than leaving it stale. |
| R-08 (part) | Only `core/Diagnostics.lua` — the file *this* changeset pushed over `layout-§1`'s cap — is peeled. `settings/Schema.lua` (3069), `modules/Tooltip.lua` (2652), `modules/Window.lua` (2644), `modules/Aggregator.lua` (2058), `modules/Export.lua` (1743) and `modules/Row.lua` (1702) are pre-existing and are not opened during a diagnostic investigation. |

---

## Changes by theme

### Theme A — Make the feign trace free when nobody is recording

**What changed.** The three trace call sites now read a plain boolean before they build
anything. `Diagnostics.feignArmed` is published alongside the existing
`IsFeignTraceArmed()` accessor, and `modules/Aggregator.lua` hoists both the module lookup and
the flag above its per-source loop so the check costs one boolean per column rather than one
table pair per death row.

**Why it mattered.** Every coalesced refresh — four a second at the shipped throttle, for the
whole of every pull, on a default profile — allocated two tables per Deaths source for a
function that discards them. Measured at **+6,720 bytes per refresh** on the 20×7 raid fixture.
Two code comments asserted the opposite in as many words; both are corrected.

**Findings covered:** R-01, R-10. **Changes implemented:** C-01.

**Files touched:** `core/Diagnostics.lua`, `modules/Feign.lua`, `modules/Aggregator.lua`.

### Theme B — Make the recording able to answer its question

**What changed.** The `judge` boundary is now admitted into the ring only for GUIDs a `cast`
line already named, with a suppressed-row counter printed so a `judge` row for an unseen GUID
is still surfaced as the finding it is. The ring itself became a write index instead of an O(n)
`table.remove(log, 1)`. `Feign.Prune`'s not-in-group eviction — previously silent — now emits a
`prune` line, and every evicted entry reports the state it held **when the decision was made**
(`noted` / `down`) rather than the post-eviction `<evicted>`.

**Why it mattered.** The three defects had one root: a recording designed around two rare
boundaries with a third, hot one dropped into the same buffer. The result was a diagnostic that
could not deliver in the only scenario it was built for. The eviction fix is the sharpest of the
three — `present` admits a roster entry only when its GUID is a safe key and it has a unit token,
which is always true for the local player and not always true for a party member, so the branch
that best explains the reported asymmetry was the one branch producing no evidence at all.

**Findings covered:** R-02, R-03, R-09, R-13. **Changes implemented:** C-02, C-03.

**Files touched:** `core/Diagnostics.lua`, `modules/Feign.lua`.

### Theme C — Re-align the committed evidence with the code

**What changed.** `docs/test-cases.md` regenerated from `lua tests/run.lua --list`; the README
`[tests]` badge moved with it; `tests/perf.lua`'s recorded baseline and derived ceiling
re-recorded from a post-fix run with the reason written down; `docs/performance.md`'s two quoted
figures refreshed from the same run; `tests/test_vendor_sync.lua`'s header corrected from
`v1.8.3` to the `v1.25.0` this addon actually bundles.

**Why it mattered.** Four artifacts were asserting things about this code that had stopped being
true, and one of them was actively harmful: `tests/perf.lua`'s ceiling carried 25.9 KB of slack
against a comment claiming 3.5%, and that slack is what let Theme A's regression through the
addon's only automated allocation guard without a red run.

**Findings covered:** R-06, R-07, R-11. **Changes implemented:** C-04, C-06, C-08 (part).

**Files touched:** `docs/test-cases.md`, `README.md`, `tests/perf.lua`, `docs/performance.md`,
`tests/test_vendor_sync.lua`.

### Theme D — Coverage and structure

**What changed.** Six new cases pin the `judge` boundary, the ring's survival under overflow,
the disarmed cost, the traced eviction, the pre-decision state, and the agreement between the
published flag and its accessor. Each carries a `-- red under:` naming a mutation that was
applied and confirmed to redden it. `core/Diagnostics.lua`'s feign section peeled into
`core/DiagnosticsFeign.lua`. `/mm debug feign <garbage>` now names the rejected argument instead
of silently printing a report.

**Why it mattered.** Three of this review's findings sat on paths the suite ran through and
asserted nothing about, which is why they shipped green. The peel is not cosmetic: this
changeset is what carried `core/Diagnostics.lua` from 1566 to 1726 LOC, past `layout-§1`'s hard
1500 cap.

**Findings covered:** R-04, R-08 (this changeset's share), R-12, R-14.
**Changes implemented:** C-05, C-07, C-08 (part).

**Files touched:** `tests/test_diagnostics.lua`, `tests/test_feign.lua`, `core/Diagnostics.lua`,
`core/DiagnosticsFeign.lua` (new), `MultiMeters.toc`, `settings/Slash.lua`.

---

## API / behaviour changes

- **`/mm debug feign <unrecognised>`** now prints `unknown: /mm debug feign <arg> — try on, off,
  or nothing.` and returns. Previously it fell through and printed the report.
- **`/mm debug feign`'s report** gains a suppressed-`judge` counter line when rows were filtered
  out, and gains `prune` lines for members evicted as not-in-group.
- **`Diagnostics.feignArmed`** — new plain boolean on the namespace's diagnostics table.
  Internal; not part of any public surface.
- **No slash verb added, renamed or removed.** `NS.COMMANDS` (`settings/Slash.lua:72`) is
  unchanged and still matches `README.md:85` in both directions.
- **No locale key added, renamed or removed.**

---

## Saved-variable / migration notes

**None.** No change in this cycle touches `defaults/Profile.lua`, `settings/Schema.lua`,
`schemaVersion` or any migration. `MultiMetersDB` and `MultiMetersPerfDB` keep their existing
shapes. Existing profiles carry forward with no action; no `/mm reset` is required.

The feign trace is **session state** — a file local with no SavedVariables backing — and is
deliberately not persisted. `/reload` empties it, which `03_SMOKE_TESTS.md` R-3 confirms.

---

## Deprecated-API migrations

**None.** No deprecated or removed API was found in this addon's own code. Every ageing call is
already behind `core/Compat.lua`'s shims — `Compat.GetSpellInfo` prefers `C_Spell.GetSpellInfo`
and falls back (`core/Compat.lua:44-55`), and `core/EnvSetup.lua:88-95` prefers
`C_AddOns.GetAddOnMetadata`. `modules/DrillDown.lua:518` and `modules/Tooltip.lua:1650` are the
only consumers and both go through the shim.

---

## Performance impact

Offline scenarios, `lua tests/perf.lua`, same machine, same day.

| Scenario | Before (`81642e6`) | After C-01 | Record |
|---|---|---|---|
| `refresh20x7` bytes/iter | 310158.1 | *expected ≈303438* — **confirm** | today's run, this review |
| `probeOverheadOff` bytes/iter | 310135.8 | *expected ≈303416* — **confirm** | today's run, this review |
| `PROBE_OFF_BYTES_CEILING` | 336000 (recorded baseline 325955, 15.8 KB stale) | *re-derived from the post-fix figure* — **confirm** | `tests/perf.lua:564` |

The 310158.1 / 303438.1 pair is the measurement this whole theme rests on: two runs of the same
runner, on `81642e6` and on its parent `0e74319`, differing only by the trace. Read the
per-scenario deltas within each run; do not compare either column against another machine.

No in-client capture is available as a record — `docs/perf-analysis/` currently holds only its
standing `README.md`. `03_SMOKE_TESTS.md` T-06 is where the first one gets made, and its
**`aggregate` bucket** is the figure to read, not the frame-time delta between arms.

---

## Test and complexity movement

- **Pass count: 1496 → 1502** (or 1501 if M3-T3's allocation check went to `tests/perf.lua` as a
  scenario rather than a case — `testing-§7` forbids counting a scenario, so it must not appear
  in the inventory or the badge either way). **Confirm against the run.**
- `docs/test-cases.md` and `README.md:7`'s badge moved in the **same change** (M4), as
  `testing` requires. Both were already 9 cases behind when this review started — `81642e6`
  added nine cases and regenerated neither — so this closes that drift too.
- **Watch-list entries these changes are expected to move**, to be confirmed by the next
  release's regeneration and **not** regenerated here:
  - `core/Diagnostics.lua` off the over-1500-LOC list (1726 → ≈1570 plus a new ≈180-line file).
  - `scanColumn@modules/Aggregator.lua` — today the repo's worst function at **CCN 36**. C-01
    hoists two reads and one branch out of its inner loop, so expect a small improvement, not a
    fix. It stays the entry to look at first.
  - The watch list itself is **two recorded runs stale** (headed `20260809-195454` while
    `20260825-103437` exists and reports 19 warnings / max CCN 31 / 8 over-cap files). Today's
    fresh run reports **23 warnings, max CCN 36**. The next release run corrects all of it.

---

## Known follow-ups

| Item | Rationale for deferring |
|---|---|
| R-05 — refresh the complexity watch list | Owned by release (`/wow-addon:bump-version`). A hand-edited report reads as measured and is worse than a stale one. |
| R-08 — the six other over-cap files | Pre-existing and unrelated to this changeset. `settings/Schema.lua` in particular has a recorded argument for staying whole (a per-page split risks the "one table, one source" property `architecture` depends on) — it wants a documented exception in the next record, not a peel. |
| No committed in-client perf capture | `docs/perf-analysis/` holds only its README. T-06 makes the first; a compliance matter beyond that. |
| `modules/Window.lua`'s header glyphs | Unverified from source whether the lock/gear controls draw Unicode glyphs or the vendored icon catalog (`libs/LibKa0s/media/icons/` ships `lock.tga` and `unlock.tga`). One in-client look settles it; `library-stack` prefers the catalog. |
| The underlying issue #25 | **Not fixed by this cycle, deliberately.** This work makes the diagnostic capable of answering the question. The answer, and the filter change it implies, is the next piece of work — and R-03 is the hypothesis it should test first. |

---

## Verification evidence

- Completed sign-off table: `docs/reviews/2026-09-07/03_SMOKE_TESTS.md`.
- Review bundle: `docs/reviews/2026-09-07/` (`01_FINDINGS.md` … `05_FINAL_SUMMARY.md`).
- Baseline commits for the perf comparison: `0e74319` (before) and `81642e6` (after the
  instrumentation, before this cycle's fixes).
- Commit range: `81642e6..HEAD`.

---

## Suggested commit message / PR description

```
fix(feign): make the issue #25 recording usable, and free when it is off

The feign trace landed working in the small and not in the large. It built a
table pair per Deaths source on every coalesced refresh whether or not anybody
was recording -- +6,720 bytes/iter on the 20x7 fixture, measured at 310158.1
against 303438.1 on the commit before it -- and it kept all three boundaries in
one 120-entry ring that `judge`, the only one of the three that is not rare,
overwrites within seconds. A player who armed it, ran a dungeon and typed
`/mm debug feign` got the least interesting boundary and neither of the two
that answer the question.

  * The three call sites now read a plain boolean before they build anything,
    matching the `Perf.on` idiom this addon already uses (performance-§2).
    The two comments that asserted this cost "one nil test plus one boolean"
    are corrected; they are true now.                            [R-01, R-10]
  * `judge` is admitted only for GUIDs a `cast` line already named, with a
    suppressed-row counter so an unexplained judge row is still surfaced. The
    ring is a write index rather than an O(n) table.remove.       [R-02, R-09]
  * Feign.Prune's not-in-group eviction is traced. `present` admits a roster
    entry only where the GUID is a safe key AND a token exists, which is always
    true for the local player and not always for a party member -- so the branch
    that best explains the reported asymmetry was the one branch producing no
    evidence at all. Evicted entries now report the state they held when the
    decision was made, not `<evicted>`.                           [R-03, R-13]
  * Six cases, each falsified against the mutation its `-- red under:` names.
    The three defects above sat on paths the suite ran through and asserted
    nothing about.                                                      [R-04]
  * The inventory and the badge catch up (they were nine cases behind before
    this branch); the perf baseline is re-recorded, because the committed one
    had gone 15.8 KB stale and that slack is what let R-01 past the guard.
                                                              [R-06, R-07, R-11]
  * core/Diagnostics.lua peeled: this changeset carried it 1566 -> 1726, past
    layout-§1's 1500 cap.                                               [R-08]

Issue #25 itself is NOT fixed here. This makes the diagnostic able to answer it.

Review: docs/reviews/2026-09-07/
```
