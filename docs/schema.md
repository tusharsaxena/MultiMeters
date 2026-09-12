# Saved variables and the settings schema

Two saved-variables are declared in `MultiMeters.toc`:

| Global | Owner | What it holds |
|---|---|---|
| `MultiMetersDB` | AceDB-3.0, assembled in `core/Database.lua` | every setting — the window registry, the id counter, the minimap table, and the account-wide schema version |
| `MultiMetersPerfDB` | `LibKa0s-Perf-1.0`, wired in `core/PerfSetup.lua` | `/mm perf` A/B capture records |

`MultiMetersPerfDB` sits **outside** the profile tree on purpose, and it is not merely "a second
table for tidiness". A capture record is diagnostics, not configuration: it describes one measured
session on one machine, and it means nothing under a different profile. Folding it into
`db.profile` would make a profile switch appear to delete captures and a profile copy appear to
duplicate them, and it would put library-owned bytes inside the tree `NS.ValidateSchema` and the
Defaults sweep both walk. Nothing in this addon reads or writes it directly — the library owns its
shape, and deleting it loses captures and nothing else.

Everything below is about `MultiMetersDB`.

---

## `db.global` — account-wide

```lua
db.global = {
    schemaVersion = 13,    -- CURRENT_DB_VERSION in core/Database.lua
}
```

The version is **addon-wide rather than per-profile** (`savedvariables-§1`), so a migration runs
once per account instead of once per profile. `NS:RunMigrations()` walks it forward one step at a
time out of the `migrations` table in `core/Database.lua`, and is called from `NS:InitDB()` and
again from every AceDB profile callback (changed / copied / reset).

**Twelve steps are wired today**, `migrations[1]` through `migrations[12]`, walking an account from
the shipped v1 shape to v13. Each is one line of the header block at the top of
`core/Database.lua`, and each is named where the key it moved is documented below:

| Step | What it does |
|---|---|
| v1 → v2 | every column becomes one uniform width |
| v2 → v3 | the three row-icon toggles collapse into one |
| v3 → v4 | the export channel `AUTO` is retired |
| v4 → v5 | `mergePets` and `throttle` lift from per-window to addon-wide |
| v5 → v6 | the two row-background keys nothing ever read are pruned |
| v6 → v7 | four class-colour booleans become three-way colour modes |
| v7 → v8 | the four header keys that restated what was on screen are pruned |
| v8 → v9 | the colour mode comes off the title bar's background |
| v9 → v10 | the `CURSOR` tooltip anchor is retired |
| v10 → v11 | the colour mode comes off the title bar's text |
| v11 → v12 | the column array stops being a chosen subset and becomes the full catalog, ticked |
| v12 → v13 | the title-bar toggle moves onto the header, and the two control colour booleans become modes |

Adding a v14 is two edits and no bootstrap change:

```lua
migrations[13] = function(db) ... end       -- the runner stamps the version
local CURRENT_DB_VERSION = 14
```

**Bump the version only for a non-additive change** — a rename, a restructure, a type change.
Adding a new leaf setting or a new window config group needs no bump: AceDB's defaults merge
absorbs the profile-level ones and `Database.EnsureWindowShape` absorbs the per-window ones.

### Why normalization is shape-driven and not version-gated

`Database.SeedWindows` runs **unconditionally**, after the version walk, on every Init and every
profile swap. It does not ask "is this account older than v2"; it asks "is this key missing".

That is not belt-and-braces, it is the only question with a reliable answer. AceDB's defaults merge
backfills `db.global.schemaVersion` to the current value the moment `db.global` is first touched —
so an account that has never seen a migration reads as already-current, and a version-gated step
would be skipped entirely, silently, on exactly the profile that needed it.

---

## `db.profile` — the profile tree

The whole thing:

```lua
db.profile = {
    enabled      = true,      -- master enable. Off = no window drawn, no provider read.
    windows      = { },       -- an ARRAY of window config tables, in picker order
    nextWindowId = 1,         -- monotonic id source; ids are never reused
    minimap      = { hide = false },   -- LibDBIcon-1.0 owns this table's shape
    master       = {                   -- options-ui-§15's Master controls tab
        visibility = "always",         -- always | inCombat | outOfCombat | never
        scale      = 1.0,              -- MULTIPLIED into every window's own scale
        alpha      = 1.0,              -- MULTIPLIED into every window's own alpha
        locked     = false,            -- ORed with every window's own lock
    },
    data         = {                   -- how the meter is read, addon-wide
        mergePets = false,             -- a pet's own row, or added to its owner's
        throttle  = 0.25,              -- seconds between refreshes
    },
    export       = {                   -- how the player last exported a segment
        metric    = "",                -- a Constants.STATS key, or "" for
                                       -- "match the exporting window's sort column"
        channel   = "SELF",            -- a Constants.EXPORT_CHANNELS key
        whisperTo = "",                -- meaningful only while channel is WHISPER
        lines     = 5,                 -- ranked lines per chat export, 1..MAX_ROWS
    },
}
```

Seven keys, and that is the design working rather than the profile being thin. A window is an
**instance, not a singleton** (design §6): there are no global display settings, so `frame`,
`header`, `rows`, `bars`, `text`, `icons`, `tooltip`, `visibility`, `columns` and `data` all live
inside one window's config. What is left at profile level is the handful of things that cannot
sensibly differ between windows.

### `windows` is an array, and it is empty in the defaults

`defaults/Profile.lua` ships `windows = {}` and `core/Database.lua` seeds exactly one window into
it. The seed **cannot** be a default: AceDB's defaults merge would fold a default window back into
a profile the user had deleted their last window from, resurrecting it on every login with no way
to refuse it. So the seed lives in `Database.SeedWindows`, which detects "brand new" by an **empty
registry** rather than by a version — the same shape-driven rule as above.

`Database.GetWindows()` is the one traversal seam; every consumer that reads the registry goes
through it, and every consumer that *mutates* it at runtime goes through
`modules/WindowManager.lua`, which is the sole sender of `WINDOWS_CHANGED`. The one other writer is
the load pass: `Database.SeedWindows` above, reached only through `NS:RunMigrations` at
initialization (`NS:OnInitialize` and `NS:InitDB`) and from AceDB's profile callbacks.
[ARCHITECTURE.md](ARCHITECTURE.md#settings-schema) names both, as `architecture-§5` requires.

### The window registry and its writer

`architecture-§5` separates a write to a schema-row path, which goes through `NS.SetByPath`, from the
membership of a **structural registry**: a collection the player creates and deletes members of,
which no row path can name. The windows are this addon's one registry.

- **Storage keys.** `db.profile.windows` is an array whose position is the display order. Each entry
  carries its `id` and its `name`, a lookup key that is unique case-insensitively. The monotonic id
  counter is `db.profile.nextWindowId`. `Database.GetWindows()` creates an empty array on first
  read, which changes no membership.
- **Writer.** `modules/WindowManager.lua` owns every runtime change: `Create`, `Delete`,
  `Duplicate`, and `Rename`'s uniqueness check. `Database.NextWindowId` (the counter's only writer)
  and `Database.EnsureWindowShape` (the template backfill) are its helpers. The panel
  (`settings/Windows.lua`) and the slash verbs (`settings/Slash.lua`) call it, and neither touches
  the array itself.
