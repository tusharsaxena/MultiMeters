-- modules/Row_NameCell.lua
--
-- The leading column's cell: the icon strip, the name string and the two
-- decisions that keep them clear of each other. Peeled out of modules/Row.lua
-- when that file went past layout-§1's 1500-line cap. It is a sibling rather
-- than a new module because it is not a new widget -- it hangs two more methods
-- on the SAME Cell prototype modules/Row.lua builds, and it is the block that
-- grows: every identity, spec-icon and pet-fold change lands in here.
--
-- WHAT STAYED BEHIND, and why. The CELL DESCRIPTOR -- the contract this pair has
-- with modules/Tooltip.lua and modules/DrillDown.lua -- is documented once, in
-- modules/Row.lua's header, because it is the one thing both files would
-- otherwise have to restate. Read it there before changing a field here.
--
-- The rules modules/Row.lua's header sets out apply here unchanged: no
-- arithmetic and no inspection of a meter value, no GetWidth / GetLeft / GetPoint
-- anywhere (rule R3), and every x on this page is arithmetic on the window's own
-- config.

local _, NS = ...

-- Used for exactly one question: may this GUID be looked at. A source GUID off
-- the meter is never secret, but a row can also carry one the roster read off
-- the unit API, and those can be (modules/Roster.lua's header).
local Secrets = NS.Secrets

-- The three file-locals modules/Row.lua publishes for this file, and the reason
-- its TOC line has to sit AFTER modules\Row.lua: all three are resolved HERE at
-- file scope, so a line that loaded first would freeze three nils in.
--
--   Cell            the shared cell prototype; the two methods below are added
--                   to it, not to a second one
--   cellBackground  the per-row background tint, so the name column is painted
--                   by the same rule as every stat column beside it
--   CLASS_TEXTURE   the client's class atlas, cropped by coordinate below
local Internals      = NS.RowInternals
local Cell           = Internals.Cell
local cellBackground = Internals.cellBackground
local CLASS_TEXTURE  = Internals.CLASS_TEXTURE

-- ---------------------------------------------------------------------------
-- The name cell
-- ---------------------------------------------------------------------------
--
-- Same widget as any other cell — it is a StatusBar so the leading column can
-- carry a class-colored bar too — plus the icons. `classFilename` is NeverSecret,
-- so this column renders in full even when every number to its right is opaque.
--
-- `specIconID` arrives beside it on every row, in a dungeon AND in a raid. That
-- was in doubt: issue #24 recorded a 19-player raid where it was absent from
-- every source row but the local player's, so the spec branch below fired once
-- and every other row drew the CLASS icon. It does not reproduce -- measured
-- 2026-09-09 on an 18-member raid mid-pull, `specIconID` reads `plain 10/10`
-- with six distinct values -- and #24 is closed. `/mm debug identity`'s field
-- audit is the one-command check if it ever goes missing again.
--
-- THE FALLBACK BELOW STAYS, and not only for a source that genuinely has no
-- spec (an NPC, a pet, an unresolved unit). It is silent by construction -- it
-- cannot tell "this source has no spec" from "this client did not send one" --
-- which is exactly what let #24 go unnoticed for as long as it did. The audit
-- is what tells those apart now; the icon rung is not the place to try.

-- The gap between the name column's icon and the name beside it, in pixels. It
-- was a literal 1 folded into the icon's own stride, which reads as the two
-- touching at any icon size a player would actually pick. Named here because
-- modules/Window.lua's name-column width has to reserve exactly this much
-- (BuildLayout's nameColumnWidth) -- the same number in two files is how a name
-- ends up clipped by the width the icon was promised.
local ICON_TEXT_GAP = 4
NS.ICON_TEXT_GAP = ICON_TEXT_GAP

local function newIcon(cell)

    local tex = cell.frame:CreateTexture(nil, "ARTWORK")
    tex:Hide()
    return tex
end

-- The cell's own edge inset for the icon strip, in pixels -- and, when a row has
-- no icons at all, the inset the name string keeps anyway. A name hard against
-- the left edge of the column reads as touching the window frame, so this is
-- what makes the no-icon answer TWO rather than nothing.
local ICON_EDGE_INSET = 2

--- Anchor one cell's icon textures along the name column, one per configured
--- slot, and create the texture the first time a slot is drawn.
---
--- EACH ICON IS PLACED FROM THE CELL'S OWN EDGE, never from the name string
--- beside it: the name is the thing that moves out of the way (placeNameText
--- below). Rule R3 forbids reading a widget's geometry back at all, so every x
--- here is arithmetic on the window's own config.
---
--- ClearAllPoints precedes the SetPoint on every pass -- a layout pass runs on
--- every frame of a drag-resize, and anchors that accumulate resolve against each
--- other, so the first pass would win forever.
---
--- @param cell table        the name Cell
--- @param slots table       the configured slot names, in order
--- @param size number       the icon's edge length
--- @param onRight boolean   whether the strip sits at the cell's right edge
--- @param layout table      the window's layout table
local function placeIcons(cell, slots, size, onRight, layout)
    for i, kind in ipairs(slots) do
        local tex = cell.icons[kind] or newIcon(cell)
        cell.icons[kind] = tex
        tex:ClearAllPoints()
        tex:SetSize(size, size)
        local y = (layout.rowHeight - size) * -0.5
        -- The stride is the icon plus ICON_TEXT_GAP. That gap was a literal 1
        -- folded in here, which reads as the icon and the name touching at any
        -- size a player would actually pick.
        local x = ICON_EDGE_INSET + (i - 1) * (size + ICON_TEXT_GAP)
        if onRight then
            tex:SetPoint("TOPRIGHT", cell.frame, "TOPRIGHT", -x, y)
        else
            tex:SetPoint("TOPLEFT", cell.frame, "TOPLEFT", x, y)
        end
    end
end

--- Hide any icon texture the config has just turned off.
---
--- Kept rather than destroyed: the pool's whole point is that widget creation
--- happens once, so the texture is still there when the setting comes back.
---
--- @param cell table   the name Cell
--- @param slots table  the configured slot names this pass drew
local function hideUnusedIcons(cell, slots)
    for kind, tex in pairs(cell.icons) do
        local wanted = false
        for _, k in ipairs(slots) do if k == kind then wanted = true end end
        if not wanted then tex:Hide() end
    end
end

--- The horizontal space the icon strip reserves, in pixels.
---
--- FIXED SPACE FOR THE ICONS, WHETHER OR NOT A GIVEN ROW HAS THEM. Computed from
--- the CONFIGURED slots rather than from what this row managed to draw, so a
--- follower NPC with no spec icon leaves a gap where the icon would be instead of
--- sliding its name left. A column whose text starts at a different x on every
--- row is not a column.
---
--- @param slots table  the configured slot names
--- @param size number  the icon's edge length
--- @return number  the inset, never zero
local function iconsInset(slots, size)
    return #slots > 0 and (ICON_EDGE_INSET + #slots * (size + ICON_TEXT_GAP)) or ICON_EDGE_INSET
end

--- Place the name string clear of the icon strip.
---
--- IT MOVES WITH THE ICONS: a strip on the left pushes the name past it by the
--- whole inset, a strip on the right leaves the name the cell's own edge. The two
--- decisions are one decision and always change together.
---
--- AN EXPLICIT WIDTH, NOT A SECOND ANCHOR. Two-point anchoring gives the
--- FontString a width too, but it also lets it grow to whatever the frame
--- becomes mid-resize; a fixed width is the same number every pass and is what
--- the truncation cap is measured against. Floored at 1, because the column can
--- genuinely be narrower than the icon plus its insets while a player drags the
--- window's edge in, and SetWidth(0) is a FontString that renders nothing.
---
--- ONE LINE, NEVER WRAPPED. A wrapped name is drawn OUTSIDE its own row -- the
--- second line lands on top of the row below it -- which is what made the grid
--- look shuffled whenever somebody had a long name. The cap in nameText is what
--- shortens it; this is what guarantees the widget cannot undo that decision by
--- reflowing.
---
--- @param cell table       the name Cell
--- @param layout table     the window's layout table
--- @param consumed number  the inset the icon strip reserved
--- @param onRight boolean  whether the strip sits at the cell's right edge
local function placeNameText(cell, layout, consumed, onRight)
    local column = layout.nameColumn or {}
    local width = (column.width or 0) - consumed - 2
    if width < 1 then width = 1 end

    cell.left:ClearAllPoints()
    if onRight then
        cell.left:SetPoint("LEFT", cell.frame, "LEFT", ICON_EDGE_INSET, 0)
    else
        cell.left:SetPoint("LEFT", cell.frame, "LEFT", consumed, 0)
    end
    cell.left:SetWidth(width)
    cell.left:SetHeight(layout.rowHeight)

    if cell.left.SetWordWrap then cell.left:SetWordWrap(false) end
    if cell.left.SetMaxLines then cell.left:SetMaxLines(1) end
end

--- Lay the class / spec / role icons out along the name cell and return the
--- text inset they consume, so the name string starts clear of them.
---
--- @param layout table
--- @return number  the horizontal inset for the name text
function Cell:ApplyIcons(layout)
    local icons = self.window.config.icons or {}
    local size = icons.size or 14
    -- ONE SLOT. There were three, one per icon kind, and a player who turned
    -- them all on got three textures competing with the name for a column that
    -- has to hold a name. The slot picks its own icon per row — see drawUnitIcon.
    local slots = icons.showIcon and { "unit" } or {}

    self.iconOrder = slots
    -- SetPlayer draws into whatever texture it finds and would otherwise SHOW an
    -- icon this pass has just hidden -- the name text moved left with the
    -- setting and the picture came straight back on the next refresh. The
    -- textures are kept (pooling), so the answer is a flag rather than a nil.
    self.iconsShown = #slots > 0
    self.icons = self.icons or {}

    local onRight = (icons.position == "RIGHT")
    placeIcons(self, slots, size, onRight, layout)
    hideUnusedIcons(self, slots)

    local consumed = iconsInset(slots, size)
    placeNameText(self, layout, consumed, onRight)
    return consumed
end

-- The crop applied to a square icon FILE, so the art fills its slot without the
-- transparent border most icon textures carry. Written as the two edges rather
-- than as an inset and a subtraction: these four numbers go straight to
-- SetTexCoord and are compared literally by the render tests.
local ICON_TRIM_MIN, ICON_TRIM_MAX = 0.07, 0.93

-- The default cap, restated nowhere else: settings/Schema.lua's row carries the
-- same number as its `default`, and this is the fallback for a window whose
-- config predates the setting.
local DEFAULT_MAX_NAME = 20

--- Render `entry.name` for the FontString: realm stripped, length capped.
---
--- `entry.name` is ConditionalSecret, so it goes through the same concat probe a
--- number would: on a client that hides it mid-pull the row still draws, with
--- the class icon carrying the identity instead. `== nil` is the one test
--- allowed on it; everything past that asks the core seam whether the value may
--- be turned into a string at all.
---
--- BOTH TRANSFORMS ARE GATED ON THAT PROBE, and that is the whole subtlety here.
--- `string.match` and `string.sub` are INSPECTIONS — they read the characters of
--- the value — and performing one on a secret is exactly what rule R1 forbids.
--- So a plain name is stripped and capped, and a secret name is handed to the
--- widget untouched and uncapped. The uncapped case is not a hole: a name we may
--- not read is one the client is already refusing to show in full.
---
--- WHAT IT MUST NOT DO IS RENDER THE SENTINEL. The opaque branch used to answer
--- NS.SafeToString(name), which is `"<secret>"` — so every row but the local
--- player's said `<secret>` where a name should be, for the whole of a pull. That
--- is the debug renderer's answer, and it is the right one for a LOG LINE, where
--- the alternative is a raise inside string.format.
---
--- A widget is not a log line. `FontString:SetText` ACCEPTS a secret and the
--- client draws the real characters — that is the whole point of the value being
--- opaque to us rather than hidden from the player, and it is the same permission
--- modules/Format.lua relies on to put "12.4M" on a bar it may not divide. So the
--- handle goes to the widget untouched, and the return type of this function is
--- "a string, or something SetText will take" (modules/Format.lua's phrase). Its
--- ONE caller passes it straight to SetText and does nothing else with it; a
--- future caller that wants to compare or concatenate the result has to reach for
--- NS.IsConcatSafe itself.
---
--- Truncate to `cap` CHARACTERS, counting UTF-8 rather than bytes. NO ELLIPSIS:
--- the name column is narrow and a cap that spends its last character saying "I
--- ran out of characters" is a character it could have spent on the name.
---
--- `s:sub(1, cap)` is wrong here and wrong in a way that only shows up on the
--- names most likely to need truncating: "Helyâ" is six bytes and five
--- characters, and a byte slice can land in the middle of the â and emit half a
--- code point, which renders as a replacement box. So the walk skips
--- continuation bytes (0x80-0xBF), which are never the start of a character.
---
--- Pure Lua rather than strlenutf8 / string.utf8sub: those are client globals
--- that the headless harness does not have, and the whole function is six lines.
---
--- @param s string   a PLAIN string — never call this on a secret
--- @param cap number
--- @return string
local function utf8Truncate(s, cap)
    local chars, i, n = 0, 1, #s
    while i <= n do
        local b = s:byte(i)
        -- A continuation byte belongs to the character before it and is not
        -- counted; anything else starts a new one.
        if b < 0x80 or b > 0xBF then
            chars = chars + 1
            if chars > cap then return s:sub(1, i - 1) end
        end
        i = i + 1
    end
    return s
end

--- @param name any        a name string, an opaque handle, or nil
--- @param text table|nil  the window's `text` config group
--- @param stripRealm boolean  true only for a real player's row (see below)
--- @return any  a string, or something SetText will take — see above
local function nameText(name, text, stripRealm)
    if name == nil then return "" end

    if not (NS.IsConcatSafe and NS.IsConcatSafe(name)) then
        -- Opaque. No match, no sub, no length — hand it over AS-IS, which is
        -- what the widget wants and what draws the player's actual name.
        return name
    end

    local out = tostring(name)

    -- REALM STRIP. A cross-realm name arrives as "Player-Realm"; the realm is
    -- never what a player is scanning a meter for and it is most of the column.
    --
    -- GATED ON THE ROW BEING AN ACTUAL PLAYER, and that gate is load-bearing
    -- rather than defensive. A hyphen is only a realm separator in a PLAYER's
    -- name; everywhere else in this grid it is part of the name. The first build
    -- of this stripped on the hyphen unconditionally and rendered the
    -- follower-dungeon NPC "Crenna Earth-Daughter" as "Crenna Earth", which
    -- reads as a truncation bug rather than as a feature.
    --
    -- The test is the GUID, not the name: `Player-` prefixes a character's GUID
    -- and nothing else's. Guessing from the string — "does the part before the
    -- hyphen contain a space" — would be a heuristic about naming conventions we
    -- do not control, when the row is already carrying the answer.
    if stripRealm then
        local bare = out:match("^([^-]+)")
        if bare then out = bare end
    end

    -- LENGTH CAP. 0 means "no cap" — an explicit off switch rather than a
    -- sentinel nobody can guess.
    local cap = (text and text.maxNameLength) or DEFAULT_MAX_NAME
    if type(cap) == "number" and cap > 0 then
        out = utf8Truncate(out, cap)
    end

    return out
end

--- Draw the leading icon slot: the player's class, or — in a drill-down — the
--- spell's own icon.
---
--- A drill-down row is a SPELL, not a player, so the class slot carries the
--- spell's icon, which is the only identity it has. The bar stays the
--- drilled-into player's class color, so the trip into a breakdown and back
--- reads as one continuous view.
--- Draw the row's single icon: the spell's in a breakdown, otherwise the unit's.
---
--- THE LADDER, and each rung is there for a reason rather than as a preference:
---
---   1. A BREAKDOWN ROW IS A SPELL. Its `icon` is the spell's own file id and it
---      has no class, no spec and no role — this rung has nothing to do with
---      units and is first because the row is not one.
---   2. SPEC IF THERE IS ONE. "Which unit is this row" is the question the icon
---      answers, and a spec answers it better than a class: it separates the
---      three druids in a raid, which a class icon cannot.
---   3. CLASS OTHERWISE. A spec is not always known — an NPC, a pet, a player
---      the unit API has not resolved — and a class icon is still an answer.
---   4. NEVER A ROLE. Three roles across a whole raid identifies nobody, and it
---      was the icon most likely to be showing when the name got squeezed.
---
--- `classFilename` and `specIconID` are both NeverSecret, so every branch here
--- keeps working mid-pull when the numbers beside it are opaque.
local function drawUnitIcon(tex, entry)
    if entry.isDrillDown then
        if entry.icon then
            tex:SetTexture(entry.icon)
            tex:SetTexCoord(ICON_TRIM_MIN, ICON_TRIM_MAX, ICON_TRIM_MIN, ICON_TRIM_MAX)
            tex:Show()
        else
            tex:Hide()
        end
        return
    end

    if entry.specIconID then
        tex:SetTexture(entry.specIconID)
        tex:SetTexCoord(ICON_TRIM_MIN, ICON_TRIM_MAX, ICON_TRIM_MIN, ICON_TRIM_MAX)
        tex:Show()
        return
    end

    local coords = _G.CLASS_ICON_TCOORDS
    local c = coords and entry.classFilename and coords[entry.classFilename]
    if c then
        tex:SetTexture(CLASS_TEXTURE)
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
        tex:Show()
    else
        tex:Hide()
    end
end

--- Draw the name column for one player: icons, and a class-colored name.
---
--- NO BAR. The name column used to draw one scaled to the sort column, which
--- duplicated what the sort column's own cell already shows an arm's length to
--- the right and cost this frame its readable geometry to do it.
---
--- @param entry table   the aggregated row
--- @param _sortKey string  the window's sort column; see the note below on why
---   the name cell no longer reads it
function Cell:SetPlayer(entry, _sortKey)
    self.entry = entry

    -- THE NAME CELL IS NEVER HANDED A VALUE. Not "handed one and told not to
    -- draw it" — never handed one.
    --
    -- SetValue(secret) marks a frame HasSecretValues, which makes its anchoring
    -- and position data secret too and propagates that to everything anchored to
    -- it (rule R3). The name cell used to take the sort column's figure purely to
    -- scale a bar behind the name; dropping that bar therefore also takes this
    -- frame out of the secret set entirely, which is a taint win on top of the
    -- visual one. `sortKey` is now unused here and kept in the signature because
    -- modules/Row.lua's caller passes it positionally and a future re-read of the
    -- sort column would land here.
    --
    -- The bar is flattened rather than hidden: the widget still exists (it is the
    -- cell's frame and everything else anchors to it), it just draws nothing.
    self.frame:SetMinMaxValues(0, 1)
    self.frame:SetValue(0)
    self.frame:SetStatusBarColor(0, 0, 0, 0)

    self:ApplyNameColor(entry)

    -- THE CLASS TINT RUNS ACROSS THIS CELL TOO. It is painted by Cell:SetValue
    -- for every stat column, and the name column was the one cell that never got
    -- it — so the tint began at the Damage column and the player column sat
    -- conspicuously undressed beside it. The background is the cell's own
    -- texture, not the bar, so this stays true of a cell whose bar is flattened
    -- to nothing (which this one always is).
    local br, bgc, bb, ba = cellBackground((self.window.config.bars or {}), entry, self.key)
    self.bg:SetColorTexture(br, bgc, bb, ba)

    -- A `Player-…` GUID is the only thing whose name can carry a realm. A pet, a
    -- follower-dungeon NPC, an enemy and a drill-down spell all keep every
    -- hyphen they came with.
    local isCharacter = entry.guid ~= nil and not entry.isDrillDown
        and Secrets.IsSafeKey(entry.guid)
        and tostring(entry.guid):match("^Player%-") ~= nil

    self.left:SetText(nameText(entry.name, self.window.config.text, isCharacter))
    self.right:SetText("")

    local icons = self.icons
    if not (icons and self.iconsShown) then return end
    if icons.unit then drawUnitIcon(icons.unit, entry) end
end
