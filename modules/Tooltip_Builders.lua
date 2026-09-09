-- modules/Tooltip_Builders.lua
--
-- WHAT A HOVER SAYS. The death events behind one death (issue #1), and the four
-- tooltips the primitives build: Targets -- which enemies this player hit, the
-- per-spell cell breakdown, the name tooltip that summarizes EVERY tracked
-- statistic for one player, and the spell row inside a breakdown.
--
-- WHY IT IS A SEPARATE FILE. modules/Tooltip.lua went past layout-§1's 1500-line
-- cap (issue #28). This is the part a feature adds to; the primitives it is built
-- out of are the part that must not be touched casually, and they stay behind in
-- modules/Tooltip.lua with the drawing machinery in modules/Tooltip_Lines.lua.
-- Everything here moved across unchanged, and hangs its four public methods --
-- `Tooltip:CellTooltip`, `:NameTooltip`, `:SpellTooltip` -- on the SAME module
-- table modules/Tooltip.lua builds. `Tooltip:Hide` stayed with the teardown.
--
-- THE SECRETS RULE STILL BINDS EVERY LINE, and binds it hardest here, because
-- this is where the instinct to say "just show the top five" and "put the total
-- at the bottom" lives. It is written out once, in modules/Tooltip.lua's header:
-- no arithmetic and no comparison on an amount, ordering only when NS.Secrets
-- says comparison is legal, counting through SafeCount and walking through
-- SafeIterate. Read it there before changing anything below.
--
-- TOC POSITION: modules/, after modules\Tooltip.lua AND after
-- modules\Tooltip_Lines.lua. LOAD-BEARING: every name in the block below is
-- resolved at FILE SCOPE off `NS.TooltipInternals`, and the second half of that
-- table is not filled until modules\Tooltip_Lines.lua has run.

local _, NS = ...

local Tooltip = NS.Tooltip
local L = NS.L
local Const = NS.Constants
local Compat = NS.Compat
local State = NS.State
local Debug = NS.Debug

-- The primitives modules/Tooltip.lua publishes, and the line machinery
-- modules/Tooltip_Lines.lua adds to the same table. FILE SCOPE, which is what
-- makes this file's TOC position load-bearing.
local I = NS.TooltipInternals
local Perf = I.Perf
local FALLBACK_ICON = I.FALLBACK_ICON
local TARGET_ICON = I.TARGET_ICON
local TOOLTIP_ICON_SIZE = I.TOOLTIP_ICON_SIZE
local COLLECT_LIMIT = I.COLLECT_LIMIT
local provider = I.provider
local formatNumber = I.formatNumber
local formatShare = I.formatShare
local unreadable = I.unreadable
local plainWord = I.plainWord
local plainTruth = I.plainTruth
local displayName = I.displayName
local nameColor = I.nameColor
local tooltipConfig = I.tooltipConfig
local resolveWindow = I.resolveWindow
local sessionTypeOf = I.sessionTypeOf
local sessionIDOf = I.sessionIDOf
local numberStyleOf = I.numberStyleOf
local spellLineCap = I.spellLineCap
local applyPlacement = I.applyPlacement
local openTooltip = I.openTooltip
local collectSpells = I.collectSpells
local sortSpellsIfLegal = I.sortSpellsIfLegal
local EVENT_SPELL_CHARS = I.EVENT_SPELL_CHARS
local EVENT_CASTER_CHARS = I.EVENT_CASTER_CHARS
local MELEE_ICON = I.MELEE_ICON
local DEATH_ICON = I.DEATH_ICON
local addSectionGap = I.addSectionGap
local reapplyFonts = I.reapplyFonts
local releaseLines = I.releaseLines
local lineWidget = I.lineWidget
local measureText = I.measureText
local charSpan = I.charSpan
local applyMinimumWidth = I.applyMinimumWidth
local applyDeathMinimumWidth = I.applyDeathMinimumWidth
local lineStyle = I.lineStyle
local drawLine = I.drawLine
local addSpellLine = I.addSpellLine
local MAX_DEATH_LINES = I.MAX_DEATH_LINES
local NO_CLOCK_TEXT = I.NO_CLOCK_TEXT
local deathClockOf = I.deathClockOf
local killingBlowOf = I.killingBlowOf
local deathLineLabel = I.deathLineLabel

-- ---------------------------------------------------------------------------
-- Death events (issue #1)
-- ---------------------------------------------------------------------------
--
-- One line per incoming event behind a death, drawn on the same carrier the
-- spell breakdown uses so fonts, borders, colours and the width machinery are
-- inherited rather than duplicated.
--
-- WHAT IS DIFFERENT FROM A SPELL LINE, and why each difference exists:
--
--   * the bar is HP REMAINING, not the amount. A death is read by watching a
--     health bar empty, and `currentHP` with the recap's own max is exactly that
--     — handed over raw so the WIDGET divides. Tainted code doing that division
--     itself is the thing rule R1 forbids.
--   * the caption carries a time and an attacker as well as a spell. Both extra
--     terms come off the event, both may be secret, and the join is therefore
--     ONE string.format rather than any `..`. This file has never concatenated
--     anything that could be secret and this is not where it starts.
--   * the amount slot is the damage alone. Overkill goes in the CAPTION instead,
--     because AMOUNT_SLOT_WIDTH is a fixed 66px with no per-font measurement and
--     "-787.3K (138.1K overkill)" would clip exactly the way "100.0%" once
--     clipped to "100....". Widening it would change every tooltip in the addon.

--- Seconds between an event and the death, as a negative number, or nil.
---
--- GATED, even though a live capture showed these fields plain in combat. A
--- subtraction is arithmetic, arithmetic on a secret raises, and "plain today"
--- is an observation about one build. A refused subtraction costs the time
--- prefix on one line; an ungated one costs the tooltip mid-pull.
---
--- @return number|nil
local function eventOffset(when, deathTime)
    if when == nil or deathTime == nil then return nil end
    local Secrets = NS.Secrets
    if not (Secrets and Secrets.CanCompare2 and Secrets.CanCompare2(when, deathTime)) then
        return nil
    end
    return when - deathTime
end

--- The event's own icon, off its spell id, or nil when there is not one.
---
--- Both the id and the client's texture lookup are optional: a melee swing has
--- no spell at all, and Compat is the only path to a texture that survives the
--- API moving between expansions. The caller supplies the fallback art.
---
--- @param spellID any|nil
--- @return string|number|nil
local function eventIcon(spellID)
    return (spellID ~= nil and Compat and Compat.GetSpellTexture)
        and Compat.GetSpellTexture(spellID) or nil
end

--- What to call an event the client did not name, and the icon that goes with it.
---
--- A MELEE SWING HAS NO SPELL AT ALL — no id, no name — so it fell through to
--- the "the client could not name this" placeholder and printed "#?", which
--- reads as a bug in the addon rather than as a melee hit. Blizzard's own
--- recap draws it as "Melee" with the weapon icon, and so does this.
---
--- Three arms, four namings, and no way out without one: a swing, a heal, and
--- a fall-through that shows a spell by id or, with no id at all, a bare
--- question mark. Every path returns a caption, because a line with an empty
--- spell slot reads as a drawing fault.
---
--- @param kind string|nil   the event type, already through plainWord
--- @param spellID any|nil
--- @param icon string|number|nil  the event's own icon, kept unless a swing
--- @return string name, string|number|nil icon
local function eventCaption(kind, spellID, icon)
    if kind == "SWING_DAMAGE" then
        return L["Melee"] or "Melee", icon or MELEE_ICON
    elseif kind == "SPELL_HEAL" or kind == "SPELL_PERIODIC_HEAL" then
        return L["Heal"] or "Heal", icon
    end
    -- A spell the client cannot name is shown by id rather than dropped,
    -- exactly as addSpellLine does it. The explicit nil branch is there
    -- because string.format("%s", nil) raises in Lua 5.1.
    return (spellID ~= nil) and string.format("#%s", spellID) or "#?", icon
end

--- One event's time column, sign and all, or "" when the offset was refused.
---
--- SPELLED WITH THE SIGN, not left to the subtraction. Every event precedes the
--- death, so the figure is zero or negative — and the killing blow's is exactly
--- zero, which `%.1f` renders as "0.0s" while the whole column reads in
--- negatives. "-0.0s" is the honest one: it says "at the moment of death", not
--- "zero seconds".
---
--- The drawn text and the measured text come through here together, so the
--- column can never be sized against a string it will not render.
---
--- @param secondsBefore number|nil  already gated; nil when it could not be computed
--- @return string
local function eventTimeText(secondsBefore)
    if secondsBefore == nil then return "" end
    if secondsBefore > 0 then
        return string.format("%.1fs", secondsBefore)
    end
    -- math.abs, not unary minus: negating a zero yields NEGATIVE zero, which
    -- "%.1f" renders as "-0.0" and the sign above then doubles into "--0.0s".
    return string.format("-%.1fs", math.abs(secondsBefore))
end

--- The three text columns of one event, plus the icon that heads its line.
---
--- SPLIT RATHER THAN COMPOSED. One string used to hold the time, the spell, the
--- caster and an overkill clause, so a long name pushed the numbers off the
--- right edge and the killing blow rendered as "355.8Kove…37.3%". Each part now
--- goes to its own reserved slot and the engine clips into it.
---
--- Nothing here joins two of them. A spell name and a caster name are both
--- resolved off ids the client can hand back secret, and `..` on a secret
--- raises where a widget setter takes one happily.
---
--- @param event table
--- @param secondsBefore number|nil  already gated; nil when it could not be computed
--- @return string icon, any timeText, any name, any caster
local function eventColumns(event, secondsBefore)
    local spellID = event.spellId
    local icon = eventIcon(spellID)

    -- The event type is read through `plainWord`, because it comes off a recap
    -- like everything else and comparing a secret string raises. Read for EVERY
    -- event, named or not: the read is a Secrets access, and moving it inside
    -- the unnamed branch would quietly change which events are asked about.
    local kind = plainWord(event.event)

    local name = event.spellName
    if name == nil then
        name, icon = eventCaption(kind, spellID, icon)
    end

    -- `hideCaster` may be a secret boolean, so it goes through plainTruth. An
    -- absent caster leaves the column EMPTY rather than collapsing it: the
    -- columns have to line up down the whole tooltip.
    local caster = event.sourceName
    if plainTruth(event.hideCaster) then caster = nil end

    local timeText = eventTimeText(secondsBefore)

    return string.format("|T%s:%d:%d:0:0|t", icon or FALLBACK_ICON,
        TOOLTIP_ICON_SIZE, TOOLTIP_ICON_SIZE), timeText, name, caster or ""
end

--- Draw one recap event.
---
--- NO OVERKILL. It is the part of a killing blow that exceeded health the player
--- no longer had, it appears on exactly one line out of ten, and on this surface
--- it was colliding with the HP percentage beside it. The figure is still in the
--- payload for anything that later wants it.
---
--- @param event table
--- @param deathTime any|nil   the newest event's timestamp
--- @param maxHealth any|nil   the recap's own max, for the bar
local function addEventLine(event, deathTime, maxHealth, numberStyle, style)
    local icon, timeText, name, caster =
        eventColumns(event, eventOffset(event.timestamp, deathTime))

    -- The tooltip's own line carries ONLY the icon. Everything else is on the
    -- carrier, in fixed slots, so the columns line up down the whole tooltip
    -- instead of ragging against names of a dozen different lengths.
    GameTooltip:AddLine(icon, 1, 1, 1)

    local index = GameTooltip:NumLines()
    drawLine(index,
        formatNumber(event.amount, numberStyle),
        formatShare(event.currentHP, maxHealth),
        event.currentHP, maxHealth, style, name, "event")

    local frame = lineWidget(index)
    frame.time:SetText(timeText)
    frame.caster:SetText(caster)
end

--- The wider of `widest` and ONE event's time cell, or `widest` when the offset
--- was refused.
---
--- The offsets are plain numbers this addon computed — the gate in `eventOffset`
--- guarantees it — so comparing and measuring them is legal where doing the same
--- to the names beside them would not be. The measured string comes out of
--- `eventTimeText`, the very call the drawn line uses, so the column can never be
--- sized against a string it will not render.
---
--- @return number|nil
local function widerTimeCell(event, deathTime, widest, path, size, flags)
    local off = eventOffset(event.timestamp, deathTime)
    if off == nil then return widest end
    local w = measureText(eventTimeText(off), path, size, flags)
    if w ~= nil and (widest == nil or w > widest) then return w end
    return widest
end

--- The spell and caster widths grown by ONE event — ALL OR NOTHING.
---
--- The third return is false the moment a caption cannot be read, and the caller
--- stops asking: the two widths mean nothing once it is false.
---
--- @return number spellW, number casterW, boolean readable
local function widerNameCells(event, spellW, casterW, path, size, flags)
    local name = plainWord(event.spellName)
    local caster = plainWord(event.sourceName)
    -- nil is fine on either — a swing has no spell name and plenty of
    -- events name no caster. What is NOT fine is a value that is there
    -- and may not be read, which is what plainWord answers nil for too,
    -- so the two are told apart by asking Secrets directly.
    if unreadable(event.spellName) or unreadable(event.sourceName) then
        return spellW, casterW, false
    end
    local sw = name and measureText(name, path, size, flags) or 0
    local cw = caster and measureText(caster, path, size, flags) or 0
    if sw and sw > spellW then spellW = sw end
    if cw and cw > casterW then casterW = cw end
    return spellW, casterW, true
end

--- Size the three event columns onto the style, before any line is drawn.
---
--- ONE WALK OF `ordered`, measuring the time cell and the two name cells of each
--- event together. This runs on the hover path, where a second pass over the same
--- array buys nothing but its own loop overhead.
---
--- The time column is sized from THIS recap's longest offset.
---
--- @param ordered table   the collected events, killing blow first
--- @param total number
--- @param deathTime any|nil  the killing blow's timestamp
--- @param style table    written in place
local function measureEventColumns(ordered, total, deathTime, style)
    local path, size, flags = style.fontPath, style.fontSize, style.fontFlags
    local widest, spellW, casterW = nil, 0, 0
    -- One unreadable caption abandons the whole measurement rather than sizing
    -- the column from the readable half — a column that fits four names out of
    -- ten is worse than one reserved for all of them. The time column is still
    -- measured over every event, which is why this only gates the names.
    local namesReadable = true

    for i = 1, total do
        local event = ordered[i]
        widest = widerTimeCell(event, deathTime, widest, path, size, flags)
        if namesReadable then
            spellW, casterW, namesReadable =
                widerNameCells(event, spellW, casterW, path, size, flags)
        end
    end

    style.eventTimeWidth = widest

    -- A couple of characters of air, so a name that exactly fills its column
    -- does not read as though it were clipped. Capped at the reservation, or
    -- shrinking to fit would become growing to fit and a forty-character boss
    -- ability would push the numbers off the edge.
    if namesReadable then
        local pad = charSpan(2, path, size, flags)
        style.eventSpellWidth  = math.min(spellW + pad, charSpan(EVENT_SPELL_CHARS, path, size, flags))
        style.eventCasterWidth = math.min(casterW + pad, charSpan(EVENT_CASTER_CHARS, path, size, flags))
    else
        style.eventSpellWidth, style.eventCasterWidth = nil, nil
    end
end

--- The recap's events as a plain array, newest first, capped at COLLECT_LIMIT.
---
--- SafeIterate — the only legal way to walk an array whose entries may be secret
--- — runs forwards, and `#` on the recap's own array is what rule R1 forbids, so
--- the cap lands DURING the forward walk. What survives it is therefore the
--- events nearest the death; capping after the reverse would keep the wrong end.
---
--- The per-entry gates skip with a bare `return`. `return false` would stop the
--- walk and drop every event sitting behind one junk entry.
---
--- @return table
local function collectEvents(Secrets, events)
    local ordered = {}
    Secrets.SafeIterate(events, function(_, event)
        if type(event) ~= "table" then return end
        if Secrets.CanAccessTable and not Secrets.CanAccessTable(event) then return end
        ordered[#ordered + 1] = event
        if #ordered >= COLLECT_LIMIT then return false end
    end)
    return ordered
end

--- Every event behind one death, oldest first.
---
--- REVERSED FROM THE CLIENT'S ORDER, which is newest first. The killing blow
--- reads as the last line for the same reason a story ends with its ending.
---
--- @return boolean  whether anything was drawn
local function drawDeathEvents(recap, numberStyle, style)
    local events = recap and recap.events
    if type(events) ~= "table" then return false end
    local Secrets = NS.Secrets
    if not (Secrets and Secrets.SafeIterate) then return false end
    if Secrets.CanAccessTable and not Secrets.CanAccessTable(events) then return false end

    -- Collected first, because the draw has to run backwards and the only legal
    -- walk runs forwards. See `collectEvents`.
    local ordered = collectEvents(Secrets, events)
    local total = #ordered
    if total == 0 then return false end

    -- Element one is the killing blow, so its timestamp is the moment of death
    -- and every other line is measured against it.
    local deathTime = ordered[1].timestamp
    local maxHealth = recap.maxHealth

    measureEventColumns(ordered, total, deathTime, style)

    for i = total, 1, -1 do
        addEventLine(ordered[i], deathTime, maxHealth, numberStyle, style)
    end
    return true
end

--- @param row table          a death drill-down row (needs .recapID)
--- @param style table        the line style every carrier is drawn with
--- @param numberStyle string|nil  the hovered window's abbreviation style
local function addDeathBreakdown(row, style, numberStyle)
    local P = NS.Provider
    local recap = (row.recapID ~= nil and P and P.GetRecap)
        and P.GetRecap(row.recapID) or nil

    -- THE HEADER IS NOT DECORATION; IT KEEPS A CARRIER OFF LINE 1.
    --
    -- drawLine fonts the tooltip line its carrier sits behind and records it, and
    -- restoreFonts puts SetFontObject(GameTooltipText) back on teardown. On a
    -- live client GameTooltipTextLeft1 inherits GameTooltipHeaderText, NOT
    -- GameTooltipText — so an event on line 1 would leave every GameTooltip in
    -- the game rendering its title in the small body font until the next
    -- /reload. The damage is to a shared FontString this addon does not own,
    -- which is why it outlives the hover and everything else here.
    --
    -- Every other caller already puts a header on line 1 for its own reasons,
    -- which is why releaseLines can claim "a spell line is never line 1" and why
    -- this never fired before. The death branch is the first path that would
    -- have started at the top.
    --
    -- It earns its place besides: the row says only "Death 3", so this is where
    -- a reader finds out whose death and when. Both terms go through one
    -- AddDoubleLine rather than any concatenation — `displayName` may be secret.
    local nr, ng, nb = nameColor(row)
    GameTooltip:AddDoubleLine(displayName(row),
        row.deathClock or L["Death recap"] or "Death recap",
        nr, ng, nb, 1, 0.82, 0)

    -- THE SAME GAP AND CAPTION EVERY OTHER SECTION IN THIS FILE GETS. Without
    -- them the header sat flush against the first bar, which nothing else here
    -- does, and the tooltip read as though a different addon had drawn it. The
    -- gap is also what keeps a carrier off line 1 with room to spare.
    addSectionGap(style)
    GameTooltip:AddLine(L["Death recap"] or "Death recap", 1, 0.82, 0)

    if not drawDeathEvents(recap, numberStyle, style) then
        -- A DEATH THE CLIENT NO LONGER HOLDS SAYS SO. An empty tooltip under the
        -- cursor reads as a broken addon; a sentence reads as a fact about the
        -- client, which is what it is.
        GameTooltip:AddLine(L["No recap stored for this death"] or
            "No recap stored for this death", 1, 0.82, 0)
        return
    end

    -- Reserved from CONFIG, never measured off a line that has held a recap
    -- value — the whole reason applyMinimumWidth exists. SpellTooltip has never
    -- needed it before because its other paths draw no carriers.
    applyDeathMinimumWidth(style)
end

--- The provider's per-spell detail for one player in one column, or nil when
--- there is nothing to read.
---
--- Every step is optional and any one of them missing means "no breakdown": the
--- module may not be loaded, the build may not have GetSourceDetail, the row may
--- be a placeholder with no GUID, and the API may hand back something that is
--- not a table. Answering nil for all four keeps the two builders free of the
--- same four-way guard.
---
--- @param window table|nil
--- @param statKey string
--- @param row table|nil
--- @return table|nil
local function sourceDetailFor(window, statKey, row)
    if not (row and row.guid) then return nil end

    -- TEST ROWS ANSWER FOR THEMSELVES. The provider has nothing to say about a
    -- `Test-N` guid — correctly, there is no such source — so asking it drew
    -- "No data yet" over a grid full of numbers, which reads as a broken tooltip
    -- rather than as placeholder data.
    local A = NS.Aggregator
    if A and A.TestSourceDetail then
        local test = A.TestSourceDetail(row.guid, statKey)
        if test then return test end
    end

    local P = provider()
    local source = P and P.GetSourceDetail
        and P:GetSourceDetail(sessionTypeOf(window), statKey, row.guid, nil, sessionIDOf(window))
    if type(source) ~= "table" then return nil end
    return source
end

--- Draw the "Deaths" section on a GRID cell: one line per death, newest first.
---
--- ISSUE #1'S FIRST COMPLAINT. This cell used to run the ordinary spell path,
--- which asks the provider for `combatSpells` on a Deaths source — there is no
--- spell list on a death row, so it rendered "No data yet": technically honest
--- and completely useless. A Deaths cell should never have been showing a spell
--- breakdown at all.
---
--- The lines are the same shape the drill-down's rows are, and deliberately so:
--- this tooltip is the INDEX into that list, so hovering and then clicking
--- shows the same deaths in the same order.
---
--- THE LINE NAMES THE KILLING BLOW where the client will say: "Death 3 | Ragnaros
--- | Sulfuras Smash". Both halves are optional and independently switchable
--- (Tooltip -> Contents), and both go missing on their own terms -- an
--- environmental death has no caster, a melee swing has no spell name, and a
--- restricted pull can withhold either. See killingBlowOf: what cannot be read
--- plainly is not drawn, and what remains is still a numbered death.
---
--- @param row table       an aggregated row (needs .deaths)
--- @param style table
--- @param timeStyle string|nil  the window's timestamp style
--- @param config table|nil      the tooltip config, for the two content switches
--- @return number  lines drawn
local function addDeathList(row, style, timeStyle, config)
    local deaths = row.deaths
    if type(deaths) ~= "table" or #deaths == 0 then return 0 end

    local P = provider()
    if not (P and P.GetRecap) then return 0 end

    addSectionGap(style)
    GameTooltip:AddLine(L["Deaths"], 1, 0.82, 0)

    local total = #deaths
    local drawn = 0
    for i = 1, total do
        local id = deaths[i]
        local clock, caster, spell
        if id ~= false and id ~= nil then
            -- ONE GetRecap FOR BOTH READS. It is memoized per id in
            -- modules/Provider.lua, so a second call would be free -- but the two
            -- facts come off the same event and asking twice invites them to
            -- disagree the day the memo is invalidated between the calls.
            --
            -- The offset falls back to the Current session for the reason
            -- modules/DrillDown.lua's copy records: Overall reports -1 for every
            -- death it holds, and Overall is what a window shows by default.
            local recap = P.GetRecap(id)
            clock = deathClockOf(recap, timeStyle)
            caster, spell = killingBlowOf(recap)
        end

        -- Numbered chronologically and listed newest first, exactly as
        -- modules/DrillDown.lua builds the rows this indexes. A reader who hovers
        -- and then clicks must see the same list twice.
        --
        GameTooltip:AddLine(string.format("|T%d:%d:%d:0:0|t %s", DEATH_ICON,
            TOOLTIP_ICON_SIZE, TOOLTIP_ICON_SIZE,
            deathLineLabel(total - i + 1, caster, spell, config)), 1, 1, 1)
        -- The time goes in the AMOUNT slot rather than the line, so the times
        -- line up in a column instead of ragging against names of two lengths.
        --
        -- PLAIN ONES FOR THE BAR, so it draws FULL. A death is not a quantity
        -- and there is nothing here to scale against, but an empty bar behind
        -- every line reads as a value that failed to load — so the bar is the
        -- row's backing, exactly as it is on a death row in the drill-down.
        drawLine(GameTooltip:NumLines(), clock or NO_CLOCK_TEXT, "", 1, 1, style, nil, "clock")
        drawn = drawn + 1
        if drawn >= MAX_DEATH_LINES then break end
    end
    return drawn
end

--- Draw the "Spell breakdown" section, and answer how many spell lines it drew.
---
--- The order is collect, then sort-if-legal, then draw: the sort is the one step
--- that may be refused mid-pull, and refusing it leaves the provider's own
--- ordering in place rather than degrading anything downstream of it.
---
--- @param source table       a DamageMeterCombatSessionSource
--- @param _statKey string     kept so the call site reads like its siblings; the
---   breakdown is drawn the same way for every column
--- @param cap number         the most lines this section may draw
--- @param numberStyle string|nil
--- @return number  lines drawn
local function addSpellBreakdown(source, _statKey, cap, numberStyle, style)
    local spells, spellTotal = collectSpells(source)
    sortSpellsIfLegal(spells)

    addSectionGap(style)
    GameTooltip:AddLine(L["Spell breakdown"], 1, 0.82, 0)

    -- The bars scale to the BIGGEST SPELL in this breakdown, not to the source's
    -- own maxAmount: a breakdown is read against itself — "which of my spells did
    -- the most" — and scaling to a column-wide max would leave every bar on a
    -- mediocre player's tooltip stubbed at one cell.
    --
    -- Taken after the sort, so it is the first entry when the sort was legal, and
    -- `source.maxAmount` when it was not. No comparison is performed here; drawLine
    -- refuses to fill on its own if the operands cannot be divided.
    local barMax = (spells[1] and spells[1].totalAmount) or source.maxAmount

    -- ONE LINE PER SPELL, on every column including this one. The avoidable
    -- breakdown used to tag each spell with a gray "Avoidable" / "Avoidable,
    -- Deadly" sub-line beneath its bar, and it was noise in the one place it
    -- appeared: EVERY spell in an Avoidable Damage breakdown is avoidable — the
    -- tooltip's own header says so — so the tag restated the column for each row
    -- while breaking the list into ragged, mismatched groups.
    local shown = 0
    for i = 1, #spells do
        if i > cap then break end
        addSpellLine(spells[i], numberStyle, barMax, style, source.totalAmount)
        shown = i
    end

    -- SafeCount answers how many rows the array really holds without ever
    -- applying `#` to it, which is what lets this line be honest about what was
    -- left out. A nil count means "we could not see the array", and then there
    -- is nothing truthful to say.
    if spellTotal and spellTotal > shown then
        GameTooltip:AddLine(string.format(L["and %d more"], spellTotal - shown), 0.6, 0.6, 0.6)
    end

    return shown
end

-- ---------------------------------------------------------------------------
-- Targets — which enemies this player hit
-- ---------------------------------------------------------------------------

--- The stat whose cells this section appears under. Damage only: "who did you
--- hit" is a question about damage dealt, and the same list under a Healing or
--- an Interrupts cell would be answering a question nobody asked of it.
local TARGET_STAT = "DamageDone"

--- Draw the "Targets" section, and answer how many lines it drew.
---
--- Everything hard about this lives in modules/Targets.lua, which either hands
--- back a list whose numbers are PLAIN — it refuses outright rather than sum
--- secrets — or hands back nil. So this function is ordinary: nil means no
--- section, and a list means the amounts may be formatted, divided and drawn
--- exactly like any other.
---
--- The bars scale to the biggest target rather than to the player's own total,
--- for the same reason the spell bars scale to the biggest spell: a breakdown is
--- read against itself.
---
--- @param row table
--- @param statKey string
--- @param config table
--- @param style table
--- @param numberStyle string|nil
--- @param window table|nil
--- @return number  lines drawn
local function addTargetBreakdown(row, statKey, config, style, numberStyle, window)
    if not config.showTargets then return 0 end
    if statKey ~= TARGET_STAT then return 0 end

    local T = NS.Targets
    if not (T and T.ForPlayer) then return 0 end

    local cap = config.maxTargets
    if type(cap) ~= "number" or cap < 1 then cap = 3 end

    local list = T.ForPlayer(window, row and row.name, cap)
    if not list then return 0 end

    local total = T.Total(list)
    local max = list[1] and list[1].total

    addSectionGap(style)
    GameTooltip:AddLine(L["Targets"], 1, 0.82, 0)

    for i = 1, #list do
        local entry = list[i]
        -- The tooltip line carries ONLY THE ICON, in the same `|T…|t` escape a
        -- spell line uses, so the target section lines up with the spell section
        -- above it column for column. The NAME is drawn on the carrier's own
        -- label slot, which is the only way to start it where a spell NAME starts
        -- rather than where a spell ICON starts. See `lineWidget`.
        GameTooltip:AddLine(string.format("|T%s:%d:%d:0:0|t",
            TARGET_ICON, TOOLTIP_ICON_SIZE, TOOLTIP_ICON_SIZE), 1, 1, 1)
        drawLine(GameTooltip:NumLines(),
            formatNumber(entry.total, numberStyle),
            formatShare(entry.total, total),
            entry.total, max, style,
            entry.name or L["Unknown"])
    end

    return #list
end

--- Tell the player that the Deaths column answers a click.
---
--- It is the one cell where clicking does something other than drill down, so
--- the tooltip says so rather than leaving the player to discover it.
local function addDeathRecapHint(row, statKey)
    if statKey ~= "Deaths" then return end
    if not row or row.deathRecapID == nil then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Click for details"], 0.6, 0.6, 0.6)
end

-- ---------------------------------------------------------------------------
-- Cell tooltip — the per-spell breakdown
-- ---------------------------------------------------------------------------

--- The hovered player's class colour, or nil when the row carries no class.
---
--- `classFilename` is NeverSecret, which is why this keeps answering mid-pull
--- when the bar LENGTHS cannot. A nil colour is a legitimate answer: it reaches
--- `lineStyle`, where `modeColor` with nothing to read leaves the CONFIGURED
--- colour standing.
---
--- @param row table|nil
--- @return table|nil
local function rowClassColor(row)
    local classes = _G.RAID_CLASS_COLORS
    return classes and row and row.classFilename and classes[row.classFilename] or nil
end

--- The player's death-clock format, from wherever it is actually kept.
---
--- The tooltip config block has NO copy of this key, so the hovered window's own
--- text block is the only path by which the player's setting reaches
--- Format.DeathTime.
---
--- @return string|nil
local function deathTimeFormatFor(config, window)
    return config.deathTimeFormat
        or (window and window.text and window.text.deathTimeFormat)
end

--- The breakdown lines behind one cell, and how many of them were drawn.
---
--- DEATHS TAKES ITS OWN PATH, and never the spell one. See addDeathList.
---
--- @param statKey string  the HOVERED column, not the sort column
--- @return number  lines drawn
local function addStatBreakdown(row, statKey, config, style, window)
    if statKey == "Deaths" then
        return addDeathList(row, style, deathTimeFormatFor(config, window), config)
    end
    local source = config.showSpells and sourceDetailFor(window, statKey, row)
    if not source then return 0 end
    return addSpellBreakdown(source, statKey, spellLineCap(config),
        numberStyleOf(window), style)
end

--- Show the spell breakdown behind one player's number in one column.
---
--- @param row table         the aggregated row under the cursor (needs .guid)
--- @param statKey string    a core/Constants.lua STATS key
--- @param anchorFrame table the cell frame the tooltip anchors to
--- @param window table|nil  the window config; looked up from row.windowId if
---                          omitted
function Tooltip:CellTooltip(row, statKey, anchorFrame, window)
    local t0 = Perf.on and debugprofilestop()

    window = resolveWindow(row, window)
    local config = tooltipConfig(window)
    -- Every line widget from the previous hover comes down first: they are pooled
    -- and re-anchored, so a stale one would otherwise sit behind a tooltip line it
    -- no longer describes.
    releaseLines()
    if not openTooltip(anchorFrame, config) then return end

    local stat = Const.STAT_BY_KEY[statKey]
    local nr, ng, nb = nameColor(row)
    GameTooltip:AddDoubleLine(displayName(row), stat and L[stat.label] or statKey,
        nr, ng, nb, 1, 0.82, 0)

    -- The bars wear the hovered player's class color, so a tooltip reads as
    -- belonging to the row it came off. See `rowClassColor`.
    local color = rowClassColor(row)
    -- THE HOVERED COLUMN, not the sort column: this tooltip is the breakdown of
    -- one statistic, and that statistic is the one whose cell the pointer is on.
    config.statKey = statKey or config.statKey
    local style = lineStyle(config, color)

    local shown = addStatBreakdown(row, statKey, config, style, window)

    if shown == 0 then
        GameTooltip:AddLine(L["No data yet"], 0.6, 0.6, 0.6)
    end

    addTargetBreakdown(row, statKey, config, style, numberStyleOf(window), window)

    addDeathRecapHint(row, statKey)

    -- After every line, before the Show that sizes the frame: the number slots are
    -- our widgets, so GameTooltip cannot size itself around them.
    applyMinimumWidth(style)

    GameTooltip:Show()
    -- AFTER Show, not before, and for the same reason twice over: the show path
    -- re-fonts the tooltip's lines AND re-anchors it to its owner. See
    -- `reapplyFonts` and `applyPlacement`.
    reapplyFonts()
    applyPlacement()

    if t0 then Perf.Note("tooltip", debugprofilestop() - t0) end
    -- BEHIND ITS OWN CHANNEL. A tooltip is rebuilt on every mouse-over and on
    -- every refresh the cursor sits through, so this line alone can fill a
    -- capped buffer and evict the pass somebody was reading. `/mm debug tooltip`.
    if State.debug and State.debugTooltip and Debug then
        Debug("Tooltip", "cell %s spells=%d", statKey, shown)
    end
end

-- ---------------------------------------------------------------------------
-- Name tooltip — every statistic for one player
-- ---------------------------------------------------------------------------

--- One statistic's color as three plain numbers, dimmed when the hovered window
--- has no column for it.
---
--- The catalog's palette, the same three numbers modules/Row.lua paints the bar
--- with. An unknown key answers a neutral rather than a tenth color, so a stat
--- added to the catalog without a palette entry renders plainly instead of
--- inventing a hue nothing else in the addon uses.
---
--- @param statKey string
--- @param shown boolean|nil  is this statistic a column in the hovered window
--- @return number, number, number
local function statColor(statKey, shown)
    -- Resolved to a local first: `f and f(x)` truncates to one value.
    local reader = NS.StatColor
    local cr, cg, cb
    if reader then cr, cg, cb = reader(statKey) end
    if not cr then
        if shown then return 1, 1, 1 end
        return 0.62, 0.62, 0.62
    end
    if shown then return cr, cg, cb end
    local dim = Const.STAT_DIM or 0.6
    return cr * dim, cg * dim, cb * dim
end

--- Which stats the hovered window has on screen, as a lookup.
---
--- Built per hover rather than cached: the column list is short, and holding a
--- cached copy would need invalidating on every column edit for no measurable
--- gain.
local function onScreenStats(window)
    local onScreen = {}
    if window and type(window.columns) == "table" then
        for i = 1, #window.columns do
            local column = window.columns[i]
            if type(column) == "table" and column.stat then onScreen[column.stat] = true end
        end
    end
    return onScreen
end

--- One line per tracked statistic, dimmed where the window is not showing that
--- column, and the count of lines drawn.
---
--- EVERY LINE WEARS ITS OWN STATISTIC'S COLOR, label and amount alike — the
--- configured palette (`NS.StatColor`), the same eight colors a bar takes
--- under `bars.colorMode == "stat"`, and it wears them WHATEVER that setting says.
--- This is the one place all eight statistics are on screen at once, so the color
--- is doing work here that it is only optionally doing on a bar: it is what ties
--- the "Healing" line in this list to the Healing column in the grid behind it.
--- The setting governs the BARS; this list is not a bar.
---
--- Stats the window does show are drawn in full color; the rest are dimmed — the
--- same hue at a lower level rather than a flat gray, so the two groups stay
--- distinguishable without a hidden statistic losing its identity.
---
--- One provider call per statistic. That is up to eight calls on a hover, and it
--- is the right trade: the totals live on the per-source read anyway, and
--- caching them would mean holding meter values across time — which is exactly
--- the thing this addon does not do.
---
--- `~= nil` is the only test applied to the amount; it then goes straight to the
--- formatter, which accepts a secret.
---
--- @param row table
--- @param window table|nil
--- @param numberStyle string|nil
--- @return number  lines drawn
local function addAllStatLines(row, window, numberStyle)
    local onScreen = onScreenStats(window)
    local rendered = 0

    for i = 1, #Const.STATS do
        local stat = Const.STATS[i]
        local source = sourceDetailFor(window, stat.key, row)
        if source and source.totalAmount ~= nil then
            -- BOTH SIDES IN THE SAME COLOR, so the line reads as one fact rather
            -- than as a colored name beside a neutral number.
            --
            -- Through AddDoubleLine's own color arguments and NOT through a
            -- `|cff…` escape on the string. Two reasons, and the second is the
            -- one that matters: an escape is a concatenation, and `formatNumber`
            -- may hand back a SECRET, which may not be concatenated. The tooltip
            -- applies the color arguments to whatever string it was handed,
            -- secret or not, so the same mechanism serves both sides of the line.
            local r, g, b = statColor(stat.key, onScreen[stat.key])
            GameTooltip:AddDoubleLine(L[stat.label],
                formatNumber(source.totalAmount, numberStyle), r, g, b, r, g, b)
            rendered = rendered + 1
        end
    end

    return rendered
end

--- Summarize EVERY tracked statistic for one player, including the columns this
--- window does not show.
---
--- Showing the hidden columns is the requirement, not an accident: the reason to
--- hover a name is to ask "what else did they do", and a summary limited to the
--- columns already on screen would answer nothing the grid has not answered
--- already.
---
--- @param row table
--- @param anchorFrame table
--- @param window table|nil
function Tooltip:NameTooltip(row, anchorFrame, window)
    local t0 = Perf.on and debugprofilestop()

    window = resolveWindow(row, window)
    local config = tooltipConfig(window)
    -- Every line widget from the previous hover comes down first: they are pooled
    -- and re-anchored, so a stale one would otherwise sit behind a tooltip line it
    -- no longer describes.
    releaseLines()
    if not openTooltip(anchorFrame, config) then return end

    GameTooltip:AddLine(displayName(row), nameColor(row))

    if not config.showAllStatsOnName then
        GameTooltip:Show()
        -- AFTER Show: the show path re-anchors the tooltip to its owner, so a
        -- point set before the lines were added is silently thrown away.
        applyPlacement()
        if t0 then Perf.Note("tooltip", debugprofilestop() - t0) end
        return
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["All statistics"], 1, 0.82, 0)

    local rendered = addAllStatLines(row, window, numberStyleOf(window))

    if rendered == 0 then
        GameTooltip:AddLine(L["No data yet"], 0.6, 0.6, 0.6)
    end

    GameTooltip:Show()
    -- AFTER Show: the show path re-anchors the tooltip to its owner, so a
    -- point set before the lines were added is silently thrown away.
    applyPlacement()

    if t0 then Perf.Note("tooltip", debugprofilestop() - t0) end
    if State.debug and State.debugTooltip and Debug then
        Debug("Tooltip", "name stats=%d", rendered)
    end
end

-- ---------------------------------------------------------------------------
-- Spell tooltip — a row inside a breakdown
-- ---------------------------------------------------------------------------

--- Show the GAME's own tooltip for the spell a drill-down row stands for.
---
--- The rows of a breakdown are spells, not players, and the two tooltips this
--- file otherwise builds both answer the wrong question about one. The cell
--- tooltip asks the provider for a spell breakdown OF a spell and renders "No
--- data yet"; the name tooltip lists every tracked statistic for a source that
--- is not a source and renders a column of zeros. Both are honest and both are
--- useless.
---
--- What a player wants there is the spell — what it does, what it costs, what it
--- scales with — and the client already renders that better than this addon
--- could. So the row hands GameTooltip a spell ID and gets out of the way.
---
--- EVERY CELL IN THE ROW, the name included. A breakdown row is one thing rather
--- than a grid of independent numbers, so hovering any part of it asks the same
--- question and must get the same answer.
---
--- @param row table         a drill-down row (needs .spellID)
--- @param anchorFrame table the cell frame the tooltip anchors to
--- @param window table|nil  the window config
function Tooltip:SpellTooltip(row, anchorFrame, window)
    local t0 = Perf.on and debugprofilestop()

    window = resolveWindow(row, window)
    local config = tooltipConfig(window)
    -- Our own line widgets come down first: this tooltip is the client's, and a
    -- pooled bar left over from a spell breakdown would sit behind its text.
    releaseLines()
    if not openTooltip(anchorFrame, config) then return end

    -- THE DEATH BRANCH GOES FIRST, above the spellID path and not below it.
    -- SetSpellByID replaces the tooltip's whole content, so a death row that
    -- happened to carry a spellID would silently render the client's spell page
    -- instead of the event list — a failure that looks like a design choice.
    -- KEYED ON THE ROW KIND, not on the id. A death the client gave no recap id
    -- for is still a death row, and falling through to the one-line name path
    -- would render "Death 2" and nothing else — indistinguishable from a tooltip
    -- that failed to build.
    if row and row.isDeath then
        -- The same class-colour resolution CellTooltip does. `classFilename` is
        -- NeverSecret, and a death row carries the drilled-into player's, so the
        -- bars stay that player's colour for the whole trip. A nil colour is a
        -- legitimate answer: drawLine falls back to grey.
        local classes = _G.RAID_CLASS_COLORS
        local color = classes and row.classFilename and classes[row.classFilename] or nil
        addDeathBreakdown(row, lineStyle(config, color), numberStyleOf(window))
        GameTooltip:Show()
        -- AFTER Show: the show path re-anchors the tooltip to its owner, so a
        -- point set before the lines were added is silently thrown away.
        applyPlacement()
        reapplyFonts()
        if t0 then Perf.Note("tooltip", debugprofilestop() - t0) end
        return
    end

    local spellID = row and row.spellID
    -- SetSpellByID replaces the tooltip's whole content, so it is the last word
    -- rather than something to add lines to.
    if spellID ~= nil and GameTooltip.SetSpellByID then
        local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)
        if ok then
            GameTooltip:Show()
            -- AFTER Show: the show path re-anchors the tooltip to its owner, so a
            -- point set before the lines were added is silently thrown away.
            applyPlacement()
            if t0 then Perf.Note("tooltip", debugprofilestop() - t0) end
            return
        end
    end

    -- No id, or a client that refused it. A one-line name beats an empty frame:
    -- the row is still telling the player which spell it is.
    GameTooltip:AddLine(displayName(row), 1, 1, 1)
    GameTooltip:Show()
    -- AFTER Show: the show path re-anchors the tooltip to its owner, so a
    -- point set before the lines were added is silently thrown away.
    applyPlacement()
    reapplyFonts()

    if t0 then Perf.Note("tooltip", debugprofilestop() - t0) end
end
