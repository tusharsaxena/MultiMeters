# 04 — Technical design (Ka0s Multi Meters, 2026-09-23)

The remediation design for every deviation in `02_DEVIATIONS.md`, keyed by ID. It includes the Info
entry and the SHOULD, because the engagement this feeds is asked to address **all** findings.

**Upstream first.** None of these findings needs a LibKa0s change. The vendored payload is
byte-identical to `v1.55.0` and the dispatcher, latch, launcher, bus and options toolkit are all
consumed correctly. One item has an optional upstream dimension, noted under MM-A-25. A collection
sweep that re-vendors a newer LibKa0s before this plan executes changes nothing here except the tag
MM-A-19's consolidated bundle has to span. That bundle must then also name the new tag, or a second
bundle must be written for it.

---

## MM-A-20 — isolated, recorded event registration (the only code change with runtime reach)

**Shape.**

1. Replace `registerIfValid` (`core/MultiMeters.lua:124-132`) with one helper, `registerEvent(target,
   event, handler)`, that:
   - asks `C_EventUtils.IsEventValid(event)` first where it exists, as the SHOULD front gate;
   - then **always** calls `pcall(target.RegisterEvent, target, event, handler)`;
   - appends `event` to `NS.State.rejectedEvents` (a session-only array) whenever either step says
     no, and logs one `[Init]`-tagged debug line with the name.
