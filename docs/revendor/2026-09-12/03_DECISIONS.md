# 03 — Decisions

This run was non-interactive. The owner answered the interview in advance on 2026-09-12: **adopt**
means deleting a local shim only where the kit now provides the same contract and the suite stays
green (characterization first); **decline** means anything that needs a harness migration, and a
decline is returned to the owner as a proposed issue rather than filed by this run.

| Candidate | Outcome | Why |
|---|---|---|
| #29 — the local event half in `tests/wow_mock.lua` | **adopt** | Characterized first: with kit revision 16 copied and the shim still in place, the suite was 1749/0/0, and the cases that read `__events` or call `__fireEvent` (`tests/test_lifecycle.lua`, `tests/test_window_placement.lua`, `tests/test_degraded.lua`) were green. With the event lines deleted and `embedAceEvent` chained to the kit's `AceEvent:Embed`, the suite stayed 1749/0/0 and no test expectation was edited. |

**Nothing was declined, so nothing is proposed as an issue from this bundle.** Classes A and C
(`02_CANDIDATES.md`) were not offered, so they are not declines either.

Kept, and not a v1.30.0 candidate: the message half of `tests/wow_mock.lua`'s AceEvent
replacement. It exists for `UnregisterAllMessages` and string-method dispatch, which kit revision
16 does not model. That is a kit gap of its own, not something this release offered.
