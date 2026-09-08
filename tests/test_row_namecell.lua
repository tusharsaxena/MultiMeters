-- tests/test_row_namecell.lua — modules/Row_NameCell.lua: the one cell in the
-- row that never holds a figure.
--
-- Peeled from tests/test_row.lua along the seam modules/Row.lua was peeled on.
-- The name cell is the odd one out: every other cell in the row takes a meter
-- value, and this one takes a NAME. That difference is the whole subject here.
-- Because it holds no figure it stays OUT of the secret set — its geometry is
-- readable while a pull is restricted, which is why the icon and truncation
-- cases below can assert on widths at all. The one secret it does handle is the
-- name itself, and the rule there is the mirror of the number rule in
-- tests/test_row.lua: the handle goes to SetText untouched, because SetText is
-- a widget setter and not a log renderer.
--
-- What lives here: class colour on the name string, the spec/class icon slot
-- and the space it consumes, the realm strip and the character-counting cap,
-- and the fold arrow and drill-down hand-off that hang off the same cell. What
-- stays in tests/test_row.lua: the value cell, the shared colour/media/mouse
-- parts and the cell descriptor.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse

--- A window instance with a known column set, plus one row built off its pool.
---
--- The row is created through NS.Row.New rather than through a refresh so a case
--- can hand it any entry it likes, including shapes the aggregator would never
--- produce. Duplicated from tests/test_row.lua rather than published: it is
--- eighteen lines, and a fixture both suites can edit independently is worth
--- more than one they must agree about.
local function bench(configure)
    local inst = T.load()
    local NS = inst.NS

    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked = true
    cfg.columns = {
        { stat = "DamageDone", enabled = true },
        { stat = "Interrupts", enabled = true },
    }
    cfg.data.sortColumn = "DamageDone"
    if configure then configure(cfg) end

    local window = NS.Window.New(cfg)
    local row = NS.Row.New(window)
    row:ApplyLayout(window.layout)
    return inst, window, row, cfg
end

--- An aggregator-shaped entry.
local function entry(values, opts)
    opts = opts or {}
    return {
        guid          = opts.guid or "Player-1-0000000A",
        name          = opts.name or "Alpha",
        classFilename = opts.classFilename or "MAGE",
        specIconID    = opts.specIconID,
        role          = opts.role or "DAMAGER",
        isPlayer      = opts.isPlayer or false,
        isDrillDown   = opts.isDrillDown,
        icon          = opts.icon,
        maxAmount     = opts.maxAmount,
        values        = values,
        cells         = values,
    }
end

-- ---------------------------------------------------------------------------
-- The name cell
-- ---------------------------------------------------------------------------

test("The name cell is never handed a meter value at all", function()
    local inst, _, row = bench()
    inst.mocks.setRestricted(true)
    row:Update(entry{
        DamageDone = { total = inst.mocks.secret(60), maxAmount = inst.mocks.secret(100) },
        Interrupts = { total = 9,  maxAmount = 9 },
    }, 1)

    -- The name column used to draw a bar scaled to the sort column, which meant
    -- handing this frame a secret purely to size a rectangle. Dropping the bar
    -- takes the frame OUT of the secret set: its geometry stays readable, which
    -- is the taint half of the change and the half a screenshot cannot show.
    -- red under: restoring the SetValue(total) call in Cell:SetPlayer.
    local bar = row.nameCell.frame
    assertEqual(bar:GetValue(), 0, "the name cell holds no figure")
    assertEqual(bar:HasSecretValues(), false,
        "and is therefore not marked secret, unlike every stat cell beside it")

    -- The stat cell in the same row DID take one, which is what makes the
    -- assertion above a real distinction rather than an artifact of the fixture.
    assertEqual(row.cells.DamageDone.frame:HasSecretValues(), true)
end)

test("The name cell colors the NAME by class, now that no bar carries it", function()
    local inst, _, row = bench()
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { name = "Alpha", classFilename = "MAGE" }), 1)

    local r, g, b = row.nameCell.left:GetTextColor()
    local c = inst.mocks.RAID_CLASS_COLORS.MAGE
    assertEqual(r, c.r)
    assertEqual(g, c.g)
    assertEqual(b, c.b)
end)

test("An unknown class reads as white, not as a tenth palette entry", function()
    local _, _, row = bench()
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { name = "Whatsit", classFilename = "NOTACLASS" }), 1)

    local r, g, b = row.nameCell.left:GetTextColor()
    assertEqual(r, 1); assertEqual(g, 1); assertEqual(b, 1)
