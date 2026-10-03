# 05 — Summary (MultiMeters)

LibKa0s v1.67.0 -> v1.68.0 from the local annotated tag (`cc9f5eb`); base v1.67.0 from the CLAUDE.md
provenance line, agreeing with the last payload commit `eba033e`. Kit revision stays 35. Provenance
rolled in the same commit as the bytes, with `docs/settings-panel.md`'s vendor stamp. Minors:
WidgetsDragHandle 3 -> 4 (Widgets key 12.1.3 -> 12.1.4); every other file unchanged. No file added or
deleted, no cross-major skew, no span bundle (3h empty), no base correction (Step 0 all `ok`).

- Delivered free (class A): nothing that reaches this host; the drag handle is not drawn here.
- Contract blockers (3g): none. The 12.1.3 -> 12.1.4 document diff adds `Since 4` rows only, and
  states a host without the hook is unchanged (`version-12.1.4-docs.md:46-48`).
- Adopted: nothing.
- Declined: `tooltipPlace` / `place`, not applicable (no drag strip). No issue filed: not a real gap.
- Unreached: none.
- Gate after the copy, every Lua run through `ka0s-bounded`: `lua tests/run.lua` 2187 passed, 0 failed,
  1 skipped, 2188 total, including `tests/test_vendor_sync.lua`'s three cases (libs/LibKa0s and
  tests/_kit match the v1.68.0 tag; runner 100755). `luacheck .` 0 warnings / 0 errors in 146 files
  (`.luacheckrc` excludes `libs/` and `tests/_kit/`; no host file changed). Sighted complexity
  (`tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`): pass, 0 warnings, max CCN 15,
  4895 functions. Case count unchanged by this commit, so `docs/test-cases.md` (total 2188) and the
  README badge are untouched.
