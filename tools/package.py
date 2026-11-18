"""Builds the release zip: dist/Lootwright-<version>.zip with the three addon folders.

Only what the game needs goes in, taken from each TOC's file list:
  Lootwright/              Lootwright.toc, its .lua files, Media/*.tga, LICENSE, NOTICE.md
  Lootwright_Data/         Lootwright_Data.toc, GeneratedData.lua, LICENSE
  Lootwright_Professions/  Lootwright_Professions.toc, its .lua files, LICENSE
Left out: docs/, tools/, Art/, CLAUDE.md, ROADMAP.md, git files, and the sub-addon folders that sit
inside the repo root (they get their own top-level folders in the zip).

Checks before writing: every file a TOC lists exists, all TOC versions match, and the media
the code references exists. Run tools/build_data.py first so the data is current.

Usage: python -I tools/package.py
"""

import pathlib
import re
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"

ADDONS = {
    "Lootwright": ROOT,
    "Lootwright_Data": ROOT / "Lootwright_Data",
    "Lootwright_Professions": ROOT / "Lootwright_Professions",
}
EXTRA = {  # files the TOC doesn't list but the release should carry, per addon
    "Lootwright": ["LICENSE", "NOTICE.md"],
    "Lootwright_Data": [],
    "Lootwright_Professions": [],
}


def toc_info(folder, name):
    toc = folder / (name + ".toc")
    text = toc.read_text(encoding="utf-8-sig")
    files = [ln.strip() for ln in text.splitlines() if ln.strip() and not ln.startswith("#")]
    m = re.search(r"^## Version:\s*(\S+)", text, re.M)
    return toc, files, m.group(1) if m else None


def main():
    problems, entries, versions = [], [], {}
    for name, folder in ADDONS.items():
        toc, files, version = toc_info(folder, name)
        versions[name] = version
        entries.append((toc, f"{name}/{toc.name}"))
        for rel in files:
            path = folder / rel.replace("\\", "/")
            if not path.exists():
                problems.append(f"{name}: TOC lists {rel}, which doesn't exist")
            entries.append((path, f"{name}/{rel.replace(chr(92), '/')}"))
        for rel in EXTRA[name]:
            path = ROOT / rel
            if not path.exists():
                problems.append(f"{name}: missing {rel}")
            entries.append((path, f"{name}/{rel}"))
        # The licence goes in every folder, so each one stands on its own.
        if "LICENSE" not in EXTRA[name]:
            entries.append((ROOT / "LICENSE", f"{name}/LICENSE"))

    # Textures: everything the code points at under Media/.
    code = "\n".join(p.read_text(encoding="utf-8") for p in ROOT.glob("*.lua"))
    media = sorted(set(re.findall(r'MEDIA \.\. "(\w+)"', code)))
    for tex in media:
        path = ROOT / "Media" / (tex + ".tga")
        if not path.exists():
            problems.append(f"Media/{tex}.tga is used in code but missing")
        entries.append((path, f"Lootwright/Media/{tex}.tga"))
    icon = ROOT / "Media" / "emblem.tga"  # the TOC's IconTexture
    if (icon, "Lootwright/Media/emblem.tga") not in entries:
        entries.append((icon, "Lootwright/Media/emblem.tga"))

    if len(set(versions.values())) != 1:
        problems.append(f"TOC versions differ: {versions}")
    if problems:
        print("Not packaged:\n  " + "\n  ".join(problems))
        sys.exit(1)

    version = versions["Lootwright"]
    DIST.mkdir(exist_ok=True)
    out = DIST / f"Lootwright-{version}.zip"
    seen = set()
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for path, arc in entries:
            if arc in seen:
                continue
            seen.add(arc)
            z.write(path, arc)
    print(f"{out.relative_to(ROOT)}: {len(seen)} files, {out.stat().st_size // 1024} KB, version {version}")
    for arc in sorted(seen):
        print("  " + arc)


if __name__ == "__main__":
    main()
