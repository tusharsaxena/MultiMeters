# 05 Summary

- **Tag:** LibKa0s v1.93.0 to v1.105.0 (kit revision 53 to 57). The base comes from the CLAUDE.md
  provenance line and agrees with the last payload commit (`3236484`). 35 shipped files moved a minor,
  and 10 of them are new (01_DELTA.md 3c). There is no cross-major skew.
- **Span bundle:** none owed. There is no base correction (Step 0: ok).
- **Contract blockers:** none.
- **Consumer-owed fixes, in the re-vendor commit:**
  - the DebugLog stub gains `Report` and `Serialize`, and the two-table parity case ignores the private
    `__view`;
  - the Options stub gains `SideTabs`;
  - `NS.Compat` wires `RegionalNames`, `UnitCharacterName`, `CharacterKey` and `RealmKey`, with the
    simulator seam classifying them (three pure, one answered by the world);
  - the settings pin moves on the five font rows (+ Ka0s Bebas Neue, Ka0s Russo One);
  - `docs/compat-layer.md` is updated.
- **Delivered for free (class A):** the library tooltips placed beside their menu or window, the settings
  mark on the library windows, plain-text Copy and the console footer, the slider-box revert, the stronger
  Ka0s Default rows and the new hot marks, two fonts.
- **Icons:** the `LibKa0s icons:` line is kept as it was (23 names, `settings` already present). The prune
  kept 25 files (23 icons and 2 license texts) and removed every other icon and the callout sounds (no
  `LibKa0s sounds:` line). No provenance split was needed. The README credits are unchanged: Open Iconic
  and Phosphor still ship and nothing from Game-icons does. There were no dead stub mirrors
  (`__releaseChrome`: none).
- **Adopted:** nothing. **Declined:** nothing. **Owed in phase [3]:** LibKa0s#92, #88, #89, #86, #79,
  #87 and the `DefaultSkin` MUST (02_CANDIDATES.md B).
- **Gate:** `ka0s-bounded lua tests/run.lua` gave 2589 passed, 0 failed, 1 skipped (2590), also with
  `KA0S_KIT_CLIENT=retail`. This is a Retail-only addon, so there is no forever profile. `ka0s-bounded
  luacheck .` gave 0 warnings / 0 errors in 190 files. The largest shipped file is
  `modules/Window_Header.lua` at 1475 lines (cap 1500).
- **Smoke owed (owner, in client):**
  - the settings mark on the debug console, the copy window, the perf panel and the sim panel opens
    MultiMeters' settings;
  - the skin picker's gear sits in its header;
  - the segment menu's and the Export dropdown's entry tips open beside the menu;
  - junk typed into a slider box reverts on Enter and on tab-away;
  - `/mm diagnostics` lists Role, Callout, WaypointArrow and Tooltip in `LibKa0s running:`;
  - the two new fonts appear in the font pickers;
  - a re-look at test-strip placement (v1.103.0).
- **Noted, not fixed (pre-existing):** `docs/test-cases.md` and the README Tests badge say 2586, but the
  suite runs 2589 passing cases. The kit's `test_client_globals.lua` (3 cases) is missing from the
  generated inventory. This drift dates from before this re-vendor (the file was last regenerated
  2026-11-06), and this re-vendor leaves the count unchanged.
