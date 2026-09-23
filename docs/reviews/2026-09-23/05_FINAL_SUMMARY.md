# Final summary — Ka0s Multi Meters, review cycle of 2026-09-23

> **Written ahead of implementation.** This summary assumes every change in `02_PROPOSED_CHANGES.md`
> was applied and every check in `03_SMOKE_TESTS.md` passed. Figures marked *(expected)* are
> predictions to replace with observed values before this text becomes a PR body.

## Headline

This cycle closes the last gaps in the addon's off switch, makes a default-on feature actually work,
and removes a scheduled silent failure from chat export.

- **The off switch.** Turning the addon off was already a genuine stand-down: every event
  unregistered and every clock stopped. But the one function that puts a window on screen directly
  never asked whether the addon was up. Leaving test mode from the settings panel therefore brought a
  window back while the addon was off. `/mm toggle` or a minimap click did the same during a
  performance capture's suspended arm. That function now asks the same latch the rest of the addon
  does.
- **Always show yourself.** The feature ships ticked but only engaged when a player had also set a
  row cap. It now pins the player into the rows the window actually draws.
- **Chat export.** Exports reached chat through a global Blizzard has deprecated. When that global
  goes, the export would have printed to the player alone while looking like it had been sent. Sends
  now go through the Compat layer, and a missing sender is announced.
- **Also in this cycle:** render work per refresh is cut (measured before and after in client), and
  a set of smaller UX, comment and evidence corrections lands.

## Counts

**Critical fixed: 0 · High fixed: 3 · Medium fixed: 5 · Low fixed: 9**

| Severity | Findings fixed |
|---|---|
| High | F-001, F-002, F-003 |
| Medium | F-004, F-005, F-006, F-007, F-008 |
| Low | F-009, F-010, F-011, F-012, F-013, F-014, F-015, F-016, F-017 |

Two fixes are partial or conditional:

- **F-017 is measurement only.** This cycle adds instrumentation. Whether to change the registrations
  is decided next cycle, from the numbers.
- **F-008's fix branch is chosen by SM-06.** If the client's meter keeps data across logout, the map
  is capped rather than cleared at login.

## Changes by theme

### A. The latch owns every show path

- **What changed:** `WindowProto:Show()` refuses while the addon is stood down, for either reason.
  `Window.New` no longer arms its refresh clock while the addon is stood down. `/mm toggle` and the
  launcher's left-click answer "suspended" during a perf capture. The launcher no longer calls a
  refusal line that the library-less stub never had.
- **Why it mattered:** "disabled" and "suspended" are promises that nothing draws. One direct show
  path broke both promises, from surfaces the standard requires to stay live.
- **Findings / changes:** F-002, F-004, F-005, F-006 / C-01, C-04.
- **Files:**
  - `modules/Window_Placement.lua`
  - `modules/WindowManager.lua`
  - `modules/Window.lua`
  - `core/LauncherSetup.lua`
  - `settings/Slash.lua`
  - `locales/enUS.lua`
  - `tests/test_disabled.lua`
  - `tests/test_degraded.lua`

### B. The self-pin follows the drawn rows

- **What changed:** a pure `Aggregator.SelfPinIndex` decides whether the player belongs in the last
  visible slot for this window's height and scroll position. `Render` applies that decision.
- **Why it mattered:** on the shipped `maxRows = 0`, the pin ran against a 40-row cap while the window
  drew about 10 rows. The ticked box did nothing in every raid.
- **Findings / changes:** F-001 / C-02.
- **Files:**
  - `modules/Aggregator.lua`
  - `modules/Window.lua`
  - `tests/test_window.lua`
  - `tests/test_aggregator.lua`

### C. Chat sends through Compat

- **What changed:** `Compat.ChatSender()` prefers `C_ChatInfo.SendChatMessage`. When no sender exists,
  an export to a real channel prints one notice before falling back to printing to the player.
- **Why it mattered:** the deprecated global's eventual removal would have turned every channel export
  into a silent self-print.
- **Findings / changes:** F-003 / C-03.
- **Files:**
  - `core/Compat.lua`
  - `modules/Export.lua`
  - `locales/enUS.lua`
  - `tests/test_export.lua`

### D. Refresh cost

- **What changed:**
  - Rows stay bound to their slots across refreshes, and only surplus rows are released.
  - Cells are cleared only when they will not be refilled.
  - Only live cells are updated.
  - The visibility module's diagnostic evaluation runs only with debug on.
  - The two chatty event handlers are counted.
- **Why it mattered:** each refresh (4/s in combat) wrote every drawn cell twice and re-anchored every
  row.
- **Findings / changes:** F-007, F-009, F-017 / C-05, C-06, C-15.
- **Files:**
  - `modules/Window.lua`
  - `modules/Row.lua`
  - `modules/Visibility.lua`
  - `tests/test_visibility.lua`
  - `core/PerfSetup.lua`
  - `core/MultiMeters.lua`

### E. Hygiene and evidence

- **What changed:**
  - Window commands name the missing window.
  - Slash acknowledgements are routed through `L`.
  - A breakdown survives a rename.
  - Comments on the show ladder and load order are corrected.
  - The test mock reads its version from the TOC.
  - The lint whitelist drops `GetSpellInfo`.
  - `docs/performance.md` quotes today's feign figure.
  - The remembered roster gets a lifetime.
