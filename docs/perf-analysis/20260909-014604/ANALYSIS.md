# Analysis — 20260909-014604

- **Addon:** MultiMeters 0.1.0 (record schema 2, client interface 120100)
- **Captured:** 2026-09-09 01:41 local, label `2026-09-09 01:41`
- **Who / where:** Sacrìlege-Frostmourne, level 90 Protection Paladin · Silvermoon City — The Bazaar · solo
- **Delta:** +0.50 ms/frame — **at the floor, treat as unresolved**, and it is 7× larger than the bracketed Lua can account for
- **Previous capture:** none — this is the first capture in this store

## Headline

A solo, single-window, eight-column run in Silvermoon City — The Bazaar: 68.3 s of combat with the
addon active, 74.2 s with it suspended. **What was being fought is not recorded** — the context block
carries character, class, level, realm, spec, group, zone and subzone, and nothing about a target.
The addon's **bracketed Lua cost 5.409 ms per second of combat** — 4.511 ms/s in the coalesced
window refresh and 0.899 ms/s in the meter-event fan-out — which at 75.2 fps is about
**0.072 ms/frame**. The reported frame-time delta is **+0.5003 ms/frame**,
sitting exactly on the resolution floor the instrument is trusted below; it is **not** a measurement
of the addon, and the gap between it and the 0.072 ms/frame the buckets can see is either noise or
cost outside every bracket (the client's own layout and draw of the addon's frames, which no bucket
times). Two things this run establishes that were previously only asserted: the declared bucket tree
in `core/PerfSetup.lua` **cannot describe `providerRead` at all**, because that bucket is reached
through more than one real parent in the source, and the two paths `core/PerfSetup.lua` suspects
most — `tooltip` and its declared child `targets` — **never fired at all**, so the addon's suspected
worst case is still unmeasured. Containment itself was measured nowhere in this capture: every nested
row reports its parent as declared and not observed.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 68.3320 | 5136 | 75.1624 | 13.3045 |
| suspended (addon inert) | 74.1750 | 5793 | 78.0991 | 12.8042 |
| **delta** (active − suspended) | −5.8430 | −657 | −2.9367 | **+0.5003** |

The sign is the right way round — the active arm is the slower one — so this is not the backwards
delta that signals the environment moved underneath the run. But **+0.5003 ms/frame is the floor, not
a result.** The playbook puts the resolution floor of a 60–80 s A/B at roughly ±0.3 ms/frame and calls
anything below about 0.5 ms/frame unresolved; this reading is 0.0003 ms/frame above that line, which
is a coin toss dressed as a measurement. Read it as *"the frame-time instrument could not separate
this addon from the noise"*, not as *"the addon costs half a millisecond a frame"*, and certainly not
as *"no measurable impact"* — the instrument was never sharp enough to say either.

Two further reasons to distrust the number specifically. First, **the arms are not the same length**:
arm B ran 74.175 s against arm A's 68.332 s, 8.6 % longer, so the two aggregates are averaged over
different amounts of fight. Combat gating equalizes *what* was measured, never *how much*. Second,
**the bracketed Lua cannot account for the delta**: 5.409 ms/s over 75.1624 frames per second is
0.072 ms/frame, and 0.5003 is roughly seven times that. `buckets[*].totalMs` is Lua execution time
only, so a real difference could legitimately live in the client's layout and draw of the window this
addon keeps on screen — work suspend removes along with the Lua, and work no bracket in this addon can
ever see. It could equally be drift between 01:43:41 and 01:44:42. This capture cannot tell those
apart, and it should not pretend to.

