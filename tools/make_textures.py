"""Draws Lootwright's "bound ledger" textures (Phase 9 design).

Writes to docs/ledger-textures/ (not used in game since design B was chosen):
  parchment.tga  256x256, tiles seamlessly    page background
  leather.tga    256x256, tiles seamlessly    binding / header background
  stitch_h.tga   64x8, tiles horizontally     saddle stitch along top/bottom edges
  stitch_v.tga   8x64, tiles vertically       saddle stitch along left/right edges
  corner.tga     32x32, with alpha            brass corner cap (top-left; flip for the others)
  crest.tga      128x128, with alpha          anvil-and-hammer crest (title, minimap, AddOns list)
  anvil.tga      16x16, with alpha            divider glyph
and docs/design-preview.png, a mock window built from those textures.

WoW loads .tga from addon folders; sizes are powers of two. PNG copies sit next to each .tga for
previewing. Deterministic (fixed seed), so re-running gives the same files.

Usage: python -I tools/make_textures.py
"""

import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
# The bound-ledger design isn't used in game any more (design B was chosen), so these textures live
# under docs/, out of the addon's Media folder. make_brand.py still reads them.
MEDIA = ROOT / "docs" / "ledger-textures"
rng = np.random.default_rng(7)

GOLD = (201, 162, 74)
GOLD_LIGHT = (241, 212, 138)
GOLD_DARK = (138, 106, 58)
LEATHER = (74, 50, 32)
INK = (58, 39, 22)


def tileable_noise(size, cells):
    """Smooth value noise that tiles: random grid, tiled 3x3, upscaled, centre cut out."""
    grid = rng.random((cells, cells))
    big = np.tile(grid, (3, 3))
    img = Image.fromarray((big * 255).astype(np.uint8)).resize((size * 3, size * 3), Image.BICUBIC)
    a = np.asarray(img, dtype=np.float32)[size:2 * size, size:2 * size] / 255.0
    return a - a.mean()


def save(img, name):
    MEDIA.mkdir(exist_ok=True)
    img.save(MEDIA / (name + ".tga"))
    img.save(MEDIA / (name + ".png"))
    return img


def parchment():
    s = 256
    n = 0.55 * tileable_noise(s, 4) + 0.30 * tileable_noise(s, 16) + 0.15 * tileable_noise(s, 64)
    fibre = tileable_noise(s, 128)  # fine speckle, then stretched sideways into fibres
    fibre = np.asarray(Image.fromarray(((fibre + 0.5) * 255).clip(0, 255).astype(np.uint8))
                       .filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float32) / 255 - 0.5
    base = np.array([233, 220, 188], dtype=np.float32)
    shade = (n * 26 + fibre * 10)[..., None]
    rgb = (base + shade * np.array([1.0, 0.95, 0.85])).clip(0, 255).astype(np.uint8)
    return save(Image.fromarray(rgb, "RGB").convert("RGBA"), "parchment")


def leather():
    return save(leather_image(), "leather")


def leather_image():
    """The leather texture without saving it (the crest uses it for its inner disc)."""
    s = 256
    n = 0.5 * tileable_noise(s, 6) + 0.5 * tileable_noise(s, 48)
    pebble = tileable_noise(s, 96)
    pebble = (pebble > 0.08).astype(np.float32) * -0.5  # small dark pores
    base = np.array(LEATHER, dtype=np.float32)
    shade = (n * 30 + pebble * 14)[..., None]
    rgb = (base + shade).clip(0, 255).astype(np.uint8)
    return Image.fromarray(rgb, "RGB").convert("RGBA")


def stitch():
    # 4x supersampled, then scaled down for smooth edges.
    k = 4
    w, h = 64 * k, 8 * k
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x0 in range(0, w, 16 * k):  # 4 stitches per tile, 10 px thread, 6 px gap
        d.rounded_rectangle([x0 + 3 * k + 2, 3 * k + 2, x0 + 13 * k + 2, 5 * k + 2], radius=k, fill=(20, 12, 6, 120))
        d.rounded_rectangle([x0 + 3 * k, 3 * k, x0 + 13 * k, 5 * k], radius=k, fill=GOLD + (230,))
        d.line([x0 + 4 * k, 3 * k + 2, x0 + 12 * k, 3 * k + 2], fill=GOLD_LIGHT + (220,), width=2)
    h_img = img.resize((64, 8), Image.LANCZOS)
    save(h_img, "stitch_h")
    return h_img, save(h_img.rotate(90, expand=True), "stitch_v")


