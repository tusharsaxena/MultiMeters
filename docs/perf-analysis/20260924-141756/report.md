# Report — 20260924-141756

The client's own output, copied out of the debug-log window after `/mm perf finish`. Nothing here is
edited, reordered or recomputed; the `HH:MM:SS | [Tag]` prefixes are the client's.

## The report

```
14:17:56 | [Perf] capture: 2026-09-24 14:15  (MultiMeters, schema 2, v1.0.0)
14:17:56 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
14:17:56 | [Perf] where:     Silvermoon City — Falconwing Square
14:17:56 | [Perf] group:     solo
14:17:56 | [Perf] active:       73.9s    8763 frames   118.5 fps    8.44 ms/frame
14:17:56 | [Perf] suspended:    67.4s    7962 frames   118.2 fps    8.46 ms/frame
14:17:56 | [Perf] delta:                                                   -0.03 ms/frame
14:17:56 | [Perf] 
14:17:56 | [Perf] bucket            calls   total ms       ms/s    max ms
14:17:56 | [Perf] meterEvent         1926       8.32      0.113     0.023
14:17:56 | [Perf] spellEvent           81       0.32      0.004     0.007
14:17:56 | [Perf] refresh             290     111.58      1.509     2.156
14:17:56 | [Perf] providerRead       2320      16.23      0.220     1.815
14:17:56 | [Perf]   aggregate         290      52.82      0.715     1.968
14:17:56 | [Perf]   render            290      48.38      0.654     0.310
14:17:56 | [Perf]     renderRow       290      40.51      0.548     0.264
14:17:56 | [Perf] (buckets nest: providerRead observed inside aggregate, aggregate observed inside refresh, render observed inside refresh, renderRow observed inside render — do not sum)
```

## The run log

The capture's provenance. These lines are how a later reader confirms both arms were combat-gated,
that arm B really was suspended, and that no `/reload` landed between the arms. They are every line
of the paste that is neither the report above nor the dump, in the order the client printed them,
including the `[Debug]`, `[Init]`, `[Visibility]`, `[Aggregator]`, `[Render]`, `[Window]` and
`[Provider]` lines. A trailing `(xN)` is the debug log's own repeat-coalescing, not an edit.

```
14:15:08 | [Debug] logging disabled
14:15:08 | [Debug] logging enabled
14:15:08 | [Init] MultiMeters v1.0.0, schema v16, profile 'SmokeTest24Sep'
14:15:11 | [Perf] run started — 2026-09-24 14:15
14:15:11 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
14:15:11 | [Perf] where:     Silvermoon City — Falconwing Square
14:15:11 | [Perf] group:     solo
14:15:11 | [Perf] perf run STARTED — 2026-09-24 14:15
14:15:12 | [Perf] experiment A armed (addon active) — waiting for combat
14:15:14 | [Visibility] #1=show(world)
14:15:14 | [Perf] Experiment A RECORDING — combat started
14:15:15 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7
14:15:15 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok
14:15:15 | [Render] window 1 drew 1/1 rows
14:15:25 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
14:15:25 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
14:15:25 | [Render] window 1 drew 1/1 rows (x41)
14:15:35 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
14:15:35 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
14:15:35 | [Render] window 1 drew 1/1 rows (x41)
14:15:45 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
14:15:45 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
14:15:45 | [Render] window 1 drew 1/1 rows (x41)
14:15:55 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
14:15:55 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
14:15:55 | [Render] window 1 drew 1/1 rows (x41)
14:16:05 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
14:16:05 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
14:16:05 | [Render] window 1 drew 1/1 rows (x41)
14:16:16 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
14:16:16 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
14:16:16 | [Render] window 1 drew 1/1 rows (x41)
14:16:26 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
14:16:26 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
14:16:26 | [Render] window 1 drew 1/1 rows (x41)
14:16:28 | [Visibility] #1=show(world)
14:16:28 | [Perf] Experiment A ENDED — 73.9s, 8763 frames, 118.5 fps
14:16:28 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x10)
14:16:28 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/value reason=ok
14:16:36 | [Visibility] #1=show(world)
14:16:36 | [Visibility] #1=show(world)
14:16:36 | [Visibility] #1=show(world)
14:16:36 | [Visibility] #1=show(world)
14:16:37 | [Visibility] #1=show(world)
14:16:39 | [Visibility] #1=show(world)
14:16:39 | [Visibility] #1=show(world)
14:16:39 | [Visibility] #1=show(world)
14:16:40 | [Visibility] #1=show(world)
14:16:42 | [Perf] addon SUSPENDED — inert
14:16:42 | [Window] 1 hidden (suspended)
14:16:42 | [Provider] suspended
14:16:42 | [Visibility] #1=show(world)
14:16:42 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
14:16:44 | [Perf] Experiment B RECORDING — combat started
14:17:51 | [Perf] Experiment B ENDED — 67.4s, 7962 frames, 118.2 fps
14:17:54 | [Perf] run finished — A 73.9s / 8763 frames, B 67.4s / 7962 frames
14:17:54 | [Provider] resumed
14:17:54 | [Visibility] #1=show(world)
14:17:54 | [Perf] addon RESUMED — events and frames restored
14:17:54 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
14:17:54 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/value reason=ok (x2)
14:17:54 | [Render] window 1 drew 1/1 rows (x12)
```

## The dump

The one JSON line is committed beside this file as [`dump.json`](dump.json), byte for byte as the
client emitted it. It is not reproduced here, so that there is exactly one copy to cite.
