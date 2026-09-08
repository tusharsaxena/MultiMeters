-- settings/Profiles.lua
--
-- The Profiles page: AceDBOptions' create / switch / copy / reset / delete UI,
-- hosted inside this addon's own canvas.
--
-- ---------------------------------------------------------------------------
-- THE ONE PLACE AceConfigDialog IS PERMITTED
-- ---------------------------------------------------------------------------
--
-- Every other page in this addon is drawn by LibKa0s-Options-1.0 from NS.Schema,
-- and AceConfig is not in the picture at all. This page is the documented
-- exception, for one reason: the options table is not ours. AceDBOptions
-- generates it — every scope dropdown, every confirmation, every profile-list
-- refresh — and re-expressing that as schema rows would mean maintaining a copy
-- of AceDB's own profile model that goes stale the first time AceDB adds a
-- scope. So the library's page shell hosts an AceGUI container, and
-- AceConfigDialog renders into it.
--
-- The exception is scoped to CONTENT. The canvas, the header, the breadcrumb
-- and the registration are still Helpers.CreatePanel, so this page looks like
-- the other twelve rather than like a bolted-on Ace window.
--
-- ---------------------------------------------------------------------------
-- NO DEFAULTS BUTTON, AND IT IS NOT AN OVERSIGHT
-- ---------------------------------------------------------------------------
--
-- "Restore defaults" on this page would mean deleting the player's profiles,
-- which is not what anyone means by restoring a default (options-ui-§3). The
-- header button is suppressed here, and the same predicate is enforced a second
-- time in settings/OptionsSetup.lua's skipRestoreAll so that `/mm resetall` and
-- the global Defaults sweep skip these rows too. Two enforcements of one rule,
-- because the destructive controls this page hosts are the library's, not ours.
--
-- ---------------------------------------------------------------------------
-- SetRenderer DRAWS THIS PAGE, AND ONE MESSAGE FINISHES THE JOB
-- ---------------------------------------------------------------------------
--
-- This page goes through H.SetRenderer exactly like the other eight, and the
-- reason is the combat refusal. The Blizzard AddOns sidebar reaches a canvas
-- without going through OpenOptionsPanel, so a page with no guard of its own is
-- reachable mid-pull — and that guard is the library's, inline in SetRenderer,
-- so a page that hand-rolls its own copy has a refusal that drifts from the
-- other eight the first time the library's wording or behaviour moves.
--
-- SetRenderer's contract is "draw once, and again when the library says you are
-- dirty", and that is one draw short here: the widget tree belongs to
-- AceConfigDialog, which re-reads the active profile only when the dialog is
-- fed again. The missing draw is a profile switch made from somewhere else —
-- the slash command, a reset, a copy — and the PROFILE_CHANGED listener at the
-- foot of Build supplies exactly that. The page used to buy the same freshness
-- by re-Opening on EVERY show, and it paid for it with the refusal above.

local _, NS = ...

local L = NS.L

local PAGE = "profiles"

local function Build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    if not LibStub then return nil end

    local H = NS.Helpers
    if not (H and H.CreatePanel) then return nil end

    local AceDBOptions    = LibStub("AceDBOptions-3.0",    true)
    local AceConfig       = LibStub("AceConfig-3.0",       true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    local AceGUI          = NS.AceGUI or LibStub("AceGUI-3.0", true)
    if not (AceDBOptions and AceConfig and AceConfigDialog and AceGUI) then return nil end

    -- AceDB may have failed to initialize (core/Database.lua degrades rather
    -- than raising), and an options table built over a nil db raises inside
    -- AceDBOptions instead of here.
    if not (NS.db and NS.db.profile) then return nil end

    -- Registered once, at build time. The table AceDBOptions returns is live
    -- against NS.db, so it does not need rebuilding when the profile changes.
    AceConfig:RegisterOptionsTable("MultiMeters-Profiles", AceDBOptions:GetOptionsTable(NS.db))

    local ctx = H.CreatePanel("MultiMetersProfilesPanel", L["Profiles"], {
        pageKey        = PAGE,
        defaultsButton = false,   -- explicit, per the note above
    })

    -- An AceGUI SimpleGroup parented to our body. AceConfigDialog:Open accepts
    -- any AceGUI container as its target, so pointing it here lands the
    -- AceDBOptions widgets inside this canvas instead of opening a second
    -- floating window over the settings panel.
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Fill")
    container.frame:SetParent(ctx.body)
    container.frame:ClearAllPoints()
    container.frame:SetPoint("TOPLEFT",     ctx.body, "TOPLEFT",      8, -8)
    container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8,  8)

    H.SetRenderer(ctx, function()
        AceConfigDialog:Open("MultiMeters-Profiles", container)
    end)

    -- The draw SetRenderer's dirty rule cannot see for itself. Every path that
    -- makes the active profile a different thing lands on core/Database.lua's
    -- single PROFILE_CHANGED emitter, and H.RefreshPanel is the library's own
    -- seam for a page that repaints off its host's bus rather than off a library
    -- widget's set(): shown, it re-renders now; hidden, it is marked dirty and
    -- re-renders on its next show. Nothing extra is needed for a change made ON
    -- this page — AceConfigDialog re-Opens the container itself after every
    -- control it activates.
    --
    -- A PRIVATE bus target rather than NS: CallbackHandler keys callbacks by
    -- (message, target), so a second PROFILE_CHANGED receiver registered on the
    -- shared addon object would silently clobber the first (architecture-§4,
    -- anti-pattern #32).
    local bus = NS.NewBusTarget and NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.Constants.MSG.PROFILE_CHANGED, function()
            H.RefreshPanel(ctx, true)
        end)
    end

    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["Profiles"])
end

if NS.RegisterOptionsPage then
    NS.RegisterOptionsPage(PAGE, L["Profiles"], Build)
end
