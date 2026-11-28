"""One command for releases: bump the version, build everything, mark a release done.

  python -I tools/release.py                 build: shared loot, data, zip, checks, copies the changelog
  python -I tools/release.py data            data release: new shared-loot rates -> patch bump, changelog line, zip
  python -I tools/release.py bump patch     0.10.0 -> 0.10.1 (fixes, data rebuilds, tweaks)
  python -I tools/release.py bump minor      0.10.1 -> 0.11.0 (new features, options, data sources)
  python -I tools/release.py bump 1.0.0      an exact version
  python -I tools/release.py notes           copies the changelog section to the clipboard (build does it too)
  python -I tools/release.py released        dates the top CHANGELOG.md section (after uploading)

bump sets ## Version in the three TOCs and VERSION in Core.lua, and opens a
"## <version>, not released yet" section at the top of CHANGELOG.md if there isn't one.
The rules for which bump to use are in CLAUDE.md ("Versions and changelog").
"""

import datetime
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOCS = [ROOT / "Lootwright.toc", ROOT / "Lootwright_Data" / "Lootwright_Data.toc",
        ROOT / "Lootwright_Professions" / "Lootwright_Professions.toc"]
CORE = ROOT / "Core.lua"
CHANGELOG = ROOT / "CHANGELOG.md"
GENERATED = ROOT / "Lootwright_Data" / "GeneratedData.lua"
COMMUNITY = ROOT / "tools" / "data" / "community_loot.json"
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
            # leave out empty headings (bump opens New / Changed / Fixed)
            return re.sub(r"^### .*\n\s*(?=^### |\Z)", "", log[h.start():end].strip() + "\n", flags=re.M).strip()
    return None


def notes(version=None):
    """Copy this version's changelog (without its heading line) to the clipboard and save it to dist/."""
    version = version or current()
    text = section(version)
    if not text:
        raise SystemExit(f"CHANGELOG.md has no section for {version}")
    body = text.split("\n", 1)[1].strip() + "\n"
    out = ROOT / "dist" / f"changelog-{version}.md"
    out.parent.mkdir(exist_ok=True)
    out.write_text(body, encoding="utf-8")
    tries = ([["clip"]] if sys.platform == "win32" else [["wl-copy"], ["xclip", "-selection", "clipboard"]])
    for cmd in tries:
        try:
            data = body.encode("utf-16-le") if cmd == ["clip"] else body.encode("utf-8")
            if subprocess.run(cmd, input=data).returncode == 0:
                print(f"Changelog for {version} copied to the clipboard (also in {out.relative_to(ROOT)}).")
                return
        except FileNotFoundError:
            pass
    print(f"No clipboard tool found; open {out.relative_to(ROOT)} and copy it from there.")


def run(script):
    print(f"--- {script}")
    if subprocess.run([sys.executable, "-I", str(ROOT / "tools" / script)], cwd=ROOT).returncode:
        raise SystemExit(f"{script} failed")


def make_data():
    print("--- merge_loot.py (players' shared loot from GitHub)")
    r = subprocess.run([sys.executable, "-I", str(ROOT / "tools" / "merge_loot.py")], cwd=ROOT)
    if r.returncode:
        print("Couldn't fetch shared loot (no gh or no network); building with the last merged file.")
    run("build_data.py")


def community():
    """communityRates as the game will see it: {item: "npc:k:n;..."} read from GeneratedData.lua."""
    m = re.search(r"communityRates=\{([^}]*)\}", read(GENERATED))
    return dict(re.findall(r'\[(\d+)\]="([^"]*)"', m.group(1))) if m else {}


def data_line(rates, players):
    mobs = {e.split(":")[0] for v in rates.values() for e in v.split(";")}
    return (f"- **Updated drop rates from players:** {len(rates)} items on {len(mobs)} mobs now have rates "
            f"measured in Forever, from the shared loot of {players} players. Thank you!")


