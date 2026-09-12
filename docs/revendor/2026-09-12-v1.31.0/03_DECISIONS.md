# 03 — Decisions

**A non-interactive run.** The orchestrator's brief for this wave stood in for the interview: adopt
any kit-17 surface that retires a local layer, characterize first, and only where the suite stays
green. Filing and pushing were skipped by instruction, so a decline below is recorded here and **not
filed** as an issue.

| Candidate | Decision | Record |
|---|---|---|
| B1: kit 17's AceEvent message half | **adopt** | Commit `58023d8`, together with B2. The local `busRegistry` / `embedAceEvent` / `libs["AceEvent-3.0"]` replacement is deleted, and seven suites read `mocks.__msgRegistry`. |
| B2: kit 17's AceAddon module layer and lifecycle | **adopt** | Commit `58023d8`. The `NewAddon` wrapper (`NewModule`, `GetModule`, `IterateModules`, `__enableAll`, `__fireEvent`) is deleted. `tests/run.lua` and `tests/perf.lua` enable through `AceAddon:EnableAddon(NS)`; the suites read `mocks.__fireEvent`, `NS.modules` and `NS.orderedModules`. |
| B3: OptionsCompose `spec.bind` | **never (not applicable)** | No record-backed page exists here: every composed block is path-keyed. **Unfiled**: filing skipped by instruction. A later run should file it as `state:will-not-do`, `severity:low`, citing v1.31.0. |

**Kept local, and why.** The AceDB-3.0 wrapper in `tests/wow_mock.lua`, which dispatches
CallbackHandler's string-method form to `OnProfileChanged` / `OnProfileReset` / `OnProfileCopied`.
Kit 17 did not change the AceDB fake, and the base still calls whatever it is handed. Also kept: the
frame model, the secret simulator, `C_AddOns`, and the LibSharedMedia / LibDataBroker / LibDBIcon /
AceConfig fakes, none of which the kit models.
