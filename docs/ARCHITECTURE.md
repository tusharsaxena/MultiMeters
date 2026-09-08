# Architecture

Orient-yourself map for **Ka0s Multi Meters**. A single-frame, multi-column group meter for Retail
(Midnight, 12.x): one row per group member, one column per statistic, each cell a `StatusBar` with a
`FontString` on it. Every number is read from Blizzard's built-in damage meter through
`C_DamageMeter`; the addon never parses the combat log.

This file is the hub. Topic detail lives in `docs/` and is linked from each section — a section here
that outgrows a screen belongs in its topic doc with a summary and a link left behind.

## Overview

Forty-five non-vendored source files: 1 locale, 15 `core/`, 1 `defaults/`, 15 `modules/`, 13 `settings/`.

The addon is built on the **private namespace** WoW hands each file. `core/MultiMeters.lua` calls
`AceAddon-3.0:NewAddon(NS, addonName, …)`, which promotes that table in place — so **`NS` *is* the
addon object**. There is no `_G.MultiMeters` and no rebind. `NS.addon` is published for callers that
want to name "the AceAddon object" without assuming the promotion.

Three things define the shape of everything else:

- **The data source is Blizzard's.** `C_DamageMeter` accumulates the numbers; this addon reads,
  joins, orders and draws them. `modules/Provider.lua` is the only caller, through `core/Compat.lua`'s
  guarded shims — so an 11.x client, or a PTR build missing one function, degrades to a window
  rendering Blizzard's own failure reason rather than erroring at load.
