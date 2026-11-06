# Summary: LibKa0s v1.89.0 -> v1.90.0 (item SF1-RV-MM)

- **Tag:** v1.89.0 -> v1.90.0 (local tag, commit `4485b8f`, not yet pushed). The base comes from the `CLAUDE.md`
  provenance line (3a), which agrees with the last payload commit `2746ad0`. Kit revision 51, unchanged.
- **Per-file minors that moved:** Core 15 -> 16, Skin 16 -> 17, SkinPaint 18 -> 19, SkinPaintExtras 17 -> 18,
  Widgets 23 -> 24, WidgetsAutocomplete 7 -> 8, OptionsAppearance 6 -> 7. No new or removed file, no cross-major
  skew.
- **Span bundle / base correction:** none (3h unrecorded list empty; Step 0 `ok`).
- **Delivered free (class A):** every Widgets edge (the Export modal's dropdown, the skinned segment menu and its
  levels) is one physical pixel at any UI scale and sub-pixel position (SF1-L1); a skin copy from this addon leaves
  a `keepScope` owner's Scope alone (SF1-L2).
- **Contract blockers (3g, 3j):** none. Every moved major is consumed, and each document says a host owes nothing.
  Dead stub mirrors: none (`__releaseChrome` not found).
- **Icons:** `LibKa0s icons:` line kept unchanged, directly under the rolled provenance line (`CLAUDE.md:62-63`).
  Before the prune both content and byte diffs were empty against the whole tag. The prune
  (`lua /tmp/claude-1000/rv190-mm/tools/prune-icons.lua .`) printed `23 icon(s) declared; kept 25 file(s),
  removed 5815`, the same split as v1.89.0 (202 Open Iconic, 1433 Phosphor, 4180 Game-icons removed). No
  provenance split.
- **README credits:** unchanged. The shipped sets are still Open Iconic and Phosphor, both credited, and no
  Game-icons mark ships.
- **Refresh file:** none (a new tag for this addon, not a refresh).
- **Adopted:** nothing. **Declined:** `keepScope`, not applicable (03_DECISIONS.md); no issue filed, by the run's
  instruction.
- **Skipped / unreached:** none.
- **Gate (re-vendor commit):** `ka0s-bounded luacheck .`: 0 warnings / 0 errors in 190 files.
  `ka0s-bounded lua tests/run.lua`: 2586 passed, 0 failed, 1 skipped (the opt-out diagnostics case, which this
  addon does not take), 2587 total. Both vendor-sync cases pass. The largest addon file is
  `modules/Window_Header.lua` at 1475 lines, under the 1500-line cap. No addon function changed, so the CCN
  figure is unchanged.
- **Column-header check (the owner's SF1 ruling 5):** MultiMeters draws no divider line above or below its column
  headers. The strip is a frame with one flat fill texture (`modules/Window_Frame.lua:366-374`, transparent by
  default) and per-column fills (`modules/Window_Header.lua:594-596`); the title-bar hairline was removed in R4-SEP
  (`modules/Window_Header.lua:521-524`). No `SF1-MM-HDR` commit.
