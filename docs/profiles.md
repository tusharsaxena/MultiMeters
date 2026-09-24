# Profiles

> Ka0s Multi Meters. Part of the doc set mapped in
> [ARCHITECTURE.md](ARCHITECTURE.md#documentation-map). The hub's summary sits under
> [Settings schema](ARCHITECTURE.md#settings-schema).

A `documentation-§3` Tier 2 doc: this addon has user-visible profiles, so what a profile is here, how
the addon reacts when one changes and what a profile never holds live in this one place. The
Profiles page moved here from [settings-panel.md](settings-panel.md) and the profile lifecycle from
[schema.md](schema.md). Both leave a summary and a link behind.

## One shared profile by default

`AceDB:New("MultiMetersDB", NS.defaults, true)` passes `true` as the third argument, which AceDB
expands to the shared `"Default"` profile. Omitting it falls back to a **per-character** profile,
which contradicts the documentation and is the source of every "each new character lands on its own
settings" report in the collection. Players who want per-character opt in through the Profiles page.

## The Profiles page — the one place AceConfigDialog is permitted

`settings/Profiles.lua` registers AceDBOptions-3.0's own create / switch / copy / reset / delete
tree as the ninth settings page. It carries **zero** schema rows.

Every other page is drawn by `LibKa0s-Options-1.0` from `NS.Schema`, and AceConfig is not in the
picture at all. This page is the documented exception for one reason: **the options table is not
ours.** AceDBOptions generates it — every scope dropdown, every confirmation, every profile-list
refresh — and re-expressing that as schema rows would mean maintaining a copy of AceDB's own profile
model that goes stale the first time AceDB adds a scope.

The exception is scoped to **content**. The canvas, the header, the breadcrumb and the registration
are still `Helpers.CreatePanel`, so this page looks like the other eight rather than like a bolted-on
Ace window. An AceGUI `SimpleGroup` is parented to `ctx.body` and `AceConfigDialog:Open` targets it,
which lands the widgets inside this canvas instead of opening a second floating window over the
settings panel.

**It draws through `SetRenderer`, like every other page.** That is where its combat lock comes
from: the Blizzard AddOns sidebar reaches a canvas without going through `NS.OpenOptionsPanel`, and a
page carrying its own copy of the lock has one that drifts from the other eight the moment the
library's moves. This page hand-rolled that copy until the `CX03` sweep, and paid for it by being the
one page the library did not draw.

`SetRenderer` is one draw short here, though, and the shortfall is real: the widget tree belongs to
AceConfigDialog, which re-reads the active profile only when the dialog is fed again, so "draw once,
and again when the library says you are dirty" would show a profile switch made from the slash
command as a stale profile list. The page therefore takes a private bus target and calls
`H.RefreshPanel(ctx, true)` on `PROFILE_CHANGED` — the library's own seam for a page that repaints
off its host's message bus. Shown, it redraws now; hidden, it is marked dirty and redraws on its next
show. Changes made *on* the page need nothing: AceConfigDialog re-`Open`s the container itself after
every control it activates.

**No Defaults button.** "Restore defaults" on this page would mean deleting the player's profiles,
which is not what anyone means by restoring a default (`options-ui-§3`). The header button is
suppressed with `defaultsButton = false`. [The reset-all veto](#the-reset-all-veto) below is the
second enforcement.

## What a profile change does

`core/Database.lua` registers **one handler per AceDB profile event**, because the one debug line each
logs is worded by the event (`debug-logging-§10`):

```lua
db.RegisterCallback(Database, "OnProfileChanged", "OnProfileChanged")
db.RegisterCallback(Database, "OnProfileCopied",  "OnProfileCopied")
db.RegisterCallback(Database, "OnProfileReset",   "OnProfileReset")
```

| Event | Debug line |
|---|---|
| switch | `[Profile] switched to '<name>'` |
| copy | `[Set] copied profile '<source>' → '<name>'` |
| reset | `[Set] reset profile '<name>' to defaults`, logged after the rebuild and ending ` (stopped by an error)` if it raised |

All three share one `rebuild`. It runs `NS:RunMigrations()`, because the newly active profile may be a
copy authored at an older version or a reset back to an empty registry. It clears
`NS.State.activeWindowId` and wipes every session cache. It re-takes or releases the `disabled` hold
for the new profile's `enabled` (`slash-commands-§7`: a profile switch can flip it with no verb and no
checkbox touched). Then it fires **one** `PROFILE_CHANGED` message. `fireProfileChanged` is the single
emitter: every path that makes the active profile a different thing routes through it, so the bus
catalog names one site and stays true.

### The `PROFILE_CHANGED` fan-out

The payload is `{ newProfileKey }`. Every receiver rebuilds off the message rather than off a direct
call from `core/Database.lua` (`architecture-§4`):

| Receiver | What it does |
|---|---|
| `modules/WindowManager.lua` | Rebuilds the whole registry (`Init`) and refreshes every window: a swap replaces every config table |
| `modules/Visibility.lua` | Forgets its cached verdicts and re-evaluates |
| `modules/Roster.lua` | Treats it as a roster change and rebuilds lazily |
| `modules/Aggregator.lua`, `modules/DrillDown.lua` | Treat it as a meter reset; every drill-down exits |
| `modules/Format.lua`, `modules/Targets.lua` | Invalidate their caches, on private bus targets |
| `settings/Profiles.lua` | `H.RefreshPanel(ctx, true)`, on a private bus target (above) |

The full catalog is in [message-bus.md](message-bus.md).

## The reset-all veto

**General → Reset all settings is a profile reset.** It, `/mm resetall` and Profiles → Reset Profile
are the same act: `db:ResetProfile()` on the active profile only, which deletes the extra windows and
leaves one fresh one. Other profiles and the profile list are never touched.

**The Profiles page is vetoed from every sweep.** `settings/OptionsSetup.lua`'s `skipRestoreAll`
predicate refuses the page's rows (and, since reset-all became a profile reset, every other row the
profile stores) from `/mm resetall`, the General popup and the header Defaults sweep. The degradation
stub's own reset loop uses the same named predicate, so a profiles row is safe on both paths. Only the
`sessionOnly` rows are walked. The detail is in settings-panel.md, under
[Reset all settings vs Reset Profile](settings-panel.md#reset-all-settings-vs-reset-profile) and
[The two pages with no Defaults button](settings-panel.md#the-two-pages-with-no-defaults-button-and-why-each).

## What is per-profile and what is account-wide

**In the profile:** the window registry (`windows`, an array, and the `nextWindowId` counter), the
master `enabled` switch, the `master` controls, the addon-wide `data` settings and the remembered
`export` choices. A window's whole look lives inside its own entry, so a profile copy is a deep table
copy. The shape is in [schema.md → `db.profile`](schema.md#dbprofile--the-profile-tree).

**In `db.global`, shared by every profile:**

- `schemaVersion`. The migration stamp is account-wide (`savedvariables-§1`), not per-profile.
- `minimap`, LibDBIcon's table. Moved off the profile in v15, so switching profile does not move or
  hide the minimap button ([schema.md → `minimap`](schema.md#minimap--and-it-lives-under-global)).
- `roster`, the remembered roster. It is learned data about the client's meter, which no one profile
  owns ([schema.md → `db.global`](schema.md#dbglobal--account-wide)).

`MultiMetersPerfDB` sits outside `MultiMetersDB` altogether, so a profile switch neither hides nor
duplicates a perf capture.

## Migrations reach every profile

The stamp is account-wide, so a migration runs once per **account**. That makes one rule binding on
every profile-scoped step: it walks **every stored profile** through `allProfiles(db)`
(`db.sv.profiles`), never `db.profile` alone. A profile the player has not activated this session is
still theirs. A step that lifted only the active one would leave the others to surprise them on the
next swap, after the stamp had moved forward, and the step would never run again.

The runner owns the stamp and advances it only after a step returned. Every step is idempotent
against a fresh default profile, and `Database.SeedWindows` normalizes the window shape after the
walk on every Init and every profile swap. A profile that arrives by copy or reset is therefore
brought to the current shape whatever its own history. The ladder and the stamp rules are in
[schema.md](schema.md); `tests/test_migrations.lua` pins them.

## Related

- [schema.md](schema.md) — the persisted shape and the migration ladder
- [settings-panel.md](settings-panel.md) — the other eight pages and the reset-all act in full
- [message-bus.md](message-bus.md) — `PROFILE_CHANGED` among the fourteen
- [disabled-state.md](disabled-state.md) — why the three AceDB callbacks survive the stand-down
