#!/usr/bin/env python3
"""PreToolUse hook for Agent|Task: deny a built-in agent spawn that names no model.

An Agent call without `model` runs on the session model (Opus, Fable), which is the most
expensive choice for lookup and mechanical work. The built-in types `general-purpose`,
`Explore`, `Plan` and `claude` (and a call with no type) have no model of their own, so the
hook asks the caller to pick one. `fork` and every custom type are allowed: a custom
agent's definition sets its model.

Hooks from the user's own settings may block a call but not rewrite it, so this denies.
Set CLAUDE_AGENT_MODEL_GUARD=0 to turn the guard off. Any error exits 0 (allow).
"""
import json
import os
import sys

TOOLS = {"Agent", "Task"}
BUILTIN = {"", "general-purpose", "explore", "plan", "claude"}

REASON = (
    "This Agent call names no `model`, so it would run on the session model. Name one: "
    "`model: \"sonnet\"` for lookup, search or mechanical work, or the session model explicitly "
    "(`opus`, `fable`) when the task needs it."
)


def decide(payload):
    """Return the deny reason, or None to allow."""
    if not isinstance(payload, dict) or payload.get("tool_name") not in TOOLS:
        return None
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        return None
    if tool_input.get("model"):
        return None
    kind = str(tool_input.get("subagent_type") or "").strip().lower()
    return REASON if kind in BUILTIN else None


def main():
    try:
        if os.environ.get("CLAUDE_AGENT_MODEL_GUARD") == "0":
            return 0
        reason = decide(json.load(sys.stdin))
        if reason:
            json.dump(
                {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": reason}},
                sys.stdout,
            )
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
