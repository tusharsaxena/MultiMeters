# 02 — Candidates (MultiMeters)

Sources: `git -C ../LibKa0s log --oneline v1.67.0..v1.68.0`, LibKa0s `CHANGELOG.md:13` (the v1.68.0
block, "WidgetsDragHandle minor 4"), and the `Since 4` markers in
`docs/api/Widgets/version-12.1.4-docs.md` (`:22`, `:692`, `:725`), diffed against `version-12.1.3-docs.md`.

| Class | Candidate | Evidence | Would touch | Blast radius |
|---|---|---|---|---|
| B | `tooltipPlace(tip, frame)` on the drag-handle spec (and `place` on a tooltip descriptor): the host places the strip's tooltip, falling back to the cursor owner | `version-12.1.4-docs.md:18-48`, `:692`, `:725` | none: this addon builds no `DragHandle` | additive, but with no surface to add it to |

No class A item reaches this host: the change is confined to `lib.DragHandle`, which nothing here
calls (`grep -rn 'DragHandle\|tooltipPlace'` outside `libs/` and `tests/_kit/` is empty), and a host
without the hook keeps minor 3's call order (`version-12.1.4-docs.md:46`). No class C: no major is new.

**Recommendation: decline as not applicable.** The hook is a field on a widget this addon does not
draw. MultiMeters' windows move by their own header (`modules/Window_Header.lua`), not by a LibKa0s
drag strip, so there is no tooltip to place.
