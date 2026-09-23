# 03 — Decisions

Taken under the owner's delegation (CP-6), not in an interview. A decline becomes a public GitHub
issue in this repository, carrying one `state:` label and one `severity:` label. Each entry below
was written when its decision was made, and its outcome was filled in when it was known.

## C1 — `LibKa0s-Compat-1.0`: adopt

- **Rule:** CP-6 rule 1. `3b-specs/compat.md` §8.3 prescribes this adoption for MultiMeters and
  gives no permission to defer.
- **Reason:** it fixes a live `compat` breach, a feature module reading `_G.GetSpecialization`
  (`modules/Roster.lua:187`), and a legacy-rung defect that only a harness can reach
  (`core/Compat.lua:53-55`). The call surface `NS.Compat.X` / `NS.Secrets.X` stays put, so no call
  site moves.
- **Accepted behavior changes**, each prescribed by the Compat API document:
  1. The legacy `GetSpellInfo` rung is remapped: the rank is dropped, and the icon becomes the
     second return.
  2. `GetSpecializationInfo(nil)` answers `nil` instead of calling the client. There is no caller.
  3. On a load with the library absent, the four readers answer the absent value `nil` (the reader
     arm) instead of reading the client, and the three guards re-implement the one-rung body (the
     guard arm).
- **Outcome: adopted in `6ace3c2`.**
  - The two characterization cases (reader return counts, the trio's truth table on both edges of
    the Activating state) were green on the unchanged code. The suite read 1934/0/0 before the move.
  - Five cases were added: library identity, the reader arm, the guard arm checked against the
    library, the Roster routing, and the two-call surface parity on both loads. One case was
    corrected: the legacy remap, with its fixture fixed to the real shape. The `SEAMS` rows were
    added as well.
  - Gate after the commit: 1939/0/0, and lint 0/0 across 125 files.
  - The pre-adoption `core/Compat.lua`, `core/Secrets.lua` and `modules/Roster.lua` were run
    against the new tests with `git show HEAD:<file>`. Five cases went red there: the remap,
    identity, the reader arm, the Roster routing, and the existing soft-optional case through the
    new `SEAMS` rows. The guard-arm and parity cases pass on both, as they should, because the host
    bodies already gave the library's answers and carried its member set.

## C2 — `LibKa0s-Bus-1.0`: adopt

- **Rule:** CP-6 rule 1. `3b-specs/bus.md` §12 prescribes the record half and `Catalog` for
  MultiMeters, and sequences the wire rename ahead of `Catalog`.
- **Reason:** it fixes the naming-cheatsheet MUST: `<Event>` must be PascalCase, and every one of the
  fourteen wire strings fails it. It also retires the hand-written record at `core/Namespace.lua:168-253`
  in favor of the shared, tested one.
- **Accepted behavior changes:**
  1. `NS.BusStandUp` runs first in `standUp`. The spec requires this because the library defers any
     registration made while the bus is down.
  2. Events on a bus target are recorded as well as messages.
  3. The bus holds a target strongly while its record is non-empty. It used to hold targets weakly,
     but CallbackHandler and AceEvent's `embeds` held them anyway.
  4. On a load with the library absent, the untracked-target stub records nothing, so a disable
     there leaves bus registrations live. That limitation is stated in `docs/ARCHITECTURE.md`.
- **Outcome: adopted in `0aee02a`.**
  - The three characterization cases (the disable/enable round trip, a retired receiver staying
    retired, a subscription made while disabled going live on enable) were green on the unchanged
    code. The suite read 1942/0/0 before the move.
  - Six cases were added: the while-down deferral, the stand-up order, the wire-string shape, the
    catalog's strictness (and the plain table when the library is absent), the degraded untracked
    stub, and stub and record parity. The `SEAMS` rows were added as well.
  - Gate after the commit: 1948/0/0, and lint 0/0 across 125 files.
  - Seven cases went red against the pre-adoption `core/Namespace.lua`, `core/Constants.lua` and
    `core/LifecycleSetup.lua`: all six new ones, and the existing soft-optional case through the
    new `SEAMS` rows.
  - One doc gate failed on the way: `## Message bus` passed the hub's 60-line spill threshold at 61
    lines. The new paragraph was shortened, and it links to `disabled-state.md` instead of
    repeating it.

## C3 — `LibKa0s-Schema-1.0` (partial: primitives, registry, bracket): decline, not now

- **Rule:** CP-6 rule 2, because the spec itself says the repo MAY defer.
  - `3b-specs/schema.md:548`: "Minor 1 removes none of MM's walker or bracket code; MM MAY defer."
  - `LibKa0s/docs/api/Schema/version-1-docs.md:372-373`: "A partial adopter for which that trade is
    not worth two code paths MAY defer adoption until it adopts `Set`."
- **Reason:** adoption removes no host line. Every primitive becomes two code paths, the library's
  when it is present and the host's when it is not. MultiMeters also stays off `Set`, because its
  all-or-nothing `SetByPaths` batch, which announces once (`settings/Schema_Paths.lua:773-798`), is
  single-consumer write semantics that minor 1 cannot express.
- **Filed as:** [#52](https://github.com/tusharsaxena/MultiMeters/issues/52), labeled
  `state:triaged` and `severity:medium` (a deferred duplication), with the re-check trigger in its
  body. It was created with `gh issue create`.
