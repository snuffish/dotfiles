#!/usr/bin/env python3
"""PostToolUse hook: checks a just-written implementation plan against /plan › §2 Style (~/.claude/CLAUDE.md › Plans).

Plans reach disk through Write/Edit, or through Bash when artifact-protocol › Claim publishes a scratchpad draft (the
command names the target and prints the path it wrote). Only plans modified in the last two minutes are checked, so
reading an old plan doesn't nag. On a breach it adds a reminder to the conversation; it never blocks and always exits 0.
"""

import json
import os
import re
import sys
import time

PLAN_PATH = re.compile(r"[^\s'\"`()<>]*implementation_plan-[^\s'\"`()<>]*")
FRESH_SECONDS = 120
MAX_BULLET_WORDS = 25
MAX_PROSE_WORDS = 15
SKIP_PREFIXES = ("#", "|", ">", "<!--", "**Status", "**Suffix", "**Inputs")


def candidate_paths(event):
    tool_input = event.get("tool_input") or {}
    if event.get("tool_name") in ("Write", "Edit", "MultiEdit"):
        path = tool_input.get("file_path") or ""
        return [path] if PLAN_PATH.fullmatch(os.path.basename(path)) else []
    response = event.get("tool_response")
    output = "\n".join(str(response.get(key) or "") for key in ("stdout", "stderr")) if isinstance(response, dict) else ""
    found = PLAN_PATH.findall(str(tool_input.get("command") or "") + "\n" + output)
    return [os.path.expanduser(path if path.endswith(".md") else path + ".md") for path in found]


def problems_in(text):
    lines = text.splitlines()
    problems = []
    headings = [line for line in lines if line.startswith("## ")]
    if not headings or "Open Questions" not in headings[-1]:
        problems.append(f"the last section is {headings[-1] if headings else 'missing'!r}; Open Questions must be last")

    start = next((i for i, line in enumerate(lines) if line.startswith("## ") and "Open Questions" in line), None)
    if start is not None:
        blocks = []
        for line in lines[start + 1:]:
            if line.startswith("## "):
                break
            if re.match(r"(\d+\.|-)\s", line):  # a top-level question; indented lines belong to it
                blocks.append([line])
            elif blocks:
                blocks[-1].append(line)
        problems += [f"question without a Rec: {block[0].strip()[:80]}" for block in blocks
                     if not re.search(r"\*\*rec|\brec:", " ".join(block), re.IGNORECASE)]

    in_code = False
    for number, line in enumerate(lines, start=1):
        if line.startswith("```"):
            in_code = not in_code
        if in_code or not line.strip() or line.lstrip().startswith(SKIP_PREFIXES):
            continue
        words = len(re.sub(r"`[^`]*`", "x", line).split())
        bullet = re.match(r"\s*(-|\d+\.)\s", line)
        if words > (MAX_BULLET_WORDS if bullet else MAX_PROSE_WORDS):
            kind = "bullet" if bullet else "prose line"
            problems.append(f"L{number}: {kind} of {words} words; use fragments or sub-bullets: {line.strip()[:60]}")
    return problems


def main():
    event = json.load(sys.stdin)
    now = time.time()
    reports = []
    for path in dict.fromkeys(candidate_paths(event)):
        if not path.endswith(".md") or not os.path.isfile(path) or now - os.path.getmtime(path) > FRESH_SECONDS:
            continue
        with open(path, encoding="utf-8") as plan:
            problems = problems_in(plan.read())
        if problems:
            shown = problems[:8] + ([f"… {len(problems) - 8} more"] if len(problems) > 8 else [])
            reports.append(f"{path}:\n- " + "\n- ".join(shown))
    if not reports:
        return
    reminder = ("Plan style check (/plan › §2 Style, from ~/.claude/CLAUDE.md › Plans: extremely concise, questions "
                "at the end). Fix these before presenting the plan:\n" + "\n".join(reports))
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": reminder}},
                     ensure_ascii=False))


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stdin.reconfigure(encoding="utf-8")
        main()
    except Exception:  # a reminder hook must never break a tool call
        pass
    sys.exit(0)
