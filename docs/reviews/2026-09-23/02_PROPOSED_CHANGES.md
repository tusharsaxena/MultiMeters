# Proposed changes — Ka0s Multi Meters, review of 2026-09-23

**Standard resolved:** Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)**, fetched verbatim. Every change
below was checked against it as a guardrail. This is not a compliance audit: pre-existing deviations
that no change here touches are left to `wow-addon:standards-audit`.

**Upstream change-set:** **none.** No finding traces into `libs/` or `tests/_kit/`. No entry in this
document targets a path under either one.

**Test-count rule** (`testing-§5`): every change marked *adds cases* moves the pass count. It must
regenerate `docs/test-cases.md` with `lua tests/run.lua --list > docs/test-cases.md` and bump the README
`Tests-N/N` badge **in the same commit**, never as a follow-up. Do not add cases to
`tests/test_provider.lua`, which is exactly at the 1500-line cap (`layout-§1`).

---

## HLD — themes

### Theme A — The latch owns every show path (F-002, F-004, F-005, F-006)

`NS.ShouldShow` step 0 already makes a stood-down addon inert, but two surfaces reach around it:

- `WindowProto:Show()` puts a frame on screen without asking the ladder.
- `Window.New` arms a refresh clock without asking the latch.

The fix puts the latch question into **those two primitives** rather than into each caller. That way,
the test-mode exit, `/mm toggle`, the launcher's left-click and any future caller are all covered by
one rule.

