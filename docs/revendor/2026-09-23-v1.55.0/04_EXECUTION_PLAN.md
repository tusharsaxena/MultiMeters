# 04 — Execution plan

Each adopted candidate gets its own commit, in this order:

1. Write the characterization cases and run them green against the **unchanged** code.
2. Change the code.
3. Add the new cases: the degraded load and the parity gates.
4. Run `ka0s-bounded luacheck .` and `ka0s-bounded lua tests/run.lua` and confirm both are green.
5. Commit.

A candidate that goes red and cannot be made green without changing pinned behavior is rolled back to
its commit boundary. `libs/` and `tests/_kit/` are not touched.

The assertion standard is "behaves the same". The cases pin outputs, return arity and call order.
They do not settle for "still runs".

## Commit 1 — C1 `LibKa0s-Compat-1.0`

**Characterization first** (in `tests/test_compat.lua`, green on the pre-adoption code):

- **Return arity of each wired reader on the modern rung.**
  - `GetSpellInfo` gives exactly 6 values.
  - `GetSpellTexture`, `GetSpecialization` and a `GetSpellInfo` miss each give exactly 1.
  - `GetSpecializationInfo(1)` passes the 5 mock values through.
- **The secret trio's truth table** over a plain number, a simulated secret, `nil`, a string and
  `true`, with `canaccessvalue` accessible and then inaccessible. It is compared as one rendered
  string, so a single cell that moves is named.
- **The roster role path** with `C_SpecializationInfo` present and the deprecated global stubbed to
  answer nil. The player's role still comes from the spec. This case is red under a Roster that
  reads only `_G.GetSpecialization`, so it pins the routing.

**Code:**

- `core/Compat.lua`:
  - Resolve `CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)`.
  - Point the four readers at it, each falling back to a reader arm that answers `nil`.
  - Keep the header and the spec-icon comment, since they document caller facts rather than the
    ladder.
- `core/Secrets.lua`: wire `IsSecret`, `CanAccess` and `IsSafeKey` from `CompatLib`. The current
  bodies stay as the guard arm, with the comment the API document asks for. `CanCompare`,
  `CanCompare2`, the table members and `SafeIterate` are unchanged and still call `Secrets.CanAccess`
  at call time.
- `modules/Roster.lua:187`: `NS.Compat.GetSpecialization`. `GetSpecializationRole` stays inline,
  because it is a single-consumer member (spec OPEN-6).
- `tests/run.lua`: add `["LibKa0s-Compat-1.0"] = shared.mocks.LibStub("LibKa0s-Compat-1.0", true)` to
  the surface-source map.

**New cases:**

- The legacy rung is remapped. The fixture is corrected to the real shape
  `name, rank, icon, castTime, minRange, maxRange, spellID`, and the icon is asserted at position 2.
- On a full load, each wired member is the library's function (identity, not just a matching
  answer).
- The degraded load (`T.load{ libFiles = {} }`):
  - The four readers answer the absent table with arity 1.
  - The three guards answer exactly what the live library answers under the same `issecretvalue`
    fixture.
- Parity, in two calls:
  - `NS.Compat`, ignoring the trio and the unwired `GetSpellName` / `GetSpellCooldown`.
  - `NS.Secrets`, ignoring the six readers.
  - Both run on the degraded and the live load.
- `tests/test_degraded.lua` `SEAMS` gains `LibKa0s-Compat-1.0` → `core/Compat.lua`, which checks the
  premise and the soft-optional lookup.

**Docs:**

- `docs/compat-layer.md`: the Spell and Specialization rows point at the library, and a new
  guard-arm note is added.
- `docs/ARCHITECTURE.md`:
  - Module map row, compat-layer row and the line count claim.
  - The `core/Compat.lua:<n>` citation in *Hard-coded texture paths*, re-measured.

## Commit 2 — C2 `LibKa0s-Bus-1.0`

**Characterization first** (green on the pre-adoption code):

- **The record round trip on the shared lifecycle.** A probe target subscribes. Disable (`/mm set
  enabled false`) takes its registration out of `mocks.__registrations()`, and enable puts it back.
  This pins that a stand-down/stand-up still works end to end.
- **A retired target (`UnregisterAllMessages`) is not resurrected by a stand-up.** This is the
  `WindowProto:UnregisterBus` contract.
- **The stand-up order.** The latch's `standUp` runs the bus before `NS:OnEnable`, so a module that
  registers during `OnEnable` is live straight away.
  - This case is written against the target order. It is red on the pre-adoption code until the
    reorder lands, which is the one intended move.
  - The existing stand-down order case (`tests/test_disabled.lua` "standDown fires in order") stays
    as it is.

**Code:**

- `core/Namespace.lua:168-253` becomes:
  - The `LibStub("LibKa0s-Bus-1.0", true)` resolution, or the untracked-target stub from
    options-ui-§1 / the Bus API document's worked example.
  - `NS.busRecord = Bus:New{ name = addonName, isDown = function() ... NS.IsStoodDown() end }`.
  - The three delegates. `NS.BusStandUp` logs `rejected` through `NS.Debug`.
  - `NS.BusLib`, published so the parity gate can reach the stub.
- `core/LifecycleSetup.lua`: `NS.BusStandUp()` moves to the first line of `standUp`.
- `core/Constants.lua`: the fourteen wire strings become PascalCase, keeping every key.
  `Constants.MSG = BusLib and BusLib.Catalog(addonName, MSG) or MSG`.
  `TEST_MODE_CHANGED` keeps the wire suffix `PreviewChanged`.

**New cases:**

- Every wire string passes the cheatsheet shape: prefix, then a PascalCase suffix that contains a
  lowercase letter.
- `NS.Constants.MSG` is strict: reading an undeclared key raises and names the key. On a degraded
  load it is the plain table.
- The bus stub has parity with `"LibKa0s-Bus-1.0"`, and its instance has two-table parity with the
  live `NS.busRecord`.
- The degraded load hands out untracked targets that still receive messages, and `BusStandDown`
  there answers 0.
- `tests/test_degraded.lua` `SEAMS` gains `LibKa0s-Bus-1.0` → `core/Namespace.lua`.

**Docs:** `docs/ARCHITECTURE.md`

- *Message bus*: name the major, the catalog's strictness and the wire spelling.
- *Known limitations*: the degraded install's untracked targets.
- The documentation-map `message-bus.md` row, if its wording names the record.

`docs/common-tasks.md` changes its example wire string to PascalCase.

## Commit 3 — the bundle

`05_SUMMARY.md`, and the outcomes filled into `03_DECISIONS.md`. `docs/test-cases.md` is regenerated
with `ka0s-bounded lua tests/run.lua --list`, and the README Tests badge is brought to the new
total, as `docs/testing.md` requires.
