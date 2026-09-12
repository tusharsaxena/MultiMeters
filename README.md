# Ka0s Multi Meters

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1690082)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-1804%2F1804_passing-green)

Most Damage meter addons show you one statistic at a time. This addon shows all of them in one grid — who kicked, who dispelled, who stood in the fire, who died. One row per player, one column per statistic.

The numbers are Blizzard's. Multi Meters asks the built-in meter for them and arranges them; it never touches the combat log, so it adds no additional computation to what the game is already doing.

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

On the first run after installing, a default window shows up unlocked, so drag it by the title bar and pull the bottom-right
corner to size it. Placing a meter between pulls is a pain because there is nothing in it to look
at, so `/mm test` fills every window with obvious placeholder rows and prints TEST in the header
while you work. Same command turns it off, `/mm lock` freezes everything once you are happy, and
`/mm reset-positions` rescues anything you have dragged off the edge of the screen.

`/mm toggle` hides and shows windows by name or all at once, and the × in the title bar closes
whichever one you clicked. You will get more out of the visibility settings, though: tell a window
which contexts it belongs in — dungeons and raids and nothing else, say — and which situations it
should get out of the way for, and you can stop thinking about it. Ten hide rules ship. Solo,
mounted, dead, on a flight path, and six more.

Seven controls can sit in the title bar — close, minimise, lock, settings, segment, reset, export —
and you pick which ones each window draws. The segment control is the three horizontal lines, and it
is the one people miss. Open it for every fight the game still holds, by name and length, Current and
Overall at the bottom; your pick sticks until you change it, reloads included.

Then there is the detail underneath the grid. Hovering a cell shows the spells behind that number;
the same on a name gives you everything tracked for the player. Click either to drill in, or click a
Deaths cell for the recap, which is usually the more interesting trip. For a second window, `/mm
window new`, then copy the settings across from the first rather than building them twice.

Everything else is configuration, and it lives in two places: the addon's own page under Settings →
AddOns in game, and `/mm` (or `/multimeters`), which prints the full command list.

## How it works

Blizzard's meter already tracks all of these and exposes them through an in-game API. Multi Meters asks it for the figures and lays them out as a grid, so what you read here is what the built-in meter would have told you. Nothing chews through the combat log a second time.

The one odd behaviour falls out of that. Midnight hands addons combat numbers as secret values — an addon can draw bars for a number without being able to read it — and the tag identifying which row a number belongs to is sealed with it. So the grid is built two ways. Out of combat, by identity. In combat, rows come from the game's own live ranking of the sort column, and everything else is matched onto them by class and spec. Two players sharing both cannot be separated, so their cells stay empty. The header says as much in gray.

## FAQ

| Question | Answer |
|----------|--------|
| Do I need Details or Skada? | No. It is not a plugin for another meter and does not read one. Blizzard's meter has to be switched on; that is the whole dependency. |
| Does it replace my damage meter? | It can. Add the Damage and Healing columns and the usual numbers sit next to the ones you would otherwise change windows to see. Plenty of people run both anyway. |
| Why is a cell empty mid-fight, and why is the header gray? | Midnight hides the tag the game normally gives addons for each row, for the length of the fight. Rows are still the live ranking; the other columns get matched onto them by class and spec, and anyone sharing both with someone else cannot be told apart. Those cells are left empty. The header keeps a running count of it, in the form `restricted — 10 of 18 share a class and spec`, so the figure matches the blank rows you can see. |
| Can nothing be done about that? | Not from an addon, no. We tried three ways and measured all three dead: the game refuses to look a row up by the sealed tag it just handed you, no other field it sends mid-fight separates two players of one spec, and the columns disagree about which of a duplicate pair they are even reporting on. Blank is what is left, and it is honest. |
| Can I look back at an earlier fight? | Yes. The three horizontal lines in the header list every fight the game still holds, by name and length, Current and Overall at the bottom. Your pick sticks across reloads. If the game drops that fight, the window quietly falls back to Current. |
| Can I have one window for damage and another for utility? | Yes. Make a second one on the Windows page and give it different columns. Almost every setting is per window. |
| Does it work in raids and PvP? | Yes. Visibility is per window, so you can have one that only appears in dungeons and another that only appears in arenas. |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| The window says the damage meter is unavailable | Blizzard's meter is off, or unavailable where you are standing. The window prints whatever reason the game gave. Switch the built-in meter on. |
| The window is empty and says it is waiting for combat data | Nothing has happened yet in the session you are looking at, which is normal between pulls. Pick Overall or an older fight from the segment control. No setting for this; the header already has the control. |
| The window only shows placeholder rows | Test mode is on. `/mm test`, or the General page. Unlocking has nothing to do with it — that used to switch preview on as a side effect, which made unticking Test mode look broken. The lock governs dragging now, nothing else. |
| I cannot open the settings while fighting | On purpose. Blizzard protects the settings machinery in combat and the panel would rather refuse than risk your action bars. It opens the second you drop out. |
| A pet has its own row and I wanted it folded into its owner | Separate rows is the default because it is exact in and out of combat. **Merge pets into their owner** on the General page folds them in, with one catch that is exactly why it is not the default: merging is addition, and the game will not let an addon add two combat numbers together mid-fight. A merged pet's damage goes missing until the pull ends. |
| I cannot find the window | `/mm reset-positions`. |
| Something looks wrong and you want to report it | `/mm debug on`, reproduce it, `/mm debug` to open the console, then copy the log into the issue. Add `/mm debug tooltip` if a tooltip is involved — that channel is off by default because a tooltip redraws on every mouse-over and its lines bury everything else in the buffer within seconds. |

## Issues and feature requests

Please raise them on GitHub:
<https://github.com/tusharsaxena/MultiMeters/issues>

## Version History

| Version | Date | Highlights |
|---|---|---|
| 1.0.0 | 2026-09-10 | First published release — Multi Meters is now on CurseForge<br>Fixed test mode drawing breakdown bars with no numbers on them<br>Roster rows now carry spec identity<br>Updated for game patch 12.1.0 |
| 0.1.0 | 2026-08-09 | First release. Multi-column single-frame group meter sourced from Blizzard's damage meter: Damage, Healing, Interrupts, Dispels, Avoidable Damage and Deaths; current/overall sessions; multiple independently configured windows with copy-settings-from; tooltips, cell drill-down and death recap; per-window visibility. |

## Credits

The debug console uses [JetBrains Mono](https://www.jetbrains.com/lp/mono/), licensed under the SIL
Open Font License 1.1, and the header controls draw [Open Iconic](https://github.com/iconic/open-iconic)
(MIT). Both ship inside the bundled LibKa0s payload, with their license text beside them.

