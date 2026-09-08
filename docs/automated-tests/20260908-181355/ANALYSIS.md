# Analysis — 20260908-181355

- **Addon:** MultiMeters 0.1.0
- **Verdict:** green
- **Commit:** a348545 (`feat/2026-09-07-audit-review-remediation`), clean
- **Previous run:** [`20260825-103437`](../20260825-103437/) — **amber**

## Headline

**Green, and the last two runs were amber.** Lint 0/0 over 93 files, 1530 cases with none failed and
none skipped, fifteen perf scenarios all passing their own assertions, and `lizard` warning on 23
functions at max CCN 34 — recorded, not gating.

Two things changed the verdict. The perf suite failed two allocation ceilings on both August runs —
*a restricted pass allocated 447916 bytes/iter, over the 436000-byte ceiling* and *a dormant pass
allocated 351313 bytes/iter, over the 336000-byte ceiling* — and both now pass with room:
`refresh20x7Restricted` is 412373.3 and the dormant path 303438.1. And this is the first run whose
`RESULTS.md` came out of the runner end to end, which is what finally lets the file say what the
repository actually measures.

## The record this replaces said the opposite of the truth

The watch list above the table read, in full:

> **None.** `lizard` reports 0 warnings and a maximum CCN of 15

directly above a table row recording **19 warnings and a maximum of 31**. That is
`MULTIMETERS-R-05`. It was written at [`20260809-195454`](../20260809-195454/), where it was true,
and the runner had no way to update it: until test-kit revision 15 it wrote one table row and a fixed
lead-in, so the two tables `automated-tests-§4` mandates had no producer and a hand-written watch
list was the only kind there was. Four runs later the prose still described the first one.