Neither arm is a capped client: 13.30 and 12.80 ms/frame are not equal to each other and neither is a
round limiter value like 8.33 or 16.67.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
68.332 s, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `meterEvent` | 15598 | 61.3982 | 0.899 | 0.0606 | none — top level, and genuinely not nested |
| `refresh` | 265 | 308.2296 | 4.511 | 3.3876 | none — top level |
| `providerRead` | 2120 | 44.8127 | 0.656 | 0.3144 | declares `refresh` — **not observed**; the source shows more than one real caller path (below) |
| `aggregate` | 265 | 101.8738 | 1.491 | 2.0205 | declares `refresh` — **not observed** |
| `render` | 265 | 198.7347 | 2.908 | 1.4024 | declares `refresh` — **not observed** |
| `renderRow` | 1325 | 137.2940 | 2.009 | 0.3934 | declares `render` — **not observed** |

**Total accounted cost: 5.409 ms per second of combat** — the two top-level buckets, `meterEvent`
plus `refresh`: 61.3982 + 308.2296 = 369.6278 ms over the active arm's 68.332 s. (The rounded ms/s
figures, 0.899 + 4.511, add to 5.410; 5.409 is the unrounded quotient.) The four nested rows are
already inside `refresh` and are not added.

### The ratios that survive a change of combat duration

These are the figures a later capture of a different length can be compared against; `totalMs` cannot.

| Ratio | Value | Where it comes from |
|---|---|---|
| refresh passes per second | 3.878 | 265 calls / 68.332 s — the profile's `throttle = 0.25` (`defaults/Profile.lua:775`) |
| ms per refresh pass | 1.163 | 308.2296 / 265 |
| meter events per second | 228.3 | 15598 / 68.332 |
| ms per meter event | 0.00394 | 61.3982 / 15598 |
| `providerRead` calls per pass | **8.000** | 2120 / 265 — one per configured column |
| ms per `providerRead` | 0.02114 | 44.8127 / 2120 |
| ms per `aggregate` pass | 0.3844 | 101.8738 / 265 |
| `renderRow` calls per pass | **5.000** | 1325 / 265 — five rows drawn |
| ms per `renderRow` | 0.1036 | 137.2940 / 1325 |
| ms per row-cell | 0.01295 | 137.2940 / (1325 × 8 columns) |

The two integer ratios pin eight columns and five rows. A third observation pins the window count:
`refresh`, `aggregate` and `render` each recorded exactly 265 calls, so one window refreshed, built
and rendered once per pass. **Eight columns, five rows, one window.** Nothing in the report states
that directly; it falls out of the call counts.

### The declared tree is unverified, and one bucket cannot be described by it at all

Every row above prints the *"declares itself within X — not observed"* form, exactly as
`docs/perf-analysis/README.md` predicts: every bracket in this addon calls `Perf.Note(key, ms)` with
two arguments and never passes `parentKey`, so `observedWithin` is never populated and the tree in
`core/PerfSetup.lua:…buckets` is an **unverified claim**. That much was known.

(A side observation while checking those call sites: the call-site table in
[`../README.md`](../README.md) had drifted — it listed `renderRow` at `modules/Row.lua:1620` against
an actual `:1633`, `aggregate` at `modules/Aggregator.lua:1694` against `:1735`, and `tooltip` at
`modules/Tooltip.lua:2393` against `:2400`, among others. The store README is the one non-frozen file
here and has been corrected in the same change as this bundle; this note records that it was wrong
when this capture was read.)

What this capture adds on that front is **nothing**, and it is worth saying why, because the
arithmetic looks tempting. `observedWithin` is empty for every row here, so no containment was
measured in either direction: the tree is unverified, and nothing in this capture promotes
*unverified* to *wrong*. Summing the nested rows against `refresh` is the one operation this file's
own bucket table and `report.md`'s client line both forbid — *buckets nest, do not sum* — and it is
forbidden for a reason. A sum whose terms may overlap cannot tell a false declaration from a double
count, from two brackets that overlap in some third way, or from a `refresh` total assembled partly
out of the three early-return exits at `modules/Window.lua:1856`, `:1866` and `:1889`, which is not a
clean container for anything. The sum is not evidence and it is not performed here.

