# Decisions (MultiMeters)

- No adoption in this item (MM-ATS-RV of the 2026-09-26 automated-tests sweep; the candidate interview
  is out of scope, and there are no candidates).
- `tests/run.lua`'s by-name load-list assertion gains `OptionsRegistry.lua`, `OptionsCombat.lua` and
  `OptionsNav.lua`. The shells call each only when present (`if lib.__AttachX then`), so a payload
  missing one raises nothing. This addon reaches for all three: the registry for every page's
  registration, the combat lock through the tab strip, and the nav rail on the Windows page.
  `OptionsIds.lua` and `OptionsIdList.lua` are left off: this addon draws no id widget.
- The degraded stub needs no new member. Its comment on the id lookups now names `OptionsIds.lua`.
- `docs/testing.md` and `docs/common-tasks.md` list the same sixteen files as the runner.
- Plan: `Ka0sAddonsCommonTasks/docs/2026-09-26-AUTOMATED_TESTS_SWEEP/` (ATS-20, ATS-21).
