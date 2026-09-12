# 04 — Execution plan

One adopted candidate. It rides in the re-vendor commit, as the library's adoption note asks
("delete the shims in the re-vendor commit").

## #29 — the event half comes from the kit

- **Files:** `tests/wow_mock.lua` only. `libs/` and `tests/_kit/` are not touched beyond the
  copy.
- **Characterization, before the change:** the existing cases already pin the observable
  contract, so none was written. `tests/test_lifecycle.lua:182-190` asserts every production
  event is recorded against its handler-name string with no extras; `:265-266` asserts an
  unregistered optional event is absent and a registered one maps to `"OnPlayerStateChanged"`;
  `tests/test_window_placement.lua:397-398` does the same for the vehicle pair; and the
  `__fireEvent` callers in `tests/test_lifecycle.lua` and `tests/test_degraded.lua` drive a
  recorded string through `host[handler]`. Run with kit 16 and the shim in place: 1749/0/0.
- **The change:** capture the kit's `libs["AceEvent-3.0"]` before the local replacement, call its
  `Embed` first inside `embedAceEvent`, and delete the local `__events` / `RegisterEvent` /
  `UnregisterEvent` / `UnregisterAllEvents`. The local message functions are assigned after the
  kit's `Embed` and so overwrite only the message half.
- **What proves it:** the same cases, unedited, green: the recorded value is still the handler
  string, `__events` is still the field, and `__fireEvent` still resolves it. Plus `luacheck`
  0/0 with `tests/wow_mock.lua` inside the checked set (it is: `Checking tests/wow_mock.lua OK`).
- **Commit boundary:** the re-vendor commit, beside the payloads and the provenance line.
