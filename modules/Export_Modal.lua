-- modules/Export_Modal.lua
--
-- The export modal: the dialog the header glyph and `/mm export` open, its three
-- selectors, the whisper row and the two action buttons. Every frame this feature
-- draws is here and nowhere else.
--
-- WHY IT IS A SEPARATE FILE. modules/Export.lua went over layout-§1's 1500-line
-- cap, and its own header had been naming the seam to cut on since it was written:
-- a pure half that serializes a segment and a UI half that asks the player what to
-- serialize. This is that UI half, moved across unchanged. The pure half keeps the
-- name modules/Export.lua and keeps the module table; this file only hangs the
-- modal off it.
--
-- The combat refusal the pure half's header describes is enforced here too, and
-- deliberately more than once: Export.Available() is asked when the modal opens,
-- again inside each click handler, and once more inside the serializers. The
-- restriction can activate while the modal sits open, so the click is the last
-- moment anyone can check.
--
-- TOC POSITION: modules/, immediately after modules\Export.lua. LOAD-BEARING: the
-- three publications at the bottom of that file (`Export.__EM_DASH`,
-- `Export.__cfgOf`, `Export.__channelRow`) are resolved below at FILE SCOPE, so a
-- position before it would resolve all three to nil for the life of the session.

local addonName, NS = ...

-- The pure half owns the table; this file only adds the modal to it. It is a
-- PLAIN TABLE on NS, like NS.Slash -- see modules/Export.lua for why.
local Export = NS.Export

local Const = NS.Constants
local L     = NS.L
local MSG   = Const.MSG

-- The modal's three selectors are LibKa0s-Widgets-1.0 dropdowns; see "The
-- modal's three selectors" below for why. Soft-optionaled like every other
-- LibKa0s seam this addon carries: `Export.Open` refuses rather than building a
-- modal with three dead controls when this is nil.
local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

-- Read by both halves of the peel and owned by the pure one; see "What
-- modules/Export_Modal.lua reaches for" at the bottom of modules/Export.lua. FILE
-- SCOPE, which is what makes this file's TOC position load-bearing.
local EM_DASH    = Export.__EM_DASH
local cfgOf      = Export.__cfgOf
local channelRow = Export.__channelRow

-- The choices the Lines selector offers. Not 1..40 in a spinner: the point of a
-- chat dump is that it is short, and five numbers are quicker to hit than a
-- slider. The last one is the aggregator's own ceiling rather than a literal 40,
-- so a change to MAX_ROWS moves both.
local LINE_CHOICES = { 3, 5, 10, 20, Const.MAX_ROWS }

-- ---------------------------------------------------------------------------
-- The profile seam
-- ---------------------------------------------------------------------------
--
-- Every choice the modal makes is remembered at `export.*` in the profile, so
-- the second export of an evening is one click. Writes go through
-- NS.SetByPath — the schema's single write seam — which logs the change,
-- announces CONFIG_CHANGED and keeps an open settings panel in step. Reads go
-- through NS.GetSetting for the same reason: it is the one place that knows how
-- a path resolves.
--
-- Both fall back to the profile table directly, and that fallback is NOT
-- decoration. SetByPath refuses a path it has no schema row for, and a degraded
-- or partially loaded install can reach this file with settings/Schema.lua
-- absent. The fallback is what makes the modal remember a choice anyway, for
-- the length of the session at worst.

local EXPORT_GROUP = "export"

--- Read one remembered export choice.
---
--- @param key string       the leaf name under `export.`
--- @param fallback any     what to answer when nothing is stored
--- @return any
local function readExport(key, fallback)
    if type(NS.GetSetting) == "function" then
        local v = NS.GetSetting(EXPORT_GROUP .. "." .. key)
        if v ~= nil then return v end
    end
    local db = NS.db
    local group = db and db.profile and db.profile[EXPORT_GROUP]
    local stored = group and group[key]
    if stored ~= nil then return stored end
    return fallback
end

--- Remember one export choice.
---
--- @param key string
--- @param value any
--- @return boolean  whether it was stored anywhere
local function writeExport(key, value)
    if type(NS.SetByPath) == "function" then
        if NS.SetByPath(EXPORT_GROUP .. "." .. key, value) then return true end
    end
    local db = NS.db
    if not (db and db.profile) then return false end
    local group = db.profile[EXPORT_GROUP]
    if type(group) ~= "table" then
        group = {}
        db.profile[EXPORT_GROUP] = group
    end
    group[key] = value
    return true
end

