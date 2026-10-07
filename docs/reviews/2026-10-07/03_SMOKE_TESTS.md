# Smoke tests — Ka0s Multi Meters, review of 2026-10-07

These checks need the game client. The owner runs them after `02_PROPOSED_CHANGES.md` lands; an agent never marks one passed. Everything headless (lint, the suite, `tests/perf.lua`, complexity) was already measured in `01_FINDINGS.md`.

## Pre-flight

- Retail client on `## Interface: 120100`. The game loads `GIT/MultiMeters` through its symlink, so test the main checkout, not a side worktree.
- Before logging in, run once from the repo root: `lua tests/run.lua` (0 failed) and `luacheck .` (0/0).
- `/console scriptErrors 1`, then `/reload`.
- Use a **pet class** (Beast Mastery hunter, Unholy death knight, or a warlock with a demon). A target dummy is enough for most checks.
- Keep one window with at least the Damage and Healing columns shown and **Merge pets into their owner** ticked (General → Behavior).

## Per-change tests

### C-01: pet ahead of its owner folds into the owner's total (F-001)

- **Setup:** the pet class above, with Merge pets ticked. Set the window to the **Current** segment.
- **Steps:**
  1. Fight a target dummy for about 20 s while letting the pet do most of the damage. Hunter: stop casting except for basic shots. Otherwise, keep the pet attacking and auto-attack only.
  2. Leave combat and wait for the window to refresh (0.25 s by default).
  3. Untick Merge pets and read the pet's own row and your own row in Damage. Write down both totals.
  4. Tick Merge pets again.
- **Expected:** with Merge pets on, your row's Damage total equals the sum of the two totals from step 3, within rounding. It must not equal your own total alone.
- **Pass/Fail:** Pass if the merged total is the sum. Fail if it equals your solo figure.
- Repeat with `/mm export`, sending to Self. The Damage line for you must show the same summed figure.

### C-02: a partial roster no longer multiplies refresh cost (F-003)

- **Setup:** a party of 3 or more. `/mm debug on`.
- **Steps:**
  1. Have a member leave and rejoin, or zone into a dungeon together, while the window is shown.
  2. Watch the debug console's `[Roster]` lines.
- **Expected:** at most one `partial build (a of b) — will retry` line, then `built members=…`. No error popup, and no visible hitch while the group forms.
- **Perf evidence:** if a hitch is suspected, run `/mm perf` with the two-arm capture protocol (`performance-§7`) during a roster churn. Then read the `aggregate` bucket's ms/call against the previous capture under `docs/perf-analysis/`, and record the bucket figure rather than the frame-time delta. Record the capture with `/dev-copilot:wow-perf-analysis`.
- **Pass/Fail:** Pass if the window keeps rendering and the `[Roster]` lines show a retry per refresh, not a burst.

### C-03: case-only rename (F-004)

- **Steps:** on Windows, select a window named `Raid` (rename it first if needed). Type `raid` in Window name and press Enter.
- **Expected:** the picker and header show `raid`, not `raid 2`.
- **Pass/Fail:** the exact name typed is kept.

### C-04: `/mm window copy` with spaces (F-005)

- **Setup:** two windows, one still on its default name `Multi Meters #1`, and a second named `Second`.
- **Steps:** type `/mm window copy Multi Meters #1 Second`.
- **Expected:** `Copied everything from 'Multi Meters #1'.` and `Second` takes `#1`'s settings, keeping its own position.
- **Also:** `/mm window copy nosuch Second` still answers `No window named 'nosuch'.`
- **Pass/Fail:** both replies as stated.

### C-05: `Secrets.PlainTruth` (F-006, F-007)

- **Setup:** a dungeon or dummy pull, `/mm debug on`.
- **Steps:**
  1. Mid-pull, hover a row's name cell and a Damage cell.
  2. Mid-pull, type `/mm debug identity`.
  3. After the pull, type `/mm diagnostics`.
- **Expected:** no Lua error. The identity report prints its correlation and source-lookup sections without a `raised` section error. Your own row is still marked as you in the tooltip.
- **Pass/Fail:** no error popup, and no section ending in an error line.

### C-06: back button removed (F-008)

- **Steps:** left-click a Damage cell to open a breakdown, right-click a row to leave it, then left-click the same cell twice.
- **Expected:** the breakdown opens and closes as before. No button is drawn above the rows. No error.
- **Pass/Fail:** behavior is unchanged from before the change.

## Regression suite

- `/reload` cleanly. Then log out and back in: no error, and the windows restore at their saved positions.
- `/mm disable`: windows hide and `/mm toggle` refuses with the dispatcher's line. Then `/mm enable`: windows return, built from the current settings.
- Enter and leave combat with all windows visible. The values freeze to provider order mid-pull and re-sort afterwards.
- Open the settings panel (`/mm`) and toggle Merge pets, Refresh interval and one Visibility rule on the General page.
- **Cross-addon (in-client half of the measured clean pass):** with all eleven Ka0s addons loaded, type each root (`/at`, `/am`, `/bl`, `/cm`, `/kcd`, `/lh`, `/mm`, `/pm`, `/pfe`, `/pc`, `/wg`) and confirm each reaches its own addon. Then open Settings → AddOns and confirm each addon appears once, and each multi-page addon's pages appear once each.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | | | |
| C-04 | | | |
| C-05 | | | |
| C-06 | | | |
| Regression | | | |
| Cross-addon | | | |
