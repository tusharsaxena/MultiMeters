-- core/Namespace.lua
--
-- The addon's identity, and the one factory every message-bus consumer goes
-- through. Nothing here has a side effect: no frame, no event registration, no
-- SavedVariables read. That is deliberate — this file loads near the top of the
-- core block, so anything it did would happen before the addon has decided
-- whether it is even going to run.
--
-- WHY IT IS NOT core/Constants.lua. Constants owns values the DISPLAY reasons
-- about (the stat catalog, the shipped font, the bus names). This file owns who
-- the addon IS — name, version, chat tag — plus the bus-target factory, which is
-- infrastructure rather than a value. Keeping them apart means a reader chasing
-- "what is this addon called" and a reader chasing "which stats can it show"
-- never open the same file.
--
-- TOC POSITION: after Compat, EnvSetup, MediaSetup and Constants in the core
-- block. The hard constraint is core/EnvSetup.lua FIRST, because resolveVersion()
-- below runs at load and reads the TOC manifest through NS.Meta — the
-- LibKa0s-Env-1.0 seam — rather than touching C_AddOns directly (architecture-§1:
-- every cross-patch call lives behind a seam). Constants sitting ahead of this
-- file is fine in both directions:
-- Constants reads nothing this file publishes, and nothing here reads
-- NS.Constants. Everything AFTER this point — State, Secrets, CoreSetup,
-- PerfSetup, DebugLogSetup, MultiMeters, Database, and all of
-- modules/ and settings/ — may read NS.PREFIX / NS.name / NS.version at load
-- time, so this file must stay above them.

local addonName, NS = ...

-- Chat tag prepended to every user-facing chat line (slash-commands-§4). Single
-- source of truth: core/CoreSetup.lua hands the printer a FUNCTION that re-reads
-- this field, so a later retag is never frozen into the printer. Cyan is the
-- collection's mandated tag color; the bracketed short form is the addon's slash
-- verb in caps, matching /mm.
NS.PREFIX = "|cff00ffff[MM]|r"

-- Gray color opener for de-emphasized "notice" chat lines — something the user
-- should see but not be alarmed by (options-ui-§2). Wrap the message BODY only
-- (`GRAY .. text .. "|r"`); the cyan [MM] tag stays full-color. The canonical
-- consumer is the options-panel combat refusal, which declines rather than
-- defers.
NS.GRAY = "|cff9d9d9d"

--- One player's class color as three plain numbers, or nil when the class is not
--- known.
---
--- ONE READER FOR ALL FOUR SURFACES that can wear a class color: the bars and the
--- name in modules/Row.lua, that file's cell text under `text.classColor`, the
--- header lines in modules/Window.lua under `header.classColor` /
--- `columnHeader.classColor`, and the tooltip under `tooltip.classColor`. Four
--- private lookups into RAID_CLASS_COLORS is the duplicate that drifts the first
--- time one of them grows a fallback the others do not have.
---
--- `classFilename` is the token WoW's own table is keyed by ("MAGE", "PRIEST")
--- and is NeverSecret, which is what makes a class color legal to compute at the
--- height of a pull when every number beside it is opaque (design §4).
---
--- NIL IS AN ANSWER, never a tenth color. An unknown class means "no class
--- information", and every caller decides for itself what to draw instead --
--- white for a name, the shared neutral for a bar, the configured color for a
--- line of text. Substituting one here would make that decision for all of them.
---
--- The global is read at CALL time, not captured: RAID_CLASS_COLORS is Blizzard's
--- and this file loads early.
---
--- @param classFilename string|nil
--- @return number|nil r, number|nil g, number|nil b
function NS.ClassRGB(classFilename)
    if type(classFilename) ~= "string" then return nil end
    local classes = _G.RAID_CLASS_COLORS
    local c = classes and classes[classFilename]
    if not c then return nil end
    return c.r, c.g, c.b
end

