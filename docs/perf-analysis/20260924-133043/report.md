# Report — 20260924-133043

The client's own output, copied out of the debug-log window after `/mm perf finish`. Nothing here is
edited, reordered or recomputed; the `HH:MM:SS | [Tag]` prefixes are the client's.

## The report

```
13:30:43 | [Perf] capture: 2026-09-24 13:27 mm20-before  (MultiMeters, schema 2, v1.0.0)
13:30:43 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
13:30:43 | [Perf] where:     Silvermoon City — Falconwing Square
13:30:43 | [Perf] group:     solo
13:30:43 | [Perf] active:       69.0s    8842 frames   128.1 fps    7.81 ms/frame
13:30:43 | [Perf] suspended:    66.8s    7944 frames   118.9 fps    8.41 ms/frame
13:30:43 | [Perf] delta:                                                   -0.61 ms/frame
13:30:43 | [Perf]
13:30:43 | [Perf] bucket            calls   total ms       ms/s    max ms
13:30:43 | [Perf] meterEvent         1818       8.07      0.117     0.028
13:30:43 | [Perf] spellEvent           73       0.32      0.005     0.011
13:30:43 | [Perf] refresh             272     118.06      1.710     2.971
13:30:43 | [Perf] providerRead       2176      13.82      0.200     0.125
13:30:43 | [Perf]   aggregate         272      48.91      0.709     0.584
13:30:43 | [Perf]   render            272      59.01      0.855     2.504
13:30:43 | [Perf]     renderRow       270      36.13      0.523     0.463
13:30:43 | [Perf] (buckets nest: providerRead observed inside aggregate, aggregate observed inside refresh, render observed inside refresh, renderRow observed inside render — do not sum)
```

## The run log

The capture's provenance. These lines are how a later reader confirms both arms were combat-gated,
that arm B really was suspended, and that no `/reload` landed between the arms. They are every line
of the paste that is neither the report above nor the dump, in the order the client printed them,
including the `[Debug]`, `[Init]`, `[Visibility]`, `[Roster]`, `[Aggregator]`, `[Render]`,
`[Window]` and `[Provider]` lines. A trailing `(xN)` is the debug log's own repeat-coalescing, not an
edit.

```
13:27:46 | [Debug] logging enabled
13:27:46 | [Init] MultiMeters v1.0.0, schema v16, profile 'SmokeTest24Sep'
13:27:49 | [Perf] run started — 2026-09-24 13:27 mm20-before
13:27:49 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
13:27:49 | [Perf] where:     Silvermoon City — Falconwing Square
13:27:49 | [Perf] group:     solo
13:27:49 | [Perf] perf run STARTED — 2026-09-24 13:27 mm20-before
13:28:01 | [Perf] experiment A armed (addon active) — waiting for combat
13:28:03 | [Visibility] #1=show(world)
13:28:03 | [Perf] Experiment A RECORDING — combat started
13:28:03 | [Roster] built members=1 pets=0 raid=no
13:28:03 | [Aggregator] identity rows=0 keys=0 collidedKeys=0 collidedRows=0 filled=0/0 collided=0 unmatched=0 absent=0
13:28:03 | [Aggregator] window=1 cols=8 rows=0 dropped=0 unfolded=0 sort=value/provider reason=ok
13:28:03 | [Render] window 1 drew 0/0 rows
13:28:04 | [Aggregator] identity rows=0 keys=0 collidedKeys=0 collidedRows=0 filled=0/0 collided=0 unmatched=0 absent=0 (x2)
13:28:04 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7
13:28:04 | [Aggregator] window=1 cols=8 rows=0 dropped=0 unfolded=0 sort=value/provider reason=ok (x2)
13:28:04 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok
13:28:04 | [Render] window 1 drew 0/0 rows (x2)
13:28:04 | [Render] window 1 drew 1/1 rows
13:28:14 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
13:28:14 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
13:28:14 | [Render] window 1 drew 1/1 rows (x41)
13:28:24 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
13:28:24 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
13:28:24 | [Render] window 1 drew 1/1 rows (x41)
13:28:34 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
13:28:34 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
13:28:34 | [Render] window 1 drew 1/1 rows (x41)
13:28:45 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
13:28:45 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
13:28:45 | [Render] window 1 drew 1/1 rows (x41)
13:28:55 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
13:28:55 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
13:28:55 | [Render] window 1 drew 1/1 rows (x41)
13:29:05 | [Aggregator] identity rows=1 keys=1 collidedKeys=0 collidedRows=0 filled=0/7 collided=0 unmatched=0 absent=7 (x41)
13:29:05 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x41)
13:29:05 | [Render] window 1 drew 1/1 rows (x41)
13:29:12 | [Visibility] #1=show(world)
13:29:12 | [Perf] Experiment A ENDED — 69.0s, 8842 frames, 128.1 fps
13:29:13 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/provider reason=ok (x30)
13:29:13 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/value reason=ok
13:29:20 | [Perf] addon SUSPENDED — inert
13:29:20 | [Window] 1 hidden (suspended)
13:29:20 | [Provider] suspended
13:29:20 | [Visibility] #1=show(world)
13:29:20 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
13:29:26 | [Perf] Experiment B RECORDING — combat started
13:30:33 | [Perf] Experiment B ENDED — 66.8s, 7944 frames, 118.9 fps
13:30:40 | [Perf] run finished — A 69.0s / 8842 frames, B 66.8s / 7944 frames
13:30:40 | [Provider] resumed
13:30:40 | [Visibility] #1=show(world)
13:30:40 | [Perf] addon RESUMED — events and frames restored
13:30:40 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
13:30:40 | [Aggregator] window=1 cols=8 rows=1 dropped=0 unfolded=0 sort=value/value reason=ok (x2)
13:30:40 | [Render] window 1 drew 1/1 rows (x32)
```

## The dump

The one JSON line is committed beside this file as [`dump.json`](dump.json), byte for byte as the
client emitted it. It is not reproduced here, so that there is exactly one copy to cite.
