# Slash dispatch

> Ka0s Multi Meters. Part of the doc set mapped in
> [ARCHITECTURE.md](ARCHITECTURE.md#documentation-map). The hub's summary is
> [Slash commands](ARCHITECTURE.md#slash-commands).

A `documentation-§3` Tier 2 doc: this addon has eight or more commands and a sub-command tree
(`window`), so the command surface lives here rather than in the hub. It moved here whole from the
hub's `## Slash commands` section; the sub-tree, the disabled gate's live list, the degraded
behavior and the refusal lines were added beside it.

## The dispatch table

`/mm` and `/multimeters` are aliases, registered through AceConsole (never a raw `SLASH_*` global).
A bare `/mm` (empty, or whitespace only) runs the `config` verb with `""` and opens the settings
panel on its landing page; `/mm help` prints the index (`slash-commands-§4`, LibKa0s-Slash minor 11).
The library-absent stub in `settings/Slash.lua` mirrors the rule, so there `config` answers that the
panel is unavailable.
`NS.COMMANDS` in `settings/Slash.lua` is the sender-authoritative dispatch table: **18 verbs**, the
twelve reserved ones first in the order the standard fixes, then this addon's six. The dispatcher, the
help renderer and the schema CLI are LibKa0s-Slash-1.0's; the verb table stays this addon's and is
passed *in*, because the settings landing page renders the same rows and library ownership would make
that a load-time cycle between two majors.

| Command | What it does |
|---|---|
| `help` | Show the command index |
| `config` | Open the settings panel on its landing page (`options` is accepted as an alias). A bare `/mm` runs this verb |
| `enable` / `disable` | Turn the addon on or off. **Aliases, never a second switch** (`slash-commands-§2`): both write `enabled` — the path General → Master controls' **Enable Multi Meters** box writes — through `NS.SetByPath`, the same single write seam, so they hold no state of their own and one `onChange` runs whichever surface was used. `/mm set enabled true` is the same write by its long name, and the acknowledgment is `slash-commands-§5`'s `path = value` line, re-read after the write. **The dispatcher survives the disabled state**: nothing unregisters the chat command, tears down `NS.COMMANDS` or drops the dispatcher, so every reserved verb — and the bare `/mm`, which opens the panel — still works with the addon off, and the pair is never one-way. `disable` **stands the addon down** rather than hiding its windows; what that means, and what the six feature verbs answer instead, is [disabled-state.md](disabled-state.md). **On a library-absent or partial load they keep working, by `options-ui-§1` route (a)**: the `enabled` row is composed by LibKa0s-Options-1.0's MasterControls, so with that major missing there is no row for `CliSet` to parse against (and with the Slash major missing `CliSet` is the stub's). The pair then calls `NS.SetByPath("enabled", want)` directly; the Schema seam, live or stub, stores the path through its `writeThrough` list and pulls the latch in its `announce` ([schema.md](schema.md#the-degradation-stub)). The reply is `enabled = <value>`, or the seam's refusal |
| `list` | List every setting and its current value |
| `get <path>` | Read one setting |
| `set <path> <value>` | Write one setting |
| `reset <path>` | Reset one setting to its default |
| `resetall` | Reset the active profile to the shipped defaults, **after a confirmation**. It opens the General page's "Reset all settings?" popup (`MULTIMETERS_RESET_ALL`, through `NS.ShowResetAll`, the opener the button calls), and only accepting resets; No or Escape changes nothing. The reset is a **profile reset**, so it is the equivalent of a new profile: extra windows are deleted and one fresh window is left. The same act as Profiles → Reset Profile; other profiles are never touched. Until 2026-09-12 it went to the library's `CliResetAll`, which reset only the active window's rows, and then, until the owner's decision the same day, it reset without asking. See [settings-panel.md](settings-panel.md#reset-all-settings-vs-reset-profile) |
| `debug` | Toggle the console window; `on` / `off` set session logging; **`tooltip`** toggles the tooltip log channel, off by default because a tooltip is rebuilt on every mouse-over and would evict the buffer; **`diag`** prints the diagnostic report; **`recap`** prints the death-recap probe alone; **`identity`** prints the mid-pull identity-correlation capture (issue #22); **`feign on`** / **`feign off`** arm and disarm the feign-death recording and **`feign`** prints it (issue #25) |
| `perf` | Performance capture — `/mm perf help` for the run's own verbs |
| `version` | Print the addon version, read from the TOC manifest |
| `lock` | Lock or unlock every window for dragging. It governs movement and nothing else: unlocking no longer switches Test mode on. General → Master controls' **Lock frame** box is the same switch |
| `test` | Toggle test mode — placeholder rows, for positioning. The General page's Test mode box is the same switch. Combat starting ends it, and a start during combat is refused |
| `toggle` | Show or hide one window by name, or all of them |
| `window` | `list` · `new <name>` · `delete <name>` · `copy <source> <target>` |
| `reset-positions` | Move every window back to the center of the screen |
| `export` | Open the export modal for one window's segment: `/mm export [window]` |

## The host verbs

The six host verbs act on **windows** — instances the registry owns — rather than on schema rows, so
they are untouched by the library's absence and route straight into `modules/WindowManager.lua`
rather than duplicating its rules. Window keys accept either an id or a name: a number is an id, a
string is a name, matched case-insensitively but stored exactly as typed.

`export` is the one of the six that ends somewhere other than the registry: it resolves a window the
same way `/mm toggle` does, then hands the **config** — not the live instance — to `NS.Export:Open`. A window in the registry that has never been built still points at a segment, and
its numbers are as exportable as a drawn one's. Named with no argument it means the window the
settings panel is pointed at, falling back to the first in the registry, because the CLI has no
picker and `/mm export` on a fresh login has to mean something. Whether an export may run at all is
asked once, of `NS.Export.Available()`, and is never re-decided here — see [Taint notes](ARCHITECTURE.md#taint-notes).

### The `window` sub-tree

`/mm window` dispatches through `WINDOW_VERBS`, a table built once at file scope in
`settings/Slash.lua` rather than an `if verb == … elseif` ladder, so which sub-verbs exist is answered
by reading the table. Each handler takes the registry and the rest of the line and answers
`modules/WindowManager.lua`'s own `ok, err` pair, so `doWindow` has one place that prints a failure.

| Sub-verb | What it does |
|---|---|
| `list` | Print the registry's own listing (`WindowManager:BuildListLines`). A bare `/mm window` is `list` |
| `new <name>` | `WindowManager:Create` |
| `delete <name>` | `WindowManager:Delete` |
| `copy <source> <target>` | `WindowManager:CopyFrom`. The source is the first word and the target is the rest, so a target name with spaces can be typed; a source with spaces is copied from the settings panel instead |

A sub-verb the table does not know prints the usage line, and so does a registry too old to carry the
member a sub-verb needs, or a `copy` with only one name.

### The `debug` words

`debug` takes seven words: `on`, `off`, `tooltip`, `diag`, `recap`, `identity` and `feign`, which takes
`on` / `off` of its own. `tooltip` is a pure toggle of a session flag on `NS.State` and always prints
the state it landed in. The three reports and `feign` answer without the console seam; any word the
ladder does not know toggles the console, exactly as a bare `/mm debug` does, and only `feign`
refuses an argument, because only `feign` reads one. What each one prints is in
[debug.md](debug.md).

## Disabled — total, and the slash surface is not

`slash-commands-§7`. **Disabled means the addon is not running.** Every game event unregistered,
every module and bus subscription dropped, every timer canceled, every window hidden at the source,
nothing written from a game event. It is one `LibKa0s-Lifecycle-1.0` latch with two named holds —
`disabled` from the stored `enabled` path, `perf` from the capture harness — and releasing one never
stands up an addon the other still holds down. It replaced a draw gate.

**The command surface is deliberately unchanged.** All twelve reserved verbs answer, and the bare
`/mm` opens the settings panel; only this addon's own six feature verbs refuse, on one line naming
`/mm enable`. Full detail, the teardown table and the launcher's options menu while disabled:
[disabled-state.md](disabled-state.md).

**The gate is the library's, and the live set is its data** (LibKa0s-Slash minor 13). The host passes
two descriptor fields. `isEnabled` asks `NS.IsDisabled` at dispatch time and never caches it, so the
command after `/mm enable` works. The live set is the library's `LIVE_VERBS`, the standard's thirteen
reserved verbs, and this host passes no `liveVerbs` to narrow it. `diagnostics` is in that set
but not yet in `NS.COMMANDS`, so for now it answers `unknown command` and the index.

- **Still answers while disabled:** `help`, `config`, `version`, `enable`, `disable`, `debug`, `perf`,
  `get`, `set`, `list`, `reset`, `resetall`, and the bare `/mm`.
- **Refused while disabled:** `lock`, `test`, `toggle`, `window`, `reset-positions`, `export`.

It asks `NS.IsDisabled`, not `NS.IsStoodDown`. A perf-suspended addon is stood down but not disabled,
and a line telling someone mid-capture to type `/mm enable` would be the wrong advice.

## Degraded behavior

`/mm` is registered unconditionally, so something always answers it. Without `LibKa0s-Slash-1.0`
`settings/Slash.lua` builds a stub, and what a player sees is this:

- **The host verbs keep working.** They never went to the library.
- **The schema CLI names the missing library.** `list`, `get`, `set`, `reset` and `resetall`'s CLI
  path each answer `/mm <verb> is unavailable. <cause>.`, where the cause is `NS.LIBKA0S_MISSING`
  (`core/CoreSetup.lua`). They never go quiet.
- **`help` renders plainly.** The stub carries no copy of the library's row formatter.
- **A bare `/mm` still runs `config`,** which then answers that the panel is unavailable.
- **`enable` / `disable` keep working.** They write `NS.SetByPath("enabled", want)` directly (see the
  table above).
- **The refusal line keeps the collection's wording.** The stub carries a byte copy of
  `DISABLED_LINE_FORMAT`, which `tests/test_degraded.lua` pins against the library.

## Refusal lines

Every refusal is one line in chat and changes nothing.

| When | The line |
|---|---|
| A feature verb while the addon is disabled | `Ka0s Multi Meters is disabled — enable it with /mm enable` (the library's `cli:DisabledLine()`) |
| An unknown verb, enabled or disabled | `unknown command '<verb>'`, then the index. A typo is not refused, so the disabled line never answers one |
| A schema-CLI verb on a library-absent load | `/mm <verb> is unavailable. <cause>.` |
| `/mm set` or `/mm enable` rejected by the seam | `Invalid value for <path>`, then the seam's reason (Slash minor 15); on the direct `enabled` path, the seam's reason alone |
| `/mm window` with an unknown sub-verb or a malformed `copy` | `Usage: /mm window list, new <name>, delete <name>, copy <source> <target>` |
| A host verb with the window layer not loaded | `window management is unavailable — modules/WindowManager.lua did not load.` |
| `/mm export` while an export may not run | the reason `NS.Export.Available()` gives, or `export is not available right now.` |
| `/mm export <name>` naming no window | `No window named '<name>'.` |
| `/mm debug feign <word>` with an unknown word | `unknown feign argument '<word>' — /mm debug feign on\|off, or /mm debug feign to print the recording.` |
| `/mm test` during combat | `modules/WindowManager.lua`'s own line; nothing more is printed here |

Every line goes through `NS.L`.

## Related

- [disabled-state.md](disabled-state.md) — the teardown the disabled gate sits on
- [debug.md](debug.md) — the `debug` words in full
- [settings-panel.md](settings-panel.md#reset-all-settings-vs-reset-profile) — what `/mm resetall`
  resets
- [schema.md](schema.md#the-degradation-stub) — the Schema seam the `enable` / `disable` pair falls
  back to
