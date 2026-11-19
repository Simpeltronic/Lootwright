# Lootwright: roadmap (WoW Forever addon)

**Goal:** type an item name and see which mobs drop it, in which zones, the mobs' level range, and the drop rate. Then mark the selected mobs on the map, working alongside Questie where possible.

## 0. Key facts (checked Nov 2026)

- Forever runs on the **modern (Midnight) client UI**, not the Classic Era one. The Forever 1.60.1 API notes say it shares Mainline's UI architecture and most APIs. Write the addon with modern APIs (`C_AddOns`, `C_Map`, `C_Timer`, `Settings`, `BackdropTemplate`, `C_Texture` style), not old Classic-only snippets.
- TOC: `## Interface: 16001`. A `_Forever.toc` suffix is accepted as well as `Lootwright.toc`.
- Install path: `World of Warcraft\_forever_\Interface\AddOns\Lootwright`
- Midnight addon restrictions apply in combat. Keep the UI out-of-combat only and don't read protected data during fights.
- Debugging: `/console scriptErrors 1`, or install BugSack and BugGrabber.

## 1. Data sources

| Source | Use | Notes |
|---|---|---|
| **ForeverDB** (CurseForge, by fatedfr) | **Primary.** Drops with chances, NPC level range and rank, spawn coordinates per map, vendors, quests. About 26.8k items, 15.8k NPCs, includes Forever-only content. | GPL-3.0. It rebuilds twice a day. Load it with `C_AddOns.LoadAddOn("ForeverDB")` and read the global `ForeverDB`. The page doesn't document the table layout, so Phase 1 starts by inspecting it in game. |
| **QuestieDB** | Forever-only NPC and map positions, already installed for you. | GPL-3.0. It is the base of ForeverDB's Forever content. |
| **CMaNGOS classic-db / VMaNGOS** | Vanilla drop rates, if ForeverDB is missing something. | GPL SQL dumps. |
| **pfQuest data** | More drop rates and positions. | MIT. |
| **Wowhead** | Manual cross-checking only. | Don't scrape it. Wowhead's terms forbid it, and ForeverDB deliberately avoids it. |
| **In-game recording** (later) | Replace weak rates with what you actually see. | ForeverDB's recorder does this for rates after 20+ loots. |

**Decision:** depend on ForeverDB instead of building our own database. This saves weeks. If it proves too limited, we write a build script that merges the other sources into our own Lua tables (Phase 6).

## 2. Architecture

```
Lootwright/
  Lootwright.toc
  Core.lua          -- init, slash commands (/if, /lootwright), saved variables
  Data.lua          -- adapter over ForeverDB: FindItems(name), GetSources(itemID)
  Search.lua        -- fuzzy name search, index built lazily, shift-click item links
  UI.lua            -- search box + results list + detail panel
  Map.lua           -- map pins (Phase 4)
  Integrations.lua  -- Questie / TomTom / HandyNotes (Phase 5)
```

Keep **Data.lua as the only file that knows ForeverDB's format**. If the format changes, only that adapter needs fixing.

## 3. Phases

**Status (Nov 2026):** Phases 1-5 are done, plus extras: farm list with goals, professions (known recipes, "Farm materials"), waypoint arrow, and one window with Search / Professions / Farm tabs. CLAUDE.md has the details. Note that Phases 1-4 ended up built on QuestieDB, not ForeverDB (see CLAUDE.md, "Data sources").

### Phase 1: Spike (a day or two)
- Create the folder and a TOC with `## Interface: 16001`, `## Dependencies: ForeverDB`, a `## SavedVariables: LootwrightDB` line, and a "hello world" slash command.
- In game, dump `ForeverDB` with `/dump` or `/tinspect ForeverDB` to learn the table layout (items, NPCs, drops, spawns).
- Write down the layout in `docs/foreverdb-format.md`.
- **Done when:** `/if Linen Cloth` prints item ID, the dropping NPC IDs and drop rates in chat.

### Phase 2: Search and results (MVP)
- Window with a search box. Match by name (case-insensitive, partial), with a result list.
- Selecting an item shows a table of sources: mob name, zone, level range, rank (normal, elite, rare, boss), drop %. Sort by drop rate and filter by zone.
- Handle items with several sources (vendors, quests, containers).
- Accept shift-clicked item links in the search box.
- **Done when:** you can look up an item and get a correct, sorted list of mobs.

### Phase 3: Quality of life
- Highlight sources near your level, and show your current zone first.
- Item tooltip line: "Drops from: ..." (top 3 sources).
- Remember recent searches, favorites and a farm list.
- Color-code drop rates.
- Faction and level filters.

