-- modules/Window_Lifecycle.lua
--
-- How ONE window is born, re-pointed, stood down and put away, and the bus wiring
-- that keeps it listening in between: Window.New, RegisterBus / UnregisterBus,
-- SetConfig, Destroy, Suspend and Resume.
--
-- ---------------------------------------------------------------------------
-- WHY THIS IS ITS OWN FILE
-- ---------------------------------------------------------------------------
--
-- modules/Window.lua stood at 1490 lines against layout-§1's 1500-line cap after
-- issue #29's two peels (modules/Window_Header.lua, modules/Window_Placement.lua),
-- and the automated-test disposition ruled that the next change to add lines there
-- peels first. This is the seam that ruling named: the bus wiring and the lifecycle
-- tail sit OUTSIDE the refresh chain issue #29 forbids cutting. They arm the clock
-- and mark the window dirty; they never decide what is drawn. Only these functions
-- moved -- the refresh contract they feed is still stated, and still lives, in
-- modules/Window.lua's header.
--
-- FILE-SCOPE READS, and why the TOC line is load-bearing. This file resolves three
-- things modules/Window.lua publishes -- NS.Window, NS.WindowProto and
-- NS.WindowInternals (the row pool's constructor and the OnUpdate clock, which
-- stay with the chain they belong to) -- so it MUST load after modules/Window.lua.

local _, NS = ...

local MSG = NS.Constants.MSG

local Window      = NS.Window
local WindowProto = NS.WindowProto
local newRowPool  = NS.WindowInternals.newRowPool
local onUpdate    = NS.WindowInternals.onUpdate

-- ---------------------------------------------------------------------------
-- Bus wiring
-- ---------------------------------------------------------------------------
--
-- A PRIVATE target per window (NS.NewBusTarget), never the shared addon object.
-- Every handler does the same two things — invalidate what the message
-- invalidated, then set the dirty flag — because the throttle is the only thing
-- allowed to decide when work happens.

function WindowProto:RegisterBus()
    local bus = NS.NewBusTarget()
    self.bus = bus
    if not bus then return end

    local function dirty() self:MarkDirty() end

    bus:RegisterMessage(MSG.METER_UPDATED, dirty)
    bus:RegisterMessage(MSG.METER_SESSION, dirty)
    bus:RegisterMessage(MSG.METER_RESET, function()
        self:MarkDirty()
    end)
    bus:RegisterMessage(MSG.RESTRICTION_CHANGED, dirty)

    -- A roster change is both: the rows are stale AND the show answer may have
    -- moved, because `hideWhenSolo` is a roster fact. A window hidden by that
    -- rule has no OnUpdate running — a hidden frame's script does not fire — so
    -- the ladder has to be re-run from the message or the window can never come
    -- back when the player groups up.
    bus:RegisterMessage(MSG.ROSTER_CHANGED, function()
        self:RefreshVisibility()
        self:MarkDirty()
    end)

    -- Context messages change the SHOW answer, not the data, so they go through
    -- the ladder rather than through the dirty flag.
    -- A zone change is the one thing that makes an explicit "show this" stale:
    -- the context rules now have something new to say, which is their whole job.
    bus:RegisterMessage(MSG.ZONE_CHANGED, function()
        self:ClearForcedShow()
        self:RefreshVisibility()
    end)
    bus:RegisterMessage(MSG.ENTERING_WORLD, function()
        self:ClearForcedShow()
        self:RefreshVisibility()
    end)
    -- The player's own state. These are the SAME shape as the roster case above
    -- and they are here for the same reason: modules/Visibility.lua is a
    -- predicate that publishes nothing, so a rule it owns takes effect only when
    -- something re-runs the ladder — and there is no fallback, because onUpdate
    -- refreshes DATA and never re-asks NS.ShouldShow. Without these two
    -- subscriptions, "hide when skyriding" waits for the next zone change,
    -- group change or settings write, which is indistinguishable from not
    -- working. ClearForcedShow is deliberately NOT called: `/mm toggle` is an
    -- explicit request about THIS window, and mounting up is not a reason to
    -- forget it.
    bus:RegisterMessage(MSG.PLAYER_STATE_CHANGED, function()
        self:RefreshVisibility()
    end)
    bus:RegisterMessage(MSG.COMBAT_CHANGED, function()
        self:RefreshVisibility()
    end)
    bus:RegisterMessage(MSG.TEST_MODE_CHANGED, function()
        -- ApplyTitle as well as MarkDirty: the red TEST MODE marker lives in the
        -- title, and the title is only rewritten on a config change — so without
        -- this the marker appeared on the next settings edit rather than on the
        -- toggle that turned it on.
        self:ApplyTitle()
        self:RefreshVisibility()
        self:MarkDirty()
    end)

    -- Entering or leaving a drill-down changes what this window draws entirely.
    -- The name comes from the bus catalog and from nowhere else: a hand-spelled
    -- fallback beside it is a second definition of the same string, and the day
    -- the catalog's value changes the sender moves and the listener does not
    -- (architecture-§4).
    bus:RegisterMessage(MSG.DRILLDOWN_CHANGED,
        function(_, payload)
            local id = payload and payload.windowId
            if id ~= nil and id ~= self.id then return end
            -- The list is about to become a different list. An offset carried
            -- from the grid into a breakdown points into rows that are not there.
            self:ResetScroll()
            self:MarkDirty()
            self.elapsed = self.throttle   -- a click must not wait a full tick
        end)

    -- A settings write. The payload names a window id when the change was
    -- window-relative, so a twenty-window profile does not re-apply nineteen
    -- windows because one of them was edited.
    bus:RegisterMessage(MSG.CONFIG_CHANGED, function(_, payload)
        local id = payload and payload.windowId
        if id ~= nil and id ~= self.id then return end
        self:ApplyConfig()
        self:RefreshVisibility()
        self:MarkDirty()
    end)
