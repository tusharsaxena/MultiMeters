# Report — 20260909-014604

The client's own output, copied out of the debug-log window after `/mm perf finish`. Nothing here is
edited, reordered or recomputed; the `HH:MM:SS | [Perf]` prefixes are the client's.

## The report

```
01:46:03 | [Perf] capture: 2026-09-09 01:41  (MultiMeters, schema 2, v0.1.0)
01:46:03 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:46:03 | [Perf] where:     Silvermoon City — The Bazaar
01:46:03 | [Perf] group:     solo
01:46:03 | [Perf] active:       68.3s    5136 frames    75.2 fps   13.30 ms/frame
01:46:03 | [Perf] suspended:    74.2s    5793 frames    78.1 fps   12.80 ms/frame
01:46:03 | [Perf] delta:                                                   +0.50 ms/frame
01:46:03 | [Perf] 
01:46:03 | [Perf] bucket            calls   total ms       ms/s    max ms
01:46:03 | [Perf] meterEvent        15598      61.40      0.899     0.061
01:46:03 | [Perf] refresh             265     308.23      4.511     3.388
01:46:03 | [Perf]   providerRead     2120      44.81      0.656     0.314
01:46:03 | [Perf]   aggregate         265     101.87      1.491     2.021
01:46:03 | [Perf]   render            265     198.73      2.908     1.402
01:46:03 | [Perf]     renderRow      1325     137.29      2.009     0.393
01:46:03 | [Perf] (buckets nest: providerRead declares itself within refresh — not observed, aggregate declares itself within refresh — not observed, render declares itself within refresh — not observed, renderRow declares itself within render — not observed — do not sum)
```

## The run log

The capture's provenance. These lines are how a later reader confirms both arms were combat-gated,
that arm B really was suspended, and that no `/reload` landed between the arms.

```
01:15:12 | [Perf] run started — 2026-09-09 01:15
01:15:12 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:15:12 | [Perf] where:     Silvermoon City — The Bazaar
01:15:12 | [Perf] group:     solo
01:15:12 | [Perf] perf run STARTED — 2026-09-09 01:15
01:15:38 | [Perf] run CANCELED — measurements discarded, nothing saved
01:41:53 | [Perf] run started — 2026-09-09 01:41
01:41:53 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:41:53 | [Perf] where:     Silvermoon City — The Bazaar
01:41:53 | [Perf] group:     solo
01:41:53 | [Perf] perf run STARTED — 2026-09-09 01:41
01:42:20 | [Perf] experiment A armed (addon active) — waiting for combat
01:42:32 | [Perf] Experiment A RECORDING — combat started
01:43:41 | [Perf] Experiment A ENDED — 68.3s, 5136 frames, 75.2 fps
01:44:29 | [Perf] addon SUSPENDED — inert
01:44:29 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
01:44:42 | [Perf] Experiment B RECORDING — combat started
01:45:56 | [Perf] Experiment B ENDED — 74.2s, 5793 frames, 78.1 fps
01:46:02 | [Perf] run finished — A 68.3s / 5136 frames, B 74.2s / 5793 frames
01:46:02 | [Perf] addon RESUMED — events and frames restored
01:46:02 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
```

The first `run started` at 01:15:12 was **canceled** 26 s later with nothing saved; it contributed no
measurement and is kept only because it is part of the paste. The recorded capture is the 01:41 run.

## The dump

The one JSON line is committed beside this file as [`dump.json`](dump.json), byte for byte as the
client emitted it. It is not reproduced here, so that there is exactly one copy to cite.
