"""Build Lootwright_Data/GeneratedData.lua (the Lootwright_Data sub-addon) from the ForeverDB addon's data files.

Offline only: Lootwright never reads ForeverDB while the game runs.

Reads (from ForeverDB/Data):
  Recipes.lua  every recipe per profession, with reagents
  Loot.lua     dungeon/raid boss loot with measured drop rates and kill counts
  Meta.lua     data version
and from tools/data/ClassicDB_*.sql.gz (CMaNGOS classic-db dump, GPL-3.0, git-ignored):
  creature_loot_template / reference_loot_template -> per-mob drop rates of 1% and up

Licence: ForeverDB's data is GPL-3.0 with an attribution term (section 7(b)). The generated file
keeps ForeverDB's "-- Data: ForeverDB.net" line, and Lootwright credits
"Data from ForeverDB.net (https://foreverdb.net)".

Usage:
  python tools/build_data.py [path to ForeverDB/Data]
"""

import gzip
import pathlib
import re
import sys

DEFAULT_SRC = r"Z:\Blizzard\World of Warcraft\_forever_\Interface\AddOns\ForeverDB\Data"
OUT = pathlib.Path(__file__).resolve().parent.parent / "Lootwright_Data" / "GeneratedData.lua"

NUM = re.compile(r"-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?")
IDENT_EQ = re.compile(r"[A-Za-z_]\w*\s*=(?!=)")


class LuaParser:
    """Parses a Lua table literal (enough for generated data files, not general Lua)."""

    def __init__(self, text, pos=0):
        self.t, self.i = text, pos

    def skip(self):
        t = self.t
        while self.i < len(t):
            c = t[self.i]
            if c in " \t\r\n,;":  # separators are treated like whitespace
                self.i += 1
            elif t.startswith("--[[", self.i):
                self.i = t.index("]]", self.i) + 2
            elif t.startswith("--", self.i):
                j = t.find("\n", self.i)
                self.i = len(t) if j < 0 else j
            else:
                break

    def value(self):
        self.skip()
        t, c = self.t, self.t[self.i]
        if c == "{":
            return self.table()
        if c in "\"'":
            return self.string()
        if t.startswith("[[", self.i):
            j = t.index("]]", self.i)
            s = t[self.i + 2:j]
            self.i = j + 2
            return s
        m = NUM.match(t, self.i)
        if m:
            self.i = m.end()
            s = m.group()
            return float(s) if any(ch in s for ch in ".eE") else int(s)
        for word, v in (("true", True), ("false", False), ("nil", None)):
            if t.startswith(word, self.i):
                self.i += len(word)
                return v
        raise ValueError(f"unexpected {t[self.i:self.i + 30]!r} at {self.i}")

    def string(self):
        t, q = self.t, self.t[self.i]
        self.i += 1
        out = []
        while t[self.i] != q:
            c = t[self.i]
            if c == "\\":
                n = t[self.i + 1]
                if n.isdigit():
                    m = re.match(r"\d{1,3}", t[self.i + 1:])
                    out.append(chr(int(m.group())))
                    self.i += 1 + len(m.group())
                    continue
                out.append({"n": "\n", "t": "\t", "r": "\r"}.get(n, n))
                self.i += 2
            else:
                out.append(c)
                self.i += 1
        self.i += 1
        return "".join(out)

    def table(self):
        self.i += 1
        arr, d = [], {}
        while True:
            self.skip()
            t = self.t
            if t[self.i] == "}":
                self.i += 1
                break
            if t[self.i] == "[" and not t.startswith("[[", self.i):
                self.i += 1
                k = self.value()
                self.skip()
                assert t[self.i] == "]", t[self.i:self.i + 20]
                self.i += 1
                self.skip()
                assert t[self.i] == "=", t[self.i:self.i + 20]
                self.i += 1
                d[k] = self.value()
                continue
            m = IDENT_EQ.match(t, self.i)
            if m:
                key = m.group().rstrip("= \t")
                self.i = m.end()
                d[key] = self.value()
            else:
                arr.append(self.value())
        if d and arr:
            for n, v in enumerate(arr, 1):
                d[n] = v
            return d
        return d if d else arr


def read_assignment(path, name):
    """Returns (first line, parsed value of `ns.<name> = {...}`)."""
    text = path.read_text(encoding="utf-8")
    m = re.search(r"ns\." + re.escape(name) + r"\s*=\s*", text)
    if not m:
        raise SystemExit(f"{path.name}: ns.{name} not found")
    return text.splitlines()[0], LuaParser(text, m.end()).value()


