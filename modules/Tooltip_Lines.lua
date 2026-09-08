-- modules/Tooltip_Lines.lua
--
-- ONE POOLED LINE, as a widget. The carrier frame and its bar, the text
-- measurement the widths rest on, the slot layout, the resolved style, and the
-- draw itself -- plus the four death helpers that decide what a death line's
-- label says before anything is drawn.
--
-- WHY IT IS A SEPARATE FILE. modules/Tooltip.lua went past layout-§1's 1500-line
-- cap (issue #28) and this is the middle third of it, moved across unchanged. It
-- is a sibling rather than a new module because it is not a new surface: it hangs
-- `Tooltip.WidthParts` on the SAME module table modules/Tooltip.lua builds, and
-- everything else here is private to the three files of the peel.
--
-- THE SECRETS RULE STILL BINDS EVERY LINE. It is written out once, in
-- modules/Tooltip.lua's header, and it is not weaker on this side of the seam:
-- no amount is added, subtracted, divided or compared here either; amounts reach
-- the screen through string.format or the number formatter; booleans off the API
-- go through `plainTruth`. Read that header before changing anything below.
--
-- TOC POSITION: modules/, immediately after modules\Tooltip.lua. LOAD-BEARING:
-- every name in the block below is resolved at FILE SCOPE off
-- `NS.TooltipInternals`, so a position before that file would freeze in a table
-- of nils for the life of the session.

local _, NS = ...

local Tooltip = NS.Tooltip
local L = NS.L
local Compat = NS.Compat

-- The primitives modules/Tooltip.lua publishes for this file. FILE SCOPE, which
-- is what makes this file's TOC position load-bearing.
local I = NS.TooltipInternals
local FALLBACK_ICON = I.FALLBACK_ICON
local TOOLTIP_ICON_SIZE = I.TOOLTIP_ICON_SIZE
local formatNumber = I.formatNumber
local formatShare = I.formatShare
local plainWord = I.plainWord
local plainTruth = I.plainTruth
local tooltipConfig = I.tooltipConfig
local mediaPath = I.mediaPath
local tooltipFont = I.tooltipFont
local rgba = I.rgba
local BAR_HEIGHT = I.BAR_HEIGHT
local BAR_FALLBACK_TEXTURE = I.BAR_FALLBACK_TEXTURE
local BAR_INSET_LEFT = I.BAR_INSET_LEFT
local SLOT_RIGHT_PAD = I.SLOT_RIGHT_PAD
local SHARE_SLOT_WIDTH = I.SHARE_SLOT_WIDTH
local SLOT_GAP = I.SLOT_GAP
local AMOUNT_SLOT_WIDTH = I.AMOUNT_SLOT_WIDTH
local SHARE_WIDEST = I.SHARE_WIDEST
local LABEL_INSET_LEFT = I.LABEL_INSET_LEFT
local NAME_COLUMN_CHARS = I.NAME_COLUMN_CHARS
local EVENT_SPELL_CHARS = I.EVENT_SPELL_CHARS
local EVENT_CASTER_CHARS = I.EVENT_CASTER_CHARS
local EVENT_TIME_WIDEST = I.EVENT_TIME_WIDEST
local DEATH_DETAIL_SEP = I.DEATH_DETAIL_SEP
local DEATH_CLOCK_WIDEST = I.DEATH_CLOCK_WIDEST
local NAME_WIDTH_PER_CHAR = I.NAME_WIDTH_PER_CHAR
local NAME_GAP = I.NAME_GAP
local TOOLTIP_H_PADDING = I.TOOLTIP_H_PADDING
local SLOT_COLOR_DEFAULT = I.SLOT_COLOR_DEFAULT
local linePool = I.linePool
local applyLineFont = I.applyLineFont
local ensureTooltipHook = I.ensureTooltipHook

--- The nth pooled line's carrier frame, created on first use. Its bar and its two
--- number slots hang off it under `.bar`, `.amount` and `.share`.
local function lineWidget(index)
    local line = linePool[index]
    if line then return line end
    -- First line of the session is also the moment the pool starts needing the
    -- OnHide hook, and the earliest point in this file that can install it.
    ensureTooltipHook()

    -- BackdropTemplate for the optional LSM border. Asked for at CREATION, since
    -- a template cannot be added to a frame afterwards — so a player who turns
    -- the border on mid-session gets it on lines that were pooled before they
    -- did. Nothing is read back off the backdrop; it is set and forgotten, which
    -- is what keeps it clear of rule R3.
    local frame = CreateFrame("Frame", nil, GameTooltip, "BackdropTemplate")
    frame:SetHeight(BAR_HEIGHT)
    -- The tooltip's own level, NOT one above it: see the layering note above.
    frame:SetFrameLevel(GameTooltip:GetFrameLevel())

    -- BackdropTemplate on the BAR as well as on the carrier: the border is drawn
    -- on the bar (see applyLineBorder), and a template cannot be added to a frame
    -- after it exists.
    local b = CreateFrame("StatusBar", nil, frame, "BackdropTemplate")
    b:SetAllPoints(frame)
    b:SetFrameLevel(frame:GetFrameLevel())
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetColorTexture(0, 0, 0, 0.35)
    b.bg = bg

    -- Right to left: the share is pinned to the line's right edge, and the amount
    -- to the share's left edge. Both are right-justified inside a fixed width, so
    -- both columns line up down the tooltip whatever the numbers are.
    local share = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    share:SetWidth(SHARE_SLOT_WIDTH)
    share:SetJustifyH("RIGHT")
    share:SetPoint("RIGHT", frame, "RIGHT", -SLOT_RIGHT_PAD, 0)


    -- The LABEL slot, used by target lines and left empty by spell lines.
    --
    -- A target has no icon — a unit is not a spell — but its name still has to
    -- start where a spell NAME starts, not where a spell ICON starts, or the two
    -- sections read as two different tables. There is no way to indent
    -- GameTooltip's own line text (a `|T…|t` spacer needs a transparent texture
    -- to point at, and padding with spaces is font-dependent), so the name goes
    -- on OUR carrier instead — which is already anchored past the icon, wears the
    -- configured font for free, and can be placed to the pixel.
    --
    -- Bounded on the right by the amount slot so a long unit name is clipped
    -- rather than drawn underneath the numbers.
    local label = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", frame, "LEFT", LABEL_INSET_LEFT, 0)

    local amount = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    amount:SetWidth(AMOUNT_SLOT_WIDTH)
    amount:SetJustifyH("RIGHT")
    amount:SetPoint("RIGHT", share, "LEFT", -SLOT_GAP, 0)


    -- Keyed onto the carrier the way Blizzard's own `parentKey` does, so the
    -- pool holds one object rather than a record of four.
    label:SetPoint("RIGHT", amount, "LEFT", -SLOT_GAP, 0)

    -- TWO MORE SLOTS, USED ONLY BY THE DEATH BRANCH. They are created for every
    -- carrier rather than lazily because the pool never destroys one: a carrier
    -- that grew slots on its first event line would be a different object from
    -- one that had only ever drawn spells, and the layout below would have to
    -- test for that on every draw.
    --
    -- Their placement and width are stated per draw, in `applySlotLayout`, and
    -- NOT here — the carrier drawing line 4 of this hover drew line 4 of the
    -- last one, so anything set once at creation is a stale value waiting to
    -- happen.
    local time = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    time:SetJustifyH("RIGHT")
    if time.SetWordWrap then time:SetWordWrap(false) end

    local caster = frame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    caster:SetJustifyH("LEFT")
    if caster.SetWordWrap then caster:SetWordWrap(false) end
    if label.SetWordWrap then label:SetWordWrap(false) end

    frame.bar, frame.amount, frame.share, frame.label = b, amount, share, label
    frame.time, frame.caster = time, caster
    linePool[index] = frame
    return frame
