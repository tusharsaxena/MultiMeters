# 02 — Candidates: LibKa0s v1.34.0

Sources: the v1.34.0 block of `CHANGELOG.md` at the tag; `docs/api/Options/version-18.15.5.3-docs.md`,
`docs/api/Slash/version-10-docs.md` and `docs/api/testkit/version-19-docs.md` at the tag.

## Class A: delivered on the copy alone

| Item | What it does here |
|---|---|
| Slash 10: a `string` row takes the whole value after the path, trimmed | `window.name` (`settings/Schema.lua:179`) and `export.whisperTo` now keep every word from `/mm set`. So do the LSM rows whose shipped defaults have spaces in them, `window.barTexture` (`"Blizzard Raid Bar"`, `:282`) and `window.font` (`"Friz Quadrata TT"`, `:290`), which the CLI could not set back to their own defaults before. |
| Options 18 / OptionsCompose 5 | **Nothing moved on the copy alone.** The Reset-all tooltip kept *"Restore every setting in this addon to its default."*, the wording for a host with no `resetProfile`, although `settings/OptionsSetup.lua:197` supplies one. The composers never saw that descriptor; B1 hands them one. |
| Kit 19: the AceDB fake's `OnProfileReset` carries no key | Unreachable: this harness's AceDB wrapper already fires no key on a reset (01_DELTA §3f). |

## Class B: host change required

### B1. `profilesPage = true` (O18), through a compose descriptor

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
descriptor would change nothing.

**What was adopted instead.** `__AttachCompose(O, d)` reads `d` in one place: `resetAllTooltip`
(`libs/LibKa0s/OptionsCompose.lua:264`–`:268`, called at `:496`). The button's click is
`spec.onResetAll`, and no bulk hook or other behaviour reads `d`. So `settings/Schema_Compose.lua`
passes a compose descriptor as the second argument, `{ profilesPage = true, resetProfile = <forwarder>
}`. The forwarder calls the real descriptor's `resetProfile`, which `settings/OptionsSetup.lua`
publishes as `NS.OptionsDescriptor`, resolving it at call time. It is not a second reset. The
owner's "adopt as needed" covered it, after the first pass withheld it.

## Class C: whole-module adoption

None.
