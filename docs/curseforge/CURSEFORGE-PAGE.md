# Lootwright on CurseForge: page guide

Everything needed to set up Lootwright's CurseForge project: the images, the rules they follow, the text to paste, and the screenshots to take. Based on CurseForge's own guidelines and on how the most-downloaded WoW addon pages are built (Questie, Details!, WeakAuras, AtlasLoot, DBM). Sources are at the end.

Decisions already made: **links to GitHub and a donation page** (no Discord), a **practical, slightly warm tone**, a **crest-only logo**, and **real in-game screenshots**.

---

## 1. Files in this kit

| File | Size | Use |
|---|---|---|
| `logo-400.png` | 400 × 400 | The project avatar (upload as the logo). Opaque PNG. |
| `logo-crest.png` | 512 × 512 | The crest alone on transparent, for other places (GitHub, social). |
| `banner.png` | 1200 × 300 | The first image in the description. |
| `divider.png` | 1200 × 40 | Optional section break in the description. Use 2–3 times at most. |
| `CURSEFORGE-PAGE.md` | | This guide. |

All images are drawn by `tools/make_brand.py` from the addon's own textures (`tools/make_textures.py`), so they match the in-game window.

---

## 2. Logo rules

**What CurseForge requires**
- Square, **at least 400 × 400**, PNG. Larger images get scaled down.
- **Not WebP** (CurseForge has a known WebP bug).
- Not a plain colour, not another project's avatar, not a generic game logo, nothing copyrighted.

**How Lootwright uses it**
- The logo is **the crest only**: a hammer over an anvil in a brass ring, on stitched leather with brass corners. No text: the name sits right next to the logo everywhere on CurseForge and in the app, and text would be unreadable at search-result size.
- **Don't** stretch, recolour, outline, add glow or drop shadow, or put it on a busy background.
- **Minimum size:** the crest stays recognisable down to about 32 px. Below that, use the small 64 px crest from the art brief (`crest_64`) once it exists.
- **Clear space:** keep at least a quarter of the crest's width free around it when it's placed on other backgrounds.
- **Colours:** brass `#C9A24A`, highlight `#F1D48A`, shade `#8A6A3A`, leather `#4A3220`, parchment `#E9DCBC`. The full palette is in the design brief.

**Wordmark (banner only)**
- "Lootwright" in the banner is set in Georgia Bold as a **stand-in**. Georgia is a Microsoft font: fine for drafts, but **before the public release** replace it with an openly licensed face (for example a Google Fonts serif under the OFL licence, such as Cinzel or IM Fell English) or a hand-lettered wordmark from the artist, and re-run `tools/make_brand.py`.
- The tagline "Find it. Farm it. Craft it." may change; it lives in `tools/make_brand.py`.

---

## 3. Page design rules

**What the top pages do (and Lootwright copies)**
- An **H1 and a row of badges** first, then **one line that says what the addon is**. Every top page does this.
- **Short sections with headings:** WeakAuras' clean split (Features, Quick Start, Documentation, Problems, Support) is the model.
- A **"Quick start"** line with the slash command, like WeakAuras' "type `/wa`".
- **Screenshots in the Gallery tab**, each with a caption. Questie also puts a few inline under its feature headings; Lootwright does the same for its 3 main features.
- **Credits and team at the bottom; licence in the sidebar.**
- **Donation link small, at the bottom.** CurseForge's rules require donation and partner banners to be "civil in size and at the bottom of the page".

**What Lootwright avoids**
- Hype claims ("most powerful", "best"): Details! does this, but it doesn't fit our tone.
- Hit counters and big image buttons (they look dated on Details!).
- Long link lists at the top (DBM): Lootwright has two links, and they sit in one badge row.
- Stale info: AtlasLootClassic's page still lists versions from 2023. Update the page with every release.

**Layout and style**
- English first (CurseForge requires English before other languages).
- Use the **WYSIWYG** or **Markdown** editor; the text below is Markdown.
- Headings: H1 for the name only, H2 for sections, H3 for single features.
- Images: banner at the top, at most 3 inline screenshots, divider at most 3 times. Everything else in the Gallery.
- Write like the addon: plain sentences, the player's words (mobs, drops, farm, reagents), no jargon.
- Be honest about limits (rates are only known for some items). The addon itself says "rate unknown" instead of guessing; the page should too.
- **ForeverDB's credit must be visible on the page** (its licence requires it): keep the Credits section exactly as written below.

