# LibKa0s v1.62.0 -> v1.63.0: the delta (MultiMeters)

Copied from the tag `v1.63.0` (`dd7a774`) with `git -C ../LibKa0s archive v1.63.0 LibKa0s testkit`,
never from a working tree.

## Claimed and actual version, before the copy

`grep -n '[Bb]undles' CLAUDE.md` read v1.62.0. The last commit to touch either payload
(`git log -1 -- libs/LibKa0s tests/_kit`, `bdda70b`) left the same line, and the payload matched the
library at `v1.62.0` byte for byte (`diff -rq` against `git archive v1.62.0`, both folders, printed
nothing): no skew. `Slash.lua` was minor 16. The span walk (`docs/revendor` horizon 2026-08-25,
vendored tags against recorded bundles) printed no unrecorded tag, so there is no span bundle.

## libs/LibKa0s (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/LibKa0s/Slash.lua and libs/LibKa0s/Slash.lua differ
```

The byte diff (`diff -rq`, no strip) named the same file: nothing differed by line ending alone.

- `Slash.lua`: minor 16 -> 17. The `profile` verb's behavior: the `profiles` descriptor field, the
  instance members `CliProfile` and `ProfileSwitch`, the lib-level `lib.ProfileNames`, and nine
  `PROFILE_*` keys in `lib.STRINGS`. `lib.LIVE_VERBS` is unchanged, and `profile` is not reserved.
- `git -C ../LibKa0s diff --stat v1.62.0 v1.63.0 -- LibKa0s testkit`: `LibKa0s/Slash.lua`, 130
  insertions, 1 deletion. Every other file is unchanged.

## tests/_kit (`diff -rq --strip-trailing-cr`, before the copy)

Empty. `grep -n 'Kit.VERSION'`: kit revision 31 on both sides. Both payloads are copied whole in one
commit anyway, so the pairing rule holds by construction.

## Consumption map

`git grep -noE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' -- '*.lua' ':!libs' ':!tests'`: Slash is
looked up once, in `settings/Slash.lua`. It is the only major that moved a minor.

## Contract delta

None. `docs/api/Slash/version-17-docs.md` ("Compatibility") states that no runtime behavior moves: a
host that passes no `profiles` and registers no `profile` row sees no change. The code diff adds
members and strings and changes no existing function. The one gate the document names as able to go
red on the copy alone, a by-name `T.assertSurfaceParity(<stub>, "LibKa0s-Slash-1.0")` case, does not
exist here: `tests/test_surface_parity.lua` records why Slash has no parity case (the dispatcher is a
file-scope local). The suite stays green on the copy with no stub change (see `05_SUMMARY.md`).
