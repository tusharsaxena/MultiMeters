Delta: LibKa0s v1.14.0 -> v1.54.2 (span: v1.14.0 v1.16.0 v1.17.0 v1.18.0 v1.18.1 v1.19.0 v1.20.0 v1.21.0 v1.22.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.43.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.54.2)

# 01 — Delta: the consolidated span bundle

Written 2026-09-24 for plan item MM-30 of the 2026-09-23 review and standards-audit remediation
(finding MultiMeters-A-19), on branch `feat/2026-09-23-review-audit-remediation`. It is the
sanctioned record for a lapsed span (`audit-review-history`, standard v2.65.0): one folder named for
the first and last unrecorded tags, holding `01_DELTA.md` and `05_SUMMARY.md` only. Nothing is
re-vendored here and no code changes. The per-tag deliberation files (02 to 04) are absent on
purpose, and no per-tag folders are back-filled: these tags arrived through collection sweeps, or
folded into feature commits, and whatever was decided about each was decided in its carrying commit,
which `05_SUMMARY.md` lists per tag.

## The true previous base

Line 1 names the first and last **unrecorded** tags, not a delta base. The span's first tag,
v1.14.0, was vendored at `b81f514` (2026-08-25 02:18) over a provenance line that named **v1.12.0**
(`git show b81f514^:CLAUDE.md`), so that is the true base of the span. The store's first bundle,
`docs/revendor/2026-08-25/`, records v1.15.0 (`f81b6d9`, the same morning), and it is also the
audit horizon. The next single-tag bundle, `docs/revendor/2026-09-23-v1.55.0/`, names v1.54.2 as its
base, which is `d2169d4`, the last tag in this span. That base is correct, and so are the bases of
every other earlier bundle (v1.24.0 -> v1.25.0, v1.29.0 -> v1.30.0, v1.30.0 -> v1.31.0 through
v1.33.0 -> v1.34.0, v1.55.0 -> v1.56.0), each cross-checked against the provenance history
`git log -- libs/LibKa0s tests/_kit` shows. No correction is owed to any frozen bundle.

Eight tags inside that range already have bundles and are not in the span list: v1.15.0
(`2026-08-25/`), v1.25.0 (`2026-09-03/`), v1.30.0 (`2026-09-12/`), v1.31.0, v1.32.0, v1.33.0
(`2026-09-12-v1.3x.0/`), v1.34.0 (`2026-09-13-v1.34.0/`) and v1.55.0 (`2026-09-23-v1.55.0/`).
v1.56.0 is recorded by the RV-MM bundle `2026-09-23-v1.56.0/`. Two bare-dated bundles name a second
tag on line 1 only as their base (v1.24.0 in `2026-09-03/`, v1.29.0 in `2026-09-12/`). The audit
reads only the last tag of a bare-dated line 1, so those two count as unrecorded and are listed
here. Those frozen bundles are not edited.

Tags the library cut that this addon never vendored are not in the span, because no commit here
carried them: v1.13.0, v1.40.0, v1.41.0, v1.46.0, v1.48.0, v1.48.1, v1.49.0, v1.49.1, v1.54.0 and
v1.54.1.

## How the list was derived

