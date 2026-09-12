# 03 — Decisions

**A non-interactive run.** The orchestrator's rollout brief (debug-logging-§10, standard v2.44.0)
stood in for the interview. Two corrections arrived during the run and were folded in before the
commit. Filing and pushing were skipped by instruction.

| Candidate | Decision | Record |
|---|---|---|
| B1: Options bracket | **adopt** | Commit `3c41618`. `NS.Bulk` is the one mute; N is counted by the seam. |
| B2: Slash bracket | **adopt (defensive)** | Commit `3c41618`. `/mm resetall` no longer reaches `CliResetAll`. |

## Calls made along the way

- **N is the seam's count, not the library's.** The orchestrator's first correction ruled that
  bulkEnd's `count` must not be N. While a bracket is open, the seam reads each row before and
  after its write, and counts the row once, only if its stored value moved. The column array is
  counted the same way.
- **Nesting.** A depth counter sums the tallies, logs only at depth 0, and stays silent if any level
  reported `info.profileReset`. The Columns page brackets its array write around the library's
  page bracket, so the nesting is real.
- **Zero rows.** A press on a page already at its defaults logs `[Set] reset <page>: 0 rows`. The
  line is emitted, and no per-row line ever is.
- **The profile-reset line carries no count.** The orchestrator's second correction ruled that the
  count must be the rows the reset changed, or be omitted, and never the stored-row total. A reset
  here deletes every extra window, so "rows changed" is neither cheap nor well defined.
  AceDBOptions' Reset Profile also reaches `OnProfileReset` with no pre-reset hook. So the count is
  omitted, and with no count handed off there is nothing to go stale.
  `tests/test_database.lua` pins the countless wording.
- **`/mm resetall` does not confirm.** It did not before either. The popup guards a click that can
  be mis-aimed, and a typed verb is not one. This is flagged for the owner.
- **The `[Init]` seed trace is quiet during a profile reset.** The reset line already says the
  profile is back to one shipped window, so a reset-all with nothing else moving logs one line in
  total. Reactor lines a row's `onChange` emits, such as `[Test] off`, stay.