--- One statistic's color as three plain numbers, or nil when the key has none.
---
--- ONE READER FOR EVERY SURFACE THAT WEARS THE PALETTE, exactly as ClassRGB above
--- is for class colors, and added for the same reason: the palette became a
--- SETTING (General -> Statistic colors), and five files each doing their own
--- `Const.STAT_COLORS[key]` would have been five surfaces that ignored it.
---
--- THE CONSTANT IS THE FALLBACK, NOT THE DEAD LETTER. It answers for a key the
--- profile has never stored, for a stat added to the catalog after a profile was
--- written, and for a degraded install with no database at all -- which is the
--- case that decides the shape here: a window must still draw its palette when
--- there is nothing to read a setting out of.
---
--- Plain numbers throughout: no part of this is a meter value, so none of it is
--- secret and all of it is legal at the height of a pull (design §4).
---
--- @param statKey string|nil
--- @return number|nil r, number|nil g, number|nil b
function NS.StatColor(statKey)
    if type(statKey) ~= "string" then return nil end

    local shipped = NS.Constants and NS.Constants.STAT_COLORS
    shipped = shipped and shipped[statKey]
    -- A key with no shipped entry has no row in the settings panel either
    -- (settings/Schema.lua generates one per palette entry), so there is nothing
    -- stored for it and nothing to fall back to.
    if not shipped then return nil end

    local stored = NS.GetSetting and NS.GetSetting("statColors." .. statKey)
    if stored ~= nil and NS.RGBA then
        local r, g, b = NS.RGBA(stored, shipped[1], shipped[2], shipped[3], 1)
        return r, g, b
    end

    return shipped[1], shipped[2], shipped[3]
end

--- The LOCAL player's class color, for a surface with no row to ask about.
---
--- The window's own chrome -- the title bar, the column-header strip, the header
--- controls, the backdrop and the border -- is about the WINDOW rather than about
--- any one player, so "class color" there can only mean yours (options-ui-§17's
--- "everything else takes the player's").
---
--- THROUGH THE LIBRARY'S ONE RESOLVER, published as NS.ClassColor by
--- core/CoreSetup.lua: options-ui-§17 puts the lookup in LibKa0s so nine addons
--- read the same table and cache it the same way, and this addon's own copy of it
--- was one of the three that were merged. What stays private is ClassRGB above,
--- which answers for a classFilename rather than for a unit token and has no
--- library equivalent -- a meter row is a GUID and a class name, not a unit.
---
--- Resolved at CALL time: core/CoreSetup.lua loads after this file.
---
--- @return number|nil r, number|nil g, number|nil b
function NS.PlayerClassRGB()
    local resolve = NS.ClassColor
    if not resolve then return nil end
    return resolve("player")
end

-- The folder name, which is also the AceAddon name, the SavedVariables stem and
-- the Interface\AddOns path segment. Taken from the vararg rather than written
-- out so a rename cannot leave one of the four behind.
NS.name = addonName

-- Fallback version stamp, used only when the TOC manifest cannot be read (an
-- older client without C_AddOns, or the headless test harness where there is no
-- manifest at all). The manifest is the better source because it cannot drift
-- from the packaged build (slash-commands-§3) — a hand-edited constant can.
local FALLBACK_VERSION = "1.0.0"

--- Resolved once at load: the packaged version if the client can tell us, the
--- literal above otherwise. Read by `/mm version`, the perf descriptor's record
--- stamp and the options panel header.
---
--- Resolved HERE rather than lazily because LibKa0s-Perf-1.0 takes `version` as
--- a plain string at :New time and cannot defer it — a nil here stamps every
--- capture record "v?", which is unattributable the moment it leaves the session
--- (performance-§8).
local function resolveVersion()
    local v = NS.Meta("Version")
    if type(v) == "string" and v ~= "" then return v end
    return FALLBACK_VERSION
end

NS.version = resolveVersion()

-- Kept as its own field so a caller that genuinely wants "what the source says"
-- (a test asserting the fallback path, a bug report comparing the two) can ask
-- for it without re-deriving the literal.
NS.FALLBACK_VERSION = FALLBACK_VERSION

