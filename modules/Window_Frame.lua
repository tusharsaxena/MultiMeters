-- modules/Window_Frame.lua
--
-- How ONE window's frames are built and dressed: the anchor/visible pair, the
-- drag bar, the body, the strips and the grip (BuildFrame, once per window), and
-- ApplyConfig, the one path a settings change takes onto them, with the edge and
-- fill it paints (ApplyBorder) and the surface-color reader the header shares.
--
-- ---------------------------------------------------------------------------
-- WHY THIS IS ITS OWN FILE
-- ---------------------------------------------------------------------------
--
-- modules/Window.lua stood at exactly layout-§1's 1500-line cap, and the owner
-- ruled it split before its next change (MM-04, 2026-10-31). Build-and-apply is
-- the half of the loop that runs on a settings change and never on a refresh, so
-- it is the cut that leaves each side readable on its own. Rule R3 did not move:
-- it is stated in modules/Window.lua's header, and nothing here reads geometry
-- back off a frame. Only these functions moved, unchanged.
--
-- FILE-SCOPE READS, and why the TOC line is load-bearing. This file resolves
-- NS.WindowProto, NS.WindowFontPath, NS.WindowModule and NS.WindowInternals'
-- `clamp` and `lsm`, all published by modules/Window.lua, so it MUST load after
-- it. It publishes NS.SurfaceColor, which modules/Window_Header.lua resolves at
-- file scope, so it MUST load before that file.

local _, NS = ...

local Const = NS.Constants
local L     = NS.L

-- LibKa0s-Widgets-1.0, for the test-mode and sim strips BuildStrips/BuildFrame make.
-- Optional: with no library the window builds without a strip (modules/Window.lua).
local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

local WindowProto = NS.WindowProto
local fontPath    = NS.WindowFontPath
local mod         = NS.WindowModule
local clamp       = NS.WindowInternals.clamp
local lsm         = NS.WindowInternals.lsm

--- The LSM border texture the player picked, or nil for "no border at all".
---
--- "NONE" IS ANSWERED HERE, BEFORE THE FALLBACK, and that distinction is the
--- whole shape of this function. `nil` and `""` and LSM's own `"None"` are a
--- CHOICE — the player asked for no edge — and the answer is nil. A name that is
--- present but cannot be fetched is a FAILURE, most often a media pack that is no
--- longer installed, and that falls back to the SKIN's own edge rather than to
--- a literal: `fallback` is the edge file the skin's Shell just wrote onto the
--- backdrop (ApplyBorder), and restating it here would be the copy that goes
--- stale one hex digit at a time.
---
--- Conflating the two is what handed a player who picked "None" the Ka0s edge
--- they had just turned off. Same rule, same order, as modules/Tooltip.lua's
--- `mediaPath` — the addon's other LSM resolver, and the other surface with a
--- border setting on it.
-- The collection's one class-color reader (core/Namespace.lua), resolved
-- defensively like every other seam member this file takes.
local PlayerClassRGB = NS.PlayerClassRGB or function() return nil end

-- Forward-declared because the window's own backdrop and border read it from
-- ApplyBorder, which is written above the header surfaces it was extracted for.
-- Defined once, below, beside the other color readers.
local surfaceColor

local function borderPath(name, fallback)
    if type(name) ~= "string" or name == "" or name == "None" then return nil end
    local media = lsm()
    local path = media and media:Fetch("border", name, true)
    return path or fallback
end