-- ---------------------------------------------------------------------------
-- Export modal
-- ---------------------------------------------------------------------------
--
-- Everything below needs a live client. It is built on the FIRST Open and reused
-- forever after: a modal rebuilt per click leaks a frame per click for the life
-- of the session, and frames are never destroyed in WoW.
--
-- Two frames rather than one. The modal picks what to export; the copy window
-- shows the result, at a higher strata so it sits ON TOP of the modal that
-- spawned it.
--
-- The copy window is LibKa0s-Widgets-1.0's now. It used to be a deliberate local
-- copy, and the comment here called itself "the third in the collection" — it
-- was the fourth. BankLedger had one too, and the register that was supposed to
-- be tracking them had never been written. Four copies of one frame is four
-- skins to keep in step, and the collection stops reading as one author's work
-- the first time one is restyled and the others are not.

local MODAL_NAME = "MultiMetersExportWindow"
local COPY_NAME  = "MultiMetersExportCopyWindow"

local ROW_H        = 24

-- The modal's vertical grid, as one table rather than as eight literals scattered
-- through EnsureFrame. It is published on the module (`Export.__geometry`) for the
-- one reason a private constant ever should be: the whisper row's arithmetic is
-- the thing that was wrong — a 20px box at -126 under a warning line at -154 in a
-- frame 236 tall that accounted for neither — and out of game the arithmetic is
-- all there is to check. The modal itself is smoke-tested.
local GEOM = {
    rowHeight         = ROW_H,
    rowGap            = 6,
    metricTop         = 36,
    channelTop        = 66,
    linesTop          = 96,
    whisperTop        = 126,
    warningTop        = 158,
    height            = 236,
}
GEOM.heightWithWhisper = GEOM.height + GEOM.rowHeight + GEOM.rowGap

Export.__geometry = GEOM

local MODAL_WIDTH  = 372
local MODAL_HEIGHT = GEOM.height
local COPY_WIDTH   = 640
local COPY_HEIGHT  = 420
local TITLEBAR_H   = 26
local EDIT_FALLBACK_WIDTH = 590

-- Built lazily, kept forever.
local modal, copyWindow

-- The window an Open was invoked from, and the choices the modal is currently
-- showing. Module-level rather than stored on the frame because the frame is
-- built once and reused for every window: whatever it was showing last time is
-- not what this Open is about.
local invoker

--- Is there a client to build frames on? Asked at CALL time, not captured, so
--- the headless harness loads this file with the whole UI half inert while the
--- pure half above stays reachable.
---
--- @return boolean
local function hasUI()
    return type(CreateFrame) == "function"
end

--- Read a color out of the shared skin, with a fallback per channel.
---
--- NS.SKIN degrades to an EMPTY TABLE rather than nil, so the index is always
--- safe; the fallbacks are for the degraded branch, where every field is absent
--- and a button still has to be visible.
---
--- @param key string
--- @param dr number
--- @param dg number
--- @param db number
--- @param da number
--- @return number, number, number, number
local function skinColor(key, dr, dg, db, da)
    local skin = NS.SKIN
    local c = type(skin) == "table" and skin[key] or nil
    if NS.RGBA then return NS.RGBA(c, dr, dg, db, da) end
    if type(c) ~= "table" then return dr, dg, db, da end
    return c[1] or dr, c[2] or dg, c[3] or db, c[4] or da
end

--- The dragging title bar both frames wear. Identical construction in both, so
--- it is one function: a strip across the top that moves the frame, a centered
--- caption, and the shared close button on the right.
---
--- The caption is stored as `frame.title` because that is the key NS.ApplySkin
--- looks for when it applies the skin's accent color — which is why the whole
--- bar is built BEFORE the skin goes on. Setting the title color here instead
--- would be this file deciding what the addon looks like.
---
--- @param frame table   the frame being titled
--- @param text string   the caption
--- @return table  the title bar
local function makeTitleBar(frame, text)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(TITLEBAR_H)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local caption = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    caption:SetPoint("CENTER")
    caption:SetText(text)
    frame.title = caption

    -- Two guards, not one: the helper may be absent on a degraded install, and
    -- it answers nil on a client with no CreateFrame. Anchoring is ours because
    -- the library hands the button back unanchored on purpose.
    if NS.MakeCloseButton then
        local close = NS.MakeCloseButton(bar, function() frame:Hide() end)
        if close then close:SetPoint("RIGHT", bar, "RIGHT", -6, 0) end
        frame.closeButton = close
    end

    return bar
end

