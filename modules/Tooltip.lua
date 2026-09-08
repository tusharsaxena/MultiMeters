-- modules/Tooltip.lua
--
-- What a hover says. Two tooltips, one module:
--
--   * hovering a STAT CELL lists the individual spells behind that one number
--     for that one player — which kick, which dispel, which avoidable hit;
--   * hovering the NAME cell summarizes EVERY tracked statistic for that
--     player, including the columns this window is not showing, which is the
--     cross-column read the whole addon exists for.
--
-- ---------------------------------------------------------------------------
-- SECRETS: THE RULE THAT SHAPES EVERY LINE BELOW
-- ---------------------------------------------------------------------------
--
-- A tooltip looks like the safest place in a meter — it is unprotected, it is
-- built out of strings, nothing about it is secure. It is in fact the most
-- dangerous, because a tooltip is where a developer's instinct is to say "just
-- show the top five spells" and "put the total at the bottom". Both of those are
-- Lua errors mid-pull: a top-N is a COMPARISON and a total is ARITHMETIC, and
-- while the Combat addon restriction is active every amount on a spell row is a
-- SECRET value.
--
-- So, in this file:
--   * no amount is ever added, subtracted, divided or compared;
--   * every amount reaches the screen through string.format or through the
--     number formatter, both of which accept secrets (design §4);
--   * ordering is attempted ONLY when NS.Secrets says comparison is legal, and
--     otherwise the spells are shown in the order the API returned them, which
--     is a real ordering and not a fallback to nonsense;
--   * booleans off the API (isAvoidable, isDeadly) are never truth-tested
--     directly, because a SECRET boolean raises on a boolean test — they go
--     through `plainTruth`, which asks core/Secrets.lua first;
--   * nil-ness tests use an explicit `~= nil`, which is the one comparison a
--     non-boolean secret permits.
--
-- Counting is the other trap. `#spells` is the length operator, forbidden on a
-- secret table, so the count comes from NS.Secrets.SafeCount and the walk from
-- NS.Secrets.SafeIterate — which is also why the "and N more" line can exist at
-- all without measuring anything we are not allowed to measure.
--
-- ---------------------------------------------------------------------------
-- WHY GAMETOOLTIP
-- ---------------------------------------------------------------------------
--
-- A private tooltip frame would let us style it, and would cost us every addon
-- that hooks GameTooltip, the player's tooltip skin, and the automatic
-- repositioning that keeps a tooltip on screen. GameTooltip is cleared and
-- re-owned on every hover, so nothing we add outlives the hover.

-- ---------------------------------------------------------------------------
-- WHAT IS HERE, AND WHAT IS IN THE TWO SIBLINGS
-- ---------------------------------------------------------------------------
--
-- This file went past layout-§1's 1500-line cap (issue #28) and was peeled along
-- the two seams its own banners already drew. What stays here is THE PRIMITIVES
-- and the teardown rule: the secret-safe writers, the configuration read, the
-- media lookups, the anchoring, the spell collection, the font that has to be put
-- back, the pooled lines and the OnHide hook that empties them.
--
--   * modules/Tooltip_Lines.lua -- one pooled line as a WIDGET: its carrier, the
--     text measurement, the slot layout, the resolved style and the draw.
--   * modules/Tooltip_Builders.lua -- what the hovers actually SAY: the death
--     events, and the four tooltips (Targets, the cell breakdown, the name
--     tooltip, the spell row).
--
-- The seam between the three is `NS.TooltipInternals` at the bottom of this file
-- and at the bottom of modules/Tooltip_Lines.lua. The SECRETS rule above is not
-- local to this file: it binds all three, and the two siblings say so.

local _, NS = ...

local Tooltip = NS:NewModule("Tooltip", "AceEvent-3.0")
NS.Tooltip = Tooltip

local L      = NS.L
local Const  = NS.Constants
local State  = NS.State
-- `Compat` and `Debug` went across with the code that read them: the two siblings
-- re-derive them off NS the same way this header does.

-- Load-time upvalue, never an NS lookup in the bracket itself (performance-§2).
-- core/PerfSetup.lua loads well before modules/, and it always publishes at least
-- the degradation stub, so the `or {}` covers only a hand-broken install.
local Perf = NS.Perf or {}

-- Fallback icon for a spellID the client cannot resolve — a real texture rather
-- than a blank, so a missing icon reads as "unknown spell" instead of as a
-- broken layout.
local FALLBACK_ICON = [[Interface\ICONS\INV_Misc_QuestionMark]]

-- The icon every TARGET line wears. A target is a unit rather than a spell, so
-- there is no per-row icon to look up and the slot sat empty -- one section of
-- the tooltip indented past an icon column with nothing in it, which reads as a
-- missing icon rather than as a section that has none. One shared texture is
-- honest about that: its job is to hold the column where every spell line puts
-- its icon, not to tell one target from another.
--
-- Ability_hunter_focusedaim: a reticle over a target, which is the closest thing
-- the client's icon set has to "the thing you were hitting".
--
-- AND THE CATALOG HAS `target`, so this is a considered decline rather than an
-- oversight (library-stack-§8). It is wrong here for the reason above: the slot
-- sits in a column of Blizzard spell icons, and the catalog's marks are white
-- with their shape in the alpha channel BY RULE, so the one line drawing a Ka0s
-- glyph would be the one line that looked foreign. Recorded in
-- docs/ARCHITECTURE.md's "Hard-coded texture paths" census.
local TARGET_ICON = [[Interface\ICONS\Ability_Hunter_FocusedAim]]

-- Icon edge length inside a tooltip line, in pixels. Sized to sit on the text
-- baseline at the game's default tooltip font rather than to match the row
-- icons, which are configurable and live in a different frame entirely.
local TOOLTIP_ICON_SIZE = 14

-- How many spell rows to pull off the API before deciding what to show.
--
-- Larger than any sane `tooltip.maxSpells` on purpose: when comparison is legal
-- we sort what we collected and show the biggest few, and sorting only the first
-- ten rows the API happened to hand back would produce a "top 5" that is nothing
-- of the sort. Small enough that a hover never walks a long array.
local COLLECT_LIMIT = 64

-- ---------------------------------------------------------------------------
-- Collaborators, resolved at call time
-- ---------------------------------------------------------------------------
--
-- modules/ files load in TOC order and this one cannot assume it is last, so
-- neither the provider nor the number formatter is captured as a load-time
-- upvalue. Both resolutions are shape-agnostic — flat NS field first, AceAddon
-- module second — because that is the pattern the rest of the addon uses to
-- reach a module and it costs one table read on a path that runs on a hover.

