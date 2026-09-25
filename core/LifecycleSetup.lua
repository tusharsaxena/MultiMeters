local addonName, NS = ...

-- core/LifecycleSetup.lua -- the ONE latch, and the addon's ONE teardown.
--
-- slash-commands-§7 (`The disabled state is total`). Disabled means the addon is
-- NOT RUNNING. Not hidden, not quiet, not skipping a repaint -- not running. The
-- player who unticks *Enable Ka0s Multi Meters* has asked for the outcome they
-- would get by unticking the addon in Blizzard's own list, minus the /reload.
--
-- ── WHY THIS IS NOT A SECOND TEARDOWN PATH ───────────────────────────────────
--
-- This addon already shipped the machinery: `Provider:Suspend`, `WindowManager:
-- Suspend` and the show ladder's step 0, built for performance-§6's second arm.
-- Disable declined to use it and implemented itself as a DRAW GATE instead --
-- `NS.ShouldShow` read the stored switch as one rung of the show ladder, every
-- one of the addon's twenty-one game-event registrations stayed live, every bus
-- subscription stayed live, and the client went on walking the registration list
-- on every UNIT_SPELLCAST_SUCCEEDED in a raid for an addon that claimed to be
-- off. That is anti-pattern #85, and the addon did not stop watching -- it
-- stopped reacting.
--
-- So there is exactly one way down and exactly one way back up, and BOTH reasons
-- to be inert are named holds on it: `disabled`, taken from the stored `enabled`
-- path, and `perf`, taken by LibKa0s-Perf-1.0 for Experiment B. Releasing one
-- MUST NOT stand up an addon the other is still holding down -- which is
-- reachable today, because `/mm disable` is a live verb during a suspended arm.
--
-- ── TOC POSITION ─────────────────────────────────────────────────────────────
--
-- AFTER core/CoreSetup.lua and BEFORE core/PerfSetup.lua, and the second half is
-- a HARD constraint rather than tidiness: from Perf minor 12 `descriptor.
-- lifecycle` is REQUIRED and `:New` raises without it, so a PerfSetup that
-- loaded first would take the addon down at load. Everything this file's two
-- callbacks reach -- the module layer, the window registry, the bus registry --
-- is resolved at CALL time, because modules/ loads after core/.

local Lifecycle = LibStub and LibStub("LibKa0s-Lifecycle-1.0", true)

--- Resolve one runtime module at CALL time, never hoisted: this file loads
--- before modules/, so a load-time lookup would answer nil forever. Both shapes
--- are tried because a module is free to be an AceAddon child or a plain NS
--- table, and the teardown must not be the file that pins that choice.
local function mod(name)
    local m = NS[name]
    if m then return m end
    if NS.GetModule then return NS:GetModule(name, true) end
    return nil
end

-- ---------------------------------------------------------------------------
-- The teardown
-- ---------------------------------------------------------------------------

-- Each helper below is one numbered step of `standDown`'s own doc comment
-- (further down this file), broken out so every function in this file stays
-- under the collection's complexity limit. The split is purely structural --
-- `standDown` still runs them in exactly this order and nothing else changed.

-- 1. The game events. All twenty-one of them, on the one AceEvent target that
--    owns them, plus the settle timer core/MultiMeters.lua arms.
local function standDownEvents()
    if NS.UnregisterAllEvents then NS:UnregisterAllEvents() end
    if NS.CancelAllTimers then NS:CancelAllTimers() end
    if NS.ResetStatePending then NS.ResetStatePending() end
end

-- 2. The AceAddon children. Each is its own AceEvent target, so each owns its
--    own message subscriptions and `UnregisterAllMessages` on the addon object
--    would not reach a single one of them.
local function standDownModules()
    if NS.IterateModules then
        for _, m in NS:IterateModules() do
            if m.UnregisterAllMessages then m:UnregisterAllMessages() end
        end
    end
end

-- 4. The windows: the OnUpdate that drives the coalesced refresh, and the
--    per-window bus target. A coalescing repaint timer left armed to wake up
--    and find a flag is the shape slash-commands-§7 names as the single most
--    expensive one.
local function standDownWindows()
    local wm = mod("WindowManager")
    if wm and wm.Suspend then wm:Suspend() end
end