What the **source** says — a source reading, to be settled by measurement rather than by arithmetic —
is that `providerRead` has more than one real parent, so a single-parent `within` cannot describe it
at all. `providerRead` is bracketed inside `Provider.GetColumn` (`modules/Provider.lua:329`, closed
at `:349`), and `Provider.GetColumn` has four non-test callers:

- `takeColumn` (`modules/Aggregator.lua:1027`) and `scanColumn` (`:1463`), the identity build and the
  GUID build respectively, both inside the `aggregate` bracket opened at `modules/Aggregator.lua:1704`
  and closed at `:1735`. On the refresh path the parent is `aggregate`, not `refresh`.
- `buildMap` (`modules/Targets.lua:275`), reached from `Targets.ForPlayer` at `modules/Targets.lua:384`
  and therefore inside the `targets` bracket opened at `:367` — and `targets` itself declares
  `within = "tooltip"` (`core/PerfSetup.lua:127`). On the tooltip path `providerRead` runs nowhere
  near `aggregate` or `refresh`.
- `core/Diagnostics.lua:397`, `:1388` and `:1428`, with no perf bracket open above them at all.

`core/PerfSetup.lua` declares `{ key = "providerRead", within = "refresh" }`. Swapping that for
`within = "aggregate"` would trade one incomplete claim for another. The finding to record is that
**this bucket has no single parent**, not that its declared parent is the wrong one — and once
`parentKey` is threaded (action 2), a tooltip-exercising capture should be expected to report it as
observed in more than one parent.

Note what none of this licenses: subtraction. `aggregate − providerRead = 57.06 ms` (0.215 ms/pass)
and `render − renderRow = 61.44 ms` (0.232 ms/pass) are *plausible* readings of "the GUID join and
ordering, excluding the column reads" and "the render pass excluding the row loop" — but they rest on
containment that was reasoned, not observed, and they must not be quoted as measured until
`parentKey` is threaded through. The same bar applies to expressing one bucket as a **percentage** of
another: a share is the same claim as a subtraction wearing a different sign.

`meterEvent` is the one bucket that is genuinely not nested and must not be read as though it were:
it brackets the bus fan-out at event rate (`core/MultiMeters.lua:382`, `:392`, `:399`), while
`refresh` brackets the coalesced pass on the window's own 0.25 s clock. Two different clocks, no
overlap.

### Two declared buckets never fired

`core/PerfSetup.lua` declares **eight** buckets. Six appear above. Absent from the table entirely:

- **`tooltip`** — bracketed at `modules/Tooltip.lua:2400`, `:2534`, `:2552`, `:2613`, `:2627`, `:2641`
- **`targets`** — bracketed at `modules/Targets.lua:394`, `:402`, `:416`

These two are not peers: `core/PerfSetup.lua:127` declares `{ key = "targets", within = "tooltip" }`,
so `targets` is a child of `tooltip` and only `tooltip` is a top-level absence. Both recorded zero
calls, so nothing in this capture ranks either of them by cost; they are listed here as the two paths
`core/PerfSetup.lua` suspects most, not as the two most expensive.

Zero calls means the player never hovered a cell for the whole 68 s. That is a **result about what
this run exercised**, and an unflattering one, because `core/PerfSetup.lua`'s own comment names
`targets` as *"the expensive half: `modules/Targets.lua` makes a provider call PER ENEMY to
reconstruct a list the API does not carry"*. The path this addon's author most suspects is the one
this capture says nothing about. A follow-up run must park the mouse on a cell.

### Why the two live paths cost what they do

**`refresh` — 4.511 ms/s, 83.4 % of the addon's measured cost** (4.511 / 5.409; both top-level
buckets, so this share is a real one). Driven by `throttle = 0.25` (`defaults/Profile.lua:775`),
floored by `Constants.THROTTLE_MIN = 0.05` at `core/Constants.lua:560` — inert at this profile's
0.25 — which is why 265
passes land in 68.3 s and not the 15598 the meter events would otherwise have caused. The coalescing
is doing its job: without it, refresh would run at 228 Hz instead of 3.9 Hz. Inside a pass
(`modules/Window.lua:1841`–`:1896`) the work is guarded early — hidden window, minimised window,
meter unavailable and missing aggregator all return before any of it — then one `Aggregator.Build`
and one `Render`.

