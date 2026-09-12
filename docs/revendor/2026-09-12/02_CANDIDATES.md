# 02 — Candidates

## What v1.30.0 carries

No file in `LibKa0s/` moved (see `01_DELTA.md` §3c). The release is **kit revision 16**, four
changes to `testkit/`, each closing a gap between the kit's Ace fakes and real Ace3. Sources:
`git -C ../LibKa0s show v1.30.0:CHANGELOG.md`, block `## v1.30.0 — 2026-09-12`, and
`LibKa0s/docs/api/testkit/version-16-docs.md` at the tag. The library side has no `Since`
markers to read, because no library major's minor moved.

| # | Kit change | Where in the tag |
|---|---|---|
| [#27](https://github.com/tusharsaxena/LibKa0s/issues/27) | `AceGUI:Release` + `widget:Release()`, in the real order, raising on `Release(nil)` and on a double release, recording `w.__released` / `AceGUI.__released` | `testkit/mock_base.lua`, the AceGUI factory |
| [#28](https://github.com/tusharsaxena/LibKa0s/issues/28) | `VendorSync.register` adds `the automated-test runner is recorded executable (100755)` | `testkit/vendor_sync.lua` |
| [#29](https://github.com/tusharsaxena/LibKa0s/issues/29) | AceEvent's event half on every `Embed` target, the same three functions the `NewAddon` target carries, validated as CallbackHandler validates, one registry per mock build | `testkit/mock_base.lua:179-244`, used at `:561` and `:596` |
| [#30](https://github.com/tusharsaxena/LibKa0s/issues/30) | `NewAddon` stamps AceConsole's `Printf` beside `Print` | `testkit/mock_base.lua`, `NewAddon` |

## Classification for this addon

### A — delivered on the copy alone (not offered)

- **#28, the runner-mode case.** `tests/test_vendor_sync.lua` is a three-line delegate to
  `VendorSync.register(T, { root = ROOT })`, so the case arrives with the kit. It passes:
  `git ls-files -s tests/_kit/run-automated-tests.sh` already reports `100755`. This is the
  whole of the count's move, **1748 → 1749**, exactly the figure the library's adoption note
  measured for this addon.
- **#27, `AceGUI:Release`.** This addon carries no local `Release` shim, and neither its source nor
  its suites call `AceGUI:Release`, `widget:Release` or read `__released`. The only `:Release`
  calls in `tests/` are `RowProto:Release` (`modules/Row.lua`), the addon's own pooled row. The
  fidelity is there for the first page that re-renders through AceGUI; nothing to delete today.
- **#30, `Printf`.** This addon neither publishes nor calls `NS.Printf`
  (`core/MultiMeters.lua` reclaims `NS.Print` only, and `core/CoreSetup.lua` publishes Print and
  Format). A kit-stamped `Printf` sits unused on `NS`, as the AceConsole mixin does in the
  client. `tests/test_degraded.lua`'s parity list does not include it, so nothing moves.

### B — host change required (offered)

- **#29 — delete the local event half in `tests/wow_mock.lua`.** `embedAceEvent` (then
  `tests/wow_mock.lua:1220-1249`) stamped its own `RegisterEvent` / `UnregisterEvent` /
  `UnregisterAllEvents` at `:1240-1247`, recording `handler or event`, and replaced
  `__events` with a fresh table on `UnregisterAllEvents`. The kit now provides the same contract
  on every Embed target, recording `handler or true`, clearing in place and validating the method.
  - *Files it would touch:* `tests/wow_mock.lua` only.
  - *Blast radius:* **replaces** harness code the addon owns, with no production change. The
    wholesale `libs["AceEvent-3.0"]` replacement stays, because the kit's message half still lacks
    `UnregisterAllMessages` (`modules/Provider.lua`'s Suspend, `modules/Window.lua`'s
    UnregisterBus) and string-method dispatch. So the event lines cannot simply be dropped: with
    the whole library replaced, a module target would lose `RegisterEvent` altogether. The local
    `embedAceEvent` has to **chain to the kit's `Embed`** for the event half and keep its own
    message half on top.
  - *Where the two shapes differ:* only on a registration with no handler. Every production
    registration passes a method name (`core/MultiMeters.lua:133-197`), and every named method
    exists on `NS`, so the kit's validation passes and the recorded value (the string) is what the
    shim recorded.
  - *Recommendation:* **adopt**, conditional on the suite staying green without editing a test
    expectation. `tests/test_lifecycle.lua:182-190` and `:265-266` and
    `tests/test_window_placement.lua:397-398` read `__events` directly; `addon:__fireEvent`
    (`tests/wow_mock.lua`) resolves a recorded string through `host[handler]`.

### C — whole-module adoption

None offered. `LibKa0s-Item-1.0` is still in the payload with no lookup, as it was at the last
re-vendor, and its minor did not move in this release, so no premise changed.
