# Lootwright changelog

Versions follow the rules in `CLAUDE.md` ("Versions and changelog"). Newest first.

## 0.10.0 (Beta), not released yet

### New
- **Drop rates for normal mobs** from CMaNGOS classic-db (Classic 1.12 data, drops of 1% and up, 4,545 items). Shown as rough rates with "~" and sorted after real rates, because they match only 38% of rates measured in Forever.
- **Many more mobs in search results.** Mobs only CMaNGOS lists are added: 8,075 drops on 1,555 items were missing, and 1,173 items showed no mobs at all. Cloth now lists every mob instead of about 200.
- **Your own loot is counted** (on your PC only): looted corpses, empty kills and what was on them, per mob. Mob tooltips in the window show "You: 9 of 40 corpses". Option "Record your own loot", `/if loot`.
- **Your loot judges the list.** After 20 corpses of a mob, your measured rate replaces an unknown or rough one, and a mob that never dropped the item turns grey and moves to the bottom ("Not seen in your loot").
- **Share your loot data** with `/if share`: copy the text into the "Share loot data" form on GitHub to help work out real Forever drop rates for everyone.
- **Crafted materials in trade-skill blue** on the Farm tab and the tracker, with a "Usually crafted" tooltip.

### Changed
- Recipe farming only breaks a crafted material into its own materials if your character has that profession.

### Fixed
- Farming a recipe for something you already own (a bag you wear, armour you have on) no longer finishes at once: the goal now counts on top of what you own when you add it.

### For developers
- `tools/build_data.py` reads the CMaNGOS dump (`tools/data/`, not in git) and prints how well a rate source agrees with rates measured in Forever.
- `tools/merge_loot.py` reads shared loot data from GitHub issues.
- `/if loot debug`, `/if loot target`, `/if loot reset` for testing.

## 0.9.0 (Beta), 18 November 2026

First public release on CurseForge.
- Item search with every mob that drops it: level, rank, zone, drop rate, your zone first.
- Map skulls on spawns, waypoint arrow, farm list with goals, recipe farming with sub-materials, ready notices.
- Professions tab with every recipe (ForeverDB data), dungeon boss loot with rates measured in Forever.
- Options panel, minimap button, the "dark field guide" look, experimental farm tracker.
