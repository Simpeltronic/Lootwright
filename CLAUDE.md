# ItemFinder

A WoW Forever addon. The player types an item name and sees which mobs drop it, their zone, level range, rank and drop rate. Later: mark those mobs on the map.

Read `ROADMAP.md` for the full plan. This file is the short version plus the facts learned so far.

## Current state

- **Phase 1 done** (commit a6ea043): `/if status` and `/if Linen Cloth` verified in game.
- **Phase 2 written, not yet verified in game** (v0.1.0): split into `Core.lua` (slash, log, shared formatting), `Data.lua` (all QuestieDB/Questie access), `Search.lua` (name index) and `UI.lua` (window). `/if` alone opens the window; the chat commands still work.
- QuestieDB's `Item.npcDrops` is empty for many common items (e.g. Linen Cloth). `Data.lua` falls back to QuestieDB's quest-item drop tables (`QuestieClassicItemDrops`, ~2k items, `[itemId][npcId] = rate`), using Questie's decoded `DropDB.tableWowhead` / `tablePserver` when Questie is loaded. This fallback is not yet verified in game.
- Next: test the window and the fallback; then Phase 3.

## Reading game output from here

- All `say()` output is also saved to `ItemFinderDB.log` (last 500 lines). Read it after a `/reload` from `Z:\Blizzard\World of Warcraft\_forever_\WTF\Account\<ACCOUNT>\SavedVariables\ItemFinder.lua`.
- `Logs\WoWChatLog.txt` (`/chatlog`) does not capture addon `print()` output. Lua errors are not in the log; they need BugSack or a screenshot.

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
