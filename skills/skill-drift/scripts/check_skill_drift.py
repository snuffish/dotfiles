#!/usr/bin/env python3
"""Checks the factual claims in the registry's skills, Modules, Profiles, and repo docs against the codebase.

Reads skills/skills-claims.json: one entry per claim, with the source file, line, quote, and how to verify it.
Also runs a built-in auto-scan pass (--no-auto to skip) across skills/**/*.md, claude/AGENTS.md, GLOSSARY.md,
and docs/adr/*.md that verifies relative links, #anchor slugs, `<target>` › *Heading* pointers, and warns on
covered SKILL.md or Module files with zero claims.

Usage:
    python3 -I skills/skill-drift/scripts/check_skill_drift.py
    python3 -I skills/skill-drift/scripts/check_skill_drift.py --file 'skills/_modules/*'
    python3 -I skills/skill-drift/scripts/check_skill_drift.py --project GR.PRIIS
    python3 -I skills/skill-drift/scripts/check_skill_drift.py --json
    python3 -I skills/skill-drift/scripts/check_skill_drift.py --strict
    python3 -I skills/skill-drift/scripts/check_skill_drift.py --mcp
    python3 -I skills/skill-drift/scripts/check_skill_drift.py --no-auto
"""

import argparse
import fnmatch
import json
import os
import posixpath
import re
import shutil
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

for stream in (sys.stdout, sys.stderr):
    stream.reconfigure(encoding="utf-8", errors="replace")

DEFAULT_REPO = Path(__file__).resolve().parents[3]
DEFAULT_CLAIMS = DEFAULT_REPO / "skills" / "skills-claims.json"
WARN_KINDS = {"other", "count"}
WARN_METHODS = {"executable", "mcp_tool"}
TEMPLATE_ANCHOR_RE = re.compile(r"^(?:finding-\d+(?:-plain)?|thread-\d+|minor-findings|req-\d+|hunk-\d+|item-\d+)$", re.I)
POINTER_RE = re.compile(
    r"(?:\[([^\]]+)\]\(([^)]+)\)|`([^`\n]+)`(?:\s+skill)?)\s*›\s*(?:\*{1,2}|_{1,2}|`)([^*\n_`]+)(?:\*{1,2}|_{1,2}|`)"
)
CONFIG_ALIASES = {
    "~/.claude/CLAUDE.md": "claude/AGENTS.md",
    "~/.gemini/GEMINI.md": "claude/AGENTS.md",
    "AGENTS.md": "claude/AGENTS.md",
    "~/.claude/settings.json": "claude/settings.json",
    "~/.claude/statusline.sh": "claude/statusline.sh",
}


class Repo:
    """The files git knows about in a repository root (plus optional workspace parent files), read once and cached."""

    def __init__(self, root: Path, ws_root: Path | None = None):
        self.root = root
        self.ws_root = ws_root
        out = subprocess.run(
            ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
            cwd=root,
            capture_output=True,
            check=True,
        ).stdout.decode("utf-8", errors="replace")
        self.files = sorted({f for f in out.split("\0") if f and (root / f).is_file()})
        self.dirs = {posixpath.dirname(f) for f in self.files if posixpath.dirname(f)}
        self.dirs |= {"/".join(d.split("/")[:i]) for d in list(self.dirs) for i in range(1, d.count("/") + 1)}
        self._text, self._glob, self._slugs, self._anchors = {}, {}, {}, {}

    def _resolve_disk_path(self, rel: str) -> Path | None:
        p = self.root / rel
        if p.is_file():
            return p
        if self.ws_root and (self.ws_root / rel).is_file():
            return self.ws_root / rel
        return None

    def text(self, rel: str) -> str:
        if rel not in self._text:
            p = self._resolve_disk_path(rel)
            self._text[rel] = p.read_text(encoding="utf-8", errors="replace") if p else ""
        return self._text[rel]

    def glob(self, pattern: str) -> list[str]:
        if pattern not in self._glob:
            rx = re.compile("|".join(glob_to_regex(p) for p in expand_braces(pattern)))
            matched = [f for f in self.files if rx.fullmatch(f)]
            if not matched and self.ws_root and (self.ws_root / pattern).is_file():
                matched = [pattern]
            self._glob[pattern] = matched
        return self._glob[pattern]

    def exists(self, rel: str, kind: str | None = None) -> bool:
        rel = rel.rstrip("/")
        if kind != "dir" and (rel in self.files or (self.ws_root and (self.ws_root / rel).is_file())):
            return True
        if kind != "file" and (rel in self.dirs or (self.ws_root and (self.ws_root / rel).is_dir())):
            return True
        return False

    def slugs(self, rel: str) -> set[str]:
        if rel not in self._slugs:
            self._slugs[rel] = compute_slugs(self.text(rel))
        return self._slugs[rel]

    def heading_anchors(self, rel: str) -> tuple[set[str], list[str]]:
        if rel not in self._anchors:
            self._anchors[rel] = compute_heading_anchors(self, rel, seen_files=set())
        return self._anchors[rel]


