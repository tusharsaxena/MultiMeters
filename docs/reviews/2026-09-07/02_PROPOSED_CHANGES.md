# Proposed changes — Ka0s Multi Meters, 2026-09-07

Derived from `01_FINDINGS.md`. Standards cross-check **performed** against
**Ka0s WoW Addon Standard v2.38.0 (2026-09-02)**, resolved from
`https://github.com/tusharsaxena/WowAddonStandards` — the index plus all 26 linked section
files.

---

## HLD — themes

### Theme A — Make the feign trace free when nobody is recording

**Covers:** R-01, R-10, R-09

The trace's three call sites each build a fresh `{ order = {...}, ... }` table and only then
call `TraceFeign`, which discards it. Two allocations per observation, on the addon's hot path,
in every session. Measured: +6,720 bytes per coalesced refresh at raid fixture size.

The addon already has the right idiom for this and uses it fifteen times: `local t0 = Perf.on
and debugprofilestop()` — a plain boolean field read, then the work. The trace should read the
same way. `Diagnostics.IsFeignTraceArmed()` exists (`core/Diagnostics.lua:1618`) and has no
callers; a function call per death row is still cheaper than two tables, but a **plain published
boolean** is cheaper again and matches the surrounding code.

**Alternatives considered.**

- *Keep the table build and make `TraceFeign` reuse a scratch table.* Rejected: it moves the
  cost rather than removing it, and it makes the call sites reentrancy-sensitive for no gain.
- *Pass the fields as varargs instead of a table.* Rejected: the `order` array is what gives the
  report its stable field order, and the standard's line-format discipline is worth more than
  the allocation this would still not remove (the varargs themselves are free, but the sites
  would still concatenate to build a key list).
- *Drop the `judge` boundary entirely.* Rejected: it is the only boundary that says what the
  aggregator actually got, and R-02 fixes the volume problem more cheaply.

**Trade-off.** A published boolean is a second piece of state that `ArmFeignTrace` must keep in
step with `feignTrace`. That is one line, and it is the same coupling `LibKa0s-Perf-1.0`'s `on`
field already lives with, so it is a familiar shape rather than a novel one.

### Theme B — Make the recording able to answer the question it was built for

**Covers:** R-02, R-03, R-13

Three defects, one root: the recording was designed for the two rare boundaries and the third,
hot one was bolted into the same buffer. Fixing the buffer is the bulk; the two smaller items
(the untraced `unit == nil` eviction, and `state` reporting post-eviction) are corrections to
what each entry *says*.

R-03 matters disproportionately. The instrumentation exists to distinguish "the cast never
arrived" from "the entry was evicted before judgement", and the eviction branch most likely to
fire asymmetrically for a party member — a roster entry whose GUID is secret or whose token is
absent — is the one branch that emits nothing at all. A report can currently show a clean
`prune` history for a member who was in fact dropped.

**Alternatives considered.**

- *Raise `FEIGN_TRACE_MAX` to a few thousand.* Rejected as the whole fix: it delays the overrun
  rather than preventing it, and it makes the report unreadable. Kept as part of the fix for the
  two rare kinds, where a larger cap is genuinely right.
- *Sample `judge` (record every Nth).* Rejected: the interesting `judge` row is a specific GUID,
  and sampling is exactly the operation that loses it.
- *Record `judge` only for GUIDs that already appear in a `cast` line.* **This is the shape to
  prefer.** It is the join the report performs anyway, it bounds `judge` by the number of
  feigns rather than by the number of deaths, and it makes the ring's arithmetic sane without
  a second buffer. Noted as the recommended option in the LLD.

### Theme C — Re-align the committed evidence with the code

**Covers:** R-05, R-06, R-07, R-11

Four artifacts assert things about this code that stopped being true. Each has a different
owner and a different legitimate moment, and it matters not to collapse them:

- `docs/test-cases.md` and the README badge are **regenerated now**, as part of finishing the
  issue-#25 work — `testing` requires them to move with the change that moved the count, and
  that change has already landed without them.
- `tests/perf.lua`'s recorded baseline is **re-recorded as part of the R-01 fix**, because the
  R-01 fix is what changes the number.
- `docs/automated-tests/RESULTS.md` is **not touched here.** `automated-tests-§3` puts its
  regeneration at release, under `/wow-addon:bump-version`. Hand-editing it is worse than
  leaving it stale, because it would then read as measured.
- `tests/test_vendor_sync.lua:14`'s version quote is a one-word comment fix.

### Theme D — Structural pressure (recorded, not scheduled)

