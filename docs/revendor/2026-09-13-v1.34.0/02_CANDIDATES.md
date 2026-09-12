# 02 — Candidates: LibKa0s v1.34.0

Sources: the v1.34.0 block of `CHANGELOG.md` at the tag; `docs/api/Options/version-18.15.5.3-docs.md`,
`docs/api/Slash/version-10-docs.md` and `docs/api/testkit/version-19-docs.md` at the tag.

## Class A: delivered on the copy alone

| Item | What it does here |
|---|---|
| Slash 10: a `string` row takes the whole value after the path, trimmed | `window.name` (`settings/Schema.lua:179`) and `export.whisperTo` now keep every word from `/mm set`. So do the LSM rows whose shipped defaults have spaces in them, `window.barTexture` (`"Blizzard Raid Bar"`, `:282`) and `window.font` (`"Friz Quadrata TT"`, `:290`), which the CLI could not set back to their own defaults before. |
| Options 18 / OptionsCompose 5, without the new field | The descriptor supplies `resetProfile` (`settings/OptionsSetup.lua:197`), so on the copy alone the Reset-all tooltip moves to *"Reset the current profile to its defaults. Your other profiles are not affected."* |
| Kit 19: the AceDB fake's `OnProfileReset` carries no key | Unreachable: this harness's AceDB wrapper already fires no key on a reset (01_DELTA §3f). |

## Class B: host change required

### B1. `profilesPage = true` on the Options descriptor (O18)

This addon ships an AceDBOptions Profiles sub-page and supplies `resetProfile`, which is the case
`version-18.15.5.3-docs.md` ("What the host does") names. With the field the General page's
Reset-all tooltip reads *"Reset the current profile to its defaults — the same thing Profiles →
Reset Profile does. Your other profiles are not affected."*, which is `options-ui-§12`'s SHOULD.

## Class C: whole-module adoption

None.
