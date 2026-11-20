Delta: LibKa0s v1.107.0 -> v1.108.0

Recorded for item SD-RV-MM of Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/` (the copy, provenance,
icon-declaration and prune mechanics of `/dev-copilot:wow-revendor-libka0s` 2.10.1; the adoption interview and the
issue filing are skipped, because the run's bundle pre-decides this addon's work as SD-SK-MM). The payload comes from
the local tag, never the sibling tree: `git -C ../LibKa0s archive v1.108.0 LibKa0s testkit tools` (tag commit
`56c20b76`, not yet on origin, which is expected for this run: `git -C ../LibKa0s ls-remote --tags origin v1.108.0`
prints nothing).

## Step 0 pre-flight (this addon)

The newest single-tag bundle is `2026-11-19-v1.107.0`. Its line 1 says base v1.106.0, and the provenance line before
its re-vendor commit `09abaa1` named v1.106.0. Result: ok, so there is no base correction.

## 3a Base

- `grep -n '[Bb]undles' CLAUDE.md` named v1.107.0 (CLAUDE.md:62) before the roll.
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` returned `5ff37cf` (AF-RV-MM, the re-cut v1.107.0), whose
  CLAUDE.md names v1.107.0. The two agree.
- Before the copy, `diff -rq` of a v1.107.0 extract against `libs/LibKa0s` printed only `Only in <extract>/LibKa0s/media/`
  lines (the undeclared icons and the callout sounds), and against `tests/_kit` printed nothing. The payload matched.
- Range: `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0` is 14 commits (SD-LK-94, SD-LK-99, SD-LK-100, SD-LK-97
  Batches A to D with their review fixes, SD-LK-GUARD x3, SD-LK-REL x2). `git -C ../LibKa0s diff --stat v1.107.0
  v1.108.0 -- LibKa0s testkit` is 23 files, +1363 / -306.

## 3b/3c Per-file minors that moved (old = this addon before the copy, new = v1.108.0)

Run with the spec's loop over the tag's `LibKa0s.xml`. Files not listed did not move. No file is new.

| File | Old | New |
|---|---|---|
| Core.lua | MINOR 18 | 19 |
| Callout.lua | MINOR 4 | 5 |
| CalloutSettings.lua | SETTINGS_MINOR 5 | 6 |
| WaypointArrow.lua | MINOR 2 | 3 |
| WaypointArrowSettings.lua | SETTINGS_MINOR 2 | 3 |
| Charts.lua | MINOR 2 | 3 |
| ChartsRender.lua | RENDER_MINOR 1 | 2 |
| SkinPaint.lua | PAINT_MINOR 19 | 20 |
| SkinPaintHud.lua | HUD_MINOR 1 | 2 |
| SkinPaintControls.lua | CONTROLS_MINOR 18 | 19 |
| Widgets.lua | MINOR 29 | 30 |
| WidgetsDropdown.lua | DROPDOWN_MINOR 2 | 3 |
| WidgetsDragHandle.lua | DRAG_MINOR 15 | 16 |
| WidgetsDragHandleTip.lua | DRAGTIP_MINOR 2 | 3 |
| WidgetsLineChart.lua | CHART_MINOR 7 | 8 |
| WidgetsBar.lua | BAR_MINOR 1 | 2 |
| OptionsCompose.lua | COMPOSE_MINOR 19 | 20 |

Every file matched v1.107.0 before the copy, so there is no cross-major skew.

## 3d Diffs

After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the v1.108.0
extract were both empty. After the prune the only differences are `Only in <extract>/LibKa0s/media/icons` (the
undeclared icons) and `Only in <extract>/LibKa0s/media/sounds` (no `LibKa0s sounds:` line, so none ship). No file was
removed upstream, so nothing was deleted by hand.

## 3e Consumption map