**Covers:** R-08, R-12, R-14

`core/Diagnostics.lua` crossed `layout-§1`'s 1500-LOC cap in this changeset (1566 → 1726). Six
other shipped files were already over. This theme proposes **one** peel — the one this changeset
caused — and records the rest for the next release's watch list rather than opening a refactor
front during a diagnostic investigation.

**Alternative considered and rejected:** peeling `settings/Schema.lua` (3069 LOC). The committed
watch list argues, correctly, that a split would have to be by page and would put the
"one table, one source" property at risk — which `architecture` names as the schema's whole
point. Size alone is not a reason to break it. Recorded as a known, argued exception instead.

---

## Upstream change-set

**Empty.** No finding this pass lands in a library repo. Nothing in `libs/` or `tests/_kit/` is
targeted by any change below, and no change below edits a path under either.

---

## LLD — the change-set

### C-01 — Gate every trace call site on a plain boolean *(R-01, R-10)*

**Files:** `core/Diagnostics.lua`, `modules/Feign.lua`, `modules/Aggregator.lua`

Publish the armed state as a plain field alongside the existing accessor:

```lua
-- core/Diagnostics.lua, near :1604
Diagnostics.feignArmed = false          -- plain boolean; read by the call sites

function Diagnostics.ArmFeignTrace(on)
    feignTrace = on and {} or nil
    Diagnostics.feignArmed = feignTrace ~= nil
    return Diagnostics.feignArmed
end
```

Then, at each site, read it **before** building anything:

```lua
-- modules/Feign.lua:102-105
local function trace(kind, fields)
    local D = NS.Diagnostics
    if D and D.TraceFeign then D.TraceFeign(kind, fields) end
end
```
→
```lua
--- Armed? One table index and one boolean test, evaluated BEFORE the caller
--- builds anything. This mirrors `Perf.on` (performance-§2): the sites that
--- feed a probe must cost nothing while the probe is off, and a table built
--- for a function that discards it is not nothing.
local function armed()
    local D = NS.Diagnostics
    return D ~= nil and D.feignArmed == true
end

local function trace(kind, fields)
    local D = NS.Diagnostics
    if D and D.TraceFeign then D.TraceFeign(kind, fields) end
end
```

and wrap each site's **table construction**, not just its call:

```lua
-- modules/Feign.lua:276-282  (and :141-142, :147-148)
if armed() then
    trace("prune", { order = {...}, ... })
end
```

```lua
-- modules/Aggregator.lua:1488-1497
if Feign then
    local D = NS.Diagnostics
    if D and D.TraceFeign then
        D.TraceFeign("judge", { order = {...}, ... })
    end
end
```
→
```lua
-- Hoisted out of the source loop entirely: the armed state cannot change
-- mid-pass, so this is one boolean test per COLUMN rather than one per row.
if Feign and traceArmed then
    D.TraceFeign("judge", { ... })
end
```
with `local D = NS.Diagnostics` and `local traceArmed = D ~= nil and D.feignArmed == true`
resolved **once**, above the `for index, src in ipairs(column.sources)` loop at
`modules/Aggregator.lua:1472`.

**Also fix the two comments that assert the false cost:** `modules/Aggregator.lua:1485-1486`
and `modules/Feign.lua:99-100`. After this change they become true, which is the point.

`IsFeignTraceArmed()` (R-10) is retained — it is now the tested accessor over the published
field, and the field is what the hot sites read. That resolves the dead-code finding without
deleting a member the suite pins.

**Risk:** low. Behaviour is identical when armed; the only change when disarmed is that nothing
is built. Two invariants must hold together (`feignTrace` and `feignArmed`), and C-05 adds the
case that pins them.

**Standards conformance:** shaped by `performance-§2` (dormant instrumentation costs one upvalue
read, one field read, one boolean test) and its `performance-§9` corollary that the claim is a
measured number rather than a comment. The rejected option — leaving the sites alone and making
`TraceFeign` cheaper — would have left a documented anti-pattern in place while appearing to fix
it. No new deviation introduced.

### C-02 — Bound `judge` by feigns, not by deaths *(R-02)*

**Files:** `core/Diagnostics.lua`

Two parts.

1. **Raise the cap for the rare kinds and keep `judge` out of their way.** Either two rings
   (`cast`/`prune` in one at ~400, `judge` in its own at ~120) or one ring plus a `judge`
   admission filter. Prefer the filter:

