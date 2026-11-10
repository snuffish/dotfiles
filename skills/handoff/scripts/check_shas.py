#!/usr/bin/env python3
"""List the commit SHAs an artifact names that are not on the current branch.

Usage: python3 -I check_shas.py <repo-root> <artifact.md>...

A reword, rebase or force-push leaves a handoff or plan naming commits that are gone from the branch
(test-bloat guards, 2026-11-10: four dead SHAs in the plan checklist). Exit 1 when any are found.
"""
import re
import subprocess
import sys
from pathlib import Path

# A backticked hex word of SHA length with at least one letter, so plain numbers pass.
SHA = re.compile(r"`([0-9a-f]{7,40})`")


def shas(text):
    return sorted({word for word in SHA.findall(text) if re.search(r"[a-f]", word)})


def on_branch(repo, sha):
    result = subprocess.run(["git", "-C", repo, "merge-base", "--is-ancestor", sha, "HEAD"], capture_output=True)
    return result.returncode == 0


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    repo, paths = argv[0], argv[1:]
    stale = [(path, sha) for path in paths for sha in shas(Path(path).read_text()) if not on_branch(repo, sha)]
    for path, sha in stale:
        print(f"{path}: `{sha}` is not an ancestor of HEAD")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
