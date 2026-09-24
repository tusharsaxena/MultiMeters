# 05 — Summary: LibKa0s span v1.14.0 -> v1.54.2 (base v1.12.0)

Plan item MM-30, 2026-09-24, branch `feat/2026-09-23-review-audit-remediation`, finding
MultiMeters-A-19. This bundle records the 33 LibKa0s tags MultiMeters vendored from the audit
horizon (2026-08-25 00:00) up to `2026-09-23-v1.55.0/` without writing a bundle for any of them.
The span's true base is v1.12.0, the provenance line before `b81f514`; `01_DELTA.md` has the
derivation, the per-tag table and the carrying commits. Nothing is re-vendored, no code changes, no
frozen bundle is edited, and no per-tag folder is back-filled. From here each re-vendor writes its
own `docs/revendor/<YYYY-MM-DD>-v<tag>/` bundle, as `2026-09-23-v1.55.0/` and `2026-09-23-v1.56.0/`
already do.

Retrospective: no candidates were formulated and no decisions were taken in this bundle. Each tag's
decisions were taken in the commit that carried it, read from that commit's subject and body and
listed below.

## Per tag

- v1.14.0: carried by sweep (`b81f514`), nothing adopted. Kit revision 12's loader cache took the
  suite from 2m10.8s to 7.3s with no host change.
- v1.16.0: carried by sweep (`c75bd29`), nothing adopted.
- v1.17.0: adopted in `4e9adde`. Pool minor 3 parks backward, so `WindowProto:HideAll` drops its own
  reversal and `core/PoolSetup.lua`'s degraded fallback moves with it.
- v1.18.0: adopted in `cc988f2`. Options minor 9's `resetProfile` descriptor field replaces the
  `afterRestoreAll` wrapper in `settings/OptionsSetup.lua`.
- v1.18.1: carried by sweep (`d41b9fa`), nothing adopted. The landing-logo fix arrives with the
  bytes.
- v1.19.0: adopted in `7ef6dcd`. The Columns page takes Widgets' ReorderList, and the deviation row
  for the local drag is retired. `43b4a3d` and `4315d22` fixed the drag against pre-tag payload;
  `7dbdf27` carried the tagged bytes.
- v1.20.0: carried (`e94fa17`), nothing adopted. The degraded Options stub gains the four new
  members as no-ops; nothing in `settings/` calls them yet.
- v1.21.0: carried by sweep (`325ed90`), nothing adopted. Tab art fix only.
- v1.22.0: carried by sweep (`50f80cc`), nothing adopted. Tab art and content panel.
- v1.23.0: carried by sweep (`ac33cbb`), nothing adopted. Content box padding.
- v1.24.0: adopted in `fe264cb`. The settings-revamp-v2 contract: ReorderList's row chrome, the
  composed Master controls tab, and the library's font, border and bar composers.
- v1.26.0: adopted in `ae2502a`. `settings/Schema.lua` unwraps the composer's media reader.
- v1.27.0: adopted in `ae5ff5e`. `tests/run.lua` declares kit 15's `test_eol` gate.
- v1.28.0: carried by sweep (`df4021f`), nothing adopted. Perf usage block fix.
- v1.29.0: carried by sweep (`047e634`), nothing adopted. `perf dump` folds into `report`.
- v1.35.0: carried by sweep (`ed3b3cc`), nothing adopted. The degraded Options stub gains six inert
  members for surface parity; no page adopts the new widgets.
- v1.36.0: carried by sweep (`445e8dd`), nothing adopted. `SelectTab` joins the stub as a no-op.
- v1.36.1: carried by sweep (`329edbe`), nothing adopted.
- v1.36.2: carried by sweep (`632300f`), nothing adopted. One test constant follows the library's
  ASCII arrow.
- v1.37.0: carried by sweep (`6f48bb6`), nothing adopted. No `testModePath`, since this addon has no
  test mode that stays on.
- v1.38.0: adopted in `c115ec0`. A bare `/mm` opens the settings panel (Slash minor 11), and the
  library-absent stub mirrors it.
- v1.39.0: carried (`dfbb40e`), adopted in `84e9ed3`. The launcher: one broker object, its own logo,
  and the global minimap table.
- v1.42.0: adopted in `ef7df34`. LibKa0s-Lifecycle's stand-down latch, with the perf run as its
  second hold.
- v1.43.0: carried by sweep (`7aff579`), nothing adopted. Kit revision 23 only.
- v1.44.0: carried by sweep (`22be736`), nothing adopted.
- v1.45.0: carried by sweep (`4976d36`), nothing adopted. `shownWhen` is unused here.
- v1.46.1: adopted in `cc168e7`. The combat lock: the options-panel tests assert the cover in place
  of the old close-the-window refusal, and the docs describe the lock.
- v1.47.0: carried by sweep (`beb53d0`), nothing adopted. This addon draws no id list.
- v1.50.0: carried by sweep (`3f6b1f4`), nothing adopted.
- v1.51.0: carried by sweep (`4e393ee`), nothing adopted.
- v1.52.0: carried by sweep (`075293f`), nothing adopted.
- v1.53.0: carried by sweep (`22dc46b`), nothing adopted.
- v1.54.2: adopted in `d2169d4`. The kit's US-English gate replaces the hand-written copy, and
  `tests/run.lua` declares it.
