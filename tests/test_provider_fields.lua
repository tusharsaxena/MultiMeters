-- tests/test_provider_fields.lua — modules/Provider.lua's raw source-row field
-- probe, both passes (issues #22 and #24).
--
-- Peeled out of tests/test_provider.lua along its section seams, byte for byte;
-- that file keeps the R1a/R1b claims (one caller, no value inspected) and every
-- other provider read. The file-top locals are restated here rather than shared,
-- because a helper handed across suites through a global is a coupling no case
-- would catch.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertNil   = T.assertNil

local CURRENT = 1   -- Enum.DamageMeterSessionType.Current, as the mock reports it

-- ---------------------------------------------------------------------------
-- The raw source-row field probe — issue #22
-- ---------------------------------------------------------------------------
--
-- WHY IT CANNOT BE DONE ANYWHERE ELSE, and why reading GetColumn would have been
-- worthless. `collectSource` above projects a source onto a FIXED list of
-- thirteen fields. A probe asking "what plain fields does the client put on a
-- source row" that read a projected source would be asking what fields THIS FILE
-- copies — it would confirm our own opinion back to us and report "no candidate"
-- on a client that had one, which is the exact failure core/Diagnostics.lua
-- exists to prevent.
--
-- So the probe reads the RAW row, which means it lives here: this is the only
-- file that may reach the meter at all. What it hands back is a DESCRIPTION and
-- never a value — a name, a type where the type is knowable, and whether this
-- context may put the thing in a string.

test("Provider describes the RAW source row, not the projection it keeps", function()
    -- red under: probing GetColumn's sources, which can only ever report the
    -- thirteen fields collectSource copies.
    local inst = T.load()
    inst.mocks.setSession(CURRENT, "*", {
        combatSources = {
            { sourceGUID = "Player-1-0000000A", classFilename = "WARRIOR",
              specIconID = 9, totalAmount = 100, someFieldWeDoNotCopy = 71 },
        },
        maxAmount = 100, totalAmount = 100,
    })

    local fields = inst.NS.Provider.ProbeSourceFields(CURRENT, "DamageDone")
    local byName = {}
    for _, f in ipairs(fields) do byName[f.name] = f end

    assertTrue(byName.someFieldWeDoNotCopy ~= nil,
        "the probe reported the projection, so it can never find a new field")
    assertEqual(byName.someFieldWeDoNotCopy.plain, true)
    assertEqual(byName.classFilename.plain, true)
end)

test("The probe DESCRIBES a secret field and never carries its value", function()
    -- Rule R1. A descriptor that carried the value would put a secret into a
    -- table core/Diagnostics.lua then formats, and the whole line would come back
    -- `<secret>` — which is how the three most useful lines of the main report
    -- once came back carrying nothing.
    local inst = T.load()
    inst.mocks.setSession(CURRENT, "*", {
        combatSources = { { sourceGUID = "Player-1-0000000A", classFilename = "MAGE",
                            totalAmount = 100 } },
        maxAmount = 100, totalAmount = 100,
    })
    inst.mocks.setRestricted(true)

    local fields = inst.NS.Provider.ProbeSourceFields(CURRENT, "DamageDone")
    local byName = {}
    for _, f in ipairs(fields) do byName[f.name] = f end

    assertEqual(byName.totalAmount.plain, false, "a meter value is secret mid-pull")
    assertNil(byName.totalAmount.value, "the descriptor carried the secret itself")
    assertEqual(byName.classFilename.plain, true,
        "and the fields the identity key rests on are still plain")
end)

test("The probe answers an empty list rather than raising on no session", function()
    -- It is typed on a client that is already misbehaving.
    local inst = T.load()
    inst.mocks.setMeterAvailable(false)
    assertEqual(#inst.NS.Provider.ProbeSourceFields(CURRENT, "DamageDone"), 0)
end)

test("The probe is callable in both the dot and the colon shape", function()
    local inst = T.load()
    inst.mocks.setSession(CURRENT, "*", {
        combatSources = { { sourceGUID = "Player-1-0000000A", classFilename = "MAGE" } },
    })
    assertEqual(#inst.NS.Provider:ProbeSourceFields(CURRENT, "DamageDone"),
                #inst.NS.Provider.ProbeSourceFields(CURRENT, "DamageDone"))
end)

test("The probe reports a field the addon READS and the client does not have", function()
    -- FOUND IN A LIVE RAID, and it is the failure a probe that lists only what
    -- is present cannot ever surface. `specIconID` is absent from every source
    -- row on a 12.0 client — not secret, ABSENT — so the identity key degrades
    -- from class+spec+isMe to class+isMe, and eighteen of nineteen rows collide.
    -- The first capture listed ten plain fields and looked healthy; the fact
    -- that mattered was the eleventh, which was not on it.
    -- red under: building the report out of `pairs` on the row alone.
    local inst = T.load()
    inst.mocks.setSession(CURRENT, "*", {
        combatSources = { { sourceGUID = "Player-1-0000000A", classFilename = "MAGE",
                            totalAmount = 100 } },
        maxAmount = 100, totalAmount = 100,
    })

    local byName = {}
    for _, f in ipairs(inst.NS.Provider.ProbeSourceFields(CURRENT, "DamageDone")) do
        byName[f.name] = f
    end

    assertTrue(byName.specIconID ~= nil, "a field the projection reads was not reported at all")
    assertEqual(byName.specIconID.absent, true)
    assertEqual(byName.specIconID.plain, false, "an absent field is not a plain one")
    assertNil(byName.classFilename.absent, "a field that IS there is not marked absent")
end)

test("The projection's field list and collectSource cannot drift apart", function()
    -- The absent-field report is only as truthful as the list it checks
    -- against, and a list restated beside the projection is a list that goes
    -- stale the first time a field is added to one and not the other. Scanned
    -- out of the source, because a drift would fail no behavioral test — it
    -- would just quietly under-report.
    -- Rooted through T.root, like codeLines atop test_provider.lua. A bare
    -- relative path resolves against the runner's cwd, so this scan worked
    -- only for as long as the runner happened to be started from the repo
    -- root; from any other directory io.open returned nil and the case
    -- died on the assert, reporting a missing file as a drift.
    local relPath = "modules/Provider.lua"
    local fh = assert(io.open(T.root .. "/" .. relPath, "r"))
    -- Normalized, because this scan is about the source, not about how the
    -- line ends. The pattern below anchors on "\nend\n"; against a correctly
    -- checked-out CRLF working tree that never matches, the body comes back
    -- nil, and the case fails claiming a drift that is not there. The EOL
    -- gate is what has an opinion about line endings; this case does not.
    local text = fh:read("*a"):gsub("\r\n", "\n")
    fh:close()

    -- The WHOLE function, not the literal alone: `sourceCreatureID` is read into
    -- a local above the projection, and a scan of the literal by itself reported
    -- it as undeclared.
    local body = text:match("\nlocal function collectSource%(.-\n(.-)\nend\n")
    assertTrue(body ~= nil, "collectSource's body could not be found")

    local read = {}
    for field in body:gmatch("src%.([%w_]+)") do read[field] = true end

    local declared = {}
    for _, name in ipairs(_G.MULTIMETERS_TEST.load().NS.Provider.SOURCE_FIELDS) do
        declared[name] = true
    end

    for field in pairs(read) do
        assertTrue(declared[field], "collectSource reads " .. field
            .. ", and Provider.SOURCE_FIELDS does not declare it")
    end
    for field in pairs(declared) do
        assertTrue(read[field], "Provider.SOURCE_FIELDS declares " .. field
            .. ", and collectSource does not read it")
    end
end)

-- ---------------------------------------------------------------------------
-- The field probe, second pass — issues #22 and #24
-- ---------------------------------------------------------------------------
--
-- The first version read source row ONE and described it. Two things it could
-- therefore not say, both of which turned out to be the answer:
--
--   * `specIconID` is absent in a raid for every row EXCEPT the local player's.
--     A one-row probe reports "absent" or "present" and has no word for that,
--     and the pattern had to be inferred from the identity histogram instead.
--   * Whether a plain field would DISCRIMINATE. `classification` is plain and
--     not in the key, so it printed as a candidate — but a field carrying one
--     value for the whole raid is no more a join key than no field at all, and
--     one row cannot tell the two apart.
--
-- So it samples, and it counts. Distinct values are counted only over PLAIN
-- ones: a secret may not be compared or used as a table key (rule R1), and the
-- gate is per VALUE rather than per field because a field can be plain on one
-- row and secret on another.

test("The probe samples several rows, not just the first", function()
    -- red under: reading sources[1] and describing it.
    local inst = T.load()
    inst.mocks.setSession(CURRENT, "*", {
        combatSources = {
            { sourceGUID = "Player-1-0000000A", classFilename = "MAGE",   totalAmount = 3 },
            { sourceGUID = "Player-1-0000000B", classFilename = "PRIEST", totalAmount = 2 },
            { sourceGUID = "Player-1-0000000C", classFilename = "ROGUE",  totalAmount = 1 },
        },
        maxAmount = 3, totalAmount = 6,
    })

    local byName = {}
    for _, f in ipairs(inst.NS.Provider.ProbeSourceFields(CURRENT, "DamageDone")) do
        byName[f.name] = f
    end
    assertEqual(byName.classFilename.sampled, 3)
    assertEqual(byName.classFilename.present, 3)
end)

test("A field present on SOME rows only is reported as such, not as absent", function()
    -- THE #24 SHAPE, and the one a single-row probe has no word for. `specIconID`
    -- arrives for the local player and for nobody else in a raid; "absent" and
    -- "present" are both lies about that.
    -- red under: deriving absent from a single row's nil-ness.
    local inst = T.load()
    inst.mocks.setSession(CURRENT, "*", {
        combatSources = {
            { sourceGUID = "Player-1-0000000A", classFilename = "MAGE",   totalAmount = 3 },
            { sourceGUID = "Player-1-0000000B", classFilename = "PRIEST", totalAmount = 2,
              specIconID = 135771 },
        },
        maxAmount = 3, totalAmount = 5,
    })

    local byName = {}
    for _, f in ipairs(inst.NS.Provider.ProbeSourceFields(CURRENT, "DamageDone")) do
        byName[f.name] = f
    end
    assertEqual(byName.specIconID.present, 1, "one row carried it")
    assertEqual(byName.specIconID.sampled, 2, "out of two sampled")
    assertNil(byName.specIconID.absent, "present on one row is not absent")
end)

test("The LOCAL player's row is sampled even when it sits past the window", function()
    -- The row that carries the spec in a raid is the local player's, and in a
    -- 19-player group it is wherever their damage puts them. A probe that reads
    -- the top of the list would have missed the single row that disproves
    -- "absent for everyone".
    -- red under: sampling the first N rows and stopping.
    local inst = T.load()
    local sources = {}
    for i = 1, 14 do
        sources[i] = { sourceGUID = "Player-1-000000" .. i, classFilename = "MAGE",
                       totalAmount = 100 - i }
    end
    -- Past any sane sample window, and the only row with a spec.
    sources[15] = { sourceGUID = "Player-1-0000000P", classFilename = "PRIEST",
                    totalAmount = 1, isLocalPlayer = true, specIconID = 135771 }
    inst.mocks.setSession(CURRENT, "*",
        { combatSources = sources, maxAmount = 99, totalAmount = 500 })

    local byName = {}
    for _, f in ipairs(inst.NS.Provider.ProbeSourceFields(CURRENT, "DamageDone")) do
        byName[f.name] = f
    end
    assertEqual(byName.specIconID.present, 1,
        "the local player's row was never sampled, so the spec looked absent")
    assertEqual(byName.specIconID.local_, true, "and nothing said WHICH row carried it")
end)

test("Distinct PLAIN values are counted, so a constant field reads as one", function()
    -- THE MEASUREMENT THAT SETTLES A CANDIDATE. `classification` is plain and not
    -- in the key, so it prints as a candidate — and a field carrying one value
    -- for the whole raid is no more a join key than no field at all.
    -- red under: reporting that a field is plain and stopping there.
    local inst = T.load()
    inst.mocks.setSession(CURRENT, "*", {
        combatSources = {
            { sourceGUID = "P1", classFilename = "MAGE",   classification = "normal", totalAmount = 3 },
            { sourceGUID = "P2", classFilename = "PRIEST", classification = "normal", totalAmount = 2 },
            { sourceGUID = "P3", classFilename = "ROGUE",  classification = "normal", totalAmount = 1 },
        },
        maxAmount = 3, totalAmount = 6,
    })

    local byName = {}
    for _, f in ipairs(inst.NS.Provider.ProbeSourceFields(CURRENT, "DamageDone")) do
        byName[f.name] = f
    end
    assertEqual(byName.classification.distinct, 1, "one value across three players")
    assertEqual(byName.classFilename.distinct, 3, "and three where they really differ")
end)

test("A SECRET value is never compared or keyed on to count distinctness", function()
    -- Rule R1. Distinctness is a comparison, and the gate is per VALUE rather
    -- than per field because a field can be plain on one row and secret on the
    -- next. `distinct` is nil — not 0 — when nothing plain was seen: the two are
    -- different facts.
    local inst = T.load()
    inst.mocks.setSession(CURRENT, "*", {
        combatSources = {
            { sourceGUID = "P1", classFilename = "MAGE",   totalAmount = 3 },
            { sourceGUID = "P2", classFilename = "PRIEST", totalAmount = 2 },
        },
        maxAmount = 3, totalAmount = 5,
    })
    inst.mocks.setRestricted(true)

    local byName = {}
    for _, f in ipairs(inst.NS.Provider.ProbeSourceFields(CURRENT, "DamageDone")) do
        byName[f.name] = f
    end
    assertEqual(byName.totalAmount.secret, 2, "both rows' values were secret")
    assertNil(byName.totalAmount.distinct,
        "a secret field was counted, which means it was compared")
    assertEqual(byName.classFilename.distinct, 2, "and the plain field beside it still counts")
end)
