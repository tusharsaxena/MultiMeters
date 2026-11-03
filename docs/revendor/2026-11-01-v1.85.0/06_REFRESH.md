# Refresh: the re-cut v1.85.0

`FS-MM-GATE` of Ka0sAddonsCommonTasks `docs/2026-11-01-FULL_SKINNING/`. The local tag moved from LibKa0s `9776130` to `2ad1a50`, for the owner's rulings of 2026-11-01, the review and the gate. `libs/LibKa0s/` and `tests/_kit/` are copies of the tag again, by hand, apart from the pruned icons. Kit revision 49 -> 50.

- **Moved:** Media 12, OptionsCompose 18, Skin 15, SkinDefs 25, SkinDefsOthers 7, SkinEUI 4, SkinPaint 17, SkinPaintControls 15, SkinPaintExtras 16, Widgets 21.
- **Facade:** `BarBorder`, which answers its stored three, and `HoverArt`, a no-op.
- **Moved under no call:** a bar family row's `disabledIf` is a function, Show border gains one, and the border value lists gain `Solid`; the pins in `tests/test_schema.lua`, `tests/test_skin_hud.lua`, `tests/test_skin_flip.lua` and `tests/test_settings_pin.lua` follow.
- **Found by that move:** `settings/Schema_Compose.lua`'s compose descriptor had no `addonName` or `get`, so a composed picker showed no skin value and a bar border's rows stayed live under a real style. Both are passed now.
- **Adopted:** `Kit.skinValues` and `Kit.skinSwitch` (`tests/skin_facts.lua`), `S.BarBorder` behind `NS.SkinBorderShown`, `S.IconBorder` on a Texture, and `W.ContextMenu` for the segment picker. The client's menu stays under the Combat restriction, because a label can be a secret string there and the menu's `menuWidth` does arithmetic on its `GetStringWidth`.
- **Owed nothing:** no numeric path reaches `Skin.FollowOnce`, whose keys here are empty, so no repair step. `S.Mark` here is on the Columns blocks, which this addon pools itself and which are no AceGUI widgets, so nothing untracks. No bar default here is a real style: `bars.borderStyle` and `tooltip.barBorderStyle` ship None and `bars.border` false. The `frame.borderStyle` default is the window's edge and reads no `bar.*` token; `docs/releasing.md`'s naming of this addon there has no reader behind it.
