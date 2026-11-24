# Lootwright changelog

Versions follow the rules in `CLAUDE.md` ("Versions and changelog"). Newest first.

## 0.15.2, 24 November 2026

### Changed
- **Loot counting pauses while you're in a group:** with group loot rules (rolls, round robin, master loot) the loot isn't all yours, and empty kills can't be told from "not your turn", so grouped counts made drop rates come out too high. Nothing is recorded in a group any more; it resumes when you leave. Counts you already have stay as they are.

### For developers
- `tools/merge_loot.py` marks shares from addon versions older than 0.15.2 in the review lists and prints the already-approved ones (they may include group loot).

## 0.15.1, 24 November 2026

### Fixed
- **Quest items no longer turn mobs grey:** Lootwright never counts quest items in your loot (they drop only while you're on the quest), so after 20 corpses it read "0 seen" and marked every mob "Not seen in your loot": grey, last in the list and without map pins. Quest items are now left out of that check, and the mob tooltip says "Quest item: not counted in your loot" instead of "0 of 13 corpses".

## 0.15.0, 24 November 2026

### New
- **Click to share:** the thank-you line in chat at login now has a clickable "[Share your loot data]" that opens the share window, like Questie's links. `/if share` still works.

### Changed
- **The share reminder is a chat line with a click link now,** not a window in the middle of the screen. If you were in combat at login, or play a long session without logging in again, it appears at your next loading screen (a zone change or instance) once you have 100 or more new counted corpses. It shows at most once per session, and only if you turned on loot counting.
- **Boss loot and recipes refreshed** from ForeverDB.net (24 November 2026): about 230 more boss-loot items.
- **New option "Share reminder as a pop-up window"** (off by default) in Options > General: tick it to get the small reminder window in the middle of the screen instead of the chat line.

### For developers
- `tools/merge_loot.py`: only a plain `x` in the form sheet's OK column approves a row; one form row counts as one player; a form share is linked to a GitHub account only for the repo owner's own shares. Steps in `docs/loot-review.md`.

## 0.14.0, 24 November 2026

### New
- **Drop rates from players:** loot that Lootwright players share with `/if share` now becomes drop rates for everyone, once a mob has 20 or more looted corpses in the shared data, from at least two players. They are measured in Forever, so they take priority over the other rates. The mob tooltip says "Measured in Forever by Lootwright players: 9 of 40 corpses". Mobs only players have seen dropping an item are added to the list. Your own counts still fill in where the shared data has fewer than 20 corpses. Shares are reviewed before they count, and numbers that don't fit other players' are left out.

### Changed
- **Sharing loot no longer needs a GitHub account:** the `/if share` window now links to a simple web form. Shares are still reviewed before they count.

### For developers
- `tools/merge_loot.py` also reads the form's sheet (`tools/data/form_shares.csv`, only rows with `x` in the OK column). See `docs/loot-review.md`.
- `LibLootwright.CommunityRates(itemId)` (added to contract 1): `{ [npcId] = { k, n } }` from shared loot. `tools/release.py` fetches the latest shares before building.

## 0.13.0, 24 November 2026

### New
- **Hide the map checkbox:** a new option hides the small "Lootwright" checkbox in the map's corner, if it covers something. Your pins still follow the "Lootwright pins on the world map" option.

### Changed
- **Options in groups:** the Options panel now has headings (Tooltips, World map, Farming, General), with the four map options together, and shorter labels.

## 0.12.0, 24 November 2026

### New
- **Map checkbox:** a "Lootwright" checkbox in the world map's bottom-right corner shows or hides Lootwright's pins (also in Options).
- **A thank-you at login** for players who help build drop rates, with how many corpses you've counted so far.
- **Map pins with more than one farm item:** when mobs on one pin drop several things you're farming, the pin shows the item you still need most, with a small light-gold "+1" (or "+2") badge at its corner. Hover lists every farm item with its icon and how many you still need.
- **New map pins:** the item you're hunting, shown round on a light disc with a dark rim: brass for the mob you clicked on the Search tab, green for farm spawns (now 12 px, with the spawn count beside it, not on top). Replaces the raid skull, so Lootwright's pins no longer look like other addons' markers and stand out on orange maps.

### Changed
- Options, messages and help text say "map pins" instead of "skulls", and the Options labels are clearer.
- **Each character has its own farm list.** Goals, endless items and recipe groups are now saved per character. The first character you log in with after this update keeps your current list; your other characters start with an empty one. Favorites, recent items and loot counts stay shared.
- **Bank that completes a goal shows in light gold:** when your bags plus your bank reach the goal, the bank part of the count and the bar turn light gold instead of light green, so you can see you already have enough, waiting in the bank.
- **Goals below what you have add on top:** in the farm popup, a number at or below your bag count is added to it (you have 30, type 1: farm to 31). The line next to the box shows it in light gold, e.g. "+1 on top (goal 31)". Bank items still show in brackets on the Farm tab.
- **Finished goals stay until you remove them.** When you reach a farm goal, the item turns gold with a check (name, count and a full gold bar) on the Farm tab and the tracker, instead of disappearing. Its mobs lose their map pins and "Farm:" line. Press Remove when you're done with it.
- **Finished recipes too:** when you've crafted enough, the recipe row turns gold and stays until you remove it; its material rows go away.

### Fixed
- Farming something your profession can craft (like Bolt of Silk Cloth) added it as a plain item instead of its recipe, when the game reported an empty realm name. Lootwright now asks the game which professions you have.

## 0.11.0, 24 November 2026

### New
- **Endless farming:** leave the goal box empty (or press Endless) to keep farming an item without a set goal. On the Farm tab and the tracker it shows "32 · 1 stack", and the bar fills toward the next full stack, then starts over.

### Changed
- The farm popup's "No goal" button is now called "Endless".

## 0.10.0, 19 November 2026

### New
- **Drop rates for normal mobs** from CMaNGOS classic-db (Classic 1.12 data, drops of 1% and up, 4,545 items). Shown as rough rates with "~" and sorted after real rates, because they match only 38% of rates measured in Forever.
- **Many more mobs in search results.** Mobs only CMaNGOS lists are added: 8,075 drops on 1,555 items were missing, and 1,173 items showed no mobs at all. Cloth now lists every mob instead of about 200.
- **Welcome window** on first start: what Lootwright does, with two opt-ins, both off until you tick them: the farm tracker, and helping improve drop rates. `/if welcome` shows it again.
- **Help improve drop rates (opt-in):** Lootwright counts what you loot, on your PC only: looted corpses, empty kills and what was on them, per mob. Mob tooltips in the window show "You: 9 of 40 corpses". `/if loot` shows a summary.
- **Shared loot data is open data** (CC BY 4.0): the share form and window say so, so other addons and sites can use the merged counts with credit.
- **Share reminder:** players who opted in get a small "Share your loot data?" window at login after every 100 new corpses, with Share now and Later.
- **Your loot judges the list.** After 20 corpses of a mob, your measured rate replaces an unknown or rough one, and a mob that never dropped the item turns grey and moves to the bottom ("Not seen in your loot").
- **Share your loot data** with `/if share`: copy the text into the "Share loot data" form on GitHub to help work out real Forever drop rates for everyone.
- **Crafted materials in trade-skill blue** on the Farm tab and the tracker, with a "Usually crafted" tooltip.
- **Bank counts on the Farm tab:** "1(2) / 3" means 1 in your bags and the bank can cover the other 2; the bar fills the bank part in a lighter green. Same on the on-screen tracker. The tooltip gives the exact bank count. Goals still count bags and equipped only. Open your bank once per session so the game knows what's in it.
- **Farm a recipe from the Search tab:** for an item your profession can craft, Farm adds its recipe, with the materials as a group, the same as the Professions tab. The goal box still counts the item, and the popup shows how many crafts that is.
- **One colour rule for farm items:** green = farm it from mobs, blue = crafted, grey = vendor only, gold = recipe. Single farm items now use it too, on the Farm tab and the tracker.
- **Craft tag in the Search list:** a small blue "craft" next to items a recipe makes, and a "Crafted: Tailoring (...)" tooltip line.

### Changed
- The Search tab's footer names all rate sources and explains "~".
- The farm tracker is no longer experimental. It stays off until you turn it on (welcome window, `/if mini` or Options).
- Recipe farming only breaks a crafted material into its own materials if your character has that profession.

### Fixed
- Farming a recipe for something you already own (a bag you wear, armour you have on) no longer finishes at once: the goal now counts on top of what you own when you add it.

### For developers
- `tools/build_data.py` reads the CMaNGOS dump (`tools/data/`, not in git) and prints how well a rate source agrees with rates measured in Forever.
- `tools/merge_loot.py` reads shared loot data from GitHub issues.
- **LibLootwright:** `Lootwright_Data` is now a library other addons can depend on without Lootwright: drop rates, boss loot and recipes through a small API with a contract number (see `Lootwright_Data/API.lua`).
- `tools/release.py`: one command to bump the version, build the data and zip, and print the changelog for CurseForge.
- `/if loot debug`, `/if loot target`, `/if loot reset` for testing.

## 0.9.0 (Beta), 18 November 2026

First public release on CurseForge.
- Item search with every mob that drops it: level, rank, zone, drop rate, your zone first.
- Map skulls on spawns, waypoint arrow, farm list with goals, recipe farming with sub-materials, ready notices.
- Professions tab with every recipe (ForeverDB data), dungeon boss loot with rates measured in Forever.
- Options panel, minimap button, the "dark field guide" look, experimental farm tracker.