--- A flat button in the addon's own colors.
---
--- The colors come out of NS.SKIN rather than being restated as literals here.
--- A hand-copied palette is a palette that drifts the first time the skin
--- changes, and it drifts silently — the button just stops matching.
---
--- @param parent table
--- @param text string
--- @param onClick function
--- @param icon string  optional. A LibKa0s-Media icon name drawn to the left of the label.
--- @return table  the button, with `.text` for later relabelling
local function makeButton(parent, text, onClick, icon)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetHeight(ROW_H)

    -- The flat 1px fill standalone-windows-§1 names for a Ka0s edge, hard-coded
    -- rather than fetched: it is a client primitive, not a mark, so it is not
    -- something LibKa0s-Media's catalog answers for (library-stack-§8). The
    -- whisper row below wears the same backdrop, and docs/ARCHITECTURE.md's
    -- "Hard-coded texture paths" census carries both sites as one row.
    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        button:SetBackdropColor(skinColor("bg", 0.1, 0.1, 0.12, 0.9))
        button:SetBackdropBorderColor(skinColor("innerBorder", 0.24, 0.24, 0.27, 0.9))
    end

    -- THE ICON IS BESIDE THE LABEL, NEVER INSTEAD OF IT. These two buttons are the
    -- only irreversible-ish things in the modal -- one opens a copy window, the
    -- other writes to a chat channel other people read -- and a mark alone would
    -- make "which one sends to guild?" a question answered by hovering. The label
    -- stays centred whether or not the art resolves, so a missing icon leaves the
    -- button exactly as it was rather than off-centre.
    local path = icon and NS.Icon and NS.Icon(icon)
    if path then
        local art = button:CreateTexture(nil, "OVERLAY")
        art:SetPoint("LEFT", button, "LEFT", 10, 0)
        art:SetSize(14, 14)
        art:SetTexture(path)
        art:SetVertexColor(1, 1, 1)
        button.icon = art
    end

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER")
    label:SetText(text)
    button.text = label

    button:SetScript("OnEnter", function()
        if button:IsEnabled() then label:SetTextColor(skinColor("title", 1, 0.82, 0)) end
    end)
    button:SetScript("OnLeave", function()
        label:SetTextColor(button:IsEnabled() and 1 or 0.4,
                           button:IsEnabled() and 1 or 0.4,
                           button:IsEnabled() and 1 or 0.4)
    end)
    button:SetScript("OnClick", onClick)

    return button
end

--- Grey a button out, or bring it back.
---
--- Both halves matter. The Disable is what makes the click do nothing; the color
--- is what tells the player why nothing happened before they click it a second
--- time.
---
--- @param button table|nil
--- @param enabled boolean
local function setEnabled(button, enabled)
    if not button then return end
    if enabled then
        button:Enable()
        if button.text then button.text:SetTextColor(1, 1, 1) end
    else
        button:Disable()
        if button.text then button.text:SetTextColor(0.4, 0.4, 0.4) end
    end
end

