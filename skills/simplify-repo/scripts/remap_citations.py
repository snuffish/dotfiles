#!/usr/bin/env python3
"""Remap `file:line` references in the docs after an edit moved lines.

For every `path.ext:12` or `path.ext:12-20` in the tracked doc files, the old line numbers (the file
at --base, default HEAD) are mapped onto the working tree with difflib. Prints one row per reference
that changes. A range end that sat on a changed or removed line is marked CHECK, with the old and the
new line text: --apply writes the nearest line, and the reference has to be read by hand. Run it
before committing the code that moved the lines, or pass the commit before that code as --base.
Without --apply nothing is written.

A doc that already differs from --base is never rewritten: its numbers are no longer the ones --base
had. When it equals what the remap of its --base text gives, it counts as already remapped; otherwise
it is listed as EDITED. A second run before the commit is therefore safe.

Usage: python3 -I remap_citations.py [--base <ref>] [--docs <glob> ...] [--apply] [--repo <dir>]
Exit codes: 0 nothing left to check, 1 CHECK, AMBIGUOUS or UNRESOLVED rows, 2 git error.
"""
import argparse, difflib, re, subprocess, sys
from pathlib import Path

CITE = re.compile(r"(?<![\w/.-])((?:[\w.-]+/)*[\w.-]+\.[A-Za-z][A-Za-z0-9]*):(\d+)(?:-(\d+))?(?!\w)")


def git(root, *args):
    r = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout


def shared_folders(a, b):
    n = 0
    for x, y in zip(a.split("/")[:-1], b.split("/")[:-1]):
        if x != y:
            break
        n += 1
    return n


def resolve(cited, doc, known):
    """Repo path of a cited file: the path itself, else the one tracked file it is the tail of.
    Several tails: the one sharing most folders with the doc. Returns a path, "" (several) or None."""
    if cited in known:
        return cited
    hits = [p for p in known if p.endswith("/" + cited)]
    if len(hits) > 1:
        best = max(shared_folders(p, doc) for p in hits)
        hits = [p for p in hits if shared_folders(p, doc) == best]
    return hits[0] if len(hits) == 1 else ("" if hits else None)


def line_map(old, new):
    """old line number -> (new line number, exact)."""
    m = {}
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes():
        for k, i in enumerate(range(i1, i2)):
            if tag == "equal":
                m[i + 1] = (j1 + k + 1, True)
            else:  # replaced or deleted: the nearest line of the new block
                m[i + 1] = (min(j1 + k, max(j2 - 1, j1)) + 1, False)
    return m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="HEAD", help="commit the docs' line numbers are true for")
    ap.add_argument("--docs", nargs="+", default=["*.md"], help="globs of the doc files to rewrite")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--repo", default=".", help="a folder inside the repo")
    a = ap.parse_args()

    try:
        root = git(a.repo, "rev-parse", "--show-toplevel").strip()
        changed = set(git(root, "diff", "--name-only", a.base).splitlines())
        known = set(git(root, "ls-files", "--full-name", "--", ":/").splitlines()) | changed
        docs = git(root, "ls-files", "--full-name", "--", *(f":/{g}" for g in a.docs)).splitlines()
    except RuntimeError as e:
        print(e, file=sys.stderr)
        return 2
    moved = {Path(p).suffix for p in changed}
    maps = {}

    def mapped(path):
        if path not in maps:
            old = git(root, "show", f"{a.base}:{path}").splitlines()
            new = (Path(root) / path).read_text().splitlines()
            maps[path] = (line_map(old, new), old, new)
        return maps[path]

    def text_at(lines, n):
        return lines[n - 1].strip()[:110] if 0 < n <= len(lines) else "<no such line>"

    def remap(doc, text):
        """The text with every reference to a changed file remapped, the rows to print, and the counts."""
        rows, n = [], {"found": 0, "change": 0, "check": 0}

        def swap(match):
            cited, first, last = match.group(1), int(match.group(2)), match.group(3)
            path = resolve(cited, doc, known)
            if not path:
                if Path(cited).suffix in moved:  # only suffixes the edit touched: `host.com:443` is no reference
                    n["check"] += 1
                    rows.append(f"{'UNRESOLVED' if path is None else 'AMBIGUOUS'} {doc}: {match.group(0)}")
                return match.group(0)
            n["found"] += 1
            if path not in changed:
                return match.group(0)
            if not (Path(root) / path).is_file():
                n["check"] += 1
                rows.append(f"CHECK(file removed) {doc}: {match.group(0)}")
                return match.group(0)
            m, old, new = mapped(path)
            last = int(last) if last else None
            if first not in m or (last and last not in m):
                n["check"] += 1
                rows.append(f"CHECK(out of range) {doc}: {match.group(0)}")
                return match.group(0)
            (nfirst, exact_first), (nlast, exact_last) = m[first], (m[last] if last else (None, True))
            out = f"{cited}:{nfirst}" + (f"-{nlast}" if last else "")
            exact = exact_first and exact_last
            if out == match.group(0) and exact:
                return out
            n["change"] += out != match.group(0)
            n["check"] += not exact
            rows.append(f"{'ok   ' if exact else 'CHECK'} {doc}: {match.group(0)} -> {out}")
            if not exact:
                for o, w in ((first, nfirst), (last, nlast)) if last else ((first, nfirst),):
                    rows.append(f"        old {o}: {text_at(old, o)}")
                    rows.append(f"        new {w}: {text_at(new, w)}")
            return out

        return CITE.sub(swap, text), rows, n

    total = {"found": 0, "change": 0, "check": 0}
    already = 0
    for doc in docs:
        text = (Path(root) / doc).read_text()
        if doc in changed:  # its numbers are no longer --base's: never rewrite it
            try:
                at_base = git(root, "show", f"{a.base}:{doc}")
            except RuntimeError:
                continue  # a doc written after --base cites today's lines
            updated, _, n = remap(doc, at_base)
            total["found"] += n["found"]
            if updated == text:
                already += 1
            elif updated != at_base:
                print(f"EDITED {doc}: differs from {a.base} and from the remapped text; left alone")
            continue
        updated, rows, n = remap(doc, text)
        print("\n".join(rows), end="\n" if rows else "")
        for key in total:
            total[key] += n[key]
        if a.apply and updated != text:
            (Path(root) / doc).write_text(updated)

    print(f"{total['found']} reference(s) to tracked files; {total['change']} citation(s) change, "
          f"{total['check']} to check; changed code files: {len(changed - set(docs))}; "
          f"docs already remapped: {already}; " + ("applied" if a.apply else "dry run"))
    return 1 if total["check"] else 0


if __name__ == "__main__":
    sys.exit(main())