The band table was stale in the same direction and by a wider margin. It listed three files on
notice, the largest at 1478. Those same three files are now **2270, 3080 and 2650** — every one of
them over the 1500 cap, and twelve more with them.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260825-103437` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 93 files | [`lint.txt`](lint.txt) | 47 → 93 files; 0/0 unchanged |
| tests | pass | 1530 passed, 0 skipped, 0 failed, 1530 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1257 → 1530 |
| perf | **pass** | 15 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | **fail → pass**; 13 → 15 scenarios |
| complexity | pass | 23 warnings, max CCN 34 | [`complexity.txt`](complexity.txt) | 19 → 23 warnings; max 31 → 34 |

**Complexity in full.**

| Metric | `20260825-103437` | This run |
|---|---|---|
| Total NLOC | 26531 | 32913 |
| Functions | 2884 | 3337 |
| Avg NLOC / function | 7.7 | 8.2 |
| Avg CCN | 2.5 | 2.6 |
| Max CCN | 31 | 34 |
| Avg tokens / function | 59.8 | 63.7 |
| Warnings (CCN > 15) | 19 | 23 |
| Warn rate (`Fun Rt` / `nloc Rt`) | — | 0.01 / 0.00 |
| Files 1000–1500 | 6 | 2 |
| Files over 1500 | 8 | 15 |

Read the band and cap figures together: the on-notice band did not empty, it **drained upward**. Six
files on notice and eight over cap became two and fifteen.

## Every warned function carries a disposition, and none of them is new

`M4-26` ruled on all 23 four days before this run, in `docs/ARCHITECTURE.md` § *Complexity register*.
This run is the first fresh `lizard` measurement since, and it resolves against that register
exactly: **the same 23 functions, in the same order, with the same 23 CCN values** — 34 for
`scanColumn`, 30 for `Cell:ApplyBorder`, 28 for `NS.ReorderableBlocks`, 27 for `Export.ChatLines`,
26 for `drawDeathEvents`, and so on down to the three CCN-16 rows. Eleven peels with an open issue
naming the seam (#35–#45), twelve accepts each carrying the condition that ends it.

The only thing that moved is the line ranges, and the register says in as many words that its ranges
are dated measurements rather than claims about today: `Cell:ApplyBorder` 646-726 → 659-739,
`NS.ReorderableBlocks` 215-310 → 227-322, `Cell:ApplyIcons` 1155-1231 → 1168-1244, `eventColumns`
1859-1912 → 1866-1919, `Tooltip:CellTooltip` 2335-2397 → 2342-2404, `drawDeathEvents` 1950-2032 →
1957-2039, `place` 1277-1409 → 1283-1415, `onPrintToChat` 1427-1492 → 1432-1497. Membership and CCN,
which are the invariants, did not move at all.

**Two rows can never carry a disposition forward, and that is a property of the data rather than a
defect.** `migrations[1]` and `migrations[12]` are both reported as `]` in `core/Database.lua` at
CCN 16. The runner keys on function name plus file and falls back to CCN to break a tie; neither key
separates these two, so it leaves both blank rather than attaching one entry's ruling to the other —
which is the right refusal, because a blank cell asks for a decision and a wrong one answers a
question nobody asked. Their home of record is the register, and the cells here say so.

## What moved

- **lint** — 47 → 93 files at 0/0, the test tree coming into scope.
- **tests** — 1257 → 1530, a gain of 273. `docs/test-cases.md` and the README badge already read
  1530, and the bundle's [`test-cases.md`](test-cases.md) is byte-identical to `docs/test-cases.md`
  at HEAD, so no count claim moves in this commit.
- **perf** — 13 → 15 scenarios, and from fail to pass. `feignTraceAbsent` and `feignTraceOff` are
  new and identical at 71224.1 bytes/iter, which is the point: the trace costs nothing when it is
  off and nothing when it is absent. `throttleIdle` allocates 0 and `suspended` 5202.3, so both
  quiet paths are cheap. The zero-overhead pair sits within noise of itself — `probeOverheadOff`
  303415.8 against `probeOverheadOn` 303420.9, five bytes apart — which is what `performance-§2`
  wants.
- **complexity** — 19 → 23 warnings and max 31 → 34. Both rises are accounted for by name in the
  register rather than being a surprise; `doDebug` is the one warned function that got **worse** this
  cycle, 23 → 25 under `M2-11`, for a stated reason, which is exactly the move a watch list exists
  to catch.

## On fifteen files over the cap

Every one is tracked. Eight carry an issue naming the seam a peel would follow (#27–#34) and seven
are register rows that peel with the module they mirror — a suite that mirrors an over-cap module has
no seam of its own, so peeling it first would commit to a partition the module has not chosen.
`layout-§1` allows a breach exactly three terminal states: peeled, an issue naming the seam, or a
ratified register row with a re-check trigger. All fifteen sit in the second or third.

`tests/test_layout_cap.lua` asserts the *membership* of that census in both directions on every run —
a file that crosses and is not listed turns the suite red, and so does a row for a file that has
fallen back under. It is green, which is how all fifteen were already accounted for before this run
measured them. **Nothing is peeled this cycle**; `03_SPEC.md` § C22 rules it out, and the deliverable
was the disposition.

## The `ANALYSIS.md` gap, noted once

Four of this repository's five bundles carry no `ANALYSIS.md` — `20260809-194203`, `20260825-021705`,
`20260825-103437`, and until this file, this one. The first three are not getting one. Writing an
analysis today into a folder stamped in August would date a reading to a day nobody took it, which is
worse than a gap, because a gap is legible. Fixed forward: this bundle has one, and every bundle from
here gets one at the time of its run. Collection-wide the gap stands at 37 of 95 bundles.

## Actions

None in this bundle. Eleven peels are filed and owned, twelve accepts each carry a re-check trigger,
and fifteen cap breaches are tracked. On the shelf-life clock (`automated-tests-§4`): this repository
has exactly one release run, [`20260809-195454`](../20260809-195454/), and it predates every entry in
the register, so none of the twelve accepts has spent a release cycle yet. The clock starts at the
next `--release` bundle.
