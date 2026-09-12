# 02 — Candidates: what v1.31.0 carries for MultiMeters

## Sources

```
git -C ../LibKa0s log --oneline v1.30.0..v1.31.0
git -C ../LibKa0s show v1.31.0:CHANGELOG.md                                   # block "## v1.31.0 — 2026-09-12"
git -C ../LibKa0s show v1.31.0:docs/api/testkit/version-17-docs.md
git -C ../LibKa0s show v1.31.0:docs/api/Perf/version-11.5-docs.md
git -C ../LibKa0s show v1.31.0:docs/api/Options/version-15.15.4.3-docs.md
```

Commits in range: `3162e53` (Options 15.15.4.3, the record-backed bind arm), `f355fdc` (kit 17), `bab743c`
(Perf minor 11), `1f1790c` (the review fixes to kit 17 and the Options arm), and three release-record
commits (`2b312db`, `30db4ed`, `e7e1962`).

## Class A: reached the addon on the copy alone

- **Perf minor 11, `P.Save` traces its retention prune.** `version-11.5-docs.md`, "`Perf.lua` minor 11"
  and the `Save(record)` member row: one line through `P.Log` when the ring trims. This addon's
  descriptor `log` (`core/PerfSetup.lua:194`) routes every perf line to the console ungated, so the
  line arrives with no host change. Pinned by a test, `PerfSetup: a save past the ring's cap says what
  it dropped, in the console` (commit `8546df9`), which passes on arrival.
- **OptionsWidgets minor 15, a path-less row reads and writes through its own `get` / `set`.**
  CHANGELOG, "`OptionsWidgets.lua` minor 15": the gate is `path == nil`, so a path-keyed row is
  untouched. Every row in `settings/Schema.lua` carries a path. Nothing moves.
- **Kit 17's real AceTimer, AceConsole and object model on the named `NewAddon` path.**
  `version-17-docs.md`, "For consumers: nothing moves": this addon's harness reaches the named path,
  and `core/MultiMeters.lua:29` lists `AceEvent-3.0`, `AceTimer-3.0` and `AceConsole-3.0`, so `NS`
  keeps every mixin it had and gains a timer whose cancel is honored. The suite total did not move
  (1779 / 0 / 0 before and after the copy).
- **The review's kit changes**: `handle.cancelled` (AceTimer's own field), the repeating timer's period
  held when the clock does not move, and the no-name `NewAddon` path narrowed to a lone table. No test
  here reads a timer handle's cancel field or `repeating`/`looping`, and `NewAddon` is always called
  with a name. There was nothing to port.
  Checked with `grep -rnE '\.canceled\b|\.cancelled\b|\.looping\b|\.repeating\b' tests/*.lua
  tests/perf.lua`: no hit. Looser patterns find only prose, a drag handle and secret-value handles.

## Class B: host change required

### B1. Kit 17's AceEvent message half retires the harness's own

- **What.** `M.__msgRegistry`, CallbackHandler's string-method dispatch, `UnregisterAllMessages`, and
  mid-dispatch registration queued to the end of the dispatch.
- **Evidence.** `version-17-docs.md`, "AceEvent: two CallbackHandler registries". The local copy was
  `tests/wow_mock.lua:1189-1256` at `48fa075`: `busRegistry`, `resolveCallback`, `embedAceEvent`, and a
  wholesale `libs["AceEvent-3.0"]` replacement. The v1.30.0 bundle kept it because kit 16 had no
  `UnregisterAllMessages` (`docs/revendor/2026-09-12/03_DECISIONS.md`, the closing note).
- **Touches.** `tests/wow_mock.lua`; the seven suites that read `mocks.__busRegistry`.
- **Blast radius.** Replaces code the harness owns. Every bus subscription in the suite runs on it.
- **Recommendation.** Adopt, since the premise that kept it (a missing `UnregisterAllMessages`) is gone.

### B2. Kit 17's AceAddon module layer and lifecycle retire the harness's own

- **What.** `NewModule` / `GetModule` / `IterateModules` / `modules` / `orderedModules`,
  `AceAddon:EnableAddon`, and `M.__fireEvent(event, ...)`.
- **Evidence.** `version-17-docs.md`, "AceAddon: modules" and "AceAddon: the lifecycle, driven the way
  the client drives it". It names this addon: "A harness that wants only the enable cascade — KickCD's
  and MultiMeters' `__enableAll` — calls `AceAddon:EnableAddon(addon)`". The local copy was
  `tests/wow_mock.lua:1325-1395` at `48fa075`, a `NewAddon` wrapper stamping `NewModule`, `GetModule`,
  `IterateModules`, `__enableAll` and `__fireEvent`.
- **Touches.** `tests/wow_mock.lua`, `tests/run.lua`, `tests/perf.lua`, `tests/test_lifecycle.lua`,
  `tests/test_degraded.lua`.
- **Blast radius.** Replaces code the harness owns. One behavior differs: the kit enables the addon's
  `OnEnable` before its modules', as the client does, where the local layer ran the modules first.
- **Recommendation.** Adopt. Take it in the same commit as B1, since both lived in one `NewAddon`
  wrapper.

### B3. OptionsCompose minor 4, `spec.bind`: the record-backed composer arm

- **What.** A composer can emit rows bound to a registry record's `get` / `set` instead of paths.
- **Evidence.** CHANGELOG, "`OptionsCompose.lua` minor 4 — `spec.bind`, the record-backed arm";
  `version-15.15.4.3-docs.md`.
- **Touches.** Nothing. Every composed block here (`settings/Schema_Compose.lua:476`) is path-keyed.
  The per-window blocks are window-relative paths that the seam resolves against a window id
  (issue #49), not records bound by closures.
- **Blast radius.** None, since there is no call site.
- **Recommendation.** Decline as not applicable. It was built for PanelMaster's panel editor
  (PanelMaster#48).

## Class C: whole-module adoption

None new. The consumption map (`01_DELTA.md` §3e) is v1.30.0's: every major but **Item** has a lookup.
Item did not move this release and is not re-offered.
