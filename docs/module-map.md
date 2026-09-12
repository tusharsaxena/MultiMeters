# Module map

Where each responsibility lives, what each file publishes, and what it consumes. `MultiMeters.toc`
is the source of truth for load order — check this map against it before editing.

Fifty-seven non-vendored source files: 1 locale, 17 `core/`, 1 `defaults/`, 23 `modules/`,
15 `settings/`.

Thirteen of those arrived on one day, 2026-09-09, and **not one of them is a new module.** They are
peels. `layout-§1` caps an authored file at 1500 lines; seven source files were over it —
`settings/Schema.lua` at 3080, `modules/Tooltip.lua` at 2774, `modules/Window.lua` at 2746,
`modules/Aggregator.lua` at 2122, `core/Diagnostics.lua` at 1867, `modules/Row.lua` at 1829 and
`modules/Export.lua` at 1790 — and each was cut along a seam its own header had already named rather
than at whatever line brought it under. Nothing was rewritten on the way out: a reader chasing a
behaviour into a peeled file is reading the block that used to sit under a banner in its parent.

That is also why so many of the new TOC lines are load-bearing and say so at the line. A peel hangs
its functions on the **same** prototype or module table its parent builds, so the parent publishes
what used to be a file-local — `NS.WindowProto`, `NS.RowInternals`, `NS.TooltipInternals`,
`Aggregator._identity`, `Export.__cfgOf`, `NS.SchemaCompose` — and the child resolves it at **file
scope**. A child that loaded first would not raise: it would freeze a table of nils in for the life
of the session. Check a peel's position against `MultiMeters.toc` before moving it.

Two rules govern almost every entry below, and they are worth having in mind while reading it:

- **R1** — `modules/Provider.lua` is the only caller of `C_DamageMeter` (through `core/Compat.lua`'s
  shims), and `core/Secrets.lua` is the only file that inspects a meter value. Everywhere else a
  value is an opaque handle.
- **R3** — layout is computed from config and never read back off a frame that has held a value.

