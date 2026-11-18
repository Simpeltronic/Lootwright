# ItemFinder

A WoW Forever addon. The player types an item name and sees which mobs drop it, their zone, level range, rank and drop rate. Later: mark those mobs on the map.

Read `ROADMAP.md` for the full plan. This file is the short version plus the facts learned so far.

## Current state

- **Phase 1 done** (commit a6ea043): `/if status` and `/if Linen Cloth` verified in game.
- **Phase 2 done** (v0.1.0, commit 4e273c3, verified in game): split into `Core.lua` (slash, log, shared formatting), `Data.lua` (all QuestieDB/Questie access), `Search.lua` (name index) and `UI.lua` (window). `/if` alone opens the window; the chat commands still work.
- QuestieDB's `Item.npcDrops` is empty for many common items (e.g. Linen Cloth). `Data.lua` falls back to QuestieDB's quest-item drop tables (`QuestieClassicItemDrops`, ~2k items, `[itemId][npcId] = rate`), using Questie's decoded `DropDB.tableWowhead` / `tablePserver` when Questie is loaded. Verified with Linen Cloth (200 mobs). Known weakness: Wowhead rates for quest mobs are often 100% from tiny samples, so they sort to the top.
- On Forever, `InputBoxTemplate` edit boxes didn't take keyboard input (keys went to game binds). Use `SearchBoxTemplate`.
- **Phase 3 part 1 done** (verified in game): level colours by difficulty, colour-coded rates, current zone sorted first (matched by zone name), recent items (`ItemFinderDB.recent`), and a "Drops from" tooltip line via `TooltipDataProcessor` (`/if tooltip` toggles `ItemFinderDB.tooltip`).
- **Phase 4 done** (verified in game): clicking a mob row puts skull pins on the world map (`Map.lua`), opening the mob's main zone. "Clear pins" button and `/if clear`. World map only; no minimap pins or clustering.
- Map pins copy HereBeDragons-Pins (in Questie's `Libs`): a Lua pin pool in `WorldMapFrame.pinPools` + a `MapCanvasDataProviderMixin` provider. Pins must NOT set their own `OnEnter`/`OnLeave` scripts (the canvas asserts); define `OnMouseEnter`/`OnMouseLeave` methods instead.
- Drop rates from <= 10 kills are detected (exact k/n fractions in Wowhead data), shown with `*` and sorted after real rates.
- **Phase 3 done** (part 2 verified in game). Search results list matching favorites first, in gold. Favorite button (`ItemFinderDB.favorites`, shown in gold above recent items), "Near lvl" filter (+/-5 levels, `ItemFinderDB.nearLevel`) and "Friendly" checkbox (mobs friendly to your faction are hidden unless `ItemFinderDB.showFriendly`; uses `Npc.friendlyToFaction`). Filters also apply to the tooltip line. No separate farm list (favorites cover it).
- **Phase 5 done** (arrow verified in game in the same zone; across zones on one continent it points via world-position conversion, grey "In <zone>" otherwise): clicking a map pin sets a waypoint. Forever does NOT show the game's own waypoint arrow (`C_Map.SetUserWaypoint` + `C_SuperTrack` only gives a map ping; verified), so `Arrow.lua` draws our own arrow + distance from `C_Map.GetPlayerMapPosition` and `GetPlayerFacing`, both wrapped in `pcall` and checked with `issecretvalue`. Right-click clears it; it clears itself within 10 yards. Questie's public API (`Questie.API`: RegisterOnReady, RegisterForQuestUpdates, GetQuestObjectiveIconForUnit) has no custom pins, so our own pins stay. TomTom and HandyNotes are not installed, so no integration for them.
- **Farm list done** (verified in game; an item that is both farm and favorite shows as farm, green, which the user wants) (`Farm.lua`, `ItemFinderDB.farm`): separate from favorites on purpose (favorites = bookmarks in the window; farm = short active list that changes the game world). "Farm" button next to Favorite; farm items green at the top of lists. Mobs that drop farm items get "Farm: <item> <rate> (have N)" on their in-game tooltip (unit `TooltipDataProcessor`, NPC ID from the GUID, out of combat only) and on mob rows in the window.
- **Farm goals done** (verified in game): a "Goal" box next to Farm (applied on Enter). `ItemFinderDB.farm[id] = { goal = n }`. On `BAG_UPDATE_DELAYED`, items whose bag count (`C_Item.GetItemCount`) reaches the goal are removed, with a chat + screen message. Tooltip shows "(have 12/40)".
- **Professions done** (verified in game): `Prof.lua` reads the open profession window. **Forever uses the modern `C_TradeSkillUI` API** (log: "Saved 26 Tailoring recipes (modern profession API)"); the classic `GetTradeSkill*` path stays as a fallback. Saved into `ItemFinderDB.prof[name-realm][profession]`. Known recipes only; no classic `GetCraft*` (old Enchanting UI). `ProfUI.lua` window (`/if prof` or the Professions button): recipes, materials with have/need for N crafts and their sources, "Farm materials" sets farm goals for missing, non-vendor-only materials. A full recipe list (unlearned recipes) would need Phase 6 data.
- **Tabs done** (verified in game; after farm/favorite changes `refreshItemRows` recolours the Search rows): the main window has bottom tabs Search / Professions / Farm (plain `UIPanelButtonTemplate` buttons below the frame; selected one uses `LockHighlight`). Each tab is a page frame covering the window; `ProfUI.Build(page)` and `FarmUI.Build(page)` build into theirs. The separate Professions window is gone. `UI.ShowTab(key)` switches and saves `ItemFinderDB.tab`; `/if` reopens the last tab; `/if prof`, `/if farm`. Clicking a material or farm row calls `UI.ShowItem`, which switches to Search.
- Pin clicks: an `OnMouseDown` script on the pin is allowed (RareScanner does it); only `OnEnter`/`OnLeave` scripts trip the canvas assert.

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

### Remaining phases (see ROADMAP.md)

6 Dependency review, 7 Data improvements, 8 Design, 9 Release. Next up: Phase 6.

### Later: better drop rates (Phase 7)

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

- ~~`Npc.spawns` layout~~ Answered: `{ [areaId] = { {x, y, phase?}, ... } }`, x/y in percent (0-100), `(-1,-1)` = inside an instance.
- ~~Area ID to uiMapID~~ Answered: `LibQuestieDB.Support.Get("ZoneDB").private.areaIdToUiMapId` and `.areaIdToUiMapIdOverride` (Lua source strings; `loadstring` them, override wins). Coordinates need no reprojection.
- Whether `C_Map.GetAreaInfo` returns names for Forever's new zones.
- Whether Questie's `Public/` API allows custom pins. If not, draw our own.
