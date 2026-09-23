# 02 — Candidates: LibKa0s v1.55.0

Worked out from three sources, in the playbook's order, and never from memory:

1. `git -C ../LibKa0s log --oneline v1.54.2..v1.55.0`, and the `CHANGELOG.md` block `## v1.55.0 — 2026-09-23`.
2. The `Since` markers in `LibKa0s/docs/api/<Major>/version-1-docs.md` for the three new majors.
   No existing major moved a minor (01_DELTA 3c), so there is no older document to diff.
3. The per-consumer adoption deltas that name this repo with `file:line`:
   `Ka0sAddonsCommonTasks/docs/2026-09-22-SUITE_STANDARDS_AND_LIBKA0S_SWEEP/3b-specs/compat.md` §8.3
   (and §4's gate amendment), `.../bus.md` §12 *MultiMeters* (and §12's common block), and
   `.../schema.md` §11 *MultiMeters* (and §11's common block, §14 V-3).

The owner delegated the interview (CP-6). Each decision below is taken by the delegation's rules and
recorded, with its reason, in `03_DECISIONS.md`.

## Class A: delivered by the re-vendor, not offered

- **Test kit revision 25.** Phase 5 wired it in `a5a1014`. That covers the layout-§1 cap census
  (`tests/_kit/test_layout_cap.lua`), the `.gitattributes` body case in `test_eol`, suite declaration
  by `(basename, directory)`, and the commit SHA in the automated-test record.
- **No consumed major moved.** Core, Lifecycle, Launcher, DebugLog, Env, Pool, Perf, Media, Widgets,
  Slash and Options are all byte-identical to v1.54.2 (01_DELTA 3c and 3g). Nothing changed in them,
  so nothing arrived for free through them.

## Class B: host change on a consumed major

**None.** The v1.55.0 CHANGELOG block says "No existing `.lua` file in the library changes". Every
new surface in this release sits under one of the three new majors, so every candidate is class C.

## Class C: whole-module adoption

Checked for a recorded refusal first. `gh issue list --state all` has no issue that names Compat,
Bus, Schema, wire names or the secret seam. The only LibKa0s decline on record is #20 (Item, a
different major). `grep -rn 'LibKa0s' docs --include='*.md' | grep -iE 'declin|not adopt|exempt'`
finds no refusal of any of the three. None of the three is settled, so each is offered.

### C1 — `LibKa0s-Compat-1.0`: the spell and spec readers, and the secret trio

- **What:** `NS.Compat.GetSpellInfo`, `GetSpellTexture`, `GetSpecialization` and
  `GetSpecializationInfo` delegate to the library. `NS.Secrets.IsSecret`, `CanAccess` and `IsSafeKey`
  are wired from it too, and their current bodies become the guard arm. `modules/Roster.lua:187`
  stops reading `_G.GetSpecialization` and asks `NS.Compat.GetSpecialization` instead.
- **Evidence:**
  - Surface: `LibKa0s/docs/api/Compat/version-1-docs.md:43-59`.
  - Stub rules: `:162-175`.
  - Wiring and the two-call parity gate for AuraMaster and MultiMeters: `:177-241`.
  - Spec: `3b-specs/compat.md:487-501` (§8.3), plus the gate amendment at `:222-238`.
- **Defects it fixes:**
  - `modules/Roster.lua:187` is a live `compat` breach: a feature module reads a deprecated global
    directly (spec OPEN-6).
  - The legacy `GetSpellInfo` rung passes the rank through as the icon (`core/Compat.lua:53-55`).
    The fixture at `tests/test_compat.lua:77` encodes that wrong shape. Only a harness can reach
    this rung.
- **Files:**
  - `core/Compat.lua`
  - `core/Secrets.lua`
  - `modules/Roster.lua`
  - `tests/test_compat.lua`
  - `tests/test_degraded.lua` (the premise and soft-optional lists)
  - `tests/test_surface_parity.lua`
  - `tests/run.lua` (the surface-source map)
  - `docs/compat-layer.md`
  - `docs/ARCHITECTURE.md`
- **Blast radius:** replaces host code. Seven function bodies go, and the call surface
  (`NS.Compat.X`, `NS.Secrets.X`) stays.
  - A degraded install loses spell names, icons and spec, because the reader arm answers `nil`
    where the host used to read the client itself. That is the shape the API document prescribes.
  - `GetSpellCooldown` and `GetSpellName` are not wired, because MultiMeters has no caller for either.
- **Recommendation: adopt.** The spec prescribes it for this repo with no "MAY defer". It closes a
  live standard breach, and the call surface does not move.

### C2 — `LibKa0s-Bus-1.0`: the stand-down record and the strict catalog

