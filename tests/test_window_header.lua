-- tests/test_window_header.lua — modules/Window_Header.lua: the title strip,
-- the column headers and the sort hand-off, and the segment selector.
--
-- Peeled out of tests/test_window.lua alongside the module it mirrors. This is
-- the band across the top of a window and everything the player clicks in it:
-- the padlock and the gear, the title text and its two colour modes, the
-- hairline divider, the header LINE that says which fight is on screen, the
-- per-column header buttons and the arrow that marks the sort, the segment
-- picker, the notice text, and the minimise collapse that takes the whole body
-- away and leaves this strip behind.
--
-- Two things here are worth knowing before reading a failure. First, the sort
-- arrow has THREE rungs — the collection's own art, then the Blizzard atlas,
-- then an ASCII character — and cases exist for each, so an arrow assertion that
-- fails on one rung may be perfectly correct on another; read which rung the
-- case forced. Second, the column-header `place()` closure creates once and
-- dresses on every apply, and the cases at the bottom of this file pin that
-- boundary specifically: a header button is re-pointed and re-labelled, never
-- rebuilt, and a column that goes away is hidden rather than destroyed.
--
-- Rule R3 still binds every case here — no geometry is read back off a cell that
-- has held a meter value — but the cases that PROVE it by poisoning the getters
-- live in tests/test_window.lua with the render loop they drive.
--
-- THE FIXTURE IS DUPLICATED, DELIBERATELY. `scene()` and the group data under it
-- are copied from tests/test_window.lua rather than shared: ~50 lines are
-- cheaper to keep in three places than a fourth file every suite loads and
-- nobody proves anything about.


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

test("The header carries a lock and a gear, and the padlock shows the state", function()
    local inst, window, cfg = scene()

    -- The controls live on window.controls now, built by
    -- modules/HeaderControls.lua. Same widgets, same clicks, one owner.
    assertTrue(window.controls.lock ~= nil)
    assertTrue(window.controls.settings ~= nil)
    assertTrue(window.controls.lock:GetScript("OnClick") ~= nil)
    assertTrue(window.controls.settings:GetScript("OnClick") ~= nil)

    -- The padlock's art is whatever resolved: our own texture where the payload
    -- is there, an atlas where the client has one, an ASCII character where it
    -- has neither. Whatever the mechanism, the two states must not look
    -- identical — that is the only thing that makes it a state indicator.
    --
    -- THE TEXTURE PATH IS IN THE FINGERPRINT, and it was not. The collection
    -- ships BOTH halves of this one now (`lock` and `unlock`), so on the art rung
    -- the state is carried by which file is drawn; the atlas rung, which still
    -- has one asset, carries it by desaturating. Alpha carried it too until the
    -- dimming came out — brightness is not a state signal, and an unlocked
    -- padlock at 0.45 read as a half-broken icon beside six full-strength ones.
    -- Reading only the atlas and the alpha meant this case was measuring the one
    -- mechanism the shipped install does not use.
    local function art(button)
        return table.concat({
            tostring(button.tex:GetTexture()),
            tostring(button.tex:GetAtlas()),
            tostring(button.tex.__desaturated),
            tostring(button.glyph:GetText()),
        }, "/")
    end

    cfg.frame.locked = true
    inst.NS.HeaderControls:Apply(window)
    local lockedArt = art(window.controls.lock)

    cfg.frame.locked = false
    inst.NS.HeaderControls:Apply(window)
    assertFalse(art(window.controls.lock) == lockedArt,
        "an open padlock and a closed one must not draw the same art")
end)

test("The padlock toggles THIS window only", function()
    -- Per-window, unlike `/mm lock`, which moves every window at once. A player
    -- clicking a button attached to one window means that one.
    local inst, window, cfg = scene()
    assertTrue(inst.NS.WindowManager:Create("Second"))
    local other = inst.NS.Database.GetWindows()[2]
    other.frame.locked = true
    cfg.frame.locked = true

    window.controls.lock:_run("OnClick")
    assertEqual(cfg.frame.locked, false)
    assertEqual(other.frame.locked, true, "the other window did not move")
end)

test("The title-bar divider can be switched off, and does not move the title row", function()
    -- The one piece of the window's chrome a player can hide. What matters as much
    -- as the hiding is that NOTHING ELSE MOVES: TitleRowTop centres the title row
    -- against the DIVIDER_INSET constant, not against this texture, so a hidden
    -- line leaves the title, the session line and the control strip exactly where
    -- they were. A layout that measured the divider would shift all three.
    -- red under: gating the title row on the divider, or hiding it by height 0.
    local _, window, cfg = scene()

    window:ApplyConfig()
    local rowTop = window:TitleRowTop(cfg.header.height)
    assertTrue(window.frame.divider:IsShown(), "the divider ships drawn")

    cfg.header.divider = false
    window:ApplyConfig()
    assertFalse(window.frame.divider:IsShown(), "the divider ignored its setting")
    assertEqual(window:TitleRowTop(cfg.header.height), rowTop,
        "hiding the divider moved the title row")
end)

test("The divider's thickness is a setting", function()
    local _, window, cfg = scene()
    cfg.header.dividerThickness = 4
    window:ApplyConfig()
    assertEqual(window.frame.divider:GetHeight(), 4)
end)

