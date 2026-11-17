#!/usr/bin/env python3
"""Parse each JSON file and flag duplicate keys; skip files that allow comments by convention.

Usage: python3 -I check_json.py <file> …   (exit 1 when any file fails)
"""
import fnmatch
import json
import pathlib
import sys

JSONC = ("tsconfig*.json", "*.jsonc", "devcontainer.json", "*/.vscode/*")


def no_duplicates(pairs):
    keys = [k for k, _ in pairs]
    dupes = sorted({k for k in keys if keys.count(k) > 1})
    if dupes:
        raise ValueError(f"duplicate key(s): {', '.join(dupes)}")
    return dict(pairs)


failed = False
for arg in sys.argv[1:]:
    path = pathlib.Path(arg)
    if any(fnmatch.fnmatch(path.name, p) or fnmatch.fnmatch(str(path), p) for p in JSONC):
        print(f"skip {arg} (JSON with comments)")
        continue
    try:
        json.loads(path.read_text(), object_pairs_hook=no_duplicates)
        print(f"ok   {arg}")
    except (ValueError, OSError) as e:
        failed = True
        print(f"FAIL {arg}: {e}")
sys.exit(1 if failed else 0)
