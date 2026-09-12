# Testing

A headless Lua unit harness lives under `tests/` — run `lua tests/run.lua` from the repo root (it
exits non-zero on any failure); `luacheck .` must stay at 0 warnings and 0 errors. The tree is clean
on both counts today, so a new warning is a regression rather than background noise.

The suites load every source under a WoW-API mock and assert what is genuinely ours: the LibKa0s
descriptors and their degradation stubs, the GUID join in `modules/Aggregator.lua`, pet folding,
sort-mode fallback, window-relative path resolution, the visibility ladder, the meter-unavailable
path, and — the one that matters most here — that no file outside `core/Secrets.lua` ever inspects a
value that came out of `C_DamageMeter`.

The harness draws nothing and cannot model taint, so it complements rather than replaces the in-game
checks in [smoke-tests.md](smoke-tests.md).

## Local toolchain

`lua` (5.1 exactly) and `luacheck` on `PATH` are the whole toolchain — there is no build step, and
the only runner beyond `tests/run.lua` is the vendored `tests/_kit/run-automated-tests.sh`, which
shells out to the same two commands. `lizard` is a third, **optional** tool, driven by the
non-gating `complexity` suite of that runner.

What to install, in the WSL2/Ubuntu commands that actually work, is the root
[DEPENDENCIES.md](../DEPENDENCIES.md). That file says *what to install*; this one says *how to
verify*. Lua 5.1 is a hard requirement there for a reason worth repeating once: the kit's loader
sandboxes each source chunk with `setfenv`, which 5.2 removed.

## What is the harness, and what is this addon's

The registry, the assertion set, the `skip` status, the suite-inventory gate, the `--list` renderer
and the source loader all belong to the **vendored kit** — `tests/_kit/framework.lua`,
`loader.lua`, `mock_base.lua`, `vendor_sync.lua`, copied verbatim from LibKa0s's `testkit/`.

**`tests/_kit/` is never edited here.** A kit fix goes upstream to LibKa0s and is re-vendored; a
local patch is reverted silently by the next re-vendor, and in the meantime this addon is testing
something no other repo runs. `tests/test_vendor_sync.lua` is the byte-identity gate that says so
out loud.

What stays in `tests/run.lua` is only what is genuinely Ka0s Multi Meters': the two load lists, the
instance factory `loadInstance`, the lifecycle kick, and the suite list.

The kit **collects, then runs**. `test()` only records a case; nothing executes until `Kit.run`.
That is why `--list` cannot disagree with the run it enumerates — it is a pure filter over the same
registry rather than a second code path.

### Both load lists are derived, never typed

```lua
local LIB_FILES   = Loader.xmlFiles(root .. "/libs/LibKa0s/LibKa0s.xml")
local ADDON_FILES = Loader.tocFiles(root .. "/MultiMeters.toc")
```

The addon half comes straight out of `MultiMeters.toc`, in TOC order, so the runner cannot drift
from what the client loads. The library half comes out of `LibKa0s.xml`, in the XML's own order,
because the TOC pulls the whole library in through that one `.xml` and `Loader.tocFiles`
deliberately skips it.

That derivation is not fussiness. **A short library load list does not raise.** It leaves the
dependent major unregistered, the host's setup file falls back to its degradation stub, and the
suite happily measures the stub — green, and testing nothing. Five seams in this addon degrade that
way (`core/CoreSetup.lua`, `core/PerfSetup.lua`, `core/DebugLogSetup.lua`, `settings/Slash.lua`,
`settings/OptionsSetup.lua`), so `tests/run.lua` also asserts by name that
`Core.lua`, `DebugLog.lua`, `Slash.lua`, `Options.lua`, `OptionsWidgets.lua`, `OptionsCompose.lua`,
`OptionsScroll.lua`, `Perf.lua` and `PerfPanel.lua` are all present. A re-vendor that drops one
fails there, with a name. `OptionsCompose.lua` is on that list for a reason the runner argues in
place rather than leaving to the reader: `settings/Schema.lua` **composes** the master controls tab
and every font, border and bar group out of it, so a re-vendor that dropped it would take fifty-odd
schema rows with it rather than merely losing a widget.

The degraded path is exercised by a **real load**, never by hand-stubbing the member under test:

```lua
local inst = T.load{ libFiles = {} }   -- the whole addon, with LibKa0s absent
```

### The stub is checked in both directions

`tests/test_degraded.lua` asks whether the `settings/OptionsSetup.lua` stub answers the calls this
addon makes **today** — it greps `H.Foo(` out of `settings/*.lua` and checks each one resolves.
That cannot see a member the library publishes and the pages have not adopted yet, so the day a
page starts calling one, the stub is silently short and nothing goes red until a player with no
LibKa0s opens the panel.

`tests/test_surface_parity.lua` is the other direction: it compares the stub against the **live
surface**, through the kit's `T.assertSurfaceParity(stub, "LibKa0s-Options-1.0", ignore)`. A member
arrives on the list the moment the library publishes it and stays there until that file says out
loud why the stub does not carry it. `tests/run.lua` registers where the live half is looked up
(`Kit.setSurfaceSource`), because this stub mirrors the **instance** `lib:New(descriptor)` returned
and not the four-member library table LibStub answers for the same name. The other five seams are
not compared by name, and the suite's header gives the reason for each.

