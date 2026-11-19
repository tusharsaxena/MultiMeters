# 04 Execution plan

One commit, AF-RV-MM: both payloads copied whole from the v1.107.0 extract, the provenance line rolled
(CLAUDE.md:62), the icon declaration kept (CLAUDE.md:63), the prune run with the tag's `tools/prune-icons.lua`,
this bundle and the v1.106.0 span bundle, and the standard reference refreshed to v2.115.0 (the vendored quirks
block in `docs/midnight-quirks.md`). No adoption, so no characterization test; the gate is the existing suite,
including `tests/test_vendor_sync.lua`.