end)

test("The name cell renders a plain name and survives a secret one", function()
    local inst, _, row = bench()
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } }, { name = "Alpha" }), 1)
    assertEqual(row.nameCell.left:GetText(), "Alpha")

    -- ConditionalSecret: mid-pull the handle goes to the widget UNTOUCHED, and
    -- the client draws the real characters. SetText accepts a secret — the same
    -- permission modules/Format.lua relies on to put "12.4M" on a bar it may not
    -- divide — so the player sees the name, not a placeholder.
    --
    -- THE BUG THIS PINS: the opaque branch used to answer NS.SafeToString(name),
    -- so every row but the local player's read `<secret>` for the whole of a
    -- pull. That is the right answer for a LOG LINE, where the alternative is a
    -- raise inside string.format, and the wrong one for a widget.
    -- red under: returning the sentinel from nameText's opaque branch.
    inst.mocks.setRestricted(true)
    local handle = inst.mocks.secret("Alpha")
    row:Update(entry({ DamageDone = { total = inst.mocks.secret(1),
                                      maxAmount = inst.mocks.secret(1) } },
        { name = handle }), 1)

    local drawn = row.nameCell.left:GetText()
    assertTrue(drawn == handle, "the widget must get the handle itself, untouched")
    assertFalse(drawn == "<secret>", "the sentinel is a log renderer, never a name")
    assertEqual(inst.mocks.reveal(drawn), "Alpha", "and it is the right handle")
end)

-- ── realm strip and truncation ──────────────────────────────────────────────

test("A cross-realm PLAYER name loses its realm", function()
    local _, _, row = bench()
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { guid = "Player-1-0000000A", name = "Stabby-Aerie Peak" }), 1)
    assertEqual(row.nameCell.left:GetText(), "Stabby",
        "the realm is most of the column and never what anyone is scanning for")
end)

test("An NPC keeps the hyphen in its name", function()
    -- "Crenna Earth-Daughter" is a follower-dungeon companion, and the first
    -- build of the realm strip rendered her as "Crenna Earth". A hyphen is only
    -- a realm separator in a PLAYER's name; the row's GUID is what says which
    -- this is, and guessing from the string would be a heuristic about naming
    -- conventions we do not control.
    -- red under: stripping on the hyphen unconditionally.
    --
    -- The cap is raised for this case so it asserts ONE thing. At the shipped
    -- default of 20 this exact name is 21 characters and truncates, which is the
    -- cap working correctly and would mask whether the strip fired.
    local _, _, row = bench(function(c) c.text.maxNameLength = 0 end)
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { guid = "Creature-0-3766-2813-30763-209065-000078A00B",
          name = "Crenna Earth-Daughter" }), 1)
    assertEqual(row.nameCell.left:GetText(), "Crenna Earth-Daughter")
end)

test("A pet keeps its hyphen too", function()
    local _, _, row = bench()
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { guid = "Pet-0-1234-5-6-7-8", name = "Gore-Tusk" }), 1)
    assertEqual(row.nameCell.left:GetText(), "Gore-Tusk")
end)

test("The name never wraps, and gets a fixed width to be truncated against", function()
    -- A WRAPPED NAME IS DRAWN OUTSIDE ITS OWN ROW: the second line lands on the
    -- row below and the whole grid reads as shuffled. Two-point anchoring also
    -- let the string grow to whatever the frame became mid-resize, so the width
    -- the cap was measured against moved while the mouse did.
    -- red under: anchoring LEFT and RIGHT instead of setting a width.
    local _, window, row = bench()
    local cell = row.nameCell

    assertEqual(cell.left.__wordWrap, false, "a name must never reflow onto a second line")
    assertTrue(cell.left:GetWidth() > 0, "the name text needs a width of its own")
    assertTrue(cell.left:GetWidth() < window.layout.nameColumn.width,
        "and it must leave room for the icons beside it")
end)

