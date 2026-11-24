"""Merge shared loot data (from /if share, posted as GitHub issues with the loot-data label).

Keeps only the latest share per share ID (a share always holds all of that player's counts),
then adds the counts up per game build and writes tools/data/community_loot.json:
  { build: { npcId: { "n": corpses, "e": empty, "items": { itemId: corpses with it } } } }

Usage:
  python -I tools/merge_loot.py            reads the issues with gh
  python -I tools/merge_loot.py file.txt   reads share strings from a text file instead

Shared text is untrusted: only the strict format below is accepted, anything else is skipped.
The merged counts are open data under CC BY 4.0 (players agree to that on the share form; see NOTICE.md).
"""

import json
import pathlib
import re
import subprocess
import sys

REPO = "Simpeltronic/Lootwright"
OUT = pathlib.Path(__file__).resolve().parent / "data" / "community_loot.json"

SHARE = re.compile(r"!LW:1!([\w.\-]{1,20});([\w.\-]{1,20});([0-9a-f]{8});([0-9:;,=]*)!End:LW!")
MOB = re.compile(r"(\d{1,7}):(\d{1,6}):(\d{1,6}):((?:\d{1,7}=\d{1,6})(?:,\d{1,7}=\d{1,6})*)?")


def parse(text):
    """Yields (addon version, build, share id, {npc: {"n", "e", "items"}}) for each share in text."""
    for m in SHARE.finditer(text.replace("\n", "").replace("\r", "")):
        version, build, sid, body = m.groups()
        mobs = {}
        for part in filter(None, body.split(";")):
            mm = MOB.fullmatch(part)
            if not mm:
                continue
            npc, n, e, items = int(mm[1]), int(mm[2]), int(mm[3]), mm[4] or ""
            counts = {int(i): int(c) for i, c in (x.split("=") for x in filter(None, items.split(",")))}
            if e > n or any(c > n for c in counts.values()):
                continue  # impossible counts
            mobs[npc] = {"n": n, "e": e, "items": counts}
        yield version, build, sid, mobs


def merge(shares):
    """shares: [(build, who, mobs)] oldest first. Latest share per contributor wins; sums per build.

    who is the GitHub account that posted the issue (not the share ID inside the text, which the
    poster chooses), so one account counts once however many shares it posts.
    "by" = corpses per contributor, so build_data.py can check contributors over all builds.
    """
    latest = {}
    for build, who, mobs in shares:
        latest[who] = (build, mobs)
    out = {}
    for who, (build, mobs) in latest.items():
        b = out.setdefault(build, {})
        for npc, m in mobs.items():
            t = b.setdefault(npc, {"n": 0, "e": 0, "by": {}, "items": {}})
            t["by"][who] = m["n"]
            t["n"] += m["n"]
            t["e"] += m["e"]
            for item, c in m["items"].items():
                t["items"][item] = t["items"].get(item, 0) + c
    return out, len(latest)


def from_issues():
    raw = subprocess.run(
        ["gh", "issue", "list", "--repo", REPO, "--label", "loot-data", "--state", "all",
         "--limit", "1000", "--json", "number,createdAt,body,author"],
        capture_output=True, text=True, check=True).stdout
    for issue in sorted(json.loads(raw), key=lambda i: i["createdAt"]):
        yield (issue.get("author") or {}).get("login") or f"issue{issue['number']}", issue["body"] or ""


def self_check():
    s = "!LW:1!0.9.1;1.60.1;0a1b2c3d;3240:20:3:5128=9,5470=2;99:5:5:;7:1:0:1=9!End:LW!"
    (_, build, sid, mobs), = parse(s)
    assert build == "1.60.1" and sid == "0a1b2c3d", (build, sid)
    assert mobs == {3240: {"n": 20, "e": 3, "items": {5128: 9, 5470: 2}}, 99: {"n": 5, "e": 5, "items": {}}}, mobs
    old = {3240: {"n": 5, "e": 0, "items": {5128: 1}}}
    merged, players = merge([("1.60.1", "a", old), ("1.60.1", "a", mobs), ("1.60.1", "b", old)])
    assert players == 2 and merged["1.60.1"][3240] == {"n": 25, "e": 3, "by": {"a": 20, "b": 5}, "items": {5128: 10, 5470: 2}}, merged


def main():
    self_check()
    if len(sys.argv) > 1:  # a file you saved yourself (emailed shares): trusted, keyed by share ID
        texts = [(None, pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))]
    else:
        texts = list(from_issues())
    shares = [(build, who or sid, mobs) for who, text in texts for _, build, sid, mobs in parse(text)]
    merged, players = merge(shares)
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(merged, indent=1, sort_keys=True), encoding="utf-8")
    for build, mobs in sorted(merged.items()):
        corpses = sum(m["n"] for m in mobs.values())
        enough = sum(1 for m in mobs.values() if m["n"] >= 20)
        print(f"build {build}: {corpses} corpses, {len(mobs)} mob kinds ({enough} with 20+ corpses)")
    print(f"{len(shares)} shares from {players} players -> {OUT.relative_to(OUT.parent.parent.parent)}")
    print("Contributors: " + ", ".join(sorted({w for w, _ in texts if w})))


if __name__ == "__main__":
    main()
