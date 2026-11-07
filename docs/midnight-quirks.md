# Midnight quirks

The 12.0 (Midnight) client behaviors this addon works around, and the secret-value model behind
them. `docs/ARCHITECTURE.md` → `## Taint notes` states the constraint and the three design rules it
forces; this page is the detail behind them and the place a new workaround is written down.

It is required in every addon (`documentation-§3`, Tier 2, from v2.102.0). This addon carries
several — a probed event, an event registered against a namespace that may not be there, a settle pass over client state that lags its own event, and a whole data
path arranged around values that are secret while a restriction is active. What it does NOT carry is
a second copy of the shims `LibKa0s` supplies; those are the library's to document.

The first part below is the collection's client-quirks catalog (`client-quirks`), vendored whole
from the standard and replaced wholesale on every revendor (never edit inside its markers); the
second, `## MultiMeters-specific quirks`, is this addon's own.

<!-- BEGIN VENDORED: quirks catalog v2.103.1 (source: WowAddonStandards) -->
> Part of the **[Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards/blob/master/standards/STANDARDS.md)** — the split standard. This section is vendored whole into every addon's `docs/midnight-quirks.md` (§1), so its links are absolute. Cross-references use the `filename-§N` form (see the index's section map).

## Client quirks

The client behaviors the collection paid for more than once. Each entry here was discovered
**independently in two or more Ka0s repositories**, written up in each, and promoted by a harvest so the
next addon reads it instead of rediscovering it. A behavior one repo found stays in that repo's
`docs/midnight-quirks.md` until a second repo meets it.

*Why this section exists.* By 2026-11-06 eleven addons kept a private `docs/midnight-quirks.md`, 2,073
lines and about 133 entries between them, and about 81 of those entries were 21 behaviors written up
independently two to eight times. Nine of the eleven opened with their own restatement of the 12.0 secret
rules. Three write-ups contradicted this standard, and one contradiction was this standard's own error
(events-frames-taint-§2, *The combat-start edge*). A catalog was proposed and deferred twice, on
2026-08-25 and 2026-09-22, because an inventory rots; the build stamp per entry (§1) is the answer to that
objection (WowAddonStandards `harvests/2026-11-06/02_FINDINGS.md`, F3-01; every write-up quoted in
`harvests/2026-11-06/03_EVIDENCE.md`, Part A).

### 1. How an entry is written, and how it expires (MUST)

Every entry **MUST** carry:

- **The behavior**, stated as what the client does, not as advice.
- **Measured:** the client build or date it was observed on, where any write-up recorded one. An entry with
  no measurement says *not measured*; that is a weaker entry, not a missing field.
- **Cost:** what happened to an addon that did not know it.
- **Client:** the client it was measured on, `Retail` or `Forever` (clients-§1). An entry that names none is a Retail entry, which is every entry written before v2.103.0; a Forever behavior is written with `Forever` and its build, and it is not assumed to hold on Retail.
- **Do:** the workaround, as a rule an addon can follow.
- **Source:** the deepest write-up — the repo and document that probed furthest — and the harvest that
  promoted it. Every version is quoted in that harvest's `03_EVIDENCE.md`.

**Expiry.** An entry describes a client, and clients move. When the retail interface number moves past the
newest *Measured* stamp in an entry and an addon observes otherwise, the entry is corrected in a standard
release — not worked around in the addon. An entry nobody can reproduce moves to §6 as an open probe rather
than being deleted, because the behavior may only have moved.

**What an addon does with this section (MUST): carry it as a vendored block.** This section is the one
part of the standard an addon carries a **copy** of, because it is reference data about the game client
that a working addon needs offline, next to the code that works around it — not a rule, which is only ever
pointed at. Every addon's `docs/midnight-quirks.md` (documentation-§3) is two parts: the vendored block,
opened by a `BEGIN VENDORED` HTML comment naming the catalog's version and source and closed by an
`END VENDORED` HTML comment, each spelled exactly as `/dev-copilot:wow-revendor-standards` writes it; then
the addon's own section. The markers are described here rather than shown, because this text travels
inside them: a literal marker in the vendored copy would give the file a second end marker for the next
re-vendor to cut at.

