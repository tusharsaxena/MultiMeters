-- tests/mock_frame.lua
--
-- The FRAME MODEL, peeled out of tests/wow_mock.lua when that file passed
-- layout-§1's 1500-line cap (issue #34). Loaded from there and nowhere else, and
-- NOT a suite: tests/run.lua's SUITES list must not gain an entry for it.
--
-- WHY IT IS THE LARGEST THING THE MOCK CARRIES. The kit base's frame stub answers
-- any PascalCase method from a metatable and returns THE FRAME ITSELF, so
-- `bar:CreateFontString()` and the bar are one object and "which widget got the
-- text" is unanswerable. This addon's entire output is text and bar values written
-- onto per-cell FontStrings and StatusBars (modules/Row.lua), so distinct region
-- objects with REAL STATE are a correctness requirement here rather than a luxury.
-- The base's own header names this as a divergence it expects a consumer's
-- extender to make.
--
-- IT IS HANDED THE SECRET SIMULATOR, not its own copy of one. `SetText`, `SetValue`
-- and `GetStringWidth` all have to recognize a simulated secret, and recognition is
-- registry identity (tests/mock_secrets.lua): a second load of that chunk would
-- give this file a second registry and every `__hasSecretValues` flag would answer
-- false for a secret minted by the builder. So the builder loads the simulator once
-- and passes it in.
--
--     local Frame = loadfile(root .. "/tests/mock_frame.lua")(Secrets)
--
-- Publishes: makeFrame(objectType, parent, name) · unloadable (the texture-path
-- registry the builder wipes per build) · installTooltip(M).

local Secrets = ...
local secret            = Secrets.secret
local isSimulatedSecret = Secrets.isSimulatedSecret

-- ===========================================================================
-- The frame model
-- ===========================================================================
--
-- Real state for everything this addon's correctness depends on, and a
-- self-returning no-op for everything else. What is modeled, and why:
--
--   VISIBILITY — modules/Window.lua's whole show ladder is observable only if
--     IsShown() can answer false. The base's blanket stub returns the frame,
--     which is permanently truthy.
--   GEOMETRY — the anchor frame's GetPoint round trip IS WindowProto:SavePosition
--     (the file exists to keep that read off a value-carrying widget), so a
--     SetPoint that recorded nothing would make rule R3's payoff untestable.
--   TEXT / FONT / COLOR — the cells and the header line are the addon's entire
--     visible output.
--   STATUS BAR values — `SetValue` / `SetMinMaxValues` are where a secret ends
--     up. Recording them raw is how a suite proves the handle reached the widget
--     without anything having looked at it.
--   BACKDROP — modules/Window.lua's ApplyBorder branches on `frame.SetBackdrop`
--     and writes a table whose edgeFile/edgeSize encode the "borderSize == 0
--     means no edge" rule.
--
-- Numeric getters that are NOT modeled return real numbers, never the frame:
-- LibKa0s-Options-1.0's always-shown-scrollbar patch does arithmetic on
-- GetHeight() and concatenates GetName(), and a table in either place raises
-- inside the library on the first panel render (kit fidelity rule 2).

local NUMERIC_GETTERS = {
    GetLeft = 0, GetRight = 0, GetTop = 0, GetBottom = 0,
    GetStringWidth = 0, GetStringHeight = 0,
    GetTextWidth = 0, GetTextHeight = 0,
    GetNumRegions = 0, GetNumChildren = 0,
    GetID = 0,
}

local makeFrame  -- forward declaration; regions are frames too

--- Normalize SetPoint's two overloads into one record. Both forms are used by
--- modules/Window.lua (`SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -5)`) and by
--- modules/Row.lua (`SetPoint("LEFT", bar, "LEFT", 2, 0)`).
local function recordPoint(point, a, b, c, d)
    if type(a) == "number" or a == nil then
        return { point = point, relativeTo = nil, relativePoint = point, x = a or 0, y = b or 0 }
    end
    return { point = point, relativeTo = a, relativePoint = b or point, x = c or 0, y = d or 0 }
end

local FRAME = {}

-- ── visibility ─────────────────────────────────────────────────────────────
function FRAME.Show(self)
    local was = self.__shown
    self.__shown = true
    if not was then self:_run("OnShow") end
    return self
