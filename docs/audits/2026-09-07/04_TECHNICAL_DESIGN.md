# 04 — Technical design (remediation)

Keyed to the IDs in `02_DEVIATIONS.md`. Design only — this bundle changes no addon code.

The repo is in good shape. Nine of the twelve findings are documentation or configuration, one is
packaging, one is structural, and none is a defect a player can trigger into an error. The design
below is therefore weighted toward **not destabilising a green suite**: every code-touching step is
mechanical, reversible, and has a suite assertion that must stay green across it.

---

## A. `.pkgmeta` — MM-A-04 *(the only player-facing item)*

**File:** `.pkgmeta`.

**Change:** two lines in the `ignore:` block, placed with the other dot-entries so the block stays
readable as one group:

```yaml
ignore:
  - .luacheckrc
  - .gitignore
  - .gitattributes
  - .pkgmeta
  - .claude
  - .superpowers
  - docs
  …
```

**Why not a wildcard.** A `- .*` line would also swallow anything a future tool drops that *should*
ship, and the packager's semantics for a leading-dot glob are not worth relying on. Two explicit
lines, plus the enumeration-proof check below, is the durable pair.

**Guard against recurrence.** The named-entry list in `AUDIT.md` goes stale the moment a new tool
writes a new dot-directory; the whole-directory sweep does not. Add it as a case to the repo's own
suite rather than leaving it to the next audit:

```lua
-- tests/test_packaging.lua (new)
-- red under: a new root dot-directory appears and nobody adds an ignore row.
for entry in rootDotEntries() do
  if entry ~= ".git" then assertTrue(pkgmetaIgnores(entry), entry .. " is not ignored") end
end
```

The harness already reads repo files (`tests/test_vendor_sync.lua` reads `CLAUDE.md`), so the
capability exists and no new plumbing is needed.

**Risk:** none. No Lua changes, no load order, no stored data.

---

## B. Documentation — MM-A-03, MM-A-06, MM-A-10, MM-A-09

These four are one body of work and have a strict internal order, because MM-A-03's new files are
where MM-A-06's over-length sections spill **to**.

### B1. Five Tier 2 docs (MM-A-03)

| New file | Content, and where it comes from |
|---|---|
| `docs/slash-dispatch.md` | The verb table lifted out of `ARCHITECTURE.md`'s *Slash commands* section, plus the `window` sub-verb tree, argument grammar, and which verbs LibKa0s-Slash owns versus which this addon implements. Derived from `settings/Slash.lua:72`'s `NS.COMMANDS`. |
| `docs/message-bus.md` | The sender/payload/consumer table, derived from `core/Constants.lua:489`'s `MSG` catalog — the fourteen messages with the one-sender contract and the two documented multi-dispatch exceptions (`METER_RESET`, `ROSTER_CHANGED`'s inverted direction). |
| `docs/compat-layer.md` | The 28 shims in `core/Compat.lua` by family — the eight `C_DamageMeter` ones, the four death-recap ones, the `RecapMembers` / `RecapAPIs` / `CallRecap` probe, the player-state probes — each with the client behaviour it guards and the fallback it returns. |
| `docs/profiles.md` | Thin by design: that the tree is AceDBOptions' unchanged, the `PROFILE_CHANGED` fan-out, the reset-all veto, and a link to `schema.md` for the persisted shape. Three screens is a correct length here; the doc's job is that the question has an addressable answer. |
| `docs/debug.md` | `/mm debug on\|off` versus `/mm debug diag\|recap\|identity`; what each probe prints and what it is for; the console is the library's and is documented there. |

**Then rewrite the Tier 2 block in `ARCHITECTURE.md:683-698`.** Five rows move from the evaluation
table into the map's *Topic detail* table as ordinary registered docs. Keep the evaluation table
only for `midnight-quirks.md`, whose *Not applicable* argument (the secret-value model is the
addon's defining constraint, carried by *Taint notes* and `data-flow.md`, not a quirk beside a main
subject) survives re-measurement and is the row shape the standard actually wants.

**If a trigger is thought wrong**, the change belongs in `documentation-§3` upstream, not in a
*Not applicable* row here. That is a `standards-upstream` conversation and it does not block B1:
ship the doc, and retire it if the trigger is later narrowed.

### B2. Hub spill (MM-A-06)

`docs/ARCHITECTURE.md` 787 → target under ~400.

