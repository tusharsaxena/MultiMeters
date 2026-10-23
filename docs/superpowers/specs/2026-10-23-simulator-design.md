# The `/mm sim` simulator — a scripted fight through the real meter

**Date:** 2026-10-23
**Issue:** [MultiMeters#60](https://github.com/tusharsaxena/MultiMeters/issues/60) (scope: its scenario list, each with a headless end-to-end suite)
**Run:** the collection run "sim auto-run, QC preview selector, mode strips, MM/KCD simulators", items MM-10 to MM-20
**Source design:** `Ka0sAddonsCommonTasks/docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/inputs/design-mm-sim.md`, with the
run's binding rulings in that bundle's `inputs/OWNER_SCOPE.md` and `03_SPEC.md`
**Builds on:** LibKa0s v1.76.0 — LibKa0s-Sim-1.0 (the seam, the session, the step panel and the auto-run on start) and
LibKa0s-Widgets-1.0's `TestStrip` in its `kind = "sim"` flavor

This is the in-repo copy of the design, adapted to what shipped. Like every file under `docs/superpowers/`, it is
frozen: the code and the living docs (`docs/ARCHITECTURE.md`, `docs/data-flow.md`, `docs/module-map.md`) win
where they differ.

---

## 1. The state before the simulator

- **The meter was already routed; the world was not.** `core/Compat.lua` held the eight guarded `C_DamageMeter`
  shims, and `modules/Provider.lua` was their only caller (`tests/test_provider.lua` scans for it). The reads a
  simulation must answer for the group and the zone went straight to `_G`: `UnitGUID`, `UnitName`, `UnitExists`
  and `UnitClass` in `modules/Roster.lua`, the group size and raid reads, `IsInGroup` and `IsInInstance` in
  `modules/Visibility.lua`, `UnitAffectingCombat("player")` in four files, and `OpenDeathRecapUI` in
  `modules/DrillDown.lua`.
- **Events had one table and no single entry.** `core/MultiMeters.lua`'s `EVENTS` array registered one method
  per event, so there was no function a simulated delivery could reuse and no place for a real-event filter.
- **Test mode substituted the source at the provider** (`modules/Aggregator_Preview.lua`'s fixed rows). It is
  a layout aid, not a run of the engine.
- **Two SavedVariables writes a session could reach:** the remembered roster (`db.global.roster`, written on
  every roster build and wiped by `Roster.Forget` on `MSG.METER_RESET`) and each window's segment pin
  (`window.data.sessionID` / `sessionType`, which the stale-pin repair `DropStaleSegment` clears when the
  client no longer holds the segment).
- **Three outward actions:** the export's `ChatSender`, `ResetAllCombatSessions` (which wipes Blizzard's own
  meter) and opening Blizzard's death recap.

## 2. The design

### 2.1 Files

| File | Job |
|---|---|
| `core/Compat.lua` | Twelve new world members (MM-10), each a guarded `_G` read at call time; the callers above switch to them |
| `core/MultiMeters.lua` | `NS:OnGameEvent`, `NS.DeliverEvent`, `NS.HANDLER_BY_EVENT` and the `NS.RealEventFilter` hook (MM-11) |
| `core/SimSetup.lua` | The LibKa0s-Sim-1.0 seam over `NS.Compat`: the pure members, the three guarded ones, the library-absent stubs (MM-12) |
| `modules/SimWorld.lua` | The invented world and one provider per wrapped member (MM-13) |
| `modules/SimDrivers.lua` | World edits plus the events the client would fire for each, in the client's order (MM-14) |
| `modules/Sim.lua` | The session host: descriptor, refusals, gate, prepare, the real-event classifier, the stop (MM-15) |
| `modules/SimScenario.lua` | The four #60 scenarios and the step player (MM-16) |

TOC: `core\SimSetup.lua` straight after `core\Compat.lua` (the seam wraps every member in place at load, host
contract H2), and the four `modules\Sim*.lua` files after `modules\Visibility.lua`.

### 2.2 One dispatch entry

Every `EVENTS` row registers the one handler `OnGameEvent`. It drops the event when `NS.RealEventFilter`
answers true, and otherwise calls `NS.DeliverEvent(event, ...)`, which looks up `NS.HANDLER_BY_EVENT` and runs
the named method, answering 0 for an unknown or client-refused event and 1 otherwise. `DeliverEvent` is the
simulator's `deliver`, so the simulated and real paths run the same function. The filter is consulted on the
real path only, and only `modules/Sim.lua` sets it, for the length of a session.

### 2.3 The seam

- **Pure, never wrapped:** the real player's spec and real spells, the recap diagnostics probes, the number
  formatters, the menu, texture and atlas helpers, `BarInterpolation`, and the real player's travel state.
- **Guarded, never reaching the client during a session:** `ResetAllCombatSessions` clears the invented
  segments and fires `DAMAGE_METER_RESET` on the session's timer; `ChatSender` prints `[sim] <chatType>: <text>`
  and counts the send; `OpenDeathRecap` prints one line and answers false, so the drill-down falls back to its
  own breakdown.
- **Everything else is wrapped and has a provider.** A wrapped member with no provider would answer live, and
  the end-to-end suite would show it as a wrong row.

### 2.4 The world

Built in `prepare` on the session bag, by seed:

- **Members.** The local player is the real player (read live inside `NS.SimSeam:Live`); the mates are invented,
  with `Player-9998-SIM%04d` GUIDs, a range no client issues, and hunters and warlocks carry pets so pet
  attribution and Merge pets run.
- **Group, zone and combat.** Unit tokens are `player` plus `party1-4`, or `raid1-N` with the player at a seeded
  index. Zones are The Rookery, Liberation of Undermine, Priory of the Sacred Flame and Isle of Dorn.
- **Segments and recaps**, newest first, with ids from 1000000 up, in the shapes `modules/Provider.lua` reads.
- **The numbers are plain and invented:** a seeded per-member, per-stat rate (a base rate times the role's
  shape times a jitter of plus or minus 20%); a tick adds rate times seconds; `amountPerSecond` is total over
  duration; Overall sums every segment since the last reset.
- **The world is closed.** `GetCombatSessionFromID` answers nil for any id it did not invent, and every
  provider builds a fresh table per call.

### 2.5 Drivers and scenarios

| Driver | Events, in order |
|---|---|
| `FormGroup`, `Disband` | `GROUP_ROSTER_UPDATE` |
| `Zone` | `PLAYER_ENTERING_WORLD(false, false)`, `ZONE_CHANGED_NEW_AREA` |
| `Pull` | `PLAYER_REGEN_DISABLED`, `DAMAGE_METER_CURRENT_SESSION_UPDATED` |
| `Tick`, `Die` | `DAMAGE_METER_CURRENT_SESSION_UPDATED` |
| `EndFight` | `PLAYER_REGEN_ENABLED`, one `DAMAGE_METER_COMBAT_SESSION_UPDATED` per stat, `DAMAGE_METER_CURRENT_SESSION_UPDATED` |
| `Reset` | through `NS.Provider.Reset()`, whose guarded shim fires `DAMAGE_METER_RESET` |

A fight plays over time: its ticks are booked on the session's timer, and the step gate stays closed ("The
fight is still running.") until they finish, so the auto-run, a typed `step` and a click-ahead all wait.

| Scenario | Label | Steps |
|---|---|---|
| `dungeon` | Dungeon: pull and boss (5) | Form a 5-player group, enter The Rookery, pull Trash, pull Speaker Shadowcrown (a damage dealer dies) |
| `raid` | Raid boss (20) | Form a 20-player raid, enter Liberation of Undermine, pull Vexie and the Geargrinders (two deaths) |
| `wipe` | Wipe and reset (5) | Form a group, enter The Rookery, the boss wipe (everyone dies), Reset meter data, re-pull Trash |
| `zone` | Zone change between segments (5) | Form a group, enter The Rookery, fight, leave to Isle of Dorn, enter Priory of the Sacred Flame, fight |

No `sizes` (the issue fixes 5 and 20) and no host verbs.

### 2.6 The host

- **Refusals, in order:** stood down; test mode on; combat; inside an instance; in a group; General visibility
  hides every window.
- **Prepare:** build the world, snapshot every window's pin, install the real-event filter, send
  `MSG.SIM_CHANGED { active = true }`, fire `DAMAGE_METER_RESET` so every cache starts from the empty simulated
  meter through the real handlers. **No window is force-shown**: each window's visibility rules answer the
  simulated world.
- **The real-event classifier**, while a session runs: real combat (`PLAYER_REGEN_DISABLED`, or a restriction
  state other than Inactive) stops it with the combat reason, then delivers; a loading screen stops it; a real
  roster or zone edge stops it when the live read says grouped or in an instance, and is consumed otherwise;
  real `DAMAGE_METER_*` events are consumed; anything else is delivered.
- **Other stops:** the stand-down (disable, or a perf capture) and a profile change.
- **The stop,** each step isolated: clear the filter; restore the pins (skipped on a profile change, whose
  snapshot belongs to the profile that is gone); wipe the shared cache; resync through `ENTERING_WORLD`,
  `METER_SESSION` and `COMBAT_CHANGED`, **never** `METER_RESET`; close an open drill-down; send
  `SIM_CHANGED { active = false }`; record the last stop for the diagnostics.
- **Session-only stores:** `modules/Roster.lua` keeps the remembered roster in a session table while a session
  runs, `DropStaleSegment` stands aside, and test mode refuses to start.
- **The step delay** is a 1 s constant, `Host.STEP_DELAY` (no settings row; see D8).
- **The slash verb** is one `NS.COMMANDS` row, `sim`, whose grammar is the library's `RunVerb`; a feature verb,
  refused while disabled. Starting from the panel or with `/mm sim start <scenario>` plays the run at once
  (LibKa0s v1.76.0's auto-run); Pause, a click on a step row, Resume, Restart and Stop stay.

### 2.7 Secrets

**The simulator never produces a secret and never simulates the `Combat` restriction.** Its values are plain,
so `Secrets.CanCompare` answers true and the engine takes the GUID join and the value sort, as it does out of
combat. `Secrets.IsRestricted()` stays live and is always false during a session, because a session cannot
coexist with real combat. The secret paths keep their proof in the headless `mock_secrets` suites. Two
invariants hold: `core/Secrets.lua` remains the only inspector of a **client** value, and
`modules/SimWorld.lua` does arithmetic only on its own invented numbers. The simulator files never spell
`Compat.<meter shim>`, because providers are registered by key string.

### 2.8 The marker

Every Multi Meters window shows the sim strip, LibKa0s-Widgets-1.0's `TestStrip` with `kind = "sim"`, in the
test strip's slot under the title (the two modes are exclusive), placed by the same narrow `ApplyTestStrip`
path on `SIM_CHANGED`. The strip's room is reserved while test mode is on or a session runs. No SIMULATION
word goes in any title. The diagnostics report gains a `sim` section and the debug console a `Sim` tag (MM-19).

## 3. Decisions

| # | Decision | Why |
|---|---|---|
| D1 | The real player is the simulated local player; the mates are invented. | The player's own row, `isLocalPlayer` and `Roster.LocalGUID` must line up as they do in game. |
| D2 | The world is closed. | Mixing real and invented segments gives grids no client can produce. |
| D3 | Pins are snapshotted and restored, the stale-pin repair stands aside, and the roster lives in a session store. | These are the only SavedVariables writes a session reaches; the end-to-end suite proves the saved tables come back byte-identical. |
| D4 | The stop resyncs without `METER_RESET`. | That message makes `Roster.Forget` wipe the real remembered roster once the seam is off. |
| D5 | Fights tick over time behind a gate. | #60 asks for providers that grow over a fight; the auto-run and click-ahead still wait correctly. |
| D6 | No restriction or secret simulation. | Section 2.7. |
| D7 | No forced show of windows. | The visibility rules answering the simulated world are part of the engine under test. |
| D8 | No `sim.stepDelay` setting; a 1 s constant. | Dropped by the run's plan review as outside the owner's scope (the source design's MM-18). |
| D9 | One `OnGameEvent` entry. | #60's prerequisite; the simulated and real paths share `DeliverEvent` by construction. |
| D10 | No host verbs, no sizes. | #60 fixes the sizes, and the picker reaches every scenario. |
| D11 | No SIMULATION title word; a minimized window shows no sim marker. | The owner's ruling for the run: the word goes wherever the strip exists, and the step panel marks the run. |

## 4. Risks and limitations

- **No secret or restriction coverage in a session.** By design (D6); the headless suites carry it.
- **Feign and the player-state hide rules stay live**, because the simulated player is the real one.
- **A window pinned to a real segment reads no session during a run** and shows its empty state, since the
  world is closed; the stop restores the pin.
- **A `/reload` mid-run leaves a simulated pin** in the profile; the next refresh's `DropStaleSegment` clears it.
- **The export's staggered sends after a stop** still use the guarded sender and only print.
- **Generated counts** (`docs/test-cases.md`, the README test badge) move with every item that adds cases.
