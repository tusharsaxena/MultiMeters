-- tests/test_aggregator_identity.lua — modules/Aggregator_Identity.lua: the grid
-- drawn while the GUID is secret.
--
-- Peeled out of tests/test_aggregator.lua behind the module it mirrors. The GUID
-- join, the group filter and pet folding stay there; ordering is in
-- tests/test_aggregator_sort.lua; the preview grid is in
-- tests/test_aggregator_preview.lua.
--
-- What is tested here is the SECOND build. Under the Combat restriction
-- `sourceGUID` is secret, so there is no key to join on, and the module
-- correlates rows by class plus spec plus "is it me" instead. Correlation can be
-- wrong in a way a join cannot, so nearly every case below is about a REFUSAL:
-- an ambiguous key fills no cell, a collision a later column proves blanks the
-- cells an earlier one already wrote, a sum nobody may compute goes quiet rather
-- than reading zero. The rest measure that refusal — the correlation rectangle
-- issue #22 asked for, which exists so a raid capture can be read against a
-- ceiling rather than against a hunch.
--
-- The fixtures are copies of tests/test_aggregator.lua's, small enough that a
-- duplicate is cheaper to read than a shared file to find.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual
local assertTrue  = T.assertTrue
local assertNil   = T.assertNil

local CURRENT = 1   -- Enum.DamageMeterSessionType.Current

local ALPHA = "Player-1-0000000A"
local BETA  = "Player-1-0000000B"
local GAMMA = "Player-1-0000000C"
local PET   = "Pet-0-00001111"

local GROUP = {
    { guid = ALPHA, name = "Alpha", class = "PALADIN", role = "TANK"    },
    { guid = BETA,  name = "Beta",  class = "PRIEST",  role = "HEALER"  },
    { guid = GAMMA, name = "Gamma", class = "ROGUE",   role = "DAMAGER" },
}

--- One combatSources row, in the shape modules/Provider.lua reads
--- (`sourceGUID`, not `guid` — see the harness contract).
local function src(guid, total, opts)
    opts = opts or {}
    return {
        sourceGUID       = guid,
        name             = opts.name or guid,
        classFilename    = opts.class or "MAGE",
        specIconID       = opts.specIconID,
        isLocalPlayer    = opts.localPlayer,
        totalAmount      = total,
        amountPerSecond  = opts.rate,
        deathTimeSeconds = opts.deathTime,
        deathRecapID     = opts.recapID,
        sourceDisplayType = opts.displayType,
    }
end

