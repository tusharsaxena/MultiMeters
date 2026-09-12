-- tests/test_format.lua — modules/Format.lua: rendering a meter number without
-- ever looking at one.
--
-- The whole file exists because abbreviating 12400000 to "12.4M" is a division,
-- and a division on a secret raises. So the cases below are written against the
-- SIMULATED SECRET (tests/wow_mock.lua), whose metatable traps `/`, `*`, `-`,
-- `..`, `<` and indexing: a division that crept back into this module would not
-- return a slightly wrong string here, it would raise, and every case that runs
-- a secret through Number / Rate / Duration / Percent is therefore a live probe
-- for that regression rather than a restatement of the header.

local T = _G.MULTIMETERS_TEST

local test         = T.test
local assertEqual  = T.assertEqual
local assertTrue   = T.assertTrue
local assertFalse  = T.assertFalse

--- A fresh instance with the Combat restriction ACTIVE: meter values arrive
--- secret and are not accessible, which is the state most of a pull is spent in.
local function restricted()
    local inst = T.load()
    inst.mocks.setRestricted(true)
    return inst
end

-- ---------------------------------------------------------------------------
-- Publication
-- ---------------------------------------------------------------------------

test("Format: NS.Format is a callable table carrying both contracts", function()
    local NS = T.NS
    assertEqual(type(NS.Format), "table", "NS.Format must stay indexable")
    assertEqual(type(NS.Format.Number), "function")
    -- Calling it reaches LibKa0s-Core's chat printer; the collision is resolved
    -- by the __call metamethod rather than by taking either name away.
    local meta = getmetatable(NS.Format)
    assertEqual(type(meta and meta.__call), "function", "NS.Format must stay callable")
    -- Both aliases are the same table, not copies that can drift.
    assertTrue(NS.Numbers == NS.Format, "NS.Numbers aliases the formatter")
    assertTrue(NS.NumberFormat == NS.Format, "NS.NumberFormat aliases the formatter")
end)

-- ---------------------------------------------------------------------------
-- The native formatter is the path taken
-- ---------------------------------------------------------------------------

test("Format.Number goes through the native ABBREVIATING formatter", function()
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks

    -- No formatter has been built yet: the instance is created lazily, on the
    -- first call, and cached for the session.
    assertEqual(mocks.__lastNumericFormatter, nil, "formatter must be built lazily")

    -- ONE decimal at every magnitude, by the ladder in modules/Format.lua, so
    -- "4.2M" and not "4M" — and not "4.20M" either. The ladder used to carry two
    -- rungs per suffix chasing three significant figures, which made a column
    -- change shape partway down itself: "4.75K" on one row and "10.2K" on the
    -- next, because the two had landed on different rungs.
    -- red under: CreateNumericRuleFormatter, which abbreviates nothing.
    local out = NS.Format.Number(4200000)
    assertEqual(out, "4.2M")

    local formatter = mocks.__lastNumericFormatter
    assertEqual(type(formatter), "table", "a formatter instance must have been created")
    -- One probe (the ladder self-check) plus this value. The probe is what proves
    -- the breakpoints actually took: SetBreakpoints returning without error is
    -- NOT proof, and the live client rendered "47K" where the ladder says "47.5K"
    -- because it had quietly kept its own.
    local afterFirst = formatter.__formatCount
    assertTrue(afterFirst >= 1, "the value must go through :FormatNumber")

    -- Cached: a second call reuses the instance rather than asking C_StringUtil
    -- again (280 calls a frame on a raid, otherwise).
    NS.Format.Number(9000)
    assertTrue(mocks.__lastNumericFormatter == formatter, "the instance must be cached")
    assertEqual(formatter.__formatCount, afterFirst + 1)
end)

test("Format.Invalidate drops the cached formatter instance", function()
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks

    NS.Format.Number(1000)
    local first = mocks.__lastNumericFormatter
    NS.Format.Invalidate()
    NS.Format.Number(1000)
    assertFalse(mocks.__lastNumericFormatter == first,
        "a new instance must be built after Invalidate")
end)