| Section | Now | Spills to | Leaves behind |
|---|---|---|---|
| *Known limitations* `:452-636` | ~184 | `docs/scope.md`'s out-of-scope half | a summary paragraph and one link |
| *Taint notes* `:304-409` | ~105 | `docs/midnight-quirks.md` (**new** — and note this makes midnight-quirks' trigger moot: it becomes a shipped Tier 2 doc rather than a *Not applicable* row) | R1/R3, the `Combat`-not-`ChallengeMode` fact, one link |
| *Slash commands* `:193-233` | ~40 | `docs/slash-dispatch.md` (B1) | the verb list, one link |
| *Event subscriptions* `:233-304` | ~71 | `docs/module-map.md`'s lifecycle half | the event → owner table, one link |
| *Overview* `:11-77` | ~66 | `docs/scope.md` | the two-paragraph what-and-why |

**Constraint:** the spill rule says *"a summary and exactly one link"*. Resist the temptation to
leave two links per section; that is how the hub grew the first time.

**Interaction with B1's `midnight-quirks.md`.** Spilling *Taint notes* there is the cleaner shape
than keeping a *Not applicable* row, and it costs nothing extra — the content already exists. If it
is done, the evaluation table in `ARCHITECTURE.md` disappears entirely, which is the tidier end
state.

### B3. `docs/audits/` store row (MM-A-10)

One row in the *Topic detail* table beside `revendor/` (`docs/ARCHITECTURE.md:681`):

```markdown
| `audits/` | Frozen — one dated bundle per standards audit: current state, deviations, evidence, design, plan |
```

**Never a row per audit.** The map's own preamble (`:638-639`) already states the store rule; this
row is the application of it.

### B4. Tests badge (MM-A-09)

`README.md:7` → `Tests-1496%2F1496_passing`, and then stop hand-maintaining it: the run bundle's
`manifest.json` carries `suites.tests.{passed,total}`, so the badge can be regenerated by the same
step that writes `RESULTS.md`. A hand-typed badge will drift again on the next test added.

---

## C. Complexity record — MM-A-02, MM-A-02a

**This is a process fix first and a code fix second.** Do not refactor toward a number before the
record is honest, or the refactor is measured against a baseline nobody can reproduce.

1. **Produce a fresh bundle.** `tests/_kit/run-automated-tests.sh` — vendored, executable, and
   unmodified (confirmed by the empty `diff -r` in `03_EVIDENCE.md` §0.8). It rewrites `RESULTS.md`'s
   run table itself.
2. **Re-author the watch list by hand** against that bundle: the *Functions over threshold* table
   with a disposition per entry, and the *Files by `layout-§1` band* table with the seven over-cap
   files (MM-A-01) called what they are — **over the cap**, not *on notice*.
3. **Write `ANALYSIS.md`** for the new bundle (MM-A-02a). Do **not** back-fill one into either
   frozen 2026-08-25 bundle; a frozen bundle is never edited.
4. **Give each entry a disposition that is not "accepted".** `automated-tests-§4`'s shelf-life rule
   starts a three-release clock the moment an entry reads *Accepted*, and this repo currently has a
   clean sheet on that. Keeping it clean is worth more than the convenience of the word.

**Reading the 23, so the refactor targets the right ones** (`performance-§10`): most of the new
entries are dense `and`/`or` defaulting, which `lizard` scores as branching and which a reader does
not experience as complexity. The two that are genuinely tangled control flow are
`NS.ReorderableBlocks` (CCN 28, a drag state machine) and `scanColumn` (CCN 36, per-column stat
dispatch mixed with secret-value guards). Those two are the ones worth a design, and each wants a
**characterization test first** (`testing-§13`) because both are currently covered only indirectly.

**Forbidden shapes to avoid while doing it** (`performance-§11`, anti-patterns #43/#52/#54):
- no `doTheRest()` helper whose name describes nothing;
- no dispatch or defaults table constructed **inside** the function — `scanColumn` runs per column
  per refresh, so a per-call table allocation there is strictly worse than the branches it replaces;
- no `t.k = stored.k or D.k` introduced over any field whose stored `false` / `""` / empty set is a
  real user choice — `window.frame.lock`, `export.whisperTo` (whose empty string is its shipped
  default, per `settings/Schema.lua`'s own note) and every visibility answer are exactly that.

---

## D. Structural — MM-A-01

Seven files over the 1500 cap. **Do not attempt this in one change**, and do not start it before C
is done: the fresh bundle is the before-picture.

Peel order, easiest and lowest-risk first, each along a seam the file's own header already names:

1. **`core/Diagnostics.lua` 1726 → n files.** The lowest-risk of the seven: it owns no state and is
   read at call time (`MultiMeters.toc:58-59` says so). Split by probe —
   `core/Diagnostics.lua` (the dispatcher) plus `core/diagnostics/` bodies, or three sibling files.
   No load-order constraint moves.
2. **`settings/Schema.lua` 3069 → per-page files.** The risk is real and named in `RESULTS.md`: the
   "one table" property is what the panel, the CLI and reset-all all read. Preserve it by keeping
   `settings/Schema.lua` as the assembler that concatenates `settings/schema/<page>.lua` arrays in
   declaration order — **the order is the page order and the tab order**, so the concatenation
   sequence is load-bearing and gets a TOC comment saying so. `tests/test_schema.lua` and
   `tests/test_schema_defaults.lua` pin the result and must stay green unchanged.
3. **`modules/Window.lua` 2644 → `modules/Window.lua` + `modules/Window_Header.lua`.** The peel
   `RESULTS.md:66` itself nominates.
4. **`modules/Tooltip.lua` 2652** — the event/drilldown column builders are already distinct
   functions (`eventColumns`, the anonymous CCN-26 body); they lift cleanly.
5. **`modules/Aggregator.lua` 2058**, **`modules/Export.lua` 1743**, **`modules/Row.lua` 1702** —
   last, and only after the first four have shown the suite tolerates the pattern.

**Constraint that binds every one of them:** a new file in `core/` or `modules/` is a new TOC line,
and `toc-file-§5` requires a comment at the line naming what resolves **if the position is
load-bearing**. Most of these peels are not — say so by leaving them unannotated rather than
writing "order matters", which `toc-file-§5` explicitly rates as the same failure in weaker form.
`tests/test_loadorder.lua` is the assertion that catches a mistake here.

---

## E. Line endings — MM-A-05

One action, in its own commit with no other change in it so the renormalisation diff is readable:

```sh
git add --renormalize .
git commit -m "chore: renormalize line endings against the declared CRLF pin"
git rm -r --cached . -q && git checkout .     # or delete the worktree and re-checkout
```

`.gitattributes` needs **no** edit — it is already the canonical client-bound body. Do this
**after** the code-moving work in D, not before, or every peel commit re-mixes with it.

---

## F. Shared media — MM-A-07 *(cross-repo; do not do it here alone)*

`settings/ColumnBlocks.lua:60-61` and ConsumableMaster's priority list draw the same two Blizzard
`ReadyCheck` textures, by explicit agreement recorded at `:58-59`. Two coherent end states:

- **Adopt the catalog in both repos in one coordinated change** — `NS.Icon("circle-check")` and
  `NS.Icon("ban")` — keeping the shared vocabulary the comment is protecting while moving it onto
  the shared payload. This is the preferred end state.
- **Or ratify it** with a `## Documented deviations` row in **both** repos, cited to
  `library-stack-§8`, with a re-check trigger naming the catalog gaining a mark whose semantics are
  ready/not-ready rather than check/ban.

**What must not happen** is changing one repo. That converts a deliberate shared vocabulary into an
inconsistency, which is worse than the current state.

---

## G. Suite gap — MM-A-08

One new case in `tests/test_options_panel.lua`:

```lua
test("Panel: a wrapped strip's geometry does not move with the selection", function()
    -- red under: tabArtHeight() reads the SELECTED button's art, or the chrome band is
    -- measured after the selection is applied.
    local inst = T.load()
    local baseline
    for i = 1, tabCount do
        local ctx = showPage(inst, "bars"); selectTab(ctx, i)
        local shape = { chrome = ctx.chromeHeight, rows = yOffsets(ctx.__tabKids) }
        if baseline then assertDeepEqual(shape, baseline, "selection " .. i)
        else baseline = shape end
    end
end)
```

**The case is only as good as the mock.** `testing-§12`'s trap applies directly: a harness that
answers one height for every atlas cannot fail this case and would be green against nothing.
`tests/wow_mock.lua` must be made to answer **different** heights for the selected and unselected
tab atlases before the case is written, and the case must be shown red under
`tabArtHeight()` reading `TAB_ATLAS[true][1]`. If it cannot be made red, it has not been written.

---

## H. Issue hygiene — MM-A-11

Re-run `lua tests/perf.lua`, then either close **#17** as `state:done` citing the run, or re-triage
it with the measurement that still fails. Use `gh issue edit` / `gh issue close` with `--label`;
never a hand-rolled GraphQL query, and space the calls out.

---

## I. Standards upstream — MM-A-12

Raise against `WowAddonStandards`, not against this repo: `options-ui-§16`'s mechanical clause
(*every `LSM30_*` hit MUST be a composer call site*) misclassifies an addon-wide **broadcast meta**
row that sets a value the composed groups then read. Either narrow the clause to hits that
reproduce a mandated **block**, or have `LibKa0s-OptionsCompose` expose a composer for the
broadcast meta so the mechanical form and the intent agree again. No local change meanwhile.

---

## Ordering constraints, in one place

- **B1 before B2** — the spill targets must exist first.
- **C before D** — a fresh baseline before any refactor, or the refactor cannot be measured.
- **D before E** — renormalisation last, so it does not mix into every peel commit.
- **G's mock work before G's case** — a case that cannot go red is not a case.
- **A, B3, B4, H** are independent and can land at any time.
- **F and I leave this repo** — neither is finished here.
