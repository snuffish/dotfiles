#!/usr/bin/env python3
"""SessionStart hook: report merge-conflict state in the session's git repo.

Flags an unfinished merge, rebase, cherry-pick or revert, unmerged paths, and conflict
markers left in changed files (e.g. a file staged before it was resolved). Silent when the
repo is clean or the directory is not a git repo. Tells both the user (systemMessage) and
Claude (additionalContext). Set CLAUDE_CONFLICT_CHECK=0 to turn it off.
"""
import json
import os
import re
import subprocess
import sys

OPERATIONS = {
    "MERGE_HEAD": "merge",
    "rebase-merge": "rebase",
    "rebase-apply": "rebase",
    "CHERRY_PICK_HEAD": "cherry-pick",
    "REVERT_HEAD": "revert",
}
MARKER = re.compile(rb"^(<{7}(?: |$)|={7}$|>{7}(?: |$)|\|{7}(?: |$))", re.M)
MAX_LISTED = 10
MAX_SCAN_BYTES = 2_000_000


def git(cwd, *args):
    result = subprocess.run(["git", "-C", cwd, *args], capture_output=True, timeout=5)
    return result.stdout.decode(errors="replace").strip() if result.returncode == 0 else None


def lines(text):
    return [line for line in (text or "").splitlines() if line]


def in_progress(cwd):
    found = []
    for name, label in OPERATIONS.items():
        path = git(cwd, "rev-parse", "--path-format=absolute", "--git-path", name)
        if path and os.path.exists(path) and label not in found:
            found.append(label)
    return found


def files_with_markers(cwd, top, skip):
    changed = set(lines(git(cwd, "diff", "--name-only", "HEAD")))
    changed |= set(lines(git(cwd, "ls-files", "--others", "--exclude-standard")))
    hits = []
    for rel in sorted(changed - skip):
        path = os.path.join(top, rel)
        try:
            if not os.path.isfile(path) or os.path.getsize(path) > MAX_SCAN_BYTES:
                continue
            with open(path, "rb") as handle:
                data = handle.read()
        except OSError:
            continue
        if b"\0" not in data and MARKER.search(data):
            hits.append(rel)
    return hits


def listing(paths):
    shown = [f"  - {p}" for p in paths[:MAX_LISTED]]
    if len(paths) > MAX_LISTED:
        shown.append(f"  - ... and {len(paths) - MAX_LISTED} more")
    return "\n".join(shown)


def main():
    if os.environ.get("CLAUDE_CONFLICT_CHECK") == "0":
        return
    try:
        cwd = json.load(sys.stdin).get("cwd") or os.getcwd()
    except (ValueError, AttributeError):
        cwd = os.getcwd()
    top = git(cwd, "rev-parse", "--show-toplevel")
    if not top:
        return

    operations = in_progress(cwd)
    unmerged = sorted(set(lines(git(cwd, "diff", "--name-only", "--diff-filter=U"))))
    markers = files_with_markers(cwd, top, set(unmerged))
    if not (operations or unmerged or markers):
        return

    parts = [f"Merge-conflict state in {top}:"]
    if operations:
        parts.append(f"- In progress: {', '.join(operations)} (not finished or aborted)")
    if unmerged:
        parts.append(f"- {len(unmerged)} unmerged path(s):\n{listing(unmerged)}")
    if markers:
        parts.append(f"- Conflict markers in {len(markers)} changed file(s):\n{listing(markers)}")
    report = "\n".join(parts)

    context = (
        f"{report}\n\nTell the user about this before other work. Do not resolve, continue, "
        "abort or commit the operation unless the user asks; /resolve-conflicts handles it."
    )
    print(json.dumps({
        "systemMessage": report,
        "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": context},
    }))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # never block session start
        print(f"conflict-check: {error}", file=sys.stderr)
