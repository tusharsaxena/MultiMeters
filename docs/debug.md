# Debug surface

Everything `/mm debug` reaches: the console, the two session flags behind it, the channels that write
into it, the diagnostics report, and the three probes that print a report of their own.

The console itself is `LibKa0s-DebugLog-1.0`'s window — its buffer, its copy window and its
formatters are the library's, configured in `core/DebugLogSetup.lua`. What is documented here is
this addon's own surface on top of it.

## The verbs

| Command | What it does |
|---|---|
| `/mm debug` | Toggle the console window. Never touches a flag. |
| `/mm debug on` / `off` | Set the session logging flag. Works with the window closed. |
| `/mm debug tooltip` | Toggle the tooltip log channel. Off by default; prints the state it landed in. |
| `/mm diagnostics`, `/mm debug diagnostics` | Write the diagnostics report into the console, after whatever is already there (`debug-logging-§14`), turning logging on for the session first if it is off. Both forms run the same report; `diag`, its old name, is an unknown word now. |
| `/mm debug recap` | Print the death-recap probe alone (issue #1). |
| `/mm debug identity` | Print the mid-pull correlation capture (issue #22). |
| `/mm debug feign on` / `off` | Arm and disarm the feign-death recording (issue #25). |
| `/mm debug feign` | Print the recording. |

**Logging and the window are separate on purpose.** Logging runs with the console closed, so a bug
can be reproduced first and the log read afterwards.

**The console's title bar carries an orange Diagnostics link** (LibKa0s-DebugLog-1.0 minor 16), just
right of the Debug On/Off label with a small gap, drawn as plain text like that label. A click runs
the same report as `/mm diagnostics`, `NS.DebugLog:RunDiagnostics()`.

**The four read verbs run without the console seam at all.** They are what a player is asked to type
when something looks wrong, and requiring them to open a window first is one more step between a bug
and its report. `feign` is the only one that reads an argument, because it is the only one that is
not a read: a feign is over before a player finishes typing, so the trace is armed before the run and
printed after it. A word `feign` does not recognize is named and refused rather than falling through
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

One channel can drown the log it shares. The buffer is capped — 3000 lines as of LibKa0s v1.60.0 —
and three call sites write on the `Tooltip` channel:

| Site | Fires on |
|---|---|
| `modules/Row.lua` | **mouse motion over a row** |
| `modules/Tooltip_Builders.lua` (cell) | a cell tooltip being built |
| `modules/Tooltip_Builders.lua` (name) | a name tooltip being built |

The first is the loud one: resting the cursor on a row reaches it as fast as the mouse reports its
position, and the cell and name tooltips are rebuilt on every refresh the cursor sits through. Written
plainly, a few seconds of hovering evicts the `[Aggregator]` and `[Render]` lines somebody was
actually reading. Gating it costs nothing — the tooltips themselves are unaffected, only the log is.

**Opt-in does not exempt a path from `debug-logging-§9`**, so all three are also change-gated: each
writes through `NS.DebugSteady` keyed on the hovered frame, so a hover speaks once when it starts
(and again if its count changes) and is silent while it holds. Leaving the cell or row calls
`NS.DebugSteadyForget` on that frame, which writes the held run's `(xN)` line and forgets it, so the
next hover of the same cell speaks again. `tests/test_row_mouse.lua` pins both.

**A half-gated channel reads exactly like a gated one from the console**, which is how the first cut
of this shipped with `modules/Row.lua` missed. `tests/test_slash_diagnostics.lua` scans the source for
`Tooltip` call sites (through `NS.Debug` or `NS.DebugSteady`) not preceded by the flag, and expects
exactly three, so a fourth site added without the guard fails the suite rather than quietly restoring
the flood.

## Coverage

`NS.Debug(channel, format, ...)` is the sink; the channel is the bracketed tag at the head of the
line. This section is the map of what writes each tag and when, so a log read back after a repro can
be matched to the code that wrote it (`debug-logging-§8`). Twenty-one tags come from this addon's own
call sites; `Perf` is written straight to the buffer by the perf harness with `DebugLog:Add`.

**The library's tags.** `Cmd`, `Lifecycle`, `Cfg`, `Launcher` and part of `Set` are written by
LibKa0s itself, through the gated sink this addon hands each descriptor as `debug` (standard v2.73.0,
`debug-logging-§4`; LibKa0s v1.65.0): the slash dispatcher's refusals, the stand-down latch's edges,
the options panel's combat lock, the launcher, and the schema runtime's write lines. The wording is
the library's, and this addon writes **no** line of its own beside any of them: the `[Init] stood
down` / `stood up` pair `core/LifecycleSetup.lua` used to write is gone, replaced by the library's
`[Lifecycle]` line. `tests/test_library_lines.lua` pins each landing here once. A **state** line
written while logging is off at login (the launcher's registration, the rejected events) goes through
the console's at-enable queue, `NS.DebugAtEnable`, and is written the first time logging is turned
on, once (`debug-logging-§8`, dependencies once at enable).

**Quiet steady state (`debug-logging-§9`).** Every path that repeats — the refresh tick, the
visibility pass, a roster retry, a drill view, a refusal the join repeats on every pass, the meter
availability memo, a tooltip rebuilt under a resting cursor — writes through `NS.DebugSteady`
(`core/DebugLogSetup.lua`). A line is written
when its summary changes and **not otherwise**; when a run ends, its line comes out once more with
`(xN)`, the number of passes it stood for, just before the line that ended it. There is no heartbeat:
through a whole dungeon key the ten-second heartbeat this replaced filled the console with an
`[Aggregator]` / `[Render]` pair `(x41)` every ten seconds and nothing changing. Whether the loop is
still alive is `/mm diagnostics`'s `aggregator` section, whose `age=` is the time since each
window's last pass. Toggling logging forgets every run, so the first pass after `/mm debug on`
always speaks, and so does the console's **Clear** (the descriptor's `onClear`, LibKa0s-DebugLog
minor 18). The sink is this addon's rather than the console's `DebugChanged` because it counts a run
and writes the `(xN)` line; the library gate has no count, and `debug-logging-§9` names `onClear` as
the route for a host that keeps its own.

| Tag | Written by | When | Steady-gated |
|---|---|---|---|
| `Init` | the library's `initSummary` (`core/DebugLogSetup.lua`) | on `/mm debug on`: version, schema, profile, window count, whether LibSharedMedia loaded | — |
| `Init` | `core/Database.lua` | a default window seeded into an empty profile | — |
| `Init` | `core/MultiMeters.lua` | an enable whose event registrations the client refused, naming them; at login it is held by the at-enable queue and written when logging is turned on | — |
| `Lifecycle` | `LibKa0s-Lifecycle-1.0` (the library's) | `stood down: added <hold> (holds: <set>)` and `stood up: released <hold> (holds: none)`, one line per edge of the addon's own latch; a hold that moves no edge writes nothing | — |
| `Cmd` | `LibKa0s-Slash-1.0` (the library's) | `refused <verb>[ <path>]: <guard>` — each refusal the dispatcher decides: the disabled gate (`refused lock: disabled`), an unknown verb, a get/set/reset path not found or a value it could not parse, a profile switch refused (unknown, already current, in combat); the chat line is unchanged | — |
| `Migrate` | `core/Database.lua` | each schema step that runs, and a version with no step | — |
| `Profile` | `core/Database.lua` | a profile switch | — |
| `Set` | the schema runtime (library) and `core/Database.lua` | every settings write, bulk act and profile reset or copy — see [Settings lines](#settings-lines) | — |
| `Set` | `settings/Schema_Paths.lua` | `<path> refused: <reason>` — a write the seam rejected, with the sentence the caller shows | — |
| `Event` | `core/MultiMeters.lua` | each world entry, zone, group and combat edge and each restriction change (below) | — |
| `Bus` | `core/Namespace.lua` | message registrations the bus refused on stand-up | — |
| `Provider` | `modules/Provider.lua` | `meter available` / `meter unavailable: <reason>` when the answer changes; a reset of every session; suspend and resume | availability |
| `Aggregator` | `modules/Aggregator.lua` | one pass summary per window (`window=… rows=… dropped=… sort=… reason=…`) | yes |
| `Aggregator` | `modules/Aggregator.lua` | `dropped guid=…` — why the first refused source of a pass was refused | yes |
| `Aggregator` | `modules/Aggregator_Identity.lua` | the identity-correlation rectangle, on a mid-pull pass | yes |
| `Render` | `modules/Window.lua` | `window N drew D/E rows` per window per pass | yes |
| `Roster` | `modules/Roster.lua` | `built members=…` or `partial build (a of b) — will retry` (a held build, flushed by the next `built`) | yes |
| `Roster` | `modules/Roster.lua` | the remembered roster pruned or forgotten | — |
| `Visibility` | `modules/Visibility.lua` | every window's show answer and its rule (`#1=show(dungeon)`), on a roster, zone, combat or player-state edge, under debug only | yes |
| `Window` | `modules/Window_Placement.lua` | a window moved by a drag; a shown window hidden, with the reason | — |
| `Window` | `modules/Window_Header.lua` | a pinned segment dropped as stale; `sort by name refused: restricted` | — |
| `Windows` | `modules/WindowManager.lua` | a window created, deleted, renamed, copied or reset | — |
| `Test` | `core/State.lua`, `modules/WindowManager.lua` | test mode on or off; `start refused: in combat` | — |
| `DrillDown` | `modules/DrillDown.lua` | entering and leaving a drill view, a recap opened | — |
| `DrillDown` | `modules/DrillDown.lua` | `rows window=… n=…` for the drill view being drawn | yes |
| `Export` | `modules/Export.lua` | a chat dump sent (at once, staggered, or printed locally); a staggered dump's hold (`sent line 1 of N to X, the rest queued`) pairs with `sent the queued rest of a dump (N-1 lines) to X` when the last queued line goes out, or with `canceled the queued rest of a dump: <why>` when the tail is dropped — a hold with neither is a tail whose timers never ran | — |
| `Export` | `modules/Export_Modal.lua` | `csv`, `chat` or `open refused: <sentence>` — the refusal the player was shown | — |
| `Format` | `modules/Format.lua` | the number formatter degrading at build (no breakpoints, no floor) | — |
| `Feign` | `modules/Feign.lua` | a Feign Death cast noted | — |
| `Tooltip` | `modules/Row.lua`, `modules/Tooltip_Builders.lua` | row hover, cell and name tooltips — **only** with `/mm debug tooltip` on (above) | yes, per hovered frame |
| `Columns` | `settings/Columns.lua` | the settings panel's Columns entry painted | — |
| `Blocks` | `settings/ColumnBlocks.lua` | column blocks released, and the drag list's own trace | — |
| `Cfg` | `LibKa0s-Options-1.0` (the library's) | the settings panel opened, or its open or register held in combat and the parked register's `register flushed (combat ended)`; each write, Defaults, tab, rail or page show the combat lock refused, as `<what> refused (in combat)`, once per text per combat | — |
| `Launcher` | `LibKa0s-Launcher-1.0` (the library's) | the minimap and compartment button's own trace; its state lines (`registered`, a broker library absent) are held by the at-enable queue and written when logging is turned on | — |
| `Perf` | the perf harness | a capture's steps | — |

**Deliberately not logged.** The player-state block (mount, vehicle, form, gliding, pet battle,
death) has no `[Event]` line by the owner's ruling; its effect shows in the `[Visibility]` line. The
spellcast, system-message and `DAMAGE_METER_*` events fire constantly and are not traced; their
effect is the pass lines above. The `pcall`s in `core/Compat.lua`, `core/CoreSetup.lua`,
`core/Secrets.lua` and `modules/Format.lua` are probes whose failure is an answer (a secret refused, a
formatter missing), not an error, and a line per failure would be a line per cell. The disabled
refusal a slash verb prints is the library's `[Cmd]` line above, not this addon's;
`/mm diagnostics`'s `state` section records the disabled hold.

### The `[Event]` line

`Event` (owner, 2026-09-29) is one line per game event that changes where a window may show or what
the meters may read: `[Event] <EVENT> lockdown=<bool> restricted=<bool>`, then the event's fields.
`restricted=` is `NS.State.restricted` as the line is written; for
`ADDON_RESTRICTION_STATE_CHANGED … type=<n> state=<n>` that is after the handler refreshed it. The
others are `PLAYER_ENTERING_WORLD … login=<bool> reload=<bool>`, `ZONE_CHANGED_NEW_AREA`,
`GROUP_ROSTER_UPDATE` and both `PLAYER_REGEN_` edges.

### Settings lines

Every settings write is logged once, at the write seam (`NS.SetByPath`, `settings/Schema_Paths.lua`),
as `[Set] <path> = <value>` (`debug-logging-§10`). Two kinds of act are logged differently.

| Act | What the console shows |
|---|---|
| One write: a widget, `/mm set`, `/mm reset <path>` | `[Set] <path> = <value>` |
| A batch that is not a bulk act: a header sort, a resize, a segment pick | one `[Set] <path> = <value>` per row |
| A page's **Defaults** button | `[Set] reset <page>: N rows` |
| The Columns entry's **Defaults** button (the array and the header rows) | `[Set] reset columns: N rows` |
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

## The diagnostics report

`/mm diagnostics` and `/mm debug diagnostics` run one report (`debug-logging-§14`). It is what the
README's `## Reporting a bug` asks a player to copy, so it has to work from any state: logging off,
the console closed, the addon disabled, or mid-pull under the restriction. The console's Diagnostics
link runs the same report.

**Running it turns debug logging on for the session** (`debug-logging-§14`, LibKa0s
DebugLogDiagnostics minor 2), as `/mm debug on` would, and a `/reload` turns it off again. When
logging is off, the run goes through the flag's one seam (`NS.DebugLog:SetEnabled(true)`) before it
writes, so the `debug logging ON` chat line, the `[Debug] logging enabled` console line and the
`[Init]` summary land just ahead of the begin marker, and the header reads `debug logging: on`. It
never turns logging off, and with logging already on it writes no second enable line. This addon
keeps the library's default: its descriptor in `core/DebugLogSetup.lua` does not set
`diagnosticsEnablesLogging = false`. The sections read state only and never touch the flag. Because
logging is on while the sections run, a gated trace their reads cause (the provider's
`[Provider] meter available` line, the first time the memo is asked) can also land ahead of the
begin marker.

**The frame is the library's.** `LibKa0s-DebugLog-1.0`'s `RunDiagnostics` writes the begin and end
markers carrying the brand (`Ka0s Multi Meters`), the identity header, a pcall around each section
(a raise costs one `section <name> failed` line), the plain-text strip and the line cap: 1200
lines or the buffer's 3000 less 100, whichever is smaller, ending in a `truncated` line and then the end
marker when a report runs past it. It appends after the trace already in the buffer, clears
nothing, and writes through the ungated append (`debug-logging-§12`).

**The sections are this addon's,** handed over by `core/Diagnostics.lua`'s `Sections()` through the
descriptor field `diagnostics`, in this order:

| Section | File | Prints |
|---|---|---|
| `state` | `core/Diagnostics_Runtime.lua` | the stored enable flag, disabled and stood down, the Lifecycle holds, both schema stamps, the profile and its list, the restriction as mirror, authority and raw state, test mode, the tooltip channel, the lock view, the provider's suspend flag |
| `settings` | same | the profile's rows that differ from their defaults, plus `enabled`, `master.visibility` and `data.mergePets` always |
| `window settings` | same | each window diffed against its default; colors and position as one value each, from config |
| `windows` | same | the resolved context, then per window: built, shown, minimized, locked, rows drawn, `ShouldShow`'s answer and the rule behind it, size and position from config |
| `sessions` | same | the sessions the client holds, each window's pin, and the fallback a stale pin takes |
| `aggregator` | same | the last render pass per window |
| `roster and caches` | same | the cached group, the remembered map, every `State.cache` table's size |
| `atlases` … `death recap` | `core/Diagnostics.lua`, `core/Diagnostics_DeathRecap.lua` | the client probes: atlases, number formatting, visibility, header, name column, cells, tooltip font and width, targets, provider order, death recap |
| `events` | `core/Diagnostics.lua` | the event registrations the client refused, last |

**It reads and never changes.** Nothing it reaches takes or releases a hold, registers an event,
arms a timer, builds the roster, dirties a window or moves the settings panel's window pointer
(`tests/test_diagnostics_runtime.lua` lists the calls it must never make). While the addon is stood
down, `sessions` and `aggregator` say `stood down` rather than printing empty data.

**Secrets print as `<secret>`.** Every session figure, name and duration goes through the writer's
`str`, and a window's size and position come from its config, never from the frame, whose geometry
is secret once it has been handed a secret (R3 in [ARCHITECTURE.md](ARCHITECTURE.md)).

`diag`, the report's old debug word, is an unknown word now: `/mm debug diag` toggles the console
as any unknown word does and `/mm diag` answers `unknown command`. No other name runs the report.

## The probes

Each answers to one issue and is self-contained so it can be deleted with that issue. They were
peeled out of `core/Diagnostics.lua` on 2026-09-09 for `layout-§1`, one file apiece.

| File | Verb | Issue | Prints |
|---|---|---|---|
| `core/Diagnostics.lua` | `diagnostics` | — | the sections of the diagnostics report, and the `out` seam the siblings share |
| `core/Diagnostics_DeathRecap.lua` | `recap` | #1 | whether this client can read a death recap, searched two ways |
| `core/Diagnostics_Identity.lua` | `identity` | #22 | the correlation rectangle, the seat probe, the secret-GUID lookup verdict and the source-field audit |
| `core/Diagnostics_Feign.lua` | `feign` | #25 | the armed feign-death recording |
| `core/Diagnostics_Runtime.lua` | `diagnostics` | — | the addon-state sections that open the report (not a probe: no issue, no topic word) |

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
- [midnight-quirks.md](midnight-quirks.md) — the client behaviors the probes were written to measure
- [slash-dispatch.md](slash-dispatch.md) — the slash surface in full
- [ARCHITECTURE.md](ARCHITECTURE.md) — the deviation register
