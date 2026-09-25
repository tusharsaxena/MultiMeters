# Smoke tests: Ka0s Multi Meters, after the 2026-09-23 changes

This checklist covers only what the game client can show. The headless suites already ran in Step 0
(see `01_FINDINGS.md`, *Measurement run*). Before logging in, run them again once:

```
~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua     # all green, count == README badge
~/.claude/wow-addon/bin/ka0s-bounded luacheck .               # 0 warnings / 0 errors
~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/perf.lua    # exit 0; refresh20x7 api/iter still 8
```

## Pre-flight

1. Install the branch build into `_retail_/Interface/AddOns/MultiMeters`. The client must be Retail on
   `## Interface: 120100`.
2. Load only MultiMeters. The last step also loads the other nine Ka0s addons. Type `/console scriptErrors 1`,
   then `/reload`. Install BugSack if you have it.
3. Use a character that can join a group. Several steps need a raid-sized group (11+), a target dummy,
   or a Hunter in the group.
4. Keep a copy of `WTF/Account/<acct>/SavedVariables/MultiMeters.lua` so you can restore it between
   steps that change settings.

---

## Per-change tests

### SM-01. Disabled addon: Test mode cannot bring a window back (C-01, F-002)

- **Setup:** default profile, one window visible, out of combat.
- **Steps:**
  1. `/mm disable`. Chat echoes `enabled = false` and the window disappears.
  2. `/mm config`, then General → Master controls. Tick **Test mode**, then untick it.
  3. Close the panel and wait 10 s.
  4. `/mm enable`.
- **Expected:** after step 2 no Multi Meters window is on screen. After step 4 the window returns.
  No Lua error at any point.
- **Pass/Fail:** **Pass** if no window is visible between steps 2 and 4.

### SM-02. Perf suspended arm: toggle and launcher stay inert (C-01, F-004)

- **Setup:** default profile, window visible, near a target dummy.
- **Steps:**
  1. `/mm perf`. In the panel, start a run. Record arm A with a short fight, then move to arm B
     (addon SUSPENDED).
  2. While suspended, type `/mm toggle`.
  3. Left-click the minimap button.
  4. Finish or cancel the run.
- **Expected:**
  - Steps 2 and 3 each print one line saying the windows are suspended for a performance capture,
    and no window appears.
  - After step 4 the windows come back as they were.
  - Right-clicking the minimap button during arm B still opens settings.
- **Pass/Fail:** **Pass** if no window shows during arm B and the suspended line prints once per action.

### SM-03. A window created while disabled does not tick (C-01, F-005)

- **Steps:**
  1. `/mm disable`.
  2. Open the Windows page and create a new window.
  3. Run `/run print(MultiMetersDB and "ok")` as a sanity check, and confirm no window is visible.
  4. `/mm enable`.
- **Expected:** after step 4 both windows appear and update in combat. No Lua error at any point.
- **Pass/Fail:** **Pass** if both windows draw live data after re-enable and nothing showed before it.

### SM-04. Always show yourself on the default profile (C-02, F-001)

- **Setup:**
  - Fresh profile: Profiles page → Reset Profile, which leaves one window at the default 220 px height.
  - Join a group of 11 or more (a raid or LFR). You must deal little enough damage to rank below 10th:
    sit out the first pull, or tank with low damage.
- **Steps:**
  1. Pull, then check the window after about 20 s.
  2. Scroll the window so that your own row is naturally visible.
  3. Untick Frame → Row → **Always show yourself**.
- **Expected:**
  1. In step 1 your row occupies the **last** visible slot, with your own name and value. If the
     grid shows ranks, check that yours is your real rank and not the slot number.
  2. In step 2 there is no duplicate of your row.
  3. In step 3 you drop off the view again.
- **Pass/Fail:** **Pass** if all three hold.

### SM-05. Chat export routes and announces (C-03, F-003)

- **Setup:** in a party with a second character or friend.
- **Steps:**
  1. Open the export modal from a window's export glyph and choose Party. Send.
  2. Choose Whisper and enter a misspelled name. Send.
  3. Choose Self only. Send.
- **Expected:**
  1. In step 1 the other player receives the lines and there is no "unavailable" notice.
  2. In step 2 you see one line saying there is nobody by that name, and the remaining lines stop.
  3. In step 3 the lines print locally with no notice.
- **Pass/Fail:** **Pass** if all three hold.
- **Also check:** `/run print(C_ChatInfo and C_ChatInfo.SendChatMessage ~= nil)` prints `true` on this build.

### SM-06. Remembered roster across a fresh login (decides C-14, F-008)

This test runs before C-14 is written, and it decides which branch C-14 takes.

- **Steps:**
  1. Group with 3 or more players and fight so the meter has data.
  2. Run `/run local t=MultiMetersDB.global.roster.byGuid local n=0 for _ in pairs(t) do n=n+1 end print(n)`.
  3. `/etrace`, filtered to `DAMAGE_METER`. Then **Log Out** fully to the character screen and log back in.
  4. Look at the meter window and at Blizzard's own damage meter.
  5. Run the command from step 2 again.
- **Record:**
  - Did Blizzard's meter keep the previous session's data?
  - Did `DAMAGE_METER_RESET` fire at login?
  - What was the count at step 2, and what was it at step 5?
- **Pass/Fail:** there is no pass or fail here. Record the answers in the sign-off Notes: they choose
  C-14's branch.

### SM-07. Render cost before and after (C-05, F-007)

- **Setup:** a group of 10 or more is preferred; solo is acceptable if labelled. The same zone and the
  same addon set for both captures, and no `/reload` between the two arms of either capture.
