#!/usr/bin/env python3
"""Check that skills/simplify/SKILL.md mirrors Claude Code's built-in /simplify.

Exit 0 = mirror matches, 1 = drift (unified diff on stderr), 2 = native template
not found in the binary (layout changed; update the anchors below).
Usage: check_native_mirror.py [--binary PATH] [--skill PATH] [--print-body]
"""
import argparse, difflib, glob, os, re, shutil, sys

TOOL = "invoke_subagent"  # agy name for the native ${mt} (Agent tool)
A_ANCHOR = b"4 cleanup agents in parallel"
B_ANCHOR = b"tool unavailable \\u2192 single-pass inline cleanup"
PIECES = [  # placeholder order inside both templates, with the text each starts with
    (b'"## Phase 0 ', '"'),
    (b"Flag new code that re-implements", "`"),
    (b"### Simplification", "`"),
    (b"### Efficiency", "`"),
    (b"### Altitude", "`"),
]


def unescaped(d, ch, pos, step):
    """Index of the nearest unescaped `ch` from pos going in `step` direction."""
    i = pos
    while 0 <= i < len(d):
        if d[i:i + 1] == ch:
            n, j = 0, i - 1
            while j >= 0 and d[j:j + 1] == b"\\":
                n, j = n + 1, j - 1
            if n % 2 == 0:
                return i
        i += step
    return -1


def js_decode(b):
    s = b.decode("utf8")
    return re.sub(r"\\(u[0-9a-fA-F]{4}|.)", lambda m: chr(int(m[1][1:], 16)) if len(m[1]) == 5 else
                  {"n": "\n", "t": "\t"}.get(m[1], m[1]), s)


def extract(binary):
    d = open(binary, "rb").read()
    out = {}
    for key, anchor in (("A", A_ANCHOR), ("B", B_ANCHOR)):
        i = d.find(anchor)
        if i < 0:
            return None
        s, e = unescaped(d, b"`", i, -1), unescaped(d, b"`", i, 1)
        if s < 0 or e < 0:
            return None
        out[key] = d[s + 1:e]
    pieces = []
    cur = 0  # pieces are consecutive in the binary; later ones skip look-alikes elsewhere
    for start, quote in PIECES:
        i = d.find(start, cur)
        if i < 0:
            return None
        if quote == '"':
            i += 1
        e = unescaped(d, quote.encode(), i + 1, 1)
        cur = e
        pieces.append(js_decode(d[i:e]))
    texts = {}
    for key, raw in out.items():
        t = raw.decode("utf8")
        m = re.search(r"via the \$\{(\w+)\} tool", t) or re.search(r"\$\{(\w+)\} tool", t)
        if not m:
            return None
        tool = m[1]
        names = [n for n in re.findall(r"\$\{(\w+)\}", t) if n != tool]
        if len(names) != len(pieces):
            return None
        t = t.replace("${%s}" % tool, TOOL)
        for n, p in zip(names, pieces):
            t = t.replace("${%s}" % n, p, 1)
        texts[key] = js_decode(t.encode("utf8"))
    return texts


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


def find_binary():
    exe = shutil.which("claude")
    if exe:
        return os.path.realpath(exe)
    c = sorted(glob.glob(os.path.expanduser("~/.local/share/claude/versions/*")))
    return c[-1] if c else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--binary")
    ap.add_argument("--skill", default=os.path.join(os.path.dirname(__file__), "..", "SKILL.md"))
    ap.add_argument("--print-body", action="store_true")
    a = ap.parse_args()
    binary = a.binary or find_binary()
    t = extract(binary) if binary and os.path.exists(binary) else None
    if not t:
        print(f"anchors not found in {binary}: native /simplify template moved", file=sys.stderr)
        return 2
    if a.print_body:
        print(t["A"], t["B"], sep="\n=====\n")
        return 0
    skill = norm(open(a.skill).read())
    bad = 0
    for key in "AB":
        want = norm(t[key])
        if want in skill:
            continue
        bad = 1
        # report first diverging region against the best-matching skill window
        head = want[:60]
        pos = skill.find(head)
        got = skill[pos:pos + len(want)] if pos >= 0 else skill[:len(want)]
        sys.stderr.writelines(difflib.unified_diff(
            re.split(r"(?<=[.:;]) ", got), re.split(r"(?<=[.:;]) ", want),
            f"SKILL.md (branch {key})", f"native (branch {key})", lineterm="\n"))
        sys.stderr.write("\n")
    print("DRIFT" if bad else f"OK: mirrors {binary}")
    return bad


if __name__ == "__main__":
    sys.exit(main())
