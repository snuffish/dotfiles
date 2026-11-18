#!/usr/bin/env python3
"""Print the tracked code files of a repo or folder as rows for a whole-file cleanup, as JSON.

Rows are parent folders, largest first. A row lists its code files with their line counts, the test
files that name one of them, and the files passed with --protect. Lockfiles, generated files and docs
are left out with branch_scope.py's patterns; every other file without a code extension is counted
per extension and never opened.

Usage: python3 -I repo_scope.py [<path> ...] [--protect <path> ...] [--no-touch <path> ...] [--repo <dir>]
Exit codes: 0 ok, 1 nothing in scope, 2 git error.
"""
import argparse, fnmatch, json, os, re, sys
from pathlib import Path

# One list of skip patterns for both skills.
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "simplify-branch" / "scripts"))
from branch_scope import git, is_doc, is_generated  # noqa: E402

CODE = {
    ".py", ".sh", ".bash", ".zsh", ".ps1", ".cs", ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
    ".go", ".rs", ".java", ".kt", ".rb", ".php", ".swift", ".c", ".h", ".cpp", ".hpp", ".sql",
    ".yml", ".yaml",
}
TEST_DIRS = {"tests", "test", "__tests__", "e2e"}
TEST_NAMES = ("test_*", "*_test.*", "*.test.*", "*.spec.*", "*Tests.cs", "*Test.java")


def is_test(path):
    *folders, name = path.split("/")
    return bool(TEST_DIRS & set(folders)) or any(fnmatch.fnmatch(name, p) for p in TEST_NAMES)


def names(path):
    """Regex source for "a test names this file": its file name, an import of its stem, or the bare stem
    when that is distinctive (upper case, `_` or `-`). `run` or `body` alone would match any test."""
    name = path.rsplit("/", 1)[-1]
    stem = re.escape(Path(name).stem)
    if re.search(r"[A-Z_-]", stem):
        return rf"\b{stem}\b"
    return rf"\b(?:import|from)\s+(?:[\w.]+\.)?{stem}\b|[/\"']{stem}[\"']|\b{re.escape(name)}\b"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*", help="folders or files to scope; default: the whole repo")
    ap.add_argument("--protect", nargs="+", default=[], help="files whose changes must stay small")
    ap.add_argument("--no-touch", nargs="+", default=[], help="paths left out of files, rows and tests")
    ap.add_argument("--repo", default=".", help="a folder inside the repo; paths are read against it")
    a = ap.parse_args()

    try:
        os.chdir(a.repo)
        root = git("rev-parse", "--show-toplevel")
        left_out = [f":(exclude){p}" for p in a.no_touch]
        tracked = git("ls-files", "--full-name", "--", *(a.paths or [":/"]), *left_out).splitlines()
        everything = git("ls-files", "--full-name", "--", ":/", *left_out).splitlines()
        protected = set(git("ls-files", "--full-name", "--", *a.protect).splitlines()) if a.protect else set()
        dirty = set(git("diff", "--name-only", "HEAD").splitlines())
        default = git("symbolic-ref", "--short", "refs/remotes/origin/HEAD", check=False).removeprefix("origin/")
        branch = git("branch", "--show-current")
        head = git("rev-parse", "--short=12", "HEAD")
    except (OSError, RuntimeError) as e:
        print(json.dumps({"error": str(e)}))
        return 2

    generated = [f for f in tracked if is_generated(f)]
    docs = [f for f in tracked if is_doc(f) and not is_generated(f)]
    other = {}
    code = []
    for f in tracked:
        if is_generated(f) or is_doc(f):
            continue
        ext = Path(f).suffix
        if ext in CODE:
            code.append(f)
        else:
            other[ext or "(none)"] = other.get(ext or "(none)", 0) + 1
    # Tests are looked up in the whole repo: a scoped folder is usually tested from a tests/ folder beside it.
    tests = [f for f in everything if Path(f).suffix in CODE and is_test(f) and not is_generated(f)]
    files = [f for f in code if not is_test(f)]

    def read(f):
        return (Path(root) / f).read_text(errors="ignore")

    lines = {f: read(f).count("\n") for f in files}
    test_text = {t: read(t) for t in tests}
    rows = {}
    for f in files:
        row = rows.setdefault(f.rsplit("/", 1)[0] if "/" in f else ".", {"files": [], "lines": 0})
        row["files"].append(f)
        row["lines"] += lines[f]
    for row in rows.values():
        named = re.compile("|".join(names(f) for f in row["files"] if Path(f).stem != "__init__") or r"(?!)")
        row["tests"] = [t for t in tests if named.search(test_text[t])]
        row["protected"] = [f for f in row["files"] + row["tests"] if f in protected]
        row["simplify"] = "/simplify " + " ".join(row["files"])

    out = {
        "repo_root": root,
        "branch": branch,
        "head": head,
        "default_branch": default or None,
        "on_default": bool(default) and branch == default,
        "files": files,
        "lines": lines,
        "tests": tests,
        "rows": dict(sorted(rows.items(), key=lambda kv: -kv[1]["lines"])),
        "protected": sorted(protected),
        "no_touch": a.no_touch,
        "dirty": sorted(dirty & set(files + tests)),
        "skipped_generated": generated,
        "skipped_docs": docs,
        "skipped_other": dict(sorted(other.items(), key=lambda kv: -kv[1])),
    }
    print(json.dumps(out, indent=2))
    return 0 if files else 1


if __name__ == "__main__":
    sys.exit(main())
