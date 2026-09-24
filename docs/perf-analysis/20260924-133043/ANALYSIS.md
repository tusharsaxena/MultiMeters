# Analysis — 20260924-133043

- **Addon:** MultiMeters 1.0.0 (record schema 2, client interface 120100)
- **Captured:** 2026-09-24 13:27 local, label `2026-09-24 13:27 mm20-before`
- **Who / where:** Sacrìlege-Frostmourne, level 90 Protection Paladin · Silvermoon City — Falconwing Square · solo
- **Delta:** −0.61 ms/frame (`deltaMsPerFrame` −0.6051) — **backwards** (the suspended arm is the slower one): the environment moved between the arms. Not a resolved reading of the addon, and not a speed-up
- **Previous capture:** [`20260909-014604`](../20260909-014604/ANALYSIS.md)

## Headline

This is the **BEFORE** capture for MM-20 (smoke test SM-07), label `mm20-before`, taken on branch head
`4182f4a` (the loaded build logged itself as `MultiMeters v1.0.0, schema v16`; see
[`report.md`](report.md)'s run log). MM-20 addresses review finding MultiMeters-R-07: rows stay bound
across Render passes, and `Row:Update` walks only live cells. Its acceptance gate is that the AFTER
capture's **`render` ms/call comes in lower than this capture's 0.21696 ms/call** (`render` totalMs
59.0126 / 272 calls, [`dump.json`](dump.json)). Next to that, **`renderRow` costs 0.13380 ms/row**
(36.1258 / 270). The addon's bracketed Lua came to **1.832 ms per second of combat**, about 0.0143
ms/frame at 128.1 fps, and `refresh` took 1.710 ms/s of that. The frame-time delta runs backwards and
resolves nothing. With **one drawn row per pass**, the render path this run exercised is close to its
minimum, which limits how much MM-20's change can show here.

### What was checked before reading

Each check compares a field in [`dump.json`](dump.json) with the repo at `4182f4a` or with
[`report.md`](report.md). All of them passed. Nothing below has been corrected.

| Check | Result |
|---|---|
| `dump.addon` against the repo | `MultiMeters`. **Pass** |
| `dump.version` against the TOC `## Version` | `1.0.0` = `MultiMeters.toc` `## Version: 1.0.0`. **Pass** |
| `dump.schema` against the vendored library | `2` = `lib.SCHEMA = 2` (`libs/LibKa0s/Perf.lua:54`). **Pass**. The `schema v16` in the run log's `[Init]` line is the addon's SavedVariables schema, a different number |
| `dump.interface` | `120100`, the client's build. It equals the TOC's `## Interface: 120100`, so the client and the addon are on the same build this time |
| Report figures against the dump | All 28 bucket figures (7 rows × calls / total ms / ms/s / max ms), both arms' seconds, frames, fps and ms/frame, and the delta match the dump at the report's precision. One case needed a second look: `providerRead` max prints `0.125` against the dump's `0.1255`. The dump value is itself rounded to 4 dp, and the report rounds the unrounded value, so either `0.125` or `0.126` is consistent. **Pass** |
| Both arms `frames > 0` | active 8842, suspended 7944. **Pass** |
| Arms combat-gated, B suspended, no `/reload` between | The log has `Experiment A RECORDING — combat started` at 13:28:03, `addon SUSPENDED — inert` at 13:29:20 before `experiment B armed`, and `Experiment B RECORDING — combat started` at 13:29:26. The only `[Init]` line is at 13:27:46, before `run started`. `addon RESUMED` (13:30:40) comes after `Experiment B ENDED` (13:30:33). **Pass** |
| Stamp | `timestamp` 1790236843 → `date -d @1790236843 +%Y%m%d-%H%M%S` = `20260924-133043`, local time (IST). Taken from the record, not reconstructed. The label's 13:27 is when the run *started*. The timestamp matches the 13:30:43 at which the report printed, three seconds after `run finished` |

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 69.0230 | 8842 | 128.1022 | 7.8063 |
| suspended (addon inert) | 66.8200 | 7944 | 118.8866 | 8.4114 |
| **delta** (active − suspended) | +2.2030 | +898 | +9.2156 | **−0.6051** |

**The sign is backwards.** The suspended arm, with the addon inert, ran *slower* than the active arm by
0.6051 ms/frame. Its magnitude sits above the playbook's ≈0.5 ms/frame floor. But the addon cannot
make the client faster by running, so a backwards delta says the environment moved between the arms.
It is not a measurement of the addon and must not be read as a speed-up. The resolution question is
moot anyway: the buckets account for 1.832 ms/s, or 0.0143 ms/frame at the active arm's 128.1022 fps
(126.4481 ms / 69.023 s / 128.1022). That is far below the ±0.3 ms/frame floor, so even a delta with
the right sign could not have resolved this addon's cost in this fixture.

The arms differ in length: arm A ran 69.023 s and arm B 66.820 s, so A was 2.203 s (3.3 %) longer.
Combat gating equalizes *what* was measured, never *how much*. Neither arm shows a capped client, since
7.81 and 8.41 ms/frame are unequal and neither is a round limiter value. Arm B's 8.41 ms/frame (118.9
fps) does sit near the 8.33 ms of a 120 fps cap, and the record has no field that could rule a limiter
in or out. The active arm's 128.1 fps does rule out a 120 fps cap during arm A.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
69.023 s, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `meterEvent` | 1818 | 8.0665 | 0.117 | 0.0279 | none — top level |
| `spellEvent` | 73 | 0.3239 | 0.005 | 0.0108 | none — top level |
| `refresh` | 272 | 118.0577 | 1.710 | 2.9713 | none — top level |
| `providerRead` | 2176 | 13.8186 | 0.200 | 0.1255 | declares none; **observed** inside `aggregate` |
| `aggregate` | 272 | 48.9076 | 0.709 | 0.5838 | declares `refresh`; **observed** inside `refresh` |
| `render` | 272 | 59.0126 | 0.855 | 2.5040 | declares `refresh`; **observed** inside `refresh` |
| `renderRow` | 270 | 36.1258 | 0.523 | 0.4632 | declares `render`; **observed** inside `render` |

