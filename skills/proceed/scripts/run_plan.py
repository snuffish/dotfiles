#!/usr/bin/env python3
"""Autonomous phase runner: one `/proceed` phase per `claude -p`, then gates, verifier, commit and handoff update.

Usage: run-plan.sh <plan.md> [--handoff H.md] [--base REF] [--resume] [--max-phases N] [--gates SCRIPT] [--dry-run]

Per phase: snapshot the global rule paths, run `claude -p "/proceed <handoff> --runner phase <N> …"`, then the gate
stages (format, tests, budget, drift) against the PR target branch, a read-only verifier, `git commit` (never push)
and a handoff update (Run-Status CONTINUE | BLOCKED | DONE, Next-Phase, Open caveats). A failed gate or verifier
finding gets at most 2 fix runs per phase, then the run stops BLOCKED with the failing output. A global leak (a
changed rule file, a claude-mem write in the phase transcript) stops it at once. At the end a retro is written.

Exit codes: 0 DONE, 1 BLOCKED, 2 setup or usage error, 3 --max-phases reached with phases remaining.
"""
import argparse
import datetime
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import uuid
from pathlib import Path

STAGES = ["format", "tests", "budget", "drift"]
SKIPPED = 3  # a gate stage's exit code for "not applicable here"; its stdout line becomes a caveat
MAX_FIXES = 2
MEMORY_TOOLS = ["mcp__plugin_claude-mem_mcp-search__save_memory", "mcp__plugin_claude-mem_mcp-search__work_state_write",
                "mcp__plugin_claude-mem_mcp-search__observation_add"]
CONVENTIONAL = re.compile(r"^(feat|fix|chore|docs|refactor|test|perf|build|ci|style|revert)(\([^)]+\))?!?:\s+\S", re.I)
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*$", re.M)
PHASE_TITLE = re.compile(r"^Phase\s+(\d+[a-z]?)\b[\s:.—–-]*(.*)$", re.I)
VERIFIER_TOOLS = "Read,Grep,Glob,Bash(git diff:*),Bash(git status:*),Bash(git log:*),Bash(git show:*)"
HOME = Path.home()
# Paths a phase must never change: a rule written here outlives the run and applies to every project.
DEFAULT_GLOBAL = [HOME / ".claude" / n for n in ("CLAUDE.md", "settings.json", "skills", "agents", "commands", "rules", "hooks")] + [
    HOME / ".claude-memory", HOME / ".claude-mem" / "MY-RULES.md", HOME / ".terminal" / "skills",
    HOME / ".terminal" / "claude", HOME / ".agents",
]
SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv"}
# Machine-written stores under the watched paths: background sync rewrites them during any session, so a change there
# says nothing about the phase (claude-mem device sync, claude.ai skill sync; first real run, 30040, 2026-11-11).
DEFAULT_SKIP_TREES = [HOME / ".claude-memory" / "claude-mem", HOME / ".claude" / "skills" / "synced"]


class Blocked(Exception):
    """The run cannot continue without a person; the message becomes the handoff's Blocked section."""


def now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sh(cmd, cwd=None, timeout=3600, env=None, stdin=None):
    """(returncode, combined output). A timeout is 124, a missing tool 127."""
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout, env=env, input=stdin)
        return p.returncode, (p.stdout or "") + (p.stderr or "")
    except subprocess.TimeoutExpired as e:
        return 124, f"timed out after {timeout}s\n{(e.stdout or b'').decode(errors='replace') if isinstance(e.stdout, bytes) else (e.stdout or '')}"
    except FileNotFoundError:
        return 127, f"{cmd[0]} not found on PATH"


def tail(text, lines=80):
    rows = text.rstrip().splitlines()
    return "\n".join(rows[-lines:])


# ── Plan and handoff text ────────────────────────────────────────────────────────────────────────

