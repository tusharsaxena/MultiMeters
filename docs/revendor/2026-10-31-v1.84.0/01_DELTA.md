Delta: LibKa0s v1.83.0 -> v1.84.0

# 01 — Delta (MultiMeters)

Local annotated tag `v1.84.0`, commit `e917ccd`. The tag is not pushed. This run is the repo's leg of
Ka0sAddonsCommonTasks `docs/2026-10-31-FINDINGS_REMEDIATION/M2_LIBRARY_RELEASE.md`, step 7.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` gives line 62, v1.83.0. `git log -1 --format=%H -- libs/LibKa0s tests/_kit`
gives `0d603a4`, whose CLAUDE.md names v1.83.0, so the two agree. Base: v1.83.0.

Step 0, for this addon: the newest single-tag bundle is `2026-10-24-v1.77.0`, base v1.76.0, and the
line before it agrees. The v1.80.0..v1.83.0 span is recorded. No correction.

## 3b. Actual version

`git archive HEAD libs/LibKa0s tests/_kit` against `git -C ../LibKa0s archive v1.83.0 LibKa0s testkit`, with
`diff -rq --strip-trailing-cr` and the undeclared icons set aside: no difference. The bytes are v1.83.0.

## 3c. Per-file minors that move

Loop over the tag's `LibKa0s/LibKa0s.xml` with the `[A-Z_]*MINOR` grep. `old: new` marks a file new in this range.

```
Schema.lua  old: 2  new: 3
Charts.lua  old: new  new: 1
ChartsRender.lua  old: new  new: 1
Skin.lua  old: 10  new: 11
SkinOwnerTokens.lua  old: new  new: 1
SkinDefs.lua  old: 18  new: 19
SkinDefsOthers.lua  old: new  new: 1
WidgetsDragHandle.lua  old: 8  new: 10
DebugLogDiagnostics.lua  old: 5  new: 6
Slash.lua  old: 20  new: 21
Options.lua  old: 34  new: 35
OptionsWidgets.lua  old: 38  new: 40
OptionsFlow.lua  old: new  new: 2
OptionsIds.lua  old: 5  new: 6
OptionsIdSuggest.lua  old: new  new: 1
OptionsTabs.lua  old: 11  new: 13
OptionsTabbed.lua  old: new  new: 2
OptionsCompose.lua  old: 14  new: 15
OptionsSkinPicker.lua  old: 4  new: 5
OptionsSkinPickerRows.lua  old: new  new: 1
SimPanel.lua  old: 8  new: 9
SimPanelRender.lua  old: new  new: 1
```

No file is behind on a major this repo keeps, so there is no cross-major skew.

## 3d. Diffs before the copy

`diff -r --strip-trailing-cr` of the extract against `libs/LibKa0s` and `tests/_kit`: 24 and 5 content
differences outside the undeclared icons, all of them the moved files and the new files above. No
`Only in libs/LibKa0s` line outside what the copy replaces.

## 3e. Consumption

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/` and `tests/`: Bus, Compat, Core,
DebugLog, Env, Launcher, Lifecycle, Media, Perf, Pool, Sim, Skin. New major `LibKa0s-Charts-1.0`:
no lookup, an unadopted module. See `02_CANDIDATES.md`.

## 3f. Kit

`grep -n 'Kit.VERSION'`: revision 46 -> 47 (`mock_ace.lua` peeled off `mock_base.lua`). The two payloads move
together in one commit, which meets the pairing rule.

## 3g. Contract delta

Read for the majors that moved and that this addon looks up: Options, Schema, Slash, Skin, Widgets,
DebugLog, Sim. Each document pair was diffed at `docs/api/<Major>/` v1.83.0 against v1.84.0, and the text
states every change as additive or a pure move. No MUST appeared under an existing surface. The one
`__AttachCompose` site, `settings/Schema_Compose.lua:343`, hands `profilesPage` and `resetProfile`, and
neither contract moved.

**Blockers:** one, of the pin kind, fixed in the copy's commit. `O.PositionBlock` is a new public member,
so `tests/test_surface_parity.lua` goes red on it. It is a composer, and this addon reaches composers
through the `__AttachCompose` table in `settings/Schema_Compose.lua`, never through `NS.Helpers`, so it
joins that suite's documented live-only composer group rather than the stub. A stub member would have no
caller.

## 3h. Unrecorded tags

The listing printed nothing beyond this run's own tag. No span bundle.

## 3i. Icon declaration

`CLAUDE.md:63`, directly under the provenance line, kept unchanged. Charts draws no catalog icon and this
addon does not adopt it. No provenance split.

## 3j. Tests assuming the whole folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests`: `test_mediasetup.lua:90,112,123` and
`test_options_panel.lua:889-890` check declared names only. Nothing to fix.
