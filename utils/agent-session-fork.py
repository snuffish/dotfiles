#!/usr/bin/env python3
"""
agent-session-fork.py: Transpile and fork agent conversations between Claude Code and Antigravity.
Supports:
  --from claude --to agy --id <session_id> [--cwd <cwd>]
  --from agy --to claude --id <session_id> [--cwd <cwd>]
  --from agy --to agy --id <session_id> [--cwd <cwd>]

Output contract: prints a session id for `--to claude`, and the path of a seed
handoff .md for `--to agy`. agy cannot load a conversation this script builds or
copies (it reads ~/.gemini/antigravity-cli/conversations/<id>.db, and a copied .db
keeps the source's internal trajectory id), so an agy fork is a new session seeded
with the old history: `agy -i "<prompt naming the seed file>"`.
"""

import argparse
import glob
import json
import os
import re
import shutil
import sqlite3
import sys
import time
import uuid

MAX_CLAUDE_CHARS = 480_000  # ~120k tokens safe limit for Claude context window


def clean_claude_user_text(text: str) -> str:
    """Strip Claude harness wrappers from user text."""
    if not isinstance(text, str):
        return ""
    text = re.sub(r"<system-reminder>[\s\S]*?</system-reminder>", "", text)
    text = re.sub(r"<command-message>[^<]*</command-message>\s*", "", text)
    text = re.sub(r"<local-command-caveat>[\s\S]*?</local-command-caveat>\s*", "", text)
    text = re.sub(r"<task-notification>[\s\S]*?</task-notification>\s*", "", text)
    text = re.sub(
        r"<command-name>(?P<n>[^<]*)</command-name>\s*(?:<command-args>(?P<a>[\s\S]*?)</command-args>)?",
        lambda m: f"{m.group('n')} {m.group('a') or ''}".strip(),
        text,
    )
    return text.strip()


def clean_agy_user_text(text: str) -> str:
    """Strip Antigravity harness wrappers from user content."""
    if not isinstance(text, str):
        return ""
    text = re.sub(r"<ADDITIONAL_METADATA>[\s\S]*?</ADDITIONAL_METADATA>", "", text)
    text = re.sub(r"<USER_SETTINGS_CHANGE>[\s\S]*?</USER_SETTINGS_CHANGE>", "", text)
    text = re.sub(r"<SYSTEM_MESSAGE>[\s\S]*?</SYSTEM_MESSAGE>", "", text)
    text = re.sub(r"<USER_REQUEST>\s*", "", text)
    text = re.sub(r"</USER_REQUEST>\s*", "", text)
    return text.strip()


def find_claude_session_file(session_id: str) -> str | None:
    projects_dir = os.path.expanduser("~/.claude/projects")
    # Exact or prefix match
    matches = glob.glob(os.path.join(projects_dir, "*", f"{session_id}*.jsonl"))
    if matches:
        return matches[0]
    # Check recursive if needed
    for root, _, files in os.walk(projects_dir):
        for f in files:
            if f.endswith(".jsonl") and session_id in f:
                return os.path.join(root, f)
    return None


MAX_AGY_SEED_CHARS = int(os.environ.get("MAX_AGY_SEED_CHARS", "200000"))


