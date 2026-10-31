-- tests/test_skinsetup.lua — the LibKa0s-Skin-1.0 seam (core/SkinSetup.lua, skinning-§3).
--
-- What this addon owes the skin engine, and nothing the library pins itself: the owner is
-- registered under the folder name with this addon's read and write seams and its owner tokens;
-- the eight skin.* keys are addon-wide, default to Ka0s Default, and are skip-render schema rows
-- in the Skin tab's group; the tab sits after Statistic colors and before Keybindings; the
-- profile's skin is applied right after AceDB exists and on every profile event; one pick, from
-- this addon's tab or from another addon's copy, is ONE effective SetChoice (one OnLooksChanged),
-- however many store writes follow it; every library factory this addon calls is handed the
-- owner; and without the library the degraded facade answers every name the live one carries.
--
-- EACH CASE ON ITS OWN INSTANCE. A skin change is session state in the library, and the shared
-- instance is every other suite's; a fresh `T.load{}` starts on Ka0s Default and is thrown away.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "MultiMeters"

local SKIN_PATHS = {
    "skin.source", "skin.skin", "skin.ignorePanel", "skin.ignoreFonts", "skin.font",
    "skin.texture", "skin.outline", "skin.pickerSeen",
}

--- A fresh instance with a counter on this owner's OnLooksChanged.
local function scene()
    local inst = T.load{}
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    local counter = { looks = 0 }
    inst.NS.Skin.OnLooksChanged(function() counter.looks = counter.looks + 1 end)
    return inst, inst.NS, Skin, counter
end

local function rowAt(NS, path)
    for _, row in ipairs(NS.Schema) do
        if row.path == path then return row end
    end
    return nil
end

--- Show General and click the tab labeled `label`; answers the ctx and the widgets it drew.
local function openTab(inst, label)
    local NS = inst.NS
    local ctx = NS.Helpers.__panelFor("general")
    assertTrue(ctx ~= nil, "no General page")
    ctx.panel:Hide()
    ctx.panel:Show()
    local tab
    for _, kid in ipairs(ctx.__tabKids or {}) do
        if kid.__ka0sTabTipLabel == label then tab = kid end
    end
    assertTrue(tab ~= nil, "the General page draws no " .. label .. " tab")
    local created = inst.mocks.__libs["AceGUI-3.0"].__created
    ctx.__tabKids[1]:__fire("OnClick")
    local from = #created
    tab:__fire("OnClick")
    local out = {}
    for i = from + 1, #created do out[#out + 1] = created[i] end
    return ctx, out
end