--- Put a frame over the meter window it was opened from.
---
--- Anchored to the window's ANCHOR, never to its visible frame. The visible
--- frame has held secret meter values, which makes its position data secret and
--- propagates that to anything anchored to it (rule R3); the anchor is the bare
--- invisible frame that exists precisely so there is something upstream of every
--- value to hang geometry off. Nothing is read back either way — SetPoint only
--- writes — but anchoring to the anchor keeps this frame outside the secret
--- graph entirely.
---
--- Re-applied on every open rather than once at build time, so the modal lands
--- over the window wherever the player has since dragged it.
---
--- @param frame table
--- @param win table|nil
local function centerOnWindow(frame, win)
    frame:ClearAllPoints()
    local target = type(win) == "table" and win.anchor or nil
    if target and target.IsShown and target:IsShown() then
        frame:SetPoint("CENTER", target, "CENTER", 0, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- The copy window belongs to LibKa0s-Widgets-1.0. What stays here is the
-- DESCRIPTOR: the frame's global name, the size, the face, the title, the skin
-- and the anchor — the things a vendored library cannot know about this addon.
-- The build is lazy inside the library, so a session that never exports creates
-- nothing.
--
-- The `scroll:GetWidth()` READ-BACK moved with the code it belongs to, and its
-- note moves with it, because rule R3 (docs/data-flow.md) otherwise forbids
-- reading geometry off a frame here. The exemption still applies and still for
-- the same reason: this frame can never hold a meter value — its EditBox holds a
-- plain CSV string, produced by a serializer that refuses to run at all while
-- values can be secret. The read now happens inside the library's `Show`, with
-- `editWidth` as the fallback for the first open, where the scroll frame has not
-- been laid out yet and answers 0.

--- Build the copy window handle, once.
---
--- @return table|nil  the handle, or nil with no client and no widget library
local function ensureCopyWindow()
    if copyWindow then return copyWindow end
    if not hasUI() then return nil end
    if not W or not W.CopyWindow then return nil end

    copyWindow = W.CopyWindow({
        addonName = addonName,
        name      = COPY_NAME,
        width     = COPY_WIDTH,
        height    = COPY_HEIGHT,
        title     = L["Export"] .. EM_DASH .. L["Ctrl+C, then Esc"],
        font      = Const.FONT_MONO,
        fontSize  = 10,
        editWidth = EDIT_FALLBACK_WIDTH,
        applySkin = NS.ApplySkin,
        -- Consulted on every show, so the popup lands over the window that
        -- spawned it wherever the user has since dragged it. The window's ANCHOR,
        -- never its visible frame: the visible frame has held secret meter values
        -- and anchoring to it would propagate that (rule R3), which is the same
        -- reasoning centerOnWindow above carries for the modal.
        anchorTo  = function()
            return type(invoker) == "table" and invoker.anchor or nil
        end,
    })

    -- Published for the suite the moment it exists, not at file load: an EditBox
    -- is write-only through the frame API as this module uses it, so the handle
    -- is the only seam from which a headless case can assert what the window is
    -- showing. Same reason as `Export.__geometry` above.
    Export.__copyWindow = copyWindow
    return copyWindow
end

--- Show text in the copy window, selected and ready for Ctrl+C.
---
--- The ORDER inside the window — width, text, cursor, show, focus, highlight —
--- is the library's now. It was load-bearing here and it is load-bearing there;
--- what changed is that it is written down once instead of four times.
---
--- @param text string
local function showCopy(text)
    local win = ensureCopyWindow()
    if not win then return end
    win:Show(text)
end

-- See ensureCopyWindow for why the pair is published.
Export.__showCopy = showCopy

-- ---------------------------------------------------------------------------
-- The modal's three selectors
-- ---------------------------------------------------------------------------
--
-- LibKa0s-Widgets-1.0 dropdowns, and this REVERSES what this file used to argue.
-- The old reasoning was that a dropdown of our own would be a second menu
-- vocabulary to keep in step with Blizzard's, so these were plain buttons opening
-- a MenuUtil context menu — the mechanism the window header's segment selector
-- still uses.
--
-- What changed is whose dropdown it is. It is not ours: it is the collection's,
-- shared with Bank Ledger's filter bar and specified by a suite in the library's
-- own repo. Against that, MenuUtil is the second vocabulary — a menu with
-- Blizzard's gold title and no selected-row mark, dropped from a button wearing
-- this addon's flat skin.
--
-- The header's segment selector is deliberately NOT converted here. It is a
-- different control in a different frame and its own change.

--- The label for a stat key, localized at the use site.
--- @param statKey string|nil
--- @return string
local function metricLabel(statKey)
    if statKey == nil then return L["Unknown"] end
    local stat = Const.STAT_BY_KEY[statKey]
    if not stat then return L["Unknown"] end
    return L[stat.label] or stat.label
end

--- Which stat the chat dump actually ranks by, right now.
---
--- The stored choice, when the catalog still answers for it. It always does on a
--- profile this build wrote: Export.Open SEEDS the invoking window's sort column
--- on the way in, so the selector shows a real stat before anyone has touched it.
---
--- The two fallbacks below are for the profiles that predate that. `""` was once
--- a deliberate choice meaning "match whichever column the window is sorted by",
--- and a build that offered a stat this one dropped leaves a key the catalog has
--- never heard of. Both read as unset, both land on the window's own column, and
--- neither needs a migration step — which is why there is not one.
---
--- Public and window-taking rather than a local reading the modal's `invoker`,
--- because a rule this easy to get wrong belongs where the harness can reach it;
--- the UI passes nothing and gets the window it was opened from.
---
--- @param win table|nil  a Window instance or config; the invoking window if nil
--- @return string  a key that Const.STAT_BY_KEY answers for
function Export.ResolveMetric(win)
    if win == Export then win = nil end

    local stored = readExport("metric", nil)
    if stored ~= nil and Const.STAT_BY_KEY[stored] then return stored end

    local data = cfgOf(win or invoker).data or {}
    local sortColumn = data.sortColumn
    if sortColumn and Const.STAT_BY_KEY[sortColumn] then return sortColumn end
    return Const.STATS[1].key
end

--- The label for a channel key, localized at the use site.
--- @param key string|nil
--- @return string
local function channelLabel(key)
    local row = channelRow(key)
    if row and row.label then return L[row.label] or row.label end
    -- No catalog (or a stored key it no longer lists): show the key itself
    -- rather than "Unknown", because the key is what the player will read back
    -- in the settings panel.
    return tostring(key)
end

--- Re-read every remembered choice and repaint the modal from it.
---
--- One function rather than a repaint at each write site: the whisper box
--- appearing, the two action buttons greying out and the three labels changing
--- are all one question — "what does the profile say now" — and splitting it is
--- how a modal ends up showing a channel it is not going to send on.
local function refreshModal()
    if not modal then return end

    local available, reason = Export.Available()
    local channel = readExport("channel", "SELF")

    -- Shows the RESOLVED stat even when the stored choice is "match the window",
    -- because the question the player is asking of this button is "what will it
    -- print", not "what is in my profile".
    modal.metricDD:SetValue(Export.ResolveMetric(),
        L["Metric: %s"]:format(metricLabel(Export.ResolveMetric())))
    modal.channelDD:SetValue(channel, L["Channel: %s"]:format(channelLabel(channel)))
    local lines = readExport("lines", 5)
    modal.linesDD:SetValue(lines, L["Lines: %s"]:format(tostring(lines)))

    local whispering = channel == "WHISPER"
    if whispering then
        modal.whisperBox:SetText(readExport("whisperTo", "") or "")
    end
    modal.whisperRow:SetShown(whispering)

    local warningTop = GEOM.warningTop + (whispering and (GEOM.rowHeight + GEOM.rowGap) or 0)
    modal.warning:ClearAllPoints()
    modal.warning:SetPoint("TOPLEFT", 16, -warningTop)
    modal.warning:SetPoint("TOPRIGHT", -16, -warningTop)
    modal:SetHeight(whispering and GEOM.heightWithWhisper or GEOM.height)

    modal.warning:SetText(available and "" or (reason or ""))
    setEnabled(modal.csvButton, available)
    setEnabled(modal.chatButton, available)
end

--- Store a choice and repaint.
--- @param key string
--- @param value any
local function chooseExport(key, value)
    writeExport(key, value)
    refreshModal()
end

--- The Metric selector's options: the catalog, in catalog order.
--- @return table
local function metricOptions()
    local out = {}
    for i, stat in ipairs(Const.STATS) do
        out[i] = { value = stat.key, label = L[stat.label] or stat.label }
    end
    return out
end

--- The Channel selector's options.
---
--- The catalog is core/Constants.lua's and only core/Constants.lua's. Restating
--- the channel list here would be two lists to keep in step, and the settings
--- panel reads the same one.
--- @return table
local function channelOptions()
    local out = {}
    for i, row in ipairs(Const.EXPORT_CHANNELS or {}) do
        out[i] = { value = row.key, label = L[row.label] or row.label }
    end
    return out
end

--- The Lines selector's options.
--- @return table
local function linesOptions()
    local out = {}
    for i, count in ipairs(LINE_CHOICES) do
        out[i] = { value = count, label = tostring(count) }
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The two actions
-- ---------------------------------------------------------------------------

--- Serialize the invoking window's segment and show it for copying.
---
--- The availability check is repeated here, at the click, and that repetition is
--- the point: the modal may have been opened out of combat and clicked ten
--- seconds into a pull, and the greyed-out button is a hint rather than a
--- guarantee.
local function onExportCsv()
    local available, reason = Export.Available()
    if not available then
        if NS.Print then NS.Print(reason) end
        refreshModal()
        return
    end

    local result = Export.Build(invoker)
    -- SAYING SO, rather than a button that swallows the click. A window showing
    -- "Waiting for combat data" has nothing to serialize, and a dialog that
    -- answers a press with nothing at all reads as broken rather than as empty.
    if not result or #result == 0 then
        if NS.Print then NS.Print(L["There is nothing to export."]) end
        return
    end
    showCopy((Export.CSV(result, Export.SessionLabel(invoker))))
end

--- Why this channel cannot reach anybody, or nil when it can.
---
--- ASKED BEFORE THE AGGREGATOR IS. A whisper with nobody named resolves to "keep
--- it to yourself" inside ResolveChannel, which is the safe answer but a silent
--- one — the player asked for it to reach somebody. The same goes for the
--- channel that reads its recipient off the game: no target, or a target that
--- cannot be whispered, would resolve to the silent SELF as well. Both are
--- caught here, where there is still a name box on screen to point at, and
--- before Export.Build can answer "There is nothing to export." instead.
---
--- The target is asked at the click rather than at the open, because the answer
--- changes between opening the modal and pressing the button.
---
--- @param channel string      the chosen channel key
--- @param whisperTo any       the contents of the name box
--- @return string|nil         the sentence to print, or nil to carry on
local function recipientRefusal(channel, whisperTo)
    if channel == "WHISPER" and tostring(whisperTo):match("^%s*$") then
        return L["Enter a name to whisper to."]
    end
    if channel == "TARGET" then
        local _, noTarget = Export.TargetName()
        if noTarget then return noTarget end
    end
    return nil
end

--- Rank the chosen metric and put it where the player asked.
local function onPrintToChat()
    local available, reason = Export.Available()
    if not available then
        if NS.Print then NS.Print(reason) end
        refreshModal()
        return
    end

    local channel = readExport("channel", "SELF")
    local whisperTo = readExport("whisperTo", "")
    local noRecipient = recipientRefusal(channel, whisperTo)
    if noRecipient then
        if NS.Print then NS.Print(noRecipient) end
        return
    end

    local statKey = Export.ResolveMetric()
    -- Built with the metric as the SORT COLUMN, so "top 5 healing" is the top
    -- five healers rather than the top five damage dealers listed with their
    -- healing beside them.
    local result = Export.Build(invoker, statKey)
    if not result or #result == 0 then
        if NS.Print then NS.Print(L["There is nothing to export."]) end
        return
    end

    local lines = Export.ChatLines(result, statKey, readExport("lines", 5),
        Export.SessionLabel(invoker))

    -- SAID BEFORE THE SEND, not after, and only where it is actually true. Say
    -- and Yell out in the world have to leave inside this click (Export.Send's
    -- "Getting a dump past the server"), so the stagger that keeps a long dump
    -- whole is not available and the server may drop the tail. A player who sees
    -- four of their ten lines arrive deserves to know it was the flood rule and
    -- not the addon.
    local chatType = Export.ResolveChannel(channel, whisperTo)
    if Export.NeedsHardwareEvent(chatType) and #lines > Export.ChatBatch() and NS.Print then
        NS.Print(L["Say and Yell go out all at once outside instances, so the server may drop some of %d lines. Fewer lines, or a group channel, will arrive whole."]
            :format(#lines))
    end

    Export.Send(lines, channel, whisperTo)

    -- Confirmed only for a send that LEFT this client. On SELF the lines are
    -- themselves the confirmation, sitting in the chat frame, and a summary under
    -- them would be one line of noise per export.
    if channel ~= "SELF" and NS.Print then
        -- The header line is not a ranked row, so it is not counted.
        NS.Print(L["Exported %d rows to chat."]:format(math.max(#lines - 1, 0)))
    end
end

--- One of the modal's three selectors: a LibKa0s-Widgets-1.0 dropdown, full
--- modal width, anchored `top` px below the modal's top edge.
---
--- ART IS A PARAMETER, AND IT IS RESOLVED IN ONE PLACE. The widget is vendored
--- and cannot know which addon folder its copy sits in, so it takes no
--- dependency on LibKa0s-Media-1.0 and every texture it draws arrives through
--- `opts` (LibKa0s docs/api/Widgets/version-7-docs.md, "Why it takes no dependency on
--- LibKa0s-Media-1.0"). Resolving that at each call site is how three selectors
--- come to wear two skins the day one of them is restyled and the others are
--- missed; this function is the one place `NS.Icon` is asked on the widget's
--- behalf, and the geometry every selector shares lives here with it.
---
--- NO `glyphFont`, DELIBERATELY — not an oversight, and not a line to "fix".
--- None of this modal's options carries a `glyph`: metricOptions,
--- channelOptions and linesOptions each build `{ value =, label = }` and
--- nothing else, and the widget then draws no glyph column at all. `glyphFont`
--- is a PRECONDITION for an option that carries `glyph`, not decoration — and
--- it must be a MONOSPACE face (`Const.FONT_MONO` here), because a proportional
--- one has no such glyph and renders a box. If an option here ever grows one,
--- this is the single line that has to grow with it.
---
--- `NS.Icon` answers nil on a load with no LibKa0s-Media, which is exactly the
--- widget's own fallback: it draws Blizzard's arrow instead.
---
--- @param parent table   the modal
--- @param top number     px below the modal's top edge
--- @return table         the dropdown frame
local function makeSelector(parent, top)
    local dd = W.Dropdown(parent, MODAL_WIDTH - 32, { chevron = NS.Icon("chevron-down") })
    dd:SetHeight(GEOM.rowHeight)
    dd:SetPoint("TOPLEFT", 16, -top)
    dd:SetPoint("TOPRIGHT", -16, -top)
    return dd
end

--- Build the modal, once.
---
--- @return table|nil  the frame, or nil with no client
local function EnsureFrame()
    if modal then return modal end
    if not hasUI() then return nil end

    modal = CreateFrame("Frame", MODAL_NAME, UIParent, "BackdropTemplate")
    modal:SetSize(MODAL_WIDTH, MODAL_HEIGHT)
    modal:SetPoint("CENTER")
    -- DIALOG, which is BELOW the FULLSCREEN strata the shared dropdown menu puts
    -- its click-catcher on (FULLSCREEN_DIALOG for the menu itself, FULLSCREEN for
    -- the catcher beneath it — LibKa0s-Widgets-1.0's own popup, one instance
    -- shared by every dropdown in the process). That ordering is what lets a
    -- click outside an open selector menu close the menu instead of landing on
    -- the modal — and the copy window, also FULLSCREEN, still opens above this.
    modal:SetFrameStrata("DIALOG")
    modal:EnableMouse(true)
    modal:SetMovable(true)
    modal:SetClampedToScreen(true)

    makeTitleBar(modal, L["Export"])

    local metricDD = makeSelector(modal, GEOM.metricTop)
    metricDD:SetOptions(metricOptions())
    metricDD.onSelect = function(v) chooseExport("metric", v) end

    local channelDD = makeSelector(modal, GEOM.channelTop)
    channelDD:SetOptions(channelOptions())
    channelDD.onSelect = function(v) chooseExport("channel", v) end

    local linesDD = makeSelector(modal, GEOM.linesTop)
    linesDD:SetOptions(linesOptions())
    linesDD.onSelect = function(v) chooseExport("lines", v) end

    -- Shown only while the channel is WHISPER. Hidden rather than disabled: a
    -- greyed-out name box on a raid-channel export is a control asking to be
    -- filled in for no reason.
    --
    -- NOT InputBoxTemplate, and that is the fix rather than a preference. The
    -- template carries its own rounded, gold-edged art and its own text insets;
    -- beside three flat selectors it read as a control borrowed from another
    -- addon, and its insets are what clipped the name. This is the same backdrop
    -- the selectors above it wear, so the four rows are one column.
    local whisperRow = CreateFrame("Frame", nil, modal, "BackdropTemplate")
    whisperRow:SetHeight(GEOM.rowHeight)
    whisperRow:SetPoint("TOPLEFT", 16, -GEOM.whisperTop)
    whisperRow:SetPoint("TOPRIGHT", -16, -GEOM.whisperTop)
    if whisperRow.SetBackdrop then
        whisperRow:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        whisperRow:SetBackdropColor(skinColor("bg", 0.1, 0.1, 0.12, 0.9))
        whisperRow:SetBackdropBorderColor(skinColor("innerBorder", 0.24, 0.24, 0.27, 0.9))
    end

    -- The caption INSIDE the row, as a prefix, so this reads "Whisper to: …" in
    -- the same shape as "Metric: …" above it. It was a separate FontString above
    -- the box, in 12px of room the old layout did not actually have.
    local whisperCaption = whisperRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    whisperCaption:SetPoint("LEFT", 8, 0)
    whisperCaption:SetText(L["Whisper to:"] .. " ")
    whisperCaption:SetTextColor(skinColor("title", 1, 0.82, 0))

    local whisperBox = CreateFrame("EditBox", nil, whisperRow)
    whisperBox:SetPoint("LEFT", whisperCaption, "RIGHT", 2, 0)
    whisperBox:SetPoint("RIGHT", -8, 0)
    whisperBox:SetPoint("TOP", 0, 0)
    whisperBox:SetPoint("BOTTOM", 0, 0)
    whisperBox:SetFontObject("GameFontHighlightSmall")
    whisperBox:SetAutoFocus(false)
    whisperBox:SetScript("OnEnterPressed", function(self)
        chooseExport("whisperTo", self:GetText() or "")
        self:ClearFocus()
    end)
    -- Stored on focus loss as well as on Enter: nobody expects to have to press
    -- Enter in a name box before clicking the button right below it.
    whisperBox:SetScript("OnEditFocusLost", function(self)
        writeExport("whisperTo", self:GetText() or "")
    end)
    whisperBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local warning = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warning:SetPoint("TOPLEFT", 16, -GEOM.warningTop)
    warning:SetPoint("TOPRIGHT", -16, -GEOM.warningTop)
    warning:SetJustifyH("CENTER")
    warning:SetWordWrap(true)
    -- The one hand-set color in this file, and it is a state rather than a style:
    -- the sentence is a refusal, and the skin has no "this is refused" accent.
    warning:SetTextColor(0.9, 0.25, 0.25)

    -- A spreadsheet for the CSV and a speech bubble for chat: the two icons say
    -- WHERE the export lands, which is the only difference between these buttons.
    local csvButton = makeButton(modal, L["Export to CSV"], onExportCsv, "spreadsheet")
    csvButton:SetWidth(160)
    csvButton:SetPoint("BOTTOMLEFT", 16, 14)

    local chatButton = makeButton(modal, L["Print to Chat"], onPrintToChat, "chat")
    chatButton:SetWidth(160)
    chatButton:SetPoint("BOTTOMRIGHT", -16, 14)

    modal.metricDD   = metricDD
    modal.channelDD  = channelDD
    modal.linesDD    = linesDD
    modal.whisperBox = whisperBox
    modal.whisperRow = whisperRow
    modal.warning    = warning
    modal.csvButton  = csvButton
    modal.chatButton = chatButton

    NS.ApplySkin(modal)
    modal:Hide()

    -- The modal is in UISpecialFrames (below), so Escape hides it directly —
    -- never through onHide/a click handler this file controls. An open Metric,
    -- Channel or Lines menu is the shared LibKa0s-Widgets-1.0 popup: a
    -- process-wide singleton parented to UIParent at FULLSCREEN_DIALOG, not to
    -- this modal, so the modal's own Hide() does not reach it (see the
    -- FrameStrata comment above and LibKa0s docs/api/Widgets/version-7-docs.md, "Behavior a host
    -- must know"). Without this, Escape would leave the menu orphaned above the
    -- game with the modal that owned it already gone. CloseMenu() is a safe
    -- no-op when no dropdown here has ever opened the menu, or when it is
    -- already closed, so this needs no extra guard beyond W itself, which is
    -- already resolved as a file-local and nil on a degraded load.
    if W then
        modal:SetScript("OnHide", function() W.CloseMenu() end)
    end

    -- THE RESTRICTION ARRIVES WHILE THE MODAL IS OPEN, and that is the ordinary
    -- case rather than the exotic one: a player opens this between pulls and the
    -- tank pulls. Nothing else on screen would repaint it, so the two action
    -- buttons would sit lit above a serializer that has started refusing, and
    -- the warning line would stay blank until a click explained it.
    --
    -- The clicks re-check regardless (onExportCsv / onPrintToChat refuse on
    -- their own). This subscription is what makes the modal SAY so first, which
    -- is the difference between a dialog that looks broken and one that reads as
    -- the game's rule being enforced.
    --
    -- One private bus target, taken once with the frame it repaints, exactly as
    -- each window takes its own (modules/Window.lua). Nil on a degraded load
    -- with no AceEvent, where a modal that does not repaint is a cost worth
    -- paying over a modal that does not open.
    local bus = NS.NewBusTarget and NS.NewBusTarget()
    if bus and MSG then
        bus:RegisterMessage(MSG.RESTRICTION_CHANGED, function() refreshModal() end)
    end
    modal.bus = bus

    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, MODAL_NAME)
    end

    return modal
end

--- Show the export modal for one window.
---
--- Callable as `NS.Export:Open(win)` (what the header glyph does) and as
--- `NS.Export.Open(cfg)` (what the slash verb does). The sniff is the same one
--- Aggregator.Build uses, and it exists for the same reason: two call sites
--- written by different hands, neither of which should have to care.
---
--- Refuses to open at all while restricted, rather than opening a modal with two
--- dead buttons — the sentence in chat is the useful half of that interaction.
---
--- @param a table|nil  Export, or a Window instance / config
--- @param b table|nil  a Window instance / config when called with a colon
--- @return table|nil  the modal, or nil when it did not open
function Export.Open(a, b)
    local win = (a == Export) and b or a

    local available, reason = Export.Available()
    if not available then
        if NS.Print then NS.Print(reason) end
        return nil
    end

    invoker = win

    -- SPEC §10. No widget, no modal. Three labels that open nothing look like a
    -- broken addon; a sentence looks like a missing library, which is what it is.
    -- Same shape as the combat refusal above, for the same reason.
    if not W then
        if NS.Print then NS.Print(L["The export window needs LibKa0s."]) end
        return nil
    end

    local frame = EnsureFrame()
    if not frame then return nil end

    -- SEEDED, and this reverses a decision this file used to argue for. The old
    -- shape stored "" — "match whichever column the window is sorted by" — and
    -- resolved it fresh at every use, which meant the Metric button showed a
    -- label naming a rule instead of naming a stat. The rule was right and
    -- unreadable; seeding keeps the behaviour and puts the answer in the control.
    --
    -- It is also what makes the settings panel's "Default metric" row removable:
    -- a preference every open overwrites is a preference in name only.
    --
    -- Only from a column the catalog answers for. A window that has never been
    -- sorted leaves whatever was chosen last time, which is the better of the
    -- two wrong answers.
    local seed = (cfgOf(win).data or {}).sortColumn
    if seed and Const.STAT_BY_KEY[seed] then writeExport("metric", seed) end

    refreshModal()
    centerOnWindow(frame, win)
    frame:Show()

    return frame
end