def write_agy_seed(steps: list, label: str, source_id: str, title, cwd: str, dry_run: bool) -> str:
    """Render normalized steps (agy transcript shape) to a handoff .md; return its path."""
    forks_dir = os.path.expanduser("~/.cache/agy-forks")
    ts = time.strftime("%Y%m%d-%H%M%S")
    path = os.path.join(forks_dir, f"{label}-{source_id[:8]}-{ts}.md")

    blocks = []
    for s in steps:
        stype = s.get("type")
        content = (s.get("content") or "").strip()
        if stype == "USER_INPUT":
            text = clean_agy_user_text(content) if label == "agy" else re.sub(
                r"</?USER_REQUEST>", "", content
            ).strip()
            if text:
                blocks.append(f"## User\n\n{text}\n")
        elif stype == "PLANNER_RESPONSE":
            parts = [content] if content else []
            for tc in s.get("tool_calls") or []:
                args = json.dumps(tc.get("args", {}), ensure_ascii=False)
                parts.append(f"[tool {tc.get('name')}: {args[:300]}]")
            if parts:
                blocks.append("## Assistant\n\n" + "\n\n".join(parts) + "\n")
        elif stype == "GENERIC" and content:
            blocks.append(f"[tool result: {content[:400]}]\n")

    total, kept = 0, []
    for b in reversed(blocks):
        total += len(b)
        if total > MAX_AGY_SEED_CHARS and kept:
            break
        kept.append(b)
    kept.reverse()
    while kept and not kept[0].startswith("## User"):
        kept.pop(0)  # start on a user turn
    truncated = len(kept) < len(blocks)

    header = (
        f"# Forked session: {title or source_id}\n\n"
        f"Source: {label} session {source_id}; working directory {cwd}.\n"
        + (f"Truncated to the newest {len(kept)} of {len(blocks)} turns; full history is not kept here.\n" if truncated else "")
        + "\n---\n\n"
    )
    if dry_run:
        return f"[DRY-RUN] Would write seed {path} ({len(kept)}/{len(blocks)} turns)"
    os.makedirs(forks_dir, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(header + "\n".join(kept))
    os.chmod(path, 0o600)
    return path


def claude_to_agy(source_id: str, cwd: str, dry_run: bool = False) -> str:
    src_file = find_claude_session_file(source_id)
    if not src_file or not os.path.isfile(src_file):
        raise FileNotFoundError(f"Claude session file not found for ID: {source_id}")

    transcript_steps = []
    step_idx = 0
    title = None

    with open(src_file, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if not line.strip():
                continue
            try:
                record = json.loads(line)
            except Exception:
                continue

            rtype = record.get("type")

            # Extract title if available
            if rtype == "ai-title" and (record.get("aiTitle") or record.get("title")):
                title = record.get("aiTitle") or record.get("title")

            ts = record.get("timestamp") or time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            msg = record.get("message", {})
            content = msg.get("content")

            if rtype == "user":
                if isinstance(content, str):
                    cleaned = clean_claude_user_text(content)
                    if cleaned:
                        if not title:
                            title = cleaned.splitlines()[0][:80]
                        transcript_steps.append({
                            "step_index": step_idx,
                            "source": "USER_EXPLICIT",
                            "type": "USER_INPUT",
                            "status": "DONE",
                            "created_at": ts,
                            "content": f"<USER_REQUEST>\n{cleaned}\n</USER_REQUEST>",
                        })
                        step_idx += 1
                elif isinstance(content, list):
                    # Check for tool_result vs text
                    for block in content:
                        if not isinstance(block, dict):
                            continue
                        if block.get("type") == "tool_result":
                            res_content = block.get("content", "")
                            if isinstance(res_content, list):
                                res_text = "\n".join(
                                    b.get("text", "") for b in res_content if isinstance(b, dict)
                                )
                            else:
                                res_text = str(res_content)
                            transcript_steps.append({
                                "step_index": step_idx,
                                "source": "MODEL",
                                "type": "GENERIC",
                                "status": "DONE",
                                "created_at": ts,
                                "content": res_text,
                            })
                            step_idx += 1
                        elif block.get("type") == "text":
                            cleaned = clean_claude_user_text(block.get("text", ""))
                            if cleaned:
                                transcript_steps.append({
                                    "step_index": step_idx,
                                    "source": "USER_EXPLICIT",
                                    "type": "USER_INPUT",
                                    "status": "DONE",
                                    "created_at": ts,
                                    "content": f"<USER_REQUEST>\n{cleaned}\n</USER_REQUEST>",
                                })
                                step_idx += 1

            elif rtype == "assistant":
                text_parts = []
                thinking_parts = []
                tool_calls = []

                if isinstance(content, list):
                    for block in content:
                        if not isinstance(block, dict):
                            continue
                        btype = block.get("type")
                        if btype == "text":
                            text_parts.append(block.get("text", ""))
                        elif btype == "thinking":
                            thinking_parts.append(block.get("thinking", ""))
                        elif btype == "tool_use":
                            tname = block.get("name")
                            tinput = block.get("input", {})
                            # Remap tools
                            if tname == "Bash":
                                tool_calls.append({
                                    "name": "run_command",
                                    "args": {
                                        "CommandLine": tinput.get("command", ""),
                                        "toolSummary": tinput.get("description", "Run command"),
                                        "WaitMsBeforeAsync": 5000,
                                    },
                                })
                            elif tname == "FileEdit":
                                tool_calls.append({
                                    "name": "edit_file",
                                    "args": {
                                        "Path": tinput.get("file_path", ""),
                                        "Target": tinput.get("old_string", ""),
                                        "Replacement": tinput.get("new_string", ""),
                                    },
                                })
                            elif tname in ("View", "FileRead"):
                                tool_calls.append({
                                    "name": "read_file",
                                    "args": {
                                        "Path": tinput.get("file_path", ""),
                                    },
                                })
                            else:
                                # Flatten unmapped tool to assistant text note to prevent ghost tool errors
                                text_parts.append(
                                    f"[Ran tool `{tname}` with args: {json.dumps(tinput)}]"
                                )

                step_data = {
                    "step_index": step_idx,
                    "source": "MODEL",
                    "type": "PLANNER_RESPONSE",
                    "status": "DONE",
                    "created_at": ts,
                }
                if text_parts:
                    step_data["content"] = "\n\n".join(text_parts)
                if thinking_parts:
                    step_data["thinking"] = "\n\n".join(thinking_parts)
                if tool_calls:
                    step_data["tool_calls"] = tool_calls

                if text_parts or thinking_parts or tool_calls:
                    transcript_steps.append(step_data)
                    step_idx += 1

    return write_agy_seed(transcript_steps, "claude", source_id, title, cwd, dry_run)


def agy_to_claude(source_id: str, cwd: str, dry_run: bool = False) -> str:
    cli_dir = os.path.expanduser("~/.gemini/antigravity-cli")
    brain_dir = os.path.join(cli_dir, "brain", source_id)
    transcript_path = os.path.join(brain_dir, ".system_generated", "logs", "transcript.jsonl")
    if not os.path.isfile(transcript_path):
        transcript_path = os.path.join(brain_dir, ".system_generated", "logs", "transcript_full.jsonl")
    if not os.path.isfile(transcript_path):
        raise FileNotFoundError(f"Antigravity transcript not found for ID: {source_id}")

    target_uuid = str(uuid.uuid4())
    slug = re.sub(r"[^a-zA-Z0-9]", "-", cwd)
    proj_dir = os.path.expanduser(f"~/.claude/projects/{slug}")
    target_file = os.path.join(proj_dir, f"{target_uuid}.jsonl")

    # Read and parse steps
    raw_steps = []
    with open(transcript_path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if not line.strip():
                continue
            try:
                raw_steps.append(json.loads(line))
            except Exception:
                continue

    # Filter out system and ephemeral noise
    usable_steps = [
        s for s in raw_steps if s.get("type") in ("USER_INPUT", "PLANNER_RESPONSE", "GENERIC")
    ]

    # Context window truncation check
    total_chars = sum(len(s.get("content", "") or "") for s in usable_steps)
    if total_chars > MAX_CLAUDE_CHARS:
        sys.stderr.write(
            f"Transcript exceeds safe Claude size ({total_chars} chars). Truncating oldest turns...\n"
        )
        accum = 0
        truncated = []
        for s in reversed(usable_steps):
            accum += len(s.get("content", "") or "")
            truncated.append(s)
            if accum >= MAX_CLAUDE_CHARS:
                break
        truncated.reverse()
        # Find first USER_INPUT to keep conversation starting cleanly
        start_idx = 0
        for i, s in enumerate(truncated):
            if s.get("type") == "USER_INPUT":
                start_idx = i
                break
        usable_steps = truncated[start_idx:]

    claude_lines = []
    parent_uuid = None
    last_tool_id = None
    first_title = None

    # Header records
    claude_lines.append({"type": "mode", "mode": "normal", "sessionId": target_uuid})
    claude_lines.append({
        "type": "permission-mode",
        "permissionMode": "default",
        "sessionId": target_uuid,
    })

    for s in usable_steps:
        stype = s.get("type")
        ts = s.get("created_at") or time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        msg_uuid = str(uuid.uuid4())

        if stype == "USER_INPUT":
            raw_text = s.get("content", "")
            cleaned = clean_agy_user_text(raw_text)
            if not cleaned:
                continue
            if not first_title:
                first_title = cleaned.splitlines()[0][:80]
            record = {
                "type": "user",
                "sessionId": target_uuid,
                "uuid": msg_uuid,
                "parentUuid": parent_uuid,
                "timestamp": ts,
                "cwd": cwd,
                "message": {"role": "user", "content": cleaned},
            }
            claude_lines.append(record)
            parent_uuid = msg_uuid

        elif stype == "PLANNER_RESPONSE":
            content_blocks = []
            thinking = s.get("thinking")
            if thinking:
                content_blocks.append({"type": "thinking", "thinking": thinking})
            content_text = s.get("content")
            if content_text:
                content_blocks.append({"type": "text", "text": content_text})

            tool_calls = s.get("tool_calls", [])
            for tc in tool_calls:
                tname = tc.get("name")
                args = tc.get("args", {})
                last_tool_id = f"toolu_{uuid.uuid4().hex[:24]}"
                if tname == "run_command":
                    content_blocks.append({
                        "type": "tool_use",
                        "id": last_tool_id,
                        "name": "Bash",
                        "input": {
                            "command": args.get("CommandLine", ""),
                            "description": args.get("toolSummary", "Run command"),
                        },
                    })
                elif tname == "edit_file":
                    content_blocks.append({
                        "type": "tool_use",
                        "id": last_tool_id,
                        "name": "FileEdit",
                        "input": {
                            "file_path": args.get("Path", ""),
                            "old_string": args.get("Target", ""),
                            "new_string": args.get("Replacement", ""),
                        },
                    })
                elif tname == "read_file":
                    content_blocks.append({
                        "type": "tool_use",
                        "id": last_tool_id,
                        "name": "View",
                        "input": {
                            "file_path": args.get("Path", ""),
                        },
                    })
                else:
                    content_blocks.append({
                        "type": "text",
                        "text": f"[Invoked tool `{tname}` with: {json.dumps(args)}]",
                    })

            if content_blocks:
                record = {
                    "type": "assistant",
                    "sessionId": target_uuid,
                    "uuid": msg_uuid,
                    "parentUuid": parent_uuid,
                    "timestamp": ts,
                    "cwd": cwd,
                    "message": {"role": "assistant", "content": content_blocks},
                }
                claude_lines.append(record)
                parent_uuid = msg_uuid

        elif stype == "GENERIC":
            result_content = s.get("content", "")
            if not result_content:
                continue
            t_id = last_tool_id or f"toolu_{uuid.uuid4().hex[:24]}"
            record = {
                "type": "user",
                "sessionId": target_uuid,
                "uuid": msg_uuid,
                "parentUuid": parent_uuid,
                "timestamp": ts,
                "cwd": cwd,
                "message": {
                    "role": "user",
                    "content": [{"type": "tool_result", "tool_use_id": t_id, "content": result_content}],
                },
            }
            claude_lines.append(record)
            parent_uuid = msg_uuid

    if first_title:
        claude_lines.append({
            "type": "ai-title",
            "title": f"[Fork] {first_title}",
            "sessionId": target_uuid,
        })

    # Terminal leaf header required by Claude Code
    final_records = [
        {"type": "last-prompt", "leafUuid": parent_uuid or target_uuid, "sessionId": target_uuid}
    ] + claude_lines

    if dry_run:
        return f"[DRY-RUN] Would create Claude session {target_uuid} with {len(final_records)} records at {target_file}"

    os.makedirs(proj_dir, exist_ok=True)
    with open(target_file, "w", encoding="utf-8") as f:
        for r in final_records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    return target_uuid


def agy_to_agy(source_id: str, cwd: str, dry_run: bool = False) -> str:
    cli_dir = os.path.expanduser("~/.gemini/antigravity-cli")
    logs = os.path.join(cli_dir, "brain", source_id, ".system_generated", "logs")
    transcript_path = next(
        (p for p in (os.path.join(logs, "transcript.jsonl"), os.path.join(logs, "transcript_full.jsonl")) if os.path.isfile(p)),
        None,
    )
    if not transcript_path:
        raise FileNotFoundError(f"Antigravity transcript not found for ID: {source_id}")

    steps = []
    with open(transcript_path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            try:
                steps.append(json.loads(line))
            except Exception:
                continue

    title = None
    for s in steps:
        if s.get("type") == "USER_INPUT":
            cleaned = clean_agy_user_text(s.get("content", ""))
            if cleaned:
                title = cleaned.splitlines()[0][:80]
                break
    return write_agy_seed(steps, "agy", source_id, title, cwd, dry_run)


def main():
    parser = argparse.ArgumentParser(description="Cross-agent and intra-agent session fork transpiler.")
    parser.add_argument("--from", dest="from_agent", required=True, choices=["claude", "agy", "antigravity"])
    parser.add_argument("--to", dest="to_agent", required=True, choices=["claude", "agy", "antigravity"])
    parser.add_argument("--id", dest="session_id", required=True, help="Source conversation / session ID")
    parser.add_argument("--cwd", default=os.getcwd(), help="Target working directory")
    parser.add_argument("--dry-run", action="store_true", help="Simulate without writing files")

    args = parser.parse_args()
    from_agent = "antigravity" if args.from_agent == "agy" else args.from_agent
    to_agent = "antigravity" if args.to_agent == "agy" else args.to_agent

    try:
        if from_agent == "claude" and to_agent == "antigravity":
            res_id = claude_to_agy(args.session_id, args.cwd, args.dry_run)
        elif from_agent == "antigravity" and to_agent == "claude":
            res_id = agy_to_claude(args.session_id, args.cwd, args.dry_run)
        elif from_agent == "antigravity" and to_agent == "antigravity":
            res_id = agy_to_agy(args.session_id, args.cwd, args.dry_run)
        elif from_agent == "claude" and to_agent == "claude":
            # Native claude fork already handled via --fork-session
            res_id = args.session_id
        else:
            sys.stderr.write(f"Unsupported transition: {from_agent} -> {to_agent}\n")
            sys.exit(1)

        if to_agent == "antigravity" and not args.dry_run and not os.path.isfile(res_id):
            raise RuntimeError(f"seed file was not written: {res_id}")
        print(res_id)
    except Exception as e:
        sys.stderr.write(f"Error during fork: {e}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
