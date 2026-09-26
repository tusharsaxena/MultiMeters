-- modules/Row_Border.lua
--
-- The cell outline `bars.border` asks for: the four flat edge textures, the LSM
-- edge-art backdrop that replaces them, the color and thickness both paths share,
-- and the per-row re-tint the `class` color mode needs. Peeled out of
-- modules/Row.lua (layout-§1) along the seam the outline already had: every
-- function here reads only each other and three published helpers, and nothing
-- in modules/Row.lua reaches into them -- it calls the two methods below by name,
-- at CALL time (Cell:ApplyLayout and Cell:SetValue).
--
-- The rules modules/Row.lua's header sets out apply here unchanged: no
-- arithmetic and no inspection of a meter value, and no GetWidth / GetLeft /
-- GetPoint anywhere (rule R3). The outline's geometry is two anchors on the
-- cell's own bar and a thickness out of the window's config.

local _, NS = ...

-- Resolved at FILE SCOPE, which is what makes this file's TOC line load-bearing:
-- it must sit after modules\Row.lua, which publishes all four.
--
--   Cell        the shared cell prototype; the two methods below are added to it
--   RGBA        the core seam's color reader, or Row.lua's degraded fallback
--   ClassRGB    the class-color reader, or Row.lua's degraded fallback
--   borderEdge  the LSM edge-art resolver ("None" is a choice, not a failure)
local Internals  = NS.RowInternals
local Cell       = Internals.Cell
local RGBA       = Internals.RGBA
local ClassRGB   = Internals.ClassRGB
local borderEdge = Internals.borderEdge

-- The four sides of the `bars.border` outline. Named rather than written out
-- four times so the create loop, the place loop and the tint loop all walk one
-- list and cannot disagree about how many edges a rectangle has.
local BORDER_SIDES = { "top", "bottom", "left", "right" }

