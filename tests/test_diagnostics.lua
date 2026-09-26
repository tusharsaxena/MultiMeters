-- tests/test_diagnostics.lua — core/Diagnostics.lua, the sections of the
-- `/mm diagnostics` report (debug-logging-§14).
--
-- The report exists because three display bugs in a row were caused by assuming
-- something about the running client and never checking it. So the property that
-- matters most here is that the report itself cannot become another one: it must
-- run to completion on a hostile client, print rather than raise, and never be
-- the reason a player cannot describe what they are seeing.
--
-- What lives here is the frame, the entry point and the short probes — the same
-- cut core/Diagnostics.lua was peeled along, and for the same reason. A probe
-- written for one issue is meant to be DELETED WITH THAT ISSUE, which only works
-- if its cases go out with it, so each long-lived probe's cases sit beside its
-- module in a sibling suite: test_diagnostics_deathrecap.lua (issue #1),
-- test_diagnostics_identity.lua (issue #22) and test_diagnostics_feign.lua
-- (issue #25).

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertFalse = T.assertFalse

--- Run the report and hand back everything it wrote, as one string.
---
--- The report is the LibKa0s helper's (`RunDiagnostics`, debug-logging-§14): it
--- writes every line into the debug console buffer, after whatever is already
--- there, and prints ONE chat line naming the count. The content cases below read
--- the buffer; the routing is left to the cases that actually test it.
local function report(inst)
    local D      = inst.NS.DebugLog
    local buffer = D.buffer
    local bufN   = #buffer

    D:RunDiagnostics()

    local lines = {}
    for i = bufN + 1, #buffer do lines[#lines + 1] = buffer[i] end
    return table.concat(lines, "\n"), lines
end

local BRAND = "Ka0s Multi Meters"

test("Diagnostics: the sections are handed to the LibKa0s helper, not run by hand", function()
    -- debug-logging-§14 (STD-16): the host writes SECTIONS only. The line buffer,
    -- the per-section pcall, the markers and the cap are the library's, so this
    -- file publishes a section list and nothing that runs it.
    -- red under: a host-written Report() that loops, pcalls and prints itself.
    local inst = T.load{ enable = true }
    local Diag = inst.NS.Diagnostics
    assertEqual(type(Diag.Sections), "function", "the section list is published")
    assertEqual(Diag.Report, nil, "the hand-rolled entry point is retired")
    local list = Diag.Sections()
    assertTrue(#list >= 12, "every existing section is on the list: " .. #list)
    for _, entry in ipairs(list) do
        assertEqual(type(entry[1]), "string", "each section is named")
        assertEqual(type(entry[2]), "function", "each section is a function of the writer")
    end
end)

test("Diagnostics: the report carries both markers with the addon's brand", function()
    -- STD-08: the first line is the begin marker and the last the end marker with
    -- the line count, both naming `Ka0s Multi Meters`.
    -- red under: a descriptor with no `brandName`, which falls back to the title.
    local inst = T.load{ enable = true }
    local _, lines = report(inst)
    assertTrue(lines[1]:find("[Diag] ==== " .. BRAND .. " diagnostics begin ====", 1, true) ~= nil,
        "the first line is the begin marker: " .. tostring(lines[1]))
    local last = lines[#lines]
    assertTrue(last:find("[Diag] ==== " .. BRAND .. " diagnostics end: " .. #lines
        .. " line(s) ====", 1, true) ~= nil, "the last line is the end marker: " .. tostring(last))
end)

test("Diagnostics: the report is plain text, with no color escapes left in it", function()
    -- STD-11: the sections still color their headings and verdicts, and the
    -- helper strips every escape so the Copy text pastes clean.
    -- red under: sections written straight to the console, around the helper.
    local inst = T.load{ enable = true }
    local _, lines = report(inst)
    for _, line in ipairs(lines) do
        assertTrue(line:find("|c%x%x%x%x%x%x%x%x") == nil and line:find("|r", 1, true) == nil,
            "a color escape survived: " .. line)
    end
end)

test("Diagnostics: the report prints exactly one chat line, naming Copy", function()
    -- STD-09: the lines go to the console, and chat gets one tagged line with the
    -- count. Chat interleaves everything with combat spam, so the report itself
    -- never lands there.
    local inst = T.load{ enable = true }
    local chatN = #inst.mocks.__chat
    local _, lines = report(inst)
    assertEqual(#inst.mocks.__chat, chatN + 1, "the report spammed chat, or said nothing")
    local said = inst.mocks.__chat[#inst.mocks.__chat]
    assertTrue(said:find(tostring(#lines), 1, true) ~= nil, "the line names the count: " .. said)
    assertTrue(said:find("Copy", 1, true) ~= nil, "and names Copy: " .. said)
end)

test("Diagnostics: with LibKa0s absent both forms print the placeholder and nothing else", function()
    -- STD-14: the DebugLog stub has no console to write into, so the report is the
    -- collection's one placeholder line, naming `/mm diagnostics`, from either form.
    -- red under: a form that bypasses the stub's RunDiagnostics.
    local inst = T.load{ libFiles = {} }
    for _, form in ipairs({ "diagnostics", "debug diagnostics" }) do
        local n = #inst.mocks.__chat
        inst.NS.Slash:OnSlash(form)
        assertEqual(#inst.mocks.__chat, n + 1, "`/mm " .. form .. "` printed one line")
        assertTrue(inst.mocks.__chat[#inst.mocks.__chat]:find(
            "/mm diagnostics is unavailable: the LibKa0s library did not load.", 1, true) ~= nil,
            "`/mm " .. form .. "` printed the placeholder")
    end
end)

test("Diagnostics: every section appears", function()
    local inst = T.load{ enable = true }
    local text = report(inst)
    for _, section in ipairs({ "atlases", "number formatting", "visibility",
                               "header", "name column", "cells" }) do
        assertTrue(text:find(section, 1, true) ~= nil, "missing section: " .. section)
    end
end)

test("Diagnostics: the rejected event names are printed, or `none`", function()
    -- events-frames-taint-§1: the record of refused names has to be reachable by
    -- the player, and this report is what a player is asked to paste.
    -- red under: a report with no events section.
    local clean = report(T.load{ enable = true })
    assertTrue(clean:find("rejected events: none", 1, true) ~= nil, "no rejected-events line")

    local inst = T.load{ enable = true, mutate = function(m)
        m.__badEvents = { UNIT_SPELLCAST_SUCCEEDED = true }
    end }
    local text = report(inst)
    assertTrue(text:find("rejected events: UNIT_SPELLCAST_SUCCEEDED", 1, true) ~= nil,
        "the refused name is not in the report")
end)

test("Diagnostics: it reports what the CLIENT has, not what the addon wants", function()
    -- The whole point. Importing the addon's own candidate list would report on
    -- our opinion instead of on the client's, and reporting on our own opinion is
    -- how the three bugs happened.
    local inst = T.load{ enable = true }
    inst.mocks.setAtlases({ ["common-icon-settings"] = true })

    local text = report(inst)
    assertTrue(text:find("common%-icon%-settings%s+yes") ~= nil,
        "an atlas the client HAS must read yes")
    assertTrue(text:find("common%-icon%-lock%s+no") ~= nil,
        "and one it lacks must read no")
end)

test("Diagnostics: a number that misses the ladder is FLAGGED, not just printed", function()
    -- A column of numbers with no expectation beside them is a column somebody
    -- has to check by eye, which is the step that keeps going wrong.
    local inst = T.load{ enable = true }
    local text = report(inst)
    assertTrue(text:find("47500", 1, true) ~= nil, "the probe values must appear")
    assertTrue(text:find("47.5K", 1, true) ~= nil, "and what each one should render as")
end)

test("Diagnostics: one broken section cannot take the report down", function()
    -- A diagnostic that dies halfway is worse than none, because it looks like
    -- the thing it was diagnosing. STD-12: a raise costs exactly ONE line,
    -- `section <name> failed: <err>`, and the next section runs.
    -- red under: a section adapter that swallows the raise, or one that leaves
    -- the sink pointed at the dead section's writer.
    local inst = T.load{ enable = true }
    inst.NS.Tooltip.WidthParts = function() error("boom", 2) end

    local text, lines = report(inst)
    local failed = 0
    for _, line in ipairs(lines) do
        if line:find("section tooltip width failed:", 1, true) then failed = failed + 1 end
    end
    assertEqual(failed, 1, "the broken section says so, on exactly one line")
    assertTrue(text:find("boom", 1, true) ~= nil, "and the line carries the error")
    assertTrue(text:find("atlases", 1, true) ~= nil, "sections before the break still ran")
    assertTrue(text:find("targets cross-reference", 1, true) ~= nil,
        "and sections after it still ran")
end)

test("Diagnostics: it never renders a meter value", function()
    -- It reports on widgets and APIs, never on numbers. A cell's stored figure is
    -- described rather than read: rendering it would be legal and INSPECTING it to
    -- describe it would not (rule R1). The simulator raises on an inspection, and
    -- every section runs under the helper's pcall, so the proof is that NO section
    -- reports a failure.
    local inst = T.load{ enable = true }
    inst.mocks.setRestricted(true)
    inst.mocks.setSecretValues(true)

    local text = report(inst)
    assertTrue(text:find(" failed: ", 1, true) == nil, "a section inspected a secret: " .. text)
end)

test("Diagnostics: one visibility line per window, from the debug pass's last answer", function()
    -- Visibility.LastResult is filled only by the debug-gated Evaluate pass
    -- (MultiMeters-R-09), and this report is its reader. With debug off the line
    -- says the pass never ran instead of guessing; with debug on it prints the
    -- answer the pass remembered.
    local inst = T.load{ enable = true }
    local NS = inst.NS
    local windows = NS.Database.GetWindows()

    NS.State.debug = false
    local _, lines = report(inst)
    local seen = 0
    for _, line in ipairs(lines) do
        if line:find("last pass #", 1, true) then
            seen = seen + 1
            assertTrue(line:find("not evaluated (debug was off)", 1, true) ~= nil, line)
        end
    end
    assertEqual(seen, #windows, "one visibility line per window")

    NS.State.debug = true
    NS.Visibility:Evaluate()
    local _, reason = NS.Visibility.LastResult(windows[1].id)
    local text = report(inst)
    assertTrue(text:find("last pass #" .. tostring(windows[1].id) .. ": ", 1, true) ~= nil)
    assertTrue(text:find("(" .. reason .. ")", 1, true) ~= nil,
        "the line must carry the ladder's reason")
end)

test("Diagnostics: with no window it says so rather than erroring", function()
    local inst = T.load{}
    local text = report(inst)
    assertFalse(text == "", "the report must still print")
end)

-- ---------------------------------------------------------------------------
-- Where the report goes
-- ---------------------------------------------------------------------------

test("Diagnostics: the report lands in the debug console, not in chat", function()
    -- Forty lines a player has to hand back verbatim belong in the window that
    -- has a buffer, scrollback and a copy button. Chat interleaves them with
    -- combat spam, so a report pasted out of it arrives shuffled.
    -- red under: a section adapter that leaves `out` on NS.Print.
    local inst = T.load{ enable = true }
    local D = inst.NS.DebugLog

    local chatN, bufN = #inst.mocks.__chat, #D.buffer
    D:RunDiagnostics()

    assertTrue(#D.buffer > bufN + 10, "the report did not reach the console buffer")
    assertEqual(#inst.mocks.__chat, chatN + 1, "only the one count line goes to chat")
end)

test("Diagnostics: the console is OPENED, so the report is not written out of sight", function()
    -- Writing into a closed window would be the same failure as writing into a
    -- no-op: the player sees nothing and reports that the command does nothing.
    -- red under: Add without Show.
    local inst = T.load{ enable = true }
    inst.NS.DebugLog:Hide()
    assertFalse(inst.NS.DebugLog:IsShown(), "the console was already open")

    inst.NS.DebugLog:RunDiagnostics()
    assertTrue(inst.NS.DebugLog:IsShown(), "the report never opened the console")
end)

test("Diagnostics: a font size read back as 10.000000953674 is not called a failure", function()
    -- The client stores a font size as a float and reads 10 back as
    -- 10.000000953674, so an equality test reported "SetFont did not take" for a
    -- SetFont that took perfectly. A diagnostic that confidently names the wrong
    -- cause is worse than no diagnostic — it sends the fix to the wrong place.
    -- red under: `sample.setSize ~= sample.askedSize`.
    local inst = T.load{ enable = true }
    inst.NS.Tooltip.__fontProbe = {
        index = 4, line = inst.mocks.__stubFrame("FontString"),
        askedPath = "X.ttf", askedSize = 10,               askedFlags = "OUTLINE",
        setPath   = "X.ttf", setSize   = 10.000000953674,  setFlags   = "OUTLINE",
        showPath  = "X.ttf", showSize  = 10.000000953674,  showFlags  = "OUTLINE",
    }

    local text = report(inst)
    assertFalse(text:find("SetFont did not take") ~= nil,
        "a float-precision difference was reported as a refused SetFont")
    assertTrue(text:find("stuck through layout") ~= nil,
        "the font verdict is missing entirely")
end)

test("Diagnostics: a font the layout reverted is named as such", function()
    -- The other half of the same verdict, and the one the live client hit: the
    -- SetFont takes, and the show path re-fonts the line at its own size with no
    -- flags. That needs the opposite fix to a refused SetFont, so the report has
    -- to tell them apart.
    -- red under: collapsing the two branches into one message.
    local inst = T.load{ enable = true }
    inst.NS.Tooltip.__fontProbe = {
        index = 13, line = inst.mocks.__stubFrame("FontString"),
        askedPath = "X.ttf", askedSize = 10,              askedFlags = "OUTLINE",
        setPath   = "X.ttf", setSize   = 10.000000953674, setFlags   = "OUTLINE",
        showPath  = "X.ttf", showSize  = 10.999999046326, showFlags  = "",
    }

    local text = report(inst)
    assertTrue(text:find("the layout reverted it") ~= nil,
        "a reverted font was not reported as a revert")
end)

-- ---------------------------------------------------------------------------
-- The targets cross-reference verdict
-- ---------------------------------------------------------------------------

test("Diagnostics: a walk that never reached a spell does not blame the build", function()
    -- THE BUG THIS EXISTS FOR, and it is a diagnostic telling a lie rather than
    -- a display drawing one. In a pull an enemy's GUID and its creature ID are
    -- both secret, so `GetSourceDetail` is never called, so no spell is ever
    -- seen — and the verdict read that silence as "this build does not carry the
    -- caster". The same client answered with the caster name immediately once
    -- combat ended. A report that confidently names the wrong cause sends the
    -- fix to the wrong place, which is the one thing this file must not do.
    -- red under: `if withDetails == 0 then` as the only branch.
    local inst = T.load{ enable = true }
    local mocks = inst.mocks

    -- One enemy in the column, reachable by neither identifier — which is every
    -- enemy for the whole of a pull.
    mocks.setSession(1, mocks.Enum.DamageMeterType.EnemyDamageTaken, {
        combatSources = { {
            sourceGUID       = mocks.secret("Creature-0-0000-0-0-0001"),
            guid             = mocks.secret("Creature-0-0000-0-0-0001"),
            sourceCreatureID = mocks.secret(6001),
            creatureID       = mocks.secret(6001),
            name             = mocks.secret("Cleave Training Dummy"),
            totalAmount      = 1,
            sourceDisplayType = mocks.Enum.DamageMeterSourceDisplayType.Enemy,
        } },
        maxAmount = 1, totalAmount = 1, durationSeconds = 60,
    })
    inst.NS.Database.GetWindows()[1].data.sessionType = 1
    mocks.setRestricted(true)

    local text = report(inst)
    assertTrue(text:find("enemy column: 1 sources", 1, true) ~= nil,
        "the fixture never reached the targets section")
    assertFalse(text:find("this build does not", 1, true) ~= nil,
        "the report blamed the client for a field the restriction merely hid")
    assertTrue(text:find("re%-run out of combat") ~= nil,
        "and it must say what to do instead of stopping at the accusation")
end)

test("Diagnostics: the number probes expect what the SHIPPING ladder renders", function()
    -- These wants were written against a three-significant-figure ladder that
    -- modules/Format.lua has since retired on purpose, and they outlived it — so
    -- a live report flagged three correct figures as wrong. A column of
    -- expectations nobody maintains is worse than no column, because it trains
    -- the reader to ignore the marks that matter.
    -- red under: want = "4.75K" / "475.0K" / "1.41M".
    local inst = T.load{ enable = true }
    local text = report(inst)

    local section = text:match("%-%- number formatting %-%-(.-)\n[^\n]*%-%- visibility")
    assertTrue(section ~= nil, "the number formatting section is missing")
    assertFalse(section:find("<%-%- expected") ~= nil,
        "the shipping ladder's own output is flagged as unexpected:\n" .. section)
end)


--- An enemy column holding one source with the given display type.
local function enemyColumn(inst, displayType)
    local mocks = inst.mocks
    mocks.setSession(1, mocks.Enum.DamageMeterType.EnemyDamageTaken, {
        combatSources = { {
            sourceGUID        = "Creature-0-0000-0-0-0001",
            guid              = "Creature-0-0000-0-0-0001",
            sourceCreatureID  = 6001,
            creatureID        = 6001,
            name              = "Cleave Training Dummy",
            totalAmount       = 1,
            sourceDisplayType = displayType,
        } },
        maxAmount = 1, totalAmount = 1, durationSeconds = 60,
    })
    inst.NS.Database.GetWindows()[1].data.sessionType = 1
end

test("Diagnostics: the enemy column's display types are printed, not assumed", function()
    -- THE BELT ON A LOOSENED GATE. modules/Aggregator.lua now admits a source
    -- flagged None when it carries a real player class, which is safe exactly as
    -- long as enemies keep reporting Enemy — an assumption about a live client,
    -- not a fact about the code. So the client is asked and the answer printed.
    -- red under: no display-type line in the targets section.
    local inst = T.load{ enable = true }
    enemyColumn(inst, inst.mocks.Enum.DamageMeterSourceDisplayType.Enemy)

    local text = report(inst)
    assertTrue(text:find("display types: 2 x1", 1, true) ~= nil,
        "the enemy column's display types are missing from the report")
end)

test("Diagnostics: an enemy flagged None is called out, because it defeats the class gate", function()
    -- The one reading that turns the aggregator's new branch from narrow into
    -- dangerous. If a mob is ever filed under None, the class filename is the
    -- only thing between a trash pack and the grid — and that is a sentence a
    -- player should read in a report rather than infer from a wrong row.
    -- red under: printing the tally without checking it.
    local inst = T.load{ enable = true }
    enemyColumn(inst, inst.mocks.Enum.DamageMeterSourceDisplayType.None)

    local text = report(inst)
    assertTrue(text:find("flagged None", 1, true) ~= nil,
        "a None-flagged enemy passed without comment")
end)

test("Diagnostics: a display-type check that could not run says so", function()
    -- `sourceDisplayType` is secret for the whole of a pull — measured on a live
    -- client, which printed `display types: <secret> x5` across a five-enemy
    -- column. With every entry unreadable the None check finds nothing and
    -- prints nothing, which reads exactly like "checked, all clear". A belt that
    -- silently did not run is worse than no belt.
    -- red under: printing the tally and falling through to the None check.
    local inst = T.load{ enable = true }
    enemyColumn(inst, inst.mocks.secret(2))
    inst.mocks.setRestricted(true)

    local text = report(inst)
    assertTrue(text:find("every display type is secret", 1, true) ~= nil,
        "a check that could not run passed itself off as a clean one")
end)

-- ---------------------------------------------------------------------------
-- The provider-order probe (issue #14)
-- ---------------------------------------------------------------------------
--
-- modules/Provider.lua rests on ONE unverified assumption: that `combatSources`
-- arrives already ranked by the stat that was asked for, descending. The whole
-- mid-pull grid is built on it — identity mode takes row identity from POSITION,
-- so if the order is wrong the grid is wrong, not merely the sort. Nothing in
-- Blizzard's documentation says it, and it has never been measured.
--
-- It is measurable HERE, out of combat, where the amounts are plain and `<` is
-- legal: walk each column in the order the API returned it and ask whether the
-- totals descend. The check cannot run mid-pull and says so rather than looking
-- calm, exactly like the display-type belt above it.

test("Diagnostics: the provider-order probe reports a RANKED column as ranked", function()
    local inst = T.load{ enable = true }
    -- The shipped default is Overall; the fixture seeds Current, and the probe
    -- reads whichever session the first window is pointed at.
    inst.NS.Database.GetWindows()[1].data.sessionType = 1
    inst.mocks.setSession(1, "*", {
        combatSources = {
            { sourceGUID = "Player-1-0000000A", name = "Alpha", totalAmount = 300 },
            { sourceGUID = "Player-1-0000000B", name = "Beta",  totalAmount = 200 },
            { sourceGUID = "Player-1-0000000C", name = "Gamma", totalAmount = 100 },
        },
        maxAmount = 300, totalAmount = 600,
    })

    local text = report(inst)
    assertTrue(text:find("provider order", 1, true) ~= nil, "the section must appear")
    assertTrue(text:find("ranked", 1, true) ~= nil,
        "a descending column is the assumption holding, and the probe must say so")
end)

test("Diagnostics: the probe NAMES the position where the order breaks", function()
    -- The decision this probe exists to print. An out-of-order column disproves
    -- the assumption outright, and the index is what turns "it is wrong" into
    -- something the fix can be written against.
    -- red under: reporting a bare yes/no with no index.
    local inst = T.load{ enable = true }
    -- The shipped default is Overall; the fixture seeds Current, and the probe
    -- reads whichever session the first window is pointed at.
    inst.NS.Database.GetWindows()[1].data.sessionType = 1
    inst.mocks.setSession(1, "*", {
        combatSources = {
            { sourceGUID = "Player-1-0000000A", name = "Alpha", totalAmount = 100 },
            { sourceGUID = "Player-1-0000000B", name = "Beta",  totalAmount = 900 },
        },
        maxAmount = 900, totalAmount = 1000,
    })

    local text = report(inst)
    assertTrue(text:find("NOT ranked", 1, true) ~= nil,
        "an ascending column disproves the assumption and must say so loudly")
    assertTrue(text:find("index 2", 1, true) ~= nil, "and name where it broke")
end)

test("Diagnostics: the probe REFUSES mid-pull rather than reporting a false all-clear", function()
    -- Comparing two secrets raises. A probe that quietly found no break while
    -- unable to compare anything would print exactly what a healthy column
    -- prints, which is the failure mode the display-type belt was written for.
    -- red under: dropping the CanCompare2 gate.
    local inst = T.load{ enable = true }
    -- The shipped default is Overall; the fixture seeds Current, and the probe
    -- reads whichever session the first window is pointed at.
    inst.NS.Database.GetWindows()[1].data.sessionType = 1
    inst.mocks.setSession(1, "*", {
        combatSources = {
            { sourceGUID = "Player-1-0000000A", name = "Alpha",
              totalAmount = inst.mocks.secret(100) },
            { sourceGUID = "Player-1-0000000B", name = "Beta",
              totalAmount = inst.mocks.secret(900) },
        },
        maxAmount = 900, totalAmount = 1000,
    })
    inst.mocks.setSecretsAccessible(false)

    local text = report(inst)
    assertTrue(text:find("cannot be checked", 1, true) ~= nil,
        "the probe has to admit it did not run")
    assertTrue(text:find("NOT ranked", 1, true) == nil,
        "and must not accuse the API on evidence it never gathered")
end)
