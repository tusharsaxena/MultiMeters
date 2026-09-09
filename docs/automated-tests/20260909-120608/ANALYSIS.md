# Analysis — 20260909-120608

- **Addon:** MultiMeters 0.1.0
- **Verdict:** green
- **Commit:** cc89785 (feat/2026-09-09-ccn-loc-remediation), dirty
- **Previous run:** [`20260908-181355`](../20260908-181355/)

## Headline

All four suites pass, and the two figures this run was taken to measure both reached zero:
**`lizard` warns on no function** where it warned on 23 the day before, and **no authored file is over
`layout-§1`'s 1500-line cap** where fifteen were. That clears the last of `automated-tests-§3`'s
release gate — all four at `pass` plus zero functions above CCN 15 — which this addon has never
satisfied and which is why it has never cut a tag. Nothing newly crossed a threshold. The one thing to
act on is not a regression but a consequence: the 1000–1500 on-notice band went from 2 files to 19,
because a peel lands a file wherever its seam falls, and six of the nineteen are source.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260908-181355 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 122 files | [`lint.txt`](lint.txt) | +29 files, still 0/0 |
| tests | pass | 1728 passed, 0 skipped, 0 failed, 1728 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +198 cases, all passing |
| perf | pass | 15 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged at 15 |
| complexity | pass | 0 warnings, max CCN 15 | [`complexity.txt`](complexity.txt) | **23 → 0 warnings; max CCN 34 → 15** |

| Metric | Value | Previous |
|---|---|---|
| Total NLOC | 36689 | 32913 |
| Functions | 3752 | 3337 |
| Avg NLOC / function | 8.1 | 8.2 |
| Avg CCN | 2.4 | 2.6 |
| Max CCN | 15 | 34 |
| Avg tokens / function | 62.8 | 63.7 |
| Warnings (CCN > 15) | **0** | 23 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 | 0.01 / 0.03 |
| Files in the 1000–1500 band | 19 | 2 |
| Files over the 1500 cap | **0** | 15 |

**Read the averages, not the totals.** Total NLOC rose by 3776 and the function count by 415, and
neither is a complexity signal — they are what a refactor that replaces branches with named helpers
and data tables does to a codebase, plus 198 new test cases. The figures that carry meaning all moved
the right way: **avg CCN 2.6 → 2.4**, **avg NLOC/function 8.2 → 8.1**, **avg tokens 63.7 → 62.8**. The
addon is larger and each function in it is smaller and simpler, which is the trade `performance-§11`'s
permitted shapes are supposed to make.

**Max CCN is 15, which is exactly the threshold and not under it.** **Ten** functions sit on it, nine
in shipped source and one in a suite — `NS.ShouldShow` (`core/MultiMeters.lua:461`), `scanColumn`
(`modules/Aggregator.lua:1028`), `deathRow` (`modules/DrillDown.lua:618`), `artFor` and
`HeaderControls` (`modules/HeaderControls.lua:279`, `:449`), `buildMap` (`modules/Targets.lua:270`),
`Tooltip:SpellTooltip` (`modules/Tooltip_Builders.lua:970`), `WindowProto` (`modules/Window.lua:757`),
`Build` (`settings/Profiles.lua:59`) and one anonymous entry in `tests/test_texture_paths.lua:273`.
They pass, because `lizard` warns *above* 15. They also have zero headroom, and this addon's own
history says what that means: `docs/automated-tests/RESULTS.md`'s v0.1.0 watch list recorded four functions at
exactly 15 with "whoever next edits one knows there is **zero** headroom left", and by 2026-09-08 two
of them read 30 and 24. That is the shape to watch, not the count.

## What moved

- **lint** — 93 → 122 files, still 0 warnings / 0 errors. The 29 new files are the peels: thirteen
  source siblings, about fourteen suites and two mocks. Scope is the whole authored tree; `.luacheckrc`
  excludes only `libs/` and `tests/_kit/`, so the 0/0 covers everything this repo writes.
- **tests** — 1530 → 1728, zero failed and zero skipped in both. 194 of the 198 new cases are the
  characterization tests written *before* the refactor and run against the unrefactored code, as
  `performance-§11` requires; the rest follow the peels. No case was lost to a peel: each of the eight
  suite splits held its count exactly.
- **perf** — 15 scenarios, unchanged, and that is the point. The offline scenarios are the same
  scenarios pinning the same costs across a cycle that rewrote 23 functions and split 15 files.
- **complexity** — the headline. 23 warnings → 0; max CCN 34 → 15. Every one of the 23 came down,
  including the twelve that carried a ratified **Accepted** disposition with a re-check trigger: an
  accept is a compliant watch-list state and it is not a release gate.
- **layout** — 15 files over cap → 0; band 2 → 19. The band grew because the peels landed files in it,
  not because anything grew into it.

## Complexity watch list

### Functions `lizard` warned on

None. First run in this repository's history to say so.

### Files by `layout-§1` band

19 files in the 1000–1500 band, 0 over the cap. The table and every disposition are in
[`../RESULTS.md`](../RESULTS.md#complexity-watch-list) rather than restated here — a figure copied into
two files is a figure that will disagree with itself, which is the failure this cycle spent a commit
repairing elsewhere.

The four tightest are `tests/wow_mock.lua` (34 lines of headroom), `tests/test_row.lua` (44),
`modules/Row.lua` (58) and `tests/test_window_header.lua` (79). `modules/Row.lua` is the one to watch:
source, on the refresh path, and the file every identity, spec-icon and pet-fold change has
historically landed in.

## Actions

1. **None gating.** The release gate is satisfied for the first time; whether to tag is a separate
   decision and belongs to `/wow-addon:bump-version`.
2. **`modules/Row.lua` (1442) and `tests/test_row.lua` (1456)** — 58 and 44 lines of headroom, and they
   mirror each other, so they will cross together and peel together when they do. The seam is already
   visible: the value cell is the largest remaining block in the module. No issue is open for this; it
   is new here, and the band row is its only record.
3. **`tests/wow_mock.lua` (1466)** — tightest in the repository, and the file every one of the 60
   suites loads. The next thing added to it should go to a third sibling beside `mock_secrets.lua` and
   `mock_frame.lua` rather than into it. New here.
4. **The ten functions at exactly CCN 15**, listed under *Suites* above. Passing, zero headroom, and
   this addon has watched exactly this state turn into CCN 30 once already — its v0.1.0 watch list
   carried four at 15 and two of them read 30 and 24 a year later. Two of the ten are functions this
   cycle refactored *down* to exactly 15 — `scanColumn` from 34 and `WindowProto:BuildLayout` from 24,
   both verified against the previous run's `complexity.txt`. That is the expected shape of a refactor
   aimed at a threshold, and it is also why they are worth naming: a function parked exactly on a
   limit is one edit from crossing it. New here.
