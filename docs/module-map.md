# Module map

Where each responsibility lives, what each file publishes, and what it consumes. `MultiMeters.toc`
is the source of truth for load order — check this map against it before editing.

Seventy-two non-vendored source files: 1 locale, 22 `core/`, 1 `defaults/`, 32 `modules/`,
16 `settings/`.

Thirteen of those arrived on one day, 2026-09-09, and **not one of them is a new module.** They are
peels. `layout-§1` caps an authored file at 1500 lines; seven source files were over it —
`settings/Schema.lua` at 3080, `modules/Tooltip.lua` at 2774, `modules/Window.lua` at 2746,
`modules/Aggregator.lua` at 2122, `core/Diagnostics.lua` at 1867, `modules/Row.lua` at 1829 and
`modules/Export.lua` at 1790 — and each was cut along a seam its own header had already named rather
than at whatever line brought it under. Nothing was rewritten on the way out: a reader chasing a
behavior into a peeled file is reading the block that used to sit under a banner in its parent.

That is also why so many of the new TOC lines are load-bearing and say so at the line. A peel hangs
its functions on the **same** prototype or module table its parent builds, so the parent publishes
what used to be a file-local — `NS.WindowProto`, `NS.RowInternals`, `NS.TooltipInternals`,
`Aggregator._identity`, `Aggregator._order`, `Export.__cfgOf`, `NS.SchemaCompose` — and the child resolves it at **file
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
│                         C_SpecializationInfo, all eight C_DamageMeter reads,
│                         C_StringUtil.CreateNumericRuleFormatter and the chat
│                         sender C_ChatInfo.SendChatMessage, plus the world reads the
│                         simulator answers. 42 shims, no logic
│   ├── SimSetup.lua    — the LibKa0s-Sim-1.0 seam: wraps every NS.Compat member at
│                         load (pure, guarded, the rest). STRAIGHT after Compat.lua
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
│                         private-bus-target factory over LibKa0s-Bus-1.0's
│                         stand-down record (NS.BusStandDown / NS.BusStandUp)
│   ├── State.lua       — session-only flags (debug, debugTooltip, restricted,
│                         testMode, activeWindowId) and the shared per-module cache
│                         with its one wipe seam. Nothing here is ever persisted
│   ├── Secrets.lua     — THE ONLY VALUE INSPECTOR (R1). Restriction state,
│                         IsSecret / CanAccess / CanCompare / CanCompare2,
│                         CanAccessTable, SafeIterate, SafeCount
│   ├── CoreSetup.lua   — LibKa0s-Core-1.0 seam: the secret-safe NS.PREFIX-tagged
│                         printer (NS.Print === NS.Util.print), NS.IsConcatSafe /
│                         NS.SafeToString / NS.SECRET, NS.RGBA, NS.SKIN / NS.ApplySkin /
│                         NS.MakeCloseButton, NS.MakeResizable (nil below Core 10),
│                         and NS.LIBKA0S_MISSING
│   ├── SkinSetup.lua   — LibKa0s-Skin-1.0 seam: the owner "MultiMeters" and its six
│                         mm.* owner tokens, NS.Skin (the facade), the read and write
│                         seams, NS.SkinColor / SkinEscape / SkinMediaKey, the AceGUI
│                         painters and the first-run skin picker; a degraded facade
│                         that answers every name without the library
│   ├── LifecycleSetup.lua — LibKa0s-Lifecycle-1.0 seam: THE ONE LATCH and THE ONE
│                         TEARDOWN. standDown / standUp, the `disabled` hold taken
│                         from the stored enable path, NS.IsStoodDown / NS.IsDisabled.
│                         BEFORE PerfSetup.lua, which raises without a lifecycle
│   ├── PerfSetup.lua   — LibKa0s-Perf-1.0 seam: NS.Perf, the 10 buckets, and the
│                         latch — the `perf` hold is the second reason to be inert
│   ├── DebugLogSetup.lua — LibKa0s-DebugLog-1.0 seam: NS.DebugLog, the bare
│                         NS.Debug(tag, fmt, …) sink, and NS.DebugSteady — the
│                         same sink for a pass that repeats on a timer
│   ├── LauncherSetup.lua — LibKa0s-Launcher-1.0 seam: NS.Launcher, the ONE
│   │                     LibDataBroker object registered twice (launcher-§1). Holds the
│   │                     descriptor and nothing else: the folder name, the logo, how
│   │                     the panel opens and the options menu's four verb-backed pairs.
│   │                     Reads Constants.LOGO_128 at FILE SCOPE. Also owns the Show window
│   │                     key binding's button, MultiMetersToggleWindows (launcher-§6),
│   │                     built before the library-absent fork
│   ├── PoolSetup.lua   — LibKa0s-Pool-1.0 seam: NS.Pool, the window row pool's
│                         free/active halves. After libs/, BEFORE modules/Window.lua,
│                         ahead of its only consumer, modules/Window_Render.lua. RANK STABILITY IS THE LIBRARY'S — minor 3
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
│   ├── Diagnostics.lua — `/mm diagnostics`: the sectioned report a player pastes into
│   │                     a bug report. Reads modules at CALL time, owns no state,
│   │                     and every section is pcall-wrapped so one broken probe
│   │                     cannot take the report down. Also the FRAME the three
│   │                     probes below hang off: it publishes the shared print
│   │                     helpers (out, safe, shown, probe) they take off
│   │                     the table rather than redefine
│   ├── Diagnostics_DeathRecap.lua
│   │                   — `/mm debug recap`: can issue #1's Death Recap window be
│   │                     built at all. Rides along in `/mm diagnostics` too, so its
│   │                     section goes back onto the shared table
│   ├── Diagnostics_Identity.lua
│   │                   — `/mm debug identity`: the issue #22 identity-correlation
│   │                     measurement. NOT part of `/mm diagnostics`; the entry point
│   │                     at the foot of the file is the only way in
│   ├── Diagnostics_Feign.lua
│   │                   — `/mm debug feign`: the issue #25 feign recording. The one
│   │                     probe carrying STATE — the ring, its write index and the
│   │                     armed flag modules/Feign.lua and modules/Aggregator.lua
│   │                     read through NS.Diagnostics at call time
│   └── Diagnostics_Runtime.lua
│                       — the addon-state sections that open `/mm diagnostics`:
│                         state, settings, per-window settings, windows, sessions,
│                         the aggregator's last pass, roster and caches, sim.
│                         Read-only
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
│   ├── Aggregator.lua  — the GUID join, group filtering, pet folding, the sort
│   │                     ladder, and the only two divisions in the addon.
│   │                     Chooses per pass between the join and the identity
│   │                     build below
│   ├── Aggregator_Identity.lua
│   │                   — the grid drawn while sourceGUID is SECRET, and the
│   │                     rectangle that measures how much of it got filled.
│   │                     Shares the row-assembly helpers through
│   │                     Aggregator._identity and hands buildByIdentity back
│   ├── Aggregator_Preview.lua
│   │                   — the invented meter: the test rows a player laying out
│   │                     columns at a target dummy sees. Reads nothing the
│   │                     aggregator holds, which is what made it the cheap cut
│   ├── Aggregator_Order.lua
│   │                   — the orderings the sort ladder picks among, and the
│   │                     row cap (ApplyRowLimit, SelfPinIndex). Takes UNRANKED
│   │                     off Aggregator._order and hangs the orderings back
│   ├── WindowManager.lua — the window REGISTRY: create / delete / rename /
│                         duplicate / copy-from, lock, test mode, toggle. The ONE
│                         WINDOWS_CHANGED emitter
│   ├── Window.lua      — one window instance and its LOOP's contract: the
│   │                     refresh and anchor rules, the layout computation (R3)
│   │                     and the cached config. Publishes WindowProto for the
│   │                     five files below
│   ├── Window_Frame.lua
│   │                   — the two frames built once (BuildFrame), ApplyConfig,
│   │                     the edge and fill (ApplyBorder) and NS.SurfaceColor
│   ├── Window_Render.lua
│   │                   — the row pool, the scroll, the OnUpdate clock, Refresh
│   │                     and Render
│   ├── Window_Lifecycle.lua
│   │                   — how a window is born, re-pointed, stood down and put
│   │                     away: Window.New, the private bus target's thirteen
│   │                     subscriptions, SetConfig, Destroy, Suspend, Resume
│   ├── Window_Header.lua
│   │                   — the header BAND of one window: the title bar, the session
│   │                     line, the test-mode and sim strips, the column labels, the sort a click on one performs,
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
│   ├── Row_Border.lua  — the cell outline `bars.border` draws: four flat edge
│   │                     textures or an LSM edge-art backdrop on the bar, and the
│   │                     per-row re-tint the `class` color mode needs
│   ├── Row_Cells.lua   — which of a row's cells are LIVE (the ordered liveCells
│   │                     array Update walks), and Release back to the pool
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
│   │                     no frame; refuses at the source
│   ├── Sim.lua         — the simulator's session host: NS.Sim on LibKa0s-Sim-1.0,
│   │                     the refusals, the gate, the real-event classifier, the
│   │                     pin snapshot and the stop's resync. Loads BEFORE the
│   │                     world and drivers, which fill its tables in place
│   ├── SimWorld.lua    — the simulator's invented world (the real player plus
│   │                     seeded mates, zones, segments, deaths and recaps) and
│   │                     every provider the seam answers from. Plain invented
│   │                     numbers only; registers on NS.SimSeam at FILE SCOPE
│   ├── SimDrivers.lua  — the simulator's drivers: each edits the world, then
│   │                     fires the client's events through NS.Sim:Fire in the
│   │                     client's order; a fight's ticks ride NS.Sim:After
│   └── SimScenario.lua — the four #60 scenarios (dungeon, raid, wipe, zone):
│                         labeled, tipped steps, and NS.SimHost.Play, which
│                         plays each step through the drivers
└── settings/
    ├── Schema_Compose.lua
    │                   — WHAT THE ARRAY IS DECLARED OUT OF and nothing else: the
    │                     refresh routing a row's onChange reaches for, the dropdown
    │                     vocabularies, the common validators, and the
    │                     LibKa0s-Options-1.0 composers with every canonical block
    │                     composed out of them. Holds no row of its own. Published
    │                     once as NS.SchemaCompose; loads FIRST of the three
    ├── Schema.lua      — NS.Schema: the 180-row array itself, and nothing else. The
    │                     composers decide WHICH rows there are; this file decides
    │                     where each one sits. This is the file that grows, and a
    │                     new setting is still one row in it
    ├── Schema_Skin.lua — the seven skip-render skin.* rows (the skin, its Scope, its
    │                     overrides, the picker's memory), appended to NS.Schema;
    │                     the library's Skin tab draws them
    ├── Schema_Paths.lua — THE SETTINGS RUNTIME'S DESCRIPTOR: one LibKa0s-Schema-1.0
    │                     instance (NS.SchemaRuntime) over NS.Schema, or its
    │                     degradation stub; the window-relative resolveRoot, the
    │                     announce, the hidden columns row, and the shims GetSetting,
    │                     SetByPath, SetByPaths, FindSchemaRow, RegisterSchemaRows,
    │                     ApplyDefault, NS.Bulk; SchemaForPage, ValidateSchema.
    │                     THE ONE CONFIG_CHANGED SENDER
    ├── Slash.lua       — LibKa0s-Slash-1.0 seam: NS.COMMANDS (20 verbs), the five
    │                     schema adapters, the `profile` row, the six window verbs,
    │                     and the one gate that refuses a feature verb while the
    │                     addon is disabled
    ├── OptionsSetup.lua — LibKa0s-Options-1.0 seam: NS.Helpers IS the library
    │                     instance, the panel registry, the reset-all veto, and the
    │                     one row no reset may write (the minimap button)
    ├── ColumnBlocks.lua — the ROW CONTENTS of the Columns entry's reorderable
    │                     list. The gesture and the chrome are LibKa0s-Widgets-1.0's
    │                     ReorderList; loads BEFORE Columns.lua
    └── General · Windows · Profiles, and Frame · Header · Bars ·
        Tooltip · Visibility · Columns
                          — the 3 panel pages (General, Windows, Profiles) and the
                          Windows page's 7 entries. General is FIRST; the six
                          files after Windows.lua register entries on its rail,
                          under the band (H.WindowBanner) that picks the window
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
| `Compat.lua` | All 42 shims, the world reads the simulator answers among them — the TOC-manifest reader is no longer among them; it moved to `EnvSetup.lua`. Never inspects a meter value; reading a field off a session table and passing it on is not inspection. The four spell and spec readers are bound to `LibKa0s-Compat-1.0`, and each answers `nil` without it | `NS.Compat` | `_G`, `LibKa0s-Compat-1.0` |
| `Constants.lua` | The stat catalog, the **shipped** per-stat palette (`STAT_COLORS`, the seed for the `statColors.*` setting and the fallback every `NS.StatColor` call degrades to, plus the `STAT_DIM` factor), the two stat lookups — `STAT_BY_KEY` ("may this be a column") and `READABLE_STAT_BY_KEY` ("may this be read", the catalog plus `OFF_CATALOG_STATS`), enum resolutions, the `MSG` catalog (strict through `LibKa0s-Bus-1.0`'s `Catalog`), timing and pool bounds, the `LAYERS` table (every strata and frame-level band, frame-layering-§5), the monospace font path (resolved from the LibKa0s payload, falling back to the client font) and its LSM key | `NS.Constants`, `NS.Const` | `_G.Enum`, `NS.MediaFont`, `LibKa0s-Bus-1.0` (`Catalog`) |
| `SimSetup.lua` | The LibKa0s-Sim-1.0 seam: wraps every `NS.Compat` function member in place at load, except the seventeen pure ones, with three guarded answers (`ResetAllCombatSessions`, `ChatSender`, `OpenDeathRecap`) that never reach the client while a session runs. With the library absent, the reference seam and session stubs | `NS.SimSeam`, `NS.SimHost` (`.Guarded`), and `NS.Sim` (the stub) when the library is absent | `LibKa0s-Sim-1.0`, `NS.Compat`; `NS.Sim`, `NS.SimHost.World`/`.world`, `NS.Print`, `NS.Debug` at call time |
| `EnvSetup.lua` | The LibKa0s-Env seam: this addon's TOC manifest, and the one place the manifest-then-constant version pair is resolved. Repeats the reader ladder itself on a degraded install, so an install missing LibKa0s still reports its packaged version | `NS.Meta`, `NS.Version` | `LibKa0s-Env-1.0`, `NS.version` at call time. Owns no state and registers no event |
| `Namespace.lua` | Addon identity, the collection's one class-color reader (four surfaces can wear one — the bars and cell text in `Row.lua`, both header strips in `Window_Header.lua`, the tooltip), the one **statistic**-palette reader beside it (`NS.StatColor`, which reads the `statColors.*` setting and falls back to `Constants.STAT_COLORS`) and the bus-target factory, whose record is `LibKa0s-Bus-1.0`'s, with the untracked-target stub when the library is absent. No side effects at all: building the record is bookkeeping, and nothing registers | `NS.PREFIX`, `NS.GRAY`, `NS.name`, `NS.version`, `NS.FALLBACK_VERSION`, `NS.ClassRGB`, `NS.PlayerClassRGB`, `NS.StatColor`, `NS.NewBusTarget`, `NS.BusStandDown`, `NS.BusStandUp`, `NS.busRecord`, `NS.BusLib` | `NS.Meta`, `_G.RAID_CLASS_COLORS`, `_G.UnitClass`, `LibKa0s-Bus-1.0`, `NS.IsStoodDown` (late-bound) |
| `State.lua` | The five session flags, each with exactly one named writer — `debugTooltip` is the tooltip log channel, off by default and written only by `/mm debug tooltip` (see [debug.md](debug.md)) — and `State.Cache` / `State.WipeCache` (wipes **in place**, so a module may hold its sub-table as an upvalue) | `NS.State` | `NS.Constants.MSG` |
| `Secrets.lua` | Restriction state, per-value and per-table inspection (including `PlainTruth`, the one truth test for a field that might be a secret boolean), and the two bounded walks. Correct when the whole secrets system is absent. `IsSecret` / `CanAccess` / `IsSafeKey` are `LibKa0s-Compat-1.0`'s, with a guard arm that re-implements each body when the library is absent | `NS.Secrets` | `_G.C_RestrictedActions`, `_G.issecretvalue` and friends, `LibKa0s-Compat-1.0` |
| `MediaSetup.lua` | The LibKa0s-Media seam: where the icons and the monospace face come from, and the one call that registers the face with LibSharedMedia. Answers `nil` for both on a degraded install, which is what sends the header down its art ladder | `NS.Icon`, `NS.MediaFont` | `LibKa0s-Media-1.0`, LibSharedMedia. Owns no state and registers no event |
| `CoreSetup.lua` | The LibKa0s-Core seam and the shared "library missing" cause clause. `NS.MakeCloseButton` is the one member WRAPPED rather than handed over: it supplies the addon folder name the library needs to build a texture path for its own close icon | `NS.Util.print` / `NS.Print`, `NS.Format` (printer, later rebound), `NS.IsConcatSafe`, `NS.SafeToString`, `NS.SECRET`, `NS.RGBA`, `NS.SKIN`, `NS.ApplySkin`, `NS.MakeCloseButton`, `NS.MakeResizable` (the library's grip on Core minor 10 or later; a nil-answering function below that and on a degraded install, so there is no grip), `NS.SafeRegisterEvent` / `NS.SafeRegisterUnitEvent` / `NS.SafeRegisterEvents`, `NS.LIBKA0S_MISSING` | `NS.PREFIX` |
| `SkinSetup.lua` | The LibKa0s-Skin-1.0 seam (skinning-§3): registers the owner `"MultiMeters"` at file load with its read and write seams and its six owner tokens (`mm.rowHover`, `mm.rowStripe`, `mm.tipHint`, `mm.dim`, `mm.testWord`, `mm.warn`, each Ka0s Default's old pixel following a library role token), applies the stored skin, Scope and overrides, resolves the HUD's media through each `<key>FromSkin` companion, paints the AceGUI widgets the addon acquires itself, and shows the first-run skin picker (held through combat, never while stood down). The degraded arm answers every facade name from `NS.SKIN_FALLBACK` | `NS.Skin`, `NS.SKIN_TOKENS`, `NS.SKIN_FALLBACK`, `NS.SKIN_TAB`, the skin rows' value tables, `NS.SkinChoice` / `NS.WriteSkinChoice`, `NS.SkinOverride`, `NS.ApplySkinChoice` / `ApplySkinIgnore` / `ApplySkinOverride` / `ApplySkinOutline`, `NS.SkinColor`, `NS.SkinEscape`, `NS.SkinPanelColor` (a settings-page color, stock while the panel is ignored), `NS.SkinWindowLooks`, `NS.SkinMediaKey`, `NS.SkinFontFlags`, `NS.SkinHudFontSize`, `NS.SkinPaintAce` / `SkinPaintAceTree`, `NS.MaybeShowSkinPicker` / `HideSkinPicker` / `ResumeSkinPicker`, `NS.SkinPickerSpec`, `NS.RunSkinVerb` | `LibKa0s-Skin-1.0`, and at call time `NS.GetSetting`, `NS.SetByPath`, `NS.Helpers` (the picker), `NS.WindowManager` (the eye), `NS.IsStoodDown`, `NS.ApplySkin` (the degraded Shell), `NS.Print`, `NS.Debug`. Registers no event |
| `LifecycleSetup.lua` | The ONE `LibKa0s-Lifecycle-1.0` latch and the addon's ONE teardown: `standDown` / `standUp`, the `disabled` hold taken from the stored `enabled` path, and the show ladder's answer. The descriptor passes the gated sink as `debug`, so the edge lines are the library's `[Lifecycle]` lines and this file writes none. **Loads before `PerfSetup.lua`** — the perf descriptor requires `lifecycle` and raises without it | `NS.lifecycle`, `NS.StandDown`, `NS.StandUp`, `NS.SyncEnabledHold`, `NS.IsStoodDown`, `NS.IsDisabled` | `NS.GetSetting`, and `Provider` / `WindowManager` / `Visibility` / `Export` at call time |
| `PerfSetup.lua` | The perf descriptor: bucket list, the latch, log routing. **No `suspend` / `resume`** — from Perf minor 12 nothing reads them and the teardown is the latch's | `NS.Perf` | `NS.Version`, `NS.lifecycle` |
| `DebugLogSetup.lua` | The console descriptor (including `addonName`, which is what makes the console's own close/copy/clear draw the collection's art), the debug sink, and the steady-state sink a timer-driven pass logs through (re-armed by turning logging on and by the console's Clear, through `onClear`), and the console's at-enable queue for a state line written while logging is off | `NS.DebugLog`, `NS.Debug`, `NS.DebugAtEnable`, `NS.DebugSteady`, `NS.DebugSteadyReset` | `NS.Constants.FONT_MONO`, `NS.State.debug`, `NS.Print`, `NS.SafeToString` |
| `PoolSetup.lua` | The LibKa0s-Pool seam: the free/active halves of the window row pool. What stays in `modules/Window_Render.lua` is what the library holds no opinion about — `pool.all` (every row ever built, so a **parked** row is re-laid-out too) and batch growth, folded into the `Acquire` factory closure. The degraded fallback is the same three members locally, parking **backward** exactly as `LibKa0s-Pool-1.0` minor 3 does; a forward-parked degraded install is the rank flicker back | `NS.Pool` | `LibKa0s-Pool-1.0`. Owns no state and registers no event |
| `LauncherSetup.lua` | The LibKa0s-Launcher seam: the descriptor for the ONE LibDataBroker object LibDBIcon and any broker display both draw from (`launcher-§1`). Holds what is genuinely this addon's — the **folder** name (LibDBIcon keys the button's saved position by it), the logo, `version` from the TOC for the status tooltip's title (Launcher minor 3; the library draws the tooltip and this file passes no `onTooltipShow`), and the options menu's four accessor-and-toggle pairs (Launcher minor 4, `launcher-§2` at v2.67.0): `isEnabled` = `not NS.IsDisabled()` with `setEnabled` → the `enable`/`disable` verb, `isLocked` = `WindowManager:IsLocked` with `toggleLock` → `lock`, `isTestMode` = `NS.State.testMode` with `toggleTestMode` → `test`, `isWindowShown` = `WindowManager:AnyShown` with `toggleWindow` → `toggle`. Every toggle is the verb's own handler, looked up in `NS.COMMANDS` at click time. Left-click opens the panel (`openSettings`), in either state. The `minimap` field is a **closure**, never the table: `db.global.minimap` does not exist when core/ loads. `debug` is the gated sink and `debugAtEnable` the console's at-enable queue (Launcher minor 5), so the library's `registered` line, written at login with logging off, lands when logging is turned on. The inversion is NOT here — it is the write seam's carve-out. It also builds the Show window key binding's button (`launcher-§6`): the plain, hidden, non-secure `MultiMetersToggleWindows` Button the root `Bindings.xml` clicks, registered `AnyDown`, whose OnClick is `toggleWindows`, the very function the descriptor's `toggleWindow` is. A key cannot be grayed, so `toggleWindows` prints `NS.Slash:DisabledLine()` while disabled, as the dispatcher does for `/mm toggle`; otherwise it runs the verb. Built **before** the library-absent fork, with the `BINDING_HEADER_MULTIMETERS` (the binding category's title) and `BINDING_NAME_CLICK MultiMetersToggleWindows:LeftButton` labels set by `rawset`, and `NS.BINDINGS`, the one bindings table (`{ command, tooltip }` in `Bindings.xml` order) the General page's Keybindings tab and the suite read | `NS.Launcher` — `Register`, `IsRegistered`, `Object`, `IsShown`, `SetShown`; `NS.BINDINGS` | `LibKa0s-Launcher-1.0`, `NS.Constants.LOGO_128` (at file scope), `NS.db.global.minimap`, `NS.WindowManager`, `NS.OpenOptionsPanel`, `NS.COMMANDS`, `NS.IsDisabled` (all at call time) |
| `MultiMeters.lua` | AceAddon promotion, the printer reclaim, all 22 game-event registrations (the `EVENTS` array, each through `NS.SafeRegisterEvent` with the one handler `OnGameEvent`, refusals in `NS.State.rejectedEvents`), the dispatch table, the fan-out onto the bus, and `NS.ShouldShow` | `NS.addon`, `NS.ShouldShow`, `NS:OnInitialize` / `OnEnable`, `NS:OnGameEvent`, `NS.DeliverEvent`, `NS.HANDLER_BY_EVENT`, `NS.RealEventFilter` (the simulator's hook) | `NS.Constants.MSG`, `NS.State`, `NS.Secrets`, `NS.Launcher`, `NS.CreateOptionsPanel`, `NS.Slash` |
| `Database.lua` | The AceDB instance, window shape key-fill, the monotonic id counter, seeding, migrations, and the AceDB profile callbacks | `NS.Database` (`GetWindows`, `FindWindow`, `NextWindowId`, `SeedWindows`, `EnsureWindowShape`), `NS.db`, `NS:InitDB`, `NS:RunMigrations` | `NS.defaults`, `NS.WINDOW_TEMPLATE`, `NS.DefaultWindow`, `NS.Constants.MSG` |
| `Diagnostics.lua` | The section list of the `/mm diagnostics` report and its client probes: atlas probes, the formatter ladder, visibility, header, name column, cells, tooltip font and width, the Targets cross-reference, the provider-order probe, and the rejected events, which close the report. The addon-state sections that open it live in `Diagnostics_Runtime.lua` and are reached through `NS.Diagnostics.Runtime` when they run. LibKa0s-DebugLog-1.0 runs them (`RunDiagnostics`, through the descriptor's `diagnostics` field in `core/DebugLogSetup.lua`), each under its own pcall, and nothing here inspects a meter value. It is also the FRAME the three probe files hang off — the print helpers are defined once, here | `NS.Diagnostics` (`Sections`, `SetEmit`) and, for the three files below, the shared helpers `out` / `safe` / `shown` / `probe` | `NS.DebugLog`, `NS.Print`, `NS.SECRET`, `NS.Provider`, `NS.Constants.STATS`, `NS.Database`, `NS.Secrets`, `NS.WindowManager` |
| `Diagnostics_DeathRecap.lua` | `/mm debug recap` — issue #1's question, asked in one place: can a Death Recap window be built at all, and what does the recap API actually hand back. Self-contained, so it can be deleted with its issue; it also rides along in `/mm diagnostics`, which is why its section function goes back onto the shared table | `Diagnostics.ReportDeathRecap`, `Diagnostics.reportDeathRecap` (the section the frame calls) | `NS.Diagnostics` and its print helpers, **at file scope** — the reason its TOC line must follow `core/Diagnostics.lua` |
| `Diagnostics_Identity.lua` | `/mm debug identity` — the issue #22 identity-correlation measurement: which fields could key a row while `sourceGUID` is secret, and what each one costs when it is absent. **Not** part of `/mm diagnostics`; nothing in the frame reaches into it | `Diagnostics.ReportIdentity` | `NS.Diagnostics` and its `out`, **at file scope**. Prints through the frame's `out` rather than a second printer, so a line from here takes the route the report set |
| `Diagnostics_Runtime.lua` | The addon-state sections of `/mm diagnostics` (DX-MM), written straight to the library's section writer: the latch and its holds, both schema stamps, the profiles, the restriction (mirror, authority, raw state), the session flags and the availability memo; the profile's rows that differ from their defaults plus `enabled`, `master.visibility` and `data.mergePets` always; each window diffed against `NS.DefaultWindow` for its id and name, position from config; the window inventory with the ladder's live and remembered answers; the sessions the client holds and what each window reads; the aggregator's last render pass; the roster and cache counts. Read-only: no reset, no invalidation, no roster build, no geometry off a frame. While stood down, sessions and aggregator say so | `Diagnostics.Runtime` (`state`, `settings`, `windowSettings`, `windows`, `sessions`, `aggregator`, `rosterAndCaches`) | `NS.Diagnostics` **at file scope**; `NS.Schema`, `NS.GetSetting`, `NS.DefaultWindow`, `NS.Database`, `NS.lifecycle`, `NS.Secrets`, `NS.Provider`, `NS.Aggregator`, `NS.Visibility`, `NS.WindowManager`, `NS.State` at call time |
| `Diagnostics_Feign.lua` | `/mm debug feign` — the issue #25 recording, and the sink the trace writes to. The one probe that is not purely a read and the one that carries STATE: a bounded ring, its write index, and the armed flag `modules/Feign.lua` and `modules/Aggregator.lua` check through `NS.Diagnostics` at the three boundaries a feign crosses. Armed before a run, printed after it | `Diagnostics.ArmFeignTrace`, `IsFeignTraceArmed`, `TraceFeign`, `ReportFeign`, `Diagnostics.feignArmed` | `NS.Diagnostics` and its print helpers, **at file scope** |

**Sends:** `MultiMeters.lua` sends `ENTERING_WORLD`, `ROSTER_CHANGED`, `ZONE_CHANGED`,
`RESTRICTION_CHANGED`, `METER_UPDATED`, `METER_SESSION`, `METER_RESET`, `COMBAT_CHANGED` and
`PLAYER_STATE_CHANGED`. `State.lua` sends `TEST_MODE_CHANGED`. `Database.lua` sends
`PROFILE_CHANGED`.

### `defaults/`

| File | Owns | Publishes | Consumes |
|---|---|---|---|
| `Profile.lua` | The window template (`frame`, `header`, `rows`, `bars`, `text`, `icons`, `tooltip`, `visibility`, `columns`, `data`) and the near-empty profile around it: the window array, the id counter, `enabled` | `NS.defaults`, `NS.WINDOW_TEMPLATE`, `NS.DefaultWindow(id, name)` | `NS.Constants` (stat catalog, font name) |

The default window ships six columns, derived from the catalog's `defaultEnabled` flags rather than
restated: Damage · Healing · Interrupts · Dispels · Avoidable Damage · Deaths.

### `modules/`

| File | Module? | Owns | Publishes | Consumes |
|---|---|---|---|---|
| `Format.lua` | plain table | The `NumericRuleFormatter` instances and the three-rung degradation ladder. No division of a meter value, anywhere | `NS.Format` (callable table), `NS.Numbers`, `NS.NumberFormat` — `Number`, `Rate`, `Duration`, `Percent`, `Invalidate` | `NS.Compat.CreateNumericRuleFormatter`, `NS.Secrets`, `NS.State.Cache("Format")`, `NS.L`. Subscribes `CONFIG_CHANGED`, `PROFILE_CHANGED` on a private bus target |
| `Provider.lua` | AceAddon | Every meter read, the memoized availability answer, and the suspend flag | `NS.Provider` — `GetColumn`, `GetSourceDetail`, `GetAvailableSessions`, `GetSessionDuration`, `IsAvailable`, `AvailabilityMemo`, `InvalidateAvailability`, `ProbeSourceByGuid`, `ProbeSourceLookup`, `ProbeSourceFields`, `Reset`, `Suspend` / `Resume` / `IsSuspended` | `NS.Compat`, `NS.Secrets`, `NS.Constants.STAT_BY_KEY`. Subscribes `METER_RESET`, `METER_SESSION`, `ENTERING_WORLD`. **Sends `METER_RESET`** from `Provider.Reset` |
| `Roster.lua` | AceAddon | The group array, the GUID index, the pet→owner map, roles. Rebuilt lazily on first read after an invalidation; a **partial** map (fewer members than `GetNumGroupMembers`) is retried once per aggregate pass, armed by `BeginPass`, never per lookup | `NS.Roster` — `GetGroup`, `LocalGUID`, `Get`, `IsGroupMember`, `OwnerOf`, `RoleOf`, `Refresh`, `Forget`, `BeginPass` (called once at the top of `Aggregator.Build`) | the unit, role and group API through `NS.Compat` (resolved at call time; the simulator's seam), the local player's spec index through `NS.Compat.GetSpecialization`, `NS.State.Cache("Roster")`, and the remembered map at `db.global.roster`, which it owns. Subscribes `ROSTER_CHANGED`, `ENTERING_WORLD`, `PROFILE_CHANGED`, `TEST_MODE_CHANGED`, and `METER_RESET`, which is what forgets the remembered map. A complete build past `4 * MAX_ROWS` remembered members prunes it to the live group (smoke INSTALL-5, branch B) |
| `Feign.lua` | AceAddon | The set of GUIDs believed to be feigning rather than dead. `C_DamageMeter` hands a Feign Death a valid `deathRecapID`, so the Deaths column counts it. **Cannot run while restricted**: it joins a plain GUID against `sourceGUID`, which is secret for the whole of a pull | `NS.Feign` — `Note`, `IsFeigned`, `Prune`, `Clear` | the unit API through `_G` at call time, `NS.Roster.GetGroup`, `NS.Secrets`. Subscribes `METER_RESET`, `ENTERING_WORLD`, `ROSTER_CHANGED`. Fed by `core/MultiMeters.lua`'s `UNIT_SPELLCAST_SUCCEEDED` handler, which owns the only game event |
| `Aggregator.lua` | AceAddon | The exact GUID join — filter, pet folding, the sort ladder, the one-stage-at-a-time scan — and `percent`, and the choice, once per pass, between that join and the identity build next door. The build pipeline is **one algorithm** and issue #30 forbids cutting inside it, which is what decided where the peels went | `NS.Aggregator` — `Build`, `LastIdentityStats`, `LastPass` (the last render pass per window, for `/mm diagnostics`); plus `Aggregator._identity`, the private seam carrying the row-assembly helpers (`newRow`, `setCell`, `isEnemySource`, `UNRANKED`) the identity build shares with the join, and `Aggregator._order`, the seam that carries `UNRANKED` out to the orderings and brings them back | `NS.Provider`, `NS.Roster`, `NS.Secrets`, `NS.State.Cache("Aggregator")`. Subscribes `METER_RESET`, `PROFILE_CHANGED` |
| `Aggregator_Identity.lua` | — | The grid drawn while `sourceGUID` is secret, and the rectangle that measures how much of it got filled: the correlation pass, the collision bookkeeping and the per-pass identity statistics. It exists because the client stopped handing out GUIDs, and it asks a question the join never asks | `Aggregator._identity.buildByIdentity`, and `lastIdentityStats` on the same seam — the one private the peel had to publish, written at the end of a pass here and read by `Aggregator.LastIdentityStats` there | `NS.Aggregator`, `NS.Provider`, `NS.Roster`, `NS.Secrets`, `NS.Constants`, and the five `Aggregator._identity` helpers — all **at file scope**, which is what pins its TOC line after `modules/Aggregator.lua` |
| `Aggregator_Preview.lua` | — | The invented meter: the placeholder group, spells and scaling a player sees when they unlock a window at a target dummy. Placeholder data is required of any addon with a positionable display | `NS.Aggregator.TestGroup`, `TestColumn`, `TestRecap`, `TestSourceDetail` | the module table, and nothing else. **No upvalue crosses the line in either direction** — which is what made this the cheapest second cut once the identity seam had not got the file under on its own. `Provider`, `Roster`, `Tooltip` and `DrillDown` reach these four at call time, behind an `and`, exactly as before |
| `Aggregator_Order.lua` | — | The orderings (`reverseRows`, `orderByProvider`, `orderByValue`, `orderByName`, `orderByRoster`) and the row cap. Each ordering takes a row array and a direction and reads no pass table, which is why they could leave while the ladder that picks among them (`applySortMode`) and Build stayed: peeled in the 2026-09-26 automated-tests sweep (ATS-12), 1432 → 1230 | `NS.Aggregator.ApplyRowLimit`, `SelfPinIndex`; and `orderByProvider`, `orderByValue`, `orderByName`, `orderByRoster` on `Aggregator._order` | `NS.Aggregator`, `NS.Roster`, `NS.Secrets`, `NS.Constants`, and `UNRANKED` off `Aggregator._order` — all **at file scope**, which is what pins its TOC line after `modules/Aggregator.lua` |
| `WindowManager.lua` | AceAddon | The live instance registry and every runtime mutation of the window list: the `architecture-§5` registry writer, with the load pass (`Database.SeedWindows`) the only other writer. Deep-copies on duplicate and copy-from | `NS.WindowManager` — `Resolve`, `Get`, `All`, `Init`, `Create`, `Delete`, `Rename`, `Duplicate`, `CopyFrom`, `RefreshAll`, `MarkAllDirty`, `ResetPosition(s)`, `SetLocked` / `IsLocked`, `SetTestMode` / `IsTest`, `Toggle` / `AnyShown`, `BuildListLines`, `Suspend` / `Resume`, `COPY_GROUPS` | `NS.Database`, `NS.Window`, `NS.State`, `NS.DefaultWindow`. Subscribes `PROFILE_CHANGED`. **The one `WINDOWS_CHANGED` sender** |
| `Window.lua` | plain table + prototype | One instance and its **loop's contract**: the anchor/visible frame rule and the refresh rule in its header, `BuildLayout` (R3), `ChromeOffsets`, `RefreshUpvalues`, and the helpers its siblings share. Issue #29 kept the whole loop in this file; at the cap the owner ruled it split (MM-04, 2026-10-31), along its own banners, into the build-and-apply half and the draw half below | `NS.Window` and the layout `WindowProto` methods, among them `ChromeOffsets()` (the strip's, the column headers' and the body's top, from the layout alone); and, for the five files below, `NS.WindowProto`, `NS.WindowFontPath`, `NS.WindowModule` and `NS.WindowInternals` (`clamp`, `lsm`; `Window_Render.lua` adds the row pool's constructor and the `OnUpdate` clock) | `NS.Constants`, `NS.State`, `NS.Sim`, `NS.DataSetting`, `NS.SkinHudFontSize`, `NS.SkinWindowLooks` |
| `Window_Frame.lua` | — | How a window's frames are built once and dressed on every settings change: the anchor/visible pair, the drag bar, `BuildFrame` (with its once-only helpers `BuildBody` and `BuildStrips`), `ApplyConfig`, `ApplyBorder` and the surface-color reader. Peeled out of `Window.lua` at the cap (MM-04): it runs on a settings change and never on a refresh | `WindowProto:BuildFrame`, `BuildBody`, `BuildStrips`, `ApplyConfig`, `ApplyBorder`; and `NS.SurfaceColor` for `Window_Header.lua` | `NS.WindowProto`, `NS.WindowFontPath`, `NS.WindowModule`, `NS.WindowInternals.clamp` / `.lsm` **at file scope**; `NS.ApplySkin`, `NS.Skin`, `NS.MakeResizable`, `NS.MasterSetting`, `NS.HeaderControls`, `NS.PlayerClassRGB`, `NS.RGBA`, `NS.StatColor` |
| `Window_Render.lua` | — | What a window draws and when: the row pool, the scroll, the `OnUpdate` throttle, `Refresh` and `Render`. Peeled out of `Window.lua` at the cap (MM-04): the half of the loop that runs on the clock | `WindowProto:Acquire`, `HideAll`, `ReleaseSurplus`, `PlaceRow`, `MaxScroll`, `ScrollBy`, `ResetScroll`, `MarkDirty`, `ShouldPoll`, `IsTest`, `Refresh`, `SelfPin`, `Render`; and `newRowPool` / `onUpdate` on `NS.WindowInternals` for `Window_Lifecycle.lua` | `NS.WindowProto`, `NS.WindowModule`, `NS.WindowInternals` **at file scope**; `NS.Row`, `NS.Pool`, `NS.Provider`, `NS.Aggregator`, `NS.DrillDown`, `NS.Secrets`, `NS.Skin` at call time |
| `Window_Lifecycle.lua` | — | How a window is born, re-pointed, stood down and put away, and the bus wiring that keeps it listening in between. Peeled out of `Window.lua` for layout-§1 along the seam the automated-test disposition named: it arms the clock and marks the window dirty, and never decides what is drawn, so it sits outside issue #29's refresh chain | `NS.Window.New(config)`, `WindowProto:RegisterBus`, `UnregisterBus`, `SetConfig`, `Destroy`, `Suspend`, `Resume` | `NS.Window`, `NS.WindowProto` and `NS.WindowInternals`, all at file scope; `NS.NewBusTarget` and `NS.IsStoodDown` at call time. Each instance subscribes 12 messages on **its own** private bus target |
| `Window_Header.lua` | — | The header **band**: the sort art and its ladder, the title bar, the session line, the column labels above the grid, the sort a click on one of those labels performs, the segment dropdown, the session label, the restricted notice and the unavailable notice. The band is computed from config and read back from nothing at all, which is why it separates from the loop cleanly | `NS.HeaderStyle(window)` (the header's font and color, read by `modules/HeaderControls.lua` at call time), and the band's `WindowProto` methods — `ApplyHeader`, `ApplyTitle`, `ApplyHeaderStrip`, `ApplySessionLine`, `ApplyColumnHeaders`, `ApplyMinimized`, `PlaceTestStrip` and `ApplyTestStrip` (the test-mode strip: placed, and on the toggle the narrow re-layout that never runs `ApplyConfig`), `SortByColumn`, `SetSegment`, `SetSessionType`, `OpenSegmentMenu`, `UpdateHeaderText`, `ShowNotice`, `TitleBandHeight()` (the bar from the frame's top edge to the divider: the midline, the divider and the drag strip are all placed from it) and `TitleRowMid(h)` — the one midline the title, the session line and the control strip are all anchored by their middles on | `NS.WindowProto`, `NS.WindowFontPath`, `NS.SurfaceColor`, `NS.WindowModule`, `NS.Constants`, `NS.L`, `NS.PlayerClassRGB`, `NS.RGBA` — the first four **at file scope**, which is what makes its TOC position load-bearing |
| `Window_Placement.lua` | — | Where a window sits, how big it is, whether it is locked, and whether it is on screen at all — everything the player's hands and the visibility ladder do to the frame, as against what the loop draws inside it. **R3 did not weaken on this side of the seam**: `SavePosition` and `SaveSize` ask `inst.anchor`, the bare frame that has never held a meter value, and never `inst.frame` | the placement `WindowProto` methods — `ApplyPosition`, `SavePosition`, `SaveSize`, `ApplyResizeBounds`, `ApplyLock`, `ApplyLevels`, `BringToFront`, `RefreshVisibility`, `Show`, `ClearForcedShow`, `Hide`, `IsShown` | `NS.WindowProto`, **at file scope** |
| `HeaderControls.lua` | plain table | The window's own control strip: which controls exist, where each sits (right-to-left, indexed, a hidden one yields its slot), what art each draws from (our TGA -> Blizzard atlas -> ASCII) and when the set fades | `NS.HeaderControls` — `Attach`, `Apply`, `ApplyLevels`, `HookHover`, `WidthUsed` | `NS.Compat.FirstTexture` / `FirstAtlas`, `NS.SetByPath`, `NS.HeaderStyle`, `NS.ShowResetMeterData`. Every control in the strip is built here, close included, so the strip is the same seven controls with or without LibKa0s. Owns no state and registers no event |
| `Row.lua` | plain table + prototype | Row and cell widgets, **the cell descriptor** — the contract `modules/Tooltip.lua` and `modules/DrillDown.lua` both read, documented once here so neither the peel nor they restate it — the bar skin, the four color rules, the text style, `SetValue`, and the mouse hand-off | `NS.Row.New(window)`, `NS.Row.OffsetFor(layout, index)`, and `NS.RowInternals` (`Cell`, `cellBackground`, `CLASS_TEXTURE`, `newCell`, `RowProto`, `RGBA`, `ClassRGB`, `borderEdge`) for the three files below; `RowProto:ApplyLevel` re-levels the row's overlay frame | `NS.Constants`, `NS.RGBA`, `NS.Format` / `NS.NumberFormat`, and `NS.Tooltip` / `NS.DrillDown` resolved at call time |
| `Row_Border.lua` | — | The cell outline `bars.border` asks for. Two mutually exclusive paths: four flat edge textures at OVERLAY sublevel 7 (the shipped default, built on first use and kept), or an LSM edge file drawn as the bar's **own** backdrop, never a child frame (R3). One color rule (`bars.borderColorMode`, `class` being this row's player) and one clamped thickness serve both. Peeled out of `Row.lua` for layout-§1; `Row.lua` calls its two methods by name at call time | `Cell:ApplyBorder`, `Cell:ApplyEntryBorderColor` | `NS.RowInternals`' `Cell`, `RGBA`, `ClassRGB` and `borderEdge` **at file scope** — the reason its TOC line sits right after `modules\Row.lua` |
| `Row_Cells.lua` | — | Which of a row's cells are live, and handing the row back. `BindLiveCells` grows the cell set to the layout's columns and rebuilds `row.liveCells` **in place** — cleared with a numeric loop, never reallocated — hiding and blanking the cells the layout dropped; `RowProto:Update` walks that array rather than every cell the row ever had (review F-007). `Release` blanks every cell when a row leaves the screen | `RowProto:BindLiveCells`, `RowProto:Release` | `NS.RowInternals.RowProto` and `.newCell` **at file scope** — the reason its TOC line sits right after `modules\Row.lua` |
| `Row_NameCell.lua` | — | The leading column's cell alone: the icon strip, the name string, and the two decisions that keep them clear of each other. A sibling rather than a new widget — it hangs two more methods on the **same** `Cell` prototype — and the block that grows, since every identity, spec-icon and pet-fold change lands in it. `Row.lua`'s rules bind unchanged: no arithmetic on a meter value, and no `GetWidth` / `GetLeft` / `GetPoint` anywhere (R3) | `Cell:ApplyIcons`, `Cell:SetPlayer`, `NS.ICON_TEXT_GAP` | `NS.RowInternals`' three members **at file scope** — the reason its TOC line sits after `modules\Row.lua` — and `NS.Secrets`, for exactly one question: may this GUID be looked at |
| `Targets.lua` | plain table | The enemy cross-reference. One walk over every `EnemyDamageTaken` source's spells builds **every** player's target list at once, keyed on `combatSpellDetails.unitName` and cached per session. **All-or-nothing**: one unreadable amount abandons the whole build | `NS.Targets` — `ForPlayer`, `Total`, `Invalidate` | `NS.Provider.GetColumn` / `GetSourceDetail`, `NS.Secrets`, `NS.State.Cache("Targets")`. Subscribes `METER_RESET`, `METER_SESSION`, `METER_UPDATED`, `PROFILE_CHANGED` on a private bus target |
| `Tooltip.lua` | AceAddon | The **primitives** every hover is built out of, and the teardown: the secret-safe wrappers (`unreadable`, `plainWord`), the display name and its color, the resolved config, font and placement, the spell collection and its legal-only sort, the shared line pool's font handling, and `Tooltip:Hide` (which restores the SHARED line FontStrings). This is the half that must not be touched casually, which is why it is the half that stayed | `NS.Tooltip` — `Hide` — and `NS.TooltipInternals`, the private table the other two files of the peel resolve at file scope | `NS.Provider`, `NS.Secrets`, `NS.Numbers`, `NS.Compat.GetSpellInfo`, `NS.WINDOW_TEMPLATE`, `NS.Database.FindWindow` |
| `Tooltip_Lines.lua` | — | **One pooled line, as a widget**: the carrier frame and its bar, the text measurement every width rests on, the slot layout, the resolved style and the draw itself — plus the four death helpers that decide what a death line's label says before anything is drawn | `Tooltip.WidthParts(style)`, and the drawing primitives it fills in on the second half of `NS.TooltipInternals` | every name it uses off `NS.TooltipInternals`, **at file scope** — a position before `modules/Tooltip.lua` would freeze a table of nils in for the session — plus `NS.L` and `NS.Compat` |
| `Tooltip_Builders.lua` | — | **What a hover says**: the death events behind one death (issue #1), and the four tooltips the primitives assemble — Targets (which enemies this player hit), the per-cell spell breakdown, the name tooltip that summarizes every tracked statistic for one player, and the spell row inside a breakdown. This is the part a feature adds to | `Tooltip:CellTooltip`, `Tooltip:NameTooltip`, `Tooltip:SpellTooltip` | `NS.TooltipInternals` **at file scope**, and the second half of that table is not filled until `modules/Tooltip_Lines.lua` has run — so its TOC line follows **both**. Also `NS.Constants`, `NS.Compat`, `NS.State`, `NS.Debug`, `NS.L`. The secrets rule binds hardest here, because this is where "just show the top five" and "put the total at the bottom" would be written |
| `DrillDown.lua` | AceAddon | Per-window view state (session-only, in `State.Cache`), the spell-row contract, click routing, the death recap | `NS.DrillDown` — `GetState`, `IsActive`, `Enter`, `Exit`, `ExitAll`, `OnCellClick`, `OnRowClick` (the right-click way out, called from `Row.lua`), `BuildRows`, `Title` | `NS.Provider`, `NS.Secrets`, `NS.Compat`, `NS.Database.FindWindow`. Subscribes `METER_RESET`, `PROFILE_CHANGED`, `WINDOWS_CHANGED`. **The one `DRILLDOWN_CHANGED` sender** |
| `Export.lua` | plain table | **The pure half**, which is the seam this file's own header had been naming since it was written: the two serializers and everything they need. `HeaderName`, `CsvField` and `Columns` derive the CSV shape from the stat catalog rather than restating it; `SessionConfig` builds the synthetic window config the aggregator is asked with; `ResolveChannel`, `ChatBatch`, `SendDelay` and `Send` carry the throttled dump and its whisper-failure watch. **Draws no frame.** **Refuses entire while the Combat restriction is active** — `tostring` is not a permitted operation on a secret | `NS.Export` — `Available`, `HeaderName`, `CsvField`, `Columns`, `SessionConfig`, `Build`, `SessionLabel`, `CSV`, `ChatLines`, `ResolveChannel`, `TargetName`, `NeedsHardwareEvent`, `ChatBatch`, `SendDelay`, `Send`, `NoteSystemMessage` — plus the three privates the modal reads, `Export.__EM_DASH`, `__cfgOf` and `__channelRow` | `NS.Aggregator.Build`, `NS.Format`, `NS.Constants` (`STATS`, `STAT_BY_KEY`, `MAX_ROWS`, `SESSION_TYPE`, `EXPORT_CHANNELS`, `EXPORT_CHANNEL_BY_KEY`), `NS.Compat.ChatSender` (the only way `Send` reaches a channel), and `NS.Secrets` — resolved through its own `mod()` lookup at **call** time, never captured, so the pure half holds no sibling as an upvalue |
| `Export_Modal.lua` | — | **The UI half**: the dialog the header glyph and `/mm export` open, its three selectors — `LibKa0s-Widgets-1.0` dropdowns since the collection grew a shared one — the whisper row, the two action buttons and the copy-paste window. Every frame this feature draws is here and nowhere else; all of it is built lazily on the first `Open` and reused forever, so a session in which nobody exports never pays for it. The combat refusal is enforced **again** here, and deliberately more than once — `Available()` on open, again inside each click handler, and once more inside the serializers — because the restriction can activate while the modal sits open, and the click is the last moment anyone can check | `NS.Export.Open`, `NS.Export.ResolveMetric` | `Export.__EM_DASH` / `__cfgOf` / `__channelRow` **at file scope**, which is what pins its TOC line after `modules/Export.lua`; plus `NS.Constants` (including `FONT_MONO` for the copy window), `NS.L`, `NS.GetSetting` / `NS.SetByPath`, `NS.ApplySkin`, `NS.MakeCloseButton`, `NS.NewBusTarget`, and `LibKa0s-Widgets-1.0` looked up directly — the one library this pair reaches for itself rather than through a `core/*Setup.lua` seam, because the widget is built lazily inside `Open` rather than wired at load; it calls `W.CloseMenu()` from the modal's `OnHide`, since the popup is process-wide and the modal's own `Hide` does not reach it. Subscribes exactly one message — `RESTRICTION_CHANGED`, on a private target taken with the modal frame, so an open dialog grays itself when a pull starts — and sends none |
| `Visibility.lua` | AceAddon | The context translation table and the predicate: context first, then the hide-shaped vetoes, then the two combat rules. No frame is touched and no message is sent | `NS.Visibility` — `GetContext`, `ShouldShow`, `Allows`, `Evaluate`, `Refresh`, `LastResult`, `Forget` | `NS.Database.GetWindows`, the instance and player-state APIs through `_G`, and `NS.Compat` for the delve / skyriding / housing probes. Subscribes `ZONE_CHANGED`, `ENTERING_WORLD`, `ROSTER_CHANGED`, `COMBAT_CHANGED`, `PLAYER_STATE_CHANGED`, `PROFILE_CHANGED` — for the Evaluate pass only, which runs only under debug and feeds its debug line and `/mm diagnostics`'s per-window "last pass" lines; the window re-runs the ladder off the same two messages, because this module publishes nothing |
| `Sim.lua` | plain table | The simulator's **session host** (MultiMeters#60). Builds `NS.Sim` with `LibKa0s-Sim-1.0`'s `New` over `NS.SimSeam`, delivering through `NS.DeliverEvent`. The start's refusals, in order (stood down, test mode, combat, an instance, a group, General visibility `never`), each run inside `NS.SimSeam:Live` and each a `[Sim]` debug line naming its guard; the gate (closed while `w.pending` fight ticks are booked); `Prepare` (the world from the real player, the window pin snapshot in `session.mmPins`, `NS.RealEventFilter`, `SIM_CHANGED { active = true }`, the simulated `DAMAGE_METER_RESET`, the step panel); the real-event classifier `OnRealEvent` (`EVENT_RULES`: combat and a restriction edge stop with `combat`, a world entry with `world`, a live group with `group`, a live instance with `instance`, the client's meter events are consumed); and the seven stop steps (the filter cleared, the pins restored unless the reason is `profile`, the caches wiped, the resync through `ENTERING_WORLD`, `METER_SESSION` and `COMBAT_CHANGED`, never `METER_RESET`, the drill-down closed, `SIM_CHANGED { active = false }`, `Host.lastStop`). The step delay is the constant `Host.STEP_DELAY` (1 s). With the library absent `NS.Sim` stays `core/SimSetup.lua`'s stub | `NS.Sim` (live), `NS.SimHost` — `SCENARIOS`, `PANEL`, `STEP_DELAY`, `StepDelay`, `Refusal`, `Gate`, `Prepare`, `OnRealEvent`, `EVENT_RULES`, `StatusLine`, `PanelAnchor`, `world`, `lastStop`. **The one `SIM_CHANGED` sender** | `LibKa0s-Sim-1.0`, `NS.SimSeam`, `NS.Constants.MSG` **at file scope**; `NS.SimHost.World`, `NS.Compat`, `NS.Database`, `NS.WindowManager`, `NS.SetByPaths`, `NS.DrillDown`, `NS.Slash` at call time |
| `SimWorld.lua` | plain table | The simulator's **invented world** (MultiMeters#60) and its answers. `World.New(seed, player)` builds it from a seeded Park-Miller generator: the real player first (GUID, name, class and live spec role read by the caller inside `NS.SimSeam:Live`), then fixed seeded mates `Player-9998-SIM%04d` from forty invented names, hunters and warlocks with pets `Pet-0-9998-SIM%04d`. Pure functions of the world table edit it: `SetGroup` (party or raid tokens, the player at a seeded raid index), `SetZone`, `OpenSegment` / `CloseSegment`, `Tick` (rate x seconds per stat, pets dealing a quarter of their owner's damage as their own row, the enemy taking the group's damage), `Die` (a Deaths row and a recap in `Aggregator.TestRecap`'s shape), `ResetSegments`; `Session`, `SourceDetail` and `AvailableSessions` answer fresh tables in the client's shape. **Plain invented numbers only**: it never reads a client meter value, so `core/Secrets.lua` stays the only inspector of client values, and it never spells a `Compat.`-prefixed meter shim (the `test_provider` scan) | `NS.SimHost.World` (`New`, `SetGroup`, `Unit`, `SetZone`, `OpenSegment`, `CloseSegment`, `Tick`, `Die`, `ResetSegments`, `Session`, `SourceDetail`, `AvailableSessions`, `PROVIDED`, `PROVIDERS`, and the `ZONES` / `NAMES` / `CLASSES` tables); 22 providers registered by key on `NS.SimSeam` **at file scope** | `NS.SimSeam` **at file scope**; `NS.SimHost.world`, `NS.Constants.STAT_TYPE` / `SESSION_TYPE` / `SOURCE_DISPLAY_TYPE` at call time |
| `SimDrivers.lua` | plain table | The simulator's **drivers** (MultiMeters#60). Each edits the world (`NS.SimHost.world`) first, then fires the client's events through `NS.Sim:Fire`, read at call time, with the client's payloads and order: `FormGroup(n, raid)` and `Disband()` (`GROUP_ROSTER_UPDATE`); `Zone(key)` (`PLAYER_ENTERING_WORLD(false, false)`, then `ZONE_CHANGED_NEW_AREA`); `Pull(fight)` (a new segment, combat on, `PLAYER_REGEN_DISABLED`, then the first `Tick`); `Tick(fight)` (the world grows by `secondsPerTick`, any death booked for that tick, `DAMAGE_METER_CURRENT_SESSION_UPDATED`); `EndFight(fight)` (combat off, `PLAYER_REGEN_ENABLED`, then one `DAMAGE_METER_COMBAT_SESSION_UPDATED(enumValue, sessionID)` per `Constants.STATS` entry in order, then `DAMAGE_METER_CURRENT_SESSION_UPDATED`); `Reset()` (the player's own `Provider.Reset`, which the guarded `ResetAllCombatSessions` answers); `Fight(fight)` (the pull and first tick now, ticks 2..n booked `TICK` = 0.5 s apart with `NS.Sim:After`, counted on `w.pending`, the last ending the fight). Sends no bus message and never calls the client's meter; every timer is a session timer, so a stop cancels a fight in flight | `NS.SimHost.Drivers` (`FormGroup`, `Disband`, `Zone`, `Pull`, `Tick`, `EndFight`, `Reset`, `Fight`, `TICK`) | `NS.SimHost.World` **at file scope**; `NS.Sim`, `NS.SimHost.world`, `NS.Provider` and `NS.Constants.STATS` at call time |
| `SimScenario.lua` | plain tables | The simulator's **scenarios** (MultiMeters#60), filled into `NS.SimHost.SCENARIOS` in place: `dungeon` (a 5-player group, The Rookery, Trash 6 x 4 s, Speaker Shadowcrown 10 x 18 s with a damage dealer dying at tick 7), `raid` (a 20-player raid, Liberation of Undermine, Vexie and the Geargrinders 12 x 25 s with two deaths), `wipe` (the boss as `Speaker Shadowcrown (wipe)`, everyone dead by tick 8, a meter reset, a 4-tick re-pull) and `zone` (Trash in The Rookery, the Isle of Dorn, the Priory of the Sacred Flame, Trash again). No `sizes`. Each timeline builds fresh `{ kind, label, tip, ... }` steps (the library stamps the steps it plays), with localized labels and tips naming the events the step fires and what the world holds after it. `Host.Play(step, session)` runs `PLAY[step.kind]` (`form`, `zone`, `fight`, `reset`) through the drivers and answers the step's detail | `NS.SimHost.Play`, `NS.SimHost.PLAY`, `NS.SimHost.FIGHTS`, the four `SCENARIOS` entries | `NS.SimHost.Drivers` and `NS.SimHost.World` **at file scope**; `NS.L` |

### `settings/`

| File | Owns | Publishes | Consumes |
|---|---|---|---|
| `Schema_Compose.lua` | What the array is **declared out of**, and nothing else: the refresh routing a row's `onChange` reaches for, the dropdown vocabularies its `values` point at, the common validators, and the LibKa0s-Options-1.0 composers together with every canonical block composed out of them. It holds no row of its own — the composers decide *which* rows there are, and `Schema.lua` decides where they sit | `NS.SchemaCompose` (one table rather than fifty names on `NS`, so the peel costs the namespace one entry and the array can re-localize each member under the name its rows already spell) and `NS.MasterControlsAfterGroup`, published separately because `settings/General.lua` is its reader | `NS.L`, `NS.Constants`. Captures nothing across the load boundary — but **not for one reason**, and the TOC only accounts for one of the four. `NS.Helpers` is the one this file genuinely loads before: `settings/OptionsSetup.lua` builds it afterwards, which is why a media row's `values` has to be the deferred `lsmValues` closure rather than a list. `NS.db` exists at **no** file's load time at all: `core/Database.lua` loads long before this one, but it only *declares* `NS:InitDB`, and the AceDB object is not assigned until that runs inside `OnInitialize`. `NS.WindowManager` and `NS.Visibility` both publish themselves at file scope and both load **before** this file, so a capture would in fact resolve; they are still reached through `NS` because the only things that reach them are runtime callbacks — `onResetPosition` wants the live registry and whatever `NS.State.activeWindowId` names at the moment of the click, Lock frame's `get`/`set` want the live registry's `IsLocked`/`SetLocked`, and `refreshVisibility` falls back to `NS:GetModule("Visibility", true)` so a partial install fails open rather than freezing a nil in |
| `Schema.lua` | **The array, and nothing else.** 180 rows across 8 page keys, each one the single source of truth for a setting's widget, its CLI parser and its default. This is the file that grows, and a new setting is still one row in it | `NS.Schema` | every member of `NS.SchemaCompose`, resolved **at file scope** as the array is declared — which is what puts `settings/Schema_Compose.lua` ahead of it in the TOC |
| `Schema_Skin.lua` | The eight skin rows (skinning-§2, §3): `skin.source`, `skin.skin`, the Scope's `skin.ignorePanel` and `skin.ignoreFonts`, the overrides `skin.font` and `skin.texture`, the Font outline `skin.outline`, and `skin.pickerSeen`, every one `skipRender` in the Skin tab's group (`NS.SKIN_TAB`, `"Appearance"`) on the General page, each `onChange` applying only its own half. A file of its own because `Schema.lua` sits near the 1500-line cap. **Load-bearing position**: after `Schema.lua`, whose array it appends to, and before `Schema_Paths.lua`, which indexes the finished array | rows appended to `NS.Schema` | `NS.defaults.profile.skin`, `NS.SKIN_TAB` and the value tables `core/SkinSetup.lua` publishes, `NS.ApplySkinChoice` / `ApplySkinIgnore` / `ApplySkinOverride` / `ApplySkinOutline` at call time |
| `Schema_Paths.lua` | The settings runtime's descriptor (issue #52). The machinery — path splitting and walking, the `path → row` index, the single write seam, the all-or-nothing batch and the bulk bracket that logs a bulk copy or reset as one `[Set]` line — is `LibKa0s-Schema-1.0` minor 2's; this file builds its one instance, or the write-completing degradation stub in the shape the library's docs prescribe, and supplies what is this addon's: window resolution and the window-relative path model, the announce, the hidden `window.columns` row (written whole, repaired by its `normalize`), and the page and validation surfaces. The one inverted row keeps its own get/set in `Schema_Compose.lua` | `NS.SchemaRuntime`, `NS.__schemaLib`, and the shims `NS.GetSetting`, `NS.SetByPath`, `NS.SetByPaths` (both taking an optional window id), `NS.FindSchemaRow`, `NS.RegisterSchemaRows`, `NS.ApplyDefault`, `NS.Bulk` (`begin` / `finish` / `run`, the runtime's `BulkBegin` / `BulkEnd` / `BulkRun`); `NS.SchemaForPage`, `NS.ValidateSchema`, `NS.NormalizeColumns`, `NS.MINIMAP_PATH` | `NS.Schema` **at file scope** — the runtime builds its index by walking the array, which is why it must load *after* it — plus `NS.db`, `NS.State.activeWindowId`, `NS.Constants`, and `NS.Helpers` / `NS.Visibility` at call time. **The one `CONFIG_CHANGED` sender** |
| `Slash.lua` | `NS.COMMANDS`, the five schema adapters pointed at the seam above, the `profile` row (the descriptor's `profiles` answers `NS.db`; the verb is the library's `CliProfile`), the six window verbs, the library-absent stub, and the descriptor's `isEnabled` / `brandName` — the LIBRARY's disabled gate, with `liveVerbs` = the library's thirteen reserved verbs plus `profile`, so only this addon's own feature verbs refuse (`slash-commands-§2`, `§7`). The descriptor's `debug` is the gated sink, so every refusal the dispatcher decides is the library's `[Cmd]` line. `NS.Slash.__dispatcher` is a debug seam for the parity case | `NS.Slash` — `Register`, `OnSlash`, `PrintHelp`, `HelpRows`, `LandingRows`, `DisabledLine`, `Version` | LibKa0s-Slash-1.0, `NS.WindowManager`, `NS.DebugLog`, `NS.Perf`, `NS.Export`, the schema seam |
| `OptionsSetup.lua` | The options descriptor, the page registry, the reset-all veto (`page == "profiles"`), the one row no reset in the panel may write (`global.minimap.shown`, exempted at `applyDefault` — `launcher-§3`), the Windows page's entry registry, `RenderWindowPage`, `SelectSection`, `OpenOptionsPage` (MultiMeters#55), and the library-absent stub | `NS.Helpers` (the library instance itself), `NS.CreateOptionsPanel`, `NS.OpenOptionsPanel`, `NS.RefreshOptionsPanel`, `NS.RegisterWindowSection`, `NS.__WindowSection` (test seam), `Helpers.RenderWindowPage`, `Helpers.RestoreActiveSection` | LibKa0s-Options-1.0, `NS.Schema`, `NS.Slash:LandingRows` |
| `Windows.lua` | The window picker — `H.WindowBanner`, **the only writer of `NS.State.activeWindowId`**, decorated onto the library instance and drawn once, as the Windows page's band above its rail — and the Windows page's General entry (MultiMeters#55): the registry buttons (New window in the band through `O.PageBanner`'s `action`; rename, Duplicate and Delete on the entry) plus the Copy settings from block with its group filter, whose display labels name what is copied, on one bespoke General tab | a page registration and a Windows-page entry | `NS.WindowManager`, `NS.State.SetActiveWindow`, `NS.RefreshOptionsPanel` |
| `Frame.lua` | Windows-page entry: registers `frame` (28 rows across four tabs: Size and position, Quick style, Background and border, Rows). Pure schema — the header controls moved to Header and "Reset position" to General | a Windows-page entry | `NS.Helpers` |
| `Header.lua` | Windows-page entry: registers `header` (38 rows across three tabs: Title bar, Title text, Controls): the title bar's own shape, its text, and the icon strip it carries -- which buttons are shown and how they are drawn, one Controls tab since item 020. The column-header strip moved to the Columns entry it labels. Rows are stored at `window.frame.*` / `window.header.*`. Pure schema | a Windows-page entry | `NS.Helpers` |
| `Bars.lua` | Windows-page entry: registers `bars` (31 rows across three tabs: Bar, with Fill, Background and Border subsections; Text, with Content and Style; Icons): the bar, its background, its border, the cell's two text slots and the row icon. The Text and Icons pages folded in here; their PATHS did not move with them. Pure schema | a Windows-page entry | `NS.Helpers` |
| `Tooltip.lua` | Windows-page entry: registers `tooltip` (34 rows across four tabs: General, Contents, Bar, Text; Death timestamps is edited under Contents > Deaths while stored at `window.text.deathTimeFormat`). Pure schema | a Windows-page entry | `NS.Helpers` |
| `Visibility.lua` | Windows-page entry: registers `visibility` (17 rows on one Rules tab, under Show in, Hide when and Combat). Pure schema | a Windows-page entry | `NS.Helpers` |
| `ColumnBlocks.lua` | The ROW CONTENTS of a reorderable list — state glyph, label, and the rule where the enabled ones stop — plus the wiring that hands the list to LibKa0s. The **gesture and the chrome** are `LibKa0s-Widgets-1.0`'s `ReorderList` (minor 9): the handle, its 30px gutter, the **bounded box behind every row**, the carried copy, the insertion line and the clamp. The host's own row background was deleted in the same change as the re-vendor, or the two fills would stack. Loads **before** `Columns.lua` | `NS.ReorderableBlocks(ctx, spec)`, `NS.BLOCK_HEIGHT`, `NS.BLOCK_STRIDE` | `LibKa0s-Widgets-1.0`, `NS.Helpers.EnsureScroll`, `NS.AceGUI`, `NS.Icon` |
| `Columns.lua` | Windows-page entry: registers `columns` (9 schema rows — the `window.columnHeader.*` text and background rows moved here from Header, and the face's "Use the skin's font" companion — on its Column header tab, under Text and Background), plus the block editor: one block per statistic, ticked or not, dragged into order, on the tab that carries **no** schema rows. Every write to the array hands the seam a freshly built whole array, and every mutation re-checks combat | a Windows-page entry | `NS.ReorderableBlocks`, `NS.SetByPath("window.columns", …)`, `NS.Constants.STATS` |
| `General.lua` | The General page (30 rows in all: **three** drawn tabs — **Master controls**, **Behavior**, Statistic colors — plus a fourth group, Export, whose four rows are `hidden` and therefore never become a tab, and the eight skip-render skin rows `settings/Schema_Skin.lua` appends, whose group the library's **Skin** tab takes, before Keybindings): `options-ui-§15`'s canonical set, Minimap button and Test mode included and nothing of this addon's own after it; the two addon-wide data settings, Merge pets and Refresh interval, moved to the **Behavior** tab, since §15 fixes Master controls' set and neither is canonical, and the eight generated statistic-color swatches. The `General` tab that held those three and Test mode was retired into Master controls — §15 forbids reordering, renaming or splitting the canonical set, and the eight canonical rows are the whole tab now: Test mode became canonical in standard v2.47.0 and the minimap toggle in v2.53.0, so this addon has no row of its own left on it. The reset **button pair** is drawn by the hook `H.MasterControls` hands back, not here; what this file still supplies is the reset-everything confirmation popup and one sentence under each of two tabs. Also hosts the **reset-meter-data dialog**, which has no button on any page: the header's own reset control is the one way to open it, and it routes to `NS.Provider.Reset` rather than to the Compat shim | a page registration, `NS.ShowResetMeterData` | `NS.Helpers`, `NS.MasterControlsAfterGroup`, `NS.Provider.Reset` |
| `Profiles.lua` | The AceDBOptions profile tree, hosted in this addon's canvas. **The one place `AceConfigDialog` is permitted**, and the one page vetoed from reset-all | a page registration | AceDBOptions-3.0, AceConfigDialog-3.0 |

Schema rows total 188 across 8 page keys — windows 1, frame 28, header 38, bars 31, tooltip 34,
visibility 17, columns 9, general 30. Counting them means reading `settings/Schema.lua` (180, the
array is the whole of that file) and `settings/Schema_Skin.lua` (the eight skin rows it appends);
`Schema_Compose.lua` contributes no row. `Schema_Paths.lua` appends exactly one more, the hidden
`window.columns` row (189 at runtime). `profiles` is the only page with zero schema rows: it hosts
AceDBOptions' own tree rather than any of ours, which is bespoke by necessity and says why in its
file header. `columns` carries 9 schema rows (the column-header text and background rows moved here
from Header) plus a bespoke block editor with none — the array it edits is also bespoke by necessity,
for the same "a flat path model has no vocabulary for this shape" reason.

## Load order

`MultiMeters.toc` is authoritative. The order is dependency, not alphabetical.

`Bindings.xml` at the repo root is NOT in the TOC: the client reads it from the addon folder by
name, as it does the TOC itself. It declares the one `CLICK MultiMetersToggleWindows:LeftButton`
binding (`launcher-§6`), in the category `BINDING_HEADER_MULTIMETERS` with no `header`, and no Lua;
the button it clicks, both labels and `NS.BINDINGS` (the table the General page's Keybindings tab
draws) come from `core/LauncherSetup.lua` at load.

1. **`libs/`** — LibStub, CallbackHandler, AceAddon/Event/Timer/DB/DBOptions/Console/Config/GUI,
   LibKa0s, LibSharedMedia, AceGUI-3.0-SharedMediaWidgets, LibDataBroker, LibDBIcon.
2. **`locales/enUS.lua`** — first, so `NS.L` exists for every declaration below.
3. **`core/`**, in this order and for these reasons:
   1. `Compat.lua` — first in the block, though nothing now depends on that: the TOC-manifest
      reader that used to make it load-bearing has moved to `EnvSetup.lua`. **`SimSetup.lua` follows
      it straight away, and that is load-bearing**: the seam wraps every `NS.Compat` member in place
      at load, so a file between the two could capture or call a member before the wrap (LibKa0s Sim
      host contract H2). The two move together.
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
      file-scope reader. `SkinSetup.lua` follows it (**load-bearing**): it registers the owner and
      publishes `NS.Skin` and the skin rows' value tables at file load, so it sits above every file
      that builds a frame and above `settings/Schema_Skin.lua`, and reaches `CoreSetup`'s
      `NS.ApplySkin` and `NS.Print` at call time.
   8. `PerfSetup.lua` — after `Namespace` (a nil `version` stamps every capture record `v?`) and
      **before every `modules/` file that takes `local Perf = NS.Perf` at load**.
   9. `DebugLogSetup.lua` — after `Constants`, `State` and `CoreSetup`.
   10. `MediaSetup.lua` — **before `Constants.lua`**, which resolves `FONT_MONO` from `NS.MediaFont`,
      and therefore before `defaults/Profile.lua` names the font at load. This is one of the few
      TOC positions in `core/` that is load-bearing rather than conventional.
   11. `PoolSetup.lua` — after the `libs/` block and **before `modules/Window.lua`**, ahead of the
      pool's only consumer, `modules/Window_Render.lua`. It carries no other constraint: it publishes `NS.Pool` and captures nothing.
   12. `MultiMeters.lua` — after every setup file; promotes `NS` into the AceAddon object.
   13. `Database.lua` — after `State`, before `OnInitialize` runs. Reads `NS.defaults` at *call*
       time, because `defaults/` loads later.
   14. `Diagnostics.lua` — **deliberately unconstrained.** It reads every module at *call* time
       and owns no state, so nothing depends on where *it* loads. What does depend on it is
       everything below.
   15. `Diagnostics_DeathRecap.lua`, 16. `Diagnostics_Identity.lua`, 17. `Diagnostics_Feign.lua`,
       18. `Diagnostics_Runtime.lua` —
       **all four after `Diagnostics.lua`, and load-bearingly so.** Each resolves `NS.Diagnostics`
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
   **`Aggregator_Identity` → `Aggregator_Preview` → `Aggregator_Order`** → `WindowManager` → `Window` →
   **`Window_Frame` → `Window_Render` → `Window_Lifecycle` → `Window_Header` → `Window_Placement`** → `HeaderControls` → `Row` → **`Row_Border`** → **`Row_Cells`** → **`Row_NameCell`** →
   `Targets` → `Tooltip` → **`Tooltip_Lines` → `Tooltip_Builders`** → `DrillDown` → `Export` →
   **`Export_Modal`** → `Visibility` → `Sim` → `SimWorld` → `SimDrivers` → `SimScenario`.

   `Sim` builds `NS.Sim` with the host's own tables (`NS.SimHost.SCENARIOS` and `PANEL`), which the
   simulator files after it fill in place, so it loads ahead of all of them (a LOAD-BEARING TOC
   note); the library reads every descriptor table at use. `SimWorld` registers its providers on
   `NS.SimSeam` at *file scope*, so it must follow `core/SimSetup.lua` (a LOAD-BEARING TOC note). `SimDrivers` captures `NS.SimHost.World` at
   *file scope*, so it follows `SimWorld` (its own LOAD-BEARING note). `SimScenario` fills
   `NS.SimHost.SCENARIOS` and sets `NS.SimHost.Play` at *file scope* and captures `NS.SimHost.Drivers`
   and `NS.SimHost.World` there, so it follows `SimDrivers` (its own LOAD-BEARING note).

   The fourteen in bold are the layout-§1 peels, and **every one of their positions is load-bearing**
   for the same reason: each resolves something its parent publishes at *file scope*, so a peel
   ahead of its parent captures nil and stays nil for the session.
   `modules/Aggregator_Identity.lua` takes the five row-assembly helpers off `Aggregator._identity`;
   `Aggregator_Preview.lua` needs only the module table, but is kept beside its sibling because that
   is where the reading order puts it. `Aggregator_Order.lua` takes `UNRANKED` off `Aggregator._order`.
   `Window_Frame.lua` and `Window_Render.lua` resolve `NS.WindowProto`, `NS.WindowModule` and
   `NS.WindowInternals` (`Window_Frame.lua` also `NS.WindowFontPath`), all published by
   `modules/Window.lua`, and they come next because the three after them read what they add:
   `Window_Lifecycle.lua` resolves `NS.Window`, `NS.WindowProto` and `NS.WindowInternals` (whose
   `newRowPool` and `onUpdate` `Window_Render.lua` hangs on it), `Window_Header.lua` resolves
   `NS.WindowProto`, `NS.WindowFontPath`, `NS.SurfaceColor` (published by `Window_Frame.lua`) and
   `NS.WindowModule`, and `Window_Placement.lua` resolves `NS.WindowProto`. `Window_Header.lua` also sits **ahead of**
   `HeaderControls.lua`, which reads the `NS.HeaderStyle` it publishes; that read is at *call* time,
   so this half is order by intent rather than a load-time requirement, and the TOC says which is
   which.
   `Row_Border.lua` resolves `NS.RowInternals.Cell`, `.RGBA`, `.ClassRGB` and `.borderEdge`,
   `Row_Cells.lua` `.RowProto` and `.newCell`, and `Row_NameCell.lua` `.Cell`, `.cellBackground` and
   `.CLASS_TEXTURE`, all three after `modules/Row.lua`.
   `Tooltip_Lines.lua` resolves `NS.TooltipInternals` after `modules/Tooltip.lua`, and
   `Tooltip_Builders.lua` must follow **both**, because the second half of that table is not filled
   until `Tooltip_Lines.lua` has run. `Export_Modal.lua` resolves `Export.__EM_DASH`, `__cfgOf` and
   `__channelRow` after `modules/Export.lua`.

   `Row.lua` loads
   before `Tooltip.lua` and `DrillDown.lua` and therefore resolves both at *call* time. `Targets.lua`
   loads before `Tooltip.lua`, which is its only caller, and resolves the provider at *call* time for
   the same reason `Tooltip.lua` does. `Export.lua` is the one entry here under **no** constraint at
   all: its in-addon caller — `modules/HeaderControls.lua`'s export control — loads *before* it, so it can
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
   3. `Schema_Paths.lua` — **after the array**, because its runtime builds the `path → row` index by walking
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
3. `NS.Launcher:Register()` — **after** `InitDB`, because LibDBIcon stores the button's position
   inside the table it is registered against, which is `NS.db.global.minimap`. Idempotent.
4. `NS.CreateOptionsPanel()` — schema validation, the parent category, and the queued page builders.
5. `NS.Slash:Register()` — `/mm` and `/multimeters`, through AceConsole. If the settings layer never
   loaded, both verbs are claimed anyway and say so rather than going silent.

**`NS:OnEnable`** registers the game events — the **22** rows of the `EVENTS` array, each through
`NS.SafeRegisterEvent`, all with the ONE handler name `OnGameEvent` (MultiMeters#60). The rows name
**12** handler methods, folded at load into `NS.HANDLER_BY_EVENT`; `NS:OnGameEvent` consults
`NS.RealEventFilter` (the simulator's hook, `nil` outside a session) and otherwise calls
`NS.DeliverEvent`, which calls the named method. Eleven of the 22 are the player-state block behind
`OnPlayerStateChanged`. Which event becomes which message is tabulated in `docs/ARCHITECTURE.md` →
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
load: a private bus target carrying `RESTRICTION_CHANGED`, so a dialog left open across a pull grays
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
addon. Since the 2026-10-29 skinning rollout each of those surfaces also wears this addon's own
skin, through `core/SkinSetup.lua` (ARCHITECTURE.md [Skins](ARCHITECTURE.md#skins)). Twelve LibKa0s majors are consumed — Core, Media, Perf, DebugLog, Env, Pool, Launcher, Slash, Options,
Sim, Skin and Widgets. Eleven are reached through a seam file of their own (`core/CoreSetup.lua`,
`core/MediaSetup.lua`, `core/PerfSetup.lua`, `core/DebugLogSetup.lua`, `core/EnvSetup.lua`, `core/SimSetup.lua`,
`core/SkinSetup.lua`, `core/PoolSetup.lua`, `core/LauncherSetup.lua`, `settings/Slash.lua`,
`settings/OptionsSetup.lua`); Widgets has no seam file and
is resolved at each of its two call sites — `modules/Export_Modal.lua`, which builds the addon's only
dropdowns, and `settings/ColumnBlocks.lua`, whose block list is the library's `ReorderList` — because
both widgets are built lazily on first use rather than wired at load. Every one of the twelve degrades
rather than erroring when `libs/LibKa0s` is absent (Sim to its reference stubs, which say so only when
`/mm sim` is typed). Three of them pass the addon's own **folder name** to the library, and all three now say so
explicitly: `core/CoreSetup.lua`'s `MakeCloseButton` wrapper, and the descriptors in
`core/DebugLogSetup.lua` and `core/PerfSetup.lua`. The perf one used to reach the right answer only
through `name` — `PerfPanel.lua` minor 4 reads `addonName or name`, so it was right by luck and one
rename away from wrong — and it now states `addonName` beside `name`, the same shape the console's
descriptor has. This is why that file passes **no** `decorate` hook:
the one it used to carry drew a close button with the name dropped, so the panel wore a
multiplication sign beside a console wearing the mark. The name matters because a texture path is
absolute from `Interface\AddOns\`
and a vendored library cannot know which folder it was copied into — that is what lets the library's
own windows wear the same close, copy and clear marks the meter window's header draws. Six explain the
absence through the one shared cause clause `NS.LIBKA0S_MISSING`; **Media is deliberately silent**,
because what it degrades is chrome. The icons this window draws and its monospace face ship inside the
LibKa0s payload (`LibKa0s-Media-1.0`), so a missing library takes the art with it — the header walks
down its own atlas-then-ASCII ladder, the numbers fall back to the client font, and neither wants a
line of chat about it.

## Game-event edges are load-bearing

Which events reach which handler, and what each becomes on the bus, is tabulated in
`docs/ARCHITECTURE.md` → [Event subscriptions](ARCHITECTURE.md#event-subscriptions). What that
table does not say is why an edge cannot simply be dropped:

**These edges are load-bearing, not an optimization.** There is no fallback poll: `onUpdate` in
`modules/Window_Render.lua` refreshes *data* and never re-asks `NS.ShouldShow`, so the show ladder is
re-run only from a bus message a window subscribes to (`ROSTER_CHANGED`, `ZONE_CHANGED`,
`ENTERING_WORLD`, `COMBAT_CHANGED`, `PLAYER_STATE_CHANGED`, `TEST_MODE_CHANGED`, `CONFIG_CHANGED`).
A visibility input with no edge on the bus is a rule that never fires — which is exactly what
happened to `hideInVehicle`, shipped in 0.1.0 with no vehicle event registered, and to the first cut
of the player-state rules, which reached `Visibility` but not the window.
