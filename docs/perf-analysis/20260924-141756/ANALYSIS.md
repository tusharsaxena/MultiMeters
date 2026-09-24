# Analysis — 20260924-141756

- **Addon:** MultiMeters 1.0.0 (record schema 2, client interface 120100)
- **Captured:** 2026-09-24 14:15 local, label `2026-09-24 14:15`
- **Who / where:** Sacrìlege-Frostmourne, level 90 Protection Paladin · Silvermoon City — Falconwing Square · solo
- **Delta:** −0.03 ms/frame (`deltaMsPerFrame` −0.0267) — **unresolved**, far below the floor
- **Previous capture:** [`20260924-133043`](../20260924-133043/ANALYSIS.md)

## Headline

This is the **AFTER** capture for MM-20 (smoke test SM-07, MM.12), taken on the `mm20-candidate`
build whose tip is `f6904ee` ("MM-20: Keep rows bound across renders; Update walks only live
cells"). MM-20's acceptance gate is that `render` ms/call comes in lower than the BEFORE capture's
0.21696. Here **`render` costs 0.16682 ms/call** (`render` totalMs 48.3770 / 290 calls,
[`dump.json`](dump.json)), **23.1 % lower, so the gate passes**. The whole saving sits in the render
pass *outside* the row loop, which fell from 0.08414 to 0.02713 ms/pass (−67.8 %), while
`renderRow` stayed flat at 0.13969 ms/row against 0.13380. That is the cost MM-20 aimed at: no
per-pass pool release and re-acquire, and no re-anchor of a row whose slot did not change. The addon's
bracketed Lua came to **1.626 ms per second of combat**, about 0.0137 ms/frame at 118.5 fps. The
frame-time delta resolves nothing. Two things the record cannot show are stated below: the run was
started without its `mm20-after` label, and the log cannot prove which build was loaded.

### What was checked before reading

Each check compares a field in [`dump.json`](dump.json) with the repo at `f6904ee` or with
[`report.md`](report.md). Nothing below has been corrected.

| Check | Result |
|---|---|
| `dump.addon` against the repo | `MultiMeters`. **Pass** |
| `dump.version` against the TOC `## Version` | `1.0.0` = `MultiMeters.toc` `## Version: 1.0.0`. **Pass** |
| `dump.schema` against the vendored library | `2` = `lib.SCHEMA = 2` (`libs/LibKa0s/Perf.lua:54`). **Pass**. The `schema v16` in the run log's `[Init]` line is the addon's SavedVariables schema, a different number |
| `dump.interface` | `120100`, the client's build. It equals the TOC's `## Interface: 120100` |
| Report figures against the dump | All 28 bucket figures (7 rows × calls / total ms / ms/s / max ms), both arms' seconds, frames, fps and ms/frame, and the delta match the dump at the report's precision. One case needed a second look: `renderRow` max prints `0.264` against the dump's `0.2645`. The dump value is itself rounded to 4 dp, and the report rounds the unrounded value, so either `0.264` or `0.265` is consistent. **Pass** |
| Both arms `frames > 0` | active 8763, suspended 7962. **Pass** |
| Arms combat-gated, B suspended, no `/reload` between | The log has `Experiment A RECORDING — combat started` at 14:15:14, `addon SUSPENDED — inert` at 14:16:42 before `experiment B armed`, and `Experiment B RECORDING — combat started` at 14:16:44. The only `[Init]` line is at 14:15:08, before `run started`. `addon RESUMED` (14:17:54) comes after `Experiment B ENDED` (14:17:51). **Pass** |
| Label | `2026-09-24 14:15`, the harness's default: the run was started without the `mm20-after` label. **Reported, not corrected.** Identification as the MM-20 AFTER capture comes from the owner's hand-off, not from the record |
| Which build was loaded | **Not verifiable from the log.** The `[Init]` line reads `MultiMeters v1.0.0, schema v16`, exactly as in the BEFORE capture, because MM-20 changes neither the version nor the SavedVariables schema. See caveat 2 below |
| Stamp | `timestamp` 1790239676 → `date -d @1790239676 +%Y%m%d-%H%M%S` = `20260924-141756`, local time (IST). Taken from the record, not reconstructed. The label's 14:15 is when the run *started*. The timestamp matches the 14:17:56 at which the report printed, two seconds after `run finished` |

### Caveats

1. **No label.** The run was started without `mm20-after`, so `dump.label` is `2026-09-24 14:15`.
   That this is the AFTER capture is the owner's statement in the hand-off, not something the record
   carries.
2. **The build is not provable from the log.** Both captures report `v1.0.0` / `schema v16`, since
   MM-20 changes neither. The owner fully restarted the client on `mm20-candidate` before the run (the
   `[Init]` at 14:15:08 is consistent with a fresh load and proves nothing more). The shift of cost
   out of `render` − `renderRow`, and nowhere else, is consistent with MM-20's change. It is
   corroboration, not proof.
3. **One drawn row.** With one row per pass, the gain measured here is the per-pass overhead. With
   more rows, the slot-binding saving should scale with rows, but this capture does not measure that.
4. **`providerRead` and `aggregate` max spiked** to 1.8151 and 1.9682 ms, against 0.1255 and 0.5838
   before, while their per-call means stayed close (0.00700 vs 0.00635 ms/call, 0.18215 vs 0.17981
   ms/pass). MM-20 does not touch either path. This looks like a single outlier pass, and nothing in
   this data attributes it.
5. **A burst of nine `[Visibility] #1=show(world)` lines at 14:16:36–:40** falls between the arms:
   after `Experiment A ENDED` (14:16:28) and before `experiment B armed` (14:16:42). It touches
   neither arm.

### The owner's checks outside the record

These are the owner's observations as given in the hand-off. The record carries neither, and nothing
in this bundle can confirm them.

- **MM-20 visual check (SM-07):** no flicker, blink or misordering was seen in the window during the
  fight.
- **MM-21 `/reload` check (MM.13, partial):** the owner's screenshots before and after a `/reload` show
  the same row (the player, at 130.6K) and the same three segments, so the remembered roster survived
  the reload.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 73.9190 | 8763 | 118.5487 | 8.4354 |
| suspended (addon inert) | 67.3750 | 7962 | 118.1744 | 8.4621 |
| **delta** (active − suspended) | +6.5440 | +801 | +0.3743 | **−0.0267** |

**Unresolved.** −0.0267 ms/frame is a tenth of the ±0.3 ms/frame floor, so the frame-time instrument
did not see the addon, and that is a fact about resolution, not a finding of zero cost. The sign is
nominally backwards (the suspended arm slower), but at this size it means nothing either way. Unlike
the BEFORE capture, whose arms ran 128.1 and 118.9 fps, the arms here are near-identical, 118.5 and
118.2 fps. The buckets account for 1.626 ms/s, or 0.0137 ms/frame at the active arm's 118.5487 fps
(120.2146 ms / 73.919 s / 118.5487), so even a delta with the floor removed could not have resolved
this addon's cost in this fixture.

The arms differ in length: arm A ran 73.919 s and arm B 67.375 s, so A was 6.544 s (9.7 %) longer.
Combat gating equalizes *what* was measured, never *how much*. Both arms sit at 8.44–8.46 ms/frame,
within about 0.13 ms of the 8.33 ms of a 120 fps cap, and two arms at the same frame time is the
record's only hint of a limiter. The record has no field that could rule a cap in or out. In the
BEFORE capture the active arm's 128.1 fps ruled a 120 fps cap out; nothing here does. A capped client
would flatten the delta, which is one more reason to read the buckets instead.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
73.919 s, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `meterEvent` | 1926 | 8.3220 | 0.113 | 0.0229 | none — top level |
| `spellEvent` | 81 | 0.3171 | 0.004 | 0.0066 | none — top level |
| `refresh` | 290 | 111.5755 | 1.509 | 2.1557 | none — top level |
| `providerRead` | 2320 | 16.2338 | 0.220 | 1.8151 | declares none; **observed** inside `aggregate` |
| `aggregate` | 290 | 52.8222 | 0.715 | 1.9682 | declares `refresh`; **observed** inside `refresh` |
| `render` | 290 | 48.3770 | 0.654 | 0.3097 | declares `refresh`; **observed** inside `refresh` |
| `renderRow` | 290 | 40.5103 | 0.548 | 0.2645 | declares `render`; **observed** inside `render` |

**Total accounted cost: 1.626 ms per second of combat.** That is the three top-level buckets:
`meterEvent` + `spellEvent` + `refresh` = 8.3220 + 0.3171 + 111.5755 = 120.2146 ms over 73.919 s. The
four nested rows are already inside `refresh` and are not added.

### Declared vs observed nesting

The report's footer reads: *"providerRead observed inside aggregate, aggregate observed inside
refresh, render observed inside refresh, renderRow observed inside render — do not sum"*. Every nest
says **observed**, as in the BEFORE capture. None is declared-but-unobserved, and none is observed
inside a parent other than the declared one. `providerRead` was observed only inside `aggregate`,
because the tooltip path, where it would run inside `targets`, never fired. Because containment is
measured, the two remainders are quotable: `render` − `renderRow` = 7.8667 ms (**0.02713 ms/pass**),
and `aggregate` − `providerRead` = 36.5884 ms (**0.12617 ms/pass**).

### MM-20's gate figures

| Figure | AFTER (this capture) | BEFORE (`20260924-133043`) | Change |
|---|---|---|---|
| **`render` ms/call**: the MM-20 acceptance gate | **0.16682** (48.3770 / 290) | 0.21696 (59.0126 / 272) | **−23.1 %. Gate passes** |
| `renderRow` ms/row | 0.13969 (40.5103 / 290) | 0.13380 (36.1258 / 270) | +4.4 %, flat |
| `render` outside the row loop, ms/pass | **0.02713** ((48.3770 − 40.5103) / 290) | 0.08414 ((59.0126 − 36.1258) / 272) | **−67.8 %** |
| `renderRow` ms per `render` pass | 0.13969 (40.5103 / 290) | 0.13282 (36.1258 / 272) | +5.2 % |
| `renderRow` calls per `render` pass | 1.0000 (290 / 290) | 0.9926 (270 / 272) | the BEFORE run had 2 zero-row passes |
| `render` max ms | 0.3097 | 2.5040 | −87.6 % |
| `refresh` ms/call | 0.38474 (111.5755 / 290) | 0.43404 (118.0577 / 272) | −11.4 % |
| ms per row-cell | 0.01746 (40.5103 / (290 × 8)) | 0.01672 | +4.4 % |

**Where the saving came from.** Per pass, `render` is the row loop plus everything around it. AFTER,
0.13969 + 0.02713 = 0.16682. BEFORE, 0.13282 + 0.08414 = 0.21696. The pass got 0.05014 ms cheaper
because the part outside the row loop lost 0.05701 ms, partly offset by the row loop costing 0.00687
ms more per pass. Part of that offset is the row count itself: here every one of the 290 passes drew
a row, while two of the BEFORE capture's 272 passes drew none. Outside the row loop is where MM-20's
Window change lands: `Render` no longer opens with `HideAll`, reuses the rows already bound to their
slots instead of releasing and re-acquiring them from the pool, and `PlaceRow` re-anchors a row only
when its layout version or slot changed (commit message of `f6904ee`). The row loop is
`RowProto:Update` (`modules/Row.lua:1336`, bracketed at `:1377`), and MM-20's other half, walking only
live cells, lands there. With 8 columns and all of them shown, the live walk covers essentially the
cells the old walk did, so no gain was expected inside it. The +4.4 % per row is within the run-to-run
noise these per-call means carry between two sessions, and it is not attributed here. `render`'s max
fell from 2.5040 to 0.3097 ms: the BEFORE run's worst pass was a render spike, and nothing like it
recurred.

**One row drawn, and no zero-row passes.** The run log shows `[Aggregator] window=1 cols=8 rows=1` and
`[Render] window 1 drew 1/1 rows` from the first pass of arm A (14:15:15) onward, with
`identity rows=1 … filled=0/7 … absent=7` throughout. Unlike the BEFORE capture there is no
`[Roster] built` line and no `identity rows=0` pass, so `renderRow` counts 290 calls against
`render`'s 290 rather than 270 against 272.

### Which buckets fired

`core/PerfSetup.lua` declares **ten** buckets. Seven fired and are in the table above.
**Three never fired**, the same three as last time:

- **`systemEvent`**: no `CHAT_MSG_SYSTEM` message reached the whisper-to-nobody check
  (MultiMeters-R-17) in 73.9 s.
- **`tooltip`**: no cell was hovered during arm A.
- **`targets`**: declared `within = "tooltip"`, so its absence follows from `tooltip`'s.

Zero calls says what the run exercised, and nothing about what those paths cost.

## What the capture did not hold constant

The context block names the same character, spec, zone and subzone as the BEFORE capture (Silvermoon
City — Falconwing Square), `group: solo`. Load order was held by *suspend*, not by disabling the
addon, and no `/reload` falls between the arms. The owner's hand-off gives the target as the same
**Cleave Training Dummy**, one window (#1), eight columns; the log confirms `window=1 cols=8 rows=1`
throughout arm A. The record itself carries no target field, so "same target" comes from the owner,
not from this bundle. The scenario the BEFORE capture asked the AFTER capture to repeat was held:
solo, Cleave Training Dummy, Falconwing Square, window #1, 8 columns, 1 row, A then suspended B.

What was not held constant:

1. **Arm duration.** 73.919 s against 67.375 s, a 9.7 % difference, against 69.023 / 66.820 s in the
   BEFORE capture. `ms/s` and per-call ratios absorb it; the frame-time aggregates do not.
2. **A 16-second gap between the arms.** Arm A ended at 14:16:28, the addon was suspended at 14:16:42,
   and arm B began recording at 14:16:44. The nine `[Visibility] #1=show(world)` lines at 14:16:36–:40
   fall inside that gap (caveat 5).
3. **A capital-city subzone.** Other players, their effects and nameplates are outside the run's
   control in Falconwing Square. The frame rate was not the same as in the BEFORE session: the active
   arm ran 118.5 fps here against 128.1 there, so per-call Lua timings were taken in a somewhat
   different scene.
4. **Sort resolution between arms.** Throughout arm A, `[Aggregator]` reports `sort=value/provider`,
   as the BEFORE capture asked for. The `(x10)` run of that line printed at 14:16:28 closes arm A's
   passes. The one `sort=value/value` line, also at 14:16:28, prints after `Experiment A ENDED`, the
   same flip the BEFORE capture recorded after its arm A. No `[Aggregator]` or `[Render]` line appears
   between 14:16:42 and 14:17:54, so the log gives no sign that the window worked while suspended.
5. **A `[Visibility] #1=show(world)` line at 14:16:42**, right after `[Window] 1 hidden (suspended)`.
   It is the same pattern the BEFORE capture recorded: `Evaluate` logs the window's own rule answer and
   the suspend latch keeps the window down.
6. **Solo, one window, eight columns, one row.** This addon's cost scales with group size × open
   windows × columns × rows, and this capture measures this fixture and nothing else (caveat 3).

## What moved

Against [`20260924-133043`](../20260924-133043/ANALYSIS.md), compared on `ms/s` and per-call ratios
only. This is the closest pair in the store: the same addon version, the same fixture and the same
subzone, with MM-20 as the intended difference (caveat 2 says what the log cannot prove). The two
sessions still ran at different frame rates (active arm 118.5 against 128.1 fps), so small per-call
differences are not attributed.

| Figure | 20260924-133043 (BEFORE) | 20260924-141756 (AFTER) | Change |
|---|---|---|---|
| Total accounted | 1.832 ms/s | 1.626 ms/s | −11.2 % |
| `refresh` | 1.710 ms/s, 0.43404 ms/pass | 1.509 ms/s, 0.38474 ms/pass | −11.4 % per pass |
| refresh passes/s | 3.941 | 3.923 | ≈ same (the 0.25 s throttle) |
| `render` | 0.855 ms/s, 0.21696 ms/pass | 0.654 ms/s, 0.16682 ms/pass | **−23.1 % per pass** |
| `render` outside the row loop | 0.08414 ms/pass | 0.02713 ms/pass | **−67.8 %** |
| `renderRow` per row | 0.523 ms/s, 0.13380 ms/row | 0.548 ms/s, 0.13969 ms/row | +4.4 %, flat |
| `aggregate` | 0.709 ms/s, 0.17981 ms/pass | 0.715 ms/s, 0.18215 ms/pass | +1.3 % per pass |
| `aggregate` outside `providerRead` | 0.12900 ms/pass | 0.12617 ms/pass | −2.2 % |
| `providerRead` | 0.200 ms/s, 0.00635 ms/call, 8.000/pass | 0.220 ms/s, 0.00700 ms/call, 8.000/pass | +10.2 % per call; calls/pass unchanged |
| `meterEvent` | 0.117 ms/s, 0.00444 ms/event, 26.34/s | 0.113 ms/s, 0.00432 ms/event, 26.06/s | −2.6 % per event |
| `spellEvent` | 0.005 ms/s, 0.00444 ms/call | 0.004 ms/s, 0.00391 ms/call | −11.8 % per call, on 81 calls |
| Max ms: `render` / `refresh` | 2.5040 / 2.9713 | 0.3097 / 2.1557 | render spike gone |
| Max ms: `providerRead` / `aggregate` | 0.1255 / 0.5838 | 1.8151 / 1.9682 | one outlier pass (caveat 4) |
| Nesting | all observed | all observed | unchanged |
| Frame-time delta | −0.6051 (backwards) | −0.0267 (unresolved) | neither resolves the addon |

What did **not** move: `providerRead` calls per pass (8.000, one per configured column), the refresh
cadence (≈3.9 passes/s), the event rate (≈26/s), one window, solo, and `systemEvent`, `tooltip` and
`targets` still never firing.

The `refresh` drop per pass (−0.04930 ms) is almost all `render`'s (−0.05014 ms). `aggregate` moved
+0.00234 ms/pass, and the rest of `refresh` barely moved. The `providerRead` per-call rise (+10.2 %)
is small in absolute terms (0.00065 ms/call) and MM-20 does not touch that path; it is not attributed.

## Actions

1. **Take a multi-row capture of MM-20.** The one-row gate passed, but at one row the per-row half of
   MM-20 (slot binding saving work per bound row, and the live-cell walk) is exercised at its minimum.
   A fixture drawing several rows per pass (a group, or a session with more sources) would show
   whether the saving scales with rows as expected. Carries forward action 2 of `20260924-133043`. No
   issue owns it.
2. **Start every capture with its label** (`/mm perf start <label>`). This run's record carries only
   the harness default, so its identity rests on the hand-off (caveat 1). Process note for the next
   capture. New here; no issue owns it.
3. **Watch the `providerRead` and `aggregate` max in the next capture.** A single 1.8 to 2.0 ms pass
   against sub-0.6 ms maxima before is not attributable from one run (caveat 4). If it recurs, it
   needs a bracket or a log line that can say which pass it was. New here; no issue owns it.
4. **Exercise `tooltip` and `targets`.** Both have zero calls again. Hover a cell during arm A.
   Carries forward action 3 of `20260924-133043`.
5. **Exercise `systemEvent`.** It has never fired in this store, and MultiMeters-R-17's question
   cannot be settled from numbers until it does. Carries forward action 4 of `20260924-133043`.
6. **If a frame-time delta is ever wanted, run somewhere quieter and check the frame limiter.** Three
   captures in Silvermoon City have now produced a delta at the floor, one backwards and one
   unresolved, and this run's two arms both sat near a 120 fps cap. Carries forward action 5 of
   `20260924-133043`.
