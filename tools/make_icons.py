"""Cuts Lootwright's emblem (Option E: loot bag, route, red X) out of the designer's reference sheet
and writes the in-game icons into Media/.

Source: the Option E reference sheet from Art/Lootwright-Minimap-Icon-Handoff.zip
(00_option_E_reference_sheet.png). The numbered 64 px PNGs in that zip are rough crops, so the
large "Default" and "Hover" emblems on the sheet are used as masters instead.

Writes Media/:
  emblem.tga         64x64   default emblem (minimap button, window header)
  emblem_hover.tga   64x64   brighter, for the button's highlight
  emblem_32.tga      32x32   small version
and docs/emblem-master.png (512x512, transparent) for reference.

Usage: python -I tools/make_icons.py <path to 00_option_E_reference_sheet.png>
"""

import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
MEDIA = ROOT / "Media"

# Rough boxes around the big emblems on the 1254 px sheet; the ring is found inside them.
BOXES = {"default": (22, 188, 348, 514), "hover": (338, 196, 640, 498)}


def find_ring(img):
    """Centre and outer radius of the gold ring: the extent of bright gold pixels."""
    a = np.asarray(img.convert("RGB")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    gold = (r > 150) & (g > 100) & (b < 110) & (r - b > 70)
    # Ignore the label text under the emblem: keep rows above the bottom 12% of the box.
    gold[int(gold.shape[0] * 0.88):, :] = False
    ys, xs = np.nonzero(gold)
    # The bottom of the ring may be hidden with the label, so measure the width and the top edge.
    x0, x1, y0 = xs.min(), xs.max(), ys.min()
    radius = (x1 - x0) / 2
    return (x0 + x1) / 2, y0 + radius, radius


def cut(sheet, box, size=512):
    region = sheet.crop(box)
    cx, cy, r = find_ring(region)
    r += 1  # include the ring's outer anti-aliased edge
    sq = region.crop((round(cx - r), round(cy - r), round(cx + r), round(cy + r))).resize((size, size), Image.LANCZOS)
    k = 4  # smooth circular mask, drawn 4x and scaled down
    mask = Image.new("L", (size * k, size * k), 0)
    ImageDraw.Draw(mask).ellipse([2 * k, 2 * k, size * k - 2 * k, size * k - 2 * k], fill=255)
    sq.putalpha(mask.resize((size, size), Image.LANCZOS))
    return sq, (cx, cy, r)


def save(img, name):
    MEDIA.mkdir(exist_ok=True)
    img.save(MEDIA / (name + ".tga"))
    img.save(MEDIA / (name + ".png"))


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    sheet = Image.open(sys.argv[1]).convert("RGBA")
    if sheet.size != (1254, 1254):
        raise SystemExit(f"Expected the 1254x1254 Option E sheet, got {sheet.size}.")
    default, ring = cut(sheet, BOXES["default"])
    hover, _ = cut(sheet, BOXES["hover"])
    default.save(ROOT / "docs" / "emblem-master.png")
    save(default.resize((64, 64), Image.LANCZOS), "emblem")
    save(hover.resize((64, 64), Image.LANCZOS), "emblem_hover")
    save(default.resize((32, 32), Image.LANCZOS), "emblem_32")
    print("ring centre/radius in box:", tuple(round(v, 1) for v in ring))
    print("wrote Media/emblem.tga, emblem_hover.tga, emblem_32.tga and docs/emblem-master.png")


if __name__ == "__main__":
    main()