test("Format.Number('full') renders every digit and no abbreviation", function()
    local inst = T.load()
    local NS = inst.NS

    -- "Full" goes to the RULE formatter — no breakpoints, so no abbreviation.
    -- That is the object v0.1.0 was using for everything by mistake, here doing
    -- the job it is actually for.
    assertEqual(NS.Format.Number(4200000, "full"), "4200000")
end)

test("Format.Number('full') renders a rate's DIGITS, not its decimals", function()
    -- `amountPerSecond` is a float. `string.format("%s", 53571.392857143)` — the
    -- old "full" path — put fifteen characters in a 92px cell, which is what
    -- made the live window overlap into its neighbour.
    -- red under: `return passthrough(v)` for the full mode.
    local out = T.load().NS.Format.Number(53571.392857143, "full")
    assertFalse(tostring(out):find("%.") ~= nil,
        "a full-format number must not carry a decimal tail: " .. tostring(out))
end)

test("Format.Number abbreviates a sub-thousand rate to its whole part", function()
    -- The floor breakpoint. Without it a rate that has not reached a thousand
    -- renders every digit of its float.
    -- red under: dropping the breakpoint = 0 entry from the ladder.
    local out = T.load().NS.Format.Number(470.66666666667)
    assertEqual(out, "470")
end)

test("Format.Number renders a value BELOW ONE without dumping its float", function()
    -- THE INTERMITTENT ONE. The ladder's floor sat at `breakpoint = 1`, so any
    -- value in (0, 1) matched no rule at all and the formatter fell back to its
    -- plain render — every digit of the float, in a 92px cell.
    --
    -- It looked random because of WHICH figures can be sub-one. The rate slot is
    -- the only place a fraction reaches the grid, and `isRate` is true for
    -- exactly two stats — which is why it was "primarily damage or healing" and
    -- why no other column ever showed it.
    -- red under: a floor entry the client's rules never reach below.
    local F = T.load().NS.Format
    for _, v in ipairs({ 0.42857142857143, 0.5, 0.999 }) do
        local out = F.Number(v)
        assertFalse(tostring(out):find("%.") ~= nil,
            "a sub-one value must not render its decimals: " .. tostring(v)
                .. " -> " .. tostring(out))
    end
    assertEqual(F.Number(0.42857142857143), "0")
    -- Zero itself has always been fine and must stay so.
    assertEqual(F.Number(0), "0")
end)

test("Format.Number('full') also covers a value below one", function()
    -- Same floor, same fault, on the non-abbreviating formatter: its single
    -- breakpoint was written at 0, which this client refuses outright.
    local F = T.load().NS.Format
    assertFalse(tostring(F.Number(0.42857142857143, "full")):find("%.") ~= nil,
        "full mode means every DIGIT, never every decimal place")
end)

test("Format: a formatter whose ladder never took is NOT cached", function()
    -- HARDENING. A formatter that refused every rung still abbreviates nothing,
    -- and caching it made one bad build stick for the rest of the session — the
    -- same shape of bug as modules/Roster.lua's partial map. Refusing to cache it
    -- sends the render down the AbbreviateNumbers rung, which always abbreviates,
    -- and lets the next invalidation try again.
    -- red under: `cache.numeric = f` regardless of whether the ladder applied.
    local inst = T.load()
    local NS, mocks = inst.NS, inst.mocks

    -- A client that accepts the call and keeps its own rules — the live failure
    -- this file's ladderTook exists to catch.
    local realCreate = mocks.C_StringUtil.CreateAbbreviatedNumberFormatter
    mocks.C_StringUtil.CreateAbbreviatedNumberFormatter = function()
        local f = realCreate()
        f.SetBreakpoints = function() end   -- silently ignored
        return f
    end
    NS.Format.Invalidate()

    local out = NS.Format.Number(4200000)
    mocks.C_StringUtil.CreateAbbreviatedNumberFormatter = realCreate

    assertFalse(tostring(out):find("4200000", 1, true) ~= nil,
        "an unabbreviating formatter must not be the one that renders: " .. tostring(out))
end)

