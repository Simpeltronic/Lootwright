"""Final frames (F2 thick + bone inner line): frame_target.png (brass), frame_farm.png (green), and frames_final_on_map.png.
Run: python make_frames_final.py <scratch dir containing map_crop.png> [A|B]   (A = dark 1px + bone 2px, B = bone 3px; default chosen below)"""
import os, sys, subprocess, ast
from PIL import Image, ImageDraw, ImageFont
OUT = os.path.dirname(os.path.abspath(__file__)); SCR = sys.argv[1]; MODE = sys.argv[2] if len(sys.argv) > 2 else "A"
DARK, BRASS, GREEN, BONE = "#14171C", "#C9A24A", "#4FD36A", "#E8E4D8"; S = 8
OUTL, BAND = 3, 10
LAYERS = {"A": [(1, DARK), (2, BONE)], "B": [(3, BONE)]}[MODE]
INSET = OUTL + BAND + sum(w for w, _ in LAYERS)
def frame(col):
    im = Image.new("RGBA", (64*S, 64*S), (0,0,0,0)); d = ImageDraw.Draw(im); o = 0
    for w, c in [(OUTL, DARK), (BAND, col)] + LAYERS:
        d.rectangle([o*S, o*S, (64-o)*S-1, (64-o)*S-1], fill=c); o += w
    d.rectangle([o*S, o*S, (64-o)*S-1, (64-o)*S-1], fill=(0,0,0,0))
    return im.resize((64,64), Image.LANCZOS)
frames = {"target": frame(BRASS), "farm": frame(GREEN)}
if __name__ == "__main__":
    for k, f in frames.items(): f.save(os.path.join(OUT, f"frame_{k}.png"))
    shot = Image.open(r"Z:\Blizzard\World of Warcraft\_forever_\Screenshots\WoWScrnShot_112426_103914.jpg").convert("RGB").crop((22,842,38,858))
    def trim(im): w = im.width; return im.crop((w*0.08, w*0.08, w*0.92, w*0.92))
    def flat(c, e): im = Image.new("RGB", (16,16), e); ImageDraw.Draw(im).rectangle([2,2,13,13], fill=c); return im
    ICONS = [("silk", trim(shot)), ("ore grey", trim(flat("#8a8f98", "#3c4048"))), ("herb green", trim(flat("#3f9a2f", "#1d4a14"))), ("dark", trim(flat("#2b2433", "#15101a")))]
    def pin(kind, icon, size):
        b = Image.new("RGBA", (64,64), (0,0,0,0)); b.paste(icon.resize((64-2*INSET,)*2, Image.LANCZOS).convert("RGBA"), (INSET, INSET)); b.alpha_composite(frames[kind]); return b.resize((size, size), Image.LANCZOS)
    base = Image.open(os.path.join(SCR, "map_crop.png")).convert("RGBA")
    pts = ast.literal_eval(subprocess.check_output([sys.executable, "-I", os.path.join(OUT, "find_skulls.py"), os.path.join(SCR, "map_crop.png")], text=True).splitlines()[1])
    farm_pts = [p for p in pts if p[0] < 560 and p[1] > 60]; tgt_pts = [(140,95),(300,250),(420,190),(250,330),(470,265)]
    # extra farm pins for a 30+ density test: jitter copies on a loose grid across the canyon
    import random; random.seed(2); extra = [(x+random.randint(-14,14), y+random.randint(-12,12)) for x, y in farm_pts for _ in range(2)]
    FARM, TGT = 13, 15; font = ImageFont.load_default(size=14); panels = []
    for name, fp_ in (("Final frame, 12 farm pins + 5 target pins", farm_pts), ("Density test: 36 farm pins + 5 target pins", farm_pts + extra)):
        im = base.copy()
        for n, (x, y) in enumerate(fp_): im.alpha_composite(pin("farm", ICONS[n % 4][1], FARM), (x-FARM//2, y-FARM//2))
        for n, (x, y) in enumerate(tgt_pts): im.alpha_composite(pin("target", ICONS[n % 4][1], TGT), (x-TGT//2, y-TGT//2))
        zoom = im.crop((60,20,500,360)).resize((880,680), Image.NEAREST)
        row = Image.new("RGBA", (835+880+30, 715), (20,23,28,255)); d = ImageDraw.Draw(row)
        d.text((10,8), name + "  (left: real size, farm 13 px / target 15 px; right: 2x; icons cycle silk / ore / herb / dark)", fill=(232,228,216,255), font=font)
        row.paste(im, (10,30)); row.paste(zoom, (855,30)); panels.append(row)
    W = panels[0].width; strip = Image.new("RGBA", (W, 190), (217,201,163,255)); sd = ImageDraw.Draw(strip)
    sd.text((10,6), "Strip: final frames at 64 / 14 / 12 px, empty window, then each icon (brass = target, green = farm)", fill=DARK, font=font)
    y = 30
    for kind in ("target", "farm"):
        sd.text((10, y+20), kind, fill=DARK, font=font); x = 90
        f = frames[kind]; strip.alpha_composite(f, (x, y)); x += 90
        for sz in (14, 12): strip.alpha_composite(f.resize((sz, sz), Image.LANCZOS), (x, y+25)); x += 30
        x += 30
        for _, ic in ICONS:
            for sz in (64, 14, 12): strip.alpha_composite(pin(kind, ic, sz), (x, y + (64-sz)//2)); x += sz + 12
            x += 30
        y += 78
    out = Image.new("RGBA", (W, sum(p.height for p in panels) + strip.height), (20,23,28,255)); y = 0
    for p in panels + [strip]: out.paste(p, (0, y)); y += p.height
    out.convert("RGB").save(os.path.join(OUT, "frames_final_on_map.png")); print(MODE, INSET, len(farm_pts))