**`render` — 2.908 ms/s, 0.750 ms per pass; `renderRow` — 2.009 ms/s, 0.518 ms per pass.** `render`
declares itself inside `refresh` (4.511 ms/s) and `renderRow` inside `render`, but neither containment
was observed, so none of the three may be quoted as a share of another. The row loop is
at `modules/Window.lua:1955`–`:1970`, capped by `layout.maxRows`, and each iteration acquires a row
from the pool, repoints it and calls `RowProto:Update` (`modules/Row.lua:1595`), which walks
`self.cells` calling `cell:SetValue(entry)` per column. **This is the figure that scales.** At five
rows × eight columns it is 0.0130 ms per cell. The header comment in `core/PerfSetup.lua` sizes the
worst case itself: *"a 20-player group times 7 columns is 140 cells per pass"*. 140 cells at this
run's per-cell rate is ≈1.813 ms per pass against the **0.518 ms/pass this run measured for the row
loop** (`renderRow`, 137.2940 / 265) — and at 3.9 passes per second that is roughly 7.03 ms/s **for
the row loop alone**, not for all of `render`. (`render`'s non-row remainder is 0.232 ms/pass, which
would put full render near 2.045 ms/pass, ≈7.93 ms/s — but that remainder is a subtraction across
unobserved containment, so it is an estimate and not a measurement.) **This capture is solo. It is
not a measurement of the case the addon was instrumented to worry about.**

**`aggregate` — 1.491 ms/s, 0.384 ms/pass.** One `Aggregator.Build` per pass
(`modules/Aggregator.lua:1700`). `providerRead` (0.656 ms/s) is reached from inside this bracket on
the refresh path, but that containment was not observed, so the two are not stated as a share of one
another; the difference of 0.215 ms/pass — the GUID join, the sort (`applySortMode`) and the row cap
— is a reasoned reading and not a measured one. Its `maxMs` of 2.0205 against a 0.384 ms mean is a 5×
spread that **nothing in this record explains.** It is specifically *not* a pass switching between
the GUID join and identity correlation: `pass.identityMode` is set once per pass from
`Secrets.IsRestricted()` (`modules/Aggregator.lua:518`), the Combat restriction holds for the whole
of a pull (`core/Secrets.lua:112`), and both arms were combat-gated end to end
(`RECORDING — combat started` to `ENDED`), so every pass in arm A took the same branch at
`modules/Aggregator.lua:1713`. Which branch that was is not recorded — and since `scanColumn`
(`modules/Aggregator.lua:1463`) sits in the branch combat suppresses, the 2120 column reads most
likely came through `takeColumn` (`:1027`). That the record does not carry which build ran is itself
a gap: log `identityMode` per capture, or bracket the two builds separately.

**`providerRead` — 0.656 ms/s, exactly 8 calls per pass.** `Provider.GetColumn` reads one
`C_DamageMeter` column and walks its sources through `Secrets.SafeIterate`
(`modules/Provider.lua:345`). Eight calls per pass is *not* a per-source cost — it is one call per
**configured column**, so it scales with the column count, not with group size. At 0.021 ms each this
is the cheapest of the three thirds, and it is worth recording that the comment at
`modules/Window.lua:1901`–`:1905` describes an earlier design that read every column a *second* time
per refresh for the percent denominator; that regression is gone and the numbers here are consistent
with one read per column per pass.

**`meterEvent` — 0.899 ms/s at 228 events per second.** Three handlers, all the same shape: read
`NS.Perf` at call time, `SendMessage`, note (`core/MultiMeters.lua:380`–`:402`). 0.00394 ms per event
with a 0.0606 ms maximum — the fan-out itself is cheap and flat, and the coalescing means the
expensive consequence is decoupled from it. This is the bucket that would scale with raid size and
window count, and at 0.9 ms/s solo it has headroom.

