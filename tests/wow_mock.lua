-- tests/wow_mock.lua
--
-- Ka0s Multi Meters' half of the WoW-API mock, layered over the shared base in
-- tests/_kit/mock_base.lua (testing-§1).
--
-- Returns a BUILDER — `mockmod.build()` — so every instance gets a fresh, fully
-- isolated fake client. Nothing is shared between two builds: not the meter data,
-- not the frame registry, not LibStub's library table.
--
-- ---------------------------------------------------------------------------
-- WHAT THE BASE CONTRIBUTES, AND WHAT THIS FILE ADDS
-- ---------------------------------------------------------------------------
--
-- build() starts from the vendored base builder and then OVERWRITES PER KEY, per
-- the kit's README. There is no merge machinery, because the base hands back a
-- fresh table on every call.
--
-- Inherited from the base and used as-is: `time`, `date`, `GetTime`, `wipe`,
-- `tinsert`, `tremove`, `C_Timer`, `debugprofilestop` + `__profileMs`, the
-- Settings canvas registry (`Settings`, `__mainPanel`, `__subcategories`,
-- `SettingsPanel`, `__settingsClosed`), `hooksecurefunc`, `CreateColor`,
-- `PlaySound`, `StaticPopupDialogs` / `StaticPopup_Show`, `UISpecialFrames`,
-- `DEFAULT_CHAT_FRAME`, the AceDB-3.0 fake (whose copyDefaults reproduces AceDB's
-- real merge-in-place semantics, which core/Database.lua's `== nil` window fill
-- depends on), the AceGUI-3.0 widget factory, and LibStub itself — including its
-- STRICT silent flag, which is what proves every soft-optional
-- `LibStub("LibKa0s-...-1.0", true)` in this addon actually passed `true`.
--
-- Overwritten here, and why:
--
--   * THE FRAME MODEL. The base's frame stub answers any PascalCase method from
--     a metatable and returns THE FRAME ITSELF, so `bar:CreateFontString()` and
--     the bar are one object and "which widget got the text" is unanswerable.
--     This addon's whole output is text and bar values written onto per-cell
--     FontStrings and StatusBars (modules/Row.lua), so distinct region objects
--     with REAL STATE are a correctness requirement here, exactly as they are in
--     KickCD and WhatGroup. The base's own header names this as a divergence it
--     expects consumers to make in their own extender.
--   * NOTHING OF ACE'S EVENT OR ADDON LIBRARY. Both used to be replaced here: the
--     AceEvent message half, for `UnregisterAllMessages` and string-method
--     dispatch, and AceAddon, for NewModule / GetModule. Kit revision 17 (LibKa0s
--     v1.31.0) models both from CallbackHandler and AceAddon-3.0 themselves, so
--     the copies went; see LibStub extras below for what a suite reaches instead.
--   * `C_AddOns`. The base deliberately does not stub it (see its header). This
--     addon reads the TOC manifest through it for NS.version and for the perf
--     descriptor's record stamp, so it is stubbed HERE, where a test that wants
--     the deprecated-global fallback can clear it with `mocks.C_AddOns = nil`.
--     Clearing `_G.C_AddOns` is NOT enough: `mocks._G` is the loader environment,
--     so `_G.C_AddOns` resolves back through this table.
--   * `string` / `format`. See tests/mock_secrets.lua.
--
--
-- ---------------------------------------------------------------------------
-- THE CONTROL SURFACE, in one place
-- ---------------------------------------------------------------------------
--
-- Secrets      mocks.secret(v) · mocks.secretTable(t) · mocks.reveal(v)
--              mocks.isSimulatedSecret(v) · mocks.SECRET_ERROR
--              mocks.setRestricted(b) · mocks.setSecretValues(b) · mocks.setCursor(x, y) · mocks.setMouseDown(btn, b)
--              mocks.setSecretsAccessible(b) · mocks.setRestrictionState(n)
-- Meter        mocks.setMeterAvailable(ok, reason) · mocks.setSession(...)
--              mocks.setSourceDetail(...) · mocks.buildSession(opts)
--              mocks.setSessionDuration(...) · mocks.setAvailableSessions(list)
--              mocks.resetMeterCalls() · mocks.__meter
-- Menus        mocks.MenuUtil · mocks.__lastMenu (root:Nth(kind, n))
-- Group        mocks.setGroup(spec) · mocks.setPet(unit, guid) · mocks.setSolo()
--              mocks.setInstance(type) · mocks.setInCombat(b)
--              mocks.setInVehicle(b) · mocks.__group
-- Player state mocks.setDelve(b) · mocks.setDelveVia(which) · mocks.setMounted(b)
--              mocks.setShapeshiftForm(id) · mocks.setCanGlide(b)
--              mocks.setInHousing(b) · mocks.setOnTaxi(b)
--              mocks.setInPetBattle(b) · mocks.setDeadOrGhost(b)
--              mocks.setEventInvalid(name)
-- Frames       mocks.__frames (creation order) · mocks.__frameByName
--              mocks.__stubFrame(objectType, parent, name)
-- Manifest     mocks.__toc (Version / Title / Notes)
-- Timers       mocks.__timers · mocks.__fireTimers() (base) · mocks.__flushTimers()

local repoRoot = ... or "."
local kitMockBase = dofile(repoRoot .. "/tests/_kit/mock_base.lua")