### Phase 4: Map pins
- Resolve mob spawn coordinates (zone/map ID and x, y) from ForeverDB.
- Draw pins on the world map and the minimap with Blizzard's map APIs (`C_Map`, a map data provider on `WorldMapFrame`). Cluster nearby spawns.
- A button on each result row: "Show on map", plus a "Clear pins" command.
- **Done when:** selecting a mob row marks all of its spawns in its zone, and the pins clear properly.

### Phase 5: Integrations
- **Questie:** it exposes a public `Questie.API` (wait for `Questie.API.isReady` or use `RegisterOnReady`). Check the files in Questie's `Public/` folder to see whether it supports custom notes or icons. If it doesn't, our own pins from Phase 4 are the fallback, and we make sure they don't overlap with Questie's.
- **TomTom** (optional): "Set waypoint" on a spawn.
- **HandyNotes** (optional): an alternate way to put pins on the map, which other Forever addons already do.
- **Auction/tooltip addons:** only if easy.
- Every integration must be optional. The addon works without any of them.

### Phase 6: Dependency review
Decide what Lootwright needs installed, and what it could do without. The answer shapes Phase 7.

What it uses today:

| Addon | How | Used for | Required? |
|---|---|---|---|
| **QuestieDB** | `## Dependencies`, global `LibQuestieDB` | Item names, mob drops, mob level/rank/zone/faction, spawns, area-to-map tables, quest-item drop tables | Yes. Nothing works without it. |
| **Questie** | `## OptionalDeps`, `QuestieLoader` modules `QuestieDB`, `DropDB` | Drop rates with Questie's manual corrections, and its already-decoded drop tables | No. Without it we decode QuestieDB's drop tables ourselves. |

Everything else is the game's own API (`C_Map`, `C_TradeSkillUI`, `TooltipDataProcessor`, `C_Item`, world map canvas). Code we learned from but don't load: HereBeDragons-Pins (map pin pool), RareScanner (pin clicks, waypoints), ForeverDB_Helper (arrow approach).

Questions to answer:
- **QuestieDB:** keep it as a required addon, or ship our own data file (built by the Phase 7 script) so Lootwright works alone? Trade-offs: download size, who keeps the data current through Forever's beta patches, GPL-3.0 attribution.
- **Questie:** is the optional hook worth keeping? It only adds Questie's manual rate corrections. Check how often its rate differs from QuestieDB's own table.
- **Private-API risk:** list every place we reach into another addon's internals (`QuestieLoader:ImportModule`, `Support.Get(...).private`, `WorldMapFrame.pinPools`). Each could break on their update; decide which to keep, wrap or replace.
- **Done when:** every dependency is either kept with a reason, made optional, or removed, and the TOC matches.

**Findings and decisions (Nov 2026):**
- **QuestieDB: kept, required.** Every Questie user already has it (Questie reads its data from it); it's 36 MB of data we'd otherwise ship and keep current through Forever's beta patches; it's actively updated for Forever (1.1.2); and `LibQuestieDB` is a public, versioned API (`contractVersion` 4, `RequireContract`). Lootwright now checks the contract at login and in `/if status`, and the TOC carries `## X-QuestieDB-Contract: 4`.
- **Questie: removed.** Everything we read through it is QuestieDB data: the Wowhead and CMaNGOS drop tables and the manual corrections (154 items, 178 entries, `Support.Get("QuestieItemDropCorrections").Era`). Questie only added the lookup order, now copied into `Data.lua` (correction, then CMaNGOS, then Wowhead). This also fixed our no-Questie fallback, which checked Wowhead before CMaNGOS. Cost: the drop tables are decoded once by us even when Questie has its own copy (a one-time hitch and some memory).
- **Internals kept on purpose:** `Support.Get("ZoneDB").private.areaIdToUiMapId` (no game API maps area IDs to map IDs; pcall'd, only pins fail if it breaks), `Support.Get(...)` drop tables (QuestieDB's documented whole-table access), and `WorldMapFrame.pinPools` (Blizzard internal that Questie and HereBeDragons also rely on).
- Phase 7 (own data file) is about *adding* measured rates, not replacing QuestieDB.

### Phase 7: Data improvements
- **Built:** `tools/build_data.py` turns ForeverDB's `Recipes.lua`, `Loot.lua` and `Meta.lua` into `GeneratedData.lua` (every recipe, and boss loot with rates measured in Forever and kill counts). Keeps the `-- Data: ForeverDB.net` line; credits in the TOC, `/if status` and NOTICE.md.
- **Not available from ForeverDB:** per-mob rates for normal mobs (`Items.lua` only names one best source per item). That needs CMaNGOS classic-db's loot tables, a separate download; ask first.
- Show the data version and date in the window (Phase 9).
- Optional: our own recorder (the `LOOT_OPENED` event) saves observed drop counts to `LootwrightDB`. Show "observed 3/40 (7.5%)" next to the database rate.

