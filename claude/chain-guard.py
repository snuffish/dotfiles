#!/usr/bin/env python3
"""PreToolUse hook for Bash: deny compound commands, which allow rules never match.

Allow rules match only simple commands, so a chained, cd-prefixed, env-prefixed or multi-line
command always prompts the user, who rejected them in sessions 4855660a, 704ed014 and 9cfdf42e
despite the CLAUDE.md rule "One simple command per Bash call". Denied here:

- `&&`, `||`, `;` or a newline outside quotes (chains, multi-line scripts, heredocs); a
  backslash-newline continuation is one command and passes
A bare `cd <dir>` passes: fix-findings runs it as its own call so cwd-reading hooks see the tree.
- a leading `VAR=value` prefix
- a pipe into `head` or `tail` (use `quiet <cmd>`, or Read with offset/limit)

Text inside quotes is ignored, so `python3 -I -c "a; b"` and `git log --grep "x && y"` pass.
Set CLAUDE_CHAIN_GUARD=0 to turn the guard off.
"""
import json
import os
import re
import sys

QUOTED = re.compile(r"'[^']*'|\"(?:[^\"\\]|\\.)*\"")
CHECKS = [
    (re.compile(r"&&|\|\||;|\n"), "chains commands (`&&`, `||`, `;` or a newline)"),
    (re.compile(r"^\s*[A-Za-z_]\w*=\S*\s+\S"), "starts with a `VAR=value` prefix"),
    (re.compile(r"\|\s*(head|tail)\b"), "pipes into head/tail; use `quiet <cmd>` or Read with offset/limit"),
]


COMMENT = re.compile(r"(^|\s)#[^\n]*")
# `(cd <dir> && <one command>)`: the PRIIS team skills (priis-verify, priis-frontend-verify, priis-ship)
# prescribe this form for npm scripts. It passes and prompts as before; team docs are not ours to rewrite.
SUBSHELL_CD = re.compile(r"^\(\s*cd\s+[^\s;&|()]+\s*&&\s*[^;&|()\n]+\)$")


def problem(command):
    # A backslash-newline continues one command, so it is not a chain.
    unquoted = QUOTED.sub(lambda m: " " * len(m.group(0)), command.strip().replace("\\\n", " "))
    unquoted = COMMENT.sub(" ", unquoted).strip()
    if SUBSHELL_CD.match(unquoted):
        return None
    for pattern, why in CHECKS:
        if pattern.search(unquoted):
            return why
    return None


def main():
    if os.environ.get("CLAUDE_CHAIN_GUARD") == "0":
        return 0
    payload = json.load(sys.stdin)
    if payload.get("tool_name") != "Bash":
        return 0
    why = problem((payload.get("tool_input") or {}).get("command") or "")
    if not why:
        return 0
    reason = (
        f"This command {why}. Allow rules match only simple commands, so it would prompt the user. "
        "Split it into one simple command per Bash call (independent ones can go in parallel), "
        "or put a longer script in a scratchpad file and run that file."
    )
    json.dump(
        {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}},
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
