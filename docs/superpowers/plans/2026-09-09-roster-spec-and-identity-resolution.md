# Roster spec + identity resolution — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give a meter row its real spec icon and name from the roster when the
client's own source row does not carry them, so issue #24's wrong icon is fixed
out of combat and improves mid-pull wherever the identity key still
discriminates.

**Architecture:** Three seams, each independently useful. `modules/Roster.lua`
learns a spec icon per member from the unit API (never from the meter, and never
by sending an inspect). `modules/Aggregator.lua`'s `newRow` prefers the source's
own `specIconID` and falls back to the roster's, which fixes every row out of
combat. `modules/Aggregator_Identity.lua` gains an identity-key -> GUID map,
recorded during out-of-combat GUID-mode passes and consulted mid-pull behind a
triple gate, so an unambiguous row recovers its real name, role and spec icon
while an ambiguous one keeps today's honest degradation.

**Tech Stack:** Lua 5.1 (WoW 12.0 Retail), Ace3, LibKa0s v1.29.0, luacheck,
the repo's headless harness (`lua tests/run.lua`).

**Spec:** GitHub issues
[#24](https://github.com/tusharsaxena/MultiMeters/issues/24) (the absent field)
and [#22](https://github.com/tusharsaxena/MultiMeters/issues/22) (what it does to
the key), plus the Background section below. Read both issues before Task 3.

## Background — what this is built on

`specIconID` is absent from a raid source row for every player but the local one
(#24). `identityKey` folds a missing icon to `0`, so in a raid the key collapses
from class+spec+isMe to class+isMe and two players of one class collide whatever
their specs are (#22). The blanking that follows is correct and does not change
here.

Scoot's Damage Meter Y (`core/components/damagemetersY/data.lua:347-400`) solves
the *name* half of this with a tier ladder: an out-of-combat `identityKey -> GUID`
map plus a `GUID -> name` roster map, consulted mid-pull and gated on the
collision set. It caches `specIcon` per GUID too (`core/inspect.lua:206-209`) and
never wires it to the row icon, so Scoot has #24 as well. This plan takes the
ladder and finishes it.

## Global Constraints

Copied verbatim from `CLAUDE.md` and the Ka0s WoW Addon Standard. Every task's
requirements implicitly include this section.

- **`modules/Provider.lua` is the only file that reaches `C_DamageMeter`**, and
  only through `core/Compat.lua`'s guarded meter shims. **No task in this plan
  adds a meter read.** Every new fact comes from the unit API or from data the
  aggregator already holds.
- **`core/Secrets.lua` is the only file that inspects a value.** Everywhere else
  a meter value is an opaque handle: never compare it, add it, key on it, or
  apply `#` to it. `== nil` is the one permitted test.
- **Layout is computed from config and never read back off a frame.**
- **No `NotifyInspect` is ever sent.** An addon that inspects on a timer competes
  with the player's own inspect for one shared client slot; owning that is a
  separate subsystem and is explicitly out of scope (see "Deliberately not in
  scope").
- Green gate before every commit: `lua tests/run.lua` and `luacheck .` must both
  be clean (0 failures / 0 warnings / 0 errors).
- **Never bump the version.** Not in the TOC, not in the README, not anywhere.
- Files are CRLF (`.gitattributes`). A test asserts it. If you write a file with
  a tool that normalises line endings, repair it with
  `rm <path> && git checkout -- <path>` before re-applying your edit, or convert
  back to CRLF explicitly.
- If a change would deviate from the standard, STOP and flag it rather than
  silently deviating or silently "fixing" to match.

## Deliberately not in scope

State these back if asked to add them; do not build them.

- **An inspect service.** `GetInspectSpecialization(unit)` is read for whatever
  the client already holds, and nothing more. Task 1's probe measures how often
  that is populated; if the answer is "rarely", a passive inspect service is a
  *separate plan*, modelled on `Scoot/core/inspect.lua`.
- **Any change to the blanking rule.** A collided key still blanks every
  secondary cell. This plan resolves display identity only, never a figure.
- **`row.guid` mid-pull.** Rows built by identity keep their `rank_N` /
  `ident:<key>` keys. The resolved GUID is display-only and must never reach the
  data join, the tooltip's source lookup, or the drill-down — those would open
  another player's breakdown on a stale map.

---

### Task 1: The roster carries a spec icon, and says how often it could

**Files:**
- Modify: `modules/Roster.lua` (add `unitSpecIcon` after `unitClassFile` at :161; extend the entry and `seenMap` literals in `build()` at :337-352; add `Roster.SpecIconOf` after `Roster.RoleOf` at :525)
- Modify: `tests/wow_mock.lua` (`setUnit` at :707, `setGroup` at :734, spec globals at :866)
- Modify: `core/Diagnostics_Identity.lua` (a new section in `reportIdentity`)
- Test: `tests/test_roster.lua`, `tests/test_diagnostics_identity.lua`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `Roster.SpecIconOf(guid) -> number|nil` — the member's spec icon file id, or nil.
  - `Roster.GetGroup()` entries gain `specIconID = number|nil`.
  - `Roster.ProbeSpecCoverage() -> { units = number, resolved = number, isRaid = boolean }`
  - mock: `mocks.setGroup{ { ..., specID = 250 } }` and `mocks.setUnit(token, { specID = 250 })`.

- [ ] **Step 1: Teach the mock the specialization APIs**

The mock has `GetSpecialization` / `GetSpecializationRole` for the local player's
role only (`tests/wow_mock.lua:866-867`). It has no `GetSpecializationInfo`, no
`GetInspectSpecialization` and no `GetSpecializationInfoByID`, so none of the
code below can be tested until it does.

In `tests/wow_mock.lua`, inside `setUnit` (:707), carry the spec through — add
`specID = spec.specID,` to the stored table, immediately after the `role` field.

In `setGroup` (:734), forward it — in the `setUnit{...}` call inside the
`for i, member in ipairs(spec)` loop, add `specID = member.specID,` after
`role = member.role,`. Do the same in the `if group.inRaid and i == 1 then`
duplicate `setUnit("raid1", {...})` call just below it, so the player's raid
token agrees with their `player` token.

Then, immediately after the existing `M.GetSpecializationRole` line (:867), add:

```lua
    -- Static specialization data. NONE of it is a meter value and none of it is
    -- ever secret: these are catalog reads about a class, not about a pull. The
    -- fixture answers a spec icon derived from the id so a test can assert the
    -- exact number without a table of real icon ids.
    --
    -- `GetSpecializationInfoByID` returns (id, name, description, icon, role,
    -- classFile) and `GetSpecializationInfo` returns the same shape for an INDEX
    -- into the local player's own specs. The icon is the FOURTH return in both,
    -- which is the only part modules/Roster.lua reads.
    local function specInfoFor(specID)
        if type(specID) ~= "number" or specID <= 0 then return nil end
        return specID, "Mock Spec " .. specID, "", 900000 + specID, "DAMAGER", "WARRIOR"
    end
    M.__specInfoFor = specInfoFor

    M.GetSpecializationInfoByID = function(specID) return specInfoFor(specID) end

    -- The local player's active spec, by INDEX. The fixture holds one spec, so
    -- index 1 is the player unit's own specID and anything else is nil.
    M.GetSpecializationInfo = function(index)
        if index ~= 1 then return nil end
        local u = unit("player")
        return specInfoFor(u and u.specID)
    end

    -- Whatever inspect data the client already holds for a unit. `nil` is the
    -- ordinary answer for a raid member nobody has inspected, and it is the case
    -- issue #24 is about — so the fixture defaults to it and a test has to ASK
    -- for a populated spec.
    M.GetInspectSpecialization = function(token)
        local u = unit(token)
        return u and u.specID or nil
    end
```

Finally, `M.GetSpecialization` currently answers `group.specRole and 1 or nil`
(:866), which ties the local player's spec INDEX to whether a role was set. That
is now load-bearing for the icon too, so widen it — replace that one line with:

```lua
    M.GetSpecialization = function()
        local u = unit("player")
        if u and u.specID then return 1 end
        return group.specRole and 1 or nil
    end
```

- [ ] **Step 2: Write the failing Roster tests**

Append to `tests/test_roster.lua`:

```lua
-- ---------------------------------------------------------------------------
-- Spec icons — issue #24
-- ---------------------------------------------------------------------------
--
-- The meter does not send `specIconID` for a raid source row (#24), so the row
-- icon falls back to the class and three druids read as one player. The unit API
-- still knows, for the local player always and for anybody else the client has
-- inspect data on, and none of it is a meter value.

local SPECCED = {
    { guid = "Player-1-0000000A", name = "Tankadin", class = "PALADIN",
      role = "TANK",    specID = 66  },
    { guid = "Player-1-0000000B", name = "Healbot",  class = "PRIEST",
      role = "HEALER",  specID = 257 },
    { guid = "Player-1-0000000C", name = "Stabby",   class = "ROGUE",
      role = "DAMAGER" },   -- no inspect data: the ordinary raid case
}

test("Roster: a member carries the spec icon the unit API knows", function()
    local inst = grouped(SPECCED)
    local group = inst.NS.Roster.GetGroup()

    -- 900000 + specID is the mock's derivation; see tests/wow_mock.lua.
    assertEqual(group[1].specIconID, 900066, "the local player's own spec")
    assertEqual(group[2].specIconID, 900257, "a member the client has data for")
    assertNil(group[3].specIconID, "a member nobody has inspected")
end)

test("Roster.SpecIconOf answers by GUID, and nil rather than a guess", function()
    local inst = grouped(SPECCED)
    local R = inst.NS.Roster

    assertEqual(R.SpecIconOf("Player-1-0000000A"), 900066)
    assertNil(R.SpecIconOf("Player-1-0000000C"), "no data is nil, never zero")
    assertNil(R.SpecIconOf("Player-1-0000000Z"), "a stranger")
    assertNil(R.SpecIconOf(nil), "and nil is not a key")
end)

test("Roster: the spec icon is REMEMBERED alongside the name", function()
    -- The remembered map outlives the group, because the meter's data does. An
    -- icon that vanished when the dungeon group broke up would take the row's
    -- identity with it exactly when the player is reading the summary.
    local inst = grouped(SPECCED)
    inst.NS.Roster.GetGroup()

    inst.mocks.setSolo("Player-1-0000000Z", "Alone", "MAGE")
    inst.NS.Roster.Refresh()

    assertEqual(inst.NS.Roster.SpecIconOf("Player-1-0000000A"), 900066,
        "the departed member's icon is still known")
end)

test("Roster: a client with no specialization API degrades to no icon", function()
    -- The whole module is written against a client that might not have the call.
    -- red under: an unguarded _G read.
    local inst = grouped(SPECCED)
    inst.mocks.GetSpecialization           = nil
    inst.mocks.GetSpecializationInfo       = nil
    inst.mocks.GetInspectSpecialization    = nil
    inst.mocks.GetSpecializationInfoByID   = nil
    inst.NS.Roster.Forget()
    inst.NS.Roster.Refresh()

    local group = inst.NS.Roster.GetGroup()
    assertEqual(#group, 3, "the roster still builds")
    assertNil(group[1].specIconID)
end)

test("Roster.ProbeSpecCoverage counts how many members resolved", function()
    -- ISSUE #24'S OPEN QUESTION, measured rather than assumed: whether the
    -- client answers GetInspectSpecialization for a group member nobody has
    -- explicitly inspected is a property of the running client, and the only
    -- honest way to find out is to count it in a real raid.
    local inst = grouped(SPECCED)
    local c = inst.NS.Roster.ProbeSpecCoverage()

    assertEqual(c.units, 3)
    assertEqual(c.resolved, 2)
    assertFalse(c.isRaid, "a party, not a raid")
end)
```

- [ ] **Step 3: Run them to verify they fail**

Run: `lua tests/run.lua`
Expected: the five new cases FAIL — `specIconID` is nil on every entry and
`Roster.SpecIconOf` / `Roster.ProbeSpecCoverage` do not exist.

- [ ] **Step 4: Read the spec off the unit API**

In `modules/Roster.lua`, immediately after `unitClassFile` (ends at :166), add:

```lua
--- The spec icon this unit is playing, or nil.
---
--- WHY THE ROSTER AND NOT THE METER. `specIconID` is absent from a raid source
--- row for every player but the local one (issue #24) — not secret, not
--- nil-under-restriction, simply not sent — so the row icon falls back to the
--- class and three druids read as one player. None of what this reads is a meter
--- value: a spec id and its icon are catalog facts about a class, always plain,
--- and legal to compare and key on at any point in a pull.
---
--- TWO SOURCES, for the same reason `unitRole` above has two. The local player's
--- ACTIVE spec is ours to read outright and needs nothing from anybody. For
--- every other unit there is only whatever inspect data the client already
--- holds, which may be nothing.
---
--- NO `NotifyInspect` IS SENT FROM HERE, and none ever should be. There is one
--- inspect slot per client and the player's own right-click must always win it;
--- an addon that polls for spec data is a service with a lifecycle, a queue and
--- a back-off, and that is not this file. An empty answer degrades to the class
--- icon, which is exactly what happens today.
---
--- The icon is the FOURTH return of both calls — (id, name, description, icon,
--- role, ...) — and it is the only part read.
local function unitSpecIcon(unit)
    if unit == "player" then
        local getSpec = _G.GetSpecialization
        local getInfo = _G.GetSpecializationInfo
        local index = getSpec and getSpec()
        if index == nil or not getInfo then return nil end
        local _, _, _, icon = getInfo(index)
        return (type(icon) == "number") and icon or nil
    end

    local getInspect = _G.GetInspectSpecialization
    local byID       = _G.GetSpecializationInfoByID
    local specID = getInspect and getInspect(unit)
    -- `> 0` because the API answers 0 for "no data", which is a number and would
    -- otherwise be looked up as though it were a spec.
    if type(specID) ~= "number" or specID <= 0 or not byID then return nil end
    local _, _, _, icon = byID(specID)
    return (type(icon) == "number") and icon or nil
end
```

- [ ] **Step 5: Carry it on the entry and on the remembered copy**

In `build()`, the entry literal (:337) currently reads:

```lua
                local entry = {
                    guid          = guid,
                    unit          = unit,
                    name          = unitName(unit),
                    classFilename = unitClassFile(unit),
                    role          = unitRole(unit),
                    isPlayer      = (unit == "player"),
                }
```

Add `specIconID` after `classFilename`:

```lua
                local entry = {
                    guid          = guid,
                    unit          = unit,
                    name          = unitName(unit),
                    classFilename = unitClassFile(unit),
                    specIconID    = unitSpecIcon(unit),
                    role          = unitRole(unit),
                    isPlayer      = (unit == "player"),
                }
```

And in the `seenMap.byGuid[guid]` literal just below it (:350), add the same
field after `classFilename`, so the remembered copy carries it too:

```lua
                    specIconID    = entry.specIconID,
```

- [ ] **Step 6: Publish the lookup and the coverage probe**

In `modules/Roster.lua`, immediately after `Roster.RoleOf` (ends at :528), add:

```lua
--- The spec icon for a GUID, or nil.
---
--- nil AND NEVER ZERO. A caller draws an icon or falls back to the class one, and
--- `0` is a number that would be handed to SetTexture as though it were a file
--- id. "Not known" has exactly one spelling here.
---
--- @param guid string
--- @return number|nil
function Roster.SpecIconOf(guid)
    local entry = Roster.Get(guid)
    return entry and entry.specIconID or nil
end

--- How many group members the client could name a spec for — issue #24.
---
--- A MEASUREMENT, NOT A FEATURE. Whether `GetInspectSpecialization` answers for a
--- member nobody has explicitly inspected is a property of the running client
--- that decides how much of #24 the roster can fix on its own, and it cannot be
--- answered from here — only asked, in a real raid. `/mm debug identity` prints
--- it; nothing on the render path reads it.
---
--- @return table  { units, resolved, isRaid }
function Roster.ProbeSpecCoverage()
    local group = ensure()
    local resolved = 0
    for i = 1, #group do
        if group[i].specIconID ~= nil then resolved = resolved + 1 end
    end
    return {
        units    = #group,
        resolved = resolved,
        isRaid   = (_G.IsInRaid and _G.IsInRaid()) and true or false,
    }
end
```

- [ ] **Step 7: Run the Roster tests to verify they pass**

Run: `lua tests/run.lua`
Expected: all five new cases PASS, and nothing else moved.

- [ ] **Step 8: Write the failing report test**

Append to `tests/test_diagnostics_identity.lua`, immediately before the
`test("Diagnostics: the identity report audits what the CLIENT annotates secret"` case:

```lua
test("Diagnostics: the report says how many members the client knows a spec for", function()
    -- ISSUE #24'S OTHER HALF. The field audit says the meter did not send a spec
    -- icon; this says whether the UNIT API could have. The two together decide
    -- whether the roster can fix #24 on its own or whether an inspect service is
    -- needed, and neither can be answered offline.
    local inst = pulled(T.load{ enable = true })
    inst.mocks.setGroup({
        { guid = "Player-1-0000000A", name = "Alpha", class = "WARRIOR", specID = 71 },
        { guid = "Player-1-0000000B", name = "Beta",  class = "PRIEST" },
    })
    inst.NS.Roster.Refresh()

    local text = identityReport(inst)
    assertTrue(text:find("spec coverage", 1, true) ~= nil, "the coverage line is missing")
    assertTrue(text:find("1 of 2", 1, true) ~= nil, "the ratio is missing")
end)
```

- [ ] **Step 9: Run it to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — "the coverage line is missing".

- [ ] **Step 10: Print the coverage line**

In `core/Diagnostics_Identity.lua`, add this function immediately above
`reportLookup`:

```lua
--- What the UNIT API knows about specs, beside what the METER sent — issue #24.
---
--- The field audit below reports that the meter did not send `specIconID`. This
--- reports whether anybody else could have. A high ratio here says the roster
--- fixes #24 on its own; a low one says the client holds inspect data for almost
--- nobody and a passive inspect service is the only route left.
local function reportSpecCoverage()
    local R = NS.Roster
    if not (R and R.ProbeSpecCoverage) then return end

    local ok, c = pcall(R.ProbeSpecCoverage)
    if not (ok and type(c) == "table") then return end

    out(string.format("  spec coverage: the unit API named a spec for %d of %d %s (raid: %s)",
        c.resolved, c.units, c.units == 1 and "member" or "members", tostring(c.isRaid)))
    if c.units > 0 and c.resolved < c.units then
        out("  The shortfall is members the client holds no inspect data for. No")
        out("  inspect is ever sent from the addon, so this is what is free.")
    end
end
```

Then call it from `reportIdentity`, on the line immediately before
`reportLookup(stats)`:

```lua
    reportSpecCoverage()
```

- [ ] **Step 11: Run the full gate**

Run: `lua tests/run.lua && luacheck .`
Expected: all tests PASS; luacheck reports `0 warnings / 0 errors`.

- [ ] **Step 12: Commit**

```bash
git add modules/Roster.lua tests/wow_mock.lua tests/test_roster.lua \
        core/Diagnostics_Identity.lua tests/test_diagnostics_identity.lua
git commit -m "$(cat <<'EOF'
Roster learns a spec icon, and the report says how often it could

The meter does not send specIconID for a raid source row (#24). The unit
API still knows, for the local player always and for anybody else the
client already holds inspect data on -- none of it a meter value, and no
NotifyInspect is ever sent. `/mm debug identity` now prints the coverage
ratio, which is what decides whether the roster fixes #24 on its own.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01CVx7o2xdz6H1jH2CZviDw8
EOF
)"
```

---

### Task 2: A row prefers the roster's spec icon over an absent one

**Files:**
- Modify: `modules/Aggregator.lua:171-189` (`newRow`)
- Test: `tests/test_aggregator.lua`

**Interfaces:**
- Consumes: `Roster.Get(guid)` entries now carrying `specIconID` (Task 1).
- Produces: aggregated rows whose `specIconID` is the source's where the client
  sent one and the roster's otherwise. `modules/Row_NameCell.lua`'s `drawUnitIcon`
  needs no change — its spec rung already fires on `entry.specIconID`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_aggregator.lua`:

```lua
test("Aggregator: a row with no spec on the source takes the roster's — #24", function()
    -- THE OUT-OF-COMBAT HALF OF ISSUE #24. In a raid the client sends
    -- `specIconID` on the local player's source row and on nobody else's, so
    -- every other row fell back to the class icon and three druids read as one
    -- player. Out of combat the GUID is plain, so the roster can answer.
    -- red under: newRow taking the icon from the source alone.
    local inst = T.load()
    inst.mocks.setGroup({
        { guid = "Player-1-0000000A", name = "Alpha", class = "WARRIOR", specID = 71 },
        { guid = "Player-1-0000000B", name = "Beta",  class = "PRIEST",  specID = 257 },
    })
    inst.NS.Roster.Refresh()
    inst.mocks.setSession(1, "*", {
        combatSources = {
            -- Exactly the raid shape: a spec on the local player's row, none on
            -- anybody else's.
            { sourceGUID = "Player-1-0000000A", name = "Alpha", classFilename = "WARRIOR",
              specIconID = 111, isLocalPlayer = true, totalAmount = 100, amountPerSecond = 10 },
            { sourceGUID = "Player-1-0000000B", name = "Beta", classFilename = "PRIEST",
              isLocalPlayer = false, totalAmount = 50, amountPerSecond = 5 },
        },
        maxAmount = 100, totalAmount = 150,
    })

    local result = inst.NS.Aggregator.Build({
        id = 1, name = "Test",
        columns = { { stat = "DamageDone", width = 80 } },
        rows = {},
        data = { sessionType = 1, sortMode = "provider", sortColumn = "DamageDone" },
    })

    local byGuid = {}
    for _, row in ipairs(result.rows) do byGuid[row.guid] = row end

    assertEqual(byGuid["Player-1-0000000A"].specIconID, 111,
        "the SOURCE wins where the client sent one")
    assertEqual(byGuid["Player-1-0000000B"].specIconID, 900257,
        "and the roster fills the row the client said nothing about")
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `Player-1-0000000B`'s `specIconID` is nil.

- [ ] **Step 3: Fall back to the roster in `newRow`**

In `modules/Aggregator.lua`, `newRow` (:180) currently reads:

```lua
        specIconID    = src and src.specIconID,
```

Replace that single line with:

```lua
        -- THE SOURCE FIRST, THE ROSTER SECOND — issue #24. The client sends
        -- `specIconID` on a raid source row for the local player and for nobody
        -- else, so this field was nil for the whole grid and every row fell
        -- through modules/Row_NameCell.lua's spec rung to the class icon. The
        -- roster reads the same fact off the unit API, where it is not missing.
        --
        -- The source still WINS where it answered: it describes the entity that
        -- actually did the damage, which for a pet or an unowned ally is not a
        -- group member at all and has no roster entry to be confused with.
        specIconID    = (src and src.specIconID) or (member and member.specIconID),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `lua tests/run.lua`
Expected: PASS, and no other case moved.

- [ ] **Step 5: Run the full gate**

Run: `lua tests/run.lua && luacheck .`
Expected: all tests PASS; `0 warnings / 0 errors`.

- [ ] **Step 6: Commit**

```bash
git add modules/Aggregator.lua tests/test_aggregator.lua
git commit -m "$(cat <<'EOF'
A row takes the roster's spec icon when the client sent none (#24)

The source still wins where it answered -- a pet or an unowned ally is
not a group member and has no roster entry to be confused with. Out of
combat this fixes issue #24 outright: the GUID is plain, so every row
joins a roster entry that knows the spec the meter did not send.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01CVx7o2xdz6H1jH2CZviDw8
EOF
)"
```

---

### Task 3: The identity-key -> GUID map, recorded out of combat

**Files:**
- Modify: `modules/Aggregator.lua` (publish two seam members near the existing `Aggregator._identity` table; call the recorder from `placeSource` at :967)
- Modify: `modules/Aggregator_Identity.lua` (the map's storage and its reader, beside `identityKey` at :104)
- Test: `tests/test_aggregator_identity.lua`

**Interfaces:**
- Consumes: `identityKey(src)` (`modules/Aggregator_Identity.lua:104`), unchanged.
- Produces:
  - `Aggregator._identity.identityMap` — `{ [key] = guid | false }`, `false` meaning
    the key stood for more than one GUID and resolves to nobody.
  - `Aggregator._identity.noteIdentity(guid, src)` — records one out-of-combat pairing.
  - `Aggregator.IdentityGUID(key) -> string|nil` — the reader, nil for an unknown
    or collided key.
  - `Aggregator.ForgetIdentityMap()` — wipes it; called on a meter reset.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_aggregator_identity.lua`:

```lua
-- ---------------------------------------------------------------------------
-- The identity -> GUID map
-- ---------------------------------------------------------------------------
--
-- Built out of combat, where the GUID is plain and the identity key can be paired
-- with it, and read mid-pull where the key is all there is. A key seen against
-- two different GUIDs resolves to NOBODY: it is exactly the ambiguity the
-- blanking rule exists for, and guessing between the two would put a stranger's
-- name on a row.

--- An out-of-combat pass over a group of `spec`, so the map is populated.
local function mapped(inst, sources)
    inst.mocks.setSession(1, "*", {
        combatSources = sources,
        maxAmount = 100, totalAmount = 300,
    })
    inst.NS.Aggregator.Build({
        id = 1, name = "Test",
        columns = { { stat = "DamageDone", width = 80 } },
        rows = {},
        data = { sessionType = 1, sortMode = "provider", sortColumn = "DamageDone" },
    })
    return inst
end

test("Aggregator: an out-of-combat pass records identity -> GUID", function()
    local inst = T.load()
    inst.mocks.setGroup({
        { guid = "Player-1-0000000A", name = "Alpha", class = "WARRIOR" },
        { guid = "Player-1-0000000B", name = "Beta",  class = "PRIEST" },
    })
    inst.NS.Roster.Refresh()
    mapped(inst, {
        { sourceGUID = "Player-1-0000000A", classFilename = "WARRIOR", specIconID = 9,
          isLocalPlayer = true, totalAmount = 100, amountPerSecond = 10 },
        { sourceGUID = "Player-1-0000000B", classFilename = "PRIEST", specIconID = 5,
          isLocalPlayer = false, totalAmount = 50, amountPerSecond = 5 },
    })

    local A = inst.NS.Aggregator
    assertEqual(A.IdentityGUID("WARRIOR_9_true"), "Player-1-0000000A")
    assertEqual(A.IdentityGUID("PRIEST_5_false"), "Player-1-0000000B")
    assertNil(A.IdentityGUID("MAGE_1_false"), "a key nobody wore")
    assertNil(A.IdentityGUID(nil), "and nil is not a key")
end)

test("Aggregator: a key worn by two GUIDs resolves to NOBODY", function()
    -- The whole safety property. Two priests of one spec share a key, and
    -- answering either GUID would put one player's name on the other's row.
    -- red under: last-write-wins.
    local inst = T.load()
    inst.mocks.setGroup({
        { guid = "Player-1-0000000A", name = "Alpha", class = "PRIEST" },
        { guid = "Player-1-0000000B", name = "Beta",  class = "PRIEST" },
    })
    inst.NS.Roster.Refresh()
    mapped(inst, {
        { sourceGUID = "Player-1-0000000A", classFilename = "PRIEST", specIconID = 5,
          isLocalPlayer = false, totalAmount = 100, amountPerSecond = 10 },
        { sourceGUID = "Player-1-0000000B", classFilename = "PRIEST", specIconID = 5,
          isLocalPlayer = false, totalAmount = 50, amountPerSecond = 5 },
    })

    assertNil(inst.NS.Aggregator.IdentityGUID("PRIEST_5_false"))
end)

test("Aggregator: a MID-PULL pass never writes the map", function()
    -- Mid-pull the GUID is secret, so there is no pairing to record — and a
    -- `rank_N` key written in as though it were a GUID would be read back later
    -- as one. red under: recording from the identity build.
    local inst = T.load()
    inst.mocks.setGroup({
        { guid = "Player-1-0000000A", name = "Alpha", class = "WARRIOR" },
    })
    inst.NS.Roster.Refresh()
    inst.mocks.setRestricted(true)
    mapped(inst, {
        { sourceGUID = "Player-1-0000000A", classFilename = "WARRIOR", specIconID = 9,
          isLocalPlayer = true, totalAmount = 100, amountPerSecond = 10 },
    })

    assertNil(inst.NS.Aggregator.IdentityGUID("WARRIOR_9_true"))
end)

test("Aggregator.ForgetIdentityMap wipes it", function()
    -- A meter reset is the moment those pairings stopped describing anything.
    local inst = T.load()
    inst.mocks.setGroup({ { guid = "Player-1-0000000A", name = "Alpha", class = "WARRIOR" } })
    inst.NS.Roster.Refresh()
    mapped(inst, {
        { sourceGUID = "Player-1-0000000A", classFilename = "WARRIOR", specIconID = 9,
          isLocalPlayer = true, totalAmount = 100, amountPerSecond = 10 },
    })
    assertEqual(inst.NS.Aggregator.IdentityGUID("WARRIOR_9_true"), "Player-1-0000000A")

    inst.NS.Aggregator.ForgetIdentityMap()
    assertNil(inst.NS.Aggregator.IdentityGUID("WARRIOR_9_true"))
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `lua tests/run.lua`
Expected: the four new cases FAIL — `Aggregator.IdentityGUID` does not exist.

- [ ] **Step 3: Store the map beside the key that builds it**

In `modules/Aggregator_Identity.lua`, immediately after `identityKey` (ends at
:112), add:

```lua
-- ---------------------------------------------------------------------------
-- THE IDENTITY -> GUID MAP
-- ---------------------------------------------------------------------------
--
-- Out of combat `sourceGUID` is plain and the identity key can be paired with
-- it. Mid-pull the key is all there is. So the pairing is RECORDED on every
-- out-of-combat pass and READ during a restricted one, which is how a row that
-- has no GUID can still be given the right name, role and spec icon.
--
-- `false` IS NOT `nil`, and the difference is the whole safety property. A key
-- seen against two different GUIDs stands for nobody: answering either one would
-- put a stranger's name on a row, which is the same lie a mislabeled number
-- would be and is refused for the same reason. `nil` means "never seen"; `false`
-- means "seen, and ambiguous". Both resolve to nothing; only `false` is a fact.
--
-- SESSION-SCOPED, deliberately. It is derived from meter sessions that a reload
-- outlives, but rebuilding it costs one out-of-combat refresh and persisting it
-- would mean a schema row, a defaults entry and a migration for a table that is
-- stale the moment somebody respecs. `Aggregator.ForgetIdentityMap` is the
-- meter-reset path.
local identityMap = {}
Seam.identityMap = identityMap

--- Record one out-of-combat pairing. Called for a GROUP MEMBER'S OWN source only.
---
--- GUARDED ON THE GUID BEING A LEGAL KEY rather than on the restriction, because
--- that is the property actually required: a secret GUID cannot be stored and a
--- `rank_N` placeholder is not a GUID at all. Mid-pull every source fails this
--- test, which is what keeps the map an out-of-combat artefact without this
--- function having to know which build is running.
local function noteIdentity(guid, src)
    if not Secrets.IsSafeKey(guid) then return end
    local key = identityKey(src)
    local seen = identityMap[key]
    if seen == nil then
        identityMap[key] = guid
    elseif seen ~= guid then
        -- Two GUIDs, one key. Latched: once ambiguous, always ambiguous for as
        -- long as this map lives, because the pass that proves it is not
        -- necessarily the pass that reads it.
        identityMap[key] = false
    end
end
Seam.noteIdentity = noteIdentity

--- The GUID a key stands for, or nil for an unknown or an ambiguous one.
---
--- @param key string|nil
--- @return string|nil
function Aggregator.IdentityGUID(key)
    if key == nil then return nil end
    local guid = identityMap[key]
    return (guid ~= false) and guid or nil
end

--- Forget every pairing — the meter-reset path.
function Aggregator.ForgetIdentityMap()
    for key in pairs(identityMap) do identityMap[key] = nil end
end
```

- [ ] **Step 4: Record from the out-of-combat build**

`modules/Aggregator_Identity.lua` loads AFTER `modules/Aggregator.lua`, so the
recorder cannot be called by name from the earlier file — it is reached off the
seam, exactly as the seam's other members are.

In `modules/Aggregator.lua`, inside `placeSource` (:967), the `isOwn` branch
currently reads:

```lua
    if isOwn then
        setCell(row, statKey, src, maxAmount, isCount)
        if touched then touched[row] = true end
```

Add the recorder as the first statement of that branch:

```lua
    if isOwn then
        -- The map that lets a mid-pull row be named. Recorded HERE because this
        -- is the one place that holds a plain GUID and the source it belongs to
        -- at the same time; `noteIdentity` refuses anything that is not a legal
        -- key, so a restricted pass writes nothing. A PET is deliberately not
        -- recorded: `isOwn` is false for one, and a pet's identity key describes
        -- the pet rather than the member whose row it folds into.
        local note = Aggregator._identity and Aggregator._identity.noteIdentity
        if note then note(row.guid, src) end
        setCell(row, statKey, src, maxAmount, isCount)
        if touched then touched[row] = true end
```

- [ ] **Step 5: Wipe it when the meter resets**

`Aggregator:OnMeterReset` (`modules/Aggregator.lua:1328`) already handles both
`METER_RESET` and `PROFILE_CHANGED`, and currently reads:

```lua
function Aggregator:OnMeterReset()
    State.WipeCache("Aggregator")
end
```

Replace the body with:

```lua
function Aggregator:OnMeterReset()
    State.WipeCache("Aggregator")
    -- The identity map describes pairings between keys and GUIDs in data that
    -- has just stopped existing. Guarded because it is published by
    -- modules/Aggregator_Identity.lua, which loads after this file — a degraded
    -- load that stopped short would otherwise take the reset path down with it.
    if Aggregator.ForgetIdentityMap then Aggregator.ForgetIdentityMap() end
end
```

Extend the doc comment above it to say so, keeping the existing sentence:

```lua
--- The cache this module owns describes a fight that no longer exists once the
--- meter is reset or the profile changes. So does the identity map: a key
--- paired with a GUID in data the client has just dropped names nobody.
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `lua tests/run.lua`
Expected: all four new cases PASS.

- [ ] **Step 7: Run the full gate**

Run: `lua tests/run.lua && luacheck .`
Expected: all tests PASS; `0 warnings / 0 errors`.

- [ ] **Step 8: Commit**

```bash
git add modules/Aggregator.lua modules/Aggregator_Identity.lua \
        tests/test_aggregator_identity.lua
git commit -m "$(cat <<'EOF'
Record identity -> GUID out of combat, so a mid-pull row can be named

`false` is not nil: a key seen against two GUIDs stands for nobody, and
answering either would put a stranger's name on a row. The recorder is
guarded on the GUID being a legal key rather than on the restriction,
which is what keeps a restricted pass from writing a rank placeholder in
as though it were a GUID.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01CVx7o2xdz6H1jH2CZviDw8
EOF
)"
```

---

### Task 4: A mid-pull row adopts its display identity, behind three gates

**Files:**
- Modify: `modules/Aggregator_Identity.lua` (`identityRow` at :294, `buildByIdentity` at :578)
- Test: `tests/test_aggregator_identity.lua`

**Interfaces:**
- Consumes: `Aggregator.IdentityGUID(key)` (Task 3), `Roster.Get(guid)` carrying
  `specIconID` (Task 1), `detectCollisions(pass)`'s result
  (`modules/Aggregator_Identity.lua:254`).
- Produces:
  - Rows built by identity carry `name`, `role` and `specIconID` from the roster
    when all three gates pass. `row.guid` is UNCHANGED — still `rank_N` /
    `ident:<key>` — so nothing about the data join, the tooltip or the drill-down
    moves.
  - `Seam.lastIdentityStats.resolved` — `{ rows, byMap, blockedCollision, blockedStale, unknown }`,
    for the report in Task 5.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_aggregator_identity.lua`:

```lua
-- ---------------------------------------------------------------------------
-- Mid-pull display identity — the three gates
-- ---------------------------------------------------------------------------
--
-- A row whose key is unambiguous in the remembered map AND unambiguous in this
-- pass AND resolves to somebody still in the group takes that member's name,
-- role and spec icon. Failing any gate leaves today's degradation exactly as it
-- is. Nothing here touches a FIGURE, and `row.guid` never moves: the resolved
-- GUID is display-only, and letting it reach the drill-down would open another
-- player's breakdown off a map built before the pull.

--- Populate the map out of combat, then run a restricted pass over `sources`.
local function resolvedPass(inst, group, oocSources, pullSources)
    inst.mocks.setGroup(group)
    inst.NS.Roster.Refresh()
    inst.mocks.setSession(1, "*", { combatSources = oocSources,
                                    maxAmount = 100, totalAmount = 300 })
    local cfg = {
        id = 1, name = "Test",
        columns = { { stat = "DamageDone", width = 80 } },
        rows = {},
        data = { sessionType = 1, sortMode = "provider", sortColumn = "DamageDone" },
    }
    inst.NS.Aggregator.Build(cfg)

    inst.mocks.setRestricted(true)
    inst.mocks.setSession(1, "*", { combatSources = pullSources,
                                    maxAmount = 100, totalAmount = 300 })
    return inst.NS.Aggregator.Build(cfg)
end

test("Identity: an unambiguous row takes the roster's name and spec icon", function()
    -- red under: taking the source's own (secret) name mid-pull for a row the
    -- map can name outright.
    local inst = T.load()
    local src = { classFilename = "PRIEST", specIconID = 5, isLocalPlayer = false,
                  totalAmount = 50, amountPerSecond = 5 }
    local result = resolvedPass(inst,
        { { guid = "Player-1-0000000A", name = "Alpha", class = "WARRIOR", specID = 71 },
          { guid = "Player-1-0000000B", name = "Healbot", class = "PRIEST",
            role = "HEALER", specID = 257 } },
        { { sourceGUID = "Player-1-0000000A", classFilename = "WARRIOR", specIconID = 9,
            isLocalPlayer = true, totalAmount = 100, amountPerSecond = 10 },
          { sourceGUID = "Player-1-0000000B", classFilename = "PRIEST", specIconID = 5,
            isLocalPlayer = false, totalAmount = 50, amountPerSecond = 5 } },
        { { sourceGUID = "Player-1-0000000A", classFilename = "WARRIOR", specIconID = 9,
            isLocalPlayer = true, totalAmount = 100, amountPerSecond = 10 }, src })

    local priest
    for _, row in ipairs(result.rows) do
        if row.identityKey == "PRIEST_5_false" then priest = row end
    end
    assertTrue(priest ~= nil, "the priest row is missing")
    assertEqual(priest.name, "Healbot", "the roster's plain name, not the secret one")
    assertEqual(priest.role, "HEALER")
    assertEqual(priest.specIconID, 900257, "the roster's spec icon")
    assertTrue(priest.guid:find("^rank_") ~= nil or priest.guid:find("^ident:") ~= nil,
        "the row key must NOT become the resolved GUID")
end)

test("Identity: a key ambiguous in THIS pass is never resolved", function()
    -- Gate 2. The map may name the key from a pull where only one priest was
    -- present; two on the grid now means neither can be named.
    -- red under: trusting the map alone.
    local inst = T.load()
    local result = resolvedPass(inst,
        { { guid = "Player-1-0000000A", name = "Alpha", class = "PRIEST", specID = 257 } },
        { { sourceGUID = "Player-1-0000000A", classFilename = "PRIEST", specIconID = 5,
            isLocalPlayer = false, totalAmount = 100, amountPerSecond = 10 } },
        { { classFilename = "PRIEST", specIconID = 5, isLocalPlayer = false,
            totalAmount = 100, amountPerSecond = 10 },
          { classFilename = "PRIEST", specIconID = 5, isLocalPlayer = false,
            totalAmount = 50, amountPerSecond = 5 } })

    for _, row in ipairs(result.rows) do
        assertTrue(row.name ~= "Alpha",
            "a collided key must never wear a resolved name")
    end
end)

test("Identity: a resolved GUID who has LEFT the group is not used", function()
    -- Gate 3. The map outlives the group it was built from; a name for somebody
    -- who is no longer here is a name for somebody else's row.
    -- red under: skipping the membership check.
    local inst = T.load()
    inst.mocks.setGroup({
        { guid = "Player-1-0000000A", name = "Alpha", class = "WARRIOR" },
        { guid = "Player-1-0000000B", name = "Healbot", class = "PRIEST", specID = 257 },
    })
    inst.NS.Roster.Refresh()
    local cfg = {
        id = 1, name = "Test",
        columns = { { stat = "DamageDone", width = 80 } },
        rows = {},
        data = { sessionType = 1, sortMode = "provider", sortColumn = "DamageDone" },
    }
    inst.mocks.setSession(1, "*", { combatSources = {
        { sourceGUID = "Player-1-0000000B", classFilename = "PRIEST", specIconID = 5,
          isLocalPlayer = false, totalAmount = 50, amountPerSecond = 5 },
    }, maxAmount = 50, totalAmount = 50 })
    inst.NS.Aggregator.Build(cfg)

    -- The priest leaves, and the meter is reset so nothing remembers them.
    inst.NS.Roster.Forget()
    inst.mocks.setSolo("Player-1-0000000A", "Alpha", "WARRIOR")
    inst.NS.Roster.Refresh()

    inst.mocks.setRestricted(true)
    local result = inst.NS.Aggregator.Build(cfg)
    for _, row in ipairs(result.rows) do
        assertTrue(row.name ~= "Healbot", "a departed member must not name a row")
    end
end)

test("Identity: the pass reports which tier each row resolved through", function()
    -- The measurement, in the shape the rest of this file's diagnostics take:
    -- a rate nobody can see is a mechanism nobody can tune.
    local inst = T.load()
    inst.NS.State.debug = true
    resolvedPass(inst,
        { { guid = "Player-1-0000000A", name = "Alpha", class = "WARRIOR", specID = 71 } },
        { { sourceGUID = "Player-1-0000000A", classFilename = "WARRIOR", specIconID = 9,
            isLocalPlayer = true, totalAmount = 100, amountPerSecond = 10 } },
        { { sourceGUID = "Player-1-0000000A", classFilename = "WARRIOR", specIconID = 9,
            isLocalPlayer = true, totalAmount = 100, amountPerSecond = 10 } })

    local stats = inst.NS.Aggregator.LastIdentityStats()
    assertTrue(stats ~= nil, "no identity pass was measured")
    assertTrue(stats.resolved ~= nil, "the resolution tiers are missing")
    assertEqual(stats.resolved.rows, 1)
end)
```

- [ ] **Step 2: Run them to verify they fail**

Run: `lua tests/run.lua`
Expected: the four new cases FAIL — no row carries a resolved name and
`stats.resolved` is nil.

- [ ] **Step 3: Resolve, behind the three gates**

In `modules/Aggregator_Identity.lua`, add this function immediately above
`identityRow` (:294):

```lua
--- Give a row the identity the map can prove, or leave it exactly as it was.
---
--- THREE GATES, AND ALL THREE ARE LOAD-BEARING:
---
---   1. The MAP must name one GUID for this key. `false` — two GUIDs wore it out
---      of combat — resolves to nobody.
---   2. THIS PASS must not have found the key ambiguous. The map may have been
---      built from a pull where only one of the two priests was present, and two
---      on the grid now means neither can be named.
---   3. The GUID must still be one of ours. The map outlives the group it
---      describes, and a name for somebody who left is a name for somebody
---      else's row.
---
--- WHAT IT DOES NOT TOUCH. `row.guid` stays the position key it was built with.
--- The resolved GUID is DISPLAY ONLY: letting it become the row key would send
--- the drill-down and the tooltip to look up a source by a GUID this pass never
--- read off the meter, and a stale map would open another player's breakdown.
--- Not one FIGURE is resolved either — a collided key blanks its cells exactly as
--- before, and this changes nothing about that rule.
---
--- THE RESIDUAL RISK, stated rather than hidden: a player who joins mid-fight
--- wearing a key that was unambiguous when the map was built inherits the earlier
--- player's name. It needs a same-class, same-spec replacement arriving inside
--- one pull, and the tiers below are what would show it happening.
local function resolveIdentity(pass, row, key)
    local tiers = pass.resolved
    tiers.rows = tiers.rows + 1

    local guid = Aggregator.IdentityGUID(key)
    if guid == nil then
        -- Gate 1. Told apart for the report: a key the map latched as ambiguous
        -- and a key it never saw need different fixes.
        if Seam.identityMap[key] == false then
            tiers.blockedCollision = tiers.blockedCollision + 1
        else
            tiers.unknown = tiers.unknown + 1
        end
        return
    end
    if pass.collisions and pass.collisions[key] then
        tiers.blockedCollision = tiers.blockedCollision + 1
        return
    end
    if not Roster.IsGroupMember(guid) then
        tiers.blockedStale = tiers.blockedStale + 1
        return
    end

    local member = Roster.Get(guid)
    if member == nil then
        tiers.blockedStale = tiers.blockedStale + 1
        return
    end

    tiers.byMap = tiers.byMap + 1
    -- Each field only where the roster HAS one, so a partial entry never blanks
    -- something the source could still answer.
    if member.name ~= nil then row.name = member.name end
    if member.role ~= nil then row.role = member.role end
    if member.specIconID ~= nil then row.specIconID = member.specIconID end
end
```

- [ ] **Step 4: Call it, and give the pass what it needs**

Still in `modules/Aggregator_Identity.lua`:

In `identityRow`, the block that ends the "not local" branch currently reads:

```lua
    if not isLocal then
        row.isPlayer      = false
        row.isLocalPlayer = false
    end
    row.identityKey   = key
```

Replace it with:

```lua
    if not isLocal then
        row.isPlayer      = false
        row.isLocalPlayer = false
        -- The local player already keys on a real GUID and took the roster's
        -- name and role in newRow; everybody else gets whatever the map can
        -- prove, which for a collided key is nothing.
        resolveIdentity(pass, row, key)
    end
    row.identityKey   = key
```

In `buildByIdentity` (:578), the pass currently computes `collisions` and keeps
them local. Publish both the set and the tier counters onto the pass, so
`identityRow` can reach them — immediately after
`local collisions = detectCollisions(pass)`, add:

```lua
    -- ON THE PASS, because identityRow runs per source and both of these are
    -- whole-pass facts. The counters are ours and plain: incrementing them is not
    -- arithmetic on a meter value and stays legal mid-pull.
    pass.collisions = collisions
    pass.resolved = { rows = 0, byMap = 0, blockedCollision = 0,
                      blockedStale = 0, unknown = 0 }
```

- [ ] **Step 5: Carry the tiers out on the stats**

In `identityStats` (:517), the stats literal ends with
`positions    = probePositions(pass, collisions),`. Add one line after it:

```lua
        -- The mid-pull identity resolution's own rate, so the mechanism can be
        -- tuned against a capture rather than against an opinion.
        resolved     = pass.resolved,
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `lua tests/run.lua`
Expected: all four new cases PASS, and every pre-existing identity case still
passes — in particular the ones asserting that collided rows keep blank cells.

- [ ] **Step 7: Run the full gate, including complexity**

Run: `lua tests/run.lua && luacheck . && lizard -l lua -C 15 modules/Aggregator_Identity.lua`
Expected: all tests PASS; `0 warnings / 0 errors`; lizard reports
`No thresholds exceeded`. If `resolveIdentity` lands above CCN 15, split the
gate chain into a helper that answers the resolved GUID or nil and a caller that
applies the fields.

- [ ] **Step 8: Commit**

```bash
git add modules/Aggregator_Identity.lua tests/test_aggregator_identity.lua
git commit -m "$(cat <<'EOF'
A mid-pull row adopts its display identity behind three gates

Unambiguous in the map, unambiguous in this pass, and still in the
group. `row.guid` never moves -- the resolved GUID is display-only, and
letting it become the row key would send the drill-down to open another
player's breakdown off a map built before the pull. No figure is
resolved: a collided key blanks its cells exactly as before.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01CVx7o2xdz6H1jH2CZviDw8
EOF
)"
```

---

### Task 5: The report prints the resolution tiers

**Files:**
- Modify: `core/Diagnostics_Identity.lua` (`reportIdentity`)
- Test: `tests/test_diagnostics_identity.lua`

**Interfaces:**
- Consumes: `Aggregator.LastIdentityStats().resolved` (Task 4).
- Produces: nothing other tasks read.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_diagnostics_identity.lua`, before the field-audit case:

```lua
test("Diagnostics: the report prints how many rows resolved an identity", function()
    -- The mid-pull resolution is the one mechanism here that can be WRONG rather
    -- than merely empty, so its rate is the number to watch across a raid night.
    local inst = pulled(T.load{ enable = true })
    local text = identityReport(inst)

    assertTrue(text:find("identity resolution", 1, true) ~= nil,
        "the resolution line is missing")
    assertTrue(text:find("collided", 1, true) ~= nil,
        "the blocked tiers are missing")
end)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — "the resolution line is missing".

- [ ] **Step 3: Print the tiers**

In `core/Diagnostics_Identity.lua`, add this function immediately above
`reportMultiplicity`:

```lua
--- How many rows recovered a real name and icon, and why the rest did not.
---
--- `byMap` is the mechanism working. `collided` and `stale` are it REFUSING,
--- which is the behaviour to want. `unknown` is a key the out-of-combat map never
--- saw at all — a player who joined after the last unrestricted refresh — and a
--- large figure there says the map is being rebuilt too rarely rather than that
--- anything is wrong.
local function reportResolution(stats)
    local r = stats.resolved
    if r == nil then return end

    out(string.format("  identity resolution: %d of %d rows named from the map",
        r.byMap, r.rows))
    out(string.format("    collided %d   stale %d   unknown %d",
        r.blockedCollision, r.blockedStale, r.unknown))
    out("  collided = ambiguous in the map or in this pass; stale = the GUID it")
    out("  named has left the group. Both are REFUSALS and are working as built.")
end
```

Then call it from `reportIdentity`, on the line immediately after
`reportRectangle(stats)`:

```lua
        reportResolution(stats)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `lua tests/run.lua`
Expected: PASS.

- [ ] **Step 5: Run the full gate**

Run: `lua tests/run.lua && luacheck .`
Expected: all tests PASS; `0 warnings / 0 errors`.

- [ ] **Step 6: Commit**

```bash
git add core/Diagnostics_Identity.lua tests/test_diagnostics_identity.lua
git commit -m "$(cat <<'EOF'
`/mm debug identity` prints the resolution tiers

The mid-pull resolution is the one mechanism here that can be wrong
rather than merely empty, so its rate is the number to watch. Collided
and stale are refusals working as built; a large `unknown` says the
out-of-combat map is being rebuilt too rarely.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01CVx7o2xdz6H1jH2CZviDw8
EOF
)"
```

---

### Task 6: The docs follow the code

**Files:**
- Modify: `docs/module-map.md` (the `Roster.lua` and `Aggregator.lua` rows)
- Modify: `docs/data-flow.md` (the identity-mode section)
- Modify: `docs/ARCHITECTURE.md` (Known limitations)
- Regenerate: `docs/test-cases.md`

**Interfaces:**
- Consumes: every public name added in Tasks 1-5.
- Produces: nothing code reads.

- [ ] **Step 1: Update the module map**

In `docs/module-map.md`, find the `Roster.lua` row and add `SpecIconOf` and
`ProbeSpecCoverage` to its published-surface cell, in the order they appear in
the file. Find the `Aggregator.lua` row and add `IdentityGUID` and
`ForgetIdentityMap` to its cell the same way.

- [ ] **Step 2: Correct the data-flow claim**

`docs/data-flow.md` states that identity mode is built out of the fields Blizzard
annotates `NeverSecret`, and issue #22 quotes it as the assumption that failed.
Add a paragraph to that section recording what is now true:

> A row built by identity also carries a DISPLAY identity where one can be
> proved: an identity-key -> GUID map recorded on every out-of-combat pass is
> consulted mid-pull, and a key that is unambiguous in the map, unambiguous in
> this pass, and still resolves to a group member gives the row that member's
> name, role and spec icon. The row's own key does not change — the resolved
> GUID never reaches the data join, the tooltip or the drill-down — and no
> figure is resolved: a collided key blanks its cells exactly as before.

- [ ] **Step 3: Record what is still open**

In `docs/ARCHITECTURE.md`'s Known limitations, add a row or bullet in the shape
the section already uses, saying: the roster resolves a spec icon only for the
local player and for members the client already holds inspect data on, because
the addon never sends `NotifyInspect`; `/mm debug identity`'s spec-coverage line
measures the shortfall, and a passive inspect service is the open direction if
that ratio proves low in a real raid. Reference issue #24.

- [ ] **Step 4: Regenerate the test inventory**

The generator writes LF; `.gitattributes` declares `docs/test-cases.md` CRLF, and
a test asserts it. Regenerate and convert in one step:

```bash
lua tests/run.lua --list > /tmp/tc.md && python3 -c "
import io
d = io.open('/tmp/tc.md','rb').read().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
io.open('docs/test-cases.md','wb').write(d)
"
```

- [ ] **Step 5: Verify the inventory is in sync and the gate is green**

```bash
diff <(lua tests/run.lua --list) docs/test-cases.md && echo "in sync"
lua tests/run.lua && luacheck .
```

Expected: `in sync` with no diff output; all tests PASS including the eol case;
`0 warnings / 0 errors`.

- [ ] **Step 6: Commit**

```bash
git add docs/module-map.md docs/data-flow.md docs/ARCHITECTURE.md docs/test-cases.md
git commit -m "$(cat <<'EOF'
The docs follow the roster-spec and identity-resolution work

data-flow.md carried the assumption issue #22 quotes as the one that
failed; it now records what identity mode actually does. The remaining
gap -- a spec icon for a member the client holds no inspect data on --
is in Known limitations with the coverage line that measures it.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01CVx7o2xdz6H1jH2CZviDw8
EOF
)"
```

---

## After the plan

Neither issue closes here.

- **#24** is fixed out of combat and improved mid-pull wherever the key
  discriminates. It stays open on the raid mid-pull case, which is #22.
- **#22** is untouched by design. It turns on the `/mm debug identity` lookup
  verdict: if the client resolves a source from a secret GUID, identity
  correlation goes away entirely and most of Task 4 becomes dead code worth
  deleting. Do not start #22 work before that capture is in.
- The **spec-coverage ratio** from Task 1 decides whether a passive inspect
  service is worth planning. Model it on `Scoot/core/inspect.lua` if so — one
  owner for every `NotifyInspect`, a ticker behind a `CanSendNow()` gate, and a
  `hooksecurefunc` back-off so the player's own inspect always wins.
