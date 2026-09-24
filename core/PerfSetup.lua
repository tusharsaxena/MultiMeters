local addonName, NS = ...

-- core/PerfSetup.lua — wires the addon into LibKa0s-Perf-1.0.
--
-- The probe, the guided A/B run, the record schema and the clickable step panel
-- are the library's. This file supplies the part only this addon can know: which
-- paths are worth measuring, and what "inert" means here.
--
-- TOC POSITION: seventh in the core block — after core/CoreSetup.lua, before
-- core/DebugLogSetup.lua — and BEFORE every module that takes
-- `local Perf = NS.Perf` as a load-time upvalue (all of modules/, which loads
-- after core/). That last constraint is the binding one. Two others are worth
-- stating because they are not symmetrical:
--   * core/Namespace.lua has run, so NS.version exists — the descriptor takes
--     `version` as a plain STRING resolved once at :New, so a file sitting higher
--     in the block would capture nil and stamp every capture record "v?",
--     unattributable the moment it leaves the session (performance-§8). This is
--     a HARD constraint: move this file above Namespace and captures go anonymous.
--   * core/DebugLogSetup.lua has NOT run yet, and that is fine. Every seam that
--     reaches the console — `log`, `showLog`, `decorate` — resolves NS.DebugLog
--     inside its own closure at CALL time rather than capturing it here, so the
--     sink is found the moment it exists. Do not "optimize" those into upvalues.
--
-- WHERE THE SIGNAL IS, and why the bucket list looks like this. This addon has
-- exactly one hot path and it is event-driven rather than per-frame: a busy pull
-- fires DAMAGE_METER_CURRENT_SESSION_UPDATED far faster than anything needs to
-- redraw, which is why the window coalesces to an interval instead of refreshing
-- per event. So the two questions a capture has to answer are "how much does the
-- event handler itself cost at raid rate" (meterEvent) and "what does one
-- coalesced pass cost" (refresh) — and the buckets under `refresh` say which
-- third of that pass to look at: reading the columns off C_DamageMeter (which
-- the aggregate does, so that read sits inside it), joining them by GUID and
-- ordering them, or drawing.
--
-- `renderRow` nests inside `render` rather than beside it because a 20-player
-- group times 7 columns is 140 cells per pass, and per-row is the only grain at
-- which "the window is slow" becomes "the window is slow because of how many rows
-- it has". A reader comparing two captures months apart cannot be expected to
-- know which totals overlap, so the nesting is DECLARED rather than left as
-- prose, and a parent must never be summed with its children.

local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)

if not lib then
    -- A missing vendored lib must degrade, not error at load. The addon's own
    -- function is unaffected by the absence of a diagnostics harness, but the
    -- stub has to cover EVERY member the addon reaches: the hot-path gate `on`
    -- and sink `Note`, the `suspended` flag every show decision consults as step
    -- 0 of its ladder, and OnCommand — because `/mm perf` is registered
    -- unconditionally in settings/Slash.lua, so something has to answer it.
    --
    -- `Open`/`Close` are answered too. Nothing in this addon uses Shape B today
    -- (the inline Shape A form is mandatory on anything running per refresh), but
    -- a stub that omits a member is not a fallback — it is a crash moved to a
    -- rarer code path.
    NS.Perf = {
        on        = false,
        suspended = false,
        Note      = function() end,
        Open      = function() end,
        Close     = function() end,
        -- The cause half is core/CoreSetup.lua's shared clause
        -- (NS.LIBKA0S_MISSING); only the consequence is this seam's. Read at
        -- CALL time rather than captured into a load-time local, so the TOC
        -- order of the two setup files can never freeze a nil in.
        OnCommand = function()
            return { NS.LIBKA0S_MISSING .. ", so performance measurement is unavailable." }
        end,
    }
    return
end

