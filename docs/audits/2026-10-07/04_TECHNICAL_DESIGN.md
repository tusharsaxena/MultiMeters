# 04 — Technical design (Ka0s Multi Meters, 2026-10-07)

Remediation design for the open deviations in `02_DEVIATIONS.md`. Nothing here changes player-visible
behavior. Every change is either a document, a comment, a dead fallback rung, or a test. The work
splits into three changesets with no ordering constraint between them. Within each, the order below
is chosen so the green gate holds after every commit.

## Changeset A — the re-vendor record and the stamps it left behind (MM-A-19, MM-A-19a)

**Files:** `docs/revendor/2026-10-07-v1.69.0-v1.70.0/01_DELTA.md` and `05_SUMMARY.md` (both new),
`docs/settings-panel.md`, `docs/testing.md`, `DEPENDENCIES.md`.

- **The span bundle.** It uses the shape `audit-review-history` fixes. Line 1 of `01_DELTA.md` is
  exactly `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.69.0 v1.70.0)`. The rest of the file is the
  payload delta, read from `git -C ../LibKa0s diff --stat v1.68.1 v1.70.0 -- LibKa0s testkit`. It
  covers `WidgetsLineChart.lua` (v1.69.0), `WidgetsAutocomplete.lua` (v1.70.0) and kit revision 37.
  `05_SUMMARY.md` has one line per tag. Each reads *carried by sweep, nothing adopted*, with the
  reason: `LineChart` and `Autocomplete` are `Widgets` members this addon does not call, and neither
  tag adds a consumer MUST.
- **Check that the bundle is complete:** re-run the `AUDIT.md` re-vendor script and expect
  `UNRECORDED:` to be empty.
- **The stamps.** Replace `v1.68.1 bundled` in `docs/settings-panel.md:29` with wording that names
  no tag ("the vendored LibKa0s"). The provenance line in `CLAUDE.md` is the one place the tag is
  owed, and a second copy is what drifted. Do the same for `kit 36` in `docs/testing.md:597` and
  `DEPENDENCIES.md:35`, or set both to `kit 37`. Naming no tag is preferred, because it removes the
  thing that drifts.
- **Process note:** both drifting commits were bare `chore:` re-vendors.
  `/dev-copilot:wow-revendor-libka0s` writes the bundle and syncs the stamps itself. The next
  re-vendor should go through it.

## Changeset B — doc and comment corrections (MM-A-23, MM-A-24, MM-A-29, MM-A-06)

**Files:** `docs/ARCHITECTURE.md`, `core/LifecycleSetup.lua` (comment only), `settings/Slash.lua`
(comments only), `DEPENDENCIES.md`, `docs/automated-tests/README.md`, optionally
`tests/test_doc_structure.lua`.

- **MM-A-23:** `core/LifecycleSetup.lua:117`, `(architecture-4)` → `(architecture-§4)`. This is a
  comment, and the file is already UTF-8.
