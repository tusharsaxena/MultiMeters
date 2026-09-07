# Review findings — Ka0s Multi Meters, 2026-09-07

**Verdict: minor issues.** The addon is structurally strong — lint clean, 1496/1496 green,
every declared perf bucket reached by a real bracket, both test load lists TOC/XML-derived,
vendor sync byte-identical against LibKa0s v1.25.0. Everything below concentrates in one
place: the feign-trace instrumentation (issue #25) that landed **during this review** as
commit `81642e6`, plus a stale layer of committed evidence that is no longer describing
this code.

**Standards cross-check: performed.** Resolved `Ka0s WoW Addon Standard v2.38.0, 2026-09-02`
from `https://github.com/tusharsaxena/WowAddonStandards`, index plus all 26 section files.

**A note on the working tree.** The task brief described 10 modified files. Partway through
this session those files were committed by someone else as `81642e6 "Measure why the feign
filter misses party members, before fixing it"`. The tree is now clean and that commit is
`HEAD`. Every finding below was formed against that content and the line numbers cite it.
The perf baseline in R-01 is `0e74319` — the commit immediately before it — which is the
correct before-arm.

---

## Measurement run (Step 0 — all re-run today, 2026-09-07)

| Suite | Command (repo root) | Result |
|---|---|---|
| luacheck | `luacheck .` | **pass** — 0 warnings / 0 errors in 45 files. Scope: excludes `libs/`, `tests/`, `docs/audits/`, `docs/reviews/`, `_dev/` per `.luacheckrc:6` — which is exactly what `lint-§2` prescribes. |
| Headless tests | `lua5.1 tests/run.lua` | **pass** — 1496 passed, 0 failed, 0 skipped, 1496 total. |
| `--list` inventory | `lua5.1 tests/run.lua --list > <scratch>/list.md` | **pass** (rc 0), 1665 lines. |
| Offline perf | `lua5.1 tests/perf.lua` | **pass** (rc 0), 13 scenarios, all assertions held. |
| Complexity | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | **ran**, rc 1 (warnings present). 31773 NLOC, 3276 functions, avg CCN 2.5, **23 warnings**, max CCN **36** (`scanColumn@1439-1540@./modules/Aggregator.lua`). |
| `make test` | — | **skipped**: no root `Makefile`. |
| Vendor sync | run as part of `tests/run.lua` (`tests/test_vendor_sync.lua` → `tests/_kit/vendor_sync.lua`) | **pass** — 2 cases, 0 skipped, so the sibling `../LibKa0s` checkout was found and both payloads compared byte-for-byte against the tag. |

### Committed artifacts that disagree with today's run

- **`docs/test-cases.md` is stale.** It records `| **Total** | **1487** |` (line 1656) and
  `### test_diagnostics.lua (60)` (line 215). Today's `--list` says **1496** and
  `test_diagnostics.lua (69)`. The nine missing entries are the feign-trace cases added in
  `81642e6`; the same commit did not regenerate the inventory. → **R-06**
- **`README.md:7` badge is stale.** `![Tests](...Tests-1487%2F1487_passing-green)` against a
  suite that runs 1496. Same commit, same omission. → **R-06**
- **`docs/automated-tests/RESULTS.md` watch list is stale, and its staleness is not benign.**
  It is headed *"Current as of `20260809-195454`"* and states **"Functions over threshold —
  None."** and **"Nothing is over the 1500 cap"**. Today: 23 functions over CCN 15, max 36,
  and seven shipped `.lua` files over 1500 LOC. → **R-05**
- **`docs/performance.md` is stale.** Line 225 quotes *"421214 bytes against 325955"*; today
  those scenarios measure **412373.3** and **310135.8**. → **R-07**
- **`tests/perf.lua:564`'s recorded baseline is stale**, and that is what let R-01 through.
  → **R-02**

Nothing that needs the game client was run here; the in-client checklist is
`03_SMOKE_TESTS.md`.

---

## High

### MULTIMETERS-R-01 — The disarmed feign trace allocates on every Deaths refresh
`[perf]` · `modules/Aggregator.lua:1488-1497`, `modules/Feign.lua:102-105`,
`modules/Feign.lua:276-282`

`TraceFeign` returns on its first line when nothing is armed (`core/Diagnostics.lua:1634-1635`),
but every call site **builds its argument table before it calls** — an outer hash table plus an
inner `order` array, two allocations per observation, whether or not anybody is recording.

The comment above the `judge` site claims the opposite, in as many words:
`modules/Aggregator.lua:1485-1486` — *"resolved at call time and costs one nil test plus one
boolean while nobody has armed a recording."* `modules/Feign.lua:99-100` repeats it. Neither is
true; the nil test happens two allocations too late.

**Measured, today, on this machine:** `refresh20x7` allocates **310158.1 bytes/iter** at `HEAD`
(`81642e6`) against **303438.1 bytes/iter** at `0e74319`, the commit before the trace landed —
a clean-room second run of `lua5.1 tests/perf.lua` on a scratch copy of the repo at that parent.
**+6,720 bytes per coalesced refresh, disarmed**, which is 336 bytes for each of the 20 death
sources in the fixture. `probeOverheadOff` moves the same way, 303415.8 → 310135.8.

`performance-§2` and `performance-§9` make "free when off" a measured property rather than a
comment; this is the same rule one layer up from a `Perf` bracket, and the addon's own hot path
is the one that pays.

**Reachability:** any player on a default profile with the Deaths column enabled (it ships
`defaultEnabled = true`, `core/Constants.lua:262`), on every coalesced refresh — four times a
second at the shipped 0.25s throttle, for the whole of every pull. Armed or not.

**Fix direction:** gate at the call site on a plain boolean before the table is built.
`Diagnostics.IsFeignTraceArmed()` already exists for exactly this and has no callers (R-11);
better still, publish the armed flag as a plain field so the site reads one boolean, matching
the `Perf.on` idiom this addon already uses everywhere else.

### MULTIMETERS-R-02 — The 120-entry ring guarantees the feign report loses the evidence it exists to show
`[design]` · `core/Diagnostics.lua:1604` (`FEIGN_TRACE_MAX = 120`), `:1643`

All three boundaries — `cast`, `prune`, `judge` — share one 120-entry ring, oldest evicted
first (`if #log > FEIGN_TRACE_MAX then table.remove(log, 1) end`). The file's own header
(`core/Diagnostics.lua:1594-1597`) states the problem and then does not solve it: *"`judge`
fires once per death source row on every Deaths refresh, which is the one of the three that is
not rare."* Arming is offered as the mitigation, but arming is precisely the state in which the
recording runs.

The arithmetic is not marginal. `judge` fires once per Deaths **source row**, and the Deaths
column reports one row **per death event** accumulated over the session
(`core/Constants.lua:252-257`), at the 0.25s refresh throttle. Ten accumulated deaths is 40
entries/second; the ring is 120. Every `cast` and `prune` line — the two boundaries that decide
between the issue's two candidate causes — is evicted within about three seconds of wall clock.
A player who arms the trace, runs a dungeon and then types `/mm debug feign` gets 120 `judge`
lines from the last few seconds and nothing else.

**Reachability:** every player who follows the issue-#25 instructions. The verb is documented
in the shipped help text (`settings/Slash.lua:80`) and in `README.md:85`, and the report itself
tells the player to *"run the dungeon, then `/mm debug feign`"* — the exact sequence that empties
the ring.

**Fix direction:** one bounded ring **per kind**, or a much larger cap for the two rare kinds
with a small separate one for `judge`. Whatever the shape, the `cast` lines must survive a
dungeon, because the report's own most-informative outcome (`core/Diagnostics.lua:1694-1701`,
"nothing recorded … the cast event never reached the addon") is only readable if their absence
means absence rather than eviction.

