#!/usr/bin/env python3
"""Collect last-working-day evidence for /standup-recap and print it as JSON.

Sources: git commits, Azure DevOps PRs, review threads, work items and pipeline
runs, GitHub PRs (--all only) and claude-mem session summaries. Each source
degrades to one line in `notes` when its CLI is missing or fails.
"""

import argparse
import concurrent.futures
import datetime as dt
import json
import os
import re
import shutil
import sqlite3
import subprocess
import time
from pathlib import Path

os.environ["TZ"] = "Europe/Stockholm"
time.tzset()

TIMEOUT = 20
LOOKBACK_DAYS = 7
SCAN_DEPTH = 4
THREAD_CAP = 10
VOTES = {"10": "approved", "5": "approved with suggestions", "0": "reset vote", "-5": "waiting for author",
         "-10": "rejected"}
SKIP_DIRS = {"node_modules", ".git", "bin", "obj", "dist", "build", ".venv", "venv", "worktrees"}
DONE_STATES = ("New", "Closed", "Done", "Removed", "Resolved", "To Do", "Proposed")
CLAUDE_MEM_DB = Path.home() / ".claude-mem" / "claude-mem.db"
TRANSCRIPTS = Path.home() / ".claude" / "projects"

NOTES = []
META = {"az_invoke_calls": 0, "thread_calls": 0}


class Skip(Exception):
    pass


def run(cmd, cwd=None):
    if shutil.which(cmd[0]) is None:
        raise Skip(f"{cmd[0]} not installed")
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        raise Skip(f"`{' '.join(cmd[:3])}` timed out after {TIMEOUT}s")
    if p.returncode != 0:
        first = (p.stderr.strip().splitlines() or ["exit " + str(p.returncode)])[0]
        raise Skip(f"`{' '.join(cmd[:3])}` failed: {first[:160]}")
    return p.stdout


def run_json(cmd):
    if cmd[:3] == ["az", "devops", "invoke"]:
        META["az_invoke_calls"] += 1
    return json.loads(run(cmd + ["-o", "json"]) or "null")


def guarded(source, default, fn, *args):
    try:
        return fn(*args)
    except Skip as e:
        NOTES.append(f"{source}: skipped ({e})")
    except Exception as e:  # one broken source must not sink the recap
        NOTES.append(f"{source}: skipped ({type(e).__name__}: {e})")
    return default


def parse_ts(value):
    """ISO timestamp (any offset, 'Z', 7-digit fractions) → local aware datetime."""
    if not value:
        return None
    v = re.sub(r"(\.\d{6})\d+", r"\1", value.replace("Z", "+00:00"))
    d = dt.datetime.fromisoformat(v)
    return (d if d.tzinfo else d.astimezone()).astimezone()


def local_day(value):
    d = parse_ts(value) if isinstance(value, str) else value
    return d.date() if d else None


# ---------------------------------------------------------------- identity


def az_identity():
    me = run(["az", "account", "show", "--query", "user.name", "-o", "tsv"]).strip()
    cfg = run(["az", "devops", "configure", "-l"])
    m = re.search(r"https://dev\.azure\.com/([^/\s]+)|https://([^./\s]+)\.visualstudio\.com", cfg)
    org = (m.group(1) or m.group(2)) if m else None
    if not org:
        raise Skip("no default organization in `az devops configure -l`")
    project = re.search(r"^project\s*=\s*(.+)$", cfg, re.M)
    return me, org, project and project.group(1).strip()


# ---------------------------------------------------------------- git