# ---------------------------------------------------------------- Lua output
def lua(v):
    if v is None:
        return "nil"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return ("%.4f" % v).rstrip("0").rstrip(".")
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(v, list):
        return "{" + ",".join(lua(x) for x in v) + "}"
    if isinstance(v, dict):
        parts = []
        for k, x in v.items():
            key = "[" + lua(k) + "]" if not (isinstance(k, str) and re.fullmatch(r"[A-Za-z_]\w*", k)) else k
            parts.append(key + "=" + lua(x))
        return "{" + ",".join(parts) + "}"
    raise TypeError(type(v))


# ---------------------------------------------------------------- builders
def build_recipes(recipes):
    """[profession] = { {spell, name, skill, item, count, "reagents", learn, newInForever}, ... }
    learn: "t" trainer, "a" automatic, "i<itemId>" from a recipe item."""
    out = {}
    for prof, rows in recipes.items():
        out[prof] = [
            [r[0], r[1], r[2], r[6], r[7], r[8], r[9], 1 if len(r) > 11 and r[11] == 1 else 0]
            for r in rows
        ]
    return out


def build_boss_loot(loot):
    """bossLoot[item] = "npc:pct:kills:src;..." (pct 0 = unknown, kills 0 = unknown, src f Forever / c Classic)
    bosses[npc] = {name, instance name, instance level range}"""
    per_item, bosses = {}, {}
    for inst in loot.get("inst", []):
        for boss in inst.get("bosses", []) or []:
            npc, text = boss.get("npc"), boss.get("loot") or ""
            if not npc:
                continue
            bosses[npc] = [boss.get("name", ""), inst.get("name", ""), inst.get("lv", "")]
            for entry in text.split(";"):
                f = entry.split(":")
                if len(f) < 3 or not f[0]:
                    continue
                item = int(f[0])
                pct = float(f[1] or 0)
                src = f[2]
                kills = int(f[4]) if len(f) > 4 and f[4] else 0
                pct_s = ("%.2f" % pct).rstrip("0").rstrip(".")
                per_item.setdefault(item, []).append(f"{npc}:{pct_s}:{kills}:{src}")
    return {k: ";".join(v) for k, v in sorted(per_item.items())}, bosses


# ---------------------------------------------------------------- CMaNGOS mob drop rates
CMANGOS_MIN_PCT = 1.0  # drops below this are mostly world drops on every mob; they'd make the file ~19 MB


def sql_columns(sql, table):
    m = re.search(r"CREATE TABLE `%s` \((.*?)\n\) ENGINE" % table, sql, re.S)
    if not m:
        raise SystemExit(f"CMaNGOS dump: table {table} not found")
    return re.findall(r"^\s+`(\w+)`", m.group(1), re.M)


def sql_rows(sql, table):
    """Yields each row of `INSERT INTO table VALUES (...),(...);` as a list of strings."""
    for m in re.finditer(r"INSERT INTO `%s` VALUES (.*?);\n" % table, sql, re.S):
        s, i, n = m.group(1), 0, len(m.group(1))
        while i < n:
            if s[i] != "(":
                i += 1
                continue
            i += 1
            row, cur, q = [], [], False
            while True:
                c = s[i]
                if q:
                    if c == "\\":
                        cur.append(s[i + 1])
                        i += 2
                        continue
                    if c == "'":
                        q = False
                    else:
                        cur.append(c)
                elif c == "'":
                    q = True
                elif c == ",":
                    row.append("".join(cur))
                    cur = []
                elif c == ")":
                    row.append("".join(cur))
                    i += 1
                    break
                else:
                    cur.append(c)
                i += 1
            yield row


def sql_table(sql, table):
    cols = sql_columns(sql, table)
    return cols, (dict(zip(cols, r)) for r in sql_rows(sql, table))


def loot_tables(sql, table):
    """[entry] = [(item, chance, group, mincountOrRef), ...]"""
    out = {}
    for d in sql_table(sql, table)[1]:
        out.setdefault(int(d["entry"]), []).append(
            (int(d["item"]), float(d["ChanceOrQuestChance"]), int(d["groupid"]), int(d["mincountOrRef"])))
    return out


def resolve_loot(entries, refs, mult=1.0, acc=None, depth=0):
    """acc[item] = chance (0-1) to drop from one kill.
    CMaNGOS rules: ungrouped entries roll on their own; in a group one entry drops, and entries
    with chance 0 split what the explicit chances leave. A negative chance is a quest-only drop.
    mincountOrRef < 0 points to reference_loot_template entry -n, rolled with the row's chance."""
    acc = {} if acc is None else acc
    groups = {}
    for e in entries:
        groups.setdefault(e[2], []).append(e)
    for gid, es in groups.items():
        share = 0.0
        if gid:
            zeros = [e for e in es if not e[1]]
            if zeros:
                share = max(0.0, 100 - sum(abs(e[1]) for e in es)) / len(zeros)
        for item, chance, _, ref in es:
            p = mult * (abs(chance) if chance else (share if gid else 100)) / 100
            if ref < 0:
                if depth < 5:
                    resolve_loot(refs.get(-ref, []), refs, p, acc, depth + 1)
            else:
                acc[item] = acc.get(item, 0.0) + p
    return acc


