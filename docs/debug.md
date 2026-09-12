# Debug surface

Everything `/mm debug` reaches: the console, the two session flags behind it, the channels that write
into it, and the four probes that print a report instead.

The console itself is `LibKa0s-DebugLog-1.0`'s window — its buffer, its copy window and its
formatters are the library's, configured in `core/DebugLogSetup.lua`. What is documented here is
this addon's own surface on top of it.

## The verbs

| Command | What it does |
|---|---|
| `/mm debug` | Toggle the console window. Never touches a flag. |
| `/mm debug on` / `off` | Set the session logging flag. Works with the window closed. |
| `/mm debug tooltip` | Toggle the tooltip log channel. Off by default; prints the state it landed in. |
| `/mm debug diag` | Print the diagnostic report. |
| `/mm debug recap` | Print the death-recap probe alone (issue #1). |
| `/mm debug identity` | Print the mid-pull correlation capture (issue #22). |
| `/mm debug feign on` / `off` | Arm and disarm the feign-death recording (issue #25). |
| `/mm debug feign` | Print the recording. |

**Logging and the window are separate on purpose.** Logging runs with the console closed, so a bug
can be reproduced first and the log read afterwards.

**The four read verbs run without the console seam at all.** They are what a player is asked to type
when something looks wrong, and requiring them to open a window first is one more step between a bug
and its report. `feign` is the only one that reads an argument, because it is the only one that is
not a read: a feign is over before a player finishes typing, so the trace is armed before the run and
printed after it. A word `feign` does not recognise is named and refused rather than falling through
to the report — `/mm debug feign of`, typed by somebody who meant `off`, used to print an empty
recording and leave the trace armed with no line saying so.

## The flags

Both live on `NS.State`, both are session-only, and neither ever reaches SavedVariables
(`debug-logging-§5`). A console left on does not survive a `/reload`, which is the point:
`tests/test_state.lua` asserts it three ways.

| Flag | Default | Written by | Read by |
|---|---|---|---|
| `State.debug` | off | `NS.DebugLog:SetEnabled` only | every `NS.Debug` call site, through the sink |
| `State.debugTooltip` | off | `/mm debug tooltip` only | the three `Tooltip` channel sites |

### Why the tooltip channel has a switch of its own

One channel can drown the log it shares. The buffer is capped — 1500 lines as of LibKa0s v1.15.0 —
and three call sites write on the `Tooltip` channel:

| Site | Fires on |
|---|---|
| `modules/Row.lua` | **mouse motion over a row** |
| `modules/Tooltip_Builders.lua` (cell) | a cell tooltip being built |
| `modules/Tooltip_Builders.lua` (name) | a name tooltip being built |

The first is the loud one: resting the cursor on a row emits a line as fast as the mouse reports its
position, so a few seconds of hovering evicts the `[Aggregator]` and `[Render]` lines somebody was
actually reading. Gating it costs nothing — the tooltips themselves are unaffected, only the log is.

**A half-gated channel reads exactly like a gated one from the console**, which is how the first cut
of this shipped with `modules/Row.lua` missed. `tests/test_slash.lua` scans the source for
`Debug("Tooltip"` call sites not preceded by the flag, so a fourth site added without the guard fails
the suite rather than quietly restoring the flood.

## The channels

`NS.Debug(channel, format, ...)` is the sink; the channel is the bracketed name at the head of the
line. Nineteen go through it: eighteen from this addon's own call sites, and `Cfg`, which the options
library logs through the descriptor's `debug` hook. The nineteen do not include `Perf`, whose lines
the perf harness writes straight to the buffer with `DebugLog:Add`, so the console can show twenty.
The three that dominate a live capture are `Aggregator` (one summary line per refresh pass),
`Render` (one per window per pass) and `Roster` (one per rebuild).

A pass whose summary line is **unchanged** from the previous pass is not logged; a change is never
delayed and never dropped, and a repeat is collapsed to a heartbeat carrying `(xN)`. That behaviour
is a documented deviation from `debug-logging-§8` — see `## Documented deviations` in
[ARCHITECTURE.md](ARCHITECTURE.md) — and it exists because four passes a second into a capped buffer
otherwise leaves a console holding forty seconds of one repeated string.

### Settings lines

Every settings write is logged once, at the write seam (`NS.SetByPath`, `settings/Schema_Paths.lua`),
as `[Set] <path> = <value>` (`debug-logging-§10`). Two kinds of act are logged differently.

| Act | What the console shows |
|---|---|
| One write: a widget, `/mm set`, `/mm reset <path>` | `[Set] <path> = <value>` |
| A batch that is not a bulk act: a header sort, a resize, a segment pick | one `[Set] <path> = <value>` per row |
| A page's **Defaults** button | `[Set] reset <page>: N rows` |
| The Columns page's **Defaults** button (the array and the header rows) | `[Set] reset columns: N rows` |
| Copy settings from one window onto another | `[Set] copy from '<source>' to '<target>': N rows` |
| **Reset all settings** or `/mm resetall` once its popup is accepted, or Profiles → **Reset Profile** | `[Set] reset profile '<name>' to defaults` |
| Profiles → **Copy From** | `[Set] copied profile '<source>' → '<name>'` |
| A profile switch | `[Profile] switched to '<name>'` |

**A bulk act writes no line per row.** N counts the rows whose stored value actually moved, so a
row already at its default does not add to it and a second Defaults press reads `0 rows`. The count
is kept by the seam itself inside `NS.Bulk`'s bracket, not taken from the library. Brackets nest,
and only the outermost logs. A reactor line a row's `onChange` emits during the act, such as
`[Test] off`, is not a `[Set]` line, so it stays.

**A profile reset is one line, from the profile handler.** `core/Database.lua`'s `OnProfileReset`
logs it. The reset-all bracket, which also wraps the session-row walk, adds nothing, and the re-seed's
`[Init]` trace is quiet during a reset. The line carries no row count. A reset deletes every extra
window, so "rows changed" is neither cheap nor well defined, and `debug-logging-§10` allows the count
to be left off. It must never be the profile's stored-row total.

**An act an error stopped still logs its one line, ending ` (stopped by an error)`.** A row that
raises partway through a Defaults press, a copy or a reset-all closes the bracket anyway. The line
counts the rows written before the error, the mute is released, and the error is re-raised. The
next bracket starts unmarked. `OnProfileReset` works the same way: it logs its line after the
rebuild, as `[Set] reset profile '<name>' to defaults (stopped by an error)` when the rebuild
raised. A reset-all whose `ResetProfile` itself raised never reaches that handler, so its bracket
logs `[Set] reset all: N rows (stopped by an error)` instead.

## The probes

Each answers to one issue and is self-contained so it can be deleted with that issue. They were
peeled out of `core/Diagnostics.lua` on 2026-09-09 for `layout-§1`, one file apiece.

| File | Verb | Issue | Prints |
|---|---|---|---|
| `core/Diagnostics.lua` | `diag` | — | the general report, and the `out` seam the siblings share |
| `core/Diagnostics_DeathRecap.lua` | `recap` | #1 | whether this client can read a death recap, searched two ways |
| `core/Diagnostics_Identity.lua` | `identity` | #22 | the correlation rectangle, the seat probe, the secret-GUID lookup verdict and the source-field audit |
| `core/Diagnostics_Feign.lua` | `feign` | #25 | the armed feign-death recording |

`identity` is the one typed **mid-pull**, by a player who was asked to type it. It reports what it
needs — the flag on, and a pull running — rather than going quiet when it has neither, and it says
plainly when a capture proves nothing: an all-plain reading taken after the pull refuses to draw the
secret-GUID verdict rather than reporting the control as the answer. Its field audit also knows which
absences a session explains. A player row has no creature id and an NPC row has no GUID, so on an
all-player column `sourceCreatureID` is missing from every row by construction, and on an all-NPC
column `sourceGUID` is. Those print in lower case with the reason beside them and stay out of the
defect tally (issue #48).

## Rules a line in here obeys

- **R1 — a stored figure is described, never inspected.** A meter value is reported as plain or
  secret by a concatenation probe; its magnitude is never read. `distinct` counts in the field audit
  are counts of plain values only.
- **Every argument goes through `NS.SafeToString`.** A value a branch could not use is exactly the
  one likely to be secret, and a secret raises inside `string.format`.
- **No probe reaches `C_DamageMeter`.** `modules/Provider.lua` is the only file that may, so a probe
  that needs a raw source row asks `Provider.ProbeSourceFields` or `Provider.ProbeSourceLookup` for a
  *description* of one.

## Related

- [testing.md](testing.md) — the harness, the lint, the green commit gate
- [midnight-quirks.md](midnight-quirks.md) — the client behaviours the probes were written to measure
- [ARCHITECTURE.md](ARCHITECTURE.md) — the slash surface in full, and the deviation register