--- The Skin tab's check box whose label ends with `name` (a choice-grid radio or a Scope box).
local function choiceNamed(inst, name)
    local ctx, created = openTab(inst, "Skin")
    for _, w in ipairs(created) do
        local label = tostring(w.labelText or "")
        if w.type == "CheckBox" and label:sub(-#name) == name then return w, ctx end
    end
    return nil, ctx
end

-- ── the owner ────────────────────────────────────────────────────────────────────────────────

test("Skin seam: the owner is the folder name, and NS.Skin is its facade", function()
    -- red under: registering under the brand or a typo (the library keys every frame and every
    -- listener by owner), or publishing a facade of some other owner.
    local _, NS, Skin = scene()
    assertTrue(Skin:IsOwner(OWNER), "core/SkinSetup.lua did not register the owner")
    assertTrue(rawequal(NS.Skin, Skin:For(OWNER)), "NS.Skin is not Skin:For(\"MultiMeters\")")
    assertEqual(NS.Skin.owner, OWNER)
    assertEqual(Skin:OwnerLabel(OWNER), "Ka0s Multi Meters", "the copy confirmation names the brand")
end)

test("Skin seam: the read answers Ka0s Default before the profile store exists", function()
    -- RegisterOwner calls `get` at FILE LOAD, before NS:InitDB; a getter that raised there would be
    -- a visible Lua error on every login.
    local inst = T.load{ initDB = false, options = false }
    local ok, source, skin = pcall(inst.NS.SkinChoice)
    assertTrue(ok, "NS.SkinChoice raised without a store: " .. tostring(source))
    assertEqual(source, "ka0s")
    assertEqual(skin, "ka0s")
    local font, texture = inst.NS.SkinOverride()
    assertEqual(font, false)
    assertEqual(texture, false)
end)

-- ── the owner tokens (DECISIONS X1, X2, X12) ─────────────────────────────────────────────────

test("Skin seam: every owner token is registered, namespaced mm., and keeps its pixel on Ka0s Default", function()
    -- red under: a token the library refused (a library family, a follow of the wrong kind), or a
    -- Ka0s Default value that moved off today's pixel.
    local _, NS, Skin = scene()
    local n = 0
    for name, def in pairs(NS.SKIN_TOKENS) do
        n = n + 1
        assertTrue(name:match("^mm%.") ~= nil, name .. ": owner tokens are namespaced mm. (X12)")
        local c = Skin:Token(OWNER, name)
        assertTrue(type(c) == "table", name .. ": the library refused the token")
        for i = 1, 4 do
            assertTrue(math.abs((c[i] or 1) - (def.default[i] or 1)) < 1e-6,
                ("%s[%d]: Ka0s Default answers %s, not today's %s"):format(name, i, tostring(c[i]),
                    tostring(def.default[i])))
        end
    end
    assertTrue(n > 0, "no owner tokens")
end)

test("Skin seam: another skin draws each owner token from its follow token", function()
    -- X2: every skin draws the token in its own palette.
    local _, NS, Skin = scene()
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local obsidian = Skin:ResolveSkin("obsidian")
    for name, def in pairs(NS.SKIN_TOKENS) do
        local c, want = Skin:Token(OWNER, name), obsidian[def.follow]
        assertTrue(type(want) == "table", name .. ": follows " .. tostring(def.follow) .. ", no color")
        for i = 1, 4 do
            assertTrue(math.abs((c[i] or 1) - (want[i] or 1)) < 1e-6,
                ("%s[%d]: Obsidian does not draw %s"):format(name, i, def.follow))
        end
    end
end)

-- ── the keys and the rows ────────────────────────────────────────────────────────────────────

test("Skin seam: the skin keys default to Ka0s Default, the panel ignored and the picker unseen", function()
    -- skinning-§2's per-profile pair, the owner's 2026-10-27 Scope call, and O3's picker on every
    -- profile. red under: any default moved.
    local _, NS = scene()
    local d = NS.defaults.profile.skin
    assertEqual(d.source, "ka0s")
    assertEqual(d.skin, "ka0s")
    assertEqual(d.ignorePanel, true)
    assertEqual(d.ignoreFonts, false)
    assertEqual(d.font, "")
    assertEqual(d.texture, "")
    assertEqual(d.outline, "hud", "the Font outline: HUD text only (LibKa0s v1.83.0)")
    assertEqual(d.pickerSeen, false)
end)

test("Skin seam: the eight skin keys are skip-render rows in the Skin tab's group", function()
    -- red under: a row that renders itself on top of the library's tab, or one outside the group
    -- whose place the tab takes.
    local _, NS = scene()
    assertEqual(NS.SKIN_TAB, "Appearance", "the key O.AppearanceTab answers")
    for _, path in ipairs(SKIN_PATHS) do
        local row = rowAt(NS, path)
        assertTrue(row ~= nil, path .. " is not a schema row")
        assertEqual(row.page, "general", path .. ": page")
        assertEqual(row.group, NS.SKIN_TAB, path .. ": group")
        assertTrue(row.skipRender == true, path .. ": the tab draws it, so it must be skipRender")
    end
end)

test("Skin seam: the skin row's values are every registered skin, in the library's order", function()
    local _, NS, Skin = scene()
    local row = rowAt(NS, "skin.skin")
    local skins = Skin:Skins()
    assertEqual(#row.sorting, #skins, "one value per registered skin")
    for i, def in ipairs(skins) do
        assertEqual(row.sorting[i], def.key, "value " .. i)
        assertTrue(row.values[def.key] ~= nil, def.key .. " has no label")
    end
    assertEqual(row.sorting[1], "ka0s", "Ka0s Default first")
end)

test("Skin seam: /mm set refuses a skin that is not registered and applies one that is", function()
    -- The `values` check is the CLI parser's, so this drives the verb.
    local _, NS, Skin, counter = scene()
    NS.Slash:OnSlash("set skin.skin no-such-skin")
    assertEqual(NS.db.profile.skin.skin, "ka0s", "an unknown skin was stored")
    assertEqual(counter.looks, 0, "a refused set repainted")
    NS.Slash:OnSlash("set skin.skin obsidian")
    assertEqual(NS.db.profile.skin.skin, "obsidian", "a registered skin was refused")
    local _, applied = Skin:GetChoice(OWNER)
    assertEqual(applied, "obsidian", "a bare set must move the applied skin (the row's onChange)")
    assertEqual(counter.looks, 1, "one set, one repaint")
end)

test("Skin seam: /mm set reaches an exception, and only its own half", function()
    local _, NS, Skin = scene()
    NS.Slash:OnSlash("set skin.ignoreFonts true")
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the set applied")
    assertEqual(panel, true, "the other half untouched")
end)

test("Skin seam: the write seam stores media's halves, \"\" for the skin's own", function()
    local _, NS = scene()
    NS.WriteSkinChoice(nil, nil, nil, { font = "Friz Quadrata TT", texture = false })
    assertEqual(NS.db.profile.skin.font, "Friz Quadrata TT")
    assertEqual(NS.db.profile.skin.texture, "")
    NS.WriteSkinChoice("ka0s", "glass")
    assertEqual(NS.db.profile.skin.font, "Friz Quadrata TT", "a write with no media leaves it alone")
    assertEqual(NS.db.profile.skin.skin, "glass")
end)

-- ── the tab ──────────────────────────────────────────────────────────────────────────────────

test("Skin seam: one tab pick is one effective SetChoice, one repaint, in the profile", function()
    -- The tab calls SetChoice first, then the write seam, which writes each row through
    -- NS.SetByPath; each row's onChange applies only its own half and finds it applied already.
    -- red under: an onChange that re-applies the whole stored pair (two repaints, the first to a
    -- half-written skin), or a seam that writes the profile around NS.SetByPath.
    local inst, NS, Skin, counter = scene()
    local cb = choiceNamed(inst, "Obsidian")
    assertTrue(cb ~= nil, "the Skin tab drew no Obsidian choice")
    counter.looks = 0
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    assertEqual(counter.looks, 1, "one pick must repaint exactly once")
    local source, skin = Skin:GetChoice(OWNER)
    assertEqual(source, "ka0s")
    assertEqual(skin, "obsidian", "the pick did not move the applied skin")
    assertEqual(NS.db.profile.skin.skin, "obsidian", "the pick did not reach the profile")
end)

test("Skin seam: the tab's Ignore fonts reaches the library and the profile, one repaint", function()
    local inst, NS, Skin, counter = scene()
    local cb = choiceNamed(inst, "Ignore fonts")
    assertTrue(cb ~= nil, "the Skin tab drew no Ignore fonts box")
    counter.looks = 0
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the library's exception moved")
    assertEqual(panel, true, "and the other kept")
    assertEqual(NS.db.profile.skin.ignoreFonts, true, "the profile holds it")
    assertEqual(counter.looks, 1, "one toggle repaints once")
end)

test("Skin seam: another addon's copy to every Ka0s addon repaints this one once", function()
    -- The library's copy calls SetChoice for each other owner, then WriteChoice, which reaches this
    -- addon's registered setter.
    local _, NS, Skin, counter = scene()
    Skin:SetChoice(OWNER, "ka0s", "ember")
    assertTrue(Skin:WriteChoice(OWNER, "ka0s", "ember"), "the copy's write did not reach the setter")
    assertEqual(counter.looks, 1, "a copy must repaint this addon exactly once")
    assertEqual(NS.db.profile.skin.skin, "ember", "the copy did not land in the profile")
end)

-- ── the profile events ───────────────────────────────────────────────────────────────────────

test("Skin seam: a profile switch applies the new profile's skin before the rebuild", function()
    -- core/Database.lua's rebuild applies the skin before PROFILE_CHANGED rebuilds the windows, so
    -- the rebuilt windows are drawn in the new profile's skin. The spy stands in for the first
    -- per-session step after it and records what was applied by then.
    -- red under: applying the skin after the rebuild, or not at all on a switch.
    local _, NS, Skin, counter = scene()
    local db = NS.db
    db:SetProfile("SkinProbe")
    db.profile.skin.skin = "glass"
    db.profile.skin.ignoreFonts = true
    db.profile.skin.texture = "Ka0s Matte"
    db:SetProfile("Default")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "back on Default, Default's skin")
    local real, seen = NS.State.SetActiveWindow, nil
    NS.State.SetActiveWindow = function(...)
        seen = select(2, Skin:GetChoice(OWNER))
        return real(...)
    end
    counter.looks = 0
    db:SetProfile("SkinProbe")
    NS.State.SetActiveWindow = real
    assertEqual(seen, "glass", "the skin was not applied before the rebuild")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "glass", "the switch did not move the applied skin")
    local _, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the profile's stored exception came with it")
    local _, texture = Skin:GetOverride(OWNER)
    assertEqual(texture, "Ka0s Matte", "the profile's stored override came with it")
    assertTrue(counter.looks >= 1, "the switch repainted")
end)

