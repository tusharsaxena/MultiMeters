Delta: LibKa0s v1.91.0 -> v1.92.0

Recorded before anything was copied. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.92.0 LibKa0s testkit tools` (tag commit d690237, local annotated tag, not yet pushed). Run under the WoW Forever port, item WFP-RV-MM.

## 3a Base
- `grep -ioE 'Bundles \[LibKa0s\]\(...\) v...' CLAUDE.md` names v1.91.0.
- Last payload commit `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 94b3127; its CLAUDE.md names v1.91.0. They agree.
- Payload today equals the library at v1.91.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.91.0 extract printed nothing (payload-matches).
- Step 0 pre-flight row for this addon: MultiMeters  2026-11-06-v1.91.0  base v1.90.0  vendored-before v1.90.0@94b3127  ok. No base correction needed.
- Library range: `git -C ../LibKa0s log --oneline v1.91.0..v1.92.0` is 12 commits (WFP-LK-01 to WFP-LK-07).

## 3b/3c Per-file minors that moved (old = this addon, new = v1.92.0), 10 files
```
Compat.lua  old: 1  new: 2
Slash.lua  old: 21  new: 22
Launcher.lua  old: 7  new: 8
OptionsRegistry.lua  old: 4  new: 5
OptionsWidgets.lua  old: 44  new: 45
OptionsFlow.lua  old: 2  new: 3
OptionsTabs.lua  old: 15  new: 16
OptionsTabbed.lua  old: 2  new: 3
OptionsKeybinds.lua  old: 7  new: 8
Perf.lua  old: 15  new: 16
```
No consumer file is behind on a minor the tag did not move: every unmoved file matched in the v1.91.0 diff above, so there is no cross-major skew.

## 3d Diffs
- Pre-copy, `diff -r --strip-trailing-cr` against the v1.92.0 extract: the only differences are the files the library changed in the range (10 non-icon lines in libs/LibKa0s, plus the kit files). Post-copy the same diff, both payloads, is empty apart from the icons the addon did not declare (Step 4, below).

## 3e Consumption map
```
core/Compat.lua:73:LibStub("LibKa0s-Compat-1.0", true)
core/Constants.lua:591:LibStub("LibKa0s-Bus-1.0", true)
core/CoreSetup.lua:122:LibStub("LibKa0s-Core-1.0", true)
core/Database_Migrations.lua:859:LibStub("LibKa0s-Skin-1.0", true)
core/Database_Migrations.lua:987:LibStub("LibKa0s-Skin-1.0", true)
core/DebugLogSetup.lua:254:LibStub("LibKa0s-DebugLog-1.0", true)
core/Diagnostics_Runtime.lua:422:LibStub("LibKa0s-Sim-1.0", true)
core/EnvSetup.lua:74:LibStub("LibKa0s-Env-1.0", true)
core/LauncherSetup.lua:91:LibStub("LibKa0s-Launcher-1.0", true)
core/LifecycleSetup.lua:37:LibStub("LibKa0s-Lifecycle-1.0", true)
core/MediaSetup.lua:74:LibStub("LibKa0s-Media-1.0", true)
core/Namespace.lua:211:LibStub("LibKa0s-Bus-1.0", true)
core/PerfSetup.lua:42:LibStub("LibKa0s-Perf-1.0", true)
core/PoolSetup.lua:35:LibStub("LibKa0s-Pool-1.0", true)
core/Secrets.lua:160:LibStub("LibKa0s-Compat-1.0", true)
core/SimSetup.lua:41:LibStub("LibKa0s-Sim-1.0", true)
core/SkinSetup.lua:112:LibStub("LibKa0s-Skin-1.0", true)
modules/Export_Modal.lua:39:LibStub("LibKa0s-Widgets-1.0", true)
modules/Sim.lua:325:LibStub("LibKa0s-Sim-1.0", true)
modules/Window.lua:73:LibStub("LibKa0s-Widgets-1.0", true)
modules/Window_Frame.lua:32:LibStub("LibKa0s-Widgets-1.0", true)
modules/Window_Header.lua:78:LibStub("LibKa0s-Widgets-1.0", true)
settings/ColumnBlocks.lua:94:LibStub("LibKa0s-Widgets-1.0", true)
settings/OptionsSetup.lua:134:LibStub("LibKa0s-Options-1.0", true)
settings/Schema_Compose.lua:325:LibStub("LibKa0s-Options-1.0", true)
settings/Schema_Paths.lua:85:LibStub("LibKa0s-Schema-1.0", true)
settings/Slash.lua:209:LibStub("LibKa0s-Slash-1.0", true)
```
Majors in the payload with no lookup in this addon (unadopted, class C): LibKa0s-Charts-1.0 LibKa0s-Glow-1.0 LibKa0s-IconBrowser-1.0 LibKa0s-Item-1.0 LibKa0s-Toast-1.0 

