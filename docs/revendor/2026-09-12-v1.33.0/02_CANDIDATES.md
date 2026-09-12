# 02 — Candidates: LibKa0s v1.33.0

Sources: the v1.33.0 block of `CHANGELOG.md` at the tag; `docs/api/Options/version-17.15.4.3-docs.md`,
`docs/api/Slash/version-9-docs.md` and `docs/api/testkit/version-18-docs.md` at the tag.

## Class A: delivered on the copy alone

| Item | What it does here |
|---|---|
| Options 17: every LSM font loaded on the first panel show | The descriptor already hands the library `getLSM` (`settings/OptionsSetup.lua:225`). The Header, Bars, Tooltip and Columns text rows are composed as `FontGroup` blocks (`settings/Schema_Compose.lua:784`, `:956`, `:1113`, `:1160`), which write `LSM30_Font`. So the first open of those dropdowns now draws every row. Nothing to wire. |
| Slash 9 | Docstrings only. Nothing. |
| Kit 18: the AceDB fake's `OnProfileCopied` carries the source key | Unreachable here. `tests/wow_mock.lua` wraps the kit's AceDB and re-fires string-form handlers itself, already with the source for a copy. `tests/test_database.lua:213` asserts `'Default' → 'Raid'` through that wrapper, before and after. |

## Class B: host change required

None. v1.33.0 adds no descriptor field and no member.

## Class C: whole-module adoption

None.
