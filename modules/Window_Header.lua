-- modules/Window_Header.lua
--
-- The header band of ONE window: the art it draws the sort mark with, the title
-- bar, the session line, the column labels above the grid, the sort a click on
-- one of those labels performs, and the segment selector the header dropdown
-- drives. modules/Window.lua owns the window; this file owns the strip along the
-- top of it.
--
-- ---------------------------------------------------------------------------
-- WHY THIS IS ITS OWN FILE
-- ---------------------------------------------------------------------------
--
-- modules/Window.lua was 2746 lines against layout-§1's 1500-line cap, and issue
-- #29 names the seam: the window's CHROME is separable from the window's LOOP.
-- The loop — the refresh contract, layout rule R3, the cached config, frame
-- construction, applying config, the row pool and the refresh — is ONE causal
-- chain and stayed whole over there, because splitting it would put a reader on
-- two files to follow one frame. What is here answers to nothing in it: the band
-- is computed from config and read back from nothing at all.
--
-- modules/HeaderControls.lua is both the precedent and the neighbor. The gear,
-- the padlock and the export button came out of the same band for the same
-- reason, and `HeaderControls.Style` reads `NS.HeaderStyle`, which is published
-- below.
--
-- ---------------------------------------------------------------------------
-- WHAT THIS FILE NEEDS FROM ITS SIBLING, AND WHY THE TOC POSITION IS LOAD-BEARING
-- ---------------------------------------------------------------------------
--
-- The methods below hang on the SAME `WindowProto` modules/Window.lua builds —
-- there is one window prototype, not two — so that file publishes it as
-- `NS.WindowProto` for this file and for modules/Window_Placement.lua, and for
-- nothing else. The font reader and the collaborator resolver come across the
-- same way, and the surface-color reader from modules/Window_Frame.lua (MM-04).
-- All four are resolved at FILE SCOPE, so this file MUST load after both; the TOC
-- says so at its line.

local _, NS = ...

local Const = NS.Constants
local L     = NS.L

-- The window prototype this file adds to, and the three readers its siblings keep:
-- `fontPath` because ApplyConfig sets the notice font from it too, and
-- `surfaceColor` because ApplyBorder paints the window's own backdrop with it
-- (both in modules/Window_Frame.lua; fontPath is published by modules/Window.lua).
-- One reader each rather than a second copy of the fallback chain in this file.
local WindowProto  = NS.WindowProto
local fontPath     = NS.WindowFontPath
local surfaceColor = NS.SurfaceColor
local mod          = NS.WindowModule

-- The collection's one class-color reader (core/Namespace.lua), resolved
-- defensively like every other seam member this file takes.
local PlayerClassRGB = NS.PlayerClassRGB or function() return nil end

-- Taken from the CORE SEAM (core/CoreSetup.lua publishes NS.RGBA), not from a
-- second LibStub lookup carrying its own copy of the library's channel reader.
-- Resolved defensively so a degraded install renders in the caller's default
-- colors instead of raising.
local RGBA = NS.RGBA or function(_, dr, dg, db, da)
    return dr, dg, db, da
end

-- How far up from the bottom of the tinted title band the title bar a player sees
-- ends (where a hairline divider was drawn until R4-SEP; no Ka0s window draws a
-- line under its title now). Named because `TitleBandHeight`, which the title row
-- is centered in and the drag strip spans, and the shipped 30px bar depend on it.
local BAR_INSET = 2

-- How much of the header the session line is allowed to run across, right to
-- left. A constant rather than a measurement of the text inside it: this file
-- never measures a widget (rule R3), and the line is right-justified inside it,
-- so the number only has to be wide enough for the longest string it can hold.
local SESSION_LINE_WIDTH = 220

-- The shared skinned menu (LibKa0s-Widgets-1.0), for the segment picker. Nil without the library.
local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

-- ---------------------------------------------------------------------------
-- HEADER ART, AND THE TWO WAYS IT ALREADY FAILED
-- ---------------------------------------------------------------------------
--
-- First attempt: texture paths (`Interface\Buttons\UI-SortArrow-Up`). They do
-- not exist, and a texture that fails to load draws nothing and raises nothing —
-- so the arrow was simply absent, with no error to read.
--
-- Second attempt: Unicode glyphs (BLACK UP-POINTING TRIANGLE, GEAR, LOCK). Those
-- are not in the game's default font and rendered as replacement boxes. "A glyph
-- is in the font or it renders as a box" was the reasoning, and the box is what
-- happened.
--
-- Both failures share a shape: the art was NAMED at authoring time and its
-- existence was never checked. So now it is checked at runtime — atlases through
-- Compat.FirstAtlas, which asks C_Texture.GetAtlasInfo — and underneath every
-- candidate there is an ASCII fallback, because the one thing that cannot fail is
-- a character every font has had since 1963.
--
-- The FALLBACK IS NOT A PLACEHOLDER. `v`, `^`, `*`, `#` and `>` are what this draws on
-- a client where nothing else resolves, and that is a legible header rather than
-- a row of boxes.
-- CONFIRMED PRESENT on a live 12.x client via `/mm diagnostics`, which is the
-- only reason any of these names is here. `common-dropdown-icon-sortdown`,
-- `common-icon-settings` and `common-icon-lock` were all probed and all absent —
-- they are the names that looked right and were not.
--
-- `auctionhouse-ui-sortarrow` points DOWN as shipped; the ascending form is the
-- same texture flipped vertically, which is one SetTexCoord rather than a second
-- asset to go looking for.
local SORT_ATLAS_DOWN = { "auctionhouse-ui-sortarrow" }
local SORT_ATLAS_UP   = { "auctionhouse-ui-sortarrow" }
local SORT_ASCII_DOWN = "v"
local SORT_ASCII_UP   = "^"

-- THE TOP RUNG, above both of the above, and the reason it is not simply the
-- only rung is the paragraph above: art that is NAMED at authoring time and
-- never checked is how this header failed twice. `NS.Icon` answers nil for an
-- absent library AND for a name the catalog does not ship, so the check is the
-- same call that produces the path — there is no window in which a name is
-- believed and not verified.
--
-- Two assets, not one flipped. The atlas rung flips `auctionhouse-ui-sortarrow`
-- with SetTexCoord because the client ships one arrow; the collection ships
-- both, and flipping one of a matched pair would draw an inverted glyph that
-- looks right today and stops looking right the moment the art is redrawn.
--
-- Tinted with the HEADER color rather than shipped gold, exactly as
-- BankLedger's LedgerTable.lua tints the same two marks: the art is near-white
-- by contract, and near-white beside a gold label reads as a second color
-- inside one string rather than as one control.
local SORT_MARK_DOWN = "sort-down"
local SORT_MARK_UP   = "sort-up"

-- The gear, padlock and export art moved to modules/HeaderControls.lua with the
-- controls themselves. SORT_* above stays: ApplyColumnHeaders draws the sort
-- arrow and that is this file's own, not a header control.


-- The header's lock and gear buttons, as GLYPHS rather than as textures.
--
-- Textures were the first attempt and they would not line up. Each shipped icon
-- carries its own transparent padding, so three of them at a nominal 14x14 sit at
-- three different apparent heights and the row reads as if it were assembled by
-- accident. Nudging each one by hand fixes the screenshot and breaks at the next
-- font size.
--
-- A glyph has no padding problem: three FontStrings at one size on one baseline
-- ARE aligned, by construction, and they scale with the header font instead of
-- against it. This is also what the reference screenshot is doing.

--- Click on a column header: sort by it, or reverse it.
local function onColumnClick(button)
    local inst = button.mmWindow
    if inst then inst:SortByColumn(button.mmKey) end
end