- **Those numbers are secret in combat.** See [Taint notes](#taint-notes). This is the defining
  constraint and it is why the aggregator has two builds rather than one, why the formatter exists,
  and why there is no column drag editor.
- **A window is an instance, not a singleton.** There are no global display settings: `frame`,
  `header`, `rows`, `bars`, `text`, `icons`, `tooltip`, `visibility`, `columns` and `data` all live
  inside one window's own config. That is what makes multi-window and copy-settings-from cheap — a
  copy is a deep table copy, optionally filtered to one group — and it is why the profile itself is
  nearly empty: an array of windows, an id counter, two addon-wide toggles, and the `export` group,
  which remembers an **action** the player takes rather than how any one window looks.

Eight statistics are catalogued in `core/Constants.lua`; six ship enabled on a new window (Damage,
Healing, Interrupts, Dispels, Avoidable Damage, Deaths). Adding a ninth is one row in that catalog —
the column editor, the defaults, the aggregator's read loop, the sort-column dropdown and the tooltip
header all read the same table.

`EnemyDamageTaken` is **read but not catalogued**. The meter offers it and `modules/Targets.lua`
walks it to build "which enemies this player hit", but it is not a column: every catalog row answers
a question about a group member, and that one answers a question about an enemy, so offering it as a
column asked a single grid row to be both a player and a mob. `Constants.STAT_BY_KEY` is therefore
"may this be a column" and `Constants.READABLE_STAT_BY_KEY` — the catalog plus
`Constants.OFF_CATALOG_STATS` — is "may this be read", which is the lookup `modules/Provider.lua`
alone uses. It returns as its own window type, whose rows are enemies
([issue #2](https://github.com/tusharsaxena/MultiMeters/issues/2)).

Chrome comes from LibKa0s-Core-1.0's shared `SKIN` / `ApplySkin`, never a private lookalike, so the
meter window, the debug console and the perf step panel wear the same Ka0s edge as every sibling
addon. Nine LibKa0s majors are consumed — Core, Media, Perf, DebugLog, Env, Pool, Slash, Options and
Widgets. Eight are reached through a seam file of their own (`core/CoreSetup.lua`,
`core/MediaSetup.lua`, `core/PerfSetup.lua`, `core/DebugLogSetup.lua`, `core/EnvSetup.lua`,
`core/PoolSetup.lua`, `settings/Slash.lua`, `settings/OptionsSetup.lua`); Widgets has no seam file and
is resolved at each of its two call sites — `modules/Export.lua`, whose modal builds the addon's only
dropdowns, and `settings/ColumnBlocks.lua`, whose block list is the library's `ReorderList` — because
both widgets are built lazily on first use rather than wired at load. Every one of the nine degrades
rather than erroring when `libs/LibKa0s` is absent. Three of them pass the addon's own **folder name** to the library, and all three now say so
explicitly: `core/CoreSetup.lua`'s `MakeCloseButton` wrapper, and the descriptors in
`core/DebugLogSetup.lua` and `core/PerfSetup.lua`. The perf one used to reach the right answer only
through `name` — `PerfPanel.lua` minor 4 reads `addonName or name`, so it was right by luck and one
rename away from wrong — and it now states `addonName` beside `name`, the same shape the console's
descriptor has. This is why that file passes **no** `decorate` hook:
the one it used to carry drew a close button with the name dropped, so the panel wore a
multiplication sign beside a console wearing the mark. The name matters because a texture path is
absolute from `Interface\AddOns\`
and a vendored library cannot know which folder it was copied into — that is what lets the library's
own windows wear the same close, copy and clear marks the meter window's header draws. Five explain the
absence through the one shared cause clause `NS.LIBKA0S_MISSING`; **Media is deliberately silent**,
because what it degrades is chrome. The icons this window draws and its monospace face ship inside the
LibKa0s payload (`LibKa0s-Media-1.0`), so a missing library takes the art with it — the header walks
down its own atlas-then-ASCII ladder, the numbers fall back to the client font, and neither wants a
line of chat about it.

Full scope boundaries, including the two features that are structurally impossible rather than merely
unbuilt, in [scope.md](scope.md).

## Module map

Every file, what it owns, what it publishes, what it consumes, plus TOC load order and the AceAddon
lifecycle: **[module-map.md](module-map.md)**. The shape at a glance:

| Layer | Files | Responsibility |
|---|---|---|
| `locales/` | `enUS.lua` | `NS.L`, with the key-is-the-string fallback. Loads first. |
| `core/` boundary | `Compat.lua` | All 28 cross-patch shims, including the eight `C_DamageMeter` reads. No logic. |
| `core/` boundary | `EnvSetup.lua` | The `LibKa0s-Env-1.0` seam: `NS.Meta` / `NS.Version`, the TOC-manifest reader `Compat.lua` used to own. |
| `core/` values | `Constants.lua`, `Namespace.lua`, `State.lua` | The stat catalog, the bus catalog, identity, session-only flags and the shared cache. |
| `core/` the rule | `Secrets.lua` | **The only file that inspects a meter value.** |
| `core/` seams | `MediaSetup`, `CoreSetup`, `PerfSetup`, `DebugLogSetup`, `PoolSetup` | LibKa0s wiring, the art and font seam, and the window row pool. The `LSM30_Border` fixup that used to make a sixth file here is `lib.__PatchLSM30Border()` now, called from `settings/OptionsSetup.lua`: AceGUI's widget registry is process-global, so a re-registration belongs to the library the whole collection shares. |
| `core/` runtime | `MultiMeters.lua`, `Database.lua` | The single game-event listener and the show ladder; AceDB and migrations. |
| `defaults/` | `Profile.lua` | The window template. The only place a profile default is hardcoded. |
| `modules/` data | `Provider`, `Roster`, `Feign`, `Aggregator`, `Format` | Read → join → order → render as text. `Feign` is the one source row the addon deliberately discards. |
| `modules/` display | `WindowManager`, `Window`, `HeaderControls`, `Row`, `Targets`, `Tooltip`, `DrillDown`, `Visibility`, `Minimap` | The registry, one window, one row, the enemy cross-reference, the two hover surfaces, the breakdown, the context predicate, the launcher. |
| `modules/` output | `Export` | The segment a window is pointed at, as CSV or as ranked chat lines. Calls no meter API — it asks the aggregator, exactly as a window does. |
| `settings/` | `Schema`, `Slash`, `OptionsSetup`, `ColumnBlocks` + 9 pages | One schema drives the panel, the CLI and the defaults reset; `ColumnBlocks` is the Columns page's row, drawn into `LibKa0s-Widgets-1.0`'s `ReorderList`. |

The path a number takes through those layers — the throttle, the GUID join, pet folding, the sort
identity build, the formatter and the widget setters — is **[data-flow.md](data-flow.md)**. Read it before
touching the data path.

## Settings schema

`NS.Schema` in `settings/Schema.lua` is the single source of truth: **162 rows across 8 page keys**
(windows 1, frame 26, header 31, bars 28, tooltip 30, visibility 17, columns 8, general 21), each one
wiring automatically into its panel widget — one tab per distinct `group`, via
`LibKa0s-Options-1.0`'s `RenderTabbedSchema` — its `/mm get|set|list|reset` coverage, and the
per-page and global defaults reset. A ninth registered page, Profiles, hosts no schema rows at all.
Adding a setting is one row and never a parallel mutator; adding a tab is a `group` no existing row
on that page uses, and nothing else.

**Roughly a third of those rows are COMPOSED rather than written out.** `options-ui-§15`, `§16` and
`§17` fix the master-controls set and the font, border and bar blocks across the whole collection,
and `LibKa0s-Options-1.0`'s composers emit each from one declaration — a hand-written copy is
anti-pattern #73. What comes out is an array of ordinary rows, so nothing downstream changed. See
[settings-panel.md](settings-panel.md#the-composed-blocks) for which block is used where, and the
[deviation register](#documented-deviations) for what a load without LibKa0s does to them.

The write seam is `NS.SetByPath`; the reader is `NS.GetSetting`. Both the panel and the CLI point at
them, so `/mm set window.frame.width 300` takes exactly the path a slider takes — same validation,
same debug line, same `CONFIG_CHANGED` message, same panel re-sync.

**The window-relative path model** is the one thing here that is not standard-issue. Almost every
setting is per-window, and a window is an instance created at runtime — so an absolute path would
have to be `windows.<id>.frame.width`: dynamic, unknowable at load, and inexpressible in the flat
path model the CLI and the panel both read. Resolution: a window row's path is **relative** and
spelled `window.frame.width`, resolved by the seam against `NS.State.activeWindowId`, which the
settings panel's window picker — `H.WindowBanner`, decorated by `settings/Windows.lua` and drawn on
all seven window pages — moves. The other **twenty-one** rows keep absolute paths and resolve against
`db.profile`: `enabled`, `minimap.hide`, the four `master.*` controls (`options-ui-§15`'s addon-wide
visibility, scale, alpha and lock — distinct from the per-window `frame.*` three, and composed with
them rather than replacing them), `data.mergePets`, `data.throttle` (addon-wide since schemaVersion
5), the three `export.*` preferences, the eight `statColors.*` swatches (generated one per
`Constants.STAT_COLORS` entry — see [settings-panel.md](settings-panel.md#the-statistic-palette)),
and the two `sessionOnly` rows `state.testMode` and `state.debugConsole`, whose own `get`/`set` are
the whole of their storage. Moving one integer of session state retargets **141** rows.

One page carries **zero** schema rows: `settings/Profiles.lua` hosts AceDBOptions' own tree and is
the one place `AceConfigDialog` is permitted, because the options table is not ours to re-express. It
is also the one page vetoed from reset-all — resetting it deletes user data. `settings/Columns.lua`
carries **eight** — the `window.columnHeader.*` text and background rows, moved here from Header
because this is the page that labels the strip they style — alongside its bespoke block editor, which
still edits an ordered array whose length is the user's, a shape a path model has no vocabulary for:
`window.columns` is a documented carve-out, read like any node and accepted **whole-array** on write,
validated and rebuilt entry by entry by the same seam.

`NS.ValidateSchema()` proves every row's `default` equals `defaults/Profile.lua`'s. The two are
restated independently rather than sharing a reference precisely so the check can prove something.

Panel behavior, the widget makers and the page tree: [settings-panel.md](settings-panel.md). The
persisted shape and the migration seam: [schema.md](schema.md).

## Message bus

Fourteen `AceEvent` messages are the only inter-module communication channel — modules never call each
other across boundaries. Every name is declared once in `core/Constants.lua`'s `MSG` catalog, so a
typo in a subscriber is a nil-index at load rather than a callback that silently never fires.
**One sender each**; a second sender is a bug, not a convenience.

| Message | Sender | Consumers | Payload |
|---|---|---|---|
| `METER_UPDATED` | `core/MultiMeters.lua` | `Targets`, every `Window` | — |
| `METER_SESSION` | `core/MultiMeters.lua` | `Provider`, `Targets`, every `Window` | `{ type, sessionID }` |
| `METER_RESET` | `core/MultiMeters.lua`, and `Provider.Reset` for the manual path | `Provider`, `Aggregator`, `Targets`, `DrillDown`, every `Window` | — |
| `ROSTER_CHANGED` | `core/MultiMeters.lua` | `Roster`, `Visibility`, every `Window` | — |
| `ZONE_CHANGED` | `core/MultiMeters.lua` | `Visibility`, every `Window` | — |
| `ENTERING_WORLD` | `core/MultiMeters.lua` | `Provider`, `Roster`, `Visibility`, every `Window` | `{ isLogin, isReload }` |
| `RESTRICTION_CHANGED` | `core/MultiMeters.lua` | every `Window`, the export modal (`modules/Export.lua`) | `{ type, state }` |
| `COMBAT_CHANGED` | `core/MultiMeters.lua` | `Visibility`, every `Window` | — |
| `PLAYER_STATE_CHANGED` | `core/MultiMeters.lua` | `Visibility`, every `Window` | — |
| `PROFILE_CHANGED` | `core/Database.lua` (`fireProfileChanged`) | `Format`, `Roster`, `Aggregator`, `Targets`, `WindowManager`, `DrillDown`, `Visibility`, `settings/Profiles.lua` | `{ newProfileKey }` |
| `CONFIG_CHANGED` | `settings/Schema.lua` (`NS.SetByPath`) | `Format`, every `Window` | `{ section, windowId }` |
| `WINDOWS_CHANGED` | `modules/WindowManager.lua` (`announce`) | `DrillDown`, the settings panel | `{ windowId, action }` |
| `TEST_MODE_CHANGED` | `core/State.lua` (`State.SetTestMode`) | `Roster`, every `Window` | `{ enabled }` |
| `DRILLDOWN_CHANGED` | `modules/DrillDown.lua` (`announce`) | the addressed `Window` | `{ windowId, active }` |

`METER_RESET` has two dispatch paths on purpose: the game fires `DAMAGE_METER_RESET` and
`Provider.Reset` also announces, so a manual reset does not depend on the event arriving. Every
handler on it is idempotent, and a duplicate wipe is a far smaller problem than a window still
drawing rows for sessions that no longer exist.

`CONFIG_CHANGED` and `WINDOWS_CHANGED` are deliberately distinct: the first is a setting moving
inside a window that already exists (re-apply and refresh), the second is the registry changing
*shape* (rebuild, and the panel re-draws its picker). Both carry `windowId`, so a twenty-window
profile does not re-apply nineteen windows for one edit.

**Bus-target discipline.** CallbackHandler keys callbacks by `(message, target)`, so two receivers of
one message on the same object silently clobber each other and only the last registrant fires. This
addon is unusually exposed — every window subscribes to the same refresh messages and there can be
many windows. AceAddon modules are their own targets; each `Window` instance, `modules/Format.lua`
and the export modal own a private target from `NS.NewBusTarget()`. Nothing registers on the shared
addon object.

## Slash commands

`/mm` and `/multimeters` are aliases, registered through AceConsole (never a raw `SLASH_*` global).
`NS.COMMANDS` in `settings/Slash.lua` is the sender-authoritative dispatch table: **16 verbs**, the
ten reserved ones first in the order the standard fixes, then this addon's six. The dispatcher, the
help renderer and the schema CLI are LibKa0s-Slash-1.0's; the verb table stays this addon's and is
passed *in*, because the settings landing page renders the same rows and library ownership would make
that a load-time cycle between two majors.

| Command | What it does |
|---|---|
| `help` | Show the command index |
| `config` | Open the settings panel (`options` is accepted as an alias) |
| `list` | List every setting and its current value |
| `get <path>` | Read one setting |
| `set <path> <value>` | Write one setting |
| `reset <path>` | Reset one setting to its default |
| `resetall` | Reset the active profile to the shipped defaults — a **profile reset**, so it is the equivalent of a new profile: extra windows are deleted and one fresh window is left. The same act as Profiles → Reset Profile; other profiles are never touched. See [settings-panel.md](settings-panel.md#reset-all-settings-vs-reset-profile) |
| `debug` | Toggle the console window; `on` / `off` set session logging; **`diag`** prints the diagnostic report; **`recap`** prints the death-recap probe alone; **`identity`** prints the mid-pull identity-correlation capture (issue #22); **`feign on`** / **`feign off`** arm and disarm the feign-death recording and **`feign`** prints it (issue #25) |
| `perf` | Performance capture — `/mm perf help` for the run's own verbs |
| `version` | Print the addon version, read from the TOC manifest |
| `lock` | Lock or unlock every window for dragging. It governs movement and nothing else: unlocking no longer switches Test mode on |
| `test` | Toggle test mode — placeholder rows, for positioning |
| `toggle` | Show or hide one window by name, or all of them |
| `window` | `list` · `new <name>` · `delete <name>` · `copy <source> <target>` |
| `reset-positions` | Move every window back to the center of the screen |
| `export` | Open the export modal for one window's segment: `/mm export [window]` |

The six host verbs act on **windows** — instances the registry owns — rather than on schema rows, so
they are untouched by the library's absence and route straight into `modules/WindowManager.lua`
rather than duplicating its rules. Window keys accept either an id or a name: a number is an id, a
string is a name, matched case-insensitively but stored exactly as typed.

`export` is the one of the six that ends somewhere other than the registry: it resolves a window the
same way `/mm toggle` does, then hands the **config** — not the live instance — to `NS.Export:Open`. A window in the registry that has never been built still points at a segment, and
its numbers are as exportable as a drawn one's. Named with no argument it means the window the
settings panel is pointed at, falling back to the first in the registry, because the CLI has no
picker and `/mm export` on a fresh login has to mean something. Whether an export may run at all is
asked once, of `NS.Export.Available()`, and is never re-decided here — see [Taint notes](#taint-notes).

## Event subscriptions

**`core/MultiMeters.lua` registers every game event this addon listens to, and no other file
registers any.** Each handler does the minimum translation and republishes onto the bus; none reads a
value and — with two stated exceptions, the feign filter and the system-message filter below — none
decides anything, which is what lets that section be read as a wiring diagram.

| Event | Handler | Becomes |
|---|---|---|
| `PLAYER_ENTERING_WORLD` | `OnEnteringWorld` | `ENTERING_WORLD { isLogin, isReload }` |
| `GROUP_ROSTER_UPDATE` | `OnRosterUpdate` | wipes the `Roster` cache **first**, then `ROSTER_CHANGED` |
| `ZONE_CHANGED_NEW_AREA` | `OnZoneChanged` | `ZONE_CHANGED` |
| `ADDON_RESTRICTION_STATE_CHANGED` | `OnRestrictionChanged` | mirrors `NS.State.restricted`, then `RESTRICTION_CHANGED { type, state }` |
| `DAMAGE_METER_CURRENT_SESSION_UPDATED` | `OnMeterUpdated` | `METER_UPDATED` |
| `DAMAGE_METER_COMBAT_SESSION_UPDATED` | `OnMeterSession` | `METER_SESSION { type, sessionID }` |
| `DAMAGE_METER_RESET` | `OnMeterReset` | wipes every cache, then `METER_RESET` |
| `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` | `OnCombatChanged` | `COMBAT_CHANGED` |
| `PLAYER_MOUNT_DISPLAY_CHANGED`, `UNIT_ENTERED_VEHICLE`, `UNIT_EXITED_VEHICLE`, `UPDATE_SHAPESHIFT_FORM`, `PLAYER_CAN_GLIDE_CHANGED`, `PLAYER_IS_GLIDING_CHANGED`, `PET_BATTLE_OPENING_START`, `PET_BATTLE_CLOSE`, `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST` | `OnPlayerStateChanged` | `PLAYER_STATE_CHANGED` |
| `UNIT_SPELLCAST_SUCCEEDED` | `OnSpellSucceeded` | **the one handler that decides something** — Feign Death (5384) only, straight into `modules/Feign.lua`. Nothing reaches the bus: republishing every cast in a raid to save one comparison would be worse, and no other file may see a game event |
| `CHAT_MSG_SYSTEM` | `OnSystemMessage` | **the second handler that decides something** — offered straight to `modules/Export.lua`'s `NoteSystemMessage`, which answers `false` unless a whisper dump is in flight. Nothing reaches the bus, for the reason above it: the line is chatty, one file cares, and the filter belongs with the queue it cancels |

The three `DAMAGE_METER_*` handlers carry the `meterEvent` perf bracket. It measures the **fan-out**,
not the redraw: `SendMessage` walks every subscribed window's callback synchronously, which is the
cost that scales with window count at raid event rate. What a window then does on its own throttle
tick is the separate `refresh` bucket.

The player-state block exists for `modules/Visibility.lua`'s rules and carries **no payload**,
because those rules read their inputs live at the moment they are asked.

**These edges are load-bearing, not an optimisation.** There is no fallback poll: `onUpdate` in
`modules/Window.lua` refreshes *data* and never re-asks `NS.ShouldShow`, so the show ladder is
re-run only from a bus message a window subscribes to (`ROSTER_CHANGED`, `ZONE_CHANGED`,
`ENTERING_WORLD`, `COMBAT_CHANGED`, `PLAYER_STATE_CHANGED`, `TEST_MODE_CHANGED`, `CONFIG_CHANGED`).
A visibility input with no edge on the bus is a rule that never fires — which is exactly what
happened to `hideInVehicle`, shipped in 0.1.0 with no vehicle event registered, and to the first cut
of the player-state rules, which reached `Visibility` but not the window.

`PLAYER_IS_GLIDING_CHANGED` is **probed** through `C_EventUtils.IsEventValid` rather than registered
outright: it is the newest of the set and a client that has not got it raises on `RegisterEvent`.
Losing that one edge is survivable where losing the block is not — `PLAYER_CAN_GLIDE_CHANGED` still
fires when the mount changes, which is the transition the skyriding rule turns on.
`UNIT_ENTERED_VEHICLE` / `UNIT_EXITED_VEHICLE` fire for every unit, so `OnPlayerStateChanged`
filters those two to `"player"`; that check is a filter, not a decision.

**The filter is keyed on the event name, and must stay that way.** Only the vehicle pair carries a
unit token in `arg1`. `PLAYER_CAN_GLIDE_CHANGED` and `PLAYER_IS_GLIDING_CHANGED` carry a **boolean**
there (`canGlide` / `isGliding`); `PLAYER_MOUNT_DISPLAY_CHANGED` carries nothing. A filter that
tested `arg1 ~= "player"` for the whole block swallowed both skyriding edges while ground mounts kept
working — which read as "skyriding is broken" rather than as a filter bug.

**Every edge is answered twice**, immediately and again after `Constants.PLAYER_STATE_SETTLE` (0.5s).
Some client state lags its own event: `IsMounted()` has flipped by the time
`PLAYER_MOUNT_DISPLAY_CHANGED` arrives, `GetGlidingInfo`'s `canGlide` has not always done so. Read at
the edge alone, a lagging input answers with the state the player just left, and since a hidden
window has no `OnUpdate` running, that stale answer stands until the next zone change. One settle
pass is booked per burst, not per event — mounting fires several at once.

`ADDON_RESTRICTION_STATE_CHANGED` is registered even on a client without `C_RestrictedActions` — an
event that never fires costs nothing, and the alternative is a version check to keep in step with
`core/Secrets.lua`'s. `OnEnable` also **seeds** `NS.State.restricted` from `Secrets.IsRestricted()`,
because a `/reload` taken mid-pull re-enables the addon inside an already-active restriction and
there is no second edge to catch.

Everything else is a bus subscription. Registration by module is tabulated in
[module-map.md](module-map.md#what-each-file-publishes-and-consumes).

Perf buckets, declared in `core/PerfSetup.lua` with their nesting: `meterEvent` · `refresh`
(→ `providerRead`, `aggregate`, `render` → `renderRow`) · `tooltip`. A parent is never summed with
its children. Detail in [performance.md](performance.md) and
[perf-analysis/README.md](perf-analysis/README.md).

## Taint notes

**This is the constraint that shapes the whole addon.** Read it before changing anything on the data
path; the full trip is in [data-flow.md](data-flow.md).

`C_DamageMeter`'s session returns are `SecretWhenInCombat`. While the **`Combat`** addon restriction
is active, the numeric fields come back to tainted code — which is all of ours — as **secret values**.

| Tainted code MAY | Tainted code MAY NOT |
|---|---|
| store them in variables and in table **values** | do arithmetic on them |
| pass them to Lua functions and return them | compare them, or boolean-test them |
| concatenate with `..`, and `string.format` / `string.join` them | use them as table **keys** |
| pass them to `StatusBar:SetValue` / `SetMinMaxValues` and `FontString:SetText` | apply the `#` length operator |
| call `type()` on them, and test `== nil` | index them |
| call `NumericRuleFormatter:FormatNumber` on them | call `table.concat` with them |

Each forbidden operation raises **immediately**. The single exception the addon leans on is that a
**non-boolean** secret may still be tested for nil-ness, which is why `== nil` appears everywhere a
truth test would be natural — `value or 0` is a truth test and raises; `value == nil and 0 or value`
does not. `table.concat` is worth naming twice: it is the one string operation that raises on a
secret, which is exactly why LibKa0s uses it as the detection probe.

`classFilename`, `specIconID`, `isLocalPlayer` and `deathRecapID` are `NeverSecret` and always
readable — all four verified in-game under an active restriction. `name` is `ConditionalSecret`.

**`sourceGUID` is NOT.** The addon was built on the reading that a meter source GUID is never secret
and is therefore its only legal join key; in-game it comes back secret *and* inaccessible for the
whole of a pull, so the join has no key while the restriction is active. `isLocalPlayer` is what row
identity is rebuilt from — see Known limitations below.

**The unit API hands out secret GUIDs too**:
in a follower dungeon `UnitGUID("party3pet")` answers a secret string, and keying on one raises
`attempted to perform indexed assignment on a table that cannot be indexed with secret keys` on every
refresh tick. `modules/Roster.lua` — the addon's only reader of the unit API — therefore vets every
GUID through `NS.Secrets.IsSafeKey` before using it as a key, and vets the argument of `Get`,
`IsGroupMember` and `OwnerOf` the same way. An unreadable pet falls into the existing
"unattributable" case: no map entry, `OwnerOf` nil — and it then gets a row **of its own**, under its
own name, rather than being dropped (see [Known limitations](#known-limitations)).

Three design rules follow, and they are enforced in one place each rather than remembered in twenty:

- **R1 — `modules/Provider.lua` is the only caller of `C_DamageMeter`, and `core/Secrets.lua` is the
  only file that inspects a value.** Everything downstream treats a value as an opaque handle it may
  hand to a widget setter or the native formatter, and to nothing else. If a module needs to know
  something about a value — is it secret, may I sort these, how many entries does this array have —
  it asks `NS.Secrets`.
- **R2 — row order is never computed from values while comparison is illegal.** `orderByValue`
  proves comparability in a separate pass *before* `table.sort` is entered, because a comparator that
  discovers an illegal comparison halfway through has already raised.
- **R3 — layout is computed from config, never read back off a frame.** `SetValue(secret)` marks a
  frame `HasSecretValues`, which makes its position data secret and propagates that to anything
  anchored to it. There is not one `GetPoint` / `GetWidth` / `GetLeft` in `modules/Row.lua`; a window
  keeps drag and resize on a bare `inst.anchor` frame that never holds a value.

R3 also runs the other way: **a frame that is never handed a value keeps readable geometry**, so the
cheapest way to shrink the secret set is to stop handing values to frames that do not need them. The
name cell is the worked example — it used to take the sort column's figure purely to scale a bar
behind the player's name, and dropping that bar took the frame out of the secret set entirely. The
class color moved onto the name text, which is better anyway: `classFilename` is `NeverSecret`, so
the identity stays legible at the height of a pull when every number on the row is opaque.

The name cell is also where the addon's only **string inspection** lives. Stripping a realm
(`string.match`) and capping a length (`string.sub`) read the characters of a value, which R1 forbids
on a secret — so both are gated on the concat probe, and a `ConditionalSecret` name reaches the widget
untouched and uncapped. The cap counts UTF-8 characters rather than bytes; a byte slice can emit half
a code point, and accented names are exactly the ones most likely to need truncating.

**`tostring` is not on the permitted list, and that is why an export is a refusal rather than a
degradation.** A CSV cell is `tostring(value)` and a chat line splices a formatted number into a
sentence. `tostring` on a secret neither raises nor launders it: it answers a **secret string**,
which then poisons the `find` and the `gsub` that RFC-4180 quoting is made of, and the `table.concat`
that joins a row. Everywhere else in the addon a restricted value travels on as an opaque handle and
the display loses a bar or a percentage; there is no equivalent escape for a serializer, because a
serializer's whole job is to look at the characters of a value. A serializer that is subtly wrong
mid-pull is worse than one that says no.

So `modules/Export.lua` says no, at four points rather than one, because the restriction can activate
between any two of them: `Export.Available()` answers false, `/mm export` prints the sentence and
opens nothing, the modal refuses to open, and `Export.CSV` / `Export.ChatLines` refuse again at their
own first line for a caller that reached them anyway. Underneath all four, and independent of them,
every field passes `Secrets.CanAccess` on its way into a cell and yields `""` when it fails — so a
race between the check and the walk can produce a blank cell, and can never raise.

The other half of that file's discipline is what it does **not** do. An export wants every stat for
every player, which is exactly the loop `modules/Provider.lua` already writes — so writing it again
would put a second caller on `C_DamageMeter` and break R1. Instead `Export.SessionConfig` builds a
synthetic window config naming every catalogued stat, pointed at the invoking window's segment, and
hands it to `Aggregator.Build`. The aggregator neither knows nor cares that no frame will draw the
result, and the ranking a chat dump needs happens there, under the aggregator's own guards, rather
than in a sort of the exporter's own.

**Secrecy keys off `Combat`, not `ChallengeMode`.** Between packs in a key the values and the GUIDs
are fully readable, so the exact GUID join runs for most of a dungeon run and identity mode covers the
pulls themselves. `ADDON_RESTRICTION_STATE_CHANGED` fires with `state = Activating` **before**
enforcement begins and access is still permitted during that dispatch, which is why
`core/Secrets.lua` exposes the raw state and not just a boolean. `modules/Aggregator.lua` no longer
listens for that edge: it existed to take one last value-sort and freeze the result, and a frozen
`guid → position` map cannot be applied to rows that have no GUID.

Two consequences worth stating once, because both look like bugs: **percentage text slots go quiet in
combat** (a percentage is a division), and **a pet keeps its own row rather than being summed into its
owner's while restricted** (a sum is arithmetic, and the native formatter renders but does not sum).
The second is why the scoring feature is deferred — [scope.md](scope.md#deferred-scoring).

## The segment selector

The **segment control** in the header strip — the three horizontal lines — opens a context menu of
every session the client is still holding — name and duration, newest first as the API returns them — then a divider, then the
two synthetic entries `Current` and `Overall`. The menu anchors to the header's session line, which
is where it has always come out; that line used to be a 220px Button and opened the menu itself,
which put an invisible click target across the middle of the title bar and was removed.

The choice is stored in `window.data.sessionID`, which **overrides `sessionType` when set** and is
`nil` when no segment is pinned. It has no schema row: it is not a settings-panel control and its
unset state cannot be expressed as a default. It is persisted like any other key in `window.data`.

Threading it took one optional trailing argument rather than a new shape. `Provider.GetColumn`,
`GetSourceDetail` and `GetSessionDuration` each accept a trailing `sessionID`; nil routes to the
`…FromType` shim exactly as before, and a number routes to the `…FromID` shim. `modules/Provider.lua`
therefore remains the only caller of `C_DamageMeter`, and every existing call site was unchanged.
`Compat.GetCombatSessionFromID` and `Compat.GetAvailableCombatSessions` had shipped unused since v0.1.0
for precisely this.

Every read path honors the pin, and that matters more than it looks: a tooltip or a drill-down still
reading the live pull while the grid under it showed a fight from ten minutes ago would be describing
a different encounter than the row the cursor is on.

**Staleness is handled by forgetting, at the top of the refresh.** `WindowProto:DropStaleSegment`
asks `Provider.HasSession` and clears a pin the client no longer holds. A stale id does not raise —
it silently reads an empty session, which is indistinguishable from a broken addon. Session ids are
never reused, so nothing is lost by forgetting one. With no provider module at all the pin is left
alone: that is a broken install, not a stale segment, and rewriting the player's setting because of
our own load order would be the worse failure.

`Compat.OpenContextMenu` wraps `MenuUtil.CreateContextMenu` and is the only Blizzard menu API
wired. The pre-11.0 alternatives are deliberately absent — they do not exist on any client this
addon supports, and a fallback nobody can run is a fallback nobody has tested.

**It is no longer the only menu in the addon, and this control is deliberately the one that keeps
it.** The export modal's three selectors are `LibKa0s-Widgets-1.0` dropdowns — a flat-skinned button
that drops the library's own popup, shared process-wide with every other Ka0s addon's dropdowns.
This control is not converted: it is a mark in a header strip rather than a labelled selector in a
form, its list is built from live client state and carries a divider, and a dropdown button wide
enough to show a session name would take back the title bar the removed 220px Button already cost.
The two mechanisms coexist on purpose — see `modules/Export.lua`'s "The modal's three selectors"
comment, which argues the same split from the other side.

## Known limitations

- **`specIconID` does not arrive in a raid, so the identity key is class alone and a raid grid is 98%
  blank mid-pull.** With `sourceGUID` secret, every column but the sort one is joined by
  `classFilename .. specIconID .. isLocalPlayer` — except that in a 19-player raid `specIconID` is
  **absent** from every raw source row but the local player's, in combat *and* immediately after. It
  is not secret and not nil-under-restriction; it is not sent. **In a dungeon it arrives normally**
  and the key works as designed, which is how this survived to a raid. `identityKey` folds a missing
  icon to `0`, so every non-local key reads `CLASS_0_false` and two players of one **class** collide
  whatever their specs are. What separates the two cases is not established — see
  [#24](https://github.com/tusharsaxena/MultiMeters/issues/24).

  Measured with `/mm debug identity` in a 19-player raid, 2026-09-01: **8 distinct keys across 19
  rows, 18 of those rows wearing a collided key, 3 of 133 correlated cells filled (2%)**. `unmatched`
  was **0 in every column**, so the correlation is not failing to match — there is almost nothing
  left to tell two players apart with. The blanking itself is correct and does not change; a
  mislabeled number is a lie the player cannot see.

  The same capture killed the second direction: engine source order is **value-ranked per column and
  re-ranks between passes**, so a duplicate pair's seats differ between columns and between two
  captures of one pull. Positional pairing has nothing stable to rest on. The only plain field on the
  row outside the key is `classification`, whose usefulness is unmeasured.

  `specIconID`'s absence has a **second, visible consequence**, filed separately as
  [#24](https://github.com/tusharsaxena/MultiMeters/issues/24): `modules/Row.lua`'s spec-icon branch
  fires for the local player's row and no other, so every other row draws the class icon. The
  fallback hides the cause. Blizzard's own meter shows the same thing on the same pull, so the
  ceiling here may be the client's rather than ours.

  Tracked as [#22](https://github.com/tusharsaxena/MultiMeters/issues/22). Nothing is fixed yet.
  What shipped is the instrumentation, one ordering bug it exposed (a key proved ambiguous by a late
  column used to keep cells an early column had already written), and the absent-field report that
  found the cause — see [testing.md](testing.md#capturing-an-identity-correlation-run).
- **The feign-death filter cannot run mid-pull, and that is structural.** `C_DamageMeter` hands a
  Feign Death a valid `deathRecapID`, so the Deaths column counts a hunter's feign as a death.
  `modules/Feign.lua` records the GUID off the cast and `modules/Aggregator.lua` drops that source —
  but the join is a plain GUID against `sourceGUID`, and `sourceGUID` is secret for the whole of a
  pull. That is the entire reason the aggregator has a second, GUID-free identity build. There is no
  plain key on the other side of the join while the restriction is up, so **a feign is counted as a
  death mid-pull and the count corrects itself the moment combat ends.** Do not "fix" this by keying
  on something secret; there is nothing to key on.
- **The feign-death filter is reported to work for the local player and not for party members, and
  the cause is not yet measured** ([#25](https://github.com/tusharsaxena/MultiMeters/issues/25)).
  Two candidates fit the symptom equally well from the count alone, and they need opposite fixes:
  either `UNIT_SPELLCAST_SUCCEEDED(5384)` never arrives for a party unit token, so
  `modules/Feign.lua` is never told about the feign at all; or it does arrive and `Feign.Prune`
  evicts the entry before the Deaths walk judges the row, because a feign is presented to *other*
  clients as a death and the `hp <= 0` exit currently wins outright over `UnitIsFeignDeath`. Your own
  feign never collides with that — `UnitHealth("player")` stays at its real figure — which is exactly
  the asymmetry reported. **Nothing offline can tell the two apart:** `tests/wow_mock.lua` answers
  full health for any unrecorded token and every case in `tests/test_feign.lua` sets health on
  `"player"`. `/mm debug feign on` records all three boundaries a feign crosses — the cast, each
  prune verdict with the raw readings behind it, and the per-row `ShouldDropDeath` answer — and
  `/mm debug feign` prints them. The per-row answer is recorded **only for a GUID a cast line
  named**: it fires once per death in the column on every refresh, so admitting all of them filled
  the 120-entry ring with judgements on players who never feigned and evicted the one cast line the
  report exists to show. The refusals are counted and the total is printed, because a large refusal
  count beside an empty log is itself the finding — the refresh ran and never met the GUID.
  Fix on that measurement, not on either hypothesis.
- **A past death cannot be dated against the run it happened in, so the addon does not try.**
  Measured on a live client: the **Current** session held *zero* deaths, the **Overall** session held
  eighteen and reported `deathTimeSeconds = -1` for every one, and the session's own duration is
  *combat* time rather than wall time — 32 minutes of it spanning a run whose deaths were three hours
  back. A "time into the fight" timestamp style was built on three separate derivations of that
  figure and removed — see [#18](https://github.com/tusharsaxena/MultiMeters/issues/18), which
  carries the captures. `/mm debug recap`'s **dating** section is what proved each one could not
  work, and is kept for whoever tries again. Deaths are dated by wall clock or by "how long ago".
- **The death list is a snapshot taken on entry.** While a window is drilled into a player's deaths,
  `modules/Window.lua` renders `DrillDown:BuildRows` *instead of* running an aggregate pass, so there
  is no current row to re-read the deaths off. A player who dies again while somebody is looking at
  their list will not appear in it until the list is left and re-entered. Re-deriving it would cost a
  second aggregate pass per frame to keep fresh a list nobody is watching change.
- English (`enUS`) only. The locale plumbing and the metatable fallback exist; no second locale ships.
- Retail / Midnight only — a single `## Interface` line. `C_DamageMeter` does not exist on Classic.
- **Pet attribution is best-effort, but an unattributable ally is no longer lost.** Guardians,
  totems, temporary summons and any pet whose owner was never within unit-API range cannot be tied
  to an owner — the roster REMEMBERS every attribution it once made, so leaving the group does not
  lose one, but a guardian the unit API never saw was never attributable in the first place. Such a
  source now gets **its own row, under its own name**, rather than vanishing off the grid. That is
  not the mislabeling the drop rule guards against: the rule is about putting one player's numbers
  under another player's *name*, and this row claims no owner at all. The gate that keeps it safe is
  `sourceDisplayType`, and it never reads "not Enemy" as "one of ours" — read that loose way, a
  source whose display type is absent becomes a row and the whole trash pack lands on the grid.
- **A delve companion is admitted, because the client files one under `None`.** The gate above was
  `Ally` and nothing else until a live delve showed Valeera Sanguinar doing 24.98M of a run's 61.31M
  and never reaching the grid, while the header total counted her — a session total is the client's
  own sum and never consults the row gate. `display=0` is `None`: neither `Ally` nor `Enemy`. So a
  `None` source is now admitted **only when its `classFilename` is a class `RAID_CLASS_COLORS`
  recognizes**. That table is the oracle rather than a list of our own because `modules/Row.lua`
  already looks a row up in it to color the bar and pick the class icon — what this refuses could
  only ever have drawn as an uncolored, iconless row. A mob would have to report `None` *and* carry
  a genuine class filename to slip through, and `/mm debug diag` prints the enemy column's display
  types so that a `None` there is reported rather than inferred from a wrong row.
- **`data.mergePets` is off by default, and has no effect during a pull.** A pet gets its own row,
  which needs no arithmetic and is exact in both states. Merging is addition and needs the owner
  link, so it runs only where GUIDs are plain — out of combat.
- **The roster is sticky for the life of the meter's data.** Someone who left the group mid-run stays
  on the grid until the meter is reset. That is deliberate: the alternative — what shipped in
  v0.1.0 — was the window emptying itself the moment you left a dungeon, for a session that still
  held everyone's numbers.
- **Two players of the same class AND specialization cannot be told apart mid-pull.** `sourceGUID`
  is `SecretWhenInCombat`, so while the restriction is active the grid is built by identity
  correlation (`classFilename` + `specIconID` + `isLocalPlayer`) rather than by the GUID join, over
  the union of every column. Rows are correct — the sort column's are the engine's own ranking, and
  anyone it never mentioned is parked after them — but where two rows share an identity key, their
  **secondary columns are left empty** rather than filled from a source that might be the other
  player's, and an ambiguous key gets no row invented for it at all. The header says `restricted — some rows cannot be told apart`, and the
  full grid returns on the first refresh after combat.
- **Pets are separate rows for the whole of a pull, whatever `data.mergePets` says.** Folding needs
  the owner link, the owner link needs a GUID, and there is none while restricted.
- **Mid-pull the grid can be re-ranked and reversed, but not sorted.** Picking a different stat
  column and flipping the direction both reach the grid during a pull — neither compares anything,
  the first because identity mode builds its rows out of the chosen column's own `combatSources` and
  the second because reversing is a permutation. Ordering by **name** is still refused with a
  message: it compares a `ConditionalSecret` and has no engine ranking behind it. The sort arrow
  follows `applied` rather than the request, so it never marks a column the rows are not in.
- **The provider-order assumption is measured, not proven.** The engine's ranking is what identity
  mode calls "the order", and nothing in Blizzard's documentation says `combatSources` arrives
  ranked. `/mm debug diag`'s **provider order** section checks it out of combat, where comparison is
  legal, and refuses inside a pull rather than reporting an all-clear it did not earn.
- **Percentage text slots render empty in combat.** By design; the slots default to total and rate.
- **Exporting is unavailable for the whole of a pull.** Both halves — the CSV and the chat dump —
  refuse while the Combat restriction is active, and say so in a sentence rather than producing a
  file of `<secret>`. The reason is `tostring`, which is not a permitted operation on a secret; the
  full argument is in [Taint notes](#taint-notes).
- **An export is capped at 40 rows**, inherited from `Constants.MAX_ROWS` by way of
  `Aggregator.ApplyRowLimit`. A 40-player raid exports whole; a larger group is truncated at the
  aggregator's own ceiling. Stated rather than worked around: raising it means raising the cap every
  window draws against, which is a display decision and not an export one.
- **An export carries the segment's ranking, not the invoking window's view.** It names every stat in
  the catalog, not the window's enabled columns, and it ignores the window's row cap and sort — what
  is on screen is a display choice, and "export this" means the data behind it. Only the *segment* is
  inherited, because "export this" said while looking at last pull means last pull.
- **The export copy window is the third copy-paste window in the collection**, after
  `LibKa0s/DebugLog.lua`'s and `LootHistory/modules/Export.lua`'s. It is a deliberate local copy
  rather than an oversight — the three want to evolve apart — but the shape is stable enough to
  harvest, and the destination is `lib.MakeCopyWindow(name, title)` in LibKa0s Core. Recorded here
  rather than in the deviations register below, because that register is for departures from a
  numbered rule of the standard and this is a library-harvest candidate: no rule is being departed
  from. Filed as a limitation so the issue sweep picks it up as a follow-up.
- **The tooltip's Targets section is absent for the whole of a pull, not degraded.** It is the one
  place in the addon where restriction costs *information* rather than decoration, and it is
  deliberate, and there are now **two independent reasons**, either of which is sufficient:

  1. *The enemy cannot be identified.* Both identifiers the API accepts are secret in a pull —
     `sourceGUID` is `SecretWhenInCombat`, and `sourceCreatureID` turns out to be too. Passing a
     secret `sourceCreatureID` does not merely fail to resolve, it **raises**
     (`bad argument #4 … Secret values are only allowed during untainted execution`), and because
     `Targets.ForPlayer` runs on the tooltip's render path that raise took *every cell tooltip* down
     for the whole pull, not just this section. `modules/Targets.lua` now gates both identifiers
     through `NS.Secrets.IsSafeKey` and abandons the build when neither survives — calling with both
     nil does not fail, it answers for a **different source**, whose numbers would be summed in as
     though they were this enemy's.
  2. *The sum is illegal.* One enemy's damage from one player does not exist in the API; it is a
     **sum** over that enemy's matching spells, and a sum of secrets raises. Summing only the
     readable rows would show a number that is wrong, plausible and invisibly low, so the build is
     refused entire on the first unreadable amount.

  It is also off by default and Damage-column only, because it costs one provider call per enemy on
  the first hover of a session. See [data-flow.md §9](data-flow.md).
- **`provider` sort mode rests on an unverified assumption** — that `combatSources` arrives sorted by
  the requested statistic. Isolated in `modules/Provider.lua`; `value` and `roster` do not depend on
  it.
- **Scoring is deferred**, and cannot be computed in combat at all. See
  [scope.md](scope.md#deferred-scoring).
- **No in-window column drag editor** — settings-panel only, and structurally so (rule R3).
- **Scrolling is the mouse wheel only — there is no scrollbar.** A window draws `layout.maxRows`
  rows chosen out of a longer list, so scrolling moves an integer offset rather than a scroll child;
  there is no widget to size and nothing measured. The cost is that a player cannot see there are
  rows above or below without trying the wheel.
- Debug logging is session-only (`NS.State.debug`) and resets on every `/reload`.
- **A refresh pass logs on change, not on every pass.** The `[Aggregator]` and `[Render]` summary
  lines go through `NS.DebugSteady`, which emits a change immediately and otherwise re-announces an
  unchanged run at most every 10 seconds as `… (xN)`. It is what keeps a 1500-line buffer holding
  hours rather than two minutes. Ratified as a deviation from debug-logging §8 — see the register
  below. Note the console's **Clear** button does not reset the comparison (the library offers the
  host no hook), so a freshly cleared console can sit silent until the next change or heartbeat.
- No automated in-client tests: headless suites plus manual in-game smoke tests.
- Not published — `X-Curse-Project-ID` and `X-Wago-ID` are deliberately absent from the TOC.

**The tooltip is the one thing this addon positions itself.** Everything else is laid out from config
and never anchored to a frame that has held a meter value (rule R3) — but the eight tooltip anchors
name boxes of a 3×3 around the hovered cell, and Blizzard's `SetOwner` tokens cannot express the four
diagonals at all. So `modules/Tooltip.lua` calls `SetOwner` with the closest token first and then lays
a `SetPoint` over it. That `SetPoint` anchors GameTooltip to a cell with secret geometry, which is
the one call in the addon that could raise inside Blizzard's own code while tainted by us. It is
`pcall`'d, and a failure leaves the token's placement standing: the tooltip opens in roughly the
right place rather than not at all.

## Documentation map

Every `.md` under `docs/` appears in exactly one of the three tables below (`documentation-§3`).
**A store gets one row; its dated bundles get none.** `docs/automated-tests/` and
`docs/perf-analysis/` register their two live docs — the README that says how a bundle is produced
and, for the automated-test record, the `RESULTS.md` the runner rewrites — and nothing else under
them; the dated folders beside those files are frozen evidence, and evidence is not registered.
`docs/revendor/` and `docs/superpowers/` are frozen through and through and get one row apiece.

`docs/issues/` used to hold image evidence attached to GitHub issues — GitHub's API has no supported
path for uploading an issue attachment, so a raw link to a committed file is the only way a
screenshot reaches one. **The directory is gone.** An issue's images are deleted when it closes and
its links are re-pointed at the commit that last carried them, which keeps resolving forever without
the repo carrying the weight; issue #1's are pinned to `dcb29ad`. Re-create it only when an open
issue needs a picture, and expect it to empty itself again.

### Canonical trio (Tier 1)

| Doc | Covers |
|---|---|
| `ARCHITECTURE.md` | This file — the hub: overview, module map, schema, bus, slash, events, taint, limitations, this register, deviations |
| `testing.md` | How to run the harness and lint; the green commit gate |
| `smoke-tests.md` | The in-game smoke-test suite |

### Verification and record

| Doc | Covers |
|---|---|
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page: buckets, offline scenarios, the in-game A/B |
| `perf-analysis/README.md` | What a recorded in-game capture bundle is and how to produce it |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated, never hand-edited |

### Topic detail

| Doc | Covers |
|---|---|
| `scope.md` | What the addon does and deliberately does not, including why scoring cannot be computed in combat |
| `module-map.md` | Every non-vendored file, its responsibility, TOC load order, the AceAddon lifecycle |
| `schema.md` | The persisted shape, every default, and the migration seam |
| `settings-panel.md` | The nine pages, per-option behavior, and the write seam |
| `data-flow.md` | `C_DamageMeter` → pixel, and the secret-value rules that shape every hop |
| `common-tasks.md` | Recipes for the changes made most often here |
| `superpowers/` | Tier 3 planning history, frozen — the approved design specs and build plans behind each feature, under `specs/` and `plans/`, dated and never revised after the fact |
| `revendor/` | Frozen — one dated bundle per LibKa0s re-vendor: the payload delta and what was adopted, declined or filed from it |

### Tier 2 conditional docs — evaluated at v0.1.0

Each trigger was measured against the source, not assumed. **None of the six ships today**, and the
measurements that decided that are recorded here so a later audit can re-run them rather than
re-argue them — one of them, `compat-layer.md`, is now flagged as having crossed its own line. This
is an evaluation record, not a fourth register table — every doc below that *does* exist is
registered above.

| Doc | Status | Trigger, as measured |
|---|---|---|
| `slash-dispatch.md` | Not applicable | **16 verbs in `NS.COMMANDS`.** Ten are the standard's reserved set, implemented entirely by LibKa0s-Slash-1.0 and documented by the standard. This addon's own surface is 6 verbs and one 4-entry sub-verb tree (`window`: list/new/delete/copy); `debug` takes 4 words, `perf` delegates its whole sub-surface to the library, and `export` takes one optional window name. The [Slash commands](#slash-commands) section carries all of it in a screen. |
| `message-bus.md` | Not applicable | **14 distinct messages**, all declared in one catalog (`core/Constants.lua` `MSG`) with the owning sender named beside each. Every payload is a flat table of one to two plain fields; none carries a handle, a curve object or a per-unit filter needing prose. The [Message bus](#message-bus) section carries sender, consumers and payload for all fourteen in one table. |
| `compat-layer.md` | **Re-measure — the trigger now fires** | **`core/Compat.lua` is 761 lines and 28 shims** (8 of them `C_DamageMeter`, 4 death-recap, plus the recap-namespace probe `RecapMembers` / `RecapAPIs` / `CallRecap`), each still a guarded namespace check around one passthrough, with no feature decisions and no state, and nothing there inspects a meter value. But the comparison point — KickCD's 490-line Compat, which ships the doc — has been passed by half again. It was 389 lines and 18 shims when this row was last measured. Raise the doc, or re-argue the trigger, through `/wow-addon:standards-audit`; it is not this register's call to make. |
| `midnight-quirks.md` (secret values) | Not applicable | The 12.0 secret-value model is this addon's **defining** constraint, not a quirk beside its main subject — so it is carried by [Taint notes](#taint-notes) (the operation lists, R1/R3, the `Combat`-not-`ChallengeMode` fact) and by [data-flow.md](data-flow.md), which is Tier 1 and mandatory here regardless. A third copy would be the one that drifts. |
| `profiles.md` | Not applicable | `settings/Profiles.lua` is 126 lines hosting **AceDBOptions-3.0's own tree** unchanged. The addon adds no profile semantics beyond the `PROFILE_CHANGED` fan-out already tabulated above and the reset-all veto already stated under [Settings schema](#settings-schema); the persisted shape is [schema.md](schema.md)'s. |
| `debug.md` | Not applicable | The console is `LibKa0s-DebugLog-1.0`'s window. `/mm debug` toggles it and takes `on` / `off`. This addon's own surface is `/mm debug diag`, `/mm debug recap` and `/mm debug identity` — `core/Diagnostics.lua`, ~1570 lines of print statements whose header explains itself, with no state and no options for a doc to describe. It has grown — the death-recap probe for issue #1 is the newest section, the first with a verb of its own, and the first to search the client two ways because one was measured to be unreliable — so this is the Tier 2 trigger nearest to firing; re-measure it when a section gains state or an option. |

## Documented deviations

The **single home** for a ratified deviation from the Ka0s WoW Addon Standard. A deviation not in this
table is not ratified: an audit that cannot find the decision here re-files it as an open MUST
failure, and the same argument gets had every cycle. The reasoning may live at length in the topic doc
named in **Why**; the row is what makes it a decision rather than a note.

**Re-check trigger** is the condition that *ends* the deviation, written so a reader can tell whether
it has already fired. A row without one is a permanent opt-out wearing a table's clothes. When a cited
rule changes so that the behavior becomes mandated or permitted outright, the row is **retired** —
this table must not become a graveyard.

Rows are shaped `| Rule | What differs | Why | Decided | Re-check trigger |`.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| debug-logging §8 — each recompute logged "as a single summary line" | A refresh pass whose summary line is **unchanged** from the previous pass is not logged. The line is emitted on every *change*, plus a heartbeat at most every 10s carrying `(xN)` for the passes it stood for. | `throttle = 0.25` is four passes a second, each emitting an `[Aggregator]` and a `[Render]` line (three while restricted) into a buffer capped at 500 lines (§1) — **the console holds 40 seconds**. (Measured 2026-08-21 against the cap of the day; LibKa0s v1.15.0 raised it to 1500, which buys two minutes rather than forty seconds and evicts the console just the same.) A live capture showed one identity line repeating byte-identically for 41 seconds: ~160 passes, ~480 lines, one string, evicting every other line in the buffer. That is the harm §9 names ("it **evicts** it") arriving by a route §9 does not cover: §9 bounds *per-item* emission and says nothing about a pass repeating unchanged on a timer. A change is never delayed and never dropped, so nothing a reader wants is what goes missing. Implementation and reasoning: `core/DebugLogSetup.lua` → the steady-state sink. | 2026-08-21 | debug-logging gains a rule for repeating timer-driven passes — the gap is general to any Ka0s addon with a refresh timer, so the standard is the right long-term home and this row retires the day it lands. |
| options-ui §17 — every colour picker carries a "use class colour" companion | `window.header.bgColor` — the title bar's own background — ships with **no** companion. Every other non-palette swatch in the addon has one. | Neither answer a companion could give is true of this surface. The title bar is **one strip spanning the whole window**, so "per statistic" could only ever mean the sort column's colour — a fact already on screen twice, in that column's own header and in its arrow — and that is the same argument that took the mode off the title bar's *text* background and off the divider's `stat` option. The strip beside it, the column-header background, **does** keep a mode, and the difference is the point: that one labels the columns, so per-statistic tints each label with its own column's colour and means something (`settings/Schema.lua`, the note above `window.columnHeader.bgColorMode`). A companion added here would be a control wired to a colour nobody chose. | 2026-09-02 | The title bar grows a surface that belongs to one column or to one player — a per-row header, a sort-column tint on the strip itself — at which point "which class" and "which statistic" both have an answer and the row retires. |
| options-ui §17 — "one resolver": the class-colour lookup is the library's | `NS.ClassRGB(classFilename)` (`core/Namespace.lua`) stays as a **second** reader of `RAID_CLASS_COLORS`, beside the library's `NS.ClassColor(unit)`. | The two answer different questions. `LibKa0s-Core-1.0`'s `ClassColor` takes a **unit token**; a meter row is a GUID and a `classFilename` out of `C_DamageMeter`, and most rows have no token at all — a player who left the group, an NPC in a damage-taken column, a follower-dungeon companion. Retiring `ClassRGB` in favour of the unit-keyed lookup would silently uncolour every one of them. The **surface** question — the window's chrome, its header, its backdrop and its border — does go through the library, via `NS.PlayerClassRGB`, which is the case the standard's clause is about; what stays private is the roster reader. Neither has a fallback the other lacks: the degraded reader in `core/CoreSetup.lua` calls `ClassRGB` too, so there is still exactly one table lookup in the addon. | 2026-09-02 | `LibKa0s-Core-1.0` grows a class-**filename** overload of `ClassColor` (or a sibling reader), at which point `ClassRGB` becomes the private copy the clause forbids and is deleted. |
| options-ui §15, §16 — the canonical blocks are composed by the library | With `libs/LibKa0s` **absent**, the composed rows are absent from `NS.Schema` too: the Master controls tab and every font, border and bar group simply are not declared. A degraded install's schema is the hand-written half. | The alternative is a hand-written copy of each block standing behind the composer, which is precisely anti-pattern #73 and precisely the drift the composers were extracted to end — and it would be a copy nobody exercises, so it would go stale first. The cost is **nothing a player can reach**: a degraded install has no settings panel (`settings/OptionsSetup.lua` stubs it) and no schema CLI (`settings/Slash.lua` refuses `get`/`set`/`list`/`reset`/`resetall` by name), so those rows have no reader left; every stored setting still merges from `defaults/Profile.lua` and every window still draws with the player's values. `settings/Schema.lua` stamps each composed row `composed`, and `tests/test_degraded.lua` asserts the difference is exactly that set and nothing else — so a page file that raised at load is still a named failure. | 2026-09-02 | The composers move somewhere a host can reach without the library, or LibKa0s stops being an optional dependency (`DEPENDENCIES.md`), at which point the degradation branch and this row both go. |
| layout §1 — no authored `.lua` over 1500 lines, `tests/` included | The **seven suites that mirror an over-cap module** — `tests/test_window.lua` (2737), `test_tooltip.lua` (2708), `test_row.lua` (1606), `test_aggregator.lua` (1605), `test_schema.lua` (1573), `test_diagnostics.lua` (1557), `test_export.lua` (1509) — stay over the cap and are **not** peeled on their own. The other eight breaches are not covered here: each has an open issue naming its seam (#27–#34). | **A mirror suite has no seam of its own.** Its partition is whatever partition its module ends up peeled on, and the two files already track each other closely enough that several banners are byte-identical — `modules/Window.lua:258` and `tests/test_window.lua:242` are both *Layout — rule R3 in one function*, `Window.lua:1997` and `test_window.lua:1208` both *Sorting from the column headers*, `modules/Row.lua:1119` and `test_row.lua:816` both *The name cell*, `core/Diagnostics.lua:1295` and `test_diagnostics.lua:343` both *The provider-order probe*. Peeling the suite first commits to a partition the module has not chosen yet; when the module later picks a different one, the result is two files that no longer pair, and `testing-§1`'s one-suite-per-module layout is what makes a red legible — you read the failing case name and you know which file to open. So the peel is real and it is scheduled: it happens in the module's own commit, on the module's own seam, which is also the only commit in which the moved cases can be re-pointed without guessing. Nothing here disputes that the cap binds test files — `layout-§1` is explicit that it does, and this addon is the repository whose 2026-09-07 audit filed against seven source files and none of its seven test files, which is the reading the standard was revised to end. | 2026-09-08 | The mirrored module is peeled, or its issue (#27–#33) reaches a terminal state — the suite peels along the same seam, in the same commit. A suite whose module drops under the cap without a peel loses its partner and peels on its own evidence instead. |
| library-stack §8 — "where the addon needs a mark it MUST use the catalog's" | `settings/ColumnBlocks.lua:60-61`'s column-block enable/disable glyph stays on Blizzard's `ReadyCheck-Ready` / `ReadyCheck-NotReady` pair, although `LibKa0s-Media-1.0` **does** carry `circle-check` and `ban`. This is the one site in the addon where the catalog has the mark and the addon declines it. | **Three reasons, and only the third is the one that binds.** (1) *Colour.* The catalog's art ships white with its shape in the alpha channel, because the collection tints by multiplying — so `circle-check` and `ban` would both draw white, and enabled-vs-disabled would be carried by shape alone where the pair on screen today carries it in green and red as well. Reconstructing that means a vertex colour per state, which is a second vocabulary for one signal rather than one fewer. (2) *Degradation.* `NS.Icon` answers **nil** on a load without the payload (`core/MediaSetup.lua`), and this glyph has no ladder beneath it the way `modules/HeaderControls.lua`'s art does — the block would lose its tick outright, where a Blizzard path is part of the client and cannot go missing. (3) *Parity, which is why the line exists at all.* These are the same two textures ConsumableMaster's priority list wears (`settings/StatPriority.lua:108-109`, with `modules/KCMItemRow.lua:28-29` and `settings/Category.lua:82-83` beside it), so a player running both reads one glyph vocabulary rather than two. Moving one addon alone does not reduce the deviation; it converts a shared vocabulary into a split one, which is strictly worse than the state being ratified here. The 2026-09-07 remediation plan reaches the same conclusion in as many words — the two sites "move in both repositories together or in neither", and filing the row in both is the other half of the same choice. This repository can only file its half. | 2026-09-08 | ConsumableMaster's three sites adopt the catalog, or its priority list is retired — at which point the parity argument has no second half and this pair moves in the same cycle it does. Reasons (1) and (2) are answered upstream instead and each retires this row on its own: a `LibKa0s-Media-1.0` that publishes a tinted state pair, or an `NS.Icon` contract that carries a Blizzard fallback. |

**One row is ratified.** The register also carried a row for the drag-to-reorder block list living
in `settings/ColumnBlocks.lua` rather than in LibKa0s, adopted because a library widget re-vendors
into every addon in the collection and one consumer is not enough evidence to freeze a signature on.
That row was retired on 2026-08-27, on precisely the re-check trigger it was written with:
ConsumableMaster's priority list wanted the same gesture, the second consumer arrived, and the
widget moved to `LibKa0s-Widgets-1.0` as `ReorderList` at minor 8 ([issue
#21](https://github.com/tusharsaxena/MultiMeters/issues/21)). What moved was the gesture alone — the
handle, the carried copy, the insertion line, the clamp; the row itself stayed here, because the two
adopting lists draw nothing alike.

**One row is ratified.** The register also carried a row for a root `TODO.md`
holding work that was decided but unscheduled, adopted as a stopgap until the repo had an issue store.
That row was retired on 2026-08-11 when the backlog moved to
[GitHub issues](https://github.com/tusharsaxena/MultiMeters/issues), which is precisely the re-check
trigger it was written with.

Rows above are ratified. The paragraph below is why the section is never *removed* even when it is
empty: an audit needs to be able to tell "nothing has been ratified" from "the register was never
written".

Three things read like deviations and are not, recorded here so the same question is not re-opened:

- **`NS.Format` is a callable table.** `core/CoreSetup.lua` publishes LibKa0s's chat printer under
  that name and the design brief names the same field for the number formatter.
  `modules/Format.lua` resolves the collision in one place rather than renaming either contract, and
  publishes `NS.Numbers` / `NS.NumberFormat` as unambiguous aliases. That is a naming decision inside
  this addon, not a departure from a numbered rule.
- **`modules/Roster.lua` does not send `ROSTER_CHANGED`.** The build brief made it the sender; it
  cannot be, because `core/MultiMeters.lua` is the single game-event listener and already owns
  `GROUP_ROSTER_UPDATE`. The direction is inverted and the module subscribes instead. The message
  still has exactly one sender — which is what the rule asks for.
- **`METER_RESET` has two dispatch sites.** Both are inside the one-sender contract's intent: the
  game's event and the addon's own `Provider.Reset`, which must announce even if the event never
  arrives. Every handler is idempotent. Reasoned in `modules/Provider.lua`.

### Files over the 1500-line cap

`layout-§1` caps every **authored** `.lua` this repository tracks at 1500 lines — `tests/` included,
with vendored code (`libs/`, `tests/_kit/`) the only carve-out that reaches anything here; nothing in
this repo is generated non-shipping data, so the second carve-out has no instance. It gives a file
over the cap three terminal states: peeled, an open issue naming the seam a peel would follow, or a
ratified row in the register above carrying a re-check trigger. What it does not allow is a breach
nothing anywhere remarks on — "the count sitting in a bundle manifest that no document reads". This
table is the remark, and it is why an audit **MUST NOT** re-file `layout-§1` against any file in it.

Fifteen files, measured 2026-09-08 with

```
git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn
```

| File | Lines (2026-09-08) | Disposition |
|---|---|---|
| `settings/Schema.lua` | 3080 | Issue [#27](https://github.com/tusharsaxena/MultiMeters/issues/27) — the schema array out of the path machinery |
| `tests/test_window.lua` | 2737 | Register row above — peels with `modules/Window.lua` ([#29](https://github.com/tusharsaxena/MultiMeters/issues/29)) |
| `tests/test_tooltip.lua` | 2708 | Register row above — peels with `modules/Tooltip.lua` ([#28](https://github.com/tusharsaxena/MultiMeters/issues/28)) |
| `modules/Tooltip.lua` | 2652 | Issue [#28](https://github.com/tusharsaxena/MultiMeters/issues/28) — the four tooltip builders out from under the secret-safe primitives |
| `modules/Window.lua` | 2644 | Issue [#29](https://github.com/tusharsaxena/MultiMeters/issues/29) — header art, sorting and the segment selector out of the refresh chain |
| `tests/wow_mock.lua` | 2266 | Issue [#34](https://github.com/tusharsaxena/MultiMeters/issues/34) — the secret simulator and the frame model out to siblings |
| `modules/Aggregator.lua` | 2083 | Issue [#30](https://github.com/tusharsaxena/MultiMeters/issues/30) — identity mode and the correlation rectangle out of the build pipeline |
| `core/Diagnostics.lua` | 1824 | Issue [#31](https://github.com/tusharsaxena/MultiMeters/issues/31) — one file per long-lived probe |
| `modules/Export.lua` | 1743 | Issue [#32](https://github.com/tusharsaxena/MultiMeters/issues/32) — the pure serializer from the modal, the split its own `:50` banner already names |
| `modules/Row.lua` | 1702 | Issue [#33](https://github.com/tusharsaxena/MultiMeters/issues/33) — the name cell out to its own file |
| `tests/test_row.lua` | 1606 | Register row above — peels with `modules/Row.lua` ([#33](https://github.com/tusharsaxena/MultiMeters/issues/33)) |
| `tests/test_aggregator.lua` | 1605 | Register row above — peels with `modules/Aggregator.lua` ([#30](https://github.com/tusharsaxena/MultiMeters/issues/30)) |
| `tests/test_schema.lua` | 1573 | Register row above — peels with `settings/Schema.lua` ([#27](https://github.com/tusharsaxena/MultiMeters/issues/27)) |
| `tests/test_diagnostics.lua` | 1557 | Register row above — peels with `core/Diagnostics.lua` ([#31](https://github.com/tusharsaxena/MultiMeters/issues/31)) |
| `tests/test_export.lua` | 1509 | Register row above — peels with `modules/Export.lua` ([#32](https://github.com/tusharsaxena/MultiMeters/issues/32)) |

**The line counts are dated because they drift, and nothing asserts them.** What
`tests/test_layout_cap.lua` asserts is the *membership* of this table, in both directions: a file that
crosses 1500 and is not listed here turns the suite red, and so does a row for a file that has fallen
back under the cap or been deleted. A figure in this column is a measurement, not a claim about today.

**Nothing here is peeled this cycle.** The 2026-09-07 remediation plan rules out splitting any file
(`03_SPEC.md` § C22 non-goals): the seven source files are the largest mechanical churn available in
this repository, they have no player-visible payoff, and they collide head-on with the feign-death and
identity work landing in `modules/` and `core/` at the same time. The deliverable was the disposition,
and the disposition is this table.

**The 1000–1500 band is on notice, not in breach**: `tests/test_provider.lua` (1359) and
`tests/test_database.lua` (1004) are the only two files in it. They are named here so a later reader
can tell that the band was looked at rather than missed; neither needs a disposition until it crosses.

### Hard-coded texture paths

`library-stack-§8` makes the shared catalog the addon's **vocabulary for marks**: where the addon
needs one it uses `LibKa0s-Media-1.0`'s, ships no private copy, and draws no local substitute. The
2026-09-07 collection review found the rule bypassed across all nine addons and could not say by how
much — three passes produced three different figures, and the one that was believed was believed
because it was the biggest, not because anyone could reproduce it. So the number below arrives with
the command that produced it and the scope that command runs over, and this table is what an audit
reads instead of measuring again.

**Fifteen lines carrying fifteen paths, twelve distinct file/path pairs, measured 2026-09-08** over
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
`core/Compat.lua:624` and `modules/Window.lua:92` both quote `UI-SortArrow-Up` while explaining that
it does not exist, `core/MediaSetup.lua:27` names the `Interface\AddOns\` prefix in the argument for
taking the folder name from the vararg, and `core/Namespace.lua:137` does the same. A comment naming
a texture is not a texture, so they are named here rather than given rows — and naming them is what
makes the subtraction from 19 checkable by a reader who runs the looser form.

| File | Path | Disposition |
|---|---|---|
| `core/Constants.lua` | `Interface\AddOns\MultiMeters\media\logos\multimeters.logo.tga` | The addon's **own shipped art**, which no icon catalog is meant to replace (`layout-§3`). The reasoning above the line is about the extension, not the hard-coding: `.tga` is the only form the client loads, and the `.png` master beside it is packaging. |
| `modules/Export.lua` | `Interface\Buttons\WHITE8x8` | The flat 1px fill `standalone-windows-§1` **mandates** for the shared window edge — a client primitive, not a mark, so outside what the catalog answers for. `LibKa0s/Core.lua:91,94` reaches for the same file for the same reason. Two sites, one path. |
| `modules/Minimap.lua` | `Interface\Icons\achievement_challengemode_gold` | **Pinned to the TOC.** `MultiMeters.toc:6`'s `## IconTexture` names this exact path, so the launcher and the AddOns-list entry are the same addon on sight; a catalog mark here would make them two. `library-stack-§8` sends a mark the catalog lacks **upstream** rather than into an addon, and there is nothing to send: the set is white-in-alpha by rule and this is the client's own colour art. |
| `modules/Row.lua` | `Interface\TargetingFrame\UI-Classes-Circles` | The client's **class atlas**, cropped by coordinate. The catalog carries no class art and `library-stack-§8` sends a missing mark upstream rather than into an addon — but twelve class circles are Blizzard's own data, not a Ka0s glyph, and they change when the game's classes do. |
| `modules/Row.lua` | `Interface\TargetingFrame\UI-StatusBar` | Last-resort bar fill after an LSM fetch answers nothing. The catalog **does** ship bar textures (`library-stack-§8`), and they reach LSM through `core/MediaSetup.lua`'s `RegisterLSM` — so the only load that reaches this line is one where the payload is absent and `NS.MediaTexture` answers nil too. A fallback that needs the thing that is missing is not a fallback. |
| `modules/Tooltip.lua` | `Interface\ICONS\INV_Misc_QuestionMark` | The client's canonical unknown-item mark, standing in for a spellID it cannot resolve. `library-stack-§8` has no equivalent and could not sensibly grow one: the whole point of this texture is that every WoW player already reads it as "missing", which is a meaning the client owns and a Ka0s glyph cannot borrow. |
| `modules/Tooltip.lua` | `Interface\ICONS\Ability_Hunter_FocusedAim` | The icon every TARGET line wears, and the second site where the catalog **does** have a candidate — `target`. A considered decline, not an oversight: this slot sits in a column of coloured Blizzard spell icons, and `library-stack-§8` requires catalog art to be white with its shape in the alpha channel, so the one line drawing a Ka0s glyph would be the one line that looked foreign. |
| `modules/Tooltip.lua` | `Interface\Buttons\WHITE8X8` | The fill `standalone-windows-§1` mandates, here as the bar fallback for a window with no texture configured — a `StatusBar` with no texture draws nothing, so a tint alone is not a fallback. The casing differs from the `modules/Export.lua` row and from nothing else; `LibKa0s` spells it both ways too (`Core.lua:91` / `Widgets.lua:44`), WoW paths are case-insensitive, and it is recorded here so nobody spends a commit "fixing" it. |
| `modules/Window.lua` | `Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up` | The corner resize grip. `library-stack-§8`'s catalog carries `resize`, but it is a **glyph** — one state, one colour; this is a two-state pair (`-Up` and the `-Highlight` below) that a player already reads in every chat window. The 2026-09-07 plan names the chat size-grabber among the chrome the catalog has no equivalent for. |
| `modules/Window.lua` | `Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight` | The hover half of the pair above. The second state is what makes it chrome rather than a mark: `library-stack-§8`'s catalog publishes no hover variant of anything, so adopting it would mean drawing one locally, which is the thing the rule forbids. |
| `settings/ColumnBlocks.lua` | `Interface\RaidFrame\ReadyCheck-Ready` | **Register row above** — `library-stack §8`, ratified 2026-09-08 on parity with ConsumableMaster's priority list. The one site here where the catalog has the mark. |
| `settings/ColumnBlocks.lua` | `Interface\RaidFrame\ReadyCheck-NotReady` | **Register row above** — the other half of the same pair and the same row. |

**The paths are the invariant, not the count.** `tests/test_texture_paths.lua` reads the tracked set
and this table and compares them in both directions: a file that grows a hard-coded path nobody
listed turns the suite red, and so does a row for a path that has gone. It pins the distinct
file/path pair rather than a line number or an occurrence count, because those move on every ordinary
edit while the arrival of a *new* path is the only event this rule has an opinion about. It also
asserts that the two `ColumnBlocks.lua` rows have a `library-stack §8` row to point at, so "register
row above" stays a reference rather than becoming a phrase.

## Complexity register

`performance-§10` makes the complexity report a **report** — it says in as many words that a commit
MUST NOT be gated on it — and then asks the one thing that turns a page of numbers into a decision
record: every function `lizard` warns on carries a **one-line disposition**. `automated-tests-§3`
gates the **tag** on the same figure, zero functions above CCN 15, evaluated by
`/wow-addon:bump-version` from a release run's `manifest.json`. This addon has **23** functions above
15, which is why it has never cut a tag, and why the blanket answer — "accept them all, they are all
`and`/`or` defaulting" — is the failure anti-pattern **#53** describes: a list where everything is
accepted is an inventory, and an inventory cannot tell you when something alarming arrives.

**Measured 2026-09-08 at `80f8c9e`**, with the invocation `performance-§10` fixes and which this
table may never vary from:

```
lizard -l lua -x './libs/*' -x './tests/_kit/*' .
```

Twenty-three warnings, all in shipped source — `core/` **5**, `modules/` **16**, `settings/` **2**.
(The remediation plan's row for this work says 15 and 3. It is wrong in both cells, the total is
right, and it was already wrong when it was written — measured at `02aff8c`, before the cycle
opened, the same split reads 5 / 16 / 2. `settings/Schema.lua` has no warned function in it and
never had one.)

**Read `lizard`'s Function column before you go looking for the function.** Its Lua parser names
nine of these twenty-three entries in ways that will not lead a reader to the code, in three
different ways:

- **A method is reported under its receiver.** `Cell@646-726` is `Cell:ApplyBorder`,
  `Cell@1155-1231` is `Cell:ApplyIcons`, `WindowProto@312-413` is `WindowProto:BuildLayout`,
  `Tooltip@2335-2397` is `Tooltip:CellTooltip`, `DrillDown@395-428` is `DrillDown:OnCellClick`.
- **A `t[k] = function` assignment is reported as `]`.** All three `core/Database.lua` entries are
  migration steps: `migrations[1]`, `migrations[4]`, `migrations[12]`.
- **`(anonymous)@1961-2032` is not anonymous and does not start at 1961.** The parser opens the entry
  at the `function(_, event)` handed to `Secrets.SafeIterate` and closes it at the `end` of the
  enclosing function, so callback and host are reported as one row under the callback's name and with
  the callback's parameter count. The function is `drawDeathEvents@1950-2032`, and it appears nowhere
  else in the output.

**Two of these rows cannot carry a disposition forward, and that is why this table is the home of
record rather than `RESULTS.md`.** The kit's runner keys the watch list on function name plus file,
falling back to CCN to break a tie, and leaves the cell blank when neither key is unique
(`tests/_kit/run-automated-tests.sh:537-556`, which names this addon as the case it was written for).
Three rows here are `]` in `core/Database.lua` and two of those three are CCN 16 — so `migrations[1]`
and `migrations[12]` are indistinguishable on both keys and will read blank on every run that
regenerates them, forever. Their disposition exists here or nowhere.

**Two of these functions have already spent a trigger this repository wrote for them, in its own
hand.**
`docs/automated-tests/RESULTS.md`'s v0.1.0 watch list carries an *At the ceiling* table of four
functions at exactly CCN 15, written so "whoever next edits one knows there is **zero** headroom
left". Two of the four are on this table now: `Cell:ApplyBorder` at **30** and
`WindowProto:BuildLayout` at **24**. The other two, `normalizeColumns` and `Cell:Update`, are still
under the line. A trigger that fires and is not acted on is the thing this register is for, so both
are peels rather than accepts, and neither is arguable.

Rows are in `lizard`'s own order, which is the order the runner emits them in. **Location carries the
line range**, because it is the only thing that separates the three `]` rows; the runner's own
Location cell is the file alone.

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `migrations[1]` (`]`) | 16 | `core/Database.lua:270-296` | **Accepted.** A shipped migration step is frozen the day it lands; the count is `type(x) == "table"` guards down profiles → windows → columns, and the one decision in it is the frame-widening `if`. Re-check: any step gains a branch that is not a type guard, or passes 40 NLOC. |
| `migrations[4]` (`]`) | 17 | `core/Database.lua:372-401` | **Accepted.** Same shape and the same freeze: the lift of `mergePets` / `throttle` to profile level, guarded twice per key because "already set" cannot be told from "just merged in". Re-check: as above. |
| `migrations[12]` (`]`) | 16 | `core/Database.lua:659-684` | **Accepted.** Same again: `titleBar` moves to `header.show` and two class-colour booleans become modes, each behind a `~= nil` and a prune. Re-check: as above. |
| `reportDeathDating` | 25 | `core/Diagnostics.lua:648-689` | **Accepted.** Developer-only print code behind `/mm debug diag`; the count is `x and y or "nil"` inside two `string.format` argument lists, and the function's whole value is that it prints inputs rather than a conclusion. Re-check: the Tier 2 trigger already recorded for `debug.md` above — a probe section gains state or an option. |
| `reportFeignRoster` | 17 | `core/Diagnostics.lua:1738-1761` | **Accepted.** Same class: three guarded unit reads per group member in one formatted line, printed for the whole group so a non-feigning baseline sits beside the feigning row. Re-check: as above. |
| `scanColumn` | 34 | `modules/Aggregator.lua:1462-1565` | **Peel** — [#35](https://github.com/tusharsaxena/MultiMeters/issues/35). The per-source loop body, and the counted-column max pass under it. `M2-09` already took 36 → 34 by hoisting `judgeTracer` out, so the seam is proven rather than proposed. |
| `DrillDown:OnCellClick` | 18 | `modules/DrillDown.lua:395-428` | **Accepted.** 20 NLOC; the count is three `f() and "x" or "none"` returns plus the Deaths ladder, and the ladder's **order** is the only thing the function records. Re-check: a second `statKey` grows a ladder of its own — two ladders are a table. |
| `Export.ChatLines` | 27 | `modules/Export.lua:535-600` | **Peel** — [#36](https://github.com/tusharsaxena/MultiMeters/issues/36). The header build and the ranked line are two functions sharing a name; the `hasExtra` bookkeeping belongs entirely to the second. |
| `onPrintToChat` | 16 | `modules/Export.lua:1427-1492` | **Accepted.** Four refusals, each with a recorded reason and each asked at the click because the answer changes between opening the modal and pressing the button, then a linear send. One point over. Re-check: a fifth refusal, or CCN 20. |
| `Feign.Prune` | 25 | `modules/Feign.lua:247-337` | **Peel** — [#37](https://github.com/tusharsaxena/MultiMeters/issues/37). The `unit == nil` fork: the member who left the group and the member whose health is read are two verdicts, and the function's own comments already treat them as separate findings. |
| `Format.DeathTime` | 19 | `modules/Format.lua:646-665` | **Accepted.** 15 NLOC at CCN 19 is `performance-§10`'s own documented artefact in its purest form: every `or` fallback scores as a decision and not one of them branches. Re-check: a third style beyond `clock` and `ago`. |
| `onClick` | 24 | `modules/HeaderControls.lua:322-372` | **Peel** — [#38](https://github.com/tusharsaxena/MultiMeters/issues/38). A seven-way `elseif` on the control name, sharing no state across arms; a module-level dispatch table is the shape `performance-§11` permits, built once rather than per click (#52). |
| `build` | 20 | `modules/Roster.lua:249-366` | **Accepted.** One unit walk with three outputs, and the header says why it is not three walks; the count is `unitExists` / `IsSafeKey` guards plus the nested pet read. Re-check: a fourth output joins the walk, or the pet lookup grows a second kind — then the per-unit body peels to `addMember`. |
| `Cell:ApplyBorder` | 30 | `modules/Row.lua:646-726` | **Peel** — [#39](https://github.com/tusharsaxena/MultiMeters/issues/39). Its own comment names the seam — the art path and the flat path are mutually exclusive — and the per-side anchor chain under it is a data table. **Its ceiling row's trigger has fired**: 15 → 30. |
| `Cell:ApplyIcons` | 19 | `modules/Row.lua:1155-1231` | **Accepted.** The slot array is `{ "unit" }` or `{}` today, so the loop is degenerate and what remains is defaulting and the left/right mirror. Re-check: a second slot returns — [#8](https://github.com/tusharsaxena/MultiMeters/issues/8) would do it — at which point the loop is real and the peel is worth taking. |
| `eventColumns` | 19 | `modules/Tooltip.lua:1859-1912` | **Accepted.** A name-resolution ladder over one recap event where each arm is a documented client behaviour: a melee swing carries no spell at all, a heal names none, an unnamed spell shows its id rather than being dropped. Re-check: a fourth event kind. |
| `drawDeathEvents` (`(anonymous)`) | 26 | `modules/Tooltip.lua:1950-2032` | **Peel** — [#40](https://github.com/tusharsaxena/MultiMeters/issues/40). Collect, measure, draw are already three phases in sequence; the measuring pass carries all of the `namesReadable` bookkeeping and none of the drawing. See the parser note above before opening the file. |
| `Tooltip:CellTooltip` | 20 | `modules/Tooltip.lua:2335-2397` | **Accepted.** Linear composition — release, open, header, style, one Deaths/spell branch, five appends, then `Show` and the two fixups that must follow it. The count is defaulting; there is no tangle here to peel. Re-check: a third path joins the Deaths/spell branch. |
| `Visibility.ShouldShow` | 23 | `modules/Visibility.lua:239-276` | **Peel** — [#41](https://github.com/tusharsaxena/MultiMeters/issues/41). Eight copies of one line in 21 NLOC; a module-level `{ flag, probe, reason }` table and one loop is `performance-§11`'s permitted shape, and it makes the veto **order** — which the comment says is the point — data rather than line position. |
| `WindowProto:BuildLayout` | 24 | `modules/Window.lua:312-413` | **Peel** — [#42](https://github.com/tusharsaxena/MultiMeters/issues/42). The middle third: the visible-column filter, the equal share and the placement loop. Rule R3 is the constraint on the peel — config in, numbers out, no frame read back. **Its ceiling row's trigger has fired**: 15 → 24. |
| `place` | 18 | `modules/Window.lua:1277-1409` | **Peel** — [#43](https://github.com/tusharsaxena/MultiMeters/issues/43). 133 lines and 5 parameters, and create-once-then-dress is the split `LIBKA0S-R-01` already cut in the library's `TabStrip`. Being a closure over the enclosing method is the work, and the reason it is worth more than CCN 18 suggests. |
| `NS.ReorderableBlocks` | 28 | `settings/ColumnBlocks.lua:215-310` | **Peel** — [#44](https://github.com/tusharsaxena/MultiMeters/issues/44). The loop body is doing three jobs — draw the block, register the row, draw the boundary rule — and everything outside it is one refusal and a descriptor. |
| `doDebug` | 25 | `settings/Slash.lua:434-505` | **Peel** — [#45](https://github.com/tusharsaxena/MultiMeters/issues/45). The only verb that takes an argument is the only nested ladder; the other three name a `Diagnostics` method and collapse to a table. **The only warned function that got worse this cycle** — 23 → 25 under `M2-11`, for a good reason, which is exactly the move a watch list exists to catch. |

**Eleven peels, twelve accepts, and no split lands here.** The 2026-09-07 remediation plan rules one
out (`03_SPEC.md` § C22 non-goals) and `M4-26`'s deliverable was the disposition — so that
`automated-tests-§4`'s "every watch-list entry carries a disposition" has something to resolve
against instead of 23 blank cells. Every peel names a seam the code argues for itself; not one of
them is an extraction performed to move a number, which `performance-§11` and anti-pattern **#52**
both forbid, and each issue states what the peel must not change.

**The shelf life starts at the next release run.** `automated-tests-§4` and anti-pattern **#53** give
an accepted entry three consecutive release runs, after which it is fixed or converted into a
tracked deviation with an ID. This repository's last release run is
[`20260809-195454`](automated-tests/20260809-195454/), the v0.1.0 run, and its watch list predates
every entry here — so none of the twelve accepts has spent a run yet, and the clock starts at the
first release run after this register is written.

**What `tests/test_complexity_register.lua` asserts, and what it does not.** It reads this table and
checks that the count stated above matches the rows, that every Location names a file that exists,
that no two rows name the same function at the same location, and that every disposition is
followable — an issue number, or an accept with the re-check trigger that stops it being a permanent
opt-out. It never runs `lizard`, and that is deliberate: `performance-§10` says a commit **MUST NOT**
be gated on complexity, and a suite that shelled out to `lizard` would be exactly that gate wearing a
test's clothes. The CCN figures here are dated measurements, like the line counts in the census
above, and the same rule applies — membership and disposition are the invariants, the numbers are
prose. What re-measures them is the runner, at `M5-01`.

## Load order

`MultiMeters.toc` is the source of truth; the order is dependency, not alphabetical. Full
per-file reasoning in [module-map.md](module-map.md#load-order). The binding constraints:

1. `libs/` — Ace3, LibKa0s, LibSharedMedia, AceGUI-3.0-SharedMediaWidgets, LibDataBroker, LibDBIcon.
2. `locales/enUS.lua` — first, so `NS.L` exists for every declaration below.
3. `core/Compat.lua` **first** in the core block — it is the boundary every later file's cross-patch
   call goes through — and `core/EnvSetup.lua` immediately after it and **before
   `core/Namespace.lua`**, whose `resolveVersion()` runs at *file scope* and reads the TOC manifest
   through the `NS.Meta` seam that file publishes. A seam that loaded later would pin `NS.version` to
   `FALLBACK_VERSION` for the whole session, silently.
4. `core/MediaSetup.lua` **before `core/Constants.lua`**, which resolves `FONT_MONO` from the
   `NS.MediaFont` it publishes. It is the one seam outside the cause clause, so it is free to load
   first and has to.
5. `core/PoolSetup.lua` after the `libs/` block and **before `modules/Window.lua`**, the pool's only
   consumer. It carries no other constraint: it publishes `NS.Pool` and captures nothing.
6. `core/CoreSetup.lua` before `core/MultiMeters.lua`, whose AceConsole reclaim reads
   `NS.Util.print`; and **first of the five seams that share the cause clause**, because it defines
   `NS.LIBKA0S_MISSING`.
7. `core/PerfSetup.lua` after `core/Namespace.lua` (a nil `version` stamps every capture record `v?`)
   and **before every `modules/` file that takes `local Perf = NS.Perf` as a load-time upvalue**.
8. `defaults/Profile.lua` after `core/Constants.lua`, whose stat catalog it captures at load.
9. `modules/Format.lua` first in the module block; `modules/Row.lua` resolves `Tooltip` and
   `DrillDown` at *call* time because both load after it. `modules/Targets.lua` loads before
   `modules/Tooltip.lua`, its only caller. `modules/Export.lua` sits after `modules/DrillDown.lua`
   and is the one file in the block whose position carries no constraint at all: it captures no
   sibling at load and resolves every one of them — `Aggregator`, `Format`, `Secrets` — at call
   time, because `modules/Window.lua` loads *before* it and holds the button that calls it.
10. `settings/Schema.lua` first in the settings block — `Slash.lua` and `OptionsSetup.lua` both point
    their seams at `NS.SetByPath` / `NS.GetSetting` at load — and `settings/OptionsSetup.lua` before
    every page file, which call `NS.Helpers` members inside schema-row literals at file load.
