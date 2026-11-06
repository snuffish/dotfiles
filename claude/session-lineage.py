#!/usr/bin/env python3
"""Session titles and lineage for Claude Code. One script for SessionStart, UserPromptSubmit and SessionEnd.

Title: "<ticket> <glyph> <task>", e.g. "22470 ⟲ grill skill drift ADR". The glyph says how the session began
(· startup, ⟲ /clear, ⑂ /branch or fork) and the task comes from the first prompt that has real words in it.
/clear and forks inherit the previous session's custom title, so a new session's title is replaced unless the
user set one by hand (--name at startup, or /rename after the session started).

Lineage: one JSON file per session in ~/.claude/session-lineage/, read by the `cs` picker. A /clear session's
parent comes from the SessionEnd(clear) of the same claude process; a fork's parent is the transcript that
holds the fork's first copied message.
"""
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

STATE = Path(os.environ.get("SESSION_LINEAGE_DIR") or Path.home() / ".claude" / "session-lineage")
GLYPHS = {"startup": "·", "clear": "⟲", "fork": "⑂"}
GENERIC_BRANCHES = {"main", "master", "develop", "HEAD"}
MAX_TITLE = 50
MAX_NAMING_PROMPTS = 3  # give up after this many prompts without usable words; Claude's own title stays
FILLER = set(
    "a an the please pls can could would you we i me my just quickly also and or then so ok okay hey hi "
    "hello thanks thank lets let's now this that it is are be to of for in on with if not do does what why how "
    "error exit code".split()
)


def main():
    data = json.load(sys.stdin)
    STATE.mkdir(parents=True, exist_ok=True)
    event = data.get("hook_event_name")
    if event == "SessionStart":
        on_start(data)
    elif event == "UserPromptSubmit":
        on_prompt(data)
    elif event == "SessionEnd":
        on_end(data)


def on_start(data):
    sid, source = data["session_id"], data.get("source", "startup")
    record = load(sid)
    if record and source in ("resume", "compact"):
        save(sid, record | {"updated": now()})
        return
    if source not in GLYPHS:
        return
    cwd = data.get("cwd") or ""
    branch, tag = branch_and_tag(cwd)
    inherited = data.get("session_title") or ""
    parent = clear_parent() if source == "clear" else fork_parent(data.get("transcript_path"))
    # "/clear <name>" renames the session being left; keep its record in step
    if parent and (parent_record := load(parent)) and (name := latest_custom_title(parent_record.get("transcript"))):
        save(parent, parent_record | {"title": name})
    save(sid, {
        "id": sid, "parent": parent, "source": source, "tag": tag, "branch": branch, "cwd": cwd,
        "transcript": data.get("transcript_path"), "started": now(), "updated": now(),
        "title": inherited, "inherited_title": inherited,
        # At startup a title can only come from --name, which wins; after /clear or a fork it is inherited
        "naming": "done" if source == "startup" and inherited else "pending",
        "naming_prompts": 0, "first_prompt": "", "last_prompt": "",
    })
    if source == "clear" and parent:
        # systemMessage prints in the new session's terminal; the id is what `claude -r` takes
        previous = load(parent) or {}
        title = latest_custom_title(previous.get("transcript")) or previous.get("title") or "(untitled)"
        print(json.dumps({"systemMessage": f"Previous session: {title}\n  claude -r {parent}"}, ensure_ascii=False))


def on_prompt(data):
    sid = data["session_id"]
    record = load(sid)
    if not record:
        return
    prompt = data.get("prompt") or ""
    if is_noise(prompt):
        return
    text = one_line(prompt)
    record |= {"last_prompt": text[:200], "updated": now()}
    record["first_prompt"] = record["first_prompt"] or text[:200]
    if record["naming"] == "pending" and not renamed_by_user(record):
        record["naming_prompts"] += 1
        task = task_words(prompt)
        if task:
            title = f"{record['tag']} {GLYPHS[record['source']]} {task}".strip()[:MAX_TITLE].rstrip()
            record |= {"title": title, "naming": "done"}
            save(sid, record)
            print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "sessionTitle": title}}))
            return
        if record["naming_prompts"] >= MAX_NAMING_PROMPTS:
            record["naming"] = "gave-up"
    elif record["naming"] == "pending":
        record["naming"] = "user"
    save(sid, record)


def on_end(data):
    sid = data["session_id"]
    record = load(sid)
    if record:
        save(sid, record | {"ended": now(), "end_reason": data.get("reason"), "updated": now()})
    if data.get("reason") == "clear" and (pid := claude_pid()):
        (STATE / f".cleared-by-{pid}").write_text(sid)


# Parents