--- The font every line of the header strip is drawn in: the player's face or the
--- skin's title face (NS.SkinTitleFontKey, cause L8), its
--- size (the skin's HUD scale while the face follows it, D-09), and the outline flag
--- WoW wants as nil rather than as the string "NONE" (From skin through the Font
--- outline, D-07).
--- One reader for all three so the title, the session line and the column labels
--- can never drift onto different fonts.
---
--- @param header table  the window's `header` config group
--- @return string path, number size, string|nil flags
local function headerFont(header)
    local flags = NS.SkinFontFlags(header.outline)
    return fontPath(NS.SkinTitleFontKey(header)),
        NS.SkinHudFontSize(header.size or 12, header.fontFromSkin), flags
end

--- Which statistic the WINDOW is about, for the two header surfaces that answer
--- "per statistic" with one color rather than one per column: the sort column.
---
--- Read off the config rather than off `self.sortColumn`, so this is callable
--- from NS.HeaderStyle with a bare window and gives the same answer either way.
local function windowStat(window)
    local data = (window and window.config or {}).data
    return (data and data.sortColumn) or "DamageDone"
end

--- The header's text color, defaulting to the gold WoW uses for its own headers.
---
--- SKIN, CLASS OR CUSTOM, AND NO STATISTIC. "Per statistic" could only ever paint
--- this the SORT column's color -- a fact already on screen twice, in that
--- column's own header and in its arrow -- and the title bar is one strip over
--- the whole window rather than a thing that belongs to a column. That refusal
--- stands and is why the mode list here is the window chrome's three (skin /
--- class / custom, MM-A1) rather than the three every cell surface answers.
---
--- CLASS DID NOT SURVIVE THE SAME ARGUMENT, and the note here used to say it had:
--- that "class could only be the local player's, which the title bar is not about
--- -- it names the window". What settled it the other way is that the rest of the
--- strip already wears it. The controls take a class color (and so did the
--- divider under them, until R4-SEP removed it); a title that alone could not was the odd one out, and
--- "the header is yours" is a perfectly good thing for a player to want a window
--- to say. It is still the LOCAL player's class, because that is the only class a
--- window-wide strip can mean.
---
--- The configured ALPHA survives the mode, the same rule every other surface in
--- this addon keeps: a class color carries none of its own, so taking the
--- swatch's is what stops a mode change from silently altering the opacity.
---
--- `skin`, THE SHIPPED MODE (MM-A1), is the skin's `title.text`, whole, out of
--- the window's cached skinLooks (`looks`): no token is read on a title pass.
---
--- @return number r, number g, number b, number a
local function headerColor(header, looks)
    local r, g, b, a = RGBA(header.color, 1, 0.82, 0, 1)
    local skin = header.colorMode == "skin" and looks and looks.titleText
    if skin then return skin[1], skin[2], skin[3], skin[4] or 1 end
    if header.colorMode == "class" then
        local cr, cg, cb = PlayerClassRGB()
        -- An unknown class keeps the configured color rather than falling back
        -- to a tenth hue invented here -- the same answer every other mode reader
        -- in this addon gives.
        if cr then return cr, cg, cb, a end
    end
    return r, g, b, a
end