## What the capture did not hold constant

The context block is identical across both arms — same character, same spec, same zone and subzone
(Silvermoon City — The Bazaar), same `group: solo`. Load order was held by *suspend* rather than by
disabling the addon (`01:44:29 | addon SUSPENDED — inert`), and **no `/reload` appears anywhere in
the run log between the arms**, so the two arms share one session and one shared-frame ownership.
`addon RESUMED` at 01:46:02 lands after arm B ended at 01:45:56, so nothing was restored mid-arm.
Both arms are combat-gated: `RECORDING — combat started` opens each one, which is the condition that
makes them comparable at all.

What was **not** held constant:

1. **Arm duration.** 68.332 s vs 74.175 s — arm B ran 8.6 % longer. `ms/s` and per-call ratios absorb
   this; the frame-time aggregates do not.
2. **A 61-second gap between the arms.** Arm A ended 01:43:41; arm B started recording 01:44:42.
   Anything in a capital city's Bazaar — passers-by loading in, other players' spell effects,
   a zone population change — moved freely in that minute and is charged to the delta.
3. **Silvermoon City is a populated capital, not an isolated target.** This is the single worst thing
   about the capture as an environment. Other players' frames, nameplates and effects are the
   dominant variable in a city, and none of it is under the run's control. A dummy in an empty
   instance would produce a delta worth the name.
4. **The rotation is not evidenced.** Nothing in the record says both arms fought the same fight the
   same way. 5136 frames vs 5793 frames and 228 meter events per second in arm A is all we have;
   arm B's event rate is not recorded at all, because the addon was inert and could not count them.
5. **Solo.** `context.group` is `solo`, and this addon's cost scales with group size × open windows ×
   columns. A solo capture and a 20-player capture are not measurements of the same addon.
6. **What was being fought.** No artefact in this bundle records a target of any kind — `dump.json`'s
   context block is character, class, level, realm, spec, group, zone and subzone only. "Same target"
   is precisely the comparability condition an A/B turns on, and this capture cannot evidence it.

One thing worth stating rather than passing over: `interface` is **120100** while the addon's TOC
declares `## Interface: 120007`. That is not a mismatch — `interface` is the *client's* build TOC from
`GetBuildInfo`'s fourth return, not the addon's line — but it does record that this capture was taken
on a client one build ahead of the addon's declared interface.

## What moved

**First capture — nothing to diff against; every figure above is a baseline reading.** The store's
`README.md` said in as many words that it was empty and that a fabricated first row would be worse
than an absent one; this is the real first row.

For whoever runs the second capture, these are the baselines that will survive a change of duration
and are the ones to compare against — never `totalMs`:

| Baseline | 20260909-014604 |
|---|---|
| Total accounted | 5.409 ms/s |
| `refresh` | 4.511 ms/s, 1.163 ms/pass, 3.878 passes/s |
| `render` | 2.908 ms/s, 0.750 ms/pass |
| `renderRow` | 2.009 ms/s, 0.1036 ms/row, 0.01295 ms/cell |
| `aggregate` | 1.491 ms/s, 0.384 ms/pass |
| `providerRead` | 0.656 ms/s, 0.0211 ms/call, 8.000 calls/pass |
| `meterEvent` | 0.899 ms/s, 0.00394 ms/event, 228.3 events/s |
| Fixture | 1 window, 8 columns, 5 rows, solo |

A second capture is only comparable to this one if it is also solo with eight columns and one window.
Anything else is a different measurement, not a regression.

## Actions