### MULTIMETERS-R-03 — The one eviction path most likely to explain issue #25 emits no trace
`[design]` · `modules/Feign.lua:247-249`

`Feign.Prune` walks the feigned set and drops any GUID not present in `present`:

```lua
local unit = present[guid]
if unit == nil then
    feigned[guid] = nil
else
```

`present` is built at `modules/Feign.lua:236-240` and admits an entry only when
`Secrets.IsSafeKey(entry.guid)` **and** `entry.unit` are both true. So a party member whose
roster entry carries a secret GUID, or has no unit token this pass, is evicted **silently** —
no `prune` line, no `judge` explanation, nothing in the recording at all.

That is not a peripheral branch. It is a leading candidate for the very asymmetry the issue
describes: the local player's own GUID is never secret and always has a token, so `player`
never takes this path while a party member can. The instrumentation added to answer "why does
this work for me and not for them" is blind to the branch that most plausibly answers it — and
worse, its silence reads as "prune saw nothing unusual".

**Reachability:** any group with a hunter where a member's roster entry is secret or
token-less on a prune pass; and, unconditionally, every developer reading a `/mm debug feign`
report, who will draw the wrong conclusion from a `prune`-shaped hole.

**Fix direction:** trace this branch too, with a distinct verdict value (`state="<not in
group>"`), gated behind the same armed-boolean R-01 asks for.

