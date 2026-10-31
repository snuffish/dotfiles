#!/usr/bin/env python3
"""SessionStart hook: warns when the registry's skills or Modules have drifted from the code.

Runs skills/skill-drift/scripts/check_skill_drift.py and, when it reports FAIL or STALE claims, shows the developer
a one-line warning and gives Claude the failing claims plus a pointer to the skill-drift skill. WARN and SKIP rows
stay quiet: they depend on the machine or on wording, not on drift.

The result is cached in the git dir (skill-drift-cache.json) per HEAD, working-tree status and diff, checker/claims
content, and target project HEADs (e.g. GR.PRIIS), so a session in an unchanged checkout doesn't pay for a second run.

It only ever adds context: it never blocks a session and exits 0 even when it fails itself.
"""

import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CHECKER = REPO / "skills" / "skill-drift" / "scripts" / "check_skill_drift.py"
CLAIMS = REPO / "skills" / "skills-claims.json"
SHOWN = 8


def git(cwd: Path, *args: str) -> bytes:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, check=True).stdout


def project_heads() -> bytes:
    projects_dir = REPO / "skills" / "Projects"
    if not projects_dir.is_dir():
        return b""
    parts = []
    for ws_file in sorted(projects_dir.glob("*/.workspaces")):
        proj_name = ws_file.parent.name
        for raw in ws_file.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            ws = Path(os.path.expanduser(line)).resolve()
            for cand in (ws / proj_name, ws):
                if (cand / ".git").exists():
                    try:
                        parts.append(git(cand, "rev-parse", "HEAD"))
                        parts.append(git(cand, "status", "--porcelain=v1", "-z"))
                    except Exception:
                        pass
                    break
    return b"".join(parts)


def cache_key() -> str:
    digest = hashlib.sha256()
    for part in (
        git(REPO, "rev-parse", "HEAD"),
        git(REPO, "status", "--porcelain=v1", "-z"),
        git(REPO, "diff", "HEAD"),
        CHECKER.read_bytes(),
        CLAIMS.read_bytes(),
        project_heads(),
    ):
        digest.update(part)
    return digest.hexdigest()


def drift() -> list[dict]:
    """The checker's FAIL and STALE results, from the cache when nothing changed since the last run."""
    git_path = git(REPO, "rev-parse", "--git-path", "skill-drift-cache.json").decode("utf-8").strip()
    cache = Path(git_path) if os.path.isabs(git_path) else (REPO / git_path)
    key = cache_key()
    try:
        cached = json.loads(cache.read_text(encoding="utf-8"))
        if cached.get("key") == key:
            return cached["results"]
    except (OSError, ValueError, KeyError):
        pass
    proc = subprocess.run(
        [sys.executable, "-I", str(CHECKER), "--claims", str(CLAIMS), "--json"],
        cwd=REPO,
        capture_output=True,
        encoding="utf-8",
        timeout=45,
    )
    results = [r for r in json.loads(proc.stdout)["results"] if r["status"] in ("fail", "stale")]
    cache.write_text(json.dumps({"key": key, "results": results}, ensure_ascii=False), encoding="utf-8")
    return results


def main() -> None:
    results = drift()
    if not results:
        return
    fails = sum(r["status"] == "fail" for r in results)
    stale = len(results) - fails
    summary = (
        f"Skill drift: {fails} failing and {stale} stale claim(s) in ~/.terminal/skills "
        "(python3 -I ~/.terminal/skills/skill-drift/scripts/check_skill_drift.py)."
    )
    lines = [
        f"- {r['status'].upper()} {r['file']}:{r['line']} ({r['kind']}) {r['value'][:60]}: {r['detail'][:160]}"
        for r in results[:SHOWN]
    ]
    if len(results) > SHOWN:
        lines.append(f"- … {len(results) - SHOWN} more; run the checker for the full list.")
    context = (
        f"{summary} A skill or Module may now state something the code no longer does; check the cited code before "
        "relying on these lines, and follow the skill-drift skill to triage and fix them:\n" + "\n".join(lines)
    )
    print(
        json.dumps(
            {
                "systemMessage": summary,
                "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": context},
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        main()
    except Exception:  # a warning hook must never break session start
        pass
    sys.exit(0)
