-- modules/Window.lua
--
-- ONE window: its frames, its header, its row pool, and the coalesced refresh
-- loop that decides when any of it is redrawn. modules/WindowManager.lua owns
-- the registry of these; this file owns an instance.
--
-- A window is an INSTANCE, not a singleton (design §6). Every display setting
-- lives in the window's own config table, which is what makes multi-window and
-- copy-settings-from cheap — and it is why nothing in this file reads
-- `db.profile` for anything except the master enable.
--
-- ---------------------------------------------------------------------------
-- THE ANCHOR FRAME, AND WHY THERE ARE TWO FRAMES INSTEAD OF ONE
-- ---------------------------------------------------------------------------
--
-- Rule R3: a StatusBar handed a secret meter value is marked HasSecretValues,
-- which makes its position data secret and propagates that to anything anchored
-- to it. So no code path in this addon may read geometry back off a widget that
-- has held a value.
--
-- Dragging and resizing want exactly that, though: "where did the user just put
-- this window" is a GetPoint, and "how big did they just make it" is a GetWidth.
-- The way out is to keep those two questions on a frame that can never touch a
-- value. `inst.anchor` is a bare, empty, invisible Frame parented to UIParent.
-- It has no children, no textures and no cells; the VISIBLE window is anchored
-- TOPLEFT and BOTTOMRIGHT to it, so it inherits the anchor's position and size.
--
-- Secretness travels from a frame to whatever is anchored TO that frame — i.e.
-- downstream — and the anchor is upstream of everything. Drag and resize
-- therefore act on the anchor, the two getters read the anchor, and the visible
-- window and its rows are never asked a question about themselves. Everything
-- else on screen — the header strip, the column headers, the row positions, the
-- cell widths — is computed from config in BuildLayout below, and read back from
-- nothing at all.
--
-- ---------------------------------------------------------------------------
-- THE REFRESH LOOP
-- ---------------------------------------------------------------------------
--
-- Meter events fire far faster than a human reads. One event must NEVER drive
-- one rebuild, so every message handler in this file does nothing but set a
-- flag, and a single OnUpdate spends the profile's `data.throttle` (0.25s by
-- default, clamped to Constants.THROTTLE_MIN/MAX) before turning that flag into
-- a Refresh. A twenty-second pull that reports two thousand times still draws
-- eighty times.
--
-- Each window owns a PRIVATE bus target from NS.NewBusTarget(). CallbackHandler
-- keys callbacks by (message, target), so several windows registering the same
-- message on the shared addon object would silently clobber each other and only
-- the last one would ever refresh (anti-pattern #32).

local _, NS = ...

-- Perf bracket upvalue (performance-§2): resolved ONCE at load, never through an
-- NS lookup on the hot path.
local Perf = NS.Perf

local Const = NS.Constants
local MSG   = Const.MSG
local L     = NS.L

local Window = {}
NS.Window = Window

local WindowProto = {}
WindowProto.__index = WindowProto

-- Published for the two files this one was peeled into for layout-§1:
-- modules/Window_Header.lua and modules/Window_Placement.lua hang their methods on
-- THIS table, because there is one window prototype and not three. Nothing else
-- reads it, and both resolve it at file scope -- which is what makes their TOC
-- positions load-bearing.
NS.WindowProto = WindowProto

-- Gap between two adjacent columns. Defined in core/Constants.lua because
-- core/Database.lua's width migration sizes a frame around the same seam.
local COLUMN_GAP = Const.COLUMN_GAP

-- How tall the column-header strip is, as a multiple of the row height. The
-- headers are the same text at the same size as the rows, so tying them to the
-- row height keeps the grid on one rhythm when a player changes it.
local HEADER_ROW_FACTOR = 1.0

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function lsm()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

local function fontPath(name)
    local media = lsm()
    local path = media and name and media:Fetch("font", name, true)
    return path or Const.FONT_MONO or _G.STANDARD_TEXT_FONT
end

-- Published for modules/Window_Header.lua, which draws the title, the session line
-- and the column labels and so asks this exact question three more times. One
-- reader rather than a second LSM lookup carrying its own fallback chain -- the
-- same bargain the header surfaces already struck among themselves.
NS.WindowFontPath = fontPath

--- The LSM border texture the player picked, or nil for "no border at all".
---
--- "NONE" IS ANSWERED HERE, BEFORE THE FALLBACK, and that distinction is the
--- whole shape of this function. `nil` and `""` and LSM's own `"None"` are a
--- CHOICE — the player asked for no edge — and the answer is nil. A name that is
--- present but cannot be fetched is a FAILURE, most often a media pack that is no
--- longer installed, and that falls back to the LIBRARY's own edge rather than to
--- a literal: NS.SKIN's edgeFile is the Ka0s window edge (standalone-windows),
--- and restating it here would be the copy that goes stale one hex digit at a
--- time.
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
-- Defined once, below, beside the other colour readers.
local surfaceColor

local function borderPath(name)
    if type(name) ~= "string" or name == "" or name == "None" then return nil end
    local media = lsm()
    local path = media and media:Fetch("border", name, true)
    return path or (NS.SKIN and NS.SKIN.edgeFile)
end

-- Taken from the CORE SEAM (core/CoreSetup.lua publishes NS.RGBA), not from a
-- second LibStub lookup carrying its own copy of the library's channel reader —
-- the same note applies in modules/Row.lua, which is precisely the file the copy
-- was duplicated with. Resolved defensively so a degraded install renders in the
-- caller's default colors instead of raising.
local RGBA = NS.RGBA or function(_, dr, dg, db, da)
    return dr, dg, db, da
end

local function clamp(v, lo, hi)
    if type(v) ~= "number" then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
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
--- @param key string  scale | alpha | locked
local function masterSetting(key)
    local read = NS.MasterSetting
    local v = read and read(key)
    local bounds = MASTER_BOUNDS[key]
    if not bounds then return v end
    return clamp(v, bounds[1], bounds[2])
end

--- Resolve a collaborator module by either shape it can have: a plain table hung
--- on NS, or an AceAddon module in the registry. Same resolution PerfSetup uses,
--- and for the same reason — the modules are written by different hands and this
--- file must not care which idiom won.
local function mod(name)
    local m = NS[name]
    if m then return m end
    if NS.GetModule then return NS:GetModule(name, true) end
    return nil
end

-- Published for modules/Window_Header.lua's segment selector, which resolves
-- modules/Provider.lua by the same either-shape rule.
NS.WindowModule = mod

-- ---------------------------------------------------------------------------
-- Layout — rule R3 in one function
-- ---------------------------------------------------------------------------

--- How wide the Player column has to be, from the config alone.
---
--- IT FOLLOWS "MAX NAME LENGTH", and it did not before: the cap shortened the
--- text and the column stayed at a fixed 118px, so lowering it left a wide
--- column with a short name rattling around in it and raising it clipped the
--- name the setting had just permitted. The setting names a number of
--- CHARACTERS, so the column it lives in is the one thing that should follow it.
---
--- FROM CONFIG, NEVER MEASURED. Rule R3 (docs/data-flow.md): layout is computed,
--- never read back off a frame. So the per-character width is an ESTIMATE off the
--- font size rather than a GetStringWidth -- NAME_CHAR_RATIO is a little generous
--- because a name that is one pixel too wide is a name with a comma clipped off
--- its realm, while one that is a few too wide costs nothing anybody can see.
---
--- The icon's allowance is added only when the icon is actually drawn, which is
--- the other half of what the player asked for: turning the icon off should give
--- the width back to the name rather than leave a hole where a picture was.
--- `ICON_TEXT_GAP` is modules/Row.lua's, published rather than restated, because
--- the two files reserving different gaps is how a name gets clipped by the
--- space its icon was promised.
---
--- @param cfg table  a window config
--- @return number  pixels
local function nameColumnWidth(cfg)
    local text  = cfg.text or {}
    local icons = cfg.icons or {}

    local cap = text.maxNameLength
    -- 0 is the documented "no cap", and a window with no cap has no length to
    -- size itself from -- so it keeps the shipped width.
    if type(cap) ~= "number" or cap <= 0 then return Const.NAME_COLUMN_WIDTH end

    local size = text.size or 11
    local width = math.ceil(cap * size * Const.NAME_CHAR_RATIO) + Const.NAME_COLUMN_PAD

    if icons.showIcon then
        width = width + (icons.size or 14) + (NS.ICON_TEXT_GAP or 4)
    end

    if width < Const.NAME_COLUMN_MIN then width = Const.NAME_COLUMN_MIN end
    return width
end

--- The stat columns of one window: which stored entries are drawn, how wide each
--- one is, where each one starts, and the narrowest the grid may be dragged to.
---
--- FROM CONFIG ONLY, like the rest of the layout. It is handed the config and
--- three numbers and reads nothing back off a frame -- rule R3 survives the peel
--- precisely because there is no frame argument here to break it with.
---
--- The name column has already been placed at x 0 by the caller, so this starts
--- the running x past it and its seam.
---
--- @param cfg table  a window config
--- @param frame table  cfg.frame, already defaulted to a table by the caller
--- @param pad number  the frame padding
--- @param nameWidth number  the Player column's width
--- @return table columns, number x, number minWidth
local function columnLayout(cfg, frame, pad, nameWidth)
    -- STAT COLUMNS SHARE WHATEVER THE FRAME HAS LEFT, EQUALLY.
    --
    -- Dragging the window wider used to leave the grid where it was and add empty
    -- space on the right; dragging it narrower clipped the rightmost column off
    -- the edge. Neither is what a player means by resizing a table.
    --
    -- So the stored per-column `width` stops being the drawn width and becomes
    -- what it always described — the shape a NEW column is born at. The drawn
    -- width is the frame's, minus the padding, minus the name column, minus the
    -- seams, divided by however many columns there are. The name column is
    -- excluded on purpose: a name does not get longer because the window did.
    --
    -- Const.COLUMN_MIN_WIDTH is the floor. Below it a column cannot hold an
    -- abbreviated number and its header at once, so the grid stops shrinking and
    -- the frame is clamped instead (MinResize below).
    local visible = {}
    for _, col in ipairs(cfg.columns or {}) do
        -- TWO REASONS A STORED ENTRY IS NOT DRAWN, and they are different facts.
        --
        -- `enabled == false` is the player's decision, made on the Columns page
        -- and reversible there. Every statistic in the catalog has an entry now,
        -- so most of a typical window's array is exactly this case.
        --
        -- An unknown stat is a profile written against a build with more
        -- statistics than this one. normalizeColumns drops those on the way IN,
        -- so reaching one here means an array that has not been through the seam
        -- yet -- and a nameless empty column is worse than an absent one either
        -- way.
        local stat = col.enabled and Const.STAT_BY_KEY[col.stat]
        if stat then visible[#visible + 1] = { col = col, stat = stat } end
    end

    local statWidth = Const.COLUMN_WIDTH
    if #visible > 0 then
        local available = (frame.width or 694) - pad * 2
            - nameWidth - COLUMN_GAP * #visible
        statWidth = math.floor(available / #visible)
        if statWidth < Const.COLUMN_MIN_WIDTH then statWidth = Const.COLUMN_MIN_WIDTH end
    end

    local columns = {}
    local x = nameWidth + COLUMN_GAP
    for _, entry in ipairs(visible) do
        columns[#columns + 1] = {
            key   = entry.col.stat,
            stat  = entry.stat,
            x     = x,
            width = statWidth,
        }
        x = x + statWidth + COLUMN_GAP
    end

    -- Zero visible columns is a live arm: math.max(#visible, 1) still reserves one
    -- column of floor, so the window cannot be dragged down onto the name alone.
    local minWidth = nameWidth + pad * 2
        + math.max(#visible, 1) * (Const.COLUMN_MIN_WIDTH + COLUMN_GAP)

    return columns, x, minWidth
end

--- How many rows this window will ask the pool for.
---
--- `rows.maxRows == 0` means "as many as fit", which is why this is computed from
--- the configured frame height rather than read off the frame -- and Const.MAX_ROWS
--- is the final cap that keeps a corrupted config from asking the pool for
--- thousands of frames.
---
--- @param frame table  cfg.frame, already defaulted to a table by the caller
--- @param rows table  cfg.rows, likewise
--- @param layout table  the layout so far: padding, titleHeight, headerHeight,
---        rowHeight and rowSpacing are all already resolved on it
--- @return number
local function rowCapacity(frame, rows, layout)
    local bodyHeight = (frame.height or 220) - layout.padding * 2
        - layout.titleHeight - layout.headerHeight
    local fits = math.floor((bodyHeight + layout.rowSpacing)
        / (layout.rowHeight + layout.rowSpacing))
    if fits < 1 then fits = 1 end
    local capped = rows.maxRows or 0
    if capped > 0 and capped < fits then fits = capped end
    return math.min(fits, Const.MAX_ROWS)
end

--- Compute every coordinate this window will use, from CONFIG ONLY.
---
--- Not one widget is consulted. That is the whole point: after a cell has been
--- handed a secret value its geometry is secret too, so the only trustworthy
--- source of "where does the third column start" is the arithmetic that put it
--- there. Recomputed on a settings change, never on a refresh.
---
--- @return table layout
function WindowProto:BuildLayout()
    local cfg    = self.config
    local frame  = cfg.frame or {}
    local rows   = cfg.rows or {}
    local header = cfg.header or {}

    local pad       = frame.padding or 6
    local rowHeight = rows.height or 16
    local spacing   = rows.spacing or 1

    -- The name column is not a stat and can never be removed, so it is placed
    -- first and separately (core/Constants.lua).
    local nameWidth = nameColumnWidth(cfg)
    local columns, x, minWidth = columnLayout(cfg, frame, pad, nameWidth)

    local layout = {
        padding     = pad,
        rowHeight   = rowHeight,
        rowSpacing  = spacing,
        titleHeight = (header.show ~= false) and (header.height or 18) or 0,
        headerHeight = rowHeight * HEADER_ROW_FACTOR,
        growUp      = (rows.growthDirection == "UP"),
        columns     = columns,
        nameColumn  = { key = "name", x = 0, width = nameWidth, showBar = true },
        -- The smallest this window may be dragged to, both axes, from the same
        -- arithmetic that just laid it out. Published on the layout so the resize
        -- clamp and the layout can never disagree about it.
        minWidth    = minWidth,
        rowWidth    = x - COLUMN_GAP,
        bodyWidth   = (frame.width or 694) - pad * 2,
    }
    layout.minHeight = pad * 2 + layout.titleHeight + layout.headerHeight + rowHeight
    layout.maxRows = rowCapacity(frame, rows, layout)

    return layout
end

-- ---------------------------------------------------------------------------
-- Cached config (performance-§3)
-- ---------------------------------------------------------------------------

--- Cache the per-refresh config reads into instance fields, and rebuild the
--- layout. Called on creation and on ANY settings change — never per frame.
---
--- The values below are read on every OnUpdate tick, and reaching
--- the profile's `data.throttle` forty times a second through three table lookups
--- is exactly the per-frame cost the standard's upvalue rule exists to remove.
function WindowProto:RefreshUpvalues()
    local cfg = self.config
    local data = cfg.data or {}

    -- ADDON-WIDE since it stopped being a property of a window: a refresh rate
    -- is one answer, not one per window. Still cached as an upvalue here, which
    -- is the whole point of this function — NS.DataSetting walks two tables and
    -- this is read on every OnUpdate tick.
    local throttle   = (NS.DataSetting and NS.DataSetting("throttle")) or 0.25
    self.throttle    = clamp(throttle, Const.THROTTLE_MIN, Const.THROTTLE_MAX)
    self.sessionType = data.sessionType or Const.SESSION_TYPE.Current
    self.sortColumn  = data.sortColumn or "DamageDone"
    -- EITHER LOCK PINS THE WINDOW. `master.locked` (General -> Master controls) is
    -- addon-wide and `frame.locked` (Frame -> General) is this window's own; a
    -- window is draggable only while neither is on. ORed rather than overriding,
    -- so unticking the master leaves the windows a player locked one at a time
    -- locked -- an override would silently erase those.
    self.locked      = (masterSetting("locked") or (cfg.frame or {}).locked) and true or false
    self.layout      = self:BuildLayout()
end

-- ---------------------------------------------------------------------------
-- Frame construction
-- ---------------------------------------------------------------------------

local function onDragStart(frame)
    local inst = frame.mmWindow
    if not inst or inst.locked then return end
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

local function onResizeStop(grip)
    local inst = grip.mmWindow
    if not inst then return end
    inst.anchor:StopMovingOrSizing()
    inst:SaveSize()
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
    anchor:SetSize(frameCfg.width or 694, frameCfg.height or 220)
    anchor:SetMovable(true)
    anchor:SetResizable(true)
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
    -- The title and divider members are assigned BEFORE ApplySkin so the library
    -- can tint them. Their colors are deliberately never set here: Core.SKIN's
    -- values are the contract, and a matching literal in this file is the copy
    -- that goes stale one hex digit at a time (standalone-windows).
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -5)

    frame.divider = frame:CreateTexture(nil, "ARTWORK")
    frame.divider:SetHeight(1)

    -- The header strip's own background (`header.bgColor`). On the BORDER layer:
    -- above the backdrop's bgFile, which is BACKGROUND, and below the divider,
    -- which is ARTWORK — so the strip tints without swallowing the line under
    -- it. Built here rather than on first use so moving the setting re-colors a
    -- texture that already exists instead of creating one mid-frame.
    --
    -- Not a member of `frame`: NS.ApplySkin walks a fixed set of frame keys and
    -- an extra one is a key it has never heard of.
    self.headerBG = frame:CreateTexture(nil, "BORDER")

    if NS.ApplySkin then NS.ApplySkin(frame) end

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
    -- grid keeps exactly the behaviour it has today and only a drilled window
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

    -- ALWAYS BUILT, never gated on a setting. There used to be a `resizeGrip`
    -- checkbox read right here, and because BuildFrame runs ONCE per window,
    -- unticking it did nothing at all until a reload -- the reported bug. The
    -- grip's visibility is the LOCK's answer and only the lock's: ApplyLock and
    -- ApplyMinimised are its two authors and both ask the same question.
    do
        -- THE GRIP ART IS A PAIR, and that is why it is not the catalog's.
        -- LibKa0s-Media carries `resize`, but it is one glyph in one state; this
        -- is -Up plus -Highlight, the two-state chrome a player already reads in
        -- every chat window, and the catalog publishes no hover variant of
        -- anything (library-stack-§8). Both paths are carried in
        -- docs/ARCHITECTURE.md's "Hard-coded texture paths" census.
        local grip = CreateFrame("Button", nil, frame)
        grip:SetSize(12, 12)
        grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
        grip:SetNormalTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up]])
        grip:SetHighlightTexture([[Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight]])
        grip.mmWindow = self
        grip:SetScript("OnMouseDown", function() anchor:StartSizing("BOTTOMRIGHT") end)
        grip:SetScript("OnMouseUp", onResizeStop)
        self.grip = grip
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

    self.anchor:SetSize(frameCfg.width or 694, frameCfg.height or 220)
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
    frame:SetFrameStrata(frameCfg.strata or "MEDIUM")

    -- The skin is re-applied rather than patched: ApplySkin owns the backdrop,
    -- the inner border and the two accent tints, and re-running it is how a
    -- re-skinned library lands here without this file knowing what changed.
    -- ApplyBorder then layers the player's edge over the result — in that order,
    -- because the skin is the base look and the setting is the override.
    if NS.ApplySkin then NS.ApplySkin(frame) end
    self:ApplyBorder(frameCfg)

    self:ApplyHeader()

    -- The body is placed from config, and everything below it hangs off the body
    -- rather than off a sibling — one anchor chain, one direction, no cycles.
    local pad = layout.padding
    self.body:ClearAllPoints()
    self.body:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -(pad + layout.titleHeight + layout.headerHeight))
    self.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)

    self.notice:ClearAllPoints()
    self.notice:SetPoint("TOPLEFT", self.body, "TOPLEFT", 4, -8)
    self.notice:SetPoint("TOPRIGHT", self.body, "TOPRIGHT", -4, -8)
    self.notice:SetFont(fontPath((cfg.header or {}).font), (cfg.text or {}).size or 11, "")

    for _, row in ipairs(self.pool.all) do
        row:ApplyLayout(layout)
    end
    self:ApplyResizeBounds()
    self:ApplyLock()
    self:ApplyMinimised()
