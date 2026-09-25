-- tests/test_launchersetup.lua — core/LauncherSetup.lua: the ONE LibDataBroker object, registered
-- twice (launcher-§1), and the Master-controls row that shows and hides its minimap half.
--
-- REPLACED tests/test_minimap.lua, which covered the hand-rolled version of the same feature. What
-- the cases assert has deliberately NOT changed much — the object is named for the addon folder,
-- it is registered against the live table, both libraries stay optional — because those are the
-- promises the player sees and the adoption must keep them. (The buttons changed at Launcher minor
-- 4: left opens the panel, right opens the options menu, launcher-§2 at standard v2.67.0.) What HAS changed is where each promise is kept: the wiring is the library's now, and
-- this file's job is to prove the descriptor this addon hands it is right, not to re-test the
-- library.
--
-- THE FOUR THINGS ONLY THIS FILE CAN SEE:
--
--   THE MENU ENTRIES. `ADDONS.md` records this addon's as Enabled · Locked · Test mode · Show
--   window, and each entry must call the SAME handler its slash verb runs, so the cases drive the
--   real verbs through the menu rather than asserting a function exists.
--
--   THE INVERSION. The row says SHOWN and LibDBIcon's key says HIDDEN, so the get/set at the
--   single write seam invert. A sign error there is invisible in a settings panel screenshot and
--   obvious to a player, which is the worst combination a gate can leave alone.
--
--   THE STORE, AND THE SURVIVAL PROPERTY, which are two things rather than one. `launcher-§3`
--   fixes the table at `db.global.minimap`, and this addon stored it under `profile` until
--   schemaVersion 15, so the cases below prove a profile switch does not move the button. That no
--   RESET moves it either is a separate property of the setting — the derivation from the scope is
--   retired at standard v2.54.0 — so both of this addon's resets are driven for real, and one of
--   them (the General page's Defaults button) did reach the row until the exemption landed.
--
--   THE DEGRADATION. Three libraries can be absent independently — LibKa0s, LibDataBroker,
--   LibDBIcon — and a host with any of them missing must lose the button and nothing else.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse
local assertNil   = T.assertNil

local ADDON = "MultiMeters"
local PATH  = "global.minimap.shown"

local function ldb(inst)  return inst.mocks.__libs["LibDataBroker-1.1"] end
local function icon(inst) return inst.mocks.__libs["LibDBIcon-1.0"] end
local function broker(inst) return ldb(inst).__objects[ADDON] end

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

test("Launcher: Register creates ONE object and registers it against the global table", function()
    local inst = T.load()
    assertEqual(inst.NS.Launcher:Register(), true)

    local object = broker(inst)
    assertTrue(object ~= nil, "the object is named for the addon FOLDER")
    -- "launcher" is the LDB type for an object whose value is a click rather than a number. A
    -- display handed "data source" promises a `text` value that updates, which this object does
    -- not have, and draws an empty value cell beside the icon forever.
    assertEqual(object.type, "launcher")
    assertEqual(type(object.OnClick), "function")
    assertEqual(type(object.OnTooltipShow), "function")

    local registration = icon(inst).objects[ADDON]
    assertTrue(registration ~= nil, "and LibDBIcon draws its button from that SAME object")
    assertTrue(registration.broker == object)
    -- LibDBIcon treats the table it is handed as its own and WRITES `minimapPos` into it, so it
    -- has to be the live table and not a copy. The descriptor passes a FUNCTION for exactly this
    -- reason: a table captured at file load is nil, and one captured early is replaced by AceDB.
    assertTrue(registration.db == inst.NS.db.global.minimap)
end)

test("Launcher: the object wears this addon's OWN logo, not a borrowed icon", function()
    local inst = T.load()
    inst.NS.Launcher:Register()
    -- launcher-§4: one file is the addon's face in three places — the AddOns list, the minimap
    -- button and a broker display — so the LDB icon is the same path `## IconTexture` names. A
    -- Blizzard path or a numeric file id here makes the addon look like something else in the one
    -- list where the player is choosing what to turn off (anti-pattern #82).
    assertEqual(broker(inst).icon, inst.NS.Constants.LOGO_128)
    assertTrue(broker(inst).icon:find("multimeters%.logo%.128%.tga") ~= nil)
end)

test("Launcher: the broker label is the BRAND NAME, in plain text", function()
    -- launcher-§1 fixes this string at `Ka0s <Name>` because a broker display prints it BESIDE THE
    -- OTHER TEN: it is the one field that decides whether the collection reads as one collection in
    -- Titan Panel or as eleven unrelated addons installed together. Across the collection's
    -- adoptions it came out three ways, and a display sorting alphabetically filed one under `A`
    -- while the rest sat under `K`.
    local inst = T.load()
    inst.NS.Launcher:Register()
    local label = broker(inst).label

    assertEqual(label, "Ka0s Multi Meters")
    -- NO ESCAPE SEQUENCE OF ANY KIND. A display that draws the string raw splatters a colored
    -- label across a list of plain-text rows; one that strips escapes mangles it instead.
    assertEqual(label:find("|c", 1, true), nil, "a color escape leaked into the broker label")
    assertEqual(label:find("|r", 1, true), nil, "a color terminator leaked into the broker label")
    assertEqual(label:find("|T", 1, true), nil, "a texture escape leaked into the broker label")
    -- AND NOT THE FOLDER NAME, which is the registration `name` LibDBIcon keys the saved position
    -- by. `MultiMeters` is an identifier; `Ka0s Multi Meters` is a name. Two fields, two jobs.
    -- The object is looked up BY the folder name above, so reaching it at all is what proves the
    -- registration still uses it; what this asserts is that the two fields did not converge.
    assertTrue(label ~= ADDON, "the label is the brand name, not the folder name")
end)

test("Launcher: the label is NOT wired to the TOC's Title, even where the two agree", function()
    -- The two strings match today, and that is a coincidence this case exists to keep harmless. A
    -- `## Title` MAY carry color escapes and one in the collection does — Ka0s Pretty Chat's is
    -- `Ka0s |cffff0000P|cffff9900r|…` — so an addon that read its label off the manifest would put
    -- that straight into a broker row (launcher-§1, anti-pattern #84). Driven by giving the mock
    -- manifest an escaped Title BEFORE any source loads: a wired label would carry it through.
    local inst = T.load{ mutate = function(m)
        m.__toc.Title = "Ka0s |cffff0000M|cffff9900M|r"
    end }
    inst.NS.Launcher:Register()

    assertEqual(broker(inst).label, "Ka0s Multi Meters")
    -- The manifest really was changed, or the assertion above proves nothing.
    assertEqual(inst.NS.Meta("Title"), "Ka0s |cffff0000M|cffff9900M|r")
end)

test("Launcher: the TOC's IconTexture names the same file the object does", function()
    local fh = assert(io.open(T.root .. "/MultiMeters.toc", "r"))
    local declared
    for line in fh:lines() do
        declared = declared or line:match("^##%s*IconTexture:%s*(.-)%s*$")
    end
    fh:close()
    assertTrue(declared ~= nil, "the TOC declares no ## IconTexture")
    -- Read off disk rather than compared to a literal, because the two are only useful to a player
    -- if they agree and only a reader of both files would ever notice they had drifted.
    assertEqual(declared, T.NS.Constants.LOGO_128:gsub("\\\\", "\\"))
end)

test("Launcher: the icon file exists, uncompressed and 32-bit", function()
    -- THE SUBTLER HALF OF anti-pattern #82. An icon in the wrong format draws nothing and raises
    -- nothing, so no other gate in this repo would report it: the panel renders, the button is
    -- registered, and the player sees an empty square. layout-§4 fixes the format at TGA image
    -- type 2 (uncompressed), 32 bpp, 128x128, and the header is 18 bytes of fixed offsets.
    local fh = assert(io.open(T.root .. "/media/logos/multimeters.logo.128.tga", "rb"),
        "media/logos/multimeters.logo.128.tga is missing — the launcher would draw nothing")
    local header = fh:read(18)
    local size = fh:seek("end")
    fh:close()

    assertEqual(#header, 18)
    assertEqual(header:byte(3), 2, "TGA image type must be 2 (uncompressed true-color), not 10 (RLE)")
    assertEqual(header:byte(17), 32, "must be 32 bpp — convert('RGBA') is what makes it so")
    assertEqual(header:byte(13) + header:byte(14) * 256, 128)
    assertEqual(header:byte(15) + header:byte(16) * 256, 128)
    -- 128 * 128 * 4 plus the header, give or take a footer: a file far off that is compressed.
    assertTrue(size >= 65536, "128x128 at 32 bpp cannot be smaller than its own pixels")
end)

test("Launcher: Register is idempotent", function()
    local inst = T.load()
    assertEqual(inst.NS.Launcher:Register(), true)
    local object = broker(inst)

    -- A host may call this from OnInitialize and again from a login handler, and LibDBIcon's
    -- Register on a name it already holds would otherwise build a second button over the first.
    assertEqual(inst.NS.Launcher:Register(), true)
    assertTrue(broker(inst) == object, "the second call builds no second object")
    assertTrue(icon(inst).objects[ADDON].broker == object)
end)

test("Launcher: IsRegistered and Object report what Register actually did", function()
    local inst = T.load{ initDB = false, options = false }
    assertFalse(inst.NS.Launcher:IsRegistered())
    assertNil(inst.NS.Launcher:Object())

    local ok = inst.NS.Launcher:Register()
    -- Called before InitDB the descriptor's `minimap` closure answers nothing, so there is nowhere
    -- to keep the button's position and the honest answer is false — but the broker object still
    -- exists, because a display can show the plugin without a minimap button.
    assertFalse(ok)
    assertFalse(inst.NS.Launcher:IsRegistered())
    assertTrue(inst.NS.Launcher:Object() ~= nil)
end)

test("Launcher: OnInitialize registers it, after the database exists", function()
    local inst = T.load()
    -- T.load() runs the lifecycle, so this is the wiring in core/MultiMeters.lua rather than a
    -- call this file made. Registering before AceDB built the store would hand LibDBIcon a table
    -- that is thrown away, and the button would go back to the default angle every login.
    assertTrue(icon(inst).objects[ADDON] ~= nil)
    assertTrue(icon(inst).objects[ADDON].db == inst.NS.db.global.minimap)
end)

-- ---------------------------------------------------------------------------
-- The buttons (Launcher minor 4, launcher-§2 at standard v2.67.0)
-- ---------------------------------------------------------------------------
--
-- LEFT-CLICK OPENS THE SETTINGS PANEL, on every addon and in either state: the rungs are retired,
-- and so is minor 2's disabled left-click refusal, because the panel is setup and is where a
-- disabled addon is turned back on. What the left button used to do here (toggle the windows) is
-- the menu's *Show window* entry now. Both are the library's; these cases pin that this addon's
-- `openSettings` reaches the one seam the `config` verb uses.

local function chatSince(inst, n)
    local lines = {}
    for i = n + 1, #inst.mocks.__chat do lines[#lines + 1] = inst.mocks.__chat[i] end
    return lines
end

test("Launcher: LEFT-click opens the settings panel, and toggles nothing", function()
    local inst = T.load{ enable = true }

    local opens, toggles = 0, 0
    inst.NS.OpenOptionsPanel = function() opens = opens + 1 end
    inst.NS.WindowManager.Toggle = function() toggles = toggles + 1 end

    broker(inst).OnClick(nil, "LeftButton")
    -- OpenOptionsPanel carries the combat refusal — the options canvas is a protected frame — so a
    -- private path from this button would be the one way to reach the panel without that guard.
    assertEqual(opens, 1)
    assertEqual(toggles, 0, "the retired rung-(a) left click still toggled the windows")
end)

test("Launcher: a LEFT-click while disabled still opens the panel, and says nothing", function()
    -- red under: a host that kept a disabled gate of its own around openSettings. The library
    -- retired the refusal (minor 4): the panel is where the addon is re-enabled.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Launcher:Register()
    assertTrue(NS.SetByPath("enabled", false))

    local opens = 0
    NS.OpenOptionsPanel = function() opens = opens + 1 end
    local n = #inst.mocks.__chat
    broker(inst).OnClick(nil, "LeftButton")

    assertEqual(opens, 1, "a disabled left click did not open the panel")
    assertEqual(#chatSince(inst, n), 0, "a left click printed a line")
end)

test("Launcher: a click on a build with no window manager does not raise", function()
    local inst = T.load()
    local saved = inst.NS.WindowManager
    inst.NS.WindowManager = nil
    inst.NS.GetModule = nil

    local okLeft = pcall(broker(inst).OnClick, nil, "LeftButton")
    local okRight = pcall(broker(inst).OnClick, nil, "RightButton")
    inst.NS.WindowManager = saved
    -- The library pcalls the handler too, so this is belt and braces: a raising handler inside the
    -- client's click dispatch is a red error box over the player's minimap.
    assertTrue(okLeft)
    assertTrue(okRight)
end)

-- ---------------------------------------------------------------------------
-- The options menu (right-click)
-- ---------------------------------------------------------------------------
--
-- ADDONS.md (standard v2.67.0) records this addon's entries as Enabled · Locked · Test mode · Show
-- window. The library draws the menu and grays it; what only this file can prove is that each
-- entry reaches THE SAME HANDLER ITS SLASH VERB RUNS, so its refusals, combat rules and chat lines
-- are the addon's own (launcher-§2). The spy cases swap the verb's own NS.COMMANDS handler and
-- watch the click arrive there; the effect cases leave the real handler in place.

--- Install the menu fake over the builder's, right-click, and answer the recorded menu.
local function openMenu(inst)
    local menu = inst.__menu or assert(loadfile(T.root .. "/tests/mock_menu.lua"))()(inst.mocks)
    inst.__menu = menu
    menu.install()
    local before = menu.opens
    broker(inst).OnClick({}, "RightButton")
    assertEqual(menu.opens, before + 1, "the right click opened no menu")
    return menu.last
end

--- Replace one slash verb's handler with a recorder and answer the calls it saw.
local function spyVerb(NS, verb)
    local calls = {}
    for _, entry in ipairs(NS.COMMANDS) do
        if entry[1] == verb then
            entry[3] = function(rest) calls[#calls + 1] = rest end
            return calls
        end
    end
    error("no /mm " .. verb .. " verb to spy on")
end

test("Launcher menu: right-click opens the four entries ADDONS.md records, in order", function()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Launcher:Register()
    local opens = 0
    NS.OpenOptionsPanel = function() opens = opens + 1 end

    local menu = openMenu(inst)
    assertEqual(menu.titles[1], "Ka0s Multi Meters", "the menu is titled with the brand label")
    assertEqual(table.concat(menu:Texts(), ","), "Enabled,Locked,Test mode,Show window")
    assertEqual(opens, 0, "a right click that found its menu does not also open the panel")
end)

test("Launcher menu: each entry calls its slash verb's own handler, once", function()
    -- red under: a toggle that re-implemented the verb (a direct WindowManager call) rather than
    -- going through NS.COMMANDS, since the spy sits on the verb's handler and nowhere else.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Launcher:Register()
    local calls = {
        disable = spyVerb(NS, "disable"),
        lock    = spyVerb(NS, "lock"),
        test    = spyVerb(NS, "test"),
        toggle  = spyVerb(NS, "toggle"),
    }

    openMenu(inst):Click("Enabled")
    openMenu(inst):Click("Locked")
    openMenu(inst):Click("Test mode")
    openMenu(inst):Click("Show window")

    for verb, seen in pairs(calls) do
        assertEqual(#seen, 1, "/mm " .. verb .. " ran " .. #seen .. " times")
        -- The bare verb: `/mm lock`, `/mm test` and `/mm toggle` with no argument are the toggles.
        assertEqual(seen[1], "", "/mm " .. verb .. " was handed an argument")
    end
end)

test("Launcher menu: Enabled writes the setting both ways, through /mm enable and /mm disable",
function()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Launcher:Register()

    assertTrue(openMenu(inst):Checked("Enabled"))
    openMenu(inst):Click("Enabled")
    assertEqual(NS.GetSetting("enabled"), false, "unticking Enabled did not disable the addon")
    assertTrue(NS.IsDisabled())

    -- Enabled stays live while disabled, or the menu could turn the addon off and never back on.
    local menu = openMenu(inst)
    assertFalse(menu:Checked("Enabled"))
    menu:Click("Enabled")
    assertEqual(NS.GetSetting("enabled"), true, "ticking Enabled did not re-enable the addon")
end)

test("Launcher menu: Locked, Test mode and Show window act and read back through the addon",
function()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Launcher:Register()
    NS.WindowManager:SetLocked(false)
    NS.State.SetTestMode(false)

    assertFalse(openMenu(inst):Checked("Locked"))
    local n = #inst.mocks.__chat
    openMenu(inst):Click("Locked")
    assertTrue(NS.WindowManager:IsLocked(), "Locked did not lock every window")
    assertTrue(openMenu(inst):Checked("Locked"), "Locked is read afresh on every open")
    -- The verb's own acknowledgment, because the verb ran: not a line the launcher wrote.
    assertTrue(inst.mocks.__chat[n + 1]:find(NS.L["Windows are locked."], 1, true) ~= nil)

    openMenu(inst):Click("Test mode")
    assertTrue(NS.State.testMode, "Test mode did not start test mode")
    assertTrue(openMenu(inst):Checked("Test mode"))
    openMenu(inst):Click("Test mode")
    assertFalse(NS.State.testMode)

    -- Show window is checked while ANY window is shown, which is the question `/mm toggle` asks
    -- before it decides to hide them all or show them all.
    local shown = NS.WindowManager:AnyShown()
    assertEqual(openMenu(inst):Checked("Show window"), shown)
    openMenu(inst):Click("Show window")
    assertEqual(NS.WindowManager:AnyShown(), not shown, "Show window did not toggle the windows")
    assertEqual(openMenu(inst):Checked("Show window"), not shown)
end)

test("Launcher menu: while disabled, everything but Enabled is grayed and inert", function()
    -- The ruling: features refuse while disabled (slash-commands-§7), so the three feature entries
    -- are grayed with the note, and a grayed entry the client dispatched anyway calls nothing.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Launcher:Register()
    assertTrue(NS.SetByPath("enabled", false))
    local calls = { lock = spyVerb(NS, "lock"), test = spyVerb(NS, "test"),
        toggle = spyVerb(NS, "toggle") }

    local menu = openMenu(inst)
    assertEqual(table.concat(menu:Texts(), ","), "Enabled,"
        .. "Locked (enable the addon first),Test mode (enable the addon first),"
        .. "Show window (enable the addon first)")
    assertTrue(menu:Find("Enabled").enabled, "Enabled must stay live while disabled")
    for _, prefix in ipairs({ "Locked", "Test mode", "Show window" }) do
        assertFalse(menu:Find(prefix).enabled, prefix .. " is not grayed while disabled")
        menu:ForceClick(prefix)
    end
    for verb, seen in pairs(calls) do
        assertEqual(#seen, 0, "a grayed entry still ran /mm " .. verb)
    end
end)

test("Launcher menu: a perf capture is not the disabled state; the entries stay live", function()
    -- isEnabled asks NS.IsDisabled, the store setEnabled writes, so the Enabled box and the setting
    -- cannot disagree. A capture's suspend is the addon's own hold, and each verb answers it in its
    -- own words: Show window runs `/mm toggle`, which prints the suspend line.
    -- red under: `isEnabled` asking NS.IsStoodDown, which unticks Enabled mid-capture.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Launcher:Register()
    NS.Perf.Suspend()

    local menu = openMenu(inst)
    local enabled = menu:Checked("Enabled")
    local live = menu:Find("Show window").enabled
    local n = #inst.mocks.__chat
    menu:Click("Show window")
    local said = inst.mocks.__chat[n + 1]
    NS.Perf.Resume()

    assertTrue(enabled, "a perf capture unticked Enabled")
    assertTrue(live, "a perf capture grayed Show window")
    local want = NS.L["Windows are suspended while a performance capture runs."]
    assertTrue(said ~= nil and said:find(want, 1, true) ~= nil, "not the suspend line: " .. tostring(said))
end)

test("Launcher menu: with no context-menu API, right-click opens the settings panel", function()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Launcher:Register()
    inst.mocks.MenuUtil = nil
    local opens = 0
    NS.OpenOptionsPanel = function() opens = opens + 1 end

    broker(inst).OnClick({}, "RightButton")
    assertEqual(opens, 1, "a client with no MenuUtil lost the panel from the right button")
end)

test("Launcher: the descriptor carries none of minor 4's retired fields", function()
    -- `onClick`, `leftClickLabel`, `disabledLine` and `slash` are ignored by the library, so no
    -- runtime case can see them; read the source instead (launcher-§5: dead configuration).
    local fh = assert(io.open(T.root .. "/core/LauncherSetup.lua", "r"))
    local src = fh:read("*a")
    fh:close()
    for _, field in ipairs({ "onClick", "leftClickLabel", "disabledLine", "slash" }) do
        assertNil(src:match("\n%s*" .. field .. "%s*="), "core/LauncherSetup.lua still passes " .. field)
    end
end)

-- ---------------------------------------------------------------------------
-- The tooltip
-- ---------------------------------------------------------------------------

-- THE TOOLTIP IS THE LIBRARY'S (Launcher minor 3, launcher-§1 at v2.66.0). It draws one shape in
-- all eleven addons, including while the addon is disabled; this addon's descriptor only answers
-- its questions. So these cases pin the ANSWERS: the version from the TOC and the two states this
-- addon really has (every window locked, test mode). The click hints are fixed since minor 4
-- (`Open settings` / `Options menu`) and pinned here only as lines of the block. They also pin that
-- nothing of the host's is appended, because a host hook drawing a title or a click hint would
-- draw a second copy of the library's (anti-pattern #89).

--- The tooltip's lines on one show, with the status colors stripped: the words are the contract,
--- and the one color (green or red around a status value) is the library's to test.
local function tooltipLines(inst)
    local lines = {}
    local tt = {
        AddLine = function(_, text) lines[#lines + 1] = (tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end,
        AddDoubleLine = function(_, left, right) lines[#lines + 1] = "DOUBLE " .. tostring(left) .. " " .. tostring(right) end,
    }
    broker(inst).OnTooltipShow(tt)
    return lines
end

test("Launcher tooltip: the full block, enabled, with nothing of the host's appended", function()
    local inst = T.load{ enable = true, mutate = function(m) m.__toc.Version = "9.8.7" end }
    local NS = inst.NS
    NS.Launcher:Register()
    NS.WindowManager:SetLocked(false)
    NS.State.SetTestMode(false)

    -- EXACTLY six lines, in this order. A seventh would be a host line, and this addon has none of
    -- its own to add: the old hook drew only a title, a version and the two click hints, which are
    -- all the library's now.
    local lines = tooltipLines(inst)
    assertEqual(table.concat(lines, "\n"), table.concat({
        "Ka0s Multi Meters  v9.8.7",
        "Enabled: Yes",
        "Locked: No",
        "Test mode: Off",
        "Left-click: Open settings",
        "Right-click: Options menu",
    }, "\n"))
end)

test("Launcher tooltip: the version is the TOC's, not the hardcoded fallback", function()
    -- red under: `version = NS.version`, which is core/Namespace.lua's resolution at file scope,
    -- or a literal. Only a manifest version neither carries tells the paths apart.
    local inst = T.load{ mutate = function(m) m.__toc.Version = "4.3.2-tt" end }
    inst.NS.Launcher:Register()
    assertEqual(tooltipLines(inst)[1], "Ka0s Multi Meters  v4.3.2-tt")
end)

test("Launcher tooltip: Locked follows every window's own lock, read on every show", function()
    -- The same accessor the Master-controls *Lock frame* row reads (WindowManager:IsLocked):
    -- ticked only while EVERY window is locked. Asked on each show, never cached.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Launcher:Register()

    NS.WindowManager:SetLocked(true)
    assertEqual(tooltipLines(inst)[3], "Locked: Yes")
    NS.WindowManager:SetLocked(false)
    assertEqual(tooltipLines(inst)[3], "Locked: No")
    assertEqual(NS.GetSetting("master.locked"), false, "the row and the tooltip read one accessor")
end)

test("Launcher tooltip: Test mode follows the session flag, read on every show", function()
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Launcher:Register()

    NS.State.SetTestMode(true)
    assertEqual(tooltipLines(inst)[4], "Test mode: On")
    NS.State.SetTestMode(false)
    assertEqual(tooltipLines(inst)[4], "Test mode: Off")
end)

test("Launcher tooltip: while disabled it still shows, with the same two hints", function()
    -- THE OWNER'S RULING: the button always answers a hover, disabled included, since that is when
    -- a player most needs to ask. Neither button is refused any more (minor 4), so the hints do not
    -- change with the state.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    NS.Launcher:Register()
    assertTrue(NS.SetByPath("enabled", false))

    local lines = tooltipLines(inst)
    assertEqual(#lines, 6)
    assertEqual(lines[2], "Enabled: No")
    assertEqual(lines[5], "Left-click: Open settings")
    assertEqual(lines[6], "Right-click: Options menu")
end)

test("Launcher: the tooltip callback never shows or clears the tooltip itself", function()
    local inst = T.load()

    -- LibDataBroker hands the object already anchored and cleared. Calling Show() here is the
    -- classic way to get a tooltip that will not go away when the cursor leaves the button.
    local called = {}
    local tt = setmetatable({}, { __index = function(_, key)
        return function() called[key] = true end
    end })
    tt.AddLine = function() end
    tt.AddDoubleLine = function() end

    broker(inst).OnTooltipShow(tt)
    assertNil(called.Show)
    assertNil(called.ClearLines)
    assertNil(called.SetOwner)
end)

test("Launcher: the tooltip callback tolerates an object it cannot write to", function()
    local inst = T.load()
    assertTrue(pcall(broker(inst).OnTooltipShow, {}),
        "a display addon with a minimal tooltip object must not break the hover")
    assertTrue(pcall(broker(inst).OnTooltipShow, nil))
end)

-- ---------------------------------------------------------------------------
-- The Master-controls row
-- ---------------------------------------------------------------------------

test("Minimap row: it is COMPOSED, stored, and named for what it shows", function()
    local row = T.NS.FindSchemaRow(PATH)
    assertTrue(row ~= nil, "the MasterControls composer emitted no minimap row")
    -- options-ui-§15/§16: the canonical set is composed and never hand-written, and this row is
    -- part of it since compose minor 7.
    assertEqual(row.composed, true)
    assertEqual(row.type, "bool")
    assertEqual(row.page, "general")
    -- STORED, not session-only. The console and Test mode are things a reload ends; a hidden
    -- minimap button is furniture the player arranged.
    assertNil(row.sessionOnly)
    -- The default is the row's OWN sense — shown — while defaults/Profile.lua ships `hide = false`.
    assertEqual(row.default, true)
    assertEqual(row.label, "Minimap button")
end)

test("Minimap row: it OPENS the fourth line and Test mode pairs beside it", function()
    -- options-ui-§15 fixes the column order as [Minimap button] [Test mode], and the reason is not
    -- tidiness: EVERY addon has a minimap button and only some have a test mode, so the
    -- always-present row takes column 1. Put the other way round, an addon with no test mode draws
    -- a hole in the first column with a lone control to its right.
    local rows, at = T.NS.Schema, nil
    for i, row in ipairs(rows) do
        if row.path == PATH then at = i break end
    end
    assertTrue(at ~= nil)
    assertEqual(rows[at].startsLine, true, "the minimap row opens its line")
    assertEqual(rows[at + 1].path, "state.testMode", "and Test mode is what shares it")
    assertNil(rows[at + 1].startsLine,
        "Test mode must pair into the second column, not claim a line of its own")
end)

test("Minimap row: get INVERTS LibDBIcon's key", function()
    local NS = T.NS
    NS.db.global.minimap.hide = false
    assertEqual(NS.GetSetting(PATH), true, "hide = false reads as SHOWN")
    NS.db.global.minimap.hide = true
    assertEqual(NS.GetSetting(PATH), false, "hide = true reads as hidden")
    NS.db.global.minimap.hide = false
end)

test("Minimap row: set inverts onto `hide` and never writes a second key", function()
    local NS = T.NS
    assertTrue(NS.SetByPath(PATH, false))
    assertEqual(NS.db.global.minimap.hide, true, "display false stores hide = true")
    assertEqual(NS.GetSetting(PATH), false, "and reads back in display terms")

    assertTrue(NS.SetByPath(PATH, true))
    assertEqual(NS.db.global.minimap.hide, false)

    -- A parallel `minimap.show` beside the library's own key would be two records of one state,
    -- free to disagree the first time the player used LibDBIcon's menu (anti-pattern #81).
    local keys = {}
    for key in pairs(NS.db.global.minimap) do keys[#keys + 1] = key end
    table.sort(keys)
    assertEqual(table.concat(keys, ","), "hide")
end)

test("Minimap row: the write MOVES the button, not just the boolean", function()
    local inst = T.load()

    assertTrue(inst.NS.SetByPath(PATH, false))
    assertEqual(icon(inst).__shown[ADDON], false, "unticking the box hides the button NOW")

    assertTrue(inst.NS.SetByPath(PATH, true))
    assertEqual(icon(inst).__shown[ADDON], true, "and ticking it shows the button again")
    -- Following at the next reload instead is the failure this asserts against: the checkbox and
    -- the minimap would disagree for the rest of the session.
end)

test("Minimap row: nothing else in the schema stores the negation of what it shows", function()
    -- The inversion used to be a generic `row.invert` flag that exactly one row ever carried. A
    -- two-line facility with one user reads as a facility; this pins that there is still one, so
    -- the next reader knows there is no second inverted row to find.
    local inverted = {}
    for _, row in ipairs(T.NS.Schema) do
        if row.invert then inverted[#inverted + 1] = row.path end
    end
    assertEqual(table.concat(inverted, ","), "", "`invert` is retired; the carve-out names its one row")
end)

test("Minimap row: `/mm reset <path>` restores it to SHOWN", function()
    local NS = T.NS
    assertTrue(NS.SetByPath(PATH, false))
    assertEqual(NS.db.global.minimap.hide, true)

    NS.ApplyDefault(NS.FindSchemaRow(PATH))
    -- The row's `default` is display terms (shown) and the seam inverts it on the way in. Getting
    -- this round trip backwards would make a reset HIDE the button.
    assertEqual(NS.db.global.minimap.hide, false)

    -- NS.ApplyDefault ITSELF is not vetoed, and that is the line the exemption below draws: a
    -- player naming this one row on purpose is the opposite of a page sweep that reached it on
    -- the way past. The veto sits on the OPTIONS descriptor's applyDefault, which `/mm reset` does
    -- not go through (settings/OptionsSetup.lua).
end)

test("Minimap row: the schema default and the shipped tree agree, through the inversion", function()
    -- NS.ValidateSchema is the gate that compares every row's `default` against
    -- defaults/Profile.lua. The minimap row is the one it has to compare as OPPOSITES, so this
    -- asserts the validator was taught about it rather than quietly skipping it.
    assertEqual(T.NS.ValidateSchema(), 0)
    assertEqual(T.NS.defaults.global.minimap.hide, false)
    assertEqual(T.NS.FindSchemaRow(PATH).default, true)
end)

-- ---------------------------------------------------------------------------
-- The store is GLOBAL, and that is the point
-- ---------------------------------------------------------------------------

test("Minimap store: the profile ships no `minimap` table any more", function()
    assertNil(T.NS.defaults.profile.minimap,
        "launcher-§3 puts LibDBIcon's table in the global store; a profile copy would be a second one")
    local minimap = T.NS.defaults.global.minimap
    assertEqual(minimap.hide, false)
    -- LibDBIcon owns the shape of this table and writes `minimapPos` into it as the player drags
    -- the button. The addon must never enumerate it or normalize keys out of it, or a dragged
    -- button snaps back on the next login.
    local keys = 0
    for _ in pairs(minimap) do keys = keys + 1 end
    assertEqual(keys, 1)
end)

test("Minimap store: switching profiles does not move the player's button", function()
    local inst = T.load()
    inst.NS.db.global.minimap.hide = true
    inst.NS.db.global.minimap.minimapPos = 217

    inst.NS.db:SetProfile("Another")
    -- A profile is how a player configures what the addon DRAWS; the ring of buttons around the
    -- minimap is furniture they arranged once. Profile-scoped, both of these would vanish on a
    -- switch made for an unrelated reason.
    assertEqual(inst.NS.db.global.minimap.hide, true)
    assertEqual(inst.NS.db.global.minimap.minimapPos, 217)
end)

-- ---------------------------------------------------------------------------
-- The button survives a reset, and that is a PROPERTY of the setting
-- ---------------------------------------------------------------------------
--
-- launcher-§3 states it rather than deriving it: whether the button is shown is a per-installation
-- display preference, in the same class as the ANGLE the player dragged it to, which LibDBIcon
-- keeps in the very same table and which no reset touches. It MUST survive BOTH of the resets this
-- addon ships, and the two cases below drive each of them for real rather than asserting where the
-- value happens to be stored — the derivation the standard retired, because "it is global, and the
-- reset is a profile reset" is not an argument a page's own Defaults button has ever heard.

test("Minimap store: Reset all settings does not un-hide a button the player hid", function()
    local inst = T.load()
    assertTrue(inst.NS.SetByPath(PATH, false))
    assertEqual(inst.NS.db.global.minimap.hide, true)

    -- THE ACT ITSELF, not the primitive underneath it: this is what MULTIMETERS_RESET_ALL's
    -- OnAccept and `/mm resetall` both run (settings/General.lua). It sweeps the session rows,
    -- hands the profile to AceDB and lands on the migration runner — three chances to reach a row
    -- nobody meant it to reach, which is why the case drives all three rather than db:ResetProfile.
    inst.NS.Helpers.RestoreAllDefaults()
    assertEqual(inst.NS.db.global.minimap.hide, true,
        "Reset all settings put the button back on a minimap the player had cleared")
    assertFalse(inst.NS.Launcher:IsShown(), "and the button itself came back with it")

    -- It really did reset: a case where the reset silently did nothing would pass the assertion
    -- above for the wrong reason.
    assertTrue(inst.NS.GetSetting("enabled"))

    -- And the primitive, for the same reason: db.global is AceDB's other store, and a step that
    -- reached across from a fresh profile would show up here.
    assertTrue(inst.NS.SetByPath(PATH, false))
    inst.NS.db:ResetProfile()
    assertEqual(inst.NS.db.global.minimap.hide, true)
    assertEqual(inst.NS.db.global.schemaVersion, 16,
        "the version lives in db.global, so the migrations that follow a reset are a no-op")
end)

test("Minimap store: the General page's Defaults button does not un-hide it either", function()
    -- THE ONE THAT ACTUALLY REACHED IT. The minimap row is a Master-controls row on General, and
    -- LibKa0s-Options' RestoreDefaults walks every row of the page it is given — it consults no
    -- veto, by design, because a page button resets its page. So a player who hid the button and
    -- later pressed Defaults on General to reset something else got the button back, at the
    -- library's default angle. red under: settings/OptionsSetup.lua's applyDefault exemption removed.
    local inst = T.load()
    local NSi = inst.NS

    assertTrue(NSi.SetByPath(PATH, false))
    assertTrue(NSi.SetByPath("master.scale", 1.75))

    local ctx = NSi.Helpers.__panelFor("general")
    assertTrue(ctx ~= nil, "no panel is registered for the General page")
    assertTrue(ctx.panel.defaultsOnClick ~= nil, "the General page must offer a Defaults button")
    -- The panel's OWN handler, which is what a click runs.
    ctx.panel.defaultsOnClick()

    assertEqual(NSi.db.global.minimap.hide, true,
        "the page's Defaults button un-hid the button (launcher-§3: it must not)")
    assertFalse(NSi.Launcher:IsShown())

    -- ONE ROW, NOT THE WHOLE PAGE. An exemption that accidentally made the button inert would pass
    -- the assertion above and break the button, so the case proves its neighbors still reset.
    assertEqual(NSi.GetSetting("master.scale"), NSi.FindSchemaRow("master.scale").default,
        "the exemption is one row wide; the rest of the page still resets")
end)

test("Minimap store: neither reset re-hides a button the player left shown", function()
    -- The property is symmetric: a reset may not un-hide a hidden button, and may not hide a shown
    -- one. The shipped state is SHOWN, so only the second half could ever be an accident of a
    -- carve-out written the wrong way round.
    local inst = T.load()
    assertEqual(inst.NS.db.global.minimap.hide, false)

    inst.NS.Helpers.__panelFor("general").panel.defaultsOnClick()
    assertEqual(inst.NS.db.global.minimap.hide, false)

    inst.NS.Helpers.RestoreAllDefaults()
    assertEqual(inst.NS.db.global.minimap.hide, false)
    assertTrue(inst.NS.Launcher:IsShown())
end)

-- ---------------------------------------------------------------------------
-- The migration
-- ---------------------------------------------------------------------------

test("Database v15: the profile's minimap table moves to the global store, position included", function()
    local inst = T.load()
    local db = inst.NS.db

    db.global.schemaVersion = 14
    db.global.minimap = { hide = false }
    db.profile.minimap = { hide = true, minimapPos = 123.5 }

    inst.NS:RunMigrations()

    assertEqual(db.global.schemaVersion, 16)
    assertEqual(db.global.minimap.hide, true, "the player's own answer is carried")
    -- minimapPos is the ANGLE they dragged the button to, written by LibDBIcon itself. Dropping it
    -- puts an adopted button back at the library's default position — a silent loss that reads as
    -- the adoption having broken something.
    assertEqual(db.global.minimap.minimapPos, 123.5)
    assertNil(db.profile.minimap, "and the profile key is pruned, because AceDB never removes one")
end)

test("Database v15: an account that already stored it globally keeps what it has", function()
    local inst = T.load()
    local db = inst.NS.db

    db.global.schemaVersion = 14
    db.global.minimap = { hide = true, minimapPos = 42 }
    db.profile.minimap = { hide = false, minimapPos = 300 }

    inst.NS:RunMigrations()

    assertEqual(db.global.minimap.hide, true)
    assertEqual(db.global.minimap.minimapPos, 42)
end)

test("Database v15: a profile that never placed a button leaves the shipped default", function()
    local inst = T.load()
    local db = inst.NS.db

    db.global.schemaVersion = 14
    db.global.minimap = { hide = false }
    db.profile.minimap = nil

    inst.NS:RunMigrations()

    assertEqual(db.global.schemaVersion, 16)
    assertEqual(db.global.minimap.hide, false)
end)

test("Database v15: it is idempotent", function()
    local inst = T.load()
    local db = inst.NS.db

    db.global.schemaVersion = 14
    db.profile.minimap = { hide = true }
    inst.NS:RunMigrations()
    local after = db.global.minimap.hide

    db.global.schemaVersion = 14
    inst.NS:RunMigrations()
    assertEqual(db.global.minimap.hide, after)
end)

-- ---------------------------------------------------------------------------
-- Degradation
-- ---------------------------------------------------------------------------

test("Degraded: Register answers false, quietly, when LibDataBroker is absent", function()
    local inst = T.load{ mutate = function(mocks)
        mocks.__libs["LibDataBroker-1.1"] = nil
    end }
    -- The failure mode of a missing broker library is a meter with no minimap icon, never a Lua
    -- error during OnInitialize that takes the options panel and the slash commands down with it.
    assertEqual(inst.NS.Launcher:Register(), false)
    assertFalse(inst.NS.Launcher:IsRegistered())
end)

test("Degraded: with no LibDBIcon there is still a broker plugin, and no button", function()
    local inst = T.load{ mutate = function(mocks)
        mocks.__libs["LibDBIcon-1.0"] = nil
    end }
    -- `false` is the honest answer — the section's headline surface is not there — but a display
    -- addon can still show the plugin, so the object is not thrown away with the button.
    assertEqual(inst.NS.Launcher:Register(), false)
    assertTrue(broker(inst) ~= nil)
end)

test("Degraded: a host with NEITHER broker library loads and enables without raising", function()
    local ok, inst = pcall(T.load, { enable = true, mutate = function(mocks)
        mocks.__libs["LibDataBroker-1.1"] = nil
        mocks.__libs["LibDBIcon-1.0"] = nil
    end })
    assertTrue(ok, "a stripped build must lose the button and nothing else")
    -- And the row still works: the checkbox writes a boolean into a table LibDBIcon is not there to
    -- read, which is exactly what it should do — the player's answer is kept for the install that
    -- has the library.
    assertTrue(inst.NS.SetByPath(PATH, false))
    assertEqual(inst.NS.db.global.minimap.hide, true)
end)

test("Degraded: with LibKa0s absent the seam stubs every member the addon calls", function()
    local inst = T.load{ libFiles = {} }
    local Lb = inst.NS.Launcher
    assertTrue(Lb ~= nil, "core/LauncherSetup.lua must publish NS.Launcher on both paths")
    for _, member in ipairs({ "Register", "IsRegistered", "Object", "IsShown", "SetShown" }) do
        assertEqual(type(Lb[member]), "function", "the stub omits " .. member)
    end
    assertEqual(Lb:Register(), false)
    assertFalse(Lb:IsRegistered())
    assertNil(Lb:Object())
end)

test("Degraded: with LibKa0s absent the stub still answers from the STORE", function()
    local inst = T.load{ libFiles = {} }
    -- Answering `true` because nothing contradicted it would tell a checkbox something untrue. The
    -- boolean is the host's own either way; what is lost is the button.
    inst.NS.db.global.minimap.hide = true
    assertFalse(inst.NS.Launcher:IsShown())

    assertEqual(inst.NS.Launcher:SetShown(true), false, "and it is honest that no button moved")
    assertEqual(inst.NS.db.global.minimap.hide, false)
end)

test("Degraded: core/LauncherSetup.lua passes the silent flag to LibStub", function()
    -- LibKa0s and both broker libraries are OptionalDeps. A non-silent LibStub call on a stripped
    -- build raises at load, before OnInitialize has a chance to degrade.
    local fh = assert(io.open(T.root .. "/core/LauncherSetup.lua", "r"))
    local n, offenders = 0, {}
    for line in fh:lines() do
        n = n + 1
        if line:find("LibStub%(") and not line:find(",%s*true%s*%)") then
            offenders[#offenders + 1] = n .. ": " .. line
        end
    end
    fh:close()
    assertEqual(table.concat(offenders, "\n"), "")
end)