- **What:**
  - `core/Namespace.lua:168-253`: the hand-written record (a weak-keyed registry, message-only
    wrappers and the `__busStandDown` / `__busStandUp` pair) becomes `Bus:New{ name, isDown }`. It
    keeps three delegates: `NS.NewBusTarget`, `NS.BusStandDown` and `NS.BusStandUp`.
  - `NS.BusStandUp` moves to the first line of `standUp` (`core/LifecycleSetup.lua:151` / `:159`).
  - The fourteen wire strings in `core/Constants.lua:519-559` are renamed to PascalCase, and
    `Constants.MSG` is wrapped in `Bus.Catalog`.
- **Evidence:**
  - API document: `LibKa0s/docs/api/Bus/version-1-docs.md:69-100` (surface), `:184-220` (Catalog)
    and `:257-313` (the worked example, including the untracked-target stub).
  - `WowAddonStandards/standards/standards/options-ui.md:64` names that stub shape.
  - Spec: `3b-specs/bus.md:547-551` (the common block) and `:564-577` (MultiMeters).
- **Defect it fixes:** every wire string in `core/Constants.lua` breaks the naming-cheatsheet MUST
  that `<Event>` is PascalCase (`naming-cheatsheet.md:21`). That row names this addon without naming
  it ("exactly one addon in the collection diverged by letting it leak into the wire string").
  `bus.md:301` records the rename as owed (debt row 9+13), and `Catalog` refuses these names until it
  lands.
- **Files:**
  - `core/Namespace.lua`
  - `core/Constants.lua`
  - `core/LifecycleSetup.lua`
  - `tests/test_lifecycle.lua`
  - `tests/test_disabled.lua`
  - `tests/test_constants.lua`
  - `tests/test_degraded.lua`
  - `tests/test_surface_parity.lua`
  - `tests/run.lua`
  - `docs/ARCHITECTURE.md` (Message bus, Known limitations)
  - `docs/common-tasks.md`
- **Blast radius:** replaces host code: about 86 lines of record, plus a wire rename.
  - Subscribers and senders read constants, never literals. `grep -rn 'Ka0s_MultiMeters_'` outside
    `core/Constants.lua` finds only comments and docs. No other repo in the collection listens for a
    MultiMeters message: the same grep over the sibling checkouts finds only the spec and the
    harvest bundle.
  - The rename is therefore invisible on the wire to anything but this addon.
  - Deliberate behavior changes:
    1. A registration made while the bus is down is recorded but not live until `StandUp`. That is
       why the stand-up moves first.
    2. Events on a tracked target are now recorded too.
    3. A degraded install (no library) hands out untracked targets, so a disable there leaves bus
       registrations live.
- **Recommendation: adopt.** The spec prescribes both halves for this repo, and it fixes a live
  naming MUST.

### C3 — `LibKa0s-Schema-1.0`: primitives, registry and bracket (partial adopter)

- **What:** call the library's `SplitPath` / `Read` / `Write` / `SameValue`, `FindRow` / `AddRows`
  and `BulkBegin` / `BulkEnd` / `BulkRun` when the library is present, and the host's own functions
  when it is not (`settings/Schema_Paths.lua:97-127`, `:245-280`, `:549-634`, `:585-595`).
  MultiMeters keeps `SetByPath`, `SetByPaths`, `ApplyDefault` and `ValidateSchema`.
- **Evidence:**
  - Spec: `3b-specs/schema.md:540-549` ("Minor 1 removes none of MM's walker or bracket code; MM
    MAY defer"), and §14 V-3 at `:696-698`.
  - `LibKa0s/docs/api/Schema/version-1-docs.md:360-373`: "A partial adopter for which that trade is
    not worth two code paths MAY defer adoption until it adopts `Set`."
- **Files:** `settings/Schema_Paths.lua` and `settings/Schema.lua`, with their suites.
- **Blast radius:** additive in lines, but it forks every path primitive into two code paths. The live
  path would run the library and the degraded path the host copy. No host line is deleted.
- **Recommendation: decline, not now.** Both the spec and the API document say this repo MAY defer.
  The trade buys a second code path for every primitive and removes nothing, and MultiMeters'
  single-consumer `SetByPaths` batch keeps it off `Set` in minor 1. Re-offer this when a Schema minor
  can express an all-or-nothing batch that announces once.

## Order (rule 4: fixes a live defect, then closes a recorded gap, then new capability; smallest blast radius first)

1. **C1 Compat.** Fixes a live `compat` breach (`modules/Roster.lua:187`). It has the smaller blast
   radius of the two adoptions: seven bodies and one call site.
2. **C2 Bus.** Fixes a live naming MUST, which is also a recorded gap (debt row 9+13). Larger blast
   radius: it replaces the record, reorders the stand-up and renames the wire.
3. **C3 Schema.** A new capability that the spec lets this repo defer. Declined as not now.
