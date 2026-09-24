-- tests/test_window_header_sort.lua — modules/Window_Header.lua: sorting from
-- the column headers, and the sort-arrow ladder.
--
-- Peeled from tests/test_window_header.lua (layout-§1) along the seam its
-- disposition named. Which header wears the arrow, which way it points, what a
-- click on a header does to the sort (in and out of combat), and the three rungs
-- of the arrow ladder — the collection's own art, then the Blizzard atlas, then
-- an ASCII character. An arrow assertion that fails on one rung may be
-- perfectly correct on another; read which rung the case forced.
--
-- What stays in tests/test_window_header.lua: the title strip, the header line,
-- the segment menu, the column headers' labels, fonts and colors, minimize, and
-- the create-once/dress cases for the column-header place() closure.
--
-- THE FIXTURE IS DUPLICATED, DELIBERATELY, as it is in tests/test_window_header.lua
-- (see that file's header for the reasoning).

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse
local assertNil   = T.assertNil

local CURRENT = 1

local ALPHA = "Player-1-0000000A"
local BETA  = "Player-1-0000000B"

local GROUP = {
    { guid = ALPHA, name = "Alpha", class = "PALADIN", role = "TANK"    },
    { guid = BETA,  name = "Beta",  class = "PRIEST",  role = "HEALER"  },
}

local function src(guid, total, opts)
    opts = opts or {}
    return {
        sourceGUID      = guid,
        name            = opts.name or guid,
        classFilename   = opts.class or "MAGE",
        totalAmount     = total,
        amountPerSecond = opts.rate or 1,
    }
end

--- A loaded instance, a group, a session, and ONE live window instance whose
--- config has been made unconditionally visible and locked.
---
--- Locked matters: an unlocked window implies preview mode (a player
--- positioning a window at a target dummy needs a full grid), and preview data
--- never touches the provider — which would make every case below vacuous.
local function scene(opts)
    opts = opts or {}
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks

    mocks.setGroup(GROUP)
    NS.Roster.Refresh()
    mocks.setSession(CURRENT, "*", {
        combatSources = opts.sources or { src(ALPHA, 100), src(BETA, 50) },
        maxAmount     = 100,
        totalAmount   = 150,
    })
    mocks.setSessionDuration(CURRENT, 212)
    if opts.restricted then mocks.setRestricted(true) end

    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked  = true
    cfg.visibility    = { dungeon = true, raid = true, arena = true,
                          battleground = true, world = true,
                          hideWhenSolo = false, hideInVehicle = false }
    cfg.data.sortMode = opts.sortMode or "provider"
    -- The shipped default is Overall; these fixtures seed the CURRENT session,
    -- so the window is pointed at it explicitly rather than every case having to
    -- seed two sessions to assert one thing.
    cfg.data.sessionType = CURRENT
    if opts.configure then opts.configure(cfg) end

    local window = NS.Window.New(cfg)
    window:RefreshVisibility()
    return inst, window, cfg
end

-- ---------------------------------------------------------------------------
-- Sorting from the column headers
-- ---------------------------------------------------------------------------

test("The sort column shows an arrow and the others do not", function()
    local _, window, cfg = scene{ sortMode = "value" }
    cfg.data.sortColumn = "DamageDone"
    window:ApplyColumnHeaders()

    -- Texture where the client has the atlas, ASCII where it does not — the
    -- marker is that ONE of them is drawn.
    local function marked(button)
        return button.arrowTex:IsShown() or button.arrow:IsShown()
    end

    local damage = window.columnHeaders[2]
    assertEqual(damage.mmKey, "DamageDone")
    assertTrue(marked(damage))
    assertFalse(marked(window.columnHeaders[3]),
        "only the column the rows are actually ordered by is marked")
end)

test("The arrow flips with the direction", function()
    local _, window, cfg = scene{ sortMode = "value" }
    cfg.data.sortColumn = "DamageDone"

    -- A GLYPH, not a texture. The first version used
    -- `Interface\\Buttons\\UI-SortArrow-Up/-Down`, which do not exist — and a
    -- texture that fails to load is silent, so the column simply had no arrow and
    -- there was nothing to read.
    -- red under: SetTexture on a path that does not resolve.
    -- The shipped arrow points DOWN; ascending is the same texture flipped, which
    -- is one SetTexCoord rather than a second asset to go missing.
    --
    -- Covers the arrowTex's texture AND atlas along with the ASCII glyph and its
    -- coord, because which of those three rungs answers depends on what is
    -- registered in the environment the test runs in — the top mark rung wins
    -- here, and it differs by TEXTURE rather than by flipping a coord.
    local function arrowState(button)
        return tostring(button.arrow:GetText()) .. "/" ..
            tostring(button.arrowTex.__texture) .. "/" ..
            tostring(button.arrowTex.__atlas) .. "/" ..
            table.concat({ button.arrowTex:GetTexCoord() }, ",")
    end

    cfg.data.sortAscending = false
    window:ApplyColumnHeaders()
    local down = arrowState(window.columnHeaders[2])

    cfg.data.sortAscending = true
    window:ApplyColumnHeaders()
    assertFalse(arrowState(window.columnHeaders[2]) == down,
        "ascending and descending must not draw the same arrow")
end)

test("The sort arrow prefers the collection's own art over the Blizzard atlas", function()
    -- The ladder's top rung. Red under: a build that still reaches straight for
    -- `auctionhouse-ui-sortarrow` while `sort-down.tga` sits unused in the payload.
    local inst, window, cfg = scene{ sortMode = "value" }
    cfg.data.sortColumn = "DamageDone"
    window:ApplyColumnHeaders()

    local marked = window.columnHeaders[2]
    assertEqual(marked.arrowTex.__texture, inst.NS.Icon("sort-down"),
        "the descending arrow is the shipped mark, not an atlas")
    assertTrue(marked.arrowTex:IsShown(), "and it is the rung actually drawn")
end)

test("The sort arrow's two directions are two assets, never one flipped", function()
    -- The atlas rung flips one texture with SetTexCoord because it has only one.
    -- The mark rung has both, so a flip here would draw an upside-down glyph that
    -- happens to look right and breaks the moment the art is redrawn.
    local inst, window, cfg = scene{ sortMode = "value" }
    cfg.data.sortColumn = "DamageDone"

    cfg.data.sortAscending = false
    window:ApplyColumnHeaders()
    local down = window.columnHeaders[2].arrowTex.__texture

    cfg.data.sortAscending = true
    window:ApplyColumnHeaders()
    local up = window.columnHeaders[2].arrowTex.__texture

    assertEqual(down, inst.NS.Icon("sort-down"))
    assertEqual(up, inst.NS.Icon("sort-up"))
    assertFalse(down == up, "ascending and descending are distinct assets")
end)

test("The sort arrow falls to the Blizzard atlas with no LibKa0s art", function()
    -- The rung below. Red under: a top rung that concatenates a nil path, or one
    -- that shows an empty texture rather than standing aside for the atlas.
    local inst, window, cfg = scene{ sortMode = "value" }
    cfg.data.sortColumn = "DamageDone"
    local realIcon = inst.NS.Icon
    inst.NS.Icon = function() return nil end

    window:ApplyColumnHeaders()
    local marked = window.columnHeaders[2]
    assertTrue(marked.arrowTex:IsShown() or marked.arrow:IsShown(),
        "the column still says which way it is sorted")
    -- The atlas rung legitimately leaves __texture nil (SetAtlas clears it, per
    -- the mock's "a texture is either a file or an atlas, never both") — so the
    -- failure this guards is arrowTex shown with NEITHER a texture NOR an atlas,
    -- not the atlas rung's ordinary shape.
    assertFalse(marked.arrowTex:IsShown() and marked.arrowTex.__texture == nil
        and marked.arrowTex.__atlas == nil,
        "and never shows a texture it failed to resolve")

    inst.NS.Icon = realIcon
end)

test("Clicking a header sorts by it; clicking again reverses", function()
    local _, window, cfg = scene{ sortMode = "provider" }

    assertTrue(window:SortByColumn("Interrupts"))
    assertEqual(cfg.data.sortColumn, "Interrupts")
    assertEqual(cfg.data.sortMode, "value", "picking a column implies ordering by its values")
    assertEqual(cfg.data.sortAscending, false, "largest first on the first click")

    assertTrue(window:SortByColumn("Interrupts"))
    assertEqual(cfg.data.sortAscending, true, "the second click reverses")

    assertTrue(window:SortByColumn("DamageDone"))
    assertEqual(cfg.data.sortColumn, "DamageDone")
    assertEqual(cfg.data.sortAscending, false,
        "a DIFFERENT column starts descending rather than inheriting the flip")
end)

test("Clicking a header drops the frozen sort order", function()
    -- The freeze is a snapshot of the OLD sort and would be reapplied over the
    -- new one for the rest of the pull, so the click would appear to do nothing.
    -- red under: removing the WipeCache("Aggregator") call.
    local inst, window = scene{ sortMode = "value" }
    local frozen = inst.NS.State.Cache("Aggregator")
    frozen[window.id] = { "Player-1-0000000A" }

    window:SortByColumn("Interrupts")
    assertNil(inst.NS.State.Cache("Aggregator")[window.id])
end)

test("A STAT header is honored in combat: the column it ranks by is a choice", function()
    -- The refusal used to cover every header, and it was too wide. Picking a
    -- different stat mid-pull compares NOTHING: modules/Aggregator.lua builds the
    -- whole mid-pull row list out of `sortColumn`'s own combatSources, so
    -- changing which column that is re-ranks the grid by the engine's own
    -- ordering for the new stat. Refusing it was the whole of "sorting does
    -- nothing in combat" (issue #14).
    -- red under: reinstating the blanket IsRestricted guard in SortByColumn.
    local inst, window, cfg = scene{ sortMode = "value", restricted = true }
    cfg.data.sortColumn = "DamageDone"

    local said = {}
    inst.NS.Print = function(msg) said[#said + 1] = msg end

    assertTrue(window:SortByColumn("Interrupts"))
    assertEqual(cfg.data.sortColumn, "Interrupts", "the grid re-ranks by the new column")
    assertEqual(#said, 0, "nothing was refused, so there is nothing to explain")
end)

test("A stat header REVERSES in combat too, because reversing compares nothing", function()
    -- The direction reaches modules/Aggregator.lua, which applies it by turning
    -- the engine's order back to front — a permutation, legal on secrets.
    local _, window, cfg = scene{ sortMode = "value", restricted = true }
    cfg.data.sortColumn    = "DamageDone"
    cfg.data.sortAscending = false

    assertTrue(window:SortByColumn("DamageDone"))
    assertEqual(cfg.data.sortAscending, true, "the second click reverses, pull or no pull")
end)

test("The Player header sorts by PLAYER, ascending first", function()
    -- It used to toggle between `roster` and `value` — a reasonable thing for
    -- some header to do, and not what a header labeled "Player" says. A-Z is
    -- what a player means by "sort by name", so the first click ascends and the
    -- second reverses, exactly like a stat column.
    -- red under: toggling sortMode between roster and value.
    local _, window, cfg = scene{ sortMode = "value" }

    assertTrue(window:SortByColumn("name"))
    assertEqual(cfg.data.sortMode, "name")
    assertEqual(cfg.data.sortAscending, true, "A-Z first")

    assertTrue(window:SortByColumn("name"))
    assertEqual(cfg.data.sortMode, "name", "still by name")
    assertEqual(cfg.data.sortAscending, false, "and the second click reverses it")
end)

test("The Player header is the ONE that still refuses while restricted", function()
    -- Ordering by name compares a ConditionalSecret, which raises mid-pull, and
    -- unlike a stat column there is no engine ranking to fall back on: `name`
    -- mode mid-pull would silently draw the damage order under an arrow pointing
    -- at the Player column. Refusing with a message beats that.
    local inst, window, cfg = scene{ sortMode = "value", restricted = true }
    local said = {}
    inst.NS.Print = function(msg) said[#said + 1] = msg end

    assertFalse(window:SortByColumn("name"))
    assertEqual(cfg.data.sortMode, "value", "the click changed nothing")
    assertEqual(#said, 1, "the player is owed the reason")
end)

test("Mid-pull the arrow sits on the column the rows are ACTUALLY ordered by", function()
    -- `name` mode survives into a pull when the restriction starts after the
    -- click. The order then comes from the sort COLUMN, and leaving the arrow on
    -- the Player header makes the grid state a lie rather than a limitation
    -- (issue #14).
    -- red under: `sortKey = (data.sortMode == "name") and "name" or data.sortColumn`
    -- with no identity-mode branch.
    local inst, window, cfg = scene{ sortMode = "value" }
    window:SortByColumn("name")
    cfg.data.sortColumn = "DamageDone"

    inst.mocks.setRestricted(true)
    window:Refresh()
    window:ApplyColumnHeaders()

    local byKey = {}
    for _, button in ipairs(window.columnHeaders or {}) do byKey[button.mmKey] = button end
    local function marked(button)
        return button ~= nil and (button.arrow:IsShown() or button.arrowTex:IsShown())
    end

    assertFalse(marked(byKey["name"]),
        "nothing is ordered by name mid-pull, so the Player header must not claim it is")
    assertTrue(marked(byKey["DamageDone"]),
        "the engine ranked these rows by Damage, and the header has to say so")
end)

test("The sort arrow moves to the Player header in name mode", function()
    -- The name column was the one header that could be sorted by and never said
    -- so, because the arrow was placed from `sortColumn` alone.
    local _, window, cfg = scene{ sortMode = "value" }
    window:SortByColumn("name")
    window:ApplyColumnHeaders()

    local nameButton
    for _, button in ipairs(window.columnHeaders or {}) do
        if button.mmKey == "name" then nameButton = button end
    end
    assertTrue(nameButton ~= nil, "the Player header must exist as a button")
    assertTrue(nameButton.arrow:IsShown() or nameButton.arrowTex:IsShown(),
        "the header the order came from has to carry the arrow")
    assertEqual(cfg.data.sortMode, "name")
end)

-- ---------------------------------------------------------------------------
-- The arrow ladder's placement and its two lower rungs (issue #43)
-- ---------------------------------------------------------------------------

test("The sort arrow follows the LABEL, rather than sitting at a fixed offset", function()
    -- Placed at the label's own measured width plus three, so a long header and a
    -- short one both get an arrow tucked against the text. The measurement is of a
    -- FontString this window owns that has never held a value — rule R3 is about
    -- cells that have.
    -- red under: a dress helper that anchors the arrow to the button's RIGHT edge,
    -- which puts it over the next column's numbers on a narrow grid.
    local _, window, cfg = scene{ sortMode = "value" }
    cfg.data.sortColumn = "DamageDone"
    window:ApplyColumnHeaders()

    local damage = window.columnHeaders[2]
    assertTrue(damage.arrowTex:IsShown(), "the fixture must reach the texture rung")
    local point, relativeTo, relativePoint, x = damage.arrowTex:GetPoint(1)
    assertEqual(point, "LEFT")
    assertEqual(relativePoint, "LEFT")
    assertTrue(relativeTo == damage.text, "the arrow hangs off the label, not the button")
    assertEqual(x, damage.text:GetStringWidth() + 3)
end)

test("The atlas rung flips ONE texture with SetTexCoord, and only for ascending", function()
    -- `auctionhouse-ui-sortarrow` points down as shipped, so the ascending form is
    -- the same asset flipped vertically — one SetTexCoord rather than a second
    -- asset to go missing, which is how the first two attempts at this art failed.
    -- red under: a dress helper that sets the coord once and leaves it, so the
    -- arrow keeps whichever direction it was last drawn in.
    local inst, window, cfg = scene{ sortMode = "value" }
    cfg.data.sortColumn = "DamageDone"
    local realIcon = inst.NS.Icon
    inst.NS.Icon = function() return nil end   -- stand the shipped art down

    cfg.data.sortAscending = false
    window:ApplyColumnHeaders()
    local damage = window.columnHeaders[2]
    assertEqual(damage.arrowTex:GetAtlas(), "auctionhouse-ui-sortarrow")
    local a, b, c, d = damage.arrowTex:GetTexCoord()
    assertEqual(a, 0); assertEqual(b, 1); assertEqual(c, 0); assertEqual(d, 1)

    cfg.data.sortAscending = true
    window:ApplyColumnHeaders()
    a, b, c, d = damage.arrowTex:GetTexCoord()
    assertEqual(a, 0); assertEqual(b, 1)
    assertEqual(c, 1, "ascending is the shipped arrow turned upside down")
    assertEqual(d, 0)

    inst.NS.Icon = realIcon
end)

test("With no art and no atlas the arrow is an ASCII character, and a legible one", function()
    -- The bottom rung, and it is NOT a placeholder: `v` and `^` are what this
    -- draws on a client where nothing else resolves. The two failures before it
    -- were a texture path that did not exist (silent) and a Unicode glyph the game
    -- font lacks (a box) — both named at authoring time and never asked about.
    -- red under: a dress helper that leaves the FontString empty, or one that
    -- shows the texture and the glyph at once.
    local inst, window, cfg = scene{ sortMode = "value" }
    cfg.data.sortColumn = "DamageDone"
    inst.NS.Icon = function() return nil end
    inst.mocks.setAtlases({})

    cfg.data.sortAscending = false
    window:ApplyColumnHeaders()
    local damage = window.columnHeaders[2]
    assertTrue(damage.arrow:IsShown(), "the ASCII rung has to draw when the two above cannot")
    assertFalse(damage.arrowTex:IsShown(), "and never both at once")
    assertEqual(damage.arrow:GetText(), "v")

    cfg.data.sortAscending = true
    window:ApplyColumnHeaders()
    assertEqual(damage.arrow:GetText(), "^")

    -- The glyph is text on this rung, so it takes the strip's font and shadow
    -- rather than being left fontless — which is the error that once took the
    -- whole addon down at BuildFrame.
    local font, size = damage.arrow:GetFont()
    assertTrue(font ~= nil and size ~= nil, "the fallback glyph was never given a font")
end)