**Total accounted cost: 1.832 ms per second of combat.** That is the three top-level buckets:
`meterEvent` + `spellEvent` + `refresh` = 8.0665 + 0.3239 + 118.0577 = 126.4481 ms over 69.023 s. The
four nested rows are already inside `refresh` and are not added.

### Declared vs observed nesting

The report's footer reads: *"providerRead observed inside aggregate, aggregate observed inside
refresh, render observed inside refresh, renderRow observed inside render — do not sum"*. Every nest
says **observed**. None is declared-but-unobserved, and none is observed inside a parent other than
the declared one. The dump agrees: each nested bucket carries an `observedWithin`, and where a
`within` is declared, it matches. `providerRead` declares no `within` (it has more than one real
parent, per `core/PerfSetup.lua`) and was observed only inside `aggregate`. That is expected, because
the tooltip path, where it would run inside `targets`, never fired.

This is the first capture in this store where containment was **measured**. In
`20260909-014604` every nest printed *declared, not observed*. With observed containment, two
remainders become quotable as measured: `render` − `renderRow` = 22.8868 ms (**0.08414 ms/pass**, the
render pass outside the row loop), and `aggregate` − `providerRead` = 35.0890 ms (**0.12900 ms/pass**,
the join/sort/cap outside the column reads).

### MM-20's gate figures

| Figure | Value | From |
|---|---|---|
| **`render` ms/call**: the MM-20 acceptance gate | **0.21696** | 59.0126 / 272 |
| **`renderRow` ms/row** | **0.13380** | 36.1258 / 270 |
| `refresh` ms/call | 0.43404 | 118.0577 / 272 |
| `renderRow` calls per `render` pass | 0.9926 | 270 / 272 |
| `renderRow` ms per `render` pass | 0.13282 | 36.1258 / 272 |
| ms per row-cell | 0.01672 | 36.1258 / (270 × 8 columns) |

**One row drawn.** The run log shows `[Aggregator] window=1 cols=8 rows=1` and
`[Render] window 1 drew 1/1 rows` throughout arm A. `renderRow` counts 270 calls against `render`'s 272,
so two passes drew no row. The log accounts for both: at the start of arm A, `drew 0/0 rows` prints at
13:28:03 and its run closes with `(x2)` at 13:28:04. A `(xN)` is the length of a run including the
line that opened it (`emitRun`, `core/DebugLogSetup.lua:158`–`:163`, is called with `slot.repeats + 1`). Those were
the passes before the provider had a source for the player (`identity rows=0`). After them,
`identity rows=1 … filled=0/7 … absent=7` holds for the rest of the arm.

