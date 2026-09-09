-- tests/mock_secrets.lua
--
-- The SECRET SIMULATOR, peeled out of tests/wow_mock.lua when that file passed
-- layout-§1's 1500-line cap (issue #34). It is loaded from there and nowhere
-- else, it is NOT a suite, and tests/run.lua's SUITES list must not gain an entry
-- for it -- Kit.assertSuiteInventory asserts that list against tests/test_*.lua in
-- both directions and this file is neither declared nor named like a case.
--
-- ONE REGISTRY, PROCESS-WIDE, AND THAT IS DELIBERATE. `plainOf` and `secretTables`
-- are file-local weak-keyed tables, so every build() shares them; a secret minted
-- under one mock instance is still recognized as one under the next. That was true
-- before the peel and it stays true, which is why this file is dofile'd once by the
-- builder rather than re-loaded per build: two copies of this chunk would mean two
-- registries, and `mocks.reveal(fs.__text)` would answer the wrapper instead of the
-- value the moment a fixture crossed between them.
--
-- Publishes: SECRET_ERROR · secret(v) · secretTable(t) · isSimulatedSecret(v) ·
-- isSimulatedSecretTable(t) · reveal(v) · newStringLibrary().
--
-- ---------------------------------------------------------------------------
-- THE SECRET SIMULATOR — the most valuable thing in this file
-- ---------------------------------------------------------------------------
--
-- While WoW 12.0's Combat addon restriction is active, every number this addon
-- displays arrives as a SECRET VALUE. Tainted code — all of ours — may store one,
-- pass it, put it in a table VALUE, hand it to StatusBar:SetValue /
-- FontString:SetText, and hand it to a native formatter. It may NOT compare it,
-- do arithmetic on it, boolean-test it, use it as a table KEY, apply `#` to it,
-- or index it.
--
-- `mocks.secret(v)` returns a TABLE whose metatable raises a recognizable error
-- from every one of those forbidden operations, so an illegal line anywhere in
-- the addon fails the test LOUDLY instead of quietly passing on a plain number.
-- That is the whole point: without it, a suite that "proves" the never-inspect
-- rule proves nothing, because a plain number satisfies every assertion a secret
-- would have failed.
--
-- WHAT CANNOT BE TRAPPED IN LUA 5.1, stated rather than pretended:
--
--   * `__eq` is only consulted when BOTH operands are tables of the same
--     metatable. `secret == nil`, `secret == 0` and `secret == "x"` are answered
--     false by the VM without any metamethod running. That is fine — nil-ness
--     testing is the one permitted boolean-shaped operation on a non-boolean
--     secret, and it is what modules/Row.lua and modules/Format.lua rely on — but
--     it does mean an ILLEGAL `secret == someOtherValue` cannot be caught here.
--   * TRUTH TESTING (`if secret then`, `secret and x`, `not secret`) has no
--     metamethod in any Lua version. A table is always truthy, so
--     `if src.totalAmount then` passes here and raises in the client. There is no
--     way to close that from Lua; the guard against it is review and the
--     `== nil` idiom the source files use everywhere.
--   * `__len` IS DEFINED BELOW AND LUA 5.1 IGNORES IT. In 5.1 the length operator
--     consults a metamethod only for userdata, never for a table, so `#secret`
--     quietly answers 0 here and raises in the client. The metamethod is kept so
--     the trap becomes live the day this harness moves to 5.2+, and because a
--     reader looking for "is `#` covered?" should find an answer rather than a
--     silence — but `#` is NOT a caught mistake today. The real defense is
--     core/Secrets.lua's SafeIterate / SafeCount, which never apply the operator
--     at all, and `mocks.secretTable(t)` below, whose INDEXING trap does fire and
--     therefore catches any walk that skipped the CanAccessTable guard.
--   * A SECRET USED AS A TABLE KEY is legal Lua and cannot be trapped: `t[secret]`
--     is an ordinary hash lookup on a table reference. The addon's defense is
--     structural — modules/Aggregator.lua joins on `sourceGUID`, which is the one
--     field the client never makes secret, and the mock never wraps it.
--   * A MIXED-TYPE COMPARISON (`secret < 5`) raises, but with Lua's own "attempt
--     to compare number with table" rather than the tagged message: the VM
--     rejects the operand types before any metamethod runs. Two secrets compared
--     against each other do reach `__lt` / `__le` and produce the tagged error.
--     Either way it fails loudly, which is the point; a suite matching on
--     `mocks.SECRET_ERROR` should use two secrets.
--   * `type(secret)` answers "table", where the client answers the underlying
--     type. Every `type(x) ~= "number"` guard in modules/Aggregator.lua and
--     modules/Format.lua therefore takes its REFUSAL branch under simulation,
--     which is the behavior those guards exist to produce while restricted — so
--     the divergence lands on the correct side.
--   * `string.format("%s", secret)` and `tostring(secret)`: the client permits
--     both (they yield a secret STRING). Lua 5.1's `string.format` calls
--     `luaL_checklstring`, which does not honor `__tostring` and raises on a
--     table. Rather than pretend, this file publishes `mocks.string` — a
--     pass-through of the real string library whose `format` substitutes each
--     simulated secret with the value behind it — and `mocks.format` alongside
--     it. Addon chunks resolve `string` and `format` through the loader
--     environment, so they get the faithful behavior; nothing else in the process
--     is touched.
--   * `table.concat` REALLY DOES raise on a table element in stock Lua 5.1, with
--     no help from this file. That is the exact probe core/CoreSetup.lua's
--     IsConcatSafe uses, so the degradation path it guards is genuinely
--     exercised.
--
-- `__concat` IS trapped, which is stricter than the live client (where `..` on a
-- secret yields a secret string). It is trapped deliberately: `..` is the one
-- forbidden-adjacent operation a well-meaning refactor reaches for, every call
-- site in this addon that concatenates a possibly-secret value already guards it
-- (`pcall` in modules/Format.lua, `NS.IsConcatSafe` in modules/Row.lua), and a
-- trap there turns "somebody removed the guard" into a failing test.

