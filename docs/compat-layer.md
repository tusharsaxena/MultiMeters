# Compat layer

`core/Compat.lua` is the one file in this addon allowed to name a deprecated global or a namespace
that may not exist on the client the player is running. Every other module reaches for `NS.Compat.X`
and gets a shape that matches a modern Midnight 12.x client; where the underlying API is absent the
shim degrades to a stated default rather than erroring at the call site.

It is first in the TOC's core block. Nothing depends on that any more — the TOC-manifest reader that
made it load-bearing is `core/EnvSetup.lua`'s now — but it costs nothing and it reads correctly.

**Twenty-nine shims**, counted the way `documentation-§3` counts them: entry points published on
this addon's own `Compat` table, over this file alone. The threshold is three. This addon's
"might not exist" surface is unusually large because `C_DamageMeter` — its entire data source — is
new in 12.0, so a client one patch behind has none of it and a PTR build can carry the namespace
without one of its members.

## The surface

| Group | Shims | Answers with, where the API is absent |
|---|---|---|
| Spell | `GetSpellInfo`, `GetSpellTexture` | `nil` |
| Specialization | `GetSpecialization`, `GetSpecializationInfo` | `nil` |
| `C_DamageMeter` | `IsDamageMeterAvailable`, `GetCombatSessionFromType`, `GetCombatSessionFromID`, `GetCombatSessionSourceFromType`, `GetCombatSessionSourceFromID`, `GetAvailableCombatSessions`, `GetSessionDurationSeconds`, `ResetAllCombatSessions` | `nil`, except as noted below |
| `C_DeathRecap` | `HasDeathRecap`, `HasRecapEvents`, `GetRecapEvents`, `GetRecapMaxHealth` | `false` / `nil` |
| Recap discovery | `RecapMembers`, `RecapAPIs`, `CallRecap` | an empty finding, never an error |
| Number formatting | `CreateAbbreviatedNumberFormatter`, `GetDefaultAbbreviationBreakpoints`, `CreateNumericRuleFormatter` | `nil` |
| Context menus | `OpenContextMenu` | `false` |
| Icon art | `FirstTexture`, `FirstAtlas` | `nil` |
| Player context | `IsInDelve`, `IsSkyriding`, `IsInHousing` | `false` |
| Bar animation | `BarInterpolation` | `nil`, and the caller omits the argument, so the bar snaps as it did on every client before 12.0 |

Callers, by weight: `modules/Provider.lua` (the meter, the four `C_DeathRecap` readers and the
recap-discovery probe), `modules/DrillDown.lua` and `modules/Tooltip_Lines.lua`
(`Compat.GetSpellInfo`) with `modules/Tooltip_Builders.lua` (`Compat.GetSpellTexture`),
`modules/Visibility.lua` (player context), `modules/HeaderControls.lua` (`FirstTexture` and
`FirstAtlas`) and `modules/Window_Header.lua` (`FirstAtlas`, and the only caller `OpenContextMenu`
has), `modules/Format.lua` (the formatters), and `modules/Row.lua` (`BarInterpolation`, from `Cell:SetValue`). `modules/Tooltip.lua` and `modules/Window.lua`
themselves name nothing in this file any more: the CCN peel took the spell shims across to the
tooltip's builder and line files, and the header art and the menu across to
`modules/Window_Header.lua`.

## The rule this file exists to keep

**It never inspects a meter value.** Reading a field off a session table is not inspection; assigning
it to a local and asking a question about it is, and that is `core/Secrets.lua`'s exclusive job
(design §4, rule R1). Everything here passes meter numbers through untouched.

That is not a style preference. While the Combat addon restriction is active every number
`C_DamageMeter` and `C_DeathRecap` hand back may be a **secret value**: tainted code may pass one
straight into a client API that accepts it, but comparing it, adding to it, keying on it or asking
for its length is a hard Lua error. A single `if session.totalAmount > 0` in this file would be an
error mid-pull, in the one place a player cannot see it and cannot work around it.

