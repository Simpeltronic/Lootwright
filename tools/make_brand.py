"""Draws Lootwright's CurseForge images into docs/curseforge/ in the dark field guide style,
with the Option E emblem (loot bag, dotted route, red X).

  logo-400.png    400x400 project avatar: the emblem on the dark panel (CurseForge: >= 400x400, 1:1, PNG)
  logo-crest.png  512x512 emblem on transparent, for GitHub and other places
  banner.png      1200x300 header for the top of the description
  divider.png     1200x24 section divider (thin line with a brass accent)

Needs docs/emblem-master.png (tools/make_icons.py).
Text uses Inter (tools/fonts/Inter-Variable.ttf, SIL Open Font License 1.1, from github.com/google/fonts).

Usage: python -I tools/make_brand.py
"""

import pathlib

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "curseforge"

BG = (20, 23, 28)
PANEL = (26, 30, 37)
LINE = (47, 53, 64)
TEXT = (214, 218, 225)
MUTED = (138, 147, 163)
WHITE = (255, 255, 255)
BRASS = (201, 162, 74)


FONT = pathlib.Path(__file__).resolve().parent / "fonts" / "Inter-Variable.ttf"  # SIL OFL 1.1, see fonts/OFL.txt


def font(size, bold=False):
    """Inter (openly licensed, fine for public images). Variable font: weight 700 or 400."""
    f = ImageFont.truetype(str(FONT), size)
    f.set_variation_by_axes([min(32, max(14, size)), 700 if bold else 400])  # optical size, weight
    return f


def emblem(size):
    return Image.open(ROOT / "docs" / "emblem-master.png").convert("RGBA").resize((size, size), Image.LANCZOS)


def logo():
    s = 400
    img = Image.new("RGBA", (s, s), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, s - 1, s - 1], outline=LINE, width=2)
    # A soft panel disc behind the emblem so it doesn't float on flat black.
    d.ellipse([22, 22, s - 22, s - 22], fill=PANEL, outline=LINE, width=2)
    img.alpha_composite(emblem(320), (40, 40))
    img.convert("RGB").save(OUT / "logo-400.png")


def banner():
    w, h = 1200, 300
    img = Image.new("RGBA", (w, h), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], outline=LINE, width=2)
    img.alpha_composite(emblem(220), (60, 40))
    d.text((320, 58), "Lootwright", font=font(92, True), fill=WHITE)
    d.rectangle([324, 178, 324 + 150, 181], fill=BRASS)  # the one warm accent, like the in-game tab underline
    d.line([474, 179, 1130, 179], fill=LINE, width=2)
    d.text((324, 196), "Find any item. Farm what you need.", font=font(32), fill=TEXT)
    d.text((326, 244), "SEARCH   ·   TRACK   ·   FARM   ·   CRAFT", font=font(18, True), fill=MUTED)
    img.convert("RGB").save(OUT / "banner.png")


def divider():
    w, h = 1200, 24
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line([40, h // 2, w - 40, h // 2], fill=LINE + (255,), width=2)
    d.rectangle([w // 2 - 60, h // 2 - 1, w // 2 + 60, h // 2 + 1], fill=BRASS + (255,))
    img.save(OUT / "divider.png")


def main():
    if not (ROOT / "docs" / "emblem-master.png").exists():
        raise SystemExit("Run tools/make_icons.py first (it writes docs/emblem-master.png).")
    OUT.mkdir(parents=True, exist_ok=True)
    emblem(512).save(OUT / "logo-crest.png")
    logo()
    banner()
    divider()
    print("wrote", ", ".join(sorted(p.name for p in OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