--- The title bar's background: the skin's `title.bg` while `header.bgColorFromSkin`
--- is on (MM-A1, out of the window's cached skinLooks), else the swatch.
local function titleBarColor(header, looks)
    local skin = header.bgColorFromSkin == true and looks and looks.titleBg
    if skin then return skin[1], skin[2], skin[3], skin[4] or 1 end
    return RGBA(header.bgColor, 0, 0, 0, 0.5)
end

--- The title band's two stops, bottom then top: the skin's `title.bgBottom` and
--- `title.bgTop` while `header.bgColorFromSkin` is on and the skin draws its band
--- as a gradient (Ka0s Default, WoW Midnight), else nil and the band is flat.
local function titleBarStops(header, looks)
    if header.bgColorFromSkin ~= true or not looks then return nil end
    local top, bottom = looks.titleBgTop, looks.titleBgBottom
    if top and bottom then return bottom, top end
    return nil
end

--- `c`'s four channels into the kept Color object `into`, made once per window.
local function intoColor(into, r, g, b, a)
    into = into or CreateColor(r, g, b, a)
    into.r, into.g, into.b, into.a = r, g, b, a
    return into
end

--- The tinted strip's fill: the skin's title gradient (LootHistory's band, R5-MM1),
--- or one color for a flat skin and for the player's swatch.
---
--- ONE PATH FOR BOTH, ON A WHITE BASE: the strip is always a white texture under a
--- vertical gradient, and a flat color is a gradient whose two stops agree. A
--- texture drawn flat after a gradient would otherwise keep the gradient's tint
--- unless it was reset, and that reset is state to track per texture (the skeptic's
--- note against P.fill's copy). The two Color objects are kept on the window, so
--- a repaint allocates nothing. Without CreateColor the swatch is drawn flat.
function WindowProto:PaintHeaderStrip(header)
    local tex, looks = self.headerBG, self.skinLooks
    local br, bg, bb, ba = titleBarColor(header, looks)
    local tr, tg, tb, ta = br, bg, bb, ba
    local bottom, top = titleBarStops(header, looks)
    if bottom then
        br, bg, bb, ba = bottom[1], bottom[2], bottom[3], bottom[4] or 1
        tr, tg, tb, ta = top[1], top[2], top[3], top[4] or 1
    end
    if type(CreateColor) ~= "function" or not tex.SetGradient then
        tex:SetColorTexture(br, bg, bb, ba)
        return
    end
    self.headerLow = intoColor(self.headerLow, br, bg, bb, ba)
    self.headerHigh = intoColor(self.headerHigh, tr, tg, tb, ta)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetGradient("VERTICAL", self.headerLow, self.headerHigh)
end

--- A cached look a column header surface follows: `field` of the window's skinLooks while the
--- group's `modeKey` is Custom and its companion is on. A class or per-statistic mode keeps its color.
local function customLook(group, modeKey, companion, window, field)
    if group[modeKey] ~= "custom" or group[companion] ~= true then return nil end
    return window.skinLooks and window.skinLooks[field]
end

--- `look`'s four channels, or the color handed in when there is no look.
local function lookOver(look, r, g, b, a)
    if not look then return r, g, b, a end
    return look[1], look[2], look[3], look[4] or 1
end

--- The header's font and color, in the one shape modules/HeaderControls.lua
--- asks for it.
---
--- THE SEAM EXISTED BEFORE ANYTHING FILLED IT. `HeaderControls.Style` has always
--- read `NS.HeaderStyle` and always fallen through to a white 12px fallback,
--- because nothing published the function — so every comment saying the controls
--- take the header's color described something that had never run. Published
--- here rather than computed there for the reason `headerFont` is one reader for
--- three lines: a second opinion about what the header looks like is how the
--- title and the strip below it end up on different fonts.
---
--- @param window table
--- @return table  { path, size, flags, r, g, b }
function NS.HeaderStyle(window)
    local header = (window.config or {}).header or {}
    local path, size, flags = headerFont(header)
    local r, g, b = headerColor(header, window.skinLooks)
    return { path = path, size = size, flags = flags, r = r, g = g, b = b }
end

--- The column-header strip's own font, size and flags.
---
--- Its OWN group, and that is the point of it existing. These used to come from
--- two different places — the path and size off `text`, the outline off `header`
--- — so changing the cell font silently restyled the headers and no setting
--- could make the strip differ from the numbers beneath it.
local function columnHeaderFont(colHeader)
    local flags = NS.SkinFontFlags(colHeader.outline)
    return fontPath(NS.SkinMediaKey(colHeader, "font", "hud.font")),
        NS.SkinHudFontSize(colHeader.size or 11, colHeader.fontFromSkin), flags
end

--- Where something `h` pixels tall sits so it is CENTERED on the title band:
--- the y offset to anchor its MIDDLE (LEFT, RIGHT or CENTER) at, relative to the
--- band frame's own middle (`self.headerBand`, laid by ApplyHeaderStrip).
---
--- WHY EVERY LINE OF THE TITLE BAR ASKS THIS. The title and the session line were
--- pinned 5px below the frame's top edge — a constant that predates the title bar
--- having a configurable height and had nothing to do with the band it draws in.
--- One center for the text, the session line and the controls means the row
--- cannot drift again when the bar's height, the font size or the control size
--- changes.
---
--- ON THE BAND, AT 0 (R5-MM1 and R5-WIN, the round 5 lead's call 6: every header
--- child of every Ka0s window is anchored by its middle to the band at y 0). Until
--- round 5 the row was centered on the frame's top edge down to BAR_INSET above
--- the tinted strip's bottom, an offset off the frame while the strip itself hung
--- at the padding; the two answered different middles. The band is now the strip
--- and the drag handle and the row's middle, so there is one middle. No per-font
--- nudge: a box is centered, a face's own baseline is the owner's smoke check.
---
--- COMPUTED, NEVER MEASURED (rule R3): `h` is the caller's own configured size,
--- not something read back off a widget. A box taller than the band and its edges
--- hangs from the frame's top edge instead, so it overflows downward rather than
--- off the window.
---
--- @param h number  the height of the thing being placed
--- @return number y  the offset to anchor its MIDDLE at, relative to the band's middle
function WindowProto:TitleRowMid(h)
    h = h or 0
    local e = self:HeaderInset()
    local over = e + (self:TitleBandHeight() - h) / 2
    if over < 0 then return over end
    return 0
end

--- How far in from the frame's edges the title band sits: flush inside the edge
--- that is drawn (S.Shell's own inset under the skin's edge, the player's edge
--- size under theirs; ApplyBorder records it), 1 before the first border pass.
---
--- @return number
function WindowProto:HeaderInset()
    return self.edgeInset or 1
end

--- How tall the title band is: the padding plus the header height, less
--- BAR_INSET. 6 padding + 26 bar - 2 = 30 shipped, LootHistory's bar and Ka0s DPS
--- Race's `TITLE_BAR_H` (only at the shipped settings: the player's Padding and
--- Header height move it). One number for the band, the row's center and the drag
--- strip, so none can disagree about where the bar ends. 0 with the header hidden.
---
--- @return number
function WindowProto:TitleBandHeight()
    local layout = self.layout
    if layout.titleHeight <= 0 then return 0 end
    return layout.padding + layout.titleHeight - BAR_INSET
end

--- Where the header's two text lines must stop on the right: the frame padding,
--- plus the width of each header button that is currently shown. Shared by the
--- title and the session line so neither can end up running underneath one.
function WindowProto:HeaderRightInset()
    -- Every button that sits in the top-right corner has to be counted here, or
    -- the session line runs underneath them. Computed rather than measured — the
    -- buttons are placed from these same numbers (rule R3).
    -- FROM CONFIG, NOT FROM THE WIDGETS. The previous version asked each button
    -- `:IsShown()`, and a freshly created Button is shown by default -- so until
    -- the first layout pass ran, the inset counted every button as present
    -- whether the player had turned it off or not. Asking the module means the
    -- room the title reserves is derived from the same config the placement
    -- reads, so the two cannot disagree.
    local used = NS.HeaderControls and NS.HeaderControls.WidthUsed(self) or 0
    if used > 0 then used = used + self.layout.padding end
    return self.layout.padding + used
end

--- Whether the strip is drawn: test mode reserved it, and the window is not
--- collapsed. NOT tied to `header.show` -- a window with its header hidden is
--- still marked as test data (OWNER_SCOPE G). Minimized with the header hidden is
--- the rule's carved-out collapsed state.
local function stripShown(self)
    return self.layout.stripHeight > 0
        and not ((self.config.frame or {}).minimized and true or false)
end

--- Whether a /mm sim session runs (MultiMeters#60). It decides WHICH strip the
--- slot shows: the sim strip while a simulation runs, the test strip otherwise.
local function simRunning()
    return (NS.Sim and NS.Sim:IsActive()) and true or false
end

--- The window's name, in the title bar.
function WindowProto:ApplyTitle()
    local cfg    = self.config
    local header = cfg.header or {}
    local frame  = self.frame
    local path, size, flags = headerFont(header)

    -- `header.align` needs the title to SPAN the strip: a FontString with no
    -- width is exactly as wide as its text, so SetJustifyH on the bare TOPLEFT
    -- anchor it used to carry would move nothing at all. The span stops short of
    -- the close button, and the session line keeps its own RIGHT anchor — the
    -- two halves of the strip are placed from opposite ends, so aligning one can
    -- never push the other off the frame.
    -- On the band by its middle (TitleRowMid); the x offsets are the frame's, less
    -- the band's inset, so the title keeps its place off the window's edges.
    local y, e, band = self:TitleRowMid(size), self:HeaderInset(), self.headerBand
    frame.title:ClearAllPoints()
    frame.title:SetPoint("LEFT", band, "LEFT", 8 - e, y)
    frame.title:SetPoint("RIGHT", band, "RIGHT", e - self:HeaderRightInset(), y)
    -- The skin's `title.align` while the companion is on (cause L9); the session line keeps its RIGHT
    -- anchor, so the two never trade ends. Degraded, the token answers nothing.
    frame.title:SetJustifyH(NS.Skin.Resolve("title.align", header.align or "LEFT", header.alignFromSkin == true)
        or header.align or "LEFT")
    NS.SkinHudFont(frame.title, path, size, flags, header.shadow, header.shadowFromSkin,
        self.skinLooks and self.skinLooks.keptShadow)
    -- THE RED TEST MODE WORD marks test mode only where the strip does not: a
    -- minimized window (the strip goes with the body) or a load without the
    -- Widgets library (no strip is built). Test mode fills the grid with numbers
    -- that look exactly like real ones, so a label saying otherwise must always be
    -- on screen -- but once, not twice: with the strip showing, the title saying
    -- it too was the same word repeated (OWNER_SCOPE 2026-10-23).
    -- THE WINDOW'S NAME, ALWAYS. `header.title` was a second name for a window
    -- that already has one, and two names for one thing is two things that can
    -- disagree -- a window renamed in the picker kept whatever its header had been
    -- set to, with no way to tell from the header which window you were looking
    -- at. Renaming a window renames its header now.
    -- A simulation never writes a title word, minimized or not: its marker is
    -- the sim strip alone, and the step panel marks the run (OWNER_SCOPE A).
    local title = cfg.name or L["Multi Meters"]
    if NS.State and NS.State.testMode and not stripShown(self) and not simRunning() then
        -- The word's red is this addon's owner token (core/SkinSetup.lua), today's
        -- pixel under Ka0s Default and the skin's test-mode red under every other,
        -- cached on ApplyConfig (RefreshUpvalues) rather than read per title pass.
        title = title .. "   " .. ((self.skinLooks or {}).testWord or "")
            .. L["TEST MODE"] .. "|r"
    end
    frame.title:SetText(title)
    frame.title:SetShown((cfg.header or {}).show ~= false)

    -- THE TITLE IS HEADER TEXT, and it now takes the header's color like the
    -- session line beside it. It used to be left to ApplySkin -- frame.title is
    -- one of the two members the library tints -- which meant the Header text
    -- group's color and its class-color checkbox styled every part of the
    -- header strip EXCEPT the one word a player thinks of as the header. The
    -- font, size, outline and shadow above always came from that group; only the
    -- color did not, and the inconsistency read as a bug because it was one.
    --
    -- After ApplySkin, not instead of it: ApplyConfig re-runs the skin and then
    -- calls ApplyHeader, so the library still owns the backdrop and the accents
    -- and this owns the one FontString the settings claim to govern.
    frame.title:SetTextColor(headerColor(header, self.skinLooks))
end

--- The tinted block behind the header, and the drag strip over it.
function WindowProto:ApplyHeaderStrip()
    local header = self.config.header or {}
    local layout = self.layout
    local frame  = self.frame

    -- THE TITLE BAR ONLY. It used to cover both header rows — the title bar and
    -- the column labels — on the reading that "the header" is the whole block a
    -- player points at. That was wrong twice over: the column strip has its OWN
    -- background setting (`columnHeader.bgColor`), so a player who set both got
    -- one drawn over the other with no way to see the lower one, and a color
    -- picked for the title bar silently restyled the grid's column labels too.
    -- Two strips, two settings, two rectangles.
    -- A PLAIN COLOR, with no mode of its own. The column strip below has one
    -- because "per statistic" tints each label with its own column's color; this
    -- is one strip over the whole window, so the same mode could only paint it the
    -- sort column's color -- a fact already on screen twice over. What it has is
    -- the skin's companion (MM-A1, DECISIONS D3): while `bgColorFromSkin` is on it
    -- draws `title.bg` (clear for a skin that draws no title band), cached in
    -- skinLooks; off, the swatch, which following the skin never rewrites.
    -- LIKE LOOTHISTORY'S BAR (R5-MM1, the owner's round 5 item 2, image 33): the
    -- band sits flush inside the window's edge, at the edge's own inset, rather
    -- than at the row padding, which left a 4-5 px strip of the window's fill
    -- between the edge and the band (the "black inner border"). TitleBandHeight
    -- high: 30 at the shipped settings, as LootHistory's. The rows, the column
    -- strip and the body keep the padding, LootHistory's 6 px content inset.
    local e, height = self:HeaderInset(), self:TitleBandHeight()
    local band = self.headerBand
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", frame, "TOPLEFT", e, -e)
    band:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -e, -e)
    band:SetHeight(height > 0 and height or 1)

    self.headerBG:ClearAllPoints()
    self.headerBG:SetAllPoints(band)
    self:PaintHeaderStrip(header)
    self.headerBG:SetShown(layout.titleHeight > 0)

    -- The drag strip covers exactly the band. It used to be `titleHeight` tall,
    -- which left the bottom `padding - BAR_INSET` pixels of the bar (4 shipped)
    -- dead to a drag. Sized from the layout like every other coordinate — never
    -- measured off the title FontString.
    self.dragBar:ClearAllPoints()
    self.dragBar:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
    self.dragBar:SetPoint("TOPRIGHT", band, "TOPRIGHT", 0, 0)
    self.dragBar:SetHeight(height > 0 and height or 1)
    self.dragBar:SetShown(layout.titleHeight > 0)

    -- NO LINE UNDER THE TITLE BAR (R4-SEP, the owner's 2026-11-03 sign-off: every
    -- window of every Ka0s addon, like the Ka0s Skin Tester's showroom). The
    -- hairline and its four settings (Show divider, thickness, color, color mode)
    -- are gone; the v25 -> v26 migration prunes what a profile stored for them.
end

--- The right-hand line of the header strip. Only its widget is placed here —
--- UpdateHeaderText writes the text, once per refresh rather than once per
--- settings change.
---
--- IT USED TO SAY WHICH SESSION, HOW LONG AND HOW MUCH, behind three checkboxes,
--- and all three are gone. The session NAME is the window's own title said twice
--- — a window called "Overall" that also says "Overall" beside itself. The
--- DURATION belongs to the segment and the segment picker already names it. The
--- TOTAL is a number nobody reads off a header when the column under it holds
--- the same figure per player.
---
--- What is left has nowhere else to live and is not a preference: the DRILL-DOWN
--- TITLE, which says whose breakdown this is, and the RESTRICTED NOTICE, which
--- says why a cell can be empty mid-pull. So the line is always available and
--- draws only when it has one of those to say — a header that is blank most of
--- the time and speaks when something is unusual, rather than one that repeats
--- the window's own name four times a second.
function WindowProto:ApplySessionLine()
    local header = self.config.header or {}
    local path, size, flags = headerFont(header)
    local shown = true

    -- The BUTTON is what gets placed; the text fills it (SetAllPoints, in Build).
    -- Its width is a constant rather than a measurement of the string inside it,
    -- because measuring is the one thing this file never does — and a fixed click
    -- target is also steadier for the player than one that changes size every
    -- time the group total ticks over a magnitude.
    self.sessionLine:ClearAllPoints()
    local height = math.max(size + 4, 12)
    self.sessionLine:SetPoint("RIGHT", self.headerBand, "RIGHT",
        self:HeaderInset() - self:HeaderRightInset(), self:TitleRowMid(height))
    self.sessionLine:SetSize(SESSION_LINE_WIDTH, height)
    self.sessionLine:SetShown(shown)

    NS.SkinHudFont(self.sessionText, path, size, flags, header.shadow, header.shadowFromSkin,
        self.skinLooks and self.skinLooks.keptShadow)
    self.sessionText:SetTextColor(headerColor(header, self.skinLooks))
    self.sessionText:SetShown(shown)
end

--- The column labels above the grid.
-- ---------------------------------------------------------------------------
-- Column headers -- built once, dressed every pass
-- ---------------------------------------------------------------------------

--- One column header widget, built. Called on the FIRST pass for an index and
--- never again: dressing is a separate step below, so a settings change
--- re-points and re-colors what is already there and costs no frames.
---
--- @param parent Frame  the header strip
--- @param window table  the window instance, stashed for onColumnClick
--- @return table  the button
local function newHeaderButton(parent, window)
    local button = CreateFrame("Button", nil, parent)
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetPoint("LEFT", button, "LEFT", 0, 0)
    -- The sort arrow, in the same shipped atlas the Loot History header
    -- uses, so it reads as "a column header arrow" rather than as this
    -- addon's own invention.
    button.arrow = button:CreateFontString(nil, "OVERLAY")
    button.arrow:SetPoint("LEFT", button.text, "LEFT", 0, 0)
    button.arrow:SetJustifyH("LEFT")
    button.arrow:Hide()
    -- The per-column background, for `bgColorMode == "stat"`. BACKGROUND
    -- layer so the label and the sort arrow stay above it, and built with
    -- the button rather than on demand: these are pooled for the life of
    -- the window like every other widget here.
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints(button)
    button.bg:Hide()
    button.arrowTex = button:CreateTexture(nil, "OVERLAY")
    button.arrowTex:SetSize(10, 10)
    button.arrowTex:Hide()
    button.mmWindow = window
    button:SetScript("OnClick", onColumnClick)
    return button
end

--- The dress context -- everything ApplyColumnHeaders resolves ONCE for the whole
--- strip and every header then wears. Allocated once at FILE SCOPE and refilled
--- per pass rather than per header (anti-pattern #43). ApplyColumnHeaders is
--- never re-entered, so a single table serves every window.
local headerDress = {}

--- The sort arrow on one header. Three rungs, tried in order -- the two shipped
--- assets, then the one atlas arrow flipped, then an ASCII character -- and
--- exactly one of `arrow` / `arrowTex` is left shown by any of them.
---
--- THE COLOR IS PASSED IN rather than re-resolved, because the arrow wears the
--- same color as its label and once did not: sorting by name puts the arrow on
--- the Player header, where it was drawn in the sort column's stat color over a
--- label that is no longer that color.
---
--- @param button table  the header button
--- @param d table  the dress context
--- @param tr number @param tg number @param tb number @param ta number
local function dressSortArrow(button, d, tr, tg, tb, ta)
    -- Placed after the label rather than at a fixed offset, so it follows
    -- the text however long the label is. GetStringWidth is a measurement
    -- of a FontString this window OWNS and that has never held a value --
    -- rule R3 is about cells that have, and this is neither.
    local after = button.text:GetStringWidth() + 3
    local mark = NS.Icon and NS.Icon(
        d.sortAscending and SORT_MARK_UP or SORT_MARK_DOWN)
    local atlas = not mark and NS.Compat.FirstAtlas(
        d.sortAscending and SORT_ATLAS_UP or SORT_ATLAS_DOWN)

    if mark then
        button.arrowTex:ClearAllPoints()
        button.arrowTex:SetPoint("LEFT", button.text, "LEFT", after, 0)
        button.arrowTex:SetTexture(mark)
        -- No SetTexCoord: two assets, not one flipped. The atlas branch
        -- below flips because it has only one arrow to flip.
        button.arrowTex:SetTexCoord(0, 1, 0, 1)
        local arrow = d.sortArrow
        if arrow then tr, tg, tb = arrow[1], arrow[2], arrow[3] end
        button.arrowTex:SetVertexColor(tr, tg, tb)
        button.arrowTex:Show()
        button.arrow:Hide()
    elseif atlas then
        button.arrowTex:ClearAllPoints()
        button.arrowTex:SetPoint("LEFT", button.text, "LEFT", after, 0)
        button.arrowTex:SetAtlas(atlas)
        -- Flipped vertically for ascending: the shipped arrow points
        -- down, and one SetTexCoord beats a second asset to go missing.
        if d.sortAscending then
            button.arrowTex:SetTexCoord(0, 1, 1, 0)
        else
            button.arrowTex:SetTexCoord(0, 1, 0, 1)
        end
        button.arrowTex:Show()
        button.arrow:Hide()
    else
        NS.SkinHudFont(button.arrow, d.font, d.size, d.flags, d.shadow, d.shadowFromSkin)
        button.arrow:SetTextColor(tr, tg, tb, ta)
        button.arrow:SetText(d.sortAscending and SORT_ASCII_UP or SORT_ASCII_DOWN)
        button.arrow:ClearAllPoints()
        button.arrow:SetPoint("LEFT", button.text, "LEFT", after, 0)
        button.arrow:Show()
        button.arrowTex:Hide()
    end
end

--- Everything about one column header that a settings change can move: font,
--- color, label, the background mode, and the sort arrow. Re-run on every pass
--- over a button newHeaderButton built once.
---
--- @param button table  the header button
--- @param key string  the column key, "name" for the Player column
--- @param label string  the localized label
--- @param width number  the drawn column width
--- @param d table  the dress context
local function dressHeaderButton(button, key, label, width, d)
    -- LEFT-ALIGNED, both the name column and every stat column. The cells
    -- below are right-aligned and the headers used to match them, which put
    -- each label hard against the NEXT column's numbers and read as if it
    -- belonged to them.
    button.text:SetWidth(width)
    button.text:SetHeight(d.headerHeight)
    NS.SkinHudFont(button.text, d.font, d.size, d.flags, d.shadow, d.shadowFromSkin)
    -- PER COLUMN, and only here. `stat` mode on every other surface resolves
    -- to one color for the whole surface; this strip is the one place where
    -- "per statistic" is literally per column, so each label takes the color
    -- of the column it labels.
    --
    -- THE NAME COLUMN IS NOT A STATISTIC AND MUST NOT BORROW ONE. It used to
    -- fall through to `hr, hg, hb`, but that fallback is itself resolved
    -- through windowStat() -- the SORT column -- so "Player" came out in the
    -- sorted stat's color: red on a damage-sorted window, and a different
    -- color every time the sort moved. White is what it says instead, the
    -- one color on this strip that claims no statistic. Only in `stat` mode:
    -- every other mode's fallback is a color the player actually chose.
    --
    -- Resolved into locals rather than applied inline because THE SORT ARROW
    -- WEARS THE SAME COLOR and had the same bug. Sorting by name puts the
    -- arrow on the Player header, where it was drawn in the sort column's
    -- stat color over a label that is no longer that color.
    local tr, tg, tb, ta = d.hr, d.hg, d.hb, d.ha
    if d.colorMode == "stat" then
        if key == "name" then
            -- The skin's highlight: white under Ka0s Default.
            tr, tg, tb = NS.SkinColor("text.highlight")
        else
            tr, tg, tb, ta = surfaceColor("stat", d.color, key, d.hr, d.hg, d.hb, d.ha)
        end
    end
    button.text:SetTextColor(tr, tg, tb, ta)
    button.text:SetJustifyH("LEFT")
    button.text:SetText(label)

    -- The strip-wide texture and the per-column ones are mutually exclusive,
    -- and both are set every pass: a player switching modes would otherwise
    -- keep whichever they left behind, drawn under the one they chose.
    if d.perColumnBG and key ~= "name" then
        local cr, cg, cb, ca = surfaceColor("stat", d.bgColor, key,
            d.bgr, d.bgg, d.bgb, d.bga)
        button.bg:SetColorTexture(cr, cg, cb, ca)
        button.bg:Show()
    else
        button.bg:Hide()
    end

    if key == d.sortKey then
        dressSortArrow(button, d, tr, tg, tb, ta)
    else
        button.arrow:Hide()
        button.arrowTex:Hide()
    end
end

function WindowProto:ApplyColumnHeaders()
    local cfg    = self.config
    local layout = self.layout
    local pad    = layout.padding
    local colHeader = cfg.columnHeader or {}
    local colFont, colSize, flags = columnHeaderFont(colHeader)
    -- The STRIP labels the grid rather than any row in it, so its class color is
    -- the local player's -- the same reading the title bar takes, and for the
    -- same reason. Its `stat` color is NOT the same, though, and that is the
    -- point of resolving it per column below: this is the one surface where "per
    -- statistic" is literally per column, so each label can take the color of
    -- the column it labels. The values here are the fallback the name column and
    -- any unresolvable stat land on.
    local hr, hg, hb, ha = surfaceColor(colHeader.colorMode, colHeader.color,
        windowStat(self), 1, 0.82, 0, 1)
    -- The skin's `hud.label` while the companion is on, under `custom` only: the other two modes are
    -- a class and a statistic, which keep their color. Nil, degraded, leaves the swatch.
    hr, hg, hb, ha = lookOver(customLook(colHeader, "colorMode", "colorFromSkin", self, "hudLabel"),
        hr, hg, hb, ha)

    -- One FontString per drawn column plus the name column's, placed at the same
    -- x offsets the cells will use — from the SAME layout table, so a header can
    -- never drift from the column under it.
    local _, headerTop = self:ChromeOffsets()
    self.headerFrame:ClearAllPoints()
    -- Both top corners are the window's, so the strip's clip box is the window's width and a
    -- column header dragged past the edge is cut there; layout.rowWidth only places the labels.
    self.headerFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", pad, -headerTop)
    self.headerFrame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -pad, -headerTop)
    self.headerFrame:SetHeight(layout.headerHeight)

    -- PER STATISTIC IS PER COLUMN HERE, so `stat` mode paints each header button
    -- rather than the strip: one rectangle behind each label, in that column's
    -- own color. Every other mode is one color for the whole strip and stays on
    -- the single texture, which is both cheaper and the only way "class" could be
    -- drawn at all -- a class is not a property of a column.
    local perColumnBG = (colHeader.bgColorMode == "stat")
    local bgr, bgg, bgb, bga = surfaceColor(perColumnBG and "custom" or colHeader.bgColorMode,
        colHeader.bgColor, windowStat(self), 0, 0, 0, 0)
    -- The skin's band while the companion is on, under `custom` only (cause A1).
    bgr, bgg, bgb, bga = lookOver(customLook(colHeader, "bgColorMode", "bgColorFromSkin", self, "headerBand"),
        bgr, bgg, bgb, bga)
    self.headerBg:SetColorTexture(bgr, bgg, bgb, bga)
    self.headerBg:SetShown(not perColumnBG)

    local data = cfg.data or {}
    -- The arrow belongs on whichever header the CURRENT order came from, and in
    -- `name` mode that is the Player column rather than a stat one. Without this
    -- the name column was the one header that could be sorted by and never said
    -- so.
    local sortKey = (data.sortMode == "name") and "name" or data.sortColumn

    -- MID-PULL THE ARROW FOLLOWS THE GRID, NOT THE REQUEST. Under the Combat
    -- restriction every mode degrades to the engine's ranking of the sort COLUMN
    -- (`aggregate.applied == "provider"`), so a `name` window drawn there was
    -- putting the arrow on the Player header over rows ordered by damage — the
    -- grid state stating something untrue rather than admitting a limitation.
    -- Read off the aggregate the render pass parked here, for the same reason
    -- RestrictedNotice does: it describes the grid on screen rather than the
    -- restriction state at the moment the header was drawn.
    local aggregate = self.aggregate
    if aggregate and aggregate.identityMode then sortKey = data.sortColumn end

    -- Resolved ONCE for the whole strip; every header then wears it. Refilled
    -- rather than reallocated -- see headerDress above.
    local d = headerDress
    d.headerHeight = layout.headerHeight
    d.font, d.size, d.flags = colFont, colSize, flags
    d.shadow, d.shadowFromSkin = colHeader.shadow, colHeader.shadowFromSkin
    d.colorMode, d.color = colHeader.colorMode, colHeader.color
    -- `icon.arrow` while the label follows the skin (cause L8); otherwise the arrow wears the label's.
    d.sortArrow = customLook(colHeader, "colorMode", "colorFromSkin", self, "sortArrow")
    d.hr, d.hg, d.hb, d.ha = hr, hg, hb, ha
    d.perColumnBG, d.bgColor = perColumnBG, colHeader.bgColor
    d.bgr, d.bgg, d.bgb, d.bga = bgr, bgg, bgb, bga
    d.sortKey = sortKey
    d.sortAscending = data.sortAscending

    -- EVERY HEADER IS A BUTTON, including the name column's -- clicking it sorts
    -- by that column, clicking it again reverses. The widget is created once per
    -- index and re-pointed, never rebuilt, so a settings change costs no frames.
    local function place(index, key, label, x, width)
        local button = self.columnHeaders[index]
        if not button then
            button = newHeaderButton(self.headerFrame, self)
            self.columnHeaders[index] = button
        end

        button.mmKey = key
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.headerFrame, "TOPLEFT", x, 0)
        button:SetSize(width, layout.headerHeight)

        dressHeaderButton(button, key, label, width, d)
        button:Show()
    end

    place(1, "name", L["Player"], layout.nameColumn.x, layout.nameColumn.width)
    for i, col in ipairs(layout.columns) do
        -- Localized at the USE SITE, never in core/Constants.lua: the catalog
        -- stores the English key so a locale registering later still wins.
        -- `headerLabel` falls back to the full label; only the stats whose full
        -- label does not fit a column carry an override.
        place(i + 1, col.key, L[col.stat.headerLabel or col.stat.label], col.x, col.width)
    end
    for i = #layout.columns + 2, #self.columnHeaders do
        self.columnHeaders[i]:Hide()
    end
end

-- ---------------------------------------------------------------------------
-- The test-mode and simulation strips (MultiMeters#59, #60, LibKa0s#48)
-- ---------------------------------------------------------------------------

local function placeStrip(strip, frame, pad, stripTop, show)
    if not strip then return end
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -stripTop)
    strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -stripTop)
    strip:SetShown(show)