--- A window config shaped exactly like a stored one, but small enough that a
--- case names only what it is about.
local function makeWindow(opts)
    opts = opts or {}
    local columns = {}
    for _, key in ipairs(opts.columns or { "DamageDone" }) do
        columns[#columns + 1] = { stat = key, width = 80, showBar = true }
    end
    return {
        id      = opts.id or 1,
        name    = "Test",
        columns = columns,
        rows    = opts.rows or {},
        data    = {
            sessionType = CURRENT,
            -- `provider` unless a case is about ordering: it needs no comparison
            -- and so cannot quietly reorder what a join case is asserting.
            sortMode    = opts.sortMode or "provider",
            sortColumn  = opts.sortColumn,
        },
    }
end

--- Turn pet merging on for an instance.
---
--- ADDON-WIDE since schemaVersion 5, so it is written to the profile rather than
--- into the synthetic window config above: merging says what a pet's damage IS,
--- which is not a question two windows may answer differently. Off is the
--- shipped default — a pet gets its own row — because merging is addition, and
--- addition on two secret values raises.
local function mergePets(inst)
    local profile = inst.NS.db.profile
    profile.data = profile.data or {}
    profile.data.mergePets = true
end

--- A loaded instance with the standard three-player group.
local function loaded(opts)
    opts = opts or {}
    local inst = T.load()
    inst.mocks.setGroup(opts.group or GROUP)
    inst.NS.Roster.Refresh()
    return inst
end

--- Install one session spec under `statKey` (or every stat when omitted).
local function install(inst, sources, opts)
    opts = opts or {}
    local statType = opts.statKey
        and inst.NS.Constants.STAT_BY_KEY[opts.statKey].enumValue or "*"
    inst.mocks.setSession(CURRENT, statType, {
        combatSources   = sources,
        maxAmount       = opts.maxAmount,
        totalAmount     = opts.totalAmount,
        durationSeconds = opts.durationSeconds,
    })
end

--- A group whose player has a pet, for the two cases that ask what becomes of
--- it when the fold cannot run.
local function withPet()
    local inst = loaded()
    inst.mocks.setPet("player", PET)
    inst.NS.Roster.Refresh()
    return inst
end

-- ---------------------------------------------------------------------------
-- Identity mode — the grid while the GUID is secret
-- ---------------------------------------------------------------------------
--
-- Rows come from the union of every column, exactly as the GUID join takes
-- them, and a key no column can attribute fills nothing at all.

test("A healer with no damage is on the mid-pull grid, from the healing column", function()
    -- THE MISSING ROWS. The identity build took its row list from the SORT
    -- column alone, so a healer who did no damage and a player whose only
    -- contribution was one interrupt were absent for the whole of a pull and
    -- reappeared the instant it ended — rows flickering into existence rather
    -- than a rule. The GUID join has always taken the union of every column.
    -- red under: building rows from the sort column only.
    local inst = loaded()
    inst.mocks.setRestricted(true)
    install(inst, { src(ALPHA, 100, { class = "WARRIOR" }) },
        { statKey = "DamageDone", maxAmount = 100 })
    install(inst, { src(BETA, 500, { class = "PRIEST" }) },
        { statKey = "HealingDone", maxAmount = 500 })

    local result = inst.NS.Aggregator.Build(
        makeWindow{ columns = { "DamageDone", "HealingDone" }, sortColumn = "DamageDone" })

    assertEqual(#result, 2, "the healer is on the grid")
    -- Ranked first, unranked after: the damage row holds its place and the
    -- healer is parked past it rather than interleaved.
    assertEqual(inst.mocks.reveal(result[1].values.DamageDone.total), 100)
    assertEqual(inst.mocks.reveal(result[2].values.HealingDone.total), 500)
    assertNil(result[2].values.DamageDone, "and has no damage cell, because they did none")
end)

test("An ambiguous key gets no invented row, because no column could ever fill it", function()
    -- Two priests: the healing column cannot say which of them a figure belongs
    -- to, so it fills neither — and inventing a row for the pair would put an
    -- always-empty line on the grid.
    local inst = loaded()
    inst.mocks.setRestricted(true)
    install(inst, { src(ALPHA, 100, { class = "WARRIOR" }) },
        { statKey = "DamageDone", maxAmount = 100 })
    install(inst, { src(BETA, 500, { class = "PRIEST" }), src(GAMMA, 300, { class = "PRIEST" }) },
        { statKey = "HealingDone", maxAmount = 500 })

    local result = inst.NS.Aggregator.Build(
        makeWindow{ columns = { "DamageDone", "HealingDone" }, sortColumn = "DamageDone" })

    assertEqual(#result, 1, "only the row the sort column actually ranked")
    assertTrue(result.ambiguous, "and the header is told the grid is short an answer")
end)

test("A collision the LAST column reveals still blanks the FIRST column's cells", function()
    -- ORDER MUST NOT DECIDE HONESTY. `collisions` is one table filled as each
    -- column is read, so a key proved ambiguous by the third column was already
    -- written into cells by the second — and those cells stay, carrying one
    -- priest's number under a row that might be the other priest. That is the
    -- exact mislabel every other refusal in this file exists to prevent, reached
    -- by nothing but the order the window happens to list its columns in.
    --
    -- The sort column names neither priest, so its pre-pass cannot catch them.
    -- red under: detecting collisions column-by-column as the fill walks them.
    local inst = loaded()
    inst.mocks.setRestricted(true)
    install(inst, { src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }) },
        { statKey = "DamageDone", maxAmount = 100 })
    -- ONE priest here: this column cannot tell there is a second.
    install(inst, { src(BETA, 7, { class = "PRIEST", specIconID = 5 }) },
        { statKey = "Interrupts", maxAmount = 7 })
    -- ...and here they both are.
    install(inst, {
        src(BETA,  3, { class = "PRIEST", specIconID = 5 }),
        src(GAMMA, 2, { class = "PRIEST", specIconID = 5 }),
    }, { statKey = "Dispels", maxAmount = 3 })

    local result = inst.NS.Aggregator.Build(makeWindow{
        columns = { "DamageDone", "Interrupts", "Dispels" }, sortColumn = "DamageDone" })

    assertTrue(result.ambiguous, "the fixture is only meaningful if the key collided")
    for _, row in ipairs(result) do
        if row.identityKey == "PRIEST_5_false" then
            assertNil(row.values.Interrupts,
                "an early column's cell survived a collision a later column proved")
        end
    end
    assertEqual(#result, 1, "an always-empty row was invented for a collided key")
end)

test("A sort column the window does not LIST still builds mid-pull", function()
    -- `sortColumn` is kept whenever it names a real stat, and nothing requires
    -- it to be one of the window's own columns — a stored config can point at a
    -- stat whose column was later removed. The identity build reads its keys out
    -- of a per-column sweep, and the sweep walks the window's columns: a sort
    -- column outside that list has no swept keys, and indexing them raised.
    -- red under: sweeping pass.keys alone.
    local inst = loaded()
    inst.mocks.setRestricted(true)
    install(inst, { src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }) },
        { statKey = "DamageDone", maxAmount = 100 })
    install(inst, { src(ALPHA, 4, { class = "WARRIOR", specIconID = 9 }) },
        { statKey = "Interrupts", maxAmount = 4 })

    local result = inst.NS.Aggregator.Build(makeWindow{
        columns = { "DamageDone" }, sortColumn = "Interrupts" })
    assertEqual(#result, 1, "the grid came out empty for a sort column off the list")
end)

test("A correlated cell carries the RATE, or a rate column renders no text", function()
    -- THE EMPTY HEALING COLUMN. The shipped text layout is `leftSlot = "smart"`,
    -- which on a RATE stat — Damage, Healing — is `amountPerSecond` rather than
    -- the total. Correlation carried only the total, so mid-pull every rate
    -- column but the sort one drew its bar from the total and its text from a nil
    -- rate: a bar with no number beside it.
    --
    -- Avoidable and Interrupts hid the bug, because neither is a rate stat and
    -- smart renders their absolute figure instead. Only the rate columns were
    -- blank, which is exactly what was reported.
    -- red under: `row.values[statKey] = { total = value, maxAmount = ... }`.
    local inst = loaded()
    inst.mocks.setRestricted(true)
    install(inst, { src(ALPHA, 100, { rate = 10 }) },
        { statKey = "DamageDone", maxAmount = 100 })
    install(inst, { src(ALPHA, 500, { rate = 50 }) },
        { statKey = "HealingDone", maxAmount = 500 })

    local result = inst.NS.Aggregator.Build(
        makeWindow{ columns = { "DamageDone", "HealingDone" }, sortColumn = "DamageDone" })

    assertEqual(#result, 1)
    local healing = result[1].values.HealingDone
    assertEqual(inst.mocks.reveal(healing.total), 500)
    assertEqual(inst.mocks.reveal(healing.rate), 50,
        "a rate stat's text slot reads amountPerSecond — without it the cell is silent")
end)

test("A correlated Deaths column keeps the recap id the death view opens on", function()
    -- `deathRecapID` is NeverSecret and rides on the source row. The GUID join
    -- promotes it onto the row so neither the tooltip nor the drill-down has to
    -- know which column it arrived on; correlation dropped it, so mid-pull a
    -- death had no recap to open.
    local inst = loaded()
    inst.mocks.setRestricted(true)
    install(inst, { src(ALPHA, 100, { rate = 10 }) },
        { statKey = "DamageDone", maxAmount = 100 })
    install(inst, { src(ALPHA, 0, { recapID = 4242 }) },
        { statKey = "Deaths", maxAmount = 0 })

    local result = inst.NS.Aggregator.Build(
        makeWindow{ columns = { "DamageDone", "Deaths" }, sortColumn = "DamageDone" })

    assertEqual(result[1].values.Deaths.total, 1, "one source row, one death")
    assertEqual(result[1].deathRecapID, 4242)
end)

test("A pet is a ROW OF ITS OWN while restricted, not a dropped contribution", function()
    -- WHAT THE PET FOLD USED TO DO HERE, and why it stopped. Merging is
    -- addition; addition on two secrets raises; so mid-pull the fold refused and
    -- the pet's numbers were simply dropped, leaving the owner's total quietly
    -- low for the whole fight.
    --
    -- The fold cannot run mid-pull at all now — it needs the owner link, which
    -- needs a GUID, which is secret. So the pet arrives as what Blizzard's own
    -- list says it is: a source, on a row, with its own name and numbers. That is
    -- MORE information than the old behavior, not less, and nothing is summed.
    -- red under: attempting the fold in identity mode.
    local inst = withPet()
    inst.mocks.setRestricted(true)
    install(inst, {
        src(ALPHA, 100, { rate = 10, class = "WARLOCK" }),
        src(PET, 40, { rate = 4, name = "Ghoul", class = "PET" }),
    }, { maxAmount = 100, totalAmount = 140 })

    mergePets(inst)
    local result = inst.NS.Aggregator.Build(makeWindow{})
    assertEqual(#result, 2, "the pet's damage is shown rather than discarded")
    assertEqual(inst.mocks.reveal(result[1].values.DamageDone.total), 100,
        "and the owner's own number is untouched — nothing was added to it")
    assertEqual(inst.mocks.reveal(result[2].values.DamageDone.total), 40)
end)

test("A pet's own row survives the restriction, where a merged one would not", function()
    local inst = withPet()
    inst.mocks.setRestricted(true)
    install(inst, {
        src(ALPHA, inst.mocks.secret(100)),
        src(PET, inst.mocks.secret(40), { name = "Bheemyn" }),
    }, { maxAmount = inst.mocks.secret(100) })

    -- No sum is attempted, so there is nothing for the restriction to forbid.
    local result = inst.NS.Aggregator.Build(makeWindow())
    assertEqual(#result, 2, "mid-pull, both rows are present and both are exact")
end)

test("Aggregator answers nil percent while restricted — never zero", function()
    local inst = loaded()
    install(inst, { src(ALPHA, 75), src(BETA, 25) },
        { maxAmount = 75, totalAmount = 100 })
    inst.mocks.setRestricted(true)

    mergePets(inst)
    local result = inst.NS.Aggregator.Build(makeWindow{})
    -- A division on an inaccessible operand raises, so the slot goes quiet. nil
    -- means "cannot be known right now" and callers must not read it as 0%.
    assertNil(result[1].values.DamageDone.percent)
    assertNil(result[2].values.DamageDone.percent)
end)

-- ---------------------------------------------------------------------------
-- Deaths, which is COUNTED and so is legal mid-pull
-- ---------------------------------------------------------------------------
--
-- Counting is ours, not the meter's, so it survives the restriction where a
-- sum does not. The identity build tallies deaths through a parallel map:
-- that is a SECOND capture point, and a change made to one build and not the
-- other is invisible until somebody drills in during a pull.

test("Counting a death is legal mid-pull, where summing two secrets is not", function()
    -- The counter is ours, not the meter's, so incrementing it is not arithmetic
    -- on a secret. The simulator raises on the illegal form, so reaching the
    -- assertion is the proof.
    local inst = loaded()
    inst.mocks.setRestricted(true)
    inst.mocks.setSecretValues(true)
    install(inst, { src(ALPHA, 0, { recapID = 2 }), src(ALPHA, 0, { recapID = 1 }) },
        { statKey = "Deaths" })

    local ok, err = pcall(inst.NS.Aggregator.Build, makeWindow{ columns = { "Deaths" } })
    assertTrue(ok, "counting inspected a meter value: " .. tostring(err))
end)

test("A correlated Deaths column keeps every death too", function()
    -- Mid-pull there is no GUID, so the identity build tallies deaths through a
    -- parallel map instead. It is a SECOND capture point, and a change made to
    -- one build and not the other is invisible until somebody drills in during
    -- a pull.
    -- red under: accumulating the array only in setCell.
    local inst = loaded()
    install(inst, { src(ALPHA, 500, { class = "PALADIN", specIconID = 1 }) },
        { statKey = "DamageDone", maxAmount = 500 })
    install(inst, {
        src(ALPHA, 0, { class = "PALADIN", specIconID = 1, recapID = 29 }),
        src(ALPHA, 0, { class = "PALADIN", specIconID = 1, recapID = 27 }),
    }, { statKey = "Deaths", maxAmount = 0 })
    inst.mocks.setRestricted(true)

    local rows = inst.NS.Aggregator.Build(
        makeWindow{ columns = { "DamageDone", "Deaths" }, sortColumn = "DamageDone" })
    assertEqual(rows[1].values.Deaths.total, 2)
    assertEqual(#rows[1].deaths, 2, "the identity build dropped a death")
    assertEqual(rows[1].deaths[1], 29, "newest first here too")
end)

test("A collided identity key gets no deaths array, as it gets no cell", function()
    -- Two players of one class and spec cannot be told apart mid-pull, and this
    -- file's whole warrant for correlating is that it REFUSES rather than
    -- guesses. A death list attached outside that refusal would put one
    -- player's deaths under the other player's name.
    -- red under: assigning row.deaths outside the collision guard.
    local inst = loaded()
    install(inst, {
        src(ALPHA, 500, { class = "PALADIN", specIconID = 1 }),
        src(BETA,  400, { class = "PALADIN", specIconID = 1 }),
    }, { statKey = "DamageDone", maxAmount = 500 })
    install(inst, {
        src(ALPHA, 0, { class = "PALADIN", specIconID = 1, recapID = 29 }),
    }, { statKey = "Deaths", maxAmount = 0 })
    inst.mocks.setRestricted(true)

    local rows = inst.NS.Aggregator.Build(
        makeWindow{ columns = { "DamageDone", "Deaths" }, sortColumn = "DamageDone" })
    for _, row in ipairs(rows) do
        assertNil(row.values.Deaths, "the fixture is only meaningful if the key collided")
        assertNil(row.deaths, "a collided row was given somebody's death list")
    end
end)

test("The identity build keeps that slot too", function()
    -- Two builds, one shape. The GUID build being fixed and the identity build
    -- not would make the lists differ in and out of combat.
    local inst = loaded()
    install(inst, { src(ALPHA, 500, { class = "PALADIN", specIconID = 1 }) },
        { statKey = "DamageDone", maxAmount = 500 })
    install(inst, {
        src(ALPHA, 0, { class = "PALADIN", specIconID = 1, recapID = 29 }),
        src(ALPHA, 0, { class = "PALADIN", specIconID = 1 }),
    }, { statKey = "Deaths", maxAmount = 0 })
    inst.mocks.setRestricted(true)

    local rows = inst.NS.Aggregator.Build(
        makeWindow{ columns = { "DamageDone", "Deaths" }, sortColumn = "DamageDone" })
    assertEqual(rows[1].values.Deaths.total, 2)
    assertEqual(#rows[1].deaths, 2)
    assertEqual(rows[1].deaths[2], false)
end)

test("The feign filter cannot run mid-pull, and does not pretend to", function()
    -- STRUCTURAL, not a defect. It joins a plain GUID against sourceGUID, and
    -- sourceGUID is secret for the whole of a pull — which is the entire reason
    -- there is a second, GUID-free build. Pinned as behaviour so nobody "fixes"
    -- it by keying on something secret.
    local inst = loaded()
    install(inst, { src(ALPHA, 500, { class = "PALADIN", specIconID = 1 }) },
        { statKey = "DamageDone", maxAmount = 500 })
    install(inst, { src(ALPHA, 0, { class = "PALADIN", specIconID = 1, recapID = 29 }) },
        { statKey = "Deaths", maxAmount = 0 })
    inst.NS.Feign.Note(ALPHA)
    inst.mocks.setRestricted(true)

    local rows = inst.NS.Aggregator.Build(
        makeWindow{ columns = { "DamageDone", "Deaths" }, sortColumn = "DamageDone" })
    assertEqual(rows[1].values.Deaths.total, 1,
        "if this ever reads 0, the restricted build found a plain key and the "
        .. "limitation can be lifted from docs/ARCHITECTURE.md")
end)

-- ---------------------------------------------------------------------------
-- Identity correlation: the diagnostics (issue #22)
-- ---------------------------------------------------------------------------
--
-- The shipped `identity` debug line could not answer the question it was written
-- for. It reported how many KEYS collided, not how many ROWS those keys covered,
-- so the ceiling a raid capture should be read against could not be computed;
-- it summed each column's key count into one figure, so `keys` was neither a
-- cardinality nor comparable to `rows`; and `filled/possible` accumulated
-- against a row list that was still GROWING, so `possible` was not rows x
-- columns and the arithmetic done on a live capture was wrong.
--
-- What replaces it is a rectangle: every row against every CORRELATED column,
-- each cell landing in exactly one of four buckets, and every miss therefore
-- attributable. Built only while the debug flag is on, because it is 30 rows
-- times 6 columns four times a second and nothing on the render path reads it.

--- A restricted instance with `n` distinct-class damage rows plus whatever else
--- the case installs.
local function debugging(inst)
    inst.NS.State.debug = true
    return inst
end

test("Identity stats count collided ROWS, not just collided keys", function()
    -- THE MEASUREMENT THE ISSUE ASKED FOR. Six collided keys over eighteen rows
    -- says nothing about the ceiling until you know how many rows those six keys
    -- cover, and the shipped line reported only the six.
    -- red under: reporting the size of the collisions set alone.
    local inst = debugging(loaded())
    inst.mocks.setRestricted(true)
    install(inst, {
        src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }),
        src(BETA,   50, { class = "PRIEST",  specIconID = 5 }),
        src(GAMMA,  30, { class = "PRIEST",  specIconID = 5 }),
    }, { statKey = "DamageDone", maxAmount = 100 })
    install(inst, { src(ALPHA, 4, { class = "WARRIOR", specIconID = 9 }) },
        { statKey = "Interrupts", maxAmount = 4 })

    local result = inst.NS.Aggregator.Build(makeWindow{
        columns = { "DamageDone", "Interrupts" }, sortColumn = "DamageDone" })
    local stats = result.identityStats

    assertEqual(stats.collidedKeys, 1, "one class+spec pair is shared")
    assertEqual(stats.collidedRows, 2, "and TWO rows wear it — the ceiling turns on this")
    assertEqual(stats.rows, 3)
    assertEqual(stats.keys, 2, "DISTINCT keys, not a per-column count summed")
end)

test("Identity stats attribute every miss to one of three causes", function()
    -- `filled/possible` alone cannot separate the blank that is CORRECT (a
    -- healer did no damage) from the blank that is the fault the line exists to
    -- surface (the key is in the column and still did not match). One number
    -- covering both is why a live capture could not be acted on.
    -- red under: counting only filled and possible.
    local inst = debugging(loaded())
    inst.mocks.setRestricted(true)
    install(inst, {
        src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }),
        src(BETA,   50, { class = "PRIEST",  specIconID = 5 }),
        src(GAMMA,  30, { class = "ROGUE",   specIconID = 3 }),
    }, { statKey = "DamageDone", maxAmount = 100 })
    -- The priest heals; nobody else appears in the column at all.
    install(inst, { src(BETA, 500, { class = "PRIEST", specIconID = 5 }) },
        { statKey = "HealingDone", maxAmount = 500 })

    local result = inst.NS.Aggregator.Build(makeWindow{
        columns = { "DamageDone", "HealingDone" }, sortColumn = "DamageDone" })
    local col = result.identityStats.columns.HealingDone

    assertEqual(col.rows, 3, "the rectangle is every row, not the rows so far")
    assertEqual(col.filled, 1)
    assertEqual(col.absent, 2, "the warrior and the rogue did no healing, honestly")
    assertEqual(col.collided, 0)
    assertEqual(col.unmatched, 0,
        "a key present in the column that still produced no cell is the FAULT bucket")
end)

test("A collided key lands in the collided bucket, not the absent one", function()
    -- The two are opposite diagnoses: absent means the correlation worked and
    -- the player did nothing, collided means the correlation refused. Reporting
    -- either as the other sends the next change in the wrong direction.
    -- red under: classifying a miss by whether byKey holds the key alone.
    local inst = debugging(loaded())
    inst.mocks.setRestricted(true)
    install(inst, {
        src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }),
        src(BETA,   50, { class = "PRIEST",  specIconID = 5 }),
        src(GAMMA,  30, { class = "PRIEST",  specIconID = 5 }),
    }, { statKey = "DamageDone", maxAmount = 100 })
    install(inst, {
        src(BETA,  500, { class = "PRIEST", specIconID = 5 }),
        src(GAMMA, 400, { class = "PRIEST", specIconID = 5 }),
    }, { statKey = "HealingDone", maxAmount = 500 })

    local result = inst.NS.Aggregator.Build(makeWindow{
        columns = { "DamageDone", "HealingDone" }, sortColumn = "DamageDone" })
    local col = result.identityStats.columns.HealingDone

    assertEqual(col.collided, 2, "both priest rows were refused, and for that reason")
    assertEqual(col.filled, 0, "the only healing in the column belonged to the pair")
    assertEqual(col.absent, 1, "and the warrior is absent, which is a different fact")
end)

test("The standing identity line names collided KEYS and ROWS, and every miss by cause (#22)", function()
    -- The line is what a live capture is read from, and `collided=1/2` read as a
    -- fraction. Keys and rows are separate figures with their own names, and the
    -- blank cells are split into the two causes the line exists to tell apart:
    -- `collided` (the correlation refused) and `unmatched` (a key in the column
    -- that still found no row), beside `absent` (the player did none of it).
    -- red under: the shipped `identity rows=N keys=N collided=K/R filled=F/P`.
    local inst = debugging(loaded())
    inst.mocks.setRestricted(true)
    local lines = {}
    inst.NS.DebugSteady = function(_, tag, fmt, ...)
        if tag == "Aggregator" then lines[#lines + 1] = fmt:format(...) end
    end
    install(inst, {
        src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }),
        src(BETA,   50, { class = "PRIEST",  specIconID = 5 }),
        src(GAMMA,  30, { class = "PRIEST",  specIconID = 5 }),
    }, { statKey = "DamageDone", maxAmount = 100 })
    install(inst, {
        src(BETA,  500, { class = "PRIEST", specIconID = 5 }),
        src(GAMMA, 400, { class = "PRIEST", specIconID = 5 }),
    }, { statKey = "HealingDone", maxAmount = 500 })

    local stats = inst.NS.Aggregator.Build(makeWindow{
        columns = { "DamageDone", "HealingDone" }, sortColumn = "DamageDone" }).identityStats
    local line = ""
    for _, l in ipairs(lines) do
        if l:find("^identity ") then line = l end
    end
    assertTrue(line:find("collidedKeys=1 collidedRows=2", 1, true) ~= nil, "got: " .. line)
    assertTrue(line:find("filled=0/3 collided=2 unmatched=0 absent=1", 1, true) ~= nil,
        "got: " .. line)
    assertEqual(stats.filled + stats.collided + stats.unmatched + stats.absent, stats.possible,
        "every correlated cell lands in exactly one bucket")
end)

