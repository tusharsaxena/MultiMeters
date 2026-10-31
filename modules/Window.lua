-- modules/Window.lua
--
-- ONE window: the refresh contract, the layout it is drawn to (rule R3) and the
-- cached config the loop reads. modules/WindowManager.lua owns the registry of
-- these; this file and its five siblings own an instance:
--
--   modules/Window_Frame.lua      the two frames, ApplyConfig, the edge and fill
--   modules/Window_Render.lua     the row pool, the scroll, the clock and the draw
--   modules/Window_Lifecycle.lua  birth, bus wiring, stand-down
--   modules/Window_Header.lua     the header band
--   modules/Window_Placement.lua  where the window sits and whether it is shown
--
-- Frame and Render were peeled out of this file on 2026-10-31 (MM-04), when it
-- stood at exactly layout-§1's 1500-line cap. Issue #29 had kept the loop whole
-- in one file so a reader could follow one frame in one place; the owner ruled
-- the cap first (bundle 2026-10-30-SKIN_FONTS_AND_FEEDBACK, Addendum 07). The
-- cut follows the loop's own banners -- build and apply on one side, pool and
-- refresh on the other -- and the contract that ties them is still stated here.
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
-- one rebuild, so every message handler (wired in modules/Window_Lifecycle.lua)
-- does nothing but set a flag, and a single OnUpdate spends the profile's
-- `data.throttle` (0.25s by default, clamped to Constants.THROTTLE_MIN/MAX)
-- before turning that flag into a Refresh. A twenty-second pull that reports
-- two thousand times still draws eighty times.
--
-- Each window owns a PRIVATE bus target from NS.NewBusTarget(). CallbackHandler
-- keys callbacks by (message, target), so several windows registering the same
-- message on the shared addon object would silently clobber each other and only
-- the last one would ever refresh (anti-pattern #32).

local _, NS = ...

local Const = NS.Constants

-- LibKa0s-Widgets-1.0, for the test-mode strip (W.TestStrip, minor 13) and its sim
-- flavor (`kind = "sim"`, minor 14). Optional: with no library the window builds
-- without a strip, reserves nothing, and the red TEST MODE title word is the label
-- instead (modules/Window_Header.lua); a simulation then has no window marker.
local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

-- The window's own gap above and below the strip. The library publishes the strip's
-- HEIGHT and no reserve: the gap is host layout (MultiMeters#59, LibKa0s#48).
local STRIP_GAP = 2

--- The room the strip slot takes under the title: its height plus a gap above
--- and below while test mode is on OR a simulation runs (22 at HEIGHT 18), and 0
--- otherwise or with no Widgets library. The test strip and the sim strip share
--- the one slot. From mode state and a library constant, never from a strip's
--- own geometry.
local function stripReserve()
    if not (W and W.TestStrip) then return 0 end
    local test = NS.State and NS.State.testMode
    local sim = NS.Sim and NS.Sim:IsActive()
    if not (test or sim) then return 0 end
    return STRIP_GAP + W.TEST_STRIP.HEIGHT + STRIP_GAP
end

local Window = {}
NS.Window = Window

local WindowProto = {}
WindowProto.__index = WindowProto

-- Published for the five files this one was peeled into for layout-§1:
-- modules/Window_Frame.lua, Window_Render.lua, Window_Lifecycle.lua,
-- Window_Header.lua and Window_Placement.lua hang their methods on THIS table,
-- because there is one window prototype and not six. Nothing else reads it, and
-- all five resolve it at file scope -- which is what makes their TOC positions
-- load-bearing.
NS.WindowProto = WindowProto

-- Gap between two adjacent columns. Defined in core/Constants.lua because
-- core/Database_Migrations.lua's width migration sizes a frame around the same seam.
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


local function clamp(v, lo, hi)
    if type(v) ~= "number" then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
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

    -- The size the cells DRAW at (the skin's HUD scale, D-09; still from config): a capped name fits.
    local size = text.size or 11
    if NS.SkinHudFontSize then size = NS.SkinHudFontSize(size, text.fontFromSkin) end
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
    local bodyHeight = (frame.height or 228) - layout.padding * 2
        - layout.titleHeight - layout.stripHeight - layout.headerHeight
    local fits = math.floor((bodyHeight + layout.rowSpacing)
        / (layout.rowHeight + layout.rowSpacing))
    if fits < 1 then fits = 1 end
    local capped = rows.maxRows or 0
    if capped > 0 and capped < fits then fits = capped end
    return math.min(fits, Const.MAX_ROWS)
end

--- Compute every coordinate this window will use, from config and test-mode
--- state; never from widget geometry.
---
--- Not one widget is consulted. That is the whole point: after a cell has been
--- handed a secret value its geometry is secret too, so the only trustworthy
--- source of "where does the third column start" is the arithmetic that put it
--- there. Recomputed on a settings change and on the test-mode toggle (the strip
--- takes room under the title), never on a refresh.
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
        titleHeight = (header.show ~= false) and (header.height or 26) or 0,
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
    -- THE TEST-MODE STRIP takes its room out of the ROWS, never out of the window:
    -- minHeight below leaves it out, so the resize floor does not move under the
    -- player on the toggle and SaveSize never persists a test-mode size. At the
    -- minimum height the strip takes the room of the one row (rowCapacity's floor).
    layout.stripHeight = stripReserve()
    layout.minHeight = pad * 2 + layout.titleHeight + layout.headerHeight + rowHeight
    layout.maxRows = rowCapacity(frame, rows, layout)

    return layout
end

--- Where the chrome below the title sits, from the layout alone: the strip's top,
--- the column headers' top and the body's top, each as a distance down from the
--- frame's top edge. With no strip (stripHeight 0) the headers sit straight under
--- the title, exactly where they always did.
---
--- @return number stripTop
--- @return number headerTop
--- @return number bodyTop
function WindowProto:ChromeOffsets()
    local layout = self.layout
    local below = layout.padding + layout.titleHeight
    local headerTop = below + layout.stripHeight
    return below + STRIP_GAP, headerTop, headerTop + layout.headerHeight
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
    -- A WINDOW IS LOCKED BY ITS OWN `frame.locked` AND NOTHING ELSE. General ->
    -- Master controls' Lock frame is a view over every window's own lock, not a
    -- lock of its own: ticking it writes each window's `frame.locked` through
    -- WindowManager:SetLocked, the same as `/mm lock`. It used to be a second lock
    -- ORed over this one, and after `/mm lock` that left the box unable to unlock
    -- anything (docs/ARCHITECTURE.md, Documented deviations).
    self.locked      = (cfg.frame or {}).locked and true or false
    self.layout      = self:BuildLayout()
    -- A new layout may move a row, so every bound row re-anchors on its next draw.
    self.layoutVersion = (self.layoutVersion or 0) + 1
    -- The row and session-line colors, from the skin once here, never per row (core/SkinSetup.lua).
    if NS.SkinWindowLooks then self.skinLooks = NS.SkinWindowLooks(self.skinLooks) end
end


-- Published for the two files the loop was peeled into (MM-04): modules/Window_Frame.lua
-- takes `clamp` and `lsm`, and modules/Window_Render.lua hangs the row pool's constructor
-- and the OnUpdate clock back on this same table, where modules/Window_Lifecycle.lua
-- resolves them at FILE SCOPE (hence all three load-bearing TOC lines).
NS.WindowInternals = { clamp = clamp, lsm = lsm }
