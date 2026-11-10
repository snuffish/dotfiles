#!/usr/bin/env python3
"""PreToolUse hook for Bash: deny commands whose side effects were costly before.

- `rm` with an unquoted glob: a glob deleted a user backup on 2026-11-03. Delete by exact path.
- `az repos pr update --description` without `--draft`: the call publishes a draft PR.
- An unquoted glob in a `--flag=value` word (`--include=*.py`, `--format=%(trailers)`): zsh expands it and
  aborts the whole command with "no matches found" (sessions d5b3dbc1, 26411941 and afba83ab).

Set CLAUDE_SAFETY_GUARD=0 to turn the guard off.
"""
import json
import os
import re
import sys

SEGMENT_START = re.compile(r"&&|\|\||[;\n(|]")
QUOTED = re.compile(r"'[^']*'|\"(?:[^\"\\]|\\.)*\"")
# rm as the segment's command, so `echo rm *` and `git rm` pass.
RM = re.compile(r"^\s*(sudo\s+)?rm\s")
GLOB = re.compile(r"[*?]|\[[^\]]*\]")
PR_UPDATE = re.compile(r"\baz\s+repos\s+pr\s+update\b")
# A `--flag=value` word whose value holds a glob character that no backslash escapes. A bare `(` counts
# (`--format=%(trailers)`, session afba83ab); the `(` of a `$(…)` substitution does not.
FLAG_GLOB = re.compile(r"(?<!\S)--[\w-]+=(?:\\.|\$\(|(?!\$\()[^\s\\*?(])*[*?(]\S*")


def segments(command):
    return SEGMENT_START.split(command)


def rm_glob(command):
    # Quoted globs reach rm literally, so only unquoted ones expand.
    unquoted = QUOTED.sub(lambda m: " " * len(m.group(0)), command)
    for segment in segments(unquoted):
        match = RM.search(segment)
        if match and GLOB.search(segment[match.end() :]):
            return segment.strip()
    return None


def pr_update_without_draft(command):
    # Quoted text such as "$(cat body.md)" holds no flags, and its `(` must not split the call.
    unquoted = QUOTED.sub(lambda m: " " * len(m.group(0)), command)
    for segment in segments(unquoted):
        if PR_UPDATE.search(segment) and "--description" in segment and "--draft" not in segment:
            return segment.strip()
    return None


def flag_glob(command):
    # Quoted globs reach the command literally, so only unquoted ones make zsh abort.
    unquoted = QUOTED.sub(lambda m: " " * len(m.group(0)), command)
    match = FLAG_GLOB.search(unquoted)
    return match.group(0) if match else None


def main():
    if os.environ.get("CLAUDE_SAFETY_GUARD") == "0":
        return 0
    payload = json.load(sys.stdin)
    if payload.get("tool_name") != "Bash":
        return 0
    command = (payload.get("tool_input") or {}).get("command") or ""
    if hit := rm_glob(command):
        reason = (
            f"`{hit}` deletes through a glob. List the matches first, then rm each approved path "
            "exactly, with no wildcards."
        )
    elif hit := pr_update_without_draft(command):
        reason = (
            "`az repos pr update --description` without `--draft` publishes a draft PR. Read the PR's "
            "isDraft and pass `--draft <isDraft>`."
        )
    elif hit := flag_glob(command):
        reason = (
            f"`{hit}` holds an unquoted glob: zsh expands it and aborts with \"no matches found\". "
            "Quote the value, e.g. `--include='*.py'`."
        )
    else:
        return 0
    json.dump(
        {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}},
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
