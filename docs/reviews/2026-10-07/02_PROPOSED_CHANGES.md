# Proposed changes — Ka0s Multi Meters, review of 2026-10-07

These changes were checked against Ka0s WoW Addon Standard **v2.76.1 (2026-10-07)**, which was fetched with `curl` (27 section files). Finding IDs refer to `01_FINDINGS.md`. No entry targets `libs/` or `tests/_kit/`.

## HLD

### Theme A: make the pet fold independent of source order (F-001, F-002)

The fold was written for "owner first, then pets", and the provider orders sources by value, so a pet that out-did its owner arrives first. There are two possible repairs:

- **Chosen:** mark a cell that a pet fold created, and when the owner's own source lands on a marked cell, *add* to it instead of replacing it. This keeps the single pass and the existing guards, and touches one function.
- *Rejected:* a two-pass scan (owners first, pets second). It doubles the walk over `column.sources` in the hottest path, measured at `refresh20x7` 297237.4 bytes/iter today. It also changes `providerIndex` bookkeeping that three existing cases pin.
- *Rejected:* changing the existing case at `tests/test_aggregator.lua:341` so that it also checks the total. `testing-§12` and the review rules say to add the falsifying case, not to change what an existing case pins.

### Theme B: retry a partial roster once per pass, not once per lookup (F-003)

The comments already state the intended contract: one unit walk per refresh. The code does a walk per lookup. The chosen design separates the *read* path from the *retry* path:

- `Roster.Get`, `IsGroupMember`, `OwnerOf` and `LocalGUID` read the cached map, even when it is partial.
- `Roster.GetGroup()`, the explicit and public entry point, keeps retrying a partial map. The aggregator calls it once at the start of each GUID-join pass, so each refresh retries once.
- This keeps `tests/test_roster.lua:330`'s contract intact ("the very next read [of `GetGroup`] is correct, with no event needed").
- *Rejected:* a `GetTime()`-keyed throttle. The mock's `GetTime` is inherited from the base, and the existing case's "next read" would then depend on the clock, which would mean editing that case.

### Theme C: window-name UX (F-004, F-005)

- A window being renamed is not a collision with itself.
- `/mm window copy` resolves the source/target split by trying each whitespace boundary until both halves resolve. That handles names with spaces without adding quoting syntax to the slash grammar.

### Theme D: keep the secret inspection in one file (F-006, F-007)

Move `plainTruth` into `core/Secrets.lua` as `Secrets.PlainTruth`, as the `CLAUDE.md` invariant requires. Both module copies and the two Provider diagnostic probes then call it. This is one addon, two consumers with identical semantics and no behavior flags, so it is **not** anti-pattern #55, which concerns promotion into a shared library on raw frequency.

### Theme E: remove the retired back button (F-008)

Delete the dead machinery and its three cases. The test count drops by three in the same change (`testing-§5`).

### Deferred: F-009

The vehicle pair stays on AceEvent. The `events-frames-taint-§1` unit-filter frame is permitted, but it would add a frame that the `slash-commands-§7` stand-down and the mock's registration recording must both cover, all for an event that rarely fires. Revisit only if a capture brackets the handler and shows a cost.

## Upstream change-set

None.

## LLD

### C-01: an own source adds to a pet-created cell (F-001, F-002)

**File:** `modules/Aggregator.lua`, in `foldPet` (`:265`) and `placeSource` (`:917`).

```lua
-- foldPet: when the owner has no cell yet, adopt the pet's figures and MARK the cell
if cell == nil then
    setCell(row, statKey, src, nil)
    row.values[statKey].fromPet = true
    return true
end
-- (the sum branch also sets cell.fromPet = true — a cell holding any pet share is marked)

-- placeSource, the isOwn branch
if isOwn then
    local prior = (not isCount) and row.values[statKey] or nil
    setCell(row, statKey, src, maxAmount, isCount)
    if prior and prior.fromPet and not addPetShare(row.values[statKey], prior) then
        pass.unfolded = pass.unfolded + 1
    end
    if touched then touched[row] = true end
```

`addPetShare(cell, prior)` adds `prior.total` and `prior.rate` into `cell` using the guards `foldPet` already uses: `Secrets.CanCompare2` and both operands `number`. It returns false when the addition is illegal. The fold runs only unrestricted, so in practice the false branch is defensive.

