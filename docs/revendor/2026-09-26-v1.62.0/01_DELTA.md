# LibKa0s v1.61.0 -> v1.62.0: the delta (MultiMeters)

Copied from the tag `v1.62.0` (`e660362`) with `git -C ../LibKa0s archive v1.62.0 LibKa0s testkit`,
never from a working tree.

## Claimed and actual version, before the copy

`grep -n '[Bb]undles' CLAUDE.md` read v1.61.0, and the vendored minors matched v1.61.0 file for file
(Options 25, OptionsWidgets 31, OptionsTabs 5, OptionsNav 1): no skew.

## libs/LibKa0s (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/LibKa0s/LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
Files <tag>/LibKa0s/Options.lua and libs/LibKa0s/Options.lua differ
Only in <tag>/LibKa0s: OptionsCombat.lua
Only in <tag>/LibKa0s: OptionsIdList.lua
Only in <tag>/LibKa0s: OptionsIds.lua
Only in <tag>/LibKa0s: OptionsRegistry.lua
Files <tag>/LibKa0s/OptionsTabs.lua and libs/LibKa0s/OptionsTabs.lua differ
Files <tag>/LibKa0s/OptionsWidgets.lua and libs/LibKa0s/OptionsWidgets.lua differ
```

The byte diff (`diff -rq`, no strip) named the same files: nothing differed by line ending alone.

- `Options.lua`: minor 25 -> 26. The page registry and the registration park move out to `OptionsRegistry.lua`; the shell calls `lib.__AttachRegistry(O, d)` where they stood.
- `OptionsRegistry.lua`: new, minor 1. `O.RegisterOptionsPage`, `O.__pages`, `O.CreateOptionsPanel`, `O.OpenOptionsPanel`, unchanged.
- `OptionsWidgets.lua`: minor 31 -> 32. The id surface moves out; it calls `lib.__AttachIds` and `lib.__AttachIdList`.
- `OptionsIds.lua`: new, minor 1. `O.ResolveId`, `O.UnnamedCandidates`, `O.ID_NAME_HINT`, `O.IdInput`, unchanged.
- `OptionsIdList.lua`: new, minor 1. `O.IdList`, unchanged.
- `OptionsTabs.lua`: minor 5 -> 6. The combat lock's page chrome moves out; it calls `lib.__AttachCombat(O)`.
- `OptionsCombat.lua`: new, minor 1. `O.__buildCover`, `O.__releaseOwnedFocus` and the page-scoped combat events, unchanged.
- `LibKa0s.xml`: loads the four new files, each right after the file it left.
- The Options major key moves from `25.31.5.7.4.1` to `26.1.32.1.1.6.1.7.4.1`. Every other file is unchanged.

## tests/_kit (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/testkit/README.md and tests/_kit/README.md differ
Files <tag>/testkit/framework.lua and tests/_kit/framework.lua differ
Only in <tag>/testkit: inventory.lua
Only in <tag>/testkit: prose_coverage.lua
Only in <tag>/testkit: prose_selftests.lua
Files <tag>/testkit/run-automated-tests.sh and tests/_kit/run-automated-tests.sh differ
Files <tag>/testkit/test_layout_cap.lua and tests/_kit/test_layout_cap.lua differ
Files <tag>/testkit/test_prose.lua and tests/_kit/test_prose.lua differ
```

`grep -n 'Kit.VERSION'`: kit revision 27 -> 31. Revision 28 peels the suite inventory to
`inventory.lua`; 29 peels the prose gate to `prose_coverage.lua` and `prose_selftests.lua`; 30 prints
`None.` under an empty watch-list table (ATS-20); 31 drops `Kit.layoutCap.exempt` files from the band
table (ATS-21). Both payloads are copied whole in one commit, so the pairing rule holds by construction.

## Consumption map

`git grep -noE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' -- '*.lua' ':!libs' ':!tests'`: Options
is looked up in `settings/OptionsSetup.lua` and `settings/Schema_Compose.lua`. It is the only major
that moved a minor.

## Contract delta

None. The changelog states no member, descriptor field or row field changes, and every moved member
is attached to the instance at the point it used to be defined, in the same order. The degraded stub's
surface-parity case (`tests/test_surface_parity.lua`) stays green with no stub change.