end

--- The window edge: `frame.borderStyle`, `borderSize` and `borderColor`.
---
--- LAYERED OVER NS.ApplySkin, never instead of it. The library has just written
--- its own backdrop onto the frame — bgFile, edgeFile, edgeSize, insets — and
--- this rewrites ONE part of that table: the edge. The base fields are read back
--- off NS.SKIN rather than restated as literals here, which is the whole reason
--- the seam exports SKIN alongside ApplySkin (core/CoreSetup.lua). A re-skinned
--- library therefore still lands on this window, and the only thing this file
--- claims to know is what the PLAYER chose.
---
--- `borderSize == 0` means "no edge", and it drops edgeFile with it: a zero
--- edgeSize with a texture still present is the combination WoW draws as a hard
--- 1px line, which is the setting doing the opposite of what it says. A
--- borderStyle of "None" means the same thing and is `borderPath`'s answer, not
--- this function's -- the rule belongs with the resolver, so a second caller
--- inherits it instead of restating it.
---
--- THE SKIN'S INNER HIGHLIGHT GOES WITH THE EDGE. LibKa0s's ApplySkin builds a
--- 1px `frame.innerBorder` child inset inside the black edge, and it is a child
--- frame rather than part of the backdrop this function rewrites -- so with the
--- style set to None and the thickness at 0 it was the whole visible border,
--- outliving both controls that claim to govern one. It is shown exactly when
--- there is an edge for it to sit inside.
---
--- @param frameCfg table  the window's `frame` config group
function WindowProto:ApplyBorder(frameCfg)
    local frame = self.frame
    if not frame.SetBackdrop then return end

    local skin = NS.SKIN or {}
    local size = clamp(frameCfg.borderSize or 2, 0, 32)
    local edge = (size > 0) and borderPath(frameCfg.borderStyle) or nil
    local inset = edge and size or 0

    -- Type-tested, not truth-tested: `innerBorder` is a key LibKa0s writes onto a
    -- frame this file does not own, and a mock that answers every key with a
    -- function would otherwise be indexed as a frame -- the library's own header
    -- records that exact breakage.
    if type(frame.innerBorder) == "table" and frame.innerBorder.SetShown then
        frame.innerBorder:SetShown(edge ~= nil)
    end

    frame:SetBackdrop({
        bgFile   = skin.bgFile,
        edgeFile = edge,
        edgeSize = edge and size or nil,
        insets   = { left = inset, right = inset, top = inset, bottom = inset },
    })

    -- BOTH SWATCHES ANSWER A MODE NOW (options-ui-§17). Two values each, class and
    -- custom: a window's fill and its edge belong to the WINDOW rather than to any
    -- row in it, so `class` is the LOCAL player's -- the same call headerColor
    -- makes for the strip along the top. "Per statistic" is deliberately absent for
    -- the reason it is absent from the title bar: over one surface spanning the
    -- whole window it could only ever mean the sort column's colour, which is
    -- already on screen twice.
    --
    -- THE CONFIGURED ALPHA SURVIVES THE MODE, which is what makes the backdrop's
    -- 0.75 a tint under `class` rather than a slab: RAID_CLASS_COLORS carries no
    -- alpha, and a mode that reset transparency would be one setting cancelling
    -- another. It is also why neither swatch is ever disabled.
    local br, bg, bb, ba = surfaceColor(frameCfg.backdropColorMode, frameCfg.backdropColor,
        nil, 0, 0, 0, 0.75)
    if frame.SetBackdropColor then frame:SetBackdropColor(br, bg, bb, ba) end

    if edge and frame.SetBackdropBorderColor then
        local er, eg, eb, ea = surfaceColor(frameCfg.borderColorMode, frameCfg.borderColor,
            nil, 0, 0, 0, 1)
        frame:SetBackdropBorderColor(er, eg, eb, ea)
    end