**Tests (new, in `tests/test_aggregator.lua`):** `"A pet that outranks its owner still folds into the owner's total and rate"`, using sources `PET 400 (rate 40) → BETA 200 → ALPHA 100 (rate 10)` with `mergePets` on, and asserting `total == 500` and `rate == 50`. Its comment reads `-- red under: drop the fromPet merge in placeSource`. Today's code returns 100 (measured; see F-001). Optionally add a second case with two pets ahead of the owner.

**Risk:** `fromPet` is a new field on a cell table that the Row, Tooltip and Export modules read by name. None of them iterates a cell with `pairs`, so an extra key is inert (to confirm in review by grepping `pairs(cell` and `pairs(c)`). The fix only fires when `mergePets` is on.

**Count movement:** +1 (or +2). Regenerate `docs/test-cases.md` with `lua tests/run.lua --list > docs/test-cases.md` and update the README `[tests]` badge **in the same change** (`testing-§5`).

### C-02: a partial roster is retried once per pass (F-003)

**File:** `modules/Roster.lua`, in `ensure` (`:537`) and the public lookups. Also `modules/Aggregator.lua`, in `Build` (`:1193`), and `tests/perf.lua`.

```lua
-- Read path: build only when cold; a partial map is answered from, not rebuilt.
local function current()
    return cache.group or build()
end

-- Retry path: the one place a partial map is rebuilt.
local function ensure()
    local group = cache.group
    if group and not cache.partial then return group end
    return build()
end

function Roster.GetGroup() return ensure() end          -- unchanged contract
-- Get / IsGroupMember / OwnerOf / LocalGUID: ensure() -> current()
```

In `Aggregator.Build`, on the unrestricted branch only, before the `scanColumn` loop, call `Roster.GetGroup()` so that each GUID-join pass retries a partial roster once. The identity branch keeps only `Roster.LocalGUID()`.

**Comments:** rewrite `modules/Roster.lua:405` and `:533-535` to describe the new contract ("retried once per aggregate pass, from `Aggregator.Build` through `GetGroup`; the lookups read what is there"). Today's text describes it, but the code does not do it yet.

**Tests:** add `"A partial roster is walked once per pass, not once per lookup"`. It counts `inst.mocks.UnitGUID` calls across one seven-column `Aggregator.Build` with `party2` unresolved and asserts **one** walk's worth (the number of resolved units). Its comment reads `-- red under: Roster.Get calling ensure()`. Today's code gives 60 against 3 (measured). `tests/test_roster.lua:330` must stay green unchanged. If any existing case goes red, that is a behavior pin, and the design gets revised; the case is never edited.

**Perf:** add a `rosterPartial` scenario to `tests/perf.lua`: `refresh20x7` with one unit unresolved. Assert `api/iter` equals `refresh20x7`'s 8.00 plus at most one walk. Scenarios are not test cases (`testing-§7`, `performance-§9`), so the badge does not move for this.

**Count movement:** +1.

### C-03: a rename does not collide with itself (F-004)

**File:** `modules/WindowManager.lua`, in `uniqueName` (`:187`) and `Rename` (`:319`).

```lua
local function uniqueName(base, selfId)
    base = tostring(base or ""):match("^%s*(.-)%s*$")
    if base == "" then return defaultName() end
    local hit = M.Resolve(base)
    if not hit or hit.id == selfId then return base end
    local n = 2
    while true do
        local cand = base .. " " .. n
        local h = M.Resolve(cand)
        if not h or h.id == selfId then return cand end
        n = n + 1
    end
end
-- Rename: uniqueName(newName, cfg.id); Create/Duplicate pass nil (unchanged behavior)
```

**Tests:** `"Renaming a window to a different case of its own name keeps that name"` (`Raid` → `raid` gives `raid`), with `-- red under: drop the selfId check`. The existing `"Rename keeps the uniqueness check the row does not have"` (`tests/test_windowmanager.lua:683`) must stay green.

**Count movement:** +1.

### C-04: `/mm window copy` accepts names with spaces (F-005)

**File:** `settings/Slash.lua`, in `WINDOW_VERBS.copy` (`:615`).

```lua
function WINDOW_VERBS.copy(M, tail)
    if not M.CopyFrom then return false, WINDOW_USAGE end
    -- Try every whitespace split, left to right, until both halves name a window.
    for left, right in splits(tail) do            -- "a b c" -> ("a","b c"), ("a b","c")
        if M.Resolve(left) and M.Resolve(right) then return M:CopyFrom(left, right) end
    end
    local source, target = tail:match("^(%S+)%s+(.+)$")   -- unchanged error path
    if not source then return false, WINDOW_USAGE end
    return M:CopyFrom(source, target)
end
```

