Delta: LibKa0s v1.68.0 -> v1.68.1

# 01 — Delta (MultiMeters)

Item DC-REV-01 of the 2026-10-04 LibKa0s v1.68.1 re-vendor, branch
`feat/2026-10-04-revendor-libka0s-v1.68.1`, run as `/dev-copilot:wow-revendor-libka0s MultiMeters --tag v1.68.1`.
v1.68.1 is the library's half of the `wow-addon` -> `dev-copilot` rename: test kit revision 36, no
LibStub minor moved. Copied from the **local** annotated tag `v1.68.1` (tag object `9fb7956`, commit
`9000cbd`) with `git -C ../LibKa0s archive v1.68.1 LibKa0s testkit | tar -x -C <scratch>`, never a branch
tip. The library's checkout sits one merge past the tag (`29e61d6`), and
`git -C ../LibKa0s diff --quiet v1.68.1 HEAD -- LibKa0s testkit` exited 0, so the tree and the tag agree
on both payloads; the copy is still taken from the tag.

## Step 0. Pre-flight

The roster walk over `../WowAddonStandards/standards/ADDONS.md` printed `ok` for all eleven addons.
MultiMeters' newest single-tag bundle, `2026-10-02-v1.68.0`, states base v1.67.0, and the provenance
line before its re-vendor commit `8b0345c` named v1.67.0. No base correction is owed.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` -> `55:Bundles [LibKa0s](...) v1.68.0 (MIT).` The last commit touching
either payload (`git log -1 --format=%H -- libs/LibKa0s tests/_kit`) is `8b0345c` (TP-MM-01), and its
CLAUDE.md names v1.68.0; `git log "$c..HEAD" -- CLAUDE.md` lists no roll since. The two agree, and
`diff -rq` of the v1.68.0 archive against both payloads printed `payload-matches`. Base v1.68.0.

`git -C ../LibKa0s log --oneline v1.68.0..v1.68.1`: 7 commits (the drag-attach merge `c2c078d`,
SD-FIN-01 `0e9deee`, then DC-REN-01..05, `cfefa99`..`9000cbd`). `git -C ../LibKa0s diff --stat v1.68.0
v1.68.1 -- LibKa0s testkit`: `testkit/framework.lua | 2`, `testkit/run-automated-tests.sh | 8`,
`testkit/test_eol.lua | 2`; 3 files changed, 6 insertions, 6 deletions. Nothing under `LibKa0s/`.

## 3b/3c. Per-file minors

The 3b grep over `libs/LibKa0s/*.lua` matched 32 constants, one per file the tag's `LibKa0s.xml` lists
(32). The per-file loop over that XML compared every file's constant, vendored against the tag:
**no file moved.** No file is new (no empty `old:` column), none removed. The library majors stay
where v1.68.0 left them (CHANGELOG v1.68.1 block: `Core` 10, `Widgets` key 12.1.4, `Options` key
28.2.34.2.3.8.1.7.4.2, `Perf` key 14.1.1.6, and the rest unchanged). No cross-major skew.

## 3d. Diffs (before the copy)

- `diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` (content) and `diff -rq` (bytes): both
  empty.
- `diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit` and `diff -rq`: both list exactly
  `framework.lua`, `run-automated-tests.sh` and `test_eol.lua`, the three files the tag changed. No
  `Only in` line on either side, so nothing will be deleted.

## 3e. Consumption

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v
/tests/` lists 18 lookup sites across Compat, Bus, Core, DebugLog, Env, Launcher, Lifecycle, Media,
Perf, Pool, Widgets, Options, Schema and Slash, unchanged from v1.68.0. No major moved, so the
consumption map gates nothing in this range.

## 3f. Kit revision

`grep -n 'Kit.VERSION'`: `<scratch>/testkit/framework.lua:20` reads 36, `tests/_kit/framework.lua:20`
reads 35. Revision 36 renames the commands the kit names (`/wow-addon:bump-version` ->
`/dev-copilot:bump-version` in the `RESULTS.md` lead-in the runner prints and two comments;
`wow-addon/scripts/normalize-eol.sh` -> `dev-copilot/scripts/normalize-eol.sh` in one comment;
`/wow-addon:automated-tests` -> `/dev-copilot:wow-automated-tests` in `test_eol.lua`'s header). No kit
member, case name, mock or manifest field changes (`docs/api/testkit/version-36-docs.md` at the tag), so
`docs/test-cases.md` does not change. Both payloads are copied whole in one commit, so the
revision-11 pairing rule (LibKa0s v1.9.0 or newer travels with kit revision 11 or newer) holds by
construction.

## 3g. Contract delta — blockers

None. The majors to read are those 3c says moved a minor, intersected with those 3e says this addon
looks up; 3c moved none, so the intersection is empty and no `docs/api/<Major>/` document pair applies.
The kit's own document, `git -C ../LibKa0s show v1.68.1:docs/api/testkit/version-36-docs.md`, states
"No public member is added, removed or renamed, no kit case is added, removed or renamed, no mock
changes, and the manifest the runner writes is unchanged." The one `__Attach*` site,
`settings/Schema_Compose.lua:479` (`optlib.__AttachCompose`), belongs to Options, whose files did not
move.

## 3h. Unrecorded tags

The audit walk from the store's horizon (2026-08-25) over `libs/LibKa0s`, `tests/_kit` and the
CLAUDE.md provenance rolls, minus the tags `docs/revendor/` records, printed nothing. No span bundle.

## After the copy

`cp -r` of both payloads; then `diff -r --strip-trailing-cr` and `diff -r` of `<scratch>/LibKa0s`
against `libs/LibKa0s` and of `<scratch>/testkit` against `tests/_kit` are all empty, content and bytes.
`tests/_kit/run-automated-tests.sh` stays recorded `100755`. Nothing was deleted (no `Only in` line
before the copy). In the same commit: CLAUDE.md:55's provenance line rolled v1.68.0 -> v1.68.1,
`docs/settings-panel.md:29`'s "v1.68.0 bundled" stamp with it, and the two lines of the addon's own
prose that name the kit revision it holds moved 35 -> 36 (`DEPENDENCIES.md:35`, "the sighted shadow
... builds (kit 36)"; `docs/testing.md:597`, the complexity row's "(kit 36: ...)"). `tests/run.lua:356`
("since kit revision 35") names the revision `test_lizard_sighted` arrived in, not the one held, and is
left as written. `README.md` carries no provenance line, so nothing was removed there.
