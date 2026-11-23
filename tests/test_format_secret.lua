-- tests/test_format_secret.lua — a secret number follows the window's number format (R3).
--
-- THE CLIENT REFUSES TO FORMAT A SECRET FOR AN ADDON. `FormatNumber` is documented
-- `SecretArguments = "AllowedWhenUntainted"` (Blizzard_APIDocumentationGenerated,
-- NumericFormatterAPIDocumentation.lua), and addon code is always tainted, so both
-- formatter instances raise on a secret, which is what a number is for the whole of a pull.
-- `AbbreviateNumbers` is `AllowedWhenTainted` and takes an options table whose `config` is a
-- cached `CreateAbbreviateConfig(breakpoints)` object.
--
-- Before this fix every secret cell paid a raised and caught error, then fell to a bare
-- `AbbreviateNumbers(v)` that knows none of the decimals settings and renders a sub-1000
-- rate digit for digit ("69.5625" in a 92 px cell). tests/wow_mock.lua now models both
-- halves of that: the formatter raises on a secret, and the bare call keeps the digits.
--
-- The fix asks Secrets.IsSecret first and, for a secret, calls AbbreviateNumbers with a
-- config built ONCE per mode, trusted only when it renders this addon's own plain probes
-- exactly. A config the client refuses, or one that renders anything else, leaves the cell
-- on the old path, so a client that will not take it looks as it does today.

local T = _G.MULTIMETERS_TEST

local test         = T.test
local assertEqual  = T.assertEqual
local assertTrue   = T.assertTrue

local function restricted(mutate)
    local inst = T.load(mutate and { mutate = mutate } or nil)
    inst.mocks.setRestricted(true)
    return inst
end

-- One plain number per mode and what the mode's own ladder renders it as.
local EXPECTED = {
    abbreviated      = { total = "47.5K",  rate = "69" },
    abbreviatedWhole = { total = "47K",    rate = "69" },
    abbreviatedTwo   = { total = "47.50K", rate = "69" },
    full             = { total = "47500",  rate = "69" },
}

test("FormatSecret: the mock formatter refuses a secret, as the client does", function()
    -- The premise the fix rests on. red under: a mock FormatNumber that reveals the secret.
    local inst = restricted()
    local f = inst.mocks.C_StringUtil.CreateAbbreviatedNumberFormatter()
    local ok = pcall(f.FormatNumber, f, inst.mocks.secret(47500))
    assertTrue(not ok, "FormatNumber must raise on a secret")
end)

test("FormatSecret: a secret renders by the window's number format in every mode", function()
    -- red under: the old path, which renders every mode as the bare "47.5K" and a
    -- sub-1000 secret rate as its float digits.
    local inst = restricted()
    local NS, mocks = inst.NS, inst.mocks
    for mode, want in pairs(EXPECTED) do
        assertEqual(NS.Format.Number(mocks.secret(47500), mode), want.total, mode .. " total")
        assertEqual(NS.Format.Rate(mocks.secret(69.5625), mode), want.rate, mode .. " rate")
        -- A plain value in the same mode renders the same string: one look in and out of combat.
        assertEqual(NS.Format.Number(47500, mode), want.total, mode .. " plain total")
    end
end)

test("FormatSecret: a secret never reaches FormatNumber, so no error is raised per cell", function()
    local inst = restricted()
    local NS, mocks = inst.NS, inst.mocks
    NS.Format.Number(47500)  -- builds and probes the formatter
    local f = mocks.__lastNumericFormatter
    local before = f.__formatCount
    NS.Format.Number(mocks.secret(47500))
    assertEqual(f.__formatCount, before, "the secret was handed to FormatNumber")
end)

test("FormatSecret: the config is built once per mode and dropped by Invalidate", function()
    local inst = restricted()
    local NS, mocks = inst.NS, inst.mocks
    NS.Format.Number(mocks.secret(1), "abbreviatedTwo")
    local afterFirst = mocks.__abbreviateConfigCount
    assertTrue(afterFirst >= 1, "no config was built")
    for _ = 1, 5 do NS.Format.Number(mocks.secret(47500), "abbreviatedTwo") end
    assertEqual(mocks.__abbreviateConfigCount, afterFirst, "the config was rebuilt per cell")
    NS.Format.Number(mocks.secret(1), "abbreviatedWhole")
    assertTrue(mocks.__abbreviateConfigCount > afterFirst, "a second mode shares the first's config")
    local twoModes = mocks.__abbreviateConfigCount
    NS.Format.Invalidate()
    NS.Format.Number(mocks.secret(1), "abbreviatedTwo")
    assertTrue(mocks.__abbreviateConfigCount > twoModes, "Invalidate kept a stale config")
end)

test("FormatSecret: a config the client refuses leaves the old path", function()
    -- red under: trusting a config without probing it, or letting the refusal raise.
    local inst = restricted(function(mocks)
        mocks.CreateAbbreviateConfig = function() error("InvalidBreakpoint") end
    end)
    local NS, mocks = inst.NS, inst.mocks
    assertEqual(NS.Format.Number(mocks.secret(47500), "abbreviatedTwo"), "47.5K",
        "the old path is the bare AbbreviateNumbers")
end)

test("FormatSecret: a config that renders a probe wrongly is not trusted", function()
    -- A client that takes the config but renders it wrongly: it drops the fraction, so
    -- abbreviatedTwo's probe draws "47K" where the ladder wants "47.50K". The bare call
    -- (no options) is untouched, so the old path still draws "47.5K".
    -- red under: trusting a config without the abbreviatesAs probes in provenOptions,
    -- which hands the cell the wrong render, "47K".
    local inst = restricted(function(mocks)
        local real = mocks.AbbreviateNumbers
        mocks.AbbreviateNumbers = function(v, options)
            local out = real(v, options)
            if options and options.config then out = (out:gsub("%.%d+", "")) end
            return out
        end
    end)
    local NS, mocks = inst.NS, inst.mocks
    assertEqual(NS.Format.Number(mocks.secret(47500), "abbreviatedTwo"), "47.5K",
        "a config that failed its probes was trusted")
end)

test("FormatSecret: a secret duration takes the same route and keeps its unit", function()
    local inst = restricted()
    local NS, mocks = inst.NS, inst.mocks
    assertEqual(NS.Format.Duration(mocks.secret(212.75)), "212" .. NS.L["s"])
end)
