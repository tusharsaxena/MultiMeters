# Scope

What Ka0s Multi Meters is, what is in scope, and what is deliberately not. This doc records the
*boundary* decisions, so a fresh contributor can tell whether a feature request is in or out without
re-litigating it — and, for the two entries that matter most, so nobody re-proposes something the
data source cannot express.

## What it is

A single-frame, multi-column group meter for Retail (Midnight, 12.x). One row per group member, one
column per statistic, each cell a `StatusBar` with its text on it.

Every other meter shows one statistic per window. Answering "who kicked, who dispelled, who stood in
things, who died" means four windows or four mode switches. Multi Meters shows all of them as
columns of one grid.

**Every number comes from Blizzard's built-in damage meter through `C_DamageMeter`.** The addon never
parses the combat log, never maintains its own event accumulator, and never persists a number. That
is the single largest scope decision in the project and everything below follows from it.

Identity: folder `MultiMeters` · TOC `MultiMeters.toc` · display name `Ka0s Multi Meters` ·
`/mm` with a `/multimeters` alias · SavedVariables `MultiMetersDB` + `MultiMetersPerfDB` · MIT ·
Retail only · English only.

## In scope

- **Eight statistics**, catalogued in `core/Constants.lua`: Damage, Healing, Absorbs, Interrupts,
  Dispels, Damage Taken, Avoidable Damage, Deaths. Six are enabled on a new window; adding a ninth is
  one row in that catalog and nothing else. `EnemyDamageTaken` is deliberately **not** among them —
  it describes an enemy rather than a group member, so it needs a window type whose rows are enemies
  rather than a column on this one ([issue #2](https://github.com/tusharsaxena/MultiMeters/issues/2)).
  The addon still READS it: it is what `modules/Targets.lua` cross-references to answer "which enemies
  this player hit".
- **Multiple independent windows.** A window is an instance, not a singleton — there are no global
  display settings. `frame`, `header`, `rows`, `bars`, `text`, `icons`, `tooltip`, `visibility`,
  `columns` and `data` all live inside one window's config, which is what makes multi-window and
  copy-settings-from cheap: a copy is a deep table copy, optionally filtered to one group.
- **Copy settings from**, with a group filter — copying one window's columns onto another while
  leaving its position and visibility rules alone is the actual request behind the feature.
- **Current vs Overall sessions**, per window, plus the historical session list the client keeps.
- **Three sort modes** — value, provider order, roster order — with the fallback ladder described
  in [data-flow.md](data-flow.md#5-the-three-sort-modes-and-identity-mode). The sort freeze that
  section used to carry is retired: it was keyed on `sourceGUID`, which is secret exactly when a
  freeze would have been wanted, so a mid-pull row never had a key to hold steady. The engine's own
  ranking under identity mode replaces it.
- **Tooltips**: a per-cell spell breakdown, and an all-statistics summary on a player's name that
  deliberately includes the columns the window is *not* showing.
- **Cell drill-down** into a player's per-spell breakdown, rendered through the same row path as the
  grid, plus a hand-off to Blizzard's own death recap from the Deaths column.
- **Pet folding** into owners, best-effort — see the caveat below.
- **A nine-page settings panel** driven by one 162-row schema, with full `/mm` CLI parity for every
  schema-shaped operation.
- **Visibility rules** per window — **show everywhere, hide nowhere** out of the box. Seven contexts
  (dungeon, raid, arena, battleground, delve, scenario, open world), all on by default; ten hide
  rules (solo, vehicle, mounted, skyriding, flight path, player housing, pet battle, dead, in
  combat, out of combat), all off by default.
- **AceDB profiles**, all characters starting on the shared `"Default"` profile.
- **Test mode** and an unlock/drag cycle, so a window can be laid out at a target dummy.
- **A minimap button** and LDB launcher (left-click toggles the windows, right-click opens settings).
- **A perf harness** (`/mm perf`) and an on-screen debug console (`/mm debug`), both LibKa0s's.

**The catalog is one table, and there are two lookups over it.**

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

## Deferred: scoring

A weighted score across damage, healing, kicks and dispels — "who actually carried this key" — is the
most obvious feature this addon does not have. It is deferred rather than declined, and the reason is
structural rather than a matter of effort.

**A weighted score is arithmetic over meter values, so it cannot be computed in combat at all.**

While the `Combat` addon restriction is active, `C_DamageMeter`'s numeric returns come back to
tainted code — which is all of ours — as **secret values**. Tainted code may not do arithmetic on
one. Not multiply by a weight, not sum across four columns, not divide by a group total, not compare
two scores to rank them. Every one of those raises an immediate Lua error, and it raises in the
middle of a pull, in every window, four times a second.

There is no escape hatch for it. There *is* one for formatting — `NumericRuleFormatter:FormatNumber`
performs division and rounding natively and accepts secrets, which is the only reason "12.4M" is
legal at all (see [data-flow.md](data-flow.md#6-the-formatter)). That hatch **renders; it does not
sum**. The same asymmetry is what forces pet folding to drop a pet's row rather than add it to its
owner's while restricted.

So a scoring feature can land in exactly two shapes, and neither is a small change to the current
data layer:

1. **Out of combat / post-run.** Between packs in a key the restriction is inactive and values are
   plain numbers, so a score computed at the end of a run — or between pulls — is ordinary Lua. This
   is the likely shape.
2. **Expressed through `C_CurveUtil` curve objects**, which evaluate natively the way the numeric
   formatter formats natively. Whether the available curve surface can express a weighted sum across
   four independent inputs has not been established.

This is recorded now, at v0.1.0, so the data layer is not designed toward an in-combat aggregate it
can never produce — and so the next person to propose it reads this paragraph first.

**What is not the answer:** computing the score anyway and guarding it with `IsRestricted()`. That
produces code which is correct out of combat and a hard error in combat, which is the worst of the
two possible failures — it ships green and breaks in a raid.

## Out of scope

These have been considered and explicitly declined.

- **Parsing the combat log.** `COMBAT_LOG_EVENT_UNFILTERED` is the traditional way to build a meter
  and is the thing this addon exists not to do. Blizzard's meter is already accumulating the same
  numbers, correctly, natively, with no per-event Lua cost; re-deriving them would buy a second set
  of numbers that disagrees with the game's own.
- **An in-window column drag editor.** Every other meter lets you drag a column edge. This one
  deliberately does not, and it is not an effort question: resizing by dragging means reading the
  cell's geometry back (`GetWidth`, `GetLeft`, `GetPoint`), and a cell that has been handed a secret
  value through `SetValue` has secret geometry which propagates to everything anchored to it. That
  read is exactly the one this addon may never perform on a live cell. Confining column management to
  `settings/Columns.lua` removes the hazard rather than guarding against it (rule R3).
- **Bar colors that depend on the value** — "color by rank", "color above threshold", a gradient from
  the column max. All four shipped color modes (class, role, per-statistic, custom) are
  value-independent by necessity: deciding a color from a number requires comparing it, which is
  illegal for the whole of a pull, which is exactly when a meter is read.
- **Persisting meter numbers.** Nothing this addon stores in SavedVariables is a meter value. Holding
  one across time would mean holding a handle whose accessibility changes underneath us, and the
  client already keeps the session history the picker reads.
- **Resetting the meter as part of any refresh path.** `Provider.Reset` exists, is reachable only
  from the General page's confirmation and the header's reset control, and wipes the sessions
  Blizzard's *own* meter is showing too —
  not just ours. An addon that can silently reset the meter is an addon that will be blamed for a
  lost log.
- **Localization.** English only for the addon's own strings. `locales/enUS.lua` carries the mandated
  key-is-the-string metatable fallback and the file is structured for a translator to copy, so the
  plumbing exists — but no second locale ships and none is planned.

  This is **not** a license to be locale-*dependent*, which is a different thing. Nothing persisted
  or compared is derived from a localized string: stat keys are the English enum names, the visibility
  contexts are unlocalized tokens, and `Visibility.ShouldShow`'s second return — which `/mm debug diag`
  prints and the tests assert on — is a stable token by design.
- **Classic support.** A single `## Interface` line, targeting Midnight. `C_DamageMeter` does not
  exist on any Classic client, so there is nothing to read.
- **A private tooltip frame.** `GameTooltip` costs us the ability to style it and buys every addon
  that hooks it, the player's tooltip skin, and the automatic repositioning that keeps a tooltip on
  screen.
- **Dps and Hps as separate columns.** `Enum.DamageMeterType.Dps` and `.Hps` are never queried:
  `amountPerSecond` ships on the same source row as `totalAmount`, so one `DamageDone` read fills
  both halves of the Damage column. A separate Dps column would be a second session read for a number
  already in hand.
- **A shipped bar texture — still not drawn here, but no longer for want of one.** The font and the
  icons this addon draws (JetBrains Mono under the OFL, Open Iconic under MIT) come from the bundled
  LibKa0s payload rather than from this repo, and since LibKa0s v1.9.2 that payload also carries
  seven statusbar textures registered with LSM as `Ka0s Gradient` and `Ka0s Underline` / `Overline`
  1, 2 and 4. **This addon does not select any of them.** Bars still default to an LSM statusbar the
  player already has, and both costs that kept a shipped texture out are now paid by the library
  rather than by this repo — a license notice beside the bytes, and one registry key for the whole
  collection. What is left is a default-value decision nobody has made, which is
  [issue #4](https://github.com/tusharsaxena/MultiMeters/issues/4)'s to make; a player who wants the
  Ka0s look can already pick it out of the dropdown.

## Known limitations

Everything this addon knows it cannot do, in one list. `docs/ARCHITECTURE.md` →
`## Known limitations` names the themes and links here; the entries live here because the list is
the longest thing the hub was carrying and a hub is an index.

### Caveats of the data source, not scope decisions

Two behaviors look like missing features and are limitations of what `C_DamageMeter` hands over.



**Pet attribution is best-effort.** The API exposes `sourceGUID` and `classification` but no explicit
owner link, so `modules/Roster.lua` matches pets to owners by asking `UnitGUID` for each member's pet
unit. That is exact for what it covers — `playerpet`, `partyNpet`, `raidNpet` — and covers nothing
else: guardians, totems, temporary summons, a second pet, or a pet whose owner is out of unit-API
range at build time. An unattributable ally — a guardian, a totem, a second pet — is shown as **its own row under its own
name** rather than dropped or folded into a guessed owner. A row that names itself is not the failure
the drop rule was written for: that rule is about one player's numbers appearing under another
player's *name*, and this row makes no claim about an owner. Enemies are still refused on
`sourceDisplayType`, which is never read as "anything that is not an enemy". A **delve companion** is
admitted alongside the explicit allies: the client files one under `None`, so a `None` source is kept
when its `classFilename` is a class `RAID_CLASS_COLORS` recognizes, and dropped otherwise.

**Percentage text slots go quiet in combat.** A percentage is a division. `modules/Aggregator.lua`
computes it once per cell when the operands are accessible and answers `nil` when they are not —
which is most of a pull — and `nil` means "cannot be known right now", never "zero percent". A column
configured to show percentages simply renders no text while restricted. This is why the text slots
default to total and rate.

### The rest


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
  [#24](https://github.com/tusharsaxena/MultiMeters/issues/24): `modules/Row_NameCell.lua`'s
  spec-icon branch fires for the local player's row and no other, so every other row draws the class
  icon. The fallback hides the cause, and that file's header is where the argument is written out.
  Blizzard's own meter shows the same thing on the same pull, so the ceiling here may be the
  client's rather than ours.

  Tracked as [#22](https://github.com/tusharsaxena/MultiMeters/issues/22). Nothing is fixed yet.
  What shipped is the instrumentation, one ordering bug it exposed (a key proved ambiguous by a late
  column used to keep cells an early column had already written), and the absent-field report that
  found the cause — see [testing.md](testing.md#capturing-an-identity-correlation-run).
- **The feign-death filter cannot run mid-pull, and that is structural.** `C_DamageMeter` hands a
  Feign Death a valid `deathRecapID`, so the Deaths column counts a hunter's feign as a death.
  `modules/Feign.lua` records the GUID off the cast and `modules/Aggregator.lua` drops that source —
  but the join is a plain GUID against `sourceGUID`, and `sourceGUID` is secret for the whole of a
  pull. That is the entire reason the aggregator has a second, GUID-free identity build, which lives
  in `modules/Aggregator_Identity.lua` rather than beside the drop in `modules/Aggregator.lua`.
  There is no plain key on the other side of the join while the restriction is up, so **a feign is
  counted as a death mid-pull and the count corrects itself the moment combat ends.** Do not "fix"
  this by keying on something secret; there is nothing to key on.
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
  recognizes**. That table is the oracle rather than a list of our own because the class filename is
  already what the grid draws a row from, in two files: `modules/Row.lua`'s `barColor` takes the
  bar's colour out of `RAID_CLASS_COLORS` itself (through `NS.ClassRGB`), and
  `modules/Row_NameCell.lua` keys the class icon on the same filename in `CLASS_ICON_TCOORDS`. What
  this refuses could only ever have drawn as an uncolored, iconless row. A mob would have to report
  `None` *and* carry a genuine class filename to slip through, and `/mm debug diag` prints the enemy
  column's display types so that a `None` there is reported rather than inferred from a wrong row.
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
  full argument is in [midnight-quirks.md](midnight-quirks.md#why-an-export-refuses-rather-than-degrades).
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
  [Deferred: scoring](#deferred-scoring) above.
- **No in-window column drag editor** — settings-panel only, and structurally so (rule R3).
- **Scrolling is the mouse wheel only — there is no scrollbar.** A window draws `layout.maxRows`
  rows chosen out of a longer list, so scrolling moves an integer offset rather than a scroll child;
  there is no widget to size and nothing measured. The cost is that a player cannot see there are
  rows above or below without trying the wheel.
- Debug logging is session-only (`NS.State.debug`) and resets on every `/reload`.
- **A refresh pass logs on change, not on every pass.** The `[Aggregator]` and `[Render]` summary
  lines go through `NS.DebugSteady`, which emits a change immediately and otherwise re-announces an
  unchanged run at most every 10 seconds as `… (xN)`. It is what keeps a 1500-line buffer holding
  hours rather than two minutes. Ratified as a deviation from debug-logging §8 — see
  [ARCHITECTURE.md](ARCHITECTURE.md#documented-deviations). Note the console's **Clear** button does not reset the comparison (the library offers the
  host no hook), so a freshly cleared console can sit silent until the next change or heartbeat.
- No automated in-client tests: headless suites plus manual in-game smoke tests.
- Published on CurseForge (`X-Curse-Project-ID: 1690082`). `X-Wago-ID` remains absent.

**The tooltip is the one thing this addon positions itself.** Everything else is laid out from config
and never anchored to a frame that has held a meter value (rule R3) — but the eight tooltip anchors
name boxes of a 3×3 around the hovered cell, and Blizzard's `SetOwner` tokens cannot express the four
diagonals at all. So `modules/Tooltip.lua` calls `SetOwner` with the closest token first and then lays
a `SetPoint` over it. That `SetPoint` anchors GameTooltip to a cell with secret geometry, which is
the one call in the addon that could raise inside Blizzard's own code while tainted by us. It is
`pcall`'d, and a failure leaves the token's placement standing: the tooltip opens in roughly the
right place rather than not at all.

## The unverified assumption

`provider` sort mode treats the order the API returns `combatSources` in as "sorted by the requested
statistic, descending". **Nothing in Blizzard's documentation states that.** It is an assumption taken
from how the built-in meter displays, and it is isolated in `modules/Provider.lua`'s header because
that file is the only place a correction would land — `value` and `roster` modes do not depend on it.
If it proves false in-game, the fix is a sort inside `GetColumn` and no other file changes.

It is now **measured rather than left standing**: `/mm debug diag`'s **provider order** section walks
each column out of combat, where the amounts are plain, and reports `ranked, descending` or
`NOT ranked` with the index where the order broke. Inside a pull it refuses with `cannot be checked`
rather than reporting an all-clear it could not earn. Identity mode takes row *identity* from
position, so a wrong order here is a wrong grid rather than only a wrong order — which is why the
assumption is worth a probe instead of a comment.
