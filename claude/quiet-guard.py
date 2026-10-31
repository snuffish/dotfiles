#!/usr/bin/env python3
"""PreToolUse hook for Bash: deny build, test and install commands whose output would land
in context unfiltered, and tell Claude to rerun them through `quiet`.

Hooks from the user's own settings may block a call but not rewrite it, so this denies
rather than wrapping. A noisy command passes when it already runs under `quiet`, runs in
the background, pipes or redirects its output, or asks only for help or a version.
Set CLAUDE_QUIET_GUARD=0 to turn the guard off.
"""
import json
import os
import re
import sys

NOISY = re.compile(
    r"\bdotnet\s+(build|test|restore|publish|format|pack)\b"
    r"|\bnpx\s+(playwright\s+test|tsc|eslint|vitest)\b"
    r"|\bnpm\s+(ci|install|i)\b"
    r"|\bnpm\s+run\s+(build|lint|test|e2e)[\w:-]*"
    r"|\bformat-changed\.ps1\b"
)
SEGMENT_START = re.compile(r"&&|\|\||[;\n(]")
PASS = re.compile(r"--help\b|\s-h\b|--version\b|--list\b")


def segment_of(command, start):
    begin = max((m.end() for m in SEGMENT_START.finditer(command, 0, start)), default=0)
    end = SEGMENT_START.search(command, start)
    return command[begin : end.start() if end else len(command)]


QUOTED = re.compile(r"'[^']*'|\"(?:[^\"\\]|\\.)*\"")


def needs_quiet(command):
    # Blank out quoted text so `git log --grep "dotnet test"` is not mistaken for a build.
    command = QUOTED.sub(lambda m: " " * len(m.group(0)), command)
    for match in NOISY.finditer(command):
        segment = segment_of(command, match.start())
        if re.search(r"(^|\s)quiet\s", segment) or re.search(r"[|>]", segment) or PASS.search(segment):
            continue
        return match.group(0)
    return None


def main():
    if os.environ.get("CLAUDE_QUIET_GUARD") == "0":
        return 0
    payload = json.load(sys.stdin)
    tool_input = payload.get("tool_input") or {}
    if payload.get("tool_name") != "Bash" or tool_input.get("run_in_background"):
        return 0
    noisy = needs_quiet(tool_input.get("command") or "")
    if not noisy:
        return 0
    reason = (
        f"`{noisy}` prints build/test noise that would stay in context. Rerun the same command with "
        f"`quiet` in front of it (e.g. `cd x && quiet {noisy} …`). quiet keeps the full log and prints "
        "errors, warning counts and the tail with the log path; read the log only if that is not enough."
    )
    json.dump(
        {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}},
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