The `AUDIT.md` re-vendor comparison (WowAddonStandards v2.65.0) with the `revendor-libka0s` Step 3h
"rolled here" walk added, run before this bundle existed:

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)          # -> 2026-08-25
tag_at() {
  git show "$1:CLAUDE.md" 2>/dev/null |
    grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' |
    grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1
}
{ git log --since="$horizon 00:00" --format=%H -- libs/LibKa0s tests/_kit
  git log --since="$horizon 00:00" --format=%H -- CLAUDE.md | while read -r c; do
    [ "$(tag_at "$c")" != "$(tag_at "$c^")" ] && echo "$c"
  done
} | while read -r c; do tag_at "$c"; done | sed '/^$/d' | sort -uV > vendored.txt   # 42 tags
# recorded.txt: the recorded-side loop over docs/revendor/*/                          # 9 tags
grep -vxF -f recorded.txt vendored.txt                                                # 33 tags
```

Output: vendored is v1.14.0 through v1.56.0 (42 tags); recorded is v1.15.0, v1.25.0, v1.30.0 to
v1.34.0, v1.55.0 and v1.56.0; the difference is the 33 tags on line 1. The "rolled here" walk adds
no tag the payload walk missed: every provenance roll since the horizon sits in a commit that also
touched `libs/LibKa0s` or `tests/_kit`. After this bundle, the same comparison prints nothing.

**Correction to the item text.** MM-30 and the audit named 28 tags, v1.18.0 to v1.53.0, plus the
kit-only v1.54.2. That count dropped the horizon day's own commits: v1.14.0 (02:18), v1.16.0 and
v1.17.0 were all vendored on 2026-08-25, which a bare-date `--since` loses. The v2.65.0 comparison,
with `00:00` on the bound, finds 33 tags. The folder is named for the span it actually covers,
`2026-09-24-v1.14.0-v1.54.2`, not the item's expected `v1.18.0-v1.54.2`.

## The carrying commits

One row per tag, from `git log --format='%h %ad %s' --date=short -- libs/LibKa0s tests/_kit`, each
joined to the tag its `git show <sha>:CLAUDE.md` provenance line names. Where several commits carry
the same tag, the row names the one that rolled the provenance line, and the notes below name the
others. Payload: `lib` is `libs/LibKa0s/`, `kit` is `tests/_kit/`.

| Tag | Commit | Date | Payload | Subject |
|---|---|---|---|---|
| v1.14.0 | `b81f514` | 2026-08-25 | both | Re-vendor LibKa0s v1.14.0 — the green gate goes from 2m10.8s to 7.3s |
| v1.16.0 | `c75bd29` | 2026-08-25 | both | Re-vendor LibKa0s v1.16.0 |
| v1.17.0 | `4e9adde` | 2026-08-25 | lib | Re-vendor LibKa0s v1.17.0 and hand the ordering contract back to the library |
| v1.18.0 | `cc988f2` | 2026-08-26 | lib | Re-vendor LibKa0s v1.18.0 and take the library's resetProfile field |
| v1.18.1 | `d41b9fa` | 2026-08-26 | lib | Re-vendor LibKa0s v1.18.1: the landing logo stops pooling its texture |
| v1.19.0 | `7ef6dcd` | 2026-08-27 | lib | Adopt LibKa0s ReorderList, and retire the deviation it was filed under |
| v1.20.0 | `e94fa17` | 2026-08-27 | both | Carry the tagged LibKa0s v1.20.0 payload |
| v1.21.0 | `325ed90` | 2026-08-31 | lib | Re-vendor LibKa0s v1.21.0: tabs cut from the client's own tab art |
| v1.22.0 | `50f80cc` | 2026-08-31 | lib | Re-vendor LibKa0s v1.22.0: OPie's tab art, a real content panel, and the wrap fix |
| v1.23.0 | `ac33cbb` | 2026-08-31 | lib | Re-vendor LibKa0s v1.23.0: content box padding, and flush wrapped tab rows |
| v1.24.0 | `fe264cb` | 2026-09-02 | lib | feat(settings): adopt the library's row chrome and the composed groups |
| v1.26.0 | `ae2502a` | 2026-09-08 | lib | M3-02: adopt LibKa0s v1.26.0, and unwrap the composer's media reader with it |
| v1.27.0 | `ae5ff5e` | 2026-09-08 | both | M4-01: adopt LibKa0s v1.27.0, and wire the gate that came with it |
| v1.28.0 | `df4021f` | 2026-09-09 | lib | re-vendor LibKa0s v1.28.0 — the perf usage block renders correctly |
| v1.29.0 | `047e634` | 2026-09-09 | lib | re-vendor LibKa0s v1.29.0 — the JSON dump folds into the report step |
| v1.35.0 | `ed3b3cc` | 2026-09-14 | both | Re-vendor LibKa0s v1.35.0 (Options 18.16.5.3, kit 20) |
| v1.36.0 | `445e8dd` | 2026-09-15 | both | Re-vendor LibKa0s v1.36.0 |
| v1.36.1 | `329edbe` | 2026-09-15 | both | Re-vendor LibKa0s v1.36.1: fix pooled CheckBox gold-fill leak |
| v1.36.2 | `632300f` | 2026-09-15 | lib | Re-vendor LibKa0s v1.36.2: drop grid-cell yellow fill, ASCII-only strings |
| v1.37.0 | `6f48bb6` | 2026-09-16 | lib | Re-vendor LibKa0s v1.37.0 |
| v1.38.0 | `c115ec0` | 2026-09-16 | lib | Re-vendor LibKa0s v1.38.0; a bare /mm opens the settings panel |
| v1.39.0 | `dfbb40e` | 2026-09-16 | lib | Re-vendor LibKa0s v1.39.0: the launcher major arrives |
| v1.42.0 | `ef7df34` | 2026-09-17 | both | Disabling the addon stands it down, and a perf run takes the same latch |
| v1.43.0 | `7aff579` | 2026-09-17 | kit | Re-vendor LibKa0s v1.43.0: kit revision 23 bounds every run and stops holding built instances |
| v1.44.0 | `22be736` | 2026-09-19 | lib | Re-vendor LibKa0s v1.44.0 |
| v1.45.0 | `4976d36` | 2026-09-19 | lib | Re-vendor LibKa0s v1.45.0 |
| v1.46.1 | `cc168e7` | 2026-09-19 | lib | Re-vendor LibKa0s v1.46.1 |
| v1.47.0 | `beb53d0` | 2026-09-20 | lib | Re-vendor LibKa0s v1.47.0 |
| v1.50.0 | `3f6b1f4` | 2026-09-21 | lib | Re-vendor LibKa0s v1.50.0 |
| v1.51.0 | `4e393ee` | 2026-09-22 | lib | Re-vendor LibKa0s v1.51.0 |
| v1.52.0 | `075293f` | 2026-09-22 | lib | Re-vendor LibKa0s v1.52.0 |
| v1.53.0 | `22dc46b` | 2026-09-22 | lib | Re-vendor LibKa0s v1.53.0 |
| v1.54.2 | `d2169d4` | 2026-09-22 | kit | Adopt the kit's US-English gate, and delete the copy this repo was keeping |

Notes on the tags carried by more than one commit:

- **v1.19.0.** `7ef6dcd` rolled the provenance line over a pre-tag copy of Widgets minor 8.
  `43b4a3d` and `4315d22` carried further pre-tag payload fixes under the same line, and `7dbdf27`
  ("Carry the tagged LibKa0s v1.19.0 payload") replaced the copy with the released tag's bytes.
- **v1.20.0.** After `e94fa17` carried the tag, `efb2574` and `864325d` copied payload from the
  unreleased `options-tabbed-pages` branch while the line still named v1.20.0; their own bodies
  record the vendor-sync gate red until v1.21.0 (`325ed90`) carried the released bytes.
- **v1.29.0.** `b3f8ff1` (CP-3c, the automated-test run record) touched `tests/_kit/` too, but only
  the file mode of `run-automated-tests.sh`. The tag did not move.
- **v1.54.2.** Kit revision 24; the library bytes are identical to v1.53.0.

Folded copies, where the re-vendor rode inside a feature commit rather than standing alone
(`versioning-git` makes that a SHOULD, not a MUST): v1.19.0 (`7ef6dcd`), v1.24.0 (`fe264cb`),
v1.42.0 (`ef7df34`) and v1.54.2 (`d2169d4`). Each rolled the provenance line in the same commit as
the copy, the pairing `tests/test_vendor_sync.lua` now enforces.
