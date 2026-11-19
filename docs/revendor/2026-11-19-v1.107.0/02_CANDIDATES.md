# 02 Candidates: LibKa0s v1.106.0 -> v1.107.0

Source: the tag's `CHANGELOG.md` v1.107.0 block and the Widgets API documents for key 28.2.7.15.2.7.8.6.1.1.

## A. Reached this addon on the re-vendor alone

- WidgetsDragHandle minor 15 (marks [?][settings][close], header tints, tighter gap, `ApplyLevel` re-levels the
  settings mark, LibKa0s#96) and WidgetsDragHandleTip minor 2 (the strip tooltip always above). This addon draws no
  drag strip, so neither change has a visible effect here. It is recorded as delivered.

## B. Host change required

None for this addon. The release's host changes (strip `settings`/`onClose` handlers, the strip `tooltipPlace`
hook's removal) are the `AF-STRIP-*` items of the run, and the run lists none for MultiMeters.

## C. Whole-module adoption

None new in this range (no file added, no major added).