end


--- A hidden FontString kept solely to measure text, OUTSIDE GameTooltip.
---
--- IT ONLY EVER SEES A CONSTANT OF OURS. An earlier version measured the spell
--- captions on it, which is what the note on `applyMinimumWidth` describes as
--- having failed: a caption can be secret, and a secret measured is a secret
--- back. Everything it is given now is a literal in this file, so the width it
--- answers is an ordinary number and rule R3 is not in play — the ruler is
--- parentless, never placed inside the tooltip, and has never been handed a
--- meter value.
local ruler = nil

--- The width of one PLAIN string at one font, or nil if unmeasurable.
---
--- @param text string  a literal of ours — never a caption, never a meter value
local function measureText(text, path, size, flags)
    if not ruler then
        local host = CreateFrame("Frame")
        host:Hide()
        ruler = host:CreateFontString(nil, "OVERLAY")
    end
    if not ruler.SetFont then return nil end
    ruler:SetFont(path, size, flags)
    ruler:SetText(text)
    local ok, w = pcall(ruler.GetStringWidth, ruler)
    if not ok or type(w) ~= "number" then return nil end
    return w
end

--- The width of N characters at one font, for a reserved column.
local function charSpan(chars, path, size, flags)
    return measureText(string.rep("n", chars), path, size, flags)
        or (chars * size * NAME_WIDTH_PER_CHAR)
end