end

--- The anchoring half of ApplyTestStrip: place both strips in the one slot under
--- the title, inset by the padding on both sides, and show the one the slot is
--- reserved for -- the sim strip while a simulation runs, the test strip
--- otherwise. ApplyConfig runs this too, so a settings change that moves the
--- title moves the strips with it. Positions come from ChromeOffsets, i.e. from
--- the layout, never off a frame.
function WindowProto:PlaceTestStrip()
    local pad = self.layout.padding
    local stripTop = self:ChromeOffsets()
    local shown, sim = stripShown(self), simRunning()
    placeStrip(self.testStrip, self.frame, pad, stripTop, shown and not sim)
    placeStrip(self.simStrip, self.frame, pad, stripTop, shown and sim)
end

--- The test-mode toggle's whole effect on a window, and NARROW on purpose: the
--- full ApplyConfig re-positions, re-scales, re-skins and re-borders, and a toggle
--- that combat start fires (M:EndTestModeForCombat) must not make a window jump.
---
--- One layout rebuild (RefreshUpvalues, which bumps layoutVersion so every row
--- re-anchors on its next draw), then the strip, the column headers and the body
--- re-anchored from ChromeOffsets, the title rewritten (the red TEST MODE word is
--- written only when the strip is not shown) and the resize bounds re-applied (unchanged: the strip never moves layout.minHeight).
function WindowProto:ApplyTestStrip()
    if not self.frame then return end
    self:RefreshUpvalues()
    self:PlaceTestStrip()

    local pad = self.layout.padding
    local _, headerTop, bodyTop = self:ChromeOffsets()
    self.headerFrame:ClearAllPoints()
    self.headerFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", pad, -headerTop)
    self.headerFrame:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -pad, -headerTop)
    self.body:ClearAllPoints()
    self.body:SetPoint("TOPLEFT", self.frame, "TOPLEFT", pad, -bodyTop)
    self.body:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -pad, pad)

    self:ApplyTitle()
    self:ApplyResizeBounds()
