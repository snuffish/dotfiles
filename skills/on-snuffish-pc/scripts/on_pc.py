#!/usr/bin/env python3
"""Run one task on Snuffish-PC in a detached tmux session and fetch the results.

Subcommands:
  start --kind shell|claude [--sync <repo>] [--model m] [--dest d] -- <task...>
  status <id>      running | done (exit N) | died
  wait <id>        poll until done, fetch, print the summary
  fetch <id>       copy log, exit, out/ and changes.patch back
  list             runs on the PC with their state

The host comes from ON_PC_HOST (default snuffish-pc). Exit 2 = setup error
(host unreachable, bad arguments, unknown run id).
"""

from __future__ import annotations

import argparse
import json
import os
import random
import shlex
import string
import subprocess
import sys
import tempfile
import time
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
BRIEF = SKILL_DIR.parent / "subagent" / "references" / "brief.md"
PC_RULES = SKILL_DIR / "references" / "pc-rules.md"
REMOTE_ROOT = ".cache/on-snuffish-pc"  # relative to the PC home directory
LOCAL_ROOT = Path.home() / ".cache" / "on-snuffish-pc" / "runs"
ARTIFACT_ROOT = Path.home() / ".cache" / "agent-artifacts"
SSH_OPTS = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=5"]
TAIL_LINES = 30      # log lines in the summary of a failed run
TAIL_LINES_OK = 15   # log lines in the summary of a successful run
OUT_LISTED = 10      # out/ file names listed in the summary


class SetupError(Exception):
    """Exit 2: the run could not start or the id is unknown."""


def host() -> str:
    return os.environ.get("ON_PC_HOST", "snuffish-pc")


def ssh_argv(remote_cmd: str) -> list[str]:
    return ["ssh", *SSH_OPTS, host(), remote_cmd]


def run(argv: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(argv, text=True, capture_output=True, **kw)


def remote_dir(run_id: str) -> str:
    return f"{REMOTE_ROOT}/{run_id}"


def new_run_id() -> str:
    suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=4))
    return time.strftime("%Y%m%d-%H%M%S-") + suffix


def probe() -> None:
    res = run(ssh_argv("true"))
    if res.returncode != 0:
        msg = (res.stderr or "").strip().splitlines()
        raise SetupError(f"{host()} unreachable: {msg[-1] if msg else 'ssh failed'}")


def sync_files(repo: Path) -> list[str]:
    """Tracked + untracked files, git-ignored ones excluded, deleted ones dropped."""
    res = run(["git", "-C", str(repo), "ls-files", "-co", "--exclude-standard", "-z"])
    if res.returncode != 0:
        raise SetupError(f"{repo} is not a git repository")
    names = sorted({n for n in res.stdout.split("\0") if n})
    return [n for n in names if (repo / n).is_file() or (repo / n).is_symlink()]


def default_dest(run_id: str) -> Path:
    # The main checkout's name, also from inside a linked worktree (<repo>/.git → <repo>).
    res = run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"])
    out = res.stdout.strip()
    repo = Path(out).parent.name if res.returncode == 0 and out else "misc"
    return ARTIFACT_ROOT / repo / "on-snuffish-pc" / run_id


def after_rule(text: str) -> str:
    """The prompt part of a reference file: everything after its first '---' line, rules dropped."""
    parts = text.split("\n---\n", 1)
    body = parts[1] if len(parts) == 2 else text
    return body.replace("\n---\n", "\n").strip()


def build_prompt(task: str) -> str:
    """PC rules, then the /subagent standing brief (which ends in 'Task:'), then the task."""
    return f"{after_rule(PC_RULES.read_text())}\n\n{after_rule(BRIEF.read_text())}\n{task}\n"


def run_script(kind: str, model: str | None) -> str:
    """The script tmux runs on the PC. Paths come from its own location."""
    if kind == "shell":
        invoke = 'zsh "$RUN/task.sh"'
    else:
        model_flag = f" --model {shlex.quote(model)}" if model else ""
        invoke = f'claude -p --dangerously-skip-permissions{model_flag} < "$RUN/prompt.txt"'
    return f"""#!/bin/zsh
RUN=${{0:A:h}}
mkdir -p "$RUN/out"
export ONPC_RUN="$RUN" ONPC_OUT="$RUN/out"
if [[ -d "$RUN/work" ]]; then
  git -C "$RUN/work" init -q
  git -C "$RUN/work" add -A
  git -C "$RUN/work" -c user.name=on-pc -c user.email=on-pc@local commit -qm baseline --allow-empty
  cd "$RUN/work"
else
  cd "$RUN/out"
fi
{invoke} > "$RUN/log.txt" 2>&1 < /dev/null
code=$?
if [[ -d "$RUN/work/.git" ]]; then
  git -C "$RUN/work" add -A
  git -C "$RUN/work" diff --cached --binary HEAD > "$RUN/changes.patch"
fi
print -r -- $code > "$RUN/exit.tmp"
mv "$RUN/exit.tmp" "$RUN/exit"
"""


