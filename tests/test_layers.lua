-- tests/test_layers.lua — where every frame this addon draws sits in the draw order
-- (frame-layering, standard v2.88.0): the one layers table in core/Constants.lua and
-- the strata, level and toplevel of each frame class in it.
--
-- THE RECORDER. The kit's opt-in frame-layer recorder (tests/_kit/mock_layers.lua)
-- is installed on a FRESH instance before any source loads, so every frame the addon
-- builds answers strata (inherited through its parents), level (parent + 1 unless set),
-- toplevel and a Raise count. This addon's own frame model (tests/mock_frame.lua)
-- seeds every frame with an explicit level 0, which would read to the recorder as a
-- level set by hand; `layered()` clears that seed so an unset level inherits, as in
-- the client.
--
-- Levels are asserted RELATIVE to the frame they are stated against, never as
-- absolute numbers, because the rule is that no level in the addon is absolute.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse

local CURRENT = 1
local ALPHA   = "Player-1-0000000A"

--- A fresh instance whose frames record their layers.
local function layered()
    return T.load{ mutate = function(m)
        local plain = m.CreateFrame
        m.CreateFrame = function(...)
            local f = plain(...)
            if type(f) == "table" then rawset(f, "__level", nil) end
            return f
        end
        dofile(T.root .. "/tests/_kit/mock_layers.lua")(m)
    end }
end

--- A layered instance with one window built and shown.
local function scene(configure)
    local inst = layered()
    local NS, mocks = inst.NS, inst.mocks
    mocks.setSession(CURRENT, "*", {
        combatSources = { { sourceGUID = ALPHA, name = "Alpha", totalAmount = 100 } },
        maxAmount = 100, totalAmount = 100,
    })
    local cfg = NS.Database.GetWindows()[1]
    cfg.data.sessionType = CURRENT
    cfg.frame.locked = false
    cfg.visibility = { dungeon = true, raid = true, arena = true, battleground = true,
                       world = true, hideWhenSolo = false, hideInVehicle = false }
    if configure then configure(cfg) end
    local window = NS.Window.New(cfg)
    window:RefreshVisibility()
    return inst, window, cfg
end

local function LAYERS(inst) return inst.NS.Constants.LAYERS end

-- ---------------------------------------------------------------------------
-- The table
-- ---------------------------------------------------------------------------

test("LAYERS: one table names the addon's strata and level bands", function()
    local inst = layered()
    local layers = LAYERS(inst)
    assertTrue(type(layers) == "table", "NS.Constants.LAYERS is missing")
    assertEqual(layers.STRATA.HUD, "MEDIUM", "a meter window's default tier")
    assertEqual(layers.STRATA.MODAL, "DIALOG", "the export modal's tier")
    local L = layers.LEVEL
    -- The order is the rule; the numbers are the reference offsets.
    assertTrue(L.CHROME < L.ROWS and L.ROWS < L.CELLS and L.CELLS < L.ROW_OVERLAY
        and L.ROW_OVERLAY < L.CONTROLS and L.CONTROLS < L.GRIP,
        "the window's bands must climb chrome < rows < cells < overlay < controls < grip")
    assertEqual(L.GRIP, 10, "mirrors LibKa0s-Core-1.0's GRIP_LEVEL, which draws the grip")
    assertEqual(L.TOOLTIP_LINE, 0, "tooltip lines share GameTooltip's level so layers interleave")
end)

