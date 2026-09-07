# 05 — Execution plan

Ordered, checkable remediation for the twelve root deviations in `02_DEVIATIONS.md` (13 including
the one dependent). Read as one document with `02_DEVIATIONS.md`; every figure here is the same
figure there.

**Green gate between every step:** `lua tests/run.lua` (baseline **1496/1496**) and `luacheck .`
(baseline **0/0 in 45 files**). Any step that moves either baseline states the new number in its
commit message.

**Not in scope for this plan:** MM-A-07 (needs a coordinated ConsumableMaster change) and MM-A-12
(a `WowAddonStandards` change). Both are carried as hand-offs in Sprint 5.

---

## Sprint 1 — Stop shipping dev tooling, and fix the cheap wrong lines

Small, independent, no ordering constraints between them. Land first because Sprint 1 contains the
only Medium in the bundle.

| # | Step | Closes | Done when |
|---|---|---|---|
| 1.1 | Add `- .claude` and `- .superpowers` to `.pkgmeta`'s `ignore:` block | **MM-A-04** | The `for e in .[!.]*` sweep in `03_EVIDENCE.md` §0.7 prints `UNACCOUNTED — .git` and nothing else |
| 1.2 | Add `tests/test_packaging.lua`: every root dot-entry except `.git` has an ignore row | **MM-A-04** (recurrence) | Case is red with 1.1 reverted, green with it applied; suite total rises from 1496 |
| 1.3 | `README.md:7` → `Tests-1496%2F1496_passing` | **MM-A-09** | Badge equals `lua tests/run.lua`'s total |
| 1.4 | Add the `audits/` **and** `reviews/` store rows beside `revendor/` in `docs/ARCHITECTURE.md`'s *Topic detail* table | **MM-A-10** | Every directory under `docs/` is named exactly once in the map; no row per audit or per review |
| 1.5 | Re-run `lua tests/perf.lua`; close **#17** as `state:done` citing the run, or re-triage with what still fails | **MM-A-11** | No `state:untriaged` issue contradicts a measurement taken today |

**Risk:** none of these touch a load path. 1.2 is the only new code and it reads files, which the
harness already does in `tests/test_vendor_sync.lua`.

---

## Sprint 2 — Make the record honest before changing anything it measures

Must complete before Sprint 4. A refactor measured against a stale baseline is unmeasured.

| # | Step | Closes | Done when |
|---|---|---|---|
| 2.1 | Run `tests/_kit/run-automated-tests.sh`, producing a new dated bundle | **MM-A-02** | A new `docs/automated-tests/<stamp>/` exists with all seven artifacts, and `RESULTS.md`'s run table has its row |
| 2.2 | Write `<stamp>/ANALYSIS.md` for that bundle. **Do not** back-fill either frozen 2026-08-25 bundle | **MM-A-02a** | The newest bundle has an `ANALYSIS.md`; the two frozen ones are byte-identical to before |
| 2.3 | Re-author `RESULTS.md`'s *Functions over threshold* table against the new numbers — 23 entries, max CCN 36 — each with a disposition, and none reading a bare `Accepted` | **MM-A-02** | The table's numbers reproduce from `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .`; `RESULTS.md:30`'s *"Current as of"* names the new bundle |
| 2.4 | Re-author the *Files by `layout-§1` band* table: the seven over-cap files listed as **over the cap**, not *on notice*; `tests/wow_mock.lua` re-measured | **MM-A-02**, feeds **MM-A-01** | `settings/Schema.lua` reads 3069 and not 1371; `modules/Window.lua` reads 2644 and not 1232 |

**Check at the end of Sprint 2:** the three numbers in `RESULTS.md`'s newest row match
`manifest.json`, and `manifest.json` matches a fresh `lizard` run. If they do not, the runner was
edited — which the empty `diff -r tests/_kit` currently rules out, and which must stay ruled out.

---

## Sprint 3 — Documentation: ship the Tier 2 set, then drain the hub

Strict internal order: 3.1–3.5 before 3.6, because the spill targets must exist first.

| # | Step | Closes | Done when |
|---|---|---|---|
| 3.1 | `docs/slash-dispatch.md` — the 16 verbs from `settings/Slash.lua:72`, the `window` sub-verb tree, argument grammar, library-owned versus addon-owned | **MM-A-03** | Present; `ARCHITECTURE.md`'s *Slash commands* links it once |
| 3.2 | `docs/message-bus.md` — the 14 messages from `core/Constants.lua:489`, sender/payload/consumers, and the two documented multi-dispatch exceptions | **MM-A-03** | Present; the table's message list equals `MSG`'s keys exactly |
| 3.3 | `docs/compat-layer.md` — the 28 shims in `core/Compat.lua` (761 lines) by family, each with the client behaviour guarded and the fallback returned | **MM-A-03** | Present; the register row at `ARCHITECTURE.md:695` that asked for this decision is replaced by a map row |
| 3.4 | `docs/profiles.md` and `docs/debug.md` — thin by design, each linking rather than restating | **MM-A-03** | Both present and registered |
| 3.5 | Rewrite `ARCHITECTURE.md:683-698`: the five rows move from the evaluation table into the map's *Topic detail* table. Keep only `midnight-quirks.md`'s row — or retire the table entirely if 3.7 ships that doc | **MM-A-03** | No `Not applicable` row survives whose trigger the code fires |
| 3.6 | Spill *Known limitations* (~184 lines) into `docs/scope.md`; *Event subscriptions* (~71) into `docs/module-map.md`; *Overview* (~66) into `docs/scope.md`. **One** link left behind each | **MM-A-06** | No mandated section past ~60 lines |
| 3.7 | Spill *Taint notes* (~105) into a new `docs/midnight-quirks.md`, registered as Tier 2 | **MM-A-06**, **MM-A-03** | `ARCHITECTURE.md` under ~400 lines; `wc -l docs/ARCHITECTURE.md` is the check |

