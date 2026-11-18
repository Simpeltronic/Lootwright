# ItemFinder

A WoW Forever addon. The player types an item name and sees which mobs drop it, their zone, level range, rank and drop rate. Later: mark those mobs on the map.

Read `ROADMAP.md` for the full plan. This file is the short version plus the facts learned so far.

## Current state

- **Phase 1 (prototype)** is in progress. `Core.lua` (v0.0.2) has `/if <item name>`, `/if #<id>`, shift-click lookup, `/if status` and `/if raw item|npc <id>`. Output goes to chat only. There is no UI yet.
- **Not yet verified in game.** The code was written without running it and without a Lua syntax check. The first job is to run it in game, read any errors, and fix them.
- Next: confirm `/if status` and `/if Linen Cloth` work, then Phase 2 (search window and results list).

## Environment facts

- **Game:** WoW Forever beta. TOC `## Interface: 16001`. A `_Forever.toc` suffix is also accepted.
- **Client:** Forever runs on the **modern (Midnight) client UI**, not Classic. Use modern APIs (`C_AddOns`, `C_Map`, `C_Timer`, `C_Item`, `Settings`, `BackdropTemplate`). Do not copy old Classic-only snippets.
- **Combat restrictions** of the modern client apply. Keep the UI out-of-combat and don't read protected data during fights.
- **Install path:** `Z:\Blizzard\World of Warcraft\_forever_\Interface\AddOns\ItemFinder`
- **Project folder:** `I:\VibeStuff\Wow addons\ItemFinder`. The AddOns folder should be a junction to this folder (`mklink /J`), so there is one copy of the files.
- **Testing:** the game can't be run from here. After each change the user runs `/reload` and pastes any Lua errors back. `/console scriptErrors 1` shows them. There is no Lua installed in the cloud workspace, so syntax can't be checked there. If a local `luac`/`luajit` exists, use it with `-p`.

## Data sources (decided)

| What | Where | Notes |
|---|---|---|
| Item names, mobs that drop an item | `LibQuestieDB.Item` (`GetAllIds`, `name`, `npcDrops`, `objectDrops`, `vendors`) | Public API of the **QuestieDB** addon. Global `LibQuestieDB`. |
| Mob name, level range, rank, zone, spawns | `LibQuestieDB.Npc` (`name`, `minLevel`, `maxLevel`, `rank`, `zoneID`, `spawns`) | Spawn table layout still to be confirmed with `/if raw npc <id>`. |
| Drop rate | `QuestieLoader:ImportModule("QuestieDB").GetItemDroprate(itemId, npcId)` | From the **Questie** addon, optional. Returns `{rate, source}` or `nil`. **Only has rates for quest items**, so most items show "rate ?". |

Contract check available: `LibQuestieDB.RequireContract(n)`.

### Do not do these

- **Do not use the `ForeverDB` global.** The installed `ForeverDB` addon is the foreverdb.net addon (CurseForge project 1725334). It keeps its data in a private namespace and exposes no global. (A different CurseForge project, "forever-db" by fatedfr, does expose one, but it is not installed and would clash by name.)
- **Do not scrape Wowhead.** Its terms forbid it.
- **Do not edit files in other addons' folders.**

### Later: better drop rates (Phase 6)

The foreverdb.net addon's data files (`ForeverDB\Data\Items.lua`, `Loot.lua`) have measured drop rates. They are GPL-3.0 with an attribution term: keep the `-- Data: ForeverDB.net` header line in any copied file, and credit "Data from ForeverDB.net (https://foreverdb.net)" in the addon's credits. The plan is a build script that generates our own data file from them (plus CMaNGOS classic-db, GPL-3.0). It must not read ForeverDB at runtime.

## Architecture (planned)

```
ItemFinder/
  ItemFinder.toc
  Core.lua          init, slash commands, saved variables
  Data.lua          the ONLY file that talks to LibQuestieDB / Questie
  Search.lua        name index + search
  UI.lua            search box, results list, detail panel
  Map.lua           map pins
  Integrations.lua  Questie / TomTom / HandyNotes (all optional)
```

Today everything is in `Core.lua`. Splitting it into `Data.lua`, `Search.lua` and `UI.lua` is part of Phase 2.

## Rules for working on this

- Keep `Data.lua` as the only code that knows the data format. The UI works with plain tables like `{ npcId, name, minLevel, maxLevel, rank, zone, rate, source }`.
- Build the name index in chunks with `C_Timer.After(0, ...)` so the game doesn't freeze. QuestieDB has about 26k+ items.
- Every integration (Questie rates, TomTom, HandyNotes) is optional. The addon must work without them.
- Be honest in the UI: say "rate unknown" instead of showing a made-up number.
- Add new commands and options to `/if` instead of making new slash commands.
- Commit after each working step.

## Workflow

1. Claude Code edits the files.
2. The user runs `/reload` in game and tests.
3. The user pastes any Lua error or odd output back.
4. Repeat. Update "Current state" in this file at the end of each session.

## Open questions

- Exact layout of `Npc.spawns` (expected: zone ID mapped to a list of `{x, y}`). Check with `/if raw npc <id>`.
- Whether `C_Map.GetAreaInfo` returns names for Forever's new zones.
- How to convert QuestieDB area IDs and coordinates to the `uiMapID` that map pins need. `LibQuestieDB.Support` has `areaIdToUiMapId` data. Check `support/Forever/Zones/` in the QuestieDB addon folder.
- Whether Questie's `Public/` API allows custom pins. If not, draw our own.
