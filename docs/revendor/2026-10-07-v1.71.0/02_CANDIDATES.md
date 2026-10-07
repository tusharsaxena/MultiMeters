# 02 — Candidates (MultiMeters)

Sources: `git -C ../LibKa0s show v1.71.0:CHANGELOG.md` (the v1.71.0 block, "What a consumer owes"),
the delta in 01_DELTA.md, and the consumption map there.

- **Delivered on the copy (class A, nothing for the host to do):** `/mm set` refuses `nan` and the
  infinities on a number row (Slash 20.2); the `--list` Totals count only cases that run, with a
  `Skipped` row (kit 38); `Env.GetAddOnMetadata` reads `C_AddOns` only (Env 2).

## Not adopted in this run

No interview was held and no GitHub issue was filed (OWNER_SCOPE 5 for this remediation run): every
candidate below is recorded and left for a later, owner-led revendor pass.

- **`Kit.secret` / `Kit.installSecretValue()` (kit 38):** opt-in secret-value simulator.
  MultiMeters' tests carry their own `issecretvalue` stubs (`tests/wow_mock.lua`,
  `tests/test_secrets.lua`, `tests/test_compat.lua`); migrating them is optional and not done here.
- **`WidgetsLineChart` 3 (clip, hover re-sync, `ChartMath.ClipSegment`):** unused surface;
  MultiMeters draws no line chart.
- **`WidgetsAutocomplete` 2 (hooks re-installed per call, `maxRows` floored):** unused surface;
  MultiMeters has no autocomplete box.
- **`OptionsIdList` 4:** unused surface; MultiMeters' schema has no `IdList` row.
- **Dropping MultiMeters' own bare-global rung in `NS.Meta`'s library-absent branch** (the host
  counterpart of Env 2): owned by item MM-07 of this plan, not adopted here.