def build_mob_rates(sql):
    """mobRates[item] = "npc:pct;..." for drops of at least CMANGOS_MIN_PCT percent."""
    creature, refs = loot_tables(sql, "creature_loot_template"), loot_tables(sql, "reference_loot_template")
    cols, npcs = sql_table(sql, "creature_template")
    loot_col = next(c for c in cols if c.lower() == "lootid")
    per_item = {}
    for d in npcs:
        npc, loot = int(d["Entry"]), int(d[loot_col])
        if not loot or loot not in creature:
            continue
        for item, p in resolve_loot(creature[loot], refs).items():
            pct = min(p, 1.0) * 100
            if pct >= CMANGOS_MIN_PCT:
                per_item.setdefault(item, []).append((npc, pct))
    return {item: ";".join("%d:%s" % (n, ("%.2f" % p).rstrip("0").rstrip(".")) for n, p in sorted(rows))
            for item, rows in sorted(per_item.items())}


def find_cmangos_dump():
    found = sorted((pathlib.Path(__file__).resolve().parent / "data").glob("ClassicDB_*.sql.gz"))
    if not found:
        raise SystemExit("CMaNGOS dump missing: download Full_DB/ClassicDB_*.sql.gz from "
                         "https://github.com/cmangos/classic-db into tools/data/")
    return found[-1]


def self_check():
    refs = {5: [(10, 0, 1, 1), (11, 0, 1, 1)]}
    got = resolve_loot([(1, 50, 0, 1), (2, 0, 1, 1), (3, 60, 1, 1), (0, 20, 0, -5)], refs)
    assert {k: round(v, 3) for k, v in got.items()} == {1: 0.5, 2: 0.4, 3: 0.6, 10: 0.1, 11: 0.1}, got
    sql = "CREATE TABLE `t` (\n  `a` int,\n  `b` text\n) ENGINE=x;\nINSERT INTO `t` VALUES (1,'x\\'y,)'),(2,'');\n"
    assert list(sql_rows(sql, "t")) == [["1", "x'y,)"], ["2", ""]] and sql_columns(sql, "t") == ["a", "b"]
    p = LuaParser('{[10]={"a\\"b",2.5,true},x={3,4},-- c\n[ "k" ]="v",5}').value()
    assert p[10] == ["a\"b", 2.5, True] and p["x"] == [3, 4] and p["k"] == "v" and p[1] == 5, p
    assert lua({"a": [1, "x"], 7: 1.25}) == '{a={1,"x"},[7]=1.25}'


def main():
    self_check()
    src = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC)
    credit, recipes = read_assignment(src / "Recipes.lua", "recipes")
    _, loot = read_assignment(src / "Loot.lua", "lootDB")
    _, meta = read_assignment(src / "Meta.lua", "meta")
    assert credit.startswith("-- Data: ForeverDB.net"), credit

    rec = build_recipes(recipes)
    boss_loot, bosses = build_boss_loot(loot)
    assert rec and boss_loot and bosses, "nothing parsed"

    dump = find_cmangos_dump()
    with gzip.open(dump, "rt", encoding="utf-8", errors="replace") as f:
        mob_rates = build_mob_rates(f.read())
    assert mob_rates, "no CMaNGOS loot parsed"

    body = lua({
        "version": meta.get("version", "?"),
        "build": meta.get("build", "?"),
        "recipes": rec,
        "bossLoot": boss_loot,
        "bosses": bosses,
        "mobRates": mob_rates,
        "mobRatesFrom": dump.name,
    })
    OUT.write_text(
        credit + "\n"
        + "-- Generated by tools/build_data.py from ForeverDB data " + str(meta.get("version")) + ". Don't edit.\n"
        + "-- Data from ForeverDB.net (https://foreverdb.net), GPL-3.0 with an attribution term (section 7(b)).\n"
        + "-- mobRates: from CMaNGOS classic-db (https://github.com/cmangos/classic-db), GPL-3.0, " + dump.name + ".\n"
        # Part of the Lootwright_Data sub-addon: joins Lootwright's namespace.
        + "local ns = LootwrightNS\n"
        + "if not ns then return end\n"
        + "ns.Gen = " + body + "\n",
        encoding="utf-8", newline="\n",
    )
    n_rec = sum(len(v) for v in rec.values())
    print(f"{OUT.name}: {n_rec} recipes in {len(rec)} professions, "
          f"{len(boss_loot)} boss-loot items from {len(bosses)} bosses, "
          f"{len(mob_rates)} items with CMaNGOS mob rates, "
          f"{OUT.stat().st_size // 1024} KB (ForeverDB {meta.get('version')})")


if __name__ == "__main__":
    main()
