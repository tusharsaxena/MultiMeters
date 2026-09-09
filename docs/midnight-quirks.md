# Midnight quirks

The 12.0 (Midnight) client behaviors this addon works around, and the secret-value model behind
them. `docs/ARCHITECTURE.md` → `## Taint notes` states the constraint and the three design rules it
forces; this page is the detail behind them and the place a new workaround is written down.

It exists because `documentation-§3`'s trigger fired: **at least one client-version workaround of the
addon's own**. This addon carries several — a probed event, an event registered against a namespace
that may not be there, a settle pass over client state that lags its own event, and a whole data
path arranged around values that are secret while a restriction is active. What it does NOT carry is
a second copy of the shims `LibKa0s` supplies; those are the library's to document.

## Secret GUIDs come out of the unit API too

In a follower dungeon `UnitGUID("party3pet")` answers a secret string, and keying on one raises
`attempted to perform indexed assignment on a table that cannot be indexed with secret keys` on every
refresh tick. `modules/Roster.lua` — which reaches `UnitGUID` for the whole group and is the only
file that keys a map on what comes back — therefore vets every GUID through `NS.Secrets.IsSafeKey`
before using it as a key, and vets the argument of `Get`, `IsGroupMember` and `OwnerOf` the same way.
It is not the only unit-token GUID in the addon and the gate is not only its: `core/MultiMeters.lua`'s
`UNIT_SPELLCAST_SUCCEEDED` handler reads `UnitGUID(unit)` and hands it to `modules/Feign.lua`, whose
`Note` asks `IsSafeKey` the same question for the same reason, and logs the refusal rather than
dropping the cast in silence. An unreadable pet falls into the existing
"unattributable" case: no map entry, `OwnerOf` nil — and it then gets a row **of its own**, under its
own name, rather than being dropped (see [scope.md](scope.md#known-limitations)).

## A frame that never sees a value keeps readable geometry

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

## Why an export refuses rather than degrades

**`tostring` is not on the permitted list.** A CSV cell is `tostring(value)` and a chat line splices a formatted number into a
sentence. `tostring` on a secret neither raises nor launders it: it answers a **secret string**,
which then poisons the `find` and the `gsub` that RFC-4180 quoting is made of, and the `table.concat`
that joins a row. Everywhere else in the addon a restricted value travels on as an opaque handle and
the display loses a bar or a percentage; there is no equivalent escape for a serializer, because a
serializer's whole job is to look at the characters of a value. A serializer that is subtly wrong
mid-pull is worse than one that says no.

So the export path says no at four points rather than one, because the restriction can activate
between any two of them — and since the layout-§1 peel those four sit in **three files** rather than
one, which is worth knowing before going looking for them. `Export.Available()` is the single gate,
in `modules/Export.lua`, and answers false; `/mm export` asks it in `settings/Slash.lua`'s `doExport`
and prints the sentence rather than opening anything; `Export.Open` in `modules/Export_Modal.lua`
refuses to open the modal at all; and `Export.CSV` / `Export.ChatLines`, back in
`modules/Export.lua`, refuse again at their own first line for a caller that reached them anyway.
The modal asks three more times after it is open — once in its refresh, and once inside each of the
two action-button handlers — because a dialog opened out of combat can be clicked ten seconds into a
pull, and a greyed-out button is a hint rather than a guarantee. Underneath all of them, and
independent of them, every field passes `Secrets.CanAccess` on its way into a cell and yields `""`
when it fails — so a race between the check and the walk can produce a blank cell, and can never
raise.

The other half of `modules/Export.lua`'s discipline is what it does **not** do. An export wants
every stat for every player, which is exactly the loop `modules/Provider.lua` already writes — so
writing it again would put a second caller on `C_DamageMeter` and break R1. Instead
`Export.SessionConfig` builds a synthetic window config naming every catalogued stat, pointed at the
invoking window's segment, and hands it to `Aggregator.Build`. The aggregator neither knows nor
cares that no frame will draw the result, and the ranking a chat dump needs happens there, under the
aggregator's own guards, rather than in a sort of the exporter's own.

## The restriction keys off `Combat`

Secrecy keys off `Combat`, not `ChallengeMode`. Between packs in a key the values and the GUIDs
are fully readable, so the exact GUID join runs for most of a dungeon run and identity mode covers the
pulls themselves. `ADDON_RESTRICTION_STATE_CHANGED` fires with `state = Activating` **before**
enforcement begins and access is still permitted during that dispatch, which is why
`core/Secrets.lua` exposes the raw state and not just a boolean. `modules/Aggregator.lua` no longer
listens for that edge: it existed to take one last value-sort and freeze the result, and a frozen
`guid → position` map cannot be applied to rows that have no GUID.

## Client-version workarounds on the event edges

The events themselves are tabulated in `docs/ARCHITECTURE.md` →
[Event subscriptions](ARCHITECTURE.md#event-subscriptions). What follows is the part of that wiring
that exists because of what a particular client does or does not have.

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
