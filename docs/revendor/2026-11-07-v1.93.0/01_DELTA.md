Delta: LibKa0s v1.92.0 -> v1.93.0

Recorded before anything was committed. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.93.0 LibKa0s testkit tools` (tag commit 07ef4d2, local annotated tag, not yet pushed). Run under the WoW Forever port, item WFP-RV2-MM.

## 3a Base
- `grep -ioE 'Bundles \[LibKa0s\]\(...\) v...' CLAUDE.md` named v1.92.0 before the roll.
- Last payload commit before this run, `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = b6e3ec9; its CLAUDE.md names v1.92.0. They agree.
- Payload before the copy equalled the library at v1.92.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.92.0 extract printed nothing (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.92.0..v1.93.0` is 6 commits (WFP-LK-06, WFP-LK-08, WFP-FIX-02, WFP-LK-09).

## 3b/3c Per-file minors that moved (old = this addon, new = v1.93.0)
```
OptionsTabs.lua  old: 16  new: 17
OptionsHeader.lua  old: none  new: 1
```
Every file not listed matched v1.92.0 before the copy, so there is no cross-major skew.

## 3d Diffs
Post-copy, `diff -r --strip-trailing-cr` of both payloads against the v1.93.0 extract is empty apart from the icons the addon did not declare; `tests/test_vendor_sync.lua` is green.

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
Majors in the payload with no lookup in this addon: LibKa0s-Charts-1.0 LibKa0s-Glow-1.0 LibKa0s-IconBrowser-1.0 LibKa0s-Item-1.0 LibKa0s-Toast-1.0 

## 3f Kit revision
```
old: 20:Kit.VERSION = 52
251:  t.KIT_VERSION = Kit.VERSION
new: 20:Kit.VERSION = 53
251:  t.KIT_VERSION = Kit.VERSION
```
Kit revision 53 pairs with v1.93.0 and both payloads are copied whole in one commit.

## 3g Contract delta and Blockers
`git diff -U0 v1.92.0 v1.93.0 -- LibKa0s/` is the OptionsTabs minor 17 peel (O.PageHeader and O.SubTabStrip moved unchanged into the new OptionsHeader.lua) and the LibKa0s.xml line that loads it. No member changed its name, arguments or behavior. Host-supplied members, `__Attach*` sites in this addon:
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
**Blockers: none.** One addition in the kit is not a contract change but is a new gate every consumer inherits: `test_client_globals` (kit revision 53), wired in this commit.

## 3h Unrecorded vendored tags
```
(empty)
```

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: 63:LibKa0s icons: chat, ph:chat-text, chevron-down, chevron-up, clear, close, confirm, copy, expand, export, eye, info, lock, minimise, move, reset, segment, settings, sort-down, sort-up, spreadsheet,
- Kept as written; no icon name changes in this run.

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
