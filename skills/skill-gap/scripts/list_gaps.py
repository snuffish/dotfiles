#!/usr/bin/env python3
"""Lists the skill gaps in ~/.terminal/skill-gaps/ and classifies each one against the registry.

The gap file format and its Status values are defined in skills/_modules/core.md › Skill gaps. This script only reads:
it never writes a gap file, commits or changes a ref.

Usage:
    python3 -I <registry>/skill-gap/scripts/list_gaps.py                 table
    python3 -I <registry>/skill-gap/scripts/list_gaps.py --json          machine-readable results
    python3 -I <registry>/skill-gap/scripts/list_gaps.py --dir <folder>  another gap folder (a fixture)

The registry is the folder two levels above this script (`<registry>`, e.g. ~/.terminal/skills); the gap folder is
skill-gaps/ next to it. The registry is trunk-only and fixes are often still uncommitted, so gaps are compared against
the working tree and its git history, not a remote ref. Both Status formats are read: `- **Status:** <value>` in the
template and the older `Status: <value> · Command: …` line under the heading.

- closed: Status is `fixed` or `not a gap: <reason>`.
- stale: no skill of that name in the registry, or the text the Proposed edit says to replace (`replace `<old>``) is
  no longer in the file it names.
- likely-fixed: a file the gap names (the Proposed edit's paths, else the skill's folder) has a commit since the gap's
  Found time, or an uncommitted change saved after it (file mtime).
- open: none of the above.

Exit code 0 = listed (even when there are no gaps), 2 = the folder can't be read.
"""

import argparse
import json
import re
import subprocess
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path

for stream in (sys.stdout, sys.stderr):
    stream.reconfigure(encoding="utf-8", errors="replace")

REGISTRY = Path(__file__).resolve().parents[2]
CLASSES = ("open", "likely-fixed", "stale", "closed")

NAME = re.compile(r"^.+?-skill_gap-(?P<rest>.+)\.md$")
FIELD = re.compile(r"^\s*-\s*\*\*(?P<key>[A-Za-z ]+):\*\*\s*(?P<value>.*)$")
OLD_STATUS = re.compile(r"^Status:\s*(?P<value>[^·]+)")
HEADER = re.compile(r"^#\s*Skill gap:\s*(?P<skill>\S+)")
OWNER = re.compile(r"artifact-owner:.*created\s+(?P<date>\d{4}-\d{2}-\d{2})T(?P<time>\d{2}:\d{2})")
FOUND_AT = re.compile(r"(?P<date>\d{4}-\d{2}-\d{2})(?:\s+(?P<time>\d{1,2}:\d{2}))?")
REPLACE = re.compile(r"replace\s+(?P<tick>`+)(?P<old>.+?)(?P=tick)\s+with", re.IGNORECASE)
TICKED = re.compile(r"(?P<tick>`+)(?P<text>.+?)(?P=tick)")


def git(*args):
    """stdout of a git command run in the registry, or None when it fails."""
    proc = subprocess.run(["git", *args], cwd=REGISTRY, capture_output=True, encoding="utf-8", errors="replace")
    return proc.stdout if proc.returncode == 0 else None


def skill_folders():
    """{name: folder} for every skill in the registry: the top level and Projects/<Project>/."""
    found = {}
    for md in [*REGISTRY.glob("*/SKILL.md"), *REGISTRY.glob("Projects/*/*/SKILL.md")]:
        found.setdefault(md.parent.name, md.parent)
    return found


def parse(path):
    """The fields of one gap file, whichever Status format it uses."""
    text = path.read_text(encoding="utf-8", errors="replace")
    gap = {"file": path.name, "path": str(path), "skill": None, "status": None, "found": None, "where": None,
           "proposed_edit": None, "format": "template", "since": None}
    for line in text.splitlines():
        if m := FIELD.match(line):
            key = m["key"].strip().lower().replace(" ", "_")
            if key in ("status", "found", "where", "proposed_edit") and gap[key] is None:
                gap[key] = m["value"].strip()
        elif gap["status"] is None and (m := OLD_STATUS.match(line.strip())):
            gap["status"], gap["format"] = m["value"].strip(), "old"
        if gap["skill"] is None and (m := HEADER.match(line)):
            gap["skill"] = m["skill"].strip()
        if gap["since"] is None and (m := OWNER.search(line)):
            gap["since"] = f"{m['date']} {m['time']}"
    if found := FOUND_AT.search(gap["found"] or ""):
        gap["since"] = f"{found['date']} {found['time'] or '00:00'}"
    return gap


