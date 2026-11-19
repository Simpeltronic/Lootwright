"""One command for releases: bump the version, build everything, mark a release done.

  python -I tools/release.py                 build: data, zip, checks, prints the changelog section
  python -I tools/release.py bump patch      0.10.0 -> 0.10.1 (fixes, data rebuilds, tweaks)
  python -I tools/release.py bump minor      0.10.1 -> 0.11.0 (new features, options, data sources)
  python -I tools/release.py bump 1.0.0      an exact version
  python -I tools/release.py released        dates the top CHANGELOG.md section (after uploading)

bump sets ## Version in the three TOCs and VERSION in Core.lua, and opens a
"## <version>, not released yet" section at the top of CHANGELOG.md if there isn't one.
The rules for which bump to use are in CLAUDE.md ("Versions and changelog").
"""

import datetime
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOCS = [ROOT / "Lootwright.toc", ROOT / "Lootwright_Data" / "Lootwright_Data.toc",
        ROOT / "Lootwright_Professions" / "Lootwright_Professions.toc"]
CORE = ROOT / "Core.lua"
CHANGELOG = ROOT / "CHANGELOG.md"
CORE_VERSION = re.compile(r'^local VERSION = "([^"]+)"', re.M)
TOC_VERSION = re.compile(r"^## Version:\s*(\S+)", re.M)
SECTION = re.compile(r"^## (\d+\.\d+\.\d+)\b(.*)$", re.M)


def read(p):
    return p.read_text(encoding="utf-8-sig")


def write(p, text):
    p.write_text(text, encoding="utf-8", newline="")


def current():
    return CORE_VERSION.search(read(CORE)).group(1)


def next_version(cur, how):
    if re.fullmatch(r"\d+\.\d+\.\d+", how):
        return how
    major, minor, patch = map(int, cur.split("."))
    if how == "patch":
        return f"{major}.{minor}.{patch + 1}"
    if how == "minor":
        return f"{major}.{minor + 1}.0"
    raise SystemExit("bump takes patch, minor or an exact version like 1.0.0")


def bump(how):
    cur = current()
    new = next_version(cur, how)
    for toc in TOCS:
        write(toc, TOC_VERSION.sub(f"## Version: {new}", read(toc), count=1))
    write(CORE, CORE_VERSION.sub(f'local VERSION = "{new}"', read(CORE), count=1))
    log = read(CHANGELOG)
    top = SECTION.search(log)
    if not top or top.group(1) != new:
        if top and "not released yet" in top.group(2):
            # The unreleased section moves to the new number (e.g. a patch turned into a minor).
            log = log[:top.start()] + f"## {new}{top.group(2)}" + log[top.end():]
        else:
            entry = f"## {new}, not released yet\n\n### New\n\n### Changed\n\n### Fixed\n\n"
            log = log[:top.start()] + entry + log[top.start():] if top else log + "\n" + entry
        write(CHANGELOG, log)
    print(f"Version {cur} -> {new} in the three TOCs, Core.lua and CHANGELOG.md.")
    print("Also update docs/changelog.html and republish it (see CLAUDE.md).")


def released():
    log = read(CHANGELOG)
    top = SECTION.search(log)
    if not top or "not released yet" not in top.group(2):
        raise SystemExit("The top CHANGELOG.md section isn't marked \"not released yet\".")
    date = datetime.date.today().strftime("%d %B %Y").lstrip("0")
    line = f"## {top.group(1)}{top.group(2).replace('not released yet', date)}"
    write(CHANGELOG, log[:top.start()] + line + log[top.end():])
    print(f"{top.group(1)} marked released on {date}. Update docs/changelog.html too.")


def section(version):
    """The CHANGELOG.md section for a version, to paste into CurseForge's changelog field."""
    log = read(CHANGELOG)
    heads = list(SECTION.finditer(log))
    for i, h in enumerate(heads):
        if h.group(1) == version:
            end = heads[i + 1].start() if i + 1 < len(heads) else len(log)
            return log[h.start():end].strip()
    return None


def build():
    version = current()
    for script in ("build_data.py", "package.py"):
        print(f"--- {script}")
        r = subprocess.run([sys.executable, "-I", str(ROOT / "tools" / script)], cwd=ROOT)
        if r.returncode:
            raise SystemExit(f"{script} failed")
    toc_versions = {TOC_VERSION.search(read(t)).group(1) for t in TOCS}
    if toc_versions != {version}:
        raise SystemExit(f"Core.lua says {version} but the TOCs say {sorted(toc_versions)}")
    text = section(version)
    if not text:
        raise SystemExit(f"CHANGELOG.md has no section for {version}: run bump or add one")
    print(f"\n--- Changelog for CurseForge ({version})\n{text}")
    print(f"\nUpload dist/Lootwright-{version}.zip, then run: python -I tools/release.py released")


def self_check():
    assert next_version("0.10.0", "patch") == "0.10.1"
    assert next_version("0.10.3", "minor") == "0.11.0"
    assert next_version("0.10.0", "1.0.0") == "1.0.0"


def main():
    self_check()
    args = sys.argv[1:]
    if not args or args == ["build"]:
        build()
    elif args[0] == "bump" and len(args) == 2:
        bump(args[1])
    elif args == ["released"]:
        released()
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
