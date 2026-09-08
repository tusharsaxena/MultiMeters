-- tests/test_window.lua — modules/Window.lua: the two frames, the coalesced
-- refresh clock, and rule R3.
--
-- R3 is the reason this file has two frames instead of one: a StatusBar handed a
-- secret meter value is marked HasSecretValues, its POSITION data becomes secret
-- with it, and that propagates to anything anchored to it. So drag and resize
-- act on a bare anchor frame that never holds a value, and every other
-- coordinate is computed from config. The cases below prove that by POISONING
-- the getters — replacing GetWidth / GetHeight / GetLeft / GetPoint on the live
-- cells with functions that raise — and then driving a full refresh through
-- them. A read that crept back in is a failure with a stack trace, not a comment
-- somebody has to notice.
--
-- modules/Window.lua was peeled three ways, and so was this suite. The header
-- band — the title strip, the column-header buttons and the sort hand-off, the
-- segment selector — is proved in tests/test_window_header.lua; position, size,
-- the lock and the show ladder in tests/test_window_placement.lua. What stays
-- here is the refresh chain the other two hang off: the layout arithmetic, the
-- throttle, the row pool, the render loop and the scroll offset.
--
-- THE FIXTURE IS DUPLICATED, DELIBERATELY. `scene()` and the two lines of group
-- data under it are ~50 lines that all three files need; publishing them would
-- mean a fourth file that every suite loads and nobody proves anything about.
-- Copies stay copies: if one drifts, the case that depended on the drift is the
-- one that goes red.


local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse
local assertNil   = T.assertNil

local CURRENT = 1

local ALPHA = "Player-1-0000000A"
local BETA  = "Player-1-0000000B"

local GROUP = {
    { guid = ALPHA, name = "Alpha", class = "PALADIN", role = "TANK"    },
    { guid = BETA,  name = "Beta",  class = "PRIEST",  role = "HEALER"  },
}

local function src(guid, total, opts)
    opts = opts or {}
    return {
        sourceGUID      = guid,
        name            = opts.name or guid,
        classFilename   = opts.class or "MAGE",
        totalAmount     = total,
        amountPerSecond = opts.rate or 1,
    }
end

--- A loaded instance, a group, a session, and ONE live window instance whose
--- config has been made unconditionally visible and locked.
---
--- Locked matters: an unlocked window implies preview mode (a player
--- positioning a window at a target dummy needs a full grid), and preview data
--- never touches the provider — which would make every case below vacuous.
local function scene(opts)
    opts = opts or {}
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks

    mocks.setGroup(GROUP)
    NS.Roster.Refresh()
    mocks.setSession(CURRENT, "*", {
        combatSources = opts.sources or { src(ALPHA, 100), src(BETA, 50) },
        maxAmount     = 100,
        totalAmount   = 150,
    })
    mocks.setSessionDuration(CURRENT, 212)
    if opts.restricted then mocks.setRestricted(true) end

    local cfg = NS.Database.GetWindows()[1]
    cfg.frame.locked  = true
    cfg.visibility    = { dungeon = true, raid = true, arena = true,
                          battleground = true, world = true,
                          hideWhenSolo = false, hideInVehicle = false }
    cfg.data.sortMode = opts.sortMode or "provider"
    -- The shipped default is Overall; these fixtures seed the CURRENT session,
    -- so the window is pointed at it explicitly rather than every case having to
    -- seed two sessions to assert one thing.
    cfg.data.sessionType = CURRENT
    if opts.configure then opts.configure(cfg) end

    local window = NS.Window.New(cfg)
    window:RefreshVisibility()
    return inst, window, cfg
end

-- ---------------------------------------------------------------------------
-- The two frames
-- ---------------------------------------------------------------------------

test("Window builds a bare anchor plus the visible frame, and names both", function()
    local inst, window = scene()

    assertTrue(window.anchor ~= nil, "the clean geometry frame")
    assertTrue(window.frame ~= nil, "the visible one")
    assertFalse(window.anchor == window.frame)
    assertEqual(window.frame:GetName(), "MultiMetersWindow" .. tostring(window.id))
    assertEqual(window.anchor:GetName(), window.frame:GetName() .. "Anchor")

    -- The visible window inherits the anchor's geometry rather than owning any:
    -- two points, TOPLEFT and BOTTOMRIGHT, both onto the anchor.
    assertEqual(window.frame:GetNumPoints(), 2)
    local point, relativeTo = window.frame:GetPoint(1)
    assertEqual(point, "TOPLEFT")
    assertTrue(relativeTo == window.anchor)

    -- ESC MUST NOT CLOSE IT. A meter is furniture, not a dialog: it is meant to
    -- sit there for a whole raid night, and Escape is a key a player presses
    -- constantly for other reasons — clearing a target, closing somebody else's
    -- frame, leaving a vehicle. Any of those taking the meter down leaves an
    -- empty screen with nothing to say which key did it.
    -- red under: tinsert(UISpecialFrames, name).
    for _, name in ipairs(inst.mocks.UISpecialFrames) do
        assertFalse(name == window.frame:GetName(),
            "the meter must not be in UISpecialFrames")
    end
end)

-- ---------------------------------------------------------------------------
-- Layout — rule R3 in one function
-- ---------------------------------------------------------------------------

test("BuildLayout computes every coordinate from config alone", function()
    local inst, window, cfg = scene()
    local Const = inst.NS.Constants

    cfg.frame.padding = 6
    cfg.rows.height   = 16
    cfg.rows.spacing  = 1
    -- 0 is the documented "no cap", and a window with no cap keeps the shipped
    -- NAME_COLUMN_WIDTH. Said here rather than inherited from the default cap:
    -- this case is about the ARITHMETIC around the name column, and it used to
    -- pass only because the shipped cap happened to compute back to the same
    -- number. The case below pins that calibration on its own.
    cfg.text.maxNameLength = 0
    cfg.columns = {
        { stat = "DamageDone", enabled = true },
        { stat = "Interrupts", enabled = true },
    }
    cfg.frame.width = 500
    local layout = window:BuildLayout()

    assertEqual(layout.nameColumn.x, 0)
    assertEqual(layout.nameColumn.width, Const.NAME_COLUMN_WIDTH)

    -- STAT COLUMNS SHARE WHAT IS LEFT, EQUALLY. The stored per-column width is
    -- the shape a NEW column is born at, not the drawn width — dragging the
    -- window wider used to leave the grid where it was and add empty space, and
    -- narrower used to clip the rightmost column off the edge.
    local expected = math.floor((500 - 12 - Const.NAME_COLUMN_WIDTH - 2 * 2) / 2)
    assertEqual(layout.columns[1].width, expected)
    assertEqual(layout.columns[2].width, expected, "equally, not proportionally")
    assertEqual(layout.columns[1].x, Const.NAME_COLUMN_WIDTH + 2)
    assertEqual(layout.columns[2].x, Const.NAME_COLUMN_WIDTH + 2 + expected + 2)
    assertEqual(layout.rowHeight, 16)
end)

