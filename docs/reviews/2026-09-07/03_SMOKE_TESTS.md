# Manual smoke tests — Ka0s Multi Meters, review of 2026-09-07

Executed **in-client**, after the changes in `02_PROPOSED_CHANGES.md` have been applied.
Everything that runs headless already ran in Step 0 of `01_FINDINGS.md` and is not repeated here.

---

## Pre-flight

**One command line, before you log in.** Both must be clean; if either is not, stop and fix
before testing in-client.

```
cd <repo>
luacheck .
lua tests/run.lua
```

Expect `0 warnings / 0 errors` and, after C-05, **1502 passed, 0 failed** (1496 before C-05).
If the count and `docs/test-cases.md` disagree, C-04 was not done — go back.

**Client setup.**

- Retail, Interface **120007** (`MultiMeters.toc:1`). No other interface version is supported.
- Install the addon as `Interface/AddOns/MultiMeters/` — the full working tree, `libs/`
  included. Do not test a nolib build.
- `/console scriptErrors 1` — Lua errors must surface as popups, not be swallowed.
- Two characters are needed across the suite: **a hunter** (for Feign Death), and any second
  character to group with. If you cannot field a hunter, sections T-02, T-03 and T-05 cannot be
  executed and must be marked `Blocked` rather than `Pass`.
- **Fresh SavedVariables for the first run:** before first login, delete
  `WTF/Account/<ACCOUNT>/SavedVariables/MultiMeters.lua` and `MultiMetersPerfDB` if present.
  Keep a copy — R-1 in the regression suite needs a pre-existing profile.

---

## T-01 — Nothing is built while the trace is disarmed *(C-01)*

**Change covered:** C-01 — gate every trace call site on a plain boolean.

**Setup:** log in on any character, solo, out of combat. Trace **not** armed (this is the
default at every login — `feignTrace` is a file local with no persistence).

**Steps:**
1. `/mm` — confirm the window is showing and the **Deaths** column is present (it ships enabled).
2. `/run collectgarbage("collect"); print(collectgarbage("count"))` — note the figure.
3. Kill five training dummies' worth of time at the **Stormwind Valley of Heroes dummies**, or
   run any content that produces at least a few group deaths in the session. Let 60 seconds of
   refreshes elapse with the window open.
4. `/run collectgarbage("count")` — note the figure. Do **not** collect first.
5. `/mm debug feign` — confirm it prints `not recording.` and the remedy line.

**Expected:** step 5 prints `not recording.` followed by `/mm debug feign on`, then the
`group now:` block. No Lua error at any point.

**Pass / Fail:** **Pass** if step 5 prints exactly the disarmed text and the session produced no
error popup. The GC delta in steps 2–4 is *orientation only* — the authoritative measurement for
C-01 is `tests/perf.lua`'s `probeOverheadOff` from the pre-flight, not this figure. Record it
anyway so a wild reading is visible.

---

## T-02 — The cast boundary records, and survives a full run *(C-01, C-02)*

**Change covered:** C-02 — `judge` no longer floods the `cast` and `prune` lines out of the ring.
This is **the** test of the review; it is the failure R-02 describes.

**Setup:** a party of at least two, one of them a hunter you control or can direct. A
**Mythic+ or Heroic dungeon** — something long enough to accumulate deaths. Do not use a raid
finder group; you need a hunter who will feign on command.

**Steps:**
1. Zone in. `/mm debug feign on` — expect `feign trace ON — run the dungeon, then /mm debug feign.`
2. **Immediately**, at the first pull, have the hunter cast **Feign Death** once.
3. Run the whole dungeon. Do not `/reload`. Accumulate at least ten group deaths — wipe
   deliberately once or twice if the run is going too well.
4. At the end, `/mm debug feign`.

**Expected:** the printed report contains, in this order:
- a `restriction:` / `armed: true` header line;
- an entry count;
- **at least one `cast  unit=party<N>  guid=…  kept=…` line from step 2**, still present after
  the whole dungeon;
