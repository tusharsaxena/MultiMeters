# Architecture

Orient-yourself map for **Ka0s Multi Meters**. A single-frame, multi-column group meter for Retail
(Midnight, 12.x): one row per group member, one column per statistic, each cell a `StatusBar` with a
`FontString` on it. Every number is read from Blizzard's built-in damage meter through
`C_DamageMeter`; the addon never parses the combat log.

This file is the hub. Topic detail lives in `docs/` and is linked from each section — a section here
that outgrows a screen belongs in its topic doc with a summary and a link left behind.

## Overview


Sixty-one non-vendored source files: 1 locale, 20 `core/`, 1 `defaults/`, 24 `modules/`, 15 `settings/`.

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


The stat catalog, the eight statistics and the one this addon reads without cataloging, what a
window owns, and the two features that are structurally impossible rather than merely unbuilt are
all in **[scope.md](scope.md)**. Which LibKa0s majors are consumed, which seam file reaches each and
what each degrades to are in [module-map.md](module-map.md#libka0s-seams).

## Module map

Every file — all fifty-eight of them — what it owns, what it publishes, what it consumes, plus TOC
load order and the AceAddon lifecycle: **[module-map.md](module-map.md)**. The shape at a glance:

| Layer | Files | Responsibility |
|---|---|---|
| `locales/` | `enUS.lua` | `NS.L`, with the key-is-the-string fallback. Loads first. |
| `core/` boundary | `Compat.lua` | All 30 cross-patch shims, including the eight `C_DamageMeter` reads and the chat export's `ChatSender`. Four of them, the spell and spec readers, are bound to `LibKa0s-Compat-1.0` and answer `nil` without it. No logic. |
| `core/` boundary | `EnvSetup.lua` | The `LibKa0s-Env-1.0` seam: `NS.Meta` / `NS.Version`, the TOC-manifest reader `Compat.lua` used to own. |
| `core/` values | `Constants.lua`, `Namespace.lua`, `State.lua` | The stat catalog, the bus catalog, identity, session-only flags and the shared cache. |
| `core/` the rule | `Secrets.lua` | **The only file that inspects a meter value.** Its guards `IsSecret` / `CanAccess` / `IsSafeKey` are `LibKa0s-Compat-1.0`'s, with a guard arm that re-implements each body when the library is absent. |
| `core/` seams | `MediaSetup`, `CoreSetup`, `LifecycleSetup`, `PerfSetup`, `DebugLogSetup`, `PoolSetup`, `LauncherSetup` | LibKa0s wiring, the art and font seam, and the window row pool. `LifecycleSetup` is the ONE latch and the ONE teardown — `disabled` and `perf` are two holds on it — and it loads **before** `PerfSetup`, which raises without a `lifecycle`. The `LSM30_Border` fixup that used to make a seventh file here is `lib.__PatchLSM30Border()` now, called from `settings/OptionsSetup.lua`: AceGUI's widget registry is process-global, so a re-registration belongs to the library the whole collection shares. `LauncherSetup` hands `LibKa0s-Launcher-1.0` the descriptor for the one LDB object. The library owns the clicks and draws the status tooltip and, since Launcher minor 4 (`launcher-§2`, v2.67.0), the options menu: left-click opens the settings panel, right-click opens the menu (Enabled · Locked · Test mode · Show window). The descriptor only answers: `version`, and four accessor-and-toggle pairs whose toggles are the `enable`/`disable`, `lock`, `test` and `toggle` verbs' own `NS.COMMANDS` handlers. No host tooltip lines. |
| `core/` runtime | `MultiMeters.lua`, `Database.lua` | The single game-event listener and the show ladder; AceDB and migrations. |
| `core/` diagnostics | `Diagnostics.lua` + `Diagnostics_Runtime`, `Diagnostics_DeathRecap`, `_Identity`, `_Feign` | `/mm diagnostics`, its addon-state sections (`_Runtime`), and the three per-issue probes hung off it. Each probe is self-contained so it can be deleted with the issue it answers. |
| `defaults/` | `Profile.lua` | The window template. The only place a profile default is hardcoded. |
| `modules/` data | `Provider`, `Roster`, `Feign`, `Aggregator` (+ `_Identity`, `_Preview`), `Format` | Read → join → order → render as text. `Feign` is the one source row the addon deliberately discards; `Aggregator_Identity` is the grid drawn while the GUID is secret. |
| `modules/` display | `WindowManager`, `Window` (+ `_Lifecycle`, `_Header`, `_Placement`), `HeaderControls`, `Row` (+ `_Border`, `_Cells`, `_NameCell`), `Targets`, `Tooltip` (+ `_Lines`, `_Builders`), `DrillDown`, `Visibility` | The registry, one window, one row, the enemy cross-reference, the two hover surfaces, the breakdown and the context predicate. The launcher left this block when it was adopted from `LibKa0s-Launcher-1.0`: it is `core/LauncherSetup.lua` now, a seam like the other six rather than a module of its own. |
| `modules/` output | `Export`, `Export_Modal` | The segment a window is pointed at, as CSV or as ranked chat lines — the pure half and the dialog that drives it. Calls no meter API: it asks the aggregator, exactly as a window does. |
| `settings/` | `Schema_Compose` → `Schema` → `Schema_Paths`, `Slash`, `OptionsSetup`, `ColumnBlocks` + 3 pages and 6 Windows-page entries | One schema drives the panel, the CLI and the defaults reset: what the array is composed from, the array, and the path and write seams. `ColumnBlocks` is the Columns entry's row, drawn into `LibKa0s-Widgets-1.0`'s `ReorderList`. |

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

`NS.Schema` in `settings/Schema.lua` is the single source of truth: **169 rows across 8 page keys**
(windows 1, frame 26, header 36, bars 29, tooltip 30, visibility 17, columns 8, general 22), each one
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

**The runtime is `LibKa0s-Schema-1.0` minor 2's** (issue #52): `settings/Schema_Paths.lua` builds
`NS.SchemaRuntime` from the rows, a window-aware `resolveRoot` and the announce, or a log-silent
[degradation stub](schema.md#the-degradation-stub) without LibKa0s. The write seam is `NS.SetByPath`
(its `Set`), batched by `NS.SetByPaths` (`SetMany`); the reader is `NS.GetSetting`. The panel and the
CLI both point at them: same validation, debug line, `CONFIG_CHANGED` and panel re-sync.

**The window-relative path model** is the one thing here that is not standard-issue. A window row's
path is relative (`window.frame.width`) and the seam resolves it against `NS.State.activeWindowId`,
which the settings panel's window picker moves, or against a window id the caller passes. The other
twenty-two rows keep absolute paths against `db.profile`, so moving one integer retargets **147**
rows ([schema.md](schema.md#the-window-relative-path-model) lists both sets).

Profiles carries **zero** rows: AceDBOptions' own tree, the one place `AceConfigDialog` is permitted,
and vetoed from reset-all ([profiles.md](profiles.md)). Columns carries eight
`window.columnHeader.*` rows beside its block editor, whose array is a hidden 170th row, [`window.columns`](schema.md#the-columns-row).

**The window registry has one writer** (`architecture-§5`), since no row can name a window's
existence. Its storage keys are `db.profile.windows` (entries carry their `id` and unique `name`) and
the id counter `db.profile.nextWindowId`. Its writer is `modules/WindowManager.lua` (`Create`,
`Delete`, `Duplicate`, `Rename`'s uniqueness check) with its helpers `Database.NextWindowId` and
`Database.EnsureWindowShape`. Its load pass is `Database.SeedWindows`, run only by `NS:RunMigrations`.
Rows inside a window stay the seam's even when the registry writes them, through the seam's optional
window id ([schema.md](schema.md#the-window-registry-and-its-writer)).

**Named non-setting state** (`architecture-§5`) is written outside the seam and needs no register
row. Each piece has one owner, and every writer is listed with the act that reaches it:

| Storage key | Class | Owner | Writers — and the act |
|---|---|---|---|
| `frame.position` in each `db.profile.windows` entry ([detail](schema.md#frameposition-is-named-non-setting-state)) | geometry only a drag determines | `WindowProto` (`modules/Window_Placement.lua`) | `WindowProto:SavePosition` (title-bar drag-stop); `WindowManager:ResetPosition` / `:ResetPositions` (General's *Reset position*, `/mm reset-positions`) put back the shipped center; `WindowManager:Create` (whole, via `NS.DefaultWindow`) and `:Duplicate` (its 24 px offset); `Database.EnsureWindowShape`'s backfill when `Create`, `Duplicate` or `CopyFrom` calls it |
| `db.global.roster` (`byGuid`, `pets`, `count`) ([detail](schema.md#dbglobal--account-wide)) | learned data | `modules/Roster.lua` | `build()` and its `linkPetOf`, recording every member and pet-owner link the live build sees (the lazy rebuild after a roster invalidation), and `count` beside them; past `4 * MAX_ROWS` members a complete build prunes every member not in the live group, with their pet links; `Roster.Forget` clears it on `METER_RESET`. **Bounded by that prune, not forgotten at login**: SM-06 (2026-09-24) saw the meter keep the previous fight's data (two Cleave Training Dummy segments, 1:09 with 128.8K damage and 1:13) across a full logout and fresh login, so a login forget would drop the owners of numbers still on screen. Every writer runs from a build or a bus message, both gone while stood down, so no game event writes it while disabled |
| `db.global.minimap`'s `minimapPos` ([detail](schema.md#minimap)) | a vendored library's own writes | `core/LauncherSetup.lua` (the descriptor's `minimap` closure hands LibDBIcon the table) | LibDBIcon, when the player drags the minimap button. `hide` is what the `global.minimap.shown` row stores (inverted), written through the seam by the row's own inverting `set` |
| `MultiMetersPerfDB` | recorded data a vendored library writes | `core/PerfSetup.lua` (hands LibKa0s-Perf the key) | LibKa0s-Perf's `P.Save` on `/mm perf finish`: appends, trims the ring to 10, discards an older schema |

**Sort, session type and the pinned segment are preferences, not a remembered view**: a header
click and the segment menu choose them, so the five `window.data.*` fields are hidden rows written
through the seam by window id; the pin's none is `NO_SEGMENT` (0) ([schema.md](schema.md#data)).

`NS.ValidateSchema()` proves every row's `default` equals `defaults/Profile.lua`'s. Panel behavior:
[settings-panel.md](settings-panel.md); persisted shape and migrations: [schema.md](schema.md).

## Message bus

Fourteen `AceEvent` messages, declared once in `core/Constants.lua`'s `MSG` catalog through
`LibKa0s-Bus-1.0`'s `Catalog`, are the only channel between modules. Each has **one sender**, and every
receiver that is not an AceAddon module owns a private target from `NS.NewBusTarget()`. The catalog
with sender, consumers and payload, the two `METER_RESET` paths and the stand-down record:
**[message-bus.md](message-bus.md)**.

## Slash commands

`/mm` and `/multimeters` dispatch `NS.COMMANDS` (`settings/Slash.lua`) through LibKa0s-Slash-1.0:
**19 verbs**, the thirteen reserved ones then this addon's six, plus the `window` sub-tree. A bare `/mm`
opens the settings panel. The verb table, the sub-tree, the `debug` words, the degraded behavior and
every refusal line: **[slash-dispatch.md](slash-dispatch.md)**.

### Disabled — total, and the slash surface is not

`slash-commands-§7`. Disabled means the addon is not running, and the command surface stays: all
thirteen reserved verbs answer and only the six feature verbs refuse, on one line naming `/mm enable`.
The gate and its live list: [slash-dispatch.md](slash-dispatch.md#disabled--total-and-the-slash-surface-is-not);
the teardown: [disabled-state.md](disabled-state.md).

## Event subscriptions


**`core/MultiMeters.lua` registers every game event this addon listens to, and no other file
registers any.** Each handler does the minimum translation and republishes onto the bus; none reads a
value and — with two stated exceptions, the feign filter and the system-message filter below — none
decides anything, which is what lets that section be read as a wiring diagram.

Every registration goes through `NS.SafeRegisterEvent` (`core/CoreSetup.lua`, LibKa0s-Core minor 8,
`events-frames-taint-§1`), walked off the module-level `EVENTS` array, so one name the client does
not know costs only itself and lands in `NS.State.rejectedEvents`, which `/mm diagnostics` prints.

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
tick is the separate `refresh` bucket. `OnSpellSucceeded` and `OnSystemMessage` carry their own
top-level buckets, `spellEvent` and `systemEvent`: measurement only, so a capture can say whether
their all-session registration is worth narrowing (MultiMeters-R-17).

The player-state block exists for `modules/Visibility.lua`'s rules and carries **no payload**,
because those rules read their inputs live at the moment they are asked.

**These edges are load-bearing, not an optimization** — there is no fallback poll, so a visibility
input with no edge on the bus is a rule that never fires. Why, and which rule it cost, is in
[module-map.md](module-map.md#game-event-edges-are-load-bearing). The three edges that exist because
of what a particular client has — the newest-of-the-set `PLAYER_IS_GLIDING_CHANGED`, the event-name filter, and
the settle pass over client state that lags its own event — are in
[midnight-quirks.md](midnight-quirks.md#client-version-workarounds-on-the-event-edges).

Everything else is a bus subscription. Registration by module is tabulated in
[module-map.md](module-map.md#what-each-file-publishes-and-consumes).

Perf buckets, declared in `core/PerfSetup.lua` with their nesting: `meterEvent` · `spellEvent` ·
`systemEvent` · `refresh` (→ `aggregate` → `providerRead`, `render` → `renderRow`) · `tooltip`
(→ `targets` → `providerRead`).
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
  anchored to it. There is not one `GetPoint` / `GetWidth` / `GetLeft` in `modules/Row.lua`, in
  `modules/Row_NameCell.lua`, the name cell peeled out of it, in `modules/Row_Border.lua` or in `modules/Row_Cells.lua`; a window keeps drag and resize on a
  bare `inst.anchor` frame that never holds a value.

Two consequences worth stating once, because both look like bugs: **percentage text slots go quiet in
combat** (a percentage is a division), and **a pet keeps its own row rather than being summed into its
owner's while restricted** (a sum is arithmetic, and the native formatter renders but does not sum).
The second is why the scoring feature is deferred — [scope.md](scope.md#deferred-scoring).

The rest of the model — secret GUIDs out of the unit API, what R3 buys when it runs the other way,
why an export refuses entire rather than degrading, and why secrecy keys off `Combat` rather than
`ChallengeMode` — is in **[midnight-quirks.md](midnight-quirks.md)**.

## The segment selector

The header strip's **segment control** pins a window to one session the client still holds. The
pin is `window.data.sessionID` (`Constants.NO_SEGMENT` when none), read through
`Database.PinnedSegment`; every read path honors it, a stale pin is dropped at the top of the refresh,
and `modules/Provider.lua` stays the only caller of `C_DamageMeter`. The menu, the threading and why
this control keeps a context menu rather than a dropdown are in
**[data-flow.md](data-flow.md#the-segment-selector)**.

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
- **A bus with no library.** On an install missing `libs/LibKa0s`, `NS.NewBusTarget()` still hands
  every receiver a private target, but through the untracked-target stub (`options-ui-§1`), which
  records nothing. A disable there leaves bus-target registrations live. The game events are still
  unregistered at their one listener, so little is ever sent to them. The same install has already
  lost the options toolkit, the slash dispatcher and the latch, and says so in chat.

**The tooltip is the one thing this addon positions itself**, and that one `SetPoint` onto a cell
with secret geometry is the only call in the addon that could raise inside Blizzard's own code while
tainted by us. It is `pcall`'d; a failure leaves the `SetOwner` token's placement standing.

## Documentation map

Every `.md` under `docs/` appears in exactly one of the four tables below (`documentation-§3`).
**A store gets one row; its dated bundles get none.** `docs/automated-tests/` and
`docs/perf-analysis/` register their live docs — the README that says how a bundle is produced and,
for the automated-test record, the `RESULTS.md` the runner rewrites — and nothing else under them;
the dated folders beside those files are frozen evidence, and evidence is not registered.
`docs/revendor/` and `docs/superpowers/` are frozen through and through and get one row apiece.

The two stores' READMEs do **not** land in the same table, and that is the standard's own
classification rather than an inconsistency here: `automated-tests/README.md` is an unconditional
member of `### Verification and record`, while `perf-analysis/README.md` is the one member of that
group that is *also* a Tier 2 doc with a stated trigger, so `documentation-§3` sends it to
`### Conditional` — the only table with the Status and Trigger columns that can express the state.
The trigger decides the table.

`docs/issues/` used to hold image evidence attached to GitHub issues — GitHub's API has no supported
path for uploading an issue attachment, so a raw link to a committed file is the only way a
screenshot reaches one. **The directory is gone.** An issue's images are deleted when it closes and
its links are re-pointed at the commit that last carried them, which keeps resolving forever without
the repo carrying the weight; issue #1's are pinned to `dcb29ad`. Re-create it only when an open
issue needs a picture, and expect it to empty itself again.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `ARCHITECTURE.md` | This file — the hub: overview, module map, schema, bus, slash, events, taint, limitations, this register, deviations |
| `scope.md` | What the addon does and deliberately does not, including why scoring cannot be computed in combat |
| `module-map.md` | Every non-vendored file, its responsibility, TOC load order, the AceAddon lifecycle |
| `schema.md` | The persisted shape, every default, and the migration seam |
| `settings-panel.md` | The three pages (the Windows page carries seven entries on a nav rail), per-option behavior, and the write seam |
| `data-flow.md` | `C_DamageMeter` → pixel, and the secret-value rules that shape every hop |
| `common-tasks.md` | Recipes for the changes made most often here |

### Conditional (documentation-§3, Tier 2)

Each trigger was measured against the source, not assumed, and the measurement stays on the row
whichever way it came out — so a later audit can re-run it rather than re-argue it. **All seven
ship**, and each row carries the count that decided it, so the number is what a re-check reads, not
the verdict beside it.

| Doc | Status | Trigger, as measured |
|---|---|---|
| `perf-analysis/README.md` | Present | **The performance harness is wired** — `core/PerfSetup.lua` plus `Perf` brackets in eight modules (`performance-§12`). The doc says what a recorded in-game capture bundle is and how to produce one; `docs/perf-analysis/20260909-014604/` is the standing example. |
| `compat-layer.md` | Present | **`core/Compat.lua` is 770 lines and 30 shims** (4 of them the spell and spec readers bound to `LibKa0s-Compat-1.0` since LibKa0s v1.55.0, 8 of them `C_DamageMeter`, 4 death-recap, plus the recap-namespace probe `RecapMembers` / `RecapAPIs` / `CallRecap` the bar-animation read `BarInterpolation` and the chat sender `ChatSender`), each a guarded namespace check around one passthrough, with no feature decisions, no state, and nothing there inspecting a meter value. The row read *re-measure — the trigger now fires* from the day this addon's Compat passed KickCD's, which ships the doc: 389 lines and 18 shims when the row was last written, 777 and 29 at the v1.55.0 adoption, 746 and 29 after it (`wc -l core/Compat.lua`; the four readers kept their names), and 770 and 30 once `ChatSender` took the chat export off the deprecated global. `documentation-§3` has since given the trigger a number — **three or more** addon-specific shims, counted over this file alone — which settles it at any reading. Written, and registered on this row. |
| `midnight-quirks.md` | Present | **At least one client-version workaround of the addon's own** — the trigger as §3 states it, and this addon carries four: the isolated event registrations (the newest, `PLAYER_IS_GLIDING_CHANGED`, the likeliest refused), `ADDON_RESTRICTION_STATE_CHANGED` registered against a namespace a client may not have, the settle pass over client state that lags its own event, and the secret-value model itself. It was read as Not applicable on the argument that a third copy of the secret-value rules would be the one that drifts — which was an argument against DUPLICATING them, not against the doc. The detail was MOVED here rather than copied: [Taint notes](#taint-notes) keeps the constraint, the operation lists and R1–R3, and nothing is stated twice. |
| `debug.md` | Present | The console is `LibKa0s-DebugLog-1.0`'s window; this addon's own surface is the diagnostics report (`/mm diagnostics`, `debug-logging-§14`), the three probe verbs, the `tooltip` channel flag and the eighteen `NS.Debug` channels. **Written 2026-09-09, when this row's own re-check trigger fired.** It had read "Not applicable — print statements with no state and no options for a doc to describe", which was true until `/mm debug tooltip` added a session flag on `NS.State`. The trigger was recorded on the row and the doc followed in the same changeset. |
| `slash-dispatch.md` | Present | **19 verbs in `NS.COMMANDS` and a sub-command tree**, against a trigger of eight or more commands or any sub-command tree. Thirteen verbs are the standard's reserved set (`diagnostics` joined it with standard v2.68.0); this addon's own six include `window` with its four sub-verbs (list/new/delete/copy), `debug` takes seven words, and `export` an optional window name. The row used to waive it as "carried in a screen", which the trigger does not accept; the hub's `## Slash commands` section was MOVED into the doc (2026-09-24, MultiMeters-A-03) and a summary and link left behind. |
| `message-bus.md` | Present | **14 distinct messages**, against a trigger of more than ten. All are declared in one catalog (`core/Constants.lua` `MSG`) with one sender each. The row used to waive it as "one table carries it", which the trigger does not accept; the hub's `## Message bus` section was MOVED into the doc (2026-09-24, MultiMeters-A-03) and a summary and link left behind. |
| `profiles.md` | Present | **User-visible profiles**: `settings/Profiles.lua` registers AceDBOptions-3.0's tree as a settings page. The row used to waive it as "no profile semantics of its own"; the trigger is the visible profiles, not the semantics. The Profiles page moved in from settings-panel.md and the lifecycle from schema.md (2026-09-24, MultiMeters-A-03), with the `PROFILE_CHANGED` fan-out, the reset-all veto, the global-vs-profile split and the migration runner's every-profile rule beside them. |

### Verification and record (documentation-§3)

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page: buckets, offline scenarios, the in-game A/B |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated by the runner, never hand-edited apart from the watch list's `Disposition` column (automated-tests-§4) |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `disabled-state.md` | What *disabled* means here — the one latch, its two holds, the full teardown and rebuild, what survives because it is setup, and the slash and launcher surfaces while the addon is off |
| `texture-paths.md` | The hard-coded texture-path census (`library-stack-§8`): every `Interface\` path in authored source, its disposition, and the command that measures it |
| `superpowers/` | Tier 3 planning history, frozen — the approved design specs and build plans behind each feature, under `specs/` and `plans/`, dated and never revised after the fact |
| `revendor/` | Frozen — one dated bundle per LibKa0s re-vendor: the payload delta and what was adopted, declined or filed from it |
| `audits/` | Frozen — one dated bundle per `/wow-addon:standards-audit` run: the state, the deviations and the evidence as they stood on that date |
| `reviews/` | Frozen — one dated bundle per `/wow-addon:review` run: the findings, the proposed changes and the plan as they stood on that date |

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
| `debug-logging-§8` — each recompute logged "as a single summary line" | A refresh pass whose summary line is **unchanged** from the previous pass is not logged. The line is emitted on every *change*, plus a heartbeat at most every 10s carrying `(xN)` for the passes it stood for. | `throttle = 0.25` is four passes a second, each emitting an `[Aggregator]` and a `[Render]` line (three while restricted) into a buffer then capped at 500 lines (`debug-logging-§1`) — **the console held 40 seconds**. (Measured 2026-08-21 against the cap of the day; LibKa0s v1.15.0 raised it to 1500, which buys two minutes rather than forty seconds, and v1.60.0 to 3000, the figure `debug-logging-§9` now quotes, which buys four and evicts the console just the same.) A live capture showed one identity line repeating byte-identically for 41 seconds: ~160 passes, ~480 lines, one string, evicting every other line in the buffer. That is the harm `debug-logging-§9` names ("it **evicts** it") arriving by a route §9 does not cover: §9 bounds *per-item* emission and says nothing about a pass repeating unchanged on a timer. A change is never delayed and never dropped, so nothing a reader wants is what goes missing. Implementation and reasoning: `core/DebugLogSetup.lua` → the steady-state sink. | 2026-08-21 | debug-logging gains a rule for repeating timer-driven passes — the gap is general to any Ka0s addon with a refresh timer, so the standard is the right long-term home and this row retires the day it lands. |
| `options-ui-§17` — every color picker carries a "use class color" companion | `window.header.bgColor` — the title bar's own background — ships with **no** companion. Every other non-palette swatch in the addon has one. | Neither answer a companion could give is true of this surface. The title bar is **one strip spanning the whole window**, so "per statistic" could only ever mean the sort column's color — a fact already on screen twice, in that column's own header and in its arrow — and that is the same argument that took the mode off the title bar's *text* background and off the divider's `stat` option. The strip beside it, the column-header background, **does** keep a mode, and the difference is the point: that one labels the columns, so per-statistic tints each label with its own column's color and means something (`settings/Schema_Compose.lua`, the note above `window.columnHeader.bgColorMode`). A companion added here would be a control wired to a color nobody chose. | 2026-09-02 | The title bar grows a surface that belongs to one column or to one player — a per-row header, a sort-column tint on the strip itself — at which point "which class" and "which statistic" both have an answer and the row retires. |
| `options-ui-§17` — "one resolver": the class-color lookup is the library's | `NS.ClassRGB(classFilename)` (`core/Namespace.lua`) stays as a **second** reader of `RAID_CLASS_COLORS`, beside the library's `NS.ClassColor(unit)`. | The two answer different questions. `LibKa0s-Core-1.0`'s `ClassColor` takes a **unit token**; a meter row is a GUID and a `classFilename` out of `C_DamageMeter`, and most rows have no token at all — a player who left the group, an NPC in a damage-taken column, a follower-dungeon companion. Retiring `ClassRGB` in favor of the unit-keyed lookup would silently uncolor every one of them. The **surface** question — the window's chrome, its header, its backdrop and its border — does go through the library, via `NS.PlayerClassRGB`, which is the case the standard's clause is about; what stays private is the roster reader. Neither has a fallback the other lacks: the degraded reader in `core/CoreSetup.lua` calls `ClassRGB` too, so there is still exactly one table lookup in the addon. | 2026-09-02 | `LibKa0s-Core-1.0` grows a class-**filename** overload of `ClassColor` (or a sibling reader), at which point `ClassRGB` becomes the private copy the clause forbids and is deleted. |
| library-stack-§8 — "where the addon needs a mark it MUST use the catalog's" | `settings/ColumnBlocks.lua:72-73`'s column-block enable/disable glyph stays on Blizzard's `ReadyCheck-Ready` / `ReadyCheck-NotReady` pair, although `LibKa0s-Media-1.0` **does** carry `circle-check` and `ban`. This is the one site in the addon where the catalog has the mark and the addon declines it. | **Three reasons, and only the third is the one that binds.** (1) *Color.* The catalog's art ships white with its shape in the alpha channel, because the collection tints by multiplying — so `circle-check` and `ban` would both draw white, and enabled-vs-disabled would be carried by shape alone where the pair on screen today carries it in green and red as well. Reconstructing that means a vertex color per state, which is a second vocabulary for one signal rather than one fewer. (2) *Degradation.* `NS.Icon` answers **nil** on a load without the payload (`core/MediaSetup.lua`), and this glyph has no ladder beneath it the way `modules/HeaderControls.lua`'s art does — the block would lose its tick outright, where a Blizzard path is part of the client and cannot go missing. (3) *Parity, which is why the line exists at all.* These are the same two textures ConsumableMaster's priority list wears (`settings/StatPriority.lua`'s `INCLUDED_TEX`/`EXCLUDED_TEX`, with `modules/KCMItemRow.lua`'s `OWNED_TEX`/`NOT_OWNED_TEX` and `settings/Category.lua`'s `OWNED_ICON`/`NOT_OWNED_ICON` beside them — named rather than numbered, because no gate in this repository can follow a line number into another one and one of those three had already slipped a lane's worth of edits by the next morning), so a player running both reads one glyph vocabulary rather than two. Moving one addon alone does not reduce the deviation; it converts a shared vocabulary into a split one, which is strictly worse than the state being ratified here. The 2026-09-07 remediation plan reaches the same conclusion in as many words — the two sites "move in both repositories together or in neither", and filing the row in both is the other half of the same choice. This repository can only file its half. **Re-challenged 2026-09-08 and unchanged.** The item's acceptance asks for two things at once — both named sites on `NS.Icon`, *and* MultiMeters' parity comment still true — and from inside this repository alone the two are not simultaneously satisfiable while ConsumableMaster's three sites stand: the move that meets the first clause is what makes the second false. The finding the item traces to says so in its own words, offering "in MultiMeters and ConsumableMaster together, **or** file the register row in both" (`MM-A-07` in `docs/audits/2026-09-07/`), and this is that second branch taken deliberately rather than a site left unvisited. LootHistory's half of the same item shipped meanwhile and settles reasons (1) and (2) on the record rather than in argument — its `NS.IconMarkup` carries the state color in the escape's own vertex fields and keeps the Blizzard path underneath as the fallback rung — which is why the row has always said only the third reason binds. | 2026-09-08 | ConsumableMaster's three sites adopt the catalog, or its priority list is retired — at which point the parity argument has no second half and this pair moves in the same cycle it does. Reasons (1) and (2) are answered upstream instead and each retires this row on its own: a `LibKa0s-Media-1.0` that publishes a tinted state pair, or an `NS.Icon` contract that carries a Blizzard fallback. |
| library-stack-§8 — "where the addon needs a mark it MUST use the catalog's" | `modules/Tooltip.lua:107` hard-codes `Ability_Hunter_FocusedAim` for the TARGET line's icon instead of the catalog's `target`. | A white alpha glyph in a column of colored spell icons reads as foreign ([texture-paths.md](texture-paths.md#the-census)). Ratified as MM-A-25's option (b); the owner's option (a), `NS.Icon("target")` with this path as the nil fallback, stays open. | 2026-09-23 | The catalog ships a colored or iconic variant of `target`, or the tooltip stops drawing spell icons. |
| library-stack-§8 — "where the addon needs a mark it MUST use the catalog's" | `modules/Window.lua:646-647` hard-code the chat `UI-ChatIM-SizeGrabber-Up` / `-Highlight` pair for the resize grip instead of the catalog's `resize`. | A two-state hover pair every player reads in each chat window, and the catalog publishes no hover variant, so adopting it would mean drawing one locally (MM-A-25, option (b)). | 2026-09-23 | `LibKa0s-Media-1.0` gains a hover variant of `resize`. |
| options-ui-§15 — the per-instance scale, alpha and lock stay on the instance's own page: "the two are different settings and MUST NOT be conflated" | Master controls' **Lock frame** (`master.locked`) is a view over every window's own `frame.locked`, not a separate addon-wide lock. It reads ticked only when every window is locked (`WindowManager:IsLocked`), and ticking or unticking it writes each window's own lock through `WindowManager:SetLocked`, the same switch as `/mm lock on` and `/mm lock off`. The row is `sessionOnly` and stores nothing; `core/Database.lua`'s v13 → v14 step carried a stored `master.locked = true` onto every window and pruned the key. A window's own padlock (its header, or Frame → Lock window) still locks that window alone. Master scale and Master alpha are unchanged and still compose with the per-window pair. | With a separate master lock ORed over the per-window locks, `/mm lock` set the per-window locks, and the Lock frame checkbox could then neither unlock the windows nor visibly lock them (owner-reported bug, 2026-09-16). The owner chose one switch over two. Implementation: the `master.locked` entry in `settings/Schema_Compose.lua`'s Master controls `dress()`, and `WindowProto:RefreshUpvalues` in `modules/Window.lua`. | 2026-09-16 | The standard defines a master lock that coexists with per-window locks without this trap, or MultiMeters drops per-window locks. |

**Retired on 2026-09-09: the seven mirror suites over the cap.** The register carried a `layout-§1`
row ratifying seven test files over the 1500-line cap, `tests/test_window.lua` (2737) down to
`tests/test_export.lua` (1509), on the argument that a mirror suite has no seam of its own and must
peel along whatever seam its module is peeled on. Its trigger was *"The mirrored module is peeled …
the suite peels along the same seam, in the same commit."* It fired: on 2026-09-09 every mirrored
module was peeled and each suite followed it, so a row for a state that no longer exists is retired
rather than re-dated. Worth keeping from it: the peel had to be the module's commit because the two
files track each other closely enough that a failing case name tells you which file to open, and the
peel kept that pairing.

**Retired on 2026-09-08: the composed blocks on a degraded load.** The register carried an
`options-ui-§15`/`§16` row for the schema a library-less install ends up with — the Master controls
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

Nothing is over the cap today. On 2026-09-09 the last of fifteen breaches was peeled, each source
file along the seam its own issue named and each suite behind the module it mirrors, and the census
table that used to stand here went with them. The heading stays and carries this sentence, because
`layout-§1` treats an empty census as a **result**: a heading with nothing under it cannot be told
apart from a census nobody wrote.

`tests/_kit/test_layout_cap.lua` (test-kit revision 25, vendored with LibKa0s v1.55.0) keeps that
honest, replacing the hand-written `tests/test_layout_cap.lua` this repository carried until then. A
file that crosses 1500 lines turns it red until a row naming the file and its terminal state is added
here, a row that outlives its breach turns it red the other way, and this section going blank or
losing its heading is red as well.

The **1000–1500 on-notice band** is busier than it has ever been, because a peel lands a file wherever
its seam falls. `modules/Window.lua` reached 1490 after the bound-slot render (review F-007) and was peeled
first, as ruled: the bus wiring and the lifecycle tail went to `modules/Window_Lifecycle.lua`,
leaving it at 1321. `modules/Row.lua` reached 1446 after its live-cell set and `Release` left for
`modules/Row_Cells.lua`, and was peeled again in the 2026-09-26 automated-tests sweep: the cell outline — the flat
edges, the edge-art backdrop and the per-row re-tint — went to `modules/Row_Border.lua`, leaving it
at 1226. It is still source, on the refresh path, and the file every identity, spec-icon and
pet-fold change has historically landed in. The band's figures are
tabulated in [automated-tests/RESULTS.md](automated-tests/RESULTS.md#files-by-layout-1-band), not
here: `automated-tests-§4` makes that one overwritten file their home, and two copies of a
measurement stay equal only by there being one.

### Hard-coded texture paths

The census of every hard-coded `Interface\` path in authored source, with a disposition per
file/path pair and the command that measures it, is **[texture-paths.md](texture-paths.md)**, and
`tests/test_texture_paths.lua` compares it with the tree in both directions. Its three
`library-stack-§8` declines of a mark the catalog does carry are ratified in the register above.

## Complexity register

None. On 2026-09-09 the last of this addon's twenty-three warned functions came under CCN 15, and the
table that used to stand here went with them.

`performance-§10` makes the complexity report a *report* that a commit MUST NOT be gated on, and asks
that every function `lizard` warns on carry a one-line disposition. The register answered its
twenty-three with eleven peels and twelve accepts, and then all twenty-three came down, accepts
included: an accept is a compliant *watch-list* state but not a release gate, and
`automated-tests-§3` refuses a tag while any function sits above CCN 15. Each of the twelve turned out
to be one of `performance-§11`'s permitted shapes away from the line. Two had already spent a trigger
this repository wrote itself (`Cell:ApplyBorder` and `WindowProto:BuildLayout`, on the v0.1.0 *At the
ceiling* list at CCN 15, read 30 and 24 by 2026-09-08), which is the argument for the register.

`tests/test_complexity_register.lua` still guards the shape and holds vacuously over an empty table;
each of its checks (the stated tally, a Location that exists, no function twice, a followable
disposition) comes back the moment a row does. `lizard` is never run from the suite, because a test
that shelled out to it would be the commit gate `performance-§10` forbids. The measurement lives in
`docs/automated-tests/RESULTS.md` and each run's `docs/automated-tests/<stamp>/complexity.txt`.

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
   `NS.Util.print`; and **first of the six seams that share the cause clause**, because it defines
   `NS.LIBKA0S_MISSING`.
7. `core/LauncherSetup.lua` **after `core/Constants.lua`**, whose `LOGO_128` its descriptor reads at
   *file scope*: `LibKa0s-Launcher-1.0` raises on a launcher with no icon, and one wearing nothing
   draws nothing and raises nothing (`launcher-§4`, anti-pattern #82). Everything else it names —
   `NS.db`, `NS.WindowManager`, `NS.OpenOptionsPanel` — is resolved at *call* time, so it is free to
   load before all three, and `Register()` runs from `OnInitialize` after `InitDB`.
8. `core/PerfSetup.lua` after `core/Namespace.lua` (a nil `version` stamps every capture record `v?`)
   and **before every `modules/` file that takes `local Perf = NS.Perf` as a load-time upvalue**.
9. `defaults/Profile.lua` after `core/Constants.lua`, whose stat catalog it captures at load.
10. `modules/Format.lua` first in the module block; `modules/Row.lua` resolves `Tooltip` and
   `DrillDown` at *call* time because both load after it. `modules/Targets.lua` loads before
   `modules/Tooltip.lua`, its only caller. **Each of the eleven `modules/` peels follows the parent it
   was cut from, and every one of those positions is load-bearing**: each resolves at *file scope*
   something its parent publishes, so a peel loading first captures nil and stays nil for the
   session. `modules/Export.lua` was the one file in the block whose position carried no constraint
   at all, and that is no longer true — `modules/Export_Modal.lua` reads `Export.__EM_DASH`,
   `Export.__cfgOf` and `Export.__channelRow` at file scope, so it must follow it.
11. The settings block opens with the three schema files in the order `settings/Schema_Compose.lua`
    → `settings/Schema.lua` → `settings/Schema_Paths.lua`, and each of the three positions is
    load-bearing for a different reason: the array resolves every `NS.SchemaCompose` member at *file
    scope*, the path seam builds its `path → row` index by walking `NS.Schema` at *file scope*, and
    `Slash.lua` and `OptionsSetup.lua` both point their seams at the `NS.SetByPath` / `NS.GetSetting`
    that `settings/Schema_Paths.lua` — not `Schema.lua` — publishes. That pins the path file from
    **both** sides, which is why splitting the schema took three files rather than two. Then
    `settings/OptionsSetup.lua` before every page file, which call `NS.Helpers` members inside
    schema-row literals at file load.