1. **Record in `core/PerfSetup.lua` that `providerRead` has no single parent.** It declares
   `{ key = "providerRead", within = "refresh" }`, but `Provider.GetColumn` is reached from inside
   `aggregate` on the refresh path (`modules/Aggregator.lua:1027`, `:1463`), from inside `targets` on
   the tooltip path (`modules/Targets.lua:275`, and `targets` declares `within = "tooltip"`), and with
   no bracket above it from `core/Diagnostics.lua:397`, `:1388` and `:1428`. Swapping `refresh` for
   `aggregate` would replace one incomplete claim with another; the single-parent `within` shape
   cannot describe this bucket. **Saves:** nothing at runtime — it stops a reader mis-attributing
   0.656 ms/s to a slot the bucket does not exclusively occupy. **Risks:** none; it is a declaration,
   and `within` does not gate recording. Note the interaction with action 2: once `parentKey` is
   threaded, a capture that exercises the tooltip path will legitimately set `observedMixed` on this
   bucket, and the descriptor and the report wording need room for that. New here — no issue,
   deviation ID or review finding currently owns it.
2. **Thread `parentKey` through all 22 `Perf.Note` call sites so containment is observed rather than
   declared.** `Perf.Note(key, ms, parentKey)` takes it; every site in this addon passes two
   arguments. The 22, across the eight declared buckets: `core/MultiMeters.lua:384`, `:394`, `:402`
   (`meterEvent`); `modules/Window.lua:1856`, `:1866`, `:1889`, `:1896` (`refresh`) and `:1999`
   (`render`); `modules/Provider.lua:349` (`providerRead`); `modules/Aggregator.lua:1735` and
   `modules/DrillDown.lua:668`, `:700` (`aggregate`); `modules/Row.lua:1633` (`renderRow`);
   `modules/Tooltip.lua:2400`, `:2534`, `:2552`, `:2613`, `:2627`, `:2641` (`tooltip`); and
   `modules/Targets.lua:394`, `:402`, `:416` (`targets`). Two buckets have more than one producing
   site and it matters to everything above: `refresh` is assembled from Window's four exits, three of
   them early returns, so a `refresh` total is not a clean container; `aggregate` comes from
   `modules/Aggregator.lua:1735` plus `modules/DrillDown.lua:668`/`:700`. **Saves:** it makes
   `aggregate − providerRead` and `render − renderRow` quotable instead of merely plausible, and it is
   what would settle action 1. Note what the library actually does with the argument, because it is
   less than one might hope: `P.Note` records `observedWithin` on the first observation and sets
   `observedMixed` when a later one disagrees with it (`libs/LibKa0s/Perf.lua:418`–`:427`); it never
   compares the observation against the descriptor's declared `within`, and it never refuses a note.
   The declared-versus-observed comparison happens when the report is written, in `nestingSentence`
   (`libs/LibKa0s/Perf.lua:250`–`:251`), which prints *"`providerRead` declares itself within
   `refresh` but was observed inside `aggregate`"*. Reported, not refused. **Risks:** an extra
   argument on a path that runs 1325 times per 68 s is negligible, but the `renderRow` and
   `providerRead` sites are the hot ones and should be measured, not assumed. This is the
   instrumentation gap this capture exposed.
3. **Take a capture that exercises `tooltip` and `targets`.** Both declared buckets recorded zero
   calls, and `core/PerfSetup.lua`'s own comment names `targets` as the expensive half — a provider
   call per enemy. **Saves:** unknown, which is the point. **Risks:** none; it is a capture protocol
   change (hover a cell during arm A), not a code change.
4. **Take a group capture before drawing any conclusion about `renderRow`.** At 0.01295 ms/cell,
   `core/PerfSetup.lua`'s own 140-cell worst case extrapolates to ≈1.813 ms/pass for the row loop
   against the 0.518 ms/pass this run measured for that same loop (`renderRow`). **Saves:** nothing
   directly; it turns
   the addon's central scaling assumption from arithmetic into a measurement. **Risks:** none.
5. **Re-run the A/B somewhere the environment can be held.** A populated capital with a 61-second gap
   between arms and an 8.6 % duration difference cannot produce a resolvable frame-time delta. A
   dummy in a quiet instance, arms back to back, equal durations. **Saves:** it is the only way the
   0.5003 ms/frame figure ever becomes a number worth quoting. **Risks:** none.
