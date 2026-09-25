# Hard-coded texture paths

> Ka0s Multi Meters. Part of the doc set mapped in
> [ARCHITECTURE.md](ARCHITECTURE.md#documentation-map). The census below records a decision per site;
> the three sites that decline a mark the catalog does carry are ratified in the hub's
> [Documented deviations](ARCHITECTURE.md#documented-deviations), the register's single home.

`library-stack-§8` makes the shared catalog the addon's **vocabulary for marks**: where the addon
needs one it uses `LibKa0s-Media-1.0`'s, ships no private copy, and draws no local substitute. The
2026-09-07 collection review found the rule bypassed across all nine addons and could not say by how
much — three passes produced three different figures, and the one that was believed was believed
because it was the biggest, not because anyone could reproduce it. So the number below arrives with
the command that produced it and the scope that command runs over, and this table is what an audit
reads instead of measuring again.

**Fifteen lines carrying fifteen paths, thirteen distinct file/path pairs, measured 2026-09-16** over
the tracked `*.lua` this repository authors — `libs/` excluded because vendored code is audited where
it is written, `tests/` excluded because a path in a fixture is an assertion about a string rather
than chrome any player sees:

```
git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/' \
  | xargs grep -nE '("|\[\[)Interface\\'
```

**The quote is part of the pattern, and that is the correction this section exists to record.** The
remediation plan's own per-repo census put this addon at **8**, which is exactly what a
`grep 'Interface\\\\'` returns here: the escaped form inside a double-quoted string, and nothing
else. Seven of this repository's paths are written as Lua **long-bracket** literals —
`[[Interface\ICONS\…]]`, the form that needs no escaping and is what `modules/` reaches for — and a
pattern keyed on the doubled backslash cannot see any of them. The plan's prose already knew about
two of the seven, naming "the chat size-grabber" and "class circles" among the chrome the catalog
cannot answer for, so the narrative and the tally were measured with different hands. That is the
same defect the cluster was filed for, one layer down: the scope was written out and the *pattern*
was not.

Dropping the quote widens the match to **19** lines, and the four it adds are prose, not paths:
`core/Compat.lua:593` and `modules/Window_Header.lua:78` both quote `UI-SortArrow-Up` while explaining that
it does not exist, `core/MediaSetup.lua:27` names the `Interface\AddOns\` prefix in the argument for
taking the folder name from the vararg, and `core/Namespace.lua:137` does the same. A comment naming
a texture is not a texture, so they are named here rather than given rows — and naming them is what
makes the subtraction from 19 checkable by a reader who runs the looser form.

## The census

| File | Path | Disposition |
|---|---|---|
| `core/Constants.lua` | `Interface\AddOns\MultiMeters\media\logos\multimeters.logo.tga` | The addon's **own shipped art**, which no icon catalog is meant to replace (`layout-§3`). The reasoning above the line is about the extension, not the hard-coding: `.tga` is the only form the client loads, and the `.png` master beside it is packaging. |
| `modules/Export_Modal.lua` | `Interface\Buttons\WHITE8x8` | The flat 1px fill `standalone-windows` **mandates** for the shared window edge — a client primitive, not a mark, so outside what the catalog answers for. `LibKa0s/Core.lua:91,94` reaches for the same file for the same reason. Two sites, one path. |
| `core/Constants.lua` | `Interface\AddOns\MultiMeters\media\logos\multimeters.logo.128.tga` | The addon's **own shipped art** again, in its icon form. `layout-§4` requires this exact file and `launcher-§4` requires it in three places at once -- the TOC's `## IconTexture`, the minimap button and a broker display -- so one path is read by `core/LauncherSetup.lua` and restated in `MultiMeters.toc`. A catalog mark here is the thing `launcher-§4` forbids outright: a borrowed icon makes the addon look like something else in the one list where the player is choosing what to turn off (**anti-pattern #82**). Replaced `modules/Minimap.lua`'s borrowed `achievement_challengemode_gold` when the launcher was adopted. |
| `modules/Row.lua` | `Interface\TargetingFrame\UI-Classes-Circles` | The client's **class atlas**, cropped by coordinate. The catalog carries no class art and `library-stack-§8` sends a missing mark upstream rather than into an addon — but twelve class circles are Blizzard's own data, not a Ka0s glyph, and they change when the game's classes do. |
| `modules/Row.lua` | `Interface\TargetingFrame\UI-StatusBar` | Last-resort bar fill after an LSM fetch answers nothing. The catalog **does** ship bar textures (`library-stack-§8`), and they reach LSM through `core/MediaSetup.lua`'s `RegisterLSM` — so the only load that reaches this line is one where the payload is absent, and on that load the catalog's textures never reached LSM either. A fallback that needs the thing that is missing is not a fallback. |
| `modules/Tooltip.lua` | `Interface\ICONS\INV_Misc_QuestionMark` | The client's canonical unknown-item mark, standing in for a spellID it cannot resolve. `library-stack-§8` has no equivalent and could not sensibly grow one: the whole point of this texture is that every WoW player already reads it as "missing", which is a meaning the client owns and a Ka0s glyph cannot borrow. |
| `modules/Tooltip.lua` | `Interface\ICONS\Ability_Hunter_FocusedAim` | **Register row** in the hub's [Documented deviations](ARCHITECTURE.md#documented-deviations) — `library-stack-§8`, ratified 2026-09-23. The icon every TARGET line wears, and a site where the catalog **does** have a candidate — `target`. This slot sits in a column of colored Blizzard spell icons, and `library-stack-§8` requires catalog art to be white with its shape in the alpha channel, so the one line drawing a Ka0s glyph would be the one line that looked foreign. |
| `modules/Tooltip.lua` | `Interface\Buttons\WHITE8X8` | The fill `standalone-windows` mandates, here as the bar fallback for a window with no texture configured — a `StatusBar` with no texture draws nothing, so a tint alone is not a fallback. The casing differs from the `modules/Export_Modal.lua` row and from nothing else; `LibKa0s` spells it both ways too (`Core.lua:91` / `Widgets.lua:44`), WoW paths are case-insensitive, and it is recorded here so nobody spends a commit "fixing" it. |
| `modules/Window.lua` | `Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up` | **Register row** in the hub's [Documented deviations](ARCHITECTURE.md#documented-deviations) — `library-stack-§8`, ratified 2026-09-23. The corner resize grip. The catalog carries `resize`, but it is a **glyph** — one state, one color; this is a two-state pair (`-Up` and the `-Highlight` below) that a player already reads in every chat window. |
| `modules/Window.lua` | `Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight` | **Register row** — the hover half of the pair above, under the same row. The catalog publishes no hover variant of anything, so adopting it would mean drawing one locally, which is the thing the rule forbids. |
| `settings/ColumnBlocks.lua` | `Interface\RaidFrame\ReadyCheck-Ready` | **Register row** in the hub's [Documented deviations](ARCHITECTURE.md#documented-deviations) — `library-stack-§8`, ratified 2026-09-08 on parity with ConsumableMaster's priority list. |
| `settings/ColumnBlocks.lua` | `Interface\RaidFrame\ReadyCheck-NotReady` | **Register row** — the other half of the same pair and the same row. |

**The paths are the invariant, not the count.** `tests/test_texture_paths.lua` reads the tracked set
and this table and compares them in both directions: a file that grows a hard-coded path nobody
listed turns the suite red, and so does a row for a path that has gone. It pins the distinct
file/path pair rather than a line number or an occurrence count, because those move on every ordinary
edit while the arrival of a *new* path is the only event this rule has an opinion about. It also
asserts that every site declining a catalog mark the payload does carry — the `ColumnBlocks.lua` pair,
the tooltip's TARGET glyph and the window's size-grabber pair — has a `library-stack-§8` row in the
hub's register citing the lines it is declared on, so "register row" stays a reference rather than
becoming a phrase.
