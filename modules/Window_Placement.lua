-- modules/Window_Placement.lua
--
-- Where ONE window sits, how big it is, whether it is locked, and whether it is
-- on screen at all — everything the player's hands and the visibility ladder do
-- to a window's frame, as opposed to what the refresh loop draws inside it.
--
-- ---------------------------------------------------------------------------
-- WHY THIS IS ITS OWN FILE
-- ---------------------------------------------------------------------------
--
-- modules/Window.lua was 2746 lines against layout-§1's 1500-line cap. Issue #29
-- names the seam that peeled modules/Window_Header.lua off it, and forbids
-- cutting inside the loop — the refresh contract, layout rule R3, the cached
-- config, frame construction, applying config, the row pool and the refresh, all
-- of which stayed whole. The header band alone does not get the remainder under
-- the cap, so this is a second cut along a line the file's own banners already
-- drew: `Show / hide` was one of them, and the position, size and lock block
-- above it is the other half of the same question — a window's placement and its
-- presence, neither of which is in that chain.
--
-- READING GEOMETRY BACK IS STILL FORBIDDEN, and this is the file that lives off
-- that rule. Rule R3 is stated in modules/Window.lua's own header and did not
-- move: SavePosition and SaveSize ask `inst.anchor`, the bare frame that has
-- never held a meter value, and never `inst.frame`. Only these functions moved.
--
-- The methods hang on the SAME `WindowProto` modules/Window.lua builds and
-- publishes as `NS.WindowProto`, resolved at FILE SCOPE — so this file MUST load
-- after modules/Window.lua, and the TOC says so at its line.

local _, NS = ...

local WindowProto = NS.WindowProto