def corner():
    k = 4
    s = 32 * k
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    t = 6 * k  # arm thickness
    L = 26 * k  # arm length
    d.rectangle([2 * k, 2 * k, L + 2 * k, 2 * k + t], fill=(20, 12, 6, 140))   # shadow
    d.rectangle([2 * k, 2 * k, 2 * k + t, L + 2 * k], fill=(20, 12, 6, 140))
    d.rectangle([0, 0, L, t], fill=GOLD + (255,))
    d.rectangle([0, 0, t, L], fill=GOLD + (255,))
    d.line([0, 0, L, 0], fill=GOLD_LIGHT + (255,), width=k)                     # top highlight
    d.line([0, 0, 0, L], fill=GOLD_LIGHT + (255,), width=k)
    d.line([t, t, L, t], fill=GOLD_DARK + (255,), width=k)                      # inner shade
    d.line([t, t, t, L], fill=GOLD_DARK + (255,), width=k)
    r = 2 * k
    c = t // 2
    d.ellipse([c - r, c - r, c + r, c + r], fill=GOLD_DARK + (255,))            # rivet
    d.ellipse([c - r + k // 2, c - r + k // 2, c + r - k, c + r - k], fill=GOLD_LIGHT + (255,))
    return save(img.resize((32, 32), Image.LANCZOS), "corner")


def anvil_shape(d, ox, oy, sc, fill):
    """Anvil silhouette in a 24x16 box at (ox, oy), scaled by sc."""
    pts = [(0, 3), (17, 3), (24, 7), (13, 7), (13, 10), (16, 10), (16, 13), (4, 13), (4, 10), (7, 10), (7, 7), (0, 7)]
    d.polygon([(ox + x * sc, oy + y * sc) for x, y in pts], fill=fill)


def crest(size=128, name="crest"):
    """The crest, drawn at 512 px and scaled to `size`. name=None returns it without saving."""
    k = 4
    s = 128 * k
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s // 2
    R = 60 * k
    d.ellipse([c - R + 2 * k, c - R + 3 * k, c + R + 2 * k, c + R + 3 * k], fill=(20, 12, 6, 150))  # shadow
    d.ellipse([c - R, c - R, c + R, c + R], fill=GOLD_DARK + (255,))
    d.ellipse([c - R + 2 * k, c - R + 2 * k, c + R - 2 * k, c + R - 2 * k], fill=GOLD + (255,))
    ri = R - 9 * k
    d.ellipse([c - ri, c - ri, c + ri, c + ri], fill=GOLD_DARK + (255,))
    ri2 = ri - 2 * k
    inner = Image.fromarray(np.asarray(leather_image().resize((s, s)))[..., :3]).convert("RGBA")
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse([c - ri2, c - ri2, c + ri2, c + ri2], fill=255)
    img.paste(inner, (0, 0), mask)
    # Hammer: handle, then head, angled over the anvil.
    hammer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hammer)
    hd.rounded_rectangle([c - 3 * k, c - 34 * k, c + 3 * k, c + 8 * k], radius=2 * k, fill=(160, 122, 70, 255))
    hd.rounded_rectangle([c - 13 * k, c - 42 * k, c + 13 * k, c - 30 * k], radius=2 * k, fill=GOLD_LIGHT + (255,))
    hd.rectangle([c - 13 * k, c - 33 * k, c + 13 * k, c - 30 * k], fill=GOLD + (255,))
    hammer = hammer.rotate(-35, center=(c, c + 6 * k), resample=Image.BICUBIC)
    img.alpha_composite(hammer, (6 * k, -2 * k))
    d = ImageDraw.Draw(img)
    sc = 3.1 * k
    ox, oy = c - 12 * sc, c - 1 * k
    anvil_shape(d, ox + 1.5 * k, oy + 2 * k, sc, (20, 12, 6, 170))
    anvil_shape(d, ox, oy, sc, GOLD + (255,))
    d.line([ox, oy + 3 * sc, ox + 17 * sc, oy + 3 * sc], fill=GOLD_LIGHT + (255,), width=k)
    out = img.resize((size, size), Image.LANCZOS)
    return save(out, name) if name else out


def anvil_glyph():
    k = 8
    img = Image.new("RGBA", (16 * k, 16 * k), (0, 0, 0, 0))
    anvil_shape(ImageDraw.Draw(img), 1 * k, 2 * k, 0.58 * k, GOLD_DARK + (255,))
    return save(img.resize((16, 16), Image.LANCZOS), "anvil")


def tile(tex, w, h):
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, tex.height):
        for x in range(0, w, tex.width):
            out.paste(tex, (x, y))
    return out