### Phase 8: Modules and options
**Done (Nov 2026, verified in game):** `Lootwright_Data` (load on demand) and `Lootwright_Professions` sub-addons; an options panel with five feature toggles. `Lootwright_Map` was not split out: pins and the arrow are small, and have their own toggles instead.

Let players switch off what they don't use. Two levels:
- **Options** (the game's `Settings` panel, plus `/if` commands): turn single features on or off. Candidates: the "Drops from" item tooltip line, the "Farm:" mob tooltip line, map pins, the waypoint arrow, farm-goal messages, the minimap button, default tab. Each feature checks its option before it does anything (hooks registered but idle when off).
- **Search filters (built early, with Phase 7)** (checkboxes under the search box, saved; options, not sub-addons, since players flip them often): Reagents, Quest, Gear, Other (every item has exactly one kind; reagents = used in a recipe or trade goods), plus Dungeon (ForeverDB boss loot; normal dungeon mobs aren't covered). Ticked = shown; all start ticked. Reagents are the main selling point, so Phase 9 (design) should put them front and centre. Applied to all matches, with a "N hidden by filters" count.
- **Sub-addons** (separate folders players can untick in the AddOns list, like `AtlasLootContinued_Crafting`), each with `## Dependencies: Lootwright`:
  - `Lootwright_Data`: `GeneratedData.lua` (ForeverDB recipes and boss loot, ~284 KB), `## LoadOnDemand: 1`, loaded the first time it's needed. Without it Lootwright carries no ForeverDB data and runs on QuestieDB alone.
  - `Lootwright_Professions`: `Prof.lua` and `ProfUI.lua` (recipe scanning and the Professions tab). Without it the tab is hidden and no profession events are registered.
  - Maybe `Lootwright_Map`: map pins and the arrow, if they turn out heavy.
- The core (`Lootwright`: search, mob table, farm list) has to work with every sub-addon off, and pick them up when they're on (check for their `ns` hooks or a small registration call, never assume).
- Development: one git repo with all folders side by side; each gets its own junction into AddOns.
- **Done when:** each option and each sub-addon can be turned off without errors, the features it owns disappear cleanly, and memory use drops when they're off.

### Phase 9: Design
Make Lootwright look and feel its own, not like a debug window.
- A visual identity: icon, colour accents, header, consistent fonts and spacing across all three tabs.
- Real WoW-style tabs instead of plain buttons (check which tab template works on Forever).
- Item icons in lists, quality colours, clearer empty states, and a tidier mob table (rank badges, rate bars).
- Minimap or addon-compartment button.
- Look at what other Forever addons (Questie, AtlasLoot, RareScanner, ForeverDB) do, and pick what makes Lootwright stand out instead of copying them.
- **Done when:** mockups are agreed on first, then built, and every tab follows them.

### Phase 10: Release
- Localization if wanted, icon, and a CurseForge page. (The options panel is built in Phase 8.)
- Re-run `tools/build_data.py` right before packaging, so the ForeverDB data is current.
- Package with a `.pkgmeta` and GitHub Actions (BigWigs packager).
- Make the license GPL-3.0-compatible, since ForeverDB is GPL-3.0 and QuestieDB is GPL-3.0.

## 4. Risks and open questions

1. ForeverDB's table layout is undocumented, so we have to reverse-engineer it (Phase 1).
2. Forever gets regular builds, so API and data can change with each one. Pin the interface number and re-test after patches.
3. Questie's API may not allow adding custom pins, so the Phase 4 pins are the safe default.
4. Combat restrictions on the modern client may affect tooltips and map code.
5. Drop rates are community or server estimates, so they may not match real Forever rates. The addon should say so.
6. Loading a 26.8k-item database can cause a hitch. Build the name index lazily or in small chunks with `C_Timer`.

## 5. Moving to Claude Code

When we're ready, do this in the project folder `I:\VibeStuff\Wow addons\ItemFinder`:

1. Put this file there as `ROADMAP.md`.
2. Add a short `CLAUDE.md` with the key facts from section 0, the file layout from section 2, the rule that Data.lua is the only place that touches ForeverDB's format, and the current phase.
3. Save a dump of `ForeverDB`'s structure (from Phase 1) in `docs/foreverdb-format.md`, so Claude Code knows the data layout without having to run the game.
4. Create a junction or symlink from the project folder into `_forever_\Interface\AddOns\Lootwright`, so edits show up in game after `/reload`.
5. Start with `git init` and commit after each phase.
6. Workflow loop: Claude Code edits, you `/reload`, you paste any Lua errors back.