def discover_repos(root):
    """Every repo under root (depth ≤ SCAN_DEPTH), keyed by its common git dir."""
    if shutil.which("git") is None:
        raise Skip("git not installed")
    repos = {}
    root = Path(root).expanduser()
    for dirpath, dirnames, _ in os.walk(root):
        depth = len(Path(dirpath).relative_to(root).parts)
        if (Path(dirpath) / ".git").exists():
            path = Path(dirpath)
            try:
                common = run(["git", "-C", str(path), "rev-parse", "--path-format=absolute", "--git-common-dir"]).strip()
            except Skip:
                continue
            repo = repos.setdefault(common, {"path": str(path), "name": path.name, "worktrees": []})
            if Path(common).parent == path:
                repo.update(path=str(path), name=path.name)
        dirnames[:] = [] if depth >= SCAN_DEPTH else [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
    for repo in repos.values():
        porcelain = run(["git", "-C", repo["path"], "worktree", "list", "--porcelain"])
        for block in porcelain.strip().split("\n\n"):
            fields = dict(line.split(" ", 1) for line in block.splitlines() if " " in line)
            if "worktree" in fields and Path(fields["worktree"]).exists():
                repo["worktrees"].append(fields["worktree"])
    return list(repos.values())


def classify(repo, org):
    try:
        remotes = run(["git", "-C", repo["path"], "remote", "-v"])
    except Skip:
        remotes = ""
    repo["work"] = bool(org) and org.lower() in remotes.lower()
    email = guarded("git", "", lambda: run(["git", "-C", repo["path"], "config", "user.email"]).strip())
    repo["emails"] = {email} if email else set()
    return repo


def short_branch(ref):
    return re.sub(r"^refs/(heads/|remotes/[^/]+/)?", "", ref or "")


def git_activity(repo, emails, start, end):
    """My non-merge commits whose author date falls in [start, end)."""
    fmt = "%H%x1f%aI%x1f%S%x1f%s"
    cmd = ["git", "-C", repo["path"], "log", "--all", "--no-merges", "--source", f"--format={fmt}",
           f"--since={start - dt.timedelta(days=1)}", f"--until={end + dt.timedelta(days=1)}"]
    cmd += [f"--author={e}" for e in sorted(emails)]
    commits, seen = [], set()
    for line in run(cmd).splitlines():
        sha, date, source, subject = line.split("\x1f", 3)
        day = local_day(date)
        if sha in seen or not start <= day < end:
            continue
        seen.add(sha)
        commits.append({"sha": sha[:8], "day": str(day), "time": parse_ts(date).strftime("%H:%M"),
                        "repo": repo["name"], "branch": short_branch(source), "subject": subject})
    return commits


def git_state(repo, me_emails):
    """Live state per worktree: branch, last commit, unpushed and dirty counts."""
    trees = []
    for wt in repo["worktrees"] or [repo["path"]]:
        branch = run(["git", "-C", wt, "rev-parse", "--abbrev-ref", "HEAD"]).strip()
        if branch == "HEAD":  # detached snapshot
            continue
        last = run(["git", "-C", wt, "log", "-1", "--format=%cI%x1f%ae"]).strip().split("\x1f")
        unpushed = int(run(["git", "-C", wt, "rev-list", "--count", "HEAD", "--not", "--remotes"]).strip() or 0)
        dirty = len(run(["git", "-C", wt, "status", "--porcelain"]).splitlines())
        trees.append({"repo": repo["name"], "path": wt, "branch": branch, "last_commit": last[0],
                      "mine": last[-1] in me_emails, "unpushed": unpushed, "dirty_files": dirty})
    return trees


def wip_branches(repo, me_emails, since):
    """Local branches with my recent tip commit that the default branch does not contain."""
    try:
        default = run(["git", "-C", repo["path"], "symbolic-ref", "--short", "refs/remotes/origin/HEAD"]).strip()
    except Skip:
        default = "origin/main"
    out = run(["git", "-C", repo["path"], "for-each-ref", "refs/heads",
               "--format=%(refname:short)%1f%(committerdate:iso-strict)%1f%(authoremail:trim)"])
    wip = []
    for line in out.splitlines():
        name, date, email = line.split("\x1f")
        if email not in me_emails or local_day(date) < since:
            continue
        ahead = run(["git", "-C", repo["path"], "rev-list", "--count", f"{default}..{name}"]).strip()
        if ahead != "0":
            wip.append({"repo": repo["name"], "branch": name, "ahead": int(ahead), "last_commit": date})
    return wip


# ---------------------------------------------------------------- grouping


def group_key(subject="", branch="", repo=""):
    """Work item id from `#NNNNN:` subject, else `(feature|bugfix)/NNNNN_` branch, else repo:branch chore."""
    m = re.match(r"#(\d+):", subject or "") or re.match(r"(?:feature|bugfix)/(\d+)_", branch or "")
    return f"wi:{m.group(1)}" if m else f"chore:{repo}:{branch}"


def pr_key(pr):
    return group_key(pr["title"], pr["branch"], pr["repo"])


def summary_of(text):
    """First sentence of a description: the paragraph under a `Summary` heading, else the first prose paragraph."""
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text or "") if p.strip()]
    heading = next((i for i, p in enumerate(paragraphs) if re.match(r"#+ .*summary", p, re.I)), None)
    prose = [p for p in paragraphs[heading + 1 if heading is not None else 0:]
             if not p.startswith(("#", "|", "-", "*", ">", "```")) and len(p.split()) > 4]
    if not prose:
        return None
    sentence = re.split(r"(?<=[.!?])\s", re.sub(r"\s+", " ", prose[0]), maxsplit=1)[0]
    return sentence[:200]