class MultiRepo:
    """Manages the primary ~/.terminal Repo and lazy-loaded project Repos from skills/Projects/<Project>/.workspaces."""

    def __init__(self, primary_root: Path):
        self.primary_root = primary_root
        self.primary = Repo(primary_root)
        self._projects: dict[str, Repo | None] = {}

    def project(self, name: str) -> Repo | None:
        if name not in self._projects:
            self._projects[name] = self._discover_project(name)
        return self._projects[name]

    def _discover_project(self, name: str) -> Repo | None:
        ws_file = self.primary_root / "skills" / "Projects" / name / ".workspaces"
        if not ws_file.is_file():
            return None
        for raw in ws_file.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            ws = Path(os.path.expanduser(line)).resolve()
            if not ws.is_dir():
                continue
            cand = ws / name
            if (cand / ".git").exists():
                return Repo(cand, ws_root=ws)
            if (ws / ".git").exists():
                return Repo(ws)
            for child in sorted(ws.iterdir()):
                if child.is_dir() and (child / ".git").exists():
                    return Repo(child, ws_root=ws)
        return None

    def for_base(self, base: str | None) -> tuple[Repo | None, str]:
        base = base or "repo"
        if base.startswith("project:"):
            proj = base.split(":", 1)[1]
            return self.project(proj), proj
        return self.primary, ""


def expand_braces(pattern: str) -> list[str]:
    m = re.search(r"\{([^{}]*)\}", pattern)
    if not m:
        return [pattern]
    return [x for alt in m.group(1).split(",") for x in expand_braces(pattern[: m.start()] + alt + pattern[m.end() :])]


def glob_to_regex(pattern: str) -> str:
    out, i = [], 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return "".join(out)


def resolve(base: str | None, rel: str, source: str) -> str | None:
    """Resolve a claim path or glob as repo-relative posix, or None when it points outside the repo."""
    rel_norm = rel.replace("\\", "/")
    if rel_norm in CONFIG_ALIASES and (base or "repo") != "file_dir":
        rel_norm = CONFIG_ALIASES[rel_norm]
    start = posixpath.dirname(source) if base == "file_dir" else ""
    path = posixpath.normpath(posixpath.join(start, rel_norm))
    return None if path.startswith("..") or posixpath.isabs(path) else path


def norm_heading(s: str) -> str:
    s = re.sub(r"<[^>]+>", "", s)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)
    s = re.sub(r"[`*_~]", "", s)
    s = re.sub(r"^(?:step\s+\d+[a-z]?|case\s+[a-z]|\d+(?:\.\d+)*)\s*[—–:\-.\)]\s*", "", s.strip(), flags=re.I)
    return re.sub(r"\s+", " ", s).strip().lower()


def compute_slugs(markdown: str) -> set[str]:
    """GitHub heading anchors and HTML <a id/name="..."> anchors of a markdown file, skipping fenced code."""
    seen, out, fence_marker = Counter(), set(), None
    for line in markdown.splitlines():
        stripped = line.lstrip()
        if m_fence := re.match(r"^(`{3,}|~{3,})", stripped):
            marker = m_fence.group(1)
            if fence_marker is None:
                fence_marker = marker
            elif stripped.startswith(fence_marker[0] * len(fence_marker)) and not stripped[len(fence_marker) :].strip():
                fence_marker = None
            continue
        if fence_marker is not None:
            continue
        for am in re.finditer(r"<a\s+(?:id|name)=[\"']([^\"']+)[\"']", line, re.I):
            out.add(am.group(1).lower())
        if not (m := re.match(r"#{1,6}\s+(.*?)\s*#*\s*$", line)):
            continue
        heading = re.sub(r"<[^>]+>", "", m.group(1))
        heading = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", heading)
        slug = re.sub(r"[^\w\- ]", "", heading.strip().lower()).replace(" ", "-")
        out.add(slug if not seen[slug] else f"{slug}-{seen[slug]}")
        seen[slug] += 1
    return out


