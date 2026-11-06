# Summary: LibKa0s v1.85.0 -> v1.89.0 (item V89-MM)

- **Tag:** v1.85.0 -> v1.89.0. The base comes from the `CLAUDE.md` provenance line (3a), which agrees with the last
  payload commit `47fa201`. Kit revision 50 -> 51, in the same commit as the library (the pairing rule).
- **Per-file minors that moved:** Toast 3 -> 4, Widgets 22 -> 23, DebugLogDiagnostics 6 -> 7; new
  `LibKa0s-IconBrowser-1.0` (IconBrowserSources 1, IconBrowserWindow 1, IconBrowser 1). There is no cross-major
  skew, and no file was removed upstream.
- **Span bundle / base correction:** none (3h unrecorded list empty; Step 0 `ok`).
- **Delivered free (class A):** the diagnostics report names IconBrowser (DIAG 7). Flat Widgets menus draw what
  minor 22 drew, so the segment menu is unchanged until it is adopted. Kit 51 brings the CallbackHandler
  unregister guard. Toast 4 is shipped and unused here.
- **Contract blockers (3g, 3j):** none. Dead stub mirrors: none (`__releaseChrome` not found).
- **Icons:** `LibKa0s icons:` line kept unchanged, directly under the rolled provenance line (`CLAUDE.md:62-63`).
  The prune removed 5815 files: 202 Open Iconic, 1433 Phosphor and 4180 Game-icons. It kept 22 Open Iconic
  icons, 1 Phosphor icon and both license files. No provenance split was needed.
- **README credits:** unchanged. The shipped sets are still Open Iconic and Phosphor, both credited, and no
  Game-icons mark ships.
- **Refresh file:** none.
- **Adopted:** Widgets 23 `radio` + `selected` tick on the skinned segment menu
  (`modules/Window_Header.lua:1212`, `OpenSkinnedSegmentMenu`). The owner decided **adopt** in the run plan. It is
  implemented in the separate item **V89A-MM**, not in this re-vendor commit.
- **Declined:** none. No issue filed. IconBrowser is settled because the addon has no icon chooser (owner
  ruling). `submenu`, `opts.check` and Toast 4 do not apply.
- **Skipped / unreached:** none.
- **Gate (re-vendor commit):** `ka0s-bounded luacheck .`: 0 warnings / 0 errors in 190 files.
  `ka0s-bounded lua tests/run.lua`: 2585 passed, 0 failed, 1 skipped (the opt-out diagnostics case, which
  this addon does not take), 2586 total. Both vendor-sync cases pass. The largest addon file is
  `modules/Window_Header.lua` at 1476 lines, under the 1500-line cap.
