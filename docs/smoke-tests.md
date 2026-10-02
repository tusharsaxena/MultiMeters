# Smoke tests — Ka0s Multi Meters

These are the in-client checks for **Ka0s Multi Meters** that the headless suite cannot make.
`lua tests/run.lua` loads every source file under a mocked client and proves the logic; it cannot run
the real `C_DamageMeter`, real secret values or the real `Combat` addon restriction, and that is where
this addon's risk lives (the [COMBAT](#combat) theme). Run the suite before claiming a non-trivial
change works, before a release, and after refreshing `libs/` or bumping `## Interface:`. A change
confined to `.luacheckrc`, a headless-only gate under `tests/` or docs never reaches the client, so
`luacheck .` at 0/0 and a green `lua tests/run.lua` is its whole verification. Start each session from
a clean `/reload`; turn `/mm debug on` only where a step says so. Record each run on the check's
`Result:` line (date, client build, pass or what failed). IDs are `<THEME>-<n>`, stable across
rewrites: a new check takes the next free number in its theme, and a retired number is not reused.
Companion docs: [testing.md](testing.md) for the harness, [ARCHITECTURE.md](ARCHITECTURE.md) for the
secret-value rules the checks refer to.

## Index

| ID range | Theme | What it covers |
|---|---|---|
| INSTALL-1 to INSTALL-9 | [Install, load and reload](#install) | First login, SavedVariables shape, `/reload`, logout, old-file upgrades |
| SLASH-1 to SLASH-14 | [Slash commands](#slash) | Banner, help, every verb, CLI refusals, the minimap button |
| PANEL-1 to PANEL-47 | [Settings panel](#panel) | Tree, Windows page, entry shapes, text and color controls, Defaults, combat lock, the Columns editor, color drags, widget reuse |
| PROFILE-1 to PROFILE-17 | [Profiles](#profile) | The Profiles page, resets, the `/mm profile` verb |
| STATE-1 to STATE-11 | [Enable, disable, lock and Test mode](#state) | Stand-down, disabled refusals, perf suspension, lock, Test mode |
| WIN-1 to WIN-38 | [Windows and the header](#win) | Header controls, minimize, reset, divider, scale, border, drag, multi-window, the library resize grip |
| VIS-1 to VIS-12 | [Visibility](#vis) | Contexts and hide rules |
| GRID-1 to GRID-32 | [What the grid shows](#grid) | Text slots, numbers, names, pets, sorting, empty states, bar animation, segments |
| TIP-1 to TIP-36 | [Tooltips, drill-down and deaths](#tip) | Cell and name tooltips, breakdowns, death list and recap, tooltip styling, Targets |
| EXPORT-1 to EXPORT-55 | [Export](#export) | The modal, the whisper box, the CSV window and file, Print to Chat, `/mm export` |
| COMBAT-1 to COMBAT-30 | [Restricted pulls](#combat) | Secret values mid-pull, live ranking, identity ambiguity, refusals |
| DIAG-1 to DIAG-42 | [Diagnostics](#diag) | Debug console, perf capture, the diagnostics report, measurement captures, the event trace, rejected events, resizing the console, copy windows and perf panel, the console's Diagnostics link, diagnostics turning logging on, the library's own slash and Lifecycle lines, state lines at enable |
| DEGRADED-1 to DEGRADED-10 | [LibKa0s absent](#degraded) | The library-absent install, no resize grip |
| LOC-1 | [Non-English client](#non-english-client) | The CSV header on another locale |

## Before you start

- **`/reload`** means `/console reloadui`.
- **BugSack / BugGrabber** (or the stock Lua error frame), enabled and cleared, is the main signal.
  "No Lua error" means none at any point. Meter errors arrive four times a second mid-pull, so a
  single one fails the check even if the window looks right.
- **Restricted** means the `Combat` addon restriction is active, which is when meter numbers arrive as
  secret values. It follows combat, not Mythic+: between packs in a key the values are readable.
- **A pull** means a real one: a Mythic+ trash pack or a raid pull with the group fighting. A target
  dummy does not activate the restriction and is no substitute where a check says "a pull". Where a
  dummy is enough, the check says so.
- **Old SavedVariables.** INSTALL-6 to INSTALL-9 need a `MultiMeters.lua` file saved by an older
  build; copy it aside before INSTALL-1 wipes it.
- **Several windows.** Checks that say "two windows" start from Windows → General → **New window**.
- **Reporting a failure.** Give where (dungeon and key level, raid or open world; solo or grouped and
  the composition), when (in combat or between packs; login, reload or zone-in), the full Lua error
  with its stack (a secret-value error names the operation: compare, arithmetic, index, length or
  concat), the window config (`/mm list`), the diagnostics report taken right after the failure
  (`/mm diagnostics`, then **Copy** in the console), and whether it reproduces with one window and
  after `/mm set window.data.sortMode roster`, which takes value comparison out of the picture.

## INSTALL

- **INSTALL-1. Fresh install.** Quit WoW, delete `WTF/Account/<ACCOUNT>/SavedVariables/MultiMeters.lua`
  and its `.bak`, confirm the character-select AddOns list shows **Ka0s Multi Meters** enabled, log in
  → no Lua error; exactly one window, named **Multi Meters #1**, centered on screen, showing the six
  default columns after the name column, left to right: Damage · Healing · Interrupts · Dispels ·
  Avoidable Damage · Deaths. Result:
- **INSTALL-2. No schema errors.** After INSTALL-1, open the settings panel and walk every page →
  no `schema error:` line and no "schema path does not resolve" line at any point (either means a
  schema row's path or default disagrees with `defaults/Profile.lua`). Result:
- **INSTALL-3. SavedVariables shape.** After INSTALL-1, `/reload`, then read `MultiMeters.lua` on disk
  → `profileKeys`, `profiles.Default`, `global.schemaVersion = 16`, a one-entry `profile.windows`
  whose window has `id = 1`, and `profile.nextWindowId = 2`. Result:
- **INSTALL-4. `/reload` keeps the layout.** Move the window, resize it, change its bar color and its
  column set, `/reload` → position, size, color and columns survive; the window is in the same
  visibility state; no error during load; `nextWindowId` has not moved. Result:
- **INSTALL-5. Meter data survives a full logout.** Fight a target dummy, `/logout` fully, log back in
  → window #1 still shows the previous fight's segments and the people in them. A player who left the
  group keeps their row on data from before the logout. An empty meter after a fresh login means the
  observation behind `db.global.roster`'s bound (prune above `4 * MAX_ROWS`, no forget at login,
  `modules/Roster.lua`) has changed and the bound needs revisiting. Result:
- **INSTALL-6. Upgrade from v1 (uniform column widths).** Log in with a file written by v0.1.0 →
  every column is the same width and the window is wide enough to show the rightmost one; a window
  previously dragged wider keeps its width (the step only widens); after `/reload` nothing moves and
  `schemaVersion` has advanced; a second profile not activated this session has its widths lifted
  too. Result:
- **INSTALL-7. Upgrade from v12 (title bar and control colors).** Log in with a file saved at
  `schemaVersion` 12 or earlier, on a window with its title bar off and at least one of *Control class
  color* / *Control hover class color* ticked → the title bar is still off and the control colors are
  exactly as they were; Header → **Title bar** shows the toggle unticked; Header → **Button style**
  shows **Class color** for whichever flag was ticked, not Custom; after `/reload` nothing moves; a
  second, inactive profile is carried across too. A title bar back on, or colors reset to Custom,
  means the step wrote a default. Result:
- **INSTALL-8. Upgrade from v13 (Lock frame).** On a build from before v14, with two windows, unlock
  one from its header padlock, tick General → Master controls → **Lock frame**, log out; update and log
  in → every window is locked, including the one whose padlock was open; **Lock frame** reads ticked,
  and unticking it unlocks every window; after `/reload` nothing moves and `schemaVersion` is at least
  14; `/mm get master.locked` answers whether every window is locked; a second, inactive profile with
  Lock frame ticked arrives locked; one with it unticked keeps each window's own lock. Result:
- **INSTALL-9. Upgrade from v15 (minimize keys and the minimap button).** On a build from before v16
  (`schemaVersion` 15 or earlier), hide the minimap button, collapse one window with its minimize
  control, hide the minimize control on a second window (Header → Controls), log out; update and log
  in → the button is still hidden and `/mm get global.minimap.shown` answers `false`;
  `/dump MultiMetersDB.global.minimap` shows `hide = true` (plus `minimapPos` if the button was ever
  dragged) and no `shown` key; the first window is still collapsed; the second still has no minimize
  control and its Header → Controls → **Show minimize** box reads unticked;
  `/dump MultiMetersDB.global.schemaVersion` prints `16`; in `/dump
  MultiMetersDB.profiles.Default.windows` every window's `frame` keys are spelled the US way
  (`minimized`, `showMinimize`; the v16 step renames the two British-spelled keys and drops them), and
  the collapsed one reads `minimized = true`. A window back expanded, or a minimize control back on
  screen, means the v16 step lost the old key. Result:

## SLASH

- **SLASH-1. Banner and help.** `/mm help` → the help index; every line the addon prints starts with
  one cyan `[MM]`, verb names are yellow. A doubled `[MM][MM]`, a line missing the banner, or a green
  line with a trailing colon (AceConsole's printer) means `core/MultiMeters.lua`'s reclaim of
  `NS.Print` broke. Result:
- **SLASH-2. Bare `/mm`.** Type `/mm`, then `/mm` followed only by spaces → each opens the settings
  panel on the **Ka0s Multi Meters** landing page, the same as `/mm config`, and prints nothing.
  Result:
- **SLASH-3. Every verb answers.** Run `/mm help`, `/mm config`, `/mm list`, `/mm version`,
  `/mm get window.frame.width`, `/mm set window.frame.width 520`, `/mm reset window.frame.width`,
  `/mm lock`, `/mm lock off`, `/mm test`, `/mm test on`, `/mm toggle`, `/mm window list`,
  `/mm reset-positions`, `/mm debug`, `/mm debug on`, `/mm debug off`, `/mm diagnostics`,
  `/mm perf help`, `/mm profile`, `/mm export`, then `/multimeters help` and `/mm frobnicate` →
  every verb answers and none errors; `/multimeters` behaves as `/mm`; the unknown verb prints
  `unknown command 'frobnicate'` followed by the index. Result:
- **SLASH-4. Help and landing page agree.** Compare `/mm help` with the settings landing page → the
  same commands with the same descriptions, including `export` and `profile` (both read
  `NS.COMMANDS`; a difference means someone wrote a second list). Result:
- **SLASH-5. Version.** `/mm version` → matches the TOC's `## Version` line. Result:
- **SLASH-6. `set` and `get` target the active window.** With two windows, `/mm set
  window.frame.width 520` → the window the band is on changes and `/mm get window.frame.width` reads
  520; pick the other window in the band and repeat the same command → it now targets the other
  window, with no change to the typed path. `/mm reset window.frame.width` → only that row returns
  to its default. Result:
- **SLASH-7. CLI refusals and clamps.** `/mm set window.columns.2.width 90` → *Setting not found:
  window.columns.2.width* (a column has no path of its own; columns are edited under Windows →
  Columns); `/mm set window.frame.scale 5` → not refused but clamped to the top of the range, echoing
  `window.frame.scale = 2.00x`; `/mm set nonsense.path 1` → *Setting not found: nonsense.path*.
  `/mm set window.data.sortMode bogus` (a value the parser takes and the row's check refuses) → one
  line *Invalid value for window.data.sortMode* and no `window.data.sortMode = …` echo;
  `/mm get window.data.sortMode` still reads `value`. Result:
- **SLASH-8. `/mm list` and hidden rows.** `/mm list` → every setting grouped under the same page
  keys the panel uses, with the column list as `window.columns = N shown`; it includes
  `window.frame.minimized`, which the panel does not draw;
  `/mm set window.frame.minimized true` collapses the window. Result:
- **SLASH-9. `/mm toggle`.** `/mm toggle` → every window flips; `/mm toggle <window name>` (for
  example `/mm toggle Multi Meters #1`) → only that window flips, its name read with case and inner
  spaces kept. Result:
- **SLASH-10. `/mm lock`.** `/mm lock` twice → it toggles; `/mm lock off` → it sets, printing
  *Windows are unlocked — drag them into place.*; `/mm lock on` prints *Windows are locked.* Result:
- **SLASH-11. `/mm window`.** `/mm window list` → one line per window: its name, *Enabled* when it
  is on screen or *Disabled* when hidden, and a count of every column in its list, shown or not
  (`8 Columns` on a fresh window). `/mm window new Raid` → *Window 'Raid' created.*; `/mm window new
  Solo`, then `/mm window copy Raid Solo` → *Copied everything from 'Raid'.* and Solo takes Raid's
  settings (the source is the first word, so a source whose name has a space is copied from Windows
  → General instead); `/mm window delete Solo` → *Window 'Solo' deleted.* with no confirmation (the
  panel's **Delete window** asks first, WIN-34); `/mm window delete Raid` the same. Result:
- **SLASH-12. `/mm config` in combat.** Enter combat (a dummy is fine), type `/mm config`, then a bare
  `/mm` → each refuses with one gray notice; leaving combat does not open the panel (nothing was
  queued). Result:
- **SLASH-13. Minimap button, enabled.** Start unlocked: `/mm lock off` (SLASH-10 ends locked).
  Hover the button → the tooltip ends *Left-click: Open settings* / *Right-click: Options menu*. Left-click → the settings panel opens. Right-click → a menu
  titled *Ka0s Multi Meters* with four checkboxes in order, each ticked to match the current state:
  **Enabled**, **Locked**, **Test mode**, **Show window**. Click **Locked** → chat prints *Windows are
  locked.* and the entry reads ticked on reopen. Click **Test mode** → placeholder rows appear; again
  → they go. Click **Show window** → every window hides (or shows, if none was up), as `/mm toggle`.
  Result:
- **SLASH-14. Minimap button, disabled.** `/mm disable` (or untick **Enabled** in the menu, which
  prints `enabled = false`). Left-click → the panel still opens and nothing prints. Right-click →
  **Enabled** unticked and clickable; **Locked**, **Test mode** and **Show window** grayed, each reading
  *(enable the addon first)*, and not clickable. Tick **Enabled** → the addon comes back, as
  `/mm enable`. Result:

## PANEL

The Windows page is one page per window: the Active window band on top, the nav rail on the left
(General · Frame · Header · Bars · Tooltip · Visibility · Columns), and the entry's tab strip to its
right. Open the panel with `/mm config`.

- **PANEL-1. The Settings tree.** Settings → AddOns → Ka0s Multi Meters → the tree reads General ·
  Windows · Profiles, and nothing else: no Frame, Header, Bars, Tooltip, Visibility or Columns
  entries, nested or not. Result:
- **PANEL-2. Windows page layout.** Open Windows → the band spans the top; the rail is on the left
  with its seven entries and the page opens on General; the rail's top edge is level with the top of
  the tab art (the tab itself, not the space above it). Result:
- **PANEL-3. Only the controls scroll.** Rail → Bars, scroll to the bottom of the Bar tab → only the
  controls move; the band, the rail and the tab strip stay put. Result:
- **PANEL-4. Each entry remembers its tab.** Frame → Size and position, then Bars, then Frame → Frame
  opens on Size and position. Columns → Header background, then General, then Columns → Columns opens
  on Header background. Result:
- **PANEL-5. The band switches windows and keeps the tab.** With two windows, on Bars → Border pick
  the other window in the band → still on Bars → Border, now showing the other window's values; every
  other entry shows the newly picked window's values on the next visit; pick the first window again →
  the same. Result:
- **PANEL-6. First show draws correctly.** `/reload`, then open each page for the first time → every
  widget correctly sized, none squashed into a zero-width column, every widget in the same skin as
  your other AceGUI addons. With a skinning addon (ElvUI / AddOnSkins) loaded, the skin also reaches
  the band's window dropdown and the tab strip (both built on first show, like the Defaults button);
  a piece left unskinned is the lazy-build rule failing for it
  ([settings-panel.md](settings-panel.md#eager-category-lazy-body-lazy-defaults-button)). Result:
- **PANEL-7. Changes apply at once.** On every page and every Windows entry, move one control of each
  type present (checkbox, slider, dropdown, color, edit box) → the window changes immediately, with no
  `/reload`. Result:
- **PANEL-8. Tab strips fit one row.** `/reload`, open Windows as the first page of the session, then
  visit every entry → from the first frame, the tabs sit in one row to the right of the rail, none
  under the rail and none stacked one per row. At default UI scale no strip wraps: Frame's four, Bars'
  six, Tooltip's six, Header's four, Visibility's three, Columns' three (a wrap is `placeTabs`
  arithmetic, not a copy problem). Result:
- **PANEL-9. Clicking the current tab.** Click the tab you are already on → nothing at all: no
  flicker, no repaint, no message. Result:
- **PANEL-10. Rail tooltips and look.** Hover each rail entry → a tooltip saying what the entry holds;
  the rail reads as a tree pane (gold entries, the selected one white on a blue bar), visibly different
  from the gold tabs. Result:
- **PANEL-11. Tabs survive reuse.** On every page that draws a strip, cycle every tab three times,
  ending on the first; do Columns too, which drives the strip directly rather than through the schema
  renderer → on every pass each tab carries its own label, the selected tab is the one you pressed,
  the body belongs to that tab, and the strip's height does not change. A carried-over label, a
  highlight on the wrong tab or a moving height is the tab pool handing back a half-dressed frame
  (invisible to every headless check). No Lua error. Result:
- **PANEL-12. Tab art.** Look at any strip → a flat backing with the active tab drawn darker. Record
  whether it reads as tabs or wants Blizzard's tab atlas; changing it is a
  `LibKa0s/OptionsWidgets.lua` change, not a Multi Meters one. Result:
- **PANEL-13. Entry shapes.** Visit each entry → the tabs read, in order, each holding the rows named:
  **Frame**: General (Lock window, Keep on screen, then the four *(all surfaces)* rows), Size and
  position (Width, Height, Scale, Opacity, Frame strata, Padding), Background and border (a
  *Background* heading with Background color and Background color mode, then a *Border* heading with
  Border style, Border thickness, Border color and Border color mode), Row (Maximum rows, Row height,
  Row spacing, Growth direction, Always show yourself, Highlight yourself, Highlight on mouseover,
  Alternating background); it opens on General, where *Font outline (all surfaces)* shows **None**
  on a fresh profile. **Bars**: Bar, Background, Border, Text content, Text style, Icons; none of the
  Row rows above appears on Bars (their paths are `window.rows.*`, and `/mm get window.rows.height`
  answers). **Header**: Title bar (Show title bar, Alignment, Header height, Header background, then
  the divider rows), Title text (the face the window's name is drawn in: Font, Font size, Text color,
  Text color mode, Font outline, Text shadow; the name itself is typed on Windows → General), Controls,
  Button style (an *Icon* heading with Reveal controls on hover beside Control size; a *Color* heading
  with Control color and Control color mode on one line and Control hover color and Control hover
  color mode on the next; an *Opacity* heading with Control opacity beside Control hover opacity).
  **Tooltip**: General (Tooltip anchor, Tooltip scale, Horizontal offset, Vertical offset, Hide
  tooltips in combat), Bar, Bar background, Bar border, Text, Contents (Show spell breakdown, Maximum
  spells, Show targets, Maximum targets, Name the killer, Name the killing blow, Summarize on the name).
  **Visibility**: Where to show this window (the seven contexts: Dungeons, Raids, Arenas,
  Battlegrounds, Delves, Scenarios, Open world), When to hide this window (Hide when solo, Hide in
  vehicles, Hide when mounted, Hide when skyriding, Hide on flight paths, Hide in player housing, Hide
  in pet battles, Hide while dead), Combat (Hide in combat, Hide out of combat). Each tab label appears
  once, and no row sits on a tab other than the one named here. Frame has no Header controls tab, no
  Reset position button, no Show resize grip and no Minimized checkbox; Header has no Column headers
  tab. Stored paths did not move with the rows: `/mm get window.text.size` and `/mm get
  window.frame.closeButton` still answer (the close row keeps its older key; there is no
  `showClose`). Result:
- **PANEL-14. The Controls tab reads like the strip.** Header → Controls → each checkbox draws its
  control's own icon between the tick box and the words, and the rows run in the strip's left-to-right
  order: the segment line (no icon), export, reset, segment picker, settings, lock, minimize, close.
  Each icon matches the header's; a missing icon means `NS.Icon` answered nil for that art name.
  Result:
- **PANEL-15. The General page.** Open General → it is first in the tree, draws no window band, and
  its strip reads **[ Master controls ][ Behavior ][ Statistic colors ]**. Master controls holds
  Enable Multi Meters, General visibility, Master scale, Master alpha, Lock frame, Debug console,
  Minimap button and Test mode (the last two paired on one line below Lock frame / Debug console),
  then the **Reset position** / **Reset all settings** pair and one sentence saying what each reaches,
  with no paragraph under it. No second Test mode, Debug console or *Debug* heading anywhere; no tab
  named General, Data, Maintenance or Export; no Reset meter data button on this or any page. Result:
- **PANEL-16. Master scale and alpha.** With a window at Frame → Scale 0.8, set General → **Master
  scale** to 0.5 → the window draws at 0.4; back to 1.0 → every window is exactly the size it was set
  to. **Master alpha** behaves the same way over each window's opacity. Result:
- **PANEL-17. Behavior is addon-wide.** With two windows, change General → Behavior → **Merge pets
  into their owner** and **Refresh interval** → every window follows, not only the selected one.
  Result:
- **PANEL-18. The Minimap button toggle.** Untick General → **Minimap button** → the button leaves
  the minimap immediately; tick it → it returns at the angle it was dragged to, and
  `/mm get global.minimap.shown` reads `true`. Switch profiles → the button neither moves nor
  reappears. General → **Reset all settings** → it stays hidden if it was hidden. With Master
  controls open, `/mm set global.minimap.shown false` → the button hides and the **Minimap button** box
  unticks without a click; `/reload` → still hidden; `/mm set global.minimap.shown true` → it returns.
  Result:
- **PANEL-19. The statistic palette.** General → Statistic colors → one swatch per statistic in the
  catalog's colors, with a note saying where they are worn (check the note is true). Change Damage's
  swatch → all four palette surfaces move together: Bars → Bar color mode Per-statistic, Bars → Text
  style color mode Per-statistic, the Columns header text and background modes, and the Damage line of
  a name tooltip (which wears the palette always). General's **Defaults** → the shipped colors return.
  Result:
- **PANEL-20. The five text controls, four surfaces.** Bars → Text style, Header → Title text, Columns
  → Header text and Tooltip → Text each carry a font picker, font outline, text shadow, text color and
  a **Text color mode**: Class / Per-statistic / Custom on Bars, Columns and Tooltip; Class / Custom
  only on Header → Title text (no Per-statistic, as in WIN-20). Walk each mode the surface offers on
  each page → only that surface changes (the cells; the title and session line; the "Player | Damage
  | Healing" strip; a hovered tooltip). Per-statistic means: each cell its own column's color, the
  tooltip the hovered column's, and each column label its own column's. Columns → Header background
  has a Background color mode of Class / Per-statistic / Custom, where
  Per-statistic paints one rectangle per label; Header → Title bar's background is a plain color with
  no mode. The configured opacity survives every mode (a tint, not a slab). A control that moves the
  wrong surface means two groups share a key. Result:
- **PANEL-21. Class color on each surface.** Set Text color mode to Class on each page → Bars → Text
  style colors each row by its own class (a mixed grid is multi-colored); Tooltip → Text takes the
  hovered player's class (hover two classes); Header → Title text and Columns → Header text take your
  own class. With Bars → Text style → **Text opacity** at 50% and mode Class → the text stays
  half-transparent. Result:
- **PANEL-22. The four meta rows.** Frame → General carries Color mode, Bar texture, Font and Font
  outline, each marked *(all surfaces)*. Set **Color mode (all surfaces)** to Per-statistic → the six
  surface dropdowns follow (Bars → Bar, Bars → Background, Columns → Header text, Columns → Header
  background, Tooltip → Bar, Tooltip → Bar background); the three text modes (Bars → Text style,
  Tooltip → Text, Header → Title text) do not move. Set one of the six back to Custom → only that one
  changes. The bar texture reaches the grid and the tooltip; the font and outline reach the cells,
  both header strips and the tooltip. Result:
- **PANEL-23. Media pickers see late-registered media.** Load a media pack that registers fonts,
  borders and bar textures (SharedMedia_MyMedia or similar), then open all eleven pickers: Frame →
  General's Font and Bar texture, Frame → Border style, Bars → Texture and Border style, Tooltip → Bar
  texture and Bar border style, and the font picker on Bars → Text style, Header → Title text, Columns
  → Header text and Tooltip → Text → each list holds a name that could only have come from the pack. A
  plausible-looking stock list is not a pass: nine of these rows are built by LibKa0s-Options' schema
  composers, and a composer holding a list built before the pack registered fails silently. In each
  font picker every name is drawn in its own face, not all in the default one. Result:
- **PANEL-24. The Border dropdown is flush, whoever loaded last.** Open Frame → Border style and
  Tooltip → Bar border style → the closed control's left edge is flush with the controls stacked with
  it (no ~42px gap), and opening it still draws a border preview per row on hover. Then enable KickCD,
  PanelMaster, AbsorbTracker and ConsumableMaster alongside, walk every addon's Border dropdown, change
  the load order (disable and re-enable addons, or rename a folder), `/reload` and walk them again →
  all five addons look the same on both passes (`LSM30_Border` is one process-wide AceGUI slot, now
  registered once by LibKa0s). A dropdown that differs, or changes with load order, is the finding. No
  Lua error. Result:
- **PANEL-25. Which pages have Defaults.** Open each page → General and Windows carry a **Defaults**
  button in the page header and Profiles does not. On Windows the one button acts on the entry on
  screen: Frame, Header, Bars, Tooltip, Visibility, Columns, or General, where it restores nothing
  (PANEL-27). Result:
- **PANEL-26. Defaults reaches the whole entry.** On each of Frame, Header, Bars, Tooltip, Visibility
  and Columns, change a value on a tab that is not showing, switch tabs, press **Defaults**, switch
  back → your change is gone too. On Columns, stay on the block editor tab, change a value on Header
  text or Header background without visiting it, press Defaults → it is reset as well. Result:
- **PANEL-27. Defaults stays on its entry and window.** With two windows and the first active: change
  Frame → Size and position → Width and Header → Title bar → Header height; select Frame and press
  Defaults → only the Frame rows reset, on the active window only (Header height keeps your value; the
  other window is unchanged). With `/mm debug on`, the press logs one `[Set] reset <page>: N rows` line
  with no `[Set] <path> = …` lines under it, and a second press logs `0 rows`. With Windows → General
  selected, click Defaults → nothing changes and one line says General has no settings to restore;
  the window keeps its name. Result:
- **PANEL-28. Panel and CLI stay in step.** With the Frame entry open, `/mm set window.frame.width
  640` → the Width slider moves to 640 without reopening the page; move the slider → `/mm get
  window.frame.width` reports the new value. Result:
- **PANEL-29. An open page locks in combat.** Open Windows on a tabbed entry (then repeat with Columns
  open), enter combat (a dummy is fine) → a gray cover reading *Settings are locked during combat.*
  falls over the whole page, band, rail and tab strip included; one gray chat line says settings are
  locked; a rail entry, a tab, a widget, a block glyph, a drag handle and the Defaults button all do
  nothing; the Settings window stays open; no Lua error. Leave combat → the cover lifts on its own and
  the page shows current values on the entry you were on. Result:
- **PANEL-30. Every page mid-combat from the Blizzard sidebar.** Close the Settings window, enter
  combat, open Settings → AddOns → Ka0s Multi Meters from the Blizzard sidebar, walk General, Windows
  and Profiles → each shows the gray cover with nothing drawn under it (on Windows the band, rail and
  strip too); the Settings window stays open; no `ADDON_ACTION_BLOCKED` and no `C stack overflow`;
  exactly one gray *settings are locked during combat* line for the whole walk. Still in combat, with
  the page open, click an action-bar button → it fires, with no *Interface action failed because of an
  AddOn*. After combat the page on screen draws without a click. "Two pages covered and one rendering"
  is the failure. Result:
- **PANEL-31. The Windows → General entry.** Rename the window in the name box and press Enter, click
  **New window**, **Duplicate window**, then **Delete window** and confirm; then under *Copy settings
  from* pick the other window as Source window and Bars under Settings to copy, and click **Copy** → the
  entry shows one tab, General; each act works, and the band follows a new or duplicated window; the
  copy changes only the active window's Bars settings. Result:
- **PANEL-32. Columns: drag by the handle.** Out of combat, Windows → Columns → hover a block's handle
  → it turns gold and says *Drag to reorder*. Drag a block from the bottom of the ticked group to the
  top by its handle → the window's columns reorder at once and the page shows the new order. The
  handle is the full-height strip down the block's left edge; pressing anywhere else starts no drag.
  If the drag does nothing, `/mm debug on` and retry: `[Blocks] grab N at y=…` on press and
  `[Blocks] drop N -> M (R rows)` on release (no `grab`: the press missed the handle; `grab` without
  `drop`: no release path fired; `0 rows`: the cursor read did not move). Result:
- **PANEL-33. Columns: drag feedback.** During a drag → a copy of the block follows the cursor,
  including past the top and bottom of the list; the source row fades; a gold insertion line marks
  the landing spot; the list never reflows under the pointer. Result:
- **PANEL-34. Columns: tick and untick.** Untick a middle block → it drops to the top of the unticked
  group, just below the rule, and the window loses that column. Re-tick it → it lands at the end of the
  ticked group and reappears as the rightmost column. Result:
- **PANEL-35. Columns: the rule clamps a drag.** An unticked block has no handle. Drag a ticked block
  toward the unticked group → the insertion line stops at the rule and the block stays ticked (a
  clamped drop writes nothing, so the line stopping is the only feedback). Result:
- **PANEL-36. Columns: the last column stays.** Untick down to one column, then untick that one →
  refused with *A window must keep at least one column.* Result:
- **PANEL-37. Columns: one label, one glyph.** After each drag, tick and untick → every block shows one
  name and one glyph (no "DamageDeaths" overprint, no tick crossed by a cross), and clicking a glyph
  toggles the statistic you clicked. Result:
- **PANEL-38. Columns: drag twice.** Drag, drop, then drag again → the second drag works like the
  first and no carried copy is left floating over the list. Result:
- **PANEL-39. Columns: Defaults.** Reorder and untick, then press Columns' **Defaults** → the shipped
  statistics come back, ticked and in shipped order, along with the header text and background rows;
  with `/mm debug on` the console logs `[Set] reset columns: N rows`, the column list counted as one
  row. Result:
- **PANEL-40. Columns: no leftovers.** With `/mm debug on`, after every drag and every Defaults → no row
  shows two names stacked and no drag handle appears anywhere that is not a block (not by the intro
  text, not on the scrollbar). Each repaint prints, in this order, `[Blocks] released N handles, M
  boxes` and `[Blocks] released N blocks` for the list going away (skipped when there was none),
  `[Columns] paint window=N`, then `[Blocks] painted N rows, M draggable, K boxed, boundary=…` for the
  new one. The blocks and handles released always equal the rows and draggable handles the repaint
  before it painted. Result:
- **PANEL-41. Columns: glyph tooltips.** Hover a tick and a cross → each says what a click will do:
  *Click to hide this column* / *Click to show this column*. Result:
- **PANEL-42. Columns: tabs and leaving mid-drag.** The strip reads Columns, Header text, Header
  background, and the page opens on Columns; Header text shows only the header-font rows and Header
  background only its color pair, with no section heading of their own. Drag a block, drop it, and
  click Header text at once → no handle or block survives onto that tab, and with `/mm debug` the
  `[Blocks] released N blocks` line comes before its repaint. Then start a drag and, holding the
  mouse, click Frame on the rail; release → Frame shows no drag handle on any row; back on Columns
  every block is there in a readable order and dragging still works. Result:
- **PANEL-43. Columns: the library drag.** Drag a block from the middle of the ticked group to a lower
  slot → the insertion line is in the list's own color and the order changes on the page and in the
  window. Switch the band to another window and drag in its Columns → it draws its own line, not a
  leftover. After the drop, idle frame time with the page open is what it was before the drag (no row
  `OnUpdate` left armed). Result:
- **PANEL-44. Columns: a drag held into combat.** Out of combat start a handle drag, pull a dummy while
  holding it, drop → refused with *Columns cannot be changed during combat.* and the columns do not
  change. No Lua error. Result:
- **PANEL-45. A color drag is throttled.** With `/mm debug on` and the console open, set Bars → Bar →
  Bar color mode to **Custom color**, click **Bar color** and drag around the picker for about three seconds →
  the window's bars recolor while you drag, not only on release, with no per-frame stutter; the
  console shows `[Set] window.bars.customColor = …` lines at about twenty a second, not one per frame.
  **Cancel** → the color from before the drag returns at once. Result:
- **PANEL-46. Switching windows does not leak.** With two windows, open Windows, then `/run
  collectgarbage() print(collectgarbage("count"))`. Switch the band between the two windows 30
  times and run the same line; repeat the 30 switches and read it again → the figure does not climb
  with each round of 30 (a few KB of noise is fine). `/framestack` over the band → exactly one
  Dropdown under it. No `SetParent` or `Release` error. Result:
- **PANEL-47. The panel still opens once the descriptor names the addon folder.** On LibKa0s v1.67.0
  the Options descriptor passes `addonName` (LibKa0s#42). Log in with `/mm debug on`, open `/mm config`
  and visit General, every Windows tab and Profiles → each page renders as before, with no Lua error on
  load or on open, and no `[Cfg] help art:` line in the console (no list here carries help marks, so the
  change is latent). Result:

## PROFILE

- **PROFILE-1. The Profiles page draws.** Open another addon's options page, then Ka0s Multi Meters →
  Profiles → the AceDBOptions controls render (current profile, New, Copy From, Delete, Reset
  Profile), never a blank page under the header. Result:
- **PROFILE-2. A fresh character shares `Default`.** Log in on a character that has never loaded the
  addon → Profiles shows it on the shared **Default** profile, not a per-character one. Result:
- **PROFILE-3. Switching on the page.** Create "Test", switch to it, change several settings and add a
  window, switch back to Default → every window rebuilds at once: the old profile's windows are gone,
  the new profile's are drawn, positioned and populated; no stale window is left; the settings panel
  and the band list the new profile's windows; profiles with different window counts work in both
  directions; no Lua error. Result:
- **PROFILE-4. Copy From.** On Default, Copy From "Test" → Test's windows come across; editing one
  profile's window afterwards does not touch the other's. Result:
- **PROFILE-5. Reset starts the profile over.** With two or more windows, each renamed and restyled
  (font size, width, a column added or removed), pick one in the band, then General → **Reset all
  settings** and accept → exactly one window, **Multi Meters #1**, at screen center in shipped
  defaults, with the six shipped columns in catalog order; the extras are deleted, not restyled. The
  popup warned about the deletion first. Profiles → **Reset Profile** gives the identical result.
  Result:
- **PROFILE-6. `/mm resetall` asks first.** With two windows and `/mm debug on`, type `/mm resetall`
  → the popup the General page's **Reset all settings** button opens (*Reset this profile to the addon
  defaults? …*, with **Yes** and **No**) appears, nothing has changed, and showing it logged no `[Set]`
  line. Click **No** (or press Escape) → both windows unchanged and no `[Set]` line. Type it again and
  click **Yes** → one fresh window, as PROFILE-5, and exactly one `[Set]` line, `[Set] reset profile
  '<name>' to defaults` (no `[Set] reset all` line). The rebuild's own `[Roster]`, `[Aggregator]` and
  `[Visibility]` lines beside it are expected. Result:
- **PROFILE-7. A reset leaves other profiles alone.** Create a second profile, switch back, reset (by
  each of the three routes) → the profile list is unchanged, you are still on the profile you were
  on, and the second profile's windows and settings are untouched. Result:
- **PROFILE-8. Export choices follow the profile.** Set different export Channel and Lines on two
  profiles, switch between them → the modal's choices switch with the profile. Result:
- **PROFILE-9. The page stays fresh after a switch made elsewhere.** Open Profiles, page away to
  General, type `/mm resetall` and accept; come back to Profiles → the profile list and the scope
  dropdowns are redrawn for the profile you are on. Repeat, switching with `/mm profile <name>` while
  Profiles is hidden, and again while it is on screen → it shows the new current profile each time
  (the `PROFILE_CHANGED` listener reaching `H.RefreshPanel`). Result:
- **PROFILE-10. `/mm profile` lists.** With profiles Default, "raid" and "Test", type `/mm profile` →
  a header line `Profiles`, then one line per profile sorted without regard to case (Default, raid,
  Test), the current one followed by `(current)`, then the hint `/mm profile <name> switches profile`.
  Every line carries the `[MM]` banner and none ends in a colon. Result:
- **PROFILE-11. `/mm profile <name>` switches.** With `/mm debug on` and the console open, on Default
  type `/mm profile Test` → chat prints `Switched to profile 'Test'.`; every window rebuilds for Test,
  as in PROFILE-3; the console shows one `[Profile] switched to 'Test'` line; an open Profiles page
  shows Test as current. Result:
- **PROFILE-12. Naming the current profile.** On Test, `/mm profile Test` → `Already on profile
  'Test'.`, no `[Profile]` line, and no window rebuilds. Result:
- **PROFILE-13. An unknown name is refused.** `/mm profile Nosuch` → `No profile named 'Nosuch'.`
  then the list; nothing switches, and the Profiles page shows no new profile. `/mm profile test`
  (wrong case) → `No profile named 'test'.`, `Did you mean 'Test'?`, then the list; still no switch.
  Result:
- **PROFILE-14. Quotes and spaces.** Create "Raid Team" on the Profiles page (creating it switches to
  it), then `/mm profile Default`. `/mm profile "Raid Team"` → `Switched to profile 'Raid Team'.`;
  `/mm profile Default`, then `/mm profile 'Raid Team'` → switches again; `/mm profile Default`, then
  `/mm profile Raid Team` → switches again (quotes stripped, inner space and case kept). Result:
- **PROFILE-15. The verb answers while disabled.** Make "Off" a profile with General → Enable Multi
  Meters unticked and switch to it (the addon stands down). `/mm profile` → the list, not the disabled
  refusal. `/mm profile Default` → switches, and since Default is enabled the addon stands back up:
  windows return and feature verbs work. Result:
- **PROFILE-16. Refused in combat.** Enter combat (a dummy is fine), `/mm profile Test` → `Can't switch
  profiles in combat.`; no switch, no `[Profile]` line, nothing rebuilds. A bare `/mm profile` in
  combat still lists. Result:
- **PROFILE-17. The verb in help.** `/mm help` and the landing page → a `profile` row reading *List
  profiles, or switch to one: profile <name>*, right after the thirteen reserved verbs. Result:

## STATE

- **STATE-1. Disabled stands the addon down.** `/mm disable` (or `/mm set enabled false`, or untick
  General → Enable Multi Meters) → every window hidden at once, nothing refreshes. Then run
  `/mm toggle`, `/mm lock`, `/mm test`, `/mm window new Raid`, `/mm reset-positions` and `/mm export`
  → each prints one line naming `/mm enable` and does nothing: `/mm window list` afterwards shows no
  `Raid`, and nothing moves on screen (a verb that printed the refusal and then acted is the failure).
  `/mm`, `/mm help`, `/mm config` (the panel opens), `/mm version`, `/mm list`, `/mm get enabled`,
  `/mm set master.scale 1.5`, `/mm reset master.scale`, `/mm resetall`, `/mm debug`, `/mm diagnostics`,
  `/mm perf help` and `/mm profile` still answer. `/mm enable` → the addon returns and the six feature
  verbs work at once ([disabled-state.md](disabled-state.md)). Result:
- **STATE-2. Help unchanged while disabled.** While disabled, `/mm help` and the landing page → every
  verb keeps its row, the refused ones included. Result:
- **STATE-3. Nothing comes back while disabled.** `/mm disable`, then on General → Master controls
  tick and untick **Test mode** → no window appears. Result:
- **STATE-4. A window made while disabled comes up live.** `/mm disable`, create a window from
  Windows → General, `/mm enable` → the new window refreshes like the others (its rows move in Test
  mode or in a fight). Result:
- **STATE-5. A perf capture suspends the windows.** `/mm perf start`, then `/mm perf measure b` (the
  suspended arm, which stands the windows down at once). During it: type `/mm toggle` → no window
  appears and chat prints *Windows are suspended while a performance capture runs.*; right-click the
  minimap button → **Enabled** still ticked and nothing grayed; click **Show window** → the same line
  and no window; left-click → the panel still opens. `/mm perf cancel` afterwards brings the windows
  back. Result:
- **STATE-6. Lock and Test mode are independent.** With Test mode off, `/mm lock off` → a real
  (possibly empty) grid, no placeholder rows. `/mm test on` with the window locked → placeholders.
  Unticking Test mode on an unlocked window clears the placeholders. Result:
- **STATE-7. Lock frame is every window's lock.** Two windows, panel on General → Master controls:
  `/mm lock on` → **Lock frame** reads ticked. Untick it → every window unlocks (drags by its title bar,
  shows its grip). Tick it → every window locks. Unlock one window from its header padlock → the others
  stay locked and **Lock frame** reads unticked until that window is locked again. Result:
- **STATE-8. The Test mode box follows the verb.** With General → Master controls open, `/mm test` on
  and off → the Test mode box ticks and unticks without a click. Result:
- **STATE-9. Test mode rows.** `/mm test` → chat prints *test mode on — showing placeholder rows*
  and ten Ka0s-named placeholder members appear, with plausible numbers that do not change between
  refreshes; `/mm test` again → *test mode off*. Result:
- **STATE-10. Combat ends Test mode.** Test mode on, pull a dummy → one line *Test mode off — combat
  started*; the placeholders give way to the real (possibly empty) grid and the box unticks; the window
  stays up, or hides if its Visibility → Combat → hide in combat is ticked. Leaving combat does not turn
  Test mode back on. (`/mm test off` by hand always leaves the window on screen.) Result:
- **STATE-11. Test mode cannot start in combat.** With Test mode off, enter combat (a dummy is fine),
  type `/mm test`, then click the minimap menu's **Test mode** → each prints one line *Cannot start test
  mode during combat* and no placeholder rows appear. (The General page's Test mode box is under the
  combat cover then, PANEL-29, so it is not a route.) Leave combat → General → Master controls → Test
  mode reads unticked. Result:

## WIN

- **WIN-1. Seven header controls, our own art.** Hover the title bar → seven controls, right to left:
  close, minimize, lock, settings, segment, reset, export, each a white glyph from this addon's art
  (close from `libs/LibKa0s/media/icons/close.tga`, export from `.../export.tga`) at the same size,
  weight, center line and color. A plain letter (`*`, `#`, `>`) means the art and the atlas both
  failed; a thin gray multiplication sign at the close end is LibKa0s's own close button. Result:
- **WIN-2. Icons sit inside their slots.** Each icon is drawn at 72% of **Control size**, with air
  between neighbors → icons touching means the inset was lost. Result:
- **WIN-3. A hidden control closes the gap.** Header → Controls, hide the lock → everything to its left
  moves right by exactly one slot and nothing to its right moves; no hole. Result:
- **WIN-4. The title never runs under a control.** At every **Control size** from 10 to 32 and with
  any combination hidden → the title stays clear of the strip. Result:
- **WIN-5. The strip is centered.** The strip, the window name and the session line sit on one line,
  centered in the title bar, with equal gaps above the row and below it to the divider. Change Header
  → Title bar → **Header height**, Header → Title text → **Font size** and Header → Button style →
  **Control size** → all three stay on the shared line. Result:
- **WIN-6. Exactly one control reveals.** Sweep the pointer along the strip, on an unlocked and on a
  locked window → only the control under the pointer comes to full alpha and turns gold, following
  the pointer control by control with no flicker in the gaps; none stays bright after the pointer
  leaves; the set never lights up as a whole when crossing the title bar. Result:
- **WIN-7. Control colors.** Header → Button style → change **Control color** (white by default) and
  **Control hover color** (gold) → the strip follows at once, at rest and under the pointer. Result:
- **WIN-8. Each color has its own mode.** Set **Control color mode** to Class color → the resting strip
  takes your class and the hover color is unchanged. Set only **Control hover color mode** to Class
  color → the resting color is unchanged and the hovered control takes your class. Both at Class is
  allowed. Result:
- **WIN-9. Control opacities and the reveal.** An untouched window shows **Control opacity** 25% and
  **Control hover opacity** 100%; move each alone → only its end changes. Set Control opacity near zero
  and turn **Reveal controls on hover** off → the strip shows at the hover value, not invisible, and
  the hover color still marks the control under the pointer. Result:
- **WIN-10. The lock icon matches its neighbors.** Unlock a window → the padlock has the same
  brightness and color as the other six, locked or open; only the glyph changes. Result:
- **WIN-11. The export control's tooltip.** Hover the export control → *Export a segment to CSV or to
  chat*; it is the only control in the strip with a tooltip. Result:
- **WIN-12. Title bar off takes the strip.** Header → Title bar, turn the title bar off → the whole
  strip goes, export included; turn it on → all seven return. Result:
- **WIN-13. Minimize collapses to the title bar.** Click minimize → the plus/minus flips and the column
  headers, rows, *Waiting for combat data...* notice and resize grip all go (anything still drawn is
  parented to the frame, not the body). Result:
- **WIN-14. A collapsed window stops updating.** Collapse a window, pull → it does not tick. Result:
- **WIN-15. Expanding restores the height.** Collapse, `/reload` → it comes back collapsed; expand →
  it returns to the exact height you set, not a default. Result:
- **WIN-16. The reset control asks first.** Click the header's reset control → a confirmation opens
  in the middle of the screen asking *Clear every recorded combat session?* with **Yes** and **No**;
  nothing is cleared yet; **No** leaves the sessions intact. (The warning that it also wipes the
  game's own meter data is on the **Show reset** row's tooltip under Header → Controls, not in the
  dialog. A second popup opening on top can pull it up the stack; that is accepted.) Result:
- **WIN-17. Reset accepted.** Click reset and accept → Blizzard's own meter window empties too
  (`C_DamageMeter.ResetAllCombatSessions` is account-wide), every open drill-down closes, and the
  window shows *Waiting for combat data...* Result:
- **WIN-18. The divider.** Header → Title bar → **Show divider** ships on. Turn it off → the hairline
  under the title strip goes and nothing else moves (title, session line and controls stay). **Divider
  thickness** grows it downward. **Divider color mode** ships as Ka0s skin (the line as the shared
  skin painted it); switch to Class color → your class; to Custom color → the swatch. With a low
  swatch opacity, switching between Custom and Class leaves the opacity alone. There is no
  per-statistic mode. Result:
- **WIN-19. The header background stops at the title bar.** Header → Title bar → Header background to
  something loud and Columns → Header background → Background color to something else → two distinct
  bands, the second starting where the first ends. Result:
- **WIN-20. The window name takes the header's color.** Header → Title text → **Text color** → the
  window name follows it, with its font, size, outline and shadow; set **Text color mode** to Class
  color → the title takes your class, the same as the session line beside it. With a low swatch
  opacity, switching modes leaves the opacity alone. No per-statistic mode. The Settings window's
  footer Defaults also resets this tab. Result:
- **WIN-21. Scale scales the whole window.** Frame → Scale to 0.5, then 2.0 → the window's outline
  grows and shrinks with its contents (a box that keeps its size while the grid shrinks into a corner
  means the scale missed the anchor). Result:
- **WIN-22. No border means no border.** Frame → Border style **None** and Border thickness **0** → no
  edge of any kind (a surviving 1px line is the skin's `frame.innerBorder`). None at a non-zero
  thickness → also no edge, not the Ka0s edge. Result:
- **WIN-24. The resize grip follows the lock.** Unlocked → the bottom-right grip shows and resizes the
  window (persistence across `/reload` is INSTALL-4); locked → no grip. There is no Show resize grip
  setting. The grip is LibKa0s-Core's since MultiMeters#58: 16 px (it was 12) and one pixel inside
  the corner; it must not cover the last row's value at the minimum size. Result:
- **WIN-25. The lock governs the title-bar drag, not the cells.** `/mm lock off` (or untick Frame →
  General → Lock window), drag the window by its title bar → it moves as one object (persistence
  across `/reload` is INSTALL-4). `/mm lock on`, drag the title bar again → it does not move. Locked
  and unlocked alike, hovering a cell shows its tooltip. Result:
- **WIN-26. Resetting positions.** With one window, `/mm reset-positions` → *Moved 1 window back to
  the center.* Move two windows off center, `/mm reset-positions` → every window re-centers and chat
  prints *Moved 2 windows back to the center.* (a raw locale key, or *1 windows*, is the failure).
  General → Master controls → **Reset position** → only the window the band is on re-centers. Result:
- **WIN-27. A new window.** Windows → General → **New window** → the band follows it and it is named
  **Multi Meters #2** (the count of windows, not the id). Result:
- **WIN-28. Windows are independent.** Give two windows different width, bar color, column set and sort
  column → each draws its own width, color, columns and row order; changing window 2's bar color leaves
  window 1 alone (a shared sub-table means `deepcopy` was bypassed). Result:
- **WIN-29. Copy settings: one group.** Windows → General → Copy settings from, source window 1, group
  **Bars**, Copy → the target's bar settings match and its width, columns, position and visibility
  rules are untouched. Result:
- **WIN-30. Copy settings: Everything.** Repeat with **Everything** → all ten groups copy, but not the
  target's id, name or position (it does not land on top of its source). Result:
- **WIN-31. A copy is one redraw and one line.** With `/mm debug on` and the console open, copy settings
  → the target redraws once and the console shows one `[Set] copy from '<A>' to '<B>': N rows` line,
  never a line per row. Result:
- **WIN-32. Duplicate.** **Duplicate window** → the new window is offset 24px down and right. Result:
- **WIN-33. The band is keyed by id.** Name two windows "Raid" → each is still selectable in the band.
  Result:
- **WIN-34. Delete.** **Delete window** → it confirms first; on the last window → refused with *The
  last window cannot be deleted.* Result:
- **WIN-35. Deleting the selected window.** Delete the window the band is on → every Windows entry
  re-renders against the first surviving window, with no empty widgets. Result:
- **WIN-36. Edits on another window stay there.** With the band on window 1, resize window 2 by its grip
  and click one of its column headers → the size and sort land on window 2 only (its Frame entry shows
  the new width once the band moves to it) and the band stays on window 1. Result:
- **WIN-37. The resize grip is the library's and still sizes the window.** Unlock window 1 and drag the
  bottom-right grip with the left button → it shows a pressed state while held, the window resizes,
  stops at the grid's minimum, and keeps its new size across `/reload` (INSTALL-4). With `/mm debug on`,
  one drag writes one `[Set] window.frame.width` and one `[Set] window.frame.height` line, on release,
  not one per frame. A right-click on the grip does nothing. Set Frame strata to **HIGH**, then
  **DIALOG** → the grip still draws and takes the mouse above the window's backdrop. Set Opacity to 0.3
  → the grip fades with the window. Result:
- **WIN-38. The grip survives a rule-driven hide.** With window 1 unlocked and a visibility rule that
  hides it (for example hide out of instance, or a context rule toggled), let the rule hide the window
  and then show it again → the grip is back and resizes. Lock the window → no grip. Minimize it, then
  `/mm lock off` → no grip over the collapsed window. Expand it → the grip is back. Result:

## VIS

Every rule ships **off**, so each hide rule has to be switched on for its check.

- **VIS-1. A fresh profile shows everywhere.** On a fresh profile, visit solo open world, grouped open
  world, a five-player dungeon, a raid, a battleground, a delve and a vehicle → the window is visible
  in every one (all seven contexts on, all ten rules off). Result:
- **VIS-2. Open world.** Turn **Open world** off → it hides outdoors and still shows in a dungeon.
  Result:
- **VIS-3. Hide when solo.** Turn **Hide when solo** on, drop group → it hides; group up → it returns.
  Result:
- **VIS-4. Delves and scenarios.** In a delve → shown, and `/mm diagnostics` reports `type=scenario
  resolved=delve`; turn **Delves** off → it hides while **Scenarios** stays on. In an ordinary scenario
  or follower dungeon → shown, reported as `resolved=scenario`. A window hiding in both means the delve
  probe is not firing. Result:
- **VIS-5. Vehicles.** Tick Visibility → When to hide this window → **Hide in vehicles**, then enter a
  vehicle (a quest turret or a vehicle encounter) → the window hides at once; leave → it shows at once,
  on the vehicle event itself, not at the next zone change. Result:
- **VIS-6. Housing, flight paths, pet battles.** Switch each rule on → the window goes in your house,
  on a taxi and during a pet battle, and returns when you leave. Result:
- **VIS-7. Hide when mounted.** On → it goes while mounted; on a druid it also goes in Travel, Aquatic
  and Flight Form, and not in Cat, Bear or Moonkin. Result:
- **VIS-8. Hide when skyriding.** On → it goes the moment the skyriding bar appears, standing on the
  ground; a Dracthyr's Soar and a Haranir flight form count. Dismount from a ground mount and from a
  skyriding mount → it returns both times (never hiding for good after a mount). Result:
- **VIS-9. Hide while dead.** On → it goes on death and returns on release or resurrection. Result:
- **VIS-10. Hide in / out of combat.** Tick each alone and pull a dummy → it hides on its own side of
  the pull and returns promptly on the other side. Tick both → it never shows. Result:
- **VIS-11. Diagnostics names the rule.** After each of VIS-2 to VIS-10, `/mm diagnostics` → its
  `ShouldShow` line names the rule that decided (with both combat rules ticked:
  `ShouldShow -> false (in combat)` or `(out of combat)`). Result:
- **VIS-12. Test mode overrides context.** With a hide rule in force, `/mm test` → the window shows
  wherever you stand. Result:

## GRID

- **GRID-1. Number formats.** Bars → Text content → **Number format**, on a column with a large number
  → *Abbreviated (12.4M)*, *Abbreviated, no decimals (12M)*, *Abbreviated, two decimals (12.40M)* and
  *Full (12400000)* each render what the name says. Look hardest at two decimals: a client that
  refuses the rule falls back to its own defaults, which shows as the setting doing nothing. Result:
- **GRID-2. The text slots are literal.** Bars → Text content, set **Left text** and **Right text** in
  turn → **None** on both: a bar and no text; **Smart value (Per Second or Absolute)**: the rate on
  Damage and Healing, the total on Interrupts, Dispels, Avoidable and Deaths; **Smart value (Absolute |
  Per Second)**: both on Damage and Healing, the total alone on the other four (an Interrupts cell
  reading `9 | 3` fails); **Absolute value**: the total on every column; **Per second value**: a figure
  on Damage and Healing and nothing on the other four; **Percent**: the share. Left None with Right set
  → the figure stays on the right. Result:
- **GRID-3. Text opacity fades only the text.** Bars → Text style → **Text opacity** 10% → names and
  numbers go faint while bars, backgrounds, borders and class icons keep their brightness. Bars → Bar →
  **Bar opacity** dims everything; both at 50% leaves the text at 25%. Result:
- **GRID-4. Every column is a bar.** Every column draws a bar (no numbers-only column), and the columns
  share the frame width evenly (no per-column width). Result:
- **GRID-5. Abbreviation reaches the cells.** At a target dummy out of combat, push Damage past a
  million → an abbreviated figure such as `1.4M`, one decimal place at any magnitude (fewer
  significant figures than the reference screenshots is accepted), and no `/s` on the rate. Raw digits
  (`1410000`) mean neither native formatter exists on this client. Result:
- **GRID-7. A rate below 1000.** Put a Healing or Damage rate under 1000 on screen (a healer at a
  dummy), with GRID-1's Bars → Text content → **Number format** on *Abbreviated (12.4M)* then *Full
  (12400000)*, out of combat and in → a whole number (`411`), never its float (`411.90476…`). If
  digits show: `/mm debug on`, change any setting, and report the `[Format]` line
  (the rung the client took) with the `-- number formatting --` block from `/mm diagnostics`. Result:
- **GRID-8. The realm is stripped.** Group with someone from another realm → their name shows without
  `-Realm`. Result:
- **GRID-9. Truncation.** In a follower dungeon → companion names within the default cap of 15 show in
  full. `/mm set window.text.maxNameLength 8` → names truncate with a single `…` glyph, not three
  periods. `/mm set window.text.maxNameLength 0` → full names again. Result:
- **GRID-10. Truncation counts characters.** Truncate a name with an accent (`Helyâ`) right at the
  accented character → no replacement box. Result:
- **GRID-11. Spell names keep their hyphens.** Drill into a player → a spell name containing a hyphen
  keeps it (the realm strip does not reach breakdown rows). Result:
- **GRID-12. Always show yourself.** In a raid, on the shipped window (Frame → Row → **Maximum rows**
  0) with Frame → Row → **Always show yourself** on (the default), be ranked below the last visible row
  → the last row drawn is you and the rows above are the top of the list in order. Scroll with the
  wheel until your own row is in view → the last slot returns to its own rank and you appear once.
  Untick the option → the last slot is its own rank throughout. Result:
- **GRID-13. Sort modes out of combat.** `/mm set window.data.sortMode roster` → group order (you
  first), then role, then name. `/mm set window.data.sortMode provider` → the game's own order.
  Click a statistic's column header → value sorting again (`/mm get window.data.sortMode` reads
  `value`). Result:
- **GRID-14. An unowned ally has its own row.** After a pull, out of combat → a guardian, totem or pet
  whose owner the unit API never saw has a row under its own name. Result:
- **GRID-15. A delve companion has a row.** In a delve with Valeera → she has a row mid-pull and again
  after it, with her own name, class color and figures, and out of combat her figure plus yours equals
  the header total. A companion other than Valeera has no row until its creature id is added to
  `Constants.COMPANION_CREATURE_IDS` (issue #56); note its name and the creature id the
  `/mm diagnostics` targets section prints. Result: pass (owner, 2026-10-02)
- **GRID-16. No enemy gets a row.** Hit a PvP Training Dummy, then out of combat → the grid shows only
  you, and the `/mm diagnostics` targets section prints the dummy's `class=WARRIOR` and
  `enemies the grid would admit as a row: 0 of 1` (issue #56). After an open-world pull → no mob's
  name appears as a row, mid-pull or after. If one does, stop and report it with `/mm diagnostics`
  taken out of combat (its targets section prints each enemy's `class=`,
  `enemies carrying a player class: N of M` and the admit count). Result: pass (owner, 2026-10-02)
- **GRID-17. Pets fold into the owner when merged.** With a hunter and a warlock in the group, out
  of combat after a pull, on the shipped settings → each pet has a row of its own under its own name,
  as Blizzard's meter shows it. Note the hunter's and the pet's Damage. Tick General → Behavior →
  **Merge pets into their owner** (it ships off) → the pet rows go, and the hunter's Damage is the
  two figures added together. Leave it ticked for GRID-18. Result:
- **GRID-18. Pet swaps correct themselves.** With **Merge pets into their owner** still ticked from
  GRID-17, a hunter dismisses and re-summons, or a warlock swaps demons → the new pet's damage is in
  its owner's row again within one refresh, with no row of its own. Untick the option afterwards.
  Result:
- **GRID-19. The meter-unavailable prompt.** Turn off Blizzard's built-in damage meter (the client's
  setting or CVar), `/reload` → in place of rows, *Blizzard's damage meter is not available.*, *Multi
  Meters reads every number from the game's built-in damage meter. Enable it to see data here.*, and in
  gray *Reason: …* quoting Blizzard's `failureReason` verbatim. No Lua error, never an empty window
  with no explanation. Result:
- **GRID-20. The meter returns without a reload.** Re-enable the meter → within a few seconds (or after
  a zone change or meter event) the rows come back. Result:
- **GRID-21. The two empty states differ.** With the meter enabled and no combat data (click the
  header's reset control and accept, WIN-17; a fresh login keeps the old fights, INSTALL-5) → *Waiting
  for combat data...*, never the unavailable prompt. Result:
- **GRID-22. Bar fills slide.** With Bars → Bar → **Animate bar fills** on (the default), at a dummy →
  each fill slides to its new length instead of stepping four times a second, and when the leader grows
  the other bars shrink smoothly. Result:
- **GRID-23. Animation off snaps.** Turn Animate bar fills off (or `/mm set window.bars.animate false`)
  → the bars snap. Result:
- **GRID-24. The animation changes nothing else.** With it on and off → the same numbers, row order
  and export. Result:
- **GRID-25. The segment menu.** After two or three pulls, click the segment control → a menu of the
  stored fights with durations, a divider, then `Current` and `Overall`, anchored to the session line.
  The segment control is the only route: hovering the empty header left of "Overall" gives no glow and
  clicking there opens nothing. Result:
- **GRID-26. Pinning a fight.** Pick a stored fight → the grid shows that fight's numbers and the header
  names it. Result:
- **GRID-27. Tooltips follow the pin.** On a pinned window, hover a cell and drill into a row → both
  describe the pinned fight, not the live pull. Result:
- **GRID-28. A pin holds through a new pull.** Pull with one window pinned and a second unpinned → the
  pinned one stays on its fight while the other follows the pull. Result:
- **GRID-29. Current clears the pin.** Pick `Current` → the window follows the live pull again. Result:
- **GRID-30. A pin survives `/reload`.** Pin a fight, `/reload` → still pinned. Result:
- **GRID-31. A reset clears a stale pin.** Pin a fight, then reset the meter from the header's reset
  control → on the next refresh the window falls back to Current on its own, never sitting empty.
  Result:
- **GRID-32. Session ids are never 0.** Run three or four pulls, `/mm diagnostics` → every stored
  `sessionID` is a positive integer; log out and in, pull, read again → still no 0. Pin each listed
  fight → each pins. `/mm get window.data.sessionID` answers the pinned id; after picking Overall it
  answers `0`. `/mm set window.data.sessionID 0` unpins; `/mm set window.data.sessionID -1` → *Invalid
  value for window.data.sessionID*. Record the lowest and highest ids seen. Result:

## TIP

TIP-1 to TIP-21 are checkable out of combat. COMBAT-18 repeats the hover, click and mouse-off checks
among them (TIP-1, TIP-4 to TIP-9, TIP-12 to TIP-17 and TIP-20) mid-pull, where they matter most.

- **TIP-1. Cell tooltip.** Hover a Damage cell → the spells behind the number, with icons, capped at
  **Maximum spells** (10 by default), with an *and N more* line when there are more. Result:
- **TIP-2. Spell order.** Out of combat → biggest first. Result:
- **TIP-3. Avoidable Damage lines.** In Test mode (`/mm test`), hover an Avoidable Damage cell → one
  line per spell and nothing else: no "Avoidable" / "Avoidable, Deadly" sub-line and no Overkill line.
  Result:
- **TIP-4. Name tooltip.** Hover a name cell → every tracked statistic for that player, including
  columns this window does not show; each line wears its own statistic's color (label and amount)
  whatever the bar color mode is; held beside the grid, the Damage line matches the Damage bars'
  red; statistics with no column here are the same hue dimmed, number included, not flat gray. Result:
- **TIP-5. Drill-down.** Click a Damage cell → the grid is replaced by that player's spell breakdown in
  the same style, with the header `<player> - <stat>`. Clicking the same cell again, or right-clicking
  any row, returns to the grid. There is no Back button. Result:
- **TIP-6. Breakdown rows show the spell's tooltip.** In a breakdown, hover rows (middle of a cell and
  the name cell) → the client's own spell tooltip, never "No data yet" or a column of zeroed
  statistics, and the row highlights. With `/mm debug on` and then `/mm debug tooltip` (it answers
  *tooltip logging ON — mouse over a row and read the console.*), one `[Tooltip] row spell=<id>` line
  per row entered; `/mm debug tooltip` again answers *tooltip logging off.* Result:
- **TIP-7. A left-click in a spell breakdown does nothing.** Open a Damage cell's spell breakdown
  (TIP-5) and left-click a row → nothing happens: no empty drill, no new window. (A death list is
  different; see TIP-17.) Result:
- **TIP-8. The wheel scrolls.** Shrink the window until rows are hidden → the mouse wheel scrolls both
  the grid and a breakdown, stops at both ends, holds through refreshes, and resets to the top on
  entering or leaving a breakdown. Result:
- **TIP-9. A breakdown holds still.** Watch an open breakdown through several refreshes → its rows do
  not reshuffle. Result:
- **TIP-10. Renaming keeps the breakdown.** Open a breakdown, rename the window from Windows → General
  → it stays open under the new title. Copy settings onto that window → it returns to the grid. Result:
- **TIP-11. Death timestamps.** Bars → Text content → **Death timestamps**, try both styles (time of
  day, time ago) → the Deaths cell tooltip and the death list always agree. Result:
- **TIP-12. Deaths cell tooltip.** Hover a Deaths cell for someone who died → one line per death,
  newest first, each `Death N` with the time on the right; never "Spell breakdown" or "No data yet".
  Result:
- **TIP-13. The death list.** Click that Deaths cell → a list of that player's deaths, one row each:
  `Death 1`, `Death 2`… numbered chronologically (so the newest-first list counts down), with the
  time of death over a full bar. A time reading `—` (recap no longer held) still has its row. Result:
- **TIP-14. The counts agree.** The number of rows in the death list equals the number in the cell you
  clicked, out of combat and in. Result:
- **TIP-15. Death tooltip layout.** A death tooltip has a header, a paragraph gap, a caption, then the
  bars; a header flush against the first bar is the failure (it also restyles every GameTooltip title
  until `/reload`). Result:
- **TIP-16. What killed them.** Hover a death row → one line per incoming hit, oldest first: seconds
  before death, spell, attacker, damage taken, HP percent remaining. Columns line up; long names clip
  inside their column and never wrap. A melee swing reads `Melee` with the weapon icon (never `#?`).
  The bar is HP remaining, emptying down the list. The last line is the killing blow with an overkill
  clause. A hidden caster shows no parentheses, never `()`. Result:
- **TIP-17. The recap is the right one.** With a player who died more than once, click a death row →
  Blizzard's own Death Recap for that exact death, not the newest; the list stays open behind it.
  Result:
- **TIP-18. Feign Death is not a death.** Out of combat, a hunter feigns and leaves combat → not
  counted in the cell or the list. Feign, then really die → the real death is counted. (Mid-pull a
  feign is counted and corrects when combat ends; see scope.md's Known limitations.) Result:
- **TIP-19. No `C_DeathRecap`.** On a client without it → a Deaths click falls back to Blizzard's
  frame, then to the ordinary breakdown; the cell is never dead. Result:
- **TIP-20. Leaving hides the tooltip.** Hover a cell, then move the mouse off the window → the
  tooltip always hides; one left pinned under the cursor is the failure. Result:
- **TIP-21. Death line switches.** Tooltip → Contents; hover a Deaths cell → on a fresh profile each
  line reads *Death 3 | <who>* (**Name the killer** on, **Name the killing blow** off). Turn the killing
  blow on → *Death 3 | <who> | <what>*. Turn Name the killer off → the caster half goes with no
  separator left; turn the spell off → the same. A fall or fire names no caster and melee reads
  **Melee**; neither takes the numbered line with it. Result:
- **TIP-22. Hide tooltips in combat.** Tooltip → General → **Hide tooltips in combat**, pull, hover a
  cell → no tooltip; leave combat → one appears as soon as the player is out of combat. Result:
- **TIP-23. Anchors.** Tooltip → General → **Tooltip anchor**, walk all eight → each is a box of a 3×3
  around the cell ("Top left" above and to the left, "Left" beside and growing left, and so on), each
  opens away from the cell rather than across it, and each lands somewhere different. There is no "At
  cursor"; **Top** is the default. Result:
- **TIP-24. Tooltip appearance.** Hover cells → every Targets line carries an icon in the spell icon
  column; the player's name is class-colored wherever a tooltip names one; the text color mode reaches
  the spell name as well as the numbers; the bar fill and the backdrop each take their own color, mode
  and opacity. Result:
- **TIP-25. The tooltip's own bar texture.** Tooltip → Bar → Bar texture unlike the grid's → the
  tooltip bars change and the grid's do not; change the grid's → the tooltip's do not. Result:
- **TIP-26. Bar spacing.** Tooltip → Bar → **Bar spacing** 6 → space opens between lines; back to 1
  (the shipped default) → the tight spacing returns. Result:
- **TIP-27. The tooltip font.** Tooltip → Text → font, size and **Thick outline** → apply to the spell
  names as well as both number columns. Result:
- **TIP-28. The tooltip bar border.** Tooltip → Bar border → a real LSM border at thickness 2, hover →
  a border around each spell bar; set it back to **None**, hover the same cell → no border at all
  (a lingering border is the pooled line not being cleared). Result:
- **TIP-29. Offsets.** Tooltip → General → Horizontal offset 60, Vertical offset -60 → the tooltip
  moves and still stays on screen near the edges. Result:
- **TIP-30. Maximum spells 0.** Tooltip → Contents → **Maximum spells** 0, hover someone with a long
  list → every spell, up to 64, with *and N more* past that; 0 does not act like 10. Result:
- **TIP-31. Other tooltips are untouched.** After TIP-23 to TIP-30, hover a bag item, a party member's
  unit frame and a quest in the tracker → each looks exactly as always: stock font and spacing, no
  bars, no borders. Result:
- **TIP-32. The Targets section.** Tooltip → Contents → **Show targets** on, **Maximum targets** 3; out
  of combat after a pull on several enemies, hover your Damage cell → a **Targets** header under the
  spells, listing the enemies you hit, biggest first, with bars and a share column. Result:
- **TIP-33. Targets on Damage only.** Hover a Healing and an Interrupts cell → no Targets section.
  Result:
- **TIP-34. Each player's own targets.** Hover another player's Damage cell → their targets, not yours
  and not the group's. Result:
- **TIP-35. The cap trims after ordering.** Raise Maximum targets to 10 → more enemies, still biggest
  first, led by the same three as at 3. Result:
- **TIP-36. Targets off costs nothing.** Turn Show targets off → no Targets header, and a `/mm perf`
  capture while hovering shows no `targets` bucket activity. Result:

## EXPORT

Everything here works at a target dummy; the combat refusals are COMBAT-23 to COMBAT-26.

- **EXPORT-1. The modal opens over its window.** Out of combat after a pull, drag a window to a corner
  and click its export control → the modal opens centered on that window. Result:
- **EXPORT-2. The modal's title bar.** Its title reads **Export**, drags the modal, and ends in the
  collection's close icon (the one the window header draws), gray at rest and red under the pointer; a
  thin gray multiplication sign means LibKa0s was not told the addon folder or the art is missing.
  Result:
- **EXPORT-3. The modal's layout.** Three selectors stacked, **Metric**, **Channel**, **Lines**, each
  reading `Label: value`, and two action buttons, **Export to CSV** and **Print to Chat**. Result:
- **EXPORT-4. Action icons.** A spreadsheet icon left of Export to CSV's label and a speech bubble left
  of Print to Chat's; the words stay, centered. Result:
- **EXPORT-5. One modal, reused.** Open it from window 1, close it, open it from window 2 → it
  re-centers on window 2 and exports window 2's segment. Result:
- **EXPORT-6. Closing.** Esc closes it, and so does the close button. Result:
- **EXPORT-7. Esc with a menu open.** Open Metric, Channel or Lines, press Esc without picking → the
  modal and its dropped menu both close; no menu is left floating. Result:
- **EXPORT-8. The selector menu.** Click Metric → a flat dark menu drops directly under the button,
  left-aligned with it, with no gold title bar; the current row is gold and the rest light gray (like
  Bank Ledger's Data Set menu, not a Blizzard right-click menu). The same on Channel and Lines. Result:
- **EXPORT-9. A click outside lands.** With a menu open, left-click and then right-click on the modal
  behind it → the menu closes and the click takes effect in the same press. Result:
- **EXPORT-10. Picking repaints at once.** Pick a different entry in each selector → the menu closes
  and the button reads the new choice before the menu has finished closing. Result:
- **EXPORT-11. One menu at a time.** Open Metric, then click Channel without picking → Metric closes as
  Channel drops; never two menus. Result:
- **EXPORT-12. No leading glyphs.** No row in the three menus shows a box or stray character before its
  label. Result:
- **EXPORT-13. Metric follows the window.** Export from a window sorted by Healing → **Metric:
  Healing** before you touch anything; from another sorted by Interrupts → **Interrupts**. There is no
  "Match the window" entry. Result:
- **EXPORT-14. A pick holds until the next open.** Pick Deaths → the button reads Deaths and the chat
  dump ranks by Deaths. Close, re-open from a window sorted by Healing → **Healing** again. Result:
- **EXPORT-15. The whisper row.** Walk Channel through every entry → a fourth row, `Whisper to: ` in
  gold with an edit field in the same flat box, exists only for **Whisper**; the modal grows by one row
  with the warning line and buttons moving down, nothing overlapping; back to **Self only** → the row
  goes and the modal shrinks. Result:
- **EXPORT-16. The name box shows its text.** Type a full name → fully visible, on the caption's
  baseline. Result:
- **EXPORT-17. The name is stored without Enter.** Type a name and press Enter → stored, focus leaves
  the box. Type a name and click away → stored anyway. Type a name and click **Print to Chat** straight
  away → it is whispered. Result:
- **EXPORT-18. Esc in the box.** Esc → focus clears and the modal stays; a second Esc closes it.
  Result:
- **EXPORT-19. The name is kept.** Switch to another channel and back to Whisper → your name is still
  there. Result:
- **EXPORT-20. A blank whisper is refused.** Whisper with the box empty (or spaces), Print to Chat →
  one line *Enter a name to whisper to.*; nothing sent, no error. Result:
- **EXPORT-21. Cross-realm whispers.** Channel **Whisper**, type a player from another realm in the
  box as `Name-Realm` (the form `/w` takes), **Print to Chat** → the lines reach that player. Result:
- **EXPORT-22. The CSV window.** With several players in the segment, **Export to CSV** → a wider
  window opens above the modal (the modal stays visible under it), centered on the meter window,
  titled **Export — Ctrl+C, then Esc**, ending in the same close icon, its text in the bundled
  JetBrains Mono with the digit columns lined up. Result:
- **EXPORT-23. Pre-selected, from the top.** The whole text is highlighted the moment it appears, with
  the view at the top of the file. Result:
- **EXPORT-24. Copying.** Ctrl+C, paste into a text editor → the whole CSV with its line breaks, not one
  line. Result:
- **EXPORT-25. Esc closes only the copy window.** With the copy window and the Export modal open,
  press Esc → only the copy window closes; the modal stays. Result:
- **EXPORT-26. One copy window.** Export again without closing it → it refills rather than stacking a
  second; after `/reload`, export again → still one window, still centered. Result:
- **EXPORT-27. It follows the meter window.** Drag the meter window elsewhere and export → the copy
  window centers on it there. Result:
- **EXPORT-28. The first open.** On the first export of a session, lines may wrap oddly while the scroll
  frame is unlaid (the 590px fallback) and not on the second → cosmetic; note it if seen. Result:
- **EXPORT-29. The file in a spreadsheet.** Paste the CSV into a spreadsheet → one header row and one
  row per player; the header row is byte-identical to the line quoted in LOC-1; every catalog
  statistic is present even from a window showing only Damage, with `_ps` on Damage and Healing only
  and one `_pct` per statistic; values are raw integers (`4821993`, not `4.8M`) and `_pct` a bare
  two-decimal number; `session` (the segment the window's header names) and `duration` repeat on
  every row; absent figures are empty cells, never `nil`; no trailing blank row; a raid over 40 stops
  at 40 data rows. Result:
- **EXPORT-30. A name with a space and a hyphen.** After a follower dungeon or delve, export → an NPC
  ally such as `Crenna Earth-Daughter` arrives whole, unquoted, in one cell. Result:
- **EXPORT-31. The CSV keeps the realm.** Group with someone from another realm and export → their
  `name` keeps `-Realm`. Result:
- **EXPORT-32. Commas and quotes.** A name containing a comma or a quote → that field is wrapped in
  double quotes with inner quotes doubled, and reads as one cell. Result:
- **EXPORT-33. Self only reaches nobody.** Do this before any other channel. Channel **Self only**,
  Metric Damage, Lines 5, Print to Chat → the lines appear in your frame, each with the `[MM]` banner
  and with no notice line before them, and a group member sees nothing (anything seen is a hard fail).
  Result:
- **EXPORT-34. The dump's shape.** A header line `Multi Meters — Damage — Current (2:14)` then ranked
  lines such as `1. Kaosz 4.8M (84.2K, 31.2%)`, abbreviated. Result:
- **EXPORT-35. Only meaningful parentheses.** Metric Deaths or Interrupts → no per-second figure
  (`1. Kaosz 3 (12.5%)`); never an empty `( )`. Result:
- **EXPORT-36. The ranking follows the metric.** Metric Healing → the top healers, not the damage
  ranking with healing beside it. Result:
- **EXPORT-37. The line cap.** Walk all five Lines choices; Lines 3 → four lines (header plus three);
  Lines 40 in a five-player group → six lines, not forty. Result:
- **EXPORT-38. The channels.** Say reaches people nearby, Party and Raid the group, Instance a dungeon
  or LFR group, Guild the guild; each sends the same lines without the `[MM]` banner. A Party export
  that only prints to you, after *This client has no way to send chat messages, so the export was
  printed to you instead.*, is the failure. Result:
- **EXPORT-39. The channel list.** Channel offers Say, Party, Raid, Instance, Guild, Whisper, Whisper my
  target and Self only; there is no Automatic. A profile that stored the retired `AUTO` opens on Self
  only. Result:
- **EXPORT-40. Say outdoors.** In a city, Lines 20, Say → every line leaves inside the click, after a
  one-line warning that the server may drop some; only the header arriving is the failure. Result:
- **EXPORT-41. Say inside an instance.** Lines 20, Say inside a dungeon or raid → staggered, about seven
  seconds, all twenty arrive. Result:
- **EXPORT-42. The pause every fifth line.** Lines 20 to Party → five quick lines, a beat, five more.
  Result:
- **EXPORT-43. Whisper.** With a name in the box → it reaches that character and nobody else. Result:
- **EXPORT-44. Whisper my target.** The box is hidden. Target a group member → they get it; a
  cross-realm member → it still arrives. Nothing targeted → *You have no target to whisper to.*; a boss
  or NPC → *Your target is not a player.*; neither sends or prints the dump to you. Result:
- **EXPORT-45. The target is read at the click.** Open the modal on one target, switch targets, send →
  it goes to the second. Result:
- **EXPORT-46. A whisper to nobody stops.** Whisper a nonsense name, Lines 20 → after the game's "No
  player named ..." the addon says once *There is nobody called '...' to whisper to. The rest of the
  export was not sent.* and the other nineteen lines are dropped. Result:
- **EXPORT-47. No line is cut.** A long NPC ally name on a line with a share → the line arrives whole.
  Result:
- **EXPORT-48. An empty segment.** Out of combat, click the header's reset control and accept (the
  window reads *Waiting for combat data...*, WIN-17; a fresh login is no substitute, since the old
  fights survive it, INSTALL-5), open the export modal, Channel **Self only**, **Print to Chat**, then
  **Export to CSV** → each prints one line *There is nothing to export.*; nothing is sent, no copy
  window opens, no error. Result:
- **EXPORT-49. What is remembered.** Set Metric Healing, Channel Party, Lines 20 and a whisper name;
  close; `/reload`; re-open → Channel, Lines and the name are as you left them for every window (they
  are addon-wide); Metric reads the opening window's sort column. With `/mm debug on`, re-open on the
  same window → no `[Set] export.metric` line. Result:
- **EXPORT-50. No Export group in the panel.** General shows no Export group; the modal is the only
  place these are set. Result:
- **EXPORT-51. The CLI reaches the export rows.** `/mm get export.channel` answers; with the modal
  closed, `/mm set export.lines 10`, re-open → `Lines: 10`. Result:
- **EXPORT-52. `/mm export` uses the active window.** With two windows, select the second in the band
  and pin it to a different segment, `/mm export`, Export to CSV → the `session` column names the
  second window's segment. With nothing ever selected, it opens for the first window. Result:
- **EXPORT-53. `/mm export <name>`.** `/mm export Multi Meters #1` → the modal for that window (name
  case and inner spaces kept). Result:
- **EXPORT-54. An unknown window.** `/mm export Nosuchwindow` → *No window named 'Nosuchwindow'.* and
  nothing opens. Result:
- **EXPORT-55. A window never drawn.** For a window that exists but has not been drawn this session
  (for example one a hide rule has kept hidden since login), `/mm export <its name>` → it exports (the
  verb hands over the config, not the live frame). Result:

## COMBAT

Every check here needs a real pull (a Mythic+ pack or raid pull) with BugSack cleared, the window
locked, the default value sort (`/mm get window.data.sortMode` reads `value`) and the six default
columns, unless it says otherwise. Record the
dungeon and key level (or raid), group composition, number of packs and whether the error frame
stayed empty; "no errors" from a dummy is not evidence here.

- **COMBAT-1. No Lua error through a key.** Zone in (the window shows the whole group between packs),
  fight at least three packs and one boss without touching anything, check the error frame after each →
  empty. Watch for *attempt to compare two secret values*, *…arithmetic on a secret value*, *…use a
  secret value as a table index*, *…get length of a secret value* and `table.concat` errors. Result:
- **COMBAT-2. Bars move.** Every cell's bar fills and drains through the pull (none frozen at zero).
  Result:
- **COMBAT-3. Text renders mid-pull.** Damage reads like `188K`, never `188000` or `<secret>`, and looks
  the same as out of combat; with the shipped smart slot, Damage and Healing read as rates and the
  other four as counts and totals; set **Smart value (Absolute | Per Second)** for one pull → both
  figures on Damage and Healing and the absolute alone elsewhere. `<secret>` means the native formatter
  was unreachable. Result:
- **COMBAT-4. Names and class colors hold.** The name column renders in full at the height of a pull;
  if a name ever blanks, the class icon and bar still carry the row. Result:
- **COMBAT-5. The header renders.** "Current", the duration ticking as `m:ss` and the group total for
  the sort column, throughout. Result:
- **COMBAT-6. The grid is not empty.** Rows show all pull. *Waiting for combat data...* with a live
  session means sources are being dropped (`/mm debug on`: `dropped=` equal to the group size). Result:
- **COMBAT-7. Percent slots go empty.** With Bars → Text content → **Left text** on **Percent**
  (`/mm set window.text.leftSlot percent`) → the slot empties on the pull and refills between packs
  (empty means unknowable, never zero). Result:
- **COMBAT-8. The refresh is smooth.** About four updates a second (`data.throttle = 0.25`) with no
  stutter or hitch at a big pull; capture one with DIAG-7 rather than guess. Result:
- **COMBAT-9. Between packs everything comes back.** On the first refresh after the pull → percentages
  return, blanked cells fill, pets fold per **Merge pets**, and the gray `restricted` note goes.
  Result:
- **COMBAT-10. `/reload` mid-pull.** `/reload` during a pull → the addon comes back with no error
  (`NS.State.restricted` is seeded from `Secrets.IsRestricted()` at enable). Result:
- **COMBAT-11. Live ranking.** Note the order between packs, pull → rows keep coming and re-rank live
  (someone overtaking moves up during the fight); the header says `restricted` in gray. Result:
- **COMBAT-12. Pets mid-pull.** Every row is present, with pets as their own rows whatever **Merge
  pets** says. Result:
- **COMBAT-13. Duplicate class and spec.** In a group with two players of the same class and spec →
  their Damage is right and their other columns are empty; the header reads `restricted — N of M share
  a class and spec` while under a quarter of the rows are affected, and `restricted — N of M blank:
  duplicate specs` from a quarter up, the whole sentence fitting the header at two-digit counts. Result:
- **COMBAT-14. Sort modes mid-pull.** `/mm set window.data.sortMode roster` before one pull, then
  `/mm set window.data.sortMode provider` before the next → in combat each shows the engine's ranking,
  as COMBAT-11. Click a statistic's column header afterwards to return to value sorting. Result:
- **COMBAT-15. A stat header click mid-pull.** Click a stat header → the grid re-ranks by that stat and
  the arrow moves; click it again → reversed; nothing printed. Result:
- **COMBAT-16. The Player header mid-pull.** Click it → nothing moves and *Sorting is not possible while
  the game restricts combat data.* prints. Result:
- **COMBAT-17. The name sort in combat.** Out of combat, click the Player header (the arrow moves to
  it; `/mm get window.data.sortMode` reads `name`), then pull → the arrow leaves the Player header for
  the sort column. Result:
- **COMBAT-18. Tooltips and drill-down mid-pull.** Repeat TIP-1, TIP-4 to TIP-9, TIP-12 to TIP-17
  and TIP-20 during a pull → no Lua error and the same results; a present, correct *and N more* line;
  the spell list in the game's own order (never *invalid order function for sorting*); the tooltip
  never stays pinned under the cursor. Result:
- **COMBAT-19. Death lines mid-pull.** With both death-line switches on → a caster or spell the client
  hid is simply absent, never an error. Result:
- **COMBAT-20. Death bars mid-pull.** Hover a death row → the bars draw; the HP percentages may vanish
  (a division), but a Lua error means something computed the ratio in Lua. Result:
- **COMBAT-21. Tooltip placement mid-pull.** Hover cells → no Lua error naming this addon; a tooltip in
  the wrong box mid-pull and the right box out of combat is the `pcall` fallback working. Result:
- **COMBAT-22. Targets are absent mid-pull.** With Show targets on, hover a Damage cell → no Targets
  section at all (a list mid-pull is a hard fail) and no Lua error. Result:
- **COMBAT-23. Export actions refuse.** Open the modal between packs and leave it open; pull; click
  Export to CSV, then Print to Chat → nothing exported or sent; one line *Export is not available while
  the game restricts combat data.*; both buttons gray out and the same sentence appears in red on the
  modal. No Lua error. Result:
- **COMBAT-24. The glyph and the verb refuse.** Mid-pull, click a window's export control and run
  `/mm export` → nothing opens and the same sentence prints. The control does not gray and ungray
  through the fight. Result:
- **COMBAT-25. The modal recovers on its own.** Leave the modal open to the end of the pull → both
  buttons come back live and the warning clears without a click; an export then works. (On a degraded
  load with no AceEvent, close and re-open instead.) Result:
- **COMBAT-26. A modal opened after the pull.** Keep the modal closed through a pull, open it after →
  both buttons live. Result:
- **COMBAT-27. The pet fold at the edges.** With a hunter in the group, tick General → Behavior →
  **Merge pets into their owner** (it ships off), then pull → in combat the hunter's number is low by
  the pet's share, and it catches up when combat ends; no Lua error at either transition. Untick the
  option afterwards. Result:
- **COMBAT-28. Bar fills slide mid-pull.** With Animate bar fills on → the bars still slide and no
  Lua error. Record client build and whether it was a key or a raid. Result:
- **COMBAT-29. Diagnostics mid-pull.** `/mm diagnostics` → no Lua error; session figures, names and
  durations read `<secret>` where hidden, and every window's size and position still print. Record
  whether it was a key or a raid. Result:
- **COMBAT-30. Cell borders mid-pull.** Tick Bars → Border → **Bar border** (it ships off) and pick a
  **Border style** other than None (an LSM edge, the backdrop path), then pull → the borders draw
  around the cells and no Lua error appears. Result:

## DIAG

- **DIAG-1. The debug log.** `/mm debug on`, `/mm debug` to open the console, complete a pull → an
  `[Aggregator]` line whenever a pass differs from the one before, such as `window=1 cols=6 rows=5
  dropped=0 unfolded=0 sort=value/value reason=ok` (`sort=value/value` between packs, `value/provider`
  mid-pull, where the game's order stands in); a run of identical passes is folded into one line
  ending `(xN)` about every ten seconds, and `[Render] window N drew …` lines behave the same way. A
  roster build logs one `[Roster] built members=…` line and a visibility pass one `[Visibility]` line;
  nothing is logged per row or cell. A large `dropped=` out of combat means the owner map missed
  something; `unfolded=` in combat is expected. Result:
- **DIAG-2. Logging off.** `/mm debug off` → logging stops and the console stays open; after `/reload`
  neither the flag nor the console state has survived. Result:
- **DIAG-3. Console and flag are separate.** `/mm debug` toggles the console window; `/mm debug on|off`
  sets the flag; logging runs with the console closed. Result:
- **DIAG-4. The console's title icons.** Three icons, right to left: close, clear, copy, in the meter
  header's art, one size and pitch, gray at rest and gold under the pointer; words or a multiplication
  sign mean the art or `addonName` was lost. Result:
- **DIAG-5. No tooltips on copy and clear.** Hover each → it turns gold and nothing pops up. Result:
- **DIAG-6. Clear and copy work.** Clear → the log empties. Copy → the copy window opens with the same
  close icon; Ctrl+C then Esc work. Result:
- **DIAG-7. A perf capture.** `/mm perf help`, `/mm perf start`, `/mm perf measure a`, then a raid
  pull (a Mythic+ pack will do; a solo dummy records only your own casts). Still in combat in that A
  window, whisper a name nobody is playing (`/w Zzqxvw hi`): the server's *No player named …* reply
  is a system message, and no fight produces one on its own. After the pull, `/mm perf measure b`,
  fight another pack, `/mm perf finish` (chat shows *perf run FINISHED — saved; …* first and *addon
  RESUMED — restored* second, the windows come back and no report prints; the console has them the
  other way round, *addon RESUMED — events and frames restored* then *perf run FINISHED — saved;
  …*), then `/mm perf report` → during the B window the addon is inert without a `/reload` (no
  provider reads, timers stopped, every window refused) and nothing (combat, roster change, a
  settings write) brings a window back. The report, written to the console with the JSON line after
  it, has a `meterEvent`, a `spellEvent` and a `systemEvent` row, each with calls above zero and a
  total ms column (that column can read 0.00: `systemEvent` returns at once when no whisper export
  is pending, so read its `totalMs` from the JSON line if it matters. The brackets record only in
  window A's combat, and a bucket that recorded nothing has no row: `meterEvent` counts the
  `DAMAGE_METER_*` events, `spellEvent` every `UNIT_SPELLCAST_SUCCEEDED` from any unit,
  `systemEvent` each `CHAT_MSG_SYSTEM`.) It also names `refresh` with `aggregate` and `render` under
  it, `renderRow` under `render`, and `providerRead`, plus `tooltip` (and `targets` under it) only
  if a cell was hovered in window A, which is DIAG-10's run; every nested bucket reads **observed
  inside**, never *declares itself within X — not observed*. Hand the report and dump to
  `/wow-addon:perf-analysis`. Result:
- **DIAG-8. Captures carry the version.** Every capture record is stamped with the addon version, never
  `v?`. Result:
- **DIAG-9. Perf output ignores the debug flag.** With `/mm debug off`, run a capture → its output
  still appears. Result:
- **DIAG-10. A group capture with the tooltip path.** In a group of 15 or more with Tooltip → Show
  targets on, during the A window park the mouse on your Damage cell for several seconds, then on
  another player's → `tooltip` and `targets` record calls; the nesting note reports `providerRead
  observed inside more than one parent`; `renderRow` calls per pass match the rows on screen. Result:
- **DIAG-11. Perf labels and cancel.** `/mm perf start mylabel` → the started line reads *perf run
  STARTED — <date> <time> mylabel*; `/mm perf finish`, then `/mm perf report` → the report's
  `capture:` line names the same label. `/mm perf start` with no label → the started line carries the
  date and time alone; `/mm perf cancel` → *perf run CANCELED — nothing saved* (one L in CANCELED). No
  Lua error. Result:
- **DIAG-12. The perf panel's close control.** `/mm perf`, then `/mm debug` beside it → exactly one close
  control, in the panel's top-right corner, in the same art as the console's and the header's (a thin
  gray multiplication sign is the library's fallback; two stacked means a `decorate` hook came back);
  clicking it closes the panel and `/mm perf` reopens it. No Lua error. Result:
- **DIAG-13. The report while disabled.** `/mm disable`, then `/mm diagnostics`, `/mm debug diagnostics`,
  `/multimeters diagnostics` and `/multimeters debug diagnostics` → each writes the same full report,
  whose `state` section reads `stored enabled=false` and `stood down=true`. `/mm enable` after. Result:
- **DIAG-14. The report appends.** `/mm debug on`, change a setting or two, `/mm diagnostics` → the
  trace lines are still above `==== Ka0s Multi Meters diagnostics begin ====`. Result:
- **DIAG-15. The report copies clean.** After DIAG-14, **Copy** and paste → the trace, the begin marker
  and the end line `==== Ka0s Multi Meters diagnostics end: N line(s) ====`, with no `|c` escapes.
  Result:
- **DIAG-16. The report is ungated.** `/mm debug off`, `/mm diagnostics` → the full report lands, begin
  to end marker, even though logging was off when it ran; it also turns logging on (DIAG-38), so the
  header now reads `Debug: ON`. Result:
- **DIAG-17. The buffer cap.** With `/mm debug on`, refresh through a few pulls or repeat
  `/mm diagnostics` until the console passes its cap → the counter reads `N / 3000 lines`, stops at
  3000, and nothing stalls as lines keep arriving; Copy opens without a hitch and holds the newest
  lines in order, the oldest dropped. Record where it settled. Result:
- **DIAG-18. The old name is gone.** `/mm debug diag` → toggles the console like any unknown word;
  `/mm diag` → `unknown command`. Neither runs the report. Result:
- **DIAG-19. The README's bug-report steps.** From a fresh `/reload` with the console closed, follow
  `## Reporting a bug` in the README word for word → every step works and the paste holds the trace
  and the whole report. Result:
- **DIAG-20. The export control's art in the report.** `/mm diagnostics` → its atlas probe lists
  `poi-scrollofresonance` and `UI-HUD-MicroMenu-Questlog-Up` with whether each resolves, and its header
  dump shows what the export control drew. Record which resolved (never yet seen on a live client).
  Result:
- **DIAG-21. Provider order.** After a pull, out of combat, `/mm diagnostics` → the `-- provider order
  --` section gives each stat `ranked, descending`, `NOT ranked, breaks at index N` or `nothing to
  check` (mid-pull every line reads `cannot be checked`); a `NOT ranked` goes to issue #14. Then in a
  full group: click the Damage header until the arrow points down (`/mm get window.data.sortColumn`
  reads it back), pick **Overall** from the segment menu, open Blizzard's meter on Damage done with the
  same scope, and compare the two lists by name; repeat for Healing and Interrupts, and once mid-pull →
  the orders match. On a mismatch, report the stat, instance, session type, both orders, in or out of
  combat, and whether the addon's order looks like any consistent order. Result:
- **DIAG-22. The identity capture.** In the largest group you can get (20 or more; a party proves
  nothing), `/mm debug on` before the pull; about ten seconds in, `/mm debug identity`; about fifteen
  seconds later, again; after combat, once more; then copy the console → no Lua error at any point
  (the probe walks a raw source row with `pairs`, a shape the mock only approximates); the standing
  line reads `identity rows=N keys=N collidedKeys=N collidedRows=N filled=F/P collided=N unmatched=N
  absent=N` with `filled + collided + unmatched + absent == P`, and the header's `N of M` equals
  `collidedRows`. Report `unmatched` above zero with its column, any `PARTIAL` line other than
  `specIconID`, any `ABSENT` line, any `WOULD widen the key` field (or `No usable candidates`), and
  whether a collided key's seats hold their order across both captures, with group size, the
  duplicated class+spec pairs, instance and difficulty, and all three captures in full. Typed before
  any pull with the flag on this session, the report says `no identity pass has been measured`; the
  after-combat capture instead shows the last pass under *the pull has ENDED*. Result:
- **DIAG-23. The feign verb refuses a typo.** On a fresh session, `/mm debug feign of` → one line
  ``unknown feign argument 'of' — `/mm debug feign on|off`, or `/mm debug feign` to print the recording.``
  (backticks included) and nothing else; `/mm debug feign` then still says `armed: false`. Result:
- **DIAG-24. The feign capture.** `/mm debug feign on` (answers `feign trace ON`), run a dungeon with a
  hunter who is not you, have them feign twice (and feign then really die), then `/mm debug feign` and
  copy the console → record it with the group size and composition: no `cast` line means
  `UNIT_SPELLCAST_SUCCEEDED` never arrived; `prune` lines read `state=noted` or `state=down`, never
  `<evicted>`; `unit=<not in group>` against a hunter still in the party is a roster fault; `N judge
  rows suppressed` with no `judge` lines means no cast line named the GUID. Note the Deaths count shown
  beside it. Result:
- **DIAG-25. Does a feign's recap differ?** Out of combat, a hunter feigns once without dying and
  another member really dies; `/mm debug recap` → compare what `HasRecapEvents`, `GetRecapEvents` and
  `GetRecapMaxHealth` answered for the hunter's newest row and the real death's. Both alike (events, a
  max health, the same shape) → issue #25 stays not fixable from this provider. The feign consistently
  different across three feigns → paste the dump into the issue. Result:
- **DIAG-26. Event trace: zoning.** `/mm debug on`, console open, zone into a dungeon (or take a
  portal) → `[Event] PLAYER_ENTERING_WORLD lockdown=false restricted=… login=false reload=false`, then
  `[Event] ZONE_CHANGED_NEW_AREA …` when the zone name changes without a loading screen. Result:
- **DIAG-27. Event trace: combat.** Pull a dummy, then leave combat → `[Event] PLAYER_REGEN_DISABLED …`
  at the pull and `[Event] PLAYER_REGEN_ENABLED …` when combat ends. Result:
- **DIAG-28. Event trace: roster.** Join or leave a group, or have someone join yours →
  `[Event] GROUP_ROSTER_UPDATE …`, once or a few times. Result:
- **DIAG-29. Event trace: the restriction.** A boss pull and kill (follower dungeon or LFR), or a key
  start and end → `[Event] ADDON_RESTRICTION_STATE_CHANGED lockdown=… restricted=… type=<n> state=<n>`
  at each edge, `restricted=true` while active. Note every `type=`/`state=` pair and when. Result:
- **DIAG-30. Event trace: quiet events.** Mount, dismount, shapeshift, die and release → no `[Event]`
  line for any of them, and the windows still hide and show by your visibility rules. Result:
- **DIAG-31. Rejected events.** On a current client, `/mm diagnostics` → the `-- events --` section,
  the last in the report, reads `rejected events: none`. Then `/reload` and `/mm debug on` → no
  `[Init] rejected events:` line in the console (a name refused at login is held by the console's
  at-enable queue and written the moment logging is turned on, so this is the load's own answer).
  `/mm disable`, `/mm enable` → still none. Any event named is a finding: the client no longer knows
  it. Result:
- **DIAG-32. The console resizes.** `/mm debug`, then drag the grip in the console's bottom-right
  corner → the console grows and shrinks on both axes from its 700 × 344 opening size; the log text,
  the scrollbar and the title bar follow, the three title icons stay in their corner, the scrollbar's
  thumb and the `N / 3000 lines` counter still match the buffer (no digit under the grip), and the
  buffer and scroll position are unchanged. Shrink it as far as it goes → it stops while the title and
  all three icons still fit side by side and the title bar, the status bar and a few lines still
  show. No Lua error. Result:
- **DIAG-33. The copy windows resize.** Console **Copy**, then drag its bottom-right grip → it resizes
  on both axes, the text box widens and narrows with it, and the scroll bar's down button sits above
  the grip and takes a click on its whole face; it stops shrinking at 240 × 140. Repeat on the
  **Export to CSV** window (EXPORT-22) → the same, and its size is its own: resizing one leaves the
  other at the size it had. No Lua error. Result:
- **DIAG-34. The perf panel resizes in width only.** `/mm perf`, then drag its bottom-right grip → the
  panel widens and every step row stretches with it; the height does not move; it never goes
  narrower than its opening width. No Lua error. Result:
- **DIAG-35. Sizes last the session, never a reload.** Resize the console, the console's copy window,
  the CSV window and the perf panel, close each and reopen it → each comes back at the size you
  left. Then `/reload` and reopen each → each is at its default again (the console 700 × 344, the
  panel its opening size, each copy window its own); do the same once with the console dragged
  elsewhere first, and the reload still restores the default size. Result:
- **DIAG-36. Another addon's console is unaffected.** With another Ka0s addon loaded, resize this
  addon's console, then open the other addon's debug console → it opens at 700 × 344; resize it →
  this addon's console keeps the size it had. Result:
- **DIAG-37. The Diagnostics link.** Bare `/mm debug` → in the title bar, top left, the word
  **Diagnostics** sits just right of the `Debug: ON` / `Debug: OFF` label with a small gap, drawn
  orange in the same plain text as that label: no button art, border or background. Hover it → it
  brightens; move off → orange again. Click it → the diagnostics report is written into the console,
  begin to end marker, with the one chat line giving its line count, exactly as `/mm diagnostics`
  writes it. Toggle the label between ON and OFF → the gap after it holds for either word. Drag the
  console in as far as it goes (DIAG-32) → the link still fits beside the label and the title.
  Result:
- **DIAG-38. Diagnostics turns logging on for the session.** `/reload` → logging is off (DIAG-2).
  `/mm diagnostics` → chat prints the `debug logging ON` line, then the report's line-count line; the
  console holds `[Debug] logging enabled` and the `[Init]` summary ahead of the begin marker, the
  report's header reads `debug logging: on`, and the title-bar label reads `Debug: ON`. Change a
  setting → a `[Set]` line streams. `/reload` → logging is off again. Click the console's Diagnostics
  link (DIAG-37) → the same: logging on for the session. `/reload`, then `/mm debug on` and
  `/mm debug diagnostics` → the report appends with no second `logging enabled` line. `/mm debug off`
  → logging stops, and nothing turns it back on until the next report or `/mm debug on`. Result:
- **DIAG-39. A slash refusal shows in the console.** `/mm debug on`, then `/mm frobnicate` → chat
  prints the unknown-command line and the help, as before; the console holds one
  `[Cmd] refused frobnicate: unknown verb` line. `/mm disable`, then `/mm lock` → chat prints the
  disabled line; the console holds one `[Cmd] refused lock: disabled` line, and no second line for
  the same refusal. `/mm enable` after. Result:
- **DIAG-40. A Lifecycle edge shows in the console.** `/mm debug on`, `/mm disable` → the console
  holds one `[Lifecycle] stood down: added disabled (holds: disabled)` line and no `[Init] stood down`
  line. `/mm enable` → one `[Lifecycle] stood up: released disabled (holds: none)` line. Result:
- **DIAG-41. State written at login lands at enable, and Clear re-arms.** `/reload`, then
  `/mm debug on` → after the `[Init]` summary the console holds one `[Launcher] registered` line
  (written at login, while logging was off). `/mm debug off`, `/mm debug on` → no second
  `[Launcher] registered`. With a window drawing and nothing changing, press the console's Clear →
  within a second one `[Render] window 1 drew …` line comes back rather than an empty console until
  the next change. Result:
- **DIAG-42. A secret still prints as `<secret>`.** Mid-pull, run `/mm diagnostics` → the secret
  session names and durations, and the display-types tally, read `<secret>` exactly as before, and
  the plain fields beside them still print. No Lua error. The sentinel is now the library's
  `Core.SECRET` rather than the report's own copy (MultiMeters#58). Result:

## DEGRADED

Rename `libs/LibKa0s` to `libs/LibKa0s_off` (or delete it from a copy of the install), then `/reload`.

- **DEGRADED-1. The addon still runs.** → it loads and the window draws rows. Result:
- **DEGRADED-2. One honest line.** → the first line the addon prints names the cause: *The LibKa0s
  library is missing from this installation of Ka0s Multi Meters (expected in libs/LibKa0s); running
  on reduced built-in fallbacks.* Each line after it that reports a missing piece repeats the cause
  with its own consequence, such as *…, so there is no minimap button and no broker plugin.* Result:
- **DEGRADED-3. What names the missing library.** `/mm config` and a bare `/mm` say the settings panel
  is unavailable; `/mm help` still prints the index (plainly); `/mm list`, `get`, `set` and `reset` each
  name the missing library; `/mm perf` says performance measurement is unavailable. Result:
- **DEGRADED-4. The host verbs work.** `/mm lock`, `/mm test`, `/mm toggle`, `/mm window list`,
  `/mm reset-positions` → each works. Result:
- **DEGRADED-5. Enable and disable work.** `/mm disable` → `enabled = false` and the windows go;
  `/mm enable` → `enabled = true` and they return; neither says anything is unavailable. Result:
- **DEGRADED-6. `/mm resetall` works.** → the same popup; accepting resets the profile. Result:
- **DEGRADED-7. No half-loaded schema.** No Lua error at load; `/mm list`'s absence message is
  expected, a partial settings surface is not. Result:
- **DEGRADED-8. `/mm profile` names the library.** `/mm profile` and `/mm profile Default` → each prints
  `/mm profile is unavailable.` with the cause, and nothing switches. Result:
- **DEGRADED-10. No grip without the library.** → the window draws with no bottom-right grip and no
  Lua error, and `/mm lock` then `/mm lock off` raise nothing (MultiMeters#58: the seam answers no
  grip rather than re-implementing the library's). Result:
- **DEGRADED-9. Restoring.** Rename the folder back, `/reload` → everything returns. Result:

## Non-English client

- **LOC-1. The CSV header does not translate.** On a non-English client (German, for example), export
  a CSV and compare its header line with this one → byte-identical:
  `session,duration,name,class,spec,role,damage_done,damage_done_ps,damage_done_pct,healing_done,healing_done_ps,healing_done_pct,absorbs,absorbs_pct,interrupts,interrupts_pct,dispels,dispels_pct,damage_taken,damage_taken_pct,avoidable_damage_taken,avoidable_damage_taken_pct,deaths,deaths_pct`
  (snake_case from the stat keys, never localized, so a file opens with the same formulas anywhere).
  Result:

## Pending sign-off

Checks with no pass on record in their current form, with their origin in the previous suite (its
`§n` sections) or in the 2026-09-23 remediation plan's in-client checklist (`06 <step>`, in
Ka0sAddonsCommonTasks `docs/2026-09-23-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/06_SMOKE_TESTS.md`,
whose `RESUME.md` §5 leaves its sessions owed). Two kinds: checks the old suite or that plan marked as
never run, unconfirmed or with an empty Result, and checks this rewrite added or corrected against
the code (a corrected check has not been run as written). Sign one off on its own `Result:` line, then
remove its row here.

From that plan, these have a pass on record and are not listed: 06 MM.12, the MM-20 after capture
(PASS 2026-09-24); 06 P.6 and the `/reload` half of 06 MM.13 (INSTALL-5, and the `/reload` clause
of INSTALL-4, which is listed only for its own correction; recorded 2026-09-24; the roster bound
rests on MM-21's headless case); the Multi Meters half of 06 X1.3 (the clamp, recorded 2026-09-24);
06 X1.4 and the disabled half of 06 MM.5 (SLASH-13, SLASH-14; PASS 2026-09-25 after M6); the tab
half of 06 MM.10 (PANEL-4 and PANEL-42, the owner's 2026-09-26 run of the Windows page checks). 06
Q.4 was the alternative to MM.12 and was not needed. 06 MM.14 asked for a full pass of the old suite;
the steps that session added are listed here by ID.

| ID | Origin | Why it is owed |
|---|---|---|
| INSTALL-4 | §2 | Corrected: the column set replaces a per-column width, which no longer exists |
| INSTALL-6 | §22 step 4 | Corrected: `schemaVersion` has advanced, rather than being 2 |
| INSTALL-7 | §23 step 4 | Corrected: the control color modes live on Header → Button style |
| INSTALL-8 | §34 step 4 | Corrected: `schemaVersion` is at least 14, rather than exactly 14 |
| INSTALL-9 | 06 MM.1 (MM-16, MM-13, MM-12) | New: the v15 to v16 upgrade, never run |
| SLASH-3 | §14 | New verbs in the sweep: `diagnostics`, `profile`, `export` and an unknown word |
| SLASH-4 | §14, §26 `/mm export` | New: the `profile` row |
| SLASH-7 | §14; 06 MM.4 (MM-09) | Corrected: the ordinal path answers *Setting not found*, and an out-of-range scale is clamped, not refused; new: a validated row's refusal, never run |
| SLASH-9 | §14 | Corrected: the by-name example is `Multi Meters #1`; no window is named Meter |
| SLASH-10 | §14; 06 MM.11 (MM-22) | Never run: the lock lines through the locale |
| SLASH-11 | §6 | Corrected: the list line's shape, the one-word copy source, no confirmation on the CLI delete |
| SLASH-12 | §4; 06 X1.6 | Never run: `/mm config` in combat |
| PANEL-11 | §29 (`M4-01`) | "NOT YET RUN" |
| PANEL-13 | §4 | Corrected: Tooltip's tab names and order; each tab's rows restated from the code (Title text holds the name's face, not the name; Button style's three headings; the hide rules add solo, vehicles and flight paths, and combat is its own tab); the close row's path is `window.frame.closeButton` |
| PANEL-15 | §4 | Corrected: the General page has three tabs |
| PANEL-18 | §4, §6; 06 MM.2 (MM-16), 06 MM.8 (MM-14) | Corrected: the `/mm set global.minimap.shown` half and the `/reload`; never run |
| PANEL-20 | §4 | Corrected: Header → Title text offers Class / Custom only |
| PANEL-23 | §4 (`M3-02`); 06 L.10 (LK-24) | "Not yet run"; new: each font name in its own face |
| PANEL-24 | §30 (`M4-07`) | "NOT YET RUN" |
| PANEL-25 | §4 | Corrected: General and Windows both carry Defaults |
| PANEL-30 | §4 (LibKa0s v1.46.1); 06 X1.6 | "not yet run"; new: an action-bar click in combat raises no taint line |
| PANEL-40 | §5 | Corrected: the order and full shape of the `[Blocks]` lines |
| PANEL-43 | §5 (LK-21); 06 MM.10 (MM-18), 06 L.9 (LK-21) | Never run: the library drag |
| PANEL-45 | 06 MM.9 (MM-17) | New: the color picker's throttle |
| PANEL-46 | 06 L.12 (LK-27), 06 X1.2 | New: switching windows leaks nothing |
| PANEL-47 | New (LibKa0s v1.67.0, 2026-10-02, CA-MM-NM) | The panel with `addonName` on the Options descriptor (LibKa0s#42), never run in a client |
| PROFILE-5 | §4, §16 | Corrected: the fresh window is **Multi Meters #1** |
| PROFILE-6 | §16 | Corrected: the popup's wording, and only `[Set]` lines are counted |
| PROFILE-9 | §15 (`M2-18`) | "Not yet run" |
| PROFILE-10 to PROFILE-17 | New | The `/mm profile` verb (SP-MM-02), never run in a client |
| STATE-1 | §14 | New: `/mm diagnostics` and `/mm profile` among the verbs that answer while disabled |
| STATE-3 | §3 SM-01; 06 MM.6 (MM-01) | Never run |
| STATE-4 | §3 SM-03; 06 MM.6 (MM-01) | Never run |
| STATE-5 | §3 SM-02, §14 SM-02; 06 MM.5 (MM-02), 06 MM.6 (MM-01) | Corrected: the suspension starts at `/mm perf measure b`, not at `start`; never run in the plan either |
| STATE-9 | §3; 06 MM.11 (MM-22) | Corrected: the `/mm test` lines; never run |
| STATE-11 | §3 | Corrected: the General page's box is under the combat cover, so only `/mm test` and the minimap menu are routes |
| WIN-5 | §1 header controls | Corrected: the Header control names |
| WIN-12 | §26 control | Corrected: the toggle is on Header → Title bar |
| WIN-16 | §1 header controls | Corrected: the dialog asks *Clear every recorded combat session?* with Yes / No; the meter-data warning is not in it |
| WIN-24 | Corrected (LibKa0s v1.67.0, 2026-10-02, CA-MM-02) | The grip is the library's: 16 px, one pixel inside the corner |
| WIN-25 | §3 | Corrected: the window drags by its title bar, and the cells answer the mouse locked or unlocked |
| WIN-26 | §3, §16; 06 MM.11 (MM-22) | Corrected: the singular and plural lines; never run |
| WIN-28 | §6; 06 MM.8 (MM-14) | Corrected: the refresh interval is addon-wide, not a per-window difference; only the band's window moves, never run |
| WIN-31 | §6, §16; 06 MM.8 (MM-14) | Never run: one refresh and one `[Set]` line per copy |
| WIN-37, WIN-38 | New (LibKa0s v1.67.0, 2026-10-02, CA-MM-02) | The library resize grip on the art frame (strata, alpha, one save per release) and after a rule-driven hide, never run in a client |
| VIS-5 | §7 | Corrected: the vehicle rule ships off and is now switched on first |
| GRID-3 | §8 | Corrected: Bars → Text style and Bars → Bar |
| GRID-7 | §19 step 6 (issue #26) | "Unconfirmed in game" |
| GRID-9 | §20 step 2 | Corrected: the default name cap is 15 |
| GRID-12 | §9 SM-04; 06 Q.5 (MM-03) | Corrected: Frame → Row → Maximum rows and Always show yourself; never run in the plan either |
| GRID-13 | §9 | Corrected: each sort mode is set with `/mm set window.data.sortMode` |
| GRID-17 | §12 | Corrected: pets have their own rows unless **Merge pets into their owner** is ticked first; it ships off |
| GRID-18 | §12 "Also worth checking" | Corrected: the fold needs **Merge pets into their owner** ticked |
| GRID-21 | §13 | Corrected: the empty state comes from the header reset; a fresh login keeps the old fights |
| GRID-31 | §21 step 8 | Corrected: the meter reset is the header control's |
| TIP-6 | §10 | Corrected: the row line also needs `/mm debug tooltip` |
| TIP-10 | §10; 06 MM.7 (MM-05) | Never run |
| TIP-11 | §10 | Corrected: Death timestamps is on Bars → Text content |
| TIP-23 | §4, §24 | Corrected: there is no "At cursor" anchor |
| TIP-26 | §24 | Corrected: Bar spacing ships at 1 |
| EXPORT-20 | §26 whisper | Corrected: a blank whisper is refused with a line |
| EXPORT-21 | §26 whisper | Corrected: a statement turned into a step |
| EXPORT-29 | §26 file | Corrected: 24 columns, and the header row is compared with LOC-1's |
| EXPORT-33 | §26 chat; 06 Q.6 (MM-04) | Corrected: the channel is **Self only**; there is no *Print to myself*; corrected: no notice line before the lines |
| EXPORT-38 | §26 chat; 06 Q.6 (MM-04) | Corrected: a Party export printed locally with the no-sender notice fails; never run |
| EXPORT-39 | §26 chat | Corrected: the list includes **Whisper my target** |
| EXPORT-48 | §26 chat | Corrected: the *There is nothing to export.* line, and the empty segment comes from the header reset, not a fresh login |
| EXPORT-53 | §26 `/mm export` | Corrected: the by-name example is `Multi Meters #1`; no window is named Meter |
| EXPORT-54 | §26 `/mm export` | Corrected: *No window named '…'.* |
| COMBAT-7 | §8 | Corrected: the step names the control and the command |
| COMBAT-13 | §9, §27 | Corrected: the `N of M` header strings |
| COMBAT-14 | §9 | Corrected: each sort mode is set with `/mm set` |
| COMBAT-17 | §9 | Corrected: the name sort is set by the Player header |
| COMBAT-27 | §12 | Corrected: the catch-up needs **Merge pets into their owner** ticked; it ships off |
| COMBAT-30 | New | Cell borders mid-pull, which `modules/Row_Border.lua` said the suite checked |
| DIAG-1 | §18 | Corrected: `sort=value/provider` mid-pull, and repeated passes folded into `(xN)` lines |
| DIAG-7 | §18; 06 Q.7 (MM-19), 06 L.8 (LK-20) | Corrected: `measure a`, `measure b` and `report`; `finish` prints no report; restored: `meterEvent`, `spellEvent` and `systemEvent` each with calls and ms, and the whisper `systemEvent` needs; *perf run FINISHED* then *addon RESUMED* in chat at `finish`; calls above zero, not total ms; the plan's bucket and parent steps never ran |
| DIAG-10 | §18 (issue #47) | "Unconfirmed in game" |
| DIAG-11 | §29 | "NOT YET RUN"; corrected: a bare `start` is stamped with the date and time, never `unlabeled` |
| DIAG-12 | §31 | "NOT YET RUN" |
| DIAG-15 | §35 step 4 | Corrected: the end marker carries the line count |
| DIAG-17 | §35 step 6; 06 L.7 (LK-19) | Corrected: the copy holds the newest lines in order; never run |
| DIAG-20 | §26 control | The atlas rung is "still unconfirmed" |
| DIAG-22 | §27 | Corrected: when `no identity pass has been measured` appears |
| DIAG-23 | §28 | Corrected: the refusal line includes its backticks |
| DIAG-26 to DIAG-30 | §37 MM-E1 to MM-E5 (2026-09-29) | Result empty |
| DIAG-31 | 06 MM.3 (MM-07), 06 X1.5 | New: the rejected-events line; corrected (LibKa0s v1.65.0, DG-MM-01): a name refused at login is held and written at `/mm debug on`, so no enable cycle is needed |
| DIAG-32 to DIAG-36 | New (LibKa0s v1.64.0, 2026-09-30) | The resizable console, copy windows and perf panel, never run in a client |
| DIAG-16 | Corrected (LibKa0s v1.64.0, 2026-09-30, DL-MM-03) | The report still lands with logging off, but now turns logging on, so the header reads `Debug: ON` afterwards |
| DIAG-37, DIAG-38 | New (LibKa0s v1.64.0, 2026-09-30, DL-MM-03) | The console's Diagnostics link, and diagnostics turning logging on for the session, never run in a client |
| DIAG-39 to DIAG-41 | New (LibKa0s v1.65.0, 2026-10-01, DG-MM-01) | The library's `[Cmd]` and `[Lifecycle]` lines, the at-enable queue and Clear's re-arm, never run in a client |
| DIAG-42 | New (LibKa0s v1.67.0, 2026-10-02, CA-MM-01) | The report's secret sentinel is now `Core.SECRET`, never run in a client |
| DEGRADED-1 | §17; 06 X2.11 | Never run |
| DEGRADED-2 | §17 | Corrected: the first line's full text, and each later line repeating the cause |
| DEGRADED-3 | §17; 06 X2.11 | Never run: a bare `/mm` answers |
| DEGRADED-8 | New | `/mm profile` with LibKa0s absent |
| DEGRADED-10 | New (LibKa0s v1.67.0, 2026-10-02, CA-MM-02) | No resize grip with LibKa0s absent, never run in a client |
| LOC-1 | §26 file | Corrected: the header has 24 columns, not 26 |
