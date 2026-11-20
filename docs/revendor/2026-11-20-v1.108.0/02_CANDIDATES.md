# 02 Candidates: LibKa0s v1.107.0 -> v1.108.0

Source: the tag's `CHANGELOG.md` v1.108.0 block and its *What a consumer owes* list.

## A. Reached this addon on the re-vendor alone

- WidgetsDropdown minor 3: the shared menu measures no secret label and reads no width that answers a secret (U-21,
  narrowed by the owner on 2026-11-20). It is what lets SD-SK-MM drop the segment picker's in-combat client-menu
  fallback.
- SkinPaintHud minor 2: `S.BarGloss` also takes a fill Texture. This addon hands it StatusBars only, so nothing moves.

## B. Host change required

The run's SD-SK-MM item: the three swatch companions (SD-SK-MM.2, .4, .5), the classless fill and tooltip line colors
(SD-SK-MM.3, .6), the tooltip spell-bar switch surface (SD-SK-MM.1), the guard declarations of kit revision 58, and the
segment picker's fallback removal (U-21).

## C. New surfaces not adopted (noted, not interviewed)

- `W.OwnerWarnings(owner, sink)` (Widgets minor 30): reports an owner-less library widget under an owned frame to a
  debug sink. This addon builds its library widgets with an owner; not wired.
- `Core.ApplySkin` host tables with `skinBands` (Core minor 19), `W.BarStyle` `glossFromSkin`, `Callout` and
  `WaypointArrow` members: surfaces this addon does not consume.
