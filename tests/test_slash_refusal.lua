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