test("The name column's formula is calibrated to the shipped width at a 20 cap", function()
    -- NAME_CHAR_RATIO and NAME_COLUMN_PAD are set so that a 20-character cap at
    -- 11pt with the icon on lands on exactly NAME_COLUMN_WIDTH -- a measured
    -- value that has been right in the client for as long as this addon has had
    -- a name column. The SHIPPED cap is 15 and computes narrower, which is the
    -- point of the setting; what this pins is that the formula is still anchored
    -- to a real measurement rather than drifting off one.
    -- red under: retuning the ratio or the pad for the look of it.
    local inst, window, cfg = scene()
    local Const = inst.NS.Constants

    cfg.text.maxNameLength = 20
    cfg.text.size          = 11
    cfg.icons.showIcon     = true
    cfg.icons.size         = 14

    assertEqual(window:BuildLayout().nameColumn.width, Const.NAME_COLUMN_WIDTH)
end)

test("A stat column never shrinks below the legible floor", function()
    -- Below Const.COLUMN_MIN_WIDTH a column cannot hold an abbreviated number and
    -- its header at once. The grid stops shrinking and the frame is clamped
    -- instead of drawing something illegible.
    local inst, window, cfg = scene()
    local Const = inst.NS.Constants
    cfg.frame.width = 100          -- far below anything the grid can hold
    local layout = window:BuildLayout()

    for i, col in ipairs(layout.columns) do
        assertEqual(col.width, Const.COLUMN_MIN_WIDTH, "column " .. i)
    end
end)

