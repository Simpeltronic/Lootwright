# Lootwright map pins: design brief

Lootwright is a WoW Forever addon. It marks mobs on the world map with small pins. Today they use the game's raid skull; we want our own, simple pins in the Lootwright look.

## The look

- "Dark field guide": flat dark UI, brass accents, item-quality colours as the only bright colours.
- Emblem: a loot bag, a dotted route and a red X ("loot is here"). Pins can borrow the X or the route.
- Colours: dark `#14171C`, brass `#C9A24A`, farm green `#4FD36A`, bone `#E8E4D8`, emblem red `#C0392B`.
- Simple shapes, thick outlines, no gradients or fine detail. They must read at **10 px** on a busy, parchment-coloured map.

## Pins needed

| File | Use | Shown at |
|---|---|---|
| `pin_target.tga` | the mob you clicked on the Search tab (one per spawn) | 14 px |
| `pin_farm.tga` | grouped spawns of mobs you're farming (a count is drawn next to it in code) | 10 px |

The two must be easy to tell apart (for example brass for the clicked mob, green for farm spawns).

## Ideas to try (3 to 5 options per pin is plenty)

1. A skull inside a ring (brass ring / green ring).
2. The emblem's red X, alone or on a small dark disc.
3. A diamond marker: brass diamond with a skull, small green gem for farm spawns.

## Delivery

- 64 x 64 px, transparent background, centred, a little padding.
- PNG for review; final files as 32-bit TGA (uncompressed, with alpha) for WoW.
- Put them in `Media/` of the Lootwright project (`I:\VibeStuff\Wow addons\ItemFinder\Media\`), plus one preview sheet showing all options at 64, 14 and 10 px on a parchment background.
- The pins ship in the addon under GPL-3.0. If AI tools made them, say so (r/wowaddons asks for an "AI Disclaimer").
