-- modules/Export.lua
--
-- Takes what a meter window is showing and turns it into text a human can carry
-- somewhere else: a CSV of the whole segment for a spreadsheet, or a short
-- ranked list for chat. A glyph in the window header opens the modal below;
-- `/mm export` opens the same one.
--
-- TOC POSITION: modules/, after modules/DrillDown.lua. Everything it needs from
-- a sibling module is resolved at CALL time (see `mod` below), so its place in
-- the modules/ block carries no meaning beyond "after the things it reads".
--
-- ---------------------------------------------------------------------------
-- WHY THIS FILE HAS NO DATA PATH OF ITS OWN
-- ---------------------------------------------------------------------------
--
-- The tempting shape is a walk over the meter API: an export wants every stat
-- for every player, which is exactly the loop modules/Provider.lua already
-- writes. Doing it again here would put a SECOND caller on C_DamageMeter, and
-- rule R1 (docs/data-flow.md) allows exactly one.
--
-- So this file asks for its data the way a window does. SessionConfig builds a
-- SYNTHETIC window config — one naming every stat in the catalog, pointed at the
-- invoking window's segment — and hands it to Aggregator.Build. The aggregator
-- does not know or care that no frame will ever draw the result. Nothing below
-- touches Provider, Compat's meter shims, or C_DamageMeter, and it must stay
-- that way: an export is a consumer of the grid's data, not a second producer.
--
-- ---------------------------------------------------------------------------
-- WHY THE WHOLE THING IS A REFUSAL IN COMBAT
-- ---------------------------------------------------------------------------
--
-- A CSV cell is `tostring(value)`, and `tostring` is NOT on docs/data-flow.md's
-- list of operations permitted on a secret. It does not raise and it does not
-- launder: it answers a SECRET STRING, which then poisons the `find`, the `gsub`
-- and the `..` that RFC-4180 quoting is made of. There is no way to write a
-- serializer that is correct while the Combat restriction is active, and a
-- serializer that is subtly wrong mid-pull is worse than one that says no.
--
-- Hence two independent guards, deliberately belt-and-braces:
--
--   1. STRUCTURAL. Secrets.IsRestricted() is asked when the modal opens, again
--      inside each click handler, and once more at the top of the serializers.
--      The restriction can activate while the modal sits open; the click is the
--      last moment anyone can check.
--   2. PER VALUE. Every field passes Secrets.CanAccess on its way in and yields
--      "" when it fails. A race between the check and the walk can therefore
--      produce a blank cell. It can never produce an error.
--
-- ---------------------------------------------------------------------------
-- THE TWO HALVES, AND WHY THEY ARE TWO FILES
-- ---------------------------------------------------------------------------
--
-- Everything here is PURE: no frames, no globals beyond the ones the fields come
-- from, and every function reachable from the headless harness
-- (tests/test_export.lua). The other half is the export modal, and it now lives
-- in modules/Export_Modal.lua: built lazily on the first Open and guarded on
-- CreateFrame so it loads in a harness that has no client at all -- the UI half
-- degrades to nil and this half still works.
--
-- They were one file until it went over layout-§1's 1500-line cap. The seam is
-- the one this banner already drew; nothing moved across it. Three file-locals
-- the modal still needs are published at the bottom of this file, and that is the
-- only thing the peel changed.

local _, NS = ...

-- A PLAIN TABLE on NS, like NS.Slash — not an AceAddon module. There is no
-- OnEnable to run and nothing to wire at load: it is called directly
-- (NS.Export:Open) and nothing else.
--
-- It does take ONE bus subscription, and only once a modal has been built:
-- RESTRICTION_CHANGED, on a private target, so an open dialog greys its buttons
-- when a pull starts instead of waiting for a click to explain itself. Its only
-- other lasting state is the window it was opened from and the two lazily built
-- frames.
NS.Export = NS.Export or {}
local Export = NS.Export

local Const = NS.Constants
local L     = NS.L

-- U+2014 EM DASH, spelled in bytes. The source files in this addon are read and
-- edited by tools whose encoding cannot be assumed; the escape always survives.
local EM_DASH = " \226\128\148 "

-- The shape of a staggered chat dump. See "Getting a dump past the server" for
-- the rules these three numbers answer to.
--
-- CHAT_STAGGER is roughly three lines a second: inside the byte budget, and fast
-- enough that a five-line ranking is on screen before anybody has read the first
-- line. CHAT_BATCH_GAP is the extra second taken every CHAT_BATCH lines, which is
-- what keeps a long dump under the "too many messages" counter public channels
-- keep as well as under the byte rate. A forty-line dump takes about twenty
-- seconds, and arriving whole is the point.
local CHAT_STAGGER   = 0.3
local CHAT_BATCH     = 5
local CHAT_BATCH_GAP = 1.0

