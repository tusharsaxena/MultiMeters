# 04 — Execution plan

1. **Re-vendor**, one commit on `chore/2026-09-12-libka0s-1.33.0`, on top of the Profiles `Show()`
   fix (`1bf536f`). Both payloads were copied whole from the tag. Only `Options.lua`, `Slash.lua`
   and three kit files changed. CR equals LF in every changed file, and the runner stays `100755`.
2. **Docs in the same commit:** the provenance line (`CLAUDE.md:52`) and the dated "the two agree"
   measurement at `docs/testing.md:490`–`:491` move from v1.32.0 to v1.33.0. References that name
   Options 16, Slash 8 or kit revision 17 as the release that introduced the bulk bracket or the
   kit's AceEvent / AceAddon are history, and they stay as written.
3. **Gate:** `lua tests/run.lua` and `luacheck .`, with `tests/test_vendor_sync.lua` comparing both
   payloads against the tag and skipping none.

No adoption commit follows, because nothing in Class B exists.