def parse_phases(plan):
    """[{label, title, body}] in plan order: each `## Phase 3: title` heading through the next heading of the same
    or a shallower level."""
    heads = [(m.start(), len(m.group(1)), m.group(2)) for m in HEADING.finditer(plan)]
    phases = []
    for i, (start, level, title) in enumerate(heads):
        m = PHASE_TITLE.match(title)
        if not m:
            continue
        end = next((s for s, lv, _ in heads[i + 1:] if lv <= level), len(plan))
        phases.append({"label": m.group(1).lower(), "title": m.group(2).strip() or title, "body": plan[start:end].strip()})
    return phases


def get_field(text, key):
    m = re.search(rf"^\*\*{re.escape(key)}:\*\*[ \t]*(.*)$", text, re.M)
    return m.group(1).strip() if m else None


def head_end(text):
    m = re.search(r"^(---|## )", text, re.M)
    return m.start() if m else len(text)


def set_field(text, key, value):
    line = f"**{key}:** {value}"
    pat = re.compile(rf"^\*\*{re.escape(key)}:\*\*.*$", re.M)
    if pat.search(text):
        return pat.sub(lambda _: line, text, count=1)
    end = head_end(text)
    fields = list(re.finditer(r"^\*\*[\w-]+:\*\*.*\n?", text[:end], re.M))
    if fields:
        pos = fields[-1].end()
        return text[:pos] + ("" if text[:pos].endswith("\n") else "\n") + line + "\n" + text[pos:]
    title = re.search(r"^# .*\n", text, re.M)
    pos = title.end() if title else 0
    return text[:pos] + "\n" + line + "\n" + text[pos:]


def section_span(text, heading):
    m = re.search(rf"^## {re.escape(heading)}[ \t]*\n", text, re.M)
    if not m:
        return None
    nxt = re.search(r"^(## |---)", text[m.end():], re.M)
    return m.start(), m.end() + (nxt.start() if nxt else len(text) - m.end())


def get_caveats(text):
    span = section_span(text, "Open caveats")
    if not span:
        return []
    return [ln[2:].strip() for ln in text[span[0]:span[1]].splitlines() if ln.startswith("- ")]


def set_section(text, heading, body_lines):
    """Replace the `## heading` section, drop it when `body_lines` is empty, else insert it before the last `---`."""
    span = section_span(text, heading)
    block = f"## {heading}\n" + "\n".join(body_lines) + "\n\n" if body_lines else ""
    if span:
        return text[:span[0]] + block + text[span[1]:]
    if not block:
        return text
    rule = text.rfind("\n---\n")
    pos = rule + 1 if rule != -1 else len(text)
    return text[:pos] + block + text[pos:]


def set_caveats(text, caveats):
    seen, unique = set(), []
    for c in caveats:
        if c not in seen:
            seen.add(c)
            unique.append(c)
    return set_section(text, "Open caveats", [f"- {c}" for c in unique] or ["- none"])


def first_backticked(value):
    m = re.search(r"`([^`]+)`", value or "")
    return m.group(1) if m else None


# ── Global-path snapshot and transcript scan ─────────────────────────────────────────────────────

def global_paths():
    override = os.environ.get("RUN_PLAN_GLOBAL_PATHS")
    return [Path(p) for p in override.split(os.pathsep) if p] if override else DEFAULT_GLOBAL


def skip_trees():
    override = os.environ.get("RUN_PLAN_GLOBAL_SKIP")
    return {str(Path(p)) for p in override.split(os.pathsep) if p} if override is not None else {str(p) for p in DEFAULT_SKIP_TREES}


def snapshot():
    """{path: sha256} of every file under the global rule paths, the machine-written stores left out."""
    snap, skipped = {}, skip_trees()
    for root in global_paths():
        files = [root] if root.is_file() else []
        if root.is_dir():
            for dirpath, dirs, names in os.walk(root):
                dirs[:] = [d for d in dirs if d not in SKIP_DIRS and os.path.join(dirpath, d) not in skipped]
                files += [Path(dirpath) / n for n in names]
        for f in files:
            try:
                snap[str(f)] = hashlib.sha256(f.read_bytes()).hexdigest()
            except OSError:
                continue
    return snap