end

--- Resolve one of the header surfaces' three colour modes.
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
--- THE CONFIGURED ALPHA SURVIVES EVERY MODE. Neither RAID_CLASS_COLORS nor the
--- stat palette carries one, and a mode that silently reset transparency would be
--- one setting cancelling another — which matters most for the two BACKGROUNDS,
--- where the alpha is what makes a colour a tint rather than a slab.
---
--- A colour that cannot be resolved — an unknown class, a stat with no palette
--- entry — falls back to the CONFIGURED one, which is the honest answer rather
--- than an invented hue.
---
--- @param mode string|nil    "class" | "stat" | "custom"
--- @param stored table|nil   the configured colour
--- @param statKey string|nil which statistic `stat` means here
--- @param dr number @param dg number @param db number @param da number
--- @return number r, number g, number b, number a
function surfaceColor(mode, stored, statKey, dr, dg, db, da)
    local r, g, b, a = RGBA(stored, dr, dg, db, da)

    if mode == "class" then
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

-- ---------------------------------------------------------------------------
-- The row pool
-- ---------------------------------------------------------------------------
--
-- Ten or more dynamic frames means a pool rather than create-and-destroy: a
-- 40-player raid that reshuffles every quarter second would otherwise churn
-- hundreds of frames a minute, and WoW never truly frees one. Rows are acquired
-- for a refresh, released at the end of it, and kept forever.

