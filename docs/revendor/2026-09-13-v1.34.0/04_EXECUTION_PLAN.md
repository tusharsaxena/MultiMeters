# 04 — Execution plan

1. **Re-vendor**, one commit on `chore/2026-09-12-libka0s-1.33.0`, on top of `e66fa0c`. Both
   payloads were copied whole from the tag. Only `Options.lua`, `OptionsCompose.lua`, `Slash.lua`
   and three kit files changed. CR equals LF in every changed file, and the runner stays `100755`.
2. **Docs in the same commit:** the provenance line (`CLAUDE.md:52`) and the dated "the two agree"
   measurement at `docs/testing.md:490`–`:491` move to v1.34.0. This repo carries no live
   geometry-flip revision note, so there is no "revision 19 at the earliest" line to move.
3. **Gate:** `lua tests/run.lua` and `luacheck .`, with `tests/test_vendor_sync.lua` comparing both
   payloads against the tag and skipping none.
4. **Slash pin**, its own commit: a test that `window.name` set through the slash with several
   words is stored whole, red on Slash minor 9; `docs/test-cases.md` and the README badge
   regenerated. **B1 is not adopted** (02_CANDIDATES B1), so no settings-panel or smoke-test line
   about the tooltip moves.