test("The sort column is named, and is not part of the correlated rectangle", function()
    -- Nothing is correlated onto the sort column: every row on the grid came
    -- FROM it. Counting it as filled would inflate the one ratio the capture is
    -- read for.
    local inst = debugging(loaded())
    inst.mocks.setRestricted(true)
    install(inst, { src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }) },
        { statKey = "DamageDone", maxAmount = 100 })
    install(inst, { src(ALPHA, 4, { class = "WARRIOR", specIconID = 9 }) },
        { statKey = "Interrupts", maxAmount = 4 })

    local stats = inst.NS.Aggregator.Build(makeWindow{
        columns = { "DamageDone", "Interrupts" }, sortColumn = "DamageDone" }).identityStats

    assertEqual(stats.sortColumn, "DamageDone")
    assertNil(stats.columns.DamageDone, "the sort column is not correlated onto anything")
    assertEqual(stats.possible, 1, "one row times one correlated column")
    assertEqual(stats.filled, 1)
end)

test("Identity stats carry the rows-per-key histogram", function()
    -- THE MEASUREMENT THAT BOUNDS THE FIX. Widening the key is worth doing in
    -- proportion to how many rows currently share one, and nothing in the
    -- shipped line said. `{ [1] = 1, [2] = 1 }` reads as "one key worn alone,
    -- one key worn by a pair".
    -- red under: reporting a collision count without the shape of it.
    local inst = debugging(loaded())
    inst.mocks.setRestricted(true)
    install(inst, {
        src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }),
        src(BETA,   50, { class = "PRIEST",  specIconID = 5 }),
        src(GAMMA,  30, { class = "PRIEST",  specIconID = 5 }),
    }, { statKey = "DamageDone", maxAmount = 100 })

    local stats = inst.NS.Aggregator.Build(makeWindow{
        columns = { "DamageDone" }, sortColumn = "DamageDone" }).identityStats

    assertEqual(stats.multiplicity[1], 1, "the warrior's key stands for one row")
    assertEqual(stats.multiplicity[2], 1, "the priests' key stands for two")
    assertNil(stats.multiplicity[3])