test("The divider's SKIN mode writes no colour at all, so a re-skin still reaches it", function()
    -- The shipped mode, and the reason it is a mode rather than a stored colour.
    -- `skin` does not resolve SKIN.divider and write it -- it writes NOTHING, so
    -- whatever ApplySkin put on the texture stands. That is how standalone-windows
    -- survives a per-window colour picker: the shared value is never copied into
    -- this repo and never into a profile, so changing it upstream still lands here.
    -- red under: seeding the swatch from SKIN.divider, or "skin" resolving to a
    -- literal — either one freezes today's skin into every saved profile.
    local inst, window, cfg = scene()
    local skin = inst.mocks.LibStub("LibKa0s-Core-1.0", true).SKIN

    cfg.header.dividerColorMode = "skin"
    window:ApplyConfig()
    local drawn = window.frame.divider.__colorTexture
    assertEqual(drawn[1], skin.divider[1], "skin mode did not leave the library's tint standing")
    assertEqual(drawn[4], skin.divider[4], "the divider's alpha was dropped")

    -- And the profile holds no copy of it, which is the half that would rot.
    assertFalse(inst.NS.GetSetting("window.header.dividerColor").r == skin.divider[1],
        "the custom swatch was seeded from the skin")
end)

test("The divider takes a custom colour and a class colour, keeping the configured alpha", function()
    -- A class colour has no alpha of its own, so it takes the swatch's — the same
    -- rule the cell text keeps, where the configured alpha survives every mode.
    -- red under: a class divider drawn at 1.0 while the swatch says 0.4.
    local inst, window, cfg = scene()

    cfg.header.dividerColor     = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }
    cfg.header.dividerColorMode = "custom"
    window:ApplyConfig()
    local c = window.frame.divider.__colorTexture
    assertEqual(c[1], 0.1)
    assertEqual(c[4], 0.4)

    cfg.header.dividerColorMode = "class"
    window:ApplyConfig()
    local k = window.frame.divider.__colorTexture
    local cr = inst.NS.PlayerClassRGB()
    assertEqual(k[1], cr, "the divider ignored the class colour")
    assertEqual(k[4], 0.4, "the configured alpha did not survive the mode change")
end)

-- ---------------------------------------------------------------------------
-- The header line
-- ---------------------------------------------------------------------------