---

## 4. Project settings

| Field | Value |
|---|---|
| **Name** | Lootwright (unique on CurseForge as of Nov 2026; names must not contain the game name or a version) |
| **Summary** (one sentence) | Search any item to see which mobs drop it, where and how often, then farm it with map markers, goals and recipe material lists. |
| **Main category** | Professions |
| **Additional categories** (up to 4) | Map & Minimap, Tooltip, Bags & Inventory |
| **Licence** | GNU General Public License v3 (GPL-3.0). Required: Lootwright includes GPL-3.0 data from QuestieDB's ecosystem and ForeverDB. |
| **Game version** | WoW Forever (check which flavour CurseForge lists for Forever when uploading) |
| **Source** | Link to the public GitHub repository |
| **Issues** | Link to GitHub Issues |
| **Donation** | Link to the donation page (PayPal, Ko-fi, Patreon or similar) |

Before the first upload: the file must be a `.zip`, and the project needs one **Release** file before it shows in the CurseForge app.

---

## 5. Description (paste into the Markdown editor)

Replace the three placeholders: `GITHUB_URL`, `DONATE_URL`, and the image URLs once the images are uploaded to the project.

```markdown
![Lootwright](BANNER_IMAGE_URL)

# Lootwright

[![Source on GitHub](https://img.shields.io/badge/source-GitHub-4A3220?logo=github)](GITHUB_URL) [![Report a problem](https://img.shields.io/badge/issues-GitHub-8A6A3A)](GITHUB_URL/issues)

**Find it. Farm it. Craft it.** Type an item's name and Lootwright shows which mobs drop it, where they are, what level they are and how often it drops. Then put it on your farm list, and the mobs that drop it get marked on your map until you have enough.

Made for **WoW Forever**, with crafting materials front and centre.

## Features

### Find where anything drops
Search by name, or shift-click an item. See every mob that drops it with level, rank, zone and drop rate, best rates first and your own zone at the top. Filter by Reagents, Quest items, Gear or Dungeon boss drops.

![Search tab](SCREENSHOT_1_URL)

### Farm with goals
Add an item to your farm list and set a goal: "40 Linen Cloth". Mobs that drop it get a "Farm:" line on their tooltip and a skull on the world map. When your bags hold 40, it leaves the list by itself.

![Farm tab](SCREENSHOT_6_URL)

### Farm a whole recipe
Pick a recipe on the Professions tab and press **Farm recipe**. Lootwright lists every material as a goal, opens up crafted materials into what they're made from (Bolt of Linen Cloth into Linen Cloth), greys out what you buy from vendors, and tells you when each one is ready.

![Professions tab](SCREENSHOT_5_URL)

### Also
- **Map skulls and a waypoint arrow:** click a mob to mark its spawns; click a skull for an arrow and distance.
- **Tooltips:** "Drops from" on item tooltips, "Farm:" on mob tooltips.
- **Every recipe:** the Professions tab lists all recipes for every profession, and shows how to learn the ones you don't know yet.
- **Honest numbers:** boss drop rates measured in Forever with their kill counts. Rates based on very few kills are marked, and items with no known rate say so.

## Quick start

Type `/if` (or `/lootwright`) to open the window. `/if options` opens the settings, `/if help` lists every command.

## Requirements

- **QuestieDB** (required): Lootwright reads item, mob and map data from it. You don't need Questie itself.

## Parts you can switch off

Lootwright comes in three parts. Untick the ones you don't need in the AddOns list:
- **Lootwright:** search, farm list, map and tooltips.
- **Lootwright - Data:** every recipe and dungeon boss loot. Loads only when needed.
- **Lootwright - Professions:** the Professions tab.

Single features (tooltip lines, map skulls, the arrow, messages) can be turned off in `/if options`.

## Good to know

- Drop rates are known for quest items and dungeon bosses. Most other mobs show "rate unknown" rather than a guess.
- Profession recipes you know are read from your profession windows: open each one once.

## Problems and ideas

Report bugs and ideas on [GitHub Issues](GITHUB_URL/issues). If something breaks, type `/console scriptErrors 1`, reproduce it, and include the error text.

## Credits

- **Data from ForeverDB.net (https://foreverdb.net)**: recipes and dungeon boss loot with drop rates measured in WoW Forever.
- **QuestieDB** (https://github.com/Questie/QuestieDB): item, mob, spawn and map data.
- Some boss-loot rates come from CMaNGOS classic-db, via ForeverDB.

Lootwright is free software under the GPL-3.0 licence.

---

If Lootwright saves you some farming time, you can [buy me a coffee](DONATE_URL).
```

