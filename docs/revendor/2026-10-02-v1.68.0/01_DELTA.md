Delta: LibKa0s v1.67.0 -> v1.68.0

# 01 — Delta (MultiMeters)

Item TP-MM-01 of the 2026-10-02 LibKa0s tooltip-place re-vendor
(`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_TOOLTIP_PLACE/`), branch `feat/2026-10-02-drag-attach`.
Copied from the **local** annotated tag `v1.68.0` (commit `cc9f5eb`) with
`git -C ../LibKa0s archive v1.68.0 LibKa0s testkit | tar -x -C <scratch>`, never a branch tip. The
library's checkout sat at the tag (`rev-parse HEAD` equals `rev-parse v1.68.0^{commit}`) and
`git -C ../LibKa0s diff --quiet v1.68.0 -- LibKa0s testkit` exited 0.

## Step 0. Pre-flight

The roster walk over `../WowAddonStandards/standards/ADDONS.md` printed `ok` for all eleven addons;
MultiMeters' newest single-tag bundle, `2026-10-02-v1.67.0`, states base v1.66.0, and the provenance
line before its re-vendor commit `eba033e` named v1.66.0. No base correction is owed.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` -> `55:Bundles [LibKa0s](...) v1.67.0 (MIT).` The last commit touching
either payload (`git log -1 -- libs/LibKa0s tests/_kit`) is `eba033e` (CA-MM-RV), and its CLAUDE.md
names v1.67.0. The two agree, and `diff -rq` of the v1.67.0 archive against both payloads printed
`payload-matches`. Base v1.67.0.

`git -C ../LibKa0s log --oneline v1.67.0..v1.68.0`: 12 commits (the census-adoption merge and its
CA-LK-04/04R/FIN-02 tail, then DA-LK-01..07R). `git -C ../LibKa0s diff --stat v1.67.0 v1.68.0 -- LibKa0s
testkit`: `LibKa0s/WidgetsDragHandle.lua | 84`, 1 file changed, 69 insertions, 15 deletions. Nothing
under `testkit/`.

## 3b/3c. Per-file minors

The 3b grep over `libs/LibKa0s/*.lua` matched 32 constants, one per file the tag's `LibKa0s.xml` lists
(32). The per-file loop over that XML reported exactly one move:

| File | Old | New |
|---|---|---|
| WidgetsDragHandle.lua | DRAG_MINOR 3 | 4 |

Every other file's constant is unchanged; no file is new (no empty `old:` column), none removed. The
Widgets member key moves 12.1.3 -> 12.1.4. No cross-major skew: the claimed tag's bytes are the
vendored bytes.

## 3d. Diffs (before the copy)

- `diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` (content) and `diff -rq` (bytes): both
  list only `WidgetsDragHandle.lua`. No `Only in` line on either side.
- `diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit` and `diff -rq`: both empty.

## 3e. Consumption

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v
/tests/` lists the addon's lookups; Widgets is looked up at `modules/Export_Modal.lua:39` and
`settings/ColumnBlocks.lua:78`. Neither builds a drag handle: `grep -rn 'DragHandle\|tooltipPlace'`
outside `libs/` and `tests/_kit/` is empty. This addon draws no drag strip, so the moved file is
loaded (it ships in `LibKa0s.xml`) and never called by host code.

## 3f. Kit revision

`Kit.VERSION = 35` in both `<scratch>/testkit/framework.lua:20` and `tests/_kit/framework.lua:20`; the kit
payload is byte-identical to v1.67.0's. Both payloads are still copied whole in one commit (the
revision-11 pairing rule holds by construction).

## 3g. Contract delta — blockers

None. Widgets moved a minor and is consumed, so both documents were read:
`diff <(git show v1.67.0:docs/api/Widgets/version-12.1.3-docs.md) <(git show
v1.68.0:docs/api/Widgets/version-12.1.4-docs.md)`. The diff adds the "What changed at 12.1.4" section
(`version-12.1.4-docs.md:18-48`), one spec row `tooltipPlace` (`:692`, **Since 4**), the
`tooltipPlace` prose (`:725` on), and restamps the consumer census from v1.66.0 to v1.67.0. No existing
row's sentence changes, and no new MUST lands on an existing surface; the document states "Without a
hook nothing changes" and "What a host must change: nothing" (`:46-48`). The one `__Attach*` site
here, `settings/Schema_Compose.lua:479` (`optlib.__AttachCompose`), belongs to Options, whose files
did not move.

## 3h. Unrecorded tags

The audit walk from the store's horizon (2026-08-25) over `libs/LibKa0s`, `tests/_kit` and the
CLAUDE.md provenance rolls, minus the tags `docs/revendor/` records, printed nothing. No span bundle.

## After the copy

`cp -r` of both payloads; then `diff -r --strip-trailing-cr` and `diff -rq` of `<scratch>/LibKa0s`
against `libs/LibKa0s` and of `<scratch>/testkit` against `tests/_kit` are all empty. Nothing was
deleted (no `Only in` line before the copy). CLAUDE.md:55's provenance line rolled v1.67.0 -> v1.68.0,
and `docs/settings-panel.md:29`'s "v1.67.0 bundled" stamp with it, in the same commit. `README.md`
carries no provenance line, so nothing was removed there.
