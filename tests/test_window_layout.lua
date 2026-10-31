-- tests/test_window_layout.lua — WindowProto:BuildLayout and the throttle clamp: rule R3 in one
-- function, the column share, the row fit and the arms a later peel could move.
--
-- Peeled out of tests/test_window.lua along this seam when that suite passed its re-check, 28
-- lines under layout-§1's cap; a pure move, case names unchanged. The fixture is copied rather
-- than shared, for the reason that file's header gives.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse

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
    local inst = T.load(opts.load)
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
    -- CREATED with (core/Database_Migrations.lua's v1->v2 migration writes it), and the
    -- drawn width comes from the frame. A helper that started honoring the
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
    -- window: 694x228, 6px padding, 16px rows, 1px spacing, a 26px title height.
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
    assertEqual(layout.titleHeight, 26, "an absent `show` is not `show == false`")
    assertEqual(layout.bodyWidth, 694 - 12, "the shipped frame width")
    assertEqual(layout.nameColumn.width, Const.NAME_COLUMN_WIDTH,
        "no cap means the shipped name column")
    assertEqual(layout.maxRows, 10, "the shipped height fits ten rows")
end)