def changed_paths(before, after):
    return sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))


def transcript_tool_uses(session_id):
    """[(tool name, input dict)] a session called, read from its transcript; None when no transcript is found."""
    base = os.environ.get("RUN_PLAN_TRANSCRIPTS", str(HOME / ".claude" / "projects"))
    paths = glob.glob(os.path.join(base, "*", f"{session_id}.jsonl"))
    if not paths:
        return None
    uses = []
    for path in paths:
        for line in Path(path).read_text(errors="replace").splitlines():
            try:
                content = (json.loads(line).get("message") or {}).get("content")
            except (ValueError, AttributeError):
                continue
            for item in content if isinstance(content, list) else []:
                if isinstance(item, dict) and item.get("type") == "tool_use":
                    uses.append((item.get("name", ""), item.get("input") or {}))
    return uses


def transcript_memory_writes(session_id):
    """Names of claude-mem write tools a session called, read from its transcript."""
    return [name.rsplit("__", 1)[-1] for name, _ in transcript_tool_uses(session_id) or [] if name in MEMORY_TOOLS]


def written_by(path, uses):
    """True when a tool call in `uses` wrote `path`: a file tool naming it, or a Bash command naming it or its folder
    (in full or ~ form). Folder-level on purpose: a phase command that names a global folder is suspect anyway."""
    home, real = str(HOME), os.path.realpath(path)  # realpath: macOS /var is /private/var, and skills may be symlinks
    names = {path, real, os.path.dirname(path), os.path.dirname(real)}
    names |= {n.replace(home, "~", 1) for n in names if n.startswith(home)}
    for name, args in uses:
        target = args.get("file_path") or args.get("notebook_path")
        if target and os.path.realpath(os.path.expanduser(target)) == real:
            return True
        if name == "Bash" and any(n in (args.get("command") or "") for n in names):
            return True
    return False


# ── Runner ───────────────────────────────────────────────────────────────────────────────────────

