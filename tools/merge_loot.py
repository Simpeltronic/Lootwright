"""Merge shared loot data (from /if share, posted as GitHub issues with the loot-data label).

Only approved issues count: ones you gave the loot-ok label (only repo maintainers can add labels)
and that weren't edited after you added it, or that you posted yourself. An approved issue edited
later goes back to waiting: remove and add the label again after checking it. The others are listed as waiting, with the poster's account age, to review.
Keeps only the latest share per GitHub account (a share always holds all of that player's counts),
then adds the counts up per game build and writes tools/data/community_loot.json:
  { build: { npcId: { "n": corpses, "e": empty, "items": { itemId: corpses with it },
                      "by": { account: { "n": corpses, "items": {...} } } } } }

Usage:
  python -I tools/merge_loot.py            reads the issues with gh
  python -I tools/merge_loot.py file.txt   reads share strings from a text file instead

Shared text is untrusted: only the strict format below is accepted, anything else is skipped.
The merged counts are open data under CC BY 4.0 (players agree to that on the share form; see NOTICE.md).
"""

import csv
import io
import json
import pathlib
import re
import subprocess
import sys

REPO = "Simpeltronic/Lootwright"
OWNER = REPO.split("/")[0]
APPROVED = "loot-ok"
OUT = pathlib.Path(__file__).resolve().parent / "data" / "community_loot.json"
FORM = OUT.parent / "form_shares.csv"  # the Google Form sheet, exported as CSV

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
            t["by"][who] = {"n": m["n"], "items": dict(m["items"])}
            t["n"] += m["n"]
            t["e"] += m["e"]
            for item, c in m["items"].items():
                t["items"][item] = t["items"].get(item, 0) + c
    return out, len(latest)


def gh(*args):
    return subprocess.run(["gh", *args], capture_output=True, text=True, check=True).stdout


def approved_unedited(number):
    """True when the issue has the loot-ok label and its text wasn't edited after the label was
    last added, so an approval covers only what you reviewed. Labels are visible in the issue's timeline."""
    owner, name = REPO.split("/")
    q = ('query($o:String!,$n:String!,$i:Int!){repository(owner:$o,name:$n){issue(number:$i){lastEditedAt '
         'timelineItems(itemTypes:[LABELED_EVENT],last:50){nodes{... on LabeledEvent{createdAt label{name}}}}}}}')
    issue = json.loads(gh("api", "graphql", "-f", f"query={q}", "-f", f"o={owner}", "-f", f"n={name}",
                          "-F", f"i={number}"))["data"]["repository"]["issue"]
    labelled = [e["createdAt"] for e in issue["timelineItems"]["nodes"] if (e.get("label") or {}).get("name") == APPROVED]
    if not labelled:
        return False
    edited = issue.get("lastEditedAt")
    return edited is None or edited < max(labelled)  # ISO 8601 UTC strings sort as times


def from_issues():
    """(approved [(account, body)], waiting [(issue, account, body)]), oldest first."""
    raw = gh("issue", "list", "--repo", REPO, "--label", "loot-data", "--state", "all",
             "--limit", "1000", "--json", "number,createdAt,body,author,labels")
    approved, waiting = [], []
    for issue in sorted(json.loads(raw), key=lambda i: i["createdAt"]):
        who = (issue.get("author") or {}).get("login") or f"issue{issue['number']}"
        labelled = any(l.get("name") == APPROVED for l in issue.get("labels") or [])
        if who == OWNER or (labelled and approved_unedited(issue["number"])):
            approved.append((who, issue["body"] or ""))
        else:
            waiting.append((issue["number"], who, issue["body"] or ""))
    return approved, waiting


NICK_BAD = re.compile(r"[^\w .\-]")
CREDITS = pathlib.Path(__file__).resolve().parent.parent / "CONTRIBUTORS.md"


def clean_nick(text):
    """A nickname for the public thank-you list: letters, digits, space, _ . - only, at most 24 characters.
    Shared text is untrusted, and the list is published, so nothing else gets through."""
    nick = NICK_BAD.sub("", text or "").strip()[:24].strip()
    return "" if nick.lower().strip("_ ") in ("", "no response") else nick


def nick_from_issue(body):
    """The optional nickname field of the GitHub issue form ("### Nickname ..." heading), or ""."""
    m = re.search(r"###\s*Nickname[^\n]*\n+([^\n#]*)", body or "")
    return clean_nick(m[1]) if m else ""


