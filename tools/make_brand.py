"""Draws Lootwright's CurseForge images into docs/curseforge/.

  logo-400.png       400x400 project avatar: the crest on stitched leather (CurseForge: >= 400x400, 1:1, PNG)
  logo-crest.png     512x512 crest on transparent, for other uses
  banner.png         1200x300 header for the top of the description
  divider.png        1200x40 section divider (thin brass rule with the anvil)

Reuses the textures from tools/make_textures.py, so run that first (it writes docs/ledger-textures/).
The wordmark uses Georgia Bold as a stand-in face; see docs/curseforge/CURSEFORGE-PAGE.md.

Usage: python -I tools/make_brand.py
"""

import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import make_textures as mt  # noqa: E402  (same folder)

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "curseforge"
MEDIA = ROOT / "docs" / "ledger-textures"  # written by make_textures.py


def load(name):
    return Image.open(MEDIA / (name + ".png")).convert("RGBA")


def stitched_leather(w, h, inset=10):
    img = mt.tile(load("leather"), w, h)
    sh, sv = load("stitch_h"), load("stitch_v")
    for x in range(inset, w - inset, sh.width):
        part = sh.crop((0, 0, min(sh.width, w - inset - x), sh.height))
        img.alpha_composite(part, (x, inset - 2))
        img.alpha_composite(part, (x, h - inset - sh.height + 2))
    for y in range(inset, h - inset, sv.height):
        part = sv.crop((0, 0, sv.width, min(sv.height, h - inset - y)))
        img.alpha_composite(part, (inset - 2, y))
        img.alpha_composite(part, (w - inset - sv.width + 2, y))
    return img


def corners(img, size=32):
    c = load("corner")
    if size != c.width:
        c = c.resize((size, size), Image.LANCZOS)
    w, h = img.size
    img.alpha_composite(c, (0, 0))
    img.alpha_composite(c.transpose(Image.FLIP_LEFT_RIGHT), (w - size, 0))
    img.alpha_composite(c.transpose(Image.FLIP_TOP_BOTTOM), (0, h - size))
    img.alpha_composite(c.transpose(Image.ROTATE_180), (w - size, h - size))


def logo(big_crest):
    img = stitched_leather(400, 400, inset=14)
    corners(img, 48)
    img.alpha_composite(big_crest.resize((300, 300), Image.LANCZOS), (50, 50))
    img.convert("RGB").save(OUT / "logo-400.png")  # opaque, no transparency surprises on the site


def banner(big_crest):
    w, h = 1200, 300
    img = stitched_leather(w, h, inset=14)
    corners(img, 48)
    img.alpha_composite(big_crest.resize((210, 210), Image.LANCZOS), (70, 45))
    d = ImageDraw.Draw(img)
    title, tag = mt.font(96, True), mt.font(30)
    d.text((316, 70), "Lootwright", font=title, fill=mt.GOLD_LIGHT)
    d.line([320, 186, 1110, 186], fill=mt.GOLD_DARK, width=2)
    d.text((320, 204), "Find it. Farm it. Craft it.", font=tag, fill=(233, 220, 188))
    img.convert("RGB").save(OUT / "banner.png")


def divider():
    w, h = 1200, 40
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    anvil = load("anvil").resize((32, 32), Image.LANCZOS)
    mid = w // 2
    d.line([40, h // 2, mid - 30, h // 2], fill=mt.GOLD_DARK + (255,), width=2)
    d.line([mid + 30, h // 2, w - 40, h // 2], fill=mt.GOLD_DARK + (255,), width=2)
    img.alpha_composite(anvil, (mid - 16, 4))
    img.save(OUT / "divider.png")


def main():
    if not (MEDIA / "leather.png").exists():
        raise SystemExit("Run tools/make_textures.py first.")
    OUT.mkdir(parents=True, exist_ok=True)
    big = mt.crest(512, None)
    big.save(OUT / "logo-crest.png")
    logo(big)
    banner(big)
    divider()
    print("wrote", ", ".join(sorted(p.name for p in OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