-- THE WINDOW WEARS ITS OWNER'S SKIN (skinning-§1): S.Shell through the facade,
-- with no top bar (the header strip is the window's own). The EDGE is the skin's
-- while `frame.borderColorMode` is `skin` (the shipped mode, MM-A1: the Shell
-- draws `win.border` in `win.borderStyle` / `win.borderSize` with `win.inner`);
-- under `class` or `custom` the Shell draws none and ApplyBorder draws the
-- player's. Core's ApplySkin first, owner-less, because it builds the
-- `innerBorder` child ApplyBorder shows with the player's edge. Shell records the
-- LAST options it was handed, so a skin switch replays the current mode and then
-- fires OnLooksChanged, whose listener (modules/WindowManager.lua) re-runs
-- ApplyConfig, and with it ApplyBorder, over the new skin.
-- Without the library (NS.SKIN_LIVE false) there is no Shell to draw an edge,
-- so `skin` falls back to the player's, the pre-skin look (DEGRADED-11).
local SHELL_SKIN_EDGE = { noTopBar = true }
local SHELL_OWN_EDGE  = { noTopBar = true, noBorder = true }
local function skinEdge(frameCfg)
    return (frameCfg or {}).borderColorMode == "skin" and NS.SKIN_LIVE == true
end
local function paintShell(frame, frameCfg)
    if NS.ApplySkin then NS.ApplySkin(frame) end
    local opts = skinEdge(frameCfg) and SHELL_SKIN_EDGE or SHELL_OWN_EDGE
    if NS.Skin and NS.Skin.Shell then NS.Skin.Shell(frame, opts) end
end

-- Taken from the CORE SEAM (core/CoreSetup.lua publishes NS.RGBA), not from a
-- second LibStub lookup carrying its own copy of the library's channel reader —
-- the same note applies in modules/Row.lua, which is precisely the file the copy
-- was duplicated with. Resolved defensively so a degraded install renders in the
-- caller's default colors instead of raising.
local RGBA = NS.RGBA or function(_, dr, dg, db, da)
    return dr, dg, db, da
end

-- The bounds each `master.*` multiplier is clamped to, matched to the sliders that
-- write them (settings/Schema.lua's Master controls block). Clamped rather than
-- trusted for the reason every other slider read in this file is: the value can
-- also arrive from `/mm set` or from a hand-edited SavedVariables, and a scale of
-- 0 is a window nobody can find again.
local MASTER_BOUNDS = {
    scale = { 0.5, 2.0 },
    alpha = { 0, 1 },
}

--- One addon-wide master control, defaulted and clamped.
---
--- Through defaults/Profile.lua's ONE reader (NS.MasterSetting), which falls back
--- to the shipped value rather than to a literal here -- the same bargain
--- `NS.DataSetting` gets, and for the same reason: a second copy of 1.0 in a module
--- is a value that can drift from the schema row that claims to set it.
---
--- @param key string  scale | alpha
local function masterSetting(key)
    local read = NS.MasterSetting
    local v = read and read(key)
    local bounds = MASTER_BOUNDS[key]
    if not bounds then return v end
    return clamp(v, bounds[1], bounds[2])
end
-- ---------------------------------------------------------------------------
-- Frame construction
-- ---------------------------------------------------------------------------

local function onDragStart(frame)
    local inst = frame.mmWindow
    if not inst or inst.locked then return end
    inst:BringToFront()
    inst.anchor:StartMoving()
end

local function onDragStop(frame)
    local inst = frame.mmWindow
    if not inst then return end
    inst.anchor:StopMovingOrSizing()
    inst:SavePosition()
end

local function onSizeChanged(anchor, width, height)
    -- The handler ARGUMENTS are the new size. Taking them here rather than
    -- calling GetWidth later means the resize path never asks a frame a
    -- question, which keeps the rule the same on both axes even though the
    -- anchor would in fact be safe to ask.
    local inst = anchor.mmWindow
    if not inst then return end
    inst.pendingWidth  = width
    inst.pendingHeight = height
end




--- The body frame: wheel scrolling and the right-click that leaves a breakdown.
--- Split out of BuildFrame to keep it under the CCN gate; runs once, from there.
function WindowProto:BuildBody(frame)
    self.body = CreateFrame("Frame", nil, frame)

    -- ── SCROLLING ────────────────────────────────────────────────────────────
    --
    -- NOT a ScrollFrame, and not because one would be hard. This window already
    -- draws `layout.maxRows` rows chosen out of a longer list, so scrolling is
    -- choosing a DIFFERENT window into that list — one integer, applied at the
    -- top of the render loop. A ScrollFrame would mean building every row and
    -- letting the client clip them, which is more frames, more work per refresh,
    -- and a scroll child whose height would have to be measured.
    --
    -- The offset is plain and comes from a wheel event, so nothing here reads
    -- geometry back off a frame or looks at a meter value (rules R1 and R3 are
    -- untouched).
    self.scrollOffset = 0
    self.body:EnableMouseWheel(true)

    -- RIGHT-CLICK ON EMPTY SPACE leaves a breakdown. The rows handle their own
    -- (modules/Row.lua), but a short breakdown leaves most of the body bare and
    -- "right-click anywhere" has to mean anywhere.
    --
    -- The body's mouse is enabled ONLY while a breakdown is open. There is a
    -- comment on the frame above saying the body used to take the mouse and
    -- "stole every hover from the cells underneath it" — the cells are
    -- descendants and should still win, but that was learned the hard way, so the
    -- grid keeps exactly the behavior it has today and only a drilled window
    -- changes.
    self.body:SetScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" then return end
        local D = mod("DrillDown")
        if D and D.Exit then D:Exit(self.config) end
    end)
    if self.body.RegisterForClicks then
        self.body:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    self.body:EnableMouse(false)
    self.body:SetScript("OnMouseWheel", function(_, delta)
        -- Up scrolls toward the top, which is `delta > 0` and a SMALLER offset.
        self:ScrollBy(delta > 0 and -1 or 1)
    end)
end

--- The test-mode and simulation strips. Split out of BuildFrame (CCN gate); runs once.
function WindowProto:BuildStrips(frame)
    -- THE TEST-MODE STRIP (MultiMeters#59, LibKa0s#48): a yellow band between the
    -- title and the column headers saying the numbers under it are placeholders.
    -- It is NOT part of the header, so a window with its header hidden is still
    -- marked. Born hidden; ApplyTestStrip places and shows it. No tooltip, so the
    -- mouse stays off. The red title word shows only when the strip cannot (a
    -- minimized window, or no Widgets library); the session-line `Test` stays.
    self.testStrip = W and W.TestStrip and W.TestStrip(frame, {
        text = L["TEST MODE: placeholder numbers, not your fight. Combat ends it."],
        icon = NS.Icon and NS.Icon("info"),
        -- The skin owner (LibKa0s-Widgets-1.0 16, skinning-§1): the strip's legibility follows
        -- this addon's skin through its strip.* tokens; amber stays the meaning color.
        owner = NS.name,
    }) or nil
end

--- Build the two frames, the header and the body. Runs once per window per
--- session; everything after it is re-application, never reconstruction.
function WindowProto:BuildFrame()
    if self.frame then return end

    local cfg   = self.config
    local frameCfg = cfg.frame or {}
    local name  = "MultiMetersWindow" .. tostring(self.id)

    -- The clean geometry frame. Empty on purpose — see the file header.
    local anchor = CreateFrame("Frame", name .. "Anchor", UIParent)
    anchor:SetSize(frameCfg.width or 694, frameCfg.height or 228)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(frameCfg.clampToScreen ~= false)
    anchor.mmWindow = self
    anchor:SetScript("OnSizeChanged", onSizeChanged)
    self.anchor = anchor

    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
    frame:SetMovable(true)
    -- The BODY does not take the mouse. It used to, so that the whole window
    -- dragged as one object, and that is exactly what stole every hover from the
    -- cells underneath it. Dragging is the title bar's job now (dragBar, below).
    frame:EnableMouse(false)
    -- TOPLEVEL, so overlapping windows stack whole instead of interleaving their
    -- cells and backdrops (frame-layering-§4). BringToFront does the raising.
    frame:SetToplevel(true)
    frame.mmWindow = self
    self.frame = frame

    -- The drag handle: an invisible strip over the title bar. A window is dragged
    -- from its title bar in every other frame in the game, and it is the one
    -- horizontal band of this window that no cell occupies — so dragging and
    -- hovering a number stop competing for the same clicks.
    local dragBar = CreateFrame("Frame", nil, frame)
    dragBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    dragBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    dragBar:EnableMouse(true)
    dragBar:RegisterForDrag("LeftButton")
    dragBar:SetScript("OnDragStart", onDragStart)
    dragBar:SetScript("OnDragStop",  onDragStop)
    dragBar.mmWindow = self
    self.dragBar = dragBar

    -- ESC DOES NOT CLOSE THIS WINDOW, and the frame is deliberately NOT in
    -- UISpecialFrames.
    --
    -- That list is right for a dialog you opened and will dismiss. A meter is
    -- neither: it is furniture, it is meant to sit there for a whole raid night,
    -- and Escape is a key a player presses constantly for other reasons —
    -- clearing a target, closing somebody else's frame, leaving a vehicle. Every
    -- one of those would take the meter down, and nothing about the resulting
    -- empty screen says which key did it or how to undo it.
    --
    -- Closing is therefore an explicit act: the X in the header, or `/mm toggle`.
    -- The frames are still NAMED, because a name is what `/framestack` and any
    -- other addon needs to talk about them.
    -- The title and divider members are assigned BEFORE the skin so the Shell
    -- can tint them. Their colors are deliberately never set here: the skin's
    -- tokens are the contract, and a matching literal in this file is the copy
    -- that goes stale one hex digit at a time (standalone-windows).
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    -- A font before the Shell paints it: the client gives a template-less FontString an invalid
    -- size until one is set, and the Shell scales the title's own size into the skin's font.
    -- ApplyHeader sets the player's header font over it.
    frame.title:SetFontObject("GameFontNormal")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -5)

    frame.divider = frame:CreateTexture(nil, "ARTWORK")
    frame.divider:SetHeight(1)

    -- The header strip's own background (`header.bgColor`). On the BORDER layer:
    -- above the backdrop's bgFile, which is BACKGROUND, and below the divider,
    -- which is ARTWORK — so the strip tints without swallowing the line under
    -- it. Built here rather than on first use so moving the setting re-colors a
    -- texture that already exists instead of creating one mid-frame.
    --
    -- Not a member of `frame`: the skin walks a fixed set of frame keys and an
    -- extra one is a key it has never heard of.
    self.headerBG = frame:CreateTexture(nil, "BORDER")

    paintShell(frame, self.config.frame)

    -- ── The header's controls ──
    --
    -- Built by modules/HeaderControls.lua, which owns the whole strip: which
    -- controls exist, where each sits, what art it draws from, and when it
    -- fades. This file keeps the frames they hang on and nothing else about
    -- them -- see that module's header for why the boundary sits here.
    if NS.HeaderControls then
        NS.HeaderControls:Attach(self)
        NS.HeaderControls:HookHover(self)
    end

    -- The header's own text line, and the segment selector behind it.
    --
    -- The line carries the session name, its duration and -- when the window asks
    -- for it -- the group total for the sort column, folded into one string
    -- because every piece may be a secret and only `..` may join those.
    --
    -- IT TAKES NO MOUSE, and that is a deliberate removal. It used to be a
    -- Button carrying the segment dropdown, sized to a fixed 220px so the text
    -- could be right-justified inside it — which put an INVISIBLE CLICK TARGET
    -- across the middle of the header. It glowed red on hover, it opened a menu
    -- from a patch of empty title bar, and nothing on screen said it was there.
    -- Sizing it to its own text instead is not available: this file may not
    -- measure a widget (rule R3).
    --
    -- The dropdown did not go anywhere. The strip's segment control opens the
    -- same menu (modules/HeaderControls.lua), and it is a control a player can
    -- see, which the session line never was.
    --
    -- The FontString stays a child of this frame rather than of `frame`, because
    -- that is what lets ONE SetPoint in ApplyHeader place both.
    self.sessionLine = CreateFrame("Frame", nil, frame)

    self.sessionText = self.sessionLine:CreateFontString(nil, "OVERLAY")
    self.sessionText:SetJustifyH("RIGHT")
    self.sessionText:SetAllPoints(self.sessionLine)

    self:BuildBody(frame)

    -- The column-header strip lives on the BODY and holds plain FontStrings that
    -- never receive a value, so it is one of the few things here that could
    -- safely be measured — and still is not, for one rule rather than two.
    self.columnHeaders = {}
    self.headerFrame = CreateFrame("Frame", nil, frame)
    -- The column-header strip's backdrop. A plain texture rather than a
    -- BackdropTemplate: it is a flat fill behind text, nothing measures it, and a
    -- texture is a leaf the way the row backgrounds are. Transparent by default,
    -- so a window that never touches the setting looks exactly as it always did.
    self.headerBg = self.headerFrame:CreateTexture(nil, "BACKGROUND")
    self.headerBg:SetAllPoints(self.headerFrame)

    -- The meter-unavailable notice. Built once and kept hidden: it replaces the
    -- rows entirely when C_DamageMeter has nothing to give (design §6), and a
    -- window that has to build a panel at the moment it discovers a failure is a
    -- window that fails twice.
    self.notice = frame:CreateFontString(nil, "OVERLAY")
    self.notice:SetJustifyH("CENTER")
    self.notice:Hide()

    self:BuildStrips(frame)
    -- THE SIMULATION STRIP (MultiMeters#60): the same strip in its sim flavor (its
    -- own tint), in the same slot, shown while a /mm sim session runs. It replaces
    -- any title word for the simulation: there is none (OWNER_SCOPE A).
    self.simStrip = W and W.TestStrip and W.TestStrip(frame, {
        kind = "sim",
        text = L["SIMULATION: a scripted fight, not your data. /mm sim stop ends it."],
        icon = NS.Icon and NS.Icon("info"),
        owner = NS.name,
    }) or nil

    -- ALWAYS BUILT, never gated on a setting. There used to be a `resizeGrip`
    -- checkbox read right here, and because BuildFrame runs ONCE per window,
    -- unticking it did nothing at all until a reload -- the reported bug. The
    -- grip's visibility is the LOCK's answer and only the lock's: ApplyLock and
    -- ApplyMinimized are its two authors and both ask the same question.
    --
    -- THE LIBRARY'S GRIP (Core.MakeResizable, Core minor 10), split the way rule
    -- R3 needs it: it SIZES the bare anchor, which also takes SetResizable and
    -- the bounds, but is DRAWN on the art frame (`gripParent`), so it shares the
    -- window's strata, alpha and rule-driven visibility. The profile is written
    -- on release only (`onResizeStop`, issue #49): the library's `onResize` runs
    -- on every size tick and on the programmatic SetSize in ApplyConfig, so it is
    -- not passed. `canResize` refuses a locked window even if something shows the
    -- grip later. ApplyResizeBounds runs after this in every ApplyConfig and owns
    -- the bounds from then on; the minimum here is the same layout figure. With
    -- no library, or a Core below 10, NS.MakeResizable answers nil: no grip.
    do
        local layout = self.layout or self:BuildLayout()
        self.grip = NS.MakeResizable(anchor, {
            gripParent   = frame,
            minWidth     = layout.minWidth,
            minHeight    = layout.minHeight,
            canResize    = function() return not self.locked end,
            onResizeStop = function() self:SaveSize() end,
        })
    end

    frame:Hide()
end

-- ---------------------------------------------------------------------------
-- Applying config to the frames
-- ---------------------------------------------------------------------------

--- Push the whole config onto the widgets: geometry, chrome, header, column
--- headers and every pooled row. Idempotent, and the ONE path a settings change
--- takes — so "did I remember to re-apply X" has a single answer.
function WindowProto:ApplyConfig()
    self:BuildFrame()
    self:RefreshUpvalues()

    local cfg      = self.config
    local frameCfg = cfg.frame or {}
    local layout   = self.layout
    local frame    = self.frame

    -- NEVER BELOW THE LAYOUT'S OWN FLOOR. The Height slider goes to 60 and the
    -- floor (title bar, column labels, one row) is 70 shipped since the bar grew
    -- to 30px, so a stored height under it drew the one row the layout always
    -- reserves hanging past the frame's bottom edge. The stored value is left
    -- alone; only the drawn size is held at the floor the resize grip keeps.
    local height = math.max(frameCfg.height or 228, layout.minHeight or 0)
    self.anchor:SetSize(frameCfg.width or 694, height)
    self.anchor:SetClampedToScreen(frameCfg.clampToScreen ~= false)
    self:ApplyPosition()

    -- BOTH FRAMES, and that is what makes Scale scale the WINDOW rather than only
    -- its contents.
    --
    -- The visible frame is pinned TOPLEFT and BOTTOMRIGHT to the anchor, so the
    -- anchor's screen rect dictates its screen rect whatever scale it carries.
    -- Scaling the frame alone therefore left the box exactly the size it was and
    -- shrank everything inside it: at 0.5 you got a full-size window with a
    -- miniature grid in the corner of it, which is the bug as reported.
    --
    -- Scaling the anchor takes its screen rect to width*scale by height*scale;
    -- the frame, at the same scale, then measures width by height in its own
    -- units and lays its rows out against the numbers the player set. One scale
    -- on both, and every part of the window changes size together.
    --
    -- BOTH SCALES COMPOSE, AND SO DO BOTH ALPHAS. `master.scale` and `master.alpha`
    -- (General -> Master controls) are addon-wide MULTIPLIERS over this window's own
    -- Scale and Opacity, which stay on the Frame page and stay per-window -- so a
    -- window at 0.80 under a master of 0.50 draws at 0.40, and turning the master
    -- back to 1.00 gives every window exactly the size it was set to. Multiplying
    -- rather than choosing is what lets one control shrink a whole layout without
    -- flattening the differences the player set between its windows.
    local scale = (frameCfg.scale or 1.0) * masterSetting("scale")
    self.anchor:SetScale(scale)
    frame:SetScale(scale)
    frame:SetAlpha((frameCfg.alpha or 1.0) * masterSetting("alpha"))
    frame:SetFrameStrata(frameCfg.strata or Const.LAYERS.STRATA.HUD)

    -- The skin is re-applied rather than patched: the Shell owns the backdrop,
    -- the inner border and the two accent tints, and re-running it is how a
    -- re-skinned library lands here without this file knowing what changed.
    -- ApplyBorder then layers the player's edge over the result — in that order,
    -- because the skin is the base look and the setting is the override.
    paintShell(frame, frameCfg)
    self:ApplyBorder(frameCfg)

    self:ApplyHeader()

    -- The body is placed from config, and everything below it hangs off the body
    -- rather than off a sibling — one anchor chain, one direction, no cycles.
    local pad = layout.padding
    local _, _, bodyTop = self:ChromeOffsets()
    self.body:ClearAllPoints()
    self.body:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -bodyTop)
    self.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)

    self.notice:ClearAllPoints()
    self.notice:SetPoint("TOPLEFT", self.body, "TOPLEFT", 4, -8)
    self.notice:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -4, -8)
    self.notice:SetFont(fontPath(NS.SkinMediaKey(cfg.header or {}, "font", "hud.font")),
        NS.SkinHudFontSize((cfg.text or {}).size or 11, (cfg.header or {}).fontFromSkin), "")
    -- The notice's text in the skin's highlight (white under Ka0s Default, the
    -- stock FontString color it always drew); re-run on every skin switch.
    if NS.SkinColor then self.notice:SetTextColor(NS.SkinColor("text.highlight")) end

    self:PlaceTestStrip()

    for _, row in ipairs(self.pool.all) do
        row:ApplyLayout(layout)
    end
    self:ApplyResizeBounds()
    self:ApplyLock()
    self:ApplyMinimized()