--- A row pool: the library's two arrays, plus the host's third.
---
--- `all` holds every row ever built, parked ones included. ApplyLayout and ApplyLock iterate it so
--- a FREE row is re-laid-out too — without that, a row parked across a settings change comes back
--- at the old width the next time the group grows, and nothing would have caught it.
local function newRowPool()
    local pool = NS.Pool.New()
    pool.all = {}
    return pool
end

--- Take a row from the free list, growing the pool a batch at a time.
---
--- The free/active mechanics are the library's. The BATCH lives in the factory closure because
--- `Acquire` calls its factory once per miss: the closure builds the batch, parks the surplus on
--- the free list the library is about to draw from, registers all of it in `pool.all`, and returns
--- one. Each row costs an ApplyLayout and an EnableCellMouse at build, which is why they are built
--- five at a time rather than on demand.
function WindowProto:Acquire()
    local pool = self.pool
    return NS.Pool.Acquire(pool, function()
        local first
        for i = 1, Const.POOL_GROW_STEP do
            local fresh = NS.Row.New(self)
            fresh:ApplyLayout(self.layout)
            fresh:EnableCellMouse()
            pool.all[#pool.all + 1] = fresh
            if i == 1 then first = fresh else pool.free[#pool.free + 1] = fresh end
        end
        return first
    end)
end

--- Return every active row to the free list.
---
--- `Release` runs through the library's `before` hook, so it still sees the row while it is shown
--- and the library hides it immediately after — in the same call.
---
--- RANK STABILITY IS THE LIBRARY'S PROMISE NOW, not ours. `ReleaseAll` parks the active set
--- backward as of LibKa0s-Pool-1.0 minor 3, so the next run of `Acquire` calls hands position 1
--- the widget position 1 had. This function used to reverse the parked segment itself to get
--- that; against a library that already parks backward that reversal double-reverses and brings
--- the flicker straight back, so it came out in the same commit as the minor-3 payload. There is
--- nothing to add here — the ordering invariant is still required, and
--- tests/test_window.lua still pins it.
function WindowProto:HideAll()
    NS.Pool.ReleaseAll(self.pool, function(row) row:Release() end)
end

-- ---------------------------------------------------------------------------
-- The refresh
-- ---------------------------------------------------------------------------

--- Mark the window as needing a redraw. Every message handler ends here and
--- nothing else, which is what makes the throttle the only clock in the file.
--- The largest legal scroll offset for a list of `count` rows.
---
--- Derived from `layout.maxRows`, which is itself derived from the configured
--- frame height — so this is config arithmetic rather than a measurement, and it
--- answers 0 whenever everything already fits.
function WindowProto:MaxScroll(count)
    local visible = (self.layout and self.layout.maxRows) or 1
    local over = (count or 0) - visible
    return (over > 0) and over or 0
end

--- Move the scroll offset by `delta` rows and redraw.
---
--- ONLY THE FLOOR IS APPLIED HERE. The ceiling is the length of a list this
--- function does not have: it runs from a wheel event, between refreshes, and
--- asking the aggregator for a fresh list to find out how long it is would turn
--- a scroll into a meter read. So the offset is allowed to run optimistically
--- past the end and `Render` clamps it against the list it is actually drawing.
---
--- That is not a shortcut, it is the only ordering that cannot go stale: a
--- remembered row count is one refresh out of date the moment the group changes,
--- and clamping against a stale count is how a scroll silently stops one row
--- short of the bottom.
---
--- @param delta number  rows to move; negative is toward the top
function WindowProto:ScrollBy(delta)
    local want = (self.scrollOffset or 0) + (delta or 0)
    if want < 0 then want = 0 end
    if want == self.scrollOffset then return end

    self.scrollOffset = want
    self:MarkDirty()
    -- The wheel must answer NOW rather than on the next throttle tick, for the
    -- same reason a drill-down click does.
    self.elapsed = self.throttle
end

--- Put the view back at the top. Called when the LIST CHANGES IDENTITY —
--- entering or leaving a breakdown — because an offset carried across is an
--- offset into a list that no longer exists.
function WindowProto:ResetScroll()
    if self.scrollOffset == 0 then return end
    self.scrollOffset = 0
end

function WindowProto:MarkDirty()
    self.dirty = true
end

--- Whether this window should redraw on the throttle tick even though no message
--- has marked it dirty.
---
--- THE METER'S EVENTS ARE NOT A COMPLETE HEARTBEAT, and relying on them alone is
--- why a live window's numbers sat still through a fight.
--- `DAMAGE_METER_CURRENT_SESSION_UPDATED` describes the CURRENT session; a window
--- reading Overall, or pinned to a stored segment, is not what that event is
--- about and can go a whole pull without one arriving. The rows were correct and
--- stale at the same time, which is the worst way for a meter to be wrong.
---
--- So while a fight is on, a SHOWN window polls on the clock it already has.
--- This costs one aggregate per throttle tick per visible window — 0.25s by
--- default, which is exactly the rate a busy pull already drives through the
--- dirty flag — and it costs nothing at all out of combat, where the events are
--- sufficient and a still window should do no work.
---
--- @return boolean
function WindowProto:ShouldPoll()
    if not self.frame:IsShown() then return false end
    -- A COLLAPSED WINDOW HAS NOTHING TO DRAW INTO. This is a real clause and not
    -- an emergent one: `OnUpdate` is installed on `frame`, which stays SHOWN
    -- while minimised -- only the body hides -- so without this the window goes
    -- on aggregating every stat and rendering rows into a hidden body four times
    -- a second, forever.
    if (self.config.frame or {}).minimised then return false end
    if self:IsTest() then return false end
    local inCombat = _G.InCombatLockdown and _G.InCombatLockdown()
    if inCombat then return true end
    return (NS.Secrets and NS.Secrets.IsRestricted()) and true or false
end

local function onUpdate(frame, elapsed)
    local inst = frame.mmWindow
    if not inst then return end
    inst.elapsed = (inst.elapsed or 0) + elapsed
    if inst.elapsed < inst.throttle then return end
    inst.elapsed = 0
    if not inst.dirty and not inst:ShouldPoll() then return end
    inst.dirty = false
    inst:Refresh()
end

--- Can the game's meter give this window anything, and if not, what does it say
--- about why.
---
--- Provider is called in the DOT form its own file publishes it in
--- (`Provider.IsAvailable`): these are plain namespaced functions, not methods,
--- and a colon here would hand it this window as its first argument. A missing
--- Provider is treated as available, because the notice it would raise is about
--- the GAME's meter and there is nothing here to have asked.
---
--- @return boolean available, string|nil reason
local function meterAvailability()
    local Provider = mod("Provider")
    if Provider and Provider.IsAvailable then
        return Provider.IsAvailable()
    end
    return true, nil
end

--- The spell breakdown this window is drilled into, or nil when it is showing
--- the ordinary grid.
---
--- Detected by BuildRows answering non-nil rather than by a mode flag this file
--- would have to keep in step with modules/DrillDown.lua's own idea of what is
--- open. The rows are a plain table, so testing THEM is safe; the title beside
--- them may be a secret string — DrillDown formats the source's
--- ConditionalSecret name into it — so it is passed on as text and never tested.
---
--- @return table|nil rows, string|nil title
local function drillRowsFor(config)
    local DrillDown = mod("DrillDown")
    if DrillDown and DrillDown.BuildRows then
        return DrillDown:BuildRows(config)
    end
    return nil, nil
end

--- The ordered rows the aggregator answers for this window.
---
--- ONE PATH. There is no test branch here any more. Test mode used to hand the
--- renderer a whole separate result table built by a separate function, which
--- made the two modes diverge at every seam nobody thought to duplicate:
--- tooltips found no source, the drill-down opened on nothing, and every fix had
--- to be applied twice. It now substitutes the DATA, at modules/Provider.lua and
--- modules/Roster.lua — the two files that talk to the client — so everything
--- from here down is the live code reading invented numbers.
---
--- Called in the DOT form for the same reason meterAvailability is. "refresh" is
--- the perf bracket this runs inside, passed so the aggregate's capture observes
--- its parent (issue #47).
local function aggregateEntries(Aggregator, config)
    if Aggregator.Build then return Aggregator.Build(config, "refresh") end
    return nil
end

--- Whether the window draws placeholder data.
---
--- ONE DOOR: `/mm test`, or the General page's checkbox, both of which write
--- NS.State.testMode.
---
--- An unlocked window used to imply this, and that coupling was the first bug
--- reported against the addon: a fresh install ships unlocked, so the very first
--- login showed placeholder rows and no amount of unchecking "Preview mode"
--- would clear them — the lock was still forcing it back on. The lock now governs
--- dragging and nothing else.
function WindowProto:IsTest()
    return (NS.State and NS.State.testMode) and true or false
end

--- Draw the window.
---
--- The order matters. Availability is asked FIRST, because a client with the
--- meter switched off has nothing for any of the rest of this to do; then a
--- drill-down replaces the grid entirely if one is open; then the data comes
--- from the aggregator, in preview form when TEST MODE is on; then the rows are
--- drawn.
---
--- Test mode is the ONE door to preview data -- see IsTest above. An unlocked
--- window used to imply it, and this line still said so a release after the
--- coupling was removed.
function WindowProto:Refresh()
    if not (self.frame and self.frame:IsShown()) then return end
    -- A COLLAPSED WINDOW HAS NOWHERE TO DRAW. ShouldPoll's clause covers the
    -- polling half of the tick and nothing else: onUpdate takes an early branch
    -- on `dirty`, and every meter message sets that flag, so without this the
    -- whole aggregate-and-render ran for a hidden body through an entire fight.
    -- It also stops ShowNotice putting the "waiting for combat data" line back
    -- over a window that has been collapsed.
    if (self.config.frame or {}).minimised then return end

    local t0 = Perf.on and debugprofilestop()

    local available, reason = meterAvailability()
    if not available then
        self:ShowNotice(reason)
        if t0 then Perf.Note("refresh", debugprofilestop() - t0) end
        return
    end

    -- No aggregator is a BROKEN INSTALL, not a switched-off meter, so it draws
    -- nothing rather than telling the player to enable something that is already
    -- on. The chat printer has already said the addon is half-loaded.
    local Aggregator = mod("Aggregator")
    if not Aggregator then
        self:HideAll()
        if t0 then Perf.Note("refresh", debugprofilestop() - t0) end
        return
    end

    -- A PINNED SEGMENT THAT NO LONGER EXISTS IS DROPPED HERE, before anything
    -- reads it. sessionID is persisted, so a window can come back from a reload,
    -- a meter reset or a zone change still pointed at a segment the client has
    -- discarded — and a stale id does not error, it silently reads an empty
    -- session, which looks exactly like a broken addon.
    --
    -- Cleared in the CONFIG rather than shadowed on the instance so there is one
    -- resolved answer: modules/Aggregator.lua, the tooltip and the drill-down all
    -- read `data.sessionID` directly, and a session id is never reused, so
    -- forgetting one loses nothing that could come back.
    self:DropStaleSegment()

    -- A window that is drilled into a player's spell breakdown draws THAT
    -- instead of the grid, so it is asked before the aggregator is. The "is this
    -- a breakdown" answer travels on as its own boolean and the title travels
    -- beside it as text only — a secret string may be drawn, never truth-tested.
    local drillRows, title = drillRowsFor(self.config)
    if drillRows then
        self:Render(drillRows, false, true, title)
        if t0 then Perf.Note("refresh", debugprofilestop() - t0) end
        return
    end

    local preview = self:IsTest()
    self:Render(aggregateEntries(Aggregator, self.config), preview)

    if t0 then Perf.Note("refresh", debugprofilestop() - t0) end
end

--- Put the aggregator's answer on screen.
---
--- The percent text slot used to cost a second full session read per column per
--- refresh: this file asked Provider.GetColumn for every column's group total so
--- the cells could divide by it. modules/Aggregator.lua already holds both
--- operands and already divides — `cell.percent` — so the row path reads that
--- and the extra read is gone.
---
--- @param entries table|nil  the ordered array of rows to draw
--- @param preview boolean
--- @param isDrill boolean|nil  true when these rows are a spell breakdown. A
---   PLAIN boolean, deliberately separate from the title: `drillTitle` can be a
---   secret string and must never be branched on.
--- @param drillTitle string|nil  the breakdown's header line, text only
function WindowProto:Render(entries, preview, isDrill, drillTitle)
    local t0 = Perf.on and debugprofilestop()

    self.notice:Hide()
    self:HideAll()

    local layout = self.layout
    entries = entries or {}

    -- The back button belongs to modules/DrillDown.lua and is anchored into this
    -- window's body at a config-derived offset — nothing measures it, and
    -- nothing measures the body it lands in (rule R3).
    local DrillDown = mod("DrillDown")
    -- NO BACK BUTTON. It used to be acquired here and every drill row shifted
    -- down by its height — which is what pushed the last row out through the
    -- bottom of the frame, since `layout.maxRows` is derived from the body
    -- height and knew nothing about a button drawn inside it. Right-click on any
    -- row leaves a breakdown now (modules/Row.lua), so the height is the rows'
    -- again and the overflow cannot recur.
    if DrillDown and DrillDown.ReleaseBackButton then
        DrillDown:ReleaseBackButton(self.config)
    end

    -- See the note where this script was installed: the body claims the mouse
    -- only while a breakdown is open, so the grid's hover behaviour is untouched.
    self.body:EnableMouse(isDrill and true or false)

    -- THE CLAMP LIVES HERE, and only here. `ScrollBy` applies the floor; this
    -- applies the ceiling, against the list actually being drawn rather than
    -- against a remembered count that a group change would have made stale.
    --
    -- Re-clamping every draw is what covers the list shrinking under a
    -- stationary offset, which happens constantly — a player leaves the group, a
    -- breakdown has fewer spells than the grid had rows — and an offset past the
    -- end would render an empty window that scrolling could not fix.
    local offset = self.scrollOffset or 0
    local maxOffset = self:MaxScroll(#entries)
    if offset > maxOffset then offset = maxOffset end
    if offset < 0 then offset = 0 end
    self.scrollOffset = offset

    local drawn = 0
    for i = 1 + offset, #entries do
        if drawn >= layout.maxRows then break end
        local entry = entries[i]
        if entry then
            drawn = drawn + 1
            local row = self:Acquire()
            local y = NS.Row.OffsetFor(layout, drawn)
            row.frame:ClearAllPoints()
            if layout.growUp then
                row.frame:SetPoint("BOTTOMLEFT", self.body, "BOTTOMLEFT", 0, y)
            else
                row.frame:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -y)
            end
            row:Update(entry, drawn)
        end
    end

    -- An empty grid with no explanation reads as a broken addon. The meter is
    -- available (Refresh established that above), there is simply nothing in the
    -- session yet — which is the normal state between pulls.
    if drawn == 0 and not preview and not isDrill then
        self.notice:SetText(NS.GRAY .. L["Waiting for combat data..."] .. "|r")
        self.notice:Show()
    end

    -- Park the aggregate on the window so UpdateHeaderText can read the group
    -- total off it. The aggregator already computed the sort column's total
    -- during the pass it just made; re-entering Provider.GetColumn for the same
    -- number would be a second full session read per refresh, on the hot path.
    self.aggregate = entries

    self:UpdateHeaderText(preview, isDrill, drillTitle)

    -- ONE debug line per pass, built inside the gate. A line per row would be
    -- forty allocations a quarter second on a raid, all of them discarded by a
    -- disabled sink (debug-logging-§4).
    if NS.State and NS.State.debug then
        -- Keyed on the window id: two windows sharing the `Render` tag would
        -- otherwise alternate and defeat each other's comparison, so neither
        -- would ever be suppressed and the fix would silently do nothing.
        NS.DebugSteady(self.id, "Render", "window %d drew %d/%d rows%s",
            self.id, drawn, #entries, preview and " (preview)" or "")
    end

    -- Render runs only from Refresh, so its one parent is passed and the capture
    -- OBSERVES the nesting rather than taking the descriptor's word (issue #47).
    if t0 then Perf.Note("render", debugprofilestop() - t0, "refresh") end
end

-- ---------------------------------------------------------------------------
-- Bus wiring
-- ---------------------------------------------------------------------------
--
-- A PRIVATE target per window (NS.NewBusTarget), never the shared addon object.
-- Every handler does the same two things — invalidate what the message
-- invalidated, then set the dirty flag — because the throttle is the only thing
-- allowed to decide when work happens.

function WindowProto:RegisterBus()
    local bus = NS.NewBusTarget()
    self.bus = bus
    if not bus then return end

    local function dirty() self:MarkDirty() end

    bus:RegisterMessage(MSG.METER_UPDATED, dirty)
    bus:RegisterMessage(MSG.METER_SESSION, dirty)
    bus:RegisterMessage(MSG.METER_RESET, function()
        self:MarkDirty()
    end)
    bus:RegisterMessage(MSG.RESTRICTION_CHANGED, dirty)

    -- A roster change is both: the rows are stale AND the show answer may have
    -- moved, because `hideWhenSolo` is a roster fact. A window hidden by that
    -- rule has no OnUpdate running — a hidden frame's script does not fire — so
    -- the ladder has to be re-run from the message or the window can never come
    -- back when the player groups up.
    bus:RegisterMessage(MSG.ROSTER_CHANGED, function()
        self:RefreshVisibility()
        self:MarkDirty()
    end)

    -- Context messages change the SHOW answer, not the data, so they go through
    -- the ladder rather than through the dirty flag.
    -- A zone change is the one thing that makes an explicit "show this" stale:
    -- the context rules now have something new to say, which is their whole job.
    bus:RegisterMessage(MSG.ZONE_CHANGED, function()
        self:ClearForcedShow()
        self:RefreshVisibility()
    end)
    bus:RegisterMessage(MSG.ENTERING_WORLD, function()
        self:ClearForcedShow()
        self:RefreshVisibility()
    end)
    -- The player's own state. These are the SAME shape as the roster case above
    -- and they are here for the same reason: modules/Visibility.lua is a
    -- predicate that publishes nothing, so a rule it owns takes effect only when
    -- something re-runs the ladder — and there is no fallback, because onUpdate
    -- refreshes DATA and never re-asks NS.ShouldShow. Without these two
    -- subscriptions, "hide when skyriding" waits for the next zone change,
    -- group change or settings write, which is indistinguishable from not
    -- working. ClearForcedShow is deliberately NOT called: `/mm toggle` is an
    -- explicit request about THIS window, and mounting up is not a reason to
    -- forget it.
    bus:RegisterMessage(MSG.PLAYER_STATE_CHANGED, function()
        self:RefreshVisibility()
    end)
    bus:RegisterMessage(MSG.COMBAT_CHANGED, function()
        self:RefreshVisibility()
    end)
    bus:RegisterMessage(MSG.TEST_MODE_CHANGED, function()
        -- ApplyTitle as well as MarkDirty: the red TEST MODE marker lives in the
        -- title, and the title is only rewritten on a config change — so without
        -- this the marker appeared on the next settings edit rather than on the
        -- toggle that turned it on.
        self:ApplyTitle()
        self:RefreshVisibility()
        self:MarkDirty()
    end)

    -- Entering or leaving a drill-down changes what this window draws entirely.
    -- The name comes from the bus catalog and from nowhere else: a hand-spelled
    -- fallback beside it is a second definition of the same string, and the day
    -- the catalog's value changes the sender moves and the listener does not
    -- (architecture-§4).
    bus:RegisterMessage(MSG.DRILLDOWN_CHANGED,
        function(_, payload)
            local id = payload and payload.windowId
            if id ~= nil and id ~= self.id then return end
            -- The list is about to become a different list. An offset carried
            -- from the grid into a breakdown points into rows that are not there.
            self:ResetScroll()
            self:MarkDirty()
            self.elapsed = self.throttle   -- a click must not wait a full tick
        end)

    -- A settings write. The payload names a window id when the change was
    -- window-relative, so a twenty-window profile does not re-apply nineteen
    -- windows because one of them was edited.
    bus:RegisterMessage(MSG.CONFIG_CHANGED, function(_, payload)
        local id = payload and payload.windowId
        if id ~= nil and id ~= self.id then return end
        self:ApplyConfig()
        self:RefreshVisibility()
        self:MarkDirty()
    end)
end

function WindowProto:UnregisterBus()
    if self.bus and self.bus.UnregisterAllMessages then
        self.bus:UnregisterAllMessages()
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

--- Build one window instance around a stored config.
---
--- @param config table  a window config from db.profile.windows
--- @return table
function Window.New(config)
    local inst = setmetatable({
        id     = config.id,
        config = config,
        -- `free`/`active` are LibKa0s-Pool-1.0's; `all` is host state living beside them, for
        -- the layout and lock passes that must reach PARKED rows too. The library's pool is a
        -- plain table with no metatable precisely so a host can do this. See core/PoolSetup.lua.
        pool   = newRowPool(),
        dirty  = true,
        elapsed = 0,
    }, WindowProto)

    inst:ApplyConfig()
    inst:RegisterBus()
    inst.frame:SetScript("OnUpdate", onUpdate)
    inst:RefreshVisibility()

    return inst
end

--- Point an existing instance at a (possibly rewritten) config table and
--- re-apply everything. Used by the manager after a copy or a rename, so a
--- window is never torn down and rebuilt for a settings change.
function WindowProto:SetConfig(config)
    self.config = config
    self.id = config.id
    self:ApplyConfig()
    self:RefreshVisibility()
    self:MarkDirty()
end

--- Take the window off screen and off the bus for good. The frames survive —
--- WoW never frees one — but nothing references them and nothing drives them.
function WindowProto:Destroy()
    self:UnregisterBus()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
    self:HideAll()
end

--- Stop doing work without changing what the user configured (performance-§6).
--- The OnUpdate goes, which is what stops the coalesced pass already queued from
--- firing once more inside a measurement window and being attributed to an addon
--- that is supposed to be idle. Bus registrations stay: Resume republishes, and
--- a window that had torn them down would never hear it.
function WindowProto:Suspend()
    if self.frame then self.frame:SetScript("OnUpdate", nil) end
end

function WindowProto:Resume()
    if self.frame then self.frame:SetScript("OnUpdate", onUpdate) end
    self:RefreshVisibility()
    self:MarkDirty()
end