--- modules/Provider.lua, or nil.
local function provider()
    if NS.Provider then return NS.Provider end
    if NS.GetModule then return NS:GetModule("Provider", true) end
    return nil
end

--- Render one meter amount as text.
---
--- THE ONLY LEGAL ABBREVIATOR is C_StringUtil's numeric rule formatter, whose
--- FormatNumber does the division natively; modules/Format.lua owns the
--- instances. Note that `NS.Format` is NOT it — that name belongs to
--- LibKa0s-Core's chat printf, claimed in core/CoreSetup.lua — so the number
--- formatter is reached through the module registry.
---
--- When no formatter is reachable the value is returned UNTOUCHED rather than
--- stringified. It is then handed to string.format's `%s`, which accepts a
--- secret; calling tostring() on it here would be an inspection this file is not
--- allowed to make (rule R1).
---
--- @param value any   a meter amount, possibly secret
--- @param style string|nil  "abbreviated" | "full"
--- @return any  a string, or the original opaque value
local function formatNumber(value, style)
    local F = NS.Numbers or (NS.GetModule and NS:GetModule("Format", true))
    if F then
        if F.Number then return F.Number(value, style) end
        if F.FormatNumber then return F:FormatNumber(value, style) end
    end
    return value
end

--- One spell's share of the player's total for this column, as trailing text.
---
--- A SHARE IS A DIVISION, so this is the one slot on a spell line that cannot
--- survive a pull. modules/Format.lua's ratio form asks core/Secrets.lua whether
--- the two operands may be divided and answers an EMPTY STRING when they may
--- not — so mid-pull the percentages simply are not there, and the amount beside
--- them is unaffected. That is the intended behaviour, not a degraded one: the
--- alternative is approximating a number the client will not let us compute.
---
--- The empty answer must never be read as "0%". It is returned as "" precisely so
--- that a caller appends nothing rather than appending a lie.
---
--- @param value any   this spell's amount, possibly secret
--- @param total any   the player's total for this column, possibly secret
--- @return string     "" when the division is not permitted
local function formatShare(value, total)
    local F = NS.Numbers or (NS.GetModule and NS:GetModule("Format", true))
    if not (F and F.Percent) then return "" end
    return F.Percent(value, total) or ""
end

-- ---------------------------------------------------------------------------
-- Secret-safe primitives
-- ---------------------------------------------------------------------------

--- Truth-test a field that MIGHT be a secret boolean.
---
--- `if spell.isAvoidable then` is the natural way to write this and it raises
--- the moment the Combat restriction is active, because a boolean test on a
--- secret boolean is exactly what tainted code may not do. Asking
--- core/Secrets.lua whether the value is accessible first keeps the inspection
--- in the one file allowed to make it, and an inaccessible flag reads as false —
--- the tooltip loses a "Deadly" tag mid-pull rather than erroring.
---
--- @param v any
--- @return boolean
--- Whether a value is present and may NOT be read.
---
--- Distinct from `plainWord` answering nil, which also covers "there is nothing
--- here". A caption that is absent costs a column nothing; one that is secret
--- costs the whole measurement.
local function unreadable(v)
    if v == nil then return false end
    local S = NS.Secrets
    return (S and S.CanAccess and not S.CanAccess(v)) and true or false
end

--- A string this code may compare, or nil.
---
--- The recap's `event` field decides whether a line is a swing or a heal, and a
--- comparison against a secret raises. nil means "cannot tell", which lands on
--- the ordinary path.
local function plainWord(v)
    if v == nil then return nil end
    local S = NS.Secrets
    if S and S.CanAccess and not S.CanAccess(v) then return nil end
    if type(v) ~= "string" then return nil end
    return v
end

local function plainTruth(v)
    local Secrets = NS.Secrets
    if not (Secrets and Secrets.CanAccess) then return false end
    if not Secrets.CanAccess(v) then return false end
    return v and true or false
end

--- A player's display name, or a placeholder.
---
--- `name` is ConditionalSecret: readable most of the time, opaque some of the
--- time, and never something to concatenate a fallback onto with `or` without
--- asking first. An inaccessible name still renders — it goes to the widget as
--- the opaque handle it is — but a NIL name has to become a string here, since
--- the tooltip's first line cannot be nil.
---
--- @param row table
--- @return any  a string, or an opaque name handle
local function displayName(row)
    local name = row and row.name
    if name == nil then return L["Player"] end
    return name
end

--- The colour a tooltip's first line draws the player's name in.
---
--- BY CLASS, ALWAYS, and not behind a setting. Every other name this addon draws
--- is class-coloured -- the Player column has been since the first build -- and
--- the tooltip's own header was the one place a name came out white, so a hover
--- read as belonging to nothing in particular. `classFilename` is NeverSecret,
--- which is why this keeps working mid-pull when the numbers under it do not.
---
--- Three returns, for AddDoubleLine's first colour triple. A row with no class --
--- an NPC, an enemy, a spell in a breakdown -- keeps white, which is the honest
--- answer rather than a tenth palette entry.
---
--- @param row table|nil
--- @return number r, number g, number b
local function nameColor(row)
    local classes = _G.RAID_CLASS_COLORS
    local c = classes and row and row.classFilename and classes[row.classFilename]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------

-- Every field the two builders read, with the shipped value beside it. Taken
-- from NS.WINDOW_TEMPLATE at CALL time rather than copied as literals, so a
-- change to defaults/Profile.lua cannot leave a stale second copy here.
local function tooltipConfig(window)
    local template = NS.WINDOW_TEMPLATE and NS.WINDOW_TEMPLATE.tooltip or nil
    local stored = (type(window) == "table" and window.tooltip) or nil

    local function field(key, hardDefault)
        if stored and stored[key] ~= nil then return stored[key] end
        if template and template[key] ~= nil then return template[key] end
        return hardDefault
    end

    return {
        anchor             = field("anchor", "CURSOR"),
        scale              = field("scale", 1.0),
        offsetX            = field("offsetX", 0),
        offsetY            = field("offsetY", 0),
        showSpells         = field("showSpells", true),
        maxSpells          = field("maxSpells", 10),
        showAllStatsOnName = field("showAllStatsOnName", true),
        hideInCombat       = field("hideInCombat", false),
        textColor          = field("textColor", nil),
        barTexture         = field("barTexture", "Blizzard Raid Bar"),
        barColor           = field("barColor", nil),
        barColorMode       = field("barColorMode", "class"),
        barAlpha           = field("barAlpha", 0.85),
        barBgColor         = field("barBgColor", nil),
        barBgColorMode     = field("barBgColorMode", "custom"),
        barBgAlpha         = field("barBgAlpha", 0.1),
        barSpacing         = field("barSpacing", 1),
        barBorderStyle     = field("barBorderStyle", "None"),
        barBorderSize      = field("barBorderSize", 1),
        barBorderColor     = field("barBorderColor", nil),
        barBorderColorMode = field("barBorderColorMode", "custom"),
        font               = field("font", "Friz Quadrata TT"),
        fontSize           = field("fontSize", 12),
        fontOutline        = field("fontOutline", "NONE"),
        fontShadow         = field("fontShadow", false),
        colorMode          = field("colorMode", "custom"),
        -- WHICH statistic `colorMode == "stat"` means. Filled in by the CALLER,
        -- because only the caller knows: a cell tooltip is about the column that
        -- was hovered, which is the whole of what it is showing. The window's sort
        -- column stood here first and was wrong for exactly that reason -- every
        -- breakdown, of every column, came out in the sort column's colour, so a
        -- Healing tooltip was red.
        --
        -- The two tooltips that are NOT about one statistic -- the name tooltip,
        -- which lists them all, and the death recap -- fall back to the sort
        -- column, which is the only statistic those two can be said to be about.
        statKey            = (type(window) == "table" and window.data
                              and window.data.sortColumn) or "DamageDone",
        showTargets        = field("showTargets", false),
        maxTargets         = field("maxTargets", 3),
        showDeathCaster    = field("showDeathCaster", true),
        showDeathSpell     = field("showDeathSpell", true),
    }