def font(size, bold=False):
    for name in (["georgiab.ttf", "georgia.ttf"] if bold else ["georgia.ttf"]) + ["arial.ttf"]:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def preview(parch, leath, sh, sv, corn, cr, anv):
    """A 720x470 mock of the Search tab, at the size the game window has."""
    W, H = 720, 440
    img = tile(leath, W, H + 30)
    d = ImageDraw.Draw(img)
    # Stitch along the binding, 6 px in from the edge.
    for x in range(6, W - 6, sh.width):
        img.alpha_composite(sh.crop((0, 0, min(sh.width, W - 6 - x), 8)), (x, 4))
        img.alpha_composite(sh.crop((0, 0, min(sh.width, W - 6 - x), 8)), (x, H - 12))
    for y in range(6, H - 6, sv.height):
        img.alpha_composite(sv.crop((0, 0, 8, min(sv.height, H - 6 - y))), (4, y))
        img.alpha_composite(sv.crop((0, 0, 8, min(sv.height, H - 6 - y))), (W - 12, y))
    # Page.
    page = tile(parch, W - 36, H - 70)
    pd = ImageDraw.Draw(page)
    for y in range(66, page.height, 18):  # ledger rules in the mob table
        pd.line([238, y, page.width - 10, y], fill=(201, 180, 138, 255), width=1)
    pd.line([232, 8, 232, page.height - 8], fill=(181, 87, 74, 160), width=1)  # margin rule
    img.alpha_composite(page, (18, 50))
    # Corners.
    img.alpha_composite(corn, (0, 0))
    img.alpha_composite(corn.transpose(Image.FLIP_LEFT_RIGHT), (W - 32, 0))
    img.alpha_composite(corn.transpose(Image.FLIP_TOP_BOTTOM), (0, H - 32))
    img.alpha_composite(corn.transpose(Image.ROTATE_180), (W - 32, H - 32))
    # Header.
    img.alpha_composite(cr.resize((34, 34), Image.LANCZOS), (22, 10))
    d.text((64, 15), "Lootwright", font=font(20, True), fill=GOLD_LIGHT)
    d.text((W - 200, 20), "Farm 3  ·  Goals 2", font=font(12), fill=(184, 154, 106))
    # Left column: search, filters, items.
    f12, f11, f14 = font(12), font(11), font(15, True)
    x0, y0 = 30, 62
    d.rounded_rectangle([x0, y0, x0 + 200, y0 + 22], radius=3, fill=(246, 236, 210), outline=(184, 154, 106))
    d.text((x0 + 8, y0 + 4), "cloth", font=f12, fill=(122, 96, 64))
    cx = x0
    for label, on in (("Reagents", True), ("Quest", False), ("Gear", False), ("Dungeon", False)):
        w = d.textlength(label, font=f11) + 14
        d.rounded_rectangle([cx, y0 + 30, cx + w, y0 + 48], radius=9,
                            fill=(90, 61, 30) if on else (216, 199, 158))
        d.text((cx + 7, y0 + 33), label, font=f11, fill=GOLD_LIGHT if on else INK)
        cx += w + 5
    items = [("Linen Cloth", (184, 184, 168), "14 recipes", True), ("Wool Cloth", (168, 154, 122), "22 recipes", False),
             ("Silk Cloth", (143, 143, 176), "31 recipes", False), ("Bolt of Linen Cloth", (200, 196, 180), "9 recipes", False)]
    for i, (name, col, tag, sel) in enumerate(items):
        y = y0 + 60 + i * 24
        if sel:
            d.rectangle([x0 - 2, y - 2, x0 + 202, y + 20], fill=(214, 195, 147))
        d.rectangle([x0 + 2, y + 1, x0 + 18, y + 17], fill=col, outline=(90, 61, 30))
        d.text((x0 + 24, y + 2), name, font=f12, fill=(29, 122, 42) if sel else INK)
        tw = d.textlength(tag, font=f11)
        d.rounded_rectangle([x0 + 200 - tw - 10, y + 1, x0 + 200, y + 17], radius=3, fill=(90, 61, 30))
        d.text((x0 + 200 - tw - 5, y + 2), tag, font=f11, fill=GOLD_LIGHT)
    # Right: item header and mob table on the ledger rules.
    rx = 268
    d.rectangle([rx, 62, rx + 30, 92], fill=(184, 184, 168), outline=(90, 61, 30))
    d.text((rx + 40, 62), "Linen Cloth", font=f14, fill=(43, 29, 18))
    d.text((rx + 40, 82), "200 mobs  ·  8 objects", font=f11, fill=(122, 96, 64))
    ay = 104
    img.alpha_composite(anv, (rx + 180, ay))
    d.line([rx, ay + 8, rx + 172, ay + 8], fill=GOLD_DARK, width=1)
    d.line([rx + 204, ay + 8, W - 40, ay + 8], fill=GOLD_DARK, width=1)
    heads = [("Mob", rx), ("Level", rx + 178), ("Zone", rx + 224), ("Drop", rx + 318)]
    for t, x in heads:
        d.text((x, 122), t, font=f11, fill=(138, 106, 58))
    rows = [("Defias Raider", "17-18", "Westfall", 0.708, "Elite"), ("Venture Co. Peon", "13-14", "The Barrens", 0.708, None),
            ("Burning Blade Acolyte", "11-12", "The Barrens", 0.712, None), ("Kobold Miner", "7-8", "Elwynn Forest", 0.22, None),
            ("Murloc Forager", "9-10", "Westfall", 0.12, None)]
    for i, (mob, lvl, zone, rate, rank) in enumerate(rows):
        y = 138 + i * 18 + 2
        d.text((rx, y), mob, font=f12, fill=INK)
        if rank:
            bx = rx + d.textlength(mob, font=f12) + 6
            d.rounded_rectangle([bx, y + 1, bx + 34, y + 14], radius=3, fill=GOLD)
            d.text((bx + 5, y + 1), rank, font=f11, fill=(43, 29, 18))
        d.text((rx + 178, y), lvl, font=f12, fill=INK)
        d.text((rx + 224, y), zone, font=f12, fill=INK)
        bar = (rx + 318, y + 4, rx + 378, y + 11)
        d.rounded_rectangle(bar, radius=3, fill=(205, 185, 138))
        good = rate >= 0.25
        d.rounded_rectangle([bar[0], bar[1], bar[0] + int(60 * rate), bar[3]], radius=3,
                            fill=(47, 138, 58) if good else (184, 134, 11))
        d.text((rx + 384, y), f"{rate * 100:.1f}%", font=f11, fill=(29, 122, 42) if good else (138, 106, 26))
    # Tabs hanging below the binding.
    tx = 20
    for label, on in (("Search", True), ("Professions", False), ("Farm", False)):
        w = d.textlength(label, font=f12) + 30
        d.rounded_rectangle([tx, H - 6, tx + w, H + 24], radius=5, fill=(233, 220, 188) if on else (90, 61, 30))
        d.text((tx + 15, H + 4), label, font=f12, fill=INK if on else (233, 220, 188))
        tx += w + 4
    out = ROOT / "docs" / "design-preview.png"
    img.save(out)
    return out


def main():
    p, l = parchment(), leather()
    sh, sv = stitch()
    c, cr, a = corner(), crest(), anvil_glyph()
    out = preview(p, l, sh, sv, c, cr, a)
    print("wrote", ", ".join(sorted(f.name for f in MEDIA.glob("*.tga"))), "and", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