-- ---------------------------------------------------------------------------
-- The bus record: LibKa0s-Bus-1.0
-- ---------------------------------------------------------------------------
--
-- THE STAND-DOWN IS WHY THIS EXISTS (slash-commands-§7). A bus target is
-- anonymous: it is created inside the consumer that wants it, it subscribes in
-- a closure, and nothing else has ever held a reference to it. That is fine
-- while the addon only ever goes one way, and it is exactly what makes a TOTAL
-- stand-down impossible -- `NS.StandDown` cannot unregister what it cannot
-- reach, and a registration it cannot reach is one the client goes on walking
-- for an addon the player switched off.
--
-- So every target this factory makes is TRACKED, and since LibKa0s v1.55.0 the
-- record is the library's (`LibKa0s-Bus-1.0`, LibKa0s/docs/api/Bus/version-1-docs.md
-- is its contract). This file wrote the same record by hand until then --
-- message-only, weak-keyed -- and three sibling addons wrote their own. The three
-- names below are what the rest of the addon calls, and they did not move.
--
-- WHAT THE RECORD DOES, in the terms a receiver can see:
--   * StandDown takes every tracked event AND message registration down through
--     AceEvent's own raw unregister, and keeps the record.
--   * StandUp replays the record as it is NOW. A receiver that dropped a
--     registration while the addon was down stays dropped -- `WindowProto:
--     UnregisterBus` on a destroyed window is the real case -- and one that
--     subscribed while down goes live here. Replay is correct rather than lazy
--     because a bus subscription in this addon is unconditional: no consumer
--     subscribes to a different set depending on a setting, so "rebuild from
--     current state" (performance-§6) and "replay what was recorded" are the same
--     set. A consumer that ever grows a conditional subscription moves that
--     decision into its own re-wire.
--   * While the bus is down a registration is RECORDED, NOT MADE, which is why
--     core/LifecycleSetup.lua's standUp brings the bus up before anything else.
--   * StandUp is refused while the latch still holds the addon down: `isDown`
--     asks core/LifecycleSetup.lua's NS.IsStoodDown, late-bound because that file
--     loads after this one. Inside the latch's own standUp callback the latch has
--     already recorded the edge, so the predicate answers false there.
--
-- THE DEGRADATION STUB is the untracked-target stub options-ui-§1 names and the
-- API document's worked example prints: each receiver still gets a private
-- AceEvent target (the receiver rule below holds), but nothing is recorded, so a
-- disable on an install with no LibKa0s leaves those registrations live. Stated in
-- docs/ARCHITECTURE.md's Known limitations; such an install has already lost the
-- options toolkit, the slash dispatcher and the latch, and says so in chat.
local Bus = LibStub and LibStub("LibKa0s-Bus-1.0", true)
if not Bus then
    Bus = {
        New = function(_, d)
            return {
                name = d and d.name,
                NewTarget = function()
                    local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
                    if not AceEvent then return nil end
                    local t = {}; AceEvent:Embed(t); return t
                end,
                StandDown = function() return 0 end,
                StandUp   = function() return 0, {} end,
            }
        end,
        Catalog = function(_, messages) return messages end,
    }
end

-- Published for tests/test_surface_parity.lua, which holds the stub above to the
-- live `LibKa0s-Bus-1.0` surface. Nothing in the addon calls through it.
NS.BusLib = Bus

NS.busRecord = Bus:New{
    name   = addonName,
    isDown = function() return NS.IsStoodDown ~= nil and NS.IsStoodDown() end,
}

--- A fresh AceEvent-embedded table for a message-bus / event RECEIVER
--- (architecture-§4), tracked by the record above.
---
--- Any consumer that is NOT itself an AceAddon module -- a window instance, the
--- settings panel, the aggregator's throttle -- MUST own a private target from
--- this factory rather than registering on the shared addon object.
--- CallbackHandler keys callbacks by (message, target), so two receivers of one
--- message registered on the SAME object silently clobber each other and only
--- the last registrant ever fires (anti-pattern #32). This addon is especially
--- exposed to that: every window subscribes to the same refresh messages, and
--- there can be many windows.
---
--- A consumer that retires a target empties it (`UnregisterAllMessages`), and
--- the record lets go of it; there is no separate retire call.
---
--- @return table|nil  an AceEvent-embedded table, or nil when AceEvent-3.0 is
---   absent (a broken install -- callers treat that as "no bus" and degrade).
function NS.NewBusTarget()
    return NS.busRecord:NewTarget()
end

--- Drop every bus registration every tracked target holds, keeping the record.
--- @return number  the recorded entries taken down (0 when already down)
function NS.BusStandDown()
    return NS.busRecord:StandDown()
end

--- Put every recorded bus registration back, as the record stands now.
---
--- A replayed entry that raises is dropped from the record rather than aborting
--- the rest of the stand-up, and named here through the debug seam: in practice
--- only a registration made while down can do that, since nothing validated it.
--- @return number  the entries made live
function NS.BusStandUp()
    local replayed, rejected = NS.busRecord:StandUp()
    if rejected and #rejected > 0 and NS.Debug then
        NS.Debug("Bus", "rejected on stand-up: %s", table.concat(rejected, ", "))
    end
    return replayed
end