def mentioned_ids(text):
    return {int(n) for n in re.findall(r"(?:#|!|PR\s*#?)(\d{4,6})\b", text or "")}


# ---------------------------------------------------------------- Azure DevOps


def az_prs(me):
    rows = run_json(["az", "repos", "pr", "list", "--creator", me, "--status", "all", "--top", "100", "--query",
                     "[].{id:pullRequestId,title:title,desc:description,status:status,draft:isDraft,created:creationDate,"
                     "closed:closedDate,closedBy:closedBy.uniqueName,branch:sourceRefName,repo:repository.name,"
                     "repoId:repository.id,reviewers:reviewers[].{name:displayName,email:uniqueName,vote:vote}}"])
    for pr in rows:
        pr["branch"] = short_branch(pr["branch"])
        pr["mine"] = True
    return rows


def az_review_prs(me):
    rows = run_json(["az", "repos", "pr", "list", "--reviewer", me, "--status", "all", "--top", "100", "--query",
                     f"[?createdBy.uniqueName!='{me}'].{{id:pullRequestId,title:title,desc:description,status:status,"
                     "created:creationDate,closed:closedDate,branch:sourceRefName,repo:repository.name,"
                     "repoId:repository.id,author:createdBy.displayName,"
                     f"vote:reviewers[?uniqueName=='{me}'] | [0].vote}}"])
    for pr in rows:
        pr["branch"] = short_branch(pr["branch"])
        pr["mine"] = False
    return rows


def az_threads(pr, project, me, start, end):
    """My comments and vote updates on one PR inside [start, end); counts against THREAD_CAP."""
    META["thread_calls"] += 1
    data = run_json(["az", "devops", "invoke", "--area", "git", "--resource", "pullRequestThreads",
                     "--route-parameters", f"project={project}", f"repositoryId={pr['repoId']}",
                     f"pullRequestId={pr['id']}", "--api-version", "7.1"])
    comments, votes = 0, []
    for thread in data.get("value", []):
        kind = ((thread.get("properties") or {}).get("CodeReviewThreadType") or {}).get("$value")
        for c in thread.get("comments", []):
            if c.get("author", {}).get("uniqueName", "").lower() != me.lower():
                continue
            if not start <= local_day(c.get("publishedDate")) < end:
                continue
            if kind == "VoteUpdate":
                vote = re.search(r"voted (-?\d+)", c.get("content", ""))
                votes.append(VOTES.get(vote.group(1), c["content"]) if vote else c.get("content", ""))
            elif c.get("commentType") != "system":
                comments += 1
    return {"pr": pr["id"], "comments": comments, "votes": votes}


def az_work_items(me, start, end):
    """Items I own or changed in [start, end), with my System.State transitions."""
    wiql = (f"SELECT [System.Id] FROM workitems WHERE [System.ChangedDate] >= '{start}' "
            f"AND [System.ChangedDate] < '{end}' AND ([System.AssignedTo] = @Me OR [System.ChangedBy] = @Me)")
    ids = [row["id"] for row in run_json(["az", "boards", "query", "--wiql", wiql, "--query", "[].{id:id}"])]
    return parallel(lambda i: az_work_item(i, me, start, end), ids)