**What that means for MM-20.** MM-20 keeps rows bound across Render passes and makes `Row:Update` walk
only live cells. In this fixture there is exactly one row to keep bound, and one row's cells to walk,
per pass. Row acquisition, re-pointing and the cell walk are the costs MM-20 targets, and at one row
they are about as small as they get. The render work outside the row loop (0.08414 ms/pass) is a large
share of `render` here and is not what MM-20 changes. **A lower AFTER `render` ms/call is the gate, but
the size of the drop this fixture can show is bounded by how little render work one row involves.** A
null or marginal difference here would not show that MM-20 has no effect at larger row counts.

### Which buckets fired

`core/PerfSetup.lua` declares **ten** buckets. Seven fired and are in the table above.
**Three never fired:**

- **`systemEvent`**: the `CHAT_MSG_SYSTEM` whisper-to-nobody check (MultiMeters-R-17). No system
  message reached it in 69 s.
- **`tooltip`**: no cell was hovered during arm A.
- **`targets`**: declared `within = "tooltip"`, so its absence follows from `tooltip`'s.

Zero calls says what the run exercised. It says nothing about what those paths cost.
`core/PerfSetup.lua` names `targets` as the expensive half of the tooltip, and it is still unmeasured
in this store. `spellEvent` fired 73 times (1.058/s) at 0.00444 ms each. It is a bucket the previous
capture did not declare, so this is its first reading.

## What the capture did not hold constant