end)

test("A collided key records where its sources sat in every column", function()
    -- THE ORDERING PROBE. Pairing two same-spec players by their POSITION is the
    -- only direction left if the key cannot be widened, and it may only be taken
    -- if the engine's order is stable across columns. That is a question about a
    -- live client, so what ships is the capture, not the conclusion — and it is
    -- captured only for the keys where it would be used.
    -- red under: recording no positions at all.
    local inst = debugging(loaded())
    inst.mocks.setRestricted(true)
    install(inst, {
        src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }),
        src(BETA,   50, { class = "PRIEST",  specIconID = 5 }),
        src(GAMMA,  30, { class = "PRIEST",  specIconID = 5 }),
    }, { statKey = "DamageDone", maxAmount = 100 })
    install(inst, {
        src(GAMMA, 400, { class = "PRIEST", specIconID = 5 }),
        src(BETA,  500, { class = "PRIEST", specIconID = 5 }),
    }, { statKey = "HealingDone", maxAmount = 500 })

    local stats = inst.NS.Aggregator.Build(makeWindow{
        columns = { "DamageDone", "HealingDone" }, sortColumn = "DamageDone" }).identityStats
    local seats = stats.positions["PRIEST_5_false"]

    assertTrue(seats ~= nil, "the collided key recorded no seats")
    assertEqual(table.concat(seats.DamageDone, ","), "2,3")
    assertEqual(table.concat(seats.HealingDone, ","), "1,2")
    assertNil(stats.positions["WARRIOR_9_false"], "an unambiguous key needs no probe")