`splits` is a file-local iterator built **once at file scope**, not inside the handler. The fallback keeps today's `No window named '…'` reply for a genuinely unknown name. If the split is ambiguous (several splits resolve), the leftmost resolving split wins, and the `docs/slash-dispatch.md` window-verb row says so.

**Tests:** `"window copy resolves a source name with spaces"` (`Multi Meters #1` → `Second`), with `-- red under: the single %S+ split`.

**Count movement:** +1.

**Standards:** `slash-commands-§3` (the `COMMANDS` table stays the host's). The verb surface is unchanged; only argument parsing changes.

### C-05: `Secrets.PlainTruth` (F-006, F-007)

**Files:** `core/Secrets.lua` (new member), `modules/Aggregator.lua:446` (the local becomes an alias of the member, and the `_identity.plainTruth` seam keeps its name), `modules/Tooltip.lua:224` (alias; the `NS.Secrets` absence guard moves into the caller only if `Tooltip` can load without `Secrets`, which the TOC order rules out because `core/Secrets.lua` loads first), and `modules/Provider.lua:551`, `:649`, `:676`.

```lua
-- core/Secrets.lua
function Secrets.PlainTruth(v)
    if not Secrets.CanAccess(v) then return false end
    return v and true or false
end
-- Provider probes
if Secrets.PlainTruth(src.isLocalPlayer) then ... end
local plain = not Secrets.IsSecret(value)        -- drop the boolean short-circuit
```

**Tests:** in `tests/test_secrets.lua`, `"PlainTruth reads a secret boolean as no claim"`. Use `tests/mock_secrets.lua`'s secret wrapper, with `-- red under: return v and true or false unguarded`. Re-run `tests/test_provider_fields.lua` unchanged. If a case pins the boolean short-circuit, read why before changing course.

**Count movement:** +1.

### C-06: remove the retired back button (F-008)

**Files:** `modules/DrillDown.lua` (`AcquireBackButton`, `ReleaseBackButton`, `backButtons`, `BACK_BUTTON_WIDTH`/`HEIGHT`, and the two lookups in `Exit`/`ExitAll`), `modules/Window.lua:1286-1298` (the `ReleaseBackButton` call and the two comments above it), `tests/test_drilldown.lua:376`, `:393`, `:405` (the three cases over removed code), and `docs/module-map.md:338` (the `DrillDown.lua` row lists `AcquireBackButton`, `ReleaseBackButton`).

**Risk:** characterization is not required (`testing-§13`): this removes behavior that has no caller, rather than refactoring live behavior. Grep `BackButton` across the repo afterwards. It must come back empty outside `docs/reviews/` and `docs/audits/`, which are frozen.

**Count movement:** −3.

## Net test movement

Roughly 2188 → 2190 total (+1 C-01, +1 C-02, +1 C-03, +1 C-04, +1 C-05, −3 C-06). The exact figure is whatever the regenerated `--list` says. Each change regenerates `docs/test-cases.md` and the badge itself, never in a later commit.

## Complexity note (for the next release run to confirm, not to run now)

C-01 adds one branch to `placeSource`, which currently passes lizard. The fresh run shows max CCN 15 across the tree, so check `placeSource` on the next release run. If it reaches 16, extract `addPetShare` as a named helper, not as a `part2`-style helper (anti-pattern #52). C-04's `splits` iterator is a new file-local in `settings/Slash.lua` (924 lines today, below the 1000-line on-notice band).

## Standards conformance

| Change | Conformance |
|---|---|
| C-01 | No new deviation. The new case carries a `red under` comment (`testing-§12`). Inventory and badge move in the same change (`testing-§5`) |
| C-02 | No new deviation. The offline scenario lives in the runner, outside the gate (`performance-§9`, `testing-§7`). No existing test is edited (`testing-§12`) |
| C-03 | No new deviation. Writes still go through `NS.SetByPath` (the single write seam) |
| C-04 | No new deviation. The verb set is unchanged (`slash-commands-§2`, `§3`). No per-call table is built inside the handler |
| C-05 | Restores `CLAUDE.md`'s "`core/Secrets.lua` is the only file that inspects a value". Not anti-pattern #55: it stays in the addon and is not promoted into LibKa0s |
| C-06 | No new deviation. The count moves in the same change (`testing-§5`) |