def from_form_text(text):
    """(approved [(None, row text)], waiting [(row number, time, row text)], nicknames {share ID: nick})
    from the Google Form sheet.

    Export the sheet as CSV. A row counts only when its "OK" column is exactly x (you type it there
    after reviewing it). Approved shares are keyed by their share ID, since a form has no accounts.
    """
    rows = list(csv.reader(io.StringIO(text)))
    if not rows:
        return [], []
    ok = next((i for i, h in enumerate(rows[0]) if h.strip().lower() == "ok"), None)
    nick = next((i for i, h in enumerate(rows[0]) if "nickname" in h.lower()), None)
    approved, waiting, nicks = [], [], {}
    for number, row in enumerate(rows[1:], start=2):  # row 1 is the header, as in the sheet
        body = " ".join(c for i, c in enumerate(row) if i != nick)
        blocks = [m.group(0) for m in SHARE.finditer(body.replace("\n", ""))]
        if not blocks:
            continue
        if ok is not None and ok < len(row) and row[ok].strip().lower() == "x":  # "no", "?" etc. stay waiting
            approved.append((None, blocks[-1]))  # one row = one player: extra share blocks in a row never count
            if nick is not None and nick < len(row):
                for _, _, sid, _ in parse(blocks[-1]):
                    nicks[sid] = clean_nick(row[nick])  # the latest approved row decides, even an empty one
        else:
            waiting.append((number, row[0] if row else "", body))
    return approved, waiting, nicks


def from_form():
    return from_form_text(FORM.read_text(encoding="utf-8-sig")) if FORM.exists() else ([], [], {})


CLEAN_FROM = (0, 15, 2)  # first addon version that pauses loot counting in a group


def old_note(version):
    """Warning text when a share comes from an addon older than CLEAN_FROM. A share holds all of a
    player's counts, so even an updated player may still carry old group counts: you decide per share."""
    try:
        v = tuple(int(x) for x in version.split("."))
    except ValueError:
        v = (0,)
    return "" if v >= CLEAN_FROM else f" [addon {version}: older than 0.15.2, may include group loot]"


def show_form_waiting(waiting, approved):
    """Prints form rows waiting for review. 'known' = that share ID is already approved (an update)."""
    if not waiting:
        return
    known = {sid for _, text in approved for _, _, sid, _ in parse(text)}
    print(f"\n{len(waiting)} form rows wait for your review (they don't count until you type x in the OK column):")
    for number, when, body in waiting:
        if len(list(parse(body))) > 1:
            print(f"  row {number}: WARNING, {len(list(parse(body)))} share blocks in one row; only the last would count, look closely")
        for version, build, sid, mobs in parse(body):
            print(f"  row {number} ({when}): id {sid}{' (update of an approved share)' if sid in known else ''}, "
                  f"build {build}, {len(mobs)} mob kinds, {sum(m['n'] for m in mobs.values())} corpses, "
                  f"biggest {max((m['n'] for m in mobs.values()), default=0)} on one mob{old_note(version)}")


def show_waiting(waiting):
    """Prints shares waiting for review: poster, account age and size, so fakes stand out."""
    if not waiting:
        return
    print(f"\n{len(waiting)} shares wait for your review (they don't count until approved):")
    for number, who, body in waiting:
        try:
            created = gh("api", f"users/{who}", "--jq", ".created_at").strip()[:10]
        except (subprocess.CalledProcessError, OSError):
            created = "?"
        mobs = [m for share in parse(body) for m in share[3].values()]
        versions = "".join(old_note(share[0]) for share in parse(body))
        print(f"  #{number} by {who} (account since {created}): {len(mobs)} mob kinds, "
              f"{sum(m['n'] for m in mobs)} corpses{versions}  https://github.com/{REPO}/issues/{number}")
    print(f"Approve one: gh issue edit <number> --repo {REPO} --add-label {APPROVED}")


