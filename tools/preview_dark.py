"""Renders docs/design-preview-dark.png: the "dark field guide" Search tab (design B) with the
Option E emblem in the header. A design preview only; the game draws the real window in Lua.

Needs Media/emblem.png (tools/make_icons.py). Usage: python -I tools/preview_dark.py
"""

import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent

BG = (20, 23, 28)
PANEL = (26, 30, 37)
LINE = (47, 53, 64)
TEXT = (214, 218, 225)
MUTED = (138, 147, 163)
WHITE = (255, 255, 255)
BRASS = (201, 162, 74)
GREEN = (79, 211, 106)
GREEN_DIM = (30, 42, 34)
GREEN_EDGE = (47, 107, 60)
YELLOW = (255, 209, 0)
SEL = (29, 42, 63)
BLUE = (110, 162, 255)


def font(size, bold=False):
    for name in (["segoeuib.ttf"] if bold else []) + ["segoeui.ttf", "arial.ttf"]:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def pill(d, x, y, text, f, fill=None, outline=None, color=TEXT, pad=8, h=20):
    w = d.textlength(text, font=f) + 2 * pad
    d.rounded_rectangle([x, y, x + w, y + h], radius=h // 2, fill=fill, outline=outline)
    d.text((x + pad, y + 2), text, font=f, fill=color)
    return x + w


def main():
    W, H = 720, 440
    img = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, H - 1], outline=LINE)
    f11, f12, f13, f16 = font(11), font(12), font(13), font(17, True)

    # Header: emblem, name, tagline, tabs as pills, close.
    emblem = Image.open(ROOT / "Media" / "emblem.png").convert("RGBA").resize((34, 34), Image.LANCZOS)
    img.alpha_composite(emblem, (12, 8))
    d.text((54, 9), "Lootwright", font=f16, fill=WHITE)
    d.text((55, 29), "Find any item. Farm what you need.", font=f11, fill=MUTED)
    x = 400
    x = pill(d, x, 15, "Search", f12, fill=SEL, color=BLUE) + 6
    x = pill(d, x, 15, "Professions", f12, outline=LINE, color=MUTED) + 6
    x = pill(d, x, 15, "Farm", f12, outline=LINE, color=MUTED) + 6
    d.text((W - 24, 13), "×", font=font(18), fill=MUTED)
    d.line([0, 50, W, 50], fill=LINE)
    d.line([12, 50, 120, 50], fill=BRASS, width=2)  # the one warm accent, under the emblem

    # Left column.
    x0, y0 = 12, 62
    d.rounded_rectangle([x0, y0, x0 + 208, y0 + 24], radius=4, fill=PANEL, outline=LINE)
    d.text((x0 + 10, y0 + 4), "cloth", font=f12, fill=MUTED)
    cx = x0
    for label, on in (("Reagents", True), ("Quest", False), ("Gear", False), ("Dungeon", False)):
        cx = pill(d, cx, y0 + 32, label, f11, fill=GREEN_DIM if on else None, outline=GREEN_EDGE if on else LINE,
                  color=GREEN if on else MUTED, pad=7, h=18) + 4
    d.text((x0, y0 + 56), "4 matches, 12 hidden by filters", font=f11, fill=MUTED)
    items = [("Linen Cloth", (154, 154, 138), 14, True), ("Wool Cloth", (138, 125, 99), 22, False),
             ("Silk Cloth", (127, 127, 168), 31, False), ("Bolt of Linen Cloth", (176, 170, 150), 9, False)]
    for i, (name, col, n, sel) in enumerate(items):
        y = y0 + 76 + i * 24
        if sel:
            d.rounded_rectangle([x0 - 2, y - 2, x0 + 210, y + 20], radius=3, fill=SEL)
        d.rounded_rectangle([x0 + 2, y + 1, x0 + 19, y + 18], radius=3, fill=col, outline=LINE)
        d.text((x0 + 26, y + 1), name, font=f13, fill=GREEN if sel else TEXT)
        tag = str(n)
        tw = d.textlength(tag, font=f11)
        d.rounded_rectangle([x0 + 206 - tw - 10, y + 2, x0 + 206, y + 17], radius=3,
                            outline=GREEN_EDGE if sel else LINE)
        d.text((x0 + 206 - tw - 5, y + 2), tag, font=f11, fill=GREEN if sel else MUTED)
    d.line([232, 50, 232, H - 1], fill=LINE)

    # Right: item header, mob table.
    rx = 246
    d.rounded_rectangle([rx, 62, rx + 32, 94], radius=4, fill=(154, 154, 138), outline=LINE)
    d.text((rx + 42, 61), "Linen Cloth", font=font(16, True), fill=WHITE)
    d.text((rx + 42, 81), "200 mobs  ·  8 objects  ·  used in 14 recipes", font=f11, fill=MUTED)
    bx = W - 12
    for label in ("Favorite", "Farm"):
        w = d.textlength(label, font=f12) + 20
        d.rounded_rectangle([bx - w, 66, bx, 88], radius=4, outline=LINE, fill=PANEL)
        d.text((bx - w + 10, 69), label, font=f12, fill=TEXT)
        bx -= w + 6
    d.line([rx, 104, W - 12, 104], fill=LINE)
    cols = [("MOB", rx), ("LVL", rx + 196), ("ZONE", rx + 244), ("DROP", rx + 352)]
    for t, cxx in cols:
        d.text((cxx, 110), t, font=font(10, True), fill=MUTED)
    rows = [("Defias Raider", "Elite", "17-18", YELLOW, "Westfall", 0.708), ("Venture Co. Peon", None, "13-14", GREEN, "The Barrens", 0.708),
            ("Burning Blade Acolyte", None, "11-12", GREEN, "The Barrens", 0.712), ("Kobold Miner", None, "7-8", (154, 163, 178), "Elwynn Forest", 0.22),
            ("Murloc Forager", None, "9-10", (154, 163, 178), "Westfall", 0.12)]
    for i, (mob, rank, lvl, lc, zone, rate) in enumerate(rows):
        y = 130 + i * 24
        if i % 2 == 1:
            d.rectangle([rx - 4, y - 3, W - 12, y + 19], fill=PANEL)
        d.text((rx, y), mob, font=f13, fill=TEXT)
        if rank:
            px = rx + d.textlength(mob, font=f13) + 6
            pill(d, px, y + 1, rank, f11, outline=(107, 90, 20), color=YELLOW, pad=5, h=16)
        d.text((rx + 196, y), lvl, font=f13, fill=lc)
        d.text((rx + 244, y), zone, font=f13, fill=TEXT)
        good = rate >= 0.25
        bar0 = rx + 352
        d.rounded_rectangle([bar0, y + 6, bar0 + 56, y + 12], radius=3, fill=(38, 43, 51))
        d.rounded_rectangle([bar0, y + 6, bar0 + int(56 * rate), y + 12], radius=3, fill=GREEN if good else YELLOW)
        d.text((bar0 + 62, y), f"{rate * 100:.1f}%", font=f11, fill=GREEN if good else YELLOW)

    # Footer.
    d.line([232, H - 30, W, H - 30], fill=LINE)
    d.text((rx, H - 24), "Rates: QuestieDB and ForeverDB.net data", font=f11, fill=MUTED)
    d.text((W - 150, H - 24), "Options", font=f11, fill=BLUE)
    out = ROOT / "docs" / "design-preview-dark.png"
    img.convert("RGB").save(out)
    print("wrote", out.relative_to(ROOT))


if __name__ == "__main__":
    main()
