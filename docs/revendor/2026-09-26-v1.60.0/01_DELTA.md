Delta: LibKa0s v1.58.0 -> v1.60.0

# 01 — Delta

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.60.0 LibKa0s testkit | tar -x -C <scratch>/`. The tag points at commit
`bed0eb1` (`git -C ../LibKa0s rev-parse v1.60.0^{commit}`) and is the newest tag. v1.59.0 (the
WidgetsDragHandle close mark) is crossed on the way, so this bundle covers both releases.

This re-vendor is item **DR-MM-01** of the cross-repo diagnostics rollout
(`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND/`). That plan has already decided every
candidate, so `03_DECISIONS.md` records the plan's answers rather than an interview, and no decline
issue is filed (the plan says so explicitly).

## Base check

```
c=$(git log -1 --format=%h -- libs/LibKa0s tests/_kit)   # 3500c15, "M6-MM: Re-vendor LibKa0s v1.58.0 ..."
git show $c:CLAUDE.md | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'   # v1.58.0
git -C ../LibKa0s archive v1.58.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit   # clean
```

The vendored bytes are exactly v1.58.0. **ok.**

## 3a — Claimed version

```
grep -n '[Bb]undles' CLAUDE.md README.md
```

> CLAUDE.md:54: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.58.0 (MIT).

No README line. Claim and bytes agree (above).

## 3b / 3c — Per-file minors, v1.58.0 -> v1.60.0

```
grep -hoE 'local (MAJOR, )?([A-Z_]*MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua | sort
grep -hoE 'local (MAJOR, )?([A-Z_]*MINOR) *= *("[^"]+", *)?[0-9]+' <scratch>/LibKa0s/*.lua | sort
grep -o 'file="[^"]*"' <scratch>/LibKa0s/LibKa0s.xml
```

The tag's `LibKa0s.xml` lists 22 files (one more than v1.58.0: `DebugLogDiagnostics.lua`).

| File | Constant | v1.58.0 | v1.60.0 |
|---|---|---|---|
| `DebugLog.lua` | `MINOR` | 13 | **14** |
| `DebugLogDiagnostics.lua` | `DIAG_MINOR` | — | **1** (new) |
| `Slash.lua` | `MINOR` | 15 | **16** |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 2 | **3** (v1.59.0) |
| every other file | — | unchanged | unchanged |

No cross-major skew: the consumer is behind on no file after the copy.

## 3d — Both diffs, before the copy

```
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s
diff -rq                     <scratch>/LibKa0s libs/LibKa0s
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit
diff -rq                     <scratch>/testkit tests/_kit
```

Content and bytes agree (no line-ending drift). Differences: `DebugLog.lua`, `LibKa0s.xml`,
`Slash.lua`, `WidgetsDragHandle.lua` differ; `DebugLogDiagnostics.lua` only in the tag; kit
`README.md`, `framework.lua` differ; `test_diagnostics_contract.lua` only in the tag. **No
`Only in libs/LibKa0s` or `Only in tests/_kit` line**, so nothing is deleted.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

DebugLog is looked up at `core/DebugLogSetup.lua:227`, Slash at `settings/Slash.lua:178`, Widgets at
`modules/Export_Modal.lua:39` and `settings/ColumnBlocks.lua:78`. The addon builds no `DragHandle`
(`grep -rn DragHandle core modules settings` finds none), so WidgetsDragHandle 3 is not consumed.
Item is still unconsumed, as before.

## 3f — Kit revision

```
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua   # 27 vs 26
```

Kit 26 -> **27**: one new suite, `test_diagnostics_contract.lua`, and its `KIT_GATE_RULE` row. Both
payloads move in one commit (the pairing rule; satisfied by construction).

## 3g — Contract delta

Majors that moved and are consumed: DebugLog, Slash (Widgets moved only in `WidgetsDragHandle.lua`,
which this addon does not use).

```
diff <(git -C ../LibKa0s show v1.58.0:docs/api/DebugLog/version-13-docs.md) \
     <(git -C ../LibKa0s show v1.60.0:docs/api/DebugLog/version-14.1-docs.md)
diff <(git -C ../LibKa0s show v1.58.0:docs/api/Slash/version-15-docs.md) \
     <(git -C ../LibKa0s show v1.60.0:docs/api/Slash/version-16-docs.md)
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit
```

- **DebugLog `MAX_BUFFER` 1500 -> 3000, slack 64 -> 128** (`version-14.1-docs.md:50-51`). A value
  change on an unchanged surface. `grep -rn 'MAX_BUFFER\|BUFFER_SLACK' --include='*.lua' .` outside
  `libs/` and `tests/_kit/` finds nothing, so no host test pins the literal. Not a blocker.
- **DebugLog instance surface gains `RunDiagnostics`, `BuildDiagnostics`, `DebugVerb`**
  (`version-14.1-docs.md:525-526`, `:615-619`). The library-absent stub in
  `core/DebugLogSetup.lua` must carry the same members for the surface-parity suite, and its
  `RunDiagnostics` prints `"%s is unavailable: the LibKa0s library did not load."` with
  `/mm diagnostics` and returns 0. This is a **blocker** in the skill's sense (the parity suite is
  red without it), fixed in the re-vendor commit.
- **Slash `LIVE_VERBS` gains `diagnostics`** (`version-16-docs.md`, the `lib.LIVE_VERBS` row; was
  twelve verbs at `version-15-docs.md`). MultiMeters passes no `liveVerbs` and takes the library
  default (`settings/Slash.lua:134`), so there is no host copy to roll. `/mm diagnostics` is not yet
  a registered verb (it arrives in DR-MM-02/03), so while disabled it now falls through the live gate
  to the ordinary unknown-verb answer. Not a blocker; the comment at `settings/Slash.lua:134`
  ("TWELVE") is rolled to thirteen in the same commit.
- `__AttachCompose` (`settings/Schema_Compose.lua:479`): OptionsCompose did not move in this range.
  Nothing to re-check.

**Blockers:** one, the DebugLog stub members above, fixed in Step 4's commit.
