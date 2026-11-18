# Lootwright design brief: "bound ledger"

## The addon

Lootwright is a World of Warcraft addon for **WoW Forever** (the modern WoW client running classic-era content). A player types an item name and sees which monsters drop it, where, at what level and how often. The player can then farm it: map markers, goals, and crafting recipes with their materials. **Crafting materials (reagents) are the main selling point.**

The name: a "wright" is a maker (shipwright, wheelwright). Lootwright is the craftsman who knows where every material comes from.

## The look

**A craftsman's bound ledger:** a leather-bound account book on a workbench. The window is the open book: a leather binding with a saddle stitch along the edge, small brass corner caps, and a parchment page with faint ledger lines that the data table sits on.

Mood: practical, warm and well made, like a tool someone uses daily. Not a treasure map and not a spellbook.

### Do
- Use real craft materials: tanned leather, linen-weave parchment, brass, waxed thread.
- Keep texture subtle: a fine grain that still reads at 100% scale and doesn't fight the text on top.
- Keep decoration at the edges: stitch, corners, header. The page centre stays calm so data is readable.
- Make it look used but cared for: even wear, no damage.

### Don't
- No burnt edges, coffee stains, torn paper, blood, skulls or heavy ageing.
- No ornate filigree, Celtic knots, gems or glowing runes.
- No Blizzard art, logos, fonts or textures copied in. Everything has to be original.
- No photographic realism with strong lighting. Light from the top left, soft, consistent.

## Window and layout

- Main window: **720 × 440 px** at 100% UI scale, plus tabs hanging 30 px below.
- Header band on the leather: crest (34 px), title "Lootwright", a small status on the right.
- Page: inset 18 px from the left and right, 50 px from the top.
- Left column, 200 px: search box, filter chips (Reagents, Quest, Gear, Dungeon), item list with icons and a "N recipes" tag.
- Right side: item header (icon, name, counts), a divider with the anvil glyph, then the mob table on ledger lines (Mob, Level, Zone, Drop with a rate bar).
- A thin red margin rule separates the two columns, as in an account book.
- Tabs below the binding: Search, Professions, Farm. The active tab is parchment, the others leather.

See `mockup-search-tab.png` for all of this put together.

## Palette

| Role | Hex |
|---|---|
| Parchment base | `#E9DCBC` |
| Parchment light (inputs, active tab) | `#F6ECD2` |
| Leather | `#4A3220` |
| Leather dark (header, inner ring) | `#3A2716` |
| Brass | `#C9A24A` |
| Brass highlight | `#F1D48A` |
| Brass shade | `#8A6A3A` |
| Ink (text on parchment) | `#3A2716` |
| Ledger rule | `#C9B48A` |
| Margin rule | `#B5574A` |
| Good drop rate | `#2F8A3A` |
| Middling drop rate | `#B8860B` |
| Farm item (green text) | `#1D7A2A` |

Item names in lists use WoW's item-quality colours (grey, white, green, blue, purple, orange). They aren't part of this palette and must stay readable on the parchment.

## Type

The game draws all text with its own fonts, so no font files are needed: Friz Quadrata (titles) and Arial Narrow (body). The mockup uses Georgia only as a stand-in. Art should leave room for text and contain no baked-in text, except optionally a "Lootwright" wordmark (see below).

## Assets wanted

All assets must be **original**. Sizes are **powers of two** (WoW requires this). Deliver **32-bit PNG with alpha**; they get converted to `.tga` for the game. Current placeholders are in `current-textures/`, at the same sizes and names.

| File | Size | Notes |
|---|---|---|
| `parchment` | 256 × 256 | Page background. **Must tile seamlessly** in both directions. Subtle fibre, no single features that repeat visibly. Opaque. |
| `leather` | 256 × 256 | Binding and header. **Must tile seamlessly.** Fine pebble grain. Opaque. |
| `stitch_h` | 64 × 8 | Saddle stitch, **tiles horizontally** (4 stitches per tile, even spacing). Transparent background, soft shadow. |
| `stitch_v` | 8 × 64 | Same stitch, vertical. |
| `corner` | 32 × 32 | Brass corner cap for the top-left corner (flipped in-game for the others): an L-shape about 6 px thick and 26 px long, with one rivet. Transparent background. |
| `crest` | 128 × 128 | The emblem: hammer over an anvil in a round brass ring on leather. Used on the title bar (shown at about 34 px), minimap button and AddOns list (about 20–32 px), so it must read when tiny. Transparent outside the ring. |
| `crest_64` | 64 × 64 | Same crest simplified for small sizes (thicker shapes, fewer details). |
| `anvil` | 16 × 16 | Small anvil glyph that sits in the middle of a horizontal divider line. Transparent. |

Nice to have, if the style holds up:

| File | Size | Notes |
|---|---|---|
| `tab_active` / `tab_inactive` | 128 × 32 | Tab shapes: parchment (active) and leather (inactive), rounded bottom corners, stitch optional. Stretch horizontally. |
| `chip_on` / `chip_off` | 64 × 16 | Filter "pill" backgrounds: leather with brass text space (on), pale parchment (off). |
| `badge_elite` | 64 × 16 | Small brass tag for "Elite" or "Boss" behind text. |
| `wordmark` | 256 × 64 | "Lootwright" lettered as if stamped in brass on leather, for an About panel or the CurseForge page. |

## Technical limits

- Powers of two only: 8, 16, 32, 64, 128, 256 or 512 px.
- The UI may be scaled down to about 65%, so details thinner than 2 px may vanish.
- Tiling textures repeat many times across the window: avoid any blob, stain or line that makes the repeat obvious.
- Colours should stay close to the palette, so text contrast holds.

## Files in this package

- `DESIGN-BRIEF.md`: this file.
- `mockup-search-tab.png`: the Search tab at real size, built from the current textures.
- `current-textures/*.png`: today's procedurally drawn placeholders, with the names and sizes above.
- `make_textures.py`: the script that drew the placeholders. It's for reference only, not needed for the art.