end)

test("The identity stats are not built at all with the debug flag off", function()
    -- It is a rectangle of rows times columns walked four times a second, and
    -- nothing on the render path reads it. A diagnostic that costs the player
    -- frames is a diagnostic that gets turned off and then is not there when it
    -- is wanted.
    -- red under: computing the stats unconditionally.
    local inst = loaded()
    inst.mocks.setRestricted(true)
    install(inst, { src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }) },
        { statKey = "DamageDone", maxAmount = 100 })

    assertNil(inst.NS.Aggregator.Build(makeWindow{ columns = { "DamageDone" } }).identityStats)
end)

test("The GUID build reports no identity stats, because it correlated nothing", function()
    -- Out of combat the join is exact. A rectangle of misses would read as a
    -- fault where there is none.
    local inst = debugging(loaded())
    install(inst, { src(ALPHA, 100) }, { statKey = "DamageDone", maxAmount = 100 })

    assertNil(inst.NS.Aggregator.Build(makeWindow{ columns = { "DamageDone" } }).identityStats)
end)

test("Aggregator keeps the last identity pass for the report to print", function()
    -- `/mm debug identity` is typed AFTER the pull it is about, and it has no
    -- window handle. The stats therefore outlive the pass that produced them.
    -- red under: publishing the stats on the result alone.
    local inst = debugging(loaded())
    inst.mocks.setRestricted(true)
    install(inst, {
        src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }),
        src(BETA,   50, { class = "PRIEST",  specIconID = 5 }),
        src(GAMMA,  30, { class = "PRIEST",  specIconID = 5 }),
    }, { statKey = "DamageDone", maxAmount = 100 })
    inst.NS.Aggregator.Build(makeWindow{ columns = { "DamageDone" } })

    local kept = inst.NS.Aggregator.LastIdentityStats()
    assertEqual(kept.collidedRows, 2)
    assertEqual(kept.rows, 3)