test("Format: the abbreviating formatter is given breakpoints, or it does nothing", function()
    -- The whole bug in one assertion. A formatter with no breakpoints is not
    -- broken and does not raise — it just renders "4200000".
    local inst = T.load()
    inst.NS.Format.Number(4200000)
    local f = inst.mocks.__lastNumericFormatter
    assertEqual(f.__kind, "abbreviated", "the ABBREVIATING type must be the one built")
    assertTrue(f.__breakpoints ~= nil and #f.__breakpoints > 0,
        "and it must have been given a ladder")
end)

test("Format.Number('') for nil, which is a different fact from zero", function()
    assertEqual(T.NS.Format.Number(nil), "")
    assertEqual(T.NS.Format.Rate(nil), "")
    assertEqual(T.NS.Format.Duration(nil), "")
    assertEqual(T.NS.Format.Percent(nil), "")
end)

-- ---------------------------------------------------------------------------
-- Secrets: nothing below divides, and the simulator proves it
-- ---------------------------------------------------------------------------

test("Format.Number accepts a secret and returns something SetText takes", function()
    local inst = restricted()
    local NS, mocks = inst.NS, inst.mocks

    local secret = mocks.secret(4200000)
    assertTrue(mocks.isSimulatedSecret(secret), "the fixture must actually be secret")
    assertFalse(NS.Secrets.CanAccess(secret), "and inaccessible while restricted")

    -- Any Lua arithmetic on `secret` raises MOCK_SECRET_VIOLATION, so reaching
    -- the assertion at all is the proof that nothing here divided.
    local out = NS.Format.Number(secret)
    assertEqual(out, "4.2M", "the NATIVE formatter did the arithmetic")

    -- A FontString takes it: the mock stores SetText's argument raw.
    local fs = mocks.__stubFrame("FontString")
    -- A bare FontString has no font, and SetText on one raises in the client (the
    -- harness models that now — it cost a load once). Real call sites always have
    -- a font by this point; this one is a scratch widget.
    fs:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    fs:SetText(out)
    assertEqual(fs:GetText(), "4.2M")
end)

test("Format.Rate renders the bare number — no unit suffix", function()
    local inst = restricted()
    local NS, mocks = inst.NS, inst.mocks

    -- The column header already says which statistic this is. Restating it per
    -- cell spends most of a column's width on two characters.
    -- red under: `return Number(v, mode) .. rateSuffix()` — the suffix comes back.
    local out = NS.Format.Rate(mocks.secret(300000))
    assertEqual(out, "300.0K")
    assertEqual(out, NS.Format.Number(mocks.secret(300000)),
        "Rate and Number agree on a rate value; only the call site differs")
end)

test("Format.Duration refuses the clock arithmetic on an inaccessible value", function()
    local inst = restricted()
    local NS, mocks = inst.NS, inst.mocks

    -- 212 seconds is 3:32, and computing that is a division and a modulo. While
    -- the value is inaccessible the function must take the OTHER path — the
    -- native formatter plus a suffix — rather than doing the arithmetic.
    local out = NS.Format.Duration(mocks.secret(212))
    assertEqual(out, "212" .. NS.L["s"],
        "an inaccessible duration renders abbreviated with a unit, not as mm:ss")
end)

test("Format.Duration does the clock arithmetic on a plain number", function()
    local F = T.NS.Format
    assertEqual(F.Duration(212), "3:32")
    assertEqual(F.Duration(0), "0:00")
    assertEqual(F.Duration(59.6), "1:00", "rounds to the nearest second")
    assertEqual(F.Duration(3725), "1:02:05", "past an hour it grows a field")
    assertEqual(F.Duration(-5), "0:00", "a negative duration is clamped, never negative-formatted")
end)

test("Format.Percent(value, total) refuses when an operand is inaccessible", function()
    local inst = restricted()
    local NS, mocks = inst.NS, inst.mocks

    -- The ratio form is a division. Both operands secret, one secret, and a zero
    -- denominator all answer EMPTY — never an approximation, and never "0%".
    assertEqual(NS.Format.Percent(mocks.secret(50), mocks.secret(100)), "")
    assertEqual(NS.Format.Percent(mocks.secret(50), 100), "")
    assertEqual(NS.Format.Percent(50, 0), "")
end)