end

--- Show or hide everything below the title bar, per `frame.minimized`.
---
--- APPLIED FROM CONFIG AT THE TAIL OF ApplyConfig, not from the click. Any
--- CONFIG_CHANGED re-runs ApplyConfig, which unconditionally restores the body's
--- anchors and the window's size -- so a collapse driven only from the button
--- would be silently undone by the next unrelated setting change.
---
--- THE ANCHOR IS NOT RESIZED. Shrinking it fires onSizeChanged, which writes
--- pendingWidth/pendingHeight, and SaveSize persists whatever is pending on the
--- next resize-stop -- so a collapsed height would leak into `frame.height` and
--- the window would never come back to the size the player chose. Hiding the
--- children is the whole collapse.
---
--- Four things hang below the title, not one: the body carries the rows, but the
--- column-header strip, the notice and the grip are parented to the FRAME and
--- would go on drawing over a collapsed window.
function WindowProto:ApplyMinimized()
    local frameCfg = self.config.frame or {}
    -- `and true or false`, never `~= false`: a profile stored before this
    -- existed has no key at all, and `~= false` would collapse every one of them.
    local down = frameCfg.minimized and true or false

    -- THE WINDOW ACTUALLY SHRINKS. Hiding the children alone left a full-height
    -- empty frame sitting there, which is not what "collapse to the title bar"
    -- means to anybody looking at it.
    --
    -- The ANCHOR is left alone -- resizing it fires onSizeChanged, which writes
    -- pendingWidth/pendingHeight, and SaveSize persists whatever is pending on
    -- the next resize-stop, so the collapsed height would leak into
    -- frame.height and the window would never come back to the size the player
    -- chose. The visible frame is unpinned from the anchor's bottom instead and
    -- given the title bar's own height; expanding re-pins it.
    local frame = self.frame
    if down then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.anchor, "TOPLEFT", 0, 0)
        frame:SetPoint("TOPRIGHT", self.anchor, "TOPRIGHT", 0, 0)
        -- EXACTLY THE BAND AND ITS EDGES (R5-MM1): the band plus the edge above and
        -- below it, so no strip of the window's fill shows under a collapsed bar.
        -- With the header hidden, the padding's own collapsed state stands.
        local band = self:TitleBandHeight()
        if band > 0 then
            frame:SetHeight(band + 2 * self:HeaderInset())
        else
            frame:SetHeight(self.layout.padding * 2 + self.layout.titleHeight)
        end
    else
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.anchor, "TOPLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", self.anchor, "BOTTOMRIGHT", 0, 0)
    end

    if self.body then self.body:SetShown(not down) end
    if self.headerFrame then self.headerFrame:SetShown(not down) end
    -- The test-mode strip goes with the body and comes back on expand, if test
    -- mode still reserves it (PlaceTestStrip asks the same question).
    self:PlaceTestStrip()
    -- The red title word follows the strip: it shows exactly while the strip
    -- cannot, so a collapse or expand on any path rewrites the title.
    self:ApplyTitle()
    -- The notice is re-shown by Refresh whenever there is nothing to draw, so
    -- hiding it here is not enough on its own -- Refresh checks the same flag.
    if self.notice and down then self.notice:Hide() end
    if self.empty and down then self.empty:Hide() end
    -- ApplyLock is the grip's other author, so expanding must not resurrect a
    -- grip the lock had hidden.
    if self.grip then
        self.grip:SetShown(not down and not (frameCfg.locked and true or false))
    end