def clear_parent():
    pid = claude_pid()
    marker = STATE / f".cleared-by-{pid}" if pid else None
    if not marker or not marker.exists():
        return None
    parent = marker.read_text().strip()
    marker.unlink(missing_ok=True)
    return parent or None


def fork_parent(transcript_path):
    """A fork copies its parent's messages with their uuids; the oldest other transcript holding the first one is the parent."""
    if not transcript_path or not os.path.exists(transcript_path):
        return None
    first_uuid = None
    with open(transcript_path, errors="ignore") as f:
        for line in f:
            if m := re.search(r'"uuid":"([0-9a-f-]{36})"', line):
                first_uuid = m.group(1)
                break
    if not first_uuid:
        return None
    me = Path(transcript_path)
    candidates = [p for p in me.parent.glob("*.jsonl") if p != me]
    candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    needle = f'"uuid":"{first_uuid}"'
    for p in candidates[:200]:
        try:
            if needle in p.read_text(errors="ignore"):
                return p.stem
        except OSError:
            continue
    return None


# Titles

def renamed_by_user(record):
    """A custom title in the transcript that neither came with the session nor from this hook was set with /rename."""
    latest = latest_custom_title(record.get("transcript"))
    return bool(latest) and latest not in (record.get("inherited_title"), record.get("title"))


def latest_custom_title(path):
    if not path or not os.path.exists(path):
        return None
    latest = None
    with open(path, errors="ignore") as f:
        for line in f:
            if '"type":"custom-title"' in line:
                try:
                    latest = json.loads(line).get("customTitle")
                except ValueError:
                    pass
    return latest


def task_words(prompt):
    prompt = prompt.strip()
    # Slash command: its name plus the first arguments, so "/proceed handoff-31301.md" and "/proceed" differ
    if m := re.search(r"<command-name>/?([\w:.-]+)</command-name>", prompt):
        args = re.search(r"<command-args>(.*?)</command-args>", prompt, re.S)
        name, rest = m.group(1), args.group(1) if args else ""
    elif m := re.match(r"/([\w:.-]+)\s*(.*)", prompt, re.S):
        name, rest = m.group(1), m.group(2)
    else:
        name = None
    if name:
        return " ".join([name.split(":")[-1], *words(rest, keep_filler=True)[:4]])
    picked = [w for w in words(prompt) if w.lower() not in FILLER]
    return " ".join(picked[:6]) if len(picked) >= 2 else ""


def words(text, keep_filler=False):
    text = re.sub(r"```.*?```|`[^`]*`|<[^>]+>|https?://\S+", " ", text, flags=re.S)
    tokens = []
    for raw in text.split():
        token = Path(raw).name if "/" in raw else raw  # paths shrink to their file name
        token = token.strip(".,:;!?()[]{}\"'*")
        if token and re.search(r"[\w]", token) and (keep_filler or len(token) > 1):
            tokens.append(token)
    return tokens


def is_noise(prompt):
    head = prompt.lstrip()[:40]
    return not head or head.startswith(("<task-notification", "<system-reminder", "[SYSTEM", "<local-command"))


def one_line(text):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", text)).strip()


def branch_and_tag(cwd):
    """Branch, and the title tag: the ticket number in the branch, else a linked worktree's folder name."""
    if not cwd:
        return "", ""
    branch = git(cwd, "symbolic-ref", "--quiet", "--short", "HEAD")
    if m := re.match(r"(?:[A-Za-z]+/)?(\d+)[_-]", branch):
        return branch, m.group(1)
    if not branch or branch in GENERIC_BRANCHES:
        dirs = git(cwd, "rev-parse", "--path-format=absolute", "--git-dir", "--git-common-dir").splitlines()
        if len(dirs) == 2 and dirs[0] != dirs[1]:
            return branch, Path(dirs[0]).name.removeprefix("worktree-")[:24]
    return branch, ""


def git(cwd, *args):
    try:
        return subprocess.run(["git", "--no-optional-locks", "-C", cwd, *args],
                              capture_output=True, text=True, timeout=3).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def claude_pid():
    pid = os.getppid()
    for _ in range(6):
        try:
            out = subprocess.run(["ps", "-o", "ppid=,comm=", "-p", str(pid)],
                                 capture_output=True, text=True, timeout=2).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            return None
        if not out:
            return None
        ppid, comm = out.split(None, 1)
        if Path(comm).name == "claude":
            return pid
        pid = int(ppid)
    return None


# Storage

def load(sid):
    try:
        return json.loads((STATE / f"{sid}.json").read_text())
    except (OSError, ValueError):
        return None


def save(sid, record):
    path = STATE / f"{sid}.json"
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(record, ensure_ascii=False))
    tmp.replace(path)


def now():
    return int(time.time())


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # never block a session over a title
        print(f"session-lineage: {e}", file=sys.stderr)
