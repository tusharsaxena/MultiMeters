local addonName, NS = ...

-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam: which skin this addon wears (skinning-§3).
--
-- ── WHAT IT PUBLISHES ────────────────────────────────────────────────────────────────────────
--
--   NS.Skin                 the owner's facade, `Skin:For("MultiMeters")`: the painting vocabulary
--                           (Shell, TitleBar, Button, ...) and Token / Color / Resolve /
--                           OnLooksChanged. Every surface that draws reads its colors here.
--   NS.SKIN_TOKENS          this addon's owner tokens (skinning-§1, LibKa0s-Skin-1.0 minor 7):
--                           the colors it draws under Ka0s Default that no library token holds
--                           exactly, each with its Ka0s Default pixel and the library ROLE token
--                           every other skin draws it from (DECISIONS X1, X2, X12).
--   NS.SkinChoice()         the stored (source, skin) pair, read through NS.GetSetting; "ka0s",
--                           "ka0s" before NS:InitDB has built the profile store.
--   NS.WriteSkinChoice(s,k,i,m) the write seam: every half through NS.SetByPath, the one seam
--                           `/mm set` and the panel already write through (options-ui-§1); `i`, the
--                           Scope's `{ panel, fonts }`, writes the two exceptions, and `m`, the Font
--                           and texture section's `{ font, texture }`, writes the two overrides, ""
--                           for false (the skin's own).
--   NS.ApplySkinIgnore(p,f) moves the applied exceptions: `Skin:SetIgnore`, live; no argument
--                           applies the stored pair, a nil half keeps that half.
--   NS.SkinOverride()       the stored overrides: font, texture, each an LSM key or false for the
--                           skin's own; false, false before NS:InitDB.
--   NS.ApplySkinOverride(f,t) moves the applied overrides: `Skin:SetOverride`, live; no argument
--                           applies the stored pair, a nil half keeps that half, false or "" clears.
--   NS.ApplySkinChoice(s,k) moves the applied skin: `Skin:SetChoice`, which resolves, repaints
--                           every frame recorded for this owner and THEN fires OnLooksChanged. No
--                           argument applies the stored pair (NS:OnInitialize, the profile
--                           events), and with it the stored exceptions and overrides; a nil half
--                           keeps that half (each Skin tab row's onChange).
--   NS.SKIN_SOURCE_VALUES   the source row's values and order, and the skin row's (every registered
--   NS.SKIN_SOURCE_SORT     skin, in the library's order), in this addon's `values` / `sorting`
--   NS.SKIN_VALUES          row shape. settings/Schema_Skin.lua reads all four at file load.
--   NS.SKIN_SORT
--   NS.SKIN_TAB             the Skin tab's key, "Appearance": the schema group of the skin rows and
--                           the key O.AppearanceTab answers, so the library's tab takes the group's
--                           place on the General page's strip (settings/General.lua).
--   NS.SKIN_FALLBACK        the host copy of the Ka0s Default library tokens the degraded facade
--                           answers.
--   NS.SkinColor(name)      a color token as a call site writes it (three components when opaque),
--                           so a literal that became a token keeps its arity on Ka0s Default.
--   NS.SkinEscape(name)     a color token as a "|cffrrggbb" escape, rounded to the byte, so markup
--                           written as a literal keeps its bytes on Ka0s Default (|cff9d9d9d).
--
-- ── WHERE IT LOADS ───────────────────────────────────────────────────────────────────────────
--
-- After core/CoreSetup.lua, whose NS.ApplySkin the degraded facade's Shell routes to and whose
-- NS.Print the reload line uses (both read at call time), and above every module that builds a
-- frame, so NS.Skin exists for all of them. settings/Schema_Skin.lua reads the value tables at
-- file load and is far below. Nothing here reads the profile at load: RegisterOwner calls `get`
-- once, before AceDB exists, and it answers Ka0s Default; the profile's pair is applied by
-- NS.ApplySkinChoice right after NS:InitDB (core/MultiMeters.lua) and on every profile event
-- (core/Database.lua's rebuild).
--
-- ── WHY A ROW'S onChange PASSES ONE HALF ─────────────────────────────────────────────────────
--
-- The Skin tab and another addon's "Copy to every Ka0s addon" both call Skin:SetChoice FIRST and
-- write the store after, one half at a time. A row reaction that re-applied the whole stored pair
-- would apply the half-written one in between: a second repaint, to a skin the player never
-- picked. Applying only the row's own half against the applied choice makes each write a no-op
-- (SetChoice is idempotent), so a pick is ONE effective SetChoice and one repaint, while a bare
-- `/mm set skin.skin obsidian` still repaints.

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)
local L = NS.L

local SOURCE_PATH, SKIN_PATH = "skin.source", "skin.skin"
local PANEL_PATH, FONTS_PATH = "skin.ignorePanel", "skin.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "skin.font", "skin.texture"
local DEFAULT = "ka0s"

NS.SKIN_TAB = "Appearance"

-- The colors this addon draws under Ka0s Default that no library token holds exactly (the
-- rollout's MM-G1..G4). Each keeps today's pixel as its `default`, so Ka0s Default does not move
-- (DECISIONS X1), and follows the nearest library ROLE token, so every other skin draws it in its
-- own palette (X2). The names are this addon's namespace, `mm.`, never a library family (X12).
local DIM = 0x9d / 255
NS.SKIN_TOKENS = {
    -- The meter row's mouseover wash (modules/Row.lua): white at 0.10 where `list.hover` is gold.
    ["mm.rowHover"]  = { default = { 1, 1, 1, 0.10 }, follow = "list.hover" },
    -- The meter row's alternating stripe (modules/Row.lua): white at 0.05 where `list.stripe` is 0.03.
    ["mm.rowStripe"] = { default = { 1, 1, 1, 0.05 }, follow = "list.stripe" },
    -- The tooltip hint and overflow lines ("and N more", "Click for details", "No data yet"):
    -- 0.6 gray, between `gtip.muted` 0.5 and `gtip.subtle` 0.7.
    ["mm.tipHint"]   = { default = { 0.6, 0.6, 0.6, 1 }, follow = "gtip.muted" },
    -- The dim text inside the meter window (the session line's "restricted" notes, the notice's
    -- reason line), NS.GRAY |cff9d9d9d today.
    ["mm.dim"]       = { default = { DIM, DIM, DIM, 1 }, follow = "text.muted" },
    -- The red TEST MODE word in a window title (modules/Window_Header.lua), |cffff2020 today:
    -- `sem.modeTest` is 1, 0.15, 0.15, four levels off, so it keeps its own pixel (X1).
    ["mm.testWord"]  = { default = { 1, 0x20 / 255, 0x20 / 255, 1 }, follow = "sem.modeTest" },
    -- The export modal's refusal line (modules/Export_Modal.lua): 0.9, 0.25, 0.25 where `sem.off`
    -- is 0.9, 0.3, 0.3.
    ["mm.warn"]      = { default = { 0.9, 0.25, 0.25, 1 }, follow = "sem.off" },
}

-- The Ka0s Default library tokens the DEGRADED facade answers, copied from the library and limited
-- to the ones this addon reads. Both arms publish the table, so tests/test_skinsetup.lua can hold
-- each entry to the live library's Ka0s Default value: a copy that drifts goes red there. A surface
-- converted to a token adds the token here in the same change. The owner tokens are not copied:
-- the degraded facade answers their `default` from NS.SKIN_TOKENS, which is the same pixel.
NS.SKIN_FALLBACK = {
    ["win.bg"]     = { 0.06, 0.06, 0.08, 0.92 },
    ["win.border"] = { 0, 0, 0, 1 },
    ["win.inner"]  = { 0.24, 0.24, 0.27, 0.85 },
    ["title.text"] = { 1, 0.82, 0, 1 },
    ["divider"]    = { 0.24, 0.24, 0.27, 0.85 },
    ["text.highlight"] = { 1, 1, 1, 1 },
    ["text.heading"]   = { 1, 0.82, 0, 1 },
    ["text.accent"]    = { 1, 0.82, 0, 1 },
}

--- A color token's components AS A CALL SITE WRITES THEM: r, g, b for an opaque color and r, g, b,
--- a otherwise (the library's own text and vertex rule), so a site that passed three components
--- before it read a token still passes three on Ka0s Default. nil for a token the skin leaves alone.
--- Read through NS.Skin at call time, so it answers the live skin, or the host copy degraded.
function NS.SkinColor(name)
    local r, g, b, a = NS.Skin.Color(name)
    if r == nil then return nil end
    if a == nil or a == 1 then return r, g, b end
    return r, g, b, a
end

--- A color token as a "|cffrrggbb" escape, each channel rounded to the nearest byte (0x9d/255 is
--- 9d), so markup a call site wrote as a literal keeps its bytes on Ka0s Default. nil for a token
--- the skin leaves alone.
function NS.SkinEscape(name)
    local r, g, b = NS.Skin.Color(name)
    if r == nil then return nil end
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

-- The source row's values, and the skin row's: every registered skin, Ka0s Default first. Without
-- the library the one skin the degraded facade can draw.
NS.SKIN_SOURCE_VALUES = { ka0s = L["Ka0s skins"], eui = "EllesmereUI" }
NS.SKIN_SOURCE_SORT   = { "ka0s", "eui" }
NS.SKIN_VALUES, NS.SKIN_SORT = {}, {}
if Skin and type(Skin.Skins) == "function" then
    for _, def in ipairs(Skin:Skins()) do
        if NS.SKIN_VALUES[def.key] == nil then NS.SKIN_SORT[#NS.SKIN_SORT + 1] = def.key end
        NS.SKIN_VALUES[def.key] = def.label or def.key
    end
end
if #NS.SKIN_SORT == 0 then
    NS.SKIN_VALUES[DEFAULT], NS.SKIN_SORT[1] = "Ka0s Default", DEFAULT
end

--- A stored read, nil-safely: nil until the profile store exists.
local function stored(path)
    if not (NS.db and NS.GetSetting) then return nil end
    return NS.GetSetting(path)
end

--- The stored pair, lazily and nil-safely: Ka0s Default until the profile store exists.
function NS.SkinChoice()
    return stored(SOURCE_PATH) or DEFAULT, stored(SKIN_PATH) or DEFAULT
end

--- A stored override as the profile keeps it: the LSM key, or "" for the skin's own (false, nil, "").
local function storedKey(v)
    if type(v) == "string" and v ~= "" then return v end
    return ""
end

--- The write seam: every half through NS.SetByPath (validate, store, the [Set] line, onChange).
--- `ignore` is `{ panel, fonts }` and `media` `{ font = key|false, texture = key|false }`: the Skin
--- tab and another addon's copy hand them here after Skin:SetIgnore / Skin:SetOverride moved the
--- applied pair, so each row's onChange re-applies its own half as a no-op.
function NS.WriteSkinChoice(source, skin, ignore, media)
    if not (NS.db and NS.SetByPath) then return end
    if source ~= nil then NS.SetByPath(SOURCE_PATH, source) end
    if skin ~= nil then NS.SetByPath(SKIN_PATH, skin) end
    if type(ignore) == "table" then
        NS.SetByPath(PANEL_PATH, ignore.panel == true)
        NS.SetByPath(FONTS_PATH, ignore.fonts == true)
    end
    if type(media) == "table" then
        NS.SetByPath(FONT_PATH, storedKey(media.font))
        NS.SetByPath(TEXTURE_PATH, storedKey(media.texture))
    end
end

--- The stored overrides, nil-safely: each an LSM key, or false for the skin's own; false, false
--- until the profile store exists.
function NS.SkinOverride()
    local font, texture = storedKey(stored(FONT_PATH)), storedKey(stored(TEXTURE_PATH))
    return font ~= "" and font or false, texture ~= "" and texture or false
end

--- The stored exceptions, nil-safely. Until the profile store exists, the shipped defaults.
local function storedIgnore()
    local panel, fonts = stored(PANEL_PATH), stored(FONTS_PATH)
    if panel == nil then panel = true end
    return panel == true, fonts == true
end

-- ── the degraded arm ─────────────────────────────────────────────────────────────────────────

if not Skin then
    local function color(name)
        local c = NS.SKIN_FALLBACK[name] or (NS.SKIN_TOKENS[name] and NS.SKIN_TOKENS[name].default)
        if c then return c[1], c[2], c[3], c[4] or 1 end
    end
    local function noop() end
    local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
    -- Every vocabulary name answers, and a primitive with no host meaning is a no-op that never
    -- raises. The list is LibKa0s-Skin-1.0's VOCAB; tests/test_skinsetup.lua holds this table to the
    -- live facade key for key.
    for _, name in ipairs({
        "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
        "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
        "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
        "GetAccentColor", "GetPanelColor", "GetFont",
        "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
        "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
        "BarTexture",
    }) do S[name] = noop end

    S.Token = function(name)
        local def = NS.SKIN_TOKENS[name]
        return NS.SKIN_FALLBACK[name] or (def and def.default)
    end
    S.Color = color
    S.Resolve = function(kind, value, fromSkin)
        if fromSkin or value == S.FROM_SKIN then return S.Token(kind) end
        return value
    end
    S.OnLooksChanged = function(fn) return fn end   -- the skin never changes without the library
    S.IsEnabled = function() return false end
    S.GetStyle = function() return "ka0s:" .. DEFAULT end

    -- The window edge is CoreSetup's pre-library skin, byte for byte what a working install drew.
    S.Shell = function(frame) if NS.ApplySkin then NS.ApplySkin(frame) end end
    -- Text in a token's color: a role ("title", or a text.* role) or a token name.
    S.Text = function(fs, role)
        local name = role == "title" and "title.text" or tostring(role)
        local r, g, b, a = color(name)
        if r == nil then r, g, b, a = color("text." .. tostring(role)) end
        if r and fs and fs.SetTextColor then fs:SetTextColor(r, g, b, a) end
    end
    S.GetPanelColor = function() return color("win.bg") end
    S.GetFont = function() return STANDARD_TEXT_FONT end
    S.ChartStyle = function() return {} end
    S.BarStyle = function() return {} end

    NS.Skin = S
    function NS.ApplySkinChoice() return false, false end
    function NS.ApplySkinIgnore() return false, false end
    function NS.ApplySkinOverride() return false end
    return
end

-- ── the live seam ────────────────────────────────────────────────────────────────────────────

NS.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, {
    label  = "Ka0s Multi Meters",
    get    = NS.SkinChoice,
    set    = NS.WriteSkinChoice,
    tokens = NS.SKIN_TOKENS,
    -- The one line the EllesmereUI provider writes when it refuses a facade, or an owner token the
    -- library refuses: the debug console, read at call time (core/DebugLogSetup.lua loads below).
    log    = function(line) if NS.Debug then NS.Debug("Skin", "%s", tostring(line)) end end,
})

-- The one line a reload request earns on the path that has no popup of its own (a profile event
-- leaving an EllesmereUI that painted this session). The Skin tab raises the library's popup for
-- its own picks.
local RELOAD_LINE = L["Reload your interface (/reload) to finish changing the skin."]

function NS.ApplySkinIgnore(panel, fonts)
    if type(Skin.SetIgnore) ~= "function" then return false, false end
    if panel == nil and fonts == nil then panel, fonts = storedIgnore() end
    local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    return changed, reload
end

--- No argument applies the stored overrides; a nil half keeps that half, false or "" clears it
--- (the skin's own). A copy without SetOverride (a Skin major before minor 6) moves nothing.
function NS.ApplySkinOverride(font, texture)
    if type(Skin.SetOverride) ~= "function" then return false end
    if font == nil and texture == nil then font, texture = NS.SkinOverride() end
    return Skin:SetOverride(addonName, font, texture)
end

--- No argument applies the stored pair AND the stored exceptions and overrides (NS:OnInitialize,
--- the profile events); a nil half keeps that half and leaves the rest alone (each Skin tab row).
function NS.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = NS.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    if whole then
        NS.ApplySkinIgnore()
        NS.ApplySkinOverride()
    end
    return changed, reload
end