end

--- Title, session line, and the column headers — the whole header strip, in the
--- order it is stacked on screen.
function WindowProto:ApplyHeader()
    -- FIRST, and the order is load-bearing: ApplyTitle and ApplySessionLine both
    -- read HeaderRightInset, which is derived from what the controls occupy.
    if NS.HeaderControls then NS.HeaderControls:Apply(self) end
    self:ApplyTitle()
    self:ApplyHeaderStrip()
    self:ApplySessionLine()
    self:ApplyColumnHeaders()
end

-- ---------------------------------------------------------------------------
-- Sorting from the column headers
-- ---------------------------------------------------------------------------

--- Sort this window by `key`, or reverse it if it is already the sort column.
---
--- REFUSES WHILE THE COMBAT RESTRICTION IS ACTIVE, and says so. Ordering by value
--- means comparing meter values, which raises while they are secret — the
--- aggregator already declines to re-sort mid-pull and holds the frozen order
--- (rule R2). Without a message the click would simply do nothing, which reads as
--- a broken button rather than as a rule.
---
--- The name column sorts by `roster` — group order — because "sort by name" over
--- a `ConditionalSecret` name is a string comparison on a value we may not read.
--- Group order is the stable, always-legal thing a player actually means when
--- they click the Player header.
---
--- @param key string  a stat key, or "name"
--- @return boolean  whether the sort changed
function WindowProto:SortByColumn(key)
    if key == nil then return false end

    local data = self.config.data
    if not data then return false end

    -- ONE HEADER IS REFUSED WHILE THE RESTRICTION IS ACTIVE, AND ONLY ONE.
    --
    -- This used to refuse EVERY header, which is where "sorting does nothing in
    -- combat" came from. It was too wide by two whole operations:
    --
    --   * Picking a different STAT column compares nothing. modules/Aggregator.lua
    --     builds the entire mid-pull row list out of `sortColumn`'s own
    --     combatSources, so changing which column that is re-ranks the grid by
    --     the engine's own ordering for the new stat.
    --   * Reversing compares nothing either — it is a permutation of an array
    --     this addon built, and the aggregator applies it without touching a
    --     value (see reverseRows in modules/Aggregator_Order.lua).
    --
    -- The Player column is the genuine refusal. Ordering by name compares a
    -- ConditionalSecret, which raises, and unlike a stat column there is no
    -- engine ranking standing behind it — `name` mode mid-pull would draw the
    -- damage order under an arrow pointing at the Player header. Without a
    -- message the click would simply do nothing, which reads as a broken button
    -- rather than as a rule.
    if key == "name" and NS.Secrets and NS.Secrets.IsRestricted() then
        -- Named in the log as well (debug-logging-§8, Diagnosis): no [Set] line
        -- follows a refused click, and "the header did nothing" is the report.
        if NS.State.debug then
            NS.Debug("Window", "window %d sort by name refused: restricted", self.id)
        end
        if NS.Print then
            NS.Print(L["Sorting is not possible while the game restricts combat data."])
        end
        return false
    end

    -- THE PLAYER COLUMN SORTS BY PLAYER. It used to toggle between `roster` and
    -- `value`, which is a reasonable thing for some header to do and not what a
    -- header labeled "Player" says. Ascending first, because A-Z is what a
    -- player means by "sort by name"; clicking again reverses it, exactly like a
    -- stat column.
    --
    -- THE CLICK CHOOSES THE SORT, so the sort is a preference with rows
    -- (architecture-§5, issue #50) and the click writes them through the seam as
    -- one batch addressed to THIS window: validated, one `[Set]` line per row,
    -- announced once, whichever window the settings panel is pointed at. The
    -- rows' own onChange drops the frozen order, which is a snapshot of the OLD
    -- sort and would be reapplied over the new one for the rest of the pull, so
    -- `/mm set` drops it too.
    local writes
    if key == "name" then
        if data.sortMode == "name" then
            writes = { { "window.data.sortAscending", not data.sortAscending } }
        else
            writes = { { "window.data.sortMode", "name" },
                       { "window.data.sortAscending", true } }
        end
    elseif data.sortColumn == key and data.sortMode == "value" then
        writes = { { "window.data.sortAscending", not data.sortAscending } }
    else
        writes = { { "window.data.sortColumn", key },
                   { "window.data.sortMode", "value" },
                   { "window.data.sortAscending", false } }
    end
    if not (NS.SetByPaths and NS.SetByPaths(writes, self.id)) then return false end

    self:ApplyColumnHeaders()
    self:MarkDirty()
    return true
end

-- ---------------------------------------------------------------------------
-- The segment selector
-- ---------------------------------------------------------------------------
--
-- `data.sessionType` picks Current or Overall. `data.sessionID`, when it pins
-- one, overrides it with a specific stored segment — the fight the player picked
-- out of the header dropdown. Constants.NO_SEGMENT (0) means "no segment
-- pinned", which is the default; Database.PinnedSegment is how it is read. Both
-- are hidden rows, and every write below goes through the seam addressed to
-- this window (architecture-§5, issues #49 and #50).

--- One stored session's entry, as menu text: its name, then its duration.
---
--- Both pieces come off the API and BOTH MAY BE SECRET, so the two rules that
--- shape every other display string apply here too: joined with `..` and never
--- with table.concat, and the name goes through the concat probe before
--- tostring. A menu label is drawn and nothing else is ever asked of it.
---
--- @param entry table  { sessionID, name, durationSeconds }
--- @return string
local function segmentLabel(entry)
    local name = entry.name
    if name == nil then
        name = L["Segment"]
    elseif NS.IsConcatSafe and NS.IsConcatSafe(name) then
        name = tostring(name)
    else
        name = NS.SafeToString and NS.SafeToString(name) or L["Segment"]
    end

    local F = NS.Format
    if type(F) ~= "table" or not F.Duration then F = NS.NumberFormat end
    if entry.durationSeconds == nil or not (F and F.Duration) then return name end

    local ok, out = pcall(function() return name .. "   " .. F.Duration(entry.durationSeconds) end)
    return ok and out or name
end

--- Forget a pinned segment the client no longer holds. See Refresh.
function WindowProto:DropStaleSegment()
    -- Never while a simulation runs (MultiMeters#60, H4): the session list is the
    -- simulated world's, so every real pin would look stale and be dropped.
    -- modules/Sim.lua's stop restores the pins it snapshotted instead.
    if NS.Sim and NS.Sim:IsActive() then return end
    local pinned = NS.Database.PinnedSegment(self.config.data)
    if pinned == nil then return end

    local Provider = mod("Provider")
    -- No provider at all is a broken install, not a stale segment: leaving the
    -- pin alone means it still works once the module is there, and dropping it
    -- would quietly rewrite the player's setting because of our own load order.
    if not (Provider and Provider.HasSession) then return end

    if not Provider.HasSession(pinned) then
        if NS.State and NS.State.debug then
            NS.Debug("Window", "window %d dropped stale segment %s", self.id, tostring(pinned))
        end
        -- A row wins (architecture-§5): the pin is a row, so even this repair
        -- writes it through the seam, addressed to this window.
        if NS.SetByPath then NS.SetByPath("window.data.sessionID", Const.NO_SEGMENT, self.id) end
    end
end

--- Point this window at one stored segment, or at Constants.NO_SEGMENT (or nil)
--- for "follow sessionType".
---
--- The menu entry CHOOSES the pin, so it is a row and goes through the seam
--- addressed to this window (architecture-§5), which validates, logs and
--- announces it.
--- @param sessionID number|nil
function WindowProto:SetSegment(sessionID)
    local data = self.config.data
    if not data then return end
    if sessionID == nil then sessionID = Const.NO_SEGMENT end
    if data.sessionID == sessionID then return end
    if not (NS.SetByPath and NS.SetByPath("window.data.sessionID", sessionID, self.id)) then
        return
    end
    self:MarkDirty()
end

--- Point this window at Current or Overall, clearing any pinned segment.
---
--- Clearing is the point: picking "Current" out of a menu that is showing a
--- stored fight means "stop showing that fight", and leaving the id set would
--- make the choice do nothing at all.
---
--- The menu entry CHOOSES the session type, and clearing the pin is part of the
--- same choice, so both are one batch through the seam addressed to this window
--- (architecture-§5, issues #49 and #50): validated together, stored together,
--- announced once. A refused type stores neither, so the pin is never dropped
--- for a choice that did not land.
--- @param sessionType number
function WindowProto:SetSessionType(sessionType)
    local data = self.config.data
    if not data then return end
    if not (NS.SetByPaths and NS.SetByPaths({
        { "window.data.sessionID",   Const.NO_SEGMENT },
        { "window.data.sessionType", sessionType },
    }, self.id)) then
        return
    end
    self.sessionType = sessionType
    self:MarkDirty()
end

-- The two synthetic entries' menu values; a stored segment's value is its session id.
local SEGMENT_CURRENT, SEGMENT_OVERALL = "Current", "Overall"

--- The menu's anchor for this window: built once, never shown, because the header's control is what
--- the player clicks. It keeps the menu's old place below the session line. A window hidden by a route
--- that is no click closes the menu with it.
local function segmentAnchor(window)
    local anchor = window.segmentAnchor
    if anchor then return anchor end
    anchor = CreateFrame("Frame", nil, window.frame)
    anchor:SetSize(SESSION_LINE_WIDTH, 1)
    anchor:SetPoint("TOPRIGHT", window.sessionLine, "BOTTOMRIGHT", 0, 0)
    anchor:Hide()
    if window.frame.HookScript then
        window.frame:HookScript("OnHide", function() W.CloseMenu() end)
    end
    window.segmentAnchor = anchor
    return anchor
end

--- A row's click: the choice its value names.
local function pickSegment(window, value)
    if value == SEGMENT_CURRENT then
        window:SetSessionType(Const.SESSION_TYPE.Current)
    elseif value == SEGMENT_OVERALL then
        window:SetSessionType(Const.SESSION_TYPE.Overall)
    else
        window:SetSegment(value)
    end
end

--- A title, the stored segments newest first, a divider, then the two synthetic entries, on the skinned
--- menu, the entry the window shows marked: `isActive` and Widgets 23's `radio`/`selected` read one
--- predicate, so every segment row keeps a tick column and the shown one draws the menu's tick (the
--- owned menu's Ka0s `confirm`). The same shape the client's menu draws below, which has no tick.
function WindowProto:OpenSkinnedSegmentMenu(sessions)
    local data = self.config.data or {}
    local active = NS.Database.PinnedSegment(data)
    if active == nil then
        active = data.sessionType == Const.SESSION_TYPE.Overall and SEGMENT_OVERALL or SEGMENT_CURRENT
    end

    local rows = { { title = true, label = L["Segment"] } }
    local function add(value, label)
        local function shown() return value == active end
        rows[#rows + 1] = {
            value = value, label = label, radio = true, selected = shown, isActive = shown,
            onClick = function() pickSegment(self, value) end,
        }
    end
    for _, entry in ipairs(sessions) do
        if type(entry) == "table" and entry.sessionID ~= nil then add(entry.sessionID, segmentLabel(entry)) end
    end
    rows[#rows + 1] = { divider = true }
    add(SEGMENT_CURRENT, L["Current"])
    add(SEGMENT_OVERALL, L["Overall"])

    W.ContextMenu(segmentAnchor(self), rows, { owner = NS.name, width = SESSION_LINE_WIDTH })
    return true
end

--- Open the header's segment dropdown.
---
--- Stored segments first, newest first as the API returns them, then a divider,
--- then the two synthetic entries. That order matches what the player is
--- reaching for: the reason to open this menu at all is almost always to look
--- back at a fight that just ended.
---
--- THE SKINNED MENU, EXCEPT WHILE A LABEL MAY BE SECRET (cause A2). A stored session's duration is
--- secret under the Combat restriction and `..` keeps a secret, so segmentLabel's answer can be one.
--- W.ContextMenu sizes itself by every row's GetStringWidth, in math.min and an addition, which raises
--- on the secret that answers (Widgets minor 21's menuWidth, which `opts.width` does not skip). The
--- client's menu draws a secret, so it stays for exactly that window. It also stays on an install
--- without the library.
function WindowProto:OpenSegmentMenu()
    local Provider = mod("Provider")
    if not (Provider and Provider.GetAvailableSessions) then return false end

    local sessions = Provider.GetAvailableSessions()

    local restricted = NS.Secrets and NS.Secrets.IsRestricted and NS.Secrets.IsRestricted()
    if W and W.ContextMenu and not restricted then return self:OpenSkinnedSegmentMenu(sessions) end

    return NS.Compat.OpenContextMenu(self.sessionLine, function(_, root)
        root:CreateTitle(L["Segment"])

        for _, entry in ipairs(sessions) do
            if type(entry) == "table" and entry.sessionID ~= nil then
                local id = entry.sessionID
                root:CreateButton(segmentLabel(entry), function()
                    self:SetSegment(id)
                end)
            end
        end

        root:CreateDivider()
        root:CreateButton(L["Current"], function()
            self:SetSessionType(Const.SESSION_TYPE.Current)
        end)
        root:CreateButton(L["Overall"], function()
            self:SetSessionType(Const.SESSION_TYPE.Overall)
        end)
        -- Plain buttons, no mark: the shown segment's tick is the skinned menu's alone. This menu
        -- serves only the Combat restriction and an install without the library, and stays as it is.
    end)
end

--- Which session the header names — or nil when it names none.
---
--- The name comes from the window's own setting rather than from the data: the
--- aggregator returns rows, and asking it to name the session would make it read
--- a field it has no other use for.
---
--- NO LONGER DRAWN IN THE HEADER, and kept because modules/Export.lua asks the
--- WINDOW for it: a CSV or a chat dump is headed "Multi Meters — Damage —
--- Overall", and the window is the only thing that knows which segment it was
--- reading. The header dropped it because it repeated the window's own title.
---
--- @param preview boolean
--- @return string|nil
function WindowProto:SessionLabel(preview)
    if preview then return L["Test"] end

    -- A PINNED SEGMENT NAMES ITSELF. Saying "Current" over a window that is
    -- showing a fight from ten minutes ago is the one label that is actively
    -- misleading, and it is also the only feedback the player gets that their
    -- click landed.
    local sessionID = NS.Database.PinnedSegment(self.config.data)
    if sessionID ~= nil then
        local Provider = mod("Provider")
        for _, entry in ipairs(Provider and Provider.GetAvailableSessions() or {}) do
            if type(entry) == "table" and entry.sessionID == sessionID then
                return segmentLabel(entry)
            end
        end
        -- Pinned but not in the list: Refresh's staleness check has not run yet
        -- this pass. Say so rather than falling through to a label that claims a
        -- session this window is not reading.
        return L["Segment"]
    end

    return (self.sessionType == Const.SESSION_TYPE.Overall)
        and L["Overall"] or L["Current"]
end

-- `DurationText` AND `SortTotalText` LIVED HERE and are gone with the two
-- checkboxes that gated them. The duration belongs to the segment, which the
-- header's own picker names; the group total is a figure the column under it
-- already holds per player. Neither had another caller: the export builds its own
-- session label and reads its own totals.

--- The note that this grid was built the restricted way, or nil when it was not.
---
--- REPLACES THE FROZEN-SORT NOTICE, which said the rows had stopped reordering.
--- They have not: `sourceGUID` is secret for the whole of a pull, so the rows are
--- the engine's own ranking of the sort column and they re-rank live. What the
--- player is owed instead is why a CELL can be empty — the other columns are
--- matched to those rows by class and spec, and a pair that cannot be told apart
--- has its cells left blank rather than guessed at.
---
--- Read off the aggregate the render pass parked here rather than from the
--- restriction state directly, so the line describes the grid actually on screen
--- rather than the state at the moment the header was drawn.
---
--- @param preview boolean
--- @return string|nil
function WindowProto:RestrictedNotice(preview)
    if preview then return nil end
    local aggregate = self.aggregate
    if not (aggregate and aggregate.identityMode) then return nil end
    -- The note's gray is the owner token `mm.dim` (core/SkinSetup.lua): NS.GRAY's
    -- bytes under Ka0s Default, the skin's muted text under every other. This runs
    -- on every throttled refresh of a pull, so it reads the escape RefreshUpvalues
    -- cached, never the token (R2).
    local dim = (self.skinLooks or {}).dim or NS.GRAY
    if not aggregate.ambiguous then return dim .. L["restricted"] .. "|r" end

    -- THE COUNT, WHERE THERE IS ONE. Both figures are OUR OWN plain integers --
    -- a tally of rows the aggregator kept, never a meter value -- so formatting
    -- them mid-pull is legal where formatting a total would need NS.Format.
    --
    -- Guarded on both being positive rather than on non-nil: an aggregate from a
    -- build that predates the count answers nil, and "0 of 0 rows" is a worse
    -- sentence than the one it would replace.
    --
    -- A QUARTER OF THE GRID is where naming the cause stops being enough (issue
    -- #22). Every secondary cell on a collided row is blank, so the share of rows
    -- is the share of the grid the blanks cost. Below a quarter the grid mostly
    -- reads and the cause is the sentence; from a quarter up the player is
    -- looking at an empty grid and the sentence says BLANK. Integer arithmetic on
    -- two counts of our own, so it is legal mid-pull, and the string is no longer
    -- than the one beside it (SESSION_LINE_WIDTH above).
    local ambiguous, total = aggregate.ambiguousRows, #(aggregate.rows or aggregate)
    if type(ambiguous) == "number" and ambiguous > 0 and total > 0 then
        local QUARTER = 4
        local fmt = (ambiguous * QUARTER >= total)
            and L["restricted \226\128\148 %d of %d blank: duplicate specs"]
            or  L["restricted \226\128\148 %d of %d share a class and spec"]
        return dim .. string.format(fmt, ambiguous, total) .. "|r"
    end
    return dim .. L["restricted \226\128\148 some rows cannot be told apart"] .. "|r"
end

--- The header's right-hand line: which session, how long it has run, and the
--- group total for the sort column.
---
--- Both the duration and the total are OPAQUE handles like every other number
--- here. The duration goes to NS.Format.Duration and the total to
--- NS.Format.Number — neither is divided, floored or compared in this file,
--- which is why "1:23" is legal mid-pull at all: the formatter does the
--- arithmetic natively (design §4).
---
--- @param preview boolean
--- @param isDrill boolean|nil    a PLAIN boolean; see Render
--- @param drillTitle string|nil  "<player> - <stat>" while drilled in, and
---   possibly a SECRET string — it is written to the widget, never tested
function WindowProto:UpdateHeaderText(preview, isDrill, drillTitle)
    if not self.sessionText:IsShown() then return end

    -- A breakdown is about one player and one statistic, and saying so is worth
    -- more than the session line it replaces. `== nil` rather than `or ""`: the
    -- title is a formatted string and `or` would truth-test it.
    if isDrill then
        self.sessionText:SetText(drillTitle == nil and "" or drillTitle)
        return
    end

    -- FOLDED WITH `..`, NOT JOINED WITH table.concat.
    --
    -- Two of the pieces below come out of NS.Format having been built from a
    -- secret, and a formatted secret is itself secret. `..` is explicitly legal
    -- on one; table.concat is the single string operation that RAISES on one —
    -- it is literally the probe core/CoreSetup.lua uses to detect a secret at
    -- all. Joining this line was therefore a Lua error on the first refresh
    -- after the header showed a duration or a total, four times a second, for
    -- the whole of every pull.
    --
    -- Each piece answers nil when it has nothing to say, and `part == nil` is
    -- the only question asked about it: a piece that IS present may be a
    -- formatted secret, which may be concatenated but never truth-tested.
    local line
    local function add(part)
        if part == nil then return end
        if line == nil then line = part else line = line .. "  " .. part end
    end

    -- THE SESSION NAME, THE DURATION AND THE TOTAL USED TO BE HERE, behind three
    -- checkboxes that are gone: the name repeated the window's own title, the
    -- duration belongs to the segment the picker already names, and the total is
    -- a figure the column under it holds per player. What is left is the state
    -- that has nowhere else to be said.
    --
    -- `preview` still reaches the line, because "TEST" over a grid full of
    -- placeholder numbers is the one label that stops a player reading invented
    -- data as their own.
    add(preview and L["Test"] or nil)
    add(self:RestrictedNotice(preview))

    -- WHICH FIGHT THIS IS. It was dropped from the header on the argument that it
    -- repeated the window's own title -- true of a window still called "Overall",
    -- and false the moment the player pins a stored segment out of the picker, or
    -- renames the window, which is most of them. So it is back, behind a setting,
    -- rather than back unconditionally.
    --
    -- LAST, so it lands nearest the icon strip: the line is right-aligned and the
    -- picker that changes this label is the control immediately to its right, so
    -- the two read as one thing rather than as a caption and an unrelated button.
    --
    -- SessionLabel(false), never SessionLabel(preview) -- it answers "Test" under
    -- preview, which the first piece above has already said.
    if (self.config.frame or {}).showSegmentText ~= false then
        add(self:SessionLabel(false))
    end

    self.sessionText:SetText(line == nil and "" or line)
end

--- Replace the rows with Blizzard's own reason and what to do about it.
---
--- The failure reason comes from C_DamageMeter.IsDamageMeterAvailable and is
--- quoted rather than interpreted: the game knows why its meter is off, and
--- guessing on its behalf is how an addon tells a player to enable something
--- that was never the problem.
function WindowProto:ShowNotice(reason)
    self:HideAll()
    local lines = {
        L["Blizzard's damage meter is not available."],
        L["Multi Meters reads every number from the game's built-in damage meter. Enable it to see data here."],
    }
    if reason ~= nil and NS.IsConcatSafe and NS.IsConcatSafe(reason) then
        local dim = NS.SkinEscape and NS.SkinEscape("mm.dim") or NS.GRAY
        lines[#lines + 1] = dim .. L["Reason: %s"]:format(tostring(reason)) .. "|r"
    end
    self.notice:SetText(table.concat(lines, "\n\n"))
    self.notice:Show()
end