test("Format.Percent computes the ratio when both operands are plain", function()
    local F = T.NS.Format
    assertEqual(F.Percent(25, 200), "12.5%")
    assertEqual(F.Percent(30, 200, 0), "15%", "the decimals argument reaches the format string")
    -- The pre-computed form: the aggregator divides, this only renders.
    assertEqual(F.Percent(12.5), "12.5%")
end)

test("Format.Percent refuses a pre-computed share it cannot access", function()
    local inst = restricted()
    -- A caller that hands a RAW meter value into the one-argument form has made
    -- a mistake; refusing beats guessing.
    assertEqual(inst.NS.Format.Percent(inst.mocks.secret(12.5)), "")
end)

-- ---------------------------------------------------------------------------
-- The degradation ladder
-- ---------------------------------------------------------------------------

test("Format.Number falls back to AbbreviateNumbers when C_StringUtil is absent", function()
    local inst = T.load{ mutate = function(mocks) mocks.C_StringUtil = nil end }
    local NS, mocks = inst.NS, inst.mocks
    mocks.setRestricted(true)

    assertEqual(NS.Compat.CreateNumericRuleFormatter(), nil,
        "the shim must answer nil rather than inventing a Lua formatter")
    assertEqual(NS.Compat.CreateAbbreviatedNumberFormatter(), nil)
    -- Rung 2 is Blizzard's own global, which also accepts a secret. Its rounding
    -- is Blizzard's, not our ladder's — one decimal — and that is fine: this rung
    -- exists so a client without C_StringUtil still reads, not so it matches.
    assertEqual(NS.Format.Number(mocks.secret(4200000)), "4.2M")
    assertEqual(mocks.__lastNumericFormatter, nil, "no native formatter was reachable")
end)

test("Format.Number falls back to SafeToString when neither abbreviator exists", function()
    local inst = T.load{ mutate = function(mocks)
        mocks.C_StringUtil     = nil
        mocks.AbbreviateNumbers = nil
    end }
    local NS, mocks = inst.NS, inst.mocks
    mocks.setRestricted(true)

    -- Rung 3 is honest rather than pretty: it says the number exists and we may
    -- not render it, which is a different fact from "0".
    local out = NS.Format.Number(mocks.secret(4200000))
    assertEqual(type(out), "string", "SetText must still get a string")
    assertFalse(out == "0", "a hidden number must never render as zero")
    assertEqual(out, NS.SafeToString(mocks.secret(1)),
        "the last rung is NS.SafeToString, not tostring")
end)

test("Format.Rate degrades to the bare number when the suffix cannot be joined", function()
    local inst = T.load{ mutate = function(mocks)
        mocks.C_StringUtil      = nil
        mocks.AbbreviateNumbers = nil
    end }
    local NS, mocks = inst.NS, inst.mocks
    mocks.setRestricted(true)

    local out = NS.Format.Rate(mocks.secret(300))
    assertEqual(type(out), "string")
end)

-- ---------------------------------------------------------------------------
-- Static guarantees the header claims
-- ---------------------------------------------------------------------------

