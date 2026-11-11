#!/usr/bin/env python3
"""Session identity and state colours for Claude Code. One script for every hook event it listens to.

Identity (which project) comes from claude/session-colors.json: ordered rules, first match wins, else a hash of
the repo name. State (what the session is doing) comes from the event: working, waiting, done, plan.

In tmux the pane carries its identity colour (@claude_frame, read by the border styles in tmux.conf) and its
state as a pill (@claude_pill for the pane border, @claude_glyph for the window tab). The pane background is
never touched. Every event also prints an OSC 2 title
(terminalSequence) so a plain terminal shows the state too. statusline.sh reads the state file for its badge.
Any error exits 0 without output: a hook bug must never block a prompt.
"""
import fnmatch
import json
import os
import re
import subprocess
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONFIG = Path(os.environ.get("SESSION_COLORS_CONFIG") or HERE / "session-colors.json")
STATE = Path(os.environ.get("SESSION_LOOK_DIR") or Path.home() / ".claude" / "session-look")
# Notification types that mean the session needs the user; idle_prompt fires ~60 s after Stop and stays done
WAITING_NOTIFICATIONS = {"permission_prompt", "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input"}
WORKTREE_MARK = "/.claude/worktrees/"


def main():
    try:
        data = json.load(sys.stdin)
        out = handle(data, load_config(), tmux_pane=os.environ.get("TMUX_PANE"))
        if out:
            print(json.dumps(out, ensure_ascii=False))
    except Exception:
        pass


def handle(data, config, tmux_pane, run=None):
    """Apply one hook event. Returns the hook output dict, or None."""
    run = run or run_tmux
    sid, event = data["session_id"], data.get("hook_event_name")
    if event == "SessionEnd":
        if tmux_pane:
            run(reset_args(tmux_pane))
        (STATE / f"{sid}.json").unlink(missing_ok=True)
        return None
    record = None if event == "SessionStart" else load_record(sid)
    if record is None:
        color = pick_color(config, data.get("cwd") or "")
        record = {"color": color, "frame": config["colors"][color]["frame"], "state": None, "mode": None}
    state = state_for(event, data)
    if state is None:
        return None
    mode = data.get("permission_mode") or record["mode"]
    if mode == "plan" and state in ("working", "done"):
        state = "plan"
    look = config["colors"][record["color"]]
    spec = config["states"][state]
    changed = (record["state"], record["mode"]) != (state, mode)
    record |= {"state": state, "mode": mode, "glyph": spec["glyph"], "label": spec["label"], "sgr": look["sgr"]}
    save_record(sid, record)
    if tmux_pane and (changed or event == "SessionStart"):
        run(apply_args(tmux_pane, record["frame"], spec, repo_name(data.get("cwd") or "")))
    out = {"terminalSequence": osc_title(f"{spec['glyph']} {record['color']}")}
    if event == "SessionStart" and config.get("color_command"):
        out["initialUserMessage"] = f"/color {record['color']}"
    return out


def state_for(event, data):
    if event == "SessionStart":
        return "done"
    if event in ("UserPromptSubmit", "PreToolUse"):
        return "working"
    if event == "PermissionRequest":
        return "waiting"
    if event == "Notification":
        return "waiting" if data.get("notification_type") in WAITING_NOTIFICATIONS else None
    if event == "Stop":
        return "done"
    return None


def pick_color(config, cwd):
    path = os.path.expanduser(cwd)
    branch = None
    for rule in config.get("rules", []):
        if "cwd" in rule and not fnmatch.fnmatch(path, os.path.expanduser(rule["cwd"])):
            continue
        if "branch" in rule:
            branch = branch if branch is not None else git_branch(path)
            if not re.search(rule["branch"], branch):
                continue
        return rule["color"]
    names = sorted(config["colors"])
    return names[zlib.crc32(repo_name(path).encode()) % len(names)]


def repo_name(path):
    """Repo directory name; a /.claude/worktrees/<slug> checkout counts as its main repo."""
    if WORKTREE_MARK in path:
        return Path(path.split(WORKTREE_MARK)[0]).name
    p = Path(path)
    for candidate in (p, *p.parents):
        if (candidate / ".git").exists():
            return candidate.name
    return p.name


def git_branch(path):
    try:
        res = subprocess.run(["git", "-C", path, "symbolic-ref", "--short", "-q", "HEAD"],
                             capture_output=True, text=True, timeout=2)
        return res.stdout.strip()
    except Exception:
        return ""


def apply_args(pane, frame, spec, repo):
    pill = f"#[bg={spec['pill']},fg=#11111b] {spec['glyph']} {spec['tag']} #[default]"
    return [
        "set-option", "-p", "-t", pane, "@claude_frame", frame, ";",
        "set-option", "-p", "-t", pane, "@claude_pill", pill, ";",
        "set-option", "-w", "-t", pane, "@claude_glyph", pill, ";",
        "select-pane", "-t", pane, "-T", repo,
    ]


def reset_args(pane):
    return [
        # window-style: clears the tint v1 left in panes that were open during the upgrade
        "set-option", "-pu", "-t", pane, "window-style", ";",
        "set-option", "-pu", "-t", pane, "@claude_frame", ";",
        "set-option", "-pu", "-t", pane, "@claude_pill", ";",
        "set-option", "-wu", "-t", pane, "@claude_glyph", ";",
        "select-pane", "-t", pane, "-T", "",
    ]


def run_tmux(args):
    # Detached and not awaited: waiting on the tmux client put the hook's p95 over 100 ms. No inherited
    # stdout, so Claude Code reads the hook's output without waiting for tmux to exit
    subprocess.Popen(["tmux", *args], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


def osc_title(text):
    clean = "".join(ch for ch in text if ch >= " " and ch != "\x7f")
    return f"\x1b]2;{clean}\x07"


def load_config():
    return json.loads(CONFIG.read_text())


def load_record(sid):
    try:
        return json.loads((STATE / f"{sid}.json").read_text())
    except (OSError, ValueError):
        return None


def save_record(sid, record):
    STATE.mkdir(parents=True, exist_ok=True)
    # Per-process tmp name: parallel hooks of one session never share it, and rename is atomic
    tmp = STATE / f".{sid}.{os.getpid()}.tmp"
    tmp.write_text(json.dumps(record, ensure_ascii=False))
    os.replace(tmp, STATE / f"{sid}.json")


if __name__ == "__main__":
    main()
