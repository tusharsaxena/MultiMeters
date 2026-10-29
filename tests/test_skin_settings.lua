-- tests/test_skin_settings.lua — the settings widgets this addon acquires itself, painted for its
-- skin (core/SkinSetup.lua's NS.SkinPaintAce / NS.SkinPaintAceTree, the rollout's MM-04).
--
-- The library paints its own pages, tabs and rows for the owner. What this file pins is what the
-- library cannot see: the AceGUI widgets this addon creates itself (the Windows page's action
-- dropdown and name box, the Columns page's block slots and boundary rule), the AceConfigDialog
-- tree on the Profiles page (acquired from AceGUI past the owner proxy), and the column blocks'
-- label colors, which are the skin's accent and disabled text (Ka0s Default's gold and 0.5 gray,
-- pinned in tests/test_columnblocks.lua). Without the library both helpers paint nothing.
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "MultiMeters"

--- Run `fn(seen)` with NS.SkinPaintAce recording each widget it is handed, by type.
local function recordingPaint(NS, fn)
    local real = NS.SkinPaintAce
    local seen = {}
    NS.SkinPaintAce = function(w)
        seen[#seen + 1] = w
        return real(w)
    end
    local ok, err = pcall(fn, seen)
    NS.SkinPaintAce = real
    if not ok then error(err, 0) end
end

local function typesOf(list)
    local out = {}
    for _, w in ipairs(list) do out[w.type or "?"] = (out[w.type or "?"] or 0) + 1 end
    return out
end

local function panelFor(NS, key)
    local ctx = NS.Helpers.__panelFor(key)
    assertTrue(ctx ~= nil, "no panel registered for the '" .. key .. "' page")
    return ctx
end

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

test("Skin settings: the Profiles page paints the tree AceConfigDialog drew, after each Open", function()
    -- red under: dropping NS.SkinPaintAceTree from settings/Profiles.lua's renderer, or calling it
    -- before AceConfigDialog:Open (it would paint an empty container).
    local inst = T.load{}
    local NS = inst.NS
    local ACD = inst.mocks.__libs["AceConfigDialog-3.0"]
    local real = NS.SkinPaintAceTree
    local calls = {}
    NS.SkinPaintAceTree = function(container)
        calls[#calls + 1] = { container = container, opens = ACD.__opens or 0 }
        return real(container)
    end
    local ok, err = pcall(function()
        local ctx = panelFor(NS, "profiles")
        ctx.panel:Hide()
        ctx.panel:Show()
        assertTrue(#calls >= 1, "the Profiles renderer painted nothing")
        local last = calls[#calls]
        assertTrue(rawequal(last.container, ACD.__lastOpen.container), "it painted the container Open filled")
        assertTrue(last.opens >= 1, "it painted before AceConfigDialog:Open drew the tree")
    end)
    NS.SkinPaintAceTree = real
    if not ok then error(err, 0) end
end)

test("Skin settings: the Windows page paints its own dropdowns and the window-name box", function()
    -- red under: dropping NS.SkinPaintAce from H.ActionDropdown or renderNameBox (settings/Windows.lua).
    local inst = T.load{}
    local NS = inst.NS
    recordingPaint(NS, function(seen)
        local ctx = panelFor(NS, "windows")
        ctx.panel:Hide()
        ctx.panel:Show()
        assertTrue(NS.Helpers.SelectSection("windows"), "the Windows page lists no windows entry")
        local types = typesOf(seen)
        assertTrue((types.Dropdown or 0) >= 2, "the action dropdowns were not painted")
        assertTrue((types.EditBox or 0) >= 1, "the window-name box was not painted")
    end)
end)

--- The Columns page's block list, rendered as settings/Columns.lua renders it.
local ITEMS = {
    { key = "a", label = "Alpha", enabled = true },
    { key = "b", label = "Bravo", enabled = false },
}

local function renderBlocks(NS)
    local ctx = NS.Helpers.CreatePanel("MultiMetersSkinBlocksPanel", "Blocks", {})
    if NS.CancelReorder then NS.CancelReorder(ctx) end
    NS.Helpers.ClearScroll(ctx)
    return NS.ReorderableBlocks(ctx, { items = ITEMS, onToggle = function() end, onMove = function() end })
end

test("Skin settings: the column blocks paint their slots and boundary rule", function()
    -- red under: dropping NS.SkinPaintAce from drawBlock or addBoundaryRule (settings/ColumnBlocks.lua).
    local inst = T.load{}
    local NS = inst.NS
    recordingPaint(NS, function(seen)
        renderBlocks(NS)
        local types = typesOf(seen)
        assertEqual(types.SimpleGroup, 2, "one painted slot per block")
        assertEqual(types.Heading, 1, "the boundary rule is painted")
    end)
end)

test("Skin settings: under another skin the column-block labels take its accent and disabled text", function()
    -- Ka0s Default's gold and gray are pinned in tests/test_columnblocks.lua.
    -- red under: the literal 1, 0.82, 0 / 0.5 gray back in applyBlock.
    local inst = T.load{}
    local NS = inst.NS
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    Skin:SetChoice(OWNER, "ka0s", "ember")
    local blocks = renderBlocks(NS)
    for i, token in ipairs({ "text.accent", "text.disabled" }) do
        local want = { NS.Skin.Color(token) }
        local got = { blocks[i].mmLabel:GetTextColor() }
        for c = 1, 3 do
            assertTrue(near(got[c], want[c]), ("block %d channel %d is %s, want %s (%s)"):format(
                i, c, tostring(got[c]), tostring(want[c]), token))
        end
    end
end)

test("Skin settings: degraded, PaintAce and PaintAceTree paint nothing and raise nothing", function()
    local inst = T.load{ libFiles = {} }
    local NS = inst.NS
    assertEqual(inst.mocks.LibStub("LibKa0s-Skin-1.0", true), nil, "the library is not absent")
    local w = inst.mocks.__libs["AceGUI-3.0"]:Create("SimpleGroup")
    assertEqual(NS.SkinPaintAce(w), false, "PaintAce is a no-op")
    assertEqual(NS.SkinPaintAceTree(w), 0, "PaintAceTree paints nothing")
end)
