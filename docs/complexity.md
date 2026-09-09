# Complexity report

<!-- GENERATED — do not hand-edit. Regenerate per performance-§10. -->

- **Generated:** 2026-09-09
- **Tool:** lizard 1.24.0
- **Command:** `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .`
- **Standard:** v2.40.0

## Watch list

**None.** `lizard` warns on no function in this addon, and no authored file sits in `layout-§1`'s
1000–1500 on-notice band without being named below. An empty watch list is a **result**, not a
dropped heading.

This is the first report at this path. It is also the first run in this repository's history to warn
on nothing: the run of 2026-09-08 warned on **23** functions, eleven of them carrying a **Peel**
disposition with an issue number and twelve a ratified **Accepted** with a re-check trigger. All
twenty-three came under CCN 15 on 2026-09-09, accepts included — an accept is a compliant watch-list
state and it is not a release gate, and `automated-tests-§3` refuses a tag while any function sits
above 15.

### Newly crossed since the previous report

Nothing crossed. Everything that had crossed came back.

### The 1000–1500 LOC band

Eleven files, every one of them put there by the 2026-09-09 peels rather than by growth — a peel
lands a file wherever its seam falls, and several fell high. None is in breach; they are listed so
that whoever next edits one knows the headroom before they start.

| File | Lines | Headroom |
|---|---|---|
| `tests/wow_mock.lua` | 1466 | 34 |
| `tests/test_row.lua` | 1456 | 44 |
| `tests/test_window_header.lua` | 1421 | 79 |
| `tests/test_tooltip_deaths.lua` | 1403 | 97 |
| `tests/test_provider.lua` | 1359 | 141 |
| `settings/Schema.lua` | 1350 | 150 |
| `settings/Schema_Compose.lua` | 1285 | 215 |
| `tests/test_export.lua` | 1275 | 225 |
| `tests/test_aggregator.lua` | 1255 | 245 |
| `tests/test_window.lua` | 1240 | 260 |
| `tests/test_database.lua` | 1121 | 379 |

### Reading the number, before acting on one

`lizard` counts every `and` and `or` short-circuit as a decision, and in Lua that is where most of a
function's score comes from — so a high number usually means *this function defaults or guards a lot
of fields*, not *this function has tangled control flow*. The two want completely different fixes,
and the metric ranks them the wrong way round. The fix for repeated defaulting is a data table plus
one loop (`performance-§11`), never respelling `x = a or b` as an `if`/`else`, which is the same
decision count in three times the lines and the tell that the report is being gamed rather than read
(anti-pattern **#52**).

## Raw output

```
    446      10.8     1.2       81.1        36     ./tests/test_roster.lua
    917       7.3     1.3       66.4       132     ./tests/test_row.lua
    332       7.6     1.3       70.1        45     ./tests/test_row_namecell.lua
    637      16.3     4.0      120.5        35     ./tests/test_schema.lua
    158      11.1     2.6       73.8        14     ./tests/test_schema_defaults.lua
    369       9.9     1.2       73.9        36     ./tests/test_schema_paths.lua
    340       5.9     1.3       47.3        59     ./tests/test_secrets.lua
    497       7.7     1.3       55.9        63     ./tests/test_slash.lua
    163       7.8     1.7       58.8        19     ./tests/test_state.lua
     16      14.0     1.0       85.0         1     ./tests/test_surface_parity.lua
    341      12.2     1.7      108.0        27     ./tests/test_targets.lua
    205      18.1     6.9      107.8        10     ./tests/test_texture_paths.lua
    360       7.7     1.9       61.6        43     ./tests/test_tooltip.lua
    351       8.4     2.0       66.5        32     ./tests/test_tooltip_builders.lua
    912       5.6     1.3       43.6       172     ./tests/test_tooltip_deaths.lua
    521       7.8     1.6       65.4        68     ./tests/test_tooltip_lines.lua
      4       0.0     0.0        0.0         0     ./tests/test_vendor_sync.lua
    583       8.4     1.5       67.8        53     ./tests/test_visibility.lua
    766      10.6     1.6       81.2        70     ./tests/test_window.lua
    373      10.1     1.4       88.5        35     ./tests/test_windowmanager.lua
    871       9.4     1.6       76.6        89     ./tests/test_window_header.lua
    416      11.0     1.4       84.3        37     ./tests/test_window_placement.lua
    832       3.9     2.4       27.8       162     ./tests/wow_mock.lua

===============================================================================================================
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
==========================================================================================
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
------------------------------------------------------------------------------------------
     36689       8.1     2.4       62.8     3752            0      0.00    0.00
```