--- Resolve a collaborator by either shape it can have: a plain table hung on NS,
--- or an AceAddon module in the registry. Same helper modules/Window.lua uses,
--- and here for a second reason as well — modules/ load order relative to this
--- file is not guaranteed, so NOTHING below may be captured at file scope.
---
--- @param name string
--- @return table|nil
local function mod(name)
    local m = NS[name]
    if m then return m end
    if NS.GetModule then return NS:GetModule(name, true) end
    return nil
end

--- The number formatter, resolved defensively. NS.Format is a callable table and
--- NS.NumberFormat is the same object under its other name; a degraded install
--- can have published only one of them.
---
--- @return table|nil
local function fmt()
    local F = mod("Format")
    if type(F) ~= "table" or not F.Number then F = NS.NumberFormat end
    if type(F) ~= "table" or not F.Number then return nil end
    return F
end

--- Accept either a Window instance or a bare config table.
---
--- The slash verb has only a config (it walks the registry), the header glyph
--- has only an instance, and every entry point below is reachable from both. One
--- unwrap at the top of each is cheaper than two APIs.
---
--- @param win table|nil  a Window instance, or a window config
--- @return table  a config table, possibly empty
local function cfgOf(win)
    if type(win) ~= "table" then return {} end
    if type(win.config) == "table" then return win.config end
    return win
end

-- ---------------------------------------------------------------------------
-- Serialization — pure
-- ---------------------------------------------------------------------------

--- Is exporting legal right now?
---
--- The one gate the whole file hangs off. False while the Combat restriction is
--- active, because a serializer cannot run there (see the header). Answers a
--- real boolean and a sentence the caller may show verbatim.
---
--- @return boolean available, string|nil reason
function Export.Available()
    local Secrets = mod("Secrets")
    if Secrets and Secrets.IsRestricted() then
        return false, L["Export is not available while the game restricts combat data."]
    end
    return true, nil
end

--- A stat key as a CSV header name: "DamageDone" -> "damage_done".
---
--- DERIVED, never a restated list. A hand-written table of nine header names is a
--- table that goes stale the first time the catalog grows a tenth stat, and it
--- goes stale silently — the new column would export under whatever name the
--- table's fallback picked. The one rule below covers every key the catalog has
--- and every key it will have, because the keys are CamelCase by construction.
---
--- A localized label is emphatically NOT what goes here: a CSV is a data
--- interchange, and a German client must produce a file a colleague on an
--- English client can open with the same formulas.
---
--- @param statKey string
--- @return string
function Export.HeaderName(statKey)
    local out = tostring(statKey):gsub("(%l)(%u)", "%1_%2")
    return out:lower()
end

--- One CSV field, RFC-4180 quoted: wrapped when it contains a comma, a quote, a
--- CR or an LF, with embedded quotes doubled.
---
--- This is the LAUNDERING POINT of the whole file. Everything upstream of it may
--- be an opaque meter handle; everything downstream is a plain Lua string, which
--- is why the row assembly below is allowed to use table.concat at all.
---
--- The CanAccess guard is the per-value half of the combat rule. `tostring` on a
--- secret answers a secret string rather than raising, and a secret string
--- poisons the `find` and the `gsub` on the next two lines — so the value is
--- asked first and a blank field is the answer when it says no. A blank cell in
--- a race is a cost worth paying for a serializer that cannot error.
---
--- @param v any     a plain value, or an opaque meter handle, or nil
--- @return string
function Export.CsvField(v)
    if v == nil then return "" end
    local Secrets = mod("Secrets")
    if Secrets and Secrets.CanAccess and not Secrets.CanAccess(v) then return "" end
    local s = tostring(v)
    if s:find('[,"\r\n]') then s = '"' .. s:gsub('"', '""') .. '"' end
    return s
end

--- The stat half of the CSV column set, in catalog order.
---
--- Three kinds, and the reason each exists:
---   * `total` — one per stat, always. The raw amount.
---   * `rate`  — one per `isRate` stat and no others, suffixed `_ps`. A
---               per-second figure for Deaths or Interrupts is nonsense, and an
---               always-blank column is worse than an absent one.
---   * `pct`   — one per stat, suffixed `_pct`. Blank rather than absent when the
---               share cannot be computed (a counted stat has no column total,
---               and no stat has one mid-pull), because a spreadsheet's columns
---               must line up between two exports of different fights.
---
--- Each entry carries the same three facts twice: positionally, for the terse
--- `for _, c in ipairs` walk the serializer does, and by name, so a call site
--- that wants one of them reads as prose.
---
--- @return table  array of { header, statKey, kind } / { header=, statKey=, kind= }
function Export.Columns()
    local columns = {}
    local function add(header, statKey, kind)
        columns[#columns + 1] = {
            header, statKey, kind,
            header = header, statKey = statKey, kind = kind,
        }
    end

    for _, stat in ipairs(Const.STATS) do
        local base = Export.HeaderName(stat.key)
        add(base, stat.key, "total")
        if stat.isRate then add(base .. "_ps", stat.key, "rate") end
        add(base .. "_pct", stat.key, "pct")
    end

    return columns