- **Alternative rejected:** a disabled/suspended check in each of the three callers. That is three
  copies of one question, and the next `Show()` caller would be the fourth site to forget. It is also
  the shape of the "second teardown path" anti-pattern (#85): two mechanisms that have to agree about
  what "inert" means.
- **Alternative rejected:** hiding windows imperatively after the fact. `slash-commands-§7` requires
  hiding "at the source", because hidden frames come back.
- **Trade-off:** `/mm toggle` during a perf suspend now does nothing visible. That is the correct
  answer for an inert arm (`performance-§6`), and the change prints one line saying why rather than
  failing silently.

### Theme B — *Always show yourself* pins against the rows actually drawn (F-001)

The pin moves from "the configured cap" to "the rows this window will draw at this scroll offset". The
decision stays a **pure function in `modules/Aggregator.lua`**, next to `ApplyRowLimit`, and
`Window:Render` asks it one question per pass: *which entry goes in the last slot?* That keeps
`modules/Window.lua`, 76 lines under the cap, from growing beyond a few lines.

- **Alternative rejected:** passing `layout.maxRows` into `Aggregator.Build`. The export path and the
  diagnostics call `Build` without a window and would have to invent a height. The scroll offset only
  exists in the window.
- **Alternative rejected:** truncating to `layout.maxRows` inside `Build`. That would break scrolling,
  which relies on the full list being there.

### Theme C — Chat sends go through Compat, and a missing sender says so (F-003)

`core/Compat.lua` gains a `SendChatMessage` shim that prefers `C_ChatInfo.SendChatMessage` and falls
back to the deprecated global (`compat`: "MUST route every deprecated-API call through `Compat`"; "a
shim no major carries is written in this same file, by hand"). `modules/Export.lua` calls the shim.

When the player asked for a real channel and no sender exists, the export prints **one tagged notice**
before printing to self, so a misroute can no longer look like a send.

- **Alternative considered and deferred:** an additive `SendChatMessage` member on
  `LibKa0s-Compat-1.0`. No sibling addon sends chat today (the census found no other call site in
  loaded sources), so a library member would have one consumer. That is the premature promotion
  anti-pattern #55 warns against.

### Theme D — Refresh cost: stop clearing what is about to be refilled (F-007, F-009, F-017)

`Render` keeps rows bound to slots across passes and releases only the surplus. `Row:Update` walks only
the live cells. `Visibility:Evaluate` stops doing work on edges when debug is off.

This theme is **measure-first**. It ships only with a before/after in-client capture showing that the
`render` and `renderRow` buckets moved, plus the offline `refresh20x7` bytes and API counts unchanged
or lower. F-017 (the two chatty event registrations) is **measure only** in this cycle: add a bracket
or count and decide next cycle.

### Theme E — Evidence and hygiene (F-008 decision, F-010, F-011, F-012, F-013, F-014, F-015, F-016)

These are small, independent corrections: UX strings, comments, the mock version, the lint whitelist,
and a stale doc figure. F-008's direction is **decided by smoke test SM-06**, so it is written as two
branches below.

---

## LLD — change-set

### C-01 — `WindowProto:Show()` and `Window.New` ask the latch (F-002, F-004, F-005) — *adds cases*

**`modules/Window_Placement.lua`, `WindowProto:Show` (`:231`).**

```lua
function WindowProto:Show()
    -- THE LATCH FIRST (slash-commands-§7, performance-§6). Every other show path goes
    -- through NS.ShouldShow step 0; this one puts a frame up directly, so it has to
    -- ask the same question itself or a stood-down addon draws.
    if NS.IsStoodDown and NS.IsStoodDown() then return false end
    self:BuildFrame()
    ...                                  -- unchanged
    return true
end
```

**`modules/WindowManager.lua:659`.** Replace the perf-only guard with the latch:
`applyTestMode(enabled, not enabled and not (NS.IsStoodDown and NS.IsStoodDown()))`. With C-01's guard
in `Show()`, this expression is belt and braces. It is kept so the intent reads at the call site.

**`modules/WindowManager.lua`, `M:Toggle` (`:690`).** When `NS.IsStoodDown()` is true, return
`false, L["Windows are suspended while a performance capture runs."]` without touching any instance.
The disabled case never gets here, because the library refuses the verb and the launcher refuses the
click. The slash layer already prints `err` (`settings/Slash.lua:439`). For the launcher, change
`core/LauncherSetup.lua:235-236` to print the same `err` when `Toggle` returns it. Add the locale key.

**`modules/Window.lua:1382`.** Arm the clock only when the addon is up:
`if not (NS.IsStoodDown and NS.IsStoodDown()) then inst.frame:SetScript("OnUpdate", onUpdate) end`.
Stand-up already re-arms it through `WindowManager:Resume` → `inst:Resume()` (`:1420-1424`), so nothing
else changes.

**Tests** go in `tests/test_disabled.lua`, which is at 647 lines. Each case carries a `-- red under:` note (`testing-§12`):

1. Disabled mid-session: tick then untick the Test mode row, and no window is shown. *Red under:* reverting C-01's `Show()` guard.
2. Perf suspended: `/mm toggle` and the launcher's `onClick` show nothing and print the suspended line. *Red under:* removing the `Toggle` guard **and** the `Show()` guard.
3. Disabled: `WindowManager:Create("x")`, and no instance has an `OnUpdate`. After `enable`, every instance has one. *Red under:* reverting the `Window.New` guard. The second half is what proves the first half is not vacuous.

**Risk:** callers that relied on `Show()` returning nothing. A grep shows three callers, all in
`modules/WindowManager.lua`, and none reads the return. Existing cases
`tests/test_lifecycle.lua:288` and `tests/test_disabled.lua` *"Disabled 5"* must stay green.

**Standards:** `slash-commands-§7` (hidden at the source; OnUpdate cleared), `performance-§6` (suspend
inert), anti-pattern #85 (one latch, no second teardown path).

### C-02 — The self-pin follows the drawn slice (F-001) — *adds cases*

**`modules/Aggregator.lua`.** Add a pure function beside `ApplyRowLimit`, with no allocation:

```lua
--- The entry index to draw in the LAST visible slot instead of the one there, or nil.
--- Pure: reads flags, never a meter value (isPlayer is roster-derived and plain).
function Aggregator.SelfPinIndex(entries, first, visible, rowsConfig)
    if not (rowsConfig and rowsConfig.alwaysShowSelf) or visible < 1 then return nil end
    local last = first + visible - 1
    if #entries <= last and first == 1 then return nil end   -- everything fits
    for i = first, math.min(last, #entries) do
        if entries[i].isPlayer then return nil end            -- already on screen
    end
    for i = 1, #entries do
        if entries[i].isPlayer then return i end
    end
    return nil
end
```

**`modules/Window.lua`, `Render` (`:1199-1221`).** Before the loop, when the window is not in a
drill-down, compute `local pin = Aggregator.SelfPinIndex(entries, 1 + offset, layout.maxRows, self.config.rows)`
(resolved through `mod("Aggregator")`). In the loop, when `drawn + 1 == layout.maxRows` and `pin` is
set, draw `entries[pin]` in that slot. The expected change is about 6 lines, keeping `Window.lua` under
1440.

`ApplyRowLimit`'s existing pin stays: it still decides which rows survive an explicit cap below the
window's capacity.

**Tests** go in `tests/test_window.lua`, which is at 1240 lines:

1. A default window (`maxRows = 0`), 20 entries with the player at rank 15: the last drawn row is the player. *Red under:* removing the `pin` substitution.
2. Scrolled so the player is inside the slice: no substitution happens.
3. `alwaysShowSelf = false`: no substitution happens.

Also add one pure case in `tests/test_aggregator.lua` for `SelfPinIndex` returning `nil` when the player
is already in the slice.

**Risk:** a pinned row's rank number. `row:Update(entry, drawn)` passes `drawn` as the index. Check
whether the name cell shows a rank. If it does, pass the entry's real position (`pin`) so the player
sees "15." and not "10.". `03_SMOKE_TESTS.md` checks this.

**Complexity:** `Render` is at CCN 14 today. The fresh lizard run flags `WindowProto@1164-1221` at 14.
One added `if` takes it to 15, the gate ceiling. Keep the substitution a single expression
(`local entry = (pin and drawn + 1 == layout.maxRows) and entries[pin] or entries[i]`), or lift the
slot choice into a named local function. Never an unnamed `part2` (anti-pattern #52). The next
release's regeneration should confirm the function stays at 15 or below.

**Standards:** rule R3 in `docs/data-flow.md`, and `CLAUDE.md`'s invariant that layout comes from
config only (no widget read-back), are untouched: the pin reads a plain flag.

### C-03 — `Compat.SendChatMessage`, and a notice when no sender exists (F-003) — *adds cases*

**`core/Compat.lua`.** Add a hand-written shim, resolved at **call** time so the harness's absent
global keeps its meaning:

```lua
--- Chat send: 11.2.0 moved it to C_ChatInfo; the global lives on in Deprecated_ChatInfo.lua
--- until Blizzard removes it. nil when neither exists (the headless harness).
function Compat.ChatSender()
    local ci = _G.C_ChatInfo
    if ci and ci.SendChatMessage then return ci.SendChatMessage end
    return _G.SendChatMessage
end
```

**`modules/Export.lua:879`.** Change it to `local send = chatType and NS.Compat.ChatSender()`. In the
`if not send` branch, when `chatType ~= nil` (a real channel was asked for), first print one line:
`L["Chat sending is unavailable on this client — the export was printed to you only."]`. The *Self
only* path (`chatType == nil`) stays silent, as it is today.

**Tests** go in `tests/test_export.lua`, which is at 1275 lines:

1. With `C_ChatInfo.SendChatMessage` mocked, the send goes to it and not to the global. *Red under:* reverting to `_G.SendChatMessage`.
2. With neither mocked and channel `RAID`, exactly one notice is printed before the lines. *Red under:* removing the notice.
3. With channel `SELF`, no notice is printed.

Update any existing export case that counted chat lines on the no-sender path.

**Standards:** `compat` (deprecated calls only in `core/Compat.lua`). No deviation is introduced.

### C-04 — Stub `DisabledLine` gap closed at the wrapper (F-006) — *adds a case*

**`settings/Slash.lua:743`.** Publish the wrapper only when the dispatcher has the member:
`if cli.DisabledLine then function Sl:DisabledLine() return cli:DisabledLine() end end`.
`core/LauncherSetup.lua:232`'s existing guard then works as written: on the stub, the refused click
prints nothing and writes nothing.

- **Rejected:** giving the stub its own `DisabledLine` wording. That re-implements the dispatcher's
  line, which is exactly the stub drift the review brief and `testing-§8` warn against. The launcher's
  own comment (`:226-228`) says the line must be the dispatcher's, never a second copy.

**Test** goes in `tests/test_degraded.lua`: load with `LibKa0s-Slash-1.0`'s file removed from `libFiles`
but the rest of the library present, disable, then call the launcher's `onClick`. It must not raise and
must write nothing. *Red under:* restoring the unconditional wrapper. Optionally record in
`tests/test_surface_parity.lua`'s header that the Slash seam is now covered by this case.

### C-05 — Render keeps rows bound; Update walks live cells (F-007) — *measure-first; may add cases*

- **`modules/Window.lua`, `Render`.** Replace `self:HideAll()` + re-acquire with slot reuse. Keep
  `self.slots[i]` bound across passes, call `Acquire` only when `drawn > #slots`, release only the
  slots past `drawn` at the end, and re-anchor a slot only when `layout` changed. Record a
  `layoutVersion` bumped in `ApplyConfig`, and compare it per slot.
- **`modules/Row.lua`.** `ApplyLayout` stores the live cells as an array (`self.live`). `Update`
  iterates `self.live` instead of `pairs(self.cells)`. Net zero lines: the `live` set already exists
  at `:1311-1321`. **`Row.lua` must stay under 1500 (it is at 1469).** If the change adds lines,
  remove a stale comment block first.
- **Gate:** offline `refresh20x7` API count unchanged (8) and bytes/iter not higher. An in-client
  `/mm perf` capture in a group (see `03_SMOKE_TESTS.md` SM-07) shows `render` ms/call lower than
  the pre-change capture taken the same session. Frame-time delta is **not** evidence (below the
  harness's run-to-run spread).
- **Risk:** stale anchoring after a layout change. Mitigate with `layoutVersion`. The scroll-offset
  change has to re-anchor too, because slot positions are offset-independent: slot *i* always sits at
  `OffsetFor(layout, i)`, so this is safe.

### C-06 — `Visibility:Evaluate` only when someone reads it (F-009)

`modules/Visibility.lua:389-419`: return early from `Evaluate` when `not State.debug`, and delete
`Visibility.LastResult` together with its test. Alternatively, if a diagnostic genuinely needs it, wire
it into `/mm debug diag`. A function with zero shipped callers is dead code either way. Keep the
subscriptions: removing them changes nothing observable and churns `tests/test_disabled.lua`'s
registration census.

### C-07 — Correct window-command errors (F-010) — *adds cases*

- `modules/WindowManager.lua`: `Toggle` miss (`:704`) and `Delete`/`CopyFrom` miss (`:272`, `:471-472`) return `L["No window named '%s'."]:format(key)`.
- `Rename` with an empty name (`:309`) returns a new `L["A window needs a name."]`.
- `Resolve` misses from the settings panel's picker, which passes an id, keep `"No window is selected."`: distinguish on `type(key) == "number"`.
- Add cases in `tests/test_windowmanager.lua`, which is at 788 lines.

### C-08 — Route the Slash acknowledgements (F-011)

Move `settings/Slash.lua:415`, `:428`, `:446-447` (use two keys, not concatenated plurals), `:580`,
`:632-633` and `:696-697` into `L[...]` with English keys (`localization-§2`). Add the keys to
`locales/enUS.lua`. No `enUS.lua` key may be left unread (`localization-§3`).

### C-09 — Comment corrections (F-012)

- `core/MultiMeters.lua`: move `:459-463` above `function NS.ShouldShow` (`:499`), and move `:346-361` above `function NS:OnSpellSucceeded` (`:377`).
- Renumber the ladder steps 0→1→2→3, and fix `modules/Window_Placement.lua:202`'s "step 1" note.
- `modules/HeaderControls.lua:302`, `:372`: "settings/ loads **after** modules/".
- `core/LauncherSetup.lua:213-214`: drop the `shown` claim and state what Toggle actually does.
- Comment-only; no behaviour change and no case count change.

### C-10 — Mock version from the TOC (F-013)

`tests/wow_mock.lua:1087`: derive `Version` from `MultiMeters.toc` (read the `## Version:` line through
the root the mock already receives). Do not hard-code `"1.0.0"`. Any case asserting `0.1.0` moves in
the same commit. `docs/test-cases.md` changes only if a case name changes.

### C-11 — Drop `GetSpellInfo` from `read_globals` (F-014)

`.luacheckrc:69`: remove `"GetSpellInfo"`. `luacheck .` must stay at 0/0, confirmed with the fresh run:
no bare call exists.

### C-12 — Correct the stale feign figure (F-015)

`docs/performance.md:289`: re-run `tests/perf.lua` in that commit and quote the figure it prints. Today
that is 71544.1 for both arms. Keep the sentence's claim, which is arm equality. Never hand-edit a
number without the run.

### C-13 — The drill-down survives a rename (F-016) — *adds a case*

`modules/DrillDown.lua:850-855`: exit only when `payload.action ~= "renamed"`. Add a case in
`tests/test_drilldown.lua` (829 lines). *Red under:* removing the action check.

### C-14 — Decide the remembered roster's lifetime (F-008) — *blocked on SM-06*

- **If SM-06 shows the meter is empty after a fresh login:** in `Roster:OnRosterChanged` for
  `ENTERING_WORLD` with `isLogin == true` (the payload is `{ isLogin, isReload }`), call
  `Roster.Forget()`. Add a case.
- **If SM-06 shows the meter's data survives logout:** keep the map, cap it (for example, drop the
  entries not seen in the live roster when it exceeds `4 × MAX_ROWS`), and add a case.
- Either branch keeps the write player- or meter-driven, never from a game event while disabled.
  Roster's subscriptions are already stood down.

### C-15 — Measure the two chatty handlers (F-017) — *measurement only*

Add the handlers to an existing bucket, or count calls in a debug-only probe, and decide next cycle.
Adding a **new** perf bucket means a descriptor entry in `core/PerfSetup.lua` and a bracket, in one
commit, so it is never declared-but-unreached (`performance-§3`). No registration change this cycle.

---

## Standards conformance (per change)

| Change | Shaped by | New deviation? |
|---|---|---|
| C-01 | `slash-commands-§7`, `performance-§6`, anti-pattern #85; one latch, no per-caller copies | No |
| C-02 | `CLAUDE.md` R3 (layout from config); anti-pattern #52 when keeping `Render` ≤ CCN 15 | No |
| C-03 | `compat` (deprecated calls only in `core/Compat.lua`); anti-pattern #55 argues against a library promotion now | No |
| C-04 | `testing-§8` stub coverage; the rejected alternative would re-implement the dispatcher's line | No |
| C-05 | `performance-§2`/`§9` (measure, never assert wall-clock); `layout-§1` (Row.lua ≤ 1500) | No |
| C-06 | Dead-code removal | No |
| C-07, C-08 | `localization-§2`/`§3` | No |
| C-09 to C-13 | Comments, lint, evidence | No |
| C-14 | `slash-commands-§7` (no SV write from a game event while disabled) | No |
| C-15 | `performance-§3` (declared bucket ⇔ reached bracket) | No |

## Expected test and complexity movement

Pass count **rises** with C-01 (3), C-02 (4), C-03 (3), C-04 (1), C-07 (about 3), C-13 (1) and C-14 (1).
Each commit moves `docs/test-cases.md` and the README badge with it.

Watch-list direction, to be confirmed by the next release's regeneration rather than run now:

- `WindowProto@1164-1221` (`Render`) holds at CCN 15 or below.
- `modules/Window.lua` rises by about 6 lines from 1424.
- `modules/Row.lua` stays at 1469 or below.