test("The icon inset is the SAME for a row with no icons to draw", function()
    -- A follower NPC has no spec icon. The space is reserved from the CONFIGURED
    -- slots rather than from what the row managed to draw, so its name still
    -- starts where every other name starts — a column whose text begins at a
    -- different x per row is not a column.
    local _, _, row = bench(function(c)
        c.icons = c.icons or {}
        c.icons.showClass, c.icons.showSpec, c.icons.showRole = true, true, true
    end)

    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { name = "Withspec", classFilename = "MAGE", specIconID = 135846 }), 1)
    local withIcons = row.nameCell.left:GetWidth()

    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { name = "Nospec" }), 2)
    assertEqual(row.nameCell.left:GetWidth(), withIcons,
        "the inset is the column's, not the row's")
end)

test("A layout pass keeps the class color instead of flashing white", function()
    -- THE RESIZE FLICKER. Cell:ApplyTextStyle repaints every slot in the
    -- window's text color, and it runs on every layout pass — which during a
    -- drag-resize is every frame. The class color was only restored by the next
    -- Cell:SetPlayer, up to a throttle interval later, so names flashed white for
    -- as long as the mouse was moving.
    -- red under: ApplyTextStyle ending at SetShadowOffset.
    local _, window, row = bench()
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { name = "Priesty", classFilename = "PRIEST" }), 1)

    local before = { row.nameCell.left:GetTextColor() }

    -- What a resize does, repeatedly, with no refresh in between.
    row:ApplyLayout(window.layout)

    local after = { row.nameCell.left:GetTextColor() }
    for i = 1, 3 do
        assertEqual(after[i], before[i],
            "the name lost its class color on a layout pass (component " .. i .. ")")
    end
    assertFalse(after[1] == 1 and after[2] == 1 and after[3] == 1,
        "the fixture must use a class whose color is not white")
end)

test("A name past the cap is truncated with NO ellipsis", function()
    -- The column is narrow and the cap is small, so a glyph spent saying "there
    -- was more" is a glyph not spent on the name. The cut is the whole signal.
    -- red under: appending U+2026 to the truncated string.
    local _, window, row = bench(function(c) c.text.maxNameLength = 8 end)
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { name = "Meredy Huntswell" }), 1)
    assertEqual(row.nameCell.left:GetText(), "Meredy H")
    assertEqual(window.config.text.maxNameLength, 8)
end)

test("Truncation counts CHARACTERS, never bytes", function()
    -- "Helyâ" is 6 bytes and 5 characters. A byte slice at 5 lands inside the â
    -- and emits half a code point, which renders as a replacement box — and the
    -- names most likely to need truncating are exactly the accented ones.
    -- red under: `out:sub(1, cap)`.
    local _, _, row = bench(function(c) c.text.maxNameLength = 5 end)
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { name = "Hely\195\162nder" }), 1)
    assertEqual(row.nameCell.left:GetText(), "Hely\195\162")
end)

test("A cap of 0 means no cap", function()
    local _, _, row = bench(function(c) c.text.maxNameLength = 0 end)
    local long = "Averyveryverylongnpcnamethatkeepsgoing"
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } }, { name = long }), 1)
    assertEqual(row.nameCell.left:GetText(), long)
end)

test("Neither the realm strip nor the cap is applied to a SECRET name", function()
    -- string.match and string.sub READ the characters of a value, and performing
    -- either on a secret is exactly what rule R1 forbids. A name we may not read
    -- goes to the widget untouched.
    -- red under: stripping before the IsConcatSafe probe.
    local inst, _, row = bench(function(c) c.text.maxNameLength = 4 end)
    inst.mocks.setRestricted(true)
    local ok = pcall(row.Update, row, entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { name = inst.mocks.secret("Stabby-Aerie Peak") }), 1)
    assertTrue(ok, "inspecting a secret name raised")
end)

test("A drill-down row keeps a hyphen, which is part of a spell name", function()
    -- The realm strip is anchored to the first hyphen. On a spell that is not a
    -- separator, and stripping there would silently shorten it to its first word.
    -- No cap, because this name is longer than the shipped one and the case is
    -- about the hyphen rather than about the truncation three cases above.
    local _, _, row = bench(function(c) c.text.maxNameLength = 0 end)
    local spell = { guid = "s1", name = "Fire-and-Brimstone", isDrillDown = true,
                    classFilename = "WARLOCK", role = "NONE",
                    values = { DamageDone = { total = 1, maxAmount = 1 } } }
    spell.cells = spell.values
    row:Update(spell, 1)
    assertEqual(row.nameCell.left:GetText(), "Fire-and-Brimstone")
end)

