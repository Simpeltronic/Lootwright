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
- **Bank counts on the Farm tab:** "1(2) / 3" means 1 in your bags and the bank can cover the other 2; the bar fills the bank part in a lighter green. Same on the on-screen tracker. The tooltip gives the exact bank count. Goals still count bags and equipped only. Open your bank once per session so the game knows what's in it.
- **Farm a recipe from the Search tab:** for an item your profession can craft, the farm popup lets you pick "Farm the item" or "Farm the recipe (Tailoring)". The recipe adds its materials as a group, the same as the Professions tab; the goal box still counts the item, and the popup shows how many crafts that is.
- **One colour rule for farm items:** green = farm it from mobs, blue = crafted, grey = vendor only, gold = recipe. Single farm items now use it too, on the Farm tab and the tracker.
- **Craft tag in the Search list:** a small blue "craft" next to items a recipe makes, and a "Crafted: Tailoring (...)" tooltip line.

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
