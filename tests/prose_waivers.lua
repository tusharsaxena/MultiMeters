-- tests/prose_waivers.lua — what the kit's US-English gate MUST NOT correct here.
--
-- Read by `tests/_kit/test_prose.lua` (localization-§5). Per FILE and per WORD, never per file
-- alone: a whole-file waiver hides every OTHER British spelling in a file this repository edits
-- often. Every file below is waived for `minimis` and for nothing else, so a `colour` that lands in
-- any of them still reddens.
--
-- This addon's own spelling is `minimize` everywhere it owns the word: the header control's key,
-- its `showMinimize` setting, the `window.frame.minimized` path, the locale keys and the prose.
-- The stored keys moved in schema v16 (core/Database.lua, migrations[15]). What is left below is
-- spelling this repository does not own, in the two shapes localization-§5 sanctions.

return {
    waived = {
        -- A LIBRARY'S FIELD NAME. LibKa0s-Media-1.0 ships the header icon as
        -- `libs/LibKa0s/media/icons/minimise.tga` and catalogs it under `minimise`; NS.Icon looks
        -- it up by that key, and a respelling answers nil and draws nothing. These files name that
        -- catalog key: the control's `art` (modules/HeaderControls.lua), the Header page's
        -- `controlLabel` icon (settings/Schema.lua), and the two suites that assert the library
        -- ships the art the header draws.
        ["modules/HeaderControls.lua"] = { minimis = true },
        ["settings/Schema.lua"] = { minimis = true },
        ["tests/test_headercontrols.lua"] = { minimis = true },
        ["tests/test_mediasetup.lua"] = { minimis = true },
        -- STORED DATA MATCHED ON ITS OWN TOKEN. The v15 -> v16 step reads the two keys a player's
        -- SavedVariables file still carries under the old spelling (`minimised`, `showMinimise`)
        -- and moves them onto the US ones. It has to spell them the way the file on disk does, or
        -- the lookup never matches and every collapsed window comes back open. Its suite writes
        -- the same old keys into a fixture account to prove the move.
        ["core/Database.lua"] = { minimis = true },
        ["tests/test_migrations.lua"] = { minimis = true },
    },
}