end

function WindowProto:UnregisterBus()
    if self.bus and self.bus.UnregisterAllMessages then
        self.bus:UnregisterAllMessages()
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

--- Build one window instance around a stored config.
---
--- @param config table  a window config from db.profile.windows
--- @return table
function Window.New(config)
    local inst = setmetatable({
        id     = config.id,
        config = config,
        -- `free`/`active` are LibKa0s-Pool-1.0's; `all` is host state living beside them, for
        -- the layout and lock passes that must reach PARKED rows too. The library's pool is a
        -- plain table with no metatable precisely so a host can do this. See core/PoolSetup.lua.
        pool   = newRowPool(),
        dirty  = true,
        elapsed = 0,
    }, WindowProto)

    inst:ApplyConfig()
    inst:RegisterBus()
    -- No clock while stood down (slash-commands-§7): WindowManager:Resume arms
    -- every instance, this one included, at stand-up.
    if not (NS.IsStoodDown and NS.IsStoodDown()) then inst.frame:SetScript("OnUpdate", onUpdate) end
    inst:RefreshVisibility()

    return inst
end

--- Point an existing instance at a (possibly rewritten) config table and
--- re-apply everything. Used by the manager after a copy or a rename, so a
--- window is never torn down and rebuilt for a settings change.
function WindowProto:SetConfig(config)
    self.config = config
    self.id = config.id
    self:ApplyConfig()
    self:RefreshVisibility()
    self:MarkDirty()
end

--- Take the window off screen and off the bus for good. The frames survive —
--- WoW never frees one — but nothing references them and nothing drives them.
function WindowProto:Destroy()
    self:UnregisterBus()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
    if self.anchor then self.anchor:Hide() end
    self:HideAll()
end

--- Stop doing work without changing what the user configured (performance-§6).
--- The OnUpdate goes, which is what stops the coalesced pass already queued from
--- firing once more inside a measurement window and being attributed to an addon
--- that is supposed to be idle. Bus registrations stay: Resume republishes, and
--- a window that had torn them down would never hear it.
function WindowProto:Suspend()
    if self.frame then self.frame:SetScript("OnUpdate", nil) end
end

function WindowProto:Resume()
    if self.frame then self.frame:SetScript("OnUpdate", onUpdate) end
    self:RefreshVisibility()
    self:MarkDirty()
end