end
function FRAME.Hide(self)
    local was = self.__shown
    self.__shown = false
    if was then self:_run("OnHide") end
    return self
end
--- Mouse-wheel plumbing. Recorded rather than no-op'd because a window that
--- forgot EnableMouseWheel has a live OnMouseWheel script the client will never
--- call — the scroll code runs perfectly in a harness and does nothing in game.
function FRAME.EnableMouseWheel(self, v) self.__mouseWheel = v and true or false; return self end
function FRAME.IsMouseWheelEnabled(self) return self.__mouseWheel and true or false end
--- Which buttons a frame asked for. A right-click handler on a frame that never
--- called RegisterForClicks is the same class of silent failure.
function FRAME.RegisterForClicks(self, ...)
    self.__clicks = { ... }
    return self
end
function FRAME.SetShown(self, v)
    if v then self:Show() else self:Hide() end
    return self
end
function FRAME.IsShown(self) return self.__shown end
--- Shown AND every ancestor shown — the distinction that matters once a row is
--- parented onto a hidden window body.
function FRAME.IsVisible(self)
    local f = self
    while f do
        if not f.__shown then return false end
        f = f.__parent
    end
    return true
end

-- ── geometry ───────────────────────────────────────────────────────────────
function FRAME.SetPoint(self, point, a, b, c, d)
    self.__points[#self.__points + 1] = recordPoint(point, a, b, c, d)
    return self
end
function FRAME.ClearAllPoints(self) self.__points = {}; return self end
function FRAME.GetNumPoints(self) return #self.__points end
function FRAME.GetPoint(self, i)
    local p = self.__points[i or 1]
    if not p then return nil end
    return p.point, p.relativeTo, p.relativePoint, p.x, p.y
end
function FRAME.SetAllPoints(self, rel)
    self.__allPoints = rel or self.__parent or true
    return self
end
function FRAME.SetSize(self, w, h) self.__w, self.__h = w or 0, h or 0; return self end
function FRAME.SetWidth(self, w) self.__w = w or 0; return self end
function FRAME.SetHeight(self, h) self.__h = h or 0; return self end
function FRAME.GetWidth(self) return self.__w end
function FRAME.GetHeight(self) return self.__h end
function FRAME.GetSize(self) return self.__w, self.__h end
function FRAME.SetScale(self, s) self.__scale = s or 1; return self end
function FRAME.GetScale(self) return self.__scale end
function FRAME.GetEffectiveScale(self)
    local s, f = 1, self
    while f do
        s = s * (f.__scale or 1)
        f = f.__parent
    end
    return s
end
function FRAME.SetAlpha(self, a) self.__alpha = a or 1; return self end
function FRAME.GetAlpha(self) return self.__alpha end
function FRAME.SetFrameStrata(self, v) self.__strata = v; return self end
function FRAME.GetFrameStrata(self) return self.__strata end
function FRAME.SetFrameLevel(self, v) self.__level = v or 0; return self end
function FRAME.GetFrameLevel(self) return self.__level end

-- ── identity / parenting ───────────────────────────────────────────────────
--- Always a STRING (kit fidelity rule 2). An anonymous frame gets a synthetic
--- unique name rather than nil, because the scrollbar patch concatenates it.
function FRAME.GetName(self) return self.__name end
function FRAME.GetObjectType(self) return self.__objectType end
function FRAME.SetParent(self, p) self.__parent = p; return self end
function FRAME.GetParent(self) return self.__parent end

-- ── movement / sizing ──────────────────────────────────────────────────────
--
-- Recorded rather than no-opped: modules/Window.lua's drag and resize handlers
-- are the ONLY place in the addon permitted to read geometry back off a widget,
-- and the whole two-frame anchor design exists so that read lands on a frame
-- that never held a value. A test proves that by seeing StartMoving land on
-- `inst.anchor` and never on `inst.frame`.
function FRAME.SetMovable(self, v) self.__movable = v and true or false; return self end
function FRAME.SetResizable(self, v) self.__resizable = v and true or false; return self end
function FRAME.SetClampedToScreen(self, v) self.__clamped = v and true or false; return self end
function FRAME.EnableMouse(self, v) self.__mouseEnabled = v and true or false; return self end
function FRAME.IsMouseEnabled(self) return self.__mouseEnabled and true or false end
function FRAME.RegisterForDrag(self, ...) self.__dragButtons = { ... }; return self end
function FRAME.StartMoving(self) self.__moves = (self.__moves or 0) + 1; return self end
function FRAME.StartSizing(self, point)
    self.__sizings = (self.__sizings or 0) + 1
    self.__lastSizingPoint = point
    return self
end
function FRAME.StopMovingOrSizing(self) self.__stops = (self.__stops or 0) + 1; return self end

-- ── text ───────────────────────────────────────────────────────────────────
--
-- SetText takes the value RAW and stores it raw. That is deliberate and it is
-- the point of the whole harness: a FontString handed a secret keeps the handle,
-- so a suite can assert `mocks.reveal(fs.__text)` without the mock having
-- inspected anything on the addon's behalf.
-- A FONTSTRING WITH NO FONT RAISES ON SetText, exactly as the client does.
--
-- This was silent here for a release and it cost a load: a glyph FontString was
-- built and given its text in the same breath, before anything called SetFont,
-- and the client answered `FontString:SetText(): Font not set` at BuildFrame —
-- taking the whole addon down before a single window existed. Every test passed,
-- because this stub happily stored the string.
--
-- A FontString created FROM A TEMPLATE inherits a font, which is why the check
-- keys on `__font or __template` rather than on `__font` alone; a bare
-- CreateFontString() is the case that has to be caught.
function FRAME.SetText(self, t)
    if self.__objectType == "FontString" and not (self.__font or self.__template) then
        error("FontString:SetText(): Font not set", 2)
    end
    -- A widget handed a secret STRING is as tainted as one handed a secret
    -- number. SetValue already recorded this; SetText did not, and a FontString
    -- is where most of this addon's secrets actually land.
    if isSimulatedSecret(t) then self.__hasSecretValues = true end
    self.__text = t
    return self
end
function FRAME.GetText(self) return self.__text end
--- A PROPORTIONAL-ISH string width, so layout that measures text is testable.
---
--- The numeric-getter default answers 0, which silently disables any code that
--- sizes something from a string — modules/Tooltip.lua widens the tooltip from
--- the longest spell name, and a zero measurement made that whole path look like
--- a no-op that still passed.
---
--- Six pixels a character is close enough for the game's default font at 12pt,
--- and the exact figure does not matter: what a suite asserts is that a wider
--- string produced a wider layout.
---
--- Answers 0 for anything that is not a plain string — a FontString handed a
--- SECRET must not be measured, and a double that measured one anyway would let
--- a rule-R3 violation through.
--- Whether this frame OR ANY ANCESTOR has been handed a secret.
---
--- SECRETNESS PROPAGATES UPWARD, and that is the half the first version of this
--- double missed. A widget handed a secret makes its PARENT secret, and the
--- parent's layout is then what every sibling is measured against — so a
--- FontString that never held a value of its own still answers a secret width
--- once anything else inside the same frame has held one.
---
--- Modelling only the direct case let a real rule-R3 violation ship green: the
--- addon measured GameTooltip's own line while its own amount slot, parented to
--- the same tooltip, had just been handed a secret amount.
local function inheritsSecret(frame)
    local f, guard = frame, 0
    while f and guard < 32 do
        if f.__hasSecretValues then return true end
        f, guard = f.__parent, guard + 1
    end
    return false
end

function FRAME.GetStringWidth(self)
    -- The width of anything inside a tainted frame is itself secret. Returning a
    -- simulated secret is what makes a `w > widest` comparison raise here the way
    -- it raises in the client, instead of quietly answering a number.
    if inheritsSecret(self) then return secret(#(tostring(self.__text or "")) * 6) end
    local t = self.__text
    if type(t) ~= "string" then return 0 end
    -- SCALED BY THE FONT SIZE, because a real one is. A flat pixels-per-character
    -- made every measurement size-blind, so code that measured text at the
    -- configured size looked identical to code that ignored the setting — and
    -- the addon's tooltip width is exactly that code.
    local size = (self.__font and self.__font.size) or 12
    return #t * size * 0.5
end
function FRAME.SetFormattedText(self, fmt, ...)
    if self.__objectType == "FontString" and not (self.__font or self.__template) then
        error("FontString:SetFormattedText(): Font not set", 2)
    end
    self.__text = fmt and string.format(fmt, ...) or nil
    return self
end
function FRAME.SetFont(self, path, size, flags)
    self.__font = { path = path, size = size, flags = flags }
    return self
end
function FRAME.GetFont(self)
    local f = self.__font
    if not f then return nil end
    return f.path, f.size, f.flags
end
--- Adopt a font OBJECT, which is how a restyled widget is put back.
---
--- Recorded rather than no-op'd because it is the whole of modules/Tooltip.lua's
--- font-restore contract: the addon writes SetFont onto GameTooltip's SHARED line
--- FontStrings and has to undo it, and a stub that swallowed the call would make
--- "did it clean up" unassertable. `__font` is cleared so `GetFont` answers nil
--- again — a restored line is one that no longer carries an explicit font.
function FRAME.SetFontObject(self, obj)
    self.__fontObject = obj
    self.__font = nil
    return self
end
function FRAME.GetFontObject(self) return self.__fontObject end
function FRAME.SetTextColor(self, r, g, b, a)
    self.__textColor = { r, g, b, a or 1 }
    return self
end
function FRAME.GetTextColor(self)
    local c = self.__textColor
    if not c then return 1, 1, 1, 1 end
    return c[1], c[2], c[3], c[4]
end
function FRAME.SetJustifyH(self, v) self.__justifyH = v; return self end
function FRAME.GetJustifyH(self) return self.__justifyH end
function FRAME.SetJustifyV(self, v) self.__justifyV = v; return self end
function FRAME.SetShadowOffset(self, x, y) self.__shadow = { x, y }; return self end
function FRAME.SetShadowColor(self, r, g, b, a) self.__shadowColor = { r, g, b, a }; return self end
function FRAME.SetWordWrap(self, v) self.__wordWrap = v; return self end

-- ── textures ───────────────────────────────────────────────────────────────
--
-- SetTexture/GetTexture used to be a total round-trip: whatever went in came
-- back out, for every path ever passed. That models a client where no texture
-- can fail to load, which is the one thing this addon has repeatedly been
-- bitten by -- a path that does not exist draws nothing and RAISES NOTHING.
--
-- With a total round-trip, a `SetTexture(p); if GetTexture() then` probe
-- resolves for every path, so the addon's art ladder would take its first rung
-- every time and the atlas and ASCII rungs below it would become unreachable in
-- tests while still being the live behaviour on a client missing the file.
--
-- `mocks.setTextureLoadable(path, false)` is how a case says "this file is not
-- there". Unlisted paths still load, so every existing case is unaffected.
-- File scope because FRAME is, but WIPED PER BUILD below -- an instance that
-- marked a path missing must not leave it missing for the next one.
local unloadable = {}

function FRAME.SetTexture(self, t)
    self.__texture = t
    if t ~= nil then self.__atlas = nil end
    return self
end
function FRAME.GetTexture(self)
    local t = self.__texture
    if type(t) == "string" and unloadable[t] then return nil end
    return t
end
--- A texture is EITHER a file or an atlas, never both, and the mock has to say
--- so: the addon's art ladder tries a file and then an atlas on the SAME
--- texture, and if setting one did not clear the other a test could not tell
--- which rung had won.
---
--- `GetAtlas` used to be undefined, which meant the PascalCase catch-all
--- answered the texture object itself -- truthy, so `assertTrue(t:GetAtlas())`
--- passed whatever happened, and `assertEqual(t:GetAtlas(), "name")` failed with
--- `<table>`. core/Diagnostics.lua prints this value, so a live report was
--- carrying `table: 0x...` where an atlas name belonged.
function FRAME.SetAtlas(self, a)
    self.__atlas = a
    self.__texture = nil
    return self
end
function FRAME.GetAtlas(self) return self.__atlas end
function FRAME.SetTexCoord(self, ...) self.__texCoord = { ... }; return self end
function FRAME.GetTexCoord(self)
    local c = self.__texCoord
    if not c then return nil end
    return c[1], c[2], c[3], c[4]
end
function FRAME.SetColorTexture(self, r, g, b, a)
    self.__colorTexture = { r, g, b, a or 1 }
    return self
end
function FRAME.SetVertexColor(self, r, g, b, a)
    self.__vertexColor = { r, g, b, a or 1 }
    return self
end
function FRAME.SetDrawLayer(self, layer, sub) self.__drawLayer = { layer, sub }; return self end
function FRAME.SetNormalTexture(self, t) self.__normalTexture = t; return self end
function FRAME.SetDesaturated(self, v) self.__desaturated = v and true or false; return self end
function FRAME.SetHitRectInsets(self, l, r, t, b)
    self.__hitRect = { l, r, t, b }
    return self
end
-- Resize bounds, as the client models them: the frame refuses to be sized below
-- the minimum, which is what modules/Window.lua leans on instead of clamping in
-- Lua on every OnSizeChanged tick.
function FRAME.SetResizeBounds(self, minW, minH, maxW, maxH)
    self.__resizeBounds = { minW = minW, minH = minH, maxW = maxW, maxH = maxH }
    return self
end
function FRAME.GetResizeBounds(self)
    local b = self.__resizeBounds
    if not b then return nil end
    return b.minW, b.minH, b.maxW, b.maxH
end
function FRAME.SetHighlightTexture(self, t) self.__highlightTexture = t; return self end
function FRAME.SetPushedTexture(self, t) self.__pushedTexture = t; return self end
function FRAME.SetDisabledTexture(self, t) self.__disabledTexture = t; return self end

-- ── backdrop ───────────────────────────────────────────────────────────────
function FRAME.SetBackdrop(self, b) self.__backdrop = b; return self end
function FRAME.GetBackdrop(self) return self.__backdrop end
function FRAME.SetBackdropColor(self, r, g, b, a)
    self.__backdropColor = { r, g, b, a or 1 }
    return self
end
function FRAME.SetBackdropBorderColor(self, r, g, b, a)
    self.__backdropBorderColor = { r, g, b, a or 1 }
    return self
end

-- ── status bar ─────────────────────────────────────────────────────────────
--
-- The four setters a secret meter value legally reaches. Values are stored
-- UNTOUCHED — no tonumber, no comparison, no default substitution — because the
-- C side is the layer allowed to look and this stub is standing in for it.
--
-- The optional trailing `interpolation` (patch 12.0, an Enum.StatusBarInterpolation)
-- is recorded beside the value, so a suite can assert which setters animate
-- (issue #23). Absent is recorded as nil, which is the client's `Immediate`.
function FRAME.SetMinMaxValues(self, mn, mx, interpolation)
    self.__min, self.__max = mn, mx
    self.__minMaxInterpolation = interpolation
    return self
end
function FRAME.GetMinMaxValues(self) return self.__min, self.__max end
function FRAME.SetValue(self, v, interpolation)
    self.__value = v
    self.__valueInterpolation = interpolation
    self.__setValueCount = (self.__setValueCount or 0) + 1
    -- Mirror the client's HasSecretValues marking: a bar handed a secret has
    -- secret geometry from then on, and rule R3 says nothing may read it back.
    -- Recorded rather than enforced, so a suite can assert the rule rather than
    -- discover it as a crash.
    if isSimulatedSecret(v) then self.__hasSecretValues = true end
    return self
end
function FRAME.GetValue(self) return self.__value end
function FRAME.HasSecretValues(self) return self.__hasSecretValues and true or false end
function FRAME.SetStatusBarColor(self, r, g, b, a)
    self.__barColor = { r, g, b, a or 1 }
    return self
end
function FRAME.GetStatusBarColor(self)
    local c = self.__barColor
    if not c then return 1, 1, 1, 1 end
    return c[1], c[2], c[3], c[4]
end
function FRAME.SetStatusBarTexture(self, t)
    self.__barTexture = t
    if type(t) == "table" then
        self.__barTextureObj = t
    else
        self.__barTextureObj = self.__barTextureObj or makeFrame("Texture", self)
        self.__barTextureObj.__texture = t
    end
    return self
end
function FRAME.GetStatusBarTexture(self)
    self.__barTextureObj = self.__barTextureObj or makeFrame("Texture", self)
    return self.__barTextureObj
end
function FRAME.SetOrientation(self, v) self.__orientation = v; return self end
function FRAME.GetOrientation(self) return self.__orientation end
function FRAME.SetReverseFill(self, v) self.__reverseFill = v and true or false; return self end
function FRAME.GetReverseFill(self) return self.__reverseFill and true or false end

-- ── child regions ──────────────────────────────────────────────────────────
--
-- DISTINCT objects, recorded in creation order. The base returns the parent
-- itself; here a cell's bar, its background texture and its two FontStrings must
-- be four different things or modules/Row.lua's left/right text slots are one
-- slot and every text assertion is vacuous.
local function createRegion(self, objectType, template)
    local r = makeFrame(objectType, self)
    r.__template = template
    self.__regions[#self.__regions + 1] = r
    return r
end
function FRAME.CreateTexture(self, _name, layer, template, sublevel)
    local r = createRegion(self, "Texture", template)
    -- The SUBLEVEL is recorded as well as the layer. Two textures on one layer
    -- have no defined draw order between them, so "which of these is on top" is
    -- only answerable when the sublevel is known -- and modules/Row.lua's cell
    -- border is exactly that question (it was drawn under the bar it outlines).
    r.__layer = layer
    r.__sublevel = sublevel
    return r
end
function FRAME.CreateFontString(self, _name, layer, template)
    local r = createRegion(self, "FontString", template)
    r.__layer = layer
    r.__template = template
    return r
end
function FRAME.CreateLine(self) return createRegion(self, "Line", nil) end
function FRAME.CreateMaskTexture(self) return createRegion(self, "MaskTexture", nil) end
function FRAME.GetRegions(self) return unpack(self.__regions) end

-- ── scripts / events ───────────────────────────────────────────────────────
--
-- Handlers are STORED, and `_run` / `_fire` drive them. modules/Window.lua's
-- entire refresh clock is an OnUpdate, so a no-op SetScript would make the
-- throttle — the addon's single most important performance property —
-- unreachable from a test.
function FRAME.SetScript(self, which, fn)
    self.__scripts[which] = fn and { fn } or nil
    if which == "OnEvent" then self.__onEvent = fn end
    return self
end
function FRAME.HookScript(self, which, fn)
    local list = self.__scripts[which]
    if not list then list = {}; self.__scripts[which] = list end
    list[#list + 1] = fn
    return self
end
function FRAME.GetScript(self, which)
    local list = self.__scripts[which]
    return list and list[1]
end
function FRAME._run(self, which, ...)
    local list = self.__scripts[which]
    if not list then return end
    for _, fn in ipairs(list) do fn(self, ...) end
end
--- Alias for the kit's own spelling, so a suite written against the base's
--- `__fire` keeps working.
function FRAME.__fire(self, which, ...) return self:_run(which, ...) end
function FRAME._fire(self, ev, ...)
    if self.__onEvent then self.__onEvent(self, ev, ...) end
end
function FRAME.RegisterEvent(self, ev) self.__events[ev] = true; return self end
function FRAME.RegisterUnitEvent(self, ev, ...) self.__events[ev] = { ... }; return self end
function FRAME.UnregisterEvent(self, ev) self.__events[ev] = nil; return self end
function FRAME.UnregisterAllEvents(self) self.__events = {}; return self end
function FRAME.IsEventRegistered(self, ev) return self.__events[ev] ~= nil end

local frameSeq = 0

--- Build a frame-shaped stub.
---
--- `objectType` mirrors CreateFrame's first argument, or "Texture" /
--- "FontString" for a region. `parent` wires the chain IsVisible and
--- GetEffectiveScale walk.
function makeFrame(objectType, parent, name)
    frameSeq = frameSeq + 1
    local f = {
        __objectType = objectType or "Frame",
        __name       = name or ("MultiMetersMockFrame" .. frameSeq),
        __parent     = parent,
        __shown      = true,   -- CreateFrame'd frames start shown
        __points     = {},
        __regions    = {},
        __scripts    = {},
        __events     = {},
        __w = 0, __h = 0, __scale = 1, __alpha = 1, __level = 0,
    }
    return setmetatable(f, {
        __index = function(_, k)
            local m = FRAME[k]
            if m ~= nil then return m end
            local n = NUMERIC_GETTERS[k]
            if n ~= nil then return function() return n end end
            -- WoW frame methods are PascalCase; addon-stored data fields are not
            -- (`frame.mmWindow`, `bar.mmCell`, `cell.showBar`). Answer a no-op
            -- method for the former and nil for the latter — a real frame returns
            -- nil for an unset field, and returning a callable there is how an
            -- unset `self.__whatever` silently becomes truthy.
            if type(k) == "string" and k:match("^%u") then
                return function() return f end
            end
            return nil
        end,
    })
end

-- ===========================================================================
-- GameTooltip
-- ===========================================================================
--
-- Installed onto a mock instance rather than built at file scope, because the
-- tooltip is per-build state -- its recorded line list, its owner and the
-- GameTooltipTextLeft/Right<N> line widgets all have to be fresh for every
-- instance, and the line widgets are registered on the mock table itself so
-- `_G["GameTooltipTextLeft3"]` resolves through it.
--
-- It lives in this file rather than in the builder because it is frame modelling:
-- a real widget object with real state, for the same reason everything above is.

--- Install GameTooltip, its line widgets and its two companions onto `M`.
---
--- @param M table  the mock instance under construction
local function installTooltip(M)
    -- GameTooltip with a RECORDED line list. modules/Tooltip.lua's whole output is
    -- AddLine / AddDoubleLine calls, so a no-op tooltip would make every tooltip
    -- case pass without asserting anything.
    local tooltip = makeFrame("GameTooltip", nil, "GameTooltip")
    tooltip.__lines = {}
    -- GAMETOOLTIP IS BLIZZARD'S, AND THIS ADDON'S EXECUTION IS TAINTED.
    --
    -- Measured in game: `GameTooltipTextLeft5:GetStringWidth()` answers a SECRET
    -- number even when every value on the line is plainly readable — the error
    -- reads "while execution tainted by 'MultiMeters'". So it is not our own
    -- secrets propagating; it is that tainted code may not measure inside a
    -- shared Blizzard frame at all, whatever is in it.
    --
    -- Marking the tooltip itself is what makes `inheritsSecret` cover every line
    -- widget and every carrier we park inside it, which is the real rule: layout
    -- in here is computed from config and never read back (rule R3).
    tooltip.__hasSecretValues = true
    -- The OFFSET PAIR is recorded, not dropped. `tooltip.offsetX/offsetY` reach
    -- the client only through these two arguments — the addon deliberately never
    -- places the tooltip itself — so a SetOwner that ignored them would make the
    -- entire setting untestable while looking implemented.
    function tooltip:SetOwner(owner, anchor, x, y)
        self.__owner, self.__anchor = owner, anchor
        self.__ownerX, self.__ownerY = x, y
        return self
    end
    function tooltip:GetOwner() return self.__owner end

    -- SHOW RE-ANCHORS THE TOOLTIP TO ITS OWNER, and modelling that is the whole
    -- reason this override exists. The client does it -- it is the same pass that
    -- re-fonts the tooltip's lines, which modules/Tooltip.lua already works around
    -- with `reapplyFonts` -- so a point set BEFORE the lines were added is
    -- silently thrown away.
    --
    -- A mock whose Show kept our points made the anchor setting look implemented
    -- while the player got Blizzard's token placement instead: "Top left" sat
    -- directly above the cell growing right, and no anchor produced the box beside
    -- it at all. The suite was green throughout. Modelling the awkward behaviour
    -- rather than the convenient one is rule 5 of the mock's own header.
    function tooltip:Show()
        -- The base frame's Show, not a replacement for it: OnShow has to fire on
        -- the hide->show TRANSITION, because a suite case models a tooltip skin
        -- that re-fonts every line from that hook.
        local was = self.__shown
        self.__shown = true
        -- The re-anchor, before the hook rather than after: the client has placed
        -- the tooltip by the time anything watching OnShow sees it.
        self.__points = {}
        if not was then self:_run("OnShow") end
        return self
    end
    function tooltip:ClearLines() self.__lines = {}; return self end
    -- PER-LINE FONTSTRINGS, under the client's own global names.
    --
    -- `GameTooltipTextLeft3` / `TextRight3` are how an addon anchors anything to a
    -- tooltip line, and modules/Tooltip.lua's spell bars are anchored between the
    -- two. A stub with no line widgets made those bars silently undrawable — the
    -- code ran, found nil, and returned, which is a real failure mode wearing a
    -- passing test.
    local function lineWidgets(index)
        local leftName  = "GameTooltipTextLeft"  .. index
        local rightName = "GameTooltipTextRight" .. index
        -- Registered on the MOCK TABLE, not just in the by-name index: an addon
        -- reaches these through `_G["GameTooltipTextLeft3"]`, and `mocks._G`
        -- resolves through this table (see the C_AddOns note above).
        if not M[leftName] then
            M[leftName]  = makeFrame("FontString", tooltip, leftName)
            M[rightName] = makeFrame("FontString", tooltip, rightName)
            -- The real ones inherit GameTooltipText, so they HAVE a font and
            -- SetText works on them. Without this the writes below raise the
            -- mock's own "Font not set" guard.
            M[leftName].__template  = "GameTooltipText"
            M[rightName].__template = "GameTooltipText"
            M.__frameByName[leftName]  = M[leftName]
            M.__frameByName[rightName] = M[rightName]
        end
        return M[leftName], M[rightName]
    end

    -- The TEXT REACHES THE LINE WIDGETS, not just the recorded line list.
    -- modules/Tooltip.lua widens the tooltip from the longest spell name, which it
    -- measures off GameTooltipTextLeft<N> — and a widget the mock never wrote to
    -- measures zero, which turned that whole path into a no-op that still passed.
    function tooltip:AddLine(text, r, g, b)
        self.__lines[#self.__lines + 1] = { text = text, r = r, g = g, b = b }
        local left, right = lineWidgets(#self.__lines)
        left:SetText(text)
        right:SetText(nil)
        return self
    end
    function tooltip:AddDoubleLine(leftText, rightText, lr, lg, lb, rr, rg, rb)
        -- THE COLORS ARE RECORDED, not discarded. The name tooltip colors both
        -- sides of its lines through these arguments rather than through a
        -- `|cff…` escape — an escape is a concatenation and the amount may be a
        -- secret — so a mock that drops them leaves the coloring untestable.
        self.__lines[#self.__lines + 1] = {
            text = leftText, right = rightText, double = true,
            leftColor = { lr, lg, lb }, rightColor = { rr, rg, rb },
        }
        local left, right = lineWidgets(#self.__lines)
        left:SetText(leftText)
        right:SetText(rightText)
        return self
    end
    function tooltip:NumLines() return #self.__lines end
    -- The client's own spell tooltip. It REPLACES the content, which is why the
    -- addon treats it as the last word rather than something to add lines to —
    -- so the double records what it was asked for and clears the line list.
    function tooltip:SetSpellByID(id)
        self.__spellID = id
        self.__lines = {}
        return true
    end
    -- The tooltip sizes itself from its own text, and modules/Tooltip.lua's amount
    -- and share slots are NOT its text — they are addon widgets. So the addon
    -- widens the frame itself, and has to put the width back afterwards or the
    -- next addon's item tooltip inherits it. A no-op stub would make both halves
    -- of that unassertable.
    function tooltip:SetMinimumWidth(w) self.__minWidth = w or 0; return self end
    function tooltip:GetMinimumWidth() return self.__minWidth or 0 end
    -- Line spacing is a property of the SHARED tooltip, exactly like the minimum
    -- width above, and it is left behind the same way — so it is recorded for the
    -- same reason: "did the addon put it back" has to be a question a suite can
    -- ask.
    function tooltip:SetCustomLineSpacing(s) self.__lineSpacing = s or 0; return self end
    function tooltip:GetCustomLineSpacing() return self.__lineSpacing or 0 end
    M.GameTooltip = tooltip
    -- The font object GameTooltip's own line FontStrings inherit, and the one
    -- modules/Tooltip.lua restores them to. A plain sentinel table: nothing reads
    -- through it, and identity is the whole assertion.
    M.GameTooltipText = { __fontObject = "GameTooltipText" }
    M.GameTooltip_SetDefaultAnchor = function() end
end

return {
    makeFrame      = makeFrame,
    unloadable     = unloadable,
    installTooltip = installTooltip,
}
