-- tests/test_windows_rail.lua
--
-- The Windows page as one page per window (MultiMeters#55): the Active window band, the nav rail
-- (General, Frame, Header, Bars, Tooltip, Visibility, Columns), each entry's own tab strip, the tab
-- each entry keeps, the Columns reorder cancel on a rail switch, and Defaults for the active entry.
-- The pattern is AuraMaster's Containers page (#6) on LibKa0s v1.61.0's O.NavRail. Pinned from the
-- outside: a fresh instance per case, the page shown the way Blizzard shows it, the rail clicked
-- through the library's own entry buttons.

local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue, assertFalse = T.assertEqual, T.assertTrue, T.assertFalse

local RAIL_ORDER = "windows,frame,header,bars,tooltip,visibility,columns"

--- A fresh instance with spies on the three chrome calls, recording each page's last rail and strip,
--- and handles on its Windows page. `opts` goes to T.load.
local function env(opts)
    local inst = T.load(opts)
    local H = inst.NS.Helpers
    local rails, strips, calls = {}, {}, {}
    local navRail, tabStrip, pageBanner = H.NavRail, H.TabStrip, H.PageBanner
    H.NavRail = function(ctx, spec, ...)
        calls[#calls + 1] = "NavRail"
        rails[ctx] = spec
        return navRail(ctx, spec, ...)
    end
    H.TabStrip = function(ctx, spec, ...)
        calls[#calls + 1] = "TabStrip"
        strips[ctx] = spec
        return tabStrip(ctx, spec, ...)
    end
    H.PageBanner = function(ctx, spec, ...)
        calls[#calls + 1] = "PageBanner"
        return pageBanner(ctx, spec, ...)
    end

    local P = { inst = inst, NS = inst.NS, L = inst.NS.L, calls = calls }

    function P.ctx() return H.__panelFor("windows") end

    --- Show the Windows page the way Blizzard does, driving the genuine deferred render.
    function P.show()
        local ctx = P.ctx()
        assertTrue(ctx ~= nil, "no Windows page registered")
        ctx.panel:Hide()
        ctx.panel:Show()
        -- The render is pcall'd by the library, so a raise shows up as no rail, not as an error.
        assertTrue(rails[ctx] ~= nil, "the Windows page drew no rail (its renderer raised)")
        return ctx
    end

    function P.railKeys()
        local out = {}
        for i, e in ipairs((rails[P.ctx()] or {}).entries or {}) do out[i] = e.key end
        return table.concat(out, ",")
    end

    function P.railValue() return (rails[P.ctx()] or {}).value end

    function P.tabLabels()
        local out = {}
        for i, t in ipairs((strips[P.ctx()] or {}).tabs or {}) do out[i] = t.label end
        return table.concat(out, "|")
    end

    --- The library's own rail button for entry `key` (ctx.__railKids is the rail's ledger, in order).
    function P.railButton(key)
        local ctx = P.ctx()
        for i, e in ipairs((rails[ctx] or {}).entries or {}) do
            if e.key == key then return ctx.__railKids[i] end
        end
        error("the rail drew no entry " .. tostring(key), 2)
    end

    --- Click rail entry `key` the way the player does, and answer the page's ctx.
    function P.rail(key)
        local ctx = P.ctx()
        P.railButton(key):__fire("OnClick")
        ctx.panel:Hide()
        ctx.panel:Show()
        return ctx
    end

    return P
end

--- The groups of a page key's rows, in declaration order: the strip RenderTabbedSchema draws.
local function groupsOf(NS, page)
    local out, seen = {}, {}
    for _, row in ipairs(NS.SchemaForPage(page, NS.State and NS.State.activeWindowId)) do
        if row.group and not seen[row.group] then
            seen[row.group] = true
            out[#out + 1] = row.group
        end
    end
    return table.concat(out, "|")
end

--- Whether any widget under `root` is a `wtype` carrying `text` as its label or its text.
local function has(root, wtype, text)
    for _, c in ipairs(root and root.children or {}) do
        if c.type == wtype and (c.text == text or c.labelText == text) then return true end
        if has(c, wtype, text) then return true end
    end
    return false
end

-- ── the registry ─────────────────────────────────────────────────────────────────────────────

test("Windows rail: the seven entries register under their page keys, on both builds", function()
    local L = T.NS.L
    local LABELS = {
        windows = "General", frame = "Frame", header = "Header", bars = "Bars",
        tooltip = "Tooltip", visibility = "Visibility", columns = "Columns",
    }
    local builds = { live = T.NS, ["library-absent"] = T.load{ libFiles = {} }.NS }
    for build, NSx in pairs(builds) do
        for key, label in pairs(LABELS) do
            -- red under: a page file registering no section, or the registry defined inside the
            -- live arm only (a library-absent load would lose it)
            local s = NSx.WindowSection and NSx.WindowSection(key)
            assertTrue(s ~= nil, build .. ": " .. key .. " registered no section")
            assertEqual(s.key, key, build .. ": " .. key .. " keeps its page key, so every row path is unchanged")
            assertEqual(s.label, L[label], build .. ": " .. key .. "'s rail label")
            assertEqual(type(s.tooltip), "string", build .. ": " .. key .. " carries a rail tooltip")
        end
    end
end)

-- ── the page ─────────────────────────────────────────────────────────────────────────────────

test("Windows rail: the band, then the rail General..Columns, 120 wide, opening on General", function()
    local P = env()
    local ctx = P.show()
    -- red under: the rail in TOC order, an entry missing, or the page opening on Frame
    assertEqual(P.railKeys(), RAIL_ORDER)
    assertEqual(ctx.activeSection, "windows", "the page opens on General (options-ui-§14)")
    assertEqual(P.railValue(), "windows")
    assertEqual(ctx.railWidth, 120)
    assertEqual(ctx.__bannerWidget and ctx.__bannerWidget.labelText, P.L["Active window"],
        "the band is the Active window picker")
end)

test("Windows rail: the draw order is PageBanner, NavRail, TabStrip", function()
    local P = env()
    P.show()
    -- red under: the rail drawn before the band (its top ignores the band) or after the strip (the
    -- strip places itself with no inset)
    assertEqual(table.concat({ P.calls[1], P.calls[2], P.calls[3] }, ","), "PageBanner,NavRail,TabStrip")
end)

test("Windows rail: General is one General tab holding the window's acts and a Copy settings from block", function()
    local P = env()
    local ctx = P.show()
    local L = P.L
    -- red under: the old Window / Copy from pair, or Copy from left on a tab of its own
    assertEqual(P.tabLabels(), L["General"])
    assertEqual(ctx.activeTab, L["General"])
    for _, b in ipairs({ "New window", "Duplicate window", "Delete window", "Copy" }) do
        assertTrue(has(ctx.scroll, "Button", L[b]), "General draws " .. b)
    end
    assertTrue(has(ctx.scroll, "EditBox", L["Window name"]), "General draws the name box")
    assertTrue(has(ctx.scroll, "Dropdown", L["Source window"]), "General draws the copy source")
    assertTrue(has(ctx.scroll, "Dropdown", L["Settings to copy"]), "General draws the group filter")
    assertTrue(has(ctx.scroll, "Heading", L["Copy settings from"]), "the copy block has its own heading")
    assertFalse(has(ctx.scroll, "Dropdown", L["Active window"]), "the band is the only picker")
end)

test("Windows rail: a rail click draws that entry's own strip under the same band", function()
    local P = env()
    P.show()
    local L = P.L
    local ctx = P.rail("bars")
    assertEqual(ctx.activeSection, "bars")
    assertEqual(P.railValue(), "bars")
    -- red under: the entry rendered under the page's own key (General's one tab, not Bars')
    assertEqual(P.tabLabels(), groupsOf(P.NS, "bars"))
    assertEqual(ctx.__bannerWidget.labelText, L["Active window"], "the band is drawn with the entry")
    P.rail("columns")
    assertEqual(P.tabLabels(), table.concat({ L["Columns"], L["Header text"], L["Header background"] }, "|"))
end)

test("Windows rail: each entry keeps its own tab, including one chosen by the library's own strip click", function()
    local P = env()
    P.show()
    local L = P.L
    local ctx = P.rail("frame")
    ctx.__tabKids[2]:__fire("OnClick")              -- the library's own strip click: no host render
    assertEqual(ctx.activeTab, L["Size and position"])
    P.rail("bars")
    assertEqual(ctx.activeTab, L["Bar"], "Bars opens on its first tab")
    ctx.__tabKids[3]:__fire("OnClick")
    assertEqual(ctx.activeTab, L["Border"])
    P.rail("frame")
    -- red under: one scalar activeTab for the page (Frame reopens on Border's slot or its first tab),
    -- or a stash only on host renders (the strip click above never reaches the host)
    assertEqual(ctx.activeTab, L["Size and position"])
    P.rail("columns")
    ctx.__tabKids[3]:__fire("OnClick")              -- Columns' own strip: a host render
    assertEqual(ctx.activeTab, L["Header background"])
    P.rail("windows")
    P.rail("bars")
    assertEqual(ctx.activeTab, L["Border"], "and through General")
    P.rail("columns")
    assertEqual(ctx.activeTab, L["Header background"])
end)

test("Windows rail: choosing another window in the band keeps the entry and its tab", function()
    local P = env()
    local NS, L = P.NS, P.L
    assertTrue(NS.WindowManager:Create("Second"))
    local list = NS.Database.GetWindows()
    P.show()
    local ctx = P.rail("bars")
    ctx.__tabKids[3]:__fire("OnClick")
    assertEqual(ctx.activeTab, L["Border"])
    ctx.__bannerWidget:__fire("OnValueChanged", list[2].id)
    assertEqual(NS.State.activeWindowId, list[2].id)
    -- red under: a window switch resetting the entry or the tab (options-ui-§14: the rail is not a picker)
    assertEqual(ctx.activeSection, "bars")
    assertEqual(ctx.activeTab, L["Border"])
    assertEqual(ctx.unit, list[2].id, "the page now edits the second window")
end)

-- Review Focus 1 (NR-MM-02).
test("Windows rail: leaving Columns on the rail mid-drag cancels the reorder BEFORE the scroll clear", function()
    local P = env()
    local inst, NS = P.inst, P.NS
    P.show()
    local ctx = P.rail("columns")
    -- The blocks are raw frames off the mock's creation register, newest first (tests/test_columns.lua).
    local frames, blocks = inst.mocks.__frames, {}
    for i = #frames, 1, -1 do
        local f = frames[i]
        if f.mmIndex and blocks[f.mmIndex] == nil then blocks[f.mmIndex] = f end
    end
    inst.mocks.setMouseDown("LeftButton", true)
    inst.mocks.setCursor(0, 1000)
    blocks[1].mmHandle:_run("OnMouseDown")
    assertTrue(ctx.mmReorder ~= nil, "the press left no live reorder to cancel")

    local order = {}
    local realCancel, realClear = NS.CancelReorder, NS.Helpers.ClearScroll
    NS.CancelReorder = function(c)
        order[#order + 1] = c.mmReorder and "cancel-live" or "cancel"
        return realCancel(c)
    end
    NS.Helpers.ClearScroll = function(c)
        order[#order + 1] = "clear"
        return realClear(c)
    end
    local button = P.railButton("frame")
    local ok, err = pcall(function() button:__fire("OnClick") end)
    NS.CancelReorder, NS.Helpers.ClearScroll = realCancel, realClear
    inst.mocks.setMouseDown("LeftButton", false)
    assertTrue(ok, tostring(err))

    assertEqual(ctx.activeSection, "frame", "the rail click did not switch entries")
    -- red under: the page renderer clearing the scroll before it cancels (a live handle handed to a
    -- pooled frame), or canceling only when the Columns entry is the one being drawn
    assertEqual(order[1], "cancel-live", "the first thing the switch did was not the cancel: " .. table.concat(order, ","))
    assertEqual(order[2], "clear", "no scroll clear followed the cancel: " .. table.concat(order, ","))
    assertTrue(ctx.mmReorder == nil, "the reorder controller survived the rail switch")
end)

-- Review Focus 2 (NR-MM-02).
test("Windows rail: Defaults restores the active entry's rows for the active window; General keeps the name; Columns restores both halves", function()
    local P = env()
    local NS, L, inst = P.NS, P.L, P.inst
    assertTrue(NS.WindowManager:Create("Second"))
    local w1, w2 = NS.Database.GetWindows()[1], NS.Database.GetWindows()[2]
    NS.State.SetActiveWindow(w1.id)
    assertTrue(NS.SetByPath("window.frame.width", 300, w2.id))
    assertTrue(NS.SetByPath("window.frame.width", 350, w1.id))
    assertTrue(NS.SetByPath("window.header.height", 30, w1.id))
    P.show()
    local ctx = P.rail("frame")

    ctx.panel.defaultsOnClick()
    -- red under: a click closure that fixed the entry at build time (General's nothing), or a walk
    -- over every entry's rows
    assertEqual(NS.Database.FindWindow(w1.id).frame.width, 694, "a Frame row is back")
    assertEqual(NS.Database.FindWindow(w1.id).header.height, 30, "a Header row is not a Frame row")
    assertEqual(NS.Database.FindWindow(w2.id).frame.width, 300, "only the active window")

    P.rail("windows")
    assertTrue(NS.WindowManager:Rename(NS.Database.FindWindow(w1.id).name, "Mine"))
    local before = #inst.mocks.__chat
    ctx.panel.defaultsOnClick()
    -- red under: General's Defaults walking the window.name row (the window renamed to "Multi Meters")
    assertEqual(NS.Database.FindWindow(w1.id).name, "Mine", "General keeps the window's name")
    local said = inst.mocks.__chat[#inst.mocks.__chat] or ""
    assertTrue(#inst.mocks.__chat > before
        and said:find(L["General has no settings to restore. The window's name is kept."], 1, true) ~= nil,
        "General says why nothing moved")

    P.rail("columns")
    local shipped = NS.DefaultWindow(w1.id).columns
    local scrambled = {}
    for i = #shipped, 1, -1 do
        scrambled[#scrambled + 1] = { stat = shipped[i].stat, enabled = i % 2 == 0 }
    end
    assertTrue(NS.SetByPath("window.columns", scrambled))
    assertTrue(NS.SetByPath("window.columnHeader.font", "Skurri"))
    ctx.panel.defaultsOnClick()
    local after = NS.Database.FindWindow(w1.id)
    for i, col in ipairs(shipped) do
        assertEqual(after.columns[i].stat, col.stat, "column " .. i .. " is the shipped statistic")
    end
    assertEqual(after.columnHeader.font, "Friz Quadrata TT", "and the header rows came back with it")
end)

test("Windows rail: the page offers one Defaults button whose tooltip fits every entry", function()
    local P = env()
    local ctx = P.show()
    assertTrue(ctx.panel.wantsDefaultsButton, "the Windows page offers Defaults since #55")
    assertEqual(ctx.panel.defaultsTooltip,
        P.L["Restore the active window's settings in the section on screen to their shipped values. On Columns that includes the shipped column list. General has nothing to restore: the window's name is kept."])
end)
