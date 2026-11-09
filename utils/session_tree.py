#!/usr/bin/env python3
"""Session tree shared by `cs` and the ar/cr/agr pickers.

As a filter (stdin -> stdout) it takes the pickers' TSV rows (age, short id, branch, label, id, file, cwd[, agent]),
newest first, and returns them in tree order: children under their parent, oldest first, trees ordered by their
newest session, with "<tree lines><glyph> " put in front of the label. A parent that is not in the list makes the
child a plain root. SESSION_TREE=0 passes the rows through unchanged (unified-sessions.sh applies the tree once
over both agents' rows).

Parents: Claude's lineage records (~/.claude/session-lineage, SESSION_LINEAGE_DIR overrides), Antigravity's
parent_conversation_id (subagents) and the fork prompt's agy-forks/<agent>-<source id first 8>-... path.
"""
import json
import os
import re
import sqlite3
import sys
from pathlib import Path

STATE = Path(os.environ.get("SESSION_LINEAGE_DIR") or Path.home() / ".claude" / "session-lineage")
AGY_DB = Path.home() / ".gemini" / "antigravity-cli" / "conversation_summaries.db"
GLYPHS = {"startup": "·", "clear": "⟲", "fork": "⑂", "subagent": "↳"}
ANSI = re.compile(r"\x1b\[[0-9;]*m")
AGENT_TAG = re.compile(r"\x1b\[\d+m\[(?:claude|agy)\]\x1b\[0m\s*")
FORK_PROMPT = re.compile(r"agy-forks/(?:claude|agy)-([0-9a-f]{8})-")


def walk(node, children):
    """The node and all its descendants, depth first."""
    nodes = [node]
    for child in children.get(node["id"], []):
        nodes += walk(child, children)
    return nodes


def emit(node, children, prefix, out, render):
    """Append (id, text) for the node's descendants with ├ └ │ lines; render(node) is the row text."""
    kids = children.get(node["id"], [])
    for i, kid in enumerate(kids):
        last = i == len(kids) - 1
        out.append((kid["id"], f"{prefix}{'└' if last else '├'} {render(kid)}"))
        emit(kid, children, prefix + ("  " if last else "│ "), out, render)


def parents(ids):
    """{session id: (parent id, source)} for the ids that have a known parent."""
    ids = set(ids)
    links = {}
    for sid in ids:
        try:
            record = json.loads((STATE / f"{sid}.json").read_text())
        except (OSError, ValueError):
            continue
        if record.get("parent"):
            links[sid] = (record["parent"], record.get("source") or "fork")
    if AGY_DB.is_file():
        try:
            db = sqlite3.connect(f"file:{AGY_DB}?mode=ro", uri=True, timeout=2)
            found = db.execute("SELECT conversation_id, parent_conversation_id, preview FROM conversation_summaries").fetchall()
        except sqlite3.Error:
            found = []
        for sid, parent, preview in found:
            if sid not in ids:
                continue
            if parent:
                links[sid] = (parent, "subagent")
            elif m := FORK_PROMPT.search(preview or ""):
                # Never guess: a prefix that matches no listed session, or several, leaves a plain root
                matches = [i for i in ids if i.startswith(m.group(1)) and i != sid]
                if len(matches) == 1:
                    links[sid] = (matches[0], "fork")
    return links


def order(rows, links):
    """Rows (column lists, newest first; id in column 5) in tree order with the tree put in front of column 4."""
    nodes = {r[4]: {"id": r[4], "row": r, "i": i} for i, r in enumerate(rows)}
    children = {}
    for sid, node in nodes.items():
        parent = links.get(sid, (None,))[0]
        if parent in nodes and parent != sid:
            children.setdefault(parent, []).append(node)
    for kids in children.values():
        kids.sort(key=lambda n: -n["i"])  # oldest first
    seen = set()
    roots = []
    for node in sorted(nodes.values(), key=lambda n: n["i"]):
        if links.get(node["id"], (None,))[0] not in nodes:
            roots.append(node)
    # A parent cycle leaves nodes no root reaches; make them roots so no row is dropped
    for root in roots:
        seen.update(n["id"] for n in walk(root, children))
    roots += [n for n in nodes.values() if n["id"] not in seen]
    roots.sort(key=lambda n: min(m["i"] for m in walk(n, children)))

    def render(node):
        source = links.get(node["id"], (None, "startup"))[1]
        return glyph_label(node["row"][3], GLYPHS.get(source, "·"))

    out = []
    for root in roots:
        out.append((root["id"], render(root)))
        emit(root, children, "", out, render)
    return [with_label(nodes[sid]["row"], text) for sid, text in out]


def glyph_label(label, glyph):
    plain = ANSI.sub("", AGENT_TAG.sub("", label, 1))
    # Titles the lineage hook wrote already carry the glyph ("3715 ⟲ task")
    return "" if re.search(r"(^|\s)[·⟲⑂↳] ", plain[:80]) else f"{glyph} "


def with_label(row, text):
    """Put the tree text after the agent tag (ar) or at the start of the label."""
    label = row[3]
    m = AGENT_TAG.match(label)
    head = m.group(0) if m else ""
    return row[:3] + [head + text + label[len(head):]] + row[4:]


def main():
    data = sys.stdin.read()
    if os.environ.get("SESSION_TREE") == "0":
        return sys.stdout.write(data)
    try:
        rows = [line.split("\t") for line in data.splitlines() if line]
        rows = [r for r in rows if len(r) >= 7]
        out = order(rows, parents(r[4] for r in rows))
        sys.stdout.write("".join("\t".join(r) + "\n" for r in out))
    except Exception as e:  # the picker still works without the tree
        print(f"session_tree: {e}", file=sys.stderr)
        sys.stdout.write(data)


if __name__ == "__main__":
    main()