- **Steps:**
  1. **On the pre-change build**, run the full `/mm perf` two-arm protocol:
     - Arm A starts on combat and records a fight of about 60 s.
     - Arm B is suspended, again gated on combat and about 60 s.
     - Finish.
     - Record it with `/wow-addon:perf-analysis` as a `docs/perf-analysis/<stamp>/` bundle.
  2. Install the post-change build and repeat the protocol in the same session conditions.
- **Expected:** `render` ms/call and `renderRow` ms/call are lower after the change. `refresh` calls
  per second are unchanged, since the throttle is unchanged.
- **Pass/Fail:** **Pass** if the `render` ms/call drops.
  - Compare **bucket figures**, never the frame-time delta, which is below the harness's measured spread.
  - Never compare captures taken with different addon sets.

### SM-08. Window command errors (C-07, F-010)

- **Steps:**
  1. `/mm toggle nosuchwindow`
  2. `/mm window delete nosuchwindow`
  3. `/mm window copy nosuch "Multi Meters #1"`
  4. Rename a window to an empty name on the Windows page.
- **Expected:**
  - Steps 1 to 3 print `No window named 'nosuchwindow'.`, or `nosuch` for step 3.
  - Step 4 prints a message saying a window needs a name.
  - None of them prints "Setting not found" or "No window is selected."
- **Pass/Fail:** **Pass** if every message names the problem.

### SM-09. Slash acknowledgements still read correctly (C-08, F-011)

- **Steps:** run each of `/mm lock`, `/mm lock`, `/mm test`, `/mm test`, `/mm reset-positions`, `/mm debug tooltip` twice, and `/mm debug feign on`, then `off`.
- **Expected:** the same English lines as before. `reset-positions` says "1 window" or "N windows"
  with correct grammar.
- **Pass/Fail:** **Pass** if the text is unchanged in meaning and grammatical.

### SM-10. Drill-down survives a rename (C-13, F-016)

- **Steps:**
  1. After a fight, click a player's Damage cell to open the breakdown.
  2. Rename that window on the Windows page.
- **Expected:** the breakdown stays open under the new title.
- **Pass/Fail:** **Pass** if the breakdown stays open.

### SM-11. Stub path (C-04, F-006)

This check is optional: it needs a hand-broken install.

- **Setup:** in a **scratch copy** of the addon folder (never the repo), delete
  `libs/LibKa0s/Slash.lua` and remove its line from `LibKa0s.xml`.
- **Steps:**
  1. `/reload`.
  2. `/mm disable`.
  3. Left-click the minimap button.
- **Expected:** no Lua error, and nothing is written.
- **Pass/Fail:** **Pass** if there is no error. Restore the real folder afterwards.

---

## Regression suite

| # | Check | Expected |
|---|---|---|
| R-1 | `/reload` | No error. Windows are restored at their saved positions |
| R-2 | Fresh profile (Profiles → New) | One window, *Multi Meters #1*, default columns |
| R-3 | Login → `PLAYER_ENTERING_WORLD` | No error. Windows follow their visibility rules |
| R-4 | Enter and leave combat with a window shown; mount and dismount with *hide when mounted* on | Hides and shows on each edge. Test mode ends on pull, with one chat line |
| R-5 | Profile switch between a profile with `enabled = false` and one with `enabled = true` | The addon stands down and up with the switch, with no error |
| R-6 | Settings panel: open every page and toggle at least one control on each; press Defaults on one page | Windows follow each change. The minimap button's shown state survives Defaults |
| R-7 | `/mm` bare; `/mm help`; `/mm config` while disabled | The panel opens or help prints. Nothing is refused |
| R-8 | Feature verbs while disabled (`/mm toggle`, `/mm test`, `/mm export`) | One refusal line naming `/mm enable` for each, and nothing else happens |
| R-9 | Mid-pull (restriction active): hover a row, open a breakdown | Tooltip and breakdown render with no "secret" error; export refuses with its restriction message |
| R-10 | `/mm perf` full run, then `/reload` | `MultiMetersPerfDB` is written. Windows restored after the run finishes |

## Taint-specific

No taint findings were raised. As a guard for C-01 and C-02:

1. Enter combat with a window shown.
2. Click a cell to drill down, then right-click to exit.
3. Leave combat.
4. Confirm no `Interface action failed because of an AddOn` line appears.

Then confirm the panel opens from both `/mm config` and Esc → Options → AddOns.

## Cross-addon, in client (all ten Ka0s addons loaded)

1. Type each root and confirm it reaches its own addon: `/at`, `/am`, `/bl`, `/cm`, `/kcd`, `/lh`,
   `/mm`, `/pm`, `/pc`, `/wg`. Use the full names too where your muscle memory differs.
2. Open Settings → AddOns and confirm each addon appears **exactly once**.
3. Confirm each multi-page addon's pages appear once each.

## Localization sanity

C-08 routes strings through `L`, but no non-English locale ships, so there is nothing to switch to. As a check:

1. `/run print(GetLocale())`.
2. On an enUS client, repeat SM-09.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| SM-01 (C-01 / F-002) | | | |
| SM-02 (C-01 / F-004) | | | |
| SM-03 (C-01 / F-005) | | | |
| SM-04 (C-02 / F-001) | | | |
| SM-05 (C-03 / F-003) | | | |
| SM-06 (C-14 decision / F-008) | | n/a | meter kept data? RESET at login? counts before/after: |
| SM-07 (C-05 / F-007) | | | bundle stamps before / after: |
| SM-08 (C-07 / F-010) | | | |
| SM-09 (C-08 / F-011) | | | |
| SM-10 (C-13 / F-016) | | | |
| SM-11 (C-04 / F-006) | | | optional |
| R-1 … R-10 | | | |
| Cross-addon | | | |