- **Findings / changes:** F-008, F-010 to F-016 / C-07 to C-14.
- **Files:**
  - `modules/WindowManager.lua`
  - `settings/Slash.lua`
  - `modules/DrillDown.lua`
  - `core/MultiMeters.lua`
  - `modules/Window_Placement.lua`
  - `modules/HeaderControls.lua`
  - `core/LauncherSetup.lua`
  - `tests/wow_mock.lua`
  - `.luacheckrc`
  - `docs/performance.md`
  - `modules/Roster.lua`
  - `locales/enUS.lua`
  - Each change's own suite

## API / behavior changes

| Surface | Change |
|---|---|
| `/mm toggle` and the launcher's left-click during a perf capture's suspended arm | Now inert, with one line saying so. Previously they showed windows |
| Test mode unticked while the addon is disabled | Leaves windows hidden. Previously it showed them |
| *Always show yourself* | Now effective at the default `maxRows = 0` |
| Chat export | Now sent through `C_ChatInfo.SendChatMessage` where it exists. A missing sender produces one notice |
| `/mm window …` and `/mm toggle` misses | Now answer `No window named '<name>'.` |
| New locale keys | The suspended-capture line, the chat-unavailable notice, *A window needs a name.*, and the Slash acknowledgement strings (C-08) |
| Slash verbs, SavedVariables schema, defaults | No new or renamed slash verbs. No schema version change. No new or removed defaults |

## Saved-variable / migration notes

There is no schema bump (`CURRENT_DB_VERSION` stays 15). The C-14 roster change edits
`db.global.roster`, which is learned data rather than a setting. Either the map is cleared at a fresh
login, or it is capped. No migration is needed, and existing profiles are unaffected.

## Deprecated-API migrations

| Old API | New API | Files |
|---|---|---|
| `SendChatMessage` (global, deprecated 11.2.0) | `C_ChatInfo.SendChatMessage` via `Compat.ChatSender()` | `core/Compat.lua`, `modules/Export.lua` |

## Performance impact

Fill in from SM-07's two `docs/perf-analysis/` bundles:

- `render` ms/call: before ___, after ___ *(expected lower)*.
- `renderRow` ms/call: before ___, after ___.
- Offline `refresh20x7` today: 8 API calls/iter, 303438.1 B/iter.
- Offline `refresh20x7` after: ___ *(expected ≤, API count unchanged)*.

Omit this section if C-05 is reverted at CP4.

## Test and complexity movement

- **Pass count:** 1948 before, about 1965 after *(expected: +3 C-01, +4 C-02, +3 C-03, +1 C-04, about
  +3 C-07, +1 C-13, +1 C-14)*.
- `docs/test-cases.md` and the README badge move in each commit that moves the count.
- **Watch list**, to be confirmed at the next release's regeneration and not regenerated here:
  - `WindowProto@1164-1221` (`Render`) stays at CCN ≤ 15.
  - `modules/Window.lua` rises about 6 lines from 1424.
  - `modules/Row.lua` stays at ≤ 1469.
  - The stale `NS.ValidateSchema` row in `docs/automated-tests/RESULTS.md` drops out, because today's
    fresh run no longer warns on it.

## Known follow-ups

- **F-017's registration decision:** it needs one cycle of the new counts first.
- **A `LibKa0s-Compat-1.0` chat-send member:** deferred until a second addon sends chat. With one
  consumer, adding it would be anti-pattern #55.
- **`tests/test_provider.lua` sits exactly at the 1500-line cap.** It needs a peel before it can take
  another case.
- **The cross-addon baseline table in the review brief is stale.** It records nine addons, ten majors
  and `120007`; the collection now has ten addons, fifteen majors and `120100`. Update it wherever that
  brief is maintained.

## Verification evidence

- The completed sign-off table in `docs/reviews/2026-09-23/03_SMOKE_TESTS.md`.
- The two `docs/perf-analysis/<stamp>/` bundles from SM-07.
- Commit range: `4aefb58..<head>` on `feat/2026-09-23-review-audit-remediation`.

## Suggested PR description

```
MultiMeters: close the stand-down's last show path, fix Always show yourself, route chat via Compat

- The latch now owns every show path: WindowProto:Show() and Window.New ask NS.IsStoodDown(),
  so unticking Test mode while disabled, or /mm toggle / a minimap click during a perf
  capture's suspended arm, no longer puts a window on screen or arms a refresh clock
  (F-002, F-004, F-005; slash-commands-§7, performance-§6).
- Always show yourself pins into the rows the window actually draws, so it works at the
  default "as many as fit" (F-001).
- Chat export sends through Compat.ChatSender() (C_ChatInfo first) and announces a missing
  sender instead of silently printing to self (F-003; compat).
- The Slash wrapper publishes DisabledLine only when the dispatcher has it (F-006).
- Render keeps rows bound to slots and updates only live cells, measured in client (F-007).
- Hygiene: window-command errors, routed Slash strings, rename keeps the breakdown, comment
  fixes, mock version from TOC, lint whitelist, stale perf figure, roster lifetime
  (F-008..F-016); chatty-handler counts (F-017).

Review bundle: docs/reviews/2026-09-23/. Tests 1948 -> <N>, luacheck 0/0.
```
