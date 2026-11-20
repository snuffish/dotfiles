#!/usr/bin/env python3
"""List, show and follow the background work Claude Code sessions start.

Three kinds of task:
  bash   a Bash call with run_in_background (or moved to the background):
         <root>/<project>/<session>/tasks/<id>.output, written as the command prints and
         ending with "[exited with code N]"; no such line = running (or killed with its session)
  agent  a background sub-agent: tasks/<id>.output links to its JSONL transcript; the
         sibling <id>.meta.json holds the description and "finished"
  pc     an /on-snuffish-pc run (id YYYYMMDD-HHMMSS-xxxx); handed to on_pc.py tail

Subcommands:
  list [--hours H] [--session S] [--pc]   tasks changed in the last H hours (default 6), newest last
  show <id> [-n N]                        the last N lines (agent transcripts rendered as text)
  follow <id> [-n N] [--pane]             print new output until the task ends; --pane does it
                                          in a new tmux pane below this one

<root> is $CLAUDE_TASKS_ROOT, else /private/tmp/claude-<uid> (macOS) or /tmp/claude-<uid>.
Exit 2 = unknown id, no tmux for --pane, or the PC unreachable.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

ON_PC = Path(__file__).resolve().parent.parent.parent / "on-snuffish-pc" / "scripts" / "on_pc.py"
PC_ID = re.compile(r"^\d{8}-\d{6}-[a-z0-9]{4}$")
EXIT_LINE = re.compile(r"^\[exited with code (-?\d+)\]$", re.M)
# "Command running in background with ID: X" (run_in_background) or "moved to the background (ID: X)".
BG_ID = re.compile(r"background (?:with ID: |\(ID: )(\w+)")
TEXT_MAX = 300  # characters kept from one rendered agent message


class TaskError(Exception):
    """Exit 2."""


def tasks_root() -> Path:
    env = os.environ.get("CLAUDE_TASKS_ROOT")
    if env:
        return Path(env)
    mac = Path("/private/tmp") / f"claude-{os.getuid()}"
    return mac if mac.is_dir() else Path("/tmp") / f"claude-{os.getuid()}"


def task_files() -> list[Path]:
    return sorted(tasks_root().glob("*/*/tasks/*.output"))


def find(task_id: str) -> Path:
    hits = [p for p in task_files() if p.stem == task_id]
    if not hits:
        raise TaskError(f"no task {task_id} under {tasks_root()}")
    return hits[-1]


def kind(path: Path) -> str:
    return "agent" if path.is_symlink() else "bash"


def agent_meta(path: Path) -> dict:
    meta = path.resolve().with_suffix(".meta.json")
    try:
        return json.loads(meta.read_text())
    except (OSError, ValueError):
        return {}


def bash_state(path: Path) -> str:
    try:
        size = path.stat().st_size
        with path.open("rb") as fh:
            fh.seek(max(0, size - 200))
            tail = fh.read().decode(errors="replace")
    except OSError:
        return "gone"
    m = EXIT_LINE.search(tail)
    return f"done exit {m.group(1)}" if m else "running"


def state(path: Path) -> str:
    if kind(path) == "agent":
        return "done" if agent_meta(path).get("finished") else "running"
    return bash_state(path)


def bash_labels(session_dir: Path) -> dict[str, str]:
    """Task id -> the Bash call's description, read from the session transcript."""
    transcript = Path.home() / ".claude" / "projects" / session_dir.parent.name / f"{session_dir.name}.jsonl"
    labels: dict[str, str] = {}
    inputs: dict[str, dict] = {}
    try:
        lines = transcript.read_text(errors="replace").splitlines()
    except OSError:
        return labels
    for raw in lines:
        if "tool_use" not in raw and "background" not in raw:
            continue
        try:
            content = (json.loads(raw).get("message") or {}).get("content")
        except ValueError:
            continue
        for block in content if isinstance(content, list) else []:
            if block.get("type") == "tool_use":
                inputs[block.get("id", "")] = block.get("input") or {}
            elif block.get("type") == "tool_result":
                body = block.get("content")
                text = body if isinstance(body, str) else " ".join(
                    b.get("text", "") for b in body or [] if isinstance(b, dict))
                m = BG_ID.search(text)
                if m:
                    inp = inputs.get(block.get("tool_use_id", ""), {})
                    labels[m.group(1)] = inp.get("description") or inp.get("command", "")[:80]
    return labels


def age(path: Path) -> str:
    secs = int(time.time() - path.stat().st_mtime)
    return f"{secs // 60}m" if secs < 3600 else f"{secs // 3600}h{secs % 3600 // 60:02d}m"


def cmd_list(args: argparse.Namespace) -> int:
    cutoff = time.time() - args.hours * 3600
    rows, labels = [], {}
    for p in task_files():
        try:
            mtime = p.stat().st_mtime
        except OSError:
            continue
        session = p.parent.parent
        if mtime < cutoff or (args.session and not session.name.startswith(args.session)):
            continue
        if kind(p) == "agent":
            label = agent_meta(p).get("description", "")
        else:
            if session not in labels:
                labels[session] = bash_labels(session)
            if p.stem not in labels[session] and state(p) == "running":
                continue  # foreground call: no background record
            label = labels[session].get(p.stem, "")
        rows.append((mtime, f"{p.stem:20}  {kind(p):5}  {state(p):12}  {age(p):>6} ago  "
                            f"{session.parent.name.rsplit('-', 1)[-1]}/{session.name[:8]}  {label}"))
    if args.pc:
        res = subprocess.run([sys.executable, "-I", str(ON_PC), "list"], text=True, capture_output=True)
        if res.returncode != 0:
            print(f"(PC: {res.stderr.strip()})")
        for line in res.stdout.splitlines() if res.returncode == 0 else []:
            run_id, _, st = line.partition(" ")
            if not PC_ID.match(run_id):
                continue
            started = time.mktime(time.strptime(run_id[:15], "%Y%m%d-%H%M%S"))
            if started >= cutoff:
                rows.append((started, f"{run_id:20}  pc     {st:12}  started {time.strftime('%H:%M', time.localtime(started))}"))
    for _, row in sorted(rows):
        print(row)
    if not rows:
        print(f"no tasks in the last {args.hours:g} h under {tasks_root()}" + (" or on the PC" if args.pc else ""))
    return 0


