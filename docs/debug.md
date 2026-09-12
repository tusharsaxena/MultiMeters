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
line. Eighteen exist. The three that dominate a live capture are `Aggregator` (one summary line per
refresh pass), `Render` (one per window per pass) and `Roster` (one per rebuild).

A pass whose summary line is **unchanged** from the previous pass is not logged; a change is never
delayed and never dropped, and a repeat is collapsed to a heartbeat carrying `(xN)`. That behaviour
is a documented deviation from `debug-logging-§8` — see `## Documented deviations` in
[ARCHITECTURE.md](ARCHITECTURE.md) — and it exists because four passes a second into a capped buffer
otherwise leaves a console holding forty seconds of one repeated string.

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
