-- tests/test_slash_refusal.lua
--
-- The refusals settings/Slash.lua's schema seams hand back to LibKa0s-Slash-1.0
-- (minor 15). A sibling of tests/test_slash.lua, which is near the line cap.
--
-- ── WHY THE SEAMS ANSWER ─────────────────────────────────────────────────────
--
-- CliSet re-reads the stored value and echoes it as `<path> = <value>`. When the
-- write seam refused the value, that echo is the OLD value printed as though the
-- write had landed. From minor 15 the descriptor's `set` MAY answer
-- `false, reason[, why]`, and CliSet prints the INVALID line and the reason
-- instead of the echo. `applyDefault` answering exactly false does the same for
-- CliReset on a row with no default: NO_DEFAULT, not an echo of the unchanged
-- value. The adapters used to swallow NS.SetByPath's and NS.ApplyDefault's
-- answers, so the library never saw a refusal.

local T = _G.MULTIMETERS_TEST
local test = T.test
local assertEqual, assertTrue = T.assertEqual, T.assertTrue

--- Every chat line one command produced, on a fresh instance.
local function say(inst, msg)
    local n = #inst.mocks.__chat
    inst.NS.Slash:OnSlash(msg)
    local out = {}
    for i = n + 1, #inst.mocks.__chat do out[#out + 1] = inst.mocks.__chat[i] end
    return out
end

local function joined(lines) return table.concat(lines, "\n") end

local function has(text, needle) return text:find(needle, 1, true) ~= nil end

test("Slash refusal: `set` a value the row's validate refuses prints the refusal, not the old value", function()
    local inst = T.load()
    local NSi = inst.NS
    -- The pinned segment has no min/max for the parser to clamp to, so -5 reaches
    -- the seam intact and the row's validate (0, or a positive integer) refuses it.
    -- `window.frame.width -5` cannot show this: the parser clamps it to the row's
    -- min of 160 before the seam sees it, and 160 is a valid width.
    local before = NSi.GetSetting("window.data.sessionID")
    local shown = joined(say(inst, "set window.data.sessionID -5"))
    assertTrue(has(shown, "Invalid value for window.data.sessionID"),
        "the refusal must be printed, got: " .. shown)
    assertTrue(not has(shown, " = "),
        "a refused write must not echo the unchanged value as though it landed, got: " .. shown)
    assertEqual(NSi.GetSetting("window.data.sessionID"), before, "nothing was stored")
end)

test("Slash refusal: `reset` on a row with no default prints NO_DEFAULT and keeps the value", function()
    local inst = T.load()
    local NSi = inst.NS
    NSi.RegisterSchemaRows({
        { path = "window.frame.noDefaultProbe", type = "number", page = "frame" },
    })
    say(inst, "set window.frame.noDefaultProbe 5")
    assertEqual(NSi.GetSetting("window.frame.noDefaultProbe"), 5, "precondition: the probe row holds 5")

    local shown = joined(say(inst, "reset window.frame.noDefaultProbe"))
    assertTrue(has(shown, "window.frame.noDefaultProbe has no default to restore"),
        "the library's NO_DEFAULT line, got: " .. shown)
    assertEqual(NSi.GetSetting("window.frame.noDefaultProbe"), 5,
        "a row with no default is left alone, not written to nil")
end)

-- ── every acknowledgment reads the locale (MultiMeters-R-11) ───────────────
--
-- The feature verbs' acknowledgments used to be raw English, and the
-- reset-positions count built its plural by concatenating "1 window" or
-- "N windows" into a sentence, which no translation can reorder. Each is now a
-- whole-sentence key read through NS.L, with the plural as two distinct keys
-- (localization-§1). A spy on NS.L's reads is what shows a line came through
-- the locale rather than merely printing the same English: the fallback answers
-- every key with itself, so the chat text alone cannot tell the two apart.

--- Record every key read from `inst.NS.L` from now on. The declared entries are
--- moved into a shadow table so that every read, declared or not, reaches the
--- recording `__index`; the table's identity is kept, because settings/Slash.lua
--- captured it at load.
local function spyLocale(inst)
    local L = inst.NS.L
    local store, reads = {}, {}
    for k, v in pairs(L) do store[k] = v end
    for k in pairs(store) do L[k] = nil end
    setmetatable(L, { __index = function(_, k)
        reads[k] = (reads[k] or 0) + 1
        local v = store[k]
        if v == nil then return k end
        return v
    end })
    return reads
end

local ACK_KEYS = {
    { "lock on",    "Windows are locked." },
    { "lock off",   "Windows are unlocked \226\128\148 drag them into place." },
    { "test on",    "test mode on \226\128\148 showing placeholder rows" },
    { "test off",   "test mode off" },
    { "debug feign on",  "feign trace ON \226\128\148 run the dungeon, then `/mm debug feign`." },
    { "debug feign off", "feign trace off." },
    { "debug feign of",
      "unknown feign argument '%s' \226\128\148 `/mm debug feign on|off`, or `/mm debug feign` to print the recording." },
}

test("Slash locale: every feature-verb acknowledgment reads its whole-sentence key", function()
    for _, case in ipairs(ACK_KEYS) do
        local inst = T.load()
        local reads = spyLocale(inst)
        local shown = joined(say(inst, case[1]))
        assertTrue((reads[case[2]] or 0) > 0,
            ("`/mm %s` must read L[%q], printed: %s"):format(case[1], case[2], shown))
    end
end)

test("Slash locale: `debug tooltip` reads the key for the state it landed in", function()
    local inst = T.load()
    local reads = spyLocale(inst)
    say(inst, "debug tooltip")
    assertTrue((reads["tooltip logging ON \226\128\148 mouse over a row and read the console."] or 0) > 0,
        "turning tooltip logging on reads its key")
    say(inst, "debug tooltip")
    assertTrue((reads["tooltip logging off."] or 0) > 0, "turning it off reads its key")
end)

test("Slash locale: reset-positions says its plural through two distinct keys", function()
    local ONE, MANY = "Moved 1 window back to the center.", "Moved %d windows back to the center."
    local inst = T.load()
    local reads = spyLocale(inst)
    assertEqual(#inst.NS.Database.GetWindows(), 1, "precondition: a fresh profile holds one window")
    local shown = joined(say(inst, "reset-positions"))
    assertTrue((reads[ONE] or 0) > 0 and not reads[MANY], "one window reads the singular key, got: " .. shown)
    assertTrue(has(shown, ONE), "and prints it: " .. shown)

    inst = T.load()
    say(inst, "window new Second")
    say(inst, "window new Third")
    reads = spyLocale(inst)
    shown = joined(say(inst, "reset-positions"))
    assertTrue((reads[MANY] or 0) > 0 and not reads[ONE], "three windows read the plural key, got: " .. shown)
    assertTrue(has(shown, MANY:format(3)), "and print the count: " .. shown)
end)
