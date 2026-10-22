# 02 — Candidates (MultiMeters)

From `git -C ../LibKa0s log --oneline v1.71.0..v1.75.0`, the v1.72.0 to v1.75.0 `CHANGELOG.md`
blocks and their `docs/api/` documents. The contract changes 01_DELTA.md classes as blockers are not
listed here: they were fixed in the re-vendor commit.

## Class A: reached the addon on the copy

- **Options 29 scroll keep** (v1.73.0): a structural refresh keeps the page's scroll offset. No host
  change. Owner smoke PANEL-48.
- **Kit 39 / 40 / 41**: the wider `__fireUnconditional` reach, the declaration-aware vendor gate and
  the crashed-complexity bucket all run in this addon's suites as of the copy.

## Class B: host change required

- **`W.TestStrip`** (Widgets minor 13, LibKa0s#48). The test-mode strip under the title. **Adopt, in
  MM-01** (OWNER_SCOPE #48 and D: a narrow `ApplyTestStrip` on toggle; the title marker and the
  session-line word stay). It passes `NS.Icon('info')`, which this re-vendor already declares.
- **`W.SearchBox`** (Widgets minor 13, #52): no search field in this addon.
- **`Item.BonusIDsFromLink`** (Item minor 3, #51): this addon never reads an item link.
- **`O.Drawer`** (OptionsDrawer minor 1, v1.73.0): no settings page here groups rows into drawers.
- **`Perf.Note` `parentKey = false`** (Perf minor 15, v1.72.0): no bucket here is sometimes nested
  and sometimes top level.
- **`Kit.assertLatchHoldOrder`** (kit 39): the latch case in this addon's suite already exists by
  hand; nothing requires the switch.

## Class C: whole-module adoption

- **`LibKa0s-Glow-1.0`** (new major, #56): this addon draws no proc or highlight glow.
- **`LibKa0s-Sim-1.0`** (new major, #54): a meter simulator is tracked as MultiMeters#60, which
  stays open and `state:triaged`, repointed at Sim-1.0 in MM-03. Not this run.
