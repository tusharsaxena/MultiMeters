-- tests/test_diagnostics_identity.lua — core/Diagnostics_Identity.lua, the
-- `/mm debug identity` capture.
--
-- Peeled out of tests/test_diagnostics.lua alongside the module, because a probe
-- written for an issue is meant to be deleted with the issue and that only works
-- if its cases can go out with it. Issue #22's capture is a self-contained
-- question put to a live client, and this is the file that goes out with the
-- answer.
--
-- The property the parent suite protects protects this one too: the report must
-- run to completion on a hostile client, print rather than raise, and never be
-- the reason a player cannot describe what they are seeing.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertNil   = T.assertNil

-- ---------------------------------------------------------------------------
-- `/mm debug identity` — the issue #22 capture
-- ---------------------------------------------------------------------------
--
-- Three of the five measurements issue #22 needs can only be taken on a live
-- client in a real raid: what the client actually annotates NeverSecret, how many
-- rows share a class+spec at 30 players, and whether the engine's ordering is
-- stable enough to pair a duplicate pair by position. This report is how they
-- come back. Everything below tests that it RUNS and says what it found — the
-- findings themselves are the player's to paste.

--- Run the identity report and hand back everything it printed.
local function identityReport(inst)
    local D      = inst.NS.DebugLog
    local buffer = D and D.buffer
    local chatN  = #inst.mocks.__chat
    local bufN   = buffer and #buffer or 0

    inst.NS.Diagnostics.ReportIdentity()

    local lines = {}
    if buffer then
        for i = bufN + 1, #buffer do lines[#lines + 1] = buffer[i] end
    end
    for i = chatN + 1, #inst.mocks.__chat do lines[#lines + 1] = inst.mocks.__chat[i] end
    return table.concat(lines, "\n"), lines
end

--- A restricted instance mid-pull with two priests of one spec on the grid, and
--- one identity pass already built with the debug flag on.
local function pulled(inst)
    inst.NS.State.debug = true
    inst.mocks.setRestricted(true)
    inst.mocks.setSession(1, "*", {
        combatSources = {
            { sourceGUID = "Player-1-0000000A", name = "Alpha", classFilename = "WARRIOR",
              specIconID = 9, totalAmount = 100, amountPerSecond = 10 },
            { sourceGUID = "Player-1-0000000B", name = "Beta", classFilename = "PRIEST",
              specIconID = 5, totalAmount = 50, amountPerSecond = 5 },
            { sourceGUID = "Player-1-0000000C", name = "Gamma", classFilename = "PRIEST",
              specIconID = 5, totalAmount = 30, amountPerSecond = 3 },
        },
        maxAmount = 100, totalAmount = 180,
    })
    inst.NS.Aggregator.Build({
        id = 1, name = "Test",
        columns = { { stat = "DamageDone", width = 80 }, { stat = "HealingDone", width = 80 } },
        rows = {},
        data = { sessionType = 1, sortMode = "provider", sortColumn = "DamageDone" },
    })
    return inst
end

test("Diagnostics: the identity report is published and reachable", function()
    local inst = T.load{ enable = true }
    assertEqual(type(inst.NS.Diagnostics.ReportIdentity), "function")
end)

