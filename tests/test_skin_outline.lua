-- tests/test_skin_outline.lua — the font outline (LibKa0s v1.82.0, Skin minor 9; MM-01 of
-- Ka0sAddonsCommonTasks docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, ruling D-06): stored as skin.outline
-- ("hud", the default since v1.83.0, "all", "off"), written only through the skin write seam (NS.WriteSkinChoice's
-- `media.outline`), and applied with Skin:SetOutline at load, on every profile event and on the row's
-- own write. The reference is LibKa0sSkinTester's tests/test_skin_outline.lua.
--
-- EACH CASE ON ITS OWN INSTANCE: the applied outline is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "MultiMeters"

local function scene()
    local inst = T.load{}
    return inst, inst.NS, inst.mocks.LibStub("LibKa0s-Skin-1.0")
end

local function rowAt(NS, path)
    for _, row in ipairs(NS.Schema) do
        if row.path == path then return row end
    end
    return nil
end

test("Skin outline: a fresh profile stores HUD text only, the library's default, and wears it", function()
    local _, NS, Skin = scene()
    assertEqual(NS.db.profile.skin.outline, "hud")
    assertEqual(NS.defaults.profile.skin.outline, Skin.OUTLINE_DEFAULT)
    assertEqual(Skin:GetOutline(OWNER), "hud")
end)

test("Skin outline: the schema row offers the library's three modes, in its order, skip-render", function()
    local _, NS, Skin = scene()
    local row = rowAt(NS, "skin.outline")
    assertTrue(row ~= nil, "a skin.outline row")
    assertTrue(row.skipRender == true, "the Skin tab draws it")
    assertEqual(row.group, NS.SKIN_TAB, "in the Skin tab's group")
    assertEqual(table.concat(row.sorting, ","), table.concat(Skin.OUTLINE_MODES, ","))
    for _, mode in ipairs(Skin.OUTLINE_MODES) do
        assertTrue(row.values[mode] ~= nil, mode .. " has no label")
    end
end)

test("Skin outline: the write seam stores media.outline, and leaves it alone when it is nil", function()
    -- red under: WriteSkinChoice dropping media.outline (the Skin tab's Font outline and the copy
    -- would move the look and never store it).
    local _, NS = scene()
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "hud" })
    assertEqual(NS.db.profile.skin.outline, "hud")
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false })
    assertEqual(NS.db.profile.skin.outline, "hud", "a media without outline leaves it")
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "off" })
    assertEqual(NS.db.profile.skin.outline, "off")
end)

test("Skin outline: another addon's copy reaches the store through WriteChoice", function()
    local _, NS, Skin = scene()
    Skin:WriteChoice(OWNER, "ka0s", "ember", nil, { font = false, texture = false, outline = "off" })
    assertEqual(NS.db.profile.skin.outline, "off")
end)

test("Skin outline: /mm set applies the mode live, its own half only", function()
    local _, NS, Skin = scene()
    NS.Slash:OnSlash("set skin.outline all")
    assertEqual(NS.db.profile.skin.outline, "all")
    assertEqual(Skin:GetOutline(OWNER), "all")
    assertEqual(NS.Skin.Token("font.outline"), "OUTLINE", "All text outlines window text")
    NS.Slash:OnSlash("set skin.outline hud")
    assertEqual(NS.db.profile.skin.outline, "hud")
    assertEqual(Skin:GetOutline(OWNER), "hud")
    assertEqual(NS.Skin.Token("font.outline"), "", "window text loses its outline")
    assertEqual(NS.Skin.Token("hud.outline"), "OUTLINE", "the HUD keeps it")
    NS.Slash:OnSlash("set skin.outline off")
    assertEqual(NS.Skin.Token("hud.outline"), "", "Off takes both")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "the skin did not move")
end)

test("Skin outline: /mm set refuses a mode the library does not know", function()
    local _, NS, Skin = scene()
    NS.Slash:OnSlash("set skin.outline thick")
    assertEqual(NS.db.profile.skin.outline, "hud")
    assertEqual(Skin:GetOutline(OWNER), "hud")
end)

test("Skin outline: the stored mode is applied with the stored pair at load", function()
    -- red under: ApplySkinChoice's whole-pair path (OnInitialize, the profile events) not applying
    -- the stored outline.
    local _, NS, Skin = scene()
    NS.db.profile.skin.outline = "off"
    NS.ApplySkinChoice()
    assertEqual(Skin:GetOutline(OWNER), "off")
end)

test("Skin outline: a profile switch applies the incoming profile's mode, and back", function()
    local _, NS, Skin = scene()
    NS.Slash:OnSlash("set skin.outline off")
    NS.db:SetProfile("OutlineProbe")
    assertEqual(Skin:GetOutline(OWNER), "hud", "the new profile keeps the default")
    NS.db:SetProfile("Default")
    assertEqual(Skin:GetOutline(OWNER), "off", "Default's is back")
end)

test("Skin outline: without the skin engine the apply is a quiet no-op and the store still takes it", function()
    local libFiles = {}
    for _, path in ipairs(T.libFiles) do
        if not path:match("/Skin%.lua$") then libFiles[#libFiles + 1] = path end
    end
    local inst = T.load{ libFiles = libFiles }
    local NS = inst.NS
    assertEqual(NS.ApplySkinOutline(), false)
    NS.WriteSkinChoice(nil, nil, nil, { font = false, texture = false, outline = "off" })
    assertEqual(NS.db.profile.skin.outline, "off")
end)
