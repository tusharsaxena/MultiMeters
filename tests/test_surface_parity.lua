-- tests/test_surface_parity.lua — the LibKa0s-absent Options stub carries the whole live surface.
--
-- settings/OptionsSetup.lua has two arms. Above the fork it builds a descriptor and hands it to
-- `lib:New(...)`; below it, for the install where `libs/LibKa0s` is missing, it hand-writes a table
-- that stands in for what `New` would have returned. That second table is a second implementation
-- of somebody else's surface, so it drifts the moment the library grows a member a page file starts
-- calling: the live path stays green and the degraded path raises in exactly the install the stub
-- exists for. Nine addons in this collection carry one of these arms, and the survey that produced
-- CX02 found the drift had already happened in a sibling — a stub missing `SetRenderer` outright,
-- with every suite in that repo green.
--
-- WHAT THIS ADDS THAT tests/test_degraded.lua DOES NOT. That suite's "the options stub publishes
-- every Helpers member the page files touch" case greps `H.Foo(` out of `settings/*.lua` and checks
-- the stub answers each one. That is a check against the addon's CALL SITES, and it is the right
-- shape for what it covers — but it can only see members this addon already calls. A member the
-- library publishes and the pages have not adopted yet is invisible to it, which means the day a
-- page starts calling one, the stub is silently a member short and nothing goes red until a player
-- with no LibKa0s opens the settings panel. This case is the other direction: it compares the stub
-- against the LIVE SURFACE, so a member arrives on the list the moment the library publishes it,
-- and stays there until this file says out loud why the stub does not carry it.
--
-- THE BY-NAME FORM. `T.assertSurfaceParity(stub, "LibKa0s-Options-1.0", ignore)` — kit 15, vendored
-- by M4-01. It looks the live half up rather than being handed one, and it compares only
-- `Kit.publicMembers`: LibStub's own MAJOR / MINOR / MODULES, and every `__`-prefixed key, are
-- dropped. Those are the library talking to itself across its own file boundary — `__AttachCompose`,
-- `__AttachWidgets`, `__print` — and a stub is obliged to carry none of them. The exemptions below
-- are therefore all HOST decisions; none of them is a library internal.
--
-- WHERE THE LIVE HALF COMES FROM, and why it is not the obvious place. `tests/run.lua` registers it
-- with `Kit.setSurfaceSource`. It has to: this stub mirrors an INSTANCE — what `lib:New(descriptor)`
-- returned, decorated in place by the page files — and not the library table LibStub answers for the
-- same name. Left to `Kit.expose`'s auto-wiring, which reaches for the mock's LibStub,
-- "LibKa0s-Options-1.0" resolves a four-member table (LAYOUT, New, PatchAlwaysShowScrollbar,
-- STRINGS) and this case goes red for three reasons that have nothing to do with the stub.
--
-- THE OTHER FIVE SEAMS ARE NOT HERE, and each has a reason rather than an omission:
--
--   * DebugLog — `tests/test_debuglogsetup.lua`'s "the stub carries the WHOLE live surface" already
--     compares the two instances, built by two real loads. Restating it here in the by-name form
--     would be one gate written twice, and the second copy is the one that goes stale.
--   * Perf — `core/PerfSetup.lua`'s stub covers EVERY MEMBER THE ADDON REACHES and deliberately no
--     more; the library's surface is the whole capture harness. Parity against it would demand a
--     stub for `Start`, `Measure`, `Save` and `FormatReport`, which is the duplicate `testing-§8`
--     forbids. `tests/test_degraded.lua` greps the reached set out of the addon instead, which is
--     the assertion that matches the contract.
--   * Core — the seam's two halves are two blocks of one file of ours, and what they have in common
--     is a set of names hung on NS, not a major's surface. There is no name to look up.
--   * Slash — `settings/Slash.lua` keeps its dispatcher as a file-scope local, so there is nothing
--     to compare without publishing an introspection member on shipped source. Out of CX02's scope,
--     which is the `settings/OptionsSetup.lua` arms; recorded rather than done.
--   * Widgets — `modules/Export.lua` reaches the library table directly and degrades by REFUSING to
--     open, not by standing in for a surface. There is no stub to check.

