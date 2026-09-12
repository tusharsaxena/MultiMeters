# 02 — Candidates: LibKa0s v1.34.0

Sources: the v1.34.0 block of `CHANGELOG.md` at the tag; `docs/api/Options/version-18.15.5.3-docs.md`,
`docs/api/Slash/version-10-docs.md` and `docs/api/testkit/version-19-docs.md` at the tag.

## Class A: delivered on the copy alone

| Item | What it does here |
|---|---|
| Slash 10: a `string` row takes the whole value after the path, trimmed | `window.name` (`settings/Schema.lua:179`) and `export.whisperTo` now keep every word from `/mm set`. So do the LSM rows whose shipped defaults have spaces in them, `window.barTexture` (`"Blizzard Raid Bar"`, `:282`) and `window.font` (`"Friz Quadrata TT"`, `:290`), which the CLI could not set back to their own defaults before. |
| Options 18 / OptionsCompose 5 | **Nothing moves.** The Reset-all tooltip still reads *"Restore every setting in this addon to its default."*, the wording for a host with no `resetProfile`, although `settings/OptionsSetup.lua:197` supplies one. The composers never see that descriptor: see B1. |
| Kit 19: the AceDB fake's `OnProfileReset` carries no key | Unreachable: this harness's AceDB wrapper already fires no key on a reset (01_DELTA §3f). |

## Class B: host change required

### B1. `profilesPage = true` on the Options descriptor (O18): it cannot reach this addon's button

This addon ships an AceDBOptions Profiles sub-page and supplies `resetProfile`, which is the case
`version-18.15.5.3-docs.md` ("What the host does") names, and the v1.34.0 CHANGELOG lists it as a
one-line adopter. It is not one, because its Master controls are not composed on the `lib:New`
instance:

- `settings/Schema_Compose.lua:476`–`:484` attaches the composers to a table of its own with
  `optlib.__AttachCompose(C)`, passing **no descriptor**;
- `:628` calls `MasterControls` at that file's load, and the TOC loads it (line 115) before
  `settings/OptionsSetup.lua` (line 123) builds the descriptor;
- `resetAllTooltip(desc)` runs when `MasterControls` is called, not when the button is drawn
  (`libs/LibKa0s/OptionsCompose.lua:494`–`:498`), and a missing descriptor answers as no
  `resetProfile`.

Measured: a test that fires the General page's real button and expects the equivalence text read
*"Restore every setting in this addon to its default."* So `profilesPage = true` on the
descriptor would change nothing. Reaching the button needs new host wiring, a descriptor handed to
`__AttachCompose` at `Schema_Compose.lua` load (before the real `resetProfile` exists), or a
library change. Either is outside this run's brief.

## Class C: whole-module adoption

None.