```lua
-- Diagnostics.TraceFeign, before the ring append
-- `judge` fires per DEATH ROW per refresh, so it is the one kind that can flood
-- the other two out of a shared ring. Admit only the rows whose GUID a `cast`
-- line already named — which is the join this report performs anyway, and which
-- bounds `judge` by the number of feigns rather than by the number of deaths.
if kind == "judge" and not castSeen[tostring(fields.guid)] then return end
```
   with `castSeen` populated on every `cast` entry and cleared by `ArmFeignTrace`.

2. **Replace `table.remove(log, 1)`** *(R-09)* with a write index into a fixed-size table, and
   have `reportFeign` read from the index forward. O(1) per insert instead of O(120).

**Risk:** medium — the admission filter changes what the report contains. It must not silently
hide a `judge` row for a GUID with no `cast` line, because "a death row judged for a GUID we
never saw cast" is itself informative. Mitigate by keeping a **counter** of suppressed `judge`
rows and printing it: `"judge: 412 rows suppressed for GUIDs with no cast line"`. That preserves
the finding while removing the flood.

**Standards conformance:** no rule constrains a diagnostic ring's shape. The change stays inside
`debug-logging`'s discipline (the report is printed through the addon's own sink at
`core/Diagnostics.lua:105`, not `print`). No new deviation.

### C-03 — Trace the not-in-group eviction, and report the pre-decision state *(R-03, R-13)*

**Files:** `modules/Feign.lua`

```lua
-- :247-249
local unit = present[guid]
if unit == nil then
    feigned[guid] = nil
else
```
→
```lua
local unit = present[guid]
if unit == nil then
    -- TRACED, because this is the branch that can fire asymmetrically: `present`
    -- admits an entry only where the roster GUID is a safe key AND a unit token
    -- exists (:236-240), and the local player's is always both. A party member
    -- dropped here leaves no `prune` line at all, which reads to a report reader
    -- as "prune saw nothing unusual" — the opposite of what happened.
    if armed() then
        trace("prune", { order = { "unit", "guid", "hp", "feigning", "state", "evicted" },
                         unit = "<not in group>", guid = guid, hp = nil,
                         feigning = nil, state = feigned[guid], evicted = true })
    end
    feigned[guid] = nil
else
```

And capture the state **before** the eviction at `:266`:

```lua
local wasState = feigned[guid]          -- "noted" | "down", read before :266 clears it
...
state = wasState or "?",
```

`"down"` means prune actually observed the unit feigning at least once; `"noted"` means it never
did. That distinction is the difference between "the client told us and we dropped it anyway"
and "the client never told us", which is the whole question.

**Risk:** low. Read-only additions plus one local hoisted above an existing assignment.

**Standards conformance:** none engaged. No new deviation.

### C-04 — Regenerate the inventory and the badge *(R-06)*

**Files:** `docs/test-cases.md` (generated), `README.md:7`

```
lua tests/run.lua --list > docs/test-cases.md
```
and set the badge to the total that file reports. **Never hand-edited** — the file's own header
(`docs/test-cases.md:7`) says so, and `testing` makes the runner's `--list` the sole writer.

This change is **required** by C-05 and C-06 regardless, since both move the count. Doing it as
part of this work also clears the pre-existing 1487→1496 drift that `81642e6` left behind.

**Standards conformance:** directly required by `testing` (inventory and badge move with the
change that moved the count). The rejected option — hand-editing the two numbers — is what the
generated-file header forbids.

### C-05 — Cases for the three untested behaviours *(R-04, and the regression guards for C-01…C-03)*

**Files:** `tests/test_diagnostics.lua`, `tests/test_feign.lua`

New cases, each with an explicit `-- red under:` naming the mutation that reddens it, matching
the convention the existing nine already follow:

| Case | Reddens under |
|---|---|
| `Diagnostics: the judge boundary records the aggregator's verdict` | removing the `judge` site, or hoisting it out of the loop wrongly |
| `Diagnostics: a full ring keeps the cast lines` | C-02 reverted — 200 `judge` observations then assert the first `cast` line is still present |
| `Diagnostics: nothing is built while the trace is disarmed` | C-01 reverted — count allocations across N disarmed refreshes and assert flat |
| `Feign: a member dropped from the group is TRACED, not silently evicted` | C-03 reverted |
| `Feign: an evicted entry reports the state it held when the decision was made` | C-03's `wasState` reverted |
| `Diagnostics: the armed field and the armed accessor never disagree` | C-01's two-invariant coupling |