- **MM-A-24, hub:**
  - `:45`: either "Every file — all sixty-three of them —" or drop the count ("Every authored
    file"). Dropping it is preferred: `:14` already carries the gated count, and a second copy is
    the one that drifted.
  - `:511-512`: "Its three" → "Its two".
  - `:444` and `:454`: "**One row is ratified.**" → "**Retired on 2026-08-27: …**" and
    "**Retired on 2026-08-11: …**", the same heading shape the paragraphs at `:413`, `:420` and
    `:430` use.
- **MM-A-24, comments:**
  - `settings/Slash.lua:82-83`: drop "the README's command table" from the list of readers.
  - `settings/Slash.lua:857`: "the report lands with logging off" → "the report lands whatever the
    flag reads, and the run turns logging on for the session (debug-logging-§14)".
- **MM-A-24, gate (optional):** extend `tests/test_doc_structure.lua`'s file-count case to fail on
  any spelled-out "all `<word>` of them" in the hub whose number disagrees with the tracked count.
  Red under: `:45` reading "fifty-eight". If `:45` drops its count instead, the gate is not needed.
- **MM-A-29:**
  - `DEPENDENCIES.md:98` becomes `bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle   # the complexity report (release-time; sighted)`.
  - `docs/automated-tests/README.md:38`'s command cell becomes
    `bash tests/_kit/run-automated-tests.sh --suite complexity` (it runs
    `lizard -l lua -L 1500 -x "./libs/*" -x "./tests/_kit/*" .` over the sighted shadow).
  - **The pin is an owner decision**, and there are two options:
    - (a) Un-pin. `DEPENDENCIES.md:35` becomes "any recent", `:58` becomes `pipx install lizard`,
      and `:68-70` gets the standard's sentence ("`lizard` stays 'any recent' because the sighted
      suite checks function-count parity on every run").
    - (b) Keep the pin and add a `## Documented deviations` row: Rule `documentation-§7`, what
      differs (lizard held at 1.24.0), why, the decision date, and a re-check trigger such as "the
      kit's sanitizer is re-targeted to a newer `lizard`".
    - (a) is the default, because the standard argues against the pin's stated reason.
- **MM-A-06 (optional, same commit as the hub edits):** move the five retired-row paragraphs
  (`:413-458`) out of the hub. Each becomes one line, "Retired `<date>`: `<rule>` — `<one-clause
  reason>` (see `<bundle>`)", pointing at the audit or review bundle that carries the reasoning.
  Trim the Conditional table's measurement prose (`:361-367`) to the count and one clause. Expected
  result: about 470 lines, near the SHOULD. **Risk:** `tests/test_deviation_register.lua` and
  `tests/test_texture_paths.lua` read the register. Run the suite after the move. The retired rows
  are prose, not table rows, so those cases should not depend on them, but confirm it.

## Changeset C — code and test (MM-A-27, MM-A-30)

**Files:** `core/EnvSetup.lua`, `tests/test_envsetup.lua`, `core/PerfSetup.lua` (comment),
`settings/Slash.lua` (comment), `tests/test_disabled.lua`.

- **MM-A-27:**
  - Delete `core/EnvSetup.lua:93-95` (the `_G.GetAddOnMetadata` rung). `NS.Meta`'s library-absent
    branch is then `C_AddOns.GetAddOnMetadata` → `nil`, and `nil` still sends
    `core/Namespace.lua` to `FALLBACK_VERSION`, which is what `test_envsetup.lua:161` already pins.
  - Delete the case at `tests/test_envsetup.lua:146`. Replace it with a red-first case asserting
    that with `C_AddOns` absent, a bare `GetAddOnMetadata` mock is **not** consulted (spy it and
    assert zero calls). That pins the deletion. Red under: the rung restored.
  - Reword `settings/Slash.lua:64` and `core/PerfSetup.lua:94` to drop "the pre-11.x rung".
  - **Risk: none in client.** `## Interface: 120100` admits no client without `C_AddOns`. The only
    reader of the third rung was the harness.
- **MM-A-30:** extend "Disabled 8" in `tests/test_disabled.lua` with the right-click half, as
  `slash-commands-§7` step 8 reads it:
  - After `NS.SetByPath("enabled", false)`, call `inst.mocks.__resetSvWrites()` and record
    `#shownFrames(inst)`.
  - Drive `obj.OnClick(obj, "RightButton")` through the kit's menu mock, which is the same helper
    `tests/test_launchersetup.lua` uses (`openMenu`). Lift it into a shared local or reuse it through
    `T`.
  - Assert the menu opened, *Enabled* is enabled, *Locked*, *Test mode* and *Show window* are
    grayed, `#__svWrites() == 0`, and no frame was shown.
  - Falsification comment: "red under: a host OnClick that toggles a window on right-click, or a
    menu entry that is live while disabled".
  - **Risk:** the case count moves by one or by zero, depending on whether the assertion is added
    to the existing case. If a new case is added, regenerate `docs/test-cases.md` and the README
    badge in the same commit (`testing-§5`).

## Release-time item (MM-A-28, MM-A-26)

No code change. At the next `/dev-copilot:bump-version`:

- **MM-A-28:** the release's `## Version History` row carries a highlight in player language:
  "- `/mm set global.minimap.hide` is now `/mm set global.minimap.shown` (with the value flipped);
  update any macro that used the old name". As an alternative, the owner may append that highlight
  to the existing 1.1.0 row now, since that is the release that changed it. Appending is punctuation
  plus one new highlight, which `documentation-§1` item 11 allows. Every README edit goes through
  the de-AI pass (`documentation-§1`).
- **MM-A-26:** the release run is the first sighted bundle. Confirm the manifest has
  `suites.complexity.blindFiles: 0` and that the watch list's dispositions were carried forward.

## What is deliberately not done

- No register row is filed for anything in this run. Each open gap has a fix. The one candidate is
  MM-A-29's pin, and it is an owner choice.
- The two new `Widgets` members are not adopted. `LineChart` and `Autocomplete` have no consumer
  here, and adopting a widget because it exists would be the speculative work the standard warns
  against.
- `NS.DebugSteady` stays. The `debug-logging-§9` SHOULD names a host-kept gate re-armed from
  `onClear` as acceptable, and the reason it is kept is written at `core/DebugLogSetup.lua:220-225`.