def with_data_line(log, version, line):
    """CHANGELOG.md with the data line in this version's Changed list (replacing an older data line)."""
    heads = list(SECTION.finditer(log))
    i = next(i for i, h in enumerate(heads) if h.group(1) == version)
    start, end = heads[i].end(), heads[i + 1].start() if i + 1 < len(heads) else len(log)
    body = re.sub(r"^- \*\*Updated drop rates from players:\*\*.*\n", "", log[start:end], flags=re.M)
    if "### Changed\n" in body:
        body = body.replace("### Changed\n", "### Changed\n" + line + "\n", 1)
    else:
        body = "\n\n### Changed\n" + line + "\n" + body.lstrip("\n")
    return log[:start] + body + log[end:]


def data_release():
    """Rebuild with the latest approved shares; if the community rates changed, bump the patch (unless a
    version is already waiting), add the changelog line and build the zip."""
    before = community()
    make_data()
    after = community()
    if after == before:
        print("\nCommunity rates didn't change: no data release needed. (GeneratedData.lua may still have "
              "changed if ForeverDB did; see git status.)")
        return
    top = SECTION.search(read(CHANGELOG))
    if not top or "not released yet" not in top.group(2):
        bump("patch")
    merged = json.loads(COMMUNITY.read_text(encoding="utf-8")) if COMMUNITY.exists() else {}
    players = len({w for b in merged.values() for m in b.values() for w in m.get("by", {})})
    write(CHANGELOG, with_data_line(read(CHANGELOG), current(), data_line(after, players)))
    finish()


def build():
    make_data()
    finish()


def finish():
    version = current()
    run("package.py")
    toc_versions = {TOC_VERSION.search(read(t)).group(1) for t in TOCS}
    if toc_versions != {version}:
        raise SystemExit(f"Core.lua says {version} but the TOCs say {sorted(toc_versions)}")
    text = section(version)
    if not text:
        raise SystemExit(f"CHANGELOG.md has no section for {version}: run bump or add one")
    print(f"\n--- Changelog for CurseForge ({version})\n{text}\n")
    notes(version)
    print(f"\nUpload dist/Lootwright-{version}.zip, then run: python -I tools/release.py released")


def self_check():
    assert next_version("0.10.0", "patch") == "0.10.1"
    assert next_version("0.10.3", "minor") == "0.11.0"
    assert next_version("0.10.0", "1.0.0") == "1.0.0"
    line = data_line({"5": "7:1:20;8:2:30", "6": "7:3:20"}, 3)
    assert line.startswith("- **Updated drop rates from players:** 2 items on 2 mobs") and "3 players" in line
    log = "# x\n\n## 0.2.0, not released yet\n\n### New\n\n### Changed\n- old\n- **Updated drop rates from players:** 1 item\n\n### Fixed\n\n## 0.1.0, 1 May\n\n### Changed\n- a\n"
    log = with_data_line(log, "0.2.0", "- **Updated drop rates from players:** new")
    assert log.count("Updated drop rates") == 1 and "### Changed\n- **Updated drop rates from players:** new\n- old\n" in log, log
    assert with_data_line("## 0.3.0, not released yet\n", "0.3.0", "- L") == "## 0.3.0, not released yet\n\n### Changed\n- L\n"
    real_read = globals()["read"]
    globals()["read"] = lambda p: log
    try:
        assert section("0.2.0") == "## 0.2.0, not released yet\n\n### Changed\n- **Updated drop rates from players:** new\n- old", section("0.2.0")
    finally:
        globals()["read"] = real_read


def main():
    self_check()
    args = sys.argv[1:]
    if not args or args == ["build"]:
        build()
    elif args[0] == "bump" and len(args) == 2:
        bump(args[1])
    elif args == ["data"]:
        data_release()
    elif args == ["notes"]:
        notes()
    elif args == ["released"]:
        released()
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