Full reasoning in [data-flow.md](data-flow.md) and [ARCHITECTURE.md](ARCHITECTURE.md#taint-notes).

## Directory tree

```
MultiMeters (AceAddon; the private NS table is promoted in place — no _G.MultiMeters)
├── locales/
│   └── enUS.lua        — NS.L, with the key-is-the-string metatable fallback.
│                         Loads FIRST, ahead of core/, and bootstraps the namespace
├── core/
│   ├── Compat.lua      — every cross-patch API call: C_Spell,
│                         C_SpecializationInfo, all eight C_DamageMeter reads and
│                         C_StringUtil.CreateNumericRuleFormatter. 28 shims, no logic
│   ├── EnvSetup.lua    — the LibKa0s-Env seam: NS.Meta / NS.Version, the TOC-manifest
│                         reader Compat used to own. BEFORE Namespace.lua, which
│                         resolves NS.version at file scope
│   ├── Constants.lua   — NS.Constants / NS.Const: the STAT CATALOG (8 rows), the
│                         SHIPPED per-stat palette (STAT_COLORS + STAT_DIM), which
│                         seeds the statColors.* setting and is the fallback
│                         NS.StatColor degrades to, the off-catalog reads
│                         (EnemyDamageTaken — read, never a column), the
│                         enum resolutions, the MSG bus catalog (14 names), throttle
│                         bounds, pool and row caps, the shipped mono font
│   ├── Namespace.lua   — identity (NS.PREFIX, NS.name, NS.version, NS.GRAY),
│                         the one class-color reader (NS.ClassRGB /
│                         NS.PlayerClassRGB) and NS.NewBusTarget(), the
│                         private-bus-target factory
│   ├── State.lua       — session-only flags (debug, debugTooltip, restricted,
│                         testMode, activeWindowId) and the shared per-module cache
│                         with its one wipe seam. Nothing here is ever persisted
│   ├── Secrets.lua     — THE ONLY VALUE INSPECTOR (R1). Restriction state,
│                         IsSecret / CanAccess / CanCompare / CanCompare2,
│                         CanAccessTable, SafeIterate, SafeCount
│   ├── CoreSetup.lua   — LibKa0s-Core-1.0 seam: the secret-safe NS.PREFIX-tagged
│                         printer (NS.Print === NS.Util.print), NS.IsConcatSafe /
│                         NS.SafeToString, NS.RGBA, NS.SKIN / NS.ApplySkin /
│                         NS.MakeCloseButton, and NS.LIBKA0S_MISSING
│   ├── PerfSetup.lua   — LibKa0s-Perf-1.0 seam: NS.Perf, the 8 buckets, and the
│                         suspend/resume that makes the addon inert without a reload
│   ├── DebugLogSetup.lua — LibKa0s-DebugLog-1.0 seam: NS.DebugLog, the bare
│                         NS.Debug(tag, fmt, …) sink, and NS.DebugSteady — the
│                         same sink for a pass that repeats on a timer
│   ├── PoolSetup.lua   — LibKa0s-Pool-1.0 seam: NS.Pool, the window row pool's
│                         free/active halves. After libs/, BEFORE modules/Window.lua,
│                         its only consumer. RANK STABILITY IS THE LIBRARY'S — minor 3
│                         parks the active set backward — and the degraded fallback
│                         here parks the same way rather than flickering
│   ├── MediaSetup.lua  — the LibKa0s-Media seam: NS.Icon / NS.MediaFont, and the one
│   │                     call that registers the library's font with LSM. Loads BEFORE
│   │                     Constants, which resolves FONT_MONO from it
│   ├── MultiMeters.lua — AceAddon bootstrap, the AceConsole printer reclaim, THE
│                         SINGLE GAME-EVENT LISTENER (22 events, the last of them
│                         PROBED, all but two fanned onto the bus), and
│                         NS.ShouldShow — the one show ladder
│   ├── Database.lua    — the AceDB instance, window-shape key-fill, the id counter,
│                         SeedWindows, the migration runner, and the ONE
│                         PROFILE_CHANGED emitter
│   ├── Diagnostics.lua — `/mm debug diag`: the sectioned report a player pastes into
│   │                     a bug report. Reads modules at CALL time, owns no state,
│   │                     and every section is pcall-wrapped so one broken probe
│   │                     cannot take the report down. Also the FRAME the three
│   │                     probes below hang off: it publishes the shared print
│   │                     helpers (out, safe, shown, probe, SECRET) they take off
│   │                     the table rather than redefine
│   ├── Diagnostics_DeathRecap.lua
│   │                   — `/mm debug recap`: can issue #1's Death Recap window be
│   │                     built at all. Rides along in `/mm debug diag` too, so its
│   │                     section goes back onto the shared table
│   ├── Diagnostics_Identity.lua
│   │                   — `/mm debug identity`: the issue #22 identity-correlation
│   │                     measurement. NOT part of `/mm debug diag`; the entry point
│   │                     at the foot of the file is the only way in
│   └── Diagnostics_Feign.lua
│                       — `/mm debug feign`: the issue #25 feign recording. The one
│                         probe carrying STATE — the ring, its write index and the
│                         armed flag modules/Feign.lua and modules/Aggregator.lua
│                         read through NS.Diagnostics at call time
├── defaults/
│   └── Profile.lua     — NS.defaults, NS.WINDOW_TEMPLATE, NS.DefaultWindow(). The
│                         only place a profile default is hardcoded
├── modules/
│   ├── Format.lua      — the NumericRuleFormatter instances and every text
│                         assembly. NS.Format is a CALLABLE TABLE (index → number
│                         formatter, call → chat printer); NS.Numbers and
│                         NS.NumberFormat are the same object
│   ├── Provider.lua    — THE ONLY READER OF THE METER (R1). Columns, per-source
│                         detail, session list, duration, reset, and the perf
│                         suspend that stops the addon ASKING
│   ├── Roster.lua      — group membership, pet→owner attribution, roles. Built
│                         from the unit API only; no meter value ever enters it
│   ├── Feign.lua       — the one source row the addon throws away. C_DamageMeter
│   │                     gives a Feign Death a valid deathRecapID, so a hunter's
│   │                     feign is reported as a death; this holds the GUIDs that
│   │                     are feigning. Cannot run mid-pull -- see its header.
│   ├── Aggregator.lua  — the GUID join, group filtering, pet folding, the three
│   │                     sort modes, the row cap, and the only two divisions in
│   │                     the addon. Chooses per pass between the join and the
│   │                     identity build below
│   ├── Aggregator_Identity.lua
│   │                   — the grid drawn while sourceGUID is SECRET, and the
│   │                     rectangle that measures how much of it got filled.
│   │                     Shares the row-assembly helpers through
│   │                     Aggregator._identity and hands buildByIdentity back
│   ├── Aggregator_Preview.lua
│   │                   — the invented meter: the test rows a player laying out
│   │                     columns at a target dummy sees. Reads nothing the
│   │                     aggregator holds, which is what made it the cheap cut
│   ├── WindowManager.lua — the window REGISTRY: create / delete / rename /
│                         duplicate / copy-from, lock, test mode, toggle. The ONE
│                         WINDOWS_CHANGED emitter
│   ├── Window.lua      — one window instance and its LOOP: the anchor/visible
│   │                     frame pair, the layout computation (R3), frame
│   │                     construction, ApplyConfig, the row pool and the coalesced
│   │                     refresh. Publishes WindowProto for the two files below
│   ├── Window_Header.lua
│   │                   — the header BAND of one window: the title bar, the session
│   │                     line, the column labels, the sort a click on one performs,
│   │                     the segment dropdown, the notices, and NS.HeaderStyle
│   ├── Window_Placement.lua
│   │                   — where a window SITS and whether it is there at all:
│   │                     position, size, resize bounds, lock, show/hide and the
│   │                     visibility refresh. Saves off inst.anchor, never
│   │                     inst.frame (R3)
│   ├── HeaderControls.lua — the window's own control strip: which controls exist,
│                         where each sits (right-to-left, a hidden one yields its
│                         slot), the TGA → Blizzard atlas → ASCII art ladder, and
│                         when the set fades. Built here with or without LibKa0s
│   ├── Row.lua         — one row and its cells: the StatusBar + two FontStrings,
│   │                     the bar colors, the text styling, the mouse hand-off, and
│   │                     the CELL DESCRIPTOR Tooltip.lua and DrillDown.lua read.
│   │                     Nothing here looks at a number
│   ├── Row_NameCell.lua — the LEADING column's cell alone: the icon strip, the name
│   │                     string, and the two decisions that keep them clear of each
│   │                     other. Two more methods on the same Cell prototype — the
│   │                     block every identity and pet-fold change lands in
│   ├── Targets.lua     — the enemy cross-reference: reconstructs "who did this
│                         player hit" out of the EnemyDamageTaken data — which is
│                         read, never a column of this grid (issue #2) — and
│                         refuses outright rather than summing secrets
│   ├── Tooltip.lua     — the PRIMITIVES every hover is built out of: the secret
│   │                     wrappers, the name and window resolution, the styling and
│   │                     placement, the spell collection and its legal-only sort,
│   │                     and Tooltip:Hide. Publishes them as NS.TooltipInternals
│   ├── Tooltip_Lines.lua — ONE POOLED LINE as a widget: the carrier frame and its
│   │                     bar, the text measurement the widths rest on, the slot
│   │                     layout and the draw, plus the four death helpers that
│   │                     decide what a death line's label says
│   ├── Tooltip_Builders.lua
│   │                   — WHAT A HOVER SAYS: the death events behind one death
│   │                     (issue #1) and the four tooltips — Targets, the per-cell
│   │                     spell breakdown, the whole-player summary on a name, and
│   │                     the spell row inside a breakdown. The part a feature adds to
│   ├── DrillDown.lua   — per-player per-stat breakdown rendered through the SAME
│                         row path, right-click-to-leave, and the death-recap hand-off
│   ├── Export.lua      — the PURE half: a segment as CSV or as ranked chat lines,
│   │                     the channel resolution and the throttled send. Draws no
│   │                     frame. Refuses outright while restricted
│   ├── Export_Modal.lua — the UI half: the dialog the header glyph and `/mm export`
│   │                     open, its three selectors, the whisper row, the two action
│   │                     buttons and the copy-paste window. Every frame this
│   │                     feature draws is here. Re-checks the combat refusal on
│   │                     every click, because a pull can start while it is open
│   ├── Visibility.lua  — the context predicate. Publishes no message and touches
│                         no frame; refuses at the source
│   └── Minimap.lua     — the LibDataBroker launcher and its LibDBIcon button
└── settings/
    ├── Schema_Compose.lua
    │                   — WHAT THE ARRAY IS DECLARED OUT OF and nothing else: the
    │                     refresh routing a row's onChange reaches for, the dropdown
    │                     vocabularies, the common validators, and the
    │                     LibKa0s-Options-1.0 composers with every canonical block
    │                     composed out of them. Holds no row of its own. Published
    │                     once as NS.SchemaCompose; loads FIRST of the three
    ├── Schema.lua      — NS.Schema: the 169-row array itself, and nothing else. The
    │                     composers decide WHICH rows there are; this file decides
    │                     where each one sits. This is the file that grows, and a
    │                     new setting is still one row in it
    ├── Schema_Paths.lua — THE PATH MACHINERY and the seams every reader and writer
    │                     of a setting lands on: the window-relative path model, the
    │                     path index rebuilt off NS.Schema, GetSetting, SetByPath,
    │                     FindSchemaRow, RegisterSchemaRows, ApplyDefault,
    │                     SchemaForPage, ValidateSchema and the columns carve-out.
    │                     Names no single setting. THE ONE CONFIG_CHANGED SENDER
    ├── Slash.lua       — LibKa0s-Slash-1.0 seam: NS.COMMANDS (16 verbs), the five
    │                     schema adapters, and the six host verbs
    ├── OptionsSetup.lua — LibKa0s-Options-1.0 seam: NS.Helpers IS the library
    │                     instance, plus the panel registry and the reset-all veto
    ├── ColumnBlocks.lua — the ROW CONTENTS of the Columns page's reorderable
    │                     list. The gesture and the chrome are LibKa0s-Widgets-1.0's
    │                     ReorderList; loads BEFORE Columns.lua
    └── General · Windows · Frame · Header · Bars · Tooltip ·
        Visibility · Columns · Profiles
                          — the 9 panel pages, in panel order. General is FIRST;
                          the six between Windows and Profiles are drawn with a
                          "  - " indent, because the banner (H.WindowBanner) can
                          retarget them to a different window
```

## What each file publishes and consumes

### `locales/`

| File | Owns | Publishes | Consumes |
|---|---|---|---|
| `enUS.lua` | Every user-facing string, organized page by page in panel order | `NS.L` | nothing — loads first |

`L` carries the mandated metatable fallback: a missing key returns the key itself. Never hand this
table to a LibKa0s descriptor's `L` field — it answers for *every* key and would shadow the library's
own strings entirely.

### `core/`

| File | Owns | Publishes | Consumes |
|---|---|---|---|
| `Compat.lua` | All 28 cross-patch shims — the TOC-manifest reader is no longer among them; it moved to `EnvSetup.lua`. Never inspects a meter value; reading a field off a session table and passing it on is not inspection | `NS.Compat` | `_G` only |
| `Constants.lua` | The stat catalog, the **shipped** per-stat palette (`STAT_COLORS`, the seed for the `statColors.*` setting and the fallback every `NS.StatColor` call degrades to, plus the `STAT_DIM` factor), the two stat lookups — `STAT_BY_KEY` ("may this be a column") and `READABLE_STAT_BY_KEY` ("may this be read", the catalog plus `OFF_CATALOG_STATS`), enum resolutions, the `MSG` catalog, timing and pool bounds, the monospace font path (resolved from the LibKa0s payload, falling back to the client font) and its LSM key | `NS.Constants`, `NS.Const` | `_G.Enum`, `NS.MediaFont` |
| `EnvSetup.lua` | The LibKa0s-Env seam: this addon's TOC manifest, and the one place the manifest-then-constant version pair is resolved. Repeats the reader ladder itself on a degraded install, so an install missing LibKa0s still reports its packaged version | `NS.Meta`, `NS.Version` | `LibKa0s-Env-1.0`, `NS.version` at call time. Owns no state and registers no event |
| `Namespace.lua` | Addon identity, the collection's one class-color reader (four surfaces can wear one — the bars and cell text in `Row.lua`, both header strips in `Window.lua`, the tooltip), the one **statistic**-palette reader beside it (`NS.StatColor`, which reads the `statColors.*` setting and falls back to `Constants.STAT_COLORS`) and the bus-target factory. No side effects at all | `NS.PREFIX`, `NS.GRAY`, `NS.name`, `NS.version`, `NS.FALLBACK_VERSION`, `NS.ClassRGB`, `NS.PlayerClassRGB`, `NS.StatColor`, `NS.NewBusTarget` | `NS.Meta`, `_G.RAID_CLASS_COLORS`, `_G.UnitClass` |
| `State.lua` | The five session flags, each with exactly one named writer — `debugTooltip` is the tooltip log channel, off by default and written only by `/mm debug tooltip` (see [debug.md](debug.md)) — and `State.Cache` / `State.WipeCache` (wipes **in place**, so a module may hold its sub-table as an upvalue) | `NS.State` | `NS.Constants.MSG` |
| `Secrets.lua` | Restriction state, per-value and per-table inspection, and the two bounded walks. Correct when the whole secrets system is absent | `NS.Secrets` | `_G.C_RestrictedActions`, `_G.issecretvalue` and friends |
| `MediaSetup.lua` | The LibKa0s-Media seam: where the icons and the monospace face come from, and the one call that registers the face with LibSharedMedia. Answers `nil` for both on a degraded install, which is what sends the header down its art ladder | `NS.Icon`, `NS.MediaFont` | `LibKa0s-Media-1.0`, LibSharedMedia. Owns no state and registers no event |
| `CoreSetup.lua` | The LibKa0s-Core seam and the shared "library missing" cause clause. `NS.MakeCloseButton` is the one member WRAPPED rather than handed over: it supplies the addon folder name the library needs to build a texture path for its own close icon | `NS.Util.print` / `NS.Print`, `NS.Format` (printer, later rebound), `NS.IsConcatSafe`, `NS.SafeToString`, `NS.RGBA`, `NS.SKIN`, `NS.ApplySkin`, `NS.MakeCloseButton`, `NS.LIBKA0S_MISSING` | `NS.PREFIX` |
| `PerfSetup.lua` | The perf descriptor: bucket list, suspend, resume, log routing | `NS.Perf` | `NS.Version`, and `Provider` / `WindowManager` / `Visibility` at call time |
| `DebugLogSetup.lua` | The console descriptor (including `addonName`, which is what makes the console's own close/copy/clear draw the collection's art), the debug sink, and the steady-state sink a timer-driven pass logs through | `NS.DebugLog`, `NS.Debug`, `NS.DebugSteady`, `NS.DebugSteadyReset` | `NS.Constants.FONT_MONO`, `NS.State.debug`, `NS.Print`, `NS.SafeToString` |
| `PoolSetup.lua` | The LibKa0s-Pool seam: the free/active halves of the window row pool. What stays in `modules/Window.lua` is what the library holds no opinion about — `pool.all` (every row ever built, so a **parked** row is re-laid-out too) and batch growth, folded into the `Acquire` factory closure. The degraded fallback is the same three members locally, parking **backward** exactly as `LibKa0s-Pool-1.0` minor 3 does; a forward-parked degraded install is the rank flicker back | `NS.Pool` | `LibKa0s-Pool-1.0`. Owns no state and registers no event |
| `MultiMeters.lua` | AceAddon promotion, the printer reclaim, all 22 game-event registrations (21 outright plus `PLAYER_IS_GLIDING_CHANGED`, probed), the fan-out onto the bus, and `NS.ShouldShow` | `NS.addon`, `NS.ShouldShow`, `NS:OnInitialize` / `OnEnable` | `NS.Constants.MSG`, `NS.State`, `NS.Secrets`, `NS.Minimap`, `NS.CreateOptionsPanel`, `NS.Slash` |
| `Database.lua` | The AceDB instance, window shape key-fill, the monotonic id counter, seeding, migrations, and the AceDB profile callbacks | `NS.Database` (`GetWindows`, `FindWindow`, `NextWindowId`, `SeedWindows`, `EnsureWindowShape`), `NS.db`, `NS:InitDB`, `NS:RunMigrations` | `NS.defaults`, `NS.WINDOW_TEMPLATE`, `NS.DefaultWindow`, `NS.Constants.MSG` |
| `Diagnostics.lua` | The `/mm debug diag` report: atlas probes, the formatter ladder, visibility, header, name column, cells, tooltip font and width, the Targets cross-reference, and the provider-order probe. Every section is `pcall`-wrapped, and nothing here inspects a meter value. It is also the FRAME the three probe files hang off — the print helpers are defined once, here | `NS.Diagnostics` (`Report`, `SetEmit`) and, for the three files below, the shared helpers `out` / `safe` / `shown` / `probe` / `SECRET` | `NS.DebugLog`, `NS.Print`, `NS.Provider`, `NS.Constants.STATS`, `NS.Database`, `NS.Secrets`, `NS.WindowManager` |
| `Diagnostics_DeathRecap.lua` | `/mm debug recap` — issue #1's question, asked in one place: can a Death Recap window be built at all, and what does the recap API actually hand back. Self-contained, so it can be deleted with its issue; it also rides along in `/mm debug diag`, which is why its section function goes back onto the shared table | `Diagnostics.ReportDeathRecap`, `Diagnostics.reportDeathRecap` (the section the frame calls) | `NS.Diagnostics` and its print helpers, **at file scope** — the reason its TOC line must follow `core/Diagnostics.lua` |
| `Diagnostics_Identity.lua` | `/mm debug identity` — the issue #22 identity-correlation measurement: which fields could key a row while `sourceGUID` is secret, and what each one costs when it is absent. **Not** part of `/mm debug diag`; nothing in the frame reaches into it | `Diagnostics.ReportIdentity` | `NS.Diagnostics` and its `out`, **at file scope**. Prints through the frame's `out` rather than a second printer, so a line from here takes the route the report set |
| `Diagnostics_Feign.lua` | `/mm debug feign` — the issue #25 recording, and the sink the trace writes to. The one probe that is not purely a read and the one that carries STATE: a bounded ring, its write index, and the armed flag `modules/Feign.lua` and `modules/Aggregator.lua` check through `NS.Diagnostics` at the three boundaries a feign crosses. Armed before a run, printed after it | `Diagnostics.ArmFeignTrace`, `IsFeignTraceArmed`, `TraceFeign`, `ReportFeign`, `Diagnostics.feignArmed` | `NS.Diagnostics` and its print helpers, **at file scope** |

**Sends:** `MultiMeters.lua` sends `ENTERING_WORLD`, `ROSTER_CHANGED`, `ZONE_CHANGED`,
`RESTRICTION_CHANGED`, `METER_UPDATED`, `METER_SESSION`, `METER_RESET`, `COMBAT_CHANGED` and
`PLAYER_STATE_CHANGED`. `State.lua` sends `TEST_MODE_CHANGED`. `Database.lua` sends
`PROFILE_CHANGED`.

### `defaults/`

| File | Owns | Publishes | Consumes |
|---|---|---|---|
| `Profile.lua` | The window template (`frame`, `header`, `rows`, `bars`, `text`, `icons`, `tooltip`, `visibility`, `columns`, `data`) and the near-empty profile around it: the window array, the id counter, `enabled`, `minimap` | `NS.defaults`, `NS.WINDOW_TEMPLATE`, `NS.DefaultWindow(id, name)` | `NS.Constants` (stat catalog, font name) |

The default window ships six columns, derived from the catalog's `defaultEnabled` flags rather than
restated: Damage · Healing · Interrupts · Dispels · Avoidable Damage · Deaths.

### `modules/`

| File | Module? | Owns | Publishes | Consumes |
|---|---|---|---|---|
| `Format.lua` | plain table | The `NumericRuleFormatter` instances and the three-rung degradation ladder. No division of a meter value, anywhere | `NS.Format` (callable table), `NS.Numbers`, `NS.NumberFormat` — `Number`, `Rate`, `Duration`, `Percent`, `Invalidate` | `NS.Compat.CreateNumericRuleFormatter`, `NS.Secrets`, `NS.State.Cache("Format")`, `NS.L`. Subscribes `CONFIG_CHANGED`, `PROFILE_CHANGED` on a private bus target |
| `Provider.lua` | AceAddon | Every meter read, the memoized availability answer, and the suspend flag | `NS.Provider` — `GetColumn`, `GetSourceDetail`, `GetAvailableSessions`, `GetSessionDuration`, `IsAvailable`, `InvalidateAvailability`, `ProbeSourceByGuid`, `ProbeSourceLookup`, `ProbeSourceFields`, `Reset`, `Suspend` / `Resume` / `IsSuspended` | `NS.Compat`, `NS.Secrets`, `NS.Constants.STAT_BY_KEY`. Subscribes `METER_RESET`, `METER_SESSION`, `ENTERING_WORLD`. **Sends `METER_RESET`** from `Provider.Reset` |
| `Roster.lua` | AceAddon | The group array, the GUID index, the pet→owner map, roles. Rebuilt lazily on first read after an invalidation | `NS.Roster` — `GetGroup`, `Get`, `IsGroupMember`, `OwnerOf`, `RoleOf`, `Refresh`, `Forget` | the unit API through `_G` at call time, `NS.State.Cache("Roster")`, and the remembered map at `db.global.roster`, which it owns. Subscribes `ROSTER_CHANGED`, `ENTERING_WORLD`, `PROFILE_CHANGED`, `TEST_MODE_CHANGED`, and `METER_RESET`, which is what forgets the remembered map |
| `Feign.lua` | AceAddon | The set of GUIDs believed to be feigning rather than dead. `C_DamageMeter` hands a Feign Death a valid `deathRecapID`, so the Deaths column counts it. **Cannot run while restricted**: it joins a plain GUID against `sourceGUID`, which is secret for the whole of a pull | `NS.Feign` — `Note`, `IsFeigned`, `Prune`, `Clear` | the unit API through `_G` at call time, `NS.Roster.GetGroup`, `NS.Secrets`. Subscribes `METER_RESET`, `ENTERING_WORLD`, `ROSTER_CHANGED`. Fed by `core/MultiMeters.lua`'s `UNIT_SPELLCAST_SUCCEEDED` handler, which owns the only game event |
| `Aggregator.lua` | AceAddon | The exact GUID join — filter, pet folding, ordering, the one-stage-at-a-time scan — the row cap and `percent`, and the choice, once per pass, between that join and the identity build next door. The build pipeline is **one algorithm** and issue #30 forbids cutting inside it, which is what decided where the peels went | `NS.Aggregator` — `Build`, `ApplyRowLimit`, `LastIdentityStats`; plus `Aggregator._identity`, the private seam carrying the row-assembly helpers (`newRow`, `setCell`, `isEnemySource`, `plainTruth`, `UNRANKED`) the identity build shares with the join | `NS.Provider`, `NS.Roster`, `NS.Secrets`, `NS.State.Cache("Aggregator")`. Subscribes `METER_RESET`, `PROFILE_CHANGED` |
| `Aggregator_Identity.lua` | — | The grid drawn while `sourceGUID` is secret, and the rectangle that measures how much of it got filled: the correlation pass, the collision bookkeeping and the per-pass identity statistics. It exists because the client stopped handing out GUIDs, and it asks a question the join never asks | `Aggregator._identity.buildByIdentity`, and `lastIdentityStats` on the same seam — the one private the peel had to publish, written at the end of a pass here and read by `Aggregator.LastIdentityStats` there | `NS.Aggregator`, `NS.Provider`, `NS.Roster`, `NS.Secrets`, `NS.Constants`, and the five `Aggregator._identity` helpers — all **at file scope**, which is what pins its TOC line after `modules/Aggregator.lua` |
| `Aggregator_Preview.lua` | — | The invented meter: the placeholder group, spells and scaling a player sees when they unlock a window at a target dummy. Placeholder data is required of any addon with a positionable display | `NS.Aggregator.TestGroup`, `TestColumn`, `TestRecap`, `TestSourceDetail` | the module table, and nothing else. **No upvalue crosses the line in either direction** — which is what made this the cheapest second cut once the identity seam had not got the file under on its own. `Provider`, `Roster`, `Tooltip` and `DrillDown` reach these four at call time, behind an `and`, exactly as before |
| `WindowManager.lua` | AceAddon | The live instance registry and every runtime mutation of the window list: the `architecture-§5` registry writer, with the load pass (`Database.SeedWindows`) the only other writer. Deep-copies on duplicate and copy-from | `NS.WindowManager` — `Resolve`, `Get`, `All`, `Init`, `Create`, `Delete`, `Rename`, `Duplicate`, `CopyFrom`, `RefreshAll`, `MarkAllDirty`, `ResetPosition(s)`, `SetLocked` / `IsLocked`, `SetTestMode` / `IsTest`, `Toggle`, `BuildListLines`, `Suspend` / `Resume`, `COPY_GROUPS` | `NS.Database`, `NS.Window`, `NS.State`, `NS.DefaultWindow`. Subscribes `PROFILE_CHANGED`. **The one `WINDOWS_CHANGED` sender** |
| `Window.lua` | plain table + prototype | One instance and its **loop**: the anchor/visible frame pair, `BuildLayout` (R3), `RefreshUpvalues`, `BuildFrame`, `ApplyConfig`, `ApplyBorder`, the row pool, the scroll, the `OnUpdate` throttle, `Refresh` and `Render`, plus the bus registration and teardown. Issue #29 names that chain as one causal sequence and forbids cutting inside it — splitting it would put a reader on two files to follow one frame | `NS.Window.New(config)` and the loop's `WindowProto` methods; and, for the two files below, `NS.WindowProto`, `NS.WindowFontPath`, `NS.SurfaceColor` and `NS.WindowModule` | `NS.Constants`, `NS.Row`, `NS.Provider`, `NS.Aggregator`, `NS.DrillDown`, `NS.ShouldShow`, `NS.Format`, `NS.ApplySkin`. Each instance subscribes 10 messages on **its own** private bus target |
| `Window_Header.lua` | — | The header **band**: the sort art and its ladder, the title bar, the session line, the column labels above the grid, the sort a click on one of those labels performs, the segment dropdown, the session label, the restricted notice and the unavailable notice. The band is computed from config and read back from nothing at all, which is why it separates from the loop cleanly | `NS.HeaderStyle(window)` (the header's font and colour, read by `modules/HeaderControls.lua` at call time), and the band's `WindowProto` methods — `ApplyHeader`, `ApplyTitle`, `ApplyHeaderStrip`, `ApplySessionLine`, `ApplyColumnHeaders`, `ApplyMinimised`, `SortByColumn`, `SetSegment`, `SetSessionType`, `OpenSegmentMenu`, `UpdateHeaderText`, `ShowNotice`, and `TitleRowTop(h)` — the one centre line the title, the session line and the control strip are all placed against | `NS.WindowProto`, `NS.WindowFontPath`, `NS.SurfaceColor`, `NS.WindowModule`, `NS.Constants`, `NS.L`, `NS.PlayerClassRGB`, `NS.RGBA` — the first four **at file scope**, which is what makes its TOC position load-bearing |
| `Window_Placement.lua` | — | Where a window sits, how big it is, whether it is locked, and whether it is on screen at all — everything the player's hands and the visibility ladder do to the frame, as against what the loop draws inside it. **R3 did not weaken on this side of the seam**: `SavePosition` and `SaveSize` ask `inst.anchor`, the bare frame that has never held a meter value, and never `inst.frame` | the placement `WindowProto` methods — `ApplyPosition`, `SavePosition`, `SaveSize`, `ApplyResizeBounds`, `ApplyLock`, `RefreshVisibility`, `Show`, `ClearForcedShow`, `Hide`, `IsShown` | `NS.WindowProto`, **at file scope** |
| `HeaderControls.lua` | plain table | The window's own control strip: which controls exist, where each sits (right-to-left, indexed, a hidden one yields its slot), what art each draws from (our TGA -> Blizzard atlas -> ASCII) and when the set fades | `NS.HeaderControls` — `Attach`, `Apply`, `HookHover`, `WidthUsed` | `NS.Compat.FirstTexture` / `FirstAtlas`, `NS.SetByPath`, `NS.HeaderStyle`, `NS.ShowResetMeterData`. Every control in the strip is built here, close included, so the strip is the same seven controls with or without LibKa0s. Owns no state and registers no event |
| `Row.lua` | plain table + prototype | Row and cell widgets, **the cell descriptor** — the contract `modules/Tooltip.lua` and `modules/DrillDown.lua` both read, documented once here so neither the peel nor they restate it — the bar skin and border, the four colour rules, the text style, `SetValue`, and the mouse hand-off | `NS.Row.New(window)`, `NS.Row.OffsetFor(layout, index)`, and `NS.RowInternals` (`Cell`, `cellBackground`, `CLASS_TEXTURE`) for the file below | `NS.Constants`, `NS.RGBA`, `NS.Format` / `NS.NumberFormat`, and `NS.Tooltip` / `NS.DrillDown` resolved at call time |
| `Row_NameCell.lua` | — | The leading column's cell alone: the icon strip, the name string, and the two decisions that keep them clear of each other. A sibling rather than a new widget — it hangs two more methods on the **same** `Cell` prototype — and the block that grows, since every identity, spec-icon and pet-fold change lands in it. `Row.lua`'s rules bind unchanged: no arithmetic on a meter value, and no `GetWidth` / `GetLeft` / `GetPoint` anywhere (R3) | `Cell:ApplyIcons`, `Cell:SetPlayer`, `NS.ICON_TEXT_GAP` | `NS.RowInternals`' three members **at file scope** — the reason its TOC line sits after `modules\Row.lua` — and `NS.Secrets`, for exactly one question: may this GUID be looked at |
| `Targets.lua` | plain table | The enemy cross-reference. One walk over every `EnemyDamageTaken` source's spells builds **every** player's target list at once, keyed on `combatSpellDetails.unitName` and cached per session. **All-or-nothing**: one unreadable amount abandons the whole build | `NS.Targets` — `ForPlayer`, `Total`, `Invalidate` | `NS.Provider.GetColumn` / `GetSourceDetail`, `NS.Secrets`, `NS.State.Cache("Targets")`. Subscribes `METER_RESET`, `METER_SESSION`, `METER_UPDATED`, `PROFILE_CHANGED` on a private bus target |
| `Tooltip.lua` | AceAddon | The **primitives** every hover is built out of, and the teardown: the secret-safe wrappers (`unreadable`, `plainWord`, `plainTruth`), the display name and its colour, the resolved config, font and placement, the spell collection and its legal-only sort, the shared line pool's font handling, and `Tooltip:Hide` (which restores the SHARED line FontStrings). This is the half that must not be touched casually, which is why it is the half that stayed | `NS.Tooltip` — `Hide` — and `NS.TooltipInternals`, the private table the other two files of the peel resolve at file scope | `NS.Provider`, `NS.Secrets`, `NS.Numbers`, `NS.Compat.GetSpellInfo`, `NS.WINDOW_TEMPLATE`, `NS.Database.FindWindow` |
| `Tooltip_Lines.lua` | — | **One pooled line, as a widget**: the carrier frame and its bar, the text measurement every width rests on, the slot layout, the resolved style and the draw itself — plus the four death helpers that decide what a death line's label says before anything is drawn | `Tooltip.WidthParts(style)`, and the drawing primitives it fills in on the second half of `NS.TooltipInternals` | every name it uses off `NS.TooltipInternals`, **at file scope** — a position before `modules/Tooltip.lua` would freeze a table of nils in for the session — plus `NS.L` and `NS.Compat` |
| `Tooltip_Builders.lua` | — | **What a hover says**: the death events behind one death (issue #1), and the four tooltips the primitives assemble — Targets (which enemies this player hit), the per-cell spell breakdown, the name tooltip that summarizes every tracked statistic for one player, and the spell row inside a breakdown. This is the part a feature adds to | `Tooltip:CellTooltip`, `Tooltip:NameTooltip`, `Tooltip:SpellTooltip` | `NS.TooltipInternals` **at file scope**, and the second half of that table is not filled until `modules/Tooltip_Lines.lua` has run — so its TOC line follows **both**. Also `NS.Constants`, `NS.Compat`, `NS.State`, `NS.Debug`, `NS.L`. The secrets rule binds hardest here, because this is where "just show the top five" and "put the total at the bottom" would be written |
| `DrillDown.lua` | AceAddon | Per-window view state (session-only, in `State.Cache`), the spell-row contract, click routing, the death recap | `NS.DrillDown` — `GetState`, `IsActive`, `Enter`, `Exit`, `ExitAll`, `OnCellClick`, `BuildRows`, `Title`, `AcquireBackButton`, `ReleaseBackButton` | `NS.Provider`, `NS.Secrets`, `NS.Compat`, `NS.Database.FindWindow`. Subscribes `METER_RESET`, `PROFILE_CHANGED`, `WINDOWS_CHANGED`. **The one `DRILLDOWN_CHANGED` sender** |
| `Export.lua` | plain table | **The pure half**, which is the seam this file's own header had been naming since it was written: the two serializers and everything they need. `HeaderName`, `CsvField` and `Columns` derive the CSV shape from the stat catalog rather than restating it; `SessionConfig` builds the synthetic window config the aggregator is asked with; `ResolveChannel`, `ChatBatch`, `SendDelay` and `Send` carry the throttled dump and its whisper-failure watch. **Draws no frame.** **Refuses entire while the Combat restriction is active** — `tostring` is not a permitted operation on a secret | `NS.Export` — `Available`, `HeaderName`, `CsvField`, `Columns`, `SessionConfig`, `Build`, `SessionLabel`, `CSV`, `ChatLines`, `ResolveChannel`, `TargetName`, `NeedsHardwareEvent`, `ChatBatch`, `SendDelay`, `Send`, `NoteSystemMessage` — plus the three privates the modal reads, `Export.__EM_DASH`, `__cfgOf` and `__channelRow` | `NS.Aggregator.Build`, `NS.Format`, `NS.Constants` (`STATS`, `STAT_BY_KEY`, `MAX_ROWS`, `SESSION_TYPE`, `EXPORT_CHANNELS`, `EXPORT_CHANNEL_BY_KEY`), and `NS.Secrets` — resolved through its own `mod()` lookup at **call** time, never captured, so the pure half holds no sibling as an upvalue |
| `Export_Modal.lua` | — | **The UI half**: the dialog the header glyph and `/mm export` open, its three selectors — `LibKa0s-Widgets-1.0` dropdowns since the collection grew a shared one — the whisper row, the two action buttons and the copy-paste window. Every frame this feature draws is here and nowhere else; all of it is built lazily on the first `Open` and reused forever, so a session in which nobody exports never pays for it. The combat refusal is enforced **again** here, and deliberately more than once — `Available()` on open, again inside each click handler, and once more inside the serializers — because the restriction can activate while the modal sits open, and the click is the last moment anyone can check | `NS.Export.Open`, `NS.Export.ResolveMetric` | `Export.__EM_DASH` / `__cfgOf` / `__channelRow` **at file scope**, which is what pins its TOC line after `modules/Export.lua`; plus `NS.Constants` (including `FONT_MONO` for the copy window), `NS.L`, `NS.GetSetting` / `NS.SetByPath`, `NS.ApplySkin`, `NS.MakeCloseButton`, `NS.NewBusTarget`, and `LibKa0s-Widgets-1.0` looked up directly — the one library this pair reaches for itself rather than through a `core/*Setup.lua` seam, because the widget is built lazily inside `Open` rather than wired at load; it calls `W.CloseMenu()` from the modal's `OnHide`, since the popup is process-wide and the modal's own `Hide` does not reach it. Subscribes exactly one message — `RESTRICTION_CHANGED`, on a private target taken with the modal frame, so an open dialog greys itself when a pull starts — and sends none |
| `Visibility.lua` | AceAddon | The context translation table and the predicate: context first, then the hide-shaped vetoes, then the two combat rules. No frame is touched and no message is sent | `NS.Visibility` — `GetContext`, `ShouldShow`, `Allows`, `Evaluate`, `Refresh`, `LastResult`, `Forget` | `NS.Database.GetWindows`, the instance and player-state APIs through `_G`, and `NS.Compat` for the delve / skyriding / housing probes. Subscribes `ZONE_CHANGED`, `ENTERING_WORLD`, `ROSTER_CHANGED`, `COMBAT_CHANGED`, `PLAYER_STATE_CHANGED`, `PROFILE_CHANGED` — for the Evaluate pass and its debug line only; the window re-runs the ladder off the same two messages, because this module publishes nothing |
| `Minimap.lua` | plain table | The LDB launcher object and the LibDBIcon registration | `NS.Minimap.Init`, `NS.Minimap.Refresh` | `NS.db.profile.minimap` (owned by LibDBIcon once registered), `NS.WindowManager`, `NS.OpenOptionsPanel` |

### `settings/`

| File | Owns | Publishes | Consumes |
|---|---|---|---|
| `Schema_Compose.lua` | What the array is **declared out of**, and nothing else: the refresh routing a row's `onChange` reaches for, the dropdown vocabularies its `values` point at, the common validators, and the LibKa0s-Options-1.0 composers together with every canonical block composed out of them. It holds no row of its own — the composers decide *which* rows there are, and `Schema.lua` decides where they sit | `NS.SchemaCompose` (one table rather than fifty names on `NS`, so the peel costs the namespace one entry and the array can re-localize each member under the name its rows already spell) and `NS.MasterControlsAfterGroup`, published separately because `settings/General.lua` is its reader | `NS.L`, `NS.Constants`. Captures nothing across the load boundary — but **not for one reason**, and the TOC only accounts for one of the four. `NS.Helpers` is the one this file genuinely loads before: `settings/OptionsSetup.lua` builds it afterwards, which is why a media row's `values` has to be the deferred `lsmValues` closure rather than a list. `NS.db` exists at **no** file's load time at all: `core/Database.lua` loads long before this one, but it only *declares* `NS:InitDB`, and the AceDB object is not assigned until that runs inside `OnInitialize`. `NS.WindowManager` and `NS.Visibility` both publish themselves at file scope and both load **before** this file, so a capture would in fact resolve; they are still reached through `NS` because the only things that reach them are runtime callbacks — `onResetPosition` wants the live registry and whatever `NS.State.activeWindowId` names at the moment of the click, and `refreshVisibility` falls back to `NS:GetModule("Visibility", true)` so a partial install fails open rather than freezing a nil in |
| `Schema.lua` | **The array, and nothing else.** 169 rows across 8 page keys, each one the single source of truth for a setting's widget, its CLI parser and its default. This is the file that grows, and a new setting is still one row in it | `NS.Schema` | every member of `NS.SchemaCompose`, resolved **at file scope** as the array is declared — which is what puts `settings/Schema_Compose.lua` ahead of it in the TOC |
| `Schema_Paths.lua` | The path machinery and the seams every reader and writer of a setting lands on: path splitting and memoization, window resolution, the window-relative path model, the one inverted row, the `path → row` index, the read seam, the write seam, the `columns` whole-array carve-out, and the page and validation surfaces. **Nothing in this file names a single setting** — the array is the part that grows, this is the part that is read when something is wrong | `NS.GetSetting`, `NS.SetByPath`, `NS.SetByPaths` (both taking an optional window id), `NS.FindSchemaRow`, `NS.RegisterSchemaRows`, `NS.ApplyDefault`, `NS.SchemaForPage`, `NS.ValidateSchema`, `NS.NormalizeColumns` | `NS.Schema` **at file scope** — it builds its index by walking the array, which is why it must load *after* it — plus `NS.db`, `NS.State.activeWindowId`, `NS.Constants`, and `NS.Helpers` / `NS.Visibility` at call time. **The one `CONFIG_CHANGED` sender** |
| `Slash.lua` | `NS.COMMANDS`, the five schema adapters pointed at the seam above, the six host verbs, and the library-absent stub | `NS.Slash` — `Register`, `OnSlash`, `PrintHelp`, `HelpRows`, `LandingRows`, `Version` | LibKa0s-Slash-1.0, `NS.WindowManager`, `NS.DebugLog`, `NS.Perf`, `NS.Export`, the schema seam |
| `OptionsSetup.lua` | The options descriptor, the page registry, the reset-all veto (`page == "profiles"`), and the library-absent stub | `NS.Helpers` (the library instance itself), `NS.CreateOptionsPanel`, `NS.OpenOptionsPanel`, `NS.RefreshOptionsPanel` | LibKa0s-Options-1.0, `NS.Schema`, `NS.Slash:LandingRows` |
| `Windows.lua` | The window picker — `H.WindowBanner`, **the only writer of `NS.State.activeWindowId`**, decorated onto the library instance and drawn by all seven window pages — and the five registry buttons plus the copy-from group filter, behind a bespoke two-tab strip (Window, Copy from) | a page registration | `NS.WindowManager`, `NS.State.SetActiveWindow`, `NS.RefreshOptionsPanel` |
| `Frame.lua` | The Frame page (26 rows across four tabs: General, Size and position, Background and border, Row). Pure schema — the header controls moved to Header and "Reset position" to General | a page registration | `NS.Helpers` |
| `Header.lua` | The Header page (31 rows across four tabs): the title bar's own text, every toggle for the icon strip it carries (Controls) and how those controls are drawn (Button style). The column-header strip moved to the Columns page it labels. Rows are stored at `window.frame.*` / `window.header.*`. Pure schema | a page registration | `NS.Helpers` |
| `Bars.lua` | The Bars page (28 rows across six tabs: Bar, Background, Border, Text content, Text style, Icons): the bar, its background, its border, the cell's two text slots and the row icon. The Text and Icons pages folded in here; their PATHS did not move with them. Pure schema | a page registration | `NS.Helpers` |
| `Tooltip.lua` | The Tooltip page (30 rows across six tabs: General, Bar, Bar background, Bar border, Text, Contents). Pure schema | a page registration | `NS.Helpers` |
| `Visibility.lua` | The Visibility page (17 rows across three tabs — where, extra rules, combat). Pure schema | a page registration | `NS.Helpers` |
| `ColumnBlocks.lua` | The ROW CONTENTS of a reorderable list — state glyph, label, and the rule where the enabled ones stop — plus the wiring that hands the list to LibKa0s. The **gesture and the chrome** are `LibKa0s-Widgets-1.0`'s `ReorderList` (minor 9): the handle, its 30px gutter, the **bounded box behind every row**, the carried copy, the insertion line and the clamp. The host's own row background was deleted in the same change as the re-vendor, or the two fills would stack. Loads **before** `Columns.lua` | `NS.ReorderableBlocks(ctx, spec)`, `NS.BLOCK_HEIGHT`, `NS.BLOCK_STRIDE` | `LibKa0s-Widgets-1.0`, `NS.Helpers.EnsureScroll`, `NS.AceGUI`, `NS.Icon` |
| `Columns.lua` | The Columns page (8 schema rows — the `window.columnHeader.*` text and background rows moved here from Header — across two of its three tabs), plus the block editor: one block per statistic, ticked or not, dragged into order, on the tab that carries **no** schema rows. Every write to the array hands the seam a freshly built whole array, and every mutation re-checks combat | a page registration | `NS.ReorderableBlocks`, `NS.SetByPath("window.columns", …)`, `NS.Constants.STATS` |
| `General.lua` | The General page (21 rows in all: **two** drawn tabs — **Master controls**, Statistic colours — plus a third group, Export, whose three rows are `hidden` and therefore never become a tab): `options-ui-§15`'s canonical set followed by this addon's own four (the minimap toggle, the two addon-wide data settings, test mode), and the eight generated statistic-colour swatches. The `General` tab that held those four was retired into Master controls — §15 forbids reordering, renaming or splitting the canonical set, not appending after it, and the six stay first and contiguous. The reset **button pair** is drawn by the hook `H.MasterControls` hands back, not here; what this file still supplies is the reset-everything confirmation popup and one sentence under each of two tabs. Also hosts the **reset-meter-data dialog**, which has no button on any page: the header's own reset control is the one way to open it, and it routes to `NS.Provider.Reset` rather than to the Compat shim | a page registration, `NS.ShowResetMeterData` | `NS.Helpers`, `NS.MasterControlsAfterGroup`, `NS.Provider.Reset` |
| `Profiles.lua` | The AceDBOptions profile tree, hosted in this addon's canvas. **The one place `AceConfigDialog` is permitted**, and the one page vetoed from reset-all | a page registration | AceDBOptions-3.0, AceConfigDialog-3.0 |

Schema rows total 169 across 8 page keys — windows 1, frame 26, header 36, bars 29, tooltip 30,
visibility 17, columns 8, general 22. Counting them means reading `settings/Schema.lua` alone: the
array is the whole of that file now, and neither `Schema_Compose.lua` nor `Schema_Paths.lua`
contributes a row. `profiles` is the only page with zero schema rows: it hosts
AceDBOptions' own tree rather than any of ours, which is bespoke by necessity and says why in its
file header. `columns` carries 8 schema rows (the column-header text and background rows moved here
from Header) plus a bespoke block editor with none — the array it edits is also bespoke by necessity,
for the same "a flat path model has no vocabulary for this shape" reason.

## Load order

`MultiMeters.toc` is authoritative. The order is dependency, not alphabetical.

1. **`libs/`** — LibStub, CallbackHandler, AceAddon/Event/Timer/DB/DBOptions/Console/Config/GUI,
   LibKa0s, LibSharedMedia, AceGUI-3.0-SharedMediaWidgets, LibDataBroker, LibDBIcon.
2. **`locales/enUS.lua`** — first, so `NS.L` exists for every declaration below.
3. **`core/`**, in this order and for these reasons:
   1. `Compat.lua` — first in the block, though nothing now depends on that: the TOC-manifest
      reader that used to make it load-bearing has moved to `EnvSetup.lua`.
   2. `EnvSetup.lua` — **before `Namespace.lua`**, which calls the `NS.Meta` it publishes at file
      scope. A seam loading later would neither raise nor log; `NS.version` would simply be the
      hardcoded `FALLBACK_VERSION` for the session. Load-bearing, not conventional.
   3. `Constants.lua` — before everything that reads `NS.Constants.*` without an existence check.
      Must stay free of logic.
   4. `Namespace.lua` — resolves `NS.version` at load; everything after may read it.
   5. `State.lua` — after `Constants` (the test-mode toggle names a message from the catalog).
   6. `Secrets.lua` — before any consumer. Deliberately carries **no** perf bracket.
   7. `CoreSetup.lua` — after `Constants` (for the prefix), before `MultiMeters.lua` (whose
      AceConsole reclaim reads `NS.Util.print`), and **first of the LibKa0s seams that report a
      degraded install**, because `NS.LIBKA0S_MISSING` is defined here. `EnvSetup.lua` and
      `MediaSetup.lua` are exempt: neither touches the clause, and both are pinned earlier by a
      file-scope reader.
   8. `PerfSetup.lua` — after `Namespace` (a nil `version` stamps every capture record `v?`) and
      **before every `modules/` file that takes `local Perf = NS.Perf` at load**.
   9. `DebugLogSetup.lua` — after `Constants`, `State` and `CoreSetup`.
   10. `MediaSetup.lua` — **before `Constants.lua`**, which resolves `FONT_MONO` from `NS.MediaFont`,
      and therefore before `defaults/Profile.lua` names the font at load. This is one of the few
      TOC positions in `core/` that is load-bearing rather than conventional.
   11. `PoolSetup.lua` — after the `libs/` block and **before `modules/Window.lua`**, the pool's
      only consumer. It carries no other constraint: it publishes `NS.Pool` and captures nothing.
   12. `MultiMeters.lua` — after every setup file; promotes `NS` into the AceAddon object.
   13. `Database.lua` — after `State`, before `OnInitialize` runs. Reads `NS.defaults` at *call*
       time, because `defaults/` loads later.
   14. `Diagnostics.lua` — **deliberately unconstrained.** It reads every module at *call* time
       and owns no state, so nothing depends on where *it* loads. What does depend on it is
       everything below.
   15. `Diagnostics_DeathRecap.lua`, 16. `Diagnostics_Identity.lua`, 17. `Diagnostics_Feign.lua` —
       **all three after `Diagnostics.lua`, and load-bearingly so.** Each resolves `NS.Diagnostics`
       and that file's print helpers at *file scope*, so one loading first would freeze nils in and
       take its verb down with no error anywhere. Among themselves they are unordered: none reads
       another. Deleting one with its issue is a TOC line and a file, which was the whole point of
       cutting on the probe rather than at a line number.

   `LSMPatch.lua` used to sit at 12, unconstrained, patching AceGUI's `LSM30_Border`
   from a `PLAYER_LOGIN` frame. That registration writes into a **process-global**
   registry, so it was never this addon's private business; it is
   `lib.__PatchLSM30Border()` in `LibKa0s-Options-1.0` now, called from
   `settings/OptionsSetup.lua`'s live arm. See that call site for why file load is
   early enough and why the timing change is safe.
4. **`defaults/Profile.lua`** — after `core/Constants.lua`, whose stat catalog it captures at load.
5. **`modules/`** — `Format` first (nothing reads another module, and `Row` and `Tooltip` both format
   on their first render), then `Provider` → `Roster` → `Feign` → `Aggregator` →
   **`Aggregator_Identity` → `Aggregator_Preview`** → `WindowManager` → `Window` →
   **`Window_Header` → `Window_Placement`** → `HeaderControls` → `Row` → **`Row_NameCell`** →
   `Targets` → `Tooltip` → **`Tooltip_Lines` → `Tooltip_Builders`** → `DrillDown` → `Export` →
   **`Export_Modal`** → `Visibility` → `Minimap`.

   The eight in bold are the layout-§1 peels, and **every one of their positions is load-bearing**
   for the same reason: each resolves something its parent publishes at *file scope*, so a peel
   ahead of its parent captures nil and stays nil for the session.
   `modules/Aggregator_Identity.lua` takes the five row-assembly helpers off `Aggregator._identity`;
   `Aggregator_Preview.lua` needs only the module table, but is kept beside its sibling because that
   is where the reading order puts it.
   `Window_Header.lua` resolves `NS.WindowProto`, `NS.WindowFontPath`, `NS.SurfaceColor` and
   `NS.WindowModule`, and `Window_Placement.lua` resolves `NS.WindowProto` — both after
   `modules/Window.lua`, which publishes all four. `Window_Header.lua` also sits **ahead of**
   `HeaderControls.lua`, which reads the `NS.HeaderStyle` it publishes; that read is at *call* time,
   so this half is order by intent rather than a load-time requirement, and the TOC says which is
   which.
   `Row_NameCell.lua` resolves `NS.RowInternals`' three members after `modules/Row.lua`.
   `Tooltip_Lines.lua` resolves `NS.TooltipInternals` after `modules/Tooltip.lua`, and
   `Tooltip_Builders.lua` must follow **both**, because the second half of that table is not filled
   until `Tooltip_Lines.lua` has run. `Export_Modal.lua` resolves `Export.__EM_DASH`, `__cfgOf` and
   `__channelRow` after `modules/Export.lua`.

   `Row.lua` loads
   before `Tooltip.lua` and `DrillDown.lua` and therefore resolves both at *call* time. `Targets.lua`
   loads before `Tooltip.lua`, which is its only caller, and resolves the provider at *call* time for
   the same reason `Tooltip.lua` does. `Export.lua` is the one entry here under **no** constraint at
   all: its in-addon caller — `modules/Window.lua`'s header glyph — loads *before* it, so it can
   capture no sibling at load and looks every one of them up when a button is clicked instead. It
   sits after `DrillDown.lua` because that is where the reading order puts it, the last of the things
   a window does with its rows, and not because anything would break elsewhere.
6. **`settings/`** — last, and the three Schema files first inside it, **in that order and for three
   different reasons**:

   1. `Schema_Compose.lua` — **before `Schema.lua`.** The array resolves every member of
      `NS.SchemaCompose` at *file scope* as it is declared, so a composer file loading second would
      leave the array declared out of nils. It captures nothing itself, and only **one** of the
      four names it reaches through `NS` is a load-order matter: `NS.Helpers`, which
      `settings/OptionsSetup.lua` builds afterwards. `NS.db` is assigned by `NS:InitDB()` during
      `OnInitialize` and exists at no file's load time; `NS.WindowManager` and `NS.Visibility` both
      load *before* this file and could be captured, and are not because the only things that reach
      them are runtime callbacks. The per-file table above says which is which.
   2. `Schema.lua` — the array.
   3. `Schema_Paths.lua` — **after the array**, because it builds its `path → row` index by walking
      `NS.Schema` at *file scope*; and **still before `Slash.lua` and `OptionsSetup.lua`**, which
      point their seams at `NS.SetByPath` / `NS.GetSetting` / `NS.FindSchemaRow` / `NS.ApplyDefault`
      at load. It is the one file in the addon pinned from **both** sides, which is why splitting
      `settings/Schema.lua` needed three files rather than two.

   `OptionsSetup.lua` must then precede every page file, because the pages call `NS.Helpers` members
   inside schema-row literals at file load.

## AceAddon lifecycle

`core/MultiMeters.lua` calls `AceAddon-3.0:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0",
"AceConsole-3.0")`. `NewAddon` promotes the table it is handed, so **`NS` is the addon object** —
there is no `_G.MultiMeters` and no rebind. `NS.addon` is published anyway, so a test or the perf
descriptor can name "the AceAddon object" without assuming the promotion happened in place.

Immediately after `NewAddon`, `NS.Print` is reclaimed from AceConsole's mixin by re-pointing it at
`NS.Util.print`. The two must remain the **same function object**, not two lookalike wrappers.

**`NS:OnInitialize`** (on `ADDON_LOADED`), in order:

1. `self:InitDB()` — builds AceDB against `NS.defaults` with the shared `"Default"` profile
   (the third argument is `true`; omitting it silently produces per-character profiles), then
   migrates and seeds.
2. `self:RunMigrations()` — idempotent after step 1, called explicitly so the lifecycle reads as the
   standard's four steps.
3. `NS.Minimap.Init()` — **after** `InitDB`, because LibDBIcon stores the button's position inside
   `NS.db.profile.minimap`.
4. `NS.CreateOptionsPanel()` — schema validation, the parent category, and the queued page builders.
5. `NS.Slash:Register()` — `/mm` and `/multimeters`, through AceConsole. If the settings layer never
   loaded, both verbs are claimed anyway and say so rather than going silent.

**`NS:OnEnable`** registers the game events — **21** `self:RegisterEvent` calls routed to **11**
handlers, and a twenty-second event, `PLAYER_IS_GLIDING_CHANGED`, which is *probed* through
`C_EventUtils.IsEventValid` rather than registered outright and therefore may or may not take. Ten of
the 21 are the player-state block behind `OnPlayerStateChanged` alone, and the probed one would make
eleven. Which event becomes which message is tabulated in `docs/ARCHITECTURE.md` →
[Event subscriptions](ARCHITECTURE.md#event-subscriptions); why none of them may be dropped is
[below](#game-event-edges-are-load-bearing).

`OnEnable` also seeds `NS.State.restricted` from `NS.Secrets.IsRestricted()` — a `/reload` taken
mid-pull re-enables the addon inside an already active restriction, and there is no second
`ADDON_RESTRICTION_STATE_CHANGED` edge to catch.

**Module `OnEnable`** hooks then run: `Provider`, `Roster`, `Feign`, `Aggregator`, `DrillDown`,
`Visibility` each subscribe to their bus messages; `WindowManager:OnEnable` calls `Init()`, which
builds one `NS.Window.New(cfg)` instance per stored config. Windows are re-pointed with `SetConfig`
on a profile swap rather than torn down and rebuilt — a rebuild is a flicker the player sees.

`modules/Export.lua` and `modules/Export_Modal.lua` appear nowhere in that sequence and need to.
Between them they are one plain table with no `OnEnable` and nothing to wire at load; the two frames
are built by `Export_Modal.lua` on the first `Open` and never before, so a session in which nobody
exports never pays for it. The one thing the pair does keep is taken with the modal rather than at
load: a private bus target carrying `RESTRICTION_CHANGED`, so a dialog left open across a pull greys
its own buttons.

## Bus-target discipline

CallbackHandler keys callbacks by `(message, target)`, so two receivers of one message registered on
the same object silently clobber each other and only the last registrant fires. This addon is
unusually exposed: every window subscribes to the same refresh messages, and there can be many
windows.

- AceAddon modules that subscribe (`Provider`, `Roster`, `Feign`, `Aggregator`, `WindowManager`,
  `DrillDown`, `Visibility`) are their own AceEvent targets.
- `Tooltip` is an AceAddon module as well, and is **not** in that list: it has neither
  an `OnEnable` nor a single `RegisterMessage`, so it never becomes a bus target at all. Its two
  peels, `modules/Tooltip_Lines.lua` and `modules/Tooltip_Builders.lua`, register nothing either —
  the peel moved no subscription, because there was none to move.
- Everything else — each `Window` instance, `modules/Format.lua`, `modules/Targets.lua`, the Profiles
  page in `settings/Profiles.lua`, and the export modal in `modules/Export_Modal.lua` once it has
  been built — owns a private target from `NS.NewBusTarget()`.
- Nothing registers on the shared addon object.

## LibKa0s seams

Which majors this addon consumes, which file reaches each, and what each degrades to when
`libs/LibKa0s/` is absent. The per-file table above carries each seam's own members; this is the
roll-call, and it used to sit in `docs/ARCHITECTURE.md` → `## Overview`.

Chrome comes from LibKa0s-Core-1.0's shared `SKIN` / `ApplySkin`, never a private lookalike, so the
meter window, the debug console and the perf step panel wear the same Ka0s edge as every sibling
addon. Nine LibKa0s majors are consumed — Core, Media, Perf, DebugLog, Env, Pool, Slash, Options and
Widgets. Eight are reached through a seam file of their own (`core/CoreSetup.lua`,
`core/MediaSetup.lua`, `core/PerfSetup.lua`, `core/DebugLogSetup.lua`, `core/EnvSetup.lua`,
`core/PoolSetup.lua`, `settings/Slash.lua`, `settings/OptionsSetup.lua`); Widgets has no seam file and
is resolved at each of its two call sites — `modules/Export_Modal.lua`, which builds the addon's only
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

## Game-event edges are load-bearing

Which events reach which handler, and what each becomes on the bus, is tabulated in
`docs/ARCHITECTURE.md` → [Event subscriptions](ARCHITECTURE.md#event-subscriptions). What that
table does not say is why an edge cannot simply be dropped:

**These edges are load-bearing, not an optimisation.** There is no fallback poll: `onUpdate` in
`modules/Window.lua` refreshes *data* and never re-asks `NS.ShouldShow`, so the show ladder is
re-run only from a bus message a window subscribes to (`ROSTER_CHANGED`, `ZONE_CHANGED`,
`ENTERING_WORLD`, `COMBAT_CHANGED`, `PLAYER_STATE_CHANGED`, `TEST_MODE_CHANGED`, `CONFIG_CHANGED`).
A visibility input with no edge on the bus is a rule that never fires — which is exactly what
happened to `hideInVehicle`, shipped in 0.1.0 with no vehicle event registered, and to the first cut
of the player-state rules, which reached `Visibility` but not the window.
