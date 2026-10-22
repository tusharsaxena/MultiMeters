# 06 — Refresh (MultiMeters, MM-RV2)

An addendum to this frozen bundle; files 01 to 05 are unchanged. The local annotated tag v1.75.0
moved after MM-RV vendored it at commit `265a89e`: first to `6bf5f3e` (LK-26: Sim minor 2,
SimTimeline minor 2), then to its final position, commit `9e5c4e2` (LK-27: SimPanel minor 2; tag
object `d0ad7d8`). This refresh re-copies both payloads from that final position.

- **Old commit:** `265a89e`. **New commit:** `9e5c4e2`.
- **Copy:** `git -C ../LibKa0s archive v1.75.0 LibKa0s testkit`, copied whole over
  `libs/LibKa0s/` and `tests/_kit/`, then the tag's `tools/prune-icons.lua` run against the
  unchanged `LibKa0s icons:` line in CLAUDE.md (17 icons declared, 18 files kept, 5,822 removed,
  the same result as MM-RV). No "Only in" files outside the pruned icons.
- **Files that changed:** `libs/LibKa0s/Sim.lua`, `libs/LibKa0s/SimTimeline.lua` and
  `libs/LibKa0s/SimPanel.lua`, and nothing else. `tests/_kit/` is byte-identical (kit revision 41).
- **New minors:** Sim 1 -> 2, SimTimeline 1 -> 2, SimPanel 1 -> 2. Every other minor is as in
  05_SUMMARY.md.
- **Provenance line:** stays `v1.75.0`; no edit. MultiMeters is not a Sim host (Sim-1.0 declined,
  MultiMeters#60 stays open), and no addon test or doc pins a Sim, SimTimeline or SimPanel minor
  or the Sim docs key, so nothing else moved.
- **Gate**, every run through `ka0s-bounded`: `lua tests/run.lua` 2210 passed, 0 failed,
  1 skipped (2211 total), `test_vendor_sync` green against the moved tag; `luacheck .`
  0 warnings / 0 errors in 146 files; no authored `.lua` file over 1500 lines (largest 1480).