So the shims are guards and passthroughs, and nothing else. `HasRecapEvents` is the only member in
either namespace group that answers a question at all, and what it answers about is existence, not
size. The rules that govern what happens to those values afterwards are in
[ARCHITECTURE.md → Taint notes](./ARCHITECTURE.md#taint-notes) and [data-flow.md](./data-flow.md).

## The three degrade shapes, and why they differ

Most shims answer `nil`. Three groups deliberately do not, and each exception is forced by its
caller rather than chosen for tidiness.

**`GetAvailableCombatSessions` answers an empty table.** The session picker iterates it
unconditionally to build its dropdown. Answering `nil` would put an existence check in the UI layer
for a case the UI cannot do anything about.

**The three player-context probes answer `false`.** Each one feeds a `modules/Visibility.lua` rule
that only ever **hides** a window, so "I cannot tell" has to mean "do not hide". Guessing the other
way would make a window vanish on any client whose API surface this addon read wrong, in a state the
player has no way to connect back to a setting.

**`ResetAllCombatSessions` and `OpenContextMenu` answer a boolean** — whether the call was actually
made. Both are actions rather than reads, and a caller that cannot tell a no-op from a success will
eventually report one as the other.

## Guarding, and why the namespace alone is not enough

Every shim checks the namespace **and** the member:

```lua
local api = damageMeter()
if not (api and api.GetCombatSessionFromType) then return nil end
return api.GetCombatSessionFromType(sessionType, statType)
```

`C_DamageMeter` existing does not mean the member does. A PTR build can carry the namespace with a
member missing, which is exactly the state the guard has to survive; `if api.GetX()` without the
`and` is a nil-index error at the one moment the fallback was supposed to save you.

The four `C_DeathRecap` readers carry a second layer: each call is wrapped in `pcall`, because the
client refuses a recap id it does not recognize by **raising**, and a raise reaching the render path
would take a tooltip down mid-hover. `HasRecapEvents` additionally coerces whatever comes back to a
plain `true`/`false` — a `nil`, a `1` or a secret all have to become a boolean here rather than at
ten call sites, because callers branch on it at the height of a pull.

`HasDeathRecap` is keyed on `GetRecapEvents` rather than on the namespace, because the events **are**
the feature: a build carrying the table without that member can do nothing useful, and a death list
whose every row reads as a dash is worse than the fallback such a client has always had.

Capability is probed by presence throughout. There is no `WOW_PROJECT_ID` branch in this file and
there must not be one — the 12.0 namespaces land one API at a time, so a build check would be right
about the build and wrong about the function.

## The recap-discovery probe

`RecapMembers`, `RecapAPIs` and `CallRecap` are not shims over a known API. They are a **search** for
one, and they live here rather than in `core/Diagnostics_DeathRecap.lua` — the report that consumes
them — because a reader could plausibly sit on the meter namespace itself and this file is the only
one permitted to name it. Half a search in a file that may not host it is not a search.

They exist because guessing failed twice. Round one walked a live 12.x client with nine deaths in the
session and came back with one function — a corpse coordinate. Round two added a direct-index search
and ran it over **the same two namespaces**, which re-asked a question that was already answered and
left the one that mattered untouched. The reader is `C_DeathRecap.GetRecapEvents`, in a namespace
neither round searched.

The lesson is written into the code and worth repeating here: a search is only as wide as its
narrowest axis, and the narrow axis was never the one under suspicion. So the probe now searches two
ways — `pairs` enumeration, which asks *what is here*, and a candidate list asked by direct index,
which asks *is this here* and sees through a namespace that answers via `__index` and enumerates
empty. Every finding carries `how`, `walk` or `named`, because that one word is the difference
between "the client has nothing" and "our search was too narrow".

`RecapMembers` dumps **unfiltered** members on purpose. The filter is what made round one ambiguous:
a namespace with seven members and no recap function among them is a conclusive answer, a namespace
with two is a proxy and the walk is at fault, and nobody can tell those apart from a filtered list.
`present` is reported separately from an empty name list for the same reason — "this client has no
`C_DeathInfo`" and "it has one and it enumerates as empty" are different findings.

`CallRecap` never examines its own result, not even for truthiness: a recap event carries an amount
and an HP figure, and both are meter values.

## Number formatting is a compat problem, not a formatting one

`C_StringUtil.CreateAbbreviatedNumberFormatter` is **the only legal way to render "12.4M" from a
secret**. Abbreviating a number is division and rounding, and both are arithmetic; the formatter
object performs that arithmetic natively and accepts secrets (design §4, *Number formatting*).
`modules/Format.lua` owns the instances — one per number style, built once and reused — and is the
only caller. No call site in this addon divides a meter value.

Three formatter types arrived in 12.0.5 and only one of them abbreviates. This addon shipped v0.1.0
calling `CreateNumericRuleFormatter()` — the rule-based one — with no breakpoints configured, which
is a perfectly working formatter that renders `1410000` as `1410000`. Every number was
unabbreviated and nothing failed loudly, because nothing had failed: the addon was asking the wrong
object. Both are kept, because the `full` number style genuinely wants the one that does not
abbreviate.

The `nil` case is real and stays the caller's to handle. A Lua fallback that did the division itself
would be correct out of combat and a hard error in combat, which is the worse of the two available
failures, so `modules/Format.lua` degrades instead.

## Icon art is checked, because guessing failed twice there too

The header's sort arrow and its lock and gear buttons were first drawn from texture paths that do not
exist — and a texture that fails to load draws nothing and raises nothing, so the arrow was simply
absent with no error to read. They were then redrawn as Unicode glyphs, which are not in the game's
default font and rendered as replacement boxes. Both failures share a shape: the art was named at
authoring time and its existence was never checked.

`FirstAtlas` and `FirstTexture` check it at runtime against the client that is actually running, and
they are deliberately **not** the same shape as each other. `C_Texture.GetAtlasInfo` is a pure
existence query — ask about a name, get an answer, touch nothing. There is no such query for a
texture **file**, so `FirstTexture` has to set each candidate on a real `Texture` and ask what it is
holding afterwards. Which means it mutates, and has to clean up: on a total miss it clears the
texture before returning, or the last failed path stays set underneath whatever the caller draws next
and the atlas rung inherits an invisible texture instead of replacing one.

## Context menus: one API, no fallbacks

`OpenContextMenu` wires `MenuUtil` and nothing else. `UIDropDownMenu` and `EasyMenu` are pointedly
not wired as fallbacks: they are absent on every client this addon supports, and a fallback nobody
can run is a fallback nobody has tested. The generator is passed through unchanged rather than
wrapped in a descriptor shape of our own, which would be a second menu vocabulary to keep in step
with Blizzard's. The call is `pcall`'d because it is driven from a click handler, and a menu that
fails to open must not put an error in front of the player mid-pull.

## What is deliberately not here

- **Shims `LibKa0s` supplies are not counted against this file's trigger and are not restated here.**
  TOC metadata is `LibKa0s-Env-1.0`'s, reached through `core/EnvSetup.lua` — which is also why the
  `Compat.GetAddOnMetadata` its header names is a historical reference rather than a member of this
  file.
- **`C_DeathRecap.GetRecapLink`** is left unshimmed until something wants a chat link (spec §10).
- **`Compat.OpenDeathRecap`** does not exist. `modules/DrillDown.lua:271` probes for it optimistically
  so that the call site picks it up with no edit if it is ever added; the guard there is the whole of
  its current behavior.
- **Anything that reads a meter value.** `core/Secrets.lua` owns that, exclusively.

## Adding a shim

One `function Compat.X(...)` in `core/Compat.lua`, namespace and member guarded separately, with the
degrade default chosen from its caller's direction rather than from habit — and one case per rung in
`tests/test_compat.lua`, since a shim with no absent-API case is a shim whose fallback has never run.
If the new API returns anything a meter produced, it is a passthrough and nothing here may look at it.

## See also

- [ARCHITECTURE.md → Taint notes](./ARCHITECTURE.md#taint-notes) — the secret-value operation lists and rules R1/R3.
- [data-flow.md](./data-flow.md) — `C_DamageMeter` → pixel, and the secret rules at every hop.
- [module-map.md](./module-map.md) — where `core/Compat.lua` sits, and who calls it.
- [scope.md](./scope.md) — why scoring cannot be computed in combat at all.
