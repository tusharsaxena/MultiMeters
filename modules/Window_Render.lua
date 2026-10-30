-- modules/Window_Render.lua
--
-- What ONE window draws and when: the row pool, the scroll, the OnUpdate clock
-- that turns the dirty flag into a Refresh, and Render, which binds the
-- aggregator's answer to rows slot by slot.
--
-- ---------------------------------------------------------------------------
-- WHY THIS IS ITS OWN FILE
-- ---------------------------------------------------------------------------
--
-- modules/Window.lua stood at exactly layout-§1's 1500-line cap, and the owner
-- ruled it split before its next change (MM-04, 2026-10-31). This is the half of
-- the loop that runs on the clock; the refresh contract it implements (one event
-- never drives one rebuild, a private bus target per window) is still stated in
-- modules/Window.lua's header. Only these functions moved, unchanged.
--
-- FILE-SCOPE READS, and why the TOC line is load-bearing. This file resolves
-- NS.WindowProto, NS.WindowModule and NS.WindowInternals, all published by
-- modules/Window.lua, so it MUST load after it; and it hangs `newRowPool` and
-- `onUpdate` on NS.WindowInternals, which modules/Window_Lifecycle.lua resolves
-- at file scope, so it MUST load before that file.

local _, NS = ...

-- Perf bracket upvalue (performance-§2): resolved ONCE at load, never through an
-- NS lookup on the hot path.
local Perf = NS.Perf

local Const = NS.Constants
local L     = NS.L

local WindowProto = NS.WindowProto
local mod         = NS.WindowModule

-- ---------------------------------------------------------------------------
-- The row pool
-- ---------------------------------------------------------------------------
--
-- Ten or more dynamic frames means a pool rather than create-and-destroy: a
-- 40-player raid that reshuffles every quarter second would otherwise churn
-- hundreds of frames a minute, and WoW never truly frees one. Rows are acquired
-- once, stay bound to their slots across refreshes, and are kept forever.

--- A row pool: the library's two arrays, plus the host's third.
---
--- `all` holds every row ever built, parked ones included. ApplyLayout and ApplyLock iterate it so
--- a FREE row is re-laid-out too — without that, a row parked across a settings change comes back
--- at the old width the next time the group grows, and nothing would have caught it.
local function newRowPool()
    local pool = NS.Pool.New()
    pool.all = {}
    return pool
end