end)

-- ---------------------------------------------------------------------------
-- The ambiguous-row count the header shows — issue #22
-- ---------------------------------------------------------------------------
--
-- The correlation rectangle answers this too, but only while the debug flag is
-- on: it is a diagnostic and costs a walk of every row against every column. The
-- header needs the same number on every pass, for every player, with no flag --
-- so the count is taken off the final row list once and published on the result.

test("Identity: the pass publishes how many ROWS wear a collided key", function()
    -- ROWS, NOT KEYS. Two priests of one spec beside a lone warrior is one
    -- collided KEY and two blanked ROWS, and a header saying "1" would be
    -- describing the addon's bookkeeping rather than the grid in front of the
    -- player. red under: publishing the key count.
    local inst = loaded()
    inst.mocks.setRestricted(true)
    install(inst, {
        src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }),
        src(BETA,   50, { class = "PRIEST",  specIconID = 5 }),
        src(GAMMA,  25, { class = "PRIEST",  specIconID = 5 }),
    }, { maxAmount = 100 })

    local result = inst.NS.Aggregator.Build(
        makeWindow{ columns = { "DamageDone", "HealingDone" }, sortColumn = "DamageDone" })

    assertTrue(result.ambiguous, "the pair must be found ambiguous")
    assertEqual(#result, 3, "all three rows are on the grid")
    assertEqual(result.ambiguousRows, 2, "two ROWS wear the collided key, not one key")
end)

