-- tests/test_menu_selected.lua — a menu's selected row always reads apart from its plain rows
-- (FB2-MM-01; Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH/R2_SMOKE_FEEDBACK.md, decision
-- D3, then the owner's ruling of 2026-11-24 on round 2, FB2-MM-02; LibKa0s v1.113.0, WidgetsDropdown
-- minor 4).
--
-- The owner, 2026-11-24: "make the current selected always be a different color than the other
-- texts - e.g. gold in ka0s default ... Check this for all addons that have a similar pattern".
-- THE AUDIT. This addon marks a selected entry in two menus, both the library's shared menu, and
-- builds no menu or picker list of its own and paints no row color of its own:
--   * the meter window's segment menu (modules/Window_Header.lua, OpenSkinnedSegmentMenu): a
--     W.ContextMenu whose shown segment is a ticked `radio` row (`selected` / `isActive`);
--   * the Export modal's Metric and Channel dropdowns (modules/Export_Modal.lua): W.Dropdown.
-- Neither passes a value color (`opt.color`), so the selected row's color is the library's
-- W.SelectedColor(owner) alone. The settings panel's dropdowns are AceGUI's (the schema's value
-- rows, and settings/Windows.lua's Source window and Settings to copy, which SetValue the current
-- pick): AceGUI marks the picked item with its check, and the library's SkinAce paints every
-- pull-out item's text, so their selected color is the library's to set, not this addon's
-- (FB2-MM-REV). Without the library the segment menu is
-- the client's MenuUtil menu, which this addon does not paint. These cases walk every shipped
-- skin. The owner ruled on round 2 (WoW Forever's tan accent kept for a selection: the issue "has
-- not been fixed"; of the gold, "leave it as gold"): a selected row is Ka0s Default's gold in every
-- skin, the skin's own `menu.textSel` standing in only where the gold sits too near its `menu.text`,
-- which none of the shipped skins does, so every walked skin is held to the gold.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function rgb(r, g, b) return ("%.3f,%.3f,%.3f"):format(r, g, b) end
local GOLD = rgb(1, 0.82, 0)   -- Ka0s Default's gold, the selection in every shipped skin

--- Run `open` with CreateFrame watched; answer the shared menu, the first unnamed Frame parented
--- straight to UIParent (every dropdown and W.ContextMenu opens it; the modal and the window are
--- named or hang off something else).
local function captureMenu(inst, open)
    local m, saved, menu = inst.mocks, inst.mocks.CreateFrame, nil
    m.CreateFrame = function(ftype, name, parent, ...)
        local f = saved(ftype, name, parent, ...)
        if not menu and ftype == "Frame" and name == nil and parent == m.UIParent then menu = f end
        return f
    end
    local ok, err = pcall(open)
    m.CreateFrame = saved
    assertTrue(ok, "opening the menu raised: " .. tostring(err))
    assertTrue(menu ~= nil and type(menu.buttons) == "table", "the shared menu was built")
    return menu
end

--- The text color of the shown menu row whose label carries `label`, as "r,g,b".
local function rowColor(menu, label)
    for _, b in ipairs(menu.buttons) do
        local text = b.fs and b.fs:GetText()
        if b:IsShown() and type(text) == "string" and text:find(label, 1, true) then
            return rgb(b.fs:GetTextColor())
        end
    end
    return nil
end

local function skinKeys(inst)
    local Skin, out = inst.mocks.LibStub("LibKa0s-Skin-1.0"), {}
    for _, def in ipairs(Skin:Skins()) do out[#out + 1] = def.key end
    return Skin, out
end

--- For every shipped skin: open the menu, and hold its selected row to W.SelectedColor, to Ka0s
--- Default's gold, and apart from its plain row.
local function walkSkins(inst, open, selectedLabel, plainLabel)
    local NS = inst.NS
    local W = inst.mocks.LibStub("LibKa0s-Widgets-1.0")
    local Skin, keys = skinKeys(inst)
    assertTrue(#keys >= 9, "every shipped skin walked, got " .. #keys)
    local menu
    for _, key in ipairs(keys) do
        Skin:SetChoice(NS.name, "ka0s", key)
        if menu then open() else menu = captureMenu(inst, open) end
        local sel, plain = rowColor(menu, selectedLabel), rowColor(menu, plainLabel)
        assertTrue(sel ~= nil and plain ~= nil, key .. ": both rows are shown")
        assertEqual(sel, rgb(W.SelectedColor(NS.name)), key .. ": the selected row is the library's selected color")
        assertEqual(sel, GOLD, key .. ": the selected row is Ka0s Default's gold")
        assertTrue(sel ~= plain, key .. ": the selected row reads apart from a plain row (" .. sel .. ")")
        W.CloseMenu()
    end
    Skin:SetChoice(NS.name, "ka0s", "ka0s")
    return Skin
end

test("Menu selected: the segment menu's shown segment reads apart in every skin (D3)", function()
    local inst = T.load()
    local NS, L = inst.NS, inst.NS.L
    inst.mocks.setAvailableSessions{ { sessionID = 4, name = "Bribed Guard", durationSeconds = 22 } }
    local cfg = NS.Database.GetWindows()[1]
    cfg.data.sessionType = NS.Constants.SESSION_TYPE.Current
    local window = NS.Window.New(cfg)
    assertEqual(NS.Database.PinnedSegment(cfg.data), nil, "no pin: Current is the shown entry")
    walkSkins(inst, function() window:OpenSegmentMenu() end, L["Current"], L["Overall"])
end)

test("Menu selected: Azeroth's and WoW Forever's segment menus mark the shown segment in gold (FB2-MM-02)",
function()
    local inst = T.load()
    local NS, L = inst.NS, inst.NS.L
    inst.mocks.setAvailableSessions{}
    local cfg = NS.Database.GetWindows()[1]
    cfg.data.sessionType = NS.Constants.SESSION_TYPE.Overall
    local window = NS.Window.New(cfg)
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    local W = inst.mocks.LibStub("LibKa0s-Widgets-1.0")
    local menu
    -- Azeroth: its own gold accent sits too near its parchment; WoW Forever: the default skin on
    -- Forever, whose tan accent #C9A07A round 2 kept and the owner ruled out.
    for _, key in ipairs({ "azeroth", "forever" }) do
        Skin:SetChoice(NS.name, "ka0s", key)
        if menu then window:OpenSegmentMenu() else menu = captureMenu(inst, function() window:OpenSegmentMenu() end) end
        assertEqual(rowColor(menu, L["Overall"]), GOLD, key .. ": the selection is Ka0s Default's gold")
        assertEqual(rgb(W.SelectedColor(NS.name)), GOLD, key .. ": W.SelectedColor answers the gold")
        W.CloseMenu()
    end
    Skin:SetChoice(NS.name, "ka0s", "ka0s")
end)

test("Menu selected: the Export modal's Metric dropdown marks the stored metric apart in every skin (D3)",
function()
    local inst = T.load()
    local NS = inst.NS
    local current, plain = NS.Export.ResolveMetric(), nil
    local selLabel
    for _, stat in ipairs(NS.Constants.STATS) do
        if stat.key == current then selLabel = stat.label elseif not plain then plain = stat.label end
    end
    assertTrue(selLabel ~= nil and plain ~= nil, "a stored metric and another to compare it with")
    local modal = NS.Export.Open({})
    assertTrue(type(modal) == "table", "the modal opened")
    walkSkins(inst, function() modal.metricDD:__fire("OnClick") end, selLabel, plain)
end)