- `prune` lines;
- possibly a `judge: N rows suppressed …` summary line (C-02's counter);
- the `group now:` block.

**Pass / Fail:** **Pass** only if the step-2 `cast` line is still in the report. If the report is
120 `judge` lines and no `cast` line, C-02 did not land — this is exactly the pre-fix behaviour
and it must be reported as a **Fail**, not as "the hunter must not have feigned".

**Note for the tester:** if there is genuinely no `cast` line *and* no `judge` flood — a short,
tidy report with `nothing recorded.` — that is not a test failure, it is the diagnostic doing
its job and saying `UNIT_SPELLCAST_SUCCEEDED` never arrived. Record the full report text in the
issue and mark this row **Pass (with finding)**.

---

## T-03 — A member who leaves the group is traced, not silently dropped *(C-03)*

**Change covered:** C-03 — the `unit == nil` eviction now emits a `prune` line.

**Setup:** party of two, the second being the hunter. Trace armed.

**Steps:**
1. `/mm debug feign on`.
2. Have the hunter cast **Feign Death**.
3. Have the hunter **leave the group** (or run far enough out of range that their roster entry
   loses its unit token — leaving the group is the deterministic version).
4. Wait for at least one refresh with a Deaths source present, or force one by taking damage.
5. `/mm debug feign`.

**Expected:** the report contains a `prune  unit=<not in group>  guid=…  state=…  evicted=true`
line for the hunter's GUID, and the `state` field reads `noted` or `down` — **not** `<evicted>`.

**Pass / Fail:** **Pass** if both the `<not in group>` line is present and `state` names a real
prior state. **Fail** if the eviction produced no line at all (C-03 not landed) or if `state`
reads `<evicted>` (the R-13 half of C-03 not landed).

---

## T-04 — The report degrades rather than raising *(C-01, C-03 guards)*

**Change covered:** C-01 and C-03 both add reads on the `NS.Diagnostics` table from module code.

**Setup:** solo, any character, out of combat, fresh login.

**Steps:**
1. `/mm debug feign` (never armed this session).
2. `/mm debug feign on`, then `/mm debug feign off`, then `/mm debug feign`.
3. `/mm debug feign banana`.
4. `/mm debug diag`.
5. `/mm debug on`, then `/mm debug` to open the console, then `/mm debug feign` again.

**Expected:**
- Step 1: `not recording.` and the remedy.
- Step 2: `feign trace ON — …`, then `feign trace off.`, then `not recording.`
- Step 3 (C-08): `unknown: /mm debug feign banana — try on, off, or nothing.` and **no** report
  printed. Before C-08 this printed a report instead.
- Step 4: the full diagnostic report, unchanged by this work.
- Step 5: the feign report renders **into the debug console** rather than chat, and the console's
  copy window can select it.

**Pass / Fail:** **Pass** if all five behave as written with no error popup.

---

## T-05 — Taint and combat *(regression only; no taint finding was raised)*

No finding in this review touches a protected API, a secure frame or a combat-gated write. This
section exists because C-01 and C-03 add code to a path (`Feign.Prune`) that runs **inside
combat**, on the aggregator's refresh.

**Setup:** hunter in party, target dummies or a dungeon trash pull.

**Steps:**
1. `/mm debug feign on`.
2. Enter combat. Stay in combat for at least 30 seconds with the window open.
3. While still in combat, click an action bar slot repeatedly.
4. While still in combat, `/mm debug feign`.
5. Leave combat.

**Expected:** no `Interface action failed because of an AddOn` red text at any point in steps
3–4. The report prints normally in step 4.

**Pass / Fail:** **Pass** if no red taint text appears. Any occurrence is a **Fail** and blocks
the change set.

---

## T-06 — Performance capture, two-arm *(C-01, C-06)*

**Change covered:** C-01's removal of the disarmed hot-path allocation.

Follow the standard's two-arm protocol exactly; do **not** improvise it.

**Setup:** a dungeon or raid group of at least ten. Window open, Deaths column enabled, trace
**disarmed** (the state C-01 is about). No `/reload` between arms. Same addon set both arms.

**Steps:**
1. `/mm perf help` — read the harness's own instructions and follow them over these.
2. **Arm 1 (clean):** `/mm perf start`, pull, fight for the window the harness asks for, stop.
3. **Arm 2 (suspend):** with the harness suspended, repeat the identical pull.
4. `/mm perf report`, then record the run as a frozen bundle via `/wow-addon:perf-analysis` into
   `docs/perf-analysis/<YYYYMMDD-HHMMSS>/`.

**Expected:** read the **bucket figures** — `aggregate` in particular, since that is the bucket
containing `scanColumn` and therefore the `judge` site. Do **not** read the frame-time delta
between arms; it is below the harness's run-to-run spread and resolves nothing.

**Pass / Fail:** **Pass** if the capture completes and a bundle is committed. This is a
**measurement**, not a threshold — there is no number here that fails the change. The
authoritative before/after for C-01 is the headless `probeOverheadOff` figure from C-06, which
should read approximately **303,400 bytes/iter** after the fix against **310,136** before it.

This is also the first capture this repo would hold: `docs/perf-analysis/` currently contains
only its standing `README.md`.

---

## T-07 — Localization *(not applicable)*

No finding in this review touched a `L[...]` key, a tooltip pattern, or a user-facing translated
string. The strings C-08 adds sit on the `debug` verb, alongside the addon's existing
untranslated diagnostic output (`core/DebugLogSetup.lua:292`). **Skip this section.**

---

## Regression suite

Not tied to any one change; these cover what the change set could plausibly break.

| # | Check | Expected |
|---|---|---|
| R-1 | Log in with a **pre-existing** `MultiMeters.lua` SavedVariables from before the changes | No migration prompt, no error, every window in its saved position, every column as configured |
| R-2 | Log in with SavedVariables **deleted** | Defaults populate, one window appears, Deaths column present |
| R-3 | `/reload` with the window open and the trace armed | No error; the trace is **empty** afterwards (it is session state and does not persist) — confirm with `/mm debug feign` |
| R-4 | ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD | No error popup at any stage |
| R-5 | Enter and leave combat five times with the window visible | Window follows the visibility rules; no flicker, no error |
| R-6 | Open the settings panel (`/mm config`) and **also** via Esc → Options → AddOns | Both open the same category; the tab strip renders on every page |
| R-7 | Toggle every control on the **General → Master controls** tab at least once | Each takes effect; no error; `/reload` preserves each |
| R-8 | Switch AceDB profile, then switch back | Windows rebuild; no orphaned frames; no error |
| R-9 | Enable and disable the Deaths column, then re-enable | The `judge` site is behind `isCount`; confirm no error and no stale column |
| R-10 | `/mm export` to chat with a hunter's feign in the session | The export runs; the feign filter behaves as before this work (C-01…C-03 are read-only w.r.t. the filter) |
| R-11 | `/mm debug diag`, `/mm debug recap`, `/mm debug identity` | All three unchanged; the new `feign` branch sits above them and must not have swallowed their dispatch |

R-11 is the one worth care: C-08 adds an early `return` on the `feign` branch. Confirm the three
sibling verbs still reach their reports.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| T-01 | | | |
| T-02 | | | |
| T-03 | | | |
| T-04 | | | |
| T-05 | | | |
| T-06 | | | |
| T-07 | n/a | n/a | No locale-tagged findings |
| R-1 … R-11 | | | |
