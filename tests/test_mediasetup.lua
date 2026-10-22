-- tests/test_mediasetup.lua — core/MediaSetup.lua, the LibKa0s-Media-1.0 seam.
--
-- THE CASE THAT EARNS THIS FILE is the catalog cross-check. Every icon this addon
-- draws is named as a plain string in modules/HeaderControls.lua and resolved
-- against a catalog that now lives in ANOTHER REPO. If the library renames a mark,
-- or this addon asks for one it never shipped, the answer is nil, the ladder walks
-- down to an atlas nobody has confirmed, and the control quietly stops being the
-- icon it was — with every suite green, because a texture that does not load draws
-- nothing and raises nothing. That failure has already happened twice here, which
-- is why the ladder exists at all; this is the first version of it that can be
-- caught out of game.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertNil   = T.assertNil

local VENDORED = "Interface\\AddOns\\MultiMeters\\libs\\LibKa0s\\media\\"

-- ---------------------------------------------------------------------------
-- The seam
-- ---------------------------------------------------------------------------

test("MediaSetup: NS.Icon answers the vendored path, extensionless", function()
    -- Extensionless is not a preference: this addon's header art has failed
    -- silently twice, and its surviving note says a path carrying `.tga` is one
    -- of the two spellings that draws nothing. The client appends it.
    local inst = T.load()
    assertEqual(inst.NS.Icon("settings"), VENDORED .. "icons\\settings")
end)

test("MediaSetup: an icon the library does not ship answers nil", function()
    -- nil is a value the ladder can branch on. A plausible path to a texture
    -- that is not there is a control that is simply absent, forever, silently.
    local inst = T.load()
    assertNil(inst.NS.Icon("nosuchicon"))
end)

test("MediaSetup: NS.MediaFont answers the vendored face", function()
    local inst = T.load()
    assertEqual(inst.NS.MediaFont("JetBrains Mono"),
        VENDORED .. "fonts\\JetBrainsMono-Regular.ttf")
    assertNil(inst.NS.MediaFont("Comic Sans"))
end)

test("MediaSetup: the font this addon names is the face the library registers", function()
    -- Two names for one thing, in two repos: Constants.FONT_MONO_NAME is what
    -- every default stores, and the library's FONTS is what gets registered with
    -- LibSharedMedia. A profile naming a key nobody registered silently renders
    -- in Blizzard's fallback face, which is the exact outcome shipping a
    -- monospace font was meant to prevent.
    local inst = T.load()
    local Media = inst.mocks.LibStub("LibKa0s-Media-1.0", true)
    assertTrue(Media ~= nil, "the vendored library did not load")
    assertTrue(Media.FONTS[inst.NS.Constants.FONT_MONO_NAME] ~= nil,
        "FONT_MONO_NAME is '" .. tostring(inst.NS.Constants.FONT_MONO_NAME)
        .. "', which the library's FONTS does not carry")
    assertEqual(inst.NS.Constants.FONT_MONO,
        inst.NS.MediaFont(inst.NS.Constants.FONT_MONO_NAME))
end)

-- ---------------------------------------------------------------------------
-- The catalog, against what this addon actually asks for
-- ---------------------------------------------------------------------------

--- The `LibKa0s icons:` declaration in CLAUDE.md, parsed by the kit's one parser
--- (tests/_kit/vendor_sync.lua). Never a second parser here: the prune and the vendor gate read
--- the line through the same function, so this suite cannot disagree with what shipped.
local function declaredIcons()
    local VendorSync = dofile((T.root or ".") .. "/tests/_kit/vendor_sync.lua")
    local fh = assert(io.open((T.root or ".") .. "/CLAUDE.md", "rb"))
    local doc = fh:read("*a")
    fh:close()
    local decl, err = VendorSync.iconDeclaration(doc)
    assertTrue(decl ~= nil, "CLAUDE.md carries no readable `LibKa0s icons:` line: " .. tostring(err))
    local set = {}
    for _, name in ipairs(decl.names or {}) do set[name] = true end
    return decl, set
end

test("MediaSetup: every icon this addon draws is declared and ships", function()
    -- The names are strings in this addon and the catalog is in another repo; since LibKa0s
    -- v1.75.0 the build also ships ONLY the declared subset. A drawn name missing from the
    -- declaration still resolves to a path through NS.Icon, and then draws blank in game.
    -- red under: dropping a drawn name from the LibKa0s icons: line, or a prune that removed its file
    local inst = T.load()
    local _, declared = declaredIcons()
    local root = (T.root or ".") .. "/libs/LibKa0s/media/icons/"

    -- Every draw site, both halves of every two-state control (only one is drawn at a time, and
    -- a test that took the default state would miss the other), the library-drawn names for the
    -- surfaces this addon wires (close: Core.MakeCloseButton through NS.MakeCloseButton, the
    -- debug console, PerfPanel and W.CopyWindow; copy and clear: the debug console's title bar),
    -- and the host-passed info mark (W.TestStrip art; OptionsIdList's help mark).
    for _, name in ipairs({
        "close", "minimise", "expand", "lock", "unlock",          -- modules/HeaderControls.lua
        "settings", "segment", "reset", "export",                 -- HeaderControls, Schema labels
        "sort-up", "sort-down",                                   -- modules/Window_Header.lua
        "chevron-down", "spreadsheet", "chat",                    -- modules/Export_Modal.lua
        "copy", "clear",                                          -- library-drawn, DebugLog
        "info",                                                   -- host-passed, TestStrip/IdList
    }) do
        assertTrue(declared[name] == true,
            "this addon draws '" .. name .. "', which the CLAUDE.md `LibKa0s icons:` line omits")
        assertTrue(inst.NS.Icon(name) ~= nil, "NS.Icon answered nil for " .. name)
        local fh = io.open(root .. name .. ".tga", "rb")
        assertTrue(fh ~= nil, "libs/LibKa0s/media/icons/" .. name .. ".tga is not vendored")
        if fh then fh:close() end
    end
end)

test("MediaSetup: every name the declaration lists has a file in the vendored copy", function()
    -- This checks the COPY against the declaration: a prune or a packaging step that dropped a
    -- declared file leaves a line naming art this build does not carry. That UNdeclared files do
    -- not ship is tests/test_vendor_sync.lua's job (the kit gates declared == shipped), so this
    -- suite does not repeat it.
    local decl = declaredIcons()
    local root = (T.root or ".") .. "/libs/LibKa0s/media/icons/"
    local missing = {}
    for _, name in ipairs(decl.names or {}) do
        local fh = io.open(root .. name .. ".tga", "rb")
        if fh then fh:close() else missing[#missing + 1] = name end
    end
    assertEqual(table.concat(missing, ", "), "")
end)

-- ---------------------------------------------------------------------------
-- Degraded
-- ---------------------------------------------------------------------------

test("MediaSetup: with no library there is no art, and that is not an error", function()
    -- The art is INSIDE the payload that is missing, so a degraded install has
    -- none of it. NS.Icon answering nil is what sends the header down its ladder
    -- to the atlas and ASCII rungs, which exist for exactly this.
    local inst = T.load{ libFiles = {} }
    assertNil(inst.NS.Icon("settings"))
    assertNil(inst.NS.MediaFont("JetBrains Mono"))
end)
