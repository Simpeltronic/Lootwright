# Lootwright idea bank

Ideas that were tried or discussed but put aside. Each says what it was, why it was shelved, and what was learned, so it can be picked up later.

## Making room for other addons' map pins (shelved 24 Nov 2026)

**Idea:** Lootwright's map pins shouldn't cover Questie's or RareScanner's pins.

**Tried:**
1. Nudge our pins sideways (up to three pin widths) when they overlap another addon's pin. Still overlapped a little in game.
2. Hide our pin where it overlaps, and add its info to the other pin's tooltip instead ("Lootwright: Silk Cloth (need 8)"). Didn't work in game (commit 89b0417, removed in the next commit).

**Learned:**
- `WorldMapFrame:EnumerateAllPins()` lists every addon's pins; `pin.normalizedX/Y` and `pin.pinTemplate` tell where and whose.
- Questie draws through HereBeDragons: the canvas pin holds Questie's icon frame in `pin.icon`, with its own `OnEnter`. Its data has `Type = "monster"` and `ObjectiveTargetId` (the NPC) on kill objectives.
- Questie rebuilds its map tooltip itself (`GameTooltip._Rebuild`), which may wipe lines added from outside. Probably why the tooltip lines didn't show.
- Overlap is in screen pixels, so it changes with map zoom; a check at draw time isn't enough.

**If picked up again:** check Questie's tooltip code (`Modules/FramePool/QuestieFramePool.lua`, `Map/` hover files) for a supported way to add lines, and re-check overlaps on zoom.

## Questie kill-quest mobs that drop farm items (shelved with the above)

**Idea:** when Questie tells you to kill a mob that also drops something you're farming, say so on Questie's pin, e.g. "Lootwright: also drops Silk Cloth 12% (have 4/15)". Tooltip line only, never drawing on Questie's icon. Only with Questie installed.

**Status:** built together with the overlap work and removed with it. Needs the same working way into Questie's tooltip.
