# Decisions (MultiMeters)

- No adoption interview and no GitHub issue in this run. The re-vendor is step 1 of item SP-MM-02 of
  the 2026-09-29 smoke-rework and profile-verb plan
  (`Ka0sAddonsCommonTasks/docs/2026-09-29-SMOKE_REWORK_AND_PROFILE_VERB/`, spec S3), where the owner
  already decided the adoption (D1-D3).
- Adopted: only the Slash minor 17 profile surface, by the same item, in the commit after this one
  (`SP-MM-02: /mm profile via CliProfile`). That commit adds the `profile` row, the `profiles`
  descriptor field, `lib.LIVE_VERBS` plus `profile` as this host's `liveVerbs`, and `CliProfile` and
  `ProfileSwitch` on the degraded stub.
- Nothing else is adopted, because nothing else arrived.