def az_work_item(wid, me, start, end):
    item = run_json(["az", "boards", "work-item", "show", "--id", str(wid), "--fields",
                     "System.Title,System.State,System.WorkItemType", "--expand", "none", "--query", "fields"])
    updates = run_json(["az", "devops", "invoke", "--area", "wit", "--resource", "updates",
                        "--route-parameters", f"id={wid}", "--api-version", "7.1"])
    states = []
    for u in updates.get("value", []):
        fields = u.get("fields") or {}
        state = fields.get("System.State")
        changed = (fields.get("System.ChangedDate") or {}).get("newValue")
        if state and changed and (u.get("revisedBy") or {}).get("uniqueName", "").lower() == me.lower():
            day = local_day(changed)
            if start <= day < end:
                states.append({"day": str(day), "from": state.get("oldValue"), "to": state.get("newValue")})
    return {"id": wid, "title": item.get("System.Title"), "type": item.get("System.WorkItemType"),
            "state": item.get("System.State"), "states": states}


def az_open_items():
    """My assigned items in progress; Blocked ones become blockers."""
    states = ", ".join(f"'{s}'" for s in DONE_STATES)
    wiql = f"SELECT [System.Id] FROM workitems WHERE [System.AssignedTo] = @Me AND [System.State] NOT IN ({states})"
    ids = [row["id"] for row in run_json(["az", "boards", "query", "--wiql", wiql, "--query", "[].{id:id}"])]
    return parallel(lambda i: {"id": i, **run_json(["az", "boards", "work-item", "show", "--id", str(i), "--fields",
                                                    "System.Title,System.State,System.WorkItemType",
                                                    "--expand", "none", "--query", "fields"])}, ids)


def az_pipelines(me, start):
    """Latest run per pipeline + branch, among my runs that finished on or after start."""
    runs = run_json(["az", "pipelines", "runs", "list", "--requested-for", me, "--query-order", "FinishTimeDesc",
                     "--top", "100", "--query", "[].{id:id,pipeline:definition.name,branch:sourceBranch,"
                     "result:result,status:status,finished:finishTime}"])
    latest = {}
    for r in runs:
        if r["finished"] and local_day(r["finished"]) < start:
            continue
        latest.setdefault((r["pipeline"], r["branch"]), r)
    for r in latest.values():
        m = re.match(r"refs/pull/(\d+)/merge", r["branch"] or "")
        r["pr"] = int(m.group(1)) if m else None
        r["branch"] = short_branch(r["branch"])
    return list(latest.values())


# ---------------------------------------------------------------- GitHub


def gh_activity(start):
    rows = json.loads(run(["gh", "search", "prs", "--author", "@me", "--updated", f">={start}", "--limit", "50",
                           "--json", "number,title,body,repository,state,createdAt,closedAt,url"]) or "[]")
    return [{"id": r["number"], "title": r["title"], "desc": r["body"], "repo": r["repository"]["nameWithOwner"],
             "status": r["state"], "created": r["createdAt"], "closed": r["closedAt"], "url": r["url"],
             "branch": "", "mine": True, "host": "github"} for r in rows]


# ---------------------------------------------------------------- sessions


def sessions(start, end, projects):
    try:
        return sessions_from_claude_mem(start, end, projects)
    except (sqlite3.Error, FileNotFoundError) as e:
        NOTES.append(f"claude-mem: unreadable ({e}); fell back to transcripts")
        return sessions_from_transcripts(start, end, projects)


def epoch_ms(day):
    return int(dt.datetime.combine(day, dt.time()).astimezone().timestamp() * 1000)


def sessions_from_claude_mem(start, end, projects):
    if not CLAUDE_MEM_DB.exists():
        raise FileNotFoundError(str(CLAUDE_MEM_DB))
    con = sqlite3.connect(f"file:{CLAUDE_MEM_DB}?mode=ro", uri=True)
    rows = con.execute(
        "SELECT memory_session_id, project, request, completed, created_at FROM session_summaries s "
        "WHERE created_at_epoch >= ? AND created_at_epoch < ? AND prompt_number = "
        "(SELECT MAX(prompt_number) FROM session_summaries t WHERE t.memory_session_id = s.memory_session_id) "
        "ORDER BY created_at_epoch", (epoch_ms(start), epoch_ms(end))).fetchall()
    con.close()
    return [{"day": str(local_day(created)), "project": project, "request": (request or "")[:300],
             "completed": (completed or "")[:500], "source": "claude-mem"}
            for _, project, request, completed, created in rows if projects is None or project in projects]


