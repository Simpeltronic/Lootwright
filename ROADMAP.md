# ItemFinder: roadmap (WoW Forever addon)

**Goal:** type an item name and see which mobs drop it, in which zones, the mobs' level range, and the drop rate. Then mark the selected mobs on the map, working alongside Questie where possible.

## 0. Key facts (checked Nov 2026)

- Forever runs on the **modern (Midnight) client UI**, not the Classic Era one. The Forever 1.60.1 API notes say it shares Mainline's UI architecture and most APIs. Write the addon with modern APIs (`C_AddOns`, `C_Map`, `C_Timer`, `Settings`, `BackdropTemplate`, `C_Texture` style), not old Classic-only snippets.
- TOC: `## Interface: 16001`. A `_Forever.toc` suffix is accepted as well as `ItemFinder.toc`.
- Install path: `World of Warcraft\_forever_\Interface\AddOns\ItemFinder`
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
ItemFinder/
  ItemFinder.toc
  Core.lua          -- init, slash commands (/if, /itemfinder), saved variables
  Data.lua          -- adapter over ForeverDB: FindItems(name), GetSources(itemID)
  Search.lua        -- fuzzy name search, index built lazily, shift-click item links
  UI.lua            -- search box + results list + detail panel
  Map.lua           -- map pins (Phase 4)
  Integrations.lua  -- Questie / TomTom / HandyNotes (Phase 5)
```

Keep **Data.lua as the only file that knows ForeverDB's format**. If the format changes, only that adapter needs fixing.

## 3. Phases

### Phase 1: Spike (a day or two)
- Create the folder and a TOC with `## Interface: 16001`, `## Dependencies: ForeverDB`, a `## SavedVariables: ItemFinderDB` line, and a "hello world" slash command.
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

### Phase 6: Data improvements
- Show the data version and date (from `ForeverDB.meta`) in the window.
- Optional: our own recorder (the `LOOT_OPENED` event) saves observed drop counts to `ItemFinderDB`. Show "observed 3/40 (7.5%)" next to the database rate.
- Fallback build script (Python) that merges CMaNGOS, pfQuest and QuestieDB exports into compact Lua tables, if ForeverDB isn't enough.

### Phase 7: Release
- Localization if wanted, an options panel (`Settings` API), icon, and a CurseForge page.
- Package with a `.pkgmeta` and GitHub Actions (BigWigs packager).
- Make the license GPL-3.0-compatible, since ForeverDB is GPL-3.0 and QuestieDB is GPL-3.0.

## 4. Risks and open questions

1. ForeverDB's table layout is undocumented, so we have to reverse-engineer it (Phase 1).
2. Forever is in beta, so API and data can change with each build. Pin the interface number and re-test after patches.
3. Questie's API may not allow adding custom pins, so the Phase 4 pins are the safe default.
4. Combat restrictions on the modern client may affect tooltips and map code.
5. Drop rates are community or server estimates, so they may not match real Forever rates. The addon should say so.
6. Loading a 26.8k-item database can cause a hitch. Build the name index lazily or in small chunks with `C_Timer`.

## 5. Moving to Claude Code

When we're ready, do this in the project folder `I:\VibeStuff\Wow addons\ItemFinder`:

1. Put this file there as `ROADMAP.md`.
2. Add a short `CLAUDE.md` with the key facts from section 0, the file layout from section 2, the rule that Data.lua is the only place that touches ForeverDB's format, and the current phase.
3. Save a dump of `ForeverDB`'s structure (from Phase 1) in `docs/foreverdb-format.md`, so Claude Code knows the data layout without having to run the game.
4. Create a junction or symlink from the project folder into `_forever_\Interface\AddOns\ItemFinder`, so edits show up in game after `/reload`.
5. Start with `git init` and commit after each phase.
6. Workflow loop: Claude Code edits, you `/reload`, you paste any Lua errors back.
