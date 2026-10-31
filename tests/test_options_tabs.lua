-- tests/test_options_tabs.lua
--
-- settings/OptionsSetup.lua through the drawn pages: the tab strips, the Master controls tab, the
-- Active window band, the shared timer and the Keybindings tab. Peeled out of
-- tests/test_options_panel.lua at this seam when that suite passed its re-check; a pure move, case
-- names unchanged. Loads straight after it, so the shared instance arrives in the same state.


local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue, assertFalse = T.assertEqual, T.assertTrue, T.assertFalse

-- The canvas frame name each page builds under. It dates from the years
-- `ctx.pageKey` was unset (see the `carries its page key` case in tests/test_options_panel.lua), when
-- reaching a page's ctx by key was not possible and no other case in this suite
-- should have been blocked behind that. The key resolves now; this stays as the
-- independent handle, so the cases below do not all rest on the one thing that
-- case exists to check.
local PANEL_NAME = {
    windows    = "MultiMetersWindowsPanel",
    general    = "MultiMetersGeneralPanel",
    profiles   = "MultiMetersProfilesPanel",
}

--- One page's ctx: through the library's own seam when it resolves, and by the
--- panel's frame name when it does not.
local function panelFor(inst, pageKey)
    local ctx = inst.NS.Helpers.__panelFor(pageKey)
    if ctx then return ctx end
    local name = PANEL_NAME[pageKey]
    for _, c in ipairs(inst.NS.Helpers.__panels()) do
        if c.panel and c.panel:GetName() == name then return c end
    end
    return nil
end

--- Show a page's panel, driving the genuine deferred first render.
local function showPage(inst, pageKey)
    local ctx = panelFor(inst, pageKey)
    assertTrue(ctx ~= nil, "no panel registered for the '" .. pageKey .. "' page")
    ctx.panel:Hide()
    ctx.panel:Show()
    return ctx
end

