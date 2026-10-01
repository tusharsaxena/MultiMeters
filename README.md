# Ka0s Multi Meters

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1690082)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-2158%2F2158_passing-green)

Most damage meter addons show you one statistic at a time. Multi Meters puts all of them in one grid: who kicked, who dispelled, who stood in the fire, who died. Every player gets a row and every statistic gets a column.

The numbers are Blizzard's. Multi Meters asks the built-in meter for them and arranges them. It never touches the combat log, so it adds no work on top of what the game is already doing.

## Screenshots

**_Main window_**

![Main window](https://media.forgecdn.net/attachments/1937/48/multimeters-screenshot-01-png.png)

**_Summary tooltip_**

![Summary tooltip](https://media.forgecdn.net/attachments/1937/49/multimeters-screenshot-02-png.png)

**_Spell breakdown tooltip (in the main window)_**

![Spell breakdown tooltip (in the main window)](https://media.forgecdn.net/attachments/1937/50/multimeters-screenshot-03-png.png)

**_Spell breakdown_**

![Spell breakdown](https://media.forgecdn.net/attachments/1937/51/multimeters-screenshot-04-png.png)

**_Death recap_**

![Death recap](https://media.forgecdn.net/attachments/1937/52/multimeters-screenshot-05-png.png)

## Usage

The first time you run it after installing, you get a default window, already unlocked. Drag it by the title bar and pull the bottom-right corner to size it. Placing an empty meter between pulls is a pain, so `/mm test` fills every window with placeholder rows and prints TEST in the header while you work. It switches itself off the moment you pull, and `/mm lock` freezes everything once you're happy with the layout.

Setting a window up takes four steps. Most of it happens on the Windows page, where the Active window dropdown at the top picks the window you're working on and the list down the left side takes you through the rest.

- Pick your columns. The Columns entry lists every statistic the game offers, and the ticked ones are the columns this window shows. A new window starts with Damage, Healing, Interrupts, Dispels, Avoidable Damage and Deaths. Click a block to show or hide it and drag it by its handle to reorder. Columns only change out of combat.
- Decide when it shows. On Visibility you tell the window which content it belongs in (dungeons and raids and nothing else, say) and which situations it should get out of the way for. There are ten hide rules: solo, mounted, dead, on a flight path, and six more. Set it once and you can stop thinking about it.
- Choose your header controls. The title bar has room for seven: close, minimize, lock, settings, segment, reset and export, and the Header entry's Controls tab picks which ones this window draws. The segment control is the three horizontal lines, and it's the one people miss. It picks which fight the window shows, and your pick sticks through a reload.
- Dig into the numbers. Hover a cell to see the spells behind it, or hover a name to see everything tracked for that player. Click either one to drill in. Clicking a Deaths cell opens the recap instead, which is usually the more interesting trip.

Want a second window? Click **New window** on the Windows page, or run `/mm window new`, then use Copy settings from instead of building it twice. The minimap button opens the settings on a left-click. A right-click gives you four switches: Enabled, Locked, Test mode and Show window.

Everything else is on the addon's page under Settings → AddOns, and `/mm` (or `/multimeters`) on its own opens it. `/mm help` prints the full command list.

## How it works

Blizzard's meter already tracks all of these and exposes them through an in-game API. Multi Meters asks it for the figures and lays them out as a grid, so what you read here is what the built-in meter would have told you. Nothing chews through the combat log a second time.

That design is also where the one odd behavior comes from. In Midnight, addons get combat numbers as secret values: an addon can draw a bar for a number without being able to read it. The tag that says which row a number belongs to is sealed the same way. So Multi Meters builds the grid in two different ways. Out of combat, it matches rows by identity. In combat, the rows come from the game's own live ranking of the sort column, and every other column is matched onto them by class and spec. If two players share both, there's no telling them apart, so their cells stay empty and the header says so in gray.

## FAQ

| Question | Answer |
|----------|--------|
| Do I need Details or Skada? | No. It isn't a plugin for another meter and doesn't read one. The only thing it depends on is Blizzard's meter, which has to be switched on. |
| Does it replace my damage meter? | It can. Add the Damage and Healing columns and the usual numbers sit right next to the ones you'd otherwise switch windows to see. Plenty of people run both anyway. |
| Why is a cell empty mid-fight, and why is the header gray? | For the length of a fight, Midnight hides the tag the game normally gives addons for each row. The rows still follow the live ranking, and the other columns get matched onto them by class and spec. When a player shares both with someone else, the two can't be told apart, so those cells are left empty. The header keeps a running count, in the form `restricted — 10 of 18 share a class and spec`, so the figure matches the blank rows you can see. |
| Can nothing be done about that? | Not from an addon. We tried three ways and measured all three, and none of them work. The game refuses to look a row up by the sealed tag it just handed you. No other field it sends mid-fight separates two players of one spec. And the columns disagree about which of a duplicate pair they're even reporting on. A blank cell is what's left, and at least it's honest. |
| Can I look back at an earlier fight? | Yes. The three horizontal lines in the header list every fight the game still holds, by name and length, with Current and Overall at the bottom. Your pick sticks across reloads. If the game drops that fight, the window quietly falls back to Current. |
| Can I have one window for damage and another for utility? | Yes. Make a second one on the Windows page and give it different columns. Almost every setting is per window. |
| Does it work in raids and PvP? | Yes. Visibility is per window, so you can have one that only appears in dungeons and another that only appears in arenas. |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| The window says the damage meter is unavailable | Blizzard's meter is off, or it isn't available where you're standing. The window prints whatever reason the game gave. Switch the built-in meter on. |
| The window is empty and says it is waiting for combat data | Nothing has happened yet in the session you're looking at, which is normal between pulls. Pick Overall or an older fight from the segment control. There's no setting for this, because the header already has the control. |
| The window only shows placeholder rows | Test mode is on. Turn it off with `/mm test` or the **Test mode** box on the General page. Starting a fight turns it off too. Unlocking has nothing to do with it. It used to: unlocking switched preview on as a side effect, which made unticking Test mode look broken. Now the lock only governs dragging. |
| I cannot open the settings while fighting | That's on purpose. Blizzard protects the settings machinery in combat, and the panel would rather refuse than risk your action bars. It opens the second you drop out. |
| A pet has its own row and I wanted it folded into its owner | Pets get separate rows by default because that's exact both in and out of combat. **Merge pets into their owner** on the General page folds them in, with one catch, and the catch is exactly why it isn't the default. Merging means adding, and the game won't let an addon add two combat numbers together mid-fight, so a merged pet's damage goes missing until the pull ends. |
| I cannot find the window | `/mm reset-positions`. |
| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. If a tooltip is involved, type `/mm debug tooltip` before you reproduce it. That channel is off by default because a tooltip redraws on every mouse-over, and within seconds its lines bury everything else in the buffer. |

## Reporting a bug

- Type `/mm debug on` and reproduce the bug.
- Type `/mm diagnostics`.
- If the debug window isn't open, open it with `/mm debug`. Press **Copy**, copy the entire output, and include it with your bug report.

The report is added after the debug trace in the same window, so one copy carries both.

## Issues and feature requests

Please raise them on GitHub:
<https://github.com/tusharsaxena/MultiMeters/issues>

## Version History

| Version | Date | Highlights |
|---|---|---|
| 1.1.0 | 2026-09-27 | - Settings are easier to find your way around: three pages (General, Windows and Profiles), and the Windows page has an Active window picker and a side list with its own Defaults button<br>- New minimap button: left-click opens settings, right-click switches Enabled, Locked, Test mode and Show window, and hovering shows the version and status<br>- Bars slide to their new length instead of snapping on every refresh<br>- Test mode ends when combat starts and won't start mid-fight. A bare `/mm` opens settings, `/mm enable` and `/mm disable` turn the addon on and off, and `/mm resetall` asks first<br>- Fixed "Always show yourself" dropping you off the window when you rank below the visible rows, and `/mm diagnostics` now prints a full report to attach to bug reports |
| 1.0.1 | 2026-09-11 | - Re-published 1.0.0 unchanged (a rebuild trigger); the TOC still read 1.0.0 |
| 1.0.0 | 2026-09-10 | - First published release — Multi Meters is now on CurseForge<br>- Fixed test mode drawing breakdown bars with no numbers on them<br>- Roster rows now carry spec identity<br>- Updated for game patch 12.1.0 |
| 0.1.0 | 2026-08-09 | - First release. Multi-column single-frame group meter sourced from Blizzard's damage meter: Damage, Healing, Interrupts, Dispels, Avoidable Damage and Deaths; current/overall sessions; multiple independently configured windows with copy-settings-from; tooltips, cell drill-down and death recap; per-window visibility. |

## Credits

The debug console uses [JetBrains Mono](https://www.jetbrains.com/lp/mono/), licensed under the SIL
Open Font License 1.1, and the header controls draw [Open Iconic](https://github.com/iconic/open-iconic)
(MIT). Both ship inside the bundled LibKa0s payload, with their license text beside them.