--- The CODE of one repo file, with every comment removed — whole-line and
--- trailing alike. The headers here discuss the very APIs the assertions
--- forbid, so a grep that cannot tell prose from code proves nothing either way.
local function codeLines(relPath)
    local fh = assert(io.open(T.root .. "/" .. relPath, "r"))
    local out, n = {}, 0
    for line in fh:lines() do
        n = n + 1
        if not line:match("^%s*%-%-") then
            out[#out + 1] = { n = n, text = (line:gsub("%s%-%-.*$", "")) }
        end
    end
    fh:close()
    return out
end

test("modules/Format.lua never calls tonumber on anything", function()
    -- Coercing a meter value is an inspection, and this file is not
    -- core/Secrets.lua. There is no guarded form of this that is acceptable.
    for _, line in ipairs(codeLines("modules/Format.lua")) do
        assertFalse(line.text:find("tonumber", 1, true) ~= nil,
            "modules/Format.lua:" .. line.n .. " calls tonumber")
    end
end)

test("modules/Format.lua never calls table.concat", function()
    -- `..` is legal on a secret; table.concat is the one string operation that
    -- raises on one — it is literally core/CoreSetup.lua's secret probe.
    for _, line in ipairs(codeLines("modules/Format.lua")) do
        assertFalse(line.text:find("table.concat", 1, true) ~= nil,
            "modules/Format.lua:" .. line.n .. " calls table.concat")
    end
end)

test("Format.Number and Format.Rate contain no division at all", function()
    -- The two functions on the render path. Duration and Percent DO divide, both
    -- behind a core/Secrets.lua gate and on plain numbers only, which the cases
    -- above exercise; these two have no gate because they have no arithmetic.
    local lines = codeLines("modules/Format.lua")
    local inFunction = false
    for _, line in ipairs(lines) do
        local name = line.text:match("^function Format%.(%a+)")
        if name == "Number" or name == "Rate" then
            inFunction = true
        elseif line.text:match("^function ") then
            inFunction = false
        elseif inFunction then
            assertFalse(line.text:find("/") ~= nil,
                "modules/Format.lua:" .. line.n .. " divides on the render path")
        end
    end
end)

test("The three abbreviated modes are one ladder at three decimal counts", function()
    -- The rungs and their letters are identical across all three; only the split
    -- between the significand and its fraction moves. That is what "how many
    -- decimals" means to a NumericRuleFormatter, and it is why scaledLadder
    -- derives the variants rather than restating the array twice.
    -- red under: a variant that abbreviates at a different breakpoint, or one
    -- that silently renders the shipped decimal count.
    local inst = T.load()
    local F = inst.NS.Format

    assertEqual(F.Number(47500, "abbreviated"), "47.5K")
    assertEqual(F.Number(47500, "abbreviatedWhole"), "47K")
    assertEqual(F.Number(47500, "abbreviatedTwo"), "47.50K")
end)

test("Each abbreviated mode caches its own formatter, so two windows cannot fight", function()
    -- Three modes are three objects with three breakpoint arrays. One cache slot
    -- between them would have a window on `abbreviated` rebuilding the object a
    -- window on `abbreviatedWhole` just built, every refresh, forever -- which is
    -- the same argument that gave `full` its own slot.
    -- red under: a single `cache.numeric` shared across the modes.
    local inst = T.load()
    local F = inst.NS.Format

    -- Interleaved on purpose: a shared slot passes when each mode is asked for in
    -- turn and fails the moment they alternate.
    assertEqual(F.Number(47500, "abbreviated"), "47.5K")
    assertEqual(F.Number(47500, "abbreviatedWhole"), "47K")
    assertEqual(F.Number(47500, "abbreviated"), "47.5K")
    assertEqual(F.Number(47500, "abbreviatedWhole"), "47K")
end)

test("An unknown number format renders as the shipped one rather than raising", function()
    -- A profile written against a build with a fourth mode, read by one without
    -- it. The stored string is not a thing this addon can validate at read time,
    -- so the render path answers with the default instead of erroring on a
    -- coalesced refresh ticker.
    -- red under: indexing ABBREVIATIONS without the fallback.
    local inst = T.load()
    assertEqual(inst.NS.Format.Number(47500, "abbreviatedFourteen"), "47.5K")
end)

test("A ladder the client silently refuses is DETECTED, not assumed", function()
    -- SetBreakpoints returning without error is not proof that it took. The live
    -- client rendered "47K" where the ladder says "47.5K", which means it had
    -- quietly kept its own — a pcall that does not throw looked like success and
    -- was not. So the result is measured, on a number this addon owns.
    -- red under: `if pcall(SetBreakpoints, ...) then return end`.
    local inst = T.load{ mutate = function(mocks)
        local real = mocks.C_StringUtil.CreateAbbreviatedNumberFormatter
        mocks.C_StringUtil = setmetatable({
            CreateAbbreviatedNumberFormatter = function()
                local f = real()
                -- Accepts the call, ignores the array: exactly what the live
                -- client appears to do with a breakpoint it does not like.
                f.SetBreakpoints = function(self, list)
                    if list and list[1] and list[1].breakpoint == 0 then return end
                    self.__breakpoints = list
                end
                return f
            end,
        }, { __index = mocks.C_StringUtil })
    end }

    -- The floor entry is what gets refused, so the ladder WITHOUT it must be the
    -- one that ends up installed — not Blizzard's defaults, and not nothing.
    assertEqual(inst.NS.Format.Number(47500), "47.5K")
end)

-- ---------------------------------------------------------------------------
-- Format.DeathTime — how a death is labelled (issue #1)
-- ---------------------------------------------------------------------------
--
-- Three ways to say when somebody died, because there are three different
-- questions a reader has: "when in the evening", "how long ago", and "how far
-- into the fight".

test("Format.DeathTime renders the wall clock by default", function()
    local inst = T.load()
    local F = inst.NS.Numbers or inst.NS.Format
    assertEqual(F.DeathTime(1787381686, "clock", 1787381686),
        inst.mocks.date("%H:%M:%S", 1787381686))
    assertEqual(F.DeathTime(1787381686, nil, 1787381686),
        inst.mocks.date("%H:%M:%S", 1787381686), "an unset style is the clock")
end)

test("Format.DeathTime counts backwards from now", function()
    local inst = T.load()
    local F = inst.NS.Numbers or inst.NS.Format
    -- 8 minutes and change before `now`.
    local now = 1787381686
    local text = F.DeathTime(now - 500, "ago", now)
    assertTrue(text:find("8", 1, true) ~= nil, "500s is 8 minutes, got " .. text)
    assertTrue(F.DeathTime(now - 20, "ago", now):lower():find("s") ~= nil,
        "under a minute must read in seconds, not '0 min'")
end)

test("Format.DeathTime answers nil when there is no timestamp at all", function()
    local inst = T.load()
    local F = inst.NS.Numbers or inst.NS.Format
    assertTrue(nil == F.DeathTime(nil, "clock", 1787381686))
    assertTrue(nil == F.DeathTime(nil, "ago", 1787381686))
end)

test("Format.DeathTime never inspects a secret", function()
    -- Every one of these is arithmetic or a comparison, and all three inputs
    -- come off a recap. A refused input answers nil rather than raising.
    local inst = T.load()
    local F = inst.NS.Numbers or inst.NS.Format
    inst.mocks.setSecretsAccessible(false)
    local secret = inst.mocks.secret(1787381686)
    assertTrue(pcall(F.DeathTime, secret, "clock", 1787381686))
    assertTrue(nil == F.DeathTime(secret, "clock", 1787381686))
end)

-- ---------------------------------------------------------------------------
-- Format.DeathTime — the arms nothing above reaches (characterization,
-- performance-§11)
-- ---------------------------------------------------------------------------
--
-- The cases above pin the two headline answers: a wall clock, and "8 minutes
-- ago". What they do NOT pin is every other arm of the same function — the
-- minute/second boundary, the clamp, the two ways `now` can be refused, and the
-- style that is neither "clock" nor "ago". Each of those is a branch a rewrite
-- can drop without any existing case going red, so each gets a case here.

test("Format.DeathTime: the seconds/minutes boundary and the exact strings", function()
    local inst = T.load()
    local F = inst.NS.Numbers or inst.NS.Format
    local now = 1787381686
    -- Under a minute reads in whole seconds; 60 is the first reading that is
    -- allowed to say "minutes" at all. The header calls the seconds branch out
    -- by name — "0 min ago" for a death that happened while you were reading the
    -- tooltip is worse than saying nothing — so the boundary is the contract and
    -- not an implementation detail.
    assertEqual(F.DeathTime(now - 59, "ago", now), "59s ago")
    assertEqual(F.DeathTime(now - 60, "ago", now), "1m ago")
    -- Minutes TRUNCATE rather than round: 119 seconds is one minute, not two. A
    -- refactor reaching for a tidier `math.floor(x / 60 + 0.5)` changes every
    -- second reading in the tooltip.
    assertEqual(F.DeathTime(now - 119, "ago", now), "1m ago")
    assertEqual(F.DeathTime(now - 500, "ago", now), "8m ago")
    -- There is NO hour rung. An hour-old death reads "60m ago", deliberately —
    -- a session that long is the exception and a third unit would be a third
    -- string to translate for it.
    assertEqual(F.DeathTime(now - 3600, "ago", now), "60m ago")
end)

test("Format.DeathTime clamps a death in the future to zero", function()
    local inst = T.load()
    local F = inst.NS.Numbers or inst.NS.Format
    local now = 1787381686
    -- The recap's clock and ours are two different clocks, and a death stamped a
    -- second ahead of `now` is ordinary. Clamped, so the reader never sees
    -- "-1m ago" or a negative second count.
    assertEqual(F.DeathTime(now + 5, "ago", now), "0s ago")
    assertEqual(F.DeathTime(now, "ago", now), "0s ago")
end)

test("Format.DeathTime treats any unknown style as the clock", function()
    local inst = T.load()
    local F = inst.NS.Numbers or inst.NS.Format
    local when = 1787381686
    local clock = inst.mocks.date("%H:%M:%S", when)
    -- "ago" is the ONLY special style; everything else falls through. This is
    -- what makes the removed third style ("how far into the fight", issue #18)
    -- safe to leave in a saved profile: a stored `style = "elapsed"` renders a
    -- wall clock rather than nil and an em dash.
    assertEqual(F.DeathTime(when, "elapsed", when), clock)
    assertEqual(F.DeathTime(when, "fight", when), clock)
    assertEqual(F.DeathTime(when, "AGO", when), clock, "the style match is case-sensitive")
end)

test("Format.DeathTime falls back to the clock when 'now' cannot be had", function()
    local inst = T.load()
    local F = inst.NS.Numbers or inst.NS.Format
    local when = 1787381686
    local clock = inst.mocks.date("%H:%M:%S", when)

    -- A REFUSED comparison is not a refused format. `when` is accessible here and
    -- `now` is not, so the countdown cannot be computed — but the wall clock
    -- still can, and that is what the reader gets. Answering nil here would draw
    -- an em dash over a timestamp we are holding.
    inst.mocks.setSecretsAccessible(false)
    local secretNow = inst.mocks.secret(when + 300)
    assertTrue(pcall(F.DeathTime, when, "ago", secretNow), "a secret 'now' must not raise")
    assertEqual(F.DeathTime(when, "ago", secretNow), clock)

    -- Same answer when there is no clock in the client at all: `time` absent is
    -- the degraded case, and it degrades to the clock rather than to nothing.
    local realTime = inst.mocks.time
    inst.mocks.time = nil
    local out = F.DeathTime(when, "ago")
    inst.mocks.time = realTime
    assertEqual(out, clock, "no time() means no countdown, but still a clock")
end)

test("Format.DeathTime defaults 'now' to the client clock", function()
    local inst = T.load()
    local F = inst.NS.Numbers or inst.NS.Format
    local realTime = inst.mocks.time
    -- The third argument exists so the suite can pin the arithmetic; the CALLERS
    -- (modules/Tooltip.lua, modules/DrillDown.lua) pass two arguments and rely on
    -- `time()` being read fresh on every call. Pinned by moving the clock and
    -- watching the same death read differently.
    inst.mocks.time = function() return 1787381686 end
    local first = F.DeathTime(1787381686 - 120, "ago")
    inst.mocks.time = function() return 1787381686 + 180 end
    local second = F.DeathTime(1787381686 - 120, "ago")
    inst.mocks.time = realTime
    assertEqual(first, "2m ago")
    assertEqual(second, "5m ago", "time() must be read per call, not cached")
end)

test("Format.DeathTime routes both countdown strings through the locale", function()
    local inst = T.load()
    local F = inst.NS.Numbers or inst.NS.Format
    local now = 1787381686
    -- Both readings are L keys, not literals baked into the format call. A
    -- translator changes the unit and the word order here; the "%d" is the only
    -- part the module owns.
    inst.NS.L["%ds ago"] = "vor %ds"
    inst.NS.L["%dm ago"] = "vor %dm"
    assertEqual(F.DeathTime(now - 30, "ago", now), "vor 30s")
    assertEqual(F.DeathTime(now - 600, "ago", now), "vor 10m")
end)

test("Format.DeathTime refuses a secret timestamp in either style", function()
    local inst = T.load()
    local F = inst.NS.Numbers or inst.NS.Format
    inst.mocks.setSecretsAccessible(false)
    local secret = inst.mocks.secret(1787381686)
    -- The "clock" half of this is pinned above; the "ago" half is the one that
    -- would raise, because it subtracts. The guard is on `when` at the top of the
    -- function and covers both, and it answers nil — the caller draws an em dash.
    assertTrue(pcall(F.DeathTime, secret, "ago", 1787381686))
    assertTrue(nil == F.DeathTime(secret, "ago", 1787381686))
    -- The refusal comes BEFORE `date` is reached, so an inaccessible timestamp is
    -- never handed to a client API either.
    assertTrue(nil == F.DeathTime(secret, "ago"))
end)

-- ---------------------------------------------------------------------------
-- Issue #26 -- a rate below 1000 rendered every decimal digit it had
-- ---------------------------------------------------------------------------
--
-- The live cell read `411.90476190...`. Two of the degradation ladder's
-- candidates carried no rule below 1000 -- the ladder without its floor, and the
-- client's own defaults -- so a client that refused our arrays fell through to a
-- plain render, which for a float is every digit. And `full` mode's formatter set
-- one fractional rung, never probed it and had no fallback at all.

test("A sub-thousand rate stays whole even when the client's OWN ladder is in force (#26)", function()
    -- A client that silently keeps its own rules whenever an array carries a
    -- K/M/B rung that is not one of its own -- the shape the issue's `206K`
    -- (no decimal) points at. Its defaults have nothing below 1000.
    -- red under: installing GetDefaultAbbreviationBreakpoints() bare.
    local inst = T.load{ mutate = function(mocks)
        local real = mocks.C_StringUtil.CreateAbbreviatedNumberFormatter
        local defaults = mocks.C_StringUtil.GetDefaultAbbreviationBreakpoints()
        local own = {}
        for _, bp in ipairs(defaults) do own[bp] = true end
        mocks.C_StringUtil = setmetatable({
            GetDefaultAbbreviationBreakpoints = function() return defaults end,
            CreateAbbreviatedNumberFormatter = function()
                local f = real()
                f.SetBreakpoints = function(self, list)
                    for _, bp in ipairs(list) do
                        if bp.abbreviation ~= "" and not own[bp] then return end
                    end
                    self.__breakpoints = list
                end
                return f
            end,
        }, { __index = mocks.C_StringUtil })
    end }
    local F = inst.NS.Format

    assertEqual(F.Number(47500), "47K", "the client's own K rung is the one in force")
    assertEqual(F.Number(411.90476190476), "411", "a sub-thousand rate renders its whole part")
    assertEqual(F.Rate(411.90476190476), "411")
    assertEqual(F.Number(0.42857142857143), "0")
end)

test("'full' keeps a sub-thousand rate whole on a client that refuses a fractional breakpoint (#26)", function()
    -- red under: plain() setting its single 0.001 rung with no probe and no
    -- fallback, which leaves the formatter with no rule at all.
    local inst = T.load{ mutate = function(mocks)
        local real = mocks.C_StringUtil.CreateNumericRuleFormatter
        mocks.C_StringUtil = setmetatable({
            CreateNumericRuleFormatter = function()
                local f = real()
                f.SetBreakpoints = function(self, list)
                    for _, bp in ipairs(list) do
                        if bp.breakpoint < 1 then return end
                    end
                    self.__breakpoints = list
                end
                return f
            end,
        }, { __index = mocks.C_StringUtil })
    end }
    local F = inst.NS.Format

    assertEqual(F.Number(411.90476190476, "full"), "411")
    assertEqual(F.Number(4200000, "full"), "4200000", "and full still abbreviates nothing")
end)