--- Place the carrier's text slots for the kind of line about to be drawn.
---
--- STATED ON EVERY DRAW, BOTH WAYS. The pool keys a carrier by tooltip line
--- index, so the frame drawing line 4 of this hover is the one that drew line 4
--- of the last one — and an event line narrows the name column and shows two
--- extra slots. A spell line that inherited either would render its name into a
--- 22-character box with a stray time beside it.
---
--- @param frame table   a pooled carrier
--- @param style table
--- @param mode string|nil  nil for an ordinary line, "event" for a recap event,
---   "clock" for a death in a Deaths cell's list
local function applySlotLayout(frame, style, mode)
    local path, size, flags = style.fontPath, style.fontSize, style.fontFlags
    local label = frame.label

    label:ClearAllPoints()
    frame.share:ClearAllPoints()
    frame.share:Show()
    frame.share:SetPoint("RIGHT", frame, "RIGHT", -SLOT_RIGHT_PAD, 0)
    frame.amount:ClearAllPoints()
    frame.amount:SetPoint("RIGHT", frame.share, "LEFT", -SLOT_GAP, 0)
    frame.amount:SetWidth(AMOUNT_SLOT_WIDTH)

    if mode == "clock" then
        -- ONE FIGURE, AT THE RIGHT EDGE. A death has no share, and leaving the
        -- empty share slot in place held the time a whole column short of the
        -- bar's edge while every other tooltip's rightmost figure sits against
        -- it. So the share comes down and the amount takes its place.
        frame.time:Hide()
        frame.caster:Hide()
        frame.share:Hide()
        frame.amount:ClearAllPoints()
        frame.amount:SetPoint("RIGHT", frame, "RIGHT", -SLOT_RIGHT_PAD, 0)
        frame.amount:SetWidth((measureText(DEATH_CLOCK_WIDEST, path, size, flags)
            or AMOUNT_SLOT_WIDTH) + SLOT_RIGHT_PAD)
        label:SetWidth(0)
        label:SetPoint("LEFT", frame, "LEFT", LABEL_INSET_LEFT, 0)
        label:SetPoint("RIGHT", frame.amount, "LEFT", -SLOT_GAP, 0)
        return
    end

    if mode ~= "event" then
        frame.time:Hide()
        frame.caster:Hide()
        -- Width from its two anchors, as it has always been: the name column of
        -- a spell line runs from the icon to the amount slot.
        label:SetWidth(0)
        label:SetPoint("LEFT", frame, "LEFT", LABEL_INSET_LEFT, 0)
        label:SetPoint("RIGHT", frame.amount, "LEFT", -SLOT_GAP, 0)
        return
    end

    -- Measured from this recap's own longest time where one was worked out,
    -- with the constant as a floor. Sized to a constant it carried a character
    -- of slack down its left edge on every list whose longest was shorter.
    local timeWidth = (style.eventTimeWidth
        or measureText(EVENT_TIME_WIDEST, path, size, flags) or 0) + SLOT_RIGHT_PAD

    frame.time:Show()
    frame.time:SetFont(path, size, flags)
    frame.time:SetWidth(timeWidth)
    frame.time:ClearAllPoints()
    -- The same inset the share slot keeps on the right, so the row's two edges
    -- are symmetrical.
    frame.time:SetPoint("LEFT", frame, "LEFT", SLOT_RIGHT_PAD, 0)

    -- MEASURED WHERE THAT IS LEGAL, RESERVED WHERE IT IS NOT. `style.eventSpellWidth`
    -- is set only when every caption in this recap could be read, which out of
    -- combat is all of them — and out of combat is when a death recap is read.
    -- Mid-pull the captions are secret, the measurement is refused, and the
    -- column falls back to the character reservation it always had.
    label:SetWidth(style.eventSpellWidth or charSpan(EVENT_SPELL_CHARS, path, size, flags))
    label:SetPoint("LEFT", frame.time, "RIGHT", SLOT_GAP, 0)

    frame.caster:Show()
    frame.caster:SetFont(path, size, flags)
    frame.caster:SetWidth(style.eventCasterWidth
        or charSpan(EVENT_CASTER_CHARS, path, size, flags))
    frame.caster:ClearAllPoints()
    frame.caster:SetPoint("LEFT", label, "RIGHT", SLOT_GAP, 0)
end

--- The width of `NAME_COLUMN_CHARS` characters at one font.
---
--- 'n' is the reference glyph on purpose: it is the classic average-width letter
--- (the "en"), so 25 of them approximate 25 characters of a real name far better
--- than 25 of a wide 'W' or a narrow 'i' would.
local function measureNameSpan(path, size, flags)
    return measureText(string.rep("n", NAME_COLUMN_CHARS), path, size, flags)
        or (NAME_COLUMN_CHARS * size * NAME_WIDTH_PER_CHAR)
end

--- How wide the share slot must be at one font to hold a full "100.0%".
---
--- Measured rather than assumed, for the reason on SHARE_SLOT_WIDTH: the share
--- is six glyphs at its widest, not five, and the font size is the player's to
--- choose. The constant is the floor, so this never makes the slot narrower than
--- it has always been.
local function shareSlotWidth(path, size, flags)
    local w = measureText(SHARE_WIDEST, path, size, flags)
    if not w then return SHARE_SLOT_WIDTH end
    w = w + SLOT_RIGHT_PAD
    return (w > SHARE_SLOT_WIDTH) and w or SHARE_SLOT_WIDTH
end