end

-- The identity columns every row leads with. Session and duration ride on EVERY
-- row rather than sitting in a preamble on purpose: two exports concatenated in
-- one sheet then still mean something, and a pivot table can group by fight
-- without anyone hand-editing the file first.
local LEAD_HEADERS = { "session", "duration", "name", "class", "spec", "role" }

--- The window config an export is built from: every stat in the catalog, the
--- invoking window's segment, and the aggregator's own row ceiling.
---
--- Deliberately NOT the window's own config. What is on screen is a display
--- choice — three columns, sorted by damage, capped at ten rows — and none of
--- that is what someone asking for "the data" means. The segment IS inherited,
--- because "export this" said while looking at last pull means last pull.
---
--- `sortColumn` is an argument rather than always the window's, so Print to Chat
--- can rank by the metric it is about to print. Ranking happens here, in the
--- aggregator, where comparing two values is legal; nothing below ever sorts.
---
--- @param win table|nil            a Window instance or config
--- @param sortColumn string|nil    override the window's sort column
--- @return table  a synthetic window config for Aggregator.Build
function Export.SessionConfig(win, sortColumn)
    local cfg  = cfgOf(win)
    local data = cfg.data or {}

    local columns = {}
    for _, stat in ipairs(Const.STATS) do
        columns[#columns + 1] = { stat = stat.key, enabled = true }
    end

    if sortColumn == nil or Const.STAT_BY_KEY[sortColumn] == nil then
        sortColumn = data.sortColumn
    end
    if sortColumn == nil or Const.STAT_BY_KEY[sortColumn] == nil then
        sortColumn = Const.STATS[1] and Const.STATS[1].key
    end

    return {
        -- A string id, where a window's is a number. It never enters the
        -- registry — it exists so the rows the aggregator stamps say where they
        -- came from if one ever turns up in a log.
        id      = "export",
        columns = columns,
        -- MAX_ROWS is the aggregator's hard ceiling anyway; naming it here makes
        -- the 40-row truncation a documented property of an export rather than
        -- something a reader has to find in ApplyRowLimit.
        rows    = { maxRows = Const.MAX_ROWS },
        data    = {
            sessionType   = data.sessionType or Const.SESSION_TYPE.Current,
            sessionID     = data.sessionID,
            sortColumn    = sortColumn,
            sortMode      = "value",
            sortAscending = false,
            -- Addon-wide (defaults/Profile.lua's NS.DataSetting), so an export
            -- merges pets exactly as the grid it was taken from does.
            mergePets     = NS.DataSetting and NS.DataSetting("mergePets") or false,
        },
    }
end

--- Build the data an export renders.
---
--- @param win table|nil            a Window instance or config
--- @param sortColumn string|nil    rank by this stat instead of the window's
--- @return table|nil  an Aggregator.Build result, or nil with no aggregator
function Export.Build(win, sortColumn)
    local Aggregator = mod("Aggregator")
    if not (Aggregator and Aggregator.Build) then return nil end
    return Aggregator.Build(Export.SessionConfig(win, sortColumn))
end

--- What to call the segment being exported.
---
--- Asked of the WINDOW, never of the provider: naming a stored session means
--- matching an id against the session list, and this file is not allowed near
--- that API (rule R1). A window instance already answers the question for its
--- own header, so the instance answers it here too; a bare config falls back to
--- the two names a config can produce on its own.
---
--- pcall'd because SessionLabel reaches through a collaborator that a degraded
--- install may not have, and a missing label must cost an export nothing.
---
--- @param win table|nil
--- @return string
function Export.SessionLabel(win)
    if type(win) == "table" and type(win.SessionLabel) == "function" then
        local ok, label = pcall(win.SessionLabel, win, false)
        -- No `~= ""`: that is a comparison, and a window's label is a string
        -- built from a session name the meter may be hiding. type() is the whole
        -- test the answer needs.
        if ok and type(label) == "string" then return label end
    end

    local data = cfgOf(win).data or {}
    if data.sessionID ~= nil then return L["Segment"] end
    if data.sessionType == Const.SESSION_TYPE.Overall then return L["Overall"] end
    return L["Current"]
end

--- A cell's percentage as a bare two-decimal number, or "".
---
--- NOT Format.Percent, which appends a "%" — a spreadsheet wants a number it can
--- average. `cell.percent` is already scaled 0..100 and is computed by the
--- aggregator only when the comparison behind it was legal, so it is a plain
--- number or nil; the guards below are for the nil and for the impossible.
---
--- @param cell table|nil
--- @return string
local function percentField(cell)
    local pct = cell and cell.percent
    if type(pct) ~= "number" then return "" end
    return string.format("%.2f", pct)
end

--- A duration as raw whole seconds, for a spreadsheet. "" when it is missing or
--- cannot be looked at.
---
--- @param seconds any
--- @return string
local function durationField(seconds)
    if seconds == nil then return "" end
    local Secrets = mod("Secrets")
    if Secrets and Secrets.CanAccess and not Secrets.CanAccess(seconds) then return "" end
    if type(seconds) ~= "number" then return "" end
    return string.format("%d", math.floor(seconds + 0.5))
end

--- An Aggregator.Build result as CSV text.
---
--- Pure CSV: no preamble, no comment line, CRLF endings and a trailing CRLF, so
--- it pastes into a sheet without anyone deleting a header block first.
---
--- Refuses outright while the Combat restriction is active — see the file
--- header. The refusal is an EMPTY STRING rather than nil so a caller that hands
--- the answer straight to an EditBox cannot be the thing that errors; the reason
--- rides on the second return for a caller that wants to say why.
---
--- @param result table|nil   an Aggregator.Build result
--- @param session string|nil the segment's name, for the leading column
--- @return string csv, string|nil reason
function Export.CSV(result, session)
    local ok, reason = Export.Available()
    if not ok then return "", reason end
    if type(result) ~= "table" then return "", nil end

    local columns = Export.Columns()

    local header = {}
    for i, name in ipairs(LEAD_HEADERS) do header[i] = name end
    for _, column in ipairs(columns) do header[#header + 1] = column.header end

    local lines = { table.concat(header, ",") }

    -- `result.rows` and `result` are the same table in a normal build; the
    -- degenerate "no config" build returns a `rows` that is a separate empty
    -- array. Reading the field first is correct for both.
    local rows     = result.rows or result
    local session_ = Export.CsvField(session)
    local duration = Export.CsvField(durationField(result.durationSeconds))

    for _, row in ipairs(rows) do
        local cells = {
            session_,
            duration,
            Export.CsvField(row.name),
            Export.CsvField(row.classFilename),
            Export.CsvField(row.specIconID),
            Export.CsvField(row.role),
        }

        for _, column in ipairs(columns) do
            -- An absent cell is the COMMON case, not an error: most players have
            -- no row in Dispels, Interrupts or Deaths. It exports as blank.
            local cell = row.values and row.values[column.statKey]
            local value
            if column.kind == "pct" then
                value = percentField(cell)
            elseif column.kind == "rate" then
                value = cell and cell.rate
            else
                value = cell and cell.total
            end
            cells[#cells + 1] = Export.CsvField(value)
        end

        -- table.concat is legal here and nowhere near a meter value: every entry
        -- came out of CsvField, which answers a plain string or "".
        lines[#lines + 1] = table.concat(cells, ",")
    end

    return table.concat(lines, "\r\n") .. "\r\n", nil
end

--- One player's name, as a string safe to concatenate into a chat line.
---
--- `row.name` is ConditionalSecret — the roster's answer is plain, the meter's
--- fallback is not — so it is asked twice before it is used: CanAccess for "may
--- this context look at it", IsConcatSafe for "will `..` survive it". Out of
--- combat both say yes and this is one tostring; mid-pull neither is reached,
--- because ChatLines refuses before it gets here.
---
--- @param row table
--- @return string
local function displayName(row)
    local name = row.name
    if name == nil then return L["Unknown"] end

    local Secrets = mod("Secrets")
    if Secrets and Secrets.CanAccess and not Secrets.CanAccess(name) then
        return L["Unknown"]
    end
    if NS.IsConcatSafe and not NS.IsConcatSafe(name) then
        return NS.SafeToString and NS.SafeToString(name) or L["Unknown"]
    end
    return tostring(name)
end

--- The first line of a chat dump: addon, metric, segment and duration.
---
--- Built with `..` rather than table.concat, which is the house rule for any
--- string a meter value can reach: concat raises on a secret where `..` is on
--- the permitted list, and a formatter can hand back a handle rather than a
--- string on a client we have not met yet.
---
--- Each half of the title is independently optional and losing one may only lose
--- itself: a session that is not a string drops its own segment, a result with no
--- `durationSeconds` (or a formatter with no Duration) drops the parenthetical,
--- and the addon-and-metric stem is always there.
---
--- @param result table       an Aggregator.Build result
--- @param stat table         the catalog stat being printed
--- @param session string|nil the segment's name
--- @param F table            the formatter table
--- @return string
local function chatHeader(result, stat, session, F)
    local head = L["Multi Meters"] .. EM_DASH .. (L[stat.label] or stat.label)
    -- `type()` is permitted on a secret and `..` is permitted on one; asking
    -- whether it is the empty string is not. Window never answers "" anyway.
    if type(session) == "string" then
        head = head .. EM_DASH .. session
    end
    -- DECIDED FROM THE PLAIN INPUT, never from the formatter's answer. Duration
    -- can hand back a secret string, and `~= ""` on one is a comparison — which
    -- is on the forbidden list even though `..` two lines up is not.
    -- modules/Window.lua's DurationText makes the same distinction.
    local seconds = result.durationSeconds
    if seconds ~= nil and F.Duration then
        head = head .. " (" .. F.Duration(seconds) .. ")"
    end
    return head
end

--- One ranked line: "3. Kaosz 4.8M (240.1K, 31.2%)".
---
--- A row with no cell for this stat is still named and still ranked — the amount
--- is whatever F.Number makes of nil — because a dump that silently skips a rank
--- reads as a missing player rather than as a missing figure.
---
--- @param index number  the rank, which is the aggregator's order
--- @param row table     one Aggregator.Build row
--- @param stat table    the catalog stat being printed
--- @param F table       the formatter table
--- @return string
local function chatLine(index, row, stat, F)
    local cell = row.values and row.values[stat.key]
    local line = index .. ". " .. displayName(row) .. " "
        .. F.Number(cell and cell.total)

    -- The parenthetical carries whatever is meaningful and nothing else: no
    -- per-second figure for a counted stat, no share when the aggregator
    -- could not compute one. An empty "( )" would be noise on every line of
    -- a Deaths dump.
    -- `hasExtra` rather than `extra ~= ""`, for the same reason the duration
    -- in the header is decided from its input: a formatter may have put a secret
    -- string into `extra`, and reading one back to ask whether it is empty is
    -- a comparison. The boolean knows the answer without looking.
    local extra, hasExtra = "", false
    if stat.isRate and cell and cell.rate ~= nil and F.Rate then
        extra, hasExtra = extra .. F.Rate(cell.rate), true
    end
    if cell and type(cell.percent) == "number" and F.Percent then
        if hasExtra then extra = extra .. ", " end
        extra, hasExtra = extra .. F.Percent(cell.percent), true
    end
    if hasExtra then line = line .. " (" .. extra .. ")" end

    return line
end

--- An Aggregator.Build result as a short ranked list for chat.
---
--- The first line names the addon, the metric, the segment and its duration; the
--- rest are ranked entries. Abbreviated numbers here, unlike the CSV — chat
--- wants "4.8M", and nobody reads a nine-digit figure out of a scrolling frame.
---
--- The RANK IS THE ORDER THE AGGREGATOR RETURNED. Nothing here sorts: comparing
--- two meter values is the operation the restriction forbids, and the aggregator
--- has already done it under its own guards. Rank by a different stat by asking
--- Export.Build for that sort column.
---
--- Refuses to the empty array while restricted, for the reason in the header.
---
--- @param result table|nil    an Aggregator.Build result
--- @param statKey string|nil  which stat to print; defaults to the first catalog stat
--- @param limit number|nil    how many ranked lines; clamped 1..MAX_ROWS, default 5
--- @param session string|nil  the segment's name, for the header line
--- @return table  array of strings, possibly empty
function Export.ChatLines(result, statKey, limit, session)
    if not Export.Available() then return {} end
    if type(result) ~= "table" then return {} end

    local stat = Const.STAT_BY_KEY[statKey] or Const.STATS[1]
    if not stat then return {} end

    limit = tonumber(limit) or 5
    if limit < 1 then limit = 1 end
    if limit > Const.MAX_ROWS then limit = Const.MAX_ROWS end

    local F = fmt()
    if not F then return {} end

    local lines = { chatHeader(result, stat, session, F) }
    local rows  = result.rows or result

    for index, row in ipairs(rows) do
        if index > limit then break end
        lines[#lines + 1] = chatLine(index, row, stat, F)
    end

    return lines
end

-- ---------------------------------------------------------------------------
-- Channels
-- ---------------------------------------------------------------------------

--- One row out of the channel catalog, by key.
---
--- @param key string|nil
--- @return table|nil
local function channelRow(key)
    if key == nil then return nil end

    -- The BY_KEY map first: core/Constants.lua builds it from the array so the
    -- two cannot disagree, and it names this module as the consumer it exists
    -- for. The scan below is the degraded path only — a load where the map is
    -- absent but the array is not — rather than a second lookup with its own
    -- opinion about what a key means.
    local byKey = Const.EXPORT_CHANNEL_BY_KEY
    if type(byKey) == "table" then return byKey[key] end

    local catalog = Const.EXPORT_CHANNELS
    if type(catalog) ~= "table" then return nil end
    for _, row in ipairs(catalog) do
        if row.key == key then return row end
    end
    return nil
end

--- Who the player currently has targeted, as a name a whisper can be addressed to.
---
--- THE POINT OF THE "Whisper my target" CHANNEL. It is not a mode of the Whisper
--- row: the two differ in where the name comes from — a box the player types
--- into, or the game — and that is the whole feature. Clicking a name in the
--- grid and pressing the glyph beats typing "Kaosz-Draenor" correctly.
---
--- READ AT SEND TIME, never stored. A remembered target is a name that was true
--- when the modal was opened and is a stranger by the time the button is pressed.
---
--- GetUnitName with `showServerName` is what qualifies a cross-realm target as
--- Name-Realm, which is the form a whisper needs; UnitName drops the realm and
--- would address the whisper to whoever holds that name on THIS realm. It falls
--- back to UnitName only where the client has no GetUnitName at all.
---
--- The two refusals are separate strings because they are separate mistakes:
--- nothing targeted at all, and a target that cannot read a whisper.
---
--- @return string|nil name, string|nil reason  exactly one is non-nil
function Export.TargetName()
    local exists = _G.UnitExists
    if exists and not exists("target") then
        return nil, L["You have no target to whisper to."]
    end

    local isPlayer = _G.UnitIsPlayer
    if isPlayer and not isPlayer("target") then
        return nil, L["Your target is not a player."]
    end

    local get = _G.GetUnitName
    local name = get and get("target", true)
    if type(name) ~= "string" or name == "" then
        local plain = _G.UnitName
        name = plain and plain("target")
    end
    if type(name) ~= "string" or name == "" then
        return nil, L["You have no target to whisper to."]
    end

    return name, nil
end

--- Turn a stored channel choice into the pair SendChatMessage wants.
---
--- SELF answers nil, and that is why it is the default: a misclick on a modal
--- that defaulted to RAID is a wipe-night apology, while a misclick on SELF is
--- three lines in your own chat frame.
---
--- AUTO IS RETIRED and is named here anyway. It used to resolve itself at send
--- time and was removed as ambiguous (core/Constants.lua's catalog comment says
--- why); core/Database.lua's v3 -> v4 step folds the stored key to SELF. This
--- line is for the profile that arrives afterwards from a copy or a hand edit:
--- without it the fallback below would hand SendChatMessage a chat type of
--- "AUTO", which is not one.
---
--- Anything else uses the catalog row's chatType when there is one and the key
--- itself otherwise; the keys ARE the chat types ("SAY", "PARTY", "GUILD"), so
--- this keeps working on a load where core/Constants.lua's catalog is missing.
---
--- @param channel string|nil  a key from Const.EXPORT_CHANNELS
--- @param target string|nil   the whisper recipient, for WHISPER
--- @return string|nil chatType, string|nil target
function Export.ResolveChannel(channel, target)
    if type(channel) ~= "string" or channel == "" then channel = "SELF" end
    channel = channel:upper()

    if channel == "SELF" then return nil, nil end

    -- The recipient comes off the game rather than off the profile, and a
    -- missing one lands on the same "keep it to yourself" nil the empty box
    -- does. onPrintToChat asks FIRST, where there is a specific sentence to say
    -- about which of the two mistakes it was.
    if channel == "TARGET" then
        local name = Export.TargetName()
        if not name then return nil, nil end
        return "WHISPER", name
    end

    if channel == "WHISPER" then
        if type(target) ~= "string" then target = nil end
        if target then target = target:gsub("^%s+", ""):gsub("%s+$", "") end
        -- A whisper with nobody to whisper to is not an error to report at the
        -- send site; it is the same "keep it to yourself" SELF means.
        if not target or target == "" then return nil, nil end
        return "WHISPER", target
    end

    if channel == "AUTO" then return nil, nil end

    -- Everything past here is a plain channel, and every plain key in the
    -- catalog IS its own chat type ("SAY", "RAID", "GUILD"). SELF and WHISPER
    -- are the only two that are not, and both answered above.
    local row = channelRow(channel)
    return (row and row.chatType) or channel, nil
end

-- ---------------------------------------------------------------------------
-- Getting a dump past the server
-- ---------------------------------------------------------------------------
--
-- Two independent rules stand between a ranked list and the people meant to read
-- it, and they pull in opposite directions.
--
-- RULE ONE — THE FLOOD. The server rate-limits outbound chat. ChatThrottleLib,
-- which is the collection's reference for this, holds addon traffic to 800
-- characters a second after a 4000-byte burst, on the reading that ~2000 CPS is
-- safe and a sustained 3000 CPS disconnects you. Public channels are stricter
-- again and count MESSAGES rather than bytes: more than about three in quick
-- succession answers with "the number of messages that can be sent to this
-- channel is limited". A forty-line dump fired in one frame therefore arrives
-- truncated, at the one moment a truncated ranking is worst. Hence the stagger
-- below, and the extra second every CHAT_BATCH lines on top of it.
--
-- RULE TWO — THE HARDWARE EVENT. Since patch 8.2.5 SendChatMessage on SAY, YELL
-- and CHANNEL is only permitted from inside a hardware event — a real click or
-- keypress — with SAY and YELL exempted inside instances and CHANNEL never
-- exempted. A C_Timer callback is not a hardware event, so a staggered SAY dump
-- delivered the first line (sent inside the click) and SILENTLY dropped every
-- line after it. That was the bug: "print to Say only prints the header".
--
-- The two rules cannot both be honored, so the channel decides which one binds.
-- Where a hardware event is required the whole dump goes out inside the click,
-- flood risk and all, because a message that is rate-limited MIGHT arrive and a
-- message sent off a timer certainly will not. Everywhere else the stagger wins.
-- onPrintToChat warns before taking the burst path with more than one batch.

--- Chat types Blizzard restricts to hardware events.
local HARDWARE_EVENT_TYPES = { SAY = true, YELL = true, CHANNEL = true }

--- Must this chat type be sent from inside the click that asked for it?
---
--- CHANNEL always. SAY and YELL only OUTSIDE an instance: Blizzard's exemption
--- is exactly "SAY/YELL within instances", which covers the dungeon and raid
--- content this addon is read in, so the staggered path is the one a raid
--- actually takes and the burst is the open-world edge.
---
--- A client with no IsInInstance (the headless harness) is treated as outdoors,
--- which is the restrictive answer and the one that cannot invent a send.
---
--- @param chatType string|nil  a SendChatMessage chat type
--- @return boolean
function Export.NeedsHardwareEvent(chatType)
    if not HARDWARE_EVENT_TYPES[chatType] then return false end
    if chatType == "CHANNEL" then return true end
    local inInstance = _G.IsInInstance and _G.IsInInstance()
    return not inInstance
end

--- How many lines go out between two batch gaps.
--- @return number
function Export.ChatBatch()
    return CHAT_BATCH
end

--- How long after the click line `index` should go out.
---
--- CHAT_STAGGER between neighbours, plus one CHAT_BATCH_GAP for every whole
--- batch already sent. The batch gap is the answer to the public-channel rule
--- above: three-a-second is comfortably inside the byte budget and still trips
--- the "too many messages" counter on a long run, and a pause every fifth line
--- lets that counter drain. Line 1 is always 0 — a button that appears to do
--- nothing for a third of a second is a button people press twice.
---
--- Published so the arithmetic is checkable out of game; the timers themselves
--- are not.
---
--- @param index number  1-based line number
--- @return number  seconds
function Export.SendDelay(index)
    if type(index) ~= "number" or index < 2 then return 0 end
    local sent = index - 1
    return sent * CHAT_STAGGER + math.floor(sent / CHAT_BATCH) * CHAT_BATCH_GAP
end

-- Bumped by every send and by every cancellation, and captured by each queued
-- line. A line whose generation is stale simply does not send, which is how the
-- tail of a whisper dump is dropped the moment the server says there is nobody
-- by that name — without a timer handle per line to hold and cancel.
local sendGeneration = 0

-- The whisper dump currently in flight, or nil: { target, generation }. Read by
-- NoteSystemMessage below, which is the only thing that looks at it.
local pendingWhisper

--- The game's own "no such player" error, as a Lua pattern with the name captured.
---
--- Built from the client's ERR_CHAT_PLAYER_NOT_FOUND_S rather than from an
--- English literal, so it holds on a non-English client. Escaped first and
--- un-escaped at the `%s` second, in that order: doing it the other way round
--- would escape the capture group back into a literal.
---
--- @return string
local function playerNotFoundPattern()
    local template = _G.ERR_CHAT_PLAYER_NOT_FOUND_S
    if type(template) ~= "string" or template == "" then
        template = "No player named \"%s\" is currently playing."
    end
    local escaped = template:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    return "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
end

--- Drop everything still queued.
local function cancelQueue()
    sendGeneration = sendGeneration + 1
    pendingWhisper = nil
end

--- One CHAT_MSG_SYSTEM line, offered by core/MultiMeters.lua's fan-out.
---
--- WHY THIS IS A CALL AND NOT A SUBSCRIPTION. architecture-§4 gives
--- core/MultiMeters.lua every game event, and the choice left is whether the
--- system message reaches the bus. It does not, for the reason the feign filter
--- gives on the same page: republishing every system line in a raid to save one
--- string match here would cost more than the match, and the only reader is this
--- one. So the fan-out hands it over the way it hands a feign cast to
--- modules/Feign.lua, and the FILTER lives with the thing that cares.
---
--- Cheap in the common case on purpose: no whisper in flight is a nil test, and
--- that is what this is for every system message the player will ever see except
--- the handful that follow a mistyped name.
---
--- THE POINT IS THE TAIL, not the error itself. A twenty-line whisper to a name
--- nobody is playing is twenty identical system errors and no way to stop them;
--- catching the first drops the other nineteen and says once, in the addon's own
--- voice, what went wrong. The name is not checked BEFORE sending because there
--- is no client-side way to ask — only the server knows who is playing.
---
--- @param message string|nil  the system line
--- @return boolean  whether it was the error this watches for
function Export.NoteSystemMessage(message)
    local pending = pendingWhisper
    if not pending then return false end
    if pending.generation ~= sendGeneration then
        pendingWhisper = nil
        return false
    end
    if type(message) ~= "string" then return false end
    if not message:match(playerNotFoundPattern()) then return false end

    local target = pending.target
    cancelQueue()
    if NS.Print then
        NS.Print(L["There is nobody called '%s' to whisper to. The rest of the export was not sent."]
            :format(tostring(target)))
    end
    return true
end

--- Put a set of chat lines where the player asked for them.
---
--- SELF goes through NS.Print, which is the addon's prefixed chat printer and
--- reaches nobody else. Everything else goes through SendChatMessage one line at
--- a time — the API's 255-byte ceiling is per message, and no line built above
--- comes close, because every field in one is a formatted number or a player
--- name.
---
--- Falls back to printing when the client has no SendChatMessage at all (the
--- headless harness does not define one), so a test of the caller does not need
--- a stub to avoid an error. A client with no C_Timer sends everything at once,
--- which is the old behavior and still better than not sending.
---
--- @param lines table|nil     array of strings
--- @param channel string|nil  a key from Const.EXPORT_CHANNELS
--- @param target string|nil   the whisper recipient
--- @return boolean  whether anything was emitted
function Export.Send(lines, channel, target)
    if type(lines) ~= "table" or #lines == 0 then return false end

    local chatType, to = Export.ResolveChannel(channel, target)
    local send = chatType and _G.SendChatMessage

    -- LOCAL PRINTING IS NOT A SEND and is not throttled: NS.Print writes straight
    -- into the player's own chat frame, reaches nobody, and the server never
    -- sees it. This is also the path a client with no SendChatMessage takes, so
    -- an export there degrades to "printed to yourself" rather than to silence.
    if not send then
        if not NS.Print then return false end
        for _, line in ipairs(lines) do NS.Print(line) end
        return true
    end

    -- A new send supersedes whatever the last one still had queued.
    cancelQueue()
    local generation = sendGeneration

    local after = _G.C_Timer and _G.C_Timer.After
    -- Inside the click or not at all: see "Getting a dump past the server".
    if Export.NeedsHardwareEvent(chatType) or not after then
        for _, line in ipairs(lines) do send(line, chatType, nil, to) end
        return true
    end

    send(lines[1], chatType, nil, to)
    local last = #lines
    for i = 2, last do
        local line = lines[i]
        after(Export.SendDelay(i), function()
            if generation ~= sendGeneration then return end
            send(line, chatType, nil, to)
            -- The dump is over, so nothing is waiting on a system message any
            -- more. Disarming here rather than on a second timer keeps the two
            -- facts — "lines are still queued" and "a failure can still cancel
            -- them" — as one.
            if i == last then pendingWhisper = nil end
        end)
    end

    -- Armed only for a whisper, and only while its own lines are still queued:
    -- the error this watches for is the server's answer to a name nobody is
    -- playing, and it is worth catching exactly once per dump.
    if chatType == "WHISPER" then
        pendingWhisper = { target = to, generation = generation }
    end

    return true
end

-- ---------------------------------------------------------------------------
-- What modules/Export_Modal.lua reaches for
-- ---------------------------------------------------------------------------
--
-- Three file-locals above are read by BOTH halves, so the peel had to publish
-- them rather than copy them: a second EM_DASH or a second channel lookup is two
-- things to keep in step, which is exactly what the split must not create. The
-- `__` prefix is this file's existing spelling for a private published only
-- because something out of reach needs it (`Export.__geometry`,
-- `Export.__copyWindow`). They are not API: nothing outside this pair may read
-- them, and the modal resolves all three at FILE SCOPE, which is why its TOC line
-- has to sit after this one.
Export.__EM_DASH    = EM_DASH
Export.__cfgOf      = cfgOf
Export.__channelRow = channelRow