-- The two halves this file was peeled into (layout-§1's 1500-line cap; issue #34).
-- Neither is a SUITE -- Kit.assertSuiteInventory never sees them and tests/run.lua's
-- SUITES list must not name them -- and both are resolved through `repoRoot` for the
-- same reason the kit base is: a run may be started from anywhere, so nothing here
-- guesses at a relative path.
--
--   tests/mock_secrets.lua  the secret simulator, and the string/format overrides
--                           that go with it (THE SECRET SIMULATOR, below, is its
--                           header now -- read it there)
--   tests/mock_frame.lua    the frame model: real widget objects with real state,
--                           and GameTooltip
--
-- Loaded ONCE, at file scope, not per build. The simulator's registry is what makes
-- a secret recognizable, and a second load of that chunk would mint a second
-- registry; the frame model is handed the same one so `SetText` and `SetValue` agree
-- with `mocks.isSimulatedSecret` about what they were given.
local Secrets = dofile(repoRoot .. "/tests/mock_secrets.lua")
local Frame   = assert(loadfile(repoRoot .. "/tests/mock_frame.lua"))(Secrets)

local SECRET_ERROR           = Secrets.SECRET_ERROR
local secret                 = Secrets.secret
local secretTable            = Secrets.secretTable
local reveal                 = Secrets.reveal
local isSimulatedSecret      = Secrets.isSimulatedSecret
local isSimulatedSecretTable = Secrets.isSimulatedSecretTable
local makeFrame              = Frame.makeFrame
local unloadable             = Frame.unloadable

-- ===========================================================================
-- The meter fixture
-- ===========================================================================
--
-- Sessions are held as PLAIN SPECS and materialized on read. The materializer is
-- what wraps the secret-bearing fields, so a suite writes ordinary numbers and
-- flips `mocks.setSecretValues(true)` to make the same fixture arrive opaque —
-- which is exactly the transition the addon has to survive.
--
-- The field list below is the addon's own reading of the 12.0 contract, taken
-- from core/Secrets.lua and modules/Provider.lua: amounts, rates, durations and
-- the ConditionalSecret display `name` are secret; GUIDs, class files, spec icon
-- IDs, spell IDs, recap IDs, classifications and the display-type enum are not.
-- `sourceGUID` in particular is the ONLY legal join key in the whole addon, so it
-- is never wrapped.

local SECRET_FIELDS = {
    totalAmount      = true,
    amountPerSecond  = true,
    maxAmount        = true,
    durationSeconds  = true,
    deathTimeSeconds = true,
    overkillAmount   = true,
    name             = true,   -- ConditionalSecret
    -- SecretWhenInCombat, per Blizzard's own annotation on
    -- DamageMeterCombatSource — and the omission that let this harness stay
    -- green while the addon showed an empty grid for every pull it ever ran.
    --
    -- The addon was built on the reading that a meter sourceGUID is never
    -- secret and is therefore its only legal join key. The mock was written from
    -- the same reading, so the restricted cases handed the aggregator a PLAIN
    -- GUID, the GUID join ran, the rows came out, and 771 cases agreed with each
    -- other about a client neither of them had asked. Measured in-game it comes
    -- back secret AND inaccessible: NS.Secrets.IsSafeKey refuses it, every
    -- source is dropped, and the window says "Waiting for combat data" with a
    -- full session behind it.
    --
    -- A fixture is only worth what it refuses to let you get away with.
    sourceGUID       = true,
}

--- Deep-copy `spec`, wrapping the secret-bearing leaves when `wrap` is true.
---
--- A SIMULATED SECRET IS ITSELF A TABLE (see the header), so it is carried
--- through by reference rather than recursed into. Copying it produced a plain
--- empty table with none of the trapping metatable on it — silently stripping
--- the one property the fixture was written to express — so a suite that placed
--- `mocks.secret(x)` in a session spec was testing a plain value and passing for
--- the wrong reason. The SECRET_FIELDS wrapping below is unaffected: it wraps
--- leaves on the way out, after this branch.
local function materialize(spec, wrap)
    if type(spec) ~= "table" then return spec end
    local out = {}
    for k, v in pairs(spec) do
        if isSimulatedSecret(v) or isSimulatedSecretTable(v) then
            out[k] = v
        elseif type(v) == "table" then
            out[k] = materialize(v, wrap)
        elseif wrap and SECRET_FIELDS[k] and v ~= nil then
            out[k] = secret(v)
        else
            out[k] = v
        end
    end
    return out
end

-- ===========================================================================
-- Session fixtures
-- ===========================================================================

-- The class ladder a generated roster walks, one per source and wrapping at the
-- end. Ten distinct classes so a fixture the size of a full party never repeats
-- a class — a repeat would make a class-colour or spec-icon assertion pass for
-- the wrong row.
local DEFAULT_CLASSES = {
    "WARRIOR", "PRIEST", "MAGE", "ROGUE", "HUNTER", "WARLOCK",
    "MONK", "DRUID", "PALADIN", "DEATHKNIGHT",
}

--- buildSession's knobs with every default already resolved, so the two builders
--- below read as a description of the fixture rather than as a pile of `or`s.
--- The defaults are the ones a suite gets by writing `mocks.buildSession()`:
--- five allies, a plausible top parse, and a 212-second run.
---
--- @param opts table|nil  see buildSession
--- @return table
local function sessionOptions(opts)
    opts = opts or {}
    return {
        count           = opts.count or 5,
        top             = opts.top or 4200000,
        step            = opts.step or 0.085,
        prefix          = opts.guidPrefix or "Player-1-",
        classes         = opts.classes or DEFAULT_CLASSES,
        names           = opts.names,
        deaths          = opts.deaths,
        durationSeconds = opts.durationSeconds or 212,
    }
end

-- ===========================================================================
-- The builder
-- ===========================================================================

local function build()
    local M = kitMockBase()

    -- ── secret plumbing, published ─────────────────────────────────────────
    M.SECRET_ERROR        = SECRET_ERROR
    M.secret              = secret
    M.secretTable         = secretTable
    M.reveal              = reveal
    M.isSimulatedSecret   = isSimulatedSecret
    M.isSimulatedSecretTable = isSimulatedSecretTable

    -- Faithful string.format over a simulated secret: a plain pass-through of the
    -- real library for everything else, so `string.rep`, `string.match` and the rest
    -- are untouched. Built per instance in tests/mock_secrets.lua, where the reason
    -- it has to exist at all is written down.
    local mockString, formatShim = Secrets.newStringLibrary()
    M.string = mockString
    M.format = formatShim

    -- ── restriction state ──────────────────────────────────────────────────
    --
    -- Three flags rather than one, because they are three different facts and the
    -- addon reacts to each separately:
    --   __restricted        is the Combat restriction active (drives
    --                       C_RestrictedActions and the InCombatLockdown fallback
    --                       core/Secrets.lua uses on a client without the API)
    --   __secretValues      does the meter hand back opaque values
    --   __secretsAccessible may tainted code still look at them — true during the
    --                       `Activating` dispatch, which is the last legal moment
    --                       for a value sort (design §5)
    M.__restricted        = false
    M.__secretValues      = false
    M.__secretsAccessible = false
    M.__restrictionState  = nil   -- nil = derive from __restricted

    --- Turn the Combat addon restriction on or off.
    ---
    --- Flips `__secretValues` with it, because that is the pairing the client
    --- actually produces; call `mocks.setSecretValues` afterwards to separate them
    --- (the Activating edge is the case that needs it).
    function M.setRestricted(v)
        v = v and true or false
        M.__restricted   = v
        M.__secretValues = v
        M.__inCombat     = v          -- the base's UnitAffectingCombat source
        M.__group.inCombat = v
    end

    function M.setSecretValues(v) M.__secretValues = v and true or false end
    function M.setSecretsAccessible(v) M.__secretsAccessible = v and true or false end

    --- Force the raw Enum.AddOnRestrictionState the API reports. nil restores the
    --- derived answer (Active while restricted, Inactive otherwise).
    function M.setRestrictionState(state) M.__restrictionState = state end

    M.Enum = M.Enum or {}
    -- Real 12.0 values, restated from core/Constants.lua so the mock and the
    -- addon's guarded fallbacks cannot disagree about what a number means.
    M.Enum.AddOnRestrictionType  = { Combat = 0 }
    M.Enum.AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 }
    M.Enum.DamageMeterType = {
        DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4,
        Interrupts = 5, Dispels = 6, DamageTaken = 7, AvoidableDamageTaken = 8,
        Deaths = 9, EnemyDamageTaken = 10,
    }
    -- Which of the two groups a unit is in. `IsInGroup` takes one of these, and
    -- the distinction is load-bearing for the export module's AUTO channel: a
    -- premade raid standing inside a raid instance is in the HOME group, and
    -- INSTANCE_CHAT for such a group is a silent no-op on a live client.
    M.Enum.PartyCategory = { Home = 1, Instance = 2 }
    M.Enum.DamageMeterSessionType       = { Overall = 0, Current = 1, Expired = 2 }
    M.Enum.DamageMeterSourceDisplayType = { None = 0, Ally = 1, Enemy = 2 }

    M.C_RestrictedActions = {
        IsAddOnRestrictionActive = function(restrictionType)
            if restrictionType ~= nil and restrictionType ~= M.Enum.AddOnRestrictionType.Combat then
                return false
            end
            return M.__restricted
        end,
        GetAddOnRestrictionState = function(restrictionType)
            if restrictionType ~= nil and restrictionType ~= M.Enum.AddOnRestrictionType.Combat then
                return M.Enum.AddOnRestrictionState.Inactive
            end
            if M.__restrictionState ~= nil then return M.__restrictionState end
            return M.__restricted and M.Enum.AddOnRestrictionState.Active
                or M.Enum.AddOnRestrictionState.Inactive
        end,
    }

    M.InCombatLockdown = function() return M.__restricted end

    -- ── the cursor ─────────────────────────────────────────────────────────
    --
    -- settings/ColumnBlocks.lua's drag reads this on every OnUpdate frame, and a
    -- drag nothing offline can drive is a drag that ships untested -- which is
    -- exactly how a page's button once shipped wired to nothing at all. Scaled
    -- coordinates, like the real one: callers divide by GetEffectiveScale().
    M.__cursorX, M.__cursorY = 0, 0
    M.GetCursorPosition = function() return M.__cursorX, M.__cursorY end
    function M.setCursor(x, y) M.__cursorX, M.__cursorY = x or 0, y or 0 end

    -- Whether a mouse button is held. settings/ColumnBlocks.lua's drag polls this
    -- rather than waiting for OnDragStop, so a drag that is never released is a
    -- drag the suite can hold open and inspect mid-flight.
    M.__mouseDown = {}
    M.IsMouseButtonDown = function(button)
        return M.__mouseDown[button or "LeftButton"] and true or false
    end
    function M.setMouseDown(button, down)
        M.__mouseDown[button or "LeftButton"] = down and true or false
    end

    -- ── the four detection globals ─────────────────────────────────────────
    --
    -- Consistent with the simulator by construction: a value is secret iff this
    -- file wrapped it. Accessibility is the separate question core/Secrets.lua's
    -- CanAccess / CanCompare2 ask, and `__secretsAccessible` is what makes the
    -- Activating edge — where values are secret AND still readable — reachable.
    M.issecretvalue = function(v) return isSimulatedSecret(v) end
    M.canaccessvalue = function(v)
        if not isSimulatedSecret(v) then return true end
        return M.__secretsAccessible
    end
    M.issecrettable = function(t) return isSimulatedSecretTable(t) end
    M.canaccesstable = function(t)
        if type(t) ~= "table" then return false end
        if not isSimulatedSecretTable(t) then return true end
        return M.__secretsAccessible
    end

    -- ── C_DamageMeter ──────────────────────────────────────────────────────
    local meter = {
        available     = true,
        failureReason = nil,
        -- [sessionType][statType] = plain session spec
        sessionSpecs  = {},
        -- [sessionType][statType][key] = plain source spec; key is a GUID, or
        -- "creature:<id>" for an enemy, or "*" as the catch-all
        sourceSpecs   = {},
        durations     = {},
        sessions      = {},
        resets        = 0,
        calls         = {},
    }
    M.__meter = meter

    local function bump(name)
        meter.calls[name] = (meter.calls[name] or 0) + 1
    end

    --- Zero every call counter. Suites and tests/perf.lua both measure "how many
    --- reads did one refresh make", which is only a number if it can be reset.
    function M.resetMeterCalls()
        for k in pairs(meter.calls) do meter.calls[k] = nil end
    end

    function M.setMeterAvailable(ok, reason)
        meter.available     = ok and true or false
        meter.failureReason = reason
    end

    --- Install a session spec for (sessionType, statType). Pass nil to remove it,
    --- which is how the "no session" reason is reached.
    function M.setSession(sessionType, statType, spec)
        meter.sessionSpecs[sessionType] = meter.sessionSpecs[sessionType] or {}
        meter.sessionSpecs[sessionType][statType] = spec
    end

    --- Install the per-source spell breakdown behind one cell.
    --- `key` is a source GUID, "creature:<id>", or "*" for every source.
    function M.setSourceDetail(sessionType, statType, key, spec)
        meter.sourceSpecs[sessionType] = meter.sourceSpecs[sessionType] or {}
        meter.sourceSpecs[sessionType][statType] = meter.sourceSpecs[sessionType][statType] or {}
        meter.sourceSpecs[sessionType][statType][key or "*"] = spec
    end

    function M.setSessionDuration(sessionType, seconds) meter.durations[sessionType] = seconds end
    function M.setAvailableSessions(list) meter.sessions = list or {} end

    --- A plausible session spec: `count` ally sources, descending by amount.
    ---
    --- Deterministic on purpose — the perf runner and every suite need the same
    --- numbers on every run, and a randomized fixture makes a failure
    --- irreproducible. `opts.guidPrefix` lets a caller line the GUIDs up with a
    --- group built by `mocks.setGroup`, which is what makes the aggregator's join
    --- assertable.
    ---
    --- @param opts table|nil {
    ---   count, top, step, guidPrefix, names, classes, statKey, deaths,
    ---   durationSeconds }
    --- @return table  a plain session spec, ready for setSession
    --- The i-th combat source of a generated session, carrying `amount` as its
    --- total. Source 1 is the local player, which is what makes the "highlight
    --- me" rendering assertable without a caller having to say so.
    ---
    --- @param spec table    a resolved sessionOptions table
    --- @param i number      1-based position in the roster
    --- @param amount number this source's total for the run
    --- @return table
    local function buildSource(spec, i, amount)
        -- The design brief names this field `guid`; modules/Provider.lua reads
        -- `sourceGUID`. Both are published, from the one string, so a fixture
        -- written against either spelling lines up with the code that consumes it.
        local guid = string.format("%s%08X", spec.prefix, i)
        return {
            sourceGUID        = guid,
            guid              = guid,
            sourceCreatureID  = nil,
            name              = (spec.names and spec.names[i]) or ("Mock" .. i),
            classFilename     = spec.classes[((i - 1) % #spec.classes) + 1],
            specIconID        = 135000 + i,
            isLocalPlayer     = (i == 1),
            totalAmount       = amount,
            amountPerSecond   = math.floor(amount / 300),
            deathTimeSeconds  = spec.deaths and (i * 7) or nil,
            deathRecapID      = spec.deaths and (1000 + i) or nil,
            classification    = "normal",
            sourceDisplayType = M.Enum.DamageMeterSourceDisplayType.Ally,
        }
    end

    function M.buildSession(opts)
        local spec = sessionOptions(opts)

        -- A descending ladder from `top`, each source `step` below the one above
        -- it, floored at 1 so a long roster never produces a zero or a negative
        -- total that the aggregator's percentages would divide by.
        local sources, total = {}, 0
        for i = 1, spec.count do
            local amount = math.floor(spec.top * (1 - (i - 1) * spec.step))
            if amount < 1 then amount = 1 end
            total = total + amount
            sources[i] = buildSource(spec, i, amount)
        end

        return {
            combatSources   = sources,
            maxAmount       = sources[1] and sources[1].totalAmount or 0,
            totalAmount     = total,
            durationSeconds = spec.durationSeconds,
        }
    end

    --- A plausible per-source spell breakdown, for the tooltip and drill-down.
    function M.buildSourceDetail(opts)
        opts = opts or {}
        local count = opts.count or 4
        local top   = opts.top or 900000
        local spells, total = {}, 0
        for i = 1, count do
            local amount = math.floor(top / i)
            total = total + amount
            spells[i] = {
                spellID        = 100 + i,
                name           = "Mock Spell " .. i,
                totalAmount    = amount,
                -- THE CLIENT SENDS A RATE ON A SPELL, and this builder did not.
                -- On a rate stat the figure modules/Row.lua actually PRINTS is
                -- the rate (`leftSlot` ships as `smart`, which has no fallback to
                -- the total), so a spell fixture carrying only `totalAmount`
                -- models a client that draws bars with no numbers on them. The
                -- preview builder had the same hole and it reached a player's
                -- screen; this one had never been asserted against rendered text,
                -- which is the only reason it did not.
                amountPerSecond = math.floor(amount / 300),
                isAvoidable    = opts.avoidable and (i % 2 == 0) or false,
                isDeadly       = opts.deadly and (i == 1) or false,
                overkillAmount = opts.overkill and math.floor(amount / 10) or nil,
            }
        end
        return { combatSpells = spells, maxAmount = spells[1] and spells[1].totalAmount or 0,
                 totalAmount = total }
    end

    M.C_DamageMeter = {
        IsDamageMeterAvailable = function()
            bump("IsDamageMeterAvailable")
            if meter.available then return true, nil end
            return false, meter.failureReason
        end,

        GetCombatSessionFromType = function(sessionType, statType)
            bump("GetCombatSessionFromType")
            local byStat = meter.sessionSpecs[sessionType]
            local spec = byStat and (byStat[statType] or byStat["*"])
            if spec == nil then return nil end
            return materialize(spec, M.__secretValues)
        end,

        GetCombatSessionFromID = function(sessionID, statType)
            bump("GetCombatSessionFromID")
            local byStat = meter.sessionSpecs[sessionID]
            local spec = byStat and (byStat[statType] or byStat["*"])
            if spec == nil then return nil end
            return materialize(spec, M.__secretValues)
        end,

        GetCombatSessionSourceFromType = function(sessionType, statType, sourceGUID, creatureID)
            bump("GetCombatSessionSourceFromType")
            -- THE CLIENT REFUSES A SECRET creatureID, and it refuses it loudly:
            -- `bad argument #4 … Secret values are only allowed during untainted
            -- execution`. A secret one used to slip through this mock and merely
            -- fail to match a fixture key, which is why the raise shipped —
            -- `sourceCreatureID` is plain out of combat and SECRET in a pull, so
            -- nothing offline disagreed. Modelled so it fails here first.
            --
            -- ARGUMENT #3 IS DELIBERATELY NOT MODELLED THE SAME WAY. A secret
            -- sourceGUID is believed to resolve nothing rather than to raise
            -- (modules/Targets.lua drops one before calling, so no path in this
            -- addon passes one), and there is no observed client raise for it.
            -- Asserting one here would be inventing behaviour.
            if isSimulatedSecret(creatureID) then
                error("bad argument #4 to 'GetCombatSessionSourceFromType' "
                    .. "(Secret values are only allowed during untainted execution)", 2)
            end
            local byStat = meter.sourceSpecs[sessionType]
            local byKey = byStat and (byStat[statType] or byStat["*"])
            if not byKey then return nil end
            local key = sourceGUID or (creatureID and ("creature:" .. tostring(creatureID)))
            local spec = (key and byKey[key]) or byKey["*"]
            if spec == nil then return nil end
            return materialize(spec, M.__secretValues)
        end,

        GetCombatSessionSourceFromID = function(sessionID, statType, sourceGUID, creatureID)
            bump("GetCombatSessionSourceFromID")
            return M.C_DamageMeter.GetCombatSessionSourceFromType(
                sessionID, statType, sourceGUID, creatureID)
        end,

        GetAvailableCombatSessions = function()
            bump("GetAvailableCombatSessions")
            return meter.sessions
        end,

        GetSessionDurationSeconds = function(sessionType)
            bump("GetSessionDurationSeconds")
            local d = meter.durations[sessionType]
            if d == nil then return nil end
            if M.__secretValues then return secret(d) end
            return d
        end,

        ResetAllCombatSessions = function()
            bump("ResetAllCombatSessions")
            meter.resets = meter.resets + 1
            meter.sessionSpecs = {}
            meter.sourceSpecs  = {}
        end,
    }

    -- ── C_StringUtil: the only legal way to abbreviate a secret ────────────
    --
    -- The formatter is a NATIVE seam, which is the entire reason modules/Format.lua
    -- may hand it a secret at all — so this stub is allowed to reveal the value.
    -- Nothing else in the mock does.
    -- A FORMATTER ONLY ABBREVIATES IF IT HAS BREAKPOINTS, and modelling that is
    -- the whole point of this stub.
    --
    -- The previous version of this mock abbreviated unconditionally, inside
    -- CreateNumericRuleFormatter. That made the entire suite green while the LIVE
    -- client rendered "53571.392857143" in every cell, because the real
    -- NumericRuleFormatter with no breakpoints on it is a working formatter that
    -- does not abbreviate — the addon was asking the wrong object and no test
    -- could see it. A mock that is kinder than the client is a mock that hides
    -- the bug it exists to catch (mock_base's rule 5).
    --
    -- Breakpoint semantics, MEASURED ON A LIVE CLIENT rather than taken from the
    -- documentation:
    --
    --     displayed = n / (significandDivisor * fractionDivisor)
    --     decimals  = log10(fractionDivisor)
    --
    -- The wiki's worked example does not hold under that formula, and this stub
    -- previously implemented the wiki's version — which is how a ladder that put
    -- every number two orders of magnitude too small passed every test. Truncated,
    -- not rounded, also per observation ("4.75" renders "4.7").
    local function decimalsFor(fractionDivisor)
        local d, n = 0, fractionDivisor or 1
        while n >= 10 do n, d = n / 10, d + 1 end
        return d
    end

    local function newFormatter(kind)
        local formatter = { __formatCount = 0, __kind = kind, __breakpoints = nil }

        function formatter:SetBreakpoints(list)
            if type(list) ~= "table" then error("SetBreakpoints wants an array", 2) end
            self.__breakpoints = list
        end
        function formatter:GetBreakpoints()   return self.__breakpoints end
        function formatter:ClearBreakpoints() self.__breakpoints = nil end
        function formatter:AddBreakpoint(bp)
            self.__breakpoints = self.__breakpoints or {}
            self.__breakpoints[#self.__breakpoints + 1] = bp
        end

        function formatter:FormatNumber(v)
            self.__formatCount = self.__formatCount + 1
            local n = reveal(v)
            if type(n) ~= "number" then return tostring(n) end

            local best
            for _, bp in ipairs(self.__breakpoints or {}) do
                if n >= (bp.breakpoint or 0)
                    and (best == nil or (bp.breakpoint or 0) >= (best.breakpoint or 0)) then
                    best = bp
                end
            end

            -- NO BREAKPOINT MATCHED: the plain render. This is the branch the
            -- addon lived in for a whole release.
            if best == nil then return tostring(n) end

            local scaled = n / ((best.significandDivisor or 1) * (best.fractionDivisor or 1))
            local d = decimalsFor(best.fractionDivisor)
            local factor = 10 ^ d
            local truncated = math.floor(scaled * factor) / factor
            return string.format("%." .. d .. "f", truncated) .. (best.abbreviation or "")
        end

        M.__lastNumericFormatter = formatter
        return formatter
    end

    M.C_StringUtil = {
        -- The RULE formatter. Ships with no breakpoints, so it renders plainly
        -- until somebody puts some on it.
        CreateNumericRuleFormatter = function() return newFormatter("rule") end,

        -- The ABBREVIATING formatter. Also ships with no breakpoints — the
        -- caller is expected to set them, from GetDefaultAbbreviationBreakpoints
        -- or its own ladder.
        CreateAbbreviatedNumberFormatter = function() return newFormatter("abbreviated") end,

        GetDefaultAbbreviationBreakpoints = function()
            -- Blizzard's own ladder, in the same multiplying semantics: one
            -- decimal below 10K, none above, which is what the live client shows
            -- when our own array is refused.
            return {
                { breakpoint = 1e3, abbreviation = "K", significandDivisor = 100, fractionDivisor = 10,
                  abbreviationIsGlobal = false },
                { breakpoint = 1e4, abbreviation = "K", significandDivisor = 1e3, fractionDivisor = 1,
                  abbreviationIsGlobal = false },
                { breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10,
                  abbreviationIsGlobal = false },
            }
        end,
    }

    M.AbbreviateNumbers = function(v)
        local n = reveal(v)
        if type(n) ~= "number" then return tostring(n) end
        if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
        if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
        return string.format("%d", n)
    end

    -- ── group / units ──────────────────────────────────────────────────────
    --
    -- modules/Roster.lua walks `player`, then `raid1..N` (in a raid) or
    -- `party1..N-1`, and asks for each unit's pet by token. Everything it can ask
    -- is answered from this one table so a suite composes a group in one call.
    local group = {
        inGroup      = false,
        inRaid       = false,
        size         = 0,
        inInstance   = false,
        instanceType = "none",
        inCombat     = false,
        inVehicle    = false,
        -- The player-state axis the visibility rules read. Every one of these
        -- ships false, which is the answer that keeps a window VISIBLE: a rule
        -- that only ever hides must degrade towards showing.
        difficultyID = 0,
        delve        = false,
        delveSignal  = nil,   -- one rung of the ladder, when a case drives just one
        mounted      = false,
        formID       = 0,
        canGlide     = false,
        housing      = false,
        onTaxi       = false,
        petBattle    = false,
        deadOrGhost  = false,
        units        = {},   -- [unitToken] = { guid, name, class, classFile, role }
    }
    M.__group = group

    local CLASS_NAMES = {
        WARRIOR = "Warrior", PRIEST = "Priest", MAGE = "Mage", ROGUE = "Rogue",
        HUNTER = "Hunter", WARLOCK = "Warlock", MONK = "Monk", DRUID = "Druid",
        PALADIN = "Paladin", DEATHKNIGHT = "Death Knight", SHAMAN = "Shaman",
        DEMONHUNTER = "Demon Hunter", EVOKER = "Evoker",
    }

    local function setUnit(token, spec)
        if spec == nil then group.units[token] = nil; return end
        group.units[token] = {
            guid      = spec.guid,
            name      = spec.name,
            classFile = spec.classFile or spec.class or "WARRIOR",
            role      = spec.role or "NONE",
            -- An NPC is a unit too. `isPlayer = false` is the target
            -- modules/Export.lua's "Whisper my target" channel has to refuse.
            isPlayer  = spec.isPlayer ~= false,
            -- The realm a cross-realm name carries, for GetUnitName's
            -- showServerName form. Absent for a same-realm unit, which is what
            -- makes the two forms distinguishable in a test.
            realm     = spec.realm,
        }
    end
    M.setUnit = setUnit

    --- Compose a group.
    ---
    --- `spec` is an array of { guid, name, class, role }, the PLAYER FIRST — the
    --- order modules/Roster.lua produces and the order `roster` sort mode is
    --- defined against. `opts.raid` builds raid1..N instead of party1..N-1.
    ---
    --- GUIDs default to the same "Player-1-%08X" shape `mocks.buildSession`
    --- produces, so a session built with the default prefix joins against a group
    --- built with no GUIDs at all.
    function M.setGroup(spec, opts)
        opts = opts or {}
        spec = spec or {}
        group.units = {}
        group.inRaid = opts.raid and true or false
        group.size   = #spec
        group.inGroup = #spec > 1
        -- A group is a HOME group unless a test says otherwise. Queued content is
        -- the exception, so it is the flag that has to be set rather than unset.
        group.instanceGroup = false

        for i, member in ipairs(spec) do
            local guid = member.guid or string.format("Player-1-%08X", i)
            local token = (i == 1) and "player"
                or (group.inRaid and ("raid" .. i) or ("party" .. (i - 1)))
            setUnit(token, {
                guid = guid, name = member.name or ("Mock" .. i),
                class = member.class, role = member.role,
            })
            -- In a raid the player is also raidN. Roster de-duplicates by GUID,
            -- and reproducing the duplicate here is what makes that provable.
            if group.inRaid and i == 1 then
                setUnit("raid1", { guid = guid, name = member.name or "Mock1",
                                   class = member.class, role = member.role })
            end
        end
        return group
    end

    --- Solo: one unit, `player`, and no group. The default state.
    function M.setSolo(guid, name, class)
        return M.setGroup({ { guid = guid or "Player-1-00000001",
                              name = name or "Mock1", class = class or "MAGE",
                              role = "DAMAGER" } })
    end

    --- Give `unit` a pet. The token is derived exactly as modules/Roster.lua
    --- derives it, so a mismatch is impossible.
    function M.setPet(unit, guid, name)
        local token = (unit == "player") and "playerpet" or (unit .. "pet")
        setUnit(token, { guid = guid, name = name or "MockPet", class = "PET" })
        return token
    end

    --- Put the player INSIDE an instance. Says nothing about which group they are
    --- in: a premade raid walking into a raid is in an instance and is not an
    --- instance group. `setInstanceGroup` is the other half.
    function M.setInstance(instanceType)
        group.inInstance   = (instanceType ~= nil and instanceType ~= "none")
        group.instanceType = instanceType or "none"
    end

    --- Make the current group a QUEUED (instance) group — a dungeon finder party,
    --- a raid finder raid, a battleground. This is what `IsInGroup(Instance)` and
    --- `IsPartyLFG` answer, and the only state INSTANCE_CHAT actually reaches.
    function M.setInstanceGroup(v)
        group.instanceGroup = v and true or false
    end

    function M.setInCombat(v)
        group.inCombat = v and true or false
        M.__inCombat   = group.inCombat
    end

    function M.setInVehicle(v) group.inVehicle = v and true or false end

    -- ── player state, for the visibility rules ─────────────────────────────
    --
    -- One setter per rule, each answering exactly the probe core/Compat.lua and
    -- modules/Visibility.lua make and nothing else. They are separate rather
    -- than one table so a case names the state it is driving in its own line.

    --- Put the player in a delve. Drives all three rungs of Compat.IsInDelve's
    --- ladder at once, because a live client can answer on any of them: a delve
    --- reports instanceType "scenario" with difficulty 208, and the two delve
    --- namespaces agree.
    function M.setDelve(v)
        group.delve = v and true or false
        group.delveSignal = nil
        if group.delve then
            M.setInstance("scenario")
            group.difficultyID = 208
        elseif group.difficultyID == 208 then
            group.difficultyID = 0
        end
    end

    --- Answer only ONE rung of the delve ladder, to prove the other two are not
    --- load-bearing. `which` is "party", "difficulty" or "delvesui".
    function M.setDelveVia(which)
        group.delve = false
        M.setInstance("scenario")
        group.difficultyID = (which == "difficulty") and 208 or 0
        group.delveSignal = which
    end

    function M.setMounted(v) group.mounted = v and true or false end

    --- The druid travel/aquatic/flight form ids (3, 4, 27) core/Compat.lua reads
    --- as mount-like. Any other id, including 0, is not a mount.
    function M.setShapeshiftForm(id) group.formID = tonumber(id) or 0 end

    --- Skyriding capability — the second return of C_PlayerInfo.GetGlidingInfo.
    --- Capability, not altitude: it is true on the ground the moment the
    --- skyriding bar is available, which is what the rule is about.
    function M.setCanGlide(v) group.canGlide = v and true or false end

    function M.setInHousing(v) group.housing = v and true or false end
    function M.setOnTaxi(v) group.onTaxi = v and true or false end
    function M.setInPetBattle(v) group.petBattle = v and true or false end
    function M.setDeadOrGhost(v) group.deadOrGhost = v and true or false end

    local function unit(token) return group.units[token] end

    M.UnitExists = function(token) return unit(token) ~= nil end
    M.UnitGUID   = function(token) local u = unit(token) return u and u.guid end
    M.UnitName   = function(token) local u = unit(token) return u and u.name end
    M.UnitClass  = function(token)
        local u = unit(token)
        if not u then return nil end
        return CLASS_NAMES[u.classFile] or u.classFile, u.classFile
    end
    M.UnitGroupRolesAssigned = function(token)
        local u = unit(token)
        return u and u.role or "NONE"
    end

    -- The player's own specialization role, which is what modules/Roster.lua
    -- falls back to when no group has assigned one. `mocks.setSpecRole(nil)`
    -- drives the case where even this is unavailable.
    group.specRole = nil
    function M.setSpecRole(role) group.specRole = role end
    M.GetSpecialization     = function() return group.specRole and 1 or nil end
    M.GetSpecializationRole = function() return group.specRole end
    M.UnitAffectingCombat = function() return group.inCombat end
    M.UnitInVehicle       = function() return group.inVehicle end
    M.UnitIsUnit          = function(a, b)
        local ua, ub = unit(a), unit(b)
        return ua ~= nil and ub ~= nil and ua.guid == ub.guid
    end
    M.UnitIsPlayer = function(token)
        local u = unit(token)
        return u ~= nil and u.isPlayer ~= false
    end

    --- Blizzard's realm-qualifying name reader. With `showServerName` a
    --- cross-realm unit answers "Name-Realm", which is the form a whisper needs;
    --- without it, and for a same-realm unit, it is the plain name.
    M.GetUnitName = function(token, showServerName)
        local u = unit(token)
        if not u then return nil end
        if showServerName and u.realm then return u.name .. "-" .. u.realm end
        return u.name
    end
    M.UnitIsDead   = function() return false end

    -- Unit health, for the feign-death filter in modules/Feign.lua. There was no
    -- health seam here before it, because nothing in this addon had ever needed
    -- one: every number it shows comes from C_DamageMeter. A unit with no
    -- recorded health answers full, which is the state that keeps a feign
    -- REMEMBERED — the clear fires only on a confirmed 0.
    M.__unitHealth = {}
    function M.setUnitHealth(token, current, maximum)
        M.__unitHealth[token] = { current = current, maximum = maximum or 100 }
    end
    -- Whether a unit is feigning. Read only in the "they stood back up"
    -- direction by modules/Feign.lua -- a false reading on a living unit is
    -- trustworthy, a true one is not, because it lingers through a
    -- feign-then-die transition.
    M.__unitFeign = {}
    function M.setUnitFeignDeath(token, feigning)
        M.__unitFeign[token] = feigning and true or false
    end
    M.UnitIsFeignDeath = function(token)
        return M.__unitFeign[token] and true or false
    end

    M.UnitHealth    = function(token)
        local h = M.__unitHealth[token]
        return h and h.current or 100
    end
    M.UnitHealthMax = function(token)
        local h = M.__unitHealth[token]
        return h and h.maximum or 100
    end
    -- Category-aware, like the real one. No argument means "either group", which
    -- is what every caller that does not care asks.
    M.IsInGroup           = function(category)
        if category ~= nil and category == M.Enum.PartyCategory.Instance then
            return group.instanceGroup and group.inGroup
        end
        return group.inGroup
    end
    M.IsPartyLFG          = function() return group.instanceGroup and group.inGroup end
    M.IsInRaid            = function() return group.inRaid end
    M.GetNumGroupMembers  = function() return group.size end
    M.IsInInstance        = function() return group.inInstance, group.instanceType end
    -- name, instanceType, difficultyID, ... — only the three fields anything in
    -- this addon reads are populated.
    M.GetInstanceInfo     = function()
        return "MockInstance", group.instanceType, group.difficultyID
    end

    -- ── the player-state APIs ──────────────────────────────────────────────

    M.IsMounted             = function() return group.mounted end
    M.GetShapeshiftFormID   = function() return group.formID end
    M.UnitOnTaxi            = function(token) return token == "player" and group.onTaxi end
    M.UnitIsDeadOrGhost     = function(token) return token == "player" and group.deadOrGhost end

    -- isGliding, canGlide, forwardSpeed. Only canGlide is read: the rule fires on
    -- capability, not on being airborne.
    M.C_PlayerInfo = M.C_PlayerInfo or {}
    M.C_PlayerInfo.GetGlidingInfo = function()
        return group.canGlide, group.canGlide, 0
    end

    M.C_Housing = M.C_Housing or {}
    M.C_Housing.IsInsideHouseOrPlot = function() return group.housing end

    M.C_PetBattles = M.C_PetBattles or {}
    M.C_PetBattles.IsInBattle = function() return group.petBattle end

    -- The three delve signals, each answering independently so a case can drive
    -- one rung of the ladder and leave the others silent.
    M.C_PartyInfo = M.C_PartyInfo or {}
    M.C_PartyInfo.IsDelveInProgress = function()
        return group.delve or group.delveSignal == "party"
    end

    M.C_Map = M.C_Map or {}
    M.C_Map.GetBestMapForUnit = function() return 2248 end

    M.C_DelvesUI = M.C_DelvesUI or {}
    M.C_DelvesUI.HasActiveDelve = function()
        return group.delve or group.delveSignal == "delvesui"
    end

    -- Event-name validation, which core/MultiMeters.lua asks before registering
    -- PLAYER_IS_GLIDING_CHANGED. Everything is valid unless a case says
    -- otherwise, so the probe's failure path has to be opted into.
    M.__invalidEvents = {}
    function M.setEventInvalid(name) M.__invalidEvents[name] = true end
    M.C_EventUtils = M.C_EventUtils or {}
    M.C_EventUtils.IsEventValid = function(name)
        return not M.__invalidEvents[name]
    end
    M.IsLoggedIn          = function() return true end

    M.setSolo()

    -- Class colors and icon coordinates, so modules/Row.lua's `class` color mode
    -- and class-icon path are exercised rather than skipped over.
    M.RAID_CLASS_COLORS = {}
    M.CLASS_ICON_TCOORDS = {}
    for cls in pairs(CLASS_NAMES) do
        M.RAID_CLASS_COLORS[cls] = { r = 0.5, g = 0.6, b = 0.7 }
        M.CLASS_ICON_TCOORDS[cls] = { 0, 0.25, 0, 0.25 }
    end
    M.STANDARD_TEXT_FONT = [[Fonts\FRIZQT__.TTF]]

    -- ── C_Texture ──────────────────────────────────────────────────────────
    --
    -- Atlas existence, which core/Compat.lua's FirstAtlas asks before drawing
    -- anything. The known set is deliberately SMALL and settable: the bug this
    -- guards against is art that does not exist on the live client, so the
    -- default here is "almost nothing exists" rather than "everything does".
    -- The set a live 12.x client reported through `/mm debug diag`. Small on
    -- purpose: the bug this guards against is art that does not exist, so the
    -- default is "almost nothing exists" rather than "everything does".
    M.__atlases = {
        ["auctionhouse-ui-sortarrow"] = true,
        ["GM-icon-settings"]          = true,
        ["Garr_LockedBuilding"]       = true,
    }
    -- Wiped per build; see the note beside `unloadable`.
    for k in pairs(unloadable) do unloadable[k] = nil end

    --- Mark a texture path as failing to load, the way a missing file does on a
    --- live client: SetTexture takes it and GetTexture answers nil.
    function M.setTextureLoadable(path, loadable)
        unloadable[path] = (loadable == false) or nil
    end

    function M.setAtlases(set) M.__atlases = set or {} end
    M.C_Texture = {
        GetAtlasInfo = function(name)
            if M.__atlases[name] then return { width = 16, height = 16 } end
            return nil
        end,
    }

    -- ── MenuUtil ───────────────────────────────────────────────────────────
    --
    -- The 11.0+ context-menu API, behind core/Compat.lua's OpenContextMenu shim
    -- and used by the window header's segment selector.
    --
    -- RECORDS THE MENU RATHER THAN DRAWING ONE. The generator runs immediately
    -- against a root that appends a descriptor per call, so a test can assert
    -- what the menu OFFERS — its entries, their order, the divider between the
    -- stored segments and the synthetic ones — and can invoke an entry's callback
    -- to prove the click does what the label promises. A mock that merely
    -- swallowed the call would leave the whole dropdown untested.
    --
    -- Clear `mocks.MenuUtil` to drive the shim's "this client has no menu API"
    -- path, which is what the headless-degradation suite does.
    M.__lastMenu = nil

    local function newMenuRoot()
        local root = { entries = {} }
        local function add(kind, text, callback)
            root.entries[#root.entries + 1] =
                { kind = kind, text = text, callback = callback }
            return root.entries[#root.entries]
        end
        function root:CreateTitle(text)             return add("title", text, nil) end
        function root:CreateDivider()               return add("divider", nil, nil) end
        function root:CreateButton(text, callback)  return add("button", text, callback) end
        --- The nth entry of one kind, so a case can say "the second button"
        --- without counting dividers.
        function root:Nth(kind, n)
            local seen = 0
            for _, e in ipairs(self.entries) do
                if e.kind == kind then
                    seen = seen + 1
                    if seen == n then return e end
                end
            end
            return nil
        end
        return root
    end

    M.MenuUtil = {
        CreateContextMenu = function(owner, generator)
            local root = newMenuRoot()
            root.owner = owner
            generator(owner, root)
            M.__lastMenu = root
            return root
        end,
    }

    -- ── manifest ───────────────────────────────────────────────────────────
    --
    -- Stubbed HERE and not in the base (whose header explains why). Clear
    -- `mocks.C_AddOns` — not `_G.C_AddOns` — to drive core/EnvSetup.lua's
    -- deprecated-global rung; `mocks._G` resolves through this table.
    M.__toc = {
        Version = "0.1.0",
        Title   = "Ka0s Multi Meters",
        Notes   = "One grid, one row per group member, one column per stat.",
    }
    M.C_AddOns = {
        GetAddOnMetadata = function(_, field) return M.__toc[field] end,
        IsAddOnLoaded    = function() return true, true end,
    }

    -- ── spell / spec APIs ──────────────────────────────────────────────────
    M.__spells = setmetatable({}, { __index = function(_, id)
        return { name = "Mock Spell " .. tostring(id), iconID = 130000 + (tonumber(id) or 0),
                 castTime = 0, minRange = 0, maxRange = 40, spellID = id }
    end })
    M.C_Spell = {
        GetSpellInfo    = function(id) return M.__spells[id] end,
        GetSpellTexture = function(id) return 130000 + (tonumber(id) or 0) end,
    }
    M.C_SpecializationInfo = {
        GetSpecialization     = function() return 1 end,
        GetSpecializationInfo = function() return 250, "Blood", "", 135771, "TANK" end,
    }

    M.OpenDeathRecapUI = function(id)
        M.__deathRecaps = (M.__deathRecaps or 0) + 1
        M.__lastRecapID = id
    end

    -- ── C_DeathInfo ────────────────────────────────────────────────────────
    --
    -- The probe for issue #1 exists because NOBODY KNOWS what this namespace
    -- answers on a live client for a past death or another player's. So the mock
    -- does not pick an answer: it is a blank slate a test installs a client into,
    -- and the DEFAULT is the namespace being absent entirely — which is itself
    -- one of the four outcomes the probe has to survive.
    --
    -- `M.setDeathInfo(members)` installs a namespace; `nil` removes it. Each
    -- member is a plain function, so a test models "answers for the local
    -- player's newest death and nils everything else" by writing exactly that,
    -- rather than by configuring a mock that has already guessed.
    M.C_DeathInfo = nil
    function M.setDeathInfo(members)
        M.C_DeathInfo = members
    end

    -- C_DeathRecap is the namespace the probe's first two rounds never looked
    -- at, and the one that actually carries `GetRecapEvents`. Same blank-slate
    -- rule: absent by default, a test installs the client it wants to model.
    M.C_DeathRecap = nil
    function M.setDeathRecap(members)
        M.C_DeathRecap = members
    end

    -- ── frames ─────────────────────────────────────────────────────────────
    --
    -- Every frame this run creates, in creation order, plus a by-name index. The
    -- window's frames are NAMED (modules/Window.lua names them so they can go into
    -- UISpecialFrames), so a suite can reach "MultiMetersWindow1" without holding
    -- the instance.
    M.__frames      = {}
    M.__frameByName = {}
    M.__stubFrame   = makeFrame

    M.CreateFrame = function(objectType, name, parent, template)
        local f = makeFrame(objectType or "Frame", parent, name)
        f.__template = template
        M.__frames[#M.__frames + 1] = f
        if name then M.__frameByName[name] = f end
        return f
    end

    M.UIParent           = makeFrame("Frame", nil, "UIParent")
    M.DEFAULT_CHAT_FRAME = makeFrame("Frame", nil, "ChatFrame1")
    M.__chat             = {}
    M.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg)
        M.__chat[#M.__chat + 1] = msg
    end
    M.UISpecialFrames = {}

    -- The client's own "no such player" error string, verbatim. modules/Export.lua
    -- builds its match pattern out of this global rather than out of an English
    -- literal, so a mock that omitted it would exercise the fallback and never the
    -- path a real client takes.
    M.ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named \"%s\" is currently playing."

    -- GameTooltip, with its recorded line list, its re-anchoring Show and its
    -- per-line FontStrings under the client's own global names. Installed from
    -- tests/mock_frame.lua: it is a widget model with real state, and it reads
    -- beside the rest of the frame model rather than beside the builder.
    Frame.installTooltip(M)

    -- ── timers ─────────────────────────────────────────────────────────────
    --
    -- The base already records C_Timer.After / NewTimer into `__timers` and fires
    -- them with `__fireTimers`. `__flushTimers` is the collection's other spelling
    -- of the same thing, published so a suite copied from a sibling addon works.
    M.__flushTimers = M.__fireTimers

    -- ── LibStub extras ─────────────────────────────────────────────────────
    local libs = M.__libs

    -- AceEvent-3.0 and AceAddon-3.0 are THE KIT'S, whole (kit revision 17). This
    -- file carried its own message half -- one registry, `UnregisterAllMessages`
    -- for modules/Provider.lua's Suspend and modules/Window.lua's UnregisterBus,
    -- a string method resolved on the target at dispatch -- and its own module
    -- layer, because the kit had neither. It has both now, taken from the real
    -- CallbackHandler and AceAddon-3.0, so the copies are gone. What a suite
    -- reaches instead:
    --
    --   mocks.__msgRegistry            [message] = { [target] = callable }
    --   mocks.__fireEvent(event, ...)  a game event to every registrant; answers
    --                                  how many handlers ran
    --   AceAddon:EnableAddon(NS)       the enable cascade in the client's order --
    --                                  the addon's OnEnable, then every module in
    --                                  creation order (tests/run.lua's `enable`)
    --   NS.modules, NS.orderedModules  AceAddon's own module tables

    --- AceDB-3.0 with CallbackHandler's STRING-METHOD registration form.
    ---
    --- A DIVERGENCE FROM THE BASE, and the reason for it is that this addon uses
    --- the form the base does not implement. CallbackHandler accepts both
    ---
    ---     db.RegisterCallback(obj, "OnProfileChanged", function(...) end)
    ---     db.RegisterCallback(obj, "OnProfileChanged", "OnProfileChanged")
    ---
    --- and dispatches the second as `obj:method(event, ...)`. The base stores
    --- whatever it is handed and CALLS it, so core/Database.lua's registrations --
    --- all three of which are the string form (core/Database.lua's InitDB) --
    --- raised "attempt to call a string value" the moment a profile was switched,
    --- reset or copied. Nothing noticed, because nothing in the suite had reached
    --- a profile callback: the whole PROFILE_CHANGED path was untestable.
    ---
    --- Wrapped rather than reimplemented: the base's AceDB is faithful about the
    --- things that are hard to get right -- the defaults merge, the profile
    --- table's identity surviving a reset, `db.sv` -- and this replaces exactly
    --- the two functions that carry the dispatch.
    local baseNewDB = libs["AceDB-3.0"].New
    libs["AceDB-3.0"] = {
        New = function(self, ...)
            local db = baseNewDB(self, ...)

            local registered = {}
            local baseRegister = db.RegisterCallback
            db.RegisterCallback = function(target, event, handler)
                registered[event] = registered[event] or {}
                registered[event][#registered[event] + 1] = { target = target, handler = handler }
                -- The base still gets the FUNCTION form so its own `fire` keeps
                -- working for anything registered that way; a string is withheld
                -- from it, because calling one is the bug being fixed.
                if type(handler) == "function" then baseRegister(target, event, handler) end
            end

            --- Dispatch one event to the string-form registrations.
            ---
            --- The base fires the function-form ones itself from inside whichever
            --- profile call is running, so this only has to cover what was
            --- withheld above -- and it runs AFTER that call, which is the same
            --- order CallbackHandler gives.
            local function fireStrings(event)
                for _, entry in ipairs(registered[event] or {}) do
                    local target, handler = entry.target, entry.handler
                    if type(handler) == "string" and type(target) == "table"
                        and type(target[handler]) == "function"
                    then
                        target[handler](target, event, db, db.GetCurrentProfile())
                    end
                end
            end

            for name, event in pairs({ SetProfile   = "OnProfileChanged",
                                       ResetProfile = "OnProfileReset",
                                       CopyProfile  = "OnProfileCopied" }) do
                local base = db[name]
                db[name] = function(...)
                    local result = base(...)
                    fireStrings(event)
                    return result
                end
            end

            return db
        end,
    }

    -- LibSharedMedia-3.0. Real enough to answer a Fetch: modules/Window.lua and
    -- modules/Row.lua resolve every font, bar texture and border through it, and a
    -- nil library sends them all down the fallback branch, leaving the LSM path
    -- untested. core/MediaSetup.lua registers the shipped monospace face into this,
    -- through LibKa0s-Media-1.0's own RegisterLSM.
    local media = { font = {}, statusbar = {}, border = {}, background = {}, sound = {} }
    libs["LibSharedMedia-3.0"] = {
        MediaType = { FONT = "font", STATUSBAR = "statusbar", BORDER = "border",
                      BACKGROUND = "background", SOUND = "sound" },
        Register = function(_, mediaType, key, path)
            media[mediaType] = media[mediaType] or {}
            media[mediaType][key] = path
            return true
        end,
        Fetch = function(_, mediaType, key)
            return media[mediaType] and media[mediaType][key]
        end,
        List = function(_, mediaType)
            local out = {}
            for key in pairs(media[mediaType] or {}) do out[#out + 1] = key end
            table.sort(out)
            return out
        end,
        HashTable = function(_, mediaType) return media[mediaType] or {} end,
        __media = media,
    }
    M.__media = media

    -- LibDataBroker / LibDBIcon, for modules/Minimap.lua. Present rather than
    -- absent so the registration path runs; a suite that wants the "no broker
    -- library" degradation clears them from `mocks.__libs`.
    local brokers = {}
    libs["LibDataBroker-1.1"] = {
        NewDataObject = function(_, name, obj)
            brokers[name] = obj
            return obj
        end,
        GetDataObjectByName = function(_, name) return brokers[name] end,
        __objects = brokers,
    }
    libs["LibDBIcon-1.0"] = {
        objects = {},
        Register = function(self, name, broker, db)
            self.objects[name] = { broker = broker, db = db }
        end,
        Refresh = function(self, name, db)
            self.__refreshes = (self.__refreshes or 0) + 1
            local o = self.objects[name]
            if o then o.db = db end
        end,
        Hide = function() end,
        Show = function() end,
    }

    -- AceDBOptions / AceConfig, for settings/Profiles.lua — the one page in this
    -- addon that is drawn by AceConfigDialog rather than from NS.Schema.
    libs["AceDBOptions-3.0"] = {
        GetOptionsTable = function(_, db)
            return { type = "group", name = "Profiles", args = {}, __db = db }
        end,
    }
    local registered = {}
    libs["AceConfig-3.0"] = {
        RegisterOptionsTable = function(_, name, tbl) registered[name] = tbl end,
        __registered = registered,
    }
    libs["AceConfigDialog-3.0"] = {
        Open = function(self, name, container)
            self.__opens = (self.__opens or 0) + 1
            self.__lastOpen = { name = name, container = container }
        end,
        Close = function(self) self.__closes = (self.__closes or 0) + 1 end,
        SetDefaultSize = function() end,
    }
    libs["AceConfigRegistry-3.0"] = {
        NotifyChange = function() end,
        RegisterOptionsTable = function() end,
    }

    return M
end

return { build = build }
