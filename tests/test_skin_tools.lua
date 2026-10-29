-- tests/test_skin_tools.lua — the tool surfaces and the tooltip lines on the skin (core/SkinSetup.lua's
-- owner, skinning-§3 and §7; the rollout's MM-04).
--
-- The tool surfaces are the library's own windows, and each follows this addon's skin because the
-- descriptor names the folder and no host hook (`skin` / `applySkin`) takes the job over: the debug
-- console (DebugLog minor 22), the perf panel and the sim step panel. This pins that each one, once
-- drawn, is a frame the skin engine painted FOR THIS OWNER, so a skin switch repaints it. The test
-- and sim strips and the export copy window are pinned in tests/test_skinsetup.lua's factory case.
--
-- The tooltip lines this addon writes keep GameTooltip's frame (skinning-§7) and take the owner's
-- tokens: headings and the right half of a header `gtip.title`, the hint lines `mm.tipHint`.
-- Under Ka0s Default each is exactly the literal it replaced; under another skin, that skin's.
--
-- EACH CASE ON ITS OWN INSTANCE: a skin change is library session state.

local T = _G.MULTIMETERS_TEST
local test, assertTrue = T.test, T.assertTrue

local OWNER = "MultiMeters"
local CURRENT = 1
local ALPHA   = "Player-1-0000000A"

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

--- True when the skin engine painted a frame named `name` (or matching it) FOR THIS OWNER: its record
--- of painted frames, which a skin switch walks to repaint.
local function paintedNamed(Skin, pattern)
    for f in pairs(Skin.byOwner and Skin.byOwner[OWNER] or {}) do
        local name = f.GetName and f:GetName()
        if type(name) == "string" and name:find(pattern) then return true end
    end
    return false
end

-- ── the tool surfaces ────────────────────────────────────────────────────────────────────────

test("Skin tools: the debug console is painted for this owner", function()
    -- red under: a `skin` or `applySkin` hook back in core/DebugLogSetup.lua's descriptor (it would
    -- own the whole job and the console would never follow the skin), or `addonName` dropped.
    local inst = T.load{}
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    inst.NS.DebugLog:Show()
    assertTrue(paintedNamed(Skin, "^MultiMetersDebugWindow$"), "the debug console is not painted for " .. OWNER)
    inst.NS.DebugLog:Hide()
end)

test("Skin tools: the perf panel is painted for this owner", function()
    local inst = T.load{}
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    inst.NS.Perf.ShowPanel()
    assertTrue(paintedNamed(Skin, "^MultiMetersPerfPanel$"), "the perf panel is not painted for " .. OWNER)
    inst.NS.Perf.HidePanel()
end)

test("Skin tools: the sim step panel is painted for this owner", function()
    local inst = T.load{}
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    inst.NS.Sim.ShowPanel()
    assertTrue(paintedNamed(Skin, "Sim"), "the sim step panel is not painted for " .. OWNER)
    inst.NS.Sim.HidePanel()
end)

-- ── the tooltip lines ────────────────────────────────────────────────────────────────────────

--- A capped cell tooltip: the header, the "Spell breakdown" heading and the "and N more" hint.
local function cellTooltip(inst)
    local NS, mocks = inst.NS, inst.mocks
    mocks.setSourceDetail(CURRENT, "*", "*", { combatSpells = {
        { spellID = 101, totalAmount = 300 }, { spellID = 102, totalAmount = 200 },
        { spellID = 103, totalAmount = 100 },
    }, maxAmount = 300, totalAmount = 600 })
    local cfg = NS.Database.GetWindows()[1]
    cfg.data.sessionType = CURRENT
    cfg.tooltip.maxSpells = 1
    mocks.GameTooltip:ClearLines()
    NS.Tooltip:CellTooltip({ guid = ALPHA, name = "Alpha", classFilename = "MAGE", values = {} },
        "DamageDone", mocks.__stubFrame("Frame"), cfg)
    local out = {}
    for _, line in ipairs(mocks.GameTooltip.__lines) do
        if line.double and out.header == nil then out.header = line.rightColor end
        if line.text == NS.L["Spell breakdown"] then out.heading = { line.r, line.g, line.b } end
        if type(line.text) == "string" and line.text:find("and 2 more", 1, true) then
            out.hint = { line.r, line.g, line.b }
        end
    end
    return out
end

local function sameRGB(got, want, msg)
    assertTrue(got ~= nil, msg .. ": no such line")
    for i = 1, 3 do
        assertTrue(near(got[i], want[i]), ("%s: channel %d is %s, want %s"):format(msg, i,
            tostring(got[i]), tostring(want[i])))
    end
end

test("Skin tools: under Ka0s Default the tooltip lines keep their pixels", function()
    local lines = cellTooltip(T.load{})
    sameRGB(lines.header, { 1, 0.82, 0 }, "the header's right half")
    sameRGB(lines.heading, { 1, 0.82, 0 }, "the section heading")
    sameRGB(lines.hint, { 0.6, 0.6, 0.6 }, "the overflow hint")
end)

test("Skin tools: under another skin the tooltip lines take its gtip tokens", function()
    -- red under: a literal 1, 0.82, 0 or 0.6 gray back in modules/Tooltip_Builders.lua.
    local inst = T.load{}
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    Skin:SetChoice(OWNER, "ka0s", "ember")
    local S = inst.NS.Skin
    local lines = cellTooltip(inst)
    sameRGB(lines.header, { S.Color("gtip.title") }, "the header's right half")
    sameRGB(lines.heading, { S.Color("gtip.title") }, "the section heading")
    sameRGB(lines.hint, { S.Color("mm.tipHint") }, "the overflow hint")
end)