-- ===========================================================================
-- The secret simulator
-- ===========================================================================

-- The marker every trap message carries. Suites match on this rather than on a
-- full message so the wording can be improved without breaking a case.
local SECRET_ERROR = "MOCK_SECRET_VIOLATION"

--- The plain value behind a simulated secret. A separate weak-keyed registry
--- rather than a field on the object, because `__index` is trapped and the
--- object therefore cannot be read from at all.
local plainOf = setmetatable({}, { __mode = "k" })

--- Tables that report as SECRET TABLES (issecrettable / canaccesstable), as
--- distinct from tables of secret values. Indexing one raises, which is what
--- makes core/Secrets.lua's CanAccessTable guard in SafeIterate provable.
local secretTables = setmetatable({}, { __mode = "k" })

local function trap(op)
    return function()
        error(SECRET_ERROR .. ": " .. op .. " on a secret value — tainted code may store, pass, "
            .. "table-value and widget-set a secret and may do nothing else (design rule R1)", 2)
    end
end

-- Every forbidden operation, and only those. `__eq` is absent on purpose: see the
-- header — the VM never consults it against nil or a number, and `== nil` is the
-- one test the addon is allowed to make.
local secretMeta = {
    __lt     = trap("<"),
    __le     = trap("<="),
    __add    = trap("+"),
    __sub    = trap("-"),
    __mul    = trap("*"),
    __div    = trap("/"),
    __mod    = trap("%"),
    __pow    = trap("^"),
    __unm    = trap("unary -"),
    __len    = trap("#"),
    __concat = trap(".."),
    __index  = trap("indexing"),
    -- Assignment is trapped too: a secret is not a container, and an addon that
    -- caches something onto one has confused a value for a table.
    __newindex = trap("field assignment"),
    -- Honored by tostring() but NOT by string.format in 5.1 (header).
    __tostring = function() return "<secret>" end,
}

local secretTableMeta = {
    __index    = trap("indexing a secret table"),
    __newindex = trap("assigning into a secret table"),
    __len      = trap("# on a secret table"),
    __tostring = function() return "<secret table>" end,
}

--- Wrap `v` so it behaves like a WoW 12.0 secret value.
---
--- nil passes through unchanged: "absent" and "present but opaque" are different
--- facts, and every consumer in this addon tells them apart with `== nil`.
local function secret(v)
    if v == nil then return nil end
    local s = setmetatable({}, secretMeta)
    plainOf[s] = v
    return s
end

--- Wrap `t` so it reports as a secret TABLE and raises on any index.
local function secretTable(t)
    local s = setmetatable({}, secretTableMeta)
    secretTables[s] = t or {}
    return s
end

local function isSimulatedSecret(v)
    return plainOf[v] ~= nil
end

local function isSimulatedSecretTable(t)
    return secretTables[t] ~= nil
end

--- The value behind a simulated secret, or the argument itself when it is plain.
--- This is what a NATIVE seam is allowed to do — the numeric rule formatter, a
--- StatusBar's C side — and what a suite uses to assert what a widget was handed.
local function reveal(v)
    local p = plainOf[v]
    if p ~= nil then return p end
    local t = secretTables[v]
    if t ~= nil then return t end
    return v
end

-- ===========================================================================
-- The string library that goes with them
-- ===========================================================================

--- A fresh `string` table (and the bare `format`) for one mock instance.
---
--- Lives here rather than in the builder because it is part of the simulator: it
--- exists only because Lua 5.1's `string.format` raises on a table where the
--- client happily formats a secret (see the header), and it is the one override
--- that has to know what `isSimulatedSecret` knows.
---
--- Built per call, so nothing an instance does to `mocks.string` reaches another.
---
--- @return table stringLib, function formatShim
local function newStringLibrary()
    local mockString = setmetatable({}, { __index = string })
    local function formatShim(fmt, ...)
        local n = select("#", ...)
        if n == 0 then return string.format(fmt) end
        local args = {}
        for i = 1, n do
            local v = select(i, ...)
            args[i] = isSimulatedSecret(v) and reveal(v) or v
        end
        return string.format(fmt, unpack(args, 1, n))
    end
    mockString.format = formatShim
    return mockString, formatShim
end

return {
    SECRET_ERROR             = SECRET_ERROR,
    secret                   = secret,
    secretTable              = secretTable,
    isSimulatedSecret        = isSimulatedSecret,
    isSimulatedSecretTable   = isSimulatedSecretTable,
    reveal                   = reveal,
    newStringLibrary         = newStringLibrary,
}
