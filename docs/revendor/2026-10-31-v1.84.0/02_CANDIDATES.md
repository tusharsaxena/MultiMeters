# 02 — Candidates (MultiMeters)

Sources: the `v1.84.0` block of `CHANGELOG.md`, and the `docs/api/<Major>/` documents for each major that moved.

## A. Delivered on the copy

- The peels: pure moves, with no public member, default or pixel moved (`CHANGELOG.md`, `LK-M2-PEEL`).
- `ApplyLevel` allocates nothing, and the WidgetsDragHandle fit (minors 9, 10). This addon calls no
  `DragHandle`, so neither reaches it.
- WoW Default's Friz is measured and guarded. No size moves.
- The diagnostics header names Charts (DebugLogDiagnostics minor 6). This is the one thing a player
  can see, and DIAG-43 covers it.

## B. Host change required

| Surface | Evidence | Would touch | Recommendation | Blast radius |
|---|---|---|---|---|
| `opts.beforeGroup`, `opts.afterSubgroup` | `docs/api/Options/version-35.4.40.2.6.1.7.13.2.3.15.9.4.3.6.5.5.1.1.1-docs.md` | `settings/*.lua` | Decline: no page needs a hook between groups | additive |
| `note` row | same document, Schema version 3 | `settings/Schema_*.lua` | Decline: the row descriptions carry the sentences today | additive |
| `O.PositionBlock` | same document, C15 | none | Decline: this addon has no X and Y rows | additive |
| `O.PageBanner{ acts }` | same document, OptionsTabs minor 13 | `settings/Windows.lua` | Decline: the Windows band is the addon's own | replaces host code |

## C. Whole-module

| Module | Evidence | Recommendation | Blast radius |
|---|---|---|---|
| `LibKa0s-Charts-1.0` | `docs/api/Charts/version-1.1-docs.md` | Decline: this addon draws no Insights chart | additive, none used |

The issue and docs search for an earlier refusal of Charts found none. It is new in this range.