test("A nil name renders empty rather than the string 'nil'", function()
    local _, _, row = bench()
    -- Built by hand rather than through `entry()`, which defaults the name: the
    -- case is about a row that genuinely has none.
    local blank = { guid = "g", classFilename = "MAGE", role = "NONE",
                    values = { DamageDone = { total = 1, maxAmount = 1 } } }
    blank.cells = blank.values
    row:Update(blank, 1)
    assertEqual(row.nameCell.left:GetText(), "")
end)

test("The single icon slot prefers the SPEC where there is one", function()
    -- Spec over class because "which unit is this row" is the question the icon
    -- answers, and a spec separates the three druids in a raid where a class
    -- icon cannot.
    -- red under: drawing the class icon whenever classFilename is present.
    local _, window, row = bench()
    row:ApplyLayout(window.layout)

    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { classFilename = "MAGE", specIconID = 135771, role = "TANK" }), 1)

    local icons = row.nameCell.icons
    assertEqual(icons.unit:IsShown(), true, "the one slot drew nothing")
    assertEqual(icons.unit:GetTexture(), 135771, "specIconID is a file ID and NeverSecret")
end)

test("The slot falls back to the CLASS where no spec is known", function()
    -- An NPC, a pet, a player the unit API has not resolved. A class icon is
    -- still an answer where a spec is not available.
    -- red under: hiding the icon when specIconID is nil.
    local inst, window, row = bench()
    row:ApplyLayout(window.layout)

    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { classFilename = "MAGE", specIconID = nil, role = "TANK" }), 1)

    local icons = row.nameCell.icons
    assertEqual(icons.unit:IsShown(), true, "a row with a class but no spec drew nothing")
    local c = inst.mocks.CLASS_ICON_TCOORDS.MAGE
    assertEqual(select(1, icons.unit:GetTexCoord()), c[1], "the fallback is not the class icon")
end)

test("A ROLE icon is never drawn, whatever the row carries", function()
    -- Three roles across a whole raid identifies nobody, and it was the icon
    -- most likely to be on screen when the name column ran out of room.
    -- red under: any surviving role branch.
    local _, window, row = bench()
    row:ApplyLayout(window.layout)

    -- Built directly rather than through `entry`, which defaults a class in —
    -- and a row WITH a class would legitimately draw the class icon, so the
    -- fixture has to have neither for the assertion to mean anything.
    row:Update({ guid = "Creature-0-1", name = "Some Add", role = "TANK",
                 maxAmount = 1, values = { DamageDone = { total = 1, maxAmount = 1 } },
                 cells = { DamageDone = { total = 1, maxAmount = 1 } } }, 1)

    local icons = row.nameCell.icons
    assertEqual(icons.role, nil, "a role slot still exists")
    assertEqual(icons.unit:IsShown(), false,
        "a row with only a role drew an icon, so the role ladder survived")
end)

test("A breakdown row draws the SPELL's icon, not a unit's", function()
    -- The rung that is first because the row is not a unit at all: it has no
    -- class, no spec and no role, and its `icon` is the spell's own file id.
    -- This branch lived inside the old class drawer and would have been deleted
    -- with it.
    -- red under: dropping the isDrillDown branch from drawUnitIcon.
    local _, window, row = bench()
    row:ApplyLayout(window.layout)

    row:Update({ guid = "spell:101", name = "Fireball", isDrillDown = true,
                 icon = 135808, classFilename = "MAGE", specIconID = 135771,
                 maxAmount = 1, values = { DamageDone = { total = 1 } } }, 1)

    assertEqual(row.nameCell.icons.unit:GetTexture(), 135808,
        "a breakdown row drew a unit icon instead of its spell's")
end)

test("Turning the icon off hides it rather than destroying it", function()
    -- The pool's whole premise is that widget creation happens once.
    -- red under: rebuilding the icon set on a config change.
    local _, window, row, cfg = bench()
    row:ApplyLayout(window.layout)
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { classFilename = "MAGE", specIconID = 135771 }), 1)
    assertEqual(row.nameCell.icons.unit:IsShown(), true)

    cfg.icons.showIcon = false
    row:ApplyLayout(window.layout)
    assertEqual(row.nameCell.icons.unit:IsShown(), false,
        "an icon turned off is hidden, not destroyed")
end)