---

## Medium

### MULTIMETERS-R-04 — The `judge` boundary, the ring and the silent eviction have no test coverage
`[tests]` · `tests/test_diagnostics.lua:1282-1391`, `tests/test_feign.lua`

The nine new cases cover publication (`:1282`), the disarmed state (`:1289`), `cast` (`:1300`),
`prune` (`:1316`), re-arm clearing (`:1337`), the empty-log finding (`:1349`), the roster block
(`:1361`), API absence (`:1372`) and secret description (`:1382`). None covers:

- **`judge`** — the third declared boundary, and the one with the hot-path cost. `grep -n
  "judge" tests/test_diagnostics.lua` returns two comment lines and zero assertions.
- **The ring** — `FEIGN_TRACE_MAX` appears nowhere in `tests/`, so neither the bound nor the
  eviction order is pinned. R-02 is a bug in code the inventory implies is covered.
- **The silent `unit == nil` eviction** of R-03. `tests/test_feign.lua:122` (*"somebody who
  left the group is forgotten"*) exercises that branch's **behaviour** but was written before
  the trace existed and asserts nothing about it.

**Reachability:** the test inventory only; the shipped code's defects are R-01 to R-03. This
is a coverage finding, not a runtime one — but it is why R-01 and R-02 shipped green.

**Fix direction:** add a `judge` case, a case that arms and overflows the ring and asserts the
first `cast` line survives (which is the assertion R-02 would redden), and a case pinning the
not-in-group eviction is traced.

### MULTIMETERS-R-05 — The complexity watch list asserts "none over threshold" against 23 warnings
`[docs]` · `docs/automated-tests/RESULTS.md`

The watch list is headed *"Current as of `20260809-195454`, the v0.1.0 release run"* and states
**"Functions over threshold — None."** and **"Nothing is over the 1500 cap and nothing newly
crossed a boundary."**

Today's `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` reports **23 warnings, max CCN 36**.
Even the newest *recorded* bundle contradicts the list: `20260825-103437/manifest.json` carries
`"warnings": 19, "maxCcn": 31, "overCapFiles": 8` and a verdict of `amber`. The prose was simply
never advanced past the release run two bundles back.

Its "at the ceiling" table is wrong line by line as well. It cites `normalizeColumns` at
`settings/Schema.lua:1097-1151`; line 1097 today is `key = "bgColor", label = L["Bar background
color"],` and 1151 is a bar-outline `desc`. `WindowProto:BuildLayout` at `modules/Window.lua:147-192`
resolves to a comment about header glyphs. A reader following those citations lands nowhere.

**Reachability:** every maintainer or agent who consults the watch list before touching a hot
function — which the standard tells them to do — and is told there is nothing over the line.
No runtime effect.

**Fix direction:** the record is regenerated at **release** by `/wow-addon:bump-version`
(`automated-tests-§3`), never by hand and never as part of a fix. What belongs in the meantime
is a one-line note that the watch list predates two recorded runs. Do **not** hand-edit the
numbers.

### MULTIMETERS-R-06 — `docs/test-cases.md` and the README badge did not move with the change that moved the count
`[tests]` · `docs/test-cases.md:215`, `:1656`; `README.md:7`

`81642e6` added nine cases and regenerated neither. The inventory still reads
`### test_diagnostics.lua (60)` and `| **Total** | **1487** |`; the badge still reads
`Tests-1487%2F1487_passing`. The suite runs 1496 today. `testing` requires both to move in the
same change; the file's own header says *"Generated — do not hand-edit. Regenerate with `lua
tests/run.lua --list > docs/test-cases.md`."*

**Reachability:** anyone reading the badge or the inventory — an understatement of coverage,
not an overstatement, so the risk is a maintainer trusting a stale gap list. No runtime effect.

**Fix direction:** re-run the generator into `docs/test-cases.md` and update the badge, in one
commit, as part of finishing the issue-#25 work. Not by hand-editing either number.

### MULTIMETERS-R-07 — The offline perf ceiling absorbed R-01 without reddening
`[perf]` · `tests/perf.lua:564`, and its rationale block `:539-563`

```lua
local PROBE_OFF_BYTES_CEILING = 336000   -- measured 325955 for a 20x7 pass
```

The block above it commits to the discipline explicitly: *"set just above the measured figure.
Raise it only with a recorded reason — a rise IS the finding"*, and claims *"the headroom is the
same ~3.5%"*. Today the dormant arm measures **310135.8**, so the real headroom is **25,864
bytes, 8.3%**. The recorded baseline is 15.8 KB above what the code now allocates — the path got
cheaper and the comment was never re-recorded.

That slack is what swallowed R-01: a **+6,720 byte/iter regression on the addon's hot path
passed the guard that exists to catch exactly that**, silently, and `tests/perf.lua` exited 0.

**Reachability:** no runtime effect; the cost is that the addon's only automated allocation
guard is a third looser than it reads, and has already failed once.

**Fix direction:** after R-01 is fixed, re-record the measured figure and re-derive the ceiling
from it with the stated margin, in the same commit, with the reason written down as the block
requires. Do not simply lower the number — `performance-§9` wants the recorded measurement and
the ceiling to agree.

### MULTIMETERS-R-08 — Seven shipped files are over the 1500-LOC cap, two by more than 1000 lines
`[complexity]` · `settings/Schema.lua` (3069), `modules/Tooltip.lua` (2652),
`modules/Window.lua` (2644), `modules/Aggregator.lua` (2058), `core/Diagnostics.lua` (1726),
`modules/Export.lua` (1743), `modules/Row.lua` (1702)

`layout-§1`: *"MUST cap any single `.lua` file at 1500 LOC … a >1500 file is a bug — peel it."*
Measured today with `wc -l` over `find . -name '*.lua' -not -path './libs/*' -not -path
'./tests/_kit/*'`. `settings/Schema.lua` is 3069 — more than double — against the 1371 the
committed watch list records for it, so this has roughly doubled since the last release run and
nothing recorded it.

`core/Diagnostics.lua` crossed the cap **in this changeset**: 1566 → 1726, the 160 lines
`81642e6` added. That is the one entry here that is this change's own.

I raise this as a structural finding rather than a compliance score: the same growth is what
drives R-05's staleness and what makes `scanColumn` (CCN 36, `modules/Aggregator.lua:1439-1540`)
the repo's worst function. The audit agent owns the deviation count.

**Reachability:** maintainers only; no runtime effect. The concrete cost is that
`modules/Aggregator.lua`'s feign filter now sits inside a 102-line, CCN-36 function.

**Fix direction:** the watch list already names the natural peel for `modules/Window.lua` (the
header build). `core/Diagnostics.lua` is a set of independent report sections and peels cleanly
per section. `settings/Schema.lua` is the deliberate exception the watch list argues for — leave
it, but say so in the next record rather than letting it read as unnoticed.

---

## Low

### MULTIMETERS-R-09 — The trace ring is O(n) per insert
`[perf]` · `core/Diagnostics.lua:1643`

`table.remove(log, 1)` shifts 120 elements on every observation once the ring is full. With
`judge` firing per death row per refresh that is tens of thousands of element moves per second
**while armed** — which is exactly when a player is trying to reproduce a bug and wants the
client behaving normally. A write index into a fixed-size table costs one store.

**Reachability:** a player with the trace armed during a dungeon; not on the default path.

### MULTIMETERS-R-10 — `Diagnostics.IsFeignTraceArmed` has no production caller
`[dead-code]` · `core/Diagnostics.lua:1618`

`grep -rn IsFeignTraceArmed core modules settings` returns the definition and nothing else; its
only reference anywhere is `tests/test_diagnostics.lua:1293`. It is not a degradation-stub
member (no stub carries it — `core/Diagnostics.lua` is a TOC file, always present).

Worth noting rather than deleting: it is precisely the gate R-01 needs. The accessor that would
have prevented the hot-path allocation was written and then not used.

**Reachability:** nobody. A namespace member with one test asserting its own existence.

### MULTIMETERS-R-11 — The vendor-sync suite's header quotes a LibKa0s version three majors old
`[docs]` · `tests/test_vendor_sync.lua:14`

*"the LibKa0s repo published at the tag CLAUDE.md says this addon bundles (`"Bundles [LibKa0s](...)
v1.8.3 (MIT)."`)"*. `CLAUDE.md:52` says **v1.25.0**. The gate itself reads the line at runtime
and passes, so only the comment is wrong — but it is a comment whose whole job is to tell a
reader which version is under test.

**Reachability:** a comment; no runtime effect.

### MULTIMETERS-R-12 — `/mm debug feign <typo>` silently prints the report instead of naming the bad argument
`[ux]` · `settings/Slash.lua:474-482`

`arg` is matched, and anything that is not exactly `on` or `off` falls to the `else` branch and
prints the report. `/mm debug feign of` (a plausible typo of `off`) prints a report and leaves
the trace armed, with no indication the argument was rejected. Separately, `if not D then return
end` at `:473` returns with no output at all — consistent with the three sibling verbs above it,
so noted rather than pressed.

**Reachability:** a player who mistypes a documented debug argument. `README.md:85` documents
`feign on` / `feign off` / `feign`, so the surface a typo can land on is documented.

### MULTIMETERS-R-13 — The `prune` trace reports the post-eviction state, losing the pre-decision one
`[design]` · `modules/Feign.lua:280`

```lua
state = feigned[guid] or (evicted and "<evicted>") or "?",
```

`feigned[guid]` is set to `nil` at `:266` before the trace runs, so an evicted entry always
reports `<evicted>` and never the `"noted"` / `"down"` it held when the decision was made. That
distinction is diagnostic: `"down"` means prune actually observed the unit feigning at least
once, `"noted"` means it never did. The report drops the more informative of the two on exactly
the rows that were evicted — the rows anyone reading it cares about.

**Reachability:** every reader of a `/mm debug feign` report; no runtime effect on the addon's
behaviour.

### MULTIMETERS-R-14 — A degraded-API case asserts only that nothing raised
`[tests]` · `tests/test_diagnostics.lua:1372-1380`

*"the feign report survives a client with none of the unit APIs"* clears `UnitIsFeignDeath` and
`UnitIsDead` on the mock and asserts `pcall` returned true. It asserts nothing about what the
report printed, so it stays green if the roster block silently produces no lines at all — which
is the failure a reader would actually care about. (The mock nulling *is* effective: the loader's
env falls through `mocks[k]` to the real `_G`, which has no such global — `tests/_kit/loader.lua:14-18`.)

**Reachability:** the test inventory only; the shipped guards at `core/Diagnostics.lua:1667-1672`
are correct.

---

## Observation, not a finding

**Line endings.** `.gitattributes:26` pins `* text=auto eol=crlf` with the `*.sh text eol=lf`
carve-out at `:34` and the binary block at `:43-65` — all present and correct. `git ls-files
--eol` reports **22 paths as `w/lf`** in the working tree, of which one
(`tests/_kit/run-automated-tests.sh`) is the intended carve-out; the other 21 are stragglers
that will normalize on next touch. The authoritative count and its disposition belong to
`/wow-addon:standards-audit` (`line-endings-§2`), not here.

**Marks.** No hand-drawn mark found where the vendored catalog ships one. `media/` holds only
`logos/` and one bar texture — no second copy of a LibKa0s asset. `modules/Window.lua:147`
describes the header lock/gear controls as *"GLYPHS rather than as textures"*, which is worth an
in-client look against `libs/LibKa0s/media/icons/` (the catalog ships `lock.tga` and `unlock.tga`; I found no
gear/cog entry in it), but I could not establish from source alone whether these are Unicode
glyphs or library icons rendered as font strings. Recorded as **unverified**.

---

## Upstream findings

**None.** Nothing in `libs/` or `tests/_kit/` produced a finding this pass. The vendored payload
is byte-identical to the LibKa0s v1.25.0 tag (`tests/test_vendor_sync.lua`, 2 cases, passed with
the sibling checkout present), the kit's loader and framework behaved correctly under 1496 cases,
and every LibKa0s seam this addon wires — `core/EnvSetup.lua`, `core/PoolSetup.lua`,
`core/MediaSetup.lua`, `core/CoreSetup.lua`, `core/PerfSetup.lua`, `core/DebugLogSetup.lua`,
`settings/OptionsSetup.lua`, `settings/Slash.lua` — carries both a descriptor and a stub, with
`tests/test_degraded.lua` loading the addon with `libFiles = {}` rather than hand-stubbing.