def upload(stage: Path, run_id: str, repo: Path | None, files: list[str]) -> None:
    rdir = remote_dir(run_id)
    res = run(ssh_argv(f"mkdir -p {rdir}/work" if repo else f"mkdir -p {rdir}"))
    if res.returncode != 0:
        raise SetupError(f"mkdir on {host()} failed: {res.stderr.strip()}")
    pipe_tar(["tar", "-C", str(stage), "-cf", "-", "."], f"tar -C {rdir} -xf -")
    if repo:
        listing = "\0".join(files) + "\0"
        pipe_tar(["tar", "-C", str(repo), "--null", "-T", "-", "-cf", "-"],
                 f"tar -C {rdir}/work -xf -", stdin=listing)


def tar_env() -> dict[str, str]:
    """macOS bsdtar adds AppleDouble ._* files for extended attributes unless told not to."""
    return {**os.environ, "COPYFILE_DISABLE": "1"}


def pipe_tar(local: list[str], remote_cmd: str, stdin: str | None = None) -> None:
    src = subprocess.Popen(local, stdin=subprocess.PIPE if stdin is not None else None,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=tar_env())
    dst = subprocess.Popen(ssh_argv(remote_cmd), stdin=src.stdout,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert src.stdout is not None
    src.stdout.close()
    if stdin is not None:
        assert src.stdin is not None
        src.stdin.write(stdin.encode())
        src.stdin.close()
    _, dst_err = dst.communicate()
    src.wait()
    if src.returncode or dst.returncode:
        err = (src.stderr.read().decode() if src.stderr else "") + dst_err.decode()
        raise SetupError(f"copy to {host()} failed: {err.strip()}")


def meta_path(run_id: str) -> Path:
    return LOCAL_ROOT / f"{run_id}.json"


def load_meta(run_id: str) -> dict:
    path = meta_path(run_id)
    if not path.exists():
        raise SetupError(f"unknown run id {run_id} (no {path})")
    return json.loads(path.read_text())


def cmd_start(args: argparse.Namespace) -> int:
    task = " ".join(args.task).strip()
    if not task:
        raise SetupError("no task given after --")
    repo = Path(args.sync).resolve() if args.sync else None
    files = sync_files(repo) if repo else []
    probe()
    run_id = new_run_id()
    dest = Path(args.dest).resolve() if args.dest else default_dest(run_id)
    with tempfile.TemporaryDirectory() as tmp:
        stage = Path(tmp)
        (stage / "run.sh").write_text(run_script(args.kind, args.model))
        if args.kind == "shell":
            (stage / "task.sh").write_text(task + "\n")
        else:
            (stage / "prompt.txt").write_text(build_prompt(task))
        upload(stage, run_id, repo, files)
    rdir = remote_dir(run_id)
    tmux = f"tmux new-session -d -s onpc-{run_id} {shlex.quote(f'zsh -l $HOME/{rdir}/run.sh')}"
    res = run(ssh_argv(tmux))
    if res.returncode != 0:
        raise SetupError(f"tmux start failed: {res.stderr.strip()}")
    sha = run(ssh_argv("git -C .terminal rev-parse --short HEAD")).stdout.strip() or "?"
    LOCAL_ROOT.mkdir(parents=True, exist_ok=True)
    meta = {"id": run_id, "host": host(), "kind": args.kind, "task": task,
            "model": args.model, "repo": str(repo) if repo else None,
            "files": len(files), "dest": str(dest), "started": time.time()}
    meta_path(run_id).write_text(json.dumps(meta, indent=2) + "\n")
    print(f"run {run_id} started on {host()} (tmux onpc-{run_id}, dir ~/{rdir})")
    print(f"kind={args.kind} model={args.model or '-'} synced_files={len(files)} pc_terminal_sha={sha}")
    print(f"results go to {dest}")
    return 0


def state(run_id: str) -> tuple[str, int | None]:
    rdir = remote_dir(run_id)
    cmd = (f"if [ -f {rdir}/exit ]; then cat {rdir}/exit; "
           f"elif tmux has-session -t onpc-{run_id} 2>/dev/null; then echo running; "
           f"elif [ -d {rdir} ]; then echo died; else echo missing; fi")
    res = run(ssh_argv(cmd))
    if res.returncode != 0:
        raise SetupError(f"{host()} unreachable: {res.stderr.strip()}")
    out = res.stdout.strip()
    if out.lstrip("-").isdigit():
        return "done", int(out)
    return out, None


def cmd_status(args: argparse.Namespace) -> int:
    st, code = state(args.id)
    print(f"{args.id}: {st}" + (f" (exit {code})" if code is not None else ""))
    return 0


def fetch(run_id: str, dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    rdir = remote_dir(run_id)
    src = subprocess.Popen(ssh_argv(f"tar -C {rdir} --exclude=./work -cf - ."),
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    dst = subprocess.Popen(["tar", "-C", str(dest), "-xf", "-"], stdin=src.stdout,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert src.stdout is not None
    src.stdout.close()
    _, dst_err = dst.communicate()
    src.wait()
    if src.returncode or dst.returncode:
        err = (src.stderr.read().decode() if src.stderr else "") + dst_err.decode()
        raise SetupError(f"fetch from {host()} failed: {err.strip()}")


def summary(meta: dict, st: str, code: int | None) -> str:
    dest = Path(meta["dest"])
    lines = [f"run {meta['id']} ({meta['kind']}): {st}" + (f", exit {code}" if code is not None else "")]
    lines.append(f"results: {dest}")
    log = dest / "log.txt"
    if log.exists():
        lines.append(f"log: {log}")
    outs = sorted(p for p in (dest / "out").rglob("*") if p.is_file()) if (dest / "out").exists() else []
    if outs:
        shown = [str(p.relative_to(dest / "out")) for p in outs[:OUT_LISTED]]
        more = f" (+{len(outs) - OUT_LISTED} more)" if len(outs) > OUT_LISTED else ""
        lines.append(f"out/: {', '.join(shown)}{more}")
    patch = dest / "changes.patch"
    if patch.exists() and patch.stat().st_size:
        lines.append(f"patch: {patch}")
        if meta.get("repo"):
            lines.append(f"check: git -C {meta['repo']} apply --check {patch}")
    elif meta.get("repo"):
        lines.append("patch: none (no changes)")
    if log.exists():
        # The task's own output: the last lines on success, more of them on failure.
        keep = TAIL_LINES if code != 0 else TAIL_LINES_OK
        tail = log.read_text(errors="replace").splitlines()[-keep:]
        lines.append(f"--- last {len(tail)} log lines ---")
        lines.extend(tail)
    return "\n".join(lines)


def cmd_fetch(args: argparse.Namespace) -> int:
    meta = load_meta(args.id)
    st, code = state(args.id)
    fetch(args.id, Path(meta["dest"]))
    print(summary(meta, st, code))
    return 0


def cmd_wait(args: argparse.Namespace) -> int:
    meta = load_meta(args.id)
    while True:
        st, code = state(args.id)
        if st != "running":
            break
        time.sleep(args.poll)
    if st == "missing":
        raise SetupError(f"run dir for {args.id} not found on {host()}")
    fetch(args.id, Path(meta["dest"]))
    print(summary(meta, st, code))
    return 0 if code == 0 else 1


def cmd_list(_: argparse.Namespace) -> int:
    cmd = (f"cd {REMOTE_ROOT} 2>/dev/null || exit 0; for d in */; do d=${{d%/}}; "
           f"if [ -f $d/exit ]; then echo \"$d done exit $(cat $d/exit)\"; "
           f"elif tmux has-session -t onpc-$d 2>/dev/null; then echo \"$d running\"; "
           f"else echo \"$d died\"; fi; done")
    res = run(ssh_argv(cmd))
    if res.returncode != 0:
        raise SetupError(f"{host()} unreachable: {res.stderr.strip()}")
    print(res.stdout.strip() or "no runs")
    return 0


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("start")
    s.add_argument("--kind", choices=["shell", "claude"], required=True)
    s.add_argument("--sync", metavar="REPO")
    s.add_argument("--model")
    s.add_argument("--dest")
    s.add_argument("task", nargs=argparse.REMAINDER)
    s.set_defaults(fn=cmd_start)
    for name, fn in (("status", cmd_status), ("fetch", cmd_fetch)):
        c = sub.add_parser(name)
        c.add_argument("id")
        c.set_defaults(fn=fn)
    w = sub.add_parser("wait")
    w.add_argument("id")
    w.add_argument("--poll", type=float, default=15)
    w.set_defaults(fn=cmd_wait)
    sub.add_parser("list").set_defaults(fn=cmd_list)
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    if getattr(args, "task", None) and args.task[0] == "--":
        args.task = args.task[1:]
    try:
        return args.fn(args)
    except SetupError as exc:
        print(f"on_pc: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