def sessions_from_transcripts(start, end, projects):
    """First human prompt of each top-level transcript touched in [start, end)."""
    out = []
    lo, hi = epoch_ms(start) / 1000, epoch_ms(end) / 1000
    for path in TRANSCRIPTS.glob("*/*.jsonl"):
        if not lo <= path.stat().st_mtime < hi + 86400:
            continue
        for line in path.open(encoding="utf-8", errors="replace"):
            rec = json.loads(line)
            content = (rec.get("message") or {}).get("content")
            kind = (rec.get("origin") or {}).get("kind")
            human = kind == "human" or (kind is None and isinstance(content, str) and not content.startswith("<"))
            if rec.get("type") != "user" or not human or not isinstance(content, str):
                continue
            day = local_day(rec.get("timestamp"))
            project = Path(rec.get("cwd") or "").name
            if day and start <= day < end and (projects is None or project in projects):
                out.append({"day": str(day), "project": project, "request": content[:300], "completed": "",
                            "source": "transcript"})
                break
    return out


# ---------------------------------------------------------------- window, merge, state


def pick_window(today, dates, since):
    if since:
        return {"start": since, "end": today, "picked_by": "--since"}
    prior = sorted(d for d in dates if d and today - dt.timedelta(days=LOOKBACK_DAYS) <= d < today)
    if not prior:
        return {"start": today - dt.timedelta(days=1), "end": today, "picked_by": "no activity in lookback"}
    return {"start": prior[-1], "end": prior[-1] + dt.timedelta(days=1), "picked_by": "latest active day"}


def in_window(value, window):
    day = local_day(value)
    return bool(day) and window["start"] <= day < window["end"]


def merge(window, commits, prs, review_prs, threads, items, pipelines, gh_prs, sess):
    """One entry per work item / PR / chore key across every source."""
    entries = {}

    def entry(key, **seed):
        e = entries.setdefault(key, {"key": key, "kind": key.split(":")[0], "title": None, "repo": None,
                                     "branch": None, "commits": [], "prs": [], "states": [], "pipelines": [],
                                     "comments": 0, "votes": []})
        for k, v in seed.items():
            e[k] = e[k] or v
        return e

    pr_index = {pr["id"]: pr for pr in prs + review_prs}
    merged_prs = set()
    for c in commits:
        m = re.match(r"Merged PR (\d+):", c["subject"])
        if m and int(m.group(1)) in pr_index:
            merged_prs.add(int(m.group(1)))
            continue
        e = entry(group_key(c["subject"], c["branch"], c["repo"]), repo=c["repo"], branch=c["branch"])
        e["commits"].append(re.sub(r"^#\d+:\s*", "", c["subject"]))
    for pr in prs + gh_prs:
        events = [ev for ev, when in (("opened", pr["created"]), (pr["status"].lower(), pr.get("closed")))
                  if when and in_window(when, window)]
        if pr["id"] in merged_prs and "completed" not in events:
            events.append("completed")
        if not events:
            continue
        e = entry(pr_key(pr), repo=pr["repo"], branch=pr["branch"], title=re.sub(r"^#\d+:\s*", "", pr["title"]))
        e["prs"].append({"id": pr["id"], "title": pr["title"], "events": events, "draft": pr.get("draft"),
                         "host": pr.get("host", "azure")})
    for pr in review_prs:
        if pr["id"] in merged_prs:
            e = entry(f"review:{pr['id']}", repo=pr["repo"], branch=pr["branch"], title=pr["title"])
            e.update(author=pr["author"], pr=pr["id"], vote=pr.get("vote"), completed_by_me=True)
    for t in threads:
        if not (t["comments"] or t["votes"]):
            continue
        pr = pr_index[t["pr"]]
        key = pr_key(pr) if pr["mine"] else f"review:{pr['id']}"
        e = entry(key, repo=pr["repo"], branch=pr["branch"], title=pr["title"])
        e["comments"] += t["comments"]
        e["votes"] += t["votes"]
        if not pr["mine"]:
            e.update(author=pr["author"], pr=pr["id"], vote=pr.get("vote"))
    for item in items:
        states = [s for s in item["states"] if in_window(s["day"], window)]
        if states:
            e = entry(f"wi:{item['id']}")
            e["states"] += states
    for item in items:
        if f"wi:{item['id']}" in entries:
            entries[f"wi:{item['id']}"].update(title=item["title"], type=item["type"], state=item["state"])
    for run_ in pipelines:
        if not in_window(run_["finished"], window):
            continue
        pr = pr_index.get(run_["pr"])
        key = pr_key(pr) if pr else group_key("", run_["branch"], "")
        if key in entries:
            entries[key]["pipelines"].append({"pipeline": run_["pipeline"], "result": run_["result"]})
    pr_desc = {}
    for pr in prs + gh_prs:
        pr_desc.setdefault(pr_key(pr), summary_of(pr.get("desc")))
    for e in entries.values():
        e["title"] = e["title"] or (e["commits"][0] if e["commits"] else e["key"])
        ids = {p["id"] for p in e["prs"]} | ({int(e["key"][3:])} if e["kind"] == "wi" else set())
        ids |= {e["pr"]} if e.get("pr") else set()
        candidates = [
            ("pr", summary_of(pr_index[e["pr"]].get("desc")) if e.get("pr") else pr_desc.get(e["key"])),
            ("session", next((s["request"] for s in sess if ids & mentioned_ids(s["request"])), None)),
            ("commit", e["commits"][0] if e["commits"] else None),
        ]
        e["summary_source"], e["summary"] = next(((k, v) for k, v in candidates if v), (None, None))
        e["weight"] = len(e["commits"]) + 3 * len(e["prs"]) + 2 * len(e["states"]) + e["comments"] + 2 * len(e["votes"])
    return sorted(entries.values(), key=lambda e: -e["weight"])