--- Position from the STORED anchor. Never from the frame — see the file header.
function WindowProto:ApplyPosition()
    local pos = (self.config.frame or {}).position or {}
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint(pos.point or "CENTER", UIParent,
        pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
end

--- Persist where the user just dragged the window to.
---
--- GetPoint is called on the ANCHOR, which has never held a value and never will
--- — that is the entire reason it exists (see the file header). Reading it off
--- `self.frame` would work today and would become a Lua error the first time a
--- cell inside it received a secret.
function WindowProto:SavePosition()
    local point, _, relativePoint, x, y = self.anchor:GetPoint()
    local frameCfg = self.config.frame
    if not frameCfg then return end
    frameCfg.position = {
        point         = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x             = x or 0,
        y             = y or 0,
    }
    if NS.State and NS.State.debug and NS.Debug then
        NS.Debug("Window", "%d moved to %s %d,%d", self.id, point or "CENTER",
            math.floor(x or 0), math.floor(y or 0))
    end
end

--- Persist the size the user just dragged out, from the size the OnSizeChanged
--- handler was HANDED rather than from a getter.
---
--- `frame.width` and `frame.height` ARE ROWS -- the Frame page's two sliders --
--- so the drag that ends on them is a schema-row write (architecture-§5), and it
--- goes through the seam as one batch addressed to THIS window by id: one
--- `[Set]` line per dimension, announced once, whichever window the settings
--- panel is pointed at.
--- Called from the grip's OnDragStop only; OnSizeChanged merely remembers the
--- size, so a drag costs one write however many frames it lasts.
function WindowProto:SaveSize()
    if not (self.config.frame and self.pendingWidth) then return end
    local width  = math.floor(self.pendingWidth + 0.5)
    local height = math.floor(self.pendingHeight + 0.5)
    self.pendingWidth, self.pendingHeight = nil, nil
    if NS.SetByPaths then
        NS.SetByPaths({
            { "window.frame.width",  width },
            { "window.frame.height", height },
        }, self.id)
    end
    self:ApplyConfig()
    self:MarkDirty()
end

--- Refuse to be dragged smaller than the grid needs.
---
--- Enforced by the CLIENT through SetResizeBounds rather than by clamping in Lua
--- on every OnSizeChanged tick: the frame simply stops following the cursor, so
--- there is no fight between the drag and the clamp and no frame in which the
--- window is drawn at an illegal size.
---
--- Both minimums come off the layout, which is where they were computed from the
--- same arithmetic that placed the columns — so the size the window refuses to go
--- below and the size the grid needs cannot drift apart.
---
---   width   the name column, plus every stat column at Const.COLUMN_MIN_WIDTH,
---           plus the seams and the padding.
---   height  the title bar, the column-header strip and ONE row. A window with
---           room for no rows at all is a window showing nothing, which is not a
---           size anybody means to drag to.
function WindowProto:ApplyResizeBounds()
    local anchor = self.anchor
    if not (anchor and anchor.SetResizeBounds) then return end
    anchor:SetResizeBounds(self.layout.minWidth, self.layout.minHeight)
end

--- Lock / unlock.
---
--- THE CELLS ALWAYS OWN THE MOUSE. They used to own it only while the window was
--- locked, on the theory that an unlocked window should drag as one object — and
--- since a window ships UNLOCKED, the effect was that tooltips and drill-down did
--- not work at all until you happened to lock it. A meter whose numbers you
--- cannot hover is most of a meter missing, and nothing about an unlocked window
--- says that is why.
---
--- Dragging moved to the TITLE BAR instead, which is where a window is dragged
--- from in every other frame in the game, and which is a region no cell occupies.
--- So the two are no longer in competition and the lock governs exactly one
--- thing: whether that title bar responds.
---
--- SetMovable is deliberately left true throughout — flipping it is how a window
--- ends up permanently undraggable until a reload.
function WindowProto:ApplyLock()
    local locked = self.locked
    -- MINIMISE IS THE GRIP'S OTHER AUTHOR, so this has to agree with it or
    -- `/mm lock off` resurrects a grip over a collapsed window. Whichever of the
    -- two runs last wins, so both ask the same question.
    if self.grip then
        local down = (self.config.frame or {}).minimised and true or false
        self.grip:SetShown(not locked and not down)
    end

    for _, row in ipairs(self.pool.all) do
        row:EnableCellMouse()
    end

    -- Written as a branch, not as `locked and nil or "LeftButton"`: that
    -- expression can never produce nil, because `or` takes over the moment the
    -- left side is falsy, so the "locked" case would still register the drag.
    if locked then
        self.dragBar:RegisterForDrag()
    else
        self.dragBar:RegisterForDrag("LeftButton")
    end
    -- MOUSE STAYS ON, ALWAYS. Locking is what `RegisterForDrag()` above does --
    -- an empty registration is what stops the drag -- and the mouse flag was only
    -- ever suppressing hover as a side effect. A locked window is exactly when a
    -- player wants the chrome to fade, so a mouse-disabled dragBar fires no
    -- OnEnter and modules/HeaderControls.lua's reveal is dead in its commonest
    -- case.
    self.dragBar:EnableMouse(true)
end

-- ---------------------------------------------------------------------------
-- Show / hide
-- ---------------------------------------------------------------------------

--- Consult the ladder and act on it.
---
--- The decision is NS.ShouldShow's — one ordered function, with perf suspend as
--- step 0 — and it is refused AT THE SOURCE: a window that must not show never
--- reaches the aggregator at all, rather than building rows and hiding them
--- afterwards (performance-§6).
--- Re-run the show ladder, honoring an explicit request.
---
--- `forcedShow` IS WHY CHANGING A SETTING NO LONGER CLOSES THE WINDOW.
---
--- The ladder is consulted on every CONFIG_CHANGED, and a window that is on
--- screen because the player asked for it — `/mm toggle`, or leaving test mode —
--- is not on screen because the ladder said so. So the first unrelated settings
--- edit re-ran the ladder, got "no" from a context rule, and hid the window. From
--- the player's side that is "the settings panel closes my meter", which is both
--- baffling and, as an explanation, wrong.
---
--- An explicit request therefore STICKS until the context genuinely changes — a
--- zone change or a login, which is when a context rule has something new to say.
--- It is deliberately not permanent: the visibility rules exist to follow you
--- between a dungeon and a city, and a flag that outlived that would quietly
--- disable the whole page.
---
--- AND IT OVERRIDES A CONTEXT RULE ONLY. It used to override the whole ladder,
--- which made the master enable do nothing: any window the player had ever shown
--- carried `forcedShow`, so unticking "Enable Multi Meters" re-ran the ladder, got
--- "disabled", and was overruled by a flag that means "I asked for this window in
--- this zone" — a far narrower statement than the one the master switch makes.
--- The same bug let a window come back from under a perf suspend, which step 0 of
--- the ladder exists specifically to forbid ("a suspended capture must be inert:
--- nothing may re-show a window behind suspend's back", performance-§6).
---
--- The reasons below are steps 0 and 1, which are the addon-wide answers. Matched
--- on the REASON rather than re-asking each source, because the ladder already
--- names the step that decided and a second reading of NS.Perf.suspended here is
--- a second place for the two to disagree.
local UNFORCEABLE = {
    ["suspended"] = true,   -- step 0: a suspended capture must be inert
    ["disabled"]  = true,   -- step 1: the master switch is not a context rule
    -- step 1b: General visibility set to Never. The same statement the master
    -- switch makes, made on the same tab -- so an explicit "show this window" must
    -- not overrule it either. The dropdown's two COMBAT answers are deliberately
    -- absent: those ARE context rules and behave like the per-window pair.
    ["hidden"]    = true,
    ["no window"] = true,   -- not a decision at all -- there is nothing to show
}

function WindowProto:RefreshVisibility()
    local show, reason = true, "shown"
    if NS.ShouldShow then show, reason = NS.ShouldShow(self.config) end

    if not show and self.forcedShow and not UNFORCEABLE[reason] then
        show, reason = true, "requested"
    end

    if show then
        if not self.frame:IsShown() then
            self.frame:Show()
            self:MarkDirty()
            self.elapsed = self.throttle   -- draw on the next tick, not in 0.25s
        end
    else
        self:Hide(reason)
    end
    return show, reason
end

function WindowProto:Show()
    self:BuildFrame()
    -- An explicit request. See RefreshVisibility for why it is remembered.
    self.forcedShow = true
    self.frame:Show()
    self:MarkDirty()
    -- THE SAME CLOCK NUDGE RefreshVisibility GIVES ITS OWN SHOW BRANCH, and it
    -- has to be repeated here because this path never goes through that one: it
    -- shows the frame itself. Without it `/mm toggle` put the chrome — the
    -- backdrop, the title bar, the column headers, all of which BuildFrame has
    -- already made — on screen in the same frame, and left the rows to the next
    -- throttle tick, up to a whole `data.throttle` away. A hidden frame runs no
    -- OnUpdate, so `elapsed` is frozen at whatever the hide left behind and the
    -- wait is neither fixed nor short. The window appeared to assemble itself in
    -- two stages.
    self.elapsed = self.throttle   -- draw on the next tick, not in 0.25s
end

--- Forget an explicit show request. Called on a real context change, which is
--- when the visibility rules have something new to say.
function WindowProto:ClearForcedShow()
    self.forcedShow = nil
end

function WindowProto:Hide(reason)
    if not self.frame then return end
    if self.frame:IsShown() and NS.State and NS.State.debug then
        NS.Debug("Window", "%d hidden (%s)", self.id, tostring(reason or "?"))
    end
    -- A DELIBERATE hide cancels a deliberate show. Closing the window with the X
    -- or with `/mm toggle` and having it reappear on the next settings edit would
    -- be the same bug pointed the other way.
    if reason == "closed" or reason == "toggled" then self.forcedShow = nil end
    self.frame:Hide()
    self:HideAll()
end

function WindowProto:IsShown()
    return self.frame and self.frame:IsShown() and true or false
end

