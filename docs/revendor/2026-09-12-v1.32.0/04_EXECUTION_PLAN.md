# 04 — Execution plan (B1 + B2 and the `/mm resetall` fix, one commit)

**Characterization.** The tests came first. They were written against the v1.32.0 copy and run
before any host change: 1800 passed, 15 failed. Every failure read the old behavior:
- `[Bulk]` where `[Set]` was expected;
- N counted as the rows in scope;
- `NS.Bulk` absent;
- a per-row `[Set]` line on each Defaults press (18 on General, 9 on Columns);
- a reset-all logging `switched to` plus `[Init] seeded`;
- `/mm resetall` leaving two windows standing;
- the three profile events sharing one handler.

**Files.**

- `settings/Schema_Paths.lua`:
  - `NS.Bulk` (`begin`, `finish`, `run`), with depth, the changed-only tally and profile-reset
    silence;
  - `storeWrite` counts inside a bracket, and `logWrite` is muted there;
  - `SetByPaths` runs a `summary` batch inside the bracket.
- `settings/OptionsSetup.lua`: the descriptor pair, and a `resetProfile` that answers whether it
  reset. The degraded `RestoreAllDefaults` is bracketed.
- `settings/Slash.lua`: the descriptor pair; `resetall` becomes `doResetAll`, which calls
  `Helpers.RestoreAllDefaults`.
- `settings/Columns.lua`: Defaults runs `restoreShippedColumns` and `H.RestoreDefaults` inside one
  `NS.Bulk.run`.
- `core/Database.lua`: one handler per profile event, worded by the event. The reset line has no
  count, and the seed trace is quiet while a reset rebuilds.
- `locales/enUS.lua`: the degraded acknowledgment string.
- `tests/wow_mock.lua`: each profile event gets the key real AceDB passes.

**The proving assertions.** Each is exact.
- Every page's Defaults press gives one `[Set] reset <page>: 1 rows`, then `0 rows`.
- Columns gives `reset columns: 2 rows`, then `0 rows`.
- A nested bracket gives one line.
- A live reset-all logs exactly `[Set] reset profile 'Default' to defaults`, and nothing else, when
  nothing else moves. The degraded reset-all logs the same.
- `/mm resetall` with two windows leaves one window at the shipped width and logs that one line.
- A copy says `copy from 'Source' to 'Target': N rows`, and the same copy again says `0 rows`.

**Commit boundary.** `3c41618`, "Settings: a bulk copy or reset is one [Set] line; /mm resetall is
the profile reset".