test("Skin seam: OnInitialize applies the stored skin right after the store exists", function()
    -- red under: the call dropped from core/MultiMeters.lua, or moved after a frame is built.
    local src = T.Loader.readFile("core/MultiMeters.lua")
    local init = src:find("self:InitDB%(%)")
    local apply = src:find("NS%.ApplySkinChoice%(%)")
    assertTrue(init ~= nil and apply ~= nil, "OnInitialize calls InitDB and NS.ApplySkinChoice")
    assertTrue(apply > init, "the skin is applied after the store exists")
    assertTrue(src:find("NS%.ApplySkinChoice%(%)", apply + 1) == nil, "applied once at init")
end)

-- ── the factories ────────────────────────────────────────────────────────────────────────────

test("Skin seam: every library widget factory this addon calls is handed the owner", function()
    -- Dropdown (the export modal's channel picker), ReorderList (the column blocks) and the two
    -- TestStrips (test mode, simulation) each skin themselves for `owner`, and draw stock without
    -- it. red under: a factory call added or kept without `owner = NS.name`.
    local files = {
        ["modules/Export_Modal.lua"] = 1, ["settings/ColumnBlocks.lua"] = 1, ["modules/Window_Frame.lua"] = 2,
    }
    for path, want in pairs(files) do
        local src = T.Loader.readFile(path):gsub("%-%-[^\r\n]*", "")
        local _, calls = src:gsub("W%.[A-Z][%a]*%s*%(", "")
        local _, owners = src:gsub("owner%s*=%s*NS%.name", "")
        assertEqual(owners, want, path .. ": owner hand-offs")
        assertTrue(calls >= want, path .. ": factory calls")
    end
end)

-- ── the degraded facade ──────────────────────────────────────────────────────────────────────

test("Skin seam: the degraded facade answers every name the live facade carries", function()
    -- Without the library NS.Skin is the host's table, whose painting names are no-ops (Shell and
    -- Text excepted). A facade is per owner and built by `For`, so this is the two-table form, key
    -- for key: a vocabulary name the library adds fails here until the stub answers it.
    local live, degraded = T.load{}, T.load{ libFiles = {} }
    assertEqual(degraded.mocks.LibStub("LibKa0s-Skin-1.0", true), nil, "the library is not absent")
    T.assertSurfaceParity(live.NS.Skin, degraded.NS.Skin, "Skin facade vs host stub", {})
end)

