Delta: LibKa0s v1.64.0 -> v1.65.0 (span: v1.64.0 v1.65.0)

# 01 — Delta: the consolidated span bundle

Written 2026-10-01 with GI-MM-RV. Step 3h's listing found two tags this addon vendored after
`2026-09-29-v1.63.0/` without a bundle of their own. Nothing is re-vendored by this bundle.

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)
# vendored: provenance tags at every payload commit and every CLAUDE.md roll since the horizon
# recorded: tags named by every docs/revendor/ folder (span folders: line 1 of 01_DELTA.md)
grep -vxF -f recorded.txt vendored.txt
```

Output: `v1.64.0`, `v1.65.0`.

The span's true base is v1.63.0, the provenance line before `1f6c6ad` (`git show 1f6c6ad^:CLAUDE.md`).
