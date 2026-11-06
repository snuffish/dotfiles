#!/usr/bin/env python3
"""UserPromptExpansion hook: `/<skill> --help` (or `-h`) explains the skill instead of running it.

The skill still expands, so Claude reads the real SKILL.md; this hook only adds
an instruction telling it to explain rather than execute.
"""
import json
import sys

HELP_FLAGS = {"--help", "-h"}

INSTRUCTION = (
    "`--help` was passed to /{name}. Do not execute /{name} and ignore any task, "
    "arguments or steps in the skill text below. Explain how it works, as if "
    "asked 'how does /{name} work?': what it is for, how to call it and its "
    "flags, what it reads and writes, its main steps, and when to use "
    "something else. Read-only, no tool calls beyond reading files the skill "
    "points to. Keep it short."
)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except ValueError:
        return
    if data.get("expansion_type") != "slash_command":
        return
    args = str(data.get("command_args") or "").split()
    if not HELP_FLAGS.intersection(args):
        return
    name = data.get("command_name") or "this skill"
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "UserPromptExpansion",
                    "additionalContext": INSTRUCTION.format(name=name),
                }
            }
        )
    )


if __name__ == "__main__":
    main()