def compute_heading_anchors(repo: Repo, rel: str, seen_files: set[str]) -> tuple[set[str], list[str]]:
    if rel in seen_files:
        return set(), []
    seen_files.add(rel)
    text = repo.text(rel)
    if repo.ws_root and (repo.root / rel).is_file() and (repo.ws_root / rel).is_file():
        text = text + "\n" + (repo.ws_root / rel).read_text(encoding="utf-8", errors="replace")
    anchors, raw_lines = set(), []
    fence_marker = None
    for line in text.splitlines():
        stripped = line.lstrip()
        if m_fence := re.match(r"^(`{3,}|~{3,})", stripped):
            marker = m_fence.group(1)
            if fence_marker is None:
                fence_marker = marker
            elif stripped.startswith(fence_marker[0] * len(fence_marker)) and not stripped[len(fence_marker) :].strip():
                fence_marker = None
            continue
        if fence_marker is not None:
            continue
        raw_lines.append(norm_heading(line))
        if m := re.match(r"#{1,6}\s+(.*?)\s*#*\s*$", line):
            h = m.group(1)
            for variant in (h, re.sub(r"\s*\([^)]*\)\s*$", "", h), h.split("—")[0], h.split(":")[0]):
                if nv := norm_heading(variant):
                    anchors.add(nv)
        for bm in re.finditer(r"\*\*([^*]+)\*\*", line):
            b = bm.group(1)
            for variant in (b, re.sub(r"\s*\([^)]*\)\s*$", "", b), b.split(":")[0]):
                if nv := norm_heading(variant):
                    anchors.add(nv)
    for rm in re.finditer(r"\]\((references/[^)#]+\.md)\)", text):
        ref_rel = posixpath.normpath(posixpath.join(posixpath.dirname(rel), rm.group(1)))
        if repo.exists(ref_rel, "file"):
            sub_a, sub_l = compute_heading_anchors(repo, ref_rel, seen_files)
            anchors |= sub_a
            raw_lines.extend(sub_l)
    return anchors, raw_lines


def resolve_pointer_target(repos: MultiRepo, src: str, target: str, explicit_base: str | None = None) -> tuple[Repo | None, str | None, str]:
    """Return (repo_obj, rel_path, status_hint) where status_hint is 'ok', 'skip', or 'fail'."""
    t = target.strip().strip("`")
    if any(c in t for c in ("<", ">", "…", "*", "{", "}")) or t in ("href", "target"):
        return None, None, "skip"
    if t in CONFIG_ALIASES and not (t == "CLAUDE.md" and src.startswith("skills/Projects/")):
        t = CONFIG_ALIASES[t]
    t_first = t.lstrip("/").split()[0] if t.startswith("/") else t.lstrip("/")

    if explicit_base and explicit_base.startswith("project:"):
        proj_repo, proj_name = repos.for_base(explicit_base)
        if proj_repo is None:
            return None, None, f"skip:workspace for {proj_name} not present on this machine"
        for cand in (t, t_first, f".claude/skills/{t_first}/SKILL.md", f".claude/skills/{t_first}"):
            if proj_repo.exists(cand, "file") and cand.endswith(".md"):
                return proj_repo, cand, "ok"
        return proj_repo, None, "fail"

    primary = repos.primary
    src_dir = posixpath.dirname(src)
    parent_skill_md = posixpath.normpath(posixpath.join(src_dir, "..", "SKILL.md"))
    candidates = [
        posixpath.normpath(posixpath.join(src_dir, t)),
        parent_skill_md if t == "SKILL.md" else "",
        f"skills/_modules/{t_first}.md",
        f"skills/_modules/{t_first}",
        f"skills/_modules/references/{t_first}",
        f"skills/_modules/references/{t_first}.md",
        f"skills/{t_first}/SKILL.md",
        f"skills/{t_first}",
        f"skills/Projects/GR.PRIIS/{t_first}/SKILL.md",
        t_first,
    ]
    for cand in candidates:
        if cand and not cand.startswith("..") and primary.exists(cand, "file") and cand.endswith(".md"):
            if cand == "CLAUDE.md" and src.startswith("skills/Projects/"):
                # Prefer workspace CLAUDE.md when inside a project skill
                break
            return primary, cand, "ok"

    # Check project repos (e.g. GR.PRIIS)
    proj_match = re.match(r"^skills/Projects/([^/]+)/", src)
    proj_names = [proj_match.group(1)] if proj_match else ["GR.PRIIS"]
    for pname in proj_names:
        proj_repo = repos.project(pname)
        if proj_repo is None:
            if proj_match:
                return None, None, f"skip:workspace for {pname} not present on this machine"
            continue
        for cand in (t, t_first, f".claude/skills/{t_first}/SKILL.md", f".claude/skills/{t_first}"):
            if proj_repo.exists(cand, "file") and cand.endswith(".md"):
                return proj_repo, cand, "ok"
    return primary, None, "fail"