The context block identifies one character, spec, zone and subzone (Silvermoon City — Falconwing
Square), `group: solo`. Load order was held by *suspend*, not by disabling the addon. No `/reload`
falls between the arms. The brief for this capture gives the target as a **Cleave Training Dummy**,
one window (#1), eight columns. The record itself carries no target field, so "same target in both
arms" comes from the operator, not from this bundle's evidence.

What was not held constant:

1. **Arm duration.** 69.023 s against 66.820 s, a 3.3 % difference. `ms/s` and per-call ratios absorb
   it; the frame-time aggregates do not.
2. **A 14-second gap between the arms.** Arm A ended at 13:29:12, the addon was suspended at 13:29:20,
   and arm B began recording at 13:29:26. Whatever moved in that window, and during arm B itself, is
   charged to the delta. The backwards sign shows that something did.
3. **A capital-city subzone.** Falconwing Square is inside Silvermoon City. Other players, their
   effects and nameplates are outside the run's control there, and that is the likeliest environment
   term in a backwards delta.
4. **Sort resolution between arms.** Throughout arm A, `[Aggregator]` reports
   `sort=value/provider`. From 13:29:13, after arm A ended, it reports `sort=value/value`. This is
   recorded as the log shows it. It happened outside both arms (arm B had the addon suspended, and no
   `[Aggregator]` lines appear between 13:29:20 and 13:30:40), so it does not touch arm A's buckets.
   The AFTER capture should show `sort=value/provider` during its arm A too.
5. **A `[Visibility] #1=show(world)` line at 13:29:20**, immediately after `[Window] 1 hidden
   (suspended)`. `modules/Visibility.lua`'s `Evaluate` logs each window's own rule answer and
   publishes nothing. `NS.ShouldShow`'s latch is what keeps a suspended window down
   (`core/LifecycleSetup.lua:102`–`:107`). No `[Render]` or `[Aggregator]` line appears during arm B,
   so the log gives no sign that the window worked while suspended. The paste cannot prove the negative
   beyond that.
6. **Solo, one window, eight columns, one row.** This addon's cost scales with group size × open
   windows × columns × rows. This capture measures that fixture and nothing else.

**The scenario the AFTER capture must repeat:** solo; Cleave Training Dummy; Silvermoon City —
Falconwing Square; one window (#1); 8 columns; 1 row drawn; the same A-then-suspended-B protocol.

## What moved

Against [`20260909-014604`](../20260909-014604/ANALYSIS.md), compared on `ms/s` and per-call ratios
only. **This is not a like-for-like comparison.** That capture ran older code (v0.1.0, against 1.0.0
here), in a different subzone (The Bazaar, against Falconwing Square), and drew **5 rows per pass**
against **1** here. It also ran at 75.2 fps against 128.1 fps here, so the machine and scene were not
the same either, and per-call Lua timings are sensitive to that too. Read every row below as
"different code in a different environment". None of it attributes a change to a specific commit.

| Figure | 20260909-014604 | 20260924-133043 | Change |
|---|---|---|---|
| Total accounted | 5.409 ms/s | 1.832 ms/s | −66.1 % |
| `refresh` | 4.511 ms/s, 1.16313 ms/pass | 1.710 ms/s, 0.43404 ms/pass | −62.7 % per pass |
| refresh passes/s | 3.878 | 3.941 | ≈ same (the 0.25 s throttle) |
| `render` | 2.908 ms/s, 0.74994 ms/pass | 0.855 ms/s, 0.21696 ms/pass | −71.1 % per pass |
| `renderRow` per row | 0.10362 ms/row | 0.13380 ms/row | **+29.1 %** |
| `renderRow` per pass | 0.51809 ms/pass (5.000 rows) | 0.13282 ms/pass (0.9926 rows) | −74.4 %, from row count |
| ms per row-cell | 0.01295 | 0.01672 | +29.1 % |
| `render` outside the row loop | 0.2319 ms/pass (unobserved containment then) | 0.08414 ms/pass (observed) | not comparable as measured |
| `aggregate` | 1.491 ms/s, 0.38443 ms/pass | 0.709 ms/s, 0.17981 ms/pass | −53.2 % per pass |
| `providerRead` | 0.656 ms/s, 0.02114 ms/call, 8.000/pass | 0.200 ms/s, 0.00635 ms/call, 8.000/pass | −70.0 % per call; calls/pass unchanged |
| `meterEvent` | 0.899 ms/s, 0.00394 ms/event, 228.3/s | 0.117 ms/s, 0.00444 ms/event, 26.34/s | 8.7× fewer events; +12.7 % per event |
| `spellEvent` | not declared | 0.005 ms/s, 0.00444 ms/call | new bucket |
| Nesting | all declared, none observed | all observed | containment now measured |
| Frame-time delta | +0.5003 (at the floor, unresolved) | −0.6051 (backwards) | neither resolves the addon |

What did **not** move: `providerRead` calls per pass (8.000, one per configured column, eight columns
in both), refresh cadence (≈3.9 passes/s), one window, solo, and `tooltip`/`targets` still never
firing.

The per-pass `render` and `refresh` drops are mostly the row count: 5 rows to 1. Per-row cost went
**up** 29.1 %, and per-cell the same. With one row the fixed per-row overhead is not spread over
anything, and the environment differs as well, so that rise is not attributed here. The `meterEvent`
rate fell from 228.3/s to 26.34/s, and the record cannot say whether that came from a different fight
or from a different event path in 1.0.0.

## Actions

1. **Take the MM-20 AFTER capture on the identical scenario and compare `render` ms/call against
   0.21696.** Solo, Cleave Training Dummy, Silvermoon City — Falconwing Square, one window (#1), 8
   columns, 1 row drawn, A then suspended B. The gate is AFTER `render` totalMs / calls < 0.21696.
   Report `renderRow` ms/row next to it (0.13380 here), plus the observed `render` − `renderRow`
   remainder (0.08414 ms/pass here), so the reader can see which side of the render pass moved. Owned by
   MM-20 / MultiMeters-R-07, smoke SM-07.
2. **Add a multi-row capture of MM-20 if the one-row result is marginal.** With one drawn row, the path
   MM-20 changes is exercised at its minimum. A fixture drawing several rows per pass (a group, or a
   session with more sources) would show the cell-walk change at a scale where it can register. New
   here. No issue owns it.
3. **Exercise `tooltip` and `targets`.** Both have zero calls again. This carries forward action 3 of
   `20260909-014604`: hover a cell during arm A.
4. **Exercise `systemEvent`.** It is declared as measurement-only for MultiMeters-R-17 and has never
   fired in this store. A capture needs a `CHAT_MSG_SYSTEM` event (the whisper-to-nobody case) inside
   arm A before R-17's question can be settled from numbers.
5. **Run the A/B somewhere quieter if a frame-time delta is ever wanted.** Two captures in Silvermoon
   City have now produced one delta at the floor and one backwards. The buckets are the addon's cost
   here, and 0.0143 ms/frame is far below what the frame-time instrument can see. This carries forward
   action 5 of `20260909-014604`.