test("LAYERS: no strata literal and no absolute or sibling level in the addon", function()
    -- frame-layering-§5: every SetFrameStrata and SetFrameLevel reads the table.
    -- red under: modules/Export_Modal.lua's old SetFrameStrata("DIALOG"), or
    -- HeaderControls' dragBar:GetFrameLevel() + 5.
    local files = {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        rel = rel:gsub("\\", "/")
        if rel:match("^core/") or rel:match("^modules/") or rel:match("^settings/") then
            files[#files + 1] = T.root .. "/" .. rel
        end
    end
    assertTrue(#files > 10, "the addon file list did not resolve")
    for _, path in ipairs(files) do
        local fh = assert(io.open(path, "r"))
        local n = 0
        for line in fh:lines() do
            n = n + 1
            local code = line:gsub("%-%-.*$", "")
            assertFalse(code:find('SetFrameStrata%(%s*"') ~= nil,
                path .. ":" .. n .. " sets a strata literal")
            local arg = code:match("SetFrameLevel%((.*)%)")
            if arg then
                assertTrue(arg:find("LEVEL%.") ~= nil or arg:find("LAYERS") ~= nil,
                    path .. ":" .. n .. " sets a level that names no LAYERS.LEVEL member")
            end
        end
        fh:close()
    end
end)

-- ---------------------------------------------------------------------------
-- The meter window (tiers 0 and 1)
-- ---------------------------------------------------------------------------

test("Window: the art frame takes the strata setting, is toplevel, and the anchor stays MEDIUM", function()
    local inst, window, cfg = scene()
    local S = inst.mocks.__layers
    assertEqual(S(window.frame).strata, LAYERS(inst).STRATA.HUD, "the shipped default")
    assertTrue(S(window.frame).toplevel, "peer windows must stack whole (frame-layering-§4)")
    assertEqual(S(window.anchor).strata, "MEDIUM", "the invisible anchor never takes the setting")

    cfg.frame.strata = "HIGH"
    window:ApplyConfig()
    assertEqual(S(window.frame).strata, "HIGH", "a player's pick is applied as stored")
end)

test("Window: header controls sit at frame + CONTROLS, above the drag bar", function()
    local inst, window = scene()
    local LEVEL = LAYERS(inst).LEVEL
    local base = window.frame:GetFrameLevel()
    assertEqual(window.dragBar:GetFrameLevel(), base + LEVEL.CHROME)
    for key, button in pairs(window.controls) do
        assertEqual(button:GetFrameLevel(), base + LEVEL.CONTROLS,
            key .. " is not on the window's controls band")
    end
    assertTrue(window.grip ~= nil, "no resize grip")
    assertEqual(window.grip:GetFrameLevel(), base + LEVEL.GRIP)
end)

test("Window: dragging raises the whole window and re-levels its controls and grip", function()
    -- red under: no Raise in onDragStart (the art frame takes no mouse, so toplevel
    -- alone never fires), or a raise that leaves the explicitly leveled children behind.
    local inst, window = scene()
    local LEVEL = LAYERS(inst).LEVEL
    window.dragBar:_run("OnDragStart")
    assertEqual(inst.mocks.__layers(window.frame).raised, 1, "the drag did not raise the window")

    -- Stand in for the client moving the raised window up its strata.
    window.frame:SetFrameLevel(window.frame:GetFrameLevel() + LEVEL.GRIP + 7)
    window:BringToFront()
    local base = window.frame:GetFrameLevel()
    assertEqual(window.grip:GetFrameLevel(), base + LEVEL.GRIP, "the grip fell under its window")
    assertEqual(window.controls.close:GetFrameLevel(), base + LEVEL.CONTROLS)
end)

test("Window: a header-control click raises the window it belongs to", function()
    local inst, window = scene()
    window.controls.lock:_run("OnClick")
    assertEqual(inst.mocks.__layers(window.frame).raised, 1)
end)

test("Row: the self edge and the hover wash live on a mouse-off overlay above the cells", function()
    -- red under: the two OVERLAY textures on the row frame itself, which every
    -- child cell draws over whatever the draw layer (frame-layering, MUL-S01).
    local inst, window = scene()
    local LEVEL = LAYERS(inst).LEVEL
    local row = inst.NS.Row.New(window)
    row:ApplyLayout(window.layout)

    local overlay = row.overlay
    assertTrue(overlay ~= nil, "no row overlay frame")
    assertEqual(overlay:GetParent(), row.frame)
    assertEqual(overlay:GetFrameLevel(), row.frame:GetFrameLevel() + (LEVEL.ROW_OVERLAY - LEVEL.ROWS))
    assertTrue(overlay:GetFrameLevel() > row.nameCell.frame:GetFrameLevel(),
        "the overlay must sit above the cells it marks")
    assertFalse(overlay.__mouseEnabled == true, "a mouse-live overlay steals every cell hover")
    assertEqual(row.selfHighlight.__parent, overlay, "the self edge is not on the overlay")
    assertEqual(row.mouseHighlight.__parent, overlay, "the hover wash is not on the overlay")
end)

-- ---------------------------------------------------------------------------
-- The export modal (tier 2)
-- ---------------------------------------------------------------------------

test("Export modal: DIALOG, toplevel, clamped, and raised on every open", function()
    local inst = layered()
    local modal = inst.NS.Export.Open({})
    assertTrue(type(modal) == "table", "the modal did not open")
    local s = inst.mocks.__layers(modal)
    assertEqual(s.strata, LAYERS(inst).STRATA.MODAL)
    assertTrue(s.toplevel, "the modal must come up over a Dialog-strata meter")
    assertTrue(s.clamped)
    assertEqual(s.raised, 1)
    modal:Hide()
    inst.NS.Export.Open({})
    assertEqual(inst.mocks.__layers(modal).raised, 2, "a re-open did not raise it again")
end)

-- ---------------------------------------------------------------------------
-- The strata row
-- ---------------------------------------------------------------------------

test("Frame strata row: its tooltip is the library's O.StrataTooltip over its own values", function()
    -- frame-layering-§1: the knob keeps LOW/MEDIUM/HIGH/DIALOG (CALL-04), and since
    -- it offers DIALOG its tooltip must say what DIALOG covers.
    local inst = T.load()
    local row
    for _, r in ipairs(inst.NS.Schema) do
        if r.path == "window.frame.strata" then row = r end
    end
    assertTrue(row ~= nil, "no window.frame.strata row")
    assertEqual(row.default, "MEDIUM", "the default is a setting and does not move")
    local O = inst.mocks.LibStub("LibKa0s-Options-1.0")
    local probe = {}
    O.__AttachCompose(probe, {})
    assertEqual(row.desc, probe.StrataTooltip(row.values))
    assertTrue(row.desc:find("Dialog and above", 1, true) ~= nil,
        "the DIALOG warning is missing from a row that offers DIALOG")
end)
