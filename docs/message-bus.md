# Message bus

> Ka0s Multi Meters. Part of the doc set mapped in
> [ARCHITECTURE.md](ARCHITECTURE.md#documentation-map). The hub's summary is
> [Message bus](ARCHITECTURE.md#message-bus).

A `documentation-§3` Tier 2 doc: this addon has more than ten messages, so the catalog lives here
rather than in the hub. It moved here whole from the hub's `## Message bus` section.

## The catalog

Fourteen `AceEvent` messages are the only inter-module communication channel — modules never call each
other across boundaries. Every name is declared once in `core/Constants.lua`'s `MSG` catalog.
**One sender each**; a second sender is a bug, not a convenience.

The catalog goes through **`LibKa0s-Bus-1.0`'s `Catalog`** (LibKa0s v1.55.0). It checks the table at
load: SCREAMING_SNAKE keys, and wire strings of the form `Ka0s_MultiMeters_<PascalCase>`, as in
`METER_UPDATED` → `Ka0s_MultiMeters_MeterUpdated`. It hands back a **strict** table, so a mistyped
key raises at the call site, for a sender as well as a subscriber. The wire strings used the keys'
SCREAMING_SNAKE spelling until that adoption, and every sender and subscriber reads the constant, so
the rename moved nothing else. With no LibKa0s the plain table is the catalog, and a mistyped key is
a subscriber's nil-index again. The table below names messages by key.

| Message | Sender | Consumers | Payload |
|---|---|---|---|
| `METER_UPDATED` | `core/MultiMeters.lua` | `Targets`, every `Window` | — |
| `METER_SESSION` | `core/MultiMeters.lua` | `Provider`, `Targets`, every `Window` | `{ type, sessionID }` |
| `METER_RESET` | `core/MultiMeters.lua`, and `Provider.Reset` for the manual path | `Provider`, `Roster`, `Feign`, `Aggregator`, `Targets`, `DrillDown`, every `Window` | — |
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

## Two dispatch paths for `METER_RESET`

`METER_RESET` has two dispatch paths on purpose: the game fires `DAMAGE_METER_RESET` and
`Provider.Reset` also announces, so a manual reset does not depend on the event arriving. Every
handler on it is idempotent, and a duplicate wipe is a far smaller problem than a window still
drawing rows for sessions that no longer exist.

## `CONFIG_CHANGED` is not `WINDOWS_CHANGED`

`CONFIG_CHANGED` and `WINDOWS_CHANGED` are deliberately distinct: the first is a setting moving
inside a window that already exists (re-apply and refresh), the second is the registry changing
*shape* (rebuild, and the panel re-draws its picker). Both carry `windowId`, so a twenty-window
profile does not re-apply nineteen windows for one edit.

## Bus targets

**Bus-target discipline.** CallbackHandler keys callbacks by `(message, target)`, so two receivers of
one message on the same object silently clobber each other and only the last registrant fires. This
addon is unusually exposed — every window subscribes to the same refresh messages and there can be
many windows. AceAddon modules are their own targets; each `Window` instance, `modules/Format.lua`,
`modules/Targets.lua`, the export modal in `modules/Export_Modal.lua` and `settings/Profiles.lua`'s
page own a private target from `NS.NewBusTarget()`. Nothing registers on the shared addon object.

## Standing the bus down

**The stand-down record is `LibKa0s-Bus-1.0`'s** (hand-written here until LibKa0s v1.55.0).
`NS.busRecord` (`core/Namespace.lua`) tracks every target from `NS.NewBusTarget()`, and
`NS.BusStandDown()` takes all their registrations down while keeping the record. `NS.BusStandUp()`,
called first in `standUp`, replays the record as it is now. While the bus is down, a registration
is recorded but not made, and a target its owner has emptied is never replayed. The stand-down it serves
is in [disabled-state.md](disabled-state.md), and `tests/test_disabled.lua` pins it.

## Related

- [ARCHITECTURE.md → Event subscriptions](ARCHITECTURE.md#event-subscriptions) — which game event
  becomes which message, and the one file that registers them
- [profiles.md](profiles.md) — the `PROFILE_CHANGED` fan-out in full
- [disabled-state.md](disabled-state.md) — the stand-down the bus record serves
- `core/Constants.lua` → `MSG` — the catalog itself; `tests/test_constants.lua` pins its shape