def today_state(prs, open_items, trees, wips, window):
    open_prs = [{"id": pr["id"], "title": pr["title"], "repo": pr["repo"], "draft": pr.get("draft"),
                 "approved_by": [r["name"] for r in pr["reviewers"] if r["vote"] >= 5 and not r.get("self")],
                 "changes_requested_by": [r["name"] for r in pr["reviewers"] if r["vote"] <= -5 and not r.get("self")]}
                for pr in prs if pr["status"] == "active"]
    pr_branches = {pr["branch"] for pr in prs}
    latest = max((t for t in trees if t["mine"]), key=lambda t: parse_ts(t["last_commit"]), default=None)
    return {
        "open_prs": open_prs,
        "wip_branches": [w for w in wips if w["branch"] not in pr_branches and local_day(w["last_commit"]) >= window["start"]],
        "active_items": [i for i in open_items if i.get("System.State") != "Blocked"],
        "last_branch": latest and {"repo": latest["repo"], "branch": latest["branch"]},
        "unpushed": [t for t in trees if t["unpushed"]],
        "dirty": [t for t in trees if t["dirty_files"]],
    }


def blockers(prs, open_items, pipelines):
    active = {pr["id"]: pr for pr in prs if pr["status"] == "active"}
    out = [{"type": "pipeline_failed", "pr": r["pr"], "pipeline": r["pipeline"], "branch": r["branch"]}
           for r in pipelines if r["result"] == "failed" and r["pr"] in active]
    for pr in active.values():
        votes = [r["vote"] for r in pr["reviewers"] if not r.get("self")]
        if not any(v >= 5 or v <= -5 for v in votes) and not pr.get("draft"):
            out.append({"type": "waiting_on_review", "pr": pr["id"], "title": pr["title"]})
    out += [{"type": "item_blocked", "id": i["id"], "title": i.get("System.Title")}
            for i in open_items if i.get("System.State") == "Blocked"]
    return out


def parallel(fn, items):
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        return list(pool.map(fn, items))


