# The disabled state

> Ka0s Multi Meters. Part of the doc set mapped in
> [ARCHITECTURE.md](ARCHITECTURE.md#documentation-map). The hub's summary is
> [Disabled — total, and the slash surface is not](ARCHITECTURE.md#disabled--total-and-the-slash-surface-is-not);
> the slash gate itself is in [slash-dispatch.md](slash-dispatch.md#disabled--total-and-the-slash-surface-is-not).

## The disabled state is total

`slash-commands-§7`. **Disabled means the addon is not running.** Not hidden, not quiet, not
skipping a repaint — not running. Unticking *Enable Multi Meters* gets the same outcome as unticking
the addon in Blizzard's own AddOns list, minus the `/reload`.

**This replaced a draw gate.** Through v1.0.0 the stored `enabled` key was one rung of
`NS.ShouldShow`'s ladder: the windows went away and all twenty-one game-event registrations, every
module's bus subscription and every window's OnUpdate stayed exactly where they were. The client went
on walking this addon's registration list on every `UNIT_SPELLCAST_SUCCEEDED` in a raid for an addon
the player had switched off — it had not stopped watching, it had stopped reacting (anti-pattern
\#85).

**One latch, two named holds.** `core/LifecycleSetup.lua` owns one `LibKa0s-Lifecycle-1.0` instance.
`disabled` is taken from the stored `enabled` path and is persisted; `perf` is taken by
`LibKa0s-Perf-1.0` for a capture's second arm and is session-only. The addon is stood down whenever
at least one hold is taken and stood up only when the last is released — so releasing `perf` on a run
that finished after the player disabled the addon mid-capture does **not** bring it back. There is no
`StandUp()` to call: the only route out is releasing the hold that put it down.

**It is not a second teardown path.** The perf arm's `suspend` / `resume` are gone from
`core/PerfSetup.lua`; their bodies ARE the latch's `standDown` / `standUp`, which the disable arm
reaches too. Two mechanisms that both mean *be inert* drift on the first module added after the
second was written.

| On the way down (`standDown`) | What it reaches |
|---|---|
| `NS:UnregisterAllEvents()` | all twenty-one game events — `core/MultiMeters.lua` is the only file that owns one |
| `NS:CancelAllTimers()` + `NS.ResetStatePending()` | the player-state settle pass, and the flag that would otherwise never re-book one |
| every AceAddon child's `UnregisterAllMessages()` | each module is its own AceEvent target, so the addon object's own call reaches none of them |
| `NS.BusStandDown()` | every event and message registration on every bus target `NS.NewBusTarget` has made — windows, `Format`, `Targets`, the export modal, the Profiles page — through `LibKa0s-Bus-1.0`'s record, which keeps what it took down |
| `WindowManager:Suspend()` | every window's OnUpdate, then one visibility pass so what is on screen acts on the decision now |
| `Provider:Suspend()` | stops the addon ASKING the meter for anything |
| `Export.CancelSend()` | a staggered chat dump already queued — `C_Timer.After` has no handle, so the generation is bumped instead |

Hiding is enforced **at the source**: `NS.ShouldShow` reads the latch as step 0, above everything,
so nothing — a combat transition, a target swap, a settings write — can re-show a window behind the
switch's back. A frame hidden imperatively comes back. `standUp` rebuilds from **current state**,
never from a snapshot: a window created or a column toggled while the addon was off comes back as it
is now.

The paths that show a window **without** asking the ladder ask the latch themselves, through
`NS.IsStoodDown()`, which covers the `disabled` and `perf` holds both. `WindowProto:Show` (the
manual Test mode turn-off and `/mm toggle`) returns `false` and shows nothing while stood down.
`WindowManager:Toggle` refuses first, with *Windows are suspended while a performance capture
runs.*; the disabled case never reaches it, because the slash gate refuses before it does, so that
line only answers the perf hold. `Window.New` arms no OnUpdate while stood down, and
`WindowManager:Resume` arms every instance at stand-up, including one created while the addon was
off.

`standUp` brings the bus up **first**, before `NS:OnEnable`, and the order matters. While the bus is
down, `LibKa0s-Bus-1.0` records a registration on a bus target without making it, so a disabled
addon registers nothing even when a receiver subscribes. `NS.BusStandUp()` then replays the record
as it stands. Any later step registers straight onto a live bus and publishes to receivers that are
already listening. On an install with no LibKa0s, the stub hands out untracked targets, so this one
row does nothing there ([Known limitations](./ARCHITECTURE.md#known-limitations)).

**What survives, because it is SETUP and not a feature:** the chat command registration, the
dispatcher and `NS.COMMANDS`; the settings-category registration and the panel body; the AceDB
handle, the single write seam and AceDB's `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset`
callbacks — a profile switch can flip `enabled` with nothing else touched, so `core/Database.lua`
re-evaluates the latch on all three; and the launcher's registration.

**No secure or attribute work is pended,** because this addon does none — no state driver, no
attribute driver, no secure-attribute rewrite. `slash-commands-§7` permits a disabled addon to keep
`PLAYER_REGEN_ENABLED` registered for exactly that pending completion; this addon has nothing to
complete, so it keeps **nothing** and the registration set goes to empty.

`tests/test_disabled.lua` is the conformance suite, and every assertion in it is on the registration
set, the timer set, the shown set, the SavedVariables writes and the printed lines — never on a
handler's return value, because an early return is what a draw gate does.

## The slash surface while disabled — unchanged

`slash-commands-§7`'s own ruling, and it is the half that does **not** change. **Every reserved verb
answers normally** with the addon off: `help`, `config`, `version`, `enable`, `disable`, `debug`,
`perf`, `get`, `set`, `list`, `reset`, `resetall` — and the bare `/mm` opens the settings panel,
which is the case that settled it. A player must be able to read and repair settings and reach the
panel with the addon off, which is exactly when they are most likely to need to, and `enable` above
all or the pair is one-way.

**Only this addon's own six feature verbs refuse** — `lock`, `test`, `toggle`, `window`,
`reset-positions`, `export` — on exactly one line, in the collection's one wording, naming
`/mm enable`. That is `slash-commands-§2`'s SHOULD and this addon takes it. `lock` is on that list
under `slash-commands-§8`'s own ruling (unlocking a frame that is not drawn is not a coherent
request), which says nothing about what `lock` *means* here — that is this addon's ratified deviation
and is untouched.

**The gate is the library's, not this file's.** `settings/Slash.lua` passes `isEnabled` and
`brandName` on the descriptor and **deliberately passes no `liveVerbs`**: the library's default is
the standard's twelve reserved verbs, and naming a set here could only narrow it. The hand-rolled
`ALWAYS_LIVE` wrap this addon carried, and its own spelling of the refusal line, are both gone — the
line is `cli:DisabledLine()`, built from the format string every addon in the collection shares.
`isEnabled` is asked at dispatch time and never cached, so the command after `/mm enable` works.

**The launcher.** The button stays on the minimap and the broker row stays in the display —
`minimap.hide` is a per-installation display preference and says nothing about whether the addon is
running. Since LibKa0s-Launcher minor 4 (`launcher-§2`, standard v2.67.0) its buttons need no
refusal of their own. **Left-click opens the settings panel, in either state**: the panel is setup,
and it is where a disabled addon is turned back on. **Right-click opens the options menu**, and
while the addon is disabled the library grays *Locked*, *Test mode* and *Show window* with *(enable
the addon first)*; a grayed entry calls nothing and writes nothing. *Enabled* stays live, and it
runs `/mm enable`, so the menu can turn the addon back on. **The hover still answers**: the library's
status tooltip reads *Enabled: No* and the same two fixed hints.

The menu's `isEnabled` asks `NS.IsDisabled()`, **not** `NS.IsStoodDown()`: the *Enabled* box is the
`enabled` setting, the store its toggle writes, and a perf capture must not untick it. During a
capture's suspended arm the three feature entries stay live and each verb answers the hold in its own
words — *Show window* runs `/mm toggle`, which prints *Windows are suspended while a performance
capture runs.* and shows nothing. Through Launcher minor 3 the left click was refused by the library
while stood down, reading `disabledLine` (`NS.Slash:DisabledLine()`); minor 4 retired that refusal,
and the descriptor no longer passes `disabledLine`.