2. Route all 22 registrations in `NS:OnEnable` through it. A module-level `EVENTS` list of
   `{ event, handler }` pairs keeps it one loop without a per-call table (anti-pattern #43) and keeps
   the event table in `docs/ARCHITECTURE.md` diffable against code.
3. Reset `NS.State.rejectedEvents` at the top of `OnEnable`, because `standUp` re-runs it and a stale
   list would double-count.
4. Surface the list in `/mm debug diag` (`core/Diagnostics.lua`) as one line, "Events the client
   rejected: none" or the names. That makes it reachable through the reserved `debug` verb, which is
   the second MUST.

**Tests.** Add a case to `tests/test_lifecycle.lua`, which already exercises `NS:OnEnable`'s
re-registration. It sets the kit mock's `M.__badEvents` to one
name early in the list, then asserts that:

- every later event is still registered;
- the bad name is in `NS.State.rejectedEvents`;
- `/mm debug diag` prints it.

The case must go red under a regression to bare `self:RegisterEvent`.

**Docs.**

- Correct the `:153-156` comment. An unknown event raises; it does not idle.
- Note the trade in `docs/midnight-quirks.md` under the event-edge section.

**Risk.** The disabled-state suite (`Disabled 3`) counts registrations. A helper that registered
through a different target would break it, so keep `target = self`. Registration order is unchanged.

## MM-A-21 — the 1.0.1 tag

This is a process fix at the next release, not a code change.

- `/wow-addon:bump-version` to **1.0.2** (a patch release carrying this cycle's fixes) or **1.1.0**
  (if MM-A-20 or MM-A-18a counts as a feature or stored-shape change; MM-A-18a changes
  `schemaVersion`, which argues for MINOR).
- Roll `## Version History`, and optionally add a one-line `1.0.1` row ("re-published 1.0.0
  unchanged").
- Write the release run bundle with `"release": "<version>"` and all four suites at pass. The
  complexity gate is already met, at 0 warnings.

## MM-A-18 / MM-A-18a — `minimise` → `minimize`

Two phases in one change set, because the waiver entries have to come out in the same change as the
files they cover.

1. **Prose, comments, README, identifiers that are not stored, locale values and keys.**
   - Rename `L["Show minimise"]` to `L["Show minimize"]` and `L["Minimised"]` to `L["Minimized"]`,
     together with every call site (`localization-§5`: a key change is a key change). There is only
     `enUS.lua`, so no other locale file needs to move.
   - Rename the header control key `"minimise"` (`modules/HeaderControls.lua:127`) and its art lookup.
   - The README line is a README edit, so it takes the de-AI pass (`documentation-§1`).
2. **Stored paths (MM-A-18a).**
   - Add a `v15 → v16` step in `core/Database.lua`'s runner. For every profile, including inactive
     ones, it walks each `windows[i]`, copies `frame.minimised` to `frame.minimized` and
     `header.showMinimise` to `header.showMinimize` (or wherever `showMinimise` lives; see
     `defaults/Profile.lua:130`), then nils the old keys.
   - Rename the defaults and the schema rows (`settings/Schema.lua`, `settings/Schema_Paths.lua`).
   - `NS.ValidateSchema()` must pass.
   - Add a migration case that seeds a v15 profile with `minimised = true` and asserts it survives
     as `minimized = true`.
3. Delete every `minimis` entry from `tests/prose_waivers.lua`. If the file ends up empty, delete it;
   the kit treats an absent file as no waivers.

**Risk.** The migration is the only piece that touches player data. A missed profile loses one
cosmetic collapsed-state flag, not data. The docs regenerate `docs/test-cases.md`, and case names
containing `minimise` change with it.

## MM-A-03 + MM-A-06 — spill three Tier 2 docs, then shrink the hub

- `docs/slash-dispatch.md` takes the verb table, the `window` sub-tree, `export`'s resolution and the
  disabled-surface paragraph from `## Slash commands`. The hub keeps a summary and one link, which is
  the spill rule's shape.
- `docs/message-bus.md` takes the 14-row catalog, the bus-target discipline and the stand-down record
  from `## Message bus`. The hub keeps a summary and one link.
- `docs/profiles.md` takes the Profiles page, `PROFILE_CHANGED`'s fan-out, the reset-all veto and the
  AceDBOptions carve-out, from `settings-panel.md#profiles…` and the hub. Link rather than duplicate.
- Flip the three `### Conditional` rows to *Present*. `tests/test_docmap.lua` will then require the
  files to exist.
- MM-A-06: move `### Hard-coded texture paths` (`:621-681`) into a Tier 3 doc, e.g.
  `docs/texture-paths.md`, registered in `### Addon-specific`. `tests/test_texture_paths.lua` reads
  that table, so point its path at the new file in the same commit. Leave a two-line summary and the
  link under `## Documented deviations`. The expected hub size after both moves is roughly 520–560
  lines. Going further means moving `## The segment selector` (a non-mandated section of 44 lines)
  to `data-flow.md` or `scope.md`.

**Risk.** `tests/test_doc_structure.lua` and `tests/test_docmap.lua` read the hub. Run both after
each move.

## MM-A-22 — TOC annotations

Add at-line comments in `MultiMeters.toc`:

- `core\CoreSetup.lua`: "LOAD-BEARING: defines `NS.LIBKA0S_MISSING`, which `core\DebugLogSetup.lua`
  and `core\LauncherSetup.lua` read at FILE SCOPE in their library-absent branches."
- `core\PerfSetup.lua`: "LOAD-BEARING: the descriptor resolves `NS.Version()` at FILE SCOPE (after
  EnvSetup and Namespace), and every `modules/` file takes `NS.Perf` as a load-time upvalue."
- `settings\OptionsSetup.lua`: "LOAD-BEARING: every page file captures `NS.Helpers` at FILE SCOPE and
  registers its page at load."
- One "conventional" note per group for the lines free to move.

Optionally, extend `tests/test_loadorder.lua` with the three pair assertions.

## MM-A-23 — citation notation

A mechanical sweep, one commit:

- `library-stack §8` becomes `` `library-stack-§8` `` in the register Rule cell (`:519`) and at `:671`
  and `:679`, and `COLUMNBLOCKS_RULE` in `tests/test_texture_paths.lua:48` changes in the same commit.
- The 18 §-less lines become `slash-commands-§7` and the like.
- The 35 `-\194\167N` comment lines become a raw `-§N`. These files are UTF-8 and already carry raw
  `§` elsewhere.

`luacheck` and the suite both stay green, because only comments and one test constant change.

## MM-A-24 — inventory line

Correct `docs/ARCHITECTURE.md:14` to "Fifty-eight … 19 `core/` …". Optionally, add a
`test_doc_structure` case that derives the per-folder counts from `git ls-files` and compares them
with this line and `module-map.md:6`.

## MM-A-25 — the two texture declines

The owner decides between two options.

- **(a) Adopt.**
  - `TARGET_ICON` becomes `NS.Icon("target")`, with the current path kept as the nil fallback
    (`library-stack-§8`: nil is a real answer). Tint it to sit in a column of colored spell icons.
  - The grip draws `NS.Icon("resize")`, with a highlight derived by vertex tint.
  - This option has an optional upstream dimension. If a hover variant is wanted, it is a
    `LibKa0s-Media-1.0` addition made **upstream first** (generator, minor bump, re-vendor), never
    drawn locally.
- **(b) Ratify.**
  - Add two `## Documented deviations` rows citing `library-stack-§8`, each with a Decided date.
  - Triggers: "the catalog gains a colored or spell-style `target`" for the icon, and
    "`LibKa0s-Media-1.0` publishes a hover state" for the grip.
  - `tests/test_texture_paths.lua` already asserts a register row for the ColumnBlocks pair; extend
    that to these two.

## MM-A-16 — issue labels

Three `gh issue edit` calls, spaced out:

- `#21 --remove-label state:triaged --add-label state:done`
- `#4`: `state:will-not-do` or `state:done`, after reading its body against `media/textures/`, which
  no longer exists.
- `#24`: `state:done` or `state:will-not-do`, after reading it against #22.

No code changes.

## MM-A-19 — consolidated re-vendor bundle

Write `docs/revendor/2026-09-2x-v1.34.0-to-v1.54.2/` with `01_DELTA.md` (first line:
`# 01 — Delta: LibKa0s v1.34.0 → v1.54.2 (consolidated)`) and `05_SUMMARY.md`.

- The span covers the 28 tags `v1.35.0` through `v1.53.0`, plus the kit-only `v1.54.2`.
- `v1.18.0` through `v1.29.0` predate `v1.30.0`'s bundle. The 28 include them because the vendoring
  commits were never bundled. Either widen the span to `v1.15.0 → v1.54.2` and say so, or write a
  second consolidated bundle for `v1.15.0 → v1.30.0`.
- Per tag, the bundle records the commit that carried it (`git log -- libs/LibKa0s`) and "carried by
  sweep; adopted: …" where the commit message names an adoption.
- Back-filling one folder per tag is explicitly not the fix.

## MM-A-08 — wrapped-strip geometry case

Add a case to `tests/test_options_panel.lua`. It drives `O.__tabPlacement` and `O.__tabBand` with
widths that force a wrap (for example, eight labels on a narrow width). The mock must answer a
**different** atlas height for the selected tab art. For each selection index the case computes the
band height and every row's y, and asserts they are equal across indices. Record the mutation in the
case header: it must go red when `tabArtHeight()` reads the selected art.

## MM-A-26 — Info

Discharged by the next release run (MM-A-21). No separate work.