test("The header folds its parts with `..`, and survives a secret piece", function()
    -- Two of the pieces this line can carry come out of NS.Format having been
    -- built from a secret, and a formatted secret is itself secret. `..` is legal
    -- on one; table.concat is the one string operation that RAISES on one -- it
    -- is literally the probe core/CoreSetup.lua uses to detect a secret at all.
    -- red under: joining the line rather than folding it.
    local _, window = scene{ restricted = true, preview = true }
    window:ApplyConfig()
    window:Refresh()

    local line = window.sessionText:GetText()
    assertEqual(type(line), "string")
    assertTrue(#line > 0, "the line said nothing at all")
end)

test("The header line says which fight, and stays out of the way otherwise", function()
    -- The DURATION and the TOTAL were checkboxes and are still gone: the duration
    -- belongs to the segment the picker already names, and the total is a figure
    -- the column under it holds per player.
    --
    -- The segment NAME came back. It was dropped on the argument that it repeated
    -- the window's own title -- true of a window still called "Overall", and false
    -- the moment the player pins a stored segment or renames the window.
    -- red under: putting the duration or the total back into UpdateHeaderText.
    local _, window = scene()
    window:ApplyConfig()
    window:Refresh()

    local line = window.sessionText:GetText() or ""
    assertEqual(line, "Current", "the header names the fight this window is showing")
end)

test("Show segment off leaves the header line blank again", function()
    -- The whole point of it being a setting: a player who keeps the strip tidy
    -- gets the header back the way it was before the line returned.
    -- red under: UpdateHeaderText adding the label unconditionally.
    local _, window, cfg = scene()
    cfg.frame.showSegmentText = false
    window:ApplyConfig()
    window:Refresh()

    assertEqual(window.sessionText:GetText() or "", "",
        "an unticked Show segment must leave nothing behind")
end)

test("The segment name sits LAST, nearest the picker that changes it", function()
    -- The line is right-aligned and the picker is the control immediately to its
    -- right, so the two read as one thing rather than as a caption and an
    -- unrelated button. A notice that fires at the same time goes to its left.
    -- red under: adding the label before RestrictedNotice.
    local _, window = scene{ restricted = true, sortMode = "value" }
    window:ApplyConfig()
    window:Refresh()

    local line = window.sessionText:GetText() or ""
    local notice = line:find("restricted", 1, true)
    local label  = line:find("Current", 1, true)
    assertTrue(notice ~= nil, "got: " .. line)
    assertTrue(label ~= nil, "got: " .. line)
    assertTrue(notice < label, "the segment name must be the rightmost piece, got: " .. line)
end)

test("The header says the grid was built the restricted way", function()
    -- REPLACES THE FROZEN-SORT NOTICE. The rows have not stopped reordering —
    -- they are the engine's own live ranking. What the player is owed is why a
    -- CELL can be empty: mid-pull the other columns are matched to those rows by
    -- class and spec, because `sourceGUID` is secret and cannot be joined on.
    local _, window = scene{ restricted = true, sortMode = "value" }
    window:ApplyConfig()
    window:Refresh()

    assertTrue(window.sessionText:GetText():find("restricted", 1, true) ~= nil,
        "got: " .. tostring(window.sessionText:GetText()))
end)

test("The header names AMBIGUITY when two rows cannot be told apart", function()
    -- Two players of one class AND one spec: the identity key cannot separate
    -- them, so their secondary cells are left empty rather than filled with a
    -- number that might be the other one's. That is a visible absence and it
    -- needs a reason on the line.
    local _, window, cfg = scene{
        restricted = true,
        sources = { src(ALPHA, 100, { class = "MAGE" }), src(BETA, 50, { class = "MAGE" }) },
    }
    cfg.header.showSessionName = true
    window:ApplyConfig()
    window:Refresh()

    assertTrue(window.sessionText:GetText():find("told apart", 1, true) ~= nil,
        "got: " .. tostring(window.sessionText:GetText()))
end)

test("The header line reads 'Test' while placeholder data is on screen", function()
    local inst, window = scene()
    inst.NS.State.SetTestMode(true)
    window:Refresh()
    assertTrue(window.sessionText:GetText():find("Test", 1, true) ~= nil)
end)

test("Test data never reaches the provider", function()
    local inst, window = scene()
    inst.NS.State.SetTestMode(true)
    inst.mocks.resetMeterCalls()
    window:Refresh()

    assertEqual(inst.mocks.__meter.calls.GetCombatSessionFromType or 0, 0)
    assertTrue(#window.pool.active > 2, "and the grid is full, which is the point")
end)

test("UNLOCKING A WINDOW NO LONGER TURNS TEST DATA ON", function()
    -- The first bug reported against the addon. A fresh install ships unlocked,
    -- so the very first login showed placeholder rows, and no amount of
    -- unchecking "Preview mode" cleared them — the lock was forcing it back on.
    -- Three controls each did two things; each now does one.
    -- red under: `return State.testMode or not self.locked`.
    local inst, window, cfg = scene()
    cfg.frame.locked = false
    window:ApplyConfig()

    assertFalse(window:IsTest(), "an unlocked window shows REAL data")
    inst.mocks.resetMeterCalls()
    window:Refresh()
    assertTrue((inst.mocks.__meter.calls.GetCombatSessionFromType or 0) > 0,
        "and therefore reads the meter")
end)

-- ---------------------------------------------------------------------------
-- The segment selector
-- ---------------------------------------------------------------------------

--- A scene whose client is holding two stored segments.
local function withSegments(opts)
    opts = opts or {}
    local inst, window, cfg = scene(opts)
    inst.mocks.setAvailableSessions{
        { sessionID = 4, name = "Bribed Guard", durationSeconds = 22 },
        { sessionID = 5, name = "Bribed Guard", durationSeconds = 17 },
    }
    return inst, window, cfg
end

test("Segment menu: stored segments first, then a divider, then Current/Overall", function()
    -- The reason to open this menu at all is almost always to look back at a
    -- fight that just ended, so the fights come first.
    local inst, window = withSegments()
    assertTrue(window:OpenSegmentMenu(), "the menu must actually open")

    local menu = inst.mocks.__lastMenu
    local kinds = {}
    for _, e in ipairs(menu.entries) do kinds[#kinds + 1] = e.kind end
    assertEqual(table.concat(kinds, ","), "title,button,button,divider,button,button")

    assertEqual(menu:Nth("button", 3).text, inst.NS.L["Current"])
    assertEqual(menu:Nth("button", 4).text, inst.NS.L["Overall"])
end)

test("Segment menu: an entry is labelled with its name AND its duration", function()
    local inst, window = withSegments()
    window:OpenSegmentMenu()
    assertEqual(inst.mocks.__lastMenu:Nth("button", 1).text, "Bribed Guard   0:22")
end)

test("Segment menu: picking a segment pins it and marks the window dirty", function()
    local inst, window, cfg = withSegments()
    window:OpenSegmentMenu()
    window.dirty = false

    inst.mocks.__lastMenu:Nth("button", 2).callback()
    assertEqual(cfg.data.sessionID, 5, "the SECOND stored segment, not the first")
    assertEqual(window.dirty, true, "a pinned segment has to redraw to take effect")
end)

test("Segment menu: picking Current CLEARS the pin", function()
    -- Picking "Current" out of a menu that is showing a stored fight means "stop
    -- showing that fight". Leaving the id set would make the choice do nothing.
    -- red under: SetSessionType writing sessionType without nil-ing sessionID.
    local inst, window, cfg = withSegments()
    window:SetSegment(4)

    window:OpenSegmentMenu()
    inst.mocks.__lastMenu:Nth("button", 3).callback()

    assertNil(cfg.data.sessionID)
    assertEqual(cfg.data.sessionType, inst.NS.Constants.SESSION_TYPE.Current)
end)

test("Segment menu: with no menu API the click is refused, not an error", function()
    local inst, window = withSegments()
    inst.mocks.MenuUtil = nil
    assertFalse(window:OpenSegmentMenu())
end)

test("Segment: a pinned segment is READ, not merely stored", function()
    -- The whole point. red under: an aggregator that ignores pass.sessionID,
    -- which would leave the header claiming a segment while the grid showed the
    -- live pull.
    local inst, window, cfg = withSegments()
    inst.mocks.setSession(4, "*", {
        combatSources = { src(ALPHA, 999) }, maxAmount = 999, totalAmount = 999,
    })
    cfg.data.sessionID = 4
    inst.mocks.resetMeterCalls()

    window:Refresh()
    assertEqual(inst.mocks.__meter.calls.GetCombatSessionFromID ~= nil, true,
        "the pinned segment was never read")
end)

test("Segment: the header names the pinned segment rather than lying `Current`", function()
    local _, window, cfg = withSegments()
    cfg.data.sessionID = 4
    assertEqual(window:SessionLabel(false), "Bribed Guard   0:22")

    cfg.data.sessionID = nil
    assertEqual(window:SessionLabel(false), "Current",
        "and with no pin it goes back to naming the session type")
end)

test("Segment: a stale pin is dropped on the next refresh", function()
    -- sessionID is persisted, so a window can come back from a reload or a meter
    -- reset still pointed at a segment the client has discarded. A stale id does
    -- not error — it silently reads an empty session, which looks like a broken
    -- addon.
    -- red under: removing the DropStaleSegment call from Refresh.
    local _, window, cfg = withSegments()
    cfg.data.sessionID = 99

    window:Refresh()
    assertNil(cfg.data.sessionID, "a segment the client no longer holds must be forgotten")
end)

test("Segment: a LIVE pin survives the staleness check", function()
    local _, window, cfg = withSegments()
    cfg.data.sessionID = 5
    window:Refresh()
    assertEqual(cfg.data.sessionID, 5)
end)

test("Segment: with no provider the pin is left alone rather than rewritten", function()
    -- No provider is a broken install, not a stale segment. Dropping the pin
    -- there would quietly rewrite the player's setting because of our load order.
    local inst, window, cfg = withSegments()
    cfg.data.sessionID = 4
    inst.NS.Provider = nil
    window:DropStaleSegment()
    assertEqual(cfg.data.sessionID, 4)
end)

test("Segment: the session line takes NO mouse", function()
    -- It used to be a 220px Button so its text could be right-justified inside
    -- it, which put an invisible click target across the middle of the header: it
    -- glowed red on hover and opened the segment menu from a patch of empty title
    -- bar. The strip's segment control is the visible route to the same menu.
    -- red under: CreateFrame("Button") with an OnClick and a highlight texture.
    local _, window = withSegments()
    assertTrue(window.sessionLine ~= nil)
    assertTrue(window.sessionLine.GetScript == nil
        or window.sessionLine:GetScript("OnClick") == nil,
        "the session line is clickable again")
    assertTrue(window.sessionLine.__highlightTexture == nil,
        "the session line still carries a hover highlight")
    -- The text still rides on it: a line positioned separately from the frame it
    -- is justified inside drifts the first time either moves.
    assertEqual(window.sessionText.__allPoints, window.sessionLine)
end)

-- ---------------------------------------------------------------------------
-- Sorting from the column headers
-- ---------------------------------------------------------------------------

test("Column headers are BUTTONS carrying the full stat label, left-aligned", function()
    -- A player reading "AVD" has to remember what it stood for. The header is
    -- read far less often than the numbers under it, so the space is worth it.
    local inst, window = scene{ configure = function(c)
        c.columns = {
            { stat = "DamageDone", enabled = true },
            { stat = "AvoidableDamageTaken", enabled = true },
        }
    end }
    local L = inst.NS.L

    local name, damage, avoidable = window.columnHeaders[1], window.columnHeaders[2],
        window.columnHeaders[3]
    assertEqual(name.text:GetText(), L["Player"])
    assertEqual(damage.text:GetText(), L["Damage"], "the full label, not DMG")
    assertEqual(avoidable.text:GetText(), L["Avoidable"],
        "the one stat whose full label does not fit a column")
    assertEqual(damage.text:GetJustifyH(), "LEFT")
    assertTrue(damage:GetScript("OnClick") ~= nil, "a header has to be clickable to sort")
end)

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

test("A STAT header is honoured in combat: the column it ranks by is a choice", function()
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
    -- some header to do, and not what a header labelled "Player" says. A-Z is
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

test("Test mode is marked in RED in the title, and clears when it is off", function()
    -- Test mode fills the grid with numbers that look exactly like real ones —
    -- that is the point of it — so the only thing between a player and reading
    -- placeholder data as their own performance is a label saying otherwise.
    -- red under: writing the title without consulting State.testMode.
    local inst, window = scene()
    assertFalse(window.frame.title:GetText():find("TEST MODE", 1, true) ~= nil)

    inst.NS.State.SetTestMode(true)
    local marked = window.frame.title:GetText()
    assertTrue(marked:find("TEST MODE", 1, true) ~= nil, "the marker must appear on the toggle")
    assertTrue(marked:find("|cffff2020", 1, true) ~= nil, "and it must be red")

    inst.NS.State.SetTestMode(false)
    assertFalse(window.frame.title:GetText():find("TEST MODE", 1, true) ~= nil)
end)

test("Building a window sets no text on a fontless FontString", function()
    -- THE BUG THAT BROKE THE LOAD. A FontString has no font until SetFont is
    -- called, and SetText on one answers `FontString:SetText(): Font not set` —
    -- at BuildFrame, which took the whole addon down before a single window
    -- existed. The harness models the client's rule now, so this case is the
    -- whole build path run under it.
    -- red under: SetText on a glyph in Attach, before the first Apply.
    local inst = T.load()
    local cfg = inst.NS.Database.GetWindows()[1]

    local ok, err = pcall(inst.NS.Window.New, cfg)
    assertTrue(ok, "building a window raised: " .. tostring(err))

    -- And the glyphs did get their text, once they had a font to draw it with.
    local window = inst.NS.Window.New(cfg)
    inst.NS.HeaderControls:Apply(window)
    -- One of the two draws, never neither: an atlas if the client has one, an
    -- ASCII character if it does not.
    assertTrue(window.controls.settings.tex:IsShown() or window.controls.settings.glyph:IsShown(),
        "the gear must draw something")
    assertTrue(window.controls.lock.tex:IsShown() or window.controls.lock.glyph:IsShown(),
        "and the padlock too")
end)

test("Header art falls back to ASCII on a client with none of the atlases", function()
    -- THE TWO FAILURES THIS GUARDS. Texture paths that do not exist draw nothing
    -- and raise nothing; Unicode glyphs the game font lacks draw a replacement
    -- box. Both were shipped, and both were invisible to every test, because the
    -- art was named at authoring time and never asked about.
    -- red under: SetAtlas / SetText with no existence check.
    local inst = T.load()
    -- Our own art goes first in the ladder, so it has to be taken away before
    -- the rung under test is reachable at all. tests/test_headercontrols.lua
    -- covers the ladder in full; this case stays because it is the one that
    -- names the two failures the ladder exists for.
    inst.mocks.setTextureLoadable(
        "Interface\\AddOns\\MultiMeters\\libs\\LibKa0s\\media\\icons\\settings", false)
    inst.mocks.setAtlases({})          -- a client with no matching atlas at all
    local window = inst.NS.Window.New(inst.NS.Database.GetWindows()[1])
    inst.NS.HeaderControls:Apply(window)

    assertFalse(window.controls.settings.tex:IsShown(), "no atlas resolved")
    assertTrue(window.controls.settings.glyph:IsShown(), "so the ASCII fallback draws")
    local text = window.controls.settings.glyph:GetText()
    assertTrue(text ~= nil and text ~= "", "and it is not empty")
end)

test("Header art prefers an atlas where the client has one", function()
    local inst = T.load()
    inst.mocks.setAtlases({ ["GM-icon-settings"] = true })
    local window = inst.NS.Window.New(inst.NS.Database.GetWindows()[1])
    inst.NS.HeaderControls:Apply(window)

    assertTrue(window.controls.settings.tex:IsShown(), "the atlas wins when it exists")
    assertFalse(window.controls.settings.glyph:IsShown())
end)

test("Column headers take their own font, not the cells'", function()
    -- They used to borrow the font PATH and size from `text` and the outline and
    -- colour from `header`, so changing the cell font silently restyled the
    -- headers and nothing could make the strip differ from the numbers beneath.
    -- red under: reading textCfg.font / textCfg.size in ApplyColumnHeaders.
    local _, window = scene{ configure = function(c)
        c.text.size = 9
        c.columnHeader.size = 21
        c.columnHeader.outline = "THICKOUTLINE"
    end }
    window:ApplyColumnHeaders()

    local _, size, flags = window.columnHeaders[1].text:GetFont()
    assertEqual(size, 21, "the header took the cell text size")
    assertEqual(flags, "THICKOUTLINE", "the header took its outline from somewhere else")
end)

test("Column headers have their own colour and background", function()
    -- The strip has never had a backdrop, so the setting is new capability and
    -- defaults transparent — an existing window must look identical.
    -- red under: tinting from header.color, or no headerBg texture at all.
    local _, window = scene{ configure = function(c)
        c.header.color = { r = 0, g = 1, b = 0, a = 1 }
        c.columnHeader.color = { r = 1, g = 0, b = 0, a = 1 }
        c.columnHeader.bgColor = { r = 0, g = 0, b = 1, a = 0.5 }
    end }
    window:ApplyColumnHeaders()

    local r, g = window.columnHeaders[1].text:GetTextColor()
    assertEqual(r, 1, "the header label took the title strip's colour")
    assertEqual(g, 0, "the header label took the title strip's colour")

    local bg = window.headerBg.__colorTexture
    assertTrue(bg ~= nil, "the header strip has no backdrop texture")
    assertEqual(bg[3], 1, "the backdrop did not take the configured colour")
end)

test("Per-statistic mode leaves the Player header white, not the sort column's colour", function()
    -- The Player column labels the NAMES, not a statistic, so there is no stat
    -- colour for it to take. It was taking one anyway: its fallback resolved
    -- through windowStat() -- the sort column -- so "Player" came out red on a
    -- damage-sorted window and changed colour whenever the sort moved.
    -- red under: `button.text:SetTextColor(hr, hg, hb, ha)` for the name column.
    local inst, window, cfg = scene{ configure = function(c)
        c.columnHeader.colorMode = "stat"
    end }
    cfg.data.sortColumn = "DamageDone"
    window:ApplyColumnHeaders()

    local byKey = {}
    for _, button in ipairs(window.columnHeaders or {}) do byKey[button.mmKey] = button end

    local nr, ng, nb = byKey["name"].text:GetTextColor()
    assertEqual(nr, 1, "the Player header must be white in per-statistic mode")
    assertEqual(ng, 1, "the Player header must be white in per-statistic mode")
    assertEqual(nb, 1, "the Player header must be white in per-statistic mode")

    -- The stat columns still take their own colours, which is the whole feature.
    local dr, dg, db = byKey["DamageDone"].text:GetTextColor()
    local want = inst.NS.Constants.STAT_COLORS["DamageDone"]
    assertEqual(dr, want[1], "the Damage header lost its own statistic colour")
    assertEqual(dg, want[2], "the Damage header lost its own statistic colour")
    assertEqual(db, want[3], "the Damage header lost its own statistic colour")
end)

test("The Player header's sort arrow is white too, in per-statistic mode", function()
    -- Sorting by name puts the arrow on the Player header, where it was drawn
    -- from the same stat-resolved fallback the label was -- so the arrow stayed
    -- red over a label that is no longer red.
    -- red under: the arrow branches reading `hr, hg, hb` instead of the
    -- per-header colour.
    local _, window = scene{ configure = function(c)
        c.columnHeader.colorMode = "stat"
    end }
    window:SortByColumn("name")
    window:ApplyColumnHeaders()

    local nameButton
    for _, button in ipairs(window.columnHeaders or {}) do
        if button.mmKey == "name" then nameButton = button end
    end
    assertTrue(nameButton ~= nil, "the Player header must exist as a button")

    local r, g, b
    if nameButton.arrowTex:IsShown() then
        local c = nameButton.arrowTex.__vertexColor
        assertTrue(c ~= nil, "the shown arrow texture was never tinted")
        r, g, b = c[1], c[2], c[3]
    else
        r, g, b = nameButton.arrow:GetTextColor()
    end
    assertEqual(r, 1, "the Player header's sort arrow must match its white label")
    assertEqual(g, 1, "the Player header's sort arrow must match its white label")
    assertEqual(b, 1, "the Player header's sort arrow must match its white label")
end)

-- ---------------------------------------------------------------------------
-- Minimise (issue #6)
-- ---------------------------------------------------------------------------
--
-- Review found this had ZERO behavioural coverage: ApplyMinimised could be made
-- a no-op and the suite stayed green, on the headline addition of the change.
-- Everything below is a property somebody would notice in game and nothing
-- offline was checking.

test("Minimise hides everything below the title bar", function()
    -- Four things hang there, not one. The body carries the rows, but the
    -- column-header strip, the notice and the grip are parented to the FRAME --
    -- so hiding the body alone leaves three of them drawn over a collapsed
    -- window.
    -- red under: hiding self.body and nothing else.
    local _, window, cfg = scene()
    cfg.frame.minimised = true
    window:ApplyConfig()

    assertEqual(window.body:IsShown(), false, "the rows are still there")
    if window.headerFrame then
        assertEqual(window.headerFrame:IsShown(), false, "the column headers are still there")
    end
    if window.grip then assertEqual(window.grip:IsShown(), false, "the grip is still there") end
end)

test("Minimise actually shrinks the window", function()
    -- Hiding the children left a full-height empty frame sitting there, which is
    -- not what "collapse to the title bar" means to anyone looking at it.
    -- red under: hiding children without changing the frame's height.
    local _, window, cfg = scene()
    window:ApplyConfig()

    -- Expanded, the visible frame takes its height by being pinned to BOTH
    -- corners of the anchor -- it is never explicitly sized, which is why its
    -- recorded height is 0 and cannot be the thing asserted on.
    local function pinnedToBottom(frame)
        for _, p in ipairs(frame.__points or {}) do
            if p.point == "BOTTOMRIGHT" then return true end
        end
        return false
    end
    assertTrue(pinnedToBottom(window.frame), "expanded, the frame spans the anchor")

    cfg.frame.minimised = true
    window:ApplyConfig()
    assertFalse(pinnedToBottom(window.frame),
        "collapsed, the frame must stop spanning the anchor")
    assertTrue((window.frame.__h or 0) > 0, "and take the title bar's height instead")

    cfg.frame.minimised = false
    window:ApplyConfig()
    assertTrue(pinnedToBottom(window.frame), "expanding re-pins it")
end)

test("Minimise leaves the STORED height alone, so expanding restores it", function()
    -- The anchor is deliberately not resized: doing so fires onSizeChanged,
    -- which writes pendingWidth/pendingHeight, and SaveSize persists whatever is
    -- pending on the next resize-stop -- so a collapsed height would leak into
    -- frame.height and the window would never come back to the size chosen.
    -- red under: collapsing by resizing self.anchor.
    local _, window, cfg = scene()
    local stored = cfg.frame.height

    cfg.frame.minimised = true
    window:ApplyConfig()
    assertEqual(cfg.frame.height, stored, "the collapse rewrote the stored height")

    cfg.frame.minimised = false
    window:ApplyConfig()
    assertEqual(cfg.frame.height, stored)
    assertEqual(window.body:IsShown(), true, "expanding did not bring the rows back")
end)

test("A collapsed window does not aggregate or render", function()
    -- THE COST CLAIM, and it needed two clauses rather than one. ShouldPoll
    -- covers the polling half of the tick; onUpdate takes an early branch on
    -- `dirty`, and every meter message sets that flag -- so without the guard in
    -- Refresh the whole aggregate-and-render ran for a hidden body all fight.
    -- red under: removing either clause.
    local inst, window, cfg = scene()
    cfg.frame.minimised = true
    window:ApplyConfig()

    local built = 0
    local realBuild = inst.NS.Aggregator.Build
    inst.NS.Aggregator.Build = function(...) built = built + 1 return realBuild(...) end

    window:MarkDirty()
    window:Refresh()
    assertEqual(window:ShouldPoll(), false, "a collapsed window still polls")
    assertEqual(built, 0, "a collapsed window still aggregated")

    inst.NS.Aggregator.Build = realBuild
end)

test("A collapsed window keeps the notice hidden", function()
    -- Refresh puts the "waiting for combat data" line back whenever there is
    -- nothing to draw, so hiding it once at collapse time was not enough.
    local _, window, cfg = scene()
    cfg.frame.minimised = true
    window:ApplyConfig()
    window:Refresh()
    assertEqual(window.notice:IsShown(), false, "the notice came back over a collapsed window")
end)

-- ---------------------------------------------------------------------------
-- The header's four text controls
-- ---------------------------------------------------------------------------

test("Header shadow reaches every line of the strip", function()
    -- The cell text has had a shadow all along and the other three surfaces had
    -- not, so a player styling a window had to discover which of the four had
    -- grown which control. All four carry the same four now.
    -- red under: setting the header font without its shadow.
    local _, window, cfg = scene()
    cfg.header.shadow = true
    window:ApplyConfig()

    assertEqual(window.frame.title.__shadow[1], 1, "the title has no shadow")
    assertEqual(window.frame.title.__shadow[2], -1)
    assertEqual(window.sessionText.__shadow[1], 1, "the session line has no shadow")

    cfg.header.shadow = false
    window:ApplyConfig()
    assertEqual(window.frame.title.__shadow[1], 0, "the shadow did not come off")
end)

test("Column header shadow is its OWN setting, not the header's", function()
    -- The two strips are separate groups precisely so they can differ; a shared
    -- shadow would undo half of that.
    -- red under: reading header.shadow for the column labels.
    local _, window, cfg = scene()
    cfg.header.shadow       = false
    cfg.columnHeader.shadow = true
    window:ApplyConfig()

    local button = window.columnHeaders and window.columnHeaders[1]
    assertTrue(button ~= nil, "no column header was built")
    assertEqual(button.text.__shadow[1], 1)
    assertEqual(window.frame.title.__shadow[1], 0,
        "the title took the column strip's shadow")
end)

test("The header's text answers TWO modes, and the custom one is the picker", function()
    -- Custom is the shipped mode, so a window that never touches the dropdown is
    -- drawn from the picker exactly as it was before there was a dropdown.
    -- red under: a default of "class", which would recolour every existing window
    -- on upgrade.
    local inst, window, cfg = scene()
    inst.mocks.RAID_CLASS_COLORS.PALADIN = { r = 0.41, g = 0.8, b = 0.94 }
    cfg.header.color    = { r = 0.2, g = 0.4, b = 0.6, a = 1 }
    cfg.data.sortColumn = "HealingDone"
    window:ApplyConfig()

    local c = window.frame.title.__textColor
    assertEqual(c[1], 0.2, "the title took something other than the picker")
    assertEqual(c[2], 0.4)
    assertEqual(c[3], 0.6)
    assertEqual(c[4], 1, "the configured alpha must survive")

    assertEqual(window.sessionText.__textColor[1], c[1],
        "the title and the session line are one header and must not differ")
end)

test("The header's text takes the CLASS colour, keeping the configured alpha", function()
    -- The title used to be the one thing on the strip that could not wear a class
    -- colour, while the controls and the divider beside it both could -- so it was
    -- the odd one out rather than the principled one. It is still the LOCAL
    -- player's class, because that is the only class a window-wide strip can mean.
    --
    -- The ALPHA comes off the swatch, the same rule every other surface keeps: a
    -- class colour carries none of its own, and inventing one would mean the
    -- opacity changed when the mode did.
    -- red under: a class title drawn at 1.0 while the swatch says 0.35, or the
    -- session line beside it disagreeing with the title.
    local inst, window, cfg = scene()
    inst.mocks.RAID_CLASS_COLORS.PALADIN = { r = 0.41, g = 0.8, b = 0.94 }
    cfg.header.color     = { r = 0.2, g = 0.4, b = 0.6, a = 0.35 }
    cfg.header.colorMode = "class"
    window:ApplyConfig()

    local c = window.frame.title.__textColor
    assertEqual(c[1], 0.41, "the title ignored the class colour")
    assertEqual(c[4], 0.35, "the configured alpha did not survive the mode")
    assertEqual(window.sessionText.__textColor[1], 0.41,
        "the session line did not follow the title into class colour")
end)

test("The header's text mode offers class and custom, and NOT per-statistic", function()
    -- The one half of the old refusal that stands. "Per statistic" could only ever
    -- paint this the SORT column's colour -- already on screen in that column's own
    -- header and in its arrow -- and the title bar is one strip over the whole
    -- window rather than a thing belonging to a column. Same argument that took
    -- the mode off the title bar's BACKGROUND.
    -- red under: widening this row to the three-mode set every cell surface answers.
    local inst = T.load()
    local row  = inst.NS.FindSchemaRow("window.header.colorMode")
    assertTrue(row ~= nil, "the title text has no colour mode row")

    local keys = {}
    for _, k in ipairs(row.sorting) do keys[#keys + 1] = k end
    table.sort(keys)
    assertEqual(table.concat(keys, ","), "class,custom")
end)

test("The header colour survives a sort change, having nothing to do with it", function()
    -- The old `stat` mode made the title bar change colour whenever the sort
    -- moved, which is a relationship the title bar does not have.
    local _, window, cfg = scene()
    cfg.header.color    = { r = 0.2, g = 0.4, b = 0.6, a = 1 }
    cfg.data.sortColumn = "HealingDone"
    window:ApplyConfig()
    local before = window.frame.title.__textColor[1]

    cfg.data.sortColumn = "DamageDone"
    window:ApplyConfig()
    assertEqual(window.frame.title.__textColor[1], before,
        "the title bar is not about the sorted column")
end)

test("The window NAME takes the header's colour", function()
    -- The title used to be left to the library's skin, so the Header text group
    -- styled every part of the strip except the one word a player thinks of as
    -- the header: font, size, outline and shadow all came from that group and
    -- only the colour did not.
    -- red under: dropping the SetTextColor from ApplyTitle, or letting ApplySkin
    -- run after it.
    local inst, window, cfg = scene()
    inst.mocks.RAID_CLASS_COLORS.PALADIN = { r = 0.41, g = 0.8, b = 0.94 }

    cfg.header.color = { r = 0.2, g = 0.4, b = 0.6, a = 1 }
    window:ApplyConfig()

    local c = window.frame.title.__textColor
    assertEqual(c[1], 0.2, "the title ignored the header colour")
    assertEqual(c[3], 0.6)
    assertEqual(c[1], window.sessionText.__textColor[1],
        "the title and the session line are one header and must not differ")
end)

test("Column header class color is the local player's too", function()
    -- The strip labels the grid rather than any row in it, so it takes the same
    -- reading the title bar does.
    -- red under: the two strips disagreeing about whose class they mean.
    local inst, window, cfg = scene()
    inst.mocks.RAID_CLASS_COLORS.PALADIN = { r = 0.41, g = 0.8, b = 0.94 }
    cfg.columnHeader.colorMode = "class"
    window:ApplyConfig()

    local button = window.columnHeaders and window.columnHeaders[1]
    assertTrue(button ~= nil, "no column header was built")
    assertEqual(button.text.__textColor[1], 0.41)
end)

test("A profile written before minimise existed is not collapsed", function()
    -- `~= false` would collapse every stored profile on upgrade, because none of
    -- them has the key at all.
    -- red under: `local down = frameCfg.minimised ~= false`.
    local _, window, cfg = scene()
    cfg.frame.minimised = nil
    window:ApplyConfig()
    assertEqual(window.body:IsShown(), true, "an upgraded profile came back collapsed")
end)

-- ---------------------------------------------------------------------------
-- The column-header place() closure, pinned for the split (issue #43)
-- ---------------------------------------------------------------------------
--
-- 133 lines and CCN 18, and the split it is headed for is create-once/dress —
-- the same seam LibKa0s' TabStrip was cut along. The cases above cover the label,
-- the colours and which header wears the arrow; these cover the create/dress
-- boundary itself, the placement, the mutually-exclusive backgrounds and the two
-- lower rungs of the arrow ladder.

test("Header buttons are created ONCE per index and re-pointed, never rebuilt", function()
    -- The invariant the split has to preserve: a settings change costs no frames.
    -- WoW never truly frees one, so a header strip that rebuilt itself on every
    -- ApplyConfig would leak a button per column per settings change, all session.
    -- red under: a `newHeaderButton` called unconditionally rather than on the miss.
    local inst, window, cfg = scene{ configure = function(c)
        c.columns = {
            { stat = "DamageDone",  enabled = true },
            { stat = "HealingDone", enabled = true },
        }
    end }

    local first = {}
    for i, button in ipairs(window.columnHeaders) do first[i] = button end
    assertTrue(#first >= 3, "the fixture needs the name column and two stat columns")

    local framesBefore = #inst.mocks.__frames
    cfg.columnHeader.size = 21
    cfg.columnHeader.colorMode = "stat"
    window:ApplyColumnHeaders()
    window:ApplyColumnHeaders()

    assertEqual(#inst.mocks.__frames, framesBefore,
        "dressing a header must not build one")
    for i, button in ipairs(first) do
        assertTrue(window.columnHeaders[i] == button, "header " .. i .. " was rebuilt")
    end
end)

test("A column that goes away HIDES its header; it does not destroy it", function()
    -- The tail loop, `#layout.columns + 2` onward. These are pooled for the life
    -- of the window like every other widget here, so turning a column off and on
    -- again has to hand back the SAME button rather than a new one.
    -- red under: a tail loop that starts at + 1 (which would hide the last live
    -- header) or one that drops the surplus on the floor.
    local _, window, cfg = scene{ configure = function(c)
        c.columns = {
            { stat = "DamageDone",  enabled = true },
            { stat = "HealingDone", enabled = true },
            { stat = "Interrupts",  enabled = true },
        }
    end }
    local third = window.columnHeaders[4]
    assertTrue(third ~= nil and third:IsShown(), "the fixture must draw three stat columns")

    cfg.columns[3].enabled = false
    window:ApplyConfig()
    assertTrue(window.columnHeaders[4] == third, "the surplus header was thrown away")
    assertFalse(third:IsShown(), "and a column that is off must not still label the grid")
    assertTrue(window.columnHeaders[3]:IsShown(), "the last LIVE header is still drawn")

    cfg.columns[3].enabled = true
    window:ApplyConfig()
    assertTrue(window.columnHeaders[4] == third, "and it comes back rather than being rebuilt")
    assertTrue(third:IsShown())
end)

test("Every header sits exactly over the column it labels, from the same layout", function()
    -- Both are read off the ONE layout table, which is what makes a header
    -- incapable of drifting from the cells under it. A dress helper handed its own
    -- copy of the arithmetic is exactly how that drift starts.
    local _, window, cfg = scene{ configure = function(c)
        c.columns = {
            { stat = "DamageDone", enabled = true },
            { stat = "Interrupts", enabled = true },
        }
    end }
    cfg.frame.width = 620
    window:ApplyConfig()
    local layout = window.layout

    local function placedAt(button)
        assertEqual(button:GetNumPoints(), 1, "a re-pointed header carries exactly one point")
        local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
        assertEqual(point, "TOPLEFT")
        assertEqual(relativePoint, "TOPLEFT")
        assertTrue(relativeTo == window.headerFrame, "headers hang off the strip, not the window")
        assertEqual(y, 0)
        return x
    end

    assertEqual(placedAt(window.columnHeaders[1]), layout.nameColumn.x)
    assertEqual(window.columnHeaders[1]:GetWidth(), layout.nameColumn.width)
    for i, col in ipairs(layout.columns) do
        local button = window.columnHeaders[i + 1]
        assertEqual(placedAt(button), col.x, "header " .. i .. " is off its column")
        assertEqual(button:GetWidth(), col.width)
        assertEqual(button:GetHeight(), layout.headerHeight)
        assertEqual(button.text:GetWidth(), col.width,
            "the label fills its column, which is what makes LEFT alignment read")
    end
end)

test("The Player header is a Button like every other, not a label with a gap beside it", function()
    -- It is the one header that labels no statistic, and it was once the one that
    -- could be sorted by without saying so. Being the same widget type as the rest
    -- is what keeps it clickable and what a split must not quietly change.
    local _, window = scene()
    local name = window.columnHeaders[1]

    assertEqual(name:GetObjectType(), "Button")
    assertEqual(name.mmKey, "name")
    assertTrue(name:GetScript("OnClick") ~= nil)
    assertTrue(name.mmWindow ~= nil, "the handler reaches its window off the button")
    assertEqual(name:GetObjectType(), window.columnHeaders[2]:GetObjectType())
end)

test("The strip background and the per-column ones are mutually exclusive, both ways", function()
    -- BOTH ARE WRITTEN EVERY PASS. A player switching modes would otherwise keep
    -- whichever they left behind, drawn underneath the one they chose — and the
    -- per-column texture is the only one that can carry a stat colour, while the
    -- strip texture is the only one that can carry a class colour.
    -- red under: a dress helper that only ever SHOWS a background.
    local inst, window, cfg = scene{ configure = function(c)
        c.columns = { { stat = "DamageDone", enabled = true } }
        c.columnHeader.bgColorMode = "stat"
        c.columnHeader.bgColor = { r = 0, g = 0, b = 1, a = 1 }
    end }
    window:ApplyColumnHeaders()

    local nameButton, damage = window.columnHeaders[1], window.columnHeaders[2]
    assertFalse(window.headerBg:IsShown(), "per-column mode stands the strip texture down")
    assertTrue(damage.bg:IsShown(), "and paints one rectangle per column instead")
    assertFalse(nameButton.bg:IsShown(),
        "the Player column is not a statistic and has no stat colour to take")

    local want = inst.NS.Constants.STAT_COLORS["DamageDone"]
    local got = damage.bg.__colorTexture
    assertTrue(got ~= nil, "the per-column texture was never given a colour")
    assertEqual(got[1], want[1])
    assertEqual(got[2], want[2])
    assertEqual(got[3], want[3])

    -- And back. This is the half that was left behind.
    cfg.columnHeader.bgColorMode = "custom"
    window:ApplyColumnHeaders()
    assertTrue(window.headerBg:IsShown(), "the strip texture must come back")
    assertFalse(damage.bg:IsShown(), "and the per-column one must go")
end)

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
