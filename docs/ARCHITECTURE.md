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


The stat catalog, the eight statistics and the one this addon reads without cataloguing, what a
window owns, and the two features that are structurally impossible rather than merely unbuilt are
all in **[scope.md](scope.md)**. Which LibKa0s majors are consumed, which seam file reaches each and
what each degrades to are in [module-map.md](module-map.md#libka0s-seams).

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

**These edges are load-bearing, not an optimization** — there is no fallback poll, so a visibility
input with no edge on the bus is a rule that never fires. Why, and which rule it cost, is in
[module-map.md](module-map.md#game-event-edges-are-load-bearing). The three edges that exist because
of what a particular client has — the probed `PLAYER_IS_GLIDING_CHANGED`, the event-name filter, and
the settle pass over client state that lags its own event — are in
[midnight-quirks.md](midnight-quirks.md#client-version-workarounds-on-the-event-edges).

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
The two mechanisms coexist on purpose — see `modules/Export.lua`'s "The modal's three selectors"
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
- **What the data source does not carry.** A past death cannot be dated against its run; pet
  attribution has no owner link and is best-effort; the provider-order assumption is measured rather
  than proven.
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
| `compat-layer.md` | Every client API this addon shims: the `C_DamageMeter` and `C_DeathRecap` surfaces, the recap-discovery probe, the secret-safe number formatters, the icon-existence checks and the three player-context rules |
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
| `slash-dispatch.md` | Not applicable | **16 verbs in `NS.COMMANDS`.** Ten are the standard's reserved set, implemented entirely by LibKa0s-Slash-1.0 and documented by the standard. This addon's own surface is 6 verbs and one 4-entry sub-verb tree (`window`: list/new/delete/copy); `debug` takes 4 words, `perf` delegates its whole sub-surface to the library, and `export` takes one optional window name. The [Slash commands](#slash-commands) section carries all of it in a screen. |
| `message-bus.md` | Not applicable | **14 distinct messages**, all declared in one catalog (`core/Constants.lua` `MSG`) with the owning sender named beside each. Every payload is a flat table of one to two plain fields; none carries a handle, a curve object or a per-unit filter needing prose. The [Message bus](#message-bus) section carries sender, consumers and payload for all fourteen in one table. |
| `compat-layer.md` | Present | **`core/Compat.lua` is 761 lines and 28 shims** (8 of them `C_DamageMeter`, 4 death-recap, plus the recap-namespace probe `RecapMembers` / `RecapAPIs` / `CallRecap`), each a guarded namespace check around one passthrough, with no feature decisions, no state, and nothing there inspecting a meter value. The row read *re-measure — the trigger now fires* from the day this addon's Compat passed KickCD's, which ships the doc: 389 lines and 18 shims when the row was last written, 761 and 28 now. `documentation-§3` has since given the trigger a number — **three or more** addon-specific shims, counted over this file alone — which settles it at any reading. Written; registered under [Topic detail](#topic-detail). |
| `midnight-quirks.md` | **Present** | **At least one client-version workaround of the addon's own** — the trigger as §3 states it, and this addon carries four: the probed `PLAYER_IS_GLIDING_CHANGED`, `ADDON_RESTRICTION_STATE_CHANGED` registered against a namespace a client may not have, the settle pass over client state that lags its own event, and the secret-value model itself. It was read as Not applicable on the argument that a third copy of the secret-value rules would be the one that drifts — which was an argument against DUPLICATING them, not against the doc. The detail was MOVED here rather than copied: [Taint notes](#taint-notes) keeps the constraint, the operation lists and R1–R3, and nothing is stated twice. |
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
| layout §1 — no authored `.lua` over 1500 lines, `tests/` included | The **seven suites that mirror an over-cap module** — `tests/test_window.lua` (2737), `test_tooltip.lua` (2708), `test_row.lua` (1606), `test_aggregator.lua` (1605), `test_schema.lua` (1573), `test_diagnostics.lua` (1557), `test_export.lua` (1509) — stay over the cap and are **not** peeled on their own. The other eight breaches are not covered here: each has an open issue naming its seam (#27–#34). | **A mirror suite has no seam of its own.** Its partition is whatever partition its module ends up peeled on, and the two files already track each other closely enough that several banners are byte-identical — `modules/Window.lua:258` and `tests/test_window.lua:242` are both *Layout — rule R3 in one function*, `Window.lua:1997` and `test_window.lua:1208` both *Sorting from the column headers*, `modules/Row.lua:1119` and `test_row.lua:816` both *The name cell*, `core/Diagnostics.lua:1295` and `test_diagnostics.lua:343` both *The provider-order probe*. Peeling the suite first commits to a partition the module has not chosen yet; when the module later picks a different one, the result is two files that no longer pair, and `testing-§1`'s one-suite-per-module layout is what makes a red legible — you read the failing case name and you know which file to open. So the peel is real and it is scheduled: it happens in the module's own commit, on the module's own seam, which is also the only commit in which the moved cases can be re-pointed without guessing. Nothing here disputes that the cap binds test files — `layout-§1` is explicit that it does, and this addon is the repository whose 2026-09-07 audit filed against seven source files and none of its seven test files, which is the reading the standard was revised to end. | 2026-09-08 | The mirrored module is peeled, or its issue (#27–#33) reaches a terminal state — the suite peels along the same seam, in the same commit. A suite whose module drops under the cap without a peel loses its partner and peels on its own evidence instead. |
| library-stack §8 — "where the addon needs a mark it MUST use the catalog's" | `settings/ColumnBlocks.lua:72-73`'s column-block enable/disable glyph stays on Blizzard's `ReadyCheck-Ready` / `ReadyCheck-NotReady` pair, although `LibKa0s-Media-1.0` **does** carry `circle-check` and `ban`. This is the one site in the addon where the catalog has the mark and the addon declines it. | **Three reasons, and only the third is the one that binds.** (1) *Colour.* The catalog's art ships white with its shape in the alpha channel, because the collection tints by multiplying — so `circle-check` and `ban` would both draw white, and enabled-vs-disabled would be carried by shape alone where the pair on screen today carries it in green and red as well. Reconstructing that means a vertex colour per state, which is a second vocabulary for one signal rather than one fewer. (2) *Degradation.* `NS.Icon` answers **nil** on a load without the payload (`core/MediaSetup.lua`), and this glyph has no ladder beneath it the way `modules/HeaderControls.lua`'s art does — the block would lose its tick outright, where a Blizzard path is part of the client and cannot go missing. (3) *Parity, which is why the line exists at all.* These are the same two textures ConsumableMaster's priority list wears (`settings/StatPriority.lua`'s `INCLUDED_TEX`/`EXCLUDED_TEX`, with `modules/KCMItemRow.lua`'s `OWNED_TEX`/`NOT_OWNED_TEX` and `settings/Category.lua`'s `OWNED_ICON`/`NOT_OWNED_ICON` beside them — named rather than numbered, because no gate in this repository can follow a line number into another one and one of those three had already slipped a lane's worth of edits by the next morning), so a player running both reads one glyph vocabulary rather than two. Moving one addon alone does not reduce the deviation; it converts a shared vocabulary into a split one, which is strictly worse than the state being ratified here. The 2026-09-07 remediation plan reaches the same conclusion in as many words — the two sites "move in both repositories together or in neither", and filing the row in both is the other half of the same choice. This repository can only file its half. **Re-challenged 2026-09-08 and unchanged.** The item's acceptance asks for two things at once — both named sites on `NS.Icon`, *and* MultiMeters' parity comment still true — and from inside this repository alone the two are not simultaneously satisfiable while ConsumableMaster's three sites stand: the move that meets the first clause is what makes the second false. The finding the item traces to says so in its own words, offering "in MultiMeters and ConsumableMaster together, **or** file the register row in both" (`MM-A-07` in `docs/audits/2026-09-07/`), and this is that second branch taken deliberately rather than a site left unvisited. LootHistory's half of the same item shipped meanwhile and settles reasons (1) and (2) on the record rather than in argument — its `NS.IconMarkup` carries the state colour in the escape's own vertex fields and keeps the Blizzard path underneath as the fallback rung — which is why the row has always said only the third reason binds. | 2026-09-08 | ConsumableMaster's three sites adopt the catalog, or its priority list is retired — at which point the parity argument has no second half and this pair moves in the same cycle it does. Reasons (1) and (2) are answered upstream instead and each retires this row on its own: a `LibKa0s-Media-1.0` that publishes a tinted state pair, or an `NS.Icon` contract that carries a Blizzard fallback. |

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

`layout-§1` caps every **authored** `.lua` this repository tracks at 1500 lines — `tests/` included,
with vendored code (`libs/`, `tests/_kit/`) the only carve-out that reaches anything here; nothing in
this repo is generated non-shipping data, so the second carve-out has no instance. It gives a file
over the cap three terminal states: peeled, an open issue naming the seam a peel would follow, or a
ratified row in the register above carrying a re-check trigger. What it does not allow is a breach
nothing anywhere remarks on — "the count sitting in a bundle manifest that no document reads". This
table is the remark, and it is why an audit **MUST NOT** re-file `layout-§1` against any file in it.

One file, measured 2026-09-09 with

```
git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn
```

| File | Lines (2026-09-09) | Disposition |
|---|---|---|
| `tests/test_tooltip.lua` | 3054 | Issue [#28](https://github.com/tusharsaxena/MultiMeters/issues/28) — peels behind `modules/Tooltip.lua`, three ways, along the seam that file took |

**The line counts are dated because they drift, and nothing asserts them.** What
`tests/test_layout_cap.lua` asserts is the *membership* of this table, in both directions: a file that
crosses 1500 and is not listed here turns the suite red, and so does a row for a file that has fallen
back under the cap or been deleted. A figure in this column is a measurement, not a claim about today.

**Everything else is peeled, which is why this table is one row rather than fifteen.** The seven
source files went first, each along the seam its own issue had already named, and the suites followed
the modules they mirror — `tests/test_window.lua` 3159 → 1240 behind `Window_Header` and
`Window_Placement`, `tests/wow_mock.lua` 2270 → 1466 with the secret simulator and the frame model out
to `mock_secrets.lua` and `mock_frame.lua`, `tests/test_diagnostics.lua` 1838 → 432 with one suite per
probe. A test file's seam is not its own to choose: it follows the module's, so a reader who opens
`modules/Tooltip_Builders.lua` knows which suite covers it.

**The 1000–1500 band is on notice, not in breach.** It is now the busiest it has been, because a peel
lands a file wherever the seam puts it and several landed high: `tests/test_window_header.lua` (1421),
`tests/wow_mock.lua` (1466), `tests/test_row.lua` (1456), `settings/Schema.lua` (1350),
`tests/test_provider.lua` (1359), `settings/Schema_Compose.lua` (1285), `tests/test_export.lua` (1275),
`tests/test_aggregator.lua` (1255), `tests/test_window.lua` (1240) and `tests/test_database.lua` (1121).
A file at 1456 has 44 lines of headroom, and the band exists so that whoever next edits one knows it.

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
| `modules/Export_Modal.lua` | `Interface\Buttons\WHITE8x8` | The flat 1px fill `standalone-windows-§1` **mandates** for the shared window edge — a client primitive, not a mark, so outside what the catalog answers for. `LibKa0s/Core.lua:91,94` reaches for the same file for the same reason. Two sites, one path. |
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

**Measured 2026-09-08 at `8ff9335`**, with the invocation `performance-§10` fixes and which this
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

- **A method is reported under its receiver.** `Cell@659-739` is `Cell:ApplyBorder`,
  `Cell@1168-1244` is `Cell:ApplyIcons`, `WindowProto@312-413` is `WindowProto:BuildLayout`,
  `Tooltip@2342-2404` is `Tooltip:CellTooltip`, `DrillDown@395-428` is `DrillDown:OnCellClick`.
- **A `t[k] = function` assignment is reported as `]`.** All three `core/Database.lua` entries are
  migration steps: `migrations[1]`, `migrations[4]`, `migrations[12]`.
- **`(anonymous)@1968-2039` is not anonymous and does not start at 1968.** The parser opens the entry
  at the `function(_, event)` handed to `Secrets.SafeIterate` and closes it at the `end` of the
  enclosing function, so callback and host are reported as one row under the callback's name and with
  the callback's parameter count. The function is `drawDeathEvents@1957-2039`, and it appears nowhere
  else in the output.

**Two of these rows cannot carry a disposition forward, and that is why this table is the home of
record rather than `RESULTS.md`.** The kit's runner keys the watch list on function name plus file,
falling back to CCN to break a tie, and leaves the cell blank when neither key is unique
(`tests/_kit/run-automated-tests.sh:537-556`). Its comment names this addon, but for the tie the CCN
*does* break — `Cell` twice in `modules/Row.lua`, at 30 and 19 — so read past it to the last line,
"a tie the CCN cannot break either leaves the cell blank", which is the one that binds here. Three
rows are `]` in `core/Database.lua`, none of them unique on name plus file. `migrations[4]` is CCN 17
and the tie-break carries it forward. `migrations[1]` and `migrations[12]` are both CCN 16 — those
two are indistinguishable on both keys and will read blank on every run that regenerates them,
forever. Their disposition exists here or nowhere.

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
| `onPrintToChat` | 16 | `modules/Export.lua:1432-1497` | **Accepted.** Four refusals, each with a recorded reason and each asked at the click because the answer changes between opening the modal and pressing the button, then a linear send. One point over. Re-check: a fifth refusal, or CCN 20. |
| `Feign.Prune` | 25 | `modules/Feign.lua:247-337` | **Peel** — [#37](https://github.com/tusharsaxena/MultiMeters/issues/37). The `unit == nil` fork: the member who left the group and the member whose health is read are two verdicts, and the function's own comments already treat them as separate findings. |
| `Format.DeathTime` | 19 | `modules/Format.lua:646-665` | **Accepted.** 15 NLOC at CCN 19 is `performance-§10`'s own documented artefact in its purest form: every `or` fallback scores as a decision and not one of them branches. Re-check: a third style beyond `clock` and `ago`. |
| `onClick` | 24 | `modules/HeaderControls.lua:322-372` | **Peel** — [#38](https://github.com/tusharsaxena/MultiMeters/issues/38). A seven-way `elseif` on the control name, sharing no state across arms; a module-level dispatch table is the shape `performance-§11` permits, built once rather than per click (#52). |
| `build` | 20 | `modules/Roster.lua:249-366` | **Accepted.** One unit walk with three outputs, and the header says why it is not three walks; the count is `unitExists` / `IsSafeKey` guards plus the nested pet read. Re-check: a fourth output joins the walk, or the pet lookup grows a second kind — then the per-unit body peels to `addMember`. |
| `Cell:ApplyBorder` | 30 | `modules/Row.lua:659-739` | **Peel** — [#39](https://github.com/tusharsaxena/MultiMeters/issues/39). Its own comment names the seam — the art path and the flat path are mutually exclusive — and the per-side anchor chain under it is a data table. **Its ceiling row's trigger has fired**: 15 → 30. |
| `Cell:ApplyIcons` | 19 | `modules/Row.lua:1168-1244` | **Accepted.** The slot array is `{ "unit" }` or `{}` today, so the loop is degenerate and what remains is defaulting and the left/right mirror. Re-check: a second slot returns — [#8](https://github.com/tusharsaxena/MultiMeters/issues/8) would do it — at which point the loop is real and the peel is worth taking. |
| `eventColumns` | 19 | `modules/Tooltip.lua:1866-1919` | **Accepted.** A name-resolution ladder over one recap event where each arm is a documented client behaviour: a melee swing carries no spell at all, a heal names none, an unnamed spell shows its id rather than being dropped. Re-check: a fourth event kind. |
| `drawDeathEvents` (`(anonymous)`) | 26 | `modules/Tooltip.lua:1957-2039` | **Peel** — [#40](https://github.com/tusharsaxena/MultiMeters/issues/40). Collect, measure, draw are already three phases in sequence; the measuring pass carries all of the `namesReadable` bookkeeping and none of the drawing. See the parser note above before opening the file. |
| `Tooltip:CellTooltip` | 20 | `modules/Tooltip.lua:2342-2404` | **Accepted.** Linear composition — release, open, header, style, one Deaths/spell branch, five appends, then `Show` and the two fixups that must follow it. The count is defaulting; there is no tangle here to peel. Re-check: a third path joins the Deaths/spell branch. |
| `Visibility.ShouldShow` | 23 | `modules/Visibility.lua:239-276` | **Peel** — [#41](https://github.com/tusharsaxena/MultiMeters/issues/41). Eight copies of one line in 21 NLOC; a module-level `{ flag, probe, reason }` table and one loop is `performance-§11`'s permitted shape, and it makes the veto **order** — which the comment says is the point — data rather than line position. |
| `WindowProto:BuildLayout` | 24 | `modules/Window.lua:312-413` | **Peel** — [#42](https://github.com/tusharsaxena/MultiMeters/issues/42). The middle third: the visible-column filter, the equal share and the placement loop. Rule R3 is the constraint on the peel — config in, numbers out, no frame read back. **Its ceiling row's trigger has fired**: 15 → 24. |
| `place` | 18 | `modules/Window.lua:1283-1415` | **Peel** — [#43](https://github.com/tusharsaxena/MultiMeters/issues/43). 133 lines and 5 parameters, and create-once-then-dress is the split `LIBKA0S-R-01` already cut in the library's `TabStrip`. Being a closure over the enclosing method is the work, and the reason it is worth more than CCN 18 suggests. |
| `NS.ReorderableBlocks` | 28 | `settings/ColumnBlocks.lua:227-322` | **Peel** — [#44](https://github.com/tusharsaxena/MultiMeters/issues/44). The loop body is doing three jobs — draw the block, register the row, draw the boundary rule — and everything outside it is one refusal and a descriptor. |
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
prose. What re-measures them is the runner: `M5-01` ran it, and
[`20260908-181355`](automated-tests/20260908-181355/) is the recorded reading this table was last
reconciled against — the same 23 functions in the same order at the same 23 CCN values.

**A Location range goes stale the moment anything above it moves, and nothing here goes red when it
does.** That is the cost of the paragraph above, and it is why the commit is named: `8ff9335` is
where these ranges resolve, and at any later commit they are a starting point rather than an
address. Re-derive them with the one invocation at the top of this section — it takes seconds — and
correct the column in the same change rather than leaving a register that names its own measurement
commit and is wrong about it.

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
