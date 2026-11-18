# Credits and data sources

- **Data from ForeverDB.net (https://foreverdb.net)**
  `GeneratedData.lua` (all recipes, and dungeon and raid boss loot with drop rates measured in WoW Forever) is built by `tools/build_data.py` from the ForeverDB addon's data files. That data is GPL-3.0 with an additional attribution term (GPL-3.0 section 7(b)): the file keeps ForeverDB's `-- Data: ForeverDB.net` line, and this credit must be shown wherever ItemFinder lists its sources. Some of ForeverDB's boss-loot rates come from CMaNGOS classic-db (GPL-3.0).
- **QuestieDB** (https://github.com/Questie/QuestieDB, GPL-3.0): item names, mob drops, mob levels, ranks, zones and spawns, area-to-map tables, and quest-item drop tables (Wowhead and CMaNGOS rates, with QuestieDB's manual corrections). Read at runtime through its public `LibQuestieDB` API.

Because ItemFinder includes GPL-3.0 data, ItemFinder itself has to be released under GPL-3.0 (Phase 10).