def check_heading_in_file(repo: Repo, rel: str, heading: str) -> bool:
    anchors, raw_lines = repo.heading_anchors(rel)
    nh = norm_heading(heading)
    if not nh:
        return True
    return any(nh == a or nh in a or a in nh for a in anchors if a) or any(nh in rl for rl in raw_lines)


def mcp_tools(repo_root: Path, server: str):
    """Tool names a configured stdio MCP server lists, or an error string."""
    config = {}
    for path in (repo_root / ".mcp.json", Path.home() / ".claude.json"):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        for scope in (data, data.get("projects", {}).get(str(repo_root), {})):
            config = scope.get("mcpServers", {}).get(server) or config
    if not config:
        return f"MCP server '{server}' is not configured on this machine"
    if "command" not in config:
        return f"MCP server '{server}' is not a stdio server; only stdio servers can be queried"
    messages = [
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "check-skill-drift", "version": "1"},
            },
        },
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
    ]
    try:
        proc = subprocess.run(
            [config["command"], *config.get("args", [])],
            input="".join(json.dumps(m) + "\n" for m in messages),
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=60,
            env={**os.environ, **config.get("env", {})},
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        return f"MCP server '{server}' did not answer: {e}"
    for line in proc.stdout.splitlines():
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if msg.get("id") == 2 and "result" in msg:
            return {t["name"] for t in msg["result"].get("tools", [])}
    return f"MCP server '{server}' returned no tools/list result"


class Checker:
    def __init__(self, repos: MultiRepo, query_mcp: bool):
        self.repos = repos
        self.query_mcp = query_mcp
        self._mcp = {}

    def grep_hits(self, repo: Repo, v: dict, src: str):
        rx = re.compile(v["pattern"], re.MULTILINE)
        base = v.get("base")
        effective_base = "repo" if (base and base.startswith("project:")) else base
        files = sorted({f for p in v["paths"] if (g := resolve(effective_base, p, src)) for f in repo.glob(g)})
        return files, sum(len(rx.findall(repo.text(f))) for f in files)

    def check(self, claim: dict) -> tuple[str, str]:
        """Return (status, detail) where status is 'ok', 'fail', or 'skip'."""
        v, src = claim["verify"], claim["source"]["file"]
        method = v["method"]
        base = v.get("base", "repo")
        if method == "manual":
            return "skip", f"manual: {v.get('reason', 'unchecked')}"
        if method == "executable":
            return ("ok", "") if shutil.which(v["name"]) else ("fail", f"'{v['name']}' is not on PATH")
        if method == "mcp_tool":
            if not self.query_mcp:
                return "skip", "MCP tool (pass --mcp to query the configured servers)"
            server = v["server"]
            if server not in self._mcp:
                self._mcp[server] = mcp_tools(self.repos.primary_root, server)
            tools = self._mcp[server]
            if isinstance(tools, str):
                return "fail", tools
            tool = re.sub(rf"^mcp__{re.escape(server)}__", "", v["tool"])
            return ("ok", "") if tool in tools else ("fail", f"server '{server}' has no tool '{tool}'")

        target_repo, proj_name = self.repos.for_base(base)
        if target_repo is None:
            return "skip", f"workspace for {proj_name} not present on this machine"
        effective_base = "repo" if base.startswith("project:") else base

        if method == "path_exists":
            rel = resolve(effective_base, v["path"], src)
            if rel and target_repo.exists(rel, v.get("type")):
                return "ok", ""
            on_disk = " (on disk, but git does not track it)" if rel and (target_repo.root / rel).exists() else ""
            return "fail", f"path not found: {rel or v['path']}{on_disk}"
        if method == "glob_exists":
            pat = resolve(effective_base, v["glob"], src) or v["glob"]
            n = len(target_repo.glob(pat))
            return ("ok", "") if n >= v.get("min", 1) else ("fail", f"glob matches {n}, needs {v.get('min', 1)}: {v['glob']}")
        if method == "link_resolves":
            href, _, anchor = v["href"].partition("#")
            rel = resolve(v.get("base", "file_dir"), href, src) if href else src
            if not rel or not target_repo.exists(rel):
                return "fail", f"link target not found: {v['href']}"
            if anchor and rel.endswith(".md") and anchor.lower() not in target_repo.slugs(rel):
                return "fail", f"no heading #{anchor} in {rel}"
            return "ok", ""
        if method == "heading_pointer":
            target = v.get("target") or v.get("path") or v.get("file", "")
            heading = v["heading"]
            ptr_repo, rel, hint = resolve_pointer_target(self.repos, src, target, explicit_base=base if base != "repo" else None)
            if hint.startswith("skip"):
                return "skip", hint.partition(":")[2] or "skipped"
            if not ptr_repo or not rel:
                return "fail", f"pointer target not found: {target}"
            if not check_heading_in_file(ptr_repo, rel, heading):
                return "fail", f"heading '{heading}' not found in {rel}"
            return "ok", ""
        if method == "grep":
            files, hits = self.grep_hits(target_repo, v, src)
            if not files:
                return "fail", f"no files match {v['paths']}"
            if (hits > 0) == (v.get("expect", "present") == "present"):
                return "ok", ""
            found = "not found" if v.get("expect", "present") == "present" else f"found {hits}x, expected absent"
            return "fail", f"/{v['pattern']}/ {found} in {', '.join(v['paths'])}"
        if method == "count":
            if "glob" in v:
                pat = resolve(effective_base, v["glob"], src) or v["glob"]
                n = len(target_repo.glob(pat))
            else:
                n = self.grep_hits(target_repo, v, src)[1]
            op, want = v.get("op", "eq"), v["expected"]
            good = {"eq": n == want, "gte": n >= want, "lte": n <= want}[op]
            return ("ok", "") if good else ("fail", f"counted {n}, claim says {op} {want}")
        if method == "npm_script":
            pkg = f"{v['package_dir'].rstrip('/')}/package.json"
            if not target_repo.exists(pkg):
                return "fail", f"{pkg} not found"
            scripts = json.loads(target_repo.text(pkg)).get("scripts", {})
            return ("ok", "") if v["script"] in scripts else ("fail", f"no npm script '{v['script']}' in {pkg}")
        if method == "skill_exists":
            name = v["name"].lstrip("/")
            if base.startswith("project:"):
                ok = target_repo.exists(f".claude/skills/{name}/SKILL.md") or self.repos.primary.exists(
                    f"skills/Projects/{proj_name}/{name}/SKILL.md"
                )
                return ("ok", "") if ok else ("fail", f"no skill '{name}' in {proj_name} or registry")
            ok = self.repos.primary.exists(f"skills/{name}/SKILL.md") or bool(
                self.repos.primary.glob(f"skills/Projects/*/{name}/SKILL.md")
            )
            return ("ok", "") if ok else ("fail", f"no skill '{name}' in registry")
        return "fail", f"unknown verify method '{method}' (fix the claim)"


def locate(repo: Repo, claim: dict) -> int | None:
    """Return the claim's current line in source, or None when the quote is missing."""
    src = claim["source"]
    if not repo.exists(src["file"], "file"):
        return None
    quote = " ".join(claim.get("quote", "").split())
    lines = [" ".join(line.split()) for line in repo.text(src["file"]).splitlines()]
    line = src["line"]
    if not quote or (0 < line <= len(lines) and quote in lines[line - 1]):
        return line
    return next((n for n, text in enumerate(lines, 1) if quote in text), None)


def extract_quote_window(line_text: str, target: str, max_len: int = 140) -> str:
    cleaned = " ".join(line_text.split())
    if len(cleaned) <= max_len:
        return cleaned
    pos = cleaned.find(target)
    if pos == -1:
        return cleaned[:max_len]
    start = max(0, pos - (max_len - len(target)) // 2)
    end = min(len(cleaned), start + max_len)
    if end - start < max_len:
        start = max(0, end - max_len)
    return cleaned[start:end].strip()


def reconcile_claim(claim: dict, repo: Repo, checker: Checker) -> bool:
    """Attempt to reconcile a stale or drifted claim in-place. Return True if updated."""
    src_file = claim["source"]["file"]
    if not repo.exists(src_file, "file"):
        return False
    lines = repo.text(src_file).splitlines()
    orig_line = claim["source"]["line"]
    kind = claim.get("kind", "")
    method = claim.get("verify", {}).get("method", "")
    updated = False

    # 1. Update count claim if count verification failed or drifted
    if method == "count":
        v = claim["verify"]
        base = v.get("base", "repo")
        target_repo, _ = checker.repos.for_base(base)
        if target_repo is not None:
            effective_base = "repo" if base.startswith("project:") else base
            if "glob" in v:
                pat = resolve(effective_base, v["glob"], src_file) or v["glob"]
                n = len(target_repo.glob(pat))
            else:
                n = checker.grep_hits(target_repo, v, src_file)[1]
            if v.get("expected") != n:
                v["expected"] = n
                val = str(claim.get("value", ""))
                m = re.match(r"^\d+(.*)", val)
                if m:
                    claim["value"] = f"{n}{m.group(1)}"
                else:
                    claim["value"] = str(n)
                updated = True

    # 2. Check if quote needs re-anchoring
    curr_line = locate(repo, claim)
    if curr_line is not None:
        if curr_line != orig_line:
            claim["source"]["line"] = curr_line
            claim["id"] = f"{src_file}:{curr_line}:{kind}:{claim.get('value', '')}"[:200]
            updated = True
        return updated

    # Quote is stale (not found in source). Try to find target in adjacent lines (±10)
    candidates = []
    if kind == "skill_ref":
        target = claim.get("verify", {}).get("name") or claim.get("value")
        if target:
            candidates.extend([f"`{target}`", f"/{target}", target])
    elif kind in ("symbol", "path"):
        val = claim.get("value")
        if val:
            candidates.extend([f"`{val}`", val])
    elif kind == "count":
        val = claim.get("value")
        v = claim.get("verify", {})
        candidates.extend([str(v.get("expected", "")), str(val), "skills total", "Modules"])

    search_indices = sorted(
        range(max(0, orig_line - 11), min(len(lines), orig_line + 10)),
        key=lambda i: abs(i + 1 - orig_line)
    )

    found_idx = None
    matched_target = ""
    for idx in search_indices:
        line_text = lines[idx]
        for cand in candidates:
            if cand and cand in line_text:
                found_idx = idx
                matched_target = cand
                break
        if found_idx is not None:
            break

    if found_idx is not None:
        new_line = found_idx + 1
        new_quote = extract_quote_window(lines[found_idx], matched_target)
        claim["source"]["line"] = new_line
        claim["quote"] = new_quote
        claim["id"] = f"{src_file}:{new_line}:{kind}:{claim.get('value', '')}"[:200]
        return True

    return updated


def covered_markdown_files(repo: Repo, file_globs: list[str] | None, project: str | None) -> list[str]:
    files = [
        f
        for f in repo.files
        if (f.startswith("skills/") and f.endswith(".md") and not f.startswith("skills/flat-links/"))
        or f in ("claude/AGENTS.md", "claude/CLAUDE.md", "GLOSSARY.md")
        or (f.startswith("docs/adr/") and f.endswith(".md"))
    ]
    if project:
        prefix = f"skills/Projects/{project}/"
        files = [f for f in files if f.startswith(prefix)]
    if file_globs:
        files = [f for f in files if any(fnmatch.fnmatch(f, g) for g in file_globs)]
    return files


def run_auto_scan(repos: MultiRepo, covered_files: list[str], all_claims: list[dict]) -> list[dict]:
    """Scan covered markdown files for broken relative links, #anchors, › *Heading* pointers, and 0-claim SKILL.md/Modules."""
    primary = repos.primary
    auto_results = []
    claimed_files = {c["source"]["file"] for c in all_claims}

    for f in covered_files:
        text = primary.text(f)
        fence_marker = None
        for lineno, line in enumerate(text.splitlines(), 1):
            stripped = line.lstrip()
            if m_fence := re.match(r"^(`{3,}|~{3,})", stripped):
                marker = m_fence.group(1)
                if fence_marker is None:
                    fence_marker = marker
                elif stripped.startswith(fence_marker[0] * len(fence_marker)) and not stripped[len(fence_marker) :].strip():
                    fence_marker = None
                continue
            if fence_marker is not None:
                continue

            # 1. Markdown links + #anchors outside inline backticks
            clean_no_code = re.sub(r"`[^`]*`", "", line)
            for m in re.finditer(r"\[([^\]]*)\]\(([^)]+)\)", clean_no_code):
                href = m.group(2).strip()
                if any(
                    href.startswith(p)
                    for p in ("http://", "https://", "mailto:", "file://", "antigravity-ide://", "conversation://")
                ):
                    continue
                if any(c in href for c in ("<", ">", "{", "}", "…", "*")):
                    continue
                path_part, _, anchor = href.partition("#")
                if path_part and posixpath.basename(path_part).startswith(("claude-", "antigravity-")):
                    continue
                if not path_part and anchor and TEMPLATE_ANCHOR_RE.match(anchor):
                    continue
                rel = resolve("file_dir", path_part, f) if path_part else f
                if not rel or not primary.exists(rel):
                    auto_results.append(
                        {
                            "id": f"auto:{f}:{lineno}:link_resolves:{href}"[:200],
                            "file": f,
                            "line": lineno,
                            "kind": "doc_link",
                            "value": href,
                            "status": "fail",
                            "detail": f"link target not found: {href}",
                        }
                    )
                elif anchor and rel.endswith(".md") and anchor.lower() not in primary.slugs(rel):
                    auto_results.append(
                        {
                            "id": f"auto:{f}:{lineno}:link_resolves:{href}"[:200],
                            "file": f,
                            "line": lineno,
                            "kind": "doc_link",
                            "value": href,
                            "status": "fail",
                            "detail": f"no heading #{anchor} in {rel}",
                        }
                    )

            # 2. Prose heading pointers: `<target>` › *Heading* or [label](href) › *Heading*
            for pm in POINTER_RE.finditer(line):
                _, href, code_t, heading = pm.groups()
                target = href.split("#")[0] if href else code_t
                if not target or any(c in target or c in heading for c in ("<", ">", "…", "{", "}")):
                    continue
                if target in ("SKILL.md",) and f.endswith("README.md"):
                    continue
                ptr_repo, rel, hint = resolve_pointer_target(repos, f, target)
                if hint.startswith("skip"):
                    continue
                if not ptr_repo or not rel:
                    auto_results.append(
                        {
                            "id": f"auto:{f}:{lineno}:heading_pointer:{target} › {heading}"[:200],
                            "file": f,
                            "line": lineno,
                            "kind": "doc_link",
                            "value": f"{target} › {heading}",
                            "status": "fail",
                            "detail": f"pointer target not found: {target}",
                        }
                    )
                elif not check_heading_in_file(ptr_repo, rel, heading):
                    auto_results.append(
                        {
                            "id": f"auto:{f}:{lineno}:heading_pointer:{target} › {heading}"[:200],
                            "file": f,
                            "line": lineno,
                            "kind": "doc_link",
                            "value": f"{target} › {heading}",
                            "status": "fail",
                            "detail": f"heading '{heading}' not found in {rel}",
                        }
                    )

        # 3. Warn on covered SKILL.md or top-level Module files with 0 claims
        is_skill_or_module = f.endswith("/SKILL.md") or (
            f.startswith("skills/_modules/") and posixpath.dirname(f) == "skills/_modules" and f.endswith(".md")
        )
        if is_skill_or_module and f not in claimed_files:
            auto_results.append(
                {
                    "id": f"auto:{f}:1:coverage:unclaimed",
                    "file": f,
                    "line": 1,
                    "kind": "other",
                    "value": "0 claims in skills-claims.json",
                    "status": "warn",
                    "detail": "covered SKILL.md or Module has no extracted claims in skills/skills-claims.json",
                }
            )

    return auto_results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--claims", type=Path, default=DEFAULT_CLAIMS)
    parser.add_argument("--file", action="append", help="only claims whose source matches this glob (repeatable)")
    parser.add_argument("--project", help="only check claims and files for skills/Projects/<name>")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--strict", action="store_true", help="warnings fail the run too")
    parser.add_argument("--mcp", action="store_true", help="start each configured MCP server and list its tools")
    parser.add_argument("--no-auto", action="store_true", help="skip automatic link, #anchor, and › *Heading* scan")
    parser.add_argument("--update-stale", action="store_true", help="automatically reconcile stale quotes and shifted line numbers in claims")
    args = parser.parse_args()

    claims_path = args.claims.resolve()
    repo_root = claims_path.parents[1] if claims_path.parent.name == "skills" else DEFAULT_REPO

    try:
        raw = claims_path.read_text(encoding="utf-8")
        data = json.loads(raw)
        all_claims = data["claims"]
    except (OSError, ValueError, KeyError) as e:
        print(f"Cannot read {args.claims}: {e}", file=sys.stderr)
        return 2

    repos = MultiRepo(repo_root)
    checker = Checker(repos, args.mcp)

    claims = list(all_claims)
    if args.project:
        proj_prefix = f"skills/Projects/{args.project}/"
        proj_base = f"project:{args.project}"
        claims = [
            c
            for c in claims
            if c["source"]["file"].startswith(proj_prefix) or c.get("verify", {}).get("base") == proj_base
        ]
    if args.file:
        claims = [c for c in claims if any(fnmatch.fnmatch(c["source"]["file"], g) for g in args.file)]

    # --file/--project scope the reconcile too, so a scoped run never rewrites other skills' claims
    if args.update_stale:
        reconciled = 0
        for claim in claims:
            if reconcile_claim(claim, repos.primary, checker):
                reconciled += 1
        if reconciled:
            raw = json.dumps(data, indent=2) + "\n"
            claims_path.write_text(raw, encoding="utf-8")
            print(f"Reconciled {reconciled} stale/drifted claim(s) in {claims_path.name}")

    format_ok = raw == json.dumps(data, indent=2) + "\n"

    results = []
    for claim in claims:
        line = locate(repos.primary, claim)
        if line is None:
            status, detail = "stale", f"quote no longer in source: {claim.get('quote', '')[:80]!r}"
        else:
            try:
                status, detail = checker.check(claim)
            except (re.error, KeyError) as e:
                status, detail = "fail", f"broken claim ({type(e).__name__}: {e})"
            if status == "fail" and (claim["kind"] in WARN_KINDS or claim["verify"]["method"] in WARN_METHODS):
                status = "warn"
        results.append(
            {
                "id": claim["id"],
                "file": claim["source"]["file"],
                "line": line or claim["source"]["line"],
                "kind": claim["kind"],
                "value": claim.get("value", ""),
                "status": status,
                "detail": detail,
            }
        )

    if not format_ok:
        results.append(
            {
                "id": f"format:{claims_path.name}",
                "file": claims_path.name,
                "line": 1,
                "kind": "format",
                "value": "",
                "status": "fail",
                "detail": 'not canonical: write with json.dumps(data, indent=2) + "\\n" (ASCII-escaped, trailing newline)',
            }
        )

    if not args.no_auto:
        covered = covered_markdown_files(repos.primary, args.file, args.project)
        results.extend(run_auto_scan(repos, covered, all_claims))

    totals = Counter(r["status"] for r in results)
    failed = totals["fail"] + totals["stale"] + (totals["warn"] if args.strict else 0)
    if args.json:
        print(
            json.dumps(
                {"totals": dict(totals), "results": [r for r in results if r["status"] != "ok"]},
                indent=2,
                ensure_ascii=False,
            )
        )
        return 1 if failed else 0

    print(
        f"Skill drift: {len(results)} checks"
        + "".join(f", {totals[s]} {s}" for s in ("ok", "fail", "warn", "stale", "skip") if totals[s])
    )
    for status, title in (
        ("fail", "FAIL: the skill names something that is gone"),
        ("warn", "WARN: fuzzy, count, coverage or machine-dependent checks"),
        ("stale", "STALE: re-extract these claims; the skill text changed"),
    ):
        rows = [r for r in results if r["status"] == status]
        if not rows:
            continue
        print(f"\n{title} ({len(rows)})")
        by_file = defaultdict(list)
        for r in rows:
            by_file[r["file"]].append(r)
        for file in sorted(by_file):
            print(f"  {file}")
            for r in sorted(by_file[file], key=lambda r: r["line"]):
                print(f"    L{r['line']:<4} {r['kind']:<11} {r['value'][:50]:<50}  {r['detail']}")
    if failed:
        print(
            f"\n{failed} check(s) failed. Fix the skill, or fix the claim in {claims_path.name} if the checker is wrong "
            "(skill skill-drift: skills/skill-drift/SKILL.md)."
        )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
