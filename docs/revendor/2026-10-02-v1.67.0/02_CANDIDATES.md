# 02 — Candidates (MultiMeters)

Listed, **not interviewed**: the census-adoption bundle already assigns each surface to an item.

| Class | Candidate | Evidence | Would touch | Taken by |
|---|---|---|---|---|
| A | The IdList help art falls back to the client glyph when `addonName` is not a loaded addon | LibKa0s `CHANGELOG.md` v1.67.0, "OptionsIdList minor 3" | — | Delivered by the copy; no IdList is drawn here |
| B | Options descriptor `addonName` (the host's folder name, its first vararg) | `docs/api/Options/version-28.2.34.2.3.8.1.7.4.2-docs.md`; LibKa0s#42 | `settings/OptionsSetup.lua` (the descriptor `lib:New` takes at :505; not `settings/Schema_Compose.lua`'s MasterControls display label) | **CA-MM-NM** |
| B | `MakeResizable` `gripParent` + `onResizeStop` (+ `canResize` as defence in depth) | `docs/api/Core/version-10-docs.md`, "The resize grip"; LibKa0s#41 | `modules/Window.lua`, `modules/Window_Placement.lua`, `modules/Window_Header.lua`, `core/CoreSetup.lua` | **CA-MM-02** (MultiMeters#58; design D3.3) |

No class C: no major is new.
