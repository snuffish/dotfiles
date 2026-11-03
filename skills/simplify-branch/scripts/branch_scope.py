#!/usr/bin/env python3
"""Print the files the current branch changed against its base, as JSON.

Base resolution order: --base, the active PR's target (az repos pr list),
then origin/HEAD. Committed files come from `git diff <merge-base>...HEAD`;
working-tree files are uncommitted tracked changes plus untracked files.
Deleted files are dropped; lockfiles, generated files and docs (*.md, *.html,
*.txt, *.log) are left out of "files" and listed separately.

Usage: python3 -I branch_scope.py [--base <branch>] [--committed-only]
                                  [--no-pr-lookup] [--no-fetch]
Exit codes: 0 ok, 1 nothing in scope, 2 git error (detached HEAD, no base).
"""
import argparse, fnmatch, json, subprocess, sys

GENERATED = [
    "*.lock", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "packages.lock.json",
    "*.Designer.cs", "*ModelSnapshot.cs", "*.gen.ts", "*.g.cs", "*.min.js", "*.min.css",
    "swagger.json", "*.snap",
]


def git(*args, check=True):
    r = subprocess.run(["git", *args], capture_output=True, text=True)
    if check and r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout.strip() if r.returncode == 0 else ""


def pr_target(branch):
    try:
        r = subprocess.run(
            ["az", "repos", "pr", "list", "--source-branch", branch, "--status", "active",
             "--query", "[].targetRefName", "-o", "json"],
            capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None, "az unavailable"
    if r.returncode != 0:
        return None, "az failed"
    targets = sorted(set(json.loads(r.stdout or "[]")))
    if len(targets) == 1:
        return targets[0].removeprefix("refs/heads/"), "pr"
    return None, "no active PR" if not targets else f"several PR targets: {targets}"


DOCS = ("*.md", "*.html", "*.txt", "*.log")


def is_doc(path):
    name = path.rsplit("/", 1)[-1]
    return any(fnmatch.fnmatch(name, p) for p in DOCS)


def is_generated(path):
    name = path.rsplit("/", 1)[-1]
    return any(fnmatch.fnmatch(name, p) for p in GENERATED) or "/Migrations/" in f"/{path}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base")
    ap.add_argument("--no-pr-lookup", action="store_true")
    ap.add_argument("--no-fetch", action="store_true")
    ap.add_argument("--committed-only", action="store_true")
    a = ap.parse_args()

    try:
        branch = git("branch", "--show-current")
        if not branch:
            raise RuntimeError("detached HEAD: check out the branch to simplify")
        base, source, note = a.base, "argument", None
        if not base and not a.no_pr_lookup:
            base, note = pr_target(branch)
            source = "pr" if base else None
        if not base:
            head = git("symbolic-ref", "--short", "refs/remotes/origin/HEAD", check=False)
            if not head:
                raise RuntimeError("no base: pass --base <branch> (origin/HEAD is unset)")
            base, source = head.removeprefix("origin/"), "origin/HEAD"
        if base == branch:
            raise RuntimeError(f"current branch '{branch}' is the base: nothing to scope")
        if not a.no_fetch:
            git("fetch", "--quiet", "origin", base, check=False)
        ref = f"origin/{base}" if git("rev-parse", "--verify", "--quiet", f"origin/{base}", check=False) else base
        merge_base = git("merge-base", "HEAD", ref)
        root = git("rev-parse", "--show-toplevel")

        committed = git("diff", "--name-only", "--diff-filter=d", f"{merge_base}...HEAD").splitlines()
        dirty = git("diff", "--name-only", "--diff-filter=d", "HEAD").splitlines()
        untracked = git("ls-files", "--others", "--exclude-standard").splitlines()
    except RuntimeError as e:
        print(json.dumps({"error": str(e)}))
        return 2

    working = [] if a.committed_only else sorted(set(dirty + untracked) - set(committed))
    every = sorted(set(committed) | set(working))
    skipped = [f for f in every if is_generated(f)]
    docs = [f for f in every if is_doc(f) and not is_generated(f)]
    keep = lambda f: not is_generated(f) and not is_doc(f)
    out = {
        "repo_root": root,
        "branch": branch,
        "base": base,
        "base_ref": ref,
        "base_source": source,
        "pr_lookup": note,
        "merge_base": merge_base[:12],
        "committed": [f for f in committed if keep(f)],
        "working_tree": [f for f in working if keep(f)],
        "skipped_generated": skipped,
        "skipped_docs": docs,
    }
    out["files"] = sorted(set(out["committed"]) | set(out["working_tree"]))

    # Churn per file (+added/-deleted vs the merge base) and per parent folder,
    # the raw material for the review matrix.
    span = [merge_base, "HEAD"] if a.committed_only else [merge_base]
    churn = {}
    for row in git("diff", "--numstat", *span).splitlines():
        add, dele, path = row.split("\t", 2)
        churn[path] = [int(add) if add.isdigit() else 0, int(dele) if dele.isdigit() else 0]
    for f in out["working_tree"]:
        if f not in churn:  # untracked: every line is new
            try:
                with open(f"{root}/{f}", errors="ignore") as fh:
                    churn[f] = [sum(1 for _ in fh), 0]
            except OSError:
                churn[f] = [0, 0]
    out["churn"] = {f: churn.get(f, [0, 0]) for f in out["files"]}
    groups = {}
    for f in out["files"]:
        g = groups.setdefault(f.rsplit("/", 1)[0] if "/" in f else ".", {"files": [], "added": 0, "deleted": 0})
        g["files"].append(f)
        g["added"] += out["churn"][f][0]
        g["deleted"] += out["churn"][f][1]
    out["groups"] = dict(sorted(groups.items(), key=lambda kv: -(kv[1]["added"] + kv[1]["deleted"])))
    print(json.dumps(out, indent=2))
    return 0 if out["files"] else 1


if __name__ == "__main__":
    sys.exit(main())