Unchanged from the v1.107.0 bundle: `grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' --include='*.lua' . | grep
-v -e /libs/ -e /tests/`. This addon never looks up `LibKa0s-Callout-1.0`, `LibKa0s-Charts-1.0` or
`LibKa0s-WaypointArrow-1.0`, and never builds a `W.Bar`, a `W.Footer` or a drag strip. The moved surfaces it does reach:
`O.FontGroup`, `O.BorderGroup`, `O.BarGroup` and `O.ColorPair` through `settings/Schema_Compose.lua`'s `compose`, the
shared menu `W.ContextMenu` (the segment picker, `modules/Window_Header.lua`), and `S.BarGloss` on a cell's StatusBar.

## 3f Kit revision

`grep -n 'Kit.VERSION'` reads 58 in the extract and 57 in `tests/_kit/framework.lua` before the copy. Both payloads move
together by construction (whole-folder copy).

## 3g Contract delta, and the blockers fixed in the re-vendor commit

The tag's *What a consumer owes* list (LibKa0s `CHANGELOG.md`, v1.108.0) and the Options document's *Moving to this
version* (`docs/api/Options/version-38.5.46.3.7.2.9.17.3.1.4.20.13.7.5.8.7.12.1.1.1.4-docs.md`, Batch A) bind here:

1. **OptionsCompose minor 20 emits `FromSkin` companions by default.** Seven new rows appeared, which turned
   `test_schema_defaults`, `test_settings_pin`, `ValidateSchema` and the Defaults press red: `window.frame.backdropColorFromSkin`,
   `window.frame.borderStyleFromSkin`, `window.frame.borderColorFromSkin`, `window.header.colorFromSkin`,
   `window.bars.customColorFromSkin`, `window.bars.bgColorFromSkin`, `window.tooltip.barColorFromSkin`. Every other
   companion a block would emit is already a hand-written `extra` row, which the composer does not emit twice. In
   this commit:
   - The window's fill (ColorPair, `colorFromSkin = false`), its edge (BorderGroup, `fromSkin = false`) and the
     title's color (FontGroup, `colorFromSkin = false`) opt out for good: each has a color MODE whose Skin answer is
     its default (MM-A1, the owner's R-3 of the 2026-10-29 rollout), so a bool would be a second control for the same
     thing (options-ui-§17).
   - The three swatches the audit lists as GAPs (`bars.customColor` SD-SK-MM.2, `bars.bgColor` SD-SK-MM.4,
     `tooltip.barColor` SD-SK-MM.5) opt out here too, so the schema stays byte-identical in this commit; SD-SK-MM
     removes those three opt-outs and wires the companions they then emit.
2. **Kit revision 58's skin guards.** `test_skin_switch` ran the heap past its budget on "the window's fill and edge":
   the addon's own `tests/mock_frame.lua` answered `GetStatusBarTexture` on every frame, a Texture included, so the
   spy (which now walks `GetStatusBarTexture`) followed an endless chain of fills. The mock now answers nil on a
   Texture or a FontString, as the client does. `test_skin_values` reported 37 new typed values in the shapes the
   scanner now reads; `tests/skin_facts.lua` takes them as rows (texcoords and a share as `not a color`, last-resort
   `RGBA` fallbacks and pre-resolve looks as `unreachable default`, the swatch defaults behind a Skin mode or a
   companion as cause D4, the v17 Custom control color as L6), and four that are audit GAPs (SD-SK-MM.3, SD-SK-MM.6)
   as rows naming the item that removes them.

No other blocker: the shared menu's change (no secret label measured, U-21) needs no host change, and `S.BarGloss`
keeps its StatusBar shape.

## 3h Unrecorded tags

The listing (the audit's walk plus the provenance-rolling CLAUDE.md commits, horizon 2026-08-25) printed nothing new:
v1.107.0 has its bundle. No span bundle.

## 3i Icon declaration

Kept as is, directly under the provenance line (CLAUDE.md:63). The prune refused nothing; no set was added or removed,
so the README credits are unchanged. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop for a name the host forgot.

## 3j Tests that assume the whole icon folder

Unchanged from the v1.107.0 bundle: `tests/test_mediasetup.lua:90,115,126` and `tests/test_options_panel.lua:889-890`
open declared names only, and they are green after the prune. No blocker.