**Watch for:** `documentation-§3` forbids a Tier 3 doc duplicating Tier 1/2 content, and the same
discipline applies to what stays in the hub. A section that spills leaves a **summary and one
link** — not a second copy and not two links.

---

## Sprint 4 — Peel the seven over-cap files

Only after Sprint 2. One file per PR, suite green between each, no two peels in one commit.

| # | Step | Closes | Done when |
|---|---|---|---|
| 4.1 | `core/Diagnostics.lua` 1726 → dispatcher + per-probe bodies. Lowest risk: no state, read at call time (`MultiMeters.toc:58-59`) | **MM-A-01** | Every resulting file ≤ 1500; `tests/test_diagnostics.lua` green unchanged |
| 4.2 | `settings/Schema.lua` 3069 → assembler + `settings/schema/<page>.lua`. The concatenation order **is** the page and tab order, so it is load-bearing and gets a TOC comment naming what resolves | **MM-A-01** | `tests/test_schema.lua`, `tests/test_schema_defaults.lua`, `tests/test_options_panel.lua` green **unchanged**; row count and page order identical |
| 4.3 | `modules/Window.lua` 2644 → `+ modules/Window_Header.lua`, the peel `RESULTS.md:66` nominates | **MM-A-01** | ≤ 1500 each; `tests/test_window.lua` green |
| 4.4 | `modules/Tooltip.lua` 2652 → lift `eventColumns` and the drilldown column builders | **MM-A-01** | ≤ 1500 each |
| 4.5 | `modules/Aggregator.lua` 2058, `modules/Export.lua` 1743, `modules/Row.lua` 1702 | **MM-A-01** | All ≤ 1500 |
| 4.6 | Optional, and only where a peel exposes it: characterization-test then refactor `NS.ReorderableBlocks` (CCN 28) and `scanColumn` (CCN 36) — the two entries that are genuine control flow rather than `and`/`or` defaulting | **MM-A-02** watch list | A test pins prior behaviour **before** the refactor; CCN falls; no defaults table built inside the function |

**Forbidden in every step of this sprint** (`performance-§11`; anti-patterns #43, #52, #54):
- a helper whose name describes nothing a reader would recognise;
- a dispatch or defaults table built **inside** a per-refresh function — `scanColumn` is per column
  per refresh, so that trade is strictly worse than the branches it replaces;
- `t.k = stored.k or D.k` over any field whose stored `false` / `""` / empty set is a user choice
  (`export.whisperTo`'s empty string is its shipped default and legal; every visibility answer and
  every lock flag is the same shape);
- a new TOC line annotated *"order matters"* — either name what resolves, or leave it unannotated
  because the position is conventional. `tests/test_loadorder.lua` is the guard.

---

## Sprint 5 — Renormalise, then hand off what leaves the repo

| # | Step | Closes | Done when |
|---|---|---|---|
| 5.1 | `git add --renormalize .`, commit **alone**, then re-checkout the tree | **MM-A-05** | The `git ls-files … check-attr` one-liner in `03_EVIDENCE.md` §0.6 prints **0**, down from 21. `.gitattributes` is unchanged — it was already correct |
| 5.2 | Open a coordinated issue on **both** MultiMeters and ConsumableMaster: adopt `NS.Icon("circle-check")` / `NS.Icon("ban")` in one change, **or** file the `library-stack-§8` register row in both | **MM-A-07** | Both repos land the same end state in the same cycle; neither changes alone |
| 5.3 | Raise `options-ui-§16`'s broadcast-meta ambiguity upstream in `WowAddonStandards` | **MM-A-12** | Either the clause is narrowed to hits reproducing a mandated block, or `LibKa0s-OptionsCompose` gains a broadcast-meta composer |
| 5.4 | Add the wrapped-strip geometry case — **mock first**: make `tests/wow_mock.lua` answer different heights for the selected and unselected tab atlases, prove the case red under `tabArtHeight()` reading `TAB_ATLAS[true][1]`, then commit it green | **MM-A-08** | The case exists **and** has been demonstrated red under that mutation. A case that cannot go red is not the fix |

5.1 must come **after** Sprint 4, or the renormalisation diff mixes into every peel commit and
neither is reviewable.

---

## Exit criteria for the whole plan

- `.pkgmeta` accounts for every root dot-entry but `.git`, with a suite case that keeps it true.
- `docs/ARCHITECTURE.md` under ~400 lines, no mandated section past ~60, no false *Not applicable*
  row, `docs/audits/` and `docs/reviews/` each registered once.
- Five Tier 2 docs shipped (six with `midnight-quirks.md`), each registered in the map.
- `RESULTS.md`'s watch list reproduces from a `lizard` run taken the same day, with a disposition
  per entry and no bare `Accepted`.
- No `.lua` file over 1500 lines outside `libs/`.
- The line-ending one-liner prints 0.
- `luacheck .` still 0/0; `lua tests/run.lua` green at its new, higher total.
- MM-A-07 and MM-A-12 tracked as open issues in the repos that own them, not silently dropped here.
