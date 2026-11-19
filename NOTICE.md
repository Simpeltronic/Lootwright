# Credits and data sources

- **Data from ForeverDB.net (https://foreverdb.net)**
  `GeneratedData.lua` (all recipes, and dungeon and raid boss loot with drop rates measured in WoW Forever) is built by `tools/build_data.py` from the ForeverDB addon's data files. That data is GPL-3.0 with an additional attribution term (GPL-3.0 section 7(b)): the file keeps ForeverDB's `-- Data: ForeverDB.net` line, and this credit must be shown wherever Lootwright lists its sources. Some of ForeverDB's boss-loot rates come from CMaNGOS classic-db (GPL-3.0).
- **CMaNGOS classic-db** (https://github.com/cmangos/classic-db, GPL-3.0): per-mob drop rates (1% and up) in `GeneratedData.lua`'s `mobRates`, built by `tools/build_data.py` from the classic-db SQL dump's loot tables. These are Classic 1.12 rates, not measured in Forever; they fill only rates QuestieDB and ForeverDB don't have. World of Warcraft content is Blizzard's; CMaNGOS states its use as non-commercial.
- **QuestieDB** (https://github.com/Questie/QuestieDB, GPL-3.0): item names, mob drops, mob levels, ranks, zones and spawns, area-to-map tables, and quest-item drop tables (Wowhead and CMaNGOS rates, with QuestieDB's manual corrections). Read at runtime through its public `LibQuestieDB` API.

- **Shared loot data** (from players' `/if share` posts, merged by `tools/merge_loot.py`): published as open data under Creative Commons Attribution 4.0 (CC BY 4.0, https://creativecommons.org/licenses/by/4.0/). Anyone may use it, with credit to Lootwright. Players agree to this on the share form. It holds only mob and item IDs with counts and the game build.

- **Inter** font (https://github.com/rsms/inter, SIL Open Font License 1.1): used only for the CurseForge banner images, drawn by `tools/make_brand.py`. The font and its licence are in `tools/fonts/`; it isn't part of the addon download.
- **Emblem artwork**: the Lootwright emblem (loot bag, route, red X) was made for this project and is distributed with it under GPL-3.0.

Because Lootwright includes GPL-3.0 data, Lootwright itself has to be released under GPL-3.0 (Phase 10).