test("BuildLayout drops a column whose stat this build does not offer", function()
    local _, window, cfg = scene()
    cfg.columns = {
        { stat = "DamageDone", enabled = true },
        { stat = "StatFromALaterBuild", enabled = true },
    }
    local layout = window:BuildLayout()
    assertEqual(#layout.columns, 1, "a nameless empty column is worse than an absent one")
    assertEqual(layout.columns[1].key, "DamageDone")
end)

test("BuildLayout draws only the ENABLED columns, in stored order", function()
    -- The array is the whole catalog now, so most of a typical window's entries
    -- are disabled and this filter is what makes the window show six columns
    -- rather than eight. Distinct from the unknown-stat drop above: that is a
    -- profile from a newer build, this is the player's own decision.
    -- red under: BuildLayout filtering on the catalog alone.
    local _, window, cfg = scene()
    cfg.columns = {
        { stat = "Interrupts",  enabled = true  },
        { stat = "DamageDone",  enabled = true  },
        { stat = "HealingDone", enabled = false },
        { stat = "Deaths",      enabled = false },
    }
    local layout = window:BuildLayout()
    assertEqual(#layout.columns, 2, "a disabled statistic is not a column")
    assertEqual(layout.columns[1].key, "Interrupts", "the stored order is the drawn order")
    assertEqual(layout.columns[2].key, "DamageDone")
end)

test("A layout column carries no show-bar decision", function()
    -- The bar is unconditional, so there is nothing for the layout to say about
    -- it. Left on the entry it would be a field with no reader, which is how a
    -- setting comes back to life by accident.
    local _, window, cfg = scene()
    cfg.columns = { { stat = "DamageDone", enabled = true, showBar = false } }
    local layout = window:BuildLayout()
    assertEqual(layout.columns[1].showBar, nil)
end)

test("BuildLayout derives how many rows FIT, capped by maxRows and MAX_ROWS", function()
    local inst, window, cfg = scene()

    cfg.frame.height = 220
    cfg.rows.maxRows = 0        -- "as many as fit"
    local fits = window:BuildLayout().maxRows
    assertTrue(fits > 1, "a 220px window fits more than one 16px row")

    cfg.rows.maxRows = 3
    assertEqual(window:BuildLayout().maxRows, 3, "a positive cap wins when it is smaller")

    cfg.frame.height = 4000
    cfg.rows.maxRows = 0
    assertEqual(window:BuildLayout().maxRows, inst.NS.Constants.MAX_ROWS,
        "and the hard ceiling wins over the frame height")
end)

test("The throttle is clamped to the constants, whatever the profile says", function()
    -- ADDON-WIDE since schemaVersion 5: a refresh rate is one answer, not one
    -- per window, so it is read off the profile rather than off the config.
    local inst, window = scene()
    local Const = inst.NS.Constants
    local data = inst.NS.db.profile.data

    data.throttle = 0
    window:RefreshUpvalues()
    assertEqual(window.throttle, Const.THROTTLE_MIN,
        "zero would turn every meter event into a full rebuild")

    data.throttle = 99
    window:RefreshUpvalues()
    assertEqual(window.throttle, Const.THROTTLE_MAX)
end)

-- ---------------------------------------------------------------------------
-- The refresh clock
-- ---------------------------------------------------------------------------

test("The throttle coalesces N events into ONE refresh", function()
    local inst, window = scene()
    inst.NS.db.profile.data.throttle = 0.25
    window:RefreshUpvalues()

    local refreshes = 0
    window.Refresh = function() refreshes = refreshes + 1 end

    window.dirty, window.elapsed = false, 0
    -- Twenty meter events. Every message handler in the file does nothing but
    -- set the flag; only the clock turns a flag into work.
    for _ = 1, 20 do window:MarkDirty() end

    for _ = 1, 4 do window.frame:_run("OnUpdate", 0.05) end
    assertEqual(refreshes, 0, "0.20s of a 0.25s throttle has not elapsed")

    window.frame:_run("OnUpdate", 0.05)
    assertEqual(refreshes, 1, "twenty events, one refresh")

    for _ = 1, 10 do window.frame:_run("OnUpdate", 0.05) end
    assertEqual(refreshes, 1, "and nothing more until something is dirty again")
end)

test("A clean window costs nothing when the clock comes round", function()
    local _, window = scene()
    local refreshes = 0
    window.Refresh = function() refreshes = refreshes + 1 end
    window.dirty, window.elapsed = false, 0
    for _ = 1, 20 do window.frame:_run("OnUpdate", 0.05) end
    assertEqual(refreshes, 0)
end)

test("Refresh does nothing at all while the frame is hidden", function()
    local inst, window = scene()
    window:Hide("test")
    inst.mocks.resetMeterCalls()

    window:MarkDirty()
    window:Refresh()
    for name, count in pairs(inst.mocks.__meter.calls) do
        assertEqual(count, 0, "a hidden window called " .. name)
    end
end)

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

test("Refresh draws one row per aggregated entry, from the pool", function()
    local _, window = scene()
    window:Refresh()

    assertEqual(#window.pool.active, 2)
    assertEqual(window.pool.active[1].entry.guid, ALPHA)
    assertEqual(window.pool.active[2].entry.guid, BETA)
    assertEqual(window.pool.active[1].frame:IsShown(), true)
    assertFalse(window.notice:IsShown(), "there is data, so no notice")
end)

test("Rows come from a POOL: no CreateFrame on a second refresh", function()
    local inst, window = scene()
    local Const = inst.NS.Constants

    window:Refresh()
    -- The pool grows a batch at a time, so one acquire builds POOL_GROW_STEP.
    assertEqual(#window.pool.all, Const.POOL_GROW_STEP)
    assertEqual(#window.pool.free, Const.POOL_GROW_STEP - 2)

    local framesBefore = #inst.mocks.__frames
    window:Refresh()
    window:Refresh()
    assertEqual(#inst.mocks.__frames, framesBefore,
        "WoW never truly frees a frame; a reshuffling raid must not churn them")
    assertEqual(#window.pool.all, Const.POOL_GROW_STEP)
    assertEqual(#window.pool.active, 2, "released and re-acquired, not recreated")
end)

test("HideAll returns every active row to the free list", function()
    local _, window = scene()
    window:Refresh()
    window:HideAll()

    assertEqual(#window.pool.active, 0)
    assertEqual(#window.pool.free, #window.pool.all)
    for _, row in ipairs(window.pool.all) do
        assertEqual(row.frame:IsShown(), false)
        assertNil(row.entry, "a released row holds no reference to the player it drew")
    end
end)

-- A ROW WIDGET MUST KEEP ITS RANK ACROSS REFRESHES, and the guarantee is the LIBRARY's now.
--
-- `Acquire` pops the free list from the end, so the direction `ReleaseAll` parks in decides which
-- widget the next render hands to which rank. Parked forward, the mapping reverses and re-reverses,
-- alternating with period 2 for as long as the window keeps drawing; parked backward, rank n comes
-- back to rank n. LibKa0s-Pool-1.0 minor 3 made parking backward a documented contract, so
-- `WindowProto:HideAll` is a bare `ReleaseAll` again — the host-side reversal it used to carry was
-- removed in the same commit as that payload, because against a backward-parking library it
-- double-reverses and puts the fault straight back.
--
-- WHY THIS TEST DID NOT MOVE WITH THE FIX: what it pins is the INVARIANT, not whichever layer
-- currently supplies it. A widget that keeps its rank is handed the same figure every refresh; a
-- widget that swaps rank is handed a different player's, and a meter value is a secret handle that
-- shows a transient while it resolves — so a swap paints every bar full and snaps it back, four
-- times a second, all fight. Nothing else in this repo would go red for it: the counts stay right,
-- no frame leaks, and preview mode never shows it because placeholder figures apply with no resolve
-- step. This case is the only thing between that bug and its next regression, wherever it comes
-- from, so it outlives the host code it was originally written against.
--
-- THREE PASSES, NOT TWO. A period-2 alternation is right way up on every other render, so a single
-- round trip can pass by luck; the third pass is what makes a swap unable to hide.
test("A row widget keeps its RANK across refreshes: the pool hands them back in order", function()
    local _, window = scene()

    window:Refresh()
    local firstPass = {}
    for i, row in ipairs(window.pool.active) do firstPass[i] = row end
    assertTrue(#firstPass > 1, "the fixture must draw enough rows for an order to exist")

    for pass = 2, 3 do
        window:Refresh()
        assertEqual(#window.pool.active, #firstPass, "the same rows are drawn on every pass")
        for i, row in ipairs(window.pool.active) do
            assertTrue(row == firstPass[i], string.format(
                "rank %d drew a DIFFERENT row widget on refresh %d. Acquire pops the free list " ..
                "from the end, so LibKa0s-Pool-1.0 ReleaseAll must park rows in reverse rank " ..
                "order (minor 3) and HideAll must NOT reverse that again -- either fault alone " ..
                "alternates the mapping every render, which hands every bar a different " ..
                "player's value four times a second, and a secret value shows a transient when " ..
                "it changes", i, pass))
        end
    end
end)

test("Render honors layout.maxRows and places rows from Row.OffsetFor", function()
    local inst, window, cfg = scene{
        sources = { src(ALPHA, 100), src(BETA, 50) },
    }
    cfg.rows.maxRows = 1
    window:ApplyConfig()
    window:Refresh()

    assertEqual(#window.pool.active, 1)

    cfg.rows.maxRows = 0
    window:ApplyConfig()
    window:Refresh()
    assertEqual(#window.pool.active, 2)

    local layout = window.layout
    local second = window.pool.active[2].frame
    local _, _, _, _, y = second:GetPoint(1)
    assertEqual(-y, inst.NS.Row.OffsetFor(layout, 2),
        "the vertical position is a pure function of the index and the row config")
end)

test("growthDirection UP anchors from the bottom of the body", function()
    local _, window, cfg = scene()
    cfg.rows.growthDirection = "UP"
    window:ApplyConfig()
    window:Refresh()

    local point = window.pool.active[1].frame:GetPoint(1)
    assertEqual(point, "BOTTOMLEFT")
end)

-- ---------------------------------------------------------------------------
-- Rule R3, driven
-- ---------------------------------------------------------------------------

--- Replace the four geometry getters on every cell of every pooled row with
--- functions that raise, and hand back a restore function.
local function poisonCellGetters(window)
    local poisoned = {}
    local GETTERS = { "GetWidth", "GetHeight", "GetLeft", "GetPoint" }
    for _, row in ipairs(window.pool.all) do
        local cells = { row.nameCell }
        for _, cell in pairs(row.cells) do cells[#cells + 1] = cell end
        for _, cell in ipairs(cells) do
            poisoned[#poisoned + 1] = cell.frame
            for _, name in ipairs(GETTERS) do
                cell.frame[name] = function()
                    error("rule R3: " .. name .. " was read off a cell that has held a value", 2)
                end
            end
        end
    end
    return function()
        for _, frame in ipairs(poisoned) do
            for _, name in ipairs(GETTERS) do frame[name] = nil end
        end
    end
end

test("R3: no geometry is read back off a cell that has held a secret", function()
    local _, window = scene{ restricted = true }

    window:Refresh()

    -- The bars really are marked, which is what makes the poisoning meaningful:
    -- these are the frames whose anchoring data the client has just made secret.
    local marked = 0
    for _, row in ipairs(window.pool.active) do
        for _, cell in pairs(row.cells) do
            if cell.frame:HasSecretValues() then marked = marked + 1 end
        end
    end
    assertTrue(marked > 0, "the fixture must actually hand secrets to the bars")

    local restore = poisonCellGetters(window)
    local ok, err = pcall(function()
        window:MarkDirty()
        window:Refresh()
        window:ApplyLock()
        window:UpdateHeaderText(false)
    end)
    restore()
    assertTrue(ok, tostring(err))
end)

test("modules/Window.lua reads geometry back off the anchor and nothing else", function()
    -- A static sweep beside the dynamic one: the dynamic case can only catch a
    -- read on a path it happened to drive, and this catches the line.
    local fh = assert(io.open(T.root .. "/modules/Window.lua", "r"))
    local n, offenders = 0, {}
    for line in fh:lines() do
        n = n + 1
        if not line:match("^%s*%-%-") then
            local code = line:gsub("%s%-%-.*$", "")
            for _, getter in ipairs{ "GetWidth", "GetHeight", "GetLeft", "GetPoint" } do
                local at = code:find(":" .. getter .. "%(")
                if at and not code:find("self%.anchor:" .. getter) then
                    offenders[#offenders + 1] = "modules/Window.lua:" .. n
                end
            end
        end
    end
    fh:close()
    assertEqual(#offenders, 0,
        "geometry is read off something other than the anchor: "
        .. table.concat(offenders, ", "))
end)

-- ---------------------------------------------------------------------------
-- The meter-unavailable path
-- ---------------------------------------------------------------------------

test("An unavailable meter renders the prompt INSTEAD of rows", function()
    local inst, window = scene()
    window:Refresh()
    assertEqual(#window.pool.active, 2)

    inst.mocks.setMeterAvailable(false, "DAMAGE_METER_DISABLED_BY_CVAR")
    inst.NS.Provider.InvalidateAvailability()
    window:Refresh()

    assertEqual(#window.pool.active, 0, "the rows come down")
    assertEqual(window.notice:IsShown(), true)

    local text = window.notice:GetText()
    assertTrue(text:find("built%-in damage meter") ~= nil, "it says where the numbers come from")
    -- Blizzard's own reason, quoted rather than interpreted: the game knows why
    -- its meter is off, and guessing on its behalf sends the player to the wrong
    -- setting.
    assertTrue(text:find("DAMAGE_METER_DISABLED_BY_CVAR", 1, true) ~= nil)
end)

test("The notice omits a reason it cannot safely render", function()
    local inst, window = scene()
    inst.mocks.setMeterAvailable(false, nil)
    inst.NS.Provider.InvalidateAvailability()
    window:Refresh()

    assertEqual(window.notice:IsShown(), true)
    assertFalse(window.notice:GetText():find("Reason") ~= nil,
        "a nil reason must not become the string 'nil'")
end)

test("An empty session says so rather than leaving a blank grid", function()
    local inst, window = scene()
    inst.mocks.setSession(CURRENT, "*", { combatSources = {}, maxAmount = 0, totalAmount = 0 })
    window:Refresh()

    assertEqual(#window.pool.active, 0)
    assertEqual(window.notice:IsShown(), true)
    assertTrue(window.notice:GetText():find("Waiting for combat", 1, true) ~= nil,
        "an empty grid with no explanation reads as a broken addon")
end)

-- ---------------------------------------------------------------------------
-- The drill-down branch
-- ---------------------------------------------------------------------------

test("A drilled-in window draws the breakdown, decided by the ROWS not the title", function()
    local inst, window, cfg = scene{ restricted = true }
    local NS, mocks = inst.NS, inst.mocks

    mocks.setSourceDetail(CURRENT, "*", "*", {
        combatSpells = {
            { spellID = 101, totalAmount = 60, amountPerSecond = 6 },
            { spellID = 102, totalAmount = 40, amountPerSecond = 4 },
        },
        maxAmount = 60, totalAmount = 100,
    })
    NS.DrillDown:Enter(cfg, { guid = ALPHA, name = "Alpha", classFilename = "PALADIN" },
        "DamageDone")

    window:Refresh()

    assertEqual(#window.pool.active, 2, "two spells, drawn through the ordinary row pool")
    assertEqual(window.pool.active[1].entry.guid, "spell:101")
    assertEqual(window.pool.active[1].entry.isDrillDown, true)

    -- The title is display-only and may be a secret string; the branch above it
    -- was taken on the plain rows table.
    assertEqual(window.sessionText:GetText(), NS.DrillDown.Title(cfg))

    NS.DrillDown:Exit(cfg)
    window:Refresh()
    -- Back to the grid — and this scene is RESTRICTED, so the grid's rows are
    -- keyed on their rank rather than on a GUID nothing may key on.
    assertEqual(window.pool.active[1].entry.guid, "rank_1", "and back to the grid")
end)

-- ---------------------------------------------------------------------------
-- Suspend and teardown
-- ---------------------------------------------------------------------------

test("Suspend takes the OnUpdate away and Resume puts it back", function()
    local _, window = scene()

    window:Suspend()
    assertNil(window.frame:GetScript("OnUpdate"),
        "a pass already queued must not fire once more inside a measurement window")

    window:Resume()
    assertTrue(window.frame:GetScript("OnUpdate") ~= nil)
end)

test("Destroy takes the window off screen and off the bus", function()
    local inst, window = scene()
    window:Refresh()
    window:Destroy()

    assertEqual(window:IsShown(), false)
    assertEqual(#window.pool.active, 0)
    assertNil(window.frame:GetScript("OnUpdate"))

    local MSG = inst.NS.Constants.MSG
    assertNil((inst.mocks.__busRegistry[MSG.METER_UPDATED] or {})[window.bus])
end)

test("Each window owns a PRIVATE bus target, so two windows cannot clobber each other", function()
    local inst, first, cfg = scene()
    local second = inst.NS.Window.New(cfg)

    assertFalse(first.bus == second.bus,
        "CallbackHandler keys callbacks by (message, target); a shared target loses all but one")

    first.dirty, second.dirty = false, false
    inst.NS:SendMessage(inst.NS.Constants.MSG.METER_UPDATED)
    assertEqual(first.dirty, true)
    assertEqual(second.dirty, true, "both windows heard it")
end)

-- ---------------------------------------------------------------------------
-- Scrolling
-- ---------------------------------------------------------------------------
--
-- NOT a ScrollFrame. The window already draws `layout.maxRows` rows chosen out
-- of a longer list, so scrolling is choosing a different window into that list —
-- one integer applied at the top of the render loop. Which means the cases worth
-- writing are about the INTEGER: is it clamped, does it survive a refresh, and
-- does it reset when the list stops being the same list.

--- A window whose frame fits exactly `visible` rows, rendering `total` entries.
local function scrollScene(visible, total)
    local inst, window, cfg = scene{ configure = function(c)
        c.rows.maxRows = visible
    end }
    local rows = {}
    for i = 1, total do
        rows[i] = { guid = string.format("Player-1-%08X", i), name = "Mock" .. i,
                    classFilename = "MAGE", values = {}, cells = {} }
    end
    return inst, window, cfg, rows
end

--- The names the window actually drew, top to bottom.
local function drawnNames(window)
    local out = {}
    for _, row in ipairs(window.pool.active or {}) do
        out[#out + 1] = row.entry and row.entry.name
    end
    return out
end

test("Scrolling moves the window into the list, it does not shorten it", function()
    -- red under: a render loop that always starts at index 1.
    local _, window, _, rows = scrollScene(3, 10)
    window:Render(rows, false)
    assertEqual(drawnNames(window)[1], "Mock1", "the fixture did not start at the top")
    assertEqual(#drawnNames(window), 3, "the row cap is not what the fixture set")

    window:ScrollBy(2)
    window:Render(rows, false)
    assertEqual(drawnNames(window)[1], "Mock3", "scrolling down did not move the first row")
    assertEqual(#drawnNames(window), 3, "scrolling changed how many rows are drawn")
end)

test("The offset survives a refresh, or scrolling is impossible", function()
    -- The window redraws four times a second. An offset reset per render would
    -- snap the view back to the top before a player let go of the wheel.
    -- red under: zeroing scrollOffset in Render.
    local _, window, _, rows = scrollScene(3, 10)
    window:ScrollBy(4)
    for _ = 1, 5 do window:Render(rows, false) end
    assertEqual(window.scrollOffset, 4, "a redraw threw the scroll position away")
end)

test("The offset cannot run past the end of the list", function()
    -- red under: an unclamped offset, which renders an empty window that
    -- scrolling cannot recover from.
    local _, window, _, rows = scrollScene(3, 10)
    window:ScrollBy(500)
    window:Render(rows, false)

    assertEqual(window.scrollOffset, 7, "the offset was not clamped to the last full page")
    assertEqual(#drawnNames(window), 3, "the last page is not full")
    assertEqual(drawnNames(window)[3], "Mock10", "the last row is not the last entry")
end)

test("A list that shrinks under a stationary offset re-clamps on the next draw", function()
    -- This happens constantly: a player leaves the group, a breakdown has fewer
    -- spells than the grid had rows. An offset left past the end renders nothing.
    -- red under: clamping only inside ScrollBy.
    local _, window, _, rows = scrollScene(3, 10)
    window:ScrollBy(7)
    window:Render(rows, false)
    assertEqual(#drawnNames(window), 3)

    local short = { rows[1], rows[2], rows[3], rows[4] }
    window:Render(short, false)
    assertEqual(window.scrollOffset, 1, "the offset was not re-clamped to the shorter list")
    assertTrue(#drawnNames(window) > 0, "the window rendered empty after the list shrank")
end)

test("Scrolling up stops at the top", function()
    -- red under: a negative offset.
    local _, window, _, rows = scrollScene(3, 10)
    window:ScrollBy(-5)
    window:Render(rows, false)
    assertEqual(window.scrollOffset, 0)
    assertEqual(drawnNames(window)[1], "Mock1")
end)

test("A list that fits entirely cannot be scrolled", function()
    -- red under: MaxScroll returning a negative, which would let the view slide
    -- off the top of a list that was never long enough to scroll.
    local _, window, _, rows = scrollScene(10, 3)
    window:ScrollBy(5)
    window:Render(rows, false)
    assertEqual(window.scrollOffset, 0, "a window with room to spare still scrolled")
    assertEqual(#drawnNames(window), 3, "and it still drew every row it had")
end)

test("The body takes the wheel, or the handler is never called in game", function()
    -- A live OnMouseWheel script on a frame that never called EnableMouseWheel
    -- runs perfectly in a harness and does nothing in the client.
    -- red under: dropping EnableMouseWheel.
    local _, window = scrollScene(3, 10)
    assertTrue(window.body:IsMouseWheelEnabled(), "the body does not accept the wheel")
end)

test("The wheel scrolls up on a positive delta", function()
    -- Getting this backwards is the kind of thing no unit test catches unless it
    -- names the direction: delta > 0 is "wheel up", which means a SMALLER offset.
    -- red under: inverting the sign.
    local _, window, _, rows = scrollScene(3, 10)
    window:ScrollBy(5)
    window:Render(rows, false)
    local before = window.scrollOffset
    assertTrue(before > 0, "the fixture never scrolled at all")

    window.body:_run("OnMouseWheel", 1)
    window:Render(rows, false)
    assertTrue(window.scrollOffset < before, "wheel up moved the view down the list")

    window.body:_run("OnMouseWheel", -1)
    window:Render(rows, false)
    assertEqual(window.scrollOffset, before, "wheel down did not undo it")
end)

test("Entering or leaving a breakdown puts the view back at the top", function()
    -- An offset carried from the grid into a breakdown points into rows that are
    -- not there — and it would then be re-clamped rather than reset, leaving a
    -- player part-way down a list they never scrolled.
    -- red under: dropping ResetScroll from the DRILLDOWN_CHANGED handler.
    local inst, window, cfg, rows = scrollScene(3, 10)
    window:ScrollBy(5)
    window:Render(rows, false)
    assertEqual(window.scrollOffset, 5)

    inst.NS.DrillDown:Enter(cfg,
        { guid = "Player-1-00000001", name = "Mock1", values = {} }, "DamageDone")
    assertEqual(window.scrollOffset, 0, "the grid's scroll position followed us into the breakdown")
end)

test("A drill-down draws its rows from the top of the body, with none hanging out", function()
    -- THE OVERFLOW. `layout.maxRows` is derived from the body height, and every
    -- drill row used to be pushed down by the height of a Back button drawn
    -- inside that body — so a full page of rows put its last row through the
    -- bottom of the frame. The button is gone and the offset with it.
    -- red under: re-adding a fixed drill offset to Row.OffsetFor's result.
    local _, window, _, rows = scrollScene(3, 10)

    window:Render(rows, false, false)
    local gridTop = window.pool.active[1].frame.__points[1].y

    window:Render(rows, false, true, "Alpha - Damage")
    local drillTop = window.pool.active[1].frame.__points[1].y

    assertEqual(drillTop, gridTop,
        "a breakdown's first row starts lower than the grid's, so its last row overflows")
end)

test("Right-clicking empty space below the rows leaves a breakdown", function()
    -- The rows handle their own right-click, but a short breakdown leaves most
    -- of the body bare and "right-click anywhere" has to mean anywhere.
    -- red under: no OnMouseUp on the body.
    local inst, window, cfg = scene()
    inst.NS.DrillDown:Enter(cfg,
        { guid = ALPHA, name = "Alpha", values = {} }, "DamageDone")
    assertTrue(inst.NS.DrillDown.IsActive(cfg), "the fixture never entered a breakdown")

    window.body:_run("OnMouseUp", "RightButton")
    assertFalse(inst.NS.DrillDown.IsActive(cfg), "the body ignored the right click")
end)

test("The body claims the mouse only while a breakdown is open", function()
    -- There is a hard-won comment saying the body taking the mouse "stole every
    -- hover from the cells underneath it". The cells are descendants and should
    -- still win, but that was learned the expensive way — so the grid keeps
    -- exactly the behaviour it has today and only a drilled window changes.
    -- red under: EnableMouse(true) on the body unconditionally.
    local _, window = scene()
    local rows = { { guid = ALPHA, name = "Alpha", values = {}, cells = {} } }

    window:Render(rows, false, false)
    assertFalse(window.body:IsMouseEnabled(), "the grid's body took the mouse")

    window:Render(rows, false, true, "Alpha - Damage")
    assertTrue(window.body:IsMouseEnabled(), "a breakdown's body did not take the mouse")
end)

test("Scale scales the WINDOW, not just what is inside it", function()
    -- The visible frame is pinned TOPLEFT and BOTTOMRIGHT to the anchor, so the
    -- anchor's screen rect dictates the frame's whatever scale the frame carries.
    -- Scaling the frame alone therefore left the box the size it was and shrank
    -- only its contents: at 0.5 a full-size window with a miniature grid in the
    -- corner of it.
    -- red under: dropping anchor:SetScale and keeping frame:SetScale alone.
    local _, window, cfg = scene()
    cfg.frame.scale = 0.5
    window:ApplyConfig()

    assertEqual(window.anchor:GetScale(), 0.5, "the geometry frame did not scale")
    assertEqual(window.frame:GetScale(), 0.5, "the visible frame did not scale")

    cfg.frame.scale = nil
    window:ApplyConfig()
    assertEqual(window.anchor:GetScale(), 1.0, "an unset scale is 1, not 0")
    assertEqual(window.frame:GetScale(), 1.0)
end)

test("Border style None draws NO edge, whatever the library's own is", function()
    -- `borderPath` falls back to NS.SKIN's edge when a NAMED texture cannot be
    -- fetched, which is right for a missing media pack and wrong for a CHOICE:
    -- LSM's name for the empty border is not a failed fetch, and falling back on
    -- it handed the player the Ka0s edge they had just turned off.
    --
    -- Asserted at a NON-ZERO thickness, because the `borderSize == 0` branch would
    -- otherwise hide the bug: the style has to answer for itself.
    -- red under: moving the "None" test out of `borderPath` and back behind the
    -- size check, or dropping it.
    local _, window, cfg = scene()
    cfg.frame.borderSize = 8

    -- Every spelling of "no border", including the two a hand-edited
    -- SavedVariables or a profile written before the setting existed can produce.
    for _, style in ipairs({ "None", "", "\0" }) do
        cfg.frame.borderStyle = (style ~= "\0") and style or nil
        window:ApplyConfig()
        local backdrop = window.frame.__backdrop or {}
        assertEqual(backdrop.edgeFile, nil,
            ("%q still drew an edge"):format(tostring(cfg.frame.borderStyle)))
    end
end)

test("A border style that CANNOT be fetched still falls back to the library edge", function()
    -- The other half of the same function, and the reason "None" could not simply
    -- be lumped in with it. A named texture that does not resolve is a media pack
    -- that is no longer installed -- a failure, not a choice -- and a window that
    -- silently loses its edge over it is worse than one wearing the collection's.
    -- red under: `borderPath` answering nil for anything it cannot fetch.
    local _, window, cfg = scene()
    cfg.frame.borderStyle = "A Border No Media Pack Here Provides"
    cfg.frame.borderSize  = 2
    window:ApplyConfig()

    local backdrop = window.frame.__backdrop or {}
    assertTrue(backdrop.edgeFile ~= nil,
        "an unfetchable NAME is a failure, and falls back to the Ka0s edge")
end)

test("With no border, the SKIN's inner highlight goes too", function()
    -- LibKa0s's ApplySkin builds a 1px `frame.innerBorder` CHILD inset inside the
    -- black edge. It is not part of the backdrop ApplyBorder rewrites, so with the
    -- style set to None and the thickness at 0 it was the whole visible border --
    -- outliving both controls that claim to govern one.
    -- red under: ApplyBorder leaving frame.innerBorder alone.
    local _, window, cfg = scene()
    cfg.frame.borderStyle = "None"
    cfg.frame.borderSize  = 0
    window:ApplyConfig()

    -- ASSERTED, not skipped when absent: the harness loads the real
    -- libs/LibKa0s/Core.lua, so ApplySkin has genuinely built this child by now.
    -- A guarded `if type(...) == "table"` here would pass on a day the library
    -- stopped building it, which is exactly the day this case has to fail.
    assertEqual(type(window.frame.innerBorder), "table",
        "the library's inner border was never built -- this case is asserting nothing")
    assertEqual(window.frame.innerBorder:IsShown(), false,
        "the skin's highlight is the border the settings could not turn off")

    -- And it comes back with the edge, because inside a real border it is the
    -- highlight the library drew it to be.
    cfg.frame.borderStyle = "Blizzard Tooltip"
    cfg.frame.borderSize  = 2
    window:ApplyConfig()
    assertEqual(window.frame.innerBorder:IsShown(), true)
end)

-- ── pool.all reaches PARKED rows (LibKa0s-Pool-1.0 adoption) ────────────────
--
-- The one thing the library's pool cannot express, and therefore the one thing a
-- careless adoption would have dropped. `pool.all` holds every row ever built,
-- free ones included, and ApplyLayout iterates it so a row sitting on the free
-- list is re-laid-out too. Drop that and everything still looks right until the
-- group GROWS and a parked row is handed out at the old width — long after the
-- settings change that caused it, with nothing pointing back.

test("pool: a layout change re-applies to FREE rows, not just active ones", function()
    local _, window = scene()
    window:Refresh()

    -- Park everything, so every row in `all` is on the free list.
    window:HideAll()
    assertEqual(#window.pool.active, 0)
    assertEqual(#window.pool.free, #window.pool.all, "all rows are parked")

    local applied = {}
    for _, row in ipairs(window.pool.all) do
        local real = row.ApplyLayout
        row.ApplyLayout = function(self, layout) applied[self] = true; return real(self, layout) end
    end

    window:ApplyConfig()

    local n = 0
    for _ in pairs(applied) do n = n + 1 end
    assertEqual(n, #window.pool.all,
        "every row got the new layout, including the ones nobody is drawing with")
end)

-- ---------------------------------------------------------------------------
-- The master controls (options-ui-§15)
-- ---------------------------------------------------------------------------

test("Master scale MULTIPLIES the window's own rather than replacing it", function()
    -- The two are different settings: `master.scale` is addon-wide and lives on the
    -- General page's Master controls tab, `frame.scale` is this window's and lives
    -- on the Frame page. Composing them is what lets one control shrink a whole
    -- layout without flattening the differences a player set between its windows.
    -- red under: reading either one alone, or `math.min` instead of a product.
    local inst, window, cfg = scene()

    cfg.frame.scale = 0.8
    inst.NS.db.profile.master.scale = 0.5
    window:ApplyConfig()
    assertEqual(window.frame:GetScale(), 0.4, "the two scales did not compose")
    assertEqual(window.anchor:GetScale(), 0.4, "the geometry frame took a different scale")

    -- And back: a master of 1 gives the window exactly the size it was set to.
    inst.NS.db.profile.master.scale = 1.0
    window:ApplyConfig()
    assertEqual(window.frame:GetScale(), 0.8)
end)

test("Master alpha MULTIPLIES the window's own opacity", function()
    -- red under: reading `master.alpha` alone, which would throw away every
    -- per-window opacity the moment the master moved off 1.
    local inst, window, cfg = scene()

    cfg.frame.alpha = 0.5
    inst.NS.db.profile.master.alpha = 0.5
    window:ApplyConfig()
    assertEqual(window.frame:GetAlpha(), 0.25)
end)

test("Master scale and alpha are CLAMPED to the sliders that write them", function()
    -- They can also arrive from `/mm set` or a hand-edited SavedVariables, and a
    -- scale of 0 is a window nobody can find again.
    -- red under: dropping the clamp in modules/Window.lua's masterSetting.
    local inst, window, cfg = scene()

    cfg.frame.scale, cfg.frame.alpha = 1.0, 1.0
    inst.NS.db.profile.master.scale = 99
    inst.NS.db.profile.master.alpha = -3
    window:ApplyConfig()
    assertEqual(window.frame:GetScale(), 2.0, "the scale ceiling is the slider's")
    assertEqual(window.frame:GetAlpha(), 0, "the alpha floor is the slider's")
end)

test("The window's fill and its edge each answer a colour mode", function()
    -- options-ui-§17: every swatch has a companion, and for this addon that
    -- companion is a two-value mode. `class` is the LOCAL player's -- a window is
    -- not about any one row -- and the CONFIGURED ALPHA survives it, which is what
    -- keeps a 0.75 backdrop a tint rather than a slab.
    -- red under: reading the swatch with RGBA and ignoring the mode, or letting the
    -- class colour carry its own (absent) alpha.
    local inst, window, cfg = scene()
    local mr, mg, mb = inst.NS.PlayerClassRGB()
    assertTrue(mr ~= nil, "the fixture needs the player's class in the palette")

    cfg.frame.borderStyle = "Blizzard Tooltip"
    cfg.frame.borderSize  = 2
    cfg.frame.backdropColor = { r = 0, g = 0, b = 0, a = 0.75 }
    cfg.frame.borderColor   = { r = 0, g = 0, b = 0, a = 0.5 }
    cfg.frame.backdropColorMode = "class"
    cfg.frame.borderColorMode   = "class"
    window:ApplyConfig()

    local fill = window.frame.__backdropColor
    assertEqual(fill[1], mr); assertEqual(fill[2], mg); assertEqual(fill[3], mb)
    assertEqual(fill[4], 0.75, "the swatch's alpha did not survive the mode")

    local edge = window.frame.__backdropBorderColor
    assertEqual(edge[1], mr); assertEqual(edge[2], mg); assertEqual(edge[3], mb)
    assertEqual(edge[4], 0.5, "the border swatch's alpha did not survive the mode")

    -- Custom is the shipped mode and reads the swatch, exactly as it always did.
    cfg.frame.backdropColorMode = "custom"
    window:ApplyConfig()
    assertEqual(window.frame.__backdropColor[1], 0, "custom stopped reading the swatch")
end)

test("pool: every row built lands in `all`, including the batch surplus", function()
    -- Batch growth moved into the Acquire factory closure, which the library calls once per miss.
    -- A closure that registered only the row it RETURNED would leave four of every five rows out
    -- of `all` — and those four would then never be re-laid-out.
    local inst, window = scene()
    local Const = inst.NS.Constants

    window:Refresh()
    assertEqual(#window.pool.all, Const.POOL_GROW_STEP,
        "the whole batch is tracked, not just the row handed back")
    assertEqual(#window.pool.free + #window.pool.active, #window.pool.all,
        "and every tracked row is accounted for as either parked or out")
end)

-- ---------------------------------------------------------------------------
-- BuildLayout, pinned for the split (issue #42)
-- ---------------------------------------------------------------------------
--
-- WindowProto:BuildLayout is CCN 24 and a later wave peels the column arithmetic
-- out of it. Everything below is a property of the layout table that a peel could
-- silently move: the cases above cover the equal-share formula, the two filters
-- and the row cap, and these cover the rest of the table and the arms nothing
-- else reaches. They are written against the UNREFACTORED function, which is the
-- only order in which they mean anything (performance-§11).

test("The stored per-column width is what a NEW column is born at, never the drawn one", function()
    -- The whole point of the share: `col.width` describes the shape a column is
    -- CREATED with (core/Database.lua's v1->v2 migration writes it), and the
    -- drawn width comes from the frame. A helper that started honouring the
    -- stored number would bring back the bug the share replaced — a window
    -- dragged wider keeping its grid and growing empty space on the right.
    -- red under: `width = entry.col.width or statWidth`, or a peel that writes
    -- the computed share back onto the stored entry.
    local _, window, cfg = scene()
    cfg.frame.width = 500
    cfg.text.maxNameLength = 0
    cfg.columns = {
        { stat = "DamageDone", enabled = true, width = 999 },
        { stat = "Interrupts", enabled = true, width = 7   },
    }
    local layout = window:BuildLayout()

    assertEqual(layout.columns[1].width, layout.columns[2].width,
        "two columns with different stored widths still share equally")
    assertFalse(layout.columns[1].width == 999)
    assertEqual(cfg.columns[1].width, 999, "and the stored shape is not rewritten")
    assertEqual(cfg.columns[2].width, 7)
end)

test("The name column is excluded from the share, and is not sized by the frame", function()
    -- Two facts in one place because they are the same rule: a name does not get
    -- longer because the window did, so the name column is subtracted from the
    -- available width rather than counted into the divisor.
    -- red under: a peel that divides by #visible + 1, or one that hands the name
    -- column a share of its own.
    local _, window, cfg = scene()
    cfg.text.maxNameLength = 0
    cfg.columns = {
        { stat = "DamageDone", enabled = true },
        { stat = "Interrupts", enabled = true },
    }

    cfg.frame.width = 500
    local narrow = window:BuildLayout()
    cfg.frame.width = 700
    local wide = window:BuildLayout()

    assertEqual(wide.nameColumn.width, narrow.nameColumn.width,
        "the name column does not grow with the frame")
    -- 200 more pixels across two columns is 100 each: the divisor is the STAT
    -- columns alone. Divided three ways it would be 66.
    assertEqual(wide.columns[1].width - narrow.columns[1].width, 100)
    assertEqual(wide.columns[2].width - narrow.columns[2].width, 100)
end)

test("The name column is placed first, at x 0, and carries its bar unconditionally", function()
    -- It is not a statistic and can never be removed, which is why it is placed
    -- separately from the loop. A peel that folded it into the column array would
    -- put it at the mercy of the `enabled` filter.
    local _, window = scene()
    local layout = window:BuildLayout()

    assertEqual(layout.nameColumn.key, "name")
    assertEqual(layout.nameColumn.x, 0)
    assertTrue(layout.nameColumn.showBar, "the name column's bar is not a setting")
end)

test("A window with every column disabled still lays out", function()
    -- The zero-column arm: nothing divides by #visible, `rowWidth` is the name
    -- column alone with no trailing seam, and `minWidth` still reserves room for
    -- ONE column so the window cannot be dragged down to a bare name strip it
    -- could never grow a column back into.
    -- red under: a peel that divides by zero, or one that drops the max(#visible, 1).
    local inst, window, cfg = scene()
    local Const = inst.NS.Constants
    cfg.text.maxNameLength = 0
    cfg.columns = { { stat = "DamageDone", enabled = false } }

    local layout = window:BuildLayout()
    assertEqual(#layout.columns, 0)
    assertEqual(layout.rowWidth, Const.NAME_COLUMN_WIDTH,
        "the row is the name column, and no seam hangs off its right edge")
    assertEqual(layout.minWidth,
        Const.NAME_COLUMN_WIDTH + (cfg.frame.padding or 6) * 2
            + Const.COLUMN_MIN_WIDTH + Const.COLUMN_GAP,
        "an empty grid still reserves one column's worth of floor")
end)

test("Hiding the title bar takes its height out of the layout, not out of the header strip", function()
    -- `header.show == false` is the one arm that zeroes a height, and the column
    -- strip is NOT part of it — the labels above the grid stay whatever the row
    -- height says. Both numbers feed minHeight and the body's top offset, so a
    -- peel that conflated them would either float the grid or overlap it.
    local _, window, cfg = scene()
    cfg.rows.height   = 16
    cfg.header.show   = true
    cfg.header.height = 18

    local shown = window:BuildLayout()
    assertEqual(shown.titleHeight, 18)
    assertEqual(shown.headerHeight, 16, "the column strip is one row tall")

    cfg.header.show = false
    local hidden = window:BuildLayout()
    assertEqual(hidden.titleHeight, 0)
    assertEqual(hidden.headerHeight, 16, "hiding the title bar does not hide the labels")
    assertEqual(shown.minHeight - hidden.minHeight, 18,
        "and the floor drops by exactly the bar that went away")
end)

test("bodyWidth is the frame minus its padding, whatever the grid inside it costs", function()
    -- `rowWidth` is what the columns add up to and `bodyWidth` is what the frame
    -- offers; they are different questions and a narrow window makes them differ.
    -- red under: a peel that publishes one of them twice.
    local _, window, cfg = scene()
    cfg.frame.width   = 500
    cfg.frame.padding = 6
    local layout = window:BuildLayout()

    assertEqual(layout.bodyWidth, 488)
    assertFalse(layout.rowWidth == layout.bodyWidth,
        "the fixture must make the two numbers distinguishable")
end)

test("growUp is a boolean off growthDirection, and nothing else", function()
    -- Read once here and consulted per row by Render. Any value that is not the
    -- string "UP" grows down, which is what keeps an unmigrated profile drawing
    -- the way it always did.
    local _, window, cfg = scene()
    cfg.rows.growthDirection = "UP"
    assertTrue(window:BuildLayout().growUp)
    cfg.rows.growthDirection = "DOWN"
    assertFalse(window:BuildLayout().growUp)
    cfg.rows.growthDirection = nil
    assertFalse(window:BuildLayout().growUp, "an absent setting grows down")
end)

test("A window too short for even one row still asks the pool for one", function()
    -- The `fits < 1` floor. Zero rows is a window that draws nothing and says
    -- nothing about why, and a negative count reaches Render as a loop that never
    -- runs — so the arithmetic bottoms out at one drawn row and the resize clamp
    -- (minHeight) is what actually stops the player getting here.
    local _, window, cfg = scene()
    cfg.frame.height = 1
    cfg.rows.maxRows = 0
    assertEqual(window:BuildLayout().maxRows, 1)
end)

test("A maxRows cap LARGER than the frame holds does not win", function()
    -- The cap is a ceiling, never a floor: `capped > 0 and capped < fits`. A peel
    -- that dropped the second half would draw rows out through the bottom of the
    -- frame on any window whose cap was set high and then dragged shorter.
    local _, window, cfg = scene()
    cfg.frame.height = 220
    cfg.rows.maxRows = 0
    local fits = window:BuildLayout().maxRows

    cfg.rows.maxRows = fits + 5
    assertEqual(window:BuildLayout().maxRows, fits,
        "the frame height still decides when the cap is looser than it is")
end)

test("BuildLayout survives a config with the sub-tables missing, on the shipped numbers", function()
    -- Every read in here is `x or <default>`, and those defaults are the shipped
    -- window: 694x220, 6px padding, 16px rows, 1px spacing, an 18px title bar.
    -- A profile that lost a sub-table to a failed migration lays out rather than
    -- erroring on a nil index, and it lays out looking like a new window.
    -- red under: a peel that reads `cfg.frame.width` through a helper that was
    -- handed the table rather than the default.
    local inst, window, cfg = scene()
    local Const = inst.NS.Constants
    cfg.frame  = {}
    cfg.rows   = {}
    cfg.header = {}
    cfg.text   = {}
    cfg.columns = { { stat = "DamageDone", enabled = true } }

    local layout = window:BuildLayout()
    assertEqual(layout.padding, 6)
    assertEqual(layout.rowHeight, 16)
    assertEqual(layout.rowSpacing, 1)
    assertEqual(layout.titleHeight, 18, "an absent `show` is not `show == false`")
    assertEqual(layout.bodyWidth, 694 - 12, "the shipped frame width")
    assertEqual(layout.nameColumn.width, Const.NAME_COLUMN_WIDTH,
        "no cap means the shipped name column")
    assertTrue(layout.maxRows > 1, "and the shipped height fits more than one row")
end)