def named_paths(folder, gap):
    """Files the Proposed edit targets: the ticked paths before its first ` › ` or `:` outside backticks, that exist.
    A path is absolute (`~` allowed), relative to the skill's folder, or relative to the registry."""
    edit, out, pos = gap["proposed_edit"] or "", [], 0
    for m in TICKED.finditer(edit):
        between = edit[pos:m.start()]
        if ":" in between or "›" in between or "§" in between:
            break
        pos = m.end()
        token = m["text"].strip().split(" ")[0]
        for candidate in (Path(token).expanduser(), folder / token, REGISTRY / token):
            if candidate.is_absolute() and candidate.exists() and candidate.resolve() not in out:
                out.append(candidate.resolve())
                break
    return out


def changes_since(gap, paths):
    """Commits since the gap was found and uncommitted changes, for these paths: [{sha, subject}]."""
    rel = [str(p) for p in paths]
    changes = []
    if gap["since"]:
        log = git("log", "--format=%h%x09%s", f"--since={gap['since']}", "HEAD", "--", *rel) or ""
        for line in log.splitlines():
            sha, _, subject = line.partition("\t")
            changes.append({"sha": sha, "subject": subject})
    since = datetime.strptime(gap["since"], "%Y-%m-%d %H:%M").timestamp() if gap["since"] else None
    root = Path((git("rev-parse", "--show-toplevel") or str(REGISTRY)).strip())
    status = git("status", "--porcelain", "--untracked-files=all", "--", *rel) or ""
    for line in status.splitlines():
        file = root / line[3:]
        if since is None or not file.exists() or file.stat().st_mtime > since:
            changes.append({"sha": "working", "subject": f"uncommitted {line[:2].strip() or '?'} {line[3:]}"})
    return changes


def classify(skills, gap):
    """Sets gap['class'], gap['reason'], gap['commits'] and gap['paths']."""
    status = (gap["status"] or "").strip().lower()
    gap["commits"], gap["paths"] = [], []
    if status.startswith(("fixed", "not a gap")):
        return "closed", f"Status: {gap['status']}"
    note = "" if status == "open" else f" (Status {gap['status']!r} is not a core.md value; treated as open)"
    folder = skills.get(gap["skill"] or "")
    if folder is None:
        return "stale", f"no skill {gap['skill']!r} in {REGISTRY}{note}"
    paths = named_paths(folder, gap) or [folder.resolve()]
    gap["paths"] = [str(p) for p in paths]
    basis = f"since {gap['since']}" if gap["since"] else "(no Found time; uncommitted changes only)"
    commits = changes_since(gap, paths)
    gap["commits"] = commits
    if commits:
        return "likely-fixed", f"{', '.join(gap['paths'])} changed {basis}: {len(commits)} change(s){note}"
    if (old := REPLACE.search(gap["proposed_edit"] or "")) and paths[0].is_file():
        quote = " ".join(old["old"].replace("\\`", "`").split())
        if quote not in " ".join(paths[0].read_text(encoding="utf-8", errors="replace").split()):
            return "stale", f"the text to replace is not in {paths[0]}: {old['old'][:60]!r}{note}"
    return "open", f"no change to {', '.join(gap['paths'])} {basis}{note}"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--dir", type=Path, help="gap folder to read (default: skill-gaps/ next to the registry)")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    folder = (args.dir or REGISTRY.parent / "skill-gaps").expanduser().resolve()
    if folder.exists() and not folder.is_dir():
        print(f"{folder} is not a folder.", file=sys.stderr)
        return 2

    skills = skill_folders()
    gaps = [parse(p) for p in sorted(folder.glob("*.md"))] if folder.is_dir() else []
    for gap in gaps:
        gap["class"], gap["reason"] = classify(skills, gap)
    totals = Counter(g["class"] for g in gaps)

    if args.json:
        print(json.dumps({"folder": str(folder), "registry": str(REGISTRY), "totals": dict(totals), "gaps": gaps},
                         indent=2, ensure_ascii=False))
        return 0

    print(f"Skill gaps in {folder}: {len(gaps)}" + "".join(f", {totals[c]} {c}" for c in CLASSES if totals[c]))
    if not gaps:
        return 0
    width = max(len(g["skill"] or "?") for g in gaps)
    for cls in CLASSES:
        for g in (g for g in gaps if g["class"] == cls):
            print(f"\n  {cls:<12} {g['skill'] or '?':<{width}}  {g['file']}")
            print(f"  {'':<12} {'':<{width}}  {g['reason']}")
            for c in g["commits"][:5]:
                print(f"  {'':<12} {'':<{width}}    {c['sha']} {c['subject'][:90]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