-- Where each side pins itself, and which axis carries the thickness. Both anchor
-- points name the SAME corner on the cell's own bar, so a side spans exactly one
-- edge; the axis it does NOT span is the one the thickness goes on -- a side
-- given a size on both axes is a rectangle, not an edge. Built once at file
-- scope, because this is walked per cell per layout pass.
local BORDER_ANCHOR = {
    top    = { "TOPLEFT",    "TOPRIGHT",    "SetHeight" },
    bottom = { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
    left   = { "TOPLEFT",    "BOTTOMLEFT",  "SetWidth"  },
    right  = { "TOPRIGHT",   "BOTTOMRIGHT", "SetWidth"  },
}

--- The outline's color for one cell, per the window's `bars.borderColorMode`.
---
--- TWO MODES, `class` and `custom`, and `class` is THIS ROW'S PLAYER -- an outline
--- around a cell belongs to the player whose cell it is, exactly as the fill it
--- surrounds does (modules/Row.lua's barColor). It is deliberately not the local player's:
--- the window's own edge is a different swatch on a different page and answers
--- that question its own way (modules/Window.lua's ApplyBorder).
---
--- The skin's edge is still the FALLBACK for a profile that never picked a color,
--- and the CONFIGURED ALPHA survives the mode, so a class-colored outline is as
--- opaque as the swatch beside it says.
---
--- @param bars table|nil   the window's `bars` config group
--- @param entry table|nil  the aggregated row, when there is one
--- @return number r, number g, number b, number a
local function cellBorderColor(bars, entry)
    local skin = NS.SKIN or {}
    local sr, sg, sb, sa = RGBA(skin.border, 0, 0, 0, 1)
    local r, g, b, a = RGBA(bars and bars.borderColor, sr, sg, sb, sa)
    if (bars and bars.borderColorMode) == "class" then
        local cr, cg, cb = ClassRGB(entry and entry.classFilename)
        if cr then r, g, b = cr, cg, cb end
    end
    return r, g, b, a
end

--- The player's border thickness, clamped, for BOTH paths -- the flat textures'
--- axis size and the backdrop's edgeSize are the same dial.
---
--- Clamped rather than trusted: this comes from a slider with a floor, and a
--- zero here is four invisible textures pretending to be a border. The type
--- check is not decoration either -- a string thickness out of a hand-edited
--- profile reaching the `<` raises in Lua 5.1.
---
--- @param bars table|nil  the window's `bars` config group
--- @return number  a thickness of at least 1
local function borderThickness(bars)
    local size = (bars and bars.borderThickness) or 1
    if type(size) ~= "number" or size < 1 then size = 1 end
    return size
end

--- Hide all four flat edge textures, keeping them. The pool's premise is that
--- widget creation happens once, so nothing here destroys anything: the
--- `cell.border` table and each texture keep their identity across the toggle.
---
--- @param edges table|nil  the cell's four-texture border table, when it exists
local function hideFlatBorder(edges)
    if not edges then return end
    for _, side in ipairs(BORDER_SIDES) do edges[side]:Hide() end
end

--- Create the cell's four edge textures, once.
---
--- @param cell table  the Cell
--- @return table  the four-texture border table
local function newBorderEdges(cell)
    local edges = {}
    for _, side in ipairs(BORDER_SIDES) do
        -- SUBLEVEL 7, the top of the OVERLAY layer. A border drawn at the
        -- default sublevel shares it with the two FontStrings and with
        -- whatever the fill texture's own layer resolves to, and "shares"
        -- means the draw order is not defined -- which is how an outline
        -- ends up UNDER the bar it is supposed to be outlining.
        edges[side] = cell.frame:CreateTexture(nil, "OVERLAY", nil, 7)
    end
    return edges
end

--- The ART path: an LSM edge file drawn as the bar's own backdrop, because an
--- edgeFile is a nine-slice and four solid rectangles cannot draw one.
---
--- It takes the four flat textures down on the way through -- the two paths are
--- mutually exclusive and both have to be cleared (see ApplyBorder).
---
--- @param cell table       the Cell
--- @param bars table|nil   the window's `bars` config group
--- @param edge string      the resolved edge file
local function applyArtBorder(cell, bars, edge)
    cell.frame:SetBackdrop({ edgeFile = edge, edgeSize = borderThickness(bars) })
    if cell.frame.SetBackdropBorderColor then
        cell.frame:SetBackdropBorderColor(cellBorderColor(bars, cell.entry))
    end
    hideFlatBorder(cell.border)
end

--- The FLAT path: color, clamp and place the four edge textures, one per side.
---
--- THE PLAYER'S COLOR AND THE PLAYER'S THICKNESS. Both used to be constants:
--- one pixel, in the library skin's own edge color, which no setting could
--- reach -- so "Bar border" was a switch with no dial and no swatch beside it.
--- The skin's edge is still the FALLBACK, so a window that never touches
--- either keeps exactly the border it had.
---
--- ClearAllPoints precedes the two SetPoints on EVERY pass: a second layout pass
--- re-places a side rather than stacking a second pair of anchors on it.
---
--- @param cell table       the Cell
--- @param bars table|nil   the window's `bars` config group
--- @param edges table      the cell's four-texture border table
local function applyFlatBorder(cell, bars, edges)
    local bar = cell.frame
    local r, g, b, a = cellBorderColor(bars, cell.entry)
    local size = borderThickness(bars)

    for _, side in ipairs(BORDER_SIDES) do
        local tex, anchor = edges[side], BORDER_ANCHOR[side]
        tex:ClearAllPoints()
        tex:SetColorTexture(r, g, b, a)
        tex:SetPoint(anchor[1], bar, anchor[1], 0, 0)
        tex:SetPoint(anchor[2], bar, anchor[2], 0, 0)
        tex[anchor[3]](tex, size)
        tex:Show()
    end
end

--- Draw (or hide) the thin outline `bars.border` asks for.
---
--- Four 1px textures rather than a BackdropTemplate child frame. A frame
--- anchored to this StatusBar would inherit its secretness the moment the bar is
--- handed a value (rule R3), and would then be one more thing nobody may
--- measure; a texture is a leaf, exactly like the cell's two FontStrings, and
--- nothing ever reads one back.
---
--- Built on FIRST USE and kept forever after, like every other widget in
--- modules/Row.lua — a player toggling the setting off does not destroy them, because the
--- pool's whole premise is that widget creation happens once.
---
--- The color falls back to the collection's own edge (NS.SKIN.border) when the
--- player has not picked one, so a window that never touches the setting keeps
--- the outline it always had.
---
--- TWO IMPLEMENTATIONS, AND THE CHEAP ONE IS THE DEFAULT. A border style of
--- "None" -- the shipped value -- is the four flat textures described above, and
--- costs nothing new. Any LSM edge ART needs a real backdrop, because an
--- edgeFile is a nine-slice and four solid rectangles cannot draw one, so that
--- path calls SetBackdrop on the cell itself.
---
--- THE BACKDROP GOES ON THE BAR, NOT ON A CHILD FRAME, and that distinction is
--- rule R3's: a child frame anchored to a StatusBar that has been handed a secret
--- inherits its secret anchoring, while a backdrop is textures the frame owns.
--- Nothing here reads anything back either way. It is still the one place this
--- addon decorates a frame that carries meter values, which is why it is opt-in
--- and why docs/smoke-tests.md asks for it to be checked mid-pull.
function Cell:ApplyBorder(bars)
    local wanted = (bars and bars.border) and true or false
    local edge = wanted and borderEdge(bars and bars.borderStyle) or nil
    local edges = self.border

    -- The art path and the flat path are mutually exclusive, and BOTH have to be
    -- cleared: a player switching between them mid-session would otherwise keep
    -- whichever they left behind, drawn on top of the one they chose.
    if self.frame.SetBackdrop then
        if edge then
            applyArtBorder(self, bars, edge)
            return
        end
        self.frame:SetBackdrop(nil)
    end

    -- ABOVE the lazy create, and it has to stay there: the shipped default is
    -- border = false, and hoisting the create costs four textures per cell per
    -- row for an outline nobody asked for.
    if not (wanted or edges) then return end

    if not edges then
        edges = newBorderEdges(self)
        self.border = edges
    end

    if not wanted then
        hideFlatBorder(edges)
        return
    end

    applyFlatBorder(self, bars, edges)
end

--- Re-tint this cell's outline for the player whose row it now is.
---
--- SAME SHAPE AND SAME REASON AS modules/Row.lua's ApplyEntryTextColor: ApplyBorder runs on a
--- LAYOUT and a layout has no entry, so the one mode that depends on the row has
--- to be re-applied per row. It re-tints rather than rebuilding -- the textures and
--- the backdrop are already there and only their color is in question.
---
--- A NO-OP UNLESS THE PLAYER ASKED FOR IT: with the mode anything but `class` this
--- is two table reads and a return, so the default costs nothing on a refresh tick,
--- and the color ApplyBorder painted stands. Turning the mode back off restores it
--- the same way the text color is restored -- a settings change re-runs the layout.
---
--- @param entry table|nil  the aggregated row this cell is drawing
function Cell:ApplyEntryBorderColor(entry)
    local bars = self.window.config.bars or {}
    if bars.borderColorMode ~= "class" then return end
    if not bars.border then return end

    local r, g, b, a = cellBorderColor(bars, entry)

    -- The ART path draws through the frame's backdrop; the flat path is four
    -- textures. Both are re-tinted, because either can be the one on screen and
    -- ApplyBorder chose between them from a setting this function must not re-read.
    local edges = self.border
    if edges then
        for _, side in ipairs(BORDER_SIDES) do edges[side]:SetColorTexture(r, g, b, a) end
    end
    if self.frame.SetBackdropBorderColor then
        self.frame:SetBackdropBorderColor(r, g, b, a)
    end
end
