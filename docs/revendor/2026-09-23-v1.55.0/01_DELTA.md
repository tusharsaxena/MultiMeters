# 01 — Delta: LibKa0s v1.54.2 → v1.55.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/`. The tag resolves to
`bb161b7` (`git -C ../LibKa0s rev-parse v1.55.0`); it is the newest tag
(`git -C ../LibKa0s tag --sort=-v:refname | head -1`). This addon's `tests/test_vendor_sync.lua`
resolves the tag its provenance line names and compares both payloads against it file by file, so
the copy, the provenance line and the kit wiring land in one commit.

This bundle covers Steps 2-4 of the re-vendor (tag, delta, copy). Candidate selection and adoption
of the three new majors are a separate pass and are not recorded here.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
```

> 53: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) **v1.54.2** (MIT).

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/<file>
```

Every vendored minor equals v1.54.2's, and `diff -r <v1.54.2 archive>/LibKa0s libs/LibKa0s` and
`diff -r <v1.54.2 archive>/testkit tests/_kit` are both **empty, bytes included**. The line and the
bytes agree; nothing was rolled without its payload, in either direction.

## 3c — Per-file minor delta

Read from the tag's `LibKa0s/LibKa0s.xml`, in its load order.

| File | Constant | v1.54.2 (vendored) | v1.55.0 |
|---|---|---|---|
| `Core.lua` | `MINOR` | 7 | 7 |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Compat.lua` | `MINOR` | absent | **1 (new major `LibKa0s-Compat-1.0`)** |
| `Lifecycle.lua` | `MINOR` | 1 | 1 |
| `Bus.lua` | `MINOR` | absent | **1 (new major `LibKa0s-Bus-1.0`)** |
| `Schema.lua` | `MINOR` | absent | **1 (new major `LibKa0s-Schema-1.0`)** |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 1 | 1 |
| `Media.lua` | `MINOR` | 3 | 3 |
| `Widgets.lua` | `MINOR` | 9 | 9 |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 2 | 2 |
| `DebugLog.lua` | `MINOR` | 12 | 12 |
| `Slash.lua` | `MINOR` | 14 | 14 |
| `Launcher.lua` | `MINOR` | 1 | 1 |
| `Options.lua` | `MINOR` | 23 | 23 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 30 | 30 |
| `OptionsTabs.lua` | `TABS_MINOR` | 3 | 3 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 7 | 7 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | 3 |
| `Perf.lua` | `MINOR` | 12 | 12 |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

**No cross-major skew.** No existing file's minor moved. Three files are new, each a new major that
floors on Core and returns before `NewLibrary` without it.

## 3d — Both diffs, both directions (before the copy)

```
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s
diff -rq                     <tag>/LibKa0s libs/LibKa0s
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit
diff -rq                     <tag>/testkit tests/_kit
```

- `LibKa0s/`: `Only in <tag>`: `Bus.lua`, `Compat.lua`, `Schema.lua`; `LibKa0s.xml` differs (three
  new `<Script>` rows). Content and bytes give the **same** answer, so there is no line-ending
  drift to renormalize.
- `testkit/`: `Only in <tag>`: `test_layout_cap.lua`; `README.md`, `framework.lua`,
  `run-automated-tests.sh`, `test_eol.lua`, `test_prose.lua` differ. Content and bytes agree.
- No `Only in libs/LibKa0s` or `Only in tests/_kit` line: **nothing to delete** inside either payload.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

| Major | Lookup sites |
|---|---|
| Core | `core/CoreSetup.lua:88` |
| Lifecycle | `core/LifecycleSetup.lua:37` |
| Launcher | `core/LauncherSetup.lua:79` |
| DebugLog | `core/DebugLogSetup.lua:227` |
| Env | `core/EnvSetup.lua:71` |
| Pool | `core/PoolSetup.lua:35` |
| Perf | `core/PerfSetup.lua:42` |
| Media | `core/MediaSetup.lua:72` |
| Widgets | `modules/Export_Modal.lua:39`, `settings/ColumnBlocks.lua:78` |
| Slash | `settings/Slash.lua:169` |
| Options | `settings/OptionsSetup.lua:153`, `settings/Schema_Compose.lua:463` |

**Unconsumed:** `Item` (reached only by the library itself), and the three new majors `Compat`,
`Bus`, `Schema`. Those three are the whole-module candidates for the adoption pass (class C); this
run adopts nothing.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
```

`tests/_kit/framework.lua:20: Kit.VERSION = 24` → `<tag>/testkit/framework.lua:20: Kit.VERSION = 25`.

The pairing rule (a consumer on LibKa0s v1.9.0 or newer takes kit revision 11 or newer in the same
commit) is satisfied by construction: both payloads are copied whole from one tag, in one commit.

Revision 25 changes what the runner owes: a kit suite is declared by the **pair** (basename,
directory), `test_layout_cap.lua` arrives and must be declared, and a repo that wrote its own
`tests/test_layout_cap.lua` retires it (`LibKa0s/docs/api/testkit/version-25-docs.md`, section
`Adoption`). This repository wrote its own, so the vendor commit deletes it and wires the kit's.

## 3g — Contract delta

**Majors whose minor moved ∩ majors this addon consumes = none.** No existing file's minor moved
(3c), so no consumed surface can have moved its call site.

The API documents were still read, not inferred:

```
git -C ../LibKa0s diff --stat v1.54.2 v1.55.0 -- docs/api
```

Ten files. Six are the three new majors' documents and manifests, one is the kit's new
revision-25 document, one is the index `docs/api/README.md`. The remaining two are under a consumed
major, `Widgets`: `version-9.1-docs.md` and `version-9.2-docs.md`. Their diff is a header repair
(9.1's `Status` becomes `Superseded`, `Superseded by` names 9.2; 9.2 gains its own header table,
which had been pasted from 9.1) plus a `Moving to version 9.2` note restating 9.2's hover-tint change
that already shipped in v1.48.1. No sentence under an existing surface changed meaning and no MUST
appeared.

`__Attach*` sites this addon calls: `settings/Schema_Compose.lua:479`, `optlib.__AttachCompose(C, …)`.
`OptionsCompose.lua` is unchanged (`COMPOSE_MINOR` 7 → 7), so every member supplied there keeps its
contract.

### Blockers

**None.**

## What the copy owes

- Whole-folder copy of both payloads from the tag.
- `CLAUDE.md` provenance line `v1.54.2` → `v1.55.0`, same commit. `README.md` carries no provenance
  line (`grep -n 'Bundles' README.md` is empty), so nothing to remove there.
- `tests/run.lua`: delete the bare `"test_layout_cap"` and `tests/test_layout_cap.lua`, declare
  `{ name = "test_layout_cap", dir = "tests/_kit/" }`. `Kit.layoutCap` needs no field: the hub is
  the default `docs/ARCHITECTURE.md` and the repo tracks no generated data.
- `docs/ARCHITECTURE.md` → `### Files over the 1500-line cap`: the census already stands under
  `## Documented deviations` at level 3 and states a result; its prose names the local gate being
  retired, so that reference moves to the kit's gate.