### One environment detail worth knowing

Nearly every client-API read in this addon is spelled `_G.C_DamageMeter`, `_G.canaccessvalue`,
`_G.UnitGUID` — explicit, because `architecture-§1` forbids the deprecated bare globals and the
`_G.` prefix is what makes a Compat-bypassing read visible in review. The kit's per-chunk
environment falls through to the process's real `_G`, which holds no client API at all, so an
unbound `_G.X` would read nil and every secret-value case would quietly measure the *absent-API
fallback* instead of the API. `tests/run.lua` closes that by publishing the kit-built environment
back as `mocks._G`, per instance.

### The suites the 2026-09-09 peel added

Seven source files and eight suites sat over `layout-§1`'s 1500-line cap on 2026-09-09. Peeling them
produced thirteen new modules, thirteen new suites, and — from `tests/wow_mock.lua`, the eighth
breaching test file — the two mock halves the next section describes.

**A suite's seam is not its own to choose; it follows the module's.** That is what keeps the
inventory navigable at this size: a reader who opens `modules/Window_Placement.lua` knows before
looking that its cases are in `tests/test_window_placement.lua`, and a reader who opens a suite
learns which module it speaks for from its first line. The rule is bent in exactly one place below,
and it is bent for the reason the peel happened at all.

`core/Diagnostics.lua` split three ways, and that split is about **lifecycle** rather than size. A
probe written for one issue is meant to be deleted with that issue, and that only works if its cases
go out with it — so `tests/test_diagnostics_deathrecap.lua` (issue #1),
`tests/test_diagnostics_identity.lua` (issue #22) and `tests/test_diagnostics_feign.lua` (issue #25)
each sit beside the probe module they cover, and `tests/test_diagnostics.lua` keeps the frame, the
entry point and the short probes. All four protect the same property, which is the one the report
exists for: it must run to completion on a hostile client, print rather than raise, and never itself
be the reason a player cannot describe what they are seeing.

`tests/test_aggregator.lua` kept the build pipeline, the GUID join, the group filter and pet folding.
`tests/test_aggregator_identity.lua` covers the **second** build — the grid drawn while `sourceGUID`
is secret, where there is no key to join on and rows are correlated by class plus spec plus "is it
me" instead. Nearly every case in it is about a **refusal**: an ambiguous key fills no cell, a
collision a later column proves blanks the cells an earlier one already wrote, a sum nobody may
compute goes quiet rather than reading zero. Correlation can be wrong in a way a join cannot, so the
refusals are the behavior worth pinning. `tests/test_aggregator_preview.lua` covers the grid with
nobody in the group, and the one thing it exists to hold is that test mode substitutes the **data**,
at `modules/Provider.lua`, and never the render path: a separate preview result table built by a
separate function is what shipped once, and the two modes then diverged at every seam nobody thought
to duplicate — the tooltip found no source, the drill-down opened on nothing, and every fix had to be
applied twice.

`modules/Window.lua` split into the band across the top and the geometry underneath.
`tests/test_window_header.lua` is the title strip, the column header buttons and the sort hand-off,
the segment picker and the minimise collapse that takes the body away and leaves the strip behind;
its sort-arrow cases exist once per rung of the three-rung ladder, so an arrow assertion that fails
on one rung may be perfectly correct on another and the first thing to read in a failure is which
rung the case forced. `tests/test_window_placement.lua` is where a window sits, how big it is, and
whether it is drawn at all. Its save cases **poison** `GetPoint`, `GetWidth` and `GetHeight` on the
value-carrying frame and then drive a save through them, so a rule-R3 read that crept back in is a
stack trace rather than something a reviewer has to notice.

`tests/test_row_namecell.lua` covers the one cell in the row that never holds a figure. Because it
holds no meter value it stays **out** of the secret set, its geometry stays readable through a
restricted pull, and that is why its icon and truncation cases can assert on widths at all; the value
cell and the shared colour, media and mouse parts stay in `tests/test_row.lua`.

`modules/Tooltip.lua` is the bent seam — two modules, three suites. `tests/test_tooltip_lines.lua`
covers one pooled line as a widget, including the minimum width, which is **computed** from character
spans rather than measured off a string because measuring a secret raises.
`tests/test_tooltip_builders.lua` covers the per-spell breakdown, the Deaths cell, and the name
tooltip that summarizes every tracked statistic for one player including the columns the window is
not showing. The death-event half was then split out again into `tests/test_tooltip_deaths.lua`,
because it is the largest single block on that side — enough on its own to put one file back over the
cap — and because it has the clearest lifecycle of anything here: it exists for issue #1 and goes out
with it.

`tests/test_export_modal.lua` is the half of the export that needs a frame: the modal, its three
selectors, the copy window and the Print to Chat click. What it guards is that the refusal is
re-checked **at the click** — a modal can sit open across the edge into a pull, so `Export.Open`
declining while the Combat restriction is active is not enough on its own. Everything that is a pure
function of its arguments stays in `tests/test_export.lua`, which is why that suite needs no frame at
all.

`tests/test_schema_paths.lua` covers the path machinery and `NS.SetByPath`, the one seam a schema-row
write belongs to, so the case that matters there is not "a path reads a value" but "the **same**
path reads a **different** window's value once the active window moves". Its instance-argument cases
pin the other half: a window id writes and reads **that** window, a stale id is refused rather than
redirected, and the picker never moves. `NS.SetByPaths` is held to all-or-nothing validation, one
`[Set]` line per row, and one `CONFIG_CHANGED` per batch. A bulk copy is the exception: one
`[Set] <act>: N rows` line, where N counts only the rows that changed. The same suite pins
`NS.Bulk`'s bracket: nesting, the changed-only count, silence after a profile reset, and a raise
that still closes the bracket. `tests/test_windowmanager.lua` and
`tests/test_window_placement.lua` prove that `Rename`, `CopyFrom`, `SetLocked` and `SaveSize` reach
the seam ([schema.md](schema.md#the-window-registry-and-its-writer)).
`settings/Schema_Compose.lua` is the one new module with no suite of its own, and deliberately: it
holds the vocabularies, validators and composers that build the row array, and
`tests/test_schema.lua` asserts them where it asserts the array they produce.

## What the mock models, and what it admits it cannot

**The mock is three files now, not one.** `tests/wow_mock.lua` layers this addon's half over the
shared base in `tests/_kit/mock_base.lua`, overwriting per key. Its own header lists what it inherits
and what it replaces, and why: the frame model (the base returns the frame itself from every widget
factory, which makes "which region got the text" unanswerable — and this addon's entire output is
text and bar values written onto per-cell FontStrings and StatusBars), and `C_AddOns`. On 2026-09-09
that file went over the 1500-line cap itself (issue #34) and the two largest things it carried moved
out along the seams its own header had already drawn: the **secret simulator** to
`tests/mock_secrets.lua`, and the **frame model** — with `GameTooltip` — to `tests/mock_frame.lua`.
What stayed is the builder, the meter and group fixtures, `C_AddOns`, the AceDB string-method
callbacks and the control surface, which still lists everything in one block including the two halves
that no longer live there.

**AceEvent and AceAddon are the kit's, whole** (kit revision 17, LibKa0s v1.31.0). The file used to
replace both: the message half, for `UnregisterAllMessages` and string-method dispatch, and AceAddon,
for `NewModule` / `GetModule`. The kit now models both from the real CallbackHandler and AceAddon-3.0,
so a suite reads the message registry as `mocks.__msgRegistry`, fires a game event with
`mocks.__fireEvent(event, ...)` (which answers how many handlers ran), and finds the modules in
AceAddon's own `NS.modules` / `NS.orderedModules`. `T.load{ enable = true }` runs the enable cascade
through `AceAddon:EnableAddon(NS)`, in the client's order: the addon's `OnEnable` first, then every
module in creation order. The local layer had enabled the modules first; nothing in the suite depended
on that.

**Neither half is a suite, and neither may be declared as one.** `tests/wow_mock.lua` `dofile`s them
and nothing else does; they appear in no `SUITES` entry, and the non-obvious part is what would
happen if one did. `Kit.assertSuiteInventory` enumerates the suite directory with one pattern —
`^test_(.+)%.lua$` — so a mock named in the list is a name it can never find on disk, and the gate
reddens with "declared in the suites list … but is not on disk" for a file that is plainly sitting
there. Renaming the mock to `test_…` to quiet that would be the worse outcome rather than the fix:
declaring a file is what makes its cases run, a mock declares no cases, and the list would then carry
an entry that runs nothing while reading exactly like one that runs something. The mocks' own headers
say this at the top, because the mistake is a one-line one.

**They are loaded once, at file scope, not per build — and a second load would break quietly.**
`tests/mock_secrets.lua` keeps its `plainOf` and `secretTables` registries file-local and weak-keyed,
so every `build()` shares them and a secret minted under one instance is still recognized as one
under the next. Two copies of that chunk would mean two registries, after which `mocks.reveal` hands
back the wrapper instead of the value the moment a fixture crosses between them. For the same reason
the frame model is **handed** the simulator rather than loading its own — `local Frame =
loadfile(root .. "/tests/mock_frame.lua")(Secrets)` — so that `SetText`, `SetValue` and
`GetStringWidth` agree with `mocks.isSimulatedSecret` about what they were given, recognition being
registry identity and nothing else.

**The secret simulator is the most valuable thing in the harness.** `mocks.secret(v)` returns a table
whose metatable raises a tagged `MOCK_SECRET_VIOLATION` from every operation tainted code may not
perform on a secret — arithmetic, comparison, `..`, indexing, field assignment. Without it a suite
that "proves" the never-inspect rule proves nothing, because a plain number satisfies every
assertion a secret would have failed. It lives in `tests/mock_secrets.lua` and is re-exported through
`mocks`, so nothing a suite writes changed when it moved.

It is equally valuable for being honest about its holes, which the file states rather than papers
over. In Lua 5.1 there is no metamethod for truth-testing, so `if secret then` passes here and
raises in the client; `__len` is defined but 5.1 never consults it for a table, so `#secret` answers
0 here; a secret used as a table **key** is an ordinary hash lookup and cannot be trapped at all;
and `type(secret)` answers `"table"` where the client answers the underlying type. Those are not
covered by the harness, and the defenses against them are structural instead: `SafeIterate` /
`SafeCount` in `core/Secrets.lua` never apply `#`, `modules/Aggregator.lua` joins on `sourceGUID`
(the one field the client never makes secret), and review is what catches a truth test. Read that
header before writing a secret-handling case, then pair the case with a smoke test — a rule the
harness cannot enforce is a rule that has to be checked in a real client.

One deliberate over-strictness: `__concat` **is** trapped, which is stricter than the live client
(where `..` on a secret yields a secret string). Every call site here that concatenates a possibly
secret value already guards it — `pcall` in `modules/Format.lua`, `NS.IsConcatSafe` in
`modules/Row_NameCell.lua` — so a trap there turns "somebody removed the guard" into a failing test.

The control surface is listed in one block at the top of `tests/wow_mock.lua`: the secret helpers,
the meter fixtures (`setSession`, `buildSession`, `setSourceDetail`, `setMeterAvailable`,
`resetMeterCalls`, `__meter`), the group fixtures, the frame registry, the TOC manifest and the
timers.

## Running it

```sh
lua tests/run.lua            # the whole suite; non-zero exit on any failure
lua tests/run.lua --list     # the inventory, printed; runs nothing, exits 0
luacheck .                   # must be 0 warnings / 0 errors
```

**Run these from the repository root.** The Lua cases do not care where you are — they root their
file reads through `T.root`, which the runner derives from `arg[0]` — but the vendored EOL gate
shells out to `git ls-files` in the *current* directory and refuses to report a pass it could not
actually take. From anywhere else it reddens with "this gate cannot run".

**There is no single-suite mode, and that is a design choice rather than a gap.** `Kit.run` asserts
the declared suite list against `tests/test_*.lua` on disk **in both directions** before it loads a
single case: a declared suite with no file is a hard error, and a suite file that is not declared is
one too. So narrowing `SUITES` in `tests/run.lua` to run one file does not work — it reddens
immediately. Run the whole thing (it is a few seconds) and filter the output instead:

```sh
lua tests/run.lua | grep -i provider     # just the cases whose names mention the provider
lua tests/run.lua | grep FAIL            # just the failures
```

A suite still being written is declared as `{ name = "test_foo", pending = "why" }` and **must** lose
that field the moment its file lands. A skip is never a pass: the runner counts skips in their own
column and prints each one with its reason.

### Bisecting across the audit-remediation branch

Seven commits on `feat/2026-09-07-audit-review-remediation` replay **red** from a clean clone. A
bisect that lands on one of them will blame the wrong change. In branch order:

| Commit | Item | On a clean clone |
| --- | --- | --- |
| `c61e25f` | M2-09 | 1495 passed, 1 failed |
| `3d704ad` | M2-10 | 1499 passed, 1 failed |
| `5883d17` | M2-11 | 1503 passed, 1 failed |
| `360e39e` | M2-12 | 1503 passed, 1 failed |
| `f932ee5` | M2-18 | 1506 passed, 1 failed |
| `ee0d1fe` | M3-C3 | 1506 passed, 1 failed |
| `ae2502a` | M3-02 | 1506 passed, 1 failed |

It is the same single case every time — *The projection's field list and collectSource cannot drift
apart*, in `tests/test_provider.lua`. The case scans `modules/Provider.lua` for `collectSource`'s
body and anchored the closing bracket on `"\nend\n"`. This repo is pinned CRLF, so on a correct
checkout every line ends `\r\n`, that anchor never matches, the body comes back `nil`, and the case
reports a drift between the projection and `SOURCE_FIELDS` that is not there.

**None of the seven introduced it.** `origin/master` at `02aff8c`, the commit this branch was cut
from, fails the same case with the same message at 1495 passed / 1 failed. The condition is
inherited, and it is invisible on a working tree that has been mis-normalised to LF — which is why
every figure published before the line-ending sweep was measured green.

`8eef4b8` (M4-10) closes it, by stripping CRLF before the match: 1507 passed, 0 failed. Every commit
from there to the tip is green. So if a bisect stops on one of the seven and the case you are
chasing is this one, `git bisect skip`. If it is not, filter the noise out with
`lua tests/run.lua | grep FAIL` and read what is left.

**The history is deliberately not being rewritten.** Rewriting seven commits mid-branch to repair a
defect they inherited would cost more than the note you are reading.

### The inventory

The **authoritative case count and per-suite breakdown** live in the generated inventory at
[test-cases.md](test-cases.md) — never a hand-typed number in this file or in the README prose.

```sh
lua tests/run.lua --list > docs/test-cases.md            # regenerate
diff <(lua tests/run.lua --list) docs/test-cases.md      # verify in sync; no output = clean
```

Whenever the suite changes — a case added, removed or renamed, or the pass count moves — regenerate
the inventory **and** update the README `Tests` badge in the *same* change, never as a deferred
follow-up.

### The 1500-line cap gate

`tests/test_layout_cap.lua` compares two things: every authored `.lua` git tracks, and the census
under *Files over the 1500-line cap* in [ARCHITECTURE.md](ARCHITECTURE.md). It reads them in both
directions, so a file that crosses the cap unremarked and a row left behind for a file that has
stopped breaching are each a red.

**Since 2026-09-09 there is no census to read, and that is the passing state.** The last of fifteen
breaches was peeled that day and the table came out of the hub with them, because `layout-§1`'s
terminal state for a repository with nothing over the cap is nothing over the cap *and* no census —
a heading standing over an empty table is the graveyard the rule warns about rather than evidence of
anything. The gate was amended in the same change to tell the two absences apart: the census reader
now reports whether it found the heading instead of failing on the spot, so a breach with no census
to name it is red (and the message says the heading has to come back with the row), while a row that
outlives its breach is red the other way. Before that it failed in **both** directions at once —
which is the shape a gate takes when it was written for a repository that had never reached the state
it was driving toward, and neither this suite nor the register gate below had ever been run in one.

`layout-§1` binds **every authored file the repository tracks**, `tests/` included; vendored code
(`libs/`, `tests/_kit/`) is the only carve-out that reaches this repo. A red is cleared by giving
the file one of the three terminal states the rule allows — peel it, open an issue naming the seam a
peel would follow, or ratify a register row with a re-check trigger — and then adding its row to the
census. It is not cleared by raising `CAP`, and it must not be cleared by dropping the suite from
`SUITES`: the inventory gate reddens on that too, which is the point of having one.

The line figures in the census are dated measurements and nothing asserts them, so an ordinary edit
to a large file does not redden this gate. Membership is the invariant, not the numbers.

### The complexity register gate

`tests/test_complexity_register.lua` is the same bargain one section over, and it reached the same
terminal state on the same day: on 2026-09-09 the last of this addon's twenty-three warned functions
came under CCN 15, and the register went out with them. The suite now **holds vacuously over an empty
table** — with no rows there is no folder tally owed, so the tally reader answers nil and each case
returns rather than demanding a sentence about a table with nothing in it — and every check below
comes back the moment a row does. It reads the table under *Complexity register* in
[ARCHITECTURE.md](ARCHITECTURE.md) and checks that the register still says something a reader can act
on: that the folder tally stated in its prose matches the rows beneath it, that every Location names
a file that exists, that no function is entered twice, and that every disposition can be followed — a peel naming an issue number, or an accept carrying the re-check
trigger that stops it being a permanent opt-out.

**It does not run `lizard`, deliberately.** `performance-§10` says a commit MUST NOT be gated on
complexity, and a suite that shelled out to the tool would be exactly that gate wearing a test's
clothes. It follows that this gate cannot see a *new* warned function — only the runner can, at a
recorded run — and it does not try to: the CCN figures and line ranges in the register are dated
measurements, exactly as the line counts in the cap census were, and pinning them would redden the
suite on every ordinary edit to a warned function.

Where the measurement lives now that the register does not: `docs/complexity.md`, the path
`performance-§10` fixes for the report — one file, overwritten in place and never dated, so that the
git history of the single path is the trend line — plus each run's
`docs/automated-tests/<stamp>/complexity.txt`. The report is where a *new* warned function shows up;
the register was only ever where a warned function's **disposition** lived.

Why that register lived in ARCHITECTURE.md rather than in `docs/automated-tests/RESULTS.md`, which is
where `automated-tests-§4` puts the watch list — the argument is kept because it is what a future
register would be rebuilt on: the runner carries a disposition forward only when
its key — function name plus file, tie-broken by CCN — is unique on both sides. Three of this
addon's rows are `]` in `core/Database.lua`, which is `lizard`'s spelling of `migrations[n] =
function`, so none of the three is unique on name plus file. The CCN breaks that tie for exactly one
of them: `migrations[4]` is 17 and carries its ruling forward like any other row. `migrations[1]`
and `migrations[12]` are both 16, so **those two** — and only those two — were unique on neither key,
and their generated cells read blank on every run that regenerates them. The register was where
their disposition existed at all, and the runner's Disposition column was transcribed from it. Those three functions still sit
in `core/Database.lua` and would key the same way, so a row that comes back for one of them belongs
in the hub for the same reason it did the first time.

### The texture-path census gate

`tests/test_texture_paths.lua` is the third register, and the same bargain a third time. It reads
every hard-coded `Interface\` path out of the `.lua` this repository authors and the table under
*Hard-coded texture paths* in [ARCHITECTURE.md](ARCHITECTURE.md), and compares them in both
directions: a new path nobody argued for is a red, and so is a row for a path that has gone.

`library-stack-§8` makes LibKa0s-Media's catalog the addon's vocabulary for marks, so a red is
cleared one of two ways — use `NS.Icon`, or add the row saying why the catalog cannot answer at that
site. Twelve rows say why today; two of them — the pair in `settings/ColumnBlocks.lua` — defer to a single
deviation-register row rather than arguing in place, and two further cases hold that pointer honest — a fourth asserting the
register row is still there, so *"register row above"* cannot quietly become a phrase, and a
fifth asserting the row's `settings/ColumnBlocks.lua:72-73` citation still names the lines the
two declarations are on.

**The quote is part of the pattern.** An occurrence counts when it opens a string, in either form
Lua has — `"Interface\\…"` or the long-bracket `[[Interface\…]]` — and not otherwise, because a
comment quoting a path is prose about a texture rather than a texture. Four such lines exist here
and the census names them. This is not a detail: the 2026-09-07 plan's own per-repo tally put this
addon at **8**, which is what matching the doubled backslash alone returns, and it missed the seven
long-bracket literals in `modules/` — including two the same plan's prose describes by name. The
scope was written down; the pattern was not.

**Its scope drops `tests/` entirely**, and that is the one place it differs from the two gates above.
`layout-§1`'s cap binds test files and this rule does not: a path in a fixture is an assertion about
a string — `tests/test_mediasetup.lua` spells the vendored icon prefix out precisely so a wrong one
is caught — and no player ever sees it drawn.

The line and pair totals in the census prose are dated measurements and nothing asserts them.
Membership of the distinct file/path pair is the invariant, because a line number moves on every
ordinary edit while the arrival of a *new* path is the only event the rule has an opinion about.

**The register row's citation is the one exception, and it earned the fifth case the hard way.**
That row is a reader's entry point into an argument about two named declarations rather than a
membership claim, so it has to carry a line number — and the commit that first wrote `:60-61`
also added the banner above the pair that pushed it to 72-73, shipping a pointer twelve lines
short of the thing it argues about. None of the four cases before it could see that: they never
look at a number. This one does, and it is scoped to the single citation that leads somewhere.


### The suppression gate

`tests/test_lintconfig.lua` is the fourth register, and it guards the thing the other three rest on:
that `luacheck .` reaching 0/0 is a statement about the code rather than about `.luacheckrc`.

It exists because this repo spent the whole 2026-09-07 remediation with
`ignore = { "212/self", "212/event", "211/addonName" }` at the top of that file. That list looks
careful — every entry names a variable, not just a code — and it was still the anti-pattern
`lint.md` describes. A top-level `211/addonName` does not mean "the bootstrap header may go unread";
it means no file in the addon may ever report an unused `addonName`, and thirty-two of them were
unread. `M4c-06` removed the three lines, watched eighty-four warnings appear, fixed the thirty-two
at source, and moved the fifty-two receivers that remained into per-file `files[...]` stanzas that
each say which calling convention forces the argument. `212/event` turned out to name a warning this
repository does not produce at all.

Four cases, and each is the same rule from a different side:

| Case | What it refuses |
| --- | --- |
| no top-level ignore | `ignore = { ... }` at the top of `.luacheckrc`, however narrowly its entries are spelled |
| no class switched off | `unused_args = false` and eight relatives — a blanket ignore spelled as a switch |
| every stanza is narrow | a `files[...]` ignore whose key is a directory and whose entry names no variable |
| no bare inline directive | `-- luacheck: ignore` with no code after it, anywhere in tracked Lua |

It reads `.luacheckrc` **as Lua**, under a sandbox that auto-creates tables the way luacheck's own
config loader does, so it inspects the table luacheck obeys rather than text a different spelling
would slip past. And like `test_docmap` and the vendored EOL gate, it **fails rather than skips**
when it cannot look: no config, an unreadable one, a chunk that will not compile, no `io.popen`, no
git. A gate that goes quiet when it is blind reports success, which is worse than not existing.

## Verifying the vendored copies

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s   # content — empty vs the CLAIMED tag
diff -r ../LibKa0s/LibKa0s libs/LibKa0s                       # bytes  — SHOULD be empty
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit      # content — empty vs the CLAIMED tag
diff -r ../LibKa0s/testkit tests/_kit                          # bytes  — SHOULD be empty
```

### When these diffs are supposed to be non-empty

They compare against the sibling checkout's **working tree** — whatever `../LibKa0s` happens to have
checked out — which is a different question from *"is the vendored payload the release this addon
claims?"*. The two questions give the same answer only while the library has tagged nothing newer
than the tag this addon has taken.

Between a library release and the re-vendor that carries it they disagree, and that disagreement is
the normal state rather than a defect. Re-vendoring to quiet it would be the actual mistake — it
would pull an untested library release for the sake of a clean diff. That was the state when this
section was written, at `../LibKa0s` **v1.27.0** against a [`CLAUDE.md`](../CLAUDE.md) naming
**v1.26.0**, with hundreds of differing lines on each payload and nothing wrong.

Measured 2026-09-12 the two agree: `CLAUDE.md` names **v1.33.0**, the sibling checkout sits on
**v1.33.0**, and all four commands above report nothing — content *and* bytes, for both payloads.
That is the other normal state, and it is worth knowing it reads identically to never having looked.

**The authoritative comparison is against the tag `CLAUDE.md` names**, and that one must be empty at
every commit:

```sh
tag=$(grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' CLAUDE.md \
        | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
rm -rf "/tmp/libka0s-$tag" && mkdir -p "/tmp/libka0s-$tag"
git -C ../LibKa0s archive "$tag" | tar -x -C "/tmp/libka0s-$tag"
diff -r --strip-trailing-cr "/tmp/libka0s-$tag/LibKa0s" libs/LibKa0s   # MUST be empty
diff -r --strip-trailing-cr "/tmp/libka0s-$tag/testkit" tests/_kit     # MUST be empty
```

`tests/test_vendor_sync.lua` asks exactly this question inside the suite — it greps the tag out of
`CLAUDE.md` and reads that blob out of git — so **a green suite has already answered it**, and the
block above is only the by-eye version for when you want to see the hunks. Which leaves the
working-tree diffs above answering a real but different question: *how far behind the library is
this addon?* That is release planning, not a gate.


Run **both** halves of each pair before every commit — they are different findings, and nothing
about "the tests are green" will tell you the copies have diverged. The library's own suite passes
against the library; this addon's passes against a stale copy that still works.

**Content differs** → a real fork in `libs/` or `tests/_kit/`, the forbidden state. Name every hunk.

**Bytes differ but content matches** → a line-ending divergence, not a fork. Both repos pin
`* text=auto eol=crlf` with LF blobs, so a working tree holding *either* ending reads clean to
`git status` and neither side's cleanliness proves anything. Establish which side drifted
(`file -b <path>`, and `git cat-file -p HEAD:<path> | file -b -` for what git stores) and
renormalize that side. **Re-vendoring will not converge it, and the fix is never an edit under
`libs/` or `tests/_kit/`** — that makes a fork nobody knows about, which the next re-vendor reverts
silently.

## Automated test records — the consolidated run

All four out-of-game suites go through one vendored runner, and every run is recorded:

```sh
tests/_kit/run-automated-tests.sh                                          # all four, writes a bundle
tests/_kit/run-automated-tests.sh --suite complexity                       # a subset
tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle   # the green gate; writes nothing
tests/_kit/run-automated-tests.sh --release 1.0.0                          # mark the bundle a release record
```

There are **two checkpoints** — the **commit** and the **release** (the tag) — and a suite's answer
differs between them, so a bare "gates? yes/no" column cannot be written honestly. Both are named:

| Suite | Command | Gates the **commit**? | Gates the **release** (tag)? |
|---|---|---|---|
| `lint` | `luacheck .` | **yes** | **yes** |
| `tests` | `lua tests/run.lua` | **yes** | **yes** |
| `perf` | `lua tests/perf.lua` | **no — recorded only** | **yes** |
| `complexity` | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | **no — recorded only** | **yes** |

**`lint` and `tests` gate the COMMIT.** Both green, every time, before anything is staged.

**`perf` and `complexity` never fail a run and never gate a commit** — they are measured, recorded
and diffed, not thresholded. A threshold that fails a run teaches everyone to reach for
`--no-verify`, after which the gate protects nothing and the habit remains. They contribute `amber`,
which is a signal rather than a stop.

**The RELEASE is gated on all four.** The tag requires all four suites at `pass` **plus zero
functions above CCN 15**, evaluated by `/wow-addon:bump-version` from the `manifest.json` the release
run writes — not by the runner, whose exit code is unchanged.

**A missing tool is a SKIP recorded with its reason, never a pass.** A green run that measured
nothing must not be mistakable for a green run that measured everything, so an absent `lizard` or
`luacheck` is written into the manifest as `skip` with the install line that fixes it. **A skip is
not a pass for the release gate either**: at the tag a `skip` is NOT EVALUATED rather than passed.
Install the tool and re-run.

Results live in [`automated-tests/`](automated-tests/) — `RESULTS.md` for the trend line, one frozen
`<YYYYMMDD-HHMMSS>/` bundle per run. See that directory's [README](automated-tests/README.md).

## The offline perf scenarios

`lua tests/perf.lua` is the fourth thing that can be run out of game, and it sits **outside the
green gate** on purpose: `lua tests/run.lua` does not invoke it and no commit depends on it. What it
asserts is the deterministic half — how many `C_DamageMeter` reads a refresh makes, how many
refreshes a burst of events produces, how many unit-API walks a roster change costs, how many bytes
a dormant perf bracket allocates. It asserts **no** wall-clock threshold, ever.

The scenarios, what they guard and how to read the output are in
[performance.md](performance.md).

## In-game checks

The harness draws nothing, cannot model taint, and — per the mock's own header — cannot trap a truth
test, a `#`, or a secret used as a table key. Everything in that gap is
[smoke-tests.md](smoke-tests.md), and the secret-value scenarios there are not optional: they are the
only place rules R1 and R3 are checked against a client that actually enforces them. Run that file
before claiming a non-trivial change works.

## Capturing a feign trace

`/mm debug feign` is the measurement [#25](https://github.com/tusharsaxena/MultiMeters/issues/25)
is being fixed against — the Deaths column filters the local player's Feign Death correctly and
counts a party member's. **The count alone cannot say why**, and the two causes that fit it need
opposite fixes, so nothing is changed until this comes back.

Unlike the other three debug verbs it is a **recording, not a read**. They ask the client a question
at the moment they are typed; a feign is over before a player finishes typing, so this one is armed
before the run:

1. `/mm debug feign on` — arms the recording and empties any previous one.
2. Run a dungeon with a **hunter other than you** in the party, and one where you also feign
   yourself if you are the hunter. Both halves matter: the working case is the control.
3. `/mm debug feign` — prints the log and the current group beside it.

It records the three boundaries a feign crosses, and whichever goes wrong first is the root cause:

| Line | Answers |
|---|---|
| `cast` | Did `UNIT_SPELLCAST_SUCCEEDED(5384)` arrive, and under which **unit token**? `kept` says whether the GUID could be keyed on. **No `cast` line for a party token, after a run in which that player demonstrably feigned, is the finding** — the addon was never told, and no downstream filtering can help |
| `prune` | What `modules/Feign.lua` read on the unit that pass (`hp`, `feigning`) and what it decided (`evicted`). A party member with `hp=0 feigning=true evicted=true` is the other cause: `hp <= 0` wins outright over `UnitIsFeignDeath`, and your own feign never trips it because `UnitHealth("player")` stays at its real figure |
| `judge` | The per-row `ShouldDropDeath` verdict `modules/Aggregator.lua` actually got. A `dropped=false` for a GUID a `cast` line named is the filter losing the thread between the two, and the `prune` lines in between say where |

The group block at the bottom prints `hp`, `dead` and `feigning` for **every** member, not just a
feigning one. That is the baseline: "party2 reads `hp=0`" is only evidence if the other four do not.

The recording is armed rather than always on because `judge` fires once per death source on every
Deaths refresh. Disarmed it costs one nil test.

Offline, `tests/test_diagnostics_feign.lua` proves the recording runs, captures all three boundaries
and survives a client missing the unit APIs — it moved there with `core/Diagnostics_Feign.lua`, so
the cases can be deleted with the issue. It cannot supply the readings — `tests/wow_mock.lua`
answers full health for any unrecorded token, which is why the party path never showed the bug.

## Capturing an identity-correlation run

`/mm debug identity` is the measurement [#22](https://github.com/tusharsaxena/MultiMeters/issues/22)
is being fixed against. Three of the five things it needs are **properties of the running client**
and cannot be answered offline at all — what the client annotates plain on a source row, how many
players share a class+spec at raid size, and whether the engine's source ordering is stable. The
harness proves the report runs and says what it found; it cannot supply the findings.

It prints four blocks:

| Block | Answers |
|---|---|
| **the rectangle** | Every row against every correlated column, each miss attributed: `filled` (the correlation worked), `collided` (it refused — two players share a key), `absent` (the column never named the key: an honest blank), `unmatched` (the column *did* name it and produced no cell — **the fault**, and the one to paste into the issue) |
| **rows per key** | How many keys are worn by one row, by two, by three. Bounds what widening the key could buy, before anything is spent finding out whether it *can* be widened |
| **collided key seats** | Where each ambiguous key's sources sat in each column. Two captures of one pull, compared, say whether a duplicate pair could be matched by position instead |
| **source fields** | What the client actually puts on a **raw** source row, sampled across up to 10 rows plus the local player's, with a state, a `rows` count and a `values` count per field. Read through `Provider.ProbeSourceFields`, which reads the raw row rather than `GetColumn`'s projection — a probe reading the projection could only ever report the fields this addon already copies, and would confirm our own opinion back to us |

The field audit has **three states**, and the middle one is the interesting one:

- `plain` / `SECRET` — present on every sampled row; whether this context may put it in a string.
- `ABSENT` — no sampled row carried it. **A defect, not a fact about the client**: a field the
  projection reads that is not on the row is silently nil everywhere downstream, in combat and out.
- `PARTIAL` — carried by *some* rows. This is the state a one-row probe had no word for, and it is
  what `specIconID` turns out to be in a raid: present on the local player's row and nobody else's.

`values` counts **distinct plain values** across the sampled rows, which is the question a candidate
field actually has to answer. A field that is plain and outside the key but carries *one* value for
the whole group is no more a join key than no field at all — the probe says `no use as a key` rather
than flagging it. It reads `-` for a secret field, because counting distinctness is a comparison and
rule R1 forbids one on a secret; **capture again after the pull** to get counts for those.

`ABSENCE_COST` in `core/Diagnostics_Identity.lua` says what each missing key field costs, and not every one
costs the same: a missing `specIconID` folds to `0` and collapses the key to class alone, while a
missing `isLocalPlayer` folds to `false`, which is the correct answer for every row but one.

**How to take one.** `/mm debug on` first — the rectangle is built only while the flag is on, because
it is 30 rows by 6 columns four times a second and nothing on the render path reads it. Then, **inside
a pull** in as large a group as you can get: `/mm debug identity`, wait ~15 seconds, and run it again.
The two captures are the ordering probe; one capture proves nothing about stability. Then **run it
once more after combat ends** — out of combat nothing is secret, so that is the only capture that can
fill in the `values` column for fields that read `SECRET` mid-pull, which is how a candidate field
gets settled either way. The console's copy button takes the whole buffer.

`no identity pass has been measured` means exactly that — the flag was off, or the grid was built by
the GUID join. It never means "measured, and clean".

**Read after the pull**, the report says so and marks the rectangle as the *last* identity pass
rather than the grid now. The field audit in that same capture is current and therefore useless for
the secrecy question: out of combat nothing is secret, so every field reads plain. The `ABSENT` lines
are the exception — a field the client does not ship is missing in both states, which is what makes a
post-combat capture worth taking as well as a mid-pull one.