test("Skin seam: the seam publishes the same NS members on both paths", function()
    local live, degraded = T.load{}, T.load{ libFiles = {} }
    local src = T.Loader.readFile("core/SkinSetup.lua")
    local n = 0
    for name in src:gmatch("\n%s*function NS%.([%a_]+)") do
        n = n + 1
        assertEqual(type(degraded.NS[name]), type(live.NS[name]), "NS." .. name)
    end
    for name in src:gmatch("\nNS%.([%a_]+)%s*=") do
        n = n + 1
        assertEqual(type(degraded.NS[name]), type(live.NS[name]), "NS." .. name)
    end
    assertTrue(n > 0, "found no NS members in core/SkinSetup.lua")
end)

test("Skin seam: each host-copy skin token is the live library's Ka0s Default value", function()
    -- The degraded facade answers Ka0s Default from NS.SKIN_FALLBACK, a copy of the library's own
    -- values limited to the tokens this addon reads. A copy is the thing that drifts.
    local inst = T.load{}
    local live = inst.mocks.LibStub("LibKa0s-Skin-1.0"):ResolveSkin("ka0s")
    local n = 0
    for name, c in pairs(inst.NS.SKIN_FALLBACK) do
        n = n + 1
        local want = live[name]
        assertTrue(type(want) == "table", name .. " is not a Ka0s Default color token in the library")
        for i = 1, 4 do
            assertTrue(math.abs((c[i] or 1) - (want[i] or 1)) < 1e-6,
                ("%s[%d]: host copy %s, library %s"):format(name, i, tostring(c[i]), tostring(want[i])))
        end
    end
    assertTrue(n > 0, "the host copy is empty, so this case asserts nothing")
end)

test("Skin seam: degraded, the facade answers today's colors and the seam never raises", function()
    local degraded = T.load{ libFiles = {} }
    local NS = degraded.NS
    assertEqual(NS.SkinEscape("mm.dim"), "|cff9d9d9d", "the dim gray keeps its bytes")
    local r, g, b, a = NS.SkinColor("mm.rowHover")
    assertEqual(r, 1); assertEqual(g, 1); assertEqual(b, 1); assertEqual(a, 0.10)
    assertEqual(select("#", NS.SkinColor("win.border")), 3, "an opaque token answers three components")
    assertTrue(pcall(NS.ApplySkinChoice), "ApplySkinChoice raised degraded")
    assertTrue(pcall(NS.WriteSkinChoice, "ka0s", "ka0s"), "WriteSkinChoice raised degraded")
end)