# ---------------------------------------------------------------- main


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--since", type=dt.date.fromisoformat, help="window start (YYYY-MM-DD), up to today")
    ap.add_argument("--all", action="store_true", help="include personal repos, sessions and GitHub")
    ap.add_argument("--root", default="~/Projects", help="where to look for repos (default ~/Projects)")
    ap.add_argument("--today", type=dt.date.fromisoformat, default=dt.date.today(), help=argparse.SUPPRESS)
    args = ap.parse_args()
    began = time.monotonic()
    today = args.today
    fetch_start = min(args.since or today, today - dt.timedelta(days=LOOKBACK_DAYS))

    me, org, project = guarded("az", (None, None, None), az_identity)
    repos = guarded("git", [], discover_repos, args.root)
    repos = [r for r in parallel(lambda r: classify(r, org), repos) if r["work"] or args.all]
    if not org and not args.all:
        NOTES.append("git: work repos unknown without an Azure DevOps org; rerun with --all")
    for r in repos:
        r["emails"] |= {me} if me else set()
    projects = None if args.all else {n for r in repos for n in (r["name"], Path(r["path"]).parent.name)}

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        f_commits = [pool.submit(guarded, "git", [], git_activity, r, r["emails"], fetch_start, today) for r in repos]
        f_trees = [pool.submit(guarded, "git", [], git_state, r, r["emails"]) for r in repos]
        f_wips = [pool.submit(guarded, "git", [], wip_branches, r, r["emails"], fetch_start) for r in repos]
        f_prs = pool.submit(guarded, "az prs", [], az_prs, me) if me else None
        f_reviews = pool.submit(guarded, "az reviews", [], az_review_prs, me) if me else None
        f_items = pool.submit(guarded, "az work items", [], az_work_items, me, fetch_start, today) if me else None
        f_open = pool.submit(guarded, "az work items", [], az_open_items) if me else None
        f_pipes = pool.submit(guarded, "az pipelines", [], az_pipelines, me, fetch_start) if me else None
        f_gh = pool.submit(guarded, "gh", [], gh_activity, fetch_start) if args.all else None
        f_sessions = pool.submit(guarded, "sessions", [], sessions, fetch_start, today, projects)
        result = lambda f: f.result() if f else []
        commits = [c for f in f_commits for c in f.result()]
        trees = [t for f in f_trees for t in f.result()]
        wips = [w for f in f_wips for w in f.result()]
        prs, review_prs, items = result(f_prs), result(f_reviews), result(f_items)
        open_items, pipelines, gh_prs, sess = result(f_open), result(f_pipes), result(f_gh), result(f_sessions)
    if not me:
        NOTES.append("az: PRs, reviews, work items and pipelines skipped (no az identity)")
    for pr in prs:
        for r in pr["reviewers"]:
            r["self"] = bool(me) and r["email"].lower() == me.lower()

    dates = [local_day(c["day"]) for c in commits] + [local_day(s["day"]) for s in sess]
    dates += [local_day(pr[k]) for pr in prs + gh_prs for k in ("created", "closed") if pr.get(k)]
    dates += [local_day(s["day"]) for i in items for s in i["states"]]
    window = pick_window(today, dates, args.since)

    # Thread scan: PRs touched in the lookback, reviews first, capped at THREAD_CAP calls.
    def touched(pr):
        return pr["status"] == "active" or (pr.get("closed") and local_day(pr["closed"]) >= window["start"])
    candidates = ([pr for pr in review_prs if touched(pr)] + [pr for pr in prs if touched(pr)])[:THREAD_CAP]
    threads = []
    if me and project:
        threads = [t for t in parallel(lambda pr: guarded("az threads", None, az_threads, pr, project, me,
                                                          window["start"], window["end"]), candidates) if t]
    elif me:
        NOTES.append("az threads: skipped (no default project in `az devops configure -l`)")

    in_win_sessions = [s for s in sess if in_window(s["day"], window)]
    yesterday = merge(window, [c for c in commits if in_window(c["day"], window)], prs, review_prs, threads,
                      items, pipelines, gh_prs, in_win_sessions)
    if not (yesterday or in_win_sessions):
        NOTES.append(f"nothing recorded between {window['start']} and {window['end']}")

    out = {
        "window": {**{k: str(v) if isinstance(v, dt.date) else v for k, v in window.items()},
                   "today": str(today), "today_is_live": today != dt.date.today()},
        "me": {"az": me, "org": org, "emails": sorted({e for r in repos for e in r["emails"]})},
        "notes": NOTES,
        "yesterday": yesterday,
        "today": today_state(prs, open_items, trees, wips, window),
        "blockers": blockers(prs, open_items, pipelines),
        "sessions": in_win_sessions,
        "meta": {**META, "elapsed_s": round(time.monotonic() - began, 1),
                 "repos": [{"name": r["name"], "work": r["work"]} for r in repos]},
    }
    print(json.dumps(out, indent=2, ensure_ascii=False, default=str))


if __name__ == "__main__":
    main()