test("Identity: an unambiguous pass publishes a count of ZERO, never nil", function()
    -- nil reads as "not measured" everywhere else in this module, and the header
    -- would then have to tell that apart from "measured, and nothing collided".
    local inst = loaded()
    inst.mocks.setRestricted(true)
    install(inst, {
        src(ALPHA, 100, { class = "WARRIOR", specIconID = 9 }),
        src(BETA,   50, { class = "PRIEST",  specIconID = 5 }),
    }, { maxAmount = 100 })

    local result = inst.NS.Aggregator.Build(
        makeWindow{ columns = { "DamageDone" }, sortColumn = "DamageDone" })

    assertEqual(result.ambiguous, false)
    assertEqual(result.ambiguousRows, 0)
end)

test("A GUID pass publishes a count of zero too, because nothing was correlated", function()
    -- Out of combat the join is exact and the concept does not apply. The field
    -- still has to be a number: modules/Window_Header.lua reads it on every pass
    -- and only draws the notice at all in identity mode.
    local inst = loaded()
    install(inst, {
        src(ALPHA, 100, { class = "PRIEST", specIconID = 5 }),
        src(BETA,   50, { class = "PRIEST", specIconID = 5 }),
    }, { maxAmount = 100 })

    local result = inst.NS.Aggregator.Build(
        makeWindow{ columns = { "DamageDone" }, sortColumn = "DamageDone" })

    assertEqual(result.ambiguous, false, "a GUID pass is never ambiguous")
    assertEqual(result.ambiguousRows, 0)
end)
