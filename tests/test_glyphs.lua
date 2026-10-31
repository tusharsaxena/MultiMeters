-- tests/test_glyphs.lua — the display-glyph guard over this addon's own Lua (LibKa0s v1.82.0, kit
-- revision 45's tests/_kit/glyphs.lua; MM-02 of Ka0sAddonsCommonTasks
-- docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-19).
--
-- Ten skins draw this addon's text in a dozen faces, and a character one of them lacks is a box in
-- that skin only. So every string literal in a tracked .lua file outside libs/ and tests/ carries
-- only characters every shipped face draws (the kit's safe set, read from their cmaps). The
-- addon's non-ASCII display characters are the em dash, the middle dot, the right single
-- quotation mark (U+2019) and the single right-pointing angle quotation mark (U+203A), all in the
-- set; the one arrow (core/Database.lua's profile-copy line) is a debug
-- call, which the kit skips because the console draws in mono. At adoption the guard found no
-- hits, so nothing carries a `glyph:` marker.

local T = _G.MULTIMETERS_TEST
local test = T.test

test("glyphs: display strings use only characters every shipped skin face draws", function()
    T.assertDisplayGlyphs{ label = "MultiMeters" }
end)