Note the third: an allocation assertion in the **gated** suite is unusual and must be written as
a *count*, not a byte figure, or it will flake. If a robust count is not available under the kit,
place it in `tests/perf.lua` instead as a scenario and leave the gated suite asserting only that
`TraceFeign` was not called — `testing-§7` forbids counting a measurement scenario as a test case,
so it must not then appear in `docs/test-cases.md`.

**Expected count movement:** +6 cases, 1496 → 1502. C-04 must move with it.

**Standards conformance:** `testing-§12` (every negative assertion carries the mutation that
reddens it) and `testing-§7` (scenarios are not cases) are both binding on this change and are
what shaped the table above.

### C-06 — Re-record the perf baseline and re-derive the ceiling *(R-07)*

**Files:** `tests/perf.lua:539-564`, `docs/performance.md:225,244`

After C-01 lands, run `lua tests/perf.lua`, take the new `probeOverheadOff` figure, and rewrite
both the recorded measurement in the comment and `PROBE_OFF_BYTES_CEILING` derived from it with
the ~3.5% margin the block commits to. Record **why** it moved — the block requires a recorded
reason for any change, and "C-01 removed the disarmed trace allocation, and the previously
recorded 325955 had itself gone stale by 15.8 KB" is that reason.

Then update `docs/performance.md`'s two quoted figures from the same run.

Expected direction: `probeOverheadOff` back to approximately the `0e74319` figure (303416), so
a ceiling near 314000.

**Standards conformance:** `performance-§9` (the offline runner asserts deterministic quantities
and never a wall clock — unchanged here) and its rule that a recorded figure and its ceiling must
agree. The rejected option — raising the ceiling to accommodate R-01 — is the anti-pattern the
block itself warns against ("a rise IS the finding").

### C-07 — Peel `core/Diagnostics.lua` back under the cap *(R-08, this changeset's share only)*

**Files:** `core/Diagnostics.lua` → plus one new `core/DiagnosticsFeign.lua`

`core/Diagnostics.lua` was 1566 LOC before `81642e6` and is 1726 after — it crossed
`layout-§1`'s hard cap on this change. The 160 lines added are a self-contained section with its
own state (`feignTrace`, `FEIGN_TRACE_MAX`), its own three public functions and one private
report builder. Peeling it is the natural cut and restores the cap.

TOC placement: immediately after `core/Diagnostics.lua`, which is already documented as last in
the core block *"because it reads modules at CALL time and owns no state"* (`MultiMeters.toc`).
The new file inherits that property. The shared `out`, `shown` and `probe` helpers must be
published on the `Diagnostics` table (or moved to a shared local module) rather than duplicated —
duplicating them is the copy that goes stale.

**Risk:** medium — this is the only change here that moves code rather than adding it, and the
section under investigation is the section being moved. Sequence it **after** C-01…C-03 and
C-05, so the characterization cases exist before the move.

**Standards conformance:** required by `layout-§1` (>1500 LOC is a bug — peel it). The rejected
option — leaving it, on the grounds that six other files are already over — would compound a
deviation this changeset introduced. The other six are recorded in `01_FINDINGS.md` as
pre-existing and are not touched here.

### C-08 — Two one-liners *(R-11, R-12)*

- `tests/test_vendor_sync.lua:14` — change the quoted `v1.8.3` to `v1.25.0` to match
  `CLAUDE.md:52`. Comment only; the gate reads the live line and already passes.
- `settings/Slash.lua:474-482` — name a rejected argument instead of falling through to the
  report:

```lua
if arg ~= nil and arg ~= "on" and arg ~= "off" then
    if NS.Print then NS.Print("unknown: /mm debug feign " .. arg .. " — try on, off, or nothing.") end
    return
end
```

**Standards conformance:** `slash-commands-§3` reserves the `debug` verb's meaning but does not
constrain a sub-argument's error text; this change follows the addon's existing "name it, then
help" pattern (`settings/Slash.lua`, the unknown-verb path). No new deviation.

---

## Not proposed, deliberately

- **`docs/automated-tests/RESULTS.md`.** Stale (R-05), and its regeneration belongs to release
  under `/wow-addon:bump-version` (`automated-tests-§3`). C-07 will move `core/Diagnostics.lua`
  off the over-cap list and should reduce `scanColumn`'s neighbourhood; note the expected
  direction for the next release run to confirm. Do not run the tool into the repo now.
- **`settings/Schema.lua`'s 3069 LOC.** Argued exception; see Theme D.
- **`docs/perf-analysis/`.** Holds only its standing `README.md` — no captures committed. That
  absence is a compliance matter for `/wow-addon:standards-audit`, not a change here.