end

--- The window edge and fill: `frame.borderStyle`, `borderSize`, `borderColor`
--- and `backdropColor`, each under its mode (`skin` | `class` | `custom`).
---
--- UNDER `skin` THE EDGE IS THE SHELL'S, and this writes no backdrop at all: the
--- Shell has drawn the skin's edge ring and inner rule on its edge holder and
--- left the backdrop's own edge clear, so the only thing left to set is the fill.
---
--- UNDER `class` / `custom` IT IS LAYERED OVER THE SKIN. The Shell, told to draw
--- no edge, has written its own backdrop -- bgFile, insets -- and this rewrites
--- ONE part of that table: the edge. The fill texture and the fallback edge are
--- read back off that backdrop rather than restated as literals here (no window
--- here holds a meter value, so the read is not R3's).
---
--- `borderSize == 0` means "no edge", and it drops edgeFile with it: a zero
--- edgeSize with a texture still present is the combination WoW draws as a hard
--- 1px line. A borderStyle of "None" means the same thing and is `borderPath`'s
--- answer, not this function's.
---
--- THE SKIN'S INNER HIGHLIGHT GOES WITH THE PLAYER'S EDGE. LibKa0s's ApplySkin
--- builds a 1px `frame.innerBorder` child inset inside the edge, a child frame
--- rather than part of the backdrop, so with the style set to None and the
--- thickness at 0 it was the whole visible border. It is shown exactly when there
--- is an edge for it to sit inside, in the skin's `win.inner`.
---
--- Core's inner rule, shown exactly when the player's edge is drawn, in `win.inner`.
--- Type-tested, not truth-tested: `innerBorder` is a key LibKa0s writes onto a frame
--- this file does not own, and a mock that answers every key with a function would
--- otherwise be indexed as a frame.
local function showInnerRule(frame, edge)
    local inner = frame.innerBorder
    if not (type(inner) == "table" and inner.SetShown) then return end
    inner:SetShown(edge ~= nil)
    if edge and inner.SetBackdropBorderColor and NS.Skin then
        local r, g, b, a = NS.Skin.Color("win.inner")
        if r then inner:SetBackdropBorderColor(r, g, b, a) end
    end
end

--- The player's edge (`class` / `custom`), over the backdrop the Shell just wrote. Split out of
--- ApplyBorder for the CCN gate.
local function applyOwnEdge(frame, frameCfg)
    local base = frame.GetBackdrop and frame:GetBackdrop() or nil
    base = type(base) == "table" and base or {}
    local size = clamp(frameCfg.borderSize or 2, 0, 32)
    local edge = (size > 0) and borderPath(frameCfg.borderStyle, base.edgeFile) or nil
    local inset = edge and size or 0
    showInnerRule(frame, edge)

    frame:SetBackdrop({
        bgFile   = base.bgFile,
        edgeFile = edge,
        edgeSize = edge and size or nil,
        insets   = { left = inset, right = inset, top = inset, bottom = inset },
    })
    if edge and frame.SetBackdropBorderColor then
        local er, eg, eb, ea = surfaceColor(frameCfg.borderColorMode, frameCfg.borderColor,
            nil, 0, 0, 0, 1)
        frame:SetBackdropBorderColor(er, eg, eb, ea)
    end
end

--- @param frameCfg table  the window's `frame` config group
function WindowProto:ApplyBorder(frameCfg)
    local frame = self.frame
    if not frame.SetBackdrop then return end
    local looks = self.skinLooks or {}

    -- BOTH SWATCHES ANSWER A MODE (options-ui-§17). `skin` is the skin's own
    -- (`win.bg`, cached in skinLooks; the edge is the Shell's), `class` the LOCAL
    -- player's -- a window's fill and its edge belong to the WINDOW rather than to
    -- any row in it -- and `custom` the swatch. No "per statistic": over one
    -- surface spanning the whole window it could only mean the sort column's
    -- color, already on screen twice. The configured alpha survives `class`,
    -- which is what makes the shipped 0.75 a tint rather than a slab.
    local br, bg, bb, ba = surfaceColor(frameCfg.backdropColorMode, frameCfg.backdropColor,
        nil, 0, 0, 0, 0.75, looks.winBg)

    if not skinEdge(frameCfg) then applyOwnEdge(frame, frameCfg) end
    if frame.SetBackdropColor then frame:SetBackdropColor(br, bg, bb, ba) end
end

--- Resolve one of the header surfaces' three color modes.
---
--- ONE READER FOR BOTH HEADER STRIPS AND BOTH OF THEIR BACKGROUNDS, because they
--- are one question asked four times and four private answers is how the title
--- bar and the strip under it end up disagreeing about what "class" means.
---
--- `class` IS THE LOCAL PLAYER'S. A header is about the WINDOW rather than about
--- any one row, so yours is the only class it can sensibly mean. (A cell answers
--- the same setting with the class of the row it is drawing; see
--- modules/Row.lua's ApplyEntryTextColor.)
---
--- `stat` IS THE SORT COLUMN'S — the statistic the grid is currently ranked by,
--- which is the only statistic the title bar is about. The column-header strip
--- passes its own column's key instead, and is the one surface where "per
--- statistic" is literally per column.
---
--- `skin` IS THE SKIN'S TOKEN, alpha included, handed in already resolved
--- (`skin`, one of the window's cached skinLooks colors), so no caller reads a
--- token here. A caller with no token for the surface passes nil and `skin`
--- falls back to the configured color.
---
--- THE CONFIGURED ALPHA SURVIVES EVERY OTHER MODE. Neither RAID_CLASS_COLORS nor the
--- stat palette carries one, and a mode that silently reset transparency would be
--- one setting canceling another — which matters most for the two BACKGROUNDS,
--- where the alpha is what makes a color a tint rather than a slab.
---
--- A color that cannot be resolved — an unknown class, a stat with no palette
--- entry — falls back to the CONFIGURED one, which is the honest answer rather
--- than an invented hue.
---
--- @param mode string|nil    "skin" | "class" | "stat" | "custom"
--- @param stored table|nil   the configured color
--- @param statKey string|nil which statistic `stat` means here
--- @param dr number @param dg number @param db number @param da number
--- @param skin table|nil     { r, g, b, a }, the skin's color for `skin`
--- @return number r, number g, number b, number a
function surfaceColor(mode, stored, statKey, dr, dg, db, da, skin)
    local r, g, b, a = RGBA(stored, dr, dg, db, da)

    if mode == "skin" and type(skin) == "table" then
        r, g, b, a = skin[1], skin[2], skin[3], skin[4] or 1
    elseif mode == "class" then
        local cr, cg, cb = PlayerClassRGB()
        if cr then r, g, b = cr, cg, cb end
    elseif mode == "stat" then
        -- The palette through its one reader (core/Namespace.lua), which is what
        -- makes the column-header strip follow General -> Statistic colors rather
        -- than the shipped constant. Resolved to a local FIRST: `f and f(x)` is a
        -- truncating expression, and this reader answers three values.
        local StatColor = NS.StatColor
        if StatColor then
            local sr, sg, sb = StatColor(statKey)
            if sr then r, g, b = sr, sg, sb end
        end
    end

    return r, g, b, a
end

NS.SurfaceColor = surfaceColor