```markdown
[the BEGIN VENDORED comment, stamped quirks catalog v<X.Y.Z>]
… this section, whole …
[the END VENDORED comment]

## <Addon>-specific quirks

… the addon's own quirks: one no second repo has met, its per-event costs, its own probe tables …
```

- The block is **copied whole and replaced wholesale** by `/dev-copilot:wow-revendor-standards`, stamped with
  the standard version it came from, under the same discipline as `libs/LibKa0s/` (anti-pattern #45): never
  a subset, **never edited inside the markers**. A local edit inside them is reverted by the next revendor,
  and the behavior it fixed comes back with no cause in the addon's history; a correction belongs in the
  addon's own section, where the next harvest finds it.
- The addon's own section **MUST NOT** restate a behavior the block carries. When a harvest promotes an
  entry, the revendor prunes the addon's copy: the upstream entry is the deeper write-up, and two live
  copies of one finding is the shape that drifted three times into contradiction.
- An addon with no quirks of its own still carries the block, with an empty own section.

**Contested behaviors are not rules.** Where two repos recorded opposite behavior and nobody has probed
the difference, the entry goes in §6 with both sides and the probe that would settle it.

Behaviors this standard already states elsewhere are not repeated here: the unknown-event raise
(events-frames-taint-§1), `Settings.OpenToCategory`'s numeric ID and collapsed parent (options-ui-§2),
the protected category switch in combat (options-ui-§2, anti-pattern #88), a secret through `tostring` and
`..` (events-frames-taint-§8), lockdown at `PLAYER_REGEN_DISABLED` (events-frames-taint-§2), the spec
readers' move to `C_SpecializationInfo` (compat, `LibKa0s-Compat-1.0`) and `SendChatMessage`'s move to
`C_ChatInfo` (compat).

### 2. Secret values

**A secret boolean cannot be tested at all.** `if`, `not`, `==` and `and`/`or` on a secret boolean raise
("attempt to compare … (a secret boolean value)"); the value is unusable in Lua, not merely unprintable.
`DurationObject`'s `HasExpired`, `HasStarted`, `IsActive` and `IsZero` come back secret in combat, and an
engine button's `IsShown` has answered a secret boolean out of combat. *Measured:* 12.0.7 (probe table);
12.1 (`IsShown`). *Cost:* a raise on every refresh tick of the path that tests it. *Do:* check
`issecretvalue` before any test; route a secret boolean to a C-side consumer
(`C_CurveUtil.EvaluateColorValueFromBoolean`, `SetAlphaFromBoolean`), or treat it as the cautious answer
(a secret lockdown reads as locked, a secret restriction as active, a secret claim as no claim). Two repos
disagree on whether to gate before the C-side call; that disagreement is recorded in `LibKa0s`
`docs/api/Compat` and is not ruled here. *Source:* KickCD `docs/midnight-quirks.md`, "Secret booleans are
unusable"; seven repos (harvest 2026-11-06, Q6).

**A secret cannot be a table key.** Indexing or assigning with a secret key raises "attempted to perform
indexed assignment on a table that cannot be indexed with secret keys". `UnitGUID` on a follower-dungeon
pet (`party3pet`) answers a secret string. *Cost:* a raise on every refresh tick for a roster keyed by
GUID. *Do:* guard a key with `IsSafeKey` (`LibKa0s-Compat-1.0`) or `issecretvalue` before keying; a
secret GUID is never a handle. *Source:* MultiMeters `docs/midnight-quirks.md`, the follower-dungeon pet
GUID; seven repos (Q7).

**A secret never reaches SavedVariables, and one that does is written as `nil`.** A value captured as
secret stays secret after combat ends, and the client writes a secret to SavedVariables as `nil` — or,
where it was a key, loses the entry. *Measured:* a reload probe, 2026-10-25. *Cost:* silent data loss on
the next reload. *Do:* store a plain value or nothing; never store a captured secret to read later.
*Source:* DpsRace `docs/known-limitations.md`, the reload probe; three repos (Q21).

**A frame handed a secret has secret geometry, and so does everything anchored to it.** After
`StatusBar:SetValue(secret)` (or `SetAlphaFromBoolean`, or anchoring to an aura engine container) the
frame `HasSecretValues`: its width, points and frame level read secret, out of combat too, and the
taint runs down the anchor chain to every frame anchored to it; a tooltip showing hidden information has
secret geometry. A secret size's `type` is `"number"`, so a type check lets it through, and
`BackdropTemplate`'s own arithmetic on a secret size raises. *Cost:* a raise inside Blizzard code, or a
layout computed from a secret. *Do:* compute layout from configuration and never read geometry back from a
frame that was handed a value; keep a record of the alpha you set rather than calling `GetAlpha()`; read a
frame level under a restricted anchor through a secret-safe guard (frame-layering). *Source:* AuraMaster
`docs/midnight-quirks.md`, the aura engine container entries (measured and dated); six repos and
`LibKa0s` `docs/api/Widgets` (Q8).

**A restricted spell's cooldown: branch on `isActive`, paint with the duration object.** In a restricted
state `C_Spell.GetSpellCooldown`'s timings are secret while `isEnabled` and `isActive` stay plain
(documented NeverSecret). `GetSpellCooldownDuration` answers a **zeroed** object, not `nil`, when there is
no cooldown, and a fresh object per call. *Cost:* raw `SetCooldown` with a secret start or duration raises;
a nil check passes the zeroed object. *Do:* decide from `isActive`; paint with
`Cooldown:SetCooldownFromDurationObject`, which accepts the object from tainted code. *Source:* KickCD
`docs/midnight-quirks.md`, the cooldown probe table; four repos (Q9).

**`notInterruptible` is secret, and the interruptibility events make it plain.** The cast info's
`notInterruptible` is secret; `UNIT_SPELLCAST_INTERRUPTIBLE` / `_NOT_INTERRUPTIBLE` deliver it plain.
`CastingBarFrameTemplate`'s built-in `OnUpdate` compares `GetTime()` with a secret `maxValue` and raises
when the bar shows another unit. *Do:* split the gate — the color path takes the secret C-side, the logic
path takes the event's plain value; do not inherit `CastingBarFrameTemplate` for a unit other than the
player. *Source:* KickCD `docs/midnight-quirks.md`, "split the gate in two"; two repos (Q13).

**`InChatMessagingLockdown` can answer a secret.** *Do:* read it through a guard and treat a secret as
locked. *Source:* DropWatcher and QuickComms `core/Compat.lua` (byte-identical), DpsRace; three repos (Q27).

### 3. Events

**A valid event can register without complaint and never fire.** `GUILDBANKFRAME_OPENED` registers and
never fires (*Measured:* 12.0.7); `UNIT_SPELLCAST_SUCCEEDED` is suppressed for protected interrupts;
`UNIT_HEALTH` and `UNIT_NAME_UPDATE` never fire for compound tokens such as `party1target`;
`GET_ITEM_INFO_RECEIVED` does not fire for an item already cached. This is the inverse of the
unknown-event raise (events-frames-taint-§1) and it is silent: nothing errors. *Cost:* a feature that
never runs, with nothing in the log. *Do:* confirm a new event fires in game before building on it, and
prefer an edge with a second source (a frame's `OnShow`, a gated timer) where the event is known to be
silent. *Source:* BankLedger `docs/midnight-quirks.md`, `GUILDBANKFRAME_OPENED`; four repos (Q20).

**Client state can lag its own event, or change with no event at all.** `IsMounted()` has flipped by the
time `PLAYER_MOUNT_DISPLAY_CHANGED` arrives while `C_PlayerInfo.GetGlidingInfo`'s `canGlide` sometimes has
not; after `INSPECT_READY` some slots still answer an item id with no link; switching bank tabs fires no
event, and the live warband tab has taken over a second to catch up; chat lockdown clears with no event.
*Cost:* a read at the edge answers the old state, and the display stays wrong until the next unrelated
event. *Do:* answer at the edge **and once more after a short settle** (a fraction of a second, a bounded
retry), never a poll. *Source:* MultiMeters `docs/midnight-quirks.md`, "some client state lags its own
event"; six repos (Q19).

**An empowered cast fires `UNIT_SPELLCAST_EMPOWER_*`, not the channel events.** `UnitChannelInfo`
reports it, but `UNIT_SPELLCAST_CHANNEL_START` / `_STOP` do not fire for it, and its release fires
`UNIT_SPELLCAST_SUCCEEDED` with the same cast GUID. *Do:* register the `EMPOWER_*` events wherever channels
are tracked. *Source:* KickCD `docs/midnight-quirks.md`, empowered casts; three repos (Q12).

**`ADDON_RESTRICTION_STATE_CHANGED` fires *before* enforcement.** The `Activating` state arrives before the
restriction begins, and access is still permitted during that dispatch; a dungeon restriction type has
gone active on entry and not cleared. Read the restriction type by its `Enum.AddOnRestrictionType` member
name — a member can be missing on some builds. *Measured:* 12.1.0, 2026-09-18. *Do:* treat `Activating`
as the last moment to read, not as the start of the restriction. The payload's second argument is
contested (§6). *Source:* AuraMaster `docs/midnight-quirks.md`, the restriction types; six repos (Q10).

### 4. Combat and secure frames

**Blizzard's aura buttons are forbidden to addon code, and `IsForbidden()` can say otherwise.** In
combat every call on a Blizzard aura button's objects raises "Attempt to access forbidden object from code
tainted by an AddOn"; in an instance (seen in Mythic+) the same buttons answer `IsForbidden()` `false` and
still refuse every read, `GetChildren` included. *Do:* never read Blizzard aura buttons; where a frame
must be inspected, `pcall` the read and treat a failure as forbidden. *Source:* PartyFrameEnhanced
`docs/midnight-quirks.md`, forbidden aura buttons; three repos (Q14).

**Escape runs a protected `Hide()` in combat.** A secure or protected frame listed in `UISpecialFrames` is
hidden by `CloseSpecialWindows`, which is a protected action in combat. *Do:* list a non-secure proxy in
`UISpecialFrames` and hide the protected frame from it out of combat, or keep protected frames out of the
list. *Source:* WhatGroup `docs/midnight-quirks.md`, the escape proxy; two repos (Q24).

### 5. Item, tooltip, enum and realm data

**Item data is nil until cached, and the load event has holes.** `GetItemInfo` answers nothing for an
uncached item; `GET_ITEM_INFO_RECEIVED` does not fire on an addon's first scan for an item the client
already holds; an uncached item's tooltip is not empty but a legible `RETRIEVING_ITEM_INFO` line; a failed
load drops its wait and nothing asks again. *Cost:* a blank or wrong row that never repairs. *Do:* load
through `LibKa0s-Item-1.0`'s cache-then-callback path (library-stack-§7), treat `RETRIEVING_ITEM_INFO` as
not-yet-loaded, and re-ask after a failed load. *Source:* ConsumableMaster `docs/midnight-quirks.md`, the
first-scan hole; seven repos (Q15).

**`C_TooltipInfo` returns raw templates.** Tooltip lines can carry the unexpanded plural grammar
`|4singular:plural;` (*Measured:* 12.1.5, "for the next 3 |4hour:hrs; 49 min") and a no-break space that
Lua's `%s` does not match. *Cost:* a parser that knew only the expanded words read no duration and called a
tradeable drop expired. *Do:* expand `|4…;` before matching, and match the no-break space explicitly.
*Source:* DropWatcher `docs/midnight-quirks.md`, the trade window; two repos (Q16).

**Tooltip line text can be secret** under an addon restriction, including through `TooltipDataProcessor`.
*Do:* guard each line before matching. *Source:* DropWatcher `docs/midnight-quirks.md`; two repos (Q17).

**Blizzard renumbers enums; resolve a member by name, never by number.** One build's
`Enum.TooltipDataLineType` and bank-tab values are not the next build's, and a member can be absent on a
build. *Cost:* a numeric guess for a member the build does not expose landed on an unrelated bank
container. *Do:* read `Enum.X.Member`, and handle its absence; localization-§4 already forbids the string
spelling. *Source:* DropWatcher `docs/midnight-quirks.md`, the research's enum values; five repos (Q18).

**`GetNormalizedRealmName` is nil early in login.** *Cost:* a stored `Name-` key with no realm. *Do:* never
build a `Name-Realm` key before the realm is known; defer, or fall back to `GetRealmName` with its spaces
and hyphens removed. *Source:* DropWatcher `docs/midnight-quirks.md`, realm names; four repos (Q25).

**A template-less `FontString` with no font raises on `SetText`.** "Font not set" from a `FontString`
created without a template or `SetFontObject` takes the addon down at load; a mock that does not enforce it
passes every test. *Do:* give every bare `FontString` a font object before its first `SetText`; the kit's
mock enforces it. *Source:* MultiMeters `tests/mock_frame.lua`, the font-not-set guard; three repos and
`LibKa0s` (Q22).

### 6. Open probes — contested behaviors (not rules)

Each needs an in-game probe, recorded with the build, before any section of this standard changes.

- **WoW Forever behaviors (none recorded yet).** The catalog was written on Retail. The Forever client (build 70790) has a missing-API surface, `SetDesaturation` among it, that LibKa0s tracks in LibKa0s#44, and no quirk entry yet meets this section's two-repo bar for it. Record a Forever behavior in the repo that meets it, with the build, and promote it by a harvest like any other.

- **`string.format` on a secret.** events-frames-taint-§8 says it raises, with three repos; two say it
  works, one with a mid-combat observation. The likely difference is the specifier (`%s` against `%d` and
  `%.1f`) or that the result is itself a secret string. Probe each specifier, in combat, on a damage-meter
  value and a `UnitHealth` value. Until then §8's rule stands.
- **`ADDON_RESTRICTION_STATE_CHANGED`'s second argument.** One repo documents an
  `Enum.AddOnRestrictionState` value; three (one measured) record a boolean as well. Handle both shapes.
  The 2026-09-22 harvest called this settled, and it is not.
- **`SetAllPoints(parent)` on a secure button at load.** One repo records "Cannot anchor protected frames
  to regions" and uses the implicit-parent form; another anchors its secure rows with `SetAllPoints(row)`
  at birth and treats it as working, with its in-game smoke check still owed.
<!-- END VENDORED -->

## MultiMeters-specific quirks

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
pull, and a grayed-out button is a hint rather than a guarantee. Underneath all of them, and
independent of them, every field passes `Secrets.CanAccess` on its way into a cell and yields `""`
when it fails — so a race between the check and the walk can produce a blank cell, and can never
raise.

The other half of `modules/Export.lua`'s discipline is what it does **not** do. An export wants
every stat for every player, which is exactly the loop `modules/Provider.lua` already writes — so
writing it again would put a second caller on `C_DamageMeter` and break R1. Instead
`Export.SessionConfig` builds a synthetic window config naming every cataloged stat, pointed at the
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

## Enemies are filed under `None`, not `Enemy`

`sourceDisplayType` has three values: `None` (0), `Ally` (1) and `Enemy` (2). The addon assumed that
enemies report `Enemy`, and nothing had ever measured it. The first plain reading did: on
2026-09-26, out of combat, after a PvP Training Dummy and some open-world pulls, `/mm diagnostics`
printed `display types: 0 x28` for the EnemyDamageTaken column. All 28 enemies were `None`. The
field is read correctly (`modules/Provider.lua` copies `src.sourceDisplayType`, and an absent field
would have printed `nil`, not `0`). Before that, the only live readings were `<secret>` mid-pull
and a delve companion's `display=0`.

Nothing on the grid changes because of it. The grid never reads EnemyDamageTaken, which sits in
`Constants.OFF_CATALOG_STATS` rather than `Constants.STATS`, and `modules/Targets.lua` builds the
enemy list without consulting the display type. What it does change is the weight of the `Enemy`
gate in `modules/Aggregator.lua` (`isEnemySource` and `unownedAllyRow`): that gate cannot be relied
on to recognize a mob. If a mob ever reached a grid column out of combat, the companion rule
would be the only test in its way. So the targets section of `/mm diagnostics` now prints each
enemy's `class=` and counts the enemies that carry a player class, rather than raising an alarm over
the column's `None`.

**A class is not enough either** ([#56](https://github.com/tusharsaxena/MultiMeters/issues/56)). The
companion rule used to be `None` plus a class `RAID_CLASS_COLORS` knows, on the argument that a mob
would have to report `None` AND carry a genuine class filename. The PvP Training Dummy (creature
243211) does both: `None`, class `WARRIOR`. So a `None` source is now admitted only with a real class
AND a companion identity: a `Player-` GUID, or a creature id (from `sourceCreatureID` or the GUID's
npc field) in `Constants.COMPANION_CREATURE_IDS`, which is seeded with Valeera Sanguinar's measured
248567 only. Mid-pull, identity mode refuses a classed `None` source only when its creature id or
GUID is plain and names no companion; one whose identifiers are both secret is undecidable and stays
admitted. **The allowlist rule:** an id is added from a measurement, never guessed. The targets
section of `/mm diagnostics` prints each enemy's creature id and `enemies the grid would admit as a
row: N of M`, and the aggregator's drop line prints the GUID, so a missing companion's id is read off
one of those.

## Client-version workarounds on the event edges

The events themselves are tabulated in `docs/ARCHITECTURE.md` →
[Event subscriptions](ARCHITECTURE.md#event-subscriptions). What follows is the part of that wiring
that exists because of what a particular client does or does not have.

**An unknown event name raises, so every registration is isolated.** The client answers
`RegisterEvent` for a name it does not know with `Attempt to register unknown event "<NAME>"`, and a
block of bare calls loses every line after the one that raised — here that was the three
`DAMAGE_METER_*` events, which are registered last. `OnEnable` now walks the `EVENTS` array in
`core/MultiMeters.lua` through `NS.SafeRegisterEvent` (LibKa0s-Core minor 8: the
`C_EventUtils.IsEventValid` front gate, a probe frame, then a `pcall`; the no-library stub keeps the
`pcall` alone). A refused name costs only itself and is recorded in `NS.State.rejectedEvents`, which
is replaced on every enable. Read it with `/mm diagnostics` (the `events` section says
`rejected events: none` on a healthy client), or with the debug log on, where `[Init]` carries one
`rejected events:` line when the list is not empty (written at login through the console's
at-enable queue, so it lands when logging is turned on).

`PLAYER_IS_GLIDING_CHANGED` is the name most likely to be refused: it is the newest of the set and a
client that has not got it raises on `RegisterEvent`. Losing that one edge is survivable where losing
the block is not — `PLAYER_CAN_GLIDE_CHANGED` still fires when the mount changes, which is the
transition the skyriding rule turns on.
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

`ADDON_RESTRICTION_STATE_CHANGED` is registered even on a client without `C_RestrictedActions`
rather than behind a version check to keep in step with `core/Secrets.lua`'s. That is safe because
the registration is isolated: on such a client the name is refused and recorded, not raised. `OnEnable` also **seeds** `NS.State.restricted` from `Secrets.IsRestricted()`,
because a `/reload` taken mid-pull re-enables the addon inside an already-active restriction and
there is no second edge to catch.