test("An icon turned off STAYS off across the next refresh", function()
    -- THE BUG: the name text moved left with the setting and the picture came
    -- straight back on the next row drawn. ApplyIcons hid the texture; SetPlayer
    -- then drew into whatever texture it found and showed it again, because the
    -- pool keeps the widget and the config was never re-consulted.
    -- red under: SetPlayer drawing without asking whether the slot is wanted.
    local _, window, row, cfg = bench()
    cfg.icons.showIcon = false
    row:ApplyLayout(window.layout)

    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { classFilename = "MAGE", specIconID = 135771 }), 1)
    assertEqual(row.nameCell.icons.unit:IsShown(), false,
        "the icon came back on the first row drawn after it was turned off")

    -- And turning it back on brings it back, on the next row and not a reload
    -- later.
    cfg.icons.showIcon = true
    row:ApplyLayout(window.layout)
    row:Update(entry({ DamageDone = { total = 1, maxAmount = 1 } },
        { classFilename = "MAGE", specIconID = 135771 }), 1)
    assertEqual(row.nameCell.icons.unit:IsShown(), true)
end)

test("The name starts clear of the icon, with a gap you can see", function()
    -- The stride was the icon size plus ONE pixel, which reads as the two
    -- touching at any icon size a player would actually pick.
    -- red under: folding the gap back to 1.
    local inst, window, row, cfg = bench(function(c) c.icons.showIcon = true end)
    row:ApplyLayout(window.layout)

    local gap = inst.NS.ICON_TEXT_GAP
    assertTrue(gap >= 3, "a gap under three pixels is not a gap")

    local left = row.nameCell.left
    local _, _, _, xOfs = left:GetPoint(1)
    assertEqual(xOfs, 2 + (cfg.icons.size or 14) + gap,
        "the name does not start clear of the icon plus its gap")
end)

test("Icons on the RIGHT anchor to the right edge and give the name the left one", function()
    -- THE OTHER ARM, and it is two decisions rather than one: the icon changes
    -- corner AND the name stops being inset, because the space the icon consumes
    -- is now on the far side of the string. Get one without the other and the
    -- name either overlaps the icon or starts a stride further in than it needs
    -- to. Nothing else in this suite sets `icons.position`.
    -- red under: folding the two branches into one signed offset and losing the
    -- name's own anchor with them.
    local inst, window, row, cfg = bench(function(c)
        c.icons.showIcon = true
        c.icons.position = "RIGHT"
    end)
    local cell = row.nameCell
    local size = cfg.icons.size or 14
    local gap  = inst.NS.ICON_TEXT_GAP

    local point, relativeTo, relativePoint, x = cell.icons.unit:GetPoint(1)
    assertEqual(point, "TOPRIGHT", "the icon stayed on the left")
    assertTrue(relativeTo == cell.frame)
    assertEqual(relativePoint, "TOPRIGHT")
    assertEqual(x, -2, "the first slot sits two pixels in from the edge it is anchored to")

    local lPoint, _, _, lx = cell.left:GetPoint(1)
    assertEqual(lPoint, "LEFT")
    assertEqual(lx, 2, "the name is still inset for an icon that is no longer beside it")

    -- The RESERVED WIDTH does not change with the side: the column gives up the
    -- same space either way, so a player toggling the position does not watch
    -- every name in the grid grow and shrink.
    assertEqual(cell.left:GetWidth(), window.layout.nameColumn.width - (2 + size + gap) - 2,
        "the right-hand layout reserved a different amount of room")
end)

test("The icon takes its configured size and is centred in the row", function()
    -- The vertical centring is `(rowHeight - size) * -0.5`, which is the only
    -- arithmetic in this function -- and an icon larger than the shipped 14 is
    -- exactly when getting it wrong shows, because half of it hangs into the row
    -- above. The stride the name is pushed by is the SAME size plus the gap.
    -- red under: a constant y, or a centring that forgets the sign.
    local inst, window, row = bench(function(c)
        c.icons.showIcon = true
        c.icons.size     = 20
    end)
    local cell = row.nameCell
    local gap  = inst.NS.ICON_TEXT_GAP
    local tex  = cell.icons.unit

    assertEqual(tex:GetWidth(), 20, "the size setting did not reach the texture")
    assertEqual(tex:GetHeight(), 20)

    local _, _, _, x, y = tex:GetPoint(1)
    assertEqual(x, 2)
    assertEqual(y, (window.layout.rowHeight - 20) * -0.5, "the icon is not centred on the row")

    local _, _, _, lx = cell.left:GetPoint(1)
    assertEqual(lx, 2 + 20 + gap, "the name did not move with the bigger icon")
    assertEqual(cell.left:GetHeight(), window.layout.rowHeight,
        "the name string does not fill the row it sits in")
end)