--- The terms the minimum width is built from, for `/mm debug diag`.
---
--- Split out so the diagnostic reports the SAME arithmetic the tooltip runs
--- rather than a restatement of it that can drift. Every term comes from config
--- or from the ruler, so this is safe to call outside a hover — and it reads no
--- widget that has ever held a meter value.
---
--- @param style table|nil  a resolved style; nil resolves the configured tooltip
---   font instead, which is what the diagnostic has — it runs outside a hover
---   and so has no style in hand.
--- @return table
function Tooltip.WidthParts(style)
    local path, size, flags
    if style then
        path, size, flags = style.fontPath, style.fontSize, style.fontFlags
    else
        path, size, flags = tooltipFont(tooltipConfig(nil))
    end
    if type(size) ~= "number" or size < 1 then size = 12 end

    local nameSpan = measureNameSpan(path, size, flags)
    local share    = shareSlotWidth(path, size, flags)

    return {
        chars    = NAME_COLUMN_CHARS,
        nameSpan = nameSpan,
        nameGap  = NAME_GAP,
        amount   = AMOUNT_SLOT_WIDTH,
        slotGap  = SLOT_GAP,
        share    = share,
        padding  = TOOLTIP_H_PADDING,
        total    = nameSpan + NAME_GAP + AMOUNT_SLOT_WIDTH + SLOT_GAP
            + share + TOOLTIP_H_PADDING,
    }
end

--- Widen the tooltip enough that the two number slots never sit on a spell name.
---
--- GameTooltip sizes itself from its own text, and our numbers are not its text
--- any more — so without this the tooltip shrinks to the width of the names and
--- the slots overlap them. A MINIMUM is exactly the right instrument: a longer
--- header line still wins, and nothing here shrinks the tooltip.
---
--- THE NAME SPAN IS FIXED, AND IT HAS TO BE. Two earlier versions sized it from
--- the names themselves — first by reading GameTooltip's own FontStrings, then
--- by measuring the captions on a ruler of our own — and both failed in combat
--- for the same reason, which took instrumenting the live client to see: a spell
--- breakdown's captions are SECRET mid-pull. `C_DamageMeter` hands out a secret
--- `spellID`, so the name the client resolves from it is secret too. It RENDERS
--- — `SetText` is a widget setter and takes a secret happily, which is why the
--- tooltip shows "Chain Lightning" while this code cannot tell that it does —
--- but it cannot be measured, because taking the widest of several measurements
--- is a comparison and rule R3 forbids comparing a secret. There is no
--- arrangement of a ruler that escapes that: secret in, secret out.
---
--- So the span is a reservation rather than a measurement — `NAME_COLUMN_CHARS`
--- characters at the configured font, the same in combat and out. Nothing here
--- clips a longer name: the result is a FLOOR, and GameTooltip still grows past
--- it for its own longer text.
---
--- @param style table  a resolved style from `lineStyle`, for its font
local function applyMinimumWidth(style)
    if not (_G.GameTooltip and GameTooltip.SetMinimumWidth) then return end
    GameTooltip:SetMinimumWidth(Tooltip.WidthParts(style).total)
end

--- The same floor, plus the death tooltip's two extra columns.
---
--- A death line carries a time and a caster that a spell line does not, and they
--- have to be paid for or they overlap the numbers. Reserved from the font like
--- everything else here — see the note on applyMinimumWidth for why none of it
--- may be measured off the names themselves.
local function applyDeathMinimumWidth(style)
    if not (_G.GameTooltip and GameTooltip.SetMinimumWidth) then return end
    local path, size, flags = style.fontPath, style.fontSize, style.fontFlags
    local extra = (measureText(EVENT_TIME_WIDEST, path, size, flags) or 0)
        + SLOT_RIGHT_PAD + SLOT_GAP
        + charSpan(EVENT_CASTER_CHARS, path, size, flags) + SLOT_GAP
    GameTooltip:SetMinimumWidth(Tooltip.WidthParts(style).total + extra)
end