def self_check():
    s = "!LW:1!0.9.1;1.60.1;0a1b2c3d;3240:20:3:5128=9,5470=2;99:5:5:;7:1:0:1=9!End:LW!"
    (_, build, sid, mobs), = parse(s)
    assert build == "1.60.1" and sid == "0a1b2c3d", (build, sid)
    assert old_note("0.15.2") == "" and old_note("0.16.0") == "" and old_note("0.14.0") and old_note("x") and old_note("0.9.1")
    assert mobs == {3240: {"n": 20, "e": 3, "items": {5128: 9, 5470: 2}}, 99: {"n": 5, "e": 5, "items": {}}}, mobs
    sheet = f'Timestamp,Share,OK\n2026-11-25,"{s}",x\n2026-11-26,"{s}",\nnoise,hello,x\n'
    ok, wait, _ = from_form_text(sheet)
    assert len(ok) == 1 and [w[0] for w in wait] == [3], (ok, wait)
    nicked = f'Timestamp,Share,Nickname (optional),OK\n1,"{s}",  Ra<b>vi!n_7 ,x\n2,"{s}",,\n'
    assert from_form_text(nicked)[2] == {"0a1b2c3d": "Rabvin_7"}, from_form_text(nicked)[2]
    assert clean_nick("_No response_") == "" and clean_nick("x" * 40) == "x" * 24
    assert nick_from_issue("### Loot data\n\n...\n\n### Nickname for the thank-you list (optional)\n\nBob\n") == "Bob"
    assert nick_from_issue("### Nickname for the thank-you list (optional)\n\n_No response_\n") == ""
    assert not from_form_text(f'Timestamp,Share,OK\n1,"{s}",no\n')[0]  # only x approves
    two = f'Timestamp,Share,OK\n1,"{s} {s.replace("0a1b2c3d", "ffffffff")}",x\n'
    assert len(list(parse(from_form_text(two)[0][0][1]))) == 1  # a row with two blocks counts once
    old = {3240: {"n": 5, "e": 0, "items": {5128: 1}}}
    merged, players = merge([("1.60.1", "a", old), ("1.60.1", "a", mobs), ("1.60.1", "b", old)])
    assert players == 2 and merged["1.60.1"][3240] == {"n": 25, "e": 3, "items": {5128: 10, 5470: 2},
        "by": {"a": {"n": 20, "items": {5128: 9, 5470: 2}}, "b": {"n": 5, "items": {5128: 1}}}}, merged


def main():
    self_check()
    waiting, nicks = [], {}
    if len(sys.argv) > 1:  # a file you saved yourself (emailed shares): trusted, keyed by share ID
        texts = [(None, pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))]
    else:
        texts, waiting = from_issues()
        nicks = {who: nick_from_issue(text) for who, text in texts}  # oldest first, so the latest wins
        form_ok, form_waiting, form_nicks = from_form()
        texts += form_ok
        nicks.update(form_nicks)
    # The repo owner may share through GitHub and the form: a share ID on the owner's own issue belongs
    # to the owner, so the later form share replaces it instead of adding up. Other accounts' share IDs
    # are never linked to a form row (the ID is chosen by the poster and public in the issue).
    owner = {sid: who for who, text in texts if who == OWNER for _, _, sid, _ in parse(text)}
    shares = [(build, who or owner.get(sid, sid), mobs) for who, text in texts for _, build, sid, mobs in parse(text)]
    merged, players = merge(shares)
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(merged, indent=1, sort_keys=True), encoding="utf-8")
    for build, mobs in sorted(merged.items()):
        corpses = sum(m["n"] for m in mobs.values())
        enough = sum(1 for m in mobs.values() if m["n"] >= 20)
        print(f"build {build}: {corpses} corpses, {len(mobs)} mob kinds ({enough} with 20+ corpses)")
    print(f"{len(shares)} shares from {players} players -> {OUT.relative_to(OUT.parent.parent.parent)}")
    print("Contributors: " + ", ".join(sorted({w for w, _ in texts if w})))
    olds = sorted({f"{who or sid} ({version})" for who, text in texts for version, _, sid, _ in parse(text) if old_note(version)})
    if olds:  # already approved: your call, e.g. trusted solo players are fine
        print("Approved shares from addons older than 0.15.2 (may include group loot): " + ", ".join(olds))
    names = sorted({n for n in nicks.values() if n}, key=str.lower)
    if len(sys.argv) == 1:  # only a full merge knows every approved player
        CREDITS.write_text("# Thank you\n\nPlayers who shared their loot to build Lootwright's drop rates "
                           "(nicknames they chose; approved shares only):\n\n"
                           + ("".join(f"- {n}\n" for n in names) or "No nicknames yet.\n"), encoding="utf-8")
        print(f"Thank-you list: {len(names)} nicknames -> CONTRIBUTORS.md")
    show_waiting(waiting)
    if len(sys.argv) == 1:
        show_form_waiting(form_waiting, form_ok)


if __name__ == "__main__":
    main()