test("ApplyIcons returns the inset it consumed, and never zero", function()
    -- The RETURN VALUE is the contract with the name string, and the no-icon
    -- answer is TWO, not nothing: a name hard against the left edge of the
    -- column reads as touching the window frame. The caller in RowProto:ApplyLayout
    -- discards it today, which is exactly why a refactor could drop it unnoticed.
    -- red under: returning 0 when the slot list is empty.
    local inst, window, row, cfg = bench(function(c) c.icons.showIcon = true end)
    local size = cfg.icons.size or 14
    local gap  = inst.NS.ICON_TEXT_GAP

    assertEqual(row.nameCell:ApplyIcons(window.layout), 2 + size + gap)

    cfg.icons.showIcon = false
    assertEqual(row.nameCell:ApplyIcons(window.layout), 2,
        "a column with no icons still keeps the name off the edge")
end)

test("The slot list and the drawn flag are what SetPlayer reads", function()
    -- `iconOrder` and `iconsShown` are this function's OUTPUT, read by the row
    -- draw a moment later: SetPlayer draws into whatever texture it finds and
    -- would otherwise show an icon this pass has just hidden. They are the two
    -- fields most likely to be renamed or dropped by a split, and neither is
    -- asserted anywhere else.
    -- red under: setting `iconsShown` from `icons.showIcon` rather than from the
    -- slot list that was actually laid out.
    local _, window, row, cfg = bench(function(c) c.icons.showIcon = true end)
    local cell = row.nameCell

    assertEqual(cell.iconsShown, true)
    assertEqual(#cell.iconOrder, 1, "one slot, not three")
    assertEqual(cell.iconOrder[1], "unit")

    cfg.icons.showIcon = false
    row.nameCell:ApplyIcons(window.layout)
    assertEqual(cell.iconsShown, false)
    assertEqual(#cell.iconOrder, 0, "the slot list outlived the setting")
end)

test("A narrow name column still leaves the string a width of at least one", function()
    -- SetWidth(0) is a FontString that renders nothing, and a negative width is
    -- worse -- the column can genuinely be narrower than the icon plus its
    -- insets while a player drags the window's edge in. The floor is what keeps
    -- a name visible through the drag.
    -- red under: trusting `column.width - consumed - 2`.
    local _, window, row = bench()

    row.nameCell:ApplyIcons({ rowHeight = window.layout.rowHeight, nameColumn = { width = 4 } })
    assertEqual(row.nameCell.left:GetWidth(), 1, "the name string was given no width at all")

    -- And a layout with no name column at all is a shape this must survive
    -- rather than raise on: `layout.nameColumn or {}` is the guard.
    row.nameCell:ApplyIcons({ rowHeight = window.layout.rowHeight })
    assertEqual(row.nameCell.left:GetWidth(), 1)
end)

test("A window config with no icons group at all draws a name and does not raise", function()
    -- The `or {}` guards. A profile written before the icon group existed reaches
    -- here with `config.icons` nil, and a name column that raises takes the whole
    -- row draw with it -- every number in the grid, for a missing decoration.
    -- red under: reading `config.icons.showIcon` directly.
    local _, window, row, cfg = bench()
    cfg.icons = nil

    local consumed = row.nameCell:ApplyIcons(window.layout)
    assertEqual(consumed, 2, "an absent icon group asked for icon-sized space")
    assertTrue(row.nameCell.left:GetWidth() > 0)
end)

test("Re-laying the icons out does not stack anchors on the texture or the name", function()
    -- ClearAllPoints on both, and for the reason the border has it: a layout pass
    -- runs on every frame of a drag-resize, and anchors that accumulate resolve
    -- against each other so the first pass wins forever.
    -- red under: dropping either ClearAllPoints while moving the placement into a
    -- helper.
    local _, window, row = bench(function(c) c.icons.showIcon = true end)
    local cell = row.nameCell

    row.nameCell:ApplyIcons(window.layout)
    row.nameCell:ApplyIcons(window.layout)

    assertEqual(cell.icons.unit:GetNumPoints(), 1, "the icon accumulated anchors")
    assertEqual(cell.left:GetNumPoints(), 1, "the name string accumulated anchors")
end)