--- Everything a line needs to draw itself, resolved ONCE per hover.
---
--- Resolved once rather than per line because every one of these is an LSM fetch
--- or a config walk and a breakdown may be sixty-four lines deep — and because a
--- style that could differ between two lines of one tooltip would be a bug with
--- no way to see it.
---
--- @param config table      the resolved tooltip config
--- @param color table|nil   the hovered player's class color, or nil
--- @return table
--- Resolve one of the tooltip's three colour modes onto a starting colour.
---
--- ONE READER FOR THE THREE SURFACES a tooltip line draws -- its text, its fill
--- and its backdrop -- because they are one question asked three times, and three
--- private answers is how a tooltip ends up with a class-coloured bar behind
--- stat-coloured writing for no reason a player can discover.
---
--- CLASS IS THE HOVERED PLAYER'S: `color` is that same table, resolved by the
--- caller off `row.classFilename`. A tooltip is about ONE player, which is what
--- makes the question answerable here where the window header has to fall back to
--- the local player's class instead.
---
--- STAT IS THE WINDOW'S SORT COLUMN, the statistic the grid being hovered is
--- ranked by. A tooltip lists several statistics at once and is not "about" any
--- one of them, so per-column would have no meaning here; the sort column is the
--- same answer the title bar gives (modules/Window.lua's surfaceColor).
---
--- With nothing to read either way the passed-in colour stands, which is the
--- configured one at every call site.
local function modeColor(mode, statKey, classColor, r, g, b)
    if mode == "class" then
        if classColor then return classColor.r, classColor.g, classColor.b end
    elseif mode == "stat" then
        -- Resolved to a local first: `f and f(x)` truncates to one value and this
        -- reader answers three.
        local StatColor = NS.StatColor
        if StatColor then
            local sr, sg, sb = StatColor(statKey)
            if sr then return sr, sg, sb end
        end
    end
    return r, g, b
end

--- An opacity that is safe to hand to a widget: a real number in 0..1, with the
--- shipped value standing in for anything else. A saved profile carrying a string
--- here would raise inside the setter.
local function alphaOf(v, fallback)
    if type(v) ~= "number" then return fallback end
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function lineStyle(config, color)
    local path, size, flags = tooltipFont(config)
    local borderSize = config.barBorderSize
    if type(borderSize) ~= "number" or borderSize < 0 then borderSize = 0 end

    local tr, tg, tb = rgba(config.textColor,
        SLOT_COLOR_DEFAULT[1], SLOT_COLOR_DEFAULT[2], SLOT_COLOR_DEFAULT[3], 1)

    -- CLASS IS THE HOVERED PLAYER'S, which the bars already wear -- `color` is
    -- that same table, resolved by the caller off `row.classFilename`. A tooltip
    -- is about ONE player, which is what makes the question answerable here where
    -- the window header has to fall back to the local player's class instead.
    --
    -- STAT IS THE WINDOW'S SORT COLUMN, the statistic the grid the player is
    -- hovering is currently ranked by. A tooltip lists several statistics at once
    -- and is not "about" any one of them, so per-column would have no meaning
    -- here; the sort column is the same answer the title bar gives, for the same
    -- reason (modules/Window.lua's surfaceColor).
    --
    -- With nothing to read either way, the configured colour stands.
    tr, tg, tb = modeColor(config.colorMode, config.statKey, color, tr, tg, tb)

    -- THE BAR AND ITS BACKDROP ANSWER THE SAME THREE, each with its own colour,
    -- its own mode and its own opacity. The fill used to be the hovered player's
    -- class and nothing else -- no setting reached it, and the backdrop was a
    -- hard-coded black at 0.35 that no setting reached either.
    local fr, fg, fb = rgba(config.barColor, 0.6, 0.6, 0.6, 1)
    fr, fg, fb = modeColor(config.barColorMode, config.statKey, color, fr, fg, fb)

    local br, bg_, bb = rgba(config.barBgColor, 0, 0, 0, 1)
    br, bg_, bb = modeColor(config.barBgColorMode, config.statKey, color, br, bg_, bb)

    local ebr, ebg, ebb, eba = rgba(config.barBorderColor, 0, 0, 0, 1)
    ebr, ebg, ebb = modeColor(config.barBorderColorMode, config.statKey, color, ebr, ebg, ebb)

    local shadowX, shadowY = 0, 0
    if config.fontShadow then shadowX, shadowY = 1, -1 end

    return {
        color      = color,
        textColor  = { tr, tg, tb },
        barColor   = { fr, fg, fb, alphaOf(config.barAlpha, 0.85) },
        barBgColor = { br, bg_, bb, alphaOf(config.barBgAlpha, 0.1) },
        shadowX    = shadowX,
        shadowY    = shadowY,
        texture    = mediaPath("statusbar", config.barTexture),
        -- Size zero drops the FILE with it. A zero edgeSize with a texture still
        -- present is the combination WoW draws as a hard 1px line, which is the
        -- setting doing the opposite of what it says (modules/Window.lua says
        -- the same about the window's own border).
        border     = (borderSize > 0) and mediaPath("border", config.barBorderStyle) or nil,
        borderSize = borderSize,
        -- THE OUTLINE ANSWERS A MODE TOO (options-ui-§17), and its `class` is the
        -- HOVERED player's -- the same class the fill it surrounds takes, and the
        -- one a tooltip is about. Two values, not three: an outline around one
        -- spell line has no statistic of its own to be coloured by. Resolved to
        -- three numbers plus the swatch's own alpha, which survives the mode
        -- exactly as it does for the fill and the backdrop above.
        -- KEYED, because that is the shape this file's own `rgba` reads and the
        -- shape the stored swatch this replaces already had. The two bar colours
        -- above are positional because their consumer unpacks them.
        borderColor = { r = ebr, g = ebg, b = ebb, a = eba },
        fontPath   = path,
        fontSize   = size,
        fontFlags  = flags,
    }
end

--- Put the configured border around one line's carrier, or take it off.
---
--- Called on every draw and not once at creation, because the carrier is POOLED:
--- the frame drawing line 4 of this hover drew line 4 of the last one, and a
--- player who turned the border off between the two would otherwise keep it.
--- Clearing is an explicit SetBackdrop(nil) for exactly that reason.
local function applyLineBorder(frame, style)
    -- ON THE BAR, NOT ON THE CARRIER, and that is the whole of why this setting
    -- appeared to do nothing. The carrier is the parent; the bar is a child that
    -- covers it edge to edge, so a backdrop drawn on the carrier was drawn
    -- underneath the bar and could not be seen at any thickness or style. The bar
    -- carries the BackdropTemplate too (see lineWidget), and its fill sits at
    -- BACKGROUND so the edge lands above it -- the same fix modules/Row.lua's
    -- cell border needed, for the same reason.
    frame = frame.bar or frame
    if not frame.SetBackdrop then return end

    if not style.border then
        frame:SetBackdrop(nil)
        return
    end

    frame:SetBackdrop({
        -- No bgFile: the bar underneath already draws the line's background, and
        -- a backdrop fill on top of it would flatten every bar to one color.
        edgeFile = style.border,
        edgeSize = style.borderSize,
    })
    if frame.SetBackdropBorderColor then
        local r, g, b, a = rgba(style.borderColor, 0, 0, 0, 1)
        frame:SetBackdropBorderColor(r, g, b, a)
    end
end

--- Lay out one spell line and fill in its numbers.
---
--- THE BAR IS ABSENT WHILE THE VALUES CANNOT BE DIVIDED. A bar's length is
--- amount / max, which raises on two secrets, so it is drawn when core/Secrets.lua
--- says both operands are readable and omitted when they are not — exactly like
--- the share slot. THE AMOUNT NEVER GOES AWAY: it is set on the widget as
--- whatever the formatter returned, secret or not, so a mid-pull tooltip loses
--- decoration rather than information.
---
--- @param lineIndex number   which tooltip line this sits on
--- @param amount any         the formatted amount, possibly a secret string
--- @param share string       the formatted share, or "" when it may not be taken
--- @param value any          the spell's raw total, possibly secret
--- @param max any            the largest total in this breakdown, possibly secret
--- @param style table        a resolved style from `lineStyle`
--- @param label string|nil   text for the carrier's own name slot (target lines);
---                           nil leaves it empty, which is what a spell line wants
local function drawLine(lineIndex, amount, share, value, max, style, label, mode)
    local name = GameTooltip:GetName()
    local left = name and _G[name .. "TextLeft" .. lineIndex]
    if not left then return end

    local frame = lineWidget(lineIndex)

    -- The player's font, on OUR two slots and on the tooltip's own line. The
    -- line is shared and is restored by `restoreFonts`; the slots are ours and
    -- are simply re-set on every draw.
    frame.amount:SetFont(style.fontPath, style.fontSize, style.fontFlags)
    frame.share:SetFont(style.fontPath, style.fontSize, style.fontFlags)
    frame.label:SetFont(style.fontPath, style.fontSize, style.fontFlags)
    -- OUR OWN carriers, so no restore is owed on them the way it is on a shared
    -- GameTooltip line -- but they are POOLED, so the offset is restated every
    -- draw for the same reason the face and the color are.
    frame.amount:SetShadowOffset(style.shadowX, style.shadowY)
    frame.share:SetShadowOffset(style.shadowX, style.shadowY)
    frame.label:SetShadowOffset(style.shadowX, style.shadowY)

    -- Which slots exist on this line, and how wide they are. Re-stated here for
    -- the same reason the font above it is: the carrier is pooled.
    applySlotLayout(frame, style, mode)

    -- The share slot is sized from the font, so it is re-stated every draw for
    -- the same reason the font is: the carrier is pooled, and line 4 of this
    -- hover is the frame that drew line 4 of the last one, at whatever size that
    -- hover was configured with.
    frame.share:SetWidth(shareSlotWidth(style.fontPath, style.fontSize, style.fontFlags))

    -- Re-stated every draw rather than once at creation, exactly like the font:
    -- the carrier is pooled, so line 4 of this hover is the frame that drew line
    -- 4 of the last one, under whatever color that hover was configured with.
    local tc = style.textColor
    frame.amount:SetTextColor(tc[1], tc[2], tc[3])
    frame.share:SetTextColor(tc[1], tc[2], tc[3])
    frame.label:SetTextColor(tc[1], tc[2], tc[3])
    applyLineFont(left, lineIndex, style.fontPath, style.fontSize, style.fontFlags,
        style.shadowX, style.shadowY, tc)

    applyLineBorder(frame, style)

    frame:ClearAllPoints()
    -- Past the icon on the left, out to the tooltip's own right margin on the
    -- right. Anchoring the right edge to GameTooltip rather than to the line's
    -- right FontString keeps the track a fixed span even though that FontString is
    -- now empty — the numbers moved onto this carrier.
    frame:SetPoint("LEFT", left, "LEFT", BAR_INSET_LEFT, 0)
    frame:SetPoint("RIGHT", GameTooltip, "RIGHT", -(TOOLTIP_H_PADDING / 2), 0)
    frame:Show()

    frame.amount:SetText(amount)
    frame.share:SetText(share)
    frame.label:SetText(label or "")
    -- Blanked rather than left alone: a hidden slot still holds last hover's
    -- text, and the death path reads them back in tests.
    if mode ~= "event" then
        frame.time:SetText("")
        frame.caster:SetText("")
    end

    -- THE BAR TAKES THE HANDLES RAW, exactly as modules/Row.lua's cells do.
    --
    -- This used to gate on `CanCompare2(value, max)` and hide the bar whenever
    -- the two could not be compared — which is every line of every breakdown in
    -- combat, so the tooltip lost its bars for the whole of every pull while the
    -- main window kept its own. That was a misreading of the rule. A bar's fill
    -- is amount/max computed NATIVELY, by the widget, in code that is allowed to
    -- see secrets; tainted code only may not do that division ITSELF.
    -- core/Secrets.lua says so in as many words: SetValue and SetMinMaxValues are
    -- on the MAY list.
    --
    -- So the only test applied here is `== nil`, which is legal on a non-boolean
    -- secret and is the one test Row.lua applies too. How big the value is, and
    -- how it compares to the max, is the widget's business.
    --
    -- The consequence is the documented one and it is already paid: a frame that
    -- has been handed a secret has secret geometry, so nothing anchored to this
    -- bar may be read back. Layout here is computed from config (rule R3).
    local b = frame.bar
    b:SetStatusBarTexture(style.texture or BAR_FALLBACK_TEXTURE)
    -- BACKGROUND at sublevel 1: above the bar's own backdrop texture (sublevel 0)
    -- and below everything else, so the tooltip's ARTWORK spell name reads on top
    -- of the fill and the BORDER-layer backdrop edge does too. It used to sit at
    -- BORDER, which put it level with the edge that is supposed to outline it.
    -- SetStatusBarTexture replaces the texture object, so the layer has to be
    -- re-stated every draw and not once at creation.
    local fill = b.GetStatusBarTexture and b:GetStatusBarTexture()
    if fill and fill.SetDrawLayer then fill:SetDrawLayer("BACKGROUND", 1) end
    if max == nil then
        b:SetMinMaxValues(0, 1)
    else
        b:SetMinMaxValues(0, max)
    end
    b:SetValue(value == nil and 0 or value)
    local bc = style.barColor
    b:SetStatusBarColor(bc[1], bc[2], bc[3], bc[4])
    -- The backdrop was a hard-coded black at 0.35 set once at creation, which no
    -- setting could reach and which a POOLED line would carry from one hover to
    -- the next anyway. Re-stated every draw, like the font and the border.
    local bbc = style.barBgColor
    if b.bg then b.bg:SetColorTexture(bbc[1], bbc[2], bbc[3], bbc[4]) end
    b:Show()
end

local function addSpellLine(spell, numberStyle, max, style, sourceTotal)
    local spellID = spell.spellID
    local spellName, iconID
    if spellID ~= nil and Compat and Compat.GetSpellInfo then
        spellName, iconID = Compat.GetSpellInfo(spellID)
    end

    -- A spell the client cannot name is shown by ID rather than dropped: an
    -- unnamed row is still evidence, and a silently missing row is not. The nil
    -- case has to be handled explicitly because string.format("%s", nil) raises
    -- in Lua 5.1 — the one place this line could break is the one place the
    -- data is already unusual.
    local caption = spellName
    if caption == nil then
        caption = (spellID ~= nil) and string.format("#%s", spellID) or "#?"
    end

    local label = string.format("|T%s:%d:%d:0:0|t %s",
        iconID or FALLBACK_ICON,
        TOOLTIP_ICON_SIZE, TOOLTIP_ICON_SIZE,
        caption)

    -- The amount and the share go onto our OWN widgets, in their own fixed slots,
    -- so this line is added with a LEFT SIDE ONLY. Handing them to AddDoubleLine
    -- instead would right-align the pair as one string and the share column would
    -- zig-zag behind amounts of different widths.
    --
    -- Neither is inspected on the way. `formatNumber` may hand back the ORIGINAL
    -- OPAQUE VALUE when no formatter is reachable; it travels to SetText, which is
    -- a widget setter and accepts a secret.
    GameTooltip:AddLine(label, 1, 1, 1)

    local amount = formatNumber(spell.totalAmount, numberStyle)
    local share = sourceTotal ~= nil and formatShare(spell.totalAmount, sourceTotal) or ""

    -- The line widget goes BEHIND the tooltip line that was just added, so it
    -- needs that line's index — which is NumLines now that the line exists.
    drawLine(GameTooltip:NumLines(), amount, share, spell.totalAmount, max, style, nil)
end

-- How many deaths a grid cell's tooltip will list before it stops. A raid night
-- can hold more than anyone reads in a hover, and the drill-down is one click
-- away with the whole list in it.
local MAX_DEATH_LINES = 12

-- What a death shows in place of a time when the client no longer holds its
-- recap. The same em dash modules/DrillDown.lua puts in the cell.
local NO_CLOCK_TEXT = "\226\128\148"

--- How one death is labelled, in whichever style the hovered window is set to.
---
--- The moment of death is the recap's NEWEST event, never `deathTimeSeconds` —
--- those are different clocks, one absolute and one seconds-into-session, and
--- the second is unusable besides (see modules/Format.lua's DeathTime).
---
--- Kept in step with modules/DrillDown.lua's copy on purpose: this tooltip is
--- the INDEX into that list, and the two labelling deaths differently would make
--- one list look like two.
---
--- @param recap table|nil
--- @param style string|nil  the window's timestamp style
--- @return string|nil
local function deathClockOf(recap, style)
    local events = recap and recap.events
    if type(events) ~= "table" then return nil end

    local Secrets = NS.Secrets
    if Secrets and Secrets.CanAccessTable and not Secrets.CanAccessTable(events) then
        return nil
    end

    local newest = events[1]
    if type(newest) ~= "table" then return nil end
    if Secrets and Secrets.CanAccessTable and not Secrets.CanAccessTable(newest) then
        return nil
    end

    local F = NS.Numbers or NS.Format
    if not (F and F.DeathTime) then return nil end
    return F.DeathTime(newest.timestamp, style)
end

--- Who and what landed the killing blow, as PLAIN strings or nil.
---
--- THE RECAP'S NEWEST EVENT IS THE KILLING BLOW. The array arrives newest first
--- (core/Compat.lua's GetRecapEvents), which is the same fact deathClockOf above
--- leans on for the moment of death -- element one, both times.
---
--- PLAIN OR ABSENT, and that is the whole design of this function. `sourceName`
--- and `spellName` are resolved off ids the client may hand back SECRET, and the
--- caller joins these into one label with `..` -- which is the operator this
--- addon has been bitten by once already (modules/Tooltip.lua's eventColumns
--- refuses to join a spell name to a caster name for exactly this reason). So
--- everything leaves here through `plainWord`, and a name that cannot be read
--- comes back nil and is simply not drawn. "Not available" and "secret right
--- now" are the same thing to a reader, and the line still says which death it is.
---
--- @param recap table|nil  a Provider.GetRecap result
--- @return string|nil caster, string|nil spell
local function killingBlowOf(recap)
    local events = recap and recap.events
    if type(events) ~= "table" then return nil, nil end

    local Secrets = NS.Secrets
    if Secrets and Secrets.CanAccessTable and not Secrets.CanAccessTable(events) then
        return nil, nil
    end

    local newest = events[1]
    if type(newest) ~= "table" then return nil, nil end
    if Secrets and Secrets.CanAccessTable and not Secrets.CanAccessTable(newest) then
        return nil, nil
    end

    -- `hideCaster` may be a secret boolean, so it goes through plainTruth -- the
    -- same gate eventColumns applies to the same field. An environmental death
    -- (a fall, a fire) has no caster to name and says so by setting it.
    local caster = plainWord(newest.sourceName)
    if plainTruth(newest.hideCaster) then caster = nil end

    -- A MELEE SWING HAS NO SPELL AT ALL -- no id, no name -- and is named the way
    -- Blizzard's own recap names it rather than left blank. Unlike eventColumns
    -- there is no "#12345" fallback here: an id is not a thing to put in a
    -- one-line summary, and this line is a summary.
    local spell = plainWord(newest.spellName)
    if spell == nil and plainWord(newest.event) == "SWING_DAMAGE" then
        spell = L["Melee"] or "Melee"
    end

    return caster, spell
end

--- One death list line's text: the ordinal, and whatever of the killing blow is
--- both readable and switched on.
---
--- SPLIT OUT OF addDeathList rather than inlined there, because that function is
--- already a loop over a memoized provider read with two degradation paths in it
--- and this is a third concern -- the label's own grammar. Keeping them apart is
--- what keeps either one readable, and lizard agrees.
---
--- `..` IS SAFE ON EVERY PIECE HERE and nowhere near a meter value: the ordinal is
--- this addon's own count, and killingBlowOf answers plain strings or nothing.
---
--- @param ordinal number      1 for the run's FIRST death
--- @param caster string|nil
--- @param spell string|nil
--- @param config table|nil     nil means "draw both", for a caller with no config
--- @return string
local function deathLineLabel(ordinal, caster, spell, config)
    local label = string.format(L["Death %d"] or "Death %d", ordinal)
    if caster and (config == nil or config.showDeathCaster) then
        label = label .. DEATH_DETAIL_SEP .. caster
    end
    if spell and (config == nil or config.showDeathSpell) then
        label = label .. DEATH_DETAIL_SEP .. spell
    end
    return label
end

-- ---------------------------------------------------------------------------
-- What modules/Tooltip_Builders.lua reaches for
-- ---------------------------------------------------------------------------
--
-- The same seam table modules/Tooltip.lua opened, carrying this file's half of
-- it: the line widget and the draw, the two minimum-width applications, the text
-- spans, and the death-label helpers. Not API, and resolved there at FILE SCOPE.
I.lineWidget = lineWidget
I.measureText = measureText
I.charSpan = charSpan
I.applyMinimumWidth = applyMinimumWidth
I.applyDeathMinimumWidth = applyDeathMinimumWidth
I.lineStyle = lineStyle
I.drawLine = drawLine
I.addSpellLine = addSpellLine
I.MAX_DEATH_LINES = MAX_DEATH_LINES
I.NO_CLOCK_TEXT = NO_CLOCK_TEXT
I.deathClockOf = deathClockOf
I.killingBlowOf = killingBlowOf
I.deathLineLabel = deathLineLabel