- **Load pass.** `Database.SeedWindows` runs at the end of `NS:RunMigrations`, whose only callers
  are initialization (`NS:InitDB`, then `NS:OnInitialize` again directly as an idempotent repeat)
  and `Database:OnProfileChanged` (AceDB's changed, copied and reset callbacks). It seeds one
  window into an empty registry, mints a missing id and backfills the template. It never applies a
  player's choice. "Reset all settings" (`db:ResetProfile()`) and
  AceDB's swap and copy replace the store whole, and this pass re-seeds after them.

**Naming the writer covers membership and bookkeeping only.** A member field a row addresses is a
schema-row write and belongs to `NS.SetByPath`, even when `WindowManager` is the caller. The seam's
optional window id is what makes that possible: `NS.SetByPath(path, value, windowId)` resolves a
`window.*` path against the window the id names. It never substitutes the active window, and an id
that names no window is refused. `NS.State.activeWindowId` does not move.

- `WindowManager:Rename` keeps the uniqueness check and writes `window.name` through the seam for
  the window it renames.
- `WindowManager:CopyFrom` reads each copied row off the source with `NS.GetSetting(path, sourceId)`
  and writes them onto the target as one `NS.SetByPaths` batch. Every entry is validated before any
  is stored, and the copy logs one `[Set]` line and sends one `CONFIG_CHANGED`. A value the row
  refuses stops the copy and names the row. `window.columns` goes as one whole-array entry. The
  window's sort and session type are rows now (issue #50) and travel in the batch with the rest of
  the `data` group, and so does the pinned segment, `data.sessionID`. `frame.position` is never
  copied.
- `WindowProto:SortByColumn` (a column-header click) writes the sort rows as one batch for the
  window clicked. `WindowProto:SetSessionType` (the segment menu's Current / Overall) writes
  `window.data.sessionType` and clears the pin as one batch the same way, and
  `WindowProto:SetSegment` (a stored segment) writes `window.data.sessionID` alone.
- `WindowManager:SetLocked` writes `window.frame.locked` through the seam once per window, each
  announcement tagged with that window's id.
- `WindowProto:SaveSize` writes `window.frame.width` and `window.frame.height` as one batch for the
  window that was dragged. It runs on the grip's drag-stop only; `OnSizeChanged` just remembers the
  size, so a drag costs one write however many frames it lasts.
- `frame.position` has no row (see [`frame`](#frame--the-standalone-window) below). It is named
  non-setting state, owned by `WindowProto`, and needs no register row; its writers are listed in
  `docs/ARCHITECTURE.md` → Settings schema.

### `frame.position` is named non-setting state

`architecture-§5` lets geometry that only a drag or a resize determines be written outside the
helper, with no register row, once `docs/ARCHITECTURE.md` → Settings schema names its storage key,
its one owner and every writer. `frame.position` qualifies: no control chooses it and no row
addresses it. That naming is the compliance; this is the detail behind it.

- **Storage key.** `frame.position` (`{ point, relativePoint, x, y }`) inside each
  `db.profile.windows` entry.
- **Owner.** `WindowProto`, in `modules/Window_Placement.lua`, which also reads it
  (`ApplyPosition`).
- **Writers, and the act that reaches each.**
  - `WindowProto:SavePosition` — the title bar's drag-stop (`modules/Window.lua`). It reads
    `GetPoint` off the anchor frame that never holds a value (rule R3).
  - `WindowManager:ResetPosition` — the *Reset position* button on General → Master controls, for
    the window the picker is pointed at. It puts back the shipped center, which chooses nothing.
  - `WindowManager:ResetPositions` — `/mm reset-positions`, every window back to the center.
  - `WindowManager:Create` — a new window is written whole by `NS.DefaultWindow`, the template's
    position included.
  - `WindowManager:Duplicate` — the copy lands 24 px right of and below its source. The offset is
    derived from the source and chooses nothing.
  - `Database.EnsureWindowShape` — the template backfill writes a missing `frame.position` when
    `Create`, `Duplicate` or `CopyFrom` calls it at runtime. The load pass (`Database.SeedWindows`)
    calls it too, and the load pass is not a writer the naming has to list.

`WindowManager:CopyFrom` is not a writer. Its rows go through the seam as one batch (#49), its leaf
copy skips `frame.position` by name (`UNCOPIED`), and nothing puts a position back afterwards,
because nothing took one away. `frame.width` and `frame.height` are **rows**, the Frame page's
sliders, so they are not named state: the resize drag writes them through the seam by window id
(`WindowProto:SaveSize`). A profile reset and AceDB's swap and copy replace positions with the rest
of the profile.

### `nextWindowId` — ids are minted, never reused

`Database.NextWindowId()` hands out the next integer and advances the counter. Reuse would let a
deleted window's id be handed to a new one, which would then silently inherit the settings panel's
active-window pointer and every window-relative schema path aimed at it. A window with no `id` (a
hand-edited SavedVariables, a build that predates the counter) is **given** one rather than dropped:
losing a configured window is worse than renumbering it.

### `minimap`

`{ hide = false }` is all this addon declares. `LibDBIcon-1.0` is registered against this table and
treats it as its own — it reads `hide` and **writes** `minimapPos` (and a lock / free-position pair
if the player drags the button off the minimap). The addon must never enumerate the table or
normalize keys out of it, or a dragged button snaps back on the next login.

### `master` — the addon-wide master controls

| Path | Type | Default | Control |
|---|---|---|---|
| `master.visibility` | string | `"always"` | dropdown on `general` → Master controls |
| `master.scale` | number | `1.0` | slider, 0.5 .. 2.0 |
| `master.alpha` | number | `1.0` | slider, 0 .. 1 |
| `master.locked` | bool | `false` | checkbox |

`options-ui-§15` fixes this set and its order across every Ka0s addon. All four are **addon-wide**,
and none of them is a promoted per-window row: a window here is an instance, so its own
`frame.locked`, `frame.scale` and `frame.alpha` stay on the Frame page where the banner says which
window they mean. `modules/Window.lua` **composes** each pair rather than choosing between them —
the two scales and the two alphas multiply, the two locks OR — so one control can shrink or pin a
whole layout without erasing the differences a player set between its windows. `master.visibility` is
read by `core/MultiMeters.lua`'s show ladder, below test mode, and `never` is unforceable.

`NS.MasterSetting` (`defaults/Profile.lua`) is the **one reader**, shaped exactly like
`NS.DataSetting` below and for the same reason; `modules/Window.lua` clamps what it answers to the
bounds of the sliders that write it, because these paths are also reachable from `/mm set` and from a
hand-edited SavedVariables.

**NEW rather than migrated.** This addon never shipped an addon-wide *show only in combat* checkbox —
the per-window Visibility page has its own combat pair and keeps it — so there is no stored boolean to
lift and no `schemaVersion` step. AceDB's defaults merge supplies the subtree on first login.

### `data` — how the meter is read, addon-wide

| Path | Type | Default | Control |
|---|---|---|---|
| `data.mergePets` | bool | `false` | checkbox on `general` |
| `data.throttle` | number | `0.25` | slider, `THROTTLE_MIN` 0.05 .. `THROTTLE_MAX` 2.0 |

Both were `window.data.*` until `schemaVersion` 5 and neither described a window — see
[the window template's `data` group](#data) for the lift and the one-time migration. `NS.DataSetting`
(`defaults/Profile.lua`) is the **one reader**: three modules want these two values
(`modules/Aggregator.lua` and `modules/Export.lua` want `mergePets`, `modules/Window.lua` wants
`throttle`), and each reaching into `NS.db` for itself would be three chances to disagree about what
a missing db means. Its fallback is the defaults tree rather than a literal, so a second copy of
`0.25` cannot drift from the schema row that claims to set it.

### `export` — the remembered export choices

| Path | Type | Default | Control |
|---|---|---|---|
| `export.metric` | string | the first `STATS` key | `hidden` row; drawn in the export modal, and `Export.Open` reseeds it from the invoking window |
| `export.channel` | string | `"SELF"` | `hidden` row; drawn in the export modal |
| `export.whisperTo` | string | `""` | `hidden` row; drawn in the export modal |
| `export.lines` | number | `5` | `hidden` row; drawn in the export modal |

The four rows are filed on page `general` and all marked **`hidden`**, so the panel draws none of
them: the modal's own three controls are the ones a player uses, and a second copy on a settings page
restated a control met only in the dialog — with a standing chance of the two disagreeing about what
is selected.

**Hidden rather than deleted**, and the difference is which seam writes them. The modal writes them
through `NS.SetByPath`, which **refuses a path with no row**, and `writeExport` stores nothing around
a refusal. `export.metric` shows what an absent row cost: with none, every pick in the modal's Metric
dropdown and every seed from `Export.Open` was refused and fell through to a raw profile write. The
dropdown chooses the value, so under `architecture-§5` it is a preference, and it has a hidden row
again.

All are **absolute** paths — there is no `window.` prefix to resolve. They are the **one group in the profile that is not a property of
anything on screen**: every other setting here answers "how should this look", and these answer
"how did you last export", which is an action rather than an appearance.

That is why they are addon-wide despite an export always being started *from* a window. A player who
prints the top five to party does it from whichever window is nearest, and making them restate the
habit per window would be the settings tree being tidy at the player's expense. The segment is the
one thing an export does inherit from its invoking window, and it is inherited live rather than
stored — it is already `window.data`'s.

`channel` ships as `SELF`, which prints through `NS.Print` and reaches nobody else, and that default
is a safety property rather than a taste: the export surface is a glyph in a title bar, and a
misclick must not be able to put someone's numbers in front of a raid.

`metric` and `channel` are both dropdowns **derived from a catalog** rather than written out —
`Constants.STATS` and `Constants.EXPORT_CHANNELS` — so the panel, the CLI's `values` constraint and
the modal's own menu all offer exactly the keys that exist, and a stat or a channel removed from a
catalog cannot linger as an option that resolves to nothing. Localization happens at the use site in
`settings/Schema_Compose.lua`, which holds both vocabularies, rather than in the catalog, because
`core/Constants.lua` may load before `locales/enUS.lua`.

`whisperTo` carries no non-empty check, unlike the window-name row it otherwise copies: `""` is both
its shipped default and a legal value, because it is what every channel but Whisper means. Its
validator refuses a table typed in from a hand-edited SavedVariables and nothing more — whether a
name resolves to a character is the server's answer to give, not this seam's — and a whisper with
nobody named falls back to printing to yourself rather than erroring at the send site. The modal
catches the empty box before that fallback can swallow it silently ("Enter a name to whisper to."),
and `Export.NoteSystemMessage` catches the server's *"no player named …"* answer to a name that is
filled in but wrong, cancelling the rest of the dump so one mistyped name is one message rather than
one per line.

The catalog carries **two whisper rows**, and they are two channels rather than one channel with a
mode: `WHISPER` takes its recipient from `export.whisperTo`, and `TARGET` reads it off whoever the
player has targeted at the moment the button is pressed. Nothing about the target is stored — a
remembered one is a name that was true when the modal opened.

`schemaVersion` 4 retires the channel `AUTO`, which used to resolve its own destination at send time
and was removed as ambiguous: choosing to print is choosing an audience, and a row that picks the
audience leaves the one fact the player needs unstated. A stored `AUTO` folds to `SELF`.

`lines` is clamped to `Constants.MAX_ROWS` rather than to a literal, because the aggregator truncates
an export there anyway and a slider offering 60 would be offering a number the send could not honor.

The modal writes every choice back through `NS.SetByPath`, so the panel's four widgets and the
modal's own copies of the same controls are two views of one preference rather than two preferences
that drift.

### What is deliberately *not* in the profile

The session-only flags in `core/State.lua`: `debug`, `restricted`, `testMode`, `activeWindowId`, and
`State.cache`. A flag that survives a `/reload` is a setting; these are not. Persisting
`activeWindowId` in particular would make a deleted window's id outlive the window.

---

## The window config template

Written once as a private literal in `defaults/Profile.lua` and **deep-copied per window** by
`NS.DefaultWindow(id, name)`. It is never handed out by reference: two windows sharing one
sub-table is the classic profile-aliasing bug, where editing window 2's bar color silently edits
window 1's. The template is published as `NS.WINDOW_TEMPLATE` for the merge, the tests and the
schema validator.

```lua
{
    id   = <number>,     -- stamped by NS.DefaultWindow / Database.SeedWindows
    name = "Multi Meters #1",  -- Database.WindowName(n); shown in the picker and, optionally, in the header
    frame = {...}, header = {...}, rows = {...}, bars = {...}, text = {...},
    icons = {...}, tooltip = {...}, visibility = {...}, columns = {...}, data = {...},
}
```

Those ten group names are also `modules/WindowManager.lua`'s `COPY_GROUPS` and the settings panel's
"Settings to copy" dropdown — one list, three jobs. **A group added to the template and not to
`COPY_GROUPS` simply never copies.**

### The four meta rows

`window.colorMode`, `window.barTexture`, `window.font` and `window.fontOutline` (which ships as
`NONE`, matching the two text surfaces that ship without an outline) are rows on the
**Frame** page that set the others rather than being read by anything. Each fans out to the surfaces
that have a setting of its kind: the colour mode to six, the bar texture to two (the grid and the
tooltip), and the font and its outline to four each (the cells, both header strips and the tooltip).
The tooltip's keys carry a `font` prefix of their own — `fontOutline`, not `outline` — which is why
each fan-out is a list of **paths** rather than a group list and a suffix assumed to be shared.

`window.colorMode` sets six others rather than being read by anything: `bars.colorMode`,
`bars.bgColorMode`, `columnHeader.colorMode`, `columnHeader.bgColorMode`, `tooltip.barColorMode`
and `tooltip.barBgColorMode` — `COLOR_MODE_PATHS` in `settings/Schema_Compose.lua`. Sixteen surface
modes exist in the window altogether; the broadcast reaches these six because they are the **fills**, and
one control for all of them is right when a player wants them to agree, which is the usual case.

**The two text surfaces are deliberately left out** — `text.colorMode`, the numbers in the grid, and
`tooltip.colorMode`, the tooltip's own text. Both are drawn *on top of* a surface this list does
broadcast to, so sending "per statistic" everywhere painted the Damage number in the Damage colour
over a Damage-coloured bar. Foreground text has to contrast with the broadcast, not match it, so it
stays an explicit choice. `header.colorMode` is out for its own reason — the title bar is one strip
spanning the whole window, so per-statistic there could only ever mean the sort column's colour.

All four behave the same way, so what follows about the colour mode is true of every one of them.

**It stores what was last broadcast and nothing reads it back.** A player who then changes one
surface individually has changed one surface; the meta does not fight them for it and does not claim
to describe them afterwards. Deriving it instead — showing "mixed" when the six disagree — would make
a control that cannot be set to the value it is displaying, which is worse than a shortcut that goes
stale.

The fan-out writes **through `NS.SetByPath`, one at a time**, so each target gets its own validation,
its own debug line and its own `CONFIG_CHANGED`: a broadcast is indistinguishable from the player
having set all six by hand. Writing the config tree directly would be a second write seam, and the
windows would not repaint.

**It does not fire during a reset.** `NS.ApplyDefault` raises `NS.__restoring` around its write,
because the Frame page's Defaults button walks every row of that page — and a meta row that
broadcast from there would make that button silently reset six settings on three other pages, which
is the one thing a per-page reset must not do.

### The four text controls

Four groups draw text — `text` (the cells), `header` (the title bar), `columnHeader` (the label
strip) and `tooltip` — and each of them offers the **same five controls**: an LSM **font** picker, an
**outline** dropdown over one shared value set, a **shadow** checkbox, a **colour** picker and a
**`colorMode`** dropdown. They did not always: only `text` had a shadow, none had a class colour, and
a player styling a window had to discover which surface had grown which control.
`tests/test_schema.lua`'s *every text surface offers face, outline, shadow and colour* is the
contract — a fifth surface, or a sixth control, is a row added to that table and then made to pass.

**`class` means a different class on different surfaces, and the difference is not an
inconsistency.** A cell is about the player whose row it is, so `text.colorMode = "class"` takes
**that row's** — the same reading the Player column has always had and the same one
`bars.colorMode = "class"` has. A tooltip is about the player you are hovering, so it takes **that**
player's. The two header strips are about the **window** rather than about any row, so they take the
**local player's** — the only class those surfaces can sensibly mean. One reader answers all four:
`NS.ClassRGB(classFilename)` and `NS.PlayerClassRGB()` in `core/Namespace.lua`, so the header and a
row of the grid can never disagree about what a warlock looks like.

`stat` is resolved the same way — see [the table above](#the-four-text-surfaces-and-their-colour-modes)
— and `modules/Window.lua`'s `NS.SurfaceColor` is the one reader for both header strips and both of
their backgrounds.

The configured **alpha survives** every mode on every surface. `RAID_CLASS_COLORS` carries none, and
`NS.StatColor` deliberately answers three numbers rather than four even though a stored
`statColors.*` swatch has an alpha of its own — so taking one from either would make a colour mode
silently cancel Text opacity, which is one setting overruling another. A class or statistic that cannot be read keeps the
configured colour rather than falling back to a hue invented for the occasion.

**Text opacity is folded INTO that alpha**, in `modules/Row.lua`'s `textAlpha`, rather than living
only on `FontString:SetAlpha`. The per-row colour passes write their own alpha through
`SetTextColor` after the style pass has run, and in the client the numbers came back to full opacity
while the names stayed faded — one setting working on half the grid. Folding it in means every colour
write carries the opacity and a later write cannot undo it.

Every one of the new keys ships **off**: `header.shadow`, `columnHeader.shadow`,
`tooltip.fontShadow` are `false`, and all six `colorMode` / `bgColorMode` keys ship `"custom"`. A setting added to a shipped window
must not change how that window already looks, and a shadow under an outlined face is heavier than
either alone. `text.shadow` keeps its long-standing `true`.

### `frame` — the standalone window

| Key | Default | Notes |
|---|---|---|
| `width` | `716` | slider 160–1400. Derived from the grid: name column + six default columns at `COLUMN_WIDTH` + seams + padding. |
| `height` | `220` | slider 60–900 |
| `scale` | `1.0` | 0.5–2.0. Applied to the anchor **and** the visible frame. Scaling only the frame left the box its original size and shrank its contents, because the frame is pinned TOPLEFT/BOTTOMRIGHT to the anchor and inherits its screen rect. |
| `alpha` | `1.0` | 0–1, rendered as a percentage |
| `strata` | `"MEDIUM"` | `LOW` `MEDIUM` `HIGH` `DIALOG` |
| `backdropColor` | `{ r=0, g=0, b=0, a=0.75 }` | |
| `backdropColorMode` | `"custom"` | `class` \| `custom`. options-ui-§17's companion, added in the settings-revamp-v2 pass. `class` is the LOCAL player's — a window is not about any one row — and there is no `stat`, for the reason the title bar has none. |
| `borderStyle` | `"Blizzard Tooltip"` | LSM `border` key |
| `borderStyle` = `"None"` (or `""`, or unset) | | means **no edge**, answered by `borderPath` itself. That resolver distinguishes a CHOICE from a FAILURE: "None" is nil, while a name it cannot fetch — a media pack that is no longer installed — still falls back to the library's own edge. Conflating the two handed a player who picked "None" the Ka0s edge they had just turned off. Same rule and same order as `modules/Tooltip.lua`'s `mediaPath`, the addon's other LSM resolver |
| `borderSize` | `2` | `0` drops `edgeFile` with it — a zero edge size with a texture still present is drawn as a hard 1px line. With no edge, the skin's 1px `frame.innerBorder` child is hidden too: it is not part of the backdrop `ApplyBorder` rewrites, so it used to be the whole visible border on a window whose border was switched off |
| `borderColor` | `{ r=0, g=0, b=0, a=1 }` | |
| `borderColorMode` | `"custom"` | `class` \| `custom`, the companion beside it. Same two values and same reading as `backdropColorMode`. |
| `padding` | `6` | frame edge to rows |
| `locked` | `false` | **not** coupled to Test mode — `WindowManager:SetLocked` used to also switch it on, which made unlocking a window fill it with placeholder rows and made unchecking Test mode a no-op while any window was unlocked. Locking is now about movement and nothing else; ask for a grid to aim at with `/mm test` |
| `clampToScreen` | `true` | |
| `closeButton` | `true` | a **header control**, grouped with the `show*` keys on the panel |
| `minimised` | `false` | a **hidden** schema row: writable through `NS.SetByPath` and listed by `/mm list`, but drawn as no control. It is per-window state the header's own minimise button writes, not a preference |
| `position` | `{ point="CENTER", relativePoint="CENTER", x=0, y=0 }` | **not a schema row** — named non-setting state, see below |

The chrome itself is `LibKa0s-Core-1.0`'s shared `SKIN` / `ApplySkin`, which tints `frame.title` and
`frame.divider` on its own, so the accent colors are not settings here. What the player owns is
geometry, the backdrop and the LSM border, layered over the skin in that order.

**`frame.position` is not a schema row, and it is named non-setting state** (`architecture-§5`):
geometry only a drag determines. It is four values behind one concept, no control chooses it (the
Reset position button and `/mm reset-positions` put back the shipped center, which chooses nothing),
and its owner is `WindowProto`. The naming, with every writer and the act that reaches each, is in
`docs/ARCHITECTURE.md` → Settings schema; it is what makes the write outside the helper compliant,
and it is why the deviation register carries no row for it. It
is also the one piece of window state that must never be *read back* off the live frame (rule R3).
`modules/Window.lua` keeps an empty, invisible `anchor` frame that never receives a value, and
`modules/Window_Placement.lua`'s `SavePosition` reads `GetPoint` off **that**; the visible window is anchored to it. Because positions have no row,
`NS.ApplyDefault` never reaches them. A global reset reaches them anyway, because "Reset all
settings" is a **profile reset** and a position lives in the profile. (`NS.ResetPositions` used to
exist for exactly this and was removed with its last caller; `/mm reset-positions` is the targeted
verb and goes straight to `modules/WindowManager.lua`, which owns re-anchoring a live frame.)

### `header` — the strip above the rows

`show = true` · `font = "Friz Quadrata TT"` · `size = 12` ·
`outline = "OUTLINE"` · `color = { r=1, g=0.82, b=0, a=1 }` · `colorMode = "custom"` ·
`align = "LEFT"` · `height = 18` · `bgColor = { r=0, g=0, b=0, a=0.5 }`.

**`show` moved here from `window.frame.titleBar` at `schemaVersion` 12 → 13** (`window.header.show`,
not `window.frame.titleBar` — a path naming `frame` for the Header page's own master switch misled
the next reader and read wrong in `/mm set`). `migrations[12]` in `core/Database.lua` copies a stored
`frame.titleBar` into `header.show` and deletes the old key; a profile saved before this branch opens
with its title bar exactly as it was.

**Four keys lived here and are gone**, and each of them said something already on screen: `title`
(a second name for a window that has one), `showSessionName` ("Overall" beside a window the player
called Overall), `showDuration` (the length of a segment the header's own picker names) and
`showTotals` (a group total over a column holding the same figure per player). The header draws
`window.name` now, so renaming a window renames its header and the two cannot disagree.

`schemaVersion` 8 prunes them — and **rescues a typed `title` into `window.name`**, where the window
has not been named itself. That is what the box was being used for: naming the window, in the only
field that changed what the header said. Dropping it would silently rename their windows back.

What the right-hand header line still says is **state rather than preference**: the drill-down title,
which says whose breakdown you are looking at, and the restricted notice, which says why a cell can be
empty mid-pull. It is blank the rest of the time.

**`bgColor` paints the TITLE BAR and stops there.** It used to cover both header rows, on the reading
that "the header" is the whole block a player points at — which meant `columnHeader.bgColor` was
drawn underneath it and could not be seen, and a colour picked for the title bar restyled the grid's
column labels too. Two strips, two settings, two rectangles.

`show`, `align`, `height` and `bgColor` are edited on the Header page's **Title bar** tab — the strip's
own shape; `font`, `size`, `outline`, `shadow` and `color` are the **Title text** tab — the face drawn
on it. The two used to be one group ("Header text" and "Header background" before that, which put
`align` and `height` — both properties of the text — under a heading that said background); splitting
shape from face is what makes each tab's rows a single answerable question rather than a mix of two.

### The four text surfaces and their colour modes

`text`, `header`, `columnHeader` and `tooltip` each carry the same five controls — face, outline,
shadow, colour, and a **`colorMode`** of `class` / `stat` / `custom`. The COLUMN strip carries a `bgColorMode` over the same three; the
title bar's background deliberately does not, because it is one strip over the whole window and "per
statistic" could only paint it the sort column's colour — a fact on screen twice already. `schemaVersion` 7 migrates the `classColor` boolean each of them
used to have: `true` → `"class"`, `false` → `"custom"`, which is exactly what it meant, and the dead
key is pruned.

**`stat` means a different statistic per surface, and that is the point** — it is one question ("which
statistic is this text about?") answered by whichever statistic the surface actually describes:

| Surface | What `class` is | What `stat` is |
|---|---|---|
| `text` (cells) | the class of the row being drawn | the column the cell sits in |
| `header` (title bar) | **yours** — a header is about the window, not a row | the window's **sort column** |
| `columnHeader` | yours, for the same reason | **each label's own column** — the one surface where it is literally per column |
| `tooltip` | the class of the player being hovered | **the hovered column** — a cell tooltip is the breakdown of one statistic. The name tooltip and the death recap, which are about no single one, fall back to the sort column |

`none` is deliberately **not** offered. It is a legal answer for a tint drawn behind something and
never for the writing itself, and a text surface set to "no colour" is one nobody can read.

The configured **alpha survives every mode**: neither `RAID_CLASS_COLORS` nor `Constants.STAT_COLORS`
carries one, and a mode that silently reset transparency would be one setting cancelling another.
That matters most for the two backgrounds, where the alpha is what makes a colour a tint rather than
a slab. A colour that cannot be resolved — an unknown class, a stat with no palette entry — falls
back to the configured one.

`columnHeader.bgColorMode == "stat"` is the only mode that paints **per column**: it puts a texture
behind each label rather than one across the strip, because a class is not a property of a column and
every other mode has exactly one colour to draw.

### `columnHeader` — the "Player | Damage | Healing" strip

`font = "Friz Quadrata TT"` · `size = 11` · `outline = "OUTLINE"` ·
`color = { r=1, g=0.82, b=0, a=1 }` · `colorMode = "custom"` · `bgColor = { r=0, g=0, b=0, a=0 }` ·
`bgColorMode = "custom"`.

**Separate from both neighbours, and it was not before.** The strip used to take its font path and
size from `text` and its outline and colour from `header`, so changing the cell font silently
restyled the headers and no setting could make the strip differ from the numbers beneath it. Every
default above is the value that arrangement already resolved to, so an existing window is
pixel-identical after the upgrade — what changed is that the settings exist and are independent.

`bgColor` is new capability rather than a moved one: the strip has never had a backdrop, which is why
it defaults fully transparent.

**Edited on the Columns page, not the Header page.** These eight rows carry `page = "columns"` —
**Header text** (`font`, `size`, `outline`, `shadow`, `color`, `colorMode`) and **Header background**
(`bgColorMode`, `bgColor`) are two of that page's three tabs, alongside the bespoke block editor. They
moved off Header because Columns is the page that labels the strip they style; the storage paths are
untouched (`window.columnHeader.*`), so a row's page is where it is edited and its path is where it
is stored, same as `frame`/`header` above.

### `rows` — one per group member

Edited on the **Bars page**, at the top of it: how tall a row is, how many there are and which way
they grow decide the shape of every bar drawn under them, so the two groups sit above the bar's own.
The Rows page is gone; the paths did not move with it.

`maxRows = 0` (0 means "as many as fit the frame"; a positive value caps it, hard-ceilinged at
`Constants.MAX_ROWS = 40`) · `height = 16` · `spacing = 1` · `growthDirection = "DOWN"` ·
`alwaysShowSelf = true` · `highlightSelf = **false**` · `alternatingBackground = **false**` ·
`mouseoverHighlight = true`.

`alwaysShowSelf` spends the last visible slot on the local player rather than growing the list, so
the row count stays exactly at the cap (`Aggregator.ApplyRowLimit`).

**The two row decorations ship OFF, and the other two on that tab ship ON**, which is one
distinction rather than four decisions. A meter's job is telling rows apart by their numbers;
`highlightSelf` and `alternatingBackground` shade rows for reasons that are not the numbers, so they
are the player's to ask for. `alwaysShowSelf` changes *which* rows are on screen rather than how they
are painted, and `mouseoverHighlight` answers the *cursor* — it appears where the player is pointing
and leaves with them. Changing a default does not change a stored value: an existing profile that had
either switched on keeps it, and only a profile that never touched the key follows the new default.

**`alternatingBackground` lives here and is EDITED on the Bars page**, beside `bars.bgColorMode` —
the two of them decide what colour sits behind a row, and choosing between them meant reading two
pages. It stays a row-level key because it is a row-level fact: `RowProto:Update` draws it, not the
cells.

**`classBackground` and `classBackgroundAlpha` are gone, and they were doing nothing before they
went.** The row tint is painted per CELL from `bars.bgColorMode` and `bars.bgAlpha` — it moved there
when tinting the row itself turned out to tint the two-pixel seams between the columns and lose the
separators the grid is read by — and those two keys were left behind with no reader at all. Two
settings-panel controls answering a question that was already answered one page over, into a void.

### `bars` — the StatusBar in every cell

`texture = "Blizzard Raid Bar"` (LSM `statusbar`) · `colorMode = "class"` · `customColor =
{ r=0.35, g=0.55, b=0.85, a=1 }` · `bgColor = { r=0, g=0, b=0, a=1 }` · `bgColorMode = "class"` ·
`bgAlpha = 0.35` · `border = false` · `borderThickness = 1` ·
`borderColor = { r=0, g=0, b=0, a=1 }` · `borderColorMode = "custom"` · `alpha = 1.0` ·
`fillDirection = "LEFT"` · `animate = true`.

**`animate` slides each fill to its new length between refreshes instead of snapping** (issue #23).
The slide is the client's. Patch 12.0 gave `StatusBar:SetValue` and `:SetMinMaxValues` an optional
trailing `Enum.StatusBarInterpolation`, and `modules/Row.lua`'s `Cell:SetValue` passes
`ExponentialEaseOut` (through `Compat.BarInterpolation`) to **both** setters, so the max moves with
the value. Blizzard's API docs mark the argument `NeverSecret` and keep both setters
`AllowedWhenTainted` with a secret value, so the bar animates toward a secret target in combat
without this addon holding two values or stepping between them. An addon-side interpolation
would be arithmetic on a secret, which is illegal mid-pull, exactly when the animation matters. Off,
or on a client without the enum, the argument is omitted, which is `Immediate`: the snap. Text, sort
order and export read nothing from the animation.

`borderColorMode` is options-ui-§17's companion beside the outline's swatch, added in the
settings-revamp-v2 pass. Two values, `class` and `custom`, and `class` is **the row's player's** —
an outline around a cell belongs to whoever the cell belongs to, exactly as the fill inside it does,
and not to the local player, which is what the window's own edge means one page away. It is applied
per row by `Cell:ApplyEntryBorderColor`, for the same reason `text.colorMode`'s class mode is: the
layout pass has no entry in hand. With the shipped `custom` it is two table reads and a return.

**`alpha` fades the FILL TEXTURE, not the cell.** It used to be `bar:SetAlpha`, and the StatusBar is
the cell — it parents the fill, the backdrop, both text slots and the name column's icon — so
dropping "Bar opacity" to 10% faded the whole grid. Three settings paint three surfaces (`alpha` the
fill, `bgAlpha` the backdrop, `text.alpha` the two FontStrings) and none can cancel another.

`borderThickness` and `borderColor` were constants until they were settings: one pixel, in the
library skin's own edge colour, which no setting could reach. The skin's edge is still the fallback
for the colour, so a window that never touched either keeps the border it had.

`colorMode` is `class` / `stat` / `custom`. **`class` is the default because `classFilename` is
`NeverSecret`** — a class-colored bar is still correct at the height of a pull, when every number on
the row is an opaque handle. `fillDirection` names where the fill *starts*, so `"LEFT"` means the
bar grows rightward (`SetReverseFill(false)`).

### The header's controls

The whole title row — name, session line and controls — is centred on one line through
`Window:TitleRowTop`, computed from the padding, `header.height` and each item's own configured size.
The band it centres in runs from the frame's **top edge** down to the divider, not the tinted band
alone: the padding above is not a margin to anyone looking at the window, so centring in the band
leaves it as dead space above the row and lands the text against the divider. Nothing in the title
bar is anchored to a hand-picked offset any more.

`divider = true` · `dividerThickness = 1` · `dividerColorMode = "skin"` ·
`dividerColor = { r=0.5, g=0.5, b=0.5, a=0.85 }` — the hairline between the title bar and the column
labels, and the one piece of the window's chrome a player can switch off outright. Hiding it moves
nothing else: `TitleRowTop` centres the title row against the `DIVIDER_INSET` constant rather than
against the texture.

**`skin` is the shipped mode, and it writes nothing.** It does not resolve `SKIN.divider` and apply
it — it leaves the texture exactly as `NS.ApplySkin` painted it a few lines earlier in `ApplyConfig`.
That is how a per-window colour picker coexists with `standalone-windows`: the shared value is never
copied into this repo, never stored in a profile, and never has to be migrated when it changes, so a
re-skin still reaches this window along with the debug console and the perf panel. The two override
modes — `class` (yours) and `custom` — follow `frame.title`'s precedent one screen up: `ApplySkin`
owns the accent, and a setting that claims to govern it writes *after* the library rather than
instead of it. An unknown class leaves the skin's tint standing rather than inventing a colour.

The **custom swatch is a mid grey, deliberately not `SKIN.divider`'s values** — seeding it from there
would be exactly the copy the rule forbids, and it would misdescribe the row besides: it is only ever
read under `custom`, where the skin has already been declined. The configured **alpha survives the
mode**, the same rule the cell text keeps: a class colour carries none of its own and takes the
swatch's, so changing the mode never silently changes the opacity.

There is deliberately **no `stat` mode**, for the reason the header's other surfaces have none: the
divider is one line across the whole window, so "per statistic" could only paint it the sort column's
colour — a fact already on screen twice over.

`showMinimise` · `showLock` · `showSettings` · `showSegment` · `showReset` · `showExport` — all
`true`. Six of the seven controls; `closeButton` is the seventh and deliberately keeps its older
name, because renaming it to `showClose` for symmetry would migrate every stored profile in exchange
for a consistency nobody can see. All seven sit on the Header page, on one tab —
**Controls** — window-acting first (close, minimise, lock, settings), then meter-acting (segment
picker, reset, export). Their size, hover reveal and colours sit in the tab below it, **Button
style**.

**There is no `resizeGrip` key.** There was, and it was read once while the frame was being built —
so unticking it did nothing until a reload. The grip follows the **lock**: drawn while the window is
unlocked, hidden while it is locked, which is the same question the lock already answers. Locking a
window is how you put its grip away.

`hoverReveal = true` fades every control except the one under the pointer — the reveal is per
control, not per strip, so it *is* the "which one am I about to click" feedback rather than a
separate highlight drawn behind it. `controlAlpha = 0.25` · `controlHoverAlpha = 1.0` are the two
ends of that fade and were literals in `restAlpha` until they were rows, so a window that touches
neither is drawn exactly as before. **`controlAlpha` is read only while the reveal is on** — with
fading off there is no faded state, and every control sits at the hover value, which is what a
player who has just switched fading off means by "how visible are these". It is deliberately not
disabled on the panel in that state, the same bargain `bars.customColor` gets under a non-custom
colour mode. Both are clamped to 0..1 on read: they come from a file a player can hand-edit, and an
out-of-range alpha is not an error, it is a control drawn at the nearest legal value, which reads as
the setting not working. `minimised = false`
collapses the window to that bar — the stored `frame.height` is untouched, so expanding restores it
exactly. `controlColor = { r=1, g=1, b=1, a=1 }` and `controlHoverColor = { r=1, g=0.82, b=0, a=1 }` — two
colours, because hover is the only feedback a control gives, each now paired with its own
**`controlColorMode`** / **`controlHoverColorMode`** dropdown (`class` / `custom`, both default
`"custom"`) rather than the `controlClassColor` / `controlHoverClassColor` booleans they replaced at
`schemaVersion` 12 → 13. Two modes rather than one, because rest and hover are two independent
answers: a player who wants their class colour under the pointer has not asked for the whole strip in
it, and a shared mode would make hover and rest the same colour for anyone who chose class — the one
thing a hover colour must never be. `migrations[12]` reads each stored boolean and writes `"class"` or
`"custom"` in its place. The art ships white and is tinted by a
**multiply**, so the shipped `controlColor` is the identity rather than a recolour: the icons read as
chrome, and the pointer turns exactly one of them the gold the rest of the header uses. Both are
pickers rather than a "match the header text" switch — one of the two states being unconfigurable was
the complaint that produced them. (The tint had never run at all before: `HeaderControls.Style` read
`NS.HeaderStyle`, which nothing published, so it fell through to a white fallback every time.
`modules/Window_Header.lua` publishes it now, and the controls take the header's **font** from it
while carrying their own colours.)

`controlSize = 16` is the *slot* each control occupies — its click target and the strip's layout
pitch. The art is drawn centred inside that slot at 72% of it, so a 64px icon lands at 11px in a 16px
box, on the same line as a 12px title; a glyph that reaches its own edges reads much heavier than the
header text beside it when it fills the slot outright.

**A collapsed window does not poll.** That is a real clause in `ShouldPoll`, not an emergent
property of hiding: `OnUpdate` is installed on the frame, and the frame stays shown while collapsed
— only the body hides.

### `text` — the FontString in every cell

`leftSlot = "smart"` · `rightSlot = "none"` — **both take the same six values**, `none` / `smart` /
`combined` / `total` / `rate` / `percent`, in either position. They used to take different
three-value sets overlapping on two, which made "the total on the right" unexpressible for no reason
anyone could state.

**Every value is literal and nothing falls back.** `none` renders nothing, `rate` renders nothing on
a stat with no per-second figure, and a cell whose slots both come back empty stays empty — a bar
with no text is a legitimate thing to want. The old code substituted the total whenever a cell would
otherwise have been blank, which meant setting both slots to None appeared to do nothing at all. A
lone right-slot figure likewise stays on the right rather than sliding into the empty left slot.

`smart` and `combined` are the two values whose meaning depends on the column, and both branch on
the same flag (`Constants.STATS[].isRate` — Damage and Healing). `smart` **picks**: the per-second
figure where the stat has one, the absolute figure everywhere else — one setting saying "the figure
this column is about" across a grid that mixes both kinds, and what the left slot ships as.
`combined` **shows both**, `12.4M | 53.5K`, and falls back to the absolute alone on a counting stat,
where "9 | 3 per second" is a sentence no meter should write. The join goes through `string.format`
and never `..`: both halves came out of the native formatter with a secret inside them.

`numberFormat = "abbreviated"` — four values, three of them one ladder at three fraction divisors
(`abbreviated` 12.4M · `abbreviatedWhole` 12M · `abbreviatedTwo` 12.40M) and `full` (12400000), which
is the other formatter entirely. **There is no thousands-separated form and there cannot be one**:
grouping digits means reading them, and `BreakUpLargeNumbers` raises on a handle. Each abbreviating
mode gets its own cache slot in `modules/Format.lua`, so two windows on two decimal counts do not
rebuild each other's formatter every refresh, and each is **probed against its own expected string**
— a client that accepts `SetBreakpoints` and keeps its own rules is detected rather than assumed.

`deathTimeFormat = "clock"` (`clock` / `ago`) · `maxNameLength = 15` (0 = no
cap) · `font = Const.FONT_MONO_NAME` ("JetBrains Mono") · `size = 11` · `outline = "NONE"` ·
`shadow = true` · `color = { r=1, g=1, b=1, a=1 }` · `alpha = 1.0`.

`text.alpha` is applied to the two **FontStrings**, never to the cell's StatusBar. The FontStrings
are children of that bar, so folding this setting into the bar's own alpha faded the fill, the
backdrop, the borders and the name column's icons along with the writing — fading the whole grid is
`bars.alpha`'s job. The compounding still happens in the one direction that is correct: a child's
alpha applies on top of its parent's, so a bar at 50% carrying text at 50% renders that text at 25%,
and never the reverse.

`maxNameLength` counts **characters, not bytes** — a byte slice can land inside a multi-byte
character and emit half a code point, and the names most likely to need truncating are exactly the
accented ones. It sits above WoW's 12-character player-name limit because a group meter also lists
NPCs, which are not bound by it — but not far above it: it shipped at 20, which is wider than any
name in a full group of players and spent that width on the columns beside it. The realm is stripped
regardless of the number.

The name column's own width is computed from this cap (`modules/Window.lua`'s `nameColumnWidth`), and
`Constants.NAME_CHAR_RATIO` / `NAME_COLUMN_PAD` are calibrated so a **20**-character cap at 11pt with
the icon on lands on exactly `NAME_COLUMN_WIDTH`, a measured value. The shipped cap computes
narrower, which is the point of the setting; `tests/test_window.lua` pins the calibration.

Both the strip and the cap are **gated on the concat probe**: `string.match` and `string.sub` read
the characters of a value, and doing that to a secret is what rule R1 forbids, so a `ConditionalSecret`
name reaches the widget untouched and uncapped.

`deathTimeFormat` labels a death in the Deaths tooltip and the death drill-down — the time of day,
or how long ago. A third value, "time into the fight", was built and removed: nothing on the client
can date a past death against the run it happened in, and the captures that establish that are on
[issue #18](https://github.com/tusharsaxena/MultiMeters/issues/18). Both surviving values read the
recap's own newest event timestamp, which is absolute epoch and always present.

**Nothing here divides anything.** `numberFormat` picks which `NumericRuleFormatter` instance
`modules/Format.lua` hands the value to; the formatter does the division natively, which is the only
legal way to render "12.4M" from a secret. `percent` is the one slot that goes quiet in combat —
`modules/Aggregator.lua` only produces it when both operands were accessible, and empty means
"cannot be known right now", never "zero percent". That is why the shipped pair is `total` and
`none`.

A `rate` slot renders only for stats whose catalog row sets `isRate` — `DamageDone` and
`HealingDone`. Counting stats leave it empty rather than announcing "0.42 interrupts per second";
that is a property of the **stat**, not of the slot, which is why both slots offer `rate` and both
drop it on the same columns. A cell whose slots both come back empty falls back to its total, so a
column can never render a header, a bar and no number.

### `icons` — the marks in the name column

`showIcon = true` · `size = 14` · `position = "LEFT"`.

**ONE SLOT, ONE TOGGLE.** There were three flags, one per icon kind, and a player who turned them all
on got three textures competing with the name for a column that has to hold a name. The slot picks
its own icon per row, in this order: a **breakdown row is a spell**, so it draws the spell's icon and
stops; otherwise the **spec** where `specIconID` is known, because that separates the three druids in
a raid where a class icon cannot; otherwise the **class**; and a **role never** — three roles across
a whole raid identifies nobody, and it was the icon most likely to be on screen when the name column
ran out of room.

`schemaVersion` 3 migrates the old flags: `showIcon` is on if *any* of the three was, since somebody
running the role icon alone had asked for an icon, and the three dead keys are removed rather than
left to rot in every saved profile.

`classFilename` and `specIconID` are both `NeverSecret`, so this column renders in full even when
every number to its right is opaque.

### `tooltip`

`anchor = "TOP"` · `offsetX = 0` · `offsetY = 0` · `showSpells = true` · `maxSpells = 10` ·
`showAllStatsOnName = true` · `hideInCombat = false`.

Its own appearance, kept separate from `bars` and `text` on purpose — a 14px spell line and a 90px
cell are different surfaces, and a texture or a size that reads across one often does not across the
other: `barTexture = "Blizzard Raid Bar"` · `barSpacing = 1` · `scale = 1.0` · `barColorMode = "class"` · `barAlpha = 0.85` · `barBgColorMode = "custom"` ·
`barBgAlpha = 0.1` · `barBorderStyle = "None"` ·
`barBorderSize = 1` · `barBorderColor = { r = 0, g = 0, b = 0, a = 1 }` ·
`barBorderColorMode = "custom"` ·
`font = "Friz Quadrata TT"` · `fontSize = 12` · `fontOutline = "NONE"` ·
`textColor = { r = 1, g = 1, b = 1, a = 1 }`. One colour for **both** number slots: the amount used
to be hardcoded gold and the share hardcoded white, which read as two kinds of number when they are
one line's two figures.

`barBorderColorMode` is options-ui-§17's companion beside the outline's swatch, added in the
settings-revamp-v2 pass. Two values, `class` and `custom`, and `class` is **the hovered player's** —
the same class the fill it surrounds takes, because a tooltip is opened over one row and is about
that row.

The Targets section: `showTargets = false` · `maxTargets = 3`.

The death-line section: `showDeathCaster = true` · `showDeathSpell = false`. Each line of a Deaths
cell's tooltip names what ended that death — `Death 3 | Ragnaros`, or `Death 3 | Ragnaros | Sulfuras
Smash` with both on — read off the recap's **newest** event, which is the killing blow (the array
arrives newest first, the same fact the timestamp is taken from). Two switches rather than one
because they answer different questions: who killed me is a positioning question and what killed me
is a cooldown question.

**The caster ships on and the spell ships off.** `Death 3` alone says nothing the reader did not
already know — the count is in the cell they hovered to get here — and one name closes that. The
second name is what makes the line long: a spell name is the longest thing on it, it is the half most
often absent, and it answers a question a reader has *after* clicking into the recap rather than while
scanning the list.

Both halves go quiet on their own terms and neither absence is a failure — an environmental death
sets `hideCaster`, a melee swing has no spell name (and is named "Melee", as Blizzard's own recap
does), and a restricted pull can hand either back **secret**. Everything leaves
`modules/Tooltip_Lines.lua`'s `killingBlowOf` through `plainWord`, so what cannot be read plainly is simply
not drawn: the label is built with `..` and every piece of it is a plain string by construction.

`anchor` takes eight values — the four edges and the four corners — and each names **a box of a 3×3
drawn around the hovered cell**. "Top left" is the box above and
to the LEFT; "Left" is the box beside it, growing left. Each therefore names a direction the tooltip
grows in as well as a corner it touches, which is what a player means by picking one.

**There is no "at cursor".** It was the shipped default and it is what every other tooltip in the
game does, which is exactly what was wrong with it here: over a *grid* it lands wherever the pointer
happens to be inside a cell, so the same hover puts the tooltip somewhere different every time and
reads as jitter rather than as a choice. `TOP` is the deliberate version of the same thing, and is
the default. `schemaVersion` 10 rewrites a stored `CURSOR`, and an unrecognised anchor falls back to
`TOP` for the same reason — it is where a new window puts it.

**Blizzard's tokens cannot say that**: `ANCHOR_TOPLEFT` and `ANCHOR_TOPRIGHT` are both directly above
the owner, aligned to one edge or the other, so both grow *across* the thing being hovered — and
there is no token at all for the four diagonals. So `SetOwner` is called with the closest token first,
which gives the tooltip a valid position and keeps it on screen, and `placeTooltip` then lays the
exact box over it with a `SetPoint`.

**The placement is applied AFTER `GameTooltip:Show()`**, and that is not a detail. The show path
**re-anchors** the tooltip to its owner — the same pass that re-fonts its lines, which is why
`reapplyFonts` already runs from exactly there. A point set before the lines were added is silently
thrown away, so the player got the token's placement instead: "Top left" sat directly above the cell
growing right, and no anchor produced the box beside it at all.

**That `SetPoint` is the one place this addon positions anything against a frame that has held a
meter value.** A cell handed a secret has secret anchoring data (rule R3), so this is the one call in
the file that could raise inside Blizzard's own code while tainted by us. It is `pcall`'d, and a
failure leaves the token's placement standing — the tooltip opens in roughly the right place rather
than not at all. `ANCHOR_NONE` and `ANCHOR_PRESERVE` are still absent, and now for a simpler reason:
both mean "the owner places this", which with our own placement gone would be no placement at all.

`maxSpells = 0` means "every spell the breakdown collected", which is the collector's own ceiling of
64 rather than literally unbounded — the "and N more" line stays honest about anything past it.

`showTargets` is off by default for two separate reasons: it costs one provider call per enemy on a
hover to build (cached per session afterwards), and it is a **summation**, so it is absent for the whole of a pull rather
than approximated ([data-flow.md §9](data-flow.md)).

`hideInCombat` is a **preference, not a guard**: a tooltip's numbers go through the formatter like
every other, so nothing about it is unsafe mid-pull — it is simply in the way. The combat test
behind it is `UnitAffectingCombat("player")`, not `InCombatLockdown()`; the setting is a statement
about the player, not about whether secure writes are currently legal.

### `visibility`

**Where to show this window** — every context `true`: `dungeon` · `raid` · `arena` ·
`battleground` · `delve` · `scenario` · `world`.

**When to hide this window** — every rule `false`: `hideWhenSolo` · `hideInVehicle` ·
`hideWhenMounted` · `hideWhenSkyriding` · `hideOnTaxi` · `hideInHousing` · `hideInPetBattle` ·
`hideWhenDead`.

**Combat** — `hideInCombat = false` · `hideOutOfCombat = false`.

**Show everywhere, hide nowhere.** A fresh profile draws the meter wherever the player stands and
nothing takes it away until they ask for it. This reverses 0.1.0, which shipped the open world off
and four rules on. That version was deciding on the player's behalf that a meter in the open world
is noise, and the cost of being wrong is this feature's worst failure: a window that never appears,
with seventeen checkboxes to read before you can tell which one did it. A default that only ever
shows has no such failure mode.

Refused **at the source** (`performance-§6`): a hidden window does not merely skip its draw, it
stops asking the provider for data. `modules/Visibility.lua` maps Blizzard's `instanceType` to these
keys, and anything it has never heard of resolves to `world`. Note what that means now `world` ships `true`:
an instance type a future patch invents **shows** rather than hides — the opposite of 0.1.0's
deny-by-default fallthrough, and the deliberate trade. A context nobody has taught this addon about
draws a meter the player can switch off, rather than silently withholding one they cannot find the
switch for.

**Delves resolve before the instance-type table**, because Blizzard has no delve instance type: a
delve reports `"scenario"`, the same token an ordinary scenario and a follower dungeon report.
`Compat.IsInDelve` owns the three-signal ladder that separates them — `C_PartyInfo.IsDelveInProgress`,
scenario difficulty `208`, `C_DelvesUI.HasActiveDelve` — and takes ANY of them as authoritative,
because outdoor delves do not light all three up together.

**Every rule after the context block is hide-shaped**, and that is load-bearing rather than a naming
habit. A key missing from a stored window has to read as "nothing objects"; a show-shaped key is
`false` when absent, so a profile written before the rule existed would have every window hidden by
a setting its owner never touched. `Database.EnsureWindowShape` backfills the shape, but on a
schedule `modules/Visibility.lua` cannot see and must not depend on. `hideInCombat` and
`hideOutOfCombat` are therefore two independent rules rather than one tri-state; ticking both is a
window that never shows, and `/mm debug diag` still names the side of the pull that decided.

The order of evaluation is context first, then every veto, then combat. Running it the other way
round would report `solo` as the reason a window is hidden in the open world, when the real reason
is that the player switched the open world off.

### `columns` — the ordered stat list

An **array, and it is the whole catalog** — one entry per statistic in `Constants.STATS`, each
carrying `enabled`. Filled by `NS.DefaultWindow` rather than written out in the template, so the
catalog in `core/Constants.lua` stays the single source of truth for which statistics exist;
`Constants.DEFAULT_STAT_KEYS` chooses which of them ship **ticked**.

```lua
columns = {
    { stat = "DamageDone",           enabled = true  },
    { stat = "HealingDone",          enabled = true  },
    { stat = "Interrupts",           enabled = true  },
    { stat = "Dispels",              enabled = true  },
    { stat = "AvoidableDamageTaken", enabled = true  },
    { stat = "Deaths",               enabled = true  },
    { stat = "Absorbs",              enabled = false },
    { stat = "DamageTaken",          enabled = false },
}
```

**Enabled entries always come before disabled ones**, and that ordering is a stored invariant rather
than something the page maintains — `/mm set window.columns ...` and a hand-edited SavedVariables
reach the seam without ever drawing a block. The enabled prefix, in order, is what the window draws
left to right.

It was a SUBSET the player assembled until schemaVersion 12. It is the catalog now because the
Columns page is a fixed list of blocks you tick and drag rather than a list you add to and remove
from — and a page with no add button needs every statistic already present to tick.
`width` and `showBar` went with that change: width had been dead since the window began auto-sizing
(`BuildLayout` divides the frame width evenly across the visible columns and never read `col.width`),
and the bar is unconditional.

`EnemyDamageTaken` is not offered as a column at all — it is read, never catalogued (issue #2) — and
a stored column naming it is now **dropped** by the normalizer rather than listed, because there is
no longer a remove button to act on it with. `Dps` and `Hps` are absent from the catalog entirely and
never queried: `amountPerSecond` ships on the same source row as `totalAmount`, so one `DamageDone`
read fills both halves of the column.

### `data`

`sessionType = Const.SESSION_TYPE.Overall` · `sessionID = Const.NO_SEGMENT` · `sortMode = "value"` ·
`sortColumn = "DamageDone"` · `sortAscending = false`.

**All five are hidden schema rows** (issue #50), filed on the Header page beside `frame.minimised`.
Every one of them is chosen by a control on the window itself: the header's segment menu picks
`sessionType` or pins a stored segment in `sessionID`, and one click on a column header writes the three sort fields
(`modules/Window_Header.lua`'s `SortByColumn`). `architecture-§5` reads a control that chooses a
value as setting it, so they are preferences rather than a remembered view, and a preference goes
through the helper. The controls write them through `NS.SetByPath` / `NS.SetByPaths` with the
window's own id, so a click on one window never writes the window the settings panel is pointed at.
`/mm set window.data.sortColumn HealingDone` takes the same path and the same validation: a stat
outside the catalog, a sort mode the aggregator does not know or a session type the menu never
offers is refused. The three sort rows' `onChange` drops the frozen order, so a sort written from
the CLI takes effect exactly as a click does.

They were rows once, on a Data page, and were deleted because the click wrote around the seam and a
CLI path beside it was a second writer onto the same fields. With the click on the seam there is one
writer again. They stay hidden because a panel copy of a control three inches from where the player
is looking would be a second place for the two to disagree.

**`mergePets` and `throttle` used to live here** and are addon-wide from `schemaVersion` 5, at
`profile.data`. Neither described a window: one says what a pet's damage *is*, the other is a refresh
rate, and two windows disagreeing about either is two answers to one question. The migration lifts
the **first** window's pair per profile and removes the keys from every window — there is no merge
rule that is right for a player who set two windows differently, and the first window is the one at
the top of their own picker. Note that the `== nil` rule that governs `EnsureWindowShape` deliberately
does **not** apply to that step: AceDB's defaults merge runs before any migration, so `profile.data`
is already filled with the shipped values and "the player set this" cannot be told from "the merge
just wrote it" — the window's value is the only one carrying intent.

`sortMode` is `value` / `name` / `provider` / `roster` — `name` is what the **Player** column header
sorts by — and it governs the **unrestricted** build only. While
the Combat restriction is active the rows are the engine's own ranking of the sort column, because
`sourceGUID` is secret and there is nothing of ours left to sort; see `docs/data-flow.md`.
`sortColumn` and `sortAscending` **do** still reach a restricted grid — picking a stat re-ranks it to
the engine's ordering for that stat, and the direction is applied as a reversal — so the two of them
are live in both states while `sortMode` is not.

**`sessionID` is the fifth hidden row, and its "none" is a number.** The segment menu chooses it, so
by `architecture-§5`'s own test it is a preference, and a preference goes through the helper. Its
unpinned state used to be `nil`, which no row default can state, so it is now
`Constants.NO_SEGMENT` (`0`): the row's default, the value its validator accepts beside a positive
integer session id, and what `Database.PinnedSegment` answers as "no pin" for every reader. The
client's session ids are positive, so the sentinel names none of them; a
[smoke test](smoke-tests.md#33-the-pinned-segments-none) confirms that on a live client.
`SetSegment` writes it through `NS.SetByPath` for its own window. `SetSessionType` clears it in the
same `NS.SetByPaths` batch as the type. `DropStaleSegment` clears a stale one through the seam too,
because a row wins. `WindowManager:CopyFrom` carries it in its batch like the other four. An account
saved before the row existed has no key, and `Database.EnsureWindowShape`'s backfill fills in the
sentinel.

When it *does* pin one it **overrides `sessionType`**, and every read path honors it — the aggregator's
column reads, the header's duration, the tooltip's spell breakdown and the drill-down's. A pinned id
the client no longer holds is dropped back to `NO_SEGMENT` by `WindowProto:DropStaleSegment` at the top of
the next refresh, because a stale id does not error, it silently reads an empty session.

---

## The window-relative path model

This is the part of the schema a reader will not guess, and it is the only thing about the schema
that is not standard-issue. The machinery below lives in `settings/Schema_Paths.lua` — path
resolution, the index, the read seam, the write seam and the columns carve-out were peeled out of
`settings/Schema.lua` under the 1500-line cap, along the seam that nothing in them names a single
setting. The array of rows kept the name `settings/Schema.lua`.

### The problem

Almost every setting is per-window, and a window is an instance the user creates at runtime. Written
out absolutely, a window row's path would have to be:

```
windows.<id>.frame.width
```

Dynamic, unknowable when `settings/Schema_Paths.lua` loads, and impossible to express in the **flat
path model** that the CLI (`LibKa0s-Slash-1.0`) and the panel (`LibKa0s-Options-1.0`) both read. A
flat path addresses a fixed named leaf; `<id>` is neither fixed nor named.

### The resolution

A window row's path is **relative to a window** and is spelled with a `window.` prefix:

```lua
{ path = "window.frame.width", type = "number", default = 716, page = "frame", ... }
```

`NS.GetSetting` and `NS.SetByPath` resolve that prefix against the session's **active window** —
`NS.State.activeWindowId`, which the settings panel's window picker moves. Global rows keep absolute
paths and resolve against `db.profile`. There are twenty-two of them: `enabled`, `minimap.hide`, the
four `master.*` controls (`options-ui-§15`'s addon-wide visibility, scale, alpha and lock, distinct
from the per-window `frame.*` three), `data.mergePets`, `data.throttle`, the four `export.*`
preferences, the eight `statColors.*` swatches, and the two `sessionOnly` rows `state.testMode` and
`state.debugConsole`, whose own `get`/`set` are the whole of their storage. The other 147 rows are
window rows.

```lua
-- settings/Schema_Paths.lua
local function resolveRoot(parts)
    if parts[1] == "window" then
        local w, id = activeWindow()      -- picker's selection, else windows[1]
        return w, 2, id
    end
    return NS.db and NS.db.profile or nil, 1, nil
end
```

`activeWindow()` falls back to **the first window in the registry** when nothing is selected, rather
than to nil. The CLI has no picker, and `/mm set window.frame.width 300` typed on a fresh login must
mean something rather than fail with a message about an internal pointer the user has never heard
of. `settings/Windows.lua` and `settings/Columns.lua` heal a stale pointer the same way on every
read.

### What it buys

One schema, one write seam, and one sentence that is true in both surfaces: **`window.frame.width`
means "the window I am editing"**, on the CLI exactly as in the panel. The picker retargets seventy
or so rows by moving one integer of session state instead of by rewriting every path. The panel does
not filter rows per window — it *moves the window every row resolves against*, which is why
`NS.SchemaForPage(pageKey, filter)` accepts the library's `ctx.unit` and passes it through
untouched.

### Why `NS.ValidateSchema` exists

The cost of the relative model is that a `window.`-prefixed path is resolved against a table that
does not exist until runtime, so a typo cannot fail at load. `NS.ValidateSchema()` is what closes
that hole. It runs from the options descriptor's `validate` hook at panel creation and is asserted
to return **0** by the headless suite. Two independent checks per non-session row:

1. **Resolution.** Every path must resolve against `defaults/Profile.lua` — `window.` rows against
   `NS.WINDOW_TEMPLATE`, global rows against `NS.defaults.profile`. A path that does not resolve is
   a setting whose writes land on a key nothing reads: the panel renders, the widget shows the row's
   own default, the write succeeds, and nothing anywhere says so. The row's own `default` is **not**
   an escape hatch from this — a row with a good default and a typo'd path is the worst case, not
   the exempt one.
2. **Agreement.** The row's `default` must equal the value the defaults tree ships. The two are
   restated in two files on purpose: one is what a widget shows before the db exists, the other is
   what a fresh profile is built from. A single shared reference would agree with itself by
   construction and prove nothing. A disagreement means a Defaults click silently moves a setting
   somewhere the addon never shipped it — the bug this function exists to catch.

Table defaults (every color) are compared field-wise one level deep, which is exactly as deep as
this schema's table defaults go.

---

## Row shape

```
path         resolution path. `window.`-prefixed = active window; else db.profile.
type         "bool" | "number" | "string" | "color". THE widget dispatch key —
             the options major picks a maker from it and the slash major picks a
             parser from the same field, which is what keeps the CLI and the panel
             agreeing about what a row is. There is deliberately no separate
             `widget` field: a second selector is a second thing to keep in step.
default      the shipped value; MUST equal defaults/Profile.lua's.
page         the page key. Groups `/mm list`, feeds the panel's rowsForPage, names
             the CONFIG_CHANGED section, and `page == "profiles"` is the reset-all
             veto. One key, four jobs.
group        section heading inside the page, AND the tab label on a tabbed page --
             `RenderTabbedSchema` partitions a page's rows by `group`, in
             declaration order, and draws one tab per distinct value. One tab is
             exactly one group; there is deliberately no second field naming a
             tab. A group whose every row is `hidden` is still real for `/mm
             list` and the schema-vs-defaults check, and never becomes a tab —
             `rowsForPage` drops hidden rows before grouping runs.
subgroup     a heading drawn INSIDE a tab, whenever the value CHANGES within a
             group (options-ui-§7). It names the KIND of control a mixed tab is
             holding -- Background, Border, Divider, Layout, Icon, Color, Opacity,
             All surfaces -- never a repeat of its own tab's name, and never a
             second tab level. Like a group it must be CONTIGUOUS, or its heading
             prints twice. Four tabs carry them; the rest hold one kind of control
             and need none.
label, desc  displayed strings, localized at declaration through NS.L. The flow
             engine reads `row.tooltip or row.desc`, and this addon spells it
             `desc` everywhere -- including on composed rows, where `dress()`
             clears the composer's English `tooltip` as it writes one.
startsLine   flush the pending line BEFORE this row, so a declared pair cannot be
             split across two lines by an odd number of widgets above it. Carried
             by every colour swatch, which is what makes "the mode is immediately
             to its right" a property of the declaration rather than of parity.
classColorSource   "player" | "unit" -- WHICH class this surface's `class` mode
             means, DECLARED rather than inferred (options-ui-§17). The path does
             not decide it: everything under `window.*` here is per-window, and the
             split is by surface. A cell, its outline and the tooltip are about the
             ROW's player (`unit`); the window's chrome, both header strips, the
             backdrop and the border are about the window, so they are the local
             player's (`player`).
min/max/step/fmt/isPercent    slider shape.
values/sorting/dialogControl  dropdown shape. A `number` row carrying `values` is
             inferred as an enum by both majors and constrained rather than clamped.
validate     optional predicate; a false answer refuses the write.
onChange     optional reaction for the few settings CONFIG_CHANGED cannot express.
invert       display is the negation of storage (the one minimap row).
sessionOnly  never persisted; the row's own get/set are the whole storage.
composed     stamped by `expandBlocks` on every row a LibKa0s composer emitted.
             Inert to every reader of the schema; it exists so
             tests/test_degraded.lua can say exactly which rows a library-less
             install is allowed to be missing rather than compare two totals.
```

### The composed blocks

Roughly a third of the rows are not written out. `options-ui-§15`, `§16` and `§17` fix the master
controls and the font, border and bar groups across the collection, and `LibKa0s-Options-1.0`'s
composers emit each from one declaration (`anti-patterns #73`). What that changes about the row shape
is nothing at all — a composer returns an array of **ordinary rows**, so `rowsForPage`,
`ApplyDefault`, `RestoreDefaults`, the CLI and the reset sweep all keep working untouched.

The calls live in `settings/Schema_Compose.lua`, which is what the array in `settings/Schema.lua`
is declared out of. What they add around the composers is three things:

- **`keys` and `defaults`** on every call, so the composed rows land on this addon's existing paths
  at this addon's shipped values. **The composer must not change what is stored.**
- **`dress(rows, byPath)`** afterwards, which puts back what the composers have no override for: the
  slider bounds, the `%d px` suffix, the validator, the stored value set behind a dropdown, and this
  addon's own sentence in each tooltip.
- **`withMode(rows, after, modeRow)`**, which swaps the composer's boolean `Use class color`
  companion for this addon's colour-**mode** dropdown — the richer form `options-ui-§17` names and
  forbids converting back — splicing it immediately after the swatch.

See [settings-panel.md](settings-panel.md#the-composed-blocks) for which block is used where, and
`docs/ARCHITECTURE.md`'s deviation register for what a load without LibKa0s does to them.

### `invert` — exactly one row

`minimap.hide` stores the negation of what it displays. LibDBIcon owns the `minimap` table and its
key is `hide`, while a checkbox a user reads has to say "Show minimap button" — a checkbox labelled
with a negative is the settings-panel double-negative everyone mis-clicks once. Rather than give
that one row a private get/set pair (which the CLI would then have to know about separately), the
seam carries a two-line `toStored` / `toDisplay` concept used at three call sites. `default` is
always the **stored** value, so the validator still compares like with like.

### `sessionOnly` — exempt from validation, still rows

`state.testMode` and `state.debugConsole` are never persisted, so they have no home in the defaults
tree and `NS.ValidateSchema` skips them. They are rows anyway because they belong on the page and in
`/mm list` beside the settings they sit next to — a toggle that exists only in the panel is a toggle
the CLI cannot reach. Their own `get` / `set` **are** the whole storage; `NS.GetSetting` returns
`row.get()` directly rather than `and`-ing it through, because a session row answering `false` is a
real answer and `row.get() or nil` would turn every "off" into "no such setting".

### `onChange` — the exception, not the rule

The default refresh for every row is the `CONFIG_CHANGED` message `NS.SetByPath` sends, and
`settings/Schema_Paths.lua` is its **one sender**. Windows subscribe and re-read their upvalues; the
panel re-reads its scalars. `onChange` exists only where the message genuinely cannot express the effect:

- every `window.visibility.*` row and `enabled` → `refreshVisibility()`, because the effect is a
  window appearing or disappearing (the show ladder's decision), not a window redrawing;
- `minimap.hide` → `refreshMinimap()`, because LibDBIcon holds a Blizzard-side object outside our
  config tree and has to be told to look again.

Both live in `settings/Schema_Compose.lua` alongside the vocabularies and the composers, and both
resolve their target at **call** time rather than at file scope — `refreshVisibility` reads
`NS.Visibility`, `refreshMinimap` reads LibDBIcon's own registry — so neither depends on what had
finished loading when the schema file ran.

---

## The write seam

`NS.SetByPath(path, value, windowId)` is the single write seam (`settings-schema-§1`). The panel's
widgets, `/mm set`, `/mm reset`, `NS.ApplyDefault` and the global Defaults sweep all land here, so
validation, the debug line, the row's reaction and the refresh cannot be skipped by whichever caller
forgot one. `windowId` is optional: omitted, a `window.*` path means the active window; given, it
means that window and no other (see [the window registry](#the-window-registry-and-its-writer)).

`NS.SetByPaths(writes, windowId, label)` is the same seam taking several `{ path, value }` writes as
one change. Each entry goes through exactly what `NS.SetByPath` does, and every entry is checked
before any is stored, so one refusal stores nothing. Only the tail differs: one debug line naming
the batch and its row count, and one `CONFIG_CHANGED`. Its `section` is the page when every row
shares one and `nil` when they do not, so no subscriber skips part of a change. A copy-from and a
resize drag use it.

**Order is load-bearing**: write → react (`onChange`) → log once → announce `CONFIG_CHANGED` →
re-sync the panel's scalars. Reacting before the write would hand a refresher the old value; logging
in the reactor would log it once per subscriber.

Values are **deep-copied on the way in**. A color table handed straight from a widget (or from a
row's default) would otherwise be shared with whoever else holds it, and editing one window's color
would edit theirs. `NS.ApplyDefault` copies for the same reason, and takes the **row** rather than
the path because both library majors hand over the row.

The announcement carries `{ section = row.page, windowId = <id or nil> }`. A window ignores a
payload naming a different id, so a twenty-window profile does not re-apply nineteen windows because
one of them was edited.

The refresh at the tail is `Helpers.RefreshScalars()` — an in-place value re-read, never a structural
rebuild. A structural refresh here would rebuild the page under a slider mid-drag, and writing a
value emphatically does not change which rows exist. (The picker on the Windows page *does* force a
structural sweep, because there the rows changed **subject**; see `docs/settings-panel.md`.)

---

## The columns carve-out

`window.columns` is an ordered array whose length is the user's, not the schema's. A path model
addresses named leaves; it has no vocabulary for "insert a column before index 2". So the columns
subtree is a documented carve-out rather than a row:

| Operation | Behavior |
|---|---|
| `/mm get window.columns` | **reads** — the generic resolver reaches it like any other node |
| `NS.SetByPath("window.columns", array)` | **accepted whole-array** — the only granularity a path can honestly express |
| `NS.SetByPath("window.columns.2.width", 90)` | **refused** — the ordinal moves on the next add, remove or reorder, so a stored reference to it is wrong by the next edit |

Because the array has no row, it gets none of a row's `validate`, so the check lives at the seam.
`normalizeColumns` proves the array shape before reading anything out of it (a hole or a string key
would make `#value` an arbitrary answer), then rebuilds it entry by entry.

**It REPAIRS rather than rejects**, which is the change schemaVersion 12 brought with it. An entry
naming a statistic this build does not have used to be stored and listed so the player could remove
it; with no remove button and a list that *is* the catalog, there is nothing they could do with the
row. So the normalizer:

- **drops** an entry whose `stat` is not in `Constants.STAT_BY_KEY`, and **drops** a repeat — the
  first appearance wins, so a later duplicate cannot quietly overrule the position already given it.
  Two Damage columns would show identical numbers twice and double the provider reads for them;
- **appends** every catalog statistic the caller did not mention, `enabled = false`, in catalog
  order — which is what makes a statistic added to `core/Constants.lua` appear on every existing
  profile's page with no migration of its own;
- **partitions** enabled ahead of disabled, stably, so relative order inside each group is the
  caller's.

Two things it still refuses outright, because neither has an answer it could invent: an array that
is not gapless, and one with **nothing enabled** — a window of nothing but names reads as a broken
addon, and there is no way to guess which column was meant to survive.

It is published as `NS.NormalizeColumns` so `core/Database.lua`'s `migrations[11]` shares the one
definition. That is a **deferred** read: `settings/Schema_Paths.lua` loads thirty-one TOC entries
later, but the ladder runs on Init, which is the same pattern `migrations[1]` already uses for
`NS.WINDOW_TEMPLATE`.

Rebuilding rather than accepting the caller's table does two jobs at once: the stored array can never
share a sub-table with whoever handed it over, and any extra key someone smuggled in is dropped
rather than persisted into a profile the renderer will not read. The write then takes the **same**
debug line, `CONFIG_CHANGED` message and panel re-sync every scalar write takes — a direct table
write in the page would be a second seam that looks identical and announces nothing.

---

## Merging a stored profile forward

AceDB's defaults merge fills keys of tables it knows about. It does **not** know that
`profile.windows[3]` is supposed to look like `WINDOW_TEMPLATE`, because it cannot reach inside an
array. So the per-window merge is ours, in `Database.EnsureWindowShape` → `fillMissing`.

### The `== nil` rule

```lua
for k, v in pairs(template) do
    if stored[k] == nil then
        stored[k] = copy(v)
    elseif type(v) == "table" and type(stored[k]) == "table" and v[1] == nil then
        fillMissing(stored[k], v)
    end
end
```

The presence test is `stored[k] == nil`. **It is never `stored[k] or template[k]`.**

`or` cannot tell *unset* from a stored `false`, `""` or `0`, and this profile is full of exactly
those values — `frame.locked = false`, `header.title = ""`, `rows.maxRows = 0`,
`bars.border = false`, `icons.showIcon = false`, `visibility.world = false`. An `or` merge would
silently reset a user's deliberate "off" back to the shipped "on" on every single login, and would
do it invisibly, because the setting they turned off would simply be on again.

The same rule appears in `core/CoreSetup.lua`'s `fallbackRGBA` (a stored channel of `0` survives as
`0`) and in `settings/Schema.lua`'s session-row read. It is one rule, applied everywhere a stored
value can legitimately be falsy.

### Arrays are left alone

The recursion guard is `v[1] == nil` — recurse into **keyed** sub-tables only. `columns` is an
ordered list the user edits, and key-filling it against the template would re-add columns they
removed. An **absent** `columns` array is a broken profile rather than an older one, and gets an
empty table so the window still renders.

`fillMissing` is idempotent and shape-driven, so it is safe to run on every login, every profile
swap, and after every `CopyFrom` and `Duplicate` — which is exactly where
`modules/WindowManager.lua` calls it.

---

## Profile lifecycle

`core/Database.lua` registers one callback for all three AceDB profile events:

```lua
db.RegisterCallback(Database, "OnProfileChanged", "OnProfileChanged")
db.RegisterCallback(Database, "OnProfileCopied",  "OnProfileChanged")
db.RegisterCallback(Database, "OnProfileReset",   "OnProfileChanged")
```

Each one runs `NS:RunMigrations()` (the newly-active profile may be a copy authored at an older
version, or a reset back to an empty registry), clears `NS.State.activeWindowId`, wipes every
session cache, and fires **one** `PROFILE_CHANGED` message. `fireProfileChanged` is the single
emitter — every path that makes the active profile a different thing routes through it, so the bus
catalog names one site and stays true.

`AceDB:New("MultiMetersDB", NS.defaults, true)` passes `true` as the third argument, which AceDB
expands to the shared `"Default"` profile. Omitting it falls back to a **per-character** profile,
which contradicts the documentation and is the source of every "each new character lands on its own
settings" report in the collection. Players who want per-character opt in through the Profiles page.

---

## Adding to the schema

The full recipe, with the gotchas, is in [common-tasks.md](common-tasks.md#add-a-setting). The short
version: one row in `settings/Schema.lua`, one matching default in `defaults/Profile.lua` at the same
path (relative to `WINDOW_TEMPLATE` for a `window.` row), the label and desc in `locales/enUS.lua`,
and nothing else — `/mm get|set|list|reset`, the page widget, the per-page Defaults button and
`/mm resetall` all follow. Then run `lua tests/run.lua`, which asserts `NS.ValidateSchema() == 0`.