-- 5. The provider stops ASKING the meter for anything, so a read during the
--    stand-down answers an empty column rather than a live one.
local function standDownProvider()
    local provider = mod("Provider")
    if provider and provider.Suspend then provider:Suspend() end
end

-- 6. A staggered chat dump already queued. `C_Timer.After` has no handle to
--    cancel, so modules/Export.lua bumps a generation instead and the queued
--    callbacks return without sending -- which is the only cancel available.
local function standDownExport()
    local export = NS.Export
    if export and export.CancelSend then export.CancelSend() end
end

-- 7. Re-run the visibility pass so its debug line and `/mm debug diag` record
--    the stood-down answer now rather than at the next edge. It hides NOTHING:
--    Evaluate publishes nothing, touches no frame and runs only under debug.
--    The windows already on screen go in step 4: WindowManager:Suspend re-runs
--    each window's own RefreshVisibility, which NS.ShouldShow's latch step now
--    refuses, and that same step keeps them down.
local function standDownVisibility()
    local vis = mod("Visibility")
    if vis and vis.Refresh then vis:Refresh() end
end

--- Make the addon genuinely inert, in the same turn as the write.
---
--- EVERY REGISTRATION ACTUALLY UNREGISTERED, never gated. The order below is the
--- addon's own dependency order read backwards -- game events first, because
--- core/MultiMeters.lua is the ONLY file that owns one (architecture-4) and
--- stopping it at the source is what stops the whole fan-out; then the bus, whose
--- subscribers are what the fan-out reaches; then the windows, which are the last
--- thing still holding a script.
---
--- HIDING IS NOT DONE FROM HERE, and that is performance-§6's rule rather than a
--- shortcut. `NS.ShouldShow` reads the latch as step 0, so the show decision
--- answers no AT THE SOURCE -- nothing, not a combat transition, not a target
--- swap, not a settings write, can re-show a window behind the switch's back. A
--- frame hidden imperatively comes back; a ladder that says no does not.
---
--- NO SECURE OR ATTRIBUTE WORK IS PENDED, because this addon does none: it has no
--- state driver, no attribute driver and no secure-attribute rewrite (grep the
--- tree for `SetAttribute`). slash-commands-§7 permits a disabled addon to keep
--- PLAYER_REGEN_ENABLED registered for exactly that pending completion; this
--- addon has nothing to complete, so it keeps NOTHING and the registration set
--- goes to empty. An addon that later grows secure work adds the hold-pending
--- here and releases it on that one event -- it does not start gating handlers.
local function standDown()
    standDownEvents()
    standDownModules()

    -- 3. Every anonymous bus target (core/Namespace.lua's registry).
    if NS.BusStandDown then NS.BusStandDown() end

    standDownWindows()
    standDownProvider()
    standDownExport()
    standDownVisibility()
end

--- Put it all back, FROM CURRENT STATE and never from a snapshot taken on the
--- way down (performance-§6). A column toggled, a window created or a visibility
--- rule changed while the addon was off comes back as it is NOW: `NS:OnEnable`
--- re-reads nothing it cached, each module's `OnEnable` re-registers its own
--- fixed set, and `WindowManager:Resume` calls `Init` first so a window created
--- while down is built before anything is resumed.
local function standUp()
    -- The bus FIRST. LibKa0s-Bus-1.0 records a registration made while the bus is
    -- down without making it, so a receiver a module's OnEnable (re)subscribes, or
    -- a window WindowManager:Resume builds, would sit deaf until the replay -- and
    -- anything published before that point would reach no one. Up first, every
    -- later step registers live and publishes to receivers that are listening.
    if NS.BusStandUp then NS.BusStandUp() end

    if NS.OnEnable then NS:OnEnable() end

    if NS.IterateModules then
        for _, m in NS:IterateModules() do
            if m.OnEnable then m:OnEnable() end
        end
    end

    local provider = mod("Provider")
    if provider and provider.Resume then provider:Resume() end

    local wm = mod("WindowManager")
    if wm and wm.Resume then wm:Resume() end

    local vis = mod("Visibility")
    if vis and vis.Refresh then vis:Refresh() end
end

NS.StandDown, NS.StandUp = standDown, standUp

-- ---------------------------------------------------------------------------
-- The latch
-- ---------------------------------------------------------------------------

if not Lifecycle then
    -- A missing vendored lib must degrade, not error at load. The stub covers
    -- every member the addon reaches -- `Set` from the enable row and the verbs,
    -- `Reevaluate` from the profile callbacks, `IsHeld`/`IsDown` from the show
    -- ladder and the slash gate, `Hold`/`Release` from LibKa0s-Perf-1.0 (which is
    -- itself absent on such an install, but a stub that omits a member is not a
    -- fallback, it is a crash moved to a rarer code path).
    --
    -- It is a real latch rather than a no-op: without the library the addon still
    -- has to go down when the player switches it off, and a stub that answered
    -- "never held" would turn a missing library into a master switch that does
    -- nothing. The cause half is core/CoreSetup.lua's shared clause.
    local held, down = {}, false
    local function reevaluate()
        local any = next(held) ~= nil
        if any == down then return false end
        down = any
        if down then standDown() else standUp() end
        return true
    end
    NS.lifecycle = {
        name       = addonName,
        Hold       = function(_, key) held[key] = true; return reevaluate() end,
        Release    = function(_, key) held[key] = nil;  return reevaluate() end,
        Set        = function(self, key, want)
            if want then return self:Hold(key) end
            return self:Release(key)
        end,
        IsHeld     = function(_, key) return held[key] == true end,
        IsDown     = function() return down end,
        Holds      = function()
            local out = {}
            for key in pairs(held) do out[#out + 1] = key end
            table.sort(out)
            return out
        end,
        Reevaluate = reevaluate,
        PrintHolds = function() return false end,
    }
else

NS.lifecycle = Lifecycle:New({
    name      = addonName,
    standDown = standDown,
    standUp   = standUp,
    print     = function(line) if NS.Print then NS.Print(line) end end,
})

end

-- The hold key is the LIBRARY's exported constant, never a literal: two majors
-- and every host in the collection have to spell it the same way, and the day one
-- of them reads "Disabled" the hold is taken by something nothing releases. The
-- fallback spelling is only reached on an install with no library at all, where
-- the stub above is the only thing reading it.
local HOLD_DISABLED = Lifecycle and Lifecycle.HOLD_DISABLED or "disabled"

-- ---------------------------------------------------------------------------
-- The `disabled` hold
-- ---------------------------------------------------------------------------

--- Take or release the `disabled` hold from the stored enable path.
---
--- THE ONE SPELLING. The checkbox's `onChange`, `/mm enable`, `/mm disable`,
--- `/mm set enabled false` and the three AceDB profile callbacks all land here,
--- because `lc:Set("disabled", not enabled)` written five times is written
--- backwards once (`LibKa0s-Lifecycle-1.0`, version 1).
---
--- `== false` rather than `not`, and it is load-bearing: NS.GetSetting answers
--- nil before NS:InitDB has built the store, and a nil read by a truthiness test
--- would take the addon down on a half-loaded install. Absent means "nothing has
--- said otherwise", which is not off.
---
--- @return boolean  whether this call changed the latch's state
function NS.SyncEnabledHold()
    local lc = NS.lifecycle
    if not lc then return false end
    local off = NS.GetSetting ~= nil and NS.GetSetting("enabled") == false
    return lc:Set(HOLD_DISABLED, off)
end

--- Is the addon standing down right now -- for any reason?
---
--- Published so the show ladder and the window seams all ask ONE question
--- rather than several that could disagree. It is `IsDown`, not
--- `IsHeld("disabled")`, everywhere the question is "should this happen": a
--- perf-suspended addon must refuse the same work.
--- @return boolean
function NS.IsStoodDown()
    local lc = NS.lifecycle
    return lc ~= nil and lc:IsDown() == true
end

--- Is the addon DISABLED specifically -- the player's switch, not the harness's.
---
--- The slash gate asks this one rather than `IsStoodDown`, because the refusal
--- line names `/mm enable` and that is the wrong advice to give someone whose
--- addon is merely mid-capture. slash-commands-§7 keeps `perf` on the live list
--- for the same reason. The launcher's `isEnabled` asks this one too
--- (core/LauncherSetup.lua): its Enabled box is the `enabled` setting, and a
--- perf capture must not untick it.
--- @return boolean
function NS.IsDisabled()
    local lc = NS.lifecycle
    return lc ~= nil and lc:IsHeld(HOLD_DISABLED) == true
end