test("Diagnostics: `/mm debug identity` reaches it without the debug log", function()
    -- Same reason `diag` does: it is what a player is asked to run, and a
    -- console they must open first is a step between us and the answer.
    -- red under: the verb falling through to the DebugLog branch.
    local inst = T.load{ enable = true }
    inst.NS.DebugLog = nil

    local n = #inst.mocks.__chat
    inst.NS.Slash:OnSlash("debug identity")
    assertTrue(#inst.mocks.__chat > n, "the report printed nothing")
end)

test("Diagnostics: the identity report prints the last pass's rectangle", function()
    local inst = pulled(T.load{ enable = true })
    local text = identityReport(inst)

    assertTrue(text:find("rows=3", 1, true) ~= nil, "the row count is missing")
    assertTrue(text:find("collidedRows=2", 1, true) ~= nil,
        "the measurement the issue asked for is missing")
    assertTrue(text:find("HealingDone", 1, true) ~= nil, "the per-column split is missing")
end)

test("Diagnostics: the identity report prints the rows-per-key histogram", function()
    -- The measurement that bounds what widening the key could buy.
    local inst = pulled(T.load{ enable = true })
    local text = identityReport(inst)
    assertTrue(text:find("rows per key", 1, true) ~= nil, "the histogram is missing")
    assertTrue(text:find("2 rows", 1, true) ~= nil, "the shared key is not named as shared")
end)

test("Diagnostics: the identity report prints the seats of every collided key", function()
    -- The ordering probe. Two captures of one pull, compared, say whether the
    -- engine's order is stable enough to pair a duplicate pair by position.
    local inst = pulled(T.load{ enable = true })
    local text = identityReport(inst)
    assertTrue(text:find("PRIEST_5_false", 1, true) ~= nil, "the collided key is not named")
    assertTrue(text:find("seats", 1, true) ~= nil, "the seat listing is missing")
end)

test("Diagnostics: the identity report audits what the CLIENT annotates secret", function()
    -- THE MEASUREMENT THAT DECIDES WHETHER THE KEY CAN BE WIDENED AT ALL. The
    -- three fields the key is built from may simply be every plain field there
    -- is, and nothing in the addon can answer that from here — it is a property
    -- of the running client, asked of a real source row.
    -- red under: reporting the addon's own opinion of what is plain.
    local inst = pulled(T.load{ enable = true })
    local text = identityReport(inst)

    assertTrue(text:find("source fields", 1, true) ~= nil, "the field audit is missing")
    assertTrue(text:find("classFilename%s+%S+%s+plain") ~= nil,
        "a field the key already uses must read plain")
    assertTrue(text:find("totalAmount%s+%S+%s+SECRET") ~= nil,
        "a meter value must read secret")
end)

test("Diagnostics: an un-audited field is named as a CANDIDATE for the key", function()
    -- A plain field the key does not already use is the entire content of the
    -- "widen the key" direction, and a reader should not have to diff two lists
    -- by eye to find one.
    --
    -- `specID` HERE IS A FIXTURE, NOT A CLAIM. Whether the client puts any such
    -- field on a source row is precisely the question the report is being sent
    -- in-game to answer, and inventing the answer offline would be the mistake
    -- core/Diagnostics.lua exists to stop. What is asserted is that a plain
    -- field the key does not use gets NAMED when there is one.
    local inst = T.load{ enable = true }
    inst.NS.State.debug = true
    inst.mocks.setRestricted(true)
    -- TWO rows carrying DIFFERENT values, because one row can no longer make a
    -- candidate: a field is only a candidate if it actually varies, and a single
    -- sample cannot show variation. That is the point of the change.
    inst.mocks.setSession(1, "*", {
        combatSources = {
            { sourceGUID = "Player-1-0000000A", name = "Alpha", classFilename = "WARRIOR",
              specIconID = 9, specID = 71, totalAmount = 100 },
            { sourceGUID = "Player-1-0000000B", name = "Beta", classFilename = "WARRIOR",
              specIconID = 9, specID = 72, totalAmount = 50 },
        },
        maxAmount = 100, totalAmount = 150,
    })
    inst.NS.Aggregator.Build({
        id = 1, name = "Test", columns = { { stat = "DamageDone", width = 80 } }, rows = {},
        data = { sessionType = 1, sortMode = "provider", sortColumn = "DamageDone" },
    })

    local text = identityReport(inst)
    assertTrue(text:find("specID%s+%S+%s+plain%s+.-WOULD widen the key") ~= nil,
        "a plain, varying field outside the key was not named as a candidate")
    assertTrue(text:find("2 values across 2 rows", 1, true) ~= nil,
        "and the variation that makes it a candidate is not quantified")
    assertTrue(text:find("actually VARY", 1, true) ~= nil,
        "the count that tells a reader to act on it is missing")
end)

test("Diagnostics: with NO field outside the key, the audit closes the direction", function()
    -- The other verdict, and the more likely one. "There is nothing else plain
    -- on the row" retires issue #22's first direction permanently, and it has to
    -- be said in as many words rather than left as an empty list.
    local inst = pulled(T.load{ enable = true })
    local text = identityReport(inst)
    assertTrue(text:find("No usable candidates", 1, true) ~= nil,
        "an audit that found nothing said nothing")
    assertTrue(text:find("cannot be widened", 1, true) ~= nil,
        "and did not say what that means for the fix")
end)

test("Diagnostics: with no identity pass measured, the report says so honestly", function()
    -- nil stats mean "not measured" — the flag was off, or the grid was built by
    -- the GUID join. Printing an empty rectangle would read as "measured, and
    -- clean", which is the one thing it does not mean.
    -- red under: printing zeroes for a pass that never ran.
    local inst = T.load{ enable = true }
    local text = identityReport(inst)
    assertTrue(text:find("no identity pass", 1, true) ~= nil,
        "the report invented a rectangle for a pass that never ran")
    assertTrue(text:find("debug on", 1, true) ~= nil,
        "and did not say how to get one")
end)

test("Diagnostics: the identity report survives a provider that answers nothing", function()
    -- It runs on a client that is already misbehaving, which is the only kind it
    -- is ever typed on.
    local inst = T.load{ enable = true }
    inst.NS.Provider = nil
    local ok = pcall(function() inst.NS.Diagnostics.ReportIdentity() end)
    assertTrue(ok, "the report raised instead of reporting")
end)

test("Diagnostics: an ABSENT field the addon reads is called out, loudly", function()
    -- The finding the first live capture nearly buried. A field the projection
    -- reads and the client does not ship is not a curiosity — `specIconID` being
    -- absent is what collapses the identity key to class alone, and it has to
    -- read as the headline rather than as one row of a ten-row table.
    -- red under: printing an absent field the same way as a secret one.
    local inst = T.load{ enable = true }
    inst.NS.State.debug = true
    inst.mocks.setRestricted(true)
    inst.mocks.setSession(1, "*", {
        combatSources = {
            { sourceGUID = "Player-1-0000000A", classFilename = "WARRIOR", totalAmount = 100 },
        },
        maxAmount = 100, totalAmount = 100,
    })
    inst.NS.Aggregator.Build({
        id = 1, name = "Test", columns = { { stat = "DamageDone", width = 80 } }, rows = {},
        data = { sessionType = 1, sortMode = "provider", sortColumn = "DamageDone" },
    })

    local text = identityReport(inst)
    assertTrue(text:find("specIconID%s+%S+%s+ABSENT") ~= nil,
        "an absent field was not marked absent")
    assertTrue(text:find("the addon READS this", 1, true) ~= nil,
        "nothing told the reader that an absent field is a defect, not a curiosity")
    assertTrue(text:find("field(s) absent", 1, true) ~= nil,
        "and the tally that puts the defects above the noise is missing")
    assertTrue(text:find("collapses the key to class alone", 1, true) ~= nil
            or text:find("collapses to class alone", 1, true) ~= nil,
        "and nothing said what specIconID's absence in particular costs")
end)

test("Diagnostics: a rectangle from a pull that has ENDED is marked stale", function()
    -- Read after combat, the rectangle describes a pass that no longer reflects
    -- what the grid is doing — the GUID join has taken over and every field on
    -- the row has gone plain again. Printing it beside `restriction: false`
    -- without a word invites the two halves to be read as one moment.
    -- red under: printing the rectangle identically in both states.
    local inst = T.load{ enable = true }
    inst.NS.State.debug = true
    inst.mocks.setRestricted(true)
    inst.mocks.setSession(1, "*", {
        combatSources = {
            { sourceGUID = "Player-1-0000000A", classFilename = "WARRIOR", totalAmount = 100 },
        },
        maxAmount = 100, totalAmount = 100,
    })
    inst.NS.Aggregator.Build({
        id = 1, name = "Test", columns = { { stat = "DamageDone", width = 80 } }, rows = {},
        data = { sessionType = 1, sortMode = "provider", sortColumn = "DamageDone" },
    })
    -- The pull ends. The stats stay; they are the last identity pass there was.
    inst.mocks.setRestricted(false)

    local text = identityReport(inst)
    assertTrue(text:find("the pull has ENDED", 1, true) ~= nil,
        "a post-combat capture read as though it were mid-pull")
end)

--- A restricted instance whose sources carry `extra` on the given rows.
local function pulledWith(inst, sources)
    inst.NS.State.debug = true
    inst.mocks.setRestricted(true)
    inst.mocks.setSession(1, "*", { combatSources = sources, maxAmount = 100, totalAmount = 300 })
    inst.NS.Aggregator.Build({
        id = 1, name = "Test", columns = { { stat = "DamageDone", width = 80 } }, rows = {},
        data = { sessionType = 1, sortMode = "provider", sortColumn = "DamageDone" },
    })
    return inst
end

test("Diagnostics: a field on SOME rows reads PARTIAL, and names the local row", function()
    -- THE #24 SHAPE. "Absent" and "plain" are both wrong about a field the client
    -- sends for one row out of nineteen, and the report having no word for it is
    -- why the pattern had to be inferred from a histogram the first time.
    -- red under: printing the two-state plain/SECRET/ABSENT verdict alone.
    local inst = pulledWith(T.load{ enable = true }, {
        { sourceGUID = "P1", classFilename = "MAGE",   totalAmount = 100 },
        { sourceGUID = "P2", classFilename = "PRIEST", totalAmount = 50,
          isLocalPlayer = true, specIconID = 135771 },
    })
    local text = identityReport(inst)

    assertTrue(text:find("specIconID%s+%S+%s+PARTIAL") ~= nil,
        "a field carried by one row of two did not read PARTIAL")
    assertTrue(text:find("1/2", 1, true) ~= nil, "the report did not say on how many rows")
    assertTrue(text:find("including yours", 1, true) ~= nil,
        "nothing said the local player's row is the one that has it")
end)

test("Diagnostics: a candidate with ONE value across the raid is called useless", function()
    -- SETTLES `classification` IN ONE CAPTURE. A field carrying one value for
    -- every player is no more a join key than no field at all, and printing it as
    -- a bare `<- candidate` sends the next change chasing it.
    -- red under: flagging every plain non-key field as a candidate.
    local inst = pulledWith(T.load{ enable = true }, {
        { sourceGUID = "P1", classFilename = "MAGE",   classification = "normal", totalAmount = 100 },
        { sourceGUID = "P2", classFilename = "PRIEST", classification = "normal", totalAmount = 50 },
        { sourceGUID = "P3", classFilename = "ROGUE",  classification = "normal", totalAmount = 20 },
    })
    local text = identityReport(inst)

    assertTrue(text:find("no use as a key", 1, true) ~= nil,
        "a field with one value across three players still read as a candidate")
end)

test("Diagnostics: a candidate that DOES vary is called out as worth trying", function()
    -- The other verdict, and the one that would actually move issue #22.
    local inst = pulledWith(T.load{ enable = true }, {
        { sourceGUID = "P1", classFilename = "MAGE",   classification = "alpha", totalAmount = 100 },
        { sourceGUID = "P2", classFilename = "MAGE",   classification = "beta",  totalAmount = 50 },
        { sourceGUID = "P3", classFilename = "MAGE",   classification = "gamma", totalAmount = 20 },
    })
    local text = identityReport(inst)

    assertTrue(text:find("WOULD widen the key", 1, true) ~= nil,
        "a field with a value per player was not called out")
end)

test("Diagnostics: the audit says how many rows it sampled", function()
    -- Every count on the block is out of it, and a reader comparing two captures
    -- of different group sizes needs the denominator stated.
    local inst = pulledWith(T.load{ enable = true }, {
        { sourceGUID = "P1", classFilename = "MAGE", totalAmount = 100 },
    })
    assertTrue(identityReport(inst):find("row sampled", 1, true) ~= nil,
        "the sample size is not on the report")
end)

test("Diagnostics: a missing isLocalPlayer is NOT called a degraded key", function()
    -- NOT EVERY MISSING KEY FIELD COSTS THE SAME. `specIconID` folds to 0 and
    -- collapses the key to class alone. `isLocalPlayer` folds to false, which is
    -- the correct answer for every row but one — so calling its absence a
    -- degradation sends a reader after a non-problem, in red, next to a line that
    -- is a real one.
    -- red under: treating every field in the key alike when it goes missing.
    local inst = pulledWith(T.load{ enable = true }, {
        { sourceGUID = "P1", classFilename = "MAGE",   totalAmount = 100 },
        { sourceGUID = "P2", classFilename = "PRIEST", totalAmount = 50,
          isLocalPlayer = true, specIconID = 135771 },
    })
    local text = identityReport(inst)

    local localLine  = text:match("(isLocalPlayer[^\n]*)")
    local specLine   = text:match("(specIconID[^\n]*)")
    assertTrue(localLine ~= nil and specLine ~= nil, "both fields must be on the report")
    assertNil(localLine:find("collapses", 1, true),
        "a missing isLocalPlayer folds to false, which is right, and was called a defect")
    assertTrue(specLine:find("collapses", 1, true) ~= nil,
        "a missing specIconID DOES collapse the key, and the report must say so")
end)