class Runner:
    def __init__(self, args):
        self.a = args
        self.plan = Path(args.plan).resolve()
        self.stem = re.sub(r"^.*implementation_plan-", "", self.plan.stem)
        self.artifacts = Path(os.environ.get("RUN_PLAN_ARTIFACT_DIR") or self.plan.parent)
        self.state = self.artifacts / f"run-plan-{self.stem}"
        self.claude = os.environ.get("RUN_PLAN_CLAUDE", "claude")
        self.spent = 0.0
        self.sessions = []
        self.phases = parse_phases(self.plan.read_text())
        self.handoff = Path(args.handoff).resolve() if args.handoff else self.artifacts / f"runner-handoff-{self.stem}.md"
        self.wt = None
        here = Path(__file__).resolve().parent
        self.gates = None if args.gates == "none" else Path(args.gates or here / "gates-priis.sh")

    # logging
    def log(self, event, **kv):
        with (self.state / "log.jsonl").open("a") as f:
            f.write(json.dumps({"ts": now(), "event": event, **kv}) + "\n")

    def read(self):
        return self.handoff.read_text()

    def write(self, text):
        tmp = self.handoff.with_suffix(".tmp")
        tmp.write_text(text)
        os.replace(tmp, self.handoff)

    def git(self, *a, timeout=300):
        return sh(["git", *a], cwd=self.wt, timeout=timeout)

    # setup
    def ensure_handoff(self):
        if self.handoff.exists():
            return
        first = self.phases[0]["label"]
        base = f"**Base:** `{self.a.base}`\n" if self.a.base else ""
        self.write(f"<!-- artifact-owner: run-plan · session {uuid.uuid4()} · created {now()} -->\n\n"
                   f"# Handoff: {self.stem}\n\n**Status:** Awaiting /proceed\n**Run-Status:** CONTINUE\n"
                   f"**Next-Phase:** {first}\n{base}**Plan:** `{self.plan}`\n\n---\n")

    def ensure_worktree(self):
        text = self.read()
        wt = get_field(text, "Worktree")
        wt = (first_backticked(wt) or wt or "").strip()
        if wt and wt not in ("main", "-", "—") and Path(wt).is_dir():
            self.wt = Path(wt)
            return
        base = self.a.base or first_backticked(get_field(text, "Base"))
        if not base:
            raise SystemExit("setup: the handoff names no worktree and no Base: line, and --base is missing")
        rc, root = sh(["git", "rev-parse", "--show-toplevel"])
        if rc:
            raise SystemExit("setup: run the runner inside the repository")
        branch = first_backticked(get_field(text, "Branch")) or f"runner/{self.stem}"
        path = Path(root.strip()) / ".claude" / "worktrees" / re.sub(r"[^\w.-]+", "-", branch)
        ref = self.base_ref(base, Path(root.strip()))
        exists = sh(["git", "rev-parse", "--verify", "--quiet", f"refs/heads/{branch}"], cwd=root.strip())[0] == 0
        cmd = ["git", "worktree", "add", str(path), branch] if exists else ["git", "worktree", "add", "--no-track", "-b", branch, str(path), ref]
        rc, out = sh(cmd, cwd=root.strip())
        if rc:
            raise SystemExit(f"setup: git worktree add failed (a branch checked out elsewhere: set Worktree: to it)\n{out}")
        self.wt = path
        self.log("worktree", path=str(path), branch=branch, base=ref)
        text = set_field(set_field(text, "Worktree", f"`{path}`"), "Branch", f"`{branch}`")
        self.write(text)

    # base branch
    def base_ref(self, name, cwd):
        name = re.sub(r"^refs/heads/", "", name.strip())
        sh(["git", "fetch", "--quiet", "origin", name], cwd=cwd, timeout=120)
        ok = sh(["git", "rev-parse", "--verify", "--quiet", f"origin/{name}"], cwd=cwd)[0] == 0
        return f"origin/{name}" if ok and not name.startswith("origin/") else name

    def pr_target(self, branch):
        custom = os.environ.get("RUN_PLAN_PR_BASE_CMD")
        cmds = [custom.format(branch=branch).split()] if custom else [
            ["az", "repos", "pr", "list", "--source-branch", branch, "--status", "active", "--query", "[0].targetRefName", "-o", "tsv"],
            ["gh", "pr", "view", branch, "--json", "baseRefName", "-q", ".baseRefName"],
        ]
        for cmd in cmds:
            rc, out = sh(cmd, cwd=self.wt, timeout=60)
            value = out.strip().splitlines()[-1].strip() if out.strip() else ""
            if rc == 0 and value and value.lower() not in ("none", "null"):
                return re.sub(r"^refs/heads/", "", value)
        return None

    def resolve_base(self):
        branch = self.git("branch", "--show-current")[1].strip()
        target = self.pr_target(branch)
        source = "pr"
        if not target:
            target = self.a.base or first_backticked(get_field(self.read(), "Base"))
            source = "handoff"
        if not target:
            raise Blocked("No open PR for the branch and no `Base:` line in the handoff, so there is no diff base. "
                          "A stacked branch must not be diffed against origin/main; add `**Base:** `<parent-branch>`` and re-run with --resume.")
        ref = self.base_ref(target, self.wt)
        self.log("base", branch=branch, base=ref, source=source)
        return ref

    # claude invocations
    def invoke(self, kind, label, prompt, usd, timeout, readonly=False, tools_off=False):
        if self.spent >= self.a.run_usd:
            raise Blocked(f"Run budget of ${self.a.run_usd:.2f} reached (spent ${self.spent:.2f}).")
        cmd = [self.claude, "-p", "--output-format", "json", "--max-budget-usd", str(usd), "--permission-prompts", "none",
               "--disallowedTools", ",".join(MEMORY_TOOLS)]
        if readonly:
            cmd += ["--permission-mode", "manual", "--tools", "Read,Grep,Glob,Bash", "--allowedTools", VERIFIER_TOOLS]
        elif tools_off:
            cmd += ["--permission-mode", "manual", "--tools", ""]
        else:
            cmd += ["--permission-mode", "acceptEdits"]
        env = {**os.environ, "RUN_PLAN_PHASE": label, "RUN_PLAN_STATE": str(self.state)}
        rc, out = sh(cmd, cwd=self.wt, timeout=timeout, env=env, stdin=prompt)
        data = {}
        try:
            data = json.loads(out)
            if isinstance(data, list):
                data = next((d for d in reversed(data) if d.get("type") == "result"), {})
        except ValueError:
            pass
        cost = float(data.get("total_cost_usd") or 0)
        self.spent += cost
        sid = data.get("session_id")
        if sid and not readonly:
            self.sessions.append(sid)
        self.log("invoke", label=label, kind=kind, rc=rc, cost=cost, session=sid)
        failed = rc != 0 or data.get("is_error")
        return {"ok": not failed, "text": data.get("result") if data else out, "raw": out, "cost": cost}

    # per-phase checks
    def leaks(self, snap, caveats):
        """Global writes by this phase's own sessions. A changed path no phase or fix transcript wrote came from
        another session and becomes a caveat; with a transcript missing nothing can be ruled out, so every change counts."""
        uses = [transcript_tool_uses(sid) for sid in self.sessions]
        known = None if any(u is None for u in uses) else [use for u in uses for use in u]
        found = []
        for p in changed_paths(snap, snapshot()):
            if known is None or written_by(p, known):
                found.append(f"changed: {p}")
            else:
                caveats.add(f"global path changed outside the phase (another session?): {p}")
        for sid in self.sessions:
            found += [f"claude-mem write in the phase transcript: {w}" for w in transcript_memory_writes(sid)]
        return found

    def run_stage(self, stage, base, label):
        if not self.gates:
            return SKIPPED, f"{stage}: gates disabled (--gates none)"
        env = {**os.environ, "RUN_PLAN_PHASE": label}
        rc, out = sh([str(self.gates), stage, base], cwd=self.wt, env=env)
        return rc, out

    def phase_json(self, label):
        path = self.state / f"phase-{label}.json"
        if not path.exists():
            return None, f"{path} was not written; the phase must write it (commit_message, caveats)."
        try:
            data = json.loads(path.read_text())
        except ValueError as e:
            return None, f"{path} is not valid JSON: {e}"
        if not CONVENTIONAL.match(data.get("commit_message", "")):
            return None, f"commit_message in {path} is not a conventional commit subject (type(scope): subject): {data.get('commit_message')!r}"
        return data, None

    def verify(self, ph, label):
        self.git("add", "-A")
        diff = self.git("diff", "--cached", "HEAD")[1]
        files = self.git("diff", "--cached", "--name-status", "HEAD")[1]
        prompt = (
            "You verify one phase of an implementation plan. Read-only: never edit, commit or stage.\n"
            "Compare the staged diff with the plan section. Report ONLY these:\n"
            "- missed_files: files or steps the plan section requires that the diff lacks\n"
            "- scope_creep: changes the plan section does not ask for (needed_for_phase true only when the phase cannot work without it)\n"
            "- global_leaks: changes to agent rules or memory outside the repo, or rule/instruction text meant for every project\n"
            'Answer with one JSON object and nothing else: {"missed_files":[{"file":"","why":""}],'
            '"scope_creep":[{"file":"","why":"","needed_for_phase":false}],"global_leaks":[{"path":"","why":""}],"summary":""}\n\n'
            f"## Plan section\n{ph['body']}\n\n## Files (name-status)\n{files}\n\n## Diff\n{diff[:300000]}\n")
        for attempt in range(2):
            res = self.invoke("verifier", label, prompt, self.a.verify_usd, self.a.verify_timeout, readonly=True)
            m = re.search(r"\{.*\}", res["text"] or "", re.S)
            try:
                return json.loads(m.group(0))
            except (AttributeError, ValueError):
                continue
        raise Blocked("The verifier did not return parseable JSON twice.\n" + tail(res["raw"], 20))

    def check(self, ph, base, caveats):
        """None when the phase is ready to commit, else (kind, text) for a fix run."""
        label = ph["label"]
        if not self.git("status", "--porcelain")[1].strip():
            raise Blocked("The phase produced no changes.")
        data, problem = self.phase_json(label)
        if problem:
            return "contract", problem
        caveats.update(data.get("caveats") or [])
        for stage in STAGES:
            rc, out = self.run_stage(stage, base, label)
            self.log("gate", label=label, stage=stage, rc=rc)
            if rc == SKIPPED:
                caveats.add(f"gate {stage} skipped: {out.strip().splitlines()[-1] if out.strip() else 'not applicable'}")
            elif rc != 0:
                return f"gate:{stage}", tail(out, 120)
        verdict = self.verify(ph, label)
        self.log("verifier", label=label, verdict=verdict)
        if verdict.get("global_leaks"):
            raise Blocked("The verifier found a rule change leaking into global memory:\n" + json.dumps(verdict["global_leaks"], indent=2))
        creep = [c for c in verdict.get("scope_creep", []) if not c.get("needed_for_phase")]
        for c in verdict.get("scope_creep", []):
            if c.get("needed_for_phase"):
                caveats.add(f"scope beyond the plan, kept as needed: {c.get('file')}: {c.get('why')}")
        if verdict.get("missed_files") or creep:
            return "verifier", json.dumps({"missed_files": verdict.get("missed_files", []), "scope_creep": creep}, indent=2)
        return None

    def run_phase(self, ph, caveats):
        label = ph["label"]
        os.environ["RUN_PLAN_PHASE"] = label
        base = self.resolve_base()
        snap = snapshot()
        self.sessions = []
        res = self.invoke("phase", label, f"/proceed {self.handoff} --runner phase {label} state-dir {self.state}",
                          self.a.phase_usd, self.a.phase_timeout)
        if not res["ok"]:
            raise Blocked("The phase invocation failed:\n" + tail(res["raw"], 40))
        retries = 0
        while True:
            leaked = self.leaks(snap, caveats)
            if leaked:
                raise Blocked("Global memory or rules changed during the phase (only you decide that):\n" + "\n".join(leaked))
            problem = self.check(ph, base, caveats)
            if not problem:
                data, _ = self.phase_json(label)
                msg = self.state / f"commit-{label}.txt"
                msg.write_text(data["commit_message"].rstrip() + "\n")
                rc, out = self.git("-c", "commit.cleanup=verbatim", "commit", "-q", "-F", str(msg))
                if rc == 0:
                    return retries, self.git("rev-parse", "--short", "HEAD")[1].strip(), data["commit_message"]
                problem = ("commit", tail(out, 60))
            kind, text = problem
            self.log("friction", label=label, kind=kind, text=text[:600])
            if retries >= MAX_FIXES:
                raise Blocked(f"{kind} still failing after {MAX_FIXES} fix runs:\n{text}")
            retries += 1
            fix = (f"FIX run {retries} of {MAX_FIXES} for phase {label} of {self.plan}.\nThe check `{kind}` failed. Fix only what the output "
                   f"names, inside the phase's plan section. Do not commit, do not widen scope, do not write any memory or rule file outside "
                   f"this repo. If the phase json under {self.state} is missing or wrong, rewrite it.\n\nOutput:\n{text}\n")
            res = self.invoke("fix", label, fix, self.a.fix_usd, self.a.fix_timeout)
            if not res["ok"]:
                raise Blocked("A fix invocation failed:\n" + tail(res["raw"], 40))

    # main loop
    def main(self):
        if not self.phases:
            raise SystemExit(f"setup: no `## Phase N` headings in {self.plan}")
        self.ensure_handoff()
        text = self.read()
        status = (get_field(text, "Run-Status") or "CONTINUE").upper()
        if status == "BLOCKED" and not self.a.resume:
            print(f"BLOCKED: see the Blocked section in {self.handoff}; fix it, then re-run with --resume.", file=sys.stderr)
            return 1
        if status == "DONE":
            print("DONE already.")
            return 0
        # A hand-written handoff without run fields may describe finished phases; guessing phase 1 would redo them.
        nxt = re.match(r"\d+[a-z]?", (get_field(text, "Next-Phase") or "").lower())
        if not nxt:
            raise SystemExit(f"setup: {self.handoff} has no `**Next-Phase:** <label>` line; set it to the first unfinished "
                             f"phase of {[p['label'] for p in self.phases]}")
        if self.a.dry_run:
            print(f"plan: {self.plan}\nhandoff: {self.handoff}\nphases: {[p['label'] for p in self.phases]}\nnext: {nxt.group(0)}")
            return 0
        self.state.mkdir(parents=True, exist_ok=True)
        self.ensure_worktree()
        # A commit stages the whole tree, so work from before the run would land in the wrong phase's commit.
        dirty = self.git("status", "--porcelain")[1].strip()
        if dirty and not self.a.resume:
            raise SystemExit(f"setup: {self.wt} has uncommitted changes from before the run; commit them first, or re-run "
                             f"with --resume to let phase {nxt.group(0)} take them over:\n{tail(dirty, 20)}")
        done = 0
        while True:
            text = self.read()
            label = re.match(r"\d+[a-z]?", (get_field(text, "Next-Phase") or "").lower()).group(0)
            idx = next((i for i, p in enumerate(self.phases) if p["label"] == label), None)
            if idx is None:
                raise SystemExit(f"setup: Next-Phase {label!r} is not a phase of the plan")
            if done >= self.a.max_phases:
                self.finish("CONTINUE")
                return 3
            ph = self.phases[idx]
            caveats = set(get_caveats(text)) - {"none"}
            self.log("phase_start", label=label, title=ph["title"])
            try:
                retries, sha, subject = self.run_phase(ph, caveats)
            except Blocked as b:
                self.block(label, str(b), caveats)
                self.finish("BLOCKED")
                return 1
            done += 1
            nxt = self.phases[idx + 1]["label"] if idx + 1 < len(self.phases) else None
            text = self.read()
            text = set_field(text, "Run-Status", "CONTINUE" if nxt else "DONE")
            text = set_field(text, "Next-Phase", next(f"{p['label']} — {p['title']}" for p in self.phases if p["label"] == nxt) if nxt else "none")
            text = set_field(text, "Branch", f"`{self.git('branch', '--show-current')[1].strip()}` at `{sha}` ({subject})")
            text = set_section(set_caveats(text, sorted(caveats)), "Blocked", [])
            self.write(text)
            self.log("phase_done", label=label, title=ph["title"], retries=retries, sha=sha, subject=subject, caveats=sorted(caveats))
            stale = sh(["python3", "-I", str(Path(__file__).resolve().parents[2] / "handoff" / "scripts" / "check_shas.py"), str(self.wt), str(self.handoff)])[1]
            if stale.strip():
                print("stale SHAs in the handoff:\n" + stale)
            print(f"phase {label} committed {sha}: {subject}")
            if not nxt:
                self.finish("DONE")
                return 0

    def block(self, label, reason, caveats):
        text = set_field(self.read(), "Run-Status", "BLOCKED")
        text = set_field(text, "Next-Phase", f"{label} — blocked")
        text = set_caveats(text, sorted(caveats))
        text = set_section(text, "Blocked", [f"Phase {label}, {now()}:", "", "```", tail(reason, 120), "```"])
        self.write(text)
        self.log("blocked", label=label, reason=reason[:2000])
        print(f"BLOCKED at phase {label}:\n{tail(reason, 30)}", file=sys.stderr)

    # retro and notification
    def events(self):
        path = self.state / "log.jsonl"
        return [json.loads(ln) for ln in path.read_text().splitlines()] if path.exists() else []

    def retro_table(self, events):
        order = [p["label"] for p in self.phases]
        rows = []
        for label in order:
            mine = [e for e in events if e.get("label") == label]
            if not mine:
                continue
            cost = sum(e.get("cost", 0) for e in mine if e["event"] == "invoke")
            done = next((e for e in reversed(mine) if e["event"] == "phase_done"), None)
            blocked = any(e["event"] == "blocked" for e in mine) and not done
            fixes = sum(1 for e in mine if e["event"] == "invoke" and e.get("kind") == "fix")
            title = next((e.get("title") for e in mine if e["event"] == "phase_start"), "")
            result = f"done `{done['sha']}` {done['subject']}" if done else ("BLOCKED" if blocked else "started")
            rows.append(f"| {label} {title} | {result} | {fixes} | ${cost:.2f} |")
        return "| Phase | Result | Fix runs | Cost |\n|---|---|---|---|\n" + "\n".join(rows)

    def finish(self, status):
        events = self.events()
        table = self.retro_table(events)
        friction = [e for e in events if e["event"] == "friction"]
        blocked = [e for e in events if e["event"] == "blocked"]
        body = f"# Retro: {self.stem}\n\n**Run status:** {status} · **Spent:** ${sum(e.get('cost', 0) for e in events if e['event'] == 'invoke'):.2f}\n\n{table}\n"
        if not self.a.no_retro and (friction or blocked):
            prompt = ("Write the Friction part of a run retro. Group the friction events by cause. For each cause give one line: what happened, "
                      "and a proposed change (a skill, hook, rule or memory file, named) that would remove it. Propose only; apply nothing. "
                      "Max 250 words, markdown, start with '## Friction'.\n\n" + json.dumps(friction + blocked, indent=1)[:60000])
            res = self.invoke("retro", "retro", prompt, self.a.verify_usd, self.a.verify_timeout, tools_off=True)
            body += "\n" + (res["text"] if res["ok"] else "## Friction\nThe retro run failed; see log.jsonl.") + "\n"
        else:
            body += "\n## Friction\nNone logged.\n"
        n, path = 0, self.artifacts / f"runner-retro-{self.stem}.md"
        while path.exists():
            n += 1
            path = self.artifacts / f"runner-retro-{self.stem}-{n}.md"
        path.write_text(body)
        print(f"retro: {path}")
        self.notify(f"run-plan {status}", f"{self.stem}: {status}")

    @staticmethod
    def notify(title, message):
        if shutil.which("osascript"):
            sh(["osascript", "-e", f'display notification "{message}" with title "{title}"'], timeout=10)
        elif shutil.which("notify-send"):
            sh(["notify-send", title, message], timeout=10)
        else:
            sys.stderr.write("\a")


def parse_args(argv):
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("plan")
    p.add_argument("--handoff")
    p.add_argument("--base", help="diff base when there is no PR yet (else the handoff's Base: line)")
    p.add_argument("--resume", action="store_true", help="continue after BLOCKED, with a fresh fix budget")
    p.add_argument("--max-phases", type=int, default=99)
    p.add_argument("--gates", help="gate script (stage, base) or 'none'")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--no-retro", action="store_true", help="skip the model-written friction section")
    p.add_argument("--phase-usd", type=float, default=8)
    p.add_argument("--fix-usd", type=float, default=4)
    p.add_argument("--verify-usd", type=float, default=2)
    p.add_argument("--run-usd", type=float, default=50)
    p.add_argument("--phase-timeout", type=int, default=3600)
    p.add_argument("--fix-timeout", type=int, default=1800)
    p.add_argument("--verify-timeout", type=int, default=900)
    return p.parse_args(argv)


def main(argv):
    args = parse_args(argv)
    if not Path(args.plan).is_file():
        print(f"setup: {args.plan} not found", file=sys.stderr)
        return 2
    try:
        return Runner(args).main()
    except SystemExit as e:
        if isinstance(e.code, str):
            print(e.code, file=sys.stderr)
            return 2
        raise


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