---

## 6. Screenshot shot list (Gallery)

CurseForge wants in-game screenshots with the addon enabled. Take them yourself; no edited or AI-made images (anything that could misrepresent the addon needs a visible disclaimer, so it's simpler not to use any).

**Setup for every shot**
- Resolution 1920 × 1080, UI scale at the game's default, other addons' frames hidden where they'd clutter the shot.
- A daytime outdoor zone with readable ground (Elwynn Forest, Westfall, The Barrens).
- Save as PNG. Crop to the subject with a little game world around it; don't crop so tight it looks like a mockup.
- Use the captions below as the image titles in the Gallery.

| # | Shot | Caption |
|---|---|---|
| 1 | Search tab: "Linen Cloth" selected, the Reagents filter visible, the mob table with rate bars | Find every mob that drops an item, best rates first |
| 2 | A mob in the world hovered, showing the green "Farm: Linen Cloth … (have 12/40)" tooltip line | Mobs you need are marked on their tooltip |
| 3 | World map of Westfall with grouped farm skulls; one skull hovered, showing its "N spawns here" tooltip | Farm skulls on the map, grouped by area |
| 4 | Walking towards a spawn with the waypoint arrow and distance on screen | Click a skull for an arrow to the spawn |
| 5 | Professions tab: a Tailoring recipe selected, materials with have/need and sources | Every recipe, and what it takes to make it |
| 6 | Farm tab: a recipe group with a crafted material opened up, one material with a green check, a vendor material greyed out | Farm a whole recipe, step by step |
| 7 | An item in the bags hovered, showing the "Drops from" tooltip line | Where an item drops, right on its tooltip |
| 8 | The options panel (Options > AddOns > Lootwright) | Switch off what you don't use |

Use shot 1 as the Gallery's first image: it's what people see in search results.

---

## 7. Release checklist

- [ ] Wordmark font replaced with an openly licensed one, banner re-rendered.
- [ ] `LICENSE` (GPL-3.0 text) added to the repository and the release zip.
- [ ] ForeverDB credit present in the description (section Credits) and in the addon (`/if status`, TOC, NOTICE.md).
- [ ] `tools/build_data.py` re-run right before packaging, so the data is current.
- [ ] Logo, banner and 8 screenshots uploaded; banner and inline screenshot URLs pasted into the description.
- [ ] GitHub and donation links filled in.
- [ ] One **Release** file uploaded (the app only shows projects with a release).

---

## Sources

- CurseForge, Project submission guide and tips: https://support.curseforge.com/en/support/solutions/articles/9000199552-project-submission-guide-and-tips
- CurseForge, Moderation policies: https://support.curseforge.com/en/support/solutions/articles/9000197279-moderation-policies
- CurseForge, Creating and submitting a project: https://support.curseforge.com/en/support/solutions/articles/9000197241-creating-and-submitting-a-project
- CurseForge, File project types and additional fields: https://support.curseforge.com/en/support/solutions/articles/9000197242-file-project-types-and-additional-fields
- Reference pages: Questie (https://www.curseforge.com/wow/addons/questie), Details! (https://www.curseforge.com/wow/addons/details), WeakAuras (https://www.curseforge.com/wow/addons/weakauras-2), AtlasLootClassic (https://www.curseforge.com/wow/addons/atlaslootclassic), Deadly Boss Mods (https://www.curseforge.com/wow/addons/deadly-boss-mods)
