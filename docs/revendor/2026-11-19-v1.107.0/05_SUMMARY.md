# 05 Summary: LibKa0s v1.106.0 -> v1.107.0

- Tag moved v1.106.0 -> v1.107.0; base from the provenance line (CLAUDE.md:62), confirmed by `cf9b792`.
- Minors moved: WidgetsDragHandle 14 -> 15, WidgetsDragHandleTip 1 -> 2. Kit revision 57, unchanged.
- Span bundle written: `../2026-11-19-v1.106.0-v1.106.0/` (one tag, v1.106.0). No base correction.
- Delivered for free (class A): the drag strip's new mark order, tints and tooltip placement. No visible effect
  here, because this addon draws no drag strip.
- Contract blockers: none.
- `LibKa0s icons:` line kept unchanged (it already declares `settings`). The prune refused nothing and removed
  only undeclared icons and the callout sounds. No provenance split, README credits unchanged, no dead stub
  mirrors (`__releaseChrome` appears nowhere outside `libs/`).
- Adopted: nothing. Declined: nothing. Unreached: nothing.
- Gate (Retail only; this addon ships Retail alone): `lua tests/run.lua` 2642 passed, 0 failed, 1 skipped
  (the kit's diagnostics opt-out case, which this addon does not opt into), 2643 total;
  `ka0s-bounded luacheck .` 0 warnings / 0 errors in 194 files.