end

-- ---------------------------------------------------------------------------
-- Media
-- ---------------------------------------------------------------------------

local function lsm()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

--- An LSM path, or nil. Nil is a real answer everywhere it is used here: a
--- StatusBar with no texture falls back to BAR_FALLBACK_TEXTURE, and a backdrop
--- with no edgeFile draws no border, which is what "None" has to mean.
local function mediaPath(mediaType, name)
    if type(name) ~= "string" or name == "" or name == "None" then return nil end
    local media = lsm()
    return media and media:Fetch(mediaType, name, true) or nil
end

--- The font this tooltip draws in: a path, a size, and the flag string WoW wants
--- as nil rather than as the literal "NONE".
---
--- The path falls all the way back to the client's own standard face rather than
--- to nil, because a FontString with NO font raises on SetText — and every
--- caller here sets text immediately afterwards.
---
--- @param config table
--- @return string path, number size, string|nil flags
local function tooltipFont(config)
    local path = mediaPath("font", config.font)
        or Const.FONT_MONO or _G.STANDARD_TEXT_FONT
    local size = config.fontSize
    if type(size) ~= "number" or size < 1 then size = 12 end
    local flags = (config.fontOutline ~= "NONE") and config.fontOutline or nil
    return path, size, flags
end

--- A color table's four channels, with a fallback per channel.
local function rgba(color, dr, dg, db, da)
    if type(color) ~= "table" then return dr, dg, db, da end
    return color.r or dr, color.g or dg, color.b or db, color.a or da
end

--- The window config a row belongs to.
---
--- Callers pass it explicitly wherever they have it; the lookup exists for the
--- row-pool call sites, which hold a window ID on the frame and not the table.
---
--- @param row table|nil
--- @param window table|nil
--- @return table|nil
local function resolveWindow(row, window)
    if type(window) == "table" then return window end
    local id = row and row.windowId
    if id ~= nil and NS.Database and NS.Database.FindWindow then
        local found = NS.Database.FindWindow(id)
        return found
    end
    return nil
end

--- Which session (Current / Overall / Expired) this window reads.
local function sessionTypeOf(window)
    local data = type(window) == "table" and window.data or nil
    if data and data.sessionType ~= nil then return data.sessionType end
    return Const.SESSION_TYPE.Current
end

--- Which stored SEGMENT it is pointed at, or nil for "the one sessionType
--- names". A tooltip that read the live pull while the grid under it showed a
--- historical segment would be describing a different fight than the row the
--- cursor is on.
local function sessionIDOf(window)
    local data = type(window) == "table" and window.data or nil
    return data and data.sessionID or nil
end

--- The abbreviation style the hovered window is using, so the tooltip's numbers
--- read the same way its cells do. nil means "whatever the formatter defaults
--- to", which is what an unconfigured window wants.
local function numberStyleOf(window)
    return window and window.text and window.text.numberFormat or nil
end

--- How many spell lines the breakdown may draw.
---
--- ZERO MEANS EVERY SPELL, and the honest value of "every" is COLLECT_LIMIT:
--- `collectSpells` never pulls more than that however this is set, so returning
--- anything larger would be a cap that lies about itself. Nothing is hidden by
--- the difference — the "and N more" line counts what was left out with
--- SafeCount and keeps saying so.
---
--- Everything else is clamped rather than trusted, because `maxSpells` comes off
--- a saved profile that an older build — or a hand edit — may have left as a
--- string or as a negative. The shipped default is the answer in both cases.
local function spellLineCap(config)
    local cap = config.maxSpells
    if cap == 0 then return COLLECT_LIMIT end
    if type(cap) ~= "number" or cap < 1 then return 10 end
    return cap
end

-- ---------------------------------------------------------------------------
-- Anchoring
-- ---------------------------------------------------------------------------
--
-- WHERE THE TOOLTIP GOES, as the cell of a 3x3 grid drawn around the thing being
-- hovered. "Top left" is the box above and to the LEFT of the cell; "Left" is the
-- box beside it, vertically centred; and so on around the eight. Every one of
-- them therefore names a direction the tooltip grows in as well as a corner it
-- touches, which is what a player means by picking one.
--
-- BLIZZARD'S TOKENS CANNOT SAY THIS. ANCHOR_TOPLEFT and ANCHOR_TOPRIGHT put the
-- tooltip directly ABOVE the owner, aligned to one edge or the other, so both of
-- them grow across the thing you are hovering rather than away from it; there is
-- no token at all for the four diagonal boxes. So the token is the FALLBACK and
-- the pair below is the placement.
--
-- `tip` is the tooltip's own corner and `owner` is the corner of the hovered
-- frame it is put against. Reading one row: TOPLEFT puts the tooltip's
-- BOTTOMRIGHT on the cell's TOPLEFT, so it sits up and to the left, growing that
-- way.
local ANCHOR_POINTS = {
    TOPLEFT     = { tip = "BOTTOMRIGHT", owner = "TOPLEFT" },
    TOP         = { tip = "BOTTOM",      owner = "TOP" },
    TOPRIGHT    = { tip = "BOTTOMLEFT",  owner = "TOPRIGHT" },
    LEFT        = { tip = "RIGHT",       owner = "LEFT" },
    RIGHT       = { tip = "LEFT",        owner = "RIGHT" },
    BOTTOMLEFT  = { tip = "TOPRIGHT",    owner = "BOTTOMLEFT" },
    BOTTOM      = { tip = "TOP",         owner = "BOTTOM" },
    BOTTOMRIGHT = { tip = "TOPLEFT",     owner = "BOTTOMRIGHT" },
}