--- Take a row from the free list, growing the pool a batch at a time.
---
--- The free/active mechanics are the library's. The BATCH lives in the factory closure because
--- `Acquire` calls its factory once per miss: the closure builds the batch, parks the surplus on
--- the free list the library is about to draw from, registers all of it in `pool.all`, and returns
--- one. Each row costs an ApplyLayout and an EnableCellMouse at build, which is why they are built
--- five at a time rather than on demand.
function WindowProto:Acquire()
    local pool = self.pool
    return NS.Pool.Acquire(pool, function()
        local first
        for i = 1, Const.POOL_GROW_STEP do
            local fresh = NS.Row.New(self)
            fresh:ApplyLayout(self.layout)
            fresh:EnableCellMouse()
            pool.all[#pool.all + 1] = fresh
            if i == 1 then first = fresh else pool.free[#pool.free + 1] = fresh end
        end
        return first
    end)
end

--- Return every active row to the free list.
---
--- `Release` runs through the library's `before` hook, so it still sees the row while it is shown
--- and the library hides it immediately after — in the same call.
---
--- RANK STABILITY IS THE LIBRARY'S PROMISE NOW, not ours. `ReleaseAll` parks the active set
--- backward as of LibKa0s-Pool-1.0 minor 3, so the next run of `Acquire` calls hands position 1
--- the widget position 1 had. This function used to reverse the parked segment itself to get
--- that; against a library that already parks backward that reversal double-reverses and brings
--- the flicker straight back, so it came out in the same commit as the minor-3 payload. There is
--- nothing to add here — the ordering invariant is still required, and
--- tests/test_window.lua still pins it.
function WindowProto:HideAll()
    NS.Pool.ReleaseAll(self.pool, function(row) row:Release() end)
end

--- Release only the rows past `keep`, leaving ranks 1..keep bound in their slots.
---
--- Render's per-pass counterpart to HideAll (review F-007): the active array IS
--- the slot array, so a row drawn last pass is drawn again without a trip through
--- the pool. LibKa0s-Pool-1.0 has no single-object release, so this parks by hand
--- under the library's own contract: BACKWARD, so the next Acquire hands rank
--- keep+1 the widget it had.
function WindowProto:ReleaseSurplus(keep)
    local active, free = self.pool.active, self.pool.free
    for i = #active, keep + 1, -1 do
        local row = active[i]
        row:Release()
        row:Hide()
        free[#free + 1] = row
        active[i] = nil
    end
end

--- Anchor `row` at `slot`, unless it already sits there under this layout.
--- A layout is config arithmetic, so a row whose slot and layoutVersion both
--- match is exactly where this would put it again.
function WindowProto:PlaceRow(row, slot)
    local version = self.layoutVersion
    if row.__anchoredVersion == version and row.__anchoredSlot == slot then return end
    row.__anchoredVersion, row.__anchoredSlot = version, slot

    local layout = self.layout
    local y = NS.Row.OffsetFor(layout, slot)
    row.frame:ClearAllPoints()
    if layout.growUp then
        row.frame:SetPoint("BOTTOMLEFT", self.body, "BOTTOMLEFT", 0, y)
    else
        row.frame:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -y)
    end
end

-- ---------------------------------------------------------------------------
-- The refresh
-- ---------------------------------------------------------------------------

--- Mark the window as needing a redraw. Every message handler ends here and
--- nothing else, which is what makes the throttle the only clock in the file.
--- The largest legal scroll offset for a list of `count` rows.
---
--- Derived from `layout.maxRows`, which is itself derived from the configured
--- frame height — so this is config arithmetic rather than a measurement, and it
--- answers 0 whenever everything already fits.
function WindowProto:MaxScroll(count)
    local visible = (self.layout and self.layout.maxRows) or 1
    local over = (count or 0) - visible
    return (over > 0) and over or 0
end

--- Move the scroll offset by `delta` rows and redraw.
---
--- ONLY THE FLOOR IS APPLIED HERE. The ceiling is the length of a list this
--- function does not have: it runs from a wheel event, between refreshes, and
--- asking the aggregator for a fresh list to find out how long it is would turn
--- a scroll into a meter read. So the offset is allowed to run optimiztically
--- past the end and `Render` clamps it against the list it is actually drawing.
---
--- That is not a shortcut, it is the only ordering that cannot go stale: a
--- remembered row count is one refresh out of date the moment the group changes,
--- and clamping against a stale count is how a scroll silently stops one row
--- short of the bottom.
---
--- @param delta number  rows to move; negative is toward the top
function WindowProto:ScrollBy(delta)
    local want = (self.scrollOffset or 0) + (delta or 0)
    if want < 0 then want = 0 end
    if want == self.scrollOffset then return end

    self.scrollOffset = want
    self:MarkDirty()
    -- The wheel must answer NOW rather than on the next throttle tick, for the
    -- same reason a drill-down click does.
    self.elapsed = self.throttle
end

--- Put the view back at the top. Called when the LIST CHANGES IDENTITY —
--- entering or leaving a breakdown — because an offset carried across is an
--- offset into a list that no longer exists.
function WindowProto:ResetScroll()
    if self.scrollOffset == 0 then return end
    self.scrollOffset = 0
end

function WindowProto:MarkDirty()
    self.dirty = true
end

--- Whether this window should redraw on the throttle tick even though no message
--- has marked it dirty.
---
--- THE METER'S EVENTS ARE NOT A COMPLETE HEARTBEAT, and relying on them alone is
--- why a live window's numbers sat still through a fight.
--- `DAMAGE_METER_CURRENT_SESSION_UPDATED` describes the CURRENT session; a window
--- reading Overall, or pinned to a stored segment, is not what that event is
--- about and can go a whole pull without one arriving. The rows were correct and
--- stale at the same time, which is the worst way for a meter to be wrong.
---
--- So while a fight is on, a SHOWN window polls on the clock it already has.
--- This costs one aggregate per throttle tick per visible window — 0.25s by
--- default, which is exactly the rate a busy pull already drives through the
--- dirty flag — and it costs nothing at all out of combat, where the events are
--- sufficient and a still window should do no work.
---
--- @return boolean
function WindowProto:ShouldPoll()
    if not self.frame:IsShown() then return false end
    -- A COLLAPSED WINDOW HAS NOTHING TO DRAW INTO. This is a real clause and not
    -- an emergent one: `OnUpdate` is installed on `frame`, which stays SHOWN
    -- while minimized -- only the body hides -- so without this the window goes
    -- on aggregating every stat and rendering rows into a hidden body four times
    -- a second, forever.
    if (self.config.frame or {}).minimized then return false end
    if self:IsTest() then return false end
    local inCombat = _G.InCombatLockdown and _G.InCombatLockdown()
    if inCombat then return true end
    return (NS.Secrets and NS.Secrets.IsRestricted()) and true or false
end

local function onUpdate(frame, elapsed)
    local inst = frame.mmWindow
    if not inst then return end
    inst.elapsed = (inst.elapsed or 0) + elapsed
    if inst.elapsed < inst.throttle then return end
    inst.elapsed = 0
    if not inst.dirty and not inst:ShouldPoll() then return end
    inst.dirty = false
    inst:Refresh()
end

--- Can the game's meter give this window anything, and if not, what does it say
--- about why.
---
--- Provider is called in the DOT form its own file publishes it in
--- (`Provider.IsAvailable`): these are plain namespaced functions, not methods,
--- and a colon here would hand it this window as its first argument. A missing
--- Provider is treated as available, because the notice it would raise is about
--- the GAME's meter and there is nothing here to have asked.
---
--- @return boolean available, string|nil reason
local function meterAvailability()
    local Provider = mod("Provider")
    if Provider and Provider.IsAvailable then
        return Provider.IsAvailable()
    end
    return true, nil
end

--- The spell breakdown this window is drilled into, or nil when it is showing
--- the ordinary grid.
---
--- Detected by BuildRows answering non-nil rather than by a mode flag this file
--- would have to keep in step with modules/DrillDown.lua's own idea of what is
--- open. The rows are a plain table, so testing THEM is safe; the title beside
--- them may be a secret string — DrillDown formats the source's
--- ConditionalSecret name into it — so it is passed on as text and never tested.
---
--- @return table|nil rows, string|nil title
local function drillRowsFor(config)
    local DrillDown = mod("DrillDown")
    if DrillDown and DrillDown.BuildRows then
        return DrillDown:BuildRows(config)
    end
    return nil, nil
end

--- The ordered rows the aggregator answers for this window.
---
--- ONE PATH. There is no test branch here any more. Test mode used to hand the
--- renderer a whole separate result table built by a separate function, which
--- made the two modes diverge at every seam nobody thought to duplicate:
--- tooltips found no source, the drill-down opened on nothing, and every fix had
--- to be applied twice. It now substitutes the DATA, at modules/Provider.lua and
--- modules/Roster.lua — the two files that talk to the client — so everything
--- from here down is the live code reading invented numbers.
---
--- Called in the DOT form for the same reason meterAvailability is. "refresh" is
--- the perf bracket this runs inside, passed so the aggregate's capture observes
--- its parent (issue #47).
local function aggregateEntries(Aggregator, config)
    if Aggregator.Build then return Aggregator.Build(config, "refresh") end
    return nil
end

--- Whether the window draws placeholder data.
---
--- ONE DOOR: `/mm test`, or the General page's checkbox, both of which write
--- NS.State.testMode.
---
--- An unlocked window used to imply this, and that coupling was the first bug
--- reported against the addon: a fresh install ships unlocked, so the very first
--- login showed placeholder rows and no amount of unchecking "Preview mode"
--- would clear them — the lock was still forcing it back on. The lock now governs
--- dragging and nothing else.
function WindowProto:IsTest()
    return (NS.State and NS.State.testMode) and true or false
end

--- Draw the window.
---
--- The order matters. Availability is asked FIRST, because a client with the
--- meter switched off has nothing for any of the rest of this to do; then a
--- drill-down replaces the grid entirely if one is open; then the data comes
--- from the aggregator, in preview form when TEST MODE is on; then the rows are
--- drawn.
---
--- Test mode is the ONE door to preview data -- see IsTest above. An unlocked
--- window used to imply it, and this line still said so a release after the
--- coupling was removed.
function WindowProto:Refresh()
    if not (self.frame and self.frame:IsShown()) then return end
    -- A COLLAPSED WINDOW HAS NOWHERE TO DRAW. ShouldPoll's clause covers the
    -- polling half of the tick and nothing else: onUpdate takes an early branch
    -- on `dirty`, and every meter message sets that flag, so without this the
    -- whole aggregate-and-render ran for a hidden body through an entire fight.
    -- It also stops ShowNotice putting the "waiting for combat data" line back
    -- over a window that has been collapsed.
    if (self.config.frame or {}).minimized then return end

    local t0 = Perf.on and debugprofilestop()

    local available, reason = meterAvailability()
    if not available then
        self:ShowNotice(reason)
        if t0 then Perf.Note("refresh", debugprofilestop() - t0) end
        return
    end

    -- No aggregator is a BROKEN INSTALL, not a switched-off meter, so it draws
    -- nothing rather than telling the player to enable something that is already
    -- on. The chat printer has already said the addon is half-loaded.
    local Aggregator = mod("Aggregator")
    if not Aggregator then
        self:HideAll()
        if t0 then Perf.Note("refresh", debugprofilestop() - t0) end
        return
    end

    -- A PINNED SEGMENT THAT NO LONGER EXISTS IS DROPPED HERE, before anything
    -- reads it. sessionID is persisted, so a window can come back from a reload,
    -- a meter reset or a zone change still pointed at a segment the client has
    -- discarded — and a stale id does not error, it silently reads an empty
    -- session, which looks exactly like a broken addon.
    --
    -- Cleared in the CONFIG rather than shadowed on the instance so there is one
    -- resolved answer: modules/Aggregator.lua, the tooltip and the drill-down all
    -- read the pin through Database.PinnedSegment, and a session id is never reused, so
    -- forgetting one loses nothing that could come back.
    self:DropStaleSegment()

    -- A window that is drilled into a player's spell breakdown draws THAT
    -- instead of the grid, so it is asked before the aggregator is. The "is this
    -- a breakdown" answer travels on as its own boolean and the title travels
    -- beside it as text only — a secret string may be drawn, never truth-tested.
    local drillRows, title = drillRowsFor(self.config)
    if drillRows then
        self:Render(drillRows, false, true, title)
        if t0 then Perf.Note("refresh", debugprofilestop() - t0) end
        return
    end

    local preview = self:IsTest()
    self:Render(aggregateEntries(Aggregator, self.config), preview)

    if t0 then Perf.Note("refresh", debugprofilestop() - t0) end
end

--- The entry for the row at list index `i`: the player's when `i` is the last
--- drawn slot and there is a pin, the natural one otherwise. A helper so the
--- pin costs Render no branch of its own.
local function slotEntry(entries, i, pin, lastIndex)
    if pin and i == lastIndex then return entries[pin] end
    return entries[i]
end

--- The list index of the player to pin into the last drawn slot, or nil.
---
--- "Always show yourself" asked of the rows this window DRAWS — `layout.maxRows`
--- of them from `1 + offset` — rather than of the aggregator's 40-row ceiling,
--- which on the shipped `maxRows = 0` never bit. A breakdown's rows are spells,
--- so there is no player to pin.
---
--- @param entries table
--- @param offset number  the clamped scroll offset
--- @param isDrill boolean|nil
--- @return number|nil
function WindowProto:SelfPin(entries, offset, isDrill)
    local Aggregator = mod("Aggregator")
    if isDrill or not Aggregator then return nil end
    return Aggregator.SelfPinIndex(entries, 1 + offset, self.layout.maxRows,
        (self.config or {}).rows)
end

--- The scroll offset to draw from, clamped and stored back.
---
--- THE CLAMP LIVES HERE, and only here. `ScrollBy` applies the floor; this
--- applies the ceiling, against the list actually being drawn rather than
--- against a remembered count that a group change would have made stale.
---
--- Re-clamping every draw is what covers the list shrinking under a stationary
--- offset, which happens constantly — a player leaves the group, a breakdown has
--- fewer spells than the grid had rows — and an offset past the end would render
--- an empty window that scrolling could not fix.
local function clampScroll(win, count)
    local offset = win.scrollOffset or 0
    local maxOffset = win:MaxScroll(count)
    if offset > maxOffset then offset = maxOffset end
    if offset < 0 then offset = 0 end
    win.scrollOffset = offset
    return offset
end

--- Bind the visible slice of `entries` to row widgets, slot by slot.
---
--- @return number  the rows drawn
local function drawSlice(win, entries, offset, isDrill)
    local maxRows = win.layout.maxRows
    -- "Always show yourself", against the slice actually drawn (see SelfPin).
    local pin = win:SelfPin(entries, offset, isDrill)
    local lastIndex = offset + maxRows

    local drawn = 0
    for i = 1 + offset, #entries do
        if drawn >= maxRows then break end
        local entry = slotEntry(entries, i, pin, lastIndex)
        if entry then
            drawn = drawn + 1
            local row = win.pool.active[drawn] or win:Acquire()
            win:PlaceRow(row, drawn)
            row:Update(entry, drawn)
        end
    end
    return drawn
end

--- The empty state an EMPTY live grid shows: a gold title and a line under it,
--- centered in the body (the Ka0s Drop Watcher empty state's look).
---
--- An empty grid with no explanation reads as a broken addon. The meter is
--- available (Refresh established that above), there is simply nothing in the
--- session yet — which is the normal state between pulls. A preview and a
--- breakdown say nothing. Built on first use, inside the body (so a collapsed
--- window hides it with the body), and kept apart from `notice`, which still
--- says why the meter is unavailable. Its two lines keep the game's
--- GameFontNormalLarge and GameFontHighlightSmall sizes, Drop Watcher's
--- empty-state sizes, not the window's font, and take the skin's faces and
--- colors through the facade (the heading, then `text.highlight`), recorded so a
--- skin switch repaints them.
local function showWaiting(win, preview, isDrill)
    if preview or isDrill then return end
    local e = win.empty
    if not e then
        e = CreateFrame("Frame", nil, win.body)
        e:SetSize(1, 1)
        e:SetPoint("CENTER", win.body, "CENTER", 0, 0)
        e.title = e:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        e.title:SetPoint("BOTTOM", e, "CENTER", 0, 2)
        e.text = e:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        e.text:SetPoint("TOPLEFT", win.body, "LEFT", 4, -4)
        e.text:SetPoint("TOPRIGHT", win.body, "RIGHT", -4, -4)
        e.text:SetJustifyH("CENTER")
        if NS.Skin then
            NS.Skin.Text(e.title, "heading")
            NS.Skin.Text(e.text, "text.highlight")
        end
        win.empty = e
    end
    e.title:SetText(L["No combat data yet"])
    e.text:SetText(L["Your group's numbers appear here once combat starts."])
    e:Show()
end

--- Put the aggregator's answer on screen.
---
--- The percent text slot used to cost a second full session read per column per
--- refresh: this file asked Provider.GetColumn for every column's group total so
--- the cells could divide by it. modules/Aggregator.lua already holds both
--- operands and already divides — `cell.percent` — so the row path reads that
--- and the extra read is gone.
---
--- @param entries table|nil  the ordered array of rows to draw
--- @param preview boolean
--- @param isDrill boolean|nil  true when these rows are a spell breakdown. A
---   PLAIN boolean, deliberately separate from the title: `drillTitle` can be a
---   secret string and must never be branched on.
--- @param drillTitle string|nil  the breakdown's header line, text only
function WindowProto:Render(entries, preview, isDrill, drillTitle)
    local t0 = Perf.on and debugprofilestop()

    self.notice:Hide()
    if self.empty then self.empty:Hide() end
    -- NO HideAll: rows stay bound across passes. Slot i reuses pool.active[i],
    -- the pool is asked only past it, and ReleaseSurplus returns the rest.

    entries = entries or {}

    -- NO BACK BUTTON. One used to be drawn here and every drill row shifted
    -- down by its height — which is what pushed the last row out through the
    -- bottom of the frame, since `layout.maxRows` is derived from the body
    -- height and knew nothing about a button drawn inside it. Right-click on any
    -- row leaves a breakdown now (modules/Row.lua), so the height is the rows'
    -- again and the overflow cannot recur.

    -- See the note where this script was installed: the body claims the mouse
    -- only while a breakdown is open, so the grid's hover behavior is untouched.
    self.body:EnableMouse(isDrill and true or false)

    local offset = clampScroll(self, #entries)
    local drawn = drawSlice(self, entries, offset, isDrill)
    self:ReleaseSurplus(drawn)

    if drawn == 0 then showWaiting(self, preview, isDrill) end

    -- Park the aggregate on the window so UpdateHeaderText can read the group
    -- total off it. The aggregator already computed the sort column's total
    -- during the pass it just made; re-entering Provider.GetColumn for the same
    -- number would be a second full session read per refresh, on the hot path.
    self.aggregate = entries

    self:UpdateHeaderText(preview, isDrill, drillTitle)

    -- ONE debug line per pass, built inside the gate. A line per row would be
    -- forty allocations a quarter second on a raid, all of them discarded by a
    -- disabled sink (debug-logging-§4).
    if NS.State and NS.State.debug then
        -- Keyed on the window id: two windows sharing the `Render` tag would
        -- otherwise alternate and defeat each other's comparison, so neither
        -- would ever be suppressed and the fix would silently do nothing.
        NS.DebugSteady(self.id, "Render", "window %d drew %d/%d rows%s",
            self.id, drawn, #entries, preview and " (preview)" or "")
    end

    -- Render runs only from Refresh, so its one parent is passed and the capture
    -- OBSERVES the nesting rather than taking the descriptor's word (issue #47).
    if t0 then Perf.Note("render", debugprofilestop() - t0, "refresh") end
end

-- Published for modules/Window_Lifecycle.lua, which resolves it at FILE SCOPE (hence its
-- load-bearing TOC line): Window.New and Resume need the pool constructor and the clock, and
-- both stay here with the refresh chain they belong to -- published, never restated.
NS.WindowInternals.newRowPool = newRowPool
NS.WindowInternals.onUpdate   = onUpdate