--- Show the Windows page on one of its entries (MultiMeters#55): the six window pages are entries of
--- it now, so a case that drove a sub-page drives its entry.
local function showSection(inst, key)
    local ctx = showPage(inst, "windows")
    assertTrue(inst.NS.Helpers.SelectSection(key), "the Windows page lists no entry " .. key)
    assertEqual(ctx.activeSection, key)
    return ctx
end

-- ---------------------------------------------------------------------------
-- Tabs
-- ---------------------------------------------------------------------------

-- Every page that draws a strip, and the tab it opens on. Profiles is absent because its widget
-- tree is AceConfigDialog's; Windows and Columns are here because they are tabbed too, through
-- their own bespoke builders rather than through RenderTabbedSchema.
local TABBED = {
    -- options-ui-§15: the General page's FIRST tab is `Master controls` in every
    -- Ka0s addon, so that "how do I turn this off, how do I make it smaller, how
    -- do I put it back" is one place under one name.
    general    = "Master controls",
    windows    = "General",
    frame      = "Size and position",
    header     = "Title bar",
    bars       = "Bar",
    tooltip    = "General",
    visibility = "Rules",
    columns    = "Columns",
}

-- The pages whose strip is ONE tab (options-ui-§13: a page with one section draws a one-tab
-- strip). Windows' General entry and, since item 020 merged its three tabs, Visibility's Rules.
local ONE_TAB = { windows = true, visibility = true }

test("Panel: every tabbed page opens on its first tab and draws a strip", function()
    -- red under: a page left on RenderSchema, or one whose renderer draws the strip after the
    -- rows so the band is reserved too late.
    local inst = T.load()
    local L = inst.NS.L
    for page, firstTab in pairs(TABBED) do
        local ctx = page == "general" and showPage(inst, page) or showSection(inst, page)
        assertEqual(ctx.activeTab, L[firstTab], page .. ": opens on its first tab")
        assertTrue(#(ctx.__tabKids or {}) >= (ONE_TAB[page] and 1 or 2), page .. ": drew a strip")
    end
end)

test("Panel: Profiles draws no strip", function()
    -- Its widget tree belongs to AceConfigDialog, which reuses it and re-reads the profile on
    -- every Open. A strip over that would be tabs this addon cannot fill.
    -- red under: adding profiles to the tabbed set for consistency's sake.
    local inst = T.load()
    local ctx = showPage(inst, "profiles")
    assertEqual(#(ctx.__tabKids or {}), 0)
end)

test("Panel: switching tabs re-renders without leaving the previous tab's widgets behind",
function()
    -- The Frame page's second tab is Quick style. Asserting on the TAB rather than on a child count is
    -- deliberate: a renderer that appended instead of clearing would still change the count, so
    -- a count assertion passes for the wrong reason. What proves the clear is that a widget from
    -- the tab we LEFT is gone.
    -- red under: rendering the new group without ClearScroll, which appends it under the old.
    local inst = T.load()
    local L = inst.NS.L
    local ctx = showSection(inst, "frame")

    local function labeled(name)
        for _, w in ipairs(ctx.scroll and ctx.scroll.children or {}) do
            for _, child in ipairs(w.children or {}) do
                if child.labelText == name then return true end
            end
        end
        return false
    end

    assertTrue(labeled(L["Lock window"]), "the Frame page did not open on Size and position")
    ctx.__tabKids[2]:__fire("OnClick")
    assertEqual(ctx.activeTab, L["Quick style"])
    assertTrue(labeled(L["Color mode (all surfaces)"]), "the Quick style tab did not render")
    assertFalse(labeled(L["Lock window"]), "the previous tab's widgets were left behind")
end)

test("Panel: the Master controls tab draws four pairs, Test mode beside Minimap button",
function()
    -- THE RENDERED LAYOUT, not the schema order the case in tests/test_schema.lua
    -- pins. The flow engine pairs rows two per line unless one opens a line, so
    -- which column a checkbox lands in is a property of every row above it -- and
    -- that is exactly what an assertion on the schema list cannot see.
    --
    -- [Minimap button] [Test mode] is the column order options-ui-§15 states, and BOTH
    -- halves are the composer's since compose minor 7: `minimapPath` emits the minimap row
    -- with `startsLine`, and Test mode drops its own when a minimap row was emitted. The
    -- reason for the order is that every addon has a button and only some have a test mode,
    -- so the always-present row takes column 1. This addon drew the pair the other way round
    -- while its minimap row was hand-written.
    -- red under: giving Test mode `startsLine` back, or inserting a row between the two.
    local inst = T.load()
    local L = inst.NS.L
    local ctx = showPage(inst, "general")
    assertEqual(ctx.activeTab, L["Master controls"])

    local lines = {}
    for _, w in ipairs(ctx.scroll and ctx.scroll.children or {}) do
        local cells = {}
        for _, child in ipairs(w.children or {}) do
            cells[#cells + 1] = child.labelText or child.text
        end
        if #cells > 0 then lines[#lines + 1] = table.concat(cells, " | ") end
    end

    assertEqual(table.concat(lines, "\n"), table.concat({
        L["Enable Multi Meters"] .. " | " .. L["General visibility"],
        L["Master scale"] .. " | " .. L["Master opacity"],
        L["Lock frame"] .. " | " .. L["Debug console"],
        L["Minimap button"] .. " | " .. L["Test mode"],
        L["Reset position"] .. " | " .. L["Reset all settings"],
    }, "\n"))
end)

test("Panel: the Master controls tab closes with the composer's two reset buttons", function()
    -- options-ui-§15 makes the two resets the tab's closing BUTTON PAIR rather than
    -- schema rows -- they are acts, not settings -- and the pair is drawn by the
    -- hook `H.MasterControls` HANDS BACK, so nine addons cannot end up with nine
    -- wordings of "reset everything". settings/General.lua wires that hook and nothing
    -- else: it used to add a sentence under the pair explaining that Reset position is
    -- per-window here, and that prose is gone at the owner's request.
    -- red under: dropping NS.MasterControlsAfterGroup from afterMaster, or keying
    -- the hook to a group name the schema does not use, which errors nowhere.
    local inst = T.load()
    local L = inst.NS.L
    local ctx = showPage(inst, "general")
    assertEqual(ctx.activeTab, L["Master controls"])

    local function textOnPage()
        local out = {}
        local function take(w)
            if w.labelText then out[#out + 1] = w.labelText end
            if w.text then out[#out + 1] = w.text end
        end
        for _, w in ipairs(ctx.scroll and ctx.scroll.children or {}) do
            take(w)
            for _, child in ipairs(w.children or {}) do take(child) end
        end
        return table.concat(out, "\n")
    end

    local said = textOnPage()
    assertTrue(said:find("Reset position", 1, true) ~= nil, "no Reset position button")
    assertTrue(said:find("Reset all settings", 1, true) ~= nil, "no Reset all settings button")
    assertTrue(said:find("selected on the Windows page", 1, true) == nil,
        "the explanatory paragraph under the pair was removed; nothing should restore it")
end)

test("Panel: the Statistic colors tab says where its colors are actually worn", function()
    -- A grid of eight swatches with no sentence over it reads as "the color of
    -- this statistic", full stop -- and a player who sets Damage to green, looks
    -- at a class-colored grid and sees nothing change has been misled by the
    -- page rather than by the setting. The note is drawn through the same
    -- afterGroup hook the General tab's two buttons use.
    -- red under: dropping the note, or keying it to the wrong tab, which would
    -- put it under the master enable instead.
    local inst = T.load()
    local L = inst.NS.L
    local ctx = showPage(inst, "general")

    -- `SetLabel` and `SetText` are two different setters on an AceGUI widget and
    -- land in two different fields: every schema row uses the first, and TextRow
    -- -- which is a Label, not a labeled control -- uses the second. Reading only
    -- one of them is how this case passes for the wrong reason.
    local function textOnPage()
        local out = {}
        local function take(w)
            if w.labelText then out[#out + 1] = w.labelText end
            if w.text then out[#out + 1] = w.text end
        end
        for _, w in ipairs(ctx.scroll and ctx.scroll.children or {}) do
            take(w)
            for _, child in ipairs(w.children or {}) do take(child) end
        end
        return table.concat(out, "\n")
    end

    local note = L["These colors are worn wherever an element's color mode is set to Per-statistic \226\128\148 a cell's bar and its background (Windows > Bars > Bar), the numbers on it (Windows > Bars > Text), and the column header strip (Windows > Columns > Column header). The name tooltip's all-statistics list always uses them, whatever those modes say."]
    assertTrue(textOnPage():find(note, 1, true) == nil,
        "the note is on the Master controls tab, which is not the tab it describes")

    -- The THIRD tab: Master controls, Behavior, then Statistic colors. It was the
    -- second until Merge pets and Refresh interval moved off Master controls onto a
    -- Behavior tab of their own.
    ctx.__tabKids[3]:__fire("OnClick")
    assertEqual(ctx.activeTab, L["Statistic colors"])
    assertTrue(textOnPage():find(note, 1, true) ~= nil,
        "the Statistic colors tab drew no note saying where its colors are worn")
end)

test("Panel: every Windows entry sits under the Active window band, and General has no second picker",
function()
    -- The banner is the ONLY picker (options-ui-§14). A page that kept its own would be a
    -- second writer of one piece of session state -- a synchronization problem invented by the
    -- design, which would then have to be solved forever.
    -- red under: leaving the Active window dropdown on the Windows page, or bannering only some
    -- of the sub-pages.
    local inst = T.load()
    local ENTRIES = { "windows", "frame", "header", "bars", "tooltip", "visibility", "columns" }
    for _, page in ipairs(ENTRIES) do
        local ctx = page == "general" and showPage(inst, page) or showSection(inst, page)
        assertTrue(ctx.__bannerHeight ~= nil and ctx.__bannerHeight > 0,
            page .. ": drew no banner")
    end

    -- The banner's own dropdown is parented into the chrome band, NOT added to the scroll, so
    -- anything still carrying this label INSIDE the scroll is the old picker surviving.
    local dropdowns = 0
    local ctx = showPage(inst, "windows")
    for _, w in ipairs(ctx.scroll and ctx.scroll.children or {}) do
        for _, child in ipairs(w.children or {}) do
            if child.type == "Dropdown" and child.labelText == inst.NS.L["Active window"] then
                dropdowns = dropdowns + 1
            end
        end
    end
    assertEqual(dropdowns, 0, "the Windows page kept its own picker")
end)

test("Panel: choosing a window in the banner retargets every page and keeps the tab", function()
    -- Comparing one surface across two windows is the reason to switch from a sub-page at all,
    -- so the tab is a property of the page and not of the window (options-ui-§14).
    -- red under: resetting activeTab on a structural refresh.
    local inst = T.load()
    assertTrue(inst.NS.WindowManager:Create("Second"))
    local list = inst.NS.Database.GetWindows()

    local ctx = showSection(inst, "bars")
    ctx.__tabKids[3]:__fire("OnClick")
    assertEqual(ctx.activeTab, inst.NS.L["Icons"])

    local banner = ctx.__bannerWidget
    banner:__fire("OnValueChanged", list[2].id)

    assertEqual(inst.NS.State.activeWindowId, list[2].id)
    assertEqual(ctx.activeTab, inst.NS.L["Icons"], "the tab survived the retarget")
end)

-- ---------------------------------------------------------------------------
-- The Reset all settings tooltip names Profiles -> Reset Profile
-- ---------------------------------------------------------------------------

-- options-ui-§12: the global reset IS a profile reset here (the descriptor
-- supplies resetProfile) and this addon ships a Profiles page, so the button's
-- tooltip SHOULD name the equivalence. The composer is the only writer of that
-- text; it picks the wording from the descriptor (LibKa0s-Options-1.0 minor 18),
-- and `profilesPage = true` is how the host says the page exists. Read the way
-- AttachTooltip shows it: the real button's OnEnter, GameTooltip:AddLine spied.
local RESET_ALL_TIP = "Reset the current profile to its defaults \226\128\148 the same thing "
    .. "Profiles -> Reset Profile does. Your other profiles are not affected."

local function findButton(w, text, depth)
    depth = depth or 0
    if type(w) ~= "table" or depth > 8 then return nil end
    if w.text == text and w.callbacks then return w end
    for _, child in ipairs(w.children or {}) do
        local hit = findButton(child, text, depth + 1)
        if hit then return hit end
    end
    return nil
end

test("Panel: Reset all settings' tooltip says it is the same act as Profiles -> Reset Profile", function()
    -- red under: dropping the compose descriptor from settings/Schema_Compose.lua's
    -- __AttachCompose call, or its `profilesPage = true`.
    local inst = T.load()
    local ctx = showPage(inst, "general")
    assertEqual(ctx.activeTab, inst.NS.L["Master controls"])
    local btn = findButton(ctx.scroll, "Reset all settings")
    assertTrue(btn ~= nil, "the Master controls tab draws a Reset all settings button")
    assertTrue(btn.callbacks.OnEnter ~= nil, "the button carries a tooltip")

    local tip, lines = inst.mocks.GameTooltip, {}
    local saved = rawget(tip, "AddLine")
    rawset(tip, "AddLine", function(_, text) lines[#lines + 1] = text end)
    local ok, err = pcall(btn.callbacks.OnEnter)
    rawset(tip, "AddLine", saved)
    assertTrue(ok, tostring(err))
    assertEqual(#lines, 1, "one tooltip body line")
    assertEqual(lines[1], RESET_ALL_TIP)
end)

-- The color picker's drag throttle and the slider's live commit run through the
-- descriptor's scheduleTimer. From LibKa0s-Options-1.0 24.31.x (OptionsWidgets
-- minor 31) the library keeps its own armed flag and never reads the return, so a
-- plain C_Timer.After wrapper is the whole contract. The library's throttle is
-- pinned by LibKa0s's own test_options_throttle and is not repeated (testing-§8).
test("scheduleTimer schedules once through C_Timer.After with the given delay", function()
    -- red under: a scheduleTimer that switches to NewTimer, schedules twice, drops
    -- the delay, or starts returning a handle some future edit expects to be used.
    local inst = T.load()
    local calls, handle = {}, {}
    local saved = inst.mocks.C_Timer.After
    inst.mocks.C_Timer.After = function(delay, fn)
        calls[#calls + 1] = { delay = delay, fn = fn }
        return handle
    end
    local fn = function() end
    local ok, ret = pcall(inst.NS.OptionsDescriptor.scheduleTimer, fn, 0.05)
    inst.mocks.C_Timer.After = saved
    assertTrue(ok, tostring(ret))
    assertEqual(#calls, 1, "one C_Timer.After call per scheduleTimer")
    assertEqual(calls[1].delay, 0.05)
    assertTrue(calls[1].fn == fn, "the callback is handed through unwrapped")
    assertEqual(ret, nil, "the return is unused by the library (OptionsWidgets minor 31); "
        .. "nothing here may start depending on a handle")
end)

-- ---------------------------------------------------------------------------
-- The Keybindings tab (options-ui-§20, LibKa0s v1.77.0's O.KeybindingsTab)
-- ---------------------------------------------------------------------------
--
-- The General page's LAST tab, drawn by the library from NS.BINDINGS (core/LauncherSetup.lua,
-- launcher-§6). What is this addon's, and asserted here, is the wiring: the tab is there and last,
-- its rows are NS.BINDINGS in order, a row's label is the client's BINDING_NAME_ text, and a key set
-- on either surface is the one store's. Capture, slots, conflicts, sync debouncing and the
-- never-touches-SettingsPanel cases are the library's (LibKa0s tests/test_options_keybinds*.lua)
-- and are not repeated (testing-§8).
--
-- THE SHARED INSTANCE, because Kit.keybindThroughTab presses its key into the capture listener of
-- the library the harness exposed (T.mocks' LibStub); an isolated instance carries a library of
-- its own, whose listener the driver cannot reach. The kit's binding mock is installed on it once,
-- fill-only. Its GetBindingName reads the MOCK table, while this addon's labels land in the chunk
-- environment (`rawset(_G, ...)` in core/LauncherSetup.lua writes mocks._G), so the client's
-- answer -- the label the Keybindings page shows -- is restated over the environment first.

local KB_COMMAND = "CLICK MultiMetersToggleWindows:LeftButton"

local function bindingScene()
    local inst = { NS = T.NS, mocks = T.mocks }
    local M = inst.mocks
    if not M.__kbInstalled then
        M.GetBindingName = M.GetBindingName or function(command)
            local v = rawget(M._G, "BINDING_NAME_" .. tostring(command))
            if v ~= nil then return v end
            return command
        end
        dofile(T.root .. "/tests/_kit/mock_bindings.lua")(M)
        M.__kbInstalled = true
    end
    M.clearBindings()
    M.setRestricted(false)
    return inst
end

--- Show General and open its Keybindings tab, answering the ctx and the row records the library's
--- KeybindRows drew (captured off the instance member the tab's render calls).
local function openKeybindings(inst)
    local H = inst.NS.Helpers
    local ctx = showPage(inst, "general")
    local rows
    local real = H.KeybindRows
    H.KeybindRows = function(...)
        rows = real(...)
        return rows
    end
    local tab
    for _, kid in ipairs(ctx.__tabKids or {}) do
        if kid.__ka0sTabTipLabel == "Keybindings" then tab = kid end
    end
    assertTrue(tab ~= nil, "the General page draws no Keybindings tab")
    -- The shared instance may already be on the tab, and a click on the active tab draws nothing:
    -- leave for the first tab, then come back, so the rows are drawn now.
    local ok, err = pcall(function()
        ctx.__tabKids[1]:__fire("OnClick")
        tab:__fire("OnClick")
    end)
    H.KeybindRows = real
    assertTrue(ok, tostring(err))
    return ctx, rows
end

test("Keybindings: the General page's strip ends in a Keybindings tab, after every schema tab", function()
    -- options-ui-§20: the LAST tab of the General page, labeled exactly Keybindings, a host tab with
    -- no `before`; Master controls stays first (options-ui-§15).
    -- red under: no tab (the page passes no opts.tabs), a tab placed ahead of a schema tab, or a
    -- relabeled one.
    local inst = bindingScene()
    local L = inst.NS.L
    local ctx = showPage(inst, "general")
    local labels = {}
    -- The ledger also holds the strip's panel, which carries no tab label.
    for _, kid in ipairs(ctx.__tabKids or {}) do
        if kid.__ka0sTabTipLabel then labels[#labels + 1] = kid.__ka0sTabTipLabel end
    end
    assertEqual(table.concat(labels, " | "),
        table.concat({ L["Master controls"], L["Behavior"], L["Statistic colors"], "Skin",
            "Keybindings" }, " | "))
end)

test("Keybindings: the tab's rows are NS.BINDINGS in order, labeled with the BINDING_NAME_ globals", function()
    -- red under: a tab drawn from a second list of commands, or a row label of the addon's own
    -- rather than the text the client's Keybindings page shows for the action.
    local inst = bindingScene()
    local ctx, rows = openKeybindings(inst)
    assertEqual(ctx.activeTab, "Keybindings")
    assertTrue(type(rows) == "table", "the tab drew no rows")
    assertEqual(#rows, #inst.NS.BINDINGS)
    for i, b in ipairs(inst.NS.BINDINGS) do
        assertEqual(rows[i].command, b.command)
        assertEqual(rows[i].label.text, rawget(inst.mocks._G, "BINDING_NAME_" .. b.command))
    end
    assertEqual(rows[1].label.text, "Toggle meter windows")
end)

test("Keybindings: a key bound through the tab is the client's, and a key set elsewhere shows in the tab", function()
    -- One store, both surfaces (options-ui-§20): the tab writes SetBinding then SaveBindings to the
    -- set in force, and repaints on UPDATE_BINDINGS when Options -> Keybindings (here, a plain
    -- SetBinding) changes a key. The row is ONE key button and Clear (OptionsKeybinds minor 4, the
    -- owner's follow-up to 015): a second key set on the client's page is counted on that button
    -- ("K +1"), never drawn as a second slot.
    -- red under: a tab that keeps its own key (GetBindingKey never answers it), one that caches
    -- the key it drew, or a row that still draws a second key slot.
    local inst = bindingScene()
    local M = inst.mocks
    local _, rows = openKeybindings(inst)
    assertEqual(rows[1].slots[2], nil, "the row draws a second key slot")
    assertTrue(rows[1].clear ~= nil, "the row has no Clear button")
    T.keybindThroughTab(rows[1], 1, "K")
    assertEqual(M.GetBindingKey(KB_COMMAND), "K")
    assertEqual(M.__savedBindingSets[#M.__savedBindingSets], M.GetCurrentBindingSet())

    -- Options -> Keybindings sets a second key. The client fires UPDATE_BINDINGS at the frame
    -- registered for it; the library registers through Core's SafeRegisterEvent, which the kit's
    -- recorder does not survey, so the event is delivered to that frame once its registration is
    -- confirmed (it is registered only while a row is on screen).
    local lib = M.LibStub("LibKa0s-Options-1.0")
    local f = lib.__keybindEventFrame
    M.SetBinding("F7", KB_COMMAND)
    assertEqual(rows[1].slots[1].text, "K", "the tab repainted before any event")
    assertTrue(f ~= nil and f:IsEventRegistered("UPDATE_BINDINGS"),
        "the tab does not hear UPDATE_BINDINGS while its row is on screen")
    f:GetScript("OnEvent")(f, "UPDATE_BINDINGS")
    if M.__flushTimers then M.__flushTimers() end
    assertEqual(rows[1].slots[1].text, "K +1", "the tab did not count the second key after UPDATE_BINDINGS")
    M.clearBindings()
end)

test("Keybindings: the tab refuses to bind a key in combat", function()
    -- options-ui-§20: no key is bound, cleared or saved in combat.
    -- red under: a host editor of the addon's own that skips the library's combat lock.
    local inst = bindingScene()
    local M = inst.mocks
    local _, rows = openKeybindings(inst)
    M.setRestricted(true)
    local ok, outcome = pcall(T.keybindThroughTab, rows[1], 1, "K")
    M.setRestricted(false)
    assertTrue(ok, tostring(outcome))
    assertEqual(outcome, "Key bindings can be changed after combat.")
    assertEqual(M.GetBindingKey(KB_COMMAND), nil, "a key was bound in combat")
    assertEqual(#M.__bindingWrites, 0, "SetBinding ran in combat")
end)

test("Keybindings: the General page's Defaults tooltip ends with the library's keys-unchanged sentence", function()
    -- options-ui-§20 (SHOULD): Defaults and Reset all settings never reach a key, and the Defaults
    -- button says so before it is clicked, in the library's own words (O.KEYBINDS_UNCHANGED).
    -- red under: no defaultsTooltip on the General page, or a host rewording of the sentence.
    local inst = T.load()
    local ctx = panelFor(inst, "general")
    local tip = ctx.panel.defaultsTooltip
    assertEqual(type(tip), "string", "the General page's Defaults button has no tooltip")
    local tail = inst.NS.Helpers.KEYBINDS_UNCHANGED
    assertEqual(tail, "Key bindings are not changed.")
    assertEqual(tip:sub(-#tail), tail)
end)