-- GameTooltip's own anchor tokens, keyed by the setting's value, and now the
-- FALLBACK rather than the placement: SetOwner is called with one of these first
-- so the tooltip always has a valid position, and the exact placement above is
-- then laid over it.
--
-- THE ORDER MATTERS AND IS THE SAFETY NET. Anchoring GameTooltip to a cell that
-- has been handed a meter value gives the tooltip secret anchoring data (rule
-- R3), and this addon's execution is tainted -- so the SetPoint below is the one
-- call in this file that could raise inside Blizzard's own code, at the worst
-- possible moment. It is pcall'd, and a failure leaves the token's placement
-- standing: the tooltip opens in roughly the right place rather than not at all.
--
-- ANCHOR_NONE and ANCHOR_PRESERVE are still absent, and for the same reason as
-- before: both mean "the owner places this", which with no placement of our own
-- would be no placement at all.
local ANCHOR_TOKENS = {
    TOP         = "ANCHOR_TOP",
    BOTTOM      = "ANCHOR_BOTTOM",
    LEFT        = "ANCHOR_LEFT",
    RIGHT       = "ANCHOR_RIGHT",
    TOPLEFT     = "ANCHOR_TOPLEFT",
    TOPRIGHT    = "ANCHOR_TOPRIGHT",
    BOTTOMLEFT  = "ANCHOR_BOTTOMLEFT",
    BOTTOMRIGHT = "ANCHOR_BOTTOMRIGHT",
}

--- A scale that is safe to hand to SetScale: a real number, bounded to the range
--- the schema offers. Zero or a negative would make the tooltip invisible or
--- inside-out, and a saved profile carrying a string would raise inside
--- Blizzard's own code where the traceback names neither this file nor the
--- setting.
local function tooltipScale(v)
    if type(v) ~= "number" then return 1 end
    if v < 0.5 then return 0.5 end
    if v > 2 then return 2 end
    return v
end

--- An offset that is safe to hand to SetOwner: a real number, bounded to the
--- range the schema offers. A saved profile carrying a string here would
--- otherwise raise inside Blizzard's own code, where the traceback names
--- neither this file nor the setting.
local function offset(v)
    if type(v) ~= "number" then return 0 end
    if v < -400 then return -400 end
    if v > 400 then return 400 end
    return v
end

-- WHAT THIS HOVER ASKED FOR, kept between openTooltip and the Show that ends the
-- build. Cleared by releaseLines with everything else.
local pendingPlacement

--- Put the tooltip in the box the setting names, or leave the token's placement
--- alone.
---
--- CALLED AGAIN AFTER GameTooltip:Show(), AND THAT IS THE WHOLE TRICK. The show
--- path RE-ANCHORS the tooltip to its owner -- the same way it re-fonts the
--- tooltip's lines, which is why `reapplyFonts` exists three lines below every
--- Show in this file. Placing only before the lines were added meant every point
--- set here was silently thrown away and the token's placement was what the
--- player actually got: "Top left" sat directly above the cell growing right,
--- because that is what ANCHOR_TOPLEFT does, and no anchor produced the box
--- beside the cell at all.
---
--- THE OFFSETS ARE APPLIED HERE rather than through SetOwner, so they mean the
--- same thing whichever path placed the tooltip: positive x moves it right and
--- positive y moves it up, from wherever the anchor put it.
local function applyPlacement()
    local at = pendingPlacement
    if not at then return end
    if not (GameTooltip.SetPoint and GameTooltip.ClearAllPoints) then return end

    -- pcall'd: see the note on ANCHOR_TOKENS above. A raise here means the
    -- tooltip keeps the placement SetOwner already gave it.
    pcall(function()
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint(at.tip, at.frame, at.owner, at.x, at.y)
    end)
end

--- Remember where this hover wants the tooltip, and make the first attempt.
---
--- @param anchorFrame table
--- @param config table
local function placeTooltip(anchorFrame, config)
    local at = ANCHOR_POINTS[config.anchor] or ANCHOR_POINTS.TOP
    if not (at and anchorFrame) then
        pendingPlacement = nil
        return
    end
    pendingPlacement = {
        frame = anchorFrame, tip = at.tip, owner = at.owner,
        x = offset(config.offsetX), y = offset(config.offsetY),
    }
    applyPlacement()
end

--- Claim GameTooltip for this hover, or answer false if it must not open.
---
--- The combat test is UnitAffectingCombat("player") and NOT InCombatLockdown().
--- They differ at both ends of a pull, and what the setting means is "while I am
--- fighting, keep this out of my way" — a statement about the player, not about
--- whether secure writes are currently legal.
---
--- @param anchorFrame table
--- @param config table
--- @return boolean  whether the tooltip was opened
local function openTooltip(anchorFrame, config)
    if not _G.GameTooltip or not anchorFrame then return false end

    if config.hideInCombat and _G.UnitAffectingCombat and UnitAffectingCombat("player") then
        return false
    end

    -- The offsets are passed to SetOwner rather than applied afterwards with a
    -- SetPoint of our own: the client still does the placing, and it still keeps
    -- the tooltip on screen. Nudging it ourselves would mean reading a point back
    -- off a frame that has held a secret (rule R3).
    -- SCALE BEFORE SetOwner, so the client places a tooltip of the size it is
    -- actually going to be. Set afterwards, the placement is computed against the
    -- old size and a scaled-up tooltip runs off the edge of the screen it was
    -- just fitted to.
    --
    -- RESTORED ON HIDE like the fonts are (see ensureTooltipHook): GameTooltip is
    -- Blizzard's and is shared with every other addon, so leaving it at 1.4
    -- rescales the next quest text somebody hovers.
    if GameTooltip.SetScale then
        GameTooltip:SetScale(tooltipScale(config.scale))
    end

    -- TOP is the fallback for a stored anchor this build does not offer -- a
    -- profile that escaped the v9 -> v10 step still carrying "CURSOR", say. It is
    -- the shipped default, so an unrecognised value lands on the same place a new
    -- window does rather than somewhere nothing else uses.
    GameTooltip:SetOwner(anchorFrame, ANCHOR_TOKENS[config.anchor] or "ANCHOR_TOP",
        offset(config.offsetX), offset(config.offsetY))
    placeTooltip(anchorFrame, config)
    GameTooltip:ClearLines()

    -- Line spacing is a property of the SHARED tooltip, like the minimum width,
    -- so releaseLines puts it back. Guarded because it arrived with the modern
    -- tooltip template and this addon still loads on a client without it.
    if GameTooltip.SetCustomLineSpacing then
        local spacing = config.barSpacing
        if type(spacing) ~= "number" or spacing < 0 then spacing = 0 end
        GameTooltip:SetCustomLineSpacing(spacing)
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Spell rows
-- ---------------------------------------------------------------------------