## 3f Kit revision
```
old: 20:Kit.VERSION = 51
251:  t.KIT_VERSION = Kit.VERSION
new: 20:Kit.VERSION = 52
251:  t.KIT_VERSION = Kit.VERSION
```
Kit revision 52 pairs with v1.92.0 and both payloads are copied whole in one commit, which satisfies the revision-11 pairing rule by construction.

## 3g Contract delta and Blockers
Read: `git diff -U0 v1.91.0 v1.92.0 -- LibKa0s/`, removed lines only (29). Every removed line is a version constant bump or a line rewritten to read an optional `clients` field (gate applied only when a descriptor carries `clients`), plus Perf's spec-name read, which now tries `C_SpecializationInfo.GetSpecializationInfo` first and then the bare global. No surface kept its name and arguments while changing behavior for a host that does not pass `clients`. Library API docs read: docs/api/Compat/version-2-docs.md (new), Slash 22.2, Launcher 8, Perf 16.1.1.13, Options 37.5.45...4 (all additive, Since markers only).
Host-supplied members, `__Attach*` sites in this addon:
```
./settings/Schema_Compose.lua:284:-- reason is load order. `lib.__AttachCompose` is what `lib:New` calls to hang the
./settings/Schema_Compose.lua:326:    if optlib and optlib.__AttachCompose then
./settings/Schema_Compose.lua:344:        optlib.__AttachCompose(C, {
./tests/run.lua:83:        -- Three more attachment files the shell calls only when present (`if lib.__AttachX
./tests/test_layers.lua:213:    O.__AttachCompose(probe, {})
./tests/test_options_panel.lua:847:    -- (SkinAce.lua __AttachSkinAce), so every widget a page acquires is painted for this addon's
./tests/test_options_tabs.lua:318:    -- __AttachCompose call, or its `profilesPage = true`.
./tests/test_surface_parity.lua:25:-- dropped. Those are the library talking to itself across its own file boundary — `__AttachCompose`,
./tests/test_surface_parity.lua:26:-- `__AttachWidgets`, `__print` — and a stub is obliged to carry none of them. The exemptions below
./tests/test_surface_parity.lua:79:        -- of its own through `optlib.__AttachCompose(C)` and calls them off that (`:678-688`). With
```
**Blockers: none.**

## 3h Unrecorded vendored tags
```
(empty)
```

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: 63:LibKa0s icons: chat, ph:chat-text, chevron-down, chevron-up, clear, close, confirm, copy, expand, export, eye, info, lock, minimise, move, reset, segment, settings, sort-down, sort-up, spreadsheet,
- Provenance line at CLAUDE.md:62; next non-blank line: 63: LibKa0s icons: chat, ph:chat-text, chevron-down, chevron-up,. The declaration is kept as written; no icon name changes in this run.
- README provenance line (must be absent): none

## 3j Tests that assume the whole icon folder
```
tests/prose_waivers.lua:16:        -- `libs/LibKa0s/media/icons/minimise.tga` and catalogs it under `minimise`; NS.Icon looks
tests/test_headercontrols.lua:604:    -- `minimise`, because that is LibKa0s-Media-1.0's catalog key (media/icons/minimise.tga), a
tests/test_mediasetup.lua:90:    local root = (T.root or ".") .. "/libs/LibKa0s/media/icons/"
tests/test_mediasetup.lua:115:        assertTrue(fh ~= nil, "libs/LibKa0s/media/icons/" .. name .. ".tga is not vendored")
tests/test_mediasetup.lua:126:    local root = (T.root or ".") .. "/libs/LibKa0s/media/icons/"
tests/test_options_panel.lua:889:    local fh = io.open((T.root or ".") .. "/libs/LibKa0s/media/icons/info.tga", "rb")
tests/test_options_panel.lua:890:    assertTrue(fh ~= nil, "libs/LibKa0s/media/icons/info.tga is missing")
```

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit: none
