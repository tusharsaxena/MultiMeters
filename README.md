# Ka0s Multi Meters

![WoW](https://img.shields.io/badge/WoW-Midnight_12.0.7-purple)
![Version](https://img.shields.io/badge/Version-0.1.0-blue)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-1745%2F1745_passing-green)

Most meters show you one number at a time. This one puts the whole group in a grid — who kicked, who
dispelled, who stood in the fire, who died. A row per player, a column per statistic.

The numbers are Blizzard's. Multi Meters asks the built-in meter for them and arranges them; it never
touches the combat log, so it adds nothing to what the game is already doing.

```
Player      | Damage       | Healing     | Int | Disp | Avoid Dmg | Deaths
Rukhmar     | 12.4M  188K  | 0.9M   14K  |  3  |  1   |    412K   |   1
Thundertusk |  8.1M  123K  | 6.2M   94K  |  1  |  0   |    180K   |   0
Ashvane     |  6.7M  102K  | 0.2M    3K  |  4  |  2   |     22K   |   0
```

Every column is the same width. Names carry class colour. The per-second figure sits next to the
total with no `/s` on it, because the header above already said what the column is.

That two-figure grid is one setting away from the default, which shows a single number per cell: the
rate on Damage and Healing, the plain total everywhere that has no rate. Set **Right text** to
**Absolute value** on Bars → Text content.

> **Worth knowing before you install it: in a fight the grid is partial.** Midnight seals the tag
> that says which row a number belongs to, so mid-fight the addon matches columns onto rows by class
> and spec instead. Two players who share both are indistinguishable, and their cells are left empty.
>
> Empty is the point. The alternative is putting a number in that cell that might belong to the other
> player, and you would have no way of telling. A gap you can see beats a lie you cannot. How much
> you lose depends on the group: one measured 18-player pull left 10 of its rows blank until it
> ended, where a dungeon would usually lose none. The sort column stays live and correct throughout,
> the header prints the count in gray, and the whole grid fills in the moment combat drops.

## What's new in 0.1.0

The first release.

- Damage, Healing, Interrupts, Dispels, Avoidable Damage and Deaths, as columns of one grid. Every
  cell has a bar and two text slots, and each slot takes the same six values, so "just the rate",
  "the total and the rate", "a bar with no text" and "share of the column" are one dropdown apart.
- Current pull or the whole run, switched from the window header.
- As many windows as you want, each configured on its own. Copy-settings-from means the second one
  is not a re-run of the first by hand.
- Hover a cell for the spells behind the number, or a name for everything tracked on that player. A
  Damage cell will also list which enemies they hit. Click to drill in; click a Deaths cell for the
  recap.
- Export from the title bar: the fight as CSV for a spreadsheet, or a ranked top-N to chat. To
  yourself by default, so a misclick cannot reach the raid.
- Per-window visibility, with seven contexts to appear in and ten rules that hide it — solo,
  mounted, dead, in or out of combat, and the rest.

## Screenshots

None yet. Nobody has photographed it in a live run. Next version.

## Usage

Install it and a window turns up, unlocked, so drag it by the title bar and pull the bottom-right
corner to size it. Placing a meter between pulls is a pain because there is nothing in it to look
at, so `/mm test` fills every window with obvious placeholder rows and prints TEST in the header
while you work. Same command turns it off, `/mm lock` freezes everything once you are happy, and
`/mm reset-positions` rescues anything you have dragged off the edge of the screen.

`/mm toggle` hides and shows windows by name or all at once, and the × in the title bar closes
whichever one you clicked. You will get more out of the visibility settings, though: tell a window
which contexts it belongs in — dungeons and raids and nothing else, say — and which situations it
should get out of the way for, and you can stop thinking about it. Ten hide rules ship, covering the
usual suspects. Solo, mounted, dead, on a flight path.

Seven controls can sit in the title bar — close, minimise, lock, settings, segment, reset, export —
and you pick which ones each window draws. The segment control is the three horizontal lines, and it
is the one people miss. Open it for every fight the game still holds, by name and length, Current and
Overall at the bottom; your pick sticks until you change it, reloads included.

Then there is the detail underneath the grid. Hovering a cell shows the spells behind that number;
the same on a name gives you everything tracked for the player. Click either to drill in, or click a
Deaths cell for the recap, which is usually the more interesting trip. Want a second window? `/mm
window new`, then copy the settings over from the first rather than building them twice.

The rest is configuration. It is on the addon's page under Settings → AddOns in game, and `/mm` (or
`/multimeters`) prints the full command list.

## How it works

Blizzard's meter already tracks all of this. Multi Meters asks it for the figures and lays them out
as a grid, so what you read here is what the built-in meter would have told you. Nothing chews
through the combat log a second time.

The one odd behaviour falls out of that. Midnight hands addons combat numbers sealed — an addon can
draw a number without being able to read it — and the tag identifying which row a number belongs to
is sealed with it. So the grid is built two ways. Out of combat, by identity. In combat, rows come
from the game's own live ranking of the sort column, and everything else is matched onto them by
class and spec. Two players sharing both cannot be separated, their cells stay empty, and the header
says as much in gray.

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
| 0.1.0 | 2026-08-09 | First release. Multi-column single-frame group meter sourced from Blizzard's damage meter: Damage, Healing, Interrupts, Dispels, Avoidable Damage and Deaths; current/overall sessions; multiple independently configured windows with copy-settings-from; tooltips, cell drill-down and death recap; per-window visibility. |

## Credits

The debug console uses [JetBrains Mono](https://www.jetbrains.com/lp/mono/), licensed under the SIL
Open Font License 1.1, and the header controls draw [Open Iconic](https://github.com/iconic/open-iconic)
(MIT). Both ship inside the bundled LibKa0s payload, with their license text beside them.