def render(raw: str) -> list[str]:
    """One agent transcript record as readable lines."""
    try:
        rec = json.loads(raw)
    except ValueError:
        return []
    msg = rec.get("message") or {}
    content = msg.get("content")
    role = msg.get("role")
    if isinstance(content, str):
        return [f"[{role}] {content[:TEXT_MAX]}"] if role else []
    out = []
    for block in content if isinstance(content, list) else []:
        t = block.get("type")
        if t == "text" and block.get("text", "").strip():
            out.append(f"[{role}] {block['text'].strip()[:TEXT_MAX]}")
        elif t == "tool_use":
            inp = block.get("input") or {}
            what = inp.get("description") or inp.get("command") or inp.get("file_path") or inp.get("pattern") or ""
            out.append(f"  -> {block.get('name')}: {str(what)[:160]}")
        elif t == "tool_result":
            body = block.get("content")
            text = body if isinstance(body, str) else " ".join(
                b.get("text", "") for b in body or [] if isinstance(b, dict))
            first = text.strip().splitlines()[0][:160] if text.strip() else ""
            out.append(f"  <- {'error: ' if block.get('is_error') else ''}{first}")
    return out


def lines_of(path: Path, text: str) -> list[str]:
    if kind(path) == "bash":
        return text.splitlines()
    return [line for raw in text.splitlines() for line in render(raw)]


def cmd_show(args: argparse.Namespace) -> int:
    if PC_ID.match(args.id):
        os.execv(sys.executable, [sys.executable, "-I", str(ON_PC), "tail", args.id, "-n", str(args.lines)])
    path = find(args.id)
    lines = lines_of(path, path.read_text(errors="replace"))
    print(f"{args.id} ({kind(path)}): {state(path)}  {path}")
    print("\n".join(lines[-args.lines:]) if lines else "(no output yet)")
    return 0


def open_pane(task_id: str, lines: int) -> int:
    if not os.environ.get("TMUX"):
        raise TaskError("--pane needs tmux; run: " + shlex.join(
            ["python3", "-I", str(Path(__file__).resolve()), "follow", task_id]))
    inner = shlex.join([sys.executable, "-I", str(Path(__file__).resolve()), "follow", task_id, "-n", str(lines)])
    res = subprocess.run(["tmux", "split-window", "-d", "-v", "-l", "30%", "-P", "-F", "#{pane_id}", inner],
                         text=True, capture_output=True)
    if res.returncode != 0:
        raise TaskError(f"tmux split-window failed: {res.stderr.strip()}")
    pane = res.stdout.strip()
    subprocess.run(["tmux", "set-option", "-p", "-t", pane, "remain-on-exit", "on"], capture_output=True)
    print(f"following {task_id} in tmux pane {pane} (close: tmux kill-pane -t {pane})")
    return 0


def cmd_follow(args: argparse.Namespace) -> int:
    if args.pane:
        if not PC_ID.match(args.id):
            find(args.id)
        return open_pane(args.id, args.lines)
    if PC_ID.match(args.id):
        os.execv(sys.executable, [sys.executable, "-I", str(ON_PC), "tail", args.id, "-n", str(args.lines), "-f"])
    path = find(args.id)
    print(f"following {args.id} ({kind(path)}); Ctrl-C stops the view, not the task", flush=True)
    target = path.resolve()
    pos, buf, shown = 0, "", False
    while True:
        try:
            with target.open("rb") as fh:
                fh.seek(pos)
                chunk = fh.read().decode(errors="replace")
                pos = fh.tell()
        except OSError:
            chunk = ""
        buf += chunk
        done_text, _, buf = buf.rpartition("\n")
        if done_text:
            new = lines_of(path, done_text)
            print("\n".join(new if shown else new[-args.lines:]), flush=True)
        shown = True
        st = state(path)
        if st != "running":
            if buf:
                print("\n".join(lines_of(path, buf)), flush=True)
            print(f"=== {args.id} {st}", flush=True)
            return 0
        time.sleep(args.poll)


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    ls = sub.add_parser("list")
    ls.add_argument("--hours", type=float, default=6)
    ls.add_argument("--session")
    ls.add_argument("--pc", action="store_true")
    ls.set_defaults(fn=cmd_list)
    sh = sub.add_parser("show")
    sh.add_argument("id")
    sh.add_argument("-n", "--lines", type=int, default=40)
    sh.set_defaults(fn=cmd_show)
    fo = sub.add_parser("follow")
    fo.add_argument("id")
    fo.add_argument("-n", "--lines", type=int, default=20)
    fo.add_argument("--pane", action="store_true")
    fo.add_argument("--poll", type=float, default=1)
    fo.set_defaults(fn=cmd_follow)
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        return args.fn(args)
    except TaskError as exc:
        print(f"tail_task: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
