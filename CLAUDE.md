# Lootwright

A WoW Forever addon. The player types an item name and sees which mobs drop it, their zone, level range, rank and drop rate. Later: mark those mobs on the map.

Read `ROADMAP.md` for the full plan. This file is the short version plus the facts learned so far.

**Name:** renamed from ItemFinder to **Lootwright** in Nov 2026 ("ItemFinder" is taken on CurseForge by ItemFinder Classic, and a Wildstar addon). Addon folders and TOCs: `Lootwright`, `Lootwright_Data`, `Lootwright_Professions`; globals `LootwrightDB` (saved variables), `LootwrightNS` (shared namespace); slash `/if` and `/lootwright` (not `/itemfinder`, which ItemFinder Classic uses). The repo folder on disk is still `I:\VibeStuff\Wow addons\ItemFinder`; only the AddOns junctions carry the new names. Old commits say ItemFinder.

## Current state

- **Phase 1 done** (commit ba42b58): `/if status` and `/if Linen Cloth` verified in game.
- **Phase 2 done** (v0.1.0, commit 0fbc22a, verified in game): split into `Core.lua` (slash, log, shared formatting), `Data.lua` (all QuestieDB/Questie access), `Search.lua` (name index) and `UI.lua` (window). `/if` alone opens the window; the chat commands still work.
- QuestieDB's `Item.npcDrops` is empty for many common items (e.g. Linen Cloth). `Data.lua` falls back to QuestieDB's quest-item drop tables (`QuestieClassicItemDrops`, ~2k items, `[itemId][npcId] = rate`), decoded by Lootwright itself since Phase 6 (Questie is no longer used). Verified with Linen Cloth (200 mobs). Known weakness: Wowhead rates for quest mobs are often 100% from tiny samples, so they sort to the top.
- On Forever, `InputBoxTemplate` edit boxes didn't take keyboard input (keys went to game binds). Use `SearchBoxTemplate`.
- **Phase 3 part 1 done** (verified in game): level colours by difficulty, colour-coded rates, current zone sorted first (matched by zone name), recent items (`LootwrightDB.recent`), and a "Drops from" tooltip line via `TooltipDataProcessor` (`/if tooltip` toggles `LootwrightDB.tooltip`).
- **Phase 4 done** (verified in game): clicking a mob row puts skull pins on the world map (`Map.lua`), opening the mob's main zone. "Clear pins" button and `/if clear`. World map only; no minimap pins or clustering.
- Map pins copy HereBeDragons-Pins (in Questie's `Libs`): a Lua pin pool in `WorldMapFrame.pinPools` + a `MapCanvasDataProviderMixin` provider. Pins must NOT set their own `OnEnter`/`OnLeave` scripts (the canvas asserts); define `OnMouseEnter`/`OnMouseLeave` methods instead.
- Drop rates from <= 10 kills are detected (exact k/n fractions in Wowhead data), shown with `*` and sorted after real rates.
- **Phase 3 done** (part 2 verified in game). Search results list matching favorites first, in gold. Favorite button (`LootwrightDB.favorites`, shown in gold above recent items), "Near lvl" filter (+/-5 levels, `LootwrightDB.nearLevel`) and "Friendly" checkbox (mobs friendly to your faction are hidden unless `LootwrightDB.showFriendly`; uses `Npc.friendlyToFaction`). Filters also apply to the tooltip line. (A separate farm list was added later, see below.)
- **Phase 5 done** (arrow verified in game in the same zone; across zones on one continent it points via world-position conversion, grey "In <zone>" otherwise): clicking a map pin sets a waypoint. Forever does NOT show the game's own waypoint arrow (`C_Map.SetUserWaypoint` + `C_SuperTrack` only gives a map ping; verified), so `Arrow.lua` draws our own arrow + distance from `C_Map.GetPlayerMapPosition` and `GetPlayerFacing`, both wrapped in `pcall` and checked with `issecretvalue`. Right-click clears it; it clears itself within 10 yards. Questie's public API (`Questie.API`: RegisterOnReady, RegisterForQuestUpdates, GetQuestObjectiveIconForUnit) has no custom pins, so our own pins stay. TomTom and HandyNotes are not installed, so no integration for them.
- **Farm list done** (verified in game; an item that is both farm and favorite shows as farm, green, which the user wants) (`Farm.lua`, `LootwrightDB.farm`): separate from favorites on purpose (favorites = bookmarks in the window; farm = short active list that changes the game world). "Farm" button next to Favorite; farm items green at the top of lists. Mobs that drop farm items get "Farm: <item> <rate> (have N)" on their in-game tooltip (unit `TooltipDataProcessor`, NPC ID from the GUID, out of combat only) and on mob rows in the window.
- **Farm goals done** (verified in game): a "Goal" box next to Farm (applied on Enter). `LootwrightDB.farm[id] = { goal = n }`. On `BAG_UPDATE_DELAYED`, items whose bag count (`C_Item.GetItemCount`) reaches the goal are removed, with a chat + screen message. Tooltip shows "(have 12/40)".
- **Professions done** (verified in game): `Prof.lua` reads the open profession window. **Forever uses the modern `C_TradeSkillUI` API** (log: "Saved 26 Tailoring recipes (modern profession API)"); the classic `GetTradeSkill*` path stays as a fallback. Saved into `LootwrightDB.prof[name-realm][profession]`. Known recipes only; no classic `GetCraft*` (old Enchanting UI). `ProfUI.lua` window (`/if prof` or the Professions button): recipes, materials with have/need for N crafts and their sources, "Farm materials" sets farm goals for missing, non-vendor-only materials. A full recipe list (unlearned recipes) would need Phase 6 data.
- **Tabs done** (verified in game; after farm/favorite changes `refreshItemRows` recolours the Search rows): the main window has bottom tabs Search / Professions / Farm (plain `UIPanelButtonTemplate` buttons below the frame; selected one uses `LockHighlight`). Each tab is a page frame covering the window; `ProfUI.Build(page)` and `FarmUI.Build(page)` build into theirs. The separate Professions window is gone. `UI.ShowTab(key)` switches and saves `LootwrightDB.tab`; `/if` reopens the last tab; `/if prof`, `/if farm`. Clicking a material or farm row calls `UI.ShowItem`, which switches to Search.
- **Recipe farm groups done** (verified in game, incl. crafted-material sub-levels): "Farm recipe" (Professions tab) adds `LootwrightDB.farmRecipes[key] = { name, itemId, makes, crafts, target = crafts x makes, reagents = {{itemId, count, vendorOnly}} }`. Farm tab shows the recipe row (crafted item have/target), its materials indented (have/need; vendor-only greyed with a tooltip), then single items. Materials never leave on their own; the whole group leaves when the bags hold `target` crafted items (absolute count). Recipes without a crafted item stay until removed. Crafted materials expand into their own materials (`sub` in the stored reagent, up to 3 levels, via `Prof.RecipeFor(itemId, prof)`: known recipe in the same profession first; vendor-only materials and loops aren't expanded). `Farm.Rows(r)` flattens a group with live needs: each level asks only for what's still missing (crafts left = ceil((wanted - in bags) / makes)), and a crafted material's sub-rows disappear once you have enough of it. Mob lines skip materials no recipe still needs. `Farm.Has` = single item or material (green colouring, mob tooltips); `Farm.IsSingle` = what the Search tab's Farm button toggles. Mob line: "Farm: X 43.7% (have 4/15) for Linen Bag".
- **Sub-goal notices and farm skulls done** (verified in game, incl. smaller grouped farm pins): `checkSubGoals` (Farm.lua) announces "Linen Bag: Bolt of Linen Cloth ready (6/6)." when a material goes from not ready to ready, and "Linen Bag: all materials ready. Craft it!" (state in memory; first sighting only records, so nothing fires at login). Ready rows get a green check on the Farm tab. Farm pins (Map.lua): skulls on every non-friendly mob that drops a single farm item or a farmable material still needed (`Farm.WantedItems`), on any map you view; rebuilt when the wanted set changes (signature check), sources and spawns cached; tooltip "Farm: X". Farm pins are smaller (10 px vs 14) and grouped on a fixed grid (`GROUP_CELL` = 4% of the map): one pin per cell at the average position, with a spawn count and a tooltip listing each mob kind and its count. Not zoom-aware. The selected mob's pins are never grouped. `/if farmpins` toggles (`LootwrightDB.farmPins`). "Clear pins" only clears the selected mob's pins.
- **Phase 8 done** (verified in game after the rename: `/if status` shows Lootwright_Data loaded on demand and Lootwright_Professions loaded; options panel and toggles work): sub-addons and an options panel.
  - Repo layout: the repo root is the `Lootwright` addon; `Lootwright_Data/` and `Lootwright_Professions/` are sub-addon folders inside it, each junctioned into AddOns on its own (`AddOns\Lootwright_Data`, `AddOns\Lootwright_Professions`). WoW ignores the nested copies inside `AddOns\Lootwright`.
  - Shared namespace: Core sets the global `LootwrightNS = ns`; sub-addon files start with `local ns = LootwrightNS` (+ `if not ns then return end`).
  - `Lootwright_Data` (`## LoadOnDemand: 1`): `GeneratedData.lua` (build script writes there). Read it only through `ns.GetGen()`, which loads it on first use and returns nil when it's off. Never read `ns.Gen` directly.
  - `Lootwright_Professions`: `Prof.lua`, `ProfUI.lua`. Without it the Professions tab button is hidden and `/if prof` explains.
  - `Options.lua`: canvas panel in Options > AddOns (`Settings.RegisterCanvasLayoutCategory`), `/if options`, and an Options button right of the tabs. Toggles (nil = on, false = off): `tooltip`, `farmTooltip`, `farmPins`, `arrow`, `farmAlerts` (screen messages; chat always). Shows each sub-addon's state.
- **Phase 9 (design) written, not yet verified in game:** the user chose design B, the "dark field guide" (`docs/design-preview-dark.png`, `tools/preview_dark.py`), with the Option E emblem (loot bag, dotted route, red X) from the user's art in `Art/` (zips, not committed). `tools/make_icons.py <sheet>` cuts it into `Media/emblem.tga`, `emblem_hover.tga`, `emblem_32.tga` (the numbered PNGs in the art zip are rough crops; use the reference sheet). `Theme.lua`: colours (`ns.Theme.C`), `Backdrop`, `Button`, `Pill` (`SetOn`; style "filter" green / "tab" blue), `StyleEditBox` (hides SearchBoxTemplate art), `StyleRow`, `Line`. Main frame: flat BackdropTemplate, 720x466; header with emblem, name, tagline, text tabs (`Theme.TextTab`: big text, the active one white with a brass underline on the header line; the user picked these over tab pills, which were too hard to see in game, and over tabs under the window), Options, close; the status line under the search box is one line only (it ran into the filter pills when it wrapped); pages start 26 px down so old page offsets still work. Item rows have icons and a recipe-use count; mob rows have rate bars. Callers of themed buttons/pills must use `HookScript` for OnEnter/OnLeave (SetScript would drop the hover border). `MinimapButton.lua`: `LootwrightMinimapButton` (name contains "MinimapButton", created at load, so MinimapButtonButton collects it); drag around the edge (`LootwrightDB.minimapAngle`), option `minimapButton`. The bound-ledger textures (parchment, leather, stitch, corner, crest, anvil) are unused now.
- **Phase 9 design done** (verified in game, commit 9a7fd0f).
- **Farm popup and tracker done** (verified in game): `FarmPopup.lua` replaces the Goal box: the Search tab's "Farm..." button (reads "Farming 12/40" for farmed items) opens a stack-split-like popup (goal as a bag count, - / +, mouse wheel, quick +10 / +20 / 1 stack / 2 stacks relative to what you have, Farm, No goal, Stop farming; Enter / Escape). `Tracker.lua` (EXPERIMENTAL, off by default: option `tracker` with `defaultOff`, or `/if mini`): an on-screen panel listing recipe groups with indented materials and single items, have/goal and thin bars; drag an item from your bags onto it to open the popup (`GetCursorInfo`, `OnReceiveDrag`); header drag moves, right-click locks, -/+ collapses; settings `trackerPos`, `trackerLocked`, `trackerCollapsed`. Rows are a pool of 20, then "+N more".
- **Phase 10 (release) in progress:** version 0.9.0 (Beta) in all three TOCs and `Core.lua`. `LICENSE` is the plain GPL-3.0 text (copied from ForeverDB's `COPYING.txt`, which is the unmodified FSF file, 35,149 bytes). Release: `python -I tools/build_data.py`, then `python -I tools/package.py` → `dist/Lootwright-<version>.zip` (built from each TOC's file list, plus `LICENSE` in every folder, `NOTICE.md`, and the Media textures the code references; checks versions match and listed files exist; `dist/` is git-ignored). CurseForge kit: `docs/curseforge/` (page guide with checklist, preview at https://claude.ai/artifact/NtzRngr1kdtr611nV8LMqc). The ForeverDB addon is not used by Lootwright at all (data is bundled), so the page must not list it as optional. Brand images use Inter (`tools/fonts/Inter-Variable.ttf`, OFL, downloaded with the user's OK from github.com/google/fonts). All 8 gallery screenshots are in `docs/curseforge/screens/` (cropped from the user's WoW `Screenshots` folder, `Z:\Blizzard\World of Warcraft\_forever_\Screenshots`; crops leave out character names, chat and other addons). Public repo: https://github.com/Simpeltronic/Lootwright (branch `main`; history rewritten before the first push to use the GitHub noreply email and mask the WoW account name; hashes in this file are the rewritten ones; local branch `backup-before-rewrite` keeps the old history and can be deleted). Ko-fi: https://ko-fi.com/simpeltron. Still open: upload.
- Pin clicks: an `OnMouseDown` script on the pin is allowed (RareScanner does it); only `OnEnter`/`OnLeave` scripts trip the canvas assert.

## Reading game output from here

- All `say()` output is also saved to `LootwrightDB.log` (last 500 lines). Read it after a `/reload` from `Z:\Blizzard\World of Warcraft\_forever_\WTF\Account\<ACCOUNT>\SavedVariables\Lootwright.lua`.
- `Logs\WoWChatLog.txt` (`/chatlog`) does not capture addon `print()` output. Lua errors are not in the log; they need BugSack or a screenshot.

## Environment facts

- **Game:** WoW Forever beta. TOC `## Interface: 16001`. A `_Forever.toc` suffix is also accepted.
- **Client:** Forever runs on the **modern (Midnight) client UI**, not Classic. Use modern APIs (`C_AddOns`, `C_Map`, `C_Timer`, `C_Item`, `Settings`, `BackdropTemplate`). Do not copy old Classic-only snippets.
- **Combat restrictions** of the modern client apply. Keep the UI out-of-combat and don't read protected data during fights.
- **Install path:** `Z:\Blizzard\World of Warcraft\_forever_\Interface\AddOns\Lootwright`
- **Project folder:** `I:\VibeStuff\Wow addons\ItemFinder`. The AddOns folder should be a junction to this folder (`mklink /J`), so there is one copy of the files.
- **Testing:** the game can't be run from here. After each change the user runs `/reload` and pastes any Lua errors back. `/console scriptErrors 1` shows them. There is no Lua installed in the cloud workspace, so syntax can't be checked there. If a local `luac`/`luajit` exists, use it with `-p`.

## Data sources (decided)

| What | Where | Notes |
|---|---|---|
| Item names, mobs that drop an item | `LibQuestieDB.Item` (`GetAllIds`, `name`, `npcDrops`, `objectDrops`, `vendors`) | Public API of the **QuestieDB** addon. Global `LibQuestieDB`. |
| Mob name, level range, rank, zone, spawns | `LibQuestieDB.Npc` (`name`, `minLevel`, `maxLevel`, `rank`, `zoneID`, `spawns`) | Spawns: `{ [areaId] = { {x, y, phase?}, ... } }`, x/y in percent; `(-1,-1)` = inside an instance. |
| Drop rate | QuestieDB support tables via `LibQuestieDB.Support.Get`: `QuestieClassicItemDrops` (`wowheadData`, `cmangosData`, Lua strings) and `QuestieItemDropCorrections` (`.Era`) | Lookup order copied from Questie's DropDB: correction, then cmangos, then wowhead. **Only quest items (~2k) have rates**, so most items show "rate ?". Questie itself is **not** used (Phase 6 decision). |

Contract check available: `LibQuestieDB.RequireContract(n)`.

### Do not do these

- **Do not use the `ForeverDB` global.** The installed `ForeverDB` addon is the foreverdb.net addon (CurseForge project 1725334). It keeps its data in a private namespace and exposes no global. (A different CurseForge project, "forever-db" by fatedfr, does expose one, but it is not installed and would clash by name.)
- **Do not scrape Wowhead.** Its terms forbid it.
- **Do not edit files in other addons' folders.**

### Remaining phases (see ROADMAP.md)

6 Dependency review, 7 Data improvements, 8 Modules and options (settings toggles + sub-addons `Lootwright_Data`, `Lootwright_Professions`; done), 9 Design (next), 10 Release. **Phase 6 done** (verified: `/if status` shows "contract: needs 4, OK"): QuestieDB is the only dependency; Questie removed. **Phase 7 done** (verified: `/if status` shows the ForeverDB data line; search filters tested): `tools/build_data.py` (run `python -I tools/build_data.py`) builds `GeneratedData.lua` (`ns.Gen`: `recipes`, `bossLoot`, `bosses`, `version`) from ForeverDB's `Recipes.lua`, `Loot.lua`, `Meta.lua`. Boss loot: a Forever-measured rate (source "foreverdb", with `kills`) beats QuestieDB's; bosses QuestieDB lacks are added. Professions tab shows every recipe, unlearned ones grey, "Known recipes only" checkbox. Credits in TOC, `/if status`, NOTICE.md. ForeverDB has no per-mob rates for normal mobs (that would need CMaNGOS loot tables, a download). Search filters: two rows of checkboxes under the search box, Reagents / Quest / Gear, then Other / Dungeon (`LootwrightDB.hideReagent`, `hideQuest`, `hideGear`, `hideOther`, `hideDungeon`). **Ticked = that kind is shown, all start ticked** (user's rule: ticking a box must add items, never remove them). Each item has exactly one kind, checked in order: reagent (used in any ForeverDB recipe, or classID 7 trade goods / 5 reagent), quest (12), gear (2, 4), other. Dungeon is separate (`ns.Gen.bossLoot`) and hides without GeneratedData.lua. Reagents are meant to be the addon's main selling point; item rows show "Used in N recipe(s)".

### ForeverDB data (licence)

ForeverDB's data files are GPL-3.0 with an attribution term: keep the `-- Data: ForeverDB.net` header line in any copied file, and credit "Data from ForeverDB.net (https://foreverdb.net)" in the addon's credits. `tools/build_data.py` generates our own data file from them; Lootwright never reads ForeverDB at runtime.

## Architecture

```
Lootwright/                    (the repo root; junctioned to AddOns\Lootwright)
  Lootwright.toc
  Core.lua          init, /if commands, saved-variables log, shared formatting, ns.GetGen
  Theme.lua         dark field guide look: colours, panels, buttons, pills, text tabs
  Data.lua          the ONLY file that reads QuestieDB (and ns.Gen boss loot)
  Search.lua        name index (built in chunks) + search
  UI.lua            main window: header tabs, Search tab, item tooltip line
  Map.lua           world map pins (selected mob + grouped farm skulls), waypoints
  Arrow.lua         waypoint arrow
  Farm.lua          farm list, goals, recipe groups, mob tooltip line, need cache
  FarmUI.lua        Farm tab
  FarmPopup.lua     "how many?" popup
  Tracker.lua       on-screen farm tracker (experimental)
  Options.lua       Options > AddOns panel
  MinimapButton.lua minimap button
  Media/            emblem.tga, emblem_hover.tga, emblem_32.tga (the only textures the game loads)
  Lootwright_Data/          sub-addon, load on demand: GeneratedData.lua (ForeverDB recipes, boss loot)
  Lootwright_Professions/   sub-addon: Prof.lua (scans), ProfUI.lua (Professions tab)
  tools/            build_data.py, make_icons.py, make_textures.py, make_brand.py, preview_dark.py
  docs/             phase summary, design previews, design brief, CurseForge kit, ledger textures (unused)
```

Performance rules (from the pre-release review): nothing heavy runs per frame; tooltip hooks must be cached (item line: `tipCache`; mob line: `Farm.Need` via `needCache`); farm needs are cached until `BAG_UPDATE` or a farm change; search uses a lowercase index built once; per-tick code avoids creating tables.

## Rules for working on this

- Keep `Data.lua` as the only code that knows the data format. The UI works with plain tables like `{ npcId, name, minLevel, maxLevel, rank, zone, rate, source }`.
- Build the name index in chunks with `C_Timer.After(0, ...)` so the game doesn't freeze. QuestieDB has about 26k+ items.
- Every integration (Questie rates, TomTom, HandyNotes) is optional. The addon must work without them.
- Be honest in the UI: say "rate unknown" instead of showing a made-up number.
- Add new commands and options to `/if` instead of making new slash commands.
- Commit after each working step.
- **Keep the pinned phase summary current.** Source: `docs/phases.html`, published at https://claude.ai/artifact/1MD63Q5spBKdr7nWjWXvK6 (pinned in the user's claude.ai sidebar). Whenever something significant changes for a phase (a phase finishes or starts, a feature lands in a phase, phases are added, reordered or renumbered, a known limit is found or fixed), edit `docs/phases.html` (status chip, contents, commit hashes, "Updated" date) and republish it to that URL with the Artifact tool in the same session. From a new conversation, publish with `url` set to that link (read it first) so the link stays the same.

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