--- Pull up to COLLECT_LIMIT spell rows off a session source.
---
--- Walks through NS.Secrets.SafeIterate, which never applies `#` to the array
--- and stops at the first nil — the only way to traverse a possibly-secret table
--- without measuring it. Each row is additionally checked for accessibility,
--- because the ARRAY being walkable does not make every ENTRY indexable.
---
--- @param source table  a DamageMeterCombatSessionSource
--- @return table spells, number|nil totalCount
local function collectSpells(source)
    local Secrets = NS.Secrets
    local spells = {}
    if not (Secrets and Secrets.SafeIterate) then return spells, nil end

    local total = Secrets.SafeCount and Secrets.SafeCount(source.combatSpells) or nil

    Secrets.SafeIterate(source.combatSpells, function(_, spell)
        if type(spell) ~= "table" then return end
        if Secrets.CanAccessTable and not Secrets.CanAccessTable(spell) then return end
        spells[#spells + 1] = spell
        if #spells >= COLLECT_LIMIT then return false end
    end)

    return spells, total
end

--- Order the collected spells biggest-first, but ONLY when that is legal.
---
--- Every amount is checked BEFORE table.sort is entered, not inside the
--- comparator. A comparator that refused some comparisons would return an
--- inconsistent order and Lua would raise "invalid order function for sorting" —
--- a confusing error for a correct instinct. Checking up front means the answer
--- is binary: sort everything, or sort nothing and present the provider's order,
--- which the API already returns in a meaningful sequence.
---
--- A MISSING amount fails the pre-pass too, and that is not pedantry:
--- CanAccess(nil) is TRUE — nil is not a secret — so a spell row with no
--- totalAmount sails through a comparability check and then raises inside the
--- comparator with "attempt to compare nil with number". Refusing the whole sort
--- keeps the binary answer above honest, and the provider's order is a real
--- order rather than a degradation.
---
--- @param spells table
--- @return boolean  whether the list was sorted
local function sortSpellsIfLegal(spells)
    local Secrets = NS.Secrets
    if not (Secrets and Secrets.CanCompare) then return false end

    for i = 1, #spells do
        local amount = spells[i].totalAmount
        if amount == nil then return false end
        if not Secrets.CanCompare(amount) then return false end
    end

    table.sort(spells, function(a, b)
        return a.totalAmount > b.totalAmount
    end)
    return true
end

--- One "icon Spellname .... amount" line.
---
--- The left side is assembled with string.format, which is legal with secrets;
--- the right side is the amount itself, handed to the formatter and then to the
--- widget as whatever it comes back as. Nothing in between looks at it.
---
--- @param spell table
--- @param numberStyle string|nil
-- ---------------------------------------------------------------------------
-- THE SPELL LINE: A BAR, AND TWO FIXED NUMBER SLOTS
-- ---------------------------------------------------------------------------
--
-- A GameTooltip line is TEXT. `|T…|t` embeds a texture but carries no tint, and
-- there is no markup that colors one — so the first attempt was a run of block
-- glyphs (not in the game font, drew boxes) and the second was a run of `=`
-- (legible, and obviously not a bar).
--
-- The real thing is a WIDGET PER LINE, pooled and re-anchored per hover rather
-- than created per line. Each pooled entry is a carrier Frame holding three
-- things:
--
--   * a StatusBar spanning the line, wearing the window's own bar texture and
--     the player's class color, filled to amount/max;
--   * the AMOUNT, right-aligned in a fixed-width slot;
--   * the SHARE, right-aligned in a second fixed-width slot beside it.
--
-- WHY THE NUMBERS LEFT THE TOOLTIP'S OWN RIGHT COLUMN. AddDoubleLine right-aligns
-- one string, so "5.7M 36.5%" and "398.9K 2.1%" line up at their right edge and
-- nowhere else — the percent column zig-zags, because the amount before it is a
-- different width on every row. Two right-aligned FontStrings at FIXED PIXEL
-- OFFSETS are the only way to get two columns out of one line, and the font is
-- proportional so padding with spaces cannot substitute.
--
-- WHY A CARRIER RATHER THAN HANGING THEM OFF THE BAR. The bar is absent whenever
-- the values may not be divided (see below) and the NUMBERS MUST NOT BE. Hanging
-- them off the bar would delete the tooltip's entire content mid-pull, which is
-- the exact inversion of the rule: a restricted tooltip loses decoration, never
-- information. So the carrier is always shown and the bar inside it is not.
--
-- GEOMETRY MATCHES THE GRID. A line spans from just past the icon out to the
-- tooltip's right margin, and the FILL inside it is amount/max, exactly like a
-- cell in modules/Row.lua. Every line's track is therefore the same length and
-- the fills are what differ — which is the only way a length can mean anything.
-- It starts past the icon so the icon reads as its own column and is not tinted,
-- and the spell NAME sits fully inside the track.
--
-- LAYERING. The carrier and the bar sit at the tooltip's OWN frame level, which
-- makes their draw layers interleave with the tooltip's rather than stack above
-- them. Track is BACKGROUND, fill is BORDER, GameTooltip draws its line
-- FontStrings in ARTWORK, and the two number slots are OVERLAY. So the spell name
-- lands on top of the bar and the numbers land on top of everything.
--
-- Everything comes down whenever the tooltip does — see `ensureTooltipHook` — so
-- a stale line can never outlive the hover that drew it.

--- The line height a bar has to cover. The icon is the tallest thing on a spell
--- line, so it sets the height; anything shorter leaves the line's text hanging
--- off the top and bottom of its own bar.
local BAR_HEIGHT = TOOLTIP_ICON_SIZE

--- Fallback fill for a window with no bar texture configured. A StatusBar with
--- no texture draws NOTHING, so the tint alone is not enough.
local BAR_FALLBACK_TEXTURE = "Interface\\Buttons\\WHITE8X8"

--- How far past the left FontString's edge the track starts.
---
--- The spell icon is not a separate widget — it is a `|T…|t` escape INSIDE the
--- left line, so the FontString's left edge is the icon's left edge. A track
--- pinned there runs underneath the icon and tints it. Clearing exactly the icon
--- puts the track's edge in the space between icon and name, which leaves the
--- NAME fully inside the bar — the point of a full-width bar in the first place.
local BAR_INSET_LEFT = TOOLTIP_ICON_SIZE

--- The two number slots, in pixels, measured in from the line's right edge.
---
--- FIXED, and never measured off a widget. A slot sized from the text it holds
--- would have to read a FontString that has been handed a meter amount, and a
--- widget that has held a secret has secret geometry (rule R3). Fixed slots also
--- happen to be the requirement: they are what makes the column a column.
---
--- SHARE_SLOT_WIDTH is a FLOOR rather than the whole answer. It was sized for
--- "xx.x%" on the reasoning that a share cannot exceed 100% and so cannot get
--- wider — which is wrong twice over: `Format.Percent` renders "%.1f%%", so a
--- full share is "100.0%" at SIX glyphs, and the tooltip font is configurable,
--- so any fixed pixel count clips at a large enough size. A capped row showed as
--- "100...." on screen. The drawn width is measured per font by `shareSlotWidth`
--- and this is what a client that refuses the measurement falls back to.
local SLOT_RIGHT_PAD    = 3
local SHARE_SLOT_WIDTH  = 44
local SLOT_GAP          = 6
local AMOUNT_SLOT_WIDTH = 66

--- The widest share there is, and therefore what the share slot must hold.
local SHARE_WIDEST = "100.0%"


--- Where a target's name starts inside its carrier.
---
--- The carrier's left edge already sits one icon past the line's left edge
--- (BAR_INSET_LEFT), and a spell name additionally clears the single space in
--- its own format string. This is that space, so a target name and a spell name
--- share an x.
local LABEL_INSET_LEFT = 4

--- How many characters of spell name the tooltip reserves room for.
---
--- DELIBERATELY NOT A SETTING, and deliberately not the grid's own
--- `Const.NAME_COLUMN_WIDTH`. The window's name column holds a player name and
--- this holds a spell name, which is a much longer thing — "Fury of the Storm
--- Elemental" does not fit where "Traxex" does — so the two are sized apart on
--- purpose and neither should drift into the other.
local NAME_COLUMN_CHARS = 25

-- THE DEATH TOOLTIP'S OWN COLUMNS, in characters, reserved exactly the way
-- NAME_COLUMN_CHARS is and for the same reason: a spell name and a caster name
-- are both resolved off ids the client can hand back SECRET, and measuring one
-- to size its column is the inspection rule R3 forbids. So each column is a
-- reservation at the configured font and the engine clips into it. Nothing here
-- cuts a string up — `string.sub` on a secret raises, and a truncation this code
-- performed would be an inspection besides.
local EVENT_SPELL_CHARS  = 22
-- A caster name is shorter than a spell name in nearly every case. Widened
-- again after 13 clipped "Grizzled Warbringer" a good deal earlier than the
-- column's own width suggested it would -- these are 'n' widths, and a name
-- full of wide glyphs runs out of room sooner than the reservation implies.
local EVENT_CASTER_CHARS = 16

-- The floor for the time column, and only the floor: the real width is measured
-- from the times actually in the recap being drawn. They are numbers this addon
-- computed, so measuring them is legal — unlike the names beside them.
local EVENT_TIME_WIDEST = "-9.9s"

-- The melee swing's own icon, the one Blizzard's recap uses. A swing carries no
-- spellId at all, so there is nothing to resolve one from.
local MELEE_ICON = 135274

-- inv_misc_bone_skull_03. Every line of a Deaths cell's tooltip is a death, so
-- they all wear the same icon — its job is to hold the column where every other
-- tooltip in the addon puts a spell icon, not to tell one row from another.
local DEATH_ICON = 237275

-- What separates "Death 3" from the caster and the spell that ended it. A bar
-- rather than a dash or a comma: both of the parts after it are NAMES, and both
-- can contain a dash or a comma of their own.
local DEATH_DETAIL_SEP = " | "

-- The widest a wall clock reads. The other two styles are shorter.
local DEATH_CLOCK_WIDEST = "00:00:00"

--- Rough width of one character, as a fraction of the font's point size.
---
--- A FALLBACK ONLY. The span above is measured properly on `measureText`; this
--- is what a client that refuses the measurement gets instead. 0.55 is a
--- middling ratio for the faces LSM ships, and it runs short on a narrow face —
--- which is survivable here and was not survivable when it sized a real name,
--- because the result is only ever a MINIMUM.
local NAME_WIDTH_PER_CHAR = 0.55

--- Breathing room between the name column and the amount slot.
local NAME_GAP = 10

--- What GameTooltip adds around its own content, left and right together. Used
--- only to widen the tooltip, never to place anything.
local TOOLTIP_H_PADDING = 20

--- The fallback for both number slots when no color is configured.
---
--- They used to be two constants — a gold amount and a white share — which read
--- as two kinds of number when they are one row's two figures. One color now,
--- and it is a setting.
local SLOT_COLOR_DEFAULT = { 1, 1, 1 }

local linePool = {}

-- ---------------------------------------------------------------------------
-- THE FONT, AND WHY IT HAS TO BE PUT BACK
-- ---------------------------------------------------------------------------
--
-- Our two number slots are our own FontStrings and may be set to anything. The
-- SPELL NAME is not: it is GameTooltipTextLeft<N>, which belongs to the SHARED
-- GameTooltip, and the tooltip is recycled by every addon and every unit, item
-- and quest hover in the game. A SetFont left on one is not a cosmetic leak —
-- it is this addon silently restyling somebody else's tooltip, and it survives
-- until a reload.
--
-- So every line index this hover wrote a font onto is recorded, and each one is
-- put back with SetFontObject("GameTooltipText") — the font object the real ones
-- inherit, which restores face, size and flags in one call rather than
-- reconstructing three values we would have had to read back off the widget.
--
-- `restoreFonts` runs from `releaseLines`, which is already wired to
-- GameTooltip's own OnHide — so it covers every route out of a hover, including
-- the ones that do not come back through this file.
local fontedLines = {}


--- What the font probe saw on the last spell line drawn, or nil.
---
--- Populated ONLY while the debug flag is on, and read by core/Diagnostics.lua.
--- It exists because "the spell name kept the game's font" has two completely
--- different causes — our SetFont was refused, or something after us put the font
--- back — and no screenshot can tell them apart. The probe samples the SAME
--- FontString twice, once immediately after we set it and once after
--- GameTooltip:Show() has laid the tooltip out, which is the only step between
--- the two that could revert it.
Tooltip.__fontProbe = nil

--- Give one tooltip line our font, and remember that we did.
---
--- The record keeps the font PER LINE rather than one font for the hover,
--- because they are not all the same: a section gap gets the same face at half
--- the size, and a single remembered font would have the post-layout pass stamp
--- full size back over it and quietly restore the gap this addon just halved.
local function applyLineFont(fontString, index, path, size, flags, shadowX, shadowY, textColor)
    if not (fontString and fontString.SetFont) then return end
    fontString:SetFont(path, size, flags)

    -- THE SPELL NAME IS TEXT INSIDE THE BAR, and the colour mode governs it. It
    -- is the tooltip's OWN FontString rather than one of ours -- the name is
    -- added through AddLine so the icon escape renders -- so it used to keep
    -- AddLine's white while the amount and the share beside it took the player's
    -- colour: one line, two colours, and the setting apparently working on half
    -- of it. Restored by restoreFonts with the face, for the same reason.
    if textColor and fontString.SetTextColor then
        fontString:SetTextColor(textColor[1], textColor[2], textColor[3])
    end
    -- THE SHADOW RIDES WITH THE FONT, and is recorded with it, because
    -- `reapplyFonts` runs after Show and would otherwise put back the face
    -- without the shadow the same setting asked for. Restated on every line for
    -- the reason the font is: GameTooltip is shared, and the line we are dressing
    -- may carry another addon's shadow.
    if fontString.SetShadowOffset then
        fontString:SetShadowOffset(shadowX or 0, shadowY or 0)
    end
    fontedLines[index] = { fs = fontString, path = path, size = size, flags = flags,
                           shadowX = shadowX or 0, shadowY = shadowY or 0,
                           recolored = textColor ~= nil }

    if State.debug and fontString.GetFont then
        local gotPath, gotSize, gotFlags = fontString:GetFont()
        Tooltip.__fontProbe = {
            index     = index,
            line      = fontString,
            askedPath = path, askedSize = size, askedFlags = flags,
            setPath   = gotPath, setSize = gotSize, setFlags = gotFlags,
        }
    end
end

--- Re-read the probed line after the tooltip has been shown and laid out.
local function sampleFontAfterShow()
    local probe = Tooltip.__fontProbe
    if not (probe and probe.line and probe.line.GetFont) then return end
    probe.showPath, probe.showSize, probe.showFlags = probe.line:GetFont()
end

--- Add the gap that separates one tooltip section from the next.
---
--- A blank AddLine is a WHOLE line of the tooltip's font, which is more air than
--- a section break needs — it read as a paragraph gap above "Spell breakdown"
--- and again above "Targets". There is no half-line in GameTooltip, but a line's
--- HEIGHT follows its font, so the spacer is given the configured font at half
--- size and takes half the room.
---
--- It goes through `applyLineFont` like every other line we touch, so it is
--- restored with them — a shrunken font left on a shared line is the same leak
--- as any other, and it would land on whatever the next addon puts there.
---
--- @param style table  a resolved style from `lineStyle`
local function addSectionGap(style)
    GameTooltip:AddLine(" ")
    local name = GameTooltip:GetName()
    local index = GameTooltip:NumLines()
    local left = name and _G[name .. "TextLeft" .. index]
    if not left then return end

    local half = math.floor((style.fontSize or 12) / 2)
    if half < 1 then half = 1 end
    applyLineFont(left, index, style.fontPath, half, style.fontFlags,
        style.shadowX, style.shadowY)
end

--- Put our font back on every line, AFTER GameTooltip:Show() has laid out.
---
--- ---------------------------------------------------------------------------
--- WHY THE FONT IS SET TWICE
--- ---------------------------------------------------------------------------
---
--- Setting it once, before Show, is the obvious thing and it does not hold. The
--- probe in `applyLineFont` measured it on a live client: the SetFont takes
--- (`asked 10/OUTLINE` reads back as `10/OUTLINE`), and after Show the SAME
--- FontString reads `11/no flags`. Something in the show path re-fonts the
--- tooltip's lines.
---
--- That something is very often not Blizzard: a UI skin that restyles
--- GameTooltip hooks OnShow and re-applies its own face to every line. On the
--- client this was measured on, the PATH survived and only the size and flags
--- changed — which is the signature of a skin re-applying the same font at its
--- own size, not of a reset to the stock font object.
---
--- So the first pass (in `drawLine`) is what makes the width measurement honest,
--- and this second pass is what the player actually sees. Show is NOT called
--- again afterwards: whatever re-fonts on show would simply run again and undo
--- this, and the tooltip is already sized — `applyMinimumWidth` ran before Show
--- and a smaller font only ever leaves slack.
local function reapplyFonts()
    for _, entry in pairs(fontedLines) do
        if entry.fs.SetFont then
            entry.fs:SetFont(entry.path, entry.size, entry.flags)
            if entry.fs.SetShadowOffset then
                entry.fs:SetShadowOffset(entry.shadowX, entry.shadowY)
            end
        end
    end
    sampleFontAfterShow()
end

--- Put every line this hover restyled back onto the game's own tooltip font.
local function restoreFonts()
    for index, entry in pairs(fontedLines) do
        local fontString = entry.fs
        if fontString.SetFontObject and _G.GameTooltipText then
            fontString:SetFontObject(_G.GameTooltipText)
        end
        -- The shadow goes back with the face. A font OBJECT does not carry one,
        -- so ours would otherwise stay on a shared line and turn up under the
        -- next addon's item tooltip -- the same class of leak as a bar left Shown.
        if fontString.SetShadowOffset then fontString:SetShadowOffset(0, 0) end
        -- And the colour, which a font OBJECT does not carry either. A line left
        -- in a class colour turns up under the next addon's item tooltip exactly
        -- as a left-behind shadow does.
        if entry.recolored and fontString.SetTextColor then
            fontString:SetTextColor(1, 1, 1)
        end
        fontedLines[index] = nil
    end
end

--- Take every line down, and put GameTooltip back the way it was found.
---
--- `pairs`, NOT `ipairs`. The pool is keyed by TOOLTIP LINE INDEX, and a spell
--- line is never line 1 — the header, the blank and the "Spell breakdown" caption
--- come first, so the first key is 4. `ipairs` stops at the hole at index 1 and
--- releases NOTHING, which is what left bars Shown on a recycled GameTooltip.
---
--- The bar is hidden alongside its carrier rather than left to the carrier's
--- visibility, so "is this bar showing" stays a question the widget itself can
--- answer.
---
--- The minimum width is cleared too. It is a property of the SHARED tooltip, so
--- leaving ours on it makes the next addon's item tooltip inexplicably wide —
--- the same class of bug as a bar left Shown.
local function releaseLines()
    -- The placement belongs to ONE hover. Left set, the next Show of a tooltip
    -- this addon did not build -- an item, a unit, a quest -- would re-anchor it
    -- to a cell of ours, which is the same class of leak as a bar left Shown.
    pendingPlacement = nil

    for _, frame in pairs(linePool) do
        frame.bar:Hide()
        frame:Hide()
    end
    restoreFonts()
    if _G.GameTooltip and GameTooltip.SetMinimumWidth then
        GameTooltip:SetMinimumWidth(0)
    end
    -- Line spacing belongs to the shared tooltip too, and a value left on it is
    -- the same class of bug as a bar left Shown: the next addon's item tooltip
    -- inherits our spacing for no reason it can discover.
    if _G.GameTooltip and GameTooltip.SetCustomLineSpacing then
        GameTooltip:SetCustomLineSpacing(0)
    end
    -- And the scale, for exactly the same reason and with more consequence: a
    -- tooltip left at 1.4 rescales the next quest text anybody hovers, anywhere
    -- in the UI, with nothing on screen to connect it to this addon.
    if _G.GameTooltip and GameTooltip.SetScale then
        GameTooltip:SetScale(1)
    end
end

-- ---------------------------------------------------------------------------
-- WHY THE LINES MUST COME DOWN WITH THE TOOLTIP
-- ---------------------------------------------------------------------------
--
-- GameTooltip is SHARED and RECYCLED. Hiding it does not un-Show the frames
-- parented to it — it only stops them being drawn — so a widget left Shown
-- reappears the instant anything else opens GameTooltip: a unit under the cursor,
-- an item, a quest. And because the lines are anchored to GameTooltipTextLeft<N>,
-- they re-anchor themselves onto WHATEVER that tooltip's lines now say, which is
-- how this addon put class-colored bars through the middle of a player's unit
-- tooltip and an item's stat block.
--
-- Releasing at the top of our own hovers is not enough: nothing routes another
-- addon's tooltip through this file. The only reliable signal is GameTooltip's
-- own OnHide, hooked once, for the life of the session.
local tooltipHooked = false

--- Hook GameTooltip:OnHide once, so the pool empties however the tooltip closes.
local function ensureTooltipHook()
    if tooltipHooked then return end
    local tip = _G.GameTooltip
    if not (tip and tip.HookScript) then return end
    tip:HookScript("OnHide", releaseLines)
    tooltipHooked = true
end

-- ---------------------------------------------------------------------------
-- Teardown
-- ---------------------------------------------------------------------------

--- Close whatever this module opened. Wired to every cell's OnLeave.
---
--- Unconditional rather than "hide it if we own it": GameTooltip is shared, and
--- a hide the addon did not need to do is invisible, whereas a tooltip left
--- pinned under the cursor after the mouse has moved is the single most
--- reported meter bug there is.
function Tooltip:Hide()
    -- Unconditionally, and BEFORE the hide: the OnHide hook covers every other
    -- route out, but only once a hover has opened a tooltip and installed it.
    releaseLines()
    if _G.GameTooltip then GameTooltip:Hide() end
end

-- ---------------------------------------------------------------------------
-- What the two siblings reach for
-- ---------------------------------------------------------------------------
--
-- The file-locals above that modules/Tooltip_Lines.lua and
-- modules/Tooltip_Builders.lua read. Published rather than copied, for the reason
-- every peel publishes rather than copies: a second COLLECT_LIMIT or a second
-- line pool is two things to keep in step, and the pool in particular has exactly
-- one correct number of instances -- one.
--
-- They are NOT API. Nothing outside these three files may read them, and both
-- siblings resolve them at FILE SCOPE, which is what makes their TOC positions
-- load-bearing.
local Internals = {}
NS.TooltipInternals = Internals
Internals.Perf = Perf
Internals.FALLBACK_ICON = FALLBACK_ICON
Internals.TARGET_ICON = TARGET_ICON
Internals.TOOLTIP_ICON_SIZE = TOOLTIP_ICON_SIZE
Internals.COLLECT_LIMIT = COLLECT_LIMIT
Internals.provider = provider
Internals.formatNumber = formatNumber
Internals.formatShare = formatShare
Internals.unreadable = unreadable
Internals.plainWord = plainWord
Internals.plainTruth = plainTruth
Internals.displayName = displayName
Internals.nameColor = nameColor
Internals.tooltipConfig = tooltipConfig
Internals.mediaPath = mediaPath
Internals.tooltipFont = tooltipFont
Internals.rgba = rgba
Internals.resolveWindow = resolveWindow
Internals.sessionTypeOf = sessionTypeOf
Internals.sessionIDOf = sessionIDOf
Internals.numberStyleOf = numberStyleOf
Internals.spellLineCap = spellLineCap
Internals.applyPlacement = applyPlacement
Internals.openTooltip = openTooltip
Internals.collectSpells = collectSpells
Internals.sortSpellsIfLegal = sortSpellsIfLegal
Internals.BAR_HEIGHT = BAR_HEIGHT
Internals.BAR_FALLBACK_TEXTURE = BAR_FALLBACK_TEXTURE
Internals.BAR_INSET_LEFT = BAR_INSET_LEFT
Internals.SLOT_RIGHT_PAD = SLOT_RIGHT_PAD
Internals.SHARE_SLOT_WIDTH = SHARE_SLOT_WIDTH
Internals.SLOT_GAP = SLOT_GAP
Internals.AMOUNT_SLOT_WIDTH = AMOUNT_SLOT_WIDTH
Internals.SHARE_WIDEST = SHARE_WIDEST
Internals.LABEL_INSET_LEFT = LABEL_INSET_LEFT
Internals.NAME_COLUMN_CHARS = NAME_COLUMN_CHARS
Internals.EVENT_SPELL_CHARS = EVENT_SPELL_CHARS
Internals.EVENT_CASTER_CHARS = EVENT_CASTER_CHARS
Internals.EVENT_TIME_WIDEST = EVENT_TIME_WIDEST
Internals.MELEE_ICON = MELEE_ICON
Internals.DEATH_ICON = DEATH_ICON
Internals.DEATH_DETAIL_SEP = DEATH_DETAIL_SEP
Internals.DEATH_CLOCK_WIDEST = DEATH_CLOCK_WIDEST
Internals.NAME_WIDTH_PER_CHAR = NAME_WIDTH_PER_CHAR
Internals.NAME_GAP = NAME_GAP
Internals.TOOLTIP_H_PADDING = TOOLTIP_H_PADDING
Internals.SLOT_COLOR_DEFAULT = SLOT_COLOR_DEFAULT
Internals.linePool = linePool
Internals.applyLineFont = applyLineFont
Internals.addSectionGap = addSectionGap
Internals.reapplyFonts = reapplyFonts
Internals.releaseLines = releaseLines
Internals.ensureTooltipHook = ensureTooltipHook
