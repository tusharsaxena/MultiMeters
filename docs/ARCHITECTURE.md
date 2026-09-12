# Architecture

Orient-yourself map for **Ka0s Multi Meters**. A single-frame, multi-column group meter for Retail
(Midnight, 12.x): one row per group member, one column per statistic, each cell a `StatusBar` with a
`FontString` on it. Every number is read from Blizzard's built-in damage meter through
`C_DamageMeter`; the addon never parses the combat log.

This file is the hub. Topic detail lives in `docs/` and is linked from each section — a section here
that outgrows a screen belongs in its topic doc with a summary and a link left behind.

## Overview


Fifty-seven non-vendored source files: 1 locale, 17 `core/`, 1 `defaults/`, 23 `modules/`, 15 `settings/`.

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


The stat catalog, the eight statistics and the one this addon reads without cataloguing, what a
window owns, and the two features that are structurally impossible rather than merely unbuilt are
all in **[scope.md](scope.md)**. Which LibKa0s majors are consumed, which seam file reaches each and
what each degrades to are in [module-map.md](module-map.md#libka0s-seams).

## Module map

Every file — all fifty-seven of them — what it owns, what it publishes, what it consumes, plus TOC
load order and the AceAddon lifecycle: **[module-map.md](module-map.md)**. The shape at a glance:

| Layer | Files | Responsibility |
|---|---|---|
| `locales/` | `enUS.lua` | `NS.L`, with the key-is-the-string fallback. Loads first. |
| `core/` boundary | `Compat.lua` | All 28 cross-patch shims, including the eight `C_DamageMeter` reads. No logic. |
| `core/` boundary | `EnvSetup.lua` | The `LibKa0s-Env-1.0` seam: `NS.Meta` / `NS.Version`, the TOC-manifest reader `Compat.lua` used to own. |
| `core/` values | `Constants.lua`, `Namespace.lua`, `State.lua` | The stat catalog, the bus catalog, identity, session-only flags and the shared cache. |
| `core/` the rule | `Secrets.lua` | **The only file that inspects a meter value.** |
| `core/` seams | `MediaSetup`, `CoreSetup`, `PerfSetup`, `DebugLogSetup`, `PoolSetup` | LibKa0s wiring, the art and font seam, and the window row pool. The `LSM30_Border` fixup that used to make a sixth file here is `lib.__PatchLSM30Border()` now, called from `settings/OptionsSetup.lua`: AceGUI's widget registry is process-global, so a re-registration belongs to the library the whole collection shares. |
| `core/` runtime | `MultiMeters.lua`, `Database.lua` | The single game-event listener and the show ladder; AceDB and migrations. |
| `core/` diagnostics | `Diagnostics.lua` + `Diagnostics_DeathRecap`, `_Identity`, `_Feign` | `/mm debug diag` and the three per-issue probes hung off it. Each probe is self-contained so it can be deleted with the issue it answers. |
| `defaults/` | `Profile.lua` | The window template. The only place a profile default is hardcoded. |
| `modules/` data | `Provider`, `Roster`, `Feign`, `Aggregator` (+ `_Identity`, `_Preview`), `Format` | Read → join → order → render as text. `Feign` is the one source row the addon deliberately discards; `Aggregator_Identity` is the grid drawn while the GUID is secret. |
| `modules/` display | `WindowManager`, `Window` (+ `_Header`, `_Placement`), `HeaderControls`, `Row` (+ `_NameCell`), `Targets`, `Tooltip` (+ `_Lines`, `_Builders`), `DrillDown`, `Visibility`, `Minimap` | The registry, one window, one row, the enemy cross-reference, the two hover surfaces, the breakdown, the context predicate, the launcher. |
| `modules/` output | `Export`, `Export_Modal` | The segment a window is pointed at, as CSV or as ranked chat lines — the pure half and the dialog that drives it. Calls no meter API: it asks the aggregator, exactly as a window does. |
| `settings/` | `Schema_Compose` → `Schema` → `Schema_Paths`, `Slash`, `OptionsSetup`, `ColumnBlocks` + 9 pages | One schema drives the panel, the CLI and the defaults reset: what the array is composed from, the array, and the path and write seams. `ColumnBlocks` is the Columns page's row, drawn into `LibKa0s-Widgets-1.0`'s `ReorderList`. |

Thirteen of those files were created on 2026-09-09 and **none of them is a new module.** They are
`layout-§1` peels of the seven source files that stood over the 1500-line cap, each cut along a seam
its own header had already named, and each hanging its functions on the **same** prototype or module
table its parent builds. That is why so many of the new TOC lines are load-bearing: the parent
publishes what used to be a file-local and the child resolves it at *file scope*, so a peel that
loaded first would capture nil and stay nil for the session, silently. The per-file reasons are in
[module-map.md](module-map.md#load-order); `MultiMeters.toc` states each at its own line.

The path a number takes through those layers — the throttle, the GUID join, pet folding, the sort
identity build, the formatter and the widget setters — is **[data-flow.md](data-flow.md)**. Read it before
touching the data path.

## Settings schema

`NS.Schema` in `settings/Schema.lua` is the single source of truth: **166 rows across 8 page keys**
(windows 1, frame 26, header 35, bars 28, tooltip 30, visibility 17, columns 8, general 21), each one
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

The write seam is `NS.SetByPath`, with `NS.SetByPaths` as its batch form; the reader is
`NS.GetSetting`. Both the panel and the CLI point at them, so `/mm set window.frame.width 300` takes
exactly the path a slider takes — same validation, same debug line, same `CONFIG_CHANGED` message,
same panel re-sync.

**The window-relative path model** is the one thing here that is not standard-issue. A window row's
path is relative (`window.frame.width`) and the seam resolves it against `NS.State.activeWindowId`,
which the settings panel's window picker moves, or against a window id the caller passes. The other
twenty-one rows keep absolute paths against `db.profile`, so moving one integer retargets **145**
rows ([schema.md](schema.md#the-window-relative-path-model) lists both sets).

Profiles carries **zero** rows: AceDBOptions' own tree, the one place `AceConfigDialog` is permitted,
and vetoed from reset-all. Columns carries eight `window.columnHeader.*` rows beside its block
editor, whose `window.columns` array is the seam's documented whole-array carve-out.

**The window registry has one writer** (`architecture-§5`), since no row can name a window's
existence. Its storage keys are `db.profile.windows` (entries carry their `id` and unique `name`) and
the id counter `db.profile.nextWindowId`. Its writer is `modules/WindowManager.lua` (`Create`,
`Delete`, `Duplicate`, `Rename`'s uniqueness check) with its helpers `Database.NextWindowId` and
`Database.EnsureWindowShape`. Its load pass is `Database.SeedWindows`, run only by `NS:RunMigrations`.
Rows inside a window stay the seam's even when the registry writes them, through the seam's optional
window id ([schema.md](schema.md#the-window-registry-and-its-writer)).

**`frame.position` is named non-setting state** (`architecture-§5`: geometry only a drag
determines), so it needs no register row. Its storage key is `frame.position` in each
`db.profile.windows` entry, and its one owner is `WindowProto` (`modules/Window_Placement.lua`).
`WindowProto:SavePosition` writes it on the title bar's drag-stop. `WindowManager:ResetPosition`
(General's *Reset position* button) and `:ResetPositions` (`/mm reset-positions`) put back the
shipped center. `WindowManager:Create` writes it whole through `NS.DefaultWindow`, and `:Duplicate`
writes its derived 24 px offset. `Database.EnsureWindowShape` backfills a missing one when `Create`,
`Duplicate` or `CopyFrom` calls it. Nothing else writes it
([schema.md](schema.md#frameposition-is-named-non-setting-state)).

**The sort and the session type are preferences, not a remembered view**: a header click and the
segment menu choose them, so the four `window.data.*` fields are hidden rows written through the seam
by window id. The pinned segment, `data.sessionID`, is open for the owner ([schema.md](schema.md#data)).

**`MultiMetersPerfDB` is recorded data a vendored library writes.** `core/PerfSetup.lua` owns it and
hands it to LibKa0s-Perf, whose `P.Save` appends a capture to the ring on `/mm perf finish`.

`NS.ValidateSchema()` proves every row's `default` equals `defaults/Profile.lua`'s. Panel behavior:
[settings-panel.md](settings-panel.md); persisted shape and migrations: [schema.md](schema.md).

## Message bus

Fourteen `AceEvent` messages are the only inter-module communication channel — modules never call each
other across boundaries. Every name is declared once in `core/Constants.lua`'s `MSG` catalog, so a
typo in a subscriber is a nil-index at load rather than a callback that silently never fires.
**One sender each**; a second sender is a bug, not a convenience.

| Message | Sender | Consumers | Payload |
|---|---|---|---|
| `METER_UPDATED` | `core/MultiMeters.lua` | `Targets`, every `Window` | — |
| `METER_SESSION` | `core/MultiMeters.lua` | `Provider`, `Targets`, every `Window` | `{ type, sessionID }` |
| `METER_RESET` | `core/MultiMeters.lua`, and `Provider.Reset` for the manual path | `Provider`, `Feign`, `Aggregator`, `Targets`, `DrillDown`, every `Window` | — |
| `ROSTER_CHANGED` | `core/MultiMeters.lua` | `Roster`, `Feign`, `Visibility`, every `Window` | — |
| `ZONE_CHANGED` | `core/MultiMeters.lua` | `Visibility`, every `Window` | — |
| `ENTERING_WORLD` | `core/MultiMeters.lua` | `Provider`, `Roster`, `Feign`, `Visibility`, every `Window` | `{ isLogin, isReload }` |
| `RESTRICTION_CHANGED` | `core/MultiMeters.lua` | every `Window`, the export modal (`modules/Export_Modal.lua`) | `{ type, state }` |
| `COMBAT_CHANGED` | `core/MultiMeters.lua` | `Visibility`, every `Window` | — |
| `PLAYER_STATE_CHANGED` | `core/MultiMeters.lua` | `Visibility`, every `Window` | — |
| `PROFILE_CHANGED` | `core/Database.lua` (`fireProfileChanged`) | `Format`, `Roster`, `Aggregator`, `Targets`, `WindowManager`, `DrillDown`, `Visibility`, `settings/Profiles.lua` | `{ newProfileKey }` |
| `CONFIG_CHANGED` | `settings/Schema_Paths.lua` (`NS.SetByPath`, and once per batch from `NS.SetByPaths`) | `Format`, every `Window` | `{ section, windowId }` |
| `WINDOWS_CHANGED` | `modules/WindowManager.lua` (`announce`) | `DrillDown`; the settings panel repaints on the same registry actions through `NS.RefreshOptionsPanel`, by direct call rather than by subscription | `{ windowId, action }` |
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
many windows. AceAddon modules are their own targets; each `Window` instance, `modules/Format.lua`,
`modules/Targets.lua`, the export modal in `modules/Export_Modal.lua` and `settings/Profiles.lua`'s
page own a private target from `NS.NewBusTarget()`. Nothing registers on the shared addon object.

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
| `debug` | Toggle the console window; `on` / `off` set session logging; **`tooltip`** toggles the tooltip log channel, off by default because a tooltip is rebuilt on every mouse-over and would evict the buffer; **`diag`** prints the diagnostic report; **`recap`** prints the death-recap probe alone; **`identity`** prints the mid-pull identity-correlation capture (issue #22); **`feign on`** / **`feign off`** arm and disarm the feign-death recording and **`feign`** prints it (issue #25) |
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

**These edges are load-bearing, not an optimization** — there is no fallback poll, so a visibility
input with no edge on the bus is a rule that never fires. Why, and which rule it cost, is in
[module-map.md](module-map.md#game-event-edges-are-load-bearing). The three edges that exist because
of what a particular client has — the probed `PLAYER_IS_GLIDING_CHANGED`, the event-name filter, and
the settle pass over client state that lags its own event — are in
[midnight-quirks.md](midnight-quirks.md#client-version-workarounds-on-the-event-edges).

Everything else is a bus subscription. Registration by module is tabulated in
[module-map.md](module-map.md#what-each-file-publishes-and-consumes).

Perf buckets, declared in `core/PerfSetup.lua` with their nesting: `meterEvent` · `refresh`
(→ `aggregate` → `providerRead`, `render` → `renderRow`) · `tooltip` (→ `targets` → `providerRead`).
`providerRead` has two parents, so it declares none, and every nested bracket passes the parent it
ran inside, so a capture reports the tree as observed. A parent is never summed with its children.
Detail in [performance.md](performance.md) and
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
  anchored to it. There is not one `GetPoint` / `GetWidth` / `GetLeft` in `modules/Row.lua` or in
  `modules/Row_NameCell.lua`, the name cell peeled out of it; a window keeps drag and resize on a
  bare `inst.anchor` frame that never holds a value.

Two consequences worth stating once, because both look like bugs: **percentage text slots go quiet in
combat** (a percentage is a division), and **a pet keeps its own row rather than being summed into its
owner's while restricted** (a sum is arithmetic, and the native formatter renders but does not sum).
The second is why the scoring feature is deferred — [scope.md](scope.md#deferred-scoring).

The rest of the model — secret GUIDs out of the unit API, what R3 buys when it runs the other way,
why an export refuses entire rather than degrading, and why secrecy keys off `Combat` rather than
`ChallengeMode` — is in **[midnight-quirks.md](midnight-quirks.md)**.

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
The two mechanisms coexist on purpose — see `modules/Export_Modal.lua`'s "The modal's three selectors"
comment, which argues the same split from the other side.

## Known limitations

Every one of them, with its measurement and its issue number, is in
**[scope.md](scope.md#known-limitations)**. The shape of the list, so a reader knows what kind of
thing is in it before opening it:

- **Identity mid-pull.** `sourceGUID` is secret for the whole of a pull, so the grid is rebuilt by
  identity correlation; two players of one class and spec cannot be told apart, and in a raid
  `specIconID` does not arrive at all, which makes the grid 98% blank mid-pull
  ([#22](https://github.com/tusharsaxena/MultiMeters/issues/22),
  [#24](https://github.com/tusharsaxena/MultiMeters/issues/24)). Blanking is correct: a mislabeled
  number is a lie the player cannot see.
- **Arithmetic mid-pull.** Percentages go quiet, pets keep their own rows whatever `data.mergePets`
  says, and the feign-death filter has no plain key to join on until combat ends.
- **Serializing mid-pull.** Both halves of export refuse, in a sentence, because `tostring` on a
  secret answers a secret string rather than raising.
- **What the data source does not carry.** A past death cannot be dated against its run; a feign's
  death row carries nothing a real death's lacks, so the provider cannot filter one
  ([#25](https://github.com/tusharsaxena/MultiMeters/issues/25)); pet attribution has no owner link
  and is best-effort; the provider-order assumption is measured rather than proven.
- **Deliberate ceilings.** English only, Retail only, a 40-row export cap, no in-window column drag
  editor (rule R3), wheel-only scrolling, a sticky roster, a drill-down list that is a snapshot, and
  session-only debug logging.

**The tooltip is the one thing this addon positions itself**, and that one `SetPoint` onto a cell
with secret geometry is the only call in the addon that could raise inside Blizzard's own code while
tainted by us. It is `pcall`'d; a failure leaves the `SetOwner` token's placement standing.

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
| `complexity.md` | The `lizard` report `performance-§10` fixes to this path — one file, overwritten in place, so the git history of it is the trend line. Carries the watch list and the 1000–1500 LOC band |
| `compat-layer.md` | Every client API this addon shims: the `C_DamageMeter` and `C_DeathRecap` surfaces, the recap-discovery probe, the secret-safe number formatters, the icon-existence checks and the three player-context rules |
| `debug.md` | The `/mm debug` surface: the console, the two session flags, the eighteen log channels and the four per-issue probes |
| `midnight-quirks.md` | The 12.0 client behaviors this addon works around, and the secret-value detail behind `## Taint notes` |
| `superpowers/` | Tier 3 planning history, frozen — the approved design specs and build plans behind each feature, under `specs/` and `plans/`, dated and never revised after the fact |
| `revendor/` | Frozen — one dated bundle per LibKa0s re-vendor: the payload delta and what was adopted, declined or filed from it |
| `audits/` | Frozen — one dated bundle per `/wow-addon:standards-audit` run: the state, the deviations and the evidence as they stood on that date |
| `reviews/` | Frozen — one dated bundle per `/wow-addon:review` run: the findings, the proposed changes and the plan as they stood on that date |

### Tier 2 conditional docs — evaluated at v0.1.0

Each trigger was measured against the source, not assumed. **Five of the six do not ship**, and the
measurements that decided that are recorded here so a later audit can re-run them rather than
re-argue them. The sixth, `compat-layer.md`, crossed its own line and has been written; it is
registered under [Topic detail](#topic-detail) and its row below is kept as the measurement that
moved it. This is an evaluation record, not a fourth register table — every doc below that *does*
exist is registered above.

| Doc | Status | Trigger, as measured |
|---|---|---|
| `slash-dispatch.md` | Not applicable | **16 verbs in `NS.COMMANDS`.** Ten are the standard's reserved set, implemented entirely by LibKa0s-Slash-1.0 and documented by the standard. This addon's own surface is 6 verbs and one 4-entry sub-verb tree (`window`: list/new/delete/copy); `debug` takes 7 words, one of which (`feign`) takes an argument of its own and one of which (`tooltip`) is a session flag; `perf` delegates its whole sub-surface to the library, and `export` takes one optional window name. The [Slash commands](#slash-commands) section carries all of it in a screen. |
| `message-bus.md` | Not applicable | **14 distinct messages**, all declared in one catalog (`core/Constants.lua` `MSG`) with the owning sender named beside each. Every payload is a flat table of one to two plain fields; none carries a handle, a curve object or a per-unit filter needing prose. The [Message bus](#message-bus) section carries sender, consumers and payload for all fourteen in one table. |
| `compat-layer.md` | Present | **`core/Compat.lua` is 761 lines and 28 shims** (8 of them `C_DamageMeter`, 4 death-recap, plus the recap-namespace probe `RecapMembers` / `RecapAPIs` / `CallRecap`), each a guarded namespace check around one passthrough, with no feature decisions, no state, and nothing there inspecting a meter value. The row read *re-measure — the trigger now fires* from the day this addon's Compat passed KickCD's, which ships the doc: 389 lines and 18 shims when the row was last written, 761 and 28 now. `documentation-§3` has since given the trigger a number — **three or more** addon-specific shims, counted over this file alone — which settles it at any reading. Written; registered under [Topic detail](#topic-detail). |
| `midnight-quirks.md` | **Present** | **At least one client-version workaround of the addon's own** — the trigger as §3 states it, and this addon carries four: the probed `PLAYER_IS_GLIDING_CHANGED`, `ADDON_RESTRICTION_STATE_CHANGED` registered against a namespace a client may not have, the settle pass over client state that lags its own event, and the secret-value model itself. It was read as Not applicable on the argument that a third copy of the secret-value rules would be the one that drifts — which was an argument against DUPLICATING them, not against the doc. The detail was MOVED here rather than copied: [Taint notes](#taint-notes) keeps the constraint, the operation lists and R1–R3, and nothing is stated twice. |
| `profiles.md` | Not applicable | `settings/Profiles.lua` is 126 lines hosting **AceDBOptions-3.0's own tree** unchanged. The addon adds no profile semantics beyond the `PROFILE_CHANGED` fan-out already tabulated above and the reset-all veto already stated under [Settings schema](#settings-schema); the persisted shape is [schema.md](schema.md)'s. |
| `debug.md` | Present | The console is `LibKa0s-DebugLog-1.0`'s window; this addon's own surface is the four probe verbs, the `tooltip` channel flag and the eighteen `NS.Debug` channels. **Written 2026-09-09, when this row's own re-check trigger fired.** It had read "Not applicable — print statements with no state and no options for a doc to describe", which was true until `/mm debug tooltip` added a session flag on `NS.State`. The trigger was recorded on the row and the doc followed in the same changeset. |

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
| options-ui §17 — every colour picker carries a "use class colour" companion | `window.header.bgColor` — the title bar's own background — ships with **no** companion. Every other non-palette swatch in the addon has one. | Neither answer a companion could give is true of this surface. The title bar is **one strip spanning the whole window**, so "per statistic" could only ever mean the sort column's colour — a fact already on screen twice, in that column's own header and in its arrow — and that is the same argument that took the mode off the title bar's *text* background and off the divider's `stat` option. The strip beside it, the column-header background, **does** keep a mode, and the difference is the point: that one labels the columns, so per-statistic tints each label with its own column's colour and means something (`settings/Schema_Compose.lua`, the note above `window.columnHeader.bgColorMode`). A companion added here would be a control wired to a colour nobody chose. | 2026-09-02 | The title bar grows a surface that belongs to one column or to one player — a per-row header, a sort-column tint on the strip itself — at which point "which class" and "which statistic" both have an answer and the row retires. |
| options-ui §17 — "one resolver": the class-colour lookup is the library's | `NS.ClassRGB(classFilename)` (`core/Namespace.lua`) stays as a **second** reader of `RAID_CLASS_COLORS`, beside the library's `NS.ClassColor(unit)`. | The two answer different questions. `LibKa0s-Core-1.0`'s `ClassColor` takes a **unit token**; a meter row is a GUID and a `classFilename` out of `C_DamageMeter`, and most rows have no token at all — a player who left the group, an NPC in a damage-taken column, a follower-dungeon companion. Retiring `ClassRGB` in favour of the unit-keyed lookup would silently uncolour every one of them. The **surface** question — the window's chrome, its header, its backdrop and its border — does go through the library, via `NS.PlayerClassRGB`, which is the case the standard's clause is about; what stays private is the roster reader. Neither has a fallback the other lacks: the degraded reader in `core/CoreSetup.lua` calls `ClassRGB` too, so there is still exactly one table lookup in the addon. | 2026-09-02 | `LibKa0s-Core-1.0` grows a class-**filename** overload of `ClassColor` (or a sibling reader), at which point `ClassRGB` becomes the private copy the clause forbids and is deleted. |
| library-stack §8 — "where the addon needs a mark it MUST use the catalog's" | `settings/ColumnBlocks.lua:72-73`'s column-block enable/disable glyph stays on Blizzard's `ReadyCheck-Ready` / `ReadyCheck-NotReady` pair, although `LibKa0s-Media-1.0` **does** carry `circle-check` and `ban`. This is the one site in the addon where the catalog has the mark and the addon declines it. | **Three reasons, and only the third is the one that binds.** (1) *Colour.* The catalog's art ships white with its shape in the alpha channel, because the collection tints by multiplying — so `circle-check` and `ban` would both draw white, and enabled-vs-disabled would be carried by shape alone where the pair on screen today carries it in green and red as well. Reconstructing that means a vertex colour per state, which is a second vocabulary for one signal rather than one fewer. (2) *Degradation.* `NS.Icon` answers **nil** on a load without the payload (`core/MediaSetup.lua`), and this glyph has no ladder beneath it the way `modules/HeaderControls.lua`'s art does — the block would lose its tick outright, where a Blizzard path is part of the client and cannot go missing. (3) *Parity, which is why the line exists at all.* These are the same two textures ConsumableMaster's priority list wears (`settings/StatPriority.lua`'s `INCLUDED_TEX`/`EXCLUDED_TEX`, with `modules/KCMItemRow.lua`'s `OWNED_TEX`/`NOT_OWNED_TEX` and `settings/Category.lua`'s `OWNED_ICON`/`NOT_OWNED_ICON` beside them — named rather than numbered, because no gate in this repository can follow a line number into another one and one of those three had already slipped a lane's worth of edits by the next morning), so a player running both reads one glyph vocabulary rather than two. Moving one addon alone does not reduce the deviation; it converts a shared vocabulary into a split one, which is strictly worse than the state being ratified here. The 2026-09-07 remediation plan reaches the same conclusion in as many words — the two sites "move in both repositories together or in neither", and filing the row in both is the other half of the same choice. This repository can only file its half. **Re-challenged 2026-09-08 and unchanged.** The item's acceptance asks for two things at once — both named sites on `NS.Icon`, *and* MultiMeters' parity comment still true — and from inside this repository alone the two are not simultaneously satisfiable while ConsumableMaster's three sites stand: the move that meets the first clause is what makes the second false. The finding the item traces to says so in its own words, offering "in MultiMeters and ConsumableMaster together, **or** file the register row in both" (`MM-A-07` in `docs/audits/2026-09-07/`), and this is that second branch taken deliberately rather than a site left unvisited. LootHistory's half of the same item shipped meanwhile and settles reasons (1) and (2) on the record rather than in argument — its `NS.IconMarkup` carries the state colour in the escape's own vertex fields and keeps the Blizzard path underneath as the fallback rung — which is why the row has always said only the third reason binds. | 2026-09-08 | ConsumableMaster's three sites adopt the catalog, or its priority list is retired — at which point the parity argument has no second half and this pair moves in the same cycle it does. Reasons (1) and (2) are answered upstream instead and each retires this row on its own: a `LibKa0s-Media-1.0` that publishes a tinted state pair, or an `NS.Icon` contract that carries a Blizzard fallback. |

**Retired on 2026-09-09: the seven mirror suites over the cap.** The register carried a `layout §1`
row ratifying seven test files that stayed over the 1500-line cap — `tests/test_window.lua` (2737)
down to `tests/test_export.lua` (1509) — on the argument that a mirror suite has no seam of its own:
its partition is whatever partition its module ends up peeled on, and peeling the suite first commits
to a partition the module has not chosen yet. That argument was right, and the row was written with
the trigger that ends it: *"The mirrored module is peeled … the suite peels along the same seam, in
the same commit."*

It fired. On 2026-09-09 every mirrored module was peeled along the seam its own issue named, and each
suite followed it — `tests/test_window.lua` behind `modules/Window_Header.lua` and
`Window_Placement.lua`, `tests/test_diagnostics.lua` into one suite per probe, and so on. All seven
are under the cap, the eight breaches the row explicitly did not cover are gone with them, and
nothing this repository tracks is over 1500 lines. A ratified deviation for a state that no longer
exists is the graveyard this table's own preamble forbids, so the row is retired rather than re-dated.

Worth keeping from it: the reason the peel had to be the module's commit and not its own. The two
files track each other closely enough that several banners were byte-identical — `modules/Window.lua`
and `tests/test_window.lua` both carried *Layout — rule R3 in one function*; `modules/Row.lua` and
`tests/test_row.lua` both *The name cell* — and that pairing is what makes a red legible, because you
read the failing case name and know which file to open. It survived the peel because the peel kept it.

**Retired on 2026-09-08: the composed blocks on a degraded load.** The register carried an
`options-ui §15, §16` row for the schema a library-less install ends up with — the Master controls
tab and every font, border and bar group absent, because they are the library's to emit. The
argument was that a hand-written copy standing behind the composer is anti-pattern #73 and would go
stale first, and `options-ui-§1` has since ruled exactly that: when the missing content is
**composed**, the no-copy MUST wins, a stub's composer members answer an empty row list, and — in
as many words — *"this shape needs no register row, and the rows already written for it retire"*.
So this one does. The three bounds the ruling attaches are met here and were met before it landed:
`LibKa0s` is vendored whole so the load that loses the composers loses the schema CLI in the same
breath, profile defaults merge from `defaults/Profile.lua` and are never read off the schema, and
`tests/test_degraded.lua` pins the full set, the degraded set and the composed delta by path rather
than by a single number. Nothing about the behavior changes; what changes is that it stops being
filed as a departure from a rule that now describes it.

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

None. On 2026-09-09 the last of fifteen breaches was peeled, and the census table that used to stand
here is gone with them — `layout-§1`'s terminal state for a repository with nothing over the cap is
nothing over the cap *and* no census, because a heading standing over an empty table is the graveyard
the rule warns about rather than evidence of anything.

`tests/test_layout_cap.lua` is what keeps that honest, and it reads the absence deliberately: a file
that crosses 1500 lines again turns the suite red naming the heading that has to come back with it,
and a table that outlives its last breach turns it red the other way. The gate was amended on
2026-09-09 to tell those two states apart; before that it failed in both directions at once, which is
the shape a gate takes when it was written for a repository that had never reached the state it was
driving toward.

What was peeled, and along which seam, is in the git history of that day — each of the seven source
files took the seam its own issue had already named, and the eight suites followed the modules they
mirror.

What remains worth knowing is the **1000–1500 on-notice band**, which is busier than it has ever
been: 19 files, six of them source, because a peel lands a file wherever its seam falls and a seam
chosen for what a reader can hold does not aim at a line count. The tightest is `tests/wow_mock.lua`
with 34 lines of headroom, and the one to watch is `modules/Row.lua` at 1442 — source, on the refresh
path, and the file every identity, spec-icon and pet-fold change has historically landed in.

**The band is tabulated in [complexity.md](complexity.md#the-10001500-loc-band), not here.**
`performance-§10` fixes that report to a single path and makes it the home for the watch list and the
band together, so this section carries the reading and that file carries the figures. Two copies of a
measurement stay equal only by there being one — which is the failure this whole cycle is a repair
for, in miniature.

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
`core/Compat.lua:624` and `modules/Window_Header.lua:78` both quote `UI-SortArrow-Up` while explaining that
it does not exist, `core/MediaSetup.lua:27` names the `Interface\AddOns\` prefix in the argument for
taking the folder name from the vararg, and `core/Namespace.lua:137` does the same. A comment naming
a texture is not a texture, so they are named here rather than given rows — and naming them is what
makes the subtraction from 19 checkable by a reader who runs the looser form.

| File | Path | Disposition |
|---|---|---|
| `core/Constants.lua` | `Interface\AddOns\MultiMeters\media\logos\multimeters.logo.tga` | The addon's **own shipped art**, which no icon catalog is meant to replace (`layout-§3`). The reasoning above the line is about the extension, not the hard-coding: `.tga` is the only form the client loads, and the `.png` master beside it is packaging. |
| `modules/Export_Modal.lua` | `Interface\Buttons\WHITE8x8` | The flat 1px fill `standalone-windows-§1` **mandates** for the shared window edge — a client primitive, not a mark, so outside what the catalog answers for. `LibKa0s/Core.lua:91,94` reaches for the same file for the same reason. Two sites, one path. |
| `modules/Minimap.lua` | `Interface\Icons\achievement_challengemode_gold` | **Pinned to the TOC.** `MultiMeters.toc:6`'s `## IconTexture` names this exact path, so the launcher and the AddOns-list entry are the same addon on sight; a catalog mark here would make them two. `library-stack-§8` sends a mark the catalog lacks **upstream** rather than into an addon, and there is nothing to send: the set is white-in-alpha by rule and this is the client's own colour art. |
| `modules/Row.lua` | `Interface\TargetingFrame\UI-Classes-Circles` | The client's **class atlas**, cropped by coordinate. The catalog carries no class art and `library-stack-§8` sends a missing mark upstream rather than into an addon — but twelve class circles are Blizzard's own data, not a Ka0s glyph, and they change when the game's classes do. |
| `modules/Row.lua` | `Interface\TargetingFrame\UI-StatusBar` | Last-resort bar fill after an LSM fetch answers nothing. The catalog **does** ship bar textures (`library-stack-§8`), and they reach LSM through `core/MediaSetup.lua`'s `RegisterLSM` — so the only load that reaches this line is one where the payload is absent and `NS.MediaTexture` answers nil too. A fallback that needs the thing that is missing is not a fallback. |
| `modules/Tooltip.lua` | `Interface\ICONS\INV_Misc_QuestionMark` | The client's canonical unknown-item mark, standing in for a spellID it cannot resolve. `library-stack-§8` has no equivalent and could not sensibly grow one: the whole point of this texture is that every WoW player already reads it as "missing", which is a meaning the client owns and a Ka0s glyph cannot borrow. |
| `modules/Tooltip.lua` | `Interface\ICONS\Ability_Hunter_FocusedAim` | The icon every TARGET line wears, and the second site where the catalog **does** have a candidate — `target`. A considered decline, not an oversight: this slot sits in a column of coloured Blizzard spell icons, and `library-stack-§8` requires catalog art to be white with its shape in the alpha channel, so the one line drawing a Ka0s glyph would be the one line that looked foreign. |
| `modules/Tooltip.lua` | `Interface\Buttons\WHITE8X8` | The fill `standalone-windows-§1` mandates, here as the bar fallback for a window with no texture configured — a `StatusBar` with no texture draws nothing, so a tint alone is not a fallback. The casing differs from the `modules/Export_Modal.lua` row and from nothing else; `LibKa0s` spells it both ways too (`Core.lua:91` / `Widgets.lua:44`), WoW paths are case-insensitive, and it is recorded here so nobody spends a commit "fixing" it. |
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

None. On 2026-09-09 the last of this addon's twenty-three warned functions came under CCN 15, and the
table that used to stand here went with them.

**What that table was for, and why it is not simply archived.** `performance-§10` makes the
complexity report a *report* — it says in as many words that a commit MUST NOT be gated on it — and
then asks the one thing that turns a page of numbers into a decision record: every function `lizard`
warns on carries a one-line disposition. This addon had twenty-three, which is the number anti-pattern
**#53** describes as the failure mode: a list where everything is accepted is an inventory, and an
inventory cannot tell you when something alarming arrives. The register answered that with eleven
peels and twelve accepts, each accept carrying the re-check trigger that would end it.

**All twenty-three came down, accepts included, and the reason is worth keeping.** An accept is a
compliant *watch-list* state and it is not a release gate. `automated-tests-§3` refuses a tag while any
function sits above CCN 15 — which is why this addon had never cut one — so a ratified accept would
have kept its function off the watch list and the addon off the version list at the same time. The
twelve were re-read rather than re-argued, and each turned out to be one of `performance-§11`'s
permitted shapes away from the line: a data table plus one loop for the `and`/`or` defaulting, a
module-level dispatch table for an `elseif` chain, a named helper for a block that already had a name.

**Two of them had already spent a trigger this repository wrote in its own hand.**
`docs/automated-tests/RESULTS.md`'s v0.1.0 watch list carried an *At the ceiling* table of four
functions at exactly CCN 15, written so "whoever next edits one knows there is **zero** headroom
left". By 2026-09-08 `Cell:ApplyBorder` read 30 and `WindowProto:BuildLayout` read 24. A trigger that
fires and is not acted on is the thing a register exists to catch, and it took a year and this cycle
to catch it — which is the argument for the register, not against it.

`tests/test_complexity_register.lua` still guards the shape, and reads this absence deliberately: it
holds vacuously over an empty table, and every one of its checks — that the stated tally matches the
rows, that each Location names a file that exists, that no function is entered twice, that every
disposition is followable — comes back the moment a row does. `lizard` is never run from the suite,
because `performance-§10` forbids gating a commit on complexity and a test that shelled out to it
would be that gate wearing a test's clothes. The measurement lives in `docs/complexity.md` and in each
run's `docs/automated-tests/<stamp>/complexity.txt`.

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
   `modules/Tooltip.lua`, its only caller. **Each of the eight `modules/` peels follows the parent it
   was cut from, and every one of those positions is load-bearing**: each resolves at *file scope*
   something its parent publishes, so a peel loading first captures nil and stays nil for the
   session. `modules/Export.lua` was the one file in the block whose position carried no constraint
   at all, and that is no longer true — `modules/Export_Modal.lua` reads `Export.__EM_DASH`,
   `Export.__cfgOf` and `Export.__channelRow` at file scope, so it must follow it.
10. The settings block opens with the three schema files in the order `settings/Schema_Compose.lua`
    → `settings/Schema.lua` → `settings/Schema_Paths.lua`, and each of the three positions is
    load-bearing for a different reason: the array resolves every `NS.SchemaCompose` member at *file
    scope*, the path seam builds its `path → row` index by walking `NS.Schema` at *file scope*, and
    `Slash.lua` and `OptionsSetup.lua` both point their seams at the `NS.SetByPath` / `NS.GetSetting`
    that `settings/Schema_Paths.lua` — not `Schema.lua` — publishes. That pins the path file from
    **both** sides, which is why splitting the schema took three files rather than two. Then
    `settings/OptionsSetup.lua` before every page file, which call `NS.Helpers` members inside
    schema-row literals at file load.