local T = _G.MULTIMETERS_TEST
local test, assertEqual = T.test, T.assertEqual

test("parity: the Options stub carries every public member of the live Helpers surface", function()
    -- The degraded half comes from a real load with `libs/LibKa0s` out of the load list, never from
    -- a hand-written stub — a hand-stub asserts the test author's typing (testing-§8).
    -- red under: dropping any name from settings/OptionsSetup.lua's no-op list, or degrading one to
    -- a non-function (`Helpers.Section = false`), which a plain "is the key set?" check waves past.
    local H = T.load{ libFiles = {} }.NS.Helpers
    assertEqual(type(H), "table", "the degraded load published no NS.Helpers at all")

    T.assertSurfaceParity(H, "LibKa0s-Options-1.0", {
        -- ── the composers, and the constants they publish ───────────────────────────────────────
        --
        -- Live-only ON PURPOSE, and this is the one exemption group that would look like a bug from
        -- the outside. This addon DOES use all five composers (options-ui-§15, §16) — but it does
        -- not reach them through `NS.Helpers`. settings/Schema.lua declares its rows BEFORE
        -- settings/OptionsSetup.lua has built an instance, so it takes the composers on a bare table
        -- of its own through `optlib.__AttachCompose(C)` and calls them off that (`:678-688`). With
        -- no library that attachment never happens, `compose()` answers `{}` and every composed
        -- block is empty — a documented deviation in docs/ARCHITECTURE.md, and the difference
        -- tests/test_degraded.lua measures row for row. A stub member here would have no caller.
        "MasterControls", "ColorPair", "BarGroup", "BorderGroup", "FontGroup",
        --
        -- The composers' published vocabularies. `grep -rn 'MASTER_GROUP\|CLASS_COLOR_NOTE\|
        -- FONT_FLAGS\|VISIBILITY_' core modules settings` returns nothing: the composers stamp
        -- these values onto the rows they emit, so nothing outside the library reads the tables
        -- themselves. A stub copy would be a copy with no reader and one re-vendor to go stale.
        "MASTER_GROUP", "CLASS_COLOR_NOTE", "FONT_FLAGS", "FONT_FLAGS_SORT",
        "VISIBILITY_SORT", "VISIBILITY_VALUES",

        -- ── lib.LAYOUT's scalars ────────────────────────────────────────────────────────────────
        --
        -- The stub's own header states the rule: "none of the library's LAYOUT constants. A host
        -- copy of a library constant is the copy that goes stale." None of the seven has a reader
        -- in this addon — `grep -rn 'ROW_VSPACER\|SECTION_HEADING_H\|BUTTON_PAIR_REL\|PADDING_X\|
        -- CHROME_GAP\|TAB_H\|BANNER_H' core modules settings` returns nothing — and every reader
        -- they could have sits behind an AceGUI a library-less build never gets.
        "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL", "PADDING_X",
        "CHROME_GAP", "TAB_H", "BANNER_H",

        -- ── the chrome blocks this addon does not draw ──────────────────────────────────────────
        --
        -- `grep -rn 'PageHeader\|SubTabStrip' core modules settings` returns nothing. The window
        -- pages draw their own banner (`Helpers.WindowBanner`, decorated by settings/Frame.lua and
        -- carried by the stub), and no tab of any page holds a list of like subjects that would
        -- earn a sub-strip. A stub member with no caller is a copy waiting to go stale; each joins
        -- the stub on the commit that gives it a caller.
        "PageHeader", "SubTabStrip",

        -- ── the panel machinery answered elsewhere ──────────────────────────────────────────────
        --
        -- `OpenOptionsPanel` is the one member a user actually reaches for, and the stub answers it
        -- on NS rather than on Helpers: `NS.OpenOptionsPanel` IS `NS.CreateOptionsPanel`, one honest
        -- "the settings panel is unavailable" line, because there is nothing to create and nothing
        -- to open. tests/test_degraded.lua exercises it there.
        "OpenOptionsPanel",

        -- The AceGUI handle the live panel stashes through the descriptor's `onAceGUI`. There is no
        -- AceGUI on the degraded path — that is the condition under test, not a divergence.
        "AceGUI",
    })
end)