NS.Perf = lib:New({
    name    = addonName,
    -- THE FOLDER NAME, and a different question from the one above even though this
    -- addon answers both with the same string. `name` is what the panel's frames are
    -- seeded from; `addonName` is what libs/LibKa0s/PerfPanel.lua builds the close
    -- control's texture path from, and it reads `d.addonName or d.name` -- so leaving
    -- this out would still be right, by luck, until the day the two strings diverge.
    -- `title` below is already a THIRD string, which is what a rename reaches for
    -- first. Passed explicitly for the same reason core/DebugLogSetup.lua passes it,
    -- and the two descriptors are deliberately the same shape.
    addonName = addonName,
    title   = "Ka0s Multi Meters",
    slash   = "/mm",
    sv      = "MultiMetersPerfDB",
    -- The TOC manifest is the better source than the in-code constant: it cannot
    -- drift from the packaged build (slash-commands-§3). NS.version remains the
    -- fallback for a client without the metadata API.
    --
    -- Both are resolved by NS.Version() — core/EnvSetup.lua's seam over
    -- LibKa0s-Env-1.0 (architecture-§1) — rather than by an inline ladder here.
    -- That inline ladder is what this file used to carry, and re-spelling it was
    -- how a call site quietly dropped the pre-11.x rung. settings/Slash.lua asks
    -- the same function, so `/mm version` and a capture record cannot disagree.
    version = NS.Version(),

    -- Ordered for the report, with nesting declared. These keys are the contract
    -- the module layer brackets against — a bracket naming a key that is not here
    -- still records, it just never appears in the report, which is the quiet
    -- failure mode this list exists to prevent.
    buckets = {
        { key = "meterEvent" },                          -- a DAMAGE_METER_* event handler
        -- The two narrow listeners, each top-level and each its own bucket so a
        -- capture can say which one costs what (MultiMeters-R-17). Both events stay
        -- registered all session for one use apiece; these are MEASUREMENT ONLY,
        -- and whether either registration should narrow is decided from the numbers
        -- they produce, not here.
        { key = "spellEvent" },                          -- UNIT_SPELLCAST_SUCCEEDED: the feign check
        { key = "systemEvent" },                         -- CHAT_MSG_SYSTEM: the whisper-to-nobody check
        { key = "refresh" },                             -- one coalesced window refresh pass
        -- NO `within`, and that is the finding rather than an omission (issue
        -- #47). A column read runs inside `aggregate` on a refresh, inside
        -- `targets` on a tooltip, and inside nothing from a diagnostic, so any
        -- one parent named here is false on the other paths. Provider.GetColumn
        -- passes Perf.Note whichever parent its caller ran inside instead, and a
        -- capture that exercised both paths reports it observed inside more than
        -- one parent.
        { key = "providerRead" },                        -- one C_DamageMeter column read
        { key = "aggregate",    within = "refresh" },    -- GUID join + ordering
        { key = "render",       within = "refresh" },    -- window render
        { key = "renderRow",    within = "render"  },    -- one row's cells
        { key = "tooltip" },                             -- a tooltip build
        -- Nested under `tooltip`, because that is the only thing that triggers
        -- one — and because it is the expensive half: modules/Targets.lua makes
        -- a provider call PER ENEMY to reconstruct a list the API does not carry.
        -- Its own bucket precisely so the cost of the Targets section is separable
        -- from the cost of the tooltip that holds it.
        { key = "targets",      within = "tooltip" },    -- the target cross-reference
    },

    -- THE LATCH, and it is REQUIRED from Perf minor 12 (LibKa0s v1.41.0).
    --
    -- `suspend` and `resume` USED TO LIVE HERE and are gone rather than kept
    -- alongside: from minor 12 nothing on this descriptor reads them, and leaving
    -- them would be two live copies of this addon's own teardown -- the perf arm's
    -- and the disable arm's -- which is exactly how the two drift apart on the
    -- first module added after the second was written (anti-pattern #85).
    --
    -- What they said is not lost. Their bodies are core/LifecycleSetup.lua's
    -- `standDown` / `standUp`, which the `disabled` hold reaches too, and which
    -- had to grow considerably to be a TOTAL stand-down rather than the partial
    -- one a capture could get away with: the twenty-one game events, the module
    -- message subscriptions and every anonymous bus target come down there now,
    -- where suspend left all three registered and merely stopped the work.
    --
    -- `P.Suspend()` takes `lifecycle.HOLD_PERF` and `P.Resume()` releases it --
    -- and only that. Whether the addon actually comes back is the latch's
    -- decision, which says no while the player's `disabled` hold is still taken,
    -- so a run that finished after the player switched the addon off mid-capture
    -- can no longer bring it back to life.
    lifecycle = NS.lifecycle,

    -- Perf output is deliberately NOT gated on NS.State.debug, unlike NS.Debug.
    -- That gate keeps the addon free when idle; a perf run is explicit user
    -- action and none of it executes unless someone typed `/mm perf start`.
    -- Gating it meant a user who started a run without first enabling debug
    -- logging watched a console that stayed empty while a capture plainly ran.
    log = function(line)
        if NS.DebugLog and NS.DebugLog.Add then
            NS.DebugLog:Add("Perf", line)
        elseif NS.Print then
            NS.Print(line)
        end
    end,

    print = function(line) if NS.Print then NS.Print(line) end end,

    -- `start`, `report` and `dump` want the console in front of the user.
    -- Everything else must not pop it open: a lifecycle line mid-pull is the last
    -- moment to throw a window on screen.
    showLog = function()
        if NS.DebugLog and NS.DebugLog.Show and not NS.DebugLog:IsShown() then
            NS.DebugLog:Show()
        end
    end,

    -- NO `L`, deliberately, and this is a trap rather than an omission.
    --
    -- NS.L carries the metatable fallback the standard mandates: a miss returns
    -- the KEY rather than nil, so NS.L["STEP_START"] is the string "STEP_START".
    -- Handing the library an addon-wide locale table satisfies its override check
    -- for EVERY key, its own strings become unreachable, and the panel renders
    -- STEP_START / STEP_MEASURE_A / PANEL_TITLE_SUFFIX verbatim — visible only in
    -- game. This addon has no perf translations, so it passes nothing and lets
    -- the library's English through.

    -- NO `decorate`, DELIBERATELY, and its absence is the fix rather than an
    -- omission.
    --
    -- This addon shipped one, and its entire body was a close button. It called
    -- `NS.DebugLog.MakeCloseButton(frame, api.Hide)` — two arguments onto a
    -- three-argument function — so the panel drew a multiplication sign while the
    -- console two inches away wore the collection's mark. The dropped third
    -- argument is the addon folder name, and a texture path that is never built
    -- draws nothing and raises nothing: luacheck was clean, 1,206 tests were green,
    -- and the only witness was a screenshot.
    --
    -- From PerfPanel minor 4 (LibKa0s v1.10.2) the library builds that control
    -- itself, from `addonName or name` — both of which this descriptor now states
    -- above — at the same 18px inset from the same corner. So the hook was a
    -- second copy of library behavior that could fall behind it, and had; deleting
    -- it is what the standard now asks for (performance-§4, debug-logging-§12,
    -- anti-pattern #65). tests/test_perfsetup.lua pins BOTH directions — the name
    -- present, the hook absent — and then shows the real panel against a spy on
    -- the library's factory, because the descriptor's shape says nothing about
    -- what reaches the screen.
    --
    -- Add one back only for chrome the library does not draw, and build its close
    -- control through `NS.MakeCloseButton` (core/CoreSetup.lua) — the one wrapper
    -- that carries the folder name — never with a bare call to any factory.
})
